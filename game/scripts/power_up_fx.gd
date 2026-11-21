class_name PowerUpFx
extends Control
## Living, eye-catching animation for one power-up button (added by hud.gd to
## each of the four buttons). Everything is drawn in code; the button art is
## never changed, only scaled and lit.
##
## READY (has its use)
## - Breathing: the button swells and settles in a slow rhythm, each button a
##   little out of step with the others so the row feels alive.
## - Aura: a soft glow in the power-up's own colour pulses behind the button,
##   with two tiny sparkles orbiting its rim.
## - Shine: every few seconds a glossy light sweep crosses the icon (the four
##   buttons take turns) and the "1" bubble gives a little hop.
## PRESSED
## - A rubbery punch (squash in, overshoot out), a flash, a shockwave ring and
##   a burst of star sparkles and light streaks in the power-up's colour.
## TARGETING (Bomb / Upgrade waiting for a tap on a monster)
## - Faster, bigger heartbeat, a brighter aura and a spinning dashed ring, so
##   it is obvious which power-up is armed.
## READY AGAIN (cooldown over)
## - A golden burst, a big bounce and a "READY!" tag that pops up and floats
##   away.
## COOLING DOWN
## - All of the above rests (the cooldown ring and dimmed icon in hud.gd take
##   over), so ready buttons stand out.
##
## The Shake button's own wobble (shaker.gd) uses rotation, which this never
## touches.

## Glow and burst colour per power-up.
const COLORS := {
	"merge": Color(1.0, 0.42, 0.86),
	"bomb": Color(1.0, 0.58, 0.18),
	"upgrade": Color(0.42, 0.95, 0.42),
	"battery": Color(0.72, 0.52, 1.0),
}
const GOLD := Color(1.0, 0.85, 0.35)

const BREATH_SPEED := 2.6  # radians per second (about 2.4 s per breath)
const BREATH_AMOUNT := 0.045
const ACTIVE_BEAT_SPEED := 9.0
const ACTIVE_BEAT_AMOUNT := 0.085
const SHINE_EVERY := 4.5  # seconds between light sweeps on one button
const SHINE_TIME := 0.6

var button: TextureButton
var color := Color.WHITE
## Whether the power-up has its use (false while cooling down).
var is_ready := true
## Armed and waiting for a tap (Bomb / Upgrade).
var active := false
## Punch scale, tweened by press() / celebrate(); multiplied with the breath.
var punch := 1.0

var _phase := 0.0
var _t := 0.0
var _life := 1.0  # eases to 1 when ready, 0 when cooling
var _active_amt := 0.0
var _next_shine := 0.0
var _front: Front
var _punch_tween: Tween


## Adds the effect to a power-up button. `index` staggers the rhythm.
static func attach(target: TextureButton, power_up: String, index: int) -> PowerUpFx:
	var fx := PowerUpFx.new()
	fx.name = "Fx"
	fx.button = target
	fx.color = COLORS.get(power_up, Color.WHITE)
	fx._phase = index * 1.35
	fx._next_shine = 1.2 + index * (SHINE_EVERY / 4.0)
	target.add_child(fx)
	return fx


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true  # the aura sits behind the button art
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_front = Front.new()
	_front.fx = self
	button.add_child.call_deferred(_front)
	_ensure_material()


func _process(delta: float) -> void:
	_t += delta
	_life = move_toward(_life, 1.0 if is_ready else 0.0, delta * 2.5)
	_active_amt = move_toward(_active_amt, 1.0 if active else 0.0, delta * 5.0)

	var breath := 1.0 + BREATH_AMOUNT * _life * (1.0 - _active_amt) * sin(_t * BREATH_SPEED + _phase)
	var beat := pow(maxf(sin(_t * ACTIVE_BEAT_SPEED), 0.0), 3.0)
	breath += ACTIVE_BEAT_AMOUNT * _active_amt * beat
	button.pivot_offset = button.size / 2.0
	button.scale = Vector2.ONE * punch * breath

	if is_ready and not active and _t >= _next_shine:
		_next_shine = _t + SHINE_EVERY + randf_range(-0.4, 0.4)
		shine()
	queue_redraw()
	_front.queue_redraw()


