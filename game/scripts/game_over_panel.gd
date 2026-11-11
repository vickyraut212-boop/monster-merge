class_name GameOverPanel
extends Control
## The game-over screen, part of the HUD (the GameOver node in hud.tscn).
## Built in code in the same style as the leaderboard (leaderboard_popup.gd):
## the same art, fonts, colours and glossy pill buttons.
##
## LAYOUT (720x1280 viewport; tweak the rectangles below to move things)
## - Top: a compact rounded card (the leaderboard's panel art) under a
##   "Game Over" title banner. It shows the final score big, a NEW BEST tag,
##   and two stat pills: Best Score and World Rank.
## - Middle: left clear so the monsters in the jar stay visible. main.gd adds a
##   soft purple and gold glow behind them.
## - Bottom: Leaderboard (gold, the primary button) and Play Again (purple),
##   over the power-up panel, which has no use once the game is over.
## A soft dark gradient dims the top and bottom only, never the jar.
##
## ONLINE RANK
## main.gd sends the score by itself as soon as the game ends and reports
## back through set_rank_state(): the World Rank pill shows a small spinner
## while the score is on its way, then the rank. Nothing ever waits on it.

signal play_again_pressed
signal leaderboard_pressed

enum RankState {
	NONE,  ## Not sent: leaderboard not set up, or a score of 0.
	PENDING,  ## Being sent.
	RANKED,  ## The server answered with a rank.
	QUEUED,  ## Server unreachable; Backend sends it on a later launch.
	REJECTED,  ## The server refused the run.
}

const TEX_PANEL := preload("res://assets/leaderboard/panel.png")
const TEX_CROWN := preload("res://assets/leaderboard/crown_1.png")
const TEX_TROPHY := preload("res://assets/leaderboard/trophy.png")
const TEX_STAR := preload("res://assets/leaderboard/star.png")
const FONT_BODY := preload("res://assets/fonts/Fredoka.ttf")
const FONT_TITLE := preload("res://assets/fonts/LilitaOne-Regular.ttf")

# --- Layout -----------------------------------------------------------------

## The card. panel.png is drawn at PANEL_SCALE so its curved top stays small.
const CARD_RECT := Rect2(60, 40, 600, 388)
const PANEL_SCALE := 0.75
## panel.png nine-patch margins (left, top, right, bottom) in its pixels.
const PANEL_MARGINS := [56, 124, 56, 48]
const TITLE_RECT := Rect2(170, 18, 380, 96)
const SCORE_CAPTION_Y := 124.0
const SCORE_RECT := Rect2(60, 142, 600, 112)
const NEW_BEST_RECT := Rect2(486, 128, 150, 48)
const STAT_RECTS: Array[Rect2] = [Rect2(92, 268, 256, 124), Rect2(372, 268, 256, 124)]

const LEADERBOARD_RECT := Rect2(96, 1036, 528, 112)
const PLAY_AGAIN_RECT := Rect2(200, 1168, 320, 84)

## How the dim gradient runs down the screen (0 = top, 1 = bottom): dark over
## the card, clear over the jar, dark again over the buttons.
const DIM_COLOR := Color(0.06, 0.02, 0.16)
const DIM_STOPS := [[0.0, 0.84], [0.335, 0.76], [0.37, 0.1], [0.785, 0.1], [0.81, 0.8], [1.0, 0.88]]

# --- Colours (same as the leaderboard) ----------------------------------------

const LIGHT_TEXT := Color(1, 1, 1)
const OUTLINE := Color(0.22, 0.06, 0.45)
const GOLD_TEXT := Color(1, 0.86, 0.24)
const LILAC_TEXT := Color(0.86, 0.78, 1.0)
const GOLD := Color(1, 0.8, 0.15)
const GOLD_EDGE := Color(1, 0.95, 0.6)
const GOLD_DEEP := Color(0.86, 0.48, 0.04)
const PURPLE := Color(0.45, 0.22, 0.85)
const PURPLE_EDGE := Color(0.75, 0.6, 1.0)
const PURPLE_DEEP := Color(0.28, 0.1, 0.6)

