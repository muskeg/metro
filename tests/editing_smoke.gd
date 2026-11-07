extends SceneTree

var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true

func _assert_graph(graph: TransitGraph, lines: Array[TransitLine]) -> void:
	for index in range(graph.stations.size()):
		_check(graph.stations[index].id == index, "Station IDs must match array indices after edits.")
	for index in range(graph.tracks.size()):
		var track := graph.tracks[index]
		_check(track.id == index, "Track IDs must match array indices after edits.")
		_check(graph.track_between(track.a, track.b) == track, "Pair lookup must survive compaction.")
		_check(graph.path_error(track.a, track.b, TrackGeometry.anchors(graph, track)).is_empty(), "Edited paths must remain valid.")
	for index in range(lines.size()):
		var line := lines[index]
		_check(line.id == index, "Fragment line IDs must remain selectable.")
		_check(line.tracks.size() == maxi(0, line.stations.size() - 1), "A line must keep ordered tracks and stations.")
		for segment in range(line.tracks.size()):
			_check(graph.track_between(line.stations[segment], line.stations[segment + 1]).id == line.tracks[segment], "Line tracks must match their endpoints.")

func _run() -> void:
	for target: Vector2 in [Vector2(288.0, 144.0), Vector2(-288.0, 144.0), Vector2(144.0, -288.0), Vector2(-144.0, -288.0), Vector2(288.0, 0.0), Vector2(144.0, 144.0)]:
		for diagonal_first: bool in [true, false]:
			var elastic := TrackGeometry.elastic_path(Vector2.ZERO, target, diagonal_first)
			_check(elastic[0] == Vector2.ZERO and elastic[elastic.size() - 1] == target, "Elastic routes must retain both endpoints in every quadrant.")
			_check(elastic.size() <= 3, "An unpinned elastic route must have at most one bend.")
			for index in range(1, elastic.size()):
				var difference := elastic[index] - elastic[index - 1]
				_check(difference.x == 0.0 or difference.y == 0.0 or absf(difference.x) == absf(difference.y), "Elastic segments must be cardinal or exactly diagonal.")
	_check(TrackGeometry.elastic_path(Vector2.ZERO, Vector2(288.0, 144.0)) == PackedVector2Array([Vector2.ZERO, Vector2(144.0, 144.0), Vector2(288.0, 144.0)]), "Default routing must put the diagonal first.")
	_check(TrackGeometry.elastic_path(Vector2.ZERO, Vector2(288.0, 144.0), false) == PackedVector2Array([Vector2.ZERO, Vector2(144.0, 0.0), Vector2(288.0, 144.0)]), "Alternate routing must put the straight segment first.")
	var graph := TransitGraph.new()
	for x in range(5):
		graph.add_station(Vector2(x * 384.0, 0.0))
	var forward := TransitLine.new(0, Color.CORAL)
	var reverse := TransitLine.new(1, Color.SKY_BLUE)
	var lines: Array[TransitLine] = [forward, reverse]
	for id in range(5):
		forward.append_station(graph, id)
	for id in range(4, -1, -1):
		reverse.append_station(graph, id)
	for track: Track in graph.tracks:
		track.waypoints = TrackGeometry.anchors(graph, track)
	forward.wagon_count = 4
	forward.dispatch_rate = 25.0
	forward.acceleration = 65.0
	forward.braking = 95.0
	forward.terminal_recovery = 5.0
	var shared := graph.track_between(1, 2)
	var error := graph.insert_station(shared.id, Vector2(576.0, 0.0), lines)
	_check(error.is_empty(), "Insertion on a shared straight rail must succeed.")
	_check(forward.stations == [0, 1, 5, 2, 3, 4] and reverse.stations == [4, 3, 2, 5, 1, 0], "Insertion must update every shared line in its own direction.")
	_assert_graph(graph, lines)
	var station_count := graph.stations.size()
	var track_count := graph.tracks.size()
	var before := forward.stations.duplicate()
	error = graph.insert_station(graph.track_between(0, 1).id, Vector2(48.0, 0.0), lines)
	_check(not error.is_empty(), "Insertion too close to a terminal must be refused explicitly.")
	_check(graph.stations.size() == station_count and graph.tracks.size() == track_count and forward.stations == before, "Rejected insertion must be atomic.")
	error = graph.insert_station(graph.track_between(0, 1).id, Vector2(192.0, 48.0), lines)
	_check(not error.is_empty() and graph.stations.size() == station_count, "Off-rail insertion must leave the network unchanged.")
	graph.remove_station(5, lines)
	_check(lines.size() == 4, "Deleting a shared intermediate station must split both lines.")
	_check(forward.stations == [0, 1] and reverse.stations == [4, 3, 2], "Deletion must not invent a reconnection.")
	_check(lines[2].stations == [2, 3, 4] and lines[3].stations == [1, 0], "All surviving station sequences must be preserved.")
	_check(lines[2].wagon_count == 4 and lines[2].dispatch_rate == 25.0 and lines[2].color == forward.color, "Fragments must inherit line settings and color.")
	_check(lines[2].acceleration == 65.0 and lines[2].braking == 95.0 and lines[2].terminal_recovery == 5.0, "Fragments must inherit independent motion and terminal recovery settings.")
	_assert_graph(graph, lines)
	graph.remove_track(graph.track_between(2, 3).id, lines)
	_check(lines.size() == 6, "Deleting another shared rail must preserve every disconnected fragment.")
	_assert_graph(graph, lines)
	graph.remove_station(0, lines)
	_assert_graph(graph, lines)
	var dispatcher := TransitDispatcher.new(graph)
	for line: TransitLine in lines:
		dispatcher.add_line(line)
	dispatcher.rebuild_routes()
	dispatcher.process(1.0, false)
	for line: TransitLine in lines:
		_check(dispatcher.routes.has(line.id), "Deleted and split routes must redispatch safely.")
	while not graph.stations.is_empty():
		graph.remove_station(0, lines)
	_assert_graph(graph, lines)
	_check(graph.tracks.is_empty(), "Deleting every station must remove every incident rail.")
	graph.add_station(Vector2.ZERO)
	graph.add_station(Vector2(384.0, 0.0))
	_check(lines[0].append_station(graph, 0) and lines[0].append_station(graph, 1), "An emptied line must remain reusable.")
	_assert_graph(graph, lines)

	var bend := PackedVector2Array([Vector2.ZERO, Vector2(192.0, 0.0), Vector2(192.0, 192.0), Vector2(576.0, 192.0)])
	var reshaped := TrackGeometry.reshape_endpoint(bend, Vector2(48.0, 48.0), true)
	_check(reshaped == PackedVector2Array([Vector2(48.0, 48.0), Vector2(192.0, 48.0), Vector2(192.0, 192.0), Vector2(576.0, 192.0)]), "Moving an endpoint must reshape its elbow instead of leaving a diagonal kink.")
	var split := TrackGeometry.split_at(bend, Vector2(192.0, 96.0))
	_check(split.size() == 2 and split[0][split[0].size() - 1] == split[1][0], "Splitting a bent rail must retain the shared insertion point.")
	_check(is_equal_approx(TrackGeometry.length(split[0]) + TrackGeometry.length(split[1]), TrackGeometry.length(bend)), "Insertion must preserve the drawn centerline.")

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var main_graph: TransitGraph = main.get("graph")
	main_graph.add_station(Vector2.ZERO)
	main_graph.add_station(Vector2(576.0, 192.0))
	main.call("_connect_stations", 0, 1, bend)
	var view: WorldView = main.get("world_view")
	main.call("_update_hover", Vector2.ZERO)
	_check(view.hovered_station_id == 0, "Station gizmos must appear on hover without selecting a tool.")
	var camera: Camera2D = main.get("camera")
	for zoom: float in [0.45, 1.0, 2.6]:
		camera.zoom = Vector2.ONE * zoom
		view.view_zoom = camera.zoom
		var anchor := view.station_handle_position(main_graph.stations[0], Vector2.RIGHT)
		main.call("_update_hover", anchor)
		main.call("_begin_world_interaction", anchor)
		_check(main.get("_connect_drag_source_id") == 0, "Station anchors must remain clickable at every supported zoom.")
		_check(anchor.distance_to(main_graph.stations[0].position) >= 24.0 and anchor.distance_to(main_graph.stations[0].position) * zoom >= 31.9, "Station anchors must stay outside the station body at every zoom.")
		main.call("_cancel_gesture")
	camera.zoom = Vector2.ONE
	view.view_zoom = Vector2.ONE
	main.call("_begin_world_interaction", Vector2(32.0, 0.0))
	for position: Vector2 in [Vector2(25.0, 20.0), Vector2(48.0, 42.0), Vector2(70.0, 65.0), Vector2(96.0, 96.0)]:
		main.call("_extend_stroke", position)
	_check(main.get("_drawn_points") == PackedVector2Array([Vector2.ZERO, Vector2(96.0, 96.0)]), "Slow off-angle diagonal starts must not lock to a cardinal axis.")
	main.call("_extend_stroke", Vector2(288.0, 144.0))
	var default_route: PackedVector2Array = main.get("_drawn_points")
	main.call("_extend_stroke", Vector2(-96.0, -144.0))
	main.call("_extend_stroke", Vector2(288.0, 144.0))
	_check(main.get("_drawn_points") == default_route, "Unpinned previews must depend only on the endpoint, not pointer history.")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	main.call("_input", tab)
	_check(main.get("_drawn_points") == TrackGeometry.elastic_path(Vector2.ZERO, Vector2(288.0, 144.0), false), "Tab must switch bend posture without moving either endpoint.")
	main.call("_pin_route_bend", Vector2(288.0, 144.0))
	var pinned: PackedVector2Array = main.get("_route_pins")
	main.call("_extend_stroke", Vector2(480.0, 336.0))
	var with_pin: PackedVector2Array = main.get("_drawn_points")
	_check(with_pin.slice(0, pinned.size()) == pinned, "Moving the tail must preserve pinned geometry.")
	var backspace := InputEventKey.new()
	backspace.keycode = KEY_BACKSPACE
	backspace.pressed = true
	main.call("_input", backspace)
	_check(main.get("_route_pins") == PackedVector2Array([Vector2.ZERO]), "Backspace must undo the entire pinned leg, including its generated elbow.")
	main.call("_cancel_gesture")
	main.call("_begin_world_interaction", Vector2.ZERO)
	_check(main.get("_dragging_station_id") == 0 and main.get("_connect_drag_source_id") == -1, "Center dragging must move rather than draw.")
	main.call("_move_station_to", 0, Vector2(48.0, 48.0))
	_check(main_graph.tracks[0].waypoints == reshaped, "Controller movement must use the reshaped endpoint path.")
	main.call("_move_station_to", 0, Vector2(96.0, 96.0))
	main.call("_cancel_gesture")
	main.call("_begin_world_interaction", Vector2(32.0, 0.0))
	_check(main.get("_connect_drag_source_id") == 0, "Contextual drawing must work without a station tool mode.")
	main.call("_cancel_gesture")
	_check(main_graph.stations[0].position == Vector2.ZERO and main_graph.tracks[0].waypoints == bend, "Cancelling movement must restore the complete original geometry.")
	var original := main_graph.tracks[0].waypoints.duplicate()
	_check(not main.call("_move_station_to", 0, Vector2(576.0, 192.0)), "Occupied moves must be refused.")
	_check(main_graph.tracks[0].waypoints == original, "Invalid movement must not partially mutate rails.")
	main.call("_update_hover", Vector2(32.0, 0.0))
	main.call("_begin_world_interaction", Vector2(32.0, 0.0))
	_check(main.get("_connect_drag_source_id") == 0, "Peripheral anchors must draw without a tool mode.")
	main.call("_cancel_gesture")
	main.call("_update_hover", Vector2(192.0, 96.0))
	_check(view.hovered_track_id == 0, "Rail hit testing must follow drawn bends.")
	main.call("_begin_world_interaction", Vector2(192.0, 96.0))
	_check(main_graph.stations.size() == 3 and main_graph.tracks.size() == 2, "Clicking a rail must insert rather than add a disconnected station.")
	main.call("_request_delete", 2, -1)
	_check(main.get("_delete_dialog").visible and main_graph.stations.size() == 3, "Deletion must request confirmation before mutating the graph.")
	main.get("_delete_dialog").hide()
	main.call("_apply_delete")
	_check(main_graph.stations.size() == 2 and main_graph.tracks.is_empty(), "Confirmed station deletion must remove incident rails.")
	_check(main.get("dispatcher").lines.size() == main.get("lines").size(), "Dispatcher must include all newly split lines.")
	await process_frame
	var selector: HBoxContainer = main.get("_line_selector")
	_check(selector.get_child_count() == main.get("lines").size() + 1, "All fragments must have accessible line tabs followed by the add-line button.")
	main.call("_select_line", 1)
	main.call("_connect_stations", 1, 0)
	_check(main_graph.tracks.size() == 1, "Surviving fragments must be extendable after deletion.")
	main.call("_request_delete", -1, 0)
	main.get("_delete_dialog").hide()
	main.call("_apply_delete")
	_check(main_graph.tracks.is_empty(), "Confirmed rail deletion must remove the physical rail.")
	_assert_graph(main_graph, main.get("lines"))
	main_graph.add_station(Vector2(48.0, 0.0))
	main.call("_update_hover", Vector2.ZERO)
	main.call("_begin_world_interaction", Vector2(32.0, 0.0))
	_check(main.get("_connect_drag_source_id") == 0, "A hovered station's handle must not switch to a nearby station while approaching it.")
	main.call("_cancel_gesture")
	main.call("_begin_world_interaction", Vector2(48.0, 0.0))
	_check(main.get("_dragging_station_id") == 2, "Clicking a nearby station's center must still select the nearest station.")
	main.call("_cancel_gesture")
	main.queue_free()
	await process_frame
	await _test_elastic_edits()
	await _test_rail_gizmo_reach()
	await _test_sharp_rail_picking()
	await _test_short_rail_reshaping()
	await _test_local_rail_reshaping()
	await _test_station_connect_priority()
	if _failed:
		quit(1)
	else:
		print("Editing smoke passed: shared insertion, deletion, fragments, remapping, reshaping, hover anchors and cancellation.")
		quit()

