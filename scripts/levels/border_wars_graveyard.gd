## border_wars_graveyard.gd - Ancient battlefield graveyard dungeon
## An enormous graveyard from the border wars 100 years ago
## Hundreds of thousands of corpses, scattered weapons, undead, and grave diggers
extends Node3D

const ZONE_ID := "border_wars_graveyard"

## Materials
var dirt_mat: StandardMaterial3D
var grave_mat: StandardMaterial3D
var bone_mat: StandardMaterial3D
var rusted_metal_mat: StandardMaterial3D

## Navigation
var nav_region: NavigationRegion3D

## Battlefield dimensions (large open area)
const BATTLEFIELD_SIZE := Vector2(120, 100)  # X and Z dimensions
const GROUND_Y := 0.0

## Charnel pit location (central depression)
const CHARNEL_PIT_CENTER := Vector3(0, -4.0, -20)
const CHARNEL_PIT_RADIUS := 15.0


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Border Wars Graveyard")

	_create_materials()
	_setup_navigation()
	_create_battlefield_terrain()
	_create_charnel_pit()
	_create_gravestones_and_mounds()
	_create_scattered_weapons()
	# NOTE: Gore decorations (battlefield backdrop, skull spikes, gore piles, wraiths)
	# are now pre-placed in border_wars_graveyard.tscn under GoreDecorations node
	_spawn_spawn_points()
	_spawn_portals()
	_spawn_undead_enemies()
	_spawn_grave_digger_npc()
	_spawn_loot()
	_create_atmosphere()

	print("[BorderWarsGraveyard] Dungeon initialized!")


func _create_materials() -> void:
	# Dirt/earth material - dark brownish gray
	dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.18, 0.15, 0.12)
	dirt_mat.roughness = 0.95

	# Gravestone material - weathered gray stone
	grave_mat = StandardMaterial3D.new()
	grave_mat.albedo_color = Color(0.28, 0.28, 0.3)
	grave_mat.roughness = 0.9

	# Bone material - yellowed white
	bone_mat = StandardMaterial3D.new()
	bone_mat.albedo_color = Color(0.75, 0.7, 0.55)
	bone_mat.roughness = 0.85

	# Rusted metal - for scattered weapons/armor
	rusted_metal_mat = StandardMaterial3D.new()
	rusted_metal_mat.albedo_color = Color(0.35, 0.25, 0.18)
	rusted_metal_mat.roughness = 0.8
	rusted_metal_mat.metallic = 0.3


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
	nav_mesh.agent_max_climb = 0.75
	nav_mesh.agent_max_slope = 45.0

	nav_region.navigation_mesh = nav_mesh
	call_deferred("_bake_navigation")


func _bake_navigation() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()
		print("[BorderWarsGraveyard] Navigation mesh baked!")


## Create the main battlefield terrain - large rolling ground with undulations
func _create_battlefield_terrain() -> void:
	# Main ground plane
	var ground := CSGBox3D.new()
	ground.name = "BattlefieldGround"
	ground.size = Vector3(BATTLEFIELD_SIZE.x, 2, BATTLEFIELD_SIZE.y)
	ground.position = Vector3(0, GROUND_Y - 1, 0)
	ground.material = dirt_mat
	ground.use_collision = true
	add_child(ground)

	# Add some terrain undulations (burial mounds and depressions)
	_create_terrain_feature(Vector3(-40, 0, 30), 8.0, 0.8, "Mound_NW1")
	_create_terrain_feature(Vector3(35, 0, 25), 10.0, 1.0, "Mound_NE1")
	_create_terrain_feature(Vector3(-30, 0, -30), 12.0, 1.2, "Mound_SW1")
	_create_terrain_feature(Vector3(40, 0, -25), 9.0, 0.9, "Mound_SE1")
	_create_terrain_feature(Vector3(20, 0, 40), 7.0, 0.6, "Mound_N1")
	_create_terrain_feature(Vector3(-15, 0, -40), 11.0, 1.1, "Mound_S1")

	# Boundary walls (ancient crumbling walls, suggests this was a fortified area)
	_create_boundary_walls()

	print("[BorderWarsGraveyard] Battlefield terrain created")


## Create a terrain mound/hill feature
func _create_terrain_feature(pos: Vector3, radius: float, height: float, feature_name: String) -> void:
	var mound := CSGCylinder3D.new()
	mound.name = feature_name
	mound.radius = radius
	mound.height = height
	mound.position = Vector3(pos.x, height / 2.0, pos.z)
	mound.material = dirt_mat
	mound.use_collision = true
	add_child(mound)


