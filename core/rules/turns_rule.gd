class_name TurnsRule
extends RuleBase
## "Növbə" (ICRA World 5-9, section 3.11): the disks are white and black and
## the moves take turns, white first: white, black, white... The turn shows at
## the top of the board. On top of classic Hanoi. Level JSON:
##   "rules": ["classic_hanoi", "turns"], "rule_params": {"turns": {"colours": [0, 1, 1, 0]}}
## Settings ("colours" per disk, disk 1 first: 0 white, 1 black, 2 red, -1 grey):
##   "order": [0, 0, 1, 1]  "İkiqat növbə" (white, white, black, black); [0, 1, 2]
##                          "Üç rəng" (white, black, red)
##   a grey disk (-1)       "Boz disk": it moves in any turn (the turn passes on)
##   "pass": true           "Pas": once a level a turn may be passed (its button)
## The base form and three colours follow the colour of the disk that moved
## last; a grey disk, a pass or a double turn keep the turn in the memory
## (its place in the order, and whether the pass is spent).

const ID: String = "turns"
const WHITE: int = 0
const BLACK: int = 1
const RED: int = 2
const GREY: int = -1

var colours: Array[int] = []
var order: Array[int] = [WHITE, BLACK]
var passing: bool = false
## Whether the turn lives in the memory (set by configure()).
var _remembers: bool = false


func _init() -> void:
	violation_message = "RULE_TURN"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs \"colours\": [-1..2 per disk], optional \"order\": [colours], \"pass\": true" % ID
	for key: String in params:
		if not key in ["colours", "order", "pass"]:
			return problem
	for key: String in ["colours", "order"]:
		var list: Variant = params.get(key, [])
		if typeof(list) != TYPE_ARRAY or not (list as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT and v >= -1 and v <= RED):
			return problem
	colours.assign(params.get("colours", []))
	if colours.is_empty():
		return problem
	if params.has("order"):
		order.assign(params["order"])
	if order.size() < 2 or order.has(GREY) or typeof(params.get("pass", false)) != TYPE_BOOL:
		return problem
	passing = params.get("pass", false)
	var distinct: Array[int] = []
	for colour: int in order:
		if not distinct.has(colour):
			distinct.append(colour)
	_remembers = passing or colours.has(GREY) or distinct.size() != order.size()
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {"colours": colours.duplicate()}
	var alternate: Array[int] = [WHITE, BLACK]
	if order != alternate:
		params["order"] = order.duplicate()
	if passing:
		params["pass"] = true
	return params


func colour_of(disk: int) -> int:
	return colours[disk - 1] if disk >= 1 and disk <= colours.size() else GREY


## Whether the turn lives in the memory (else the last disk's colour gives it).
func uses_memory() -> bool:
	return _remembers


func uses_last_move() -> bool:
	return not uses_memory()


## The memory: the place in the order, plus the order's length once the pass is spent.
func memory_states(_peg_count: int, _disk_count: int) -> int:
	return order.size() * (2 if passing else 1)


## The colour whose turn it is with `facts`.
func turn_of(facts: MoveFacts) -> int:
	if uses_memory():
		return order[facts.memory % order.size()]
	if facts.last_disk <= 0:
		return order[0]
	return order[(order.find(colour_of(facts.last_disk)) + 1) % order.size()]


func is_disk_movable_with(disk: int, facts: MoveFacts) -> bool:
	return colour_of(disk) == GREY or colour_of(disk) == turn_of(facts)


func is_move_allowed_with(disk: int, _from_peg: int, _to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	return is_disk_movable_with(disk, facts)


func is_disk_move_allowed_after(disk: int, _from_peg: int, _to_peg: int, _target_top: int, last_disk: int) -> bool:
	if colour_of(disk) == GREY:
		return true
	var turn: int = order[0] if last_disk <= 0 else order[(order.find(colour_of(last_disk)) + 1) % order.size()]
	return colour_of(disk) == turn


func supports_disk_move_check() -> bool:
	return not uses_memory()


func needs_facts() -> bool:
	return uses_memory()


## The next place in the order (the pass bit kept).
func memory_after(facts: MoveFacts, _disk: int, _from_peg: int, _to_peg: int) -> int:
	var place: int = facts.memory % order.size()
	var spent: int = facts.memory / order.size()
	return (place + 1) % order.size() + order.size() * spent


## The pass, while not spent: Move.new(0, 0).
func special_moves(facts: MoveFacts) -> Array[Move]:
	var moves: Array[Move] = []
	if passing and facts.memory / order.size() == 0:
		moves.append(Move.new(0, 0))
	return moves


func has_special_moves() -> bool:
	return passing


func special_memory_after(facts: MoveFacts, _move: Move) -> int:
	return (facts.memory % order.size() + 1) % order.size() + order.size()


## The pass's button shows while the pass is not spent.
func special_open(facts: MoveFacts) -> bool:
	return passing and facts.memory / order.size() == 0


func special_label() -> String:
	return "PASS_TURN"


## The turn's colour names it: "İndi ağların növbəsidir."
func pick_up_message(_disk: int, facts: MoveFacts) -> String:
	return ["RULE_TURN_WHITE", "RULE_TURN_BLACK", "RULE_TURN_RED"][turn_of(facts)]


func get_violation_message(state: PuzzleState, _move: Move) -> String:
	return pick_up_message(0, MoveFacts.of(state, null))


## White and black swapped make the same puzzle only with the order swapped
## too; the colours stay as they are.
func params_without_pegs() -> Dictionary:
	return get_params()
