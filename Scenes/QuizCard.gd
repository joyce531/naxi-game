extends Control

## A single reusable question card. Renders any question purely from its
## `prompt` + `options` fields (text / image / audio, with an optional per-item
## play button), covering all 5 question types. Emits `answered(index)` once a
## choice is made, then `continue_pressed` after feedback is shown.

signal answered(index: int)
signal continue_pressed

const SFX_CORRECT := "res://Assets/sfx/sfx_correct.ogg"
const SFX_WRONG := "res://Assets/sfx/sfx_wrong.ogg"
const AUDIO_PLAY_ICON: Texture2D = preload("res://Assets/vn/UI/quiz/quiz_audio/quiz_audio_play_icon_texture.tres")
const FEEDBACK_PANEL_TEXTURE: Texture2D = preload("res://Assets/vn/UI/quiz/quiz_feedback_panel_texture.tres")

const COLOR_SKIP := Color(0.78, 0.43, 0.02)

var _answered: bool = false
var _awaiting_continue: bool = false
var _option_buttons: Array = []

var _instruction: Label
var _prompt_box: VBoxContainer
var _options_box: GridContainer
var _skip_hint: Label
var _feedback: Label
var _continue_hint: Label
var _feedback_overlay: Control

var _sfx: AudioStreamPlayer
var _audio: AudioStreamPlayer
var _video: VideoStreamPlayer = null


func _ready() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "SFX"
	add_child(_sfx)
	_audio = AudioStreamPlayer.new()
	_audio.bus = "Music"
	add_child(_audio)
	_build_skeleton()


func _build_skeleton() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -74.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1060, 760)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	_instruction = Label.new()
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_instruction.custom_minimum_size = Vector2(0, 52)
	_instruction.add_theme_font_size_override("font_size", 38)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_instruction)

	_prompt_box = VBoxContainer.new()
	_prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_box.add_theme_constant_override("separation", 10)
	vbox.add_child(_prompt_box)

	_options_box = GridContainer.new()
	_options_box.columns = 2
	_options_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_options_box.add_theme_constant_override("h_separation", 28)
	_options_box.add_theme_constant_override("v_separation", 18)
	vbox.add_child(_options_box)

	_feedback_overlay = Control.new()
	_feedback_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_feedback_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_overlay.visible = false
	add_child(_feedback_overlay)

	_skip_hint = Label.new()
	_skip_hint.custom_minimum_size = Vector2(0, 20)
	_skip_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skip_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skip_hint.add_theme_font_size_override("font_size", 18)
	_skip_hint.add_theme_color_override("font_color", COLOR_SKIP)
	_skip_hint.add_theme_color_override("font_outline_color", Color(1.0, 0.94, 0.76, 1.0))
	_skip_hint.add_theme_constant_override("outline_size", 2)
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_hint.visible = false

	var feedback_panel := NinePatchRect.new()
	feedback_panel.anchor_left = 0.5
	feedback_panel.anchor_top = 1.0
	feedback_panel.anchor_right = 0.5
	feedback_panel.anchor_bottom = 1.0
	feedback_panel.offset_left = -419.0
	feedback_panel.offset_top = -226.0
	feedback_panel.offset_right = 419.0
	feedback_panel.offset_bottom = -118.0
	feedback_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	feedback_panel.texture = FEEDBACK_PANEL_TEXTURE
	feedback_panel.patch_margin_left = 70
	feedback_panel.patch_margin_top = 28
	feedback_panel.patch_margin_right = 70
	feedback_panel.patch_margin_bottom = 28
	feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_overlay.add_child(feedback_panel)

	var feedback_margin := MarginContainer.new()
	feedback_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	feedback_margin.add_theme_constant_override("margin_left", 24)
	feedback_margin.add_theme_constant_override("margin_top", 5)
	feedback_margin.add_theme_constant_override("margin_right", 24)
	feedback_margin.add_theme_constant_override("margin_bottom", 5)
	feedback_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_panel.add_child(feedback_margin)

	var feedback_vbox := VBoxContainer.new()
	feedback_vbox.add_theme_constant_override("separation", -2)
	feedback_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_margin.add_child(feedback_vbox)
	feedback_vbox.add_child(_skip_hint)

	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_feedback.add_theme_font_size_override("font_size", 18)
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_vbox.add_child(_feedback)

	_continue_hint = Label.new()
	_continue_hint.text = "（点击任意处继续）"
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_continue_hint.add_theme_font_size_override("font_size", 15)
	_continue_hint.add_theme_color_override("font_color", Color(0.42, 0.31, 0.21, 1.0))
	_continue_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_vbox.add_child(_continue_hint)


## Populate the card with a question. Safe to call repeatedly.
func setup(question: Dictionary) -> void:
	_answered = false
	_awaiting_continue = false
	_feedback_overlay.visible = false
	_skip_hint.visible = false
	_instruction.text = str(question.get("instruction", ""))
	_build_prompt(question.get("prompt", {}), str(question.get("type", "")))
	_build_options(question.get("options", []))


func _build_prompt(prompt: Dictionary, question_type: String) -> void:
	for c in _prompt_box.get_children():
		c.queue_free()
	if _video != null and is_instance_valid(_video):
		_video = null

	var text: Variant = prompt.get("text", null)
	var image: Variant = prompt.get("image", null)
	var audio: Variant = prompt.get("audio", null)

	if typeof(text) == TYPE_STRING and text != "":
		var l := Label.new()
		l.text = text
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(344, 120 if question_type == "text_to_image" else 180)
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		l.add_theme_font_size_override("font_size", 68 if question_type == "text_to_image" else 72)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_prompt_box.add_child(l)

	if typeof(image) == TYPE_STRING and image != "":
		var image_size := Vector2(344, 264)
		if question_type == "image_to_text":
			image_size = Vector2(290, 190)
		elif question_type == "sentence_to_text":
			image_size = Vector2(520, 180)
		var tex := ContentDB.load_texture(image)
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.custom_minimum_size = image_size
			tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_prompt_box.add_child(tr)
		else:
			_prompt_box.add_child(_make_placeholder_box(ContentDB.label_for_path(image), image_size))

	if typeof(audio) == TYPE_STRING and audio != "":
		if ContentDB.path_is_video(audio):
			var vstream := ContentDB.load_video(audio)
			if vstream != null:
				_video = VideoStreamPlayer.new()
				_video.stream = vstream
				_video.custom_minimum_size = Vector2(480, 270)
				_video.expand = true
				_prompt_box.add_child(_video)
				var pb := _create_audio_button("播放")
				pb.pressed.connect(func() -> void:
					if _video != null and is_instance_valid(_video):
						_video.play())
				_prompt_box.add_child(pb)
			else:
				_prompt_box.add_child(_make_placeholder_box("音乐片段：" + ContentDB.label_for_path(audio), Vector2(480, 180)))
				_prompt_box.add_child(_make_audio_button("播放音乐", audio))
		else:
			_prompt_box.add_child(_make_audio_button("播放读音", audio))


