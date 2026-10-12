extends Control
## Board of the colour-order prototype: target pattern, move budget, three
## pegs and the result panel. It reuses the game's PegView (tap input, red
## flash), DiskView (glide, lift, shadow), BoardLayout widths, buttons and
## theme, but runs on its own SortSession: the Hanoi engine is not touched.

const PEG_SCENE: PackedScene = preload("res://scenes/components/peg.tscn")
const DISK_SCENE: PackedScene = preload("res://prototype/sort_pattern/sort_disk.tscn")
const MENU_SCENE: String = "res://prototype/sort_pattern/sort_menu.tscn"
const MAX_DISK_HEIGHT: float = 64.0
## Strip under the pegs for the target peg's label.
const FLOOR_ROOM: float = 44.0
## Remaining moves at or below this show in the danger colour.
const LOW_MOVES: int = 3

## Seconds between the last move and the result panel (lets the disk land);
## tests set 0 to see it at once.
var result_delay: float = 0.4
var puzzle: SortPuzzle
var session: SortSession

var _peg_views: Array[PegView] = []
var _disk_views: Dictionary[int, SortDiskView] = {}
## Size -> 1-based rank among the level's distinct sizes (disk width).
var _size_rank: Dictionary[int, int] = {}
var _load_error: String = ""

@onready var _board: Control = %Board
@onready var _peg_layer: Control = %PegLayer
@onready var _disk_layer: Control = %DiskLayer
@onready var _target_mark: Label = %TargetMark
@onready var _moves_left: Label = %MovesLeftLabel
@onready var _limit_label: Label = %LimitLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _pattern: SortPatternView = %PatternView
@onready var _status: Label = %StatusLabel
@onready var _result_layer: Control = %ResultLayer
@onready var _result_title: Label = %ResultTitle
@onready var _result_text: Label = %ResultText


func _ready() -> void:
	%TitleLabel.text = SortTexts.text("BOARD_TITLE")
	%MenuButton.text = SortTexts.text("BOARD_MENU")
	%RestartButton.text = SortTexts.text("BOARD_RESTART")
	%GoalTitle.text = SortTexts.text("BOARD_GOAL_TITLE")
	%GoalHint.text = SortTexts.text("BOARD_GOAL_HINT")
	%RetryButton.text = SortTexts.text("RESULT_RETRY")
	%ResultMenuButton.text = SortTexts.text("RESULT_TO_MENU")
	_target_mark.text = SortTexts.text("BOARD_TARGET_MARK")
	%MenuButton.pressed.connect(show_menu)
	%RestartButton.pressed.connect(restart)
	%RetryButton.pressed.connect(restart)
	%ResultMenuButton.pressed.connect(show_menu)
	_board.resized.connect(_layout.bind(false))
	_result_layer.visible = false
	var errors: Array[String] = []
	puzzle = SortPuzzle.load_file(SortPuzzle.LEVEL_PATH, errors)
	if puzzle != null:
		errors.append_array(SortSolver.validate(puzzle))
	if not errors.is_empty():
		_load_error = "; ".join(errors)
		_show_message(SortTexts.text("LOAD_ERROR") % _load_error, &"DangerLabel")
		push_error("Sort prototype: %s" % _load_error)
		return
	session = SortSession.new(puzzle, SortSession.limit_override)
	_build_views()
	_refresh(false)


func get_disk_view(disk_id: int) -> SortDiskView:
	return _disk_views.get(disk_id)


func get_peg_view(peg_index: int) -> PegView:
	return _peg_views[peg_index]


func is_result_visible() -> bool:
	return _result_layer.visible


func get_result_title() -> String:
	return _result_title.text


func get_status_text() -> String:
	return _status.text


func get_moves_left_text() -> String:
	return _moves_left.text


## A tap on peg `peg_index` (also the entry point for tests).
func on_peg_pressed(peg_index: int) -> void:
	if session == null:
		return
	var matched_before: int = session.matched_count()
	var result: SortSession.TapResult = session.tap_peg(peg_index)
	match result:
		SortSession.TapResult.ILLEGAL:
			_peg_views[peg_index].flash_invalid()
			_show_message(SortTexts.text("BOARD_ILLEGAL"), &"DangerLabel")
		SortSession.TapResult.MOVED:
			_after_move(matched_before)
		SortSession.TapResult.SELECTED, SortSession.TapResult.DESELECTED:
			_show_message("", &"")
	_refresh(true)


## Back to the start position with the full move budget.
func restart() -> void:
	if session == null:
		return
	session.restart()
	_result_layer.visible = false
	_show_message("", &"")
	_refresh(true)


func show_menu() -> void:
	var transition: Node = get_node_or_null("/root/ScreenTransition")
	if transition != null:
		transition.change_scene(MENU_SCENE)
	else:
		get_tree().change_scene_to_file(MENU_SCENE)


func _after_move(matched_before: int) -> void:
	var matched: int = session.matched_count()
	var on_target: int = session.pegs[puzzle.target_peg].size()
	if matched > matched_before:
		_show_message(SortTexts.text("BOARD_PROGRESS_UP") % [matched, puzzle.disk_count()], &"SuccessLabel")
	elif on_target > matched and session.status == SortSession.Status.PLAYING:
		_show_message(SortTexts.text("BOARD_WRONG_PLACE"), &"SecondaryLabel")
	elif session.remaining() == 1 and session.status == SortSession.Status.PLAYING:
		_show_message(SortTexts.text("BOARD_LAST_MOVE"), &"DangerLabel")
	else:
		_show_message("", &"")
	if session.status != SortSession.Status.PLAYING:
		if result_delay > 0.0:
			get_tree().create_timer(result_delay).timeout.connect(_show_result)
		else:
			_show_result()


