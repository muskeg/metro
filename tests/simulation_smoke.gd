extends SceneTree

var _failed := false

func _initialize() -> void:
	_run_test.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true

func _run_test() -> void:
	var straight := TransitGraph.new()
	for position: Vector2 in [Vector2.ZERO, Vector2(192, 0), Vector2(576, 0)]:
		straight.add_station(position)
	var straight_line := TransitLine.new(0, Color.CYAN)
	for station_id in range(3):
		straight_line.append_station(straight, station_id)
	var straight_lines: Array[TransitLine] = [straight_line]
	var straight_route := TrackGeometry.circuit(straight, straight_line, straight_lines)
	var straight_stops: PackedFloat32Array = straight_route["stops"]
	for index in range(4):
		var station_id: int = [1, 2, 1, 0][index]
		var stop := TrackGeometry.point_at_distance(straight_route["points"], straight_stops[index])
		_check(stop.distance_to(straight.stations[station_id].position) <= TrackGeometry.LANE_OFFSET + 0.1, "Route smoothing must keep every intermediate station stop at its actual position.")
	var corner := TransitGraph.new()
	for position: Vector2 in [Vector2(-384, 0), Vector2.ZERO, Vector2(0, -384)]:
		corner.add_station(position)
	var corner_line := TransitLine.new(0, Color.CYAN)
	for station_id in range(3):
		corner_line.append_station(corner, station_id)
	var corner_lines: Array[TransitLine] = [corner_line]
	var corner_route := TrackGeometry.circuit(corner, corner_line, corner_lines)
	var lanes: Array = corner_route["running_paths"]
	for point: Vector2 in lanes[0]:
		for other: Vector2 in lanes[1]:
			_check(point.distance_squared_to(other) >= 100.0, "Opposing running lanes must not pinch together at a station corner.")
	var graph := TransitGraph.new()
	graph.add_station(Vector2.ZERO)
	graph.add_station(Vector2(576.0, 192.0))
	var track := graph.add_track(0, 1)
	track.waypoints = PackedVector2Array([Vector2.ZERO, Vector2(192.0, 0.0), Vector2(192.0, 192.0), Vector2(576.0, 192.0)])
	_check(graph.path_error(0, 1, track.waypoints).is_empty(), "A valid snapped stroke should be accepted.")
	var samples := TrackGeometry.sample(graph, track)
	_check(samples[0] == Vector2.ZERO and samples[samples.size() - 1] == Vector2(576.0, 192.0), "The stroke must retain station endpoints.")
	_check(samples.has(Vector2(192.0, 24.0)), "Corners should be rounded without replacing the player's path.")
	var line := TransitLine.new(0, Color("#58b8bd"))
	line.append_station(graph, 0)
	line.append_station(graph, 1)
	line.dispatch_rate = 8.0
	line.dwell_time = 1.0
	line.cruise_velocity = 90.0
	line.wagon_count = 4
	var dispatcher := TransitDispatcher.new(graph)
	dispatcher.add_line(line)
	dispatcher.rebuild_routes()
	dispatcher.process(0.2, false)
	_check(dispatcher.metros.size() == 2, "Dispatch should start service at both ends on separate tracks.")
	var saw_forward := false
	var saw_return := false
	var simultaneous_ticks := 0
	for step in range(1200):
		dispatcher.process(0.05, false)
		var forward_now := false
		var return_now := false
		for metro: Metro in dispatcher.metros:
			saw_forward = saw_forward or (metro.travel_direction == 1 and metro.moving)
			saw_return = saw_return or (metro.travel_direction == -1 and metro.moving)
			forward_now = forward_now or (metro.travel_direction == 1 and metro.moving)
			return_now = return_now or (metro.travel_direction == -1 and metro.moving)
			_check(metro.wagon_count == 4, "A dispatched train should retain its wagon count.")
		if forward_now and return_now:
			simultaneous_ticks += 1
		if step % 20 == 0:
			_check_station_blocks(dispatcher)
	_check(saw_forward and saw_return, "Both directions should actually move.")
	_check(simultaneous_ticks >= 20, "Both directions must move simultaneously, not just alternate on one lane.")
	_check(dispatcher.arrival_count >= 6, "Both directions should serve the stations without gridlock.")
	var distances: Array[float] = []
	for metro: Metro in dispatcher.metros:
		distances.append(metro.distance)
	dispatcher.process(3.0, true)
	for index in range(distances.size()):
		_check(is_equal_approx(distances[index], dispatcher.metros[index].distance), "Pause must freeze the full train.")
	dispatcher.rebuild_routes()
	_check(dispatcher.metros.is_empty(), "Geometry edits must redispatch trains rather than teleport them.")

	graph.add_station(Vector2(288.0, -192.0))
	graph.add_station(Vector2(288.0, 384.0))
	var crossing := PackedVector2Array([Vector2(288.0, -192.0), Vector2(288.0, 384.0)])
	_check(not graph.path_error(2, 3, crossing).is_empty(), "Unsignalled crossings should be refused explicitly.")
	var self_cross := PackedVector2Array([Vector2.ZERO, Vector2(288.0, 192.0), Vector2(0.0, 192.0), Vector2(288.0, 0.0), Vector2(576.0, 192.0)])
	_check(not graph.path_error(0, 1, self_cross).is_empty(), "Self-crossing strokes must be rejected.")

	var other_line := TransitLine.new(1, Color("#e98668"))
	other_line.append_station(graph, 1)
	other_line.append_station(graph, 0)
	other_line.wagon_count = 6
	other_line.dispatch_rate = 8.0
	other_line.dwell_time = 0.5
	dispatcher.add_line(other_line)
	dispatcher.rebuild_routes()
	var served: Array[bool] = [false, false]
	for step in range(600):
		dispatcher.process(0.05, false)
		for metro: Metro in dispatcher.metros:
			if metro.arrival_count > 0:
				served[metro.line_id] = true
		if step % 20 == 0:
			_check_station_blocks(dispatcher)
	_check(served[0] and served[1], "Shared-track routes with opposite station order must both serve their stations.")
	var shared_lines: Array[TransitLine] = [line, other_line]
	_check(graph.insert_station(0, Vector2(192.0, 96.0), shared_lines).is_empty(), "Shared curved rails must support intermediate stations.")
	dispatcher.rebuild_routes()
	var previous_arrivals := dispatcher.arrival_count
	for step in range(600):
		dispatcher.process(0.05, false)
		if step % 20 == 0:
			_check_station_blocks(dispatcher)
	_check(dispatcher.arrival_count >= previous_arrivals + 4, "Both shared lines must continue serving stations after insertion.")
	_check(dispatcher.routes[0]["stops"].size() == 4 and dispatcher.routes[1]["stops"].size() == 4, "Inserted stations must be served in both directions on every line.")
	graph.remove_station(4, shared_lines)
	dispatcher.lines.assign(shared_lines)
	dispatcher.rebuild_routes()
	dispatcher.process(0.2, false)
	_check(dispatcher.metros.is_empty(), "Deleting an intermediate station must remove trains from the disconnected fragments.")

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var main_graph: TransitGraph = main.get("graph")
	main_graph.add_station(Vector2.ZERO)
	main_graph.add_station(Vector2(384.0, 192.0))
	main.call("_begin_world_interaction", Vector2(32.0, 0.0))
	main.call("_pin_route_bend", Vector2(192.0, 0.0))
	main.call("_pin_route_bend", Vector2(192.0, 192.0))
	main.call("_end_world_interaction", Vector2(384.0, 192.0))
	var main_lines: Array = main.get("lines")
	_check(main_lines[0].stations == [0, 1], "Elastic drawing should connect the actual starting station.")
	_check(main_graph.tracks[0].waypoints.size() == 4, "The drawing must preserve explicitly pinned bends.")
	var original_path := main_graph.tracks[0].waypoints.duplicate()
	main.call("_begin_world_interaction", Vector2(32.0, 0.0))
	main.call("_pin_route_bend", Vector2(0.0, 192.0))
	main.call("_end_world_interaction", Vector2(384.0, 192.0))
	_check(main_graph.tracks[0].waypoints != original_path and main_lines[0].tracks.size() == 1, "Redrawing should replace geometry without duplicating the route.")
	main.call("_create_line")
	await process_frame
	var selector: HBoxContainer = main.get("_line_selector")
	_check(selector.get_child_count() == 2, "Every line should remain selectable.")
	main.call("_select_line", 0)
	main.call("_on_wagon_changed", 3.0)
	_check(main_lines[0].wagon_count == 3, "The wagon setting should apply to the selected line.")
	main.call("_begin_world_interaction", Vector2(32.0, 0.0))
	main.call("_extend_stroke", Vector2(48.0, 0.0))
	main.call("_cancel_gesture")
	_check(main.get("_connect_drag_source_id") == -1, "Cancellation must release the drawing gesture.")
	main.call("_move_station_to", 1, Vector2(432.0, 240.0))
	_check(main_graph.stations[1].position == Vector2(432.0, 240.0), "Moving a station must update the route endpoint.")
	main.call("_toggle_settings")
	_check(main.get("_settings_popup").visible, "The settings menu should remain available.")
	_check(ProjectSettings.get_setting("application/config/name") == "Metro", "The game must be named Metro.")
	main.queue_free()
	await process_frame
	if _failed:
		quit(1)
	else:
		print("Metro simulation and drawing smoke tests passed.")
		quit()

func _check_station_blocks(dispatcher: TransitDispatcher) -> void:
	for train: Metro in dispatcher.metros:
		_check(dispatcher.movement_authority(train) >= 0.0, "Movement authority must remain nonnegative.")
		_check(train.speed <= dispatcher.lines[train.line_id].cruise_velocity + 0.01, "Regulation must not exceed the maximum cruise speed.")
