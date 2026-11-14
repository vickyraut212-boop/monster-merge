class_name Intro
extends CanvasLayer
## Animated opening of the game: a grand arcade-style title reveal.
##
##   A soft radiant glow and slowly turning light rays fade in
##   -> the Monster Merge title drops in with a springy overshoot, a bloom of
##      light, twinkling sparkles and a light sweep across the letters
##   -> the alien ship glides in and drops the monsters one by one from its
##      beam; each one grows out of the beam, falls with gravity, squashes on
##      landing, rebounds and wobbles to rest
##   -> the ship zooms off, a short pause, then the monsters hop away, the
##      title floats off and gameplay fades in.
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

@export_group("Monsters")
## The monsters the ship drops, in drop order: tier, width in pixels, x
## position. They use the exact game art (assets/monsters/tier_N.png), only
## scaled, including the Tier 6 and Tier 7 art.
@export var cast: Array[Vector3] = [
	Vector3(3, 130, 92),
	Vector3(6, 200, 262),
	Vector3(7, 215, 468),
	Vector3(1, 105, 640),
]
## Where the monsters' feet land.
@export var ground_y := 1010.0

@export_group("Ship")
@export var ship_texture: Texture2D = preload("res://assets/ui/alien_ship.png")
@export var ship_width := 224.0
## Height the ship cruises at while dropping.
@export var ship_y := 650.0

@export_group("Timing (seconds)")
## When the ship arrives, after the title reveal.
@export var ship_arrive := 1.25
## Time to glide from one drop to the next.
@export var ship_move_time := 0.42
## Pause on the finished picture before gameplay starts.
@export var hold_time := 0.9
## How long the hand-over to gameplay takes.
@export var transition_time := 0.6

const SCREEN := Vector2(720, 1280)
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
var _ship: Node2D
var _beam: Beam
var _bodies: Array[Node2D] = []
var _shadows: Array[Node2D] = []
var _heights: Array[float] = []
var _tweens: Array[Tween] = []
var _done := false
var _time := 0.0
var _last_ship_x := 0.0


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
	# The ship leans into its movement and hovers gently.
	if _ship:
		var speed := (_ship.position.x - _last_ship_x) / maxf(delta, 0.0001)
		_last_ship_x = _ship.position.x
		_ship.rotation = lerpf(_ship.rotation, clampf(speed * 0.0005, -0.16, 0.16), 1.0 - exp(-8.0 * delta))
		var sprite := _ship.get_child(1) as Node2D
		sprite.position.y = sin(_time * 3.0) * 3.0


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

	for i in cast.size():
		var shadow := Shadow.new()
		shadow.position = Vector2(cast[i].z, ground_y)
		shadow.radius = cast[i].y * 0.42
		shadow.modulate.a = 0.0
		add_child(shadow)
		_shadows.append(shadow)

	for i in cast.size():
		var body := Node2D.new()
		var sprite := BlinkSprite.new()
		sprite.set_tier(int(cast[i].x))
		var s := cast[i].y / sprite.texture.get_width()
		sprite.scale = Vector2(s, s)
		var height := sprite.texture.get_height() * s
		# Feet at the body's origin, so squash and stretch happen from the ground up.
		sprite.position.y = -height / 2.0
		body.add_child(sprite)
		body.visible = false
		add_child(body)
		_bodies.append(body)
		_heights.append(height)

	# The ship, drawn over the monsters so they appear from under it.
	_ship = Node2D.new()
	_ship.position = Vector2(-ship_width, ship_y - 60.0)
	_last_ship_x = _ship.position.x
	_beam = Beam.new()
	_beam.ship_width = ship_width
	_beam.modulate.a = 0.0
	_ship.add_child(_beam)
	var ship_sprite := Sprite2D.new()
	ship_sprite.texture = ship_texture
	ship_sprite.scale = Vector2.ONE * (ship_width / ship_texture.get_width())
	_ship.add_child(ship_sprite)
	add_child(_ship)

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


# --- The sequence ----------------------------------------------------------

