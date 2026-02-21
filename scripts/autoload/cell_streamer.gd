## cell_streamer.gd - Daggerfall-style cell streaming system
## Loads/unloads cells in a ring around the player
## Player walks seamlessly across cell boundaries - NO teleport, NO rotation reset
extends Node

## Emitted when a cell finishes loading
signal cell_loaded(coords: Vector2i)

## Emitted when a cell is unloaded
signal cell_unloaded(coords: Vector2i)

## Emitted when streaming is paused (entering interior)
signal streaming_paused

## Emitted when streaming resumes (exiting interior)
signal streaming_resumed


## Streaming configuration
const LOAD_RADIUS := 1       ## Load cells within this radius of player
const UNLOAD_RADIUS := 2     ## Unload cells beyond this radius
const CELL_SIZE := 100.0     ## World units per cell (matches WorldGrid)

## Floating origin configuration
const ORIGIN_SHIFT_THRESHOLD := 500.0  ## Shift origin when player exceeds this distance

## Currently loaded cells: Vector2i -> Node3D (the cell scene/room)
var loaded_cells: Dictionary = {}

## The cell the player is currently standing in
var active_cell: Vector2i = Vector2i.ZERO

## Cumulative world offset for floating origin
var world_offset: Vector3 = Vector3.ZERO

## Is streaming active? (disabled when in interiors)
var streaming_enabled: bool = false

## Reference to player node
var _player: Node3D = null

## Cells currently being loaded (async)
var _loading_cells: Dictionary = {}

## Parent node for all loaded cells
var _cell_container: Node3D = null

## Preloaded WildernessRoom scene for procedural cells
var _wilderness_room_scene: PackedScene = null

## The "main scene" cell that should NEVER be unloaded (contains environment/lighting)
var _main_scene_cell: Vector2i = Vector2i(-9999, -9999)  # Invalid until set

## Cells that were externally registered (not loaded by CellStreamer)
var _external_cells: Dictionary = {}


func _ready() -> void:
	# Create container for cells
	_cell_container = Node3D.new()
	_cell_container.name = "CellContainer"
	add_child(_cell_container)

	# Initialize WorldGrid
	WorldGrid.initialize()

	print("[CellStreamer] Ready")


func _physics_process(delta: float) -> void:
	if not streaming_enabled:
		return

	if not _player:
		_find_player()
		return

	# Check if player crossed into a new cell
	_check_cell_boundary()

	# Check if we need to shift the floating origin
	_check_floating_origin()


## Find the player node in the scene
func _find_player() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node3D


## Check if player has crossed into a new cell
func _check_cell_boundary() -> void:
	if not _player:
		return

	# Calculate player's actual world position (accounting for origin offset)
	var player_world_pos: Vector3 = _player.global_position + world_offset
	var new_cell: Vector2i = WorldGrid.world_to_cell(player_world_pos)

	if new_cell != active_cell:
		var old_cell: Vector2i = active_cell
		active_cell = new_cell

		# Notify PlayerGPS
		if PlayerGPS:
			PlayerGPS.update_cell(new_cell)

		# Update SceneManager's region tracking for UI compatibility
		var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(new_cell)
		if cell_info and SceneManager:
			# Update location ID if entering a named location
			if not cell_info.location_id.is_empty():
				SceneManager.current_region_id = cell_info.location_id
				# Notify QuestManager that we reached this location
				if QuestManager:
					QuestManager.on_location_reached(cell_info.location_id)
			else:
				# In wilderness - use region name as fallback
				SceneManager.current_region_id = cell_info.region_name.to_snake_case()
			SceneManager.current_room_coords = new_cell

		# Update loaded cells
		_update_loaded_cells()

		print("[CellStreamer] Player crossed into cell %s (%s)" % [new_cell,
			cell_info.location_name if cell_info and not cell_info.location_name.is_empty() else "wilderness"])


## Check and perform floating origin shift if needed
func _check_floating_origin() -> void:
	if not _player:
		return

	var player_pos: Vector3 = _player.global_position
	player_pos.y = 0  # Ignore vertical distance

	if player_pos.length() > ORIGIN_SHIFT_THRESHOLD:
		_shift_floating_origin(player_pos)


## Shift the floating origin to keep player near world origin
func _shift_floating_origin(shift: Vector3) -> void:
	shift.y = 0  # Don't shift vertically

	# Shift all loaded cells
	for cell_node: Node3D in loaded_cells.values():
		cell_node.global_position -= shift

	# Shift the player
	if _player:
		_player.global_position -= shift

	# Track cumulative offset
	world_offset += shift

	print("[CellStreamer] Origin shifted by %s (cumulative: %s)" % [shift, world_offset])


