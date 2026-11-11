extends SceneTree

const StoreScript := preload("res://scripts/layout_store.gd")
var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true

func _run() -> void:
	var selectors := OS.get_cmdline_user_args()
	for selector in selectors:
		if selector not in ["jr-east", "montreal", "render-only", "--fast"]:
			push_error("Unknown preset selector: " + selector)
			quit(1)
			return
	if selectors.has("render-only") and selectors.has("--fast"):
		push_error("Preset render-only and --fast modes are mutually exclusive.")
		quit(1)
		return
	var all_presets := not selectors.has("jr-east") and not selectors.has("montreal")
	if all_presets or selectors.has("jr-east"):
		await _test_preset("res://layouts/jr_east.json", true)
	if all_presets or selectors.has("montreal"):
		await _test_preset("res://layouts/montreal.json", false)
	if _failed:
		quit(1)
	else:
		print("Preset smoke passed: factual coverage, named topology, requested fleets, service, save round-trip and actual menu loading. Timings are observations, not cross-machine performance guarantees.")
		quit()

func _test_preset(path: String, jr_east: bool) -> void:
	var store := StoreScript.new()
	var start := Time.get_ticks_usec()
	var restored := store.load_bundled_layout(path)
	_check(not restored.is_empty(), "Bundled preset must load: " + path)
	if restored.is_empty():
		return
	var parse_ms := (Time.get_ticks_usec() - start) / 1000.0
	print("%s: parsed in %.1f ms." % [path, parse_ms])
	var graph: TransitGraph = restored["graph"]
	var lines: Array[TransitLine] = restored["lines"]
	var names: Dictionary = {}
	var positions: Dictionary = {}
	for station: Station in graph.stations:
		_check(not station.display_name.is_empty(), "Every factual station/continuation must be named.")
		_check(not names.has(station.display_name), "Interchanges must share station IDs rather than duplicate names: " + station.display_name)
		_check(not positions.has(station.position), "Distinct stations must have distinct positions: " + station.display_name)
		names[station.display_name] = station.id
		positions[station.position] = true
	for line: TransitLine in lines:
		var expected_fleet: int = ([10, 8, 4, 6, 4, 4, 4, 8, 6, 6, 4] if jr_east else [10, 12, 2, 6])[line.id]
		var expected_wagons := 2 if line.display_name.begins_with("4 ") else 3
		_check(not line.display_name.is_empty() and line.max_trains == expected_fleet and line.wagon_count == expected_wagons and line.stations.size() >= 2, "Every preset path must retain its requested fleet and wagon count.")
		for track_id: int in line.tracks:
			var track := graph.tracks[track_id]
			var length := TrackGeometry.length(TrackGeometry.sample(graph, track))
			_check(length >= TrackGeometry.train_length(line.wagon_count) + 40, "Every preset segment must fit its train: " + line.display_name)
	var json := JSON.new()
	_check(json.parse(FileAccess.get_file_as_string(path)) == OK, "Preset JSON must parse.")
	var metro_stations: Dictionary = {}
	var metro_counts: Array[int] = []
	for saved: Dictionary in json.data["lines"]:
		if not jr_east and saved.get("category") == "metro":
			metro_counts.append(saved["stations"].size())
			for station_id: int in saved["stations"]:
				metro_stations[station_id] = true
	if jr_east:
		_check(lines[0].render_priority == 1, "Yamanote must have the highest render priority.")
		for line: TransitLine in lines.slice(1):
			_check(line.render_priority == 0, "Other Tokyo lines must retain their relative draw order.")
		_test_tokyo(graph, lines, names)
		_check(json.data.get("scope") == "central-tokyo-jr", "Tokyo must replace the sprawling regional preset.")
	else:
		_check(not TrackGeometry.corridor_layout(graph, lines)["aligned"], "Montreal must retain its existing non-overlapping route geometry.")
		_check(metro_counts == [27, 31, 3, 12] and metro_stations.size() == 68, "Montréal must include every station on the four métro lines exactly once per service.")
		_check(graph.stations.size() == 68 and lines.size() == 4 and graph.tracks.size() == 69, "Montréal must contain only the 68 métro stations, four lines and 69 physical tracks.")
		_check(json.data.get("scope") == "montreal-metro-only" and not json.data.has("pedestrian_transfers"), "Montréal must exclude regional connections and projected extensions.")
		_check(names.has("Georges-Vanier") and names.has("Sauvé") and names.has("Bonaventure"), "Existing métro stations must be preserved.")
		for station_id: int in range(graph.stations.size()):
			_check(metro_stations.has(station_id), "Every Montréal node must be served by a métro line.")
		for interchange: String in ["Berri-UQAM", "Lionel-Groulx", "Snowdon", "Jean-Talon"]:
			var serving := 0
			for line: TransitLine in lines:
				if line.stations.has(names[interchange]):
					serving += 1
			_check(serving == (3 if interchange == "Berri-UQAM" else 2), "Métro interchange membership must remain unchanged: " + interchange)
		_test_montreal_shape(graph, names)
	var snapshot := store.capture(graph, lines, restored["active_line"], restored["camera"], restored["zoom"])
	var round_trip := store.restore(snapshot)
	_check(not round_trip.is_empty(), "Named preset must round-trip through the user-save schema.")
	if not round_trip.is_empty():
		_check(store.capture(round_trip["graph"], round_trip["lines"], round_trip["active_line"], round_trip["camera"], round_trip["zoom"]) == snapshot, "Names and every playable setting must survive saving a preset copy.")
	start = Time.get_ticks_usec()
	var dispatcher := TransitDispatcher.new(graph)
	dispatcher.lines.assign(lines)
	dispatcher.rebuild_routes()
	_test_station_connections(graph, lines, dispatcher.routes)
	if jr_east:
		_test_jr_corridor_separation(graph, lines, dispatcher.routes, names)
		_test_jr_lane_clearance(graph, lines, dispatcher.routes)
	var build_ms := (Time.get_ticks_usec() - start) / 1000.0
	print("%s: routes built in %.1f ms." % [path, build_ms])
	for line: TransitLine in lines:
		_check(dispatcher.route_capacity(line) >= 1, "Each preset route must have room for service: " + line.display_name)
		_check(dispatcher.service_fleet(line) == line.max_trains, "Requested preset fleets must be sustainable, not just slider limits: " + line.display_name)
		if not jr_east:
			print("%s: capacity %d, service fleet %d, headway %.1fs." % [line.display_name, dispatcher.route_capacity(line), dispatcher.service_fleet(line), dispatcher.departure_headway(line)])
	start = Time.get_ticks_usec()
	var render_only := OS.get_cmdline_user_args().has("render-only")
	var fast := OS.get_cmdline_user_args().has("--fast")
	var simulation_seconds := 30.0 if jr_east or fast else 600.0
	var observed_arrivals := {}
	var shared_arrivals := 0
	for frame in range(1 if render_only else int(simulation_seconds * 60)):
		dispatcher.process(1.0 / 60.0, false)
		for train: Metro in dispatcher.metros:
			if train.arrival_count <= int(observed_arrivals.get(train.id, 0)):
				continue
			observed_arrivals[train.id] = train.arrival_count
			var line := lines[train.line_id]
			var circuit := TrackGeometry.route_for_direction(dispatcher.routes[line.id], train.travel_direction)
			var stops: PackedFloat32Array = circuit["stops"]
			var stop_index := (train.next_stop_index - 1 + stops.size()) % stops.size()
			var station_index := _station_index_for_stop(line, train.travel_direction, stop_index, stops.size())
			var station := graph.stations[line.stations[station_index]]
			var clearance := TrackGeometry.station_stop_clearance(station.id, lines)
			_check(absf(train.position.distance_to(station.position) - clearance) < 0.05, "An actual arrival must stop beside the station served by its line: %s / %s" % [line.display_name, station.display_name])
			var serving := 0
			for other: TransitLine in lines:
				if other.stations.has(station.id):
					serving += 1
			if serving > 1:
				shared_arrivals += 1
	var simulation_ms := (Time.get_ticks_usec() - start) / 1000.0
	var trains_per_line: Dictionary = {}
	for train: Metro in dispatcher.metros:
		trains_per_line[train.line_id] = int(trains_per_line.get(train.line_id, 0)) + 1
		_check(train.position.is_finite() and is_finite(train.distance), "Stress-test train poses must remain finite.")
	for line: TransitLine in lines:
		var count := int(trains_per_line.get(line.id, 0))
		_check(count > 0 and count <= line.max_trains, "Every preset path must dispatch within its fleet limit: " + line.display_name)
		if jr_east and line.id >= 7 and not render_only:
			_check(count >= 2, "Several trains must actually enter service on each southern JR route.")
		if not jr_east and not render_only and not fast:
			_check(count == line.max_trains, "Montréal must actually dispatch its full fleet on every line: " + line.display_name)
	if not render_only:
		_check(dispatcher.arrival_count > 0, "Preset simulation must continue making station calls.")
		_check(shared_arrivals > 0, "Preset simulation must exercise an actual arrival at a shared station.")
	print("%s: simulation completed in %.1f ms; loading menu/render caches." % [path, simulation_ms])
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("startup_layout_enabled", false)
	root.add_child(main)
	main.set_process(false)
	root.content_scale_factor = 1.0
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(1180, 740)
	await process_frame
	await process_frame
	main.call("_open_layouts", false)
	var selector: OptionButton = main.get("_saved_layouts")
	for index in range(selector.item_count):
		var metadata: Variant = selector.get_item_metadata(index)
		if metadata is String and metadata == path:
			selector.select(index)
	start = Time.get_ticks_usec()
	main.call("_request_layout_action")
	_check(main.get("_layout_dialog").visible, "Loading a large bundled preset must require confirmation.")
	main.get("_layout_dialog").hide()
	main.get("_layout_dialog").confirmed.emit()
	var menu_load_ms := (Time.get_ticks_usec() - start) / 1000.0
	_check(main.get("graph").stations.size() == graph.stations.size() and main.get("lines").size() == lines.size(), "Real menu loading must install the complete network.")
	if jr_east:
		var tracks: StaticTrackLayer = main.get("world_view").get("_static_tracks")
		for line: TransitLine in lines.slice(1):
			_check(tracks.line_layer(0).get_index() > tracks.line_layer(line.id).get_index(), "Yamanote rails and trains must render above every other Tokyo line after a menu load.")
		var camera: Camera2D = main.get("camera")
		var viewport_size: Vector2 = main.get_viewport_rect().size
		var usable := Rect2(Vector2(32, 80), viewport_size - Vector2(64, 160))
		for station: Station in graph.stations:
			var screen_position := viewport_size * 0.5 + (station.position - camera.position) * camera.zoom
			_check(usable.has_point(screen_position), "The compact Tokyo preset must fit inside HUD margins: " + station.display_name)
	_check(main.get("_line_label").text == lines[restored["active_line"]].display_name, "Line settings must display the factual service name.")
	var tab: Button = main.get("_line_selector").get_child(restored["active_line"])
	_check(tab.tooltip_text == lines[restored["active_line"]].display_name, "Compact tabs must expose service names in their tooltips.")
	main.get("dispatcher").process(2.0, false)
	_check(not main.get("dispatcher").metros.is_empty(), "Menu-loaded presets must start service before day/night checks.")
	main.set("paused", true)
	for phase: float in [0.5, 0.0]:
		main.set("time_of_day", phase)
		main.call("_process", 0.0)
		for frame in range(3):
			await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
	main.call("_select_line", lines.size() - 1)
	_check(main.get("active_line").max_trains == lines.back().max_trains, "Preset service selections must retain their fleet ceiling.")
	main.call("_request_clear_map")
	main.get("_layout_dialog").hide()
	main.get("_layout_dialog").confirmed.emit()
	_check(main.get("graph").stations.is_empty() and main.get("dispatcher").metros.is_empty(), "Clear must fully release large-network state.")
	main.queue_free()
	await process_frame
	if fast and not jr_east:
		print("Fast Montréal checks: full-fleet 600s soak not run.")
	print("%s: %d stations, %d physical tracks, %d playable paths, %d trains; parse %.1f ms, route build %.1f ms, %s simulation %.1f ms, menu load/render caches %.1f ms." % [path, graph.stations.size(), graph.tracks.size(), lines.size(), dispatcher.metros.size(), parse_ms, build_ms, "one-tick" if render_only else "%ds" % simulation_seconds, simulation_ms, menu_load_ms])

