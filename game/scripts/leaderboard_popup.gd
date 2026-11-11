class_name LeaderboardPopup
extends Control
## The online leaderboard screen (scenes/leaderboard.tscn), part of the HUD.
## Opens from the TOP button and from the game-over panel, and pauses the game
## while open, like the settings pop-up. Data comes from the Backend autoload;
## this file only draws it (no backend, ranking or score rules live here).
##
## LAYOUT (vicky's reference image, art in assets/leaderboard/)
## - Header: back button (closes), "Leaderboard" title banner with a crown and
##   two monsters peeking out, info and edit-profile buttons.
## - Tabs: Total Ranking / Daily Ranking, on the top edge of the panel.
## - Podium: #2 left, #1 centre (tallest, crowned, glowing), #3 right. Each
##   place has a medal, and a coloured plate with the name and a score pill.
## - List: rank #4 and down, as glossy coloured rows with a big rank number,
##   framed avatar, name and score pill. Scrolls above the pinned row.
## - Pinned "You" row: the current player's rank, pinned under the list. When
##   the player is already on the podium or in the list, that entry is
##   highlighted instead and the pinned row is hidden (never shown twice).
## - Play More button (closes the board; starts a new game from game over)
##   and the "Finish a game to climb the leaderboard!" line.
## - Profile editor: opened from the edit button, the pinned row, or your own
##   highlighted row/podium spot. Choose one of the seven avatars and change
##   your name.
##
## The whole screen is built in code from the rectangles and sizes below, so
## tweak those constants to move things. All positions are in the 720x1280
## viewport.
##
## FROM GAME OVER
## The game-over screen's Leaderboard button opens this board straight away,
## even while the new score is still being sent. Until it lands
## (set_score_pending(false), from the HUD) the line under Play More says
## "Updating your rank..." with a spinner; then the board reloads by itself.
## Each time the board loads, it scrolls to your row so you see where you are.
##
## AVATARS
## The backend has no avatar field yet, so the chosen avatar is saved on this
## device (user://profile.cfg) and only you see it. Other players get a
## stable avatar picked from their player id. Daily Ranking needs a daily
## board on the server, which doesn't exist yet, so that tab says so.

## Play More was pressed (the board has already closed itself). The HUD
## starts a new game when the game-over panel is showing.
signal play_more_pressed

const TOP_LIMIT := 100
const NAME_MIN := 3
const NAME_MAX := 16
const PROFILE_PATH := "user://profile.cfg"

const AVATARS: Array[Texture2D] = [
	preload("res://assets/leaderboard/avatar_1.png"),
	preload("res://assets/leaderboard/avatar_2.png"),
	preload("res://assets/leaderboard/avatar_3.png"),
	preload("res://assets/leaderboard/avatar_4.png"),
	preload("res://assets/leaderboard/avatar_5.png"),
	preload("res://assets/leaderboard/avatar_6.png"),
	preload("res://assets/leaderboard/avatar_7.png"),
]
const MEDALS: Array[Texture2D] = [
	preload("res://assets/leaderboard/medal_1.png"),
	preload("res://assets/leaderboard/medal_2.png"),
	preload("res://assets/leaderboard/medal_3.png"),
]
const TEX_BACKGROUND := preload("res://assets/leaderboard/background.jpg")
const TEX_PANEL := preload("res://assets/leaderboard/panel.png")
const TEX_PODIUM := preload("res://assets/leaderboard/podium.png")
const TEX_TAB_ON := preload("res://assets/leaderboard/tab_on_small.png")
const TEX_TAB_OFF := preload("res://assets/leaderboard/tab_off_small.png")
const TEX_CROWN := preload("res://assets/leaderboard/crown_1.png")
const TEX_STAR := preload("res://assets/leaderboard/star.png")
const TEX_YOU := preload("res://assets/leaderboard/you_bubble.png")
const TEX_LAUREL_L := preload("res://assets/leaderboard/laurel_left.png")
const TEX_LAUREL_R := preload("res://assets/leaderboard/laurel_right.png")
const TEX_BACK := preload("res://assets/leaderboard/icon_back.png")
const TEX_INFO := preload("res://assets/leaderboard/icon_info.png")
const TEX_EDIT := preload("res://assets/leaderboard/icon_edit.png")
const TEX_CLOSE := preload("res://assets/leaderboard/icon_close.png")
## Soft rubbery 3D pieces, rendered by tools/leaderboard_art.py at 2x the
## size they are shown. RUBBER_PAD is the transparent margin (shadow / glow)
## each was rendered with, in on-screen pixels.
const TEX_TILE_BLUE := preload("res://assets/leaderboard/rubber/tile_blue.png")
const TEX_TILE_LILAC := preload("res://assets/leaderboard/rubber/tile_lilac.png")
const TEX_TILE_ME := preload("res://assets/leaderboard/rubber/tile_me.png")
const TEX_SCORE_PILL := preload("res://assets/leaderboard/rubber/score_pill.png")
const TEX_SCORE_PILL_ME := preload("res://assets/leaderboard/rubber/score_pill_me.png")
const TEX_SCORE_PILL_CREAM := preload("res://assets/leaderboard/rubber/score_pill_cream.png")
const TEX_DISC_BLUE := preload("res://assets/leaderboard/rubber/rank_disc_blue.png")
const TEX_DISC_LILAC := preload("res://assets/leaderboard/rubber/rank_disc_lilac.png")
const TEX_DISC_ME := preload("res://assets/leaderboard/rubber/rank_disc_me.png")
const TEX_PLATES: Array[Texture2D] = [
	preload("res://assets/leaderboard/rubber/plate_pink.png"),
	preload("res://assets/leaderboard/rubber/plate_purple.png"),
	preload("res://assets/leaderboard/rubber/plate_orange.png"),
]
const TEX_TITLE_BANNER := preload("res://assets/leaderboard/rubber/title_banner.png")
const TEX_BUTTON_GREEN := preload("res://assets/leaderboard/rubber/button_green.png")
const TEX_BUTTON_YELLOW := preload("res://assets/leaderboard/rubber/button_yellow.png")
const TEX_BUTTON_PURPLE := preload("res://assets/leaderboard/rubber/button_purple.png")
const TEX_FIELD := preload("res://assets/leaderboard/rubber/field.png")
## Golden aura layers behind the top three.
const TEX_AURA := preload("res://assets/leaderboard/aura/aura.png")
const TEX_RAYS := preload("res://assets/leaderboard/aura/rays.png")
const TEX_SWIRL := preload("res://assets/leaderboard/aura/swirl.png")
const TEX_SPARKLE := preload("res://assets/leaderboard/aura/sparkle.png")

