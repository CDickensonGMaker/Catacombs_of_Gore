## willow_dale.gd - Abandoned watchtower dungeon with undead
## Layout: Cemetery Exterior -> Tower Entry Hall -> Upper Floors (conceptual)
## Contains: Skeletons, Zombies, gravestones, ruined tower structure
extends Node3D

const ZONE_ID := "dungeon_willow_dale"

## Preloaded textures (more reliable than runtime load)
const MOSSY_STONE_TEX: Texture2D = preload("res://assets/textures/environment/walls/mossy stones.png")
const DIRT_FLOOR_TEX: Texture2D = preload("res://assets/textures/environment/floors/monastary_floor_outside1.png")

## Materials
var stone_floor_mat: StandardMaterial3D
var stone_wall_mat: StandardMaterial3D
var grass_mat: StandardMaterial3D
var dirt_mat: StandardMaterial3D
var gravestone_mat: StandardMaterial3D
var wood_mat: StandardMaterial3D
var mossy_stone_mat: StandardMaterial3D  ## For GLB model

## Terrain model
var terrain_model: Node3D

## Navigation
var nav_region: NavigationRegion3D


func _ready() -> void:
	# Check if we're the main scene (have Player) or a streamed cell
	var is_main_scene: bool = get_node_or_null("Player") != null

	# Set current region for world map tracking (only if main scene)
	if is_main_scene:
		if SceneManager:
			SceneManager.set_current_region(ZONE_ID)
		SaveManager.set_current_zone(ZONE_ID, "Willow Dale Watchtower")
		# Play ruins ambient and dungeon music
		AudioManager.play_zone_ambiance("ruins")
		AudioManager.play_zone_music("ruins")

	_create_materials()
	_load_terrain_model()
	_setup_navigation()
	_spawn_spawn_points()

	# Only spawn exit portal if this is the main scene, not a streamed cell
	if is_main_scene:
		_spawn_exit_portal()

	_spawn_undead()
	_spawn_cultists()
	_spawn_loot()
	_spawn_quest_objectives()
	_spawn_cursed_totem()
	_spawn_environmental_lore()
	_create_lighting()
	_setup_cell_streaming()

	# Quest triggers for entering willow dale (only if main scene)
	if is_main_scene:
		QuestManager.on_location_reached("willow_dale_entrance")
		QuestManager.on_location_reached("willow_dale")
		QuestManager.on_location_reached("willow_dale_depths")

	print("[WillowDale] Dungeon initialized!")


func _create_materials() -> void:
	# Mossy stone material for GLB model walls/structure
	mossy_stone_mat = StandardMaterial3D.new()
	mossy_stone_mat.albedo_texture = MOSSY_STONE_TEX
	mossy_stone_mat.uv1_scale = Vector3(2, 2, 1)
	mossy_stone_mat.roughness = 0.9
	mossy_stone_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mossy_stone_mat.vertex_color_use_as_albedo = false

	# Stone floor with dirt texture
	stone_floor_mat = StandardMaterial3D.new()
	stone_floor_mat.albedo_texture = DIRT_FLOOR_TEX
	stone_floor_mat.roughness = 0.95
	stone_floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	stone_floor_mat.vertex_color_use_as_albedo = false

	# Stone walls - same mossy texture
	stone_wall_mat = StandardMaterial3D.new()
	stone_wall_mat.albedo_texture = MOSSY_STONE_TEX
	stone_wall_mat.roughness = 0.9
	stone_wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	stone_wall_mat.vertex_color_use_as_albedo = false

	# Grass - dead, yellowed
	grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.25, 0.28, 0.15)
	grass_mat.roughness = 0.95
	grass_mat.vertex_color_use_as_albedo = false

	# Dirt - dark brown with texture
	dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_texture = DIRT_FLOOR_TEX
	dirt_mat.roughness = 0.98
	dirt_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	dirt_mat.vertex_color_use_as_albedo = false

	# Gravestones - weathered gray stone
	gravestone_mat = StandardMaterial3D.new()
	gravestone_mat.albedo_color = Color(0.35, 0.33, 0.32)
	gravestone_mat.roughness = 0.85
	gravestone_mat.vertex_color_use_as_albedo = false

	# Rotting wood
	wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.2, 0.15, 0.1)
	wood_mat.roughness = 0.9
	wood_mat.vertex_color_use_as_albedo = false


