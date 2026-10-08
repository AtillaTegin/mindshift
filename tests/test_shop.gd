extends "res://tests/test_case.gd"
## Shop (economy/UX addendum 8.2/8.3): products, stub purchases and the screen.

const SAVE_PATH: String = "user://test_shop_save.json"
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
	var expected: Dictionary = {
		"coins_small": [60, "$0.99"], "coins_medium": [200, "$2.99"], "coins_large": [500, "$6.99"]}
	for id: String in expected:
		var product: Dictionary = ShopCatalog.get_product(id)
		assert_eq(product["kind"], "coins")
		assert_eq(product["coins"], expected[id][0], id)
		assert_eq(product["price"], expected[id][1], id)
	var hints: Dictionary = ShopCatalog.get_product("unlimited_hints_24h")
	assert_eq([hints["hours"], hints["price"]], [24, "$0.99"])
	assert_true(ShopCatalog.is_available(ShopCatalog.get_product("rewarded_ad")))
	assert_false(ShopCatalog.is_available(ShopCatalog.get_product("remove_ads")), "needs an ad system first")
	assert_eq(ShopCatalog.PRODUCTS.size(), 6)


func test_stub_purchases_grant_at_once() -> void:
	var store: StoreService = StoreService.new(_economy)
	assert_true(StoreService.STUB_MODE)
	assert_eq(store.purchase("coins_small"), {"ok": true, "message": "SHOP_BOUGHT_COINS", "amount": 60})
	assert_eq(store.purchase("coins_large")["amount"], 500)
	assert_eq(_economy.coins, 560)
	assert_true(store.purchase("unlimited_hints_24h")["ok"])
	assert_true(_economy.has_unlimited_hints())
	assert_eq(store.purchase("remove_ads")["ok"], false)
	assert_eq(store.purchase("nope")["ok"], false)
	for i: int in EconomySystem.ADS_PER_DAY:
		assert_eq(store.purchase("rewarded_ad")["amount"], 5)
	assert_eq(store.purchase("rewarded_ad"), {"ok": false, "message": "SHOP_AD_LIMIT", "amount": 0})
	var reopened: SaveSystem = SaveSystem.new(SAVE_PATH)
	reopened.load_save()
	assert_eq(reopened.coins, 560 + 25, "kept in the save")


func test_billing_hook_is_marked() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/store_service.gd")
	assert_true(source.contains("# TODO: real Billing SDK buraya qoşulacaq"), "addendum 8.3 marker")


func test_shop_screen_buy_buttons() -> void:
	_open_shop()
	var small: Button = _shop.get_buy_button("coins_small")
	assert_eq(small.text, "$0.99")
	assert_true(small is PolishedButton)
	small.pressed.emit()
	assert_eq(_economy.coins, 60)
	assert_eq((_shop.get_node("%CoinLabel") as Label).text, "60")
	assert_eq(_shop.get_status_text(), "+60 coin əlavə olundu (demo)")
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
	assert_eq(_economy.coins, 25)
	assert_eq(_shop.get_status_text(), "+5 coin (demo reklam)")


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
