extends Control
## Game board screen (spec 5.3): pegs, disks, goal preview and move counter.
## Tap a peg to pick up its top disk, tap another peg to move it there.

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

var session: GameSession
## Result of the last completion: { stars, improved }.
var last_result: Dictionary = {}

var _popup: LevelCompletePopup

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


func _ready() -> void:
	var app: Node = get_node_or_null("/root/App")
	if save_system == null:
		save_system = app.save if app != null else SaveSystem.new()
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
	_popup.visible = false
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


## Spec 4.6/4.9: stars from the move count, saved right away, then the popup.
func _on_solved() -> void:
	var level: Level = session.level
	var stars: int = level.stars_for_moves(session.move_count)
	var improved: bool = save_system.record_completion(level.id, stars, session.move_count, session.elapsed_seconds)
	last_result = {"stars": stars, "improved": improved}
	_popup.show_result(stars, session.move_count, level.min_moves, session.elapsed_seconds,
			improved, not _next_level().is_empty())
	level_completed.emit(level, session.move_count, session.elapsed_seconds)


## Handles a tap on peg `peg_index` (also the entry point for tests).
func on_peg_pressed(peg_index: int) -> void:
	if session == null:
		return
	var result: GameSession.TapResult = session.tap_peg(peg_index)
	if result == GameSession.TapResult.ILLEGAL:
		_peg_views[peg_index].flash_invalid()
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
		_status_label.text = ""
	for peg: PegView in _peg_views:
		peg.highlighted = peg.peg_index == session.selected_peg
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
