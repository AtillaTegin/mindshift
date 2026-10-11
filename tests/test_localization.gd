extends "res://tests/test_case.gd"
## Language infrastructure (economy/UX addendum 4.2): az.po is complete,
## tr/ru/en.po hold the same keys with "[TODO]" markers, untranslated texts
## fall back to Azerbaijani, and UI code uses keys instead of literal texts.

const LOCALE_DIR: String = "res://locale"
## Files allowed to contain Azerbaijani literals, and why.
const LITERAL_TEXT_ALLOWED: Array[String] = [
	"res://scripts/languages.gd",  # language names, each in its own language
	"res://scenes/components/coaching/coaching_demo.gd",  # developer demo scene
]
const KEY_PATTERN: String = "\"([A-Z][A-Z0-9]*_[A-Z0-9_]+)\""

var _locale_before: String = ""


func before_each() -> void:
	_locale_before = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale_before)


static func _ids(entries: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in entries:
		ids.append(entry["id"])
	return ids


func test_azerbaijani_is_complete() -> void:
	var entries: Array[Dictionary] = TranslationSync.read_po(LOCALE_DIR + "/az.po")
	assert_true(entries.size() > 30, "%d keys" % entries.size())
	for entry: Dictionary in entries:
		assert_false(String(entry["text"]).is_empty(), "az text for %s" % entry["id"])


func test_other_languages_have_every_key_and_todo_markers() -> void:
	var source_ids: Array[String] = _ids(TranslationSync.read_po(LOCALE_DIR + "/az.po"))
	for code: String in ["tr", "ru", "en"]:
		var path: String = "%s/%s.po" % [LOCALE_DIR, code]
		var entries: Array[Dictionary] = TranslationSync.read_po(path)
		assert_eq(_ids(entries), source_ids, "%s.po keys match az.po" % code)
		var untranslated: int = 0
		for entry: Dictionary in entries:
			if String(entry["text"]).is_empty():
				untranslated += 1
		var markers: int = FileAccess.get_file_as_string(path).count("#. [TODO: %s]" % code.to_upper())
		assert_eq(markers, untranslated, "%s: one [TODO] marker per untranslated key" % code)


func test_untranslated_text_falls_back_to_azerbaijani() -> void:
	for code: String in ["tr", "ru", "en"]:
		Languages.apply(code)
		assert_eq(TranslationServer.get_locale(), code)
		assert_eq(tr("MENU_PLAY"), "Oyna", "%s shows the az text, never an empty one" % code)
		assert_eq(Languages.text("LEVEL_TITLE") % 7, "Səviyyə 7", "static code too")


func test_a_filled_translation_wins_over_the_fallback() -> void:
	var turkish: Translation = Translation.new()
	turkish.locale = "tr"
	turkish.add_message("MENU_PLAY", "Oyna (tr)")
	TranslationServer.add_translation(turkish)
	Languages.apply("tr")
	assert_eq(tr("MENU_PLAY"), "Oyna (tr)")
	assert_eq(tr("MENU_LEVELS"), "Səviyyələr", "other keys still fall back")
	TranslationServer.remove_translation(turkish)


func test_language_list() -> void:
	var codes: Array[String] = []
	for language: Dictionary in Languages.ALL:
		codes.append(language["code"])
	assert_eq(codes, ["az", "tr", "ru", "en"] as Array[String])
	assert_eq(Languages.apply("xx"), "az", "unknown codes use the default")
	assert_eq(TranslationServer.get_locale(), "az")


func test_settings_language_choice_is_saved() -> void:
	var app: Node = (Engine.get_main_loop() as SceneTree).root.get_node("App")
	var language_before: String = app.save.language
	var menu: Control = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	var option: OptionButton = menu.get_node("%LanguageOption")
	assert_eq(option.item_count, 4)
	assert_eq(option.get_item_text(2), "Русский")
	option.select(3)
	option.item_selected.emit(3)
	assert_eq(TranslationServer.get_locale(), "en")
	assert_eq(app.save.language, "en")
	assert_eq((menu.get_node("%ProgressLabel") as Label).text.begins_with("Ulduz:"), true, "falls back to az")
	menu.get_parent().remove_child(menu)
	menu.free()
	app.save.set_language(language_before)


func test_every_key_used_in_the_code_exists() -> void:
	var known: Array[String] = _ids(TranslationSync.read_po(LOCALE_DIR + "/az.po"))
	var key: RegEx = RegEx.create_from_string(KEY_PATTERN)
	var missing: Array[String] = []
	for path: String in _ui_files():
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for found: RegExMatch in key.search_all(line):
				if not known.has(found.get_string(1)):
					missing.append("%s: %s" % [path.get_file(), found.get_string(1)])
	assert_eq(missing, [] as Array[String])


func test_no_literal_azerbaijani_texts_in_ui_code() -> void:
	var literal: RegEx = RegEx.create_from_string("\"[^\"]*[əöüğışçƏÖÜĞİŞÇ][^\"]*\"")
	var offenders: Array[String] = []
	assert_true(_ui_files().size() > 30, "scanned %d files" % _ui_files().size())
	assert_not_null(literal.search(FileAccess.get_file_as_string(LITERAL_TEXT_ALLOWED[0])), "the check does catch literals")
	for path: String in _ui_files():
		if LITERAL_TEXT_ALLOWED.has(path):
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			if not lines[i].strip_edges().begins_with("#") and literal.search(lines[i]) != null:
				offenders.append("%s:%d" % [path, i + 1])
	assert_eq(offenders, [] as Array[String], "put the text in locale/az.po and use its key")


static func _ui_files() -> Array[String]:
	var files: Array[String] = []
	for dir: String in ["res://scenes", "res://scripts", "res://core"]:
		files.append_array(_files(dir))
	return files


static func _files(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.get_extension() in ["gd", "tscn"]:
			found.append("%s/%s" % [dir, file_name])
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_files("%s/%s" % [dir, sub]))
	return found
