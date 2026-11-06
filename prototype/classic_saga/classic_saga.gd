extends Control

signal stop_chosen(number: int)
## Isolated map composition and interaction preview.

const ISLAND: Texture2D = preload("res://prototype/classic_saga/benares.png")
const PORTAL_GATE: Texture2D = preload("res://prototype/classic_saga/benares_gate.png")
const WATER_SHADER: Shader = preload("res://prototype/classic_saga/waterfall.gdshader")
const FRAME: Vector2 = Vector2(720, 1280)
const DEFAULT_STOP_COUNT: int = 25
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

@export var demo_chapter_index: int = -1
@export var chapter_title: String = "KLASSİK"
@export var island_texture: Texture2D = ISLAND
@export var waypoints: PackedVector2Array = WAYPOINTS
@export var threshold: Vector2 = THRESHOLD
@export var embedded_gate: bool = false
@export var painted_road: bool = false
@export var pale_water: bool = false
@export var compass_stops: bool = false
@export var stop_face: Color = Color("#173d3c")
@export var stop_size: Vector2 = Vector2(62, 48)
## Fine adjustments along the road where a bend needs extra clearance.
@export var stop_offsets: PackedFloat32Array
## Sideways placement on broad landings, in scene pixels.
@export var stop_lanes: PackedFloat32Array
## Use one road anchor per numbered stop and draw the connecting line.
@export var linked_anchors: bool = false
@export var show_route_line: bool = false
@export var portal_core: Vector2 = THRESHOLD + Vector2(0, -63)
@export var portal_radius: float = 43.0
@export var portal_light: Color = Color("#65f9df")
@export_enum("Classic", "Pigment", "Orbit", "Rings", "Balance") var chapter_effect: int = 0
@export var portal_accent: Color = Color("#bb77ff")

var _frame: Control = Control.new()
var _map: Control
var _portal: Control = Control.new()
var _portal_time: float = 0.0
var _curve: Curve2D = Curve2D.new()
var _stops: Array[Button] = []
var _stop_count: int = DEFAULT_STOP_COUNT
var _caption: Label


func _ready() -> void:
	add_child(_frame)
	var island: TextureRect = TextureRect.new()
	island.texture = island_texture
	island.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	island.position = Vector2(0, 100)
	island.size = Vector2(720, 1080)
	island.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var water: ShaderMaterial = ShaderMaterial.new()
	water.shader = WATER_SHADER
	water.set_shader_parameter("pale_water", pale_water)
	island.material = water
	_frame.add_child(island)
	var map: Control = Control.new()
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(map)
	_map = map
	_map.draw.connect(_draw_map)
	_portal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_portal)
	_portal.draw.connect(_draw_portal)
	_curve.bake_interval = 2.0
	for i: int in range(waypoints.size()):
		var point: Vector2 = waypoints[i]
		var before: Vector2 = waypoints[maxi(0, i - 1)]
		var after: Vector2 = waypoints[mini(i + 1, waypoints.size() - 1)]
		var tangent: Vector2 = (after - before) / 6.0
		_curve.add_point(point, -tangent, tangent)

	if demo_chapter_index >= 0:
		var chapter: Dictionary = ChapterPlan.DEMO_CHAPTERS[demo_chapter_index]
		_stop_count = int(chapter["last"]) - int(chapter["first"]) + 1
	var stride: float = _curve.get_baked_length() / float(_stop_count - 1)
	var group: ButtonGroup = ButtonGroup.new()
	for index: int in range(_stop_count):
		var stop: Button = Button.new()
		stop.text = str(index + 1)
		stop.toggle_mode = true
		stop.button_group = group
		stop.add_theme_font_size_override("font_size", mini(24, int(stop_size.y) - 10))
		stop.add_theme_color_override("font_color", Color("#fff1cd"))
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			stop.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var disc: Control = Control.new()
		disc.show_behind_parent = true
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stop.add_child(disc)
		disc.draw.connect(_draw_medallion.bind(disc, stop, index == _stop_count - 1))
		stop.toggled.connect(func(_active: bool) -> void: disc.queue_redraw())
		stop.mouse_entered.connect(disc.queue_redraw)
		stop.mouse_exited.connect(disc.queue_redraw)
		stop.focus_entered.connect(disc.queue_redraw)
		stop.focus_exited.connect(disc.queue_redraw)
		stop.pressed.connect(_choose_stop.bind(index + 1))
		if chapter_effect > 0:
			stop.pressed.connect(_light_stop.bind(disc))
		_frame.add_child(stop)
		stop.size = stop_size
		var offset: float = stop_offsets[index] if stop_offsets.size() == _stop_count else 0.0
		var distance: float = stride * index + offset
		var center: Vector2 = waypoints[index] if linked_anchors and waypoints.size() == _stop_count else _curve.sample_baked(distance, true)
		if stop_lanes.size() == _stop_count and stop_lanes[index] != 0.0:
			var tangent: Vector2 = _curve.sample_baked(distance + 2.0, true) - _curve.sample_baked(distance - 2.0, true)
			center += tangent.normalized().orthogonal() * stop_lanes[index]
		stop.position = center - stop.size / 2.0
		_stops.append(stop)

	var title: Label = _label(chapter_title, 44, 38)
	title.add_theme_color_override("font_color", Color("#ffdb94"))
	_label("M I N D S H I F T   /   S A G A", 18, 13)
	_caption = _label("", 27, 1202)
	_label("%s XƏRİTƏ PİLOTU" % chapter_title, 14, 1244)
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
	if linked_anchors or show_route_line:
		var thread: PackedVector2Array = _curve.get_baked_points()
		_map.draw_polyline(thread, Color("#172031d9"), 9.0, true)
		_map.draw_polyline(thread, Color("#ffe9a8"), 4.0, true)
	if painted_road:
		return
	var road: PackedVector2Array = _curve.get_baked_points()
	road.append(threshold)
	var length: float = _curve.get_baked_length()
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



