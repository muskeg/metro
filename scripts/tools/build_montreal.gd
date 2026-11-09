extends SceneTree

const StoreScript := preload("res://scripts/layout_store.gd")
const STATION_SPACING := 48.0
var graph := TransitGraph.new()
var lines: Array[TransitLine] = []
var station_ids: Dictionary = {}

func _initialize() -> void:
	_build.call_deferred()

func _station(display_name: String, x: int, y: int) -> void:
	var station := graph.add_station(Vector2(x, y) * STATION_SPACING)
	station.display_name = display_name
	station_ids[display_name] = station.id

func _line(display_name: String, color: String, stations: Array[String]) -> void:
	var line := TransitLine.new(lines.size(), Color(color))
	line.display_name = display_name
	# Yellow's three-stop shuttle only holds two trains at two wagons.
	var yellow := display_name.begins_with("4 ")
	line.max_trains = {"1 ": 10, "2 ": 12, "4 ": 2, "5 ": 6}[display_name.left(2)]
	line.wagon_count = 2 if yellow else 3
	line.dispatch_rate = 12
	for station_name: String in stations:
		assert(station_ids.has(station_name), "Missing station " + station_name)
		assert(line.append_station(graph, station_ids[station_name]))
	lines.append(line)

func _guide(a: String, b: String, bends: Array[Vector2]) -> void:
	var track := graph.track_between(station_ids[a], station_ids[b])
	assert(track != null, "Missing guided metro track.")
	var points := PackedVector2Array([graph.stations[station_ids[a]].position])
	for bend: Vector2 in bends:
		points.append(bend * STATION_SPACING)
	points.append(graph.stations[station_ids[b]].position)
	if track.a != station_ids[a]:
		points.reverse()
	track.waypoints = points

