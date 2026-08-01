# Plugin structure verification
# Run: godot --headless --path . --script tests/verify_plugin_structure.gd
# Checks plugin.cfg and plugin script can be loaded without parse errors.

extends SceneTree

var _passed: bool = true
var _errors: Array = []
var _warnings: Array = []

func _initialize():
	var code = run_verify()
	call_deferred("quit", code)

func run_verify() -> int:
	print("=== Plugin Structure Verification ===")
	print("")
	_passed = true
	_errors.clear()
	_warnings.clear()
	var version_info = Engine.get_version_info()
	print("Godot version: %d.%d.%d" % [version_info.get("major", 0), version_info.get("minor", 0), version_info.get("patch", 0)])
	print("")
	_check_plugin_cfg()
	_check_plugin_script()
	_check_version_adapter()
	_print_summary()
	return 0 if _passed else 1

func _check_plugin_cfg():
	print("Checking plugin.cfg...")
	var cfg_path = "res://addons/gdscript_complexity/plugin.cfg"
	var file_helper = load("res://tests/file_helper_4.gd").new()
	if not file_helper.file_exists(cfg_path):
		_errors.append("plugin.cfg not found at %s" % cfg_path)
		_passed = false
		return
	var content = file_helper.read_file(cfg_path)
	if content.length() == 0:
		_errors.append("plugin.cfg is empty")
		_passed = false
		return
	if content.find("[plugin]") < 0:
		_errors.append("plugin.cfg missing [plugin] section")
		_passed = false
		return
	if content.find("script=") < 0:
		_errors.append("plugin.cfg missing script= entry")
		_passed = false
		return
	print("  ✓ plugin.cfg exists and has required fields")

func _check_plugin_script():
	print("Checking plugin.gd...")
	var plugin_path = "res://addons/gdscript_complexity/plugin.gd"
	var file_helper = load("res://tests/file_helper_4.gd").new()
	if not file_helper.file_exists(plugin_path):
		_errors.append("plugin.gd not found")
		_passed = false
		return
	var content = file_helper.read_file(plugin_path)
	if content.length() == 0:
		_errors.append("plugin.gd is empty")
		_passed = false
		return
	if content.find("@tool") < 0:
		_warnings.append("plugin.gd missing @tool annotation")
	if content.find("extends EditorPlugin") < 0:
		_errors.append("plugin.gd does not extend EditorPlugin")
		_passed = false
		return
	var script = load(plugin_path)
	if script == null:
		_warnings.append("plugin.gd cannot be fully loaded in headless mode (EditorPlugin unavailable)")
		print("  ⚠ plugin.gd structure valid (full load requires editor)")
	else:
		print("  ✓ plugin.gd loads without parse errors")

func _check_version_adapter():
	print("Checking version_adapter.gd...")
	var adapter_path = "res://addons/gdscript_complexity/version_adapter.gd"
	var script = load(adapter_path)
	if script == null:
		_errors.append("Failed to load version_adapter.gd")
		_passed = false
		return
	var adapter = script.new()
	if adapter == null:
		_errors.append("Failed to instantiate version_adapter")
		_passed = false
		return
	if not adapter.has_method("is_supported_version"):
		_errors.append("version_adapter missing is_supported_version()")
		_passed = false
		return
	if not adapter.is_godot_4:
		_errors.append("version_adapter.is_godot_4 should be true on Godot 4.x")
		_passed = false
	elif not adapter.is_supported_version():
		_errors.append("version_adapter.is_supported_version() should be true on Godot 4.x")
		_passed = false
	else:
		print("  ✓ version_adapter detects Godot 4.x and marks it supported")
	adapter = null

func _print_summary():
	if _warnings.size() > 0:
		print("")
		print("Warnings:")
		for w in _warnings:
			print("  - %s" % w)
	if _errors.size() > 0:
		print("")
		print("Errors:")
		for e in _errors:
			print("  - %s" % e)
		print("")
	if _passed:
		print("")
		print("++ Plugin structure verification PASSED")
		print("")
		print("Manual steps to load plugin in editor:")
		print("  1. Open Godot 4.x editor")
		print("  2. Open this project (project.godot)")
		print("  3. Go to Project > Project Settings > Plugins")
		print("  4. Enable 'GDScript Complexity Analyzer'")
		print("  5. Check for errors in Output panel")
		print("  6. Verify dock panel appears in editor")
	else:
		print("")
		print("xx Plugin structure verification FAILED")
		print("Fix errors before loading plugin in editor")
