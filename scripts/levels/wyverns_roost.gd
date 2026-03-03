## wyverns_roost.gd - Wyvern's Roost (Rocky Outcropping Landmark)
## A rocky highland where wyverns nest. Dangerous landmark with flying enemies.
## Location: Grid (2, 5) relative to Elder Moor = East + South
extends Node3D

const ZONE_ID := "wyverns_roost"
const ZONE_SIZE := 100.0

## Materials
var rock_mat: StandardMaterial3D
var grass_mat: StandardMaterial3D
var dirt_mat: StandardMaterial3D

## Navigation
var nav_region: NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Wyvern's Roost")

	_create_materials()
	_setup_navigation()
	_create_rocky_terrain()
	_create_rock_formations()
	_spawn_spawn_points()
	_spawn_exit_door()
	_spawn_wyverns()
	_spawn_loot()
	_create_lighting()

	# Quest trigger for reaching the roost
	QuestManager.on_location_reached("wyverns_roost")

	print("[WyvernsRoost] Rocky outcropping initialized!")


func _create_materials() -> void:
	# Highland rock - gray/brown
	rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.45, 0.42, 0.38)
	rock_mat.roughness = 0.95

	# Sparse highland grass
	grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.35, 0.42, 0.28)
	grass_mat.roughness = 0.9

	# Rocky dirt
	dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.38, 0.32, 0.26)
	dirt_mat.roughness = 0.95


func _setup_navigation() -> void:
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
		print("[WyvernsRoost] Navigation mesh baked!")


## ============================================================================
## ROCKY TERRAIN - Highland rocky ground
## ============================================================================

func _create_rocky_terrain() -> void:
	# Main ground (100x100 area)
	var ground := CSGBox3D.new()
	ground.name = "HighlandGround"
	ground.size = Vector3(100, 1, 100)
	ground.position = Vector3(0, -0.5, 0)
	ground.material = grass_mat
	ground.use_collision = true
	add_child(ground)

	# Rocky patches scattered across the area
	for i in range(12):
		var patch_pos := Vector3(
			randf_range(-40, 40),
			0.01,
			randf_range(-40, 40)
		)
		var patch := CSGBox3D.new()
		patch.name = "RockPatch_%d" % i
		patch.size = Vector3(randf_range(5, 15), 0.02, randf_range(5, 15))
		patch.position = patch_pos
		patch.material = dirt_mat
		patch.use_collision = false
		add_child(patch)

	print("[WyvernsRoost] Rocky terrain created")


## ============================================================================
## ROCK FORMATIONS - The "Roost" where wyverns nest
## ============================================================================

func _create_rock_formations() -> void:
	# Central rocky spire (the main roost)
	var main_roost := Node3D.new()
	main_roost.name = "MainRoost"
	main_roost.position = Vector3(0, 0, -15)
	add_child(main_roost)

	# Large central rock tower
	var tower := CSGCylinder3D.new()
	tower.name = "RockTower"
	tower.radius = 5.0
	tower.height = 12.0
	tower.sides = 8
	tower.position = Vector3(0, 6, 0)
	tower.material = rock_mat
	tower.use_collision = true
	main_roost.add_child(tower)

	# Top platform (irregular rock)
	var top := CSGSphere3D.new()
	top.name = "RoostTop"
	top.radius = 7.0
	top.position = Vector3(0, 11, 0)
	top.scale = Vector3(1.2, 0.4, 1.2)
	top.material = rock_mat
	top.use_collision = true
	main_roost.add_child(top)

	# Side rock formations
	_create_rock_cluster(Vector3(-20, 0, -25), 1.5)
	_create_rock_cluster(Vector3(18, 0, -22), 1.2)
	_create_rock_cluster(Vector3(-25, 0, 5), 1.0)
	_create_rock_cluster(Vector3(22, 0, 10), 1.3)

	# Scattered boulders
	for i in range(20):
		var pos := Vector3(
			randf_range(-45, 45),
			0,
			randf_range(-45, 45)
		)
		# Avoid center roost area
		if pos.distance_to(Vector3(0, 0, -15)) > 15:
			_create_boulder(pos, randf_range(0.5, 2.0))

	print("[WyvernsRoost] Rock formations created")


func _create_rock_cluster(pos: Vector3, size_mult: float) -> void:
	var cluster := Node3D.new()
	cluster.name = "RockCluster"
	cluster.position = pos
	add_child(cluster)

	# 3-5 rocks in a cluster
	for i in range(randi_range(3, 5)):
		var rock := CSGSphere3D.new()
		rock.name = "ClusterRock_%d" % i
		rock.radius = 1.5 * size_mult * randf_range(0.6, 1.2)
		rock.position = Vector3(
			randf_range(-3, 3) * size_mult,
			rock.radius * 0.5,
			randf_range(-3, 3) * size_mult
		)
		rock.scale = Vector3(
			randf_range(0.7, 1.3),
			randf_range(0.4, 0.8),
			randf_range(0.7, 1.3)
		)
		rock.material = rock_mat
		rock.use_collision = true
		cluster.add_child(rock)


