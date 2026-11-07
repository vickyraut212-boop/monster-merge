class_name Intro
extends CanvasLayer
## Animated opening of the game.
##
##   Space background + Monster Merge logo
##   -> 4 monsters jump in from the bottom edge, one after another
##   -> soft squash-and-stretch landing with a little bounce
##   -> short pause -> monsters hop away, logo floats off, gameplay fades in.
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
@export var logo_center := Vector2(360, 400)

@export_group("Monsters")
## The monsters that jump in, in jump order: tier, width in pixels, x position.
## They use the exact game art (assets/monsters/tier_N.png), only scaled.
@export var cast: Array[Vector3] = [
	Vector3(3, 135, 100),
	Vector3(7, 235, 278),
	Vector3(5, 175, 478),
	Vector3(1, 110, 638),
]
## Where the monsters' feet land.
@export var ground_y := 1010.0
## How high above the ground each jump peaks.
@export var jump_height := 250.0

@export_group("Timing (seconds)")
## Logo on screen alone before the first monster jumps.
@export var first_jump_delay := 0.9
## Gap between one monster's jump and the next.
@export var jump_stagger := 0.32
## Pause on the finished picture before gameplay starts.
@export var hold_time := 1.0
## How long the hand-over to gameplay takes.
@export var transition_time := 0.6

const SCREEN := Vector2(720, 1280)

var _main: Node
var _dropper: Dropper
## Gameplay pieces hidden during the intro, and the opacity to restore.
var _hidden: Array[CanvasItem] = []
var _hidden_alpha: Array[float] = []

var _blocker: Control
var _logo: Sprite2D
var _bodies: Array[Node2D] = []
var _shadows: Array[Node2D] = []
var _heights: Array[float] = []
var _tweens: Array[Tween] = []
var _done := false


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


# --- Building the picture -------------------------------------------------

func _build() -> void:
	# Catches taps so nothing underneath reacts; a tap skips the intro.
	_blocker = Control.new()
	_blocker.size = SCREEN
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.gui_input.connect(_on_blocker_input)
	add_child(_blocker)

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
		body.position = Vector2(cast[i].z, SCREEN.y + height + 20.0)
		add_child(body)
		_bodies.append(body)
		_heights.append(height)

	# Logo last, so monsters jumping high pass behind it.
	_logo = Sprite2D.new()
	_logo.texture = logo_texture
	_logo.position = logo_center
	_logo.scale = Vector2.ZERO
	_logo.modulate.a = 0.0
	add_child(_logo)


# --- The sequence ----------------------------------------------------------

func _play() -> void:
	var logo_scale := Vector2.ONE * (logo_width / logo_texture.get_width())

	# Logo pops in with a soft overshoot, then gently floats.
	var t := _new_tween()
	t.tween_interval(0.25)
	t.tween_property(_logo, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(_logo, "scale", logo_scale * 1.06, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_logo, "scale", logo_scale, 0.2).set_trans(Tween.TRANS_SINE)
	t.tween_callback(_float_logo)

	# Monsters, one after another.
	for i in _bodies.size():
		_jump_in(i, first_jump_delay + i * jump_stagger)

	# Hold the finished picture, then hand over to gameplay.
	var last_landing := first_jump_delay + (_bodies.size() - 1) * jump_stagger + _jump_length()
	var end := _new_tween()
	end.tween_interval(last_landing + hold_time)
	end.tween_callback(_finish)


func _float_logo() -> void:
	var t := _new_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_logo, "position:y", logo_center.y - 8.0, 1.4)
	t.tween_property(_logo, "position:y", logo_center.y + 4.0, 1.4)


const PEEK_TIME := 0.16
const CROUCH_TIME := 0.12
const RISE_TIME := 0.38
const FALL_TIME := 0.3
const SETTLE_TIME := 0.7

func _jump_length() -> float:
	return PEEK_TIME + CROUCH_TIME + RISE_TIME + FALL_TIME + SETTLE_TIME


## One monster: peeks up from the bottom edge, crouches (anticipation), leaps
## in an arc stretching upwards, falls, squashes on landing, rebounds with a
## little hop and wobbles to rest.
func _jump_in(i: int, delay: float) -> void:
	var body := _bodies[i]
	var shadow := _shadows[i]
	var height := _heights[i]
	var land := Vector2(cast[i].z, ground_y)
	# Start a little towards the screen edge, so the jump travels sideways a bit.
	var start_x := land.x + signf(land.x - SCREEN.x / 2.0) * 40.0
	var peek := Vector2(start_x, SCREEN.y + height * 0.45)
	var apex := Vector2(lerpf(start_x, land.x, 0.55), land.y - jump_height)
	var tilt := signf(land.x - start_x) * 0.12
	body.position = Vector2(start_x, SCREEN.y + height + 20.0)

	var t := _new_tween()
	t.tween_interval(delay)
	# Peek up from below the screen.
	t.tween_property(body, "position", peek, PEEK_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Anticipation: crouch.
	t.tween_property(body, "scale", Vector2(1.18, 0.8), CROUCH_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Leap: rise to the top of the arc, stretched tall, leaning into the jump.
	t.tween_property(body, "position:y", apex.y, RISE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(body, "position:x", apex.x, RISE_TIME)
	t.parallel().tween_property(body, "rotation", tilt, RISE_TIME)
	t.parallel().tween_property(body, "scale", Vector2(0.84, 1.2), RISE_TIME * 0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(body, "scale", Vector2(0.98, 1.02), RISE_TIME * 0.65) \
			.set_delay(RISE_TIME * 0.35)
	# Fall onto the landing spot; the shadow grows as it comes down.
	t.tween_property(body, "position:y", land.y, FALL_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(body, "position:x", land.x, FALL_TIME)
	t.parallel().tween_property(body, "rotation", 0.0, FALL_TIME)
	t.parallel().tween_property(body, "scale", Vector2(0.9, 1.12), FALL_TIME)
	t.parallel().tween_property(shadow, "modulate:a", 1.0, FALL_TIME)
	t.parallel().tween_property(shadow, "scale", Vector2.ONE, FALL_TIME).from(Vector2(0.4, 0.4))
	t.tween_callback(_on_land.bind(i))
	# Landing squash.
	t.tween_property(body, "scale", Vector2(1.3, 0.72), 0.07) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Rebound: stretch up into a small hop.
	t.tween_property(body, "scale", Vector2(0.9, 1.12), 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(body, "position:y", land.y - 26.0, 0.15) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(shadow, "scale", Vector2(0.85, 0.85), 0.15)
	t.tween_property(body, "scale", Vector2.ONE, 0.11)
	t.parallel().tween_property(body, "position:y", land.y, 0.13) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(shadow, "scale", Vector2.ONE, 0.13)
	# Small second squash, then a soft wobble to rest.
	t.tween_property(body, "scale", Vector2(1.1, 0.92), 0.06)
	t.tween_property(body, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


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
	# Logo floats up and fades away.
	t.tween_property(_logo, "position:y", _logo.position.y - 70.0, transition_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(_logo, "modulate:a", 0.0, transition_time * 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Monsters give a little hop and drop away below the screen.
	for i in _bodies.size():
		var body := _bodies[i]
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
