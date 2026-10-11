extends Node
## Autoload "App": owns the player's save and switches between screens.
## Pass `-- --save-path=user://other.json` to use another save file (tests).

const MAIN_MENU: String = "res://scenes/main_menu.tscn"
const LEVEL_SELECT: String = "res://scenes/level_select.tscn"
const GAME_BOARD: String = "res://scenes/game_board.tscn"
const SHOP: String = "res://scenes/shop.tscn"
const SCRIPT_RUN_SAVE_PATH: String = "user://script_run_save.json"

var save: SaveSystem
var economy: EconomySystem
## Tab the level select screen opens on.
var selected_tier: String = "easy"

var _pending_level: Dictionary = {}


func _ready() -> void:
	var save_path: String = SaveSystem.DEFAULT_PATH
	# Tools, tests and e2e scripts run with --script; they must never write the
	# player's save. Their files also land in StoragePaths.SANDBOX_DIR, not in user://.
	if StoragePaths.is_script_run():
		save_path = SCRIPT_RUN_SAVE_PATH
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--save-path="):
			save_path = arg.trim_prefix("--save-path=")
	save = SaveSystem.new(save_path)
	var existing: bool = save.load_save()
	# The colour mode is applied by the ThemeManager autoload (loaded after this one).
	Languages.apply(save.language)
	economy = EconomySystem.new()
	economy.name = "Economy"
	economy.setup(save)
	add_child(economy)
	if not existing:
		economy.earn(EconomySystem.STARTING_COINS, "starting_balance")
	# Daily login bonus (spec 4.8); its own UI comes in a later phase.
	economy.claim_daily_bonus(Time.get_date_string_from_system())


func play_level(tier: String, index: int) -> void:
	selected_tier = tier
	_pending_level = {"tier": tier, "index": index}
	_go(GAME_BOARD)


## Opens bonus level `file_name` (data/levels/bonus/).
func play_bonus(file_name: String) -> void:
	_pending_level = {"bonus": file_name}
	_go(GAME_BOARD)


## The level the game board should open, once: {tier, index}, {bonus: file},
## or {} if none was requested.
func take_pending_level() -> Dictionary:
	var pending: Dictionary = _pending_level
	_pending_level = {}
	return pending


func show_level_select(tier: String = "") -> void:
	if not tier.is_empty():
		selected_tier = tier
	_go(LEVEL_SELECT)


func show_main_menu() -> void:
	_go(MAIN_MENU)


func show_shop() -> void:
	_go(SHOP)


## Every scene change fades through the ScreenTransition autoload.
func _go(scene_path: String) -> void:
	var transition: Node = get_node_or_null("/root/ScreenTransition")
	if transition != null:
		transition.change_scene(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)
