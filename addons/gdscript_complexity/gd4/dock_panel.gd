@tool
extends Control
class_name ComplexityDockPanel

# Displays complexity analysis results and controls

signal analyze_requested
signal export_requested(format: String)
signal config_requested
signal cancel_requested
signal open_requested(script_path: String, line: int)

var analyze_button: Button = null
var cancel_button: Button = null
var progress_bar: ProgressBar = null
var results_tree: Tree = null
var config_button: Button = null
var export_button: MenuButton = null
var open_button: Button = null
var status_label: Label = null

var tree_root: TreeItem = null

func _ready():
	_setup_ui()

func _setup_ui():
	# Set minimum width to prevent text overflow
	custom_minimum_size = Vector2(300, 0)
	
	var vbox = VBoxContainer.new()
	add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Top buttons row
	var button_row = HBoxContainer.new()
	vbox.add_child(button_row)
	
	analyze_button = Button.new()
	analyze_button.text = "Analyze Project"
	analyze_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	analyze_button.pressed.connect(_on_analyze_pressed)
	button_row.add_child(analyze_button)
	
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_button.pressed.connect(_on_cancel_pressed)
	cancel_button.disabled = true
	button_row.add_child(cancel_button)
	
	config_button = Button.new()
	config_button.text = "Config"
	config_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	config_button.pressed.connect(_on_config_pressed)
	button_row.add_child(config_button)
	
	export_button = MenuButton.new()
	export_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var popup = export_button.get_popup()
	popup.add_item("Export JSON")
	popup.add_item("Export CSV")
	popup.add_item("Export HTML")
	popup.id_pressed.connect(_on_export_menu_selected)
	button_row.add_child(export_button)

	open_button = Button.new()
	open_button.text = "Open"
	open_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	open_button.pressed.connect(_on_open_pressed)
	button_row.add_child(open_button)

	progress_bar = ProgressBar.new()
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.visible = false
	vbox.add_child(progress_bar)

	status_label = Label.new()
	status_label.text = "Ready"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_label)

	results_tree = Tree.new()
	results_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	results_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_tree.columns = 7
	results_tree.set_column_titles_visible(true)
	results_tree.set_column_title(0, "File/Function")
	results_tree.set_column_title(1, "CC")
	results_tree.set_column_title(2, "C-COG")
	results_tree.set_column_title(3, "Confidence")
	results_tree.set_column_title(4, "Nest")
	results_tree.set_column_title(5, "Params")
	results_tree.set_column_title(6, "LOC")
	results_tree.set_column_expand(0, true)
	results_tree.set_column_expand(1, false)
	results_tree.set_column_expand(2, false)
	results_tree.set_column_expand(3, false)
	results_tree.set_column_expand(4, false)
	results_tree.set_column_expand(5, false)
	results_tree.set_column_expand(6, false)
	results_tree.set_column_custom_minimum_width(0, 220)
	results_tree.set_column_custom_minimum_width(1, 50)
	results_tree.set_column_custom_minimum_width(2, 55)
	results_tree.set_column_custom_minimum_width(3, 70)
	results_tree.set_column_custom_minimum_width(4, 45)
	results_tree.set_column_custom_minimum_width(5, 55)
	results_tree.set_column_custom_minimum_width(6, 45)
	results_tree.item_activated.connect(_on_item_activated)
	vbox.add_child(results_tree)
	
	_apply_editor_theme()

func _apply_editor_theme():
	if not Engine.is_editor_hint():
		return
	
	var editor_interface = EditorInterface
	if editor_interface == null:
		return
	
	var base_control = editor_interface.get_base_control()
	if base_control == null:
		return
	
	var editor_theme = base_control.theme
	if editor_theme == null:
		return

	if analyze_button != null:
		analyze_button.add_theme_stylebox_override("normal", editor_theme.get_stylebox("normal", "Button"))
		analyze_button.add_theme_stylebox_override("pressed", editor_theme.get_stylebox("pressed", "Button"))
		analyze_button.add_theme_stylebox_override("hover", editor_theme.get_stylebox("hover", "Button"))
	
	if config_button != null:
		config_button.add_theme_stylebox_override("normal", editor_theme.get_stylebox("normal", "Button"))
		config_button.add_theme_stylebox_override("pressed", editor_theme.get_stylebox("pressed", "Button"))
		config_button.add_theme_stylebox_override("hover", editor_theme.get_stylebox("hover", "Button"))
	
	if export_button != null:
		export_button.add_theme_stylebox_override("normal", editor_theme.get_stylebox("normal", "MenuButton"))
		export_button.add_theme_stylebox_override("pressed", editor_theme.get_stylebox("pressed", "MenuButton"))
		export_button.add_theme_stylebox_override("hover", editor_theme.get_stylebox("hover", "MenuButton"))
	
	if status_label != null:
		status_label.add_theme_color_override("font_color", editor_theme.get_color("font_color", "Label"))
	
	if results_tree != null:
		results_tree.add_theme_stylebox_override("panel", editor_theme.get_stylebox("panel", "Tree"))
		results_tree.add_theme_color_override("font_color", editor_theme.get_color("font_color", "Tree"))

