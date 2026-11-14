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
## The trophy button under the settings button and the Leaderboard button on
## the game-over screen both open the online leaderboard pop-up (Leaderboard,
## scenes/leaderboard.tscn).
## The trophy button (assets/ui/trophy_button.png, vicky's art) sits just
## under the settings button, the same size.

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
@onready var _trophy_button: TextureButton = $TrophyButton
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


## Shows whether a power-up is ready.
## Ready: full-colour icon with a pink "1" bubble at its top right (each
## power-up holds one use).
## Cooling down: the icon eases to a dimmed, desaturated look, a thin ring
## round the button fills clockwise as the cooldown runs out, and a small
## pill under the button shows the time left ("2:59"). Nothing covers the
## icon itself.
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
		var dim := ShaderMaterial.new()
		dim.shader = _dim_shader()
		dim.set_shader_parameter("amount", 0.0)
		button.material = dim
	var cooling := left > 0.0
	badge.visible = not cooling
	overlay.visible = cooling
	if cooling:
		overlay.set_time(left, total)
	var was_cooling: bool = button.get_meta("cooling", false)
	if cooling != was_cooling:
		button.set_meta("cooling", cooling)
		_tween_dim(button, 1.0 if cooling else 0.0, 0.25 if cooling else 0.45)


static var _dim_shader_cache: Shader

## Greys out and darkens the icon by `amount` (0 = full colour, 1 = dimmed).
static func _dim_shader() -> Shader:
	if _dim_shader_cache == null:
		_dim_shader_cache = Shader.new()
		_dim_shader_cache.code = """
shader_type canvas_item;
uniform float amount = 0.0;
void fragment() {
	vec4 c = COLOR;
	float grey = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	vec3 muted = mix(vec3(grey), vec3(0.62, 0.56, 0.78) * grey * 1.25, 0.35);
	c.rgb = mix(c.rgb, muted * 0.72, amount * 0.85);
	COLOR = c;
}
"""
	return _dim_shader_cache


func _tween_dim(button: TextureButton, to: float, time: float) -> void:
	var dim := button.material as ShaderMaterial
	if dim == null:
		return
	var from := float(dim.get_shader_parameter("amount") if dim.get_shader_parameter("amount") != null else 0.0)
	button.create_tween().tween_method(func(v: float) -> void: dim.set_shader_parameter("amount", v),
			from, to, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## "2:59" for a number of seconds (rounded up, so it never shows 0:00 early).
static func format_cooldown(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%d:%02d" % [s / 60, s % 60]


## A power-up's cooldown just ended: the icon eases back to full colour (see
## set_power_up_cooldown), a soft ring of light pulses out once, the button
## gives one gentle bounce and its "1" bubble pops in. No looping flash.
func flash_power_up_ready(power_up: String) -> void:
	var button := get_power_up_button(power_up)
	if button == null:
		return
	pop_power_up_count(power_up)
	button.pivot_offset = button.size / 2.0
	var t := button.create_tween()
	t.tween_property(button, "scale", Vector2(1.08, 1.08), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(button, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var pulse := ReadyPulse.new()
	button.add_child(pulse)
	button.move_child(pulse, 0)


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


## Cooldown look on a power-up button: a thin track round the button with a
## soft gold arc that fills clockwise from 12 o'clock as the cooldown runs out
## (it is full the moment the power-up is ready), and a small rounded time
## pill tucked under the button.
class CooldownOverlay extends Control:
	const TRACK := Color(0.16, 0.08, 0.32, 0.55)
	const FILL := Color(1.0, 0.82, 0.42)
	var _fraction := 0.0
	var _pill: PanelContainer
	var _label: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(_layout)
		_pill = PanelContainer.new()
		_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.11, 0.4, 0.92)
		style.set_corner_radius_all(12)
		style.border_color = Color(0.62, 0.5, 0.95, 0.7)
		style.set_border_width_all(2)
		style.shadow_color = Color(0.06, 0.02, 0.14, 0.35)
		style.shadow_size = 3
		style.shadow_offset = Vector2(0, 2)
		style.content_margin_left = 9
		style.content_margin_right = 9
		style.content_margin_top = 0
		style.content_margin_bottom = 1
		style.anti_aliasing = true
		_pill.add_theme_stylebox_override("panel", style)
		_label = Label.new()
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 17)
		_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.8))
		var font := load("res://assets/fonts/Fredoka.ttf") as Font
		if font:
			_label.add_theme_font_override("font", font)
		_pill.add_child(_label)
		add_child(_pill)
		_layout()

	func _layout() -> void:
		if _pill == null:
			return
		_pill.reset_size()
		_pill.position = Vector2((size.x - _pill.size.x) / 2.0, size.y - _pill.size.y * 0.35)

	func set_time(left: float, total: float) -> void:
		var f := 1.0 - clampf(left / maxf(total, 0.001), 0.0, 1.0)
		var text := Hud.format_cooldown(left)
		if _label and _label.text != text:
			_label.text = text
			_layout()
		if absf(f - _fraction) > 0.0005:
			_fraction = f
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.5 + 1.0
		draw_arc(c, r, 0, TAU, 72, TRACK, 7.0, true)
		if _fraction <= 0.002:
			return
		var start := -PI / 2.0
		var end := start + TAU * _fraction
		draw_arc(c, r, start, end, maxi(4, int(72 * _fraction)), Color(FILL, 0.3), 9.0, true)
		draw_arc(c, r, start, end, maxi(4, int(72 * _fraction)), FILL, 4.5, true)
		# Rounded head on the moving end.
		draw_circle(c + Vector2.from_angle(end) * r, 3.4, Color(1.0, 0.95, 0.8))


## One soft ring of light that swells out from a power-up button and fades
## (when its cooldown ends). Removes itself.
class ReadyPulse extends Control:
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var tween := create_tween()
		tween.tween_method(func(v: float) -> void:
			_t = v
			queue_redraw(), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_callback(queue_free)

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.5
		var a := 1.0 - _t
		for k in 3:
			draw_circle(c, r * (0.92 + _t * 0.3) + k * 6.0, Color(1.0, 0.88, 0.55, 0.12 * a))
		draw_arc(c, r * (1.0 + _t * 0.28), 0, TAU, 64, Color(1.0, 0.92, 0.65, 0.8 * a), 3.0 * a + 0.5, true)