func _show_result() -> void:
	if session.status == SortSession.Status.PLAYING:
		return
	var won: bool = session.status == SortSession.Status.WON
	_result_title.text = SortTexts.text("RESULT_WIN_TITLE" if won else "RESULT_LOSE_TITLE")
	_result_title.theme_type_variation = &"SuccessLabel" if won else &"DangerLabel"
	if won:
		_result_text.text = SortTexts.text("RESULT_WIN_TEXT") % [session.moves_made, session.move_limit, puzzle.min_moves]
	else:
		_result_text.text = SortTexts.text("RESULT_LOSE_TEXT") % [session.matched_count(), puzzle.disk_count()]
	_result_layer.visible = true
	var card: Control = %ResultCard
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_message(text: String, variation: StringName) -> void:
	_status.text = text
	_status.theme_type_variation = variation


func _build_views() -> void:
	var sizes: Array[int] = []
	for disk_size: int in puzzle.sizes:
		if not sizes.has(disk_size):
			sizes.append(disk_size)
	sizes.sort()
	for i: int in sizes.size():
		_size_rank[sizes[i]] = i + 1
	for peg_index: int in puzzle.peg_count():
		var peg: PegView = PEG_SCENE.instantiate()
		peg.peg_index = peg_index
		peg.pressed.connect(on_peg_pressed)
		_peg_layer.add_child(peg)
		_peg_views.append(peg)
	for disk_id: int in puzzle.disk_count():
		var disk: SortDiskView = DISK_SCENE.instantiate()
		disk.disk_id = disk_id
		disk.disk_size = puzzle.sizes[disk_id]
		disk.color_name = puzzle.colors[disk_id]
		_disk_layer.add_child(disk)
		_disk_views[disk_id] = disk
	# The target holds every disk, largest at the bottom, so each slot's size is known.
	var slot_sizes: Array[int] = puzzle.sizes.duplicate()
	slot_sizes.sort()
	slot_sizes.reverse()
	var shares: Array[float] = []
	for disk_size: int in slot_sizes:
		shares.append(BoardLayout.disk_width(_size_rank[disk_size], sizes.size(), 1.0))
	_pattern.setup(puzzle.target_colors, shares)


func _refresh(animated: bool) -> void:
	var remaining: int = session.remaining()
	_moves_left.text = SortTexts.text("BOARD_MOVES_LEFT") % remaining
	_moves_left.theme_type_variation = &"DangerLabel" if remaining <= LOW_MOVES else &""
	_limit_label.text = SortTexts.text("BOARD_LIMIT") % session.move_limit
	var matched: int = session.matched_count()
	_progress_label.text = SortTexts.text("BOARD_PROGRESS") % [matched, puzzle.disk_count()]
	_progress_label.theme_type_variation = &"SuccessLabel" if matched > 0 else &"SecondaryLabel"
	_pattern.set_progress(matched, session.pegs[puzzle.target_peg].size())
	var target: Array = session.pegs[puzzle.target_peg]
	for disk_id: int in _disk_views:
		var index: int = target.find(disk_id)
		_disk_views[disk_id].matched = index != -1 and index < matched
	for peg: PegView in _peg_views:
		peg.highlighted = peg.peg_index == session.selected_peg
	_layout(animated)


## Places pegs and disks for the current board size and position.
func _layout(animated: bool) -> void:
	if session == null or _peg_views.is_empty():
		return
	var peg_count: int = session.pegs.size()
	var disk_count: int = puzzle.disk_count()
	var column: float = _board.size.x / peg_count
	var height: float = _board.size.y - FLOOR_ROOM
	var disk_height: float = minf(height / (disk_count + 3.5), MAX_DISK_HEIGHT)
	var base_height: float = maxf(disk_height * 0.4, 10.0)
	var base_top: float = height - base_height
	var rod_top: float = base_top - disk_height * (disk_count + 0.6)
	var lifted_y: float = rod_top - disk_height * 1.5
	for peg: PegView in _peg_views:
		peg.position = Vector2(column * peg.peg_index, 0.0)
		peg.size = Vector2(column, _board.size.y)
		peg.configure(base_top, base_height, rod_top, maxf(column * 0.05, 6.0), column * 0.96)
	_target_mark.position = Vector2(column * puzzle.target_peg, height + 4.0)
	_target_mark.size = Vector2(column, FLOOR_ROOM - 4.0)
	_pattern.custom_minimum_size.x = column
	var selected_disk: int = session.selected_disk()
	for peg_index: int in peg_count:
		var peg: Array = session.pegs[peg_index]
		for level_index: int in peg.size():
			var disk_id: int = peg[level_index]
			var view: SortDiskView = _disk_views[disk_id]
			var width: float = BoardLayout.disk_width(_size_rank[puzzle.sizes[disk_id]], _size_rank.size(), column)
			var y: float = lifted_y if disk_id == selected_disk else base_top - disk_height * (level_index + 1)
			view.selected = disk_id == selected_disk
			view.size = Vector2(width, disk_height - 4.0)
			view.move_to(Vector2(column * (peg_index + 0.5) - width * 0.5, y + 2.0), animated)
