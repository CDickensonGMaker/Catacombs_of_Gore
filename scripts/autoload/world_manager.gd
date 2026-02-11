## world_manager.gd - Manages world state, location discovery, and fast travel
## Inspired by Daggerfall Unity's hierarchical world system
extends Node

signal location_discovered(location_id: String, location_name: String, location_type: int)
signal region_entered(region_name: String)
signal cell_entered(coords: Vector2i, cell_data: WorldData.CellData)

## Discovered locations (location_id -> discovery data)
## Separate from WorldData.CellData.discovered for richer tracking
var discovered_locations: Dictionary = {}  # location_id -> {name, type, coords, discovered_time}

## Current player world position
var current_cell: Vector2i = Vector2i.ZERO
var current_region: String = ""
var current_location_id: String = ""

## Travel statistics (for achievements/stats)
var cells_traveled: int = 0
var locations_visited: int = 0


func _ready() -> void:
	# Ensure WorldData is initialized
	if WorldData.world_grid.is_empty():
		WorldData.initialize()

	# Auto-discover starting location
	discover_location_at(Vector2i.ZERO)


## Discover a location by its ID
func discover_location(location_id: String) -> void:
	if location_id.is_empty():
		return
	if discovered_locations.has(location_id):
		return  # Already discovered

	# Find location in world grid
	for coords: Vector2i in WorldData.world_grid:
		var cell: WorldData.CellData = WorldData.world_grid[coords]
		if cell.location_id == location_id:
			_register_discovery(location_id, cell.location_name, cell.location_type, coords)
			WorldData.discover_cell(coords)
			return


## Discover location at specific coordinates
func discover_location_at(coords: Vector2i) -> void:
	var cell: WorldData.CellData = WorldData.get_cell(coords)
	if not cell:
		return

	# Always mark cell as discovered
	WorldData.discover_cell(coords)

	# If cell has a location, register it
	if not cell.location_id.is_empty() and not discovered_locations.has(cell.location_id):
		_register_discovery(cell.location_id, cell.location_name, cell.location_type, coords)


## Internal: Register a discovery
func _register_discovery(location_id: String, location_name: String, location_type: int, coords: Vector2i) -> void:
	discovered_locations[location_id] = {
		"name": location_name,
		"type": location_type,
		"coords": coords,
		"discovered_time": Time.get_unix_time_from_system()
	}
	locations_visited += 1
	location_discovered.emit(location_id, location_name, location_type)


## Check if a location is discovered
func is_location_discovered(location_id: String) -> bool:
	return discovered_locations.has(location_id)


## Check if coordinates are discovered
func is_cell_discovered(coords: Vector2i) -> bool:
	return WorldData.is_discovered(coords)


## Get all discovered locations
func get_discovered_locations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for loc_id: String in discovered_locations:
		var data: Dictionary = discovered_locations[loc_id]
		result.append({
			"id": loc_id,
			"name": data.get("name", "Unknown"),
			"type": data.get("type", 0),
			"coords": _extract_coords(data.get("coords", Vector2i.ZERO))
		})
	return result


