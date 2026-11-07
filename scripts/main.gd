extends Node2D

const GRID_SIZE := 48.0
const DAY_LENGTH_SECONDS := 300.0
const FOLLOW_ZOOM := 5.0
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

@onready var camera: Camera2D = $Camera2D
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var audio: Node = $Audio

var graph: TransitGraph
var dispatcher: TransitDispatcher
var world_view: WorldView
var lines: Array[TransitLine] = []
var active_line: TransitLine
var selected_station_id: int = -1
var tool_mode: String = "station"
var paused: bool = false
var time_of_day: float = 0.5
var _previous_arrival_count: int = 0
var _panning: bool = false
var _left_pan_active: bool = false
var _space_down: bool = false
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
var _edit_original := PackedVector2Array()
var _edit_pointer_offset := Vector2.ZERO
var _dragging_station_id: int = -1
var _drag_start_position := Vector2.ZERO
var _drag_start_paths: Dictionary = {}
var _panel_status: Label
var _line_label: Label
var _line_color_picker: ColorPickerButton
var _main_panel: PanelContainer
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
var _station_button: Button
var _pause_button: Button
var _settings_button: Button
var _fullscreen_button: CheckButton
var _line_selector: HBoxContainer
var _line_button_group: ButtonGroup
var _settings_popup: PanelContainer
var _master_volume: HSlider
var _quit_dialog: ConfirmationDialog
var _delete_dialog: ConfirmationDialog
var _delete_station_id := -1
var _delete_track_id := -1
var _updating_line_controls: bool = false
var _language_selector: OptionButton
var _status_source := ""
var _status_arguments: Array = []
var _status_arguments_are_keys := false
const SETTINGS_PATH := "user://settings.cfg"
var settings_path := SETTINGS_PATH

func _ready() -> void:
	_load_language()
	DisplayServer.window_set_min_size(Vector2i(760, 520))
	graph = TransitGraphScript.new()
	dispatcher = DispatcherScript.new(graph)
	world_view = WorldViewScript.new()
	add_child(world_view)
	world_view.set_network(graph, lines)
	_create_interface()
	_create_line()
	_refresh_network()
	_update_configuration_ui()
	_update_tool_buttons()

func _process(delta: float) -> void:
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
	world_view.selected_station_id = selected_station_id
	world_view.set_dynamic_state(dispatcher.metros, camera.get_screen_center_position(), camera.zoom, time_of_day)
	if _connect_drag_source_id < 0 and _dragging_station_id < 0 and _editing_track_id < 0:
		if get_viewport().gui_get_hovered_control() == null and not _panning:
			_update_hover(get_global_mouse_position())
		else:
			_clear_hover()
	_update_status()

