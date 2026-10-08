class_name ShopCatalog
extends RefCounted
## What the shop sells (economy/UX addendum 8.2). Amounts for the packs, the
## ad reward and the 24 h hint price were chosen by the user on 2026-10-09.
## Prices are display strings for now; with real billing they come from the
## store (localised per country).
##
## kind: "coins" (real money, adds `coins`), "unlimited_hints" (real money,
## free hints for `hours`), "rewarded_ad" (free, watch an ad for coins),
## "remove_ads" (real money, one-time; only once ads exist).

const PRODUCTS: Array[Dictionary] = [
	{"id": "coins_small", "kind": "coins", "coins": 60, "price": "$0.99", "title": "SHOP_COINS_SMALL", "icon": "coin"},
	{"id": "coins_medium", "kind": "coins", "coins": 200, "price": "$2.99", "title": "SHOP_COINS_MEDIUM", "icon": "coin"},
	{"id": "coins_large", "kind": "coins", "coins": 500, "price": "$6.99", "title": "SHOP_COINS_LARGE", "icon": "coin"},
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
