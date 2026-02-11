## dungeon_generator.gd - Grid-based procedural dungeon generator
## Uses a grid system where rooms snap to positions and share walls at connections
## Only creates corridor geometry when rooms have actual gaps between them
class_name DungeonGenerator
extends Node3D

signal generation_complete(dungeon: DungeonGenerator)
signal room_count_changed(count: int)

## Grid and generation settings
@export var dungeon_seed: int = 0  # 0 = random seed
@export var max_rooms: int = 8
@export var min_rooms: int = 5
@export var grid_size: float = 15.0  # Grid unit size - must be >= largest room dimension + margin
@export var wall_thickness: float = 1.0  # Consistent wall thickness everywhere

## Dungeon-wide spawn limits
## Target: 45-55% of rooms should have enemies (per design doc)
@export var total_enemies_min: int = 15
@export var total_enemies_max: int = 25
@export var total_chests_min: int = 2
@export var total_chests_max: int = 8
@export var has_boss: bool = true
@export var min_rooms_with_enemies: int = 3  # GUARANTEE at least this many rooms have enemies
@export var max_enemies_per_room: int = 4  # Cap enemies per room for balance

## Room templates (loaded at runtime or assigned)
var entrance_templates: Array[RoomTemplate] = []
var corridor_templates: Array[RoomTemplate] = []
var combat_templates: Array[RoomTemplate] = []
var empty_templates: Array[RoomTemplate] = []
var treasure_templates: Array[RoomTemplate] = []
var special_templates: Array[RoomTemplate] = []
var boss_templates: Array[RoomTemplate] = []
var quest_templates: Array[RoomTemplate] = []  # Quest room with NPC

## Generated dungeon state
var rooms: Array[DungeonRoom] = []
var room_grid: Dictionary = {}  # Vector2i -> DungeonRoom (grid position -> room)
var actual_seed: int = 0
var nav_region: NavigationRegion3D

## Spawn tracking
var enemies_to_spawn: int = 0
var chests_to_spawn: int = 0
var enemies_spawned: int = 0
var chests_spawned: int = 0
var rooms_with_enemies: Array[DungeonRoom] = []  # Track which rooms have enemies

## Zone identification
var zone_id: String = "procedural_dungeon"

## Map data for saving/loading
var map_data: Dictionary = {}

## Navigation ready flag - pathfinding should wait for this
var navigation_ready: bool = false

## Safety enclosure settings
const SAFETY_FLOOR_Y: float = -3.0
const KILL_ZONE_Y: float = -2.0
const SAFETY_CEILING_Y: float = 10.0


func _ready() -> void:
	add_to_group("dungeon")


## Generate a complete dungeon
func generate(seed_value: int = 0) -> void:
	var max_attempts := 5
	var current_seed := seed_value if seed_value != 0 else randi()

	for attempt in range(max_attempts):
		actual_seed = current_seed
		seed(actual_seed)

		print("[DungeonGenerator] Generating dungeon with seed: %d (attempt %d/%d)" % [actual_seed, attempt + 1, max_attempts])

		_clear_dungeon()
		_init_spawn_limits()
		_setup_navigation()

		# Generate room layout using grid-based placement
		if _generate_rooms_grid():
			if _validate_dungeon():
				_spawn_room_contents()
				call_deferred("_bake_navigation")
				_init_map_data()

				print("[DungeonGenerator] Generated %d rooms with %d enemies in %d rooms, %d chests" % [
					rooms.size(), enemies_spawned, rooms_with_enemies.size(), chests_spawned
				])
				generation_complete.emit(self)
				return

		print("[DungeonGenerator] Generation failed, retrying...")
		current_seed += 1

	# All attempts failed
	push_warning("[DungeonGenerator] All %d generation attempts failed, using last result" % max_attempts)
	_spawn_room_contents()
	call_deferred("_bake_navigation")
	_init_map_data()
	generation_complete.emit(self)


## Clear existing dungeon
func _clear_dungeon() -> void:
	navigation_ready = false

	for room in rooms:
		if is_instance_valid(room):
			room.queue_free()
	rooms.clear()
	room_grid.clear()
	rooms_with_enemies.clear()

	if nav_region:
		nav_region.queue_free()
		nav_region = null

	# Clear any corridor/safety geometry
	for child in get_children():
		if child.name.begins_with("Corridor") or child.name.begins_with("Safety") or child.name.begins_with("KillZone"):
			child.queue_free()

	enemies_spawned = 0
	chests_spawned = 0


