extends SceneTree

var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true

func _run() -> void:
	await _test_quiet_guidance()
	await _test_interchange_input()
	await _test_large_map_navigation()
	await _test_line_deletion()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("startup_layout_enabled", false)
	root.add_child(main)
	_check(is_equal_approx(root.content_scale_factor, maxf(1.0, DisplayServer.screen_get_scale())), "UI density must match Retina/browser device scale.")
	root.content_scale_factor = 1.0
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(1440, 900)
	await process_frame
	await process_frame
	var panel: PanelContainer = main.get("_main_panel")
	_check(main.get("audio").get("_effects_volume") == 0.0, "Train sounds must default to muted until replacement effects are available.")
	var settings: GridContainer = main.get("_settings_grid")
	var volume_sliders := 0
	for cell: Node in settings.get_children():
		for control: Node in cell.get_children():
			_check(not (control is Label and control.text == "Sons des trains"), "Train effects volume controls must remain absent for now.")
			volume_sliders += int(control is HSlider)
	_check(volume_sliders == 2, "Settings must retain only master and music volume sliders.")
	_check_dock_overflow(main)
	_check_contrast(Color("#253b40"), Color("#faf9f4"), 7.0, "Primary UI text")
	_check_contrast(Color("#53666a"), Color("#faf9f4"), 4.5, "Secondary UI text")
	_check(panel.size.y <= 84 and panel.position.y > 700, "The route dock must leave the map open, not occupy a sidebar.")
	_check(not main.get("_line_popup").visible and not main.get("_settings_popup").visible, "Detailed controls must start closed.")
	var picker: ColorPickerButton = main.get("_line_color_picker")
	_check(main.get("_close_line_button").text == "Replier" and main.get("_close_line_button").custom_minimum_size.y >= 44, "Line controls must have a labelled, touch-sized collapse action.")
	_check(picker.custom_minimum_size.x >= 80 and picker.get_parent().get_child(0).text == "Couleur de la ligne", "The color swatch must be visibly labelled and wide enough to recognize.")
	_check(not picker.edit_alpha and not picker.get_picker().edit_alpha, "Solid line colors must not expose transparency.")
	_check(picker.get_picker().get_presets().size() >= 6, "The picker must offer the existing line palette as presets.")
	var graph: TransitGraph = main.get("graph")
	graph.add_station(Vector2.ZERO)
	graph.add_station(Vector2(576, 0))
	root.size = Vector2i(360, 760)
	await process_frame
	main.call("_request_delete", 0, -1)
	await process_frame
	var delete_dialog: ConfirmationDialog = main.get("_delete_dialog")
	_check(delete_dialog.size.x <= 328 and delete_dialog.position.x >= 0, "Wrapped deletion confirmation must fit a narrow viewport.")
	_check(delete_dialog.get_ok_button().size.y >= 44 and delete_dialog.get_cancel_button().size.y >= 44, "Deletion actions must retain accessible touch targets.")
	delete_dialog.hide()
	root.size = Vector2i(1440, 900)
	await process_frame
	main.call("_connect_stations", 0, 1)
	var dispatcher: TransitDispatcher = main.get("dispatcher")
	dispatcher.process(1.0, false)
	main.set("paused", true)
	var first_train := dispatcher.metros[0]
	var distance := first_train.distance
	main.call("_follow_train", first_train)
	main.get("_fit_window_button").pressed.emit()
	_check(main.get("_followed_train") == null and main.get("paused") and dispatcher.metros[0] == first_train and first_train.distance == distance, "Fit must end following without restarting trains or changing pause.")
	var color := Color("#cb6d95")
	picker.color_changed.emit(color)
	var lines: Array = main.get("lines")
	_check(lines[0].color == color and picker.color == color, "The real color-picker signal must update the selected line and swatch.")
	_check(dispatcher.metros[0] == first_train and first_train.distance == distance, "Color changes must not rebuild routes or restart trains.")
	_check(main.get("_panel_status").text.is_empty(), "Visible color changes must not generate confirmation messages.")
	var selector: HBoxContainer = main.get("_line_selector")
	var active_tab: Button
	for child: Node in selector.get_children():
		if not child.is_queued_for_deletion() and child.button_pressed:
			active_tab = child
	_check(active_tab.get_theme_stylebox("pressed").border_color == color, "The selected line indicator must update immediately.")
	for background: Color in [Color("#111111"), Color("#777777"), Color("#58b8bd"), Color("#e98668"), Color("#dfeee8")]:
		main.call("_style_line_tab", active_tab, background)
		_check_contrast(active_tab.get_theme_color("font_pressed_color"), active_tab.get_theme_stylebox("pressed").bg_color, 4.5, "Custom line tabs")
	main.call("_style_line_tab", active_tab, color)
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
	_check(main.get("_help_label").is_visible_in_tree(), "Readable help must remain accessible.")
	main.call("_toggle_settings")
	await process_frame
	_check(main.get("_settings_popup").visible and not main.get("_help_popup").visible, "Only one sheet should be open at a time.")
	main.call("_set_status", "Cette rame serait trop longue pour un segment. Allongez le tracé.")
	var visible_feedback := false
	for feedback: Label in main.get("_sheet_feedback"):
		visible_feedback = visible_feedback or (feedback.is_visible_in_tree() and feedback.text == main.get("_panel_status").text)
	_check(visible_feedback, "An open sheet must not hide action errors or feedback.")
	main.call("_process", 9.0)
	for feedback: Label in main.get("_sheet_feedback"):
		_check(not feedback.visible, "Transient feedback must disappear without closing the sheet.")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("/tmp/metro-menu.png") == OK, "The compact-menu screenshot must be saved.")
	await _test_responsive_layout(main)
	root.size = Vector2i(900, 600)
	main.call("_resize_interface")
	await process_frame
	main.call("_close_sheets")
	main.call("_toggle_line_settings")
	await process_frame
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
	selector = main.get("_line_selector")
	var add: Button = selector.get_child(selector.get_child_count() - 1)
	var last: Button = selector.get_child(selector.get_child_count() - 2)
	_check(add.text == "+" and not add.toggle_mode and add.size.y >= 44.0, "Add-line must be an accessible action after the tabs, not a selectable line.")
	_check(is_equal_approx(add.position.x, last.position.x + last.size.x + 8.0), "Add-line must sit directly beside the final line tab without expanding to the far edge.")
	_check(add.get_theme_stylebox("normal").border_width_bottom == last.get_theme_stylebox("normal").border_width_bottom, "Add-line must share the line tabs' underline styling.")
	_check(picker.get_popup().visible, "Pressing the swatch must open the actual picker popup.")
	_check(picker.get_popup().size.y <= 520, "The color picker must not require a taller screen than the minimum laptop viewport.")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("/tmp/metro-picker.png") == OK, "The color-picker screenshot must be saved.")
	picker.get_popup().hide()
	main.call("_close_sheets")
	await _test_route_mouse_input(main)
	await _test_density_scaled_input(main)
	await _test_station_preview_and_watch(main)
	await _test_quiet_interface(main)
	await _test_help_feedback_layout(main)
	var count: int = main.get("lines").size()
	var line_row: HBoxContainer = main.get("_line_selector")
	line_row.get_child(line_row.get_child_count() - 1).pressed.emit()
	_check(main.get("lines").size() == count + 1, "The inline plus action must actually create and select a new line.")
	main.queue_free()
	await process_frame
	if _failed:
		quit(1)
	else:
		print("Interface smoke passed: readable responsive HUD, exclusive sheets, picker, line overflow, real input and preserved trains.")
		quit()

