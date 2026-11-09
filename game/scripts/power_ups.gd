class_name PowerUps
extends Node2D
## What the power-up buttons under the jar do, and how many uses are left.
## (The 4th, battery, is the shake; its kick lives in shaker.gd.)
##
## 1. MERGE (purple & yellow monsters icon): every Tier 1 and Tier 2 monster in
##    the jar vanishes at once with a little puff.
## 2. BOMB: targeting mode. A red target appears on every monster; tap one and
##    a bomb drops on it, it is destroyed, and a cloud of smoke bursts out.
## 3. UPGRADE (arrow icon): targeting mode with green targets; tap one and that
##    monster turns into the next tier up. Tier 8 bosses can't be upgraded, so
##    they get no target.
##
## In targeting mode the ship stops dropping, a hint shows above the jar, and
## the button glows. Tap the same button again, or tap empty space, to cancel.
## Power-ups give no points.
##
## LIMITED USES
## Each power-up starts the game with START_USES uses (the number in the
## bubble on its button). A use is only spent when it does something: Merge
## when it clears at least one monster, Bomb / Upgrade when a monster is
## tapped (cancelling is free), the battery when the jar actually shakes
## (shaking the phone spends one too). At 0 the button greys out.
## Every EARN_EVERY_POINTS points scored, each power-up gets one more use,
## up to MAX_USES.
##
## main.gd creates this node, calls setup() and passes the score to
## on_score(). All the numbers are below.

## Uses at the start of each game.
const START_USES := {"merge": 1, "bomb": 2, "upgrade": 1, "battery": 3}
## Every time the score passes another multiple of this, each power-up gets +1.
const EARN_EVERY_POINTS := 500
## Most uses a power-up can hold.
const MAX_USES := 9

## Which tiers the Merge power-up clears.
const CLEAR_TIERS: Array[int] = [1, 2]
## Target colours (bomb = red, upgrade = green).
const BOMB_COLOR := Color(1.0, 0.3, 0.35)
const UPGRADE_COLOR := Color(0.4, 1.0, 0.55)
## How far outside a target you can tap and still hit it (pixels).
const TAP_SLACK := 18.0
## Seconds the bomb takes to fall onto its monster.
const BOMB_FALL_TIME := 0.38
## How far above the monster the bomb starts falling from.
const BOMB_FALL_HEIGHT := 260.0

var enabled := true
## Uses left, by power-up name.
var uses := {}

var _rewards_given := 0
var _shaker: Shaker
var _monsters: Node2D
var _dropper: Dropper
var _hud: Hud
var _spawn: Callable
## "" = not targeting, otherwise "bomb" or "upgrade".
var _mode := ""
var _time := 0.0
var _hint: Label
var _glow_tween: Tween
var _smoke_texture: Texture2D


## main.gd: the node holding the monsters, the ship, the HUD, the shaker, and
## the function that spawns a monster (tier, position) -> Monster.
func setup(monsters: Node2D, dropper: Dropper, hud: Hud, shaker: Shaker, spawn: Callable) -> void:
	_monsters = monsters
	_dropper = dropper
	_hud = hud
	_shaker = shaker
	_spawn = spawn
	hud.power_up_pressed.connect(_on_power_up_pressed)
	shaker.shaken.connect(func() -> void: _spend("battery"))
	uses = START_USES.duplicate()
	for power_up in uses:
		_refresh(power_up)


## main.gd calls this whenever the score changes: every EARN_EVERY_POINTS
## points, each power-up gets one more use.
func on_score(score: int) -> void:
	var earned := score / EARN_EVERY_POINTS
	if earned <= _rewards_given or not enabled:
		return
	var gained := earned - _rewards_given
	_rewards_given = earned
	for power_up in uses:
		uses[power_up] = mini(uses[power_up] + gained, MAX_USES)
		_refresh(power_up)
		_hud.pop_power_up_count(power_up)
	if _mode == "":
		_flash_hint("Power-ups +%d!" % gained, Color(1, 0.85, 0.35))
	GameAudio.play("bonus")


## Turns everything off at game over.
func stop() -> void:
	cancel()
	enabled = false
	_shaker.enabled = false


func _spend(power_up: String) -> void:
	uses[power_up] = maxi(uses[power_up] - 1, 0)
	_refresh(power_up)


func _refresh(power_up: String) -> void:
	_hud.set_power_up_count(power_up, uses[power_up])
	if power_up == "battery":
		_shaker.enabled = enabled and uses[power_up] > 0


