extends SceneTree

const StoreScript := preload("res://scripts/layout_store.gd")
const DIRECTORY := "res://docs/images/"

var _main: Node
var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var selectors := OS.get_cmdline_user_args()
	for selector in selectors:
		if selector not in ["jr-east", "montreal"]:
			push_error("Unknown README capture selector: " + selector)
			quit(1)
			return
	if DisplayServer.get_name() == "headless":
		push_error("README screenshots require a graphical display.")
		quit(1)
		return
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set("startup_layout_enabled", false)
	root.add_child(_main)
	_main.set_process(false)
	_main.set_process_input(false)
	root.content_scale_factor = 1.0
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(1180, 740)
	root.grab_focus()
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("README capture timed out waiting for native rendering.")
		quit(1))
	TranslationServer.set_locale("en")
	await process_frame
	await process_frame
	_main.call("_resize_interface")
	var store := StoreScript.new()
	for path: String in ["res://layouts/montreal.json", "res://layouts/jr_east.json"]:
		if not selectors.is_empty() and not selectors.has("jr-east" if path.ends_with("jr_east.json") else "montreal"):
			continue
		var restored := store.load_bundled_layout(path)
		if restored.is_empty():
			push_error("Cannot load README preset: " + store.error_message)
			quit(1)
			return
		_main.call("_replace_layout", restored, true)
		var dispatcher: TransitDispatcher = _main.get("dispatcher")
		for frame in range(60 * 60):
			dispatcher.process(1.0 / 60.0, false)
		_main.set("_previous_arrival_count", dispatcher.arrival_count)
		_main.call("_clear_hover")
		_main.set("_pointer_inside", false)
		_main.set("_title_seconds", 0.0)
		_main.call("_resize_interface")
		if path.ends_with("montreal.json"):
			await _capture("metro-day.png", 0.5)
			_main.call("_toggle_settings")
			await _capture("metro-menu.png", 0.5)
			_main.call("_close_sheets")
			_main.set("_title_seconds", 30.0)
			_main.call("_resize_interface")
			await _capture("metro-night.png", 0.0)
		else:
			await _capture("metro-jr.png", 0.5)
	_main.queue_free()
	await process_frame
	if _failed:
		quit(1)
	else:
		print("README screenshots captured at 1180x740: " + (", ".join(selectors) if not selectors.is_empty() else "Montreal day/night, sharing menu and Tokyo/Shonan JR") + ".")
		quit()

func _capture(filename: String, phase: float) -> void:
	print("Capturing " + filename)
	_main.set("time_of_day", phase)
	_main.call("_wake_interface")
	var camera: Camera2D = _main.get("camera")
	camera.reset_smoothing()
	camera.force_update_scroll()
	_main.call("_process", 0.0)
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var error := root.get_texture().get_image().save_png(DIRECTORY + filename)
	if error != OK:
		push_error("Cannot save README screenshot " + filename + ": " + error_string(error))
		_failed = true