## Initialize spawn limits
func _init_spawn_limits() -> void:
	enemies_to_spawn = randi_range(total_enemies_min, total_enemies_max)
	chests_to_spawn = randi_range(total_chests_min, total_chests_max)
	enemies_spawned = 0
	chests_spawned = 0
	print("[DungeonGenerator] Spawn limits: %d enemies, %d chests" % [enemies_to_spawn, chests_to_spawn])


## Set up navigation region
func _setup_navigation() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	add_child(nav_region)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.cell_size = 0.3
	nav_mesh.cell_height = 0.2
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0

	nav_region.navigation_mesh = nav_mesh


## Bake navigation mesh
func _bake_navigation() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()
		navigation_ready = true
		print("[DungeonGenerator] Navigation mesh baked!")


## Grid-based room generation
## Rooms are placed on a grid and share walls at connection points
func _generate_rooms_grid() -> bool:
	# Place entrance at grid origin
	var entrance := _place_room_at_grid(Vector2i.ZERO, _get_entrance_template())
	if not entrance:
		push_error("[DungeonGenerator] Failed to place entrance!")
		return false

	# Track open connections to expand from
	var open_connections: Array[Dictionary] = []  # {grid_pos, direction, source_room}

	# Add entrance's door directions as open connections
	for dir in entrance.template.get_door_directions():
		var grid_dir := _vector3_to_grid_dir(dir)
		open_connections.append({
			"grid_pos": Vector2i.ZERO + grid_dir,
			"direction": dir,
			"source_room": entrance
		})

	# Expand dungeon
	var attempts := 0
	var max_attempts := max_rooms * 15

	while rooms.size() < max_rooms and not open_connections.is_empty() and attempts < max_attempts:
		attempts += 1

		# Pick random open connection
		var conn_idx := randi() % open_connections.size()
		var conn: Dictionary = open_connections[conn_idx]
		open_connections.remove_at(conn_idx)

		var target_grid: Vector2i = conn.grid_pos
		var from_dir: Vector3 = conn.direction
		var source_room: DungeonRoom = conn.source_room

		# Skip if grid position already occupied
		if room_grid.has(target_grid):
			continue

		# Select appropriate room template
		var template := _select_room_template_for_connection(-from_dir)
		if not template:
			continue

		# Check if template has matching door
		if not template.has_door_on_side(-from_dir):
			continue

		# Place the room
		var new_room := _place_room_at_grid(target_grid, template)
		if not new_room:
			continue

		# Connect rooms
		source_room.connected_rooms[from_dir] = new_room
		new_room.connected_rooms[-from_dir] = source_room

		# Add new room's other doors as open connections
		for dir in new_room.template.get_door_directions():
			if dir != -from_dir:  # Don't go back
				var grid_dir := _vector3_to_grid_dir(dir)
				var next_grid := target_grid + grid_dir
				if not room_grid.has(next_grid):
					open_connections.append({
						"grid_pos": next_grid,
						"direction": dir,
						"source_room": new_room
					})

		room_count_changed.emit(rooms.size())

	# Ensure boss room exists
	_ensure_boss_room()

	# Seal all unused doors
	_seal_unused_doors()

	# Create corridors only where needed (rooms not adjacent)
	_create_corridors_where_needed()

	# Create safety enclosure
	_create_safety_enclosure()

	print("[DungeonGenerator] Placed %d rooms in %d attempts" % [rooms.size(), attempts])
	return rooms.size() >= min_rooms


## Place a room at a grid position
func _place_room_at_grid(grid_pos: Vector2i, template: RoomTemplate) -> DungeonRoom:
	if room_grid.has(grid_pos):
		return null  # Already occupied

	# Calculate world position from grid
	var world_pos := Vector3(
		grid_pos.x * grid_size,
		0,
		grid_pos.y * grid_size
	)

	var room := DungeonRoom.new()
	room.name = "Room_%d_%s" % [rooms.size(), template.room_type]
	room.wall_thickness = wall_thickness
	add_child(room)
	room.setup(template, world_pos, rooms.size())

	rooms.append(room)
	room_grid[grid_pos] = room

	# Store grid position on room for later reference
	room.set_meta("grid_pos", grid_pos)

	# Connect signals
	room.room_entered.connect(_on_room_entered)
	room.room_cleared.connect(_on_room_cleared)

	return room


## Convert Vector3 direction to grid direction (Vector2i)
func _vector3_to_grid_dir(dir: Vector3) -> Vector2i:
	if dir.is_equal_approx(Vector3.FORWARD):
		return Vector2i(0, 1)  # +Z
	elif dir.is_equal_approx(Vector3.BACK):
		return Vector2i(0, -1)  # -Z
	elif dir.is_equal_approx(Vector3.RIGHT):
		return Vector2i(1, 0)  # +X
	elif dir.is_equal_approx(Vector3.LEFT):
		return Vector2i(-1, 0)  # -X
	return Vector2i.ZERO


