class_name SoundFx
extends RefCounted
## Sounds built in code (no audio files, like the code-drawn icons). For now
## only the "ding" of a coin landing from a chest (economy formulas v3.1).
## Callers play them only while the player's sound setting is on.

const MIX_RATE: int = 22050
## A bell-like ding: two partials (E6 and B6) with a fast attack and an
## exponential decay.
const DING_SECONDS: float = 0.45
const DING_PARTIALS: Array = [[1318.5, 0.6], [1975.5, 0.25], [2637.0, 0.1]]
const DING_DECAY: float = 9.0

static var _ding: AudioStreamWAV


static func ding() -> AudioStreamWAV:
	if _ding == null:
		_ding = _build(DING_SECONDS, DING_PARTIALS, DING_DECAY)
	return _ding


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
