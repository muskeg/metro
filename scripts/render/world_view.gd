class_name WorldView
extends Node2D

const BACKDROP := preload("res://scripts/render/urban_backdrop.gd")
const STATIC_TRACK_LAYER := preload("res://scripts/render/static_track_layer.gd")
const RAIL_ILLUMINATION_LAYER := preload("res://scripts/render/rail_illumination_layer.gd")
const RAIL_HALO_SHADER := preload("res://scripts/render/rail_halo.gdshader")
const MOTION_ANTIALIASING := preload("res://scripts/render/motion_antialiasing.gdshader")
const CORRIDOR_WIDTH := 28.0
# Headlight reach (cab offset + 50-unit beam + 14 width) plus shadow offset, rounded up.
const TRAIN_DRAW_MARGIN := 96.0
const LANE_EDGE_WIDTH := 8.0
const RUNNING_LANE_WIDTH := 4.0
const OVERVIEW_TRAIN_ZOOM := 0.8
const OVERVIEW_BLEND_START := 0.5
const OVERVIEW_TRAIN_WIDTH := 1.5
const TRAIL_LIFETIME := 1.0
const PASSENGER_COATS := [Color("#526b79"), Color("#b98260"), Color("#798468"), Color("#8f7180"), Color("#647e83")]

class TrainTrail:
	var times := PackedFloat64Array()
	var distances := PackedFloat64Array()
	var direction := 1
	var head := 0.0

var graph: TransitGraph
var lines: Array[TransitLine] = []
var metros: Array[Metro] = []
var station_visits: Array[StationVisit] = []
var selected_station_id: int = -1
var selected_track_id := -1
var touch_controls := false
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
var _rail_halos: Array[MeshInstance2D] = []
var _rail_halos_by_line: Dictionary = {}
var _rail_halo_polygons: Array[PackedVector2Array] = []
var _rail_halo_material: ShaderMaterial
var _track_shadows: Array[PackedVector2Array] = []
var _track_shadow_meshes: Array[Mesh] = []
var _shape_meshes: Dictionary = {}
var _beams: Array = []
var _beam_strength := -1.0
var _visible_world := Rect2()
var _shape_polygons: Dictionary = {}
var _shape_indices: Dictionary = {}
var _preview := PackedVector2Array()
var _preview_color := Color.WHITE
var _preview_error := ""
var _preview_hint := ""
var _backdrop: Node2D
var _static_tracks: StaticTrackLayer
var _rail_illumination: RailIlluminationLayer
var _train_layers: Dictionary[int, Node2D] = {}
var _overview_layers: Dictionary[int, Node2D] = {}
var _train_trails: Dictionary[int, TrainTrail] = {}
var _trail_clock := 0.0
var _motion_antialiasing: CanvasLayer

func _ready() -> void:
	_backdrop = BACKDROP.new()
	_backdrop.z_index = -10
	add_child(_backdrop)
	_static_tracks = STATIC_TRACK_LAYER.new()
	_static_tracks.show_behind_parent = true
	add_child(_static_tracks)
	_static_tracks.set_network(lines, _routes)
	_refresh_train_layers()
	_static_tracks.set_shadows(_track_shadow_meshes, _track_shadows)
	_static_tracks.set_shadow_state(BACKDROP.shadow_opacity(time_of_day), BACKDROP.shadow_offset(time_of_day))
	if graph != null:
		_refresh_illumination()

func set_network(transit_graph: TransitGraph, transit_lines: Array[TransitLine], route_data: Dictionary = {}) -> void:
	_train_trails.clear()
	graph = transit_graph
	lines = transit_lines
	_routes = route_data
	if _routes.is_empty():
		var corridors := TrackGeometry.corridor_layout(graph, lines)
		for line: TransitLine in lines:
			_routes[line.id] = TrackGeometry.circuit(graph, line, lines, corridors)
	if _static_tracks != null:
		_static_tracks.set_network(lines, _routes)
		_refresh_train_layers()
	_refresh_illumination()
	queue_redraw()

func refresh_geometry() -> void:
	_train_trails.clear()
	_routes.clear()
	var corridors := TrackGeometry.corridor_layout(graph, lines)
	for line: TransitLine in lines:
		_routes[line.id] = TrackGeometry.circuit(graph, line, lines, corridors)
	if _static_tracks != null:
		_static_tracks.set_network(lines, _routes)
		_refresh_train_layers()
	_refresh_illumination()
	queue_redraw()

func set_dynamic_state(train_list: Array[Metro], center: Vector2, zoom: Vector2, phase: float, visits: Array[StationVisit] = [], delta: float = 0.0) -> void:
	metros = train_list
	_update_train_trails(delta)
	station_visits = visits
	view_center = center
	view_zoom = zoom
	time_of_day = phase
	for halo: MeshInstance2D in _rail_halos:
		halo.modulate.a = _night_strength()
	if _rail_illumination != null:
		_rail_illumination.set_night_strength(_night_strength())
		_rail_illumination.set_antialiased(view_zoom.x < 1.5)
	if _static_tracks != null:
		_static_tracks.set_antialiased(view_zoom.x < 1.5)
		_static_tracks.set_shadow_state(BACKDROP.shadow_opacity(phase), BACKDROP.shadow_offset(phase))
	if _backdrop != null:
		_backdrop.call("set_view", center, zoom, phase)
	queue_redraw()

