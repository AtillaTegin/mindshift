class_name ChestOpening
extends Control
## The chest opening in the level popup (economy formulas addendum v3.1), in
## three stages, all code-drawn:
##   build:  the lid trembles harder and harder while a glow in the level's
##           dress colour pulses (gold on a classic level);
##   burst:  the lid flies open with a short radial flash and a few sparks;
##   result: with coins, a coin lights up over the chest and flies to the
##           board's coin counter, landing with a "ding". An empty chest (60%
##           of them) gets a gentle answer instead: a small dust puff, two
##           friendly hops and "nothing this time, keep going", never a
##           "you lost" look.
## Driven by `elapsed` (advance() steps it), so tests can check any moment.

signal coins_landed(coins: int)
signal finished

const BUILD_SECONDS: float = 0.9
const BURST_SECONDS: float = 0.35
const RISE_SECONDS: float = 0.35
const FLY_SECONDS: float = 0.55
const DUST_SECONDS: float = 0.9
const CHEST_SIZE: float = 120.0
const CAPTION_FONT_SIZE: int = 26
const RAYS: int = 12
const SPARKS: int = 18

## Coins inside (0: an empty chest).
var coins: int = 0
## Dress of the level the chest was opened on (ThemeManager.SKINS), "" for gold.
var skin: String = ""
## Where the coin flies to, in canvas (global) coordinates.
var coin_target: Vector2 = Vector2.ZERO
var sound_enabled: bool = true
## Seconds since play().
var elapsed: float = 0.0
var playing: bool = false
## Whether the ding was played (tests).
var ding_played: bool = false

var _landed: bool = false
var _sparked: bool = false
var _particles: CPUParticles2D
var _player: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(500, 230)
	_particles = CPUParticles2D.new()
	_particles.one_shot = true
	_particles.emitting = false
	_particles.amount = SPARKS
	_particles.lifetime = 0.7
	_particles.explosiveness = 1.0
	_particles.direction = Vector2.UP
	_particles.spread = 180.0
	_particles.initial_velocity_min = 120.0
	_particles.initial_velocity_max = 260.0
	_particles.gravity = Vector2(0, 300)
	_particles.scale_amount_min = 4.0
	_particles.scale_amount_max = 7.0
	add_child(_particles)
	_player = AudioStreamPlayer.new()
	_player.stream = SoundFx.ding()
	add_child(_player)
	set_process(false)


## Starts the opening of a chest with `p_coins` inside.
func play(p_coins: int, p_skin: String, p_coin_target: Vector2) -> void:
	coins = maxi(p_coins, 0)
	skin = p_skin
	coin_target = p_coin_target
	elapsed = 0.0
	playing = true
	ding_played = false
	_landed = false
	_sparked = false
	visible = true
	set_process(true)
	queue_redraw()


## Ends it at once (the player moved on). Coins still in the air land
## silently, so the counter never misses them.
func stop() -> void:
	if playing and coins > 0 and not _landed:
		_land(false)
	playing = false
	set_process(false)
	visible = false


func total_seconds() -> float:
	return BUILD_SECONDS + BURST_SECONDS + (RISE_SECONDS + FLY_SECONDS if coins > 0 else DUST_SECONDS)


## "idle", "build", "burst", "result" or "done".
func phase() -> String:
	if not playing and elapsed == 0.0:
		return "idle"
	if elapsed < BUILD_SECONDS:
		return "build"
	if elapsed < BUILD_SECONDS + BURST_SECONDS:
		return "burst"
	if elapsed < total_seconds():
		return "result"
	return "done"


func advance(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	if not _sparked and elapsed >= BUILD_SECONDS:
		_sparked = true
		_particles.position = _mouth()
		_particles.color = glow_color()
		_particles.restart()
		_particles.emitting = true
	if coins > 0 and not _landed and elapsed >= total_seconds():
		_land(sound_enabled)
	if elapsed >= total_seconds():
		playing = false
		set_process(false)
		finished.emit()
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func _land(with_sound: bool) -> void:
	_landed = true
	if with_sound:
		_player.play()
		ding_played = true
	coins_landed.emit(coins)


## The glow, flash and spark colour: the level's dress, gold for classic levels.
func glow_color() -> Color:
	return ThemeManager.skin_color(skin, "mark") if not skin.is_empty() else ThemeManager.icon_color("chest_band")


func is_sparking() -> bool:
	return _particles.emitting


## The line under the chest once it is open ("" before).
func get_caption() -> String:
	if phase() in ["idle", "build", "burst"]:
		return ""
	return tr("CHEST_COINS") % coins if coins > 0 else tr("CHEST_EMPTY")


## Lid rotation (radians, negative = opening): a growing tremble, then open.
func lid_angle() -> float:
	if elapsed < BUILD_SECONDS:
		return sin(elapsed * 42.0) * 0.07 * (elapsed / BUILD_SECONDS)
	return -1.1 * clampf((elapsed - BUILD_SECONDS) / (BURST_SECONDS * 0.5), 0.0, 1.0)


## Centre of the flying coin in local coordinates, or Vector2.INF when none shows.
func coin_position() -> Vector2:
	var since_open: float = elapsed - BUILD_SECONDS - BURST_SECONDS
	if coins == 0 or since_open < 0.0 or _landed:
		return Vector2.INF
	var top: Vector2 = _mouth() - Vector2(0.0, CHEST_SIZE * 0.45)
	if since_open < RISE_SECONDS:
		return _mouth().lerp(top, ease(since_open / RISE_SECONDS, 0.4))
	var target: Vector2 = get_global_transform().affine_inverse() * coin_target
	return top.lerp(target, ease(clampf((since_open - RISE_SECONDS) / FLY_SECONDS, 0.0, 1.0), 2.2))


## Strength of the dust puff (0 when none), for an empty chest.
func dust_amount() -> float:
	var since_open: float = elapsed - BUILD_SECONDS - BURST_SECONDS
	if coins > 0 or since_open < 0.0 or not playing and phase() == "done":
		return 0.0
	return 1.0 - clampf(since_open / DUST_SECONDS, 0.0, 1.0)


func _chest_center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5)


