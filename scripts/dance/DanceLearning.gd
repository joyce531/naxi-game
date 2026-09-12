extends Control

## Data-driven teaching flow. All learner-facing Chinese content comes from
## Data/content.json; this scene never treats key presses as rhythm scores.

const DANCE_ID := "datiao_01"
enum Phase { OVERVIEW, LESSON, CUE_ARRANGE, COMPLETE }

var _dance: Dictionary = {}
var _ui: Dictionary = {}
var _phase := Phase.OVERVIEW
var _step_index := 0
var _arrange_step: Dictionary = {}
var _available_tokens: Array = []
var _answer_tokens: Array = []

var _title: Label
var _phase_title: Label
var _video: VideoStreamPlayer
var _placeholder: Label
var _detail: Label
var _cue_list: HBoxContainer
var _token_source: FlowContainer
var _answer_box: FlowContainer
var _feedback: Label
var _primary: Button
var _secondary: Button
var _clear: Button


func _ready() -> void:
	_dance = ContentDB.get_dance(DANCE_ID)
	if _dance.is_empty():
		push_error("[DanceLearning] Dance data is missing.")
		return
	_ui = _dance.get("ui", {})
	_build_ui()
	_show_phase(Phase.OVERVIEW)
	# The dance UI is constructed at runtime, so refresh the shared menu once the
	# scene is fully ready. Keep this integration without restoring the removed
	# cue-only practice page from the conflicting branch.
	call_deferred("_refresh_shared_menu")


func _refresh_shared_menu() -> void:
	ControlBar.refresh_for_current_scene()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 128)
	margin.add_theme_constant_override("margin_right", 128)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 62)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)
	_title = _label(46)
	_title.add_theme_color_override("font_color", Color("#3b210f"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.text = str(_dance.get("title", ""))
	root.add_child(_title)
	_phase_title = _label(28)
	_phase_title.add_theme_color_override("font_color", Color("#7a4827"))
	_phase_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_phase_title)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 30)
	root.add_child(body)
	var media := VBoxContainer.new()
	media.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(media)
	_video = VideoStreamPlayer.new()
	_video.custom_minimum_size = Vector2(900, 506)
	_video.expand = true
	media.add_child(_video)
	_placeholder = _label(20)
	_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	media.add_child(_placeholder)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(620, 0)
	info.add_theme_constant_override("separation", 14)
	body.add_child(info)
	_detail = _label(26)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_detail)
	_cue_list = HBoxContainer.new()
	_cue_list.add_theme_constant_override("separation", 8)
	info.add_child(_cue_list)
	_answer_box = FlowContainer.new()
	info.add_child(_answer_box)
	_token_source = FlowContainer.new()
	info.add_child(_token_source)
	_feedback = _label(22)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_feedback)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 16)
	root.add_child(controls)
	_secondary = Button.new()
	_secondary.theme_type_variation = &"QuizMenuAction"
	_secondary.custom_minimum_size = Vector2(200, 60)
	_secondary.pressed.connect(_on_secondary)
	controls.add_child(_secondary)
	_clear = Button.new()
	_clear.theme_type_variation = &"QuizMenuAction"
	_clear.custom_minimum_size = Vector2(150, 60)
	_clear.pressed.connect(_clear_answer)
	controls.add_child(_clear)
	_primary = Button.new()
	_primary.theme_type_variation = &"QuizMenuAction"
	_primary.custom_minimum_size = Vector2(260, 60)
	_primary.pressed.connect(_on_primary)
	controls.add_child(_primary)


func _show_phase(phase: Phase) -> void:
	_phase = phase
	_feedback.text = ""
	_clear.visible = phase == Phase.CUE_ARRANGE
	_token_source.visible = phase == Phase.CUE_ARRANGE
	_answer_box.visible = phase == Phase.CUE_ARRANGE
	_cue_list.visible = phase == Phase.LESSON
	match phase:
		Phase.OVERVIEW:
			_phase_title.text = _text("overview")
			_detail.text = str(_dance.get("introduction", ""))
			_primary.text = _text("learn")
			_secondary.text = _text("replay")
			_load_video(str(_dance.get("full_video", "")))
		Phase.LESSON:
			_phase_title.text = _text("lesson")
			_primary.text = _text("next")
			_secondary.text = _text("previous")
			_show_lesson_step()
		Phase.CUE_ARRANGE:
			_phase_title.text = _text("arrange")
			_primary.text = _text("submit")
			_secondary.text = _text("replay")
			_start_arrangement()
		Phase.COMPLETE:
			_phase_title.text = _text("complete")
			_detail.text = _text("done")
			_primary.text = _text("complete")
			_secondary.visible = false
			_video.stop()


