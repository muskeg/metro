extends Node2D

const GRID_SIZE := 48.0
const DAY_LENGTH_SECONDS := 300.0
const FOLLOW_ZOOM := 5.0
const UI_IDLE_SECONDS := 8.0
const UI_IDLE_ALPHA := 0.28
const UI_INK := Color("#253b40")
const UI_MUTED := Color("#53666a")
const UI_PAPER := Color("#faf9f4")
const UI_EDGE := Color("#cbd3ce")
const LINE_COLORS := [
	Color("#58b8bd"),
	Color("#e98668"),
	Color("#8d83c7"),
	Color("#d0a84f"),
	Color("#6d9c79"),
	Color("#d275a0")
]
const WorldViewScript := preload("res://scripts/render/world_view.gd")
const TransitGraphScript := preload("res://scripts/sim/transit_graph.gd")
const TransitLineScript := preload("res://scripts/sim/transit_line.gd")
const DispatcherScript := preload("res://scripts/dispatch/dispatcher.gd")
const LayoutStoreScript := preload("res://scripts/layout_store.gd")
const LayoutTransferScript := preload("res://scripts/layout_transfer.gd")

@onready var camera: Camera2D = $Camera2D
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var audio: Node = $Audio

var graph: TransitGraph
var dispatcher: TransitDispatcher
var world_view: WorldView
var lines: Array[TransitLine] = []
var active_line: TransitLine
var selected_station_id: int = -1
var paused: bool = false
var time_of_day: float = 0.5
var _previous_arrival_count: int = 0
var _panning: bool = false
var _left_pan_active: bool = false
var _space_down: bool = false
var _touch_points: Dictionary = {}
var _touch_pair := Vector2i(-1, -1)
var _touch_navigation_active := false
var _touch_navigation_sequence := false
var _touch_previous_center := Vector2.ZERO
var _touch_previous_distance := 0.0
var _touch_world_sequence := false
var _touch_world_pending := false
var _touch_world_interaction_started := false
var _touch_world_index := -1
var _touch_pending_position := Vector2.ZERO
var _followed_train: Metro = null
var _connect_drag_source_id: int = -1
var _drawn_points := PackedVector2Array()
var _route_pins := PackedVector2Array()
var _route_history: Array[PackedVector2Array] = []
var _route_diagonal_first := true
var _route_click_mode := false
var _route_ignore_release := false
var _route_press_position := Vector2.ZERO
var _route_pointer := Vector2.ZERO
var _editing_track_id := -1
var _editing_bend_index := -1
var _editing_segment_index := -1
var _edit_original := PackedVector2Array()
var _edit_pointer_offset := Vector2.ZERO
var _dragging_station_id: int = -1
var _drag_start_position := Vector2.ZERO
var _drag_start_paths: Dictionary = {}
var _panel_status: RichTextLabel
var _line_label: Label
var _line_color_picker: ColorPickerButton
var _close_line_button: Button
var _delete_line_button: Button
var _main_panel: PanelContainer
var _toolbar: HBoxContainer
var _toolbar_actions: HBoxContainer
var _brand: HBoxContainer
var _line_popup: PanelContainer
var _help_popup: PanelContainer
var _status_panel: Panel
var _line_scroll: ScrollContainer
var _line_grid: GridContainer
var _settings_grid: GridContainer
var _dock_row: HBoxContainer
var _rail_stack: VBoxContainer
var _line_stack: VBoxContainer
var _status_seconds := 0.0
var _sheet_feedback: Array[Label] = []
var _ui_root: Control
var _ui_hidden := false
var _pointer_inside := false
var _pointer_position := Vector2.ZERO
var _hide_ui_button: Button
var _restore_ui_button: Button
var _collapse_dock_button: Button
var _collapsed_dock_button: Button
var _dock_collapsed := false
var _zoom_controls: HBoxContainer
var _zoom_in_button: Button
var _zoom_out_button: Button
var _fit_window_button: Button
var _ui_idle_seconds := 0.0
var _title_seconds := 0.0
var _first_connection_completed := false
var _help_label: Label
var _navigation_help: Label
var _dispatch_slider: HSlider
var _dwell_slider: HSlider
var _velocity_slider: HSlider
var _dispatch_value: Label
var _dwell_value: Label
var _velocity_value: Label
var _wagon_slider: HSlider
var _wagon_value: Label
var _max_trains_slider: HSlider
var _max_trains_value: Label
var _pause_button: Button
var _settings_button: Button
var _help_button: Button
var _fullscreen_button: CheckButton
var _line_selector: HBoxContainer
var _line_button_group: ButtonGroup
var _settings_popup: PanelContainer
var _master_volume: HSlider
var _quit_dialog: ConfirmationDialog
var _delete_dialog: ConfirmationDialog
var _delete_station_id := -1
var _delete_track_id := -1
var _delete_line_id := -1
var _updating_line_controls: bool = false
var _language_selector: OptionButton
var _status_source := ""
var _status_arguments: Array = []
var _status_arguments_are_keys := false
const SETTINGS_PATH := "user://settings.cfg"
var settings_path := SETTINGS_PATH
var layout_store := LayoutStoreScript.new()
var startup_layout_enabled := true
var _minimum_camera_zoom := 0.08
var _layout_popup: PanelContainer
var _layout_name: LineEdit
var _saved_layouts: OptionButton
var _layout_action: Button
var _layout_heading: Label
var _layout_saving := false
var _layout_dialog: ConfirmationDialog
var _pending_layout_operation := ""
var _pending_layout_name := ""
var _pending_layout_bundled := ""
var _pending_import: Dictionary = {}
var _layout_transfer: Node
var _export_layout_button: Button
var _import_layout_button: Button

func _ready() -> void:
	_load_language()
	_configure_display()
	graph = TransitGraphScript.new()
	dispatcher = DispatcherScript.new(graph)
	world_view = WorldViewScript.new()
	add_child(world_view)
	world_view.set_network(graph, lines)
	_create_interface()
	_layout_transfer = LayoutTransferScript.new()
	_layout_transfer.imported.connect(_request_imported_layout)
	_layout_transfer.failed.connect(_on_transfer_failed)
	_layout_transfer.exported.connect(func() -> void: _set_status("Réseau exporté."))
	add_child(_layout_transfer)
	_create_line()
	_refresh_network()
	_update_configuration_ui()
	if startup_layout_enabled:
		var starter := layout_store.load_starter_layout()
		if starter.is_empty():
			_set_status("Impossible de charger le réseau inclus. Utilisez Charger pour réessayer.")
		else:
			_replace_layout(starter, true)
	get_window().mouse_exited.connect(_on_pointer_exited)

func _configure_display() -> void:
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_size = Vector2i.ZERO
	_update_display_density()
	window.dpi_changed.connect(_update_display_density)
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	var usable := DisplayServer.screen_get_usable_rect()
	var desired := Vector2i(Vector2(1180.0, 740.0) * window.content_scale_factor)
	window.size = desired.min(usable.size - Vector2i(48, 64))
	window.position = usable.position + (usable.size - window.size) / 2

func _update_display_density() -> void:
	var scale := maxf(1.0, DisplayServer.screen_get_scale())
	if not is_equal_approx(get_window().content_scale_factor, scale):
		get_window().content_scale_factor = scale
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		get_window().min_size = Vector2i(Vector2(760.0, 520.0) * scale)

func _process(delta: float) -> void:
	_update_title_fade(delta)
	_update_ui_idle(delta)
	_restore_ui_button.queue_redraw()
	_collapsed_dock_button.queue_redraw()
	time_of_day = fposmod(time_of_day + delta / DAY_LENGTH_SECONDS, 1.0)
	canvas_modulate.color = Color.WHITE
	var night_factor := _night_strength(time_of_day)
	audio.call("set_night_factor", night_factor)
	dispatcher.process(delta, paused)
	if _followed_train != null:
		if dispatcher.metros.has(_followed_train):
			camera.position = _followed_train.position
		else:
			_stop_following()
	if dispatcher.arrival_count > _previous_arrival_count:
		_previous_arrival_count = dispatcher.arrival_count
		var last_line := lines[dispatcher.last_arrival_line_id]
		audio.call("play_arrival", last_line.color.h, night_factor)
	_update_interaction_overlays()
	world_view.set_dynamic_state(dispatcher.metros, camera.get_screen_center_position(), camera.zoom, time_of_day, dispatcher.visits)
	_update_connection_guidance()
	if _connect_drag_source_id < 0 and _dragging_station_id < 0 and _editing_track_id < 0:
		if _pointer_inside and not _ui_hidden and not _any_sheet_open() and not _space_down and get_viewport().gui_get_hovered_control() == null and not _panning:
			_update_hover(world_view.get_global_transform_with_canvas().affine_inverse() * _pointer_position)
		else:
			_clear_hover()
	_update_status()
	_status_seconds = maxf(0.0, _status_seconds - delta)
	_status_panel.visible = _status_seconds > 0.0 and not _any_sheet_open()
	if _status_seconds <= 0.0:
		for feedback: Label in _sheet_feedback:
			feedback.hide()

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseMotion and not event.relative.is_zero_approx()) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed) or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventGesture:
		_wake_interface()
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
		return
	if event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
		return
	if (_touch_navigation_sequence or _touch_world_sequence) and event is InputEventMouse:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and _ui_hidden and event.keycode in [KEY_H, KEY_ESCAPE]:
		_toggle_ui()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse:
		_pointer_position = event.position
		_pointer_inside = get_viewport_rect().has_point(event.position)
		if event is InputEventMouseMotion and _connect_drag_source_id < 0 and _dragging_station_id < 0 and _editing_track_id < 0:
			world_view.station_preview_visible = false
	var world_position := _event_world_position(event) if event is InputEventMouse else get_global_mouse_position()
	if event is InputEventKey and event.pressed and not event.echo and _connect_drag_source_id >= 0:
		if event.keycode == KEY_TAB:
			_flip_route_posture()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_BACKSPACE:
			if not _route_history.is_empty():
				_route_pins = _route_history.pop_back()
			_extend_stroke(_route_pointer)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _connect_drag_source_id >= 0 and _route_click_mode and get_viewport().gui_get_hovered_control() == null:
		if _near_handle(world_position, world_view.route_flip_position()):
			_flip_route_posture()
		else:
			_end_world_interaction(world_position)
		_route_ignore_release = _connect_drag_source_id >= 0
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _route_ignore_release:
			_route_ignore_release = false
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and (_connect_drag_source_id >= 0 or _dragging_station_id >= 0 or _editing_track_id >= 0):
			var hovered := get_viewport().gui_get_hovered_control()
			if hovered != null:
				_cancel_gesture()
				_set_status("Dessin annulé : relâchez le bouton sur une station.")
			else:
				_end_world_interaction(world_position)
			get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and _left_pan_active):
			_panning = false
			_left_pan_active = false
	if event is InputEventMouseMotion:
		if _editing_track_id >= 0:
			_update_track_edit(world_position - _edit_pointer_offset)
			get_viewport().set_input_as_handled()
		elif _dragging_station_id >= 0:
			_move_station_to(_dragging_station_id, world_position)
			get_viewport().set_input_as_handled()
		elif _connect_drag_source_id >= 0:
			world_view.hover_pointer = world_position
			if not _route_click_mode or not _near_handle(world_position, world_view.route_flip_position()):
				_extend_stroke(world_position)
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		_cancel_gesture()
		if _followed_train != null:
			_stop_following()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_gesture()

