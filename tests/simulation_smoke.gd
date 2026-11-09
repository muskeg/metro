extends SceneTree

var _failed := false

func _initialize() -> void:
	_run_test.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true

func _check_route_index(route: Dictionary, label: String) -> void:
	var points: PackedVector2Array = route["points"]
	var cumulative: PackedFloat64Array = route["cumulative_lengths"]
	var total: float = route["length"]
	_check(cumulative.size() == points.size(), "%s route must cache one cumulative distance per point." % label)
	if points.is_empty():
		return
	var distances: Array[float] = [-1.0, 0.0, total, total + 1.0]
	for index in range(points.size()):
		distances.append(cumulative[index])
		if index > 0 and index % 17 == 0:
			distances.append((cumulative[index - 1] + cumulative[index]) * 0.5)
	for distance: float in distances:
		var reference := TrackGeometry.point_at_distance(points, distance)
		var indexed := TrackGeometry.point_at_distance(points, distance, cumulative)
		_check(reference.distance_to(indexed) < 0.0001, "%s indexed lookup must preserve point-at-distance results." % label)
		if total > 0.0:
			var reference_axis := TrackGeometry.car_axis(points, total, distance, distance)
			var indexed_axis := TrackGeometry.car_axis(points, total, distance, distance, cumulative)
			_check(reference_axis.distance_to(indexed_axis) < 0.0001, "%s indexed lookup must preserve car axes." % label)

func _test_parallel_express() -> void:
	var graph := TransitGraph.new()
	for index in range(4):
		graph.add_station(Vector2(0, index * 384))
	var local := TransitLine.new(0, Color.CYAN)
	for station_id in range(4):
		local.append_station(graph, station_id)
	var express := TransitLine.new(1, Color.ORANGE)
	express.append_station(graph, 3)
	express.append_station(graph, 0)
	var lines: Array[TransitLine] = [local, express]
	var corridors := TrackGeometry.corridor_layout(graph, lines)
	_check(corridors["aligned"], "Overlapping express/local geometry must form a shared corridor even with different stop sequences.")
	for line: TransitLine in lines:
		var route := TrackGeometry.circuit(graph, line, lines, corridors)
		_check(route["centerline"] == TrackGeometry.circuit(graph, line, lines)["centerline"], "Cached and standalone corridor construction must agree.")
		_check(route["stops"].size() == 2 * (line.stations.size() - 1), "Sharing a geometric spine must never add express stops.")
		_check_served_stations(graph, line, lines, route)
		var expected_x := 0.0 if line == local else TrackGeometry.CORRIDOR_SPACING
		for probe: Vector2 in [Vector2(0, 192), Vector2(0, 384), Vector2(0, 576), Vector2(0, 768), Vector2(0, 960)]:
			var expected := probe + Vector2(expected_x, 0)
			_check(TrackGeometry.closest_point(route["centerline"], probe).distance_to(expected) < 0.001, "Local and reversed express services must stay straight and separated away from their calls, including skipped stations.")
		_check_route_index(route, "Parallel express/local")
	_check(graph.stations.size() == 4 and graph.tracks.size() == 4, "Corridor alignment must not change graph topology.")
	graph.stations[3].position = Vector2(768, 768)
	graph.track_between(2, 3).waypoints = PackedVector2Array([Vector2(0, 768), Vector2(768, 768)])
	graph.track_between(3, 0).waypoints = PackedVector2Array([Vector2(768, 768), Vector2(0, 768), Vector2.ZERO])
	corridors = TrackGeometry.corridor_layout(graph, lines)
	for line: TransitLine in lines:
		var route := TrackGeometry.circuit(graph, line, lines, corridors)
		_check_served_stations(graph, line, lines, route)
		var offset := 0.0 if line == local else TrackGeometry.CORRIDOR_SPACING
		for probe: Vector2 in [Vector2(0, 576), Vector2(192, 768), Vector2(576, 768)]:
			var expected := probe + (Vector2(offset, 0) if probe.x == 0.0 else Vector2(0, -offset))
			_check(TrackGeometry.closest_point(route["centerline"], probe).distance_to(expected) < 0.001, "Parallel service slots must continue consistently around a shared corner.")
		var corner_distance := TrackGeometry.closest_point(route["centerline"], graph.stations[2].position).distance_to(graph.stations[2].position)
		_check(corner_distance < 6.0 if line == local else corner_distance > 20.0, "A local corner must reach its station without pulling a non-stopping express off its spine.")
		_check_route_index(route, "Parallel express/local corner")

