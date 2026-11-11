extends Node

const SAMPLE_RATE := 22050
const MUSIC_PATH := "res://assets/audio/lofi_metro_no_drums.mp3"
const RAIL_EFFECT_GAIN := 0.3

static var _cached_music: AudioStreamMP3
static var _cached_rail: AudioStreamWAV

var _music_player: AudioStreamPlayer
var _rail_player: AudioStreamPlayer
var _music_volume := 0.4
var _effects_volume := 0.0
var _night_factor := 0.0

func _ready() -> void:
	_music_player = _make_player()
	_rail_player = _make_player()
	_apply_volumes()
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
	for player: AudioStreamPlayer in [_music_player, _rail_player]:
		if player != null:
			had_playback = had_playback or player.has_stream_playback()
			player.stop()
			player.stream = null
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

func play_arrival() -> void:
	if DisplayServer.get_name() == "headless" or _rail_player == null or _effects_volume <= 0.0:
		return
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
	if _rail_player != null:
		if _effects_volume <= 0.0:
			_rail_player.stop()
		_rail_player.volume_db = linear_to_db(maxf(_effects_volume * RAIL_EFFECT_GAIN, 0.0001))

static func make_music() -> AudioStreamMP3:
	var stream := load(MUSIC_PATH) as AudioStreamMP3
	stream.loop = true
	return stream

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
	samples[0] = 0.0
	samples[count - 1] = 0.0
	return _make_pcm(samples, false)

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