func _test_line_deletion() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("startup_layout_enabled", false)
	root.add_child(main)
	main.set_process(false)
	root.content_scale_factor = 1.0
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(760, 520)
	await process_frame
	await process_frame
	var graph: TransitGraph = main.get("graph")
	for position: Vector2 in [Vector2.ZERO, Vector2(576, 0), Vector2(576, 576), Vector2(-576, 0), Vector2(576, 1152), Vector2(0, 576), Vector2(-576, 576)]:
		graph.add_station(position)
	var lines: Array[TransitLine] = main.get("lines")
	for station_id in [0, 1, 2, 5, 0]:
		_check(lines[0].append_station(graph, station_id), "Deletion fixture loop must build.")
	for station_ids: Array in [[1, 0, 3], [2, 4]]:
		main.call("_create_line")
		for station_id: int in station_ids:
			_check(lines.back().append_station(graph, station_id), "Shared deletion fixture must build.")
	var shared := graph.track_between(0, 1)
	var original_path := PackedVector2Array([Vector2.ZERO, Vector2(576, 0)])
	shared.waypoints = original_path
	var unrelated := graph.add_track(0, 6)
	var exclusive_station := graph.stations[5]
	var interchange := graph.stations[2]
	var retained_line := lines[1]
	retained_line.dispatch_rate = 23.0
	main.call("_select_line", 0)
	main.call("_refresh_network")
	var dispatcher: TransitDispatcher = main.get("dispatcher")
	dispatcher.process(1.0, false)
	main.call("_follow_train", dispatcher.metros[0])
	main.set("paused", true)
	main.call("_toggle_line_settings")
	await process_frame
	await _click_control(main.get("_close_line_button"))
	_check(not main.get("_line_popup").visible and main.get("_main_panel").visible, "Collapse must close settings without hiding the line tabs.")
	main.call("_toggle_line_settings")
	main.get("_delete_line_button").pressed.emit()
	var dialog: ConfirmationDialog = main.get("_delete_dialog")
	_check(dialog.visible and lines.size() == 3 and graph.stations.size() == 7, "Delete line must request confirmation before changing infrastructure.")
	dialog.canceled.emit()
	dialog.hide()
	_check(lines.size() == 3 and graph.stations.has(exclusive_station), "Cancel must preserve the complete line.")
	dispatcher.arrival_count = 4
	dispatcher.last_arrival_line_id = 2
	main.get("_delete_line_button").pressed.emit()
	dialog.hide()
	dialog.confirmed.emit()
	_check(lines.size() == 2 and lines[0] == retained_line and retained_line.id == 0 and retained_line.dispatch_rate == 23.0, "Surviving lines must be renumbered without losing preferences.")
	_check(graph.stations.size() == 6 and not graph.stations.has(exclusive_station) and graph.stations.has(interchange), "Deletion must remove exclusive stations but keep shared interchanges.")
	_check(graph.tracks.size() == 4 and graph.tracks.has(shared) and shared.waypoints == original_path and graph.tracks.has(unrelated), "Shared reversed tracks and unrelated infrastructure must remain unchanged.")
	_check(main.get("active_line") == retained_line and main.get("_followed_train") == null and main.get("paused"), "Deletion must select a survivor, clear stale following and preserve pause.")
	_check(dispatcher.metros.is_empty() and dispatcher.visits.is_empty(), "Deletion must rebuild routes without retaining old train IDs or platform visits.")
	_check(main.get("_previous_arrival_count") == dispatcher.arrival_count and dispatcher.last_arrival_line_id == -1, "Deletion must discard pending arrival feedback using obsolete line IDs.")
	var store := LayoutStore.new()
	var snapshot := store.capture(graph, lines, 0, Vector2.ZERO, 1.0)
	_check(not store.restore(snapshot).is_empty(), "The reindexed network must remain saveable and loadable.")
	while lines.size() > 1:
		main.call("_request_delete_line")
		dialog.hide()
		dialog.confirmed.emit()
	main.call("_request_delete_line")
	dialog.hide()
	dialog.confirmed.emit()
	_check(lines.size() == 1 and lines[0].stations.is_empty() and main.get("active_line") == lines[0], "Deleting the last line must leave a usable empty default line.")
	_check(graph.tracks.has(unrelated), "Deleting all services must still preserve unrelated physical infrastructure.")
	main.queue_free()
	await process_frame

