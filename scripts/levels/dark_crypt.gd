## dark_crypt.gd - Two-story dungeon with undead enemies
## Contains: Skeletons, Soul Shades, Vampire Lord boss, coffins
extends Node3D

const ZONE_ID := "dark_crypt"

var nav_region: NavigationRegion3D

## Floor heights
const FLOOR_1_Y := 0.0
const FLOOR_2_Y := -8.0  # Underground second floor

func _ready() -> void:
	_setup_navigation()
	_create_floor_1()
	_create_floor_2()
	_spawn_portals()
	_spawn_enemies()
	_spawn_loot()


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
	call_deferred("_bake_navigation")


func _bake_navigation() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()
		print("[DarkCrypt] Navigation mesh baked!")


## Create first floor (entry level)
func _create_floor_1() -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.2, 0.18, 0.22)  # Dark purple-gray
	stone_mat.roughness = 0.95

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.15, 0.13, 0.17)
	floor_mat.roughness = 0.9

	# Main entry hall (30x40)
	var floor1 := CSGBox3D.new()
	floor1.name = "Floor1_Ground"
	floor1.size = Vector3(30, 1, 40)
	floor1.position = Vector3(0, FLOOR_1_Y - 0.5, 0)
	floor1.material = floor_mat
	floor1.use_collision = true
	add_child(floor1)

	# Walls
	_create_wall(Vector3(-15.5, FLOOR_1_Y + 2, 0), Vector3(1, 5, 40), stone_mat)  # West
	_create_wall(Vector3(15.5, FLOOR_1_Y + 2, 0), Vector3(1, 5, 40), stone_mat)   # East
	_create_wall(Vector3(0, FLOOR_1_Y + 2, 20.5), Vector3(30, 5, 1), stone_mat)   # South (entry)
	_create_wall(Vector3(-8, FLOOR_1_Y + 2, -20.5), Vector3(14, 5, 1), stone_mat) # North-left
	_create_wall(Vector3(8, FLOOR_1_Y + 2, -20.5), Vector3(14, 5, 1), stone_mat)  # North-right

	# Ceiling
	var ceiling1 := CSGBox3D.new()
	ceiling1.name = "Floor1_Ceiling"
	ceiling1.size = Vector3(30, 0.5, 40)
	ceiling1.position = Vector3(0, FLOOR_1_Y + 5, 0)
	ceiling1.material = stone_mat
	ceiling1.use_collision = true
	add_child(ceiling1)

	# Coffins along the walls (decorative, some with spawners)
	_create_coffin(Vector3(-12, FLOOR_1_Y, -10))
	_create_coffin(Vector3(-12, FLOOR_1_Y, 0))
	_create_coffin(Vector3(-12, FLOOR_1_Y, 10))
	_create_coffin(Vector3(12, FLOOR_1_Y, -10))
	_create_coffin(Vector3(12, FLOOR_1_Y, 0))
	_create_coffin(Vector3(12, FLOOR_1_Y, 10))

	# Stairs down to floor 2 (north center)
	_create_stairs(Vector3(0, FLOOR_1_Y, -18), Vector3(0, FLOOR_2_Y, -18))

	print("[DarkCrypt] Floor 1 created")


## Create second floor (deeper level with boss)
func _create_floor_2() -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.15, 0.12, 0.18)  # Even darker
	stone_mat.roughness = 0.95

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.1, 0.08, 0.12)
	floor_mat.roughness = 0.9

	# Boss chamber (40x50)
	var floor2 := CSGBox3D.new()
	floor2.name = "Floor2_Ground"
	floor2.size = Vector3(40, 1, 50)
	floor2.position = Vector3(0, FLOOR_2_Y - 0.5, -30)
	floor2.material = floor_mat
	floor2.use_collision = true
	add_child(floor2)

	# Walls
	_create_wall(Vector3(-20.5, FLOOR_2_Y + 3, -30), Vector3(1, 7, 50), stone_mat)  # West
	_create_wall(Vector3(20.5, FLOOR_2_Y + 3, -30), Vector3(1, 7, 50), stone_mat)   # East
	_create_wall(Vector3(0, FLOOR_2_Y + 3, -55.5), Vector3(40, 7, 1), stone_mat)    # North (back)
	_create_wall(Vector3(-12, FLOOR_2_Y + 3, -4.5), Vector3(16, 7, 1), stone_mat)   # South-left
	_create_wall(Vector3(12, FLOOR_2_Y + 3, -4.5), Vector3(16, 7, 1), stone_mat)    # South-right

	# Ceiling with higher clearance for boss
	var ceiling2 := CSGBox3D.new()
	ceiling2.name = "Floor2_Ceiling"
	ceiling2.size = Vector3(40, 0.5, 50)
	ceiling2.position = Vector3(0, FLOOR_2_Y + 7, -30)
	ceiling2.material = stone_mat
	ceiling2.use_collision = true
	add_child(ceiling2)

	# Boss throne/altar area at the back
	var altar := CSGBox3D.new()
	altar.name = "BossAltar"
	altar.size = Vector3(8, 2, 4)
	altar.position = Vector3(0, FLOOR_2_Y + 1, -50)
	altar.material = stone_mat
	altar.use_collision = true
	add_child(altar)

	# More coffins (boss summons from these?)
	_create_coffin(Vector3(-15, FLOOR_2_Y, -20))
	_create_coffin(Vector3(-15, FLOOR_2_Y, -35))
	_create_coffin(Vector3(-15, FLOOR_2_Y, -45))
	_create_coffin(Vector3(15, FLOOR_2_Y, -20))
	_create_coffin(Vector3(15, FLOOR_2_Y, -35))
	_create_coffin(Vector3(15, FLOOR_2_Y, -45))

	print("[DarkCrypt] Floor 2 (boss chamber) created")


