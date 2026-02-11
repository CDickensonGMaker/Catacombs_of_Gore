## zone_map.gd - Zone map panel showing entire explored area of current zone
## Larger than minimap, with zoom/pan controls and marker tooltips
class_name ZoneMap
extends Control

signal marker_clicked(marker_data: Dictionary)

## Map settings
const DEFAULT_SIZE := Vector2(400, 300)
const CELL_PIXEL_SIZE := 4  # Base pixels per cell (before zoom)
const MIN_ZOOM := 1.0
const MAX_ZOOM := 4.0
const ZOOM_STEP := 0.5
const PAN_SPEED := 200.0  # Pixels per second for keyboard panning

## Colors
const COLOR_BG := Color(0.05, 0.04, 0.06, 0.95)
const COLOR_REVEALED := Color(0.15, 0.13, 0.18, 0.9)
const COLOR_WALL := Color(0.3, 0.25, 0.35, 1.0)
const COLOR_PLAYER := Color(0.3, 0.9, 0.4, 1.0)
const COLOR_ENEMY := Color(0.9, 0.2, 0.2, 1.0)
const COLOR_CHEST := Color(0.9, 0.8, 0.2, 1.0)
const COLOR_PORTAL := Color(0.3, 0.5, 0.9, 1.0)
const COLOR_NPC := Color(0.2, 0.7, 0.9, 1.0)
const COLOR_ROOM_OUTLINE := Color(0.4, 0.35, 0.45, 0.8)
const COLOR_BORDER := Color(0.3, 0.25, 0.2)
const COLOR_TEXT := Color(0.9, 0.85, 0.75)
const COLOR_DIM := Color(0.5, 0.5, 0.5)
const COLOR_ZONE_EDGE := Color(0.6, 0.5, 0.4, 0.6)
const COLOR_DOOR := Color(0.7, 0.5, 0.3, 1.0)
const COLOR_SHOP := Color(0.9, 0.7, 0.2, 1.0)
const COLOR_INN := Color(0.6, 0.4, 0.8, 1.0)
const COLOR_DUNGEON := Color(0.5, 0.2, 0.2, 1.0)
const COLOR_SHRINE := Color(0.3, 0.8, 0.8, 1.0)

## Components
var background: ColorRect
var map_container: Control
var map_canvas: Control  # Custom drawing surface
var player_marker: Control
var zoom_label: Label
var zone_name_label: Label

## Tooltip
var tooltip_panel: PanelContainer
var tooltip_label: Label

## State
var current_zoom: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO  # Offset from center in cells
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_start_offset: Vector2 = Vector2.ZERO
var center_on_player: bool = true  # Toggle for auto-centering

## UI elements
var center_toggle: CheckBox

## Cached data
var player: Node3D = null
var player_cell: Vector2i = Vector2i.ZERO


func _ready() -> void:
	custom_minimum_size = DEFAULT_SIZE
	size = DEFAULT_SIZE
	clip_contents = true

	_setup_ui()

	# Connect to MapTracker signals
	if MapTracker:
		MapTracker.map_updated.connect(_on_map_updated)
		MapTracker.cell_revealed.connect(_on_cell_revealed)


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

	# Map container (clipped area)
	map_container = Control.new()
	map_container.name = "MapContainer"
	map_container.clip_contents = true
	map_container.set_anchors_preset(PRESET_FULL_RECT)
	map_container.offset_left = 2
	map_container.offset_top = 24  # Leave room for header
	map_container.offset_right = -2
	map_container.offset_bottom = -2
	add_child(map_container)

	# Map canvas for drawing
	map_canvas = Control.new()
	map_canvas.name = "MapCanvas"
	map_canvas.set_anchors_preset(PRESET_FULL_RECT)
	map_canvas.draw.connect(_draw_map)
	map_container.add_child(map_canvas)

	# Player marker
	player_marker = _create_player_marker()
	map_container.add_child(player_marker)

	# Header with zone name and zoom controls
	_setup_header()

	# Tooltip
	_setup_tooltip()


