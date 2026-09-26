extends Control

## Reusable completion page. It uses GameManager's pending completion page while
## in the official flow and keeps `test_page` available for direct scene tests.

signal continue_requested

@export var completion_id := "test_page"

@onready var _background: TextureRect = $Background
@onready var _title: Label = $InfoFrame/Content/Title
@onready var _summary: Label = $InfoFrame/Content/BodyRow/Summary
@onready var _illustration: TextureRect = $InfoFrame/Content/BodyRow/Illustration
@onready var _continue_button: Button = $ContinueButton
@onready var _status: Label = $Status

var _continued := false
var _in_official_flow := false


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	if GameManager.is_in_game() and not GameManager.pending_completion_id.is_empty():
		completion_id = GameManager.pending_completion_id
		_in_official_flow = true
	var page := ContentDB.get_completion_page(completion_id)
	if page.is_empty():
		_show_missing_page()
		return
	_apply_page(page)


func _apply_page(page: Dictionary) -> void:
	_title.text = str(page.get("title", ""))
	_summary.text = str(page.get("summary", ""))
	_continue_button.text = str(page.get("button_text", "继续"))

	var background_texture := ContentDB.load_texture(page.get("background", ""))
	_background.texture = background_texture
	_background.visible = background_texture != null

	var illustration_texture := ContentDB.load_texture(page.get("illustration", ""))
	_illustration.texture = illustration_texture
	_illustration.visible = illustration_texture != null


func _show_missing_page() -> void:
	_title.text = "通关页面暂无内容"
	_summary.text = "请检查 Data/content.json 中的 completion_pages 配置。"
	_illustration.visible = false
	_continue_button.disabled = true


func _on_continue_pressed() -> void:
	if _continued:
		return
	_continued = true
	_continue_button.disabled = true
	continue_requested.emit()
	if _in_official_flow:
		GameManager.advance()
	else:
		_status.text = "测试页面完成（未处于正式游戏流程）"
