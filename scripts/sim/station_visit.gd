class_name StationVisit
extends RefCounted

const MAX_EXTRA_DWELL := 2.0
const FADE_TIME := 1.2
const PLACES_PER_CAR := 12
const PASSENGER_RADIUS := 0.34
const PASSENGER_SPEED := 4.0

var elapsed := 0.0
var departure_age := -1.0
var initial_passengers := 0
var alighting := 0
var boarding := 0
var exchange_duration := 0.0
var alighting_duration := 0.0
var opening_duration := 0.0
var boarding_duration := 0.0
var doors := PackedVector2Array()
var normals := PackedVector2Array()
var centers := PackedVector2Array()
var axes := PackedVector2Array()
var platform := PackedVector2Array()
var platform_edge := PackedVector2Array()
var platform_safety_edge := PackedVector2Array()
var platform_seams := PackedVector2Array()
var tactile_dots := PackedVector2Array()
var boarding_traits := PackedVector4Array()
var alighting_traits := PackedVector4Array()
var boarding_paths: Array[PackedVector2Array] = []
var alighting_paths: Array[PackedVector2Array] = []

func _init(train: Metro, route: Dictionary, minimum_dwell: float, terminal: bool) -> void:
	initial_passengers = train.passenger_count
	var door_count := (train.wagon_count + 1) * 2
	var seed_value := train.line_id * 17 + train.arrival_count * 11 + train.next_stop_index * 3
	alighting = initial_passengers if terminal else mini(initial_passengers, door_count + seed_value % (door_count * 3))
	var capacity := (train.wagon_count + 1) * PLACES_PER_CAR
	boarding = mini(capacity - initial_passengers + alighting, door_count * 2 + (seed_value * 3 + 5) % (door_count * 3))
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + train.wagon_count * 101
	for entering: bool in [false, true]:
		var traits := PackedVector4Array()
		var count := boarding if entering else alighting
		for index in range(count):
			traits.append(Vector4(random.randf_range(0.0, 0.2), random.randf_range(0.6, 0.78), random.randf_range(-3.2, 3.2), random.randf_range(8.0, 14.0)))
		if entering:
			boarding_traits = traits
		else:
			alighting_traits = traits
	var raw_alighting := ceilf(float(alighting) / door_count) * 0.4
	var raw_boarding := ceilf(float(boarding) / door_count) * 0.4
	var raw_total := 0.35 + raw_alighting + raw_boarding
	exchange_duration = minf(raw_total, minimum_dwell + MAX_EXTRA_DWELL)
	var scale := exchange_duration / raw_total
	opening_duration = 0.35 * scale
	alighting_duration = raw_alighting * scale
	boarding_duration = raw_boarding * scale
	var points: PackedVector2Array = route["points"]
	var total: float = route["length"]
	for car in range(train.wagon_count + 1):
		var distance := train.distance - float(car) * TrackGeometry.CAR_PITCH
		var center := TrackGeometry.point_at_distance(points, fposmod(distance, total))
		var axis := TrackGeometry.car_axis(points, total, distance, train.distance)
		var normal := Vector2(-axis.y, axis.x)
		centers.append(center)
		axes.append(axis)
		for door_x: float in [-1.75, 1.15]:
			doors.append(center + axis * door_x * TrackGeometry.CAR_SCALE + normal * 3.3)
			normals.append(normal)
	var outer := PackedVector2Array()
	for car in range(centers.size()):
		var normal := Vector2(-axes[car].y, axes[car].x)
		var ends := PackedFloat32Array([0.0])
		if car == 0:
			ends.insert(0, TrackGeometry.CAR_LENGTH * 0.5)
		if car == centers.size() - 1:
			ends.append(-TrackGeometry.CAR_LENGTH * 0.5)
		for end: float in ends:
			var point := centers[car] + axes[car] * end
			platform_edge.append(point + normal * 4.8)
			outer.append(point + normal * 10.5)
	var edge_steps := PackedInt32Array()
	for index in range(1, platform_edge.size()):
		edge_steps.append(maxi(1, ceili(maxf(platform_edge[index - 1].distance_to(platform_edge[index]), outer[index - 1].distance_to(outer[index])) / 2.0)))
	platform_edge = _smooth_edge(platform_edge, edge_steps)
	outer = _smooth_edge(outer, edge_steps)
	var inner_simplified := PackedVector2Array([platform_edge[0]])
	var outer_simplified := PackedVector2Array([outer[0]])
	for index in range(1, platform_edge.size() - 1):
		var inner_turn := (platform_edge[index] - inner_simplified[inner_simplified.size() - 1]).cross(platform_edge[index + 1] - platform_edge[index])
		var outer_turn := (outer[index] - outer_simplified[outer_simplified.size() - 1]).cross(outer[index + 1] - outer[index])
		if absf(inner_turn) > 0.00001 or absf(outer_turn) > 0.00001:
			inner_simplified.append(platform_edge[index])
			outer_simplified.append(outer[index])
	inner_simplified.append(platform_edge[platform_edge.size() - 1])
	outer_simplified.append(outer[outer.size() - 1])
	platform_edge = inner_simplified
	outer = outer_simplified
	for index in range(platform_edge.size()):
		platform_safety_edge.append(platform_edge[index].lerp(outer[index], 0.6 / 5.7))
	platform = platform_edge.duplicate()
	outer.reverse()
	platform.append_array(outer)
	var outlines := 0
	for polygon: PackedVector2Array in Geometry2D.merge_polygons(platform, platform):
		if not Geometry2D.is_polygon_clockwise(polygon):
			platform = polygon
			outlines += 1
	assert(outlines == 1, "A station platform must remain one connected outline.")
	outer.reverse()
	var traveled := 0.0
	var next_dot := 0.5
	var next_seam := 2.0
	for index in range(1, platform_edge.size()):
		var segment := platform_edge[index - 1].distance_to(platform_edge[index])
		while next_dot <= traveled + segment:
			var fraction := (next_dot - traveled) / maxf(segment, 0.000001)
			var inner := platform_edge[index - 1].lerp(platform_edge[index], fraction)
			var far_edge := outer[index - 1].lerp(outer[index], fraction)
			for depth: float in [0.45, 0.85]:
				var dot := inner.lerp(far_edge, depth / 5.7)
				if Geometry2D.is_point_in_polygon(dot, platform):
					tactile_dots.append(dot)
			next_dot += 1.0
		while next_seam <= traveled + segment:
			var fraction := (next_seam - traveled) / maxf(segment, 0.000001)
			var inner := platform_edge[index - 1].lerp(platform_edge[index], fraction)
			var far_edge := outer[index - 1].lerp(outer[index], fraction)
			var seam_start := inner.lerp(far_edge, 1.2 / 5.7)
			var seam_end := inner.lerp(far_edge, 5.3 / 5.7)
			if Geometry2D.is_point_in_polygon(seam_start, platform) and Geometry2D.is_point_in_polygon(seam_end, platform):
				platform_seams.append(seam_start)
				platform_seams.append(seam_end)
			next_seam += 4.0
		traveled += segment
	var walking_areas := Geometry2D.offset_polygon(platform, -PASSENGER_RADIUS - 0.2, Geometry2D.JOIN_MITER)
	assert(not walking_areas.is_empty(), "A platform must have room for its passengers.")
	for entering: bool in [false, true]:
		for index in range(boarding if entering else alighting):
			var traits := boarding_traits[index] if entering else alighting_traits[index]
			var door_index := index % doors.size()
			var normal := normals[door_index]
			var axis := Vector2(normal.y, -normal.x)
			var near := doors[door_index] + normal * (1.8 + (traits.w - 8.0) * 0.2) + axis * traits.z * 0.5
			var area := walking_areas[0]
			var nearest := INF
			for candidate: PackedVector2Array in walking_areas:
				var point := _inside_platform(near, candidate)
				if near.distance_squared_to(point) < nearest:
					nearest = near.distance_squared_to(point)
					area = candidate
			near = _inside_platform(near, area)
			var far := _inside_platform(near + normal * (2.5 + traits.w * 0.1) + axis * traits.z * 0.8, area)
			var segments := Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([near, far]), area)
			var connected := near
			for segment_path: PackedVector2Array in segments:
				if segment_path[0].distance_to(near) < 0.01:
					connected = segment_path[segment_path.size() - 1]
					break
			far = connected
			var timing := _passenger_timing(index, entering)
			# Smoothstep's peak derivative is 1.5, so shorten rather than speed up.
			if entering:
				var maximum_distance := PASSENGER_SPEED * (timing.x + timing.y) / 1.5
				far = near.move_toward(far, maximum_distance)
				boarding_paths.append(PackedVector2Array([far, near]))
			else:
				alighting_paths.append(PackedVector2Array([near, far]))

