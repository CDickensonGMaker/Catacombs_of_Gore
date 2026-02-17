## elder_moor.gd - Elder Moor (Logging Camp Starter Town)
## Small logging hamlet in the forests of Kreigstan - player's starting location
## Scene-based layout with runtime navigation baking and day/night cycle
extends Node3D

const ZONE_ID := "village_elder_moor"
const ZONE_SIZE := 300.0  # 300x300 unit region (expanded from 60x60)

## Town center radius - buildings are kept within this area
const TOWN_RADIUS := 35.0

## Elder Moor grid coordinates (from WorldData GRID_DATA)
const GRID_COORDS := Vector2i(12, 8)

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

## Edge triggers for wilderness transitions
var edge_triggers: Dictionary = {}


func _ready() -> void:
	# Set current region so the world map knows player is in Elder Moor
	if SceneManager:
		SceneManager.set_current_region(ZONE_ID)

	_setup_navigation()
	_setup_day_night_cycle()
	_setup_spawn_point_metadata()
	_create_invisible_border_walls()  # Create walls with gaps for passable edges
	_setup_edge_exits()  # Add edge triggers for wilderness transitions
	_spawn_enemy_spawners()  # Spawn goblin totems and wolf dens in wilderness
	_spawn_harvestable_herbs()  # Spawn herb nodes in wilderness
	print("[Elder Moor] Logging camp initialized (Zone size: %dx%d)" % [ZONE_SIZE, ZONE_SIZE])


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Elder Moor] NavigationRegion3D not found in scene")
		return

	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0

	nav_region.navigation_mesh = nav_mesh
	call_deferred("_bake_navigation")


func _bake_navigation() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()
		print("[Elder Moor] Navigation mesh baked")


## Setup dynamic day/night lighting
func _setup_day_night_cycle() -> void:
	DayNightCycle.add_to_level(self)


## Add metadata to spawn points for proper identification
func _setup_spawn_point_metadata() -> void:
	var spawn_points := get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	for child in spawn_points.get_children():
		if child.is_in_group("spawn_points"):
			child.set_meta("spawn_id", child.name)


## Setup edge exits for transitioning to adjacent wilderness cells
## Elder Moor at (11, 8) - creates exits for all passable adjacent cells
func _setup_edge_exits() -> void:
	var edges_container := Node3D.new()
	edges_container.name = "EdgeExits"
	add_child(edges_container)

	# Check each direction and create edge trigger if passable
	var directions: Array[Dictionary] = [
		{"dir": RoomEdge.Direction.NORTH, "offset": Vector2i(0, -1), "name": "North"},
		{"dir": RoomEdge.Direction.SOUTH, "offset": Vector2i(0, 1), "name": "South"},
		{"dir": RoomEdge.Direction.EAST, "offset": Vector2i(1, 0), "name": "East"},
		{"dir": RoomEdge.Direction.WEST, "offset": Vector2i(-1, 0), "name": "West"}
	]

	var distance: float = ZONE_SIZE / 2.0

	for dir_data: Dictionary in directions:
		var direction: int = dir_data["dir"]
		var offset: Vector2i = dir_data["offset"]
		var dir_name: String = dir_data["name"]
		var adjacent_coords: Vector2i = GRID_COORDS + offset

		# Check if adjacent cell is passable
		if WorldData.is_passable(adjacent_coords):
			var edge := RoomEdge.new()
			edge.direction = direction
			edge.room_size = ZONE_SIZE

			# Calculate edge position
			var edge_pos: Vector3
			var gate_rotation: float = 0.0
			match direction:
				RoomEdge.Direction.NORTH:
					edge_pos = Vector3(0, 0, -distance - 5)
					edge.name = "NorthEdge"
					gate_rotation = 0.0
				RoomEdge.Direction.SOUTH:
					edge_pos = Vector3(0, 0, distance + 5)
					edge.name = "SouthEdge"
					gate_rotation = PI
				RoomEdge.Direction.EAST:
					edge_pos = Vector3(distance + 5, 0, 0)
					edge.name = "EastEdge"
					gate_rotation = -PI / 2.0
				RoomEdge.Direction.WEST:
					edge_pos = Vector3(-distance - 5, 0, 0)
					edge.name = "WestEdge"
					gate_rotation = PI / 2.0

			edge.position = edge_pos
			edges_container.add_child(edge)
			edge.setup_collision()
			edge.edge_entered.connect(_on_edge_entered)
			edge_triggers[direction] = edge

			# Create visible gate/archway marker at this exit
			_create_exit_gate(edges_container, edge_pos, gate_rotation, dir_name)

			print("[Elder Moor] Created %s edge exit to %s" % [dir_name, adjacent_coords])
		else:
			print("[Elder Moor] %s edge blocked (impassable terrain at %s)" % [dir_name, adjacent_coords])


