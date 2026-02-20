## painted_world_map.gd - OpenMW-inspired painted world map display
## Shows a hand-painted map image with fog of war overlay and player marker
## Supports pan, zoom, and fast travel to discovered locations
class_name PaintedWorldMap
extends Control

signal fast_travel_requested(location_id: String, spawn_id: String)
signal location_selected(location_id: String)

## Map texture path
const MAP_TEXTURE_PATH := "res://assets/textures/ui/world_map_painted.png"

## Colors - matching existing HexWorldMap theme
const COLOR_BG := Color(0.05, 0.04, 0.06, 0.98)
const COLOR_BORDER := Color(0.4, 0.35, 0.25)
const COLOR_TEXT := Color(0.9, 0.85, 0.75)
const COLOR_DIM := Color(0.5, 0.5, 0.5)
const COLOR_GOLD := Color(0.85, 0.7, 0.3)
const COLOR_PLAYER := Color(0.2, 0.9, 0.4)
const COLOR_PLAYER_GLOW := Color(0.4, 1.0, 0.6, 0.5)
const COLOR_FOG := Color(0.08, 0.08, 0.1, 0.85)
const COLOR_TOWN_MARKER := Color(1.0, 0.9, 0.5)
const COLOR_SELECTED := Color(1.0, 0.9, 0.5, 0.8)

## Map settings
const MAP_PADDING := 10
const PLAYER_ICON_SIZE := 8.0
const TOWN_MARKER_SIZE := 6.0
const MIN_ZOOM := 0.5
const MAX_ZOOM := 3.0

## Components
var background: ColorRect
var map_canvas: Control
var map_texture: Texture2D
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

## Fog of war system
var fog_of_war: MapFogOfWar

## View state
var map_offset: Vector2 = Vector2.ZERO
var zoom_level: float = 1.0
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_offset_start: Vector2 = Vector2.ZERO

## Selection state
var selected_cell: Vector2i = Vector2i(-999, -999)
var hovered_cell: Vector2i = Vector2i(-999, -999)
var player_cell: Vector2i = WorldData.PLAYER_START  # Default to Elder Moor (7, 4)

## Cached values
var map_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(500, 400)

	_load_map_texture()
	_setup_fog_of_war()
	_setup_ui()
	_update_player_position()
	_center_on_player()


func _load_map_texture() -> void:
	if ResourceLoader.exists(MAP_TEXTURE_PATH):
		map_texture = load(MAP_TEXTURE_PATH)
		if map_texture:
			map_size = map_texture.get_size()
			print("[PaintedWorldMap] Loaded map texture: %dx%d" % [int(map_size.x), int(map_size.y)])
	else:
		push_warning("[PaintedWorldMap] Map texture not found: %s" % MAP_TEXTURE_PATH)


func _setup_fog_of_war() -> void:
	if map_size.x > 0 and map_size.y > 0:
		fog_of_war = MapFogOfWar.new(Vector2i(int(map_size.x), int(map_size.y)))

		# Reveal starting area (Elder Moor)
		fog_of_war.reveal_hex(WorldData.PLAYER_START)

		# Reveal player's current position
		_reveal_current_cell()


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

	# Location label
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
	coords_label.offset_left = -100
	add_child(coords_label)

	# Map canvas for drawing
	map_canvas = Control.new()
	map_canvas.name = "MapCanvas"
	map_canvas.set_anchors_preset(PRESET_FULL_RECT)
	map_canvas.offset_top = 46
	map_canvas.offset_left = MAP_PADDING
	map_canvas.offset_right = -MAP_PADDING
	map_canvas.offset_bottom = -30
	map_canvas.clip_contents = true
	map_canvas.draw.connect(_draw_map)
	map_canvas.gui_input.connect(_on_map_input)
	map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(map_canvas)

	# Tooltip
	_setup_tooltip()

	# Travel dialog
	_setup_travel_dialog()

	# Legend
	var legend := Label.new()
	legend.name = "Legend"
	legend.text = "Click town to fast travel | Scroll to zoom | Drag to pan | Green = You"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_color_override("font_color", COLOR_DIM)
	legend.add_theme_font_size_override("font_size", 10)
	legend.set_anchors_preset(PRESET_BOTTOM_WIDE)
	legend.offset_bottom = -4
	legend.offset_top = -18
	add_child(legend)


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


