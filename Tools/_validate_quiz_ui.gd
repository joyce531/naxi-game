extends SceneTree

## Headless smoke check for quiz UI wiring. Run:
## godot --headless --path . -s res://Tools/_validate_quiz_ui.gd

var _done := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if _done:
		return
	_done = true
	var errors: PackedStringArray = []
	for path in ["res://Scenes/DongbaQuiz.tscn", "res://Scenes/MusicQuiz.tscn", "res://Scenes/QuizCard.tscn"]:
		var ps := load(path) as PackedScene
		if ps == null:
			errors.append("Failed to load %s" % path)
			continue
		var inst := ps.instantiate()
		if inst == null:
			errors.append("Failed to instantiate %s" % path)
			continue
		if path.ends_with("DongbaQuiz.tscn") or path.ends_with("MusicQuiz.tscn"):
			for node_path in [
				"BG", "Dim", "VBox/HeaderBar/TitlePlaque/Title",
				"VBox/HeaderBar/ProgressRow/Progress", "VBox/QuizCard", "MenuButton"
			]:
				if inst.get_node_or_null(node_path) == null:
					errors.append("%s missing node %s" % [path, node_path])
			var menu := inst.get_node_or_null("MenuButton") as TextureButton
			if menu != null and not menu.is_in_group("quiz_menu"):
				errors.append("%s MenuButton not in quiz_menu group" % path)
			if menu != null and menu.texture_normal == null:
				errors.append("%s MenuButton missing texture_normal" % path)
			var bg := inst.get_node_or_null("BG") as TextureRect
			if bg != null and bg.texture == null:
				errors.append("%s BG missing texture" % path)
			# Confirm scripts compiled with autoloads available.
			var script_ok := inst.get_script() != null
			if not script_ok:
				errors.append("%s root script missing" % path)
		if path.ends_with("QuizCard.tscn"):
			if inst.get_node_or_null("PaperLayer/Center/PaperStack/MainPanel") == null:
				errors.append("%s missing MainPanel" % path)
			if inst.get_node_or_null("%FeedbackPanel") == null:
				errors.append("%s missing FeedbackPanel" % path)
		inst.free()

	for tex_path in [
		"res://Assets/vn/UI/quiz/quiz_option/quiz_option_bg_normal_9p.png",
		"res://Assets/vn/UI/quiz/quiz_option/quiz_option_bg_correct_9p.png",
		"res://Assets/vn/UI/quiz/quiz_option/quiz_option_bg_wrong_9p.png",
		"res://Assets/vn/UI/quiz/quiz_option/quiz_option_bg_skipped_9p.png",
		"res://Assets/vn/UI/quiz/quiz_audio/quiz_audio_bg_normal_9p.png",
		"res://Assets/vn/UI/quiz/quiz_audio/quiz_audio_play_icon.png",
		"res://Assets/vn/backgrounds/bg_in_the_room.png",
	]:
		if load(tex_path) == null:
			errors.append("Failed to load texture %s" % tex_path)

	# Compile-check key scripts by loading them after autoloads exist.
	for script_path in ["res://Scenes/QuizScene.gd", "res://Scenes/QuizCard.gd"]:
		var scr := load(script_path)
		if scr == null:
			errors.append("Failed to load script %s" % script_path)

	if errors.is_empty():
		print("[validate_quiz_ui] OK")
		quit(0)
	else:
		for e in errors:
			push_error("[validate_quiz_ui] " + e)
		print("[validate_quiz_ui] FAILED (%d)" % errors.size())
		quit(1)
