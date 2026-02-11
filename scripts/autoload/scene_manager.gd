## scene_manager.gd - Handles scene transitions and loading
extends Node

## Procedural dungeons regenerate each time, so saved positions are invalid
const PROCEDURAL_DUNGEON_ZONES := ["random_cave", "test_dungeon"]

## Wilderness room scene path
const WILDERNESS_ROOM_SCENE := "res://scenes/levels/wilderness_room.tscn"

## Dev mode - enables fast travel to any location
var dev_mode: bool = true  # Set to false for release

signal scene_load_started(scene_path: String)
signal scene_load_progress(progress: float)
signal scene_load_completed(scene_path: String)
signal transition_started
signal transition_completed
signal room_changed(old_coords: Vector2i, new_coords: Vector2i)

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

## Wilderness Room Grid System
## Current position in the room grid
var current_room_coords: Vector2i = Vector2i.ZERO

## Room seeds per character (character_id -> {Vector2i -> seed})
## Ensures same character always sees same rooms
var room_seeds: Dictionary = {}

## Whether we're currently in the wilderness room system
var in_wilderness: bool = false

## Last wilderness coordinates (for returning from dungeons)
var last_wilderness_coords: Vector2i = Vector2i.ZERO

## Direction player is entering from (for spawn placement)
var entering_from_direction: int = -1  # RoomEdge.Direction enum value

## Special marker for portal scenes that should return to wilderness
const RETURN_TO_WILDERNESS := "RETURN_TO_WILDERNESS"

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
	# Deferred signal connections to ensure other autoloads are ready
	call_deferred("_connect_world_signals")


## Connect to WorldManager signals for seamless streaming
func _connect_world_signals() -> void:
	if WorldManager and WorldManager.has_signal("entering_location"):
		if not WorldManager.entering_location.is_connected(_on_entering_location):
			WorldManager.entering_location.connect(_on_entering_location)
			print("[SceneManager] Connected to WorldManager.entering_location")


## Called when WorldManager detects player entering a location hex
func _on_entering_location(location_id: String, _location_type: int) -> void:
	# Transition to the location scene
	var scene_path := _get_scene_for_location(location_id)
	if scene_path.is_empty():
		print("[SceneManager] No scene mapping for location: %s" % location_id)
		return

	print("[SceneManager] WorldManager triggered location entry: %s -> %s" % [location_id, scene_path])
	change_scene(scene_path, "from_wilderness")

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
		# Only track "exterior" scenes (towns, wilderness, etc.)
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
	# Procedural dungeons need more time to generate rooms and spawn points
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
		print("[SceneManager] Player spawned at default: %s" % player_3d.global_position)
		return

	# Try any spawn point as last resort
	if spawn_points.size() > 0 and spawn_points[0] is Node3D:
		player_3d.global_position = (spawn_points[0] as Node3D).global_position
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
	# Save player state before transition
	# Could trigger autosave here

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


## ============================================================================
## WILDERNESS ROOM GRID SYSTEM
## ============================================================================

## Enter the wilderness room system from a town
## direction: 0=NORTH, 1=SOUTH, 2=EAST, 3=WEST (matches RoomEdge.Direction)
func enter_wilderness(from_direction: int, starting_coords: Vector2i = Vector2i.ZERO) -> void:
	current_room_coords = starting_coords
	in_wilderness = true
	entering_from_direction = from_direction

	# Store previous scene for returning
	var current := get_current_scene_path()
	if not current.is_empty() and not _is_interior_scene(current):
		previous_scene_path = current
		previous_spawn_id = _get_spawn_id_from_direction(_opposite_direction(from_direction))

	print("[SceneManager] Entering wilderness at %s from direction %d" % [starting_coords, from_direction])
	await _transition_to_wilderness_room(starting_coords, from_direction)


