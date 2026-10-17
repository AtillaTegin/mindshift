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
	# ICRA World 5-9, section 6.
	"king": ["MODE_KING_LABEL", "MODE_KING_NAME", "MODE_KING_RULE"],
	"river": ["MODE_RIVER_LABEL", "MODE_RIVER_NAME", "MODE_RIVER_RULE"],
}


## Sub-elements of the modes (chapter waves v1): Level.variants entry ->
## [name key, rule key]; the rule continues the name ("Şüşə disk — qutu bağlı
## olsa da görünür."). The rule panel adds them under the mode's rule, and each
## one's first level introduces it with them (INTRO_VARIANT).
const VARIANTS: Dictionary = {
	"narrow": ["VARIANT_NARROW_NAME", "VARIANT_NARROW_RULE"],
	"arch": ["VARIANT_ARCH_NAME", "VARIANT_ARCH_RULE"],
	"holed": ["VARIANT_HOLED_NAME", "VARIANT_HOLED_RULE"],
	"full_hidden": ["VARIANT_FULL_HIDDEN_NAME", "VARIANT_FULL_HIDDEN_RULE"],
	"glass": ["VARIANT_GLASS_NAME", "VARIANT_GLASS_RULE"],
	"empty_box": ["VARIANT_EMPTY_BOX_NAME", "VARIANT_EMPTY_BOX_RULE"],
	"sealed": ["VARIANT_SEALED_NAME", "VARIANT_SEALED_RULE"],
	"reclosing": ["VARIANT_RECLOSING_NAME", "VARIANT_RECLOSING_RULE"],
	"key_disk": ["VARIANT_KEY_DISK_NAME", "VARIANT_KEY_DISK_RULE"],
	"middle_lock": ["VARIANT_MIDDLE_LOCK_NAME", "VARIANT_MIDDLE_LOCK_RULE"],
	"chain_lock": ["VARIANT_CHAIN_LOCK_NAME", "VARIANT_CHAIN_LOCK_RULE"],
	# World 3-4 (MindShift_Dunya3-4_Alt_Elementler_v1.md).
	"oasis": ["VARIANT_OASIS_NAME", "VARIANT_OASIS_RULE"],
	"tunnel": ["VARIANT_TUNNEL_NAME", "VARIANT_TUNNEL_RULE"],
	"bridge": ["VARIANT_BRIDGE_NAME", "VARIANT_BRIDGE_RULE"],
	"one_way": ["VARIANT_ONE_WAY_NAME", "VARIANT_ONE_WAY_RULE"],
	"jump": ["VARIANT_JUMP_NAME", "VARIANT_JUMP_RULE"],
	"neutral": ["VARIANT_NEUTRAL_NAME", "VARIANT_NEUTRAL_RULE"],
	"colored_base": ["VARIANT_COLORED_BASE_NAME", "VARIANT_COLORED_BASE_RULE"],
	"paint": ["VARIANT_PAINT_NAME", "VARIANT_PAINT_RULE"],
	"inverse": ["VARIANT_INVERSE_NAME", "VARIANT_INVERSE_RULE"],
	"back_peg": ["VARIANT_BACK_PEG_NAME", "VARIANT_BACK_PEG_RULE"],
	"shortcut": ["VARIANT_SHORTCUT_NAME", "VARIANT_SHORTCUT_RULE"],
	"center": ["VARIANT_CENTER_NAME", "VARIANT_CENTER_RULE"],
	"eight": ["VARIANT_EIGHT_NAME", "VARIANT_EIGHT_RULE"],
	"broken_ring": ["VARIANT_BROKEN_RING_NAME", "VARIANT_BROKEN_RING_RULE"],
	"reset_peg": ["VARIANT_RESET_PEG_NAME", "VARIANT_RESET_PEG_RULE"],
	"new_leader": ["VARIANT_NEW_LEADER_NAME", "VARIANT_NEW_LEADER_RULE"],
	"waiting_ring": ["VARIANT_WAITING_RING_NAME", "VARIANT_WAITING_RING_RULE"],
	"stone": ["VARIANT_STONE_NAME", "VARIANT_STONE_RULE"],
	"long_arm": ["VARIANT_LONG_ARM_NAME", "VARIANT_LONG_ARM_RULE"],
	"three_scales": ["VARIANT_THREE_SCALES_NAME", "VARIANT_THREE_SCALES_RULE"],
	"own_limits": ["VARIANT_OWN_LIMITS_NAME", "VARIANT_OWN_LIMITS_RULE"],
	"moving_stone": ["VARIANT_MOVING_STONE_NAME", "VARIANT_MOVING_STONE_RULE"],
	# World 5 (ICRA World 5-9, sections 3.1-3.3 and 4).
	"odd_even": ["VARIANT_ODD_EVEN_NAME", "VARIANT_ODD_EVEN_RULE"],
	"vizier": ["VARIANT_VIZIER_NAME", "VARIANT_VIZIER_RULE"],
	"narrow_gate": ["VARIANT_NARROW_GATE_NAME", "VARIANT_NARROW_GATE_RULE"],
	"siege": ["VARIANT_SIEGE_NAME", "VARIANT_SIEGE_RULE"],
	"stone_bridge": ["VARIANT_STONE_BRIDGE_NAME", "VARIANT_STONE_BRIDGE_RULE"],
	"ferry": ["VARIANT_FERRY_NAME", "VARIANT_FERRY_RULE"],
	"two_crossings": ["VARIANT_TWO_CROSSINGS_NAME", "VARIANT_TWO_CROSSINGS_RULE"],
	"reverse": ["VARIANT_REVERSE_NAME", "VARIANT_REVERSE_RULE"],
	"bonfire": ["VARIANT_BONFIRE_NAME", "VARIANT_BONFIRE_RULE"],
	"mid_start": ["VARIANT_MID_START_NAME", "VARIANT_MID_START_RULE"],
	"mixed": ["VARIANT_MIXED_NAME", "VARIANT_MIXED_RULE"],
	"caravanserai": ["VARIANT_CARAVANSERAI_NAME", "VARIANT_CARAVANSERAI_RULE"],
	"three_caravans": ["VARIANT_THREE_CARAVANS_NAME", "VARIANT_THREE_CARAVANS_RULE"],
	"goal_king": ["VARIANT_GOAL_KING_NAME", "VARIANT_GOAL_KING_RULE"],
	"goal_odd_even": ["VARIANT_GOAL_ODD_EVEN_NAME", "VARIANT_GOAL_ODD_EVEN_RULE"],
}
## Sub-elements that are a lesson of their own (Level.lesson(): the exchange's
## mixed kind): the mode's name says them, so the rule panel leaves them out.
const OWN_LESSON: Array[String] = ["mixed"]


## The name of sub-element `variant` (translated).
static func variant_name(variant: String) -> String:
	return Languages.text(VARIANTS[variant][0])


## The rule of sub-element `variant` (translated).
static func variant_rule(variant: String) -> String:
	return Languages.text(VARIANTS[variant][1])


## "Şüşə disk — qutu bağlı olsa da görünür."
static func variant_line(variant: String) -> String:
	return "%s — %s" % [variant_name(variant), variant_rule(variant)]


## The rule panel's line for `level`'s sub-elements, one sentence each, in
## order; "" for a base-form level.
static func variants_of(level: Level) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for variant: String in level.variants:
		if not OWN_LESSON.has(variant):
			parts.append(variant_line(variant))
	return " ".join(parts)


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
