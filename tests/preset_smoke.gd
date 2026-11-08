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
	if selectors.is_empty() or selectors.has("jr-east"):
		await _test_preset("res://layouts/jr_east.json", true)
	if selectors.is_empty() or selectors.has("montreal"):
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
		var expected_fleet := 2 if jr_east or line.display_name.begins_with("4 ") else 6
		_check(not line.display_name.is_empty() and line.max_trains == expected_fleet and line.wagon_count == 2 and line.stations.size() >= 2, "Every preset path must retain its requested fleet and two-wagon trains.")
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
		_test_tokyo(graph, lines, names)
		_check(json.data.get("scope") == "central-tokyo-jr", "Tokyo must replace the sprawling regional preset.")
	else:
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
	if jr_east:
		_test_jr_corridor_separation(graph, lines, dispatcher.routes, names)
	var build_ms := (Time.get_ticks_usec() - start) / 1000.0
	print("%s: routes built in %.1f ms." % [path, build_ms])
	for line: TransitLine in lines:
		_check(dispatcher.route_capacity(line) >= 1, "Each preset route must have room for service within its two-train ceiling: " + line.display_name)
		if jr_east and line.id >= 7:
			_check(dispatcher.route_capacity(line) >= 2 and dispatcher.service_fleet(line) == 2, "The new Tokaido and Shonan-Shinjuku services must support both trains.")
		if not jr_east:
			print("%s: capacity %d, service fleet %d, headway %.1fs." % [line.display_name, dispatcher.route_capacity(line), dispatcher.service_fleet(line), dispatcher.departure_headway(line)])
	start = Time.get_ticks_usec()
	var render_only := OS.get_cmdline_user_args().has("render-only")
	var simulation_seconds := 30.0 if jr_east else 600.0
	for frame in range(1 if render_only else int(simulation_seconds * 60)):
		dispatcher.process(1.0 / 60.0, false)
	var simulation_ms := (Time.get_ticks_usec() - start) / 1000.0
	var trains_per_line: Dictionary = {}
	for train: Metro in dispatcher.metros:
		trains_per_line[train.line_id] = int(trains_per_line.get(train.line_id, 0)) + 1
		_check(train.position.is_finite() and is_finite(train.distance), "Stress-test train poses must remain finite.")
	for line: TransitLine in lines:
		var count := int(trains_per_line.get(line.id, 0))
		_check(count > 0 and count <= line.max_trains, "Every preset path must dispatch within its fleet limit: " + line.display_name)
		if jr_east and line.id >= 7 and not render_only:
			_check(count == 2, "Both trains must actually enter service on each new southern JR route.")
		if not jr_east and not render_only:
			_check(count == line.max_trains, "Montréal must actually dispatch six trains per line, except two on yellow: " + line.display_name)
			_check(dispatcher.service_fleet(line) == line.max_trains, "Requested Montréal fleets must be sustainable, not just slider limits.")
	if not render_only:
		_check(dispatcher.arrival_count > 0, "Preset simulation must continue making station calls.")
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
		var camera: Camera2D = main.get("camera")
		var viewport_size: Vector2 = main.get_viewport_rect().size
		var usable := Rect2(Vector2(32, 80), viewport_size - Vector2(64, 160))
		for station: Station in graph.stations:
			var screen_position := viewport_size * 0.5 + (station.position - camera.position) * camera.zoom
			_check(usable.has_point(screen_position), "The compact Tokyo preset must fit inside HUD margins: " + station.display_name)
	_check(main.get("_line_label").text == lines[restored["active_line"]].display_name, "Line settings must display the factual service name.")
	var tab: Button = main.get("_line_selector").get_child(restored["active_line"])
	_check(tab.tooltip_text == lines[restored["active_line"]].display_name, "Compact tabs must expose service names in their tooltips.")
	main.get("dispatcher").process(2.0 if render_only else 30.0, false)
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
	print("%s: %d stations, %d physical tracks, %d playable paths, %d trains; parse %.1f ms, route build %.1f ms, %s simulation %.1f ms, menu load/render caches %.1f ms." % [path, graph.stations.size(), graph.tracks.size(), lines.size(), dispatcher.metros.size(), parse_ms, build_ms, "one-tick" if render_only else "%ds" % simulation_seconds, simulation_ms, menu_load_ms])

