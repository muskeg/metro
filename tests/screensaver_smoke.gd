extends SceneTree

var _failed := false

class KioskStartup extends "res://scripts/main.gd":
	var kiosk_requested := false
	var startup_layout := ""

	func _web_kiosk_requested() -> bool:
		return kiosk_requested

	func _web_startup_parameter(parameter: String) -> String:
		return startup_layout if parameter == "layout" else ""

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _capture(main: Node, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	main.call("_process", 0.0)
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("/tmp/metro-screensaver-%s.png" % name) == OK, "Screensaver screenshot must be saved.")

func _run() -> void:
	await _test_kiosk_startup()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_check(not main.get("_screensaver_active"), "Normal startup must never enable screensaver by default.")
	root.content_scale_factor = 1.0
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(1440, 900)
	await process_frame
	main.set_process(false)
	var dispatcher: TransitDispatcher = main.get("dispatcher")
	dispatcher.process(1.0, false)
	var camera: Camera2D = main.get("camera")
	var graph: TransitGraph = main.get("graph")
	var first_train := dispatcher.metros[0]
	main.call("_follow_train", first_train)
	main.set("paused", true)
	var saved_position := camera.position
	var saved_zoom := camera.zoom
	var saved_smoothing := camera.position_smoothing_enabled
	var saved_window_mode := DisplayServer.window_get_mode()
	var saved_mouse_mode := Input.mouse_mode
	var saved_floor: float = main.get("_minimum_camera_zoom")
	var distance := first_train.distance
	main.get("_screensaver_button").pressed.emit()
	await process_frame
	await process_frame
	_check(main.get("_screensaver_active") and not main.get("paused"), "Menu entry must start screensaver and temporarily unpause.")
	_check(main.get("world_view").get("_motion_antialiasing").visible, "Screensaver must enable screen-space edge smoothing.")
	_check(main.get("_ui_root").get_parent().layer > main.get("world_view").get("_motion_antialiasing").layer, "The HUD must render after edge smoothing so text and controls stay untouched.")
	_check(not main.get("_ui_root").visible and not main.get("_restore_ui_button").visible and not main.get("_brand").visible, "Screensaver must hide every HUD element, including brand and Watch grip.")
	_check(not main.get("world_view").interaction_overlays_visible, "Screensaver must hide editing overlays.")
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "Screensaver must hide the native cursor.")
		_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Native screensaver must enter fullscreen.")
	main.call("_update_screensaver", 3.0)
	_check(not camera.position.is_equal_approx(saved_position) or not camera.zoom.is_equal_approx(saved_zoom), "Overview transition must move the camera before completion.")
	main.call("_update_screensaver", 3.0)
	var bounds: Rect2 = main.call("_layout_bounds")
	var usable_size: Vector2 = main.get_viewport_rect().size - Vector2(64, 64)
	var fit_zoom := minf(6.0, minf(usable_size.x / bounds.size.x, usable_size.y / bounds.size.y))
	_check(camera.position.is_equal_approx(bounds.get_center()) and camera.zoom.is_equal_approx(Vector2.ONE * fit_zoom), "Overview must fit all map bounds without reserving HUD space.")
	await _capture(main, "overview")
	main.call("_update_screensaver", 28.0)
	_check(main.get("_screensaver_shot") == 0, "Overview must last 35 seconds, not rotate prematurely.")
	main.call("_update_screensaver", 1.0)
	_check(main.get("_screensaver_shot") == 1 and main.get("_screensaver_train") != null, "Overview must rotate to a live train.")
	var followed: Metro = main.get("_screensaver_train")
	main.call("_update_screensaver", 6.0)
	_check(camera.position.is_equal_approx(followed.position) and camera.zoom.is_equal_approx(Vector2.ONE * 5.0), "Train shot must smoothly reach its close-up framing.")
	var dwell_remaining := first_train.dwell_remaining
	main.call("_process", 0.5)
	_check((first_train.distance != distance or first_train.dwell_remaining < dwell_remaining) and dispatcher.metros.has(first_train), "Screensaver must run the existing fleet without rebuilding trains.")
	_check(camera.position.is_equal_approx(followed.position), "Camera must track the train after simulation advances.")
	await _capture(main, "follow")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 40)
	main.call("_input", motion)
	main.call("_input", _key(KEY_P))
	_check(main.get("_screensaver_active") and not main.get("paused"), "Mouse movement and unrelated keys must neither exit nor pause screensaver.")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	main.call("_input", wheel)
	_check(camera.zoom.is_equal_approx(Vector2.ONE * 5.0), "Mouse wheel must not disrupt an automated shot.")
	main.call("_update_screensaver", 33.5)
	_check(main.get("_screensaver_shot") == 2, "Train shot must rotate to a pan after 40 seconds.")
	main.call("_update_screensaver", 6.0)
	var pan_start := camera.position
	main.call("_update_screensaver", 17.0)
	var pan_midpoint := camera.position
	main.call("_update_screensaver", 16.0)
	var pan_end := camera.position
	_check(not pan_start.is_equal_approx(pan_midpoint) and not pan_midpoint.is_equal_approx(pan_end), "Zoomed pan must continue moving throughout its shot.")
	_check(camera.zoom.x > fit_zoom and pan_start.distance_to(pan_end) * camera.zoom.x <= minf(usable_size.x + 64, usable_size.y + 64) * 0.5, "Pan must show a zoomed section and move at most half the short screen dimension.")
	await _capture(main, "pan")
	main.call("_update_screensaver", 1.0)
	var next_train: Metro = main.get("_screensaver_train")
	_check(main.get("_screensaver_shot") == 3 and next_train != followed and next_train.line_id != followed.line_id, "Successive follow shots must choose a different train and line when available.")
	main.call("_update_screensaver", 40.0)
	_check(main.get("_screensaver_active") and main.get("_screensaver_shot") == 0, "Screensaver must loop continuously back to overview.")
	root.size = Vector2i(640, 480)
	await process_frame
	main.call("_update_screensaver", 6.0)
	_check(camera.position.is_equal_approx(bounds.get_center()) and bounds.size.x * camera.zoom.x <= main.get_viewport_rect().size.x - 64.0 + 0.01, "Overview must adapt to viewport resizing.")
	main.call("_input", _key(KEY_ESCAPE))
	_check(not main.get("_screensaver_active") and main.get("paused") and main.get("_followed_train") == first_train, "Escape must restore pause and previous manual follow.")
	_check(not main.get("world_view").get("_motion_antialiasing").visible, "Leaving screensaver must disable its smoothing pass.")
	_check(camera.position.is_equal_approx(saved_position) and camera.zoom.is_equal_approx(saved_zoom) and camera.position_smoothing_enabled == saved_smoothing, "Exit must restore camera framing and smoothing.")
	_check(main.get("_ui_root").visible and not main.get("_restore_ui_button").visible and Input.mouse_mode == saved_mouse_mode and DisplayServer.window_get_mode() == saved_window_mode, "Exit must restore interface, cursor and exact window mode.")
	_check(main.get("_minimum_camera_zoom") == saved_floor and graph == main.get("graph"), "Screensaver must not change navigation limits or replace the map.")
	main.call("_stop_following")
	root.push_input(_key(KEY_K))
	_check(main.get("_screensaver_active"), "K must enter screensaver from the editor.")
	var station_count := graph.stations.size()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(320, 240)
	click.pressed = true
	root.push_input(click)
	click.pressed = false
	root.push_input(click)
	_check(not main.get("_screensaver_active") and graph.stations.size() == station_count, "Exit click and release must be consumed without editing the map.")
	main.call("_toggle_ui")
	main.call("_start_screensaver")
	var touch := InputEventScreenTouch.new()
	touch.index = 4
	touch.position = Vector2(320, 240)
	touch.pressed = true
	root.push_input(touch)
	touch.pressed = false
	root.push_input(touch)
	_check(not main.get("_screensaver_active") and main.get("_ui_hidden") and main.get("_restore_ui_button").visible, "Touch exit must restore an existing manual Watch mode.")
	_check(graph.stations.size() == station_count and not main.get("_touch_world_sequence"), "Exit tap must not leak into station placement or leave touch state active.")
	main.call("_toggle_ui")
	main.call("_follow_train", first_train)
	main.call("_start_screensaver")
	main.call("_begin_screensaver_shot", 1)
	var removed: Metro = main.get("_screensaver_train")
	_check(removed == first_train, "Removal fixture must remove the saved manual-follow target.")
	dispatcher.metros.erase(removed)
	main.call("_update_screensaver", 1.0)
	_check(main.get("_screensaver_train") != removed and dispatcher.metros.has(main.get("_screensaver_train")), "A removed train must be replaced safely.")
	main.call("_stop_screensaver")
	_check(main.get("_followed_train") == null, "A removed manual-follow target must not be restored.")
	main.queue_free()
	await process_frame
	await _test_empty_map()
	if _failed:
		quit(1)
	else:
		print("Screensaver smoke passed.")
		quit(0)

