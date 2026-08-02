extends Object

# Append-only complexity history (JSONL). Shared Godot 3/4 — file IO via gd3/gd4 helpers.

const SRC_ROOT := "res://addons/gdscript_complexity/src"
const DEFAULT_HISTORY_PATH := "complexity_history.jsonl"
const TOP_N := 5

var _file_helper = null

func _ensure_file_helper():
	if _file_helper != null:
		return
	var major = Engine.get_version_info().get("major", 0)
	var helper_path = SRC_ROOT + "/gd4/file_helper.gd"
	if major < 4:
		helper_path = SRC_ROOT + "/gd3/file_helper.gd"
	var script = load(helper_path)
	if script != null:
		_file_helper = script.new()

func resolve_path(config, override_path: String = "") -> String:
	if override_path != "":
		return _sanitize_path(override_path)
	if config != null and config.report_config.has("history_path"):
		var hp = config.report_config["history_path"]
		if hp is String and hp != "":
			return _sanitize_path(hp)
	return DEFAULT_HISTORY_PATH

func build_record(project_result, fail_count: int = 0, fail_keys: Array = []) -> Dictionary:
	_ensure_file_helper()
	var top_cog = []
	var sources = []
	if project_result.worst_cog_files.size() > 0:
		sources = project_result.worst_cog_files
	else:
		for fr in project_result.file_results:
			if fr.success:
				sources.append(fr)
		_sort_by_cog(sources)
	var n = min(TOP_N, sources.size())
	var i = 0
	while i < n:
		var fr = sources[i]
		top_cog.append({
			"path": str(fr.file_path),
			"cog": int(fr.cog)
		})
		i += 1
	var ts = ""
	if _file_helper != null and _file_helper.has_method("timestamp_utc"):
		ts = _file_helper.timestamp_utc()
	var keys = []
	for k in fail_keys:
		keys.append(str(k))
	return {
		"timestamp": ts,
		"totals": {
			"cc": int(project_result.total_cc),
			"cog": int(project_result.total_cog),
			"files": int(project_result.successful_files)
		},
		"averages": {
			"cc": float(project_result.average_cc),
			"cog": float(project_result.average_cog)
		},
		"fail_count": int(fail_count),
		"fail_keys": keys,
		"top_cog": top_cog
	}

func append_record(record: Dictionary, history_path: String) -> bool:
	_ensure_file_helper()
	if _file_helper == null:
		print("WARNING: history_store: file helper unavailable")
		return false
	history_path = _sanitize_path(history_path)
	var line = _file_helper.stringify_json(record)
	if line == "":
		return false
	var f = _file_helper.open_append(history_path)
	if f == null:
		print("WARNING: history_store: could not open %s for append" % history_path)
		return false
	_file_helper.write_line(f, line)
	_file_helper.close_file(f)
	return true

func append_from_result(project_result, config, fail_count: int = 0, override_path: String = "", fail_keys: Array = []) -> bool:
	var path = resolve_path(config, override_path)
	var record = build_record(project_result, fail_count, fail_keys)
	return append_record(record, path)

func load_previous(history_path: String) -> Dictionary:
	_ensure_file_helper()
	if _file_helper == null:
		return {}
	history_path = _sanitize_path(history_path)
	if not _file_helper.file_exists(history_path):
		return {}
	var f = _file_helper.open_read(history_path)
	if f == null:
		return {}
	var text = f.get_as_text()
	_file_helper.close_file(f)
	return _last_json_line(text)

func load_baseline(baseline_path: String) -> Dictionary:
	_ensure_file_helper()
	if _file_helper == null:
		return {}
	baseline_path = _sanitize_path(baseline_path)
	if not _file_helper.file_exists(baseline_path):
		return {}
	var f = _file_helper.open_read(baseline_path)
	if f == null:
		return {}
	var text = f.get_as_text()
	_file_helper.close_file(f)
	text = text.strip_edges()
	if text == "":
		return {}
	var normalized = baseline_path.to_lower()
	if normalized.ends_with(".jsonl"):
		return _last_json_line(text)
	var whole = _file_helper.parse_json_text(text)
	if whole.size() > 0:
		return whole
	return _last_json_line(text)

