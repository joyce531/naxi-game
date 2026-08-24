extends CanvasLayer

## Handles scene transitions with a simple black fade. Registered as an autoload
## so the fade overlay persists across scene swaps.

@export var fade_time: float = 0.3

var _rect: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 128
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


## Fade out, swap the scene, fade back in.
func goto_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade(1.0)
	get_tree().change_scene_to_file(path)
	# Let the new scene enter the tree before fading in.
	await get_tree().process_frame
	await _fade(0.0)
	_busy = false


func _fade(target_alpha: float) -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP if target_alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", target_alpha, fade_time)
	await tween.finished
