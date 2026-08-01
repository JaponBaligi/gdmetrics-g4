# Triple string closes mid-line; trail must tokenize (brackets / escapes).
func msg(path: String) -> String:
	return """Failed loading \"%s\"
	\nLocal to \"%s"
""".dedent().trim_prefix("\n") % [path, path]
