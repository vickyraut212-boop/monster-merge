class_name Hud
extends CanvasLayer
## On-screen UI: the settings button and pop-up, the score cloud, the Next
## box, the power-up panel, and the game-over panel.
##
## LAYOUT (following vicky's UI reference)
## - NextPanel: top-right corner, opposite the settings button. A dark rounded
##   box with "NEXT" over vicky's purple backing and the next monster.
## - PowerUpPanel: the wide rounded purple panel under the jar. PowerUps holds
##   its four round buttons (Merge, Bomb, Upgrade, Battery), evenly spaced.
## Move or resize any of them in the editor.
##
## The HUD keeps running while the game is paused (process_mode = Always), so
## the settings pop-up works while everything else is frozen.
##
## SETTINGS POP-UP
## The pop-up is one picture (assets/ui/settings_popup.png). Its buttons are
## invisible click areas placed over the picture, sized as fractions of it
## (anchors), so they stay lined up if the picture is resized. To adjust one,
## select it under SettingsPopup/Panel and drag its anchors in the editor.
##
## GAME OVER
## The game-over screen is GameOver (game_over_panel.gd), built in code in the
## leaderboard's style. main.gd reports how the score upload is going with
## set_rank_state(); the HUD passes it to the game-over screen and tells the
## leaderboard, which refreshes itself once the new score has landed.
##
## LEADERBOARD
## The "TOP" button under the settings button and the Leaderboard button on
## the game-over screen both open the online leaderboard pop-up (Leaderboard,
## scenes/leaderboard.tscn).
## The TOP button is a plain placeholder button; give it art later by swapping
## it for a TextureButton with the same name.

signal play_again_pressed
## Restart button in the settings pop-up.
signal restart_pressed
## Home button in the settings pop-up. Nothing listens yet: there is no home
## screen so far.
signal home_pressed
## Sound / Music / Vibrate / Effects in the settings pop-up ("sound", "music",
## "vibrate", "effects"). Sound, Music and Vibrate are switched by the HUD
## itself through GameAudio; Effects has no job yet.
signal setting_pressed(setting: String)
## A power-up button ("merge", "bomb", "upgrade", "battery"). main.gd uses
## "battery" to shake the jar; power_ups.gd handles the other three.
signal power_up_pressed(power_up: String)

@onready var _settings_button: TextureButton = $SettingsButton
@onready var _next_icon: TextureRect = $NextPanel/NextIcon
@onready var _settings_popup: Control = $SettingsPopup
@onready var _settings_panel: Control = $SettingsPopup/Panel
@onready var _power_ups: Control = $PowerUps
@onready var _score_label: Label = $ScorePanel/ScoreLabel
@onready var _best_label: Label = $ScorePanel/BestLabel
@onready var _game_over: GameOverPanel = $GameOver
@onready var _trophy_button: Button = $TrophyButton
@onready var _leaderboard: LeaderboardPopup = $Leaderboard


func _ready() -> void:
	_game_over.play_again_pressed.connect(func() -> void: play_again_pressed.emit())
	_game_over.leaderboard_pressed.connect(_leaderboard.open)
	_trophy_button.pressed.connect(func() -> void:
		_bounce(_trophy_button)
		_leaderboard.open())
	# Play More on the leaderboard: from the game-over panel it starts a new
	# game; during a game the board just closes and play carries on.
	_leaderboard.play_more_pressed.connect(func() -> void:
		if _game_over.visible:
			play_again_pressed.emit())
	_settings_popup.visible = false
	_settings_button.pressed.connect(func() -> void:
		_bounce(_settings_button)
		open_settings())
	_connect_settings_popup()
	for button: TextureButton in _power_ups.get_children():
		var power_up := button.name.to_lower()
		button.pressed.connect(func() -> void:
			_bounce(button)
			power_up_pressed.emit(power_up))


## The power-up button with this name ("merge", "bomb", "upgrade", "battery").
func get_power_up_button(power_up: String) -> TextureButton:
	return _power_ups.get_node_or_null(power_up.capitalize()) as TextureButton


