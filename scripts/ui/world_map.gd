## world_map.gd - Grid-based world map using WorldData
## Displays 17x17 grid with terrain colors, player position, fog of war
## Skyrim/Fallout-style world map for the tab menu
class_name WorldMap
extends Control

signal fast_travel_requested(zone_id: String, spawn_id: String)
signal location_selected(zone_id: String)

## Map settings
const CELL_SIZE := 28  ## Pixels per grid cell
const MAP_PADDING := 10
const PLAYER_ICON_SIZE := 12.0

## Colors
const COLOR_BG := Color(0.05, 0.04, 0.06, 0.98)
const COLOR_BORDER := Color(0.4, 0.35, 0.25)
const COLOR_TEXT := Color(0.9, 0.85, 0.75)
const COLOR_DIM := Color(0.5, 0.5, 0.5)
const COLOR_GOLD := Color(0.85, 0.7, 0.3)
const COLOR_FOG := Color(0.08, 0.08, 0.1, 0.92)
const COLOR_PLAYER := Color(0.2, 0.9, 0.4)
const COLOR_PLAYER_GLOW := Color(0.4, 1.0, 0.6, 0.5)
const COLOR_ROAD := Color(0.55, 0.45, 0.35, 0.9)
const COLOR_SELECTED := Color(1.0, 0.9, 0.5, 0.8)

## Location icon colors
const COLOR_TOWN := Color(0.7, 0.6, 0.4)
const COLOR_DUNGEON := Color(0.7, 0.3, 0.3)
const COLOR_LANDMARK := Color(0.6, 0.7, 0.5)

## Components
var background: ColorRect
var map_canvas: Control
var title_label: Label
var location_label: Label
var coords_label: Label
var tooltip_panel: PanelContainer
var tooltip_label: Label

## Travel dialog
var travel_dialog: PanelContainer
var travel_location_label: Label
var travel_confirm_btn: Button
var travel_cancel_btn: Button

## State
var selected_cell: Vector2i = Vector2i(-1, -1)
var hovered_cell: Vector2i = Vector2i(-1, -1)
var player_coords: Vector2i = Vector2i(7, 4)  # Default to Elder Moor

## Cached grid data
var grid_size: Vector2
var grid_offset: Vector2


func _ready() -> void:
	# Calculate sizes
	grid_size = Vector2(WorldData.GRID_COLS * CELL_SIZE, WorldData.GRID_ROWS * CELL_SIZE)
	custom_minimum_size = grid_size + Vector2(MAP_PADDING * 2, MAP_PADDING * 2 + 60)

	# Initialize WorldData
	if WorldData.world_grid.is_empty():
		WorldData.initialize()

	_setup_ui()
	_update_player_position()


func _setup_ui() -> void:
	# Background with border
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

	background = ColorRect.new()
	background.name = "Background"
	background.color = COLOR_BG
	background.set_anchors_preset(PRESET_FULL_RECT)
	add_child(background)

	# Title
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "WORLD MAP"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", COLOR_GOLD)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.set_anchors_preset(PRESET_TOP_WIDE)
	title_label.offset_top = 6
	title_label.offset_bottom = 26
	add_child(title_label)

	# Location label (current location name)
	location_label = Label.new()
	location_label.name = "LocationLabel"
	location_label.text = ""
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	location_label.add_theme_color_override("font_color", COLOR_TEXT)
	location_label.add_theme_font_size_override("font_size", 12)
	location_label.position = Vector2(MAP_PADDING, 28)
	add_child(location_label)

	# Coordinates label
	coords_label = Label.new()
	coords_label.name = "CoordsLabel"
	coords_label.text = ""
	coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coords_label.add_theme_color_override("font_color", COLOR_DIM)
	coords_label.add_theme_font_size_override("font_size", 11)
	coords_label.set_anchors_preset(PRESET_TOP_RIGHT)
	coords_label.offset_top = 28
	coords_label.offset_right = -MAP_PADDING
	coords_label.offset_left = -80
	add_child(coords_label)

	# Map canvas for drawing
	map_canvas = Control.new()
	map_canvas.name = "MapCanvas"
	map_canvas.position = Vector2(MAP_PADDING, 46)
	map_canvas.custom_minimum_size = grid_size
	map_canvas.size = grid_size
	map_canvas.draw.connect(_draw_map)
	map_canvas.gui_input.connect(_on_map_input)
	map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(map_canvas)

	# Compass labels
	_setup_compass_labels()

	# Tooltip
	_setup_tooltip()

	# Travel dialog
	_setup_travel_dialog()

	# Legend at bottom
	var legend := Label.new()
	legend.name = "Legend"
	legend.text = "Click location to fast travel | Green = You"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_color_override("font_color", COLOR_DIM)
	legend.add_theme_font_size_override("font_size", 10)
	legend.set_anchors_preset(PRESET_BOTTOM_WIDE)
	legend.offset_bottom = -4
	legend.offset_top = -18
	add_child(legend)


