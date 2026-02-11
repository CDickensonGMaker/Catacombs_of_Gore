## world_map.gd - Grid-based world map using WorldData
## Displays player position on the world grid with discovered/undiscovered cells
class_name WorldMap
extends Control

signal fast_travel_requested(zone_id: String, spawn_id: String)
signal location_selected(zone_id: String)

## Map settings
const DEFAULT_SIZE := Vector2(550, 400)
const CELL_SIZE := 50  ## Pixels per grid cell
const MAP_PADDING := 20

## Get color for biome
static func get_biome_color(biome: int) -> Color:
	match biome:
		WorldData.Biome.FOREST: return Color(0.2, 0.45, 0.2)
		WorldData.Biome.PLAINS: return Color(0.5, 0.55, 0.3)
		WorldData.Biome.SWAMP: return Color(0.25, 0.35, 0.3)
		WorldData.Biome.HILLS: return Color(0.45, 0.4, 0.3)
		WorldData.Biome.ROCKY: return Color(0.4, 0.38, 0.35)
		WorldData.Biome.MOUNTAINS: return Color(0.35, 0.35, 0.4)
		WorldData.Biome.COAST: return Color(0.3, 0.45, 0.55)
		WorldData.Biome.UNDEAD: return Color(0.3, 0.25, 0.35)
		WorldData.Biome.HORDE: return Color(0.45, 0.3, 0.25)
		_: return Color(0.3, 0.3, 0.3)


## Get color for location type (for icons)
static func get_location_color(loc_type: int) -> Color:
	match loc_type:
		WorldData.LocationType.NONE: return Color(0.5, 0.5, 0.5)
		WorldData.LocationType.VILLAGE: return Color(0.4, 0.7, 0.3)
		WorldData.LocationType.TOWN: return Color(0.5, 0.6, 0.8)
		WorldData.LocationType.CITY: return Color(0.7, 0.6, 0.4)
		WorldData.LocationType.CAPITAL: return Color(0.9, 0.75, 0.3)
		WorldData.LocationType.DUNGEON: return Color(0.6, 0.3, 0.5)
		WorldData.LocationType.LANDMARK: return Color(0.6, 0.55, 0.4)
		WorldData.LocationType.BRIDGE: return Color(0.5, 0.45, 0.4)
		_: return Color(0.5, 0.5, 0.5)

## Colors
const COLOR_BG := Color(0.08, 0.06, 0.1, 0.95)
const COLOR_BORDER := Color(0.3, 0.25, 0.2)
const COLOR_TEXT := Color(0.9, 0.85, 0.75)
const COLOR_DIM := Color(0.5, 0.5, 0.5)
const COLOR_GOLD := Color(0.8, 0.6, 0.2)
const COLOR_UNDISCOVERED := Color(0.15, 0.15, 0.18, 0.8)
const COLOR_CURRENT := Color(0.4, 1.0, 0.4)
const COLOR_SELECTED := Color(1.0, 0.9, 0.5)
const COLOR_IMPASSABLE := Color(0.2, 0.2, 0.25, 0.9)

## Road colors based on danger level
const COLOR_ROAD_SAFE := Color(0.7, 0.6, 0.4, 0.9)        # Low danger - tan/brown
const COLOR_ROAD_NORMAL := Color(0.6, 0.5, 0.35, 0.85)    # Medium danger - slightly darker
const COLOR_ROAD_DANGEROUS := Color(0.5, 0.35, 0.3, 0.8)  # High danger - reddish-brown
const ROAD_LINE_WIDTH := 2.0

## Components
var background: ColorRect
var map_canvas: Control
var grid_container: Control
var title_label: Label
var region_label: Label
var coords_label: Label
var cell_buttons: Dictionary = {}  # Vector2i -> Button
var selected_cell: Vector2i = Vector2i(999, 999)  # Invalid sentinel

## Travel confirmation dialog
var travel_dialog: PanelContainer
var travel_location_label: Label
var travel_confirm_btn: Button
var travel_cancel_btn: Button

