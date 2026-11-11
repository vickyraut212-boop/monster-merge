class_name LeaderboardPopup
extends Control
## The online leaderboard screen (scenes/leaderboard.tscn), part of the HUD.
## Opens from the TOP button and from the game-over panel, and pauses the game
## while open, like the settings pop-up. Data comes from the Backend autoload;
## this file only draws it (no backend, ranking or score rules live here).
##
## LAYOUT (vicky's approved compact wireframe, art in assets/leaderboard/)
## - Header: back button (closes), Monster Merge logo, edit-profile and info
##   buttons.
## - Podium: #2 left, #1 centre (tallest), #3 right. Each place shows the
##   player's avatar, crown, name and score.
## - Tabs: Total Ranking / Daily Ranking.
## - List: rank #4 and down, scrolls between the tabs and the pinned row.
## - Pinned "YOU" row: the current player's rank, pinned at the bottom. When
##   the player is already on the podium or in the list, that entry is
##   highlighted instead and the pinned row is hidden (never shown twice).
## - Profile editor: opened from the edit button, the pinned row, or your own
##   highlighted row. Choose one of the seven avatars and change your name.
##
## The whole screen is built in code from the rectangles and sizes below, so
## tweak those constants to move things. All positions are in the 720x1280
## viewport.
##
## AVATARS
## The backend has no avatar field yet, so the chosen avatar is saved on this
## device (user://profile.cfg) and only you see it. Other players get a
## stable avatar picked from their player id. Daily Ranking needs a daily
## board on the server, which doesn't exist yet, so that tab says so.

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
const CROWNS: Array[Texture2D] = [
	preload("res://assets/leaderboard/crown_1.png"),
	preload("res://assets/leaderboard/crown_2.png"),
	preload("res://assets/leaderboard/crown_3.png"),
]
## Round number badges for ranks 4-10. Ranks past 10 get a drawn circle.
const RANK_BADGES: Array[Texture2D] = [
	preload("res://assets/leaderboard/rank_4.png"),
	preload("res://assets/leaderboard/rank_5.png"),
	preload("res://assets/leaderboard/rank_6.png"),
	preload("res://assets/leaderboard/rank_7.png"),
	preload("res://assets/leaderboard/rank_8.png"),
	preload("res://assets/leaderboard/rank_9.png"),
	preload("res://assets/leaderboard/rank_10.png"),
]
const TEX_BACKGROUND := preload("res://assets/leaderboard/background.jpg")
const TEX_LOGO := preload("res://assets/leaderboard/logo.png")
const TEX_PANEL := preload("res://assets/leaderboard/panel.png")
const TEX_PODIUM := preload("res://assets/leaderboard/podium.png")
const TEX_PINNED := preload("res://assets/leaderboard/pinned_row.png")
const TEX_TAB_ON := preload("res://assets/leaderboard/tab_selected.png")
const TEX_TAB_OFF := preload("res://assets/leaderboard/tab_unselected.png")
const TEX_STAR := preload("res://assets/leaderboard/star.png")
const TEX_YOU := preload("res://assets/leaderboard/you_bubble.png")
const TEX_TROPHY := preload("res://assets/leaderboard/trophy.png")
const TEX_BACK := preload("res://assets/leaderboard/icon_back.png")
const TEX_INFO := preload("res://assets/leaderboard/icon_info.png")
const TEX_EDIT := preload("res://assets/leaderboard/icon_edit.png")
const TEX_CLOSE := preload("res://assets/leaderboard/icon_close.png")

# --- Layout -----------------------------------------------------------------

const HEADER_BUTTON := 84.0
const BACK_POS := Vector2(22, 26)
const EDIT_POS := Vector2(526, 26)
const INFO_POS := Vector2(614, 26)
const LOGO_RECT := Rect2(228, 6, 264, 187)

## Where podium.png is drawn. The PODIUM_* rectangles below are in the
## picture's own pixels (720x240) and get scaled into this rectangle.
const PODIUM_RECT := Rect2(30, 352, 660, 220)
## Per place (#1, #2, #3): x range of the block in podium.png, the y of its
## top surface, and its bottom (for reference).
const PODIUM_BLOCKS: Array[Vector4] = [
	Vector4(227, 495, 6, 201),  # gold, centre
	Vector4(26, 229, 68, 193),  # silver, left
	Vector4(491, 683, 78, 193),  # bronze, right
]
const PODIUM_AVATAR: Array[float] = [116.0, 92.0, 92.0]

