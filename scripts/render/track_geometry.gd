class_name TrackGeometry
extends RefCounted

const LANE_OFFSET := 8.0
const CORRIDOR_SPACING := 48.0
const CAR_LENGTH := 19.8
const CAR_PITCH := CAR_LENGTH + 1.0
const CAR_SCALE := CAR_LENGTH / 12.0
const CAR_WIDTH := 7.0
const SAFETY_GAP := 14.0
const GRID_SIZE := 48.0
const TERMINAL_GAP := 3.0
const STATION_TRANSITION_MIN := 64.0
# Station approaches may use this share of each end segment; shallower jogs fold opposing lanes on tight grids.
const STATION_TRANSITION_SHARE := 0.45

static func elastic_path(start: Vector2, finish: Vector2, diagonal_first: bool = true) -> PackedVector2Array:
	var target := (finish / GRID_SIZE).round() * GRID_SIZE
	var difference := target - start
	var diagonal_length := minf(absf(difference.x), absf(difference.y))
	var diagonal := Vector2(signf(difference.x), signf(difference.y)) * diagonal_length
	var elbow := start + diagonal if diagonal_first else target - diagonal
	return simplify(PackedVector2Array([start, elbow, target]))

static func sample(graph: TransitGraph, track: Track, _sample_count: int = 24) -> PackedVector2Array:
	return round_corners(anchors(graph, track))

static func anchors(graph: TransitGraph, track: Track) -> PackedVector2Array:
	var anchors := track.waypoints.duplicate()
	if anchors.size() < 2:
		anchors = PackedVector2Array([graph.stations[track.a].position, graph.stations[track.b].position])
	anchors[0] = graph.stations[track.a].position
	anchors[anchors.size() - 1] = graph.stations[track.b].position
	return simplify(anchors, anchors)

static func closest_point(points: PackedVector2Array, position: Vector2) -> Vector2:
	var closest := points[0]
	for index in range(1, points.size()):
		var candidate := Geometry2D.get_closest_point_to_segment(position, points[index - 1], points[index])
		if candidate.distance_squared_to(position) < closest.distance_squared_to(position):
			closest = candidate
	return closest

static func insertion_point(points: PackedVector2Array, position: Vector2) -> Vector2:
	var closest := points[0]
	for index in range(1, points.size()):
		var projected := Geometry2D.get_closest_point_to_segment(position, points[index - 1], points[index])
		var snapped := (projected / GRID_SIZE).round() * GRID_SIZE
		if Geometry2D.get_closest_point_to_segment(snapped, points[index - 1], points[index]).distance_to(snapped) < 0.01:
			if snapped.distance_squared_to(position) < closest.distance_squared_to(position):
				closest = snapped
		else:
			for endpoint: Vector2 in [points[index - 1], points[index]]:
				if endpoint.distance_squared_to(position) < closest.distance_squared_to(position):
					closest = endpoint
	return closest

static func split_at(points: PackedVector2Array, position: Vector2) -> Array[PackedVector2Array]:
	if position.is_equal_approx(points[0]) or position.is_equal_approx(points[points.size() - 1]):
		return []
	for index in range(1, points.size()):
		if Geometry2D.get_closest_point_to_segment(position, points[index - 1], points[index]).distance_to(position) > 0.01:
			continue
		var first := points.slice(0, index)
		first.append(position)
		var second := PackedVector2Array([position])
		second.append_array(points.slice(index))
		return [simplify(first), simplify(second)]
	return []

static func reshape_endpoint(points: PackedVector2Array, position: Vector2, at_start: bool) -> PackedVector2Array:
	var result := simplify(points)
	if not at_start:
		result.reverse()
	if result.size() > 2:
		var incoming := result[1] - result[0]
		var outgoing := result[2] - result[1]
		var intersection: Variant = Geometry2D.line_intersects_line(position, incoming, result[2], outgoing)
		if intersection is Vector2 and (intersection / GRID_SIZE).is_equal_approx((intersection / GRID_SIZE).round()) and incoming.dot(intersection - position) > 0.0 and outgoing.dot(result[2] - intersection) > 0.0:
			result[1] = intersection
		else:
			# Rebuild only the endpoint elbow; keep the user's distant bends fixed.
			var target := result[2]
			var elbow := Vector2(target.x, position.y) if absf(incoming.x) >= absf(incoming.y) else Vector2(position.x, target.y)
			result[1] = elbow
	result[0] = position
	result = simplify(result)
	if not at_start:
		result.reverse()
	return result