func _test_sharp_rail_picking() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var graph: TransitGraph = main.get("graph")
	graph.add_station(Vector2.ZERO)
	graph.add_station(Vector2(576, 0))
	graph.add_station(Vector2(576, 576))
	main.call("_connect_stations", 0, 1)
	main.call("_connect_stations", 1, 2)
	main.get("active_line").wagon_count = 6
	main.call("_refresh_network")
	main.get("camera").zoom = Vector2.ONE * 2.0
	main.call("_clear_hover")
	main.call("_update_hover", Vector2(516, 0))
	_check(main.get("world_view").hovered_track_id == 0, "Sharper rail guides must remain in place and selectable near station bends.")
	main.queue_free()
	await process_frame

func _test_rail_gizmo_reach() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var graph: TransitGraph = main.get("graph")
	var view: WorldView = main.get("world_view")
	var camera: Camera2D = main.get("camera")
	graph.add_station(Vector2.ZERO)
	graph.add_station(Vector2(0.0, 1152.0))
	main.call("_connect_stations", 0, 1)
	for endpoint: Vector2 in [Vector2(0.0, 1152.0), Vector2(1152.0, 0.0), Vector2(1152.0, 1152.0)]:
		graph.stations[1].position = endpoint
		graph.tracks[0].waypoints = PackedVector2Array([Vector2.ZERO, endpoint])
		main.call("_refresh_network")
		for zoom: float in [0.5, 1.0, 2.0, 5.0]:
			camera.zoom = Vector2.ONE * zoom
			for sign_value: float in [-1.0, 1.0]:
				main.call("_clear_hover")
				main.call("_update_hover", endpoint * 0.5)
				var anchor := view.rail_anchor
				var target := view.rail_delete_position() if sign_value < 0.0 else view.rail_move_position()
				for step in range(1, 33):
					main.call("_update_hover", anchor.lerp(target, step / 32.0))
					_check(view.hovered_track_id == 0 and view.rail_anchor == anchor, "Rail gizmos must remain anchored throughout the pointer path at every orientation and zoom.")
				main.call("_begin_world_interaction", target)
				if sign_value < 0.0:
					_check(main.get("_delete_dialog").visible, "The reachable delete gizmo must request confirmation.")
					main.get("_delete_dialog").hide()
				else:
					_check(main.get("_editing_track_id") == 0, "The reachable reshape gizmo must start editing rather than insert a station.")
					main.call("_cancel_gesture")
				_check(graph.stations.size() == 2, "Gizmo clicks must not insert stations.")
			main.call("_update_hover", endpoint * 0.5 + Vector2(5000.0, 5000.0))
			_check(view.hovered_track_id == -1, "Leaving the gizmo area must clear the rail hover.")
	main.queue_free()
	await process_frame

