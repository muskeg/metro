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
	main.set("startup_layout_enabled", false)
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
	_wait_for_fleets(dispatcher, [4, 2], 100.0)
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
	_wait_for_fleets(dispatcher, [1, 2], 80.0)
	_check(_count(dispatcher, 0) == 1 and _count(dispatcher, 1) == 2 and dispatcher.metros.has(independent_train), "Surplus trains must retire at termini without redispatching independent lines.")
	var kept := dispatcher.metros[0]
	slider.value = 3.0
	_check(dispatcher.metros.has(kept), "Raising a limit must not interrupt existing trains.")
	_wait_for_fleets(dispatcher, [3, 2], 80.0)
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
	main.set_process(false)
	var fleet := dispatcher.metros.duplicate()
	dispatcher.metros.assign([train])
	train.render_pose_valid = true
	train.render_distance = train.distance + 100.0
	for zoom: float in [0.02, 0.08, 0.4, 0.79]:
		camera.zoom = Vector2.ONE * zoom
		view._train_trails.clear()
		train.render_distance = train.distance + 20.0
		view.set_dynamic_state([train], camera.position, camera.zoom, 0.5)
		train.render_distance = train.distance + 100.0
		view.set_dynamic_state([train], camera.position, camera.zoom, 0.5, [], 1.0)
		var path := view.overview_train_path(train, dispatcher.routes[0], zoom)
		for point: Vector2 in [path[path.size() - 1], path[path.size() / 2]]:
			_check(main.call("_train_near", point) == train, "Overview picking must follow the interpolated comet head and tail at every zoom.")
	train.render_pose_valid = false
	_test_comet_geometry(view, train, dispatcher.routes[0])
	dispatcher.metros.assign(fleet)
	main.set_process(true)
	main.call("_begin_world_interaction", train.position)
	main.call("_refresh_network")
	_check(main.get("_followed_train") == null, "Redispatch must stop following a removed train.")
	first.max_trains = 7
	first.render_priority = 3
	var typed_lines: Array[TransitLine] = [first]
	graph.remove_track(first.tracks[0], typed_lines)
	dispatcher.lines.assign(typed_lines)
	dispatcher.rebuild_routes()
	_check(typed_lines.size() == 2 and typed_lines[1].max_trains == 7 and typed_lines[1].render_priority == 3 and dispatcher.train_limit(typed_lines[1]) == 0, "Fragments inherit fleet and layer preferences but disconnected single stations cannot dispatch trains.")
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