## Update which cells should be loaded/unloaded
func _update_loaded_cells() -> void:
	# Calculate which cells should be loaded
	var should_be_loaded: Array[Vector2i] = []
	for dx: int in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dy: int in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var coords: Vector2i = active_cell + Vector2i(dx, dy)
			if WorldGrid.is_in_bounds(coords):
				should_be_loaded.append(coords)

	# Unload cells that are too far
	var cells_to_unload: Array[Vector2i] = []
	for coords: Vector2i in loaded_cells.keys():
		var distance: int = WorldGrid.grid_distance(coords, active_cell)
		if distance > UNLOAD_RADIUS:
			cells_to_unload.append(coords)

	for coords: Vector2i in cells_to_unload:
		_unload_cell(coords)

	# Load cells that aren't loaded yet
	for coords: Vector2i in should_be_loaded:
		if not loaded_cells.has(coords) and not _loading_cells.has(coords):
			_load_cell(coords)


## Load a cell at the given coordinates
func _load_cell(coords: Vector2i) -> void:
	# Mark as loading
	_loading_cells[coords] = true

	var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(coords)
	if not cell_info:
		_loading_cells.erase(coords)
		return

	var cell_node: Node3D

	if cell_info.scene_path != "" and ResourceLoader.exists(cell_info.scene_path):
		# Hand-crafted scene
		cell_node = await _load_handcrafted_cell(coords, cell_info)
	else:
		# Procedural wilderness
		cell_node = _generate_procedural_cell(coords, cell_info)

	if not cell_node:
		_loading_cells.erase(coords)
		return

	# Position the cell in world space
	var world_pos: Vector3 = WorldGrid.cell_to_world(coords) - world_offset
	cell_node.global_position = world_pos
	cell_node.name = "Cell_%d_%d" % [coords.x, coords.y]

	# Add to container and track
	_cell_container.add_child(cell_node)
	loaded_cells[coords] = cell_node
	_loading_cells.erase(coords)

	# Create boundary walls for impassable edges
	_create_cell_boundaries(cell_node, coords)

	cell_loaded.emit(coords)
	print("[CellStreamer] Loaded cell %s (%s)" % [coords,
		cell_info.location_name if cell_info.location_name != "" else "wilderness"])


## Load a hand-crafted scene
func _load_handcrafted_cell(coords: Vector2i, cell_info: WorldGrid.CellInfo) -> Node3D:
	var scene: PackedScene = load(cell_info.scene_path)
	if not scene:
		push_error("[CellStreamer] Failed to load scene: %s" % cell_info.scene_path)
		return null

	var instance: Node3D = scene.instantiate()
	return instance


## Generate a procedural wilderness cell
func _generate_procedural_cell(coords: Vector2i, cell_info: WorldGrid.CellInfo) -> Node3D:
	# Try to use WildernessRoom if available
	if not _wilderness_room_scene:
		_wilderness_room_scene = load("res://scenes/generation/wilderness_room.tscn") as PackedScene

	if _wilderness_room_scene:
		var room: Node = _wilderness_room_scene.instantiate()

		# Configure the room
		if room.has_method("set_seamless_mode"):
			room.call("set_seamless_mode", true)

		# Set biome - WildernessRoom has this as an @export
		room.set("biome", WorldGrid.to_wilderness_biome(cell_info.biome))

		# Generate with deterministic seed
		var seed_value: int = coords.x * 10000 + coords.y + 12345
		if room.has_method("generate"):
			room.call("generate", seed_value, coords)

		return room as Node3D

	# Fallback: create a simple ground plane
	return _create_simple_cell(coords, cell_info)


## Create a simple cell as fallback
func _create_simple_cell(coords: Vector2i, cell_info: WorldGrid.CellInfo) -> Node3D:
	var cell: Node3D = Node3D.new()

	# Create ground mesh - slightly larger to avoid seams
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = Vector2(CELL_SIZE + 2.0, CELL_SIZE + 2.0)  # Overlap by 1 unit on each side
	ground.mesh = plane_mesh

	# Set material to grass green to match wilderness rooms
	var material: StandardMaterial3D = StandardMaterial3D.new()
	# Use consistent grass green color to prevent flashing with wilderness cells
	material.albedo_color = Color(0.2, 0.35, 0.15)  # Forest grass green
	material.roughness = 0.9
	ground.material_override = material

	cell.add_child(ground)

	# Add collision - also slightly larger to ensure no gaps
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.collision_layer = 1  # World layer
	static_body.collision_mask = 0   # Ground doesn't need to detect anything
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(CELL_SIZE + 2.0, 1.0, CELL_SIZE + 2.0)  # Thicker and overlapping
	collision.shape = box_shape
	collision.position.y = -0.5  # Match Elder Moor's ground level
	static_body.add_child(collision)
	cell.add_child(static_body)

	return cell


## Unload a cell
func _unload_cell(coords: Vector2i) -> void:
	if not loaded_cells.has(coords):
		return

	# NEVER unload the main scene cell - it contains environment/lighting
	if coords == _main_scene_cell:
		return

	# Don't unload externally registered cells (they weren't loaded by us)
	if _external_cells.has(coords):
		return

	var cell_node: Node3D = loaded_cells[coords]
	loaded_cells.erase(coords)

	# Clean up the cell
	if is_instance_valid(cell_node):
		cell_node.queue_free()

	cell_unloaded.emit(coords)
	print("[CellStreamer] Unloaded cell %s" % coords)


