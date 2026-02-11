## bandit_hideout_exterior.gd - Bandit Camp Overworld Area
## Forest clearing with bandit tents, campfires, and patrolling bandits
## Entry point to the 2-level Bandit Hideout dungeon
## Located north of Thornfield hamlet through the forest
##
## CONVERTED: Terrain, structures, and decorations are now pre-placed in .tscn
## This script only handles: environment setup, enemy spawning, interactables, doors, navigation
extends Node3D

const ZONE_ID := "bandit_hideout_exterior"
const ZONE_SIZE := 45.0  # 45x45 unit zone

var nav_region: NavigationRegion3D


func _ready() -> void:
	_setup_environment()
	_spawn_enemies_from_markers()
	_spawn_chests_from_markers()
	_spawn_doors_from_markers()
	_setup_navigation()
	_create_invisible_border_walls()
	DayNightCycle.add_to_level(self)
	print("[BanditHideoutExterior] Bandit camp loaded")


## Setup the dark forest environment
func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.25, 0.18)  # Dark forest
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.38, 0.28)  # Dim forest light
	env.ambient_light_energy = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.28, 0.2)
	env.fog_density = 0.018
	env.fog_sky_affect = 0.4

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	# Dim directional light (forest canopy blocks most light)
	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.light_color = Color(0.85, 0.82, 0.72)
	light.light_energy = 0.5
	light.rotation_degrees = Vector3(-40, 30, 0)
	light.shadow_enabled = true
	light.shadow_bias = 0.02
	add_child(light)


## Spawn enemies from Marker3D positions in EnemySpawns node
func _spawn_enemies_from_markers() -> void:
	var enemy_spawns := get_node_or_null("EnemySpawns")
	if not enemy_spawns:
		push_warning("[BanditHideoutExterior] EnemySpawns node not found")
		return

	var bandit_sprite: Texture2D = load("res://assets/sprites/enemies/human_bandit.png")
	var enemies_container := Node3D.new()
	enemies_container.name = "Enemies"
	add_child(enemies_container)

	for marker in enemy_spawns.get_children():
		if marker is Marker3D:
			var enemy_data_path: String = marker.get_meta("enemy_data", "res://data/enemies/human_bandit.tres")
			EnemyBase.spawn_billboard_enemy(
				enemies_container,
				marker.global_position,
				enemy_data_path,
				bandit_sprite,
				4, 3
			)

	print("[BanditHideoutExterior] Spawned enemies from %d markers" % enemy_spawns.get_child_count())


## Spawn chests from Marker3D positions in ChestPositions node
func _spawn_chests_from_markers() -> void:
	var chest_positions := get_node_or_null("ChestPositions")
	if not chest_positions:
		push_warning("[BanditHideoutExterior] ChestPositions node not found")
		return

	var interactables := Node3D.new()
	interactables.name = "Interactables"
	add_child(interactables)

	for marker in chest_positions.get_children():
		if marker is Marker3D:
			var chest_name: String = marker.get_meta("chest_name", "Chest")
			var is_locked: bool = marker.get_meta("is_locked", false)
			var lock_difficulty: int = marker.get_meta("lock_difficulty", 10)
			var randomize_loot: bool = marker.get_meta("randomize_loot", true)
			var persistent_id: String = marker.get_meta("persistent_id", "")

			Chest.spawn_chest(
				interactables,
				marker.global_position,
				chest_name,
				is_locked,
				lock_difficulty,
				randomize_loot,
				persistent_id
			)

	print("[BanditHideoutExterior] Spawned chests from markers")


## Spawn zone doors from Marker3D positions in DoorPositions node
func _spawn_doors_from_markers() -> void:
	var door_positions := get_node_or_null("DoorPositions")
	if not door_positions:
		push_warning("[BanditHideoutExterior] DoorPositions node not found")
		return

	var doors := Node3D.new()
	doors.name = "Doors"
	add_child(doors)

	for marker in door_positions.get_children():
		if marker is Marker3D:
			var target_scene: String = marker.get_meta("target_scene", "")
			var spawn_id: String = marker.get_meta("spawn_id", "default")
			var door_label: String = marker.get_meta("door_label", "Exit")
			var show_frame: bool = marker.get_meta("show_frame", true)

			# Handle special case for wilderness return
			if target_scene == "RETURN_TO_WILDERNESS":
				target_scene = SceneManager.RETURN_TO_WILDERNESS

			var door := ZoneDoor.spawn_door(
				doors,
				marker.global_position,
				target_scene,
				spawn_id,
				door_label
			)
			if door:
				door.rotation = marker.rotation
				door.show_frame = show_frame

	print("[BanditHideoutExterior] Spawned doors from markers")


## Setup navigation mesh (baked at runtime from pre-placed geometry)
func _setup_navigation() -> void:
	nav_region = get_node_or_null("NavigationRegion3D")
	if not nav_region:
		nav_region = NavigationRegion3D.new()
		nav_region.name = "NavigationRegion3D"
		add_child(nav_region)

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
		print("[BanditHideoutExterior] Navigation mesh baked!")


## Create invisible border walls to keep player in the zone
func _create_invisible_border_walls() -> void:
	var distance := ZONE_SIZE / 2.0
	var wall_height := 4.0
	var wall_thickness := 1.0

	# Full walls on east and west (no exits)
	_create_border_wall("EastBorder", Vector3(distance, wall_height / 2.0, 0), Vector3(wall_thickness, wall_height, distance * 2))
	_create_border_wall("WestBorder", Vector3(-distance, wall_height / 2.0, 0), Vector3(wall_thickness, wall_height, distance * 2))

	# North and south walls with gaps for exits
	var gap_half := 5.0
	var section_length := distance - gap_half

	# North wall sections (gap for cave entrance)
	_create_border_wall("NorthWestBorder", Vector3(-distance + section_length / 2.0, wall_height / 2.0, -distance), Vector3(section_length, wall_height, wall_thickness))
	_create_border_wall("NorthEastBorder", Vector3(distance - section_length / 2.0, wall_height / 2.0, -distance), Vector3(section_length, wall_height, wall_thickness))

	# South wall sections (gap for path to Thornfield)
	_create_border_wall("SouthWestBorder", Vector3(-distance + section_length / 2.0, wall_height / 2.0, distance), Vector3(section_length, wall_height, wall_thickness))
	_create_border_wall("SouthEastBorder", Vector3(distance - section_length / 2.0, wall_height / 2.0, distance), Vector3(section_length, wall_height, wall_thickness))


func _create_border_wall(wall_name: String, position: Vector3, size: Vector3) -> void:
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