var _font_bold: FontVariation
var _dim: Control
var _flash: ColorRect
var _title: Control
var _card: Control
var _score_label: Label
var _new_best: Control
var _stats: Array[Control] = []
var _best_value: Label
var _rank_value: Label
var _rank_sub: Label
var _rank_spinner: Control
var _leaderboard_button: Button
var _play_again_button: Button
var _score := 0


func _ready() -> void:
	visible = false
	_build()


## Shows the screen with a short animation: the dim and title drop in, the
## card pops, the score counts up and the buttons slide up from below.
func show_result(score: int, best: int, is_new_best: bool) -> void:
	_score = score
	visible = true
	set_best(best)
	_score_label.text = "0"
	_new_best.visible = is_new_best

	_dim.modulate.a = 0.0
	_flash.color.a = 0.35
	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", 1.0, 0.3)
	tween.tween_property(_flash, "color:a", 0.0, 0.35)

	_title.position.y = TITLE_RECT.position.y - 160.0
	tween.tween_property(_title, "position:y", TITLE_RECT.position.y, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_card.scale = Vector2(0.7, 0.7)
	_card.modulate.a = 0.0
	tween.tween_property(_card, "scale", Vector2.ONE, 0.4).set_delay(0.08) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "modulate:a", 1.0, 0.15).set_delay(0.08)

	tween.tween_method(_set_counted_score, 0, score, 0.7).set_delay(0.2) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for i in _stats.size():
		var stat := _stats[i]
		stat.modulate.a = 0.0
		tween.tween_property(stat, "modulate:a", 1.0, 0.25).set_delay(0.35 + i * 0.08)

	if is_new_best:
		_new_best.scale = Vector2.ZERO
		tween.tween_property(_new_best, "scale", Vector2.ONE, 0.35).set_delay(0.85) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Buttons work at once (no waiting on the animation).
	for pair in [[_leaderboard_button, LEADERBOARD_RECT, 0.25], [_play_again_button, PLAY_AGAIN_RECT, 0.33]]:
		var button: Button = pair[0]
		var rect: Rect2 = pair[1]
		button.position.y = rect.position.y + 260.0
		tween.tween_property(button, "position:y", rect.position.y, 0.4).set_delay(float(pair[2])) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_best(best: int) -> void:
	_best_value.text = _fmt(best)


## Updates the World Rank pill (see RankState). rank and total are only used
## for RANKED.
func set_rank_state(state: RankState, rank := 0, total := 0) -> void:
	_rank_spinner.visible = state == RankState.PENDING
	_rank_value.visible = state != RankState.PENDING
	match state:
		RankState.PENDING:
			_rank_sub.text = "Updating..."
		RankState.RANKED:
			_rank_value.text = "#%s" % _fmt(rank)
			_rank_sub.text = "of %s players" % _fmt(total) if total > 0 else ""
			_pop(_rank_value)
		RankState.QUEUED:
			_rank_value.text = "--"
			_rank_sub.text = "Offline, sends later"
		RankState.REJECTED:
			_rank_value.text = "--"
			_rank_sub.text = "Score not accepted"
		_:
			_rank_value.text = "--"
			_rank_sub.text = "Offline"


func _set_counted_score(value: int) -> void:
	_score_label.text = _fmt(value)


# --- Building ---------------------------------------------------------------

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Blocks taps to the jar and the power-ups underneath.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font_bold = FontVariation.new()
	_font_bold.base_font = FONT_BODY
	_font_bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	var ui_theme := Theme.new()
	ui_theme.default_font = _font_bold
	theme = ui_theme

	_dim = _texture(_dim_texture(), TextureRect.STRETCH_SCALE)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_flash = ColorRect.new()
	_flash.color = Color(0.85, 0.7, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)

	_build_card()
	_build_title()
	_build_buttons()