func _setup_header() -> void:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.set_anchors_preset(PRESET_TOP_WIDE)
	header.offset_bottom = 22
	header.offset_left = 4
	header.offset_right = -4
	add_child(header)

	# Zone name
	zone_name_label = Label.new()
	zone_name_label.name = "ZoneName"
	zone_name_label.text = "Zone Map"
	zone_name_label.add_theme_color_override("font_color", COLOR_TEXT)
	zone_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(zone_name_label)

	# Zoom out button
	var zoom_out := Button.new()
	zoom_out.text = "-"
	zoom_out.custom_minimum_size = Vector2(24, 20)
	zoom_out.pressed.connect(_on_zoom_out)
	header.add_child(zoom_out)

	# Zoom label
	zoom_label = Label.new()
	zoom_label.name = "ZoomLabel"
	zoom_label.text = "1x"
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_label.custom_minimum_size.x = 30
	zoom_label.add_theme_color_override("font_color", COLOR_DIM)
	header.add_child(zoom_label)

	# Zoom in button
	var zoom_in := Button.new()
	zoom_in.text = "+"
	zoom_in.custom_minimum_size = Vector2(24, 20)
	zoom_in.pressed.connect(_on_zoom_in)
	header.add_child(zoom_in)

	# Reset button
	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.custom_minimum_size = Vector2(40, 20)
	reset_btn.pressed.connect(_on_reset_view)
	header.add_child(reset_btn)

	# Center on player toggle
	center_toggle = CheckBox.new()
	center_toggle.button_pressed = center_on_player
	center_toggle.toggled.connect(_on_center_toggle)
	center_toggle.tooltip_text = "Auto-center on player"
	header.add_child(center_toggle)

	var center_label := Label.new()
	center_label.text = "Center"
	center_label.add_theme_color_override("font_color", COLOR_DIM)
	center_label.add_theme_font_size_override("font_size", 10)
	header.add_child(center_label)


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
	style.set_content_margin_all(4)
	tooltip_panel.add_theme_stylebox_override("panel", style)

	tooltip_label = Label.new()
	tooltip_label.add_theme_color_override("font_color", COLOR_TEXT)
	tooltip_panel.add_child(tooltip_label)

	add_child(tooltip_panel)


func _create_player_marker() -> Control:
	var marker := Control.new()
	marker.name = "PlayerMarker"
	marker.custom_minimum_size = Vector2(10, 10)
	marker.size = Vector2(10, 10)
	marker.draw.connect(_draw_player_marker.bind(marker))
	return marker


func _draw_player_marker(marker: Control) -> void:
	# Triangle pointing up (rotated based on facing)
	var points := PackedVector2Array([
		Vector2(5, 0),
		Vector2(0, 10),
		Vector2(10, 10),
	])
	marker.draw_colored_polygon(points, COLOR_PLAYER)


func _process(delta: float) -> void:
	if not visible:
		return

	# Get player
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D

	if player and MapTracker:
		player_cell = MapTracker.world_to_cell(player.global_position)

	# Handle keyboard panning
	_handle_keyboard_pan(delta)

	# Auto-center on player if enabled
	if center_on_player:
		pan_offset = Vector2.ZERO

	# Update zone name
	if MapTracker and zone_name_label:
		var zone_id := MapTracker.get_current_zone()
		zone_name_label.text = zone_id.capitalize().replace("_", " ") if not zone_id.is_empty() else "Zone Map"

	# Request redraw
	map_canvas.queue_redraw()
	_update_player_marker()


func _handle_keyboard_pan(delta: float) -> void:
	var pan_input := Vector2.ZERO

	if Input.is_action_pressed("ui_left"):
		pan_input.x -= 1
	if Input.is_action_pressed("ui_right"):
		pan_input.x += 1
	if Input.is_action_pressed("ui_up"):
		pan_input.y -= 1
	if Input.is_action_pressed("ui_down"):
		pan_input.y += 1

	if pan_input != Vector2.ZERO:
		# Disable center-on-player when manually panning
		center_on_player = false
		if center_toggle:
			center_toggle.button_pressed = false
		pan_offset += pan_input * (PAN_SPEED / current_zoom / CELL_PIXEL_SIZE) * delta
		_clamp_pan_offset()


