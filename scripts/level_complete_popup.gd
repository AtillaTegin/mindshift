class_name LevelCompletePopup
extends Control
## Level complete popup (spec 5.4): animated stars, time, moves against the
## minimum, and next / replay / level list buttons.

signal next_requested
signal replay_requested
signal levels_requested

const FADE_SECONDS: float = 0.2
const STAR_SECONDS: float = 0.25

var _star_count: int = 0

@onready var _panel: Control = %Panel
@onready var _stars: Array[StarView] = [%Star1, %Star2, %Star3]
@onready var _time_label: Label = %TimeLabel
@onready var _moves_label: Label = %MovesLabel
@onready var _record_label: Label = %RecordLabel
@onready var _next_button: Button = %NextButton
@onready var _replay_button: Button = %ReplayButton
@onready var _levels_button: Button = %LevelsButton


func _ready() -> void:
	_next_button.pressed.connect(func() -> void: next_requested.emit())
	_replay_button.pressed.connect(func() -> void: replay_requested.emit())
	_levels_button.pressed.connect(func() -> void: levels_requested.emit())
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size * 0.5)


static func format_time(seconds: float) -> String:
	var whole: int = maxi(roundi(seconds), 0)
	return "%d:%02d" % [whole / 60, whole % 60]


## Fills in the result and plays the appear animation.
func show_result(stars: int, moves: int, min_moves: int, seconds: float, improved: bool, has_next: bool,
		coins_earned: int = 0) -> void:
	_time_label.text = "Vaxt: %s" % format_time(seconds)
	_moves_label.text = "Gediş: %d / min %d" % [moves, min_moves]
	var notes: PackedStringArray = PackedStringArray()
	if improved:
		notes.append("Yeni rekord!")
	if coins_earned > 0:
		notes.append("+%d coin" % coins_earned)
	_record_label.text = "  ·  ".join(notes)
	_next_button.disabled = not has_next
	_next_button.text = "Növbəti səviyyə" if has_next else "Son səviyyə"
	visible = true
	modulate.a = 0.0
	_panel.scale = Vector2(0.85, 0.85)
	for star: StarView in _stars:
		star.filled = false
		star.scale = Vector2.ONE
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


## Stars earned in the shown result (the animation fills them one by one).
func get_star_count() -> int:
	return _star_count