func _test_interchange_input() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("startup_layout_enabled", false)
	root.add_child(main)
	await process_frame
	main.set_process(false)
	var graph: TransitGraph = main.get("graph")
	var station := graph.add_station(Vector2.ZERO)
	var view: WorldView = main.get("world_view")
	var camera: Camera2D = main.get("camera")
	var lines: Array[TransitLine] = main.get("lines")
	for index in range(8):
		var line := TransitLine.new(lines.size(), Color("#58b8bd"))
		line.stations = [station.id]
		lines.append(line)
	for zoom: float in [0.65, 1.0, 2.5]:
		camera.zoom = Vector2.ONE * zoom
		view.view_zoom = camera.zoom
		var edge := station.position + Vector2(0, view.station_radius(station) - 1.0)
		main.call("_begin_world_interaction", edge)
		_check(main.get("_dragging_station_id") == station.id, "The visible outer interchange ring must start a station move, not place a station or follow a train.")
		main.call("_cancel_gesture")
		var handle := view.station_handle_position(station, Vector2.RIGHT)
		_check(handle.distance_to(station.position) >= view.station_radius(station) + 12.0, "Station handles must remain outside all concentric rings.")
		main.call("_begin_world_interaction", handle)
		_check(main.get("_connect_drag_source_id") == station.id, "Growing interchange handles must still start connections.")
		main.call("_cancel_gesture")
		_check(graph.stations.size() == 1, "Interchange input must not accidentally place stations.")
	_check(main.call("_station_near", Vector2(0, 25), 20.0) == station, "Station snapping must recognize a growing marker's visible border.")
	main.queue_free()
	await process_frame

func _test_large_map_navigation() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("startup_layout_enabled", false)
	root.add_child(main)
	var density := root.content_scale_factor
	var window_size := root.size
	root.content_scale_factor = 1.0
	root.size = Vector2i(1440, 900)
	await process_frame
	main.set_process(false)
	var camera: Camera2D = main.get("camera")
	main.call("_zoom_camera", 0.001)
	_check(camera.zoom.is_equal_approx(Vector2.ONE * 0.08), "Mouse-wheel zoom must allow a 0.08x large-network overview.")
	camera.zoom = Vector2.ONE
	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 0.001
	main.call("_unhandled_input", pinch)
	_check(camera.zoom.is_equal_approx(Vector2.ONE * 0.08), "Trackpad pinch must share the same large-map zoom limit.")
	var span: Vector2 = main.get_viewport_rect().size / camera.zoom
	_check(span.x >= 14000.0 and span.y >= 9000.0, "Overview must expose a genuinely larger world area, not just change a nominal setting.")
	camera.position = Vector2(48000, -48000)
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(80, -40)
	main.call("_unhandled_input", pan)
	_check(camera.position.is_equal_approx(Vector2(47000, -47500)), "Panning must remain unbounded and zoom-scaled far beyond the initial map.")
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE
	var graph: TransitGraph = main.get("graph")
	var station_count := graph.stations.size()
	var first_touch := InputEventScreenTouch.new()
	first_touch.index = 4
	first_touch.position = Vector2(600, 440)
	first_touch.pressed = true
	main.call("_input", first_touch)
	_check(graph.stations.size() == station_count, "A touch that may become a two-finger gesture must not place a station immediately.")
	var second_touch := InputEventScreenTouch.new()
	second_touch.index = 9
	second_touch.position = Vector2(700, 440)
	second_touch.pressed = true
	main.call("_input", second_touch)
	_check(main.get("_touch_navigation_active") and main.get("_panning"), "Two-finger touches on the map must start camera navigation.")
	_check(graph.stations.size() == station_count, "Starting a two-finger gesture must not leave a station from the first touch.")
	var first_drag := InputEventScreenDrag.new()
	first_drag.index = 4
	first_drag.position = Vector2(590, 450)
	main.call("_input", first_drag)
	var second_drag := InputEventScreenDrag.new()
	second_drag.index = 9
	second_drag.position = Vector2(730, 450)
	main.call("_input", second_drag)
	_check(camera.position != Vector2.ZERO, "Moving two fingers together must pan the camera.")
	_check(camera.zoom.x > 1.0, "Moving two fingers apart must zoom in.")
	var release_touch := InputEventScreenTouch.new()
	release_touch.index = 9
	release_touch.position = second_drag.position
	release_touch.pressed = false
	main.call("_input", release_touch)
	_check(not main.get("_touch_navigation_active") and not main.get("_panning"), "Lifting a finger must end the current touch navigation gesture.")
	release_touch = InputEventScreenTouch.new()
	release_touch.index = 4
	release_touch.position = first_drag.position
	release_touch.pressed = false
	main.call("_input", release_touch)
	_check(not main.get("_touch_navigation_sequence") and main.get("_touch_points").is_empty(), "Ending a touch sequence must release all tracked pointers.")
	var tap := InputEventScreenTouch.new()
	tap.index = 12
	tap.position = Vector2(600, 440)
	tap.pressed = true
	main.call("_input", tap)
	_check(graph.stations.size() == station_count, "A single touch must wait for release before placing its station.")
	tap.pressed = false
	main.call("_input", tap)
	_check(graph.stations.size() == station_count + 1, "A single-finger tap must still place a station.")
	main.call("_zoom_camera", 1000.0)
	_check(camera.zoom.is_equal_approx(Vector2.ONE * 6.0), "Expanded overview must preserve existing close-up zoom.")
	main.queue_free()
	root.content_scale_factor = density
	root.size = window_size
	await process_frame