## Create crumbling boundary walls
func _create_boundary_walls() -> void:
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.25, 0.22, 0.2)
	wall_mat.roughness = 0.95

	# North wall (broken segments)
	_create_wall_segment(Vector3(-40, 0, -48), Vector3(25, 3, 1.5), wall_mat, "NorthWall_1")
	_create_wall_segment(Vector3(10, 0, -48), Vector3(20, 2, 1.5), wall_mat, "NorthWall_2")
	_create_wall_segment(Vector3(40, 0, -48), Vector3(15, 4, 1.5), wall_mat, "NorthWall_3")

	# South wall
	_create_wall_segment(Vector3(-35, 0, 48), Vector3(30, 2.5, 1.5), wall_mat, "SouthWall_1")
	_create_wall_segment(Vector3(25, 0, 48), Vector3(25, 3, 1.5), wall_mat, "SouthWall_2")

	# East wall
	_create_wall_segment(Vector3(58, 0, -20), Vector3(1.5, 3.5, 30), wall_mat, "EastWall_1")
	_create_wall_segment(Vector3(58, 0, 25), Vector3(1.5, 2, 25), wall_mat, "EastWall_2")

	# West wall
	_create_wall_segment(Vector3(-58, 0, 0), Vector3(1.5, 4, 40), wall_mat, "WestWall_1")
	_create_wall_segment(Vector3(-58, 0, 35), Vector3(1.5, 2.5, 20), wall_mat, "WestWall_2")


func _create_wall_segment(pos: Vector3, size: Vector3, mat: Material, wall_name: String) -> void:
	var wall := CSGBox3D.new()
	wall.name = wall_name
	wall.size = size
	wall.position = Vector3(pos.x, size.y / 2.0, pos.z)
	wall.material = mat
	wall.use_collision = true
	add_child(wall)


## Create the central charnel pit - a large depression filled with bones
func _create_charnel_pit() -> void:
	# Pit depression (carved out of terrain)
	var pit_floor := CSGBox3D.new()
	pit_floor.name = "CharnelPitFloor"
	pit_floor.size = Vector3(CHARNEL_PIT_RADIUS * 2.5, 1, CHARNEL_PIT_RADIUS * 2.5)
	pit_floor.position = Vector3(CHARNEL_PIT_CENTER.x, CHARNEL_PIT_CENTER.y - 0.5, CHARNEL_PIT_CENTER.z)
	pit_floor.material = dirt_mat
	pit_floor.use_collision = true
	add_child(pit_floor)

	# Pit walls (slopes down)
	_create_pit_wall(Vector3(CHARNEL_PIT_CENTER.x - CHARNEL_PIT_RADIUS - 2, 0, CHARNEL_PIT_CENTER.z),
		Vector3(4, 4.5, CHARNEL_PIT_RADIUS * 2.5), "PitWall_W")
	_create_pit_wall(Vector3(CHARNEL_PIT_CENTER.x + CHARNEL_PIT_RADIUS + 2, 0, CHARNEL_PIT_CENTER.z),
		Vector3(4, 4.5, CHARNEL_PIT_RADIUS * 2.5), "PitWall_E")
	_create_pit_wall(Vector3(CHARNEL_PIT_CENTER.x, 0, CHARNEL_PIT_CENTER.z - CHARNEL_PIT_RADIUS - 2),
		Vector3(CHARNEL_PIT_RADIUS * 2.5, 4.5, 4), "PitWall_N")
	_create_pit_wall(Vector3(CHARNEL_PIT_CENTER.x, 0, CHARNEL_PIT_CENTER.z + CHARNEL_PIT_RADIUS + 2),
		Vector3(CHARNEL_PIT_RADIUS * 2.5, 4.5, 4), "PitWall_S")

	# Bone piles scattered in the pit
	for i in range(12):
		var angle := randf() * TAU
		var dist := randf_range(2.0, CHARNEL_PIT_RADIUS - 2)
		var bone_pos := Vector3(
			CHARNEL_PIT_CENTER.x + cos(angle) * dist,
			CHARNEL_PIT_CENTER.y + randf_range(0.2, 0.8),
			CHARNEL_PIT_CENTER.z + sin(angle) * dist
		)
		_create_bone_pile(bone_pos, "BonePile_Pit_%d" % i)

	# Central large bone mound
	var central_bones := CSGSphere3D.new()
	central_bones.name = "CentralBoneMound"
	central_bones.radius = 3.0
	central_bones.position = Vector3(CHARNEL_PIT_CENTER.x, CHARNEL_PIT_CENTER.y + 1.0, CHARNEL_PIT_CENTER.z)
	central_bones.material = bone_mat
	central_bones.use_collision = true
	add_child(central_bones)

	print("[BorderWarsGraveyard] Charnel pit created")


