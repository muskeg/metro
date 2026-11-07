extends SceneTree

var _failed := false

class UnregulatedDispatcher:
	extends TransitDispatcher

	func _regulation_hold(_metro: Metro, _line: TransitLine, _source: int) -> float:
		return 0.0

	func _regulated_speed(_metro: Metro, line: TransitLine) -> float:
		return line.cruise_velocity * NOMINAL_SPEED_FACTOR

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition and not _failed:
		push_error(message)
		_failed = true

func _service(graph: TransitGraph, ids: Array[int], id: int) -> TransitLine:
	var line := TransitLine.new(id, Color.CYAN)
	for station_id in ids:
		line.append_station(graph, station_id)
	line.dispatch_rate = 8.0
	line.dwell_time = 1.0
	line.cruise_velocity = 150.0
	line.wagon_count = 6
	return line

func _run() -> void:
	_test_independent_lines()
	_test_service(false)
	_test_service(true)
	_test_safety_and_motion()
	_test_station_approach()
	_test_regulation()
	var regulated := _headway_variation(true)
	var unregulated := _headway_variation(false)
	print("Headway standard deviation: regulated %.3fs, unregulated %.3fs." % [regulated, unregulated])
	_check(regulated < unregulated * 0.75, "Feedback must reduce measured headway variation by at least 25%, not merely change train speeds.")
	if _failed:
		quit(1)
	else:
		print("Schedule smoke passed: independent moving blocks, route fleet guidance, multi-train sections, terminal recovery, smooth motion and gap regulation.")
		quit()

func _test_independent_lines() -> void:
	var graph := TransitGraph.new()
	for position: Vector2 in [Vector2(-576, 0), Vector2.ZERO, Vector2(576, 0), Vector2(0, -576), Vector2(0, 576)]:
		graph.add_station(position)
	var solo := TransitDispatcher.new(graph)
	solo.add_line(_service(graph, [0, 1, 2], 0))
	solo.rebuild_routes()
	var shared := TransitDispatcher.new(graph)
	shared.add_line(_service(graph, [0, 1, 2], 0))
	var crossing := _service(graph, [3, 1, 4], 1)
	crossing.dwell_time = 12.0
	crossing.cruise_velocity = 40.0
	shared.add_line(crossing)
	shared.rebuild_routes()
	for tick in range(2400):
		solo.process(0.05, false)
		shared.process(0.05, false)
		var peers: Array[Metro] = []
		for train: Metro in shared.metros:
			if train.line_id == 0:
				peers.append(train)
		_check(peers.size() == solo.metros.size(), "Crossing traffic must not change dispatch on this line.")
		for index in range(mini(peers.size(), solo.metros.size())):
			_check(is_equal_approx(peers[index].distance, solo.metros[index].distance) and peers[index].arrival_count == solo.metros[index].arrival_count, "A slow crossing line must not change this line's movement or arrivals.")
		if _failed:
			return