## Create boundary walls for edges with impassable adjacent cells
func _create_cell_boundaries(cell_node: Node3D, coords: Vector2i) -> void:
	var directions: Array[Vector2i] = [
		Vector2i(0, -1),  # North
		Vector2i(0, 1),   # South
		Vector2i(1, 0),   # East
		Vector2i(-1, 0)   # West
	]

	for dir: Vector2i in directions:
		var adjacent: Vector2i = coords + dir
		if not WorldGrid.is_passable(adjacent):
			_create_boundary_wall(cell_node, dir)


## Create an invisible boundary wall on one edge
func _create_boundary_wall(cell_node: Node3D, direction: Vector2i) -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.name = "BoundaryWall"

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()

	var half_size: float = CELL_SIZE / 2.0
	var wall_thickness: float = 2.0
	var wall_height: float = 10.0

	# Configure shape and position based on direction
	if direction.x != 0:
		# East/West wall
		shape.size = Vector3(wall_thickness, wall_height, CELL_SIZE)
		collision.position = Vector3(direction.x * half_size, wall_height / 2.0, 0)
	else:
		# North/South wall
		shape.size = Vector3(CELL_SIZE, wall_height, wall_thickness)
		collision.position = Vector3(0, wall_height / 2.0, -direction.y * half_size)

	collision.shape = shape
	wall.add_child(collision)
	cell_node.add_child(wall)


## ============================================================================
## PUBLIC API
## ============================================================================

## Start streaming from a given cell (called when game starts or exiting interior)
func start_streaming(start_coords: Vector2i) -> void:
	active_cell = start_coords
	streaming_enabled = true

	# Load initial cells
	_update_loaded_cells()

	streaming_resumed.emit()
	print("[CellStreamer] Streaming started at %s" % start_coords)


## Stop streaming (called when entering interior)
func stop_streaming() -> void:
	streaming_enabled = false

	# Unload all cells
	for coords: Vector2i in loaded_cells.keys():
		_unload_cell(coords)

	streaming_paused.emit()
	print("[CellStreamer] Streaming stopped")


## Pause streaming without unloading (for menus, etc.)
func pause_streaming() -> void:
	streaming_enabled = false
	streaming_paused.emit()


## Resume streaming
func resume_streaming() -> void:
	streaming_enabled = true
	streaming_resumed.emit()


## Check if streaming is active
func is_streaming() -> bool:
	return streaming_enabled


## Get the current active cell
func get_active_cell() -> Vector2i:
	return active_cell


## Get the world offset (for coordinate calculations)
func get_world_offset() -> Vector3:
	return world_offset


## Check if a cell is currently loaded
func is_cell_loaded(coords: Vector2i) -> bool:
	return loaded_cells.has(coords)


## Get the node for a loaded cell
func get_cell_node(coords: Vector2i) -> Node3D:
	return loaded_cells.get(coords, null)


## Force reload of a specific cell
func reload_cell(coords: Vector2i) -> void:
	if loaded_cells.has(coords):
		_unload_cell(coords)
	_load_cell(coords)


## Register a cell as the main scene (will never be unloaded)
## Call this from hand-crafted levels that are loaded as the main scene
func register_main_scene_cell(coords: Vector2i, cell_node: Node3D) -> void:
	_main_scene_cell = coords
	_external_cells[coords] = true
	if not loaded_cells.has(coords):
		loaded_cells[coords] = cell_node
	print("[CellStreamer] Registered main scene cell at %s" % coords)


## Teleport player to a specific cell (used for fast travel)
## This WILL reposition the player
func teleport_to_cell(coords: Vector2i, spawn_position: Vector3 = Vector3.ZERO) -> void:
	# Stop current streaming
	stop_streaming()

	# Reset world offset
	world_offset = Vector3.ZERO

	# Find player
	_find_player()
	if _player:
		# Position player
		var cell_center: Vector3 = WorldGrid.cell_to_world(coords)
		if spawn_position != Vector3.ZERO:
			_player.global_position = spawn_position
		else:
			_player.global_position = cell_center + Vector3(0, 1, 0)

	# Start streaming from new location
	start_streaming(coords)


## ============================================================================
## SAVE/LOAD
## ============================================================================

## Get save data
func get_save_data() -> Dictionary:
	return {
		"active_cell_x": active_cell.x,
		"active_cell_y": active_cell.y,
		"world_offset_x": world_offset.x,
		"world_offset_y": world_offset.y,
		"world_offset_z": world_offset.z,
		"streaming_enabled": streaming_enabled
	}


## Load save data
func load_save_data(data: Dictionary) -> void:
	active_cell = Vector2i(
		data.get("active_cell_x", 0),
		data.get("active_cell_y", 0)
	)
	world_offset = Vector3(
		data.get("world_offset_x", 0.0),
		data.get("world_offset_y", 0.0),
		data.get("world_offset_z", 0.0)
	)

	if data.get("streaming_enabled", false):
		start_streaming(active_cell)
