class_name RewardText
extends RefCounted
## Floating gameplay feedback, kept small and soft so the monsters stay the
## focus:
## - points(): the little "+21" where an ordinary merge happens.
## - message(): one short word for a special moment (NICE!, COMBO x3,
##   SUPER!, WELL DONE!, BONUS +30). Only one message shows at a time: a new
##   one replaces the old.
##
## STYLE: the game's normal font, a soft dark-purple outline and a faint
## shadow. Text fades in with a tiny grow, drifts up and fades out, all in
## under a second.

const OUTLINE := Color(0.2, 0.1, 0.3, 0.9)
const SHADOW := Color(0.05, 0.0, 0.12, 0.3)
const POINTS_SIZE := 26
const MESSAGE_SIZE := 36


## Small score number at a merge.
static func points(parent: Node, at: Vector2, text: String) -> void:
	var root := _make(parent, at, text, POINTS_SIZE, Color.WHITE, 8)
	_animate(root, at, 55.0, 0.75)


## One feedback message, kept between the x values in `x_limits` (the jar
## walls). Replaces any message still showing.
static func message(parent: Node, at: Vector2, text: String, color: Color,
		x_limits := Vector2(-INF, INF)) -> void:
	var old: Variant = parent.get_meta("reward_message") if parent.has_meta("reward_message") else null
	if is_instance_valid(old):
		(old as Node).queue_free()
	var root := _make(parent, at, text, MESSAGE_SIZE, color, 9)
	var half: float = (root.get_child(0) as Control).size.x / 2.0
	root.position.x = clampf(at.x, minf(x_limits.x + half, 360.0), maxf(x_limits.y - half, 360.0))
	parent.set_meta("reward_message", root)
	_animate(root, root.position, 40.0, 0.95)


static func _make(parent: Node, at: Vector2, text: String, font_size: int, color: Color, outline: int) -> Node2D:
	var root := Node2D.new()
	root.position = at
	root.z_index = 20
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("shadow_outline_size", outline)
	label.size = label.get_minimum_size() + Vector2(outline * 2, outline)
	label.position = -label.size / 2.0
	root.add_child(label)
	parent.add_child(root)
	return root


## Fade in with a tiny grow, drift up, fade out.
static func _animate(root: Node2D, at: Vector2, rise: float, life: float) -> void:
	root.modulate.a = 0.0
	root.scale = Vector2(0.9, 0.9)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "modulate:a", 1.0, 0.12)
	tween.tween_property(root, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "position:y", at.y - rise, life).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "modulate:a", 0.0, 0.28).set_delay(life - 0.28)
	tween.chain().tween_callback(root.queue_free)
