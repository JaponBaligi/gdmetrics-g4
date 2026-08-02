extends Object
class_name CacheManager

# Content-based incremental analysis cache

const ADDON_ROOT := "res://addons/gdscript_complexity"
const SRC_ROOT := ADDON_ROOT + "/src"

class CacheEntry:
	var file_path: String = ""
	var file_hash: String = ""
	var config_hash: String = ""
	var timestamp: int = 0
	var result_data: Dictionary = {}
	
	func to_dict() -> Dictionary:
		return {
			"file_path": file_path,
			"file_hash": file_hash,
			"config_hash": config_hash,
			"timestamp": timestamp,
			"result_data": result_data
		}
	
	func from_dict(data: Dictionary):
		file_path = data.get("file_path", "")
		file_hash = data.get("file_hash", "")
		config_hash = data.get("config_hash", "")
		timestamp = data.get("timestamp", 0)
		result_data = data.get("result_data", {})

var cache_path: String = ""
var enabled: bool = false
var _file_helper = null

func _init(cache_directory: String = "", enable: bool = true):
	enabled = enable
	_file_helper = load(SRC_ROOT + "/gd4/file_helper.gd").new()
	
	if cache_directory == "":
		cache_directory = ".gdcomplexity_cache"
	
	cache_path = cache_directory
	_ensure_cache_directory()

func _ensure_cache_directory():
	if not enabled:
		return
	
	# Godot 4.x: Use DirAccess static methods
	if not DirAccess.dir_exists_absolute(cache_path):
		DirAccess.make_dir_absolute(cache_path)

# Calculate content-based hash of file
func calculate_file_hash(file_path: String) -> String:
	if not _file_helper.file_exists(file_path):
		return ""
	
	var f = _file_helper.open_read(file_path)
	if f == null:
		return ""
	
	var content = f.get_as_text()
	_file_helper.close_file(f)
	
	# Use simple hash function (works in both 3.x and 4.x)
	# For better collision resistance, we could use MD5/SHA256 if available
	return _hash_string(content)

# Calculate hash of effective configuration
func calculate_config_hash(config) -> String:
	# Create a normalized representation of the config
	var config_dict = {
		"include": config.include_patterns,
		"exclude": config.exclude_patterns,
		"cc": config.cc_config,
		"cog": config.cog_config,
		"parser": config.parser_config
	}
	
	# Convert to JSON string for hashing
	var json = JSON.new()
	var json_string: String = json.stringify(config_dict)
	
	return _hash_string(json_string)

# Simple hash function (FNV-1a variant for GDScript compatibility)
func _hash_string(text: String) -> String:
	var hash = 2166136261  # FNV offset basis (32-bit)
	for i in range(text.length()):
		var char_code: int = text.unicode_at(i)
		hash = hash ^ char_code
		hash = hash * 16777619  # FNV prime (32-bit)
		# Keep within 32-bit range
		hash = hash & 0xFFFFFFFF
	
	# Convert to hex string
	var hex_chars = "0123456789abcdef"
	var result = ""
	for i in range(8):
		var nibble = (hash >> (i * 4)) & 0xF
		result = hex_chars[nibble] + result
	return result

# Get cache key for a file path
func _get_cache_key(file_path: String) -> String:
	# Create a safe filename from the file path
	var key = file_path.replace("\\", "/").replace(":", "_").replace("/", "_")
	# Limit length to avoid filesystem issues
	if key.length() > 200:
		key = key.substr(key.length() - 200)
	return key + ".cache"

# Load cached result for a file
func get_cached_result(file_path: String, config) -> Dictionary:
	if not enabled:
		return {}
	
	var file_hash = calculate_file_hash(file_path)
	if file_hash == "":
		return {}
	
	var config_hash = calculate_config_hash(config)
	var cache_key = _get_cache_key(file_path)
	var cache_file_path: String = cache_path.path_join(cache_key)
	
	if not _file_helper.file_exists(cache_file_path):
		return {}
	
	# Read cache entry
	var f = _file_helper.open_read(cache_file_path)
	if f == null:
		return {}
	
	var json_text = f.get_as_text()
	_file_helper.close_file(f)
	
	# Parse JSON
	var json = JSON.new()
	if json.parse(json_text) != OK:
		return {}
	var data: Dictionary = json.get_data()
	
	if not data is Dictionary:
		return {}
	
	var entry = CacheEntry.new()
	entry.from_dict(data)
	
	# Validate cache entry
	if entry.file_path != file_path:
		return {}
	
	if entry.file_hash != file_hash:
		# File content changed, invalidate
		return {}
	
	if entry.config_hash != config_hash:
		# Config changed, invalidate
		return {}
	
	# Cache hit - return cached result
	return entry.result_data

# Store analysis result in cache
func store_result(file_path: String, config, file_result) -> bool:
	if not enabled:
		return false
	
	var file_hash = calculate_file_hash(file_path)
	if file_hash == "":
		return false
	
	var config_hash = calculate_config_hash(config)
	var cache_key = _get_cache_key(file_path)
	var cache_file_path: String = cache_path.path_join(cache_key)
	
	# Convert FileResult to dictionary
	var result_data = _file_result_to_dict(file_result)
	
	var entry = CacheEntry.new()
	entry.file_path = file_path
	entry.file_hash = file_hash
	entry.config_hash = config_hash
	# Use ticks for compatibility (milliseconds since engine start)
	# For absolute time, we'd need OS.get_datetime() conversion, but ticks work for TTL
	entry.timestamp = Time.get_ticks_msec()
	entry.result_data = result_data
	
	# Write cache entry
	var entry_dict = entry.to_dict()
	
	var json = JSON.new()
	var json_string: String = json.stringify(entry_dict)
	
	# Write file
	var file = FileAccess.open(cache_file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json_string)
	file = null
	
	return true

