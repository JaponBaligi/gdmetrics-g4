# CSV export test script
# Run with: godot --headless --script cli/test_csv_export.gd

extends SceneTree

class MockFunc:
	var name: String = ""
	var type: String = "func"
	var start_line: int = 0
	var end_line: int = 0
	var parameters: Array = []
	var return_type: String = ""

func _initialize():
	var separator = "============================================================"
	print(separator)
	print("Testing CSV Export")
	print(separator)
	
	var batch_script = load("res://addons/gdscript_complexity/src/batch_analyzer.gd")
	var project_result = batch_script.create_project_result()
	var file_result = batch_script.create_file_result()
	
	file_result.success = true
	file_result.file_path = "res://path/with,comma.gd"
	file_result.confidence = 0.95
	
	var func_info = MockFunc.new()
	func_info.name = "my\"func"
	func_info.start_line = 10
	func_info.end_line = 20
	file_result.functions = [func_info]
	file_result.per_function_cc = {"my\"func": 3}
	file_result.per_function_cog = {"my\"func": 5}
	
	project_result.file_results = [file_result]
	
	var report_gen = load("res://addons/gdscript_complexity/src/gd4/report_generator.gd").new()
	var csv_text = report_gen.generate_csv(project_result, null)
	
	var has_header = csv_text.begins_with("file_path,function_name,CC,C-COG,confidence,line_start,line_end")
	var has_file_path = csv_text.find("\"res://path/with,comma.gd\"") >= 0
	var has_func_name = csv_text.find("\"my\"\"func\"") >= 0
	
	if has_header and has_file_path and has_func_name:
		print("PASSED: CSV export formatting and escaping")
		call_deferred("quit", 0)
	else:
		print("FAILED: CSV export formatting and escaping")
		print(csv_text)
		call_deferred("quit", 1)
