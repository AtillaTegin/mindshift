extends Control
## Isolated map composition and interaction preview.

const ISLAND: Texture2D = preload("res://prototype/classic_saga/benares.png")
const WATER_SHADER: Shader = preload("res://prototype/classic_saga/waterfall.gdshader")
const FRAME: Vector2 = Vector2(720, 1280)
const STOP_COUNT: int = 25
const WATER_CROSSINGS: Array[float] = [9.5, 16.5]
const FIRST_STOP: Vector2 = Vector2(253, 803)
const LAST_STOP: Vector2 = Vector2(365, 269)
const THRESHOLD: Vector2 = Vector2(365, 242)
const WAYPOINTS: PackedVector2Array = [
	FIRST_STOP, Vector2(381, 784), Vector2(510, 738),
	Vector2(594, 700), Vector2(510, 650), Vector2(282, 644),
	Vector2(183, 628), Vector2(173, 593), Vector2(263, 551),
	Vector2(427, 526), Vector2(504, 496), Vector2(515, 453),
	Vector2(436, 425), Vector2(237, 462), Vector2(159, 443),
	Vector2(168, 373), Vector2(327, 350), Vector2(446, 322),
	LAST_STOP,
]

var _frame: Control = Control.new()
var _map: Control
var _curve: Curve2D = Curve2D.new()
var _stops: Array[Button] = []
var _caption: Label


func _ready() -> void:
	add_child(_frame)
	var island: TextureRect = TextureRect.new()
	island.texture = ISLAND
	island.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	island.position = Vector2(0, 100)
	island.size = Vector2(720, 1080)
	island.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var water: ShaderMaterial = ShaderMaterial.new()
	water.shader = WATER_SHADER
	island.material = water
	_frame.add_child(island)
	var map: Control = Control.new()
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(map)
	_map = map
	_map.draw.connect(_draw_map)
	_curve.bake_interval = 2.0
	for i: int in range(WAYPOINTS.size()):
		var point: Vector2 = WAYPOINTS[i]
		var before: Vector2 = WAYPOINTS[maxi(0, i - 1)]
		var after: Vector2 = WAYPOINTS[mini(i + 1, WAYPOINTS.size() - 1)]
		var tangent: Vector2 = (after - before) / 6.0
		_curve.add_point(point, -tangent, tangent)

	var stride: float = _curve.get_baked_length() / float(STOP_COUNT - 1)
	var group: ButtonGroup = ButtonGroup.new()
	for index: int in range(STOP_COUNT):
		var stop: Button = Button.new()
		stop.text = str(index + 1)
		stop.toggle_mode = true
		stop.button_group = group
		stop.size = Vector2(62, 48)
		stop.position = _curve.sample_baked(stride * index, true) - stop.size / 2.0
		stop.add_theme_font_size_override("font_size", 24)
		stop.add_theme_color_override("font_color", Color("#fff1cd"))
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			stop.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var disc: Control = Control.new()
		disc.show_behind_parent = true
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stop.add_child(disc)
		disc.draw.connect(_draw_medallion.bind(disc, stop, index == STOP_COUNT - 1))
		stop.toggled.connect(func(_active: bool) -> void: disc.queue_redraw())
		stop.mouse_entered.connect(disc.queue_redraw)
		stop.mouse_exited.connect(disc.queue_redraw)
		stop.focus_entered.connect(disc.queue_redraw)
		stop.focus_exited.connect(disc.queue_redraw)
		stop.pressed.connect(_select.bind(index + 1))
		_frame.add_child(stop)
		_stops.append(stop)

	var title: Label = _label("KLASSİK", 44, 38)
	title.add_theme_color_override("font_color", Color("#ffdb94"))
	_label("M I N D S H I F T   /   S A G A", 18, 13)
	_caption = _label("", 27, 1202)
	_label("KLASSİK XƏRİTƏ PİLOTU", 14, 1244)
	_stops[0].set_pressed_no_signal(true)
	_select(1)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	var zoom: float = minf(size.x / FRAME.x, size.y / FRAME.y)
	_frame.scale = Vector2.ONE * zoom
	_frame.position = (size - FRAME * zoom) * 0.5
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#181529"))


func _draw_map() -> void:
	_map.draw_rect(Rect2(0, 0, 720, 100), Color("#211a30"))
	_map.draw_rect(Rect2(0, 1180, 720, 100), Color("#211a30"))
	for edge: float in [99.0, 1180.0]:
		_map.draw_line(Vector2(0, edge), Vector2(720, edge), Color("#b57948"), 2.0)
	var road: PackedVector2Array = _curve.get_baked_points()
	road.append(THRESHOLD)
	var length: float = _curve.get_baked_length()
	for gap: float in WATER_CROSSINGS:
		_draw_channel(length * gap / float(STOP_COUNT - 1))
	_map.draw_polyline(road, Color("#542d265e"), 27.0, true)
	_map.draw_polyline(road, Color("#774b32"), 23.0, true)
	_map.draw_polyline(road, Color("#cd9763"), 20.0, true)
	_map.draw_polyline(road, Color("#ae784e"), 16.0, true)
	for offset: int in range(8, int(length) - 4, 15):
		var p: Vector2 = _curve.sample_baked(float(offset))
		var direction: Vector2 = (_curve.sample_baked(float(offset + 4)) - p).normalized()
		var cross: Vector2 = direction.orthogonal() * 8.0
		_map.draw_line(p - cross, p + cross, Color("#8d553e85"), 1.4, true)
		_map.draw_line(p - cross + direction, p + cross + direction, Color("#ffde9eb0"), 1.0, true)
	for gap: float in WATER_CROSSINGS:
		_draw_crossing(length * gap / float(STOP_COUNT - 1))
	_draw_portal()


