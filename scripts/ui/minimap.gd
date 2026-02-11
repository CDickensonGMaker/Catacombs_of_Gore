## minimap.gd - HUD minimap showing explored areas
## Renders revealed cells, player position, enemies, and POIs
class_name Minimap
extends Control

## Minimap settings
const MAP_SIZE := Vector2(120, 120)
const CELL_PIXEL_SIZE := 4  # Pixels per cell
const VIEW_RADIUS := 15  # Cells to show from player center

## Colors
const COLOR_REVEALED := Color(0.15, 0.13, 0.18, 0.9)
const COLOR_WALL := Color(0.3, 0.25, 0.35, 1.0)
const COLOR_PLAYER := Color(0.3, 0.9, 0.4, 1.0)
const COLOR_ENEMY := Color(0.9, 0.2, 0.2, 1.0)
const COLOR_CHEST := Color(0.9, 0.8, 0.2, 1.0)
const COLOR_PORTAL := Color(0.3, 0.5, 0.9, 1.0)
const COLOR_NPC := Color(0.2, 0.7, 0.9, 1.0)
const COLOR_ROOM_OUTLINE := Color(0.4, 0.35, 0.45, 0.8)
const COLOR_QUEST_MAIN := Color(1.0, 0.85, 0.2, 1.0)  # Gold for main quest
const COLOR_QUEST_SIDE := Color(0.2, 0.8, 0.8, 1.0)   # Teal for side quests
const COLOR_QUEST_TURNIN := Color(0.2, 1.0, 0.3, 1.0) # Green for turn-in ready
const COLOR_QUEST_DISTANT := Color(0.9, 0.7, 0.3, 0.8) # Dim gold for distant objectives

## Distance thresholds for quest markers
const MARKER_VISIBLE_RANGE := 150.0  # World units - show normal marker within this range
const STREAMING_RADIUS := 300.0  # Approximate streaming radius for chunk loading

## POI Colors for shops, temples, guilds
const COLOR_SHOP := Color(0.9, 0.75, 0.3, 1.0)        # Gold/tan for merchants
const COLOR_TEMPLE := Color(0.9, 0.9, 1.0, 1.0)       # White/silver for temples
const COLOR_GUILD := Color(0.6, 0.4, 0.8, 1.0)        # Purple for guilds
const COLOR_INN := Color(0.8, 0.5, 0.2, 1.0)          # Orange for inns/taverns
const COLOR_BLACKSMITH := Color(0.5, 0.5, 0.6, 1.0)   # Steel gray for blacksmiths
const COLOR_FIREPLACE := Color(1.0, 0.5, 0.2, 1.0)    # Warm orange for campfires/fireplaces
const COLOR_FAST_TRAVEL := Color(0.4, 0.9, 1.0, 1.0)  # Cyan for fast travel shrines

## Components
var background: ColorRect
var map_container: Control
var player_marker: Control
var entity_markers: Array[Control] = []
var quest_markers: Array[Control] = []
var poi_markers: Array[Control] = []  # Shops, temples, guilds

## Cached player reference
var player: Node3D = null
var player_cell: Vector2i = Vector2i.ZERO

## Quest marker data (updated each frame)
var _quest_marker_data: Array[Dictionary] = []


func _ready() -> void:
	# Set size
	custom_minimum_size = MAP_SIZE
	size = MAP_SIZE

	# Position in top-right corner
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -MAP_SIZE.x - 10
	offset_right = -10
	offset_top = 40  # Below compass
	offset_bottom = 40 + MAP_SIZE.y

	_setup_ui()

	# Connect to MapTracker signals
	if MapTracker:
		MapTracker.map_updated.connect(_on_map_updated)
		MapTracker.cell_revealed.connect(_on_cell_revealed)