## Transition to an adjacent wilderness room
func transition_to_adjacent_room(direction: int) -> void:
	if is_loading:
		return

	var old_coords := current_room_coords
	var new_coords := _get_adjacent_coords(current_room_coords, direction)

	print("[SceneManager] Room transition: %s -> %s (direction %d)" % [old_coords, new_coords, direction])

	# Check if target cell is passable
	if not WorldData.is_passable(new_coords):
		print("[SceneManager] Cannot enter cell %s - impassable terrain" % new_coords)
		_handle_impassable_terrain(direction)
		return

	# Check if transitioning to a special location (town/dungeon)
	var location_id := WorldData.get_location_id(new_coords)
	if location_id != "":
		print("[SceneManager] Entering location: %s" % location_id)
		# Mark as discovered before leaving wilderness
		WorldData.discover_cell(new_coords)

		# Check if this is a procedural town or hand-crafted scene
		if _should_use_procedural_town(location_id):
			# Use procedural town generator
			in_wilderness = false
			current_room_coords = new_coords
			await _transition_to_procedural_town(new_coords, _opposite_direction(direction))
			room_changed.emit(old_coords, new_coords)
			return
		else:
			# Load hand-crafted scene
			var location_scene := _get_scene_for_location(location_id)
			if location_scene != "":
				in_wilderness = false
				current_room_coords = new_coords
				await change_scene(location_scene, "from_wilderness")
				room_changed.emit(old_coords, new_coords)
				return

	# Check if transitioning back to Elder Moor (room 0,0)
	if new_coords == Vector2i.ZERO:
		print("[SceneManager] Transitioning back to Elder Moor from %s" % old_coords)
		var spawn_id := "from_wilderness_west"
		if old_coords.x > 0:
			spawn_id = "from_wilderness_east"
		elif old_coords.y > 0:
			spawn_id = "from_wilderness_north"
		elif old_coords.y < 0:
			spawn_id = "from_wilderness_south"

		in_wilderness = false
		current_room_coords = Vector2i.ZERO
		await change_scene("res://scenes/levels/elder_moor.tscn", spawn_id)
		return

	# Mark cell as discovered
	WorldData.discover_cell(new_coords)

	entering_from_direction = _opposite_direction(direction)
	await _transition_to_wilderness_room(new_coords, entering_from_direction)

	room_changed.emit(old_coords, new_coords)


## Get scene path for a location ID (only for hand-crafted scenes)
func _get_scene_for_location(location_id: String) -> String:
	# Map location IDs to hand-crafted scene paths
	# Locations not listed here will use procedural generation
	match location_id:
		# SETTLEMENTS - Hand-crafted
		"village_elder_moor":
			return "res://scenes/levels/elder_moor.tscn"
		"city_dalhurst":
			return "res://scenes/levels/dalhurst.tscn"
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
		"hamlet_thornfield":
			return "res://scenes/levels/thornfield.tscn"
		"hamlet_millbrook":
			return "res://scenes/levels/millbrook.tscn"
		"village_stonehaven":
			return "res://scenes/levels/stonehaven.tscn"
		"hamlet_dusty_hollow":
			return "res://scenes/levels/dusty_hollow.tscn"
		"hamlet_windmere":
			return "res://scenes/levels/windmere.tscn"
		"village_old_crossing":
			return "res://scenes/levels/old_crossing.tscn"
		# Additional existing scenes (may need WorldData entries)
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
		# DUNGEONS - Hand-crafted
		"dungeon_willow_dale":
			return "res://scenes/levels/willow_dale.tscn"
		"dungeon_vampire_crypt":
			return "res://scenes/levels/vampire_crypt.tscn"
		"dungeon_whalers_abyss":
			return "res://scenes/levels/whalers_abyss.tscn"
		_:
			return ""  # Use procedural generation


## Check if a location should use procedural generation
func _should_use_procedural_town(location_id: String) -> bool:
	# If we have a hand-crafted scene, don't use procedural generation
	var scene_path := _get_scene_for_location(location_id)
	if scene_path != "":
		return false
	# Everything else uses procedural generation
	return true


