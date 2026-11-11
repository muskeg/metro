class_name LayoutStore
extends RefCounted

const VERSION := 1
const STARTER_PATH := "res://layouts/metro_demo.json"
const MONTREAL_PATH := "res://layouts/montreal.json"
const BUNDLED_LAYOUTS := {
	"res://layouts/metro_demo.json": "Metro démo (inclus)",
	"res://layouts/jr_east.json": "Tokyo JR central (inclus)",
	"res://layouts/montreal.json": "Montréal métro (inclus)"
}
const MAX_FILE_BYTES := 16 * 1024 * 1024
const MAX_STATIONS := 256
const MAX_TRACKS := 512
const MAX_LINES := 16
const MAX_TRACK_POINTS := 32
const MAX_TOTAL_POINTS := 2048
const MAX_LINE_POINTS := 512
const MAX_SERVICE_POINTS := 4096
const MAX_TOTAL_CALLS := 2048
const MAX_TOTAL_TRAINS := 64
const MAX_COORDINATE := 48000.0
const MAX_TOTAL_LENGTH := 200000.0
const MAX_JSON_DEPTH := 16
const MAX_JSON_TOKENS := 32768
const LINE_FIELDS := ["dispatch_rate", "dwell_time", "cruise_velocity", "acceleration", "braking", "terminal_recovery", "wagon_count", "max_trains"]

var directory := "user://layouts"
var error_message := ""

func load_starter_layout() -> Dictionary:
	return load_bundled_layout(MONTREAL_PATH if OS.has_feature("montreal_startup") else STARTER_PATH)

func load_bundled_layout(path: String) -> Dictionary:
	error_message = ""
	if not BUNDLED_LAYOUTS.has(path):
		_fail("Unknown bundled layout.")
		return {}
	var data := _read(path)
	return {} if data.is_empty() else restore(data)

func capture(graph: TransitGraph, lines: Array[TransitLine], active_id: int, position: Vector2, zoom: float) -> Dictionary:
	var stations: Array = []
	var station_names: Array = []
	var tracks: Array = []
	var saved_lines: Array = []
	for station: Station in graph.stations:
		stations.append([station.position.x, station.position.y])
		station_names.append(station.display_name)
	for track: Track in graph.tracks:
		var points: Array = []
		for point: Vector2 in track.waypoints:
			points.append([point.x, point.y])
		tracks.append({"a": track.a, "b": track.b, "waypoints": points})
	for line: TransitLine in lines:
		var saved := {"color": line.color.to_html(false), "stations": Array(line.stations)}
		if not line.display_name.is_empty():
			saved["name"] = line.display_name
		if line.render_priority != 0:
			saved["render_priority"] = line.render_priority
		for field: String in LINE_FIELDS:
			saved[field] = line.get(field)
		saved_lines.append(saved)
	var snapshot := {"version": VERSION, "stations": stations, "tracks": tracks, "lines": saved_lines,
		"active_line": active_id, "camera": [position.x, position.y], "zoom": clampf(zoom, 0.08, 6.0)}
	if station_names.any(func(value: String) -> bool: return not value.is_empty()):
		snapshot["station_names"] = station_names
	return snapshot

func valid_name(value: String) -> bool:
	return not value.strip_edges().is_empty() and value.strip_edges().length() <= 64 and not value.contains("\n") and not value.contains("\r")

func exists(layout_name: String) -> bool:
	return FileAccess.file_exists(_path(layout_name.strip_edges()))

func names() -> PackedStringArray:
	error_message = ""
	var result := PackedStringArray()
	if not DirAccess.dir_exists_absolute(directory):
		if FileAccess.file_exists(directory):
			_fail("Layout storage path is not a directory.")
		return result
	var dir := DirAccess.open(directory)
	if dir == null:
		_fail("Cannot open layout storage: " + error_string(DirAccess.get_open_error()))
		return result
	for filename: String in dir.get_files():
		if not filename.ends_with(".json"):
			continue
		var data := _read(directory.path_join(filename))
		if data.is_empty():
			return result
		if not data.get("name") is String or not valid_name(data["name"]) or _path(data["name"]).get_file() != filename:
			_fail("Invalid saved layout name: " + filename)
			return result
		result.append(data["name"])
	result.sort()
	return result