func _test_responsive_layout(main: Node) -> void:
	for viewport_size: Vector2i in [Vector2i(3840, 2160), Vector2i(1366, 768), Vector2i(1180, 740), Vector2i(1024, 600), Vector2i(760, 520), Vector2i(390, 640)]:
		root.size = viewport_size
		main.call("_resize_interface")
		await process_frame
		await process_frame
		var bounds := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_check(main.get("_line_scroll").size.x >= 96.0, "Even a phone must leave room for a full line tab.")
		_check_dock_overflow(main)
		for name: String in ["_main_panel", "_toolbar", "_zoom_controls"]:
			var control: Control = main.get(name)
			_check(bounds.encloses(control.get_global_rect()), "%s must fit %s: %s" % [name, viewport_size, control.get_global_rect()])
		for name: String in ["_line_popup", "_settings_popup", "_help_popup"]:
			main.call("_close_sheets")
			main.call("_toggle_sheet", main.get(name))
			await process_frame
			await process_frame
			_check_dock_overflow(main)
			var sheet: PanelContainer = main.get(name)
			_check(bounds.encloses(sheet.get_global_rect()), "%s must fit %s: %s" % [name, viewport_size, sheet.get_global_rect()])
			if name == "_line_popup":
				_check(main.get("_main_panel").get_global_rect().encloses(sheet.get_global_rect()), "Line controls must be inside the bottom rail, not in a floating popup.")
				_check(sheet.get_global_rect().end.y <= main.get("_dock_row").get_global_rect().position.y, "Integrated controls must leave the line tabs accessible.")
				var close: Button = main.get("_close_line_button")
				var close_rect := close.get_global_rect()
				var scroll: ScrollContainer = main.get("_line_stack").get_parent()
				scroll.scroll_vertical = 10000
				await process_frame
				_check(close.get_global_rect() == close_rect and bounds.encloses(close_rect), "The labelled collapse button must remain fixed and visible while settings scroll.")
				_check(scroll.get_global_rect().encloses(main.get("_delete_line_button").get_global_rect()), "Scrolling to the end must expose the complete delete-line action.")
				scroll.scroll_vertical = 0
			else:
				_check(sheet.get_global_rect().get_center().is_equal_approx(main.get_viewport_rect().size * 0.5), "%s must be centered on the actual viewport: %s." % [name, sheet.get_global_rect()])
				if name == "_settings_popup":
					_check(sheet.get_child(0) is VBoxContainer, "Settings must contain its full contents directly, without a scroll container.")
					var stack: VBoxContainer = sheet.get_child(0)
					_check(sheet.get_global_rect().encloses(stack.get_global_rect()), "Every settings control must fit inside the panel without scrolling.")
		var slider: HSlider = main.get("_dispatch_slider")
		_check(slider.size.y >= 32.0, "Sliders need a usable pointer target.")
		_check(main.get("_dispatch_value").get_theme_font_size("font_size") >= 16, "Values must not shrink on small viewports.")
		_check(main.get("_help_label").get_theme_font_size("font_size") >= 16, "Help must not shrink on small viewports.")
		for name: String in ["_pause_button", "_settings_button", "_collapse_dock_button", "_hide_ui_button", "_zoom_in_button", "_zoom_out_button", "_fit_window_button"]:
			var button: Button = main.get(name)
			_check(button.size.y >= 44 and button.get_theme_font_size("font_size") >= 16, "HUD actions need readable text and 44px targets.")
		var locale := TranslationServer.get_locale()
		TranslationServer.set_locale("fr")
		main.call("_update_status")
		main.call("_update_configuration_ui")
		main.call("_refresh_line_selector")
		await process_frame
		await process_frame
		_check(bounds.encloses(main.get("_toolbar").get_global_rect()), "French toolbar text must fit without reducing its font.")
		var line_sheet: PanelContainer = main.get("_line_popup")
		_check(main.get("_line_grid").get_global_rect().end.x <= line_sheet.get_global_rect().end.x, "French slider labels and values must fit inside the sheet.")
		TranslationServer.set_locale(locale)
		main.call("_update_status")
		main.call("_update_configuration_ui")
		main.call("_refresh_line_selector")
		if viewport_size.x >= 760:
			main.call("_close_sheets")
			main.call("_toggle_line_settings")
			await process_frame
			await process_frame
			_check(main.get("_wagon_slider").get_global_rect().end.y < main.get("_line_popup").get_global_rect().end.y, "All five line controls must fit without scrolling at laptop sizes.")
			var details_scroll: ScrollContainer = main.get("_line_stack").get_parent()
			_check(not details_scroll.get_v_scroll_bar().visible, "Integrated laptop controls must fit without a scrollbar: viewport=%s, scroll=%s, content=%s, panel=%s, style=%s." % [viewport_size, details_scroll.size, details_scroll.get_child(0).get_combined_minimum_size(), main.get("_line_popup").size, main.get("_line_popup").get_theme_stylebox("panel").get_minimum_size()])
		main.call("_close_sheets")
	var original_locale := TranslationServer.get_locale()
	for index in range(10):
		main.call("_create_line")
		for locale: String in ["en", "fr"]:
			TranslationServer.set_locale(locale)
			main.call("_refresh_line_selector")
			for viewport_size: Vector2i in [Vector2i(390, 640), Vector2i(760, 520), Vector2i(1024, 600)]:
				root.size = viewport_size
				main.call("_resize_interface")
				await process_frame
				await process_frame
				_check_dock_overflow(main)
				_check(is_equal_approx(main.get("_main_panel").size.x, viewport_size.x), "The bottom rail must stay full-width as lines are added.")
	TranslationServer.set_locale(original_locale)
	main.call("_refresh_line_selector")
	await process_frame
	await process_frame
	var selector: HBoxContainer = main.get("_line_selector")
	var scroll: ScrollContainer = main.get("_line_scroll")
	_check(selector.size.x > scroll.size.x and scroll.scroll_horizontal > 0, "Many lines must scroll to the active route without expanding the dock.")
	main.call("_on_line_tab_pressed", 0)
	_check(main.get("_line_popup").visible and main.get("active_line").id == 0, "Route tabs must select a line and expose its settings.")
	main.call("_on_line_tab_pressed", 1)
	_check(main.get("_line_popup").visible and main.get("active_line").id == 1, "Switching lines must keep integrated controls open.")
	main.call("_on_line_tab_pressed", 1)
	_check(not main.get("_line_popup").visible, "Tapping the same line must fold its integrated controls.")
	main.call("_on_line_tab_pressed", 0)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	_check(not main.get("_line_popup").visible, "Escape must dismiss a sheet.")

