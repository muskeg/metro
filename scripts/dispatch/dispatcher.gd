class_name TransitDispatcher
extends RefCounted

const NOMINAL_SPEED_FACTOR := 0.9
const MAX_REGULATION_HOLD := 3.0
const REACTION_TIME := 0.25

var graph: TransitGraph
var lines: Array[TransitLine] = []
var metros: Array[Metro] = []
var routes: Dictionary = {}
var arrival_count: int = 0
var last_arrival_line_id: int = -1
var _next_metro_id: int = 0
var _last_departures: Dictionary = {}
var _next_spawn_return: Dictionary = {}
var _clock := 0.0

func _init(transit_graph: TransitGraph) -> void:
	graph = transit_graph

func add_line(line: TransitLine) -> void:
	lines.append(line)

func rebuild_routes() -> void:
	metros.clear()
	routes.clear()
	_last_departures.clear()
	_next_spawn_return.clear()
	_clock = 0.0
	for line: TransitLine in lines:
		routes[line.id] = TrackGeometry.circuit(graph, line, lines)
		line.dispatch_elapsed = INF

func _stop_key(line: TransitLine, direction: int, stop_index: int) -> String:
	return "%d:%d:%d" % [line.id, direction if line.is_loop() else 1, stop_index]

func _terminal_stop(line: TransitLine, stop_index: int) -> bool:
	return not line.is_loop() and (stop_index == line.stations.size() - 2 or stop_index == 2 * line.stations.size() - 3)

func _station_dwell(line: TransitLine, stop_index: int) -> float:
	return line.dwell_time + (line.terminal_recovery if _terminal_stop(line, stop_index) else 0.0)

func _section_time(distance: float, line: TransitLine) -> float:
	var velocity := line.cruise_velocity * NOMINAL_SPEED_FACTOR
	var ramp_distance := velocity * velocity * 0.5 * (1.0 / line.acceleration + 1.0 / line.braking)
	if distance < ramp_distance:
		var peak := sqrt(2.0 * distance / (1.0 / line.acceleration + 1.0 / line.braking))
		return peak / line.acceleration + peak / line.braking
	return distance / velocity + velocity * 0.5 * (1.0 / line.acceleration + 1.0 / line.braking)

func cycle_time(line: TransitLine, direction: int = 1) -> float:
	var route := TrackGeometry.route_for_direction(routes[line.id], direction)
	var stops: PackedFloat32Array = route["stops"]
	var total: float = route["length"]
	var result := 0.0
	for index in range(stops.size()):
		var distance := fposmod(float(stops[index]) - float(stops[(index - 1 + stops.size()) % stops.size()]), total)
		result += _section_time(distance, line) + _station_dwell(line, index)
	return result

func minimum_headway(line: TransitLine) -> float:
	var clearance := TrackGeometry.train_length(line.wagon_count) + TrackGeometry.SAFETY_GAP
	return line.dwell_time + line.terminal_recovery * (0.0 if line.is_loop() else 1.0) + sqrt(2.0 * clearance / line.acceleration) + REACTION_TIME

func route_capacity(line: TransitLine) -> int:
	if not routes.has(line.id) or line.tracks.is_empty():
		return 0
	var result := 0
	var directions: Array[int] = [1]
	if line.is_loop():
		directions.append(-1)
	for direction in directions:
		var route := TrackGeometry.route_for_direction(routes[line.id], direction)
		var length: float = route["length"]
		var spacing := TrackGeometry.train_length(line.wagon_count) + TrackGeometry.SAFETY_GAP
		var geometric_capacity := maxi(1, floori(length / (spacing * 2.0)) - 1)
		var service_capacity := maxi(1, floori(cycle_time(line, direction) / minimum_headway(line)))
		result += mini(geometric_capacity, service_capacity)
	return result

func train_limit(line: TransitLine) -> int:
	return mini(line.max_trains, route_capacity(line))

func recommended_fleet(line: TransitLine) -> int:
	if route_capacity(line) == 0:
		return 0
	var headway := maxf(line.dispatch_rate, minimum_headway(line))
	var count := ceili(cycle_time(line) / headway)
	if line.is_loop():
		count += ceili(cycle_time(line, -1) / headway)
	return mini(route_capacity(line), maxi(1, count))

func service_fleet(line: TransitLine) -> int:
	return mini(train_limit(line), recommended_fleet(line))

func departure_headway(line: TransitLine, direction: int = 1) -> float:
	var fleet := maxi(1, service_fleet(line))
	if line.is_loop():
		fleet = maxi(1, (fleet + (1 if direction == 1 else 0)) / 2)
	return maxf(maxf(line.dispatch_rate, minimum_headway(line)), cycle_time(line, direction) / fleet)

