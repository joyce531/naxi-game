extends Node

## Central flow director + quiz session state.
##
## Owns the ordered flow (VN timelines, quizzes, end). VN/quiz scenes report
## completion by calling advance(). A quiz re-asks wrong questions in rounds; a
## question is removed once answered correctly, or marked "skipped" after 3
## cumulative wrong answers (with an inline review hint at that moment). The quiz
## ends when no questions remain pending, then advances to the next flow step.
## There is no pass/fail judgment.

const MAIN_MENU := "res://Scenes/MainMenu.tscn"
const VN_STAGE := "res://Scenes/VNStage.tscn"
const DONGBA_QUIZ := "res://Scenes/DongbaQuiz.tscn"
const MUSIC_QUIZ := "res://Scenes/MusicQuiz.tscn"
const END_SCREEN := "res://Scenes/EndScreen.tscn"

## A question is marked "skipped" (explained, then removed) after this many
## cumulative wrong answers across all rounds.
const MAX_WRONG := 3

## Save file holds ONLY the current flow step (no quiz details): { version, step }.
const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

# --- Flow state ---
var _flow: Array = []
var _index: int = -1

## The timeline name a freshly-loaded VNStage should start. Read by VNStage._ready().
var pending_timeline: String = ""

# --- Quiz session state ---
# _session = {
#   quiz_id, title,
#   questions: Array[Dictionary],                     # full ordered question list
#   wrong_counts: { id: int },                        # cumulative wrong count
#   status: { id: "pending"|"done"|"skipped" },
#   queue: Array[int],                                # question indices this round
#   pos: int,                                         # position within queue
#   round: int
# }
var _session: Dictionary = {}

## Retained for the (now unused) ResultScreen; the flow no longer populates it.
var last_result: Dictionary = {}


func _ready() -> void:
	_build_flow()


func _build_flow() -> void:
	_flow = [
		{"kind": "vn", "timeline": "opening"},
		{"kind": "vn", "timeline": "dongba_intro"},
		{"kind": "quiz", "quiz_id": "dongba"},
		{"kind": "vn", "timeline": "clear_story"},
		{"kind": "vn", "timeline": "music_intro"},
		{"kind": "quiz", "quiz_id": "music"},
		{"kind": "end"},
	]


## Begin the whole demo from the first step.
func start_game() -> void:
	_index = -1
	_session = {}
	advance()


## Advance to the next flow step. Called by VN/quiz scenes when a step completes.
func advance() -> void:
	_index += 1
	if _index >= _flow.size():
		_to_menu()
		return
	_enter_step(_index)


## Enter (or re-enter) a specific flow step without changing _index otherwise.
func _enter_step(i: int) -> void:
	var step: Dictionary = _flow[i]
	match step.get("kind", ""):
		"vn":
			pending_timeline = step.get("timeline", "")
			SceneLoader.goto_scene(VN_STAGE)
		"quiz":
			_start_quiz(step.get("quiz_id", ""))
		"end":
			SceneLoader.goto_scene(END_SCREEN)
		_:
			push_error("[GameManager] Unknown flow step: %s" % step)
			_to_menu()


func _to_menu() -> void:
	_index = -1
	_session = {}
	SceneLoader.goto_scene(MAIN_MENU)


## True while the player is inside the flow (i.e. not on the main menu).
func is_in_game() -> bool:
	return _index >= 0 and _index < _flow.size()


# ---------------------------------------------------------------------------
# Save / load (only the current step; quiz progress is intentionally dropped)
# ---------------------------------------------------------------------------

## Write the current flow step to disk. Returns false if not in a game.
func save_progress() -> bool:
	if not is_in_game():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[GameManager] Could not open save file for writing.")
		return false
	f.store_string(JSON.stringify({"version": SAVE_VERSION, "step": _index}))
	f.close()
	return true


## True when a usable save exists.
func has_save() -> bool:
	return _read_saved_step() >= 0


## Resume from the saved step (quiz steps restart from question 1). Falls back to
## a fresh game if the save is missing/invalid.
func continue_game() -> void:
	var step := _read_saved_step()
	if step < 0:
		start_game()
		return
	_index = step
	_session = {}
	_enter_step(_index)


## Delete any existing save file.
func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


## Returns a valid saved step index, or -1 if there is no usable save.
func _read_saved_step() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return -1
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return -1
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return -1
	var step: int = int(parsed.get("step", -1))
	if step < 0 or step >= _flow.size():
		return -1
	return step