func _refresh_train_layers() -> void:
	for layer: Node2D in _overview_layers.values():
		layer.get_parent().remove_child(layer)
		layer.queue_free()
	_overview_layers.clear()
	for layer: Node2D in _train_layers.values():
		if is_instance_valid(layer):
			layer.get_parent().remove_child(layer)
			layer.queue_free()
	_train_layers.clear()
	for line: TransitLine in lines:
		var layer := Node2D.new()
		layer.draw.connect(_draw_line_trains.bind(layer, line))
		_static_tracks.line_layer(line.id).add_child(layer)
		_train_layers[line.id] = layer
		var overview := Node2D.new()
		overview.draw.connect(_draw_line_overviews.bind(overview, line))
		_static_tracks.line_layer(line.id).add_child(overview)
		_overview_layers[line.id] = overview

func overview_opacity(zoom: float) -> float:
	return 1.0 - smoothstep(OVERVIEW_BLEND_START, OVERVIEW_TRAIN_ZOOM, zoom)

func _update_train_trails(delta: float) -> void:
	_trail_clock += maxf(delta, 0.0)
	var active: Dictionary = {}
	for train: Metro in metros:
		var id := train.get_instance_id()
		active[id] = true
		if not _routes.has(train.line_id):
			continue
		var route := TrackGeometry.route_for_direction(_routes[train.line_id], train.travel_direction)
		var total: float = route["length"]
		if total < 1.0:
			continue
		var head := fposmod(train.render_distance if train.render_pose_valid else train.distance, total)
		var trail: TrainTrail = _train_trails.get(id)
		var advance := 0.0 if trail == null else fposmod(head - trail.head, total)
		# Cab reversal jumps the logical head forward; it is not travelled track.
		var reversed := trail != null and route.has("terminal_insets") and (head < float(route["outbound_end"])) != (trail.head < float(route["outbound_end"]))
		if trail == null or trail.direction != train.travel_direction or reversed or advance > total * 0.5:
			trail = TrainTrail.new()
			trail.direction = train.travel_direction
			trail.times.append(_trail_clock)
			trail.distances.append(head)
			_train_trails[id] = trail
		elif advance > 0.000001:
			var distance := trail.distances[trail.distances.size() - 1] + advance
			if trail.times[trail.times.size() - 1] < _trail_clock - delta - 0.000001:
				trail.times.append(_trail_clock - delta)
				trail.distances.append(trail.distances[trail.distances.size() - 1])
			if trail.times.size() > 1 and _trail_clock - trail.times[trail.times.size() - 2] < 1.0 / 30.0:
				trail.times[trail.times.size() - 1] = _trail_clock
				trail.distances[trail.distances.size() - 1] = distance
			else:
				trail.times.append(_trail_clock)
				trail.distances.append(distance)
		trail.head = head
		while trail.times.size() > 1 and trail.times[1] < _trail_clock - TRAIL_LIFETIME:
			trail.times.remove_at(0)
			trail.distances.remove_at(0)
	for id: int in _train_trails.keys():
		if not active.has(id):
			_train_trails.erase(id)

func _draw_line_overviews(layer: Node2D, line: TransitLine) -> void:
	if not _routes.has(line.id) or overview_opacity(view_zoom.x) <= 0.0:
		return
	for train: Metro in metros:
		if train.line_id != line.id:
			continue
		var route := TrackGeometry.route_for_direction(_routes[line.id], train.travel_direction)
		var poses := _build_train_poses(train, route)
		if poses.has("overview_path") and _poses_visible(poses):
			_draw_overview_train(poses["overview_path"], layer)

func set_stroke_preview(points: PackedVector2Array, color: Color, error: String = "", hint: String = "") -> void:
	_preview = TrackGeometry.round_corners(points)
	_preview_color = color if error.is_empty() else Color("#d45c64")
	_preview_error = error
	_preview_hint = hint
	queue_redraw()

func set_motion_antialiasing(enabled: bool) -> void:
	if _motion_antialiasing == null:
		if not enabled:
			return
		_motion_antialiasing = CanvasLayer.new()
		_motion_antialiasing.layer = 1
		add_child(_motion_antialiasing)
		var surface := ColorRect.new()
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var shader_material := ShaderMaterial.new()
		shader_material.shader = MOTION_ANTIALIASING
		surface.material = shader_material
		_motion_antialiasing.add_child(surface)
	_motion_antialiasing.visible = enabled

func _draw() -> void:
	if graph == null:
		return
	for layer: Node2D in _train_layers.values():
		layer.modulate.a = 1.0 - overview_opacity(view_zoom.x)
		layer.queue_redraw()
	for layer: Node2D in _overview_layers.values():
		layer.modulate.a = overview_opacity(view_zoom.x)
		layer.queue_redraw()
	# The Compatibility renderer's line fringe scales in world units; omit it at close zoom.
	var night := _night_strength()
	_visible_world = get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	for station: Station in graph.stations:
		_draw_network_station(station)
		if interaction_overlays_visible and station.id == selected_station_id:
			var radius := maxf(station_radius(station) + 3.0, 20.0 / view_zoom.x) if touch_controls else station_radius(station) + 3.0
			draw_arc(station.position, radius, 0.0, TAU, 40, Color("#f9c27b"), 1.5 / view_zoom.x if touch_controls else 1.5, true)
	if interaction_overlays_visible and selected_track_id >= 0 and selected_track_id < graph.tracks.size():
		draw_polyline(TrackGeometry.sample(graph, graph.tracks[selected_track_id]), Color("#f9c27b"), 2.0 / view_zoom.x, true)
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