func process(delta: float, paused: bool) -> void:
	if paused:
		return
	var remaining := delta
	while remaining > 0.000001:
		var step := minf(remaining, 1.0 / 60.0)
		_tick(step)
		remaining -= step

func _tick(delta: float) -> void:
	_clock += delta
	_retire_surplus()
	for line: TransitLine in lines:
		if not routes.has(line.id) or line.tracks.is_empty():
			continue
		line.dispatch_elapsed += delta
		if line.dispatch_elapsed >= departure_headway(line):
			var returning: bool = _next_spawn_return.get(line.id, false)
			if not _next_spawn_return.has(line.id):
				_spawn_if_clear(line, false)
				_spawn_if_clear(line, true)
				_next_spawn_return[line.id] = false
				line.dispatch_elapsed = 0.0
			else:
				var spawned := _spawn_if_clear(line, returning)
				if not spawned:
					returning = not returning
					spawned = _spawn_if_clear(line, returning)
				if spawned:
					_next_spawn_return[line.id] = not returning
					line.dispatch_elapsed = 0.0
	for metro: Metro in metros:
		_advance_metro(metro, delta)

func _retire_surplus() -> void:
	for line: TransitLine in lines:
		var count := 0
		var directions := {1: 0, -1: 0}
		for metro: Metro in metros:
			if metro.line_id == line.id:
				count += 1
				directions[metro.travel_direction] += 1
		var desired := service_fleet(line)
		for index in range(metros.size() - 1, -1, -1):
			var metro := metros[index]
			if metro.line_id != line.id or not metro.at_station or metro.dwell_remaining > 0.0:
				continue
			var stops: PackedFloat32Array = TrackGeometry.route_for_direction(routes[line.id], metro.travel_direction)["stops"]
			var source := (metro.next_stop_index - 1 + stops.size()) % stops.size()
			var eligible := source == 0 if line.is_loop() else _terminal_stop(line, source)
			var direction_limit := (desired + (1 if metro.travel_direction == 1 else 0)) / 2 if line.is_loop() else desired
			if eligible and (count > desired or directions[metro.travel_direction] > direction_limit):
				metros.remove_at(index)
				count -= 1
				directions[metro.travel_direction] -= 1

func _spawn_if_clear(line: TransitLine, return_direction: bool) -> bool:
	var direction := -1 if return_direction and line.is_loop() else 1
	var route := TrackGeometry.route_for_direction(routes[line.id], direction)
	var total: float = route["length"]
	var stops: PackedFloat32Array = route["stops"]
	if stops.is_empty() or total < TrackGeometry.train_length(line.wagon_count) * 2.0 + 90.0:
		return false
	var count := 0
	var direction_count := 0
	for metro: Metro in metros:
		if metro.line_id == line.id:
			count += 1
			if metro.travel_direction == direction:
				direction_count += 1
	if count >= service_fleet(line):
		return false
	if line.is_loop() and direction_count >= (service_fleet(line) + (1 if direction == 1 else 0)) / 2:
		return false
	var station_index := 0 if line.is_loop() else (line.stations.size() - 2 if return_direction else stops.size() - 1)
	var spawn_distance := float(stops[station_index])
	for other: Metro in metros:
		if not _same_circuit(other, line.id, direction):
			continue
		var ahead := fposmod(other.distance - spawn_distance, total)
		var behind := fposmod(spawn_distance - other.distance, total)
		var rear_margin := TrackGeometry.train_length(line.wagon_count) + TrackGeometry.SAFETY_GAP + other.speed * REACTION_TIME + other.speed * other.speed / (2.0 * line.braking)
		if ahead <= TrackGeometry.train_length(other.wagon_count) + TrackGeometry.SAFETY_GAP or behind <= rear_margin:
			return false
	var metro := Metro.new(_next_metro_id, line.id, Vector2.ZERO)
	metro.travel_direction = direction
	metro.distance = spawn_distance
	metro.wagon_count = line.wagon_count
	metro.next_stop_index = (station_index + 1) % stops.size()
	metro.dwell_remaining = _station_dwell(line, station_index)
	metro.station_arrival_time = _clock
	_update_pose(metro, route)
	_next_metro_id += 1
	metros.append(metro)
	return true

func _same_circuit(other: Metro, line_id: int, direction: int) -> bool:
	return other.line_id == line_id and (not lines[line_id].is_loop() or other.travel_direction == direction)