func _test_montreal_shape(graph: TransitGraph, names: Dictionary) -> void:
	for reference: Array in [["Berri-UQAM", Vector2(384, 0)], ["Jean-Talon", Vector2(-192, -576)], ["Snowdon", Vector2(-576, 384)], ["Lionel-Groulx", Vector2(-96, 768)]]:
		_check(graph.stations[names[reference[0]]].position == reference[1], "Montréal must preserve its accepted shape at the tighter 48-unit spacing: " + reference[0])
	var minimum_fit := TrackGeometry.train_length(2) + 40.0
	_check(96.0 < minimum_fit and 144.0 >= minimum_fit and Vector2(96, 96).length() >= minimum_fit and Vector2(48, 48).length() < minimum_fit, "The compact straight runs must use the smallest axial/diagonal grid spacing that fits two wagons.")
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

func _test_jr_corridor_separation(graph: TransitGraph, lines: Array[TransitLine], routes: Dictionary, names: Dictionary) -> void:
	for pair: Array in [["Tokyo", "Kanda"], ["Kanda", "Akihabara"], ["Shimbashi", "Hamamatsucho"], ["Shibuya", "Ebisu"], ["Totsuka", "Ofuna"], ["Fujisawa", "Tsujido"], ["Hiratsuka", "Oiso"]]:
		var track := graph.track_between(names[pair[0]], names[pair[1]])
		var midpoint := graph.stations[track.a].position.lerp(graph.stations[track.b].position, 0.5)
		var centers: Array[Vector2] = []
		for line: TransitLine in lines:
			if line.tracks.has(track.id):
				centers.append(TrackGeometry.closest_point(routes[line.id]["centerline"], midpoint))
		_check(centers.size() >= 2, "JR separation probes must cover shared corridors.")
		for first in range(centers.size()):
			for second in range(first + 1, centers.size()):
				_check(centers[first].distance_to(centers[second]) >= 40.0, "Shared JR services must have distinct side-by-side corridors with a visible gap: " + pair[0] + " - " + pair[1])
	for first in range(graph.tracks.size()):
		var a := graph.tracks[first]
		for second in range(first + 1, graph.tracks.size()):
			var b := graph.tracks[second]
			for ai in range(a.waypoints.size() - 1):
				var axis := a.waypoints[ai + 1] - a.waypoints[ai]
				for bi in range(b.waypoints.size() - 1):
					var other_axis := b.waypoints[bi + 1] - b.waypoints[bi]
					if not is_zero_approx(axis.cross(other_axis)) or not is_zero_approx(axis.cross(b.waypoints[bi] - a.waypoints[ai])):
						continue
					var direction := axis.normalized()
					var a_start := a.waypoints[ai].dot(direction)
					var a_end := a.waypoints[ai + 1].dot(direction)
					var b_start := b.waypoints[bi].dot(direction)
					var b_end := b.waypoints[bi + 1].dot(direction)
					var overlap := minf(maxf(a_start, a_end), maxf(b_start, b_end)) - maxf(minf(a_start, a_end), minf(b_start, b_end))
					_check(overlap <= 1.0, "Distinct JR physical tracks must not lie on top of each other: %s / %s" % [graph.stations[a.a].display_name, graph.stations[b.a].display_name])

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
		"Akabane,Ikebukuro,Shinjuku,Shibuya,Ebisu,Osaki,Nishi-Oi,Musashi-Kosugi,Shin-Kawasaki,Yokohama,Hodogaya,Higashi-Totsuka,Totsuka,Ofuna,Kita-Kamakura,Kamakura,Zushi"
	]
	_check(graph.stations.size() == 80 and graph.tracks.size() == 97 and lines.size() == expected.size(), "Tokyo and its requested Shonan extensions must contain 80 stations, 97 tracks and ten services.")
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
	_check(not Geometry2D.triangulate_polygon(loop).is_empty(), "The Yamanote backbone must be a simple oval, not a tangled region.")
	for station_name: String in ["Yotsuya", "Ichigaya", "Iidabashi", "Suidobashi", "Ochanomizu"]:
		_check(Geometry2D.is_point_in_polygon(graph.stations[names[station_name]].position, loop), "Chuo's central cross-city corridor must sit inside the Yamanote loop: " + station_name)
