## sunken_crypt.gd - Early-game dungeon (Level 2-4)
## Hand-crafted dungeon with flooded lower sections and undead enemies
## Located off the main road between Elder Moor and Dalhurst
extends Node3D

const ZONE_ID := "sunken_crypt"
const ZONE_DISPLAY_NAME := "Sunken Crypt"

## Floor heights
const FLOOR_1_Y := 0.0
const FLOOR_2_Y := -6.0  # Partially flooded lower level

## Materials (created once)
var stone_mat: StandardMaterial3D
var floor_mat: StandardMaterial3D
var moss_mat: StandardMaterial3D
var water_mat: StandardMaterial3D

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
	_create_entrance_room()
	_create_corridor_1()
	_create_guard_room()
	_create_corridor_2()
	_create_shrine_room()
	_create_treasure_room()
	_create_flooded_corridor()
	_create_boss_chamber()
	_spawn_portals()
	_spawn_enemies()
	_spawn_loot()
	_setup_cell_streaming()

	print("[SunkenCrypt] Dungeon initialized")


func _create_materials() -> void:
	# Dark stone with green moss tint (water damage)
	stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.15, 0.18, 0.15)
	stone_mat.roughness = 0.95

	floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.12, 0.14, 0.12)
	floor_mat.roughness = 0.9

	# Mossy stone
	moss_mat = StandardMaterial3D.new()
	moss_mat.albedo_color = Color(0.1, 0.2, 0.1)
	moss_mat.roughness = 0.85

	# Murky water
	water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.1, 0.15, 0.12, 0.7)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.3


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
## ROOM CREATION - Edit positions/sizes here to modify dungeon layout
## ===========================================================================

## Entrance Room (12x12, height 5) - Player enters here
func _create_entrance_room() -> void:
	var pos := Vector3(0, FLOOR_1_Y, 0)
	_create_room_box(pos, Vector3(12, 5, 12), "Entrance")

	# Decorative pillars
	_create_pillar(pos + Vector3(-4, 0, -4))
	_create_pillar(pos + Vector3(4, 0, -4))
	_create_pillar(pos + Vector3(-4, 0, 4))
	_create_pillar(pos + Vector3(4, 0, 4))


## Corridor 1 - North from entrance (4x10, height 4)
func _create_corridor_1() -> void:
	var pos := Vector3(0, FLOOR_1_Y, -11)
	_create_room_box(pos, Vector3(4, 4, 10), "Corridor1")


## Guard Room (14x14, height 5) - First combat encounter
func _create_guard_room() -> void:
	var pos := Vector3(0, FLOOR_1_Y, -22)
	_create_room_box(pos, Vector3(14, 5, 14), "GuardRoom")

	# Corner pillars
	_create_pillar(pos + Vector3(-5, 0, -5))
	_create_pillar(pos + Vector3(5, 0, -5))
	_create_pillar(pos + Vector3(-5, 0, 5))
	_create_pillar(pos + Vector3(5, 0, 5))


## Corridor 2 - West from guard room (10x4, height 4)
func _create_corridor_2() -> void:
	var pos := Vector3(-12, FLOOR_1_Y, -22)
	_create_room_box(pos, Vector3(10, 4, 4), "Corridor2")


## Shrine Room (10x10, height 6) - Rest area
func _create_shrine_room() -> void:
	var pos := Vector3(-22, FLOOR_1_Y, -22)
	_create_room_box(pos, Vector3(10, 6, 10), "ShrineRoom")

	# Altar
	_create_altar(pos + Vector3(0, 0, 3))

	# Rest spot
	RestSpot.spawn_rest_spot(self, pos + Vector3(0, 0.1, 1), "Mossy Shrine")


## Treasure Room (10x10, height 4) - East from guard room
func _create_treasure_room() -> void:
	var pos := Vector3(12, FLOOR_1_Y, -22)
	_create_room_box(pos, Vector3(10, 4, 10), "TreasureRoom")

	# Coffin decorations
	_create_coffin(pos + Vector3(-3, 0, 2))
	_create_coffin(pos + Vector3(3, 0, 2))


