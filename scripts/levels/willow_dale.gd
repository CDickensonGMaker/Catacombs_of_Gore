## willow_dale.gd - Abandoned watchtower dungeon with undead
## Layout: Cemetery Exterior -> Tower Entry Hall -> Upper Floors (conceptual)
## Contains: Skeletons, Zombies, gravestones, ruined tower structure
extends Node3D

const ZONE_ID := "dungeon_willow_dale"

## Materials
var stone_floor_mat: StandardMaterial3D
var stone_wall_mat: StandardMaterial3D
var grass_mat: StandardMaterial3D
var dirt_mat: StandardMaterial3D
var gravestone_mat: StandardMaterial3D
var wood_mat: StandardMaterial3D

## Navigation
var nav_region: NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Willow Dale Watchtower")

	_create_materials()
	_setup_navigation()
	_create_exterior_cemetery()
	_create_tower_structure()
	_create_tower_interior()
	_spawn_spawn_points()
	_spawn_exit_portal()
	_spawn_undead()
	_spawn_loot()
	_create_lighting()

	# Quest trigger for entering willow dale
	QuestManager.on_location_reached("willow_dale_entrance")

	print("[WillowDale] Dungeon initialized!")


func _create_materials() -> void:
	# Stone floor - old weathered stone
	stone_floor_mat = StandardMaterial3D.new()
	stone_floor_mat.albedo_color = Color(0.22, 0.2, 0.18)
	stone_floor_mat.roughness = 0.95

	# Stone walls - slightly mossy gray
	stone_wall_mat = StandardMaterial3D.new()
	stone_wall_mat.albedo_color = Color(0.28, 0.3, 0.26)
	stone_wall_mat.roughness = 0.9

	# Grass - dead, yellowed
	grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.25, 0.28, 0.15)
	grass_mat.roughness = 0.95

	# Dirt - dark brown
	dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.18, 0.14, 0.1)
	dirt_mat.roughness = 0.98

	# Gravestones - weathered gray stone
	gravestone_mat = StandardMaterial3D.new()
	gravestone_mat.albedo_color = Color(0.35, 0.33, 0.32)
	gravestone_mat.roughness = 0.85

	# Rotting wood
	wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.2, 0.15, 0.1)
	wood_mat.roughness = 0.9


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
		print("[WillowDale] Navigation mesh baked!")


## ============================================================================
## LAYOUT OVERVIEW (top-down, north = -Z):
##
##                    [TOWER INTERIOR]
##                     Entry Hall
##                          |
##                   +------+------+
##                   |   TOWER     |
##                   |   BASE      |
##                   +------+------+
##                          |
##              [CEMETERY EXTERIOR]
##                   Gravestones
##                   scattered
##                          |
##                   [ENTRANCE]
##                     (south)
## ============================================================================


## EXTERIOR CEMETERY - Open area with graves before the tower
func _create_exterior_cemetery() -> void:
	# Large ground area (40x50)
	var ground := CSGBox3D.new()
	ground.name = "CemeteryGround"
	ground.size = Vector3(50, 1, 60)
	ground.position = Vector3(0, -0.5, 30)
	ground.material = grass_mat
	ground.use_collision = true
	add_child(ground)

	# Dirt path leading to tower
	var path := CSGBox3D.new()
	path.name = "DirtPath"
	path.size = Vector3(6, 0.05, 40)
	path.position = Vector3(0, 0.03, 25)
	path.material = dirt_mat
	path.use_collision = false
	add_child(path)

	# Gravestones scattered around
	_create_gravestones()

	# Ruined cemetery fence/wall fragments
	_create_cemetery_walls()

	print("[WillowDale] Cemetery exterior created")


func _create_gravestones() -> void:
	# Gravestone positions (scattered around cemetery)
	var positions := [
		# Left side
		Vector3(-12, 0, 45),
		Vector3(-15, 0, 38),
		Vector3(-10, 0, 32),
		Vector3(-18, 0, 28),
		Vector3(-8, 0, 22),
		# Right side
		Vector3(12, 0, 42),
		Vector3(16, 0, 35),
		Vector3(10, 0, 28),
		Vector3(14, 0, 20),
		Vector3(18, 0, 40),
		# Some tilted/fallen near tower
		Vector3(-6, 0, 15),
		Vector3(6, 0, 12),
	]

	for i in positions.size():
		_create_gravestone(positions[i], i)