## Tooltip
var tooltip_panel: PanelContainer
var tooltip_label: Label

## Map scrolling
var scroll_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO

## Road data loaded from hex_map_data.json
var road_data: Array = []  # Array of road dictionaries
var min_coords: Vector2i = Vector2i.ZERO
var max_coords: Vector2i = Vector2i.ZERO


func _ready() -> void:
	custom_minimum_size = DEFAULT_SIZE
	size = DEFAULT_SIZE
	clip_contents = true

	# Initialize WorldData if needed
	if WorldData.world_grid.is_empty():
		WorldData.initialize()

	_load_road_data()
	_setup_ui()
	_create_grid_cells()
	_center_on_player()


func _setup_ui() -> void:
	# Background
	background = ColorRect.new()
	background.name = "Background"
	background.color = COLOR_BG
	background.set_anchors_preset(PRESET_FULL_RECT)
	add_child(background)

	# Border
	var border := ColorRect.new()
	border.name = "Border"
	border.color = COLOR_BORDER
	border.set_anchors_preset(PRESET_FULL_RECT)
	border.offset_left = -2
	border.offset_top = -2
	border.offset_right = 2
	border.offset_bottom = 2
	border.z_index = -1
	add_child(border)

	# Title
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "WORLD MAP - Holy State of Cigis"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", COLOR_GOLD)
	title_label.set_anchors_preset(PRESET_TOP_WIDE)
	title_label.offset_top = 4
	title_label.offset_bottom = 22
	add_child(title_label)

	# Region label
	region_label = Label.new()
	region_label.name = "RegionLabel"
	region_label.text = ""
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	region_label.add_theme_color_override("font_color", COLOR_TEXT)
	region_label.position = Vector2(10, 24)
	add_child(region_label)

	# Coordinates label
	coords_label = Label.new()
	coords_label.name = "CoordsLabel"
	coords_label.text = ""
	coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coords_label.add_theme_color_override("font_color", COLOR_DIM)
	coords_label.set_anchors_preset(PRESET_TOP_RIGHT)
	coords_label.offset_top = 24
	coords_label.offset_right = -10
	coords_label.offset_left = -100
	add_child(coords_label)

	# Grid container (will be scrollable)
	grid_container = Control.new()
	grid_container.name = "GridContainer"
	grid_container.set_anchors_preset(PRESET_FULL_RECT)
	grid_container.offset_top = 44
	grid_container.offset_bottom = -40
	grid_container.clip_contents = true
	add_child(grid_container)

	# Map canvas for drawing grid lines and current indicator
	map_canvas = Control.new()
	map_canvas.name = "MapCanvas"
	map_canvas.set_anchors_preset(PRESET_FULL_RECT)
	map_canvas.draw.connect(_draw_map)
	grid_container.add_child(map_canvas)

	# Tooltip
	_setup_tooltip()

	# Travel dialog
	_setup_travel_dialog()

	# Instructions label at bottom
	var instructions := Label.new()
	instructions.name = "Instructions"
	instructions.text = "Click discovered locations to fast travel (Shrines only)"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_color_override("font_color", COLOR_DIM)
	instructions.set_anchors_preset(PRESET_BOTTOM_WIDE)
	instructions.offset_bottom = -10
	instructions.offset_top = -30
	add_child(instructions)