static func simplify(points: PackedVector2Array, protected_points: PackedVector2Array = PackedVector2Array()) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		if not result.is_empty() and result[result.size() - 1].is_equal_approx(point):
			continue
		if result.size() >= 2:
			var before := result[result.size() - 1] - result[result.size() - 2]
			var after := point - result[result.size() - 1]
			if absf(before.cross(after)) < 0.01 and before.dot(after) > 0.0 and not protected_points.has(result[result.size() - 1]):
				result[result.size() - 1] = point
				continue
		result.append(point)
	return result

static func round_corners(points: PackedVector2Array) -> PackedVector2Array:
	return round_corners_preserving(points, [])

static func round_corners_preserving(points: PackedVector2Array, protected_points: Array[Vector2]) -> PackedVector2Array:
	var anchors := simplify(points)
	if anchors.size() < 2:
		return anchors
	var result := PackedVector2Array([anchors[0]])
	for index in range(1, anchors.size() - 1):
		var corner := anchors[index]
		var is_station := protected_points.has(corner)
		var incoming := corner - anchors[index - 1]
		var outgoing := anchors[index + 1] - corner
		var radius_limit := 12.0 if is_station else 24.0
		var radius := minf(radius_limit, minf(incoming.length(), outgoing.length()) * 0.35)
		var entry := corner - incoming.normalized() * radius
		var exit := corner + outgoing.normalized() * radius
		result.append(entry)
		_append_curve(result, entry, entry.lerp(corner, 2.0 / 3.0), exit.lerp(corner, 2.0 / 3.0), exit)
	result.append(anchors[anchors.size() - 1])
	return result

static func _append_curve(result: PackedVector2Array, start: Vector2, first: Vector2, second: Vector2, finish: Vector2, depth: int = 0) -> void:
	var chord := finish - start
	var flatness := maxf(Geometry2D.get_closest_point_to_segment(first, start, finish).distance_to(first), Geometry2D.get_closest_point_to_segment(second, start, finish).distance_to(second))
	var turn := maxf(absf((first - start).angle_to(chord)), absf(chord.angle_to(finish - second)))
	if (flatness <= 0.01 and turn <= deg_to_rad(1.0)) or depth >= 12:
		result.append(finish)
		return
	var a := start.lerp(first, 0.5)
	var b := first.lerp(second, 0.5)
	var c := second.lerp(finish, 0.5)
	var d := a.lerp(b, 0.5)
	var e := b.lerp(c, 0.5)
	var midpoint := d.lerp(e, 0.5)
	_append_curve(result, start, a, d, midpoint, depth + 1)
	_append_curve(result, midpoint, e, c, finish, depth + 1)

