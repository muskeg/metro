class_name WorldView
extends Node2D

const BACKDROP := preload("res://scripts/render/urban_backdrop.gd")
const CORRIDOR_WIDTH := 28.0
const LANE_EDGE_WIDTH := 8.0
const RUNNING_LANE_WIDTH := 4.0

var graph: TransitGraph
var lines: Array[TransitLine] = []
var metros: Array[Metro] = []
var selected_station_id: int = -1
var hovered_station_id: int = -1
var hovered_track_id: int = -1
var hovered_bend_index: int = -1
var route_active := false
var route_source_id := -1
var route_target_id := -1
var route_pins := PackedVector2Array()
var rail_anchor := Vector2.ZERO
var hover_caption := ""
var hover_pointer := Vector2.ZERO
var view_center: Vector2 = Vector2.ZERO
var view_zoom: Vector2 = Vector2.ONE
var time_of_day: float = 0.5
var _routes: Dictionary = {}
var _preview := PackedVector2Array()
var _preview_color := Color.WHITE
var _preview_error := ""
var _backdrop: Node2D

func _ready() -> void:
	_backdrop = BACKDROP.new()
	_backdrop.z_index = -10
	add_child(_backdrop)

func set_network(transit_graph: TransitGraph, transit_lines: Array[TransitLine], route_data: Dictionary = {}) -> void:
	graph = transit_graph
	lines = transit_lines
	_routes = route_data
	if _routes.is_empty():
		for line: TransitLine in lines:
			_routes[line.id] = TrackGeometry.circuit(graph, line, lines)
	queue_redraw()

func refresh_geometry() -> void:
	_routes.clear()
	for line: TransitLine in lines:
		_routes[line.id] = TrackGeometry.circuit(graph, line, lines)
	queue_redraw()

func set_dynamic_state(train_list: Array[Metro], center: Vector2, zoom: Vector2, phase: float) -> void:
	metros = train_list
	view_center = center
	view_zoom = zoom
	time_of_day = phase
	if _backdrop != null:
		_backdrop.call("set_view", center, zoom, phase)
	queue_redraw()

func set_stroke_preview(points: PackedVector2Array, color: Color, error: String = "") -> void:
	_preview = TrackGeometry.round_corners(points)
	_preview_color = color if error.is_empty() else Color("#d45c64")
	_preview_error = error
	queue_redraw()

func _draw() -> void:
	if graph == null:
		return
	# The Compatibility renderer's line fringe scales in world units; omit it at close zoom.
	for line: TransitLine in lines:
		if not _routes.has(line.id):
			continue
		var route: Dictionary = _routes[line.id]
		var points: PackedVector2Array = route["points"]
		if points.size() < 2:
			continue
		for lane: PackedVector2Array in route["running_paths"]:
			draw_polyline(lane, line.color, LANE_EDGE_WIDTH, view_zoom.x < 1.5)
		draw_polyline(route["centerline"], line.color, CORRIDOR_WIDTH, view_zoom.x < 1.5)
		if not line.is_loop():
			var centerline: PackedVector2Array = route["centerline"]
			for end: Vector2 in [centerline[0], centerline[centerline.size() - 1]]:
				draw_circle(end, CORRIDOR_WIDTH * 0.5, line.color, true, -1.0, view_zoom.x < 1.5)
		for lane: PackedVector2Array in route["running_paths"]:
			draw_polyline(lane, line.color.darkened(0.3), RUNNING_LANE_WIDTH, view_zoom.x < 1.5)
	for metro: Metro in metros:
		if _routes.has(metro.line_id):
			_draw_headlights(metro, TrackGeometry.route_for_direction(_routes[metro.line_id], metro.travel_direction))
	for metro: Metro in metros:
		if not _routes.has(metro.line_id):
			continue
		_draw_train(metro, TrackGeometry.route_for_direction(_routes[metro.line_id], metro.travel_direction), lines[metro.line_id].color)
	for station: Station in graph.stations:
		var night := _night_strength()
		var fill := Color.WHITE.lerp(Color("#e8eff2"), night)
		var border := Color("#34464f").lerp(Color("#819ca9"), night)
		_draw_station(station.position, fill, border)
		if station.id == selected_station_id:
			draw_arc(station.position, 15.0, 0.0, TAU, 40, Color("#f9c27b"), 1.5, true)
	if _preview.size() > 1:
		draw_polyline(_preview, _preview_color, CORRIDOR_WIDTH, view_zoom.x < 1.5)
		for offset: float in [-TrackGeometry.LANE_OFFSET, TrackGeometry.LANE_OFFSET]:
			var lane := TrackGeometry.offset_points(_preview, offset)
			draw_polyline(lane, _preview_color, LANE_EDGE_WIDTH, view_zoom.x < 1.5)
			draw_polyline(lane, _preview_color.darkened(0.3), RUNNING_LANE_WIDTH, view_zoom.x < 1.5)
	_draw_gizmos()