func _test_montreal_shape(graph: TransitGraph, names: Dictionary) -> void:
	for reference: Array in [["Berri-UQAM", Vector2(384, 0)], ["Jean-Talon", Vector2(-192, -576)], ["Snowdon", Vector2(-576, 384)], ["Lionel-Groulx", Vector2(-96, 768)]]:
		_check(graph.stations[names[reference[0]]].position == reference[1], "Montréal must preserve its accepted shape at the tighter 48-unit spacing: " + reference[0])
	var minimum_fit := TrackGeometry.train_length(2) + 40.0
	_check(96.0 < minimum_fit and 144.0 >= minimum_fit and Vector2(96, 96).length() >= minimum_fit and Vector2(48, 48).length() < minimum_fit, "The compact straight runs must use the smallest axial/diagonal grid spacing that fits two wagons.")
	_check(Vector2(96, 96).length() >= TrackGeometry.train_length(3) + 40.0 and Vector2(96, 96).length() < TrackGeometry.train_length(4) + 40.0, "The compact diagonal grid must fit three-wagon trains, the longest Montréal consist.")
	_check(graph.stations[names["Monk"]].position.distance_to(graph.stations[names["Angrignon"]].position) == 144.0, "The western horizontal tail must use the minimum valid three-grid spacing.")
	_check(graph.stations[names["Jean-Drapeau"]].position == Vector2(624, 0) and graph.stations[names["Longueuil–Université-de-Sherbrooke"]].position == Vector2(720, -96), "Yellow must retain the shortest tested grid layout supporting two simultaneous trains.")
	var berri: Vector2 = graph.stations[names["Berri-UQAM"]].position
	var jean_talon: Vector2 = graph.stations[names["Jean-Talon"]].position
	var snowdon: Vector2 = graph.stations[names["Snowdon"]].position
	var groulx: Vector2 = graph.stations[names["Lionel-Groulx"]].position
	var delta := berri - jean_talon
	_check(delta.x > 0 and delta.y > 0 and is_equal_approx(delta.x, delta.y), "Orange's north arm must descend diagonally from Jean-Talon to Berri-UQAM.")
	_check(snowdon.x < groulx.x and snowdon.y < groulx.y and groulx.x < berri.x and groulx.y > berri.y, "Orange's southwest arm and downtown return must form a recognizable U.")
	var western_tip: Vector2 = graph.stations[names["Côte-Vertu"]].position
	delta = snowdon - western_tip
	_check(delta.x > 0 and is_equal_approx(delta.x, delta.y), "Côte-Vertu must align diagonally with Snowdon, not form a vertical column.")
	var angrignon: Vector2 = graph.stations[names["Angrignon"]].position
	var church: Vector2 = graph.stations[names["De l'Église"]].position
	_check(angrignon.x < church.x and angrignon.y == church.y and church.y > groulx.y, "Green's western tail must be horizontal below Lionel-Groulx.")
	var drapeau: Vector2 = graph.stations[names["Jean-Drapeau"]].position
	var longueuil: Vector2 = graph.stations[names["Longueuil–Université-de-Sherbrooke"]].position
	_check(drapeau.x > berri.x and drapeau.y == berri.y and longueuil.x > drapeau.x and longueuil.y < drapeau.y, "Yellow must run east from Berri-UQAM, then turn northeast.")
	var edouard: Vector2 = graph.stations[names["Édouard-Montpetit"]].position
	var outremont: Vector2 = graph.stations[names["Outremont"]].position
	var dogleg := graph.track_between(names["Édouard-Montpetit"], names["Outremont"])
	var rightmost := maxf(edouard.x, outremont.x)
	for point: Vector2 in dogleg.waypoints:
		rightmost = maxf(rightmost, point.x)
	_check(rightmost > maxf(edouard.x, outremont.x) and outremont.y < edouard.y, "Blue's central dogleg must bend east before returning northwest.")

