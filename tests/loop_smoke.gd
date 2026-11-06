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
	await process_frame
	var graph: TransitGraph = main.get("graph")
	var line: TransitLine = main.get("active_line")
	for position: Vector2 in [Vector2.ZERO, Vector2(576, 0), Vector2(576, 576), Vector2(0, 576), Vector2(-576, 0)]:
		graph.add_station(position)
	for pair: Array in [[0, 1], [1, 2], [2, 3]]:
		main.call("_connect_stations", pair[0], pair[1])
	_check(not line.can_close(1, 3), "A loop may only connect the two endpoints.")
	_check(not line.append_station(graph, 1), "A line must not revisit an interior station.")
	var short_line := TransitLine.new(0, Color.WHITE)
	short_line.append_station(graph, 0)
	short_line.append_station(graph, 1)
	_check(not short_line.can_close(1, 0) and not short_line.append_station(graph, 0), "Two stations cannot form a loop by reusing the same rail.")
	var view: WorldView = main.get("world_view")
	main.call("_begin_world_interaction", view.station_handle_position(graph.stations[3], Vector2.RIGHT))
	main.call("_extend_stroke", graph.stations[0].position)
	_check(view.route_target_id == 0 and view._preview_error.is_empty(), "Loop closure must show a valid preview.")
	main.call("_end_world_interaction", graph.stations[0].position)
	_check(line.is_loop() and line.stations == [0, 1, 2, 3, 0] and line.tracks.size() == 4, "Drawing back to the first station must close the line.")
	_check(not line.can_extend_from(0) and not line.append_station(graph, 4), "A closed line cannot be extended.")
	if DisplayServer.get_name() != "headless":
		main.set("paused", true)
		main.set_process(false)
		main.call("_clear_hover")
		view.selected_station_id = -1
		var camera: Camera2D = main.get("camera")
		view.set_dynamic_state([], camera.get_screen_center_position(), camera.zoom, 0.5)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var screen := view.get_global_transform_with_canvas() * Vector2(0, 288)
		var pixel := image.get_pixelv(Vector2i(screen))
		_check(absf(pixel.r - line.color.r) + absf(pixel.g - line.color.g) + absf(pixel.b - line.color.b) < 0.05, "The closing rail must be visible in the selected line color.")
	var closure_id := graph.track_between(0, 3).id
	main.call("_connect_stations", 0, 3)
	_check(line.is_loop() and line.tracks.size() == 4 and graph.track_between(0, 3).id == closure_id, "A loop rail must remain redrawable without duplicating it.")
	var route := TrackGeometry.circuit(graph, line, [line])
	for direction in [1, -1]:
		var lane := TrackGeometry.route_for_direction(route, direction)
		var points: PackedVector2Array = lane["points"]
		var stops: PackedFloat32Array = lane["stops"]
		_check(points[0].distance_to(points[points.size() - 1]) < 0.01, "Each running lane must close without a teleport.")
		_check(stops.size() == 4, "Each direction must stop once at every station.")
		for index in range(stops.size()):
			if index > 0:
				_check(stops[index] > stops[index - 1], "Loop stops must be in travel order.")
			var station_id: int = [0, 1, 2, 3][index] if direction == 1 else [3, 2, 1, 0][index]
			var stop := TrackGeometry.point_at_distance(points, stops[index])
			_check(stop.distance_to(graph.stations[station_id].position) < 30.0, "Loop stops must remain near their stations.")
	var other := TransitLine.new(1, Color.CORAL)
	other.append_station(graph, 4)
	other.append_station(graph, 0)
	other.append_station(graph, 1)
	var dispatcher := TransitDispatcher.new(graph)
	for service: TransitLine in [line, other]:
		service.wagon_count = 4
		service.dispatch_rate = 12.0
		service.dwell_time = 1.0
		service.cruise_velocity = 100.0
		dispatcher.add_line(service)
	dispatcher.rebuild_routes()
	var shared_route: Dictionary = dispatcher.routes[0]
	for direction in [1, -1]:
		var lane := TrackGeometry.route_for_direction(shared_route, direction)
		var points: PackedVector2Array = lane["points"]
		var stops: PackedFloat32Array = lane["stops"]
		_check(points[0].distance_to(points[points.size() - 1]) < 0.01, "Shared-track offsets must still produce a closed loop.")
		for index in range(stops.size()):
			if index > 0:
				_check(stops[index] > stops[index - 1], "Shared-track loop stops must remain ordered.")
			var station_id: int = [0, 1, 2, 3][index] if direction == 1 else [3, 2, 1, 0][index]
			_check(TrackGeometry.point_at_distance(points, stops[index]).distance_to(graph.stations[station_id].position) < 50.0, "Shared-track stops must remain near their stations.")
	var arrivals := [0, 0]
	var second_half := [0, 0]
	var directions := [false, false]
	for tick in range(2400):
		dispatcher.process(0.05, false)
		for metro: Metro in dispatcher.metros:
			if metro.line_id == 0 and metro.arrival_count >= 2:
				directions[0 if metro.travel_direction == 1 else 1] = true
		if tick == 1199:
			for metro: Metro in dispatcher.metros:
				arrivals[metro.line_id] += metro.arrival_count
		if tick % 20 == 0:
			_check_bodies(dispatcher)
	for metro: Metro in dispatcher.metros:
		second_half[metro.line_id] += metro.arrival_count
	_check(directions[0] and directions[1], "Both loop directions must serve stations continuously.")
	for index in range(2):
		_check(arrivals[index] >= 2 and second_half[index] >= arrivals[index] + 2, "Loop and shared-station service must continue without deadlock.")

	var lines: Array[TransitLine] = [line]
	var closing_track := graph.track_between(3, 0)
	_check(graph.insert_station(closing_track.id, Vector2(0, 288), lines).is_empty(), "A station can be inserted on the closing track.")
	_check(line.is_loop() and line.stations == [0, 1, 2, 3, 5, 0], "Insertion must preserve the closed station sequence.")
	graph.remove_track(graph.track_between(1, 2).id, lines)
	_check(lines.size() == 1 and not line.is_loop() and line.stations == [2, 3, 5, 0, 1], "Deleting any loop rail must open one continuous line.")
	_check(line.can_close(1, 2), "An opened loop must be closable again from either endpoint.")
	main.call("_connect_stations", 2, 1)
	_check(line.is_loop() and line.stations == [2, 3, 5, 0, 1, 2], "Drawing from the first endpoint must also close a loop.")
	main.queue_free()

	var deleted := TransitGraph.new()
	for position: Vector2 in [Vector2.ZERO, Vector2(576, 0), Vector2(576, 576), Vector2(0, 576)]:
		deleted.add_station(position)
	var ring := TransitLine.new(0, Color.CYAN)
	for id: int in [0, 1, 2, 3, 0]:
		ring.append_station(deleted, id)
	var rings: Array[TransitLine] = [ring]
	deleted.remove_station(1, rings)
	_check(rings.size() == 1 and ring.stations == [1, 2, 0] and ring.tracks.size() == 2, "Deleting a loop station must preserve all remaining connected rails.")
	_check_openings()
	if failed:
		quit(1)
	else:
		print("Loop smoke passed: drawing, two-way circulation, shared junctions and editing.")
		quit()

