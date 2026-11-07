extends Node

const SAMPLE_RATE := 22050
const LOOP_SECONDS := 48.0
const TEMPO_BPM := 80.0
const BEAT_SECONDS := 60.0 / TEMPO_BPM
const BAR_SECONDS := BEAT_SECONDS * 4.0
const RAIL_EFFECT_GAIN := 0.3
const CHIME_EFFECT_GAIN := 0.6

static var _cached_music: AudioStreamWAV
static var _cached_rail: AudioStreamWAV
static var _cached_arrivals: Dictionary = {}

var _music_player: AudioStreamPlayer
var _rail_player: AudioStreamPlayer
var _chime_player: AudioStreamPlayer
var _music_volume := 0.4
var _effects_volume := 0.5
var _night_factor := 0.0

func _ready() -> void:
	_music_player = _make_player()
	_rail_player = _make_player()
	_chime_player = _make_player()
	_apply_volumes()
	# Headless runs exercise synthesis explicitly, never the audio backend.
	if DisplayServer.get_name() == "headless":
		return
	if _cached_music == null:
		_cached_music = make_music()
	if _cached_rail == null:
		_cached_rail = make_rail()
	_music_player.stream = _cached_music
	_rail_player.stream = _cached_rail
	if _music_volume > 0.0:
		_music_player.play()

func _exit_tree() -> void:
	var had_playback := false
	for player: AudioStreamPlayer in [_music_player, _rail_player, _chime_player]:
		if player != null:
			had_playback = had_playback or player.has_stream_playback()
			player.stop()
			player.stream = null
	# AudioServer retires stopped playback on its mixer thread, not in stop().
	# Give it two buffers before an immediate scene shutdown can stop the driver.
	if had_playback and DisplayServer.get_name() != "headless":
		var mix_seconds := 512.0 / AudioServer.get_mix_rate()
		var drain_ms := ceili(1000.0 * (maxf(AudioServer.get_time_to_next_mix(), 0.0) + mix_seconds * 2.0))
		OS.delay_msec(clampi(drain_ms, 1, 100))

func set_night_factor(amount: float) -> void:
	_night_factor = clampf(amount, 0.0, 1.0)
	_apply_volumes()

func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()

func set_effects_volume(value: float) -> void:
	_effects_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()

func play_arrival(hue: float, night_factor: float) -> void:
	if DisplayServer.get_name() == "headless" or _chime_player == null or _effects_volume <= 0.0:
		return
	var note_index := posmod(roundi(hue * 5.0), 5)
	var night := night_factor > 0.5
	var key := note_index + (5 if night else 0)
	if not _cached_arrivals.has(key):
		_cached_arrivals[key] = make_arrival(float(note_index) / 5.0, night_factor)
	_chime_player.stream = _cached_arrivals[key] as AudioStreamWAV
	_chime_player.play()
	_rail_player.play()

func _make_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = "Master"
	add_child(player)
	return player

func _apply_volumes() -> void:
	if _music_player != null:
		_music_player.volume_db = linear_to_db(maxf(_music_volume * lerpf(0.8, 0.62, _night_factor), 0.0001))
		_music_player.stream_paused = _music_volume <= 0.0
		if _music_volume > 0.0 and _music_player.stream != null and not _music_player.playing and DisplayServer.get_name() != "headless":
			_music_player.play()
	for player: AudioStreamPlayer in [_rail_player, _chime_player]:
		if player != null:
			if _effects_volume <= 0.0:
				player.stop()
	if _rail_player != null:
		_rail_player.volume_db = linear_to_db(maxf(_effects_volume * RAIL_EFFECT_GAIN, 0.0001))
	if _chime_player != null:
		_chime_player.volume_db = linear_to_db(maxf(_effects_volume * CHIME_EFFECT_GAIN, 0.0001))