## Flooded Corridor - Down to boss (4x12, height 4)
func _create_flooded_corridor() -> void:
	var pos := Vector3(0, FLOOR_1_Y, -36)
	_create_room_box(pos, Vector3(4, 4, 12), "FloodedCorridor")

	# Stairs down
	_create_stairs(Vector3(0, FLOOR_1_Y, -38), Vector3(0, FLOOR_2_Y, -46))

	# Water at the bottom
	var water := CSGBox3D.new()
	water.name = "Water"
	water.size = Vector3(6, 0.3, 8)
	water.position = Vector3(0, FLOOR_2_Y + 0.15, -50)
	water.material = water_mat
	add_child(water)


## Boss Chamber (16x16, height 7) - Final fight
func _create_boss_chamber() -> void:
	var pos := Vector3(0, FLOOR_2_Y, -58)
	_create_room_box(pos, Vector3(16, 7, 16), "BossChamber")

	# Boss throne
	var throne := CSGBox3D.new()
	throne.name = "Throne"
	throne.size = Vector3(4, 3, 2)
	throne.position = pos + Vector3(0, 1.5, 6)
	throne.material = stone_mat
	throne.use_collision = true
	add_child(throne)

	# Corner pillars
	_create_pillar(pos + Vector3(-6, 0, -6))
	_create_pillar(pos + Vector3(6, 0, -6))
	_create_pillar(pos + Vector3(-6, 0, 6))
	_create_pillar(pos + Vector3(6, 0, 6))

	# Shallow water covering floor
	var floor_water := CSGBox3D.new()
	floor_water.name = "FloorWater"
	floor_water.size = Vector3(14, 0.2, 14)
	floor_water.position = pos + Vector3(0, 0.1, 0)
	floor_water.material = water_mat
	add_child(floor_water)


## ===========================================================================
## GEOMETRY HELPERS
## ===========================================================================

## Create a complete room (floor, ceiling, walls)
func _create_room_box(center: Vector3, size: Vector3, room_name: String) -> void:
	var half := size / 2.0

	# Floor
	var floor_box := CSGBox3D.new()
	floor_box.name = room_name + "_Floor"
	floor_box.size = Vector3(size.x, 0.5, size.z)
	floor_box.position = center + Vector3(0, -0.25, 0)
	floor_box.material = floor_mat
	floor_box.use_collision = true
	add_child(floor_box)

	# Ceiling
	var ceiling := CSGBox3D.new()
	ceiling.name = room_name + "_Ceiling"
	ceiling.size = Vector3(size.x, 0.5, size.z)
	ceiling.position = center + Vector3(0, size.y, 0)
	ceiling.material = stone_mat
	ceiling.use_collision = true
	add_child(ceiling)

	# Walls (create solid walls - door gaps are cut manually)
	_create_wall(center + Vector3(-half.x - 0.25, half.y, 0), Vector3(0.5, size.y, size.z), room_name + "_WallW")
	_create_wall(center + Vector3(half.x + 0.25, half.y, 0), Vector3(0.5, size.y, size.z), room_name + "_WallE")
	_create_wall(center + Vector3(0, half.y, -half.z - 0.25), Vector3(size.x, size.y, 0.5), room_name + "_WallN")
	_create_wall(center + Vector3(0, half.y, half.z + 0.25), Vector3(size.x, size.y, 0.5), room_name + "_WallS")


func _create_wall(pos: Vector3, size: Vector3, wall_name: String) -> void:
	var wall := CSGBox3D.new()
	wall.name = wall_name
	wall.size = size
	wall.position = pos
	wall.material = stone_mat
	wall.use_collision = true
	add_child(wall)


func _create_pillar(pos: Vector3) -> void:
	var pillar := CSGBox3D.new()
	pillar.name = "Pillar"
	pillar.size = Vector3(1, 4.5, 1)
	pillar.position = pos + Vector3(0, 2.25, 0)
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
	var steps := 12
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
		"from_sunken_crypt",
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
## ENEMIES - Edit positions here to adjust enemy placement
## ===========================================================================

