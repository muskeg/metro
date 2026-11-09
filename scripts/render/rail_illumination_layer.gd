class_name RailIlluminationLayer
extends Node2D

var _lines: Array[TransitLine] = []
var _paths: Dictionary = {}
var _strengths: Dictionary = {}
var _colors: Dictionary = {}
var _antialiased := true

func set_network(transit_lines: Array[TransitLine], paths: Dictionary, strengths: Dictionary) -> void:
	_lines = transit_lines
	_paths = paths
	_strengths = strengths
	_colors.clear()
	for line: TransitLine in _lines:
		_rebuild_line_colors(line)
	queue_redraw()

func set_night_strength(strength: float) -> void:
	modulate.a = clampf(strength, 0.0, 1.0) * 0.8

func set_antialiased(enabled: bool) -> void:
	if _antialiased == enabled:
		return
	_antialiased = enabled
	queue_redraw()

func set_line_color(line_id: int, color: Color) -> void:
	for line: TransitLine in _lines:
		if line.id == line_id:
			line.color = color
			_rebuild_line_colors(line)
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

func _draw() -> void:
	for line: TransitLine in _lines:
		if not _paths.has(line.id) or not _colors.has(line.id):
			continue
		var paths: Array[PackedVector2Array] = _paths[line.id]
		var colors: Array[PackedColorArray] = _colors[line.id]
		for index in range(paths.size()):
			draw_polyline_colors(paths[index], colors[index], 1.2, _antialiased)
