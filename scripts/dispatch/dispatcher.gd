class_name TransitDispatcher
extends RefCounted

var graph: TransitGraph
var lines: Array[TransitLine] = []
var metros: Array[Metro] = []
var routes: Dictionary = {}
var arrival_count: int = 0
var last_arrival_line_id: int = -1
var _next_metro_id: int = 0
var _body_cache: Dictionary = {}
var _junction_zones: Array[Dictionary] = []
var _junction_passages: Dictionary = {}
var _junction_owners: Dictionary = {}
var _junction_queues: Dictionary = {}

func _init(transit_graph: TransitGraph) -> void:
	graph = transit_graph

func add_line(line: TransitLine) -> void:
	lines.append(line)

func rebuild_routes() -> void:
	# Edits may change shared offsets as well as route length. Redispatch safely.
	metros.clear()
	_body_cache.clear()
	routes.clear()
	_junction_owners.clear()
	_junction_queues.clear()
	for line: TransitLine in lines:
		routes[line.id] = TrackGeometry.circuit(graph, line, lines)
		line.dispatch_elapsed = line.dispatch_rate
	_build_junctions()

func _build_junctions() -> void:
	_junction_zones.clear()
	_junction_passages.clear()
	var clearance := 0.0
	for line: TransitLine in lines:
		clearance = maxf(clearance, TrackGeometry.train_length(line.wagon_count) + 24.0)
	for station: Station in graph.stations:
		var sharing := 0
		var radius := 40.0
		var first_incident: Array[int] = []
		var different_paths := false
		var terminal := false
		var participating: Array[int] = []
		for line: TransitLine in lines:
			if not line.stations.has(station.id) or line.tracks.is_empty():
				continue
			sharing += 1
			participating.append(line.id)
			terminal = terminal or (not line.is_loop() and (station.id == line.stations[0] or station.id == line.stations.back()))
			var incident: Array[int] = []
			for track_id: int in line.tracks:
				var track := graph.tracks[track_id]
				if track.a == station.id or track.b == station.id:
					incident.append(track_id)
					radius = maxf(radius, absf(TrackGeometry.track_offset(track_id, line.id, lines)) + TrackGeometry.LANE_OFFSET + 30.0)
			incident.sort()
			if sharing == 1:
				first_incident = incident
			else:
				different_paths = different_paths or incident != first_incident
		if not terminal and (sharing < 2 or not different_paths):
			continue
		if terminal and not different_paths:
			# Parallel shared corridors have independent terminal turns.
			for line_id: int in participating:
				_junction_zones.append({"centers": [station.position], "radius": radius, "lines": [line_id]})
		else:
			_junction_zones.append({"centers": [station.position], "radius": radius, "lines": participating})
	# Nearby intersections form one interlocking: a long train must not hold
	# one junction while waiting for another train holding the next.
	var merged := true
	while merged:
		merged = false
		for first in range(_junction_zones.size()):
			for second in range(first + 1, _junction_zones.size()):
				var a: Dictionary = _junction_zones[first]
				var b: Dictionary = _junction_zones[second]
				var common_line := false
				for line_id: int in a["lines"]:
					common_line = common_line or b["lines"].has(line_id)
				if not common_line:
					continue
				var nearby := false
				for center_a: Vector2 in a["centers"]:
					for center_b: Vector2 in b["centers"]:
						nearby = nearby or center_a.distance_to(center_b) <= float(a["radius"]) + float(b["radius"]) + clearance
				if nearby:
					a["centers"].append_array(b["centers"])
					a["radius"] = maxf(a["radius"], b["radius"])
					for line_id: int in b["lines"]:
						if not a["lines"].has(line_id):
							a["lines"].append(line_id)
					_junction_zones.remove_at(second)
					merged = true
					break
			if merged:
				break
	for line: TransitLine in lines:
		_build_line_passages(line, 1)
		if line.is_loop():
			_build_line_passages(line, -1)

func _passage_key(line_id: int, direction: int) -> String:
	return "%d:%d" % [line_id, direction if lines[line_id].is_loop() else 1]