func station_handle_position(station: Station, direction: Vector2) -> Vector2:
	return station.position + direction * maxf(24.0, 32.0 / view_zoom.x)

func rail_delete_position() -> Vector2:
	return rail_anchor + Vector2(0.0, -32.0) / view_zoom.x

func rail_move_position() -> Vector2:
	return rail_anchor + Vector2(0.0, 32.0) / view_zoom.x

func route_flip_position() -> Vector2:
	if route_source_id < 0 or route_source_id >= graph.stations.size():
		return Vector2.ZERO
	return station_handle_position(graph.stations[route_source_id], Vector2.LEFT)

func _draw_station(position: Vector2, fill: Color, border: Color) -> void:
	draw_circle(position, 12.0, border)
	draw_circle(position, 10.0, fill)

func _draw_gizmos() -> void:
	var scale := 1.0 / view_zoom.x
	var ink := Color("#34464f").lerp(Color("#d5e4e9"), _night_strength())
	var accent := Color("#278e83").lerp(Color("#82d9bd"), _night_strength())
	var danger := Color("#c9505b").lerp(Color("#f19199"), _night_strength())
	var caption_position := Vector2.ZERO
	if route_active:
		if route_source_id >= 0 and route_source_id < graph.stations.size():
			var source := graph.stations[route_source_id].position
			_draw_station(source, Color.WHITE.lerp(Color("#e8eff2"), _night_strength()), ink)
			_draw_handle(route_flip_position(), ink, "swap", scale)
			if hover_pointer.distance_to(route_flip_position()) <= 11.0 * scale:
				_draw_caption(route_flip_position() + Vector2(-12.0, 28.0) * scale, "Inverser le coude", scale)
		for pin: Vector2 in route_pins:
			_draw_handle(pin, ink, "diamond", scale)
		if _preview.size() > 1:
			var endpoint := _preview[_preview.size() - 1]
			draw_arc(endpoint, 18.0 * scale, 0.0, TAU, 40, _preview_color, 2.0 * scale, true)
			if route_target_id < 0:
				for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
					draw_dashed_line(endpoint - direction * 27.0 * scale, endpoint + direction * 27.0 * scale, Color(ink, 0.35), scale, 4.0 * scale)
			if not _preview_error.is_empty():
				_draw_handle(endpoint + Vector2(26.0, -26.0) * scale, danger, "x", scale)
		if route_target_id >= 0 and route_target_id < graph.stations.size():
			var target := graph.stations[route_target_id].position
			_draw_station(target, Color.WHITE.lerp(Color("#e8eff2"), _night_strength()), _preview_color)
		if not _preview_error.is_empty() and _preview.size() > 1:
			_draw_caption(_preview[_preview.size() - 1] + Vector2(32.0, 28.0) * scale, _preview_error, scale)
		return
	if hovered_station_id >= 0 and hovered_station_id < graph.stations.size():
		var station := graph.stations[hovered_station_id]
		var anchor := station_handle_position(station, Vector2.RIGHT)
		draw_line(station.position + Vector2(15.0, 0.0), anchor, Color(ink, 0.25), scale, true)
		_draw_handle(anchor, accent, "+", scale)
		_draw_handle(station_handle_position(station, Vector2(1.0, -1.0)), danger, "x", scale)
		draw_arc(station.position, 16.0, 0.0, TAU, 40, Color(ink, 0.35), scale, true)
		caption_position = station.position + Vector2(18.0, 30.0) * scale
	elif hovered_track_id >= 0 and hovered_track_id < graph.tracks.size():
		var points := TrackGeometry.sample(graph, graph.tracks[hovered_track_id])
		draw_polyline(points, Color(accent, 0.45), 2.0 * scale, true)
		var anchors := TrackGeometry.anchors(graph, graph.tracks[hovered_track_id])
		for index in range(1, anchors.size() - 1):
			_draw_handle(anchors[index], ink, "diamond", scale)
		if hovered_bend_index < 0:
			draw_line(rail_delete_position(), rail_move_position(), Color(ink, 0.25), scale, true)
			_draw_handle(rail_anchor, accent, "+", scale)
			_draw_handle(rail_delete_position(), danger, "x", scale)
			_draw_handle(rail_move_position(), ink, "diamond", scale)
		caption_position = rail_anchor + Vector2(18.0, 54.0) * scale
	if not hover_caption.is_empty():
		_draw_caption(caption_position, hover_caption, scale)

