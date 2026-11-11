class_name StaticTrackLayer
extends Node2D

const CORRIDOR_WIDTH := 28.0
const LANE_EDGE_WIDTH := 8.0
const RUNNING_LANE_WIDTH := 4.0

var lines: Array[TransitLine] = []
var routes: Dictionary = {}
var antialiased := true
var _shadow_polygons: Array[PackedVector2Array] = []
var _shadow_items: Array[Node2D] = []
var _shadow_opacity := 0.0
var _shadow_offset := Vector2.ZERO
var _legacy_shadows := false
var _shadows_enabled := true
var _line_layers: Dictionary[int, Node2D] = {}
var _line_models: Dictionary[int, TransitLine] = {}

func set_network(transit_lines: Array[TransitLine], route_data: Dictionary) -> void:
	lines = transit_lines.duplicate()
	lines.sort_custom(func(a: TransitLine, b: TransitLine) -> bool:
		if a.render_priority != b.render_priority:
			return a.render_priority < b.render_priority
		return transit_lines.find(a) < transit_lines.find(b))
	routes = route_data
	_line_models.clear()
	var retained: Dictionary[int, Node2D] = {}
	for line: TransitLine in lines:
		_line_models[line.id] = line
		var layer: Node2D = _line_layers.get(line.id)
		if layer == null:
			layer = Node2D.new()
			layer.draw.connect(_draw_line.bind(layer, line.id))
			add_child(layer)
		move_child(layer, get_child_count() - 1)
		layer.queue_redraw()
		retained[line.id] = layer
	for line_id: int in _line_layers:
		if not retained.has(line_id):
			var layer := _line_layers[line_id]
			remove_child(layer)
			layer.queue_free()
	_line_layers = retained
	queue_redraw()

func line_layer(line_id: int) -> Node2D:
	return _line_layers[line_id]

func set_antialiased(enabled: bool) -> void:
	if antialiased == enabled:
		return
	antialiased = enabled
	for layer: Node2D in _line_layers.values():
		layer.queue_redraw()
	queue_redraw()

func set_shadows(meshes: Array[Mesh], polygons: Array[PackedVector2Array]) -> void:
	for item: Node2D in _shadow_items:
		remove_child(item)
		item.queue_free()
	_shadow_items.clear()
	_shadow_polygons = polygons
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for index in range(polygons.size()):
		if index < meshes.size() and meshes[index] != null:
			var source: Mesh = meshes[index]
			for surface in range(source.get_surface_count()):
				var arrays := source.surface_get_arrays(surface)
				var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var base := vertices.size()
				vertices.append_array(source_vertices)
				for vertex_index: int in source_indices:
					indices.append(base + vertex_index)
		else:
			var fallback := Polygon2D.new()
			fallback.polygon = polygons[index]
			fallback.z_index = -1
			add_child(fallback)
			_shadow_items.append(fallback)
	if not indices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mesh_instance := MeshInstance2D.new()
		mesh_instance.mesh = mesh
		mesh_instance.z_index = -1
		add_child(mesh_instance)
		_shadow_items.append(mesh_instance)
	_update_shadows()

func set_shadow_state(opacity: float, offset: Vector2) -> void:
	_shadow_opacity = opacity
	_shadow_offset = offset
	_update_shadows()

func set_shadow_render_mode(legacy: bool, enabled: bool) -> void:
	if _legacy_shadows == legacy and _shadows_enabled == enabled:
		return
	_legacy_shadows = legacy
	_shadows_enabled = enabled
	_update_shadows()
	queue_redraw()

func _update_shadows() -> void:
	var color := Color(0.12, 0.17, 0.23, _shadow_opacity * 0.36)
	for item: Node2D in _shadow_items:
		item.position = _shadow_offset * 0.45
		item.modulate = color
		item.visible = _shadows_enabled and not _legacy_shadows and _shadow_opacity >= 0.001

func _draw() -> void:
	if _legacy_shadows and _shadows_enabled and _shadow_opacity >= 0.001:
		draw_set_transform(_shadow_offset * 0.45)
		for polygon: PackedVector2Array in _shadow_polygons:
			draw_colored_polygon(polygon, Color(0.12, 0.17, 0.23, _shadow_opacity * 0.36))
		draw_set_transform(Vector2.ZERO)

func _draw_line(layer: Node2D, line_id: int) -> void:
	var line := _line_models[line_id]
	if not routes.has(line.id):
		return
	var route: Dictionary = routes[line.id]
	var points: PackedVector2Array = route["points"]
	if points.size() < 2:
		return
	for lane: PackedVector2Array in route["running_paths"]:
		layer.draw_polyline(lane, line.color, LANE_EDGE_WIDTH, antialiased)
	layer.draw_polyline(route["centerline"], line.color, CORRIDOR_WIDTH, antialiased)
	if not line.is_loop():
		var centerline: PackedVector2Array = route["centerline"]
		for endpoint: Vector2 in [centerline[0], centerline[centerline.size() - 1]]:
			layer.draw_circle(endpoint, CORRIDOR_WIDTH * 0.5, line.color, true, -1.0, antialiased)
	for lane: PackedVector2Array in route["running_paths"]:
		layer.draw_polyline(lane, line.color.darkened(0.3), RUNNING_LANE_WIDTH, antialiased)
