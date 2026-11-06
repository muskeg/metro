extends SceneTree

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Train visual test requires a graphical display.")
		quit(1)
		return
	root.size = Vector2i(1440, 900)
	var world := Node2D.new()
	root.add_child(world)
	var view := WorldView.new()
	world.add_child(view)
	var camera := Camera2D.new()
	world.add_child(camera)
	camera.zoom = Vector2.ONE * 6.0
	var graph := TransitGraph.new()
	graph.add_station(Vector2.ZERO)
	graph.add_station(Vector2(1200, 0))
	var line := TransitLine.new(0, Color("#58b8bd"))
	line.append_station(graph, 0)
	line.append_station(graph, 1)
	var lines: Array[TransitLine] = [line]
	var route := TrackGeometry.circuit(graph, line, lines)
	view.set_network(graph, lines, {0: route})
	var train := Metro.new(0, 0, Vector2.ZERO)
	train.distance = 600.0
	train.wagon_count = 2
	var points: PackedVector2Array = route["points"]
	train.position = TrackGeometry.point_at_distance(points, train.distance)
	camera.position = train.position
	camera.reset_smoothing()
	for phase: float in [0.5, 0.0]:
		view.set_dynamic_state([], camera.position, camera.zoom, phase)
		await process_frame
		await RenderingServer.frame_post_draw
		var empty := root.get_texture().get_image()
		view.set_dynamic_state([train], camera.position, camera.zoom, phase)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var center := Vector2i(view.get_global_transform_with_canvas() * train.position)
		var coupling := center + Vector2i(-39, 0)
		_check(_difference(image.get_pixelv(coupling), empty.get_pixelv(coupling)) > 0.05, "Adjacent cars must be joined by a wide gangway.")
		var car_corner := center + Vector2i(-28, 17)
		_check(_difference(image.get_pixelv(car_corner), empty.get_pixelv(car_corner)) > 0.1, "A subway car must have a predominantly rectangular silhouette.")
		if phase > 0.1:
			var undercarriage := center + Vector2i(19, 23)
			_check(_difference(image.get_pixelv(undercarriage), empty.get_pixelv(undercarriage)) < 0.025, "Covered wheels must not appear as decorative circles alongside the roof.")
		var shadow := center + Vector2i(0, 30)
		_check(_difference(image.get_pixelv(shadow), empty.get_pixelv(shadow)) < 0.025, "Cars must not draw an offset drop shadow.")
		var beam := center + Vector2i(120, 0)
		var light_difference := _difference(image.get_pixelv(beam), empty.get_pixelv(beam))
		if phase == 0.0:
			_check(light_difference > 0.02, "Headlights must illuminate the route at night.")
			var distant := center + Vector2i(240, 0)
			var distant_difference := _difference(image.get_pixelv(distant), empty.get_pixelv(distant))
			_check(light_difference > distant_difference + 0.01, "Headlight illumination must fade smoothly with distance.")
		else:
			_check(light_difference < 0.02, "Headlight illumination must not wash out the daytime map.")
		var name := "day" if phase > 0.1 else "night"
		_check(image.save_png("/tmp/metro-train-%s.png" % name) == OK, "Could not capture close-up train rendering.")
		if phase > 0.1:
			var old_body := image.get_pixelv(center + Vector2i(0, 10))
			line.color = Color("#d8758b")
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var recolored := root.get_texture().get_image().get_pixelv(center + Vector2i(0, 10))
			_check(_difference(old_body, recolored) > 0.1, "Close-up cars must update when the line is recolored.")
			line.color = Color("#58b8bd")
	camera.position = Vector2.ZERO
	camera.reset_smoothing()
	view.set_dynamic_state([], camera.position, camera.zoom, 0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	var station_image := root.get_texture().get_image()
	var station_center := Vector2i(view.get_global_transform_with_canvas() * Vector2.ZERO)
	var fill := station_image.get_pixelv(station_center + Vector2i(-50, 0))
	var border := station_image.get_pixelv(station_center + Vector2i(-66, 0))
	var cap := station_image.get_pixelv(station_center + Vector2i(-79, 0))
	var outside := station_image.get_pixelv(station_center + Vector2i(-90, 0))
	_check(fill.get_luminance() > 0.9 and border.get_luminance() < 0.35, "Station outlines must retain a sharp contrasting border at follow zoom.")
	_check(_difference(cap, line.color) < 0.08 and outside.get_luminance() > 0.95, "The line must form a complete rounded terminal behind the station, without displaying the turnaround.")
	_check(station_image.save_png("/tmp/metro-terminal.png") == OK, "Could not capture close-up terminal rendering.")
	world.queue_free()
	await process_frame
	if failed:
		quit(1)
	else:
		print("Train visual smoke passed: rectangular coupled cars, shadow-free rendering and soft headlights.")
		quit()

func _difference(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
