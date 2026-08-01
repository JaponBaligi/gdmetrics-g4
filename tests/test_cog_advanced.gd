# Advanced C-COG tests
# Run with: godot --headless --script cli/test_cog_advanced.gd

extends SceneTree

func _initialize():
	var separator = "============================================================"
	print(separator)
	print("Testing Advanced C-COG Rules")
	print(separator)
	
	var detector_script = load("res://addons/gdscript_complexity/src/core/control_flow_detector.gd")
	var calc_script = load("res://addons/gdscript_complexity/src/core/cog_complexity_calculator.gd")
	var node_class = detector_script.ControlFlowNode
	
	var nodes: Array = []
	
	# if at depth 1 => +2
	var if_node = node_class.new("if", 1, 1, 1)
	nodes.append(if_node)
	
	# match at depth 1 => +2
	var match_node = node_class.new("match", 2, 1, 1)
	nodes.append(match_node)
	
	# case with 3 patterns and guard => +1 (base) +2 (extra patterns) +1 (guard) = +4
	var case_node = node_class.new("case", 3, 1, 2)
	case_node.case_pattern_count = 3
	case_node.case_has_guard = true
	nodes.append(case_node)
	
	# return inside control flow => +1
	var return_node = node_class.new("return", 4, 1, 2)
	return_node.in_control_flow = true
	nodes.append(return_node)
	
	# return outside control flow => +0
	var return_outside = node_class.new("return", 5, 1, 0)
	return_outside.in_control_flow = false
	nodes.append(return_outside)
	
	# lambda contributes +1, nodes inside lambda should not leak
	var lambda_node = node_class.new("lambda", 6, 1, 1)
	nodes.append(lambda_node)
	var lambda_if = node_class.new("if", 7, 1, 2)
	lambda_if.lambda_depth = 1
	nodes.append(lambda_if)
	
	var calc = calc_script.new()
	var result = calc.calculate_cog(nodes, [])
	var expected = 10  # if(2) + match(2) + case(4) + return(1) + lambda(1)
	
	if result.total_cog == expected:
		print("PASSED: Advanced C-COG total (%d)" % result.total_cog)
		call_deferred("quit", 0)
	else:
		print("FAILED: Expected %d, got %d" % [expected, result.total_cog])
		call_deferred("quit", 1)
