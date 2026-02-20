## scene_manager.gd - Handles scene transitions and loading
## Hybrid system: hand-crafted scenes for towns/dungeons, procedural wilderness rooms
extends Node

## Procedural dungeons regenerate each time, so saved positions are invalid
const PROCEDURAL_DUNGEON_ZONES := ["random_cave", "test_dungeon"]

## Dev mode - enables fast travel to any location
var dev_mode: bool = true  # Set to false for release

## Fog of war toggle - when false, all map cells/locations are revealed
var fog_of_war_enabled: bool = true  # Set to false in dev mode to reveal all

signal scene_load_started(scene_path: String)
signal scene_load_progress(progress: float)
signal scene_load_completed(scene_path: String)
signal transition_started
signal transition_completed

## Loading state
var is_loading: bool = false
var loading_progress: float = 0.0
var target_scene_path: String = ""
var spawn_point_id: String = ""

## Previous scene tracking (for returning from interiors like inns)
var previous_scene_path: String = ""
var previous_spawn_id: String = ""

## Scene cache
var scene_cache: Dictionary = {}
var max_cached_scenes: int = 3

## Current region tracking (replaces grid coordinates)
var current_region_id: String = ""

## Wilderness tracking for hybrid system
var current_wilderness_coords: Vector2i = Vector2i(-1, -1)  # Invalid default
var last_wilderness_coords: Vector2i = Vector2i(-1, -1)  # For returning from dungeons/towns
var _current_wilderness_room: Node = null  # Reference to active WildernessRoom instance

## Transition effect
var transition_overlay: CanvasLayer
var transition_rect: ColorRect
var transition_duration: float = 0.5

## Player spawn data (from save or scene transition)
var pending_player_position: Vector3 = Vector3.ZERO
var pending_player_rotation: float = 0.0
var has_pending_position: bool = false


func _ready() -> void:
	_create_transition_overlay()


func _create_transition_overlay() -> void:
	transition_overlay = CanvasLayer.new()
	transition_overlay.layer = 100  # On top of everything
	add_child(transition_overlay)

	transition_rect = ColorRect.new()
	transition_rect.color = Color.BLACK
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.modulate.a = 0.0
	transition_overlay.add_child(transition_rect)


## Load a scene with transition
func change_scene(scene_path: String, spawn_id: String = "", fade: bool = true) -> void:
	if is_loading:
		push_warning("Already loading a scene")
		return

	# Track previous scene (for returning from interiors)
	var current_scene := get_current_scene_path()
	if not current_scene.is_empty() and current_scene != scene_path:
		# Don't overwrite previous if going into another interior
		# Only track "exterior" scenes (towns, regions, etc.)
		if not _is_interior_scene(current_scene):
			previous_scene_path = current_scene
			previous_spawn_id = "from_" + _get_scene_name(scene_path)

	target_scene_path = scene_path
	spawn_point_id = spawn_id
	is_loading = true

	scene_load_started.emit(scene_path)

	if fade:
		await _fade_out()

	await _load_scene_async(scene_path)

	if fade:
		await _fade_in()

	is_loading = false
	scene_load_completed.emit(scene_path)


## Load scene asynchronously
func _load_scene_async(scene_path: String) -> void:
	var packed_scene: PackedScene

	# Check cache first
	if scene_cache.has(scene_path):
		packed_scene = scene_cache[scene_path]
	else:
		# Load the scene
		if not ResourceLoader.exists(scene_path):
			push_error("Scene not found: " + scene_path)
			return

		# Use threaded loading for larger scenes
		ResourceLoader.load_threaded_request(scene_path)

		while true:
			var status := ResourceLoader.load_threaded_get_status(scene_path)
			match status:
				ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					var progress: Array = []
					ResourceLoader.load_threaded_get_status(scene_path, progress)
					if progress.size() > 0:
						loading_progress = progress[0]
						scene_load_progress.emit(loading_progress)
					await get_tree().process_frame
				ResourceLoader.THREAD_LOAD_LOADED:
					packed_scene = ResourceLoader.load_threaded_get(scene_path)
					break
				ResourceLoader.THREAD_LOAD_FAILED:
					push_error("Failed to load scene: " + scene_path)
					return
				_:
					await get_tree().process_frame

		# Cache the scene
		_cache_scene(scene_path, packed_scene)

	# Change to new scene
	get_tree().change_scene_to_packed(packed_scene)

	# Wait for scene to fully initialize (multiple frames for procedural content)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Handle player spawn
	_handle_player_spawn()