func _setup_ui() -> void:
	# Background with border
	background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.05, 0.04, 0.06, 0.85)
	background.set_anchors_preset(PRESET_FULL_RECT)
	add_child(background)

	# Border
	var border := ColorRect.new()
	border.name = "Border"
	border.color = Color(0.3, 0.25, 0.35, 1.0)
	border.set_anchors_preset(PRESET_FULL_RECT)
	border.offset_left = -2
	border.offset_top = -2
	border.offset_right = 2
	border.offset_bottom = 2
	border.z_index = -1
	add_child(border)

	# Container for map drawing (clipped)
	map_container = Control.new()
	map_container.name = "MapContainer"
	map_container.clip_contents = true
	map_container.set_anchors_preset(PRESET_FULL_RECT)
	map_container.offset_left = 2
	map_container.offset_top = 2
	map_container.offset_right = -2
	map_container.offset_bottom = -2
	add_child(map_container)

	# Player marker (triangle pointing in facing direction)
	player_marker = _create_player_marker()
	add_child(player_marker)


func _create_player_marker() -> Control:
	var marker := Control.new()
	marker.name = "PlayerMarker"
	marker.custom_minimum_size = Vector2(8, 8)
	marker.size = Vector2(8, 8)

	# Draw will be handled in _draw
	marker.draw.connect(_draw_player_marker.bind(marker))

	return marker


func _draw_player_marker(marker: Control) -> void:
	# Triangle pointing up (will be rotated)
	var points := PackedVector2Array([
		Vector2(4, 0),   # Top
		Vector2(0, 8),   # Bottom left
		Vector2(8, 8),   # Bottom right
	])
	marker.draw_colored_polygon(points, COLOR_PLAYER)


func _process(_delta: float) -> void:
	if not visible:
		return

	# Get player
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D

	if not player:
		return

	# Update player cell
	if MapTracker:
		player_cell = MapTracker.world_to_cell(player.global_position)

	# Request redraw
	queue_redraw()
	_update_player_marker()
	_update_entity_markers()
	_update_quest_markers()
	_update_poi_markers()


func _draw() -> void:
	if not MapTracker:
		return

	var center := MAP_SIZE / 2.0
	var offset := Vector2(2, 2)  # Border offset

	# Draw revealed cells
	for cell in MapTracker.get_revealed_cells():
		var rel_cell := cell - player_cell
		if abs(rel_cell.x) > VIEW_RADIUS or abs(rel_cell.y) > VIEW_RADIUS:
			continue

		var pixel_pos := center + Vector2(rel_cell.x, rel_cell.y) * CELL_PIXEL_SIZE
		var rect := Rect2(pixel_pos - Vector2(CELL_PIXEL_SIZE / 2.0, CELL_PIXEL_SIZE / 2.0), Vector2(CELL_PIXEL_SIZE, CELL_PIXEL_SIZE))

		# Check if cell is on room edge (for wall rendering)
		var is_edge := _is_edge_cell(cell)
		var color := COLOR_WALL if is_edge else COLOR_REVEALED
		draw_rect(rect, color)

	# Draw room outlines if in dungeon
	_draw_room_outlines(center)

	# Draw markers (chests, portals, etc.)
	_draw_markers(center)


## Check if a cell is on the edge of revealed area (wall)
func _is_edge_cell(cell: Vector2i) -> bool:
	# Check adjacent cells
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


## Draw room outlines from dungeon data
func _draw_room_outlines(center: Vector2) -> void:
	if MapTracker.current_map.rooms.is_empty():
		return

	for room_data in MapTracker.current_map.rooms:
		if not room_data.get("explored", false):
			continue

		var bounds: Dictionary = room_data.get("bounds", {})
		if bounds.is_empty():
			continue

		# Convert room bounds to minimap coords
		var room_rect := Rect2(bounds.x, bounds.y, bounds.w, bounds.h)
		var room_center := room_rect.get_center()
		var player_world := Vector2(player_cell.x * MapTracker.CELL_SIZE, player_cell.y * MapTracker.CELL_SIZE)

		var rel_pos := (room_center - player_world) / MapTracker.CELL_SIZE * CELL_PIXEL_SIZE
		var map_pos := center + rel_pos
		var map_size := room_rect.size / MapTracker.CELL_SIZE * CELL_PIXEL_SIZE

		var draw_rect := Rect2(map_pos - map_size / 2.0, map_size)

		# Only draw if on screen
		if draw_rect.intersects(Rect2(Vector2.ZERO, MAP_SIZE)):
			draw_rect(draw_rect, COLOR_ROOM_OUTLINE, false, 1.0)


