extends SceneTree

const AmbientAudio = preload("res://scripts/audio/ambient_audio.gd")
var _failed := false

func _initialize() -> void:
	_run_test.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true

func _check_rail(stream: AudioStreamWAV) -> void:
	_check(stream.format == AudioStreamWAV.FORMAT_16_BITS and not stream.stereo, "Rail sound must be mono 16-bit PCM")
	_check(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Rail sound must not loop")
	_check(stream.data.size() == int(AmbientAudio.SAMPLE_RATE * 0.65) * 2, "Rail sound must stay short")
	if stream.data.size() < 4:
		_check(false, "Rail sound must contain audio data")
		return
	var first := int(stream.data[0]) | (int(stream.data[1]) << 8)
	var last_index := stream.data.size() - 2
	var last := int(stream.data[last_index]) | (int(stream.data[last_index + 1]) << 8)
	_check(first == 0 and last == 0, "Rail sound must fade to silence at both endpoints")

func _run_test() -> void:
	_check(ProjectSettings.get_setting("audio/general/default_playback_type.web") == 0, "Web audio must use Stream playback for MP3 music")
	var music := AmbientAudio.make_music()
	_check(music is AudioStreamMP3, "Background music must load the produced MP3")
	_check(AmbientAudio.MUSIC_PATH == "res://assets/audio/lofi_metro_no_drums.mp3", "Background music must use the supplied no-drums soundtrack")
	_check(music.data.size() > 3_000_000 and music.data.size() < 3_500_000, "Full soundtrack must stay compressed below 3.5 MB")
	_check(absf(music.get_length() - 209.56) < 0.1, "Background music must retain the full-length supplied composition")
	_check(music.loop, "Background music must loop")
	_check_rail(AmbientAudio.make_rail())

	var audio := AmbientAudio.new()
	_check(audio.get("_music_volume") == 0.4 and audio.get("_effects_volume") == 0.0, "Music must retain its default and train effects must start muted")
	audio.set_music_volume(2.0)
	audio.set_effects_volume(-1.0)
	audio.set_night_factor(2.0)
	root.add_child(audio)
	await process_frame
	_check(audio.get("_music_volume") == 1.0 and audio.get("_effects_volume") == 0.0, "Volume setters must clamp to 0..1")
	_check(audio.get("_night_factor") == 1.0, "Night factor must clamp")
	audio.set_music_volume(0.0)
	var music_player: AudioStreamPlayer = audio.get("_music_player")
	_check(music_player.stream_paused or not music_player.playing, "Zero music volume must silence playback")
	audio.set_effects_volume(1.0)
	var rail_player: AudioStreamPlayer = audio.get("_rail_player")
	_check(rail_player.volume_db < 0.0, "Rail effects must be attenuated below the effects slider level")
	audio.play_arrival()
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
	print("Audio smoke: produced MP3 loading, looping, stream settings, quiet rail effect and lifecycle checked.")
	quit(1 if _failed else 0)
