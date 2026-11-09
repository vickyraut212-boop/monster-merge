extends Control
## The rounded glassy panel under the jar that holds the power-up buttons,
## drawn in code to match vicky's UI reference: a lavender-purple glass slab,
## lighter at the top left and darker at the bottom right, with a soft light
## rim, a shine along its top edge, a drop shadow under it, and a soft shadow
## under each round button so they sit on the glass.
##
## The buttons themselves live in the HUD's PowerUps node (buttons_path).

@export var corner_radius := 46.0
@export var base_color := Color(0.33, 0.23, 0.64, 0.92)
## Glass tint: strongest at the top left, fading out to the bottom right.
@export var light_color := Color(0.6, 0.47, 0.92, 0.6)
@export var dark_color := Color(0.18, 0.11, 0.4, 0.35)
@export var rim_color := Color(0.78, 0.7, 1.0, 0.55)
@export var shine_color := Color(1.0, 1.0, 1.0, 0.28)
@export var shadow_color := Color(0.04, 0.01, 0.12, 0.45)
## The node holding the round buttons (each gets a soft shadow under it).
@export var buttons_path := NodePath("../PowerUps")


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)

	# Drop shadow and the base slab with its light rim.
	var base := StyleBoxFlat.new()
	base.bg_color = base_color
	base.set_corner_radius_all(int(corner_radius))
	base.set_border_width_all(2)
	base.border_color = rim_color
	base.shadow_color = shadow_color
	base.shadow_size = 14
	base.shadow_offset = Vector2(0, 6)
	base.anti_aliasing = true
	draw_style_box(base, rect)

	# Glass tint: a diagonal gradient across the inside of the slab.
	var inner := rect.grow(-2.0)
	var points := _rounded_rect(inner, corner_radius - 2.0)
	var colors := PackedColorArray()
	for p in points:
		var t := clampf((p.x / size.x) * 0.55 + (p.y / size.y) * 0.45, 0.0, 1.0)
		colors.append(light_color.lerp(dark_color, t))
	draw_polygon(points, colors)

	# Inner glow line just inside the rim, and a bright shine along the top.
	draw_polyline(_closed(_rounded_rect(rect.grow(-7.0), corner_radius - 7.0)), Color(1, 1, 1, 0.08), 3.0, true)
	var top := _rounded_rect(rect.grow(-5.0), corner_radius - 5.0)
	var shine := PackedVector2Array()
	for p in top:
		if p.y < size.y * 0.3:
			shine.append(p)
	# The top edge runs from the top-left corner round to the top-right one.
	shine = _sorted_by_x(shine)
	draw_polyline(shine, shine_color, 2.5, true)

	# A soft round shadow under each button.
	var buttons := get_node_or_null(buttons_path) as Control
	if buttons:
		for button in buttons.get_children():
			var b := button as Control
			if b == null:
				continue
			var center := b.get_global_rect().get_center() - get_global_rect().position + Vector2(0, 6)
			var r := b.size.x * 0.47
			for i in 4:
				draw_circle(center, r + i * 3.0, Color(shadow_color, 0.07))


## Points around a rounded rectangle, clockwise from the top-left corner.
func _rounded_rect(r: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners := [
		[r.position + Vector2(radius, radius), PI],
		[Vector2(r.end.x - radius, r.position.y + radius), PI * 1.5],
		[r.end - Vector2(radius, radius), 0.0],
		[Vector2(r.position.x + radius, r.end.y - radius), PI * 0.5],
	]
	var steps := 12
	for c in corners:
		for i in steps + 1:
			var a: float = c[1] + (PI / 2.0) * float(i) / steps
			points.append(c[0] + Vector2(cos(a), sin(a)) * radius)
	return points


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out


func _sorted_by_x(points: PackedVector2Array) -> PackedVector2Array:
	var list := Array(points)
	list.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return PackedVector2Array(list)
