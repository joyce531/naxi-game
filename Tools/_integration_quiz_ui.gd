extends SceneTree

## Integration smoke: DongbaQuiz title/progress split, menu quit, feedback states.

var _done := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if _done:
		return
	_done = true

	var db := root.get_node("/root/ContentDB")
	var gm := root.get_node("/root/GameManager")

	var q: Dictionary = db.get_quiz("dongba")
	var questions: Array = q.get("questions", [])
	if questions.is_empty():
		push_error("[integration] dongba quiz has no questions")
		quit(1)
		return
	var all_indices: Array = []
	for i in questions.size():
		all_indices.append(i)
	var status := {}
	for qq in questions:
		status[qq.get("id", "")] = "pending"
	gm._session = {
		"quiz_id": "dongba",
		"title": q.get("title", ""),
		"questions": questions,
		"wrong_counts": {},
		"status": status,
		"queue": all_indices,
		"pos": 0,
		"round": 1,
	}

	var ps := load("res://Scenes/DongbaQuiz.tscn") as PackedScene
	var scene := ps.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var title := scene.get_node("VBox/HeaderBar/TitlePlaque/Title") as Label
	var progress := scene.get_node("VBox/HeaderBar/ProgressRow/Progress") as Label
	if title == null or progress == null:
		push_error("[integration] title/progress nodes missing")
		quit(1)
		return
	if title.text != gm.session_title():
		push_error("[integration] title mismatch '%s'" % title.text)
		quit(1)
		return
	if progress.text != gm.session_progress():
		push_error("[integration] progress mismatch '%s'" % progress.text)
		quit(1)
		return
	if "    " in title.text:
		push_error("[integration] title still looks concatenated: %s" % title.text)
		quit(1)
		return

	var card := scene.get_node("VBox/QuizCard")
	var ans := int(gm.session_current().get("answer_index", 0))
	var wrong := 0 if ans != 0 else 1
	var fb1: Dictionary = gm.session_answer(wrong)
	card.show_feedback(fb1)
	await process_frame
	if fb1.get("skipped", false):
		push_error("[integration] should not skip on first wrong")
		quit(1)
		return

	var menu := scene.get_node("MenuButton") as TextureButton
	if menu == null or not menu.is_in_group("quiz_menu"):
		push_error("[integration] menu button invalid")
		quit(1)
		return
	scene._on_menu_pressed()
	await process_frame
	await process_frame
	if gm.has_active_session():
		push_error("[integration] session should clear after menu quit")
		quit(1)
		return

	print("[integration_quiz_ui] OK title='%s' progress='%s'" % [title.text, progress.text])
	quit(0)
