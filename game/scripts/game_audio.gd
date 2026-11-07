extends Node
## Sound effects, background music, vibration, and the Sound / Music / Vibrate
## switches from the settings pop-up. Loaded once for the whole game as the
## "GameAudio" autoload, so music keeps playing through restarts.
##
## USING YOUR OWN SOUNDS
## Every sound is made in code as a placeholder. To replace one, drop a file
## with the same name into assets/audio/ (WAV or OGG), for example
## assets/audio/pop.ogg or assets/audio/music.ogg. It is used automatically.
## Sound names: pop, drop, click, bonus, boss, game_over, music.
##
## The switches are remembered between games in user://settings.cfg.

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const CUSTOM_SOUND_DIR := "res://assets/audio/"
const RATE := 22050

## Loudness in decibels (0 = full, -6 = about half).
@export var sfx_volume_db := -4.0
@export var music_volume_db := -14.0

var sound_on := true
var music_on := true
var vibrate_on := true

var _sounds := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	for i in 8:
		var player := AudioStreamPlayer.new()
		player.volume_db = sfx_volume_db
		add_child(player)
		_sfx_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.volume_db = music_volume_db
	add_child(_music)
	_music.stream = _get_sound("music")
	_update_music()


## Plays a sound effect. pitch 1.0 = normal, 2.0 = an octave higher.
func play(sound: String, pitch := 1.0) -> void:
	if not sound_on:
		return
	var player := _sfx_players[_next_player]
	_next_player = (_next_player + 1) % _sfx_players.size()
	player.stream = _get_sound(sound)
	player.pitch_scale = pitch
	player.play()


## Buzzes the phone for `ms` milliseconds (does nothing on a computer).
func vibrate(ms: int) -> void:
	if vibrate_on:
		Input.vibrate_handheld(ms)


func set_sound_on(on: bool) -> void:
	sound_on = on
	_save_settings()


func set_music_on(on: bool) -> void:
	music_on = on
	_update_music()
	_save_settings()


func set_vibrate_on(on: bool) -> void:
	vibrate_on = on
	_save_settings()
	vibrate(40)  # a little buzz to show it's on


func _update_music() -> void:
	if music_on and not _music.playing:
		_music.play()
	elif not music_on:
		_music.stop()


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	sound_on = config.get_value("audio", "sound", true)
	music_on = config.get_value("audio", "music", true)
	vibrate_on = config.get_value("audio", "vibrate", true)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "sound", sound_on)
	config.set_value("audio", "music", music_on)
	config.set_value("audio", "vibrate", vibrate_on)
	config.save(SETTINGS_PATH)
	settings_changed.emit()


func _get_sound(sound: String) -> AudioStream:
	if not _sounds.has(sound):
		_sounds[sound] = _load_custom(sound)
		if _sounds[sound] == null:
			_sounds[sound] = _make_sound(sound)
	return _sounds[sound]


func _load_custom(sound: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path: String = CUSTOM_SOUND_DIR + sound + "." + ext
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if sound == "music":
				if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
					stream.loop = true
				elif stream is AudioStreamWAV:
					stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
					stream.loop_end = int(stream.get_length() * stream.mix_rate)
			return stream
	return null


# ---------------------------------------------------------------------------
# Placeholder sounds, made from simple tones.

func _make_sound(sound: String) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	match sound:
		"pop":
			# Bubbly "bloop": a quick downward pitch slide.
			samples = _slide(880.0, 260.0, 0.13, 0.9)
			_mix(samples, _noise_click(0.012, 0.25), 0)
		"drop":
			samples = _slide(420.0, 180.0, 0.12, 0.45)
		"click":
			samples = _slide(1500.0, 1100.0, 0.04, 0.4)
		"bonus":
			# Rising three-note sparkle.
			for i in 3:
				_mix(samples, _tone([784.0, 1047.0, 1568.0][i], 0.12, 0.35), int(i * 0.07 * RATE))
		"boss":
			# Big pop with a chord ringing after it.
			samples = _slide(500.0, 120.0, 0.25, 1.0)
			for f in [523.0, 659.0, 784.0, 1047.0]:
				_mix(samples, _tone(f, 0.7, 0.18), int(0.08 * RATE))
		"game_over":
			for i in 3:
				_mix(samples, _tone([523.0, 415.0, 330.0][i], 0.3, 0.4), int(i * 0.22 * RATE))
		"music":
			return _make_music()
	return _to_wav(samples, false)


## A sine tone sliding from one pitch to another, fading out.
func _slide(from_hz: float, to_hz: float, length: float, volume: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(from_hz, to_hz, sqrt(t)) / RATE
		var env := minf(1.0, i / (0.004 * RATE)) * pow(1.0 - t, 2.0)
		out[i] = sin(phase) * env * volume
	return out


## A soft bell-like note: a sine with a quieter overtone, fading out.
func _tone(hz: float, length: float, volume: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var time := float(i) / RATE
		var env := minf(1.0, i / (0.005 * RATE)) * exp(-time * 6.0 / length)
		out[i] = (sin(TAU * hz * time) + 0.3 * sin(TAU * hz * 2.0 * time)) * env * volume
	return out


func _noise_click(length: float, volume: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = randf_range(-1.0, 1.0) * volume * (1.0 - float(i) / n)
	return out


## Adds `add` into `into` starting at sample `at`, growing `into` if needed.
func _mix(into: PackedFloat32Array, add: PackedFloat32Array, at: int) -> void:
	if into.size() < at + add.size():
		into.resize(at + add.size())
	for i in add.size():
		into[at + i] += add[i]


## A gentle 8-bar looping tune (placeholder until real music is added):
## a soft bass note per bar and a pentatonic melody on top.
func _make_music() -> AudioStreamWAV:
	var beat := 60.0 / 100.0  # 100 beats per minute
	var bars := [
		[261.6, [523.3, 659.3, 784.0, 659.3]],
		[220.0, [523.3, 659.3, 880.0, 784.0]],
		[174.6, [440.0, 523.3, 698.5, 523.3]],
		[196.0, [493.9, 587.3, 784.0, 587.3]],
		[261.6, [784.0, 659.3, 523.3, 659.3]],
		[220.0, [880.0, 784.0, 659.3, 523.3]],
		[174.6, [698.5, 659.3, 587.3, 523.3]],
		[196.0, [587.3, 493.9, 392.0, 493.9]],
	]
	var total := int(bars.size() * 4 * beat * RATE)
	var song := PackedFloat32Array()
	song.resize(total)
	for b in bars.size():
		var bar_start := int(b * 4 * beat * RATE)
		_mix(song, _tone(bars[b][0], 4 * beat, 0.16), bar_start)
		for k in 4:
			_mix(song, _tone(bars[b][1][k], beat * 1.6, 0.09), bar_start + int(k * beat * RATE))
	song.resize(total)  # trim note tails so the loop is seamless
	return _to_wav(song, true)


func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav
