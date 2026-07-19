extends Control

## A single reusable question card. Renders any question purely from its
## `prompt` + `options` fields (text / image / audio, with an optional per-item
## play button), covering all 5 question types. Emits `answered(index)` once a
## choice is made, then `continue_pressed` after feedback is shown.

signal answered(index: int)
signal continue_pressed

const SFX_CORRECT := "res://Assets/sfx/sfx_correct.ogg"
const SFX_WRONG := "res://Assets/sfx/sfx_wrong.ogg"

const COLOR_CORRECT := Color(0.55, 1.0, 0.6)
const COLOR_WRONG := Color(1.0, 0.55, 0.55)

var _answered: bool = false
var _awaiting_continue: bool = false
var _option_buttons: Array = []

var _instruction: Label
var _prompt_box: VBoxContainer
var _options_box: GridContainer
var _feedback: Label

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
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
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
	_instruction.add_theme_font_size_override("font_size", 26)
	vbox.add_child(_instruction)

	_prompt_box = VBoxContainer.new()
	_prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_box.add_theme_constant_override("separation", 10)
	vbox.add_child(_prompt_box)

	_options_box = GridContainer.new()
	_options_box.columns = 2
	_options_box.add_theme_constant_override("h_separation", 16)
	_options_box.add_theme_constant_override("v_separation", 16)
	vbox.add_child(_options_box)

	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_font_size_override("font_size", 22)
	_feedback.visible = false
	vbox.add_child(_feedback)


## Populate the card with a question. Safe to call repeatedly.
func setup(question: Dictionary) -> void:
	_answered = false
	_awaiting_continue = false
	_feedback.visible = false
	_instruction.text = str(question.get("instruction", ""))
	_build_prompt(question.get("prompt", {}))
	_build_options(question.get("options", []))


func _build_prompt(prompt: Dictionary) -> void:
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
		l.add_theme_font_size_override("font_size", 72)
		_prompt_box.add_child(l)

	if typeof(image) == TYPE_STRING and image != "":
		var tex := ContentDB.load_texture(image)
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.custom_minimum_size = Vector2(320, 240)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_prompt_box.add_child(tr)
		else:
			_prompt_box.add_child(_make_placeholder_box(ContentDB.label_for_path(image), Vector2(320, 240)))

	if typeof(audio) == TYPE_STRING and audio != "":
		if ContentDB.path_is_video(audio):
			var vstream := ContentDB.load_video(audio)
			if vstream != null:
				_video = VideoStreamPlayer.new()
				_video.stream = vstream
				_video.custom_minimum_size = Vector2(480, 270)
				_video.expand = true
				_prompt_box.add_child(_video)
				var pb := Button.new()
				pb.text = "▶ 播放"
				pb.pressed.connect(func() -> void:
					if _video != null and is_instance_valid(_video):
						_video.play())
				_prompt_box.add_child(pb)
			else:
				_prompt_box.add_child(_make_placeholder_box("音乐片段：" + ContentDB.label_for_path(audio), Vector2(480, 180)))
				_prompt_box.add_child(_make_audio_button("▶ 播放音乐", audio))
		else:
			_prompt_box.add_child(_make_audio_button("▶ 播放读音", audio))


func _build_options(options: Array) -> void:
	for c in _options_box.get_children():
		c.queue_free()
	_option_buttons.clear()

	for i in options.size():
		var opt: Dictionary = options[i]
		var cell := HBoxContainer.new()

		var sel := Button.new()
		sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var text: Variant = opt.get("text", null)
		var image: Variant = opt.get("image", null)
		var audio: Variant = opt.get("audio", null)

		if typeof(text) == TYPE_STRING and text != "":
			sel.text = text
			sel.add_theme_font_size_override("font_size", 30)
			sel.custom_minimum_size = Vector2(240, 72)
		elif typeof(image) == TYPE_STRING and image != "":
			var tex := ContentDB.load_texture(image)
			if tex != null:
				sel.icon = tex
				sel.expand_icon = true
				sel.custom_minimum_size = Vector2(220, 170)
			else:
				sel.text = "[占位]\n" + ContentDB.label_for_path(image)
				sel.custom_minimum_size = Vector2(220, 170)
		else:
			sel.text = "?"
			sel.custom_minimum_size = Vector2(220, 72)

		var idx := i
		sel.pressed.connect(func() -> void: _on_option_selected(idx))
		cell.add_child(sel)

		if typeof(audio) == TYPE_STRING and audio != "":
			cell.add_child(_make_audio_button("▶", audio))

		_options_box.add_child(cell)
		_option_buttons.append(sel)


func _make_audio_button(label: String, path: String) -> Button:
	var b := Button.new()
	b.text = label
	b.pressed.connect(func() -> void:
		var s := ContentDB.load_audio(path)
		if s != null:
			_audio.stream = s
			_audio.play())
	return b


func _make_placeholder_box(text: String, box_size: Vector2) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = box_size
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

	for b in _option_buttons:
		b.disabled = true
	if ans >= 0 and ans < _option_buttons.size():
		_option_buttons[ans].modulate = COLOR_CORRECT
	if not correct and chosen >= 0 and chosen < _option_buttons.size():
		_option_buttons[chosen].modulate = COLOR_WRONG

	var sfx_stream := ContentDB.load_audio(SFX_CORRECT if correct else SFX_WRONG)
	if sfx_stream != null:
		_sfx.stream = sfx_stream
		_sfx.play()

	var msg := "回答正确！" if correct else "答错了。"
	var expl := str(feedback.get("explanation", ""))
	if expl != "":
		msg += "\n" + expl
	msg += "\n\n（点击任意处继续）"
	_feedback.text = msg
	_feedback.visible = true
	_awaiting_continue = true


## After feedback is shown, a click anywhere (or Enter/advance key) proceeds.
func _input(event: InputEvent) -> void:
	if not _awaiting_continue:
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
