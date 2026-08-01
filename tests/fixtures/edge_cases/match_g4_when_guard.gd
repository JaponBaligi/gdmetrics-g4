extends Node
func f(x):
	match x:
		var n when n > 0:
			return n
		_:
			return 0