func _draw_line_trains(layer: Node2D, line: TransitLine) -> void:
	if graph == null or not _routes.has(line.id) or overview_opacity(view_zoom.x) >= 1.0:
		return
	_visible_world = get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	var train_poses: Dictionary = {}
	for metro: Metro in metros:
		if metro.line_id == line.id:
			var route := TrackGeometry.route_for_direction(_routes[line.id], metro.travel_direction)
			var poses := _build_train_poses(metro, route)
			if _poses_visible(poses):
				train_poses[metro.get_instance_id()] = poses
	_draw_sun_shadows(train_poses, layer)
	if view_zoom.x > 1.5:
		for visit: StationVisit in station_visits:
			if visit.line_id == line.id:
				_draw_station_visit(visit, layer)
	for metro: Metro in metros:
		if train_poses.has(metro.get_instance_id()):
			_draw_headlights(train_poses[metro.get_instance_id()], layer)
	for metro: Metro in metros:
		if train_poses.has(metro.get_instance_id()):
			_draw_train(metro, line.color, train_poses[metro.get_instance_id()], layer)

func _build_train_poses(metro: Metro, route: Dictionary) -> Dictionary:
	var positions := PackedVector2Array()
	var axes := PackedVector2Array()
	var total: float = route["length"]
	if total < 1.0:
		return {"positions": positions, "axes": axes}
	var points: PackedVector2Array = route["points"]
	var cumulative: PackedFloat64Array = route["cumulative_lengths"]
	var head_distance := metro.render_distance if metro.render_pose_valid else metro.distance
	for car in range(metro.wagon_count + 1):
		var distance := head_distance - float(car) * TrackGeometry.CAR_PITCH
		positions.append(TrackGeometry.point_at_distance(points, fposmod(distance, total), cumulative))
		axes.append(TrackGeometry.car_axis(points, total, distance, head_distance, cumulative))
	var poses := {"positions": positions, "axes": axes}
	if view_zoom.x < OVERVIEW_TRAIN_ZOOM:
		var trail := overview_train_trail(metro, route, view_zoom.x)
		poses["overview_path"] = trail["path"]
	return poses

func overview_train_path(metro: Metro, route: Dictionary, zoom: float) -> PackedVector2Array:
	return overview_train_trail(metro, route, zoom)["path"]

func overview_train_trail(metro: Metro, route: Dictionary, _zoom: float) -> Dictionary:
	var points: PackedVector2Array = route["points"]
	var cumulative: PackedFloat64Array = route["cumulative_lengths"]
	var total: float = route["length"]
	var head := fposmod(metro.render_distance if metro.render_pose_valid else metro.distance, total)
	var trail: TrainTrail = _train_trails.get(metro.get_instance_id())
	if trail == null or trail.times.size() < 2 or trail.times[trail.times.size() - 1] <= _trail_clock - TRAIL_LIFETIME:
		return {"path": PackedVector2Array([TrackGeometry.point_at_distance(points, head, cumulative)]), "ages": PackedFloat64Array([0.0])}
	var oldest := trail.distances[0]
	if trail.times[0] < _trail_clock - TRAIL_LIFETIME:
		oldest = lerpf(oldest, trail.distances[1], inverse_lerp(trail.times[0], trail.times[1], _trail_clock - TRAIL_LIFETIME))
	var latest := trail.distances[trail.distances.size() - 1]
	var maximum_length := minf(TrackGeometry.train_length(metro.wagon_count) * 1.5, total)
	var idle := _trail_clock - trail.times[trail.times.size() - 1]
	var length := minf(maximum_length * (1.0 - smoothstep(0.0, TRAIL_LIFETIME, idle)), latest - oldest)
	var marks := PackedFloat64Array()
	for step in range(41):
		marks.append(head - length + length * float(step) / 40.0)
	# Include route vertices so even a short bend cannot be cut by a screen-sized sample.
	for vertex_distance: float in cumulative:
		var behind := fposmod(head - vertex_distance, total)
		if behind > 0.0 and behind < length:
			marks.append(head - behind)
	marks.sort()
	var path := PackedVector2Array()
	var ages := PackedFloat64Array()
	var sample := 1
	for mark: float in marks:
		var point := TrackGeometry.point_at_distance(points, fposmod(mark, total), cumulative)
		if path.is_empty() or point.distance_squared_to(path[path.size() - 1]) > 0.000001:
			path.append(point)
			var distance := latest - (head - mark)
			while sample < trail.distances.size() - 1 and trail.distances[sample] <= distance:
				sample += 1
			var span := trail.distances[sample] - trail.distances[sample - 1]
			var fraction := (distance - trail.distances[sample - 1]) / span if span > 0.000001 else 1.0
			ages.append(_trail_clock - lerpf(trail.times[sample - 1], trail.times[sample], clampf(fraction, 0.0, 1.0)))
	return {"path": path, "ages": ages}

# Include the comet even when its real cars lie outside the viewport.
func _poses_visible(poses: Dictionary) -> bool:
	var positions: PackedVector2Array = poses["positions"]
	if positions.is_empty():
		return true
	var bounds := Rect2(positions[0], Vector2.ZERO)
	for position: Vector2 in positions:
		bounds = bounds.expand(position)
	if poses.has("overview_path"):
		for point: Vector2 in poses["overview_path"]:
			bounds = bounds.expand(point)
	return bounds.grow(maxf(TRAIN_DRAW_MARGIN, 5.0 / view_zoom.x)).intersects(_visible_world)

func station_handle_position(station: Station, direction: Vector2) -> Vector2:
	return station.position + direction * maxf(station_radius(station) + 12.0, 32.0 / view_zoom.x)

func refresh_illumination() -> void:
	_refresh_illumination()

