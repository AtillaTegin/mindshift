extends Control
## Demo-road world-map prototype. Discovery is separate from gameplay unlocks.

const CLOUDS: Shader = preload("res://prototype/saga_world/clouds.gdshader")
const BOARD_SCENE: PackedScene = preload("res://scenes/game_board.tscn")
const BOARD_SCRIPT: GDScript = preload("res://prototype/saga_world/saga_board.gd")
const GAP_SHADER: Shader = preload("res://prototype/saga_world/sky_blend.gdshader")
const GAP_HEIGHT: float = 176.0
const ART_FADE: Shader = preload("res://prototype/saga_world/sky_art_fade.gdshader")
const DISCOVERY_PATH: String = "res://.test_saves/saga_world_discovery.cfg"
const CHAPTERS: Array[Array] = [
	["Klassik", "classic", "benares.png"],
	["Tutum", "tutum", "tutum_island.png"],
	["Karakuri", "karakuri", "karakuri_kabuto.png"],
	["Kilid", "kilid", "kilid_island.png"],
	["Birləşmə I", "", "combination_1_road.png"],
	["Karvan Yolu", "karvan", "karvan_overview.png"],
	["Zolaqlı", "zolaqli", "zolaqli_long_route.png"],
	["Dairə", "daire", "daire_lower_orbit.png"],
	["Birləşmə II", "", "combination_2_road.png"],
	["Doqquz Halqa", "doqquz_halqa", "doqquz_halqa_route.png"],
	["Tərəzi", "terezi", "terezi_island.png"],
	["Birləşmə III", "", "combination_3_road.png"],
]
const SKY_COLORS: Array[Color] = [
	Color("#766caf"), Color("#397d91"), Color("#735278"), Color("#30476b"),
	Color("#a16475"), Color("#d28791"), Color("#a66ca5"), Color("#1e326b"),
	Color("#4c4b8d"), Color("#21646b"), Color("#3e8b8d"), Color("#376a6e"),
]

var _scroll: ScrollContainer = ScrollContainer.new()
var _column: VBoxContainer = VBoxContainer.new()
var _curtain: ColorRect
var _cards: Array[Button] = []
var _art_layers: Array[TextureRect] = []
var _clouds: Array[ColorRect] = []
var _captions: Array[Label] = []
var _discovery: ConfigFile = ConfigFile.new()
var _detail: Control
var _board_frame: MarginContainer
var _board_save: SaveSystem
var _scroll_tween: Tween
var _scroll_target: float = 0.0
var _transitioning: bool = false
var _started: bool = false


func _ready() -> void:
	_discovery.load(DISCOVERY_PATH)
	add_child(_scroll)
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.add_child(_column)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", 0)
	_cards.resize(CHAPTERS.size())
	_clouds.resize(CHAPTERS.size())
	_art_layers.resize(CHAPTERS.size())
	_captions.resize(CHAPTERS.size())
	for index: int in range(CHAPTERS.size() - 1, -1, -1):
		_add_chapter(index)
		if index > 0:
			_add_gap(index)
	_curtain = _mist(self, 0.0)
	_curtain.hide()
	resized.connect(_fit_cards)
	_fit_cards()
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
	_scroll.get_v_scroll_bar().value_changed.connect(_reveal_center)
	_started = true


func _add_chapter(index: int) -> void:
	var card: Button = Button.new()
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.focus_mode = Control.FOCUS_NONE
	_column.add_child(card)
	_cards[index] = card
	var color: Color = SKY_COLORS[index]
	_add_art(card, index)
	var known: bool = index == 0 or _discovery.get_value("seen", str(index), false)
	_clouds[index] = _mist(card, 0.0 if known else 0.34)
	_clouds[index].material.set_shader_parameter("tint", color)
	_clouds[index].material.set_shader_parameter("feather_edges", true)
	var title: Label = Label.new()
	title.text = str(CHAPTERS[index][0])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#fff0ca"))
	title.add_theme_color_override("font_outline_color", Color("#171628"))
	title.add_theme_constant_override("outline_size", 9)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 34
	var caption: Label = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 26)
	caption.add_theme_color_override("font_color", Color("#fff0ca"))
	caption.add_theme_color_override("font_outline_color", Color("#171628"))
	caption.add_theme_constant_override("outline_size", 8)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -76
	_captions[index] = caption
	_show_range(index)
	card.pressed.connect(_open_chapter.bind(index))