## Load the willow_dale.glb terrain model and add mesh collision
func _load_terrain_model() -> void:
	# Check if terrain model already exists in scene (placed in .tscn)
	var terrain_container: Node3D = get_node_or_null("Terrain")
	if terrain_container:
		terrain_model = terrain_container.get_node_or_null("TerrainModel")

	if not terrain_model:
		# Try to load dynamically if not in scene
		var glb_scene: PackedScene = load("res://assets/models/terrain/willow_dale.glb")
		if not glb_scene:
			push_error("[WillowDale] Failed to load willow_dale.glb")
			return

		terrain_model = glb_scene.instantiate()
		terrain_model.name = "TerrainModel"
		if terrain_container:
			terrain_container.add_child(terrain_model)
		else:
			add_child(terrain_model)

	# Apply materials and collision to all meshes
	print("[WillowDale] Applying texture: %s (valid: %s)" % [MOSSY_STONE_TEX, MOSSY_STONE_TEX != null])
	_process_model_meshes(terrain_model)


## Mesh naming conventions for collision control:
## - "_nocol" suffix: No collision (e.g., "Vines_nocol")
## - "collision" or "walkable" in name: Collision-only mesh (invisible)
const NO_COLLISION_SUFFIX := "_nocol"
const COLLISION_ONLY_NAMES := ["collision", "walkable", "colonly"]

## Recursively process all meshes in the model to add collision and materials
func _process_model_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var mesh_name: String = mesh_instance.name.to_lower()

		# Check if this is a collision-only mesh (hide visual, keep collision)
		var is_collision_only: bool = false
		for col_name in COLLISION_ONLY_NAMES:
			if mesh_name.contains(col_name):
				is_collision_only = true
				break

		# Check if this mesh should be skipped for collision
		var skip_collision: bool = mesh_name.ends_with(NO_COLLISION_SUFFIX.to_lower())

		# Apply material (unless collision-only mesh which should be invisible)
		if is_collision_only:
			mesh_instance.visible = false
		elif mesh_instance.mesh:
			# GLB embedded materials override material_override
			# Force our texture by duplicating mesh and setting surface materials
			var unique_mesh: Mesh = mesh_instance.mesh.duplicate()
			for i in range(unique_mesh.get_surface_count()):
				unique_mesh.surface_set_material(i, mossy_stone_mat)
			mesh_instance.mesh = unique_mesh

		# Create collision unless explicitly marked _nocol
		if not skip_collision and mesh_instance.mesh:
			var static_body := StaticBody3D.new()
			static_body.name = mesh_instance.name + "_Collision"
			static_body.collision_layer = 1
			static_body.collision_mask = 0

			var shape := mesh_instance.mesh.create_trimesh_shape()
			if shape:
				var collision_shape := CollisionShape3D.new()
				collision_shape.shape = shape
				static_body.add_child(collision_shape)
				mesh_instance.add_sibling(static_body)
				static_body.global_transform = mesh_instance.global_transform

	# Process children recursively
	for child in node.get_children():
		_process_model_meshes(child)


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
	if portal:
		portal.rotation.y = PI  # Face into the dungeon
		portal.show_frame = false  # No door frame for outdoor exit
		print("[WillowDale] Spawned exit portal")


## ============================================================================
## SKELETON SHADE SPAWNS - Soul Shades haunt these cursed ruins
## ============================================================================

func _spawn_undead() -> void:
	_spawn_cemetery_shades()
	_spawn_tower_shades()


## Cemetery area - shades wandering among the graves
func _spawn_cemetery_shades() -> void:
	_spawn_skeleton_shade(Vector3(-10, 0, 35))
	_spawn_skeleton_shade(Vector3(12, 0, 40))
	_spawn_skeleton_shade(Vector3(-16, 0, 25))
	_spawn_skeleton_shade(Vector3(0, 0, 30))
	_spawn_skeleton_shade(Vector3(-5, 0, 20))


## Tower interior - more shades guarding the depths
func _spawn_tower_shades() -> void:
	_spawn_skeleton_shade(Vector3(-4, 0, 0))
	_spawn_skeleton_shade(Vector3(5, 0, -3))
	_spawn_skeleton_shade(Vector3(0, 0, -6))
	_spawn_skeleton_shade(Vector3(3, 0, 2))
	_spawn_skeleton_shade(Vector3(-2, 0, -10))


