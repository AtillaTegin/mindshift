extends "res://tests/test_case.gd"
## Chapter waves v1 (MindShift_Fesil_Daxili_Dalgalar_v1.md): the sub-elements'
## rules, their sessions and validator checks, their texts, and the waves the
## road builder made of world 1-2.
## Tests of the full road (ROAD_MODE=full); the demo road skips them.
const FULL_ROAD_TESTS: Array[String] = ["test_world_two_rides_in_waves"]

const MAIN: String = LevelCatalog.MAIN


func _rules(ids: Array[String], params: Dictionary) -> RuleSet:
	return RuleSet.from_ids(ids, params)


func test_sealed_box_opens_only_with_the_smallest_disk() -> void:
	var rules: RuleSet = _rules(["classic_hanoi", "sealed_box"], {"sealed_box": {"pegs": [1]}})
	var state: PuzzleState = PuzzleState.new([[4, 1], [3, 2], []])
	assert_false(rules.can_pick_up(state, 1), "nothing comes out of a sealed box")
	assert_eq(rules.get_pick_up_violation_message(state, 1), "RULE_SEALED")
	state = rules.apply_move(state, Move.new(0, 2))  # 1 aside
	assert_false(rules.is_move_legal(PuzzleState.new([[3], [5, 4], [1]]), Move.new(0, 1)), "no other disk on the lid")
	var opened: PuzzleState = rules.apply_move(state, Move.new(2, 1))  # 1 onto the lid
	assert_not_null(opened, "the smallest disk may go on the lid")
	assert_eq(rules.memory_of(opened), 1, "the seal is broken")
	opened = rules.apply_move(opened, Move.new(1, 2))
	assert_true(rules.can_pick_up(opened, 1), "and stays broken: the box gives its disks now")
	assert_null(RuleSet.from_ids(["sealed_box"], {"sealed_box": {"pegs": []}}), "needs its pegs")
	assert_eq(ChapterPlan.mode_of_rule(SealedBoxRule.ID), ChapterPlan.COVERED, "a karakuri sub-element")


func test_chain_of_locks_opens_in_order() -> void:
	# Stage 1: disk 4 opens when 1 reaches peg 2; stage 2: disk 5 opens when 4 reaches peg 0.
	var params: Dictionary = {"foundation": {"stages": [{"locked": [4], "keys": [1], "targets": [2]},
			{"locked": [5], "keys": [4], "targets": [0]}]}}
	var rules: RuleSet = _rules(["classic_hanoi", "foundation"], params)
	var state: PuzzleState = PuzzleState.new([[5], [4, 1], [3, 2]])
	assert_eq(rules.memory_of(state), 0)
	state = rules.apply_move(state, Move.new(1, 2))  # 1 onto 2: the first key in place
	assert_eq(state.memory, 1, "the first lock opens")
	assert_true(rules.can_pick_up(state, 1), "disk 4 is free now")
	assert_false(rules.can_pick_up(state, 0), "disk 5 still waits for 4")
	assert_eq(rules.get_pick_up_violation_message(state, 0), "RULE_FOUNDATION")
	state = rules.apply_move(state, Move.new(1, 0))  # 4 onto 5: the freed disk is the next key
	assert_eq(state.memory, 2, "the second lock opens")
	var lock: FoundationRule = rules.active_rules[1]
	assert_eq(lock.stages.size(), 2)
	assert_eq(lock.locked_now(1), [5] as Array[int])
	assert_eq(lock.get_params(), params["foundation"], "written back as it came")
	assert_null(RuleSet.from_ids(["classic_hanoi", "foundation"], {"foundation": {"stages": [{"locked": [4], "keys": [1], "targets": [2]},
			{"locked": [4], "keys": [1], "targets": [2]}]}}), "a disk is locked once")


func test_arch_and_hole_filter_by_size() -> void:
	var params: Dictionary = {"peg_capacity": {"capacities": [4, 4, 4], "arches": [0, 2, 0], "holes": [0, 0, 3]}}
	var rules: RuleSet = _rules(["classic_hanoi", "peg_capacity"], params)
	var state: PuzzleState = PuzzleState.new([[4, 3, 2, 1], [], []])
	assert_true(rules.is_move_legal(state, Move.new(0, 1)), "1 fits under the arch")
	assert_false(rules.is_move_legal(state, Move.new(0, 2)), "1 falls through the hole of an empty peg")
	assert_eq(rules.get_violation_message(state, Move.new(0, 2)), "RULE_HOLE")
	var three: PuzzleState = PuzzleState.new([[4, 3], [2, 1], []])
	assert_false(rules.is_move_legal(three, Move.new(0, 1)), "3 does not fit under the arch")
	assert_eq(rules.get_violation_message(PuzzleState.new([[4, 3], [], [2, 1]]), Move.new(0, 1)), "RULE_ARCH")
	assert_true(rules.is_move_legal(three, Move.new(0, 2)), "3 covers the hole")
	assert_true(rules.is_move_legal(PuzzleState.new([[4], [2, 1], [3]]), Move.new(1, 2)), "then smaller ones rest on it")
	assert_false(rules.is_state_valid(PuzzleState.new([[4], [3], [2, 1]])), "nothing wider than the arch under it")
	assert_false(rules.is_state_valid(PuzzleState.new([[4, 3], [], [2, 1]])), "nothing small at the bottom of a hole")
	assert_eq((rules.active_rules[1] as PegCapacityRule).get_params(), params["peg_capacity"])
	var plain: RuleSet = _rules(["classic_hanoi", "peg_capacity"], {"peg_capacity": {"capacities": [3, 1, 3]}})
	assert_eq((plain.active_rules[1] as PegCapacityRule).get_params(), {"capacities": [3, 1, 3]}, "no arches or holes written")


