class_name HintNudgeWatcher
extends Node
## Points a stuck player at the Hint button (economy/UX addendum, section 3)
## with the shared FocusRing; no visuals of its own.
## - Idle: no tap for IDLE_SECONDS -> the ring breathes around the Hint button.
## - Mistakes: MISTAKES_IN_A_ROW refused moves without a legal move between
##   them -> the same ring, plus MISTAKE_TEXT on the CoachToast once per level.
## Any tap, move, undo or hint removes the ring at once. Nothing is shown during
## a tutorial, while a hint is on screen or being searched, after the level is
## solved, or when the player cannot afford a hint.

const IDLE_SECONDS: float = 9.0
const MISTAKES_IN_A_ROW: int = 2
## Translation key of the one-time toast.
const MISTAKE_TEXT: String = "NUDGE_MISTAKES"
const TOAST_SECONDS: float = 2.6

## Why the ring is shown: "" (not shown), "idle" or "mistakes".
var reason: String = ""
var idle_seconds: float = 0.0
var mistakes_in_a_row: int = 0

var _board: GameBoard
var _coaching: CoachingLayer
var _hints: HintController
var _economy: EconomySystem
var _toast_used: bool = false


func setup(board: GameBoard, coaching: CoachingLayer, hints: HintController, economy: EconomySystem) -> void:
	_board = board
	_coaching = coaching
	_hints = hints
	_economy = economy
	board.level_started.connect(_on_level_started)
	board.position_changed.connect(_on_position_changed)
	board.selection_changed.connect(_on_player_acted.unbind(1))
	board.illegal_move.connect(_on_illegal_move)
	board.pick_up_refused.connect(func(_peg: int, _message: String) -> void: _count_mistake())


func is_showing() -> bool:
	return not reason.is_empty()


## Hides the ring (if this watcher put it there) and restarts the idle count.
func dismiss() -> void:
	idle_seconds = 0.0
	if is_showing():
		reason = ""
		_coaching.ring.hide_ring()


## Advances the idle count by `delta` seconds (called every frame).
func advance(delta: float) -> void:
	if not _may_nudge():
		idle_seconds = 0.0
		if is_showing():
			dismiss()
		return
	if is_showing():
		_follow_button()
		return
	idle_seconds += delta
	if idle_seconds >= IDLE_SECONDS:
		_show("idle")


func _process(delta: float) -> void:
	if _board != null and _board.session != null:
		advance(delta)


func _may_nudge() -> bool:
	var session: GameSession = _board.session
	return session != null and not session.is_solved() \
			and (_board.tutorial == null or _board.tutorial.mode == TutorialDirector.Mode.OFF) \
			and _board.restricted_peg < 0 and not _hints.is_showing() and not _hints.is_pending() \
			and _economy.can_afford(_economy.hint_cost(session.level.difficulty))


func _show(why: String) -> void:
	reason = why
	_coaching.ring.show_around(_board.get_hint_button_rect())


## Keeps the ring on the button if the screen is laid out again.
func _follow_button() -> void:
	var rect: Rect2 = _board.get_hint_button_rect()
	if not _coaching.ring.get_target().is_equal_approx(rect):
		_coaching.ring.show_around(rect)


func _on_level_started() -> void:
	dismiss()
	mistakes_in_a_row = 0
	_toast_used = false


func _on_position_changed() -> void:
	mistakes_in_a_row = 0
	dismiss()


func _on_player_acted() -> void:
	dismiss()


func _on_illegal_move(_move: Move, _message: String) -> void:
	_count_mistake()


## A refused move or a tap on a pinned disk.
func _count_mistake() -> void:
	dismiss()
	mistakes_in_a_row += 1
	if mistakes_in_a_row < MISTAKES_IN_A_ROW or not _may_nudge():
		return
	_show("mistakes")
	if not _toast_used:
		_toast_used = true
		_coaching.toast.show_message(tr(MISTAKE_TEXT), TOAST_SECONDS)
