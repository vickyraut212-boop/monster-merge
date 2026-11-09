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
## DROP ORDER
## The very first drop of the game is always Tier 1. After that, every drop is
## a random pick between Tier 1 and TierData.MAX_DROP_TIER (Tier 3).
## Tiers 4 to 8 never drop; they are only made by merging.
## The rule lives in _pick_tier() below.

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

var enabled := true
var current_tier := 1
var next_tier := 1

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


## Every drop after the first: random Tier 1, 2 or 3.
func _pick_tier() -> int:
	return randi_range(1, TierData.MAX_DROP_TIER)


func _process(delta: float) -> void:
	if _jar == null:
		return
	_time += delta
	if enabled:
		_target_x = get_global_mouse_position().x
	# Smoothly glide towards the pointer.
	position.x = lerpf(position.x, _clamped_target_x(), 1.0 - exp(-follow_speed * delta))
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
	dropped.emit(current_tier, global_position)
	GameAudio.play("drop", randf_range(0.95, 1.05))

	current_tier = next_tier
	next_tier = _pick_tier()
	next_changed.emit(next_tier)
	_refresh_held()
	_held.visible = false
	_cooldown_left = cooldown


## Pauses dropping while a power-up waits for the player to tap a monster
## (the ship stays where it is and keeps hold of its monster).
func set_paused(paused: bool) -> void:
	if _held == null or (paused == not enabled):
		return
	enabled = not paused
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
	var ship_y := -ship_height_above + sin(_time * 3.0) * 3.0  # gentle hover
	if _held.visible:
		var radius := TierData.get_radius(current_tier)
		var bottom := _jar.get_floor_y() - position.y
		draw_dashed_line(Vector2(0, radius + 6.0), Vector2(0, bottom), aim_line_color, 3.0, 14.0)
		_draw_beam(ship_y, radius)
	# Everything below is drawn around the ship's centre, tilted by its lean.
	draw_set_transform(Vector2(0, ship_y), _lean, Vector2.ONE)
	_draw_ship()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Tractor beam shining down from the ship around the held monster.
func _draw_beam(ship_y: float, radius: float) -> void:
	var top_y := ship_y + ship_width * 0.17
	var top_half := ship_width * 0.13
	var bottom_y := radius + 14.0
	var bottom_half := radius + 18.0
	var left_top := Vector2(-top_half, top_y)
	var right_top := Vector2(top_half, top_y)
	var left_bottom := Vector2(-bottom_half, bottom_y)
	var right_bottom := Vector2(bottom_half, bottom_y)
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