## Helper: Spawn a skeleton shade enemy
func _spawn_skeleton_shade(pos: Vector3) -> void:
	var data_path := "res://data/enemies/skeleton_shade.tres"

	# Check ActorRegistry first for sprite config
	var sprite_config: Dictionary = ActorRegistry.get_sprite_config("skeleton_shade")

	var sprite_path: String
	var h_frames: int
	var v_frames: int

	if not sprite_config.is_empty():
		sprite_path = sprite_config.get("sprite_path", "")
		h_frames = sprite_config.get("h_frames", 4)
		v_frames = sprite_config.get("v_frames", 1)
	else:
		# Fall back to defaults
		sprite_path = "res://assets/sprites/enemies/undead/skeleton_shade_walking.png"
		h_frames = 4
		v_frames = 1

	var sprite: Texture2D = load(sprite_path)
	if not sprite:
		push_warning("[WillowDale] Missing skeleton shade sprite: %s" % sprite_path)
		return

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		data_path,
		sprite,
		h_frames,
		v_frames
	)
	if enemy:
		enemy.add_to_group("willow_dale_undead")
		enemy.add_to_group("skeleton_shade")
		print("[WillowDale] Spawned skeleton shade at %s" % pos)


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

	# Check if we're being run directly (F6) for testing vs through normal game flow
	# SceneManager.has_transitioned is true if a scene was loaded through normal game flow
	if not SceneManager.has_transitioned:
		print("[%s] Direct scene test mode - skipping cell streaming" % ZONE_ID)
		return

	# Use WorldGrid location_id (may differ from ZONE_ID for save compatibility)
	var my_coords: Vector2i = WorldGrid.get_location_coords("willow_dale")
	CellStreamer.register_main_scene_cell(my_coords, self)
	CellStreamer.start_streaming(my_coords)
	print("[%s] Registered as main scene, streaming started at %s" % [ZONE_ID, my_coords])


## ============================================================================
## CULTIST SPAWNS - For keepers_initiation quest
## ============================================================================

func _spawn_cultists() -> void:
	# 5+ cultists for the keepers_initiation quest "defeat_cultists" objective
	# Cultists are performing a dark ritual near the altar inside the tower

	# Cultists around the altar area (tower interior)
	_spawn_cultist(Vector3(0, 0, -3))    # At altar
	_spawn_cultist(Vector3(-3, 0, -2))   # Left of altar
	_spawn_cultist(Vector3(3, 0, -2))    # Right of altar
	_spawn_cultist(Vector3(-2, 0, 1))    # Front left
	_spawn_cultist(Vector3(2, 0, 1))     # Front right

	# Cult leader near the altar
	_spawn_cult_leader(Vector3(0, 0, -5))

	print("[WillowDale] Spawned cultists for keepers_initiation quest")


## Helper: Spawn a cultist enemy
func _spawn_cultist(pos: Vector3) -> void:
	var data_path := "res://data/enemies/cultist.tres"

	# Extract enemy type ID from path
	var enemy_type: String = data_path.get_file().get_basename()

	# Check ActorRegistry first for sprite config
	var sprite_config: Dictionary = ActorRegistry.get_sprite_config(enemy_type)

	var sprite_path: String
	var h_frames: int
	var v_frames: int

	if not sprite_config.is_empty():
		sprite_path = sprite_config.get("sprite_path", "")
		h_frames = sprite_config.get("h_frames", 3)
		v_frames = sprite_config.get("v_frames", 1)
	else:
		# Fall back to defaults
		sprite_path = "res://assets/sprites/enemies/humanoid/cultist_red.png"
		h_frames = 3
		v_frames = 1

	var sprite: Texture2D = load(sprite_path)
	if not sprite:
		push_warning("[WillowDale] Missing cultist sprite")
		return

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		data_path,
		sprite,
		h_frames,
		v_frames
	)
	if enemy:
		enemy.add_to_group("willow_dale_cultists")
		enemy.add_to_group("cultist")  # For quest objective tracking
		print("[WillowDale] Spawned cultist at %s" % pos)