func _input(event: InputEvent) -> void:
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_SPACE:
			_space_down = key_event.pressed
		elif key_event.pressed and key_event.keycode == KEY_ESCAPE:
			if _settings_popup.visible:
				_settings_popup.hide()
			else:
				selected_station_id = -1
				_set_status("Sélection effacée.")
		elif key_event.pressed and key_event.keycode == KEY_P:
			_toggle_pause()
		elif key_event.pressed and key_event.keycode == KEY_F11:
			_toggle_fullscreen()
		elif key_event.pressed and key_event.keycode == KEY_DELETE:
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
			camera.zoom = (camera.zoom * magnify_event.factor).clamp(Vector2(0.45, 0.45), Vector2(6.0, 6.0))
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
	var compact_theme := Theme.new()
	compact_theme.default_font_size = 12
	ui_root.theme = compact_theme
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)

	var panel := PanelContainer.new()
	_main_panel = panel
	panel.position = Vector2(16.0, 16.0)
	panel.custom_minimum_size = Vector2(276.0, 0.0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	ui_root.add_child(panel)
	get_viewport().size_changed.connect(_resize_interface)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 5)
	scroll.add_child(stack)

	var header := HBoxContainer.new()
	header.add_child(_label("METRO", 16, Color("#f0eee7")))
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	_settings_button = _button("Menu", _toggle_settings)
	_settings_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(_settings_button)
	stack.add_child(header)

	var tools := HBoxContainer.new()
	_station_button = _button("Station", _select_station_tool)
	_station_button.toggle_mode = true
	tools.add_child(_station_button)
	_pause_button = _button("Pause", _toggle_pause)
	tools.add_child(_pause_button)
	stack.add_child(tools)

	var line_header := HBoxContainer.new()
	line_header.add_child(_label("LIGNES", 11, Color("#b8c0bd")))
	var line_spacer := Control.new()
	line_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_header.add_child(line_spacer)
	line_header.add_child(_button("+ Nouvelle", _create_line))
	stack.add_child(line_header)
	var line_scroll := ScrollContainer.new()
	line_scroll.custom_minimum_size.y = 34.0
	line_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	line_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(line_scroll)
	_line_selector = HBoxContainer.new()
	_line_selector.add_theme_constant_override("separation", 6)
	line_scroll.add_child(_line_selector)
	_line_button_group = ButtonGroup.new()

	_line_label = _label("LIGNE 01", 12, Color("#d8e2de"))
	var line_details := HBoxContainer.new()
	_line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_details.add_child(_line_label)
	_line_color_picker = ColorPickerButton.new()
	_line_color_picker.custom_minimum_size = Vector2(36.0, 28.0)
	_line_color_picker.edit_alpha = false
	_line_color_picker.tooltip_text = "Couleur de la ligne"
	_line_color_picker.add_theme_stylebox_override("normal", _button_style(Color("#2a353c")))
	_line_color_picker.color_changed.connect(_on_line_color_changed)
	var picker := _line_color_picker.get_picker()
	picker.theme = compact_theme
	_line_color_picker.get_popup().add_theme_stylebox_override("panel", _panel_style())
	picker.edit_alpha = false
	for color: Color in LINE_COLORS:
		picker.add_preset(color)
	line_details.add_child(_line_color_picker)
	stack.add_child(line_details)
	_dispatch_slider = _add_slider(stack, "Intervalle des trains", 8.0, 60.0, 18.0, _on_dispatch_changed, "_dispatch_value")
	_max_trains_slider = _add_slider(stack, "Trains maximum", 1.0, 16.0, 4.0, _on_max_trains_changed, "_max_trains_value")
	_dwell_slider = _add_slider(stack, "Arrêt en station", 0.0, 12.0, 3.0, _on_dwell_changed, "_dwell_value")
	_velocity_slider = _add_slider(stack, "Vitesse de croisière", 40.0, 220.0, 100.0, _on_velocity_changed, "_velocity_value")
	_wagon_slider = _add_slider(stack, "Wagons par train", 1.0, 6.0, 2.0, _on_wagon_changed, "_wagon_value")
	_panel_status = _label("Cliquez sur la carte pour placer une station.", 11, Color("#b8c0bd"))
	_panel_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_panel_status)
	stack.add_child(_button("Aide", _toggle_help))
	_help_label = _label("Survolez une station : centre pour déplacer, + pour relier.\nGlissez vers une station ou cliquez pour fixer des coudes. Reliez les extrémités pour former une boucle.\nTab : inverser le coude. Retour arrière : retirer le dernier.\nSurvolez un rail : losange pour remodeler, + pour insérer, × pour supprimer. Échap / clic droit : annuler.\nCliquez sur un train pour le suivre ; Échap ou déplacer la vue pour arrêter.", 10, Color("#a0acae"))
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_help_label)
	_help_label.hide()
	var navigation_help := _label("Molette : zoom · Clic milieu/Espace + glisser : déplacer\nTrackpad : glisser à deux doigts : déplacer · pincer : zoomer", 10, Color("#a0acae"))
	_navigation_help = navigation_help
	navigation_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(navigation_help)
	navigation_help.hide()

	_settings_popup = PanelContainer.new()
	_settings_popup.position = Vector2(304.0, 16.0)
	_settings_popup.custom_minimum_size = Vector2(240.0, 0.0)
	_settings_popup.add_theme_stylebox_override("panel", _panel_style())
	ui_root.add_child(_settings_popup)
	var settings_margin := MarginContainer.new()
	settings_margin.add_theme_constant_override("margin_left", 16)
	settings_margin.add_theme_constant_override("margin_right", 16)
	settings_margin.add_theme_constant_override("margin_top", 14)
	settings_margin.add_theme_constant_override("margin_bottom", 14)
	_settings_popup.add_child(settings_margin)
	var settings_scroll := ScrollContainer.new()
	settings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_margin.add_child(settings_scroll)
	var settings_stack := VBoxContainer.new()
	settings_stack.add_theme_constant_override("separation", 6)
	settings_scroll.add_child(settings_stack)
	settings_stack.add_child(_label("RÉGLAGES", 14, Color("#f0eee7")))
	settings_stack.add_child(_label("Langue", 11, Color("#d8e2de")))
	_language_selector = OptionButton.new()
	_language_selector.add_item("English")
	_language_selector.add_item("Français")
	_language_selector.select(1 if TranslationServer.get_locale().begins_with("fr") else 0)
	_language_selector.item_selected.connect(_on_language_selected)
	settings_stack.add_child(_language_selector)
	_fullscreen_button = CheckButton.new()
	_fullscreen_button.text = "Plein écran"
	_fullscreen_button.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen_button.toggled.connect(_set_fullscreen)
	settings_stack.add_child(_fullscreen_button)
	settings_stack.add_child(_label("Volume général", 11, Color("#d8e2de")))
	_master_volume = HSlider.new()
	_master_volume.min_value = 0.0
	_master_volume.max_value = 1.0
	_master_volume.step = 0.01
	_master_volume.value = AudioServer.get_bus_volume_linear(0)
	_master_volume.value_changed.connect(_set_master_volume)
	settings_stack.add_child(_master_volume)
	settings_stack.add_child(_label("Musique", 11, Color("#d8e2de")))
	var music_volume := HSlider.new()
	music_volume.min_value = 0.0
	music_volume.max_value = 1.0
	music_volume.step = 0.01
	music_volume.value = 0.4
	music_volume.value_changed.connect(func(value: float) -> void: audio.call("set_music_volume", value))
	settings_stack.add_child(music_volume)
	settings_stack.add_child(_label("Sons des trains", 11, Color("#d8e2de")))
	var effects_volume := HSlider.new()
	effects_volume.min_value = 0.0
	effects_volume.max_value = 1.0
	effects_volume.step = 0.01
	effects_volume.value = 0.5
	effects_volume.value_changed.connect(func(value: float) -> void: audio.call("set_effects_volume", value))
	settings_stack.add_child(effects_volume)
	settings_stack.add_child(_button("Quitter le jeu", _confirm_quit))
	_settings_popup.hide()

	_quit_dialog = ConfirmationDialog.new()
	_quit_dialog.title = "Quitter Metro"
	_quit_dialog.dialog_text = "Voulez-vous vraiment quitter le jeu ?"
	_quit_dialog.ok_button_text = "Quitter"
	_quit_dialog.cancel_button_text = "Annuler"
	_quit_dialog.confirmed.connect(_quit_game)
	ui_root.add_child(_quit_dialog)
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Supprimer du réseau"
	_delete_dialog.dialog_text = "Supprimer cet élément ? Les lignes touchées seront séparées, sans reconnecter les rails."
	_delete_dialog.ok_button_text = "Supprimer"
	_delete_dialog.cancel_button_text = "Annuler"
	_delete_dialog.confirmed.connect(_apply_delete)
	ui_root.add_child(_delete_dialog)
	_resize_interface()