## Shows whether a power-up is ready. Ready: a pink "1" bubble at the top
## right of the button (each power-up holds one use). Cooling down: the button
## greys out, a dark clock-wipe covers the part of the cooldown still to go,
## and the time left ("2:59") sits in the middle of the button.
func set_power_up_cooldown(power_up: String, left: float, total: float) -> void:
	var button := get_power_up_button(power_up)
	if button == null:
		return
	var badge := button.get_node_or_null("Count") as Panel
	if badge == null:
		badge = _make_count_badge()
		button.add_child(badge)
		(badge.get_node("Label") as Label).text = "1"
	var overlay := button.get_node_or_null("Cooldown") as CooldownOverlay
	if overlay == null:
		overlay = CooldownOverlay.new()
		overlay.name = "Cooldown"
		button.add_child(overlay)
	var cooling := left > 0.0
	badge.visible = not cooling
	overlay.visible = cooling
	if cooling:
		overlay.set_time(left, total)
	button.self_modulate = Color(0.55, 0.52, 0.65) if cooling else Color.WHITE


## "2:59" for a number of seconds (rounded up, so it never shows 0:00 early).
static func format_cooldown(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%d:%02d" % [s / 60, s % 60]


## A power-up's cooldown just ended: the button springs back with a soft glow
## and its "1" bubble pops in.
func flash_power_up_ready(power_up: String) -> void:
	var button := get_power_up_button(power_up)
	if button == null:
		return
	pop_power_up_count(power_up)
	button.pivot_offset = button.size / 2.0
	var t := button.create_tween()
	t.tween_property(button, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(button, "modulate", Color(1.35, 1.3, 1.15), 0.12)
	t.tween_property(button, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(button, "modulate", Color.WHITE, 0.4)


## Little bounce on a power-up's count bubble (when it gains a use).
func pop_power_up_count(power_up: String) -> void:
	var button := get_power_up_button(power_up)
	var badge := button.get_node_or_null("Count") if button else null
	if badge == null:
		return
	badge.scale = Vector2(1.6, 1.6)
	badge.create_tween().tween_property(badge, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Side-to-side "no" shake on a power-up button (no uses left).
func shake_power_up_button(power_up: String) -> void:
	var button := get_power_up_button(power_up)
	if button == null:
		return
	var x := button.position.x
	var tween := button.create_tween()
	for dx in [10.0, -10.0, 6.0, -4.0, 0.0]:
		tween.tween_property(button, "position:x", x + dx, 0.04)


## The round count bubble: pink with a white rim and a white number.
func _make_count_badge() -> Panel:
	var badge := Panel.new()
	badge.name = "Count"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size = Vector2(40, 40)
	badge.position = Vector2(84, -2)
	badge.pivot_offset = badge.size / 2.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.32, 0.52)
	style.set_corner_radius_all(20)
	style.set_border_width_all(3)
	style.border_color = Color.WHITE
	style.shadow_color = Color(0.1, 0.02, 0.2, 0.4)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	style.anti_aliasing = true
	badge.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.name = "Label"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color(0.45, 0.05, 0.2))
	label.add_theme_constant_override("outline_size", 5)
	badge.add_child(label)
	return badge


## Shows the settings pop-up and pauses the game underneath it.
func open_settings() -> void:
	get_tree().paused = true
	_settings_popup.visible = true
	_settings_panel.scale = Vector2(0.85, 0.85)
	_settings_panel.create_tween().tween_property(_settings_panel, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Hides the settings pop-up and un-pauses the game.
func close_settings() -> void:
	_settings_popup.visible = false
	get_tree().paused = false


func _connect_settings_popup() -> void:
	var panel := _settings_panel
	(panel.get_node("Close") as TextureButton).pressed.connect(func() -> void:
		GameAudio.play("click")
		close_settings())
	(panel.get_node("Restart") as TextureButton).pressed.connect(func() -> void:
		GameAudio.play("click")
		close_settings()
		restart_pressed.emit())
	(panel.get_node("Home") as TextureButton).pressed.connect(func() -> void:
		GameAudio.play("click")
		home_pressed.emit())
	for setting in ["Sound", "Music", "Vibrate", "Effects"]:
		var key: String = setting.to_lower()
		var button := panel.get_node(setting) as TextureButton
		button.pressed.connect(func() -> void:
			_toggle_setting(key)
			GameAudio.play("click")
			setting_pressed.emit(key))
		if key != "effects":
			button.add_child(_make_off_badge())
	_refresh_toggles()


## Sound, Music and Vibrate switch on/off (saved between games by GameAudio).
## Effects has no job yet.
func _toggle_setting(key: String) -> void:
	match key:
		"sound": GameAudio.set_sound_on(not GameAudio.sound_on)
		"music": GameAudio.set_music_on(not GameAudio.music_on)
		"vibrate": GameAudio.set_vibrate_on(not GameAudio.vibrate_on)
	_refresh_toggles()


## Shows the dark "OFF" cover on each switch that is turned off.
func _refresh_toggles() -> void:
	var states := {"Sound": GameAudio.sound_on, "Music": GameAudio.music_on, "Vibrate": GameAudio.vibrate_on}
	for setting in states:
		_settings_panel.get_node(setting + "/Off").visible = not states[setting]


## A see-through dark rounded cover with "OFF" on it, sized to the blue
## button square in the pop-up art (the top part of the click area).
func _make_off_badge() -> Control:
	var badge := Panel.new()
	badge.name = "Off"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 0.04
	badge.anchor_right = 0.96
	badge.anchor_top = 0.03
	badge.anchor_bottom = 0.7
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.2, 0.6)
	style.set_corner_radius_all(24)
	badge.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "OFF"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_outline_color", Color(0.75, 0.1, 0.2))
	label.add_theme_constant_override("outline_size", 8)
	badge.add_child(label)
	return badge


## Quick squash-and-stretch (and a click sound) so a tap feels like it landed.
func _bounce(control: Control) -> void:
	GameAudio.play("click")
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(0.88, 0.88)
	control.create_tween().tween_property(control, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_score(score: int) -> void:
	_score_label.text = str(score)
	# Little bounce on the number when it changes.
	_score_label.pivot_offset = _score_label.size / 2.0
	_score_label.scale = Vector2(1.2, 1.2)
	create_tween().tween_property(_score_label, "scale", Vector2.ONE, 0.15)


func set_best(best: int) -> void:
	_best_label.text = "BEST %d" % best


func set_next(tier: int) -> void:
	_next_icon.texture = TierData.get_texture(tier)


func show_game_over(score: int, best: int, is_new_best: bool) -> void:
	_game_over.show_result(score, best, is_new_best)
	_trophy_button.visible = false  # the game-over screen has its own button


## Best score on the game-over screen (e.g. when the server knows a higher one).
func set_game_over_best(best: int) -> void:
	_game_over.set_best(best)


## How the score upload is going (see GameOverPanel.RankState). While it is
## PENDING the leaderboard shows "updating" and reloads once it lands.
func set_rank_state(state: GameOverPanel.RankState, rank := 0, total := 0) -> void:
	_game_over.set_rank_state(state, rank, total)
	_leaderboard.set_score_pending(state == GameOverPanel.RankState.PENDING)


## Cooldown cover on a power-up button: a dark clock-wipe over the round
## button for the time still to go, a thin light ring showing progress, and
## the time left in the middle.
class CooldownOverlay extends Control:
	var _fraction := 0.0
	var _label: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)
		_label = Label.new()
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 30)
		_label.add_theme_color_override("font_color", Color.WHITE)
		_label.add_theme_color_override("font_outline_color", Color(0.22, 0.1, 0.4))
		_label.add_theme_constant_override("outline_size", 10)
		var font := load("res://assets/fonts/LilitaOne-Regular.ttf") as Font
		if font:
			_label.add_theme_font_override("font", font)
		add_child(_label)

	func set_time(left: float, total: float) -> void:
		var f := clampf(left / maxf(total, 0.001), 0.0, 1.0)
		var text := Hud.format_cooldown(left)
		if _label and _label.text != text:
			_label.text = text
		if absf(f - _fraction) > 0.0005:
			_fraction = f
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.46
		# Dark wipe for the part still to go (clockwise from 12 o'clock).
		var start := -PI / 2.0 + TAU * (1.0 - _fraction)
		var pts := PackedVector2Array([c])
		var steps := maxi(3, int(48 * _fraction))
		for i in steps + 1:
			pts.append(c + Vector2.from_angle(lerpf(start, -PI / 2.0 + TAU - 0.002, float(i) / steps)) * r)
		if _fraction > 0.01:
			draw_colored_polygon(pts, Color(0.12, 0.06, 0.26, 0.55))
		# Progress ring: the elapsed part glows.
		draw_arc(c, r + 3.0, 0, TAU, 64, Color(0.12, 0.06, 0.26, 0.5), 6.0, true)
		draw_arc(c, r + 3.0, -PI / 2.0, start, 64, Color(0.75, 0.9, 1.0, 0.95), 4.0, true)
