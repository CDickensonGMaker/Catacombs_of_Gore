## mosshall_tombs.gd - Mid-game dungeon (Level 5-8)
## Larger dungeon with overgrown ancient tombs
## Features multiple paths and more challenging encounters
extends Node3D

const ZONE_ID := "mosshall_tombs"
const ZONE_DISPLAY_NAME := "Mosshall Tombs"

## Floor heights
const FLOOR_1_Y := 0.0
const FLOOR_2_Y := -8.0  # Lower catacombs

## Materials
var stone_mat: StandardMaterial3D
var floor_mat: StandardMaterial3D
var moss_mat: StandardMaterial3D
var dark_stone_mat: StandardMaterial3D

## Navigation
var nav_region: NavigationRegion3D


func _ready() -> void:
	# Register zone with SaveManager
	SaveManager.set_current_zone(ZONE_ID, ZONE_DISPLAY_NAME)

	# Play ruins ambient and dungeon music (only when main scene)
	var is_main_scene: bool = get_node_or_null("Player") != null
	if is_main_scene:
		AudioManager.play_zone_ambiance("ruins")
		AudioManager.play_zone_music("dungeon")

	_create_materials()
	_setup_navigation()

	# Upper level (Floor 1)
	_create_entrance_hall()
	_create_west_corridor()
	_create_east_corridor()
	_create_west_tomb_chamber()
	_create_east_guard_hall()
	_create_central_hub()
	_create_shrine_alcove()

	# Lower level (Floor 2)
	_create_descent_stairs()
	_create_lower_antechamber()
	_create_crypt_corridor_west()
	_create_crypt_corridor_east()
	_create_ossuary()
	_create_boss_tomb()

	_spawn_portals()
	_spawn_enemies()
	_spawn_loot()

	print("[MosshallTombs] Dungeon initialized with %d rooms" % 13)


func _create_materials() -> void:
	# Base stone - green moss tint
	stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.12, 0.18, 0.1)
	stone_mat.roughness = 0.95

	floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.08, 0.12, 0.08)
	floor_mat.roughness = 0.9

	# Heavy moss coverage
	moss_mat = StandardMaterial3D.new()
	moss_mat.albedo_color = Color(0.08, 0.22, 0.08)
	moss_mat.roughness = 0.85

	# Darker stone for lower levels
	dark_stone_mat = StandardMaterial3D.new()
	dark_stone_mat.albedo_color = Color(0.06, 0.1, 0.06)
	dark_stone_mat.roughness = 0.95


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


## ===========================================================================
## UPPER LEVEL (FLOOR 1)
## ===========================================================================

## Entrance Hall (16x12, height 6) - Grand entry with pillars
func _create_entrance_hall() -> void:
	var pos := Vector3(0, FLOOR_1_Y, 0)
	_create_room_box(pos, Vector3(16, 6, 12), "EntranceHall", stone_mat, floor_mat)

	# Double row of pillars
	_create_pillar(pos + Vector3(-5, 0, -3))
	_create_pillar(pos + Vector3(-5, 0, 3))
	_create_pillar(pos + Vector3(5, 0, -3))
	_create_pillar(pos + Vector3(5, 0, 3))


## West Corridor (4x14, height 4)
func _create_west_corridor() -> void:
	var pos := Vector3(-14, FLOOR_1_Y, 0)
	_create_room_box(pos, Vector3(14, 4, 4), "WestCorridor", stone_mat, floor_mat)


## East Corridor (4x14, height 4)
func _create_east_corridor() -> void:
	var pos := Vector3(14, FLOOR_1_Y, 0)
	_create_room_box(pos, Vector3(14, 4, 4), "EastCorridor", stone_mat, floor_mat)


## West Tomb Chamber (12x12, height 5) - Contains sarcophagi
func _create_west_tomb_chamber() -> void:
	var pos := Vector3(-26, FLOOR_1_Y, 0)
	_create_room_box(pos, Vector3(12, 5, 12), "WestTombChamber", stone_mat, floor_mat)

	# Sarcophagi
	_create_coffin(pos + Vector3(-3, 0, -3))
	_create_coffin(pos + Vector3(3, 0, -3))
	_create_coffin(pos + Vector3(-3, 0, 3))
	_create_coffin(pos + Vector3(3, 0, 3))


## East Guard Hall (14x14, height 5) - Combat room with pillars
func _create_east_guard_hall() -> void:
	var pos := Vector3(26, FLOOR_1_Y, 0)
	_create_room_box(pos, Vector3(14, 5, 14), "EastGuardHall", stone_mat, floor_mat)

	# Corner pillars
	_create_pillar(pos + Vector3(-5, 0, -5))
	_create_pillar(pos + Vector3(5, 0, -5))
	_create_pillar(pos + Vector3(-5, 0, 5))
	_create_pillar(pos + Vector3(5, 0, 5))


