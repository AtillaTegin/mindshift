extends Control
## Pilot levels that are not on the road yet (Fəsil Sistemi v1.2: Güzgü
## "Əks-səda" pilots before its chapter; the new balance scale to look at
## before its chapter; the mixed exchange's dead-end rule, Mod Kataloqu v1.1
## D.3). One button per level file in this folder; a level
## opens on the ordinary game board. Not part of the game: no path, and its
## texts stay here (the prototype folder is outside the text scans).

const BOARD_SCENE: PackedScene = preload("res://scenes/game_board.tscn")
const DIR: String = "res://prototype/pilots"
const TITLE: String = "Pilot səviyyələr"
const NAMES: Dictionary = {"mirror": "Güzgü (Əks-səda)", "balance": "Tərəzi", "swap": "Qarışıq-Ayırma (dalan)"}
const BACK: String = "Oyuna qayıt"


func _ready() -> void:
	var background: ThemedColorRect = ThemedColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var list: VBoxContainer = VBoxContainer.new()
	list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	list.offset_left = 40
	list.offset_right = -40
	list.offset_top = 60
	list.add_theme_constant_override("separation", 18)
	add_child(list)
	var title: Label = Label.new()
	title.text = TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	list.add_child(title)
	for file_name: String in level_files():
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 88)
		button.text = button_text(file_name)
		button.pressed.connect(open.bind("%s/%s" % [DIR, file_name]))
		list.add_child(button)
	var back: Button = Button.new()
	back.custom_minimum_size = Vector2(0, 80)
	back.text = BACK
	back.pressed.connect(func() -> void: get_node("/root/App").show_main_menu())
	list.add_child(back)


## The pilot level files, in name order.
static func level_files() -> Array[String]:
	var found: Array[String] = []
	for file_name: String in DirAccess.get_files_at(DIR):
		if file_name.ends_with(".json"):
			found.append(file_name)
	found.sort()
	return found


## "Güzgü (Əks-səda) 3 · 15 gediş"
static func button_text(file_name: String) -> String:
	var stem: String = file_name.get_basename()
	var errors: Array[String] = []
	var level: Level = Level.load_file("%s/%s" % [DIR, file_name], errors)
	var moves: String = " · %d gediş" % level.min_moves if level != null else ""
	return "%s %s%s" % [NAMES.get(stem.get_slice("_", 0), stem), stem.get_slice("_", 1), moves]


## Opens the level in `path` on the game board.
func open(path: String) -> void:
	var board: Node = BOARD_SCENE.instantiate()
	board.level_path = path
	var tree: SceneTree = get_tree()
	tree.root.add_child(board)
	tree.current_scene = board
	queue_free()