## Helper: Spawn the cult leader (mini-boss)
func _spawn_cult_leader(pos: Vector3) -> void:
	var data_path := "res://data/enemies/cult_leader.tres"

	# Extract enemy type ID from path
	var enemy_type: String = data_path.get_file().get_basename()

	# Check ActorRegistry first for sprite config
	var sprite_config: Dictionary = ActorRegistry.get_sprite_config(enemy_type)

	var sprite_path: String
	var h_frames: int
	var v_frames: int

	if not sprite_config.is_empty():
		sprite_path = sprite_config.get("sprite_path", "")
		h_frames = sprite_config.get("h_frames", 5)
		v_frames = sprite_config.get("v_frames", 1)
	else:
		# Fall back to defaults
		sprite_path = "res://assets/sprites/enemies/undead/vampire_lord_walk.png"
		h_frames = 5
		v_frames = 1

	var sprite: Texture2D = load(sprite_path)
	if not sprite:
		push_warning("[WillowDale] Missing cult leader sprite")
		return

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		data_path,
		sprite,
		h_frames,
		v_frames
	)
	if enemy:
		enemy.add_to_group("willow_dale_cultists")
		enemy.add_to_group("cultist")
		enemy.add_to_group("bosses")
		print("[WillowDale] Spawned Cult Leader at %s" % pos)


## ============================================================================
## QUEST OBJECTIVES - Interactables and collectibles for various quests
## ============================================================================

func _spawn_quest_objectives() -> void:
	# --- WILLOW_DALE_INVESTIGATION QUEST ---

	# Wrecked caravan near the cemetery entrance
	_spawn_wrecked_caravan(Vector3(15, 0, 48))

	# 3x merchant goods scattered around the area
	_spawn_merchant_goods(Vector3(14, 0, 46))
	_spawn_merchant_goods(Vector3(18, 0, 50))
	_spawn_merchant_goods(Vector3(12, 0, 52))

	# --- LOST_APPRENTICE QUEST ---

	# Apprentice belongings (satchel) near cemetery entrance
	_spawn_apprentice_belongings(Vector3(-10, 0, 45))

	# Apprentice Marcus body inside tower (tragic end)
	_spawn_apprentice_marcus(Vector3(4, 0, -5))

	# --- KEEPERS_INITIATION QUEST ---

	# Dark altar inside the tower (cultist ritual site)
	_spawn_willow_dale_altar(Vector3(0, 0, -7))

	print("[WillowDale] Spawned quest objectives")


## Spawn wrecked caravan for willow_dale_investigation quest
func _spawn_wrecked_caravan(pos: Vector3) -> void:
	var caravan := Node3D.new()
	caravan.name = "wrecked_caravan"
	caravan.position = pos
	caravan.add_to_group("interactable")
	caravan.set_meta("object_id", "wrecked_caravan")
	caravan.set_meta("display_name", "Wrecked Caravan")
	caravan.set_meta("interaction_type", "examine")
	add_child(caravan)

	# Broken cart body
	var cart := CSGBox3D.new()
	cart.name = "CartBody"
	cart.size = Vector3(3.0, 1.0, 2.0)
	cart.position = Vector3(0, 0.5, 0)
	cart.rotation_degrees.z = 15  # Tilted as if crashed
	cart.material = wood_mat
	cart.use_collision = true
	caravan.add_child(cart)

	# Broken wheel nearby
	var wheel := CSGCylinder3D.new()
	wheel.name = "BrokenWheel"
	wheel.radius = 0.5
	wheel.height = 0.15
	wheel.sides = 8
	wheel.position = Vector3(2.5, 0.1, 1.0)
	wheel.rotation_degrees.x = 90
	wheel.rotation_degrees.z = 25
	wheel.material = wood_mat
	wheel.use_collision = true
	caravan.add_child(wheel)

	# Interaction area
	var area := Area3D.new()
	area.name = "InteractionArea"
	area.collision_layer = 256
	area.collision_mask = 0
	var area_col := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = 3.0
	area_col.shape = area_shape
	area_col.position.y = 1.0
	area.add_child(area_col)
	caravan.add_child(area)

	# Connect to quest system when examined
	area.area_entered.connect(_on_caravan_examined)

	print("[WillowDale] Spawned wrecked caravan at %s" % pos)


func _on_caravan_examined(_area: Area3D) -> void:
	QuestManager.on_interact("wrecked_caravan")