## Handle player spawning at correct position and rotation
func _handle_player_spawn() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not player is Node3D:
		push_warning("[SceneManager] No player found in group 'player'!")
		return

	var player_3d := player as Node3D

	# For procedural dungeons, always use entrance spawn point, not saved position
	# (the dungeon layout regenerates, so saved coordinates are meaningless)
	if is_procedural_dungeon(SaveManager.current_zone_id):
		has_pending_position = false
		pending_player_position = Vector3.ZERO
		print("[SceneManager] Procedural dungeon detected, using spawn point instead of saved position")

	# Check for pending position from save
	if has_pending_position:
		player_3d.global_position = pending_player_position
		# Apply rotation if player has MeshRoot
		if player.has_node("MeshRoot"):
			player.get_node("MeshRoot").rotation.y = pending_player_rotation
		# Also sync camera pivot yaw so camera faces same direction
		if player.has_node("CameraPivot"):
			var camera_pivot := player.get_node("CameraPivot")
			if camera_pivot.has_method("set_yaw"):
				camera_pivot.set_yaw(pending_player_rotation)
		has_pending_position = false
		print("[SceneManager] Player spawned at saved position: %s" % pending_player_position)
		return

	# Check for spawn point
	var spawn_points := get_tree().get_nodes_in_group("spawn_points")
	print("[SceneManager] Looking for spawn_id: '%s', found %d spawn points" % [spawn_point_id, spawn_points.size()])

	if not spawn_point_id.is_empty():
		for point in spawn_points:
			var point_id := ""
			if point.has_meta("spawn_id"):
				point_id = point.get_meta("spawn_id")
			print("[SceneManager] Checking spawn point: %s (id=%s)" % [point.name, point_id])

			if point_id == spawn_point_id:
				if point is Node3D:
					player_3d.global_position = (point as Node3D).global_position
					_apply_spawn_rotation(player_3d, spawn_point_id)
					print("[SceneManager] Player spawned at '%s': %s" % [spawn_point_id, player_3d.global_position])
					return

		# Fall back to spawn point with matching name
		for point in spawn_points:
			if point.name == spawn_point_id and point is Node3D:
				player_3d.global_position = (point as Node3D).global_position
				_apply_spawn_rotation(player_3d, spawn_point_id)
				print("[SceneManager] Player spawned at named point '%s': %s" % [spawn_point_id, player_3d.global_position])
				return

	# Fall back to default spawn point
	var default_spawn := get_tree().get_first_node_in_group("default_spawn")
	if default_spawn and default_spawn is Node3D:
		player_3d.global_position = (default_spawn as Node3D).global_position
		# Still apply rotation based on spawn_point_id if we have one
		if not spawn_point_id.is_empty():
			_apply_spawn_rotation(player_3d, spawn_point_id)
		print("[SceneManager] Player spawned at default: %s" % player_3d.global_position)
		return

	# Try any spawn point as last resort
	if spawn_points.size() > 0 and spawn_points[0] is Node3D:
		player_3d.global_position = (spawn_points[0] as Node3D).global_position
		# Still apply rotation based on spawn_point_id if we have one
		if not spawn_point_id.is_empty():
			_apply_spawn_rotation(player_3d, spawn_point_id)
		print("[SceneManager] Player spawned at fallback spawn point: %s" % player_3d.global_position)
		return

	# Absolute fallback - raise player up to prevent falling through world
	player_3d.global_position = Vector3(0, 5, 0)
	push_warning("[SceneManager] No spawn point found! Player placed at fallback position (0, 5, 0)")


## Set pending player position and rotation (from save)
func set_player_position(pos: Vector3, rotation_y: float = 0.0) -> void:
	pending_player_position = pos
	pending_player_rotation = rotation_y
	has_pending_position = true


