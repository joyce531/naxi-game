extends Control

## Reusable, data-driven culture book. It uses GameManager's pending book while
## in the official flow and keeps `test_book` available for direct scene tests.

signal book_finished

const VALID_LAYOUTS := [&"text_only", &"image_left", &"image_right"]
const FADE_OUT_TIME := 0.18
const FADE_IN_TIME := 0.20
const SLIDE_DISTANCE := 28.0
const TEXT_SPLIT_THRESHOLD := 90

@export var book_id := "test_book"

@onready var _book_texture: TextureRect = $BookFrame/BookTexture
@onready var _fallback_book: Panel = $BookFrame/FallbackBook
@onready var _content: Control = $BookFrame/PageContent
@onready var _left_text_panel: VBoxContainer = $BookFrame/PageContent/LeftPage/TextPanel
@onready var _left_title: Label = $BookFrame/PageContent/LeftPage/TextPanel/Title
@onready var _left_body: Label = $BookFrame/PageContent/LeftPage/TextPanel/Body
@onready var _left_illustration_panel: VBoxContainer = $BookFrame/PageContent/LeftPage/IllustrationPanel
@onready var _left_illustration: TextureRect = $BookFrame/PageContent/LeftPage/IllustrationPanel/Illustration
@onready var _left_caption: Label = $BookFrame/PageContent/LeftPage/IllustrationPanel/Caption
@onready var _right_text_panel: VBoxContainer = $BookFrame/PageContent/RightPage/TextPanel
@onready var _right_title: Label = $BookFrame/PageContent/RightPage/TextPanel/Title
@onready var _right_body: Label = $BookFrame/PageContent/RightPage/TextPanel/Body
@onready var _right_illustration_panel: VBoxContainer = $BookFrame/PageContent/RightPage/IllustrationPanel
@onready var _right_illustration: TextureRect = $BookFrame/PageContent/RightPage/IllustrationPanel/Illustration
@onready var _right_caption: Label = $BookFrame/PageContent/RightPage/IllustrationPanel/Caption
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
	_clear_pages()
	_left_text_panel.visible = true
	_left_title.text = "文化介绍书暂无内容"
	_left_body.text = "请检查 Data/content.json 中的 culture_books 配置。"
	_page_number.text = "0 / 0"
	_previous_button.visible = false
	_next_button.disabled = true


func _render_spread() -> void:
	var spread: Dictionary = _spreads[_spread_index]
	var layout := StringName(str(spread.get("layout", "text_only")))
	if layout not in VALID_LAYOUTS:
		layout = &"text_only"
	var illustration_texture := ContentDB.load_texture(spread.get("illustration", ""))
	_apply_layout(spread, layout, illustration_texture)

	_page_number.text = "%d / %d" % [_spread_index + 1, _spreads.size()]
	_previous_button.visible = _spread_index > 0
	_next_button.text = str(_book.get("start_button", "开始学习")) if _is_last_spread() else "下一页"
	_update_button_lock()


func _apply_layout(spread: Dictionary, layout: StringName, texture: Texture2D) -> void:
	_clear_pages()
	var title := str(spread.get("title", ""))
	var body := str(spread.get("body", ""))
	var caption := str(spread.get("caption", ""))
	if layout == &"text_only":
		var body_pages := _body_for_pages(spread, body)
		_show_text(_left_text_panel, _left_title, _left_body, title, body_pages[0])
		if not body_pages[1].is_empty():
			_show_text(_right_text_panel, _right_title, _right_body, "", body_pages[1])
	elif layout == &"image_left":
		_show_illustration(_left_illustration_panel, _left_illustration, _left_caption, texture, caption)
		_show_text(_right_text_panel, _right_title, _right_body, title, body)
	else:
		_show_text(_left_text_panel, _left_title, _left_body, title, body)
		_show_illustration(_right_illustration_panel, _right_illustration, _right_caption, texture, caption)


func _clear_pages() -> void:
	_left_text_panel.visible = false
	_right_text_panel.visible = false
	_left_illustration_panel.visible = false
	_right_illustration_panel.visible = false
	_left_illustration.texture = null
	_right_illustration.texture = null


func _show_text(panel: VBoxContainer, title_label: Label, body_label: Label, title: String, body: String) -> void:
	panel.visible = true
	title_label.text = title
	title_label.visible = not title.is_empty()
	body_label.text = body


func _show_illustration(panel: VBoxContainer, image: TextureRect, caption_label: Label, texture: Texture2D, caption: String) -> void:
	if texture == null:
		return
	panel.visible = true
	image.texture = texture
	caption_label.text = caption
	caption_label.visible = not caption.is_empty()


func _body_for_pages(spread: Dictionary, body: String) -> PackedStringArray:
	# Optional explicit page fields take precedence while the original `body` field
	# remains fully compatible for every existing CultureBook entry.
	if spread.has("left_body") or spread.has("right_body"):
		return PackedStringArray([
			str(spread.get("left_body", body)),
			str(spread.get("right_body", "")),
		])
	if body.length() <= TEXT_SPLIT_THRESHOLD:
		return PackedStringArray([body, ""])
	return _split_body(body)


func _split_body(body: String) -> PackedStringArray:
	var paragraphs := body.split("\n\n", false)
	if paragraphs.size() > 1:
		var best_index := 1
		var best_difference := body.length()
		for i in range(1, paragraphs.size()):
			var left := "\n\n".join(paragraphs.slice(0, i))
			var right := "\n\n".join(paragraphs.slice(i))
			var difference: int = int(abs(left.length() - right.length()))
			if difference < best_difference:
				best_index = i
				best_difference = difference
		return PackedStringArray([
			"\n\n".join(paragraphs.slice(0, best_index)),
			"\n\n".join(paragraphs.slice(best_index)),
		])

	var midpoint := int(body.length() / 2.0)
	var split_at := -1
	for i in range(midpoint, body.length()):
		if "。！？；".contains(body.substr(i, 1)):
			split_at = i + 1
			break
	if split_at < 0:
		for i in range(midpoint - 1, -1, -1):
			if "。！？；".contains(body.substr(i, 1)):
				split_at = i + 1
				break
	if split_at < 0:
		split_at = midpoint
	return PackedStringArray([
		body.substr(0, split_at).strip_edges(),
		body.substr(split_at).strip_edges(),
	])


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