func _test_comet_geometry(view: WorldView, train: Metro, open_route: Dictionary) -> void:
	var points := PackedVector2Array([Vector2.ZERO, Vector2(100, 0), Vector2(100, 100), Vector2(0, 100), Vector2.ZERO])
	var route := {"points": points, "cumulative_lengths": TrackGeometry.cumulative_lengths(points), "length": 400.0}
	train.render_pose_valid = true
	var routes: Dictionary = view._routes
	view._routes = routes.duplicate()
	view._routes[train.line_id] = route
	var lengths := PackedFloat64Array()
	for speed: float in [10.0, 30.0]:
		view._train_trails.clear()
		train.render_distance = 0.0
		view.set_dynamic_state([train], Vector2.ZERO, Vector2.ONE * 0.1, 0.5)
		for step in range(1, 31):
			train.render_distance = speed * step * 0.1
			view.set_dynamic_state([train], Vector2.ZERO, Vector2.ONE * 0.1, 0.5, [], 0.1)
		lengths.append(TrackGeometry.length(view.overview_train_path(train, route, 0.1)))
	_check(absf(lengths[1] / lengths[0] - 3.0) < 0.001, "Below the train-length cap, tripling speed must triple trail length for the same one-second lifetime.")
	var wagons := train.wagon_count
	for wagon_count: int in [1, 3, 8]:
		train.wagon_count = wagon_count
		view._train_trails.clear()
		train.render_distance = 0.0
		view.set_dynamic_state([train], Vector2.ZERO, Vector2.ONE * 0.1, 0.5)
		for step in range(1, 31):
			train.render_distance = 10.0 * step
			view.set_dynamic_state([train], Vector2.ZERO, Vector2.ONE * 0.1, 0.5, [], 1.0 / 30.0)
		for zoom: float in [0.02, 0.15, 0.79]:
			_check(absf(TrackGeometry.length(view.overview_train_path(train, route, zoom)) - TrackGeometry.train_length(wagon_count) * 1.5) < 0.01, "At speed, each tail must reach 1.5 times its physical train length, not a fixed screen length.")
	train.wagon_count = wagons
	for head: float in [10.0, 110.0, 390.0]:
		for zoom: float in [0.02, 0.4, 0.79]:
			view._train_trails.clear()
			train.render_distance = fposmod(head - 90.0, 400.0)
			view.set_dynamic_state([train], Vector2.ZERO, Vector2.ONE * zoom, 0.5)
			for step in range(1, 31):
				train.render_distance = fposmod(head - 90.0 + 3.0 * step, 400.0)
				view.set_dynamic_state([train], Vector2.ZERO, Vector2.ONE * zoom, 0.5, [], 1.0 / 30.0)
			var path := view.overview_train_path(train, route, zoom)
			_check(absf(TrackGeometry.length(path) - minf(TrackGeometry.train_length(train.wagon_count) * 1.5, 90.0)) < 0.01, "Timed tails must show travelled distance, capped at 1.5 train lengths regardless of zoom.")
			_check(path[path.size() - 1].is_equal_approx(TrackGeometry.point_at_distance(points, head)), "Comet head must match the interpolated position through loop wrap.")
			for index in range(1, path.size()):
				for fraction: float in [0.25, 0.5, 0.75]:
					var point := path[index - 1].lerp(path[index], fraction)
					_check(TrackGeometry.closest_point(points, point).distance_to(point) < 0.001, "Comets must include route vertices and never cut corners.")
			var frozen := view.overview_train_trail(train, route, zoom)
			var ages: PackedFloat64Array = frozen["ages"]
			for index in range(1, ages.size()):
				_check(ages[index] <= ages[index - 1] + 0.000001, "Older trail points must fade before more recently travelled points.")
			view.set_dynamic_state([train], Vector2.ZERO, Vector2.ONE * zoom, 0.5, [], 0.0)
			_check(view.overview_train_trail(train, route, zoom) == frozen, "Pausing must freeze trail geometry and ages.")
			view.set_dynamic_state([train], Vector2.ZERO, Vector2.ONE * zoom, 0.5, [], 0.4)
			var faded := view.overview_train_trail(train, route, zoom)
			_check(faded["ages"][faded["ages"].size() - 1] > 0.39, "A stopped train must leave an ageing trace, not a freshly relit tail.")
			var shortened: PackedVector2Array = faded["path"]
			_check(TrackGeometry.length(shortened) < TrackGeometry.length(path) * 0.7, "At rest, the trail must retract from its rear instead of dimming the entire original segment.")
			_check(shortened[shortened.size() - 1].is_equal_approx(path[path.size() - 1]), "Tail erosion must leave the comet head fixed.")
			view.set_dynamic_state([train], Vector2.ZERO, Vector2.ONE * zoom, 0.5, [], 0.7)
			_check(view.overview_train_path(train, route, zoom).size() == 1, "The tail must disappear after one second at rest, leaving the head.")
	view._routes = routes
	view._train_trails.clear()
	var end: float = open_route["outbound_end"]
	for head: float in [0.0, 1.0, end + 1.0]:
		train.render_distance = head
		var path := view.overview_train_path(train, open_route, 0.02)
		_check(TrackGeometry.length(path) <= 1.01, "A new terminal departure must not trail back over the opposite leg.")
	train.render_distance = end - 20.0
	view.set_dynamic_state([train], Vector2.ZERO, Vector2.ONE * 0.1, 0.5)
	train.render_distance = end - 10.0
	view.set_dynamic_state([train], Vector2.ZERO, Vector2.ONE * 0.1, 0.5, [], 0.1)
	train.render_distance = end + 50.0
	view.set_dynamic_state([train], Vector2.ZERO, Vector2.ONE * 0.1, 0.5, [], 0.1)
	_check(view.overview_train_path(train, open_route, 0.1).size() == 1, "Cab reversal must reset the trace instead of drawing a teleport across terminal geometry.")
	view.set_dynamic_state([], Vector2.ZERO, Vector2.ONE, 0.5)
	_check(view._train_trails.is_empty(), "Retired trains must release their trace history.")
	for zoom: float in [0.5, 0.6, 0.7, 0.8]:
		var opacity := view.overview_opacity(zoom)
		_check(opacity >= 0.0 and opacity <= 1.0, "Crossfade opacity must remain bounded.")
	_check(is_equal_approx(view.overview_opacity(0.65), 0.5), "The marker and real cars must share the middle of the smooth zoom transition.")
	view.view_zoom = Vector2.ONE * 0.1
	view._visible_world = Rect2(Vector2(50, -5), Vector2(10, 10))
	_check(view._poses_visible({"positions": PackedVector2Array([Vector2(1000, 1000)]), "overview_path": PackedVector2Array([Vector2.ZERO, Vector2(100, 0)])}), "A visible comet tail must not be culled when its real cars are offscreen.")
	train.render_pose_valid = false

func _wait_for_fleets(dispatcher: TransitDispatcher, expected: Array[int], timeout: float) -> void:
	var elapsed := 0.0
	while true:
		var ready := true
		for line_id in range(expected.size()):
			ready = ready and _count(dispatcher, line_id) == expected[line_id]
		if ready:
			return
		if elapsed >= timeout:
			break
		var step := minf(1.0, timeout - elapsed)
		dispatcher.process(step, false)
		elapsed += step
	_check(false, "Fleet setup must reach %s within %.0f simulated seconds." % [expected, timeout])

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
	_wait_for_fleets(dispatcher, [3], 240.0)
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
