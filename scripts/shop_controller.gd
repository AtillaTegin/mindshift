extends Control
## Shop screen, opened from the main menu (economy/UX addendum 5). For now it
## shows the coin balance only; the products come with addendum section 8.

## Pays for purchases; taken from the App autoload when left empty.
var economy: EconomySystem

@onready var _coin_label: Label = %CoinLabel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	var app: Node = get_node_or_null("/root/App")
	if economy == null:
		if app != null:
			economy = app.economy
		else:
			economy = EconomySystem.new()
			economy.setup(SaveSystem.new())
			add_child(economy)
	economy.coins_changed.connect(func(_coins: int) -> void: _update_coins())
	_back_button.pressed.connect(func() -> void:
		if app != null:
			app.show_main_menu())
	_update_coins()


func _update_coins() -> void:
	_coin_label.text = tr("BOARD_COINS") % economy.coins