## ============================================================================
## COORDINATE CONVERSION (Square Grid System)
## ============================================================================

## Grid dimensions (must match WorldData and map image)
const GRID_COLS := 20
const GRID_ROWS := 20

## Get cell size in pixels based on map texture size
func _get_cell_size() -> float:
	if map_size.x > 0:
		return map_size.x / float(GRID_COLS)
	return 54.0  # Default: 1080 / 20 = 54


## Convert map pixel position to canvas position (with zoom and offset)
func map_to_canvas(map_pixel: Vector2) -> Vector2:
	var canvas_center: Vector2 = map_canvas.size / 2.0
	return canvas_center + (map_pixel - map_size / 2.0) * zoom_level + map_offset


## Convert canvas position to map pixel position
func canvas_to_map(canvas_pos: Vector2) -> Vector2:
	var canvas_center: Vector2 = map_canvas.size / 2.0
	return (canvas_pos - canvas_center - map_offset) / zoom_level + map_size / 2.0


## Convert grid coords to map pixel position (center of cell)
func grid_to_pixel(coords: Vector2i) -> Vector2:
	var cell_size: float = _get_cell_size()
	var pixel_x: float = float(coords.x) * cell_size + cell_size / 2.0
	var pixel_y: float = float(coords.y) * cell_size + cell_size / 2.0
	return Vector2(pixel_x, pixel_y)


## Convert grid coords to canvas position
func grid_to_canvas(coords: Vector2i) -> Vector2:
	var map_pixel: Vector2 = grid_to_pixel(coords)
	return map_to_canvas(map_pixel)


## Convert map pixel position to grid coords
func pixel_to_grid(pixel: Vector2) -> Vector2i:
	var cell_size: float = _get_cell_size()
	var col: int = int(pixel.x / cell_size)
	var row: int = int(pixel.y / cell_size)
	# Clamp to valid grid range
	col = clampi(col, 0, GRID_COLS - 1)
	row = clampi(row, 0, GRID_ROWS - 1)
	return Vector2i(col, row)


## Convert canvas position to grid coords
func canvas_to_grid(canvas_pos: Vector2) -> Vector2i:
	var map_pixel: Vector2 = canvas_to_map(canvas_pos)
	return pixel_to_grid(map_pixel)


## ============================================================================
## DRAWING
## ============================================================================

func _draw_map() -> void:
	if not map_texture:
		_draw_placeholder()
		return

	# Calculate map display rect
	var scaled_size: Vector2 = map_size * zoom_level
	var canvas_center: Vector2 = map_canvas.size / 2.0
	var map_rect := Rect2(
		canvas_center - scaled_size / 2.0 + map_offset,
		scaled_size
	)

	# Draw map texture
	map_canvas.draw_texture_rect(map_texture, map_rect, false)

	# Draw fog of war overlay
	_draw_fog_overlay(map_rect)

	# Draw town markers
	_draw_town_markers()

	# Draw player marker
	_draw_player_marker()

	# Draw selection highlight
	if selected_cell.x != -999:
		_draw_cell_highlight(selected_cell, COLOR_SELECTED)


func _draw_placeholder() -> void:
	# Draw placeholder if map texture not loaded
	var rect := Rect2(Vector2.ZERO, map_canvas.size)
	map_canvas.draw_rect(rect, Color(0.1, 0.1, 0.15))
	var center: Vector2 = map_canvas.size / 2.0
	_draw_text_centered(center, "Map texture not found", COLOR_DIM, 14)