func save_layout(layout_name: String, snapshot: Dictionary) -> bool:
	error_message = ""
	layout_name = layout_name.strip_edges()
	if not valid_name(layout_name):
		return _fail("Invalid layout name.")
	if restore(snapshot).is_empty():
		return false
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return _fail("Cannot create layout storage: " + error_string(error))
	var data := snapshot.duplicate(true)
	data["name"] = layout_name
	var buffer := encode_layout(data)
	if buffer.is_empty():
		return false
	return write_layout_file(_path(layout_name), buffer)

func encode_layout(snapshot: Dictionary) -> PackedByteArray:
	if restore(snapshot).is_empty():
		return PackedByteArray()
	var buffer := JSON.stringify(snapshot, "  ", true, true).to_utf8_buffer()
	if buffer.size() > MAX_FILE_BYTES:
		_fail("Layout exceeds the 16 MiB storage limit.")
		return PackedByteArray()
	if not _json_complexity_valid(buffer):
		_fail("Layout JSON exceeds nesting, string or token safety limits.")
		return PackedByteArray()
	return buffer

func decode_layout(buffer: PackedByteArray) -> Dictionary:
	var data := _parse_buffer(buffer)
	return {} if data.is_empty() else restore(data)

func read_layout_file(path: String) -> Dictionary:
	var data := _read(path)
	return {} if data.is_empty() else restore(data)

func write_layout_file(destination: String, buffer: PackedByteArray) -> bool:
	error_message = ""
	if buffer.size() > MAX_FILE_BYTES:
		return _fail("Layout exceeds the 16 MiB storage limit.")
	var temporary := destination + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail("Cannot write layout: " + error_string(FileAccess.get_open_error()))
	file.store_buffer(buffer)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return _fail("Cannot finish writing layout: " + error_string(error))
	# Replace only after the complete file has been written; keep the old save on failure.
	error = DirAccess.rename_absolute(temporary, destination)
	if error != OK:
		return _fail("Cannot replace saved layout: " + error_string(error))
	return true

func load_layout(layout_name: String) -> Dictionary:
	error_message = ""
	if not valid_name(layout_name):
		_fail("Invalid layout name.")
		return {}
	var data := _read(_path(layout_name.strip_edges()))
	if data.is_empty():
		return {}
	if data.get("name") != layout_name.strip_edges():
		_fail("Saved layout name does not match.")
		return {}
	return restore(data)