func _draw_caption(position: Vector2, caption: String, scale: float) -> void:
	var font := ThemeDB.fallback_font
	var text := tr(caption)
	var width := minf(300.0, get_viewport_rect().size.x - 32.0)
	var text_size := 12
	while font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x > width and text_size > 9:
		text_size -= 1
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x > width:
		while font.get_string_size(text + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x > width and text.length() > 1:
			text = text.left(text.length() - 1)
		text += "..."
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size)
	var screen := get_global_transform_with_canvas() * position
	screen.x = clampf(screen.x, 10.0, maxf(10.0, get_viewport_rect().size.x - size.x - 16.0))
	screen.y = clampf(screen.y, 22.0, maxf(22.0, get_viewport_rect().size.y - 16.0))
	position = get_global_transform_with_canvas().affine_inverse() * screen
	draw_rect(Rect2(position + Vector2(-6.0, -float(text_size) - 2.0) * scale, (size + Vector2(12.0, 8.0)) * scale), Color("#20333e"))
	draw_set_transform(position, 0.0, Vector2.ONE * scale)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color("#f1f5f5"))
	draw_set_transform(Vector2.ZERO)

func _draw_handle(position: Vector2, color: Color, symbol: String, scale: float) -> void:
	var fill := Color.WHITE.lerp(Color("#20333e"), _night_strength())
	if position.distance_to(hover_pointer) <= 11.0 * scale and not route_active:
		fill = fill.lerp(color, 0.15)
	draw_circle(position, 9.0 * scale, fill)
	draw_arc(position, 9.0 * scale, 0.0, TAU, 24, color, 1.5 * scale, true)
	if symbol == "+":
		draw_line(position - Vector2(4.0, 0.0) * scale, position + Vector2(4.0, 0.0) * scale, color, 1.5 * scale, true)
		draw_line(position - Vector2(0.0, 4.0) * scale, position + Vector2(0.0, 4.0) * scale, color, 1.5 * scale, true)
	elif symbol == "x":
		draw_line(position - Vector2(3.5, 3.5) * scale, position + Vector2(3.5, 3.5) * scale, color, 1.5 * scale, true)
		draw_line(position - Vector2(3.5, -3.5) * scale, position + Vector2(3.5, -3.5) * scale, color, 1.5 * scale, true)
	elif symbol == "diamond":
		draw_polyline(PackedVector2Array([position + Vector2(0.0, -4.0) * scale, position + Vector2(4.0, 0.0) * scale, position + Vector2(0.0, 4.0) * scale, position + Vector2(-4.0, 0.0) * scale, position + Vector2(0.0, -4.0) * scale]), color, 1.5 * scale, true)
	elif symbol == "swap":
		for direction: float in [-1.0, 1.0]:
			var offset := Vector2(0.0, -2.5 * direction)
			draw_line(position + (offset + Vector2(-4.0, 0.0)) * scale, position + (offset + Vector2(4.0, 0.0)) * scale, color, 1.5 * scale, true)
			var tip := position + (offset + Vector2(4.0 * direction, 0.0)) * scale
			draw_polyline(PackedVector2Array([tip + Vector2(-2.0 * direction, -2.0) * scale, tip, tip + Vector2(-2.0 * direction, 2.0) * scale]), color, 1.5 * scale, true)

func _draw_train(metro: Metro, route: Dictionary, color: Color) -> void:
	var points: PackedVector2Array = route["points"]
	var total: float = route["length"]
	if total < 1.0:
		return
	for car in range(1, metro.wagon_count + 1):
		var front := TrackGeometry.point_at_distance(points, fposmod(metro.distance - float(car - 1) * TrackGeometry.CAR_PITCH - 5.2, total))
		var back := TrackGeometry.point_at_distance(points, fposmod(metro.distance - float(car) * TrackGeometry.CAR_PITCH + 5.2, total))
		var normal := (front - back).normalized().orthogonal() * 2.0
		draw_colored_polygon(PackedVector2Array([front + normal, back + normal, back - normal, front - normal]), Color("#344b53"))
		draw_line(front, back, Color("#9aaeb0"), 1.4, view_zoom.x < 1.5)
	for car in range(metro.wagon_count, -1, -1):
		var distance := metro.distance - float(car) * TrackGeometry.CAR_PITCH
		var position := TrackGeometry.point_at_distance(points, fposmod(distance, total))
		var before := TrackGeometry.point_at_distance(points, fposmod(distance - 2.0, total))
		var after := TrackGeometry.point_at_distance(points, fposmod(distance + 2.0, total))
		var angle := (after - before).angle()
		draw_set_transform(position, angle)
		_draw_car(color, car == 0, car == metro.wagon_count)
	draw_set_transform(Vector2.ZERO)