## Draw map markers
func _draw_markers(center: Vector2) -> void:
	for marker in MapTracker.get_markers():
		var marker_pos := Vector3(marker.position.x, marker.position.y, marker.position.z)
		var marker_cell := MapTracker.world_to_cell(marker_pos)
		var rel_cell := marker_cell - player_cell

		if abs(rel_cell.x) > VIEW_RADIUS or abs(rel_cell.y) > VIEW_RADIUS:
			continue

		var pixel_pos := center + Vector2(rel_cell.x, rel_cell.y) * CELL_PIXEL_SIZE
		var color: Color

		match marker.type:
			"chest":
				color = COLOR_CHEST
				draw_rect(Rect2(pixel_pos - Vector2(2, 2), Vector2(4, 4)), color)
			"portal":
				color = COLOR_PORTAL
				draw_circle(pixel_pos, 3, color)
			"npc":
				color = COLOR_NPC
				draw_circle(pixel_pos, 2, color)
			_:
				color = Color.WHITE
				draw_circle(pixel_pos, 2, color)


## Update player marker position and rotation
func _update_player_marker() -> void:
	if not player:
		return

	# Center of minimap
	player_marker.position = MAP_SIZE / 2.0 - player_marker.size / 2.0

	# Rotate based on player/camera facing
	var camera := get_viewport().get_camera_3d()
	if camera:
		player_marker.rotation = -camera.global_rotation.y
	else:
		player_marker.rotation = -player.global_rotation.y

	player_marker.queue_redraw()


## Update entity markers (enemies, items)
func _update_entity_markers() -> void:
	# Clear old markers
	for marker in entity_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	entity_markers.clear()

	var center := MAP_SIZE / 2.0

	# Add enemy markers
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not enemy is Node3D:
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue

		var enemy_cell := MapTracker.world_to_cell((enemy as Node3D).global_position)
		var rel_cell := enemy_cell - player_cell

		# Only show nearby enemies
		if abs(rel_cell.x) > VIEW_RADIUS or abs(rel_cell.y) > VIEW_RADIUS:
			continue

		# Only show in revealed cells
		if not MapTracker.is_cell_revealed(enemy_cell):
			continue

		var pixel_pos := center + Vector2(rel_cell.x, rel_cell.y) * CELL_PIXEL_SIZE

		var marker := ColorRect.new()
		marker.color = COLOR_ENEMY
		marker.size = Vector2(4, 4)
		marker.position = pixel_pos - Vector2(2, 2)
		add_child(marker)
		entity_markers.append(marker)

	# Add world item markers
	var items := get_tree().get_nodes_in_group("world_items")
	for item in items:
		if not item is Node3D:
			continue

		var item_cell := MapTracker.world_to_cell((item as Node3D).global_position)
		var rel_cell := item_cell - player_cell

		if abs(rel_cell.x) > VIEW_RADIUS or abs(rel_cell.y) > VIEW_RADIUS:
			continue

		if not MapTracker.is_cell_revealed(item_cell):
			continue

		var pixel_pos := center + Vector2(rel_cell.x, rel_cell.y) * CELL_PIXEL_SIZE

		var marker := ColorRect.new()
		marker.color = COLOR_CHEST
		marker.size = Vector2(3, 3)
		marker.position = pixel_pos - Vector2(1.5, 1.5)
		add_child(marker)
		entity_markers.append(marker)


