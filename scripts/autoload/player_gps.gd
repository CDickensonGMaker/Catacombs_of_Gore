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


func _ready() -> void:
	# Initialize with starting location discovered
	discover_cell(Vector2i.ZERO)
	_discover_location_at(Vector2i.ZERO)


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

	# Also mark in WorldGrid
	WorldGrid.discover_cell(coords)

	cell_revealed.emit(coords)


## Check if a cell has been discovered
func is_discovered(coords: Vector2i) -> bool:
	return discovered_cells.has(coords)


## Discover a location at coordinates (if any)
func _discover_location_at(coords: Vector2i) -> void:
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

	location_discovered.emit(cell_info.location_id, cell_info.location_name)
	print("[PlayerGPS] Location discovered: %s" % cell_info.location_name)


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

	location_discovered.emit(location_id, cell_info.location_name)
	print("[PlayerGPS] Location discovered via shrine: %s" % cell_info.location_name)


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

	# Discover starting location
	discover_cell(Vector2i.ZERO)
	_discover_location_at(Vector2i.ZERO)


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

	# Load discovered locations
	discovered_locations = data.get("discovered_locations", {}).duplicate(true)

	print("[PlayerGPS] Loaded from dict: %d cells, %d locations" % [
		discovered_cells.size(), discovered_locations.size()
	])