func _draw_headlights(metro: Metro, route: Dictionary) -> void:
	var points: PackedVector2Array = route["points"]
	var total: float = route["length"]
	if total < 1.0:
		return
	var before := TrackGeometry.point_at_distance(points, fposmod(metro.distance - 2.0, total))
	var after := TrackGeometry.point_at_distance(points, fposmod(metro.distance + 2.0, total))
	draw_set_transform(TrackGeometry.point_at_distance(points, metro.distance), (after - before).angle())
	var strength := 0.14 * _night_strength()
	if strength > 0.001:
		for side: float in [-1.0, 1.0]:
			var source := Vector2(5.0, side * 2.0)
			for section in range(24):
				var a := float(section) / 24.0
				var b := float(section + 1) / 24.0
				var width_a := lerpf(2.5, 14.0, a)
				var width_b := lerpf(2.5, 14.0, b)
				var x_a := lerpf(0.0, 50.0, a)
				var x_b := lerpf(0.0, 50.0, b)
				var alpha_a := strength * pow(1.0 - a, 2.0)
				var alpha_b := strength * pow(1.0 - b, 2.0)
				for half: float in [-1.0, 1.0]:
					var vertices := PackedVector2Array([source + Vector2(x_a, 0), source + Vector2(x_b, 0), source + Vector2(x_b, half * width_b), source + Vector2(x_a, half * width_a)])
					draw_polygon(vertices, PackedColorArray([Color(1.0, 0.91, 0.69, alpha_a), Color(1.0, 0.91, 0.69, alpha_b), Color(1.0, 0.91, 0.69, 0.0), Color(1.0, 0.91, 0.69, 0.0)]))
	draw_set_transform(Vector2.ZERO)

func _draw_car(color: Color, locomotive: bool, last_car: bool) -> void:
	var antialias := view_zoom.x < 1.5
	_draw_car_shell(5.9, 3.3, color.darkened(0.48))
	_draw_car_shell(5.55, 2.85, color.lerp(Color("#d7e8e7"), 0.28))
	draw_rect(Rect2(-4.8, -1.5, 9.6, 3.0), color.lerp(Color("#f1f5ee"), 0.67))
	draw_line(Vector2(-4.3, -1.0), Vector2(4.0, -1.0), Color(1.0, 1.0, 1.0, 0.48), 0.25, antialias)
	for window_x: float in [-4.3, -1.5, 1.3]:
		draw_line(Vector2(window_x, -2.25), Vector2(window_x + 1.7, -2.25), Color("#45636d").lerp(Color("#f1d8a2"), _night_strength() * 0.8), 0.6, antialias)
		draw_line(Vector2(window_x, 2.25), Vector2(window_x + 1.7, 2.25), Color("#45636d").lerp(Color("#f1d8a2"), _night_strength() * 0.8), 0.6, antialias)
	if locomotive:
		draw_line(Vector2(4.1, -1.6), Vector2(4.1, 1.6), Color("#344f5c"), 0.8, antialias)
		for side: float in [-1.0, 1.0]:
			draw_circle(Vector2(5.0, side * 1.9), 0.4, Color("#fff3c9"), true, -1.0, antialias)
	elif last_car:
		for side: float in [-1.0, 1.0]:
			draw_circle(Vector2(-5.0, side * 1.9), 0.35, Color("#d84e55"), true, -1.0, antialias)

func _draw_car_shell(half_length: float, half_width: float, color: Color) -> void:
	var bevel := 0.6
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half_length + bevel, -half_width), Vector2(half_length - bevel, -half_width),
		Vector2(half_length, -half_width + bevel), Vector2(half_length, half_width - bevel),
		Vector2(half_length - bevel, half_width), Vector2(-half_length + bevel, half_width),
		Vector2(-half_length, half_width - bevel), Vector2(-half_length, -half_width + bevel)
	]), color)

func _night_strength() -> float:
	return clampf((cos(time_of_day * TAU) + 0.3) / 1.3, 0.0, 1.0)
