extends Node2D
## Main game scene. Connects the dropper, the jar and the HUD, and runs the
## merge rule: when two monsters of the same tier touch, both disappear and one
## monster of the next tier appears at their exact midpoint.

const SAVE_PATH := "user://best_score.cfg"

@onready var jar: Jar = $Jar
@onready var dropper: Dropper = $Dropper
@onready var monsters: Node2D = $Monsters
@onready var hud: Hud = $HUD

var score := 0
var best := 0
var _is_over := false
var _shaker: Shaker


func _ready() -> void:
	randomize()
	_check_sprites()

	best = _load_best()
	hud.set_score(0)
	hud.set_best(best)

	dropper.dropped.connect(_on_dropped)
	jar.game_over.connect(_on_game_over)
	hud.play_again_pressed.connect(_on_play_again)
	hud.restart_pressed.connect(_on_play_again)

	dropper.setup(jar)

	# Shake the phone (or press SHAKE on PC) to jostle the monsters.
	_shaker = Shaker.new()
	add_child(_shaker)

	# Animated opening (logo + monsters jumping in) on first launch only.
	Intro.play_over(self)


func _on_dropped(tier: int, at: Vector2) -> void:
	_spawn_monster(tier, at)


func _spawn_monster(tier: int, at: Vector2) -> Monster:
	var monster := Monster.new()
	monster.setup(tier)
	monster.position = at
	monster.touched_same_tier.connect(_on_same_tier_touched)
	monsters.add_child(monster)
	return monster


func _on_same_tier_touched(a: Monster, b: Monster) -> void:
	if _is_over or a.is_merging or b.is_merging:
		return
	a.is_merging = true
	b.is_merging = true
	# Physics bodies can't be removed in the middle of a physics step,
	# so the merge itself runs right after it.
	_merge.call_deferred(a, b)


func _merge(a: Monster, b: Monster) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	var midpoint := (a.global_position + b.global_position) / 2.0
	var velocity := (a.linear_velocity + b.linear_velocity) / 2.0
	var new_tier := a.tier + 1

	for old in [a, b]:
		monsters.remove_child(old)
		old.queue_free()

	if new_tier > TierData.tier_count():
		# Two Tier 7 bosses: both vanish for a big bonus.
		_add_score(TierData.BOSS_MERGE_BONUS)
		_show_points_popup(midpoint, 0, TierData.BOSS_MERGE_BONUS)
		GameAudio.play("boss")
		GameAudio.vibrate(120)
		return

	var points := TierData.get_points(new_tier)
	var bonus := TierData.get_bonus(new_tier)
	_add_score(points + bonus)
	_show_points_popup(midpoint, points, bonus)
	# Pop sound: small monsters pop high, big ones pop deeper.
	var size := float(new_tier - 2) / (TierData.tier_count() - 2)
	GameAudio.play("pop", lerpf(1.35, 0.7, size))
	if bonus > 0:
		GameAudio.play("bonus")
	GameAudio.vibrate(20 + new_tier * 5)
	var merged := _spawn_monster(new_tier, midpoint)
	merged.linear_velocity = velocity * 0.5
	merged.pop_in()


func _add_score(points: int) -> void:
	score += points
	hud.set_score(score)
	hud.set_best(maxi(best, score))


## Floating score text where a merge happened: the normal points in small
## white ("+21"), and any bonus on its own line in bigger gold ("BONUS +30"),
## so players can tell the two apart. Rises and fades in under a second.
func _show_points_popup(at: Vector2, points: int, bonus: int) -> void:
	var popup := Node2D.new()
	popup.position = at
	popup.z_index = 10
	add_child(popup)

	if points > 0:
		popup.add_child(_popup_label("+%d" % points, 26, Color.WHITE, Vector2(0, -16)))
	if bonus > 0:
		var bonus_label := _popup_label("BONUS +%d" % bonus, 36, Color(1, 0.82, 0.3), Vector2(0, 20))
		popup.add_child(bonus_label)
		# Little pop so the bonus catches the eye.
		bonus_label.scale = Vector2(0.6, 0.6)
		bonus_label.create_tween().tween_property(bonus_label, "scale", Vector2.ONE, 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var tween := popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", at.y - 70.0, 0.8)
	tween.tween_property(popup, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tween.chain().tween_callback(popup.queue_free)


func _popup_label(text: String, font_size: int, color: Color, offset: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.3))
	label.add_theme_constant_override("outline_size", 10)
	label.size = Vector2(260, font_size + 16)
	label.position = offset - label.size / 2.0
	label.pivot_offset = label.size / 2.0
	return label


func _on_game_over() -> void:
	_is_over = true
	dropper.stop()
	_shaker.enabled = false
	GameAudio.play("game_over")
	GameAudio.vibrate(300)
	var is_new_best := score > best
	if is_new_best:
		best = score
		_save_best(best)
	hud.show_game_over(score, best, is_new_best)


func _on_play_again() -> void:
	get_tree().reload_current_scene()


func _load_best() -> int:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 0
	return int(config.get_value("score", "best", 0))


func _save_best(value: int) -> void:
	var config := ConfigFile.new()
	config.set_value("score", "best", value)
	config.save(SAVE_PATH)


func _check_sprites() -> void:
	var missing: Array[String] = []
	for tier in range(1, TierData.tier_count() + 1):
		if TierData.get_texture(tier) == null:
			missing.append(TierData.get_tier(tier)["texture"])
	if not missing.is_empty():
		push_warning("Monster Merge: missing sprites: %s" % ", ".join(missing))