## Internal: Load and generate a wilderness room
func _transition_to_wilderness_room(coords: Vector2i, from_direction: int) -> void:
	if is_loading:
		push_warning("[SceneManager] Already loading!")
		return

	is_loading = true
	current_room_coords = coords

	scene_load_started.emit(WILDERNESS_ROOM_SCENE)
	await _fade_out()

	# Load the wilderness room scene
	var packed_scene: PackedScene
	if scene_cache.has(WILDERNESS_ROOM_SCENE):
		packed_scene = scene_cache[WILDERNESS_ROOM_SCENE]
	else:
		packed_scene = load(WILDERNESS_ROOM_SCENE)
		if packed_scene:
			_cache_scene(WILDERNESS_ROOM_SCENE, packed_scene)

	if not packed_scene:
		push_error("[SceneManager] Failed to load wilderness room scene!")
		is_loading = false
		await _fade_in()
		return

	# Instance the scene
	get_tree().change_scene_to_packed(packed_scene)

	# Wait for scene to be ready
	await get_tree().process_frame
	await get_tree().process_frame

	# Get the wilderness room and configure it
	var room := get_tree().get_first_node_in_group("wilderness_room")
	if room and room is WildernessRoom:
		var wilderness_room := room as WildernessRoom

		# Get or generate seed for this room
		var room_seed := _get_room_seed(coords)

		# Determine biome based on distance from origin
		var biome := _get_biome_for_coords(coords)
		wilderness_room.biome = biome

		# Set entry direction so barriers don't block return path
		wilderness_room.entry_direction = from_direction

		# Connect edge signals
		wilderness_room.edge_triggered.connect(_on_room_edge_triggered)

		# Generate the room
		wilderness_room.generate(room_seed, coords)

	# Wait for generation to complete
	await get_tree().process_frame
	await get_tree().process_frame

	# Spawn player at correct position
	spawn_point_id = _get_spawn_id_from_direction(from_direction)
	_handle_player_spawn()

	# Ensure MapTracker knows we're in wilderness (belt + suspenders with wilderness_room._ready())
	if MapTracker:
		MapTracker.init_zone("open_world")

	await _fade_in()

	is_loading = false
	in_wilderness = true
	scene_load_completed.emit(WILDERNESS_ROOM_SCENE)


## Handle room edge being triggered
func _on_room_edge_triggered(direction: int) -> void:
	print("[SceneManager] Room edge triggered: direction %d" % direction)
	transition_to_adjacent_room(direction)


## Handle player trying to enter impassable terrain
func _handle_impassable_terrain(direction: int) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player is CharacterBody3D:
		var player_body := player as CharacterBody3D
		# Push player back from edge
		var push_distance := 5.0
		var push_dir := Vector3.ZERO
		match direction:
			0:  # Tried to go NORTH, push back south (+Z)
				push_dir = Vector3(0, 0, push_distance)
			1:  # Tried to go SOUTH, push back north (-Z)
				push_dir = Vector3(0, 0, -push_distance)
			2:  # Tried to go EAST, push back west (-X)
				push_dir = Vector3(-push_distance, 0, 0)
			3:  # Tried to go WEST, push back east (+X)
				push_dir = Vector3(push_distance, 0, 0)

		player_body.global_position += push_dir
		print("[SceneManager] Pushed player back from impassable terrain")

	# Show message to player via HUD
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		var cell := WorldData.get_cell(_get_adjacent_coords(current_room_coords, direction))
		var terrain_name := "Mountains"
		if cell and cell.location_name != "":
			terrain_name = cell.location_name
		hud.show_notification("Impassable terrain: %s" % terrain_name)


## Transition to a procedurally generated town
func _transition_to_procedural_town(coords: Vector2i, from_direction: int) -> void:
	if is_loading:
		push_warning("[SceneManager] Already loading!")
		return

	is_loading = true
	current_room_coords = coords

	var cell: WorldData.CellData = WorldData.get_cell(coords)
	if not cell:
		push_error("[SceneManager] No cell data for coords %s" % coords)
		is_loading = false
		return

	print("[SceneManager] Generating procedural town: %s" % cell.location_name)
	scene_load_started.emit("procedural_town")
	await _fade_out()

	# Preserve the player before clearing the scene
	var player := get_tree().get_first_node_in_group("player")
	var player_saved: Node = null
	if player:
		player_saved = player
		player.get_parent().remove_child(player)

	# Clear current scene
	var current := get_tree().current_scene
	if current:
		current.queue_free()
		await get_tree().process_frame

	# Create new root node
	var town_root := Node3D.new()
	town_root.name = cell.location_name.replace(" ", "_")
	get_tree().root.add_child(town_root)
	get_tree().current_scene = town_root

	# Re-add the player to the new scene
	if player_saved:
		town_root.add_child(player_saved)

	# Create town generator
	var town: TownGenerator = TownGenerator.new()
	town.name = "TownGenerator"
	town_root.add_child(town)

	# Generate town from cell data
	var town_seed := _get_room_seed(coords)
	town.generate_from_cell(cell, coords, town_seed)

	# Wait for generation
	await get_tree().process_frame
	await get_tree().process_frame

	# Position player at spawn point
	spawn_point_id = _get_spawn_id_from_direction(from_direction)
	_handle_player_spawn()

	await _fade_in()

	is_loading = false
	in_wilderness = false
	scene_load_completed.emit("procedural_town")


