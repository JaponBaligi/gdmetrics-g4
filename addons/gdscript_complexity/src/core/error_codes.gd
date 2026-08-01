# Error code map and helpers
# Keep as strings for backward-compatible error arrays.

extends Object

const SEVERITY_ERROR = "error"
const SEVERITY_WARNING = "warning"
const SEVERITY_INFO = "info"

const CODES = {
	"FILE_NOT_FOUND": "File not found",
	"FILE_OPEN_FAILED": "Failed to open file",
	"CONFIG_HELPER_MISSING": "File helper not available",
	"CONFIG_FILE_NOT_FOUND": "Config file not found",
	"CONFIG_OPEN_FAILED": "Failed to open config file",
	"CONFIG_INVALID_JSON": "Invalid JSON in config file",
	"CONFIG_INVALID_ROOT": "Config file must contain a JSON object",
	"CONFIG_INVALID_TYPE": "Config value has invalid type",
	"CONFIG_INVALID_VALUE": "Config value has invalid value",
	"TOKEN_UNTERMINATED_COMMENT": "Unterminated multi-line comment",
	"TOKEN_UNTERMINATED_STRING": "Unterminated string",
	"TOKEN_UNBALANCED_PAREN": "Unbalanced parentheses",
	"TOKEN_UNBALANCED_BRACKET": "Unbalanced brackets",
	"TOKEN_UNBALANCED_BRACE": "Unbalanced braces",
	"TOKEN_UNKNOWN_CHAR": "Unknown character",
	"TOKEN_PARSE_ERROR": "Token parse error",
	"NO_TOKENS_FOUND": "No tokens found",
	"NO_FILES_FOUND": "No files found matching include patterns",
	"FILE_DISCOVERY_FAILED": "Failed to open root path",
	"CLASS_DECLARATION_MISSING": "class_name declaration without class definition",
	"EXTENDS_WITHOUT_CLASS": "extends declaration without class definition",
	"OUTPUT_PATH_FORBIDDEN": "Output path would overwrite protected path",
	"ANALYSIS_FAILED": "Analysis failed"
}

const DEFAULT_SEVERITY = {
	"FILE_NOT_FOUND": SEVERITY_ERROR,
	"FILE_OPEN_FAILED": SEVERITY_ERROR,
	"CONFIG_HELPER_MISSING": SEVERITY_WARNING,
	"CONFIG_FILE_NOT_FOUND": SEVERITY_WARNING,
	"CONFIG_OPEN_FAILED": SEVERITY_WARNING,
	"CONFIG_INVALID_JSON": SEVERITY_WARNING,
	"CONFIG_INVALID_ROOT": SEVERITY_WARNING,
	"CONFIG_INVALID_TYPE": SEVERITY_WARNING,
	"CONFIG_INVALID_VALUE": SEVERITY_WARNING,
	"TOKEN_UNTERMINATED_COMMENT": SEVERITY_ERROR,
	"TOKEN_UNTERMINATED_STRING": SEVERITY_ERROR,
	"TOKEN_UNBALANCED_PAREN": SEVERITY_ERROR,
	"TOKEN_UNBALANCED_BRACKET": SEVERITY_ERROR,
	"TOKEN_UNBALANCED_BRACE": SEVERITY_ERROR,
	"TOKEN_UNKNOWN_CHAR": SEVERITY_WARNING,
	"TOKEN_PARSE_ERROR": SEVERITY_ERROR,
	"NO_TOKENS_FOUND": SEVERITY_ERROR,
	"NO_FILES_FOUND": SEVERITY_ERROR,
	"FILE_DISCOVERY_FAILED": SEVERITY_ERROR,
	"CLASS_DECLARATION_MISSING": SEVERITY_WARNING,
	"EXTENDS_WITHOUT_CLASS": SEVERITY_WARNING,
	"OUTPUT_PATH_FORBIDDEN": SEVERITY_ERROR,
	"ANALYSIS_FAILED": SEVERITY_ERROR
}

func format(code: String, detail: String = "") -> String:
	var base = detail
	if base == "" and CODES.has(code):
		base = CODES[code]
	if base == "":
		base = "Unknown error"
	return "[%s] %s" % [code, base]

func get_severity(code: String) -> String:
	if DEFAULT_SEVERITY.has(code):
		return DEFAULT_SEVERITY[code]
	return SEVERITY_ERROR
