class_name SortTexts
extends RefCounted
## Player-facing texts of the colour-order prototype, Azerbaijani only. They
## stay out of locale/*.po while the mechanic is a prototype, so translators
## never see them; move them there if the mechanic joins the game.

const AZ: Dictionary = {
	"MENU_TITLE": "Prototip: Rəng ardıcıllığı",
	"MENU_NOTE": "Sınaq səviyyəsi. Əsas oyuna, səviyyələrə və qənaətə toxunmur.",
	"MENU_RULES": "• Yalnız qüllənin üst diski götürülür.\n"
			+ "• Disk boş qülləyə, eyni ölçülü və ya daha böyük diskin üstünə qoyulur.\n"
			+ "• Eyni ölçülü disklər bir-birinin üstünə qoyula bilər.\n"
			+ "• Bütün diskləri sağ qüllədə hədəfdəki rəng ardıcıllığı ilə yığ (aşağıdan yuxarı).\n"
			+ "• Yalnız uğurlu köçürmə gediş sayılır. Gedişlər bitənə qədər yığmasan, səviyyə uduzulur.",
	"MENU_LIMIT": "Gediş limiti: %d",
	"MENU_SHORTEST": "Ən qısa həll: %d gediş (limit sınaq üçün dəyişdirilə bilər)",
	"MENU_PLAY": "Başla",
	"MENU_BACK_TO_GAME": "Əsas oyuna qayıt",
	"BOARD_TITLE": "Rəng ardıcıllığı",
	"BOARD_MENU": "Menyu",
	"BOARD_RESTART": "Yenidən",
	"BOARD_MOVES_LEFT": "Qalan gediş: %d",
	"BOARD_LIMIT": "Limit: %d",
	"BOARD_GOAL_TITLE": "Hədəf",
	"BOARD_GOAL_HINT": "Sağ qüllədə, aşağıdan yuxarı",
	"BOARD_PROGRESS": "Yerində: %d / %d",
	"BOARD_TARGET_MARK": "HƏDƏF",
	"BOARD_ILLEGAL": "Böyük disk kiçik diskin üstünə qoyula bilməz",
	"BOARD_PROGRESS_UP": "Düzdür! %d / %d yerində",
	"BOARD_WRONG_PLACE": "Bu rəng hədəfdə bu yerə uyğun deyil",
	"BOARD_LAST_MOVE": "Son gediş!",
	"RESULT_WIN_TITLE": "Qələbə!",
	"RESULT_WIN_TEXT": "%d gedişdə həll etdin.\nLimit: %d · Ən qısa həll: %d",
	"RESULT_LOSE_TITLE": "Gedişlər bitdi",
	"RESULT_LOSE_TEXT": "Hədəf ardıcıllığından %d / %d disk yerində idi.",
	"RESULT_RETRY": "Yenidən cəhd et",
	"RESULT_TO_MENU": "Prototip menyusu",
	"LOAD_ERROR": "Prototip səviyyəsi yüklənmədi:\n%s",
}


static func text(key: String) -> String:
	return AZ.get(key, key)