func _station_index_for_stop(line: TransitLine, direction: int, stop_index: int, stop_count: int) -> int:
	if line.is_loop():
		return line.stations.size() - 2 - stop_index if direction < 0 else stop_index
	return stop_index + 1 if stop_index < line.stations.size() - 1 else stop_count - 1 - stop_index

func _test_station_connections(graph: TransitGraph, lines: Array[TransitLine], routes: Dictionary) -> void:
	var missing_centers := PackedStringArray()
	var missing_lanes := PackedStringArray()
	var misplaced_stops := PackedStringArray()
	for line: TransitLine in lines:
		var route: Dictionary = routes[line.id]
		var centerline: PackedVector2Array = route["centerline"]
		var lanes: Array = route["running_paths"]
		var station_count := line.stations.size() - (1 if line.is_loop() else 0)
		for station_index in range(station_count):
			var station := graph.stations[line.stations[station_index]]
			var serving := 0
			for other: TransitLine in lines:
				if other.stations.has(station.id):
					serving += 1
			var distance := TrackGeometry.closest_point(centerline, station.position).distance_to(station.position)
			if distance > 6.0:
				missing_centers.append("%s / %s: %.1f" % [line.display_name, station.display_name, distance])
			for lane: PackedVector2Array in lanes:
				distance = TrackGeometry.closest_point(lane, station.position).distance_to(station.position)
				if distance > TrackGeometry.station_radius(serving) + 0.75:
					missing_lanes.append("%s / %s: %.1f" % [line.display_name, station.display_name, distance])
		var directions: Array[int] = [1]
		if line.is_loop():
			directions.append(-1)
		for direction: int in directions:
			var circuit := TrackGeometry.route_for_direction(route, direction)
			var points: PackedVector2Array = circuit["points"]
			var stops: PackedFloat32Array = circuit["stops"]
			for stop_index in range(stops.size()):
				var station_index := _station_index_for_stop(line, direction, stop_index, stops.size())
				var station := graph.stations[line.stations[station_index]]
				var stop := TrackGeometry.point_at_distance(points, stops[stop_index])
				var clearance := TrackGeometry.station_stop_clearance(station.id, lines)
				if absf(stop.distance_to(station.position) - clearance) > 0.05:
					misplaced_stops.append("%s / %s: %.1f (expected %.1f)" % [line.display_name, station.display_name, stop.distance_to(station.position), clearance])
				_check(stop_index == 0 or stops[stop_index] > stops[stop_index - 1], "Preset stops must stay in service order: " + line.display_name)
	_check(missing_centers.is_empty(), "Every served station must lie on its service centerline: %d missing, examples %s" % [missing_centers.size(), str(missing_centers.slice(0, 8))])
	_check(missing_lanes.is_empty(), "Both running lanes must reach every served station marker: %d missing, examples %s" % [missing_lanes.size(), str(missing_lanes.slice(0, 8))])
	_check(misplaced_stops.is_empty(), "Trains must stop at their actual station markers in both directions: %d misplaced, examples %s" % [misplaced_stops.size(), str(misplaced_stops.slice(0, 8))])

