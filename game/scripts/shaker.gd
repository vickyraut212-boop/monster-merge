class_name Shaker
extends Node
## SHAKE: jostles every monster in the jar so they bounce around, bump into
## new neighbours, and any two of the same tier that touch merge as usual.
##
## - Phone / tablet: shake the device. The accelerometer spots a sharp jolt.
## - PC (and phones whose browser gives no motion data): a round SHAKE button
##   in the bottom-left corner, next to the power-up badge.
##
## main.gd creates this node; set enabled = false to switch it off (game over).
## All the numbers below can be tuned in one place.

## How hard a jolt has to be to count as a shake (change in acceleration,
## metres per second squared). Lower = more sensitive.
const SHAKE_THRESHOLD := 14.0
## Seconds to wait before another shake can fire, so one long shake doesn't
## launch the monsters into orbit.
const COOLDOWN := 0.6
## Upward kick given to each monster (pixels per second, random in range).
const KICK_UP_MIN := 220.0
const KICK_UP_MAX := 380.0
## Sideways kick, random left or right (pixels per second, at most).
const KICK_SIDE := 220.0
## A little spin so they tumble instead of hopping straight up.
const SPIN := 4.0

## PC button position and size (screen pixels, 720 x 1280 layout).
const BUTTON_RECT := Rect2(30, 1117, 100, 100)

## Switched off at game over (also hides the button).
var enabled := true:
	set(value):
		enabled = value
		if _button != null and not value:
			_button.visible = false

var _cooldown_left := 0.0
var _last_accel := Vector3.ZERO
var _use_motion := false
var _motion_seen := false
var _motion_wait := 1.5
var _button: Button


func _ready() -> void:
	_use_motion = OS.has_feature("mobile") or OS.has_feature("web_android") \
			or OS.has_feature("web_ios")
	_build_button()
	# On a phone the button stays hidden; it only appears if no motion data
	# arrives in the first moments (some phone browsers block the sensor).
	_button.visible = not _use_motion


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
	if not _use_motion:
		return

	var accel := Input.get_accelerometer()
	if accel != Vector3.ZERO:
		_motion_seen = true
	elif not _motion_seen:
		_motion_wait -= delta
		if _motion_wait <= 0.0:
			# No sensor: fall back to the button, like on PC.
			_use_motion = false
			_button.visible = true
		return

	# A shake is a sudden *change* in acceleration (holding the phone still,
	# or tilting it slowly, changes it very little).
	var jolt := (accel - _last_accel).length()
	_last_accel = accel
	if jolt >= SHAKE_THRESHOLD:
		shake()


## Kicks every monster in the jar. Safe to call any time; does nothing
## during the cooldown or after game over.
func shake() -> void:
	if not enabled or _cooldown_left > 0.0:
		return
	_cooldown_left = COOLDOWN

	for node in get_tree().get_nodes_in_group("monsters"):
		var monster := node as Monster
		if monster == null or monster.is_merging or monster.freeze:
			continue
		monster.sleeping = false
		var kick := Vector2(randf_range(-KICK_SIDE, KICK_SIDE), -randf_range(KICK_UP_MIN, KICK_UP_MAX))
		# Impulse = mass x speed, so big and small monsters jump alike.
		monster.apply_central_impulse(kick * monster.mass)
		monster.angular_velocity += randf_range(-SPIN, SPIN)

	GameAudio.play("drop", 0.8)
	GameAudio.vibrate(80)
	_wiggle_button()


## Round purple SHAKE button, drawn in code (swap in a picture later by
## giving it a texture or replacing it with a TextureButton).
func _build_button() -> void:
	var layer := CanvasLayer.new()
	# Same level as the game itself, so the HUD's pop-ups cover it.
	layer.layer = 0
	add_child(layer)

	_button = Button.new()
	_button.text = "SHAKE"
	_button.focus_mode = Control.FOCUS_NONE
	_button.position = BUTTON_RECT.position
	_button.size = BUTTON_RECT.size
	_button.pivot_offset = BUTTON_RECT.size / 2.0
	_button.add_theme_font_size_override("font_size", 22)
	_button.add_theme_color_override("font_color", Color.WHITE)
	_button.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.4))
	_button.add_theme_constant_override("outline_size", 6)
	_button.add_theme_stylebox_override("normal", _round_style(Color(0.62, 0.38, 0.9, 0.9)))
	_button.add_theme_stylebox_override("hover", _round_style(Color(0.7, 0.46, 0.96, 0.95)))
	_button.add_theme_stylebox_override("pressed", _round_style(Color(0.5, 0.28, 0.78, 0.95)))
	_button.pressed.connect(shake)
	layer.add_child(_button)


func _round_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(50)
	style.border_color = Color(1, 1, 1, 0.7)
	style.set_border_width_all(4)
	return style


## Little side-to-side wobble on the button so it feels like it shook too.
func _wiggle_button() -> void:
	if _button == null or not _button.visible:
		return
	var tween := _button.create_tween()
	for angle in [0.25, -0.25, 0.15, -0.1, 0.0]:
		tween.tween_property(_button, "rotation", angle, 0.05)
