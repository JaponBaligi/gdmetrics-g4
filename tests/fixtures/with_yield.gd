# yield syntax fixture - CC: 2, C-COG: 2
# Expected: CC = 1 (base) + 1 (if) = 2
# Expected: C-COG = 2 (if at depth 1)
# Note: yield is not a control flow structure for CC/C-COG

func async_function():
	if true:
		yield(get_tree(), "idle_frame")
		print("done")