func _draw_fog_overlay(map_rect: Rect2) -> void:
	if not fog_of_war:
		return

	# Check if fog of war is disabled
	var fog_disabled: bool = SceneManager and not SceneManager.fog_of_war_enabled
	if fog_disabled:
		return

	# Get fog texture and draw it as overlay
	var fog_tex: ImageTexture = fog_of_war.get_texture()
	if not fog_tex:
		return

	# Draw fog with inverted blend (fog blocks where image is black)
	# We need to draw the fog overlay using a shader or manual per-pixel blend
	# For simplicity, we draw a semi-transparent overlay where not explored

	# Since we can't easily do per-pixel fog blending in _draw,
	# we draw a fog rectangle and rely on the fog texture for masking
	# A proper implementation would use a shader

	# For now, draw unexplored areas as solid fog color
	var fog_image: Image = fog_of_war.get_image()
	if fog_image:
		# Draw fog overlay texture
		# This requires shader support for proper blending
		# As a fallback, we skip per-pixel fog and rely on hex-based visibility
		pass


func _draw_town_markers() -> void:
	# Ensure WorldData is initialized
	if WorldData.world_grid.is_empty():
		WorldData.initialize()

	var is_dev: bool = SceneManager and SceneManager.dev_mode
	var fog_disabled: bool = SceneManager and not SceneManager.fog_of_war_enabled

	# Iterate through all cells to find towns
	for coords: Vector2i in WorldData.world_grid:
		var cell: WorldData.CellData = WorldData.world_grid[coords]

		# Only draw towns
		if cell.location_type != WorldData.LocationType.TOWN:
			continue

		# Check visibility
		var is_visible: bool = cell.discovered or is_dev or fog_disabled
		if fog_of_war:
			is_visible = is_visible or fog_of_war.is_explored(coords)

		if not is_visible:
			continue

		var canvas_pos: Vector2 = grid_to_canvas(coords)

		# Skip if off screen
		if canvas_pos.x < -20 or canvas_pos.x > map_canvas.size.x + 20:
			continue
		if canvas_pos.y < -20 or canvas_pos.y > map_canvas.size.y + 20:
			continue

		# Draw town marker (diamond shape)
		var marker_size: float = TOWN_MARKER_SIZE * zoom_level
		var points: PackedVector2Array = [
			canvas_pos + Vector2(0, -marker_size),
			canvas_pos + Vector2(marker_size, 0),
			canvas_pos + Vector2(0, marker_size),
			canvas_pos + Vector2(-marker_size, 0)
		]
		map_canvas.draw_colored_polygon(points, COLOR_TOWN_MARKER)
		points.append(points[0])
		map_canvas.draw_polyline(points, COLOR_TOWN_MARKER.lightened(0.3), 1.5)

		# Draw town name if zoomed in enough
		if zoom_level >= 0.8:
			_draw_text_centered(canvas_pos + Vector2(0, marker_size + 8), cell.location_name, COLOR_TEXT, 10)


func _draw_player_marker() -> void:
	var canvas_pos: Vector2 = grid_to_canvas(player_cell)

	# Pulsing glow effect
	var pulse: float = (sin(Time.get_ticks_msec() * 0.004) + 1.0) / 2.0
	var glow_size: float = (PLAYER_ICON_SIZE + pulse * 4.0) * zoom_level

	# Draw glow
	map_canvas.draw_circle(canvas_pos, glow_size, COLOR_PLAYER_GLOW)

	# Draw player dot
	map_canvas.draw_circle(canvas_pos, PLAYER_ICON_SIZE * zoom_level, COLOR_PLAYER)

	# Draw direction indicator (triangle pointing north)
	var tri_size: float = 4.0 * zoom_level
	var tri_offset: float = (PLAYER_ICON_SIZE + 3) * zoom_level
	var tri_points: PackedVector2Array = [
		canvas_pos + Vector2(0, -tri_offset - tri_size),
		canvas_pos + Vector2(-tri_size, -tri_offset),
		canvas_pos + Vector2(tri_size, -tri_offset)
	]
	map_canvas.draw_colored_polygon(tri_points, COLOR_PLAYER)


func _draw_cell_highlight(coords: Vector2i, color: Color) -> void:
	var canvas_pos: Vector2 = grid_to_canvas(coords)
	var highlight_size: float = 12.0 * zoom_level

	# Draw highlight circle
	map_canvas.draw_arc(canvas_pos, highlight_size, 0, TAU, 32, color, 2.0)