func _create_boulder(pos: Vector3, size: float) -> void:
	var boulder := CSGSphere3D.new()
	boulder.name = "Boulder"
	boulder.radius = size
	boulder.position = Vector3(pos.x, size * 0.5, pos.z)
	boulder.scale = Vector3(
		randf_range(0.7, 1.4),
		randf_range(0.5, 0.9),
		randf_range(0.7, 1.4)
	)
	boulder.material = rock_mat
	boulder.use_collision = true
	add_child(boulder)


## ============================================================================
## SPAWN POINTS
## ============================================================================

func _spawn_spawn_points() -> void:
	# Default spawn at south edge
	var default_spawn := Node3D.new()
	default_spawn.name = "default_spawn"
	default_spawn.position = Vector3(0, 1.0, 45)
	default_spawn.add_to_group("spawn_points")
	default_spawn.set_meta("spawn_id", "default")
	add_child(default_spawn)

	# From wilderness
	var from_wilderness := Node3D.new()
	from_wilderness.name = "from_wilderness"
	from_wilderness.position = Vector3(0, 1.0, 45)
	from_wilderness.add_to_group("spawn_points")
	from_wilderness.set_meta("spawn_id", "from_wilderness")
	add_child(from_wilderness)

	print("[WyvernsRoost] Spawn points created")


func _spawn_exit_door() -> void:
	# Exit at south edge (back to wilderness)
	var portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, 0, 48),
		SceneManager.RETURN_TO_WILDERNESS,
		"from_wyverns_roost",
		"Exit to Highlands"
	)
	portal.rotation.y = PI
	portal.show_frame = false
	print("[WyvernsRoost] Spawned exit portal")


## ============================================================================
## WYVERN SPAWNS
## ============================================================================

func _spawn_wyverns() -> void:
	# Spawn wyverns around the roost
	_spawn_wyvern(Vector3(-15, 0, -10))
	_spawn_wyvern(Vector3(12, 0, -18))
	_spawn_wyvern(Vector3(-8, 0, 5))
	_spawn_wyvern(Vector3(20, 0, -5))
	_spawn_wyvern(Vector3(0, 0, -25))

	print("[WyvernsRoost] Spawned wyvern pack")


func _spawn_wyvern(pos: Vector3) -> void:
	# Try to load wyvern data, fall back to wolf if not available
	var data_path := "res://data/enemies/wyvern.tres"
	if not ResourceLoader.exists(data_path):
		data_path = "res://data/enemies/wolf.tres"
		push_warning("[WyvernsRoost] Wyvern enemy data not found, using wolf as fallback")

	# Try to load wyvern sprite, fall back to wolf if not available
	var sprite: Texture2D = load("res://assets/sprites/enemies/wyvern.png")
	if not sprite:
		sprite = load("res://assets/sprites/enemies/wolf.png")
	if not sprite:
		sprite = load("res://assets/sprites/enemies/skeleton_shade.png")
	if not sprite:
		push_warning("[WyvernsRoost] Missing wyvern sprite")
		return

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		data_path,
		sprite,
		3, 1  # h_frames, v_frames
	)
	if enemy:
		enemy.add_to_group("wyvern")
		enemy.add_to_group("flying_enemy")
		print("[WyvernsRoost] Spawned wyvern at %s" % pos)


## ============================================================================
## LOOT
## ============================================================================

func _spawn_loot() -> void:
	# Hidden nest loot near the main roost
	var nest_loot := Chest.spawn_chest(
		self,
		Vector3(8, 0, -20),
		"Wyvern Nest Cache",
		false, 0,
		false, "wyvern_nest_cache"
	)
	if nest_loot:
		nest_loot.setup_with_loot(LootTables.LootTier.RARE)

	print("[WyvernsRoost] Spawned loot")


## ============================================================================
## LIGHTING
## ============================================================================

func _create_lighting() -> void:
	# Harsh highland sun
	var sun := DirectionalLight3D.new()
	sun.name = "HighlandSun"
	sun.light_color = Color(0.95, 0.92, 0.85)
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	# Ambient highland light
	var ambient := OmniLight3D.new()
	ambient.name = "AmbientLight"
	ambient.light_color = Color(0.6, 0.62, 0.7)
	ambient.light_energy = 0.4
	ambient.omni_range = 60.0
	ambient.position = Vector3(0, 15, 0)
	add_child(ambient)

	print("[WyvernsRoost] Created lighting")