func _build() -> void:
	# Coordinates are an original schematic, not traced from STM's map artwork.
	var stations: Array = [
		["Angrignon", -16, 22], ["Monk", -13, 22], ["Jolicoeur", -10, 22],
		["Verdun", -7, 22], ["De l'Église", -4, 22], ["LaSalle", -2, 20],
		["Charlevoix", 0, 18], ["Lionel-Groulx", -2, 16], ["Atwater", -4, 12],
		["Guy-Concordia", -2, 10], ["Peel", 0, 8], ["McGill", 2, 6],
		["Place-des-Arts", 4, 4], ["Saint-Laurent", 6, 2], ["Berri-UQAM", 8, 0],
		["Beaudry", 10, -2], ["Papineau", 12, -4], ["Frontenac", 14, -6],
		["Préfontaine", 12, -10], ["Joliette", 14, -12], ["Pie-IX", 16, -14],
		["Viau", 18, -16], ["Assomption", 16, -18], ["Cadillac", 18, -20],
		["Langelier", 20, -22], ["Radisson", 22, -24], ["Honoré-Beaugrand", 24, -26],
		["Côte-Vertu", -24, -4], ["Du Collège", -22, -2], ["De la Savane", -20, 0],
		["Namur", -18, 2], ["Plamondon", -16, 4], ["Côte-Sainte-Catherine", -14, 6],
		["Snowdon", -12, 8], ["Villa-Maria", -10, 10], ["Vendôme", -8, 12],
		["Place-Saint-Henri", -6, 14], ["Lucien-L'Allier", 2, 12], ["Bonaventure", 4, 10],
		["Square-Victoria–OACI", 6, 8], ["Place-d'Armes", 8, 6], ["Champ-de-Mars", 10, 4],
		["Sherbrooke", 6, -2], ["Mont-Royal", 4, -4], ["Laurier", 2, -6],
		["Rosemont", 0, -8], ["Beaubien", -2, -10], ["Jean-Talon", -4, -12],
		["Jarry", -6, -14], ["Crémazie", -8, -16], ["Sauvé", -10, -18],
		["Henri-Bourassa", -12, -20], ["Cartier", -14, -22], ["De la Concorde", -17, -23],
		["Montmorency", -20, -23], ["Côte-des-Neiges", -10, 6],
		["Université-de-Montréal", -8, 4], ["Édouard-Montpetit", -6, 2],
		["Outremont", -6, -1], ["Acadie", -8, -4], ["Parc", -8, -8],
		["De Castelnau", -6, -10], ["Fabre", -2, -14], ["D'Iberville", 0, -16],
		["Saint-Michel", 2, -18], ["Jean-Drapeau", 13, 0],
		["Longueuil–Université-de-Sherbrooke", 15, -2],
		["Georges-Vanier", 0, 14]
	]
	for saved: Array in stations:
		_station(saved[0], saved[1], saved[2])
	_line("1 · Verte / Green", "#009e62", ["Angrignon", "Monk", "Jolicoeur", "Verdun", "De l'Église", "LaSalle", "Charlevoix", "Lionel-Groulx", "Atwater", "Guy-Concordia", "Peel", "McGill", "Place-des-Arts", "Saint-Laurent", "Berri-UQAM", "Beaudry", "Papineau", "Frontenac", "Préfontaine", "Joliette", "Pie-IX", "Viau", "Assomption", "Cadillac", "Langelier", "Radisson", "Honoré-Beaugrand"])
	_line("2 · Orange", "#ef7d00", ["Côte-Vertu", "Du Collège", "De la Savane", "Namur", "Plamondon", "Côte-Sainte-Catherine", "Snowdon", "Villa-Maria", "Vendôme", "Place-Saint-Henri", "Lionel-Groulx", "Georges-Vanier", "Lucien-L'Allier", "Bonaventure", "Square-Victoria–OACI", "Place-d'Armes", "Champ-de-Mars", "Berri-UQAM", "Sherbrooke", "Mont-Royal", "Laurier", "Rosemont", "Beaubien", "Jean-Talon", "Jarry", "Crémazie", "Sauvé", "Henri-Bourassa", "Cartier", "De la Concorde", "Montmorency"])
	_line("4 · Jaune / Yellow", "#f6d429", ["Berri-UQAM", "Jean-Drapeau", "Longueuil–Université-de-Sherbrooke"])
	_line("5 · Bleue / Blue", "#0086c9", ["Snowdon", "Côte-des-Neiges", "Université-de-Montréal", "Édouard-Montpetit", "Outremont", "Acadie", "Parc", "De Castelnau", "Jean-Talon", "Fabre", "D'Iberville", "Saint-Michel"])
	for track: Track in graph.tracks:
		track.waypoints = TrackGeometry.elastic_path(graph.stations[track.a].position, graph.stations[track.b].position)
	_guide("Atwater", "Lionel-Groulx", [Vector2(-5, 13)])
	_guide("Place-Saint-Henri", "Lionel-Groulx", [Vector2(-6, 16), Vector2(-4, 18)])
	_guide("Champ-de-Mars", "Berri-UQAM", [Vector2(10, 2)])
	_guide("Édouard-Montpetit", "Outremont", [Vector2(-5, 1), Vector2(-5, 0)])
	_guide("Acadie", "Parc", [Vector2(-9, -5), Vector2(-9, -7)])
	_guide("Frontenac", "Préfontaine", [Vector2(15, -7)])
	var store := StoreScript.new()
	var snapshot := store.capture(graph, lines, 0, Vector2(0, -96), 0.08)
	snapshot["name"] = "Montréal métro"
	snapshot["sources"] = ["User-supplied STM plan-metro-noir.pdf (© STM 10-2025)", "https://www.stm.info/en/network-guide/all-stm-network-maps"]
	snapshot["description"] = "The four Montreal metro lines and their 68 existing stations, with shared interchange nodes. REM, exo, bus links, continuation endpoints and projected extensions are excluded. Original schematic coordinates; not an operational timetable."
	snapshot["scope"] = "montreal-metro-only"
	for index in range(lines.size()):
		snapshot["lines"][index]["category"] = "metro"
	assert(not store.restore(snapshot).is_empty(), store.error_message)
	var file := FileAccess.open("res://layouts/montreal.json", FileAccess.WRITE)
	assert(file != null, error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(snapshot, "  "))
	file.close()
	print("Montréal preset: %d stations, %d tracks, %d line paths." % [graph.stations.size(), graph.tracks.size(), lines.size()])
	quit()
