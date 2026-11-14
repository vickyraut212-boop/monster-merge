class_name Intro
extends CanvasLayer
## Animated opening of the game: a grand arcade-style title reveal with one
## lively monster.
##
##   A soft radiant glow and slowly turning light rays fade in
##   -> the green two-eyed monster (Tier 5 art) springs up from the bottom
##      edge of the screen, tumbling a little in the air, lands on its feet
##      with a squash, bounces twice and settles, its body swaying over its
##      planted feet, stepping its feet and blinking
##   -> as it lands the Monster Merge title drops in with a springy overshoot,
##      a bloom of light, twinkling sparkles and a light sweep across the
##      letters; the monster gives a happy hop when the shine passes
##   -> the monster hops away, the title floats off and gameplay fades in.
##
## The movement follows vicky's reference (a bouncy character entrance with
## rotation, squash and stretch and little leg movements); the monster is the
## game's own art, only scaled. Its feet are the bottom strip of the same
## picture, drawn as two separate pieces just behind the body so they can
## step on their own.
##
## It plays on top of the real game scene: the game's own space background
## stays visible the whole time, and the jar, ship and HUD are simply hidden
## until the intro hands over, so there is no loading screen and no jump cut.
## It plays once per launch (not again on "Play again" / Restart).
## Tapping or clicking during the intro skips straight to the hand-over.
##
## Everything here is visual only: no physics, no score, and gameplay code is
## untouched. main.gd starts it with Intro.play_over(self).

signal finished

## Set once the intro has played, so restarting a game skips it.
static var has_played := false

@export_group("Logo")
@export var logo_texture: Texture2D = preload("res://assets/ui/logo.png")
## How wide the logo appears, in pixels (screen is 720 wide).
@export var logo_width := 600.0
## Where the logo's centre sits.
@export var logo_center := Vector2(360, 380)
## Warm glow behind the title (centre colour; it fades out to clear).
@export var glow_color := Color(1.0, 0.7, 0.85, 1.0)
@export var ray_color := Color(1.0, 0.9, 0.7, 0.15)

@export_group("Monster")
## The intro monster's tier art (Tier 5 = the green two-eyed monster).
@export var hero_tier := 5
## How wide it appears, in pixels.
@export var hero_width := 290.0
## Where its feet land.
@export var hero_ground := Vector2(360, 1000)
## Where it springs up from (below the bottom edge of the screen).
@export var hero_start := Vector2(560, 1420)
## Height of its leap above the ground.
@export var jump_height := 330.0

@export_group("Timing (seconds)")
## When the monster leaps in.
@export var leap_delay := 0.35
## Pause on the finished picture before gameplay starts.
@export var hold_time := 1.3
## How long the hand-over to gameplay takes.
@export var transition_time := 0.6

const SCREEN := Vector2(720, 1280)
## The bottom strip of the art that holds the feet (fraction of its height),
## and where the left foot ends and the right one starts (fraction of width).
const FEET_TOP := 0.9375
const FEET_SPLIT := 0.507
const SHINE_SHADER := """
shader_type canvas_item;
uniform float progress = -1.0;
uniform float width = 0.14;
void fragment() {
	vec4 c = COLOR;
	float d = abs((UV.x + (1.0 - UV.y) * 0.35) - progress);
	float s = smoothstep(width, 0.0, d) * 0.6;
	COLOR = vec4(mix(c.rgb, vec3(1.0, 0.98, 0.9), s), c.a);
}
"""

var _main: Node
var _dropper: Dropper
## Gameplay pieces hidden during the intro, and the opacity to restore.
var _hidden: Array[CanvasItem] = []
var _hidden_alpha: Array[float] = []

var _blocker: Control
var _logo: Sprite2D
var _glow: Sprite2D
var _rays: Rays
var _sparkles: Array[Node2D] = []
## The monster: _hero sits at its feet; _lean squashes, tilts and sways it
## around the feet; _body is the picture; _feet are the two feet pieces.
var _hero: Node2D
var _lean: Node2D
var _body: BlinkSprite
var _feet: Array[Sprite2D] = []
var _feet_rest: Array[Vector2] = []
var _hero_height := 0.0
var _shadow: Shadow
## 0 while the monster is in the air; fades to 1 once it has settled, which
## turns on its idle sway, breathing and stepping.
var _alive := 0.0
var _tweens: Array[Tween] = []
var _done := false
var _time := 0.0