const PANEL_RECT := Rect2(8, 470, 704, 802)
## panel.png nine-patch margins (left, top, right, bottom) in its pixels.
const PANEL_MARGINS := [56, 124, 56, 48]

const TAB_W := 300.0
const TAB_Y := 586.0
const TAB_X: Array[float] = [48.0, 372.0]
## The pill inside tab_selected.png starts this far down (the crown sits
## above it) and is this tall, in the picture's pixels (360 wide).
const TAB_ON_PILL_TOP := 64.0
const TAB_PILL_H := 121.0

const LIST_LEFT := 38.0
const LIST_RIGHT := 682.0
const LIST_GAP_BELOW_TABS := 12.0
const LIST_BOTTOM_WITH_PIN := 1094.0
const LIST_BOTTOM_NO_PIN := 1240.0
const ROW_H := 76.0
const ROW_GAP := 8

const PINNED_RECT := Rect2(20, 1082, 680, 181)
## Slots in pinned_row.png's own pixels (720x192).
const PIN_RANK_CENTER := Vector2(85, 123)
const PIN_AVATAR_CENTER := Vector2(188, 123)
const PIN_AVATAR_SIZE := 64.0
const PIN_NAME_RECT := Rect2(250, 101, 236, 48)
const PIN_SCORE_RECT := Rect2(556, 101, 124, 48)

const DARK_TEXT := Color(0.27, 0.11, 0.5)
const LIGHT_TEXT := Color(1, 1, 1)
const OUTLINE := Color(0.2, 0.06, 0.42)
const ROW_COLOR := Color(0.95, 0.92, 1.0, 0.96)
const ROW_EDGE := Color(0.71, 0.6, 0.95)
const MY_ROW_COLOR := Color(1.0, 0.84, 0.22)
const MY_ROW_EDGE := Color(0.93, 0.55, 0.06)

enum Tab { TOTAL, DAILY }

var _was_paused := false
var _tab := Tab.TOTAL
var _entries: Array = []
var _loaded_ok := false
var _loading := false
var _my_avatar := -1

var _status: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _tabs: Array[Dictionary] = []
var _podium: Array[Dictionary] = []
var _pinned: Control
var _pin_rank: Label
var _pin_avatar: TextureRect
var _pin_name: Label
var _pin_score: Label
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
	if Backend.is_configured():
		_loading = true
		# Ask the server who this player is (new players get a random name).
		Backend.fetch_me()
		Backend.fetch_top(TOP_LIMIT)
	else:
		_loading = false
	_render()


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
	if _my_avatar < 0:
		_my_avatar = _default_avatar(Backend.player_id)
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

	for i in range(3, list.size()):
		var entry: Dictionary = list[i]
		var is_me := _is_me(entry)
		me_shown = me_shown or is_me
		_rows.add_child(_make_row(i + 1, entry, is_me))
	_scroll.scroll_vertical = 0

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
	_scroll.offset_bottom = LIST_BOTTOM_WITH_PIN if _pinned.visible else LIST_BOTTOM_NO_PIN
	_status.offset_bottom = _scroll.offset_bottom
	_fill_pinned()


## Returns true if this place shows the current player.
func _fill_podium(place: int, entry: Dictionary) -> bool:
	var slot: Dictionary = _podium[place]
	var empty := entry.is_empty()
	var is_me := not empty and _is_me(entry)
	(slot["avatar"] as TextureRect).texture = null if empty else _avatar_for(entry)
	(slot["avatar"] as TextureRect).modulate = Color.WHITE
	(slot["empty"] as Label).visible = empty
	(slot["name"] as Label).text = "---" if empty else str(entry.get("display_name", "?"))
	(slot["score"] as Label).text = "0" if empty else _fmt(int(entry.get("best_score", 0)))
	(slot["you"] as Control).visible = is_me
	(slot["button"] as Button).disabled = not is_me
	(slot["button"] as Button).mouse_default_cursor_shape = CURSOR_POINTING_HAND if is_me else CURSOR_ARROW
	return is_me


