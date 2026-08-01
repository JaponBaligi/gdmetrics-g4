extends Object
# class_name CCCalculator

#  Cyclomatic Complexity calculator
# Formula: CC = 1 (base) + decisions
# Decisions: if, elif, for, while, match, case, logical operators

var cc_value: int = 0
var breakdown: Dictionary = {}

func calculate_cc(control_flow_nodes: Array, count_logical_operators: bool = true) -> int:
	cc_value = 1  # Base complexity
	breakdown = {
		"base": 1,
		"if": 0,
		"elif": 0,
		"for": 0,
		"while": 0,
		"match": 0,
		"case": 0,
		"ternary": 0,
		"and": 0,
		"or": 0,
		"not": 0
	}
	
	for node in control_flow_nodes:
		match node.type:
			"if":
				cc_value += 1
				breakdown["if"] += 1
			"ternary":
				cc_value += 1
				breakdown["ternary"] += 1
			"elif":
				cc_value += 1
				breakdown["elif"] += 1
			"for":
				cc_value += 1
				breakdown["for"] += 1
			"while":
				cc_value += 1
				breakdown["while"] += 1
			"match":
				cc_value += 1
				breakdown["match"] += 1
			"case":
				cc_value += 1
				breakdown["case"] += 1
			"and":
				if count_logical_operators:
					cc_value += 1
					breakdown["and"] += 1
			"or":
				if count_logical_operators:
					cc_value += 1
					breakdown["or"] += 1
			"not":
				if count_logical_operators:
					cc_value += 1
					breakdown["not"] += 1
	
	return cc_value

func get_breakdown() -> Dictionary:
	return breakdown.duplicate()

func get_cc() -> int:
	return cc_value

