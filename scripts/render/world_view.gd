class_name WorldView
extends Node2D

const BACKDROP := preload("res://scripts/render/urban_backdrop.gd")
const CORRIDOR_WIDTH := 28.0
const LANE_EDGE_WIDTH := 8.0
const RUNNING_LANE_WIDTH := 4.0
const PASSENGER_COATS := [Color("#526b79"), Color("#b98260"), Color("#798468"), Color("#8f7180"), Color("#647e83")]

var graph: TransitGraph
var lines: Array[TransitLine] = []
var metros: Array[Metro] = []
var station_visits: Array[StationVisit] = []
var selected_station_id: int = -1
var hovered_station_id: int = -1
var hovered_track_id: int = -1
var hovered_bend_index: int = -1
var route_active := false
var route_source_id := -1
var route_target_id := -1
var route_pins := PackedVector2Array()
var reshape_anchors := PackedVector2Array()
var rail_anchor := Vector2.ZERO
var rail_segment_index := -1
var rail_popup_axis := Vector2.DOWN
var hover_caption := ""
var hover_pointer := Vector2.ZERO
var station_preview_visible := false
var station_preview_position := Vector2.ZERO
var interaction_overlays_visible := true
var connection_hint_station_id := -1
var valid_connection_targets := PackedInt32Array()
var view_center: Vector2 = Vector2.ZERO
var view_zoom: Vector2 = Vector2.ONE
var time_of_day: float = 0.5
var _routes: Dictionary = {}
var _illuminated_paths: Dictionary = {}
var _illumination_strengths: Dictionary = {}
var _rail_halos: Array[Polygon2D] = []
var _track_shadows: Array[PackedVector2Array] = []
var _preview := PackedVector2Array()
var _preview_color := Color.WHITE
var _preview_error := ""
var _preview_hint := ""
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
	_refresh_illumination()
	queue_redraw()

func refresh_geometry() -> void:
	_routes.clear()
	for line: TransitLine in lines:
		_routes[line.id] = TrackGeometry.circuit(graph, line, lines)
	_refresh_illumination()
	queue_redraw()

func set_dynamic_state(train_list: Array[Metro], center: Vector2, zoom: Vector2, phase: float, visits: Array[StationVisit] = []) -> void:
	metros = train_list
	station_visits = visits
	view_center = center
	view_zoom = zoom
	time_of_day = phase
	for halo: Polygon2D in _rail_halos:
		halo.modulate.a = _night_strength()
	if _backdrop != null:
		_backdrop.call("set_view", center, zoom, phase)
	queue_redraw()

func set_stroke_preview(points: PackedVector2Array, color: Color, error: String = "", hint: String = "") -> void:
	_preview = TrackGeometry.round_corners(points)
	_preview_color = color if error.is_empty() else Color("#d45c64")
	_preview_error = error
	_preview_hint = hint
	queue_redraw()

func _draw() -> void:
	if graph == null:
		return
	# The Compatibility renderer's line fringe scales in world units; omit it at close zoom.
	var night := _night_strength()
	_draw_ground_shadows()
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
		if night > 0.001:
			_draw_rail_illumination(line, night)
	_draw_sun_shadows()
	if view_zoom.x > 1.5:
		for visit: StationVisit in station_visits:
			_draw_station_visit(visit)
	for metro: Metro in metros:
		if _routes.has(metro.line_id):
			_draw_headlights(metro, TrackGeometry.route_for_direction(_routes[metro.line_id], metro.travel_direction))
	for metro: Metro in metros:
		if not _routes.has(metro.line_id):
			continue
		_draw_train(metro, TrackGeometry.route_for_direction(_routes[metro.line_id], metro.travel_direction), lines[metro.line_id].color)
	for station: Station in graph.stations:
		_draw_network_station(station)
		if interaction_overlays_visible and station.id == selected_station_id:
			draw_arc(station.position, station_radius(station) + 3.0, 0.0, TAU, 40, Color("#f9c27b"), 1.5, true)
	if interaction_overlays_visible and _preview.size() > 1:
		draw_polyline(_preview, _preview_color, CORRIDOR_WIDTH, view_zoom.x < 1.5)
		for offset: float in [-TrackGeometry.LANE_OFFSET, TrackGeometry.LANE_OFFSET]:
			var lane := TrackGeometry.offset_points(_preview, offset)
			draw_polyline(lane, _preview_color, LANE_EDGE_WIDTH, view_zoom.x < 1.5)
			draw_polyline(lane, _preview_color.darkened(0.3), RUNNING_LANE_WIDTH, view_zoom.x < 1.5)
	if interaction_overlays_visible:
		if station_preview_visible:
			_draw_station(station_preview_position, Color(1.0, 1.0, 1.0, 0.22), Color(Color("#34464f").lerp(Color("#c5dce5"), night), 0.38))
		_draw_gizmos()