static func length(points: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(1, points.size()):
		total += points[index - 1].distance_to(points[index])
	return total

static func cumulative_lengths(points: PackedVector2Array) -> PackedFloat64Array:
	var cumulative := PackedFloat64Array()
	if points.is_empty():
		return cumulative
	cumulative.append(0.0)
	for index in range(1, points.size()):
		cumulative.append(cumulative[index - 1] + points[index - 1].distance_to(points[index]))
	return cumulative

static func point_at_distance(points: PackedVector2Array, distance: float, cumulative: PackedFloat64Array = PackedFloat64Array()) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var remaining := maxf(distance, 0.0)
	if cumulative.size() == points.size() and points.size() > 1:
		if remaining >= cumulative[cumulative.size() - 1]:
			return points[points.size() - 1]
		var low := 1
		var high := points.size() - 1
		while low < high:
			var middle := (low + high) / 2
			if cumulative[middle] < remaining:
				low = middle + 1
			else:
				high = middle
		var segment_start := cumulative[low - 1]
		var segment_length := cumulative[low] - segment_start
		return points[low - 1].lerp(points[low], (remaining - segment_start) / maxf(segment_length, 0.001))
	for index in range(1, points.size()):
		var segment_length := points[index - 1].distance_to(points[index])
		if remaining <= segment_length:
			return points[index - 1].lerp(points[index], remaining / maxf(segment_length, 0.001))
		remaining -= segment_length
	return points[points.size() - 1]

static func offset_points(points: PackedVector2Array, offset: float) -> PackedVector2Array:
	if points.size() < 2 or is_zero_approx(offset):
		return points.duplicate()
	var shifted := PackedVector2Array()
	var closed := points.size() > 2 and points[0].is_equal_approx(points[points.size() - 1])
	for index in range(points.size()):
		var before := points[maxi(0, index - 1)]
		var after := points[mini(points.size() - 1, index + 1)]
		if closed and (index == 0 or index == points.size() - 1):
			before = points[points.size() - 2]
			after = points[1]
		var tangent := (after - before).normalized()
		shifted.append(points[index] + Vector2(-tangent.y, tangent.x) * offset)
	return shifted

static func track_offset(track_id: int, line_id: int, lines: Array[TransitLine]) -> float:
	var sharing: Array[int] = []
	for line: TransitLine in lines:
		if line.tracks.has(track_id):
			sharing.append(line.id)
	return (float(sharing.find(line_id)) - float(sharing.size() - 1) * 0.5) * CORRIDOR_SPACING

static func corridor_layout(graph: TransitGraph, lines: Array[TransitLine]) -> Dictionary:
	# Express and local edges can share geometry without sharing stop-to-stop track IDs.
	if lines.size() < 2:
		return {"aligned": false}
	var owners: Dictionary = {}
	for line: TransitLine in lines:
		for index in range(line.tracks.size()):
			var track := graph.tracks[line.tracks[index]]
			if not owners.has(track.id):
				owners[track.id] = []
			owners[track.id].append({"line": line.id, "forward": track.a == line.stations[index]})
	var tracks: Dictionary = {}
	var supports: Dictionary = {}
	for track: Track in graph.tracks:
		if not owners.has(track.id):
			continue
		var points := anchors(graph, track)
		var segments: Array[Dictionary] = []
		for index in range(points.size() - 1):
			var axis := points[index + 1] - points[index]
			var direction := Vector2(signf(axis.x), signf(axis.y))
			if direction.x < 0.0 or (direction.x == 0.0 and direction.y < 0.0):
				direction = -direction
			var key := Vector3(direction.x, direction.y, direction.cross(points[index]))
			direction = direction.normalized()
			var first := points[index].dot(direction)
			var last := points[index + 1].dot(direction)
			var station_ids: Array[int] = []
			var stop_marks: Array[float] = []
			if index == 0:
				station_ids.append(track.a)
				stop_marks.append(first)
			if index == points.size() - 2:
				station_ids.append(track.b)
				stop_marks.append(last)
			var segment := {"a": points[index], "b": points[index + 1], "low": minf(first, last), "high": maxf(first, last), "track": track.id, "owners": owners[track.id], "stations": station_ids, "stop_marks": stop_marks}
			segments.append(segment)
			if not supports.has(key):
				supports[key] = []
			supports[key].append(segment)
		tracks[track.id] = segments
	var aligned := false
	for support: Array in supports.values():
		support.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["low"] < b["low"])
		var component: Array[Dictionary] = []
		var finish := -INF
		for index in range(support.size()):
			var segment: Dictionary = support[index]
			if not component.is_empty() and (segment["low"] > finish + 0.001 or (segment["low"] > finish - 0.001 and _splits_at(component, support, index, finish))):
				aligned = _bundle_corridor(component) or aligned
				component = []
				finish = -INF
			component.append(segment)
			finish = maxf(finish, segment["high"])
		if not component.is_empty():
			aligned = _bundle_corridor(component) or aligned
	return {"aligned": aligned, "tracks": tracks}

# A collinear corridor restarts its slots at a station where its set of services
# changes, provided every service continuing through that station also stops there.
static func _splits_at(component: Array[Dictionary], support: Array, start: int, mark: float) -> bool:
	var before: Dictionary = {}
	var after: Dictionary = {}
	var stopping: Dictionary = {}
	for segment: Dictionary in component:
		if absf(segment["high"] - mark) <= 0.001:
			_collect_boundary_lines(segment, mark, before, stopping)
	for index in range(start, support.size()):
		var segment: Dictionary = support[index]
		if segment["low"] > mark + 0.001:
			break
		_collect_boundary_lines(segment, mark, after, stopping)
	if before.keys().size() == after.keys().size() and before.keys().all(func(line_id: int) -> bool: return after.has(line_id)):
		return false
	for line_id: int in before:
		if after.has(line_id) and not stopping.has(line_id):
			return false
	return true