## True if the power-up has a use left; otherwise says so.
func _has_use(power_up: String) -> bool:
	if uses.get(power_up, 0) > 0:
		return true
	var names := {"merge": "clears", "bomb": "bombs", "upgrade": "upgrades", "battery": "shakes"}
	_flash_hint("No %s left!" % names[power_up], Color.WHITE)
	_hud.shake_power_up_button(power_up)
	return false


func _ready() -> void:
	z_index = 5  # targets draw over the monsters and the front glass
	_smoke_texture = _make_soft_circle()
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size = Vector2(720, 40)
	_hint.position = Vector2(0, 462)
	_hint.add_theme_font_size_override("font_size", 28)
	_hint.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.3))
	_hint.add_theme_constant_override("outline_size", 10)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	add_child(_hint)


## Turns targeting off (game over, restart).
func cancel() -> void:
	_set_mode("")


func _on_power_up_pressed(power_up: String) -> void:
	if not enabled:
		return
	if _mode == power_up:
		_set_mode("")  # pressing the active button again cancels
		return
	_set_mode("")
	if not _has_use(power_up):
		return
	match power_up:
		"merge":
			_clear_small_monsters()
		"bomb", "upgrade":
			_set_mode(power_up)
		"battery":
			_shaker.shake()  # spends a use through shaker.shaken


# ---------------------------------------------------------------------------
# 1. Merge: clear all Tier 1 and Tier 2 monsters.

func _clear_small_monsters() -> void:
	var cleared := 0
	for monster in _live_monsters():
		if monster.tier in CLEAR_TIERS:
			var at := monster.global_position
			_vanish(monster, 1.0)
			_smoke(at, TierData.get_radius(monster.tier) * 0.8, Color(0.85, 0.75, 1.0))
			cleared += 1
	if cleared == 0:
		_flash_hint("No small monsters to clear", Color.WHITE)
		return
	_spend("merge")
	GameAudio.play("clear")
	GameAudio.vibrate(60)


# ---------------------------------------------------------------------------
# Targeting mode (bomb and upgrade).

func _set_mode(mode: String) -> void:
	if mode != "" and _targets_for(mode).is_empty():
		_flash_hint("No monsters to " + ("bomb" if mode == "bomb" else "upgrade"), Color.WHITE)
		mode = ""
	if mode == _mode:
		return
	_mode = mode
	_dropper.set_paused(mode != "")
	_glow_button(mode)
	if mode == "":
		_hint.visible = false
	else:
		_show_hint("Tap a monster to " + ("BOMB it!" if mode == "bomb" else "UPGRADE it!"),
				BOMB_COLOR if mode == "bomb" else UPGRADE_COLOR)
		GameAudio.play("aim")
	queue_redraw()


## Monsters that can be picked in this mode.
func _targets_for(mode: String) -> Array[Monster]:
	var list: Array[Monster] = []
	for monster in _live_monsters():
		if mode == "upgrade" and monster.tier >= TierData.tier_count():
			continue
		list.append(monster)
	return list


func _process(delta: float) -> void:
	_time += delta
	if _mode != "":
		queue_redraw()


## A pulsing target over every monster that can be picked.
func _draw() -> void:
	if _mode == "":
		return
	var color := BOMB_COLOR if _mode == "bomb" else UPGRADE_COLOR
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	for monster in _targets_for(_mode):
		var c := monster.global_position
		var r := clampf(TierData.get_radius(monster.tier) * 0.45, 22.0, 64.0) * (1.0 + pulse * 0.08)
		# Dark backing so the target shows on any monster colour.
		draw_arc(c, r, 0, TAU, 48, Color(0.1, 0.05, 0.2, 0.45), 9.0, true)
		draw_arc(c, r, 0, TAU, 48, color, 4.0, true)
		draw_arc(c, r * 0.45, 0, TAU, 32, Color(color, 0.6 + pulse * 0.4), 3.0, true)
		draw_circle(c, 4.0, color)
		# Four ticks, slowly turning.
		for i in 4:
			var dir := Vector2.from_angle(_time * 1.2 + i * PI / 2.0)
			draw_line(c + dir * r * 0.7, c + dir * r * 1.3, Color(0.1, 0.05, 0.2, 0.45), 8.0, true)
			draw_line(c + dir * r * 0.7, c + dir * r * 1.3, color, 4.0, true)