func restore(data: Dictionary) -> Dictionary:
	error_message = ""
	if data.get("version") != VERSION:
		_fail("Unsupported layout version.")
		return {}
	if not data.get("stations") is Array or not data.get("tracks") is Array or not data.get("lines") is Array or data["lines"].is_empty():
		_fail("Invalid layout collections.")
		return {}
	if data["stations"].size() > MAX_STATIONS or data["tracks"].size() > MAX_TRACKS or data["lines"].size() > MAX_LINES:
		_fail("Layout exceeds station, track or line safety limits.")
		return {}
	var graph := TransitGraph.new()
	var lines: Array[TransitLine] = []
	var positions: Dictionary = {}
	var total_points := 0
	var total_calls := 0
	var total_trains := 0
	var total_length := 0.0
	var service_points := 0
	for point: Variant in data["stations"]:
		if not _point_valid(point, true):
			_fail("Invalid station position.")
			return {}
		var position := Vector2(point[0], point[1])
		if positions.has(position):
			_fail("Stations must have distinct positions.")
			return {}
		positions[position] = true
		graph.add_station(position)
	if data.has("station_names"):
		if not data["station_names"] is Array or data["station_names"].size() != graph.stations.size():
			_fail("Invalid station names.")
			return {}
		for index in range(graph.stations.size()):
			if not _display_name_valid(data["station_names"][index]):
				_fail("Invalid station name.")
				return {}
			graph.stations[index].display_name = data["station_names"][index]
	for saved: Variant in data["tracks"]:
		if not saved is Dictionary or not _index_valid(saved.get("a"), graph.stations.size()) or not _index_valid(saved.get("b"), graph.stations.size()) or saved["a"] == saved["b"] or not saved.get("waypoints") is Array:
			_fail("Invalid track references.")
			return {}
		var a := int(saved["a"])
		var b := int(saved["b"])
		if graph.track_between(a, b) != null:
			_fail("Duplicate physical track.")
			return {}
		var points := PackedVector2Array()
		if saved["waypoints"].size() > MAX_TRACK_POINTS:
			_fail("Track exceeds waypoint safety limit.")
			return {}
		total_points += maxi(2, saved["waypoints"].size())
		if total_points > MAX_TOTAL_POINTS:
			_fail("Layout exceeds total waypoint safety limit.")
			return {}
		for point: Variant in saved["waypoints"]:
			if not _point_valid(point, true):
				_fail("Invalid track waypoint.")
				return {}
			points.append(Vector2(point[0], point[1]))
		if not points.is_empty():
			if points.size() < 2 or points[0] != graph.stations[a].position or points[-1] != graph.stations[b].position:
				_fail("Track endpoints do not match their stations.")
				return {}
			for index in range(1, points.size()):
				var segment := points[index] - points[index - 1]
				if segment.is_zero_approx() or (not is_zero_approx(segment.x) and not is_zero_approx(segment.y) and not is_equal_approx(absf(segment.x), absf(segment.y))):
					_fail("Invalid track segment.")
					return {}
		graph.add_track(a, b).waypoints = points
		var anchors := TrackGeometry.anchors(graph, graph.tracks.back())
		for index in range(1, anchors.size()):
			var segment := anchors[index] - anchors[index - 1]
			if not is_zero_approx(segment.x) and not is_zero_approx(segment.y) and not is_equal_approx(absf(segment.x), absf(segment.y)):
				_fail("Invalid track segment.")
				return {}
		if not graph.path_error(a, b, anchors).is_empty():
			_fail("Track backtracks or intersects itself.")
			return {}
		total_length += TrackGeometry.length(anchors)
		if total_length > MAX_TOTAL_LENGTH:
			_fail("Layout exceeds geometry length safety limit.")
			return {}
	for saved: Variant in data["lines"]:
		if not saved is Dictionary or not saved.get("color") is String or not _color_valid(saved["color"]) or not saved.get("stations") is Array:
			_fail("Invalid line data.")
			return {}
		var line := TransitLine.new(lines.size(), Color.html(saved["color"]))
		total_calls += saved["stations"].size()
		if saved["stations"].size() > MAX_STATIONS + 1 or total_calls > MAX_TOTAL_CALLS:
			_fail("Layout exceeds station-call safety limit.")
			return {}
		if saved.has("name"):
			if not _display_name_valid(saved["name"]):
				_fail("Invalid line name.")
				return {}
			line.display_name = saved["name"]
		if not _index_valid(saved.get("render_priority", 0), MAX_LINES):
			_fail("Invalid line data.")
			return {}
		line.render_priority = int(saved.get("render_priority", 0))
		for field: String in LINE_FIELDS:
			if not _line_value_valid(field, saved.get(field)):
				_fail("Invalid line setting: " + field)
				return {}
			line.set(field, int(saved[field]) if field in ["wagon_count", "max_trains"] else float(saved[field]))
		for station_id: Variant in saved["stations"]:
			if not _index_valid(station_id, graph.stations.size()):
				_fail("Invalid line station reference.")
				return {}
			var id := int(station_id)
			if line.stations.has(id) and not (line.stations.size() == saved["stations"].size() - 1 and line.stations.size() >= 3 and id == line.stations[0]):
				_fail("Repeated station in line.")
				return {}
			if not line.stations.is_empty():
				var track := graph.track_between(line.stations.back(), id)
				if track == null:
					_fail("Missing physical track for line.")
					return {}
				line.tracks.append(track.id)
			line.stations.append(id)
		total_trains += line.max_trains
		if total_trains > MAX_TOTAL_TRAINS:
			_fail("Layout exceeds total train safety limit.")
			return {}
		var line_points := 0
		for track_id: int in line.tracks:
			var anchors := TrackGeometry.anchors(graph, graph.tracks[track_id])
			line_points += anchors.size()
			service_points += anchors.size()
			if line_points > MAX_LINE_POINTS or service_points > MAX_SERVICE_POINTS:
				_fail("Line exceeds geometry complexity safety limit.")
				return {}
			if TrackGeometry.length(TrackGeometry.round_corners(anchors)) < TrackGeometry.train_length(line.wagon_count) + 40.0:
				_fail("Line segment is too short for its train.")
				return {}
		lines.append(line)
	var service_length := 0.0
	for line: TransitLine in lines:
		for track_id: int in line.tracks:
			var track := graph.tracks[track_id]
			service_length += TrackGeometry.length(TrackGeometry.anchors(graph, track))
			var minimum_clearance := 2.0 * maxf(TrackGeometry.station_stop_clearance(track.a, lines), TrackGeometry.station_stop_clearance(track.b, lines))
			if TrackGeometry.length(TrackGeometry.sample(graph, track)) < minimum_clearance:
				_fail("Line segment cannot clear its station markers.")
				return {}
		if service_length > MAX_TOTAL_LENGTH:
			_fail("Layout exceeds total service length safety limit.")
			return {}
	if not _index_valid(data.get("active_line"), lines.size()) or not _point_valid(data.get("camera"), false) or not _number_in_range(data.get("zoom"), 0.08, 6.0):
		_fail("Invalid saved view.")
		return {}
	return {"graph": graph, "lines": lines, "active_line": int(data["active_line"]),
		"camera": Vector2(data["camera"][0], data["camera"][1]), "zoom": float(data["zoom"])}

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Cannot read layout: " + error_string(FileAccess.get_open_error()))
		return {}
	if file.get_length() > MAX_FILE_BYTES:
		_fail("Layout exceeds the 16 MiB storage limit.")
		return {}
	var buffer := file.get_buffer(file.get_length())
	var error := file.get_error()
	if error != OK:
		_fail("Cannot read layout contents: " + error_string(error))
		return {}
	return _parse_buffer(buffer)