## Create a visible gate/archway to mark an exit
func _create_exit_gate(parent: Node3D, pos: Vector3, rotation_y: float, direction_name: String) -> void:
	var gate := Node3D.new()
	gate.name = "%sGate" % direction_name
	gate.position = pos
	gate.rotation.y = rotation_y
	parent.add_child(gate)

	# Gate material
	var gate_mat := StandardMaterial3D.new()
	gate_mat.albedo_color = Color(0.4, 0.35, 0.3)
	gate_mat.roughness = 0.9

	# Left pillar
	var left_pillar := CSGBox3D.new()
	left_pillar.name = "LeftPillar"
	left_pillar.size = Vector3(1.5, 4.0, 1.5)
	left_pillar.position = Vector3(-3.5, 2.0, 0)
	left_pillar.material = gate_mat
	gate.add_child(left_pillar)

	# Right pillar
	var right_pillar := CSGBox3D.new()
	right_pillar.name = "RightPillar"
	right_pillar.size = Vector3(1.5, 4.0, 1.5)
	right_pillar.position = Vector3(3.5, 2.0, 0)
	right_pillar.material = gate_mat
	gate.add_child(right_pillar)

	# Top beam (lintel)
	var lintel := CSGBox3D.new()
	lintel.name = "Lintel"
	lintel.size = Vector3(9.0, 1.0, 1.5)
	lintel.position = Vector3(0, 4.5, 0)
	lintel.material = gate_mat
	gate.add_child(lintel)

	# Direction sign
	var sign_mat := StandardMaterial3D.new()
	sign_mat.albedo_color = Color(0.3, 0.25, 0.2)

	var sign_board := CSGBox3D.new()
	sign_board.name = "SignBoard"
	sign_board.size = Vector3(4.0, 1.0, 0.2)
	sign_board.position = Vector3(0, 3.2, 0.8)
	sign_board.material = sign_mat
	gate.add_child(sign_board)

	# Add label
	var label := Label3D.new()
	label.name = "DirectionLabel"
	label.text = "To %s" % direction_name
	label.font_size = 48
	label.position = Vector3(0, 3.2, 0.95)
	label.pixel_size = 0.01
	label.modulate = Color(0.9, 0.85, 0.7)
	gate.add_child(label)


## Handle player entering an edge trigger
func _on_edge_entered(direction: RoomEdge.Direction) -> void:
	print("[Elder Moor] Player entered %s edge, transitioning to wilderness" % RoomEdge.Direction.keys()[direction])

	# Calculate target coords
	var offset: Vector2i
	match direction:
		RoomEdge.Direction.NORTH:
			offset = Vector2i(0, -1)
		RoomEdge.Direction.SOUTH:
			offset = Vector2i(0, 1)
		RoomEdge.Direction.EAST:
			offset = Vector2i(1, 0)
		RoomEdge.Direction.WEST:
			offset = Vector2i(-1, 0)

	var target_coords: Vector2i = GRID_COORDS + offset

	# Store current coords for potential return
	SceneManager.current_room_coords = GRID_COORDS

	# Enter wilderness at the adjacent cell
	SceneManager.enter_wilderness(target_coords, direction)