## Check if a zone is a procedural dungeon (regenerates each time)
func is_procedural_dungeon(zone_id: String) -> bool:
	return zone_id in PROCEDURAL_DUNGEON_ZONES


## Cache a scene
func _cache_scene(scene_path: String, packed_scene: PackedScene) -> void:
	# Remove oldest if at capacity
	if scene_cache.size() >= max_cached_scenes:
		var oldest: String = scene_cache.keys()[0]
		scene_cache.erase(oldest)

	scene_cache[scene_path] = packed_scene


## Clear scene cache
func clear_cache() -> void:
	scene_cache.clear()


## Fade out transition
func _fade_out() -> void:
	transition_started.emit()
	var tween := create_tween()
	tween.tween_property(transition_rect, "modulate:a", 1.0, transition_duration)
	await tween.finished


## Fade in transition
func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(transition_rect, "modulate:a", 0.0, transition_duration)
	await tween.finished
	transition_completed.emit()


## Reload current scene
func reload_current_scene() -> void:
	var current := get_tree().current_scene.scene_file_path
	await change_scene(current, "", true)


## Get current scene path
func get_current_scene_path() -> String:
	if get_tree().current_scene:
		return get_tree().current_scene.scene_file_path
	return ""


## Preload a scene (for faster transitions)
func preload_scene(scene_path: String) -> void:
	if scene_cache.has(scene_path):
		return

	if not ResourceLoader.exists(scene_path):
		return

	# Start background loading
	ResourceLoader.load_threaded_request(scene_path)


## Check if scene is preloaded
func is_scene_preloaded(scene_path: String) -> bool:
	if scene_cache.has(scene_path):
		return true

	var status := ResourceLoader.load_threaded_get_status(scene_path)
	return status == ResourceLoader.THREAD_LOAD_LOADED


## Area transition trigger (called by trigger zones)
func trigger_area_transition(target_scene: String, target_spawn: String) -> void:
	await change_scene(target_scene, target_spawn, true)


## Return to the previous scene (used by inn exits, etc.)
func return_to_previous_scene() -> void:
	if previous_scene_path.is_empty():
		push_warning("[SceneManager] No previous scene to return to, using fallback")
		# Fallback to Elder Moor if no previous scene
		await change_scene("res://scenes/levels/elder_moor.tscn", "from_inn", true)
		return

	await change_scene(previous_scene_path, previous_spawn_id, true)


## Check if a scene is an interior (inn, shop, house, etc.)
func _is_interior_scene(scene_path: String) -> bool:
	var interior_keywords := ["inn_", "shop_", "house_", "interior", "inside"]
	var lower_path := scene_path.to_lower()
	for keyword in interior_keywords:
		if keyword in lower_path:
			return true
	return false


## Extract scene name from path
func _get_scene_name(scene_path: String) -> String:
	var filename := scene_path.get_file().get_basename()
	return filename


## Get previous scene path (for UI or debugging)
func get_previous_scene() -> String:
	return previous_scene_path


