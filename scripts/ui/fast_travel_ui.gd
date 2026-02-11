## fast_travel_ui.gd - Popup UI for fast travel destination selection
## Shows all discovered locations (or all in dev mode)
## Opens when interacting with FastTravelShrine
class_name FastTravelUI
extends CanvasLayer

signal destination_selected(location_id: String)
signal ui_closed

## Colors
const COL_BG := Color(0.1, 0.1, 0.12, 0.95)
const COL_HEADER := Color(0.9, 0.85, 0.7)
const COL_TEXT := Color(0.8, 0.78, 0.7)
const COL_HIGHLIGHT := Color(0.4, 0.7, 1.0)
const COL_BUTTON := Color(0.2, 0.22, 0.25)
const COL_BUTTON_HOVER := Color(0.3, 0.35, 0.4)
const COL_CURRENT := Color(0.5, 0.5, 0.5)

## UI components
var panel: PanelContainer
var title_label: Label
var location_list: VBoxContainer
var scroll_container: ScrollContainer
var close_button: Button
var current_location_label: Label

## State
var is_open: bool = false
var current_zone_id: String = ""
var selected_index: int = -1
var location_buttons: Array[Button] = []
var previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 90  # High but below pause menu
	process_mode = Node.PROCESS_MODE_ALWAYS  # Process even when paused
	_create_ui()
	hide_ui()


