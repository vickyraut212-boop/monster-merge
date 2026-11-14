class_name Dropper
extends Node2D
## The alien spaceship at the top of the jar, holding the current monster in
## its tractor beam. (The monster after it is shown in the HUD's Next box.)
## It follows the mouse or finger smoothly, shows a dashed aim line down into
## the jar, and drops the monster when the mouse button or finger is released.
##
## SPACESHIP ART
## The ship is vicky's original 3D art (assets/ui/alien_ship.png): the
## rainbow saucer with the little green alien in its glass dome. The beam is
## drawn in code so it can reach down to the held monster. To swap the ship,
## select the Dropper node and drag another PNG into "Ship Texture" in the
## Inspector; "Ship Width" sets how wide it appears. Clearing "Ship Texture"
## falls back to the UFO drawn in code (see _draw_ship).
##
## DROP ORDER (controlled randomness)
## The very first drop of the game is always Tier 1. After that, every drop is
## a weighted random pick between Tier 1 and TierData.MAX_DROP_TIER (Tier 4),
## with a few fairness rules so the order never feels unfair or repetitive:
##   - the same tier never comes more than twice in a row, and Tier 4 never
##     twice in a row;
##   - after three big drops (Tier 3 or 4) in a row, the next one is small;
##   - while the pile reaches close to the danger line, only Tier 1 or 2 drop,
##     so there is always somewhere sensible to put the monster.
## Tiers 5 to 8 never drop; they are only made by merging.
## The rules live in _pick_tier() below.
##
## DIFFICULTY
## difficulty goes from 0 to 1. It stays at 0 for the first WARMUP_TIME
## seconds of play, then rises with the score (reaching 1 at FULL_SCORE), but
## never faster than over RAMP_TIME seconds. As it rises:
##   - bigger tiers drop a little more often (DROP_WEIGHTS_EASY -> _HARD);
##   - monsters leave the beam faster (DROP_SPEED);
##   - the ship reloads a bit sooner (cooldown -> MIN_COOLDOWN);
##   - the beam sways gently from side to side (SWAY_MAX px), so where you
##     release matters; the aim line always shows the true drop point;
##   - the ship gets impatient: if you wait longer than PATIENCE seconds it
##     drops by itself. A ring round the held monster counts down the last
##     PATIENCE_WARNING seconds. PATIENCE is 0 (off) until the warm-up ends.
## All of these numbers are just below.

signal dropped(tier: int, at: Vector2)
signal next_changed(tier: int)

## How far above the jar's rim the waiting monster hangs.
## (The height follows the jar, so moving the jar moves the ship too.)
@export var hold_above_rim := 150.0
## Seconds between drops.
@export var cooldown := 0.6
## How quickly the monster catches up with the pointer (higher = snappier).
@export var follow_speed := 18.0
@export var aim_line_color := Color(1, 1, 1, 0.35)

@export_group("Spaceship")
## Your spaceship PNG. Leave empty to use the drawn UFO.
@export var ship_texture: Texture2D = preload("res://assets/ui/alien_ship.png")
## How wide the ship appears, in pixels.
@export var ship_width := 224.0
## How far above the held monster the middle of the ship floats.
@export var ship_height_above := 98.0
## How much the ship leans into its movement (0 = no lean).
@export var ship_lean := 0.0006
## Largest lean in radians (0.15 is about 9 degrees).
@export var ship_max_lean := 0.15

@export_subgroup("Colours")
@export var outline_color := Color(0.12, 0.1, 0.16)
@export var dome_color := Color(0.62, 0.95, 0.92)
@export var alien_color := Color(0.45, 0.92, 0.72)
@export var rim_color := Color(0.6, 0.78, 1.0)
@export var band_colors: Array[Color] = [
	Color(1.0, 0.86, 0.45), Color(1.0, 0.6, 0.42), Color(1.0, 0.86, 0.45),
	Color(1.0, 0.6, 0.42), Color(1.0, 0.86, 0.45),
]
@export var underside_color := Color(0.98, 0.5, 0.88)
@export var underside_center_color := Color(1.0, 0.84, 0.92)
@export var ring_color := Color(0.66, 0.88, 0.5)
@export var light_color := Color(0.62, 0.82, 1.0)
## Beam glow: strong just under the ship, fading out towards the monster.
@export var beam_color := Color(0.7, 1.0, 0.88, 0.5)
@export var sparkle_color := Color(1.0, 0.92, 0.3)