func _test_kiosk_startup() -> void:
	for requested: bool in [false, true]:
		var main: Node = load("res://scenes/main.tscn").instantiate()
		main.set_script(KioskStartup)
		main.set("kiosk_requested", requested)
		var window_mode := DisplayServer.window_get_mode()
		root.add_child(main)
		main.set_process(false)
		await process_frame
		_check(main.get("_screensaver_active") == requested, "Only an explicit kiosk startup request may activate screensaver.")
		_check(not main.get("graph").stations.is_empty(), "Kiosk entry must happen after the bundled layout has loaded.")
		_check(DisplayServer.window_get_mode() == window_mode, "URL startup must not attempt fullscreen without a browser user gesture.")
		if requested:
			_check(not main.get("_ui_root").visible and not main.get("_restore_ui_button").visible, "Kiosk startup must hide all controls.")
			main.call("_update_screensaver", 36.0)
			_check(main.get("_screensaver_shot") == 1, "Kiosk startup must run the existing cinematic cycle.")
			main.call("_input", _key(KEY_ESCAPE))
			_check(not main.get("_screensaver_active") and main.get("_ui_root").visible, "Escape must restore normal play after URL-triggered startup.")
		main.queue_free()
		await process_frame
	for layout: String in ["metro_demo", "montreal", "jr_east", "../invalid"]:
		var main: Node = load("res://scenes/main.tscn").instantiate()
		main.set_script(KioskStartup)
		main.set("kiosk_requested", true)
		main.set("startup_layout", layout)
		root.add_child(main)
		main.set_process(false)
		await process_frame
		if layout == "../invalid":
			_check(not main.get("_screensaver_active") and main.get("_ui_root").visible, "Invalid startup layouts must not hide a load failure behind kiosk mode.")
			_check(not main.get("_panel_status").text.is_empty(), "Invalid layout requests must report a visible load error.")
		else:
			var expected := LayoutStore.new().load_bundled_layout("res://layouts/" + layout + ".json")
			_check(main.get("graph").stations.size() == expected["graph"].stations.size() and main.get("lines").size() == expected["lines"].size(), "URL layout selection must load the requested bundled network before entering kiosk.")
			_check(main.get("_screensaver_active"), "Each valid bundled layout must support kiosk startup.")
			main.call("_stop_screensaver")
		main.queue_free()
		await process_frame
	var store := LayoutStore.new()
	store.directory = "user://kiosk-startup-smoke-layouts"
	var graph := TransitGraph.new()
	graph.add_station(Vector2.ZERO)
	graph.add_station(Vector2(576, 0))
	var line := TransitLine.new(0, Color("#58b8bd"))
	line.append_station(graph, 0)
	line.append_station(graph, 1)
	var lines: Array[TransitLine] = [line]
	var name := "Réseau kiosque & essais"
	_check(store.save_layout(name, store.capture(graph, lines, 0, Vector2.ZERO, 0.5)), "Custom startup fixture must save through the normal layout store.")
	for requested: bool in [false, true]:
		for saved_name: String in [name, "absent", ""]:
			var main: Node = load("res://scenes/main.tscn").instantiate()
			main.set_script(KioskStartup)
			main.set("layout_store", store)
			main.set("kiosk_requested", requested)
			main.set("startup_layout", "saved:" + saved_name)
			root.add_child(main)
			main.set_process(false)
			await process_frame
			if saved_name == name:
				_check(main.get("graph").stations.size() == 2 and main.get("lines").size() == 1, "Saved startup must load the custom network, not a bundled fallback.")
				_check(main.get("_screensaver_active") == requested, "Saved layouts must work with and without kiosk.")
				if requested:
					main.call("_stop_screensaver")
			else:
				_check(not main.get("_screensaver_active") and main.get("_ui_root").visible, "Missing or invalid saved names must leave the interface accessible.")
				_check(not main.get("_panel_status").text.is_empty(), "Missing or invalid saved names must show the startup load error.")
			main.queue_free()
			await process_frame
	_check(DirAccess.remove_absolute(store._path(name)) == OK, "Custom startup fixture cleanup must succeed.")
	_check(DirAccess.remove_absolute(store.directory) == OK, "Custom startup test directory cleanup must succeed.")