func _test_station_connect_priority() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.set_process_input(false)
	var graph: TransitGraph = main.get("graph")
	var view: WorldView = main.get("world_view")
	var camera: Camera2D = main.get("camera")
	graph.add_station(Vector2.ZERO)
	graph.add_station(Vector2(576, 0))
	graph.add_station(Vector2(-576, 0))
	main.call("_connect_stations", 0, 1)
	for zoom: float in [0.5, 1.0, 2.0, 5.0]:
		camera.zoom = Vector2.ONE * zoom
		view.view_zoom = camera.zoom
		main.call("_clear_hover")
		main.call("_update_hover", Vector2(192, 0))
		_check(view.hovered_track_id == 0, "The existing rail must still expose insertion when approaching it directly.")
		main.call("_update_hover", Vector2.ZERO)
		var anchor := view.station_handle_position(graph.stations[0], Vector2.RIGHT)
		for step in range(1, 33):
			main.call("_update_hover", Vector2.ZERO.lerp(anchor, step / 32.0))
			_check(view.hovered_station_id == 0 and view.hovered_track_id == -1, "Rail insertion must not steal a visible station connect handle or its approach corridor.")
		main.call("_begin_world_interaction", anchor)
		_check(main.get("_connect_drag_source_id") == 0 and graph.stations.size() == 3, "Clicking connect above an existing rightward rail must draw, not insert a station.")
		main.call("_extend_stroke", graph.stations[2].position)
		_check(view.route_target_id == 2 and view.get("_preview_error").is_empty(), "The captured station handle must allow a valid leftward connection.")
		main.call("_cancel_gesture")
	main.call("_update_hover", Vector2.ZERO)
	main.call("_begin_world_interaction", view.station_handle_position(graph.stations[0], Vector2.RIGHT))
	main.call("_end_world_interaction", graph.stations[2].position)
	_check(graph.stations.size() == 3 and graph.tracks.size() == 2, "Completing a left connection must keep the original right rail and avoid accidental station insertion.")
	main.queue_free()
	await process_frame