func _create_pit_wall(pos: Vector3, size: Vector3, wall_name: String) -> void:
	var wall := CSGBox3D.new()
	wall.name = wall_name
	wall.size = size
	wall.position = Vector3(pos.x, -size.y / 2.0 + 0.5, pos.z)
	wall.material = dirt_mat
	wall.use_collision = true
	add_child(wall)


func _create_bone_pile(pos: Vector3, pile_name: String) -> void:
	var pile := CSGSphere3D.new()
	pile.name = pile_name
	pile.radius = randf_range(0.5, 1.2)
	pile.position = pos
	pile.material = bone_mat
	pile.use_collision = true
	add_child(pile)


## Create gravestones and burial mounds across the battlefield
func _create_gravestones_and_mounds() -> void:
	# Generate many gravestones in rows (mass graves from the war)
	var gravestone_count := 80

	for i in range(gravestone_count):
		# Distribute across the battlefield, avoiding charnel pit
		var pos := _get_random_battlefield_position()

		# Skip if too close to charnel pit
		var dist_to_pit := Vector2(pos.x - CHARNEL_PIT_CENTER.x, pos.z - CHARNEL_PIT_CENTER.z).length()
		if dist_to_pit < CHARNEL_PIT_RADIUS + 5:
			continue

		if randf() < 0.7:
			_create_gravestone(pos, i)
		else:
			_create_burial_mound(pos, i)

	# Create organized row sections (military burial ground style)
	_create_grave_row(Vector3(-40, 0, 10), 8, Vector3(3, 0, 0), 100)
	_create_grave_row(Vector3(-40, 0, 15), 8, Vector3(3, 0, 0), 110)
	_create_grave_row(Vector3(25, 0, 30), 6, Vector3(0, 0, 3), 120)
	_create_grave_row(Vector3(30, 0, 30), 6, Vector3(0, 0, 3), 130)

	print("[BorderWarsGraveyard] Gravestones and burial mounds created")


func _get_random_battlefield_position() -> Vector3:
	var x := randf_range(-BATTLEFIELD_SIZE.x / 2.0 + 10, BATTLEFIELD_SIZE.x / 2.0 - 10)
	var z := randf_range(-BATTLEFIELD_SIZE.y / 2.0 + 10, BATTLEFIELD_SIZE.y / 2.0 - 10)
	return Vector3(x, GROUND_Y, z)


func _create_gravestone(pos: Vector3, index: int) -> void:
	var stone := CSGBox3D.new()
	stone.name = "Gravestone_%d" % index

	# Varying gravestone sizes
	var height := randf_range(0.8, 1.8)
	var width := randf_range(0.4, 0.8)
	stone.size = Vector3(width, height, 0.15)
	stone.position = Vector3(pos.x, height / 2.0, pos.z)

	# Slight random rotation (weathered, tilted)
	stone.rotation.y = randf_range(-0.2, 0.2)
	stone.rotation.z = randf_range(-0.1, 0.1)

	stone.material = grave_mat
	stone.use_collision = true
	add_child(stone)


func _create_burial_mound(pos: Vector3, index: int) -> void:
	var mound := CSGCylinder3D.new()
	mound.name = "BurialMound_%d" % index
	mound.radius = randf_range(1.0, 2.0)
	mound.height = randf_range(0.3, 0.6)
	mound.position = Vector3(pos.x, mound.height / 2.0, pos.z)
	mound.material = dirt_mat
	mound.use_collision = true
	add_child(mound)


func _create_grave_row(start_pos: Vector3, count: int, offset: Vector3, start_index: int) -> void:
	for i in range(count):
		var pos := start_pos + offset * i
		_create_gravestone(pos, start_index + i)


## Create scattered weapons and armor across the battlefield
func _create_scattered_weapons() -> void:
	var weapon_count := 40

	for i in range(weapon_count):
		var pos := _get_random_battlefield_position()

		# Skip if in charnel pit
		var dist_to_pit := Vector2(pos.x - CHARNEL_PIT_CENTER.x, pos.z - CHARNEL_PIT_CENTER.z).length()
		if dist_to_pit < CHARNEL_PIT_RADIUS:
			continue

		var roll := randf()
		if roll < 0.4:
			_create_fallen_sword(pos, i)
		elif roll < 0.7:
			_create_fallen_shield(pos, i)
		else:
			_create_armor_piece(pos, i)

	# Add some weapon clusters (battle sites)
	_create_weapon_cluster(Vector3(30, 0, -15), 5)
	_create_weapon_cluster(Vector3(-25, 0, 20), 4)
	_create_weapon_cluster(Vector3(15, 0, 35), 3)

	print("[BorderWarsGraveyard] Scattered weapons created")


