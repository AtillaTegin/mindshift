class_name HintController
extends Node
## Spec 4.7 hint, presented on the coaching overlay (addendum 2.3): the scrim
## dims the board, a ring marks the disk to move and a ghost finger shows where
## it goes. It never moves the disk. The Day 6 rules are unchanged: a hint costs
## EconomySystem.hint_cost() for the level's tier (free while unlimited hints are
## active), asking again in the same position is free, on the
## stored solution path the answer is instant, and off the path the Solver runs
## on a worker thread so the screen never freezes.

## Status text for the board ("" clears it).
signal message_changed(text: String)

## Run off-path searches on a worker thread (tests turn this off).
var background: bool = true
## The move the current hint points at, or null.
var hint_move: Move
## Points idle or stuck players at the Hint button (economy/UX addendum 3).
var nudge: HintNudgeWatcher

var _board: GameBoard
var _coaching: CoachingLayer
var _economy: EconomySystem
## Position the shown hint belongs to.
var _hint_key: String = ""
var _thread: Thread
## Position the running background search belongs to.
var _pending_key: String = ""
## When the running background search started (debug builds print how long it
## took, for the phone performance test: adb logcat).
var _started_ms: int = 0


func setup(board: GameBoard, coaching: CoachingLayer, economy: EconomySystem) -> void:
	_board = board
	_coaching = coaching
	_economy = economy
	board.position_changed.connect(clear)
	board.selection_changed.connect(_on_selection_changed)
	board.layout_changed.connect(_on_layout_changed)
	nudge = HintNudgeWatcher.new()
	nudge.name = "HintNudgeWatcher"
	nudge.setup(board, coaching, self, economy)
	add_child(nudge)


func is_pending() -> bool:
	return _thread != null


func is_showing() -> bool:
	return hint_move != null


func request() -> void:
	var session: GameSession = _board.session
	if session == null or session.is_solved() or is_pending():
		return
	# The ring is about to show the hint instead of the button.
	nudge.dismiss()
	var key: String = session.state.hash_key()
	if hint_move != null and key == _hint_key:
		_present()
		return
	# A dead end has no next move: free, the status line keeps saying so (any
	# other note gives way to it) with the way back beside it.
	if _board.dead_ends != null and _board.dead_ends.is_dead():
		message_changed.emit("")
		return
	if not _economy.can_afford(_economy.hint_cost(session.level.difficulty)):
		message_changed.emit(tr("HINT_NO_COINS"))
		return
	var on_path: Move = session.get_path_hint()
	if on_path != null:
		_apply(on_path, key)
		return
	var from_state: PuzzleState = session.state.duplicate_state()
	var level: Level = session.level
	var rules: RuleSet = session.rules
	if not background:
		_apply(GameSession.solve_hint(level, from_state, rules), key)
		return
	_pending_key = key
	_started_ms = Time.get_ticks_msec()
	_thread = Thread.new()
	_thread.start(func() -> Move: return GameSession.solve_hint(level, from_state, rules))
	message_changed.emit(tr("HINT_SEARCHING"))


## Forgets the hint and hides the overlay (called whenever the position changes).
func clear() -> void:
	if hint_move == null:
		return
	hint_move = null
	_hint_key = ""
	_coaching.clear()


func _process(_delta: float) -> void:
	if _thread == null or _thread.is_alive():
		return
	var move: Move = _thread.wait_to_finish()
	_thread = null
	if OS.is_debug_build() and _board.session != null:
		print("MindShift hint search: %d ms (level %d)" % [Time.get_ticks_msec() - _started_ms, _board.session.level.id])
	var key: String = _pending_key
	_pending_key = ""
	var session: GameSession = _board.session
	# Only show it if the player has not moved on meanwhile (then it is free).
	if session != null and not session.is_solved() and session.state.hash_key() == key:
		_apply(move, key)
	else:
		message_changed.emit("")


func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


## Shows a found hint and charges for it; a missing hint costs nothing. When
## the search found none (a dead end of a level whose moves cannot all be taken
## back) the hint leads back to the stored solution, or asks the player to take
## a move back where it cannot.
func _apply(move: Move, key: String) -> void:
	if move == null:
		move = _board.session.return_to_path_move()
	if move == null:
		message_changed.emit(tr("HINT_TAKE_BACK" if _board.session.can_undo() else "HINT_NOT_FOUND"))
		return
	_economy.spend(_economy.hint_cost(_board.session.level.difficulty))
	hint_move = move
	_hint_key = key
	message_changed.emit("")
	_present()


func _present() -> void:
	MoveCoach.present(_coaching, _board, hint_move, _board.session.selected_peg == hint_move.from_peg)


func _on_selection_changed(_peg_index: int) -> void:
	if hint_move != null:
		_present()


## Follows the board when it is laid out again (e.g. a new screen size).
func _on_layout_changed() -> void:
	if hint_move != null and _board.session.state.hash_key() == _hint_key:
		_present()
