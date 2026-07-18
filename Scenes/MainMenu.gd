extends Control

## Placeholder main menu for the setup phase. The full menu (styling, transitions)
## is built in the "screens_polish" phase.

func _on_start_pressed() -> void:
	GameManager.start_game()
