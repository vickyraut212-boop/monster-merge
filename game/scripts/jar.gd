class_name Jar
extends Node2D
## The jar the monsters fall into: left wall, right wall, floor, and the
## danger line across its open top. If any monster stays above the danger line
## for game_over_delay seconds, the jar emits game_over.
##
## All sizes are in screen pixels (the screen is 720 x 1280).

signal game_over

## LOOK (drawn in code, following vicky's U-shaped glass container art)
## A thick glowing glass U open at the top that stretches right across the
## screen, edge to edge: a bright OUTER tube hugging the screen sides, and a
## thinner INNER glass line just inside it. The red dashed game-over line runs
## across the open top. The outer tube is drawn over the monsters; everything
## else is drawn behind them.
##
## The invisible walls the monsters bump into sit just inside the glass, so
## the monsters can use the full width of the screen. The bottom corners have
## curved colliders that follow the rounded glass.

## Inside of the jar (the space monsters can occupy) = inside the glass.
## inner_left centres it: (720 - inner_width) / 2.
## The rim (and the danger line) is at y 517; the floor at
## inner_top + inner_height = 1010.
@export var inner_left := 18.0
@export var inner_top := 517.0
@export var inner_width := 684.0
@export var inner_height := 493.0

## How thick the invisible walls are (they collide but are not drawn).
@export var wall_thickness := 24.0

@export_group("Glass")
## Outer tube: its distance from the screen sides, how far it reaches below
## the floor, how round its bottom corners are, and how thick it is.
@export var outer_margin := 5.0
@export var outer_below_floor := 13.0
@export var outer_corner := 100.0
@export var outer_width := 14.0
## Inner glass line: how thick it is and how far below the rim it starts.
## It follows the outer tube's corners.
@export var inner_tube_width := 6.0
@export var inner_tube_top := 6.0
@export var outer_top_color := Color(0.7, 0.94, 1.0, 0.95)
@export var outer_bottom_color := Color(0.66, 0.64, 1.0, 0.95)
@export var glow_color := Color(0.5, 0.78, 1.0, 0.36)
@export var inner_tube_color := Color(0.78, 0.88, 1.0, 0.32)
@export var glass_fill := Color(0.78, 0.86, 1.0, 0.05)
@export var shine_color := Color(1.0, 1.0, 1.0, 0.12)

## How far below the rim the danger line sits (0 = right across the top).
@export var danger_line_offset := 0.0

## Seconds a monster may stay above the danger line before game over.
@export var game_over_delay := 2.0

## Surface feel: friction (0 = ice, 1 = grippy) and bounce (0 = none, 1 = full).
@export var wall_friction := 0.6
@export var wall_bounce := 0.05

@export_group("")
## The dashed line: soft pink normally, bright red while a monster is above it.
@export var line_color := Color(1.0, 0.62, 0.74, 0.85)
@export var danger_color := Color(1.0, 0.3, 0.38)

const SCREEN_WIDTH := 720.0

var _danger_zone: Area2D
## How long each monster (by instance id) has been above the danger line.
var _time_above_line := {}
var _in_danger := false
var _is_over := false
## Draws the outer tube over the monsters.
var _front: Node2D


func _ready() -> void:
	_build_walls()
	_build_danger_zone()
	_front = Node2D.new()
	_front.name = "FrontGlass"
	_front.z_index = 1
	_front.draw.connect(_draw_front)
	add_child(_front)
	queue_redraw()


## The inside of the jar as a rectangle.
func get_inner_rect() -> Rect2:
	return Rect2(inner_left, inner_top, inner_width, inner_height)


func get_floor_y() -> float:
	return inner_top + inner_height


func get_danger_y() -> float:
	return inner_top + danger_line_offset


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	var surface := PhysicsMaterial.new()
	surface.friction = wall_friction
	surface.bounce = wall_bounce
	walls.physics_material_override = surface
	add_child(walls)

	var t := wall_thickness
	var right := inner_left + inner_width
	var floor_y := get_floor_y()
	# Side walls reach up to the top of the screen (invisible above the rim)
	# so a bouncing monster can never fly out of the jar.
	_add_wall(walls, Rect2(inner_left - t, 0.0, t, floor_y + t))
	_add_wall(walls, Rect2(right, 0.0, t, floor_y + t))
	_add_wall(walls, Rect2(inner_left - t, floor_y, inner_width + t * 2.0, t))
	# Fill the bottom corners so monsters roll along the rounded glass
	# instead of sinking into the square corner behind it.
	var r := _inner_corner()
	for side in [-1.0, 1.0]:
		var corner_x: float = inner_left if side < 0.0 else right
		var center := Vector2(corner_x - side * r, floor_y - r)
		var points := PackedVector2Array([Vector2(corner_x, floor_y)])
		for i in 17:
			var a := lerpf(0.0, PI / 2.0, i / 16.0)
			points.append(center + Vector2(side * cos(a), sin(a)) * r)
		var filler := CollisionPolygon2D.new()
		filler.polygon = points
		walls.add_child(filler)


## Radius of the monster space's bottom corners (inside the glass).
func _inner_corner() -> float:
	return outer_corner - (inner_left - outer_margin)


