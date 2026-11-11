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
	_check(is_equal_approx(TrackGeometry.CAR_LENGTH, 18.0 * 1.1) and is_equal_approx(TrackGeometry.CAR_PITCH - TrackGeometry.CAR_LENGTH, 1.0) and TrackGeometry.CAR_WIDTH == 7.0, "All cars must grow exactly 10%, keeping their width and one-unit inter-car gap.")
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
		var coupling := center + Vector2i(roundi(-TrackGeometry.CAR_PITCH * camera.zoom.x * 0.5), 0)
		_check(_difference(image.get_pixelv(coupling), empty.get_pixelv(coupling)) > 0.05, "Adjacent cars must be joined by a wide gangway.")
		var car_corner := center + Vector2i(-42, 19)
		_check(_difference(image.get_pixelv(car_corner), empty.get_pixelv(car_corner)) > 0.1, "A subway car must have a predominantly rectangular silhouette.")
		var leading_glass := image.get_pixelv(center + Vector2i(roundi(4.0 * TrackGeometry.CAR_SCALE * camera.zoom.x), 0))
		var trailing_glass := image.get_pixelv(center + Vector2i(roundi(-(train.wagon_count * TrackGeometry.CAR_PITCH + 4.0 * TrackGeometry.CAR_SCALE) * camera.zoom.x), 0))
		_check(_difference(leading_glass, Color("#344f5c")) < 0.05 and _difference(leading_glass, trailing_glass) < 0.05, "Both ends must have matching dark cab windscreens.")
		var roof := image.get_pixelv(center + Vector2i(6, 6))
		_check(_difference(roof, Color("#dde3e2")) < 0.05, "The roof must read as pale metal rather than line-colored bodywork.")
		var equipment := image.get_pixelv(center + Vector2i(-17, 0))
		_check(equipment.get_luminance() < roof.get_luminance() - 0.15, "Follow zoom must reveal roof ventilation equipment.")
		var middle_car := center + Vector2i(roundi(-TrackGeometry.CAR_PITCH * camera.zoom.x), 0)
		var window := image.get_pixelv(middle_car + Vector2i(roundi(-3.0 * TrackGeometry.CAR_SCALE * camera.zoom.x), 14))
		var door := image.get_pixelv(middle_car + Vector2i(roundi(-2.0 * TrackGeometry.CAR_SCALE * camera.zoom.x), 14))
		var seam := image.get_pixelv(middle_car + Vector2i(roundi(-1.75 * TrackGeometry.CAR_SCALE * camera.zoom.x), 14))
		_check(_difference(door, window) > 0.1 and door.get_luminance() > seam.get_luminance() + 0.05, "Side glazing must alternate with paired doors and a visible center seam (door %s, window %s, seam %s)." % [door, window, seam])
		if phase > 0.1:
			var undercarriage := center + Vector2i(19, 23)
			_check(_difference(image.get_pixelv(undercarriage), empty.get_pixelv(undercarriage)) < 0.3, "Daytime undercarriage must have only a restrained solar shadow, not dark decorative wheels.")
		var shadow := center + Vector2i(0, 30)
		var shadow_difference := _difference(image.get_pixelv(shadow), empty.get_pixelv(shadow))
		_check(shadow_difference < (0.3 if phase > 0.1 else 0.025), "Car solar shadows must be restrained by day and disappear at midnight.")
		if phase > 0.1:
			_check(shadow_difference > 0.02, "Daytime cars must cast a measurable subtle sun shadow.")
		var far_shadow := center + Vector2i(0, 54)
		_check(_difference(image.get_pixelv(far_shadow), empty.get_pixelv(far_shadow)) < 0.025, "Noon car shadows must stay short, not wash out neighboring lanes.")
		var beam := center + Vector2i(120, 0)
		var light_difference := _difference(image.get_pixelv(beam), empty.get_pixelv(beam))
		if phase == 0.0:
			_check(light_difference > 0.02, "Headlights must illuminate the route at night.")
			var lamp_glow := center + Vector2i(48, 30)
			_check(_difference(image.get_pixelv(lamp_glow), empty.get_pixelv(lamp_glow)) > 0.08, "Lamps need a visible local glow, not only a faint broad beam.")
			var distant := center + Vector2i(240, 0)
			var distant_difference := _difference(image.get_pixelv(distant), empty.get_pixelv(distant))
			_check(light_difference > distant_difference + 0.01, "Headlight illumination must fade smoothly with distance.")
		else:
			_check(light_difference < 0.02, "Headlight illumination must not wash out the daytime map.")
		var name := "day" if phase > 0.1 else "night"
		_check(image.save_png("/tmp/metro-train-%s.png" % name) == OK, "Could not capture close-up train rendering.")
		if phase > 0.1:
			var old_body := image.get_pixelv(center + Vector2i(0, 17))
			line.color = Color("#d8758b")
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var recolored_image := root.get_texture().get_image()
			var recolored := recolored_image.get_pixelv(center + Vector2i(0, 17))
			_check(_difference(old_body, recolored) > 0.1, "Close-up cars must update when the line is recolored.")
			_check(_difference(roof, recolored_image.get_pixelv(center + Vector2i(6, 6))) < 0.025, "Recoloring the body must preserve the neutral metal roof.")
			line.color = Color("#58b8bd")
	train.passenger_count = 6
	var visit := StationVisit.new(train, route, 3.0, false)
	visit.elapsed = visit.opening_duration + visit.alighting_duration
	train.visit = visit
	train.at_station = true
	view.set_dynamic_state([train], camera.position, camera.zoom, 0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	var no_platform := root.get_texture().get_image()
	view.set_dynamic_state([train], camera.position, camera.zoom, 0.5, [visit])
	await process_frame
	await RenderingServer.frame_post_draw
	var platform_image := root.get_texture().get_image()
	var platform_center := Vector2i(view.get_global_transform_with_canvas() * train.position)
	var platform_pixel := platform_center + Vector2i(0, 45)
	_check(_difference(platform_image.get_pixelv(platform_pixel), no_platform.get_pixelv(platform_pixel)) > 0.1, "Zoomed stopped trains must reveal small platforms beside their cars.")
	var platform_gap := platform_center + Vector2i(roundi(-TrackGeometry.CAR_PITCH * camera.zoom.x * 0.5), 45)
	_check(_difference(platform_image.get_pixelv(platform_gap), no_platform.get_pixelv(platform_gap)) > 0.1, "The platform must continue across car gaps instead of splitting into separate squares.")
	var person_pixel := Vector2i(view.get_global_transform_with_canvas() * visit.passenger_position(0, false))
	_check(_difference(platform_image.get_pixelv(person_pixel), platform_image.get_pixelv(person_pixel + Vector2i(5, 0))) > 0.1, "Tiny alighting passengers must be visible on the platform, not just an empty slab.")
	var safety_pixel := Vector2i(view.get_global_transform_with_canvas() * (visit.centers[0] + visit.normals[0] * 5.4))
	_check(_difference(platform_image.get_pixelv(safety_pixel), platform_image.get_pixelv(platform_pixel)) > 0.1, "Platform safety edging must be visibly distinct from the pavement.")
	_check(visit.boarding >= visit.doors.size() * 2, "Close-up stops must display a fuller crowd of waiting boarders.")
	_check(platform_image.save_png("/tmp/metro-train-platform.png") == OK, "Could not capture the passenger platform.")
	view.set_dynamic_state([train], camera.position, camera.zoom, 0.0, [visit])
	await process_frame
	await RenderingServer.frame_post_draw
	var night_platform := root.get_texture().get_image()
	_check(_difference(night_platform.get_pixelv(safety_pixel), night_platform.get_pixelv(platform_pixel)) > 0.15, "The tactile safety edge must remain readable on nighttime pavement.")
	_check(_difference(night_platform.get_pixelv(person_pixel), night_platform.get_pixelv(person_pixel + Vector2i(5, 0))) > 0.1, "Smaller passengers must remain visible on nighttime platforms.")
	_check(night_platform.save_png("/tmp/metro-train-platform-night.png") == OK, "Could not capture nighttime platform and passenger detail.")
	visit.departure_age = StationVisit.FADE_TIME
	view.set_dynamic_state([train], camera.position, camera.zoom, 0.5, [visit])
	await process_frame
	await RenderingServer.frame_post_draw
	var faded_platform := root.get_texture().get_image()
	_check(_difference(faded_platform.get_pixelv(platform_pixel), no_platform.get_pixelv(platform_pixel)) < 0.025, "The platform must fade back into the map after departure.")
	visit.departure_age = -1.0
	camera.zoom = Vector2.ONE
	camera.reset_smoothing()
	view.set_dynamic_state([train], camera.position, camera.zoom, 0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	var map_image := root.get_texture().get_image()
	var map_center := Vector2i(view.get_global_transform_with_canvas() * train.position)
	_check(_difference(map_image.get_pixelv(map_center + Vector2i(-2, 0)), Color("#dde3e2")) < 0.05, "At map zoom the roof equipment must disappear, leaving a clean silhouette.")
	view.set_dynamic_state([train], camera.position, camera.zoom, 0.5, [visit])
	await process_frame
	await RenderingServer.frame_post_draw
	var hidden_platform := root.get_texture().get_image()
	_check(_difference(hidden_platform.get_pixelv(map_center + Vector2i(0, 8)), map_image.get_pixelv(map_center + Vector2i(0, 8))) < 0.025, "Platforms and people must remain hidden at map zoom.")
	_check(map_image.save_png("/tmp/metro-train-map.png") == OK, "Could not capture map-scale train rendering.")
	train.visit = null
	var curve := TrackGeometry.round_corners(PackedVector2Array([Vector2(-100, 0), Vector2.ZERO, Vector2(0, 100)]))
	var curve_length := TrackGeometry.length(curve)
	var compressed := false
	var curve_lengths := TrackGeometry.cumulative_lengths(curve)
	for distance in range(90, 121):
		var front_distance := float(distance)
		var back_distance := front_distance - TrackGeometry.CAR_PITCH
		var positions := PackedVector2Array([
			TrackGeometry.point_at_distance(curve, fposmod(front_distance, curve_length), curve_lengths),
			TrackGeometry.point_at_distance(curve, fposmod(back_distance, curve_length), curve_lengths),
		])
		var axes := PackedVector2Array([
			TrackGeometry.car_axis(curve, curve_length, front_distance, front_distance, curve_lengths),
			TrackGeometry.car_axis(curve, curve_length, back_distance, front_distance, curve_lengths),
		])
		var edges := view._gangway_edges(positions, axes, 1)
		var first_side := edges[0].distance_to(edges[1])
		var second_side := edges[3].distance_to(edges[2])
		if absf(first_side - second_side) > 0.5:
			compressed = true
		_check(absf(edges[0].distance_to(edges[3]) - 4.0) < 0.01 and absf(edges[1].distance_to(edges[2]) - 4.0) < 0.01, "Gangway ends must keep their width attached to each rotating car.")
	_check(compressed, "Accordion gangways must compress on the inside of curves rather than remain parallel strips.")
	graph.stations[1].position = Vector2(192, 192)
	graph.tracks[0].waypoints = PackedVector2Array([Vector2.ZERO, Vector2(192, 0), Vector2(192, 192)])
	var bent_route := TrackGeometry.circuit(graph, line, lines)
	train.distance = 193.0
	train.position = TrackGeometry.point_at_distance(bent_route["points"], train.distance)
	camera.zoom = Vector2.ONE * 12.0
	camera.position = train.position
	camera.reset_smoothing()
	view.set_network(graph, lines, {0: bent_route})
	var curved_visit := StationVisit.new(train, bent_route, 3.0, false)
	for edge: PackedVector2Array in [curved_visit.platform_edge, curved_visit.platform_safety_edge]:
		for index in range(1, edge.size() - 1):
			var incoming := edge[index] - edge[index - 1]
			var outgoing := edge[index + 1] - edge[index]
			if incoming.length() > 0.01 and outgoing.length() > 0.01:
				_check(absf(incoming.angle_to(outgoing)) < deg_to_rad(8.0), "Corner platform edges and tactile strips must turn smoothly without per-car steps (%.2f degrees at %d)." % [rad_to_deg(absf(incoming.angle_to(outgoing))), index])
	curved_visit.elapsed = 0.8
	train.visit = curved_visit
	view.set_dynamic_state([train], camera.position, camera.zoom, 0.5, [curved_visit])
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("/tmp/metro-train-curve.png") == OK, "Could not capture articulated cars with a continuous curved platform.")
	train.distance = bent_route["stops"][0]
	train.position = TrackGeometry.point_at_distance(bent_route["points"], train.distance)
	var bent_visit := StationVisit.new(train, bent_route, 3.0, false)
	bent_visit.elapsed = 0.8
	train.visit = bent_visit
	camera.zoom = Vector2.ONE * 6.0
	camera.position = train.position
	camera.reset_smoothing()
	view.set_dynamic_state([train], camera.position, camera.zoom, 0.5, [bent_visit])
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("/tmp/metro-train-berth.png") == OK, "Could not capture the restored terminal stop and continuous platform.")
	train.visit = null
	graph.stations[1].position = Vector2(1200, 0)
	graph.tracks[0].waypoints = PackedVector2Array([Vector2.ZERO, Vector2(1200, 0)])
	view.set_network(graph, lines, {0: route})
	camera.zoom = Vector2.ONE * 6.0
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
	var outside := station_image.get_pixelv(station_center + Vector2i(-108, 0))
	_check(fill.get_luminance() > 0.9 and _difference(border, line.color.darkened(0.3)) < 0.08, "Station outlines must retain their sharp darkened line-color border at follow zoom.")
	_check(_difference(cap, line.color) < 0.08 and outside.get_luminance() > 0.95, "The normal rounded terminal cap must end at the station without exposing simulation extensions.")
	_check(station_image.save_png("/tmp/metro-terminal.png") == OK, "Could not capture close-up terminal rendering.")
	var stops: PackedFloat32Array = route["stops"]
	train.distance = stops[stops.size() - 1]
	camera.position = Vector2.ZERO
	camera.reset_smoothing()
	train.position = TrackGeometry.point_at_distance(points, train.distance)
	view.set_dynamic_state([train], camera.position, camera.zoom, 0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	var train_at_station := root.get_texture().get_image()
	var covered_border := train_at_station.get_pixelv(station_center + Vector2i(0, -66))
	_check(_difference(covered_border, line.color.darkened(0.3)) < 0.12, "Opaque station rings must cover trains naturally without changing opacity.")
	var terminal_visit := StationVisit.new(train, route, 3.0, true)
	terminal_visit.elapsed = 0.8
	for vertex: Vector2 in terminal_visit.platform:
		_check(vertex.distance_to(graph.stations[0].position) > view.station_radius(graph.stations[0]), "Terminal platforms must stay entirely outside the station marker.")
	view.set_dynamic_state([train], camera.position, camera.zoom, 0.5, [terminal_visit])
	await process_frame
	await RenderingServer.frame_post_draw
	train_at_station = root.get_texture().get_image()
	for car in range(train.wagon_count + 1):
		var car_pixel := Vector2i(view.get_global_transform_with_canvas() * TrackGeometry.car_position(points, route["length"], train.distance, car))
		_check(_difference(train_at_station.get_pixelv(car_pixel), Color.WHITE) > 0.1, "Every stopped terminal car must remain visible outside the station.")
	_check(train_at_station.save_png("/tmp/metro-train-terminal-stop.png") == OK, "Could not capture the restored opaque station and terminal stop.")
	train.distance = float(route["outbound_end"]) + 10.0
	train.position = TrackGeometry.point_at_distance(points, train.distance)
	var station_markers := graph.stations.duplicate()
	graph.stations.clear()
	camera.position = train.position
	camera.reset_smoothing()
	view.set_dynamic_state([], camera.position, camera.zoom, 0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var empty_turn := root.get_texture().get_image()
	view.set_dynamic_state([train], camera.position, camera.zoom, 0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var visible_turn := root.get_texture().get_image()
	for car in range(train.wagon_count + 1):
		var pixel := Vector2i(view.get_global_transform_with_canvas() * TrackGeometry.car_position(points, route["length"], train.distance, car))
		_check(_difference(empty_turn.get_pixelv(pixel), visible_turn.get_pixelv(pixel)) > 0.05, "All train cars must remain visible during terminal movement.")
	graph.stations.assign(station_markers)
	var other := TransitLine.new(1, Color("#d8758b"))
	other.stations = [0]
	lines.append(other)
	view.set_network(graph, lines, {0: route})
	var illuminated: Array = view.get("_illuminated_paths")[0]
	var exclusion := view.station_radius(graph.stations[0]) + 23.0
	for path: PackedVector2Array in illuminated:
		for index in range(1, path.size()):
			var closest := Geometry2D.get_closest_point_to_segment(graph.stations[0].position, path[index - 1], path[index])
			_check(closest.distance_to(graph.stations[0].position) >= exclusion, "Shared-station junctions must not expose overlapping luminous cores or halos.")
	camera.position = Vector2.ZERO
	camera.reset_smoothing()
	view.set_dynamic_state([], camera.position, camera.zoom, 0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var junction_image := root.get_texture().get_image()
	var near_pixel := Vector2i(view.get_global_transform_with_canvas() * TrackGeometry.point_at_distance(route["running_paths"][0], 26.0))
	var far_pixel := Vector2i(view.get_global_transform_with_canvas() * TrackGeometry.point_at_distance(route["running_paths"][0], 80.0))
	_check(_difference(junction_image.get_pixelv(near_pixel), line.color.darkened(0.3)) < 0.1, "Night junction rails must retain the dark base lane without an exposed luminous cross.")
	_check(junction_image.get_pixelv(far_pixel).get_luminance() > junction_image.get_pixelv(near_pixel).get_luminance() + 0.08, "Suppressing junction overlap must preserve pronounced rail lighting farther away.")
	_check(junction_image.save_png("/tmp/metro-night-junction.png") == OK, "Could not capture restrained junction illumination.")
	lines.pop_back()
	var junction_graph := TransitGraph.new()
	for position: Vector2 in [Vector2.ZERO, Vector2(-384, 0), Vector2(384, 0), Vector2(0, -384), Vector2(0, 384)]:
		junction_graph.add_station(position)
	var horizontal := TransitLine.new(0, line.color)
	for station_id in [1, 0, 2]:
		horizontal.append_station(junction_graph, station_id)
	var vertical := TransitLine.new(1, Color("#d8758b"))
	for station_id in [3, 0, 4]:
		vertical.append_station(junction_graph, station_id)
	var junction_lines: Array[TransitLine] = [horizontal, vertical]
	view.set_network(junction_graph, junction_lines)
	camera.zoom = Vector2.ONE * 4.0
	camera.reset_smoothing()
	view.set_dynamic_state([], camera.position, camera.zoom, 0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	junction_image = root.get_texture().get_image()
	for probe: Vector2 in [Vector2(26, 8), Vector2(-8, 26)]:
		var expected := horizontal.color if probe.x > 0 else vertical.color
		var pixel := Vector2i(view.get_global_transform_with_canvas() * probe)
		_check(_difference(junction_image.get_pixelv(pixel), expected.darkened(0.3)) < 0.1, "A real perpendicular interchange must retain dark rails rather than glowing cross arms.")
	_check(junction_image.save_png("/tmp/metro-night-junction.png") == OK, "Could not capture the perpendicular night interchange.")
	var corner_graph := TransitGraph.new()
	var corner_line := TransitLine.new(0, Color("#58b8bd"))
	var corner_lines: Array[TransitLine] = [corner_line]
	var corner_path := PackedVector2Array([Vector2(-100, 0), Vector2.ZERO, Vector2(0, 100)])
	var corner_route := {"points": corner_path, "centerline": corner_path, "running_paths": [corner_path], "length": 200.0}
	view.set_network(corner_graph, corner_lines, {0: corner_route})
	camera.zoom = Vector2.ONE * 8.0
	camera.reset_smoothing()
	view.set_dynamic_state([], camera.position, camera.zoom, 0.0)
	for polygon: PackedVector2Array in view.get("_rail_halo_polygons"):
		_check(not Geometry2D.triangulate_polygon(polygon).is_empty(), "Rail glow must be a simple merged polygon rather than overlapping stroke triangles.")
	for halo: MeshInstance2D in view.get("_rail_halos"):
		halo.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var no_halo := root.get_texture().get_image()
	for halo: MeshInstance2D in view.get("_rail_halos"):
		halo.show()
	await process_frame
	await RenderingServer.frame_post_draw
	var corner_image := root.get_texture().get_image()
	var square_corner := Vector2i(view.get_global_transform_with_canvas() * Vector2(14.5, -14.5))
	var round_edge := Vector2i(view.get_global_transform_with_canvas() * Vector2(-40, -14.5))
	_check(_difference(corner_image.get_pixelv(square_corner), no_halo.get_pixelv(square_corner)) < 0.01, "A sharp rail turn must not illuminate the square outside its circular glow radius.")
	_check(_difference(corner_image.get_pixelv(round_edge), no_halo.get_pixelv(round_edge)) > 0.02, "Round-joined glow must retain visible illumination beside straight rails.")
	_check(corner_image.save_png("/tmp/metro-glow-corner.png") == OK, "Could not capture rounded nighttime rail glow.")
	var tight_curve := PackedVector2Array()
	for index in range(25):
		tight_curve.append(Vector2.from_angle(float(index) * PI * 0.5 / 24.0) * 4.0)
	for polygon: PackedVector2Array in WorldView._halo_polygons(tight_curve, 30.0):
		_check(not Geometry2D.triangulate_polygon(polygon).is_empty(), "A halo wider than its bend radius must resolve to a simple outline without folded geometry.")
	var loop_path := PackedVector2Array([Vector2(-50, -50), Vector2(50, -50), Vector2(50, 50), Vector2(-50, 50), Vector2(-50, -50)])
	var loop_halos := WorldView._halo_polygons(loop_path, 30.0)
	for polygon: PackedVector2Array in loop_halos:
		_check(not Geometry2D.is_point_in_polygon(Vector2.ZERO, polygon), "Merged loop glow must preserve the unlit interior hole.")
		_check(not Geometry2D.triangulate_polygon(polygon).is_empty(), "Loop halos must split into renderable polygons without filling their holes.")
	var s_curve := TrackGeometry.round_corners(PackedVector2Array([Vector2(-40, -100), Vector2(-40, 0), Vector2(40, 0), Vector2(40, 100)]))
	for lane_offset: float in [-8.0, 8.0]:
		var lane := TrackGeometry.offset_points(s_curve, lane_offset)
		var polygons := WorldView._halo_polygons(lane, 30.0)
		for polygon: PackedVector2Array in polygons:
			for vertex: Vector2 in polygon:
				_check(TrackGeometry.closest_point(lane, vertex).distance_to(vertex) <= 15.1, "Tight S-bend halo boundaries must stay within their uniform offset radius, without spikes.")
		for x in range(-60, 61, 3):
			for y in range(-30, 31, 3):
				var count := 0
				for polygon: PackedVector2Array in polygons:
					if Geometry2D.is_point_in_polygon(Vector2(x, y), polygon):
						count += 1
				_check(count <= 1, "Each S-bend glow layer must cover a pixel at most once, not stack folded triangles.")
	var s_route := {"points": s_curve, "centerline": s_curve, "running_paths": [TrackGeometry.offset_points(s_curve, -8), TrackGeometry.offset_points(s_curve, 8)], "length": TrackGeometry.length(s_curve)}
	view.set_network(corner_graph, corner_lines, {0: s_route})
	camera.zoom = Vector2.ONE * 4.0
	camera.reset_smoothing()
	view.set_dynamic_state([], camera.position, camera.zoom, 0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("/tmp/metro-glow-s-bend.png") == OK, "Could not capture uniform merged S-bend halos.")
	var station_graph := TransitGraph.new()
	for position: Vector2 in [Vector2(0, 576), Vector2.ZERO, Vector2(576, 0)]:
		station_graph.add_station(position)
	var station_line := TransitLine.new(0, Color("#58b8bd"))
	for id: int in [0, 1, 2]:
		station_line.append_station(station_graph, id)
	var station_lines: Array[TransitLine] = [station_line]
	var station_route := TrackGeometry.circuit(station_graph, station_line, station_lines)
	view.set_network(station_graph, station_lines, {0: station_route})
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE * 10.0
	camera.reset_smoothing()
	for phase: float in [0.5, 0.0, 0.25, 0.75]:
		view.set_dynamic_state([], camera.position, camera.zoom, phase)
		await process_frame
		await RenderingServer.frame_post_draw
		var centered_image := root.get_texture().get_image()
		_check(centered_image.save_png("/tmp/metro-centered-station-%s.png" % phase) == OK, "Could not capture the centered corner station and solar lighting.")
		var center := Vector2i(view.get_global_transform_with_canvas() * Vector2.ZERO)
		_check(centered_image.get_pixelv(center).get_luminance() > 0.5, "Centered corner station must retain its opaque center.")
		var station_centerline: PackedVector2Array = station_route["centerline"]
		_check(TrackGeometry.closest_point(station_centerline, Vector2.ZERO).length() < 4.3, "Rendered station must retain original tight rounding without a broad outward sweep.")
		for point: Vector2 in station_centerline:
			if point.length() < 16.0 or point.length() > 35.0:
				continue
			var pixel := Vector2i(view.get_global_transform_with_canvas() * point)
			_check(_difference(centered_image.get_pixelv(pixel), station_line.color) < 0.025, "Station ground shadows must not darken the track surface, including dawn and sunset.")
	camera.position = Vector2(300, 0)
	camera.zoom = Vector2.ONE * 6.0
	camera.reset_smoothing()
	view.set_dynamic_state([], camera.position, camera.zoom, 0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	var track_image := root.get_texture().get_image()
	view.set_network(TransitGraph.new(), [])
	await process_frame
	await RenderingServer.frame_post_draw
	var bare_surface := root.get_texture().get_image()
	var shadow_pixel := Vector2i(view.get_global_transform_with_canvas() * Vector2(300, 16))
	var shadow_delta := _difference(track_image.get_pixelv(shadow_pixel), bare_surface.get_pixelv(shadow_pixel))
	_check(shadow_delta > 0.005 and shadow_delta < 0.2, "Whole-track shadow must be visible but light on the background.")
	var shadow_graph := TransitGraph.new()
	shadow_graph.add_station(Vector2(0, -576))
	shadow_graph.add_station(Vector2(0, 576))
	var shadow_line := TransitLine.new(0, Color("#58b8bd"))
	shadow_line.append_station(shadow_graph, 0)
	shadow_line.append_station(shadow_graph, 1)
	var shadow_lines: Array[TransitLine] = [shadow_line]
	var shadow_route := TrackGeometry.circuit(shadow_graph, shadow_line, shadow_lines)
	camera.position = Vector2.ZERO
	camera.reset_smoothing()
	for phase: float in [0.25, 0.75, 0.0]:
		view.set_network(TransitGraph.new(), [])
		view.set_dynamic_state([], camera.position, camera.zoom, phase)
		await process_frame
		await RenderingServer.frame_post_draw
		var bare := root.get_texture().get_image()
		view.set_network(shadow_graph, shadow_lines, {0: shadow_route})
		for halo: MeshInstance2D in view.get("_rail_halos"):
			halo.hide()
		await process_frame
		await RenderingServer.frame_post_draw
		var shaded := root.get_texture().get_image()
		var right := Vector2i(view.get_global_transform_with_canvas() * Vector2(18, 0))
		var left := Vector2i(view.get_global_transform_with_canvas() * Vector2(-18, 0))
		var right_difference := _difference(shaded.get_pixelv(right), bare.get_pixelv(right))
		var left_difference := _difference(shaded.get_pixelv(left), bare.get_pixelv(left))
		if phase == 0.25:
			_check(right_difference > 0.05 and left_difference < 0.005, "A left-side sunrise must cast the stronger track shadow to the right (%.4f / %.4f)." % [right_difference, left_difference])
		elif phase == 0.75:
			_check(left_difference > 0.05 and right_difference < 0.005, "A right-side sunset must cast the stronger track shadow to the left (%.4f / %.4f)." % [left_difference, right_difference])
	view.set_network(shadow_graph, shadow_lines, {0: shadow_route})
	var isolated := shadow_graph.add_station(Vector2(72, 0))
	view.set_dynamic_state([], camera.position, camera.zoom, 0.75)
	await process_frame
	await RenderingServer.frame_post_draw
	var isolated_image := root.get_texture().get_image()
	var former_shadow := Vector2i(view.get_global_transform_with_canvas() * (isolated.position + Vector2(-18, 3)))
	shadow_graph.stations.remove_at(2)
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	_check(_difference(isolated_image.get_pixelv(former_shadow), root.get_texture().get_image().get_pixelv(former_shadow)) < 0.005, "Stations must not cast any shadow on the surrounding surface.")
	await _check_crossing_layers(view, camera)
	await _check_overview_trains(view, camera)
	for axis: Vector2 in [Vector2(1, 1), Vector2.RIGHT]:
		await _check_panning_edges(view, camera, axis)
	world.queue_free()
	await process_frame
	if failed:
		quit(1)
	else:
		print("Train visual smoke passed: metro details, transient zoomed platforms, tiny passengers, articulated gangways, soft headlights, layered crossings and reduced panning shimmer.")
		quit()

func _difference(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

func _check_crossing_layers(view: WorldView, camera: Camera2D) -> void:
	var graph := TransitGraph.new()
	for position: Vector2 in [Vector2(-576, 0), Vector2(576, 0), Vector2(0, -576), Vector2(0, 576)]:
		graph.add_station(position)
	var lower := TransitLine.new(0, Color("#ffd400"))
	lower.append_station(graph, 0)
	lower.append_station(graph, 1)
	var upper := TransitLine.new(1, Color("#d8758b"))
	upper.append_station(graph, 2)
	upper.append_station(graph, 3)
	var lines: Array[TransitLine] = [lower, upper]
	view.set_network(graph, lines)
	var routes: Dictionary = view.get("_routes")
	var train := Metro.new(0, 0, Vector2.ZERO)
	train.wagon_count = 2
	var upper_train := Metro.new(1, 1, Vector2.ZERO)
	upper_train.wagon_count = 2
	camera.position = Vector2.ZERO
	for zoom: float in [1.0, 6.0]:
		camera.zoom = Vector2.ONE * zoom
		camera.reset_smoothing()
		for phase: float in [0.5, 0.0]:
			view.set_dynamic_state([], camera.position, camera.zoom, phase)
			await process_frame
			await RenderingServer.frame_post_draw
			var empty := root.get_texture().get_image()
			for direction: int in [1, -1]:
				train.travel_direction = direction
				var route := TrackGeometry.route_for_direction(routes[0], direction)
				var location := TrackGeometry._distance_to_point(route["points"], Vector2.ZERO, 0)
				if direction < 0:
					location = TrackGeometry._distance_to_point(route["points"], Vector2.ZERO, int(location.y) + 1)
				train.distance = location.x
				var poses := view._build_train_poses(train, route)
				var positions: PackedVector2Array = poses["positions"]
				var covered := Vector2i(view.get_global_transform_with_canvas() * positions[0])
				var uncovered := Vector2i(view.get_global_transform_with_canvas() * (positions[2] + Vector2(1.0, 1.0)))
				view.set_dynamic_state([train], camera.position, camera.zoom, phase)
				await process_frame
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				_check(_difference(image.get_pixelv(covered), empty.get_pixelv(covered)) < 0.005, "Upper tracks must completely cover a lower train in both directions, by day/night at map/follow zoom.")
				for x in range(-12, 13, 2):
					for y in range(-20, 21, 2):
						var pixel := Vector2i(view.get_global_transform_with_canvas() * Vector2(x, y))
						_check(_difference(image.get_pixelv(pixel), empty.get_pixelv(pixel)) < 0.005, "Upper track surfaces must occlude lower cars, gangways, shadows and headlights across their full width.")
				_check(_difference(image.get_pixelv(uncovered), empty.get_pixelv(uncovered)) > 0.1, "The same lower train must remain visible outside the crossing.")
				if phase == 0.0:
					var axes: PackedVector2Array = poses["axes"]
					var beam_point := positions[0] + axes[0] * 8.0
					var beam_pixel := Vector2i(view.get_global_transform_with_canvas() * beam_point)
					_check(_difference(image.get_pixelv(beam_pixel), empty.get_pixelv(beam_pixel)) < 0.005, "A lower train's headlights must not shine through the upper track.")
			upper_train.distance = TrackGeometry._distance_to_point(routes[1]["points"], Vector2.ZERO, 0).x
			var upper_poses := view._build_train_poses(upper_train, routes[1])
			var upper_positions: PackedVector2Array = upper_poses["positions"]
			var top_pixel := Vector2i(view.get_global_transform_with_canvas() * (upper_positions[0] + Vector2(1.0, 1.0)))
			view.set_dynamic_state([train, upper_train], camera.position, camera.zoom, phase)
			await process_frame
			await RenderingServer.frame_post_draw
			_check(_difference(root.get_texture().get_image().get_pixelv(top_pixel), empty.get_pixelv(top_pixel)) > 0.1, "An upper train must remain visible above both tracks and lower trains.")
	# Reusing line IDs on load must replace the retained track's color and model.
	var replacement := TransitLine.new(1, Color("#9ba85e"))
	replacement.append_station(graph, 2)
	replacement.append_station(graph, 3)
	view.set_network(graph, [lower, replacement])
	view.set_dynamic_state([], camera.position, camera.zoom, 0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	var center := Vector2i(view.get_global_transform_with_canvas() * Vector2.ZERO)
	_check(_difference(root.get_texture().get_image().get_pixelv(center), replacement.color) < 0.025, "Loading a new line with an existing ID must replace its retained track model.")
	var reversed: Array[TransitLine] = [replacement, lower]
	view.set_network(graph, reversed)
	view.set_dynamic_state([], camera.position, camera.zoom, 0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	var reversed_empty := root.get_texture().get_image()
	train.travel_direction = 1
	train.distance = TrackGeometry._distance_to_point(routes[0]["points"], Vector2.ZERO, 0).x
	view.set_dynamic_state([train], camera.position, camera.zoom, 0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	var lower_poses := view._build_train_poses(train, routes[0])
	var lower_positions: PackedVector2Array = lower_poses["positions"]
	var raised := Vector2i(view.get_global_transform_with_canvas() * (lower_positions[0] + Vector2(1.0, 1.0)))
	_check(_difference(root.get_texture().get_image().get_pixelv(raised), reversed_empty.get_pixelv(raised)) > 0.1, "Changing track draw order must raise the matching trains as well.")

func _check_panning_edges(view: WorldView, camera: Camera2D, axis: Vector2) -> void:
	var graph := TransitGraph.new()
	graph.add_station(axis * -576.0)
	graph.add_station(axis * 576.0)
	var line := TransitLine.new(0, Color("#58b8bd"))
	line.append_station(graph, 0)
	line.append_station(graph, 1)
	var lines: Array[TransitLine] = [line]
	view.set_network(graph, lines)
	var route: Dictionary = view.get("_routes")[0]
	var train := Metro.new(0, 0, Vector2.ZERO)
	train.wagon_count = 2
	train.distance = TrackGeometry._distance_to_point(route["points"], Vector2.ZERO, 0).x
	var poses := view._build_train_poses(train, route)
	var positions: PackedVector2Array = poses["positions"]
	var normal := axis.orthogonal().normalized()
	var regions: Array[Rect2i] = []
	for phase: float in [0.5, 0.0]:
		for zoom: float in [2.0, 5.0]:
			camera.zoom = Vector2.ONE * zoom
			var changes: Array[PackedFloat32Array] = []
			var unfiltered: Image
			for enabled: bool in [false, true]:
				view.set_motion_antialiasing(enabled)
				var previous: Image
				var peaks := PackedFloat32Array([0.0, 0.0])
				for step in range(17):
					camera.position = normal * (float(step) * 0.125 / zoom)
					camera.reset_smoothing()
					camera.force_update_scroll()
					view.set_dynamic_state([train], camera.position, camera.zoom, phase)
					await process_frame
					await RenderingServer.frame_post_draw
					var image := root.get_texture().get_image()
					if step == 0:
						if not enabled:
							unfiltered = image
						else:
							for corner: Vector2i in [Vector2i(16, 16), root.size - Vector2i(16, 16)]:
								_check(_difference(image.get_pixelv(corner), unfiltered.get_pixelv(corner)) < 0.005, "Edge smoothing must leave low-contrast matte background pixels unchanged.")
						regions.clear()
						for position: Vector2 in [axis * 45.0 + normal * 14.0, positions[1]]:
							var center := Vector2i(view.get_global_transform_with_canvas() * position)
							regions.append(Rect2i(center - Vector2i(16, 16), Vector2i(32, 32)))
					if previous != null:
						for index in range(regions.size()):
							var peak := 0.0
							var region := regions[index]
							for y in range(region.position.y, region.end.y):
								for x in range(region.position.x, region.end.x):
									peak = maxf(peak, absf(image.get_pixel(x, y).get_luminance() - previous.get_pixel(x, y).get_luminance()))
							peaks[index] += peak
					previous = image
				changes.append(peaks)
			print("Pan edge changes axis=%s day=%.1f zoom=%.1f: raw %s, smoothed %s" % [axis, phase, zoom, changes[0], changes[1]])
			for index in range(regions.size()):
				_check(changes[0][index] > 0.1 and changes[1][index] < changes[0][index] * 0.8, "Screen-space smoothing must reduce peak frame-to-frame edge shimmer by at least 20%% for tracks and trains (phase %.1f, zoom %.1f, region %d)." % [phase, zoom, index])
			view.set_motion_antialiasing(false)
			camera.position = Vector2.ZERO
			camera.reset_smoothing()
			camera.force_update_scroll()
			view.set_dynamic_state([train], camera.position, camera.zoom, phase)
			await process_frame
			await RenderingServer.frame_post_draw
			_check(root.get_texture().get_image().get_data() == unfiltered.get_data(), "Disabling screensaver smoothing must restore the exact unfiltered frame.")
	view.set_motion_antialiasing(false)

func _check_overview_trains(view: WorldView, camera: Camera2D) -> void:
	var graph := TransitGraph.new()
	for position: Vector2 in [Vector2(-24000, 0), Vector2(24000, 0), Vector2(0, -24000), Vector2(0, 24000)]:
		graph.add_station(position)
	var lower := TransitLine.new(0, Color("#58b8bd"))
	lower.append_station(graph, 0)
	lower.append_station(graph, 1)
	var upper := TransitLine.new(1, Color("#d8758b"))
	upper.append_station(graph, 2)
	upper.append_station(graph, 3)
	var lines: Array[TransitLine] = [lower]
	view.set_network(graph, lines)
	var route: Dictionary = view.get("_routes")[0]
	var train := Metro.new(0, 0, Vector2.ZERO)
	train.wagon_count = 3
	var head := TrackGeometry._distance_to_point(route["points"], Vector2.ZERO, 0).x
	train.distance = head - 200.0
	train.render_distance = head
	train.render_pose_valid = true
	camera.position = Vector2.ZERO
	for zoom: float in [0.02, 0.08, 0.15, 0.4, 0.79]:
		camera.zoom = Vector2.ONE * zoom
		camera.reset_smoothing()
		camera.force_update_scroll()
		for phase: float in [0.5, 0.0]:
			view.set_dynamic_state([], camera.position, camera.zoom, phase)
			await process_frame
			await RenderingServer.frame_post_draw
			var empty := root.get_texture().get_image()
			_seed_overview_trail(view, camera, train, head, phase)
			await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var poses := view._build_train_poses(train, route)
			_check(poses.has("overview_path"), "Far zoom must replace subpixel cars with a pulse dot and rail-following tail.")
			var path: PackedVector2Array = poses["overview_path"]
			var center := Vector2i(view.get_global_transform_with_canvas() * path[path.size() - 1])
			var changed := 0
			var threshold := 0.02 if zoom == 0.02 and phase == 0.5 else 0.2
			var bounds := Rect2i(center, Vector2i.ZERO)
			for y in range(center.y - 5, center.y + 6):
				for x in range(center.x - 20, center.x + 6):
					if _difference(image.get_pixel(x, y), empty.get_pixel(x, y)) > threshold:
						changed += 1
						bounds = bounds.expand(Vector2i(x, y))
			_check(changed >= 12 and bounds.size.x >= 4 and bounds.size.y >= 1, "Pulse heads must remain visible even when the train-length tail is subpixel (zoom %.2f, phase %.1f, %d pixels, %s)." % [zoom, phase, changed, bounds.size])
			if zoom <= WorldView.OVERVIEW_BLEND_START:
				_check(image.get_pixelv(center).get_luminance() > 0.95, "The pulse head must have an opaque white center outside the zoom blend.")
			var bright := image.get_pixelv(center)
			var faint := image.get_pixelv(center + Vector2i(-17, 0))
			if phase == 0.0 and zoom <= WorldView.OVERVIEW_BLEND_START:
				_check(bright.get_luminance() > faint.get_luminance() + 0.1, "The pulse head must be visibly brighter than its fading tail.")
				_check(bounds.size.y >= 3, "The pulse dot must be thicker than its thin tail.")
				for offset: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0)]:
					_check(image.get_pixelv(center + offset).get_luminance() > 0.9, "The pulse head must be a white disc, not just a bright line endpoint.")
			if zoom <= 0.4:
				_check(image.get_pixelv(center + Vector2i(0, -3)).get_luminance() < 0.35, "The white pulse head must have a dark contrasting outline.")
			if zoom == 0.4 and phase == 0.0:
				_check(image.get_pixelv(center + Vector2i(-5, 0)).get_luminance() > image.get_pixelv(center + Vector2i(-17, 0)).get_luminance() + 0.1, "The whole train-length trace must have a strong brightness gradient, even when moving too fast for appreciable sample ageing.")
				view.set_dynamic_state([train], camera.position, camera.zoom, phase, [], 0.4)
				await process_frame
				await RenderingServer.frame_post_draw
				var eroding := root.get_texture().get_image()
				var near := center + Vector2i(-5, 0)
				var rear := center + Vector2i(-34, 0)
				_check(_difference(eroding.get_pixelv(rear), empty.get_pixelv(rear)) < 0.01, "The rear of a stopped comet must clear first as its tip advances toward the head.")
				var initial_contrast := _difference(image.get_pixelv(near), empty.get_pixelv(near))
				var retained_contrast := _difference(eroding.get_pixelv(near), empty.get_pixelv(near))
				_check(retained_contrast > 0.1 and retained_contrast >= initial_contrast * 0.75, "The front must retain at least 75%% of its contrast while the rear disappears, not fade globally (initial %.3f, retained %.3f)." % [initial_contrast, retained_contrast])
			var detail_layer: Node2D = view._train_layers[0]
			var overview_layer: Node2D = view._overview_layers[0]
			_check(is_equal_approx(overview_layer.modulate.a, view.overview_opacity(zoom)) and is_equal_approx(detail_layer.modulate.a, 1.0 - view.overview_opacity(zoom)), "Marker and detailed layers must crossfade with complementary smooth opacities.")
			if zoom <= 0.15:
				view.set_motion_antialiasing(true)
				await process_frame
				await RenderingServer.frame_post_draw
				var smoothed := root.get_texture().get_image()
				var roof_pixel := center + Vector2i(-2, 0)
				_check(_difference(smoothed.get_pixelv(roof_pixel), empty.get_pixelv(roof_pixel)) > threshold, "Pulse dots must remain distinct with screensaver edge smoothing.")
				view.set_motion_antialiasing(false)
			if zoom == 0.15 and phase == 0.0:
				var tail_pixel := center + Vector2i(-8, 0)
				view.set_dynamic_state([train], camera.position, camera.zoom, phase, [], 0.4)
				await process_frame
				await RenderingServer.frame_post_draw
				var fading := root.get_texture().get_image()
				_check(image.get_pixelv(tail_pixel).get_luminance() > fading.get_pixelv(tail_pixel).get_luminance() + 0.05, "A stationary train's trail must visibly fade as its history ages.")
				view.set_dynamic_state([train], camera.position, camera.zoom, phase, [], 0.7)
				await process_frame
				await RenderingServer.frame_post_draw
				var stopped := root.get_texture().get_image()
				var expired_tail_pixel := center + Vector2i(-6, 0)
				_check(_difference(stopped.get_pixelv(expired_tail_pixel), empty.get_pixelv(expired_tail_pixel)) < 0.01, "A stopped train must lose its trail after one second outside the head glow.")
				_check(stopped.get_pixelv(center).get_luminance() > 0.95, "The outlined white head must remain visible after its trail disappears.")
	view.view_zoom = Vector2.ONE * WorldView.OVERVIEW_TRAIN_ZOOM
	_check(not view._build_train_poses(train, route).has("overview_path"), "Detailed cars must resume at the overview threshold.")
	lines.append(upper)
	view.set_network(graph, lines)
	for zoom: float in [0.08, 0.15, 0.4, 0.65]:
		camera.zoom = Vector2.ONE * zoom
		camera.force_update_scroll()
		view.set_dynamic_state([], camera.position, camera.zoom, 0.5)
		await process_frame
		await RenderingServer.frame_post_draw
		var empty := root.get_texture().get_image()
		_seed_overview_trail(view, camera, train, head, 0.5)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := view.overview_train_path(train, route, zoom)
		var transform := view.get_global_transform_with_canvas()
		var covered := Vector2i(transform * path[path.size() - 1]) + Vector2i(-1, 0)
		_check(_difference(image.get_pixelv(covered), empty.get_pixelv(covered)) < 0.005, "Upper tracks must occlude the enlarged lower overview marker.")
		var exposed_difference := 0.0
		for local_y in range(-1, 2):
			var offset := mini(10, maxi(3, roundi(TrackGeometry.train_length(train.wagon_count) * zoom * 0.35)))
			var exposed := Vector2i(transform * path[path.size() - 1]) + Vector2i(-offset, local_y)
			exposed_difference = maxf(exposed_difference, _difference(image.get_pixelv(exposed), empty.get_pixelv(exposed)))
		_check(exposed_difference > 0.05, "Only the covered portion of an overview marker may be hidden (zoom %.2f, contrast %.3f)." % [zoom, exposed_difference])
	lower.render_priority = 1
	view.set_network(graph, lines)
	view.set_dynamic_state([train], camera.position, camera.zoom, 0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	var raised := root.get_texture().get_image()
	var path := view.overview_train_path(train, route, camera.zoom.x)
	var center := Vector2i(view.get_global_transform_with_canvas() * path[path.size() - 1])
	_check(_difference(raised.get_pixelv(center + Vector2i(-1, 0)), upper.color) > 0.2, "Render priority must raise the first line's comet over later tracks.")
	var tracks: StaticTrackLayer = view.get("_static_tracks")
	_check(tracks.line_layer(0).get_index() > tracks.line_layer(1).get_index(), "Render priority must override array order without changing line IDs.")
	camera.zoom = Vector2.ONE
	camera.force_update_scroll()
	view.set_dynamic_state([train], camera.position, camera.zoom, 0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	var detailed := root.get_texture().get_image()
	var detailed_poses := view._build_train_poses(train, route)
	var positions: PackedVector2Array = detailed_poses["positions"]
	var roof := Vector2i(view.get_global_transform_with_canvas() * positions[1])
	_check(_difference(detailed.get_pixelv(roof), Color("#dde3e2")) < 0.05, "Priority must raise detailed cars as well as overview markers.")
	var rail := Vector2i(view.get_global_transform_with_canvas() * Vector2.ZERO)
	_check(_difference(detailed.get_pixelv(rail), lower.color) < 0.025, "Priority must raise the complete rail corridor, not just its trains.")
	var station := graph.add_station(Vector2.ZERO)
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var station_pixel := Vector2i(view.get_global_transform_with_canvas() * station.position)
	_check(root.get_texture().get_image().get_pixelv(station_pixel).get_luminance() > 0.95, "Stations must stay above overview markers, including raised lines.")

func _seed_overview_trail(view: WorldView, camera: Camera2D, train: Metro, head: float, phase: float) -> void:
	view._train_trails.clear()
	train.render_distance = head - 36.0 / camera.zoom.x
	view.set_dynamic_state([train], camera.position, camera.zoom, phase)
	for step in range(1, 31):
		train.render_distance = head - (1.0 - float(step) / 30.0) * 36.0 / camera.zoom.x
		view.set_dynamic_state([train], camera.position, camera.zoom, phase, [], 1.0 / 30.0)