## Rounded, chunky fonts (SIL Open Font License, see assets/fonts/).
const FONT_BODY := preload("res://assets/fonts/Fredoka.ttf")
const FONT_TITLE := preload("res://assets/fonts/LilitaOne-Regular.ttf")

# --- Layout -----------------------------------------------------------------

const BACK_RECT := Rect2(16, 18, 84, 84)
const INFO_RECT := Rect2(620, 18, 84, 84)
const EDIT_RECT := Rect2(628, 108, 70, 70)

const TITLE_RECT := Rect2(184, 60, 352, 100)

const PANEL_RECT := Rect2(12, 146, 696, 984)
## panel.png nine-patch margins (left, top, right, bottom) in its pixels.
const PANEL_MARGINS := [56, 124, 56, 48]

const TAB_Y := 236.0
const TAB_H := 76.0
const TAB_RECTS: Array[Rect2] = [Rect2(40, TAB_Y, 316, TAB_H), Rect2(364, TAB_Y, 316, TAB_H)]

## Where podium.png is drawn. The PODIUM_BLOCKS values are in the picture's
## own pixels (720x240) and get scaled into this rectangle.
const PODIUM_RECT := Rect2(40, 472, 640, 213)
## Per place (#1, #2, #3): x range of the block in podium.png, the y of its
## top surface, and its bottom.
const PODIUM_BLOCKS: Array[Vector4] = [
	Vector4(227, 495, 6, 201),  # gold, centre
	Vector4(26, 229, 68, 193),  # silver, left
	Vector4(491, 683, 78, 193),  # bronze, right
]
const PODIUM_AVATAR: Array[float] = [128.0, 112.0, 112.0]
## Size of the golden aura behind #1, #2 and #3.
const AURA_SIZE: Array[float] = [390.0, 300.0, 300.0]

const LIST_LEFT := 34.0
const LIST_RIGHT := 686.0
const LIST_TOP := 690.0
const LIST_BOTTOM_WITH_PIN := 1004.0
const LIST_BOTTOM_NO_PIN := 1112.0
const ROW_H := 86.0
## Row content, in the row's own pixels (keep ROW_AVATAR_CENTER on the hollow
## in the tile art, see socket in tools/leaderboard_art.py).
const ROW_RANK_CENTER := Vector2(44, 39)
const ROW_AVATAR_CENTER := Vector2(124, 40)
const ROW_NAME_X := 186.0
const ROW_SCORE_SIZE := Vector2(176, 56)
const ROW_GAP := 10

const PINNED_RECT := Rect2(28, 1016, 664, 96)

const PLAY_RECT := Rect2(170, 1138, 380, 86)
const CAPTION_Y := 1232.0

# --- Colours ----------------------------------------------------------------

const DARK_TEXT := Color(0.2, 0.1, 0.42)
const LIGHT_TEXT := Color(1, 1, 1)
const OUTLINE := Color(0.22, 0.06, 0.45)
const GOLD_TEXT := Color(1, 0.86, 0.24)

enum Tab { TOTAL, DAILY }

var _was_paused := false
var _tab := Tab.TOTAL
var _entries: Array = []
var _loaded_ok := false
var _loading := false
var _my_avatar := -1
var _press_scroll := 0
## A just-finished game's score is still on its way to the server.
var _score_pending := false
## Scroll to the player's row whenever the list is drawn (while open).
var _focus_me := false
var _caption_text: Label
var _caption_spinner: Control

var _font_bold: FontVariation
var _places: Array[Dictionary] = []
var _auras: Array[Control] = []
var _status: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _tabs: Array[Dictionary] = []
var _podium: Array[Dictionary] = []
var _pinned: Button
var _info: Control
var _editor: Control
var _editor_panel: Control
var _editor_preview: TextureRect
var _editor_choices: Array[Button] = []
var _editor_avatar := 0
var _name_edit: LineEdit
var _editor_status: Label
var _save: Button
var _saving := false


func _ready() -> void:
	visible = false
	_load_profile()
	_build()
	Backend.leaderboard_loaded.connect(_on_leaderboard_loaded)
	Backend.name_changed.connect(_on_name_changed)
	Backend.me_loaded.connect(_on_me_loaded)


func open() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	_info.visible = false
	_editor.visible = false
	_select_tab(Tab.TOTAL, false)
	_entries = []
	_loaded_ok = false
	_focus_me = true
	_update_caption()
	if Backend.is_configured():
		_loading = true
		# Ask the server who this player is (new players get a random name).
		Backend.fetch_me()
		Backend.fetch_top(TOP_LIMIT)
	else:
		_loading = false
	_render()


## Reloads the board in place (the current rows stay until the new ones come).
func refresh() -> void:
	if not visible or not Backend.is_configured():
		return
	_focus_me = true
	Backend.fetch_me()
	Backend.fetch_top(TOP_LIMIT)


## Called by the HUD while a finished game's score is being sent. When it
## lands, an open board reloads so it shows the new score and rank.
func set_score_pending(pending: bool) -> void:
	var landed := _score_pending and not pending
	_score_pending = pending
	_update_caption()
	if landed:
		refresh()


## The line under Play More: a spinner and "Updating your rank..." while a
## score is on its way, the usual tip otherwise.
func _update_caption() -> void:
	if _caption_text == null:
		return
	_caption_text.text = "Updating your rank..." if _score_pending else "Finish a game to climb the leaderboard!"
	_caption_spinner.visible = _score_pending


func close() -> void:
	GameAudio.play("click")
	_name_edit.release_focus()
	visible = false
	get_tree().paused = _was_paused


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _editor.visible:
			_close_editor()
		elif _info.visible:
			_info.visible = false
		else:
			close()


# --- Data -------------------------------------------------------------------

func _on_leaderboard_loaded(entries: Array, ok: bool) -> void:
	if not visible:
		return
	_loading = false
	_loaded_ok = ok
	_entries = entries if ok else []
	_render()


## The server's answer to "who am I": refreshes the pinned row (name, rank).
func _on_me_loaded(result: Dictionary) -> void:
	if not visible or result.is_empty():
		return
	if _editor.visible and not _name_edit.has_focus() and not _saving:
		_name_edit.text = Backend.display_name
	_render()


func _is_me(entry: Dictionary) -> bool:
	return Backend.player_id != "" and entry.get("player_id", "") == Backend.player_id