func _event_world_position(event: InputEventMouse) -> Vector2:
	return world_view.get_global_transform_with_canvas().affine_inverse() * event.position

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_points[event.index] = event.position
		if _touch_points.size() == 1 and not _screen_point_over_ui(event.position):
			_touch_world_sequence = true
			_touch_world_pending = true
			_touch_world_interaction_started = false
			_touch_world_index = event.index
			_touch_pending_position = event.position
		if not _touch_navigation_sequence and _touch_points.size() == 2:
			var touch_ids: Array = _touch_points.keys()
			var first_position: Vector2 = _touch_points[touch_ids[0]]
			var second_position: Vector2 = _touch_points[touch_ids[1]]
			if not _screen_point_over_ui(first_position) and not _screen_point_over_ui(second_position):
				_touch_pair = Vector2i(touch_ids[0], touch_ids[1])
				_touch_navigation_sequence = true
				_touch_navigation_active = true
				_touch_previous_center = (first_position + second_position) * 0.5
				_touch_previous_distance = first_position.distance_to(second_position)
				_panning = true
				_touch_world_sequence = false
				_touch_world_pending = false
				_touch_world_interaction_started = false
				_touch_world_index = -1
				_cancel_gesture()
				_stop_following()
	elif _touch_points.has(event.index):
		_touch_points.erase(event.index)
		if _touch_world_sequence and event.index == _touch_world_index:
			var world_position := _screen_to_world_position(event.position)
			if _touch_world_pending:
				_begin_world_interaction(_screen_to_world_position(_touch_pending_position))
				_touch_world_interaction_started = true
			if _touch_world_interaction_started:
				_end_world_interaction(world_position)
			_touch_world_sequence = false
			_touch_world_pending = false
			_touch_world_interaction_started = false
			_touch_world_index = -1
		if _touch_navigation_sequence:
			if event.index == _touch_pair.x or event.index == _touch_pair.y:
				_touch_navigation_active = false
				_panning = false
			if _touch_points.is_empty():
				_touch_navigation_sequence = false
				_touch_pair = Vector2i(-1, -1)
				_touch_previous_distance = 0.0
	if _touch_navigation_sequence:
		get_viewport().set_input_as_handled()

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not _touch_points.has(event.index):
		return
	_touch_points[event.index] = event.position
	if _touch_world_sequence and event.index == _touch_world_index:
		if _touch_world_pending and event.position.distance_to(_touch_pending_position) >= 8.0:
			_begin_world_interaction(_screen_to_world_position(_touch_pending_position))
			_touch_world_pending = false
			_touch_world_interaction_started = true
		if _touch_world_interaction_started:
			_update_touch_world_interaction(_screen_to_world_position(event.position))
	if _touch_navigation_active and (_touch_pair.x == event.index or _touch_pair.y == event.index):
		var first_position: Vector2 = _touch_points[_touch_pair.x]
		var second_position: Vector2 = _touch_points[_touch_pair.y]
		var center := (first_position + second_position) * 0.5
		var distance := first_position.distance_to(second_position)
		var center_delta := center - _touch_previous_center
		if not center_delta.is_zero_approx():
			camera.position -= center_delta / camera.zoom
		if _touch_previous_distance > 0.0 and distance > 0.0:
			_zoom_camera_at(distance / _touch_previous_distance, center)
		_touch_previous_center = center
		_touch_previous_distance = distance
	if _touch_navigation_sequence:
		get_viewport().set_input_as_handled()

func _update_touch_world_interaction(world_position: Vector2) -> void:
	if _editing_track_id >= 0:
		_update_track_edit(world_position - _edit_pointer_offset)
	elif _dragging_station_id >= 0:
		_move_station_to(_dragging_station_id, world_position)
	elif _connect_drag_source_id >= 0:
		world_view.hover_pointer = world_position
		if not _route_click_mode or not _near_handle(world_position, world_view.route_flip_position()):
			_extend_stroke(world_position)

func _screen_to_world_position(screen_position: Vector2) -> Vector2:
	return world_view.get_global_transform_with_canvas().affine_inverse() * screen_position

func _screen_point_over_ui(screen_position: Vector2) -> bool:
	if _control_tree_contains_point(_ui_root, screen_position):
		return true
	return _restore_ui_button.is_visible_in_tree() and _restore_ui_button.get_global_rect().has_point(screen_position)

func _control_tree_contains_point(node: Node, screen_position: Vector2) -> bool:
	if node is Control:
		var control := node as Control
		if not control.is_visible_in_tree():
			return false
		if control.mouse_filter == Control.MOUSE_FILTER_STOP and control.get_global_rect().has_point(screen_position):
			return true
	for child: Node in node.get_children():
		if _control_tree_contains_point(child, screen_position):
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_SPACE:
			_space_down = key_event.pressed
		elif key_event.pressed and key_event.keycode == KEY_ESCAPE:
			if _any_sheet_open():
				_close_sheets()
			else:
				selected_station_id = -1
		elif key_event.pressed and key_event.keycode == KEY_P:
			_toggle_pause()
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_H:
			_toggle_ui()
		elif key_event.pressed and key_event.keycode == KEY_F11:
			_toggle_fullscreen()
		elif key_event.pressed and key_event.keycode == KEY_DELETE and not _ui_hidden and _followed_train == null:
			_request_delete(selected_station_id if selected_station_id >= 0 else world_view.hovered_station_id, world_view.hovered_track_id)
	if event is InputEventPanGesture:
		var pan_event := event as InputEventPanGesture
		if not pan_event.delta.is_zero_approx():
			_stop_following()
			camera.position -= pan_event.delta / camera.zoom
		get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		var magnify_event := event as InputEventMagnifyGesture
		if magnify_event.factor > 0.0:
			_zoom_camera(magnify_event.factor)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_zoom_camera(1.12)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_zoom_camera(1.0 / 1.12)
		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mouse_event.pressed
			if _panning:
				_stop_following()
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and _space_down:
			_panning = true
			_left_pan_active = true
			_stop_following()
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed and _left_pan_active:
			_panning = false
			_left_pan_active = false
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_begin_world_interaction(_event_world_position(mouse_event))
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_end_world_interaction(_event_world_position(mouse_event))
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _panning:
			camera.position -= motion.relative / camera.zoom
		elif _dragging_station_id >= 0:
			_move_station_to(_dragging_station_id, _event_world_position(motion))