## Spawn merchant goods collectible
func _spawn_merchant_goods(pos: Vector3) -> void:
	# Use WorldItem for collectibles - automatically triggers quest progress
	var goods := WorldItem.spawn_item(
		self,
		pos,
		"merchant_goods",
		Enums.ItemQuality.AVERAGE,
		1
	)
	if goods:
		goods.add_to_group("quest_items")
		print("[WillowDale] Spawned merchant goods at %s" % pos)


## Spawn apprentice belongings (satchel) for lost_apprentice quest
func _spawn_apprentice_belongings(pos: Vector3) -> void:
	var belongings := StaticBody3D.new()
	belongings.name = "apprentice_belongings"
	belongings.position = pos
	belongings.add_to_group("interactable")
	belongings.set_meta("object_id", "apprentice_belongings")
	belongings.set_meta("display_name", "Apprentice's Satchel")
	belongings.set_meta("interaction_type", "examine")
	add_child(belongings)

	# Satchel mesh
	var satchel := CSGBox3D.new()
	satchel.name = "SatchelMesh"
	satchel.size = Vector3(0.4, 0.3, 0.2)
	satchel.position = Vector3(0, 0.15, 0)
	var satchel_mat := StandardMaterial3D.new()
	satchel_mat.albedo_color = Color(0.4, 0.3, 0.2)
	satchel_mat.roughness = 0.9
	satchel.material = satchel_mat
	satchel.use_collision = true
	belongings.add_child(satchel)

	# Scattered papers
	var papers := CSGBox3D.new()
	papers.name = "Papers"
	papers.size = Vector3(0.5, 0.02, 0.3)
	papers.position = Vector3(0.3, 0.01, 0.2)
	papers.rotation_degrees.y = 25
	var paper_mat := StandardMaterial3D.new()
	paper_mat.albedo_color = Color(0.85, 0.82, 0.75)
	papers.material = paper_mat
	belongings.add_child(papers)

	# Collision shape
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.4, 0.3)
	collision.shape = shape
	collision.position.y = 0.2
	belongings.add_child(collision)

	# Interaction area
	var area := Area3D.new()
	area.name = "InteractionArea"
	area.collision_layer = 256
	area.collision_mask = 0
	var area_col := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = 2.0
	area_col.shape = area_shape
	area_col.position.y = 0.3
	area.add_child(area_col)
	belongings.add_child(area)

	area.area_entered.connect(_on_belongings_examined)

	print("[WillowDale] Spawned apprentice belongings at %s" % pos)


func _on_belongings_examined(_area: Area3D) -> void:
	QuestManager.on_interact("apprentice_belongings")


## Spawn apprentice Marcus (body) for lost_apprentice quest
func _spawn_apprentice_marcus(pos: Vector3) -> void:
	var marcus := StaticBody3D.new()
	marcus.name = "apprentice_marcus"
	marcus.position = pos
	marcus.add_to_group("interactable")
	marcus.set_meta("object_id", "apprentice_marcus")
	marcus.set_meta("display_name", "Apprentice Marcus")
	marcus.set_meta("interaction_type", "examine")
	marcus.set_meta("npc_type", "apprentice_marcus")
	add_child(marcus)

	# Body mesh (simplified prone figure)
	var body := CSGBox3D.new()
	body.name = "BodyMesh"
	body.size = Vector3(0.5, 0.2, 1.5)
	body.position = Vector3(0, 0.1, 0)
	body.rotation_degrees.y = 35  # Angled
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.3, 0.25, 0.35)  # Dark robes
	body_mat.roughness = 0.9
	body.material = body_mat
	body.use_collision = true
	marcus.add_child(body)

	# Staff nearby
	var staff := CSGCylinder3D.new()
	staff.name = "Staff"
	staff.radius = 0.04
	staff.height = 1.8
	staff.sides = 6
	staff.position = Vector3(0.5, 0.04, 0.3)
	staff.rotation_degrees.z = 85
	staff.material = wood_mat
	marcus.add_child(staff)

	# Collision shape
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.3, 1.6)
	collision.shape = shape
	collision.position.y = 0.15
	marcus.add_child(collision)

	# Interaction area
	var area := Area3D.new()
	area.name = "InteractionArea"
	area.collision_layer = 256
	area.collision_mask = 0
	var area_col := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = 2.0
	area_col.shape = area_shape
	area_col.position.y = 0.5
	area.add_child(area_col)
	marcus.add_child(area)

	area.area_entered.connect(_on_marcus_examined)

	print("[WillowDale] Spawned apprentice Marcus at %s" % pos)