func _station_nearby_segments(points: PackedVector2Array, center: Vector2, radius: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for index in range(1, points.size()):
		var start := points[index - 1]
		var delta := points[index] - start
		var length_squared := delta.length_squared()
		if length_squared < 0.000001:
			continue
		var relative := start - center
		var b := 2.0 * relative.dot(delta)
		var c := relative.length_squared() - radius * radius
		var discriminant := b * b - 4.0 * length_squared * c
		if discriminant < 0.0:
			continue
		var root := sqrt(discriminant)
		var first := maxf(0.0, (-b - root) / (2.0 * length_squared))
		var last := minf(1.0, (-b + root) / (2.0 * length_squared))
		if first <= last:
			result.append(PackedVector2Array([start + delta * first, start + delta * last]))
	return result

func _test_jr_lane_clearance(graph: TransitGraph, lines: Array[TransitLine], routes: Dictionary) -> void:
	for line: TransitLine in lines:
		var lanes: Array = routes[line.id]["running_paths"]
		for station_index in range(0 if line.is_loop() else 1, line.stations.size() - 1):
			var station := graph.stations[line.stations[station_index]]
			var first := _station_nearby_segments(lanes[0], station.position, 64.0)
			var second := _station_nearby_segments(lanes[1], station.position, 64.0)
			var separation := INF
			for a: PackedVector2Array in first:
				for b: PackedVector2Array in second:
					if Geometry2D.segment_intersects_segment(a[0], a[1], b[0], b[1]) is Vector2:
						separation = 0.0
						break
					for point: Vector2 in a:
						separation = minf(separation, point.distance_to(Geometry2D.get_closest_point_to_segment(point, b[0], b[1])))
					for point: Vector2 in b:
						separation = minf(separation, point.distance_to(Geometry2D.get_closest_point_to_segment(point, a[0], a[1])))
				if separation == 0.0:
					break
			_check(separation >= TrackGeometry.CAR_WIDTH + 1.0, "Opposing Tokyo lanes must not fold together near intermediate stations: %s / %s (%.2f)" % [line.display_name, station.display_name, separation])

func _test_jr_corridor_separation(graph: TransitGraph, lines: Array[TransitLine], routes: Dictionary, names: Dictionary) -> void:
	var corridors := TrackGeometry.corridor_layout(graph, lines)
	for pair: Array in [["Tokyo", "Kanda"], ["Kanda", "Akihabara"], ["Shimbashi", "Hamamatsucho"], ["Shibuya", "Ebisu"], ["Totsuka", "Ofuna"], ["Fujisawa", "Tsujido"], ["Hiratsuka", "Oiso"]]:
		var track := graph.track_between(names[pair[0]], names[pair[1]])
		var from_position: Vector2 = graph.stations[track.a].position
		var to_position: Vector2 = graph.stations[track.b].position
		var midpoint := from_position.lerp(to_position, 0.5)
		var axis := (to_position - from_position).normalized()
		var centers: Array[Vector2] = []
		for line: TransitLine in lines:
			if line.tracks.has(track.id):
				var center := _route_cross_section(routes[line.id]["centerline"], midpoint, axis, midpoint)
				_check(center.is_finite(), "JR separation probes must intersect every shared route.")
				if center.is_finite():
					centers.append(center)
		_check(centers.size() >= 2, "JR separation probes must cover shared corridors.")
		for first in range(centers.size()):
			for second in range(first + 1, centers.size()):
				_check(centers[first].distance_to(centers[second]) >= 40.0, "Shared JR services must have distinct side-by-side corridors with a visible gap: " + pair[0] + " - " + pair[1])
	var spacing: float = graph.stations[names["Tokyo"]].position.x / 12.0
	var probes: Array = [
		[[0, 4, 8, 9], Vector2(-16, -12), Vector2(-16, 11), "Yamanote west"],
		[[0, 4, 8, 9], Vector2(-13, -16), Vector2(-15, -14), "Yamanote northwest bevel"],
		[[0, 1, 5], Vector2(9, -16), Vector2(11, -14), "Yamanote northeast bevel"],
		[[0, 1], Vector2(12, -12), Vector2(12, 11), "Yamanote east"],
		[[0, 1, 7], Vector2(12, 1), Vector2(12, 11), "Tokyo–Shimbashi"],
		[[0], Vector2(-15, 13), Vector2(-11, 17), "Yamanote southwest bevel"],
		[[0, 1, 7], Vector2(11, 13), Vector2(7, 17), "Yamanote southeast bevel"],
		[[0, 1, 7], Vector2(-9, 18), Vector2(5, 18), "Yamanote southern shelf"],
		[[2, 3], Vector2(-34, -6), Vector2(-18, -6), "Nakano–Shinjuku"],
		[[2, 3], Vector2(-11, -3), Vector2(-9, -3), "Chuo central lower shelf"],
		[[2, 3], Vector2(-7, -4), Vector2(0, -11), "Chuo central diagonal"],
		[[2, 3], Vector2(3, -12), Vector2(8, -12), "Chuo central upper shelf"],
		[[4, 8, 9], Vector2(-7, -28), Vector2(-11, -24), "Akabane approach"],
		[[8, 9], Vector2(-18, 12), Vector2(-28, 12), "Osaki–Musashi-Kosugi"],
		[[8, 9], Vector2(-31, 13), Vector2(-35, 17), "Musashi-Kosugi–Yokohama"],
		[[7, 8, 9], Vector2(-38, 18), Vector2(-50, 18), "Yokohama–Ofuna"],
		[[7, 8], Vector2(-56, 11), Vector2(-56, 13), "Shonan coast"]
	]
	for probe: Array in probes:
		var ids: Array[int] = []
		ids.assign(probe[0])
		_check_parallel_routes(graph, lines, routes, corridors, ids, probe[1] * spacing, probe[2] * spacing, probe[3])
	# Services with the local stops keep the station axis, so neither Tokaido nor Zushi bumps.
	for spine: Array in [[7, Vector2(-11, 18), Vector2(-35, 18), "Tokaido through Kawasaki"], [9, Vector2(-37, 18), Vector2(-51, 18), "Yokosuka local through Hodogaya"]]:
		var slot: Variant = _spine_slot(corridors, lines[spine[0]], spine[1] * spacing, spine[2] * spacing)
		_check(slot != null and is_zero_approx(slot), spine[3] + " must stay centered on the station axis.")
		var route_points: PackedVector2Array = routes[spine[0]]["centerline"]
		for step in range(1, 20):
			var probe: Vector2 = (spine[1] as Vector2).lerp(spine[2], float(step) / 20.0) * spacing
			var point := _route_cross_section(route_points, probe, Vector2.RIGHT, probe)
			_check(point.is_finite() and absf(point.y - probe.y) < 0.05, spine[3] + " must run straight without station detours.")
	for station_name: String in ["Oimachi", "Omori", "Kamata"]:
		_check(is_equal_approx(graph.stations[names[station_name]].position.y - graph.stations[names["Shinagawa"]].position.y, TrackGeometry.CORRIDOR_SPACING), "Keihin-Tohoku's southern stops must sit one slot off the Tokaido axis: " + station_name)

func _route_cross_section(points: PackedVector2Array, position: Vector2, axis: Vector2, target: Vector2) -> Vector2:
	var best := Vector2(INF, INF)
	for index in range(1, points.size()):
		var first := points[index - 1]
		var last := points[index]
		var before := (first - position).dot(axis)
		var after := (last - position).dot(axis)
		if before * after > 0.0 or absf(after - before) < 0.00001:
			continue
		var candidate := first.lerp(last, -before / (after - before))
		if candidate.distance_squared_to(target) < best.distance_squared_to(target):
			best = candidate
	return best

func _spine_slot(corridors: Dictionary, line: TransitLine, start: Vector2, finish: Vector2) -> Variant:
	var axis := (finish - start).normalized()
	var normal := Vector2(-axis.y, axis.x)
	var span := start.distance_to(finish)
	for track_id: int in line.tracks:
		for segment: Dictionary in corridors["tracks"][track_id]:
			var first: Vector2 = segment["a"]
			var last: Vector2 = segment["b"]
			if absf((first - start).dot(normal)) > 0.01 or absf((last - start).dot(normal)) > 0.01:
				continue
			var low := minf((first - start).dot(axis), (last - start).dot(axis))
			var high := maxf((first - start).dot(axis), (last - start).dot(axis))
			if minf(high, span) <= maxf(low, 0.0) + 0.01:
				continue
			var bundle: Dictionary = segment["bundle"]
			var shift: Vector2 = bundle["normal"] * float(bundle["slots"][line.id]) * TrackGeometry.CORRIDOR_SPACING
			return shift.dot(normal)
	return null

func _check_parallel_routes(graph: TransitGraph, lines: Array[TransitLine], routes: Dictionary, corridors: Dictionary, line_ids: Array[int], start: Vector2, finish: Vector2, label: String) -> void:
	var axis := (finish - start).normalized()
	var normal := Vector2(-axis.y, axis.x)
	var expected := {}
	var checked := {}
	var errors := PackedStringArray()
	for line_id: int in line_ids:
		expected[line_id] = _spine_slot(corridors, lines[line_id], start, finish)
		checked[line_id] = 0
		_check(expected[line_id] != null, "%s must have a geometric spine for line %d." % [label, line_id])
	for step in range(101):
		var probe := start.lerp(finish, float(step) / 100.0)
		var offsets: Array[float] = []
		for line_id: int in line_ids:
			if expected[line_id] == null:
				continue
			var slot: float = expected[line_id]
			var transition := 24.0 if is_zero_approx(slot) else maxf(TrackGeometry.STATION_TRANSITION_MIN, absf(slot)) + 24.0
			var near_station := false
			for station_id: int in lines[line_id].stations:
				var delta: Vector2 = graph.stations[station_id].position - probe
				if absf(delta.dot(normal)) < 0.01 and absf(delta.dot(axis)) <= transition:
					near_station = true
					break
			if near_station:
				continue
			var point := _route_cross_section(routes[line_id]["centerline"], probe, axis, probe + normal * slot)
			if not point.is_finite() or absf((point - probe).dot(normal) - slot) > 0.05:
				errors.append("line %d at step %d" % [line_id, step])
				continue
			checked[line_id] += 1
			offsets.append((point - probe).dot(normal))
		for first in range(offsets.size()):
			for second in range(first + 1, offsets.size()):
				if absf(offsets[first] - offsets[second]) < TrackGeometry.CORRIDOR_SPACING - 0.05:
					errors.append("overlapping slots at step %d" % step)
	for line_id: int in line_ids:
		_check(checked[line_id] > 0, "%s must include a tested straight section for line %d away from its station approaches." % [label, line_id])
	_check(errors.is_empty(), "%s must keep its separated straight slots outside station approaches: %d failures, examples %s" % [label, errors.size(), str(errors.slice(0, 8))])

func _test_tokyo(graph: TransitGraph, lines: Array[TransitLine], names: Dictionary) -> void:
	var expected := [
		"Tokyo,Kanda,Akihabara,Okachimachi,Ueno,Uguisudani,Nippori,Nishi-Nippori,Tabata,Komagome,Sugamo,Otsuka,Ikebukuro,Mejiro,Takadanobaba,Shin-Okubo,Shinjuku,Yoyogi,Harajuku,Shibuya,Ebisu,Meguro,Gotanda,Osaki,Shinagawa,Takanawa Gateway,Tamachi,Hamamatsucho,Shimbashi,Yurakucho,Tokyo",
		"Akabane,Higashi-Jujo,Oji,Kami-Nakazato,Tabata,Nishi-Nippori,Nippori,Uguisudani,Ueno,Okachimachi,Akihabara,Kanda,Tokyo,Yurakucho,Shimbashi,Hamamatsucho,Tamachi,Takanawa Gateway,Shinagawa,Oimachi,Omori,Kamata",
		"Nakano,Shinjuku,Yotsuya,Ochanomizu,Kanda,Tokyo",
		"Nakano,Higashi-Nakano,Okubo,Shinjuku,Yoyogi,Sendagaya,Shinanomachi,Yotsuya,Ichigaya,Iidabashi,Suidobashi,Ochanomizu,Akihabara,Asakusabashi,Ryogoku,Kinshicho",
		"Akabane,Jujo,Itabashi,Ikebukuro,Shinjuku,Shibuya,Ebisu,Osaki",
		"Ueno,Nippori,Mikawashima,Minami-Senju,Kita-Senju",
		"Tokyo,Hatchobori,Etchujima,Shiomi,Shin-Kiba",
		"Tokyo,Shimbashi,Shinagawa,Kawasaki,Yokohama,Totsuka,Ofuna,Fujisawa,Tsujido,Chigasaki,Hiratsuka,Oiso,Ninomiya,Kozu,Kamonomiya,Odawara",
		"Akabane,Ikebukuro,Shinjuku,Shibuya,Ebisu,Osaki,Musashi-Kosugi,Yokohama,Totsuka,Ofuna,Fujisawa,Tsujido,Chigasaki,Hiratsuka,Oiso,Ninomiya,Kozu,Kamonomiya,Odawara",
		"Akabane,Ikebukuro,Shinjuku,Shibuya,Ebisu,Osaki,Nishi-Oi,Musashi-Kosugi,Shin-Kawasaki,Yokohama,Hodogaya,Higashi-Totsuka,Totsuka,Ofuna,Kita-Kamakura,Kamakura,Zushi",
		"Hamamatsucho,Tennozu Isle,Oi Keibajo Mae,Ryutsu Center,Showajima,Seibijo,Tenkubashi,Haneda Airport Terminal 3,Shin-Seibijo,Haneda Airport Terminal 1,Haneda Airport Terminal 2"
	]
	_check(graph.stations.size() == 90 and graph.tracks.size() == 107 and lines.size() == expected.size(), "Tokyo, its requested Shonan extensions and the Haneda monorail must contain 90 stations, 107 tracks and eleven services.")
	for station_name: String in ["Hiratsuka", "Fujisawa", "Odawara"]:
		_check(lines[7].stations.has(names[station_name]) and lines[8].stations.has(names[station_name]) and not lines[9].stations.has(names[station_name]), "Tokaido and Odawara-bound Shonan-Shinjuku must share their southern stations: " + station_name)
	for station_name: String in ["Nishi-Oi", "Shin-Kawasaki", "Hodogaya", "Higashi-Totsuka"]:
		_check(lines[9].stations.has(names[station_name]) and not lines[8].stations.has(names[station_name]), "Odawara rapid must bypass Yokosuka-local stops: " + station_name)
	for index in range(mini(lines.size(), expected.size())):
		var actual := PackedStringArray()
		for station_id: int in lines[index].stations:
			actual.append(graph.stations[station_id].display_name)
		_check(actual == expected[index].split(","), "Central JR station order and express/local stops must match: " + lines[index].display_name)
	if lines.is_empty():
		return
	_check(lines[0].is_loop() and lines[0].stations.size() == 31, "Yamanote must close through all 30 stations, including Takanawa Gateway.")
	var tokyo: Vector2 = graph.stations[names["Tokyo"]].position
	var shinjuku: Vector2 = graph.stations[names["Shinjuku"]].position
	var ikebukuro: Vector2 = graph.stations[names["Ikebukuro"]].position
	var shinagawa: Vector2 = graph.stations[names["Shinagawa"]].position
	_check(shinjuku.x < tokyo.x and ikebukuro.y < shinjuku.y and shinagawa.y > tokyo.y, "The recognizable north-up loop must put Shinjuku west, Ikebukuro north and Shinagawa south.")
	var loop := PackedVector2Array()
	for station_id: int in lines[0].stations:
		loop.append(graph.stations[station_id].position)
	loop.resize(loop.size() - 1)
	_check(not Geometry2D.triangulate_polygon(loop).is_empty(), "The Yamanote backbone must be a simple loop, not a tangled region.")
	for station_name: String in ["Yotsuya", "Ichigaya", "Iidabashi", "Suidobashi", "Ochanomizu"]:
		_check(Geometry2D.is_point_in_polygon(graph.stations[names[station_name]].position, loop), "Chuo's central cross-city corridor must sit inside the Yamanote loop: " + station_name)
	_test_tokyo_numbering_shape(graph, names)

func _test_tokyo_numbering_shape(graph: TransitGraph, names: Dictionary) -> void:
	var spacing: float = graph.stations[names["Tokyo"]].position.x / 12.0
	for reference: Array in [["Tokyo", Vector2(12, 0)], ["Shinjuku", Vector2(-16, -6)], ["Ikebukuro", Vector2(-12, -17)], ["Shinagawa", Vector2(-10, 18)], ["Ofuna", Vector2(-52, 18)], ["Odawara", Vector2(-62, 20)]]:
		_check(graph.stations[names[reference[0]]].position == reference[1] * spacing, "Tokyo must retain its accepted station-numbering schematic anchors: " + reference[0])
	var previous_y := -INF
	var west: float = graph.stations[names["Shinjuku"]].position.x
	for station_name: String in ["Takadanobaba", "Shin-Okubo", "Shinjuku", "Yoyogi", "Harajuku", "Shibuya", "Ebisu", "Meguro", "Gotanda", "Osaki"]:
		var position: Vector2 = graph.stations[names[station_name]].position
		_check(position.x == west and position.y > previous_y, "Yamanote's western side must stay straight through Osaki: " + station_name)
		previous_y = position.y
	previous_y = -INF
	var east: float = graph.stations[names["Tokyo"]].position.x
	for station_name: String in ["Ueno", "Okachimachi", "Akihabara", "Kanda", "Tokyo", "Yurakucho", "Shimbashi"]:
		var position: Vector2 = graph.stations[names[station_name]].position
		_check(position.x == east and position.y > previous_y, "Yamanote's eastern side must stay straight through Tokyo: " + station_name)
		previous_y = position.y
	var previous_x := -INF
	var north: float = graph.stations[names["Tabata"]].position.y
	for station_name: String in ["Otsuka", "Sugamo", "Komagome", "Tabata"]:
		var position: Vector2 = graph.stations[names[station_name]].position
		_check(position.y == north and position.x > previous_x, "Yamanote's northern shelf must remain horizontal: " + station_name)
		previous_x = position.x
	previous_x = -INF
	var south: float = graph.stations[names["Shinagawa"]].position.y
	var loop_ratio := (east - west) / (south - north)
	_check(loop_ratio >= 0.65 and loop_ratio <= 0.85, "Yamanote must retain the broad loop proportions of the station-numbering schematic.")
	for station_name: String in ["Shinagawa", "Takanawa Gateway", "Tamachi"]:
		var position: Vector2 = graph.stations[names[station_name]].position
		_check(position.y == south and position.x > previous_x, "Yamanote must have a flat southern base before turning toward Hamamatsucho: " + station_name)
		previous_x = position.x
	var top_left: Vector2 = graph.stations[names["Otsuka"]].position
	var top_right: Vector2 = graph.stations[names["Tabata"]].position
	var bottom_left: Vector2 = graph.stations[names["Shinagawa"]].position
	var bottom_right: Vector2 = graph.stations[names["Tamachi"]].position
	var northwest: Vector2 = graph.stations[names["Mejiro"]].position
	var northeast: Vector2 = graph.stations[names["Ueno"]].position
	var southwest: Vector2 = graph.stations[names["Osaki"]].position
	var southeast: Vector2 = graph.stations[names["Shimbashi"]].position
	var center_x := (west + east) * 0.5
	var width := east - west
	_check(northwest.y == northeast.y and southwest.y == southeast.y, "Yamanote's paired shoulders must line up to form a balanced faceted loop.")
	_check(is_equal_approx((top_left.x + top_right.x) * 0.5, center_x) and is_equal_approx((bottom_left.x + bottom_right.x) * 0.5, center_x), "Yamanote's northern and southern shelves must be centered between its sides.")
	_check((top_right.x - top_left.x) / width >= 0.35 and (top_right.x - top_left.x) / width <= 0.5 and (bottom_right.x - bottom_left.x) / width >= 0.45 and (bottom_right.x - bottom_left.x) / width <= 0.65, "Yamanote must taper visibly at both ends, rather than read as a rectangle.")
	for bevel: Vector2 in [top_left - northwest, northeast - top_right, bottom_left - southwest, southeast - bottom_right]:
		_check(not bevel.is_zero_approx() and is_equal_approx(absf(bevel.x), absf(bevel.y)), "Yamanote's four shoulders must follow clean 45-degree bevels.")
	for corner: Array in [[top_left, northwest, "Ikebukuro"], [top_right, northeast, "Nishi-Nippori"], [top_right, northeast, "Nippori"], [top_right, northeast, "Uguisudani"], [bottom_right, southeast, "Hamamatsucho"]]:
		var point: Vector2 = graph.stations[names[corner[2]]].position
		_check(Geometry2D.get_closest_point_to_segment(point, corner[0], corner[1]).distance_to(point) < 0.01, "Yamanote shoulder stations must follow the same straight facet: " + corner[2])
	previous_x = INF
	for station_name: String in ["Shinagawa", "Kawasaki", "Yokohama", "Totsuka", "Ofuna"]:
		var position: Vector2 = graph.stations[names[station_name]].position
		_check(position.y == south and position.x < previous_x, "Tokaido must run west, not south, toward Ofuna: " + station_name)
		previous_x = position.x
	var ofuna: Vector2 = graph.stations[names["Ofuna"]].position
	var chigasaki: Vector2 = graph.stations[names["Chigasaki"]].position
	var hiratsuka: Vector2 = graph.stations[names["Hiratsuka"]].position
	_check(chigasaki.y < ofuna.y and chigasaki.y == hiratsuka.y and hiratsuka.x < chigasaki.x, "The Shonan coast must fold north through Chigasaki and west to Hiratsuka.")
	var coastal_roof := chigasaki.y
	for point: Vector2 in graph.track_between(names["Chigasaki"], names["Hiratsuka"]).waypoints:
		coastal_roof = minf(coastal_roof, point.y)
	_check(graph.stations[names["Odawara"]].position.y - coastal_roof <= (south - north) * 0.4, "The western coastal fold must stay compact instead of rivaling Yamanote in height.")
	var bounds := Rect2(graph.stations[0].position, Vector2.ZERO)
	for station: Station in graph.stations:
		bounds = bounds.expand(station.position)
	_check(bounds.size.x >= bounds.size.y * 1.7, "The Tokyo preset must preserve the wide, flat station-numbering arrangement.")
	for station_name: String in ["Fujisawa", "Tsujido", "Chigasaki", "Hiratsuka", "Oiso", "Ninomiya", "Kozu", "Kamonomiya", "Odawara"]:
		_check(graph.stations[names[station_name]].position.y <= south + 3.0 * spacing, "The Tokaido extension must not stretch far below Yamanote: " + station_name)
