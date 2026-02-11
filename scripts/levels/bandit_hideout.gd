## bandit_hideout.gd - Bandit Hideout Exterior (Hand-crafted)
## The camp area outside the hideout caves
## All geometry, enemies, chests, and doors are pre-placed in the .tscn file
extends Node3D

const ZONE_ID := "bandit_hideout"

var spawn_points: Node3D
var enemy_spawns: Node3D
var door_positions: Node3D
var chest_positions: Node3D


func _ready() -> void:
	# Get optional nodes (may not exist in scene)
	# Note: Scene uses EnemySpawns, DoorPositions, ChestPositions naming convention
	spawn_points = get_node_or_null("SpawnPoints")
	enemy_spawns = get_node_or_null("EnemySpawns")
	door_positions = get_node_or_null("DoorPositions")
	chest_positions = get_node_or_null("ChestPositions")

	SaveManager.set_current_zone(ZONE_ID, "Bandit Hideout")

	_setup_environment()
	_setup_spawn_points()
	_setup_enemies()
	_setup_doors()
	_setup_chests()
	_setup_navigation()

	print("[BanditHideout] Hand-crafted level loaded")


func _setup_environment() -> void:
	# Check if WorldEnvironment already exists in scene
	if has_node("WorldEnvironment"):
		return

	# Create environment if not pre-placed (warm torchlit cave)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.03, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.18, 0.12)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.15, 0.1, 0.08)
	env.fog_density = 0.015

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	# Add directional light if not present
	if not has_node("DirectionalLight3D"):
		var light := DirectionalLight3D.new()
		light.name = "DirectionalLight3D"
		light.light_color = Color(1.0, 0.85, 0.65)
		light.light_energy = 0.15
		light.rotation_degrees = Vector3(-45, 30, 0)
		add_child(light)


func _setup_spawn_points() -> void:
	# Look for pre-placed spawn points in scene

	if not spawn_points:
		spawn_points = get_node_or_null("SpawnPoints")

	if spawn_points:
		for child in spawn_points.get_children():
			child.add_to_group("spawn_points")
			var spawn_id := child.name.replace("SpawnPoint_", "").to_lower()
			child.set_meta("spawn_id", spawn_id)
		print("[BanditHideout] Found %d pre-placed spawn points" % spawn_points.get_child_count())
	else:
		push_warning("[BanditHideout] No SpawnPoints node found, creating default")
		var default_spawn := Node3D.new()
		default_spawn.name = "SpawnPoint_Default"
		default_spawn.add_to_group("spawn_points")
		default_spawn.set_meta("spawn_id", "default")
		default_spawn.global_position = Vector3(0, 0.5, 0)
		add_child(default_spawn)


func _setup_enemies() -> void:
	# Look for pre-placed enemy markers in scene
	# Expected structure: EnemySpawns/Marker3D nodes with metadata

	if not enemy_spawns:
		enemy_spawns = get_node_or_null("EnemySpawns")

	if not enemy_spawns:
		return

	var enemy_count := 0
	for marker in enemy_spawns.get_children():
		if marker is Marker3D or marker is Node3D:
			_spawn_enemy_at_marker(marker)
			enemy_count += 1

	print("[BanditHideout] Spawned %d enemies from markers" % enemy_count)


func _spawn_enemy_at_marker(marker: Node3D) -> void:
	var enemy_data_path: String = marker.get_meta("enemy_data", "res://data/enemies/human_bandit.tres")
	var sprite_path: String = marker.get_meta("sprite_path", "res://assets/sprites/enemies/human_bandit.png")
	var h_frames: int = marker.get_meta("h_frames", 3)
	var v_frames: int = marker.get_meta("v_frames", 1)

	var sprite_texture: Texture2D = load(sprite_path)
	if not sprite_texture:
		push_error("[BanditHideout] Failed to load sprite: %s" % sprite_path)
		return

	# Spawn slightly above marker position so CharacterBody3D settles on floor
	var spawn_pos: Vector3 = marker.global_position + Vector3(0, 0.5, 0)

	var enemy = EnemyBase.spawn_billboard_enemy(
		self,
		spawn_pos,
		enemy_data_path,
		sprite_texture,
		h_frames,
		v_frames
	)

	if enemy:
		enemy.add_to_group("enemies")


func _setup_doors() -> void:
	# Look for pre-placed door markers in scene
	# Expected structure: DoorPositions/Marker3D nodes with metadata

	if not door_positions:
		door_positions = get_node_or_null("DoorPositions")

	if not door_positions:
		return

	var doors_container := Node3D.new()
	doors_container.name = "Doors"
	add_child(doors_container)

	var door_count := 0
	for marker in door_positions.get_children():
		if marker is Marker3D or marker is Node3D:
			_spawn_door_at_marker(marker, doors_container)
			door_count += 1

	print("[BanditHideout] Spawned %d doors from markers" % door_count)


func _spawn_door_at_marker(marker: Node3D, parent: Node3D) -> void:
	var target_scene: String = marker.get_meta("target_scene", "")
	var spawn_id: String = marker.get_meta("spawn_id", "default")
	var door_label: String = marker.get_meta("door_label", "Door")
	var show_frame: bool = marker.get_meta("show_frame", true)

	if target_scene.is_empty():
		push_warning("[BanditHideout] Door marker %s has no target_scene" % marker.name)
		return

	var door := ZoneDoor.spawn_door(
		parent,
		marker.global_position,
		target_scene,
		spawn_id,
		door_label,
		show_frame
	)

	if door:
		door.rotation = marker.rotation


func _setup_chests() -> void:
	# Look for pre-placed chest markers in scene
	# Expected structure: ChestPositions/Marker3D nodes with metadata

	if not chest_positions:
		chest_positions = get_node_or_null("ChestPositions")

	if not chest_positions:
		return

	var chest_count := 0
	for marker in chest_positions.get_children():
		if marker is Marker3D or marker is Node3D:
			_spawn_chest_at_marker(marker)
			chest_count += 1

	print("[BanditHideout] Spawned %d chests from markers" % chest_count)


func _spawn_chest_at_marker(marker: Node3D) -> void:
	var chest_id: String = marker.get_meta("chest_id", "chest_%s" % marker.name)
	var chest_name: String = marker.get_meta("chest_name", "Chest")
	var is_locked: bool = marker.get_meta("is_locked", false)
	var lock_difficulty: int = marker.get_meta("lock_difficulty", 10)
	var is_persistent: bool = marker.get_meta("is_persistent", false)
	var loot_tier: String = marker.get_meta("loot_tier", "common")

	# Use Chest.spawn_chest() static factory method
	var chest := Chest.spawn_chest(
		self,
		marker.global_position,
		chest_name,
		is_locked,
		lock_difficulty,
		is_persistent,
		chest_id
	)

	if chest:
		chest.rotation = marker.rotation
		# Setup loot based on tier
		var tier: LootTables.LootTier = _get_loot_tier(loot_tier)
		chest.setup_with_loot(tier)


func _get_loot_tier(tier_name: String) -> LootTables.LootTier:
	match tier_name.to_lower():
		"junk":
			return LootTables.LootTier.JUNK
		"common":
			return LootTables.LootTier.COMMON
		"uncommon":
			return LootTables.LootTier.UNCOMMON
		"rare":
			return LootTables.LootTier.RARE
		"epic":
			return LootTables.LootTier.EPIC
		"legendary":
			return LootTables.LootTier.LEGENDARY
		_:
			return LootTables.LootTier.COMMON


func _setup_navigation() -> void:
	var nav_region := get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()
		print("[BanditHideout] Navigation mesh baked")