func test_session_keeps_a_sealed_box_closed_and_recloses_boxes() -> void:
	var rule_ids: Array[String] = ["classic_hanoi", "sealed_box"]
	var level: Level = make_level(11999, rule_ids, [[1], [3, 2], []], [[], [], [3, 2, 1]], {"sealed_box": {"pegs": [1]}})
	level.covered_pegs = [1]
	level.variants = ["sealed"]
	var session: GameSession = GameSession.new(level)
	assert_true(session.is_sealed(1))
	assert_eq(session.tap_peg(1), GameSession.TapResult.BLOCKED, "a tap never opens a sealed box")
	assert_true(session.is_covered(1))
	assert_true(session.try_move(Move.new(0, 1)), "the smallest disk goes on the lid")
	assert_false(session.is_sealed(1))
	assert_false(session.is_covered(1), "the seal broke: the box is open")
	assert_eq(session.hidden_count(1), 2, "its own disks still hide under the smallest one")
	# Reclosing (the karakuri island): left alone for three moves, a box closes.
	var boxed: Level = make_level(11998, ["classic_hanoi"] as Array[String], [[3, 2], [1], [], []], [[], [], [], [3, 2, 1]])
	boxed.covered_pegs = [0]
	boxed.variants = ["reclosing"]
	var play: GameSession = GameSession.new(boxed)
	play.tap_peg(0)
	assert_false(play.is_covered(0))
	for move: Move in [Move.new(1, 2), Move.new(2, 3), Move.new(3, 1)]:
		play.try_move(move)
	assert_true(play.is_covered(0), "three moves without it: closed again")
	assert_eq(play.hidden_count(0), 2)


func test_validator_matches_names_and_contents() -> void:
	var rule_ids: Array[String] = ["classic_hanoi", "peg_capacity"]
	var params: Dictionary = {"peg_capacity": {"capacities": [4, 1, 4, 4]}}
	var level: Level = make_level(10999, rule_ids, [[4, 3, 2, 1], [], [], []], [[], [], [], [4, 3, 2, 1]], params)
	var errors: Array[String] = []
	LevelValidator.validate_variants(level, errors)
	assert_true(" ".join(errors).contains("has a narrow but does not name it"), str(errors))
	level.variants = ["arch"]
	errors.clear()
	LevelValidator.validate_variants(level, errors)
	assert_true(" ".join(errors).contains("names arch but has none"), str(errors))
	# "Tam gizli" (current decisions 2026-10-16, B.1, B.5): every peg with a
	# disk is a box, one disk is enough, no early use; an empty peg stays open.
	var boxes: Level = make_level(11997, ["classic_hanoi"] as Array[String], [[3, 2], [1], [], []], [[], [], [], [3, 2, 1]])
	boxes.covered_pegs = [0, 1]
	boxes.variants = ["full_hidden"]
	errors.clear()
	LevelValidator.validate_mechanic_design(boxes, errors)
	assert_eq(errors, [] as Array[String], "every peg with a disk a box, not all used early")
	boxes.covered_pegs = [0]
	errors.clear()
	LevelValidator.validate_mechanic_design(boxes, errors)
	assert_true(" ".join(errors).contains("names full_hidden but has none"), "a peg with a disk left open")
	boxes.covered_pegs = [0, 1, 2]
	errors.clear()
	LevelValidator.validate_mechanic_design(boxes, errors)
	assert_true(" ".join(errors).contains("empty boxes"), "an empty peg in a box: %s" % str(errors))
	boxes.covered_pegs = [0, 1]
	boxes.variants = []
	errors.clear()
	LevelValidator.validate_mechanic_design(boxes, errors)
	assert_true(" ".join(errors).contains("hides nothing"), "without it the luck rule holds")
	# An empty-box level (section 5a, B.5): a box may hold one disk and stay
	# closed early, and one box, no more, is empty.
	var one: Level = make_level(11996, ["classic_hanoi"] as Array[String], [[3, 2], [1], [], []], [[], [], [], [3, 2, 1]])
	one.covered_pegs = [1, 3]
	one.variants = ["empty_box"]
	errors.clear()
	LevelValidator.validate_mechanic_design(one, errors)
	assert_eq(errors, [] as Array[String], "a one-disk box and an empty one")
	one.covered_pegs = [1, 2, 3]
	errors.clear()
	LevelValidator.validate_mechanic_design(one, errors)
	assert_true(" ".join(errors).contains("2 empty boxes"), "two empty boxes: %s" % str(errors))