func _create_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui_root := Control.new()
	_ui_root = ui_root
	ui_root.theme = _interface_theme()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)
	_restore_ui_button = _edge_handle("Afficher l'interface", _toggle_ui)
	_restore_ui_button.theme = ui_root.theme
	_restore_ui_button.hide()
	layer.add_child(_restore_ui_button)

	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 12)
	_toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(_toolbar)
	_brand = HBoxContainer.new()
	_brand.add_theme_constant_override("separation", 8)
	_brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for artwork: String in ["res://assets/branding/metro-mark.svg", "res://assets/branding/metro-wordmark.svg"]:
		var texture := TextureRect.new()
		texture.texture = load(artwork)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.custom_minimum_size = Vector2(60, 60) if artwork.ends_with("metro-mark.svg") else Vector2(180, 60)
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_brand.add_child(texture)
	layer.add_child(_brand)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toolbar.add_child(spacer)
	_toolbar_actions = HBoxContainer.new()
	_toolbar_actions.add_theme_constant_override("separation", 8)
	_toolbar.add_child(_toolbar_actions)
	_pause_button = _button("Pause", _toggle_pause)
	_toolbar_actions.add_child(_pause_button)
	_help_button = _button("Aide", _toggle_help)
	_help_button.toggle_mode = true
	_toolbar_actions.add_child(_help_button)
	_settings_button = _button("Menu", _toggle_settings)
	_settings_button.toggle_mode = true
	_toolbar_actions.add_child(_settings_button)

	var panel := PanelContainer.new()
	_main_panel = panel
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var rail_style := StyleBoxFlat.new()
	rail_style.bg_color = UI_PAPER
	rail_style.border_color = UI_EDGE
	rail_style.border_width_top = 1
	rail_style.content_margin_left = 16.0
	rail_style.content_margin_right = 16.0
	rail_style.content_margin_top = 8.0
	rail_style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", rail_style)
	ui_root.add_child(panel)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_rail_stack = VBoxContainer.new()
	_rail_stack.add_theme_constant_override("separation", 8)
	panel.add_child(_rail_stack)
	_line_popup = PanelContainer.new()
	_line_popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_line_popup.hide()
	_rail_stack.add_child(_line_popup)
	var dock := HBoxContainer.new()
	_dock_row = dock
	dock.add_theme_constant_override("separation", 8)
	_rail_stack.add_child(dock)
	_line_scroll = ScrollContainer.new()
	_line_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_line_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock.add_child(_line_scroll)
	_line_selector = HBoxContainer.new()
	_line_selector.add_theme_constant_override("separation", 8)
	_line_scroll.add_child(_line_selector)
	_line_button_group = ButtonGroup.new()
	_collapse_dock_button = _dock_button(false)
	_collapse_dock_button.tooltip_text = "Replier les lignes"
	dock.add_child(_collapse_dock_button)
	_collapsed_dock_button = _dock_button(true)
	_collapsed_dock_button.tooltip_text = "Afficher les lignes"
	_collapsed_dock_button.hide()
	ui_root.add_child(_collapsed_dock_button)
	_zoom_controls = HBoxContainer.new()
	_zoom_controls.add_theme_constant_override("separation", 4)
	ui_root.add_child(_zoom_controls)
	_zoom_out_button = _button("-", _zoom_camera.bind(1.0 / 1.25))
	_zoom_out_button.tooltip_text = "Zoom arrière"
	_zoom_in_button = _button("+", _zoom_camera.bind(1.25))
	_zoom_in_button.tooltip_text = "Zoom avant"
	_fit_window_button = _button("", _fit_window)
	_fit_window_button.tooltip_text = "Ajuster à la fenêtre"
	_fit_window_button.draw.connect(_draw_fit_icon)
	for button: Button in [_zoom_out_button, _zoom_in_button, _fit_window_button]:
		button.custom_minimum_size = Vector2(44, 44)
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		_zoom_controls.add_child(button)

	var details_stack := VBoxContainer.new()
	details_stack.add_theme_constant_override("separation", 12)
	_line_popup.add_child(details_stack)
	var line_details := HBoxContainer.new()
	line_details.add_theme_constant_override("separation", 12)
	_line_label = _label("LIGNE 01", 16, UI_INK)
	_line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_details.add_child(_line_label)
	_close_line_button = _button("Replier", _close_sheets)
	_close_line_button.tooltip_text = "Fermer les réglages de ligne"
	_close_line_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	line_details.add_child(_close_line_button)
	details_stack.add_child(line_details)
	var details_body := PanelContainer.new()
	details_body.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	details_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_stack.add_child(details_body)
	var stack := _sheet_stack(details_body)
	_line_stack = stack
	stack.add_theme_constant_override("separation", 12)
	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 12)
	var color_label := _label("Couleur de la ligne", 16, UI_INK)
	color_row.add_child(color_label)
	_line_color_picker = ColorPickerButton.new()
	_line_color_picker.custom_minimum_size = Vector2(80.0, 44.0)
	_line_color_picker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_line_color_picker.edit_alpha = false
	_line_color_picker.tooltip_text = "Choisir la couleur de la ligne"
	_line_color_picker.color_changed.connect(_on_line_color_changed)
	var picker := _line_color_picker.get_picker()
	picker.theme = ui_root.theme
	_line_color_picker.get_popup().add_theme_stylebox_override("panel", _panel_style())
	picker.edit_alpha = false
	picker.edit_intensity = false
	picker.color_modes_visible = false
	picker.sliders_visible = false
	picker.sampler_visible = false
	picker.add_theme_constant_override("sv_height", 168)
	picker.add_theme_constant_override("sv_width", 220)
	for color: Color in LINE_COLORS:
		picker.add_preset(color)
	color_row.add_child(_line_color_picker)
	stack.add_child(color_row)
	_add_sheet_feedback(stack)
	_line_grid = GridContainer.new()
	_line_grid.columns = 2
	_line_grid.add_theme_constant_override("h_separation", 28)
	_line_grid.add_theme_constant_override("v_separation", 12)
	stack.add_child(_line_grid)
	_dispatch_slider = _add_slider(_line_grid, "Intervalle minimum", 8.0, 60.0, 18.0, _on_dispatch_changed, "_dispatch_value")
	_max_trains_slider = _add_slider(_line_grid, "Trains maximum", 1.0, 16.0, 4.0, _on_max_trains_changed, "_max_trains_value")
	_dwell_slider = _add_slider(_line_grid, "Arrêt en station", 0.0, 12.0, 3.0, _on_dwell_changed, "_dwell_value")
	_velocity_slider = _add_slider(_line_grid, "Vitesse de croisière", 40.0, 220.0, 100.0, _on_velocity_changed, "_velocity_value")
	_wagon_slider = _add_slider(_line_grid, "Wagons par train", 1.0, 6.0, 2.0, _on_wagon_changed, "_wagon_value")
	_delete_line_button = _button("Supprimer la ligne", _request_delete_line)
	_delete_line_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	stack.add_child(_delete_line_button)

	_status_panel = Panel.new()
	_status_panel.add_theme_stylebox_override("panel", _panel_style())
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(_status_panel)
	_panel_status = RichTextLabel.new()
	_panel_status.add_theme_font_override("normal_font", ui_root.get_theme_font("font", "Label"))
	_panel_status.add_theme_font_size_override("normal_font_size", 16)
	_panel_status.add_theme_color_override("default_color", UI_INK)
	_panel_status.scroll_active = false
	_panel_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_panel.add_child(_panel_status)

	_help_popup = _make_sheet(ui_root)
	_help_popup.minimum_size_changed.connect(_resize_interface.call_deferred)
	var help_stack := _sheet_stack(_help_popup)
	help_stack.add_theme_constant_override("separation", 8)
	_sheet_heading(help_stack, "Aide")
	_help_label = _label("Carte : cliquer pour placer une station\nStation : glisser le centre pour déplacer, + pour relier\nRail : losange pour remodeler, + pour insérer, × pour supprimer\nTrain : cliquer pour suivre\nTracé : Tab inverse le coude, Retour arrière annule une étape\nBoucle : relier les extrémités d'une ligne", 16, UI_INK)
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.add_theme_constant_override("line_spacing", 2)
	help_stack.add_child(_help_label)
	_navigation_help = _label("Vue : molette/pincer pour zoomer ; deux doigts ou Espace + glisser pour déplacer\nÉchap / clic droit : annuler", 16, UI_MUTED)
	_navigation_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_stack.add_child(_navigation_help)
	var watch_help := _label("H : masquer · H / Échap ou poignée en bas : revenir", 16, UI_MUTED)
	watch_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_stack.add_child(watch_help)

	_settings_popup = _make_sheet(ui_root)
	var settings_stack := _sheet_stack(_settings_popup, false)
	_settings_popup.minimum_size_changed.connect(_resize_interface.call_deferred)
	_sheet_heading(settings_stack, "RÉGLAGES")
	_settings_grid = GridContainer.new()
	_settings_grid.columns = 2
	_settings_grid.add_theme_constant_override("h_separation", 28)
	_settings_grid.add_theme_constant_override("v_separation", 16)
	settings_stack.add_child(_settings_grid)
	var language_cell := VBoxContainer.new()
	language_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_grid.add_child(language_cell)
	language_cell.add_child(_label("Langue", 16, UI_MUTED))
	_language_selector = OptionButton.new()
	_language_selector.custom_minimum_size.y = 44.0
	_language_selector.add_item("English")
	_language_selector.add_item("Français")
	_language_selector.select(1 if TranslationServer.get_locale().begins_with("fr") else 0)
	_language_selector.item_selected.connect(_on_language_selected)
	language_cell.add_child(_language_selector)
	_fullscreen_button = CheckButton.new()
	_fullscreen_button.text = "Plein écran"
	_fullscreen_button.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen_button.toggled.connect(_set_fullscreen)
	_fullscreen_button.custom_minimum_size.y = 44.0
	_fullscreen_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_settings_grid.add_child(_fullscreen_button)
	_master_volume = _add_volume(_settings_grid, "Volume général", AudioServer.get_bus_volume_linear(0), _set_master_volume)
	_add_volume(_settings_grid, "Musique", 0.4, func(value: float) -> void: audio.call("set_music_volume", value))
	_add_volume(_settings_grid, "Sons des trains", 0.5, func(value: float) -> void: audio.call("set_effects_volume", value))
	_hide_ui_button = _button("Masquer l'interface (H)", _toggle_ui)
	_hide_ui_button.tooltip_text = "H / Échap ou toucher la poignée en bas pour revenir"
	_settings_grid.add_child(_hide_ui_button)
	if not OS.has_feature("web"):
		_settings_grid.add_child(_button("Quitter le jeu", _confirm_quit))
	var layout_controls := HBoxContainer.new()
	layout_controls.add_theme_constant_override("separation", 8)
	_settings_grid.add_child(layout_controls)
	var save_layout_button := _button("Enregistrer", _open_layouts.bind(true))
	save_layout_button.tooltip_text = "Enregistrer un réseau"
	layout_controls.add_child(save_layout_button)
	var load_layout_button := _button("Charger", _open_layouts.bind(false))
	load_layout_button.tooltip_text = "Charger un réseau"
	layout_controls.add_child(load_layout_button)
	var clear_map_button := _button("Vider", _request_clear_map)
	clear_map_button.tooltip_text = "Vider la carte"
	layout_controls.add_child(clear_map_button)
	var transfer_controls := HBoxContainer.new()
	transfer_controls.add_theme_constant_override("separation", 8)
	_settings_grid.add_child(transfer_controls)
	_export_layout_button = _button("Exporter", _export_layout)
	_export_layout_button.tooltip_text = "Exporter un réseau"
	transfer_controls.add_child(_export_layout_button)
	_import_layout_button = _button("Importer", _import_layout)
	_import_layout_button.tooltip_text = "Importer un réseau"
	transfer_controls.add_child(_import_layout_button)

	_layout_popup = _make_sheet(ui_root)
	var layout_stack := _sheet_stack(_layout_popup, false)
	_sheet_heading(layout_stack, "RÉSEAUX")
	_layout_heading = _label("Nom du réseau", 16, UI_MUTED)
	layout_stack.add_child(_layout_heading)
	_layout_name = LineEdit.new()
	_layout_name.max_length = 64
	_layout_name.custom_minimum_size.y = 44.0
	_layout_name.text_submitted.connect(func(_text: String) -> void: _request_layout_action())
	layout_stack.add_child(_layout_name)
	_saved_layouts = OptionButton.new()
	_saved_layouts.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_saved_layouts.custom_minimum_size.y = 44.0
	_saved_layouts.clip_text = true
	_saved_layouts.item_selected.connect(func(index: int) -> void: _layout_name.text = _saved_layouts.get_item_text(index))
	layout_stack.add_child(_saved_layouts)
	_layout_action = _button("Enregistrer", _request_layout_action)
	layout_stack.add_child(_layout_action)
	var persistence_note := _label("Les réseaux restent sur cet appareil. Dans le navigateur, effacer les données du site efface les sauvegardes.", 16, UI_MUTED)
	persistence_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout_stack.add_child(persistence_note)
	_layout_popup.minimum_size_changed.connect(_resize_interface.call_deferred)

	_quit_dialog = ConfirmationDialog.new()
	_quit_dialog.title = "Quitter Metro"
	_quit_dialog.dialog_text = "Voulez-vous vraiment quitter le jeu ?"
	_quit_dialog.ok_button_text = "Quitter"
	_quit_dialog.cancel_button_text = "Annuler"
	_quit_dialog.confirmed.connect(_quit_game)
	ui_root.add_child(_quit_dialog)
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Supprimer du réseau"
	_delete_dialog.ok_button_text = "Supprimer"
	_delete_dialog.cancel_button_text = "Annuler"
	_delete_dialog.confirmed.connect(_apply_delete)
	_style_delete_dialog(_delete_dialog)
	ui_root.add_child(_delete_dialog)
	_layout_dialog = ConfirmationDialog.new()
	_layout_dialog.title = "RÉSEAUX"
	_layout_dialog.cancel_button_text = "Annuler"
	_layout_dialog.confirmed.connect(_confirm_layout_operation)
	_layout_dialog.canceled.connect(_cancel_layout_operation)
	_style_delete_dialog(_layout_dialog)
	ui_root.add_child(_layout_dialog)
	_resize_interface()

func _on_viewport_resized() -> void:
	if OS.has_feature("web"):
		_update_display_density()
	_resize_interface()

