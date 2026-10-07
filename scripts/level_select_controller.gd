extends Control
## Level select (spec 5.2): one tab per difficulty, a grid of levels with the
## stars earned, locked levels greyed out.

signal level_chosen(tier: String, index: int)

## Tabs of tiers that are still locked are drawn faded (still tappable, so the
## player can read what opens them).
const LOCKED_TAB_ALPHA: float = 0.55

## Progress to show; taken from the App autoload when left empty.
var save_system: SaveSystem
var current_tier: String = ""

var _tab_buttons: Dictionary[String, Button] = {}

@onready var _tabs: HBoxContainer = %Tabs
@onready var _grid: GridContainer = %Grid
@onready var _tier_info: Label = %TierInfo
@onready var _stars_label: Label = %StarsLabel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	var app: Node = get_node_or_null("/root/App")
	if save_system == null:
		save_system = app.save if app != null else SaveSystem.new()
	_back_button.pressed.connect(func() -> void:
		if app != null:
			app.show_main_menu())
	var group: ButtonGroup = ButtonGroup.new()
	for tier: String in Difficulty.ORDER:
		var button: Button = PolishedButton.new()
		button.text = Difficulty.display_name(tier)
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 72)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 26)
		if not LevelCatalog.is_tier_unlocked(tier, save_system):
			button.modulate.a = LOCKED_TAB_ALPHA
		button.pressed.connect(show_tier.bind(tier))
		_tabs.add_child(button)
		_tab_buttons[tier] = button
	show_tier(app.selected_tier if app != null else Difficulty.ORDER[0])


func show_tier(tier: String) -> void:
	current_tier = tier
	_tab_buttons[tier].set_pressed_no_signal(true)
	var app: Node = get_node_or_null("/root/App")
	if app != null:
		app.selected_tier = tier
	_tier_info.text = tier_info_text(tier, save_system)
	_stars_label.text = tr("SELECT_STARS") % save_system.get_total_stars()
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for index: int in range(1, LevelCatalog.level_count(tier) + 1):
		var cell: LevelCell = LevelCell.new()
		cell.custom_minimum_size = Vector2(0, 124)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_font_size_override("font_size", 34)
		cell.setup(index, save_system.get_stars(Difficulty.id_for(tier, index)),
				not LevelCatalog.is_unlocked(tier, index, save_system))
		cell.pressed.connect(_on_cell_pressed.bind(index))
		_grid.add_child(cell)


## Cell of the `index`-th level of the current tab (1-based).
func get_cell(index: int) -> LevelCell:
	return _grid.get_child(index - 1) as LevelCell


## The line under the tabs: the tier's size, or for a locked tier what opens it.
static func tier_info_text(tier: String, save: SaveSystem) -> String:
	if not LevelCatalog.is_tier_unlocked(tier, save):
		var needed: int = Difficulty.unlock_requirement(tier)
		return Languages.text("SELECT_TIER_LOCKED") % [
				Difficulty.display_name(Difficulty.previous_tier(tier)), needed,
				LevelCatalog.completed_toward_unlock(tier, save), needed]
	var settings: Dictionary = Difficulty.get_tier(tier)
	return Languages.text("SELECT_TIER_INFO") % [Difficulty.describe_moves(tier),
			_range_text(settings["min_pegs"], settings["max_pegs"]),
			_range_text(settings["min_disks"], settings["max_disks"])]


static func _range_text(low: int, high: int) -> String:
	return str(low) if low == high else "%d-%d" % [low, high]


func _on_cell_pressed(index: int) -> void:
	level_chosen.emit(current_tier, index)
	var app: Node = get_node_or_null("/root/App")
	if app != null:
		app.play_level(current_tier, index)