func diff_records(current: Dictionary, previous: Dictionary) -> Dictionary:
	var cur_tot = current.get("totals", {})
	var prev_tot = previous.get("totals", {})
	var cur_avg = current.get("averages", {})
	var prev_avg = previous.get("averages", {})
	var cur_keys = current.get("fail_keys", [])
	var prev_keys = previous.get("fail_keys", [])
	if typeof(cur_keys) != TYPE_ARRAY:
		cur_keys = []
	if typeof(prev_keys) != TYPE_ARRAY:
		prev_keys = []
	var prev_set = {}
	for k in prev_keys:
		prev_set[str(k)] = true
	var new_fail_count = 0
	for k in cur_keys:
		if not prev_set.has(str(k)):
			new_fail_count += 1
	return {
		"delta_total_cc": int(cur_tot.get("cc", 0)) - int(prev_tot.get("cc", 0)),
		"delta_total_cog": int(cur_tot.get("cog", 0)) - int(prev_tot.get("cog", 0)),
		"delta_avg_cc": float(cur_avg.get("cc", 0.0)) - float(prev_avg.get("cc", 0.0)),
		"delta_avg_cog": float(cur_avg.get("cog", 0.0)) - float(prev_avg.get("cog", 0.0)),
		"fail_count": int(current.get("fail_count", 0)),
		"previous_fail_count": int(previous.get("fail_count", 0)),
		"new_fail_count": new_fail_count,
		"avg_cog": float(cur_avg.get("cog", 0.0)),
		"previous_avg_cog": float(prev_avg.get("cog", 0.0))
	}

func print_diff_summary(diff: Dictionary) -> void:
	print("Diff vs baseline/previous:")
	print("  delta total_cc: %s" % _fmt_signed_int(int(diff.get("delta_total_cc", 0))))
	print("  delta total_cog: %s" % _fmt_signed_int(int(diff.get("delta_total_cog", 0))))
	print("  delta avg_cc: %s" % _fmt_signed_float(float(diff.get("delta_avg_cc", 0.0))))
	print("  delta avg_cog: %s" % _fmt_signed_float(float(diff.get("delta_avg_cog", 0.0))))
	print("  fail_count: %d (was %d)" % [
		int(diff.get("fail_count", 0)),
		int(diff.get("previous_fail_count", 0))
	])

func _fmt_signed_int(v: int) -> String:
	if v > 0:
		return "+%d" % v
	return "%d" % v

func _fmt_signed_float(v: float) -> String:
	if v > 0.0:
		return "+%.2f" % v
	return "%.2f" % v

func is_regression(diff: Dictionary) -> bool:
	if float(diff.get("avg_cog", 0.0)) > float(diff.get("previous_avg_cog", 0.0)):
		return true
	if int(diff.get("fail_count", 0)) > int(diff.get("previous_fail_count", 0)):
		return true
	if int(diff.get("new_fail_count", 0)) > 0:
		return true
	return false

func _last_json_line(text: String) -> Dictionary:
	_ensure_file_helper()
	var lines = text.split("\n")
	var i = lines.size() - 1
	while i >= 0:
		var line = str(lines[i]).strip_edges()
		if line != "":
			if _file_helper != null:
				return _file_helper.parse_json_text(line)
			return {}
		i -= 1
	return {}

func _sanitize_path(path: String) -> String:
	if path.length() == 0:
		return DEFAULT_HISTORY_PATH
	var sanitized = path.replace("\\", "/")
	while sanitized.find("../") >= 0:
		sanitized = sanitized.replace("../", "")
	while sanitized.begins_with("/"):
		sanitized = sanitized.substr(1)
	if sanitized.begins_with("res://"):
		sanitized = sanitized.substr(6)
	return sanitized

func _sort_by_cog(arr: Array) -> void:
	var n = arr.size()
	var i = 0
	while i < n:
		var best = i
		var j = i + 1
		while j < n:
			if arr[j].cog > arr[best].cog:
				best = j
			j += 1
		if best != i:
			var tmp = arr[i]
			arr[i] = arr[best]
			arr[best] = tmp
		i += 1
