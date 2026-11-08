extends SceneTree

var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true

func _run() -> void:
	var directory := "res://assets/branding/"
	_check(ProjectSettings.get_setting("application/config/icon") == directory + "metro-icon.png", "All platforms must use the Metro application icon.")
	_check(ProjectSettings.get_setting("application/boot_splash/image") == directory + "metro-splash.png", "Boot must use the Metro logo, not the default engine artwork.")
	_check(not ProjectSettings.get_setting("application/boot_splash/fullsize"), "Boot logo must retain its designed size and aspect ratio.")
	for filename: String in ["metro-mark.svg", "metro-wordmark.svg", "metro-logo.svg", "metro-icon.svg"]:
		var svg := FileAccess.get_file_as_string(directory + filename)
		_check(not svg.is_empty() and not svg.contains("<text") and not svg.contains("<image") and not svg.contains("href="), "Vector branding must be self-contained paths, independent of fonts or external images: " + filename)
		var image := Image.new()
		_check(image.load_svg_from_string(svg) == OK and not image.is_empty(), "Vector branding must rasterize: " + filename)
	var icon_texture: Texture2D = load(directory + "metro-icon.png")
	var splash_texture: Texture2D = load(directory + "metro-splash.png")
	var icon := icon_texture.get_image()
	var splash := splash_texture.get_image()
	_check(icon != null and icon.get_size() == Vector2i(1024, 1024), "Native icon must supply a 1024px source.")
	_check(splash != null and splash.get_size() == Vector2i(600, 520), "Native/Web splash must supply the complete stacked logo.")
	if icon != null:
		_check(icon.get_pixel(0, 0).a == 0.0 and icon.get_pixel(512, 40).a == 1.0, "Application icon must have transparent rounded corners and an opaque paper tile.")
		for size: int in [16, 32, 64, 180, 256, 512]:
			var small := icon.duplicate() as Image
			small.resize(size, size, Image.INTERPOLATE_LANCZOS)
			var colors := {"orange": 0, "teal": 0, "purple": 0}
			for y in range(size):
				for x in range(size):
					var pixel := small.get_pixel(x, y)
					if pixel.a < 0.5:
						continue
					if pixel.r > pixel.g * 1.3 and pixel.g > pixel.b * 1.1:
						colors["orange"] += 1
					if pixel.g > pixel.r * 1.3 and pixel.b > pixel.r * 1.3:
						colors["teal"] += 1
					if pixel.b > pixel.r * 1.15 and pixel.b > pixel.g * 1.15:
						colors["purple"] += 1
			_check(colors.values().all(func(count: int) -> bool: return count > 0), "All three Metro route colors must remain visible at " + str(size) + "px.")
	var presets := ConfigFile.new()
	_check(presets.load("res://export_presets.cfg") == OK, "Export branding configuration must load.")
	for section: String in ["preset.0.options", "preset.1.options"]:
		_check(presets.get_value(section, "application/icon", "") == directory + "metro-icon.png", "Desktop exporters must override the engine icon.")
	var head: String = presets.get_value("preset.2.options", "html/head_include", "")
	_check(head.contains("#f7f0e4") and head.contains("#status-splash") and head.contains("theme-color"), "Web loader must share the Metro paper palette and responsive splash.")
	var platforms := ["Windows Desktop", "macOS", "Web", "Linux", "Android", "iOS"]
	for index: int in range(platforms.size()):
		var section := "preset." + str(index)
		_check(presets.get_value(section, "platform", "") == platforms[index], "Every release platform must have its expected export preset.")
		_check(presets.get_value(section, "include_filter", "") == "layouts/*.json", "All release platforms must bundle the included networks.")
		var exclusions: String = presets.get_value(section, "exclude_filter", "")
		for excluded: String in ["tests/*", "dist/*", "docs/*", "scripts/tools/*"]:
			_check(exclusions.split(",").has(excluded), "Every release must exclude development resources: " + excluded)
	_check(presets.get_value("preset.3.options", "binary_format/embed_pck", false), "Linux must embed its game data in the executable.")
	_check(not presets.get_value("preset.4.options", "package/signed", true), "Android release artifacts must be explicitly unsigned.")
	_check(presets.get_value("preset.4.options", "launcher_icons/main_192x192", "") == directory + "metro-icon.png", "Android must use the Metro icon.")
	_check(presets.get_value("preset.5.options", "application/export_project_only", false), "Unsigned iOS releases must export an Xcode project, not an IPA.")
	if _failed:
		quit(1)
	else:
		print("Branding smoke passed: self-contained vectors, boot/app/export wiring, raster dimensions and three-color icons at 16-512px.")
		quit()