## Create invisible collision walls at borders - with gaps for passable edges
## Passable edges have edge triggers, blocked edges have solid walls
func _create_invisible_border_walls() -> void:
	var distance: float = ZONE_SIZE / 2.0  # 30 units
	var wall_height: float = 4.0
	var wall_thickness: float = 1.0
	var gap_half: float = 5.0  # Gap width for passable exits
	var section_length: float = distance - gap_half

	# Check each direction and only create walls for blocked edges
	# For passable edges, create wall sections with a gap in the center

	# North wall - check if north is passable
	var north_passable: bool = WorldData.is_passable(GRID_COORDS + Vector2i(0, -1))
	if north_passable:
		# Create two sections with gap in center
		_create_wall_section("NorthWestBorder", Vector3(-distance + section_length / 2.0, wall_height / 2.0, -distance),
			Vector3(section_length, wall_height, wall_thickness))
		_create_wall_section("NorthEastBorder", Vector3(distance - section_length / 2.0, wall_height / 2.0, -distance),
			Vector3(section_length, wall_height, wall_thickness))
	else:
		_create_wall_section("NorthBorder", Vector3(0, wall_height / 2.0, -distance),
			Vector3(distance * 2, wall_height, wall_thickness))

	# South wall - check if south is passable
	var south_passable: bool = WorldData.is_passable(GRID_COORDS + Vector2i(0, 1))
	if south_passable:
		_create_wall_section("SouthWestBorder", Vector3(-distance + section_length / 2.0, wall_height / 2.0, distance),
			Vector3(section_length, wall_height, wall_thickness))
		_create_wall_section("SouthEastBorder", Vector3(distance - section_length / 2.0, wall_height / 2.0, distance),
			Vector3(section_length, wall_height, wall_thickness))
	else:
		_create_wall_section("SouthBorder", Vector3(0, wall_height / 2.0, distance),
			Vector3(distance * 2, wall_height, wall_thickness))

	# East wall - check if east is passable
	var east_passable: bool = WorldData.is_passable(GRID_COORDS + Vector2i(1, 0))
	if east_passable:
		_create_wall_section("EastNorthBorder", Vector3(distance, wall_height / 2.0, -distance + section_length / 2.0),
			Vector3(wall_thickness, wall_height, section_length))
		_create_wall_section("EastSouthBorder", Vector3(distance, wall_height / 2.0, distance - section_length / 2.0),
			Vector3(wall_thickness, wall_height, section_length))
	else:
		_create_wall_section("EastBorder", Vector3(distance, wall_height / 2.0, 0),
			Vector3(wall_thickness, wall_height, distance * 2))

	# West wall - check if west is passable
	var west_passable: bool = WorldData.is_passable(GRID_COORDS + Vector2i(-1, 0))
	if west_passable:
		_create_wall_section("WestNorthBorder", Vector3(-distance, wall_height / 2.0, -distance + section_length / 2.0),
			Vector3(wall_thickness, wall_height, section_length))
		_create_wall_section("WestSouthBorder", Vector3(-distance, wall_height / 2.0, distance - section_length / 2.0),
			Vector3(wall_thickness, wall_height, section_length))
	else:
		_create_wall_section("WestBorder", Vector3(-distance, wall_height / 2.0, 0),
			Vector3(wall_thickness, wall_height, distance * 2))


## Helper to create an invisible wall section
func _create_wall_section(wall_name: String, position: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.name = wall_name
	wall.collision_layer = 1
	wall.collision_mask = 0
	add_child(wall)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = position
	wall.add_child(col)


## Spawn enemy spawners at marker positions in the wilderness
func _spawn_enemy_spawners() -> void:
	var spawners_container := get_node_or_null("EnemySpawners")
	if not spawners_container:
		return

	for marker in spawners_container.get_children():
		var spawner := EnemySpawner.new()
		spawner.position = marker.global_position

		# Configure based on marker name
		if "Goblin" in marker.name:
			spawner.spawner_id = "goblin_totem_%s" % marker.name.to_lower()
			spawner.display_name = "Goblin Totem"
			spawner.max_hp = 500  # Starter level - easier to destroy
			spawner.armor_value = 5
			spawner.spawn_interval_min = 30.0
			spawner.spawn_interval_max = 45.0
			spawner.max_spawned_enemies = 6
			spawner.spawn_count_min = 1
			spawner.spawn_count_max = 2
			spawner.enemy_data_path = "res://data/enemies/goblin_soldier.tres"
			spawner.secondary_enemy_enabled = true
			spawner.secondary_enemy_chance = 0.3
			spawner.secondary_data_path = "res://data/enemies/goblin_archer.tres"
			spawner.secondary_sprite_path = "res://assets/sprites/enemies/goblin_archer.png"
		elif "Wolf" in marker.name:
			spawner.spawner_id = "wolf_den_%s" % marker.name.to_lower()
			spawner.display_name = "Wolf Den"
			spawner.max_hp = 300
			spawner.armor_value = 3
			spawner.spawn_interval_min = 40.0
			spawner.spawn_interval_max = 60.0
			spawner.max_spawned_enemies = 4
			spawner.spawn_count_min = 1
			spawner.spawn_count_max = 2
			spawner.enemy_data_path = "res://data/enemies/wolf.tres"
			spawner.secondary_enemy_enabled = false

		add_child(spawner)
		print("[Elder Moor] Spawned enemy spawner: %s at %s" % [spawner.display_name, marker.global_position])

	# Remove the marker container since we no longer need it
	spawners_container.queue_free()


## Spawn harvestable herb plants at marker positions
func _spawn_harvestable_herbs() -> void:
	var herbs_container := get_node_or_null("HarvestableHerbs")
	if not herbs_container:
		return

	for marker in herbs_container.get_children():
		var herb := HarvestablePlant.spawn_plant(
			self,
			marker.global_position,
			"red_herb",
			"Red Herb",
			1
		)
		print("[Elder Moor] Spawned herb at %s" % marker.global_position)

	# Remove the marker container
	herbs_container.queue_free()