func _unhandled_input(event: InputEvent) -> void:
	if _mode == "":
		return
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	# Swallow both press and release so the ship doesn't drop a monster.
	get_viewport().set_input_as_handled()
	if click.pressed:
		return
	var monster := _monster_at(get_global_mouse_position())
	if monster == null:
		_set_mode("")  # tapped empty space: cancel
		return
	var mode := _mode
	_set_mode("")
	_spend(mode)
	if mode == "bomb":
		_drop_bomb(monster)
	else:
		_upgrade(monster)


## The pickable monster under a tap (the closest one if targets overlap).
func _monster_at(point: Vector2) -> Monster:
	var best: Monster = null
	var best_d := INF
	for monster in _targets_for(_mode):
		var d := point.distance_to(monster.global_position)
		if d <= TierData.get_radius(monster.tier) + TAP_SLACK and d < best_d:
			best = monster
			best_d = d
	return best


# ---------------------------------------------------------------------------
# 2. Bomb.

func _drop_bomb(monster: Monster) -> void:
	monster.is_merging = true  # can't merge while the bomb is on its way
	var bomb := Node2D.new()
	bomb.z_index = 1
	bomb.draw.connect(func() -> void: _draw_bomb(bomb))
	add_child(bomb)
	bomb.global_position = monster.global_position - Vector2(0, BOMB_FALL_HEIGHT)
	GameAudio.play("whoosh")
	# Falls onto the monster, following it if it moves.
	var start := bomb.global_position
	var tween := bomb.create_tween()
	tween.tween_method(func(t: float) -> void:
		if is_instance_valid(monster):
			bomb.global_position = start.lerp(monster.global_position, t * t)
		bomb.rotation = t * 1.5
		bomb.queue_redraw(), 0.0, 1.0, BOMB_FALL_TIME)
	tween.tween_callback(func() -> void:
		var at := bomb.global_position
		bomb.queue_free()
		_explode(monster, at))


func _explode(monster: Monster, at: Vector2) -> void:
	var r := 60.0
	if is_instance_valid(monster):
		r = TierData.get_radius(monster.tier)
		_vanish(monster, 0.0)
	_shockwave(at, r * 1.6)
	_sparks(at, r)
	_smoke(at, r, Color(0.78, 0.76, 0.82))
	GameAudio.play("boom")
	GameAudio.vibrate(150)


## A cartoon bomb: black ball, shine, fuse and a flickering spark.
func _draw_bomb(bomb: Node2D) -> void:
	var dark := Color(0.12, 0.1, 0.16)
	bomb.draw_circle(Vector2.ZERO, 30.0, dark)
	bomb.draw_circle(Vector2(-9, -10), 9.0, Color(1, 1, 1, 0.35))
	bomb.draw_rect(Rect2(-8, -40, 16, 12), Color(0.35, 0.33, 0.4))
	bomb.draw_line(Vector2(0, -40), Vector2(10, -54), Color(0.75, 0.6, 0.4), 4.0, true)
	var flicker := 7.0 + sin(_time * 40.0) * 3.0
	bomb.draw_circle(Vector2(10, -56), flicker, Color(1.0, 0.75, 0.2))
	bomb.draw_circle(Vector2(10, -56), flicker * 0.5, Color(1, 1, 0.8))


# ---------------------------------------------------------------------------
# 3. Upgrade.

func _upgrade(monster: Monster) -> void:
	var new_tier := monster.tier + 1
	var at := monster.global_position
	var velocity := monster.linear_velocity
	var spin := monster.rotation
	_vanish(monster, 0.0)
	var upgraded: Monster = _spawn.call(new_tier, at)
	upgraded.rotation = spin
	upgraded.linear_velocity = velocity * 0.5
	upgraded.pop_in()
	_shockwave(at, TierData.get_radius(new_tier) * 1.4, UPGRADE_COLOR)
	_sparks(at, TierData.get_radius(new_tier), UPGRADE_COLOR)
	GameAudio.play("upgrade")
	GameAudio.vibrate(40)


# ---------------------------------------------------------------------------
# Shared effects.

## Monsters currently in play (dropped, not already merging or vanishing).
func _live_monsters() -> Array[Monster]:
	var list: Array[Monster] = []
	if _monsters == null:
		return list
	for node in _monsters.get_children():
		var monster := node as Monster
		if monster and not monster.is_merging and not monster.freeze and not monster.is_queued_for_deletion():
			list.append(monster)
	return list


