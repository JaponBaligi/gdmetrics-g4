# File without match statements - CC: 3, C-COG: 6
# Expected: CC = 1 (base) + 1 (if) + 1 (elif) = 3
# Expected: C-COG = 2 (if depth 1) + 2 (elif depth 1) + 1 (return) + 1 (return) = 6

func check_value(x):
	if x > 0:
		return "positive"
	elif x < 0:
		return "negative"
	return "zero"