func _create_fallen_sword(pos: Vector3, index: int) -> void:
	var sword := CSGBox3D.new()
	sword.name = "FallenSword_%d" % index
	sword.size = Vector3(0.08, 0.04, 1.2)
	sword.position = Vector3(pos.x, 0.02, pos.z)
	sword.rotation.y = randf() * TAU
	sword.material = rusted_metal_mat
	sword.use_collision = false  # Decorative only
	add_child(sword)


func _create_fallen_shield(pos: Vector3, index: int) -> void:
	var shield := CSGCylinder3D.new()
	shield.name = "FallenShield_%d" % index
	shield.radius = randf_range(0.3, 0.5)
	shield.height = 0.05
	shield.position = Vector3(pos.x, 0.03, pos.z)
	shield.rotation.x = randf_range(-0.3, 0.3)
	shield.rotation.z = randf_range(-0.3, 0.3)
	shield.material = rusted_metal_mat
	shield.use_collision = false
	add_child(shield)


func _create_armor_piece(pos: Vector3, index: int) -> void:
	# Simple helmet/armor representation
	var armor := CSGSphere3D.new()
	armor.name = "ArmorPiece_%d" % index
	armor.radius = randf_range(0.15, 0.25)
	armor.position = Vector3(pos.x, armor.radius, pos.z)
	armor.material = rusted_metal_mat
	armor.use_collision = false
	add_child(armor)


func _create_weapon_cluster(center: Vector3, count: int) -> void:
	for i in range(count):
		var offset := Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		var pos := center + offset
		if randf() < 0.5:
			_create_fallen_sword(pos, 1000 + i)
		else:
			_create_fallen_shield(pos, 1000 + i)


## Spawn points for arriving from other zones
func _spawn_spawn_points() -> void:
	# Main entrance (from East Hollow)
	var from_east_hollow := Node3D.new()
	from_east_hollow.name = "from_east_hollow"
	from_east_hollow.position = Vector3(0, GROUND_Y + 0.1, 45)
	from_east_hollow.add_to_group("spawn_points")
	from_east_hollow.set_meta("spawn_id", "from_east_hollow")
	add_child(from_east_hollow)

	# Default spawn
	var default_spawn := Node3D.new()
	default_spawn.name = "default_spawn"
	default_spawn.position = Vector3(0, GROUND_Y + 0.1, 45)
	default_spawn.add_to_group("spawn_points")
	default_spawn.set_meta("spawn_id", "default")
	add_child(default_spawn)

	# Entrance spawn (for world map)
	var entrance_spawn := Node3D.new()
	entrance_spawn.name = "entrance"
	entrance_spawn.position = Vector3(0, GROUND_Y + 0.1, 45)
	entrance_spawn.add_to_group("spawn_points")
	entrance_spawn.set_meta("spawn_id", "entrance")
	add_child(entrance_spawn)

	print("[BorderWarsGraveyard] Spawn points created at: ", from_east_hollow.position)


## Spawn portal to East Hollow
func _spawn_portals() -> void:
	# Portal to East Hollow (south edge of battlefield)
	var east_hollow_portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, GROUND_Y, 48),
		"res://scenes/levels/east_hollow.tscn",
		"from_graveyard",
		"Road to East Hollow"
	)
	east_hollow_portal.rotation.y = PI  # Face into the graveyard
	east_hollow_portal.show_frame = false  # Outdoor area, no door frame

	# Register as compass POI
	east_hollow_portal.add_to_group("compass_poi")
	east_hollow_portal.set_meta("poi_id", "east_hollow_road")
	east_hollow_portal.set_meta("poi_name", "East Hollow")
	east_hollow_portal.set_meta("poi_color", Color(0.5, 0.5, 0.7))

	# Portal to Windmere (north edge - leads toward Tenger territory)
	var windmere_portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, GROUND_Y, -48),
		"res://scenes/levels/windmere.tscn",
		"from_graveyard",
		"Path to Windmere (DANGER)"
	)
	windmere_portal.rotation.y = 0
	windmere_portal.show_frame = false

	# Register as compass POI
	windmere_portal.add_to_group("compass_poi")
	windmere_portal.set_meta("poi_id", "windmere_road")
	windmere_portal.set_meta("poi_name", "Windmere (Destroyed)")
	windmere_portal.set_meta("poi_color", Color(0.7, 0.3, 0.2))  # Red-ish for danger

	# Spawn point from Windmere
	var from_windmere := Node3D.new()
	from_windmere.name = "from_windmere"
	from_windmere.position = Vector3(0, GROUND_Y + 0.1, -45)
	from_windmere.add_to_group("spawn_points")
	from_windmere.set_meta("spawn_id", "from_windmere")
	add_child(from_windmere)

	print("[BorderWarsGraveyard] Portals spawned: East Hollow, Windmere")


