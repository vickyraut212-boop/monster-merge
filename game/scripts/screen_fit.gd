extends Node
## Fills the whole screen on any shape of phone or window (the "ScreenFit"
## autoload).
##
## The game is designed on a 720 x 1280 canvas and every position in the code
## uses those numbers. The project stretches with aspect "expand", so a
## taller phone (most are) or a wider window gets a bigger canvas instead of
## black bars. This node keeps the 720 x 1280 design centred in that canvas:
## - The game world (background, jar, monsters, ship, power-up effects) moves
##   by `margin` through the viewport's canvas transform. SpaceBackground
##   paints its picture over the whole screen.
## - Each UI CanvasLayer registered with fit_layer() moves by `margin` too.
##   Full-screen backdrops in it (dims, flashes, the leaderboard background)
##   are stretched to cover the whole screen again, and full-screen holders of
##   design-positioned children keep the 720 x 1280 design size.
## Nothing changes on a screen that is exactly 9:16.

## Emitted after margin changes (and once at start).
signal changed

const DESIGN := Vector2(720, 1280)

## Extra space on each side of the 720 x 1280 design (x: left/right, y: top/bottom).
var margin := Vector2.ZERO
## The whole visible canvas, in design coordinates (starts at -margin).
var screen_rect := Rect2(Vector2.ZERO, DESIGN)

var _layers: Array[CanvasLayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_update)
	_update()


func _update() -> void:
	var size := get_viewport().get_visible_rect().size
	margin = ((size - DESIGN) / 2.0).max(Vector2.ZERO).floor()
	screen_rect = Rect2(-margin, size)
	get_viewport().canvas_transform = Transform2D(0.0, margin)
	_layers = _layers.filter(func(l: CanvasLayer) -> bool: return is_instance_valid(l))
	for layer in _layers:
		_apply(layer)
	changed.emit()


## Keeps this UI layer's design centred and its full-screen backdrops
## covering the screen. Call it once the layer's children are built.
func fit_layer(layer: CanvasLayer) -> void:
	if not _layers.has(layer):
		_layers.append(layer)
	_apply(layer)


func _apply(layer: CanvasLayer) -> void:
	layer.offset = margin
	_fit_children(layer, true)


## Children of the layer itself (parent_is_layer) are sized against the whole
## canvas; children of a design holder against 720 x 1280.
func _fit_children(parent: Node, parent_is_layer: bool) -> void:
	for child in parent.get_children():
		var c := child as Control
		if c == null:
			continue
		var kind := _kind(c)
		match kind:
			"backdrop":
				if parent_is_layer:
					_set_offsets(c, -margin.x, -margin.y, -margin.x, -margin.y)
				else:
					_set_offsets(c, -margin.x, -margin.y, margin.x, margin.y)
			"holder":
				if parent_is_layer:
					_set_offsets(c, 0, 0, -2.0 * margin.x, -2.0 * margin.y)
				_fit_children(c, false)
			"sized_backdrop":
				c.position = -margin
				c.size = DESIGN + 2.0 * margin


## What a control is, decided the first time it is seen (kept in a meta so a
## later screen change treats it the same way).
func _kind(c: Control) -> String:
	if c.has_meta("screen_fit"):
		return c.get_meta("screen_fit")
	var kind := ""
	var full := c.anchor_left == 0.0 and c.anchor_top == 0.0 and c.anchor_right == 1.0 and c.anchor_bottom == 1.0
	if full:
		kind = "backdrop" if (c is ColorRect or c is TextureRect) else "holder"
	elif c.position == Vector2.ZERO and c.size == DESIGN:
		# Sized to the design screen without anchors (the intro's flash and
		# tap blocker): stretch it over the whole screen.
		kind = "sized_backdrop"
	c.set_meta("screen_fit", kind)
	return kind


func _set_offsets(c: Control, left: float, top: float, right: float, bottom: float) -> void:
	c.offset_left = left
	c.offset_top = top
	c.offset_right = right
	c.offset_bottom = bottom
