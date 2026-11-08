extends Node

signal imported(layout: Dictionary)
signal failed(message: String)
signal exported

const StoreScript := preload("res://scripts/layout_store.gd")
const WEB_UPLOAD := """
window.MetroLayoutUpload = {
  input: null,
  generation: 0,
  open(callback, limit) {
    const generation = ++this.generation;
    if (this.input) this.input.remove();
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json,application/json';
    input.style.display = 'none';
    this.input = input;
    document.body.appendChild(input);
    const finish = (status, value) => {
      input.remove();
      if (this.input === input) this.input = null;
      if (this.generation === generation) callback(status, value);
    };
    input.addEventListener('cancel', () => finish('cancel', null), {once: true});
    input.addEventListener('change', async () => {
      const file = input.files[0];
      if (!file) { finish('cancel', null); return; }
      if (file.size > limit) { finish('error', 'Layout exceeds the 16 MiB limit.'); return; }
      try {
        const buffer = await file.arrayBuffer();
        finish('ok', buffer);
      } catch (error) {
        finish('error', 'Cannot read selected file: ' + String(error));
      }
    }, {once: true});
    input.click();
  },
  close() {
    ++this.generation;
    if (this.input) this.input.remove();
    this.input = null;
  }
};
"""

var store := StoreScript.new()
var _dialog: FileDialog
var _export_buffer := PackedByteArray()
var _web_callback: JavaScriptObject

func _ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(WEB_UPLOAD, true)
		_web_callback = JavaScriptBridge.create_callback(_on_web_file)
	else:
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.filters = PackedStringArray(["*.json ; Metro layout"])
		_dialog.use_native_dialog = true
		_dialog.file_selected.connect(_on_file_selected)
		_dialog.canceled.connect(func() -> void: _export_buffer.clear())
		add_child(_dialog)

func export_layout(snapshot: Dictionary) -> void:
	_export_buffer = store.encode_layout(snapshot)
	if _export_buffer.is_empty():
		failed.emit(store.error_message)
		return
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(_export_buffer, "Metro-layout.json", "application/json")
		_export_buffer.clear()
	else:
		_dialog.title = tr("Exporter un réseau")
		_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_dialog.current_file = "Metro-layout.json"
		_dialog.popup_centered_ratio(0.8)

func import_layout() -> void:
	_export_buffer.clear()
	if OS.has_feature("web"):
		var uploader := JavaScriptBridge.get_interface("MetroLayoutUpload")
		uploader.open(_web_callback, StoreScript.MAX_FILE_BYTES)
	else:
		_dialog.title = tr("Importer un réseau")
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.popup_centered_ratio(0.8)

func _on_file_selected(path: String) -> void:
	if not _export_buffer.is_empty():
		if store.write_layout_file(path, _export_buffer):
			exported.emit()
		else:
			failed.emit(store.error_message)
		_export_buffer.clear()
	else:
		var restored := store.read_layout_file(path)
		if restored.is_empty():
			failed.emit(store.error_message)
		else:
			imported.emit(restored)

func _on_web_file(arguments: Array) -> void:
	match arguments[0]:
		"ok":
			_receive_buffer.call_deferred(JavaScriptBridge.js_buffer_to_packed_byte_array(arguments[1]))
		"error":
			push_error(str(arguments[1]))
			failed.emit(str(arguments[1]))

func _receive_buffer(buffer: PackedByteArray) -> void:
	var restored := store.decode_layout(buffer)
	if restored.is_empty():
		failed.emit(store.error_message)
	else:
		imported.emit(restored)

func _exit_tree() -> void:
	if OS.has_feature("web"):
		var uploader := JavaScriptBridge.get_interface("MetroLayoutUpload")
		if uploader != null:
			uploader.close()
