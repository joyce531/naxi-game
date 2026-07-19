extends Control

## Thin driver shared by both quizzes. Hosts a QuizCard and walks the current
## GameManager session: show question -> record answer -> feedback -> next, and
## finishes the round (routing to ResultScreen) when the queue is exhausted.

@onready var _header: Label = $VBox/Header
@onready var _card: Control = $VBox/QuizCard


func _ready() -> void:
	if not GameManager.has_active_session():
		push_warning("[QuizScene] No active session; returning to menu.")
		GameManager.result_quit()
		return
	_card.answered.connect(_on_answered)
	_card.continue_pressed.connect(_on_continue)
	_show_current()


func _show_current() -> void:
	_header.text = "%s    %s" % [GameManager.session_title(), GameManager.session_progress()]
	_card.setup(GameManager.session_current())


func _on_answered(index: int) -> void:
	var feedback: Dictionary = GameManager.session_answer(index)
	_card.show_feedback(feedback)


func _on_continue() -> void:
	if GameManager.session_has_next():
		GameManager.session_step()
		_show_current()
	else:
		# Round finished: either continue into the redo round, or the session
		# ends (GameManager navigates away on pass/fail).
		var state := GameManager.session_end_round()
		if state == "next_round":
			_show_current()
