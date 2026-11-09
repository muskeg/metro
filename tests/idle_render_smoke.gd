extends SceneTree

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("startup_layout_enabled", false)
	root.add_child(main)
	await process_frame
	main.set_process(false)
	var initial_phase: float = main.get("time_of_day")
	main.set("paused", true)
	main.call("_process", 1.0)
	_check(is_equal_approx(main.get("time_of_day"), initial_phase), "Pausing must freeze the day/night cycle so the scene can become fully idle.")
	main.set("paused", false)
	main.call("_process", 1.0)
	_check(not is_equal_approx(main.get("time_of_day"), initial_phase), "The day/night cycle must advance during active play.")
	main.set("paused", true)
	main.set("_title_seconds", 30.0)
	main.set("_ui_idle_seconds", 8.6)
	main.set("_status_seconds", 0.0)
	_check(main.call("_can_disable_render_loop"), "A paused scene with settled interface and no active transient should be eligible for a sleeping render loop.")
	main.set("_screensaver_active", true)
	_check(not main.call("_can_disable_render_loop"), "Screensaver animation must keep the render loop active.")
	main.set("_screensaver_active", false)
	main.get("_help_popup").show()
	_check(not main.call("_can_disable_render_loop"), "An open help sheet must keep the render loop active.")
	main.get("_help_popup").hide()
	main.set("_idle_render_disabled", true)
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_P
	main.call("_input", event)
	_check(not main.get("_idle_render_disabled") and RenderingServer.is_render_loop_enabled(), "Input must wake a sleeping render loop immediately.")
	if DisplayServer.get_name() != "headless":
		main.set("_title_seconds", 30.0)
		main.set("_ui_idle_seconds", 8.6)
		main.call("_schedule_idle_render_shutdown")
		await RenderingServer.frame_post_draw
		await process_frame
		_check(main.get("_idle_render_disabled") and not RenderingServer.is_render_loop_enabled(), "A settled paused scene must stop continuous rendering.")
		main.call("_input", event)
		_check(not main.get("_idle_render_disabled") and RenderingServer.is_render_loop_enabled(), "Input must restart rendering after idle shutdown.")
	main.queue_free()
	await process_frame
	if failed:
		quit(1)
	else:
		print("Idle render smoke passed.")
		quit(0)