func station_handle_position(station: Station, direction: Vector2) -> Vector2:
	return station.position + direction * maxf(station_radius(station) + 12.0, 32.0 / view_zoom.x)

func refresh_illumination() -> void:
	_refresh_illumination()

func _refresh_illumination() -> void:
	_track_shadows.clear()
	for line: TransitLine in lines:
		if not _routes.has(line.id):
			continue
		var centerline: PackedVector2Array = _routes[line.id]["centerline"]
		if centerline.size() >= 2:
			for width: float in [CORRIDOR_WIDTH + 1.0, CORRIDOR_WIDTH + 3.0]:
				_track_shadows.append_array(_halo_polygons(centerline, width))
	for halo: Polygon2D in _rail_halos:
		remove_child(halo)
		halo.queue_free()
	_rail_halos.clear()
	_illuminated_paths.clear()
	_illumination_strengths.clear()
	var junctions: Array[Station] = []
	for station: Station in graph.stations:
		if station_line_colors(station).size() > 1:
			junctions.append(station)
	for line: TransitLine in lines:
		if not _routes.has(line.id):
			continue
		var paths: Array[PackedVector2Array] = []
		for lane: PackedVector2Array in _routes[line.id]["running_paths"]:
			paths.append(lane)
		for station: Station in junctions:
			var mask := PackedVector2Array()
			for index in range(48):
				mask.append(station.position + Vector2.from_angle(TAU * index / 48.0) * (station_radius(station) + 24.0))
			var clipped: Array[PackedVector2Array] = []
			for path: PackedVector2Array in paths:
				clipped.append_array(Geometry2D.clip_polyline_with_polygon(path, mask))
			paths = clipped
		var sampled_paths: Array[PackedVector2Array] = []
		var strengths: Array[PackedFloat32Array] = []
		for path: PackedVector2Array in paths:
			var sampled := PackedVector2Array()
			var alpha := PackedFloat32Array()
			for index in range(path.size()):
				var start := path[maxi(0, index - 1)]
				var steps := maxi(1, ceili(start.distance_to(path[index]) / 4.0)) if not junctions.is_empty() else 1
				for step in range(1, steps + 1):
					var point := start.lerp(path[index], float(step) / steps)
					var strength := 1.0
					for station: Station in junctions:
						var radius := station_radius(station)
						strength = minf(strength, smoothstep(radius + 24.0, radius + 40.0, point.distance_to(station.position)))
					if strength < 1.0 or (not alpha.is_empty() and alpha[alpha.size() - 1] < 1.0) or step == steps:
						sampled.append(point)
						alpha.append(strength)
			sampled_paths.append(sampled)
			strengths.append(alpha)
		_illuminated_paths[line.id] = sampled_paths
		_illumination_strengths[line.id] = strengths
		for index in range(sampled_paths.size()):
			if sampled_paths[index].size() < 2:
				continue
			for width: float in [30.0, 22.0, 14.0]:
				for polygon: PackedVector2Array in _halo_polygons(sampled_paths[index], width):
					var halo := Polygon2D.new()
					halo.polygon = polygon
					halo.antialiased = true
					var colors := PackedColorArray()
					for vertex: Vector2 in polygon:
						var strength := 1.0
						for station: Station in junctions:
							var radius := station_radius(station)
							strength = minf(strength, smoothstep(radius + 24.0, radius + 40.0, vertex.distance_to(station.position)))
						colors.append(Color(line.color, strength * 0.055))
					halo.vertex_colors = colors
					halo.z_index = -1
					halo.modulate.a = _night_strength()
					add_child(halo)
					_rail_halos.append(halo)