func _avatar_for(entry: Dictionary) -> Texture2D:
	if _is_me(entry):
		return AVATARS[_my_avatar_index()]
	return AVATARS[_default_avatar(str(entry.get("player_id", entry.get("display_name", ""))))]


func _my_avatar_index() -> int:
	return _my_avatar if _my_avatar >= 0 else _default_avatar(Backend.player_id)


## A stable avatar per player, so everyone looks the same on every visit
## until avatars are stored on the server.
func _default_avatar(id: String) -> int:
	return posmod(id.hash(), AVATARS.size()) if id != "" else 0


func _load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) == OK:
		_my_avatar = clampi(int(config.get_value("profile", "avatar", -1)), -1, AVATARS.size() - 1)


func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "avatar", _my_avatar)
	config.save(PROFILE_PATH)


# --- Drawing the data -------------------------------------------------------

func _render() -> void:
	_clear_rows()
	var me_shown := false

	var list: Array = _entries if _tab == Tab.TOTAL else []
	for place in 3:
		var entry: Dictionary = list[place] if place < list.size() else {}
		me_shown = _fill_podium(place, entry) or me_shown

	var my_row: Control = null
	for i in range(3, list.size()):
		var entry: Dictionary = list[i]
		var is_me := _is_me(entry)
		me_shown = me_shown or is_me
		var row := _make_row(str(i + 1), str(entry.get("display_name", "?")),
				_fmt(int(entry.get("best_score", 0))), _avatar_for(entry), is_me, i - 3, _row_width())
		if is_me:
			# PASS: a tap opens the editor while drags still scroll the list.
			row.mouse_filter = Control.MOUSE_FILTER_PASS
			row.mouse_default_cursor_shape = CURSOR_POINTING_HAND
			row.tooltip_text = "Edit your profile"
			row.gui_input.connect(_on_my_row_input)
			my_row = row
		_rows.add_child(row)
	_scroll.scroll_vertical = 0
	if _focus_me and my_row != null:
		_scroll_to_row.call_deferred(my_row)

	_status.visible = true
	if _tab == Tab.DAILY:
		_status.text = "Daily Ranking is coming soon!\nCheck Total Ranking for now."
	elif not Backend.is_configured():
		_status.text = "The online leaderboard isn't set up yet."
	elif _loading:
		_status.text = "Loading..."
	elif not _loaded_ok:
		_status.text = "Can't reach the leaderboard.\nCheck your connection."
	elif list.is_empty():
		_status.text = "No scores yet. Be the first!"
	elif list.size() <= 3:
		_status.text = "Only the podium so far.\nPlay to take a spot!"
	else:
		_status.visible = false

	# Pinned row only when the player isn't already visible above.
	_pinned.visible = not me_shown
	_scroll.size.y = (LIST_BOTTOM_WITH_PIN if _pinned.visible else LIST_BOTTOM_NO_PIN) - LIST_TOP
	_status.size.y = _scroll.size.y
	_fill_pinned()


## Returns true if this place shows the current player.
func _fill_podium(place: int, entry: Dictionary) -> bool:
	var slot: Dictionary = _podium[place]
	var empty := entry.is_empty()
	var is_me := not empty and _is_me(entry)
	(slot["avatar"] as TextureRect).texture = null if empty else _avatar_for(entry)
	(slot["empty"] as Label).visible = empty
	(slot["glow"] as Control).visible = not empty
	var name_label: Label = slot["name"]
	name_label.text = "---" if empty else str(entry.get("display_name", "?"))
	_fit_text(name_label, 27 if place == 0 else 22, 16)
	(slot["score"] as Label).text = "0" if empty else _fmt(int(entry.get("best_score", 0)))
	(slot["you"] as Control).visible = is_me
	(slot["button"] as Button).disabled = not is_me
	(slot["button"] as Button).mouse_default_cursor_shape = CURSOR_POINTING_HAND if is_me else CURSOR_ARROW
	return is_me


func _fill_pinned() -> void:
	for child in _pinned.get_children():
		_pinned.remove_child(child)
		child.queue_free()
	var on_board := Backend.my_rank > 0 and _tab == Tab.TOTAL
	var row := _make_row(str(Backend.my_rank) if on_board else "-",
			Backend.display_name if Backend.display_name != "" else "You",
			_fmt(Backend.my_best) if on_board else "-",
			AVATARS[_my_avatar_index()], true, 0, PINNED_RECT.size.x)
	row.position = Vector2(0, (PINNED_RECT.size.y - ROW_H) / 2.0)
	_pinned.add_child(row)


## One ranking row on a rubber tile: rank number on a rubber disc, framed
## avatar in the tile's hollow, name, and a score pill. Your own row is the
## purple tile with a lime glow and a "You" tag. Returns a holder Control
## (width x ROW_H) so the tag can poke out above the row.
func _make_row(rank_text: String, player_name: String, score_text: String,
		avatar_tex: Texture2D, is_me: bool, index: int, width: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, ROW_H)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lilac := index % 3 == 2
	var tile_tex: Texture2D = TEX_TILE_ME if is_me else (TEX_TILE_LILAC if lilac else TEX_TILE_BLUE)
	var pad := 30.0 if is_me else 24.0
	holder.add_child(_rubber(tile_tex, Rect2(0, 0, width, ROW_H), pad,
			Vector4((pad + 190) * 2, (pad + 40) * 2, (pad + 60) * 2, (pad + 40) * 2)))

	var disc_tex: Texture2D = TEX_DISC_ME if is_me else (TEX_DISC_LILAC if lilac else TEX_DISC_BLUE)
	var disc_rect := Rect2(ROW_RANK_CENTER - Vector2(31, 31), Vector2(62, 62))
	holder.add_child(_rubber(disc_tex, disc_rect, 10))
	var rank := _label(rank_text, 36 if rank_text.length() <= 2 else (28 if rank_text.length() == 3 else 22),
			LIGHT_TEXT, OUTLINE, 9, FONT_TITLE)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(rank, Rect2(disc_rect.position + Vector2(0, -4), disc_rect.size))
	holder.add_child(rank)

	# Avatar in its white rounded frame, sitting in the tile's hollow.
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(1, 1, 1, 0.35)
	frame_style.border_color = Color(1, 1, 1)
	frame_style.set_border_width_all(3)
	frame_style.set_corner_radius_all(18)
	frame_style.set_content_margin_all(3)
	frame_style.shadow_color = Color(0.1, 0.0, 0.3, 0.3)
	frame_style.shadow_size = 4
	frame_style.shadow_offset = Vector2(0, 2)
	frame.add_theme_stylebox_override("panel", frame_style)
	var avatar := _texture(avatar_tex)
	avatar.custom_minimum_size = Vector2(58, 58)
	frame.add_child(avatar)
	_place(frame, Rect2(ROW_AVATAR_CENTER - Vector2(32, 32), Vector2(64, 64)))
	holder.add_child(frame)

	var score_x := width - ROW_SCORE_SIZE.x - 12.0
	var name_label := _label(player_name, 30, LIGHT_TEXT if is_me else DARK_TEXT,
			OUTLINE if is_me else Color(1, 1, 1, 0.55), 6 if is_me else 3)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(name_label, Rect2(ROW_NAME_X, 0, score_x - ROW_NAME_X - 10, ROW_H - 8))
	holder.add_child(name_label)

	var pill := _score_pill(score_text, ROW_SCORE_SIZE, 30, "me" if is_me else "purple")
	pill.position = Vector2(score_x, (ROW_H - 8 - ROW_SCORE_SIZE.y) / 2.0)
	holder.add_child(pill)

	if is_me:
		var you := _texture(TEX_YOU)
		you.position = Vector2(4, -30)
		you.size = Vector2(66, 60)
		holder.add_child(you)
	return holder