## Seconds of play before difficulty starts to rise.
const WARMUP_TIME := 25.0
## Score at which difficulty reaches its maximum...
const FULL_SCORE := 3000.0
## ...but it never climbs from 0 to 1 faster than this many seconds.
const RAMP_TIME := 180.0
## Chance weights for Tier 1, 2, 3, 4 at difficulty 0 and at difficulty 1.
const DROP_WEIGHTS_EASY: Array[float] = [34.0, 30.0, 24.0, 12.0]
const DROP_WEIGHTS_HARD: Array[float] = [24.0, 26.0, 27.0, 23.0]
## Downward speed a monster leaves the beam with (px/s), easy -> hard.
const DROP_SPEED := Vector2(0.0, 420.0)
## Shortest gap between drops at full difficulty (the export cooldown is the
## gap at difficulty 0).
const MIN_COOLDOWN := 0.42
## How far the beam sways sideways at full difficulty (px).
const SWAY_MAX := 16.0
## Seconds the ship waits before dropping by itself, just after the warm-up
## (x) and at full difficulty (y).
const PATIENCE := Vector2(9.0, 5.0)
## The countdown ring shows for this many seconds before an auto-drop.
const PATIENCE_WARNING := 2.5
## If the top of the pile is closer than this to the danger line, only
## Tier 1 or 2 are picked.
const CROWDED_MARGIN := 150.0

var enabled := true
var current_tier := 1
var next_tier := 1
## 0 = opening (easy) ... 1 = hardest. See DIFFICULTY above.
var difficulty := 0.0
## Score so far (main.gd keeps it up to date).
var score := 0

var _play_time := 0.0
var _history: Array[int] = []
var _idle := 0.0
var _sway := 0.0
var _ship_lift := 0.0

var _jar: Jar
var _held: BlinkSprite
var _cooldown_left := 0.0
var _target_x := 360.0
var _time := 0.0
var _lean := 0.0
var _last_x := 0.0


func _ready() -> void:
	_held = BlinkSprite.new()
	add_child(_held)


## Called once by main.gd when the game starts.
func setup(jar: Jar) -> void:
	_jar = jar
	_target_x = jar.get_inner_rect().get_center().x
	position = Vector2(_target_x, jar.inner_top - hold_above_rim)
	current_tier = 1  # the first drop of every game is Tier 1
	next_tier = _pick_tier()
	_refresh_held()
	next_changed.emit(next_tier)


## Every drop after the first: a weighted pick from Tier 1 to MAX_DROP_TIER,
## with the fairness rules described at the top of this file.
func _pick_tier() -> int:
	var count := TierData.MAX_DROP_TIER
	var weights: Array[float] = []
	for i in count:
		var easy: float = DROP_WEIGHTS_EASY[mini(i, DROP_WEIGHTS_EASY.size() - 1)]
		var hard: float = DROP_WEIGHTS_HARD[mini(i, DROP_WEIGHTS_HARD.size() - 1)]
		weights.append(lerpf(easy, hard, difficulty))
	# The tier that will be dropped just before this one counts as history too.
	var recent: Array[int] = _history.duplicate()
	recent.append(current_tier)
	var n := recent.size()
	# No tier more than twice in a row.
	if n >= 2 and recent[n - 1] == recent[n - 2]:
		weights[recent[n - 1] - 1] = 0.0
	# Never two Tier 4s (the biggest drop) back to back.
	if recent[n - 1] == count:
		weights[count - 1] = 0.0
	# After three big drops in a row, give a small one.
	if n >= 3 and recent[n - 1] >= 3 and recent[n - 2] >= 3 and recent[n - 3] >= 3:
		for i in range(2, count):
			weights[i] = 0.0
	# Pile close to the top: only small monsters, so there is always room.
	if _is_crowded():
		for i in range(2, count):
			weights[i] = 0.0
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return 1
	var roll := randf() * total
	for i in count:
		roll -= weights[i]
		if roll < 0.0:
			return i + 1
	return 1


