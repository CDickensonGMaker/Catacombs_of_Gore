## map_tracker.gd - Tracks player exploration and manages auto-map data
## Autoload singleton for persistent map tracking across zones
extends Node

signal cell_revealed(cell: Vector2i)
signal room_entered(room_data: Dictionary)
signal map_updated()
signal location_discovered(zone_id: String)

## Cell size in world units
const CELL_SIZE := 2.0

## Reveal radius around player (in cells)
const REVEAL_RADIUS := 4

## Update interval (seconds)
const UPDATE_INTERVAL := 0.25

## Current zone's map data
var current_map: Dictionary = {
	"zone_id": "",
	"revealed_cells": {},  # Vector2i key -> bool
	"rooms": [],
	"markers": [],
	"bounds": Rect2()
}

## All zone maps (for world map)
var zone_maps: Dictionary = {}  # zone_id -> map_data

## Discovered locations (for world map fast travel)
var discovered_locations: Dictionary = {}  # zone_id -> bool

## Timer for updates
var update_timer: float = 0.0

## Reference to current dungeon generator (if any)
var current_dungeon: DungeonGenerator = null


func _ready() -> void:
	# Connect to scene changes
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		_update_exploration()


## Update exploration based on player position
func _update_exploration() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return

	var player_cell := world_to_cell(player.global_position)

	# Reveal cells around player
	var revealed_any := false
	for dx in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
		for dz in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
			# Circular reveal
			if dx * dx + dz * dz <= REVEAL_RADIUS * REVEAL_RADIUS:
				var cell := Vector2i(player_cell.x + dx, player_cell.y + dz)
				if _reveal_cell(cell):
					revealed_any = true

	if revealed_any:
		map_updated.emit()

	# Check if player entered a new room (for procedural dungeons)
	_check_room_entry(player.global_position)


## Reveal a single cell, returns true if newly revealed
func _reveal_cell(cell: Vector2i) -> bool:
	var key := _cell_to_key(cell)
	if current_map.revealed_cells.has(key):
		return false

	current_map.revealed_cells[key] = true

	# Update bounds
	var cell_rect := Rect2(
		Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE),
		Vector2(CELL_SIZE, CELL_SIZE)
	)
	if current_map.bounds.size == Vector2.ZERO:
		current_map.bounds = cell_rect
	else:
		current_map.bounds = current_map.bounds.merge(cell_rect)

	cell_revealed.emit(cell)
	return true


## Check if player entered a new room
func _check_room_entry(world_pos: Vector3) -> void:
	if not current_dungeon:
		return

	var room := current_dungeon.get_room_at_position(world_pos)
	if room and not room.is_explored:
		room.mark_explored()
		room_entered.emit({
			"index": room.room_index,
			"type": room.template.room_type,
			"bounds": _rect2_to_dict(room.get_map_bounds())
		})


## Convert world position to cell coordinates
func world_to_cell(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / CELL_SIZE)),
		int(floor(world_pos.z / CELL_SIZE))
	)


## Convert cell to world position (center of cell)
func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		(cell.x + 0.5) * CELL_SIZE,
		0,
		(cell.y + 0.5) * CELL_SIZE
	)


## Cell to string key for dictionary
func _cell_to_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