## A rubber score container with a star and the score: purple with white
## text in the list ("purple" / "me"), cream with dark text on the podium.
func _score_pill(text: String, size: Vector2, font_size: int, kind: String) -> Control:
	var pill := Control.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size = size
	var light := kind == "cream"
	var tex: Texture2D = TEX_SCORE_PILL_CREAM if light else (TEX_SCORE_PILL_ME if kind == "me" else TEX_SCORE_PILL)
	var cap := (10.0 + size.y / 2.0) * 2.0
	var vert := (10.0 + size.y * 0.4) * 2.0
	pill.add_child(_rubber(tex, Rect2(Vector2.ZERO, size), 10, Vector4(cap, vert, cap, vert)))
	var star_size := size.y * 0.66
	var star := _texture(TEX_STAR)
	_place(star, Rect2(size.y * 0.32, (size.y - star_size) / 2.0 - 2.0, star_size, star_size))
	pill.add_child(star)
	var score := _label(text, font_size, DARK_TEXT if light else LIGHT_TEXT,
			Color(1, 1, 1, 0.6) if light else OUTLINE, 3 if light else 6, FONT_TITLE)
	score.name = "Score"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var text_x := size.y * 0.32 + star_size
	_place(score, Rect2(text_x, -3, size.x - text_x - size.y * 0.25, size.y))
	pill.add_child(score)
	return pill


## Width of a row in the list (the scroll area minus its side margins).
func _row_width() -> float:
	return LIST_RIGHT - LIST_LEFT - 12.0


func _clear_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()


func _on_my_row_input(event: InputEvent) -> void:
	# A tap (press and release without scrolling) opens the editor.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_scroll = _scroll.scroll_vertical
		elif absi(_scroll.scroll_vertical - _press_scroll) <= 6:
			_open_editor()


# --- Tabs -------------------------------------------------------------------

func _select_tab(tab: Tab, render := true) -> void:
	_tab = tab
	for i in _tabs.size():
		var on := i == int(tab)
		(_tabs[i]["on"] as Control).visible = on
		(_tabs[i]["off"] as Control).visible = not on
		var label: Label = _tabs[i]["label"]
		label.add_theme_color_override("font_color", DARK_TEXT if on else LIGHT_TEXT)
		label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.55) if on else OUTLINE)
		(_tabs[i]["button"] as Button).set_pressed_no_signal(on)
	if render:
		_render()


# --- Profile editor ---------------------------------------------------------

func _open_editor() -> void:
	GameAudio.play("click")
	_info.visible = false
	_editor_avatar = _my_avatar_index()
	_update_editor_avatar()
	_name_edit.text = Backend.display_name
	_name_edit.editable = Backend.is_configured()
	_name_edit.placeholder_text = "Your name" if Backend.is_configured() else "Online name needs the leaderboard"
	_editor_status.text = ""
	_saving = false
	_save.disabled = false
	_editor.visible = true
	_pop_in(_editor_panel)


func _close_editor() -> void:
	_name_edit.release_focus()
	_editor.visible = false


func _update_editor_avatar() -> void:
	_editor_preview.texture = AVATARS[_editor_avatar]
	for i in _editor_choices.size():
		_editor_choices[i].set_pressed_no_signal(i == _editor_avatar)


func _on_save_pressed() -> void:
	if _saving:
		return
	var new_name := _name_edit.text.strip_edges()
	var name_changes := Backend.is_configured() and new_name != Backend.display_name
	if name_changes and new_name.length() < NAME_MIN:
		_editor_status.text = "Name must be at least %d characters." % NAME_MIN
		return
	GameAudio.play("click")
	_my_avatar = _editor_avatar
	_save_profile()
	if not name_changes:
		_close_editor()
		_render()
		return
	_name_edit.release_focus()
	_saving = true
	_save.disabled = true
	_editor_status.text = "Saving..."
	Backend.set_display_name(new_name)


func _on_name_changed(result: Dictionary) -> void:
	if not visible or not _saving:
		return
	_saving = false
	_save.disabled = false
	if result.has("display_name"):
		_close_editor()
		_render()
		Backend.fetch_top(TOP_LIMIT)  # show the new name in the list
	elif result.has("error"):
		_editor_status.text = str(result["error"])
	else:
		_editor_status.text = "Couldn't save. Check your connection."


# --- Building the screen ----------------------------------------------------

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font_bold = FontVariation.new()
	_font_bold.base_font = FONT_BODY
	_font_bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	var ui_theme := Theme.new()
	ui_theme.default_font = _font_bold
	theme = ui_theme

	var bg := _texture(TEX_BACKGROUND, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := NinePatchRect.new()
	panel.texture = TEX_PANEL
	panel.patch_margin_left = PANEL_MARGINS[0]
	panel.patch_margin_top = PANEL_MARGINS[1]
	panel.patch_margin_right = PANEL_MARGINS[2]
	panel.patch_margin_bottom = PANEL_MARGINS[3]
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, PANEL_RECT)
	add_child(panel)

	_places = _podium_places()
	# The auras go first so the tabs, podium and winners sit in front of them.
	for place in 3:
		var aura := _make_aura((_places[place]["avatar"] as Rect2).get_center(), AURA_SIZE[place], place)
		add_child(aura)
		_auras.append(aura)
	_build_header()
	_build_tabs()
	_build_podium()
	_build_list()
	_build_pinned()
	_build_play_more()
	_build_info()
	_build_editor()


