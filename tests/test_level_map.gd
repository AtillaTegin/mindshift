extends "res://tests/test_case.gd"
## The level map (level structure addendum v3): one winding road of numbered
## stops, no tier tabs or labels, the island branch as a surprise, and boards
## that follow the road.

const SAVE_PATH: String = "res://.test_saves/test_level_map_save.json"
const SELECT_SCENE: PackedScene = preload("res://scenes/level_select.tscn")
const BOARD_SCENE: PackedScene = preload("res://scenes/game_board.tscn")
const MAIN: String = LevelCatalog.MAIN
const BRANCH: String = LevelCatalog.BRANCH

var _nodes: Array[Node] = []
var _save: SaveSystem


func before_each() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_save = SaveSystem.new(SAVE_PATH)


func after_each() -> void:
	for node: Node in _nodes:
		node.get_parent().remove_child(node)
		node.free()
	_nodes.clear()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _add(node: Node) -> Node:
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	_nodes.append(node)
	return node


func _map_screen() -> Control:
	var screen: Control = SELECT_SCENE.instantiate()
	screen.save_system = _save
	return _add(screen)


func _complete(track: String, last_position: int, stars: int = 2) -> void:
	for position: int in range(1, last_position + 1):
		_save.record_completion(LevelCatalog.level_id_at(track, position), stars, 99, 5.0)


func _board() -> GameBoard:
	var board: GameBoard = BOARD_SCENE.instantiate()
	board.save_system = _save
	board.tutorials_enabled = false
	board.background_hints = false
	board.animate_transitions = false
	return _add(board)


func _solve(board: GameBoard) -> void:
	# Karakuri boxes open with a first tap of their own.
	for peg_index: int in board.session.level.covered_pegs:
		board.on_peg_pressed(peg_index)
	for move: Move in board.session.level.solution_path:
		board.on_peg_pressed(move.from_peg)
		board.on_peg_pressed(move.to_peg)


## Every text the screen shows, as the player reads it.
func _texts(root: Node) -> Array[String]:
	var texts: Array[String] = []
	for node: Node in root.find_children("*", "", true, false):
		if node is Label and (node as Label).is_visible_in_tree():
			texts.append(root.tr((node as Label).text))
		elif node is Button and (node as Button).is_visible_in_tree():
			texts.append(root.tr((node as Button).text))
	return texts


func test_fresh_map_shows_the_first_stop_and_a_few_locked_ones() -> void:
	var screen: Control = _map_screen()
	var map: PathMap = screen.get_map()
	assert_eq(map.shown_count(), 1 + PathMap.LOCKED_AHEAD)
	assert_eq(map.current_position(), 1)
	assert_true(screen.get_cell(1).current)
	assert_eq(screen.get_cell(1).theme_type_variation, &"MapStopCurrent")
	assert_false(screen.get_cell(1).disabled)
	for position: int in range(2, map.shown_count() + 1):
		assert_true(screen.get_cell(position).locked, "stop %d locked" % position)
		assert_true(screen.get_cell(position).disabled)
	assert_null(map.get_island_button(), "no island yet, not even a hint of it")
	assert_false((screen.get_node("%TrackButton") as Button).visible)
	assert_eq((screen.get_node("%Title") as Label).text, "Səviyyələr")


func test_no_tabs_and_no_tier_names() -> void:
	_complete(MAIN, 60)
	var screen: Control = _map_screen()
	assert_null(screen.find_child("Tabs", true, false))
	assert_null(screen.find_child("TierInfo", true, false))
	for text: String in _texts(screen):
		for word: String in ["Asan", "Orta", "Çətin", "Ekspert", "Bonus"]:
			assert_false(text.contains(word), "\"%s\" names a category" % text)


func test_map_shows_progress_and_lets_old_levels_be_replayed() -> void:
	_complete(MAIN, 12, 1)
	_save.record_completion(LevelCatalog.level_id_at(MAIN, 5), 3, 5, 5.0)
	var screen: Control = _map_screen()
	var map: PathMap = screen.get_map()
	assert_eq(map.shown_count(), 13 + PathMap.LOCKED_AHEAD, "12 done, the next one, then locked stops")
	assert_eq(map.current_position(), 13)
	assert_eq(screen.get_cell(5).stars, 3)
	assert_eq(screen.get_cell(6).stars, 1)
	assert_false(screen.get_cell(13).locked)
	assert_true(screen.get_cell(14).locked)
	assert_true(screen.get_cell(13).current)
	assert_false(screen.get_cell(6).current)
	var chosen: Array = []
	screen.level_chosen.connect(func(track: String, position: int) -> void: chosen.append([track, position]))
	if screen.get_node_or_null("/root/App") == null:
		screen.get_cell(6).pressed.emit()
		assert_eq(chosen, [[MAIN, 6]], "a 1-star level can be replayed for more stars")


func test_stops_are_laid_out_along_a_winding_road() -> void:
	_complete(MAIN, 20)
	var map: PathMap = _map_screen().get_map()
	map.size = Vector2(672, map.custom_minimum_size.y)
	var first: Vector2 = map.stop_center(1)
	var second: Vector2 = map.stop_center(2)
	assert_true(second.y < first.y, "the road climbs from level 1 at the bottom")
	assert_true(absf(first.y - second.y - PathMap.STEP) < 0.01, "one STEP apart")
	var xs: Array[float] = []
	for position: int in range(1, 9):
		xs.append(map.stop_center(position).x)
	assert_true(xs.max() - xs.min() > 200.0, "it swings left and right: %s" % str(xs))
	for position: int in range(1, map.shown_count() + 1):
		var cell: LevelCell = map.get_cell(position)
		assert_true(cell.position.x >= 0.0 and cell.position.x + cell.size.x <= map.size.x, "stop %d inside the map" % position)


