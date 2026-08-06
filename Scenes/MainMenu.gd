extends Control

## Main menu. With no save, one centered "开始旅程" button starts a fresh run.
## With a save, "继续旅程" resumes the saved flow step and "重新开始" starts over.

const BUTTON_SIZE := Vector2(560.0, 160.0)
const BUTTON_Y := 650.0
const SINGLE_BUTTON_X := 680.0
const CONTINUE_BUTTON_X := 376.0
const RESTART_BUTTON_X := 984.0

@onready var _continue_btn: Button = $ButtonLayer/ContinueButton
@onready var _start_btn: Button = $ButtonLayer/StartButton


func _ready() -> void:
	_apply_save_layout(GameManager.has_save())


func _apply_save_layout(has_saved_game: bool) -> void:
	_continue_btn.visible = has_saved_game
	if has_saved_game:
		_place_button(_continue_btn, CONTINUE_BUTTON_X)
		_place_button(_start_btn, RESTART_BUTTON_X)
		_start_btn.text = "重新开始"
	else:
		_place_button(_start_btn, SINGLE_BUTTON_X)
		_start_btn.text = "开始旅程"


func _place_button(button: Button, x: float) -> void:
	button.position = Vector2(x, BUTTON_Y)
	button.size = BUTTON_SIZE


func _on_continue_pressed() -> void:
	GameManager.continue_game()


func _on_start_pressed() -> void:
	GameManager.start_game()