func _test_service(loop: bool) -> void:
	var graph := TransitGraph.new()
	for position: Vector2 in [Vector2.ZERO, Vector2(288, 0), Vector2(1728, 0), Vector2(1728, 576)]:
		graph.add_station(position)
	var ids: Array[int] = [0, 1, 2, 3]
	if loop:
		ids.append(0)
	var line := _service(graph, ids, 0)
	line.max_trains = 30
	var dispatcher := TransitDispatcher.new(graph)
	dispatcher.add_line(line)
	dispatcher.rebuild_routes()
	var headway := maxf(line.dispatch_rate, dispatcher.minimum_headway(line))
	var expected := ceili(dispatcher.cycle_time(line) / headway)
	if loop:
		expected += ceili(dispatcher.cycle_time(line, -1) / headway)
	_check(dispatcher.recommended_fleet(line) == mini(dispatcher.route_capacity(line), expected), "Recommended fleet must be computed from cycle time / target interval, not station count.")
	var multiple_in_section := false
	var first_half := 0
	var saw_terminal_recovery := loop
	for tick in range(7200):
		var speeds := {}
		for train: Metro in dispatcher.metros:
			speeds[train.id] = train.speed
		if tick == 3600:
			first_half = dispatcher.arrival_count
			line.cruise_velocity = 80.0
			line.dwell_time = 3.0
			line.dispatch_rate = 20.0
		dispatcher.process(0.05, false)
		var sections := {}
		for train: Metro in dispatcher.metros:
			var route := TrackGeometry.route_for_direction(dispatcher.routes[0], train.travel_direction)
			var stops: PackedFloat32Array = route["stops"]
			var source := (train.next_stop_index - 1 + stops.size()) % stops.size()
			if train.at_station and dispatcher._terminal_stop(line, source) and train.dwell_remaining > line.dwell_time:
				saw_terminal_recovery = true
			if not train.at_station:
				var key := dispatcher._stop_key(line, train.travel_direction, train.next_stop_index)
				multiple_in_section = multiple_in_section or sections.has(key)
				sections[key] = true
			_check(train.speed <= maxf(line.cruise_velocity, speeds.get(train.id, 0.0)) + 0.01, "Regulation must respect the speed ceiling or brake smoothly after a live reduction.")
			for other: Metro in dispatcher.metros:
				if train.id == other.id or not dispatcher._same_circuit(other, 0, train.travel_direction):
					continue
				var gap := fposmod(other.distance - train.distance, float(route["length"]))
				_check(gap >= TrackGeometry.train_length(other.wagon_count) + TrackGeometry.SAFETY_GAP - 0.01, "Moving-block spacing must preserve the full leading train and safety gap.")
		_check(dispatcher.metros.size() <= dispatcher.train_limit(line), "Live operation must respect manual and route capacity ceilings.")
		if _failed:
			return
	_check(multiple_in_section, "A long station section must support multiple safely separated moving trains.")
	_check(saw_terminal_recovery, "Open-line terminal dwell must include recovery time.")
	_check(first_half >= 20 and dispatcher.arrival_count >= first_half + 20, "Unequal sections and live timing changes must keep serving both halves.")
	_check(dispatcher.metros.size() == dispatcher.service_fleet(line), "A slower requested frequency must withdraw surplus trains at terminals or the loop origin.")
	var clock := dispatcher._clock
	var departures := dispatcher._last_departures.duplicate()
	dispatcher.process(10.0, true)
	_check(clock == dispatcher._clock and departures == dispatcher._last_departures, "Pause must freeze regulation clocks.")
	dispatcher.rebuild_routes()
	_check(dispatcher.metros.is_empty() and dispatcher._last_departures.is_empty(), "Edits must reset circulation and feedback history.")

func _test_safety_and_motion() -> void:
	var graph := TransitGraph.new()
	graph.add_station(Vector2.ZERO)
	graph.add_station(Vector2(2304, 0))
	var line := _service(graph, [0, 1], 0)
	line.max_trains = 1
	var dispatcher := TransitDispatcher.new(graph)
	dispatcher.add_line(line)
	dispatcher.rebuild_routes()
	_check(dispatcher.route_capacity(line) > 2, "A long two-station line must not retain the old two-train cap.")
	dispatcher.process(0.1, false)
	var train := dispatcher.metros[0]
	var previous_speed := train.speed
	for tick in range(2400):
		dispatcher.process(1.0 / 60.0, false)
		var change := train.speed - previous_speed
		_check(change <= line.acceleration / 60.0 + 0.01 and change >= -line.braking / 60.0 - 0.01, "Normal station runs must respect independent acceleration/braking limits (%.3f to %.3f)." % [previous_speed, train.speed])
		previous_speed = train.speed
		if _failed:
			return
	line.cruise_velocity = 220.0
	_check(line.acceleration == 80.0 and line.braking == 100.0, "Changing cruise speed must not change acceleration/braking.")
	var other := Metro.new(999, 0, Vector2.ZERO)
	other.distance = fposmod(train.distance + 400.0, float(dispatcher.routes[0]["length"]))
	other.wagon_count = 6
	other.at_station = true
	other.dwell_remaining = 1000.0
	other.next_stop_index = 0
	other.station_arrival_time = dispatcher._clock
	dispatcher.metros.append(other)
	var old_arrivals := train.arrival_count
	for tick in range(600):
		dispatcher.process(1.0 / 60.0, false)
		var gap := fposmod(other.distance - train.distance, float(dispatcher.routes[0]["length"]))
		_check(gap >= TrackGeometry.train_length(other.wagon_count) + TrackGeometry.SAFETY_GAP - 0.01, "A stopped leader must retain its full-train clearance throughout braking.")
	_check(train.speed < 1.0 and train.arrival_count == old_arrivals, "A follower must brake before a stopped leader rather than pass through it.")