func _gui_input(event: InputEvent) -> void:
	# Mouse wheel zoom
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at_point(ZOOM_STEP, mb.position)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at_point(-ZOOM_STEP, mb.position)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				# Start drag
				is_dragging = true
				drag_start = mb.position
				drag_start_offset = pan_offset
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				# Check for marker click
				_check_marker_click(mb.position)
				accept_event()
		else:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				is_dragging = false

	# Mouse drag
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if is_dragging:
			# Disable center-on-player when manually panning
			center_on_player = false
			if center_toggle:
				center_toggle.button_pressed = false
			var delta := mm.position - drag_start
			pan_offset = drag_start_offset - delta / (current_zoom * CELL_PIXEL_SIZE)
			_clamp_pan_offset()
		else:
			# Update tooltip on hover
			_update_tooltip_at_position(mm.position)


func _zoom_at_point(zoom_delta: float, point: Vector2) -> void:
	var old_zoom := current_zoom
	current_zoom = clampf(current_zoom + zoom_delta, MIN_ZOOM, MAX_ZOOM)

	if old_zoom != current_zoom:
		zoom_label.text = "%.1fx" % current_zoom
		_clamp_pan_offset()


func _on_zoom_in() -> void:
	_zoom_at_point(ZOOM_STEP, size / 2)


func _on_zoom_out() -> void:
	_zoom_at_point(-ZOOM_STEP, size / 2)


func _on_reset_view() -> void:
	current_zoom = 1.0
	pan_offset = Vector2.ZERO
	zoom_label.text = "1x"
	center_on_player = true
	if center_toggle:
		center_toggle.button_pressed = true


func _on_center_toggle(enabled: bool) -> void:
	center_on_player = enabled
	if enabled:
		pan_offset = Vector2.ZERO


func _clamp_pan_offset() -> void:
	if not MapTracker:
		return

	var bounds := MapTracker.get_map_bounds()
	if bounds.size == Vector2.ZERO:
		return

	# Convert bounds to cells
	var min_cell := Vector2(bounds.position.x / MapTracker.CELL_SIZE, bounds.position.y / MapTracker.CELL_SIZE)
	var max_cell := Vector2(bounds.end.x / MapTracker.CELL_SIZE, bounds.end.y / MapTracker.CELL_SIZE)

	# Clamp pan to keep map visible
	pan_offset.x = clampf(pan_offset.x, min_cell.x - 10, max_cell.x + 10)
	pan_offset.y = clampf(pan_offset.y, min_cell.y - 10, max_cell.y + 10)


func _draw_map() -> void:
	if not MapTracker:
		return

	var container_size := map_container.size
	var center := container_size / 2.0
	var pixel_size := CELL_PIXEL_SIZE * current_zoom

	# Calculate view cell at center (player position + pan offset)
	var view_center_cell := Vector2(player_cell) + pan_offset

	# Draw zone edge/border first (background)
	_draw_zone_edges(center, view_center_cell, pixel_size, container_size)

	# Draw revealed cells
	for cell in MapTracker.get_revealed_cells():
		var rel_cell := Vector2(cell) - view_center_cell
		var pixel_pos := center + rel_cell * pixel_size
		var rect := Rect2(pixel_pos - Vector2(pixel_size / 2.0, pixel_size / 2.0), Vector2(pixel_size, pixel_size))

		# Skip if off-screen
		if not rect.intersects(Rect2(Vector2.ZERO, container_size)):
			continue

		# Check if cell is on edge (wall)
		var is_edge := _is_edge_cell(cell)
		var color := COLOR_WALL if is_edge else COLOR_REVEALED
		map_canvas.draw_rect(rect, color)

	# Draw room outlines if in dungeon
	_draw_room_outlines(center, view_center_cell, pixel_size)

	# Draw markers
	_draw_markers(center, view_center_cell, pixel_size)

	# Draw enemies
	_draw_entities(center, view_center_cell, pixel_size)


