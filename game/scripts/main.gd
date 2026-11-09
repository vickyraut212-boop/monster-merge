extends Node2D
## Main game scene. Connects the dropper, the jar and the HUD, and runs the
## merge rule: when two monsters of the same tier touch, both disappear and one
## monster of the next tier appears at their exact midpoint.

const SAVE_PATH := "user://best_score.cfg"

## COMBO: merges that follow each other within COMBO_WINDOW seconds form a
## chain (chain reactions in the jar, or a quick drop that merges right after
## the last one). The chain ends once COMBO_WINDOW passes with no merge.
const COMBO_WINDOW := 1.5
## Extra points per chain step: this share of the merge's points for each
## step past the first (x2 adds half again, x3 a whole extra, ...), and never
## less than COMBO_MIN_EXTRA per step.
const COMBO_STEP := 0.5
const COMBO_MIN_EXTRA := 5
## Feedback words show this far above the merge, never higher than
## MESSAGE_TOP (just under the dashed line), and between the jar walls.
const MESSAGE_LIFT := 90.0
const MESSAGE_TOP := 575.0
## Tier bonuses this big or bigger (Tier 6 and up) get a BONUS +N word.
const BONUS_MESSAGE_MIN := 30

@onready var jar: Jar = $Jar
@onready var dropper: Dropper = $Dropper
@onready var monsters: Node2D = $Monsters
@onready var hud: Hud = $HUD

var score := 0
var best := 0
var _is_over := false
var _shaker: Shaker
## For the online leaderboard: how long the run took and how many drops it
## had (the server uses these to reject impossible scores).
var _run_started_ms := 0
var _drops := 0
var _power_ups: PowerUps
## Merges in the current chain, and when the last one happened.
var _combo := 0
var _last_merge_ms := -100000


func _ready() -> void:
	randomize()
	_check_sprites()

	best = _load_best()
	hud.set_score(0)
	hud.set_best(best)

	dropper.next_changed.connect(hud.set_next)
	dropper.dropped.connect(_on_dropped)
	jar.game_over.connect(_on_game_over)
	hud.play_again_pressed.connect(_on_play_again)
	hud.restart_pressed.connect(_on_play_again)
	Backend.score_submitted.connect(_on_score_submitted)

	dropper.setup(jar)
	_run_started_ms = Time.get_ticks_msec()

	# Tap the battery power-up (or shake the phone) to jostle the monsters.
	_shaker = Shaker.new()
	_shaker.button = hud.get_power_up_button("battery")
	add_child(_shaker)

	# All four power-ups and their uses (see power_ups.gd). Added last so it
	# gets taps before the ship does while it is waiting for a target.
	_power_ups = PowerUps.new()
	_power_ups.name = "PowerUps"
	add_child(_power_ups)
	_power_ups.setup(monsters, dropper, hud, _shaker, _spawn_monster)

	# Animated opening (logo + monsters jumping in) on first launch only.
	Intro.play_over(self)


func _on_dropped(tier: int, at: Vector2) -> void:
	_drops += 1
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

	var combo := _count_combo()

	if new_tier > TierData.tier_count():
		# Two Tier 8 bosses: both vanish for a big bonus.
		var boss_extra := _combo_extra(TierData.BOSS_MERGE_BONUS, combo)
		_add_score(TierData.BOSS_MERGE_BONUS + boss_extra)
		_show_feedback(midpoint, TierData.BOSS_MERGE_BONUS + boss_extra, 0, combo, true)
		GameAudio.play("boss")
		GameAudio.vibrate(120)
		return

	var points := TierData.get_points(new_tier)
	var bonus := TierData.get_bonus(new_tier)
	var extra := _combo_extra(points, combo)
	_add_score(points + bonus + extra)
	_show_feedback(midpoint, points + bonus + extra, bonus, combo, false)
	# Pop sound: small monsters pop high, big ones pop deeper.
	var size := float(new_tier - 2) / (TierData.tier_count() - 2)
	GameAudio.play("pop", lerpf(1.35, 0.7, size))
	if combo >= 2:
		# Each step of a chain rings a little higher.
		GameAudio.play("bonus", 1.0 + 0.12 * (mini(combo, 6) - 1))
	elif bonus > 0:
		GameAudio.play("bonus")
	GameAudio.vibrate(20 + new_tier * 5 + mini(combo - 1, 4) * 10)
	var merged := _spawn_monster(new_tier, midpoint)
	merged.linear_velocity = velocity * 0.5
	merged.pop_in()