func _process(delta: float) -> void:
	_portal_time += delta
	_portal.queue_redraw()


func _draw_portal() -> void:
	if chapter_effect == 2:
		var flash: float = maxf(0.0, 1.0 - absf(fposmod(_portal_time, 11.0) - 5.0) * 9.0)
		if flash > 0.0:
			var bolt: PackedVector2Array = [Vector2(636, 101), Vector2(621, 120), Vector2(634, 124), Vector2(612, 151)]
			_portal.draw_polyline(bolt, Color(0.48, 0.69, 1.0, flash * 0.28), 8.0, true)
			_portal.draw_polyline(bolt, Color(0.77, 0.89, 1.0, flash * 0.65), 2.0, true)
	if not embedded_gate:
		var opening: PackedVector2Array = [
			Vector2(-44, 0), Vector2(-44, -79), Vector2(-36, -99),
			Vector2(-22, -113), Vector2(0, -118), Vector2(22, -113),
			Vector2(36, -99), Vector2(44, -79), Vector2(44, 0),
		]
		for index: int in range(opening.size()):
			opening[index] += threshold
		_portal.draw_set_transform(threshold, 0.0, Vector2(1.0, 0.15))
		_portal.draw_circle(Vector2.ZERO, 90.0, Color("#482b236b"), true, -1.0, true)
		_portal.draw_set_transform(Vector2.ZERO)
		_portal.draw_colored_polygon(opening, Color("#291341"))
	var pulse: float = 0.5 + 0.5 * sin(_portal_time * 2.4)
	var core: Vector2 = portal_core
	for radius: int in range(int(portal_radius), 0, -2):
		var intensity: float = pow(1.0 - float(radius) / (portal_radius + 2.0), 1.8)
		_portal.draw_circle(core, float(radius), Color("#231445").lerp(Color("#bcffec"), intensity), true, -1.0, true)
	for arm: int in range(3):
		var stream: PackedVector2Array = []
		for step: int in range(50):
			var t: float = float(step) / 49.0
			var angle: float = t * TAU * 1.15 + float(arm) * TAU / 3.0 - _portal_time * 1.7
			stream.append(core + Vector2.from_angle(angle) * (3.0 + t * (portal_radius - 5.0)))
		var hue: Color = portal_light if arm == 0 else portal_accent
		_portal.draw_polyline(stream, Color(hue, 0.22 + pulse * 0.12), 7.0, true)
		_portal.draw_polyline(stream, hue, 1.7, true)
	for index: int in range(12):
		var age: float = fposmod(float(index) / 12.0 + _portal_time * 0.6, 1.0)
		var angle: float = float(index) * 2.4 + age * 2.0
		var point: Vector2 = core + Vector2.from_angle(angle) * ((portal_radius - 3.0) * (1.0 - age))
		_portal.draw_circle(point, 1.1 + age, Color(0.8, 1.0, 0.96, sin(age * PI)), true, -1.0, true)
	if chapter_effect > 0:
		_draw_chapter_effect(core)
	if not embedded_gate:
		var gate_rect: Rect2 = Rect2(threshold + Vector2(-100, -150), Vector2(200, 152))
		_portal.draw_texture_rect(PORTAL_GATE, gate_rect, false)
	for width: int in [22, 12, 5]:
		var glow: Color = Color(portal_light, (0.3 + pulse * 0.14) * 5.0 / float(width))
		_portal.draw_line(threshold - Vector2(40, 0), threshold + Vector2(40, 0), glow, float(width), true)
	_portal.draw_line(threshold - Vector2(37, 0), threshold + Vector2(37, 0), Color("#eaffde"), 2.0, true)


