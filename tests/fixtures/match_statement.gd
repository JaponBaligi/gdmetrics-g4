# Match statement - CC: 5, C-COG: 8
# Expected: CC = 1 (base) + 1 (match) + 3 (arms) = 5
# Expected: C-COG = 2 (match depth 1) + 3 (arms) + 3 (returns in control flow) = 8

func handle_state(state):
	match state:
		"idle":
			return "waiting"
		"active":
			return "running"
		_:
			return "unknown"