static func _collect_boundary_lines(segment: Dictionary, mark: float, lines: Dictionary, stopping: Dictionary) -> void:
	var stops := false
	for stop_mark: float in segment["stop_marks"]:
		if absf(stop_mark - mark) <= 0.001:
			stops = true
	for owner: Dictionary in segment["owners"]:
		lines[owner["line"]] = true
		if stops:
			stopping[owner["line"]] = true

static func _bundle_corridor(segments: Array[Dictionary]) -> bool:
	var sharing: Array[int] = []
	var station_calls: Dictionary = {}
	var coverage: Dictionary = {}
	var direction := Vector2.ZERO
	var reference_id := 2147483647
	# Two furthest distinct tracks suffice for the sorted interval overlap scan.
	var furthest_end := -INF
	var furthest_track := -1
	var second_end := -INF
	var overlaps := false
	for segment: Dictionary in segments:
		var other_end := second_end if furthest_track == segment["track"] else furthest_end
		if other_end > segment["low"] + 0.001:
			overlaps = true
		if furthest_track == segment["track"]:
			furthest_end = maxf(furthest_end, segment["high"])
		elif segment["high"] > furthest_end:
			second_end = furthest_end
			furthest_end = segment["high"]
			furthest_track = segment["track"]
		else:
			second_end = maxf(second_end, segment["high"])
		for owner: Dictionary in segment["owners"]:
			if not sharing.has(owner["line"]):
				sharing.append(owner["line"])
				station_calls[owner["line"]] = {}
				coverage[owner["line"]] = 0.0
			var calls: Dictionary = station_calls[owner["line"]]
			for station_id: int in segment["stations"]:
				calls[station_id] = true
			coverage[owner["line"]] += segment["high"] - segment["low"]
			if owner["line"] < reference_id:
				reference_id = owner["line"]
				direction = (segment["b"] - segment["a"]).normalized() * (1.0 if owner["forward"] else -1.0)
	sharing.sort()
	# Keep the service with most local stops on the spine, avoiding unnecessary detours.
	var centered: int = sharing[0]
	for line_id: int in sharing:
		if station_calls[line_id].size() > station_calls[centered].size():
			centered = line_id
	var slots := {centered: 0}
	var ordered := sharing.duplicate()
	ordered.sort_custom(func(a: int, b: int) -> bool:
		if not is_equal_approx(coverage[a], coverage[b]):
			return coverage[a] > coverage[b]
		return a < b)
	var other_count := 0
	for line_id: int in ordered:
		if line_id == centered:
			continue
		other_count += 1
		var rank := ceili(float(other_count) * 0.5)
		slots[line_id] = -rank if other_count % 2 == 1 else rank
	var bundle := {"slots": slots, "normal": Vector2(-direction.y, direction.x)}
	for segment: Dictionary in segments:
		segment["bundle"] = bundle
	return overlaps

