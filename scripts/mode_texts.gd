class_name ModeTexts
extends RefCounted
## The one register of every mode ("rejim") the player meets (mode labels
## specification v1, section 4): Level.lesson() -> the translation keys of its
## short label on the level map, its name and its one-sentence rule under the
## board. The level map and the board's rule panel read only this, and the
## texts live in locale/az.po. Modes that are not built yet (linked pegs)
## already have theirs. A test makes sure every mode the levels and the rule
## registry can produce is listed here, so a new mode cannot be forgotten.

## Level.lesson() -> [label key, name key, rule key] in az.po.
const MODES: Dictionary = {
	"classic": ["MODE_CLASSIC_LABEL", "MODE_CLASSIC_NAME", "MODE_CLASSIC_RULE"],
	"covered_pegs": ["MODE_KARAKURI_LABEL", "MODE_KARAKURI_NAME", "MODE_KARAKURI_RULE"],
	"alternation": ["MODE_NINE_RINGS_LABEL", "MODE_NINE_RINGS_NAME", "MODE_NINE_RINGS_RULE"],
	"adjacent_pegs": ["MODE_CARAVAN_LABEL", "MODE_CARAVAN_NAME", "MODE_CARAVAN_RULE"],
	"linked_pegs": ["MODE_LINKED_LABEL", "MODE_LINKED_NAME", "MODE_LINKED_RULE"],
	"color_swap": ["MODE_SWAP_LABEL", "MODE_SWAP_NAME", "MODE_SWAP_RULE"],
	"color_swap_mixed": ["MODE_SWAP_MIXED_LABEL", "MODE_SWAP_MIXED_NAME", "MODE_SWAP_MIXED_RULE"],
	"peg_capacity": ["MODE_CAPACITY_LABEL", "MODE_CAPACITY_NAME", "MODE_CAPACITY_RULE"],
	"foundation": ["MODE_FOUNDATION_LABEL", "MODE_FOUNDATION_NAME", "MODE_FOUNDATION_RULE"],
	"stripes": ["MODE_STRIPES_LABEL", "MODE_STRIPES_NAME", "MODE_STRIPES_RULE"],
	"balance": ["MODE_BALANCE_LABEL", "MODE_BALANCE_NAME", "MODE_BALANCE_RULE"],
	"chain": ["MODE_CHAIN_LABEL", "MODE_CHAIN_NAME", "MODE_CHAIN_RULE"],
	"cyclic": ["MODE_CYCLIC_LABEL", "MODE_CYCLIC_NAME", "MODE_CYCLIC_RULE"],
	"mirror": ["MODE_MIRROR_LABEL", "MODE_MIRROR_NAME", "MODE_MIRROR_RULE"],
	"trail": ["MODE_TRAIL_LABEL", "MODE_TRAIL_NAME", "MODE_TRAIL_RULE"],
	"magnet": ["MODE_MAGNET_LABEL", "MODE_MAGNET_NAME", "MODE_MAGNET_RULE"],
}


## Whether `lesson` is registered; a combination ("peg_capacity+foundation",
## chapter plan section 4) when each of its modes is.
static func has(lesson: String) -> bool:
	for part: String in lesson.split("+"):
		if not MODES.has(part):
			return false
	return true


## The translation keys of `lesson`'s label, name and rule.
static func label_key(lesson: String) -> String:
	return MODES[lesson][0]


static func name_key(lesson: String) -> String:
	return MODES[lesson][1]


static func rule_key(lesson: String) -> String:
	return MODES[lesson][2]


## The short label on the level map (translated); a combination joins its
## modes' labels: "Tutum + Kilid" (chapter plan section 4.4).
static func label(lesson: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for part: String in lesson.split("+"):
		parts.append(Languages.text(label_key(part)))
	return " + ".join(parts)


## The mode's name (translated), the first line of the rule panel; a
## combination is named by its map label, "Tutum + Kilid" (two full names do
## not fit one line).
static func name_of(level: Level) -> String:
	if level.is_combo():
		return label(level.lesson())
	return Languages.text(name_key(level.lesson()))


## The mode's rule for `level` (translated), under its name in the rule panel;
## a combination gives both rules, one after the other (up to 3 lines). The
## balance names its level's tolerance.
static func rule_of(level: Level) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for part: String in level.lesson().split("+"):
		var text: String = Languages.text(rule_key(part))
		if part == BalanceRule.ID:
			for rule: RuleBase in level.get_rule_set().active_rules:
				if rule is BalanceRule:
					text = text % (rule as BalanceRule).tolerance
		parts.append(text)
	return " ".join(parts)
