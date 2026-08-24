extends Node

## Loads res://Data/content.json and serves quiz data + asset resolution.
## Missing assets fall back to placeholders so the framework runs before real
## art/audio exist: missing images resolve to null (callers draw a labeled box),
## missing audio resolves to the silent placeholder stream.

const CONTENT_PATH := "res://Data/content.json"
const PLACEHOLDER_SILENT := "res://Assets/_placeholder/silent.wav"

var _data: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	_data = {}
	if not FileAccess.file_exists(CONTENT_PATH):
		push_error("[ContentDB] Missing content file: %s" % CONTENT_PATH)
		return
	var f := FileAccess.open(CONTENT_PATH, FileAccess.READ)
	if f == null:
		push_error("[ContentDB] Could not open: %s" % CONTENT_PATH)
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[ContentDB] content.json did not parse to a Dictionary.")
		return
	_data = parsed


## Returns { title, pass_ratio, questions } for a quiz id (safe defaults if absent).
func get_quiz(quiz_id: String) -> Dictionary:
	var quizzes: Dictionary = _data.get("quizzes", {})
	var q: Dictionary = quizzes.get(quiz_id, {})
	return {
		"title": q.get("title", ""),
		"pass_ratio": float(q.get("pass_ratio", 0.8)),
		"questions": q.get("questions", []),
	}


func _is_usable(path: Variant) -> bool:
	return typeof(path) == TYPE_STRING and path != "" and ResourceLoader.exists(path)


## Load a texture, or null if the path is empty/missing (caller shows a placeholder).
func load_texture(path: Variant) -> Texture2D:
	if _is_usable(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	return null


## Load an audio stream, falling back to the silent placeholder when missing.
func load_audio(path: Variant) -> AudioStream:
	if _is_usable(path):
		var res: Resource = load(path)
		if res is AudioStream:
			return res
	if ResourceLoader.exists(PLACEHOLDER_SILENT):
		var ph: Resource = load(PLACEHOLDER_SILENT)
		if ph is AudioStream:
			return ph
	return null


## Load a video stream, or null when missing (caller shows a placeholder panel).
func load_video(path: Variant) -> VideoStream:
	if _is_usable(path):
		var res: Resource = load(path)
		if res is VideoStream:
			return res
	return null


func path_is_video(path: Variant) -> bool:
	return typeof(path) == TYPE_STRING and path.to_lower().ends_with(".ogv")


## A short human-readable label derived from an intended asset path,
## used to fill placeholder boxes when the real file is missing.
func label_for_path(path: Variant) -> String:
	if typeof(path) != TYPE_STRING or path == "":
		return "?"
	return path.get_file().get_basename()
