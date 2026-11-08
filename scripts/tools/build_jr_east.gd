extends SceneTree

const StoreScript := preload("res://scripts/layout_store.gd")
const OUTPUT_PATH := "res://layouts/jr_east.json"
const STATION_SPACING := 144.0

var graph := TransitGraph.new()
var lines: Array[TransitLine] = []
var station_ids: Dictionary = {}

func _initialize() -> void:
	_build.call_deferred()

func _line(display_name: String, color: String, names: Array[String]) -> void:
	var line := TransitLine.new(lines.size(), Color(color))
	line.display_name = display_name
	line.max_trains = 2
	line.dispatch_rate = 24
	for station_name: String in names:
		assert(station_ids.has(station_name), "Missing station: " + station_name)
		assert(line.append_station(graph, station_ids[station_name]), "Invalid route: " + display_name)
	lines.append(line)

func _guide(a: String, b: String, bends: Array[Vector2]) -> void:
	var track := graph.track_between(station_ids[a], station_ids[b])
	assert(track != null, "Missing guided track.")
	var points := PackedVector2Array([graph.stations[station_ids[a]].position])
	for bend: Vector2 in bends:
		points.append(bend * STATION_SPACING)
	points.append(graph.stations[station_ids[b]].position)
	if track.a != station_ids[a]:
		points.reverse()
	track.waypoints = points

