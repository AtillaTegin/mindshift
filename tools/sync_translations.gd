class_name TranslationSync
extends SceneTree
## Keeps locale/tr.po, ru.po and en.po in step with locale/az.po (the source):
##   godot --headless --path . --script res://tools/sync_translations.gd
## Every az key appears in every language. Existing translations are kept;
## missing ones get an empty msgstr (so the game falls back to Azerbaijani)
## and a "[TODO: XX]" marker with the Azerbaijani text for the translator.
## Keys no longer in az.po are dropped. Exits 0 on success.
## Only the simple PO used here is read: one-line msgid/msgstr pairs.

const LOCALE_DIR: String = "res://locale"
const SOURCE: String = "az"
const TARGETS: Array[String] = ["tr", "ru", "en"]


func _initialize() -> void:
	quit(0 if _run() else 1)


func _run() -> bool:
	var source: Array[Dictionary] = read_po(_path(SOURCE))
	if source.is_empty():
		printerr("No entries in %s" % _path(SOURCE))
		return false
	for code: String in TARGETS:
		var existing: Dictionary = {}
		for entry: Dictionary in read_po(_path(code)):
			existing[entry["id"]] = entry["text"]
		var file: FileAccess = FileAccess.open(_path(code), FileAccess.WRITE)
		if file == null:
			printerr("Cannot write %s" % _path(code))
			return false
		file.store_string(render(code, source, existing))
		file.close()
		var todo: int = 0
		for entry: Dictionary in source:
			if String(existing.get(entry["id"], "")).is_empty():
				todo += 1
		print("%s: %d keys, %d to translate" % [code, source.size(), todo])
	return true


static func _path(code: String) -> String:
	return "%s/%s.po" % [LOCALE_DIR, code]


## [{ "id", "text" }] in file order, without the header entry.
static func read_po(path: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return entries
	var id: String = ""
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		line = line.strip_edges()
		if line.begins_with("msgid "):
			id = _unquote(line.trim_prefix("msgid "))
		elif line.begins_with("msgstr ") and not id.is_empty():
			entries.append({"id": id, "text": _unquote(line.trim_prefix("msgstr "))})
			id = ""
	return entries


static func render(code: String, source: Array[Dictionary], existing: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray([
		"# MindShift UI texts, %s. Generated from az.po by tools/sync_translations.gd;" % code,
		"# fill in msgstr, keep msgid. An empty msgstr shows the Azerbaijani text.",
		"msgid \"\"", "msgstr \"\"",
		"\"Language: %s\\n\"" % code,
		"\"Content-Type: text/plain; charset=UTF-8\\n\"", ""])
	for entry: Dictionary in source:
		var text: String = existing.get(entry["id"], "")
		if text.is_empty():
			lines.append("#. [TODO: %s] az: %s" % [code.to_upper(), entry["text"]])
		lines.append("msgid %s" % _quote(entry["id"]))
		lines.append("msgstr %s" % _quote(text))
		lines.append("")
	return "\n".join(lines)


static func _unquote(value: String) -> String:
	return value.substr(1, value.length() - 2).c_unescape() if value.length() >= 2 else ""


static func _quote(value: String) -> String:
	return "\"%s\"" % value.c_escape()