## Get scene path for a location ID (for region-based navigation)
func get_scene_for_location(location_id: String) -> String:
	# Map location IDs to hand-crafted scene paths
	match location_id:
		# === DEMO ZONE LOCATIONS ===
		# Towns
		"dalhurst":
			return "res://scenes/levels/dalhurst.tscn"
		"thornfield":
			return "res://scenes/levels/thornfield.tscn"
		"millbrook":
			return "res://scenes/levels/millbrook.tscn"
		# Landmarks
		"elder_moor":
			return "res://scenes/levels/elder_moor.tscn"
		"crossroads":
			return ""  # Use region scene
		# Dungeons
		"willow_dale":
			return "res://scenes/levels/willow_dale.tscn"
		"sunken_crypts":
			return "res://scenes/levels/sunken_crypt.tscn"
		"bandit_hideout":
			return "res://scenes/levels/bandit_hideout_exterior.tscn"
		"kazer_dun_entrance":
			return "res://scenes/levels/kazan_dun_entrance.tscn"

		# === LEGACY LOCATIONS ===
		"city_kazan_dun":
			return "res://scenes/levels/kazan_dun.tscn"
		"town_aberdeen":
			return "res://scenes/levels/aberdeen.tscn"
		"town_larton":
			return "res://scenes/levels/larton.tscn"
		"capital_falkenhafen":
			return "res://scenes/levels/falkenhaften.tscn"
		"village_riverside":
			return "res://scenes/levels/riverside_village.tscn"
		"village_elven_outpost":
			return "res://scenes/levels/elven_outpost.tscn"
		"outpost_tenger_camp":
			return "res://scenes/levels/tenger_camp.tscn"
		"village_stonehaven":
			return "res://scenes/levels/stonehaven.tscn"
		"hamlet_dusty_hollow":
			return "res://scenes/levels/dusty_hollow.tscn"
		"hamlet_windmere":
			return "res://scenes/levels/windmere.tscn"
		"village_old_crossing":
			return "res://scenes/levels/old_crossing.tscn"
		"town_duncaster":
			return "res://scenes/levels/duncaster.tscn"
		"town_east_hollow":
			return "res://scenes/levels/east_hollow.tscn"
		"outpost_kings_watch":
			return "res://scenes/levels/kings_watch.tscn"
		"village_pola_perron":
			return "res://scenes/levels/pola_perron.tscn"
		"town_whalers_abyss":
			return "res://scenes/levels/whalers_abyss.tscn"
		"dungeon_vampire_crypt":
			return "res://scenes/levels/vampire_crypt.tscn"
		"dungeon_mosshall_tombs":
			return "res://scenes/levels/mosshall_tombs.tscn"
		_:
			return ""


## Apply rotation to player based on spawn point ID
func _apply_spawn_rotation(player: Node3D, spawn_id: String) -> void:
	var target_rotation: float = 0.0
	var should_rotate: bool = true

	match spawn_id:
		"from_north", "from_region_north":
			# Entered from NORTH, face south
			target_rotation = PI
		"from_south", "from_region_south":
			# Entered from SOUTH, face north
			target_rotation = 0.0
		"from_east", "from_region_east":
			# Entered from EAST, face west
			target_rotation = -PI / 2.0
		"from_west", "from_region_west":
			# Entered from WEST, face east
			target_rotation = PI / 2.0
		_:
			should_rotate = false  # Unknown spawn ID, don't change rotation

	if not should_rotate:
		return

	# Apply rotation to MeshRoot if it exists (common pattern for player controller)
	if player.has_node("MeshRoot"):
		player.get_node("MeshRoot").rotation.y = target_rotation
		print("[SceneManager] Applied spawn rotation: %.2f radians (%.1f degrees)" % [target_rotation, rad_to_deg(target_rotation)])
	elif "rotation" in player:
		# Fallback to direct rotation on player node
		player.rotation.y = target_rotation
		print("[SceneManager] Applied spawn rotation to player: %.2f radians" % target_rotation)

	# Also sync the camera pivot yaw so camera faces same direction as player
	if player.has_node("CameraPivot"):
		var camera_pivot := player.get_node("CameraPivot")
		if camera_pivot.has_method("set_yaw"):
			camera_pivot.set_yaw(target_rotation)
			print("[SceneManager] Synced camera yaw: %.2f radians" % target_rotation)


## Set current region (called by region scripts)
## Note: This sets current_room_coords to the GRID coords (20x20 system), not region-relative coords
func set_current_region(region_id: String) -> void:
	current_region_id = region_id
	# Look up the grid coords for this location from WorldData LOCATIONS
	var loc_info: Dictionary = WorldData.get_location_by_id(region_id)
	if not loc_info.is_empty():
		current_room_coords = Vector2i(loc_info.get("col", 12), loc_info.get("row", 8))
	else:
		# Fallback: try to find in world_grid by location_id
		for coords: Vector2i in WorldData.world_grid:
			var cell: WorldData.CellData = WorldData.world_grid[coords]
			if cell.location_id == region_id:
				current_room_coords = coords
				break
	# Notify WorldManager of cell entry
	if WorldManager:
		WorldManager.on_cell_entered(current_room_coords)
	print("[SceneManager] Current region: %s (coords: %s)" % [region_id, current_room_coords])