## Update quest markers on minimap
## Shows ALL active quest objectives, not just the tracked one
## Uses QuestManager's cached objective locations for cross-zone awareness
func _update_quest_markers() -> void:
	# Clear old markers
	for marker in quest_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	quest_markers.clear()
	_quest_marker_data.clear()

	if not player:
		return

	var center := MAP_SIZE / 2.0
	var player_pos: Vector3 = player.global_position

	# Get all active quests
	var active_quests: Array = QuestManager.get_active_quests() if QuestManager else []

	for quest in active_quests:
		# Check if all objectives are complete (turn-in ready)
		var all_complete: bool = QuestManager.are_objectives_complete(quest.id)
		var is_main: bool = quest.is_main_quest if "is_main_quest" in quest else false

		if all_complete:
			# Point to turn-in location - first try QuestManager cached location
			var turnin_pos: Vector3 = _get_turnin_world_position(quest)
			if turnin_pos != Vector3.ZERO and turnin_pos != Vector3.INF:
				var distance: float = player_pos.distance_to(turnin_pos)
				_add_quest_marker_with_distance(turnin_pos, COLOR_QUEST_TURNIN, "!", center, distance)
			else:
				# Fallback to scene search
				var giver_pos := _find_quest_giver_world_position(quest)
				if giver_pos != Vector3.INF:
					var distance: float = player_pos.distance_to(giver_pos)
					_add_quest_marker_with_distance(giver_pos, COLOR_QUEST_TURNIN, "!", center, distance)
		else:
			# Show markers for each incomplete objective
			for obj in quest.objectives:
				if obj.is_completed or obj.is_optional:
					continue

				var color: Color = COLOR_QUEST_MAIN if is_main else COLOR_QUEST_SIDE

				# First try QuestManager's cached objective location
				var cached_pos: Vector3 = QuestManager.get_objective_world_pos(quest.id, obj.id)
				if cached_pos != Vector3.ZERO:
					var distance: float = player_pos.distance_to(cached_pos)
					_add_quest_marker_with_distance(cached_pos, color, "*", center, distance)
				else:
					# Fallback to scene search for nearby entities
					var obj_positions := _find_objective_world_positions(obj, quest)
					for pos: Vector3 in obj_positions:
						var distance: float = player_pos.distance_to(pos)
						_add_quest_marker_with_distance(pos, color, "*", center, distance)


## Get turn-in world position from QuestManager cached data
func _get_turnin_world_position(quest) -> Vector3:
	if not QuestManager:
		return Vector3.ZERO

	# Check for cached turn-in location
	var turnin_hex: Vector2i = QuestManager.get_turnin_hex(quest.id)
	if turnin_hex != Vector2i.ZERO:
		return WorldData.axial_to_world(turnin_hex)

	return Vector3.ZERO


## Add a quest marker at a world position with distance-based rendering
func _add_quest_marker_with_distance(world_pos: Vector3, color: Color, icon: String, center: Vector2, distance: float) -> void:
	if not MapTracker:
		return

	var target_cell := MapTracker.world_to_cell(world_pos)
	var rel_cell := target_cell - player_cell

	# Calculate pixel position
	var pixel_pos := center + Vector2(rel_cell.x, rel_cell.y) * CELL_PIXEL_SIZE

	# Check if on screen or needs edge indicator
	var is_on_map: bool = pixel_pos.x >= 0 and pixel_pos.x <= MAP_SIZE.x and pixel_pos.y >= 0 and pixel_pos.y <= MAP_SIZE.y

	# Determine marker style based on distance
	var is_nearby: bool = distance <= MARKER_VISIBLE_RANGE
	var is_within_streaming: bool = distance <= STREAMING_RADIUS
	var display_color: Color = color

	# Dim color for distant objectives
	if not is_nearby:
		display_color = COLOR_QUEST_DISTANT
		# Blend with original color based on distance
		var blend_factor: float = clampf((distance - MARKER_VISIBLE_RANGE) / (STREAMING_RADIUS - MARKER_VISIBLE_RANGE), 0.0, 1.0)
		display_color = color.lerp(COLOR_QUEST_DISTANT, blend_factor * 0.5)

	if is_on_map and is_nearby:
		# Draw normal marker on map - objective is nearby
		var marker := Label.new()
		marker.text = icon
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker.add_theme_font_size_override("font_size", 12)
		marker.add_theme_color_override("font_color", display_color)
		marker.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		marker.add_theme_constant_override("outline_size", 2)
		marker.size = Vector2(16, 16)
		marker.position = pixel_pos - Vector2(8, 8)
		add_child(marker)
		quest_markers.append(marker)
	else:
		# Draw edge indicator (arrow pointing to distant objective)
		var direction := pixel_pos - center
		if direction.length_squared() < 0.1:
			direction = Vector2.RIGHT  # Default direction if too close
		var angle := direction.angle()

		# Clamp to edge of minimap
		var edge_pos := center + direction.normalized() * (min(MAP_SIZE.x, MAP_SIZE.y) / 2.0 - 10)

		# Create arrow indicator
		var marker := _create_edge_arrow_indicator(edge_pos, angle, display_color, distance, is_within_streaming)
		add_child(marker)
		quest_markers.append(marker)


