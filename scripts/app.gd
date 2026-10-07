extends Node
## Autoload "App": owns the player's save and switches between screens.
## Pass `-- --save-path=user://other.json` to use another save file (tests).

const MAIN_MENU: String = "res://scenes/main_menu.tscn"
const LEVEL_SELECT: String = "res://scenes/level_select.tscn"
const GAME_BOARD: String = "res://scenes/game_board.tscn"

var save: SaveSystem
## Tab the level select screen opens on.
var selected_tier: String = "easy"

var _pending_level: Dictionary = {}


func _ready() -> void:
	var save_path: String = SaveSystem.DEFAULT_PATH
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--save-path="):
			save_path = arg.trim_prefix("--save-path=")
	save = SaveSystem.new(save_path)
	save.load_save()


func play_level(tier: String, index: int) -> void:
	selected_tier = tier
	_pending_level = {"tier": tier, "index": index}
	get_tree().change_scene_to_file(GAME_BOARD)


## The level the game board should open, once; {} if none was requested.
func take_pending_level() -> Dictionary:
	var pending: Dictionary = _pending_level
	_pending_level = {}
	return pending


func show_level_select(tier: String = "") -> void:
	if not tier.is_empty():
		selected_tier = tier
	get_tree().change_scene_to_file(LEVEL_SELECT)


func show_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
