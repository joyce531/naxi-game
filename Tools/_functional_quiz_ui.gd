extends SceneTree

## Exercises QuizCard setup + feedback styling without full SceneLoader flow.

var _done := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if _done:
		return
	_done = true

	var card_ps := load("res://Scenes/QuizCard.tscn") as PackedScene
	var card := card_ps.instantiate()
	root.add_child(card)
	await process_frame
	await process_frame

	var sample := {
		"instruction": "测试题目",
		"prompt": {"text": "东"},
		"options": [
			{"text": "选项甲"},
			{"text": "选项乙"},
			{"text": "选项丙"},
			{"text": "选项丁"},
		],
	}
	card.setup(sample)
	await process_frame
	if card._option_buttons.size() != 4:
		push_error("[functional] expected 4 options, got %d" % card._option_buttons.size())
		quit(1)
		return
	var first: Button = card._option_buttons[0]
	if first.custom_minimum_size != Vector2(360, 140):
		push_error("[functional] option size want 360x140 got %s" % str(first.custom_minimum_size))
		quit(1)
		return

	card.show_feedback({
		"correct": false,
		"answer_index": 1,
		"chosen_index": 0,
		"skipped": true,
		"skip_hint": "累计错误已达上限",
		"explanation": "解析内容",
	})
	await process_frame
	if not card._feedback.visible:
		push_error("[functional] feedback not visible")
		quit(1)
		return
	if card._feedback_bg != null and not card._feedback_bg.visible:
		push_error("[functional] feedback panel not visible")
		quit(1)
		return

	print("[functional_quiz_ui] OK")
	quit(0)
