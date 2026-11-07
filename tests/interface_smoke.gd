extends SceneTree

var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.size = Vector2i(1440, 900)
	await process_frame
	await process_frame
	var panel: PanelContainer = main.get("_main_panel")
	_check(panel.size.x <= 280 and panel.size.y <= 460, "The main menu must be compact, not a full-height sidebar.")
	var picker: ColorPickerButton = main.get("_line_color_picker")
	_check(not picker.edit_alpha and not picker.get_picker().edit_alpha, "Solid line colors must not expose transparency.")
	_check(picker.get_picker().get_presets().size() >= 6, "The picker must offer the existing line palette as presets.")
	var graph: TransitGraph = main.get("graph")
	graph.add_station(Vector2.ZERO)
	graph.add_station(Vector2(576, 0))
	main.call("_connect_stations", 0, 1)
	var dispatcher: TransitDispatcher = main.get("dispatcher")
	dispatcher.process(1.0, false)
	main.set("paused", true)
	var first_train := dispatcher.metros[0]
	var distance := first_train.distance
	var color := Color("#cb6d95")
	picker.color_changed.emit(color)
	var lines: Array = main.get("lines")
	_check(lines[0].color == color and picker.color == color, "The real color-picker signal must update the selected line and swatch.")
	_check(dispatcher.metros[0] == first_train and first_train.distance == distance, "Color changes must not rebuild routes or restart trains.")
	_check(main.get("_panel_status").text == main.tr("Couleur de la ligne modifiée."), "Color feedback must be localized.")
	var selector: HBoxContainer = main.get("_line_selector")
	var active_tab: Button
	for child: Node in selector.get_children():
		if not child.is_queued_for_deletion():
			active_tab = child
	_check(active_tab.get_theme_color("font_color") == color.lightened(0.45), "The selected line tab must update immediately.")
	main.call("_create_line")
	var second_color: Color = lines[1].color
	main.call("_select_line", 0)
	_check(picker.color == color, "Selecting a line must restore its own color in the picker.")
	picker.get_popup().popup()
	main.call("_select_line", 1)
	_check(not picker.get_popup().visible and picker.color == second_color, "Line switching must close the picker and display the new selection.")
	picker.color_changed.emit(Color("#6aa675"))
	_check(lines[0].color == color and lines[1].color == Color("#6aa675"), "Recoloring one line must not affect another.")
	main.call("_toggle_help")
	_check(main.get("_help_label").visible, "Compact help must remain accessible.")
	main.call("_toggle_settings")
	await process_frame
	_check(main.get("_settings_popup").visible and main.get("_settings_popup").size.x <= 250, "Settings must remain available in a compact popover.")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("/tmp/metro-menu.png") == OK, "The compact-menu screenshot must be saved.")
	root.size = Vector2i(900, 600)
	await process_frame
	await process_frame
	_check(panel.position.x + panel.size.x <= 900 and panel.position.y + panel.size.y <= 600, "Compact controls must fit the minimum window size.")
	_check(picker.get_global_rect().end.x <= panel.get_global_rect().end.x, "The color swatch must fit inside the compact panel.")
	root.size = Vector2i(760, 520)
	main.call("_resize_interface")
	await process_frame
	var settings: PanelContainer = main.get("_settings_popup")
	_check(panel.position.x + panel.size.x <= 760 and panel.position.y + panel.size.y <= 520, "The main controls must fit a small laptop viewport.")
	_check(settings.position.x + settings.size.x <= 760 and settings.position.y + settings.size.y <= 520, "Settings must stay on-screen at a small laptop viewport.")
	root.size = Vector2i(900, 600)
	main.call("_resize_interface")
	await process_frame
	main.call("_toggle_settings")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = picker.get_global_rect().get_center()
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	await process_frame
	await process_frame
	_check(picker.get_popup().visible, "Pressing the swatch must open the actual picker popup.")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("/tmp/metro-picker.png") == OK, "The color-picker screenshot must be saved.")
	picker.get_popup().hide()
	await _test_route_mouse_input(main)
	main.queue_free()
	await process_frame
	if _failed:
		quit(1)
	else:
		print("Interface smoke passed: compact controls, picker, presets, per-line colors, live tabs and preserved trains.")
		quit()

func _test_route_mouse_input(main: Node) -> void:
	main.call("_select_line", 0)
	var view: WorldView = main.get("world_view")
	var graph: TransitGraph = main.get("graph")
	var camera: Camera2D = main.get("camera")
	camera.position = Vector2(48.0, 0.0)
	camera.zoom = Vector2.ONE * 0.65
	await process_frame
	await process_frame
	var anchor := view.station_handle_position(graph.stations[0], Vector2.RIGHT)
	await _mouse_motion(view, anchor)
	await _mouse_event(view, anchor, true)
	await _mouse_event(view, anchor, false)
	_check(main.get("_connect_drag_source_id") == 0 and main.get("_route_click_mode"), "Actual handle press/release must latch route drawing (source %s, pointer %s, anchor %s)." % [main.get("_connect_drag_source_id"), view.get_global_mouse_position(), anchor])
	var pointer := Vector2(288.0, 144.0)
	await _mouse_motion(view, pointer)
	var preview: PackedVector2Array = main.get("_drawn_points")
	var flip := view.route_flip_position()
	await _mouse_motion(view, flip)
	await _mouse_event(view, flip, true)
	await _mouse_event(view, flip, false)
	_check(not main.get("_route_diagonal_first") and main.get("_drawn_points") != preview, "The on-canvas flip handle must switch posture using actual mouse events.")
	await _mouse_motion(view, pointer)
	await _mouse_event(view, pointer, true)
	await _mouse_event(view, pointer, false)
	_check(main.get("_route_history").size() == 1, "A mouse click on empty space must pin exactly one leg, not two on press/release.")
	await _mouse_motion(view, graph.stations[1].position)
	await _mouse_event(view, graph.stations[1].position, true)
	await _mouse_event(view, graph.stations[1].position, false)
	_check(main.get("_connect_drag_source_id") == -1 and graph.tracks.size() == 1, "Click completion must redraw the existing connection without duplicating rails.")
	await _mouse_motion(view, anchor)
	await _mouse_event(view, anchor, true)
	await _mouse_motion(view, Vector2(240.0, -144.0))
	var preserved := graph.tracks[0].waypoints.duplicate()
	var panel: PanelContainer = main.get("_main_panel")
	var gui_position := view.get_global_transform_with_canvas().affine_inverse() * panel.get_global_rect().get_center()
	await _mouse_motion(view, gui_position)
	await _mouse_event(view, gui_position, false)
	_check(main.get("_connect_drag_source_id") == -1 and graph.tracks[0].waypoints == preserved, "Releasing a route over GUI must cancel without altering the rail.")

func _mouse_motion(view: WorldView, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = view.get_global_transform_with_canvas() * position
	root.push_input(motion, true)
	await process_frame
	await process_frame

func _mouse_event(view: WorldView, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = view.get_global_transform_with_canvas() * position
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame
	await process_frame