## Key to cell
func _key_to_cell(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() == 2:
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO


## Check if a cell is revealed
func is_cell_revealed(cell: Vector2i) -> bool:
	return current_map.revealed_cells.has(_cell_to_key(cell))


## Get all revealed cells as array
func get_revealed_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for key in current_map.revealed_cells.keys():
		cells.append(_key_to_cell(key))
	return cells


## Initialize map for a new zone
func init_zone(zone_id: String) -> void:
	# Save current zone if any
	if not current_map.zone_id.is_empty():
		zone_maps[current_map.zone_id] = current_map.duplicate(true)

	# Check if we have saved data for this zone
	if zone_maps.has(zone_id):
		current_map = zone_maps[zone_id].duplicate(true)
	else:
		current_map = {
			"zone_id": zone_id,
			"revealed_cells": {},
			"rooms": [],
			"markers": [],
			"bounds": Rect2()
		}

	# Find dungeon generator if exists
	current_dungeon = get_tree().get_first_node_in_group("dungeon") as DungeonGenerator

	# Auto-discover this location
	discover_location(zone_id)

	print("[MapTracker] Initialized map for zone: %s" % zone_id)


## Register rooms from dungeon generator
func register_dungeon_rooms(dungeon: DungeonGenerator) -> void:
	current_dungeon = dungeon
	current_map.rooms.clear()

	for room in dungeon.rooms:
		current_map.rooms.append({
			"index": room.room_index,
			"type": room.template.room_type,
			"bounds": _rect2_to_dict(room.get_map_bounds()),
			"explored": room.is_explored,
			"cleared": room.is_cleared
		})


## Add a marker to the map
func add_marker(world_pos: Vector3, marker_type: String, label: String = "") -> void:
	current_map.markers.append({
		"position": {"x": world_pos.x, "y": world_pos.y, "z": world_pos.z},
		"type": marker_type,
		"label": label
	})
	map_updated.emit()


## Remove markers of a type at position
func remove_marker(world_pos: Vector3, marker_type: String) -> void:
	var to_remove: Array[int] = []
	for i in range(current_map.markers.size()):
		var marker: Dictionary = current_map.markers[i]
		if marker.type == marker_type:
			var marker_pos := Vector3(marker.position.x, marker.position.y, marker.position.z)
			if marker_pos.distance_to(world_pos) < 1.0:
				to_remove.append(i)

	for i in range(to_remove.size() - 1, -1, -1):
		current_map.markers.remove_at(to_remove[i])

	map_updated.emit()


## Get markers of a specific type
func get_markers(marker_type: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for marker in current_map.markers:
		if marker_type.is_empty() or marker.type == marker_type:
			result.append(marker)
	return result


## Get map bounds
func get_map_bounds() -> Rect2:
	return current_map.bounds


## Get current zone ID
func get_current_zone() -> String:
	return current_map.zone_id


## Discover a location (for world map)
func discover_location(zone_id: String) -> void:
	if zone_id.is_empty():
		return

	if not discovered_locations.has(zone_id):
		discovered_locations[zone_id] = true
		location_discovered.emit(zone_id)
		print("[MapTracker] Discovered location: %s" % zone_id)


## Check if a location has been discovered
func is_location_discovered(zone_id: String) -> bool:
	return discovered_locations.has(zone_id) and discovered_locations[zone_id]


## Get all discovered locations
func get_discovered_locations() -> Array[String]:
	var result: Array[String] = []
	for zone_id in discovered_locations.keys():
		if discovered_locations[zone_id]:
			result.append(zone_id)
	return result


## Save map data to dictionary (for SaveManager)
func get_save_data() -> Dictionary:
	# Save current zone first
	if not current_map.zone_id.is_empty():
		zone_maps[current_map.zone_id] = current_map.duplicate(true)

	return {
		"current_zone": current_map.zone_id,
		"zone_maps": zone_maps.duplicate(true),
		"discovered_locations": discovered_locations.duplicate(true)
	}


## Load map data from dictionary
func load_save_data(data: Dictionary) -> void:
	if data.has("zone_maps"):
		zone_maps = data.zone_maps.duplicate(true)

	if data.has("discovered_locations"):
		discovered_locations = data.discovered_locations.duplicate(true)
	else:
		discovered_locations = {}

	if data.has("current_zone") and zone_maps.has(data.current_zone):
		current_map = zone_maps[data.current_zone].duplicate(true)
	else:
		current_map = {
			"zone_id": "",
			"revealed_cells": {},
			"rooms": [],
			"markers": [],
			"bounds": Rect2()
		}


## Reset all map data
func reset() -> void:
	current_map = {
		"zone_id": "",
		"revealed_cells": {},
		"rooms": [],
		"markers": [],
		"bounds": Rect2()
	}
	zone_maps.clear()
	discovered_locations.clear()
	current_dungeon = null


## Rect2 to dictionary for serialization
func _rect2_to_dict(r: Rect2) -> Dictionary:
	return {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y}


## Dictionary to Rect2
func _dict_to_rect2(d: Dictionary) -> Rect2:
	return Rect2(d.x, d.y, d.w, d.h)


## Handle new nodes added (detect zone changes)
func _on_node_added(node: Node) -> void:
	# Check if it's a level with ZONE_ID
	if node.has_method("get") and "ZONE_ID" in node:
		var zone_id: String = node.get("ZONE_ID")
		if not zone_id.is_empty():
			call_deferred("init_zone", zone_id)

	# Check if it's a dungeon generator
	if node is DungeonGenerator:
		node.generation_complete.connect(_on_dungeon_generated)


## Handle dungeon generation complete
func _on_dungeon_generated(dungeon: DungeonGenerator) -> void:
	register_dungeon_rooms(dungeon)

	# Auto-reveal entrance
	var entrance := dungeon.get_entrance_room()
	if entrance:
		var center_cell := world_to_cell(entrance.room_center)
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				_reveal_cell(Vector2i(center_cell.x + dx, center_cell.y + dz))
		entrance.mark_explored()