func _play() -> void:
	var logo_scale := Vector2.ONE * (logo_width / logo_texture.get_width())
	var glow_scale := Vector2(960.0, 660.0) / 256.0

	# Glow and rays fade in first, so the title arrives into the light.
	var g := _new_tween().set_parallel()
	g.tween_property(_glow, "modulate:a", 0.85, 0.6).set_trans(Tween.TRANS_SINE)
	g.tween_property(_glow, "scale", glow_scale, 0.8).from(glow_scale * 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	g.tween_property(_rays, "modulate:a", 1.0, 1.0).set_delay(0.2).set_trans(Tween.TRANS_SINE)
	g.tween_property(_rays, "scale", Vector2.ONE, 1.2).from(Vector2(0.4, 0.4)).set_delay(0.2) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Title drops in with a springy overshoot.
	var t := _new_tween()
	t.tween_interval(0.2)
	t.tween_property(_logo, "modulate:a", 1.0, 0.18)
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
	# Light sweep across the letters.
	t.tween_method(func(v: float) -> void: (_logo.material as ShaderMaterial).set_shader_parameter("progress", v),
			-0.3, 1.7, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# The ship glides in and drops each monster.
	var ship := _new_tween()
	ship.tween_interval(ship_arrive)
	var first := Vector2(cast[0].z, ship_y)
	ship.tween_property(_ship, "position", first, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in cast.size():
		if i > 0:
			ship.tween_property(_ship, "position", Vector2(cast[i].z, ship_y), ship_move_time) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ship.tween_property(_beam, "modulate:a", 1.0, 0.1)
		ship.tween_callback(_drop_monster.bind(i))
		ship.tween_interval(0.24)
		ship.tween_property(_beam, "modulate:a", 0.0, 0.12)
		# Small recoil as the ship lets go.
		ship.parallel().tween_property(_ship, "position:y", ship_y - 10.0, 0.1) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		ship.tween_property(_ship, "position:y", ship_y, 0.16).set_trans(Tween.TRANS_SINE)
	# Zoom off up and away.
	ship.tween_property(_ship, "position", Vector2(SCREEN.x + ship_width, ship_y - 260.0), 0.6) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	ship.parallel().tween_property(_ship, "scale", Vector2(0.7, 0.7), 0.6)
	ship.tween_interval(hold_time)
	ship.tween_callback(_finish)


## The title has landed: a bloom of light and the sparkles start to twinkle.
func _title_landed() -> void:
	var glow_scale := _glow.scale
	var t := _new_tween().set_parallel()
	t.tween_property(_glow, "modulate:a", 1.0, 0.12)
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


## One monster: grows out of the beam just under the ship, falls with
## gravity (stretching as it speeds up), squashes on landing, rebounds with a
## little hop and wobbles to rest.
func _drop_monster(i: int) -> void:
	var body := _bodies[i]
	var shadow := _shadows[i]
	var height := _heights[i]
	var land_y := ground_y
	var start_y := ship_y + 46.0 + height * 0.5
	body.visible = true
	body.position = Vector2(cast[i].z, start_y)
	body.scale = Vector2(0.25, 0.25)
	body.modulate = Color(1.6, 1.8, 1.6, 0.0)
	# Fall time from the drop height, so bigger drops take a little longer.
	var fall := clampf(sqrt((land_y - start_y) / 1600.0), 0.22, 0.5)

	var t := _new_tween()
	# Materialise in the beam.
	t.tween_property(body, "scale", Vector2(0.92, 1.08), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(body, "modulate", Color.WHITE, 0.22)
	# Released: falls, accelerating, a touch stretched.
	t.tween_property(body, "position:y", land_y, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(body, "scale", Vector2(0.88, 1.14), fall)
	t.parallel().tween_property(shadow, "modulate:a", 1.0, fall)
	t.parallel().tween_property(shadow, "scale", Vector2.ONE, fall).from(Vector2(0.35, 0.35))
	t.tween_callback(_on_land.bind(i))
	# Landing squash.
	t.tween_property(body, "scale", Vector2(1.28, 0.74), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Rebound: stretch up into a small hop.
	t.tween_property(body, "scale", Vector2(0.9, 1.12), 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(body, "position:y", land_y - 30.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(shadow, "scale", Vector2(0.82, 0.82), 0.16)
	t.tween_property(body, "scale", Vector2.ONE, 0.12)
	t.parallel().tween_property(body, "position:y", land_y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(shadow, "scale", Vector2.ONE, 0.14)
	# Small second squash, then a soft wobble to rest.
	t.tween_property(body, "scale", Vector2(1.1, 0.92), 0.06)
	t.tween_property(body, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	GameAudio.play("drop", 1.2)


func _on_land(i: int) -> void:
	# Soft landing thud: bigger monsters sound deeper.
	var size := clampf((cast[i].y - 100.0) / 150.0, 0.0, 1.0)
	GameAudio.play("drop", lerpf(1.25, 0.75, size))


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
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()

	var t := _new_tween().set_parallel()
	# Logo floats up and fades away with its glow, rays and sparkles.
	t.tween_property(_logo, "position:y", _logo.position.y - 70.0, transition_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for item: CanvasItem in [_logo, _glow, _rays, _ship]:
		t.tween_property(item, "modulate:a", 0.0, transition_time * 0.8) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for star in _sparkles:
		t.tween_property(star, "modulate:a", 0.0, 0.25)
	# Monsters give a little hop and drop away below the screen.
	for i in _bodies.size():
		var body := _bodies[i]
		if not body.visible:
			continue  # skipped before this one was dropped
		var d := i * 0.05
		t.tween_property(body, "scale", Vector2(1.12, 0.88), 0.08).set_delay(d)
		t.tween_property(body, "scale", Vector2(0.92, 1.1), 0.15).set_delay(d + 0.08)
		t.tween_property(body, "rotation", 0.0, 0.1).set_delay(d)
		t.tween_property(body, "position:y", body.position.y - 40.0, 0.15) \
				.set_delay(d + 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(body, "position:y", SCREEN.y + _heights[i] + 40.0, 0.4) \
				.set_delay(d + 0.23).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(_shadows[i], "modulate:a", 0.0, 0.25).set_delay(d + 0.08)
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


## Soft oval shadow on the ground under a monster.
class Shadow extends Node2D:
	var radius := 50.0

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.22))
		for k in 4:
			var r := radius * (1.0 - k * 0.15)
			draw_circle(Vector2.ZERO, r, Color(0.06, 0.02, 0.14, 0.09))


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


## The ship's tractor beam (a soft cone under the saucer).
class Beam extends Node2D:
	var ship_width := 224.0

	func _draw() -> void:
		var top := ship_width * 0.17
		var c := Color(0.7, 1.0, 0.88, 0.55)
		var pts := PackedVector2Array([Vector2(-ship_width * 0.13, top), Vector2(ship_width * 0.13, top),
				Vector2(ship_width * 0.42, top + 150.0), Vector2(-ship_width * 0.42, top + 150.0)])
		draw_polygon(pts, PackedColorArray([c, c, Color(c, 0.0), Color(c, 0.0)]))


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