## True while a settled monster reaches within CROWDED_MARGIN of the danger
## line (monsters still falling from the ship don't count).
func _is_crowded() -> bool:
	if _jar == null:
		return false
	var limit := _jar.inner_top + CROWDED_MARGIN
	for node in get_tree().get_nodes_in_group("monsters"):
		var monster := node as Monster
		if monster == null or monster.linear_velocity.y > 120.0:
			continue
		if monster.global_position.y - TierData.get_radius(monster.tier) < limit:
			return true
	return false


func _update_difficulty(delta: float) -> void:
	_play_time += delta
	if _play_time < WARMUP_TIME:
		difficulty = 0.0
		return
	var by_score := clampf(score / FULL_SCORE, 0.0, 1.0)
	var by_time := clampf((_play_time - WARMUP_TIME) / RAMP_TIME, 0.0, 1.0)
	# Smoothstep so the change creeps in rather than jumping.
	difficulty = smoothstep(0.0, 1.0, minf(by_score, by_time))


## Seconds before the ship drops by itself (0 = never, during the warm-up).
func _patience() -> float:
	if _play_time < WARMUP_TIME:
		return 0.0
	return lerpf(PATIENCE.x, PATIENCE.y, difficulty)


## The beam's current sideways sway (px).
func _sway_offset() -> float:
	return sin(_time * 1.7) * 0.7 * SWAY_MAX * difficulty + sin(_time * 2.9 + 1.3) * 0.3 * SWAY_MAX * difficulty


func _process(delta: float) -> void:
	if _jar == null:
		return
	_time += delta
	if enabled:
		_target_x = get_global_mouse_position().x
		_update_difficulty(delta)
		# The ship gets impatient once the warm-up is over.
		if _cooldown_left <= 0.0 and _patience() > 0.0:
			_idle += delta
			if _idle >= _patience():
				_drop()
	# Smoothly glide towards the pointer (plus the gentle beam sway).
	_sway = _sway_offset()
	position.x = lerpf(position.x, _clamped_target_x(), 1.0 - exp(-follow_speed * delta))
	# Big held monsters push the ship up a little so it never overlaps them.
	var lift := maxf(0.0, TierData.get_radius(current_tier) + 52.0 - ship_height_above)
	_ship_lift = lerpf(_ship_lift, lift, 1.0 - exp(-10.0 * delta))
	_held.position.x = _drop_point().x - global_position.x
	# Lean the ship into its movement, like it is flying sideways.
	var speed := (position.x - _last_x) / maxf(delta, 0.0001)
	_last_x = position.x
	_lean = lerpf(_lean, clampf(speed * ship_lean, -ship_max_lean, ship_max_lean), 1.0 - exp(-10.0 * delta))

	if _cooldown_left > 0.0:
		_cooldown_left -= delta
		if _cooldown_left <= 0.0:
			_held.visible = enabled
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or _jar == null:
		return
	# Releasing the mouse button or lifting a finger drops the monster.
	var click := event as InputEventMouseButton
	if click and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		_target_x = click.position.x
		_drop()


func _drop() -> void:
	if _cooldown_left > 0.0:
		return
	position.x = _clamped_target_x()
	dropped.emit(current_tier, _drop_point())
	GameAudio.play("drop", randf_range(0.95, 1.05))

	_history.append(current_tier)
	if _history.size() > 4:
		_history.pop_front()
	_idle = 0.0
	current_tier = next_tier
	next_tier = _pick_tier()
	next_changed.emit(next_tier)
	_refresh_held()
	_held.visible = false
	_cooldown_left = lerpf(cooldown, MIN_COOLDOWN, difficulty)