func _check_dock_overflow(main: Node) -> void:
	var scroll: ScrollContainer = main.get("_line_scroll")
	var selector: HBoxContainer = main.get("_line_selector")
	var dock: HBoxContainer = scroll.get_parent()
	var panel: PanelContainer = main.get("_main_panel")
	var available := panel.size.x - panel.get_theme_stylebox("panel").get_minimum_size().x
	var controls_width := dock.get_combined_minimum_size().x
	var tabs_width := selector.get_combined_minimum_size().x
	var overflow := controls_width + tabs_width > available + 0.5
	_check(scroll.get_h_scroll_bar().visible == overflow, "The dock scrollbar must appear only for genuine overflow, not expanding action buttons (lines=%d, tabs=%s, available=%s)." % [main.get("lines").size(), tabs_width, scroll.size.x])
	if not overflow:
		_check(scroll.size.x + 0.5 >= tabs_width and scroll.scroll_horizontal == 0, "All tabs must fit unclipped and unscrolled when the dock has enough space.")
	var collapse: Button = main.get("_collapse_dock_button")
	_check(collapse.text.is_empty() and collapse.size_flags_horizontal == Control.SIZE_SHRINK_END, "The collapse action must remain icon-only and never expand at the expense of line tabs.")
	_check(collapse.size.x <= 48.0 and collapse.size.y >= 44.0, "The panel icon must remain compact with a touch-sized target.")

func _check_contrast(foreground: Color, background: Color, minimum: float, label: String) -> void:
	var first := foreground.srgb_to_linear().get_luminance()
	var second := background.srgb_to_linear().get_luminance()
	var ratio := (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)
	_check(ratio >= minimum, "%s contrast must be at least %.1f:1, got %.2f:1." % [label, minimum, ratio])

func _test_density_scaled_input(main: Node) -> void:
	root.content_scale_factor = 2.0
	root.size = Vector2i(1520, 1040)
	main.call("_resize_interface")
	await process_frame
	await process_frame
	_check(root.get_visible_rect().size == Vector2(760, 520), "Retina rendering must use logical UI coordinates, not halve the apparent text size.")
	main.call("_close_sheets")
	await _physical_click(main.get("_settings_button").get_global_rect().get_center())
	_check(main.get("_settings_popup").visible, "Physical Retina pointer coordinates must reach the menu.")
	main.call("_close_sheets")
	await _physical_click(main.get("_line_selector").get_child(0).get_global_rect().get_center())
	_check(main.get("_line_popup").visible, "Physical Retina pointer coordinates must reach line settings.")
	var picker: ColorPickerButton = main.get("_line_color_picker")
	await _physical_click(picker.get_global_rect().get_center())
	_check(picker.get_popup().visible, "The color picker must open with real Retina input.")
	picker.get_popup().hide()
	var slider: HSlider = main.get("_dispatch_slider")
	var slider_position := slider.get_global_rect().position + Vector2(slider.size.x * 0.75, slider.size.y * 0.5)
	await _physical_click(slider_position)
	_check(main.get("active_line").dispatch_rate > 40.0, "The real slider must update its line at 2x display density.")
	main.call("_close_sheets")
	var graph: TransitGraph = main.get("graph")
	var previous_count := graph.stations.size()
	await _physical_click(Vector2(650, 150))
	_check(graph.stations.size() == previous_count + 1, "Map clicks must still place stations with display scaling enabled.")
	root.content_scale_factor = 1.0