## Get current region ID
func get_current_region_id() -> String:
	return current_region_id


## Dev mode: Fast travel to any location
func dev_fast_travel_to(location_id: String) -> void:
	if not dev_mode:
		print("[SceneManager] Dev mode disabled")
		return

	print("[SceneManager] dev_fast_travel_to called with: %s" % location_id)

	var scene_path := get_scene_for_location(location_id)
	if scene_path.is_empty():
		print("[SceneManager] No scene found for location: %s" % location_id)
		return

	print("[SceneManager] Dev fast travel to: %s" % location_id)
	await change_scene(scene_path, "from_fast_travel")


## Get all locations available for fast travel (dev mode shows all)
func get_fast_travel_locations() -> Array[Dictionary]:
	var locations: Array[Dictionary] = []

	# Ensure world grid is initialized
	if WorldData.world_grid.is_empty():
		WorldData.initialize()

	for coords: Vector2i in WorldData.world_grid:
		var cell: WorldData.CellData = WorldData.world_grid[coords]

		# Skip wilderness cells and landmarks (not fast travel destinations)
		if cell.location_type == WorldData.LocationType.NONE:
			continue
		if cell.location_type == WorldData.LocationType.LANDMARK:
			continue

		# In dev mode, show all; otherwise only discovered
		if dev_mode or cell.discovered:
			locations.append({
				"coords": coords,
				"location_id": cell.location_id,
				"location_name": cell.location_name,
				"location_type": cell.location_type,
				"region": cell.region_name,
				"discovered": cell.discovered
			})

	return locations


## ============================================================================
## HYBRID WILDERNESS SYSTEM
## Combines hand-crafted scenes for towns/dungeons with procedural wilderness
## ============================================================================

## Constant for returning to wilderness from dungeons/towns
const RETURN_TO_WILDERNESS := "RETURN_TO_WILDERNESS"

## Current room coordinates (grid-based system)
var current_room_coords: Vector2i = Vector2i(12, 8)  # Default to Elder Moor


## Check if player is currently in a procedural wilderness room
func is_in_wilderness() -> bool:
	# Check by group membership (WildernessRoom adds itself to "wilderness_room" group)
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.is_in_group("wilderness_room"):
		return true
	# Fallback: check our tracked reference
	return _current_wilderness_room != null and is_instance_valid(_current_wilderness_room)


## Get current room coordinates for world map
func get_current_room_coords() -> Vector2i:
	return current_room_coords


## Save wilderness coords before entering a dungeon/interior
func save_wilderness_coords_for_return() -> void:
	if current_wilderness_coords.x >= 0 and current_wilderness_coords.y >= 0:
		last_wilderness_coords = current_wilderness_coords
		print("[SceneManager] Saved wilderness coords for return: %s" % last_wilderness_coords)


## Enter wilderness at specified coordinates (HYBRID SYSTEM)
## Checks if target cell has a hand-crafted scene, otherwise generates procedural room
func enter_wilderness(target_coords: Vector2i, from_direction: int = -1) -> void:
	print("[SceneManager] enter_wilderness called: coords=%s, from_direction=%d" % [target_coords, from_direction])

	# Check if target is valid and passable
	var cell := WorldData.get_cell(target_coords)
	if cell == null:
		print("[SceneManager] Target cell is null, cannot travel")
		_show_travel_blocked("Cannot travel there")
		return

	if not WorldData.is_passable(target_coords):
		print("[SceneManager] Target cell is not passable")
		_show_travel_blocked("The way is blocked")
		return

	# Check if this cell has a hand-crafted scene (town/dungeon/landmark)
	var scene_path := _get_scene_for_cell(cell)
	if scene_path != "":
		# Save current wilderness coords for return
		if current_wilderness_coords.x >= 0:
			last_wilderness_coords = current_wilderness_coords
		# Load hand-crafted scene
		print("[SceneManager] Loading hand-crafted scene: %s" % scene_path)
		var spawn_id := _get_spawn_id_for_direction(from_direction)
		await _load_location_scene(scene_path, spawn_id, target_coords)
	else:
		# Generate procedural wilderness room
		print("[SceneManager] Generating procedural wilderness for coords: %s" % target_coords)
		await _load_wilderness_room(target_coords, from_direction)

	# Mark cell as discovered
	WorldData.discover_cell(target_coords)


