class_name UrbanBackdrop
extends Node2D

const NIGHT_COLOR := Color("#03060c")
const SURFACE_SHADER := preload("res://scripts/render/matte_surface.gdshader")

var view_center := Vector2.ZERO
var view_zoom := Vector2.ONE
var time_of_day := 0.5

func _ready() -> void:
	var surface := ShaderMaterial.new()
	surface.shader = SURFACE_SHADER
	material = surface
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()

func set_view(center: Vector2, zoom: Vector2, phase: float) -> void:
	view_center = center if center.is_finite() else Vector2.ZERO
	view_zoom = Vector2(_safe_zoom(zoom.x), _safe_zoom(zoom.y))
	time_of_day = fposmod(phase, 1.0) if is_finite(phase) else 0.5
	queue_redraw()

func _safe_zoom(value: float) -> float:
	return maxf(absf(value), 0.000001) if is_finite(value) else 1.0

func _visible_world_rect() -> Rect2:
	var size := get_viewport_rect().size / view_zoom
	return Rect2(view_center - size * 0.5, size).grow(96.0)

static func background_color(phase: float) -> Color:
	var stops := PackedFloat32Array([0.0, 0.18, 0.25, 0.34, 0.5, 0.66, 0.75, 0.82, 1.0])
	var colors := PackedColorArray([NIGHT_COLOR, Color("#202f4b"), Color("#c8d5e0"), Color("#f6efe2"), Color("#faf9f4"), Color("#f3eadc"), Color("#e8b7a0"), Color("#27344f"), NIGHT_COLOR])
	var time := fposmod(phase, 1.0)
	for index in range(1, stops.size()):
		if time <= stops[index]:
			return colors[index - 1].lerp(colors[index], smoothstep(stops[index - 1], stops[index], time))
	return NIGHT_COLOR

static func twilight_strength(phase: float) -> float:
	var time := fposmod(phase, 1.0)
	return maxf(1.0 - smoothstep(0.0, 0.13, absf(time - 0.25)), 1.0 - smoothstep(0.0, 0.13, absf(time - 0.75)))

static func surface_colors(phase: float) -> PackedColorArray:
	var base := background_color(phase)
	var twilight := twilight_strength(phase)
	var night := clampf((cos(phase * TAU) + 0.3) / 1.3, 0.0, 1.0)
	var top := base.lerp(Color("#0e1a30"), night * 0.18).lerp(Color("#7189ad"), twilight * 0.3)
	var bottom := base.lerp(Color("#02050a"), night * 0.35).lerp(Color("#ffddba"), twilight * 0.4)
	return PackedColorArray([top, bottom])

static func shadow_opacity(phase: float) -> float:
	var time := fposmod(phase, 1.0)
	var twilight := twilight_strength(phase)
	var sunlight := smoothstep(0.14, 0.25, time) * (1.0 - smoothstep(0.75, 0.86, time))
	return sunlight * lerpf(0.09, 0.13, twilight)

static func shadow_offset(phase: float) -> Vector2:
	var sun := sun_position(phase)
	return Vector2((0.5 - sun.x) * 14.0, 2.0) * (1.0 + twilight_strength(phase) * 0.5)

static func sun_position(phase: float) -> Vector2:
	var progress := clampf((fposmod(phase, 1.0) - 0.25) * 2.0, 0.0, 1.0)
	return Vector2((1.0 - cos(progress * PI)) * 0.5, 0.7 - sin(progress * PI) * 0.5)

func _draw() -> void:
	var rect := _visible_world_rect()
	var colors := surface_colors(time_of_day)
	var surface := material as ShaderMaterial
	surface.set_shader_parameter("top_color", colors[0])
	surface.set_shader_parameter("bottom_color", colors[1])
	surface.set_shader_parameter("warmth", twilight_strength(time_of_day))
	surface.set_shader_parameter("sun_position", sun_position(time_of_day))
	draw_rect(rect, Color.WHITE)
