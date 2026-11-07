class_name Jar
extends Node2D
## The jar the monsters fall into: left wall, right wall, floor, and the
## danger line near the top. If any monster stays above the danger line for
## GAME_OVER_DELAY seconds, the jar emits game_over.
##
## All sizes are in screen pixels (the screen is 720 x 1280).

signal game_over

## LOOK
## The jar is a glass box seen from slightly above, like vicky's glass
## container art: a front pane with a glowing edge, two side panes going back
## in perspective (their back corners rise above the rim like little fins),
## and a glass floor. It reaches almost to both screen edges. The front pane
## is drawn over the monsters (they are inside the box); everything else is
## drawn behind them.
##
## The invisible walls the monsters bump into sit halfway back along the side
## panes and the floor, so the monsters look like they stand in the middle of
## the box.

## Inside of the jar (the space monsters can occupy).
## inner_left centres it: (720 - inner_width) / 2.
## The rim sits at y 535 (where vicky marked it) so the pile reaches the
## danger line quickly; the floor is at inner_top + inner_height = 1060.
@export var inner_left := 52.0
@export var inner_top := 535.0
@export var inner_width := 616.0
@export var inner_height := 525.0

## How thick the invisible walls are (they collide but are not drawn).
@export var wall_thickness := 24.0

@export_group("Glass box")
## How far the side panes go back, left to right, from the front pane to the
## back corner (the invisible wall is halfway).
@export var depth_x := 90.0
## How much higher the back of the floor is than the front (perspective).
@export var depth_y := 56.0
## How far the back corner fins rise above the front rim.
@export var fin_height := 75.0
@export var glass_fill := Color(0.72, 0.8, 1.0, 0.16)
@export var floor_fill := Color(0.72, 0.8, 1.0, 0.24)
@export var front_fill := Color(0.85, 0.92, 1.0, 0.05)
@export var edge_color := Color(0.88, 0.94, 1.0, 0.9)
@export var glow_color := Color(0.55, 0.75, 1.0, 0.35)
@export var shine_color := Color(1.0, 1.0, 1.0, 0.1)

## How far below the rim the danger line sits.
@export var danger_line_offset := 40.0

## Seconds a monster may stay above the danger line before game over.
@export var game_over_delay := 2.0

## Surface feel: friction (0 = ice, 1 = grippy) and bounce (0 = none, 1 = full).
@export var wall_friction := 0.6
@export var wall_bounce := 0.05

@export_group("")
@export var danger_color := Color(1.0, 0.35, 0.4)

var _danger_zone: Area2D
## How long each monster (by instance id) has been above the danger line.
var _time_above_line := {}
var _in_danger := false
var _is_over := false
## Draws the front pane over the monsters.
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


## Corners of the glass box. "Front" corners are the pane nearest the player;
## "back" corners are where the side panes meet the (open) back.
func _box() -> Dictionary:
	var half := depth_x / 2.0
	var left := inner_left
	var right := inner_left + inner_width
	var floor_y := get_floor_y()
	var lift := depth_y / 2.0
	return {
		"front_tl": Vector2(left - half, inner_top),
		"front_tr": Vector2(right + half, inner_top),
		"front_bl": Vector2(left - half, floor_y + lift),
		"front_br": Vector2(right + half, floor_y + lift),
		"back_tl": Vector2(left + half, inner_top - fin_height),
		"back_tr": Vector2(right - half, inner_top - fin_height),
		"back_bl": Vector2(left + half, floor_y - lift),
		"back_br": Vector2(right - half, floor_y - lift),
	}


## Side panes, floor and danger line, behind the monsters.
func _draw() -> void:
	var b := _box()
	var left_pane := PackedVector2Array([b.front_tl, b.back_tl, b.back_bl, b.front_bl])
	var right_pane := PackedVector2Array([b.back_tr, b.front_tr, b.front_br, b.back_br])
	var floor_pane := PackedVector2Array([b.back_bl, b.back_br, b.front_br, b.front_bl])
	draw_colored_polygon(left_pane, glass_fill)
	draw_colored_polygon(right_pane, glass_fill)
	draw_colored_polygon(floor_pane, floor_fill)
	for edge in [[b.front_tl, b.back_tl], [b.back_tl, b.back_bl], [b.back_bl, b.back_br],
			[b.back_br, b.back_tr], [b.back_tr, b.front_tr]]:
		_glow_line(self, edge[0], edge[1], 2.0)

	var right := inner_left + inner_width
	var line_color := danger_color if _in_danger else Color(danger_color, 0.45)
	var y := get_danger_y()
	draw_dashed_line(Vector2(inner_left, y), Vector2(right, y), line_color, 4.0, 16.0)


## Front pane, over the monsters: a faint tint, a diagonal shine in the top
## left corner, and the glowing outline.
func _draw_front() -> void:
	var b := _box()
	var pane := Rect2(b.front_tl, b.front_br - b.front_tl)
	_front.draw_rect(pane, front_fill)
	var w := pane.size.x
	var shine := PackedVector2Array([
		b.front_tl + Vector2(w * 0.1, 0), b.front_tl + Vector2(w * 0.3, 0),
		b.front_tl + Vector2(0, w * 0.3), b.front_tl + Vector2(0, w * 0.1),
	])
	_front.draw_colored_polygon(shine, shine_color)
	for edge in [[b.front_tl, b.front_tr], [b.front_tr, b.front_br],
			[b.front_br, b.front_bl], [b.front_bl, b.front_tl]]:
		_glow_line(_front, edge[0], edge[1], 3.0)


## A glass edge: wide soft glow underneath, crisp light line on top.
func _glow_line(canvas: CanvasItem, from: Vector2, to: Vector2, width: float) -> void:
	canvas.draw_line(from, to, glow_color, width + 8.0, true)
	canvas.draw_line(from, to, edge_color, width, true)

