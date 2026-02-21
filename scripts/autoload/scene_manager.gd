## scene_manager.gd - Handles interior scene transitions only
## Wilderness streaming is handled by CellStreamer
## This script handles: fade transitions, interior loading, spawn points
extends Node

## Special constant for doors that return to wilderness streaming
const RETURN_TO_WILDERNESS := "__RETURN_TO_WILDERNESS__"

## Procedural dungeons regenerate each time, so saved positions are invalid
const PROCEDURAL_DUNGEON_ZONES := ["random_cave", "test_dungeon"]

## Dev mode - enables fast travel to any location
var dev_mode: bool = true

## Fog of war toggle
var fog_of_war_enabled: bool = true

## Signals
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

## Previous scene tracking (for returning from interiors)
var previous_scene_path: String = ""
var previous_spawn_id: String = ""

## Scene cache
var scene_cache: Dictionary = {}
var max_cached_scenes: int = 3

## Current location tracking
var current_region_id: String = ""
var current_room_coords: Vector2i = Vector2i.ZERO

## Transition effect
var transition_overlay: CanvasLayer
var transition_rect: ColorRect
var transition_duration: float = 0.5

## Player spawn data (from save or scene transition)
var pending_player_position: Vector3 = Vector3.ZERO
var pending_player_rotation: float = 0.0
var has_pending_position: bool = false

## Interior state - for tracking entry point when exiting
var _entered_from_cell: Vector2i = Vector2i.ZERO
var _entrance_position: Vector3 = Vector3.ZERO
var _entrance_facing: float = 0.0
var _is_in_interior: bool = false

## Player scene for instantiation
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
var _player_scene: PackedScene = null

## Constant for returning to overworld
const RETURN_TO_OVERWORLD := "RETURN_TO_OVERWORLD"


func _ready() -> void:
	_create_transition_overlay()


func _create_transition_overlay() -> void:
	transition_overlay = CanvasLayer.new()
	transition_overlay.layer = 100
	add_child(transition_overlay)

	transition_rect = ColorRect.new()
	transition_rect.color = Color.BLACK
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.modulate.a = 0.0
	transition_overlay.add_child(transition_rect)


## ============================================================================
## INTERIOR TRANSITIONS (NEW API for CellStreamer integration)
## ============================================================================

## Enter an interior scene (dungeon, building, etc.)
## Pauses cell streaming and loads the interior
func enter_interior(scene_path: String, spawn_id: String = "") -> void:
	if is_loading:
		push_warning("[SceneManager] Already loading a scene")
		return

	# Save current overworld state
	if CellStreamer and CellStreamer.is_streaming():
		_entered_from_cell = CellStreamer.get_active_cell()
		var player := get_tree().get_first_node_in_group("player")
		if player and player is Node3D:
			_entrance_position = player.global_position
			if player.has_node("MeshRoot"):
				_entrance_facing = player.get_node("MeshRoot").rotation.y

		# Stop streaming
		CellStreamer.stop_streaming()

	_is_in_interior = true
	await change_scene(scene_path, spawn_id)


## Exit an interior and return to the overworld
## Resumes cell streaming and places player at entrance
func exit_interior(return_facing: float = -999.0) -> void:
	if not _is_in_interior:
		push_warning("[SceneManager] Not in an interior")
		return

	if is_loading:
		push_warning("[SceneManager] Already loading")
		return

	is_loading = true
	transition_started.emit()

	await _fade_out()

	# Clear current scene
	var current_scene := get_tree().current_scene
	if current_scene:
		current_scene.queue_free()
		await get_tree().process_frame

	# Resume cell streaming
	if CellStreamer:
		CellStreamer.start_streaming(_entered_from_cell)

	# Wait for cells to load
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Position and rotate player
	var player := get_tree().get_first_node_in_group("player")
	if player and player is Node3D:
		player.global_position = _entrance_position

		# Face away from the door (opposite of entrance facing)
		var facing: float
		if return_facing > -900.0:
			facing = return_facing
		else:
			facing = _entrance_facing + PI  # Face opposite direction

		if player.has_node("MeshRoot"):
			player.get_node("MeshRoot").rotation.y = facing
		if player.has_node("CameraPivot"):
			var camera_pivot := player.get_node("CameraPivot")
			if camera_pivot.has_method("set_yaw"):
				camera_pivot.set_yaw(facing)

	_is_in_interior = false

	await _fade_in()

	is_loading = false
	scene_load_completed.emit("overworld")


## Check if currently in an interior
func is_in_interior() -> bool:
	return _is_in_interior


## ============================================================================
## STANDARD SCENE TRANSITIONS
## ============================================================================

