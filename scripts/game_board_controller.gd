class_name GameBoard
extends Control
## Game board screen (spec 5.3): pegs, disks, goal preview, move counter,
## coins, hint and undo. Tap a peg to pick up its top disk, tap another peg to
## move it there. Hints and the tutorial draw on the shared coaching overlay.

signal level_completed(level: Level, moves: int, seconds: float)
## A level was opened or restarted (emitted before position_changed).
signal level_started
## The position changed (move, undo, restart or a new level).
signal position_changed
## Pegs and disks were placed again (new position or new screen size).
signal layout_changed
## A disk was picked up (peg index) or put back (-1).
signal selection_changed(peg_index: int)
## A move was refused by the rules; `message` is the broken rule's text.
signal illegal_move(move: Move, message: String)

const PEG_SCENE: PackedScene = preload("res://scenes/components/peg.tscn")
const DISK_SCENE: PackedScene = preload("res://scenes/components/disk.tscn")
const POPUP_SCENE: PackedScene = preload("res://scenes/level_complete_popup.tscn")
const COACHING_SCENE: PackedScene = preload("res://scenes/components/coaching/coaching_layer.tscn")
const MAX_DISK_HEIGHT: float = 52.0

## Level loaded in _ready() unless the App autoload asks for another one.
@export_file("*.json") var level_path: String = "res://data/levels/easy/easy_001.json"
## Where results are recorded; taken from the App autoload when left empty.
var save_system: SaveSystem
## Pays for hints and undos; taken from the App autoload when left empty.
var economy: EconomySystem
## Off-path hints are searched on a worker thread so the screen never freezes
## (an Expert search can take a few seconds on a phone). Tests turn it off.
var background_hints: bool = true
## Coaching on the first two levels (tests of other features turn it off).
var tutorials_enabled: bool = true
## Fade through ScreenTransition when "next level" swaps the board (tests turn it off).
var animate_transitions: bool = true
## Restricted input (addendum 2.2): when >= 0, only this peg reacts to taps and
## the hint, undo and restart buttons are off.
var restricted_peg: int = -1:
	set(value):
		restricted_peg = value
		_update_buttons()

var session: GameSession
## Result of the last completion: { stars, improved, reward }.
var last_result: Dictionary = {}
var coaching: CoachingLayer
var hints: HintController
var tutorial: TutorialDirector

var _popup: LevelCompletePopup
## Short notice in the status line (e.g. not enough coins), cleared by the next action.
var _message: String = ""
var _peg_views: Array[PegView] = []
## Disk size -> view.
var _disk_views: Dictionary[int, DiskView] = {}
## Disk size -> where the disk is (or is gliding to), in board coordinates.
var _disk_targets: Dictionary[int, Rect2] = {}
## Peg index -> peg area (rod, base and the space for a lifted disk), board coordinates.
var _peg_areas: Array[Rect2] = []

@onready var _level_label: Label = %LevelLabel
@onready var _moves_label: Label = %MovesLabel
## Count-up stopwatch (economy/UX addendum, section 2). Not the same thing as a
## level's time_limit_seconds countdown, which would get its own label.
@onready var _time_label: Label = %TimeLabel
@onready var _min_label: Label = %MinLabel
@onready var _status_label: Label = %StatusLabel
@onready var _goal_preview: BoardPreview = %GoalPreview
@onready var _board: Control = %Board
@onready var _peg_layer: Control = %PegLayer
@onready var _disk_layer: Control = %DiskLayer
@onready var _restart_button: Button = %RestartButton
@onready var _back_button: Button = %BackButton
@onready var _coin_label: Label = %CoinLabel
@onready var _hint_button: Button = %HintButton
@onready var _undo_button: Button = %UndoButton


func _ready() -> void:
	var app: Node = get_node_or_null("/root/App")
	if save_system == null:
		save_system = app.save if app != null else SaveSystem.new()
	if economy == null:
		if app != null and app.save == save_system:
			economy = app.economy
		else:
			economy = EconomySystem.new()
			economy.setup(save_system)
			add_child(economy)
	economy.coins_changed.connect(func(_coins: int) -> void: _update_buttons())
	economy.allowances_changed.connect(_update_buttons)
	coaching = COACHING_SCENE.instantiate()
	add_child(coaching)
	hints = HintController.new()
	hints.name = "HintController"
	hints.background = background_hints
	hints.setup(self, coaching, economy)
	hints.message_changed.connect(show_message)
	add_child(hints)
	tutorial = TutorialDirector.new()
	tutorial.name = "TutorialDirector"
	tutorial.enabled = tutorials_enabled
	tutorial.setup(self, coaching, save_system)
	add_child(tutorial)
	_hint_button.pressed.connect(request_hint)
	_undo_button.pressed.connect(request_undo)
	_restart_button.pressed.connect(restart)
	_back_button.pressed.connect(_show_level_select)
	_board.resized.connect(_layout.bind(false))
	_popup = POPUP_SCENE.instantiate()
	_popup.visible = false
	_popup.next_requested.connect(play_next_level)
	_popup.replay_requested.connect(restart)
	_popup.levels_requested.connect(_show_level_select)
	add_child(_popup)
	var pending: Dictionary = app.take_pending_level() if app != null else {}
	if not pending.is_empty():
		var level: Level = LevelCatalog.load_level(pending["tier"], pending["index"])
		if level != null:
			start_level(level)
			return
	if not level_path.is_empty():
		load_level_file(level_path)


