## windmere.gd - Destroyed hamlet overrun by Tengers
## Once a peaceful farming community in the rolling hills,
## now completely destroyed by Tenger marauders from the south.
## HOSTILE ZONE - No safe areas, no fast travel.
##
## NOTE: All terrain, buildings, bodies, and decorations are pre-placed in the .tscn file
## This script only handles: enemy spawning, loot, door connections, navigation
extends Node3D

const ZONE_ID := "hamlet_windmere_destroyed"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Windmere (Destroyed)")

	_setup_environment()
	_setup_spawn_point_metadata()
	_setup_navigation()
	_spawn_zone_exits()
	_spawn_tenger_enemies()
	_spawn_loot()
	_setup_fire_flickering()

	print("[Windmere] Destroyed hamlet loaded - HOSTILE ZONE")


## Setup the WorldEnvironment with smoky atmosphere
func _setup_environment() -> void:
	var world_env: WorldEnvironment = $WorldEnvironment
	if world_env:
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.4, 0.38, 0.35)  # Gray-brown overcast
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.5, 0.48, 0.42)
		env.ambient_light_energy = 0.6

		# Heavy smoke fog
		env.fog_enabled = true
		env.fog_light_color = Color(0.45, 0.4, 0.35)
		env.fog_density = 0.02

		# Volumetric smoke
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.04
		env.volumetric_fog_albedo = Color(0.35, 0.32, 0.28)

		world_env.environment = env


## Setup metadata on spawn points from the scene
func _setup_spawn_point_metadata() -> void:
	var spawn_points_node: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points_node:
		push_warning("[Windmere] SpawnPoints node not found")
		return

	for child in spawn_points_node.get_children():
		if child is Marker3D:
			child.add_to_group("spawn_points")
			var spawn_id: String = child.name.replace("SpawnPoint_", "")
			child.set_meta("spawn_id", spawn_id)


## Setup navigation mesh
func _setup_navigation() -> void:
	if nav_region:
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
		print("[Windmere] Navigation mesh baked!")


## Zone exits (no fast travel - hostile zone)
func _spawn_zone_exits() -> void:
	var doors := Node3D.new()
	doors.name = "Doors"
	add_child(doors)

	# Exit to Dusty Hollow (east - toward desert)
	var to_dusty_hollow := ZoneDoor.spawn_door(
		doors,
		Vector3(24, 0, 10),
		"res://scenes/levels/dusty_hollow.tscn",
		"from_windmere",
		"Path to Dusty Hollow"
	)
	to_dusty_hollow.rotation.y = -PI/2
	to_dusty_hollow.show_frame = false

	# Exit to wilderness (south - retreat)
	var to_wilderness := ZoneDoor.spawn_door(
		doors,
		Vector3(0, 0, 24),
		SceneManager.RETURN_TO_WILDERNESS,
		"from_windmere",
		"Flee to Wilderness"
	)
	to_wilderness.rotation.y = 0
	to_wilderness.show_frame = false

	# Exit to Border Wars Graveyard (west - safer retreat)
	var to_graveyard := ZoneDoor.spawn_door(
		doors,
		Vector3(-24, 0, -10),
		"res://scenes/levels/border_wars_graveyard.tscn",
		"from_windmere",
		"Path to Border Wars Graveyard"
	)
	to_graveyard.rotation.y = PI/2
	to_graveyard.show_frame = false

	print("[Windmere] Spawned doors")


