extends SceneTree

var _failed := false
var _exercised := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true

func _run() -> void:
	if OS.get_cmdline_user_args().size() > 1:
		push_error("Intersection smoke accepts at most one scenario prefix.")
		quit(1)
		return
	var graph := TransitGraph.new()
	for position: Vector2 in [Vector2(-576, 0), Vector2.ZERO, Vector2(576, 0), Vector2(0, -576), Vector2(0, 576)]:
		graph.add_station(position)
	var horizontal := TransitLine.new(0, Color.CYAN)
	var vertical := TransitLine.new(1, Color.CORAL)
	for station_id: int in [0, 1, 2]:
		horizontal.append_station(graph, station_id)
	for station_id: int in [3, 1, 4]:
		vertical.append_station(graph, station_id)
	var dispatcher := TransitDispatcher.new(graph)
	for line: TransitLine in [horizontal, vertical]:
		line.dispatch_rate = 8.0
		line.dwell_time = 1.0
		line.wagon_count = 6
		line.cruise_velocity = 150.0
		dispatcher.add_line(line)
	dispatcher.rebuild_routes()
	_exercise(dispatcher, "Perpendicular crossing")

	var junction := TransitGraph.new()
	for position: Vector2 in [Vector2(-576, 0), Vector2.ZERO, Vector2(576, 0), Vector2(0, -576)]:
		junction.add_station(position)
	var through := TransitLine.new(0, Color.CYAN)
	var terminating := TransitLine.new(1, Color.CORAL)
	for station_id: int in [0, 1, 2]:
		through.append_station(junction, station_id)
	for station_id: int in [3, 1]:
		terminating.append_station(junction, station_id)
	terminating.cruise_velocity = 80.0
	terminating.dwell_time = 3.0
	var terminal_dispatcher := TransitDispatcher.new(junction)
	terminal_dispatcher.add_line(through)
	terminal_dispatcher.add_line(terminating)
	terminal_dispatcher.rebuild_routes()
	_exercise(terminal_dispatcher, "Shared terminal and through line")

	var close := TransitGraph.new()
	for position: Vector2 in [Vector2(-576, 0), Vector2.ZERO, Vector2(192, 0), Vector2(768, 0), Vector2(0, -576), Vector2(192, 576)]:
		close.add_station(position)
	var across := TransitLine.new(0, Color.CYAN)
	var branching := TransitLine.new(1, Color.CORAL)
	for station_id: int in [0, 1, 2, 3]:
		across.append_station(close, station_id)
	for station_id: int in [4, 1, 2, 5]:
		branching.append_station(close, station_id)
	across.wagon_count = 6
	branching.wagon_count = 6
	var close_dispatcher := TransitDispatcher.new(close)
	close_dispatcher.add_line(across)
	close_dispatcher.add_line(branching)
	close_dispatcher.rebuild_routes()
	_check(close_dispatcher._last_departures.is_empty(), "Rebuilt lines must start without stale departure regulation.")
	_exercise(close_dispatcher, "Nearby junctions with shared segment")

	var third := TransitLine.new(2, Color.GOLD)
	graph.add_station(Vector2(-576, -576))
	graph.add_station(Vector2(576, 576))
	for station_id: int in [5, 1, 6]:
		third.append_station(graph, station_id)
	third.cruise_velocity = 80.0
	third.dwell_time = 3.0
	dispatcher.add_line(third)
	dispatcher.rebuild_routes()
	_check(dispatcher.metros.is_empty() and dispatcher._last_departures.is_empty(), "Geometry edits must clear trains and departure schedules.")
	_exercise(dispatcher, "Three lines and unequal speeds")
	var single := TransitGraph.new()
	single.add_station(Vector2.ZERO)
	single.add_station(Vector2(384, 0))
	var shuttle := TransitLine.new(0, Color.CYAN)
	shuttle.append_station(single, 0)
	shuttle.append_station(single, 1)
	shuttle.wagon_count = 6
	shuttle.dispatch_rate = 8.0
	shuttle.cruise_velocity = 220.0
	shuttle.dwell_time = 3.0
	var shuttle_dispatcher := TransitDispatcher.new(single)
	shuttle_dispatcher.add_line(shuttle)
	shuttle_dispatcher.rebuild_routes()
	_exercise(shuttle_dispatcher, "Busy single-line terminals")

	var screenshot_graph := TransitGraph.new()
	for position: Vector2 in [Vector2(-576, 0), Vector2(-384, 0), Vector2(0, 0), Vector2(528, -240), Vector2(912, -240), Vector2(-384, -528), Vector2(-384, 480), Vector2(528, 480), Vector2(528, 240), Vector2(528, 0), Vector2(528, -480)]:
		screenshot_graph.add_station(position)
	var blue := TransitLine.new(0, Color.CYAN)
	var orange := TransitLine.new(1, Color.ORANGE)
	for station_id: int in [0, 1, 2, 3, 4]:
		blue.append_station(screenshot_graph, station_id)
	screenshot_graph.track_between(2, 3).waypoints = PackedVector2Array([Vector2.ZERO, Vector2(0, -144), Vector2(384, -144), Vector2(384, -240), Vector2(528, -240)])
	for station_id: int in [5, 1, 6, 7, 8, 9, 3, 10]:
		orange.append_station(screenshot_graph, station_id)
	var screenshot_dispatcher := TransitDispatcher.new(screenshot_graph)
	for line: TransitLine in [blue, orange]:
		line.wagon_count = 6
		line.dispatch_rate = 8.0
		line.cruise_velocity = 220.0
		line.dwell_time = 3.0
		screenshot_dispatcher.add_line(line)
	screenshot_dispatcher.rebuild_routes()
	_exercise(screenshot_dispatcher, "Screenshot layout with terminal queues and tight bends")
	_check(_exercised > 0, "Intersection selector must match at least one scenario.")
	if _failed:
		quit(1)
	else:
		print("Intersection smoke passed: independent lanes, sustained service and safe moving-block gaps.")
		quit()

