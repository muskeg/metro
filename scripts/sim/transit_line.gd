class_name TransitLine
extends RefCounted

var id: int
var stations: Array[int] = []
var tracks: Array[int] = []
var color: Color
var display_name := ""
var dispatch_rate: float = 18.0
var dwell_time: float = 3.0
var cruise_velocity: float = 100.0
var acceleration: float = 80.0
var braking: float = 100.0
var terminal_recovery: float = 4.0
var dispatch_elapsed: float = 0.0
var wagon_count: int = 2
var max_trains: int = 4

func _init(line_id: int, line_color: Color) -> void:
	id = line_id
	color = line_color

func append_station(graph: TransitGraph, station_id: int) -> bool:
	if station_id < 0 or station_id >= graph.stations.size():
		return false
	if is_loop() or (stations.has(station_id) and not can_close(stations.back(), station_id)):
		return false
	if not stations.is_empty() and stations.back() == station_id:
		return false
	if not stations.is_empty():
		var track := graph.add_track(stations.back(), station_id)
		if track == null:
			return false
		tracks.append(track.id)
	stations.append(station_id)
	return true

func prepend_station(graph: TransitGraph, station_id: int) -> bool:
	if station_id < 0 or station_id >= graph.stations.size():
		return false
	if is_loop() or stations.has(station_id):
		return false
	if not stations.is_empty() and stations[0] == station_id:
		return false
	if not stations.is_empty():
		var track := graph.add_track(station_id, stations[0])
		if track == null:
			return false
		tracks.insert(0, track.id)
	stations.insert(0, station_id)
	return true

func can_extend_from(station_id: int) -> bool:
	return not is_loop() and (stations.is_empty() or station_id == stations[0] or station_id == stations.back())

func is_loop() -> bool:
	return stations.size() >= 4 and stations[0] == stations.back()

func can_close(from_id: int, to_id: int) -> bool:
	return not is_loop() and stations.size() >= 3 and ((from_id == stations[0] and to_id == stations.back()) or (from_id == stations.back() and to_id == stations[0]))
