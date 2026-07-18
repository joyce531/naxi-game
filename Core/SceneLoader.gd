extends Node

## Handles scene transitions. Fade transitions are added in the "core" phase.
## This setup-phase stub provides a minimal deferred scene swap.

func goto_scene(path: String) -> void:
	call_deferred("_deferred_goto_scene", path)


func _deferred_goto_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
