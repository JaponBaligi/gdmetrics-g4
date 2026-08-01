extends Node
func f():
	var cb = func(x):
		if x:
			return func(y):
				return y if y else 0
		return null
	return cb