## Create an edge arrow indicator for distant objectives
func _create_edge_arrow_indicator(edge_pos: Vector2, angle: float, color: Color, distance: float, is_within_streaming: bool) -> Control:
	var container := Control.new()
	container.size = Vector2(24, 24)
	container.position = edge_pos - Vector2(12, 12)

	# Arrow indicator
	var arrow := Label.new()
	arrow.text = ">" if is_within_streaming else ">>"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 14 if is_within_streaming else 12)
	arrow.add_theme_color_override("font_color", color)
	arrow.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	arrow.add_theme_constant_override("outline_size", 2)
	arrow.size = Vector2(24, 24)
	arrow.pivot_offset = Vector2(12, 12)
	arrow.rotation = angle
	container.add_child(arrow)

	# Distance indicator for very distant objectives
	if not is_within_streaming:
		var dist_label := Label.new()
		var dist_text: String = ""
		if distance > 1000:
			dist_text = "%dkm" % roundi(distance / 1000.0)
		else:
			dist_text = "%dm" % roundi(distance)
		dist_label.text = dist_text
		dist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dist_label.add_theme_font_size_override("font_size", 8)
		dist_label.add_theme_color_override("font_color", color.darkened(0.2))
		dist_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		dist_label.add_theme_constant_override("outline_size", 1)
		dist_label.size = Vector2(30, 12)
		dist_label.position = Vector2(-3, 14)
		container.add_child(dist_label)

	return container


## Legacy function - calls new distance-aware version
func _add_quest_marker_at_world_pos(world_pos: Vector3, color: Color, icon: String, center: Vector2) -> void:
	var distance: float = 0.0
	if player:
		distance = player.global_position.distance_to(world_pos)
	_add_quest_marker_with_distance(world_pos, color, icon, center, distance)


## Find world position of quest giver for turn-in
func _find_quest_giver_world_position(quest) -> Vector3:
	var giver_id: String = quest.giver_npc_id if "giver_npc_id" in quest else ""

	# Search for NPC in current zone
	var npcs := get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		if npc is Node3D:
			var npc_id_val: String = ""
			if "npc_id" in npc:
				npc_id_val = str(npc.get("npc_id"))
			if npc_id_val == giver_id:
				return (npc as Node3D).global_position

	return Vector3.INF


## Find world positions of objective targets
func _find_objective_world_positions(objective, quest) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	match objective.type:
		"kill":
			# Find enemies of target type
			var enemies := get_tree().get_nodes_in_group("enemies")
			for enemy in enemies:
				if enemy is Node3D and enemy.has_method("get_enemy_data"):
					var enemy_data = enemy.get_enemy_data()
					if enemy_data and (enemy_data.id == objective.target or enemy_data.id.begins_with(objective.target)):
						if not (enemy.has_method("is_dead") and enemy.is_dead()):
							positions.append((enemy as Node3D).global_position)
							if positions.size() >= 3:  # Limit to 3 markers per objective
								break

		"talk":
			# Find NPC to talk to
			var npcs := get_tree().get_nodes_in_group("npcs")
			for npc in npcs:
				if npc is Node3D:
					var npc_id_val: String = ""
					if "npc_id" in npc:
						npc_id_val = str(npc.get("npc_id"))
					if npc_id_val == objective.target:
						positions.append((npc as Node3D).global_position)
						break

		"collect":
			# Find items on ground
			var items := get_tree().get_nodes_in_group("world_items")
			for item in items:
				if item is Node3D and item.has_method("get_item_id"):
					if item.get_item_id() == objective.target:
						positions.append((item as Node3D).global_position)
						if positions.size() >= 3:
							break

		"explore":
			# Find zone entrances
			var doors := get_tree().get_nodes_in_group("zone_doors")
			for door in doors:
				if door is Node3D:
					if "target_scene" in door:
						var target: String = door.target_scene
						if objective.target in target:
							positions.append((door as Node3D).global_position)
							break

	return positions