func _create_gravestone(pos: Vector3, index: int) -> void:
	var stone := CSGBox3D.new()
	stone.name = "Gravestone_%d" % index
	stone.size = Vector3(0.8, 1.2 + randf_range(-0.3, 0.3), 0.2)
	stone.position = Vector3(pos.x, stone.size.y / 2.0, pos.z)
	stone.material = gravestone_mat
	stone.use_collision = true

	# Random slight rotation for variety
	stone.rotation.y = randf_range(-0.2, 0.2)
	# Some stones tilted as if falling
	if index > 8:
		stone.rotation.x = randf_range(0.1, 0.3)

	add_child(stone)

	# Dirt mound in front of some graves
	if index % 2 == 0:
		var mound := CSGBox3D.new()
		mound.name = "GraveMound_%d" % index
		mound.size = Vector3(1.0, 0.15, 1.8)
		mound.position = Vector3(pos.x, 0.08, pos.z + 1.0)
		mound.material = dirt_mat
		mound.use_collision = true
		add_child(mound)


func _create_cemetery_walls() -> void:
	# Ruined low stone walls around cemetery perimeter
	var wall_height := 1.5
	var wall_thickness := 0.5

	# South entrance gap (player spawn area)
	# West wall segment (broken)
	var west_wall := CSGBox3D.new()
	west_wall.name = "CemeteryWall_West"
	west_wall.size = Vector3(wall_thickness, wall_height, 35)
	west_wall.position = Vector3(-22, wall_height / 2.0, 32)
	west_wall.material = stone_wall_mat
	west_wall.use_collision = true
	add_child(west_wall)

	# East wall segment (broken)
	var east_wall := CSGBox3D.new()
	east_wall.name = "CemeteryWall_East"
	east_wall.size = Vector3(wall_thickness, wall_height, 35)
	east_wall.position = Vector3(22, wall_height / 2.0, 32)
	east_wall.material = stone_wall_mat
	east_wall.use_collision = true
	add_child(east_wall)

	# Broken wall fragments near entrance
	var frag1 := CSGBox3D.new()
	frag1.name = "WallFragment_1"
	frag1.size = Vector3(4, 0.8, wall_thickness)
	frag1.position = Vector3(-16, 0.4, 52)
	frag1.rotation.y = 0.1
	frag1.material = stone_wall_mat
	frag1.use_collision = true
	add_child(frag1)

	var frag2 := CSGBox3D.new()
	frag2.name = "WallFragment_2"
	frag2.size = Vector3(5, 0.6, wall_thickness)
	frag2.position = Vector3(14, 0.3, 53)
	frag2.rotation.y = -0.15
	frag2.material = stone_wall_mat
	frag2.use_collision = true
	add_child(frag2)


## TOWER STRUCTURE - Stone watchtower with ruined upper section
func _create_tower_structure() -> void:
	var tower_center := Vector3(0, 0, 0)
	var tower_radius := 10.0
	var wall_thickness := 1.5
	var tower_height := 12.0

	# Tower base (octagonal approximated with box walls)
	# Front wall with doorway
	_create_tower_wall_with_door(
		Vector3(0, tower_height / 2.0, tower_radius),
		Vector3(tower_radius * 1.6, tower_height, wall_thickness),
		"TowerFront"
	)

	# Back wall (solid)
	var back_wall := CSGBox3D.new()
	back_wall.name = "TowerBack"
	back_wall.size = Vector3(tower_radius * 1.6, tower_height, wall_thickness)
	back_wall.position = Vector3(0, tower_height / 2.0, -tower_radius)
	back_wall.material = stone_wall_mat
	back_wall.use_collision = true
	add_child(back_wall)

	# Left wall
	var left_wall := CSGBox3D.new()
	left_wall.name = "TowerLeft"
	left_wall.size = Vector3(wall_thickness, tower_height, tower_radius * 2.0)
	left_wall.position = Vector3(-tower_radius, tower_height / 2.0, 0)
	left_wall.material = stone_wall_mat
	left_wall.use_collision = true
	add_child(left_wall)

	# Right wall
	var right_wall := CSGBox3D.new()
	right_wall.name = "TowerRight"
	right_wall.size = Vector3(wall_thickness, tower_height, tower_radius * 2.0)
	right_wall.position = Vector3(tower_radius, tower_height / 2.0, 0)
	right_wall.material = stone_wall_mat
	right_wall.use_collision = true
	add_child(right_wall)

	# Ruined top section - broken crenellations
	_create_ruined_battlements(tower_center, tower_radius, tower_height)

	print("[WillowDale] Tower structure created")


