class_name Station
extends RefCounted

var id: int
var position: Vector2

func _init(station_id: int, station_position: Vector2) -> void:
	id = station_id
	position = station_position
