extends SceneTree

const StoreScript := preload("res://scripts/layout_store.gd")
const TEST_DIRECTORY := "user://layout-smoke"
var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true

func _run() -> void:
	await _test_bundled_layout()
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node = scene.instantiate()
	main.set("startup_layout_enabled", false)
	var store := StoreScript.new()
	store.directory = TEST_DIRECTORY
	main.set("layout_store", store)
	root.add_child(main)
	main.set_process(false)
	root.content_scale_factor = 1.0
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(760, 520)
	await process_frame
	var graph: TransitGraph = main.get("graph")
	var lines: Array[TransitLine] = main.get("lines")
	for point: Vector2 in [Vector2.ZERO, Vector2(576, 0), Vector2(576, 576), Vector2(0, 576), Vector2(-576, 0)]:
		graph.add_station(point)
	for id: int in [0, 1, 2, 3, 0]:
		_check(lines[0].append_station(graph, id), "Loop construction must succeed.")
	var shared := TransitLine.new(1, Color("#abcdef"))
	lines.append(shared)
	for id: int in [1, 0, 4]:
		_check(shared.append_station(graph, id), "Reversed shared line construction must succeed.")
	var curved := graph.track_between(0, 4)
	curved.waypoints = PackedVector2Array([Vector2.ZERO, Vector2(-144, -144), Vector2(-432, -144), Vector2(-576, 0)])
	shared.dispatch_rate = 27.0
	shared.dwell_time = 6.0
	shared.cruise_velocity = 155.0
	shared.acceleration = 95.0
	shared.braking = 110.0
	shared.terminal_recovery = 7.0
	shared.wagon_count = 3
	shared.max_trains = 5
	shared.render_priority = 3
	lines.append(TransitLine.new(2, Color("#e98668")))
	main.get("dispatcher").lines.assign(lines)
	main.call("_refresh_network")
	main.call("_select_line", 1)
	main.get("camera").position = Vector2(192, -240)
	main.get("camera").zoom = Vector2.ONE * 0.08
	var snapshot := store.capture(graph, lines, 1, Vector2(192, -240), 0.08)
	var layout_name := "Test / réseau .."
	main.call("_open_layouts", true)
	main.get("_layout_name").text = layout_name
	main.get("_layout_action").pressed.emit()
	_check(store.exists(layout_name) and not main.get("_layout_popup").visible, "Menu save must persist a named layout and close on success.")
	_check(store.names().has(layout_name), "Unicode and path-like names must be listed safely.")
	_check(not store.valid_name("   ") and not store.valid_name("bad\nname"), "Empty and multiline names must be rejected.")
	var reopened := StoreScript.new()
	reopened.directory = TEST_DIRECTORY
	var restored := reopened.load_layout(layout_name)
	_check(not restored.is_empty(), "A new store must load the saved layout.")
	if not restored.is_empty():
		_check(store.capture(restored["graph"], restored["lines"], restored["active_line"], restored["camera"], restored["zoom"]) == snapshot, "Every geometry, line setting, ordering and view field must round-trip.")
	main.call("_open_layouts", true)
	main.get("_layout_name").text = layout_name
	main.get("_layout_action").pressed.emit()
	_check(main.get("_layout_dialog").visible, "Overwriting a name must require confirmation.")
	main.get("_layout_dialog").canceled.emit()
	main.get("_layout_dialog").hide()
	_check(store.capture(main.get("graph"), main.get("lines"), 1, Vector2(192, -240), 0.08) == snapshot, "Cancel overwrite must preserve the map.")
	main.call("_request_layout_action")
	main.get("_layout_dialog").hide()
	main.get("_layout_dialog").confirmed.emit()
	_check(not store.load_layout(layout_name).is_empty(), "Confirmed overwrite must work on an existing file.")
	main.set("paused", true)
	var dispatcher: TransitDispatcher = main.get("dispatcher")
	dispatcher.process(1.0, false)
	main.call("_follow_train", dispatcher.metros[0])
	main.call("_request_clear_map")
	_check(main.get("graph") == graph and graph.stations.size() == 5, "Requesting clear must not mutate the map.")
	main.get("_layout_dialog").canceled.emit()
	main.get("_layout_dialog").hide()
	main.call("_request_clear_map")
	main.get("_layout_dialog").hide()
	main.get("_layout_dialog").confirmed.emit()
	_check(main.get("graph").stations.is_empty() and main.get("graph").tracks.is_empty() and main.get("lines").size() == 1, "Confirmed clear must create an empty editable default line.")
	_check(main.get("dispatcher").metros.is_empty() and main.get("dispatcher").visits.is_empty() and main.get("_followed_train") == null, "Clear must remove stale trains, visits and following.")
	_check(main.get("selected_station_id") == -1 and main.get("_previous_arrival_count") == 0 and main.get("paused"), "Replacement must reset stale selection/arrivals while preserving pause.")
	_check(store.exists(layout_name), "Clear must keep named saves.")
	var second_name := "Pause"
	var empty_snapshot := store.capture(main.get("graph"), main.get("lines"), 0, Vector2.ZERO, 1.0)
	_check(store.save_layout(second_name, empty_snapshot), "A second distinct layout must save independently.")
	_check(store.names().size() == 2 and not store.load_layout(layout_name).is_empty(), "Multiple named layouts must coexist.")
	main.call("_open_layouts", false)
	for index in range(main.get("_saved_layouts").item_count):
		if main.get("_saved_layouts").get_item_text(index) == layout_name:
			main.get("_saved_layouts").select(index)
	main.get("_layout_action").pressed.emit()
	_check(main.get("_layout_dialog").visible and main.get("graph").stations.is_empty(), "Menu load must require confirmation before replacement.")
	main.get("_layout_dialog").hide()
	main.get("_layout_dialog").confirmed.emit()
	var loaded_snapshot := store.capture(main.get("graph"), main.get("lines"), main.get("active_line").id, main.get("camera").position, main.get("camera").zoom.x)
	var expected_loaded := snapshot.duplicate(true)
	for field: String in ["camera", "zoom"]:
		loaded_snapshot.erase(field)
		expected_loaded.erase(field)
	_check(loaded_snapshot == expected_loaded and main.get("camera").zoom.x > 0.08, "Menu load must preserve topology/settings and fit the map instead of restoring the saved overview.")
	main.call("_place_station", Vector2(-960, -480))
	_check(main.get("graph").stations.size() == 6, "Loaded layouts must remain editable.")
	# Expected validation failures must not replace the live map.
	for field: String in ["version", "lines", "active_line", "zoom"]:
		var invalid := snapshot.duplicate(true)
		invalid[field] = null
		_check(store.restore(invalid).is_empty() and not store.error_message.is_empty(), "Invalid " + field + " must be reported.")
	var invalid := snapshot.duplicate(true)
	invalid["tracks"][0]["a"] = 500
	_check(store.restore(invalid).is_empty(), "Out-of-range track references must be rejected.")
	invalid = snapshot.duplicate(true)
	invalid["lines"][0]["wagon_count"] = 2.5
	_check(store.restore(invalid).is_empty(), "Fractional integer settings must be rejected.")
	for value: Variant in [-1, 16, 1.5, "1", null]:
		invalid = snapshot.duplicate(true)
		invalid["lines"][0]["render_priority"] = value
		_check(store.restore(invalid).is_empty(), "Invalid render priorities must be rejected.")
	invalid = snapshot.duplicate(true)
	invalid["lines"][0]["stations"] = [0, 2]
	_check(store.restore(invalid).is_empty(), "Missing line tracks must be rejected.")
	invalid = snapshot.duplicate(true)
	invalid["camera"] = [1.0e300, 0]
	_check(store.restore(invalid).is_empty(), "Coordinates that overflow Vector2 must be rejected.")
	var bad_name := "Corrupt test"
	var file := FileAccess.open(store._path(bad_name), FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	main.call("_open_layouts", false)
	main.set("_pending_layout_operation", "load")
	main.set("_pending_layout_name", bad_name)
	var live_graph: TransitGraph = main.get("graph")
	main.call("_confirm_layout_operation")
	_check(main.get("graph") == live_graph and main.get("_status_seconds") > 0, "Corrupt load must preserve the current map and show an error.")
	file = FileAccess.open(store._path(bad_name), FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	store.names()
	_check(not store.error_message.is_empty(), "An empty JSON object must not masquerade as missing saves.")
	_check(DirAccess.remove_absolute(store._path(bad_name)) == OK, "Corrupt fixture cleanup must succeed.")
	main.queue_free()
	await process_frame
	# Restart the scene as well as the storage object.
	main = scene.instantiate()
	main.set("startup_layout_enabled", false)
	main.set("layout_store", reopened)
	root.add_child(main)
	main.set_process(false)
	main.call("_open_layouts", false)
	_check(main.get("_saved_layouts").item_count == 2 + StoreScript.BUNDLED_LAYOUTS.size(), "Saved layouts and bundled presets must be available in a fresh game instance.")
	_check(main.get("_saved_layouts").auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "Player-supplied layout names must never be translated.")
	for locale: String in ["en", "fr"]:
		TranslationServer.set_locale(locale)
		for viewport: Vector2i in [Vector2i(760, 520), Vector2i(390, 640)]:
			root.size = viewport
			main.call("_resize_interface")
			await process_frame
			await process_frame
			_check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(main.get("_layout_popup").get_global_rect()), "Layout sheet must fit narrow/minimum viewports in both languages.")
	main.queue_free()
	await process_frame
	_check(DirAccess.remove_absolute(store._path(layout_name)) == OK, "Saved fixture cleanup must succeed.")
	_check(DirAccess.remove_absolute(store._path(second_name)) == OK, "Second saved fixture cleanup must succeed.")
	_check(DirAccess.remove_absolute(TEST_DIRECTORY) == OK, "Test directory cleanup must succeed.")
	if _failed:
		quit(1)
	else:
		print("Layout smoke passed: menu save/load/clear, confirmation, restart persistence, complete round-trip, validation and responsive localization. Validation errors above are intentional.")
		quit()

func _test_bundled_layout() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var store := StoreScript.new()
	store.directory = TEST_DIRECTORY
	main.set("layout_store", store)
	root.add_child(main)
	main.set_process(false)
	var montreal_startup := OS.has_feature("montreal_startup")
	_check(main.get("graph").stations.size() == (68 if montreal_startup else 16) and main.get("lines").size() == (4 if montreal_startup else 3), "Startup must select Montreal only for exports with the montreal_startup feature.")
	_check(main.get("_status_seconds") == 0 and not main.get("_layout_popup").visible, "Successful bundled startup must be quiet with sheets closed.")
	main.call("_replace_layout", store.load_bundled_layout(StoreScript.STARTER_PATH), true)
	var graph: TransitGraph = main.get("graph")
	var lines: Array[TransitLine] = main.get("lines")
	_check(graph.stations.size() == 16 and lines.size() == 3 and lines[0].is_loop(), "The bundled demo must retain its three lines and loop.")
	_check(main.get("_status_seconds") == 0 and not main.get("_layout_popup").visible, "Successful demo startup must be quiet with sheets closed.")
	for track: Track in graph.tracks:
		_check(graph.path_error(track.a, track.b, TrackGeometry.anchors(graph, track)).is_empty(), "Bundled geometry must respect the editable map's crossing/grid rules.")
	for line: TransitLine in lines:
		_check(main.get("dispatcher").route_capacity(line) >= 2, "Every demo line must support bidirectional service.")
		var diagonal_sections := 0
		var directions: Array[Vector2] = []
		for track_id: int in line.tracks:
			_check(TrackGeometry.length(TrackGeometry.sample(graph, graph.tracks[track_id])) >= TrackGeometry.train_length(line.wagon_count) + 40, "Every demo section must fit its trains.")
			var anchors := TrackGeometry.anchors(graph, graph.tracks[track_id])
			for index in range(1, anchors.size()):
				var direction := (anchors[index] - anchors[index - 1]).normalized()
				if not is_zero_approx(direction.x) and not is_zero_approx(direction.y):
					diagonal_sections += 1
				if not directions.has(direction):
					directions.append(direction)
		if not line.is_loop():
			_check(diagonal_sections >= 2 and directions.size() >= 2, "Open demo lines must include multiple diagonals and direction changes, not straight cross arms.")
	var dispatcher: TransitDispatcher = main.get("dispatcher")
	for second in range(180):
		dispatcher.process(1.0, false)
	for line: TransitLine in lines:
		var served := false
		for train: Metro in dispatcher.metros:
			if train.line_id == line.id:
				served = true
		_check(served, "Every demo line must run trains after three simulated minutes.")
	_check(dispatcher.arrival_count >= 20, "Demo service must continue making station stops.")
	var original := store.load_bundled_layout(StoreScript.STARTER_PATH)
	var original_zoom: Vector2 = Vector2.ONE * original["zoom"]
	var original_snapshot := store.capture(original["graph"], original["lines"], original["active_line"], original["camera"], original_zoom.x)
	main.call("_place_station", Vector2(960, 960))
	_check(graph.stations.size() == 17, "The bundled demo must be editable.")
	_check(store.save_layout("Metro demo", store.capture(graph, lines, 0, Vector2.ZERO, 0.32)), "A user save may share the demo's name without overwriting its resource.")
	main.call("_open_layouts", false)
	var selector: OptionButton = main.get("_saved_layouts")
	_check(selector.item_count == 1 + StoreScript.BUNDLED_LAYOUTS.size() and selector.get_item_metadata(0) == false and selector.get_item_metadata(1) == StoreScript.STARTER_PATH, "User saves and bundled originals must remain distinct in Load.")
	selector.select(1)
	main.call("_request_layout_action")
	_check(main.get("_layout_dialog").visible and graph.stations.size() == 17, "Reloading the bundled original must ask before replacing edits.")
	main.get("_layout_dialog").hide()
	main.get("_layout_dialog").confirmed.emit()
	_check(main.get("graph").stations.size() == 16, "Confirmed bundled load must restore the original demo.")
	main.call("_request_clear_map")
	main.get("_layout_dialog").hide()
	main.get("_layout_dialog").confirmed.emit()
	_check(main.get("graph").stations.is_empty() and store.exists("Metro demo"), "Clear must empty the demo without deleting user copies.")
	main.call("_open_layouts", false)
	selector.select(1)
	main.call("_request_layout_action")
	main.get("_layout_dialog").hide()
	main.get("_layout_dialog").confirmed.emit()
	var reloaded_snapshot := store.capture(main.get("graph"), main.get("lines"), 0, main.get("camera").position, main.get("camera").zoom.x)
	_check(not is_equal_approx(reloaded_snapshot["zoom"], original_snapshot["zoom"]), "Bundled framing must use the current viewport rather than the saved zoom.")
	reloaded_snapshot.erase("zoom")
	original_snapshot.erase("zoom")
	reloaded_snapshot.erase("camera")
	original_snapshot.erase("camera")
	_check(reloaded_snapshot == original_snapshot, "Bundled original must remain unchanged after edit/save/clear, apart from auto-fitted camera.")
	main.call("_open_layouts", true)
	_check(selector.item_count == 1 and selector.get_item_metadata(0) == false, "Save must offer user files only, never the read-only bundled original.")
	for viewport: Vector2i in [Vector2i(760, 520), Vector2i(390, 640)]:
		root.content_scale_factor = 1.0
		root.min_size = Vector2i.ZERO
		root.size = viewport
		main.call("_replace_layout", store.load_bundled_layout(StoreScript.STARTER_PATH), true)
		var camera: Camera2D = main.get("camera")
		for station: Station in main.get("graph").stations:
			var offset := (station.position - camera.position).abs() * camera.zoom
			_check(offset.x <= (viewport.x - 64) * 0.5 + 0.01 and offset.y <= (viewport.y - 160) * 0.5 + 0.01, "Demo framing must fit every station on phone and minimum laptop viewports.")
	_check(DirAccess.remove_absolute(store._path("Metro demo")) == OK, "Demo copy fixture cleanup must succeed.")
	for path: String in StoreScript.BUNDLED_LAYOUTS:
		main.call("_replace_layout", store.load_bundled_layout(path), true)
		var points := PackedVector2Array()
		for station: Station in main.get("graph").stations:
			points.append(station.position)
		for track: Track in main.get("graph").tracks:
			points.append_array(TrackGeometry.anchors(main.get("graph"), track))
		for route: Dictionary in main.get("dispatcher").routes.values():
			points.append_array(route["points"])
		var bounds := Rect2(points[0], Vector2.ZERO)
		for point: Vector2 in points:
			bounds = bounds.expand(point)
		bounds = bounds.grow(24)
		for viewport: Vector2i in [Vector2i(390, 640), Vector2i(760, 520), Vector2i(1180, 740), Vector2i(1920, 1080)]:
			root.size = viewport
			await process_frame
			main.get("_fit_window_button").pressed.emit()
			var camera: Camera2D = main.get("camera")
			var used := bounds.size * camera.zoom
			var available := Vector2(viewport) - Vector2(64, 192)
			var screen_center := Vector2(viewport) * 0.5 + (bounds.get_center() - camera.position) * camera.zoom
			_check(screen_center.is_equal_approx(Vector2(32, 80) + available * 0.5), "Fit must center full station, bend and running-corridor bounds in the usable viewport: " + path)
			_check(used.x <= available.x + 0.1 and used.y <= available.y + 0.1, "Fit must never crop a layout, even below the normal overview zoom floor: " + path)
			_check(is_equal_approx(used.x, available.x) or is_equal_approx(used.y, available.y), "Fit must fill 100% of one usable window dimension: " + path)
			var zoom := camera.zoom.x
			main.call("_zoom_camera", 1.12)
			_check(camera.zoom.x > zoom, "Zooming in after fitting a huge layout must not jump or get stuck.")
			main.call("_zoom_camera", 1.0 / 1.12)
			_check(is_equal_approx(camera.zoom.x, zoom), "Zooming back out must preserve the fitted overview below 0.08.")
			var fitted_position := camera.position
			camera.position += Vector2(1000, -1000)
			main.get("_zoom_in_button").pressed.emit()
			_check(camera.zoom.x > zoom, "The plus button must zoom in.")
			main.get("_zoom_out_button").pressed.emit()
			_check(is_equal_approx(camera.zoom.x, zoom), "The minus button must zoom back out.")
			main.get("_fit_window_button").pressed.emit()
			_check(camera.position.is_equal_approx(fitted_position) and is_equal_approx(camera.zoom.x, zoom), "The fit icon must restore the complete layout after manual navigation.")
	main.call("_request_clear_map")
	main.get("_layout_dialog").hide()
	main.get("_layout_dialog").confirmed.emit()
	main.get("_fit_window_button").pressed.emit()
	_check(main.get("camera").position == Vector2.ZERO and main.get("camera").zoom == Vector2.ONE and main.get("_minimum_camera_zoom") == 0.08, "Fitting an empty map must restore the neutral camera and navigation floor.")
	main.get("graph").add_station(Vector2(480, -960))
	main.get("_fit_window_button").pressed.emit()
	_check(main.get("camera").zoom.x == 6.0 and main.get("camera").position.is_finite(), "Fitting a single station must remain finite and respect the maximum zoom.")
	main.queue_free()
	await process_frame
