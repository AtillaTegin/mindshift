extends "res://tests/test_case.gd"
## ThemeManager (economy/UX addendum 4.1): light/dark palettes with semantic
## roles, one Theme on the root window, and no colour codes in UI code.

const SAVE_PATH: String = "user://test_theme_save.json"
## Files allowed to contain colour literals, and why.
const COLOUR_LITERAL_ALLOWED: Array[String] = [
	"res://scripts/theme_manager.gd",  # the palettes themselves
	"res://scripts/level_complete_popup.gd",  # confetti: festive, the same in both modes
	"res://scenes/components/disk.gd",  # Color.WHITE placeholder until the board sets the disk colour
	# Coaching overlay primitives draw over a dimmed screen and look the same in both modes.
	"res://scenes/components/coaching/focus_ring.gd",
	"res://scenes/components/coaching/scrim.gd",
	"res://scenes/components/coaching/ghost_pointer.gd",
	"res://scenes/components/coaching/coach_toast.gd",
]

var _mode_before: String = ""
var _nodes: Array[Node] = []


func before_each() -> void:
	_mode_before = ThemeManager.mode
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func after_each() -> void:
	for node: Node in _nodes:
		node.get_parent().remove_child(node)
		node.free()
	_nodes.clear()
	ThemeManager.set_mode(_mode_before)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func test_both_palettes_define_the_same_roles() -> void:
	var light: Array = ThemeManager.LIGHT_PALETTE.keys()
	var dark: Array = ThemeManager.DARK_PALETTE.keys()
	light.sort()
	dark.sort()
	assert_eq(light, dark)
	for role: String in ThemeManager.CORE_ROLES:
		assert_true(light.has(role), "role %s" % role)
	assert_ne(ThemeManager.LIGHT_PALETTE["background"], ThemeManager.DARK_PALETTE["background"])


func test_switching_restyles_open_screens() -> void:
	ThemeManager.set_mode(ThemeManager.LIGHT)
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var label: Label = Label.new()
	var background: ThemedColorRect = ThemedColorRect.new()
	for node: Node in [label, background]:
		root.add_child(node)
		_nodes.append(node)
	assert_eq(label.get_theme_color("font_color"), ThemeManager.LIGHT_PALETTE["text_primary"])
	assert_eq(background.color, ThemeManager.LIGHT_PALETTE["background"])
	var changes: Array[String] = []
	ThemeManager.theme_changed.connect(func(mode: String) -> void: changes.append(mode), CONNECT_ONE_SHOT)
	ThemeManager.set_mode(ThemeManager.DARK)
	assert_eq(changes, [ThemeManager.DARK] as Array[String])
	assert_true(ThemeManager.is_dark())
	assert_eq(ThemeManager.color("accent"), ThemeManager.DARK_PALETTE["accent"])
	assert_eq(label.get_theme_color("font_color"), ThemeManager.DARK_PALETTE["text_primary"], "labels follow")
	assert_eq(background.color, ThemeManager.DARK_PALETTE["background"], "backgrounds follow")
	label.theme_type_variation = &"SecondaryLabel"
	assert_eq(label.get_theme_color("font_color"), ThemeManager.DARK_PALETTE["text_secondary"])


func test_unknown_mode_means_light() -> void:
	ThemeManager.set_mode("purple")
	assert_eq(ThemeManager.mode, ThemeManager.LIGHT)


func test_theme_and_language_are_saved() -> void:
	var save: SaveSystem = SaveSystem.new(SAVE_PATH)
	assert_eq(save.theme, "light")
	assert_eq(save.language, "az")
	save.set_theme("dark")
	save.set_language("ru")
	var reopened: SaveSystem = SaveSystem.new(SAVE_PATH)
	assert_true(reopened.load_save())
	assert_eq(reopened.theme, "dark")
	assert_eq(reopened.language, "ru")
	assert_true(reopened.sound_enabled, "older setting untouched")


func test_save_without_new_settings_still_loads() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "coins": 3, "completed_levels": {},
			"last_daily_bonus_date": null, "settings": {"sound_enabled": false}}))
	file.close()
	var save: SaveSystem = SaveSystem.new(SAVE_PATH)
	assert_true(save.load_save())
	assert_eq(save.coins, 3)
	assert_false(save.sound_enabled)
	assert_eq(save.theme, "light")
	assert_eq(save.language, "az")


func test_settings_dark_mode_switch() -> void:
	var app: Node = (Engine.get_main_loop() as SceneTree).root.get_node("App")
	var theme_before: String = app.save.theme
	var menu: Control = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	_nodes.append(menu)
	var toggle: CheckButton = menu.get_node("%DarkModeToggle")
	toggle.button_pressed = true
	assert_true(ThemeManager.is_dark())
	assert_eq(app.save.theme, "dark", "remembered in the save")
	assert_eq((menu.get_node("Background") as ColorRect).color, ThemeManager.DARK_PALETTE["background"])
	toggle.button_pressed = false
	assert_false(ThemeManager.is_dark())
	app.save.set_theme(theme_before)


func test_no_colour_codes_in_ui_files() -> void:
	var offenders: Array[String] = []
	var literal: RegEx = RegEx.create_from_string("\\bColor(\\(|\\.[A-Z])")
	var files: Array[String] = _files("res://scenes", ["tscn", "gd"]) + _files("res://scripts", ["gd"]) + _files("res://core", ["gd"])
	assert_true(files.size() > 30, "scanned %d files" % files.size())
	assert_not_null(literal.search(FileAccess.get_file_as_string(COLOUR_LITERAL_ALLOWED[0])), "the check does catch literals")
	for path: String in files:
		if COLOUR_LITERAL_ALLOWED.has(path):
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			if not lines[i].strip_edges().begins_with("#") and literal.search(lines[i]) != null:
				offenders.append("%s:%d" % [path, i + 1])
	assert_eq(offenders, [] as Array[String], "use ThemeManager.color(role) or a theme variation")


static func _files(dir: String, extensions: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir):
		if extensions.has(file_name.get_extension()):
			found.append("%s/%s" % [dir, file_name])
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_files("%s/%s" % [dir, sub], extensions))
	return found
