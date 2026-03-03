## player_gps.gd - Tracks player position in the world grid
## Single source of truth for player location and cell discovery
## Replaces world_manager.gd + map_tracker.gd
extends Node

## Emitted when player enters a new cell
signal cell_changed(old_cell: Vector2i, new_cell: Vector2i)

## Emitted when a new location is discovered
signal location_discovered(location_id: String, location_name: String)

## Emitted when player enters a new region
signal region_changed(old_region: String, new_region: String)

## Emitted when a cell is revealed on the map
signal cell_revealed(coords: Vector2i)


## Current cell the player is in (Elder Moor-relative coordinates)
var current_cell: Vector2i = Vector2i.ZERO

## Previous cell (for transition tracking)
var previous_cell: Vector2i = Vector2i.ZERO

## Current region name
var current_region: String = "Elder Moor"

## Current location ID (empty if in wilderness)
var current_location_id: String = "elder_moor"

## Dictionary of discovered cells: Vector2i -> discovery_timestamp (float)
var discovered_cells: Dictionary = {}

## Dictionary of discovered locations: location_id -> {name, coords, discovered_time}
var discovered_locations: Dictionary = {}

## Statistics
var total_cells_traveled: int = 0
var total_distance_traveled: int = 0

## ============================================================================
## NPC REGISTRY - Tracks NPCs by cell for streaming/minimap
## ============================================================================

## Registered NPCs: npc_id -> {node: Node3D, cell: Vector2i, type: String, zone_id: String}
var registered_npcs: Dictionary = {}


func _ready() -> void:
	# Initialize with starting location discovered (no XP - it's where you spawn)
	discover_cell(Vector2i.ZERO)
	_discover_location_at(Vector2i.ZERO, false)  # false = no discovery XP for starting location

	# Connect to scene manager to clear node references before scene changes
	if SceneManager:
		SceneManager.scene_load_started.connect(_on_scene_load_started)


## Called when a scene change begins - clear all node references to prevent stale casts
func _on_scene_load_started(_scene_path: String) -> void:
	_clear_node_references()


## Clear all node references to prevent "Trying to cast a freed object" errors
## Called at the START of scene transitions, before the old scene is freed
func _clear_node_references() -> void:
	# Clear all NPC registrations since they will be freed with the old scene
	registered_npcs.clear()


## Update the current cell (called by CellStreamer when player crosses boundary)
func update_cell(new_cell: Vector2i) -> void:
	if new_cell == current_cell:
		return

	previous_cell = current_cell
	var old_cell := current_cell
	current_cell = new_cell

	# Track statistics
	total_cells_traveled += 1
	total_distance_traveled += WorldGrid.grid_distance(old_cell, new_cell)

	# Auto-discover the new cell
	discover_cell(new_cell)

	# Check for location discovery
	_discover_location_at(new_cell)

	# Check for region change
	var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(new_cell)
	if cell_info and cell_info.region_name != current_region:
		var old_region := current_region
		current_region = cell_info.region_name
		region_changed.emit(old_region, current_region)

	# Update current location ID
	if cell_info and cell_info.location_id != "":
		current_location_id = cell_info.location_id
	else:
		current_location_id = ""

	# Emit cell changed signal
	cell_changed.emit(old_cell, new_cell)

	print("[PlayerGPS] Cell changed: %s -> %s" % [old_cell, new_cell])


## Discover a cell (reveal on map)
func discover_cell(coords: Vector2i) -> void:
	if discovered_cells.has(coords):
		return

	discovered_cells[coords] = Time.get_unix_time_from_system()

	# Also mark in WorldGrid (uses Elder Moor-relative coords)
	WorldGrid.discover_cell(coords)

	# Also mark in WorldData (uses grid coords with Elder Moor at 12,8)
	# Convert from WorldGrid coords (Elder Moor = 0,0) to WorldData grid coords
	var grid_coords: Vector2i = WorldData.region_to_grid(coords)
	WorldData.discover_cell(grid_coords)

	cell_revealed.emit(coords)


## Check if a cell has been discovered
func is_discovered(coords: Vector2i) -> bool:
	return discovered_cells.has(coords)