## Where the held monster is right now (the ship's spot plus the beam sway,
## kept inside the jar walls).
func _drop_point() -> Vector2:
	var inner := _jar.get_inner_rect()
	var radius := TierData.get_radius(current_tier)
	var x := clampf(global_position.x + _sway, inner.position.x + radius, inner.end.x - radius)
	return Vector2(x, global_position.y)


## Downward speed for a monster leaving the beam right now.
func drop_speed() -> float:
	return lerpf(DROP_SPEED.x, DROP_SPEED.y, difficulty)


## Pauses dropping while a power-up waits for the player to tap a monster
## (the ship stays where it is and keeps hold of its monster).
func set_paused(paused: bool) -> void:
	if _held == null or (paused == not enabled):
		return
	enabled = not paused
	_idle = 0.0  # the patience countdown starts again after a power-up
	if enabled and _cooldown_left <= 0.0:
		_held.visible = true


func stop() -> void:
	enabled = false
	_held.visible = false
	queue_redraw()


func _refresh_held() -> void:
	_held.set_tier(current_tier)


func _clamped_target_x() -> float:
	var inner := _jar.get_inner_rect()
	var radius := TierData.get_radius(current_tier)
	return clampf(_target_x, inner.position.x + radius, inner.end.x - radius)


func _draw() -> void:
	if _jar == null:
		return
	var ship_y := -ship_height_above - _ship_lift + sin(_time * 3.0) * 3.0  # gentle hover
	var held_x := _held.position.x
	if _held.visible:
		var radius := TierData.get_radius(current_tier)
		var bottom := _jar.get_floor_y() - position.y
		draw_dashed_line(Vector2(held_x, radius + 6.0), Vector2(held_x, bottom), aim_line_color, 3.0, 14.0)
		_draw_beam(ship_y, radius, held_x)
		_draw_patience(radius, held_x)
	# Everything below is drawn around the ship's centre, tilted by its lean.
	draw_set_transform(Vector2(0, ship_y), _lean, Vector2.ONE)
	_draw_ship()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Tractor beam shining down from the ship around the held monster.
func _draw_beam(ship_y: float, radius: float, held_x := 0.0) -> void:
	var top_y := ship_y + ship_width * 0.17
	var top_half := ship_width * 0.13
	var bottom_y := radius + 14.0
	var bottom_half := radius + 18.0
	var left_top := Vector2(-top_half, top_y)
	var right_top := Vector2(top_half, top_y)
	var left_bottom := Vector2(held_x - bottom_half, bottom_y)
	var right_bottom := Vector2(held_x + bottom_half, bottom_y)
	# Soft glow: full colour at the ship, fading to almost clear at the bottom,
	# so it reads as light rather than a solid grey shape.
	var faded := Color(beam_color, beam_color.a * 0.08)
	draw_polygon(PackedVector2Array([left_top, right_top, right_bottom, left_bottom]),
			PackedColorArray([beam_color, beam_color, faded, faded]))
	var edge := Color(beam_color.lightened(0.4), beam_color.a * 0.7)
	draw_line(left_top, left_bottom, edge, 2.0, true)
	draw_line(right_top, right_bottom, edge, 2.0, true)
	# A few short streaks inside the beam.
	for k in [-0.55, -0.3, 0.3, 0.55]:
		var t := fmod(_time * 0.8 + absf(k), 1.0)
		var a := left_top.lerp(right_top, 0.5 + k * 0.5).lerp(left_bottom.lerp(right_bottom, 0.5 + k * 0.5), t * 0.6)
		var b := left_top.lerp(right_top, 0.5 + k * 0.5).lerp(left_bottom.lerp(right_bottom, 0.5 + k * 0.5), t * 0.6 + 0.15)
		draw_line(a, b, Color(1, 1, 1, 0.45 * (1.0 - t)), 2.0, true)