func _resize_interface() -> void:
	var viewport_size := get_viewport_rect().size
	var width := maxf(0.0, viewport_size.x - 32.0)
	var narrow := viewport_size.x < 620.0
	_brand.visible = not narrow and not _ui_hidden and _title_seconds < 30.0
	_brand.position = Vector2(16.0, 16.0)
	_brand.size = _brand.get_combined_minimum_size()
	_toolbar.position = Vector2(16.0, 16.0)
	_toolbar.size = Vector2(width, 44.0)
	_line_grid.columns = 1 if narrow else (5 if viewport_size.x >= 1366.0 else (3 if viewport_size.x >= 760.0 else 2))
	_settings_grid.columns = 1 if narrow else 2
	_settings_grid.add_theme_constant_override("v_separation", 8 if narrow else 16)
	var desired_height := minf(300.0, _line_stack.get_combined_minimum_size().y + _close_line_button.get_combined_minimum_size().y + 20.0)
	var details_height := minf(desired_height, maxf(0.0, viewport_size.y - 148.0)) if _line_popup.visible else 0.0
	_line_popup.custom_minimum_size.y = details_height
	_main_panel.size = Vector2(viewport_size.x, 60.0 + (details_height + 8.0 if _line_popup.visible else 0.0))
	_main_panel.position = Vector2(0.0, viewport_size.y - _main_panel.size.y)
	_zoom_controls.size = _zoom_controls.get_combined_minimum_size()
	var zoom_bottom := viewport_size.y - 60.0 if _dock_collapsed else _main_panel.position.y
	_zoom_controls.position = Vector2(viewport_size.x - _zoom_controls.size.x - 16.0, zoom_bottom - _zoom_controls.size.y - 4.0)
	for handle: Button in [_collapsed_dock_button, _restore_ui_button]:
		handle.size = handle.get_combined_minimum_size()
		var x := viewport_size.x - handle.size.x - 16.0 if handle == _collapsed_dock_button else (viewport_size.x - handle.size.x) * 0.5
		handle.position = Vector2(x, viewport_size.y - handle.size.y - 8.0)
	var sheet_width := minf(640.0, width)
	for sheet: PanelContainer in [_settings_popup, _help_popup, _layout_popup]:
		var sheet_height := sheet.get_combined_minimum_size().y if sheet != _help_popup else minf(340.0, maxf(0.0, viewport_size.y - 32.0))
		sheet.size = Vector2(sheet_width, sheet_height)
		sheet.position = (viewport_size - sheet.size) * 0.5
	_resize_notification()

func _update_title_fade(delta: float) -> void:
	_title_seconds = minf(30.0, _title_seconds + delta)
	_brand.modulate.a = 1.0 - smoothstep(10.0, 30.0, _title_seconds)
	if _title_seconds >= 30.0:
		_brand.hide()

func _resize_notification() -> void:
	var font := _panel_status.get_theme_font("normal_font")
	var font_size := _panel_status.get_theme_font_size("normal_font_size")
	var style := _status_panel.get_theme_stylebox("panel")
	var margins := style.get_minimum_size()
	var max_width := minf(520.0, get_viewport_rect().size.x - 32.0) - margins.x
	var text_width := minf(font.get_string_size(_panel_status.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, max_width)
	var text_size := font.get_multiline_string_size(_panel_status.text, HORIZONTAL_ALIGNMENT_LEFT, maxf(1.0, text_width), font_size)
	_panel_status.position = Vector2(style.get_content_margin(SIDE_LEFT), style.get_content_margin(SIDE_TOP))
	_panel_status.size = Vector2(text_width, text_size.y)
	_status_panel.size = Vector2(text_width, text_size.y) + margins
	_status_panel.position = Vector2((get_viewport_rect().size.x - _status_panel.size.x) * 0.5, 76.0)

func _toggle_dock() -> void:
	_wake_interface()
	_close_sheets()
	_dock_collapsed = not _dock_collapsed
	_main_panel.visible = not _dock_collapsed
	_collapsed_dock_button.visible = _dock_collapsed
	_resize_interface()

func _wake_interface() -> void:
	_ui_idle_seconds = 0.0
	_ui_root.modulate.a = 1.0

func _update_ui_idle(delta: float) -> void:
	if _ui_hidden or _any_sheet_open() or _quit_dialog.visible or _delete_dialog.visible or _layout_dialog.visible or _line_color_picker.get_popup().visible or _connect_drag_source_id >= 0 or _dragging_station_id >= 0 or _editing_track_id >= 0 or _panning or _space_down:
		_wake_interface()
		return
	var fade_delta := maxf(0.0, _ui_idle_seconds + delta - UI_IDLE_SECONDS) - maxf(0.0, _ui_idle_seconds - UI_IDLE_SECONDS)
	_ui_idle_seconds += delta
	var idle_alpha := lerpf(UI_IDLE_ALPHA, 0.7, _night_strength(time_of_day))
	_ui_root.modulate.a = move_toward(_ui_root.modulate.a, idle_alpha, fade_delta * (1.0 - UI_IDLE_ALPHA) / 0.6)

func _toggle_help() -> void:
	_toggle_sheet(_help_popup)

func _toggle_line_settings() -> void:
	_toggle_sheet(_line_popup)

func _any_sheet_open() -> bool:
	return _line_popup.visible or _settings_popup.visible or _help_popup.visible or _layout_popup.visible

func _close_sheets() -> void:
	for sheet: PanelContainer in [_line_popup, _settings_popup, _help_popup, _layout_popup]:
		sheet.hide()
	_line_color_picker.get_popup().hide()
	for button: Button in [_settings_button, _help_button]:
		button.set_pressed_no_signal(false)
	for feedback: Label in _sheet_feedback:
		feedback.text = ""
		feedback.hide()
	_resize_interface()

func _toggle_sheet(sheet: PanelContainer) -> void:
	_wake_interface()
	var was_visible := sheet.visible
	_close_sheets()
	if not was_visible:
		_cancel_gesture()
		sheet.show()
		if sheet == _line_popup:
			_dock_collapsed = false
			_main_panel.show()
			_collapsed_dock_button.hide()
		elif sheet == _settings_popup or sheet == _layout_popup:
			_settings_button.set_pressed_no_signal(true)
		else:
			_help_button.set_pressed_no_signal(true)
		_resize_interface()

func _make_sheet(parent: Control) -> PanelContainer:
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", _panel_style())
	parent.add_child(sheet)
	sheet.hide()
	return sheet

func _sheet_stack(sheet: PanelContainer, scrollable: bool = true) -> VBoxContainer:
	var parent: Control = sheet
	if scrollable:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sheet.add_child(scroll)
		parent = scroll
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 16)
	parent.add_child(stack)
	return stack

func _sheet_heading(stack: VBoxContainer, title: String) -> void:
	var row := HBoxContainer.new()
	var label := _label(title, 22, UI_INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var close := _button("Fermer", _close_sheets)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(close)
	stack.add_child(row)
	_add_sheet_feedback(stack)

func _add_sheet_feedback(stack: VBoxContainer) -> void:
	var feedback := _label("", 16, UI_INK)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(feedback)
	feedback.hide()
	_sheet_feedback.append(feedback)

func _add_volume(parent: GridContainer, title: String, initial: float, callback: Callable) -> HSlider:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(cell)
	cell.add_child(_label(title, 16, UI_MUTED))
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial
	slider.custom_minimum_size.y = 32.0
	slider.value_changed.connect(callback)
	cell.add_child(slider)
	return slider

func _add_slider(parent: GridContainer, title: String, minimum: float, maximum: float, initial: float, callback: Callable, value_field: String) -> HSlider:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(cell)
	var heading := HBoxContainer.new()
	heading.add_child(_label(title, 16, UI_MUTED))
	var value_label := _label("", 16, UI_INK)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(value_label)
	cell.add_child(heading)
	set(value_field, value_label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 1.0
	slider.value = initial
	slider.custom_minimum_size.y = 32.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	cell.add_child(slider)
	return slider

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 44.0
	button.pressed.connect(callback)
	return button

func _style_delete_dialog(dialog: ConfirmationDialog) -> void:
	var theme := _interface_theme()
	var panel := _panel_style()
	panel.set_corner_radius_all(0)
	panel.shadow_size = 0
	theme.set_stylebox("panel", "AcceptDialog", panel)
	theme.set_constant("buttons_min_height", "AcceptDialog", 44)
	theme.set_constant("buttons_min_width", "AcceptDialog", 112)
	dialog.borderless = true
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var button := theme.get_stylebox(state, "Button").duplicate() as StyleBoxFlat
		button.set_corner_radius_all(0)
		theme.set_stylebox(state, "Button", button)
	dialog.theme = theme
	dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _edge_handle(tooltip: String, callback: Callable) -> Button:
	var handle := _button("", callback)
	handle.tooltip_text = tooltip
	handle.custom_minimum_size = Vector2(96.0, 44.0)
	for state: String in ["normal", "hover", "pressed"]:
		handle.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	handle.draw.connect(_draw_edge_handle.bind(handle))
	return handle

func _dock_button(collapsed: bool) -> Button:
	var button := _button("", _toggle_dock)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.size_flags_vertical = Control.SIZE_SHRINK_END
	button.custom_minimum_size = Vector2(44.0, 44.0)
	button.draw.connect(_draw_dock_icon.bind(button, collapsed))
	return button

func _draw_dock_icon(button: Button, collapsed: bool) -> void:
	var color := button.get_theme_color("font_color")
	var center := button.size * 0.5
	button.draw_polyline(PackedVector2Array([
		center + Vector2(-8, -8), center + Vector2(8, -8),
		center + Vector2(8, 8), center + Vector2(-8, 8),
		center + Vector2(-8, -8),
	]), color, 1.5, true)
	button.draw_line(center + Vector2(-8, 4), center + Vector2(8, 4), color, 1.5, true)
	var direction := -1.0 if collapsed else 1.0
	button.draw_line(center + Vector2(0, -2 - 3 * direction), center + Vector2(0, -2 + 3 * direction), color, 1.5, true)
	button.draw_polyline(PackedVector2Array([
		center + Vector2(-3, -2), center + Vector2(0, -2 + 3 * direction),
		center + Vector2(3, -2),
	]), color, 1.5, true)

func _draw_fit_icon() -> void:
	var center := _fit_window_button.size * 0.5
	var color := _fit_window_button.get_theme_color("font_color")
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var point := center + corner * 9.0
		_fit_window_button.draw_polyline(PackedVector2Array([
			point - Vector2(corner.x * 6.0, 0), point,
			point - Vector2(0, corner.y * 6.0)
		]), color, 1.5, true)

func _draw_edge_handle(handle: Button) -> void:
	var color := UI_INK.lerp(Color("#dce5e4"), _night_strength(time_of_day))
	color.a = 0.85 if handle.is_hovered() else 0.45
	var center := handle.size * 0.5
	handle.draw_line(center - Vector2(18.0, 0.0), center + Vector2(18.0, 0.0), color, 3.0, true)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UI_PAPER
	style.border_color = UI_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(12.0)
	style.shadow_color = Color(0.05, 0.10, 0.12, 0.08)
	style.shadow_size = 3
	return style

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _interface_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	for type: String in ["Button", "OptionButton", "CheckButton", "Label"]:
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, UI_INK)
	for type: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, _button_style(UI_PAPER))
		theme.set_stylebox("hover", type, _button_style(Color("#e8ede7")))
		theme.set_stylebox("pressed", type, _button_style(Color("#d3e4db")))
		theme.set_stylebox("hover_pressed", type, _button_style(Color("#c6dcd0")))
		var focus := _button_style(Color.TRANSPARENT)
		focus.border_color = UI_INK
		focus.set_border_width_all(2)
		theme.set_stylebox("focus", type, focus)
	for type: String in ["PopupMenu", "AcceptDialog", "TooltipPanel"]:
		theme.set_stylebox("panel", type, _panel_style())
	theme.set_color("font_color", "TooltipLabel", UI_INK)
	theme.set_color("font_color", "PopupMenu", UI_INK)
	theme.set_color("font_hover_color", "PopupMenu", UI_INK)
	theme.set_stylebox("hover", "PopupMenu", _button_style(Color("#d3e4db")))
	var rail := _button_style(UI_EDGE)
	rail.set_content_margin_all(0.0)
	rail.set_corner_radius_all(3)
	rail.content_margin_top = 3.0
	rail.content_margin_bottom = 3.0
	theme.set_stylebox("slider", "HSlider", rail)
	var fill := rail.duplicate() as StyleBoxFlat
	fill.bg_color = Color("#48766c")
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.8, 1.0])
	gradient.colors = PackedColorArray([UI_INK, UI_INK, Color(UI_INK, 0.0)])
	var thumb := GradientTexture2D.new()
	thumb.width = 20
	thumb.height = 20
	thumb.fill = GradientTexture2D.FILL_RADIAL
	thumb.fill_from = Vector2(0.5, 0.5)
	thumb.fill_to = Vector2(1.0, 0.5)
	thumb.gradient = gradient
	theme.set_icon("grabber", "HSlider", thumb)
	theme.set_icon("grabber_highlight", "HSlider", thumb)
	return theme