func refresh_line_color(line_id: int) -> void:
	_static_tracks.set_network(lines, _routes)
	if _rail_illumination != null:
		for line: TransitLine in lines:
			if line_id < 0 or line.id == line_id:
				_rail_illumination.set_line_color(line.id, line.color)
	for line: TransitLine in lines:
		if line_id >= 0 and line.id != line_id:
			continue
		for halo: MeshInstance2D in _rail_halos_by_line.get(line.id, []):
			var arrays := halo.mesh.surface_get_arrays(0)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for index in range(colors.size()):
				colors[index] = Color(line.color, colors[index].a)
			arrays[Mesh.ARRAY_COLOR] = colors
			var updated_mesh := ArrayMesh.new()
			updated_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			halo.mesh = updated_mesh

func _refresh_illumination() -> void:
	_track_shadows.clear()
	_track_shadow_meshes.clear()
	for line: TransitLine in lines:
		if not _routes.has(line.id):
			continue
		var centerline: PackedVector2Array = _routes[line.id]["centerline"]
		if centerline.size() >= 2:
			for width: float in [CORRIDOR_WIDTH + 1.0, CORRIDOR_WIDTH + 3.0]:
				_track_shadows.append_array(_halo_polygons(centerline, width))
	for polygon: PackedVector2Array in _track_shadows:
		_track_shadow_meshes.append(_polygon_mesh(polygon))
	if _static_tracks != null:
		_static_tracks.set_shadows(_track_shadow_meshes, _track_shadows)
	for halo: MeshInstance2D in _rail_halos:
		remove_child(halo)
		halo.queue_free()
	_rail_halos.clear()
	_rail_halos_by_line.clear()
	_rail_halo_polygons.clear()
	_illuminated_paths.clear()
	_illumination_strengths.clear()
	var junctions: Array[Station] = []
	var junction_cells: Dictionary = {}
	for station: Station in graph.stations:
		if station_line_colors(station).size() > 1:
			junctions.append(station)
			var radius := station_radius(station)
			var reach := radius + 40.0
			var first := Vector2i(((station.position - Vector2.ONE * reach) / 256.0).floor())
			var last := Vector2i(((station.position + Vector2.ONE * reach) / 256.0).floor())
			for x in range(first.x, last.x + 1):
				for y in range(first.y, last.y + 1):
					var cell := Vector2i(x, y)
					if not junction_cells.has(cell):
						junction_cells[cell] = []
					junction_cells[cell].append({"position": station.position, "radius": radius})
	for line: TransitLine in lines:
		if not _routes.has(line.id):
			continue
		_rail_halos_by_line[line.id] = []
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
					var strength := _junction_strength(point, junction_cells)
					if strength < 1.0 or (not alpha.is_empty() and alpha[alpha.size() - 1] < 1.0) or step == steps:
						sampled.append(point)
						alpha.append(strength)
			sampled_paths.append(sampled)
			strengths.append(alpha)
		_illuminated_paths[line.id] = sampled_paths
		_illumination_strengths[line.id] = strengths
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		for index in range(sampled_paths.size()):
			if sampled_paths[index].size() < 2:
				continue
			for width: float in [30.0, 22.0, 14.0]:
				for polygon: PackedVector2Array in _halo_polygons(sampled_paths[index], width):
					var triangle_indices := Geometry2D.triangulate_polygon(polygon)
					var base := vertices.size()
					for vertex: Vector2 in polygon:
						vertices.append(Vector3(vertex.x, vertex.y, 0.0))
						var strength := _junction_strength(vertex, junction_cells)
						colors.append(Color(line.color, strength * 0.055))
						uvs.append(Vector2(-1.0, 0.0))
					for vertex_index: int in triangle_indices:
						indices.append(base + vertex_index)
					var clockwise := Geometry2D.is_polygon_clockwise(polygon)
					for vertex_index in range(polygon.size()):
						var start := polygon[vertex_index]
						var finish := polygon[(vertex_index + 1) % polygon.size()]
						var edge := finish - start
						var outward := Vector2(-edge.y, edge.x) if clockwise else Vector2(edge.y, -edge.x)
						outward = outward.normalized() * 12.0
						var fringe_base := vertices.size()
						for fringe_vertex: Vector2 in [start, finish, finish + outward, start + outward]:
							vertices.append(Vector3(fringe_vertex.x, fringe_vertex.y, 0.0))
						colors.append_array(PackedColorArray([
							colors[base + vertex_index],
							colors[base + (vertex_index + 1) % polygon.size()],
							Color(line.color, 0.0),
							Color(line.color, 0.0)
						]))
						uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2(12.0, 0.0), Vector2(12.0, 0.0)]))
						indices.append_array(PackedInt32Array([fringe_base, fringe_base + 1, fringe_base + 2, fringe_base, fringe_base + 2, fringe_base + 3]))
					_rail_halo_polygons.append(polygon)
		if not indices.is_empty():
			var mesh_arrays := []
			mesh_arrays.resize(Mesh.ARRAY_MAX)
			mesh_arrays[Mesh.ARRAY_VERTEX] = vertices
			mesh_arrays[Mesh.ARRAY_COLOR] = colors
			mesh_arrays[Mesh.ARRAY_TEX_UV] = uvs
			mesh_arrays[Mesh.ARRAY_INDEX] = indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
			var halo := MeshInstance2D.new()
			halo.mesh = mesh
			halo.z_index = -1
			halo.modulate.a = _night_strength()
			if _rail_halo_material == null:
				_rail_halo_material = ShaderMaterial.new()
				_rail_halo_material.shader = RAIL_HALO_SHADER
			halo.material = _rail_halo_material
			add_child(halo)
			_rail_halos.append(halo)
			_rail_halos_by_line[line.id].append(halo)
	if _rail_illumination == null:
		_rail_illumination = RAIL_ILLUMINATION_LAYER.new()
		_rail_illumination.show_behind_parent = true
		add_child(_rail_illumination)
	else:
		move_child(_rail_illumination, get_child_count() - 1)
	_rail_illumination.set_network(lines, _illuminated_paths, _illumination_strengths, _static_tracks)
	_rail_illumination.set_night_strength(_night_strength())
	_rail_illumination.set_antialiased(view_zoom.x < 1.5)

