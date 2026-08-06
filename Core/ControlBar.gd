extends CanvasLayer

## Persistent top control bar shown only during VN and quiz scenes. A single
## "菜单" button opens a small panel with four actions: pause/resume, restart the
## whole run from the beginning, save & quit, and quit without saving. Built
## entirely in code and registered as an autoload.
##
## Runs with PROCESS_MODE_ALWAYS so the bar (and the pause overlay) keep working
## while the game tree is paused.

const QUIZ_THEME := preload("res://Assets/vn/UI/quiz/quiz_theme.tres")
const MENU_ICON := preload("res://Assets/vn/UI/quiz/quiz_menu/quiz_menu_icon.png")
const MENU_CONNECTOR := preload("res://Assets/vn/UI/quiz/quiz_menu/menu_popup_connector.png")

var _paused: bool = false
var _paused_streams: Array = []

var _menu_btn: Button
var _panel: PanelContainer
var _menu_scrim: ColorRect
var _menu_connector: TextureRect
var _pause_btn: Button
var _restart_btn: Button
var _save_quit_btn: Button
var _nosave_quit_btn: Button
var _pause_overlay: ColorRect
var _last_scene_path: String = ""

const VISIBLE_SCENES := [
	"res://Scenes/VNStage.tscn",
	"res://Scenes/DongbaQuiz.tscn",
	"res://Scenes/MusicQuiz.tscn",
]


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh_scene_visibility()


func _process(_delta: float) -> void:
	var current_scene := get_tree().current_scene
	var scene_path := current_scene.scene_file_path if current_scene != null else ""
	if scene_path == _last_scene_path:
		return
	_last_scene_path = scene_path
	_apply_scene_visibility(scene_path)


func _refresh_scene_visibility() -> void:
	var current_scene := get_tree().current_scene
	var scene_path := current_scene.scene_file_path if current_scene != null else ""
	_last_scene_path = scene_path
	_apply_scene_visibility(scene_path)


func _apply_scene_visibility(scene_path: String) -> void:
	var should_show := scene_path in VISIBLE_SCENES
	_menu_btn.visible = should_show
	if not should_show:
		_set_menu_open(false)


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
	pause_label.theme = QUIZ_THEME
	var pause_font := FontVariation.new()
	pause_font.base_font = QUIZ_THEME.default_font
	pause_font.variation_embolden = 1.5
	pause_label.add_theme_font_override("font", pause_font)
	pause_label.add_theme_color_override("font_color", Color.WHITE)
	pause_label.add_theme_font_size_override("font_size", 36)
	pause_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(pause_label)

	# A light warm veil focuses the open menu without obscuring the game art.
	_menu_scrim = ColorRect.new()
	_menu_scrim.name = "MenuScrim"
	_menu_scrim.color = Color(0.164706, 0.101961, 0.0627451, 0.12)
	_menu_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_scrim.visible = false
	add_child(_menu_scrim)

	# "菜单" button, pinned to the top-right corner.
	_menu_btn = Button.new()
	_menu_btn.name = "MenuButton"
	_menu_btn.custom_minimum_size = Vector2(96.0, 96.0)
	_menu_btn.anchor_left = 1.0
	_menu_btn.anchor_right = 1.0
	_menu_btn.offset_left = -128.0
	_menu_btn.offset_right = -32.0
	_menu_btn.offset_top = 28.0
	_menu_btn.offset_bottom = 124.0
	_menu_btn.theme = QUIZ_THEME
	_menu_btn.theme_type_variation = &"QuizMenuTrigger"
	_menu_btn.pressed.connect(_on_menu_pressed)
	add_child(_menu_btn)

	var menu_icon := TextureRect.new()
	menu_icon.name = "Icon"
	menu_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_icon.offset_left = 18.0
	menu_icon.offset_top = 8.0
	menu_icon.offset_right = -18.0
	menu_icon.offset_bottom = -28.0
	menu_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_icon.texture = MENU_ICON
	menu_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_menu_btn.add_child(menu_icon)

	var menu_label := Label.new()
	menu_label.name = "Label"
	menu_label.anchor_right = 1.0
	menu_label.offset_top = 54.0
	menu_label.offset_bottom = 82.0
	menu_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_label.theme = QUIZ_THEME
	menu_label.add_theme_font_size_override("font_size", 20)
	menu_label.text = "菜单"
	menu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_menu_btn.add_child(menu_label)

	# Short decorative connector between the trigger and the parchment panel.
	_menu_connector = TextureRect.new()
	_menu_connector.name = "MenuConnector"
	_menu_connector.anchor_left = 1.0
	_menu_connector.anchor_right = 1.0
	_menu_connector.offset_left = -96.0
	_menu_connector.offset_right = -64.0
	_menu_connector.offset_top = 112.0
	_menu_connector.offset_bottom = 176.0
	_menu_connector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_connector.texture = MENU_CONNECTOR
	_menu_connector.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_menu_connector.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_menu_connector.visible = false
	add_child(_menu_connector)

	# Compact parchment popup with exact 36 px horizontal and 60 px vertical
	# content margins supplied by the QuizMenuPanel style.
	_panel = PanelContainer.new()
	_panel.name = "MenuPanel"
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -440.0
	_panel.offset_right = -40.0
	_panel.offset_top = 138.0
	_panel.offset_bottom = 638.0
	_panel.theme = QUIZ_THEME
	_panel.theme_type_variation = &"QuizMenuPanel"
	_panel.visible = false
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.name = "Actions"
	vbox.add_theme_constant_override("separation", 20)
	_panel.add_child(vbox)

	_pause_btn = _make_menu_button("暂停", _on_pause_pressed, 36)
	vbox.add_child(_pause_btn)
	_restart_btn = _make_menu_button("重来", _on_restart_pressed, 36)
	vbox.add_child(_restart_btn)
	_save_quit_btn = _make_menu_button("保存进度退出", _on_save_quit_pressed, 30)
	vbox.add_child(_save_quit_btn)
	_nosave_quit_btn = _make_menu_button("不保存进度退出", _on_nosave_quit_pressed, 30)
	vbox.add_child(_nosave_quit_btn)

	# Keep the round trigger above the connector and panel overlap.
	_menu_btn.move_to_front()


func _make_menu_button(text: String, handler: Callable, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(328.0, 80.0)
	b.theme = QUIZ_THEME
	b.theme_type_variation = &"QuizMenuAction"
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(handler)
	return b


func _on_menu_pressed() -> void:
	_set_menu_open(not _panel.visible)
	if _panel.visible:
		_refresh_panel()


func _set_menu_open(value: bool) -> void:
	_panel.visible = value
	_menu_scrim.visible = value
	_menu_connector.visible = value


## Enable game-only actions only while a game is in progress.
func _refresh_panel() -> void:
	var in_game: bool = GameManager.is_in_game()
	_pause_btn.disabled = not in_game
	_restart_btn.disabled = not in_game
	_save_quit_btn.disabled = not in_game
	_pause_btn.text = "恢复" if _paused else "暂停"


func _on_pause_pressed() -> void:
	_set_paused(not _paused)
	_set_menu_open(false)


func _on_restart_pressed() -> void:
	_set_menu_open(false)
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