static func _halo_polygons(points: PackedVector2Array, width: float) -> Array[PackedVector2Array]:
	var outlines := Geometry2D.offset_polyline(points, width * 0.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
	var pieces: Array[PackedVector2Array] = []
	var holes: Array[PackedVector2Array] = []
	for polygon: PackedVector2Array in outlines:
		if Geometry2D.is_polygon_clockwise(polygon):
			holes.append(polygon)
		else:
			pieces.append(polygon)
	# Split through each hole before subtraction so every result is a simple polygon.
	for hole: PackedVector2Array in holes:
		var bounds := Rect2(hole[0], Vector2.ZERO)
		for point: Vector2 in hole:
			bounds = bounds.expand(point)
		var split := bounds.get_center().x
		var cut: Array[PackedVector2Array] = []
		for piece: PackedVector2Array in pieces:
			var extent := Rect2(piece[0], Vector2.ZERO)
			for point: Vector2 in piece:
				extent = extent.expand(point)
			extent = extent.grow(1.0)
			for limits: Vector2 in [Vector2(extent.position.x, split), Vector2(split, extent.end.x)]:
				var box := PackedVector2Array([Vector2(limits.x, extent.position.y), Vector2(limits.y, extent.position.y), Vector2(limits.y, extent.end.y), Vector2(limits.x, extent.end.y)])
				for half: PackedVector2Array in Geometry2D.intersect_polygons(piece, box):
					cut.append_array(Geometry2D.clip_polygons(half, hole))
		pieces = cut
	for piece: PackedVector2Array in pieces:
		assert(not Geometry2D.triangulate_polygon(piece).is_empty(), "A rail halo must resolve to simple, renderable polygons.")
	return pieces

func _draw_rail_illumination(line: TransitLine, night: float) -> void:
	var paths: Array[PackedVector2Array] = _illuminated_paths[line.id]
	var strengths: Array[PackedFloat32Array] = _illumination_strengths[line.id]
	var color := line.color.lightened(0.55)
	for index in range(paths.size()):
		var colors := PackedColorArray()
		for strength: float in strengths[index]:
			colors.append(Color(color, night * 0.8 * strength))
		draw_polyline_colors(paths[index], colors, 1.2, view_zoom.x < 1.5)

func station_line_colors(station: Station) -> PackedColorArray:
	var colors := PackedColorArray()
	for line: TransitLine in lines:
		if line.stations.has(station.id):
			colors.append(line.color)
	return colors

func station_radius(station: Station) -> float:
	return 10.0 + 2.0 * maxi(1, station_line_colors(station).size())

func _draw_network_station(station: Station) -> void:
	var colors := station_line_colors(station)
	var fill := Color.WHITE.lerp(Color("#e8eff2"), _night_strength())
	if colors.is_empty():
		_draw_station(station.position, fill, Color("#34464f").lerp(Color("#819ca9"), _night_strength()))
		return
	for index in range(colors.size()):
		draw_circle(station.position, 10.0 + 2.0 * (colors.size() - index), colors[index].darkened(0.3))
	draw_circle(station.position, 10.0, fill)

func set_rail_anchor(points: PackedVector2Array, position: Vector2) -> void:
	rail_anchor = TrackGeometry.insertion_point(points, position)
	var best_distance := INF
	for index in range(1, points.size()):
		var closest := Geometry2D.get_closest_point_to_segment(position, points[index - 1], points[index])
		var distance := closest.distance_squared_to(position)
		if distance < best_distance:
			best_distance = distance
			rail_segment_index = index - 1
			var tangent := (points[index] - points[index - 1]).normalized()
			rail_popup_axis = Vector2(-tangent.y, tangent.x)
			if rail_popup_axis.y < -0.01 or (absf(rail_popup_axis.y) < 0.01 and rail_popup_axis.x < 0.0):
				rail_popup_axis = -rail_popup_axis

func rail_delete_position() -> Vector2:
	return rail_anchor - rail_popup_axis * 32.0 / view_zoom.x

func rail_move_position() -> Vector2:
	return rail_anchor + rail_popup_axis * 32.0 / view_zoom.x

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
		for anchor: Vector2 in reshape_anchors:
			draw_circle(anchor, 3.5 * scale, Color.WHITE)
			draw_arc(anchor, 3.5 * scale, 0.0, TAU, 24, ink, 1.5 * scale, true)
		for station_id: int in valid_connection_targets:
			var station := graph.stations[station_id]
			draw_arc(station.position, maxf(station_radius(station) + 5.0, 17.0 * scale), 0.0, TAU, 40, Color(accent, 0.5), 1.5 * scale, true)
		if route_source_id >= 0 and route_source_id < graph.stations.size():
			_draw_network_station(graph.stations[route_source_id])
			_draw_handle(route_flip_position(), ink, "swap", scale)
			if hover_pointer.distance_to(route_flip_position()) <= 11.0 * scale:
				_draw_caption(route_flip_position() + Vector2(-12.0, 28.0) * scale, "Inverser le coude", scale)
		for pin: Vector2 in route_pins:
			_draw_handle(pin, ink, "diamond", scale)
		if _preview.size() > 1:
			var endpoint := _preview[_preview.size() - 1]
			if route_source_id < 0 and not route_pins.is_empty():
				endpoint = route_pins[0]
				draw_dashed_line(hover_pointer, endpoint, Color(ink, 0.35), scale, 4.0 * scale)
			if route_target_id < 0:
				draw_arc(endpoint, 18.0 * scale, 0.0, TAU, 40, _preview_color, 2.0 * scale, true)
				for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
					draw_dashed_line(endpoint - direction * 27.0 * scale, endpoint + direction * 27.0 * scale, Color(ink, 0.35), scale, 4.0 * scale)
			if not _preview_error.is_empty():
				_draw_handle(endpoint + Vector2(26.0, -26.0) * scale, danger, "x", scale)
		if route_target_id >= 0 and route_target_id < graph.stations.size():
			var station := graph.stations[route_target_id]
			_draw_network_station(station)
			draw_arc(station.position, station_radius(station) + 3.0, 0.0, TAU, 40, _preview_color, 1.5 * scale, true)
		var feedback := _preview_error if not _preview_error.is_empty() else _preview_hint
		if not feedback.is_empty() and _preview.size() > 1:
			var anchor := route_pins[0] if route_source_id < 0 and not route_pins.is_empty() else _preview[_preview.size() - 1]
			_draw_caption(anchor + Vector2(32.0, 28.0) * scale, feedback, scale)
		return
	if connection_hint_station_id >= 0 and connection_hint_station_id < graph.stations.size() and hovered_station_id != connection_hint_station_id:
		var station := graph.stations[connection_hint_station_id]
		var anchor := station_handle_position(station, Vector2.RIGHT)
		draw_line(station.position + Vector2(station_radius(station) + 3.0, 0.0), anchor, Color(ink, 0.25), scale, true)
		_draw_handle(anchor, Color(accent, 0.65), "+", scale)
	if hovered_station_id >= 0 and hovered_station_id < graph.stations.size():
		var station := graph.stations[hovered_station_id]
		var anchor := station_handle_position(station, Vector2.RIGHT)
		draw_line(station.position + Vector2(station_radius(station) + 3.0, 0.0), anchor, Color(ink, 0.25), scale, true)
		_draw_handle(anchor, accent, "+", scale)
		_draw_handle(station_handle_position(station, Vector2(1.0, -1.0)), danger, "x", scale)
		draw_arc(station.position, station_radius(station) + 4.0, 0.0, TAU, 40, Color(ink, 0.35), scale, true)
		caption_position = station.position + Vector2(station_radius(station) + 6.0 * scale, station_radius(station) + 18.0 * scale)
	elif hovered_track_id >= 0 and hovered_track_id < graph.tracks.size():
		var points := TrackGeometry.sample(graph, graph.tracks[hovered_track_id])
		draw_polyline(points, Color(accent, 0.45), 2.0 * scale, true)
		var anchors := TrackGeometry.anchors(graph, graph.tracks[hovered_track_id])
		for index in range(1, anchors.size() - 1):
			_draw_handle(anchors[index], ink, "diamond", scale)
		draw_line(rail_anchor, rail_delete_position(), Color(ink, 0.25), scale, true)
		_draw_handle(rail_delete_position(), danger, "x", scale)
		if hovered_bend_index < 0:
			draw_line(rail_anchor, rail_move_position(), Color(ink, 0.25), scale, true)
			_draw_handle(rail_anchor, accent, "+", scale)
			_draw_handle(rail_move_position(), ink, "diamond", scale)
		caption_position = rail_anchor + Vector2(18.0, 54.0) * scale
	if not hover_caption.is_empty():
		_draw_caption(caption_position, hover_caption, scale)

func _draw_caption(position: Vector2, caption: String, scale: float) -> void:
	var paragraph := TextParagraph.new()
	paragraph.width = minf(ThemeDB.fallback_font.get_string_size(tr(caption), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, minf(360.0, get_viewport_rect().size.x - 32.0))
	paragraph.add_string(tr(caption), ThemeDB.fallback_font, 16)
	var size := paragraph.get_size()
	var screen := get_global_transform_with_canvas() * position
	screen.x = clampf(screen.x, 10.0, maxf(10.0, get_viewport_rect().size.x - size.x - 16.0))
	screen.y = clampf(screen.y, 10.0, maxf(10.0, get_viewport_rect().size.y - size.y - 16.0))
	position = get_global_transform_with_canvas().affine_inverse() * screen
	draw_rect(Rect2(position - Vector2(6.0, 4.0) * scale, (size + Vector2(12.0, 8.0)) * scale), Color("#20333e"))
	draw_set_transform(position, 0.0, Vector2.ONE * scale)
	paragraph.draw(get_canvas_item(), Vector2.ZERO, Color("#f1f5f5"))
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

func _draw_station_visit(visit: StationVisit) -> void:
	var alpha := smoothstep(1.5, 3.0, view_zoom.x) * visit.platform_alpha()
	if alpha <= 0.001:
		return
	var visible_area := get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	var night := _night_strength()
	if not visit.platform.is_empty():
		var fill := Color("#d8dfdd").lerp(Color("#33464f"), night)
		fill.a = alpha * 0.96
		draw_colored_polygon(visit.platform, fill)
		var outline := visit.platform.duplicate()
		outline.append(outline[0])
		draw_polyline(outline, Color(Color("#7b8d8c").lerp(Color("#8ba0a7"), night), alpha * 0.6), 0.22, false)
		var seam := Color(Color("#899b99").lerp(Color("#82979e"), night), alpha * 0.28)
		for index in range(0, visit.platform_seams.size(), 2):
			draw_line(visit.platform_seams[index], visit.platform_seams[index + 1], seam, 0.13, false)
		draw_polyline(visit.platform_edge, Color(Color("#647b7b").lerp(Color("#acbfc4"), night), alpha * 0.8), 0.25, false)
		var safety := Color(Color("#ddc798").lerp(Color("#dac9a1"), night), alpha * 0.85)
		draw_polyline(visit.platform_safety_edge, safety, 0.65, false)
		for dot: Vector2 in visit.tactile_dots:
			draw_circle(dot, 0.09, Color(Color("#826d48"), alpha * 0.65), true, -1.0, false)
	for entering: bool in [false, true]:
		var count := visit.boarding if entering else visit.alighting
		for index in range(count):
			var door_index := index % visit.doors.size()
			var door := visit.doors[door_index]
			if not visible_area.grow(30.0).has_point(door):
				continue
			var normal := visit.normals[door_index]
			var position := visit.passenger_position(index, entering)
			var opacity := alpha * visit.passenger_opacity(index, entering)
			if opacity <= 0.001:
				continue
			var coat: Color = PASSENGER_COATS[(index + (1 if entering else 0)) % PASSENGER_COATS.size()].lerp(Color("#c1cfd2"), night * 0.55)
			coat.a = opacity
			draw_circle(position, StationVisit.PASSENGER_RADIUS, coat, true, -1.0, view_zoom.x < 3.0)
			var skin := Color("#dfb993") if index % 3 == 0 else Color("#b68968") if index % 3 == 1 else Color("#ead1b0")
			skin.a = opacity
			draw_circle(position + normal * (0.1 if not entering else -0.1), 0.15, skin, true, -1.0, view_zoom.x < 3.0)

func _draw_train(metro: Metro, route: Dictionary, color: Color) -> void:
	var points: PackedVector2Array = route["points"]
	var total: float = route["length"]
	if total < 1.0:
		return
	for car in range(1, metro.wagon_count + 1):
		draw_set_transform(Vector2.ZERO)

		var edges := _gangway_edges(points, total, metro.distance, car)
		# A compressed connector can fold across itself on a tight bend.
		for triangle: PackedVector2Array in [PackedVector2Array([edges[0], edges[1], edges[2]]), PackedVector2Array([edges[0], edges[2], edges[3]])]:
			if absf((triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])) > 0.0001:
				draw_colored_polygon(triangle, Color("#344b53"))
		if view_zoom.x > 1.5:
			var detail := smoothstep(1.5, 3.0, view_zoom.x)
			for fold in range(1, 5):
				var fraction := float(fold) / 5.0
				draw_line(edges[0].lerp(edges[1], fraction), edges[3].lerp(edges[2], fraction), Color(0.58, 0.65, 0.66, detail * 0.65), 0.22, false)
	for car in range(metro.wagon_count, -1, -1):
		var distance := metro.distance - float(car) * TrackGeometry.CAR_PITCH
		var position := TrackGeometry.point_at_distance(points, fposmod(distance, total))
		var angle := TrackGeometry.car_axis(points, total, distance, metro.distance).angle()
		draw_set_transform(position, angle, Vector2(TrackGeometry.CAR_SCALE, 1.0))
		_draw_car(color, car == 0, car == metro.wagon_count, metro.at_station and metro.visit != null and metro.visit.elapsed >= metro.visit.opening_duration)
	draw_set_transform(Vector2.ZERO)

func _draw_ground_shadows() -> void:
	var opacity := BACKDROP.shadow_opacity(time_of_day)
	if opacity < 0.001:
		return
	var offset := BACKDROP.shadow_offset(time_of_day)
	var color := Color(0.12, 0.17, 0.23, opacity * 0.5)
	draw_set_transform(offset * 0.45)
	for polygon: PackedVector2Array in _track_shadows:
		draw_colored_polygon(polygon, Color(color, opacity * 0.36))
	draw_set_transform(Vector2.ZERO)

func _draw_sun_shadows() -> void:
	var opacity := BACKDROP.shadow_opacity(time_of_day)
	if opacity < 0.001:
		return
	var offset := BACKDROP.shadow_offset(time_of_day)
	var color := Color(0.12, 0.17, 0.23, opacity * 0.5)
	for metro: Metro in metros:
		if not _routes.has(metro.line_id):
			continue
		var route := TrackGeometry.route_for_direction(_routes[metro.line_id], metro.travel_direction)
		var points: PackedVector2Array = route["points"]
		var total: float = route["length"]
		if total < 1.0:
			continue
		for car in range(metro.wagon_count + 1):
			var distance := metro.distance - car * TrackGeometry.CAR_PITCH
			var position := TrackGeometry.point_at_distance(points, fposmod(distance, total))
			var angle := TrackGeometry.car_axis(points, total, distance, metro.distance).angle()
			draw_set_transform(position + offset * 0.65, angle, Vector2(TrackGeometry.CAR_SCALE, 1.0))
			for spread: float in [0.15, 0.45]:
				_draw_car_shell(5.9 + spread, 3.3 + spread, color, 1 if car == 0 else (-1 if car == metro.wagon_count else 0))
	draw_set_transform(Vector2.ZERO)

func _gangway_edges(points: PackedVector2Array, total: float, distance: float, car: int) -> PackedVector2Array:
	var front_distance := distance - float(car - 1) * TrackGeometry.CAR_PITCH
	var back_distance := distance - float(car) * TrackGeometry.CAR_PITCH
	var front_axis := TrackGeometry.car_axis(points, total, front_distance, distance)
	var back_axis := TrackGeometry.car_axis(points, total, back_distance, distance)
	var front := TrackGeometry.point_at_distance(points, fposmod(front_distance, total)) - front_axis * 5.2 * TrackGeometry.CAR_SCALE
	var back := TrackGeometry.point_at_distance(points, fposmod(back_distance, total)) + back_axis * 5.2 * TrackGeometry.CAR_SCALE
	var front_normal := front_axis.orthogonal() * 2.0
	var back_normal := back_axis.orthogonal() * 2.0
	return PackedVector2Array([front + front_normal, back + back_normal, back - back_normal, front - front_normal])

func _draw_headlights(metro: Metro, route: Dictionary) -> void:
	var points: PackedVector2Array = route["points"]
	var total: float = route["length"]
	if total < 1.0:
		return
	draw_set_transform(TrackGeometry.point_at_distance(points, metro.distance), TrackGeometry.car_axis(points, total, metro.distance, metro.distance).angle())
	var strength := 0.42 * _night_strength()
	if strength > 0.001:
		for side: float in [-1.0, 1.0]:
			var source := Vector2(5.0 * TrackGeometry.CAR_SCALE, side * 2.0)
			for radius: float in [5.0, 3.5, 2.0]:
				draw_circle(source, radius, Color(1.0, 0.91, 0.69, strength * 0.22), true, -1.0, true)
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

func _draw_car(color: Color, leading_cab: bool, trailing_cab: bool, doors_open: bool = false) -> void:
	var antialias := view_zoom.x < 1.5
	var cab_end := 1 if leading_cab else (-1 if trailing_cab else 0)
	var detail := smoothstep(1.5, 3.0, view_zoom.x)
	var fine_detail := smoothstep(3.0, 4.5, view_zoom.x)
	_draw_car_shell(5.9, 3.3, color.darkened(0.48), cab_end)
	_draw_car_shell(5.55, 2.85, color, cab_end)
	var roof_start := -3.35 if trailing_cab else -4.8
	var roof_end := 3.35 if leading_cab else 4.8
	draw_rect(Rect2(roof_start, -1.75, roof_end - roof_start, 3.5), Color("#dde3e2"))
	if detail > 0.0:
		var glazing := Color("#45636d").lerp(Color("#f1d8a2"), _night_strength() * 0.8)
		glazing.a = detail
		for side: float in [-1.0, 1.0]:
			for window_x: float in [-3.6, -0.7, 2.2]:
				if (leading_cab and window_x > 2.0) or (trailing_cab and window_x < -3.0):
					continue
				draw_line(Vector2(window_x, side * 2.3), Vector2(window_x + 1.4, side * 2.3), glazing, 0.6, antialias)
			for door_x: float in [-1.75, 1.15]:
				var door := Color(0.78, 0.84, 0.84, detail)
				draw_rect(Rect2(door_x - 0.5, side * 2.3 - 0.35, 1.0, 0.7), door)
				if doors_open and side > 0.0:
					draw_rect(Rect2(door_x - 0.28, side * 2.3 - 0.35, 0.56, 0.7), Color(0.25, 0.34, 0.37, detail))
				else:
					draw_line(Vector2(door_x, side * 2.3 - 0.35), Vector2(door_x, side * 2.3 + 0.35), Color(0.25, 0.34, 0.37, fine_detail), 0.18, false)
		for equipment_x: float in [-1.9, 1.5]:
			draw_rect(Rect2(equipment_x - 0.65, -0.85, 1.3, 1.7), Color(0.63, 0.69, 0.70, detail))
			for slat in range(3):
				var x := equipment_x - 0.4 + slat * 0.4
				draw_line(Vector2(x, -0.6), Vector2(x, 0.6), Color(0.36, 0.43, 0.45, fine_detail), 0.18, false)
		draw_line(Vector2(0.0, -1.65), Vector2(0.0, 1.65), Color(0.57, 0.64, 0.65, fine_detail * 0.5), 0.18, false)
		draw_line(Vector2(roof_start + 0.3, -1.35), Vector2(roof_end - 0.3, -1.35), Color(1.0, 1.0, 1.0, detail * 0.55), 0.25, false)
	if cab_end != 0:
		draw_colored_polygon(PackedVector2Array([Vector2(cab_end * 3.5, -1.75), Vector2(cab_end * 4.55, -1.35), Vector2(cab_end * 4.55, 1.35), Vector2(cab_end * 3.5, 1.75)]), Color("#344f5c"))
		for side: float in [-1.0, 1.0]:
			draw_circle(Vector2(cab_end * 5.0, side * 1.9), 0.4, Color("#fff3c9") if leading_cab else Color("#d84e55"), true, -1.0, antialias)

func _draw_car_shell(half_length: float, half_width: float, color: Color, cab_end: int = 0) -> void:
	var left_bevel := 1.2 if cab_end < 0 else 0.6
	var right_bevel := 1.2 if cab_end > 0 else 0.6
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half_length + left_bevel, -half_width), Vector2(half_length - right_bevel, -half_width),
		Vector2(half_length, -half_width + right_bevel), Vector2(half_length, half_width - right_bevel),
		Vector2(half_length - right_bevel, half_width), Vector2(-half_length + left_bevel, half_width),
		Vector2(-half_length, half_width - left_bevel), Vector2(-half_length, -half_width + left_bevel)
	]), color)

func _night_strength() -> float:
	return clampf((cos(time_of_day * TAU) + 0.3) / 1.3, 0.0, 1.0)
