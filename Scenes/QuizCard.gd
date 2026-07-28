extends Control

## A single reusable question card. Renders any question purely from its
## `prompt` + `options` fields (text / image / audio, with an optional per-item
## play button), covering all 5 question types. Emits `answered(index)` once a
## choice is made, then `continue_pressed` after feedback is shown.

signal answered(index: int)
signal continue_pressed

const SFX_CORRECT := "res://Assets/sfx/sfx_correct.ogg"
const SFX_WRONG := "res://Assets/sfx/sfx_wrong.ogg"

const OPTION_NORMAL := "res://Assets/vn/UI/quiz/quiz_option/quiz_option_bg_normal_9p.png"
const OPTION_HOVER := "res://Assets/vn/UI/quiz/quiz_option/quiz_option_bg_hover_9p.png"
const OPTION_PRESSED := "res://Assets/vn/UI/quiz/quiz_option/quiz_option_bg_pressed_9p.png"
const OPTION_DISABLED := "res://Assets/vn/UI/quiz/quiz_option/quiz_option_bg_disabled_9p.png"
const OPTION_CORRECT := "res://Assets/vn/UI/quiz/quiz_option/quiz_option_bg_correct_9p.png"
const OPTION_WRONG := "res://Assets/vn/UI/quiz/quiz_option/quiz_option_bg_wrong_9p.png"
const OPTION_SKIPPED := "res://Assets/vn/UI/quiz/quiz_option/quiz_option_bg_skipped_9p.png"

const AUDIO_NORMAL := "res://Assets/vn/UI/quiz/quiz_audio/quiz_audio_bg_normal_9p.png"
const AUDIO_HOVER := "res://Assets/vn/UI/quiz/quiz_audio/quiz_audio_bg_hover_9p.png"
const AUDIO_PRESSED := "res://Assets/vn/UI/quiz/quiz_audio/quiz_audio_bg_pressed_9p.png"
const AUDIO_ICON := "res://Assets/vn/UI/quiz/quiz_audio/quiz_audio_play_icon.png"

const FEEDBACK_PANEL := "res://Assets/vn/UI/quiz/quiz_paper/quiz_feedback_panel_9p.png"

const COLOR_TEXT := Color(0.28, 0.16, 0.08, 1.0)
const COLOR_SKIP := Color(0.55, 0.35, 0.08, 1.0)

const OPTION_SIZE := Vector2(360, 140)
const IMAGE_OPTION_SIZE := Vector2(360, 160)
const AUDIO_SIZE := Vector2(320, 100)
const OPTION_PATCH := 40
const AUDIO_PATCH := 36

var _answered: bool = false
var _awaiting_continue: bool = false
var _option_buttons: Array = []

var _instruction: Label
var _prompt_box: VBoxContainer
var _options_box: GridContainer
var _skip_hint: Label
var _feedback: Label
var _feedback_bg: CanvasItem

var _sfx: AudioStreamPlayer
var _audio: AudioStreamPlayer
var _video: VideoStreamPlayer = null

var _style_option_normal: StyleBoxTexture
var _style_option_hover: StyleBoxTexture
var _style_option_pressed: StyleBoxTexture
var _style_option_disabled: StyleBoxTexture
var _style_option_correct: StyleBoxTexture
var _style_option_wrong: StyleBoxTexture
var _style_option_skipped: StyleBoxTexture
var _style_audio_normal: StyleBoxTexture
var _style_audio_hover: StyleBoxTexture
var _style_audio_pressed: StyleBoxTexture
var _audio_icon: Texture2D


func _ready() -> void:
	_cache_styles()
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "SFX"
	add_child(_sfx)
	_audio = AudioStreamPlayer.new()
	_audio.bus = "Music"
	add_child(_audio)
	_build_skeleton()


func _cache_styles() -> void:
	_style_option_normal = _make_nine_style(OPTION_NORMAL, OPTION_PATCH)
	_style_option_hover = _make_nine_style(OPTION_HOVER, OPTION_PATCH)
	_style_option_pressed = _make_nine_style(OPTION_PRESSED, OPTION_PATCH)
	_style_option_disabled = _make_nine_style(OPTION_DISABLED, OPTION_PATCH)
	_style_option_correct = _make_nine_style(OPTION_CORRECT, OPTION_PATCH)
	_style_option_wrong = _make_nine_style(OPTION_WRONG, OPTION_PATCH)
	_style_option_skipped = _make_nine_style(OPTION_SKIPPED, OPTION_PATCH)
	_style_audio_normal = _make_nine_style(AUDIO_NORMAL, AUDIO_PATCH)
	_style_audio_hover = _make_nine_style(AUDIO_HOVER, AUDIO_PATCH)
	_style_audio_pressed = _make_nine_style(AUDIO_PRESSED, AUDIO_PATCH)
	_audio_icon = load(AUDIO_ICON) as Texture2D


