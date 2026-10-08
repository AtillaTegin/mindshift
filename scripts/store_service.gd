class_name StoreService
extends RefCounted
## Buys shop products (economy/UX addendum 8.3). STUB MODE: there is no real
## payment and no real ad yet. A "purchase" grants the product at once, so the
## whole shop flow can be built and tested now; Google Play Billing needs a
## signed build and a Play Console test track, which come with the Android
## build day.

const STUB_MODE: bool = true

var _economy: EconomySystem


func _init(economy: EconomySystem) -> void:
	_economy = economy


## Buys `product_id`. Returns { ok: bool, message: String (translation key),
## amount: int }; amount is the coins or hours granted.
func purchase(product_id: String) -> Dictionary:
	var product: Dictionary = ShopCatalog.get_product(product_id)
	if not ShopCatalog.is_available(product):
		return {"ok": false, "message": "SHOP_NOT_AVAILABLE", "amount": 0}
	match product["kind"]:
		"rewarded_ad":
			return _watch_ad()
		"coins":
			# TODO: real Billing SDK buraya qoşulacaq (Google Play Billing: launch the
			# purchase flow for product_id, grant on a verified purchase, then consume).
			_economy.earn(product["coins"], "purchase")
			return {"ok": true, "message": "SHOP_BOUGHT_COINS", "amount": product["coins"]}
		"unlimited_hints":
			# TODO: real Billing SDK buraya qoşulacaq (consumable timed offer).
			_economy.grant_unlimited_hints(product["hours"])
			return {"ok": true, "message": "SHOP_BOUGHT_HINTS", "amount": product["hours"]}
	return {"ok": false, "message": "SHOP_NOT_AVAILABLE", "amount": 0}


func _watch_ad() -> Dictionary:
	if _economy.ads_left() == 0:
		return {"ok": false, "message": "SHOP_AD_LIMIT", "amount": 0}
	# TODO: real rewarded-ad SDK: show the ad and grant only when it was watched.
	var coins: int = _economy.reward_ad()
	return {"ok": true, "message": "SHOP_AD_DONE", "amount": coins}