## Central Hub (12x12, height 6) - North of entrance, leads down
func _create_central_hub() -> void:
	var pos := Vector3(0, FLOOR_1_Y, -15)
	_create_room_box(pos, Vector3(12, 6, 12), "CentralHub", stone_mat, floor_mat)

	# Central altar
	_create_altar(pos)


## Shrine Alcove (8x8, height 5) - Rest area off central hub
func _create_shrine_alcove() -> void:
	var pos := Vector3(-14, FLOOR_1_Y, -15)
	_create_room_box(pos, Vector3(8, 5, 8), "ShrineAlcove", moss_mat, floor_mat)

	# Altar
	_create_altar(pos + Vector3(0, 0, 2))

	# Rest spot
	RestSpot.spawn_rest_spot(self, pos + Vector3(0, 0.1, 0), "Overgrown Shrine")


## ===========================================================================
## LOWER LEVEL (FLOOR 2) - The Catacombs
## ===========================================================================

## Stairs down from Central Hub
func _create_descent_stairs() -> void:
	var corridor := Vector3(0, FLOOR_1_Y, -24)
	_create_room_box(corridor, Vector3(4, 4, 6), "DescentCorridor", stone_mat, floor_mat)

	# Stairs
	_create_stairs(Vector3(0, FLOOR_1_Y, -27), Vector3(0, FLOOR_2_Y, -39))


## Lower Antechamber (10x10, height 5) - Bottom of stairs
func _create_lower_antechamber() -> void:
	var pos := Vector3(0, FLOOR_2_Y, -44)
	_create_room_box(pos, Vector3(10, 5, 10), "LowerAntechamber", dark_stone_mat, dark_stone_mat)


## West Crypt Corridor (16x4, height 4)
func _create_crypt_corridor_west() -> void:
	var pos := Vector3(-12, FLOOR_2_Y, -44)
	_create_room_box(pos, Vector3(16, 4, 4), "CryptCorridorW", dark_stone_mat, dark_stone_mat)


## East Crypt Corridor (16x4, height 4)
func _create_crypt_corridor_east() -> void:
	var pos := Vector3(12, FLOOR_2_Y, -44)
	_create_room_box(pos, Vector3(16, 4, 4), "CryptCorridorE", dark_stone_mat, dark_stone_mat)


## Ossuary (10x10, height 5) - Bone storage room
func _create_ossuary() -> void:
	var pos := Vector3(-24, FLOOR_2_Y, -44)
	_create_room_box(pos, Vector3(10, 5, 10), "Ossuary", dark_stone_mat, dark_stone_mat)

	# Bone piles (represented by coffins for now)
	_create_coffin(pos + Vector3(-3, 0, 0))
	_create_coffin(pos + Vector3(3, 0, 0))
	_create_coffin(pos + Vector3(0, 0, 3))


## Boss Tomb (18x18, height 8) - Final chamber
func _create_boss_tomb() -> void:
	var pos := Vector3(0, FLOOR_2_Y, -62)
	_create_room_box(pos, Vector3(18, 8, 18), "BossTomb", dark_stone_mat, dark_stone_mat)

	# Boss throne/sarcophagus at far end
	var throne := CSGBox3D.new()
	throne.name = "BossThrone"
	throne.size = Vector3(6, 3, 3)
	throne.position = pos + Vector3(0, 1.5, 7)
	throne.material = moss_mat
	throne.use_collision = true
	add_child(throne)

	# Corner pillars
	_create_pillar(pos + Vector3(-7, 0, -7))
	_create_pillar(pos + Vector3(7, 0, -7))
	_create_pillar(pos + Vector3(-7, 0, 7))
	_create_pillar(pos + Vector3(7, 0, 7))

	# Additional center pillars
	_create_pillar(pos + Vector3(-4, 0, 0))
	_create_pillar(pos + Vector3(4, 0, 0))


## ===========================================================================
## GEOMETRY HELPERS
## ===========================================================================

