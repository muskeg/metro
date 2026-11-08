extends SceneTree

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition and not failed:
		push_error(message)
		failed = true

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1 or (not args.is_empty() and args[0] != "--fast"):
		push_error("Usage: terminal_smoke.gd [-- --fast]")
		quit(1)
		return
	var fast := args.has("--fast")
	for wagons in range(1, 7):
		for endpoint: Vector2 in [Vector2(576, 0), Vector2(0, 576), Vector2(576, 576)]:
			var graph := TransitGraph.new()
			graph.add_station(Vector2.ZERO)
			graph.add_station(endpoint)
			var line := TransitLine.new(0, Color.CYAN)
			line.append_station(graph, 0)
			line.append_station(graph, 1)
			if endpoint == Vector2(576, 576):
				graph.tracks[0].waypoints = PackedVector2Array([Vector2.ZERO, Vector2(0, 144), Vector2(576, 144), endpoint])
			line.wagon_count = wagons
			line.max_trains = 6
			line.dispatch_rate = 1.0
			var dispatcher := TransitDispatcher.new(graph)
			dispatcher.add_line(line)
			dispatcher.rebuild_routes()
			var route: Dictionary = dispatcher.routes[0]
			var points: PackedVector2Array = route["points"]
			var total: float = route["length"]
			_check(route["terminal_ready"], "Terminal fixtures must accommodate the full train and crossover.")
			for stop_index in range(route["stops"].size()):
				var stop: float = route["stops"][stop_index]
				var station := graph.stations[1 if stop_index == 0 else 0]
				var head := TrackGeometry.point_at_distance(points, stop)
				_check(head.distance_to(station.position) >= 12.0 + TrackGeometry.CAR_LENGTH * 0.5 + TrackGeometry.TERMINAL_GAP - 0.02, "Stopped terminal cabs must leave a measurable gap outside the opaque station.")
				_check_platform_clearance(route, wagons, stop, station.position, 12.0)
				for car in range(wagons + 1):
					var old := TrackGeometry.car_position(points, total, stop, car)
					var reversed := TrackGeometry.car_position(points, total, fposmod(stop + TrackGeometry.reversal_distance(route, wagons, stop_index), total), wagons - car)
					_check(old.distance_to(reversed) < 0.02, "Switching cabs must preserve every physical car position without lateral sliding or teleporting.")
					_check(absf(TrackGeometry.car_axis(points, total, stop - car * TrackGeometry.CAR_PITCH, stop).length() - 1.0) < 0.001, "Terminal car axes must stay defined at the reversal cusp.")
			var reversals := 0
			for tick in range(2400):
				var old_poses := {}
				for train: Metro in dispatcher.metros:
					old_poses[train.id] = [train.reverse_pending, train.distance]
				dispatcher.process(0.05, false)
				for train: Metro in dispatcher.metros:
					if old_poses.has(train.id) and old_poses[train.id][0] and not train.reverse_pending:
						reversals += 1
						for car in range(wagons + 1):
							var before := TrackGeometry.car_position(points, total, old_poses[train.id][1], car)
							var after := TrackGeometry.car_position(points, total, train.distance, wagons - car)
							_check(before.distance_to(after) < 1.0, "Actual departures must reverse in place before accelerating out of the station.")
					for other: Metro in dispatcher.metros:
						if train.id == other.id:
							continue
						var gap := fposmod(other.distance - train.distance, total)
						_check(gap >= TrackGeometry.train_length(wagons) + TrackGeometry.SAFETY_GAP - 0.02, "Reversal must preserve moving-block clearance after reindexing the leading car.")
				for terminal in range(2):
					var occupants := 0
					var entry: float = route["terminal_entries"][terminal]
					var exit: float = route["terminal_exits"][terminal]
					for train: Metro in dispatcher.metros:
						var within := fposmod(train.distance - entry, total)
						if within > 0.02 and within < fposmod(exit - entry, total) + wagons * TrackGeometry.CAR_PITCH + TrackGeometry.CAR_LENGTH:
							occupants += 1
							_check(dispatcher._terminal_owners.get("0:%d" % terminal, -1) == train.id, "A train inside the protected terminal must own its reservation.")
					_check(occupants <= 1, "Opposing arrivals and departures must never share a terminal crossover.")
				if failed:
					quit(1)
					return
				if fast and reversals >= 4 and dispatcher.arrival_count >= 6:
					break
			_check(reversals >= 4 and dispatcher.arrival_count >= 6, "Protected terminal service must keep reversing and serving both ends without deadlock.")
			var owners := dispatcher._terminal_owners.duplicate()
			dispatcher.process(2.0, true)
			_check(owners == dispatcher._terminal_owners, "Pause must preserve terminal reservations.")
			dispatcher.rebuild_routes()
			_check(dispatcher._terminal_owners.is_empty(), "Rebuilds must clear terminal reservations.")
	for wagons in range(1, 7):
		var shared_graph := TransitGraph.new()
		shared_graph.add_station(Vector2.ZERO)
		shared_graph.add_station(Vector2(576, 0))
		var shared_line := TransitLine.new(0, Color.CYAN)
		shared_line.append_station(shared_graph, 0)
		shared_line.append_station(shared_graph, 1)
		shared_line.wagon_count = wagons
		var origin_line := TransitLine.new(1, Color.RED)
		origin_line.stations = [0]
		var far_line := TransitLine.new(2, Color.GREEN)
		far_line.stations = [1]
		var far_line_two := TransitLine.new(3, Color.BLUE)
		far_line_two.stations = [1]
		var shared_lines: Array[TransitLine] = [shared_line, origin_line, far_line, far_line_two]
		var shared_route := TrackGeometry.circuit(shared_graph, shared_line, shared_lines)
		_check(is_equal_approx(shared_route["terminal_insets"][0], 15.0 + TrackGeometry.CAR_LENGTH * 0.5 + TrackGeometry.TERMINAL_GAP) and is_equal_approx(shared_route["terminal_insets"][1], 18.0 + TrackGeometry.CAR_LENGTH * 0.5 + TrackGeometry.TERMINAL_GAP), "Terminal offsets must independently follow each station's serving-line radius.")
		for stop_index in range(2):
			var stop: float = shared_route["stops"][stop_index]
			var station_id := 1 - stop_index
			var radius := 18.0 if station_id == 1 else 15.0
			var center := TrackGeometry.point_at_distance(shared_route["points"], stop)
			_check(center.distance_to(shared_graph.stations[station_id].position) >= radius + TrackGeometry.CAR_LENGTH * 0.5 + TrackGeometry.TERMINAL_GAP - 0.02, "Shared terminal cabs must also clear the larger rings.")
			_check_platform_clearance(shared_route, wagons, stop, shared_graph.stations[station_id].position, radius)
			for car in range(wagons + 1):
				var before := TrackGeometry.car_position(shared_route["points"], shared_route["length"], stop, car)
				var after := TrackGeometry.car_position(shared_route["points"], shared_route["length"], fposmod(stop + TrackGeometry.reversal_distance(shared_route, wagons, stop_index), shared_route["length"]), wagons - car)
				_check(before.distance_to(after) < 0.02, "Different terminal radii must not introduce a car jump on reversal.")
	var short_graph := TransitGraph.new()
	short_graph.add_station(Vector2.ZERO)
	short_graph.add_station(Vector2(288, 0))
	var short_line := TransitLine.new(0, Color.CYAN)
	short_line.append_station(short_graph, 0)
	short_line.append_station(short_graph, 1)
	var short_service := TransitDispatcher.new(short_graph)
	short_service.add_line(short_line)
	short_service.rebuild_routes()
	_check(short_service.route_capacity(short_line) == 1, "Short lines without room to clear one terminal before the other must avoid opposing-terminal deadlock.")
	for second in range(120):
		short_service.process(1.0, false)
		if fast and short_service.arrival_count >= 4:
			break
	_check(short_service.arrival_count >= 4, "A short single-train line must keep reversing rather than deadlock at its terminal locks.")
	if failed:
		quit(1)
	else:
		if fast:
			print("Fast terminal checks: all wagon/orientation fixtures reached reversal/arrival thresholds; full 120s soaks not run.")
		print("Terminal smoke passed: in-place cab reversal, visible two-lane convergence, one-train protection and sustained service for 1-6 wagons.")
		quit()

func _check_platform_clearance(route: Dictionary, wagons: int, stop: float, position: Vector2, radius: float) -> void:
	var train := Metro.new(0, 0, TrackGeometry.point_at_distance(route["points"], stop))
	train.distance = stop
	train.wagon_count = wagons
	var visit := StationVisit.new(train, route, 3.0, true)
	_check(not Geometry2D.is_point_in_polygon(position, visit.platform), "Stopped platforms must not enclose the terminal marker.")
	for index in range(visit.platform.size()):
		var closest := Geometry2D.get_closest_point_to_segment(position, visit.platform[index], visit.platform[(index + 1) % visit.platform.size()])
		_check(closest.distance_to(position) > radius + 2.5, "Every edge of the continuous terminal platform must clear the marker with a visible gap.")
