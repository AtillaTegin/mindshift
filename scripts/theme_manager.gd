extends Node
## Autoload "ThemeManager" (economy/UX addendum 4.1): light and dark colour
## sets. UI code never writes colour codes; it asks for a role, e.g.
## ThemeManager.color("accent"). Labels, buttons and panels get their colours
## from one Theme built here and set on the root window, so switching the mode
## restyles every open screen at once.
##
## Themed type variations for scenes: SecondaryLabel, SuccessLabel,
## DangerLabel, CoinLabel (Label) and CardPanel (PanelContainer).

signal theme_changed(mode: String)

const LIGHT: String = "light"
const DARK: String = "dark"
## The semantic roles every palette must define (addendum 4.1).
const CORE_ROLES: Array[String] = ["background", "surface", "text_primary", "text_secondary", "accent", "success", "danger"]

const LIGHT_PALETTE: Dictionary = {
	"background": Color("f4f1ea"),
	"surface": Color("e7e2d6"),
	"text_primary": Color("2b2d42"),
	"text_secondary": Color("6c6f7f"),
	"accent": Color("2a9d8f"),
	"success": Color("2a9d8f"),
	"danger": Color("e63946"),
	# Game-specific roles.
	"card": Color("f4f1ea"),
	"text_on_disk": Color("2b2d42"),
	"fog": Color("d9d3c4"),
	"peg": Color("8d8a80"),
	"button": Color("716f6b"),
	"button_hover": Color("7d7b77"),
	"button_pressed": Color("5a5854"),
	"button_disabled": Color("b3b0aa"),
	"button_text": Color("f4f1ea"),
	"text_disabled": Color("d9d6cf"),
	"coin": Color("c68900"),
	"star_filled": Color("f4b400"),
	"star_empty": Color("d6d1c4"),
	"dim": Color(0.05, 0.05, 0.1, 0.55),
	"shadow": Color(0.1, 0.1, 0.15, 0.18),
}

const DARK_PALETTE: Dictionary = {
	"background": Color("171923"),
	"surface": Color("232634"),
	"text_primary": Color("e8e9f0"),
	"text_secondary": Color("9396a8"),
	"accent": Color("2ec4b6"),
	"success": Color("2ec4b6"),
	"danger": Color("ff5964"),
	"card": Color("232634"),
	"text_on_disk": Color("1b1d29"),
	"fog": Color("2f3346"),
	"peg": Color("5d6072"),
	"button": Color("383c50"),
	"button_hover": Color("42475e"),
	"button_pressed": Color("2c2f40"),
	"button_disabled": Color("262936"),
	"button_text": Color("e8e9f0"),
	"text_disabled": Color("5d6072"),
	"coin": Color("f4b400"),
	"star_filled": Color("f4b400"),
	"star_empty": Color("3a3d4d"),
	"dim": Color(0.0, 0.0, 0.0, 0.6),
	"shadow": Color(0.0, 0.0, 0.0, 0.35),
}

## Functional icon colours (economy/UX addendum 7). Fixed: the same in both
## modes and independent of the accent, because they mark what a thing is.
## Coin is warm gold, hint blue-violet, undo neutral grey-blue.
const ICON_COLORS: Dictionary = {
	"coin": Color("f5b72a"),
	"coin_rim": Color("c98a0c"),
	"coin_shine": Color(1.0, 1.0, 1.0, 0.85),
	"hint": Color("9d8cff"),
	"hint_base": Color("5b4fc4"),
	"undo": Color("b4c3d6"),
	# Bonus levels: gift box and ribbon.
	"gift": Color("e76f51"),
	"gift_ribbon": Color("f4b400"),
	# Frozen disk (bonus mechanics): frosted rim and cracks.
	"ice": Color("e6f7ff"),
	"ice_edge": Color("4fb3e8"),
}

var mode: String = LIGHT
var theme: Theme


func _ready() -> void:
	var app: Node = get_node_or_null("/root/App")
	set_mode(app.save.theme if app != null else LIGHT)


func is_dark() -> bool:
	return mode == DARK


func palette() -> Dictionary:
	return DARK_PALETTE if mode == DARK else LIGHT_PALETTE


