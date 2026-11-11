class_name TransitGraph
extends RefCounted

var stations: Array[Station] = []
var tracks: Array[Track] = []
var _track_lookup: Dictionary = {}

func add_station(station_position: Vector2) -> Station:
	var station := Station.new(stations.size(), station_position)
	stations.append(station)
	return station

func add_track(station_a: int, station_b: int) -> Track:
	if station_a < 0 or station_b < 0 or station_a >= stations.size() or station_b >= stations.size():
		return null
	if station_a == station_b:
		return null
	var key := _pair_key(station_a, station_b)
	if _track_lookup.has(key):
		return tracks[_track_lookup[key]]
	var track := Track.new(tracks.size(), station_a, station_b)
	tracks.append(track)
	_track_lookup[key] = track.id
	return track

func track_between(station_a: int, station_b: int) -> Track:
	var key := _pair_key(station_a, station_b)
	if not _track_lookup.has(key):
		return null
	return tracks[_track_lookup[key]]

func first_neighbor(station_id: int, excluded_station: int) -> int:
	for track: Track in tracks:
		if track.a == station_id and track.b != excluded_station:
			return track.b
		if track.b == station_id and track.a != excluded_station:
			return track.a
	return -1

func _pair_key(station_a: int, station_b: int) -> String:
	return "%d:%d" % [mini(station_a, station_b), maxi(station_a, station_b)]

func remove_track(track_id: int, lines: Array[TransitLine]) -> void:
	assert(track_id >= 0 and track_id < tracks.size())
	_split_lines(lines, -1, track_id)
	tracks.remove_at(track_id)
	_reindex(lines)

func remove_line(line_id: int, lines: Array[TransitLine]) -> void:
	assert(line_id >= 0 and line_id < lines.size())
	var removed := lines[line_id]
	lines.remove_at(line_id)
	for index in range(lines.size()):
		lines[index].id = index
	for index in range(tracks.size() - 1, -1, -1):
		if removed.tracks.has(index) and not lines.any(func(line: TransitLine) -> bool: return line.tracks.has(index)):
			tracks.remove_at(index)
	_reindex(lines)
	for station_id in range(stations.size() - 1, -1, -1):
		if not removed.stations.has(station_id):
			continue
		var shared := lines.any(func(line: TransitLine) -> bool: return line.stations.has(station_id))
		var connected := tracks.any(func(track: Track) -> bool: return track.a == station_id or track.b == station_id)
		if not shared and not connected:
			remove_station(station_id, lines)

func remove_station(station_id: int, lines: Array[TransitLine]) -> void:
	assert(station_id >= 0 and station_id < stations.size())
	for line: TransitLine in lines:
		var closed := line.is_loop()
		var ordered: Array[int] = line.stations.slice(0, line.stations.size() - 1) if closed else line.stations.duplicate()
		var index := ordered.find(station_id)
		if index < 0:
			continue
		if (closed and ordered.size() > 3) or (not closed and index > 0 and index < ordered.size() - 1):
			var before := ordered[posmod(index - 1, ordered.size())]
			var after := ordered[(index + 1) % ordered.size()]
			if track_between(before, after) == null:
				var incoming := track_between(before, station_id)
				var outgoing := track_between(station_id, after)
				var path := TrackGeometry.anchors(self, incoming)
				if incoming.a != before:
					path.reverse()
				var tail := TrackGeometry.anchors(self, outgoing)
				if outgoing.a != station_id:
					tail.reverse()
				path.append_array(tail.slice(1))
				add_track(before, after).waypoints = path
		ordered.remove_at(index)
		if closed and ordered.size() >= 3:
			ordered.append(ordered[0])
		line.stations = ordered
	for index in range(tracks.size() - 1, -1, -1):
		var track := tracks[index]
		if track.a == station_id or track.b == station_id:
			tracks.remove_at(index)
	stations.remove_at(station_id)
	for track: Track in tracks:
		if track.a > station_id:
			track.a -= 1
		if track.b > station_id:
			track.b -= 1
	for line: TransitLine in lines:
		for index in range(line.stations.size()):
			if line.stations[index] > station_id:
				line.stations[index] -= 1
	_reindex(lines)

