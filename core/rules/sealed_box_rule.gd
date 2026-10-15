class_name SealedBoxRule
extends RuleBase
## "Möhürlü qutu" (chapter waves v1, section 3.1, karakuri wave 5): a sealed
## karakuri box. Nothing may be taken out of it, and the only disk that may be
## put onto its lid is the smallest one (user decision 2026-10-16); that move
## breaks the seal for good (like the foundation: once open, open). Which boxes
## are open is the rule's memory: bit i set means the i-th of `pegs` is open.
## The board draws a seal on the box and the box stays closed to taps. Level
## JSON (the sealed pegs are covered pegs too):
##   "rules": ["classic_hanoi", "sealed_box"],
##   "rule_params": {"sealed_box": {"pegs": [2]}}

const ID: String = "sealed_box"
## The disk that opens a seal.
const KEY_DISK: int = 1

var pegs: Array[int] = []


func _init() -> void:
	violation_message = "RULE_SEALED"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var value: Variant = params.get("pegs")
	if params.size() != 1 or typeof(value) != TYPE_ARRAY or (value as Array).is_empty() \
			or not (value as Array).all(func(p: Variant) -> bool: return typeof(p) == TYPE_INT and p >= 0):
		return "rule \"%s\" needs {\"pegs\": [sealed peg indices]}" % ID
	pegs.assign(value)
	return ""


func get_params() -> Dictionary:
	return {"pegs": pegs.duplicate()}


## Whether `peg` is still sealed under `memory`.
func is_sealed(memory: int, peg: int) -> bool:
	var index: int = pegs.find(peg)
	return index != -1 and (memory >> index) & 1 == 0


func is_disk_movable_with(disk: int, facts: MoveFacts) -> bool:
	return not is_sealed(facts.memory, facts.peg_of[disk])


func is_move_allowed_with(disk: int, from_peg: int, to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	return not is_sealed(facts.memory, from_peg) and (disk == KEY_DISK or not is_sealed(facts.memory, to_peg))


func uses_memory() -> bool:
	return true


func memory_states(_peg_count: int, _disk_count: int) -> int:
	return 1 << pegs.size()


## Every box starts sealed.
func start_memory(_state: PuzzleState) -> int:
	return 0


func memory_after(facts: MoveFacts, disk: int, _from_peg: int, to_peg: int) -> int:
	var index: int = pegs.find(to_peg)
	if disk == KEY_DISK and index != -1:
		return facts.memory | (1 << index)
	return facts.memory


func needs_facts() -> bool:
	return true