func _build_line_passages(line: TransitLine, direction: int) -> void:
	var passages: Array[Dictionary] = []
	var route := TrackGeometry.route_for_direction(routes[line.id], direction)
	var points: PackedVector2Array = route["points"]
	var total: float = route["length"]
	for zone_id in range(_junction_zones.size()):
		if not _junction_zones[zone_id]["lines"].has(line.id):
			continue
		var intervals: Array[Vector2] = []
		var run_start := -1.0
		var traveled := 0.0
		var previous := 0.0
		for index in range(1, points.size()):
			var segment := points[index - 1].distance_to(points[index])
			var steps := maxi(1, ceili(segment / 8.0))
			for step in range(steps):
				var distance := traveled + segment * float(step) / float(steps)
				var position := points[index - 1].lerp(points[index], float(step) / float(steps))
				var inside := false
				for center: Vector2 in _junction_zones[zone_id]["centers"]:
					inside = inside or center.distance_to(position) <= float(_junction_zones[zone_id]["radius"])
				if inside and run_start < 0.0:
					run_start = previous
				elif not inside and run_start >= 0.0:
					intervals.append(Vector2(run_start, distance))
					run_start = -1.0
				previous = distance
			traveled += segment
		if run_start >= 0.0:
			intervals.append(Vector2(run_start, total))
		if intervals.size() > 1 and intervals[0].x == 0.0 and intervals.back().y == total:
			intervals[0].x = intervals.back().x - total
			intervals.pop_back()
		var protected: Array[Vector2] = []
		for interval: Vector2 in intervals:
			var expanded := Vector2(interval.x - 12.0, interval.y + TrackGeometry.train_length(line.wagon_count) + 12.0)
			if not protected.is_empty() and expanded.x <= protected.back().y:
				protected[protected.size() - 1].y = maxf(protected.back().y, expanded.y)
			else:
				protected.append(expanded)
		if protected.size() > 1 and protected.back().y >= protected[0].x + total:
			protected[0].x = protected.back().x - total
			protected[0].y = maxf(protected[0].y, protected.back().y - total)
			protected.pop_back()
		for interval: Vector2 in protected:
			passages.append({"zone": zone_id, "start": fposmod(interval.x, total), "span": minf(interval.y - interval.x, total)})
	_junction_passages[_passage_key(line.id, direction)] = passages

func _junction_available(metro: Metro, available: float) -> float:
	var total: float = TrackGeometry.route_for_direction(routes[metro.line_id], metro.travel_direction)["length"]
	var line := lines[metro.line_id]
	var request_distance := line.cruise_velocity / 1.6 + 24.0
	for passage: Dictionary in _junction_passages[_passage_key(metro.line_id, metro.travel_direction)]:
		var zone_id: int = passage["zone"]
		if _junction_owners.has(zone_id) and _junction_owners[zone_id]["metro"] == metro.id:
			continue
		var distance := fposmod(float(passage["start"]) - metro.distance, total)
		if distance <= request_distance:
			if not _junction_queues.has(zone_id):
				_junction_queues[zone_id] = []
			var queue: Array = _junction_queues[zone_id]
			if not queue.has(metro.id):
				queue.append(metro.id)
			if not _junction_owners.has(zone_id) and queue[0] == metro.id:
				queue.pop_front()
				_junction_owners[zone_id] = {"metro": metro.id, "remaining": distance + float(passage["span"])}
				continue
		available = minf(available, distance)
	return available

func _release_junctions(metro: Metro, advance: float) -> void:
	for zone_id: int in _junction_owners.keys():
		var owner: Dictionary = _junction_owners[zone_id]
		if owner["metro"] != metro.id:
			continue
		owner["remaining"] -= advance
		if owner["remaining"] <= 0.001:
			_junction_owners.erase(zone_id)

func process(delta: float, paused: bool) -> void:
	if paused:
		return
	var remaining := delta
	while remaining > 0.000001:
		var step := minf(remaining, 1.0 / 60.0)
		_tick(step)
		remaining -= step

func _tick(delta: float) -> void:
	for line: TransitLine in lines:
		if not routes.has(line.id) or line.tracks.is_empty():
			continue
		line.dispatch_elapsed += delta
		if line.dispatch_elapsed >= line.dispatch_rate:
			line.dispatch_elapsed = 0.0
			_spawn_if_clear(line, false)
			_spawn_if_clear(line, true)
	for metro: Metro in metros:
		_advance_metro(metro, delta)

func _spawn_if_clear(line: TransitLine, return_direction: bool) -> void:
	var direction := -1 if return_direction and line.is_loop() else 1
	var route := TrackGeometry.route_for_direction(routes[line.id], direction)
	var total: float = route["length"]
	var points: PackedVector2Array = route["points"]
	var stops: PackedFloat32Array = route["stops"]
	var body_length := TrackGeometry.train_length(line.wagon_count)
	if total < body_length * 2.0 + 90.0:
		return
	var line_count := 0
	for metro: Metro in metros:
		if metro.line_id == line.id:
			line_count += 1
	if line_count >= mini(line.max_trains, int(total / (body_length + TrackGeometry.SAFETY_GAP + 40.0))):
		return
	var spawn_distance := float(line.wagon_count) * TrackGeometry.CAR_PITCH + 8.0
	if return_direction and not line.is_loop():
		var turnaround_start: float = route["outbound_end"]
		spawn_distance += turnaround_start + 38.0
	spawn_distance = fposmod(spawn_distance, total)
	var metro := Metro.new(_next_metro_id, line.id, Vector2.ZERO)
	metro.travel_direction = direction
	metro.distance = spawn_distance
	metro.wagon_count = line.wagon_count
	for index in range(stops.size()):
		if stops[index] > spawn_distance + 0.1:
			metro.next_stop_index = index
			break
	for other: Metro in metros:
		if other.line_id == line.id and (not line.is_loop() or other.travel_direction == direction):
			var separation := fposmod(other.distance - spawn_distance, total)
			var rear_separation := fposmod(spawn_distance - other.distance, total)
			if minf(separation, rear_separation) < body_length + TrackGeometry.SAFETY_GAP + 20.0:
				return
	var body := _body_points(points, total, spawn_distance, metro.wagon_count)
	if not _body_is_clear(body, metro.id):
		return
	var starting_junctions: Dictionary = {}
	for passage: Dictionary in _junction_passages[_passage_key(line.id, direction)]:
		var progress := fposmod(spawn_distance - float(passage["start"]), total)
		if progress <= float(passage["span"]):
			var zone_id: int = passage["zone"]
			if _junction_owners.has(zone_id) or not _junction_queues.get(zone_id, []).is_empty():
				return
			starting_junctions[zone_id] = maxf(starting_junctions.get(zone_id, 0.0), float(passage["span"]) - progress)
	for zone_id: int in starting_junctions:
		_junction_owners[zone_id] = {"metro": metro.id, "remaining": starting_junctions[zone_id]}
	_next_metro_id += 1
	_update_pose(metro, route)
	metros.append(metro)
	_body_cache[metro.id] = body

