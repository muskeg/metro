class_name Metro
extends RefCounted

var id: int
var line_id: int
var travel_direction: int = 1
var progress: float = 0.0
var speed: float = 0.0
var dwell_remaining: float = 0.0
var position: Vector2
var moving: bool = false
var arrival_count: int = 0
var distance: float = 0.0
var wagon_count: int = 2
var next_stop_index: int = 0
var blocked: bool = false
var at_station: bool = true
var station_arrival_time: float = 0.0
var departure_error: float = 0.0
var passenger_count := 0
var visit: StationVisit
var reverse_pending := false

func _init(metro_id: int, route_id: int, initial_position: Vector2) -> void:
	id = metro_id
	line_id = route_id
	position = initial_position