## Get entrance template
func _get_entrance_template() -> RoomTemplate:
	if entrance_templates.is_empty():
		push_error("[DungeonGenerator] No entrance templates!")
		return null
	return entrance_templates[randi() % entrance_templates.size()]


## Select room template that can connect from a given direction
func _select_room_template_for_connection(required_door_dir: Vector3) -> RoomTemplate:
	var candidates: Array[RoomTemplate] = []
	var weights: Array[float] = []

	# Gather all templates that have a door on the required side
	for t in combat_templates:
		if t.has_door_on_side(required_door_dir):
			candidates.append(t)
			weights.append(3.0)

	for t in empty_templates:
		if t.has_door_on_side(required_door_dir):
			candidates.append(t)
			weights.append(2.0)

	for t in corridor_templates:
		if t.has_door_on_side(required_door_dir):
			candidates.append(t)
			weights.append(2.0)

	for t in treasure_templates:
		if t.has_door_on_side(required_door_dir):
			candidates.append(t)
			weights.append(1.0)

	for t in special_templates:
		if t.has_door_on_side(required_door_dir):
			candidates.append(t)
			weights.append(0.5)

	# Add quest room with low weight (rare)
	for t in quest_templates:
		if t.has_door_on_side(required_door_dir):
			candidates.append(t)
			weights.append(0.3)

	if candidates.is_empty():
		return null

	# Weighted random selection
	var total_weight := 0.0
	for w in weights:
		total_weight += w

	var roll := randf() * total_weight
	var cumulative := 0.0

	for i in range(candidates.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return candidates[i]

	return candidates[0]


## Ensure boss room is placed
func _ensure_boss_room() -> void:
	if boss_templates.is_empty():
		push_warning("[DungeonGenerator] No boss templates available!")
		return

	# Check if boss room already exists
	for room in rooms:
		if room.template.is_boss_room:
			return

	# Find furthest room from entrance and try to attach boss room
	var entrance: DungeonRoom = rooms[0] if not rooms.is_empty() else null
	if not entrance:
		return

	var rooms_by_distance: Array[DungeonRoom] = []
	for room in rooms:
		if room != entrance:
			rooms_by_distance.append(room)

	rooms_by_distance.sort_custom(func(a: DungeonRoom, b: DungeonRoom) -> bool:
		return a.room_center.distance_to(entrance.room_center) > b.room_center.distance_to(entrance.room_center)
	)

	for candidate_room in rooms_by_distance:
		var candidate_grid: Vector2i = candidate_room.get_meta("grid_pos", Vector2i.ZERO)

		for dir in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			if candidate_room.connected_rooms.has(dir):
				continue

			if not candidate_room.template.has_door_on_side(dir):
				continue

			var grid_dir := _vector3_to_grid_dir(dir)
			var boss_grid := candidate_grid + grid_dir

			if room_grid.has(boss_grid):
				continue

			var boss_template: RoomTemplate = boss_templates[randi() % boss_templates.size()]
			if not boss_template.has_door_on_side(-dir):
				continue

			var boss_room := _place_room_at_grid(boss_grid, boss_template)
			if boss_room:
				candidate_room.connected_rooms[dir] = boss_room
				boss_room.connected_rooms[-dir] = candidate_room
				print("[DungeonGenerator] Placed boss room at grid %s" % str(boss_grid))
				return

	push_warning("[DungeonGenerator] Could not place boss room! Setting has_boss = false")
	has_boss = false  # Disable boss spawn since room couldn't be placed


## Seal unused doors on all rooms
func _seal_unused_doors() -> void:
	var sealed_count := 0
	for room in rooms:
		for dir in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			if room.template.has_door_on_side(dir) and not room.connected_rooms.has(dir):
				sealed_count += 1
		room.seal_unused_doors()
	print("[DungeonGenerator] Sealed %d unused door gaps" % sealed_count)


## Create corridors only where rooms are not directly adjacent on the grid
## Adjacent rooms share walls, non-adjacent need corridor bridges
func _create_corridors_where_needed() -> void:
	# Load textures for corridors
	var floor_texture: Texture2D = load("res://Sprite folders grab bag/stonefloor.png")
	var wall_texture: Texture2D = load("res://Sprite folders grab bag/stonewall.png")

	var corridor_mat := StandardMaterial3D.new()
	corridor_mat.albedo_color = Color(0.12, 0.1, 0.14)
	corridor_mat.roughness = 0.9
	if floor_texture:
		corridor_mat.albedo_texture = floor_texture
		corridor_mat.uv1_scale = Vector3(2, 2, 1)
		corridor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.18, 0.15, 0.2)
	wall_mat.roughness = 0.95
	if wall_texture:
		wall_mat.albedo_texture = wall_texture
		wall_mat.uv1_scale = Vector3(2, 2, 1)
		wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var made_connections: Dictionary = {}  # Track processed connections

	for room in rooms:
		var room_grid_pos: Vector2i = room.get_meta("grid_pos", Vector2i.ZERO)

		for dir: Vector3 in room.connected_rooms:
			var other_room: DungeonRoom = room.connected_rooms[dir]
			var other_grid_pos: Vector2i = other_room.get_meta("grid_pos", Vector2i.ZERO)

			# Create connection ID to avoid duplicates
			var min_idx := mini(room.room_index, other_room.room_index)
			var max_idx := maxi(room.room_index, other_room.room_index)
			var conn_id := "%d-%d" % [min_idx, max_idx]

			if made_connections.has(conn_id):
				continue
			made_connections[conn_id] = true

			# Check if rooms are directly adjacent on grid
			var expected_neighbor := room_grid_pos + _vector3_to_grid_dir(dir)
			if expected_neighbor == other_grid_pos:
				# Rooms are adjacent - they share a wall, no corridor needed
				# Just ensure floor continuity at the door gap
				_create_door_floor_bridge(room, other_room, dir, corridor_mat)
			else:
				# Rooms have a gap - create full corridor
				_create_full_corridor(room, other_room, dir, corridor_mat, wall_mat)

	print("[DungeonGenerator] Processed %d corridor connections" % made_connections.size())


