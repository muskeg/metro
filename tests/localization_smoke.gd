extends SceneTree

const TEST_SETTINGS := "user://localization-smoke.cfg"
var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true

func _run() -> void:
	if FileAccess.file_exists(TEST_SETTINGS):
		_check(DirAccess.remove_absolute(TEST_SETTINGS) == OK, "Cannot clean the previous test settings.")
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node = scene.instantiate()
	main.set("settings_path", TEST_SETTINGS)
	root.add_child(main)
	await process_frame
	_check(TranslationServer.get_locale() == "en", "English must be the default for new players.")
	_check(main.tr("Supprimer la station") == "Delete station", "Context actions must have English translations.")
	_check(main.tr("Quitter le jeu") == "Quit game", "Quit controls must be translated.")
	_check(main.tr("Couleur de la ligne") == "Line color" and main.tr("Aide") == "Help", "Color picker and compact help must be translated.")
	_check(main.tr("Trains maximum") == "Maximum trains" and main.tr("Suivi du train terminé.") == "Stopped following train.", "Train limit and follow feedback must be translated.")
	var help_text: String = main.tr(main.get("_help_label").text)
	_check(help_text.begins_with("Hover a station:") and help_text.contains("Tab: flip bend") and help_text.contains("Connect the endpoints to make a loop."), "Elastic drawing and loop help must be translated, including escaped newlines.")
	_check(main.tr("Relier une station") == "Connect stations" and main.tr("Remodeler le tracé") == "Reshape route", "Unified gizmo tooltips must be translated.")
	main.call("_select_line", 0)
	var status: Label = main.get("_panel_status")
	_check(status.text == "Line 01 selected.", "Formatted status messages must be translated before interpolation.")
	var graph: TransitGraph = main.get("graph")
	graph.add_station(Vector2.ZERO)
	graph.add_station(Vector2(384.0, 0.0))
	main.call("_connect_stations", 0, 1)
	main.call("_toggle_pause")
	main.call("_toggle_settings")
	main.call("_set_status", "Déplacement refusé : %s", ["Une ligne ne peut pas se croiser elle-même."], true)
	_check(status.text == "Cannot move station: A line cannot cross itself.", "Nested graph errors must be translated.")
	main.call("_on_language_selected", 1)
	await process_frame
	_check(TranslationServer.get_locale() == "fr", "French must be selectable without restarting.")
	_check(main.get("paused") and main.get("_settings_popup").visible, "Changing language must preserve pause and menu state.")
	_check(graph.tracks.size() == 1, "Changing language must not rebuild or clear the network.")
	_check(status.text == "Déplacement refusé : Une ligne ne peut pas se croiser elle-même.", "Existing errors must update on a language switch.")
	var line_label: Label = main.get("_line_label")
	_check(line_label.text == "LIGNE 01", "The active line name must update to French.")
	_check(main.tr("Couleur de la ligne") == "Couleur de la ligne", "The picker label must switch to French.")
	_check(main.tr("Trains maximum") == "Trains maximum", "The train limit label must switch to French.")
	main.queue_free()
	await process_frame
	var second: Node = scene.instantiate()
	second.set("settings_path", TEST_SETTINGS)
	root.add_child(second)
	await process_frame
	_check(TranslationServer.get_locale() == "fr", "Language choice must persist across game launches.")
	second.call("_on_language_selected", 0)
	await process_frame
	var selector: HBoxContainer = second.get("_line_selector")
	var line_button: Button = selector.get_child(0)
	_check(line_button.text == "Line 01", "Line tabs must update back to English.")
	second.queue_free()
	await process_frame
	_check(DirAccess.remove_absolute(TEST_SETTINGS) == OK, "Cannot clean localization test settings.")
	if _failed:
		quit(1)
	else:
		print("Localization smoke passed: English default, live French/English, errors, formats, persistence and preserved state.")
		quit()
