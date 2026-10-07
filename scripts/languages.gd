class_name Languages
extends RefCounted
## Language choice (economy/UX addendum 4.2) on Godot's TranslationServer.
## Texts live in locale/<code>.po under keys such as "MENU_PLAY". Only az.po is
## complete; tr/ru/en.po hold every key with an empty msgstr and a
## "[TODO: XX]" marker. Missing texts fall back to Azerbaijani
## (internationalization/locale/fallback="az"), never to an empty string.

const DEFAULT: String = "az"
## Shown in the settings list, each in its own language.
const ALL: Array[Dictionary] = [
	{"code": "az", "name": "Azərbaycan"},
	{"code": "tr", "name": "Türkçe"},
	{"code": "ru", "name": "Русский"},
	{"code": "en", "name": "English"},
]


static func is_known(code: String) -> bool:
	return index_of(code) >= 0


static func index_of(code: String) -> int:
	for i: int in ALL.size():
		if ALL[i]["code"] == code:
			return i
	return -1


## Switches the game to `code` (DEFAULT if unknown); returns the code used.
static func apply(code: String) -> String:
	var used: String = code if is_known(code) else DEFAULT
	TranslationServer.set_locale(used)
	return used


## A translated text outside of a Node (where tr() is not available).
static func text(key: String) -> String:
	return String(TranslationServer.translate(key))