## Helper to create a wall segment
func _create_wall(pos: Vector3, size: Vector3, mat: Material) -> void:
	var wall := CSGBox3D.new()
	wall.name = "Wall"
	wall.size = size
	wall.position = pos
	wall.material = mat
	wall.use_collision = true
	add_child(wall)


## Create a coffin (decorative + potential spawn point)
func _create_coffin(pos: Vector3) -> void:
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.25, 0.18, 0.12)  # Dark wood
	wood_mat.roughness = 0.85

	var coffin := CSGBox3D.new()
	coffin.name = "Coffin"
	coffin.size = Vector3(1.2, 0.6, 2.5)
	coffin.position = pos + Vector3(0, 0.3, 0)
	coffin.material = wood_mat
	coffin.use_collision = true
	add_child(coffin)


## Create stairs between floors
func _create_stairs(start_pos: Vector3, end_pos: Vector3) -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.2, 0.18, 0.22)
	stone_mat.roughness = 0.9

	var steps := 16
	var step_height := (start_pos.y - end_pos.y) / steps
	var step_depth := 1.0

	for i in range(steps):
		var step := CSGBox3D.new()
		step.name = "Stair_%d" % i
		step.size = Vector3(4, step_height, step_depth)
		step.position = Vector3(
			start_pos.x,
			start_pos.y - (i + 0.5) * step_height,
			start_pos.z - (i + 0.5) * step_depth
		)
		step.material = stone_mat
		step.use_collision = true
		add_child(step)


## Spawn portal back to wilderness
func _spawn_portals() -> void:
	# Portal back to Wilderness
	var exit_portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, FLOOR_1_Y, 18),
		SceneManager.RETURN_TO_WILDERNESS,
		"from_crypt",
		"Exit to Wilderness"
	)
	exit_portal.rotation.y = PI

	# Spawn point for arriving from wilderness
	var from_world := Node3D.new()
	from_world.name = "from_wilderness"
	from_world.position = Vector3(0, FLOOR_1_Y + 0.1, 15)
	from_world.add_to_group("spawn_points")
	from_world.set_meta("spawn_id", "from_wilderness")
	add_child(from_world)

	print("[DarkCrypt] Spawned exit portal")


## Spawn undead enemies
func _spawn_enemies() -> void:
	# Floor 1: Soul Shades
	_spawn_billboard_enemy(
		Vector3(-8, FLOOR_1_Y, 5),
		"res://data/enemies/skeleton_shade.tres",
		"res://assets/sprites/enemies/skeleton_shade.png",
		"Soul Shade",
		4, 4  # 4 columns x 4 rows sprite sheet
	)
	_spawn_billboard_enemy(
		Vector3(8, FLOOR_1_Y, -5),
		"res://data/enemies/skeleton_shade.tres",
		"res://assets/sprites/enemies/skeleton_shade.png",
		"Soul Shade",
		4, 4
	)

	# Floor 2: More Soul Shades
	_spawn_billboard_enemy(
		Vector3(-10, FLOOR_2_Y, -25),
		"res://data/enemies/skeleton_shade.tres",
		"res://assets/sprites/enemies/skeleton_shade.png",
		"Soul Shade",
		4, 4
	)
	_spawn_billboard_enemy(
		Vector3(10, FLOOR_2_Y, -30),
		"res://data/enemies/skeleton_shade.tres",
		"res://assets/sprites/enemies/skeleton_shade.png",
		"Soul Shade",
		4, 4
	)

	# Floor 2: Vampire Lord (boss) - uses new 4x6 sprite sheet
	_spawn_billboard_enemy(
		Vector3(0, FLOOR_2_Y, -48),
		"res://data/enemies/vampire_lord.tres",
		"res://assets/sprites/enemies/vampire_lord.png",
		"Vampire Lord",
		4, 6  # New sprite sheet is 4 columns x 6 rows
	)

	print("[DarkCrypt] Spawned undead enemies")


## Helper to spawn a billboard enemy
func _spawn_billboard_enemy(pos: Vector3, data_path: String, sprite_path: String, display_name: String, h_frames: int = 4, v_frames: int = 4) -> void:
	var sprite_texture: Texture2D = load(sprite_path)
	if not sprite_texture:
		push_warning("[DarkCrypt] Failed to load sprite: %s" % sprite_path)
		return

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		data_path,
		sprite_texture,
		h_frames,
		v_frames
	)

	if enemy:
		# Apply undead glow (purple for shades, crimson for vampires)
		enemy.call_deferred("_check_and_apply_undead_glow", data_path)
		print("[DarkCrypt] Spawned %s at %s" % [display_name, pos])


## Spawn loot chests
func _spawn_loot() -> void:
	# Floor 1 chest
	var chest1 := Chest.spawn_chest(
		self,
		Vector3(10, FLOOR_1_Y, 15),
		"Dusty Tomb Chest",
		true,
		12,
		false,
		""
	)
	chest1.setup_with_loot(LootTables.LootTier.UNCOMMON)

	# Floor 2 chest near boss
	var chest2 := Chest.spawn_chest(
		self,
		Vector3(-5, FLOOR_2_Y, -45),
		"Ancient Sarcophagus",
		true,
		15,
		false,
		""
	)
	chest2.setup_with_loot(LootTables.LootTier.RARE)

	print("[DarkCrypt] Spawned loot chests")