func _check_openings() -> void:
	for delete_station in [false, true]:
		for target in range(4):
			var graph := TransitGraph.new()
			for position: Vector2 in [Vector2.ZERO, Vector2(576, 0), Vector2(576, 576), Vector2(0, 576)]:
				graph.add_station(position)
			var line := TransitLine.new(0, Color.CYAN)
			for station_id: int in [0, 1, 2, 3, 0]:
				line.append_station(graph, station_id)
			var lines: Array[TransitLine] = [line]
			if delete_station:
				graph.remove_station(target, lines)
			else:
				graph.remove_track(graph.track_between(target, (target + 1) % 4).id, lines)
			_check(lines.size() == 1 and not line.is_loop(), "Removing any station or rail must open exactly one line.")
			_check(line.stations.size() == (3 if delete_station else 4) and line.tracks.size() == line.stations.size() - 1, "Opening a loop must preserve every surviving station and rail.")
			for index in range(line.tracks.size()):
				_check(graph.track_between(line.stations[index], line.stations[index + 1]).id == line.tracks[index], "Opened-loop tracks must match their station order.")

func _check_bodies(dispatcher: TransitDispatcher) -> void:
	for index in range(dispatcher.metros.size()):
		var a := dispatcher.metros[index]
		var route_a := TrackGeometry.route_for_direction(dispatcher.routes[a.line_id], a.travel_direction)
		var body_a := dispatcher._body_points(route_a["points"], route_a["length"], a.distance, a.wagon_count)
		for other_index in range(index + 1, dispatcher.metros.size()):
			var b := dispatcher.metros[other_index]
			var route_b := TrackGeometry.route_for_direction(dispatcher.routes[b.line_id], b.travel_direction)
			var body_b := dispatcher._body_points(route_b["points"], route_b["length"], b.distance, b.wagon_count)
			for point: Vector2 in body_a:
				for other: Vector2 in body_b:
					_check(point.distance_squared_to(other) >= 99.9, "Loop trains must not overlap, including wagons.")