## Create a floor bridge at a door gap between rooms
## Calculates actual floor edge positions and creates a bridge that covers any gap
func _create_door_floor_bridge(room1: DungeonRoom, room2: DungeonRoom, direction: Vector3, floor_mat: StandardMaterial3D) -> void:
	var door1 := room1.template.get_door_on_side(direction)
	var door2 := room2.template.get_door_on_side(-direction)
	var door_width := maxf(door1.get("width", 4.0), door2.get("width", 4.0))

	# Calculate actual floor edge positions based on room dimensions
	var room1_extent := _get_room_extent(room1.template, direction)
	var room2_extent := _get_room_extent(room2.template, -direction)

	# Floor edges in world space (where each room's floor actually ends)
	var room1_floor_edge: float
	var room2_floor_edge: float

	if abs(direction.x) > abs(direction.z):
		# East-West connection (along X axis)
		room1_floor_edge = room1.room_center.x + sign(direction.x) * room1_extent
		room2_floor_edge = room2.room_center.x - sign(direction.x) * room2_extent
	else:
		# North-South connection (along Z axis)
		room1_floor_edge = room1.room_center.z + sign(direction.z) * room1_extent
		room2_floor_edge = room2.room_center.z - sign(direction.z) * room2_extent

	# Calculate gap between floor edges
	var gap_start := minf(room1_floor_edge, room2_floor_edge)
	var gap_end := maxf(room1_floor_edge, room2_floor_edge)
	var gap_distance := gap_end - gap_start
	var gap_center := (gap_start + gap_end) / 2.0

	# Bridge length: cover the gap plus overlap for safety (min 3 units to ensure solid connection)
	var bridge_length := maxf(gap_distance + 2.0, 3.0)

	var bridge := CSGBox3D.new()
	bridge.name = "DoorBridge_%d_%d" % [room1.room_index, room2.room_index]

	if abs(direction.x) > abs(direction.z):
		# East-West connection
		bridge.size = Vector3(bridge_length, 1.0, door_width)
		bridge.position = Vector3(gap_center, -0.5, room1.room_center.z)
	else:
		# North-South connection
		bridge.size = Vector3(door_width, 1.0, bridge_length)
		bridge.position = Vector3(room1.room_center.x, -0.5, gap_center)

	bridge.material = floor_mat
	bridge.use_collision = true
	add_child(bridge)

	if gap_distance > 0.1:
		print("[DungeonGenerator] Created floor bridge covering %.1f unit gap between rooms %d and %d" % [
			gap_distance, room1.room_index, room2.room_index
		])


