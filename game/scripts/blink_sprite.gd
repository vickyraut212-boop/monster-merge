class_name BlinkSprite
extends Sprite2D
## A monster sprite that blinks at a steady, natural rhythm while idle.
## Call set_tier(tier) to show a tier; it then plays the tier's blink frames
## (assets/monsters/tier_N_blink_1..3.png): half-closed, closed, half-open.
## Every tier uses the same timing. If a tier has no blink frames it simply
## shows the still sprite.

## Seconds between blinks. Every monster uses this same rhythm.
const BLINK_INTERVAL := 3.5
## Tiny random variation (+/- seconds) so it doesn't feel robotic.
## Keep it small; big values make blinking feel erratic.
const BLINK_JITTER := 0.25
## How long each blink frame shows: half-closed, closed, half-open.
## About a quarter of a second in total, like a real relaxed blink.
const FRAME_TIMES: Array[float] = [0.06, 0.10, 0.08]

var _open: Texture2D
var _frames: Array[Texture2D] = []
var _wait := 0.0
var _frame := -1  # -1 = eyes open
var _frame_left := 0.0


func set_tier(tier: int) -> void:
	_open = TierData.get_texture(tier)
	_frames = TierData.get_blink_frames(tier)
	texture = _open
	scale = TierData.get_sprite_scale(tier)
	_frame = -1
	# Each monster starts at a different point of the same rhythm, so they
	# don't all blink at once but every one blinks at the same pace.
	_wait = randf_range(0.3, BLINK_INTERVAL)


## Blinks right away (used by the intro), then carries on its normal rhythm.
func blink_now() -> void:
	if not _frames.is_empty() and _frame < 0:
		_show_frame(0)


func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	if _frame < 0:
		_wait -= delta
		if _wait <= 0.0:
			_show_frame(0)
		return
	_frame_left -= delta
	if _frame_left > 0.0:
		return
	if _frame + 1 < _frames.size():
		_show_frame(_frame + 1)
		return
	# Blink finished: eyes open again until the next one.
	_frame = -1
	texture = _open
	_wait = BLINK_INTERVAL + randf_range(-BLINK_JITTER, BLINK_JITTER)


func _show_frame(i: int) -> void:
	_frame = i
	_frame_left = FRAME_TIMES[mini(i, FRAME_TIMES.size() - 1)]
	texture = _frames[i]