func _exercise(dispatcher: TransitDispatcher, label: String) -> void:
	if not OS.get_cmdline_user_args().is_empty() and not label.begins_with(OS.get_cmdline_user_args()[0]):
		return
	_exercised += 1
	var count := dispatcher.lines.size()
	var first_half: Array[int] = []
	var final: Array[int] = []
	var directions: Array[bool] = []
	first_half.resize(count)
	first_half.fill(0)
	final.resize(count)
	final.fill(0)
	directions.resize(count * 2)
	directions.fill(false)
	for tick in range(7200):
		dispatcher.process(0.05, false)
		if tick % 20 == 0:
			_check_blocks(dispatcher)
		if tick == 3600:
			for metro: Metro in dispatcher.metros:
				first_half[metro.line_id] += metro.arrival_count
		for metro: Metro in dispatcher.metros:
			if metro.arrival_count >= 2:
				directions[metro.line_id * 2 + (0 if metro.travel_direction == 1 else 1)] = true
	for metro: Metro in dispatcher.metros:
		final[metro.line_id] += metro.arrival_count
	for line_id in range(count):
		_check(first_half[line_id] >= 6, "Both crossing lines must serve their stations.")
		_check(final[line_id] >= first_half[line_id] + 6, "Shared-station traffic must keep making progress instead of deadlocking.")
	for served: bool in directions:
		_check(served, "Crossing service must operate in both directions on both lines.")
	var before_pause := dispatcher._last_departures.duplicate(true)
	dispatcher.process(10.0, true)
	_check(dispatcher._last_departures == before_pause, "Pause must freeze departure regulation.")
	print("%s arrivals: first half %s, final %s" % [label, first_half, final])

func _check_blocks(dispatcher: TransitDispatcher) -> void:
	for a: Metro in dispatcher.metros:
		var total: float = TrackGeometry.route_for_direction(dispatcher.routes[a.line_id], a.travel_direction)["length"]
		for b: Metro in dispatcher.metros:
			if a.id == b.id or not dispatcher._same_circuit(b, a.line_id, a.travel_direction):
				continue
			var gap := fposmod(b.distance - a.distance, total)
			_check(gap >= TrackGeometry.train_length(b.wagon_count) + TrackGeometry.SAFETY_GAP - 0.01, "Moving authority must preserve full-train rear clearance in each independent circuit.")