func _fill_pinned() -> void:
	var on_board := Backend.my_rank > 0 and _tab == Tab.TOTAL
	_pin_rank.text = str(Backend.my_rank) if on_board else "-"
	_pin_rank.add_theme_font_size_override("font_size", 30 if _pin_rank.text.length() <= 2 else (24 if _pin_rank.text.length() == 3 else 18))
	_pin_avatar.texture = AVATARS[_my_avatar_index()]
	_pin_name.text = Backend.display_name if Backend.display_name != "" else "You"
	_pin_score.text = _fmt(Backend.my_best) if on_board else "-"


func _make_row(rank: int, entry: Dictionary, is_me: bool) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size.y = ROW_H
	# PASS: taps reach the row (your own row opens the editor) while drags
	# still scroll the list.
	row.mouse_filter = Control.MOUSE_FILTER_PASS if is_me else Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = MY_ROW_COLOR if is_me else ROW_COLOR
	style.border_color = MY_ROW_EDGE if is_me else ROW_EDGE
	style.border_width_bottom = 5
	style.border_width_top = 0 if not is_me else 3
	style.border_width_left = 0 if not is_me else 3
	style.border_width_right = 0 if not is_me else 3
	if is_me:
		style.border_color = Color(1, 0.97, 0.7)
		style.shadow_color = Color(1, 0.75, 0.1, 0.55)
		style.shadow_size = 8
	style.set_corner_radius_all(24)
	style.content_margin_left = 14
	style.content_margin_right = 20
	row.add_theme_stylebox_override("panel", style)
	if is_me:
		row.gui_input.connect(_on_my_row_input)
		row.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		row.tooltip_text = "Edit your profile"

	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 14)
	row.add_child(line)

	line.add_child(_rank_badge(rank))

	var avatar := _texture(_avatar_for(entry))
	avatar.custom_minimum_size = Vector2(58, 58)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(avatar)

	var name_label := _label(str(entry.get("display_name", "?")), 28, DARK_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(name_label)

	if is_me:
		var you := _texture(TEX_YOU)
		you.custom_minimum_size = Vector2(62, 56)
		you.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(you)

	var star := _texture(TEX_STAR)
	star.custom_minimum_size = Vector2(36, 36)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(star)

	var score := _label(_fmt(int(entry.get("best_score", 0))), 28, DARK_TEXT)
	score.custom_minimum_size.x = 112
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(score)
	return row


func _rank_badge(rank: int) -> Control:
	if rank - 4 < RANK_BADGES.size():
		var badge := _texture(RANK_BADGES[rank - 4])
		badge.custom_minimum_size = Vector2(56, 56)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return badge
	# Ranks past 10: a circle drawn to match the badge art.
	var circle := PanelContainer.new()
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.custom_minimum_size = Vector2(56, 56)
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.38, 0.15, 0.78)
	style.border_color = Color(0.68, 0.5, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(28)
	circle.add_theme_stylebox_override("panel", style)
	var label := _label(str(rank), 22 if rank < 100 else 18, LIGHT_TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	circle.add_child(label)
	return circle


func _clear_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()


func _on_my_row_input(event: InputEvent) -> void:
	# A tap (press and release without scrolling) opens the editor.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed and not _scroll_moved_since_press():
		_open_editor()
	elif event is InputEventMouseButton and event.pressed:
		_press_scroll = _scroll.scroll_vertical


var _press_scroll := 0


func _scroll_moved_since_press() -> bool:
	return absi(_scroll.scroll_vertical - _press_scroll) > 6


# --- Tabs -------------------------------------------------------------------

func _select_tab(tab: Tab, render := true) -> void:
	_tab = tab
	for i in _tabs.size():
		var on := i == int(tab)
		(_tabs[i]["on"] as Control).visible = on
		(_tabs[i]["off"] as Control).visible = not on
		(_tabs[i]["label"] as Label).add_theme_color_override("font_color", DARK_TEXT if on else LIGHT_TEXT)
		(_tabs[i]["label"] as Label).add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.6) if on else OUTLINE)
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

	var bg := _texture(TEX_BACKGROUND, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Panel behind everything else; its wavy top hides behind the podium.
	var panel := NinePatchRect.new()
	panel.texture = TEX_PANEL
	panel.patch_margin_left = PANEL_MARGINS[0]
	panel.patch_margin_top = PANEL_MARGINS[1]
	panel.patch_margin_right = PANEL_MARGINS[2]
	panel.patch_margin_bottom = PANEL_MARGINS[3]
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, PANEL_RECT)
	add_child(panel)

	_build_podium()
	_build_header()
	_build_list()
	_build_tabs()
	_build_pinned()
	_build_info()
	_build_editor()