func _create_line() -> void:
	_cancel_gesture()
	_line_color_picker.get_popup().hide()
	var line := TransitLineScript.new(lines.size(), LINE_COLORS[lines.size() % LINE_COLORS.size()])
	lines.append(line)
	dispatcher.add_line(line)
	active_line = line
	selected_station_id = -1
	_refresh_network()
	_refresh_line_selector()
	_update_configuration_ui()

func _refresh_line_selector() -> void:
	for child in _line_selector.get_children():
		_line_selector.remove_child(child)
		child.queue_free()
	for line: TransitLine in lines:
		var button := Button.new()
		button.text = tr("Ligne %02d") % (line.id + 1)
		button.tooltip_text = line.display_name
		button.custom_minimum_size = Vector2(96.0, 44.0)
		button.toggle_mode = true
		button.button_group = _line_button_group
		button.button_pressed = line == active_line
		_style_line_tab(button, line.color)
		button.pressed.connect(_on_line_tab_pressed.bind(line.id))
		_line_selector.add_child(button)
	var new_line := _button("+", _create_line)
	new_line.tooltip_text = tr("+ Nouvelle")
	new_line.custom_minimum_size = Vector2(44.0, 44.0)
	new_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_line_tab(new_line, UI_INK)
	_line_selector.add_child(new_line)
	_reveal_active_line.call_deferred()
	_resize_interface()

func _reveal_active_line() -> void:
	if active_line.id == lines.size() - 1:
		_line_scroll.ensure_control_visible(_line_selector.get_child(lines.size()))
	_line_scroll.ensure_control_visible(_line_selector.get_child(active_line.id))

func _style_line_tab(button: Button, color: Color) -> void:
	button.add_theme_color_override("font_color", UI_INK)
	button.add_theme_color_override("font_pressed_color", UI_INK)
	button.add_theme_color_override("font_hover_pressed_color", UI_INK)
	var normal := StyleBoxFlat.new()
	normal.bg_color = UI_PAPER
	normal.border_color = color
	normal.border_width_bottom = 2
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	var selected := normal.duplicate() as StyleBoxFlat
	selected.bg_color = Color("#e8ede7")
	selected.border_width_bottom = 4
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", selected)
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_stylebox_override("hover_pressed", selected)

func _on_line_tab_pressed(line_id: int) -> void:
	var close_details := active_line.id == line_id and _line_popup.visible
	_select_line(line_id)
	if close_details:
		_close_sheets()
	elif not _line_popup.visible:
		_toggle_sheet(_line_popup)

func _select_line(line_id: int) -> void:
	if line_id < 0 or line_id >= lines.size():
		return
	_cancel_gesture()
	_line_color_picker.get_popup().hide()
	active_line = lines[line_id]
	selected_station_id = -1
	_refresh_line_selector()
	_update_configuration_ui()

func _toggle_ui() -> void:
	_wake_interface()
	_cancel_gesture()
	_close_sheets()
	_quit_dialog.hide()
	_delete_dialog.hide()
	_layout_dialog.hide()
	_cancel_layout_operation()
	_clear_hover()
	_ui_hidden = not _ui_hidden
	_ui_root.visible = not _ui_hidden
	_resize_interface()
	_restore_ui_button.visible = _ui_hidden
	_update_connection_guidance()
	_update_interaction_overlays()
	world_view.queue_redraw()

func _begin_world_interaction(world_position: Vector2) -> void:
	if _ui_hidden or _followed_train != null:
		var train := _train_near(world_position)
		if train != null:
			_follow_train(train)
		return
	if _any_sheet_open():
		_close_sheets()
		return
	_update_hover(world_position)
	var station_interaction := false
	if world_view.hovered_station_id >= 0:
		var hovered_station := graph.stations[world_view.hovered_station_id]
		station_interaction = hovered_station.position.distance_to(world_position) <= maxf(world_view.station_radius(hovered_station) + 3.0, 12.0 / camera.zoom.x)
		station_interaction = station_interaction or _near_handle(world_position, world_view.station_handle_position(hovered_station, Vector2.RIGHT))
		station_interaction = station_interaction or _near_handle(world_position, world_view.station_handle_position(hovered_station, Vector2(1.0, -1.0)))
	if not station_interaction:
		var train := _train_near(world_position)
		if train != null:
			_follow_train(train)
			return
	if world_view.hovered_station_id >= 0:
		var station := graph.stations[world_view.hovered_station_id]
		selected_station_id = station.id
		if _near_handle(world_position, world_view.station_handle_position(station, Vector2(1.0, -1.0))):
			_request_delete(station.id, -1)
			return
		for direction: Vector2 in [Vector2.RIGHT]:
			if _near_handle(world_position, world_view.station_handle_position(station, direction)):
				_connect_drag_source_id = station.id
				_drawn_points = PackedVector2Array([station.position])
				_route_pins = _drawn_points.duplicate()
				_route_history.clear()
				_route_diagonal_first = true
				_route_click_mode = false
				_route_press_position = world_position
				_route_pointer = world_position
				world_view.set_stroke_preview(_drawn_points, active_line.color)
				world_view.route_active = true
				world_view.route_source_id = station.id
				return
		if station.position.distance_to(world_position) <= maxf(world_view.station_radius(station) + 3.0, 12.0 / camera.zoom.x):
			_dragging_station_id = station.id
			_drag_start_position = station.position
			_drag_start_paths.clear()
			for track: Track in graph.tracks:
				if track.a == station.id or track.b == station.id:
					_drag_start_paths[track.id] = TrackGeometry.anchors(graph, track)
		return
	if world_view.hovered_track_id >= 0:
		if _near_handle(world_position, world_view.rail_delete_position()):
			_request_delete(-1, world_view.hovered_track_id)
		elif world_view.hovered_bend_index >= 0 or _near_handle(world_position, world_view.rail_move_position()):
			_editing_track_id = world_view.hovered_track_id
			_editing_bend_index = world_view.hovered_bend_index
			_editing_segment_index = world_view.rail_segment_index
			_edit_original = TrackGeometry.anchors(graph, graph.tracks[_editing_track_id])
			_edit_pointer_offset = Vector2.ZERO if _editing_bend_index >= 0 else world_position - world_view.rail_anchor
			world_view.route_active = true
			_update_track_edit(_edit_original[_editing_bend_index] if _editing_bend_index >= 0 else world_view.rail_anchor)
		else:
			_insert_station(world_view.hovered_track_id, world_view.rail_anchor)
		return
	_place_station(world_position)

func _end_world_interaction(world_position: Vector2) -> void:
	if _editing_track_id >= 0:
		_update_track_edit(world_position - _edit_pointer_offset)
		var error := _track_edit_error()
		if error.is_empty():
			if _drawn_points != _edit_original:
				graph.tracks[_editing_track_id].waypoints = _drawn_points.duplicate()
				_refresh_network()
		else:
			_set_status(error)
		_cancel_gesture()
		return
	if _dragging_station_id >= 0:
		_move_station_to(_dragging_station_id, world_position)
		_dragging_station_id = -1
		_drag_start_paths.clear()
	if _connect_drag_source_id >= 0:
		var source_id := _connect_drag_source_id
		var destination := _station_near(world_position, 24.0 / camera.zoom.x)
		if destination != null and destination.id != source_id:
			_extend_stroke(destination.position)
			var error := _connection_error(source_id, destination.id, _drawn_points)
			if not error.is_empty():
				_set_status(error)
				_route_click_mode = true
				return
			_connect_stations(source_id, destination.id, _drawn_points)
			_cancel_gesture()
		else:
			if _route_click_mode or world_position.distance_to(_route_press_position) > 6.0 / camera.zoom.x:
				_pin_route_bend(world_position)
			_route_click_mode = true

func _cancel_gesture() -> void:
	if _dragging_station_id >= 0:
		graph.stations[_dragging_station_id].position = _drag_start_position
		for track_id: int in _drag_start_paths:
			graph.tracks[track_id].waypoints = _drag_start_paths[track_id]
		_refresh_network()
	_connect_drag_source_id = -1
	_editing_track_id = -1
	_editing_bend_index = -1
	_editing_segment_index = -1
	_edit_original.clear()
	_route_pins.clear()
	_route_history.clear()
	_route_click_mode = false
	_route_ignore_release = false
	_dragging_station_id = -1
	_drag_start_paths.clear()
	_drawn_points.clear()
	if world_view != null:
		world_view.station_preview_visible = false
		world_view.route_active = false
		world_view.route_source_id = -1
		world_view.route_target_id = -1
		world_view.route_pins.clear()
		world_view.reshape_anchors.clear()
		world_view.valid_connection_targets.clear()
		world_view.set_stroke_preview(_drawn_points, Color.WHITE)

func _extend_stroke(world_position: Vector2) -> void:
	if _route_pins.is_empty():
		return
	_route_pointer = world_position
	var destination := _station_near(world_position, 24.0 / camera.zoom.x)
	var target := destination.position if destination != null else world_position
	_drawn_points = _route_pins.duplicate()
	var tail := TrackGeometry.elastic_path(_route_pins[_route_pins.size() - 1], target, _route_diagonal_first)
	_drawn_points.append_array(tail.slice(1))
	var destination_id := destination.id if destination != null else -1
	var error := _connection_error(_connect_drag_source_id, destination_id, _drawn_points, destination == null)
	world_view.route_target_id = destination_id
	world_view.route_pins = _route_pins.slice(1)
	world_view.valid_connection_targets.clear()
	for station: Station in graph.stations:
		if station.id == _connect_drag_source_id:
			continue
		var candidate := _route_pins.duplicate()
		candidate.append_array(TrackGeometry.elastic_path(_route_pins[_route_pins.size() - 1], station.position, _route_diagonal_first).slice(1))
		if _connection_error(_connect_drag_source_id, station.id, candidate).is_empty():
			world_view.valid_connection_targets.append(station.id)
	world_view.set_stroke_preview(_drawn_points, active_line.color, error)

func _flip_route_posture() -> void:
	_route_diagonal_first = not _route_diagonal_first
	_extend_stroke(_route_pointer)