## Return to wilderness from a dungeon/interior
func return_to_wilderness() -> void:
	print("[SceneManager] return_to_wilderness called, last coords: %s" % last_wilderness_coords)

	if last_wilderness_coords.x >= 0 and last_wilderness_coords.y >= 0:
		# Return to the saved wilderness coordinates
		await enter_wilderness(last_wilderness_coords, -1)
	else:
		# Fallback to Elder Moor if no saved coords
		print("[SceneManager] No saved wilderness coords, falling back to Elder Moor")
		await enter_wilderness(WorldData.PLAYER_START, -1)


## Load a hand-crafted location scene
func _load_location_scene(scene_path: String, spawn_id: String, coords: Vector2i) -> void:
	current_room_coords = coords
	current_wilderness_coords = Vector2i(-1, -1)  # Not in wilderness
	_current_wilderness_room = null

	await change_scene(scene_path, spawn_id)


## Player scene for instantiation in procedural rooms
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
var _player_scene: PackedScene = null


## Load a procedural wilderness room
func _load_wilderness_room(coords: Vector2i, from_direction: int) -> void:
	if is_loading:
		push_warning("[SceneManager] Already loading, ignoring wilderness request")
		return

	is_loading = true
	transition_started.emit()

	await _fade_out()

	# Clear current scene
	var current_scene := get_tree().current_scene
	if current_scene:
		current_scene.queue_free()
		await get_tree().process_frame

	# Create WildernessRoom instance
	var wilderness_room := WildernessRoom.new()
	wilderness_room.name = "WildernessRoom_%d_%d" % [coords.x, coords.y]

	# Set entry direction BEFORE generating (affects mountain barrier placement)
	wilderness_room.entry_direction = from_direction

	# Get biome from WorldData and convert to WildernessRoom.Biome
	var world_biome: int = WorldData.get_biome(coords)
	var wilderness_biome: int = WorldData.to_wilderness_biome(world_biome)
	# WildernessRoom.Biome only has 5 values (0-4), clamp to valid range
	wilderness_room.biome = clampi(wilderness_biome, 0, 4) as WildernessRoom.Biome

	# Generate with deterministic seed from coordinates
	var seed_value: int = coords.x * 10000 + coords.y + 12345

	# Add to scene tree
	get_tree().root.add_child(wilderness_room)
	get_tree().current_scene = wilderness_room

	# Generate the room content
	wilderness_room.generate(seed_value, coords)

	# Instantiate player if not present
	_ensure_player_exists(wilderness_room)

	# Connect edge signals for room transitions
	wilderness_room.edge_triggered.connect(_on_wilderness_edge_triggered)

	# Update tracking
	current_room_coords = coords
	current_wilderness_coords = coords
	_current_wilderness_room = wilderness_room

	# Wait for scene to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Position player based on entry direction
	_position_player_for_wilderness(from_direction, wilderness_room.room_size)

	await _fade_in()

	is_loading = false
	scene_load_completed.emit("wilderness://%d,%d" % [coords.x, coords.y])

	print("[SceneManager] Wilderness room loaded at %s" % coords)


## Ensure a player exists in the scene (instantiate if needed)
func _ensure_player_exists(parent: Node) -> void:
	var existing_player := get_tree().get_first_node_in_group("player")
	if existing_player:
		print("[SceneManager] Player already exists in scene")
		return

	# Load and cache player scene
	if _player_scene == null:
		if ResourceLoader.exists(PLAYER_SCENE_PATH):
			_player_scene = load(PLAYER_SCENE_PATH) as PackedScene
		else:
			push_error("[SceneManager] Player scene not found: %s" % PLAYER_SCENE_PATH)
			return

	# Instantiate player
	var player := _player_scene.instantiate()
	if player:
		parent.add_child(player)
		print("[SceneManager] Player instantiated in wilderness room")


