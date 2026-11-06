extends "res://scripts/game_board_controller.gd"

signal exit_requested

const BACKGROUNDS: Array[String] = [
	"classic", "tutum", "karakuri", "kilid", "combination",
]

const BENARES_LIVE: Shader = preload("res://prototype/saga_world/boards/benares_live.gdshader")

var _art: TextureRect
var _live_backdrop: ColorRect
var _benares: bool = false
var _benares_cards: Control
var _benares_theme: Theme


func start_level(level: Level) -> void:
	if _art == null:
		_art = TextureRect.new()
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_art.modulate.a = 0.32
		add_child(_art)
		move_child(_art, 1)
		_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var place: Dictionary = LevelCatalog.place_of(level.id)
	var position: int = int(place.get("position", 0))
	_art.texture = null
	_benares = position >= 1 and position <= int(ChapterPlan.DEMO_CHAPTERS[0]["last"])
	if _live_backdrop == null:
		_live_backdrop = ColorRect.new()
		_live_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var atmosphere: ShaderMaterial = ShaderMaterial.new()
		atmosphere.shader = BENARES_LIVE
		_live_backdrop.material = atmosphere
		add_child(_live_backdrop)
		move_child(_live_backdrop, 1)
		_live_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_live_backdrop.visible = _benares
	_style_benares_hud()
	for index: int in range(1, BACKGROUNDS.size()):
		var chapter: Dictionary = ChapterPlan.DEMO_CHAPTERS[index]
		if position >= int(chapter["first"]) and position <= int(chapter["last"]):
			_art.texture = load("res://prototype/saga_world/boards/%s.png" % BACKGROUNDS[index])
			break
	super.start_level(level)


func _style_benares_hud() -> void:
	if _benares_cards == null:
		_benares_cards = Control.new()
		_benares_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_benares_cards)
		move_child(_benares_cards, 2)
		_benares_cards.draw.connect(_draw_benares_cards)
		for path: String in ["Margin/Layout/TopBar", "Margin/Layout/Actions", "Margin/Layout/GoalTitle", "Margin/Layout/GoalPreview", "Margin/Layout/RulePanel"]:
			var section: Control = get_node(path)
			section.item_rect_changed.connect(_benares_cards.queue_redraw)
		_benares_theme = ThemeManager.theme.duplicate()
		_benares_theme.set_color("font_color", "Label", Color("#124c50"))
		_benares_theme.set_color("font_color", "SecondaryLabel", Color("#285b5d"))
		_benares_theme.set_color("font_color", "CoinLabel", Color("#72501a"))
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color("#215b5c") if state == "normal" else Color("#337778")
			if state == "disabled":
				style.bg_color = Color("#718a82")
			if state == "focus":
				style.draw_center = false
			style.border_color = Color("#e2bc69")
			style.set_border_width_all(2)
			style.set_corner_radius_all(32)
			_benares_theme.set_stylebox(state, "Button", style)
		for role: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			_benares_theme.set_color(role, "Button", Color("#fff4db"))
	theme = _benares_theme if _benares else null
	_benares_cards.visible = _benares
	_benares_cards.queue_redraw()


func _draw_benares_cards() -> void:
	_draw_hud_card("Margin/Layout/TopBar", "Margin/Layout/Actions", Color("#f6e3b5d9"))
	_draw_hud_card("Margin/Layout/GoalTitle", "Margin/Layout/GoalPreview", Color("#fff3dbf5"))
	_draw_hud_card("Margin/Layout/RulePanel", "Margin/Layout/RulePanel", Color("#fff3dbf5"))


func _draw_hud_card(first: String, last: String, fill: Color) -> void:
	var start: Control = get_node(first)
	var end: Control = get_node(last)
	var rect: Rect2 = start.get_global_rect().merge(end.get_global_rect())
	rect.position -= _benares_cards.global_position
	rect = rect.grow(9.0)
	var card: StyleBoxFlat = StyleBoxFlat.new()
	card.bg_color = fill
	card.border_color = Color("#ca9d54")
	card.set_border_width_all(1)
	card.set_corner_radius_all(26)
	card.shadow_color = Color("#3f351f36")
	card.shadow_size = 8
	card.shadow_offset = Vector2(0, 4)
	_benares_cards.draw_style_box(card, rect)

func _build_views() -> void:
	super._build_views()
	if not _benares:
		return
	for peg: PegView in _peg_views:
		peg.sculpted_base = true
		peg.stone_color = Color("#a97c51")
		peg.inlay_color = Color("#12535b")
		peg.needle_color = Color("#76dbe0")
		peg.queue_redraw()
	var total: int = session.state.get_disk_count()
	for size_id: int in _disk_views:
		var disk: DiskView = _disk_views[size_id]
		var shade: float = float(size_id - 1) / float(maxi(total - 1, 1))
		disk.color = Color("#ffe08a").lerp(Color("#a86922"), shade)
		disk.number_color = Color("#261707")
		disk.gilded_bevel = true
		_palette[size_id] = {"fill": disk.color, "text": disk.number_color}
		disk.queue_redraw()

func _show_level_select() -> void:
	exit_requested.emit()

func _next_level() -> Dictionary:
	var next: Dictionary = super._next_level()
	var final_chapter: Dictionary = ChapterPlan.DEMO_CHAPTERS[BACKGROUNDS.size() - 1]
	return next if int(next.get("position", 0)) <= int(final_chapter["last"]) else {}