## Create a full corridor with floor, ceiling, and walls
func _create_full_corridor(room1: DungeonRoom, room2: DungeonRoom, direction: Vector3, floor_mat: StandardMaterial3D, wall_mat: StandardMaterial3D) -> void:
	var door1 := room1.template.get_door_on_side(direction)
	var door2 := room2.template.get_door_on_side(-direction)
	var door_width := maxf(door1.get("width", 4.0), door2.get("width", 4.0))
	var corridor_height := 4.0

	# Calculate room edges
	var room1_extent := _get_room_extent(room1.template, direction)
	var room2_extent := _get_room_extent(room2.template, -direction)

	var room1_edge: Vector3 = room1.room_center + direction * (room1_extent + wall_thickness / 2.0)
	var room2_edge: Vector3 = room2.room_center - direction * (room2_extent + wall_thickness / 2.0)

	var corridor_center := (room1_edge + room2_edge) / 2.0
	var corridor_length := room1_edge.distance_to(room2_edge)

	if corridor_length < 0.5:
		return  # Rooms too close, use door bridge instead

	var conn_id := "%d_%d" % [room1.room_index, room2.room_index]

	# Floor
	var floor_csg := CSGBox3D.new()
	floor_csg.name = "CorridorFloor_%s" % conn_id

	if abs(direction.x) > abs(direction.z):
		floor_csg.size = Vector3(corridor_length, 1.0, door_width)
	else:
		floor_csg.size = Vector3(door_width, 1.0, corridor_length)

	floor_csg.position = corridor_center + Vector3(0, -0.5, 0)
	floor_csg.material = floor_mat
	floor_csg.use_collision = true
	add_child(floor_csg)

	# Ceiling
	var ceiling_csg := CSGBox3D.new()
	ceiling_csg.name = "CorridorCeiling_%s" % conn_id
	ceiling_csg.size = floor_csg.size
	ceiling_csg.size.y = 0.5
	ceiling_csg.position = corridor_center + Vector3(0, corridor_height, 0)
	ceiling_csg.material = wall_mat
	ceiling_csg.use_collision = true
	add_child(ceiling_csg)

	# Walls
	_create_corridor_walls(corridor_center, floor_csg.size, corridor_height, direction, wall_mat)

	# Torch
	_spawn_corridor_torch(corridor_center, corridor_height)


## Create corridor walls
func _create_corridor_walls(center: Vector3, floor_size: Vector3, height: float, direction: Vector3, mat: StandardMaterial3D) -> void:
	if abs(direction.x) > abs(direction.z):
		# East-West corridor - walls on North and South
		var wall_north := CSGBox3D.new()
		wall_north.size = Vector3(floor_size.x, height, wall_thickness)
		wall_north.position = center + Vector3(0, height / 2.0, floor_size.z / 2.0 + wall_thickness / 2.0)
		wall_north.material = mat
		wall_north.use_collision = true
		add_child(wall_north)

		var wall_south := CSGBox3D.new()
		wall_south.size = Vector3(floor_size.x, height, wall_thickness)
		wall_south.position = center + Vector3(0, height / 2.0, -floor_size.z / 2.0 - wall_thickness / 2.0)
		wall_south.material = mat
		wall_south.use_collision = true
		add_child(wall_south)
	else:
		# North-South corridor - walls on East and West
		var wall_east := CSGBox3D.new()
		wall_east.size = Vector3(wall_thickness, height, floor_size.z)
		wall_east.position = center + Vector3(floor_size.x / 2.0 + wall_thickness / 2.0, height / 2.0, 0)
		wall_east.material = mat
		wall_east.use_collision = true
		add_child(wall_east)

		var wall_west := CSGBox3D.new()
		wall_west.size = Vector3(wall_thickness, height, floor_size.z)
		wall_west.position = center + Vector3(-floor_size.x / 2.0 - wall_thickness / 2.0, height / 2.0, 0)
		wall_west.material = mat
		wall_west.use_collision = true
		add_child(wall_west)


## Spawn corridor torch
func _spawn_corridor_torch(pos: Vector3, height: float) -> void:
	var torch_light := OmniLight3D.new()
	torch_light.name = "CorridorTorch"
	torch_light.light_color = Color(1.0, 0.7, 0.4)
	torch_light.light_energy = 1.5
	torch_light.omni_range = 8.0
	torch_light.omni_attenuation = 1.5
	torch_light.position = pos + Vector3(0, height - 1.0, 0)
	add_child(torch_light)