func _build_header() -> void:
	var logo := _texture(TEX_LOGO)
	_place(logo, LOGO_RECT)
	add_child(logo)
	var back := _icon_button(TEX_BACK, BACK_POS, "Back")
	back.pressed.connect(close)
	var edit := _icon_button(TEX_EDIT, EDIT_POS, "Edit profile")
	edit.pressed.connect(_open_editor)
	var info := _icon_button(TEX_INFO, INFO_POS, "How the leaderboard works")
	info.pressed.connect(func() -> void:
		GameAudio.play("click")
		_info.visible = true
		_pop_in(_info.get_child(1) as Control))


func _build_podium() -> void:
	var podium := _texture(TEX_PODIUM)
	_place(podium, PODIUM_RECT)
	add_child(podium)
	var k := PODIUM_RECT.size.x / float(TEX_PODIUM.get_width())
	for place in 3:
		var block := PODIUM_BLOCKS[place]
		var left := PODIUM_RECT.position.x + block.x * k
		var right := PODIUM_RECT.position.x + block.y * k
		var top := PODIUM_RECT.position.y + block.z * k
		var cx := (left + right) / 2.0
		var size: float = PODIUM_AVATAR[place]
		# Avatar stands on the block's top surface, crown on its head.
		var avatar_rect := Rect2(cx - size / 2.0, top + 16.0 - size, size, size)

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

		var empty := _label("?", int(size * 0.5), LIGHT_TEXT, OUTLINE, 8)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_place(empty, avatar_rect)
		add_child(empty)

		var crown_h := size * 0.56
		var crown := _texture(CROWNS[place])
		_place(crown, Rect2(cx - crown_h * 0.7, avatar_rect.position.y - crown_h + 8.0, crown_h * 1.4, crown_h))
		add_child(crown)

		var you := _texture(TEX_YOU)
		_place(you, Rect2(avatar_rect.end.x - 26, avatar_rect.position.y - 20, 56, 50))
		add_child(you)

		# Name and score on the block's front face (inside the laurels on #1).
		var face_top := top + (36.0 if place == 0 else 26.0)
		var text_w := (right - left) - (80.0 if place == 0 else 24.0)
		var name_label := _label("", 22 if place == 0 else 20, DARK_TEXT, Color(1, 1, 1, 0.7), 4)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_place(name_label, Rect2(cx - text_w / 2.0, face_top, text_w, 32))
		add_child(name_label)

		var score_row := HBoxContainer.new()
		score_row.alignment = BoxContainer.ALIGNMENT_CENTER
		score_row.add_theme_constant_override("separation", 4)
		score_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(score_row, Rect2(cx - text_w / 2.0, face_top + 32.0, text_w, 36))
		add_child(score_row)
		var star := _texture(TEX_STAR)
		star.custom_minimum_size = Vector2(28, 28) if place else Vector2(32, 32)
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		score_row.add_child(star)
		var score := _label("", 28 if place == 0 else 24, DARK_TEXT, Color(1, 1, 1, 0.7), 4)
		score_row.add_child(score)
		_podium.append({"avatar": avatar, "empty": empty, "name": name_label, "score": score,
				"you": you, "button": button})