func _create_ui() -> void:
	# Dark overlay to dim background
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Main panel - centered
	panel = PanelContainer.new()
	panel.name = "FastTravelPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 450)
	panel.size = Vector2(400, 450)
	panel.position = Vector2(-200, -225)  # Center offset

	var style := StyleBoxFlat.new()
	style.bg_color = COL_BG
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = COL_HIGHLIGHT
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	add_child(panel)

	# Main container
	var vbox := VBoxContainer.new()
	vbox.name = "MainContainer"
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Margin container for padding
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	vbox.add_child(margin)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(inner_vbox)

	# Title
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "FAST TRAVEL"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", COL_HEADER)
	title_label.add_theme_font_size_override("font_size", 24)
	inner_vbox.add_child(title_label)

	# Current location display
	current_location_label = Label.new()
	current_location_label.name = "CurrentLocation"
	current_location_label.text = "Current: Unknown"
	current_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_location_label.add_theme_color_override("font_color", COL_TEXT)
	current_location_label.add_theme_font_size_override("font_size", 14)
	inner_vbox.add_child(current_location_label)

	# Separator
	var sep := HSeparator.new()
	inner_vbox.add_child(sep)

	# Instruction label
	var instruction := Label.new()
	instruction.text = "Select a destination:"
	instruction.add_theme_color_override("font_color", COL_TEXT)
	instruction.add_theme_font_size_override("font_size", 14)
	inner_vbox.add_child(instruction)

	# Scroll container for location list
	scroll_container = ScrollContainer.new()
	scroll_container.name = "ScrollContainer"
	scroll_container.custom_minimum_size = Vector2(0, 280)
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	inner_vbox.add_child(scroll_container)

	# Location list container
	location_list = VBoxContainer.new()
	location_list.name = "LocationList"
	location_list.add_theme_constant_override("separation", 4)
	location_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(location_list)

	# Close button at bottom
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Cancel (ESC)"
	close_button.custom_minimum_size = Vector2(0, 35)
	close_button.pressed.connect(_on_close_pressed)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = COL_BUTTON
	btn_style.corner_radius_top_left = 3
	btn_style.corner_radius_top_right = 3
	btn_style.corner_radius_bottom_left = 3
	btn_style.corner_radius_bottom_right = 3
	close_button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = COL_BUTTON_HOVER
	btn_hover.corner_radius_top_left = 3
	btn_hover.corner_radius_top_right = 3
	btn_hover.corner_radius_bottom_left = 3
	btn_hover.corner_radius_bottom_right = 3
	close_button.add_theme_stylebox_override("hover", btn_hover)

	inner_vbox.add_child(close_button)


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	# Check for ESC key directly as backup
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			print("[FastTravelUI] ESC pressed - closing")
			hide_ui()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		hide_ui()
		get_viewport().set_input_as_handled()
		return

	# Mouse wheel scrolling
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll_container.scroll_vertical -= 40
				get_viewport().set_input_as_handled()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll_container.scroll_vertical += 40
				get_viewport().set_input_as_handled()

	# Keyboard navigation
	if event.is_action_pressed("ui_down"):
		_navigate_list(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_navigate_list(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		if selected_index >= 0 and selected_index < location_buttons.size():
			_on_location_selected(selected_index)
			get_viewport().set_input_as_handled()


func _navigate_list(direction: int) -> void:
	if location_buttons.is_empty():
		return

	# Find next valid (non-disabled) button
	var start_index: int = selected_index
	var attempts: int = 0

	selected_index += direction
	while attempts < location_buttons.size():
		if selected_index < 0:
			selected_index = location_buttons.size() - 1
		elif selected_index >= location_buttons.size():
			selected_index = 0

		if not location_buttons[selected_index].disabled:
			break

		selected_index += direction
		attempts += 1

	_update_selection_visual()


func _update_selection_visual() -> void:
	for i in range(location_buttons.size()):
		var btn: Button = location_buttons[i]
		if i == selected_index and not btn.disabled:
			btn.grab_focus()


## Show the fast travel UI
func show_ui(zone_id: String = "") -> void:
	current_zone_id = zone_id
	is_open = true
	visible = true

	# Show mouse cursor
	previous_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Get current location name
	var current_name := "Unknown"
	if not zone_id.is_empty():
		current_name = WorldManager.get_location_name(zone_id)
		if current_name == "Unknown Location":
			current_name = zone_id.replace("_", " ").capitalize()
	elif SceneManager:
		var coords: Vector2i = SceneManager.get_current_room_coords()
		current_name = WorldData.get_cell_name(coords)

	current_location_label.text = "Current: " + current_name

	_populate_location_list()

	# Pause game
	get_tree().paused = true

	# Focus first button
	if location_buttons.size() > 0:
		selected_index = 0
		# Skip to first non-disabled button
		while selected_index < location_buttons.size() and location_buttons[selected_index].disabled:
			selected_index += 1
		if selected_index < location_buttons.size():
			location_buttons[selected_index].grab_focus()


## Hide the fast travel UI
func hide_ui() -> void:
	is_open = false
	visible = false
	get_tree().paused = false

	# Restore mouse mode
	Input.set_mouse_mode(previous_mouse_mode)

	ui_closed.emit()


## Populate the location list with available destinations
func _populate_location_list() -> void:
	# Clear existing
	for child in location_list.get_children():
		child.queue_free()
	location_buttons.clear()
	selected_index = -1

	# Get all locations - in dev mode show all, otherwise only discovered
	var locations: Array[Dictionary] = SceneManager.get_fast_travel_locations()

	# Sort by name
	locations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.location_name < b.location_name
	)

	if locations.is_empty():
		var no_locations := Label.new()
		no_locations.text = "No locations available."
		no_locations.add_theme_color_override("font_color", COL_TEXT)
		location_list.add_child(no_locations)
		return

	for i in range(locations.size()):
		var loc: Dictionary = locations[i]
		var btn := _create_location_button(loc, i)
		location_list.add_child(btn)
		location_buttons.append(btn)


## Create a button for a location
func _create_location_button(loc: Dictionary, index: int) -> Button:
	var btn := Button.new()
	btn.name = "Location_%d" % index

	# Build button text
	var loc_type_name := _get_location_type_name(loc.location_type)
	btn.text = "%s (%s)" % [loc.location_name, loc_type_name]

	# Check if this is current location
	var is_current: bool = loc.location_id == current_zone_id
	if is_current:
		btn.text += " [HERE]"
		btn.disabled = true

	btn.custom_minimum_size = Vector2(0, 32)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Store location data
	btn.set_meta("location_id", loc.location_id)
	btn.set_meta("index", index)

	# Button styling
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = COL_BUTTON
	normal_style.corner_radius_top_left = 2
	normal_style.corner_radius_top_right = 2
	normal_style.corner_radius_bottom_left = 2
	normal_style.corner_radius_bottom_right = 2
	normal_style.content_margin_left = 10
	normal_style.content_margin_right = 10

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = COL_BUTTON_HOVER
	hover_style.corner_radius_top_left = 2
	hover_style.corner_radius_top_right = 2
	hover_style.corner_radius_bottom_left = 2
	hover_style.corner_radius_bottom_right = 2
	hover_style.content_margin_left = 10
	hover_style.content_margin_right = 10

	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = COL_HIGHLIGHT.darkened(0.5)
	focus_style.border_color = COL_HIGHLIGHT
	focus_style.border_width_left = 2
	focus_style.border_width_right = 2
	focus_style.border_width_top = 2
	focus_style.border_width_bottom = 2
	focus_style.corner_radius_top_left = 2
	focus_style.corner_radius_top_right = 2
	focus_style.corner_radius_bottom_left = 2
	focus_style.corner_radius_bottom_right = 2
	focus_style.content_margin_left = 8
	focus_style.content_margin_right = 8

	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = COL_CURRENT
	disabled_style.corner_radius_top_left = 2
	disabled_style.corner_radius_top_right = 2
	disabled_style.corner_radius_bottom_left = 2
	disabled_style.corner_radius_bottom_right = 2
	disabled_style.content_margin_left = 10
	disabled_style.content_margin_right = 10

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("focus", focus_style)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6))

	btn.pressed.connect(_on_location_selected.bind(index))

	return btn