## Create safety enclosure around entire dungeon
func _create_safety_enclosure() -> void:
	if rooms.is_empty():
		return

	# Calculate dungeon bounds
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF

	for room in rooms:
		var half_w := room.template.width / 2.0
		var half_d := room.template.depth / 2.0
		min_x = minf(min_x, room.room_center.x - half_w)
		max_x = maxf(max_x, room.room_center.x + half_w)
		min_z = minf(min_z, room.room_center.z - half_d)
		max_z = maxf(max_z, room.room_center.z + half_d)

	# Add margin
	var margin := 15.0
	min_x -= margin
	max_x += margin
	min_z -= margin
	max_z += margin

	var width := max_x - min_x
	var depth := max_z - min_z
	var center_x := (min_x + max_x) / 2.0
	var center_z := (min_z + max_z) / 2.0

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.1, 0.05, 0.05)
	floor_mat.roughness = 1.0

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.05, 0.05, 0.05)
	wall_mat.roughness = 1.0

	# Safety floor at Y=-3 (closer to play area)
	var safety_floor := CSGBox3D.new()
	safety_floor.name = "SafetyFloor"
	safety_floor.size = Vector3(width, 1.0, depth)
	safety_floor.position = Vector3(center_x, SAFETY_FLOOR_Y - 0.5, center_z)
	safety_floor.material = floor_mat
	safety_floor.use_collision = true
	add_child(safety_floor)

	# Safety ceiling
	var safety_ceiling := CSGBox3D.new()
	safety_ceiling.name = "SafetyCeiling"
	safety_ceiling.size = Vector3(width, 1.0, depth)
	safety_ceiling.position = Vector3(center_x, SAFETY_CEILING_Y, center_z)
	safety_ceiling.material = wall_mat
	safety_ceiling.use_collision = true
	add_child(safety_ceiling)

	# Perimeter walls
	var wall_height := SAFETY_CEILING_Y - SAFETY_FLOOR_Y + 2.0
	var wall_y := (SAFETY_FLOOR_Y + SAFETY_CEILING_Y) / 2.0

	# North wall
	var north_wall := CSGBox3D.new()
	north_wall.name = "SafetyWallNorth"
	north_wall.size = Vector3(width + wall_thickness * 2, wall_height, wall_thickness)
	north_wall.position = Vector3(center_x, wall_y, max_z + wall_thickness / 2.0)
	north_wall.material = wall_mat
	north_wall.use_collision = true
	add_child(north_wall)

	# South wall
	var south_wall := CSGBox3D.new()
	south_wall.name = "SafetyWallSouth"
	south_wall.size = Vector3(width + wall_thickness * 2, wall_height, wall_thickness)
	south_wall.position = Vector3(center_x, wall_y, min_z - wall_thickness / 2.0)
	south_wall.material = wall_mat
	south_wall.use_collision = true
	add_child(south_wall)

	# East wall
	var east_wall := CSGBox3D.new()
	east_wall.name = "SafetyWallEast"
	east_wall.size = Vector3(wall_thickness, wall_height, depth)
	east_wall.position = Vector3(max_x + wall_thickness / 2.0, wall_y, center_z)
	east_wall.material = wall_mat
	east_wall.use_collision = true
	add_child(east_wall)

	# West wall
	var west_wall := CSGBox3D.new()
	west_wall.name = "SafetyWallWest"
	west_wall.size = Vector3(wall_thickness, wall_height, depth)
	west_wall.position = Vector3(min_x - wall_thickness / 2.0, wall_y, center_z)
	west_wall.material = wall_mat
	west_wall.use_collision = true
	add_child(west_wall)

	# Kill zone area (triggers respawn if player falls below Y=-2)
	var kill_zone := Area3D.new()
	kill_zone.name = "KillZone"
	kill_zone.collision_layer = 0
	kill_zone.collision_mask = 2  # Player layer

	var kill_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(width + 50, 2.0, depth + 50)
	kill_shape.shape = box_shape
	kill_shape.position = Vector3(center_x, KILL_ZONE_Y - 1.0, center_z)
	kill_zone.add_child(kill_shape)

	kill_zone.body_entered.connect(_on_kill_zone_entered)
	add_child(kill_zone)

	print("[DungeonGenerator] Created safety enclosure: %.0fx%.0f, kill zone at Y=%.1f" % [width, depth, KILL_ZONE_Y])


## Handle player falling into kill zone
func _on_kill_zone_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		print("[DungeonGenerator] Player fell into kill zone!")
		# Teleport player back to entrance
		var entrance_room := get_entrance_room()
		if entrance_room:
			body.global_position = entrance_room.room_center + Vector3(0, 1, 0)
		# Deal fall damage
		if body.has_method("take_damage"):
			body.take_damage(10, Enums.DamageType.PHYSICAL, null)


