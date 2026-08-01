# Triple string closes, then `\` continues onto next line.
func skipped(hint: String) -> String:
	return """
		%s
		  Reason: %s
		""".dedent().trim_prefix("\n")\
		% [hint, hint]