func _create_tower_wall_with_door(pos: Vector3, size: Vector3, wall_name: String) -> void:
	var door_width := 4.0
	var door_height := 3.5
	var side_width := (size.x - door_width) / 2.0

	# Left segment
	var left := CSGBox3D.new()
	left.name = wall_name + "_Left"
	left.size = Vector3(side_width, size.y, size.z)
	left.position = Vector3(pos.x - size.x / 2.0 + side_width / 2.0, pos.y, pos.z)
	left.material = stone_wall_mat
	left.use_collision = true
	add_child(left)

	# Right segment
	var right := CSGBox3D.new()
	right.name = wall_name + "_Right"
	right.size = Vector3(side_width, size.y, size.z)
	right.position = Vector3(pos.x + size.x / 2.0 - side_width / 2.0, pos.y, pos.z)
	right.material = stone_wall_mat
	right.use_collision = true
	add_child(right)

	# Top segment above door
	var top := CSGBox3D.new()
	top.name = wall_name + "_Top"
	top.size = Vector3(door_width, size.y - door_height, size.z)
	top.position = Vector3(pos.x, pos.y + door_height / 2.0, pos.z)
	top.material = stone_wall_mat
	top.use_collision = true
	add_child(top)


func _create_ruined_battlements(center: Vector3, radius: float, height: float) -> void:
	# Broken stone blocks at top of tower
	var battlement_positions := [
		Vector3(-8, height, -8),
		Vector3(-4, height, -9),
		Vector3(6, height, -7),
		Vector3(-7, height, 6),
		Vector3(8, height, 4),
	]

	for i in battlement_positions.size():
		var block := CSGBox3D.new()
		block.name = "Battlement_%d" % i
		block.size = Vector3(
			randf_range(1.5, 2.5),
			randf_range(1.0, 2.0),
			randf_range(1.5, 2.5)
		)
		block.position = battlement_positions[i] + Vector3(0, block.size.y / 2.0, 0)
		block.rotation.y = randf_range(-0.3, 0.3)
		block.material = stone_wall_mat
		block.use_collision = true
		add_child(block)


## TOWER INTERIOR - Ground floor entry hall
func _create_tower_interior() -> void:
	# Interior floor
	var floor := CSGBox3D.new()
	floor.name = "TowerFloor"
	floor.size = Vector3(18, 0.5, 18)
	floor.position = Vector3(0, -0.25, 0)
	floor.material = stone_floor_mat
	floor.use_collision = true
	add_child(floor)

	# Ceiling (partial - ruined)
	var ceiling := CSGBox3D.new()
	ceiling.name = "TowerCeiling"
	ceiling.size = Vector3(16, 0.5, 10)
	ceiling.position = Vector3(-2, 5.5, -3)
	ceiling.material = stone_wall_mat
	ceiling.use_collision = true
	add_child(ceiling)

	# Collapsed stairs (decorative debris)
	_create_collapsed_stairs()

	# Pillars inside tower
	_create_pillar(Vector3(-5, 0, -4))
	_create_pillar(Vector3(5, 0, -4))

	# Debris piles
	_create_debris(Vector3(-6, 0, 2))
	_create_debris(Vector3(4, 0, -6))

	print("[WillowDale] Tower interior created")