func _build_tabs() -> void:
	var k := TAB_W / float(TEX_TAB_ON.get_width())
	var pill_h := TAB_PILL_H * k
	var titles := ["Total Ranking", "Daily Ranking"]
	for i in 2:
		var x: float = TAB_X[i]
		var off := _texture(TEX_TAB_OFF, TextureRect.STRETCH_SCALE)
		var off_h := TEX_TAB_OFF.get_height() * k
		_place(off, Rect2(x, TAB_Y + (pill_h - off_h) / 2.0, TAB_W, off_h))
		add_child(off)
		var on := _texture(TEX_TAB_ON, TextureRect.STRETCH_SCALE)
		_place(on, Rect2(x, TAB_Y - TAB_ON_PILL_TOP * k, TAB_W, TEX_TAB_ON.get_height() * k))
		add_child(on)

		var button := Button.new()
		button.flat = true
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = titles[i]
		_place(button, Rect2(x, TAB_Y, TAB_W, pill_h))
		var tab: Tab = Tab.TOTAL if i == 0 else Tab.DAILY
		button.pressed.connect(func() -> void:
			GameAudio.play("click")
			_select_tab(tab))
		add_child(button)

		var label := _label(titles[i], 27, LIGHT_TEXT, OUTLINE, 6)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_place(label, Rect2(x, TAB_Y - 4, TAB_W, pill_h))
		add_child(label)
		_tabs.append({"on": on, "off": off, "label": label, "button": button})


func _build_list() -> void:
	var top := TAB_Y + TAB_PILL_H * TAB_W / float(TEX_TAB_ON.get_width()) + LIST_GAP_BELOW_TABS
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_place(_scroll, Rect2(LIST_LEFT, top, LIST_RIGHT - LIST_LEFT, LIST_BOTTOM_WITH_PIN - top))
	add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", ROW_GAP)
	_scroll.add_child(_rows)

	_status = _label("", 28, LIGHT_TEXT, OUTLINE, 6)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_status, Rect2(LIST_LEFT, top, LIST_RIGHT - LIST_LEFT, LIST_BOTTOM_WITH_PIN - top))
	add_child(_status)


func _build_pinned() -> void:
	_pinned = Button.new()
	(_pinned as Button).flat = true
	_pinned.tooltip_text = "Edit your profile"
	_pinned.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_place(_pinned, PINNED_RECT)
	(_pinned as Button).pressed.connect(_open_editor)
	add_child(_pinned)
	var art := _texture(TEX_PINNED, TextureRect.STRETCH_SCALE)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pinned.add_child(art)

	var k := PINNED_RECT.size.x / float(TEX_PINNED.get_width())
	_pin_rank = _label("", 30, LIGHT_TEXT, OUTLINE, 6)
	_pin_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pin_rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_pin_rank, Rect2(PIN_RANK_CENTER * k - Vector2(34, 26), Vector2(68, 52)))
	_pinned.add_child(_pin_rank)

	_pin_avatar = _texture(null)
	var a := PIN_AVATAR_SIZE * k
	_place(_pin_avatar, Rect2(PIN_AVATAR_CENTER * k - Vector2(a, a) / 2.0, Vector2(a, a)))
	_pinned.add_child(_pin_avatar)

	_pin_name = _label("", 28, LIGHT_TEXT, OUTLINE, 6)
	_pin_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pin_name.clip_text = true
	_pin_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(_pin_name, Rect2(PIN_NAME_RECT.position * k, PIN_NAME_RECT.size * k))
	_pinned.add_child(_pin_name)

	_pin_score = _label("", 28, LIGHT_TEXT, OUTLINE, 6)
	_pin_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pin_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_pin_score, Rect2(PIN_SCORE_RECT.position * k, PIN_SCORE_RECT.size * k))
	_pinned.add_child(_pin_score)


func _build_info() -> void:
	_info = _modal()
	var box := _modal_panel(Rect2(60, 330, 600, 600), "How it works")
	_info.add_child(box)
	var body := _label("", 26, LIGHT_TEXT, OUTLINE, 4)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "Total Ranking lists every player's best score of all time.\n\n" \
			+ "Daily Ranking is coming soon.\n\n" \
			+ "Your rank stays pinned at the bottom. Tap it, or the pencil at the top, " \
			+ "to change your name and avatar."
	_place(body, Rect2(48, 196, 504, 370))
	box.add_child(body)
	var close_button := _icon_button(TEX_CLOSE, Vector2(600 - 116, 112), "Close", box)
	close_button.pressed.connect(func() -> void: _info.visible = false)