func _draw_channel(distance: float) -> void:
	var center: Vector2 = _curve.sample_baked(distance)
	var along: Vector2 = (_curve.sample_baked(distance + 5.0) - center).normalized()
	var across: Vector2 = along.orthogonal()
	var channel: PackedVector2Array = []
	for step: int in range(-8, 9):
		var t: float = float(step) / 8.0
		channel.append(center + across * t * 52.0 + along * sin(t * PI) * 9.0)
	_map.draw_polyline(channel, Color("#543d32"), 29.0, true)
	_map.draw_polyline(channel, Color("#86704f"), 24.0, true)
	_map.draw_polyline(channel, Color("#0c535a"), 18.0, true)
	_map.draw_polyline(channel, Color("#31b4ad"), 11.0, true)
	_map.draw_polyline(channel, Color("#a4ebe0"), 2.0, true)


func _draw_crossing(distance: float) -> void:
	for index: int in range(-3, 4):
		var d: float = distance + float(index) * 6.0
		var center: Vector2 = _curve.sample_baked(d)
		var along: Vector2 = (_curve.sample_baked(d + 3.0) - center).normalized()
		var across: Vector2 = along.orthogonal() * 13.0
		_map.draw_line(center - across, center + across, Color("#754c35"), 6.0, true)
		_map.draw_line(center - across - along, center + across - along, Color("#ffe0a6"), 3.0, true)


func _draw_portal() -> void:
	var center: Vector2 = THRESHOLD + Vector2(0, -53)
	var arch: PackedVector2Array = [THRESHOLD + Vector2(-55, 0)]
	for step: int in range(49):
		var angle: float = PI + PI * float(step) / 48.0
		arch.append(center + Vector2.from_angle(angle) * 55.0)
	arch.append(THRESHOLD + Vector2(55, 0))
	var opening: PackedVector2Array = [THRESHOLD + Vector2(-45, 0)]
	for step: int in range(49):
		var angle: float = PI + PI * float(step) / 48.0
		opening.append(center + Vector2.from_angle(angle) * 45.0)
	opening.append(THRESHOLD + Vector2(45, 0))
	_map.draw_colored_polygon(opening, Color("#291341"))
	for radius: int in range(42, 0, -4):
		var ratio: float = 1.0 - float(radius) / 42.0
		_map.draw_circle(center + Vector2(0, 7), float(radius), Color("#39165f").lerp(Color("#faf0ff"), ratio * ratio), true, -1.0, true)
	for spiral: int in range(3):
		var glow: PackedVector2Array = []
		for step: int in range(64):
			var t: float = float(step) / 63.0
			glow.append(center + Vector2(0, 7) + Vector2.from_angle(t * TAU + spiral * TAU / 3.0) * (39.0 * t))
		_map.draw_polyline(glow, Color("#bd6dff88"), 6.0, true)
		_map.draw_polyline(glow, Color("#e9c2ff"), 1.5, true)
	_map.draw_polyline(arch, Color("#724027"), 24.0, true)
	_map.draw_polyline(arch, Color("#f2bd73"), 17.0, true)
	_map.draw_polyline(arch, Color("#a56639"), 7.0, true)
	for joint: int in range(13):
		var normal: Vector2 = Vector2.from_angle(PI + PI * float(joint) / 12.0)
		_map.draw_line(center + normal * 46.0, center + normal * 65.0, Color("#6a3d2b"), 2.0, true)
	var gem: Vector2 = center + Vector2(0, -55)
	_map.draw_colored_polygon(PackedVector2Array([
		gem + Vector2(0, -15), gem + Vector2(10, 0),
		gem + Vector2(0, 15), gem + Vector2(-10, 0),
	]), Color("#76f4e8"))
	_map.draw_line(THRESHOLD - Vector2(67, 0), THRESHOLD + Vector2(67, 0), Color("#ffe1a2"), 5.0, true)


func _select(level: int) -> void:
	_caption.text = "25 / 25    ·    Portal qapısı" if level == STOP_COUNT else "%02d / 25    ·    Seçilmiş dayanacaq" % level


func _label(value: String, font_size: int, top: float) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.position.y = top
	label.size.x = FRAME.x
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#f4dfc7"))
	_frame.add_child(label)
	return label


func _draw_medallion(disc: Control, stop: Button, portal: bool) -> void:
	var center: Vector2 = stop.size * 0.5
	var selected: bool = stop.button_pressed
	var metal: Color = Color("#ffe9a7") if selected else Color("#e2ae69")
	var face: Color = Color("#482b59") if portal else Color("#173d3c")
	if stop.is_hovered():
		face = face.lightened(0.17)
	disc.draw_set_transform(center, 0.0, Vector2(1.0, 0.78))
	disc.draw_circle(Vector2(0, 5), 25.0, Color("#27190fe0"), true, -1.0, true)
	disc.draw_circle(Vector2.ZERO, 25.0, metal, true, -1.0, true)
	disc.draw_circle(Vector2.ZERO, 22.0, Color("#8e582e"), true, -1.0, true)
	disc.draw_circle(Vector2.ZERO, 19.5, face, true, -1.0, true)
	disc.draw_arc(Vector2.ZERO, 22.0, PI + 0.25, TAU - 0.25, 28, Color("#fff1bc"), 1.4, true)
	if selected or stop.has_focus():
		disc.draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 40, Color("#91f5db"), 2.0, true)
	for side: float in [-1.0, 1.0]:
		var stud: Vector2 = Vector2(22.0 * side, 0)
		disc.draw_colored_polygon(PackedVector2Array([
			stud + Vector2(0, -4), stud + Vector2(3, 0),
			stud + Vector2(0, 4), stud + Vector2(-3, 0),
		]), Color("#9debd2"))