func _create_collapsed_stairs() -> void:
	# Broken staircase fragments along one wall
	var stair_base := Vector3(-7, 0, -6)

	for i in range(4):
		var step := CSGBox3D.new()
		step.name = "BrokenStair_%d" % i
		step.size = Vector3(3, 0.4, 1.2)
		step.position = Vector3(
			stair_base.x,
			0.2 + i * 0.5,
			stair_base.z - i * 1.0
		)
		step.rotation.z = randf_range(-0.1, 0.1) if i > 1 else 0
		step.material = stone_floor_mat
		step.use_collision = true
		add_child(step)

	# Collapsed section
	var rubble := CSGBox3D.new()
	rubble.name = "StairRubble"
	rubble.size = Vector3(4, 1.5, 3)
	rubble.position = Vector3(-7, 0.75, -9)
	rubble.rotation.x = 0.2
	rubble.material = stone_wall_mat
	rubble.use_collision = true
	add_child(rubble)


func _create_pillar(pos: Vector3) -> void:
	var pillar := CSGCylinder3D.new()
	pillar.name = "Pillar"
	pillar.radius = 0.6
	pillar.height = 6.0
	pillar.position = Vector3(pos.x, 3.0, pos.z)
	pillar.material = stone_wall_mat
	pillar.use_collision = true
	add_child(pillar)


func _create_debris(pos: Vector3) -> void:
	# Small pile of rubble
	var debris := CSGBox3D.new()
	debris.name = "Debris"
	debris.size = Vector3(2.5, 0.6, 2.0)
	debris.position = Vector3(pos.x, 0.3, pos.z)
	debris.rotation.y = randf_range(0, TAU)
	debris.material = stone_wall_mat
	debris.use_collision = true
	add_child(debris)


## ============================================================================
## SPAWN POINTS
## ============================================================================

func _spawn_spawn_points() -> void:
	# Player spawn from open world - south end of cemetery
	var from_world := Node3D.new()
	from_world.name = "from_open_world"
	from_world.position = Vector3(0, 1.0, 55)
	from_world.add_to_group("spawn_points")
	from_world.set_meta("spawn_id", "from_open_world")
	add_child(from_world)

	# Default spawn
	var default_spawn := Node3D.new()
	default_spawn.name = "default_spawn"
	default_spawn.position = Vector3(0, 1.0, 55)
	default_spawn.add_to_group("spawn_points")
	default_spawn.set_meta("spawn_id", "default")
	add_child(default_spawn)

	print("[WillowDale] Spawn points created at: ", from_world.position)


func _spawn_exit_portal() -> void:
	# Portal at south end of cemetery (entrance)
	var portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, 0, 58),
		SceneManager.RETURN_TO_WILDERNESS,
		"from_willow_dale",
		"Exit to Wilderness"
	)
	portal.rotation.y = PI  # Face into the dungeon
	portal.show_frame = false  # No door frame for outdoor exit
	print("[WillowDale] Spawned exit portal")


## ============================================================================
## UNDEAD SPAWNS
## ============================================================================

func _spawn_undead() -> void:
	_spawn_cemetery_undead()
	_spawn_tower_undead()


## Cemetery area - risen dead from graves
func _spawn_cemetery_undead() -> void:
	# Zombies shambling near graves
	_spawn_zombie(Vector3(-10, 0, 35))
	_spawn_zombie(Vector3(12, 0, 40))
	_spawn_zombie(Vector3(-16, 0, 25))

	# Skeleton patrol on path
	_spawn_skeleton(Vector3(0, 0, 30))
	_spawn_skeleton(Vector3(-5, 0, 20))


## Tower interior - more dangerous undead
func _spawn_tower_undead() -> void:
	# Skeletons inside tower
	_spawn_skeleton(Vector3(-4, 0, 0))
	_spawn_skeleton(Vector3(5, 0, -3))
	_spawn_skeleton(Vector3(0, 0, -6))

	# Zombie near debris
	_spawn_zombie(Vector3(3, 0, 2))