func _on_marcus_examined(_area: Area3D) -> void:
	QuestManager.on_interact("apprentice_marcus")


## Spawn the dark altar for keepers_initiation quest
func _spawn_willow_dale_altar(pos: Vector3) -> void:
	var altar := StaticBody3D.new()
	altar.name = "willow_dale_altar"
	altar.position = pos
	altar.add_to_group("interactable")
	altar.set_meta("object_id", "willow_dale_altar")
	altar.set_meta("display_name", "Dark Altar")
	altar.set_meta("interaction_type", "examine")
	add_child(altar)

	# Altar base (stone slab)
	var base := CSGBox3D.new()
	base.name = "AltarBase"
	base.size = Vector3(3.0, 0.8, 2.0)
	base.position = Vector3(0, 0.4, 0)
	var altar_mat := StandardMaterial3D.new()
	altar_mat.albedo_color = Color(0.15, 0.12, 0.1)  # Dark stone
	altar_mat.roughness = 0.95
	base.material = altar_mat
	base.use_collision = true
	altar.add_child(base)

	# Altar top slab
	var top := CSGBox3D.new()
	top.name = "AltarTop"
	top.size = Vector3(2.5, 0.15, 1.5)
	top.position = Vector3(0, 0.88, 0)
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.2, 0.1, 0.1)  # Blood-stained dark
	top_mat.roughness = 0.8
	top.material = top_mat
	top.use_collision = true
	altar.add_child(top)

	# Candles/ritual objects
	for i in range(4):
		var candle := CSGCylinder3D.new()
		candle.name = "Candle_%d" % i
		candle.radius = 0.05
		candle.height = 0.25
		candle.sides = 6
		var candle_pos: Vector3 = Vector3(
			-0.8 + (i % 2) * 1.6,
			1.0,
			-0.5 + (i / 2) * 1.0
		)
		candle.position = candle_pos
		var candle_mat := StandardMaterial3D.new()
		candle_mat.albedo_color = Color(0.9, 0.85, 0.7)
		candle.material = candle_mat
		altar.add_child(candle)

	# Eerie glow from altar
	var glow := OmniLight3D.new()
	glow.name = "AltarGlow"
	glow.light_color = Color(0.5, 0.2, 0.3)  # Dark red glow
	glow.light_energy = 1.5
	glow.omni_range = 6.0
	glow.position = Vector3(0, 1.5, 0)
	altar.add_child(glow)

	# Collision shape
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.2, 1.0, 2.2)
	collision.shape = shape
	collision.position.y = 0.5
	altar.add_child(collision)

	# Interaction area
	var area := Area3D.new()
	area.name = "InteractionArea"
	area.collision_layer = 256
	area.collision_mask = 0
	var area_col := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = 3.0
	area_col.shape = area_shape
	area_col.position.y = 1.0
	area.add_child(area_col)
	altar.add_child(area)

	area.area_entered.connect(_on_altar_examined)

	print("[WillowDale] Spawned dark altar at %s" % pos)


func _on_altar_examined(_area: Area3D) -> void:
	QuestManager.on_interact("willow_dale_altar")


## ============================================================================
## CURSED TOTEM - For bounty_undead_rising quest
## ============================================================================

