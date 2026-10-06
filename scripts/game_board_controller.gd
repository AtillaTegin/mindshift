extends Control
## Game board screen (spec 5.3): pegs, disks, goal preview and move counter.
## Tap a peg to pick up its top disk, tap another peg to move it there.

signal level_completed(level: Level, moves: int, seconds: float)

const PEG_SCENE: PackedScene = preload("res://scenes/components/peg.tscn")
const DISK_SCENE: PackedScene = preload("res://scenes/components/disk.tscn")
const MOVE_SECONDS: float = 0.12
const MAX_DISK_HEIGHT: float = 52.0

## Level loaded in _ready(); empty to wait for start_level().
@export_file("*.json") var level_path: String = "res://data/levels/easy/easy_001.json"

var session: GameSession

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


func _ready() -> void:
	_restart_button.pressed.connect(restart)
	_board.resized.connect(_layout.bind(false))
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
	_build_views()
	_goal_preview.position_state = level.goal
	var tier: Dictionary = Difficulty.get_tier(level.difficulty)
	_level_label.text = "%s · %d" % [level.difficulty.capitalize(), level.id - int(tier.get("first_id", 1)) + 1]
	_min_label.text = "Minimum: %d" % level.min_moves
	_refresh(false)


func restart() -> void:
	if session == null:
		return
	session.restart()
	_refresh(true)


## Handles a tap on peg `peg_index` (also the entry point for tests).
func on_peg_pressed(peg_index: int) -> void:
	if session == null:
		return
	var result: GameSession.TapResult = session.tap_peg(peg_index)
	if result == GameSession.TapResult.ILLEGAL:
		_peg_views[peg_index].flash_invalid()
	_refresh(true)
	if result == GameSession.TapResult.MOVED and session.is_solved():
		level_completed.emit(session.level, session.move_count, session.elapsed_seconds)


func _build_views() -> void:
	for child: Node in _peg_layer.get_children():
		child.queue_free()
	for child: Node in _disk_layer.get_children():
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