# Convert FileResult to dictionary for serialization
func _file_result_to_dict(file_result) -> Dictionary:
	return {
		"file_path": file_result.file_path,
		"success": file_result.success,
		"cc": file_result.cc,
		"cog": file_result.cog,
		"confidence": file_result.confidence,
		"functions": file_result.functions,
		"classes": file_result.classes,
		"errors": file_result.errors,
		"cc_breakdown": file_result.cc_breakdown,
		"cog_breakdown": file_result.cog_breakdown,
		"per_function_cc": file_result.per_function_cc,
		"per_function_cog": file_result.per_function_cog,
		"per_function_cc_breakdown": file_result.per_function_cc_breakdown,
		"per_function_cog_breakdown": file_result.per_function_cog_breakdown,
		"per_function_directives": file_result.per_function_directives,
		"max_nesting_depth": file_result.max_nesting_depth,
		"match_arm_count": file_result.match_arm_count,
		"lambda_count": file_result.lambda_count,
		"max_params": file_result.max_params,
		"loc_code": file_result.loc_code
	}

# Convert dictionary back to FileResult
func _dict_to_file_result(data: Dictionary):
	var result = load(SRC_ROOT + "/batch_analyzer.gd").FileResult.new()
	result.file_path = data.get("file_path", "")
	result.success = data.get("success", false)
	result.cc = data.get("cc", 0)
	result.cog = data.get("cog", 0)
	result.confidence = data.get("confidence", 0.0)
	result.functions = data.get("functions", [])
	result.classes = data.get("classes", [])
	result.errors = data.get("errors", [])
	result.cc_breakdown = data.get("cc_breakdown", {})
	result.cog_breakdown = data.get("cog_breakdown", {})
	result.per_function_cc = data.get("per_function_cc", {})
	result.per_function_cog = data.get("per_function_cog", {})
	result.per_function_cc_breakdown = data.get("per_function_cc_breakdown", {})
	result.per_function_cog_breakdown = data.get("per_function_cog_breakdown", {})
	result.per_function_directives = data.get("per_function_directives", {})
	result.max_nesting_depth = data.get("max_nesting_depth", 0)
	result.match_arm_count = data.get("match_arm_count", 0)
	result.lambda_count = data.get("lambda_count", 0)
	result.max_params = data.get("max_params", 0)
	result.loc_code = data.get("loc_code", 0)
	return result

# Clean up orphaned cache entries (files that no longer exist)
func cleanup_orphaned_entries(valid_files: Array) -> int:
	if not enabled:
		return 0
	
	var cleaned = 0
	var valid_paths = {}
	for path in valid_files:
		valid_paths[path] = true
	
	# List all cache files
	var cache_files = []
	var dir = DirAccess.open(cache_path)
	if dir != null:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".cache"):
				cache_files.append(file_name)
			file_name = dir.get_next()
	
	# Check each cache file
	for cache_file in cache_files:
		var cache_file_path: String = cache_path.path_join(cache_file)
		
		# Read cache entry to get file_path
		var f = _file_helper.open_read(cache_file_path)
		if f == null:
			# Corrupted cache file, remove it
			_remove_file(cache_file_path)
			cleaned += 1
			continue
		
		var json_text = f.get_as_text()
		_file_helper.close_file(f)
		
		var json = JSON.new()
		if json.parse(json_text) != OK:
			_remove_file(cache_file_path)
			cleaned += 1
			continue
		var data: Dictionary = json.get_data()
		
		var entry = CacheEntry.new()
		entry.from_dict(data)
		
		# Check if file still exists and is in valid_files
		if not valid_paths.has(entry.file_path) or not _file_helper.file_exists(entry.file_path):
			_remove_file(cache_file_path)
			cleaned += 1
	
	return cleaned

# Remove old cache entries (TTL-based cleanup)
func cleanup_old_entries(max_age_msec: int = 604800000) -> int:  # Default: 7 days in milliseconds
	if not enabled:
		return 0
	
	var cleaned = 0
	var current_time = Time.get_ticks_msec()
	
	# List all cache files
	var cache_files = []
	var dir = DirAccess.open(cache_path)
	if dir != null:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".cache"):
				cache_files.append(file_name)
			file_name = dir.get_next()
	
	# Check each cache file
	for cache_file in cache_files:
		var cache_file_path: String = cache_path.path_join(cache_file)
		
		# Read cache entry to get timestamp
		var f = _file_helper.open_read(cache_file_path)
		if f == null:
			continue
		
		var json_text = f.get_as_text()
		_file_helper.close_file(f)
		
		var json = JSON.new()
		if json.parse(json_text) != OK:
			continue
		var data: Dictionary = json.get_data()
		
		var entry = CacheEntry.new()
		entry.from_dict(data)
		
		# Check if entry is too old
		if current_time - entry.timestamp > max_age_msec:
			_remove_file(cache_file_path)
			cleaned += 1
	
	return cleaned

# Helper to remove a file
func _remove_file(file_path: String):
	var dir = DirAccess.open(".")
	if dir != null:
		dir.remove(file_path)

# Clear all cache entries
func clear_cache() -> int:
	if not enabled:
		return 0
	
	var cleared = 0
	var cache_files = []
	
	var dir = DirAccess.open(cache_path)
	if dir != null:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".cache"):
				cache_files.append(file_name)
			file_name = dir.get_next()
	
	for cache_file in cache_files:
		var cache_file_path: String = cache_path.path_join(cache_file)
		_remove_file(cache_file_path)
		cleared += 1
	
	return cleared