func _advance_metro(metro: Metro, delta: float) -> void:
	var line := lines[metro.line_id]
	var route := TrackGeometry.route_for_direction(routes[metro.line_id], metro.travel_direction)
	var total: float = route["length"]
	if metro.dwell_remaining > 0.0:
		metro.dwell_remaining = maxf(0.0, metro.dwell_remaining - delta)
		metro.speed = 0.0
		metro.moving = false
		return
	var stops: PackedFloat32Array = route["stops"]
	var stop_distance := fposmod(float(stops[metro.next_stop_index]) - metro.distance, total)
	var available := stop_distance
	for other: Metro in metros:
		if other.id == metro.id or other.line_id != metro.line_id or (line.is_loop() and other.travel_direction != metro.travel_direction):
			continue
		var separation := fposmod(other.distance - metro.distance, total)
		available = minf(available, maxf(0.0, separation - TrackGeometry.train_length(other.wagon_count) - TrackGeometry.SAFETY_GAP))
	available = _junction_available(metro, available)
	var acceleration := line.cruise_velocity * 0.8
	var target_speed := minf(line.cruise_velocity, sqrt(maxf(0.0, 2.0 * acceleration * available)))
	metro.speed = move_toward(metro.speed, target_speed, acceleration * delta)
	var advance := minf(metro.speed * delta, available)
	if stop_distance < 0.2 and available >= stop_distance:
		advance = stop_distance
	var candidate := fposmod(metro.distance + advance, total)
	var points: PackedVector2Array = route["points"]
	var body := _body_points(points, total, candidate, metro.wagon_count)
	if not _body_is_clear(body, metro.id):
		metro.speed = 0.0
		metro.moving = false
		metro.blocked = true
		return
	metro.blocked = available < 0.1 and stop_distance > 0.2
	metro.distance = candidate
	_release_junctions(metro, advance)
	metro.moving = advance > 0.001
	_body_cache[metro.id] = body
	_update_pose(metro, route)
	if advance >= stop_distance - 0.001:
		metro.dwell_remaining = line.dwell_time
		metro.speed = 0.0
		metro.moving = false
		metro.arrival_count += 1
		arrival_count += 1
		last_arrival_line_id = line.id
		metro.next_stop_index = (metro.next_stop_index + 1) % stops.size()

func _update_pose(metro: Metro, route: Dictionary) -> void:
	var points: PackedVector2Array = route["points"]
	var total: float = route["length"]
	metro.position = TrackGeometry.point_at_distance(points, metro.distance)
	metro.progress = metro.distance / total
	if not lines[metro.line_id].is_loop():
		metro.travel_direction = 1 if metro.distance <= float(route["outbound_end"]) else -1

func _body_points(points: PackedVector2Array, total: float, head_distance: float, wagon_count: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for car in range(wagon_count + 1):
		var distance := head_distance - float(car) * TrackGeometry.CAR_PITCH
		var center := TrackGeometry.point_at_distance(points, fposmod(distance, total))
		var before := TrackGeometry.point_at_distance(points, fposmod(distance - 2.0, total))
		var after := TrackGeometry.point_at_distance(points, fposmod(distance + 2.0, total))
		var tangent := (after - before).normalized()
		for longitudinal_offset: float in [-4.0, 0.0, 4.0]:
			result.append(center + tangent * longitudinal_offset)
	return result

func _body_is_clear(candidate: PackedVector2Array, metro_id: int) -> bool:
	for other_id: int in _body_cache:
		if other_id == metro_id:
			continue
		var other: PackedVector2Array = _body_cache[other_id]
		for point: Vector2 in candidate:
			for other_point: Vector2 in other:
				if point.distance_squared_to(other_point) < 100.0:
					return false
	return true
