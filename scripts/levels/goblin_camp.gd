## goblin_camp.gd - Goblin Camp (spawns randomly at different locations)
## A crude goblin encampment with 13-17 goblins and 1 warboss
## Used for goblin_camp_southwest, goblin_camp_south, goblin_camp_west
extends Node3D

const ZONE_ID := "goblin_camp"

## Preloaded textures
const GROUND_TEX: Texture2D = preload("res://assets/textures/environment/floors/monastary_floor_outside1.png")

## Materials
var ground_mat: StandardMaterial3D

## Navigation
var nav_region: NavigationRegion3D

## Terrain model
var terrain_model: Node3D


func _ready() -> void:
	var is_main_scene: bool = get_node_or_null("Player") != null

	if is_main_scene:
		if SceneManager:
			SceneManager.set_current_region(ZONE_ID)
		SaveManager.set_current_zone(ZONE_ID, "Goblin Camp")

	_create_materials()
	_load_terrain_model()
	_setup_navigation()
	_spawn_spawn_points()

	if is_main_scene:
		_spawn_exit_portal()

	_spawn_goblins()
	_spawn_loot()
	_create_lighting()
	_setup_cell_streaming()

	if is_main_scene:
		QuestManager.on_location_reached("goblin_camp")
		DayNightCycle.add_to_level(self)

	print("[GoblinCamp] Camp initialized!")


func _create_materials() -> void:
	ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_texture = GROUND_TEX
	ground_mat.uv1_scale = Vector3(4, 4, 1)
	ground_mat.roughness = 0.95
	ground_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ground_mat.vertex_color_use_as_albedo = false


func _load_terrain_model() -> void:
	var glb_scene: PackedScene = load("res://assets/models/terrain/goblin_camp.glb")
	if not glb_scene:
		push_error("[GoblinCamp] Failed to load goblin_camp.glb")
		return

	terrain_model = glb_scene.instantiate()
	terrain_model.name = "TerrainModel"
	add_child(terrain_model)

	# Apply materials and collision to all meshes
	_process_model_meshes(terrain_model)


## Mesh naming conventions for collision control
const NO_COLLISION_SUFFIX := "_nocol"
const COLLISION_ONLY_NAMES := ["collision", "walkable", "colonly"]

func _process_model_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var mesh_name: String = mesh_instance.name.to_lower()

		var is_collision_only: bool = false
		for col_name in COLLISION_ONLY_NAMES:
			if mesh_name.contains(col_name):
				is_collision_only = true
				break

		var skip_collision: bool = mesh_name.ends_with(NO_COLLISION_SUFFIX.to_lower())

		if is_collision_only:
			mesh_instance.visible = false
		elif mesh_instance.mesh:
			# Apply ground material to floor meshes
			if mesh_name.contains("floor") or mesh_name.contains("ground"):
				var unique_mesh: Mesh = mesh_instance.mesh.duplicate()
				for i in range(unique_mesh.get_surface_count()):
					unique_mesh.surface_set_material(i, ground_mat)
				mesh_instance.mesh = unique_mesh

		# Create collision
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
		print("[GoblinCamp] Navigation mesh baked!")


## ============================================================================
## SPAWN POINTS
## ============================================================================

func _spawn_spawn_points() -> void:
	var from_world := Node3D.new()
	from_world.name = "from_open_world"
	from_world.position = Vector3(0, 1.0, 45)
	from_world.add_to_group("spawn_points")
	from_world.set_meta("spawn_id", "from_open_world")
	add_child(from_world)

	var default_spawn := Node3D.new()
	default_spawn.name = "default_spawn"
	default_spawn.position = Vector3(0, 1.0, 45)
	default_spawn.add_to_group("spawn_points")
	default_spawn.set_meta("spawn_id", "default")
	add_child(default_spawn)

	print("[GoblinCamp] Spawn points created")


func _spawn_exit_portal() -> void:
	var portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, 0, 48),
		SceneManager.RETURN_TO_WILDERNESS,
		"from_goblin_camp",
		"Exit to Wilderness"
	)
	if portal:
		portal.rotation.y = PI
		portal.show_frame = false
		print("[GoblinCamp] Spawned exit portal")


## ============================================================================
## GOBLIN SPAWNS - 13-17 goblins + 1 warboss
## ============================================================================

func _spawn_goblins() -> void:
	# Determine random goblin count (13-17)
	var goblin_count: int = randi_range(13, 17)

	# Spawn positions spread around camp
	var spawn_positions: Array[Vector3] = [
		# Perimeter guards
		Vector3(-12, 0, 30),
		Vector3(12, 0, 30),
		Vector3(-15, 0, 15),
		Vector3(15, 0, 15),
		Vector3(-10, 0, 5),
		Vector3(10, 0, 5),
		# Camp interior
		Vector3(-5, 0, 20),
		Vector3(5, 0, 20),
		Vector3(0, 0, 15),
		Vector3(-8, 0, 10),
		Vector3(8, 0, 10),
		Vector3(-3, 0, 8),
		Vector3(3, 0, 8),
		Vector3(0, 0, 5),
		Vector3(-6, 0, 3),
		Vector3(6, 0, 3),
		Vector3(0, 0, 0),
	]

	# Shuffle and take the required count
	spawn_positions.shuffle()

	var spawned: int = 0
	for i in range(mini(goblin_count, spawn_positions.size())):
		var enemy_type := _get_random_goblin_type()
		_spawn_goblin(spawn_positions[i], enemy_type)
		spawned += 1

	print("[GoblinCamp] Spawned %d goblins" % spawned)

	# Spawn warboss at camp center
	_spawn_goblin_warboss(Vector3(0, 0, -5))