static func _inside_platform(point: Vector2, polygon: PackedVector2Array) -> Vector2:
	if Geometry2D.is_point_in_polygon(point, polygon):
		return point
	var nearest := polygon[0]
	var distance := INF
	for index in range(polygon.size()):
		var candidate := Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])
		if point.distance_squared_to(candidate) < distance:
			nearest = candidate
			distance = point.distance_squared_to(candidate)
	return nearest

static func _smooth_edge(edge: PackedVector2Array, edge_steps: PackedInt32Array) -> PackedVector2Array:
	# Uniform samples prevent tiny car-join segments from retaining sharp steps.
	var sampled := PackedVector2Array([edge[0]])
	for index in range(1, edge.size()):
		var steps := edge_steps[index - 1]
		for step in range(1, steps + 1):
			sampled.append(edge[index - 1].lerp(edge[index], float(step) / steps))
	var averaged := sampled.duplicate()
	for index in range(1, sampled.size() - 1):
		var point := Vector2.ZERO
		var weight := 0.0
		for offset in range(-3, 4):
			var neighbor := clampi(index + offset, 0, sampled.size() - 1)
			var influence := float(4 - absi(offset))
			point += sampled[neighbor] * influence
			weight += influence
		averaged[index] = point / weight
	edge = averaged
	for iteration in range(4):
		var smooth := PackedVector2Array([edge[0]])
		for index in range(1, edge.size()):
			smooth.append(edge[index - 1].lerp(edge[index], 0.25))
			smooth.append(edge[index - 1].lerp(edge[index], 0.75))
		smooth.append(edge[edge.size() - 1])
		edge = smooth
	return edge