## Update POI markers (shops, temples, guilds, inns, fireplaces, fast travel)
func _update_poi_markers() -> void:
	# Clear old markers
	for marker in poi_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	poi_markers.clear()

	if not player or not MapTracker:
		return

	var center := MAP_SIZE / 2.0

	# Define POI types to look for with their groups, icons, and colors
	var poi_types: Array[Dictionary] = [
		{"group": "merchants", "icon": "$", "color": COLOR_SHOP},
		{"group": "shops", "icon": "$", "color": COLOR_SHOP},
		{"group": "blacksmiths", "icon": "⚒", "color": COLOR_BLACKSMITH},
		{"group": "temples", "icon": "†", "color": COLOR_TEMPLE},
		{"group": "shrines", "icon": "†", "color": COLOR_TEMPLE},
		{"group": "guilds", "icon": "⚔", "color": COLOR_GUILD},
		{"group": "inns", "icon": "🏠", "color": COLOR_INN},
		{"group": "taverns", "icon": "🍺", "color": COLOR_INN},
		{"group": "innkeepers", "icon": "🏠", "color": COLOR_INN},
		{"group": "fireplaces", "icon": "🔥", "color": COLOR_FIREPLACE},
		{"group": "campfires", "icon": "🔥", "color": COLOR_FIREPLACE},
		{"group": "fast_travel", "icon": "◈", "color": COLOR_FAST_TRAVEL},
		{"group": "fast_travel_shrines", "icon": "◈", "color": COLOR_FAST_TRAVEL},
	]

	for poi_type: Dictionary in poi_types:
		var group_name: String = poi_type["group"]
		var icon: String = poi_type["icon"]
		var color: Color = poi_type["color"]

		var pois := get_tree().get_nodes_in_group(group_name)
		for poi in pois:
			if not poi is Node3D:
				continue

			var poi_node := poi as Node3D
			var poi_cell := MapTracker.world_to_cell(poi_node.global_position)
			var rel_cell := poi_cell - player_cell

			# Only show nearby POIs
			if abs(rel_cell.x) > VIEW_RADIUS or abs(rel_cell.y) > VIEW_RADIUS:
				continue

			var pixel_pos := center + Vector2(rel_cell.x, rel_cell.y) * CELL_PIXEL_SIZE

			# Check if on screen
			if pixel_pos.x < 0 or pixel_pos.x > MAP_SIZE.x or pixel_pos.y < 0 or pixel_pos.y > MAP_SIZE.y:
				continue

			# Create marker
			var marker := Label.new()
			marker.text = icon
			marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			marker.add_theme_font_size_override("font_size", 10)
			marker.add_theme_color_override("font_color", color)
			marker.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			marker.add_theme_constant_override("outline_size", 1)
			marker.size = Vector2(12, 12)
			marker.position = pixel_pos - Vector2(6, 6)

			# Add tooltip if POI has a name
			if "display_name" in poi:
				marker.tooltip_text = poi.display_name
			elif "shop_name" in poi:
				marker.tooltip_text = poi.shop_name

			add_child(marker)
			poi_markers.append(marker)


## Signal handlers
func _on_map_updated() -> void:
	queue_redraw()


func _on_cell_revealed(_cell: Vector2i) -> void:
	queue_redraw()