## Middle of the chest's open top.
func _mouth() -> Vector2:
	return _chest_center() + Vector2(0.0, -CHEST_SIZE * 0.12)


func _draw() -> void:
	if phase() == "idle":
		return
	var s: float = CHEST_SIZE
	var glow: Color = glow_color()
	var since_open: float = elapsed - BUILD_SECONDS - BURST_SECONDS
	# (a) build: a pulsing glow behind the chest.
	if elapsed < BUILD_SECONDS:
		var pulse: Color = glow
		pulse.a = 0.18 + 0.17 * (0.5 + 0.5 * sin(elapsed * 14.0))
		draw_circle(_chest_center(), s * 0.78, pulse, true, -1.0, true)
	# (b) burst: a flash and rays that shoot out and fade.
	elif since_open < 0.0:
		var k: float = (elapsed - BUILD_SECONDS) / BURST_SECONDS
		var flash: Color = glow
		flash.a = 0.45 * (1.0 - k)
		draw_circle(_mouth(), s * (0.5 + 0.6 * k), flash, true, -1.0, true)
		for i: int in RAYS:
			var direction: Vector2 = Vector2.UP.rotated(TAU * i / RAYS)
			var ray: Color = glow
			ray.a = 1.0 - k
			draw_line(_mouth() + direction * s * 0.3, _mouth() + direction * s * (0.55 + 0.75 * k), ray, 6.0, true)
	# Two friendly hops of an empty chest.
	var hop: float = 0.0
	if coins == 0 and since_open >= 0.0:
		var r: float = clampf(since_open / DUST_SECONDS, 0.0, 1.0)
		hop = -absf(sin(r * TAU)) * 10.0 * (1.0 - r)
	_draw_chest(_chest_center() + Vector2(0.0, hop), s)
	# (c) result.
	if dust_amount() > 0.0:
		_draw_dust(1.0 - dust_amount())
	var coin: Vector2 = coin_position()
	if coin != Vector2.INF:
		var flying: bool = since_open >= RISE_SECONDS
		var side: float = lerpf(s * 0.38, 34.0, clampf((since_open - RISE_SECONDS) / FLY_SECONDS, 0.0, 1.0)) if flying else s * 0.38
		var halo: Color = glow
		halo.a = 0.45 if not flying else 0.25
		draw_circle(coin, side * 0.85, halo, true, -1.0, true)
		GameIcons.draw(self, "coin", Rect2(coin - Vector2(side, side) * 0.5, Vector2(side, side)))
	_draw_caption()


func _draw_chest(center: Vector2, s: float) -> void:
	var wood: Color = ThemeManager.icon_color("chest")
	var band: Color = ThemeManager.icon_color("chest_band")
	var body: Rect2 = Rect2(center + Vector2(-s * 0.5, -s * 0.12), Vector2(s, s * 0.5))
	draw_rect(body, wood)
	for x: float in [0.14, 0.79]:
		draw_rect(Rect2(body.position + Vector2(s * x, 0.0), Vector2(s * 0.07, body.size.y)), band)
	draw_rect(Rect2(center + Vector2(-s * 0.08, -s * 0.12), Vector2(s * 0.16, s * 0.14)), band)
	# The lid turns around its back-left hinge.
	var hinge: Vector2 = body.position
	draw_set_transform(hinge, lid_angle())
	var lid: StyleBoxFlat = StyleBoxFlat.new()
	lid.bg_color = wood.lightened(0.12)
	lid.corner_radius_top_left = int(s * 0.16)
	lid.corner_radius_top_right = int(s * 0.16)
	draw_style_box(lid, Rect2(0.0, -s * 0.3, s, s * 0.3))
	for x: float in [0.14, 0.79]:
		draw_rect(Rect2(s * x, -s * 0.3, s * 0.07, s * 0.3), band)
	draw_set_transform(Vector2.ZERO)


## A few soft puffs drifting out of the open chest and fading.
func _draw_dust(r: float) -> void:
	var color: Color = ThemeManager.color("text_secondary")
	for i: int in 5:
		var direction: Vector2 = Vector2.UP.rotated(deg_to_rad(-60.0 + 30.0 * i))
		var puff: Color = color
		puff.a = 0.35 * (1.0 - r)
		draw_circle(_mouth() + direction * (12.0 + 46.0 * r), 9.0 + 12.0 * r, puff, true, -1.0, true)


func _draw_caption() -> void:
	var text: String = get_caption()
	if text.is_empty():
		return
	var since_open: float = elapsed - BUILD_SECONDS - BURST_SECONDS
	var color: Color = ThemeManager.color("success" if coins > 0 else "text_secondary")
	color.a = clampf(since_open / 0.3, 0.0, 1.0) if playing else 1.0
	var font: Font = get_theme_default_font()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_FONT_SIZE).x
	draw_string(font, Vector2((size.x - width) * 0.5, size.y - 8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			CAPTION_FONT_SIZE, color)