## Spawn Tenger enemies from marker positions
func _spawn_tenger_enemies() -> void:
	var enemy_spawns: Node3D = get_node_or_null("EnemySpawnPoints")
	if not enemy_spawns:
		push_warning("[Windmere] EnemySpawnPoints node not found")
		return

	var enemies := Node3D.new()
	enemies.name = "Enemies"
	add_child(enemies)

	# Spawn infantry
	for child in enemy_spawns.get_children():
		if child.name.begins_with("Infantry_"):
			var enemy := EnemyBase.spawn_billboard_enemy(
				enemies,
				child.global_position,
				"res://data/enemies/tenger_infantry.tres",
				null,
				4, 1
			)
			if enemy:
				enemy.add_to_group("tenger_patrol")

	# Spawn berserkers
	for child in enemy_spawns.get_children():
		if child.name.begins_with("Berserker_"):
			var enemy := EnemyBase.spawn_billboard_enemy(
				enemies,
				child.global_position,
				"res://data/enemies/tenger_berserker.tres",
				null,
				4, 1
			)
			if enemy:
				enemy.add_to_group("tenger_patrol")

	# Spawn archers
	for child in enemy_spawns.get_children():
		if child.name.begins_with("Archer_"):
			var enemy := EnemyBase.spawn_billboard_enemy(
				enemies,
				child.global_position,
				"res://data/enemies/tenger_archer.tres",
				null,
				4, 2
			)
			if enemy:
				enemy.add_to_group("tenger_patrol")

	# Spawn cavalry
	for child in enemy_spawns.get_children():
		if child.name.begins_with("Cavalry_"):
			var enemy := EnemyBase.spawn_billboard_enemy(
				enemies,
				child.global_position,
				"res://data/enemies/tenger_cavalry.tres",
				null,
				4, 1
			)
			if enemy:
				enemy.add_to_group("tenger_patrol")

	# Spawn warbanner
	for child in enemy_spawns.get_children():
		if child.name.begins_with("Warbanner_"):
			var enemy := EnemyBase.spawn_billboard_enemy(
				enemies,
				child.global_position,
				"res://data/enemies/tenger_warbanner.tres",
				null,
				4, 1
			)
			if enemy:
				enemy.add_to_group("tenger_patrol")

	print("[Windmere] Spawned Tenger enemies")


## Spawn loot from marker positions
func _spawn_loot() -> void:
	var interactables: Node3D = get_node_or_null("Interactables")
	if not interactables:
		push_warning("[Windmere] Interactables node not found")
		return

	# Tenger supply crate
	var supply_pos: Marker3D = interactables.get_node_or_null("Chest_TengerSupply")
	if supply_pos:
		var supply_crate := Chest.spawn_chest(
			interactables,
			supply_pos.global_position,
			"Tenger Supply Crate",
			false, 0,
			false, ""
		)
		if supply_crate:
			supply_crate.setup_with_loot(LootTables.LootTier.COMMON)

	# Hidden villager stash (in ruined basement)
	var hidden_pos: Marker3D = interactables.get_node_or_null("Chest_HiddenCellar")
	if hidden_pos:
		var hidden_stash := Chest.spawn_chest(
			interactables,
			hidden_pos.global_position,
			"Hidden Cellar Cache",
			true, 12,
			false, ""
		)
		if hidden_stash:
			hidden_stash.setup_with_loot(LootTables.LootTier.UNCOMMON)

	# Looted merchant goods
	var merchant_pos: Marker3D = interactables.get_node_or_null("Chest_MerchantGoods")
	if merchant_pos:
		var merchant_remains := Chest.spawn_chest(
			interactables,
			merchant_pos.global_position,
			"Scattered Merchant Goods",
			false, 0,
			false, ""
		)
		if merchant_remains:
			merchant_remains.setup_with_loot(LootTables.LootTier.COMMON)

	print("[Windmere] Spawned loot")


## Setup flickering for fire lights
func _setup_fire_flickering() -> void:
	var lights_node: Node3D = get_node_or_null("Lights")
	if not lights_node:
		return

	for child in lights_node.get_children():
		if child is OmniLight3D and child.name.begins_with("FireLight"):
			var tween := create_tween().set_loops()
			tween.tween_property(child, "light_energy", randf_range(0.6, 1.0), randf_range(0.2, 0.4))
			tween.tween_property(child, "light_energy", randf_range(0.9, 1.3), randf_range(0.15, 0.35))