func _draw_text_centered(pos: Vector2, text: String, color: Color, font_size: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = pos - Vector2(text_size.x / 2.0, -text_size.y / 4.0)
	map_canvas.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## ============================================================================
## INPUT HANDLING
## ============================================================================

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion

		if is_dragging:
			# Pan the map
			map_offset += mouse_event.relative
			_clamp_offset()
			map_canvas.queue_redraw()
		else:
			# Update hovered cell
			var coords: Vector2i = canvas_to_grid(mouse_event.position)
			if coords != hovered_cell:
				hovered_cell = coords
				_update_tooltip(coords, mouse_event.position)
				map_canvas.queue_redraw()

	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				is_dragging = true
				drag_start = mouse_event.position
				drag_offset_start = map_offset
			else:
				is_dragging = false
				# Check if it was a click (not a drag)
				var drag_dist: float = (mouse_event.position - drag_start).length()
				if drag_dist < 5.0:
					var coords: Vector2i = canvas_to_grid(mouse_event.position)
					_on_cell_clicked(coords)

		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			# Zoom in
			_zoom_at_point(mouse_event.position, 1.2)

		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			# Zoom out
			_zoom_at_point(mouse_event.position, 1.0 / 1.2)

		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE and mouse_event.pressed:
			# Center on player
			_center_on_player()


func _zoom_at_point(point: Vector2, factor: float) -> void:
	var old_zoom: float = zoom_level
	zoom_level = clampf(zoom_level * factor, MIN_ZOOM, MAX_ZOOM)

	if zoom_level != old_zoom:
		# Adjust offset to keep point stationary
		var canvas_center: Vector2 = map_canvas.size / 2.0
		var point_offset: Vector2 = point - canvas_center - map_offset
		map_offset -= point_offset * (zoom_level / old_zoom - 1.0)
		_clamp_offset()
		map_canvas.queue_redraw()


func _clamp_offset() -> void:
	# Clamp offset so map stays visible
	var scaled_size: Vector2 = map_size * zoom_level
	var max_offset: float = maxf(scaled_size.x, scaled_size.y) / 2.0
	map_offset.x = clampf(map_offset.x, -max_offset, max_offset)
	map_offset.y = clampf(map_offset.y, -max_offset, max_offset)


func _center_on_player() -> void:
	# Get player position on map using local grid_to_pixel
	var player_map_pos: Vector2 = grid_to_pixel(player_cell)

	# Calculate offset to center player
	map_offset = (map_size / 2.0 - player_map_pos) * zoom_level

	_clamp_offset()
	map_canvas.queue_redraw()


func _update_tooltip(coords: Vector2i, mouse_pos: Vector2) -> void:
	# Ensure WorldData is initialized
	if WorldData.world_grid.is_empty():
		WorldData.initialize()

	var cell: WorldData.CellData = WorldData.get_cell(coords)

	if not cell:
		tooltip_panel.visible = false
		return

	var is_dev: bool = SceneManager and SceneManager.dev_mode
	var fog_disabled: bool = SceneManager and not SceneManager.fog_of_war_enabled
	var is_discovered: bool = cell.discovered or is_dev or fog_disabled

	var text: String = ""

	if is_discovered:
		if not cell.location_name.is_empty():
			text = cell.location_name + "\n"
		if not cell.region_name.is_empty():
			text += cell.region_name + "\n"
		text += WorldData.get_cell_name(coords)
		if coords == player_cell:
			text += "\n[Current Location]"
	elif not cell.is_passable:
		text = "Impassable"
	else:
		text = "Undiscovered"

	# Show Elder Moor-relative coordinates
	var region_coords: Vector2i = WorldData.get_region_coords(cell.location_id) if not cell.location_id.is_empty() else Vector2i(0, 0)
	text += "\nRegion: (%d, %d)" % [region_coords.x, region_coords.y]

	tooltip_label.text = text
	tooltip_panel.reset_size()
	tooltip_panel.visible = true

	# Position tooltip
	var tooltip_pos: Vector2 = map_canvas.position + mouse_pos + Vector2(15, -tooltip_panel.size.y / 2.0)

	# Keep on screen
	if tooltip_pos.x + tooltip_panel.size.x > size.x - 5:
		tooltip_pos.x = map_canvas.position.x + mouse_pos.x - tooltip_panel.size.x - 15
	if tooltip_pos.y < 5:
		tooltip_pos.y = 5
	if tooltip_pos.y + tooltip_panel.size.y > size.y - 5:
		tooltip_pos.y = size.y - tooltip_panel.size.y - 5

	tooltip_panel.position = tooltip_pos


func _on_cell_clicked(coords: Vector2i) -> void:
	# Ensure WorldData is initialized
	if WorldData.world_grid.is_empty():
		WorldData.initialize()

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
	if coords == player_cell:
		return

	# Can only fast travel to towns
	if cell.location_type != WorldData.LocationType.TOWN:
		return

	if cell.location_id.is_empty():
		return

	selected_cell = coords
	location_selected.emit(cell.location_id)

	# Show travel dialog
	travel_location_label.text = "Travel to %s?" % cell.location_name
	travel_dialog.visible = true

	map_canvas.queue_redraw()


func _on_travel_confirmed() -> void:
	if selected_cell.x == -999:
		travel_dialog.visible = false
		return

	var cell: WorldData.CellData = WorldData.get_cell(selected_cell)
	if not cell or cell.location_id.is_empty():
		travel_dialog.visible = false
		return

	travel_dialog.visible = false

	# Use SceneManager's fast travel
	if SceneManager:
		SceneManager.dev_fast_travel_to(cell.location_id)

	fast_travel_requested.emit(cell.location_id, "from_fast_travel")

	selected_cell = Vector2i(-999, -999)
	map_canvas.queue_redraw()


func _on_travel_cancelled() -> void:
	travel_dialog.visible = false
	selected_cell = Vector2i(-999, -999)
	map_canvas.queue_redraw()


## ============================================================================
## UPDATE METHODS
## ============================================================================

func _reveal_current_cell() -> void:
	if fog_of_war:
		fog_of_war.reveal_hex(player_cell)


func _update_player_position() -> void:
	# Get player's current grid position from SceneManager
	if SceneManager:
		player_cell = SceneManager.current_room_coords
	else:
		player_cell = WorldData.PLAYER_START  # Default to Elder Moor

	# Reveal fog at player position
	_reveal_current_cell()

	# Ensure WorldData is initialized
	if WorldData.world_grid.is_empty():
		WorldData.initialize()

	# Update info labels
	var cell: WorldData.CellData = WorldData.get_cell(player_cell)

	if cell:
		if not cell.location_name.is_empty():
			location_label.text = cell.location_name
		elif not cell.region_name.is_empty():
			location_label.text = cell.region_name
		else:
			location_label.text = WorldData.get_cell_name(player_cell)
	else:
		location_label.text = "Wilderness"

	# Show Elder Moor-relative region coordinates
	var region_coords: Vector2i = SceneManager.current_room_coords if SceneManager else Vector2i(0, 0)
	coords_label.text = "Region: (%d, %d)" % [region_coords.x, region_coords.y]


func _process(_delta: float) -> void:
	if visible:
		_update_player_position()
		map_canvas.queue_redraw()


func refresh() -> void:
	_update_player_position()
	_center_on_player()
	map_canvas.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		refresh()


## ============================================================================
## SAVE/LOAD SUPPORT
## ============================================================================

## Get fog of war state for saving
func get_fog_state() -> Dictionary:
	if fog_of_war:
		return fog_of_war.to_dict()
	return {}


## Load fog of war state from save
func load_fog_state(data: Dictionary) -> void:
	if fog_of_war and not data.is_empty():
		fog_of_war.from_dict(data)


## Get the MapFogOfWar instance
func get_fog_of_war() -> MapFogOfWar:
	return fog_of_war
