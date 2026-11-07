class_name LeaderboardPopup
extends Control
## The online leaderboard pop-up (scenes/leaderboard.tscn), part of the HUD.
## Shows the all-time top 100 with the player's own row highlighted, the
## player's rank if they are further down, and a box to change their name.
## Opens from the trophy button and from the game-over panel. Pauses the game
## while open, like the settings pop-up. Data comes from the Backend autoload.

const TOP_LIMIT := 100
const NAME_MIN := 3

const ROW_COLOR := Color(1, 1, 1, 0.06)
const MY_ROW_COLOR := Color(1, 0.82, 0.3, 0.3)
const MEDAL_COLORS: Array[Color] = [Color(1, 0.84, 0.3), Color(0.82, 0.86, 0.92), Color(0.9, 0.6, 0.35)]

@onready var _panel: Control = $Panel
@onready var _status: Label = $Panel/Box/Status
@onready var _scroll: ScrollContainer = $Panel/Box/Scroll
@onready var _rows: VBoxContainer = $Panel/Box/Scroll/Rows
@onready var _my_rank: Label = $Panel/Box/MyRank
@onready var _name_edit: LineEdit = $Panel/Box/NameRow/NameEdit
@onready var _save: Button = $Panel/Box/NameRow/Save
@onready var _name_status: Label = $Panel/Box/NameStatus

var _was_paused := false


func _ready() -> void:
	visible = false
	($Panel/Box/Header/Close as Button).pressed.connect(close)
	_save.pressed.connect(_on_save_pressed)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _on_save_pressed())
	Backend.leaderboard_loaded.connect(_on_leaderboard_loaded)
	Backend.name_changed.connect(_on_name_changed)
	Backend.me_loaded.connect(_on_me_loaded)


func open() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_panel.scale = Vector2(0.85, 0.85)
	_panel.create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_clear_rows()
	_name_edit.text = Backend.display_name
	_name_status.text = ""
	_save.disabled = false
	_my_rank.text = ""
	var online := Backend.is_configured()
	_name_edit.editable = online
	_save.disabled = not online
	if online:
		_status.text = "Loading..."
		_status.visible = true
		# Ask the server who this player is (new players get a random name).
		_name_edit.placeholder_text = "Loading name..."
		Backend.fetch_me()
		Backend.fetch_top(TOP_LIMIT)
	else:
		_status.text = "The online leaderboard isn't set up yet."
		_status.visible = true


func close() -> void:
	GameAudio.play("click")
	_name_edit.release_focus()
	visible = false
	get_tree().paused = _was_paused


func _on_leaderboard_loaded(entries: Array, ok: bool) -> void:
	if not visible:
		return
	_clear_rows()
	if not ok:
		_status.text = "Can't reach the leaderboard. Check your connection."
		_status.visible = true
		_show_my_rank(false)
		return
	if entries.is_empty():
		_status.text = "No scores yet. Be the first!"
		_status.visible = true
		_show_my_rank(false)
		return

	_status.visible = false
	var found_me := false
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var is_me: bool = Backend.player_id != "" and entry.get("player_id", "") == Backend.player_id
		found_me = found_me or is_me
		_rows.add_child(_make_row(i + 1, str(entry.get("display_name", "?")), int(entry.get("best_score", 0)), is_me))
	_scroll.scroll_vertical = 0
	_show_my_rank(found_me)


## The server's answer to "who am I": put the real name in the box (unless
## the player is typing) and refresh the rank line.
func _on_me_loaded(result: Dictionary) -> void:
	if not visible:
		return
	_name_edit.placeholder_text = "Your name"
	if result.is_empty():
		return
	if not _name_edit.has_focus() and not _save.disabled:
		_name_edit.text = Backend.display_name
	_show_my_rank(_my_row_shown())


func _my_row_shown() -> bool:
	for row in _rows.get_children():
		if row.has_meta("is_me") and row.get_meta("is_me"):
			return true
	return false


## The player's own rank under the list, when they are not in the top 100
## (from the server, or their last score submit).
func _show_my_rank(in_list: bool) -> void:
	if in_list:
		_my_rank.text = "You're on the board!"
	elif Backend.my_rank > 0:
		_my_rank.text = "You: #%d of %d  -  best %d" % [Backend.my_rank, Backend.total_players, Backend.my_best]
	else:
		_my_rank.text = "Finish a game to get on the board."


func _make_row(rank: int, player_name: String, best_score: int, is_me: bool) -> Control:
	var row := PanelContainer.new()
	row.set_meta("is_me", is_me)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let drags scroll the list
	var style := StyleBoxFlat.new()
	style.bg_color = MY_ROW_COLOR if is_me else ROW_COLOR
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", style)

	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)

	var rank_color := MEDAL_COLORS[rank - 1] if rank <= MEDAL_COLORS.size() else Color(1, 1, 1, 0.7)
	var rank_label := _row_label("#%d" % rank, rank_color)
	rank_label.custom_minimum_size.x = 90
	line.add_child(rank_label)

	var name_label := _row_label(player_name + ("  (you)" if is_me else ""), Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(name_label)

	var score_label := _row_label(str(best_score), Color(1, 0.85, 0.4))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(score_label)
	return row


func _row_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	return label


func _clear_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()


func _on_save_pressed() -> void:
	var new_name := _name_edit.text.strip_edges()
	if new_name == Backend.display_name and new_name != "":
		_name_status.text = "That's already your name."
		return
	if new_name.length() < NAME_MIN:
		_name_status.text = "Name must be at least %d characters." % NAME_MIN
		return
	GameAudio.play("click")
	_name_edit.release_focus()
	_save.disabled = true
	_name_status.text = "Saving..."
	Backend.set_display_name(new_name)


func _on_name_changed(result: Dictionary) -> void:
	if not visible:
		return
	_save.disabled = false
	if result.has("display_name"):
		_name_edit.text = result["display_name"]
		_name_status.text = "Saved!"
		Backend.fetch_top(TOP_LIMIT)  # show the new name in the list
	elif result.has("error"):
		_name_status.text = str(result["error"])
	else:
		_name_status.text = "Couldn't save. Check your connection."