func _show_lesson_step() -> void:
	_secondary.visible = true
	var step := _current_step()
	_detail.text = str(step.get("title", ""))
	_load_step_video(step)
	_build_cue_list(step.get("actions", []))


func _on_primary() -> void:
	match _phase:
		Phase.OVERVIEW: _show_phase(Phase.LESSON)
		Phase.LESSON:
			if _step_index + 1 < _steps().size():
				_step_index += 1
				_show_lesson_step()
			else:
				_show_phase(Phase.CUE_ARRANGE)
		Phase.CUE_ARRANGE: _submit_arrangement()
		Phase.COMPLETE: GameManager.advance()


func _on_secondary() -> void:
	if _phase == Phase.LESSON and _step_index > 0:
		_step_index -= 1
		_show_lesson_step()
	else:
		_video.stream_position = 0.0
		_video.play()


func _start_arrangement() -> void:
	_arrange_step = _steps().pick_random()
	_load_step_video(_arrange_step)
	_detail.text = _text("video_replay")
	_available_tokens = _arrange_step.get("actions", []).duplicate(true)
	_available_tokens.shuffle()
	_answer_tokens.clear()
	_refresh_tokens()


func _refresh_tokens() -> void:
	for node in _token_source.get_children() + _answer_box.get_children():
		node.queue_free()
	for token: Dictionary in _available_tokens:
		var button := Button.new()
		button.theme_type_variation = &"QuizOptionButton"
		button.custom_minimum_size = Vector2(112, 68)
		button.text = str(token.get("cue", ""))
		button.pressed.connect(func() -> void: _choose_token(token))
		_token_source.add_child(button)
	for token: Dictionary in _answer_tokens:
		var button := Button.new()
		button.theme_type_variation = &"QuizOptionButton"
		button.custom_minimum_size = Vector2(112, 68)
		button.text = str(token.get("cue", ""))
		button.pressed.connect(func() -> void: _remove_token(token))
		_answer_box.add_child(button)


func _choose_token(token: Dictionary) -> void:
	_available_tokens.erase(token); _answer_tokens.append(token); _refresh_tokens()


func _remove_token(token: Dictionary) -> void:
	_answer_tokens.erase(token); _available_tokens.append(token); _refresh_tokens()


func _clear_answer() -> void:
	_available_tokens.append_array(_answer_tokens); _answer_tokens.clear(); _refresh_tokens()


func _submit_arrangement() -> void:
	var expected: Array = _arrange_step.get("actions", [])
	var correct := expected.size() == _answer_tokens.size()
	for i in expected.size():
		correct = correct and str(expected[i].get("id", "")) == str(_answer_tokens[i].get("id", ""))
	_feedback.text = _text("correct") if correct else _text("wrong")
	if correct: _show_phase(Phase.COMPLETE)


func _load_step_video(step: Dictionary) -> void:
	_load_video(str(step.get("video", "")))


func _load_video(path: String) -> void:
	_video.stream = ContentDB.load_video(path)
	_placeholder.text = "" if _video.stream != null else _text("missing_video")
	if _video.stream != null:
		_video.play()


func _steps() -> Array:
	return _dance.get("steps", [])


func _current_step() -> Dictionary:
	return _steps()[_step_index] if not _steps().is_empty() else {}


func _text(key: String) -> String:
	return str(_ui.get(key, ""))


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	return label


func _build_cue_list(actions: Array) -> void:
	for node in _cue_list.get_children():
		node.queue_free()
	for action: Dictionary in actions:
		var label := _label(22)
		label.text = str(action.get("cue", ""))
		label.add_theme_color_override("font_color", Color("#6b3d20"))
		_cue_list.add_child(label)