func _add_wall(parent: Node, rect: Rect2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = rect.get_center()
	parent.add_child(collider)


func _build_danger_zone() -> void:
	# Covers the space inside the jar from the danger line up to the top of the screen.
	_danger_zone = Area2D.new()
	_danger_zone.name = "DangerZone"
	_danger_zone.monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(inner_width, get_danger_y())
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(inner_left + inner_width / 2.0, get_danger_y() / 2.0)
	_danger_zone.add_child(collider)
	add_child(_danger_zone)


func _physics_process(delta: float) -> void:
	if _is_over:
		return
	var still_above := {}
	var longest := 0.0
	for body in _danger_zone.get_overlapping_bodies():
		if not _counts_for_danger(body):
			continue
		var id := body.get_instance_id()
		var time_above: float = _time_above_line.get(id, 0.0) + delta
		still_above[id] = time_above
		longest = maxf(longest, time_above)
	_time_above_line = still_above

	var in_danger := not still_above.is_empty()
	if in_danger != _in_danger:
		_in_danger = in_danger
		queue_redraw()

	if longest >= game_over_delay:
		_is_over = true
		game_over.emit()


## Only monsters that have been dropped count (not the one held by the dropper).
func _counts_for_danger(body: Node) -> bool:
	if not body.is_in_group("monsters"):
		return false
	if body is RigidBody2D and (body as RigidBody2D).freeze:
		return false
	return true


## Centre line of the outer tube.
func _outer_path() -> PackedVector2Array:
	return _u_path(outer_margin, SCREEN_WIDTH - outer_margin, inner_top,
			get_floor_y() + outer_below_floor, outer_corner)


## Centre line of the thin inner glass line, just inside the outer tube.
func _inner_path() -> PackedVector2Array:
	var inset := outer_width / 2.0 + inner_tube_width / 2.0 + 1.0
	return _u_path(outer_margin + inset, SCREEN_WIDTH - outer_margin - inset, inner_top + inner_tube_top,
			get_floor_y() + outer_below_floor - inset, outer_corner - inset)


## Faint glass tint, the shine, the inner glass line and the dashed line,
## behind the monsters.
func _draw() -> void:
	var outer := _outer_path()
	var inner := _inner_path()

	# A very faint tint over the whole inside, so it reads as glass.
	draw_colored_polygon(outer, glass_fill)

	# Shine: a diagonal glare in the top-left corner of the glass...
	var top := inner_top
	var l := outer_margin + outer_width
	draw_colored_polygon(PackedVector2Array([
		Vector2(l, top + 40.0), Vector2(l + 70.0, top),
		Vector2(l + 110.0, top), Vector2(l, top + 120.0),
	]), shine_color)
	# ...and a broad faint glare across the bottom right.
	var br := Vector2(SCREEN_WIDTH - outer_margin, get_floor_y() + outer_below_floor)
	draw_colored_polygon(PackedVector2Array([
		br + Vector2(-290, -30), br + Vector2(-80, -330), br + Vector2(-30, -290), br + Vector2(-220, -15),
	]), Color(1, 1, 1, 0.045))

	# Thin inner glass line, hugging the outer tube.
	_tube(self, inner, inner_tube_width, inner_tube_color, inner_tube_color, 0.7)

	# The game-over line across the open top.
	var y := get_danger_y()
	var color := danger_color if _in_danger else line_color
	draw_dashed_line(Vector2(outer_margin, y), Vector2(SCREEN_WIDTH - outer_margin, y), color, 5.0, 20.0, true, true)


## The outer tube, over the monsters.
func _draw_front() -> void:
	_tube(_front, _outer_path(), outer_width, outer_top_color, outer_bottom_color, 1.0)


## A glass tube along `path`: wide soft glow, a coloured body that shades
## from top_color to bottom_color, a darker rim, and bright highlights running
## along it. `strength` fades the whole tube.
func _tube(canvas: CanvasItem, path: PackedVector2Array, width: float,
		top_color: Color, bottom_color: Color, strength: float) -> void:
	var top := path[0].y
	var bottom := top
	for p in path:
		bottom = maxf(bottom, p.y)
	var body := PackedColorArray()
	var rim := PackedColorArray()
	for p in path:
		var t := clampf((p.y - top) / maxf(bottom - top, 1.0), 0.0, 1.0)
		var c := top_color.lerp(bottom_color, t * t)
		body.append(Color(c.lightened(0.25), c.a * strength))
		rim.append(Color(c.darkened(0.2), 0.85 * strength))
	canvas.draw_polyline(path, Color(glow_color, glow_color.a * strength), width + 20.0, true)
	canvas.draw_polyline(path, Color(glow_color, glow_color.a * strength * 1.5), width + 8.0, true)
	canvas.draw_polyline_colors(path, rim, width, true)
	canvas.draw_polyline_colors(path, body, width * 0.55, true)
	# Highlights: a bright line along the inside, a fainter one along the outside.
	canvas.draw_polyline(_offset_path(path, width * 0.2), Color(1, 1, 1, 0.8 * strength), 2.5, true)
	canvas.draw_polyline(_offset_path(path, -width * 0.32), Color(1, 1, 1, 0.3 * strength), 1.5, true)


## A U shape (open at the top) from (left, top) down, round the bottom
## corners, and back up to (right, top).
func _u_path(left: float, right: float, top: float, bottom: float, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(Vector2(left, top))
	var steps := 24
	for i in steps + 1:
		var a := PI - (PI / 2.0) * float(i) / steps  # 180 -> 90 degrees
		points.append(Vector2(left + radius, bottom - radius) + Vector2(cos(a), sin(a)) * radius)
	for i in steps + 1:
		var a := PI / 2.0 - (PI / 2.0) * float(i) / steps  # 90 -> 0 degrees
		points.append(Vector2(right - radius, bottom - radius) + Vector2(cos(a), sin(a)) * radius)
	points.append(Vector2(right, top))
	return points


## Moves every point of a U path towards the inside of the U (negative = out).
func _offset_path(path: PackedVector2Array, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in path.size():
		var prev := path[maxi(i - 1, 0)]
		var next := path[mini(i + 1, path.size() - 1)]
		var dir := (next - prev).normalized()
		# The path runs down, right, then up; (dir.y, -dir.x) points into the U.
		out.append(path[i] + Vector2(dir.y, -dir.x) * amount)
	return out
