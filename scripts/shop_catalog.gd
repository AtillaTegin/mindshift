class_name ShopCatalog
extends RefCounted
## What the shop sells (economy/UX addendum 8.2). Coin packs follow the economy
## formulas addendum v3, section 6: about 25-36 coins per dollar, in line with
## comparable puzzle games, with a slightly better rate for bigger packs. No pack
## carries a "most popular" badge until real sales data exists. The 24 h hint
## price was chosen by the user on 2026-10-09; the ad reward is EconomySystem.AD_REWARD.
## Prices are display strings for now; with real billing they come from the
## store (localised per country).
##
## kind: "coins" (real money, adds `coins`), "unlimited_hints" (real money,
## free hints for `hours`), "rewarded_ad" (free, watch an ad for coins),
## "remove_ads" (real money, one-time; only once ads exist).

const PRODUCTS: Array[Dictionary] = [
	{"id": "coins_25", "kind": "coins", "coins": 25, "price": "$0.99", "title": "SHOP_COINS_1", "icon": "coin"},
	{"id": "coins_60", "kind": "coins", "coins": 60, "price": "$1.99", "title": "SHOP_COINS_2", "icon": "coin"},
	{"id": "coins_150", "kind": "coins", "coins": 150, "price": "$4.99", "title": "SHOP_COINS_3", "icon": "coin"},
	{"id": "coins_320", "kind": "coins", "coins": 320, "price": "$9.99", "title": "SHOP_COINS_4", "icon": "coin"},
	{"id": "coins_700", "kind": "coins", "coins": 700, "price": "$19.99", "title": "SHOP_COINS_5", "icon": "coin"},
	{"id": "coins_1800", "kind": "coins", "coins": 1800, "price": "$49.99", "title": "SHOP_COINS_6", "icon": "coin"},
	{"id": "rewarded_ad", "kind": "rewarded_ad", "price": "", "title": "SHOP_AD_TITLE", "icon": "coin"},
	{"id": "unlimited_hints_24h", "kind": "unlimited_hints", "hours": 24, "price": "$0.99", "title": "SHOP_HINTS_TITLE", "icon": "hint"},
	{"id": "remove_ads", "kind": "remove_ads", "price": "", "title": "SHOP_REMOVE_ADS_TITLE", "icon": ""},
]


static func get_product(id: String) -> Dictionary:
	for product: Dictionary in PRODUCTS:
		if product["id"] == id:
			return product
	return {}


## False for products that cannot be bought yet ("remove ads" needs an ad system).
static func is_available(product: Dictionary) -> bool:
	return not product.is_empty() and product["kind"] != "remove_ads"
