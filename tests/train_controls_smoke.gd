extends SceneTree

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.size = Vector2i(1440, 900)
	await process_frame
	_check(not main.get("_max_trains_slider").editable and main.get("_max_trains_value").text == "0", "An empty line must show zero service and disable its train limit.")
	var graph: TransitGraph = main.get("graph")
	for position: Vector2 in [Vector2.ZERO, Vector2(1152, 0), Vector2(0, 576), Vector2(1152, 576)]:
		graph.add_station(position)
	main.call("_connect_stations", 0, 1)
	var lines: Array = main.get("lines")
	var dispatcher: TransitDispatcher = main.get("dispatcher")
	var first: TransitLine = lines[0]
	_check(first.max_trains == 4, "Lines must default to at most four trains.")
	first.dispatch_rate = 8.0
	first.dwell_time = 0.1
	main.call("_create_line")
	main.call("_connect_stations", 2, 3)
	var second: TransitLine = lines[1]
	second.max_trains = 2
	second.dispatch_rate = 8.0
	second.dwell_time = 0.1
	dispatcher.process(100.0, false)
	_check(dispatcher.route_capacity(first) > 2 and dispatcher.train_limit(first) == 4, "Long two-station routes must support more than two trains.")
	_check(_count(dispatcher, 0) == 4 and _count(dispatcher, 1) == 2, "Independent lines must respect their manual service caps.")
	main.call("_select_line", 0)
	var slider: HSlider = main.get("_max_trains_slider")
	_check(slider.value == 4.0 and slider.max_value == dispatcher.route_capacity(first), "The selected line's manual limit and route capacity must be shown.")
	_check(main.get("_max_trains_value").tooltip_text.contains(str(dispatcher.recommended_fleet(first))), "Fleet guidance must show the cycle-time recommendation.")
	var independent_train: Metro
	for candidate: Metro in dispatcher.metros:
		if candidate.line_id == 1:
			independent_train = candidate
			break
	slider.value = 1.0
	_check(first.max_trains == 1 and _count(dispatcher, 0) == 4 and dispatcher.metros.has(independent_train), "Reducing a limit must leave running and independent trains undisturbed.")
	dispatcher.process(80.0, false)
	_check(_count(dispatcher, 0) == 1 and _count(dispatcher, 1) == 2 and dispatcher.metros.has(independent_train), "Surplus trains must retire at termini without redispatching independent lines.")
	var kept := dispatcher.metros[0]
	slider.value = 3.0
	_check(dispatcher.metros.has(kept), "Raising a limit must not interrupt existing trains.")
	dispatcher.process(80.0, false)
	_check(_count(dispatcher, 0) == 3 and _count(dispatcher, 1) == 2, "Raising the manual limit must allow further service.")
	main.call("_select_line", 1)
	_check(slider.value == 2.0, "Switching lines must restore their independent limit.")
	main.call("_select_line", 0)
	main.set("paused", true)
	var view: WorldView = main.get("world_view")
	var camera: Camera2D = main.get("camera")
	var train: Metro
	for candidate: Metro in dispatcher.metros:
		if candidate.line_id == 0:
			train = candidate
			break
	train.distance = 500.0
	dispatcher._update_pose(train, dispatcher.routes[0])
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE
	camera.reset_smoothing()
	await process_frame
	var wagon := TrackGeometry.car_position(dispatcher.routes[0]["points"], dispatcher.routes[0]["length"], train.distance, 1)
	await _mouse(view, wagon, MOUSE_BUTTON_LEFT, true)
	await _mouse(view, wagon, MOUSE_BUTTON_LEFT, false)
	_check(main.get("_followed_train") == train and camera.zoom.x == 5.0, "Clicking a wagon must follow its train close up.")
	_check(camera.position.distance_to(train.position) < 0.01, "The follow camera must target the locomotive.")
	train.distance += 50.0
	dispatcher._update_pose(train, dispatcher.routes[0])
	await process_frame
	_check(camera.position.distance_to(train.position) < 0.01, "The camera must track the train while paused or moving.")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	await process_frame
	_check(main.get("_followed_train") == null, "Escape must stop following.")
	main.call("_begin_world_interaction", train.position)
	_check(main.get("_followed_train") == train, "A locomotive can be followed again.")
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	main.call("_unhandled_input", middle)
	_check(main.get("_followed_train") == null, "Panning must stop following.")
	middle.pressed = false
	main.call("_unhandled_input", middle)
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(36.0, -18.0)
	main.call("_unhandled_input", pan)
	_check(camera.position.is_equal_approx(Vector2(-36.0, 18.0)), "Two-finger pan gestures must move the world.")
	var magnify := InputEventMagnifyGesture.new()
	magnify.factor = 1.5
	main.call("_unhandled_input", magnify)
	_check(camera.zoom.is_equal_approx(Vector2.ONE * 1.5), "Pinch magnification must zoom in.")
	magnify.factor = 0.5
	main.call("_unhandled_input", magnify)
	_check(camera.zoom.is_equal_approx(Vector2.ONE * 0.75), "Pinch magnification must also zoom out.")
	main.call("_begin_world_interaction", train.position)
	main.call("_refresh_network")
	_check(main.get("_followed_train") == null, "Redispatch must stop following a removed train.")
	first.max_trains = 7
	var typed_lines: Array[TransitLine] = [first]
	graph.remove_track(first.tracks[0], typed_lines)
	dispatcher.lines.assign(typed_lines)
	dispatcher.rebuild_routes()
	_check(typed_lines.size() == 2 and typed_lines[1].max_trains == 7 and dispatcher.train_limit(typed_lines[1]) == 0, "Fragments inherit the preference but disconnected single stations cannot dispatch trains.")
	_test_loop_limit()
	main.queue_free()
	await process_frame
	if failed:
		quit(1)
	else:
		print("Train controls smoke passed: route caps, natural fleet withdrawal and camera following.")
		quit()

func _count(dispatcher: TransitDispatcher, line_id: int) -> int:
	var total := 0
	for train: Metro in dispatcher.metros:
		if train.line_id == line_id:
			total += 1
	return total

func _test_loop_limit() -> void:
	var graph := TransitGraph.new()
	for position: Vector2 in [Vector2.ZERO, Vector2(576, 0), Vector2(576, 576), Vector2(0, 576)]:
		graph.add_station(position)
	var line := TransitLine.new(0, Color.CYAN)
	for id: int in [0, 1, 2, 3, 0]:
		line.append_station(graph, id)
	line.max_trains = 3
	line.dispatch_rate = 8.0
	var dispatcher := TransitDispatcher.new(graph)
	dispatcher.add_line(line)
	dispatcher.rebuild_routes()
	dispatcher.process(240.0, false)
	_check(dispatcher.metros.size() == 3, "The limit must count trains in both loop directions together (actual %s)." % dispatcher.metros.size())
	_check(dispatcher.route_capacity(line) > 3, "Loop capacity must reflect its two physical circuits.")

func _mouse(view: WorldView, position: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = view.get_global_transform_with_canvas() * position
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame
	await process_frame