# ---------------------------------------------------------------------------
# Quiz session
# ---------------------------------------------------------------------------

func _quiz_scene_path(quiz_id: String) -> String:
	match quiz_id:
		"music":
			return MUSIC_QUIZ
		_:
			return DONGBA_QUIZ


func _start_quiz(quiz_id: String) -> void:
	var q: Dictionary = ContentDB.get_quiz(quiz_id)
	var questions: Array = q.get("questions", [])
	var all_indices: Array = []
	for i in questions.size():
		all_indices.append(i)
	var status := {}
	for qq in questions:
		status[qq.get("id", "")] = "pending"
	_session = {
		"quiz_id": quiz_id,
		"title": q.get("title", ""),
		"questions": questions,
		"wrong_counts": {},
		"status": status,
		"queue": all_indices,
		"pos": 0,
		"round": 1,
	}
	SceneLoader.goto_scene(_quiz_scene_path(quiz_id))


func has_active_session() -> bool:
	return not _session.is_empty() and not _session.get("questions", []).is_empty()


func session_title() -> String:
	return _session.get("title", "")


## The question at the current queue position.
func session_current() -> Dictionary:
	var queue: Array = _session.get("queue", [])
	var pos: int = _session.get("pos", 0)
	if pos < 0 or pos >= queue.size():
		return {}
	var qi: int = queue[pos]
	var questions: Array = _session.get("questions", [])
	return questions[qi]


## Progress string like "第 2 / 5 题" for the current round.
func session_progress() -> String:
	var pos: int = _session.get("pos", 0)
	var total: int = _session.get("queue", []).size()
	return "第 %d / %d 题" % [pos + 1, total]


## Record the answer for the current question and return feedback for the card.
## Sets the question's status and, on the 3rd cumulative wrong, marks it skipped
## and returns the inline review hint.
func session_answer(chosen_index: int) -> Dictionary:
	var q: Dictionary = session_current()
	if q.is_empty():
		return {}
	var id: String = q.get("id", "")
	var answer_index: int = int(q.get("answer_index", 0))
	var correct: bool = chosen_index == answer_index
	var status: Dictionary = _session.get("status", {})
	var wrong_counts: Dictionary = _session.get("wrong_counts", {})
	var just_skipped := false
	if correct:
		status[id] = "done"
	else:
		wrong_counts[id] = int(wrong_counts.get(id, 0)) + 1
		if wrong_counts[id] >= MAX_WRONG:
			status[id] = "skipped"
			just_skipped = true
	_session["status"] = status
	_session["wrong_counts"] = wrong_counts
	return {
		"correct": correct,
		"answer_index": answer_index,
		"chosen_index": chosen_index,
		"explanation": q.get("explanation", ""),
		"skipped": just_skipped,
		"skip_hint": _skip_hint() if just_skipped else "",
	}


func _skip_hint() -> String:
	match _session.get("quiz_id", ""):
		"music":
			return "这段音乐要注意哟！"
		_:
			return "这个文字要注意哟！"


func session_has_next() -> bool:
	var pos: int = _session.get("pos", 0)
	return pos + 1 < _session.get("queue", []).size()


func session_step() -> void:
	_session["pos"] = int(_session.get("pos", 0)) + 1


## Called when the current round's queue is exhausted. The next round is every
## still-"pending" question (correct ones are done, 3x-wrong ones are skipped).
## When nothing is pending the quiz is finished and we advance to the next flow
## step. Returns "next_round" or "finished".
func session_end_round() -> String:
	var pending: Array = _pending_indices()
	if pending.is_empty():
		advance()
		return "finished"
	_session["queue"] = pending
	_session["pos"] = 0
	_session["round"] = int(_session.get("round", 1)) + 1
	return "next_round"


func _pending_indices() -> Array:
	var status: Dictionary = _session.get("status", {})
	var questions: Array = _session.get("questions", [])
	var pending: Array = []
	for i in questions.size():
		if status.get(questions[i].get("id", ""), "pending") == "pending":
			pending.append(i)
	return pending


# ---------------------------------------------------------------------------
# Navigation helpers (kept for the unused ResultScreen / upcoming control bar)
# ---------------------------------------------------------------------------

## Restart the ENTIRE current quiz from scratch (all questions, fresh state).
func quiz_restart() -> void:
	_start_quiz(_session.get("quiz_id", ""))


## Abandon the session and return to the main menu.
func result_quit() -> void:
	_to_menu()
