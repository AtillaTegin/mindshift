extends Control
## Game board screen (spec 5.3): pegs, disks, goal preview, move counter,
## coins, hint and undo. Tap a peg to pick up its top disk, tap another peg to
## move it there.

signal level_completed(level: Level, moves: int, seconds: float)

const PEG_SCENE: PackedScene = preload("res://scenes/components/peg.tscn")
const DISK_SCENE: PackedScene = preload("res://scenes/components/disk.tscn")
const POPUP_SCENE: PackedScene = preload("res://scenes/level_complete_popup.tscn")
const MOVE_SECONDS: float = 0.12
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

var session: GameSession
## Result of the last completion: { stars, improved, reward }.
var last_result: Dictionary = {}
## The move the current hint points at, or null.
var hint_move: Move

var _popup: LevelCompletePopup
## Position the shown hint belongs to; asking again there costs nothing.
var _hint_key: String = ""
## Short notice in the status line (e.g. not enough coins), cleared by the next action.
var _message: String = ""
var _hint_thread: Thread
## Position the running background search belongs to.
var _pending_hint_key: String = ""

var _peg_views: Array[PegView] = []
## Disk size -> view.
var _disk_views: Dictionary[int, DiskView] = {}
var _disk_tweens: Dictionary[int, Tween] = {}

@onready var _level_label: Label = %LevelLabel
@onready var _moves_label: Label = %MovesLabel
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
	if _hint_thread != null and not _hint_thread.is_alive():
		var move: Move = _hint_thread.wait_to_finish()
		_hint_thread = null
		var key: String = _pending_hint_key
		_pending_hint_key = ""
		# Only show it if the player has not moved on meanwhile (then it is free).
		if session != null and not session.is_solved() and session.state.hash_key() == key:
			_apply_hint(move, key)
		else:
			_message = ""
			_refresh(false)


func _exit_tree() -> void:
	if _hint_thread != null:
		_hint_thread.wait_to_finish()
		_hint_thread = null


func is_hint_pending() -> bool:
	return _hint_thread != null


func load_level_file(path: String) -> bool:
	var errors: Array[String] = []
	var level: Level = Level.load_file(path, errors)
	if level == null:
		_status_label.text = "Səviyyə yüklənmədi"
		push_error("Cannot load level %s: %s" % [path, "; ".join(errors)])
		return false
	level_path = path
	start_level(level)
	return true


func start_level(level: Level) -> void:
	session = GameSession.new(level)
	last_result = {}
	_clear_hint()
	_message = ""
	_popup.visible = false
	_build_views()
	_goal_preview.position_state = level.goal
	_level_label.text = "%s · %d" % [Difficulty.display_name(level.difficulty), Difficulty.index_of_id(level.id)]
	_min_label.text = "Minimum: %d" % level.min_moves
	_refresh(false)


func restart() -> void:
	if session == null:
		return
	session.restart()
	last_result = {}
	_clear_hint()
	_message = ""
	_popup.visible = false
	_refresh(true)


## Spec 4.7: marks the disk to move next and its target peg; never moves it.
## Costs EconomySystem.HINT_COST, except when asking again in the same position.
func request_hint() -> void:
	if session == null or session.is_solved() or is_hint_pending():
		return
	session.selected_peg = -1
	var key: String = session.state.hash_key()
	if hint_move != null and key == _hint_key:
		_refresh(false)
		return
	if not economy.can_afford(EconomySystem.HINT_COST):
		_message = "Hint üçün coin çatmır"
		_refresh(false)
		return
	var on_path: Move = session.get_path_hint()
	if on_path != null:
		_apply_hint(on_path, key)
		return
	var from_state: PuzzleState = session.state.duplicate_state()
	var goal: PuzzleState = session.level.goal
	var rules: RuleSet = session.rules
	if not background_hints:
		_apply_hint(GameSession.solve_hint(from_state, goal, rules), key)
		return
	_pending_hint_key = key
	_hint_thread = Thread.new()
	_hint_thread.start(func() -> Move: return GameSession.solve_hint(from_state, goal, rules))
	_message = "Hint hesablanır..."
	_refresh(false)


## Shows a found hint and charges for it; a missing hint costs nothing.
func _apply_hint(move: Move, key: String) -> void:
	if move == null:
		_message = "Hint tapılmadı"
		_refresh(false)
		return
	economy.spend(EconomySystem.HINT_COST)
	hint_move = move
	_hint_key = key
	_message = ""
	_refresh(false)


