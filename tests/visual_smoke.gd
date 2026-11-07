extends SceneTree

var _main: Node
var _day_rail: Color
var _day_city: Color

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	# Pixel probes below use a fixed 1x render target; density/input has its own test.
	root.content_scale_factor = 1.0
	root.min_size = Vector2i.ZERO
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
	for name: String in ["_main_panel", "_status_panel", "_toolbar"]:
		_main.get(name).hide()
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
	if DisplayServer.get_name() != "headless":
		if not await _test_connection_cues(view, dispatcher, camera):
			quit(1)
			return
		if not await _test_station_ghost(view, dispatcher, camera):
			quit(1)
			return
		if not await _test_watch_handle(view, dispatcher):
			quit(1)
			return
		if not await _test_station_line_rings(view, dispatcher, camera):
			quit(1)
			return
	_main.queue_free()
	await process_frame
	print("Metro visual smoke passed.")
	quit()

func _test_station_ghost(view: WorldView, dispatcher: TransitDispatcher, camera: Camera2D) -> bool:
	var position := Vector2(-96, 96)
	for zoom: float in [0.65, 1.0, 2.5]:
		camera.zoom = Vector2.ONE * zoom
		await process_frame
		await process_frame
		for phase: float in [0.5, 0.0]:
			view.set_dynamic_state(dispatcher.metros, camera.get_screen_center_position(), camera.zoom, phase)
			_main.call("_clear_hover")
			await process_frame
			await RenderingServer.frame_post_draw
			var pixel := Vector2i(view.get_global_transform_with_canvas() * (position + Vector2(11, 0)))
			var background := root.get_texture().get_image().get_pixelv(pixel)
			_main.call("_update_hover", position)
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var ghost := root.get_texture().get_image().get_pixelv(pixel)
			var station_pixel := Vector2i(view.get_global_transform_with_canvas() * view.graph.stations[0].position)
			var station_on_screen := Rect2i(Vector2i.ZERO, root.size).has_point(station_pixel)
			var station_color := root.get_texture().get_image().get_pixelv(station_pixel) if station_on_screen else Color.TRANSPARENT
			var difference := absf(ghost.r - background.r) + absf(ghost.g - background.g) + absf(ghost.b - background.b)
			if not view.station_preview_visible or difference < 0.04 or difference > 1.4:
				push_error("Station ghost must be visible but translucent, day/night and at each zoom: delta %s at zoom %s phase %s." % [difference, zoom, phase])
				return false
			_main.call("_toggle_ui")
			await process_frame
			await RenderingServer.frame_post_draw
			var watched := root.get_texture().get_image().get_pixelv(pixel)
			if station_on_screen:
				var watched_station := root.get_texture().get_image().get_pixelv(station_pixel)
				if absf(watched_station.r - station_color.r) + absf(watched_station.g - station_color.g) + absf(watched_station.b - station_color.b) > 0.02:
					push_error("Watch mode must preserve the rendered station at %s: %s vs %s." % [station_pixel, watched_station, station_color])
					return false
			if absf(watched.r - background.r) + absf(watched.g - background.g) + absf(watched.b - background.b) > 0.02:
				push_error("Watch mode must remove the ghost from rendered pixels.")
				return false
			_main.call("_toggle_ui")
	return true

func _test_watch_handle(view: WorldView, dispatcher: TransitDispatcher) -> bool:
	_main.call("_toggle_ui")
	var handle: Button = _main.get("_restore_ui_button")
	for phase: float in [0.5, 0.0]:
		_main.set("time_of_day", phase)
		view.set_dynamic_state(dispatcher.metros, view.view_center, view.view_zoom, phase)
		handle.hide()
		await process_frame
		await RenderingServer.frame_post_draw
		var baseline := root.get_texture().get_image()
		handle.show()
		handle.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var center := Vector2i(handle.get_global_rect().get_center())
		var difference := _pixel_difference(image.get_pixelv(center), baseline.get_pixelv(center))
		if difference < 0.15 or difference > 1.6:
			push_error("Watch handle must remain visible but subtle at day/night: %s." % difference)
			return false
		for offset: Vector2i in [Vector2i(28, 0), Vector2i(0, 10)]:
			if _pixel_difference(image.get_pixelv(center + offset), baseline.get_pixelv(center + offset)) > 0.01:
				push_error("Watch handle must not draw a filled button around its small grip.")
				return false
	_main.call("_toggle_ui")
	return true

