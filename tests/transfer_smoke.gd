extends SceneTree

const TEST_FILE := "user://metro-transfer-smoke.json"
var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("startup_layout_enabled", false)
	root.add_child(main)
	main.set_process(false)
	root.content_scale_factor = 1.0
	root.size = Vector2i(1180, 740)
	await process_frame
	var store := LayoutStore.new()
	var transfer: Node = main.get("_layout_transfer")
	for path: String in LayoutStore.BUNDLED_LAYOUTS:
		main.call("_replace_layout", store.load_bundled_layout(path), true)
		var graph: TransitGraph = main.get("graph")
		var lines: Array[TransitLine] = main.get("lines")
		var camera: Camera2D = main.get("camera")
		var snapshot := store.capture(graph, lines, main.get("active_line").id, camera.position, camera.zoom.x)
		main.get("_export_layout_button").pressed.emit()
		_check(not transfer.get("_export_buffer").is_empty(), "Menu Export must prepare a complete JSON file.")
		transfer.get("_dialog").hide()
		transfer.call("_on_file_selected", ProjectSettings.globalize_path(TEST_FILE))
		var imported := store.read_layout_file(TEST_FILE)
		_check(not imported.is_empty() and store.capture(imported["graph"], imported["lines"], imported["active_line"], imported["camera"], imported["zoom"]) == snapshot, "External file must round-trip every layout setting, topology, factual name and camera: " + path)
		main.get("_import_layout_button").pressed.emit()
		transfer.get("_dialog").hide()
		transfer.call("_on_file_selected", ProjectSettings.globalize_path(TEST_FILE))
		_check(main.get("_layout_dialog").visible and main.get("graph") == graph, "Menu Import must validate then ask before replacing the live map.")
		main.get("_layout_dialog").canceled.emit()
		main.get("_layout_dialog").hide()
		_check(main.get("graph") == graph and main.get("_pending_import").is_empty(), "Canceled import must preserve the live map and discard pending content.")
		transfer.call("_on_file_selected", ProjectSettings.globalize_path(TEST_FILE))
		main.set("paused", true)
		main.get("_layout_dialog").hide()
		main.get("_layout_dialog").confirmed.emit()
		_check(main.get("graph") != graph and main.get("graph").stations.size() == graph.stations.size() and main.get("paused"), "Confirmed import must install an editable auto-fitted network while preserving pause.")
		var restored_snapshot := store.capture(main.get("graph"), main.get("lines"), main.get("active_line").id, camera.position, camera.zoom.x)
		_check(restored_snapshot == snapshot, "Import must preserve presets and deterministic fitted framing.")
	var live_graph: TransitGraph = main.get("graph")
	for text: String in ["{broken", "[]", "{\"version\":999}", "{}"]:
		var file := FileAccess.open(TEST_FILE, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		transfer.call("_on_file_selected", ProjectSettings.globalize_path(TEST_FILE))
		_check(main.get("graph") == live_graph and not main.get("_layout_dialog").visible and main.get("_status_seconds") > 0, "Invalid external files must show an error without replacing the map.")
	var oversized := PackedByteArray()
	oversized.resize(LayoutStore.MAX_FILE_BYTES + 1)
	_check(store.decode_layout(oversized).is_empty() and not store.error_message.is_empty(), "Imported files must enforce the exact 16 MiB limit.")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://layouts/metro_demo.json"))
	var bad: Dictionary
	for mutation: String in ["stations", "tracks", "lines", "coordinates", "duplicates", "waypoints", "fleet", "short_track", "backtrack", "control_name"]:
		bad = fixture.duplicate(true)
		match mutation:
			"stations": bad["stations"].resize(LayoutStore.MAX_STATIONS + 1)
			"tracks": bad["tracks"].resize(LayoutStore.MAX_TRACKS + 1)
			"lines": bad["lines"].resize(LayoutStore.MAX_LINES + 1)
			"coordinates": bad["stations"][0][0] = LayoutStore.MAX_COORDINATE + 48
			"duplicates": bad["stations"][1] = bad["stations"][0].duplicate()
			"waypoints": bad["tracks"][0]["waypoints"].resize(LayoutStore.MAX_TRACK_POINTS + 1)
			"fleet":
				bad["lines"].clear()
				for index in range(5):
					var line: Dictionary = fixture["lines"][0].duplicate(true)
					line["max_trains"] = 16
					bad["lines"].append(line)
			"short_track":
				bad["stations"][1] = [bad["stations"][0][0] + 48, bad["stations"][0][1]]
				for track: Dictionary in bad["tracks"]:
					track["waypoints"] = []
			"backtrack":
				var a: Array = bad["stations"][bad["tracks"][0]["a"]]
				var b: Array = bad["stations"][bad["tracks"][0]["b"]]
				bad["tracks"][0]["waypoints"] = [a, [a[0] + 48, a[1]], a, b]
			"control_name":
				bad["station_names"] = []
				for index in range(bad["stations"].size()):
					bad["station_names"].append("bad\tname")
		_check(store.restore(bad).is_empty() and not store.error_message.is_empty(), "Untrusted " + mutation + " must be rejected before geometry/simulation setup.")
	var deep := ("[".repeat(LayoutStore.MAX_JSON_DEPTH + 1) + "]".repeat(LayoutStore.MAX_JSON_DEPTH + 1)).to_utf8_buffer()
	var many := ("[" + "0,".repeat(LayoutStore.MAX_JSON_TOKENS + 1) + "0]").to_utf8_buffer()
	var huge_string := ("{\"ignored\":\"" + "x".repeat(4097) + "\"}").to_utf8_buffer()
	var invalid_utf8 := PackedByteArray([123, 34, 120, 34, 58, 34, 255, 34, 125])
	for buffer: PackedByteArray in [deep, many, huge_string, invalid_utf8]:
		_check(store.decode_layout(buffer).is_empty(), "Oversized JSON structures/strings and invalid UTF-8 must not reach layout construction.")
	var inert := fixture.duplicate(true)
	inert["name"] = "../../outside.json"
	inert["station_names"] = []
	for index in range(inert["stations"].size()):
		inert["station_names"].append("<script>alert('x')</script> [url=javascript:evil]station[/url]")
	var safe := store.decode_layout(store.encode_layout(inert))
	_check(not safe.is_empty() and safe["graph"].stations[0].display_name == inert["station_names"][0], "Script-like labels and path-like root names are inert data, never evaluated or used as destinations.")
	var started := Time.get_ticks_usec()
	for index in range(50):
		store.restore(bad)
	var elapsed := (Time.get_ticks_usec() - started) / 1000.0
	print("Rejected 50 adversarial layout attempts in %.1f ms." % elapsed)
	_check(elapsed < 2000.0, "Repeated malformed layouts must reject promptly without building render caches.")
	var at_limit := fixture.duplicate(true)
	at_limit["stations"] = []
	for index in range(LayoutStore.MAX_STATIONS):
		at_limit["stations"].append([index * 144, 0])
	at_limit["tracks"] = []
	at_limit["lines"] = [fixture["lines"][0].duplicate(true)]
	at_limit["lines"][0]["stations"] = []
	at_limit["lines"][0]["max_trains"] = 1
	_check(not store.restore(at_limit).is_empty(), "Exactly 256 valid stations must be accepted, not just rejected above the threshold.")
	_check(store._json_complexity_valid(("\"" + "x".repeat(4096) + "\"").to_utf8_buffer()), "The exact 4096-byte JSON string threshold must be accepted.")
	_check(not store._json_complexity_valid(("1".repeat(129)).to_utf8_buffer()), "Oversized numeric tokens must be rejected before JSON parsing.")
	_check(not store.write_layout_file("user://missing-transfer-directory/layout.json", PackedByteArray([123, 125])), "Unwritable export destination must report failure.")
	transfer.call("_on_file_selected", "user://missing-transfer-smoke.json")
	_check(main.get("graph") == live_graph and main.get("_status_seconds") > 0, "Missing import must preserve the live network.")
	_check(DirAccess.remove_absolute(TEST_FILE) == OK, "External fixture cleanup must succeed.")
	main.queue_free()
	await process_frame
	if _failed:
		quit(1)
	else:
		print("Transfer smoke passed: all presets exported/imported through menu signals, complete file round-trip, confirmation/cancel, validation, size limit and explicit I/O failures. Negative validation errors above are intentional.")
		quit()