## Dev mode: Fast travel to any location with a shrine
func dev_fast_travel_to(location_id: String) -> void:
	if not dev_mode:
		print("[SceneManager] Dev mode disabled")
		return

	print("[SceneManager] dev_fast_travel_to called with: %s" % location_id)

	# Ensure world grid is initialized
	if WorldData.world_grid.is_empty():
		WorldData.initialize()
		print("[SceneManager] Initialized world grid with %d cells" % WorldData.world_grid.size())

	# Find the coordinates for this location
	var target_coords: Vector2i = Vector2i(999, 999)
	for coords: Vector2i in WorldData.world_grid:
		var cell: WorldData.CellData = WorldData.world_grid[coords]
		if cell.location_id == location_id:
			target_coords = coords
			break

	if target_coords == Vector2i(999, 999):
		print("[SceneManager] Location not found: %s" % location_id)
		return

	var cell: WorldData.CellData = WorldData.get_cell(target_coords)
	if not cell:
		return

	print("[SceneManager] Dev fast travel to: %s at %s" % [cell.location_name, target_coords])

	# Mark as discovered
	WorldData.discover_cell(target_coords)
	current_room_coords = target_coords

	# Transition based on location type
	if _should_use_procedural_town(location_id):
		print("[SceneManager] Using procedural town for %s" % location_id)
		await _transition_to_procedural_town(target_coords, 1)  # From south
	else:
		var scene_path := _get_scene_for_location(location_id)
		print("[SceneManager] Scene path for %s: %s" % [location_id, scene_path])
		if scene_path:
			print("[SceneManager] Changing to scene: %s" % scene_path)
			await change_scene(scene_path, "from_fast_travel")
		else:
			print("[SceneManager] ERROR: No scene path found for %s" % location_id)


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


## Get or create a seed for a room at given coordinates
## Same character + same coordinates = same seed (persistent)
func _get_room_seed(coords: Vector2i) -> int:
	var char_id := "default"
	if GameManager and GameManager.player_data:
		# Use character name as unique identifier for seed generation
		char_id = GameManager.player_data.character_name if GameManager.player_data.character_name else "default"

	if not room_seeds.has(char_id):
		room_seeds[char_id] = {}

	var char_rooms: Dictionary = room_seeds[char_id]
	if not char_rooms.has(coords):
		# Generate deterministic seed from character + coords
		var base_seed := char_id.hash()
		var coord_hash := coords.x * 73856093 ^ coords.y * 19349663  # Prime numbers for good distribution
		char_rooms[coords] = base_seed ^ coord_hash

	return char_rooms[coords]


## Get biome type based on coordinates using WorldData
func _get_biome_for_coords(coords: Vector2i) -> int:
	# Use WorldData to get biome for this cell
	var world_biome: int = WorldData.get_biome(coords)
	return WorldData.to_wilderness_biome(world_biome)

## Get adjacent room coordinates based on direction
## WorldData uses: X = East/West (+ = East), Y = North/South (+ = North)
## 3D Space: NORTH is -Z, SOUTH is +Z
func _get_adjacent_coords(coords: Vector2i, direction: int) -> Vector2i:
	match direction:
		0:  # NORTH (-Z in 3D) = +Y in grid
			return coords + Vector2i(0, 1)
		1:  # SOUTH (+Z in 3D) = -Y in grid
			return coords + Vector2i(0, -1)
		2:  # EAST (+X)
			return coords + Vector2i(1, 0)
		3:  # WEST (-X)
			return coords + Vector2i(-1, 0)
	return coords


## Get opposite direction
func _opposite_direction(direction: int) -> int:
	match direction:
		0: return 1  # NORTH -> SOUTH
		1: return 0  # SOUTH -> NORTH
		2: return 3  # EAST -> WEST
		3: return 2  # WEST -> EAST
	return 0


## Get spawn point ID from direction
func _get_spawn_id_from_direction(direction: int) -> String:
	match direction:
		0: return "from_north"
		1: return "from_south"
		2: return "from_east"
		3: return "from_west"
	return "default"


