## larton.gd - Haunted Port Town of Larton
## Once a thriving coastal trading port, now overrun by ghost pirates and evil spirits
## HOSTILE ZONE - No friendly NPCs, no fast travel shrine until cleared
## Located west of Aberdeen - player enters from the east
##
## CONVERTED: All geometry pre-placed in larton.tscn
## This script handles: spawn point metadata, navigation, enemy spawning, chest spawning, borders
extends Node3D

const ZONE_ID := "town_larton_hostile"
const ZONE_SIZE := 85.0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Larton (Haunted)")
	_setup_spawn_point_metadata()
	_setup_navigation()
	_spawn_ghost_pirate_enemies()
	_spawn_chests()
	_setup_eerie_light_flickering()
	_create_invisible_border_walls()
	print("[Larton] Haunted port town loaded - HOSTILE ZONE")


## Setup spawn point metadata from Marker3D nodes
func _setup_spawn_point_metadata() -> void:
	var spawn_points: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points:
		push_warning("[Larton] SpawnPoints node not found")
		return

	for child in spawn_points.get_children():
		if child is Marker3D:
			child.add_to_group("spawn_points")
			var spawn_id: String = child.name.replace("SpawnPoint_", "")
			child.set_meta("spawn_id", spawn_id)


## Setup navigation mesh
func _setup_navigation() -> void:
	if not nav_region:
		nav_region = NavigationRegion3D.new()
		nav_region.name = "NavigationRegion3D"
		add_child(nav_region)

	var nav_mesh: NavigationMesh = NavigationMesh.new()
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
		print("[Larton] Navigation mesh baked")


## Spawn ghost pirate enemies from EnemySpawnPoints markers
func _spawn_ghost_pirate_enemies() -> void:
	var enemy_spawn_points: Node3D = get_node_or_null("EnemySpawnPoints")
	if not enemy_spawn_points:
		push_warning("[Larton] EnemySpawnPoints node not found")
		return

	var enemies_container: Node3D = get_node_or_null("Enemies")
	if not enemies_container:
		enemies_container = Node3D.new()
		enemies_container.name = "Enemies"
		add_child(enemies_container)

	var skeleton_texture: Texture2D = load("res://Sprite folders grab bag/skeleton_warrior.png")
	var drowned_texture: Texture2D = load("res://Sprite folders grab bag/swampy_undead.png")

	var enemy_count: int = 0
	for child in enemy_spawn_points.get_children():
		if child is Marker3D:
			var enemy_data_path: String
			var texture: Texture2D
			var h_frames: int
			var v_frames: int

			if child.name.begins_with("Skeleton_"):
				enemy_data_path = "res://data/enemies/skeleton_warrior.tres"
				texture = skeleton_texture
				h_frames = 4
				v_frames = 4
			elif child.name.begins_with("Drowned_"):
				enemy_data_path = "res://data/enemies/drowned_dead.tres"
				texture = drowned_texture
				h_frames = 4
				v_frames = 1
			else:
				continue

			if texture:
				var enemy: EnemyBase = EnemyBase.spawn_billboard_enemy(
					enemies_container,
					child.global_position,
					enemy_data_path,
					texture,
					h_frames,
					v_frames
				)

				if enemy:
					enemy.name = "GhostPirate_%d" % enemy_count
					enemy.behavior_mode = EnemyBase.BehaviorMode.WANDER
					enemy.wander_radius = 8.0
					enemy.leash_radius = 25.0
					enemy_count += 1

	print("[Larton] Spawned %d ghost pirate enemies" % enemy_count)


## Spawn chests from ChestPositions markers
func _spawn_chests() -> void:
	var chest_positions: Node3D = get_node_or_null("ChestPositions")
	if not chest_positions:
		push_warning("[Larton] ChestPositions node not found")
		return

	var interactables: Node3D = get_node_or_null("Interactables")
	if not interactables:
		interactables = Node3D.new()
		interactables.name = "Interactables"
		add_child(interactables)

	for marker in chest_positions.get_children():
		if marker is Marker3D:
			var chest_name: String = marker.get_meta("chest_name", "Chest")
			var is_locked: bool = marker.get_meta("is_locked", false)
			var lock_difficulty: int = marker.get_meta("lock_difficulty", 10)
			var persistent_id: String = marker.get_meta("persistent_id", "")

			Chest.spawn_chest(
				interactables,
				marker.global_position,
				chest_name,
				is_locked,
				lock_difficulty,
				true,  # randomize_loot
				persistent_id
			)

	print("[Larton] Spawned chests")