func _build() -> void:
	# North-up, hand-positioned schematic: the loop is the backbone, not an auto-packed region.
	var stations: Array = [
		["Tokyo", 6, 0], ["Kanda", 6, -2], ["Akihabara", 6, -4],
		["Okachimachi", 6, -6], ["Ueno", 6, -8], ["Uguisudani", 5, -10],
		["Nippori", 4, -11], ["Nishi-Nippori", 2, -13], ["Tabata", 0, -13],
		["Komagome", -2, -13], ["Sugamo", -4, -13], ["Otsuka", -6, -11],
		["Ikebukuro", -8, -9], ["Mejiro", -8, -7], ["Takadanobaba", -8, -5],
		["Shin-Okubo", -8, -3], ["Shinjuku", -8, -1], ["Yoyogi", -8, 1],
		["Harajuku", -8, 3], ["Shibuya", -8, 5], ["Ebisu", -6, 7],
		["Meguro", -4, 9], ["Gotanda", -2, 11], ["Osaki", 0, 11],
		["Shinagawa", 2, 11], ["Takanawa Gateway", 4, 9], ["Tamachi", 6, 7],
		["Hamamatsucho", 6, 5], ["Shimbashi", 6, 3], ["Yurakucho", 6, 1],
		["Akabane", -2, -21], ["Higashi-Jujo", -2, -19], ["Oji", 0, -17],
		["Kami-Nakazato", 0, -15], ["Oimachi", 2, 14], ["Omori", 2, 17],
		["Kamata", 2, 20], ["Nakano", -14, -1], ["Higashi-Nakano", -12, -1],
		["Okubo", -10, -1], ["Sendagaya", -6, 1], ["Shinanomachi", -4, -1],
		["Yotsuya", -2, -3], ["Ichigaya", -2, -5], ["Iidabashi", 0, -7],
		["Suidobashi", 2, -7], ["Ochanomizu", 4, -5], ["Asakusabashi", 8, -4],
		["Ryogoku", 10, -4], ["Kinshicho", 12, -4],
		["Jujo", -6, -19], ["Itabashi", -8, -15],
		["Mikawashima", 8, -11], ["Minami-Senju", 10, -13], ["Kita-Senju", 10, -17],
		["Hatchobori", 9, 1], ["Etchujima", 11, 3], ["Shiomi", 13, 5],
		["Shin-Kiba", 16, 5],
		["Kawasaki", 2, 22], ["Yokohama", 0, 23], ["Totsuka", -4, 25],
		["Ofuna", -6, 27], ["Fujisawa", -8, 27], ["Tsujido", -10, 27],
		["Chigasaki", -12, 27], ["Hiratsuka", -14, 27], ["Oiso", -16, 27],
		["Ninomiya", -18, 27], ["Kozu", -20, 27], ["Kamonomiya", -22, 27],
		["Odawara", -24, 29], ["Nishi-Oi", -2, 14], ["Musashi-Kosugi", -4, 17],
		["Shin-Kawasaki", -2, 19], ["Hodogaya", 1, 25], ["Higashi-Totsuka", 0, 27],
		["Kita-Kamakura", -4, 29], ["Kamakura", -2, 29], ["Zushi", 0, 29]
	]
	for saved: Array in stations:
		var station := graph.add_station(Vector2(saved[1], saved[2]) * STATION_SPACING)
		station.display_name = saved[0]
		station_ids[saved[0]] = station.id
	var loop: Array[String] = []
	for index in range(30):
		loop.append(stations[index][0])
	loop.append(loop[0])
	_line("JY Yamanote (30-station loop)", "#80c241", loop)
	_line("JK Keihin-Tohoku (Akabane - Kamata, local)", "#00b2e5", [
		"Akabane", "Higashi-Jujo", "Oji", "Kami-Nakazato", "Tabata",
		"Nishi-Nippori", "Nippori", "Uguisudani", "Ueno", "Okachimachi",
		"Akihabara", "Kanda", "Tokyo", "Yurakucho", "Shimbashi", "Hamamatsucho",
		"Tamachi", "Takanawa Gateway", "Shinagawa", "Oimachi", "Omori", "Kamata"
	])
	_line("JC Chuo Rapid (Nakano - Tokyo)", "#f15a22", [
		"Nakano", "Shinjuku", "Yotsuya", "Ochanomizu", "Kanda", "Tokyo"
	])
	_line("JB Chuo-Sobu Local (Nakano - Kinshicho)", "#ffd400", [
		"Nakano", "Higashi-Nakano", "Okubo", "Shinjuku", "Yoyogi", "Sendagaya",
		"Shinanomachi", "Yotsuya", "Ichigaya", "Iidabashi", "Suidobashi",
		"Ochanomizu", "Akihabara", "Asakusabashi", "Ryogoku", "Kinshicho"
	])
	_line("JA Saikyo (Akabane - Osaki)", "#00ac9a", [
		"Akabane", "Jujo", "Itabashi", "Ikebukuro", "Shinjuku", "Shibuya", "Ebisu", "Osaki"
	])
	_line("JJ Joban Rapid (Ueno - Kita-Senju)", "#00b261", [
		"Ueno", "Nippori", "Mikawashima", "Minami-Senju", "Kita-Senju"
	])
	_line("JE Keiyo Local (Tokyo - Shin-Kiba)", "#c9242f", [
		"Tokyo", "Hatchobori", "Etchujima", "Shiomi", "Shin-Kiba"
	])
	_line("JT Tokaido (Tokyo - Odawara, local)", "#f68b1e", [
		"Tokyo", "Shimbashi", "Shinagawa", "Kawasaki", "Yokohama", "Totsuka",
		"Ofuna", "Fujisawa", "Tsujido", "Chigasaki", "Hiratsuka", "Oiso",
		"Ninomiya", "Kozu", "Kamonomiya", "Odawara"
	])
	_line("JS Shonan-Shinjuku (Akabane - Odawara, rapid)", "#e85422", [
		"Akabane", "Ikebukuro", "Shinjuku", "Shibuya", "Ebisu", "Osaki",
		"Musashi-Kosugi", "Yokohama", "Totsuka", "Ofuna", "Fujisawa",
		"Tsujido", "Chigasaki", "Hiratsuka", "Oiso", "Ninomiya", "Kozu",
		"Kamonomiya", "Odawara"
	])
	_line("JS Shonan-Shinjuku (Akabane - Zushi, local)", "#b65e2a", [
		"Akabane", "Ikebukuro", "Shinjuku", "Shibuya", "Ebisu", "Osaki",
		"Nishi-Oi", "Musashi-Kosugi", "Shin-Kawasaki", "Yokohama", "Hodogaya",
		"Higashi-Totsuka", "Totsuka", "Ofuna", "Kita-Kamakura", "Kamakura", "Zushi"
	])
	for track: Track in graph.tracks:
		track.waypoints = TrackGeometry.elastic_path(graph.stations[track.a].position, graph.stations[track.b].position)
	# Express corridors bypass intermediate local markers, rather than passing through them.
	_guide("Nakano", "Shinjuku", [Vector2(-13, 0), Vector2(-9, 0)])
	_guide("Shinjuku", "Yotsuya", [Vector2(-6, -1), Vector2(-4, -3)])
	_guide("Yotsuya", "Ochanomizu", [Vector2(2, -3)])
	_guide("Ochanomizu", "Kanda", [Vector2(4, -4)])
	_guide("Ikebukuro", "Shinjuku", [Vector2(-7, -8), Vector2(-7, -2)])
	_guide("Shinjuku", "Shibuya", [Vector2(-7, 0), Vector2(-7, 4)])
	_guide("Ebisu", "Osaki", [Vector2(-2, 7), Vector2(0, 9)])
	_guide("Ueno", "Nippori", [Vector2(3, -8), Vector2(3, -10)])
	_guide("Tokyo", "Shimbashi", [Vector2(5, 1), Vector2(5, 2)])
	_guide("Shimbashi", "Shinagawa", [Vector2(8, 5), Vector2(8, 9), Vector2(6, 11)])
	_guide("Shinagawa", "Kawasaki", [Vector2(4, 13), Vector2(4, 20)])
	_guide("Akabane", "Ikebukuro", [Vector2(-10, -21), Vector2(-10, -11)])
	_guide("Osaki", "Musashi-Kosugi", [Vector2(0, 13)])
	_guide("Musashi-Kosugi", "Yokohama", [Vector2(-4, 19)])
	_guide("Higashi-Totsuka", "Totsuka", [Vector2(-2, 27)])
	var store := StoreScript.new()
	var snapshot := store.capture(graph, lines, 0, Vector2(-576, 576), 0.08)
	snapshot["name"] = "Tokyo central JR"
	snapshot["description"] = "Tokyo JR schematic anchored by the complete 30-station Yamanote loop, extending southwest along Tokaido to Odawara via Hiratsuka. Shonan-Shinjuku includes Tokaido-bound rapid and Yokosuka-bound local services to Odawara and Zushi, cropped north at Akabane. Rapid is not special rapid: it serves all Tokaido stations south of Totsuka. Other adjacent corridors retain their named cropped boundaries; these are not necessarily real service termini. Keihin-Tohoku uses its local stopping pattern. No subway, northern regional branches, airport links or timetable simulation. Original north-up schematic, not copied map artwork."
	snapshot["sources"] = [
		"https://www.jreast.co.jp/e/info/map_a4ol.pdf",
		"https://en.wikipedia.org/wiki/Yamanote_Line",
		"https://en.wikipedia.org/wiki/Keihin%E2%80%93T%C5%8Dhoku_Line",
		"https://en.wikipedia.org/wiki/Ch%C5%AB%C5%8D_Line_%28Rapid%29",
		"https://en.wikipedia.org/wiki/Ch%C5%AB%C5%8D%E2%80%93S%C5%8Dbu_Line",
		"https://en.wikipedia.org/wiki/Saiky%C5%8D_Line",
		"https://en.wikipedia.org/wiki/J%C5%8Dban_Line",
		"https://en.wikipedia.org/wiki/Keiy%C5%8D_Line",
		"https://en.wikipedia.org/wiki/T%C5%8Dkaid%C5%8D_Line_(JR_East)",
		"https://en.wikipedia.org/wiki/Sh%C5%8Dnan%E2%80%93Shinjuku_Line"
	]
	snapshot["scope"] = "central-tokyo-jr"
	assert(not store.restore(snapshot).is_empty(), store.error_message)
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	assert(file != null, error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(snapshot, "  "))
	file.close()
	print("Tokyo central JR preset: %d stations, %d tracks, %d paths." % [graph.stations.size(), graph.tracks.size(), lines.size()])
	quit()