func _create_room_box(center: Vector3, size: Vector3, room_name: String, wall_mat: Material, flr_mat: Material) -> void:
	var half := size / 2.0

	# Floor
	var floor_box := CSGBox3D.new()
	floor_box.name = room_name + "_Floor"
	floor_box.size = Vector3(size.x, 0.5, size.z)
	floor_box.position = center + Vector3(0, -0.25, 0)
	floor_box.material = flr_mat
	floor_box.use_collision = true
	add_child(floor_box)

	# Ceiling
	var ceiling := CSGBox3D.new()
	ceiling.name = room_name + "_Ceiling"
	ceiling.size = Vector3(size.x, 0.5, size.z)
	ceiling.position = center + Vector3(0, size.y, 0)
	ceiling.material = wall_mat
	ceiling.use_collision = true
	add_child(ceiling)

	# Walls
	_create_wall(center + Vector3(-half.x - 0.25, half.y, 0), Vector3(0.5, size.y, size.z), room_name + "_WallW", wall_mat)
	_create_wall(center + Vector3(half.x + 0.25, half.y, 0), Vector3(0.5, size.y, size.z), room_name + "_WallE", wall_mat)
	_create_wall(center + Vector3(0, half.y, -half.z - 0.25), Vector3(size.x, size.y, 0.5), room_name + "_WallN", wall_mat)
	_create_wall(center + Vector3(0, half.y, half.z + 0.25), Vector3(size.x, size.y, 0.5), room_name + "_WallS", wall_mat)


func _create_wall(pos: Vector3, size: Vector3, wall_name: String, mat: Material) -> void:
	var wall := CSGBox3D.new()
	wall.name = wall_name
	wall.size = size
	wall.position = pos
	wall.material = mat
	wall.use_collision = true
	add_child(wall)


func _create_pillar(pos: Vector3) -> void:
	var pillar := CSGBox3D.new()
	pillar.name = "Pillar"
	pillar.size = Vector3(1, 5.5, 1)
	pillar.position = pos + Vector3(0, 2.75, 0)
	pillar.material = moss_mat
	pillar.use_collision = true
	add_child(pillar)


func _create_coffin(pos: Vector3) -> void:
	var coffin := CSGBox3D.new()
	coffin.name = "Coffin"
	coffin.size = Vector3(1.2, 0.6, 2.5)
	coffin.position = pos + Vector3(0, 0.3, 0)
	coffin.material = stone_mat
	coffin.use_collision = true
	add_child(coffin)


func _create_altar(pos: Vector3) -> void:
	var altar := CSGBox3D.new()
	altar.name = "Altar"
	altar.size = Vector3(2.5, 1.2, 1.5)
	altar.position = pos + Vector3(0, 0.6, 0)
	altar.material = moss_mat
	altar.use_collision = true
	add_child(altar)


func _create_stairs(start_pos: Vector3, end_pos: Vector3) -> void:
	var steps := 16
	var step_height := (start_pos.y - end_pos.y) / steps
	var step_depth: float = abs(end_pos.z - start_pos.z) / steps

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


## ===========================================================================
## PORTALS & SPAWN POINTS
## ===========================================================================

func _spawn_portals() -> void:
	# Exit portal back to wilderness
	var exit_door := ZoneDoor.spawn_door(
		self,
		Vector3(0, FLOOR_1_Y, 5.5),
		SceneManager.RETURN_TO_WILDERNESS,
		"from_mosshall_tombs",
		"Exit to Wilderness"
	)
	exit_door.rotation.y = PI

	# Spawn point for arriving from wilderness
	var spawn := Node3D.new()
	spawn.name = "from_wilderness"
	spawn.position = Vector3(0, FLOOR_1_Y + 0.1, 3)
	spawn.add_to_group("spawn_points")
	spawn.set_meta("spawn_id", "from_wilderness")
	add_child(spawn)

	# Default spawn (fallback)
	var default_spawn := Node3D.new()
	default_spawn.name = "default_spawn"
	default_spawn.position = spawn.position
	default_spawn.add_to_group("spawn_points")
	default_spawn.set_meta("spawn_id", "default")
	add_child(default_spawn)


## ===========================================================================
## ENEMIES
## ===========================================================================

