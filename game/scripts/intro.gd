class_name Intro
extends CanvasLayer
## Animated opening of the game: a grand arcade-style title reveal with the
## four approved monsters.
##
##   A soft radiant glow and slowly turning light rays fade in
##   -> the monsters arrive one after another, each with its own bounce:
##        Tier 3 (pink, one eye)     hops in from the left edge
##        Tier 5 (green, two eyes)   springs up from the bottom with a twist
##        Tier 6 (red, three eyes)   somersaults in from the right edge
##        Tier 7 (lavender, 4 eyes)  makes a big leap from the bottom and lands
##                                   with a thump that makes the others hop
##   -> the Monster Merge title drops in as the first monster lands, with a
##      bloom of light and sparkles; a light sweep crosses it on the finale
##   -> all four stay on screen, blinking and gently swaying, then a radiant
##      energy pulse flashes out from them and gameplay appears behind it.
##
## Squash and stretch is done by a small shader (RUBBER_SHADER) that keeps the
## monsters' volume: the body gets wider as it gets shorter and bulges most
## round the middle, while the feet keep their shape, so the monsters stay
## round and rubbery rather than flattening like a 2D picture. The art itself
## is the exact game art (assets/monsters/tier_N.png and blink frames), only
## scaled.
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
## The four monsters, in entrance order: tier, width in pixels, x of their
## middle, y of their feet. Bigger ones stand a little further back.
@export var cast: Array[Vector4] = [
	Vector4(3, 135, 98, 1050),
	Vector4(5, 172, 228, 1034),
	Vector4(6, 196, 388, 1018),
	Vector4(7, 236, 574, 1004),
]
## When each monster starts its entrance (seconds).
@export var entrance_times: Array[float] = [0.3, 0.95, 1.6, 2.3]

