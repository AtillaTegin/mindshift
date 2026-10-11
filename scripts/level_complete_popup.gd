class_name LevelCompletePopup
extends Control
## Level complete popup (spec 5.4): animated stars, time, moves against the
## minimum, and next / replay / level list buttons.

signal next_requested
signal replay_requested
signal levels_requested

const FADE_SECONDS: float = 0.2
const STAR_SECONDS: float = 0.25
## One-shot confetti burst when the popup opens (addendum 2.4).
const CONFETTI_AMOUNT: int = 70
const CONFETTI_COLORS: Array[Color] = [Color("f4b400"), Color("2a9d8f"), Color("e76f51"), Color("8ecae6"), Color("b388eb")]

var _star_count: int = 0
var _confetti: CPUParticles2D

@onready var _panel: Control = %Panel
@onready var _stars: Array[StarView] = [%Star1, %Star2, %Star3]
@onready var _time_label: Label = %TimeLabel
@onready var _moves_label: Label = %MovesLabel
@onready var _record_label: Label = %RecordLabel
@onready var _note_label: Label = %NoteLabel
@onready var _next_button: Button = %NextButton
@onready var _replay_button: Button = %ReplayButton
@onready var _levels_button: Button = %LevelsButton


func _ready() -> void:
	_next_button.pressed.connect(func() -> void: next_requested.emit())
	_replay_button.pressed.connect(func() -> void: replay_requested.emit())
	_levels_button.pressed.connect(func() -> void: levels_requested.emit())
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size * 0.5)
	_confetti = _make_confetti()
	add_child(_confetti)


func is_confetti_emitting() -> bool:
	return _confetti.emitting


## CPU particles (no GPU particles: simpler and safe on every phone).
func _make_confetti() -> CPUParticles2D:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = CONFETTI_AMOUNT
	particles.lifetime = 1.6
	particles.explosiveness = 0.95
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(160, 10)
	particles.direction = Vector2.UP
	particles.spread = 55.0
	particles.initial_velocity_min = 380.0
	particles.initial_velocity_max = 620.0
	particles.gravity = Vector2(0, 980)
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.scale_amount_min = 7.0
	particles.scale_amount_max = 12.0
	# Each piece takes a random point of this stepped gradient, i.e. one of the colours.
	var colors: Gradient = Gradient.new()
	colors.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets: PackedFloat32Array = PackedFloat32Array()
	for i: int in CONFETTI_COLORS.size():
		offsets.append(float(i) / CONFETTI_COLORS.size())
	colors.offsets = offsets
	colors.colors = PackedColorArray(CONFETTI_COLORS)
	particles.color_initial_ramp = colors
	return particles


func _burst_confetti() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	_confetti.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.42)
	_confetti.restart()
	_confetti.emitting = true


## Same text as the board's stopwatch showed when the level was solved.
static func format_time(seconds: float) -> String:
	return GameSession.format_clock(seconds)


## Fills in the result and plays the appear animation.
## `tokens_earned`: chest tokens for the stars gained (economy formulas v3).
func show_result(stars: int, moves: int, min_moves: int, seconds: float, improved: bool, has_next: bool,
		tokens_earned: int = 0) -> void:
	_time_label.text = tr("POPUP_TIME") % format_time(seconds)
	_moves_label.text = tr("POPUP_MOVES") % [moves, min_moves]
	var notes: PackedStringArray = PackedStringArray()
	if improved:
		notes.append(tr("POPUP_RECORD"))
	if tokens_earned > 0:
		notes.append(tr("POPUP_TOKENS") % tokens_earned)
	_record_label.text = "  ·  ".join(notes)
	_next_button.disabled = not has_next
	_next_button.text = tr("POPUP_NEXT") if has_next else tr("POPUP_LAST")
	visible = true
	modulate.a = 0.0
	_panel.scale = Vector2(0.85, 0.85)
	for star: StarView in _stars:
		star.filled = false
		star.scale = Vector2.ONE
	_burst_confetti()
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	tween.parallel().tween_property(_panel, "scale", Vector2.ONE, FADE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i: int in stars:
		var star: StarView = _stars[i]
		tween.tween_callback(func() -> void:
			star.filled = true
			star.scale = Vector2(0.3, 0.3))
		tween.tween_property(star, "scale", Vector2.ONE, STAR_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_star_count = stars


## An extra line under the result (e.g. the island just opened); "" hides it.
func set_note(text: String) -> void:
	_note_label.text = text
	_note_label.visible = not text.is_empty()


func get_note() -> String:
	return _note_label.text if _note_label.visible else ""


## Stars earned in the shown result (the animation fills them one by one).
func get_star_count() -> int:
	return _star_count