func _test_short_rail_reshaping() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var graph: TransitGraph = main.get("graph")
	var view: WorldView = main.get("world_view")
	var camera: Camera2D = main.get("camera")
	graph.add_station(Vector2.ZERO)
	graph.add_station(Vector2(96, 0))
	main.get("active_line").wagon_count = 1
	main.call("_connect_stations", 0, 1)
	for endpoint: Vector2 in [Vector2(96, 0), Vector2(0, 96), Vector2(96, 96)]:
		graph.stations[1].position = endpoint
		graph.tracks[0].waypoints = PackedVector2Array([Vector2.ZERO, endpoint])
		main.call("_refresh_network")
		for zoom: float in [0.5, 1.0, 2.0, 5.0]:
			camera.zoom = Vector2.ONE * zoom
			for deleting: bool in [false, true]:
				main.call("_clear_hover")
				main.call("_update_hover", endpoint * 0.5)
				_check(view.hovered_track_id == 0 and view.hovered_station_id == -1, "Station hover halos must not hide short-rail controls.")
				var anchor := view.rail_anchor
				var target := view.rail_delete_position() if deleting else view.rail_move_position()
				_check(absf((target - anchor).normalized().dot(endpoint.normalized())) < 0.01, "Short-rail controls must sit beside the rail, not along it.")
				for step in range(1, 33):
					main.call("_update_hover", anchor.lerp(target, step / 32.0))
					_check(view.hovered_track_id == 0 and view.rail_anchor == anchor, "Short-rail controls must stay reachable beside station hover areas (end %s, zoom %s, delete %s, step %s)." % [endpoint, zoom, deleting, step])
				main.call("_begin_world_interaction", target)
				if deleting:
					_check(main.get("_delete_dialog").visible, "Short-rail deletion must remain reachable.")
					main.get("_delete_dialog").hide()
				else:
					_check(main.get("_editing_track_id") == 0, "Short-rail reshaping must start without moving a station.")
					if main.get("_editing_track_id") < 0:
						main.queue_free()
						await process_frame
						return
					_check(view.get("_preview_hint") == "Glissez vers une autre case de la grille.", "Unchanged grid-snapped edits must explain how to move the bend.")
					main.call("_update_track_edit", anchor + Vector2(1, 1))
					_check(not view.get("_preview_hint").is_empty(), "Sub-grid pointer movement must retain the snapping hint.")
					main.call("_cancel_gesture")
			main.call("_clear_hover")
			main.call("_update_hover", Vector2.ZERO)
			_check(view.hovered_station_id == 0, "Station centers must retain priority over nearby rails.")
	graph.stations[1].position = Vector2(96, 0)
	var detour := PackedVector2Array([Vector2.ZERO, Vector2(48, 48), Vector2(96, 0)])
	graph.tracks[0].waypoints = detour
	main.get("active_line").wagon_count = 6
	main.call("_refresh_network")
	camera.zoom = Vector2.ONE * 2.0
	main.call("_clear_hover")
	main.call("_begin_world_interaction", Vector2(48, 48))
	main.call("_update_track_edit", Vector2(48, 0))
	_check(main.call("_track_edit_error") == "Cette rame serait trop longue pour un segment. Allongez le tracé.", "Shortening below full-train clearance must explain the length restriction.")
	_check(view.get("_preview_error") == main.call("_track_edit_error") and view.route_pins[0] == Vector2(48, 0), "The exact rejection must accompany the dragged bend, not only the distant endpoint.")
	main.call("_end_world_interaction", Vector2(48, 0) + main.get("_edit_pointer_offset"))
	_check(graph.tracks[0].waypoints == detour, "Rejected short edits must preserve the original route.")
	main.queue_free()
	await process_frame