## Position player based on entry direction in wilderness
func _position_player_for_wilderness(from_direction: int, room_size: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not player is Node3D:
		push_warning("[SceneManager] No player found for positioning")
		return

	var player_3d := player as Node3D
	var spawn_offset := Vector3(0, 0.5, 0)  # Default center

	if from_direction >= 0:
		# Use RoomEdge to get spawn offset (player enters from opposite side)
		var opposite_dir: int = RoomEdge.get_opposite(from_direction as RoomEdge.Direction)
		spawn_offset = RoomEdge.get_spawn_offset(opposite_dir as RoomEdge.Direction, room_size)

	player_3d.global_position = spawn_offset

	# Apply rotation to face into the room
	_apply_spawn_rotation(player_3d, _get_spawn_id_for_direction(from_direction))

	print("[SceneManager] Player positioned at %s (from_direction=%d)" % [spawn_offset, from_direction])


## Handle wilderness edge trigger - transition to adjacent cell
func _on_wilderness_edge_triggered(direction: RoomEdge.Direction) -> void:
	print("[SceneManager] Wilderness edge triggered: %s" % RoomEdge.Direction.keys()[direction])

	# Calculate target coordinates based on direction
	var offset: Vector2i
	match direction:
		RoomEdge.Direction.NORTH:
			offset = Vector2i(0, -1)  # North is -Y in grid
		RoomEdge.Direction.SOUTH:
			offset = Vector2i(0, 1)   # South is +Y in grid
		RoomEdge.Direction.EAST:
			offset = Vector2i(1, 0)
		RoomEdge.Direction.WEST:
			offset = Vector2i(-1, 0)
		_:
			offset = Vector2i.ZERO

	var target_coords: Vector2i = current_wilderness_coords + offset

	# Enter the new cell (passing direction so player spawns on opposite side)
	await enter_wilderness(target_coords, direction)


## Get scene path for a cell with a location
func _get_scene_for_cell(cell: WorldData.CellData) -> String:
	if cell.location_id.is_empty():
		return ""

	# Check WorldData's LOCATION_SCENES dictionary first
	if WorldData.LOCATION_SCENES.has(cell.location_id):
		return WorldData.LOCATION_SCENES[cell.location_id]

	# Fallback to get_scene_for_location
	return get_scene_for_location(cell.location_id)


## Get spawn ID string for a direction
func _get_spawn_id_for_direction(direction: int) -> String:
	match direction:
		0: return "from_north"  # RoomEdge.Direction.NORTH
		1: return "from_south"  # RoomEdge.Direction.SOUTH
		2: return "from_east"   # RoomEdge.Direction.EAST
		3: return "from_west"   # RoomEdge.Direction.WEST
		_: return "default"


## Show travel blocked notification
func _show_travel_blocked(message: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(message)
	print("[SceneManager] Travel blocked: %s" % message)


## Legacy alias for get_scene_for_location (underscore prefix version)
func _get_scene_for_location(location_id: String) -> String:
	return get_scene_for_location(location_id)


## Helper: Convert direction int to string
func _direction_to_string(direction: int) -> String:
	match direction:
		0: return "north"  # RoomEdge.Direction.NORTH
		1: return "south"  # RoomEdge.Direction.SOUTH
		2: return "east"   # RoomEdge.Direction.EAST
		3: return "west"   # RoomEdge.Direction.WEST
	return "center"


## Legacy: Transition to adjacent room in a direction
## Calculates target coords and calls enter_wilderness
func transition_to_adjacent_room(direction: int) -> void:
	var offset: Vector2i
	match direction:
		0: offset = Vector2i(0, -1)  # NORTH
		1: offset = Vector2i(0, 1)   # SOUTH
		2: offset = Vector2i(1, 0)   # EAST
		3: offset = Vector2i(-1, 0)  # WEST
		_: offset = Vector2i.ZERO

	var target_coords: Vector2i = current_room_coords + offset
	await enter_wilderness(target_coords, direction)
