extends "res://tests/test_case.gd"
## Shop (economy/UX addendum 8.2/8.3): products, stub purchases and the screen.

const SAVE_PATH: String = "res://.test_saves/test_shop_save.json"
const SHOP_SCENE: PackedScene = preload("res://scenes/shop.tscn")

var _economy: EconomySystem
var _shop: Control


func before_each() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_economy = EconomySystem.new()
	_economy.setup(SaveSystem.new(SAVE_PATH))
	_economy.date_override = "2026-10-09"
	_economy.time_override = 1_000_000


func after_each() -> void:
	if _shop != null:
		_shop.get_parent().remove_child(_shop)
		_shop.free()
		_shop = null
	_economy.free()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _open_shop() -> void:
	_shop = SHOP_SCENE.instantiate()
	_shop.economy = _economy
	(Engine.get_main_loop() as SceneTree).root.add_child(_shop)


func test_catalog_matches_the_addendum_and_the_chosen_amounts() -> void:
	# Economy formulas addendum v3, section 6: six packs at about 25-36 coins per dollar.
	var expected: Dictionary = {
		"coins_25": [25, "$0.99"], "coins_60": [60, "$1.99"], "coins_150": [150, "$4.99"],
		"coins_320": [320, "$9.99"], "coins_700": [700, "$19.99"], "coins_1800": [1800, "$49.99"]}
	var packs: int = 0
	var last_rate: float = 0.0
	for product: Dictionary in ShopCatalog.PRODUCTS:
		if product["kind"] != "coins":
			continue
		packs += 1
		var id: String = product["id"]
		assert_true(expected.has(id), id)
		assert_eq(product["coins"], expected[id][0], id)
		assert_eq(product["price"], expected[id][1], id)
		var rate: float = product["coins"] / product["price"].trim_prefix("$").to_float()
		assert_true(rate >= 25.0 and rate <= 36.5 and rate >= last_rate - 0.2, "%s: %.1f coins per dollar, never worse than a smaller pack" % [id, rate])
		last_rate = rate
		assert_false(product.has("badge") or product.has("popular"), "no 'most popular' badge without sales data")
	assert_eq(packs, 6)
	var hints: Dictionary = ShopCatalog.get_product("unlimited_hints_24h")
	assert_eq([hints["hours"], hints["price"]], [24, "$0.99"])
	assert_true(ShopCatalog.is_available(ShopCatalog.get_product("rewarded_ad")))
	assert_false(ShopCatalog.is_available(ShopCatalog.get_product("remove_ads")), "needs an ad system first")
	assert_eq(ShopCatalog.PRODUCTS.size(), 9)


func test_stub_purchases_grant_at_once() -> void:
	var store: StoreService = StoreService.new(_economy)
	assert_true(StoreService.STUB_MODE)
	assert_eq(store.purchase("coins_25"), {"ok": true, "message": "SHOP_BOUGHT_COINS", "amount": 25})
	assert_eq(store.purchase("coins_150")["amount"], 150)
	assert_eq(_economy.coins, 175)
	assert_true(store.purchase("unlimited_hints_24h")["ok"])
	assert_true(_economy.has_unlimited_hints())
	assert_eq(store.purchase("remove_ads")["ok"], false)
	assert_eq(store.purchase("nope")["ok"], false)
	for i: int in EconomySystem.ADS_PER_DAY:
		assert_eq(store.purchase("rewarded_ad")["amount"], 4)
	assert_eq(store.purchase("rewarded_ad"), {"ok": false, "message": "SHOP_AD_LIMIT", "amount": 0})
	var reopened: SaveSystem = SaveSystem.new(SAVE_PATH)
	reopened.load_save()
	assert_eq(reopened.coins, 175 + 20, "kept in the save")


func test_billing_hook_is_marked() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/store_service.gd")
	assert_true(source.contains("# TODO: real Billing SDK buraya qoşulacaq"), "addendum 8.3 marker")


func test_shop_screen_buy_buttons() -> void:
	_open_shop()
	assert_eq(_shop.get_detail_text("coins_25"), "25 coin → $0.99")
	assert_eq(_shop.get_detail_text("coins_320"), "320 coin → $9.99")
	assert_eq(_shop.get_detail_text("coins_1800"), "1800 coin → $49.99")
	assert_eq(_shop.get_detail_text("unlimited_hints_24h"), "24 saat pulsuz hint → $0.99")
	var small: Button = _shop.get_buy_button("coins_25")
	assert_eq(small.text, "Al")
	assert_true(small is PolishedButton)
	small.pressed.emit()
	assert_eq(_economy.coins, 25)
	assert_eq((_shop.get_node("%CoinLabel") as Label).text, "25")
	assert_eq(_shop.get_status_text(), "+25 coin əlavə olundu (demo)")
	var hints: Button = _shop.get_buy_button("unlimited_hints_24h")
	hints.pressed.emit()
	assert_true(_economy.has_unlimited_hints())
	assert_eq(_shop.get_status_text(), "24 saatlıq limitsiz Hint aktivdir (demo)")
	var remove_ads: Button = _shop.get_buy_button("remove_ads")
	assert_true(remove_ads.disabled)
	assert_eq(remove_ads.text, "Tezliklə")


func test_ad_button_counts_down_and_locks() -> void:
	_open_shop()
	var ad: Button = _shop.get_buy_button("rewarded_ad")
	for i: int in EconomySystem.ADS_PER_DAY:
		assert_false(ad.disabled)
		ad.pressed.emit()
	assert_true(ad.disabled, "daily limit reached")
	assert_eq(_economy.coins, 20)
	assert_eq(_shop.get_status_text(), "+4 coin (demo reklam)")


func test_board_hint_is_free_while_unlimited() -> void:
	var board: GameBoard = (load("res://scenes/game_board.tscn") as PackedScene).instantiate()
	board.save_system = _economy.save
	board.economy = _economy
	board.tutorials_enabled = false
	board.background_hints = false
	board.level_path = Difficulty.level_path("hard", 1)
	(Engine.get_main_loop() as SceneTree).root.add_child(board)
	assert_eq((board.get_node("%HintButton") as Button).text, "Hint · 5 coin", "hard costs 5")
	_economy.grant_unlimited_hints()
	assert_eq((board.get_node("%HintButton") as Button).text, "Hint · limitsiz")
	board.request_hint()
	assert_not_null(board.hints.hint_move, "a hint with 0 coins")
	assert_eq(_economy.coins, 0)
	board.get_parent().remove_child(board)
	board.free()
