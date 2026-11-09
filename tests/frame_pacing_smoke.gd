extends SceneTree

const MAIN := preload("res://scenes/main.tscn")
const STEP := 1.0 / 60.0
const MAX_STEPS := 4

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true

func _run() -> void:
	var app := MAIN.instantiate()
	app.set("startup_layout_enabled", false)
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var dispatcher: TransitDispatcher = app.get("dispatcher")
	var step := STEP
	var start_clock: float = dispatcher.get("_clock")

	app.call("_advance_simulation", step * 0.5)
	_check(is_equal_approx(dispatcher.get("_clock"), start_clock), "A partial fixed step must not advance simulation state.")
	app.call("_advance_simulation", step * 0.5)
	_check(absf(float(dispatcher.get("_clock")) - start_clock - step) < 0.000001, "Two half-frames must produce exactly one 60 Hz simulation tick.")

	var clock_after_step: float = dispatcher.get("_clock")
	app.call("_advance_simulation", 1.0)
	_check(absf(float(dispatcher.get("_clock")) - clock_after_step - step * MAX_STEPS) < 0.00001, "Catch-up must respect the per-frame work budget.")
	var backlog: float = app.get("_simulation_accumulator")
	_check(backlog > 0.8, "Unprocessed catch-up time must remain in the accumulator rather than being dropped.")
	app.set("paused", true)
	app.call("_advance_simulation", 1.0)
	_check(is_equal_approx(app.get("_simulation_accumulator"), backlog), "Pause must freeze the accumulated simulation backlog.")
	app.set("paused", false)
	var clock_before_catchup: float = dispatcher.get("_clock")
	app.call("_advance_simulation", 0.0)
	_check(absf(float(dispatcher.get("_clock")) - clock_before_catchup - step * MAX_STEPS) < 0.00001, "A retained backlog must continue catching up after pause.")

	var route_points := PackedVector2Array([Vector2.ZERO, Vector2(100.0, 0.0)])
	dispatcher.routes[0] = {
		"points": route_points,
		"cumulative_lengths": TrackGeometry.cumulative_lengths(route_points),
		"length": 100.0,
		"centerline": route_points,
		"running_paths": []
	}
	var metro := Metro.new(1000, 0, Vector2.ZERO)
	metro.previous_distance = 98.0
	metro.distance = 2.0
	metro.previous_travel_direction = 1
	metro.travel_direction = 1
	dispatcher.metros.append(metro)
	app.set("_simulation_accumulator", step * 0.5)
	app.call("_update_render_poses")
	_check(metro.render_pose_valid and minf(metro.render_distance, 100.0 - metro.render_distance) < 0.001, "Route-wrap interpolation must take the short path across the circuit boundary.")
	metro.previous_distance = 20.0
	metro.distance = 40.0
	metro.previous_travel_direction = 1
	metro.travel_direction = -1
	app.call("_update_render_poses")
	_check(is_equal_approx(metro.render_distance, metro.distance), "A direction reversal must not interpolate across incompatible route poses.")
	await _test_follow_screen_lock(app, dispatcher, metro)

	app.queue_free()
	await process_frame
	if failed:
		quit(1)
	else:
		print("Frame pacing smoke passed: 60 Hz ticks, bounded catch-up without time loss, wraparound interpolation, reversal safety and subpixel follow-camera lock.")
		quit(0)

func _test_follow_screen_lock(app: Node, dispatcher: TransitDispatcher, metro: Metro) -> void:
	var camera: Camera2D = app.get("camera")
	var view: WorldView = app.get("world_view")
	var route: Dictionary = dispatcher.routes[0]
	camera.position_smoothing_enabled = true
	camera.position = Vector2(-100, -100)
	camera.reset_smoothing()
	metro.travel_direction = 1
	metro.previous_travel_direction = 1
	metro.position = Vector2(25, 0)
	metro.render_pose_valid = false
	app.call("_follow_train", metro)
	for refresh: int in [60, 120, 144, 0]:
		var elapsed := 0.0
		var worst_drift := 0.0
		var jitter := PackedFloat64Array([0.005, 0.013, 0.008, 0.019])
		for frame in range(32):
			elapsed += 1.0 / refresh if refresh > 0 else jitter[frame % jitter.size()]
			var tick_time := floorf(elapsed / STEP) * STEP
			metro.previous_distance = 25.0 + 20.0 * (tick_time - STEP)
			metro.distance = 25.0 + 20.0 * tick_time
			app.set("_simulation_accumulator", clampf(elapsed - tick_time, 0.0, STEP - 0.0000001))
			app.call("_process", 0.0)
			await process_frame
			var poses := view._build_train_poses(metro, route)
			var head: Vector2 = poses["positions"][0]
			var screen_position := view.get_global_transform_with_canvas() * head
			worst_drift = maxf(worst_drift, screen_position.distance_to(app.get_viewport_rect().get_center()))
		print("Follow-camera screen drift at %s: %.6f px." % [str(refresh) + " Hz" if refresh > 0 else "variable frame intervals", worst_drift])
		_check(worst_drift < 0.05, "The followed train's rendered head must stay within 0.05 screen pixels of the camera center at every render cadence.")
	app.call("_stop_following")
	_check(camera.position_smoothing_enabled, "Leaving train follow must preserve normal navigation smoothing.")
	camera.position_smoothing_enabled = false
	metro.previous_distance = 30.0
	metro.distance = 31.0
	metro.position = TrackGeometry.point_at_distance(route["points"], metro.distance, route["cumulative_lengths"])
	app.set("_simulation_accumulator", STEP * 0.5)
	app.call("_update_render_poses")
	app.set("_screensaver_train", metro)
	app.set("_screensaver_shot", 1)
	app.set("_screensaver_seconds", 6.0)
	app.call("_update_screensaver", 0.0)
	var poses := view._build_train_poses(metro, route)
	var head: Vector2 = poses["positions"][0]
	_check(camera.position.distance_to(head) < 0.0001, "Cinematic follow must use the rendered train pose, not the latest simulation pose.")
	_check((view.get_global_transform_with_canvas() * head).distance_to(app.get_viewport_rect().get_center()) < 0.05, "Cinematic follow must apply the camera transform before the train is drawn.")