@export_group("Timing (seconds)")
## Pause on the finished picture before the transition.
@export var hold_time := 1.1
## Length of the energy-pulse transition into gameplay.
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
## Volume-keeping squash and stretch around the feet. squash < 1 = shorter
## and wider, > 1 = taller and slimmer; lean shears the top sideways. The
## bottom FEET part keeps its size so feet never flatten.
const RUBBER_SHADER := """
shader_type canvas_item;
uniform float squash = 1.0;
uniform float lean = 0.0;
uniform float feet = 0.2;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	float h = 1.0 - UV.y;
	float s = mix(1.0, squash, smoothstep(0.0, feet, h));
	float hs = h / s;
	float widen = pow(squash, -0.45);
	float w = mix(1.0, widen, smoothstep(feet * 0.15, feet * 1.5, hs));
	w *= 1.0 + (widen - 1.0) * 0.25 * sin(3.14159 * clamp(hs, 0.0, 1.0));
	vec2 src = vec2((UV.x - 0.5 - lean * hs) / w + 0.5, 1.0 - hs);
	vec4 c = texture(TEXTURE, src);
	if (src.x < 0.0 || src.x > 1.0 || src.y < 0.0 || src.y > 1.0) {
		c = vec4(0.0);
	}
	COLOR = c * tint;
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
var _monsters: Array[IntroMonster] = []
var _flash: ColorRect
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

	# Monsters: shadows first, then the bodies from the back (biggest) to the
	# front, so the smaller ones stand in front.
	var shader := Shader.new()
	shader.code = RUBBER_SHADER
	for i in cast.size():
		var m := IntroMonster.new()
		m.setup(int(cast[i].x), cast[i].y, Vector2(cast[i].z, cast[i].w), shader)
		_monsters.append(m)
		add_child(m.shadow)
	for i in range(cast.size() - 1, -1, -1):
		add_child(_monsters[i])

	# Logo last, so nothing passes in front of it.
	_logo = Sprite2D.new()
	_logo.texture = logo_texture
	_logo.position = logo_center + Vector2(0, -160)
	_logo.scale = Vector2.ZERO
	_logo.modulate.a = 0.0
	var shine := ShaderMaterial.new()
	var shine_shader := Shader.new()
	shine_shader.code = SHINE_SHADER
	shine.shader = shine_shader
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

	# Full-screen flash for the energy-pulse transition (on top of everything).
	_flash = ColorRect.new()
	_flash.size = SCREEN
	_flash.color = Color(1.0, 0.9, 0.97, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


# --- The sequence ----------------------------------------------------------

func _play() -> void:
	var glow_scale := Vector2(960.0, 660.0) / 256.0
	var g := _new_tween().set_parallel()
	g.tween_property(_glow, "modulate:a", 0.55, 0.6).set_trans(Tween.TRANS_SINE)
	g.tween_property(_glow, "scale", glow_scale, 0.8).from(glow_scale * 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	g.tween_property(_rays, "modulate:a", 0.6, 0.8).set_delay(0.1).set_trans(Tween.TRANS_SINE)
	g.tween_property(_rays, "scale", Vector2.ONE, 1.4).from(Vector2(0.4, 0.4)).set_delay(0.1) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for i in _monsters.size():
		var m := _monsters[i]
		m.visible = false
		var show := _new_tween()
		show.tween_interval(entrance_times[i])
		show.tween_callback(func() -> void: m.visible = true)
	var first_land := _hop_in_from_left(_monsters[0], entrance_times[0])
	_spring_from_bottom(_monsters[1], entrance_times[1])
	_somersault_from_right(_monsters[2], entrance_times[2])
	var finale := _big_leap(_monsters[3], entrance_times[3])

	# Title drops in as the first monster lands.
	var logo_scale := Vector2.ONE * (logo_width / logo_texture.get_width())
	var t := _new_tween()
	t.tween_interval(first_land - 0.3)
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

	# Finale: light sweep across the title as the last monster lands.
	var f := _new_tween()
	f.tween_interval(finale)
	f.tween_method(func(v: float) -> void: (_logo.material as ShaderMaterial).set_shader_parameter("progress", v),
			-0.3, 1.7, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	f.tween_interval(hold_time)
	f.tween_callback(_finish)


# --- The four entrances ------------------------------------------------------
# Each adds its moves to one tween and returns when the monster first touches
# down. Landings share _land(): squash (keeping volume), a rebound stretch, a
# soft elastic settle, then a blink and the idle sway.

## Tier 3: two quick hops in from the left edge, leaning into each one.
func _hop_in_from_left(m: IntroMonster, start: float) -> float:
	var g := m.ground
	m.position = Vector2(-90.0, g.y)
	var t := _new_tween()
	t.tween_interval(start)
	var hops := [[Vector2(g.x - 70.0, g.y), 90.0, 0.3], [g, 120.0, 0.36]]
	for k in hops.size():
		var to: Vector2 = hops[k][0]
		var height: float = hops[k][1]
		var d: float = hops[k][2]
		t.tween_property(m, "squash", 0.84, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(m, "position:x", to.x, d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.parallel().tween_property(m, "lift", height, d * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(m, "lift", 0.0, d * 0.5).set_delay(d * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(m, "squash", 1.12, d * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(m, "squash", 1.0, d * 0.4).set_delay(d * 0.45)
		t.parallel().tween_property(m, "lean", 0.1, d * 0.4)
		t.parallel().tween_property(m, "lean", -0.04, d * 0.5).set_delay(d * 0.5)
		if k < hops.size() - 1:
			t.tween_callback(_thud.bind(0.3))
			t.tween_property(m, "squash", 0.86, 0.07)
	_land(t, m, 0.8, 0.0)
	return start + 0.06 + 0.3 + 0.13 + 0.06 + 0.36


## Tier 5: springs up from below the screen, twisting, and lands with a bounce.
func _spring_from_bottom(m: IntroMonster, start: float) -> float:
	var g := m.ground
	m.position = Vector2(g.x + 90.0, g.y)
	m.lift = -m.height - 160.0
	m.spin = 0.7
	m.squash = 1.18
	var t := _new_tween()
	t.tween_interval(start)
	t.tween_property(m, "lift", 250.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(m, "position:x", g.x, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(m, "spin", -0.2, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(m, "squash", 1.0, 0.42)
	t.tween_property(m, "lift", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(m, "spin", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(m, "squash", 1.1, 0.3)
	_land(t, m, 1.0, 60.0)
	return start + 0.72


## Tier 6: tumbles in from the right edge with a full somersault.
func _somersault_from_right(m: IntroMonster, start: float) -> float:
	var g := m.ground
	m.position = Vector2(SCREEN.x + 140.0, g.y)
	m.lift = 140.0
	var t := _new_tween()
	t.tween_interval(start)
	t.tween_property(m, "position:x", g.x, 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(m, "lift", 260.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(m, "lift", 0.0, 0.32).set_delay(0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(m, "spin", -TAU, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(m, "squash", 0.9, 0.2)
	t.parallel().tween_property(m, "squash", 1.1, 0.25).set_delay(0.37)
	t.tween_callback(func() -> void: m.spin = 0.0)
	_land(t, m, 1.0, 34.0, -0.09)
	return start + 0.62


## Tier 7: a big, slow leap from below the screen; its heavy landing makes
## the other three hop.
func _big_leap(m: IntroMonster, start: float) -> float:
	var g := m.ground
	m.position = Vector2(g.x - 40.0, g.y)
	m.lift = -m.height - 160.0
	m.squash = 1.2
	var t := _new_tween()
	t.tween_interval(start)
	t.tween_property(m, "lift", 230.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(m, "position:x", g.x, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(m, "squash", 0.96, 0.5).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(m, "spin", 0.12, 0.5)
	t.tween_property(m, "lift", 0.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(m, "squash", 1.14, 0.38)
	t.parallel().tween_property(m, "spin", 0.0, 0.38)
	t.tween_callback(_ground_thump)
	_land(t, m, 1.25, 28.0)
	return start + 0.88


## Shared landing: squash, rebound (with an optional small bounce of
## `bounce` px), settle, blink, then come alive.
func _land(t: Tween, m: IntroMonster, strength: float, bounce: float, tilt := 0.06) -> void:
	t.tween_callback(_thud.bind(strength))
	t.tween_property(m, "squash", 1.0 - 0.12 * strength, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(m, "lean", tilt, 0.08)
	if bounce > 0.0:
		var d := 0.12 + bounce / 600.0
		t.tween_property(m, "lift", bounce, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(m, "squash", 1.1, d * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(m, "lean", -tilt * 0.6, d)
		t.tween_property(m, "lift", 0.0, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(m, "squash", 1.0, d)
		t.tween_callback(_thud.bind(strength * 0.4))
		t.tween_property(m, "squash", 1.0 - 0.08 * strength, 0.07)
		t.parallel().tween_property(m, "lean", 0.0, 0.07)
	else:
		t.tween_property(m, "squash", 1.08, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(m, "lean", -tilt * 0.5, 0.12)
	t.tween_property(m, "squash", 1.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(m, "lean", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(m.blink)
	t.tween_property(m, "alive", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


## Tier 7's landing shakes the ground: the others give a little hop.
func _ground_thump() -> void:
	for i in _monsters.size() - 1:
		var m := _monsters[i]
		var t := _new_tween()
		t.tween_interval(0.03 * i)
		t.tween_property(m, "hop", 24.0 - i * 3.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(m, "jiggle", 1.08, 0.08)
		t.tween_property(m, "hop", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(m, "jiggle", 0.9, 0.06)
		t.tween_property(m, "jiggle", 1.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		t.tween_callback(m.blink)


## Soft landing thud: harder landings sound deeper.
func _thud(strength: float) -> void:
	GameAudio.play("drop", lerpf(1.3, 0.75, clampf(strength, 0.0, 1.25) / 1.25))


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


# --- Hand-over to gameplay -------------------------------------------------

func _on_blocker_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		_finish()


## Energy pulse: a bright ring bursts out from the monsters, the glow blooms
## and a soft flash fills the screen; at its peak the intro picture is swapped
## for the game, and the flash fades away to reveal gameplay. The monsters
## stay where they are until the flash covers them.
func _finish() -> void:
	if _done:
		return
	_done = true
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()

	var center := Vector2(SCREEN.x / 2.0, 880.0)
	var ring := Pulse.new()
	ring.position = center
	add_child(ring)
	move_child(ring, _flash.get_index())
	var peak := transition_time * 0.35

	var fx := _new_tween().set_parallel()
	fx.tween_property(ring, "progress", 1.0, transition_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fx.tween_property(_glow, "scale", _glow.scale * 1.6, peak).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fx.tween_property(_glow, "modulate:a", 1.0, peak * 0.5)
	for m in _monsters:
		fx.tween_property(m, "glow", 1.0, peak).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var t := _new_tween()
	t.tween_property(_flash, "color:a", 0.85, peak).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(_swap_to_game)
	t.tween_property(_flash, "color:a", 0.0, transition_time - peak).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(_hand_over)
	GameAudio.play("bonus", 1.25)


## Under the flash: hide the intro picture and show the game.
func _swap_to_game() -> void:
	for child in get_children():
		if child != _flash and child is CanvasItem and not child is Pulse:
			(child as CanvasItem).visible = false
	for j in _hidden.size():
		if is_instance_valid(_hidden[j]):
			_hidden[j].modulate.a = _hidden_alpha[j]


func _hand_over() -> void:
	if _dropper:
		_dropper.enabled = true
	finished.emit()
	queue_free()


func _new_tween() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	return t


## One intro monster: its feet sit at `position` (+ `lift` above the ground,
## + `hop`), `spin` turns it around its middle while in the air, and
## `squash` / `lean` drive RUBBER_SHADER. Once `alive` it breathes, sways and
## blinks by itself. It owns its ground shadow.
class IntroMonster extends Node2D:
	var tier := 1
	var ground := Vector2.ZERO
	var height := 0.0
	var shadow: Shadow
	var squash := 1.0
	var lean := 0.0
	var lift := 0.0
	var hop := 0.0
	var spin := 0.0
	var jiggle := 1.0
	var alive := 0.0
	var glow := 0.0
	var _spinner: Node2D
	var _sprite: BlinkSprite
	var _material: ShaderMaterial
	var _phase := 0.0
	var _time := 0.0

	func setup(new_tier: int, width: float, feet: Vector2, shader: Shader) -> void:
		tier = new_tier
		ground = feet
		position = feet
		_phase = new_tier * 1.7
		_sprite = BlinkSprite.new()
		_sprite.set_tier(tier)
		var tex := _sprite.texture.get_size()
		var s := width / tex.x
		height = tex.y * s
		# Padded region so the shader has room to widen and lean the art.
		var pad := Vector2(tex.x * 0.3, tex.y * 0.25)
		_sprite.region_enabled = true
		_sprite.region_rect = Rect2(-pad.x, -pad.y, tex.x + pad.x * 2.0, tex.y + pad.y + tex.y * 0.02)
		_sprite.centered = false
		_sprite.offset = Vector2(-tex.x / 2.0 - pad.x, -tex.y - pad.y)
		_sprite.scale = Vector2(s, s)
		_sprite.position = Vector2(0, height / 2.0)
		_material = ShaderMaterial.new()
		_material.shader = shader
		_sprite.material = _material
		_spinner = Node2D.new()
		_spinner.position = Vector2(0, -height / 2.0)
		_spinner.add_child(_sprite)
		add_child(_spinner)
		shadow = Shadow.new()
		shadow.radius = width * 0.42
		shadow.position = feet
		shadow.modulate.a = 0.0

	func blink() -> void:
		_sprite.blink_now()

	func _process(delta: float) -> void:
		_time += delta
		var breathe := sin(_time * 3.1 + _phase) * 0.022 * alive
		var sway := sin(_time * 2.2 + _phase * 0.6) * 0.035 * alive
		_material.set_shader_parameter("squash", squash * jiggle * (1.0 + breathe))
		_material.set_shader_parameter("lean", lean + sway)
		_spinner.rotation = spin
		var up := lift + hop
		position.y = ground.y - up
		modulate = Color(1.0 + glow * 0.8, 1.0 + glow * 0.7, 1.0 + glow * 0.8)
		# Shadow: shows only while near the ground, shrinking with height.
		var near := clampf(1.0 - up / 320.0, 0.0, 1.0)
		var visible_x := position.x > -60.0 and position.x < 780.0
		shadow.position.x = position.x
		shadow.modulate.a = near if visible and visible_x and up > -height * 0.6 else 0.0
		shadow.scale = Vector2.ONE * lerpf(0.4, 1.0, near)


## Soft oval shadow on the ground under a monster, with a faint pool of
## light round it so it still reads on the dark space background.
class Shadow extends Node2D:
	var radius := 50.0

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.2))
		for k in 4:
			draw_circle(Vector2.ZERO, radius * (1.45 - k * 0.1), Color(0.78, 0.62, 1.0, 0.045))
		for k in 5:
			draw_circle(Vector2.ZERO, radius * (1.0 - k * 0.14), Color(0.03, 0.0, 0.08, 0.16))


## Expanding ring of light for the transition.
class Pulse extends Node2D:
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()

	func _draw() -> void:
		var r := lerpf(40.0, 900.0, progress)
		var a := 1.0 - progress
		draw_circle(Vector2.ZERO, r * 0.6, Color(1.0, 0.92, 0.98, 0.25 * a))
		draw_arc(Vector2.ZERO, r, 0, TAU, 96, Color(1.0, 0.8, 0.95, 0.35 * a), 40.0 * a + 4.0, true)
		draw_arc(Vector2.ZERO, r, 0, TAU, 96, Color(1.0, 1.0, 1.0, 0.9 * a), 8.0 * a + 1.0, true)


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
