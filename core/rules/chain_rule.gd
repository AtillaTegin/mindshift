class_name ChainRule
extends RuleBase
## "Zəncirlənmiş Disklər" (new mechanics specification v1, section 2): two
## disks of different sizes are chained. They never move alone: when both are
## on top of their pegs, one compound move takes each to its own, different
## target, each judged by the other rules as if it moved alone. It counts as
## one move. The rule only names the pair (partner_of); RuleSet and the Solver
## make the compound moves. Level JSON:
##   "rules": ["classic_hanoi", "chain"], "rule_params": {"chain": {"disks": [2, 4]}}

const ID: String = "chain"

var disks: Array[int] = []


func _init() -> void:
	violation_message = "RULE_CHAIN"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var value: Variant = params.get("disks")
	if params.size() != 1 or typeof(value) != TYPE_ARRAY or (value as Array).size() != 2 \
			or not (value as Array).all(func(d: Variant) -> bool: return typeof(d) == TYPE_INT and d >= 1) \
			or value[0] == value[1]:
		return "rule \"%s\" needs {\"disks\": [two different disks]}" % ID
	disks.assign(value)
	return ""


func get_params() -> Dictionary:
	return {"disks": disks.duplicate()}


func partner_of(disk: int) -> int:
	if disk == disks[0]:
		return disks[1]
	return disks[0] if disk == disks[1] else 0


func supports_disk_move_check() -> bool:
	return true