func _add_score(points: int) -> void:
	score += points
	hud.set_score(score)
	hud.set_best(maxi(best, score))
	_power_ups.on_score(score)


## Adds this merge to the chain (or starts a new one if the last merge was
## too long ago) and returns its place in the chain: 1, 2, 3...
func _count_combo() -> int:
	var now := Time.get_ticks_msec()
	if now - _last_merge_ms <= COMBO_WINDOW * 1000.0:
		_combo += 1
	else:
		_combo = 1
	_last_merge_ms = now
	return _combo


## Extra points for a merge at this place in a chain (0 for the first).
func _combo_extra(points: int, combo: int) -> int:
	if combo < 2:
		return 0
	var steps := combo - 1
	return maxi(roundi(points * COMBO_STEP * steps), COMBO_MIN_EXTRA * steps)


## Feedback for a merge (see reward_text.gd). Only one thing shows:
## - a special moment gets one short word above the merge, picked from a small
##   vocabulary: NICE! (2nd merge in a chain), COMBO x3, SUPER! (4th),
##   WELL DONE! (5th and on, or two bosses vanishing), or BONUS +N for a big
##   tier bonus (Tier 6 and up) outside a chain;
## - any other merge just gets its points ("+21", bonus and chain extra
##   included) at the merge.
func _show_feedback(at: Vector2, total: int, bonus: int, combo: int, boss: bool) -> void:
	var text := ""
	var color := Color.WHITE
	if boss or combo >= 5:
		text = "WELL DONE!"
		color = Color(1.0, 0.72, 0.9)
	elif combo == 4:
		text = "SUPER!"
		color = Color(1.0, 0.8, 0.5)
	elif combo == 3:
		text = "COMBO x3"
		color = Color(0.68, 0.9, 1.0)
	elif combo == 2:
		text = "NICE!"
		color = Color(0.72, 1.0, 0.8)
	elif bonus >= BONUS_MESSAGE_MIN:
		text = "BONUS +%d" % bonus
		color = Color(1.0, 0.86, 0.45)
	if text == "":
		RewardText.points(self, at, "+%d" % total)
		return
	var walls := jar.get_inner_rect()
	RewardText.message(self, Vector2(at.x, maxf(at.y - MESSAGE_LIFT, MESSAGE_TOP)), text, color,
			Vector2(walls.position.x + 10.0, walls.end.x - 10.0))


func _on_game_over() -> void:
	_is_over = true
	dropper.stop()
	_power_ups.stop()
	GameAudio.play("game_over")
	GameAudio.vibrate(300)
	var is_new_best := score > best
	if is_new_best:
		best = score
		_save_best(best)
	hud.show_game_over(score, best, is_new_best)
	_submit_score()


## Sends the run to the online leaderboard. The answer arrives later in
## _on_score_submitted; the game never waits for it.
func _submit_score() -> void:
	if not Backend.is_configured() or score <= 0:
		hud.set_rank_text("")
		return
	hud.set_rank_text("Sending score...")
	Backend.submit_score(score, Time.get_ticks_msec() - _run_started_ms, _drops)


func _on_score_submitted(result: Dictionary) -> void:
	if not _is_over:
		return
	if result.has("error"):
		hud.set_rank_text("Score not accepted online")
	elif result.is_empty():
		hud.set_rank_text("Offline - score will be sent later")
	elif result.get("rank") != null:
		hud.set_rank_text("World rank #%d of %d" % [int(result["rank"]), int(result["total_players"])])
	else:
		hud.set_rank_text("")


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