# Original sixteen-bar lo-fi groove: a consonant eight-bar progression repeats
# over a steady swung kick/snare pulse, with sparse melody and muted hats.
# Events are public so tests/tools can inspect the score without decoding PCM.
static func composition_events() -> Array[Dictionary]:
	var voicings: Array[PackedInt32Array] = [
		PackedInt32Array([60, 64, 67, 71]), PackedInt32Array([57, 60, 64, 67]),
		PackedInt32Array([62, 65, 69, 72]), PackedInt32Array([55, 59, 62, 65]),
		PackedInt32Array([59, 62, 64, 67]), PackedInt32Array([57, 60, 64, 67]),
		PackedInt32Array([53, 57, 60, 64]), PackedInt32Array([55, 60, 62, 67]),
	]
	var melody := PackedInt32Array([76, 79, 74, 72, 71, 69, 72, 74])
	var events: Array[Dictionary] = []
	for bar in range(16):
		var score_bar := bar % voicings.size()
		var start := float(bar) * BAR_SECONDS + 0.3
		for voice_index in range(voicings[score_bar].size()):
			events.append({
				"time": start + float(voice_index) * 0.035,
				"note": voicings[score_bar][voice_index], "duration": 1.9, "gain": 0.08,
			})
		if bar % 2 == 0:
			events.append({
				"time": start + 1.45, "note": melody[score_bar],
				"duration": 0.9, "gain": 0.045,
			})
	return events

static func drum_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for bar in range(16):
		var start := float(bar) * BAR_SECONDS + 0.3
		for beat in [0.0, 2.0]:
			events.append({"time": start + beat * BEAT_SECONDS, "kind": "kick", "gain": 0.8})
		for beat in [1.0, 3.0]:
			events.append({"time": start + beat * BEAT_SECONDS, "kind": "snare", "gain": 0.34})
		var eighth_count := 6 if bar == 15 else 8
		for eighth in range(eighth_count):
			var swing := 0.045 if eighth % 2 == 1 else 0.0
			var accent := 0.075 if eighth % 2 == 0 else 0.045
			events.append({
				"time": start + float(eighth) * BEAT_SECONDS * 0.5 + swing,
				"kind": "hat", "gain": accent,
			})
		if bar % 4 == 3 and bar < 15:
			events.append({
				"time": start + 3.5 * BEAT_SECONDS, "kind": "kick", "gain": 0.34,
			})
		if bar % 2 == 1:
			events.append({
				"time": start + 2.75 * BEAT_SECONDS, "kind": "ghost", "gain": 0.1,
			})
	return events

static func make_music() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(SAMPLE_RATE * LOOP_SECONDS))
	var voices: Dictionary = {}
	for event: Dictionary in composition_events():
		var note := int(event["note"])
		var duration := float(event["duration"])
		var key := "%d:%.1f" % [note, duration]
		if not voices.has(key):
			voices[key] = render_music_note(note, duration)
		var voice: PackedFloat32Array = voices[key]
		_mix_voice(samples, voice, int(float(event["time"]) * SAMPLE_RATE), float(event["gain"]))
	var drums := {
		"kick": render_kick(),
		"snare": render_snare(),
		"ghost": render_snare(),
		"hat": render_hat(),
	}
	for event: Dictionary in drum_events():
		var voice: PackedFloat32Array = drums[String(event["kind"])]
		_mix_voice(samples, voice, int(float(event["time"]) * SAMPLE_RATE), float(event["gain"]))
	return _make_pcm(samples, true)