func _passenger_timing(index: int, entering: bool) -> Vector2:
	var count := boarding if entering else alighting
	var traits := boarding_traits[index] if entering else alighting_traits[index]
	var duration := boarding_duration if entering else alighting_duration
	var start := opening_duration + (alighting_duration if entering else 0.0)
	var batches := maxi(1, ceili(float(count) / doors.size()))
	var step := duration / batches
	return Vector2(start + (float(index / doors.size()) + traits.x) * step, step * traits.y)

func passenger_progress(index: int, entering: bool) -> float:
	var timing := _passenger_timing(index, entering)
	if elapsed >= timing.x + timing.y - 0.000001:
		return 1.0
	return clampf((elapsed - timing.x) / maxf(0.001, timing.y), 0.0, 1.0)

func passenger_position(index: int, entering: bool) -> Vector2:
	var path := boarding_paths[index] if entering else alighting_paths[index]
	var timing := _passenger_walk_timing(index, entering)
	var progress := clampf((elapsed - timing.x) / maxf(0.001, timing.y), 0.0, 1.0)
	return path[0].lerp(path[1], smoothstep(0.0, 1.0, progress))

func _passenger_walk_timing(index: int, entering: bool) -> Vector2:
	var timing := _passenger_timing(index, entering)
	var path := boarding_paths[index] if entering else alighting_paths[index]
	var duration := maxf(timing.y, path[0].distance_to(path[1]) * 1.5 / PASSENGER_SPEED)
	if entering:
		return Vector2(maxf(0.0, timing.x + timing.y - duration), duration)
	return Vector2(timing.x, duration)

func passenger_opacity(index: int, entering: bool) -> float:
	var progress := passenger_progress(index, entering)
	if entering:
		var traits := boarding_traits[index]
		return smoothstep(0.0, 0.35 + traits.x, elapsed) * (1.0 - smoothstep(0.85, 1.0, progress))
	if progress <= 0.0:
		return 0.0
	var timing := _passenger_walk_timing(index, false)
	var escape_age := maxf(0.0, elapsed - timing.x - timing.y)
	return smoothstep(0.0, 0.15, progress) * (1.0 - smoothstep(0.4, 2.1, escape_age))

func onboard_count() -> int:
	return initial_passengers - _completed_count(false) + _completed_count(true)

func _completed_count(entering: bool) -> int:
	var finished := 0
	for index in range(boarding if entering else alighting):
		if passenger_progress(index, entering) >= 1.0:
			finished += 1
	return finished

func platform_alpha() -> float:
	var alpha := smoothstep(0.0, opening_duration, elapsed)
	if departure_age >= 0.0:
		alpha *= 1.0 - smoothstep(0.0, FADE_TIME, departure_age)
	return alpha
