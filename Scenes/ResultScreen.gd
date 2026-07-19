extends Control

## Shown only when the whole quiz session ends below the pass threshold.
## Displays the fail message and lets the player restart the ENTIRE quiz
## (or return to the main menu).

func _ready() -> void:
	var r: Dictionary = GameManager.last_result
	var ratio: float = float(r.get("ratio", 0.0))
	var correct: int = int(r.get("correct", 0))
	var total: int = int(r.get("total", 0))
	var title: String = str(r.get("title", ""))

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.09, 0.09, 0.12, 1)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 22)
	center.add_child(vbox)

	if title != "":
		var title_label := Label.new()
		title_label.text = title
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 30)
		vbox.add_child(title_label)

	var fail_label := Label.new()
	fail_label.text = "很遗憾，挑战失败\n再来一次吧！"
	fail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fail_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(fail_label)

	var score_label := Label.new()
	score_label.text = "答对 %d / %d，正确率 %d%%" % [correct, total, int(round(ratio * 100.0))]
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(score_label)

	var retry := Button.new()
	retry.text = "重新挑战"
	retry.add_theme_font_size_override("font_size", 24)
	retry.custom_minimum_size = Vector2(240, 56)
	retry.pressed.connect(func() -> void: GameManager.quiz_restart())
	vbox.add_child(retry)

	var quit := Button.new()
	quit.text = "返回主菜单"
	quit.add_theme_font_size_override("font_size", 22)
	quit.custom_minimum_size = Vector2(240, 48)
	quit.pressed.connect(func() -> void: GameManager.result_quit())
	vbox.add_child(quit)

	retry.grab_focus()