func _parse_buffer(buffer: PackedByteArray) -> Dictionary:
	error_message = ""
	if buffer.size() > MAX_FILE_BYTES:
		_fail("Layout exceeds the 16 MiB storage limit.")
		return {}
	if not _json_complexity_valid(buffer):
		_fail("Layout JSON exceeds nesting, string or token safety limits.")
		return {}
	var text := buffer.get_string_from_utf8()
	if text.to_utf8_buffer() != buffer:
		_fail("Layout must be valid UTF-8 JSON.")
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary or json.data.is_empty():
		_fail("Invalid layout JSON.")
		return {}
	return json.data

func _json_complexity_valid(buffer: PackedByteArray) -> bool:
	var depth := 0
	var tokens := 0
	var in_string := false
	var escaped := false
	var string_length := 0
	var scalar_length := 0
	for byte: int in buffer:
		if in_string:
			if byte == 34 and not escaped:
				in_string = false
				continue
			string_length += 1
			if string_length > 4096:
				return false
			if escaped:
				escaped = false
			elif byte == 92:
				escaped = true
		elif byte == 34:
			in_string = true
			string_length = 0
			tokens += 1
		elif byte == 123 or byte == 91:
			depth += 1
			tokens += 1
			if depth > MAX_JSON_DEPTH:
				return false
		elif byte == 125 or byte == 93:
			depth -= 1
		elif byte == 44 or byte == 58:
			tokens += 1
		if not in_string:
			if (byte >= 48 and byte <= 57) or byte in [43, 45, 46, 69, 101]:
				scalar_length += 1
				if scalar_length > 128:
					return false
			else:
				scalar_length = 0
		if tokens > MAX_JSON_TOKENS:
			return false
	return true

func _path(layout_name: String) -> String:
	return directory.path_join(layout_name.sha256_text() + ".json")

func _display_name_valid(value: Variant) -> bool:
	if not value is String or value.length() > 160:
		return false
	for index in range(value.length()):
		if value.unicode_at(index) < 32 or value.unicode_at(index) == 127:
			return false
	return true

func _fail(message: String) -> bool:
	error_message = message
	push_error(message)
	return false

func _number_in_range(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func _index_valid(value: Variant, size: int) -> bool:
	return _number_in_range(value, 0, size - 1) and float(value) == floorf(float(value))

func _point_valid(value: Variant, on_grid: bool) -> bool:
	if not value is Array or value.size() != 2 or not _number_in_range(value[0], -MAX_COORDINATE, MAX_COORDINATE) or not _number_in_range(value[1], -MAX_COORDINATE, MAX_COORDINATE):
		return false
	var point := Vector2(value[0], value[1]) / 48.0
	return point.is_finite() and (not on_grid or (float(value[0]) / 48.0 == roundf(float(value[0]) / 48.0) and float(value[1]) / 48.0 == roundf(float(value[1]) / 48.0)))

func _color_valid(value: String) -> bool:
	if value.length() != 6:
		return false
	for character: String in value.to_lower():
		if not character in "0123456789abcdef":
			return false
	return true

func _line_value_valid(field: String, value: Variant) -> bool:
	match field:
		"dispatch_rate": return _number_in_range(value, 8, 60)
		"dwell_time": return _number_in_range(value, 0, 12)
		"cruise_velocity": return _number_in_range(value, 40, 220)
		"acceleration", "braking": return _number_in_range(value, 1, 10000)
		"terminal_recovery": return _number_in_range(value, 0, 300)
		"wagon_count": return _index_valid(value, 7) and value >= 1
		"max_trains": return _index_valid(value, 17) and value >= 1
	return false