func _test_empty_map() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("startup_layout_enabled", false)
	root.add_child(main)
	main.set_process(false)
	var previous_mode := DisplayServer.window_get_mode()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	main.call("_start_screensaver")
	for shot in range(4):
		main.call("_begin_screensaver_shot", shot)
		main.call("_update_screensaver", 10.0)
		var camera: Camera2D = main.get("camera")
		_check(camera.position.is_finite() and camera.zoom.is_finite() and camera.zoom.x > 0.0, "Empty maps and missing trains must keep valid framing in every shot.")
	var graph: TransitGraph = main.get("graph")
	graph.add_station(Vector2(-48000, 0))
	graph.add_station(Vector2(48000, 0))
	main.call("_begin_screensaver_shot", 0)
	main.call("_update_screensaver", 10.0)
	var camera: Camera2D = main.get("camera")
	_check(camera.zoom.x < 0.08 and camera.position.is_equal_approx(Vector2.ZERO), "Screensaver overview must fit very large maps below the manual navigation floor.")
	main.call("_stop_screensaver")
	_check(not main.get("paused"), "Exit must preserve an originally running simulation.")
	if DisplayServer.get_name() != "headless":
		_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "An already-fullscreen window must remain fullscreen on exit.")
		DisplayServer.window_set_mode(previous_mode)
	main.queue_free()
	await process_frame