## Spawn undead enemies throughout the graveyard
func _spawn_undead_enemies() -> void:
	var skeleton_sprite: Texture2D = load("res://assets/sprites/enemies/skeleton_shade.png")
	if not skeleton_sprite:
		push_warning("[BorderWarsGraveyard] Failed to load skeleton_shade sprite!")
		return

	# Spawn skeletons across the battlefield - lots of them
	var skeleton_positions := [
		# Near entrance area
		Vector3(-10, GROUND_Y, 35),
		Vector3(12, GROUND_Y, 38),
		Vector3(-5, GROUND_Y, 30),

		# Central area (around charnel pit)
		Vector3(-25, GROUND_Y, -10),
		Vector3(25, GROUND_Y, -15),
		Vector3(-20, GROUND_Y, -25),
		Vector3(20, GROUND_Y, -25),
		Vector3(-30, GROUND_Y, 0),
		Vector3(30, GROUND_Y, 5),

		# In the charnel pit (stronger presence)
		Vector3(CHARNEL_PIT_CENTER.x - 8, CHARNEL_PIT_CENTER.y + 0.5, CHARNEL_PIT_CENTER.z),
		Vector3(CHARNEL_PIT_CENTER.x + 8, CHARNEL_PIT_CENTER.y + 0.5, CHARNEL_PIT_CENTER.z),
		Vector3(CHARNEL_PIT_CENTER.x, CHARNEL_PIT_CENTER.y + 0.5, CHARNEL_PIT_CENTER.z - 8),
		Vector3(CHARNEL_PIT_CENTER.x, CHARNEL_PIT_CENTER.y + 0.5, CHARNEL_PIT_CENTER.z + 8),
		Vector3(CHARNEL_PIT_CENTER.x - 5, CHARNEL_PIT_CENTER.y + 0.5, CHARNEL_PIT_CENTER.z - 5),
		Vector3(CHARNEL_PIT_CENTER.x + 5, CHARNEL_PIT_CENTER.y + 0.5, CHARNEL_PIT_CENTER.z + 5),

		# Northern graveyard section
		Vector3(-35, GROUND_Y, -35),
		Vector3(35, GROUND_Y, -40),
		Vector3(0, GROUND_Y, -42),

		# Western section
		Vector3(-45, GROUND_Y, 15),
		Vector3(-40, GROUND_Y, -5),

		# Eastern section
		Vector3(45, GROUND_Y, 10),
		Vector3(40, GROUND_Y, -10),
	]

	for i in skeleton_positions.size():
		var pos: Vector3 = skeleton_positions[i]
		var enemy := EnemyBase.spawn_billboard_enemy(
			self,
			pos,
			"res://data/enemies/skeleton_shade.tres",
			skeleton_sprite,
			4, 4  # 4x4 sprite sheet
		)
		if enemy:
			enemy.add_to_group("graveyard_undead")
			# Apply undead glow
			enemy.call_deferred("_check_and_apply_undead_glow", "res://data/enemies/skeleton_shade.tres")

	# Add a skeleton spawner in the charnel pit (constant undead rising)
	var pit_spawner := EnemySpawner.spawn_spawner(
		self,
		Vector3(CHARNEL_PIT_CENTER.x, CHARNEL_PIT_CENTER.y + 1, CHARNEL_PIT_CENTER.z),
		"charnel_pit_spawner"
	)
	pit_spawner.display_name = "Restless Grave"
	pit_spawner.max_hp = 500
	pit_spawner.armor_value = 5
	pit_spawner.max_spawned_enemies = 6
	pit_spawner.spawn_radius = 8.0
	pit_spawner.spawn_interval_min = 25.0
	pit_spawner.spawn_interval_max = 40.0
	pit_spawner.enemy_data_path = "res://data/enemies/skeleton_shade.tres"
	pit_spawner.secondary_enemy_enabled = false  # Only skeleton shades
	pit_spawner.mesh_height = 1.5
	pit_spawner.mesh_radius = 0.8

	print("[BorderWarsGraveyard] Spawned %d undead enemies + pit spawner" % skeleton_positions.size())