# A soft Rhodes-like tine over a mellow fundamental avoids the brittle edge of
# the simpler sine-rich voice used for short interface chimes.
static func render_music_note(note: int, duration: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var count := maxi(2, int(SAMPLE_RATE * maxf(duration, 0.02)))
	samples.resize(count)
	var frequency := 440.0 * pow(2.0, float(note - 69) / 12.0)
	var step := TAU * frequency / SAMPLE_RATE
	var second_step := step * 2.01
	var third_step := step * 4.0
	var fundamental_step_sine := sin(step)
	var fundamental_step_cosine := cos(step)
	var second_step_sine := sin(second_step)
	var second_step_cosine := cos(second_step)
	var third_step_sine := sin(third_step)
	var third_step_cosine := cos(third_step)
	var fundamental_sine := 0.0
	var fundamental_cosine := 1.0
	var second_sine := 0.0
	var second_cosine := 1.0
	var third_sine := 0.0
	var third_cosine := 1.0
	var fundamental_decay := 1.0
	var tine_decay := 1.0
	var fundamental_decay_step := exp(-0.9 / SAMPLE_RATE)
	var tine_decay_step := exp(-5.0 / SAMPLE_RATE)
	var attack_count := maxi(1, int(0.008 * SAMPLE_RATE))
	var release_count := maxi(1, mini(int(0.18 * SAMPLE_RATE), count / 2))
	for index in range(count):
		var attack := clampf(float(index) / attack_count, 0.0, 1.0)
		var release := clampf(float(count - 1 - index) / release_count, 0.0, 1.0)
		var envelope := attack * attack * (3.0 - 2.0 * attack)
		envelope *= release * release * (3.0 - 2.0 * release)
		samples[index] = (
			fundamental_sine * 0.78 * fundamental_decay
			+ second_sine * 0.18 * tine_decay
			+ third_sine * 0.04 * tine_decay
		) * envelope
		var next_sine := fundamental_sine * fundamental_step_cosine + fundamental_cosine * fundamental_step_sine
		fundamental_cosine = fundamental_cosine * fundamental_step_cosine - fundamental_sine * fundamental_step_sine
		fundamental_sine = next_sine
		next_sine = second_sine * second_step_cosine + second_cosine * second_step_sine
		second_cosine = second_cosine * second_step_cosine - second_sine * second_step_sine
		second_sine = next_sine
		next_sine = third_sine * third_step_cosine + third_cosine * third_step_sine
		third_cosine = third_cosine * third_step_cosine - third_sine * third_step_sine
		third_sine = next_sine
		fundamental_decay *= fundamental_decay_step
		tine_decay *= tine_decay_step
	return samples

static func render_kick() -> PackedFloat32Array:
	var count := int(SAMPLE_RATE * 0.32)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for index in range(count):
		var progress := float(index) / float(count - 1)
		var frequency := lerpf(145.0, 58.0, progress)
		phase += TAU * frequency / SAMPLE_RATE
		var envelope := exp(-6.0 * progress) * sin(PI * progress)
		samples[index] = (sin(phase) + sin(phase * 2.0) * 0.18) * envelope
	return samples

static func render_snare() -> PackedFloat32Array:
	var count := int(SAMPLE_RATE * 0.22)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var seed_value := 149
	var filtered := 0.0
	var phase := 0.0
	for index in range(count):
		seed_value = (seed_value * 1664525 + 1013904223) & 0xffffffff
		var noise := float(seed_value & 0xffff) / 32767.5 - 1.0
		filtered += (noise - filtered) * 0.1
		var progress := float(index) / float(count - 1)
		var envelope := exp(-8.0 * progress) * sin(PI * progress)
		phase += TAU * 185.0 / SAMPLE_RATE
		samples[index] = (filtered * 0.55 + (noise - filtered) * 0.15 + sin(phase) * 0.3) * envelope
	return samples

static func render_hat() -> PackedFloat32Array:
	var count := int(SAMPLE_RATE * 0.055)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var seed_value := 827
	var previous_noise := 0.0
	for index in range(count):
		seed_value = (seed_value * 1664525 + 1013904223) & 0xffffffff
		var noise := float(seed_value & 0xffff) / 32767.5 - 1.0
		var progress := float(index) / float(count - 1)
		var envelope := exp(-32.0 * progress) * sin(PI * progress)
		previous_noise += (noise - previous_noise) * 0.12
		samples[index] = previous_noise * envelope
	return samples

# Recurrence oscillators and a multiplicative decay avoid per-sample trig/exp.
# Only short, reusable notes are synthesized; the 48-second PCM plays natively.
static func render_note(note: int, duration: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var count := maxi(2, int(SAMPLE_RATE * maxf(duration, 0.02)))
	samples.resize(count)
	var frequency := 440.0 * pow(2.0, float(note - 69) / 12.0)
	var step := TAU * frequency / SAMPLE_RATE
	var step_sine := sin(step)
	var step_cosine := cos(step)
	var oscillator_sine := 0.0
	var oscillator_cosine := 1.0
	var decay := 1.0
	var decay_step := exp(-3.0 / SAMPLE_RATE)
	var attack_count := maxi(1, int(0.025 * SAMPLE_RATE))
	var release_count := maxi(1, mini(int(0.35 * SAMPLE_RATE), count / 2))
	for index in range(count):
		var attack := clampf(float(index) / attack_count, 0.0, 1.0)
		var release := clampf(float(count - 1 - index) / release_count, 0.0, 1.0)
		var envelope := attack * attack * (3.0 - 2.0 * attack)
		envelope *= release * release * (3.0 - 2.0 * release) * decay
		var second := 2.0 * oscillator_sine * oscillator_cosine
		var third := 3.0 * oscillator_sine - 4.0 * oscillator_sine * oscillator_sine * oscillator_sine
		samples[index] = (oscillator_sine * 0.78 + second * 0.16 + third * 0.06) * envelope
		var next_sine := oscillator_sine * step_cosine + oscillator_cosine * step_sine
		oscillator_cosine = oscillator_cosine * step_cosine - oscillator_sine * step_sine
		oscillator_sine = next_sine
		decay *= decay_step
	return samples

static func make_arrival(hue: float, night_factor: float) -> AudioStreamWAV:
	var notes := PackedInt32Array([0, 2, 4, 7, 9])
	var offset := notes[posmod(roundi(hue * 5.0), notes.size())]
	var base := (60 if night_factor > 0.5 else 65) + offset
	var samples := PackedFloat32Array()
	samples.resize(int(SAMPLE_RATE * 1.35))
	_mix_voice(samples, render_music_note(base, 1.0), int(0.03 * SAMPLE_RATE), 0.12)
	_mix_voice(samples, render_music_note(base + 3, 0.9), int(0.24 * SAMPLE_RATE), 0.06)
	return _make_pcm(samples, false)

static func make_rail() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := int(SAMPLE_RATE * 0.65)
	samples.resize(count)
	var seed_value := 731
	var filtered := 0.0
	for index in range(count):
		seed_value = (seed_value * 1664525 + 1013904223) & 0xffffffff
		var noise := float(seed_value & 0xffff) / 32767.5 - 1.0
		filtered += (noise - filtered) * 0.04
		var progress := float(index) / float(count - 1)
		var envelope := sin(PI * progress)
		samples[index] = filtered * envelope * envelope * 0.08
	# Explicit zeros make even the short effects safe to stop or repeat.
	samples[0] = 0.0
	samples[count - 1] = 0.0
	return _make_pcm(samples, false)

static func _mix_voice(samples: PackedFloat32Array, voice: PackedFloat32Array, start: int, gain: float) -> void:
	for index in range(voice.size()):
		var destination := start + index
		if destination >= samples.size():
			break
		if destination >= 0:
			samples[destination] += voice[index] * gain

static func _make_pcm(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	stream.loop_begin = 0
	stream.loop_end = samples.size()
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for index in range(samples.size()):
		var value := roundi(clampf(samples[index], -1.0, 1.0) * 32767.0)
		data[index * 2] = value & 0xff
		data[index * 2 + 1] = (value >> 8) & 0xff
	stream.data = data
	return stream