func _resize_interface() -> void:
	var viewport_size := get_viewport_rect().size
	var available_width := maxf(0.0, viewport_size.x - 32.0)
	var available_height := maxf(0.0, viewport_size.y - 32.0)
	var panel_width := minf(276.0, available_width)
	_main_panel.position = Vector2(16.0, 16.0)
	_main_panel.custom_minimum_size.x = panel_width
	_main_panel.size = Vector2(panel_width, minf(460.0, available_height))
	var popup_width := minf(240.0, available_width)
	var popup_height := minf(420.0, available_height)
	_settings_popup.custom_minimum_size.x = popup_width
	_settings_popup.size = Vector2(popup_width, popup_height)
	var popup_x := _main_panel.position.x + _main_panel.size.x + 12.0
	if popup_x + popup_width > viewport_size.x - 16.0:
		popup_x = maxf(16.0, viewport_size.x - popup_width - 16.0)
	_settings_popup.position = Vector2(popup_x, 16.0)

func _toggle_help() -> void:
	_help_label.visible = not _help_label.visible
	_navigation_help.visible = _help_label.visible

func _add_slider(parent: VBoxContainer, title: String, minimum: float, maximum: float, initial: float, callback: Callable, value_field: String) -> HSlider:
	var heading := HBoxContainer.new()
	heading.add_child(_label(title, 11, Color("#d8e2de")))
	var value_label := _label("", 11, Color("#9fc9c5"))
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(value_label)
	parent.add_child(heading)
	set(value_field, value_label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 1.0
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	parent.add_child(slider)
	return slider

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 28.0
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("#e8eeea"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#34434a")))
	button.add_theme_stylebox_override("hover", _button_style(Color("#465b60")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#57797a")))
	button.pressed.connect(callback)
	return button

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#20292f")
	style.border_color = Color(0.62, 0.74, 0.72, 0.14)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.02, 0.05, 0.07, 0.12)
	style.shadow_size = 5
	return style

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	return style

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
	_set_status("Nouvelle ligne. Glissez entre deux stations pour la créer.")

func _refresh_line_selector() -> void:
	for child in _line_selector.get_children():
		child.queue_free()
	for line: TransitLine in lines:
		var button := Button.new()
		button.text = tr("Ligne %02d") % (line.id + 1)
		button.custom_minimum_size = Vector2(76.0, 28.0)
		button.toggle_mode = true
		button.button_group = _line_button_group
		button.button_pressed = line == active_line
		button.add_theme_font_size_override("font_size", 11)
		button.add_theme_color_override("font_color", line.color.lightened(0.45))
		button.add_theme_stylebox_override("normal", _button_style(Color(0.20, 0.27, 0.30, 0.88)))
		button.add_theme_stylebox_override("pressed", _button_style(Color(line.color, 0.3)))
		button.pressed.connect(_select_line.bind(line.id))
		_line_selector.add_child(button)

func _select_line(line_id: int) -> void:
	if line_id < 0 or line_id >= lines.size():
		return
	_cancel_gesture()
	_line_color_picker.get_popup().hide()
	active_line = lines[line_id]
	selected_station_id = -1
	_refresh_line_selector()
	_update_configuration_ui()
	_set_status("Ligne %02d sélectionnée.", [line_id + 1])

func _select_station_tool() -> void:
	_cancel_gesture()
	tool_mode = "inspect" if tool_mode == "station" else "station"
	selected_station_id = -1
	_update_tool_buttons()
	_set_status("Cliquez sur un espace libre pour placer une station." if tool_mode == "station" else "Survolez une station ou un rail pour le modifier.")

func _update_tool_buttons() -> void:
	_station_button.button_pressed = tool_mode == "station"

func _begin_world_interaction(world_position: Vector2) -> void:
	_update_hover(world_position)
	var station_interaction := false
	if world_view.hovered_station_id >= 0:
		var hovered_station := graph.stations[world_view.hovered_station_id]
		station_interaction = hovered_station.position.distance_to(world_position) <= maxf(15.0, 12.0 / camera.zoom.x)
		station_interaction = station_interaction or _near_handle(world_position, world_view.station_handle_position(hovered_station, Vector2.RIGHT))
		station_interaction = station_interaction or _near_handle(world_position, world_view.station_handle_position(hovered_station, Vector2(1.0, -1.0)))
	if not station_interaction:
		var train := _train_near(world_position)
		if train != null:
			_followed_train = train
			camera.zoom = Vector2.ONE * FOLLOW_ZOOM
			camera.position = train.position
			_set_status("Suivi du train. Échap ou déplacer la vue pour arrêter.")
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
		if station.position.distance_to(world_position) <= maxf(15.0, 12.0 / camera.zoom.x):
			_dragging_station_id = station.id
			_drag_start_position = station.position
			_drag_start_paths.clear()
			for track: Track in graph.tracks:
				if track.a == station.id or track.b == station.id:
					_drag_start_paths[track.id] = TrackGeometry.anchors(graph, track)
			_set_status("Déplacez la station, puis relâchez.")
		return
	if world_view.hovered_track_id >= 0:
		if _near_handle(world_position, world_view.rail_delete_position()):
			_request_delete(-1, world_view.hovered_track_id)
		elif world_view.hovered_bend_index >= 0 or _near_handle(world_position, world_view.rail_move_position()):
			_editing_track_id = world_view.hovered_track_id
			_editing_bend_index = world_view.hovered_bend_index
			_edit_original = TrackGeometry.anchors(graph, graph.tracks[_editing_track_id])
			_edit_pointer_offset = Vector2.ZERO if _editing_bend_index >= 0 else world_position - world_view.rail_anchor
			world_view.route_active = true
			_update_track_edit(_edit_original[_editing_bend_index] if _editing_bend_index >= 0 else world_view.rail_anchor)
		elif tool_mode == "station" or _near_handle(world_position, world_view.rail_anchor):
			_insert_station(world_view.hovered_track_id, world_view.rail_anchor)
		return
	if tool_mode == "station":
		_place_station(world_position)
	else:
		selected_station_id = -1

func _end_world_interaction(world_position: Vector2) -> void:
	if _editing_track_id >= 0:
		_update_track_edit(world_position - _edit_pointer_offset)
		var error := _track_edit_error()
		if error.is_empty():
			graph.tracks[_editing_track_id].waypoints = _drawn_points.duplicate()
			_refresh_network()
			_set_status("Tracé enregistré. Les trains repartent sur les deux voies.")
		else:
			_set_status(error)
		_cancel_gesture()
		return
	if _dragging_station_id >= 0:
		var moved := _move_station_to(_dragging_station_id, world_position)
		_dragging_station_id = -1
		_drag_start_paths.clear()
		if moved:
			_set_status("Station déplacée. Les rames repartent sur le tracé mis à jour.")
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
	_edit_original.clear()
	_route_pins.clear()
	_route_history.clear()
	_route_click_mode = false
	_route_ignore_release = false
	_dragging_station_id = -1
	_drag_start_paths.clear()
	_drawn_points.clear()
	if world_view != null:
		world_view.route_active = false
		world_view.route_source_id = -1
		world_view.route_target_id = -1
		world_view.route_pins.clear()
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
	var before := _editing_bend_index - 1 if _editing_bend_index >= 0 else 0
	var after := _editing_bend_index + 1 if _editing_bend_index >= 0 else _edit_original.size() - 1
	_drawn_points = _edit_original.slice(0, before)
	_drawn_points.append_array(TrackGeometry.elastic_path(_edit_original[before], bend))
	_drawn_points.append_array(TrackGeometry.elastic_path(bend, _edit_original[after], false).slice(1))
	_drawn_points.append_array(_edit_original.slice(after + 1))
	_drawn_points = TrackGeometry.simplify(_drawn_points)
	world_view.route_pins = PackedVector2Array([bend])
	world_view.set_stroke_preview(_drawn_points, active_line.color, _track_edit_error())

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
	var snapped := (world_position / GRID_SIZE).round() * GRID_SIZE
	if _station_near(snapped, 20.0) != null:
		_set_status("Les stations ont besoin d'un peu d'espace.")
		return
	graph.add_station(snapped)
	selected_station_id = graph.stations.size() - 1
	_refresh_network()
	_set_status("Station ajoutée. Tirez un point d'ancrage pour dessiner un rail.")

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
	_set_status("Tracé enregistré. Les trains repartent sur les deux voies." if not prepend else "Ligne prolongée au départ. Les rames sont redispatchées.")

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
	var distance := radius
	for station: Station in graph.stations:
		var candidate := station.position.distance_to(position)
		if candidate <= distance:
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
		_set_status("Suivi du train terminé.")

func _near_handle(position: Vector2, handle: Vector2) -> bool:
	return position.distance_to(handle) <= 11.0 / camera.zoom.x

func _clear_hover() -> void:
	world_view.hovered_station_id = -1
	world_view.hovered_track_id = -1
	world_view.hovered_bend_index = -1
	world_view.hover_caption = ""

func _update_hover(position: Vector2) -> void:
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
	if station != null:
		world_view.hovered_station_id = station.id
		world_view.hovered_track_id = -1
		world_view.hover_caption = "Relier une station" if _near_handle(position, world_view.station_handle_position(station, Vector2.RIGHT)) else ""
		if _near_handle(position, world_view.station_handle_position(station, Vector2(1.0, -1.0))):
			world_view.hover_caption = "Supprimer la station"
		elif station.position.distance_to(position) <= maxf(15.0, 12.0 / camera.zoom.x):
			world_view.hover_caption = "Glissez le centre pour déplacer"
		return
	world_view.hovered_station_id = -1
	for track: Track in graph.tracks:
		var anchors := TrackGeometry.anchors(graph, track)
		for index in range(1, anchors.size() - 1):
			if _near_handle(position, anchors[index]):
				world_view.hovered_track_id = track.id
				world_view.hovered_bend_index = index
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
			world_view.rail_anchor = TrackGeometry.insertion_point(TrackGeometry.anchors(graph, track), position)
			world_view.hover_caption = "Insérer une station"

func _insert_station(track_id: int, position: Vector2) -> void:
	var error := graph.insert_station(track_id, position, lines)
	if not error.is_empty():
		_set_status("Insertion refusée : %s", [error], true)
		return
	selected_station_id = graph.stations.size() - 1
	_clear_hover()
	_refresh_network()
	_set_status("Station insérée sur toutes les lignes partageant ce rail.")

func _request_delete(station_id: int, track_id: int) -> void:
	if station_id < 0 and track_id < 0:
		_set_status("Sélectionnez une station ou survolez un rail à supprimer.")
		return
	_cancel_gesture()
	_delete_station_id = station_id
	_delete_track_id = track_id if station_id < 0 else -1
	_delete_dialog.popup_centered(Vector2i(430, 180))

func _apply_delete() -> void:
	if _delete_station_id >= 0:
		graph.remove_station(_delete_station_id, lines)
	elif _delete_track_id >= 0:
		graph.remove_track(_delete_track_id, lines)
	else:
		return
	_delete_station_id = -1
	_delete_track_id = -1
	selected_station_id = -1
	_clear_hover()
	dispatcher.lines.assign(lines)
	_refresh_network()
	_refresh_line_selector()
	_update_configuration_ui()
	_set_status("Élément supprimé. Les fragments restent accessibles dans les onglets de lignes.")

func _refresh_network() -> void:
	_stop_following()
	dispatcher.rebuild_routes()
	world_view.set_network(graph, lines, dispatcher.routes)

func _on_dispatch_changed(value: float) -> void:
	if _updating_line_controls or active_line == null:
		return
	active_line.dispatch_rate = value
	_update_configuration_ui()

func _on_max_trains_changed(value: float) -> void:
	if _updating_line_controls or active_line == null:
		return
	active_line.max_trains = int(value)
	var count := 0
	for train: Metro in dispatcher.metros:
		if train.line_id == active_line.id:
			count += 1
	if count > active_line.max_trains:
		_refresh_network()
		_set_status("Limite réduite : les trains repartent.")
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
	active_line.wagon_count = count
	_refresh_network()
	_update_configuration_ui()
	_set_status("Composition modifiée : les rames repartent avec %d wagons.", [count])

func _update_configuration_ui() -> void:
	if active_line == null:
		return
	_updating_line_controls = true
	_line_color_picker.color = active_line.color
	_line_label.text = tr("LIGNE %02d") % (active_line.id + 1)
	_dispatch_slider.value = active_line.dispatch_rate
	_max_trains_slider.value = active_line.max_trains
	_dwell_slider.value = active_line.dwell_time
	_velocity_slider.value = active_line.cruise_velocity
	_wagon_slider.value = active_line.wagon_count
	_dispatch_value.text = "%.0f s" % active_line.dispatch_rate
	_max_trains_value.text = str(active_line.max_trains)
	_dwell_value.text = "%.0f s" % active_line.dwell_time
	_velocity_value.text = "%.0f px/s" % active_line.cruise_velocity
	_wagon_value.text = str(active_line.wagon_count)
	_line_label.add_theme_color_override("font_color", active_line.color.lightened(0.2))
	_updating_line_controls = false

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
			button.add_theme_color_override("font_color", active_line.color.lightened(0.45))
			button.add_theme_stylebox_override("pressed", _button_style(Color(active_line.color, 0.3)))
	world_view.queue_redraw()
	if _connect_drag_source_id >= 0:
		_extend_stroke(_route_pointer)
	elif not _drawn_points.is_empty():
		world_view.set_stroke_preview(_drawn_points, active_line.color)
	_set_status("Couleur de la ligne modifiée.")

func _update_status() -> void:
	_pause_button.text = tr("Continuer" if paused else "Pause")

func _set_status(source: String, arguments: Array = [], arguments_are_keys: bool = false) -> void:
	_status_source = source
	_status_arguments = arguments
	_status_arguments_are_keys = arguments_are_keys
	_refresh_status_translation()

func _refresh_status_translation() -> void:
	if _panel_status == null or _status_source.is_empty():
		return
	var arguments := _status_arguments.duplicate()
	if _status_arguments_are_keys:
		for index in range(arguments.size()):
			arguments[index] = tr(str(arguments[index]))
	_panel_status.text = tr(_status_source) if arguments.is_empty() else tr(_status_source) % arguments

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
	_settings_popup.visible = not _settings_popup.visible

func _zoom_camera(factor: float) -> void:
	camera.zoom = (camera.zoom * factor).clamp(Vector2(0.45, 0.45), Vector2(6.0, 6.0))

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