func _setup_compass_labels() -> void:
	var compass_color := COLOR_GOLD
	var font_size := 14

	# N label at top of grid
	var n_label := Label.new()
	n_label.text = "N"
	n_label.add_theme_color_override("font_color", compass_color)
	n_label.add_theme_font_size_override("font_size", font_size)
	n_label.position = Vector2(MAP_PADDING + grid_size.x / 2 - 4, 34)
	add_child(n_label)

	# S label at bottom of grid
	var s_label := Label.new()
	s_label.text = "S"
	s_label.add_theme_color_override("font_color", compass_color)
	s_label.add_theme_font_size_override("font_size", font_size)
	s_label.position = Vector2(MAP_PADDING + grid_size.x / 2 - 4, 46 + grid_size.y + 2)
	add_child(s_label)

	# W label at left of grid
	var w_label := Label.new()
	w_label.text = "W"
	w_label.add_theme_color_override("font_color", compass_color)
	w_label.add_theme_font_size_override("font_size", font_size)
	w_label.position = Vector2(2, 46 + grid_size.y / 2 - 8)
	add_child(w_label)

	# E label at right of grid
	var e_label := Label.new()
	e_label.text = "E"
	e_label.add_theme_color_override("font_color", compass_color)
	e_label.add_theme_font_size_override("font_size", font_size)
	e_label.position = Vector2(MAP_PADDING + grid_size.x + 4, 46 + grid_size.y / 2 - 8)
	add_child(e_label)


func _setup_tooltip() -> void:
	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "Tooltip"
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.z_index = 100

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	tooltip_panel.add_theme_stylebox_override("panel", style)

	tooltip_label = Label.new()
	tooltip_label.add_theme_color_override("font_color", COLOR_TEXT)
	tooltip_label.add_theme_font_size_override("font_size", 11)
	tooltip_panel.add_child(tooltip_label)

	add_child(tooltip_panel)


func _setup_travel_dialog() -> void:
	travel_dialog = PanelContainer.new()
	travel_dialog.name = "TravelDialog"
	travel_dialog.visible = false
	travel_dialog.z_index = 200

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
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
	travel_confirm_btn.custom_minimum_size = Vector2(70, 26)
	travel_confirm_btn.pressed.connect(_on_travel_confirmed)
	btn_row.add_child(travel_confirm_btn)

	travel_cancel_btn = Button.new()
	travel_cancel_btn.text = "Cancel"
	travel_cancel_btn.custom_minimum_size = Vector2(70, 26)
	travel_cancel_btn.pressed.connect(_on_travel_cancelled)
	btn_row.add_child(travel_cancel_btn)

	travel_dialog.set_anchors_preset(PRESET_CENTER)
	travel_dialog.offset_left = -90
	travel_dialog.offset_right = 90
	travel_dialog.offset_top = -45
	travel_dialog.offset_bottom = 45

	add_child(travel_dialog)


func _draw_map() -> void:
	# Draw terrain cells
	for row in range(WorldData.GRID_ROWS):
		for col in range(WorldData.GRID_COLS):
			var coords := Vector2i(col, row)
			_draw_cell(coords)

	# Draw roads
	_draw_roads()

	# Draw location icons
	for row in range(WorldData.GRID_ROWS):
		for col in range(WorldData.GRID_COLS):
			var coords := Vector2i(col, row)
			_draw_location_icon(coords)

	# Draw player icon
	_draw_player_icon()

	# Draw selection highlight
	if selected_cell.x >= 0:
		_draw_selection(selected_cell)

	# Draw hover highlight
	if hovered_cell.x >= 0 and hovered_cell != selected_cell:
		_draw_hover(hovered_cell)


func _draw_cell(coords: Vector2i) -> void:
	var cell: WorldData.CellData = WorldData.get_cell(coords)
	if not cell:
		return

	var rect := _get_cell_rect(coords)
	var is_dev: bool = SceneManager and SceneManager.dev_mode
	var fog_disabled: bool = SceneManager and not SceneManager.fog_of_war_enabled
	var is_discovered: bool = cell.discovered or is_dev or fog_disabled

	# Get terrain color
	var color: Color = WorldData.get_terrain_color(coords)

	# Apply fog of war
	if not is_discovered:
		color = COLOR_FOG

	# Draw cell background
	map_canvas.draw_rect(rect, color)

	# Draw cell border
	var border_color := color.darkened(0.3)
	border_color.a = 0.5
	map_canvas.draw_rect(rect, border_color, false, 1.0)


