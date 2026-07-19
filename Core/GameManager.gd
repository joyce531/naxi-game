extends Node

## Central flow director + quiz session state.
##
## Owns the ordered flow (VN timelines, quizzes, end). VN/quiz scenes report
## completion by calling advance(). A quiz plays all questions once, then one
## redo round over the wrong ones; the final correctness ratio decides pass
## (advance) vs fail (fail screen -> restart the entire quiz).

const MAIN_MENU := "res://Scenes/MainMenu.tscn"
const VN_STAGE := "res://Scenes/VNStage.tscn"
const DONGBA_QUIZ := "res://Scenes/DongbaQuiz.tscn"
const MUSIC_QUIZ := "res://Scenes/MusicQuiz.tscn"
const RESULT_SCREEN := "res://Scenes/ResultScreen.tscn"
const END_SCREEN := "res://Scenes/EndScreen.tscn"

# --- Flow state ---
var _flow: Array = []
var _index: int = -1

## The timeline name a freshly-loaded VNStage should start. Read by VNStage._ready().
var pending_timeline: String = ""

# --- Quiz session state ---
# _session = {
#   quiz_id, title, pass_ratio,
#   questions: Array[Dictionary],          # full ordered question list
#   results: { id: bool },                 # latest attempt per question id
#   queue: Array[int],                     # indices to play this round
#   pos: int,                              # position within queue
#   round: int
# }
var _session: Dictionary = {}

## Summary handed to ResultScreen. { passed, ratio, correct, total, title }
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
	var step: Dictionary = _flow[_index]
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
	_session = {
		"quiz_id": quiz_id,
		"title": q.get("title", ""),
		"pass_ratio": float(q.get("pass_ratio", 0.8)),
		"questions": questions,
		"results": {},
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
func session_answer(chosen_index: int) -> Dictionary:
	var q: Dictionary = session_current()
	if q.is_empty():
		return {}
	var answer_index: int = int(q.get("answer_index", 0))
	var correct: bool = chosen_index == answer_index
	var results: Dictionary = _session.get("results", {})
	results[q.get("id", "")] = correct
	_session["results"] = results
	return {
		"correct": correct,
		"answer_index": answer_index,
		"chosen_index": chosen_index,
		"explanation": q.get("explanation", ""),
	}


func session_has_next() -> bool:
	var pos: int = _session.get("pos", 0)
	return pos + 1 < _session.get("queue", []).size()


func session_step() -> void:
	_session["pos"] = int(_session.get("pos", 0)) + 1


## Called when the current round's queue is exhausted. On the first round, if
## any answers were wrong it starts one redo round over just those questions.
## Otherwise it ends the session: pass -> advance directly to the next flow
## step; fail -> route to the fail screen. Returns "next_round", "passed" or
## "failed" so the quiz scene knows whether to keep showing questions.
func session_end_round() -> String:
	var wrong: Array = _wrong_indices()
	if int(_session.get("round", 1)) == 1 and wrong.size() > 0:
		_session["queue"] = wrong
		_session["pos"] = 0
		_session["round"] = 2
		return "next_round"

	var ratio: float = _session_ratio()
	var passed: bool = ratio >= float(_session.get("pass_ratio", 0.8))
	last_result = {
		"passed": passed,
		"ratio": ratio,
		"correct": _session_correct_count(),
		"total": _session.get("questions", []).size(),
		"title": _session.get("title", ""),
	}
	if passed:
		advance()
		return "passed"
	SceneLoader.goto_scene(RESULT_SCREEN)
	return "failed"


func _wrong_indices() -> Array:
	var results: Dictionary = _session.get("results", {})
	var questions: Array = _session.get("questions", [])
	var wrong: Array = []
	for i in questions.size():
		if not results.get(questions[i].get("id", ""), false):
			wrong.append(i)
	return wrong


func _session_correct_count() -> int:
	var results: Dictionary = _session.get("results", {})
	var c: int = 0
	for q in _session.get("questions", []):
		if results.get(q.get("id", ""), false):
			c += 1
	return c


func _session_ratio() -> float:
	var total: int = _session.get("questions", []).size()
	if total == 0:
		return 0.0
	return float(_session_correct_count()) / float(total)


# ---------------------------------------------------------------------------
# Fail screen callbacks
# ---------------------------------------------------------------------------

## Restart the ENTIRE current quiz from scratch (fresh results, all questions).
func quiz_restart() -> void:
	_start_quiz(_session.get("quiz_id", ""))


## Escape hatch: abandon the session and return to the main menu.
func result_quit() -> void:
	_to_menu()