## Discover a location at coordinates (if any)
## Set award_xp=false for starting locations (player spawns there, no discovery)
func _discover_location_at(coords: Vector2i, award_xp: bool = true) -> void:
	var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(coords)
	if not cell_info:
		return

	if cell_info.location_id == "":
		return

	if discovered_locations.has(cell_info.location_id):
		return

	# New location discovered!
	discovered_locations[cell_info.location_id] = {
		"name": cell_info.location_name,
		"coords": coords,
		"type": cell_info.location_type,
		"discovered_time": Time.get_unix_time_from_system()
	}

	# Award discovery XP based on location importance (skip for starting location)
	var xp_reward: int = 0
	if award_xp:
		xp_reward = _get_discovery_xp(cell_info.location_type)
		if xp_reward > 0:
			_award_discovery_xp(xp_reward, cell_info.location_name)

	location_discovered.emit(cell_info.location_id, cell_info.location_name)
	print("[PlayerGPS] Location discovered: %s (XP: %d)" % [cell_info.location_name, xp_reward])


## Get discovery XP reward based on location type
## Small POI = 25 XP, Large city = 100 XP
func _get_discovery_xp(location_type: WorldGrid.LocationType) -> int:
	match location_type:
		WorldGrid.LocationType.CAPITAL:
			return 100  # Major discovery - capital cities
		WorldGrid.LocationType.CITY:
			return 75   # Large discovery - cities
		WorldGrid.LocationType.TOWN:
			return 50   # Medium discovery - towns
		WorldGrid.LocationType.VILLAGE:
			return 35   # Small settlement
		WorldGrid.LocationType.DUNGEON:
			return 50   # Dungeon entrances are notable discoveries
		WorldGrid.LocationType.OUTPOST:
			return 30   # Small outposts
		WorldGrid.LocationType.LANDMARK:
			return 25   # Landmarks and points of interest
		WorldGrid.LocationType.BRIDGE:
			return 25   # Bridges and crossings
		_:
			return 0    # NONE and BLOCKED give no XP


## Award discovery XP to the player
func _award_discovery_xp(amount: int, location_name: String) -> void:
	if not GameManager or not GameManager.player_data:
		return

	# Apply player's XP multiplier if they have one
	var final_xp: int = amount
	if GameManager.player_data.has_method("get_xp_multiplier"):
		final_xp = int(amount * GameManager.player_data.get_xp_multiplier())

	GameManager.player_data.add_ip(final_xp)

	# Show discovery notification with XP
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Discovered %s! (+%d XP)" % [location_name, final_xp])


## Check if a location has been discovered
func is_location_discovered(location_id: String) -> bool:
	return discovered_locations.has(location_id)


## Get all discovered locations
func get_discovered_locations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for loc_id: String in discovered_locations:
		var info: Dictionary = discovered_locations[loc_id]
		result.append({
			"id": loc_id,
			"name": info.get("name", ""),
			"coords": info.get("coords", Vector2i.ZERO),
			"type": info.get("type", WorldGrid.LocationType.NONE)
		})
	return result


