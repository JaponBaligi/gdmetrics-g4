# Logical operators - CC: 5, C-COG: 10
# Expected: CC = 1 (base) + 1 (if) + 1 (and) + 1 (if) + 1 (or) = 5
# Expected: C-COG = 2+2 (if/and) + 2+2 (if/or) + 1+1 (returns in control flow) = 10

func validate_input(x, y):
	if x > 0 and y > 0:
		return true
	if x < 0 or y < 0:
		return false
	return true