## Spawn the cursed totem that powers the undead
func _spawn_cursed_totem() -> void:
	# Position near the altar/tower area where skeleton shades patrol
	var totem_pos := Vector3(0, 0, -12)

	var totem := StaticBody3D.new()
	totem.name = "cursed_totem"
	totem.position = totem_pos
	totem.add_to_group("interactable")
	totem.add_to_group("destructible")
	totem.set_meta("object_id", "cursed_totem")
	totem.set_meta("display_name", "Cursed Totem")
	totem.set_meta("interaction_type", "destroy")
	totem.set_meta("hp", 50)
	totem.set_meta("max_hp", 50)
	add_child(totem)

	# Totem pillar - tall dark stone
	var pillar := CSGCylinder3D.new()
	pillar.name = "TotemPillar"
	pillar.radius = 0.4
	pillar.height = 2.5
	pillar.sides = 8
	pillar.position = Vector3(0, 1.25, 0)
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.1, 0.08, 0.12)  # Very dark purple-black
	pillar_mat.roughness = 0.95
	pillar_mat.emission_enabled = true
	pillar_mat.emission = Color(0.3, 0.1, 0.4)  # Faint purple glow
	pillar_mat.emission_energy_multiplier = 0.5
	pillar.material = pillar_mat
	pillar.use_collision = true
	totem.add_child(pillar)

	# Skull on top
	var skull := CSGSphere3D.new()
	skull.name = "TotemSkull"
	skull.radius = 0.35
	skull.radial_segments = 8
	skull.rings = 4
	skull.position = Vector3(0, 2.7, 0)
	var skull_mat := StandardMaterial3D.new()
	skull_mat.albedo_color = Color(0.85, 0.8, 0.7)  # Bone color
	skull_mat.roughness = 0.9
	skull_mat.emission_enabled = true
	skull_mat.emission = Color(0.5, 0.2, 0.1)  # Faint red glow in eye sockets
	skull_mat.emission_energy_multiplier = 0.8
	skull.material = skull_mat
	totem.add_child(skull)

	# Dark runes on base
	var base := CSGBox3D.new()
	base.name = "TotemBase"
	base.size = Vector3(1.0, 0.3, 1.0)
	base.position = Vector3(0, 0.15, 0)
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.08, 0.06, 0.1)
	base_mat.roughness = 0.98
	base.material = base_mat
	base.use_collision = true
	totem.add_child(base)

	# Eerie purple light emanating from totem
	var totem_light := OmniLight3D.new()
	totem_light.name = "TotemGlow"
	totem_light.light_color = Color(0.5, 0.2, 0.6)  # Purple
	totem_light.light_energy = 1.2
	totem_light.omni_range = 8.0
	totem_light.position = Vector3(0, 2.0, 0)
	totem.add_child(totem_light)

	# Collision shape
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 2.8
	collision.shape = shape
	collision.position.y = 1.4
	totem.add_child(collision)

	# Interaction area
	var area := Area3D.new()
	area.name = "InteractionArea"
	area.collision_layer = 256  # Interactable layer
	area.collision_mask = 0
	var area_col := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = 2.5
	area_col.shape = area_shape
	area_col.position.y = 1.5
	area.add_child(area_col)
	totem.add_child(area)

	# Connect interaction
	area.area_entered.connect(_on_totem_area_entered)

	print("[WillowDale] Spawned cursed totem at %s" % totem_pos)


func _on_totem_area_entered(_area: Area3D) -> void:
	# When player gets close, they can interact to destroy
	# The actual destruction is handled by the interaction system
	pass


## Called when totem is destroyed (by combat system or interaction)
func _on_totem_destroyed() -> void:
	# Trigger quest objective completion
	QuestManager.on_interact("cursed_totem")
	print("[WillowDale] Cursed totem destroyed!")


## ============================================================================
## ENVIRONMENTAL LORE - Tombstones, symbols, readable objects
## ============================================================================

## Spawn environmental storytelling elements
func _spawn_environmental_lore() -> void:
	# Readable tombstones with lore about the Keepers
	_spawn_tombstone(Vector3(-12, 0, 38), "watchman_tomb_1",
		"HERE LIES WARDEN ALDETH\nWho stood watch through the Long Night\nMay the Eye see forever")

	_spawn_tombstone(Vector3(-8, 0, 42), "watchman_tomb_2",
		"FALLEN AT THEIR POST\nThe Last Watchers of Willow Dale\nTheir vigil ended, ours begins")

	_spawn_tombstone(Vector3(10, 0, 36), "watchman_tomb_3",
		"IN MEMORY OF SISTER IRENA\nShe saw what others could not\nThe veil is thin, the watchers few")

	# Ancient Keeper symbol carved in stone near the tower
	_spawn_keeper_symbol(Vector3(-2, 0, 5))

	# Lore item pickup - a tattered journal page
	_spawn_lore_item(Vector3(5, 0, -2), "watchers_journal_page",
		"Watcher's Journal Fragment",
		"...the signs grow more troubling. The wards we placed centuries ago are failing. Something stirs beneath the old stones, something that remembers when there was no Empire, no kingdoms - only the darkness and those who fed upon it. We Keepers have watched too long to be fooled. The cultists think they summon power, but they summon only their own doom. When the barrier breaks, nothing will save them - or us...")

	print("[WillowDale] Spawned environmental lore elements")