func color(role: String) -> Color:
	var colors: Dictionary = palette()
	if not colors.has(role):
		push_error("Unknown colour role \"%s\"" % role)
		return Color.MAGENTA
	return colors[role]


## A fixed icon colour (ICON_COLORS); the same in light and dark mode.
func icon_color(role: String) -> Color:
	if not ICON_COLORS.has(role):
		push_error("Unknown icon colour \"%s\"" % role)
		return Color.MAGENTA
	return ICON_COLORS[role]


## Switches to `new_mode` (LIGHT or DARK; anything else means LIGHT).
func set_mode(new_mode: String) -> void:
	mode = DARK if new_mode == DARK else LIGHT
	theme = build_theme(palette())
	get_tree().root.theme = theme
	theme_changed.emit(mode)


## A distinct colour per disk size, spread evenly over the hue circle. The same
## in both modes: the disks are game pieces, not chrome.
func disk_color(disk_size: int, disk_count: int) -> Color:
	var hue: float = 0.02 + 0.85 * float(disk_size - 1) / float(maxi(disk_count, 2) - 1)
	return Color.from_ok_hsl(hue, 0.7, 0.62)


static func build_theme(colors: Dictionary) -> Theme:
	var built: Theme = Theme.new()
	built.set_color("font_color", "Label", colors["text_primary"])
	for variation: Array in [["SecondaryLabel", "text_secondary"], ["SuccessLabel", "success"],
			["DangerLabel", "danger"], ["CoinLabel", "coin"]]:
		built.set_type_variation(variation[0], "Label")
		built.set_color("font_color", variation[0], colors[variation[1]])

	built.set_stylebox("normal", "Button", _box(colors["button"]))
	built.set_stylebox("hover", "Button", _box(colors["button_hover"]))
	built.set_stylebox("pressed", "Button", _box(colors["button_pressed"]))
	built.set_stylebox("hover_pressed", "Button", _box(colors["button_pressed"]))
	built.set_stylebox("disabled", "Button", _box(colors["button_disabled"]))
	built.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		built.set_color(item, "Button", colors["button_text"])
	built.set_color("font_disabled_color", "Button", colors["text_disabled"])

	# Switches are plain text on the panel, not filled buttons.
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		built.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		built.set_color(item, "CheckButton", colors["text_primary"])

	built.set_stylebox("panel", "PopupMenu", _box(colors["surface"], 16, 12.0))
	built.set_stylebox("hover", "PopupMenu", _box(Color(colors["accent"], 0.25), 10))
	built.set_color("font_color", "PopupMenu", colors["text_primary"])
	built.set_color("font_hover_color", "PopupMenu", colors["text_primary"])
	built.set_font_size("font_size", "PopupMenu", 30)
	built.set_constant("v_separation", "PopupMenu", 20)

	built.set_type_variation("CardPanel", "PanelContainer")
	var card: StyleBoxFlat = _box(colors["card"], 28)
	card.content_margin_left = 40.0
	card.content_margin_right = 40.0
	card.content_margin_top = 36.0
	card.content_margin_bottom = 36.0
	built.set_stylebox("panel", "CardPanel", card)

	# Bonus level cells in the level select: an accent tile, unlike the grey levels.
	built.set_type_variation("BonusButton", "Button")
	built.set_stylebox("normal", "BonusButton", _box(colors["accent"]))
	built.set_stylebox("hover", "BonusButton", _box(colors["accent"].lightened(0.1)))
	built.set_stylebox("pressed", "BonusButton", _box(colors["accent"].darkened(0.15)))
	built.set_stylebox("hover_pressed", "BonusButton", _box(colors["accent"].darkened(0.15)))

	# One product row in the shop.
	built.set_type_variation("RowPanel", "PanelContainer")
	var row: StyleBoxFlat = _box(colors["surface"], 18)
	row.content_margin_left = 20.0
	row.content_margin_right = 16.0
	row.content_margin_top = 14.0
	row.content_margin_bottom = 14.0
	built.set_stylebox("panel", "RowPanel", row)
	return built


static func _box(fill: Color, radius: int = 8, margin: float = 6.0) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box