func _draw_zone_edges(center: Vector2, view_center: Vector2, pixel_size: float, container_size: Vector2) -> void:
	# Get map bounds and draw zone boundary
	var bounds := MapTracker.get_map_bounds()
	if bounds.size == Vector2.ZERO:
		return

	# Convert bounds to cell coordinates
	var min_cell := Vector2(bounds.position.x / MapTracker.CELL_SIZE, bounds.position.y / MapTracker.CELL_SIZE)
	var max_cell := Vector2(bounds.end.x / MapTracker.CELL_SIZE, bounds.end.y / MapTracker.CELL_SIZE)

	# Calculate screen positions
	var min_rel := min_cell - view_center
	var max_rel := max_cell - view_center
	var min_pos := center + min_rel * pixel_size
	var max_pos := center + max_rel * pixel_size

	# Draw boundary rectangle
	var boundary_rect := Rect2(min_pos, max_pos - min_pos)
	if boundary_rect.intersects(Rect2(Vector2.ZERO, container_size)):
		map_canvas.draw_rect(boundary_rect, COLOR_ZONE_EDGE, false, 2.0)


func _is_edge_cell(cell: Vector2i) -> bool:
	var neighbors := [
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x, cell.y - 1),
		Vector2i(cell.x, cell.y + 1),
	]

	for neighbor in neighbors:
		if not MapTracker.is_cell_revealed(neighbor):
			return true

	return false


func _draw_room_outlines(center: Vector2, view_center: Vector2, pixel_size: float) -> void:
	if MapTracker.current_map.rooms.is_empty():
		return

	for room_data in MapTracker.current_map.rooms:
		if not room_data.get("explored", false):
			continue

		var bounds: Dictionary = room_data.get("bounds", {})
		if bounds.is_empty():
			continue

		# Convert room bounds to cell coords
		var room_min := Vector2(bounds.x / MapTracker.CELL_SIZE, bounds.y / MapTracker.CELL_SIZE)
		var room_max := Vector2((bounds.x + bounds.w) / MapTracker.CELL_SIZE, (bounds.y + bounds.h) / MapTracker.CELL_SIZE)
		var room_center := (room_min + room_max) / 2.0

		var rel_pos := room_center - view_center
		var map_pos := center + rel_pos * pixel_size
		var map_size := (room_max - room_min) * pixel_size

		var draw_rect := Rect2(map_pos - map_size / 2.0, map_size)

		if draw_rect.intersects(Rect2(Vector2.ZERO, map_container.size)):
			map_canvas.draw_rect(draw_rect, COLOR_ROOM_OUTLINE, false, 1.0)


func _draw_markers(center: Vector2, view_center: Vector2, pixel_size: float) -> void:
	for marker in MapTracker.get_markers():
		var marker_pos := Vector3(marker.position.x, marker.position.y, marker.position.z)
		var marker_cell := MapTracker.world_to_cell(marker_pos)
		var rel_cell := Vector2(marker_cell) - view_center
		var pixel_pos := center + rel_cell * pixel_size

		# Skip if off-screen
		if pixel_pos.x < -10 or pixel_pos.x > map_container.size.x + 10:
			continue
		if pixel_pos.y < -10 or pixel_pos.y > map_container.size.y + 10:
			continue

		var marker_size := 3.0 * current_zoom
		var marker_type: String = marker.get("type", "")

		match marker_type:
			"chest":
				# Square icon for chests
				map_canvas.draw_rect(Rect2(pixel_pos - Vector2(marker_size, marker_size), Vector2(marker_size * 2, marker_size * 2)), COLOR_CHEST)
			"portal", "door", "exit":
				# Archway/door icon (rectangle with gap)
				_draw_door_icon(pixel_pos, marker_size)
			"npc", "quest_giver":
				# Circle with dot for NPCs
				map_canvas.draw_circle(pixel_pos, marker_size + 1, COLOR_NPC)
				map_canvas.draw_circle(pixel_pos, marker_size * 0.4, Color.WHITE)
			"merchant", "shop":
				# Diamond icon for shops
				_draw_diamond_icon(pixel_pos, marker_size, COLOR_SHOP)
			"inn", "tavern":
				# Bed-like icon (rectangle)
				map_canvas.draw_rect(Rect2(pixel_pos - Vector2(marker_size * 1.2, marker_size * 0.6), Vector2(marker_size * 2.4, marker_size * 1.2)), COLOR_INN)
			"dungeon", "dungeon_entrance":
				# Skull-like icon (triangle pointing down)
				_draw_dungeon_icon(pixel_pos, marker_size)
			"shrine", "rest_spot", "fireplace":
				# Star-like icon
				_draw_shrine_icon(pixel_pos, marker_size)
			"fast_travel":
				# Double circle for fast travel shrines
				map_canvas.draw_circle(pixel_pos, marker_size + 2, COLOR_SHRINE)
				map_canvas.draw_circle(pixel_pos, marker_size, COLOR_BG)
				map_canvas.draw_circle(pixel_pos, marker_size - 1, COLOR_SHRINE)
			_:
				# Default: simple circle
				map_canvas.draw_circle(pixel_pos, marker_size, Color.WHITE)


