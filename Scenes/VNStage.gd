extends Control

## Hosts a Dialogic timeline. Starts the timeline GameManager queued, and when
## the timeline finishes (or a generic "advance" signal fires from the script),
## hands control back to GameManager.advance(). No per-minigame signal is used.

var _advanced: bool = false


func _ready() -> void:
	if not Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.connect(_on_timeline_ended)
	if not Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.connect(_on_dialogic_signal)

	var timeline_name: String = GameManager.pending_timeline
	if timeline_name == "":
		push_warning("[VNStage] No pending timeline set; advancing immediately.")
		_do_advance()
		return
	Dialogic.start(timeline_name)


func _on_timeline_ended() -> void:
	_do_advance()


func _on_dialogic_signal(argument: String) -> void:
	if argument == "advance":
		_do_advance()


func _do_advance() -> void:
	if _advanced:
		return
	_advanced = true
	if Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.disconnect(_on_timeline_ended)
	if Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.disconnect(_on_dialogic_signal)
	Dialogic.clear()
	GameManager.advance()