## Adds the intro on top of `main` and starts it, unless it already played.
static func play_over(main: Node) -> void:
	if has_played:
		return
	has_played = true
	var intro := Intro.new()
	main.add_child(intro)
	intro._start(main)


func _init() -> void:
	layer = 10  # above the HUD
	process_mode = Node.PROCESS_MODE_ALWAYS


func _start(main: Node) -> void:
	_main = main
	_dropper = main.get_node_or_null("Dropper") as Dropper
	if _dropper:
		_dropper.enabled = false
	for path in ["Jar", "Monsters", "Dropper"]:
		_hide(main.get_node_or_null(path) as CanvasItem)
	var hud := main.get_node_or_null("HUD")
	if hud:
		for child in hud.get_children():
			_hide(child as CanvasItem)

	_build()
	_play()


func _hide(item: CanvasItem) -> void:
	if item == null:
		return
	_hidden.append(item)
	_hidden_alpha.append(item.modulate.a)
	item.modulate.a = 0.0


func _process(delta: float) -> void:
	_time += delta
	if _rays:
		_rays.rotation += delta * 0.09
	# Twinkle: each sparkle swells and fades on its own rhythm.
	for i in _sparkles.size():
		var star := _sparkles[i]
		var k := sin(_time * (2.2 + i * 0.37) + i * 1.9)
		star.scale = Vector2.ONE * pow(maxf(k, 0.0), 2.0) * star.get_meta("size", 1.0)
	_animate_idle()


## Once settled the monster feels alive: its body sways over its planted feet,
## it breathes, and it shifts its weight from foot to foot.
func _animate_idle() -> void:
	if _body == null or _alive <= 0.0:
		return
	var a := _alive
	var sway := sin(_time * 2.6)
	_body.skew = sway * 0.07 * a
	_body.position.x = sway * 3.0 * a
	var breathe := 1.0 + sin(_time * 3.4) * 0.018 * a
	_body.scale = _body.get_meta("base_scale") * Vector2(2.0 - breathe, breathe)
	for i in _feet.size():
		# Each foot lifts a little when the body leans away from it.
		var side := -1.0 if i == 0 else 1.0
		var lift := maxf(0.0, -sway * side) * 7.0 * a
		_feet[i].position = _feet_rest[i] + Vector2(0, -lift)
		_feet[i].rotation = -side * lift * 0.012


# --- Building the picture -------------------------------------------------

func _build() -> void:
	# Catches taps so nothing underneath reacts; a tap skips the intro.
	_blocker = Control.new()
	_blocker.size = SCREEN
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.gui_input.connect(_on_blocker_input)
	add_child(_blocker)

	# Light rays and the radiant glow behind the title.
	_rays = Rays.new()
	_rays.color = ray_color
	_rays.position = logo_center
	_rays.modulate.a = 0.0
	add_child(_rays)
	_glow = Sprite2D.new()
	_glow.texture = _radial_texture(glow_color)
	_glow.position = logo_center
	_glow.modulate.a = 0.0
	add_child(_glow)

	_build_hero()

	# Logo last, so nothing passes in front of it.
	_logo = Sprite2D.new()
	_logo.texture = logo_texture
	_logo.position = logo_center + Vector2(0, -160)
	_logo.scale = Vector2.ZERO
	_logo.modulate.a = 0.0
	var shine := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHINE_SHADER
	shine.shader = shader
	_logo.material = shine
	add_child(_logo)

	# Sparkles round the title.
	var spots: Array[Vector3] = [
		Vector3(-280, -95, 1.2), Vector3(250, -120, 1.0), Vector3(300, 40, 1.3),
		Vector3(-300, 70, 0.9), Vector3(-150, -165, 0.8), Vector3(120, 165, 1.0),
		Vector3(-60, 175, 0.7), Vector3(190, -175, 0.8),
	]
	for spot in spots:
		var star := Sparkle.new()
		star.position = logo_center + Vector2(spot.x, spot.y)
		star.set_meta("size", spot.z)
		star.scale = Vector2.ZERO
		star.modulate.a = 0.0
		add_child(star)
		_sparkles.append(star)