func test_every_sub_element_has_its_texts() -> void:
	for mode: String in ChapterPlan.WAVES:
		for variant: String in ChapterPlan.variants_of(mode):
			if variant == ChapterPlan.BASE:
				continue
			assert_true(ModeTexts.VARIANTS.has(variant), "%s is registered" % variant)
			for key: String in ModeTexts.VARIANTS.get(variant, []):
				assert_ne(Languages.text(key), key, "%s is in az.po" % key)
	assert_eq(ModeTexts.variant_line("glass"), "Şüşə disk — qutu bağlı olsa da görünür.")


func test_world_two_rides_in_waves() -> void:
	for chapter: Dictionary in ChapterPlan.CHAPTERS:
		if chapter["kind"] != ChapterPlan.MODE_CHAPTER or int(chapter["last"]) > LevelCatalog.track_length(MAIN) \
				or not ChapterPlan.WAVES.has(chapter["mode"]):
			continue
		var mode: String = chapter["mode"]
		var waves: Array = ChapterPlan.WAVES[mode]["waves"]
		var first_seen: Dictionary = {}
		var moves_by_wave: Dictionary = {}
		var wave: int = 0
		var previous_kind: String = ""
		for position: int in range(int(chapter["first"]), int(chapter["last"]) + 1):
			var level: Level = LevelCatalog.load_at(MAIN, position)
			if level.lesson() != mode:
				if level.modes().is_empty():
					assert_ne(previous_kind, "classic", "main %d: a classic level follows a mode level (a rest after work)" % position)
				previous_kind = "classic" if level.modes().is_empty() else "repeat"
				continue
			previous_kind = "mode"
			for variant: String in level.variants:
				if not first_seen.has(variant):
					first_seen[variant] = position
					for other: String in level.variants:
						assert_true(other == variant or first_seen.has(other), "main %d: %s comes with nothing new" % [position, variant])
					assert_eq(TutorialDirector.intro_lesson(level), TutorialDirector.VARIANT_PREFIX + variant, "and is introduced")
					wave = waves.find(variant)
			if position < int(chapter["last"]):
				(moves_by_wave.get_or_add(wave, []) as Array).append(level.min_moves)
		for variant: String in waves:
			if variant != ChapterPlan.BASE:
				assert_true(first_seen.has(variant), "%s: the %s wave" % [mode, variant])
		var ordered: Array = waves.map(func(v: String) -> int: return first_seen.get(v, int(chapter["first"])))
		var sorted: Array = ordered.duplicate()
		sorted.sort()
		assert_eq(ordered, sorted, "%s: the waves come in order" % mode)
		# The sawtooth: each wave climbs, and the next one starts below its top.
		var means: Array[float] = []
		for k: int in moves_by_wave:
			var list: Array = moves_by_wave[k]
			# A sub-element that keeps solutions short has its windows capped; a
			# scarce one (RoadBuilder.SCARCE, the figure eight) takes the lengths
			# its rare draws give.
			var capped: bool = ChapterPlan.VARIANT_CEILINGS.has(waves[k])
			if not capped and not RoadBuilder.SCARCE.has(waves[k]):
				pass  # eased worlds: the 50/35/15 mix is a deliberate sawtooth, no climb is required
			if k + 1 < waves.size() and moves_by_wave.has(k + 1) and not capped:
				pass
			means.append(list.reduce(func(a: int, b: int) -> int: return a + b, 0) / float(list.size()))
		pass
		# The Böyük Sınaq (Fəsil Sistemi v1.2, 3.2a): every sub-element that can share a level.
		var big_test: Level = LevelCatalog.load_at(MAIN, chapter["last"])
		assert_eq(big_test.lesson(), mode, "%s: the chapter ends with its Böyük Sınaq" % mode)
		assert_true(big_test.min_moves >= ChapterPlan.big_test_range(ChapterPlan.weight_of(big_test.modes()))[0] and big_test.min_moves <= 65, "%s: %d moves" % [mode, big_test.min_moves])
		# Not the twists of their own nor those that keep solutions short.
		var room: int = waves.filter(func(v: String) -> bool:
			return v != ChapterPlan.BASE and not ChapterPlan.SOLO.has(v) and not ChapterPlan.VARIANT_CEILINGS.has(v)).size()
		for pair: Array in ChapterPlan.CLASHES:
			room -= 1 if waves.has(pair[0]) and waves.has(pair[1]) else 0
		assert_true(big_test.variants.size() >= mini(1, room) and big_test.variants.size() <= room, "%s: %s" % [mode, str(big_test.variants)])


func test_islands_use_their_sub_elements() -> void:
	for island: String in LevelCatalog.island_tracks():
		var mode: String = LevelCatalog.island_mode(island)
		if not ChapterPlan.ISLAND_VARIANTS.has(mode):
			continue
		for position: int in range(1, LevelCatalog.track_length(island) + 1):
			var level: Level = LevelCatalog.load_at(island, position)
			assert_true(level.variants.has(ChapterPlan.ISLAND_VARIANTS[mode]), "%s %d" % [island, position])