func _junction_strength(point: Vector2, cells: Dictionary) -> float:
	var strength := 1.0
	var cell := Vector2i((point / 256.0).floor())
	for junction: Dictionary in cells.get(cell, []):
		var radius: float = junction["radius"]
		strength = minf(strength, smoothstep(radius + 24.0, radius + 40.0, point.distance_to(junction["position"])))
	return strength

static func _halo_polygons(points: PackedVector2Array, width: float) -> Array[PackedVector2Array]:
	var outlines := Geometry2D.offset_polyline(points, width * 0.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
	var pieces: Array[PackedVector2Array] = []
	var holes: Array[PackedVector2Array] = []
	for outline: PackedVector2Array in outlines:
		for polygon: PackedVector2Array in _polygon_loops(outline):
			if Geometry2D.is_polygon_clockwise(polygon):
				holes.append(polygon)
			else:
				pieces.append(polygon)
	# Split through each hole before subtraction so every result is a simple polygon.
	while not holes.is_empty():
		var hole: PackedVector2Array = holes.pop_back()
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
					for clipped: PackedVector2Array in Geometry2D.clip_polygons(half, hole):
						for polygon: PackedVector2Array in _polygon_loops(clipped):
							if Geometry2D.is_polygon_clockwise(polygon):
								holes.append(polygon)
							else:
								cut.append(polygon)
		pieces = cut
	for piece: PackedVector2Array in pieces:
		assert(not Geometry2D.triangulate_polygon(piece).is_empty(), "A rail halo must resolve to simple, renderable polygons.")
	return pieces

static func _polygon_loops(polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	# Clipper can join contours at a repeated vertex; Godot cannot triangulate that pinch.
	var pending: Array[PackedVector2Array] = [polygon]
	var loops: Array[PackedVector2Array] = []
	while not pending.is_empty():
		var contour: PackedVector2Array = pending.pop_back()
		var seen: Dictionary = {}
		var split := false
		for index in range(contour.size()):
			if seen.has(contour[index]):
				var first: int = seen[contour[index]]
				pending.append(contour.slice(first, index))
				var remainder := contour.slice(0, first)
				remainder.append_array(contour.slice(index))
				pending.append(remainder)
				split = true
				break
			seen[contour[index]] = index
		if not split and contour.size() >= 3:
			loops.append(contour)
	return loops

func station_line_colors(station: Station) -> PackedColorArray:
	var colors := PackedColorArray()
	for line: TransitLine in lines:
		if line.stations.has(station.id):
			colors.append(line.color)
	return colors

func station_radius(station: Station) -> float:
	return TrackGeometry.station_radius(station_line_colors(station).size())

func _draw_network_station(station: Station) -> void:
	var colors := station_line_colors(station)
	var fill := Color.WHITE.lerp(Color("#e8eff2"), _night_strength())
	if colors.is_empty():
		_draw_station(station.position, fill, Color("#34464f").lerp(Color("#819ca9"), _night_strength()))
		return
	var center_radius := TrackGeometry.station_center_radius(colors.size())
	for index in range(colors.size()):
		draw_circle(station.position, center_radius + 2.0 * (colors.size() - index), colors[index].darkened(0.3))
	draw_circle(station.position, center_radius, fill)

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
			if not touch_controls:
				_draw_handle(route_flip_position(), ink, "swap", scale)
			if not touch_controls and hover_pointer.distance_to(route_flip_position()) <= 11.0 * scale:
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
	if touch_controls:
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
	var caption := tr(hover_caption)
	if hovered_station_id >= 0 and hovered_station_id < graph.stations.size() and not graph.stations[hovered_station_id].display_name.is_empty():
		caption = graph.stations[hovered_station_id].display_name + ("\n" + caption if not caption.is_empty() else "")
	if not caption.is_empty():
		_draw_caption(caption_position, caption, scale, false)

func _draw_caption(position: Vector2, caption: String, scale: float, translate: bool = true) -> void:
	var text := tr(caption) if translate else caption
	var paragraph := TextParagraph.new()
	paragraph.width = minf(ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, minf(360.0, get_viewport_rect().size.x - 32.0))
	paragraph.add_string(text, ThemeDB.fallback_font, 16)
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


func _draw_station_visit(visit: StationVisit, target: Node2D) -> void:
	var alpha := smoothstep(1.5, 3.0, view_zoom.x) * visit.platform_alpha()
	if alpha <= 0.001:
		return
	if not visit.visible_in(_visible_world):
		return
	var visible_area := _visible_world
	var night := _night_strength()
	if not visit.platform.is_empty():
		var fill := Color("#d8dfdd").lerp(Color("#33464f"), night)
		fill.a = alpha * 0.96
		target.draw_colored_polygon(visit.platform, fill)
		var outline := visit.platform.duplicate()
		outline.append(outline[0])
		target.draw_polyline(outline, Color(Color("#7b8d8c").lerp(Color("#8ba0a7"), night), alpha * 0.6), 0.22, false)
		var seam := Color(Color("#899b99").lerp(Color("#82979e"), night), alpha * 0.28)
		for index in range(0, visit.platform_seams.size(), 2):
			target.draw_line(visit.platform_seams[index], visit.platform_seams[index + 1], seam, 0.13, false)
		target.draw_polyline(visit.platform_edge, Color(Color("#647b7b").lerp(Color("#acbfc4"), night), alpha * 0.8), 0.25, false)
		var safety := Color(Color("#ddc798").lerp(Color("#dac9a1"), night), alpha * 0.85)
		target.draw_polyline(visit.platform_safety_edge, safety, 0.65, false)
		for dot: Vector2 in visit.tactile_dots:
			target.draw_circle(dot, 0.09, Color(Color("#826d48"), alpha * 0.65), true, -1.0, false)
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
			target.draw_circle(position, StationVisit.PASSENGER_RADIUS, coat, true, -1.0, view_zoom.x < 3.0)
			var skin := Color("#dfb993") if index % 3 == 0 else Color("#b68968") if index % 3 == 1 else Color("#ead1b0")
			skin.a = opacity
			target.draw_circle(position + normal * (0.1 if not entering else -0.1), 0.15, skin, true, -1.0, view_zoom.x < 3.0)

func _draw_train(metro: Metro, color: Color, poses: Dictionary, target: Node2D) -> void:
	var positions: PackedVector2Array = poses["positions"]
	var axes: PackedVector2Array = poses["axes"]
	if positions.is_empty():
		return
	if overview_opacity(view_zoom.x) >= 1.0:
		return
	for car in range(1, metro.wagon_count + 1):
		target.draw_set_transform(Vector2.ZERO)
		var edges := _gangway_edges(positions, axes, car)
		# A compressed connector can fold across itself on a tight bend.
		for triangle: PackedVector2Array in [PackedVector2Array([edges[0], edges[1], edges[2]]), PackedVector2Array([edges[0], edges[2], edges[3]])]:
			if absf((triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])) > 0.0001:
				target.draw_colored_polygon(triangle, Color("#344b53"))
		if view_zoom.x > 1.5:
			var detail := smoothstep(1.5, 3.0, view_zoom.x)
			for fold in range(1, 5):
				var fraction := float(fold) / 5.0
				target.draw_line(edges[0].lerp(edges[1], fraction), edges[3].lerp(edges[2], fraction), Color(0.58, 0.65, 0.66, detail * 0.65), 0.22, false)
	var body_vertices := PackedVector2Array()
	var body_colors := PackedColorArray()
	var body_indices := PackedInt32Array()
	for car in range(metro.wagon_count, -1, -1):
		var leading := car == 0
		var trailing := car == metro.wagon_count
		var cab_end := 1 if leading else (-1 if trailing else 0)
		_append_car_mesh(body_vertices, body_colors, body_indices, positions[car], axes[car], Vector3(5.9, 3.3, cab_end), color.darkened(0.48))
		_append_car_mesh(body_vertices, body_colors, body_indices, positions[car], axes[car], Vector3(5.55, 2.85, cab_end), color)
		if cab_end != 0:
			var nose_key := Vector3(0.0, 0.0, cab_end)
			var nose := PackedVector2Array([
				Vector2(cab_end * 3.5, -1.75), Vector2(cab_end * 4.55, -1.35),
				Vector2(cab_end * 4.55, 1.35), Vector2(cab_end * 3.5, 1.75)
			])
			_cache_shape(nose_key, nose)
			_append_cached_shape(body_vertices, body_colors, body_indices, nose_key, positions[car], axes[car], Color("#344f5c"))
	if not body_indices.is_empty():
		target.draw_set_transform(Vector2.ZERO)
		RenderingServer.canvas_item_add_triangle_array(target.get_canvas_item(), body_indices, body_vertices, body_colors)
	var doors_open := metro.at_station and metro.visit != null and metro.visit.elapsed >= metro.visit.opening_duration
	for car in range(metro.wagon_count, -1, -1):
		target.draw_set_transform(positions[car], axes[car].angle(), Vector2(TrackGeometry.CAR_SCALE, 1.0))
		_draw_car(color, car == 0, car == metro.wagon_count, doors_open, target)
	target.draw_set_transform(Vector2.ZERO)

func _draw_overview_train(path: PackedVector2Array, target: Node2D) -> void:
	if path.is_empty():
		return
	if path.size() >= 2:
		var cumulative := TrackGeometry.cumulative_lengths(path)
		var colors := PackedColorArray()
		var glow := PackedColorArray()
		for distance: float in cumulative:
			var alpha := pow(distance / cumulative[cumulative.size() - 1], 1.4)
			colors.append(Color(1.0, 1.0, 1.0, alpha * 0.8))
			glow.append(Color(0.8, 0.93, 1.0, alpha * 0.18))
		target.draw_polyline_colors(path, glow, 4.0 / view_zoom.x, true)
		target.draw_polyline_colors(path, colors, OVERVIEW_TRAIN_WIDTH / view_zoom.x, true)
	var head := path[path.size() - 1]
	target.draw_circle(head, 4.0 / view_zoom.x, Color(0.8, 0.93, 1.0, 0.12), true, -1.0, true)
	target.draw_circle(head, 3.2 / view_zoom.x, Color("#17232c"), true, -1.0, true)
	target.draw_circle(head, 2.2 / view_zoom.x, Color.WHITE, true, -1.0, true)

func _append_car_mesh(vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array, position: Vector2, axis: Vector2, key: Vector3, color: Color) -> void:
	var polygon: PackedVector2Array
	if _shape_polygons.has(key):
		polygon = _shape_polygons[key]
	else:
		var half_length := key.x
		var half_width := key.y
		var cab_end := int(key.z)
		var left_bevel := 1.2 if cab_end < 0 else 0.6
		var right_bevel := 1.2 if cab_end > 0 else 0.6
		polygon = PackedVector2Array([
			Vector2(-half_length + left_bevel, -half_width), Vector2(half_length - right_bevel, -half_width),
			Vector2(half_length, -half_width + right_bevel), Vector2(half_length, half_width - right_bevel),
			Vector2(half_length - right_bevel, half_width), Vector2(-half_length + left_bevel, half_width),
			Vector2(-half_length, half_width - left_bevel), Vector2(-half_length, -half_width + left_bevel)
		])
		_cache_shape(key, polygon)
	_append_cached_shape(vertices, colors, indices, key, position, axis, color)

func _cache_shape(key: Vector3, polygon: PackedVector2Array) -> void:
	if _shape_polygons.has(key):
		return
	var triangle_indices := Geometry2D.triangulate_polygon(polygon)
	if triangle_indices.is_empty():
		push_error("Could not triangulate cached train shape.")
		return
	_shape_polygons[key] = polygon
	_shape_indices[key] = triangle_indices
	_shape_meshes[key] = _polygon_mesh(polygon)

func _append_cached_shape(vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array, key: Vector3, position: Vector2, axis: Vector2, color: Color) -> void:
	if not _shape_polygons.has(key):
		return
	var polygon: PackedVector2Array = _shape_polygons[key]
	var base := vertices.size()
	var angle := axis.angle()
	for vertex: Vector2 in polygon:
		vertices.append(position + Vector2(vertex.x * TrackGeometry.CAR_SCALE, vertex.y).rotated(angle))
		colors.append(color)
	for vertex_index: int in _shape_indices[key]:
		indices.append(base + vertex_index)

func _draw_ground_shadows() -> void:
	var opacity := BACKDROP.shadow_opacity(time_of_day)
	if opacity < 0.001:
		return
	var offset := BACKDROP.shadow_offset(time_of_day)
	var color := Color(0.12, 0.17, 0.23, opacity * 0.36)
	draw_set_transform(offset * 0.45)
	for index in range(_track_shadows.size()):
		var mesh := _track_shadow_meshes[index]
		if mesh == null:
			draw_colored_polygon(_track_shadows[index], color)
		else:
			draw_mesh(mesh, null, Transform2D.IDENTITY, color)
	draw_set_transform(Vector2.ZERO)

# Matches draw_colored_polygon's own triangulation so cached meshes keep identical pixels.
func _polygon_mesh(polygon: PackedVector2Array) -> Mesh:
	if polygon.size() < 3:
		return null
	var indices := Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty():
		push_error("Could not triangulate cached polygon.")
		return null
	var vertices := PackedVector3Array()
	for vertex: Vector2 in polygon:
		vertices.append(Vector3(vertex.x, vertex.y, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh if mesh.get_surface_count() > 0 else null

func _draw_sun_shadows(train_poses: Dictionary, target: Node2D) -> void:
	if overview_opacity(view_zoom.x) >= 1.0:
		return
	var opacity := BACKDROP.shadow_opacity(time_of_day)
	if opacity < 0.001:
		return
	var offset := BACKDROP.shadow_offset(time_of_day)
	var color := Color(0.12, 0.17, 0.23, opacity * 0.5)
	for metro: Metro in metros:
		if not train_poses.has(metro.get_instance_id()):
			continue
		var poses: Dictionary = train_poses[metro.get_instance_id()]
		var positions: PackedVector2Array = poses["positions"]
		var axes: PackedVector2Array = poses["axes"]
		if positions.is_empty():
			continue
		for car in range(metro.wagon_count + 1):
			target.draw_set_transform(positions[car] + offset * 0.65, axes[car].angle(), Vector2(TrackGeometry.CAR_SCALE, 1.0))
			for spread: float in [0.15, 0.45]:
				_draw_car_shell(5.9 + spread, 3.3 + spread, color, 1 if car == 0 else (-1 if car == metro.wagon_count else 0), target)
	target.draw_set_transform(Vector2.ZERO)

func _gangway_edges(positions: PackedVector2Array, axes: PackedVector2Array, car: int) -> PackedVector2Array:
	var front_axis := axes[car - 1]
	var back_axis := axes[car]
	var front := positions[car - 1] - front_axis * 5.2 * TrackGeometry.CAR_SCALE
	var back := positions[car] + back_axis * 5.2 * TrackGeometry.CAR_SCALE
	var front_normal := front_axis.orthogonal() * 2.0
	var back_normal := back_axis.orthogonal() * 2.0
	return PackedVector2Array([front + front_normal, back + back_normal, back - back_normal, front - front_normal])

func _draw_headlights(poses: Dictionary, target: Node2D) -> void:
	if overview_opacity(view_zoom.x) >= 1.0:
		return
	var positions: PackedVector2Array = poses["positions"]
	var axes: PackedVector2Array = poses["axes"]
	if positions.is_empty():
		return
	var strength := 0.42 * _night_strength()
	if strength <= 0.001:
		return
	if strength != _beam_strength:
		_rebuild_beams(strength)
	target.draw_set_transform(positions[0], axes[0].angle())
	for side_index in range(2):
		var source := Vector2(5.0 * TrackGeometry.CAR_SCALE, (side_index * 2 - 1) * 2.0)
		for radius: float in [5.0, 3.5, 2.0]:
			target.draw_circle(source, radius, Color(1.0, 0.91, 0.69, strength * 0.22), true, -1.0, true)
		var beam: Array = _beams[side_index]
		RenderingServer.canvas_item_add_triangle_array(target.get_canvas_item(), beam[2], beam[0], beam[1])
	target.draw_set_transform(Vector2.ZERO)

# One fading beam per side, shared by every train. Raw triangle arrays keep float vertex
# colors (ArrayMesh would quantize the faint alpha) and match draw_polygon's triangulation.
func _rebuild_beams(strength: float) -> void:
	_beam_strength = strength
	_beams.clear()
	for side: float in [-1.0, 1.0]:
		var source := Vector2(5.0 * TrackGeometry.CAR_SCALE, side * 2.0)
		var vertices := PackedVector2Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
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
				var quad := PackedVector2Array([source + Vector2(x_a, 0), source + Vector2(x_b, 0), source + Vector2(x_b, half * width_b), source + Vector2(x_a, half * width_a)])
				var base := vertices.size()
				for index: int in Geometry2D.triangulate_polygon(quad):
					indices.append(base + index)
				vertices.append_array(quad)
				colors.append_array(PackedColorArray([Color(1.0, 0.91, 0.69, alpha_a), Color(1.0, 0.91, 0.69, alpha_b), Color(1.0, 0.91, 0.69, 0.0), Color(1.0, 0.91, 0.69, 0.0)]))
		_beams.append([vertices, colors, indices])

func _draw_car(color: Color, leading_cab: bool, trailing_cab: bool, doors_open: bool, target: Node2D) -> void:
	var antialias := view_zoom.x < 1.5
	var cab_end := 1 if leading_cab else (-1 if trailing_cab else 0)
	var detail := smoothstep(1.5, 3.0, view_zoom.x)
	var fine_detail := smoothstep(3.0, 4.5, view_zoom.x)
	var roof_start := -3.35 if trailing_cab else -4.8
	var roof_end := 3.35 if leading_cab else 4.8
	target.draw_rect(Rect2(roof_start, -1.75, roof_end - roof_start, 3.5), Color("#dde3e2"))
	if detail > 0.0:
		var glazing := Color("#45636d").lerp(Color("#f1d8a2"), _night_strength() * 0.8)
		glazing.a = detail
		for side: float in [-1.0, 1.0]:
			for window_x: float in [-3.6, -0.7, 2.2]:
				if (leading_cab and window_x > 2.0) or (trailing_cab and window_x < -3.0):
					continue
				target.draw_line(Vector2(window_x, side * 2.3), Vector2(window_x + 1.4, side * 2.3), glazing, 0.6, antialias)
			for door_x: float in [-1.75, 1.15]:
				var door := Color(0.78, 0.84, 0.84, detail)
				target.draw_rect(Rect2(door_x - 0.5, side * 2.3 - 0.35, 1.0, 0.7), door)
				if doors_open and side > 0.0:
					target.draw_rect(Rect2(door_x - 0.28, side * 2.3 - 0.35, 0.56, 0.7), Color(0.25, 0.34, 0.37, detail))
				else:
					target.draw_line(Vector2(door_x, side * 2.3 - 0.35), Vector2(door_x, side * 2.3 + 0.35), Color(0.25, 0.34, 0.37, fine_detail), 0.18, false)
		for equipment_x: float in [-1.9, 1.5]:
			target.draw_rect(Rect2(equipment_x - 0.65, -0.85, 1.3, 1.7), Color(0.63, 0.69, 0.70, detail))
			for slat in range(3):
				var x := equipment_x - 0.4 + slat * 0.4
				target.draw_line(Vector2(x, -0.6), Vector2(x, 0.6), Color(0.36, 0.43, 0.45, fine_detail), 0.18, false)
		target.draw_line(Vector2(0.0, -1.65), Vector2(0.0, 1.65), Color(0.57, 0.64, 0.65, fine_detail * 0.5), 0.18, false)
		target.draw_line(Vector2(roof_start + 0.3, -1.35), Vector2(roof_end - 0.3, -1.35), Color(1.0, 1.0, 1.0, detail * 0.55), 0.25, false)
	if cab_end != 0:
		for side: float in [-1.0, 1.0]:
			target.draw_circle(Vector2(cab_end * 5.0, side * 1.9), 0.4, Color("#fff3c9") if leading_cab else Color("#d84e55"), true, -1.0, antialias)


func _draw_car_shell(half_length: float, half_width: float, color: Color, cab_end: int, target: Node2D) -> void:
	var key := Vector3(half_length, half_width, cab_end)
	var mesh: Mesh = _shape_meshes.get(key)
	if mesh == null:
		var left_bevel := 1.2 if cab_end < 0 else 0.6
		var right_bevel := 1.2 if cab_end > 0 else 0.6
		var polygon := PackedVector2Array([
			Vector2(-half_length + left_bevel, -half_width), Vector2(half_length - right_bevel, -half_width),
			Vector2(half_length, -half_width + right_bevel), Vector2(half_length, half_width - right_bevel),
			Vector2(half_length - right_bevel, half_width), Vector2(-half_length + left_bevel, half_width),
			Vector2(-half_length, half_width - left_bevel), Vector2(-half_length, -half_width + left_bevel)
		])
		_cache_shape(key, polygon)
		mesh = _shape_meshes.get(key)
	target.draw_mesh(mesh, null, Transform2D.IDENTITY, color)

func _night_strength() -> float:
	return clampf((cos(time_of_day * TAU) + 0.3) / 1.3, 0.0, 1.0)