## Spawn a readable tombstone with lore text
func _spawn_tombstone(pos: Vector3, tomb_id: String, inscription: String) -> void:
	var tombstone := StaticBody3D.new()
	tombstone.name = tomb_id
	tombstone.position = pos
	tombstone.add_to_group("interactable")
	tombstone.set_meta("object_id", tomb_id)
	tombstone.set_meta("display_name", "Tombstone")
	tombstone.set_meta("interaction_type", "read")
	tombstone.set_meta("readable_text", inscription)
	add_child(tombstone)

	# Tombstone mesh - simple weathered stone slab
	var stone := CSGBox3D.new()
	stone.name = "TombstoneMesh"
	stone.size = Vector3(0.8, 1.2, 0.2)
	stone.position = Vector3(0, 0.6, 0)
	stone.rotation_degrees.x = -5  # Slightly leaning
	stone.material = gravestone_mat
	stone.use_collision = true
	tombstone.add_child(stone)

	# Collision shape
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 1.3, 0.3)
	collision.shape = shape
	collision.position.y = 0.65
	tombstone.add_child(collision)


## Spawn the ancient Keeper symbol carved in stone
func _spawn_keeper_symbol(pos: Vector3) -> void:
	var symbol := StaticBody3D.new()
	symbol.name = "keeper_symbol"
	symbol.position = pos
	symbol.add_to_group("interactable")
	symbol.set_meta("object_id", "keeper_symbol")
	symbol.set_meta("display_name", "Ancient Symbol")
	symbol.set_meta("interaction_type", "examine")
	symbol.set_meta("readable_text", "An eye within a circle of stars is carved into the stone. The symbol is weathered but still clear - the mark of some ancient order. Around it are inscribed words in an old tongue: 'We who watch. We who remember. We who guard the threshold.'")
	add_child(symbol)

	# Symbol base - circular stone slab embedded in floor
	var base := CSGCylinder3D.new()
	base.name = "SymbolBase"
	base.radius = 0.8
	base.height = 0.1
	base.sides = 12
	base.position = Vector3(0, 0.05, 0)
	var symbol_mat := StandardMaterial3D.new()
	symbol_mat.albedo_color = Color(0.25, 0.23, 0.28)
	symbol_mat.emission_enabled = true
	symbol_mat.emission = Color(0.2, 0.15, 0.3)
	symbol_mat.emission_energy_multiplier = 0.3
	base.material = symbol_mat
	base.use_collision = true
	symbol.add_child(base)

	# Faint mystical glow
	var glow := OmniLight3D.new()
	glow.name = "SymbolGlow"
	glow.light_color = Color(0.4, 0.3, 0.6)
	glow.light_energy = 0.4
	glow.omni_range = 3.0
	glow.position = Vector3(0, 0.5, 0)
	symbol.add_child(glow)


## Spawn a lore item (journal page, note, etc.)
func _spawn_lore_item(pos: Vector3, item_id: String, display_name: String, lore_text: String) -> void:
	var item := StaticBody3D.new()
	item.name = item_id
	item.position = pos
	item.add_to_group("interactable")
	item.set_meta("object_id", item_id)
	item.set_meta("display_name", display_name)
	item.set_meta("interaction_type", "pickup")
	item.set_meta("lore_text", lore_text)
	item.set_meta("is_lore_item", true)
	add_child(item)

	# Paper/parchment visual
	var paper := CSGBox3D.new()
	paper.name = "PaperMesh"
	paper.size = Vector3(0.3, 0.02, 0.4)
	paper.position = Vector3(0, 0.01, 0)
	paper.rotation_degrees.y = randf_range(-30, 30)
	var paper_mat := StandardMaterial3D.new()
	paper_mat.albedo_color = Color(0.85, 0.80, 0.65)
	paper_mat.roughness = 0.95
	paper.material = paper_mat
	item.add_child(paper)

	# Interaction area
	var area := Area3D.new()
	area.name = "InteractionArea"
	area.collision_layer = 256
	area.collision_mask = 0
	var area_col := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = 1.5
	area_col.shape = area_shape
	area_col.position.y = 0.3
	area.add_child(area_col)
	item.add_child(area)
