extends Node

# gdmetrics:ignore
func noisy_but_ok():
	if true:
		if true:
			if true:
				return 1
	return 0

# gdmetrics:pin
func watch_me():
	return 1

func normal_complex():
	if true:
		if true:
			return 2
	return 0