## Load a scene with transition
func change_scene(scene_path: String, spawn_id: String = "", fade: bool = true) -> void:
	if is_loading:
		push_warning("[SceneManager] Already loading a scene")
		return

	# Track previous scene (for returning from interiors)
	var current_scene := get_current_scene_path()
	if not current_scene.is_empty() and current_scene != scene_path:
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
		if not ResourceLoader.exists(scene_path):
			push_error("[SceneManager] Scene not found: " + scene_path)
			return

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
					push_error("[SceneManager] Failed to load scene: " + scene_path)
					return
				_:
					await get_tree().process_frame

		_cache_scene(scene_path, packed_scene)

	# Change to new scene
	get_tree().change_scene_to_packed(packed_scene)

	# Wait for scene to initialize
	for i in range(5):
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

	# For procedural dungeons, always use spawn point
	if is_procedural_dungeon(SaveManager.current_zone_id if SaveManager else ""):
		has_pending_position = false
		pending_player_position = Vector3.ZERO

	# Check for pending position from save
	if has_pending_position:
		player_3d.global_position = pending_player_position
		if player.has_node("MeshRoot"):
			player.get_node("MeshRoot").rotation.y = pending_player_rotation
		if player.has_node("CameraPivot"):
			var camera_pivot := player.get_node("CameraPivot")
			if camera_pivot.has_method("set_yaw"):
				camera_pivot.set_yaw(pending_player_rotation)
		has_pending_position = false
		return

	# Find spawn point
	var spawn_points := get_tree().get_nodes_in_group("spawn_points")

	if not spawn_point_id.is_empty():
		for point in spawn_points:
			var point_id := ""
			if point.has_meta("spawn_id"):
				point_id = point.get_meta("spawn_id")

			if point_id == spawn_point_id and point is Node3D:
				player_3d.global_position = (point as Node3D).global_position
				_apply_spawn_rotation(player_3d, spawn_point_id)
				return

		# Fall back to spawn point with matching name
		for point in spawn_points:
			if point.name == spawn_point_id and point is Node3D:
				player_3d.global_position = (point as Node3D).global_position
				_apply_spawn_rotation(player_3d, spawn_point_id)
				return

	# Fall back to default spawn
	var default_spawn := get_tree().get_first_node_in_group("default_spawn")
	if default_spawn and default_spawn is Node3D:
		player_3d.global_position = (default_spawn as Node3D).global_position
		if not spawn_point_id.is_empty():
			_apply_spawn_rotation(player_3d, spawn_point_id)
		return

	# Try any spawn point
	if spawn_points.size() > 0 and spawn_points[0] is Node3D:
		player_3d.global_position = (spawn_points[0] as Node3D).global_position
		if not spawn_point_id.is_empty():
			_apply_spawn_rotation(player_3d, spawn_point_id)
		return

	# Absolute fallback
	player_3d.global_position = Vector3(0, 5, 0)
	push_warning("[SceneManager] No spawn point found! Player placed at fallback position")


## Apply rotation based on spawn point ID
func _apply_spawn_rotation(player: Node3D, spawn_id: String) -> void:
	var target_rotation: float = 0.0
	var should_rotate: bool = true

	match spawn_id:
		"from_north", "from_region_north":
			target_rotation = PI
		"from_south", "from_region_south":
			target_rotation = 0.0
		"from_east", "from_region_east":
			target_rotation = -PI / 2.0
		"from_west", "from_region_west":
			target_rotation = PI / 2.0
		_:
			should_rotate = false

	if not should_rotate:
		return

	if player.has_node("MeshRoot"):
		player.get_node("MeshRoot").rotation.y = target_rotation
	elif "rotation" in player:
		player.rotation.y = target_rotation

	if player.has_node("CameraPivot"):
		var camera_pivot := player.get_node("CameraPivot")
		if camera_pivot.has_method("set_yaw"):
			camera_pivot.set_yaw(target_rotation)


## Set pending player position (from save)
func set_player_position(pos: Vector3, rotation_y: float = 0.0) -> void:
	pending_player_position = pos
	pending_player_rotation = rotation_y
	has_pending_position = true


## Check if a zone is a procedural dungeon
func is_procedural_dungeon(zone_id: String) -> bool:
	return zone_id in PROCEDURAL_DUNGEON_ZONES


## ============================================================================
## SCENE CACHE
## ============================================================================

func _cache_scene(scene_path: String, packed_scene: PackedScene) -> void:
	if scene_cache.size() >= max_cached_scenes:
		var oldest: String = scene_cache.keys()[0]
		scene_cache.erase(oldest)
	scene_cache[scene_path] = packed_scene


func clear_cache() -> void:
	scene_cache.clear()