func _draw_door_icon(pos: Vector2, size: float) -> void:
	# Door/archway icon - two vertical lines with gap
	var half_gap := size * 0.4
	var height := size * 1.5
	# Left pillar
	map_canvas.draw_rect(Rect2(pos.x - size - 1, pos.y - height / 2, 2, height), COLOR_DOOR)
	# Right pillar
	map_canvas.draw_rect(Rect2(pos.x + size - 1, pos.y - height / 2, 2, height), COLOR_DOOR)
	# Top arch
	map_canvas.draw_line(Vector2(pos.x - size, pos.y - height / 2), Vector2(pos.x + size, pos.y - height / 2), COLOR_DOOR, 2.0)


func _draw_diamond_icon(pos: Vector2, size: float, color: Color) -> void:
	var points := PackedVector2Array([
		Vector2(pos.x, pos.y - size * 1.2),  # Top
		Vector2(pos.x + size, pos.y),         # Right
		Vector2(pos.x, pos.y + size * 1.2),   # Bottom
		Vector2(pos.x - size, pos.y),         # Left
	])
	map_canvas.draw_colored_polygon(points, color)


func _draw_dungeon_icon(pos: Vector2, size: float) -> void:
	# Downward triangle (skull-like) for dungeon entrances
	var points := PackedVector2Array([
		Vector2(pos.x - size, pos.y - size * 0.8),
		Vector2(pos.x + size, pos.y - size * 0.8),
		Vector2(pos.x, pos.y + size),
	])
	map_canvas.draw_colored_polygon(points, COLOR_DUNGEON)


func _draw_shrine_icon(pos: Vector2, size: float) -> void:
	# Simple 4-point star
	var points := PackedVector2Array([
		Vector2(pos.x, pos.y - size * 1.3),
		Vector2(pos.x + size * 0.3, pos.y - size * 0.3),
		Vector2(pos.x + size * 1.3, pos.y),
		Vector2(pos.x + size * 0.3, pos.y + size * 0.3),
		Vector2(pos.x, pos.y + size * 1.3),
		Vector2(pos.x - size * 0.3, pos.y + size * 0.3),
		Vector2(pos.x - size * 1.3, pos.y),
		Vector2(pos.x - size * 0.3, pos.y - size * 0.3),
	])
	map_canvas.draw_colored_polygon(points, COLOR_SHRINE)


func _draw_entities(center: Vector2, view_center: Vector2, pixel_size: float) -> void:
	# Draw enemies
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not enemy is Node3D:
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue

		var enemy_cell := MapTracker.world_to_cell((enemy as Node3D).global_position)

		# Only show in revealed cells
		if not MapTracker.is_cell_revealed(enemy_cell):
			continue

		var rel_cell := Vector2(enemy_cell) - view_center
		var pixel_pos := center + rel_cell * pixel_size

		if pixel_pos.x < -10 or pixel_pos.x > map_container.size.x + 10:
			continue
		if pixel_pos.y < -10 or pixel_pos.y > map_container.size.y + 10:
			continue

		var marker_size := 2.0 * current_zoom
		map_canvas.draw_rect(Rect2(pixel_pos - Vector2(marker_size, marker_size), Vector2(marker_size * 2, marker_size * 2)), COLOR_ENEMY)


