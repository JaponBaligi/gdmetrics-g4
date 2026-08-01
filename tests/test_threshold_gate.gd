# Verifies threshold_gate marks high-complexity fixtures as FAIL under tight limits.
extends SceneTree

func _initialize():
	var code = run_test()
	call_deferred("quit", code)

func run_test() -> int:
	print("test_threshold_gate: start")
	var version_adapter = load("res://addons/gdscript_complexity/version_adapter.gd").new()
	var config_mgr = load("res://addons/gdscript_complexity/src/config_manager.gd").new()
	var config = config_mgr.get_config()
	config.cc_config["threshold_warn"] = 1
	config.cc_config["threshold_fail"] = 2
	config.cog_config["threshold_warn"] = 1
	config.cog_config["threshold_fail"] = 2
	config.include_patterns = ["res://tests/fixtures/nested_control_flow.gd"]
	config.exclude_patterns = []

	var batch = load("res://addons/gdscript_complexity/src/batch_analyzer.gd").new()
	var project_result = batch.analyze_project(".", config, version_adapter)
	if project_result.successful_files < 1:
		print("ERROR: expected successful analysis of nested_control_flow.gd")
		return 1

	var gate = load("res://addons/gdscript_complexity/src/core/threshold_gate.gd").new()
	var result = gate.evaluate(project_result, config)
	gate.print_summary(result)

	if result["fail_count"] < 1:
		print("ERROR: expected at least one FAIL breach under tight thresholds")
		return 1

	print("test_threshold_gate: OK (%d fail breaches)" % result["fail_count"])
	return 0