func _pin_route_bend(position: Vector2) -> void:
	_extend_stroke(position)
	if _drawn_points.is_empty():
		return
	if _drawn_points[_drawn_points.size() - 1] != _route_pins[_route_pins.size() - 1]:
		_route_history.append(_route_pins.duplicate())
		_route_pins = _drawn_points.duplicate()
	_extend_stroke(position)

func _connection_error(from_id: int, to_id: int, points: PackedVector2Array, open_end: bool = false) -> String:
	var error := graph.path_error(from_id, to_id, points, open_end)
	if not error.is_empty():
		return error
	if TrackGeometry.length(points) < TrackGeometry.train_length(active_line.wagon_count) + 40.0:
		return "Ce tracé est trop court pour la rame. Allongez-le ou réduisez les wagons."
	var existing := graph.track_between(from_id, to_id) if to_id >= 0 else null
	if existing != null and active_line.tracks.has(existing.id):
		return ""
	if not active_line.can_extend_from(from_id):
		return "Reliez une extrémité de la ligne, ou choisissez une autre ligne."
	if to_id >= 0 and active_line.stations.has(to_id) and not active_line.can_close(from_id, to_id):
		return "Choisissez une nouvelle station pour prolonger la ligne."
	return ""

func _update_track_edit(position: Vector2) -> void:
	var bend := (position / GRID_SIZE).round() * GRID_SIZE
	var before := _editing_bend_index - 1 if _editing_bend_index >= 0 else _editing_segment_index
	var after := _editing_bend_index + 1 if _editing_bend_index >= 0 else _editing_segment_index + 1
	_drawn_points = _edit_original.slice(0, before)
	_drawn_points.append_array(TrackGeometry.elastic_path(_edit_original[before], bend))
	_drawn_points.append_array(TrackGeometry.elastic_path(bend, _edit_original[after], false).slice(1))
	_drawn_points.append_array(_edit_original.slice(after + 1))
	_drawn_points = TrackGeometry.simplify(_drawn_points, _edit_original)
	world_view.hover_pointer = position
	world_view.route_pins = PackedVector2Array([bend])
	world_view.reshape_anchors = PackedVector2Array([_edit_original[before], _edit_original[after]])
	var error := _track_edit_error()
	var hint := "Glissez vers une autre case de la grille." if error.is_empty() and _drawn_points == _edit_original else ""
	world_view.set_stroke_preview(_drawn_points, active_line.color, error, hint)

func _track_edit_error() -> String:
	var track := graph.tracks[_editing_track_id]
	var error := graph.path_error(track.a, track.b, _drawn_points)
	if not error.is_empty():
		return error
	for line: TransitLine in lines:
		if line.tracks.has(track.id) and TrackGeometry.length(_drawn_points) < TrackGeometry.train_length(line.wagon_count) + 40.0:
			return "Cette rame serait trop longue pour un segment. Allongez le tracé."
	return ""

func _place_station(world_position: Vector2) -> void:
	var snapped := _station_placement_position(world_position)
	if _station_near(snapped, 20.0) != null:
		_set_status("Les stations ont besoin d'un peu d'espace.")
		return
	graph.add_station(snapped)
	selected_station_id = graph.stations.size() - 1
	_refresh_network()

func _station_placement_position(world_position: Vector2) -> Vector2:
	return (world_position / GRID_SIZE).round() * GRID_SIZE

func _connect_stations(from_id: int, to_id: int, drawn: PackedVector2Array = PackedVector2Array()) -> void:
	var points := drawn
	if points.is_empty():
		points = PackedVector2Array([graph.stations[from_id].position, graph.stations[to_id].position])
	points = TrackGeometry.simplify(points)
	var error := _connection_error(from_id, to_id, points)
	if not error.is_empty():
		_set_status(error)
		return
	if TrackGeometry.length(points) < TrackGeometry.train_length(active_line.wagon_count) + 40.0:
		_set_status("Ce tracé est trop court pour la rame. Allongez-le ou réduisez les wagons.")
		return
	var existing := graph.track_between(from_id, to_id)
	var redraw := existing != null and active_line.tracks.has(existing.id)
	if not redraw and not active_line.can_extend_from(from_id):
		_set_status("Reliez une extrémité de la ligne, ou choisissez une autre ligne.")
		return
	var connected := redraw
	var prepend := false
	if redraw:
		pass
	elif active_line.can_close(from_id, to_id):
		connected = active_line.append_station(graph, active_line.stations[0])
	elif active_line.stations.is_empty():
		connected = active_line.append_station(graph, from_id)
		if connected:
			connected = active_line.append_station(graph, to_id)
	elif active_line.stations.size() == 1 or from_id == active_line.stations.back():
		connected = active_line.append_station(graph, to_id)
	else:
		prepend = true
		connected = active_line.prepend_station(graph, to_id)
	if not connected:
		_set_status("Cette liaison n'est pas valide pour la ligne sélectionnée.")
		return
	selected_station_id = to_id
	var track := graph.track_between(from_id, to_id)
	if track.a != from_id:
		points.reverse()
	track.waypoints = points
	_refresh_network()

func _move_station_to(station_id: int, world_position: Vector2) -> bool:
	var station := graph.stations[station_id]
	var snapped := (world_position / GRID_SIZE).round() * GRID_SIZE
	var occupied := _station_near(snapped, 20.0)
	if occupied != null and occupied.id != station_id:
		_set_status("Cette case est déjà occupée par une station.")
		return false
	if station.position == snapped:
		return true
	var old_position := station.position
	var previous_paths: Dictionary = {}
	for track: Track in graph.tracks:
		if track.a != station_id and track.b != station_id:
			continue
		previous_paths[track.id] = track.waypoints.duplicate()
		var baseline: PackedVector2Array = _drag_start_paths[track.id] if _drag_start_paths.has(track.id) else TrackGeometry.anchors(graph, track)
		track.waypoints = TrackGeometry.reshape_endpoint(baseline, snapped, track.a == station_id)
	station.position = snapped
	var error := ""
	for track_id: int in previous_paths:
		var track: Track = graph.tracks[track_id]
		error = graph.path_error(track.a, track.b, track.waypoints)
		if error.is_empty():
			for line: TransitLine in lines:
				if line.tracks.has(track.id) and TrackGeometry.length(TrackGeometry.sample(graph, track)) < TrackGeometry.train_length(line.wagon_count) + 40.0:
					error = "La rame serait trop longue pour ce segment."
					break
		if not error.is_empty():
			break
	if not error.is_empty():
		station.position = old_position
		for track_id: int in previous_paths:
			graph.tracks[track_id].waypoints = previous_paths[track_id]
		_set_status("Déplacement refusé : %s", [error], true)
		return false
	_refresh_network()
	return true

func _station_near(position: Vector2, radius: float) -> Station:
	var closest: Station = null
	var distance := INF
	for station: Station in graph.stations:
		var candidate := station.position.distance_to(position)
		if candidate <= maxf(radius, world_view.station_radius(station) + 3.0) and candidate <= distance:
			closest = station
			distance = candidate
	return closest

func _train_near(position: Vector2) -> Metro:
	var closest: Metro = null
	var distance := maxf(7.0, 10.0 / camera.zoom.x)
	for train: Metro in dispatcher.metros:
		var route := TrackGeometry.route_for_direction(dispatcher.routes[train.line_id], train.travel_direction)
		for car in range(train.wagon_count + 1):
			var center := TrackGeometry.car_position(route["points"], route["length"], train.distance, car)
			var candidate := center.distance_to(position)
			if candidate <= distance:
				closest = train
				distance = candidate
	return closest

func _stop_following() -> void:
	if _followed_train != null:
		_followed_train = null
		_update_interaction_overlays()

func _follow_train(train: Metro) -> void:
	_cancel_gesture()
	_clear_hover()
	_followed_train = train
	camera.zoom = Vector2.ONE * FOLLOW_ZOOM
	camera.position = train.position
	_update_interaction_overlays()
	_update_connection_guidance()

func _update_interaction_overlays() -> void:
	var editing_visible := not _ui_hidden and _followed_train == null
	world_view.interaction_overlays_visible = editing_visible
	world_view.selected_station_id = selected_station_id if editing_visible else -1
	if not editing_visible:
		_clear_hover()
	world_view.queue_redraw()

func _near_handle(position: Vector2, handle: Vector2) -> bool:
	return position.distance_to(handle) <= 11.0 / camera.zoom.x

func _clear_hover() -> void:
	world_view.station_preview_visible = false
	world_view.hovered_station_id = -1
	world_view.hovered_track_id = -1
	world_view.hovered_bend_index = -1
	world_view.hover_caption = ""
	world_view.queue_redraw()

func _on_pointer_exited() -> void:
	_pointer_inside = false
	_clear_hover()

func _update_hover(position: Vector2) -> void:
	world_view.station_preview_visible = false
	if _ui_hidden or _followed_train != null or _panning or _space_down or _any_sheet_open() or _quit_dialog.visible or _delete_dialog.visible or _layout_dialog.visible or _connect_drag_source_id >= 0 or _dragging_station_id >= 0 or _editing_track_id >= 0:
		_clear_hover()
		return
	world_view.view_zoom = camera.zoom
	world_view.hover_pointer = position
	world_view.hovered_bend_index = -1
	var station := _station_near(position, maxf(40.0, 55.0 / camera.zoom.x))
	if world_view.hovered_station_id >= 0 and world_view.hovered_station_id < graph.stations.size():
		var previous := graph.stations[world_view.hovered_station_id]
		for direction: Vector2 in [Vector2.RIGHT, Vector2(1.0, -1.0)]:
			if _near_handle(position, world_view.station_handle_position(previous, direction)):
				station = previous
				break
	if station != null and station.position.distance_to(position) <= maxf(world_view.station_radius(station) + 3.0, 12.0 / camera.zoom.x):
		_set_station_hover(station, position)
		return
	if station != null and (world_view.hovered_station_id == station.id or world_view.connection_hint_station_id == station.id):
		for direction: Vector2 in [Vector2.RIGHT, Vector2(1.0, -1.0)]:
			var handle := world_view.station_handle_position(station, direction)
			var approach := Geometry2D.get_closest_point_to_segment(position, station.position, handle)
			if _near_handle(position, approach):
				_set_station_hover(station, position)
				return
	for track: Track in graph.tracks:
		var anchors := TrackGeometry.anchors(graph, track)
		for index in range(1, anchors.size() - 1):
			if _near_handle(position, anchors[index]):
				world_view.hovered_station_id = -1
				world_view.hovered_track_id = track.id
				world_view.hovered_bend_index = index
				world_view.set_rail_anchor(anchors, position)
				world_view.rail_anchor = anchors[index]
				world_view.hover_caption = "Remodeler le tracé"
				return
	if world_view.hovered_track_id >= 0:
		if _near_handle(position, world_view.rail_delete_position()):
			world_view.hover_caption = "Supprimer le rail"
			return
		if _near_handle(position, world_view.rail_move_position()):
			world_view.hover_caption = "Remodeler le tracé"
			return
		if _near_handle(position, world_view.rail_anchor):
			world_view.hover_caption = "Insérer une station"
			return
		# Keep the popup anchored while crossing the gaps between its handles.
		var spine := Geometry2D.get_closest_point_to_segment(position, world_view.rail_delete_position(), world_view.rail_move_position())
		if _near_handle(position, spine):
			world_view.hover_caption = ""
			return
	if station != null:
		var handles_visible := world_view.hovered_station_id == station.id or world_view.connection_hint_station_id == station.id
		var rail_distance := INF
		if not handles_visible:
			for track: Track in graph.tracks:
				var anchor := TrackGeometry.insertion_point(TrackGeometry.anchors(graph, track), position)
				rail_distance = minf(rail_distance, anchor.distance_squared_to(position))
		for direction: Vector2 in [Vector2.RIGHT, Vector2(1.0, -1.0)]:
			var handle := world_view.station_handle_position(station, direction)
			if _near_handle(position, handle) and (handles_visible or handle.distance_squared_to(position) < rail_distance):
				_set_station_hover(station, position)
				return
	world_view.hovered_station_id = -1
	world_view.hovered_track_id = -1
	world_view.hover_caption = ""
	var best_distance := 20.0 / camera.zoom.x + TrackGeometry.LANE_OFFSET
	for track: Track in graph.tracks:
		var points := TrackGeometry.sample(graph, track)
		var closest := TrackGeometry.closest_point(points, position)
		var distance := closest.distance_to(position)
		if distance < best_distance:
			best_distance = distance
			world_view.hovered_track_id = track.id
			world_view.set_rail_anchor(TrackGeometry.anchors(graph, track), position)
			world_view.hover_caption = "Insérer une station"
	if world_view.hovered_track_id < 0 and station != null:
		_set_station_hover(station, position)
		return
	var snapped := _station_placement_position(position)
	if world_view.hovered_track_id < 0 and _station_near(snapped, 20.0) == null and _train_near(position) == null:
		world_view.station_preview_position = snapped
		world_view.station_preview_visible = true