## Get room extent in a direction
func _get_room_extent(template: RoomTemplate, direction: Vector3) -> float:
	if abs(direction.x) > abs(direction.z):
		return template.width / 2.0
	else:
		return template.depth / 2.0


## Spawn content in rooms
func _spawn_room_contents() -> void:
	var scene := get_tree().current_scene

	var combat_rooms: Array[DungeonRoom] = []
	var chest_rooms: Array[DungeonRoom] = []
	var quest_room: DungeonRoom = null

	for room in rooms:
		# Every room gets torches
		room.spawn_torches()

		# Entrance room
		if room == rooms[0] and room.template.room_type == "entrance":
			room.spawn_portal(scene)
			continue

		# Boss room
		if room.template.is_boss_room:
			if has_boss:
				room.spawn_boss(scene)
			chest_rooms.append(room)
			continue

		# Quest room
		if room.template.room_type == "quest":
			quest_room = room
			room.spawn_quest_npc(scene)
			continue

		# Rest spots
		if room.template.has_rest_spot:
			room.spawn_rest_spot(scene)
			continue

		# Regular rooms for combat and chests
		combat_rooms.append(room)
		chest_rooms.append(room)

	# Distribute enemies with guarantee
	_distribute_enemies_guaranteed(scene, combat_rooms)

	# Distribute chests
	_distribute_chests(scene, chest_rooms)

	# Create corridors already done in _generate_rooms_grid


## Distribute enemies with GUARANTEE of at least min_rooms_with_enemies rooms having enemies
func _distribute_enemies_guaranteed(scene: Node, combat_rooms: Array[DungeonRoom]) -> void:
	if combat_rooms.is_empty():
		push_warning("[DungeonGenerator] No combat rooms for enemy spawning!")
		return

	rooms_with_enemies.clear()

	if enemies_to_spawn <= 0:
		enemies_to_spawn = total_enemies_min

	var shuffled_rooms := combat_rooms.duplicate()
	shuffled_rooms.shuffle()

	# GUARANTEE: First ensure minimum rooms have at least 1 enemy each
	var guaranteed_rooms := mini(min_rooms_with_enemies, shuffled_rooms.size())
	for i in range(guaranteed_rooms):
		if enemies_spawned < enemies_to_spawn:
			var room: DungeonRoom = shuffled_rooms[i]
			room.spawn_single_enemy(scene, self, true)  # true = roaming enemy
			enemies_spawned += 1
			if room not in rooms_with_enemies:
				rooms_with_enemies.append(room)
			print("[DungeonGenerator] GUARANTEED roaming enemy in room %d (%s)" % [room.room_index, room.template.room_type])

	# Distribute remaining enemies
	var room_idx := 0
	var max_iterations := shuffled_rooms.size() * 3
	while enemies_spawned < enemies_to_spawn and room_idx < max_iterations:
		var room: DungeonRoom = shuffled_rooms[room_idx % shuffled_rooms.size()]
		var enemies_in_room := room.enemies_spawned.size()

		if enemies_in_room < 3:
			room.spawn_single_enemy(scene, self, true)  # All enemies roam
			enemies_spawned += 1
			if room not in rooms_with_enemies:
				rooms_with_enemies.append(room)

		room_idx += 1

	print("[DungeonGenerator] Spawned %d roaming enemies across %d rooms" % [enemies_spawned, rooms_with_enemies.size()])


## Distribute chests
func _distribute_chests(scene: Node, chest_rooms: Array[DungeonRoom]) -> void:
	if chest_rooms.is_empty() or chests_to_spawn <= 0:
		return

	var shuffled_rooms := chest_rooms.duplicate()
	shuffled_rooms.shuffle()

	for i in range(mini(chests_to_spawn, shuffled_rooms.size())):
		var room: DungeonRoom = shuffled_rooms[i]
		room.spawn_single_chest(scene)
		chests_spawned += 1


## Validate dungeon
func _validate_dungeon() -> bool:
	if rooms.is_empty():
		push_warning("[DungeonGenerator] No rooms generated!")
		return false

	var entrance := rooms[0]
	if entrance.connected_rooms.is_empty():
		push_warning("[DungeonGenerator] Entrance has no connections!")
		return false

	if rooms.size() < min_rooms:
		push_warning("[DungeonGenerator] Only %d rooms (min: %d)" % [rooms.size(), min_rooms])
		return false

	# Connectivity check
	var reachable := _count_reachable_rooms(entrance)
	if reachable < rooms.size():
		push_warning("[DungeonGenerator] Only %d/%d rooms reachable" % [reachable, rooms.size()])
		return false

	# Bidirectional connection check
	for room in rooms:
		for dir: Vector3 in room.connected_rooms:
			var other: DungeonRoom = room.connected_rooms[dir]
			if not other.connected_rooms.has(-dir) or other.connected_rooms[-dir] != room:
				push_warning("[DungeonGenerator] Invalid connection!")
				return false

	return true