func _spawn_enemies() -> void:
	# Guard Room - 2 Skeleton Shades
	_spawn_enemy(Vector3(-4, FLOOR_1_Y, -20), "skeleton_shade")
	_spawn_enemy(Vector3(4, FLOOR_1_Y, -24), "skeleton_shade")

	# Corridor 2 - 1 Skeleton Shade
	_spawn_enemy(Vector3(-12, FLOOR_1_Y, -22), "skeleton_shade")

	# Treasure Room - 1 Skeleton Warrior (harder)
	_spawn_enemy(Vector3(12, FLOOR_1_Y, -22), "skeleton_warrior")

	# Flooded Corridor - Flaming Skulls floating above player
	_spawn_enemy(Vector3(0, FLOOR_1_Y + 3.5, -32), "flaming_skull")

	# Boss Chamber - Drowned One (boss) + 2 Skeleton Shades + Flaming Skulls
	_spawn_enemy(Vector3(-4, FLOOR_2_Y, -55), "skeleton_shade")
	_spawn_enemy(Vector3(4, FLOOR_2_Y, -55), "skeleton_shade")
	_spawn_enemy(Vector3(-6, FLOOR_2_Y + 3.5, -58), "flaming_skull")
	_spawn_enemy(Vector3(6, FLOOR_2_Y + 4.0, -58), "flaming_skull")
	_spawn_boss(Vector3(0, FLOOR_2_Y, -60))


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
		"flaming_skull":
			data_path = "res://data/enemies/flaming_skull.tres"
			sprite_path = "res://assets/sprites/enemies/undead/flaming_skull_enemy.png"
			h_frames = 4
			v_frames = 1
		_:
			push_warning("[SunkenCrypt] Unknown enemy type: %s" % enemy_type)
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
		push_warning("[SunkenCrypt] Failed to load sprite: %s" % sprite_path)
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
	# For now, use Vampire Lord as boss placeholder
	# TODO: Create unique "Drowned One" boss for this dungeon
	var sprite_texture: Texture2D = load("res://assets/sprites/enemies/undead/vampire_lord_alt.png")
	if not sprite_texture:
		push_warning("[SunkenCrypt] Failed to load boss sprite")
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
## LOOT - Edit positions here to adjust chest placement
## ===========================================================================

func _spawn_loot() -> void:
	# Treasure Room chest (locked)
	var chest1 := Chest.spawn_chest(
		self,
		Vector3(12, FLOOR_1_Y, -18),
		"Waterlogged Chest",
		true,
		12,
		false,
		"sunken_crypt_treasure"
	)
	chest1.setup_with_loot(LootTables.LootTier.UNCOMMON)

	# Boss chamber reward (locked, better loot)
	var chest2 := Chest.spawn_chest(
		self,
		Vector3(0, FLOOR_2_Y, -64),
		"Ancient Sarcophagus",
		true,
		15,
		false,
		"sunken_crypt_boss"
	)
	chest2.setup_with_loot(LootTables.LootTier.RARE)


## Setup cell streaming if we're the main scene (has Player/HUD)
## When loaded as a streaming cell, this will be skipped (Player/HUD stripped by CellStreamer)
func _setup_cell_streaming() -> void:
	# Only setup streaming if we're the main scene (we have Player/HUD)
	var player: Node = get_node_or_null("Player")
	if not player:
		# We're a streaming cell, not main scene - skip streaming setup
		return

	if not CellStreamer:
		push_warning("[%s] CellStreamer not found" % ZONE_ID)
		return

	# Use WorldGrid location_id (sunken_crypts) to get coordinates
	var my_coords: Vector2i = WorldGrid.get_location_coords("sunken_crypts")
	if my_coords == Vector2i(-9999, -9999):  # Invalid coords returned if not found
		push_warning("[%s] Location 'sunken_crypts' not found in WorldGrid" % ZONE_ID)
		return
	CellStreamer.register_main_scene_cell(my_coords, self)
	CellStreamer.start_streaming(my_coords)
	print("[%s] Registered as main scene, streaming started at %s" % [ZONE_ID, my_coords])