func _process(delta: float) -> void:
	if session != null:
		session.add_time(delta)
		_update_clock()


func _update_clock() -> void:
	var text: String = GameSession.format_clock(session.elapsed_seconds)
	if _time_label.text != text:
		_time_label.text = text


func load_level_file(path: String) -> bool:
	var errors: Array[String] = []
	var level: Level = Level.load_file(path, errors)
	if level == null:
		_status_label.text = tr("BOARD_LOAD_FAILED")
		push_error("Cannot load level %s: %s" % [path, "; ".join(errors)])
		return false
	level_path = path
	start_level(level)
	return true


func start_level(level: Level) -> void:
	session = GameSession.new(level)
	last_result = {}
	_message = ""
	_popup.visible = false
	_build_views()
	_goal_preview.position_state = level.goal
	_level_label.text = "%s · %d" % [Difficulty.display_name(level.difficulty), Difficulty.index_of_id(level.id)]
	_min_label.text = tr("BOARD_MINIMUM") % level.min_moves
	_refresh(false)
	level_started.emit()
	position_changed.emit()


func restart() -> void:
	if session == null:
		return
	session.restart()
	last_result = {}
	_message = ""
	_popup.visible = false
	_refresh(true)
	level_started.emit()
	position_changed.emit()


## Spec 4.7 hint, shown by the HintController on the coaching overlay.
func request_hint() -> void:
	if session != null and not session.is_solved():
		hints.request()


## Takes back the last move. The first EconomySystem.FREE_UNDOS_PER_DAY undos
## of a day are free (over all levels), later ones cost EconomySystem.UNDO_COST.
func request_undo() -> void:
	if session == null or not session.can_undo():
		return
	if not economy.pay_for_undo():
		show_message(tr("BOARD_UNDO_NO_COINS"))
		return
	session.undo()
	_message = ""
	_refresh(true)
	position_changed.emit()


## Opens the level after the current one (next tier after the last level).
func play_next_level() -> void:
	var next: Dictionary = _next_level()
	if next.is_empty():
		return
	var level: Level = LevelCatalog.load_level(next["tier"], next["index"])
	if level == null:
		return
	var app: Node = get_node_or_null("/root/App")
	if app != null:
		app.selected_tier = next["tier"]
	var transition: Node = get_node_or_null("/root/ScreenTransition")
	if animate_transitions and transition != null:
		transition.run(start_level.bind(level))
	else:
		start_level(level)


func get_popup() -> LevelCompletePopup:
	return _popup


## Shows a short notice in the status line until the next action.
func show_message(text: String) -> void:
	_message = text
	if session != null:
		_refresh(false)


## Where disk `disk_size` is drawn (or is gliding to), in viewport coordinates.
func get_disk_rect(disk_size: int) -> Rect2:
	var rect: Rect2 = _disk_targets.get(disk_size, Rect2())
	return Rect2(rect.position + _board.global_position, rect.size)


## The area of peg `peg_index`: its rod and base plus the room above it where a
## picked-up disk hovers, in viewport coordinates.
func get_peg_rect(peg_index: int) -> Rect2:
	if peg_index < 0 or peg_index >= _peg_areas.size():
		return Rect2()
	var rect: Rect2 = _peg_areas[peg_index]
	return Rect2(rect.position + _board.global_position, rect.size)


## The Hint button, in viewport coordinates.
func get_hint_button_rect() -> Rect2:
	return _hint_button.get_global_rect()


## Handles a tap on peg `peg_index` (also the entry point for tests).
func on_peg_pressed(peg_index: int) -> void:
	if session == null or (restricted_peg >= 0 and peg_index != restricted_peg):
		return
	var selected_before: int = session.selected_peg
	var target_move: Move = Move.new(session.selected_peg, peg_index)
	var result: GameSession.TapResult = session.tap_peg(peg_index)
	if result != GameSession.TapResult.IGNORED:
		_message = ""
	_refresh(true)
	match result:
		GameSession.TapResult.ILLEGAL:
			_peg_views[peg_index].flash_invalid()
			illegal_move.emit(target_move, tr(session.rules.get_violation_message(session.state, target_move)))
		GameSession.TapResult.MOVED:
			position_changed.emit()
			if session.is_solved():
				_on_solved()
	if session.selected_peg != selected_before:
		selection_changed.emit(session.selected_peg)


func _next_level() -> Dictionary:
	var level: Level = session.level
	return LevelCatalog.next_after(level.difficulty, Difficulty.index_of_id(level.id))


func _show_level_select() -> void:
	var app: Node = get_node_or_null("/root/App")
	if app != null:
		app.show_level_select(session.level.difficulty if session != null else "")