func _test_local_rail_reshaping() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var graph: TransitGraph = main.get("graph")
	var view: WorldView = main.get("world_view")
	graph.add_station(Vector2.ZERO)
	graph.add_station(Vector2(768, 384))
	var original := PackedVector2Array([Vector2.ZERO, Vector2(192, 0), Vector2(192, 192), Vector2(576, 192), Vector2(576, 384), Vector2(768, 384)])
	main.call("_connect_stations", 0, 1, original)
	main.get("camera").zoom = Vector2.ONE * 2.0
	main.call("_clear_hover")
	main.call("_update_hover", Vector2(384, 192))
	main.call("_begin_world_interaction", view.rail_move_position())
	_check(main.get("_editing_segment_index") == 2, "A section handle must select its own pair of anchors, not the entire track.")
	_check(view.get("_preview_hint") == "Glissez vers une autre case de la grille.", "Beginning a section edit must not change the existing route.")
	if DisplayServer.get_name() != "headless":
		main.get("camera").position = Vector2(384, 192)
		main.get("camera").reset_smoothing()
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("/tmp/metro-reshape-anchors.png") == OK, "Could not capture fixed reshape anchors and the grid-snapping hint.")
	main.call("_update_track_edit", Vector2(384, 288))
	var preview: PackedVector2Array = main.get("_drawn_points").duplicate()
	_check(preview.slice(0, 3) == original.slice(0, 3) and preview.slice(preview.size() - 3) == original.slice(3), "Section reshaping must preserve every waypoint outside its neighboring anchors.")
	_check(view.reshape_anchors == PackedVector2Array([original[2], original[3]]), "The neighboring fixed anchors must be exposed to the renderer.")
	_check(graph.tracks[0].waypoints == original, "Local reshaping must remain a preview until release.")
	var offset: Vector2 = main.get("_edit_pointer_offset")
	main.call("_end_world_interaction", Vector2(384, 288) + offset)
	_check(graph.tracks[0].waypoints == preview, "Releasing a local section edit must commit the exact preview.")
	_check(view.reshape_anchors.is_empty(), "Fixed-anchor markers must clear when editing ends.")
	var committed := graph.tracks[0].waypoints.duplicate()
	main.call("_clear_hover")
	main.call("_begin_world_interaction", original[1])
	main.call("_update_track_edit", Vector2(144, 48))
	preview = main.get("_drawn_points").duplicate()
	var fixed := preview.find(original[2])
	_check(fixed >= 0 and preview.slice(fixed) == committed.slice(2), "Moving an existing bend must preserve all subsequent anchors, including a previously reshaped section.")
	_check(TrackGeometry.anchors(graph, graph.tracks[0]) == committed, "Committed editing anchors must survive subsequent geometry reads, even when collinear.")
	main.call("_cancel_gesture")
	_check(graph.tracks[0].waypoints == committed and view.reshape_anchors.is_empty(), "Cancelling a local bend edit must restore no geometry and clear its anchor markers.")
	main.call("_clear_hover")
	main.call("_begin_world_interaction", original[1])
	main.call("_end_world_interaction", Vector2(144, 48))
	_check(graph.tracks[0].waypoints == preview and TrackGeometry.anchors(graph, graph.tracks[0]).has(original[2]), "Fixed anchors that become collinear must remain available after committing the edit.")
	main.queue_free()
	await process_frame

