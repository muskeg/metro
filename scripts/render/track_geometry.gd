class_name TrackGeometry
extends RefCounted

const LANE_OFFSET := 8.0
const CORRIDOR_SPACING := 32.0
const CAR_LENGTH := 19.8
const CAR_PITCH := CAR_LENGTH + 1.0
const CAR_SCALE := CAR_LENGTH / 12.0
const CAR_WIDTH := 7.0
const SAFETY_GAP := 14.0
const GRID_SIZE := 48.0
const TERMINAL_GAP := 3.0

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
		for step in range(1, 9):
			var t := float(step) / 8.0
			result.append(entry.lerp(corner, t).lerp(corner.lerp(exit, t), t))
	result.append(anchors[anchors.size() - 1])
	return result

static func length(points: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(1, points.size()):
		total += points[index - 1].distance_to(points[index])
	return total

static func point_at_distance(points: PackedVector2Array, distance: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var remaining := maxf(distance, 0.0)
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

static func circuit(graph: TransitGraph, line: TransitLine, lines: Array[TransitLine]) -> Dictionary:
	var centerline := PackedVector2Array()
	if line.tracks.is_empty():
		return {"points": centerline, "centerline": centerline, "running_paths": [], "stops": PackedFloat32Array(), "outbound_end": 0.0, "length": 0.0}
	for index in range(line.tracks.size()):
		var track := graph.tracks[line.tracks[index]]
		var points := offset_points(anchors(graph, track), track_offset(track.id, line.id, lines))
		if track.a != line.stations[index]:
			points.reverse()
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
		centerline = simplify(centerline)
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
			stops[index] = _approach_stop(result, stops[index], graph.stations[station_id].position, station_stop_clearance(station_id, lines))
	stops[line.stations.size() - 2] = outbound_length - terminal_insets[1]
	stops[stops.size() - 1] = total - terminal_insets[0]
	var outbound_entry := _distance_to_point(outbound, point_at_distance(centerline, length(centerline) - terminal_length), 0).x
	var inbound_entry := outbound_length + _distance_to_point(inbound, point_at_distance(centerline, terminal_length), 0).x
	var near_exit := total + _distance_to_point(outbound, point_at_distance(centerline, terminal_length), 0).x
	var far_exit := outbound_length + _distance_to_point(inbound, point_at_distance(centerline, length(centerline) - terminal_length), 0).x
	var entry_margin := CAR_LENGTH * 0.5 + SAFETY_GAP
	return {"points": result, "centerline": centerline, "running_paths": [outbound, inbound], "stops": stops, "outbound_end": outbound_length, "length": total, "terminal_ready": terminal_ready, "terminal_insets": terminal_insets, "terminal_entries": PackedFloat32Array([inbound_entry - entry_margin, outbound_entry - entry_margin]), "terminal_exits": PackedFloat32Array([near_exit, far_exit])}

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

static func station_stop_clearance(station_id: int, lines: Array[TransitLine]) -> float:
	var serving := 0
	for line: TransitLine in lines:
		if line.stations.has(station_id):
			serving += 1
	return 10.0 + 2.0 * maxi(1, serving) + CAR_LENGTH * 0.5 + TERMINAL_GAP

static func _approach_stop(points: PackedVector2Array, mark: float, position: Vector2, clearance: float) -> float:
	var total := length(points)
	var traveled := 0.0
	# Walk backwards to the approach-side circle boundary, including loop wrap.
	while traveled < total:
		var distance := fposmod(mark - traveled, total)
		if point_at_distance(points, distance).distance_squared_to(position) >= clearance * clearance:
			var low := maxf(0.0, traveled - 1.0)
			var high := traveled
			for iteration in range(12):
				var middle := (low + high) * 0.5
				if point_at_distance(points, fposmod(mark - middle, total)).distance_squared_to(position) >= clearance * clearance:
					high = middle
				else:
					low = middle
			return fposmod(mark - high, total)
		traveled += 1.0
	assert(false, "A running path must leave its station marker before a stop can be placed.")
	return mark

static func _loop_route(graph: TransitGraph, line: TransitLine, lines: Array[TransitLine], points: PackedVector2Array, reverse: bool) -> Dictionary:
	var stops := PackedFloat32Array()
	var search_from := 0
	for index in range(line.stations.size() - 1):
		var station_index := line.stations.size() - 2 - index if reverse else index
		var position := closest_point(points, graph.stations[line.stations[station_index]].position)
		var mark := _distance_to_point(points, position, search_from)
		stops.append(_approach_stop(points, mark.x, graph.stations[line.stations[station_index]].position, station_stop_clearance(line.stations[station_index], lines)))
		search_from = int(mark.y)
	return {"points": points, "stops": stops, "outbound_end": length(points), "length": length(points)}

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

static func car_position(points: PackedVector2Array, total_length: float, head_distance: float, car_index: int) -> Vector2:
	return point_at_distance(points, fposmod(head_distance - float(car_index) * CAR_PITCH, total_length))

static func car_axis(points: PackedVector2Array, total: float, distance: float, head_distance: float) -> Vector2:
	var before := point_at_distance(points, fposmod(distance - 2.0, total))
	var after := point_at_distance(points, fposmod(distance + 2.0, total))
	var axis := after - before
	if axis.length_squared() < 0.0001:
		var center := point_at_distance(points, fposmod(distance, total))
		axis = after - center if head_distance > distance + 0.01 else center - before
	return axis.normalized()

static func train_length(wagon_count: int) -> float:
	return float(wagon_count) * CAR_PITCH + CAR_LENGTH
