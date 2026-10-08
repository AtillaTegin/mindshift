extends Control
## Shop screen (economy/UX addendum 5 and 8): coin packs, a rewarded ad,
## 24 h unlimited hints and "remove ads" (shown, not yet for sale). Purchases
## go through StoreService, which is in stub mode: no real payment yet.

const ROW_HEIGHT: float = 112.0

## Pays for purchases; taken from the App autoload when left empty.
var economy: EconomySystem
var store: StoreService

## Product id -> its buy button.
var _buttons: Dictionary[String, Button] = {}
## Product id -> its second text line.
var _details: Dictionary[String, Label] = {}

@onready var _coin_label: Label = %CoinLabel
@onready var _back_button: Button = %BackButton
@onready var _items: VBoxContainer = %Items
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	var app: Node = get_node_or_null("/root/App")
	if economy == null:
		if app != null:
			economy = app.economy
		else:
			economy = EconomySystem.new()
			economy.setup(SaveSystem.new())
			add_child(economy)
	store = StoreService.new(economy)
	economy.coins_changed.connect(func(_coins: int) -> void: _refresh())
	economy.allowances_changed.connect(_refresh)
	_back_button.pressed.connect(func() -> void:
		if app != null:
			app.show_main_menu())
	for product: Dictionary in ShopCatalog.PRODUCTS:
		_items.add_child(_make_row(product))
	_refresh()


## The buy button of `product_id` (also for tests).
func get_buy_button(product_id: String) -> Button:
	return _buttons.get(product_id)


func get_status_text() -> String:
	return _status_label.text


func buy(product_id: String) -> void:
	var result: Dictionary = store.purchase(product_id)
	_status_label.theme_type_variation = &"SuccessLabel" if result["ok"] else &"DangerLabel"
	var text: String = tr(result["message"])
	_status_label.text = text % result["amount"] if text.contains("%d") else text
	_refresh()


func _make_row(product: Dictionary) -> Control:
	var id: String = product["id"]
	var row: PanelContainer = PanelContainer.new()
	row.theme_type_variation = &"RowPanel"
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	row.add_child(line)
	var icon: IconView = IconView.new()
	icon.custom_minimum_size = Vector2(52, 52)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.kind = product["icon"]
	line.add_child(icon)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(texts)
	var title: Label = Label.new()
	title.text = product["title"]
	title.add_theme_font_size_override("font_size", 28)
	texts.add_child(title)
	var detail: Label = Label.new()
	detail.theme_type_variation = &"SecondaryLabel"
	detail.add_theme_font_size_override("font_size", 22)
	texts.add_child(detail)
	_details[id] = detail
	var button: PolishedButton = PolishedButton.new()
	button.custom_minimum_size = Vector2(170, 72)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(buy.bind(id))
	line.add_child(button)
	_buttons[id] = button
	return row


## Updates the balance and every row's state (ads left, offer running, ...).
func _refresh() -> void:
	_coin_label.text = str(economy.coins)
	for product: Dictionary in ShopCatalog.PRODUCTS:
		var id: String = product["id"]
		var button: Button = _buttons[id]
		var detail: Label = _details[id]
		match product["kind"]:
			"coins":
				detail.text = tr("SHOP_COINS_DETAIL") % product["coins"]
				button.text = product["price"]
			"rewarded_ad":
				detail.text = tr("SHOP_AD_DETAIL") % [EconomySystem.AD_REWARD, economy.ads_left(), EconomySystem.ADS_PER_DAY]
				button.text = tr("SHOP_AD_BUTTON")
				button.disabled = economy.ads_left() == 0
			"unlimited_hints":
				if economy.has_unlimited_hints():
					var minutes: int = economy.unlimited_hints_seconds_left() / 60
					detail.text = tr("SHOP_HINTS_ACTIVE") % ("%d:%02d" % [minutes / 60, minutes % 60])
				else:
					detail.text = tr("SHOP_HINTS_DETAIL") % product["hours"]
				button.text = product["price"]
			"remove_ads":
				detail.text = tr("SHOP_REMOVE_ADS_DETAIL")
				button.text = tr("SHOP_SOON")
				button.disabled = true
