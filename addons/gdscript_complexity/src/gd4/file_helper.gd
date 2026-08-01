# File operations helper for Godot 4.x
extends Object

func file_exists(file_path: String) -> bool:
	return FileAccess.file_exists(file_path)

func open_read(file_path: String):
	return FileAccess.open(file_path, FileAccess.READ)

func open_append(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return null
	file.seek_end()
	return file

func close_file(file):
	if file != null:
		file = null

func write_line(file, text: String):
	if file != null:
		file.store_string(text + "\n")

func timestamp_utc() -> String:
	return Time.get_datetime_string_from_system(true)

func stringify_json(data: Dictionary) -> String:
	return JSON.stringify(data)

func parse_json_text(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if parsed != null and parsed is Dictionary:
		return parsed
	return {}