func _add_art(card: Control, index: int) -> void:
	var art: TextureRect = TextureRect.new()
	art.texture = _chapter_art(index)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	var fade: ShaderMaterial = ShaderMaterial.new()
	fade.shader = ART_FADE
	fade.set_shader_parameter("upper", SKY_COLORS[index])
	fade.set_shader_parameter("lower", SKY_COLORS[index])
	_art_layers[index] = art
	art.material = fade
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)




func _add_gap(upper: int) -> void:
	var gap: ColorRect = ColorRect.new()
	gap.custom_minimum_size.y = GAP_HEIGHT
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = GAP_SHADER
	material.set_shader_parameter("upper", SKY_COLORS[upper])
	material.set_shader_parameter("lower", SKY_COLORS[upper - 1])
	material.set_shader_parameter("waterway", upper in [1, 2, 5, 10, 11])
	gap.material = material
	_column.add_child(gap)

func _chapter_art(index: int) -> Texture2D:
	var chapter: Array = CHAPTERS[index]
	var folder: String = str(chapter[1])
	var directory: String = "saga_world" if folder.is_empty() else "%s_saga" % folder
	return load("res://prototype/%s/%s" % [directory, chapter[2]]) as Texture2D

func _mist(parent: Control, density: float) -> ColorRect:
	var cloud: ColorRect = ColorRect.new()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = CLOUDS
	material.set_shader_parameter("density", density)
	cloud.material = material
	cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cloud)
	cloud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return cloud


func _fit_cards() -> void:
	for card: Button in _cards:
		card.custom_minimum_size.y = size.y
	for art: TextureRect in _art_layers:
		var image_aspect: float = float(art.texture.get_width()) / art.texture.get_height()
		art.material.set_shader_parameter("aspect_scale", size.y * image_aspect / maxf(size.x, 1.0))


func _input(event: InputEvent) -> void:
	if not _started or not _scroll.visible or _transitioning:
		return
	if event is InputEventMouseButton and event.pressed and get_global_rect().has_point(event.position):
		var direction: int = 0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			direction = -1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			direction = 1
		if direction != 0:
			var bar: VScrollBar = _scroll.get_v_scroll_bar()
			if not _scroll_tween or not _scroll_tween.is_running():
				_scroll_target = bar.value
			else:
				_scroll_tween.kill()
			_scroll_target = clampf(_scroll_target + direction * size.y * 0.42, 0.0, bar.max_value - bar.page)
			_scroll_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_scroll_tween.tween_property(bar, "value", _scroll_target, 0.38)
			get_viewport().set_input_as_handled()