func _create_grid_cells() -> void:
	# Clear existing cells
	for btn in cell_buttons.values():
		if is_instance_valid(btn):
			btn.queue_free()
	cell_buttons.clear()

	# Get world bounds
	var bounds: Dictionary = WorldData.get_world_bounds()
	var min_coords: Vector2i = bounds.min
	var max_coords: Vector2i = bounds.max

	# Create a button for each cell in the world grid
	for y in range(max_coords.y, min_coords.y - 1, -1):  # Y goes from top (max) to bottom (min)
		for x in range(min_coords.x, max_coords.x + 1):
			var coords := Vector2i(x, y)
			var cell: WorldData.CellData = WorldData.get_cell(coords)

			var btn := Button.new()
			btn.name = "Cell_%d_%d" % [x, y]
			btn.custom_minimum_size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
			btn.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)

			# Position based on grid coordinates
			# X increases right, Y increases up in world but down on screen
			var grid_x := (x - min_coords.x) * CELL_SIZE
			var grid_y := (max_coords.y - y) * CELL_SIZE
			btn.position = Vector2(grid_x + 1, grid_y + 1)

			# Style based on discovery and cell type
			_style_cell_button(btn, coords, cell)

			# Connect signals
			btn.pressed.connect(_on_cell_clicked.bind(coords))
			btn.mouse_entered.connect(_on_cell_hover_entered.bind(coords, btn))
			btn.mouse_exited.connect(_on_cell_hover_exited)

			map_canvas.add_child(btn)
			cell_buttons[coords] = btn

	# Set canvas size to fit all cells
	var grid_width := (max_coords.x - min_coords.x + 1) * CELL_SIZE
	var grid_height := (max_coords.y - min_coords.y + 1) * CELL_SIZE
	map_canvas.custom_minimum_size = Vector2(grid_width, grid_height)


func _style_cell_button(btn: Button, coords: Vector2i, cell: WorldData.CellData) -> void:
	var is_discovered := cell != null and cell.discovered
	var is_current := _is_current_cell(coords)
	var is_passable := cell == null or cell.is_passable
	var is_dev := SceneManager and SceneManager.dev_mode

	# In dev mode, show all location icons
	var show_icon := is_discovered or is_dev

	# Button text/icon based on location type
	if cell and show_icon:
		btn.text = _get_location_icon(cell.location_type)
	elif cell and not is_passable:
		btn.text = "^"  # Mountain/impassable
	else:
		btn.text = ""

	# Create styles
	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()
	var pressed := StyleBoxFlat.new()

	var base_color: Color
	if not is_discovered and cell:
		if not is_passable:
			base_color = COLOR_IMPASSABLE
		else:
			base_color = COLOR_UNDISCOVERED
	elif is_current:
		base_color = COLOR_CURRENT
	elif selected_cell == coords:
		base_color = COLOR_SELECTED
	elif cell:
		base_color = get_biome_color(cell.biome)
	else:
		base_color = COLOR_UNDISCOVERED

	normal.bg_color = base_color
	normal.set_corner_radius_all(2)
	normal.border_color = COLOR_BORDER.darkened(0.3)
	normal.set_border_width_all(1)

	hover.bg_color = base_color.lightened(0.15)
	hover.set_corner_radius_all(2)
	hover.border_color = COLOR_GOLD
	hover.set_border_width_all(1)

	pressed.bg_color = base_color.darkened(0.15)
	pressed.set_corner_radius_all(2)
	pressed.border_color = COLOR_GOLD
	pressed.set_border_width_all(1)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

	# Text color based on location type
	var text_color := COLOR_TEXT
	if cell and cell.location_type != WorldData.LocationType.NONE:
		text_color = get_location_color(cell.location_type)
	btn.add_theme_color_override("font_color", text_color if is_discovered else COLOR_DIM)


func _get_location_icon(loc_type: int) -> String:
	match loc_type:
		WorldData.LocationType.CAPITAL:
			return "*"
		WorldData.LocationType.CITY:
			return "C"
		WorldData.LocationType.TOWN:
			return "T"
		WorldData.LocationType.VILLAGE:
			return "v"
		WorldData.LocationType.DUNGEON:
			return "X"
		WorldData.LocationType.LANDMARK:
			return "!"
		WorldData.LocationType.BRIDGE:
			return "="
		_:
			return ""


func _setup_tooltip() -> void:
	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "Tooltip"
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.z_index = 100

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	tooltip_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	tooltip_panel.add_child(vbox)

	tooltip_label = Label.new()
	tooltip_label.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(tooltip_label)

	add_child(tooltip_panel)