func _physical_click(position: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = root.get_final_transform() * position
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	await process_frame
	await process_frame

func _test_station_preview_and_watch(main: Node) -> void:
	main.set_process(false)
	main.call("_close_sheets")
	var view: WorldView = main.get("world_view")
	var graph: TransitGraph = main.get("graph")
	var camera: Camera2D = main.get("camera")
	var dispatcher: TransitDispatcher = main.get("dispatcher")
	camera.zoom = Vector2.ONE
	var pointer := Vector2(-281.0, -235.0)
	main.call("_update_hover", pointer)
	_check(view.station_preview_visible and view.station_preview_position == Vector2(-288, -240), "Empty-space preview must use the exact placement grid.")
	var count := graph.stations.size()
	main.call("_begin_world_interaction", pointer)
	_check(graph.stations.size() == count + 1 and graph.stations.back().position == Vector2(-288, -240), "Clicking the ghost must create a station at its preview without a tool mode.")
	main.call("_update_hover", pointer)
	_check(not view.station_preview_visible, "An occupied station must not get a placement ghost.")
	var rail := TrackGeometry.sample(graph, graph.tracks[0])
	main.call("_update_hover", rail[rail.size() / 2])
	_check(not view.station_preview_visible and view.hovered_track_id >= 0, "Rails must keep insertion handles instead of a disconnected placement ghost.")
	main.call("_update_hover", Vector2(-480, -240))
	main.call("_on_pointer_exited")
	_check(not view.station_preview_visible and not main.get("_pointer_inside"), "Leaving the game must clear the ghost.")
	main.set("_panning", true)
	main.call("_update_hover", pointer + Vector2(192, -144))
	_check(not view.station_preview_visible, "Panning must suppress placement previews.")
	main.set("_panning", false)
	main.set("_space_down", true)
	main.call("_update_hover", pointer + Vector2(192, -144))
	_check(not view.station_preview_visible, "Space-pan must suppress placement previews.")
	main.set("_space_down", false)
	main.call("_toggle_settings")
	main.call("_update_hover", pointer + Vector2(192, -144))
	_check(not view.station_preview_visible, "Settings must suppress placement previews.")
	main.get("_hide_ui_button").pressed.emit()
	_check(main.get("_ui_hidden") and not main.get("_ui_root").visible and not view.interaction_overlays_visible, "Watch mode must hide all UI and editing decorations.")
	_check(not main.get("_settings_popup").visible, "Entering watch mode must close sheets.")
	count = graph.stations.size()
	main.call("_begin_world_interaction", Vector2(-480, -240))
	_check(graph.stations.size() == count, "Watching must not accidentally place stations.")
	var watched_line: TransitLine = dispatcher.lines[0]
	dispatcher.process(watched_line.dwell_time + watched_line.terminal_recovery + 2.0, false)
	var train: Metro = dispatcher.metros[0]
	main.call("_begin_world_interaction", train.position)
	_check(main.get("_followed_train") == train, "Train following must remain available while watching.")
	main.set("paused", false)
	var distance := train.distance
	main.call("_process", 1.0)
	_check(not is_equal_approx(train.distance, distance), "Hiding the UI must not pause or rebuild running trains.")
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(12, 8)
	var previous_position := camera.position
	main.call("_unhandled_input", pan)
	_check(camera.position != previous_position and main.get("_followed_train") == null, "Panning must remain usable while watching.")
	var zoom := InputEventMagnifyGesture.new()
	zoom.factor = 1.1
	var previous_zoom := camera.zoom
	main.call("_unhandled_input", zoom)
	_check(camera.zoom != previous_zoom, "Pinch zoom must remain usable while watching.")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	_check(not main.get("_ui_hidden") and main.get("_ui_root").visible and view.interaction_overlays_visible, "Escape must restore UI and interaction overlays.")
	var hide := InputEventKey.new()
	hide.keycode = KEY_H
	hide.pressed = true
	root.push_input(hide)
	_check(main.get("_ui_hidden"), "H must hide the UI.")
	root.push_input(hide)
	_check(not main.get("_ui_hidden"), "H must also restore the UI.")
	main.call("_begin_world_interaction", graph.stations[0].position)
	_check(main.get("_dragging_station_id") == 0, "Editing must return after leaving watch mode.")
	main.call("_toggle_ui")
	_check(main.get("_dragging_station_id") == -1, "Hiding UI during a gesture must cancel it safely.")
	main.call("_toggle_ui")
	dispatcher.process(6.0, false)
	main.call("_follow_train", dispatcher.metros[0])
	count = graph.stations.size()
	main.call("_update_hover", Vector2(-480, -240))
	_check(not view.station_preview_visible and not view.interaction_overlays_visible and view.selected_station_id == -1, "Following must immediately suppress ghost, gizmos and selection overlays.")
	main.call("_begin_world_interaction", Vector2(-480, -240))
	main.call("_begin_world_interaction", graph.stations[0].position)
	_check(graph.stations.size() == count and main.get("_dragging_station_id") == -1, "Following must prevent map placement and station editing.")
	var delete := InputEventKey.new()
	delete.keycode = KEY_DELETE
	delete.pressed = true
	main.call("_unhandled_input", delete)
	_check(not main.get("_delete_dialog").visible, "Delete must not edit the network during following.")
	main.call("_toggle_ui")
	main.call("_toggle_ui")
	_check(not view.interaction_overlays_visible, "Restoring HUD while following must not restore editing overlays.")
	main.call("_process", 0.0)
	_check(not view.station_preview_visible and main.get("_ui_root").visible, "Follow frames must keep map overlays hidden without hiding toolbar.")
	main.call("_stop_following")
	_check(view.interaction_overlays_visible, "Stopping following must restore editing overlays when HUD is shown.")
	main.call("_update_hover", Vector2(-480, -240))
	_check(view.station_preview_visible, "Ghost placement must resume after following ends.")

func _test_quiet_interface(main: Node) -> void:
	main.set_process(false)
	main.set("_title_seconds", 0.0)
	main.call("_update_title_fade", 10.0)
	var brand: HBoxContainer = main.get("_brand")
	_check(is_equal_approx(brand.modulate.a, 1.0), "Metro title must remain opaque for the first ten seconds.")
	_check(brand.get_parent() != main.get("_ui_root"), "Title fade must remain independent of the HUD idle fade.")
	_check(brand.get_child_count() == 2 and brand.size.y == 60, "Launch branding must show a 60px transit mark and vector wordmark.")
	for artwork: TextureRect in brand.get_children():
		_check(artwork.texture != null and artwork.texture.resource_path.begins_with("res://assets/branding/"), "Launch branding must use the shared vector artwork.")
		_check(artwork.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Logo artwork must not intercept map input.")
	main.call("_update_title_fade", 10.0)
	_check(is_equal_approx(brand.modulate.a, 0.5), "Metro title must be halfway faded at twenty seconds.")
	main.call("_update_title_fade", 10.0)
	main.call("_wake_interface")
	main.call("_resize_interface")
	_check(not brand.visible and is_zero_approx(brand.modulate.a), "Metro title must disappear permanently after thirty seconds despite HUD wake or resize.")
	main.call("_close_sheets")
	var graph: TransitGraph = main.get("graph")
	var count := graph.stations.size()
	var active: TransitLine = main.get("active_line")
	var paused: bool = main.get("paused")
	await process_frame
	await process_frame
	var collapse: Button = main.get("_collapse_dock_button")
	var collapse_rect := collapse.get_global_rect()
	await _click_control(collapse)
	_check(main.get("_dock_collapsed") and not main.get("_main_panel").visible, "The bottom dock must collapse using its actual button.")
	var handle: Button = main.get("_collapsed_dock_button")
	_check(handle.get_global_rect() == collapse_rect, "Collapse and restore must occupy exactly the same click target: %s / %s." % [collapse_rect, handle.get_global_rect()])
	_check(handle.is_visible_in_tree() and handle.text.is_empty() and handle.draw.is_connected(Callable(main, "_draw_dock_icon").bind(handle, true)), "Collapsed rail must leave an icon-only panel restore button.")
	for viewport_size: Vector2i in [Vector2i(390, 640), Vector2i(760, 520), Vector2i(1024, 600)]:
		root.size = viewport_size
		main.call("_resize_interface")
		await process_frame
		_check(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(handle.get_global_rect()) and handle.size.y >= 44, "Collapsed rail handle must stay touch-sized and onscreen.")
		var restore_rect := handle.get_global_rect()
		await _click_control(handle)
		await process_frame
		_check(collapse.get_global_rect() == restore_rect, "Restoring lines must keep the button at the same position after viewport resizing: %s / %s." % [collapse.get_global_rect(), restore_rect])
		await _click_control(collapse)
		_check(handle.get_global_rect() == restore_rect, "Collapsing lines must preserve the exact second-click target.")
	main.call("_wake_interface")
	main.set("time_of_day", 0.5)
	main.call("_update_ui_idle", 7.9)
	var ui: Control = main.get("_ui_root")
	_check(is_equal_approx(ui.modulate.a, 1.0), "Controls must not dim before eight idle seconds.")
	main.call("_update_ui_idle", 0.4)
	_check(is_equal_approx(ui.modulate.a, 0.64), "Idle controls must fade smoothly after eight seconds, not disappear abruptly.")
	main.call("_update_ui_idle", 0.3)
	_check(is_equal_approx(ui.modulate.a, 0.28), "Idle controls must remain faintly visible and tappable.")
	main.set("time_of_day", 0.0)
	main.call("_update_ui_idle", 0.6)
	_check(is_equal_approx(ui.modulate.a, 0.7), "Dark-night idle controls must retain readable opacity through the day/night transition.")
	main.set("time_of_day", 0.5)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2.ONE
	main.call("_input", motion)
	_check(is_equal_approx(ui.modulate.a, 1.0), "Pointer movement must restore full opacity immediately.")
	main.call("_update_ui_idle", 20.0)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = main.get("_settings_button").get_global_rect().get_center()
	main.call("_input", touch)
	_check(is_equal_approx(ui.modulate.a, 1.0), "Touch must restore controls without a keyboard.")
	touch.pressed = false
	main.call("_input", touch)
	await _click_control(handle)
	_check(not main.get("_dock_collapsed") and main.get("_main_panel").visible, "Tapping the bottom handle must expand the rail.")
	_check(graph.stations.size() == count and main.get("active_line") == active and main.get("paused") == paused, "Collapsing controls must not edit, switch lines or change pause.")
	main.call("_toggle_settings")
	main.call("_update_ui_idle", 20.0)
	_check(is_equal_approx(ui.modulate.a, 1.0), "Open sheets must not fade while reading.")
	main.call("_close_sheets")
	main.call("_update_ui_idle", 20.0)
	main.call("_set_status", "Les stations ont besoin d'un peu d'espace.")
	_check(is_equal_approx(ui.modulate.a, 1.0), "Action feedback must wake dimmed controls so errors remain readable.")
	main.set("_panning", true)
	main.call("_update_ui_idle", 20.0)
	_check(is_equal_approx(ui.modulate.a, 1.0), "Active camera gestures must not fade.")
	main.set("_panning", false)
	main.call("_toggle_ui")
	var restore: Button = main.get("_restore_ui_button")
	_check(restore.is_visible_in_tree() and restore.size.y >= 44, "Watch mode needs an independent touch-sized restore button.")
	_check(restore.text.is_empty() and restore.get_theme_stylebox("normal") is StyleBoxEmpty, "Watch restoration must have no text or filled panel.")
	_check(restore.position.y > root.size.y - 64 and is_equal_approx(restore.get_global_rect().get_center().x, root.size.x * 0.5), "The watch handle must sit discreetly at the bottom center.")
	main.call("_update_ui_idle", 30.0)
	_check(is_equal_approx(restore.modulate.a, 1.0), "The watch restore button must never fade away.")
	await _click_control(restore)
	_check(not main.get("_ui_hidden") and not restore.visible, "The real restore button must exit watch mode without a key.")
	_check(graph.stations.size() == count, "The restore tap must not leak into station placement.")
	main.call("_wake_interface")

func _click_control(control: Control) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _test_help_feedback_layout(main: Node) -> void:
	main.set_process(false)
	var original_locale := TranslationServer.get_locale()
	for locale: String in ["en", "fr"]:
		TranslationServer.set_locale(locale)
		main.call("_refresh_line_selector")
		for viewport: Vector2i in [Vector2i(1024, 640), Vector2i(760, 520), Vector2i(390, 640)]:
			root.size = viewport
			main.call("_close_sheets")
			main.call("_toggle_settings")
			await process_frame
			await process_frame
			var settings: PanelContainer = main.get("_settings_popup")
			var settings_stack: VBoxContainer = settings.get_child(0)
			_check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(settings.get_global_rect()), "All settings must fit onscreen in both languages.")
			_check(settings.get_global_rect().encloses(settings_stack.get_global_rect()), "Translated settings must be fully visible without scrolling.")
			_check(settings.get_global_rect().get_center().is_equal_approx(main.get_viewport_rect().size * 0.5), "Translated settings must remain centered.")
			main.call("_close_sheets")
			main.call("_toggle_line_settings")
			main.call("_set_status", "Cette rame serait trop longue pour un segment. Allongez le tracé.")
			await process_frame
			await process_frame
			for feedback: Label in main.get("_sheet_feedback"):
				if not feedback.is_visible_in_tree():
					_check(not feedback.visible and feedback.text.is_empty(), "Closed sheets must not receive hidden feedback that inflates their layout.")
			main.call("_close_sheets")
			main.call("_toggle_help")
			await process_frame
			await process_frame
			var help: PanelContainer = main.get("_help_popup")
			var label: Label = main.get("_help_label")
			var scroll: ScrollContainer = help.get_child(0)
			_check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(help.get_global_rect()), "Help must fit after feedback in another sheet, including on Retina logical viewports.")
			_check(help.size.y <= 340.0, "Help must not become a tall blank feedback panel.")
			if viewport.x >= 760:
				_check(not scroll.get_v_scroll_bar().visible, "Concise laptop help must fit without scrolling.")
			_check(help.get_global_rect().encloses(label.get_global_rect()) or viewport.x < 620, "Laptop help text must be visible, not displaced outside its panel.")
			_check(scroll.scroll_vertical == 0, "Help must open at its first instructions.")
			_check(main.tr(label.text).length() <= 390, "Help must remain a short action reference, not a paragraph tutorial.")
			main.call("_set_status", "Les stations ont besoin d'un peu d'espace.")
			await process_frame
			await process_frame
			_check(help.size.y <= 340.0, "Feedback while help is open must not inflate its panel.")
			main.call("_close_sheets")
			main.call("_set_status", "Les stations ont besoin d'un peu d'espace.")
			main.call("_process", 0.0)
			await process_frame
			await process_frame
			var status_panel: Panel = main.get("_status_panel")
			_check(status_panel.size.y <= 96.0, "A short notification must not become a tall blank panel: %s." % status_panel.size)
			main.call("_set_status", "Cette rame serait trop longue pour un segment. Allongez le tracé.")
			await process_frame
			var status_label: RichTextLabel = main.get("_panel_status")
			_check(status_panel.get_global_rect().encloses(status_label.get_global_rect()), "Wrapped errors must fit inside the measured toast: panel=%s label=%s." % [status_panel.get_global_rect(), status_label.get_global_rect()])
			_check(status_label.get_content_height() <= status_label.size.y, "Measured toast must not clip wrapped error text.")
			main.call("_set_status", "Les stations ont besoin d'un peu d'espace.")
			await process_frame
			_check(status_panel.size.y <= 96.0, "Short error must shrink immediately after a long error.")
			if locale == "en" and viewport.x == 1024 and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				_check(root.get_texture().get_image().save_png("/tmp/metro-toast.png") == OK, "Cannot capture the compact toast.")
			main.call("_process", 9.0)
			_check(not main.get("_status_panel").visible, "Errors must disappear after their reading window.")
			main.call("_set_status", "Les stations ont besoin d'un peu d'espace.")
			_check(is_equal_approx(main.get("_status_seconds"), 8.0), "Errors must keep a longer reading window.")
	TranslationServer.set_locale(original_locale)
	main.call("_close_sheets")