func _build_header() -> void:
	# "Leaderboard" banner (rubber) with a crown on top.
	add_child(_rubber(TEX_TITLE_BANNER, TITLE_RECT, 16))
	var title := _label("Leaderboard", 56, GOLD_TEXT, Color(0.42, 0.1, 0.55), 14, FONT_TITLE)
	title.add_theme_color_override("font_shadow_color", Color(0.3, 0.05, 0.4, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(title, Rect2(TITLE_RECT.position + Vector2(0, -6), TITLE_RECT.size))
	add_child(title)
	var crown := _texture(TEX_CROWN)
	_place(crown, Rect2(TITLE_RECT.get_center().x - 46, TITLE_RECT.position.y - 50, 92, 70))
	add_child(crown)

	var back := _icon_button(TEX_BACK, BACK_RECT, "Back")
	back.pressed.connect(close)
	var info := _icon_button(TEX_INFO, INFO_RECT, "How the leaderboard works")
	info.pressed.connect(func() -> void:
		GameAudio.play("click")
		_info.visible = true
		_pop_in(_info.get_child(1) as Control))
	var edit := _icon_button(TEX_EDIT, EDIT_RECT, "Edit profile")
	edit.pressed.connect(_open_editor)


func _build_tabs() -> void:
	var titles := ["Total Ranking", "Daily Ranking"]
	for i in 2:
		var rect: Rect2 = TAB_RECTS[i]
		var off := _pill_texture(TEX_TAB_OFF, rect)
		add_child(off)
		var on := _pill_texture(TEX_TAB_ON, rect)
		add_child(on)

		var button := Button.new()
		button.flat = true
		button.toggle_mode = true
		button.tooltip_text = titles[i]
		button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		_place(button, rect)
		var tab: Tab = Tab.TOTAL if i == 0 else Tab.DAILY
		button.pressed.connect(func() -> void:
			GameAudio.play("click")
			_select_tab(tab))
		add_child(button)

		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 10)
		_place(line, Rect2(rect.position + Vector2(0, -3), rect.size))
		add_child(line)
		var icon: Control
		if i == 0:
			icon = _texture(TEX_CROWN)
		else:
			icon = Control.new()
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.draw.connect(_draw_calendar.bind(icon))
		icon.custom_minimum_size = Vector2(44, 36)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(icon)
		var label := _label(titles[i], 30, LIGHT_TEXT, OUTLINE, 6)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(label)
		_tabs.append({"on": on, "off": off, "label": label, "button": button})


## A small calendar icon for the Daily tab (there is no art for it).
func _draw_calendar(icon: Control) -> void:
	var r := Rect2(Vector2(6, 2), Vector2(32, 32))
	icon.draw_rect(Rect2(r.position + Vector2(0, 2), r.size), Color(0.25, 0.08, 0.5, 0.5))
	var body := StyleBoxFlat.new()
	body.bg_color = Color(1, 1, 1)
	body.set_corner_radius_all(6)
	icon.draw_style_box(body, r)
	var top := StyleBoxFlat.new()
	top.bg_color = Color(0.98, 0.42, 0.62)
	top.corner_radius_top_left = 6
	top.corner_radius_top_right = 6
	icon.draw_style_box(top, Rect2(r.position, Vector2(r.size.x, 10)))
	for row in 2:
		for col in 3:
			icon.draw_rect(Rect2(r.position + Vector2(5 + col * 8, 15 + row * 8), Vector2(5, 5)), Color(0.45, 0.25, 0.8))
	icon.draw_rect(Rect2(r.position + Vector2(7, -3), Vector2(4, 7)), Color(0.45, 0.25, 0.8))
	icon.draw_rect(Rect2(r.position + Vector2(21, -3), Vector2(4, 7)), Color(0.45, 0.25, 0.8))


func _pill_texture(tex: Texture2D, rect: Rect2) -> NinePatchRect:
	var pill := NinePatchRect.new()
	pill.texture = tex
	var side := int(tex.get_height() * 0.5)
	pill.patch_margin_left = side
	pill.patch_margin_right = side
	pill.patch_margin_top = int(tex.get_height() * 0.45)
	pill.patch_margin_bottom = int(tex.get_height() * 0.45)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The art is a little taller than the tab; centre it on the tab.
	var h := float(tex.get_height())
	_place(pill, Rect2(rect.position.x, rect.get_center().y - h / 2.0, rect.size.x, h))
	return pill


## Where each podium place's block and avatar sit, from podium.png.
func _podium_places() -> Array[Dictionary]:
	var k := PODIUM_RECT.size.x / float(TEX_PODIUM.get_width())
	var places: Array[Dictionary] = []
	for place in 3:
		var block := PODIUM_BLOCKS[place]
		var left := PODIUM_RECT.position.x + block.x * k
		var right := PODIUM_RECT.position.x + block.y * k
		var top := PODIUM_RECT.position.y + block.z * k
		var bottom := PODIUM_RECT.position.y + block.w * k
		var size: float = PODIUM_AVATAR[place]
		var cx := (left + right) / 2.0
		var avatar_rect := Rect2(cx - size / 2.0, top + 22.0 - size, size, size)
		places.append({"left": left, "right": right, "top": top, "bottom": bottom, "cx": cx, "avatar": avatar_rect})
	return places


## A radiant golden aura: soft glow, slowly turning light rays, an orbiting
## swirl of light and floating sparkles. #1 gets the biggest and brightest.
func _make_aura(center: Vector2, size: float, place: int) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A little above the avatar's centre so the light crowns the winner.
	root.position = center - Vector2(0, size * 0.06)
	root.modulate.a = 1.0 if place == 0 else 0.95
	# Sparkles add light (additive); the glow and rays tint gold.
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var glow := _texture(TEX_AURA, TextureRect.STRETCH_SCALE)
	_place(glow, Rect2(-size / 2.0, -size / 2.0, size, size))
	glow.pivot_offset = glow.size / 2.0
	root.add_child(glow)
	var pulse := glow.create_tween().set_loops()
	pulse.tween_property(glow, "scale", Vector2(1.07, 1.07), 1.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "scale", Vector2(0.94, 0.94), 1.6).set_trans(Tween.TRANS_SINE)

	# Two ray layers turning opposite ways make the light shimmer.
	for layer in 2:
		var rays_size := size * (1.12 if layer == 0 else 0.86)
		var rays := _texture(TEX_RAYS, TextureRect.STRETCH_SCALE)
		_place(rays, Rect2(-rays_size / 2.0, -rays_size / 2.0, rays_size, rays_size))
		rays.pivot_offset = rays.size / 2.0
		rays.modulate = Color(1, 0.86, 0.45, 1.0 if layer == 0 else 0.6)
		root.add_child(rays)
		var turn := rays.create_tween().set_loops()
		var direction := 1.0 if layer == 0 else -1.0
		turn.tween_property(rays, "rotation", TAU * direction, 40.0 if layer == 0 else 55.0).from(0.0)

	var swirl := _texture(TEX_SWIRL, TextureRect.STRETCH_SCALE)
	_place(swirl, Rect2(-size * 0.48, size * 0.04, size * 0.96, size * 0.3))
	swirl.pivot_offset = swirl.size / 2.0
	root.add_child(swirl)
	var shimmer := swirl.create_tween().set_loops()
	shimmer.tween_property(swirl, "modulate:a", 0.5, 1.4).set_trans(Tween.TRANS_SINE)
	shimmer.tween_property(swirl, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE)

	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + place
	for i in (8 if place == 0 else 5):
		var spark := _texture(TEX_SPARKLE, TextureRect.STRETCH_SCALE)
		var s := rng.randf_range(16.0, 34.0) * size / 330.0
		var start := Vector2(rng.randf_range(-0.42, 0.42), rng.randf_range(-0.2, 0.3)) * size
		_place(spark, Rect2(start - Vector2(s, s) / 2.0, Vector2(s, s)))
		spark.modulate.a = 0.0
		spark.material = add
		root.add_child(spark)
		var rise := rng.randf_range(0.12, 0.22) * size
		var time := rng.randf_range(2.2, 3.4)
		var float_up := spark.create_tween().set_loops()
		float_up.tween_interval(rng.randf_range(0.0, 2.0))
		float_up.tween_callback(func() -> void: spark.position = start - Vector2(s, s) / 2.0)
		float_up.tween_property(spark, "modulate:a", 1.0, time * 0.3)
		float_up.parallel().tween_property(spark, "position:y", start.y - s / 2.0 - rise, time).set_trans(Tween.TRANS_SINE)
		float_up.tween_property(spark, "modulate:a", 0.0, time * 0.3)
	return root


func _build_podium() -> void:
	var podium := _texture(TEX_PODIUM)
	_place(podium, PODIUM_RECT)
	add_child(podium)
	var places := _places

	for place in 3:
		var p: Dictionary = places[place]
		var avatar_rect: Rect2 = p["avatar"]
		var size := avatar_rect.size.x
		var cx: float = p["cx"]

		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "Edit your profile"
		_place(button, avatar_rect.grow(6))
		button.pressed.connect(_open_editor)
		add_child(button)

		var avatar := _texture(null)
		_place(avatar, avatar_rect)
		add_child(avatar)
		var empty := _label("?", int(size * 0.5), LIGHT_TEXT, OUTLINE, 8, FONT_TITLE)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_place(empty, avatar_rect)
		add_child(empty)

		if place == 0:
			var crown := _texture(TEX_CROWN)
			_place(crown, Rect2(cx - 40, avatar_rect.position.y - 46, 80, 60))
			crown.rotation_degrees = 8
			add_child(crown)

		# Coloured plate on the block's front: name + score pill.
		var plate_top: float = p["top"] + (30.0 if place == 0 else 24.0)
		var plate_rect := Rect2(p["left"] + 12.0, plate_top, p["right"] - p["left"] - 24.0, p["bottom"] - plate_top - 2.0)
		add_child(_rubber(TEX_PLATES[place], plate_rect, 14, Vector4(84, 88, 84, 88)))

		var medal_h := 70.0 if place == 0 else 54.0
		var medal := _texture(MEDALS[place])
		_place(medal, Rect2(cx - medal_h * 0.66, plate_top - medal_h * 0.52, medal_h * 1.32, medal_h))
		add_child(medal)

		var you := _texture(TEX_YOU)
		_place(you, Rect2(avatar_rect.end.x - 30, avatar_rect.position.y - 18, 60, 54))
		add_child(you)

		var name_y := plate_top + medal_h * 0.5
		var name_label := _label("", 27 if place == 0 else 22, LIGHT_TEXT, OUTLINE, 7)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_place(name_label, Rect2(plate_rect.position.x + 6, name_y, plate_rect.size.x - 12, 32 if place == 0 else 28))
		add_child(name_label)

		var pill_h := 44.0 if place == 0 else 36.0
		var pill_w := minf(plate_rect.size.x - 24.0, 170.0)
		var pill := _score_pill("", Vector2(pill_w, pill_h), 30 if place == 0 else 25, "cream")
		pill.position = Vector2(cx - pill_w / 2.0, name_y + (34.0 if place == 0 else 29.0))
		add_child(pill)
		var score: Label = pill.find_child("Score", true, false)

		_podium.append({"avatar": avatar, "empty": empty, "name": name_label, "score": score,
				"you": you, "button": button, "glow": _auras[place]})


func _build_list() -> void:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_place(_scroll, Rect2(LIST_LEFT, LIST_TOP, LIST_RIGHT - LIST_LEFT, LIST_BOTTOM_WITH_PIN - LIST_TOP))
	add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Room for the row glow and the "You" tag so they aren't clipped.
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 12)
	_scroll.add_child(margin)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", ROW_GAP)
	margin.add_child(_rows)

	_status = _label("", 30, LIGHT_TEXT, OUTLINE, 7)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_status, Rect2(LIST_LEFT, LIST_TOP, LIST_RIGHT - LIST_LEFT, LIST_BOTTOM_WITH_PIN - LIST_TOP))
	add_child(_status)