func preload_scene(scene_path: String) -> void:
	if scene_cache.has(scene_path):
		return
	if ResourceLoader.exists(scene_path):
		ResourceLoader.load_threaded_request(scene_path)


func is_scene_preloaded(scene_path: String) -> bool:
	if scene_cache.has(scene_path):
		return true
	return ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_LOADED


## ============================================================================
## TRANSITIONS
## ============================================================================

func _fade_out() -> void:
	transition_started.emit()
	var tween := create_tween()
	tween.tween_property(transition_rect, "modulate:a", 1.0, transition_duration)
	await tween.finished


func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(transition_rect, "modulate:a", 0.0, transition_duration)
	await tween.finished
	transition_completed.emit()


func reload_current_scene() -> void:
	var current := get_tree().current_scene.scene_file_path
	await change_scene(current, "", true)


func get_current_scene_path() -> String:
	if get_tree().current_scene:
		return get_tree().current_scene.scene_file_path
	return ""


## ============================================================================
## PREVIOUS SCENE / INTERIOR DETECTION
## ============================================================================

func return_to_previous_scene() -> void:
	if previous_scene_path.is_empty():
		push_warning("[SceneManager] No previous scene to return to")
		await change_scene("res://scenes/levels/elder_moor.tscn", "from_inn", true)
		return
	await change_scene(previous_scene_path, previous_spawn_id, true)


## Return to wilderness cell streaming (used by dungeon exits)
func return_to_wilderness() -> void:
	print("[SceneManager] Returning to wilderness")

	# Get the coordinates we should return to
	var return_coords := Vector2i.ZERO
	if PlayerGPS:
		return_coords = PlayerGPS.current_cell

	# Fade out
	await _fade_out()

	# Unload current scene and start cell streaming
	if CellStreamer:
		# Start streaming from the return coordinates
		await CellStreamer.teleport_to_cell(return_coords)

	# Fade in
	await _fade_in()

	print("[SceneManager] Returned to wilderness at %s" % str(return_coords))


func _is_interior_scene(scene_path: String) -> bool:
	var interior_keywords := ["inn_", "shop_", "house_", "interior", "inside"]
	var lower_path := scene_path.to_lower()
	for keyword in interior_keywords:
		if keyword in lower_path:
			return true
	return false


func _get_scene_name(scene_path: String) -> String:
	return scene_path.get_file().get_basename()


func get_previous_scene() -> String:
	return previous_scene_path


## ============================================================================
## LOCATION LOOKUP
## ============================================================================

func get_scene_for_location(location_id: String) -> String:
	# Use WorldGrid's location scene mapping
	if WorldGrid.LOCATION_SCENES.has(location_id):
		return WorldGrid.LOCATION_SCENES[location_id]
	return ""


func set_current_region(region_id: String) -> void:
	current_region_id = region_id
	var coords := WorldGrid.get_location_coords(region_id)
	if coords != Vector2i.ZERO or region_id == "elder_moor":
		current_room_coords = coords
	if PlayerGPS:
		PlayerGPS.set_position(coords)


func get_current_region_id() -> String:
	return current_region_id


func get_current_room_coords() -> Vector2i:
	return current_room_coords


## ============================================================================
## FAST TRAVEL
## ============================================================================

## Fast travel to a location (works in both dev and normal mode)
## ALWAYS uses CellStreamer for seamless world navigation
func fast_travel_to(location_id: String) -> void:
	print("[SceneManager] Fast traveling to: %s" % location_id)

	var coords := WorldGrid.get_location_coords(location_id)
	print("[SceneManager] Using CellStreamer to teleport to coords: %s" % str(coords))

	# Fade out
	await _fade_out()

	if CellStreamer:
		await CellStreamer.teleport_to_cell(coords)
	else:
		push_error("[SceneManager] CellStreamer not available!")

	# Fade in
	await _fade_in()

	print("[SceneManager] Fast travel complete to %s" % location_id)


## Alias for backwards compatibility
func dev_fast_travel_to(location_id: String) -> void:
	await fast_travel_to(location_id)


func get_fast_travel_locations() -> Array[Dictionary]:
	var locations: Array[Dictionary] = []

	WorldGrid.initialize()

	for coords: Vector2i in WorldGrid.cells:
		var cell: WorldGrid.CellInfo = WorldGrid.cells[coords]

		if cell.location_type == WorldGrid.LocationType.NONE:
			continue
		if cell.location_type == WorldGrid.LocationType.LANDMARK:
			continue

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
## TRIGGER HELPERS
## ============================================================================

func trigger_area_transition(target_scene: String, target_spawn: String) -> void:
	await change_scene(target_scene, target_spawn, true)