## Removes a monster from the jar at once; `shrink` seconds of a shrinking,
## fading copy are left behind (0 = gone instantly).
func _vanish(monster: Monster, shrink: float) -> void:
	monster.is_merging = true
	if shrink > 0.0:
		var sprite := monster.get_node_or_null("BlinkSprite") as Sprite2D
		for child in monster.get_children():
			if child is Sprite2D:
				sprite = child
		if sprite:
			var ghost := Sprite2D.new()
			ghost.texture = sprite.texture
			ghost.scale = sprite.scale
			ghost.global_position = monster.global_position
			ghost.rotation = monster.rotation
			add_child(ghost)
			var t := ghost.create_tween().set_parallel(true)
			t.tween_property(ghost, "scale", ghost.scale * 0.2, shrink * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			t.tween_property(ghost, "modulate:a", 0.0, shrink * 0.35)
			t.chain().tween_callback(ghost.queue_free)
	_monsters.remove_child(monster)
	monster.queue_free()


## A burst of soft smoke puffs that drift up and fade.
func _smoke(at: Vector2, radius: float, tint: Color) -> void:
	radius = maxf(radius, 45.0)  # small monsters still get a proper puff
	var p := CPUParticles2D.new()
	p.texture = _smoke_texture
	p.one_shot = true
	p.amount = 36
	p.lifetime = 1.3
	p.explosiveness = 0.92
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.6
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = radius * 1.4
	p.initial_velocity_max = radius * 3.6
	p.damping_min = radius * 2.0
	p.damping_max = radius * 3.0
	p.gravity = Vector2(0, -40)
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	var size := radius / 40.0
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.4
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.8))
	grow.add_point(Vector2(1, 1.8))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(tint, 0.95))
	fade.set_color(1, Color(tint.darkened(0.45), 0.0))
	fade.add_point(0.4, Color(tint.darkened(0.2), 0.7))
	p.color_ramp = fade
	_play_once(p, at)


## Quick bright sparks flying out (orange for the bomb, or a given colour).
func _sparks(at: Vector2, radius: float, color := Color(1.0, 0.7, 0.2)) -> void:
	var p := CPUParticles2D.new()
	p.texture = _smoke_texture
	p.one_shot = true
	p.amount = 22
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 420.0
	p.damping_min = 300.0
	p.damping_max = 500.0
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 0.85))
	fade.set_color(1, Color(color, 0.0))
	fade.add_point(0.3, color)
	p.color_ramp = fade
	_play_once(p, at)


func _play_once(p: CPUParticles2D, at: Vector2) -> void:
	p.z_index = 1
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3, false).timeout.connect(p.queue_free)


## An expanding ring that fades out.
func _shockwave(at: Vector2, radius: float, color := Color(1.0, 0.9, 0.7)) -> void:
	var ring := Node2D.new()
	ring.z_index = 1
	add_child(ring)
	ring.global_position = at
	var state := {"t": 0.0}
	ring.draw.connect(func() -> void:
		var t: float = state["t"]
		ring.draw_circle(Vector2.ZERO, radius * 0.5 * (1.0 - t), Color(1, 1, 0.9, 0.6 * (1.0 - t)))
		ring.draw_arc(Vector2.ZERO, radius * (0.3 + 0.7 * t), 0, TAU, 48, Color(color, 1.0 - t), 10.0 * (1.0 - t) + 1.0, true))
	var tween := ring.create_tween()
	tween.tween_method(func(t: float) -> void:
		state["t"] = t
		ring.queue_redraw(), 0.0, 1.0, 0.35)
	tween.tween_callback(ring.queue_free)


## A soft white dot, used for smoke puffs and sparks.
func _make_soft_circle() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.55, Color(1, 1, 1, 0.75))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 96
	tex.height = 96
	return tex


func _show_hint(text: String, color: Color) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", color)
	_hint.modulate.a = 1.0
	_hint.visible = true


## A hint that fades away by itself.
func _flash_hint(text: String, color: Color) -> void:
	_show_hint(text, color)
	var tween := _hint.create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(_hint, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		if _mode == "":
			_hint.visible = false)


## The button for the active mode glows on and off.
func _glow_button(mode: String) -> void:
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null
	for name in ["bomb", "upgrade"]:
		var button := _hud.get_power_up_button(name)
		if button:
			button.modulate = Color.WHITE
	if mode == "":
		return
	var active := _hud.get_power_up_button(mode)
	if active == null:
		return
	_glow_tween = active.create_tween().set_loops()
	_glow_tween.tween_property(active, "modulate", Color(1.45, 1.45, 1.2), 0.35)
	_glow_tween.tween_property(active, "modulate", Color.WHITE, 0.35)
