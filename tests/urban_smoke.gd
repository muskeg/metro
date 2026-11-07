extends SceneTree

const BACKDROP_SCRIPT := preload("res://scripts/render/urban_backdrop.gd")

func _initialize() -> void:
	_run_test.call_deferred()

func _run_test() -> void:
	var backdrop := BACKDROP_SCRIPT.new()
	root.add_child(backdrop)
	var camera := Camera2D.new()
	root.add_child(camera)
	if backdrop.background_color(0.5) != Color.WHITE:
		_fail("Noon must have a pure white background.")
		return
	if backdrop.background_color(0.0) != backdrop.NIGHT_COLOR or backdrop.background_color(0.0).get_luminance() > 0.04:
		_fail("Midnight must have a dark background.")
		return
	if backdrop.background_color(0.0) != backdrop.background_color(1.0) or backdrop.background_color(0.5) != backdrop.background_color(-0.5):
		_fail("The day/night transition must wrap continuously.")
		return
	if backdrop.background_color(0.25) == Color.WHITE or backdrop.background_color(0.25) == backdrop.NIGHT_COLOR:
		_fail("Dawn and dusk must transition smoothly between white and dark.")
		return
	var centers: Array[Vector2] = [Vector2.ZERO, Vector2(-2100.0, 1450.0), Vector2(16000.0, -24000.0)]
	var zooms: Array[Vector2] = [Vector2.ONE, Vector2(0.45, 0.75), Vector2(2.6, 2.0)]
	for center: Vector2 in centers:
		for zoom: Vector2 in zooms:
			camera.position = center
			camera.zoom = zoom
			for phase: float in [0.0, 0.25, 0.5, 0.75]:
				backdrop.set_view(center, zoom, phase)
				var visible_size := root.get_visible_rect().size / zoom
				if not backdrop._visible_world_rect().encloses(Rect2(center - visible_size * 0.5, visible_size)):
					_fail("The solid backdrop must cover the viewport when panning and zooming.")
					return
				await process_frame
				await process_frame
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					var image := root.get_texture().get_image()
					for y in range(0, image.get_height(), 7):
						var expected := image.get_pixel(0, y)
						for x in range(0, image.get_width(), 7):
							var pixel := image.get_pixel(x, y)
							if absf(pixel.r - expected.r) + absf(pixel.g - expected.g) + absf(pixel.b - expected.b) > 0.025 or pixel.a < 0.99:
								_fail("The atmospheric background must remain smooth and free of scenery or grid lines.")
								return
						if phase == 0.5 and absf(expected.r - 1.0) + absf(expected.g - 1.0) + absf(expected.b - 1.0) > 0.025:
							_fail("Noon must remain pure white across the viewport.")
							return
					if phase == 0.0:
						var top := image.get_pixel(0, 0)
						var bottom := image.get_pixel(0, image.get_height() - 1)
						if absf(top.r - bottom.r) + absf(top.g - bottom.g) + absf(top.b - bottom.b) < 0.02:
							_fail("Night must have a visible but subtle atmospheric gradient.")
							return
	backdrop.set_view(Vector2.ZERO, Vector2.ZERO, -0.25)
	if not backdrop.view_zoom.is_finite() or backdrop.view_zoom.x <= 0.0 or backdrop.time_of_day != 0.75:
		_fail("Zero zoom and wrapped phases must remain safe.")
		return
	print("Backdrop smoke passed: white day, atmospheric night and smooth viewport coverage.")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