func _set_station_hover(station: Station, position: Vector2) -> void:
	world_view.hovered_station_id = station.id
	world_view.hovered_track_id = -1
	world_view.hover_caption = "Relier une station" if _near_handle(position, world_view.station_handle_position(station, Vector2.RIGHT)) else ""
	if _near_handle(position, world_view.station_handle_position(station, Vector2(1.0, -1.0))):
		world_view.hover_caption = "Supprimer la station"
	elif station.position.distance_to(position) <= maxf(world_view.station_radius(station) + 3.0, 12.0 / camera.zoom.x):
		world_view.hover_caption = "Glissez le centre pour déplacer"

func _insert_station(track_id: int, position: Vector2) -> void:
	var error := graph.insert_station(track_id, position, lines)
	if not error.is_empty():
		_set_status("Insertion refusée : %s", [error], true)
		return
	selected_station_id = graph.stations.size() - 1
	_clear_hover()
	_refresh_network()

func _request_delete(station_id: int, track_id: int) -> void:
	if station_id < 0 and track_id < 0:
		_set_status("Sélectionnez une station ou survolez un rail à supprimer.")
		return
	_cancel_gesture()
	_delete_line_id = -1
	_delete_station_id = station_id
	_delete_track_id = track_id if station_id < 0 else -1
	_delete_dialog.dialog_text = "Supprimer cette station ? Les voies voisines seront reconnectées en conservant leur tracé." if station_id >= 0 else "Supprimer ce rail ? Les lignes touchées seront séparées."
	_delete_dialog.popup_centered(Vector2i(mini(430, int(get_viewport_rect().size.x) - 32), 180))

func _request_delete_line() -> void:
	_cancel_gesture()
	_line_color_picker.get_popup().hide()
	_delete_station_id = -1
	_delete_track_id = -1
	_delete_line_id = active_line.id
	_delete_dialog.dialog_text = "Supprimer cette ligne, ses trains, ses voies et stations exclusives ? Les voies et stations partagées seront conservées."
	_delete_dialog.popup_centered(Vector2i(mini(430, int(get_viewport_rect().size.x) - 32), 180))

func _apply_delete() -> void:
	if _delete_line_id >= 0:
		var next_line := _delete_line_id
		graph.remove_line(_delete_line_id, lines)
		if lines.is_empty():
			lines.append(TransitLineScript.new(0, LINE_COLORS[0]))
		active_line = lines[mini(next_line, lines.size() - 1)]
		_previous_arrival_count = dispatcher.arrival_count
		dispatcher.last_arrival_line_id = -1
		_close_sheets()
	elif _delete_station_id >= 0:
		graph.remove_station(_delete_station_id, lines)
	elif _delete_track_id >= 0:
		graph.remove_track(_delete_track_id, lines)
	else:
		return
	_delete_station_id = -1
	_delete_track_id = -1
	_delete_line_id = -1
	selected_station_id = -1
	_clear_hover()
	dispatcher.lines.assign(lines)
	_refresh_network()
	_refresh_line_selector()
	_update_configuration_ui()

func _refresh_network() -> void:
	_stop_following()
	dispatcher.rebuild_routes()
	world_view.set_network(graph, lines, dispatcher.routes)
	for line: TransitLine in lines:
		if not line.tracks.is_empty() and not line.is_loop() and not dispatcher.routes[line.id]["terminal_ready"]:
			_set_status("Pas assez de place aux terminus. Allongez la ligne ou réduisez les wagons.")
			break
	_update_connection_guidance()
	_update_configuration_ui()

func _on_dispatch_changed(value: float) -> void:
	if _updating_line_controls or active_line == null:
		return
	active_line.dispatch_rate = value
	_update_configuration_ui()

func _on_max_trains_changed(value: float) -> void:
	if _updating_line_controls or active_line == null:
		return
	active_line.max_trains = clampi(int(value), 1, maxi(1, dispatcher.route_capacity(active_line)))
	_update_configuration_ui()

func _on_dwell_changed(value: float) -> void:
	if _updating_line_controls or active_line == null:
		return
	active_line.dwell_time = value
	_update_configuration_ui()

func _on_velocity_changed(value: float) -> void:
	if _updating_line_controls or active_line == null:
		return
	active_line.cruise_velocity = value
	_update_configuration_ui()

func _on_wagon_changed(value: float) -> void:
	if _updating_line_controls or active_line == null:
		return
	var count := int(value)
	for track_id: int in active_line.tracks:
		if TrackGeometry.length(TrackGeometry.sample(graph, graph.tracks[track_id])) < TrackGeometry.train_length(count) + 40.0:
			_set_status("Cette rame serait trop longue pour un segment. Allongez le tracé.")
			_update_configuration_ui()
			return
	var previous := active_line.wagon_count
	active_line.wagon_count = count
	if not active_line.tracks.is_empty() and not active_line.is_loop() and not TrackGeometry.circuit(graph, active_line, lines)["terminal_ready"]:
		active_line.wagon_count = previous
		_set_status("Pas assez de place aux terminus. Allongez la ligne ou réduisez les wagons.")
		_update_configuration_ui()
		return
	_refresh_network()
	_update_configuration_ui()

func _update_configuration_ui() -> void:
	if active_line == null:
		return
	_updating_line_controls = true
	_line_color_picker.color = active_line.color
	_line_label.text = active_line.display_name if not active_line.display_name.is_empty() else tr("LIGNE %02d") % (active_line.id + 1)
	_line_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_line_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_dispatch_slider.value = active_line.dispatch_rate
	_max_trains_slider.max_value = maxi(1, dispatcher.route_capacity(active_line))
	_max_trains_slider.editable = dispatcher.route_capacity(active_line) > 0
	_max_trains_slider.value = maxi(1, dispatcher.train_limit(active_line))
	_dwell_slider.value = active_line.dwell_time
	_dwell_slider.tooltip_text = tr("Arrêt minimum ; embarquement : jusqu'à 2 s de plus.")
	_velocity_slider.value = active_line.cruise_velocity
	_wagon_slider.value = active_line.wagon_count
	_dispatch_value.text = "%.0f s" % active_line.dispatch_rate
	_max_trains_value.text = str(dispatcher.train_limit(active_line))
	if dispatcher.routes.has(active_line.id):
		_dispatch_slider.tooltip_text = tr("Intervalle visé : %.1f s.") % dispatcher.departure_headway(active_line)
		_max_trains_value.tooltip_text = tr("Conseillé : %d rames. Capacité : %d.") % [dispatcher.recommended_fleet(active_line), dispatcher.route_capacity(active_line)]
		_max_trains_slider.tooltip_text = _max_trains_value.tooltip_text
	_dwell_value.text = "%.0f s" % active_line.dwell_time
	_velocity_value.text = "%.0f px/s" % active_line.cruise_velocity
	_wagon_value.text = str(active_line.wagon_count)
	_line_label.add_theme_color_override("font_color", UI_INK)
	_updating_line_controls = false
	_resize_interface()

func _on_line_color_changed(color: Color) -> void:
	if _updating_line_controls or active_line == null:
		return
	active_line.color = Color(color, 1.0)
	_update_configuration_ui()
	for child: Node in _line_selector.get_children():
		if child.is_queued_for_deletion():
			continue
		var button := child as Button
		if button.button_pressed:
			_style_line_tab(button, active_line.color)
	world_view.refresh_illumination()
	world_view.queue_redraw()
	if _connect_drag_source_id >= 0:
		_extend_stroke(_route_pointer)
	elif not _drawn_points.is_empty():
		world_view.set_stroke_preview(_drawn_points, active_line.color)

func _update_status() -> void:
	_pause_button.text = tr("Continuer" if paused else "Pause")

func _set_status(source: String, arguments: Array = [], arguments_are_keys: bool = false) -> void:
	_wake_interface()
	_status_source = source
	_status_arguments = arguments
	_status_arguments_are_keys = arguments_are_keys
	_status_seconds = 8.0
	_refresh_status_translation()

func _update_connection_guidance() -> void:
	if not graph.tracks.is_empty():
		_first_connection_completed = true
	world_view.connection_hint_station_id = -1
	if not _first_connection_completed and not graph.stations.is_empty() and not _ui_hidden and _followed_train == null and not _any_sheet_open() and not _panning and not _space_down and _connect_drag_source_id < 0 and _dragging_station_id < 0 and _editing_track_id < 0 and not _quit_dialog.visible and not _delete_dialog.visible and not _layout_dialog.visible:
		world_view.connection_hint_station_id = graph.stations[0].id

func _refresh_status_translation() -> void:
	if _panel_status == null or _status_source.is_empty():
		return
	var arguments := _status_arguments.duplicate()
	if _status_arguments_are_keys:
		for index in range(arguments.size()):
			arguments[index] = tr(str(arguments[index]))
	_panel_status.text = tr(_status_source) if arguments.is_empty() else tr(_status_source) % arguments
	_resize_notification()
	for feedback: Label in _sheet_feedback:
		if feedback.get_parent().is_visible_in_tree() and _status_seconds > 0.0:
			feedback.text = _panel_status.text
			feedback.show()
		else:
			feedback.text = ""
			feedback.hide()