func _setup_travel_dialog() -> void:
	travel_dialog = PanelContainer.new()
	travel_dialog.name = "TravelDialog"
	travel_dialog.visible = false
	travel_dialog.z_index = 200

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.98)
	style.border_color = COLOR_GOLD
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	travel_dialog.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	travel_dialog.add_child(vbox)

	var title := Label.new()
	title.text = "Fast Travel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(title)

	travel_location_label = Label.new()
	travel_location_label.text = "Travel to ?"
	travel_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	travel_location_label.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(travel_location_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	travel_confirm_btn = Button.new()
	travel_confirm_btn.text = "Travel"
	travel_confirm_btn.custom_minimum_size = Vector2(80, 30)
	travel_confirm_btn.pressed.connect(_on_travel_confirmed)
	_style_dialog_button(travel_confirm_btn, true)
	btn_row.add_child(travel_confirm_btn)

	travel_cancel_btn = Button.new()
	travel_cancel_btn.text = "Cancel"
	travel_cancel_btn.custom_minimum_size = Vector2(80, 30)
	travel_cancel_btn.pressed.connect(_on_travel_cancelled)
	_style_dialog_button(travel_cancel_btn, false)
	btn_row.add_child(travel_cancel_btn)

	# Center the dialog
	travel_dialog.set_anchors_preset(PRESET_CENTER)
	travel_dialog.offset_left = -100
	travel_dialog.offset_right = 100
	travel_dialog.offset_top = -50
	travel_dialog.offset_bottom = 50

	add_child(travel_dialog)


func _style_dialog_button(btn: Button, is_primary: bool) -> void:
	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()

	if is_primary:
		normal.bg_color = Color(0.2, 0.4, 0.3)
		hover.bg_color = Color(0.25, 0.5, 0.35)
	else:
		normal.bg_color = Color(0.2, 0.2, 0.25)
		hover.bg_color = Color(0.3, 0.3, 0.35)

	normal.border_color = COLOR_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)

	hover.border_color = COLOR_GOLD
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", COLOR_TEXT)


func _draw_map() -> void:
	# Draw roads first (under everything)
	_draw_roads()
	# Draw current cell indicator (pulsing border)
	_draw_current_indicator()


## Load road data from hex_map_data.json
func _load_road_data() -> void:
	var file_path := "res://data/world/hex_map_data.json"
	if not FileAccess.file_exists(file_path):
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json: Variant = JSON.parse_string(json_text)
	if not json is Dictionary:
		return

	var hex_data: Dictionary = json as Dictionary
	if hex_data.has("roads"):
		road_data = hex_data["roads"]
		print("[WorldMap] Loaded %d roads" % road_data.size())


## Draw roads on the map
func _draw_roads() -> void:
	if road_data.is_empty():
		return

	# Get world bounds for coordinate conversion
	var bounds: Dictionary = WorldData.get_world_bounds()
	min_coords = bounds.min
	max_coords = bounds.max

	for road: Dictionary in road_data:
		_draw_single_road(road)


## Draw a single road
func _draw_single_road(road: Dictionary) -> void:
	var hexes: Array = road.get("hexes", [])
	if hexes.size() < 2:
		return

	# Determine road color based on danger level
	var danger_level: float = road.get("danger_level", 1.0)
	var road_color: Color = _get_road_color(danger_level)

	# Draw line segments between consecutive hexes
	for i in range(hexes.size() - 1):
		var from_hex: Array = hexes[i]
		var to_hex: Array = hexes[i + 1]

		var from_coords := Vector2i(int(from_hex[0]), int(from_hex[1]))
		var to_coords := Vector2i(int(to_hex[0]), int(to_hex[1]))

		# Only draw if at least one end is discovered (or dev mode)
		var is_dev: bool = SceneManager and SceneManager.dev_mode
		var from_discovered: bool = WorldData.is_discovered(from_coords)
		var to_discovered: bool = WorldData.is_discovered(to_coords)

		if not is_dev and not from_discovered and not to_discovered:
			continue

		# Convert hex coordinates to screen position
		var from_pos: Vector2 = _hex_to_screen_pos(from_coords)
		var to_pos: Vector2 = _hex_to_screen_pos(to_coords)

		# Fade undiscovered sections (unless dev mode)
		var draw_color: Color = road_color
		if not is_dev and (not from_discovered or not to_discovered):
			draw_color.a *= 0.4

		# Draw road segment
		map_canvas.draw_line(from_pos, to_pos, draw_color, ROAD_LINE_WIDTH, true)