## Apply rotation to player based on spawn point ID
## Player should face the direction they were traveling (continue momentum)
func _apply_spawn_rotation(player: Node3D, spawn_id: String) -> void:
	# Calculate the rotation: player should face INWARD (toward center of zone)
	# from_north = spawned at north edge = traveling south = face south (PI)
	# from_south = spawned at south edge = traveling north = face north (0)
	# from_east = spawned at east edge = traveling west = face west (-PI/2)
	# from_west = spawned at west edge = traveling east = face east (PI/2)
	var target_rotation: float = 0.0

	match spawn_id:
		"from_north":
			target_rotation = PI  # Face south (continuing travel direction)
		"from_south":
			target_rotation = 0.0  # Face north (continuing travel direction)
		"from_east":
			target_rotation = -PI / 2.0  # Face west (continuing travel direction)
		"from_west":
			target_rotation = PI / 2.0  # Face east (continuing travel direction)
		"from_wilderness_north", "from_open_world_north":
			# Entered town from NORTH, so player was traveling SOUTH, face south
			target_rotation = PI
		"from_wilderness_south", "from_open_world_south":
			# Entered town from SOUTH, so player was traveling NORTH, face north
			target_rotation = 0.0
		"from_wilderness_east", "from_open_world_east":
			# Entered town from EAST, so player was traveling WEST, face west
			target_rotation = -PI / 2.0
		"from_wilderness_west", "from_open_world_west", "from_wilderness", "from_open_world":
			# Entered town from WEST, so player was traveling EAST, face east
			target_rotation = PI / 2.0
		_:
			return  # Unknown spawn ID, don't change rotation

	# Apply rotation to MeshRoot if it exists (common pattern for player controller)
	if player.has_node("MeshRoot"):
		player.get_node("MeshRoot").rotation.y = target_rotation
		print("[SceneManager] Applied spawn rotation: %.2f radians (%.1f degrees)" % [target_rotation, rad_to_deg(target_rotation)])
	elif "rotation" in player:
		# Fallback to direct rotation on player node
		player.rotation.y = target_rotation
		print("[SceneManager] Applied spawn rotation to player: %.2f radians" % target_rotation)


## Exit wilderness and return to town
func exit_wilderness_to_town(town_scene: String, spawn_id: String) -> void:
	in_wilderness = false
	current_room_coords = Vector2i.ZERO
	entering_from_direction = -1
	await change_scene(town_scene, spawn_id)


## Return to wilderness from a dungeon
## Uses last_wilderness_coords to return player to where they entered the dungeon
func return_to_wilderness() -> void:
	var return_coords := last_wilderness_coords
	if return_coords == Vector2i.ZERO:
		# Fallback to Elder Moor starting area if no coords saved
		return_coords = Vector2i(0, 0)

	print("[SceneManager] Returning to wilderness at %s" % return_coords)

	# Re-enter wilderness at the saved coordinates
	# Use direction -1 (unknown) to spawn at center
	await enter_wilderness(-1, return_coords)


## Store current wilderness coords before entering a dungeon
func save_wilderness_coords_for_return() -> void:
	if in_wilderness:
		last_wilderness_coords = current_room_coords
		print("[SceneManager] Saved wilderness coords for return: %s" % last_wilderness_coords)


## Get current room coordinates (for HUD display)
func get_current_room_coords() -> Vector2i:
	return current_room_coords


## Get current biome name (for HUD display)
func get_current_biome_name() -> String:
	if not in_wilderness:
		return ""

	# Use WorldData for location/region info
	var cell_name := WorldData.get_cell_name(current_room_coords)
	return cell_name


## Get current region name (for HUD display)
func get_current_region_name() -> String:
	if not in_wilderness:
		return ""
	return WorldData.get_region_name(current_room_coords)


## Check if current cell has a location (town/dungeon)
func get_current_location_id() -> String:
	return WorldData.get_location_id(current_room_coords)


## Check if currently in wilderness room system
func is_in_wilderness() -> bool:
	return in_wilderness


## Save room seeds for a character (called by save system)
func get_room_seeds_for_save() -> Dictionary:
	return room_seeds


## Load room seeds from save
func load_room_seeds(data: Dictionary) -> void:
	room_seeds = data