func _build_card() -> void:
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_card, CARD_RECT)
	_card.pivot_offset = Vector2(CARD_RECT.size.x / 2.0, 0.0)
	add_child(_card)

	var panel := NinePatchRect.new()
	panel.texture = TEX_PANEL
	panel.patch_margin_left = PANEL_MARGINS[0]
	panel.patch_margin_top = PANEL_MARGINS[1]
	panel.patch_margin_right = PANEL_MARGINS[2]
	panel.patch_margin_bottom = PANEL_MARGINS[3]
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = CARD_RECT.size / PANEL_SCALE
	panel.scale = Vector2(PANEL_SCALE, PANEL_SCALE)
	_card.add_child(panel)

	var caption := _label("YOUR SCORE", 24, LILAC_TEXT, OUTLINE, 6)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(caption, Rect2(0, SCORE_CAPTION_Y - CARD_RECT.position.y, CARD_RECT.size.x, 32))
	_card.add_child(caption)

	_score_label = _label("0", 104, LIGHT_TEXT, OUTLINE, 18, FONT_TITLE)
	_score_label.add_theme_color_override("font_shadow_color", Color(0.3, 0.05, 0.4, 0.8))
	_score_label.add_theme_constant_override("shadow_offset_y", 6)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_score_label, Rect2(SCORE_RECT.position - CARD_RECT.position, SCORE_RECT.size))
	_card.add_child(_score_label)

	_new_best = _pill(GOLD, GOLD_EDGE, GOLD_DEEP, 24)
	_place(_new_best, Rect2(NEW_BEST_RECT.position - CARD_RECT.position, NEW_BEST_RECT.size))
	_new_best.pivot_offset = NEW_BEST_RECT.size / 2.0
	_new_best.rotation_degrees = 8.0
	var new_best_text := _label("NEW BEST!", 24, LIGHT_TEXT, Color(0.6, 0.28, 0.0), 7, FONT_TITLE)
	new_best_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_best_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	new_best_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	new_best_text.offset_top = -3
	_new_best.add_child(new_best_text)
	_card.add_child(_new_best)

	var best := _make_stat(STAT_RECTS[0], "BEST SCORE", TEX_TROPHY)
	_best_value = best["value"]
	var rank := _make_stat(STAT_RECTS[1], "WORLD RANK", TEX_CROWN)
	_rank_value = rank["value"]
	_rank_sub = rank["sub"]
	_rank_spinner = _make_spinner(36.0)
	(rank["line"] as HBoxContainer).add_child(_rank_spinner)
	set_rank_state(RankState.NONE)