## Get road color based on danger level
func _get_road_color(danger_level: float) -> Color:
	if danger_level < 0.9:
		return COLOR_ROAD_SAFE
	elif danger_level > 1.3:
		return COLOR_ROAD_DANGEROUS
	return COLOR_ROAD_NORMAL


## Convert hex coordinates to screen position
func _hex_to_screen_pos(hex: Vector2i) -> Vector2:
	# Convert from hex coords to grid position
	# X increases right, Y increases up in world but down on screen
	var grid_x: float = (hex.x - min_coords.x) * CELL_SIZE + CELL_SIZE / 2.0
	var grid_y: float = (max_coords.y - hex.y) * CELL_SIZE + CELL_SIZE / 2.0
	return Vector2(grid_x, grid_y)


func _draw_current_indicator() -> void:
	var current_coords := _get_current_cell()
	if not cell_buttons.has(current_coords):
		return

	var btn: Button = cell_buttons[current_coords]
	var pos := btn.position
	var btn_size := btn.size

	# Draw pulsing border around current cell
	var pulse := (sin(Time.get_ticks_msec() * 0.005) + 1.0) / 2.0
	var border_color := COLOR_CURRENT
	border_color.a = 0.7 + pulse * 0.3
	var border_width := 2.0 + pulse * 1.0

	# Draw border rect
	var rect := Rect2(pos - Vector2(1, 1), btn_size + Vector2(2, 2))
	map_canvas.draw_rect(rect, border_color, false, border_width)


func _is_current_cell(coords: Vector2i) -> bool:
	return coords == _get_current_cell()


func _get_current_cell() -> Vector2i:
	# Check if in wilderness (use SceneManager coords)
	if SceneManager and SceneManager.is_in_wilderness():
		return SceneManager.get_current_room_coords()
	# If in Elder Moor or other scene, return (0,0)
	return Vector2i.ZERO


func _on_cell_clicked(coords: Vector2i) -> void:
	var cell: WorldData.CellData = WorldData.get_cell(coords)
	if not cell:
		return

	# Dev mode allows travel to any location
	var is_dev := SceneManager and SceneManager.dev_mode

	# Can't interact with undiscovered cells (unless dev mode)
	if not cell.discovered and not is_dev:
		return

	# Can't travel to current cell
	if _is_current_cell(coords):
		return

	# Can only fast travel to locations (not empty wilderness)
	if cell.location_type == WorldData.LocationType.NONE:
		return

	selected_cell = coords
	location_selected.emit(cell.location_id)

	# Show travel dialog
	_show_travel_dialog_for_cell(coords, cell)

	# Refresh button styles
	_refresh_cell_styles()


func _show_travel_dialog_for_cell(coords: Vector2i, cell: WorldData.CellData) -> void:
	var loc_name := cell.location_name if cell.location_name else "(%d, %d)" % [coords.x, coords.y]

	travel_location_label.text = "Travel to %s?" % loc_name
	travel_dialog.visible = true


func _on_travel_confirmed() -> void:
	if selected_cell == Vector2i(999, 999):
		travel_dialog.visible = false
		return

	var cell := WorldData.get_cell(selected_cell)
	if not cell or cell.location_id.is_empty():
		travel_dialog.visible = false
		return

	travel_dialog.visible = false

	# Use SceneManager's dev fast travel
	if SceneManager:
		SceneManager.dev_fast_travel_to(cell.location_id)

	# Also emit signal for parent to close menu
	fast_travel_requested.emit(cell.location_id, "from_fast_travel")