func _build_pinned() -> void:
	_pinned = Button.new()
	_pinned.flat = true
	_pinned.tooltip_text = "Edit your profile"
	_pinned.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_place(_pinned, PINNED_RECT)
	_pinned.pressed.connect(_open_editor)
	add_child(_pinned)


func _build_play_more() -> void:
	var button := Button.new()
	button.tooltip_text = "Play More"
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.flat = true
	button.add_child(_rubber(TEX_BUTTON_GREEN, Rect2(Vector2.ZERO, PLAY_RECT.size), 18))
	_press_feedback(button)
	button.size = PLAY_RECT.size
	button.position = PLAY_RECT.position
	button.pivot_offset = PLAY_RECT.size / 2.0
	button.pressed.connect(func() -> void:
		close()
		play_more_pressed.emit())
	add_child(button)
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 16)
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_top = -4
	button.add_child(line)
	var text := _label("Play More", 50, LIGHT_TEXT, Color(0.14, 0.4, 0.02), 12, FONT_TITLE)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(text)
	var play := Control.new()
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.custom_minimum_size = Vector2(42, 46)
	play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	play.draw.connect(func() -> void:
		var tri := PackedVector2Array([Vector2(4, 2), Vector2(40, 23), Vector2(4, 44)])
		play.draw_colored_polygon(tri, Color(0.14, 0.4, 0.02, 0.6))
		play.draw_colored_polygon(PackedVector2Array([Vector2(6, 4), Vector2(36, 21), Vector2(6, 38)]), Color(1, 0.84, 0.15))
		play.draw_polyline(PackedVector2Array([Vector2(6, 4), Vector2(36, 21), Vector2(6, 38), Vector2(6, 4)]), Color(1, 0.96, 0.6), 2.0, true))
	line.add_child(play)
	# Breathe gently so it reads as the next step.
	var breathe := button.create_tween().set_loops()
	breathe.tween_property(button, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(button, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)

	var caption := HBoxContainer.new()
	caption.alignment = BoxContainer.ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_constant_override("separation", 10)
	_place(caption, Rect2(0, CAPTION_Y, 720, 40))
	add_child(caption)
	for part in [TEX_LAUREL_L, "spinner", "text", TEX_LAUREL_R]:
		if part is Texture2D:
			var laurel := _texture(part)
			laurel.custom_minimum_size = Vector2(22, 36)
			caption.add_child(laurel)
		elif part == "spinner":
			_caption_spinner = _make_spinner(28.0)
			caption.add_child(_caption_spinner)
		else:
			_caption_text = _label("", 24, LIGHT_TEXT, OUTLINE, 6)
			_caption_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			caption.add_child(_caption_text)
	_update_caption()


## A small spinning ring ("updating").
func _make_spinner(size: float) -> Control:
	var spinner := Control.new()
	spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spinner.custom_minimum_size = Vector2(size, size)
	spinner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spinner.pivot_offset = Vector2(size, size) / 2.0
	spinner.draw.connect(func() -> void:
		var c := spinner.size / 2.0
		spinner.draw_arc(c, size * 0.38, 0.0, TAU, 32, Color(1, 1, 1, 0.25), 4.0, true)
		spinner.draw_arc(c, size * 0.38, 0.0, TAU * 0.3, 16, GOLD_TEXT, 4.0, true))
	var spin := spinner.create_tween().set_loops()
	spin.tween_property(spinner, "rotation", TAU, 0.8).from(0.0)
	return spinner


## Scrolls the list so the player's row sits in the middle, then gives it a
## little bounce so the eye finds it.
func _scroll_to_row(row: Control) -> void:
	if not is_instance_valid(row) or not visible:
		return
	# Wait one frame so the list has laid out its rows.
	await get_tree().process_frame
	if not is_instance_valid(row):
		return
	var row_y := row.position.y + _rows.position.y
	var target := int(row_y + row.size.y / 2.0 - _scroll.size.y / 2.0)
	var bar := _scroll.get_v_scroll_bar()
	target = clampi(target, 0, maxi(0, int(bar.max_value - bar.page)))
	var tween := _scroll.create_tween()
	tween.tween_property(_scroll, "scroll_vertical", target, 0.45) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	row.pivot_offset = row.size / 2.0
	tween.tween_property(row, "scale", Vector2(1.05, 1.05), 0.12)
	tween.tween_property(row, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_info() -> void:
	_info = _modal()
	var box := _modal_panel(Rect2(60, 330, 600, 600), "How it works")
	_info.add_child(box)
	var body := _label("", 27, LIGHT_TEXT, OUTLINE, 4)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "Total Ranking lists every player's best score of all time.\n\n" \
			+ "Daily Ranking is coming soon.\n\n" \
			+ "Your rank stays pinned at the bottom. Tap it, or the pencil at the top, " \
			+ "to change your name and avatar."
	_place(body, Rect2(48, 196, 504, 370))
	box.add_child(body)
	var close_button := _icon_button(TEX_CLOSE, Rect2(600 - 116, 112, 84, 84), "Close", box)
	close_button.pressed.connect(func() -> void: _info.visible = false)


func _build_editor() -> void:
	_editor = _modal()
	_editor_panel = _modal_panel(Rect2(40, 150, 640, 980), "Edit Profile")
	_editor.add_child(_editor_panel)
	var close_button := _icon_button(TEX_CLOSE, Rect2(640 - 116, 112, 84, 84), "Close", _editor_panel)
	close_button.pressed.connect(_close_editor)

	_editor_preview = _texture(null)
	_place(_editor_preview, Rect2(245, 150, 150, 150))
	_editor_panel.add_child(_editor_preview)

	var pick := _label("Choose your avatar", 28, LIGHT_TEXT, OUTLINE, 6)
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(pick, Rect2(40, 308, 560, 40))
	_editor_panel.add_child(pick)

	# Seven avatars: four on top, three centred below.
	var choice_group := ButtonGroup.new()
	var cell := 116.0
	for i in AVATARS.size():
		var row := 0 if i < 4 else 1
		var in_row := i if row == 0 else i - 4
		var count := 4 if row == 0 else 3
		var x := 320.0 - count * cell / 2.0 + in_row * cell + 6.0
		var choice := Button.new()
		choice.toggle_mode = true
		choice.button_group = choice_group
		choice.tooltip_text = "Avatar %d" % (i + 1)
		choice.icon = AVATARS[i]
		choice.expand_icon = true
		choice.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for state in ["normal", "hover", "focus"]:
			choice.add_theme_stylebox_override(state, _box(Color(1, 1, 1, 0.08), 22, Color(1, 1, 1, 0.0), 0, 8))
		choice.add_theme_stylebox_override("pressed", _box(Color(1, 0.84, 0.22, 0.35), 22, Color(1, 0.86, 0.25), 5, 8))
		choice.add_theme_stylebox_override("hover_pressed", _box(Color(1, 0.84, 0.22, 0.35), 22, Color(1, 0.86, 0.25), 5, 8))
		_place(choice, Rect2(x, 356 + row * cell, cell - 12, cell - 12))
		var index := i
		choice.pressed.connect(func() -> void:
			GameAudio.play("click")
			_editor_avatar = index
			_update_editor_avatar())
		_editor_panel.add_child(choice)
		_editor_choices.append(choice)

	var name_title := _label("Display name", 28, LIGHT_TEXT, OUTLINE, 6)
	_place(name_title, Rect2(56, 598, 528, 40))
	_editor_panel.add_child(name_title)
	_name_edit = LineEdit.new()
	_name_edit.max_length = NAME_MAX
	_name_edit.add_theme_font_size_override("font_size", 32)
	_name_edit.add_theme_color_override("font_color", DARK_TEXT)
	_name_edit.add_theme_color_override("font_placeholder_color", Color(DARK_TEXT, 0.45))
	_name_edit.add_theme_color_override("caret_color", DARK_TEXT)
	# The rubber hollow is drawn behind the field; the field itself is clear.
	var field_rect := Rect2(56, 642, 528, 72)
	_editor_panel.add_child(_rubber(TEX_FIELD, field_rect, 12))
	var clear := StyleBoxEmpty.new()
	clear.content_margin_left = 22
	clear.content_margin_right = 22
	clear.content_margin_bottom = 4
	var focus := _box(Color(0, 0, 0, 0), 26, Color(1, 0.86, 0.25), 3, 22)
	focus.border_width_bottom = 3
	_name_edit.add_theme_stylebox_override("normal", clear)
	_name_edit.add_theme_stylebox_override("read_only", clear)
	_name_edit.add_theme_stylebox_override("focus", focus)
	_place(_name_edit, field_rect)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _on_save_pressed())
	_editor_panel.add_child(_name_edit)

	_editor_status = _label("", 24, Color(1, 0.86, 0.4), OUTLINE, 4)
	_editor_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_editor_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_editor_status, Rect2(56, 722, 528, 64))
	_editor_panel.add_child(_editor_status)

	var cancel := _pill_button("Cancel", TEX_BUTTON_PURPLE, LIGHT_TEXT, Vector2(256, 86))
	cancel.position = Vector2(56, 800)
	cancel.pressed.connect(func() -> void:
		GameAudio.play("click")
		_close_editor())
	_editor_panel.add_child(cancel)
	_save = _pill_button("Save Changes", TEX_BUTTON_YELLOW, DARK_TEXT, Vector2(268, 86))
	_save.position = Vector2(326, 800)
	_save.pressed.connect(_on_save_pressed)
	_editor_panel.add_child(_save)