func _test_quiet_guidance() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("startup_layout_enabled", false)
	root.add_child(main)
	main.set_process(false)
	var graph: TransitGraph = main.get("graph")
	var view: WorldView = main.get("world_view")
	main.call("_place_station", Vector2.ZERO)
	main.call("_place_station", Vector2(384, 0))
	main.call("_place_station", Vector2(0, 48))
	main.call("_update_connection_guidance")
	_check(view.connection_hint_station_id == 0, "Before the first connection, a local + must suggest drawing without a popup.")
	_check(main.get("_status_seconds") == 0 and main.get("_panel_status").text.is_empty(), "Station creation must stay silent.")
	main.call("_toggle_settings")
	main.call("_update_connection_guidance")
	_check(view.connection_hint_station_id == -1, "Open sheets must suppress first-step guidance.")
	main.call("_close_sheets")
	main.call("_toggle_ui")
	_check(view.connection_hint_station_id == -1, "Watch mode must suppress first-step guidance.")
	main.call("_toggle_ui")
	main.call("_begin_world_interaction", view.station_handle_position(graph.stations[0], Vector2.RIGHT))
	main.call("_extend_stroke", Vector2(384, 0))
	_check(not view.valid_connection_targets.has(2), "Too-short destinations must not be highlighted as valid.")
	main.call("_extend_stroke", Vector2(0, -144))
	main.call("_pin_route_bend", Vector2(0, -144))
	_check(view.valid_connection_targets.has(1), "A geometrically valid destination must highlight during drawing.")
	main.call("_cancel_gesture")
	_check(view.valid_connection_targets.is_empty(), "Cancelled routes must clear destination highlights.")
	main.call("_connect_stations", 0, 1, PackedVector2Array([Vector2.ZERO, Vector2(0, -144), Vector2(384, -144), Vector2(384, 0)]))
	_check(not graph.tracks.is_empty() and view.connection_hint_station_id == -1, "First successful connection must retire the first-step cue.")
	_check(main.get("_status_seconds") == 0, "Connecting a route must not generate a saved message.")
	main.call("_create_line")
	main.call("_select_line", 0)
	main.call("_on_line_color_changed", Color("#aabbcc"))
	_check(main.get("_status_seconds") == 0, "Route creation, line switching and recoloring must not narrate success.")
	graph.tracks.clear()
	main.call("_update_connection_guidance")
	_check(view.connection_hint_station_id == -1, "The first-step cue must not return after deleting the network.")
	main.queue_free()
	await process_frame

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
	await _mouse_motion(view, graph.stations[0].position)
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
	await _mouse_motion(view, graph.stations[0].position)
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