func _pixel_difference(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

func _test_connection_cues(view: WorldView, dispatcher: TransitDispatcher, camera: Camera2D) -> bool:
	camera.zoom = Vector2.ONE
	_main.call("_clear_hover")
	for phase: float in [0.5, 0.0]:
		view.set_dynamic_state(dispatcher.metros, camera.get_screen_center_position(), camera.zoom, phase)
		view.connection_hint_station_id = -1
		view.valid_connection_targets.clear()
		await process_frame
		await RenderingServer.frame_post_draw
		var baseline := root.get_texture().get_image()
		view.connection_hint_station_id = 0
		view.route_active = true
		view.valid_connection_targets = PackedInt32Array([1])
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var ring := Vector2i(view.get_global_transform_with_canvas() * (view.graph.stations[1].position + Vector2(17, 0)))
		if _pixel_difference(root.get_texture().get_image().get_pixelv(ring), baseline.get_pixelv(ring)) < 0.05:
			push_error("Valid route destinations must have a visible local highlight at day/night.")
			return false
		view.route_active = false
		view.valid_connection_targets.clear()
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var anchor := Vector2i(view.get_global_transform_with_canvas() * view.station_handle_position(view.graph.stations[0], Vector2.RIGHT))
		if _pixel_difference(root.get_texture().get_image().get_pixelv(anchor), baseline.get_pixelv(anchor)) < 0.05:
			push_error("First-connection cue must show a visible local + without a popup.")
			return false
		view.connection_hint_station_id = -1
	return true

func _test_station_line_rings(view: WorldView, dispatcher: TransitDispatcher, camera: Camera2D) -> bool:
	var station := view.graph.add_station(Vector2(-960, -960))
	camera.position = station.position
	camera.reset_smoothing()
	camera.force_update_scroll()
	_main.call("_clear_hover")
	view.selected_station_id = -1
	view.connection_hint_station_id = -1
	var original_count := view.lines.size()
	var palette := [Color("#58b8bd"), Color("#e98668"), Color("#8d83c7"), Color("#d0a84f")]
	for count: int in [0, 1, 2, 4, 8]:
		view.lines.resize(original_count)
		for index in range(count):
			var line := TransitLine.new(original_count + index, palette[index % palette.size()])
			line.stations = [station.id, station.id]
			view.lines.append(line)
		if view.station_line_colors(station).size() != count or not is_equal_approx(view.station_radius(station), 10.0 + 2.0 * maxi(1, count)):
			push_error("Stations must have exactly one ring per serving line, even at loop endpoints.")
			return false
		for zoom: float in [1.0, 2.5]:
			camera.zoom = Vector2.ONE * zoom
			await process_frame
			await process_frame
			for phase: float in [0.5, 0.0]:
				view.set_dynamic_state(dispatcher.metros, camera.get_screen_center_position(), camera.zoom, phase)
				await process_frame
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				var transform := view.get_global_transform_with_canvas()
				if image.get_pixelv(Vector2i(transform * station.position)).get_luminance() < 0.85:
					push_error("Interchange rings must preserve the white station center.")
					return false
				for index in range(count):
					var radius := 10.0 + 2.0 * (count - index) - 1.0
					var pixel := image.get_pixelv(Vector2i(transform * (station.position + Vector2(radius, 0))))
					if _pixel_difference(pixel, palette[index % palette.size()].darkened(0.3)) > 0.08:
						push_error("Station rings must match darkened line colors, oldest outside, at day/night and zoom: count=%s index=%s pixel=%s." % [count, index, pixel])
						return false
		if count > 0:
			view.lines.back().color = Color("#cb6d95")
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var transform := view.get_global_transform_with_canvas()
			var inner := root.get_texture().get_image().get_pixelv(Vector2i(transform * (station.position + Vector2(11, 0))))
			if _pixel_difference(inner, Color("#cb6d95").darkened(0.3)) > 0.08:
				push_error("Station rings must update immediately when their line is recolored.")
				return false
		if count == 4:
			camera.zoom = Vector2.ONE * 2.5
			view.view_zoom = camera.zoom
			for mode: String in ["source", "target", "hover", "watch"]:
				view.route_active = mode == "source" or mode == "target"
				view.route_source_id = station.id if mode == "source" else 0
				view.route_target_id = station.id if mode == "target" else -1
				view.hovered_station_id = station.id
				view.selected_station_id = station.id
				view.interaction_overlays_visible = mode != "watch"
				var points := PackedVector2Array([station.position, station.position + Vector2(80, 0)]) if mode == "source" else PackedVector2Array([station.position - Vector2(80, 0), station.position])
				if mode == "hover":
					points.clear()
				view.set_stroke_preview(points, Color("#58b8bd"))
				await process_frame
				await RenderingServer.frame_post_draw
				var transform := view.get_global_transform_with_canvas()
				var image := root.get_texture().get_image()
				for index in range(count):
					var radius := 10.0 + 2.0 * (count - index) - 1.0
					var expected: Color = palette[index % palette.size()] if index < count - 1 else Color("#cb6d95")
					if _pixel_difference(image.get_pixelv(Vector2i(transform * (station.position + Vector2(radius, 0)))), expected.darkened(0.3)) > 0.08:
						push_error("Interaction overlays must preserve station line rings: %s." % mode)
						return false
			view.route_active = false
			view.hovered_station_id = -1
			view.selected_station_id = -1
			view.interaction_overlays_visible = true
			view.set_stroke_preview(PackedVector2Array(), Color.WHITE)
	view.lines.resize(original_count)
	if not is_equal_approx(view.station_radius(station), 12.0) or not view.station_line_colors(station).is_empty():
		push_error("Removing serving lines must remove their rings and shrink the station.")
		return false
	return true
