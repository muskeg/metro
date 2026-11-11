extends SceneTree

const MAIN := preload("res://scenes/main.tscn")
const SAMPLES := 600
const LOOKUPS := 2000
var failed := false

class ProfileView extends WorldView:
	var stages: Dictionary = {}
	var omit := ""

	func _record(stage: String, started: int) -> void:
		stages[stage] = float(stages.get(stage, 0.0)) + Time.get_ticks_usec() - started

	func _draw() -> void:
		_static_tracks.set_shadow_render_mode(omit == "legacy_ground", omit != "shadows")
		var started := Time.get_ticks_usec()
		super._draw()
		_record("draw_total", started)

	func _build_train_poses(train: Metro, route: Dictionary) -> Dictionary:
		var started := Time.get_ticks_usec()
		var poses := super._build_train_poses(train, route)
		_record("train_poses", started)
		return poses

	func _draw_line_trains(layer: Node2D, line: TransitLine) -> void:
		var started := Time.get_ticks_usec()
		super._draw_line_trains(layer, line)
		_record("draw_total", started)

	func _draw_train(train: Metro, color: Color, poses: Dictionary, target: Node2D) -> void:
		if omit == "trains":
			return
		var started := Time.get_ticks_usec()
		super._draw_train(train, color, poses, target)
		_record("trains", started)

	func _draw_sun_shadows(train_poses: Dictionary, target: Node2D) -> void:
		if omit == "shadows":
			return
		var started := Time.get_ticks_usec()
		super._draw_sun_shadows(train_poses, target)
		_record("train_shadows", started)

	func _draw_ground_shadows() -> void:
		if omit == "shadows":
			return
		var started := Time.get_ticks_usec()
		if omit == "legacy_ground":
			var opacity := BACKDROP.shadow_opacity(time_of_day)
			if opacity >= 0.001:
				draw_set_transform(BACKDROP.shadow_offset(time_of_day) * 0.45)
				for polygon: PackedVector2Array in _track_shadows:
					draw_colored_polygon(polygon, Color(0.12, 0.17, 0.23, opacity * 0.36))
				draw_set_transform(Vector2.ZERO)
		else:
			super._draw_ground_shadows()
		_record("ground_shadows", started)

	func _draw_headlights(poses: Dictionary, target: Node2D) -> void:
		if omit == "headlights":
			return
		var started := Time.get_ticks_usec()
		if omit == "legacy_ground":
			_legacy_headlights(poses, target)
		else:
			super._draw_headlights(poses, target)
		_record("headlights", started)

	func _legacy_headlights(poses: Dictionary, target: Node2D) -> void:
		var positions: PackedVector2Array = poses["positions"]
		var axes: PackedVector2Array = poses["axes"]
		if positions.is_empty():
			return
		target.draw_set_transform(positions[0], axes[0].angle())
		var strength := 0.42 * _night_strength()
		if strength > 0.001:
			for side: float in [-1.0, 1.0]:
				var source := Vector2(5.0 * TrackGeometry.CAR_SCALE, side * 2.0)
				for radius: float in [5.0, 3.5, 2.0]:
					target.draw_circle(source, radius, Color(1.0, 0.91, 0.69, strength * 0.22), true, -1.0, true)
				for section in range(24):
					var a := float(section) / 24.0
					var b := float(section + 1) / 24.0
					var alpha_a := strength * pow(1.0 - a, 2.0)
					var alpha_b := strength * pow(1.0 - b, 2.0)
					for half: float in [-1.0, 1.0]:
						var vertices := PackedVector2Array([source + Vector2(lerpf(0.0, 50.0, a), 0), source + Vector2(lerpf(0.0, 50.0, b), 0), source + Vector2(lerpf(0.0, 50.0, b), half * lerpf(2.5, 14.0, b)), source + Vector2(lerpf(0.0, 50.0, a), half * lerpf(2.5, 14.0, a))])
						target.draw_polygon(vertices, PackedColorArray([Color(1.0, 0.91, 0.69, alpha_a), Color(1.0, 0.91, 0.69, alpha_b), Color(1.0, 0.91, 0.69, 0.0), Color(1.0, 0.91, 0.69, 0.0)]))
		target.draw_set_transform(Vector2.ZERO)

	func _draw_car_shell(half_length: float, half_width: float, color: Color, cab_end: int, target: Node2D) -> void:
		if omit != "legacy_ground":
			super._draw_car_shell(half_length, half_width, color, cab_end, target)
			return
		var left_bevel := 1.2 if cab_end < 0 else 0.6
		var right_bevel := 1.2 if cab_end > 0 else 0.6
		target.draw_colored_polygon(PackedVector2Array([
			Vector2(-half_length + left_bevel, -half_width), Vector2(half_length - right_bevel, -half_width),
			Vector2(half_length, -half_width + right_bevel), Vector2(half_length, half_width - right_bevel),
			Vector2(half_length - right_bevel, half_width), Vector2(-half_length + left_bevel, half_width),
			Vector2(-half_length, half_width - left_bevel), Vector2(-half_length, -half_width + left_bevel)
		]), color)

	func _poses_visible(poses: Dictionary) -> bool:
		return true if omit == "legacy_ground" else super._poses_visible(poses)

	func _draw_station_visit(visit: StationVisit, target: Node2D) -> void:
		if omit == "platforms":
			return
		var started := Time.get_ticks_usec()
		super._draw_station_visit(visit, target)
		_record("platforms", started)