## A full-screen dimmed layer that blocks taps to the screen behind it.
func _modal() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.15, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	add_child(layer)
	return layer


func _modal_panel(rect: Rect2, title: String) -> Control:
	var box := NinePatchRect.new()
	box.texture = TEX_PANEL
	box.patch_margin_left = PANEL_MARGINS[0]
	box.patch_margin_top = PANEL_MARGINS[1]
	box.patch_margin_right = PANEL_MARGINS[2]
	box.patch_margin_bottom = PANEL_MARGINS[3]
	_place(box, rect)
	var heading := _label(title, 46, GOLD_TEXT, Color(0.42, 0.1, 0.55), 12, FONT_TITLE)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(heading, Rect2(0, 26, rect.size.x, 60))
	box.add_child(heading)
	return box


func _pop_in(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(0.85, 0.85)
	control.create_tween().tween_property(control, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Small helpers ----------------------------------------------------------

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


func _icon_button(tex: Texture2D, rect: Rect2, tip: String, parent: Node = self) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = tex
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.tooltip_text = tip
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_place(button, rect)
	button.pivot_offset = button.size / 2.0
	button.button_down.connect(func() -> void: button.scale = Vector2(0.9, 0.9))
	button.button_up.connect(func() -> void:
		button.create_tween().tween_property(button, "scale", Vector2.ONE, 0.15) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	parent.add_child(button)
	return button


## A rubber button (purple or yellow) with a centred label.
func _pill_button(text: String, tex: Texture2D, font_color: Color, size: Vector2) -> Button:
	var button := Button.new()
	button.flat = true
	button.tooltip_text = text
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.size = size
	button.add_child(_rubber(tex, Rect2(Vector2.ZERO, size), 16))
	var label := _label(text, 32, font_color, OUTLINE if font_color == LIGHT_TEXT else Color(1, 1, 1, 0.6),
			6 if font_color == LIGHT_TEXT else 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(label, Rect2(0, -5, size.x, size.y))
	button.add_child(label)
	_press_feedback(button)
	return button


## Squish a rubber button while it is held down, bounce back on release.
func _press_feedback(button: BaseButton) -> void:
	button.button_down.connect(func() -> void:
		button.pivot_offset = button.size / 2.0
		button.scale = Vector2(0.94, 0.94))
	button.button_up.connect(func() -> void:
		button.create_tween().tween_property(button, "scale", Vector2.ONE, 0.18) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


## A rubber piece rendered at 2x with `pad` px of shadow/glow around it,
## drawn so its body fills rect. With margins (in the texture's pixels) it
## stretches as a nine-patch, so the rounded ends keep their shape.
func _rubber(tex: Texture2D, rect: Rect2, pad: float, margins := Vector4.ZERO) -> Control:
	var area := rect.grow(pad)
	if margins == Vector4.ZERO:
		var plain := _texture(tex, TextureRect.STRETCH_SCALE)
		_place(plain, area)
		return plain
	# A nine-patch draws its corners at texture size, so draw it at 2x and
	# scale the node down by half to get crisp, correctly sized corners.
	var patch := NinePatchRect.new()
	patch.texture = tex
	patch.patch_margin_left = int(margins.x)
	patch.patch_margin_top = int(margins.y)
	patch.patch_margin_right = int(margins.z)
	patch.patch_margin_bottom = int(margins.w)
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.position = area.position
	patch.size = area.size * 2.0
	patch.scale = Vector2(0.5, 0.5)
	return patch


func _box(color: Color, radius: int, edge: Color, edge_w: int, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(edge_w)
	style.border_width_bottom = edge_w + 2 if edge_w > 0 else 0
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
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


## Shrinks a label's font until its text fits its width (long names on
## the podium), down to min_size; past that the text is trimmed with "...".
func _fit_text(label: Label, max_size: int, min_size: int) -> void:
	var font := label.get_theme_font("font")
	var size := max_size
	while size > min_size and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > label.size.x:
		size -= 1
	label.add_theme_font_size_override("font_size", size)


## 92430 -> "92,430"
func _fmt(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out
