# CI test script
# Run with: godot --headless --script cli/ci_test.gd -- --project-path . --output report.json

extends SceneTree

var FORBIDDEN_OUTPUT_PATHS = [
	"project.godot",
	".git",
	"addons/gdscript_complexity/",
	"cli/",
	"docs/",
	".github/"
]

func _initialize():
	var args = OS.get_cmdline_args()
	var project_path = "."
	var output_path = "ci_report.json"
	var csv_output_path = ""
	
	var dash_index = args.find("--")
	if dash_index >= 0:
		var remaining_args = []
		for i in range(dash_index + 1, args.size()):
			remaining_args.append(args[i])
		var i = 0
		while i < remaining_args.size():
			var arg = remaining_args[i]
			if arg == "--project-path" and i + 1 < remaining_args.size():
				project_path = _sanitize_path(remaining_args[i + 1])
				i += 2
			elif arg == "--output" and i + 1 < remaining_args.size():
				output_path = _sanitize_path(remaining_args[i + 1])
				i += 2
			elif arg == "--csv-output" and i + 1 < remaining_args.size():
				csv_output_path = _sanitize_path(remaining_args[i + 1])
				i += 2
			else:
				i += 1
	
	var exit_code = run_analysis(project_path, output_path, csv_output_path)
	call_deferred("quit", exit_code)

func _sanitize_path(path: String) -> String:
	if path.length() == 0:
		return "."
	
	var sanitized = path.replace("\\", "/")

	while sanitized.find("../") >= 0:
		sanitized = sanitized.replace("../", "")

	while sanitized.begins_with("/"):
		sanitized = sanitized.substr(1)

	if sanitized.begins_with("res://"):
		sanitized = sanitized.substr(6)
	
	return sanitized

func _check_output_overwrite(output_path: String) -> bool:
	var normalized = output_path.replace("\\", "/").to_lower()
	
	for forbidden in FORBIDDEN_OUTPUT_PATHS:
		if normalized.find(forbidden.to_lower()) >= 0:
			print("ERROR: Output path '%s' would overwrite protected path '%s'" % [output_path, forbidden])
			return false
	
	return true

func run_analysis(project_path: String, output_path: String, csv_output_path: String) -> int:
	print("Running CI analysis test...")
	
	project_path = _sanitize_path(project_path)
	output_path = _sanitize_path(output_path)
	
	if not _check_output_overwrite(output_path):
		return 1
	
	print("Project path: %s" % project_path)
	print("Output path: %s" % output_path)
	
	var version_adapter = load("res://addons/gdscript_complexity/version_adapter.gd").new()
	print("Godot version: %s" % version_adapter.get_version_string())
	
	var config = load("res://addons/gdscript_complexity/src/config_manager.gd").new()
	var config_path = "res://complexity_config.json"
	if not config.load_config(config_path):
		if config.has_errors():
			for error in config.get_errors():
				print("Config warning: %s" % error)
	var default_config = config.get_config()
	
	var batch_analyzer = load("res://addons/gdscript_complexity/src/batch_analyzer.gd").new()
	var project_result = batch_analyzer.analyze_project(project_path, default_config, version_adapter)
	
	if project_result.total_files == 0:
		print("ERROR: No files found for analysis")
		return 1
	
	print("Files analyzed: %d" % project_result.total_files)
	print("Successful: %d" % project_result.successful_files)
	print("Failed: %d" % project_result.failed_files)
	
	if project_result.successful_files == 0:
		print("ERROR: No files successfully analyzed")
		return 1
	
	var report_gen = load("res://addons/gdscript_complexity/src/gd4/report_generator.gd").new()
	var report = report_gen.generate_report(project_result, default_config)
	
	if not report_gen.write_report(report, output_path):
		print("ERROR: Failed to write report")
		return 1
	
	print("Report written to: %s" % output_path)
	
	var should_write_csv = false
	if csv_output_path != "":
		should_write_csv = true
	elif default_config.report_config.has("formats") and default_config.report_config["formats"].has("csv"):
		csv_output_path = default_config.report_config.get("csv_output_path", "complexity_report.csv")
		should_write_csv = true
	
	if should_write_csv:
		var csv_text = report_gen.generate_csv(project_result, default_config)
		if not report_gen.write_csv(csv_text, csv_output_path):
			print("ERROR: Failed to write CSV report")
			return 1
		print("CSV report written to: %s" % csv_output_path)
	print("Total CC: %d" % project_result.total_cc)
	print("Total C-COG: %d" % project_result.total_cog)
	print("Average CC: %.2f" % project_result.average_cc)
	print("Average C-COG: %.2f" % project_result.average_cog)
	
	# Release references before quit. Exit may still show "ObjectDB leaked" / "Resources still
	# in use" from loaded scripts; those are harmless. See docs/before5.md.
	report_gen = null
	batch_analyzer = null
	version_adapter = null
	config = null
	default_config = null
	project_result = null
	
	return 0