## Takes back the last move. The first FREE_UNDOS_PER_ATTEMPT undos are free,
## later ones cost EconomySystem.UNDO_COST.
func request_undo() -> void:
	if session == null or not session.can_undo():
		return
	var cost: int = EconomySystem.undo_cost(session.undo_count)
	if not economy.spend(cost):
		_message = "Geri qaytarmaq üçün coin çatmır"
		_refresh(false)
		return
	session.undo()
	_clear_hint()
	_message = ""
	_refresh(true)


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
	start_level(level)


func get_popup() -> LevelCompletePopup:
	return _popup


func _next_level() -> Dictionary:
	var level: Level = session.level
	return LevelCatalog.next_after(level.difficulty, Difficulty.index_of_id(level.id))


func _show_level_select() -> void:
	var app: Node = get_node_or_null("/root/App")
	if app != null:
		app.show_level_select(session.level.difficulty if session != null else "")


## Spec 4.6/4.9: stars from the move count, saved right away, coins for newly
## earned stars (spec 4.8), then the popup.
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
	if session == null:
		return
	_coin_label.text = "Coin: %d" % economy.coins
	_hint_button.disabled = session.is_solved() or is_hint_pending()
	_hint_button.text = "Hint · %d coin" % EconomySystem.HINT_COST
	_undo_button.disabled = not session.can_undo()
	var free_left: int = EconomySystem.FREE_UNDOS_PER_ATTEMPT - session.undo_count
	if free_left > 0:
		_undo_button.text = "Geri (pulsuz: %d)" % free_left
	else:
		_undo_button.text = "Geri · %d coin" % EconomySystem.UNDO_COST


func _clear_hint() -> void:
	hint_move = null
	_hint_key = ""


## Handles a tap on peg `peg_index` (also the entry point for tests).
func on_peg_pressed(peg_index: int) -> void:
	if session == null:
		return
	var result: GameSession.TapResult = session.tap_peg(peg_index)
	if result == GameSession.TapResult.ILLEGAL:
		_peg_views[peg_index].flash_invalid()
	if result != GameSession.TapResult.IGNORED:
		_message = ""
	if result == GameSession.TapResult.MOVED:
		_clear_hint()
	_refresh(true)
	if result == GameSession.TapResult.MOVED and session.is_solved():
		_on_solved()


func _build_views() -> void:
	for layer: Control in [_peg_layer, _disk_layer]:
		for child: Node in layer.get_children():
			layer.remove_child(child)
			child.queue_free()
	_peg_views.clear()
	_disk_views.clear()
	_disk_tweens.clear()
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
			disk.color = UIPalette.disk_color(disk_size, disk_count)
			_disk_layer.add_child(disk)
			_disk_views[disk_size] = disk


func _refresh(animated: bool) -> void:
	_moves_label.text = "Gediş: %d" % session.move_count
	if session.is_solved():
		_status_label.text = "Həll olundu! %d gedişdə (minimum %d)" % [session.move_count, session.level.min_moves]
		_status_label.add_theme_color_override("font_color", UIPalette.SUCCESS)
	else:
		_status_label.text = _message
		_status_label.add_theme_color_override("font_color", UIPalette.ERROR)
	var hint_disk: int = session.state.get_top_disk(hint_move.from_peg) if hint_move != null else -1
	for peg: PegView in _peg_views:
		peg.highlighted = peg.peg_index == session.selected_peg
		peg.hint_target = hint_move != null and peg.peg_index == hint_move.to_peg
	for disk_size: int in _disk_views:
		_disk_views[disk_size].hinted = disk_size == hint_disk
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
	for peg: PegView in _peg_views:
		peg.position = Vector2(column * peg.peg_index, 0.0)
		peg.size = Vector2(column, _board.size.y)
		peg.configure(base_top, base_height, rod_top, maxf(column * 0.05, 6.0), column * 0.96)
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
			_place_disk(disk_size, Vector2(column * (peg_index + 0.5) - width * 0.5, y + 2.0), animated)


func _place_disk(disk_size: int, target: Vector2, animated: bool) -> void:
	var view: DiskView = _disk_views[disk_size]
	if _disk_tweens.has(disk_size):
		_disk_tweens[disk_size].kill()
		_disk_tweens.erase(disk_size)
	if not animated or view.position.distance_to(target) < 0.5:
		view.position = target
		return
	var tween: Tween = create_tween()
	tween.tween_property(view, "position", target, MOVE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_disk_tweens[disk_size] = tween
