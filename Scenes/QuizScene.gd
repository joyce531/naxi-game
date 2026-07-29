extends Control

## Thin driver shared by both quizzes. Hosts a QuizCard and walks the current
## GameManager session: show question -> record answer -> feedback -> next. When
## the round's queue is exhausted it starts the next round over still-pending
## questions, or lets GameManager advance to the next flow step when none remain.

@onready var _title_label: Label = $VBox/Header/TitlePlaque/TitleLabel
@onready var _progress_label: Label = $VBox/Header/ProgressRow/ProgressLabel
@onready var _card: Control = $VBox/QuizCard
@onready var _menu_button: TextureButton = $MenuButton


func _ready() -> void:
	if not GameManager.has_active_session():
		push_warning("[QuizScene] No active session; returning to menu.")
		GameManager.result_quit()
		return
	_card.answered.connect(_on_answered)
	_card.continue_pressed.connect(_on_continue)
	if _menu_button != null:
		_menu_button.pressed.connect(_on_menu_pressed)
	_show_current()


func _show_current() -> void:
	_title_label.text = GameManager.session_title()
	_progress_label.text = GameManager.session_progress()
	_card.setup(GameManager.session_current())


func _on_answered(index: int) -> void:
	var feedback: Dictionary = GameManager.session_answer(index)
	_card.show_feedback(feedback)


func _on_continue() -> void:
	if GameManager.session_has_next():
		GameManager.session_step()
		_show_current()
	else:
		# Round finished: start the next round over still-pending questions, or
		# (when nothing is pending) GameManager advances to the next flow step.
		var state := GameManager.session_end_round()
		if state == "next_round":
			_show_current()


func _on_menu_pressed() -> void:
	GameManager.result_quit()
