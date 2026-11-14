class_name PowerUps
extends Node2D
## What the power-up buttons under the jar do, and when they can be used.
## (The 4th, battery, is the SHAKE; its kick and wobble live in shaker.gd and
## are unchanged.)
##
## 1. MERGE (purple & yellow monsters icon): every Tier 1 and Tier 2 monster in
##    the jar pops away at once, in a quick ripple across the jar.
## 2. BOMB: targeting mode. A red target appears on every monster; tap one and
##    a bomb drops on it and it is destroyed with a short flash and ring.
## 3. UPGRADE (arrow icon): targeting mode with green targets; tap one and that
##    monster turns into the next tier up. Tier 8 bosses can't be upgraded, so
##    they get no target.
##
## In targeting mode the ship stops dropping, a hint shows above the jar, and
## the button glows. Tap the same button again, or tap empty space, to cancel.
## Power-ups give no points.
##
## ONE USE, THEN A 3-MINUTE COOLDOWN
## Each power-up holds exactly one use. Using it starts a COOLDOWN_SECONDS
## (3 minute) cooldown for that power-up only; its button greys out and shows
## a countdown, and when the time is up it gets its one use back. A use is
## only spent when it does something: Merge when it clears at least one
## monster, Bomb / Upgrade when a monster is tapped (cancelling is free), the
## battery when the jar actually shakes (shaking the phone counts too).
##
## The cooldown runs on real time (the system clock), not game time: it keeps
## counting while the game is paused, between games and while the app is
## closed. When each power-up becomes ready again is saved in SAVE_PATH, so
## restarting a game doesn't reset it. If the clock is moved backwards, a
## cooldown is never longer than COOLDOWN_SECONDS.
##
## main.gd creates this node and calls setup(). All the numbers are below.

## Seconds a power-up is unavailable after it is used.
const COOLDOWN_SECONDS := 180.0
## Where the cooldowns are saved between games.
const SAVE_PATH := "user://power_ups.cfg"
const NAMES: Array[String] = ["merge", "bomb", "upgrade", "battery"]

## Which tiers the Merge power-up clears.
const CLEAR_TIERS: Array[int] = [1, 2]
## Target colours (bomb = red, upgrade = green).
const BOMB_COLOR := Color(1.0, 0.3, 0.35)
const UPGRADE_COLOR := Color(0.4, 1.0, 0.55)
const MERGE_COLOR := Color(0.86, 0.66, 1.0)
## How far outside a target you can tap and still hit it (pixels).
const TAP_SLACK := 18.0
## Seconds the bomb takes to fall onto its monster.
const BOMB_FALL_TIME := 0.42
## How far above the monster the bomb starts falling from.
const BOMB_FALL_HEIGHT := 260.0

var enabled := true
## Unix time (seconds) when each power-up is ready again; 0 = ready now.
var ready_at := {}

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
var _dot_texture: Texture2D


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
	_load()
	for power_up in NAMES:
		_refresh(power_up)


## Turns everything off at game over. (Cooldowns keep running in real time.)
func stop() -> void:
	cancel()
	enabled = false
	_shaker.enabled = false


## Seconds until the power-up is ready again (0 = ready).
func time_left(power_up: String) -> float:
	var at: float = ready_at.get(power_up, 0.0)
	if at <= 0.0:
		return 0.0
	return clampf(at - _now(), 0.0, COOLDOWN_SECONDS)


func is_ready(power_up: String) -> bool:
	return time_left(power_up) <= 0.0


func _now() -> float:
	return Time.get_unix_time_from_system()


## Uses up the power-up's one use and starts its cooldown straight away.
func _spend(power_up: String) -> void:
	ready_at[power_up] = _now() + COOLDOWN_SECONDS
	_save()
	_refresh(power_up)


func _refresh(power_up: String) -> void:
	var left := time_left(power_up)
	_hud.set_power_up_cooldown(power_up, left, COOLDOWN_SECONDS)
	if power_up == "battery":
		_shaker.enabled = enabled and left <= 0.0


