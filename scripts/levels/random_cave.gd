## random_cave.gd - Procedurally generated cave dungeon (placeholder)
## TODO: Implement proper procedural generation
extends Node3D

const ZONE_ID := "random_cave"

var nav_region: NavigationRegion3D
var cave_seed: int = 0

func _ready() -> void:
	_initialize_seed()
	_setup_navigation()
	_create_placeholder_cave()
	_spawn_portal()
	_spawn_enemies()
	_spawn_loot()
	print("[RandomCave] Generated cave dungeon with seed: %d" % cave_seed)


## Initialize the random seed for consistent dungeon generation
func _initialize_seed() -> void:
	var saved_seed := SaveManager.get_dungeon_seed(ZONE_ID)
	if saved_seed >= 0:
		# Use existing seed for persistence
		cave_seed = saved_seed
	else:
		# Generate new seed and save it
		cave_seed = randi()
		SaveManager.set_dungeon_seed(ZONE_ID, cave_seed)

	# Apply the seed for all subsequent random calls
	seed(cave_seed)


func _setup_navigation() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	add_child(nav_region)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.cell_size = 0.4
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
		print("[RandomCave] Navigation mesh baked!")


## Create placeholder cave layout (will be replaced with procedural generation)
func _create_placeholder_cave() -> void:
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.3, 0.28, 0.25)
	rock_mat.roughness = 0.95

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.25, 0.22, 0.2)
	floor_mat.roughness = 0.9

	# Simple cave floor (will be replaced with room-based generation)
	var floor := CSGBox3D.new()
	floor.name = "CaveFloor"
	floor.size = Vector3(40, 1, 60)
	floor.position = Vector3(0, -0.5, -20)
	floor.material = floor_mat
	floor.use_collision = true
	add_child(floor)

	# Cave walls (rough)
	_create_cave_wall(Vector3(-20, 3, -20), Vector3(2, 8, 60), rock_mat)
	_create_cave_wall(Vector3(20, 3, -20), Vector3(2, 8, 60), rock_mat)
	_create_cave_wall(Vector3(0, 3, -51), Vector3(40, 8, 2), rock_mat)
	_create_cave_wall(Vector3(-12, 3, 11), Vector3(16, 8, 2), rock_mat)
	_create_cave_wall(Vector3(12, 3, 11), Vector3(16, 8, 2), rock_mat)

	# Ceiling
	var ceiling := CSGBox3D.new()
	ceiling.name = "CaveCeiling"
	ceiling.size = Vector3(40, 1, 60)
	ceiling.position = Vector3(0, 8, -20)
	ceiling.material = rock_mat
	ceiling.use_collision = true
	add_child(ceiling)

	# Some rocky obstacles
	_create_rock_cluster(Vector3(-10, 0, -15))
	_create_rock_cluster(Vector3(8, 0, -35))
	_create_rock_cluster(Vector3(-5, 0, -40))


## Create cave wall with some variation
func _create_cave_wall(pos: Vector3, size: Vector3, mat: Material) -> void:
	var wall := CSGBox3D.new()
	wall.name = "CaveWall"
	wall.size = size
	wall.position = pos
	wall.material = mat
	wall.use_collision = true
	add_child(wall)


## Create cluster of rocks
func _create_rock_cluster(pos: Vector3) -> void:
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.35, 0.32, 0.28)
	rock_mat.roughness = 0.9

	for i in range(3):
		var rock := CSGSphere3D.new()
		rock.name = "Rock_%d" % i
		rock.radius = randf_range(1.0, 2.0)
		rock.position = pos + Vector3(randf_range(-2, 2), rock.radius * 0.5, randf_range(-2, 2))
		rock.material = rock_mat
		rock.use_collision = true
		add_child(rock)


## Spawn exit portal
func _spawn_portal() -> void:
	var exit_portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, 0, 8),
		SceneManager.RETURN_TO_WILDERNESS,
		"from_random_cave",
		"Exit Cave"
	)
	exit_portal.show_frame = false
	exit_portal.rotation.y = PI

	var from_world := Node3D.new()
	from_world.name = "from_wilderness"
	from_world.position = Vector3(0, 0.1, 2)
	from_world.add_to_group("spawn_points")
	from_world.set_meta("spawn_id", "from_open_world")
	add_child(from_world)


## Spawn enemies (placeholder - random enemy types)
func _spawn_enemies() -> void:
	# Mix of enemies for testing
	_spawn_billboard_enemy(
		Vector3(-8, 0, -20),
		"res://data/enemies/goblin_soldier.tres",
		"",  # Uses default mesh enemy
		"Goblin Scout"
	)

	_spawn_billboard_enemy(
		Vector3(10, 0, -35),
		"res://data/enemies/abomination.tres",
		"res://assets/sprites/enemies/abomination.png",
		"Cave Abomination"
	)


## Helper to spawn enemy (billboard or mesh)
func _spawn_billboard_enemy(pos: Vector3, data_path: String, sprite_path: String, display_name: String) -> void:
	if sprite_path.is_empty():
		# Spawn mesh-based enemy
		var enemy_scene: PackedScene = load("res://scenes/enemies/enemy_base.tscn")
		if enemy_scene:
			var enemy: EnemyBase = enemy_scene.instantiate() as EnemyBase
			if enemy:
				enemy.enemy_data = load(data_path)
				add_child(enemy)
				enemy.global_position = pos
				# Apply undead/monster glow if applicable
				enemy.call_deferred("_check_and_apply_undead_glow", data_path)
				print("[RandomCave] Spawned %s at %s" % [display_name, pos])
		return

	var sprite_texture: Texture2D = load(sprite_path)
	if not sprite_texture:
		push_warning("[RandomCave] Failed to load sprite: %s" % sprite_path)
		return

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		data_path,
		sprite_texture,
		4, 4
	)

	if enemy:
		# Apply undead/monster glow if applicable
		enemy.call_deferred("_check_and_apply_undead_glow", data_path)
		print("[RandomCave] Spawned %s at %s" % [display_name, pos])


## Spawn loot
func _spawn_loot() -> void:
	var chest := Chest.spawn_chest(
		self,
		Vector3(0, 0, -45),
		"Cave Treasure",
		true,
		10,
		false,
		""
	)
	chest.setup_with_loot(LootTables.LootTier.UNCOMMON)
