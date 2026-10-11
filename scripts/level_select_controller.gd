extends Control
## Level map (level structure addendum v3): one winding road of numbered
## levels, no difficulty tabs, with the chest meter on top (economy formulas
## v3). Completed levels can be replayed to improve their stars. Once the island (the side branch) is open, its marker on the
## road and the button under the title switch between the road and the island.

signal level_chosen(track: String, position: int)

## Progress to show; taken from the App autoload when left empty.
var save_system: SaveSystem
## Chest meter source; the App's, or one over save_system when that was injected.
var economy: EconomySystem
var track: String = LevelCatalog.MAIN

## Stop to scroll to once the scroll container knows the map's height.
var _scroll_target: int = 0

@onready var _map: PathMap = %Map
@onready var _scroll: ScrollContainer = %Scroll
@onready var _title: Label = %Title
@onready var _stars_label: Label = %StarsLabel
@onready var _track_button: Button = %TrackButton
@onready var _back_button: Button = %BackButton
@onready var _chest_meter: ChestMeter = %ChestMeter


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
	_chest_meter.economy = economy
	_back_button.pressed.connect(func() -> void:
		if app != null:
			app.show_main_menu())
	_map.level_pressed.connect(_on_level_pressed)
	_map.island_pressed.connect(show_track.bind(LevelCatalog.BRANCH, 0))
	_track_button.pressed.connect(func() -> void:
		show_track(LevelCatalog.MAIN if track == LevelCatalog.BRANCH else LevelCatalog.BRANCH))
	_scroll.get_v_scroll_bar().changed.connect(_apply_scroll)
	_map.resized.connect(_apply_scroll)
	var start_track: String = app.map_track if app != null else LevelCatalog.MAIN
	if start_track == LevelCatalog.BRANCH and not LevelCatalog.is_branch_open(save_system):
		start_track = LevelCatalog.MAIN
	show_track(start_track, app.map_focus if app != null else 0)


## Shows the road (MAIN) or the island (BRANCH), scrolled to stop `focus`
## (0: the next level to play there).
func show_track(p_track: String, focus: int = 0) -> void:
	track = p_track
	var app: Node = get_node_or_null("/root/App")
	if app != null:
		app.map_track = track
	_scroll.scroll_vertical = 0
	_map.setup(track, save_system)
	# The map's height changed: sort again once its new minimum size is known, so
	# the scroll range never keeps the old track's length.
	_scroll.queue_sort.call_deferred()
	_title.text = tr("MAP_ISLAND") if track == LevelCatalog.BRANCH else tr("MENU_LEVELS")
	_stars_label.text = tr("SELECT_STARS") % save_system.get_total_stars()
	_track_button.visible = LevelCatalog.is_branch_open(save_system)
	_track_button.text = tr("MAP_TO_MAIN") if track == LevelCatalog.BRANCH else tr("MAP_TO_ISLAND")
	if focus < 1 or focus > _map.shown_count():
		focus = _map.current_position() if _map.current_position() > 0 else _map.shown_count()
	_scroll_target = focus
	_apply_scroll()


func get_map() -> PathMap:
	return _map


## Stop `position` of the shown track (1-based), or null if not shown.
func get_cell(position: int) -> LevelCell:
	return _map.get_cell(position)


## Centres the target stop once the map has its final height.
func _apply_scroll() -> void:
	if _scroll_target < 1 or _map.size.y < _map.custom_minimum_size.y:
		return
	var center: float = _map.stop_center(_scroll_target).y
	_scroll.scroll_vertical = int(center - _scroll.size.y * 0.5)


func _on_level_pressed(p_track: String, position: int) -> void:
	_scroll_target = 0
	level_chosen.emit(p_track, position)
	var app: Node = get_node_or_null("/root/App")
	if app != null:
		app.play_level(p_track, position)
