extends SceneTree

const StoreScript := preload("res://scripts/layout_store.gd")
const OUTPUT_PATH := "res://layouts/jr_east.json"
const STATION_SPACING := 96.0
const WAGON_COUNT := 3
# Per-line fleet ceilings in line order: 64 trains total (the layout cap).
const FLEETS: Array[int] = [10, 8, 4, 6, 4, 4, 4, 8, 6, 6, 4]
# Keihin-Tohoku's southern stops sit one corridor slot below the Tokaido axis.
const KEIHIN_ROW := 18.0 + 48.0 / STATION_SPACING

var graph := TransitGraph.new()
var lines: Array[TransitLine] = []
var station_ids: Dictionary = {}

func _initialize() -> void:
	_build.call_deferred()

func _line(display_name: String, color: String, names: Array[String]) -> void:
	var line := TransitLine.new(lines.size(), Color(color))
	line.display_name = display_name
	line.max_trains = FLEETS[lines.size()]
	line.wagon_count = WAGON_COUNT
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

func _follow(a: String, b: String, via: Array[String]) -> void:
	var names: Array[String] = [a]
	names.append_array(via)
	names.append(b)
	var points := PackedVector2Array()
	for index in range(names.size() - 1):
		var section := graph.track_between(station_ids[names[index]], station_ids[names[index + 1]])
		assert(section != null, "Missing corridor section: " + names[index])
		var anchors := section.waypoints.duplicate()
		if section.a != station_ids[names[index]]:
			anchors.reverse()
		points.append_array(anchors if points.is_empty() else anchors.slice(1))
	var track := graph.track_between(station_ids[a], station_ids[b])
	assert(track != null, "Missing parallel service track.")
	if track.a != station_ids[a]:
		points.reverse()
	track.waypoints = points

