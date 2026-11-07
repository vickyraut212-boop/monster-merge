class_name Hud
extends CanvasLayer
## On-screen UI: the settings button and pop-up, the score cloud, vicky's
## evolution chart panel, the power-up buttons, and the game-over panel.
## (The next monster is shown inside the ship's glass dome.)
##
## LAYOUT
## - EvolutionChart: vicky's monster panel (assets/ui/evolution_chart.png) in
##   the top-right corner, opposite the settings button.
## - PowerUpBar: a rounded glass badge (assets/ui/powerup_bar.png) under the
##   jar, holding the Vanish, Blast and Upgrade buttons (PowerUps). Keep its
##   size at the picture's shape (about 420 x 118) so the round ends stay round.
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
## LEADERBOARD
## The "TOP" button under the settings button and the Leaderboard button on
## the game-over panel both open the online leaderboard pop-up (Leaderboard,
## scenes/leaderboard.tscn). The game-over panel's RankLabel shows the
## player's world rank once main.gd hears back from the server.
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
## A power-up button ("vanish", "blast", "upgrade"). Nothing listens yet: what
## each power-up does is still to be decided.
signal power_up_pressed(power_up: String)

@onready var _settings_button: TextureButton = $SettingsButton
@onready var _settings_popup: Control = $SettingsPopup
@onready var _settings_panel: Control = $SettingsPopup/Panel
@onready var _power_ups: Control = $PowerUps
@onready var _score_label: Label = $ScorePanel/ScoreLabel
@onready var _best_label: Label = $ScorePanel/BestLabel
@onready var _game_over: Control = $GameOver
@onready var _final_score_label: Label = $GameOver/Box/FinalScore
@onready var _final_best_label: Label = $GameOver/Box/FinalBest
@onready var _play_again_button: Button = $GameOver/Box/PlayAgain
@onready var _rank_label: Label = $GameOver/Box/RankLabel
@onready var _leaderboard_button: Button = $GameOver/Box/LeaderboardButton
@onready var _trophy_button: Button = $TrophyButton
@onready var _leaderboard: LeaderboardPopup = $Leaderboard


func _ready() -> void:
	_game_over.visible = false
	_play_again_button.pressed.connect(func() -> void: play_again_pressed.emit())
	set_rank_text("")
	_leaderboard_button.pressed.connect(func() -> void:
		GameAudio.play("click")
		_leaderboard.open())
	_trophy_button.pressed.connect(func() -> void:
		_bounce(_trophy_button)
		_leaderboard.open())
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


func show_game_over(score: int, best: int, is_new_best: bool) -> void:
	_final_score_label.text = "Score: %d" % score
	_final_best_label.text = ("New best!" if is_new_best else "Best: %d" % best)
	_game_over.visible = true
	_trophy_button.visible = false  # the game-over panel has its own button


## Online status line on the game-over panel ("World rank #12 of 340",
## "Offline - ...", or "" to hide it).
func set_rank_text(text: String) -> void:
	_rank_label.text = text
	_rank_label.visible = text != ""