## Glow behind the button: layered soft discs in the power-up's colour.
func _draw() -> void:
	var a := _life * (0.55 + 0.25 * sin(_t * BREATH_SPEED + _phase)) + _active_amt * 0.45
	if a <= 0.01:
		return
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.5
	var glow := color.lerp(Color.WHITE, 0.15)
	for i in 6:
		var k := float(i) / 5.0
		draw_circle(c, r * (1.4 - 0.34 * k), Color(glow, a * (0.07 + 0.11 * k)))


## A glossy light sweep across the icon, and a hop on the "1" bubble.
func shine() -> void:
	var mat := button.material as ShaderMaterial
	if mat:
		var tween := create_tween()
		tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("shine", v),
				-0.5, 1.7, SHINE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func() -> void: mat.set_shader_parameter("shine", -1.0))
	var badge := button.get_node_or_null("Count") as Control
	if badge and badge.visible:
		badge.pivot_offset = badge.size / 2.0
		var hop := badge.create_tween()
		hop.tween_property(badge, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		hop.tween_property(badge, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## The button was tapped. A full burst when the power-up can be used; just a
## soft squeeze when it is cooling down (hud/power_ups add the "no" shake).
func press() -> void:
	if not is_ready:
		_punch([[0.9, 0.06], [1.0, 0.2]])
		return
	_punch([[0.8, 0.07], [1.2, 0.13], [0.96, 0.1], [1.0, 0.16]])
	_burst(color, 1.0)
	shine()


## The cooldown just ended: golden burst, big bounce and a "READY!" tag.
func celebrate() -> void:
	_punch([[1.28, 0.16], [0.94, 0.12], [1.06, 0.1], [1.0, 0.16]])
	_burst(GOLD, 1.25)
	_ready_tag()
	shine()


func _punch(steps: Array) -> void:
	if _punch_tween:
		_punch_tween.kill()
	_punch_tween = create_tween()
	for step in steps:
		_punch_tween.tween_property(self, "punch", float(step[0]), float(step[1])) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Where bursts and tags go: the HUD layer above the buttons' row, so the
## button's own scale doesn't stretch them and the row keeps only buttons.
func _effects_parent() -> Node:
	var row := button.get_parent()
	return row.get_parent() if row else null


## Flash, shockwave and sparkles round the button.
func _burst(tint: Color, strength: float) -> void:
	var holder := _effects_parent()
	if holder == null:
		return
	var burst := Burst.new()
	burst.tint = tint
	burst.strength = strength
	burst.radius = minf(button.size.x, button.size.y) * 0.5
	burst.position = button.global_position + button.size / 2.0
	holder.add_child(burst)


func _ready_tag() -> void:
	var holder := _effects_parent()
	if holder == null:
		return
	var tag := Label.new()
	tag.text = "READY!"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font := load("res://assets/fonts/LilitaOne-Regular.ttf") as Font
	if font:
		tag.add_theme_font_override("font", font)
	tag.add_theme_font_size_override("font_size", 30)
	tag.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	tag.add_theme_color_override("font_outline_color", Color(0.45, 0.15, 0.05))
	tag.add_theme_constant_override("outline_size", 10)
	holder.add_child(tag)
	tag.reset_size()
	var start := button.global_position + Vector2(button.size.x / 2.0 - tag.size.x / 2.0, -tag.size.y * 0.6)
	tag.position = start
	tag.pivot_offset = tag.size / 2.0
	tag.scale = Vector2(0.3, 0.3)
	var t := tag.create_tween()
	t.tween_property(tag, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(tag, "scale", Vector2.ONE, 0.12)
	t.tween_interval(0.45)
	t.set_parallel()
	t.tween_property(tag, "position:y", start.y - 46.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(tag, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(tag.queue_free)


## Makes sure the button has the shared icon shader (dim + shine, hud.gd).
func _ensure_material() -> void:
	if button.material == null:
		var mat := ShaderMaterial.new()
		mat.shader = Hud._dim_shader()
		mat.set_shader_parameter("amount", 0.0)
		button.material = mat
	(button.material as ShaderMaterial).set_shader_parameter("shine", -1.0)


## Drawn on top of the button: orbiting sparkles while ready, and the
## spinning dashed ring while armed.
class Front extends Control:
	var fx: PowerUpFx

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if fx == null:
			return
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.5
		var life := fx._life * (1.0 - fx._active_amt * 0.5)
		if life > 0.01:
			for i in 2:
				var ang := fx._t * 1.4 + fx._phase + PI * i
				var p := c + Vector2.from_angle(ang) * r * 1.04
				var twinkle := 0.6 + 0.4 * sin(fx._t * 7.0 + i * 2.0 + fx._phase)
				_star(p, 7.5 * twinkle, Color(1, 1, 1, 0.95 * life))
		var act := fx._active_amt
		if act > 0.01:
			var rr := r * 1.12
			var segs := 12
			for i in segs:
				var a0 := fx._t * 2.2 + TAU * i / segs
				draw_arc(c, rr, a0, a0 + TAU / segs * 0.55, 8, Color(fx.color.lerp(Color.WHITE, 0.45), 0.95 * act), 5.0, true)
			draw_arc(c, rr + 7.0, 0, TAU, 64, Color(fx.color, 0.35 * act), 3.0, true)

	func _star(p: Vector2, s: float, col: Color) -> void:
		var thin := s * 0.28
		draw_circle(p, s * 0.9, Color(col, col.a * 0.25))
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(0, -s), p + Vector2(thin, -thin), p + Vector2(s, 0), p + Vector2(thin, thin),
			p + Vector2(0, s), p + Vector2(-thin, thin), p + Vector2(-s, 0), p + Vector2(-thin, -thin),
		]), col)


## One-shot flash + shockwave ring + flying star sparkles and light streaks.
## Removes itself.
class Burst extends Node2D:
	const TIME := 0.7
	var tint := Color.WHITE
	var strength := 1.0
	var radius := 60.0
	var _t := 0.0
	var _sparks: Array = []  # [angle, speed, size, spin]

	func _ready() -> void:
		z_index = 5
		var count := int(12 * strength)
		for i in count:
			var ang := TAU * i / count + randf_range(-0.2, 0.2)
			_sparks.append([ang, randf_range(1.0, 1.9) * radius * strength, randf_range(6.0, 11.0), randf_range(-6.0, 6.0)])

	func _process(delta: float) -> void:
		_t += delta
		if _t >= TIME:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / TIME
		var ease_out := 1.0 - pow(1.0 - k, 3.0)
		var fade := 1.0 - k
		# Flash.
		if k < 0.3:
			draw_circle(Vector2.ZERO, radius * (0.9 + k), Color(1, 1, 1, 0.55 * (1.0 - k / 0.3)))
		# Shockwave: a thick ring and a thin bright one just inside.
		var ring := radius * (1.0 + 1.3 * strength * ease_out)
		draw_arc(Vector2.ZERO, ring, 0, TAU, 64, Color(tint, 0.6 * fade), 10.0 * fade + 1.0, true)
		draw_arc(Vector2.ZERO, ring * 0.9, 0, TAU, 64, Color(1, 1, 1, 0.7 * fade), 3.0 * fade + 0.5, true)
		# Light streaks and stars flying out.
		for s in _sparks:
			var dir := Vector2.from_angle(float(s[0]))
			var dist := radius * 0.8 + float(s[1]) * ease_out
			var p := dir * dist
			draw_line(p - dir * 26.0 * fade, p, Color(tint.lerp(Color.WHITE, 0.4), 0.8 * fade), 4.0 * fade + 0.5, true)
			_star(p, float(s[2]) * (0.5 + fade), float(s[3]) * _t, Color(tint.lerp(Color.WHITE, 0.6), fade))

	func _star(p: Vector2, s: float, spin: float, col: Color) -> void:
		var thin := s * 0.3
		var pts := PackedVector2Array()
		for i in 8:
			var rad := s if i % 2 == 0 else thin
			pts.append(p + Vector2.from_angle(spin + TAU * i / 8.0) * rad)
		draw_circle(p, s * 0.8, Color(col, col.a * 0.3))
		draw_colored_polygon(pts, col)