func _build_options(options: Array) -> void:
	for c in _options_box.get_children():
		c.queue_free()
	_option_buttons.clear()

	for i in options.size():
		var opt: Dictionary = options[i]
		var text: Variant = opt.get("text", null)
		var image: Variant = opt.get("image", null)
		var audio: Variant = opt.get("audio", null)

		var cell := HBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_theme_constant_override("separation", 10)

		var sel := Button.new()
		sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sel.custom_minimum_size = Vector2(367, 170 if typeof(image) == TYPE_STRING and image != "" else 103)
		sel.theme_type_variation = &"QuizOptionButton"
		sel.alignment = HORIZONTAL_ALIGNMENT_CENTER
		sel.clip_text = true

		if typeof(text) == TYPE_STRING and text != "":
			sel.text = str(text)
			sel.add_theme_font_size_override("font_size", 36 if str(text).length() <= 4 else 30)
		elif typeof(image) == TYPE_STRING and image != "":
			var tex := ContentDB.load_texture(image)
			if tex != null:
				var option_image := TextureRect.new()
				option_image.set_anchors_preset(Control.PRESET_FULL_RECT)
				option_image.offset_left = 36.0
				option_image.offset_top = 12.0
				option_image.offset_right = -36.0
				option_image.offset_bottom = -12.0
				option_image.texture = tex
				option_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				option_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				option_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
				sel.add_child(option_image)
			else:
				sel.text = "[占位]\n" + ContentDB.label_for_path(image)
				sel.add_theme_font_size_override("font_size", 22)
		else:
			sel.text = "?"

		var idx := i
		sel.pressed.connect(func() -> void: _on_option_selected(idx))
		cell.add_child(sel)

		if typeof(audio) == TYPE_STRING and audio != "":
			cell.add_child(_make_audio_button("", audio, true))

		_options_box.add_child(cell)
		_option_buttons.append(sel)


func _create_audio_button(label: String, compact: bool = false) -> Button:
	var b := Button.new()
	b.text = label
	b.icon = AUDIO_PLAY_ICON
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if compact:
		b.custom_minimum_size = Vector2(48, 48)
		b.flat = true
		b.tooltip_text = "播放读音"
		b.add_theme_constant_override("icon_max_width", 28)
	else:
		b.custom_minimum_size = Vector2(253, 63)
		b.theme_type_variation = &"QuizAudioButton"
	return b


func _make_audio_button(label: String, path: String, compact: bool = false) -> Button:
	var b := _create_audio_button(label, compact)
	b.pressed.connect(func() -> void:
		var s := ContentDB.load_audio(path)
		if s != null:
			_audio.stream = s
			_audio.play())
	return b


func _make_placeholder_box(text: String, box_size: Vector2) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = box_size
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = "[占位]\n" + text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	return p


func _on_option_selected(index: int) -> void:
	if _answered:
		return
	_answered = true
	answered.emit(index)


## Called by the quiz scene after it records the answer.
func show_feedback(feedback: Dictionary) -> void:
	var correct: bool = bool(feedback.get("correct", false))
	var ans: int = int(feedback.get("answer_index", -1))
	var chosen: int = int(feedback.get("chosen_index", -1))
	var skipped: bool = bool(feedback.get("skipped", false))

	for b in _option_buttons:
		b.disabled = true
	if ans >= 0 and ans < _option_buttons.size():
		_option_buttons[ans].theme_type_variation = &"QuizOptionCorrect"
	if not correct and chosen >= 0 and chosen < _option_buttons.size():
		_option_buttons[chosen].theme_type_variation = &"QuizOptionSkipped" if skipped else &"QuizOptionWrong"

	var sfx_stream := ContentDB.load_audio(SFX_CORRECT if correct else SFX_WRONG)
	if sfx_stream != null:
		_sfx.stream = sfx_stream
		_sfx.play()

	if skipped:
		_skip_hint.text = "⚠ " + str(feedback.get("skip_hint", ""))
		_skip_hint.visible = true
	else:
		_skip_hint.visible = false

	var msg := "回答正确！" if correct else "答错了。"
	var expl := str(feedback.get("explanation", ""))
	if expl != "":
		msg += "\n" + expl
	_feedback.text = msg
	_feedback_overlay.visible = true
	_awaiting_continue = true


## After feedback is shown, a click anywhere (or Enter/advance key) proceeds.
## Clicks on chrome such as the menu button are ignored so they can quit cleanly.
func _input(event: InputEvent) -> void:
	if not _awaiting_continue:
		return
	if _is_chrome_click():
		return
	var advance_now := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_now = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("dialogic_default_action"):
		advance_now = true
	if advance_now:
		_awaiting_continue = false
		get_viewport().set_input_as_handled()
		continue_pressed.emit()


func _is_chrome_click() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	while hovered != null:
		if hovered.is_in_group("quiz_menu"):
			return true
		hovered = hovered.get_parent() as Control
	return false