## Count reachable rooms via BFS
func _count_reachable_rooms(start: DungeonRoom) -> int:
	var visited: Array[DungeonRoom] = []
	var queue: Array[DungeonRoom] = [start]

	while not queue.is_empty():
		var current: DungeonRoom = queue.pop_front()
		if current in visited:
			continue
		visited.append(current)

		for dir: Vector3 in current.connected_rooms:
			var neighbor: DungeonRoom = current.connected_rooms[dir]
			if neighbor and neighbor not in visited:
				queue.append(neighbor)

	return visited.size()


## Initialize map data
func _init_map_data() -> void:
	map_data = {
		"zone_id": zone_id + "_" + str(actual_seed),
		"seed": actual_seed,
		"grid_size": grid_size,
		"revealed_cells": [],
		"rooms": [],
		"player_markers": []
	}

	for room in rooms:
		map_data.rooms.append({
			"bounds": _rect2_to_dict(room.get_map_bounds()),
			"type": room.template.room_type,
			"explored": room.is_explored,
			"cleared": room.is_cleared,
			"center": _vector3_to_dict(room.room_center),
			"has_enemies": room in rooms_with_enemies
		})


func _rect2_to_dict(r: Rect2) -> Dictionary:
	return {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y}


func _vector3_to_dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


## Room callbacks
func _on_room_entered(room: DungeonRoom) -> void:
	print("[DungeonGenerator] Room entered: %s" % room.room_id)
	for i in range(map_data.rooms.size()):
		if i == room.room_index:
			map_data.rooms[i].explored = true
			break


func _on_room_cleared(room: DungeonRoom) -> void:
	print("[DungeonGenerator] Room cleared: %s" % room.room_id)
	for i in range(map_data.rooms.size()):
		if i == room.room_index:
			map_data.rooms[i].cleared = true
			break


## Get room at position
func get_room_at_position(world_pos: Vector3) -> DungeonRoom:
	for room in rooms:
		if room.contains_point(world_pos):
			return room
	return null


## Get entrance room
func get_entrance_room() -> DungeonRoom:
	for room in rooms:
		if room.template.room_type == "entrance":
			return room
	return rooms[0] if not rooms.is_empty() else null


## Get boss room
func get_boss_room() -> DungeonRoom:
	for room in rooms:
		if room.template.is_boss_room:
			return room
	return null


## Get quest room
func get_quest_room() -> DungeonRoom:
	for room in rooms:
		if room.template.room_type == "quest":
			return room
	return null


## Get rooms with enemies (for quest objectives)
func get_enemy_rooms() -> Array[DungeonRoom]:
	return rooms_with_enemies


## Load templates from directory
func load_templates_from_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		push_error("[DungeonGenerator] Cannot open template directory: " + path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path := path + "/" + file_name
			var template: RoomTemplate = load(full_path)
			if template:
				_categorize_template(template)
		file_name = dir.get_next()

	dir.list_dir_end()
	print("[DungeonGenerator] Loaded templates - Entrance: %d, Corridor: %d, Combat: %d, Treasure: %d, Special: %d, Boss: %d, Quest: %d" % [
		entrance_templates.size(), corridor_templates.size(), combat_templates.size(),
		treasure_templates.size(), special_templates.size(), boss_templates.size(), quest_templates.size()
	])


## Categorize template
func _categorize_template(template: RoomTemplate) -> void:
	match template.room_type:
		"entrance":
			entrance_templates.append(template)
		"corridor":
			corridor_templates.append(template)
		"guard", "prison":
			combat_templates.append(template)
		"empty":
			empty_templates.append(template)
		"treasure":
			treasure_templates.append(template)
		"shrine":
			special_templates.append(template)
		"boss":
			boss_templates.append(template)
		"quest":
			quest_templates.append(template)
		_:
			combat_templates.append(template)


## Add template directly
func add_template(template: RoomTemplate) -> void:
	# Reject templates that exceed grid size to prevent overlap
	if template.width > grid_size or template.depth > grid_size:
		push_error("[DungeonGenerator] Template '%s' (%dx%d) exceeds grid size (%.0f). REJECTED to prevent overlap!" % [
			template.room_id, template.width, template.depth, grid_size
		])
		return

	# Validate and fix door positions to ensure they're flush against walls
	template.validate_doors()

	_categorize_template(template)
