class_name DeadEndWatcher
extends Node
## The dead-end rule (Mod Kataloqu v1.1, section D.3: nobody loses). On a level
## whose rules can leave the goal out of reach for good (RuleSet.can_dead_end,
## today the mixed exchange) every new position is checked after the move, on
## a worker thread like an off-path hint. A dead end is only claimed when the
## search proves it (GameSession.is_dead_end); the board then says so kindly
## and offers a free way back to the last position that can still be solved.
## Levels whose rules cannot dead-end are never searched.

## A dead end was found, or play left it.
signal changed

## Search on a worker thread (tests turn this off).
var background: bool = true
## Moves on the board at the first dead position of the current line of play,
## or -1. Every later position of that line is a dead end too.
var dead_at: int = -1
## Searches started so far (none on levels that cannot dead-end).
var searches: int = 0

var _board: GameBoard
## Moves of the longest start of the current history known to be solvable
## (the start always is: levels are built from a solution).
var _live: int = 0
var _thread: Thread
## The running search: its level, the first move count it checks and the
## search keys of its positions, to see on return whether play has changed
## them meanwhile.
var _check_level: Level
var _check_from: int = 0
var _check_keys: PackedStringArray = PackedStringArray()
## The position changed while a search was running: look again when it ends.
var _again: bool = false


func setup(board: GameBoard) -> void:
	_board = board
	board.level_started.connect(_reset)
	board.position_changed.connect(_on_position_changed)


## Whether the position on the board is a dead end.
func is_dead() -> bool:
	return dead_at != -1 and _board.session != null and _board.session.history.size() >= dead_at


## How many moves the free way back keeps: up to the last position that can
## still be solved.
func way_back() -> int:
	return dead_at - 1


func _reset() -> void:
	var was_dead: bool = is_dead()
	_live = 0
	dead_at = -1
	_again = false
	if was_dead:
		changed.emit()


func _on_position_changed() -> void:
	var session: GameSession = _board.session
	if session == null or not session.rules.can_dead_end():
		return
	var moves: int = session.history.size()
	# Moves taken back: what is left of the line was checked already.
	_live = mini(_live, moves)
	if dead_at != -1 and moves < dead_at:
		dead_at = -1
		_live = moves
		changed.emit()
	if dead_at != -1 or moves <= _live or session.is_solved():
		return
	if _thread != null:
		_again = true
		return
	_check_level = session.level
	_check_from = _live + 1
	var line: Array[PuzzleState] = []
	_check_keys = PackedStringArray()
	for count: int in range(_check_from, moves + 1):
		var position: PuzzleState = session.position_after(count).duplicate_state()
		line.append(position)
		_check_keys.append(session.rules.search_key(position))
	var level: Level = session.level
	var rules: RuleSet = session.rules
	searches += 1
	if not background:
		_take(GameSession.first_dead_end(level, line, rules))
		return
	_thread = Thread.new()
	_thread.start(func() -> int: return GameSession.first_dead_end(level, line, rules))


func _process(_delta: float) -> void:
	if _thread == null or _thread.is_alive():
		return
	var found: int = _thread.wait_to_finish()
	_thread = null
	_take(found)
	if _again:
		_again = false
		_on_position_changed()


func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


## A search's answer for the line from _check_from: the index of its first dead
## end or -1. Kept only for the positions play still has.
func _take(found: int) -> void:
	var session: GameSession = _board.session
	if session == null or session.level != _check_level:
		return
	var moves: int = session.history.size()
	var last: int = _check_from + _check_keys.size() - 1
	if found == -1:
		if last <= moves and session.rules.search_key(session.position_after(last)) == _check_keys[-1]:
			_live = maxi(_live, last)
		return
	var first: int = _check_from + found
	if first <= moves and session.rules.search_key(session.position_after(first)) == _check_keys[found]:
		dead_at = first
		_live = mini(_live, first - 1)
		changed.emit()
