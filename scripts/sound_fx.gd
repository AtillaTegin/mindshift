class_name SoundFx
extends RefCounted
## Sounds built in code (no audio files, like the code-drawn icons): the
## "ding" of a coin landing from a chest (economy formulas v3.1) and the
## balance scale's "tık" and bell.
## Callers play them only while the player's sound setting is on.

const MIX_RATE: int = 22050
## A bell-like ding: two partials (E6 and B6) with a fast attack and an
## exponential decay.
const DING_SECONDS: float = 0.45
const DING_PARTIALS: Array = [[1318.5, 0.6], [1975.5, 0.25], [2637.0, 0.1]]
const DING_DECAY: float = 9.0

## The balance scale (Fəsil Sistemi v1.2, 5.3): a short dry "tık" when a move
## is refused, and a soft low bell when the level is solved.
const TICK_SECONDS: float = 0.06
const TICK_PARTIALS: Array = [[2400.0, 0.5], [3700.0, 0.25]]
const TICK_DECAY: float = 90.0
const BELL_SECONDS: float = 1.4
const BELL_PARTIALS: Array = [[784.0, 0.35], [1568.0, 0.12], [2352.0, 0.05]]
const BELL_DECAY: float = 3.2

static var _ding: AudioStreamWAV
static var _tick: AudioStreamWAV
static var _bell: AudioStreamWAV


static func ding() -> AudioStreamWAV:
	if _ding == null:
		_ding = _build(DING_SECONDS, DING_PARTIALS, DING_DECAY)
	return _ding


static func tick() -> AudioStreamWAV:
	if _tick == null:
		_tick = _build(TICK_SECONDS, TICK_PARTIALS, TICK_DECAY)
	return _tick


static func bell() -> AudioStreamWAV:
	if _bell == null:
		_bell = _build(BELL_SECONDS, BELL_PARTIALS, BELL_DECAY)
	return _bell


## 16-bit mono PCM of summed sine partials ([frequency, amplitude]) under one envelope.
static func _build(seconds: float, partials: Array, decay: float) -> AudioStreamWAV:
	var count: int = int(seconds * MIX_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var time: float = float(i) / MIX_RATE
		var envelope: float = minf(time / 0.005, 1.0) * exp(-decay * time)
		var value: float = 0.0
		for partial: Array in partials:
			value += sin(TAU * partial[0] * time) * partial[1]
		data.encode_s16(i * 2, int(clampf(value * envelope, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
