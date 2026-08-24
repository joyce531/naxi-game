extends Control

## Final "Demo 结束" screen with a button back to the main menu.

func _on_back_pressed() -> void:
	SceneLoader.goto_scene(GameManager.MAIN_MENU)
