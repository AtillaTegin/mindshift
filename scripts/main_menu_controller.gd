extends Control
## Main menu (spec 5.1): Play continues with the next unfinished level,
## Levels opens the level select, Settings holds sound, dark mode and language
## (economy/UX addendum 4).

@onready var _play_button: Button = %PlayButton
@onready var _levels_button: Button = %LevelsButton
@onready var _settings_button: Button = %SettingsButton
@onready var _progress_label: Label = %ProgressLabel
@onready var _settings_panel: Control = %SettingsPanel
@onready var _sound_toggle: CheckButton = %SoundToggle
@onready var _dark_mode_toggle: CheckButton = %DarkModeToggle
@onready var _language_option: OptionButton = %LanguageOption
@onready var _close_settings_button: Button = %CloseSettingsButton

var _save: SaveSystem


func _ready() -> void:
	var app: Node = get_node_or_null("/root/App")
	_save = app.save if app != null else SaveSystem.new()
	_update_progress()
	_play_button.pressed.connect(func() -> void:
		var next: Dictionary = LevelCatalog.next_to_play(_save)
		if app != null and not next.is_empty():
			app.play_level(next["tier"], next["index"]))
	_levels_button.pressed.connect(func() -> void:
		if app != null:
			app.show_level_select())
	_sound_toggle.button_pressed = _save.sound_enabled
	_sound_toggle.toggled.connect(_save.set_sound_enabled)
	_dark_mode_toggle.button_pressed = ThemeManager.is_dark()
	_dark_mode_toggle.toggled.connect(set_dark_mode)
	# Language names are shown as written in that language, never translated.
	_language_option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for language: Dictionary in Languages.ALL:
		_language_option.add_item(language["name"])
	_language_option.select(maxi(Languages.index_of(TranslationServer.get_locale()), 0))
	_language_option.item_selected.connect(func(index: int) -> void: set_language(Languages.ALL[index]["code"]))
	_settings_button.pressed.connect(func() -> void: _settings_panel.visible = true)
	_close_settings_button.pressed.connect(func() -> void: _settings_panel.visible = false)
	_settings_panel.visible = false


func set_dark_mode(enabled: bool) -> void:
	var mode: String = ThemeManager.DARK if enabled else ThemeManager.LIGHT
	ThemeManager.set_mode(mode)
	_save.set_theme(mode)


func set_language(code: String) -> void:
	_save.set_language(Languages.apply(code))


func _notification(what: int) -> void:
	# Texts built in code follow a language switch; scene texts do so by themselves.
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_progress()


func _update_progress() -> void:
	var total_levels: int = 0
	for tier: String in Difficulty.ORDER:
		total_levels += LevelCatalog.level_count(tier)
	_progress_label.text = tr("MENU_PROGRESS") % [_save.get_total_stars(), total_levels * 3]