func _build_hero() -> void:
	_shadow = Shadow.new()
	_shadow.position = hero_ground
	_shadow.radius = hero_width * 0.44
	_shadow.modulate.a = 0.0
	add_child(_shadow)

	_hero = Node2D.new()
	_hero.position = hero_start
	add_child(_hero)
	_lean = Node2D.new()
	_hero.add_child(_lean)

	_body = BlinkSprite.new()
	_body.set_tier(hero_tier)
	var tex := _body.texture
	var tex_size := tex.get_size()
	var s := hero_width / tex_size.x
	_hero_height = tex_size.y * s
	# Feet: the bottom strip of the same art, in two pieces, just behind the body.
	var feet_y := tex_size.y * FEET_TOP
	var split := tex_size.x * FEET_SPLIT
	for i in 2:
		var foot := Sprite2D.new()
		foot.texture = TierData.get_texture(hero_tier)
		foot.region_enabled = true
		foot.region_rect = Rect2(0.0, feet_y, split, tex_size.y - feet_y) if i == 0 \
				else Rect2(split, feet_y, tex_size.x - split, tex_size.y - feet_y)
		foot.centered = false
		foot.offset = Vector2(-tex_size.x / 2.0 + (0.0 if i == 0 else split), -(tex_size.y - feet_y))
		foot.scale = Vector2(s, s)
		_lean.add_child(foot)
		_feet.append(foot)
		_feet_rest.append(Vector2.ZERO)
	# Body: everything above the feet, standing on them.
	_body.region_enabled = true
	_body.region_rect = Rect2(0, 0, tex_size.x, feet_y)
	_body.centered = false
	_body.offset = Vector2(-tex_size.x / 2.0, -tex_size.y)
	_body.scale = Vector2(s, s)
	_body.set_meta("base_scale", Vector2(s, s))
	_lean.add_child(_body)


# --- The sequence ----------------------------------------------------------