## Get random goblin type (soldier/archer/mage distribution)
func _get_random_goblin_type() -> String:
	var roll: float = randf()
	if roll < 0.5:
		return "goblin_soldier"  # 50% soldiers
	elif roll < 0.8:
		return "goblin_archer"   # 30% archers
	else:
		return "goblin_mage"     # 20% mages


## Spawn a goblin of specified type
func _spawn_goblin(pos: Vector3, goblin_type: String) -> void:
	var data_path := "res://data/enemies/%s.tres" % goblin_type

	var sprite_config: Dictionary = ActorRegistry.get_sprite_config(goblin_type)

	var sprite_path: String
	var h_frames: int
	var v_frames: int

	if not sprite_config.is_empty():
		sprite_path = sprite_config.get("sprite_path", "")
		h_frames = sprite_config.get("h_frames", 4)
		v_frames = sprite_config.get("v_frames", 1)
	else:
		# Fallback defaults
		sprite_path = "res://assets/sprites/enemies/goblins/goblin_sword.png"
		h_frames = 4
		v_frames = 2

	var sprite: Texture2D = load(sprite_path)
	if not sprite:
		push_warning("[GoblinCamp] Missing goblin sprite: %s" % sprite_path)
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
		enemy.add_to_group("goblin_camp_enemies")
		enemy.add_to_group(goblin_type)


## Spawn the goblin warboss at camp center
func _spawn_goblin_warboss(pos: Vector3) -> void:
	var data_path := "res://data/enemies/goblin_warboss.tres"

	var sprite_config: Dictionary = ActorRegistry.get_sprite_config("goblin_warboss")

	var sprite_path: String
	var h_frames: int
	var v_frames: int

	if not sprite_config.is_empty():
		sprite_path = sprite_config.get("sprite_path", "")
		h_frames = sprite_config.get("h_frames", 4)
		v_frames = sprite_config.get("v_frames", 2)
	else:
		sprite_path = "res://assets/sprites/enemies/goblins/goblin_sword.png"
		h_frames = 4
		v_frames = 2

	var sprite: Texture2D = load(sprite_path)
	if not sprite:
		push_warning("[GoblinCamp] Missing warboss sprite")
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
		enemy.add_to_group("goblin_camp_enemies")
		enemy.add_to_group("goblin_warboss")
		enemy.add_to_group("bosses")
		print("[GoblinCamp] Spawned Goblin Warboss at %s" % pos)


## ============================================================================
## LOOT
## ============================================================================

func _spawn_loot() -> void:
	# Goblin supply chest
	var supply_chest := Chest.spawn_chest(
		self,
		Vector3(-10, 0, 0),
		"Goblin Supplies",
		false, 0,
		false, ""
	)
	if supply_chest:
		supply_chest.setup_with_loot(LootTables.LootTier.COMMON)

	# Warboss treasure chest (better loot, locked)
	var boss_chest := Chest.spawn_chest(
		self,
		Vector3(0, 0, -8),
		"Warboss Hoard",
		true, 15,
		false, ""
	)
	if boss_chest:
		boss_chest.setup_with_loot(LootTables.LootTier.UNCOMMON)

	print("[GoblinCamp] Spawned loot chests")


## ============================================================================
## LIGHTING
## ============================================================================

func _create_lighting() -> void:
	# Campfire lights scattered around
	_spawn_campfire_light(Vector3(0, 2, 10), Color(1.0, 0.6, 0.3), 10.0, 1.0)
	_spawn_campfire_light(Vector3(-8, 2, 5), Color(1.0, 0.5, 0.2), 8.0, 0.8)
	_spawn_campfire_light(Vector3(8, 2, 5), Color(1.0, 0.5, 0.2), 8.0, 0.8)
	_spawn_campfire_light(Vector3(0, 2, -5), Color(1.0, 0.7, 0.4), 12.0, 1.2)  # Warboss area

	print("[GoblinCamp] Created lighting")


func _spawn_campfire_light(pos: Vector3, color: Color, range_val: float, energy: float) -> void:
	var light := OmniLight3D.new()
	light.name = "CampfireLight"
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_val
	light.position = pos
	add_child(light)


## ============================================================================
## CELL STREAMING
## ============================================================================

func _setup_cell_streaming() -> void:
	var player: Node = get_node_or_null("Player")
	if not player:
		return

	if not CellStreamer:
		return

	# Get location ID from metadata or fallback
	var location_id: String = get_meta("location_id", "goblin_camp_southwest")
	var my_coords: Vector2i = WorldGrid.get_location_coords(location_id)
	CellStreamer.register_main_scene_cell(my_coords, self)
	CellStreamer.start_streaming(my_coords)
	print("[GoblinCamp] Streaming started at %s" % my_coords)