## Countdown ring round the held monster in the last PATIENCE_WARNING seconds
## before the ship drops by itself.
func _draw_patience(radius: float, held_x: float) -> void:
	var patience := _patience()
	if patience <= 0.0 or not enabled:
		return
	var left := patience - _idle
	if left > PATIENCE_WARNING:
		return
	var t := clampf(left / PATIENCE_WARNING, 0.0, 1.0)
	var fade := clampf((PATIENCE_WARNING - left) / 0.3, 0.0, 1.0)
	var color := Color(1.0, 0.85, 0.4).lerp(Color(1.0, 0.36, 0.45), 1.0 - t)
	var center := Vector2(held_x, 0)
	var r := radius + 10.0
	draw_arc(center, r, 0, TAU, 48, Color(0.1, 0.05, 0.2, 0.35 * fade), 7.0, true)
	draw_arc(center, r, -PI / 2.0, -PI / 2.0 + TAU * t, 48, Color(color, 0.95 * fade), 4.0, true)


## The UFO, drawn around (0, 0) = the middle of the saucer.
func _draw_ship() -> void:
	if ship_texture:
		var tex_size := ship_texture.get_size()
		var draw_size := tex_size * (ship_width / tex_size.x)
		draw_texture_rect(ship_texture, Rect2(-draw_size / 2.0, draw_size), false)
		return

	var hw := ship_width / 2.0   # half width of the saucer
	var ry := ship_width * 0.12  # half height of the saucer
	var line := 3.0

	# Ring and light under the saucer (behind everything else).
	var ring_c := Vector2(0, ry * 1.15)
	_fill_ellipse(ring_c, hw * 0.42, ry * 0.5, ring_color)
	_outline_ellipse(ring_c, hw * 0.42, ry * 0.5, line)
	_fill_ellipse(ring_c + Vector2(0, ry * 0.12), hw * 0.28, ry * 0.28, light_color)
	_outline_ellipse(ring_c + Vector2(0, ry * 0.12), hw * 0.28, ry * 0.28, 2.0)

	# Glass dome with the little alien inside.
	var dome_r := hw * 0.38
	var dome_c := Vector2(0, -ry * 0.9)
	draw_circle(dome_c, dome_r, dome_color)
	_draw_alien(dome_c + Vector2(0, -dome_r * 0.3), dome_r * 0.45)
	draw_arc(dome_c, dome_r - 6.0, deg_to_rad(205), deg_to_rad(245), 10, Color(1, 1, 1, 0.8), 3.0, true)
	draw_arc(dome_c, dome_r, PI, TAU, 32, outline_color, line, true)

	# Saucer: rainbow panels on top, pink underside.
	var lower := _ellipse_points(Vector2.ZERO, hw, ry, 0.0, PI, 24)
	draw_colored_polygon(lower, underside_color)
	var center_panel := PackedVector2Array()
	var panel_half := hw * 0.28
	for i in 9:
		var x := lerpf(panel_half, -panel_half, i / 8.0)
		center_panel.append(Vector2(x, _ellipse_y(x, hw, ry)))
	center_panel.append(Vector2(-panel_half, 0))
	center_panel.append(Vector2(panel_half, 0))
	draw_colored_polygon(center_panel, underside_center_color)

	var slices := band_colors.size()
	for i in slices:
		var x0 := lerpf(-hw, hw, float(i) / slices)
		var x1 := lerpf(-hw, hw, float(i + 1) / slices)
		var panel := PackedVector2Array()
		for k in 7:
			var x := lerpf(x0, x1, k / 6.0)
			panel.append(Vector2(x, -_ellipse_y(x, hw, ry)))
		# Skip corner points that sit on the saucer's tip (would repeat a point).
		if absf(panel[panel.size() - 1].y) > 0.01:
			panel.append(Vector2(x1, 0))
		if absf(panel[0].y) > 0.01:
			panel.append(Vector2(x0, 0))
		draw_colored_polygon(panel, band_colors[i])
		if i > 0:
			draw_line(Vector2(x0, -_ellipse_y(x0, hw, ry)), Vector2(x0, 0), outline_color, 2.0, true)
	draw_line(Vector2(-hw, 0), Vector2(hw, 0), outline_color, 2.0, true)
	draw_line(Vector2(-panel_half, 0), Vector2(-panel_half, _ellipse_y(panel_half, hw, ry)), outline_color, 2.0, true)
	draw_line(Vector2(panel_half, 0), Vector2(panel_half, _ellipse_y(panel_half, hw, ry)), outline_color, 2.0, true)
	_outline_ellipse(Vector2.ZERO, hw, ry, line)

	# Blue rim at the base of the dome, with the alien's hands resting on it.
	var rim_c := Vector2(0, -ry * 0.72)
	_fill_ellipse(rim_c, hw * 0.55, ry * 0.32, rim_color)
	_outline_ellipse(rim_c, hw * 0.55, ry * 0.32, 2.0)
	for side in [-1.0, 1.0]:
		var hand := rim_c + Vector2(side * dome_r * 0.5, -ry * 0.2)
		draw_circle(hand, 4.5, alien_color)
		draw_arc(hand, 4.5, 0, TAU, 12, outline_color, 2.0, true)

	# Little window dots on the underside.
	for x in [-0.72, -0.6, 0.6, 0.72]:
		draw_circle(Vector2(hw * x, ry * 0.4), 2.2, outline_color)
	draw_circle(Vector2(0, ry * 0.45), 2.2, outline_color)

	# Twinkling sparkles around the ship.
	_draw_sparkle(Vector2(-hw - 6.0, -ry * 2.2), 7.0 + sin(_time * 5.0) * 2.0)
	_draw_sparkle(Vector2(hw + 2.0, -ry * 2.8), 6.0 + sin(_time * 5.0 + 2.0) * 2.0)


