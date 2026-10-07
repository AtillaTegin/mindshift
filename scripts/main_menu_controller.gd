extends Control
## Main menu (spec 5.1): Play continues with the next unfinished level,
## Levels opens the level select, Settings holds the (not yet used) sound toggle.

@onready var _play_button: Button = %PlayButton
@onready var _levels_button: Button = %LevelsButton
@onready var _settings_button: Button = %SettingsButton
@onready var _progress_label: Label = %ProgressLabel
@onready var _settings_panel: Control = %SettingsPanel
@onready var _sound_toggle: CheckButton = %SoundToggle
@onready var _close_settings_button: Button = %CloseSettingsButton


func _ready() -> void:
	var app: Node = get_node_or_null("/root/App")
	var save: SaveSystem = app.save if app != null else SaveSystem.new()
	var total_levels: int = 0
	for tier: String in Difficulty.ORDER:
		total_levels += LevelCatalog.level_count(tier)
	_progress_label.text = "Ulduz: %d / %d" % [save.get_total_stars(), total_levels * 3]
	_play_button.pressed.connect(func() -> void:
		var next: Dictionary = LevelCatalog.next_to_play(save)
		if app != null and not next.is_empty():
			app.play_level(next["tier"], next["index"]))
	_levels_button.pressed.connect(func() -> void:
		if app != null:
			app.show_level_select())
	_sound_toggle.button_pressed = save.sound_enabled
	_sound_toggle.toggled.connect(save.set_sound_enabled)
	_settings_button.pressed.connect(func() -> void: _settings_panel.visible = true)
	_close_settings_button.pressed.connect(func() -> void: _settings_panel.visible = false)
	_settings_panel.visible = false