func _check_served_stations(graph: TransitGraph, line: TransitLine, lines: Array[TransitLine], route: Dictionary) -> void:
	var centerline: PackedVector2Array = route["centerline"]
	var lanes: Array = route["running_paths"]
	var count := line.stations.size() - (1 if line.is_loop() else 0)
	for index in range(count):
		var station := graph.stations[line.stations[index]]
		_check(TrackGeometry.closest_point(centerline, station.position).distance_to(station.position) < 6.0, "Every service centerline must reach each of its stations.")
		var serving := 0
		for other: TransitLine in lines:
			if other.stations.has(station.id):
				serving += 1
		for lane: PackedVector2Array in lanes:
			_check(TrackGeometry.closest_point(lane, station.position).distance_to(station.position) <= TrackGeometry.station_radius(serving) + 0.75, "Both running lanes must meet each served station marker.")
	var directions: Array[int] = [1]
	if line.is_loop():
		directions.append(-1)
	for direction: int in directions:
		var circuit := TrackGeometry.route_for_direction(route, direction)
		var points: PackedVector2Array = circuit["points"]
		var stops: PackedFloat32Array = circuit["stops"]
		for index in range(stops.size()):
			var station_index := index
			if line.is_loop() and direction < 0:
				station_index = line.stations.size() - 2 - index
			elif not line.is_loop():
				station_index = index + 1 if index < line.stations.size() - 1 else stops.size() - 1 - index
			var station := graph.stations[line.stations[station_index]]
			var stop := TrackGeometry.point_at_distance(points, stops[index])
			var clearance := TrackGeometry.station_stop_clearance(station.id, lines)
			_check(absf(stop.distance_to(station.position) - clearance) < 1.0, "Each actual train stop must be on the approach side of its own station.")
			if index > 0:
				_check(stops[index] > stops[index - 1], "Stations must remain in travel order after route rebuilding.")

func _test_shared_track_stations() -> void:
	var graph := TransitGraph.new()
	for index in range(3):
		graph.add_station(Vector2(index * 384, 0))
	var first := TransitLine.new(0, Color.CYAN)
	var reverse := TransitLine.new(1, Color.ORANGE)
	for station_id: int in [0, 1, 2]:
		first.append_station(graph, station_id)
	for station_id: int in [2, 1, 0]:
		reverse.append_station(graph, station_id)
	var lines: Array[TransitLine] = [first, reverse]
	var corridors := TrackGeometry.corridor_layout(graph, lines)
	_check(not corridors["aligned"], "Shared physical tracks must also be tested without distinct-edge alignment.")
	var routes: Array[Dictionary] = []
	for line: TransitLine in lines:
		var route := TrackGeometry.circuit(graph, line, lines, corridors)
		routes.append(route)
		_check_served_stations(graph, line, lines, route)
		_check_route_index(route, "Shared physical track")
	for probe: Vector2 in [Vector2(192, 0), Vector2(576, 0)]:
		var first_center := TrackGeometry.closest_point(routes[0]["centerline"], probe)
		var second_center := TrackGeometry.closest_point(routes[1]["centerline"], probe)
		_check(first_center.distance_to(second_center) >= TrackGeometry.CORRIDOR_SPACING - 0.01, "Shared physical tracks must retain separated slots between their stations.")