## One stat pill: caption, icon + value, and a small line under it.
func _make_stat(rect: Rect2, caption_text: String, icon_tex: Texture2D) -> Dictionary:
	var pill := Panel.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _box(Color(0.17, 0.04, 0.42, 0.9), 30, Color(0.62, 0.42, 1.0), 3, 0)
	style.border_width_bottom = 3
	style.border_width_top = 5
	style.border_color = Color(0.6, 0.4, 1.0)
	pill.add_theme_stylebox_override("panel", style)
	_place(pill, Rect2(rect.position - CARD_RECT.position, rect.size))
	_card.add_child(pill)
	_stats.append(pill)

	var caption := _label(caption_text, 20, LILAC_TEXT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(caption, Rect2(0, 10, rect.size.x, 26))
	pill.add_child(caption)

	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 10)
	_place(line, Rect2(0, 36, rect.size.x, 54))
	pill.add_child(line)
	var icon := _texture(icon_tex)
	icon.custom_minimum_size = Vector2(46, 42)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)
	var value := _label("--", 44, GOLD_TEXT, OUTLINE, 10, FONT_TITLE)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.size_flags_vertical = Control.SIZE_FILL
	line.add_child(value)

	var sub := _label("", 18, Color(LILAC_TEXT, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(sub, Rect2(0, 90, rect.size.x, 24))
	pill.add_child(sub)
	return {"value": value, "sub": sub, "line": line}


## Title banner, the same shape as the leaderboard's.
func _build_title() -> void:
	_title = Control.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_title, TITLE_RECT)
	add_child(_title)
	var banner := Panel.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.8, 0.42, 0.95)
	style.border_color = Color(0.98, 0.82, 1.0)
	style.set_border_width_all(4)
	style.border_width_bottom = 10
	style.set_corner_radius_all(48)
	style.shadow_color = Color(0.25, 0.05, 0.45, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 5)
	banner.add_theme_stylebox_override("panel", style)
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.add_child(banner)
	var inner := Panel.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color(0.62, 0.24, 0.85)
	inner_style.set_corner_radius_all(38)
	inner.add_theme_stylebox_override("panel", inner_style)
	_place(inner, Rect2(12, 12, TITLE_RECT.size.x - 24, TITLE_RECT.size.y - 30))
	banner.add_child(inner)
	var title := _label("Game Over", 58, GOLD_TEXT, Color(0.42, 0.1, 0.55), 14, FONT_TITLE)
	title.add_theme_color_override("font_shadow_color", Color(0.3, 0.05, 0.4, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(title, Rect2(0, -6, TITLE_RECT.size.x, TITLE_RECT.size.y))
	banner.add_child(title)
	for side in [-1.0, 1.0]:
		var star := _texture(TEX_STAR)
		var x: float = TITLE_RECT.size.x / 2.0 + side * (TITLE_RECT.size.x / 2.0 + 4.0) - 22.0
		_place(star, Rect2(x, -8, 44, 42))
		star.pivot_offset = star.size / 2.0
		star.rotation_degrees = side * 14.0
		_title.add_child(star)


func _build_buttons() -> void:
	# Primary: Leaderboard, gold, with a trophy. Breathes gently.
	_leaderboard_button = _rubber_button(GOLD, GOLD_EDGE, GOLD_DEEP, 56)
	_leaderboard_button.tooltip_text = "See your rank on the leaderboard"
	_place(_leaderboard_button, LEADERBOARD_RECT)
	_leaderboard_button.pivot_offset = LEADERBOARD_RECT.size / 2.0
	_leaderboard_button.pressed.connect(func() -> void:
		GameAudio.play("click")
		leaderboard_pressed.emit())
	add_child(_leaderboard_button)
	var line := _button_line(_leaderboard_button, 14)
	var trophy := _texture(TEX_TROPHY)
	trophy.custom_minimum_size = Vector2(70, 64)
	trophy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(trophy)
	var text := _label("Leaderboard", 50, LIGHT_TEXT, Color(0.58, 0.26, 0.0), 12, FONT_TITLE)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(text)
	var breathe := _leaderboard_button.create_tween().set_loops()
	breathe.tween_property(_leaderboard_button, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(_leaderboard_button, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)

	# Secondary: Play Again, purple, smaller.
	_play_again_button = _rubber_button(PURPLE, PURPLE_EDGE, PURPLE_DEEP, 42)
	_play_again_button.tooltip_text = "Play again"
	_place(_play_again_button, PLAY_AGAIN_RECT)
	_play_again_button.pivot_offset = PLAY_AGAIN_RECT.size / 2.0
	_play_again_button.pressed.connect(func() -> void:
		GameAudio.play("click")
		play_again_pressed.emit())
	add_child(_play_again_button)
	var again := _button_line(_play_again_button, 12)
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(36, 36)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.draw.connect(_draw_replay.bind(icon))
	again.add_child(icon)
	var again_text := _label("Play Again", 36, LIGHT_TEXT, OUTLINE, 9)
	again_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	again.add_child(again_text)


## A glossy, rubbery pill: light rim, darker thick bottom edge, soft shadow
## and a shine across the top (like the leaderboard's Play More button).
func _rubber_button(color: Color, edge: Color, deep: Color, radius: int) -> Button:
	var button := Button.new()
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color.lightened(0.06) if state == "hover" else (color.darkened(0.08) if state == "pressed" else color)
		style.border_color = edge
		style.set_border_width_all(4)
		style.border_width_bottom = 12 if state != "pressed" else 6
		style.set_corner_radius_all(radius)
		style.shadow_color = Color(deep, 0.6)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 5)
		style.anti_aliasing = true
		if state == "focus":
			style.draw_center = false
			style.border_color = Color(1, 1, 1, 0.8)
			style.shadow_size = 0
		button.add_theme_stylebox_override(state, style)
	var shine := Panel.new()
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shine_style := StyleBoxFlat.new()
	shine_style.bg_color = Color(1, 1, 1, 0.22)
	shine_style.set_corner_radius_all(radius)
	shine.add_theme_stylebox_override("panel", shine_style)
	shine.anchor_right = 1.0
	shine.offset_left = 18
	shine.offset_right = -18
	shine.offset_top = 8
	shine.offset_bottom = 30
	button.add_child(shine)
	return button


func _button_line(button: Button, separation: int) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", separation)
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_top = -4
	button.add_child(line)
	return line


## Circular "again" arrow for Play Again (there is no art for it).
func _draw_replay(icon: Control) -> void:
	var c := icon.size / 2.0 + Vector2(0, 1)
	var r := 13.0
	icon.draw_arc(c + Vector2(0, 2), r, deg_to_rad(-60), deg_to_rad(230), 24, Color(OUTLINE, 0.6), 7.0, true)
	icon.draw_arc(c, r, deg_to_rad(-60), deg_to_rad(230), 24, LIGHT_TEXT, 6.0, true)
	var tip := c + Vector2(cos(deg_to_rad(-60)), sin(deg_to_rad(-60))) * r
	icon.draw_colored_polygon(PackedVector2Array([
		tip + Vector2(-9, -6), tip + Vector2(9, -4), tip + Vector2(2, 10)]), LIGHT_TEXT)


## A small spinning ring ("updating").
func _make_spinner(size: float) -> Control:
	var spinner := Control.new()
	spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spinner.custom_minimum_size = Vector2(size, size)
	spinner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spinner.pivot_offset = Vector2(size, size) / 2.0
	spinner.draw.connect(func() -> void:
		var c := spinner.size / 2.0
		spinner.draw_arc(c, size * 0.38, 0.0, TAU, 32, Color(LILAC_TEXT, 0.25), 5.0, true)
		spinner.draw_arc(c, size * 0.38, 0.0, TAU * 0.3, 16, GOLD_TEXT, 5.0, true))
	var spin := spinner.create_tween().set_loops()
	spin.tween_property(spinner, "rotation", TAU, 0.8).from(0.0)
	return spinner


func _dim_texture() -> GradientTexture2D:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop in DIM_STOPS:
		offsets.append(stop[0])
		colors.append(Color(DIM_COLOR, stop[1]))
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	return tex


func _pill(color: Color, edge: Color, deep: Color, radius: int) -> Panel:
	var pill := Panel.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _box(color, radius, edge, 3, 0)
	style.border_width_bottom = 7
	style.shadow_color = Color(deep, 0.5)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 3)
	pill.add_theme_stylebox_override("panel", style)
	return pill


func _pop(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(1.3, 1.3)
	control.create_tween().tween_property(control, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Small helpers (same as the leaderboard's) --------------------------------

func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size


func _texture(tex: Texture2D, stretch := TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = stretch
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _box(color: Color, radius: int, edge: Color, edge_w: int, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(edge_w)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.anti_aliasing = true
	return style


func _label(text: String, size: int, color: Color, outline := Color(0, 0, 0, 0), outline_size := 0,
		font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if outline_size > 0:
		label.add_theme_color_override("font_outline_color", outline)
		label.add_theme_constant_override("outline_size", outline_size)
	return label


## 92430 -> "92,430"
static func _fmt(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out