func _make_nine_style(path: String, margins: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	var tex := load(path) as Texture2D
	if tex != null:
		sb.texture = tex
	sb.texture_margin_left = margins
	sb.texture_margin_top = margins
	sb.texture_margin_right = margins
	sb.texture_margin_bottom = margins
	sb.content_margin_left = 18
	sb.content_margin_top = 12
	sb.content_margin_right = 18
	sb.content_margin_bottom = 12
	return sb


func _build_skeleton() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 0)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	_instruction = Label.new()
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.add_theme_font_size_override("font_size", 24)
	_instruction.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(_instruction)

	_prompt_box = VBoxContainer.new()
	_prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_box.add_theme_constant_override("separation", 10)
	vbox.add_child(_prompt_box)

	_options_box = GridContainer.new()
	_options_box.columns = 2
	_options_box.add_theme_constant_override("h_separation", 20)
	_options_box.add_theme_constant_override("v_separation", 16)
	_options_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_options_box)

	_feedback_bg = get_node_or_null("%FeedbackPanel")
	var feedback_parent: Control = vbox
	if _feedback_bg != null and _feedback_bg is Control:
		var fb_margin := MarginContainer.new()
		fb_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		fb_margin.add_theme_constant_override("margin_left", 28)
		fb_margin.add_theme_constant_override("margin_right", 28)
		fb_margin.add_theme_constant_override("margin_top", 18)
		fb_margin.add_theme_constant_override("margin_bottom", 18)
		(_feedback_bg as Control).add_child(fb_margin)
		var fb_vbox := VBoxContainer.new()
		fb_vbox.add_theme_constant_override("separation", 6)
		fb_margin.add_child(fb_vbox)
		feedback_parent = fb_vbox
	elif _feedback_bg == null:
		# Fallback paper behind feedback if scene decoration is missing.
		var fb_panel := PanelContainer.new()
		fb_panel.visible = false
		fb_panel.add_theme_stylebox_override("panel", _make_nine_style(FEEDBACK_PANEL, 40))
		vbox.add_child(fb_panel)
		_feedback_bg = fb_panel
		var fb_margin2 := MarginContainer.new()
		for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			fb_margin2.add_theme_constant_override(side, 20)
		fb_panel.add_child(fb_margin2)
		var fb_vbox2 := VBoxContainer.new()
		fb_margin2.add_child(fb_vbox2)
		feedback_parent = fb_vbox2

	_skip_hint = Label.new()
	_skip_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_hint.add_theme_font_size_override("font_size", 26)
	_skip_hint.add_theme_color_override("font_color", COLOR_SKIP)
	_skip_hint.visible = false
	feedback_parent.add_child(_skip_hint)

	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_font_size_override("font_size", 20)
	_feedback.add_theme_color_override("font_color", COLOR_TEXT)
	_feedback.visible = false
	feedback_parent.add_child(_feedback)


## Populate the card with a question. Safe to call repeatedly.
func setup(question: Dictionary) -> void:
	_answered = false
	_awaiting_continue = false
	_feedback.visible = false
	_skip_hint.visible = false
	if _feedback_bg != null:
		_feedback_bg.visible = false
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
		l.add_theme_font_size_override("font_size", 64)
		l.add_theme_color_override("font_color", COLOR_TEXT)
		_prompt_box.add_child(l)

	if typeof(image) == TYPE_STRING and image != "":
		var tex := ContentDB.load_texture(image)
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.custom_minimum_size = Vector2(280, 200)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_prompt_box.add_child(tr)
		else:
			_prompt_box.add_child(_make_placeholder_box(ContentDB.label_for_path(image), Vector2(280, 200)))

	if typeof(audio) == TYPE_STRING and audio != "":
		if ContentDB.path_is_video(audio):
			var vstream := ContentDB.load_video(audio)
			if vstream != null:
				_video = VideoStreamPlayer.new()
				_video.stream = vstream
				_video.custom_minimum_size = Vector2(480, 270)
				_video.expand = true
				_prompt_box.add_child(_video)
				var pb := _make_audio_button("", "")
				pb.pressed.connect(func() -> void:
					if _video != null and is_instance_valid(_video):
						_video.play())
				_prompt_box.add_child(pb)
			else:
				_prompt_box.add_child(_make_placeholder_box("音乐片段：" + ContentDB.label_for_path(audio), Vector2(480, 180)))
				_prompt_box.add_child(_make_audio_button("", audio))
		else:
			_prompt_box.add_child(_make_audio_button("", audio))