func _draw_chapter_effect(core: Vector2) -> void:
	match chapter_effect:
		1:
			for side: float in [-1.0, 1.0]:
				for index: int in range(5):
					var age: float = fposmod(_portal_time * 0.65 + float(index) / 5.0, 1.0)
					var point: Vector2 = core + Vector2(side * portal_radius * 0.7, (0.65 - age * 1.3) * portal_radius)
					_portal.draw_circle(point, 2.0, Color(portal_accent, sin(age * PI)), true, -1.0, true)
		2:
			for index: int in range(3):
				var angle: float = _portal_time * 1.3 + float(index) * TAU / 3.0
				var offset: Vector2 = Vector2.from_angle(angle) * Vector2(0.85, 0.44) * portal_radius
				_portal.draw_circle(core + offset, 3.0, portal_light, true, -1.0, true)
		3:
			for index: int in range(9):
				var angle: float = float(index) * TAU / 9.0 - PI / 2.0
				var offset: Vector2 = Vector2.from_angle(angle) * (portal_radius - 4.0)
				var light: float = 0.25 + 0.75 * pow(0.5 + 0.5 * cos(angle - _portal_time * 3.0), 4.0)
				_portal.draw_arc(core + offset, 3.0, 0.0, TAU, 12, Color(portal_light, light), 1.4, true)


		4:
			var swing: float = sin(_portal_time * 1.65) * portal_radius * 0.22
			var left: Vector2 = core + Vector2(-portal_radius * 0.65, swing)
			var right: Vector2 = core + Vector2(portal_radius * 0.65, -swing)
			_portal.draw_line(left, right, Color(portal_accent, 0.65), 2.0, true)
			for pan: Vector2 in [left, right]:
				_portal.draw_arc(pan, 7.0, 0.0, PI, 16, portal_light, 2.5, true)


func _light_stop(disc: Control) -> void:
	disc.modulate = Color(1.55, 1.4, 1.2)
	var fade: Tween = create_tween()
	fade.tween_property(disc, "modulate", Color.WHITE, 0.32)


func _choose_stop(level: int) -> void:
	_select(level)
	stop_chosen.emit(level)


func _select(level: int) -> void:
	_caption.text = "%02d / %d    ·    %s" % [level, _stop_count, "Portal qapısı" if level == _stop_count else "Seçilmiş dayanacaq"]


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
	var face: Color = Color("#482b59") if portal else stop_face
	if stop.is_hovered():
		face = face.lightened(0.17)
	disc.draw_set_transform(center, 0.0, Vector2(1.0, minf(0.78, stop.size.y / 60.0)))
	disc.draw_circle(Vector2(0, 5), 25.0, Color("#27190fe0"), true, -1.0, true)
	disc.draw_circle(Vector2.ZERO, 25.0, metal, true, -1.0, true)
	disc.draw_circle(Vector2.ZERO, 22.0, Color("#8e582e"), true, -1.0, true)
	disc.draw_circle(Vector2.ZERO, 19.5, face, true, -1.0, true)
	disc.draw_arc(Vector2.ZERO, 22.0, PI + 0.25, TAU - 0.25, 28, Color("#fff1bc"), 1.4, true)
	if selected or stop.has_focus():
		disc.draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 40, Color("#91f5db"), 2.0, true)
	if compass_stops:
		for mark: int in range(12):
			var direction: Vector2 = Vector2.from_angle(float(mark) * TAU / 12.0)
			var inner: float = 17.0 if mark % 3 == 0 else 20.0
			disc.draw_line(direction * inner, direction * 23.0, Color("#b9e5ff"), 1.7, true)
		return
	for side: float in [-1.0, 1.0]:
		var stud: Vector2 = Vector2(22.0 * side, 0)
		disc.draw_colored_polygon(PackedVector2Array([
			stud + Vector2(0, -4), stud + Vector2(3, 0),
			stud + Vector2(0, 4), stud + Vector2(-3, 0),
		]), Color("#9debd2"))