func _on_travel_cancelled() -> void:
	travel_dialog.visible = false
	selected_cell = Vector2i(999, 999)
	_refresh_cell_styles()


func _on_cell_hover_entered(coords: Vector2i, btn: Button) -> void:
	var cell: WorldData.CellData = WorldData.get_cell(coords)
	var is_discovered := cell != null and cell.discovered
	var is_current := _is_current_cell(coords)

	var tooltip_text := ""
	if is_discovered and cell:
		if cell.location_name:
			tooltip_text = cell.location_name
		else:
			tooltip_text = WorldData.Biome.keys()[cell.biome].capitalize()
		tooltip_text += "\n" + cell.region_name
		if is_current:
			tooltip_text += "\n(Current Location)"
	elif cell and not cell.is_passable:
		tooltip_text = "Impassable Terrain"
	else:
		tooltip_text = "Undiscovered"

	# Add coordinates
	tooltip_text += "\n(%d, %d)" % [coords.x, coords.y]

	tooltip_label.text = tooltip_text
	tooltip_panel.visible = true
	tooltip_panel.reset_size()

	# Position near button (relative to grid_container, but tooltip is child of main control)
	var btn_global := btn.global_position
	var my_global := global_position
	var btn_pos := btn_global - my_global + btn.size / 2

	var tooltip_pos := btn_pos + Vector2(15, -tooltip_panel.size.y / 2)

	# Keep on screen
	if tooltip_pos.x + tooltip_panel.size.x > size.x:
		tooltip_pos.x = btn_pos.x - tooltip_panel.size.x - 15
	if tooltip_pos.y < 0:
		tooltip_pos.y = 5
	if tooltip_pos.y + tooltip_panel.size.y > size.y:
		tooltip_pos.y = size.y - tooltip_panel.size.y - 5

	tooltip_panel.position = tooltip_pos

	# Update info labels
	if cell and is_discovered:
		region_label.text = cell.region_name
	else:
		region_label.text = ""
	coords_label.text = "(%d, %d)" % [coords.x, coords.y]


func _on_cell_hover_exited() -> void:
	tooltip_panel.visible = false


func _refresh_cell_styles() -> void:
	for coords: Vector2i in cell_buttons:
		var btn: Button = cell_buttons[coords]
		var cell: WorldData.CellData = WorldData.get_cell(coords)
		if is_instance_valid(btn):
			_style_cell_button(btn, coords, cell)


func _center_on_player() -> void:
	var current := _get_current_cell()
	if not cell_buttons.has(current):
		return

	var btn: Button = cell_buttons[current]
	var center := grid_container.size / 2.0
	var btn_center := btn.position + btn.size / 2.0

	# Calculate scroll offset to center current cell
	scroll_offset = btn_center - center
	map_canvas.position = -scroll_offset


func _process(_delta: float) -> void:
	if visible:
		map_canvas.queue_redraw()
		_update_info_labels()


func _update_info_labels() -> void:
	var current := _get_current_cell()
	var cell := WorldData.get_cell(current)
	if cell:
		if cell.location_name:
			region_label.text = cell.location_name + " - " + cell.region_name
		else:
			region_label.text = cell.region_name
	coords_label.text = "(%d, %d)" % [current.x, current.y]


## Refresh the map display
func refresh() -> void:
	_create_grid_cells()
	_center_on_player()
	map_canvas.queue_redraw()


## Get scene path for a location
func get_scene_path(location_id: String) -> String:
	# Look up location in world data
	for coords: Vector2i in WorldData.world_grid:
		var cell: WorldData.CellData = WorldData.world_grid[coords]
		if cell.location_id == location_id:
			# Return scene path based on location type
			match location_id:
				"village_elder_moor":
					return "res://scenes/levels/elder_moor.tscn"
				"dungeon_willow_dale":
					return "res://scenes/levels/willow_dale.tscn"
				# Add more mappings as scenes are created
				_:
					return ""
	return ""
