extends SceneTree

const BACKDROP_SCRIPT := preload("res://scripts/render/urban_backdrop.gd")

func _initialize() -> void:
	_run_test.call_deferred()

func _run_test() -> void:
	var backdrop := BACKDROP_SCRIPT.new()
	root.add_child(backdrop)
	var camera := Camera2D.new()
	root.add_child(camera)
	if backdrop.background_color(0.5) != Color("#faf9f4"):
		_fail("Noon must have a light matte paper background.")
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
	if backdrop.background_color(0.25).b <= backdrop.background_color(0.25).r or backdrop.background_color(0.75).r <= backdrop.background_color(0.75).b:
		_fail("Dawn must be cooler than the warm sunset palette.")
		return
	if backdrop.shadow_opacity(0.0) != 0.0 or backdrop.shadow_opacity(0.5) <= 0.0 or backdrop.shadow_offset(0.25).x <= 0.0 or backdrop.shadow_offset(0.75).x >= 0.0:
		_fail("Sun shadows must disappear at midnight and change direction from dawn to dusk.")
		return
	if backdrop.shadow_offset(0.25).length() <= backdrop.shadow_offset(0.5).length() * 3.0:
		_fail("Low-sun shadows must be measurably longer than noon shadows.")
		return
	for step in range(1000):
		var phase := float(step) / 1000.0
		if _difference(backdrop.background_color(phase), backdrop.background_color(phase + 0.001)) > 0.06 or absf(backdrop.shadow_opacity(phase + 0.001) - backdrop.shadow_opacity(phase)) > 0.004:
			_fail("Palette and shadow strength must change continuously throughout the day, including wrapping.")
			return
	var previous_shadow := backdrop.shadow_offset(0.25).x
	for step in range(1, 101):
		var phase := 0.25 + step * 0.005
		var shadow := backdrop.shadow_offset(phase).x
		if shadow > previous_shadow + 0.0001 or backdrop.sun_position(phase).x < backdrop.sun_position(phase - 0.005).x:
			_fail("Sunlight must travel continuously left to right while shadows travel right to left.")
			return
		previous_shadow = shadow
	var centers: Array[Vector2] = [Vector2.ZERO, Vector2(-2100.0, 1450.0), Vector2(16000.0, -24000.0)]
	var zooms: Array[Vector2] = [Vector2.ONE, Vector2.ONE * 0.08, Vector2(0.45, 0.75), Vector2(2.6, 2.0)]
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
							if _difference(pixel, expected) > (0.22 if phase in [0.25, 0.75] else 0.055) or pixel.a < 0.99:
								_fail("The atmospheric background must remain smooth and free of scenery or grid lines (phase %.2f, center %s, zoom %s, difference %.4f)." % [phase, center, zoom, _difference(pixel, expected)])
								return
						if phase == 0.5 and expected.get_luminance() < 0.93:
							_fail("Noon must remain bright and readable across the matte surface.")
							return
					if phase == 0.0:
						var top := image.get_pixel(0, 0)
						var bottom := image.get_pixel(0, image.get_height() - 1)
						if top.get_luminance() > 0.04 or bottom.get_luminance() > 0.04:
							_fail("Night gradient must stay dark enough for rail glow to stand out.")
							return
						if absf(top.r - bottom.r) + absf(top.g - bottom.g) + absf(top.b - bottom.b) < 0.02:
							_fail("Night must have a visible but subtle atmospheric gradient.")
							return
					if center == Vector2.ZERO and zoom == Vector2.ONE and phase == 0.5:
						var low := 1.0
						var high := 0.0
						for x in range(0, image.get_width(), 3):
							var luminance := image.get_pixel(x, image.get_height() / 2).get_luminance()
							low = minf(low, luminance)
							high = maxf(high, luminance)
						if high - low < 0.002 or high - low > 0.025:
							_fail("Matte texture must be visible but restrained, not flat or distractingly noisy.")
							return
					if center == Vector2.ZERO and zoom == Vector2.ONE:
						if image.save_png("/tmp/metro-surface-%s.png" % phase) != OK:
							_fail("Could not capture the matte daylight surface.")
							return
	if DisplayServer.get_name() != "headless":
		camera.position = Vector2.ZERO
		camera.zoom = Vector2.ONE
		backdrop.set_view(camera.position, camera.zoom, 0.5)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var original := root.get_texture().get_image()
		camera.position = Vector2(48, 0)
		backdrop.set_view(camera.position, camera.zoom, 0.5)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var panned := root.get_texture().get_image()
		for x in range(100, original.get_width() - 148, 37):
			if _difference(panned.get_pixel(x, 100), original.get_pixel(x + 48, 100)) > 0.008:
				_fail("Matte grain must stay anchored to the map, not swim with the camera.")
				return
	backdrop.set_view(Vector2.ZERO, Vector2.ZERO, -0.25)
	if not backdrop.view_zoom.is_finite() or backdrop.view_zoom.x <= 0.0 or backdrop.time_of_day != 0.75:
		_fail("Zero zoom and wrapped phases must remain safe.")
		return
	print("Backdrop smoke passed: matte texture, distinct dawn/dusk, solar shadows and continuous viewport coverage.")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _difference(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