func _update_player_marker() -> void:
	if not player:
		player_marker.visible = false
		return

	player_marker.visible = true

	var container_size := map_container.size
	var center := container_size / 2.0
	var pixel_size := CELL_PIXEL_SIZE * current_zoom

	# Player position relative to view center
	var view_center := Vector2(player_cell) + pan_offset
	var rel_pos := Vector2(player_cell) - view_center
	var pixel_pos := center + rel_pos * pixel_size

	player_marker.position = pixel_pos - player_marker.size / 2.0

	# Rotate based on player/camera facing
	var camera := get_viewport().get_camera_3d()
	if camera:
		player_marker.rotation = -camera.global_rotation.y
	else:
		player_marker.rotation = -player.global_rotation.y

	player_marker.queue_redraw()


func _check_marker_click(pos: Vector2) -> void:
	if not MapTracker:
		return

	var container_size := map_container.size
	var center := container_size / 2.0
	var pixel_size := CELL_PIXEL_SIZE * current_zoom
	var view_center := Vector2(player_cell) + pan_offset

	# Adjust position for header offset
	var adjusted_pos := pos - Vector2(0, 24)

	for marker in MapTracker.get_markers():
		var marker_pos := Vector3(marker.position.x, marker.position.y, marker.position.z)
		var marker_cell := MapTracker.world_to_cell(marker_pos)
		var rel_cell := Vector2(marker_cell) - view_center
		var pixel_pos := center + rel_cell * pixel_size

		if adjusted_pos.distance_to(pixel_pos) < 10 * current_zoom:
			marker_clicked.emit(marker)
			_show_marker_tooltip(marker, pos)
			return


func _update_tooltip_at_position(pos: Vector2) -> void:
	if not MapTracker:
		tooltip_panel.visible = false
		return

	var container_size := map_container.size
	var center := container_size / 2.0
	var pixel_size := CELL_PIXEL_SIZE * current_zoom
	var view_center := Vector2(player_cell) + pan_offset

	# Adjust position for header offset
	var adjusted_pos := pos - Vector2(0, 24)

	for marker in MapTracker.get_markers():
		var marker_pos := Vector3(marker.position.x, marker.position.y, marker.position.z)
		var marker_cell := MapTracker.world_to_cell(marker_pos)
		var rel_cell := Vector2(marker_cell) - view_center
		var pixel_pos := center + rel_cell * pixel_size

		if adjusted_pos.distance_to(pixel_pos) < 8 * current_zoom:
			_show_marker_tooltip(marker, pos)
			return

	tooltip_panel.visible = false


func _show_marker_tooltip(marker: Dictionary, pos: Vector2) -> void:
	var label_text: String = marker.get("label", "")
	if label_text.is_empty():
		label_text = str(marker.get("type", "Unknown")).capitalize()

	tooltip_label.text = label_text
	tooltip_panel.visible = true
	tooltip_panel.reset_size()

	# Position near cursor
	var tooltip_pos := pos + Vector2(10, 10)
	if tooltip_pos.x + tooltip_panel.size.x > size.x:
		tooltip_pos.x = pos.x - tooltip_panel.size.x - 5
	if tooltip_pos.y + tooltip_panel.size.y > size.y:
		tooltip_pos.y = size.y - tooltip_panel.size.y - 5

	tooltip_panel.position = tooltip_pos


func _on_map_updated() -> void:
	map_canvas.queue_redraw()


func _on_cell_revealed(_cell: Vector2i) -> void:
	map_canvas.queue_redraw()


## Center view on player
func reset_to_player() -> void:
	pan_offset = Vector2.ZERO
	center_on_player = true
	if center_toggle:
		center_toggle.button_pressed = true
