class_name UrbanBackdrop
extends Node2D

const NIGHT_COLOR := Color("#142731")

var view_center := Vector2.ZERO
var view_zoom := Vector2.ONE
var time_of_day := 0.5

func _ready() -> void:
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

func background_color(phase: float) -> Color:
	var daylight := (1.0 - cos(fposmod(phase, 1.0) * TAU)) * 0.5
	return NIGHT_COLOR.lerp(Color.WHITE, smoothstep(0.0, 1.0, daylight))

func _draw() -> void:
	var rect := _visible_world_rect()
	var base := background_color(time_of_day)
	var daylight := (1.0 - cos(time_of_day * TAU)) * 0.5
	var night := 1.0 - smoothstep(0.0, 1.0, daylight)
	var twilight := sin(daylight * PI) * 0.10
	var top := base.lerp(Color("#294458"), night * 0.36).lerp(Color("#ffe2ce"), twilight)
	var bottom := base.lerp(Color("#101e29"), night * 0.22).lerp(Color("#d8e6ed"), twilight * 0.55)
	draw_polygon(
		PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.end, rect.position + Vector2(0.0, rect.size.y)]),
		PackedColorArray([top, top, bottom, bottom])
	)
