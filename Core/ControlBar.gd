extends CanvasLayer

## Persistent top control bar shown on every scene. A single "菜单" button opens a
## small panel with four actions: pause/resume, restart the whole run from the
## beginning, save & quit, and quit without saving. Built entirely in code and
## registered as an autoload so it floats above whatever scene is active.
##
## Runs with PROCESS_MODE_ALWAYS so the bar (and the pause overlay) keep working
## while the game tree is paused.

var _paused: bool = false
var _paused_streams: Array = []

var _menu_btn: Button
var _panel: PanelContainer
var _pause_btn: Button
var _restart_btn: Button
var _save_quit_btn: Button
var _nosave_quit_btn: Button
var _pause_overlay: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	# Pause overlay (full screen, blocks input while paused).
	_pause_overlay = ColorRect.new()
	_pause_overlay.color = Color(0, 0, 0, 0.6)
	_pause_overlay.anchor_right = 1.0
	_pause_overlay.anchor_bottom = 1.0
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.visible = false
	add_child(_pause_overlay)

	var pause_label := Label.new()
	pause_label.text = "已暂停\n（点击右上角「菜单」→ 恢复）"
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_label.add_theme_font_size_override("font_size", 36)
	pause_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(pause_label)

	# "菜单" button, pinned to the top-right corner.
	_menu_btn = Button.new()
	_menu_btn.text = "菜单"
	_menu_btn.anchor_left = 1.0
	_menu_btn.anchor_right = 1.0
	_menu_btn.offset_left = -104.0
	_menu_btn.offset_right = -16.0
	_menu_btn.offset_top = 12.0
	_menu_btn.offset_bottom = 48.0
	_menu_btn.pressed.connect(_on_menu_pressed)
	add_child(_menu_btn)

	# Popup panel with the four actions, just under the button.
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -224.0
	_panel.offset_right = -16.0
	_panel.offset_top = 56.0
	_panel.visible = false
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_pause_btn = _make_menu_button("暂停", _on_pause_pressed)
	vbox.add_child(_pause_btn)
	_restart_btn = _make_menu_button("重来", _on_restart_pressed)
	vbox.add_child(_restart_btn)
	_save_quit_btn = _make_menu_button("保存进度退出", _on_save_quit_pressed)
	vbox.add_child(_save_quit_btn)
	_nosave_quit_btn = _make_menu_button("不保存进度退出", _on_nosave_quit_pressed)
	vbox.add_child(_nosave_quit_btn)


func _make_menu_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(196, 40)
	b.pressed.connect(handler)
	return b


func _on_menu_pressed() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh_panel()


## Enable game-only actions only while a game is in progress.
func _refresh_panel() -> void:
	var in_game: bool = GameManager.is_in_game()
	_pause_btn.disabled = not in_game
	_restart_btn.disabled = not in_game
	_save_quit_btn.disabled = not in_game
	_pause_btn.text = "恢复" if _paused else "暂停"


func _on_pause_pressed() -> void:
	_set_paused(not _paused)
	_panel.visible = false


func _on_restart_pressed() -> void:
	_panel.visible = false
	if _paused:
		_set_paused(false)
	GameManager.start_game()


func _on_save_quit_pressed() -> void:
	GameManager.save_progress()
	get_tree().quit()


func _on_nosave_quit_pressed() -> void:
	GameManager.clear_save()
	get_tree().quit()


# ---------------------------------------------------------------------------
# Pause handling
# ---------------------------------------------------------------------------

func _set_paused(value: bool) -> void:
	_paused = value
	get_tree().paused = value
	_pause_overlay.visible = value
	if value:
		_pause_audio()
	else:
		_resume_audio()


## Pause every currently-playing audio/video stream in the whole tree (this also
## catches Dialogic's audio, which lives under its own autoload).
func _pause_audio() -> void:
	_paused_streams.clear()
	_walk_pause(get_tree().root)


func _walk_pause(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D or child is AudioStreamPlayer3D:
			if child.playing and not child.stream_paused:
				child.stream_paused = true
				_paused_streams.append(child)
		elif child is VideoStreamPlayer:
			if child.is_playing() and not child.paused:
				child.paused = true
				_paused_streams.append(child)
		_walk_pause(child)


func _resume_audio() -> void:
	for s in _paused_streams:
		if is_instance_valid(s):
			if s is VideoStreamPlayer:
				s.paused = false
			else:
				s.stream_paused = false
	_paused_streams.clear()
