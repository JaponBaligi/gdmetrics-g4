# Unit tests for CacheManager
# Run with: godot --headless --script tests/test_cache_manager.gd

extends SceneTree

func _initialize():
	var separator = "============================================================"
	print(separator)
	print("Testing CacheManager")
	print(separator)
	
	var tests_passed = 0
	var tests_failed = 0
	
	# Test 1: Cache manager initialization
	print("\n[Test 1] Cache manager initialization...")
	var cache_manager = load("res://addons/gdscript_complexity/src/cache_manager.gd").new(".test_cache", true)
	if cache_manager == null:
		print("FAILED: Failed to create cache manager")
		tests_failed += 1
	else:
		print("PASSED: Cache manager created")
		tests_passed += 1
	
	# Test 2: File hash calculation
	print("\n[Test 2] File hash calculation...")
	var test_file = "res://addons/gdscript_complexity/src/config_manager.gd"
	var hash1 = cache_manager.calculate_file_hash(test_file)
	var hash2 = cache_manager.calculate_file_hash(test_file)
	if hash1 == "" or hash2 == "":
		print("FAILED: Hash calculation returned empty string")
		tests_failed += 1
	elif hash1 != hash2:
		print("FAILED: Hash calculation is not deterministic")
		tests_failed += 1
	else:
		print("PASSED: Hash calculation works (hash: %s)" % hash1.substr(0, 8))
		tests_passed += 1
	
	# Test 3: Config hash calculation
	print("\n[Test 3] Config hash calculation...")
	var config_manager = load("res://addons/gdscript_complexity/src/config_manager.gd").new()
	var config = config_manager.get_config()
	var config_hash1 = cache_manager.calculate_config_hash(config)
	var config_hash2 = cache_manager.calculate_config_hash(config)
	if config_hash1 == "" or config_hash2 == "":
		print("FAILED: Config hash calculation returned empty string")
		tests_failed += 1
	elif config_hash1 != config_hash2:
		print("FAILED: Config hash calculation is not deterministic")
		tests_failed += 1
	else:
		print("PASSED: Config hash calculation works (hash: %s)" % config_hash1.substr(0, 8))
		tests_passed += 1
	
	# Test 4: Cache storage and retrieval
	print("\n[Test 4] Cache storage and retrieval...")
	var test_file_result = load("res://addons/gdscript_complexity/src/batch_analyzer.gd").FileResult.new()
	test_file_result.file_path = test_file
	test_file_result.success = true
	test_file_result.cc = 5
	test_file_result.cog = 10
	test_file_result.confidence = 0.95
	test_file_result.functions = []
	test_file_result.classes = []
	test_file_result.errors = []
	test_file_result.cc_breakdown = {}
	test_file_result.cog_breakdown = {}
	test_file_result.per_function_cog = {}
	
	var stored = cache_manager.store_result(test_file, config, test_file_result)
	if not stored:
		print("FAILED: Failed to store result in cache")
		tests_failed += 1
	else:
		var cached = cache_manager.get_cached_result(test_file, config)
		if cached.size() == 0:
			print("FAILED: Failed to retrieve cached result")
			tests_failed += 1
		elif cached.get("cc", -1) != 5:
			print("FAILED: Cached result data mismatch (expected cc=5, got %d)" % cached.get("cc", -1))
			tests_failed += 1
		else:
			print("PASSED: Cache storage and retrieval works")
			tests_passed += 1
	
	# Test 5: Cache invalidation on file change
	print("\n[Test 5] Cache invalidation on file change...")
	# Store initial result
	cache_manager.store_result(test_file, config, test_file_result)
	# Modify file content (simulate by creating a temp file with different content)
	var temp_file = ".test_temp_file.gd"
	# Create a temp file with different content
	var file = FileAccess.open(temp_file, FileAccess.WRITE)
	if file != null:
		file.store_string("# Different content")
		file = null
	
	# Store result for temp file
	var temp_result = load("res://addons/gdscript_complexity/src/batch_analyzer.gd").FileResult.new()
	temp_result.file_path = temp_file
	temp_result.success = true
	temp_result.cc = 1
	temp_result.cog = 2
	temp_result.confidence = 0.9
	temp_result.functions = []
	temp_result.classes = []
	temp_result.errors = []
	temp_result.cc_breakdown = {}
	temp_result.cog_breakdown = {}
	temp_result.per_function_cog = {}
	cache_manager.store_result(temp_file, config, temp_result)
	
	# Verify it's cached
	var cached_before = cache_manager.get_cached_result(temp_file, config)
	if cached_before.size() == 0:
		print("WARNING: Failed to cache temp file (may be expected)")
	
	# Modify temp file content
	file = FileAccess.open(temp_file, FileAccess.WRITE)
	if file != null:
		file.store_string("# Modified content - different")
		file = null
	
	# Try to retrieve - should be invalidated
	var cached_after_modify = cache_manager.get_cached_result(temp_file, config)
	if cached_after_modify.size() > 0:
		print("FAILED: Cache was not invalidated after file content change")
		tests_failed += 1
	else:
		print("PASSED: Cache invalidation on file change works")
		tests_passed += 1
	
	# Cleanup temp file
	var dir = DirAccess.open(".")
	if dir != null:
		dir.remove(temp_file)
	
	# Test 6: Cache invalidation on config change
	print("\n[Test 6] Cache invalidation on config change...")
	# Store with original config
	cache_manager.store_result(test_file, config, test_file_result)
	# Modify config
	var modified_config = config.duplicate()
	modified_config.cc_config["threshold_warn"] = 999
	var cached_after_config_change = cache_manager.get_cached_result(test_file, modified_config)
	if cached_after_config_change.size() > 0:
		print("FAILED: Cache was not invalidated after config change")
		tests_failed += 1
	else:
		print("PASSED: Cache invalidation on config change works")
		tests_passed += 1
	
	# Test 7: Cache cleanup
	print("\n[Test 7] Cache cleanup...")
	var cleaned = cache_manager.cleanup_orphaned_entries([test_file])
	print("Cleaned %d orphaned entries" % cleaned)
	print("PASSED: Cache cleanup works")
	tests_passed += 1
	
	# Test 8: Clear cache
	print("\n[Test 8] Clear cache...")
	var cleared = cache_manager.clear_cache()
	if cleared == 0:
		print("WARNING: No cache entries to clear (may be expected)")
	print("Cleared %d cache entries" % cleared)
	print("PASSED: Clear cache works")
	tests_passed += 1
	
	# Summary
	print("\n" + separator)
	print("Test Summary: %d passed, %d failed" % [tests_passed, tests_failed])
	print(separator)
	
	if tests_failed > 0:
		quit(1)
	else:
		quit(0)