func _reveal_center(value: float) -> void:
	if not _started or size.y <= 0.0:
		return
	var index: int = CHAPTERS.size() - 1 - clampi(roundi(value / (size.y + GAP_HEIGHT)), 0, CHAPTERS.size() - 1)
	if index == 0 or _discovery.get_value("seen", str(index), false):
		return
	_discovery.set_value("seen", str(index), true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.test_saves"))
	_discovery.save(DISCOVERY_PATH)
	_captions[index].text = "%s fəslinə xoş gəldin!" % CHAPTERS[index][0]
	var reveal: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	reveal.tween_property(_clouds[index].material, "shader_parameter/density", 0.0, 1.1)
	reveal.tween_interval(1.5)
	reveal.tween_callback(_show_range.bind(index))


func _show_range(index: int) -> void:
	var chapter: Dictionary = ChapterPlan.DEMO_CHAPTERS[index]
	_captions[index].text = "Səviyyələr %d–%d" % [chapter["first"], chapter["last"]]


func _open_chapter(index: int) -> void:
	if _transitioning:
		return
	_transitioning = true
	_curtain.material.set_shader_parameter("tint", SKY_COLORS[index])
	var folder: String = CHAPTERS[index][1]
	var scene_path: String = "res://prototype/%s_saga/%s_saga.tscn" % [folder, folder]
	if folder.is_empty():
		scene_path = "res://prototype/saga_world/%s.tscn" % str(CHAPTERS[index][2]).trim_suffix("_road.png")
	var scene: PackedScene = load(scene_path)
	await _cover()
	_scroll.hide()
	_detail = scene.instantiate()
	add_child(_detail)
	if index < 5 and ChapterPlan.is_demo():
		_detail.connect("stop_chosen", _open_board.bind(index))
	var back: Button = Button.new()
	back.text = "← Dünya xəritəsi"
	back.position = Vector2(18, 12)
	back.custom_minimum_size = Vector2(180, 48)
	_detail.add_child(back)
	back.pressed.connect(_close_chapter)
	move_child(_curtain, -1)
	await _uncover()


func _open_board(stop: int, index: int) -> void:
	if _transitioning:
		return
	var chapter: Dictionary = ChapterPlan.DEMO_CHAPTERS[index]
	var level: Level = LevelCatalog.load_at(LevelCatalog.MAIN, int(chapter["first"]) + stop - 1)
	if level == null:
		return
	_transitioning = true
	await _cover()
	_detail.hide()
	_detail.process_mode = Node.PROCESS_MODE_DISABLED
	if _board_save == null:
		_board_save = SaveSystem.new("res://.test_saves/saga_board.json")
		_board_save.load_save()
	_board_frame = MarginContainer.new()
	add_child(_board_frame)
	_board_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_frame.resized.connect(_fit_board_safe_area)
	_fit_board_safe_area()
	var board: Control = BOARD_SCENE.instantiate()
	board.set_script(BOARD_SCRIPT)
	board.set("save_system", _board_save)
	board.connect("exit_requested", _close_board)
	_board_frame.add_child(board)
	board.call("start_level", level)
	move_child(_curtain, -1)
	await _uncover()


func _fit_board_safe_area() -> void:
	if not OS.has_feature("mobile"):
		return
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = get_window().size
	if safe.size.x <= 0 or safe.size.y <= 0 or window_size.x <= 0 or window_size.y <= 0:
		return
	var origin: Vector2i = get_window().position
	safe = safe.intersection(Rect2i(origin, window_size))
	if not safe.has_area():
		return
	var scale_to_board: Vector2 = _board_frame.size / Vector2(window_size)
	var start: Vector2 = Vector2(safe.position - origin) * scale_to_board
	var end: Vector2 = Vector2(origin + window_size - safe.end) * scale_to_board
	_board_frame.add_theme_constant_override("margin_left", maxi(0, ceili(start.x)))
	_board_frame.add_theme_constant_override("margin_top", maxi(0, ceili(start.y)))
	_board_frame.add_theme_constant_override("margin_right", maxi(0, ceili(end.x)))
	_board_frame.add_theme_constant_override("margin_bottom", maxi(0, ceili(end.y)))

func _close_board() -> void:
	if _transitioning:
		return
	_transitioning = true
	await _cover()
	_board_frame.queue_free()
	_board_frame = null
	_detail.process_mode = Node.PROCESS_MODE_INHERIT
	_detail.show()
	await _uncover()

func _close_chapter() -> void:
	if _transitioning:
		return
	_transitioning = true
	await _cover()
	_detail.queue_free()
	_detail = null
	_scroll.show()
	await _uncover()


func _cover() -> void:
	_curtain.show()
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	var transition: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	transition.tween_property(_curtain.material, "shader_parameter/density", 1.0, 0.26)
	await transition.finished


func _uncover() -> void:
	var transition: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	transition.tween_property(_curtain.material, "shader_parameter/density", 0.0, 0.42)
	await transition.finished
	_curtain.hide()
	_transitioning = false
