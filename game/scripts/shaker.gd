class_name Shaker
extends Node
## SHAKE: jostles every monster in the jar so they bounce around, bump into
## new neighbours, and any two of the same tier that touch merge as usual.
##
## - Any device: tap the battery button (the 4th one) in the power-up panel.
##   main.gd connects it to shake() and sets `button` so it wobbles too.
## - Phone / tablet: shaking the device works as well. The accelerometer
##   spots a sharp jolt.
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

## Emitted each time the jar actually shakes (power_ups.gd spends a battery
## use on it).
signal shaken

## Switched off at game over, and while there are no battery uses left.
var enabled := true
## The button that triggers a shake (the battery power-up). It gets a little
## wobble each time. Optional.
var button: Control

var _cooldown_left := 0.0
var _last_accel := Vector3.ZERO
var _use_motion := false


func _ready() -> void:
	_use_motion = OS.has_feature("mobile") or OS.has_feature("web_android") \
			or OS.has_feature("web_ios")


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
	if not _use_motion:
		return

	var accel := Input.get_accelerometer()
	if accel == Vector3.ZERO:
		return  # no motion sensor data: the battery button still works

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
	shaken.emit()


## Little side-to-side wobble on the button so it feels like it shook too.
func _wiggle_button() -> void:
	if button == null or not button.visible:
		return
	button.pivot_offset = button.size / 2.0
	var tween := button.create_tween()
	for angle in [0.25, -0.25, 0.15, -0.1, 0.0]:
		tween.tween_property(button, "rotation", angle, 0.05)