## Spec 4.6/4.9: stars from the move count, saved right away, coins for the
## improvement over the best result so far (addendum 8.1), then the popup.
func _on_solved() -> void:
	var level: Level = session.level
	var stars: int = level.stars_for_moves(session.move_count)
	var previous_stars: int = save_system.get_stars(level.id)
	var improved: bool = save_system.record_completion(level.id, stars, session.move_count, session.elapsed_seconds)
	var reward: int = EconomySystem.level_reward(stars, previous_stars)
	economy.earn(reward, "level_complete")
	last_result = {"stars": stars, "improved": improved, "reward": reward}
	_popup.show_result(stars, session.move_count, level.min_moves, session.elapsed_seconds,
			improved, not _next_level().is_empty(), reward)
	level_completed.emit(level, session.move_count, session.elapsed_seconds)


func _update_buttons() -> void:
	if session == null or not is_node_ready():
		return
	var locked: bool = restricted_peg >= 0
	# The coin icon next to it says what the number is.
	_coin_label.text = str(economy.coins)
	_hint_button.disabled = locked or session.is_solved() or hints.is_pending()
	if economy.has_unlimited_hints():
		_hint_button.text = tr("BOARD_HINT_UNLIMITED")
	else:
		_hint_button.text = tr("BOARD_HINT") % economy.hint_cost(session.level.difficulty)
	_undo_button.disabled = locked or not session.can_undo()
	_restart_button.disabled = locked
	var free_left: int = economy.free_undos_left()
	if free_left > 0:
		_undo_button.text = tr("BOARD_UNDO_FREE") % free_left
	else:
		_undo_button.text = tr("BOARD_UNDO_PAID") % EconomySystem.UNDO_COST


func _build_views() -> void:
	for layer: Control in [_peg_layer, _disk_layer]:
		for child: Node in layer.get_children():
			layer.remove_child(child)
			child.queue_free()
	_peg_views.clear()
	_disk_views.clear()
	_disk_targets.clear()
	_peg_areas.clear()
	var disk_count: int = session.state.get_disk_count()
	for peg_index: int in session.state.get_peg_count():
		var peg: PegView = PEG_SCENE.instantiate()
		peg.peg_index = peg_index
		peg.pressed.connect(on_peg_pressed)
		_peg_layer.add_child(peg)
		_peg_views.append(peg)
	for peg: Array in session.state.pegs:
		for disk_size: int in peg:
			var disk: DiskView = DISK_SCENE.instantiate()
			disk.disk_size = disk_size
			disk.color = ThemeManager.disk_color(disk_size, disk_count)
			_disk_layer.add_child(disk)
			_disk_views[disk_size] = disk


func _refresh(animated: bool) -> void:
	_moves_label.text = tr("BOARD_MOVES") % session.move_count
	_update_clock()
	if session.is_solved():
		_status_label.text = tr("BOARD_SOLVED") % [session.move_count, session.level.min_moves]
		_status_label.theme_type_variation = &"SuccessLabel"
	else:
		_status_label.text = _message
		_status_label.theme_type_variation = &"DangerLabel"
	for peg: PegView in _peg_views:
		peg.highlighted = peg.peg_index == session.selected_peg
	_update_buttons()
	_layout(animated)


## Places pegs and disks for the current board size and position.
func _layout(animated: bool) -> void:
	if session == null or _peg_views.is_empty():
		return
	var peg_count: int = session.state.get_peg_count()
	var disk_count: int = maxi(session.state.get_disk_count(), 1)
	var column: float = _board.size.x / peg_count
	# Room for every disk on one peg plus the lifted disk above the rod.
	var disk_height: float = minf(_board.size.y / (disk_count + 3.5), MAX_DISK_HEIGHT)
	var base_height: float = maxf(disk_height * 0.4, 10.0)
	var base_top: float = _board.size.y - base_height
	var rod_top: float = base_top - disk_height * (disk_count + 0.6)
	var lifted_y: float = rod_top - disk_height * 1.5
	_peg_areas.clear()
	for peg: PegView in _peg_views:
		peg.position = Vector2(column * peg.peg_index, 0.0)
		peg.size = Vector2(column, _board.size.y)
		peg.configure(base_top, base_height, rod_top, maxf(column * 0.05, 6.0), column * 0.96)
		_peg_areas.append(Rect2(column * peg.peg_index + column * 0.02, lifted_y,
				column * 0.96, base_top + base_height - lifted_y))
	var selected_disk: int = session.get_selected_disk()
	for peg_index: int in peg_count:
		var peg: Array = session.state.pegs[peg_index]
		for level_index: int in peg.size():
			var disk_size: int = peg[level_index]
			var view: DiskView = _disk_views[disk_size]
			var width: float = BoardLayout.disk_width(disk_size, disk_count, column)
			var y: float = base_top - disk_height * (level_index + 1)
			if disk_size == selected_disk:
				y = lifted_y
			view.selected = disk_size == selected_disk
			view.size = Vector2(width, disk_height - 4.0)
			var target: Vector2 = Vector2(column * (peg_index + 0.5) - width * 0.5, y + 2.0)
			_disk_targets[disk_size] = Rect2(target, view.size)
			view.move_to(target, animated)
	layout_changed.emit()