func _build_options(options: Array) -> void:
	for c in _options_box.get_children():
		c.queue_free()
	_option_buttons.clear()

	for i in options.size():
		var opt: Dictionary = options[i]
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 10)

		var sel := Button.new()
		sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sel.focus_mode = Control.FOCUS_NONE
		_apply_option_styles(sel)

		var text: Variant = opt.get("text", null)
		var image: Variant = opt.get("image", null)
		var audio: Variant = opt.get("audio", null)

		if typeof(text) == TYPE_STRING and text != "":
			sel.text = text
			sel.add_theme_font_size_override("font_size", 28)
			sel.add_theme_color_override("font_color", COLOR_TEXT)
			sel.add_theme_color_override("font_hover_color", COLOR_TEXT)
			sel.add_theme_color_override("font_pressed_color", COLOR_TEXT)
			sel.add_theme_color_override("font_disabled_color", COLOR_TEXT)
			sel.custom_minimum_size = OPTION_SIZE
		elif typeof(image) == TYPE_STRING and image != "":
			var tex := ContentDB.load_texture(image)
			if tex != null:
				sel.icon = tex
				sel.expand_icon = true
				sel.add_theme_constant_override("icon_max_width", 120)
				sel.custom_minimum_size = IMAGE_OPTION_SIZE
			else:
				sel.text = "[占位]\n" + ContentDB.label_for_path(image)
				sel.add_theme_font_size_override("font_size", 20)
				sel.add_theme_color_override("font_color", COLOR_TEXT)
				sel.custom_minimum_size = IMAGE_OPTION_SIZE
		else:
			sel.text = "?"
			sel.custom_minimum_size = OPTION_SIZE

		var idx := i
		sel.pressed.connect(func() -> void: _on_option_selected(idx))
		cell.add_child(sel)

		if typeof(audio) == TYPE_STRING and audio != "":
			cell.add_child(_make_audio_button("", audio))

		_options_box.add_child(cell)
		_option_buttons.append(sel)


func _apply_option_styles(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _style_option_normal)
	btn.add_theme_stylebox_override("hover", _style_option_hover)
	btn.add_theme_stylebox_override("pressed", _style_option_pressed)
	btn.add_theme_stylebox_override("disabled", _style_option_disabled)
	btn.add_theme_stylebox_override("focus", _style_option_hover)


func _make_audio_button(_label: String, path: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = AUDIO_SIZE
	b.focus_mode = Control.FOCUS_NONE
	b.text = ""
	if _audio_icon != null:
		b.icon = _audio_icon
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 48)
	b.add_theme_stylebox_override("normal", _style_audio_normal)
	b.add_theme_stylebox_override("hover", _style_audio_hover)
	b.add_theme_stylebox_override("pressed", _style_audio_pressed)
	b.add_theme_stylebox_override("disabled", _style_audio_normal)
	b.add_theme_stylebox_override("focus", _style_audio_hover)
	if path != "":
		b.pressed.connect(func() -> void:
			var s := ContentDB.load_audio(path)
			if s != null:
				_audio.stream = s
				_audio.play())
	return b


func _make_placeholder_box(text: String, box_size: Vector2) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = box_size
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var l := Label.new()
	l.text = "[占位]\n" + text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", COLOR_TEXT)
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
		_apply_option_styles(b)

	if ans >= 0 and ans < _option_buttons.size():
		_set_option_state(_option_buttons[ans], _style_option_correct)
	if not correct and chosen >= 0 and chosen < _option_buttons.size():
		if skipped:
			_set_option_state(_option_buttons[chosen], _style_option_skipped)
		else:
			_set_option_state(_option_buttons[chosen], _style_option_wrong)

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
	msg += "\n\n（点击任意处继续）"
	_feedback.text = msg
	_feedback.visible = true
	if _feedback_bg != null:
		_feedback_bg.visible = true
	_awaiting_continue = true


func _set_option_state(btn: Button, style: StyleBoxTexture) -> void:
	btn.add_theme_stylebox_override("disabled", style)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)


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