## Get discovered locations in a specific region
func get_discovered_in_region(region_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for loc_id: String in discovered_locations:
		var data: Dictionary = discovered_locations[loc_id]
		var coords: Vector2i = _extract_coords(data.get("coords", Vector2i.ZERO))
		var cell: WorldData.CellData = WorldData.get_cell(coords)
		if cell and cell.region_name == region_name:
			result.append({
				"id": loc_id,
				"name": data.get("name", "Unknown"),
				"type": data.get("type", 0),
				"coords": coords
			})
	return result


## Get discovered locations by type (settlements, dungeons, etc.)
func get_discovered_by_type(location_type: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for loc_id: String in discovered_locations:
		var data: Dictionary = discovered_locations[loc_id]
		if data.get("type", 0) == location_type:
			result.append({
				"id": loc_id,
				"name": data.get("name", "Unknown"),
				"coords": _extract_coords(data.get("coords", Vector2i.ZERO))
			})
	return result


## Called when player enters a new cell
func on_cell_entered(coords: Vector2i) -> void:
	var cell: WorldData.CellData = WorldData.get_cell(coords)
	if not cell:
		return

	cells_traveled += 1
	current_cell = coords

	# Check for region change
	if cell.region_name != current_region:
		current_region = cell.region_name
		region_entered.emit(current_region)

	# Auto-discover cell and location
	discover_location_at(coords)

	# Update current location
	current_location_id = cell.location_id

	cell_entered.emit(coords, cell)


## Get location name by ID
func get_location_name(location_id: String) -> String:
	if discovered_locations.has(location_id):
		return discovered_locations[location_id].name

	# Search in world data
	for coords: Vector2i in WorldData.world_grid:
		var cell: WorldData.CellData = WorldData.world_grid[coords]
		if cell.location_id == location_id:
			return cell.location_name

	return "Unknown Location"


## Helper to safely extract Vector2i coords from save data (handles Dict, Vector2i, or String)
func _extract_coords(coords_raw) -> Vector2i:
	if coords_raw is Vector2i:
		return coords_raw
	elif coords_raw is Dictionary:
		return Vector2i(coords_raw.get("x", 0), coords_raw.get("y", 0))
	return Vector2i.ZERO


## Get location coordinates by ID
func get_location_coords(location_id: String) -> Vector2i:
	if discovered_locations.has(location_id):
		var loc_data: Dictionary = discovered_locations[location_id]
		return _extract_coords(loc_data.get("coords", Vector2i.ZERO))

	# Search in world data
	for coords: Vector2i in WorldData.world_grid:
		var cell: WorldData.CellData = WorldData.world_grid[coords]
		if cell.location_id == location_id:
			return coords

	return Vector2i.ZERO


## Get location region by ID
func get_location_region(location_id: String) -> String:
	var coords: Vector2i = get_location_coords(location_id)
	var cell: WorldData.CellData = WorldData.get_cell(coords)
	if cell:
		return cell.region_name
	return ""


## Calculate distance between two locations (in cells)
func get_distance(from_id: String, to_id: String) -> int:
	var from_coords := get_location_coords(from_id)
	var to_coords := get_location_coords(to_id)
	# Manhattan distance for grid-based world
	return absi(to_coords.x - from_coords.x) + absi(to_coords.y - from_coords.y)


## Get distance from current location
func get_distance_from_current(location_id: String) -> int:
	var to_coords := get_location_coords(location_id)
	return absi(to_coords.x - current_cell.x) + absi(to_coords.y - current_cell.y)


## Serialize for saving
func to_dict() -> Dictionary:
	# Also save WorldData discovered cells
	var discovered_cells: Array[Dictionary] = []
	for coords: Vector2i in WorldData.get_discovered_cells():
		discovered_cells.append({"x": coords.x, "y": coords.y})

	# Convert discovered_locations coords from Vector2i to Dictionary for JSON
	var locations_for_save: Dictionary = {}
	for loc_id: String in discovered_locations:
		var loc_data: Dictionary = discovered_locations[loc_id]
		var coords_val = loc_data.get("coords", Vector2i.ZERO)
		var coords_dict: Dictionary = {"x": 0, "y": 0}
		if coords_val is Vector2i:
			coords_dict = {"x": coords_val.x, "y": coords_val.y}
		elif coords_val is Dictionary:
			coords_dict = coords_val
		locations_for_save[loc_id] = {
			"name": loc_data.get("name", "Unknown"),
			"type": loc_data.get("type", 0),
			"coords": coords_dict,
			"discovered_time": loc_data.get("discovered_time", 0)
		}

	return {
		"discovered_locations": locations_for_save,
		"discovered_cells": discovered_cells,
		"current_cell": {"x": current_cell.x, "y": current_cell.y},
		"current_region": current_region,
		"current_location_id": current_location_id,
		"cells_traveled": cells_traveled,
		"locations_visited": locations_visited
	}


## Deserialize from save
func from_dict(data: Dictionary) -> void:
	discovered_locations = data.get("discovered_locations", {}).duplicate(true)

	# Restore current state
	var cell_data: Dictionary = data.get("current_cell", {"x": 0, "y": 0})
	current_cell = Vector2i(cell_data.get("x", 0), cell_data.get("y", 0))
	current_region = data.get("current_region", "")
	current_location_id = data.get("current_location_id", "")
	cells_traveled = data.get("cells_traveled", 0)
	locations_visited = data.get("locations_visited", 0)

	# Restore WorldData discovered cells
	var discovered_cells: Array = data.get("discovered_cells", [])
	for cell_dict: Dictionary in discovered_cells:
		var coords := Vector2i(cell_dict.get("x", 0), cell_dict.get("y", 0))
		WorldData.discover_cell(coords)

	# Also restore from discovered_locations (for compatibility)
	for loc_id: String in discovered_locations:
		var loc_data: Dictionary = discovered_locations[loc_id]
		if loc_data.has("coords"):
			var coords: Vector2i = _extract_coords(loc_data.get("coords"))
			WorldData.discover_cell(coords)


## Reset for new game
func reset_for_new_game() -> void:
	discovered_locations.clear()
	current_cell = Vector2i.ZERO
	current_region = ""
	current_location_id = ""
	cells_traveled = 0
	locations_visited = 0

	# Reset WorldData discovered flags
	for coords: Vector2i in WorldData.world_grid:
		var cell: WorldData.CellData = WorldData.world_grid[coords]
		cell.discovered = false

	# Auto-discover starting location
	discover_location_at(Vector2i.ZERO)

	# Reset streaming state
	_reset_streaming_state()


# =============================================================================
# DAGGERFALL UNITY-STYLE CHUNK STREAMING SYSTEM
# =============================================================================

## Signals for streaming events
signal hex_changed(old_hex: Vector2i, new_hex: Vector2i)
signal entering_location(location_id: String, location_type: int)
signal chunk_loaded(chunk_coords: Vector2i)
signal chunk_unloaded(chunk_coords: Vector2i)

## Streaming constants
const STREAM_RADIUS := 1  # Load 3x3 grid around player (radius of 1 = 9 chunks)
const MAX_CHUNKS := 9  # Maximum chunks in memory
const CHUNK_SIZE := 100.0  # World units per chunk (matches WorldData.CHUNK_SIZE)

## Current hex the player is in (axial coordinates)
var current_hex: Vector2i = Vector2i.ZERO

## Active chunks: chunk_coords (Vector2i) -> WildernessRoom instance
var active_chunks: Dictionary = {}

## Pool of recycled chunk instances for performance
var chunk_pool: Array[Node3D] = []

## Whether streaming is enabled (disabled during scene transitions, in towns, etc.)
var streaming_enabled: bool = false

## Parent node for wilderness chunks
var wilderness_parent: Node3D = null

## Player reference for position tracking
var _player: Node3D = null

## Last known player position (for movement detection)
var _last_player_pos: Vector3 = Vector3.ZERO

## Minimum movement distance to trigger hex check
const HEX_CHECK_THRESHOLD := 5.0


## Enable streaming mode (call when entering wilderness)
func enable_streaming(player: Node3D, parent: Node3D) -> void:
	if streaming_enabled:
		return

	_player = player
	wilderness_parent = parent
	streaming_enabled = true
	_last_player_pos = player.global_position

	# Initialize current hex from player position
	current_hex = WorldData.world_to_axial(player.global_position)

	print("[WorldManager] Streaming ENABLED at hex %s" % current_hex)

	# Load initial chunks around player
	_update_streaming(true)


## Disable streaming mode (call when entering towns/dungeons)
func disable_streaming() -> void:
	if not streaming_enabled:
		return

	streaming_enabled = false

	# Unload all active chunks
	_unload_all_chunks()

	_player = null
	wilderness_parent = null

	print("[WorldManager] Streaming DISABLED")


## Called every frame when streaming is active
func _process(delta: float) -> void:
	if not streaming_enabled or not _player:
		return

	# Only check for hex change if player has moved significantly
	var current_pos: Vector3 = _player.global_position
	if current_pos.distance_to(_last_player_pos) < HEX_CHECK_THRESHOLD:
		return

	_last_player_pos = current_pos
	_update_streaming(false)


## Update streaming - load/unload chunks based on player position
func _update_streaming(force_load: bool) -> void:
	if not _player or not wilderness_parent:
		return

	var player_pos: Vector3 = _player.global_position
	var new_hex: Vector2i = WorldData.world_to_axial(player_pos)

	# Check if player entered a new hex
	if new_hex != current_hex:
		var old_hex: Vector2i = current_hex
		current_hex = new_hex

		print("[WorldManager] Hex changed: %s -> %s" % [old_hex, new_hex])
		hex_changed.emit(old_hex, new_hex)

		# Check for location entry
		_check_location_entry(new_hex)

		# Trigger cell tracking update
		on_cell_entered(new_hex)

	# Only reload chunks if hex changed or forced
	if new_hex != current_hex or force_load:
		_load_chunks_around_hex(new_hex)
		_unload_distant_chunks(new_hex)


## Load chunks in a radius around the given hex
func _load_chunks_around_hex(center_hex: Vector2i) -> void:
	# Generate list of chunks to load (3x3 grid for STREAM_RADIUS=1)
	var chunks_to_load: Array[Vector2i] = []

	for dx in range(-STREAM_RADIUS, STREAM_RADIUS + 1):
		for dy in range(-STREAM_RADIUS, STREAM_RADIUS + 1):
			var chunk_hex := Vector2i(center_hex.x + dx, center_hex.y + dy)
			chunks_to_load.append(chunk_hex)

	# Load any chunks that aren't already active
	for chunk_hex: Vector2i in chunks_to_load:
		if not active_chunks.has(chunk_hex):
			_load_chunk(chunk_hex)


## Load a single chunk at the given hex coordinates
func _load_chunk(chunk_hex: Vector2i) -> void:
	if active_chunks.has(chunk_hex):
		return  # Already loaded

	if active_chunks.size() >= MAX_CHUNKS:
		push_warning("[WorldManager] MAX_CHUNKS reached, cannot load chunk at %s" % chunk_hex)
		return

	# Check if cell is passable
	if not WorldData.is_passable(chunk_hex):
		# Don't load impassable chunks - they'll be blocked by barriers
		return

	# Get or create a WildernessRoom instance
	var chunk: Node3D = _get_chunk_from_pool()
	if not chunk:
		# Create new WildernessRoom
		chunk = _create_wilderness_chunk()

	if not chunk:
		push_error("[WorldManager] Failed to create chunk for %s" % chunk_hex)
		return

	# Position the chunk in world space
	var world_pos: Vector3 = WorldData.axial_to_world(chunk_hex)
	chunk.position = world_pos

	# Configure the chunk for this hex
	_configure_chunk(chunk, chunk_hex)

	# Add to scene and track
	wilderness_parent.add_child(chunk)
	active_chunks[chunk_hex] = chunk

	print("[WorldManager] Loaded chunk at hex %s, world pos %s" % [chunk_hex, world_pos])
	chunk_loaded.emit(chunk_hex)


## Configure a wilderness chunk for a specific hex
func _configure_chunk(chunk: Node3D, chunk_hex: Vector2i) -> void:
	# Get cell data for this hex
	var cell: WorldData.CellData = WorldData.get_cell(chunk_hex)

	if chunk.has_method("set") and "grid_coords" in chunk:
		chunk.grid_coords = chunk_hex

	# Set biome from world data
	if cell:
		var wilderness_biome: int = WorldData.to_wilderness_biome(cell.biome)
		if "biome" in chunk:
			chunk.biome = wilderness_biome
		if "is_road_cell" in chunk:
			chunk.is_road_cell = cell.is_road

	# Enable seamless mode for streamed chunks (disables boundaries/walls)
	if chunk.has_method("set_seamless_mode"):
		chunk.set_seamless_mode(true)

	# Generate the chunk content
	# Use a deterministic seed based on hex coordinates for consistency
	var seed_value: int = _get_hex_seed(chunk_hex)
	if chunk.has_method("generate"):
		chunk.generate(seed_value, chunk_hex)


## Get deterministic seed for a hex (consistent across sessions)
func _get_hex_seed(hex: Vector2i) -> int:
	# Combine hex coordinates into a deterministic seed
	# Using prime numbers to reduce collision
	return abs(hex.x * 73856093 + hex.y * 19349663)


## Unload chunks that are too far from the given hex
func _unload_distant_chunks(center_hex: Vector2i) -> void:
	var chunks_to_unload: Array[Vector2i] = []

	for chunk_hex: Vector2i in active_chunks:
		var distance: int = WorldData.hex_distance(center_hex, chunk_hex)
		if distance > STREAM_RADIUS:
			chunks_to_unload.append(chunk_hex)

	for chunk_hex: Vector2i in chunks_to_unload:
		_unload_chunk(chunk_hex)


## Unload a single chunk
func _unload_chunk(chunk_hex: Vector2i) -> void:
	if not active_chunks.has(chunk_hex):
		return

	var chunk: Node3D = active_chunks[chunk_hex]
	active_chunks.erase(chunk_hex)

	# Return to pool or free
	_return_chunk_to_pool(chunk)

	print("[WorldManager] Unloaded chunk at hex %s" % chunk_hex)
	chunk_unloaded.emit(chunk_hex)


## Unload all active chunks
func _unload_all_chunks() -> void:
	var all_hexes: Array[Vector2i] = []
	for hex: Vector2i in active_chunks:
		all_hexes.append(hex)

	for hex: Vector2i in all_hexes:
		_unload_chunk(hex)

	active_chunks.clear()


## Create a new WildernessRoom instance
func _create_wilderness_chunk() -> Node3D:
	# Try to load the WildernessRoom scene
	var scene_path := "res://scenes/generation/wilderness_room.tscn"
	if ResourceLoader.exists(scene_path):
		var scene: PackedScene = load(scene_path)
		if scene:
			return scene.instantiate()

	# Fallback: create WildernessRoom directly
	var wilderness: Node = ClassDB.instantiate("Node3D")
	if wilderness:
		wilderness.set_script(load("res://scripts/generation/wilderness_room.gd"))
		return wilderness as Node3D

	push_error("[WorldManager] Could not create WildernessRoom")
	return null


## Get a chunk from the recycling pool
func _get_chunk_from_pool() -> Node3D:
	if chunk_pool.is_empty():
		return null

	var chunk: Node3D = chunk_pool.pop_back()

	# Reset the chunk for reuse
	if chunk.has_method("_reset_for_reuse"):
		chunk._reset_for_reuse()

	return chunk


## Return a chunk to the pool for recycling
func _return_chunk_to_pool(chunk: Node3D) -> void:
	if not chunk:
		return

	# Remove from scene
	if chunk.get_parent():
		chunk.get_parent().remove_child(chunk)

	# Clear chunk content if possible
	if chunk.has_method("_clear_content"):
		chunk._clear_content()

	# Only pool up to MAX_CHUNKS
	if chunk_pool.size() < MAX_CHUNKS:
		chunk_pool.append(chunk)
	else:
		chunk.queue_free()


## Check if entering a location (town, dungeon, etc.)
func _check_location_entry(hex: Vector2i) -> void:
	var cell: WorldData.CellData = WorldData.get_cell(hex)
	if not cell:
		return

	if cell.location_type != WorldData.LocationType.NONE and not cell.location_id.is_empty():
		print("[WorldManager] Entering location: %s (%s)" % [cell.location_name, cell.location_id])
		entering_location.emit(cell.location_id, cell.location_type)


## Reset streaming state (called on new game)
func _reset_streaming_state() -> void:
	_unload_all_chunks()
	current_hex = Vector2i.ZERO
	streaming_enabled = false
	_player = null
	wilderness_parent = null
	_last_player_pos = Vector3.ZERO

	# Clear chunk pool
	for chunk: Node3D in chunk_pool:
		if is_instance_valid(chunk):
			chunk.queue_free()
	chunk_pool.clear()


## Get the chunk at a specific hex (if loaded)
func get_chunk_at_hex(hex: Vector2i) -> Node3D:
	return active_chunks.get(hex, null)


## Check if a chunk is loaded at the given hex
func is_chunk_loaded(hex: Vector2i) -> bool:
	return active_chunks.has(hex)


## Get all currently loaded chunk coordinates
func get_loaded_chunks() -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	for hex: Vector2i in active_chunks:
		hexes.append(hex)
	return hexes


## Get player's current hex coordinates
func get_current_hex() -> Vector2i:
	return current_hex


## Teleport player to a specific hex (for fast travel)
func teleport_to_hex(target_hex: Vector2i, player: Node3D) -> bool:
	if not WorldData.is_passable(target_hex):
		push_warning("[WorldManager] Cannot teleport to impassable hex %s" % target_hex)
		return false

	# Disable streaming temporarily
	var was_streaming: bool = streaming_enabled
	if was_streaming:
		disable_streaming()

	# Move player to target hex center
	var world_pos: Vector3 = WorldData.axial_to_world(target_hex)
	player.global_position = world_pos + Vector3(0, 1.0, 0)  # Slightly above ground

	# Re-enable streaming if it was active
	if was_streaming and wilderness_parent:
		enable_streaming(player, wilderness_parent)

	print("[WorldManager] Teleported to hex %s" % target_hex)
	return true