func _on_analyze_pressed():
	analyze_requested.emit()

func _on_cancel_pressed():
	cancel_requested.emit()

func _on_config_pressed():
	config_requested.emit()

func _on_export_menu_selected(id: int):
	var format = "json"
	if id == 1:
		format = "csv"
	elif id == 2:
		format = "html"
	export_requested.emit(format)

func _on_open_pressed():
	var target = _get_selected_target()
	if target != null:
		open_requested.emit(target["script_path"], target["line"])

func _on_item_activated():
	var target = _get_selected_target()
	if target != null:
		open_requested.emit(target["script_path"], target["line"])

func set_status(text: String):
	if status_label != null:
		status_label.text = text

func set_progress(value: float, max_value: float = 100.0):
	if progress_bar != null:
		progress_bar.max_value = max_value
		progress_bar.value = value
		progress_bar.visible = (value > 0.0 and value < max_value)

func show_progress(show: bool):
	if progress_bar != null:
		progress_bar.visible = show

func clear_results():
	if results_tree != null:
		results_tree.clear()
		tree_root = null

func add_file_result(
	file_path: String,
	cc: int,
	cog: int,
	confidence: float,
	nesting: int = 0,
	params: int = 0,
	loc: int = 0
):
	if results_tree == null:
		return
	
	if tree_root == null:
		tree_root = results_tree.create_item()
		tree_root.set_text(0, "Project Results")
		tree_root.set_selectable(0, false)
	
	var file_item = results_tree.create_item(tree_root)
	file_item.set_text(0, file_path.get_file())
	file_item.set_text(1, str(cc))
	file_item.set_text(2, str(cog))
	file_item.set_text(3, "%.2f" % confidence)
	file_item.set_text(4, str(nesting))
	file_item.set_text(5, str(params))
	file_item.set_text(6, str(loc))
	file_item.set_metadata(0, {"script_path": file_path, "line": 1})
	_align_numeric_columns(file_item)
	file_item.set_selectable(0, true)
	
	return file_item

func add_function_result(parent_item: TreeItem, func_name: String, cc: int, cog: int, script_path: String, line: int):
	if results_tree == null or parent_item == null:
		return null
	
	var func_item = results_tree.create_item(parent_item)
	func_item.set_text(0, "  %s()" % func_name)
	func_item.set_text(1, str(cc))
	func_item.set_text(2, str(cog))
	func_item.set_text(3, "-")
	func_item.set_text(4, "-")
	func_item.set_text(5, "-")
	func_item.set_text(6, "-")
	func_item.set_metadata(0, {"script_path": script_path, "line": max(line, 1)})
	_align_numeric_columns(func_item)
	func_item.set_selectable(0, true)
	
	return func_item

func _get_selected_target():
	if results_tree == null:
		return null
	var item = results_tree.get_selected()
	if item == null:
		return null
	var data = item.get_metadata(0)
	if typeof(data) == TYPE_DICTIONARY and data.has("script_path"):
		return data
	return null

func _align_numeric_columns(item: TreeItem):
	if item == null:
		return
	if item.has_method("set_text_alignment"):
		for col in range(1, 7):
			item.call("set_text_alignment", col, HORIZONTAL_ALIGNMENT_RIGHT)

func set_analyze_button_enabled(enabled: bool):
	if analyze_button != null:
		analyze_button.disabled = not enabled

func set_cancel_button_enabled(enabled: bool):
	if cancel_button != null:
		cancel_button.disabled = not enabled