func _draw_roads() -> void:
	var is_dev: bool = SceneManager and SceneManager.dev_mode
	var fog_disabled: bool = SceneManager and not SceneManager.fog_of_war_enabled

	# Draw road connections from WorldData.ROADS
	for road: Array in WorldData.ROADS:
		if road.size() < 2:
			continue

		var from: Array = road[0]
		var to: Array = road[1]
		if from.size() < 2 or to.size() < 2:
			continue

		var from_coords := Vector2i(int(from[0]), int(from[1]))
		var to_coords := Vector2i(int(to[0]), int(to[1]))

		var from_cell: WorldData.CellData = WorldData.get_cell(from_coords)
		var to_cell: WorldData.CellData = WorldData.get_cell(to_coords)

		# Only draw if at least one end is discovered
		var from_discovered: bool = (from_cell and from_cell.discovered) or is_dev or fog_disabled
		var to_discovered: bool = (to_cell and to_cell.discovered) or is_dev or fog_disabled

		if not from_discovered and not to_discovered:
			continue

		var from_center := _get_cell_center(from_coords)
		var to_center := _get_cell_center(to_coords)

		var road_color := COLOR_ROAD
		if not from_discovered or not to_discovered:
			road_color.a *= 0.4

		map_canvas.draw_line(from_center, to_center, road_color, 2.0, true)


func _draw_location_icon(coords: Vector2i) -> void:
	var cell: WorldData.CellData = WorldData.get_cell(coords)
	if not cell or cell.location_type == WorldData.LocationType.NONE:
		return

	var is_dev: bool = SceneManager and SceneManager.dev_mode
	var fog_disabled: bool = SceneManager and not SceneManager.fog_of_war_enabled
	var is_discovered: bool = cell.discovered or is_dev or fog_disabled

	if not is_discovered:
		return

	var center := _get_cell_center(coords)
	var icon_size := CELL_SIZE * 0.6

	# Choose color based on location type
	var icon_color: Color
	match cell.location_type:
		WorldData.LocationType.TOWN:
			icon_color = COLOR_TOWN
		WorldData.LocationType.DUNGEON:
			# Show "?" for undiscovered dungeon
			if not cell.dungeon_discovered and not is_dev and not fog_disabled:
				_draw_text_at(center, "?", COLOR_DIM)
				return
			icon_color = COLOR_DUNGEON
		WorldData.LocationType.LANDMARK:
			icon_color = COLOR_LANDMARK
		WorldData.LocationType.BLOCKED:
			icon_color = Color(0.5, 0.4, 0.4)
		_:
			icon_color = COLOR_TEXT

	# Draw location marker (diamond shape)
	var points: PackedVector2Array = [
		center + Vector2(0, -icon_size/2),
		center + Vector2(icon_size/2, 0),
		center + Vector2(0, icon_size/2),
		center + Vector2(-icon_size/2, 0)
	]
	map_canvas.draw_colored_polygon(points, icon_color)

	# Draw outline
	map_canvas.draw_polyline(points + PackedVector2Array([points[0]]), icon_color.lightened(0.3), 1.5, true)


func _draw_player_icon() -> void:
	var center := _get_cell_center(player_coords)

	# Pulsing glow effect
	var pulse := (sin(Time.get_ticks_msec() * 0.004) + 1.0) / 2.0
	var glow_size := PLAYER_ICON_SIZE + pulse * 4.0

	# Draw glow
	map_canvas.draw_circle(center, glow_size, COLOR_PLAYER_GLOW)

	# Draw player dot
	map_canvas.draw_circle(center, PLAYER_ICON_SIZE / 2, COLOR_PLAYER)

	# Draw direction indicator (small triangle pointing up)
	var tri_size := 4.0
	var tri_offset := PLAYER_ICON_SIZE / 2 + 3
	var tri_points: PackedVector2Array = [
		center + Vector2(0, -tri_offset - tri_size),
		center + Vector2(-tri_size, -tri_offset),
		center + Vector2(tri_size, -tri_offset)
	]
	map_canvas.draw_colored_polygon(tri_points, COLOR_PLAYER)


func _draw_selection(coords: Vector2i) -> void:
	var rect := _get_cell_rect(coords)
	rect = rect.grow(1)
	map_canvas.draw_rect(rect, COLOR_SELECTED, false, 2.0)


func _draw_hover(coords: Vector2i) -> void:
	var rect := _get_cell_rect(coords)
	var hover_color := COLOR_TEXT
	hover_color.a = 0.4
	map_canvas.draw_rect(rect, hover_color, false, 1.0)


func _draw_text_at(pos: Vector2, text: String, color: Color) -> void:
	# Draw centered text - use draw_string
	var font: Font = ThemeDB.fallback_font
	var font_size := 12
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := pos - text_size / 2
	map_canvas.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


func _get_cell_rect(coords: Vector2i) -> Rect2:
	# Row 0 = top, Row 16 = bottom (matching JSON grid layout)
	var x: float = coords.x * CELL_SIZE
	var y: float = coords.y * CELL_SIZE
	return Rect2(x, y, CELL_SIZE, CELL_SIZE)