## Get discovered locations in a specific region
func get_discovered_in_region(region_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for loc_id: String in discovered_locations:
		var info: Dictionary = discovered_locations[loc_id]
		var coords: Vector2i = info.get("coords", Vector2i.ZERO)
		var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(coords)
		if cell_info and cell_info.region_name == region_name:
			result.append({
				"id": loc_id,
				"name": info.get("name", ""),
				"coords": coords
			})
	return result


## Get distance from current position to a location
func get_distance_to(location_id: String) -> int:
	var coords := WorldGrid.get_location_coords(location_id)
	return WorldGrid.grid_distance(current_cell, coords)


## Alias for get_distance_to (used by fast_travel_manager)
func get_distance_from_current(location_id: String) -> int:
	return get_distance_to(location_id)


## Get distance between two locations
func get_distance_between(from_id: String, to_id: String) -> int:
	var from_coords := WorldGrid.get_location_coords(from_id)
	var to_coords := WorldGrid.get_location_coords(to_id)
	return WorldGrid.grid_distance(from_coords, to_coords)


## Manually discover a location by ID (used by fast_travel_shrine)
func discover_location(location_id: String) -> void:
	if discovered_locations.has(location_id):
		return

	var coords := WorldGrid.get_location_coords(location_id)
	var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(coords)
	if not cell_info:
		return

	# Mark the cell as discovered
	discover_cell(coords)

	# Add to discovered locations
	discovered_locations[location_id] = {
		"name": cell_info.location_name,
		"coords": coords,
		"type": cell_info.location_type,
		"discovered_time": Time.get_unix_time_from_system()
	}

	# Award discovery XP based on location importance (shrines also give XP)
	var xp_reward: int = _get_discovery_xp(cell_info.location_type)
	if xp_reward > 0:
		_award_discovery_xp(xp_reward, cell_info.location_name)

	location_discovered.emit(location_id, cell_info.location_name)
	print("[PlayerGPS] Location discovered via shrine: %s (XP: %d)" % [cell_info.location_name, xp_reward])


## Set current position directly (used for loading saves or fast travel)
func set_position(coords: Vector2i, skip_discovery: bool = false) -> void:
	previous_cell = current_cell
	current_cell = coords

	if not skip_discovery:
		discover_cell(coords)
		_discover_location_at(coords)

	var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(coords)
	if cell_info:
		current_region = cell_info.region_name
		current_location_id = cell_info.location_id if cell_info.location_id != "" else ""


## ============================================================================
## SAVE/LOAD
## ============================================================================

## Get save data
func get_save_data() -> Dictionary:
	# Convert Vector2i keys to string for JSON compatibility
	var cells_save: Dictionary = {}
	for coords: Vector2i in discovered_cells:
		var key: String = "%d,%d" % [coords.x, coords.y]
		cells_save[key] = discovered_cells[coords]

	var locations_save: Dictionary = {}
	for loc_id: String in discovered_locations:
		var info: Dictionary = discovered_locations[loc_id].duplicate()
		var coords: Vector2i = info.get("coords", Vector2i.ZERO)
		info["coords_x"] = coords.x
		info["coords_y"] = coords.y
		info.erase("coords")
		locations_save[loc_id] = info

	return {
		"current_cell_x": current_cell.x,
		"current_cell_y": current_cell.y,
		"current_region": current_region,
		"current_location_id": current_location_id,
		"discovered_cells": cells_save,
		"discovered_locations": locations_save,
		"total_cells_traveled": total_cells_traveled,
		"total_distance_traveled": total_distance_traveled
	}


## Load save data
func load_save_data(data: Dictionary) -> void:
	current_cell = Vector2i(
		data.get("current_cell_x", 0),
		data.get("current_cell_y", 0)
	)
	previous_cell = current_cell
	current_region = data.get("current_region", "Elder Moor")
	current_location_id = data.get("current_location_id", "")
	total_cells_traveled = data.get("total_cells_traveled", 0)
	total_distance_traveled = data.get("total_distance_traveled", 0)

	# Load discovered cells
	discovered_cells.clear()
	var cells_data: Dictionary = data.get("discovered_cells", {})
	for key: String in cells_data:
		var parts: PackedStringArray = key.split(",")
		if parts.size() == 2:
			var coords := Vector2i(int(parts[0]), int(parts[1]))
			discovered_cells[coords] = cells_data[key]
			WorldGrid.discover_cell(coords)
			# Also sync to WorldData (uses grid coords with Elder Moor at 12,8)
			var grid_coords: Vector2i = WorldData.region_to_grid(coords)
			WorldData.discover_cell(grid_coords)

	# Load discovered locations
	discovered_locations.clear()
	var locations_data: Dictionary = data.get("discovered_locations", {})
	for loc_id: String in locations_data:
		var info: Dictionary = locations_data[loc_id]
		var coords := Vector2i(
			info.get("coords_x", 0),
			info.get("coords_y", 0)
		)
		discovered_locations[loc_id] = {
			"name": info.get("name", ""),
			"coords": coords,
			"type": info.get("type", 0),
			"discovered_time": info.get("discovered_time", 0.0)
		}

	print("[PlayerGPS] Loaded save data: %d cells, %d locations" % [
		discovered_cells.size(), discovered_locations.size()
	])


## Reset all tracking (for new game)
func reset() -> void:
	current_cell = Vector2i.ZERO
	previous_cell = Vector2i.ZERO
	current_region = "Elder Moor"
	current_location_id = "elder_moor"
	discovered_cells.clear()
	discovered_locations.clear()
	total_cells_traveled = 0
	total_distance_traveled = 0

	# Discover starting location (no XP - it's where you spawn)
	discover_cell(Vector2i.ZERO)
	_discover_location_at(Vector2i.ZERO, false)  # false = no discovery XP for starting location


## Alias for get_save_data() used by save_manager.gd
func to_dict() -> Dictionary:
	# Convert to format expected by WorldManagerSaveData
	var cells_array: Array = []
	for coords: Vector2i in discovered_cells:
		cells_array.append({"x": coords.x, "y": coords.y})

	return {
		"discovered_locations": discovered_locations.duplicate(true),
		"discovered_cells": cells_array,
		"current_cell": {"x": current_cell.x, "y": current_cell.y},
		"current_region": current_region,
		"current_location_id": current_location_id,
		"cells_traveled": total_cells_traveled,
		"locations_visited": discovered_locations.size()
	}


## Alias for load_save_data() used by save_manager.gd
func from_dict(data: Dictionary) -> void:
	# Load from WorldManagerSaveData format
	current_cell = Vector2i(
		data.get("current_cell", {}).get("x", 0),
		data.get("current_cell", {}).get("y", 0)
	)
	previous_cell = current_cell
	current_region = data.get("current_region", "Elder Moor")
	current_location_id = data.get("current_location_id", "")
	total_cells_traveled = data.get("cells_traveled", 0)

	# Load discovered cells from array format
	discovered_cells.clear()
	var cells_data: Array = data.get("discovered_cells", [])
	for cell_dict in cells_data:
		if cell_dict is Dictionary:
			var coords := Vector2i(cell_dict.get("x", 0), cell_dict.get("y", 0))
			discovered_cells[coords] = Time.get_unix_time_from_system()
			WorldGrid.discover_cell(coords)
			# Also sync to WorldData (uses grid coords with Elder Moor at 12,8)
			var grid_coords: Vector2i = WorldData.region_to_grid(coords)
			WorldData.discover_cell(grid_coords)

	# Load discovered locations
	discovered_locations = data.get("discovered_locations", {}).duplicate(true)

	print("[PlayerGPS] Loaded from dict: %d cells, %d locations" % [
		discovered_cells.size(), discovered_locations.size()
	])


## ============================================================================
## NPC REGISTRY API
## ============================================================================

## Register an NPC with the GPS system
## Called by NPCs on _ready()
func register_npc(npc: Node3D, npc_id: String, npc_type: String, zone_id: String = "") -> void:
	if not is_instance_valid(npc):
		return

	var cell: Vector2i = WorldGrid.world_to_cell(npc.global_position)
	registered_npcs[npc_id] = {
		"node": npc,
		"cell": cell,
		"type": npc_type,
		"zone_id": zone_id
	}


## Unregister an NPC
## Called by NPCs on _exit_tree()
func unregister_npc(npc_id: String) -> void:
	registered_npcs.erase(npc_id)


## Get all NPCs in a specific cell
func get_npcs_in_cell(cell: Vector2i) -> Array:
	var result: Array = []
	var invalid_ids: Array[String] = []

	for npc_id: String in registered_npcs:
		var info: Dictionary = registered_npcs[npc_id]
		if info.get("cell", Vector2i(-999, -999)) == cell:
			var node_ref: Variant = info.get("node")
			var node: Node3D = node_ref as Node3D if is_instance_valid(node_ref) else null
			if node:
				result.append({"id": npc_id, "node": node, "type": info.get("type", "")})
			else:
				# Mark for cleanup
				invalid_ids.append(npc_id)

	# Clean up invalid entries
	for invalid_id: String in invalid_ids:
		registered_npcs.erase(invalid_id)

	return result


## Get all registered NPCs
func get_all_npcs() -> Array:
	var result: Array = []
	var invalid_ids: Array[String] = []

	for npc_id: String in registered_npcs:
		var info: Dictionary = registered_npcs[npc_id]
		var node_ref: Variant = info.get("node")
		var node: Node3D = node_ref as Node3D if is_instance_valid(node_ref) else null
		if node:
			result.append({
				"id": npc_id,
				"node": node,
				"type": info.get("type", ""),
				"cell": info.get("cell", Vector2i.ZERO),
				"zone_id": info.get("zone_id", "")
			})
		else:
			# Mark for cleanup
			invalid_ids.append(npc_id)

	# Clean up invalid entries
	for invalid_id: String in invalid_ids:
		registered_npcs.erase(invalid_id)

	return result


## Update an NPC's cell position (call when NPC moves significantly)
func update_npc_cell(npc_id: String, new_position: Vector3) -> void:
	if not registered_npcs.has(npc_id):
		return

	var new_cell: Vector2i = WorldGrid.world_to_cell(new_position)
	registered_npcs[npc_id]["cell"] = new_cell


## Check if an NPC is registered
func is_npc_registered(npc_id: String) -> bool:
	return registered_npcs.has(npc_id)


## Get NPC info by ID
func get_npc_info(npc_id: String) -> Dictionary:
	if not registered_npcs.has(npc_id):
		return {}

	var info: Dictionary = registered_npcs[npc_id]
	var node_ref: Variant = info.get("node")

	# Check if node is still valid
	if not is_instance_valid(node_ref):
		# Clean up invalid entry
		registered_npcs.erase(npc_id)
		return {}

	return info.duplicate()


## Clear all NPC registrations (for scene changes)
func clear_npcs() -> void:
	registered_npcs.clear()
