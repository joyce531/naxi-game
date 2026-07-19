extends Control

## Main menu. "继续游戏" only appears when a save exists; it resumes from the saved
## flow step (quiz steps restart from question 1). "开始游戏" starts a fresh run.

@onready var _continue_btn: Button = $CenterContainer/VBox/ContinueButton


func _ready() -> void:
	_continue_btn.visible = GameManager.has_save()


func _on_continue_pressed() -> void:
	GameManager.continue_game()


func _on_start_pressed() -> void:
	GameManager.start_game()