## Spawn a grave digger NPC (neutral, looking for profit)
func _spawn_grave_digger_npc() -> void:
	# Create a simple NPC using the QuestGiver base as reference
	var digger := StaticBody3D.new()
	digger.name = "GraveDiggerNPC"
	digger.position = Vector3(-35, GROUND_Y, 25)
	digger.add_to_group("interactable")
	digger.add_to_group("npcs")
	add_child(digger)

	# Store NPC data as metadata
	digger.set_meta("npc_id", "grave_digger_graveyard")
	digger.set_meta("display_name", "Grave Digger")

	# Body mesh (hunched figure in ragged clothes)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.3
	body_mesh.height = 1.4  # Slightly hunched
	body.mesh = body_mesh
	body.position.y = 0.7

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.2, 0.18, 0.15)  # Dirty brown clothes
	body_mat.roughness = 0.95
	body.material_override = body_mat
	digger.add_child(body)

	# Head
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.18
	head.mesh = head_mesh
	head.position.y = 1.5

	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.5, 0.45, 0.35)  # Dirty skin tone
	head.material_override = head_mat
	digger.add_child(head)

	# Shovel prop
	var shovel := MeshInstance3D.new()
	shovel.name = "Shovel"
	var shovel_mesh := BoxMesh.new()
	shovel_mesh.size = Vector3(0.05, 1.5, 0.05)
	shovel.mesh = shovel_mesh
	shovel.position = Vector3(0.4, 0.75, 0)
	shovel.rotation.z = 0.2
	shovel.material_override = rusted_metal_mat
	digger.add_child(shovel)

	# Collision
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.4
	collision.shape = shape
	collision.position.y = 0.7
	digger.add_child(collision)

	# Interaction area
	var interact_area := Area3D.new()
	interact_area.name = "InteractionArea"
	interact_area.collision_layer = 256  # Layer 9 for interactables
	interact_area.collision_mask = 0
	digger.add_child(interact_area)

	var area_collision := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = 2.5
	area_collision.shape = area_shape
	area_collision.position.y = 1.0
	interact_area.add_child(area_collision)

	# Add compass POI
	digger.add_to_group("compass_poi")
	digger.set_meta("poi_id", "npc_grave_digger")
	digger.set_meta("poi_name", "Grave Digger")
	digger.set_meta("poi_color", Color(0.6, 0.5, 0.3))  # Brownish for neutral NPC

	# Attach a simple interaction script
	digger.set_script(_create_grave_digger_script())

	print("[BorderWarsGraveyard] Grave Digger NPC spawned at: ", digger.position)


func _create_grave_digger_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = '''extends StaticBody3D

var dialogue_ui: Control = null
var dialogue_lines := [
	"*spits* Another adventurer, eh?",
	"Plenty of treasures buried here...",
	"...if ye don\'t mind the company.",
	"The dead don\'t like being disturbed.",
	"But gold is gold, ain\'t it?",
	"Watch yerself around the pit.",
	"Things crawl out of there at night..."
]

func interact(_interactor: Node) -> void:
	if dialogue_ui:
		return
	_open_dialogue()

func get_interaction_prompt() -> String:
	return "Talk to Grave Digger"

func _open_dialogue() -> void:
	get_tree().paused = true
	GameManager.enter_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var canvas := CanvasLayer.new()
	canvas.name = "DialogueCanvas"
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	dialogue_ui = _create_dialogue_panel()
	canvas.add_child(dialogue_ui)

func _create_dialogue_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -100
	panel.offset_bottom = 100
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1)
	style.border_color = Color(0.3, 0.25, 0.2)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = "GRAVE DIGGER"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.3))
	name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_label)

	var text_label := Label.new()
	text_label.text = dialogue_lines[randi() % dialogue_lines.size()]
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	vbox.add_child(text_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	vbox.add_child(spacer)

	var btn := Button.new()
	btn.text = "Leave"
	btn.custom_minimum_size = Vector2(150, 35)
	btn.pressed.connect(_close_dialogue)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(btn)
	vbox.add_child(btn)

	return panel

func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.12, 0.15)
	normal.border_color = Color(0.3, 0.25, 0.2)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.2, 0.15)
	hover.border_color = Color(0.8, 0.6, 0.2)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	btn.add_theme_color_override("font_hover_color", Color(0.8, 0.6, 0.2))

func _close_dialogue() -> void:
	if dialogue_ui:
		var canvas := dialogue_ui.get_parent()
		dialogue_ui.queue_free()
		if canvas:
			canvas.queue_free()
		dialogue_ui = null

	get_tree().paused = false
	GameManager.exit_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
'''
	return script