func _load_language() -> void:
	var settings := ConfigFile.new()
	var error := settings.load(settings_path)
	var locale := "en"
	if error == OK:
		var saved: String = str(settings.get_value("interface", "language", "en"))
		if saved in ["en", "fr"]:
			locale = saved
		else:
			push_error("Unsupported saved language: " + saved)
	elif error != ERR_FILE_NOT_FOUND:
		push_error("Cannot load language settings: " + error_string(error))
	TranslationServer.set_locale(locale)

func _on_language_selected(index: int) -> void:
	var locale := "fr" if index == 1 else "en"
	TranslationServer.set_locale(locale)
	_refresh_line_selector()
	_update_configuration_ui()
	_update_status()
	_refresh_status_translation()
	for item_index in range(_saved_layouts.item_count):
		var bundled: Variant = _saved_layouts.get_item_metadata(item_index)
		if bundled is String and LayoutStoreScript.BUNDLED_LAYOUTS.has(bundled):
			_saved_layouts.set_item_text(item_index, tr(LayoutStoreScript.BUNDLED_LAYOUTS[bundled]))
	var settings := ConfigFile.new()
	var error := settings.load(settings_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_error("Cannot load settings for saving: " + error_string(error))
		return
	settings.set_value("interface", "language", locale)
	error = settings.save(settings_path)
	if error != OK:
		push_error("Cannot save language settings: " + error_string(error))

func _toggle_pause() -> void:
	paused = not paused

func _toggle_settings() -> void:
	_toggle_sheet(_settings_popup)

func _open_layouts(saving: bool) -> void:
	_close_sheets()
	_toggle_sheet(_layout_popup)
	_layout_saving = saving
	_layout_heading.text = "Nom du réseau" if saving else "Réseaux enregistrés"
	_layout_name.visible = saving
	_layout_name.text = ""
	_layout_action.text = "Enregistrer" if saving else "Charger"
	_saved_layouts.clear()
	var saved_names := layout_store.names()
	for saved_name: String in saved_names:
		_saved_layouts.add_item(saved_name)
		_saved_layouts.set_item_metadata(_saved_layouts.item_count - 1, false)
	if not saving:
		for path: String in LayoutStoreScript.BUNDLED_LAYOUTS:
			_saved_layouts.add_item(tr(LayoutStoreScript.BUNDLED_LAYOUTS[path]))
			_saved_layouts.set_item_metadata(_saved_layouts.item_count - 1, path)
	_saved_layouts.disabled = _saved_layouts.item_count == 0
	if _saved_layouts.item_count > 0:
		_saved_layouts.select(0)
	_layout_action.disabled = not saving and _saved_layouts.item_count == 0
	if not layout_store.error_message.is_empty():
		_set_status("Impossible de lire les sauvegardes. Vérifiez le stockage disponible.")
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		_set_status("Le stockage du navigateur est indisponible. Les sauvegardes ne survivront pas à la fermeture.")
	_resize_interface()
	if saving:
		_layout_name.grab_focus()
	elif _saved_layouts.item_count > 0:
		_saved_layouts.grab_focus()

func _request_layout_action() -> void:
	var layout_name := _layout_name.text.strip_edges() if _layout_saving else (_saved_layouts.get_item_text(_saved_layouts.selected) if _saved_layouts.selected >= 0 else "")
	if not layout_store.valid_name(layout_name):
		_set_status("Saisissez un nom de réseau (1 à 64 caractères).")
		return
	_pending_layout_name = layout_name
	var bundled: Variant = _saved_layouts.get_item_metadata(_saved_layouts.selected) if not _layout_saving else false
	_pending_layout_bundled = bundled if bundled is String else ""
	if _layout_saving and not layout_store.exists(layout_name):
		_save_layout(layout_name)
		_cancel_layout_operation()
		return
	_pending_layout_operation = "save" if _layout_saving else "load"
	_layout_dialog.dialog_text = "Remplacer le réseau enregistré sous ce nom ?" if _layout_saving else "Charger ce réseau ? La carte actuelle sera remplacée. Les modifications non enregistrées seront perdues."
	_layout_dialog.ok_button_text = "Remplacer" if _layout_saving else "Charger"
	_popup_layout_confirmation()

func _request_clear_map() -> void:
	_cancel_gesture()
	_pending_layout_operation = "clear"
	_pending_layout_name = ""
	_pending_layout_bundled = ""
	_layout_dialog.dialog_text = "Vider la carte ? Les modifications non enregistrées seront perdues. Les réseaux enregistrés seront conservés."
	_layout_dialog.ok_button_text = "Vider"
	_popup_layout_confirmation()

func _popup_layout_confirmation() -> void:
	_wake_interface()
	_layout_dialog.popup_centered(Vector2i(mini(430, int(get_viewport_rect().size.x) - 32), 200))

func _cancel_layout_operation() -> void:
	_pending_layout_operation = ""
	_pending_layout_name = ""
	_pending_layout_bundled = ""
	_pending_import = {}

func _confirm_layout_operation() -> void:
	match _pending_layout_operation:
		"save": _save_layout(_pending_layout_name)
		"load":
			var restored := layout_store.load_bundled_layout(_pending_layout_bundled) if not _pending_layout_bundled.is_empty() else layout_store.load_layout(_pending_layout_name)
			if restored.is_empty():
				_set_status("Impossible de charger ce réseau. Le fichier est absent, invalide ou incompatible.")
			else:
				_replace_layout(restored, true)
		"clear":
			var empty_lines: Array[TransitLine] = [TransitLineScript.new(0, LINE_COLORS[0])]
			_replace_layout({"graph": TransitGraphScript.new(), "lines": empty_lines, "active_line": 0, "camera": Vector2.ZERO, "zoom": 1.0})
		"import":
			_replace_layout(_pending_import, true)
			_set_status("Réseau importé. Enregistrez une copie pour le conserver sur cet appareil.")
	_cancel_layout_operation()

func _export_layout() -> void:
	_cancel_gesture()
	_layout_transfer.export_layout(layout_store.capture(graph, lines, active_line.id, camera.position, camera.zoom.x))

func _on_transfer_failed(message: String) -> void:
	if message.contains("safety limit") or message.contains("storage limit") or message.contains("16 MiB limit"):
		_set_status("Réseau refusé : limites de sécurité dépassées (16 Mio, 256 stations, 512 voies, 16 lignes, 64 trains). Simplifiez le réseau ; voir README pour les limites de géométrie.")
	else:
		_set_status("Impossible de transférer ce réseau. Vérifiez le fichier JSON et son emplacement (16 Mio maximum).")

func _import_layout() -> void:
	_cancel_gesture()
	_cancel_layout_operation()
	_layout_transfer.import_layout()

func _request_imported_layout(restored: Dictionary) -> void:
	_cancel_layout_operation()
	_pending_import = restored
	_pending_layout_operation = "import"
	_layout_dialog.dialog_text = "Importer ce réseau ? La carte actuelle sera remplacée. Les modifications non enregistrées seront perdues. Les sauvegardes existantes seront conservées."
	_layout_dialog.ok_button_text = "Importer"
	_popup_layout_confirmation()

func _save_layout(layout_name: String) -> void:
	_cancel_gesture()
	var snapshot := layout_store.capture(graph, lines, active_line.id, camera.position, camera.zoom.x)
	if not layout_store.save_layout(layout_name, snapshot):
		_set_status("Impossible d'enregistrer ce réseau. Vérifiez le stockage disponible.")
		return
	_close_sheets()
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		_set_status("Le stockage du navigateur est indisponible. Les sauvegardes ne survivront pas à la fermeture.")

func _replace_layout(restored: Dictionary, fit_view: bool = false) -> void:
	_cancel_gesture()
	_stop_following()
	_close_sheets()
	_delete_dialog.hide()
	_delete_station_id = -1
	_delete_track_id = -1
	_delete_line_id = -1
	selected_station_id = -1
	_clear_hover()
	graph = restored["graph"]
	lines.assign(restored["lines"])
	active_line = lines[restored["active_line"]]
	dispatcher = DispatcherScript.new(graph)
	dispatcher.lines.assign(lines)
	_previous_arrival_count = 0
	_first_connection_completed = not graph.tracks.is_empty()
	camera.position = restored["camera"]
	camera.zoom = Vector2.ONE * restored["zoom"]
	_minimum_camera_zoom = minf(0.08, camera.zoom.x)
	_status_source = ""
	_status_seconds = 0.0
	_panel_status.text = ""
	_refresh_network()
	_refresh_line_selector()
	if fit_view:
		_fit_layout_to_window()
	camera.reset_smoothing()
	world_view.set_dynamic_state(dispatcher.metros, camera.position, camera.zoom, time_of_day, dispatcher.visits)

func _fit_layout_to_window() -> void:
	if graph.stations.is_empty():
		camera.position = Vector2.ZERO
		camera.zoom = Vector2.ONE
		_minimum_camera_zoom = 0.08
		return
	var bounds := Rect2(graph.stations[0].position, Vector2.ZERO)
	for station: Station in graph.stations:
		bounds = bounds.expand(station.position)
	for track: Track in graph.tracks:
		for point: Vector2 in TrackGeometry.anchors(graph, track):
			bounds = bounds.expand(point)
	for route: Dictionary in dispatcher.routes.values():
		for point: Vector2 in route["points"]:
			bounds = bounds.expand(point)
	bounds = bounds.grow(24.0)
	var viewport_size := get_viewport_rect().size
	var usable := Rect2(Vector2(32, 80), (viewport_size - Vector2(64, 192)).max(Vector2.ONE))
	camera.zoom = Vector2.ONE * minf(6.0, minf(usable.size.x / bounds.size.x, usable.size.y / bounds.size.y))
	camera.position = bounds.get_center() - (usable.get_center() - viewport_size * 0.5) / camera.zoom
	_minimum_camera_zoom = minf(0.08, camera.zoom.x)

func _fit_window() -> void:
	_wake_interface()
	_cancel_gesture()
	_stop_following()
	_close_sheets()
	_clear_hover()
	_fit_layout_to_window()
	camera.reset_smoothing()
	world_view.set_dynamic_state(dispatcher.metros, camera.position, camera.zoom, time_of_day, dispatcher.visits)

func _zoom_camera(factor: float) -> void:
	_wake_interface()
	camera.zoom = (camera.zoom * factor).clamp(Vector2.ONE * _minimum_camera_zoom, Vector2.ONE * 6.0)

func _zoom_camera_at(factor: float, screen_position: Vector2) -> void:
	var world_position := _screen_to_world_position(screen_position)
	_zoom_camera(factor)
	var zoomed_world_position := _screen_to_world_position(screen_position)
	camera.position += world_position - zoomed_world_position

func _toggle_fullscreen() -> void:
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_set_fullscreen(not is_fullscreen)

func _set_fullscreen(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	if _fullscreen_button != null:
		_fullscreen_button.set_pressed_no_signal(enabled)

func _set_master_volume(value: float) -> void:
	AudioServer.set_bus_volume_linear(0, value)

func _confirm_quit() -> void:
	_quit_dialog.popup_centered()

func _quit_game() -> void:
	get_tree().quit()

func _night_strength(phase: float) -> float:
	return clampf((cos(phase * TAU) + 0.3) / 1.3, 0.0, 1.0)
