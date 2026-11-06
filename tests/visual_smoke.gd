extends SceneTree

var _main: Node
var _day_rail: Color
var _day_city: Color

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	root.size = Vector2i(1440, 900)
	await process_frame
	var graph: TransitGraph = _main.get("graph")
	graph.add_station(Vector2(-192.0, -192.0))
	graph.add_station(Vector2(384.0, -48.0))
	graph.add_station(Vector2(384.0, 288.0))
	_main.call("_connect_stations", 0, 1, PackedVector2Array([Vector2(-192.0, -192.0), Vector2(144.0, -192.0), Vector2(144.0, -48.0), Vector2(384.0, -48.0)]))
	_main.call("_connect_stations", 1, 2, PackedVector2Array([Vector2(384.0, -48.0), Vector2(576.0, -48.0), Vector2(576.0, 288.0), Vector2(384.0, 288.0)]))
	var dispatcher: TransitDispatcher = _main.get("dispatcher")
	dispatcher.process(3.0, false)
	_main.set("paused", true)
	_main.set_process(false)
	_main.call("_clear_hover")
	var view: WorldView = _main.get("world_view")
	view.selected_station_id = -1
	var camera: Camera2D = _main.get("camera")
	for phase: float in [0.5, 0.0]:
		_main.set("time_of_day", phase)
		view.set_dynamic_state(dispatcher.metros, camera.get_screen_center_position(), camera.zoom, phase)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		if DisplayServer.get_name() != "headless":
			var image := root.get_texture().get_image()
			var rail := image.get_pixel(620, 250)
			var city := image.get_pixel(740, 90)
			var solid := image.get_pixel(620, 258)
			var station_fill := image.get_pixel(528, 258)
			var station_border := image.get_pixel(528, 247)
			var shadow_position := image.get_pixel(532, 280)
			for terminal_pixel: Vector2i in [Vector2i(511, 258), Vector2i(1086, 738)]:
				var terminal_color := image.get_pixelv(terminal_pixel)
				var terminal_background := image.get_pixel(400, terminal_pixel.y)
				if absf(terminal_color.r - terminal_background.r) + absf(terminal_color.g - terminal_background.g) + absf(terminal_color.b - terminal_background.b) > 0.025:
					push_error("The terminal band must end neatly without showing the simulated turnaround: %s vs %s at phase %s." % [terminal_color, terminal_background, phase])
					quit(1)
					return
			if station_fill.get_luminance() < 0.85 or station_border.get_luminance() > 0.7:
				push_error("Stations must be simple white dots with a contrasting day/night border: %s %s at phase %s." % [station_fill, station_border, phase])
				quit(1)
				return
			var shadow_background := image.get_pixel(400, 280)
			if absf(shadow_position.r - shadow_background.r) + absf(shadow_position.g - shadow_background.g) + absf(shadow_position.b - shadow_background.b) > 0.025:
				push_error("Stations must not have a drop shadow or glow.")
				quit(1)
				return
			var line_color: Color = _main.get("lines")[0].color
			if absf(solid.r - line_color.r) + absf(solid.g - line_color.g) + absf(solid.b - line_color.b) > 0.025:
				push_error("The line corridor must be an opaque solid color.")
				quit(1)
				return
			if rail.get_luminance() >= solid.get_luminance() - 0.05:
				push_error("The train running lanes must be darker than the solid line.")
				quit(1)
				return
			var outside := image.get_pixel(620, 239)
			var outside_background := image.get_pixel(400, 239)
			if absf(outside.r - outside_background.r) + absf(outside.g - outside_background.g) + absf(outside.b - outside_background.b) > 0.025:
				push_error("The thinner rail corridor must not have a wide glow or shadow.")
				quit(1)
				return
			if phase > 0.1:
				_day_rail = rail
				_day_city = city
			else:
				if absf(rail.r - _day_rail.r) + absf(rail.g - _day_rail.g) + absf(rail.b - _day_rail.b) > 0.08:
					push_error("The night cycle should not darken the rail layer.")
					quit(1)
					return
				if _day_city.get_luminance() - city.get_luminance() < 0.03:
					push_error("The solid background should visibly darken at night.")
					quit(1)
					return
			var path := "/tmp/metro-day.png" if phase > 0.1 else "/tmp/metro-night.png"
			var error := image.save_png(path)
			if error != OK:
				push_error("Screenshot failed: " + error_string(error))
				quit(1)
				return
	var recolor := Color("#cb6d95")
	var color_picker: ColorPickerButton = _main.get("_line_color_picker")
	color_picker.color_changed.emit(recolor)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() != "headless":
		var pixel := root.get_texture().get_image().get_pixel(620, 258)
		if absf(pixel.r - recolor.r) + absf(pixel.g - recolor.g) + absf(pixel.b - recolor.b) > 0.025:
			push_error("Changing the line color must recolor the visible solid corridor.")
			quit(1)
			return
	_main.call("_update_hover", graph.stations[0].position)
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() != "headless":
		var image := root.get_texture().get_image()
		var anchor := view.station_handle_position(graph.stations[0], Vector2.RIGHT)
		var screen := view.get_global_transform_with_canvas() * anchor
		var green_pixels := 0
		for y in range(int(screen.y) - 10, int(screen.y) + 11):
			for x in range(int(screen.x) - 10, int(screen.x) + 11):
				var pixel := image.get_pixel(x, y)
				if pixel.g > 0.7 and pixel.g > pixel.r + 0.1:
					green_pixels += 1
		if green_pixels < 20:
			push_error("Hovering must render a visible, screen-sized connection anchor.")
			quit(1)
			return
		if image.save_png("/tmp/metro-gizmos.png") != OK:
			push_error("Could not save the contextual gizmo screenshot.")
			quit(1)
			return
	for viewport_size: Vector2i in [Vector2i(1440, 900), Vector2i(900, 600)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		for phase: float in [0.5, 0.0]:
			view.set_dynamic_state(dispatcher.metros, camera.get_screen_center_position(), camera.zoom, phase)
			_main.call("_begin_world_interaction", view.station_handle_position(graph.stations[0], Vector2.RIGHT))
			_main.call("_extend_stroke", graph.stations[1].position)
			if not view.get("_preview_error").is_empty():
				push_error("The rendered station-to-station preview must be valid.")
				quit(1)
				return
			await process_frame
			await RenderingServer.frame_post_draw
			if DisplayServer.get_name() != "headless":
				var image := root.get_texture().get_image()
				var diagonal_pixel := view.get_global_transform_with_canvas() * Vector2(-120.0, -120.0)
				var pixel := image.get_pixelv(Vector2i(diagonal_pixel))
				if absf(pixel.r - recolor.r) + absf(pixel.g - recolor.g) + absf(pixel.b - recolor.b) > 0.05:
					push_error("The diagonal preview must render in the selected line color at both window sizes.")
					quit(1)
					return
				var mode := "day" if phase > 0.1 else "night"
				if image.save_png("/tmp/metro-elastic-%s-%d.png" % [mode, viewport_size.x]) != OK:
					push_error("Could not save the elastic drawing screenshot.")
					quit(1)
					return
			_main.call("_cancel_gesture")
	_main.call("_begin_world_interaction", view.station_handle_position(graph.stations[0], Vector2.RIGHT))
	_main.call("_extend_stroke", Vector2(576.0, 144.0))
	if view.get("_preview_error").is_empty() or view.get("_preview_color") != Color("#d45c64"):
		push_error("Crossing previews must expose invalid geometry and use the danger color.")
		quit(1)
		return
	await process_frame
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() != "headless":
		if root.get_texture().get_image().save_png("/tmp/metro-elastic-invalid.png") != OK:
			push_error("Could not save the invalid-route screenshot.")
			quit(1)
			return
	_main.call("_cancel_gesture")
	_main.queue_free()
	await process_frame
	print("Metro visual smoke passed.")
	quit()