## Spawn loot chests
func _spawn_loot() -> void:
	# Chest near the grave digger (hidden stash)
	var digger_chest := Chest.spawn_chest(
		self,
		Vector3(-38, GROUND_Y, 22),
		"Grave Digger's Stash",
		true, 10,
		false, ""
	)
	if digger_chest:
		digger_chest.setup_with_loot(LootTables.LootTier.UNCOMMON)

	# Chest in the charnel pit (dangerous location)
	var pit_chest := Chest.spawn_chest(
		self,
		Vector3(CHARNEL_PIT_CENTER.x + 10, CHARNEL_PIT_CENTER.y + 0.5, CHARNEL_PIT_CENTER.z),
		"Fallen Soldier's Cache",
		true, 14,
		false, ""
	)
	if pit_chest:
		pit_chest.setup_with_loot(LootTables.LootTier.RARE)

	# Chest hidden behind a burial mound (north)
	var hidden_chest := Chest.spawn_chest(
		self,
		Vector3(-30, GROUND_Y + 1.5, -32),
		"Ancient Burial Offering",
		true, 12,
		false, ""
	)
	if hidden_chest:
		hidden_chest.setup_with_loot(LootTables.LootTier.UNCOMMON)

	print("[BorderWarsGraveyard] Loot chests spawned")


## Create foggy, desolate atmosphere
func _create_atmosphere() -> void:
	# World environment for graveyard atmosphere
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.1)  # Dark gray-blue night
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.2, 0.25)  # Cold ambient
	env.ambient_light_energy = 0.4

	# Heavy fog for atmosphere and PS1 draw distance feel
	env.fog_enabled = true
	env.fog_light_color = Color(0.15, 0.15, 0.18)  # Gray-blue fog
	env.fog_density = 0.025  # Thick fog

	# Volumetric fog for extra atmosphere
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.1, 0.1, 0.12)

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	# Dim directional light (moonlight)
	var moon_light := DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.light_color = Color(0.6, 0.6, 0.8)  # Cold blue-white
	moon_light.light_energy = 0.5
	moon_light.shadow_enabled = true
	moon_light.rotation_degrees = Vector3(-45, 30, 0)
	add_child(moon_light)

	# Eerie glow from the charnel pit (green-purple)
	var pit_glow := OmniLight3D.new()
	pit_glow.name = "CharnelPitGlow"
	pit_glow.light_color = Color(0.3, 0.5, 0.4)  # Sickly green
	pit_glow.light_energy = 1.5
	pit_glow.omni_range = 20.0
	pit_glow.position = Vector3(CHARNEL_PIT_CENTER.x, CHARNEL_PIT_CENTER.y + 2, CHARNEL_PIT_CENTER.z)
	add_child(pit_glow)

	# Scattered dim lights (will-o-wisps / soul fire)
	_spawn_wisp_light(Vector3(-30, 2, 15), Color(0.4, 0.6, 0.8))
	_spawn_wisp_light(Vector3(25, 2, -20), Color(0.5, 0.4, 0.7))
	_spawn_wisp_light(Vector3(-20, 2, -35), Color(0.4, 0.7, 0.5))
	_spawn_wisp_light(Vector3(35, 2, 30), Color(0.6, 0.5, 0.8))

	print("[BorderWarsGraveyard] Atmosphere created")


func _spawn_wisp_light(pos: Vector3, color: Color) -> void:
	var wisp := OmniLight3D.new()
	wisp.name = "WispLight"
	wisp.light_color = color
	wisp.light_energy = 0.8
	wisp.omni_range = 8.0
	wisp.position = pos
	add_child(wisp)