## Ticks the countdowns on the buttons and gives a use back when one ends.
func _update_cooldowns() -> void:
	for power_up in NAMES:
		var at: float = ready_at.get(power_up, 0.0)
		if at <= 0.0:
			continue
		# Clock moved backwards: never wait longer than one full cooldown.
		if at - _now() > COOLDOWN_SECONDS:
			ready_at[power_up] = _now() + COOLDOWN_SECONDS
		if time_left(power_up) <= 0.0:
			ready_at[power_up] = 0.0
			_save()
			_refresh(power_up)
			if enabled:
				_hud.flash_power_up_ready(power_up)
				GameAudio.play("bonus")
		else:
			_refresh(power_up)


func _load() -> void:
	for power_up in NAMES:
		ready_at[power_up] = 0.0
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for power_up in NAMES:
		ready_at[power_up] = float(config.get_value("ready_at", power_up, 0.0))
		if time_left(power_up) <= 0.0:
			ready_at[power_up] = 0.0


func _save() -> void:
	var config := ConfigFile.new()
	for power_up in NAMES:
		config.set_value("ready_at", power_up, ready_at.get(power_up, 0.0))
	config.save(SAVE_PATH)


## True if the power-up is ready; otherwise says how long is left.
func _has_use(power_up: String) -> bool:
	var left := time_left(power_up)
	if left <= 0.0:
		return true
	var names := {"merge": "Clear", "bomb": "Bomb", "upgrade": "Upgrade", "battery": "Shake"}
	_flash_hint("%s ready in %s" % [names[power_up], Hud.format_cooldown(left)], Color.WHITE)
	_hud.shake_power_up_button(power_up)
	return false


func _ready() -> void:
	z_index = 5  # targets draw over the monsters and the front glass
	_dot_texture = _make_soft_circle()
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
			_shaker.shake()  # spends the use through shaker.shaken


# ---------------------------------------------------------------------------
# 1. Merge: clear all Tier 1 and Tier 2 monsters.