func _build_editor() -> void:
	_editor = _modal()
	_editor_panel = _modal_panel(Rect2(40, 150, 640, 980), "Edit Profile")
	_editor.add_child(_editor_panel)
	var close_button := _icon_button(TEX_CLOSE, Vector2(640 - 116, 112), "Close", _editor_panel)
	close_button.pressed.connect(_close_editor)

	_editor_preview = _texture(null)
	_place(_editor_preview, Rect2(245, 150, 150, 150))
	_editor_panel.add_child(_editor_preview)

	var pick := _label("Choose your avatar", 26, LIGHT_TEXT, OUTLINE, 5)
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(pick, Rect2(40, 312, 560, 36))
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

	var name_title := _label("Display name", 26, LIGHT_TEXT, OUTLINE, 5)
	_place(name_title, Rect2(56, 600, 528, 36))
	_editor_panel.add_child(name_title)
	_name_edit = LineEdit.new()
	_name_edit.max_length = NAME_MAX
	_name_edit.add_theme_font_size_override("font_size", 30)
	_name_edit.add_theme_color_override("font_color", DARK_TEXT)
	_name_edit.add_theme_color_override("font_placeholder_color", Color(DARK_TEXT, 0.45))
	_name_edit.add_theme_color_override("caret_color", DARK_TEXT)
	_name_edit.add_theme_stylebox_override("normal", _box(ROW_COLOR, 22, ROW_EDGE, 3, 18))
	_name_edit.add_theme_stylebox_override("focus", _box(Color(1, 1, 1), 22, Color(1, 0.86, 0.25), 4, 18))
	_name_edit.add_theme_stylebox_override("read_only", _box(Color(ROW_COLOR, 0.6), 22, ROW_EDGE, 3, 18))
	_place(_name_edit, Rect2(56, 642, 528, 72))
	_name_edit.text_submitted.connect(func(_text: String) -> void: _on_save_pressed())
	_editor_panel.add_child(_name_edit)

	_editor_status = _label("", 24, Color(1, 0.86, 0.4), OUTLINE, 4)
	_editor_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_editor_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_editor_status, Rect2(56, 722, 528, 64))
	_editor_panel.add_child(_editor_status)

	var cancel := _pill_button("Cancel", Color(0.45, 0.22, 0.85), Color(0.75, 0.6, 1.0), LIGHT_TEXT)
	_place(cancel, Rect2(56, 800, 240, 86))
	cancel.pressed.connect(func() -> void:
		GameAudio.play("click")
		_close_editor())
	_editor_panel.add_child(cancel)
	_save = _pill_button("Save Changes", Color(1, 0.8, 0.15), Color(1, 0.95, 0.6), DARK_TEXT)
	_place(_save, Rect2(316, 800, 268, 86))
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
	var heading := _label(title, 38, Color(1, 0.86, 0.3), OUTLINE, 10)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(heading, Rect2(0, 30, rect.size.x, 56))
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


func _icon_button(tex: Texture2D, pos: Vector2, tip: String, parent: Node = self) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = tex
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.tooltip_text = tip
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_place(button, Rect2(pos, Vector2(HEADER_BUTTON, HEADER_BUTTON)))
	button.pivot_offset = button.size / 2.0
	button.button_down.connect(func() -> void: button.scale = Vector2(0.9, 0.9))
	button.button_up.connect(func() -> void:
		button.create_tween().tween_property(button, "scale", Vector2.ONE, 0.15) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	parent.add_child(button)
	return button


func _pill_button(text: String, color: Color, edge: Color, font_color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", Color(font_color, 0.5))
	button.add_theme_stylebox_override("normal", _box(color, 43, edge, 4, 12))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.08), 43, edge, 4, 12))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.1), 43, edge, 4, 12))
	button.add_theme_stylebox_override("disabled", _box(Color(color, 0.5), 43, edge, 4, 12))
	button.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), 43, Color(1, 1, 1), 3, 12))
	return button


func _box(color: Color, radius: int, edge: Color, edge_w: int, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(edge_w)
	style.border_width_bottom = edge_w + 2 if edge_w > 0 else 0
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


func _label(text: String, size: int, color: Color, outline := Color(0, 0, 0, 0), outline_size := 0) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if outline_size > 0:
		label.add_theme_color_override("font_outline_color", outline)
		label.add_theme_constant_override("outline_size", outline_size)
	return label


## 92430 -> "92,430"
func _fmt(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out
