class_name Track
extends RefCounted

var id: int
var a: int
var b: int
var waypoints: PackedVector2Array = PackedVector2Array()

func _init(track_id: int, station_a: int, station_b: int) -> void:
	id = track_id
	a = station_a
	b = station_b
