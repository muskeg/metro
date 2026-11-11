class_name RailIlluminationLayer
extends Node2D

var _lines: Array[TransitLine] = []
var _paths: Dictionary = {}
var _strengths: Dictionary = {}
var _colors: Dictionary = {}
var _antialiased := true
var _layers: Array[Node2D] = []
var _night_strength := 0.0

func set_network(transit_lines: Array[TransitLine], paths: Dictionary, strengths: Dictionary, tracks: StaticTrackLayer = null) -> void:
	for layer: Node2D in _layers:
		if is_instance_valid(layer):
			layer.get_parent().remove_child(layer)
			layer.queue_free()
	_layers.clear()
	_lines = transit_lines
	_paths = paths
	_strengths = strengths
	_colors.clear()
	for line: TransitLine in _lines:
		_rebuild_line_colors(line)
		var layer := Node2D.new()
		layer.draw.connect(_draw_line.bind(layer, line))
		if tracks != null:
			var parent := tracks.line_layer(line.id)
			parent.add_child(layer)
			parent.move_child(layer, 0)
		else:
			add_child(layer)
		_layers.append(layer)
	set_night_strength(_night_strength)
	queue_redraw()

func set_night_strength(strength: float) -> void:
	_night_strength = strength
	for layer: Node2D in _layers:
		layer.modulate.a = clampf(strength, 0.0, 1.0) * 0.8

func set_antialiased(enabled: bool) -> void:
	if _antialiased == enabled:
		return
	_antialiased = enabled
	for layer: Node2D in _layers:
		layer.queue_redraw()
	queue_redraw()

func set_line_color(line_id: int, color: Color) -> void:
	for line: TransitLine in _lines:
		if line.id == line_id:
			line.color = color
			_rebuild_line_colors(line)
			for layer: Node2D in _layers:
				layer.queue_redraw()
			queue_redraw()
			return

func _rebuild_line_colors(line: TransitLine) -> void:
	if not _paths.has(line.id) or not _strengths.has(line.id):
		return
	var line_colors: Array[PackedColorArray] = []
	var line_strengths: Array[PackedFloat32Array] = _strengths[line.id]
	for strengths: PackedFloat32Array in line_strengths:
		var colors := PackedColorArray()
		for strength: float in strengths:
			colors.append(Color(line.color.lightened(0.55), strength))
		line_colors.append(colors)
	_colors[line.id] = line_colors

func _draw_line(layer: Node2D, line: TransitLine) -> void:
	if not _paths.has(line.id) or not _colors.has(line.id):
		return
	var paths: Array[PackedVector2Array] = _paths[line.id]
	var colors: Array[PackedColorArray] = _colors[line.id]
	for index in range(paths.size()):
		layer.draw_polyline_colors(paths[index], colors[index], 1.2, _antialiased)