func _test_station_approach() -> void:
	var graph := TransitGraph.new()
	graph.add_station(Vector2.ZERO)
	graph.add_station(Vector2(2304, 0))
	var line := _service(graph, [0, 1], 0)
	line.max_trains = 1
	var dispatcher := TransitDispatcher.new(graph)
	dispatcher.add_line(line)
	dispatcher.rebuild_routes()
	dispatcher.process(0.1, false)
	var train := dispatcher.metros[0]
	var route: Dictionary = dispatcher.routes[0]
	var stops: PackedFloat32Array = route["stops"]
	train.distance = float(stops[train.next_stop_index]) - 10.0
	train.at_station = false
	train.speed = 40.0
	var approach_time := 0.0
	while not train.at_station and approach_time < 3.0:
		dispatcher.process(1.0 / 60.0, false)
		approach_time += 1.0 / 60.0
	_check(train.at_station and approach_time < 1.0, "The final ten pixels must brake into a station without a prolonged crawling tail.")
	train.distance = float(stops[0]) + 100.0
	train.next_stop_index = 0
	train.at_station = false
	train.speed = 0.0
	for tick in range(10):
		var previous := train.speed
		dispatcher._advance_metro(train, 1.0 / 1000.0)
		_check(train.speed > previous, "Subpixel movement must preserve acceleration rather than reset speed at high frame rates.")

func _test_regulation() -> void:
	var graph := TransitGraph.new()
	for position: Vector2 in [Vector2.ZERO, Vector2(1152, 0), Vector2(1152, 1152), Vector2(0, 1152)]:
		graph.add_station(position)
	var line := _service(graph, [0, 1, 2, 3, 0], 0)
	line.max_trains = 6
	var dispatcher := TransitDispatcher.new(graph)
	dispatcher.add_line(line)
	dispatcher.rebuild_routes()
	dispatcher.process(600.0, false)
	var route: Dictionary = dispatcher.routes[0]
	var stops: PackedFloat32Array = route["stops"]
	var train: Metro
	for candidate: Metro in dispatcher.metros:
		if candidate.travel_direction == 1:
			train = candidate
			break
	train.distance = stops[0]
	train.next_stop_index = 1
	train.at_station = true
	train.station_arrival_time = dispatcher._clock
	train.dwell_remaining = line.dwell_time
	var key := dispatcher._stop_key(line, 1, 0)
	var target := dispatcher.departure_headway(line, 1)
	dispatcher._last_departures[key] = dispatcher._clock - target * 0.2
	var hold := dispatcher._regulation_hold(train, line, 0)
	_check(hold > 0.0 and hold <= TransitDispatcher.MAX_REGULATION_HOLD, "An early train must receive a short, bounded station hold.")
	train.departure_error = -1.0
	_check(dispatcher._regulated_speed(train, line) < line.cruise_velocity * TransitDispatcher.NOMINAL_SPEED_FACTOR, "An early train must use a slower running profile.")
	train.departure_error = 1.0
	_check(dispatcher._regulated_speed(train, line) > line.cruise_velocity * TransitDispatcher.NOMINAL_SPEED_FACTOR and dispatcher._regulated_speed(train, line) <= line.cruise_velocity, "A late train must use bounded running-time recovery, not exceed the maximum speed.")

func _headway_variation(regulated: bool) -> float:
	var graph := TransitGraph.new()
	for position: Vector2 in [Vector2.ZERO, Vector2(1152, 0), Vector2(1152, 1152), Vector2(0, 1152)]:
		graph.add_station(position)
	var line := _service(graph, [0, 1, 2, 3, 0], 0)
	line.max_trains = 6
	var dispatcher: TransitDispatcher = TransitDispatcher.new(graph) if regulated else UnregulatedDispatcher.new(graph)
	dispatcher.add_line(line)
	dispatcher.rebuild_routes()
	for direction: int in [1, -1]:
		var route := TrackGeometry.route_for_direction(dispatcher.routes[0], direction)
		var stops: PackedFloat32Array = route["stops"]
		for fraction: float in [0.1, 0.25, 0.65]:
			var train := Metro.new(dispatcher.metros.size(), 0, Vector2.ZERO)
			train.distance = fraction * float(route["length"])
			train.travel_direction = direction
			train.wagon_count = line.wagon_count
			train.at_station = false
			train.speed = line.cruise_velocity * TransitDispatcher.NOMINAL_SPEED_FACTOR
			for index in range(stops.size()):
				if stops[index] > train.distance:
					train.next_stop_index = index
					break
			dispatcher._update_pose(train, route)
			dispatcher.metros.append(train)
	var key := dispatcher._stop_key(line, 1, 1)
	var previous := -1.0
	var gaps: Array[float] = []
	for tick in range(24000):
		dispatcher.process(0.05, false)
		var latest: float = dispatcher._last_departures.get(key, -1.0)
		if latest != previous:
			if tick > 18000 and previous >= 0.0:
				gaps.append(latest - previous)
			previous = latest
	_check(gaps.size() >= 10, "Headway comparison must sample sustained service, not just startup.")
	var mean := 0.0
	for gap in gaps:
		mean += gap
	mean /= maxi(1, gaps.size())
	var variance := 0.0
	for gap in gaps:
		variance += (gap - mean) * (gap - mean)
	return sqrt(variance / maxi(1, gaps.size()))