func _clear_small_monsters() -> void:
	var targets: Array[Monster] = []
	for monster in _live_monsters():
		if monster.tier in CLEAR_TIERS:
			targets.append(monster)
	if targets.is_empty():
		_flash_hint("No small monsters to clear", Color.WHITE)
		return
	_spend("merge")
	# They pop one after another from left to right, like a quick ripple.
	targets.sort_custom(func(a: Monster, b: Monster) -> bool: return a.global_position.x < b.global_position.x)
	for i in targets.size():
		var monster := targets[i]
		var at := monster.global_position
		var r := TierData.get_radius(monster.tier)
		var delay := minf(i * 0.035, 0.35)
		_pop_away(monster, delay)
		_after(delay + 0.12, func() -> void:
			_ring(at, r * 1.5, MERGE_COLOR, 0.28, 5.0)
			_sparkles(at, r * 1.1, MERGE_COLOR, 4))
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
	_update_cooldowns()
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
	bomb.scale = Vector2(0.6, 0.6)
	bomb.modulate.a = 0.0
	GameAudio.play("whoosh")
	# Pops into view, then falls onto the monster (following it if it moves),
	# stretching slightly with speed.
	var start := bomb.global_position
	var tween := bomb.create_tween()
	tween.tween_property(bomb, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(bomb, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(t: float) -> void:
		if is_instance_valid(monster):
			bomb.global_position = start.lerp(monster.global_position, t * t)
		bomb.rotation = sin(t * PI) * 0.35
		bomb.scale = Vector2(1.0 - t * 0.12, 1.0 + t * 0.16)
		bomb.queue_redraw(), 0.0, 1.0, BOMB_FALL_TIME)
	tween.tween_callback(func() -> void:
		var at := bomb.global_position
		bomb.queue_free()
		_explode(monster, at))


## The bomb lands: the monster swells and flashes, then bursts with a quick
## bright flash, one crisp ring and a few short streaks. No smoke, and nothing
## bigger than about twice the monster.
func _explode(monster: Monster, at: Vector2) -> void:
	var r := 60.0
	if is_instance_valid(monster):
		r = TierData.get_radius(monster.tier)
		_burst_away(monster)
	_flash(at, r * 1.3, Color(1.0, 0.92, 0.7), 0.16)
	_ring(at, r * 1.9, Color(1.0, 0.62, 0.35), 0.32, 8.0)
	_streaks(at, r, Color(1.0, 0.78, 0.35), 10)
	GameAudio.play("boom")
	GameAudio.vibrate(150)


## A cartoon bomb: glossy dark ball, cap, fuse and a flickering spark.
func _draw_bomb(bomb: Node2D) -> void:
	var dark := Color(0.16, 0.12, 0.24)
	bomb.draw_circle(Vector2(0, 3), 31.0, Color(0.05, 0.02, 0.1, 0.35))
	bomb.draw_circle(Vector2.ZERO, 30.0, dark)
	bomb.draw_circle(Vector2(4, 5), 24.0, Color(0.22, 0.17, 0.32))
	bomb.draw_circle(Vector2(-10, -11), 8.0, Color(1, 1, 1, 0.4))
	bomb.draw_circle(Vector2(-4, -17), 3.5, Color(1, 1, 1, 0.3))
	bomb.draw_rect(Rect2(-9, -38, 18, 11), Color(0.42, 0.38, 0.5))
	bomb.draw_line(Vector2(0, -38), Vector2(10, -52), Color(0.82, 0.66, 0.44), 4.0, true)
	var flicker := 7.0 + sin(_time * 40.0) * 2.5
	bomb.draw_texture_rect(_dot_texture, Rect2(Vector2(10, -54) - Vector2.ONE * flicker * 2.0, Vector2.ONE * flicker * 4.0), false, Color(1.0, 0.7, 0.25, 0.8))
	bomb.draw_circle(Vector2(10, -54), flicker * 0.45, Color(1, 1, 0.85))


# ---------------------------------------------------------------------------
# 3. Upgrade.

## A green ring pulls in onto the monster, it swaps for the next tier with a
## springy pop, and a few sparkles drift up with a small arrow.
func _upgrade(monster: Monster) -> void:
	var new_tier := monster.tier + 1
	monster.is_merging = true  # can't merge while it is being upgraded
	var r := TierData.get_radius(monster.tier)
	_ring(monster.global_position, r * 1.25, UPGRADE_COLOR, 0.18, 6.0, true)
	GameAudio.play("upgrade")
	_after(0.16, func() -> void:
		if not is_instance_valid(monster) or monster.is_queued_for_deletion():
			return
		var at := monster.global_position
		var velocity := monster.linear_velocity
		var spin := monster.rotation
		_monsters.remove_child(monster)
		monster.queue_free()
		var upgraded: Monster = _spawn.call(new_tier, at)
		upgraded.rotation = spin
		upgraded.linear_velocity = velocity * 0.5
		upgraded.pop_in()
		var nr := TierData.get_radius(new_tier)
		_flash(at, nr * 1.1, Color(0.85, 1.0, 0.88), 0.18)
		_ring(at, nr * 1.5, UPGRADE_COLOR, 0.3, 6.0)
		_sparkles(at, nr, UPGRADE_COLOR, 6)
		_arrow(at + Vector2(0, -nr * 0.4))
		GameAudio.vibrate(40))


# ---------------------------------------------------------------------------
# Shared effects. All short (well under half a second), small (about the
# monster's own size) and drawn in code, so they never hide the jar.

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


## Runs `callback` after `seconds` of game time (paused with the game).
func _after(seconds: float, callback: Callable) -> void:
	if seconds <= 0.0:
		callback.call()
		return
	get_tree().create_timer(seconds, false).timeout.connect(callback)


## Takes a monster out of the jar and leaves a copy of its sprite behind,
## ready to animate. Returns the copy (null if the monster had no sprite).
func _take_out(monster: Monster) -> Sprite2D:
	monster.is_merging = true
	var ghost: Sprite2D = null
	for child in monster.get_children():
		if child is Sprite2D:
			var sprite := child as Sprite2D
			ghost = Sprite2D.new()
			ghost.texture = sprite.texture
			ghost.scale = sprite.scale
			ghost.global_position = monster.global_position
			ghost.rotation = monster.rotation
			add_child(ghost)
			break
	_monsters.remove_child(monster)
	monster.queue_free()
	return ghost


## Merge: after `delay`, a quick squash, a hop up and a shrink to nothing.
func _pop_away(monster: Monster, delay: float) -> void:
	var ghost := _take_out(monster)
	if ghost == null:
		return
	var s := ghost.scale
	var t := ghost.create_tween()
	t.tween_interval(delay)
	t.tween_property(ghost, "scale", Vector2(s.x * 1.2, s.y * 0.8), 0.07) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(ghost, "scale", Vector2(s.x * 0.85, s.y * 1.18), 0.08) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ghost, "position:y", ghost.position.y - 14.0, 0.08)
	t.tween_property(ghost, "scale", Vector2.ZERO, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(ghost, "modulate:a", 0.0, 0.16)
	t.tween_callback(ghost.queue_free)


## Bomb: the monster swells and flashes bright, then is gone.
func _burst_away(monster: Monster) -> void:
	var ghost := _take_out(monster)
	if ghost == null:
		return
	var s := ghost.scale
	var t := ghost.create_tween().set_parallel()
	t.tween_property(ghost, "scale", s * 1.25, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(ghost, "modulate", Color(2.2, 2.0, 1.7, 1.0), 0.08)
	t.chain().tween_property(ghost, "scale", s * 0.2, 0.1).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(ghost, "modulate:a", 0.0, 0.1)
	t.chain().tween_callback(ghost.queue_free)


## A soft, quick flash of light (a glow dot that blooms and fades).
func _flash(at: Vector2, radius: float, color: Color, time: float) -> void:
	var glow := Sprite2D.new()
	glow.texture = _dot_texture
	glow.z_index = 1
	glow.modulate = color
	add_child(glow)
	glow.global_position = at
	var base := radius * 2.0 / _dot_texture.get_width()
	glow.scale = Vector2.ONE * base * 0.5
	var t := glow.create_tween().set_parallel()
	t.tween_property(glow, "scale", Vector2.ONE * base, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(glow, "modulate:a", 0.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(glow.queue_free)


## A thin ring that expands and fades (or, with `inward`, closes in).
func _ring(at: Vector2, radius: float, color: Color, time: float, width: float, inward := false) -> void:
	var ring := Node2D.new()
	ring.z_index = 1
	add_child(ring)
	ring.global_position = at
	var state := {"t": 0.0}
	ring.draw.connect(func() -> void:
		var t: float = state["t"]
		var grow := 1.0 - pow(1.0 - t, 3.0)  # ease out
		var r := lerpf(radius, radius * 0.35, grow) if inward else lerpf(radius * 0.35, radius, grow)
		var a := (1.0 - t) if not inward else minf(1.0, t * 3.0) * (1.0 - t * 0.5)
		ring.draw_arc(Vector2.ZERO, r, 0, TAU, 56, Color(color, a * 0.35), width + 6.0, true)
		ring.draw_arc(Vector2.ZERO, r, 0, TAU, 56, Color(color.lightened(0.35), a), maxf(width * (1.0 - t * 0.6), 1.0), true))
	var tween := ring.create_tween()
	tween.tween_method(func(t: float) -> void:
		state["t"] = t
		ring.queue_redraw(), 0.0, 1.0, time)
	tween.tween_callback(ring.queue_free)


## Short bright streaks shooting out from a point.
func _streaks(at: Vector2, radius: float, color: Color, count: int) -> void:
	var node := Node2D.new()
	node.z_index = 1
	add_child(node)
	node.global_position = at
	var dirs: Array[Vector2] = []
	for i in count:
		dirs.append(Vector2.from_angle(TAU * i / count + randf_range(-0.2, 0.2)))
	var state := {"t": 0.0}
	node.draw.connect(func() -> void:
		var t: float = state["t"]
		var e := 1.0 - pow(1.0 - t, 2.5)
		for d in dirs:
			var a: Vector2 = d * radius * lerpf(0.6, 1.7, e)
			var b: Vector2 = d * radius * lerpf(0.75, 2.0, e)
			node.draw_line(a, b, Color(color, 1.0 - t), lerpf(6.0, 1.5, t), true))
	var tween := node.create_tween()
	tween.tween_method(func(t: float) -> void:
		state["t"] = t
		node.queue_redraw(), 0.0, 1.0, 0.3)
	tween.tween_callback(node.queue_free)


## A few small four-point sparkles that drift up, twinkle and fade.
func _sparkles(at: Vector2, radius: float, color: Color, count: int) -> void:
	for i in count:
		var star := Sparkle.new()
		star.color = color.lightened(0.3)
		star.size = randf_range(7.0, 12.0)
		star.z_index = 1
		add_child(star)
		var angle := -PI / 2.0 + randf_range(-1.3, 1.3)
		star.global_position = at + Vector2.from_angle(angle) * radius * randf_range(0.4, 0.8)
		star.scale = Vector2.ZERO
		var end := star.position + Vector2.from_angle(angle) * radius * 0.6 + Vector2(0, -30)
		var d := randf_range(0.0, 0.08)
		var t := star.create_tween().set_parallel()
		t.tween_property(star, "scale", Vector2.ONE, 0.14).set_delay(d) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(star, "position", end, 0.5).set_delay(d) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(star, "rotation", randf_range(-1.0, 1.0), 0.5).set_delay(d)
		t.tween_property(star, "modulate:a", 0.0, 0.22).set_delay(d + 0.3)
		t.chain().tween_callback(star.queue_free)


## A small green up-arrow that rises and fades (upgrade).
func _arrow(at: Vector2) -> void:
	var node := Node2D.new()
	node.z_index = 1
	add_child(node)
	node.global_position = at
	node.draw.connect(func() -> void:
		var pts := PackedVector2Array([Vector2(0, -22), Vector2(18, -2), Vector2(7, -2),
				Vector2(7, 18), Vector2(-7, 18), Vector2(-7, -2), Vector2(-18, -2)])
		var outline := pts.duplicate()
		outline.append(pts[0])
		node.draw_polyline(outline, Color(0.08, 0.3, 0.15, 0.8), 6.0, true)
		node.draw_colored_polygon(pts, UPGRADE_COLOR.lightened(0.2)))
	node.scale = Vector2(0.4, 0.4)
	var t := node.create_tween().set_parallel()
	t.tween_property(node, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position:y", node.position.y - 60.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate:a", 0.0, 0.25).set_delay(0.35)
	t.chain().tween_callback(node.queue_free)


## A soft white dot, used for flashes and glows.
func _make_soft_circle() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.45, Color(1, 1, 1, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
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


## A small four-point star with a soft glow.
class Sparkle extends Node2D:
	var color := Color.WHITE
	var size := 10.0

	func _draw() -> void:
		var thin := size * 0.26
		var star := PackedVector2Array([
			Vector2(0, -size), Vector2(thin, -thin), Vector2(size, 0), Vector2(thin, thin),
			Vector2(0, size), Vector2(-thin, thin), Vector2(-size, 0), Vector2(-thin, -thin),
		])
		draw_circle(Vector2.ZERO, size * 0.7, Color(color, 0.25))
		draw_colored_polygon(star, color)
		draw_circle(Vector2.ZERO, size * 0.22, Color(1, 1, 1, 0.9))