func movement_authority(metro: Metro) -> float:
	var route := TrackGeometry.route_for_direction(routes[metro.line_id], metro.travel_direction)
	var total: float = route["length"]
	var available := total
	for other: Metro in metros:
		if other.id == metro.id or not _same_circuit(other, metro.line_id, metro.travel_direction):
			continue
		var gap := fposmod(other.distance - metro.distance, total)
		available = minf(available, maxf(0.0, gap - TrackGeometry.train_length(other.wagon_count) - TrackGeometry.SAFETY_GAP))
	return available

func _regulation_hold(metro: Metro, line: TransitLine, source: int) -> float:
	var key := _stop_key(line, metro.travel_direction, source)
	if not _last_departures.has(key):
		return 0.0
	var desired := float(_last_departures[key]) + departure_headway(line, metro.travel_direction)
	var base_departure := metro.station_arrival_time + _station_dwell(line, source)
	return minf(MAX_REGULATION_HOLD, maxf(0.0, desired - base_departure) * 0.5)

func _regulated_speed(metro: Metro, line: TransitLine) -> float:
	return line.cruise_velocity * NOMINAL_SPEED_FACTOR * (1.0 + clampf(metro.departure_error * 0.15, -0.1, 1.0 / NOMINAL_SPEED_FACTOR - 1.0))

func _braking_speed(distance: float, braking: float, reaction: float) -> float:
	var margin := braking * reaction
	return maxf(0.0, sqrt(margin * margin + 2.0 * braking * distance) - margin)

func _advance_metro(metro: Metro, delta: float) -> void:
	var line := lines[metro.line_id]
	var route := TrackGeometry.route_for_direction(routes[metro.line_id], metro.travel_direction)
	var total: float = route["length"]
	var stops: PackedFloat32Array = route["stops"]
	var source := (metro.next_stop_index - 1 + stops.size()) % stops.size()
	metro.blocked = false
	if metro.at_station:
		metro.dwell_remaining = maxf(0.0, metro.dwell_remaining - delta)
		var hold := _regulation_hold(metro, line, source)
		var release := metro.station_arrival_time + _station_dwell(line, source) + hold
		if metro.dwell_remaining > 0.0 or _clock < release or movement_authority(metro) < TrackGeometry.SAFETY_GAP:
			metro.speed = 0.0
			metro.moving = false
			metro.blocked = metro.dwell_remaining == 0.0
			return
		var key := _stop_key(line, metro.travel_direction, source)
		var headway := departure_headway(line, metro.travel_direction)
		metro.departure_error = (_clock - float(_last_departures[key]) - headway) / headway if _last_departures.has(key) else 0.0
		_last_departures[key] = _clock
		metro.at_station = false
	var stop_distance := fposmod(float(stops[metro.next_stop_index]) - metro.distance, total)
	var authority := movement_authority(metro)
	var available := minf(stop_distance, authority)
	var regulated_speed := _regulated_speed(metro, line)
	# A known platform needs only a substep margin, not the leader reaction buffer.
	var safe_speed := minf(_braking_speed(stop_distance, line.braking, delta), _braking_speed(authority, line.braking, REACTION_TIME))
	var target_speed := minf(regulated_speed, safe_speed)
	var previous_speed := metro.speed
	metro.speed = move_toward(metro.speed, target_speed, (line.acceleration if metro.speed < target_speed else line.braking) * delta)
	var advance := minf(metro.speed * delta, available)
	if stop_distance < 0.2 and previous_speed <= line.braking * delta and authority >= stop_distance:
		advance = stop_distance
	metro.distance = fposmod(metro.distance + advance, total)
	metro.moving = advance > 0.0
	metro.blocked = available < 0.1 and stop_distance > 0.2
	if available <= 0.0:
		metro.speed = 0.0
	_update_pose(metro, route)
	if advance >= stop_distance - 0.001:
		metro.at_station = true
		metro.station_arrival_time = _clock
		metro.dwell_remaining = _station_dwell(line, metro.next_stop_index)
		metro.speed = 0.0
		metro.moving = false
		metro.arrival_count += 1
		arrival_count += 1
		last_arrival_line_id = line.id
		metro.next_stop_index = (metro.next_stop_index + 1) % stops.size()

func _update_pose(metro: Metro, route: Dictionary) -> void:
	metro.position = TrackGeometry.point_at_distance(route["points"], metro.distance)
	metro.progress = metro.distance / float(route["length"])
	if not lines[metro.line_id].is_loop():
		metro.travel_direction = 1 if metro.distance <= float(route["outbound_end"]) else -1