func _test_collinear_loop_seam() -> void:
	var graph := TransitGraph.new()
	for position: Vector2 in [Vector2.ZERO, Vector2(0, 384), Vector2(768, 384), Vector2(768, 0), Vector2(576, 0), Vector2(384, 0), Vector2(192, 0)]:
		graph.add_station(position)
	var line := TransitLine.new(0, Color.CYAN)
	for station_id: int in [0, 1, 2, 3, 4, 5, 6, 0]:
		line.append_station(graph, station_id)
	var lines: Array[TransitLine] = [line]
	var route := TrackGeometry.circuit(graph, line, lines)
	_check_served_stations(graph, line, lines, route)
	_check_route_index(route, "Collinear loop seam")
	_check_route_index(route["reverse_route"], "Reversed collinear loop seam")

func _run_test() -> void:
	_test_parallel_express()
	_test_shared_track_stations()
	_test_collinear_loop_seam()
	var straight := TransitGraph.new()
	for position: Vector2 in [Vector2.ZERO, Vector2(192, 0), Vector2(576, 0)]:
		straight.add_station(position)
	var straight_line := TransitLine.new(0, Color.CYAN)
	for station_id in range(3):
		straight_line.append_station(straight, station_id)
	var straight_lines: Array[TransitLine] = [straight_line]
	var straight_route := TrackGeometry.circuit(straight, straight_line, straight_lines)
	_check_route_index(straight_route, "Straight")
	var straight_stops: PackedFloat32Array = straight_route["stops"]
	for index in range(4):
		if index == 1 or index == 3:
			continue
		var station_id: int = [1, 2, 1, 0][index]
		var stop := TrackGeometry.point_at_distance(straight_route["points"], straight_stops[index])
		var clearance := TrackGeometry.station_stop_clearance(station_id, straight_lines)
		_check(absf(stop.distance_to(straight.stations[station_id].position) - clearance) < 0.02, "Intermediate stops must put the leading cab just outside the station marker.")
		_check(stop.x < straight.stations[station_id].position.x if index == 0 else stop.x > straight.stations[station_id].position.x, "Each direction must stop on the approach side, not beyond the station.")
	var corner := TransitGraph.new()
	for position: Vector2 in [Vector2(-384, 0), Vector2.ZERO, Vector2(0, -384)]:
		corner.add_station(position)
	var corner_line := TransitLine.new(0, Color.CYAN)
	for station_id in range(3):
		corner_line.append_station(corner, station_id)
	var corner_lines: Array[TransitLine] = [corner_line]
	var corner_route := TrackGeometry.circuit(corner, corner_line, corner_lines)
	_check_route_index(corner_route, "Corner")
	var lanes: Array = corner_route["running_paths"]
	for point: Vector2 in lanes[0]:
		if point.distance_to(corner.stations[1].position) > 64.0:
			continue
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
	_check(graph.path_error(2, 3, crossing).is_empty(), "Independent tracks may cross away from stations without creating an interchange.")
	var original_station_count := graph.stations.size()
	var crossing_track := graph.add_track(2, 3)
	crossing_track.waypoints = crossing
	_check(graph.stations.size() == original_station_count and graph.track_between(0, 2) == null, "A visual crossing must not join the two lines or add a false station.")
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
	_check(not dispatcher.metros.is_empty() and shared_lines.size() == 2, "Deleting an intermediate station must redispatch on reconnected routes, without fragments.")
	previous_arrivals = dispatcher.arrival_count
	for step in range(600):
		dispatcher.process(0.05, false)
		if step % 20 == 0:
			_check_station_blocks(dispatcher)
	_check(dispatcher.arrival_count >= previous_arrivals + 4, "Both shared lines must continue serving stations after shape-preserving deletion.")

	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("startup_layout_enabled", false)
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
	_check(selector.get_child_count() == 3, "Every line should remain selectable with add-line immediately afterward.")
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
