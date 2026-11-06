extends SceneTree

const AmbientAudio = preload("res://scripts/audio/ambient_audio.gd")
var _failed := false

func _initialize() -> void:
	_run_test.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true

func _sample(data: PackedByteArray, index: int) -> float:
	var value := int(data[index * 2]) | (int(data[index * 2 + 1]) << 8)
	if value >= 32768:
		value -= 65536
	return float(value) / 32768.0

func _check_pcm(stream: AudioStreamWAV, label: String) -> void:
	_check(stream.format == AudioStreamWAV.FORMAT_16_BITS and not stream.stereo, label + ": expected mono 16-bit PCM")
	var data := stream.data
	var count := data.size() / 2
	var peak := 0.0
	var maximum_step := 0.0
	var previous := 0.0
	for index in range(count):
		var value := _sample(data, index)
		peak = maxf(peak, absf(value))
		maximum_step = maxf(maximum_step, absf(value - previous))
		previous = value
	_check(peak > 0.005 and peak < 0.8, label + ": PCM must be audible and safely below clipping")
	_check(maximum_step < 0.15, label + ": abrupt PCM discontinuity")
	_check(_sample(data, 0) == 0.0 and _sample(data, count - 1) == 0.0, label + ": endpoints must be silent")

func _run_test() -> void:
	var started := Time.get_ticks_msec()
	var music: AudioStreamWAV = AmbientAudio.make_music()
	var generation_ms := Time.get_ticks_msec() - started
	_check_pcm(music, "music")
	_check(music.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Music must loop natively")
	_check(music.loop_end == int(AmbientAudio.LOOP_SECONDS * AmbientAudio.SAMPLE_RATE), "Loop length must match PCM")
	_check(AmbientAudio.LOOP_SECONDS >= 30.0 and AmbientAudio.LOOP_SECONDS <= 60.0, "Expected a finite 30–60 second composition")
	var data := music.data
	var silent_samples := 0
	var longest_rest := 0
	var current_rest := 0
	for index in range(data.size() / 2):
		if _sample(data, index) == 0.0:
			silent_samples += 1
			current_rest += 1
			longest_rest = maxi(longest_rest, current_rest)
		else:
			current_rest = 0
	_check(silent_samples > AmbientAudio.SAMPLE_RATE * 5, "The composition needs substantial real rests")
	_check(longest_rest >= int(AmbientAudio.SAMPLE_RATE * 0.5), "Expected a breathing space of at least half a second")
	for index in range(int(AmbientAudio.SAMPLE_RATE * 0.2)):
		_check(_sample(data, index) == 0.0, "Loop opening must be silent")
		_check(_sample(data, music.loop_end - 1 - index) == 0.0, "Loop closing must be silent")
	var voice: PackedFloat32Array = AmbientAudio.render_note(72, 2.1)
	_check(voice[0] == 0.0 and voice[voice.size() - 1] == 0.0, "Notes need smooth attack and release endpoints")
	var attack_peak := 0.0
	var body_peak := 0.0
	var tail_peak := 0.0
	for index in range(voice.size()):
		if index < int(AmbientAudio.SAMPLE_RATE * 0.002):
			attack_peak = maxf(attack_peak, absf(voice[index]))
		elif index < int(AmbientAudio.SAMPLE_RATE * 0.2):
			body_peak = maxf(body_peak, absf(voice[index]))
		elif index >= voice.size() - int(AmbientAudio.SAMPLE_RATE * 0.2):
			tail_peak = maxf(tail_peak, absf(voice[index]))
	_check(attack_peak < body_peak * 0.1 and tail_peak < body_peak * 0.02, "Notes must attack gently and decay to silence")
	var events: Array[Dictionary] = AmbientAudio.composition_events()
	_check(events.size() > 24, "Music needs both harmony and a composed melody")
	var roots: Dictionary = {}
	for event: Dictionary in events:
		_check(int(event["note"]) >= 53, "No incessant sub-bass voices")
		if is_equal_approx(fmod(float(event["time"]), AmbientAudio.BAR_SECONDS), 0.3):
			roots[int(event["note"])] = true
	_check(roots.size() >= 3, "Harmony must change across the loop")
	var drums: Array[Dictionary] = AmbientAudio.drum_events()
	var kick_count := 0
	var snare_count := 0
	var hat_count := 0
	for event: Dictionary in drums:
		match String(event["kind"]):
			"kick":
				kick_count += 1
			"snare":
				snare_count += 1
				var beat := fposmod(float(event["time"]) - 0.3, AmbientAudio.BAR_SECONDS)
				_check(
					is_equal_approx(beat, AmbientAudio.BEAT_SECONDS)
					or is_equal_approx(beat, AmbientAudio.BEAT_SECONDS * 3.0),
					"Snare backbeats must land on beats two and four"
				)
			"hat":
				hat_count += 1
	_check(kick_count >= 20, "Music needs a steady kick pulse")
	_check(snare_count >= 20, "Music needs regular snare backbeats")
	_check(hat_count >= 40, "Music needs a swung hi-hat rhythm")
	var arrival: AudioStreamWAV = AmbientAudio.make_arrival(0.2, 0.0)
	var night_arrival: AudioStreamWAV = AmbientAudio.make_arrival(0.2, 1.0)
	var rail: AudioStreamWAV = AmbientAudio.make_rail()
	_check_pcm(arrival, "arrival")
	_check_pcm(night_arrival, "night arrival")
	_check_pcm(rail, "rail")
	_check(arrival.data != night_arrival.data, "Night arrivals should have a softer register")
	_check(arrival.loop_mode == AudioStreamWAV.LOOP_DISABLED and rail.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Effects must not loop")
	for hue_index in range(5):
		_check_pcm(AmbientAudio.make_arrival(float(hue_index) / 5.0, 0.0), "arrival hue %d" % hue_index)
		_check_pcm(AmbientAudio.make_arrival(float(hue_index) / 5.0, 1.0), "night arrival hue %d" % hue_index)
	var audio := AmbientAudio.new()
	_check(audio.get("_music_volume") == 0.55 and audio.get("_effects_volume") == 0.5, "Default volumes must match the UI")
	audio.set_music_volume(2.0)
	audio.set_effects_volume(-1.0)
	audio.set_night_factor(2.0)
	root.add_child(audio)
	await process_frame
	_check(audio.get("_music_volume") == 1.0 and audio.get("_effects_volume") == 0.0, "Volume setters must clamp to 0..1")
	_check(audio.get("_night_factor") == 1.0, "Night factor must clamp")
	audio.set_music_volume(0.0)
	var player: AudioStreamPlayer = audio.get("_music_player")
	_check(player.stream_paused or not player.playing, "Zero music volume must actually silence playback")
	audio.set_effects_volume(1.0)
	var rail_player: AudioStreamPlayer = audio.get("_rail_player")
	var chime_player: AudioStreamPlayer = audio.get("_chime_player")
	_check(rail_player.volume_db < chime_player.volume_db, "Rail effects must sit below the softened arrival chime")
	_check(chime_player.volume_db < 0.0, "Arrival chimes must be attenuated below the effects slider level")
	audio.play_arrival(0.8, 1.0)
	if DisplayServer.get_name() == "headless":
		for child: Node in audio.get_children():
			if child is AudioStreamPlayer:
				_check(not (child as AudioStreamPlayer).playing, "Headless mode must never start playback")
	root.remove_child(audio)
	for child: Node in audio.get_children():
		if child is AudioStreamPlayer:
			_check(not (child as AudioStreamPlayer).playing and (child as AudioStreamPlayer).stream == null, "Exiting must stop and release every stream")
	audio.queue_free()
	await process_frame
	print("Audio smoke: 48s original PCM generated in %d ms; amplitude, rests, envelopes, looping, effects and lifecycle checked." % generation_ms)
	quit(1 if _failed else 0)