## Helper: Spawn a skeleton enemy
func _spawn_skeleton(pos: Vector3) -> void:
	var sprite: Texture2D = load("res://assets/sprites/enemies/skeleton_warrior.png")
	if not sprite:
		# Fallback to skeleton shade if warrior not available
		sprite = load("res://assets/sprites/enemies/skeleton_shade.png")
	if not sprite:
		push_warning("[WillowDale] Missing skeleton sprite")
		return

	var data_path := "res://data/enemies/skeleton_warrior.tres"
	if not ResourceLoader.exists(data_path):
		data_path = "res://data/enemies/skeleton_shade.tres"

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		data_path,
		sprite,
		4, 4  # 4x4 sprite sheet
	)
	if enemy:
		enemy.add_to_group("willow_dale_undead")
		print("[WillowDale] Spawned skeleton at %s" % pos)


## Helper: Spawn a zombie enemy
func _spawn_zombie(pos: Vector3) -> void:
	var sprite: Texture2D = load("res://assets/sprites/enemies/zombie.png")
	if not sprite:
		# Fallback sprite
		sprite = load("res://assets/sprites/enemies/skeleton_shade.png")
	if not sprite:
		push_warning("[WillowDale] Missing zombie sprite")
		return

	var data_path := "res://data/enemies/zombie.tres"
	if not ResourceLoader.exists(data_path):
		data_path = "res://data/enemies/skeleton_shade.tres"

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		data_path,
		sprite,
		4, 4  # 4x4 sprite sheet
	)
	if enemy:
		enemy.add_to_group("willow_dale_undead")
		print("[WillowDale] Spawned zombie at %s" % pos)


## ============================================================================
## LOOT
## ============================================================================

func _spawn_loot() -> void:
	# Cemetery chest - hidden behind gravestones
	var cemetery_chest := Chest.spawn_chest(
		self,
		Vector3(-18, 0, 30),
		"Weathered Grave Offering",
		false, 0,
		false, ""
	)
	if cemetery_chest:
		cemetery_chest.setup_with_loot(LootTables.LootTier.COMMON)

	# Tower interior chest - better loot
	var tower_chest := Chest.spawn_chest(
		self,
		Vector3(6, 0, -7),
		"Watchman's Chest",
		true, 10,
		false, ""
	)
	if tower_chest:
		tower_chest.setup_with_loot(LootTables.LootTier.UNCOMMON)

	print("[WillowDale] Spawned loot chests")


## ============================================================================
## LIGHTING - Spooky atmosphere
## ============================================================================

func _create_lighting() -> void:
	# World environment set in scene, add local lights

	# Eerie moonlight for exterior (dim blue-white)
	var moon_light := DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.light_color = Color(0.6, 0.65, 0.8)
	moon_light.light_energy = 0.4
	moon_light.rotation_degrees = Vector3(-45, 30, 0)
	moon_light.shadow_enabled = true
	add_child(moon_light)

	# Cemetery ambient lights (ghostly green)
	_spawn_eerie_light(Vector3(-10, 2, 35), Color(0.3, 0.8, 0.4), 8.0, 0.6)
	_spawn_eerie_light(Vector3(12, 2, 38), Color(0.3, 0.8, 0.4), 8.0, 0.5)
	_spawn_eerie_light(Vector3(0, 2, 25), Color(0.4, 0.6, 0.8), 10.0, 0.4)

	# Tower interior - dim purple torchlight
	_spawn_eerie_light(Vector3(-5, 3, 0), Color(0.6, 0.4, 0.7), 8.0, 0.8)
	_spawn_eerie_light(Vector3(5, 3, -3), Color(0.6, 0.4, 0.7), 8.0, 0.8)

	# Tower entrance (slightly brighter)
	_spawn_eerie_light(Vector3(0, 3, 8), Color(0.5, 0.5, 0.6), 10.0, 0.6)

	print("[WillowDale] Created spooky lighting")


func _spawn_eerie_light(pos: Vector3, color: Color, range_val: float, energy: float) -> void:
	var light := OmniLight3D.new()
	light.name = "EerieLight"
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_val
	light.position = pos
	add_child(light)