func _draw_alien(center: Vector2, head_r: float) -> void:
	# Antennae
	for side in [-1.0, 1.0]:
		var base := center + Vector2(side * head_r * 0.4, -head_r * 0.8)
		var tip := center + Vector2(side * head_r * 0.75, -head_r * 1.45)
		draw_line(base, tip, outline_color, 2.0, true)
		draw_circle(tip, 3.0, alien_color)
		draw_arc(tip, 3.0, 0, TAU, 10, outline_color, 1.5, true)
	draw_circle(center, head_r, alien_color)
	draw_arc(center, head_r, 0, TAU, 24, outline_color, 2.0, true)
	# Eyes with a shine, and a small smile.
	for side in [-1.0, 1.0]:
		var eye := center + Vector2(side * head_r * 0.42, -head_r * 0.05)
		draw_circle(eye, head_r * 0.26, outline_color)
		draw_circle(eye + Vector2(-1.0, -1.2), head_r * 0.09, Color.WHITE)
	draw_arc(center + Vector2(0, head_r * 0.2), head_r * 0.18, deg_to_rad(20), deg_to_rad(160), 8, outline_color, 1.5, true)


func _draw_sparkle(center: Vector2, size: float) -> void:
	var thin := size * 0.28
	var star := PackedVector2Array([
		center + Vector2(0, -size), center + Vector2(thin, -thin),
		center + Vector2(size, 0), center + Vector2(thin, thin),
		center + Vector2(0, size), center + Vector2(-thin, thin),
		center + Vector2(-size, 0), center + Vector2(-thin, -thin),
	])
	draw_colored_polygon(star, sparkle_color)
	star.append(star[0])
	draw_polyline(star, outline_color, 1.5, true)


## Distance from the middle line to the saucer's edge at a given x.
func _ellipse_y(x: float, radius_x: float, radius_y: float) -> float:
	var r := clampf(x / radius_x, -1.0, 1.0)
	return radius_y * sqrt(1.0 - r * r)


func _ellipse_points(center: Vector2, radius_x: float, radius_y: float,
		from_angle: float, to_angle: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var a := lerpf(from_angle, to_angle, float(i) / steps)
		points.append(center + Vector2(cos(a) * radius_x, sin(a) * radius_y))
	return points


func _fill_ellipse(center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	# Stop one step short of a full turn so the first point isn't repeated.
	draw_colored_polygon(_ellipse_points(center, radius_x, radius_y, 0.0, TAU * 31.0 / 32.0, 31), color)


func _outline_ellipse(center: Vector2, radius_x: float, radius_y: float, width: float) -> void:
	draw_polyline(_ellipse_points(center, radius_x, radius_y, 0.0, TAU, 40), outline_color, width, true)
