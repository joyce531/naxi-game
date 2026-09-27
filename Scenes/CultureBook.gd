extends Control

## Reusable, data-driven culture book. It uses GameManager's pending book while
## in the official flow and keeps `test_book` available for direct scene tests.

signal book_finished

const VALID_LAYOUTS := [&"text_only", &"image_left", &"image_right"]
const FADE_OUT_TIME := 0.18
const FADE_IN_TIME := 0.20
const SLIDE_DISTANCE := 28.0

@export var book_id := "test_book"

@onready var _book_texture: TextureRect = $BookFrame/BookTexture
@onready var _fallback_book: Panel = $BookFrame/FallbackBook
@onready var _content: Control = $BookFrame/PageContent
@onready var _text_panel: VBoxContainer = $BookFrame/PageContent/TextPanel
@onready var _title: Label = $BookFrame/PageContent/TextPanel/Title
@onready var _body: Label = $BookFrame/PageContent/TextPanel/Body
@onready var _illustration_panel: VBoxContainer = $BookFrame/PageContent/IllustrationPanel
@onready var _illustration: TextureRect = $BookFrame/PageContent/IllustrationPanel/Illustration
@onready var _caption: Label = $BookFrame/PageContent/IllustrationPanel/Caption
@onready var _previous_button: Button = $PreviousButton
@onready var _next_button: Button = $NextButton
@onready var _page_number: Label = $PageNumber
@onready var _status: Label = $Status
@onready var _page_turn_audio: AudioStreamPlayer = $PageTurnAudio

var _book: Dictionary = {}
var _spreads: Array = []
var _spread_index := 0
var _transitioning := false
var _content_home := Vector2.ZERO
var _in_official_flow := false


func _ready() -> void:
	_previous_button.pressed.connect(_on_previous_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	if GameManager.is_in_game() and not GameManager.pending_book_id.is_empty():
		book_id = GameManager.pending_book_id
		_in_official_flow = true
	_book = ContentDB.get_culture_book(book_id)
	_spreads = _book.get("spreads", [])
	_content_home = _content.position
	_load_optional_assets()
	if _spreads.is_empty():
		_show_empty_state()
		return
	_render_spread()


func _load_optional_assets() -> void:
	var book_art := ContentDB.load_texture(_book.get("book_texture", ""))
	_book_texture.texture = book_art
	_book_texture.visible = book_art != null
	_fallback_book.visible = book_art == null

	var turn_sound := ContentDB.load_audio(_book.get("page_turn_sfx", ""))
	_page_turn_audio.stream = turn_sound


func _show_empty_state() -> void:
	_title.text = "文化介绍书暂无内容"
	_body.text = "请检查 Data/content.json 中的 culture_books 配置。"
	_illustration_panel.visible = false
	_page_number.text = "0 / 0"
	_previous_button.visible = false
	_next_button.disabled = true


func _render_spread() -> void:
	var spread: Dictionary = _spreads[_spread_index]
	_title.text = str(spread.get("title", ""))
	_body.text = str(spread.get("body", ""))

	var layout := StringName(str(spread.get("layout", "text_only")))
	if layout not in VALID_LAYOUTS:
		layout = &"text_only"
	_apply_layout(layout)

	var illustration_texture := ContentDB.load_texture(spread.get("illustration", ""))
	_illustration.texture = illustration_texture
	_illustration_panel.visible = layout != &"text_only" and illustration_texture != null
	_caption.text = str(spread.get("caption", ""))
	_caption.visible = _illustration_panel.visible and not _caption.text.is_empty()

	_page_number.text = "%d / %d" % [_spread_index + 1, _spreads.size()]
	_previous_button.visible = _spread_index > 0
	_next_button.text = str(_book.get("start_button", "开始学习")) if _is_last_spread() else "下一页"
	_update_button_lock()


func _apply_layout(layout: StringName) -> void:
	if layout == &"text_only":
		_set_horizontal_region(_text_panel, 0.12, 0.88)
		_set_horizontal_region(_illustration_panel, 0.08, 0.45)
	elif layout == &"image_left":
		_set_horizontal_region(_illustration_panel, 0.08, 0.45)
		_set_horizontal_region(_text_panel, 0.55, 0.92)
	else:
		_set_horizontal_region(_text_panel, 0.08, 0.45)
		_set_horizontal_region(_illustration_panel, 0.55, 0.92)


func _set_horizontal_region(control: Control, left: float, right: float) -> void:
	control.anchor_left = left
	control.anchor_right = right
	control.offset_left = 0.0
	control.offset_right = 0.0


func _on_previous_pressed() -> void:
	if _transitioning or _spread_index <= 0:
		return
	await _change_spread(-1)


func _on_next_pressed() -> void:
	if _transitioning:
		return
	if _is_last_spread():
		_transitioning = true
		_update_button_lock()
		book_finished.emit()
		if _in_official_flow:
			GameManager.advance()
		else:
			_status.text = "测试书阅读完成（未处于正式游戏流程）"
		return
	await _change_spread(1)


func _change_spread(direction: int) -> void:
	_transitioning = true
	_update_button_lock()
	if _page_turn_audio.stream != null:
		_page_turn_audio.play()

	var exit_tween := create_tween().set_parallel(true)
	exit_tween.tween_property(_content, "modulate:a", 0.0, FADE_OUT_TIME)
	exit_tween.tween_property(
		_content,
		"position:x",
		_content_home.x - SLIDE_DISTANCE * direction,
		FADE_OUT_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await exit_tween.finished

	_spread_index += direction
	_render_spread()
	_content.position = _content_home + Vector2(SLIDE_DISTANCE * direction, 0.0)

	var enter_tween := create_tween().set_parallel(true)
	enter_tween.tween_property(_content, "modulate:a", 1.0, FADE_IN_TIME)
	enter_tween.tween_property(
		_content,
		"position:x",
		_content_home.x,
		FADE_IN_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await enter_tween.finished

	_transitioning = false
	_update_button_lock()


func _update_button_lock() -> void:
	_previous_button.disabled = _transitioning
	_next_button.disabled = _transitioning


func _is_last_spread() -> bool:
	return _spread_index == _spreads.size() - 1