func _test_elastic_edits() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var graph: TransitGraph = main.get("graph")
	var view: WorldView = main.get("world_view")
	graph.add_station(Vector2.ZERO)
	graph.add_station(Vector2(576.0, 192.0))
	main.call("_begin_world_interaction", Vector2(32.0, 0.0))
	main.call("_end_world_interaction", Vector2(32.0, 0.0))
	_check(main.get("_route_click_mode") and graph.tracks.is_empty(), "Clicking the connection handle must latch drawing without creating a rail.")
	main.call("_end_world_interaction", Vector2(192.0, 96.0))
	_check(main.get("_route_pins").size() == 3 and graph.tracks.is_empty(), "Clicking empty space must pin the preview without mutating the graph.")
	main.call("_end_world_interaction", Vector2(576.0, 192.0))
	_check(graph.tracks.size() == 1 and main.get("_connect_drag_source_id") == -1, "Finishing on a station must commit the preview and clear drawing state.")
	var original := graph.tracks[0].waypoints.duplicate()
	main.call("_begin_world_interaction", original[1])
	_check(main.get("_editing_track_id") == 0 and view.hovered_bend_index == 1, "A bend diamond must start rail reshaping, not station insertion.")
	main.call("_update_track_edit", Vector2(192.0, 192.0))
	_check(graph.tracks[0].waypoints == original, "Dragging a bend must not mutate the graph before release.")
	main.call("_cancel_gesture")
	_check(graph.tracks[0].waypoints == original and not view.route_active, "Cancelling reshaping must discard all preview state.")
	main.call("_begin_world_interaction", original[1])
	main.call("_end_world_interaction", Vector2(192.0, 192.0))
	_check(graph.tracks[0].waypoints != original and graph.path_error(0, 1, graph.tracks[0].waypoints).is_empty(), "Releasing a valid bend edit must commit validated geometry.")
	var committed := graph.tracks[0].waypoints.duplicate()
	graph.add_station(Vector2(48.0, 336.0))
	graph.add_station(Vector2(528.0, 336.0))
	main.call("_create_line")
	main.call("_connect_stations", 2, 3)
	main.call("_select_line", 0)
	main.call("_begin_world_interaction", committed[1])
	main.call("_update_track_edit", Vector2(192.0, 480.0))
	_check(not main.call("_track_edit_error").is_empty(), "A crossing bend edit must be marked invalid before release.")
	_check(not view.get("_preview_error").is_empty(), "Invalid route feedback must be sent to the renderer.")
	main.call("_end_world_interaction", Vector2(192.0, 480.0))
	_check(graph.tracks[0].waypoints == committed and main.get("_editing_track_id") == -1, "An invalid bend edit must preserve the original rail atomically.")
	main.call("_update_hover", Vector2.ZERO)
	main.call("_begin_world_interaction", Vector2(32.0, 0.0))
	main.call("_pin_route_bend", Vector2(192.0, 480.0))
	main.call("_end_world_interaction", Vector2(576.0, 192.0))
	_check(main.get("_connect_drag_source_id") == 0 and graph.tracks[0].waypoints == committed, "An invalid destination must keep the preview available for correction without changing the rail.")
	main.call("_cancel_gesture")
	main.queue_free()
	await process_frame