func _initialize() -> void:
	_run.call_deferred()

func _stats(label: String, values: Array[float]) -> void:
	values.sort()
	var total := 0.0
	for value in values:
		total += value
	print("%s: mean=%.3f p50=%.3f p95=%.3f p99=%.3f max=%.3f ms n=%d" % [
		label, total / values.size(), values[values.size() / 2],
		values[ceili(values.size() * 0.95) - 1], values[ceili(values.size() * 0.99) - 1],
		values.back(), values.size()])

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var presets: Array[String] = []
	for argument: String in arguments:
		if argument in ["metro_demo", "montreal", "jr_east"]:
			presets.append(argument)
		elif argument not in ["--render", "--fleet"]:
			push_error("Unknown probe argument: %s" % argument)
			quit(1)
			return
	if presets.is_empty():
		presets.assign(["metro_demo", "montreal", "jr_east"])
	var graphical := "--render" in arguments
	if graphical and DisplayServer.get_name() == "headless":
		push_error("--render requires a graphical display.")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("Godot=%s display=%s adapter=%s rendering=%s" % [
		Engine.get_version_info()["string"], DisplayServer.get_name(),
		RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method()])
	var app := MAIN.instantiate()
	app.startup_layout_enabled = false
	app.settings_path = "user://performance-probe-settings.cfg"
	var ready_started := Time.get_ticks_usec()
	root.add_child(app)
	print("empty scene ready (includes audio synthesis if graphical)=%.3f ms" % ((Time.get_ticks_usec() - ready_started) / 1000.0))
	app.set_process(false)
	var original: WorldView = app.world_view
	var view := ProfileView.new()
	app.add_child(view)
	app.world_view = view
	original.queue_free()
	await process_frame
	root.size = Vector2i(1180, 740)
	var store := LayoutStore.new()
	for preset: String in presets:
		var started := Time.get_ticks_usec()
		var restored := store.load_bundled_layout("res://layouts/%s.json" % preset)
		if restored.is_empty():
			push_error(store.error_message)
			quit(1)
			return
		print("\n%s restore=%.3f ms" % [preset, (Time.get_ticks_usec() - started) / 1000.0])
		started = Time.get_ticks_usec()
		app._replace_layout(restored, true)
		print("route + illumination + UI rebuild=%.3f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
		if "--fleet" in arguments:
			await _fleet_probe(app, view, graphical)
			continue
		for tick in range(3600):
			app.dispatcher.process(1.0 / 60.0, false)
		var times: Array[float] = []
		var arrival_times: Array[float] = []
		for tick in range(SAMPLES):
			var arrivals: int = app.dispatcher.arrival_count
			started = Time.get_ticks_usec()
			app.dispatcher.process(1.0 / 60.0, false)
			var elapsed := (Time.get_ticks_usec() - started) / 1000.0
			times.append(elapsed)
			if arrivals != app.dispatcher.arrival_count:
				arrival_times.append(elapsed)
		print("stations=%d tracks=%d lines=%d trains=%d visits=%d halos=%d" % [
			app.graph.stations.size(), app.graph.tracks.size(), app.lines.size(),
			app.dispatcher.metros.size(), app.dispatcher.visits.size(), view._rail_halos.size()])
		var shadow_vertices := 0
		var largest_shadow := 0
		for polygon: PackedVector2Array in view._track_shadows:
			shadow_vertices += polygon.size()
			largest_shadow = maxi(largest_shadow, polygon.size())
		print("shadow polygons=%d vertices=%d largest=%d" % [view._track_shadows.size(), shadow_vertices, largest_shadow])
		_stats("simulation 1/60 s", times)
		if not arrival_times.is_empty():
			_stats("simulation with arrivals (subset)", arrival_times)
		times.clear()
		for sample in range(SAMPLES):
			started = Time.get_ticks_usec()
			for line: TransitLine in app.lines:
				app.dispatcher.departure_headway(line)
			times.append((Time.get_ticks_usec() - started) / 1000.0)
		_stats("one headway estimate per line (not entire tick)", times)
		var longest: Dictionary = {}
		for route: Dictionary in app.dispatcher.routes.values():
			if longest.is_empty() or route["points"].size() > longest["points"].size():
				longest = route
		var points: PackedVector2Array = longest["points"]
		var cumulative: PackedFloat64Array = longest["cumulative_lengths"]
		var distances := PackedFloat64Array()
		for index in range(LOOKUPS):
			distances.append(cumulative[cumulative.size() - 1] * float(index) / LOOKUPS)
		var worst_error := 0.0
		var parity_distances := distances.duplicate()
		parity_distances.append_array(cumulative)
		for distance: float in parity_distances:
			worst_error = maxf(worst_error, TrackGeometry.point_at_distance(points, distance).distance_to(TrackGeometry.point_at_distance(points, distance, cumulative)))
		if worst_error > 0.0001:
			push_error("Indexed lookup disagrees with current geometry: %f" % worst_error)
			quit(1)
			return
		started = Time.get_ticks_usec()
		for distance: float in distances:
			TrackGeometry.point_at_distance(points, distance)
		var linear_ms := (Time.get_ticks_usec() - started) / 1000.0
		started = Time.get_ticks_usec()
		for distance: float in distances:
			TrackGeometry.point_at_distance(points, distance, cumulative)
		var indexed_ms := (Time.get_ticks_usec() - started) / 1000.0
		print("lookup points=%d count=%d linear=%.3f ms indexed=%.3f ms speedup=%.1fx error=%.6f" % [
			points.size(), LOOKUPS, linear_ms, indexed_ms, linear_ms / maxf(indexed_ms, 0.001), worst_error])
		times.clear()
		for index in range(100):
			app._clear_hover()
			started = Time.get_ticks_usec()
			app._update_hover(Vector2(100000.0 + index, 100000.0))
			times.append((Time.get_ticks_usec() - started) / 1000.0)
		_stats("hover empty space (full miss)", times)
		var stationary_pointer := Vector2(100000.0, 100000.0)
		app._clear_hover()
		app._update_hover(stationary_pointer)
		times.clear()
		for index in range(SAMPLES):
			started = Time.get_ticks_usec()
			app._update_hover(stationary_pointer)
			times.append((Time.get_ticks_usec() - started) / 1000.0)
		_stats("hover stationary pointer (cache hit)", times)
		times.clear()
		for index in range(100):
			app.lines[0].color = Color.from_hsv(float(index) / 100.0, 0.7, 0.8)
			started = Time.get_ticks_usec()
			view.refresh_line_color(app.lines[0].id)
			times.append((Time.get_ticks_usec() - started) / 1000.0)
		_stats("line recolor refresh (geometry retained)", times)
		if graphical:
			await _render_probe(app, view)
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _fleet_probe(app: Node, view: ProfileView, graphical: bool) -> void:
	var original_limits: Dictionary = {}
	for line: TransitLine in app.lines:
		original_limits[line.id] = [line.max_trains, line.dispatch_rate]
	for ceiling: int in [0, 8, 16, 40]:
		for line: TransitLine in app.lines:
			line.max_trains = original_limits[line.id][0] if ceiling == 0 else ceiling
			line.dispatch_rate = original_limits[line.id][1] if ceiling == 0 else 0.0
		app.dispatcher.rebuild_routes()
		var started := Time.get_ticks_usec()
		for tick in range(240 * 60):
			app.dispatcher.process(1.0 / 60.0, false)
		var warmup_ms := (Time.get_ticks_usec() - started) / 1000.0
		var times: Array[float] = []
		for tick in range(300):
			started = Time.get_ticks_usec()
			app.dispatcher.process(1.0 / 60.0, false)
			times.append((Time.get_ticks_usec() - started) / 1000.0)
		print("\nfleet ceiling=%s trains=%d visits=%d warmup=%.0f ms" % [
			"preset" if ceiling == 0 else str(ceiling), app.dispatcher.metros.size(), app.dispatcher.visits.size(), warmup_ms])
		_stats("fleet simulation 1/60 s", times)
		if not graphical:
			continue
		view.interaction_overlays_visible = false
		app._ui_root.hide()
		var overview: Vector2 = app.camera.zoom
		var center: Vector2 = app.camera.position
		for zoom: Vector2 in [overview, Vector2.ONE * 5.0]:
			app.camera.zoom = zoom
			app.camera.position = center if zoom == overview else app.dispatcher.metros[0].position
			app.camera.reset_smoothing()
			for phase: float in [0.5, 0.0]:
				view.set_dynamic_state(app.dispatcher.metros, app.camera.position, zoom, phase, app.dispatcher.visits)
				await process_frame
				view.stages.clear()
				var draws: Array[float] = []
				for frame in range(20):
					var draw_before := float(view.stages.get("draw_total", 0.0))
					view.queue_redraw()
					await process_frame
					draws.append((float(view.stages.get("draw_total", 0.0)) - draw_before) / 1000.0)
				_stats("fleet draw CPU zoom=%.2f phase=%.1f" % [zoom.x, phase], draws)
				var means: Dictionary = {}
				for stage: String in view.stages:
					means[stage] = snappedf(float(view.stages[stage]) / 20000.0, 0.01)
				print("stage mean ms/frame: %s" % means)
		app.camera.zoom = overview
		app.camera.position = center
		app.camera.reset_smoothing()
	for line: TransitLine in app.lines:
		line.max_trains = original_limits[line.id][0]
		line.dispatch_rate = original_limits[line.id][1]

func _render_probe(app: Node, view: ProfileView) -> void:
	view.interaction_overlays_visible = false
	app._ui_root.hide()
	var overview: Vector2 = app.camera.zoom
	var center: Vector2 = app.camera.position
	for zoom: Vector2 in [overview, Vector2.ONE * 5.0]:
		app.camera.zoom = zoom
		app.camera.position = center if zoom == overview else app.dispatcher.metros[0].position
		app.camera.reset_smoothing()
		for phase: float in [0.5, 0.0]:
			var reference := PackedByteArray()
			for omit: String in ["legacy_ground", "", "trains", "shadows", "headlights", "platforms"]:
				view.omit = omit
				view.set_dynamic_state(app.dispatcher.metros, app.camera.position, zoom, phase, app.dispatcher.visits)
				await process_frame
				await RenderingServer.frame_post_draw
				view.stages.clear()
				var times: Array[float] = []
				var draws: Array[float] = []
				for frame in range(30):
					var before := Time.get_ticks_usec()
					var draw_before := float(view.stages.get("draw_total", 0.0))
					view.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
					times.append((Time.get_ticks_usec() - before) / 1000.0)
					draws.append((float(view.stages.get("draw_total", 0.0)) - draw_before) / 1000.0)
				var label := "render zoom=%.3f phase=%.1f omit=%s" % [zoom.x, phase, "none" if omit.is_empty() else omit]
				_stats(label + " frame wait", times)
				_stats(label + " draw CPU", draws)
				var means: Dictionary = {}
				for stage: String in view.stages:
					means[stage] = float(view.stages[stage]) / 30000.0
				print("stage mean ms/frame: %s" % means)
				var image_data := root.get_texture().get_image().get_data()
				if omit == "legacy_ground":
					reference = image_data
				elif omit.is_empty():
					print("legacy-vs-production full-frame byte parity=%s zoom=%.3f phase=%.1f" % [image_data == reference, zoom.x, phase])
					if image_data != reference:
						failed = true
						push_error("Cached meshes and culling must preserve the frozen legacy reference pixels.")
						var differing_pixels := 0
						var largest_difference := 0
						for pixel in range(0, reference.size(), 4):
							var difference := 0
							for channel in range(4):
								difference = maxi(difference, absi(int(image_data[pixel + channel]) - int(reference[pixel + channel])))
							if difference > 0:
								differing_pixels += 1
								largest_difference = maxi(largest_difference, difference)
						print("legacy-vs-production pixel differences=%d largest channel difference=%d/255" % [differing_pixels, largest_difference])
	view.omit = ""