func test_mechanic_stops_wear_their_dress() -> void:
	var mechanic_position: int = 0
	for position: int in range(1, LevelCatalog.track_length(MAIN) + 1):
		if LevelCatalog.mechanic_at(MAIN, position) != Level.CLASSIC:
			mechanic_position = position
			break
	_complete(MAIN, mechanic_position)
	var screen: Control = _map_screen()
	var expected: String = ThemeManager.skin_for(LevelCatalog.mechanic_at(MAIN, mechanic_position))
	assert_true(expected in ["jade", "wood"], expected)
	assert_eq(screen.get_cell(mechanic_position).skin, expected)
	assert_eq(screen.get_cell(1).skin, "", "classic levels wear none")
	assert_false(screen.get_cell(mechanic_position).locked, "a mechanic level opens like any other")


func test_island_appears_after_its_level_and_switches_tracks() -> void:
	_complete(MAIN, LevelCatalog.branch_after())
	var screen: Control = _map_screen()
	var map: PathMap = screen.get_map()
	var island: Button = map.get_island_button()
	assert_not_null(island, "the island marker sits on the road")
	var track_button: Button = screen.get_node("%TrackButton")
	assert_true(track_button.visible)
	assert_eq(track_button.text, "Gizli adaya keç")
	island.pressed.emit()
	assert_eq(screen.track, BRANCH)
	assert_eq((screen.get_node("%Title") as Label).text, "Gizli ada")
	assert_eq(map.current_position(), 1)
	assert_true(screen.get_cell(2).locked)
	assert_null(map.get_island_button(), "no marker on the island itself")
	assert_eq(track_button.text, "Əsas yola qayıt")
	track_button.pressed.emit()
	assert_eq(screen.track, MAIN)
	assert_eq(map.current_position(), LevelCatalog.branch_after() + 1)


func test_board_follows_the_road() -> void:
	var board: GameBoard = _board()
	board.start_level(LevelCatalog.load_at(MAIN, 3))
	assert_eq((board.get_node("%LevelLabel") as Label).text, "Səviyyə 3")
	_solve(board)
	var next_button: Button = board.get_popup().get_node("%NextButton")
	assert_false(next_button.disabled)
	board.play_next_level()
	assert_eq(board.session.level.id, LevelCatalog.level_id_at(MAIN, 4))
	assert_eq((board.get_node("%LevelLabel") as Label).text, "Səviyyə 4")
	board.start_level(LevelCatalog.load_at(BRANCH, 2))
	assert_eq((board.get_node("%LevelLabel") as Label).text, "Ada · 2")


func test_last_road_level_has_no_next() -> void:
	var board: GameBoard = _board()
	board.start_level(LevelCatalog.load_at(MAIN, LevelCatalog.track_length(MAIN)))
	_solve(board)
	var next_button: Button = board.get_popup().get_node("%NextButton")
	assert_true(next_button.disabled)
	assert_eq(next_button.text, "Son səviyyə")


func test_popup_announces_the_island_once() -> void:
	var after: int = LevelCatalog.branch_after()
	_complete(MAIN, after - 1)
	var board: GameBoard = _board()
	board.start_level(LevelCatalog.load_at(MAIN, after))
	_solve(board)
	assert_eq(board.get_popup().get_note(), "Gizli ada açıldı! Səviyyələr xəritəsində onu tap.")
	board.restart()
	_solve(board)
	assert_eq(board.get_popup().get_note(), "", "only the first time")
	board.start_level(LevelCatalog.load_at(MAIN, 1))
	_solve(board)
	assert_eq(board.get_popup().get_note(), "")


func test_mechanic_boards_wear_their_dress_and_classic_ones_do_not() -> void:
	var board: GameBoard = _board()
	board.start_level(LevelCatalog.load_mechanic("frozen_01.json"))
	assert_eq(board.get_board_skin().skin, "jade")
	assert_eq(board.get_node("%GoalPreview").skin, "jade")
	board.start_level(LevelCatalog.load_mechanic("fog_01.json"))
	assert_eq(board.get_board_skin().skin, "wood")
	board.start_level(LevelCatalog.load_at(MAIN, 1))
	assert_eq(board.get_board_skin().skin, "")
	assert_eq(board.get_node("%GoalPreview").skin, "")


func test_mechanic_levels_reward_and_save_like_any_level() -> void:
	var board: GameBoard = _board()
	board.start_level(LevelCatalog.load_mechanic("fog_02.json"))
	assert_eq(board.session.level.difficulty, "medium", "its own tier")
	_solve(board)
	assert_eq(board.last_result["stars"], 3)
	assert_eq(board.last_result["tokens"], 3, "chest tokens like any level")
	assert_eq(_save.get_stars(board.session.level.id), 3)
	var place: Dictionary = LevelCatalog.place_of(board.session.level.id)
	assert_eq(place["track"], MAIN, "on the road, not in a side corner")
	assert_false((board.get_popup().get_node("%NextButton") as Button).disabled, "and it has a next level")


func test_map_shows_the_chest_meter() -> void:
	_save.chest_tokens = 7
	_save.chest_keys = 1
	var screen: Control = _map_screen()
	var meter: ChestMeter = screen.get_node("%ChestMeter")
	assert_true(meter.is_visible_in_tree())
	assert_eq(meter.get_text(), "7/15 jeton")
	assert_eq(meter.economy.keys(), 1)
	meter.economy.add_tokens(8)
	assert_eq(meter.get_text(), "0/15 jeton", "follows the economy")
	assert_eq(meter.economy.keys(), 2)