## Handle location selection
func _on_location_selected(index: int) -> void:
	if index < 0 or index >= location_buttons.size():
		return

	var btn: Button = location_buttons[index]
	if btn.disabled:
		return

	var location_id: String = btn.get_meta("location_id")
	print("[FastTravelUI] Selected destination: %s" % location_id)

	destination_selected.emit(location_id)

	# Hide UI first, then start the travel coroutine
	hide_ui()

	# Start travel as a coroutine
	_execute_travel(location_id)


## Execute the actual travel (async)
func _execute_travel(location_id: String) -> void:
	print("[FastTravelUI] Executing travel to: %s" % location_id)

	if SceneManager:
		print("[FastTravelUI] Calling SceneManager.dev_fast_travel_to()")
		await SceneManager.dev_fast_travel_to(location_id)
		print("[FastTravelUI] Travel complete")
	else:
		print("[FastTravelUI] ERROR: SceneManager not found!")


## Handle close button
func _on_close_pressed() -> void:
	hide_ui()


## Get human-readable location type name
func _get_location_type_name(loc_type: int) -> String:
	match loc_type:
		WorldData.LocationType.VILLAGE: return "Village"
		WorldData.LocationType.TOWN: return "Town"
		WorldData.LocationType.CITY: return "City"
		WorldData.LocationType.CAPITAL: return "Capital"
		WorldData.LocationType.DUNGEON: return "Dungeon"
		WorldData.LocationType.LANDMARK: return "Landmark"
		WorldData.LocationType.BRIDGE: return "Bridge"
		WorldData.LocationType.OUTPOST: return "Outpost"
		_: return "Location"


## Static factory for spawning the UI
static func get_or_create() -> FastTravelUI:
	# Check if already exists in scene tree
	var existing := Engine.get_main_loop().root.get_node_or_null("FastTravelUI") as FastTravelUI
	if existing:
		return existing

	# Create new instance
	var ui := FastTravelUI.new()
	ui.name = "FastTravelUI"
	Engine.get_main_loop().root.add_child(ui)
	return ui