## Create gore decorations and battlefield backdrop
func _create_gore_decorations() -> void:
	var gore_container := Node3D.new()
	gore_container.name = "GoreDecorations"
	add_child(gore_container)

	# Add battlefield background backdrop
	var backdrop_tex: Texture2D = load("res://Sprite folders grab bag/forgottenbattlefield_background2.png")
	if backdrop_tex:
		# Create backdrop sprites around the perimeter
		_create_battlefield_backdrop(gore_container, backdrop_tex, Vector3(0, 12, -55), 0.0)      # North
		_create_battlefield_backdrop(gore_container, backdrop_tex, Vector3(0, 12, 55), PI)        # South
		_create_battlefield_backdrop(gore_container, backdrop_tex, Vector3(-60, 12, 0), PI/2)     # West
		_create_battlefield_backdrop(gore_container, backdrop_tex, Vector3(60, 12, 0), -PI/2)     # East

	# Skull spike textures
	var skull_spike_textures: Array[Texture2D] = [
		load("res://Sprite folders grab bag/skulls_spike1.png"),
		load("res://Sprite folders grab bag/skulls_spike2.png"),
		load("res://Sprite folders grab bag/skulls_spike3.png"),
	]

	# Gore pile textures
	var gore_pile_textures: Array[Texture2D] = [
		load("res://Sprite folders grab bag/gore_pile1.png"),
		load("res://Sprite folders grab bag/gore_pile2.png"),
	]

	# Ghostly wraith decoration texture
	var wraith_tex: Texture2D = load("res://Sprite folders grab bag/undeadwraith_magic.png")

	# Skull spikes among the graves - ancient battlefield remnants
	var skull_spike_positions: Array[Vector3] = [
		Vector3(-35, GROUND_Y, -30),
		Vector3(35, GROUND_Y, -35),
		Vector3(-40, GROUND_Y, 15),
		Vector3(40, GROUND_Y, 20),
		Vector3(-20, GROUND_Y, -40),
		Vector3(15, GROUND_Y, 35),
		Vector3(0, GROUND_Y, -45),
		Vector3(-45, GROUND_Y, -10),
		Vector3(50, GROUND_Y, 5),
	]

	for i in skull_spike_positions.size():
		var pos: Vector3 = skull_spike_positions[i]
		var tex: Texture2D = skull_spike_textures[i % skull_spike_textures.size()]
		if tex:
			_spawn_gore_billboard(gore_container, pos, tex, "SkullSpike_%d" % i, 0.025)

	# Gore piles scattered among the battlefield dead
	var gore_pile_positions: Array[Vector3] = [
		Vector3(-30, GROUND_Y, -15),
		Vector3(25, GROUND_Y, -25),
		Vector3(-15, GROUND_Y, 30),
		Vector3(30, GROUND_Y, 15),
		Vector3(-25, GROUND_Y, 5),
		Vector3(15, GROUND_Y, -10),
	]

	for i in gore_pile_positions.size():
		var pos: Vector3 = gore_pile_positions[i]
		var tex: Texture2D = gore_pile_textures[i % gore_pile_textures.size()]
		if tex:
			_spawn_gore_billboard(gore_container, pos, tex, "GorePile_%d" % i, 0.02)

	# Ghostly wraith decorations - wandering spirits of the fallen
	if wraith_tex:
		var wraith_positions: Array[Vector3] = [
			Vector3(-35, GROUND_Y + 0.5, 25),
			Vector3(40, GROUND_Y + 0.5, -30),
			Vector3(-10, GROUND_Y + 0.5, -38),
			Vector3(20, GROUND_Y + 0.5, 38),
			Vector3(CHARNEL_PIT_CENTER.x + 12, CHARNEL_PIT_CENTER.y + 1.5, CHARNEL_PIT_CENTER.z),
			Vector3(CHARNEL_PIT_CENTER.x - 12, CHARNEL_PIT_CENTER.y + 1.5, CHARNEL_PIT_CENTER.z),
		]

		for i in wraith_positions.size():
			var pos: Vector3 = wraith_positions[i]
			_spawn_gore_billboard(gore_container, pos, wraith_tex, "GhostlyWraith_%d" % i, 0.04)

	print("[BorderWarsGraveyard] Spawned gore decorations - %d skull spikes, %d gore piles, wraith spirits" % [
		skull_spike_positions.size(),
		gore_pile_positions.size()
	])


## Create battlefield backdrop sprite
func _create_battlefield_backdrop(parent: Node3D, texture: Texture2D, pos: Vector3, rotation_y: float) -> void:
	var backdrop := Sprite3D.new()
	backdrop.name = "BattlefieldBackdrop"
	backdrop.texture = texture
	backdrop.pixel_size = 0.15
	backdrop.position = pos
	backdrop.rotation.y = rotation_y
	backdrop.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	backdrop.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	parent.add_child(backdrop)


## Spawn a gore billboard sprite decoration
func _spawn_gore_billboard(parent: Node3D, pos: Vector3, texture: Texture2D, billboard_name: String, pixel_size: float) -> void:
	var billboard := BillboardSprite.create_billboard(parent, texture, 1, 1, pixel_size, 0.0)
	billboard.name = billboard_name
	billboard.position = pos