func _play() -> void:
	var glow_scale := Vector2(960.0, 660.0) / 256.0

	# Glow and rays fade in first, so the stage is lit when the monster arrives.
	var g := _new_tween().set_parallel()
	g.tween_property(_glow, "modulate:a", 0.55, 0.6).set_trans(Tween.TRANS_SINE)
	g.tween_property(_glow, "scale", glow_scale, 0.8).from(glow_scale * 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	g.tween_property(_rays, "modulate:a", 0.6, 0.8).set_delay(0.1).set_trans(Tween.TRANS_SINE)
	g.tween_property(_rays, "scale", Vector2.ONE, 1.4).from(Vector2(0.4, 0.4)).set_delay(0.1) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var landed := _hero_entrance()

	# Title drops in just as the monster touches down.
	var t := _new_tween()
	t.tween_interval(landed - 0.32)
	t.tween_property(_logo, "modulate:a", 1.0, 0.18)
	var logo_scale := Vector2.ONE * (logo_width / logo_texture.get_width())
	t.parallel().tween_property(_logo, "position", logo_center, 0.55) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_logo, "scale", logo_scale * 1.08, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_logo, "rotation", 0.0, 0.55).from(-0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(_title_landed)
	t.tween_property(_logo, "scale", logo_scale * 0.98, 0.14).set_trans(Tween.TRANS_SINE)
	t.tween_property(_logo, "scale", logo_scale, 0.2).set_trans(Tween.TRANS_SINE)
	t.tween_callback(_float_logo)
	t.tween_interval(0.25)
	# Light sweep across the letters, and the monster hops for joy with it.
	t.tween_callback(_happy_hop)
	t.tween_method(func(v: float) -> void: (_logo.material as ShaderMaterial).set_shader_parameter("progress", v),
			-0.3, 1.7, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_interval(hold_time)
	t.tween_callback(_finish)


## The monster springs up from below the screen in an arc, tumbling a little,
## lands on its feet with a squash, bounces twice (smaller each time) and
## settles. Returns the time of the first touch-down.
func _hero_entrance() -> float:
	var ground := hero_ground
	var apex := Vector2(lerpf(hero_start.x, ground.x, 0.6), ground.y - jump_height)
	var rise := 0.42
	var fall := 0.34
	var t := _new_tween()
	t.tween_interval(leap_delay)
	_lean.rotation = 0.6
	_lean.scale = Vector2(0.86, 1.18)
	# Up: decelerating, stretched, unwinding its spin.
	t.tween_property(_hero, "position:y", apex.y, rise).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_hero, "position:x", apex.x, rise).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_lean, "rotation", -0.18, rise).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_lean, "scale", Vector2(1.0, 1.0), rise).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_feet[0], "position", Vector2(-6, -10), rise)
	t.parallel().tween_property(_feet[1], "position", Vector2(6, -4), rise)
	# Down: accelerating, straightening up, feet reaching for the ground.
	t.tween_property(_hero, "position:y", ground.y, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_hero, "position:x", ground.x, fall).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(_lean, "rotation", 0.05, fall).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_lean, "scale", Vector2(0.92, 1.1), fall)
	t.parallel().tween_property(_feet[0], "position", Vector2.ZERO, fall)
	t.parallel().tween_property(_feet[1], "position", Vector2.ZERO, fall)
	t.parallel().tween_property(_shadow, "modulate:a", 1.0, fall)
	t.parallel().tween_property(_shadow, "scale", Vector2.ONE, fall).from(Vector2(0.3, 0.3))
	t.tween_callback(_on_land.bind(1.0))
	# Squash, then two shrinking bounces with alternating tilt.
	t.tween_property(_lean, "scale", Vector2(1.26, 0.76), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_lean, "rotation", 0.0, 0.08)
	t.parallel().tween_property(_feet[0], "position", Vector2(-5, 0), 0.08)
	t.parallel().tween_property(_feet[1], "position", Vector2(5, 0), 0.08)
	for bounce in [[70.0, 0.2, -0.08], [22.0, 0.13, 0.05]]:
		var h: float = bounce[0]
		var d: float = bounce[1]
		var tilt: float = bounce[2]
		t.tween_property(_hero, "position:y", ground.y - h, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(_lean, "scale", Vector2(0.9, 1.12), d * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(_lean, "rotation", tilt, d)
		t.parallel().tween_property(_feet[0], "position", Vector2(-2, -h * 0.1), d)
		t.parallel().tween_property(_feet[1], "position", Vector2(2, -h * 0.05), d)
		t.parallel().tween_property(_shadow, "scale", Vector2.ONE * (1.0 - h / 300.0), d)
		t.tween_property(_hero, "position:y", ground.y, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(_lean, "scale", Vector2(1.0, 1.0), d)
		t.parallel().tween_property(_lean, "rotation", 0.0, d)
		t.parallel().tween_property(_feet[0], "position", Vector2.ZERO, d)
		t.parallel().tween_property(_feet[1], "position", Vector2.ZERO, d)
		t.parallel().tween_property(_shadow, "scale", Vector2.ONE, d)
		t.tween_callback(_on_land.bind(h / 120.0))
		t.tween_property(_lean, "scale", Vector2(1.08 + h / 900.0, 0.93 - h / 1400.0), 0.06)
	# Settle with a soft wobble, blink, and come alive.
	t.tween_property(_lean, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(_body.blink_now)
	t.tween_method(func(v: float) -> void: _alive = v, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	return leap_delay + rise + fall


## Happy hop when the light sweeps across the title.
func _happy_hop() -> void:
	var y := hero_ground.y
	var t := _new_tween()
	t.tween_property(_lean, "scale", Vector2(1.12, 0.88), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_hero, "position:y", y - 48.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_lean, "scale", Vector2(0.92, 1.1), 0.12)
	t.parallel().tween_property(_lean, "rotation", 0.06, 0.18)
	t.parallel().tween_property(_shadow, "scale", Vector2(0.85, 0.85), 0.18)
	t.tween_property(_hero, "position:y", y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_lean, "scale", Vector2.ONE, 0.16)
	t.parallel().tween_property(_lean, "rotation", 0.0, 0.16)
	t.parallel().tween_property(_shadow, "scale", Vector2.ONE, 0.16)
	t.tween_callback(_on_land.bind(0.4))
	t.tween_property(_lean, "scale", Vector2(1.08, 0.93), 0.06)
	t.tween_property(_lean, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(_body.blink_now)


## The title has landed: a bloom of light and the sparkles start to twinkle.
func _title_landed() -> void:
	var glow_scale := _glow.scale
	var t := _new_tween().set_parallel()
	t.tween_property(_glow, "modulate:a", 1.0, 0.12)
	t.tween_property(_rays, "modulate:a", 1.0, 0.3)
	t.tween_property(_glow, "scale", glow_scale * 1.15, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(_glow, "scale", glow_scale, 0.5).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_glow, "modulate:a", 0.85, 0.5)
	t.chain().tween_callback(_breathe_glow.bind(glow_scale))
	for star in _sparkles:
		t.tween_property(star, "modulate:a", 1.0, 0.3)
	GameAudio.play("bonus")


func _breathe_glow(base: Vector2) -> void:
	var t := _new_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_glow, "scale", base * 1.06, 1.3)
	t.parallel().tween_property(_glow, "modulate:a", 1.0, 1.3)
	t.tween_property(_glow, "scale", base, 1.3)
	t.parallel().tween_property(_glow, "modulate:a", 0.8, 1.3)


func _float_logo() -> void:
	var t := _new_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_logo, "position:y", logo_center.y - 8.0, 1.4)
	t.tween_property(_logo, "position:y", logo_center.y + 4.0, 1.4)


## Soft landing thud: harder landings sound deeper and louder.
func _on_land(strength: float) -> void:
	GameAudio.play("drop", lerpf(1.25, 0.8, clampf(strength, 0.0, 1.0)))


# --- Hand-over to gameplay -------------------------------------------------

func _on_blocker_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	_alive = 0.0
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()

	var t := _new_tween().set_parallel()
	# Logo floats up and fades away with its glow, rays and sparkles.
	t.tween_property(_logo, "position:y", _logo.position.y - 70.0, transition_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for item: CanvasItem in [_logo, _glow, _rays]:
		t.tween_property(item, "modulate:a", 0.0, transition_time * 0.8) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for star in _sparkles:
		t.tween_property(star, "modulate:a", 0.0, 0.25)
	# The monster gives a happy little hop and bounces away off the bottom.
	t.tween_property(_lean, "scale", Vector2(1.14, 0.86), 0.08)
	t.tween_property(_lean, "scale", Vector2(0.9, 1.12), 0.15).set_delay(0.08)
	t.tween_property(_lean, "rotation", 0.0, 0.1)
	t.tween_property(_lean, "skew", 0.0, 0.1)
	t.tween_property(_hero, "position:y", _hero.position.y - 60.0, 0.18) \
			.set_delay(0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_hero, "position:y", SCREEN.y + _hero_height + 40.0, 0.42) \
			.set_delay(0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_lean, "rotation", 0.25, 0.42).set_delay(0.26)
	t.tween_property(_shadow, "modulate:a", 0.0, 0.25).set_delay(0.08)
	# Gameplay fades in underneath.
	for j in _hidden.size():
		if is_instance_valid(_hidden[j]):
			t.tween_property(_hidden[j], "modulate:a", _hidden_alpha[j], transition_time) \
					.set_delay(0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(_hand_over)


func _hand_over() -> void:
	if _dropper:
		_dropper.enabled = true
	finished.emit()
	queue_free()


func _new_tween() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	return t


## Soft oval shadow on the ground under the monster, with a faint pool of
## light round it so it still reads on the dark space background.
class Shadow extends Node2D:
	var radius := 50.0

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.2))
		for k in 4:
			draw_circle(Vector2.ZERO, radius * (1.45 - k * 0.1), Color(0.78, 0.62, 1.0, 0.045))
		for k in 5:
			draw_circle(Vector2.ZERO, radius * (1.0 - k * 0.14), Color(0.03, 0.0, 0.08, 0.16))


## Soft radial glow texture: `color` in the middle fading to clear.
func _radial_texture(color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	gradient.colors = PackedColorArray([
		color, Color(color.lerp(Color(1.0, 0.82, 0.5), 0.35), color.a * 0.55),
		Color(color, color.a * 0.15), Color(color, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	return tex


## Soft light rays fanning out from the title (rotated slowly by _process).
class Rays extends Node2D:
	var color := Color(1.0, 0.9, 0.7, 0.2)
	var count := 14
	var length := 560.0

	func _draw() -> void:
		for i in count:
			var a := TAU * i / count
			var half := 0.07 if i % 2 == 0 else 0.045
			var pts := PackedVector2Array([Vector2.ZERO,
					Vector2.from_angle(a - half) * length, Vector2.from_angle(a + half) * length])
			draw_polygon(pts, PackedColorArray([color, Color(color, 0.0), Color(color, 0.0)]))


## A twinkling four-point star.
class Sparkle extends Node2D:
	func _draw() -> void:
		var size := 17.0
		var thin := size * 0.24
		var star := PackedVector2Array([
			Vector2(0, -size), Vector2(thin, -thin), Vector2(size, 0), Vector2(thin, thin),
			Vector2(0, size), Vector2(-thin, thin), Vector2(-size, 0), Vector2(-thin, -thin),
		])
		draw_circle(Vector2.ZERO, size * 0.75, Color(1.0, 0.9, 0.6, 0.22))
		draw_colored_polygon(star, Color(1.0, 0.95, 0.75))
		draw_circle(Vector2.ZERO, size * 0.2, Color.WHITE)