func _spawn_enemies() -> void:
	# Entrance Hall - 1 patrolling shade
	_spawn_enemy(Vector3(0, FLOOR_1_Y, -3), "skeleton_shade")

	# West Tomb Chamber - 2 shades
	_spawn_enemy(Vector3(-24, FLOOR_1_Y, -2), "skeleton_shade")
	_spawn_enemy(Vector3(-28, FLOOR_1_Y, 2), "skeleton_shade")

	# East Guard Hall - 2 warriors + 1 shade
	_spawn_enemy(Vector3(24, FLOOR_1_Y, -3), "skeleton_warrior")
	_spawn_enemy(Vector3(28, FLOOR_1_Y, 3), "skeleton_warrior")
	_spawn_enemy(Vector3(26, FLOOR_1_Y, 0), "skeleton_shade")

	# Central Hub - 1 warrior
	_spawn_enemy(Vector3(0, FLOOR_1_Y, -15), "skeleton_warrior")

	# Lower Antechamber - 2 shades
	_spawn_enemy(Vector3(-3, FLOOR_2_Y, -42), "skeleton_shade")
	_spawn_enemy(Vector3(3, FLOOR_2_Y, -46), "skeleton_shade")

	# Ossuary - 2 shades
	_spawn_enemy(Vector3(-22, FLOOR_2_Y, -42), "skeleton_shade")
	_spawn_enemy(Vector3(-26, FLOOR_2_Y, -46), "skeleton_shade")

	# Crypt Corridors - 1 shade each
	_spawn_enemy(Vector3(-12, FLOOR_2_Y, -44), "skeleton_shade")
	_spawn_enemy(Vector3(12, FLOOR_2_Y, -44), "skeleton_shade")

	# Boss Tomb - Boss + 3 minions
	_spawn_enemy(Vector3(-6, FLOOR_2_Y, -58), "skeleton_warrior")
	_spawn_enemy(Vector3(6, FLOOR_2_Y, -58), "skeleton_warrior")
	_spawn_enemy(Vector3(0, FLOOR_2_Y, -55), "skeleton_shade")
	_spawn_boss(Vector3(0, FLOOR_2_Y, -66))


func _spawn_enemy(pos: Vector3, enemy_type: String) -> void:
	var data_path: String
	var sprite_path: String
	var h_frames: int = 4
	var v_frames: int = 4

	# Default values by enemy type
	match enemy_type:
		"skeleton_shade":
			data_path = "res://data/enemies/skeleton_shade.tres"
			sprite_path = "res://assets/sprites/enemies/skeleton_shade.png"
		"skeleton_warrior":
			data_path = "res://data/enemies/skeleton_warrior.tres"
			sprite_path = "res://assets/sprites/enemies/undead/skeleton_warrior.png"
			h_frames = 8
			v_frames = 12
		_:
			push_warning("[MosshallTombs] Unknown enemy type: %s" % enemy_type)
			return

	# Check ActorRegistry for Zoo patches (overrides hardcoded values)
	if ActorRegistry:
		var sprite_config: Dictionary = ActorRegistry.get_sprite_config(enemy_type)
		if not sprite_config.is_empty():
			sprite_path = sprite_config.get("sprite_path", sprite_path)
			h_frames = sprite_config.get("h_frames", h_frames)
			v_frames = sprite_config.get("v_frames", v_frames)

	var sprite_texture: Texture2D = load(sprite_path)
	if not sprite_texture:
		push_warning("[MosshallTombs] Failed to load sprite: %s" % sprite_path)
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
		enemy.add_to_group("dungeon_enemies")


func _spawn_boss(pos: Vector3) -> void:
	# Tomb Guardian Spirit - stronger vampire variant
	var sprite_texture: Texture2D = load("res://assets/sprites/enemies/undead/vampire_lord_alt.png")
	if not sprite_texture:
		push_warning("[MosshallTombs] Failed to load boss sprite")
		return

	var boss := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		"res://data/enemies/vampire_lord.tres",
		sprite_texture,
		5, 3
	)

	if boss:
		boss.add_to_group("dungeon_enemies")
		boss.add_to_group("boss")


## ===========================================================================
## LOOT
## ===========================================================================

func _spawn_loot() -> void:
	# West Tomb Chamber chest
	var chest1 := Chest.spawn_chest(
		self,
		Vector3(-26, FLOOR_1_Y, 4),
		"Moss-Covered Urn",
		false,
		0,
		false,
		"mosshall_west_tomb"
	)
	chest1.setup_with_loot(LootTables.LootTier.COMMON)

	# East Guard Hall chest (locked)
	var chest2 := Chest.spawn_chest(
		self,
		Vector3(30, FLOOR_1_Y, 0),
		"Guard's Strongbox",
		true,
		14,
		false,
		"mosshall_guard_hall"
	)
	chest2.setup_with_loot(LootTables.LootTier.UNCOMMON)

	# Ossuary chest
	var chest3 := Chest.spawn_chest(
		self,
		Vector3(-24, FLOOR_2_Y, -48),
		"Bone Vessel",
		true,
		12,
		false,
		"mosshall_ossuary"
	)
	chest3.setup_with_loot(LootTables.LootTier.UNCOMMON)

	# Boss chamber reward
	var chest4 := Chest.spawn_chest(
		self,
		Vector3(0, FLOOR_2_Y, -70),
		"Ancient Sarcophagus",
		true,
		18,
		false,
		"mosshall_boss"
	)
	chest4.setup_with_loot(LootTables.LootTier.RARE)