func _build() -> void:
	# Original wide schematic using the station-numbering map's corridor arrangement.
	var stations: Array = [
		["Tokyo", 12, 0], ["Kanda", 12, -5], ["Akihabara", 12, -9],
		["Okachimachi", 12, -11], ["Ueno", 12, -13], ["Uguisudani", 10, -15],
		["Nippori", 8, -17], ["Nishi-Nippori", 6, -19], ["Tabata", 4, -21],
		["Komagome", -2, -21], ["Sugamo", -6, -21], ["Otsuka", -8, -21],
		["Ikebukuro", -12, -17], ["Mejiro", -16, -13], ["Takadanobaba", -16, -11.5],
		["Shin-Okubo", -16, -9], ["Shinjuku", -16, -6], ["Yoyogi", -16, -3],
		["Harajuku", -16, -1], ["Shibuya", -16, 1], ["Ebisu", -16, 3],
		["Meguro", -16, 6], ["Gotanda", -16, 9], ["Osaki", -16, 12],
		["Shinagawa", -10, 18], ["Takanawa Gateway", -2, 18], ["Tamachi", 6, 18],
		["Hamamatsucho", 9, 15], ["Shimbashi", 12, 12], ["Yurakucho", 12, 4],
		["Akabane", -6, -29], ["Higashi-Jujo", -4, -27], ["Oji", -1, -24],
		["Kami-Nakazato", 1, -22], ["Oimachi", -16, KEIHIN_ROW], ["Omori", -20, KEIHIN_ROW],
		["Kamata", -24, KEIHIN_ROW], ["Nakano", -36, -6], ["Higashi-Nakano", -30, -6],
		["Okubo", -24, -6], ["Sendagaya", -12, -3], ["Shinanomachi", -8, -3],
		["Yotsuya", -5, -6], ["Ichigaya", -2, -9], ["Iidabashi", 1, -12],
		["Suidobashi", 5, -12], ["Ochanomizu", 9, -12], ["Asakusabashi", 18, -9],
		["Ryogoku", 22, -9], ["Kinshicho", 26, -9],
		["Jujo", -9, -26], ["Itabashi", -12, -23],
		["Mikawashima", 12, -21], ["Minami-Senju", 18, -21], ["Kita-Senju", 24, -21],
		["Hatchobori", 20, 0], ["Etchujima", 26, 0], ["Shiomi", 32, 0],
		["Shin-Kiba", 38, 0],
		["Kawasaki", -28, 18], ["Yokohama", -36, 18], ["Totsuka", -44, 18],
		["Ofuna", -52, 18], ["Fujisawa", -56, 14], ["Tsujido", -56, 12],
		["Chigasaki", -56, 10], ["Hiratsuka", -62, 10], ["Oiso", -62, 12],
		["Ninomiya", -62, 14], ["Kozu", -62, 16], ["Kamonomiya", -62, 17.5],
		["Odawara", -62, 20], ["Nishi-Oi", -20, 12], ["Musashi-Kosugi", -30, 12],
		["Shin-Kawasaki", -33, 15], ["Hodogaya", -39, 18], ["Higashi-Totsuka", -42, 18],
		["Kita-Kamakura", -50, 27], ["Kamakura", -46, 27], ["Zushi", -42, 27],
		["Tennozu Isle", 4, 21], ["Oi Keibajo Mae", 0, 21], ["Ryutsu Center", -3, 21],
		["Showajima", -6, 21], ["Seibijo", -9, 21], ["Tenkubashi", -12, 21],
		["Haneda Airport Terminal 3", -15, 21], ["Shin-Seibijo", -17, 23],
		["Haneda Airport Terminal 1", -17, 24.5], ["Haneda Airport Terminal 2", -17, 27]
	]
	for saved: Array in stations:
		var station := graph.add_station((Vector2(saved[1], saved[2]) * STATION_SPACING).round())
		station.display_name = saved[0]
		station_ids[saved[0]] = station.id
	var loop: Array[String] = []
	for index in range(30):
		loop.append(stations[index][0])
	loop.append(loop[0])
	_line("JY Yamanote (30-station loop)", "#80c241", loop)
	lines[0].render_priority = 1
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
	_line("MO Tokyo Monorail (Hamamatsucho - Haneda Airport Terminal 2)", "#1d4f9c", [
		"Hamamatsucho", "Tennozu Isle", "Oi Keibajo Mae", "Ryutsu Center", "Showajima",
		"Seibijo", "Tenkubashi", "Haneda Airport Terminal 3", "Shin-Seibijo",
		"Haneda Airport Terminal 1", "Haneda Airport Terminal 2"
	])
	for track: Track in graph.tracks:
		track.waypoints = TrackGeometry.elastic_path(graph.stations[track.a].position, graph.stations[track.b].position)
	_guide("Ochanomizu", "Kanda", [Vector2(9, -8)])
	_guide("Chigasaki", "Hiratsuka", [Vector2(-56, 9), Vector2(-58, 7), Vector2(-60, 7), Vector2(-62, 9)])
	_guide("Ofuna", "Kita-Kamakura", [Vector2(-52, 25)])
	_guide("Hamamatsucho", "Tennozu Isle", [Vector2(9, 17), Vector2(5, 21)])
	# Waypoints follow the corridor; only the service's station list defines stops.
	_follow("Nakano", "Shinjuku", ["Higashi-Nakano", "Okubo"])
	_follow("Shinjuku", "Yotsuya", ["Yoyogi", "Sendagaya", "Shinanomachi"])
	_follow("Yotsuya", "Ochanomizu", ["Ichigaya", "Iidabashi", "Suidobashi"])
	_follow("Akabane", "Ikebukuro", ["Jujo", "Itabashi"])
	_follow("Ikebukuro", "Shinjuku", ["Mejiro", "Takadanobaba", "Shin-Okubo"])
	_follow("Shinjuku", "Shibuya", ["Yoyogi", "Harajuku"])
	_follow("Ebisu", "Osaki", ["Meguro", "Gotanda"])
	_follow("Ueno", "Nippori", ["Uguisudani"])
	_follow("Tokyo", "Shimbashi", ["Yurakucho"])
	_follow("Shimbashi", "Shinagawa", ["Hamamatsucho", "Tamachi", "Takanawa Gateway"])
	_follow("Osaki", "Musashi-Kosugi", ["Nishi-Oi"])
	_follow("Musashi-Kosugi", "Yokohama", ["Shin-Kawasaki"])
	_follow("Yokohama", "Totsuka", ["Hodogaya", "Higashi-Totsuka"])
	var store := StoreScript.new()
	var snapshot := store.capture(graph, lines, 0, Vector2(-12, -1) * STATION_SPACING, 0.12)
	snapshot["name"] = "Tokyo central JR"
	snapshot["description"] = "Wide Tokyo JR schematic using the station-numbering map's corridor arrangement: the complete 30-station Yamanote loop has straight sides, balanced diagonal shoulders and centered, shorter northern and southern shelves. Tokaido runs west from Shinagawa through Yokohama to Ofuna, then folds north through Chigasaki and back to Odawara rather than extending far south. Shonan-Shinjuku includes Tokaido-bound rapid and Yokosuka-bound local services to Odawara and Zushi, cropped north at Akabane. Rapid is not special rapid: it serves all Tokaido stations south of Totsuka. Other adjacent corridors retain their named cropped boundaries; these are not necessarily real service termini. Keihin-Tohoku uses its local stopping pattern on its own row beside the Tokaido axis. The Tokyo Monorail runs from Hamamatsucho along the bay to Haneda Airport Terminal 2. No subway, northern regional branches, Keikyu airport line or timetable simulation. Original schematic geometry, not copied map artwork."
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
		"https://en.wikipedia.org/wiki/Sh%C5%8Dnan%E2%80%93Shinjuku_Line",
		"https://en.wikipedia.org/wiki/Tokyo_Monorail"
	]
	snapshot["scope"] = "central-tokyo-jr"
	assert(not store.restore(snapshot).is_empty(), store.error_message)
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	assert(file != null, error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(snapshot, "  "))
	file.close()
	print("Tokyo central JR preset: %d stations, %d tracks, %d paths." % [graph.stations.size(), graph.tracks.size(), lines.size()])
	quit()