static func _aligned_centerline(graph: TransitGraph, line: TransitLine, corridors: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in range(line.tracks.size()):
		var track := graph.tracks[line.tracks[index]]
		var segments: Array = corridors["tracks"][track.id]
		var reverse := track.a != line.stations[index]
		if reverse:
			segments = segments.duplicate()
			segments.reverse()
		var shifted: Array[PackedVector2Array] = []
		for segment: Dictionary in segments:
			var bundle: Dictionary = segment["bundle"]
			var offset := float(bundle["slots"][line.id]) * CORRIDOR_SPACING
			var shift: Vector2 = bundle["normal"] * offset
			var first: Vector2 = segment["a"] + shift
			var last: Vector2 = segment["b"] + shift
			shifted.append(PackedVector2Array([last, first] if reverse else [first, last]))
		var points := PackedVector2Array([shifted[0][0]])
		for segment_index in range(1, shifted.size()):
			_append_corridor_join(points, shifted[segment_index - 1], shifted[segment_index])
		points.append(shifted.back()[1])
		_append_station_connected(result, points, graph.stations[line.stations[index]].position, graph.stations[line.stations[index + 1]].position)
	return result

static func _append_corridor_join(points: PackedVector2Array, before: PackedVector2Array, after: PackedVector2Array) -> void:
	var intersection: Variant = Geometry2D.line_intersects_line(before[0], before[1] - before[0], after[0], after[1] - after[0])
	if intersection is Vector2:
		points.append(intersection)
	else:
		points.append(before[1])
		if not before[1].is_equal_approx(after[0]):
			points.append(after[0])

static func _append_station_connected(result: PackedVector2Array, points: PackedVector2Array, start: Vector2, finish: Vector2) -> void:
	if result.is_empty() or not result[result.size() - 1].is_equal_approx(start):
		result.append(start)
	if not points[0].is_equal_approx(start):
		var first_length := points[0].distance_to(points[1])
		var transition := minf(maxf(STATION_TRANSITION_MIN, points[0].distance_to(start)), first_length * STATION_TRANSITION_SHARE)
		result.append(points[0].lerp(points[1], transition / maxf(first_length, 0.001)))
	for index in range(1, points.size() - 1):
		result.append(points[index])
	var last := points.size() - 1
	if not points[last].is_equal_approx(finish):
		var last_length := points[last].distance_to(points[last - 1])
		var transition := minf(maxf(STATION_TRANSITION_MIN, points[last].distance_to(finish)), last_length * STATION_TRANSITION_SHARE)
		result.append(points[last].lerp(points[last - 1], transition / maxf(last_length, 0.001)))
	result.append(finish)

static func circuit(graph: TransitGraph, line: TransitLine, lines: Array[TransitLine], corridors: Dictionary = {}) -> Dictionary:
	var centerline := PackedVector2Array()
	if line.tracks.is_empty():
		return {"points": centerline, "cumulative_lengths": PackedFloat64Array(), "centerline": centerline, "running_paths": [], "stops": PackedFloat32Array(), "outbound_end": 0.0, "length": 0.0}
	if corridors.is_empty():
		corridors = corridor_layout(graph, lines)
	if corridors["aligned"]:
		centerline = _aligned_centerline(graph, line, corridors)
	else:
		for index in range(line.tracks.size()):
			var track := graph.tracks[line.tracks[index]]
			var offset := track_offset(track.id, line.id, lines)
			var points := offset_points(anchors(graph, track), offset)
			if track.a != line.stations[index]:
				points.reverse()
			if not is_zero_approx(offset):
				_append_station_connected(centerline, points, graph.stations[line.stations[index]].position, graph.stations[line.stations[index + 1]].position)
			else:
				if not centerline.is_empty() and not centerline[centerline.size() - 1].is_equal_approx(points[0]):
					centerline.append(graph.stations[line.stations[index]].position)
				centerline.append_array(points)
	var station_positions: Array[Vector2] = []
	for station_id: int in line.stations:
		station_positions.append(graph.stations[station_id].position)
	if line.is_loop():
		if not centerline[centerline.size() - 1].is_equal_approx(centerline[0]):
			centerline.append(graph.stations[line.stations[0]].position)
			centerline.append(centerline[0])
		centerline = simplify(centerline, PackedVector2Array(station_positions))
		var midpoint := centerline[centerline.size() - 2].lerp(centerline[0], 0.5)
		var cyclic := PackedVector2Array([midpoint])
		cyclic.append_array(centerline.slice(0, centerline.size() - 1))
		cyclic.append(midpoint)
		centerline = round_corners_preserving(cyclic, station_positions)
		var outbound_loop := offset_points(centerline, LANE_OFFSET)
		var inbound_loop := offset_points(centerline, -LANE_OFFSET)
		inbound_loop.reverse()
		var outbound_route := _loop_route(graph, line, lines, outbound_loop, false)
		var inbound_route := _loop_route(graph, line, lines, inbound_loop, true)
		outbound_route["centerline"] = centerline
		outbound_route["running_paths"] = [outbound_loop, inbound_loop]
		outbound_route["reverse_route"] = inbound_route
		return outbound_route
	# Round the whole route before separating the lanes. Joining already
	# offset tracks through a station pinches opposing lanes into each other.
	centerline = round_corners_preserving(centerline, station_positions)
	var terminal_insets := PackedFloat32Array()
	for station_id: int in [line.stations[0], line.stations.back()]:
		terminal_insets.append(station_stop_clearance(station_id, lines))
	var shared_length := float(line.wagon_count) * CAR_PITCH + maxf(terminal_insets[0], terminal_insets[1]) + CAR_LENGTH * 0.5
	var terminal_length := minf(shared_length + 64.0, length(centerline) * 0.5 - 6.0)
	if line.stations.size() > 2:
		var first_section := _distance_to_point(centerline, graph.stations[line.stations[1]].position, 0).x
		var last_section := length(centerline) - _distance_to_point(centerline, graph.stations[line.stations[line.stations.size() - 2]].position, 0).x
		terminal_length = minf(terminal_length, minf(first_section, last_section) - 6.0)
	var terminal_ready := terminal_length >= shared_length + 12.0
	var outbound := _terminal_lane(centerline, LANE_OFFSET, shared_length, terminal_length) if terminal_ready else offset_points(centerline, LANE_OFFSET)
	var inbound := _terminal_lane(centerline, -LANE_OFFSET, shared_length, terminal_length) if terminal_ready else offset_points(centerline, -LANE_OFFSET)
	inbound.reverse()
	var stop_positions: Array[Vector2] = []
	for station_index in range(1, line.stations.size()):
		stop_positions.append(closest_point(outbound, graph.stations[line.stations[station_index]].position))
	for station_index in range(line.stations.size() - 2, -1, -1):
		stop_positions.append(closest_point(inbound, graph.stations[line.stations[station_index]].position))
	var result := outbound.duplicate()
	var outbound_length := length(outbound)
	result.append_array(inbound)
	var cumulative := cumulative_lengths(result)
	var stops := PackedFloat32Array()
	var search_from := 0
	for position: Vector2 in stop_positions:
		var mark := _distance_to_point(result, position, search_from)
		stops.append(mark.x)
		search_from = int(mark.y)
	var total := length(result)
	for index in range(stops.size()):
		var station_index := index + 1 if index < line.stations.size() - 1 else stops.size() - 1 - index
		if station_index > 0 and station_index < line.stations.size() - 1:
			var station_id: int = line.stations[station_index]
			stops[index] = _approach_stop(result, stops[index], graph.stations[station_id].position, station_stop_clearance(station_id, lines), cumulative)
	stops[line.stations.size() - 2] = outbound_length - terminal_insets[1]
	stops[stops.size() - 1] = total - terminal_insets[0]
	var outbound_entry := _distance_to_point(outbound, point_at_distance(centerline, length(centerline) - terminal_length), 0).x
	var inbound_entry := outbound_length + _distance_to_point(inbound, point_at_distance(centerline, terminal_length), 0).x
	var near_exit := total + _distance_to_point(outbound, point_at_distance(centerline, terminal_length), 0).x
	var far_exit := outbound_length + _distance_to_point(inbound, point_at_distance(centerline, length(centerline) - terminal_length), 0).x
	var entry_margin := CAR_LENGTH * 0.5 + SAFETY_GAP
	return {"points": result, "cumulative_lengths": cumulative, "centerline": centerline, "running_paths": [outbound, inbound], "stops": stops, "outbound_end": outbound_length, "length": total, "terminal_ready": terminal_ready, "terminal_insets": terminal_insets, "terminal_entries": PackedFloat32Array([inbound_entry - entry_margin, outbound_entry - entry_margin]), "terminal_exits": PackedFloat32Array([near_exit, far_exit])}

static func reversal_distance(route: Dictionary, wagons: int, stop_index: int) -> float:
	var terminal := 0 if stop_index == route["stops"].size() - 1 else 1
	return wagons * CAR_PITCH + 2.0 * float(route["terminal_insets"][terminal])

static func _terminal_lane(centerline: PackedVector2Array, offset: float, shared_length: float, terminal_length: float) -> PackedVector2Array:
	var sampled := PackedVector2Array()
	var distances := PackedFloat32Array()
	var traveled := 0.0
	var total := length(centerline)
	sampled.append(centerline[0])
	distances.append(0.0)
	for index in range(1, centerline.size()):
		var segment_length := centerline[index - 1].distance_to(centerline[index])
		var steps := maxi(1, ceili(segment_length / 4.0))
		for step in range(1, steps + 1):
			var distance := traveled + segment_length * float(step) / steps
			if step < steps and distance > terminal_length + 4.0 and distance < total - terminal_length - 4.0:
				continue
			sampled.append(centerline[index - 1].lerp(centerline[index], float(step) / steps))
			distances.append(distance)
		traveled += segment_length
	var shifted := offset_points(sampled, offset)
	for index in range(sampled.size()):
		var distance := minf(distances[index], traveled - distances[index])
		shifted[index] = sampled[index].lerp(shifted[index], smoothstep(shared_length, terminal_length, distance))
	return shifted

static func station_center_radius(line_count: int) -> float:
	return 10.0 + maxi(0, line_count - 1)

static func station_radius(line_count: int) -> float:
	return station_center_radius(line_count) + 2.0 * maxi(1, line_count)

static func station_stop_clearance(station_id: int, lines: Array[TransitLine]) -> float:
	var serving := 0
	for line: TransitLine in lines:
		if line.stations.has(station_id):
			serving += 1
	return station_radius(serving) + CAR_LENGTH * 0.5 + TERMINAL_GAP

static func _approach_stop(points: PackedVector2Array, mark: float, position: Vector2, clearance: float, cumulative: PackedFloat64Array) -> float:
	var total := cumulative[cumulative.size() - 1]
	var traveled := 0.0
	# Walk backwards to the approach-side circle boundary, including loop wrap.
	while traveled < total:
		var distance := fposmod(mark - traveled, total)
		if point_at_distance(points, distance, cumulative).distance_squared_to(position) >= clearance * clearance:
			var low := maxf(0.0, traveled - 1.0)
			var high := traveled
			for iteration in range(12):
				var middle := (low + high) * 0.5
				if point_at_distance(points, fposmod(mark - middle, total), cumulative).distance_squared_to(position) >= clearance * clearance:
					high = middle
				else:
					low = middle
			return fposmod(mark - high, total)
		traveled += 1.0
	assert(false, "A running path must leave its station marker before a stop can be placed.")
	return mark

static func _loop_route(graph: TransitGraph, line: TransitLine, lines: Array[TransitLine], points: PackedVector2Array, reverse: bool) -> Dictionary:
	var stops := PackedFloat32Array()
	var cumulative := cumulative_lengths(points)
	var search_from := 0
	for index in range(line.stations.size() - 1):
		var station_index := line.stations.size() - 2 - index if reverse else index
		var position := closest_point(points, graph.stations[line.stations[station_index]].position)
		var mark := _distance_to_point(points, position, search_from)
		stops.append(_approach_stop(points, mark.x, graph.stations[line.stations[station_index]].position, station_stop_clearance(line.stations[station_index], lines), cumulative))
		search_from = int(mark.y)
	return {"points": points, "cumulative_lengths": cumulative, "stops": stops, "outbound_end": length(points), "length": length(points)}

static func route_for_direction(route: Dictionary, direction: int) -> Dictionary:
	return route["reverse_route"] if direction < 0 and route.has("reverse_route") else route

static func _distance_to_point(points: PackedVector2Array, point: Vector2, search_from: int) -> Vector2:
	var traveled := 0.0
	var best_distance := INF
	var best_mark := Vector2.ZERO
	for index in range(1, points.size()):
		var segment_length := points[index - 1].distance_to(points[index])
		if index >= search_from:
			var projected := Geometry2D.get_closest_point_to_segment(point, points[index - 1], points[index])
			var distance := projected.distance_squared_to(point)
			if distance < best_distance:
				best_distance = distance
				best_mark = Vector2(traveled + points[index - 1].distance_to(projected), index)
		traveled += segment_length
	return best_mark

static func car_position(points: PackedVector2Array, total_length: float, head_distance: float, car_index: int, cumulative: PackedFloat64Array = PackedFloat64Array()) -> Vector2:
	return point_at_distance(points, fposmod(head_distance - float(car_index) * CAR_PITCH, total_length), cumulative)

static func car_axis(points: PackedVector2Array, total: float, distance: float, head_distance: float, cumulative: PackedFloat64Array = PackedFloat64Array()) -> Vector2:
	var before := point_at_distance(points, fposmod(distance - 2.0, total), cumulative)
	var after := point_at_distance(points, fposmod(distance + 2.0, total), cumulative)
	var axis := after - before
	if axis.length_squared() < 0.0001:
		var center := point_at_distance(points, fposmod(distance, total), cumulative)
		axis = after - center if head_distance > distance + 0.01 else center - before
	return axis.normalized()

static func train_length(wagon_count: int) -> float:
	return float(wagon_count) * CAR_PITCH + CAR_LENGTH
