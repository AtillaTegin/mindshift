class_name SortSession
extends RefCounted
## Play state of the colour-order prototype: position, selection and the move
## budget. With M = move_limit and m = moves made, R = M - m moves remain. Only
## a successful transfer counts; picking up, putting back and refused moves are
## free. The game is won as soon as the target shows, within the limit, and
## lost when R reaches 0 without it (a win on the last move is a win).

enum TapResult { SELECTED, DESELECTED, MOVED, ILLEGAL, IGNORED }
enum Status { PLAYING, WON, LOST }

## Move limit picked on the prototype menu for testing; 0 keeps the level's own.
static var limit_override: int = 0

var puzzle: SortPuzzle
var pegs: Array[Array] = []
var move_limit: int = 0
var moves_made: int = 0
## Peg whose top disk is picked up, or -1.
var selected_peg: int = -1
var status: Status = Status.PLAYING


func _init(p_puzzle: SortPuzzle, p_move_limit: int = 0) -> void:
	puzzle = p_puzzle
	move_limit = p_move_limit if p_move_limit > 0 else puzzle.move_limit
	restart()


func restart() -> void:
	pegs = SortPuzzle.copy_pegs(puzzle.start)
	moves_made = 0
	selected_peg = -1
	status = Status.PLAYING


func remaining() -> int:
	return move_limit - moves_made


func matched_count() -> int:
	return puzzle.matched_count(pegs)


## Disk id picked up, or -1.
func selected_disk() -> int:
	return SortPuzzle.top_of(pegs, selected_peg) if selected_peg != -1 else -1


## A tap on a peg: picks up its top disk, puts it back (same peg) or moves it
## there. A refused move keeps the selection so another peg can be tried.
func tap_peg(peg_index: int) -> TapResult:
	if status != Status.PLAYING or peg_index < 0 or peg_index >= pegs.size():
		return TapResult.IGNORED
	if selected_peg == -1:
		if pegs[peg_index].is_empty():
			return TapResult.IGNORED
		selected_peg = peg_index
		return TapResult.SELECTED
	if peg_index == selected_peg:
		selected_peg = -1
		return TapResult.DESELECTED
	return TapResult.MOVED if try_move(Move.new(selected_peg, peg_index)) else TapResult.ILLEGAL


## Makes `move` if it is legal and the game is on; returns whether it was made.
func try_move(move: Move) -> bool:
	if status != Status.PLAYING or not puzzle.can_move(pegs, move):
		return false
	pegs = SortPuzzle.apply(pegs, move)
	moves_made += 1
	selected_peg = -1
	if puzzle.is_goal(pegs):
		status = Status.WON
	elif remaining() <= 0:
		status = Status.LOST
	return true
