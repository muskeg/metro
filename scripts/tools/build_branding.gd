extends SceneTree

const DIRECTORY := "res://assets/branding/"
const PAPER := Color("#f7f0e4")

func _initialize() -> void:
	var mark := FileAccess.get_file_as_string(DIRECTORY + "metro-mark.svg")
	var wordmark := FileAccess.get_file_as_string(DIRECTORY + "metro-wordmark.svg")
	if mark.is_empty() or wordmark.is_empty():
		push_error("Cannot read Metro vector artwork.")
		quit(1)
		return
	var icon_svg := mark.replace("<g fill=", '<rect width="512" height="512" rx="100" fill="#f7f0e4"/><g fill=')
	var logo_svg := '<svg xmlns="http://www.w3.org/2000/svg" width="800" height="700" viewBox="0 0 800 700"><title>Metro logo</title>'
	logo_svg += '<g transform="translate(144 0)">' + _body(mark) + '</g>'
	logo_svg += '<g transform="translate(0 510)">' + _body(wordmark) + '</g></svg>'
	if not _write(DIRECTORY + "metro-icon.svg", icon_svg) or not _write(DIRECTORY + "metro-logo.svg", logo_svg):
		quit(1)
		return
	var icon := Image.new()
	var error := icon.load_svg_from_string(icon_svg, 2.0)
	if error != OK:
		push_error("Cannot rasterize Metro icon: " + error_string(error))
		quit(1)
		return
	error = icon.save_png(DIRECTORY + "metro-icon.png")
	if error != OK:
		push_error("Cannot save Metro icon: " + error_string(error))
		quit(1)
		return
	var logo := Image.new()
	error = logo.load_svg_from_string(logo_svg, 0.6)
	if error != OK:
		push_error("Cannot rasterize Metro splash: " + error_string(error))
		quit(1)
		return
	var splash := Image.create(600, 520, false, Image.FORMAT_RGBA8)
	splash.fill(PAPER)
	splash.blend_rect(logo, Rect2i(Vector2i.ZERO, logo.get_size()), Vector2i(60, 40))
	error = splash.save_png(DIRECTORY + "metro-splash.png")
	if error != OK:
		push_error("Cannot save Metro splash: " + error_string(error))
		quit(1)
		return
	print("Metro branding generated: vector logo/icon, 1024px icon and 600x520 splash.")
	quit()

func _body(svg: String) -> String:
	return svg.substr(svg.find(">") + 1).trim_suffix("</svg>\n").trim_suffix("</svg>")

func _write(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write Metro artwork: " + error_string(FileAccess.get_open_error()))
		return false
	file.store_string(content)
	if file.get_error() != OK:
		push_error("Cannot finish writing Metro artwork: " + error_string(file.get_error()))
		return false
	return true