## Setup eerie light flickering for ghost ship lights
func _setup_eerie_light_flickering() -> void:
	# Ghost ship lights
	var ghost_ships: Node3D = get_node_or_null("GhostShips")
	if ghost_ships:
		for ship in ghost_ships.get_children():
			for child in ship.get_children():
				if child is OmniLight3D:
					_start_ghost_light_flicker(child)

	# Eerie ambient lights
	var eerie_lights: Node3D = get_node_or_null("Decorations/EerieLights")
	if eerie_lights:
		for light in eerie_lights.get_children():
			if light is OmniLight3D:
				_start_eerie_light_pulse(light)

	# Building interior lights
	var buildings: Node3D = get_node_or_null("Buildings")
	if buildings:
		for building in buildings.get_children():
			for child in building.get_children():
				if child is OmniLight3D:
					_start_eerie_light_pulse(child)


func _start_ghost_light_flicker(light: OmniLight3D) -> void:
	var base_energy: float = light.light_energy
	var tween: Tween = create_tween()
	tween.set_loops()

	# Ghostly pulsing effect
	tween.tween_property(light, "light_energy", base_energy * 1.3, randf_range(1.5, 2.5))
	tween.tween_property(light, "light_energy", base_energy * 0.7, randf_range(1.5, 2.5))
	tween.tween_property(light, "light_energy", base_energy * 1.1, randf_range(0.8, 1.5))
	tween.tween_property(light, "light_energy", base_energy * 0.9, randf_range(0.8, 1.5))


func _start_eerie_light_pulse(light: OmniLight3D) -> void:
	var base_energy: float = light.light_energy
	var tween: Tween = create_tween()
	tween.set_loops()

	# Slower, subtler pulse for eerie atmosphere
	tween.tween_property(light, "light_energy", base_energy * 1.15, randf_range(2.0, 4.0))
	tween.tween_property(light, "light_energy", base_energy * 0.85, randf_range(2.0, 4.0))


## Create invisible border walls
func _create_invisible_border_walls() -> void:
	var half_size: float = ZONE_SIZE / 2.0
	var wall_height: float = 8.0
	var wall_thickness: float = 1.0
	var exit_gap: float = 8.0

	# North wall (full)
	_create_border_wall("NorthBorder", Vector3(0, wall_height / 2, -half_size + 15), Vector3(ZONE_SIZE, wall_height, wall_thickness))

	# South wall (water side)
	_create_border_wall("SouthBorder", Vector3(0, wall_height / 2, half_size), Vector3(ZONE_SIZE, wall_height, wall_thickness))

	# West wall (full)
	_create_border_wall("WestBorder", Vector3(-half_size, wall_height / 2, 10), Vector3(wall_thickness, wall_height, ZONE_SIZE - 30))

	# East wall sections (with gap for Aberdeen road)
	var east_section_len: float = (ZONE_SIZE - exit_gap - 30) / 2.0
	_create_border_wall("EastNorthBorder", Vector3(half_size, wall_height / 2, -half_size / 2 + 15), Vector3(wall_thickness, wall_height, east_section_len))
	_create_border_wall("EastSouthBorder", Vector3(half_size, wall_height / 2, half_size - east_section_len / 2), Vector3(wall_thickness, wall_height, east_section_len))


func _create_border_wall(wall_name: String, position: Vector3, size: Vector3) -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.name = wall_name
	wall.collision_layer = 1
	wall.collision_mask = 0
	add_child(wall)

	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = position
	wall.add_child(col)


## Get spawn point for scene transitions
func get_spawn_point(spawn_id: String) -> Node3D:
	var spawn_points: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points:
		return null

	for child in spawn_points.get_children():
		if child.name == spawn_id or child.name == "SpawnPoint_" + spawn_id:
			return child
		if child.get_meta("spawn_id", "") == spawn_id:
			return child

	return spawn_points.get_node_or_null("SpawnPoint_default")
