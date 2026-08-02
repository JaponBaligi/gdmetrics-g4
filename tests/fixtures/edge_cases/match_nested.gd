extends Node
func f(x, y):
	match x:
		1:
			match y:
				"a":
					return 1
				"b":
					return 2
		2:
			return 3