func _get_cell_center(coords: Vector2i) -> Vector2:
	var rect := _get_cell_rect(coords)
	return rect.get_center()


func _screen_to_cell(pos: Vector2) -> Vector2i:
	var col := int(pos.x / CELL_SIZE)
	var row := int(pos.y / CELL_SIZE)

	if col < 0 or col >= WorldData.GRID_COLS or row < 0 or row >= WorldData.GRID_ROWS:
		return Vector2i(-1, -1)

	return Vector2i(col, row)


func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		var coords := _screen_to_cell(mouse_event.position)

		if coords != hovered_cell:
			hovered_cell = coords
			_update_tooltip(coords, mouse_event.position)
			map_canvas.queue_redraw()

	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var coords := _screen_to_cell(mouse_event.position)
			_on_cell_clicked(coords)


func _update_tooltip(coords: Vector2i, mouse_pos: Vector2) -> void:
	if coords.x < 0:
		tooltip_panel.visible = false
		return

	var cell: WorldData.CellData = WorldData.get_cell(coords)
	if not cell:
		tooltip_panel.visible = false
		return

	var is_dev: bool = SceneManager and SceneManager.dev_mode
	var fog_disabled: bool = SceneManager and not SceneManager.fog_of_war_enabled
	var is_discovered: bool = cell.discovered or is_dev or fog_disabled

	var text := ""

	if is_discovered:
		if cell.location_name and not cell.location_name.is_empty():
			text = cell.location_name + "\n"
		text += cell.region_name
		if cell.description and not cell.description.is_empty():
			text += "\n" + cell.description
		if coords == player_coords:
			text += "\n[Current Location]"
	elif not cell.is_passable:
		text = "Impassable"
	else:
		text = "Undiscovered"

	text += "\n(%d, %d)" % [coords.x, coords.y]

	tooltip_label.text = text
	tooltip_panel.reset_size()
	tooltip_panel.visible = true

	# Position tooltip
	var tooltip_pos := map_canvas.position + mouse_pos + Vector2(15, -tooltip_panel.size.y / 2)

	# Keep on screen
	if tooltip_pos.x + tooltip_panel.size.x > size.x - 5:
		tooltip_pos.x = map_canvas.position.x + mouse_pos.x - tooltip_panel.size.x - 15
	if tooltip_pos.y < 5:
		tooltip_pos.y = 5
	if tooltip_pos.y + tooltip_panel.size.y > size.y - 5:
		tooltip_pos.y = size.y - tooltip_panel.size.y - 5

	tooltip_panel.position = tooltip_pos


func _on_cell_clicked(coords: Vector2i) -> void:
	if coords.x < 0:
		return

	var cell: WorldData.CellData = WorldData.get_cell(coords)
	if not cell:
		return

	var is_dev: bool = SceneManager and SceneManager.dev_mode
	var fog_disabled: bool = SceneManager and not SceneManager.fog_of_war_enabled
	var is_discovered: bool = cell.discovered or is_dev or fog_disabled

	# Can't interact with undiscovered cells
	if not is_discovered:
		return

	# Can't travel to current location
	if coords == player_coords:
		return

	# Can only fast travel to locations with IDs
	if cell.location_id.is_empty():
		return

	selected_cell = coords
	location_selected.emit(cell.location_id)

	# Show travel dialog
	travel_location_label.text = "Travel to %s?" % cell.location_name
	travel_dialog.visible = true

	map_canvas.queue_redraw()


func _on_travel_confirmed() -> void:
	if selected_cell.x < 0:
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

	fast_travel_requested.emit(cell.location_id, "from_fast_travel")

	selected_cell = Vector2i(-1, -1)
	map_canvas.queue_redraw()


func _on_travel_cancelled() -> void:
	travel_dialog.visible = false
	selected_cell = Vector2i(-1, -1)
	map_canvas.queue_redraw()


func _update_player_position() -> void:
	# Get player's current grid position from SceneManager
	if SceneManager and SceneManager.is_in_wilderness():
		player_coords = SceneManager.get_current_room_coords()
	else:
		# Default to Elder Moor if not in wilderness
		player_coords = WorldData.PLAYER_START

	# Update info labels
	var cell := WorldData.get_cell(player_coords)
	if cell:
		if cell.location_name and not cell.location_name.is_empty():
			location_label.text = cell.location_name
		else:
			location_label.text = cell.region_name
	coords_label.text = "(%d, %d)" % [player_coords.x, player_coords.y]


func _process(_delta: float) -> void:
	if visible:
		_update_player_position()
		map_canvas.queue_redraw()


func refresh() -> void:
	_update_player_position()
	map_canvas.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		refresh()