func _split_lines(lines: Array[TransitLine], station_id: int, track_id: int) -> void:
	var original_lines := lines.duplicate()
	for line: TransitLine in original_lines:
		if line.is_loop():
			var cut := -1
			if station_id >= 0:
				cut = line.stations.find(station_id)
			elif track_id >= 0:
				cut = line.tracks.find(track_id)
			if cut >= 0:
				var ring := line.stations.slice(0, line.stations.size() - 1)
				var start := (cut + 1) % ring.size()
				var opened: Array[int] = []
				for offset in range(ring.size() - (1 if station_id >= 0 else 0)):
					opened.append(ring[(start + offset) % ring.size()])
				line.stations = opened
				line.tracks.clear()
				for index in range(1, opened.size()):
					line.tracks.append(track_between(opened[index - 1], opened[index]).id)
		var fragments: Array[Array] = []
		var fragment: Array[int] = []
		for index in range(line.stations.size()):
			if index > 0 and line.tracks[index - 1] == track_id and track_id >= 0:
				if not fragment.is_empty():
					fragments.append(fragment)
				fragment = []
			if line.stations[index] == station_id:
				if not fragment.is_empty():
					fragments.append(fragment)
				fragment = []
			else:
				fragment.append(line.stations[index])
		if not fragment.is_empty():
			fragments.append(fragment)
		line.stations.clear()
		line.tracks.clear()
		if fragments.is_empty():
			continue
		line.stations.assign(fragments[0])
		for index in range(1, fragments.size()):
			var extra := TransitLine.new(lines.size(), line.color)
			extra.display_name = line.display_name
			extra.render_priority = line.render_priority
			extra.dispatch_rate = line.dispatch_rate
			extra.dwell_time = line.dwell_time
			extra.cruise_velocity = line.cruise_velocity
			extra.acceleration = line.acceleration
			extra.braking = line.braking
			extra.terminal_recovery = line.terminal_recovery
			extra.wagon_count = line.wagon_count
			extra.max_trains = line.max_trains
			extra.stations.assign(fragments[index])
			lines.append(extra)

func _reindex(lines: Array[TransitLine]) -> void:
	_track_lookup.clear()
	for index in range(stations.size()):
		stations[index].id = index
	for index in range(tracks.size()):
		var track := tracks[index]
		track.id = index
		_track_lookup[_pair_key(track.a, track.b)] = index
	for line: TransitLine in lines:
		line.tracks.clear()
		for index in range(1, line.stations.size()):
			var track := track_between(line.stations[index - 1], line.stations[index])
			assert(track != null, "A surviving line fragment must retain all its physical tracks.")
			line.tracks.append(track.id)

func insert_station(track_id: int, position: Vector2, lines: Array[TransitLine]) -> String:
	assert(track_id >= 0 and track_id < tracks.size())
	if not (position / 48.0).is_equal_approx((position / 48.0).round()):
		return "Le tracé doit suivre la grille."
	for station: Station in stations:
		if station.position.distance_to(position) < 24.0:
			return "Les stations ont besoin d'un peu d'espace."
	var track := tracks[track_id]
	var paths := TrackGeometry.split_at(TrackGeometry.anchors(self, track), position)
	if paths.is_empty():
		return "Choisissez un point de grille sur le rail."
	for line: TransitLine in lines:
		if not line.tracks.has(track_id):
			continue
		for path: PackedVector2Array in paths:
			if TrackGeometry.length(TrackGeometry.round_corners(path)) < TrackGeometry.train_length(line.wagon_count) + 40.0:
				return "La rame serait trop longue pour ce segment."
	var station := add_station(position)
	for line: TransitLine in lines:
		var index := line.tracks.find(track_id)
		if index >= 0:
			line.stations.insert(index + 1, station.id)
	tracks.remove_at(track_id)
	# Keep canonical a-to-b orientation even when shared lines run in reverse.
	var first := Track.new(tracks.size(), track.a, station.id)
	first.waypoints = paths[0]
	tracks.append(first)
	var second := Track.new(tracks.size(), station.id, track.b)
	second.waypoints = paths[1]
	tracks.append(second)
	_reindex(lines)
	return ""

func path_error(from_id: int, to_id: int, points: PackedVector2Array, open_end: bool = false) -> String:
	if from_id < 0 or (to_id < 0 and not open_end) or from_id >= stations.size() or to_id >= stations.size() or from_id == to_id:
		return "Choisissez deux stations différentes."
	if points.size() < 2:
		return "Dessinez un chemin entre les stations."
	if not points[0].is_equal_approx(stations[from_id].position) or (not open_end and not points[points.size() - 1].is_equal_approx(stations[to_id].position)):
		return "Le tracé doit commencer et finir sur les stations."
	for index in range(points.size()):
		if not (points[index] / 48.0).is_equal_approx((points[index] / 48.0).round()):
			return "Le tracé doit suivre la grille."
		if index > 0 and points[index].is_equal_approx(points[index - 1]):
			return "Le tracé contient un segment vide."
		if index > 1:
			var before := (points[index - 1] - points[index - 2]).normalized()
			var after := (points[index] - points[index - 1]).normalized()
			if before.dot(after) < -0.8:
				return "Évitez de revenir sur le segment précédent."
		for previous in range(1, index - 1):
			if _segments_conflict(points[previous - 1], points[previous], points[index - 1], points[index]):
				return "Une ligne ne peut pas se croiser elle-même."
	return ""

func _segments_conflict(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
		return true
	if absf((b - a).cross(c - a)) > 0.01 or absf((b - a).cross(d - a)) > 0.01:
		return false
	var direction := (b - a).normalized()
	var start := (c - a).dot(direction)
	var finish := (d - a).dot(direction)
	return minf(maxf(start, finish), a.distance_to(b)) - maxf(minf(start, finish), 0.0) > 0.1
