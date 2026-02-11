## dusty_hollow.gd - Destroyed desert edge hamlet overrun by Tengers
## Once a hardscrabble farming community at the edge of the southern desert,
## now completely destroyed by Tenger marauders. More heavily occupied than Windmere.
## HOSTILE ZONE - No safe areas, no fast travel. Path to Tenger Camp.
##
## NOTE: All terrain, buildings, bodies, and decorations are pre-placed in the .tscn file
## This script only handles: spawn point metadata, navigation, zone exits, enemies, loot, lights
extends Node3D

const ZONE_ID := "hamlet_dusty_hollow_destroyed"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Dusty Hollow (Destroyed)")
	_setup_spawn_point_metadata()
	_setup_navigation()
	_spawn_zone_exits()
	_spawn_tenger_enemies()
	_spawn_loot()
	_setup_smolder_flickering()
	print("[Dusty Hollow] Destroyed hamlet loaded - HOSTILE ZONE")


## Setup metadata on spawn points from the scene
func _setup_spawn_point_metadata() -> void:
	var spawn_points_node: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points_node:
		push_warning("[Dusty Hollow] SpawnPoints node not found")
		return

	for child in spawn_points_node.get_children():
		if child is Marker3D:
			child.add_to_group("spawn_points")
			var spawn_id: String = child.name.replace("SpawnPoint_", "")
			child.set_meta("spawn_id", spawn_id)


## Setup navigation mesh for enemies
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
		print("[Dusty Hollow] Navigation mesh baked!")


## Zone exits (no fast travel - hostile zone)
func _spawn_zone_exits() -> void:
	# Exit to Windmere (west)
	var to_windmere := ZoneDoor.spawn_door(
		self,
		Vector3(-24, 0, 10),
		"res://scenes/levels/windmere.tscn",
		"from_dusty_hollow",
		"Path to Windmere"
	)
	to_windmere.rotation.y = PI / 2
	to_windmere.show_frame = false

	# Exit to Tenger Camp (east - deeper into danger)
	var to_tenger_camp := ZoneDoor.spawn_door(
		self,
		Vector3(24, 0, 0),
		"res://scenes/levels/tenger_camp.tscn",
		"from_dusty_hollow",
		"Path to Tenger Camp"
	)
	to_tenger_camp.rotation.y = -PI / 2
	to_tenger_camp.show_frame = false

	# Exit to wilderness (north - retreat)
	var to_wilderness := ZoneDoor.spawn_door(
		self,
		Vector3(0, 0, -24),
		"res://scenes/levels/wilderness_room.tscn",
		"from_dusty_hollow",
		"Retreat to Wilderness"
	)
	to_wilderness.rotation.y = PI
	to_wilderness.show_frame = false

	print("[Dusty Hollow] Spawned zone exits")


## Spawn Tenger enemies from markers
func _spawn_tenger_enemies() -> void:
	var enemy_spawn_points: Node3D = get_node_or_null("EnemySpawnPoints")
	if not enemy_spawn_points:
		push_warning("[Dusty Hollow] EnemySpawnPoints node not found")
		return

	var enemy_count := 0

	for child in enemy_spawn_points.get_children():
		if child is Marker3D:
			var enemy_type: String = ""
			var enemy_path: String = ""

			if child.name.begins_with("Infantry_"):
				enemy_path = "res://data/enemies/tenger_infantry.tres"
				enemy_type = "infantry"
			elif child.name.begins_with("Berserker_"):
				enemy_path = "res://data/enemies/tenger_berserker.tres"
				enemy_type = "berserker"
			elif child.name.begins_with("Archer_"):
				enemy_path = "res://data/enemies/tenger_archer.tres"
				enemy_type = "archer"
			elif child.name.begins_with("Cavalry_"):
				enemy_path = "res://data/enemies/tenger_cavalry.tres"
				enemy_type = "cavalry"
			elif child.name.begins_with("Warbanner_"):
				enemy_path = "res://data/enemies/tenger_warbanner.tres"
				enemy_type = "warbanner"
			elif child.name.begins_with("Shaman_"):
				enemy_path = "res://data/enemies/tenger_shaman.tres"
				enemy_type = "shaman"

			if enemy_path != "":
				var aggro_range: int = 4
				var patrol_radius: int = 1
				if enemy_type == "archer" or enemy_type == "shaman":
					patrol_radius = 2

				var enemy := EnemyBase.spawn_billboard_enemy(
					self,
					child.global_position,
					enemy_path,
					null,
					aggro_range,
					patrol_radius
				)
				if enemy:
					enemy.add_to_group("tenger_patrol")
					enemy_count += 1

	print("[Dusty Hollow] Spawned %d Tenger enemies" % enemy_count)


## Spawn loot from markers
func _spawn_loot() -> void:
	var interactables: Node3D = get_node_or_null("Interactables")
	if not interactables:
		push_warning("[Dusty Hollow] Interactables node not found")
		return

	# Tenger supply crate
	var supply_marker: Marker3D = interactables.get_node_or_null("Chest_SupplyCrate")
	if supply_marker:
		var supply_crate := Chest.spawn_chest(
			self,
			supply_marker.global_position,
			"Tenger Supply Crate",
			false, 0,
			false, ""
		)
		if supply_crate:
			supply_crate.setup_with_loot(LootTables.LootTier.COMMON)

	# Hidden farmer's cache (buried)
	var buried_marker: Marker3D = interactables.get_node_or_null("Chest_BuriedSavings")
	if buried_marker:
		var hidden_cache := Chest.spawn_chest(
			self,
			buried_marker.global_position,
			"Buried Savings",
			true, 14,
			false, ""
		)
		if hidden_cache:
			hidden_cache.setup_with_loot(LootTables.LootTier.UNCOMMON)

	# Raided goods
	var plundered_marker: Marker3D = interactables.get_node_or_null("Chest_PlunderedGoods")
	if plundered_marker:
		var raided_goods := Chest.spawn_chest(
			self,
			plundered_marker.global_position,
			"Plundered Goods",
			false, 0,
			false, ""
		)
		if raided_goods:
			raided_goods.setup_with_loot(LootTables.LootTier.COMMON)

	# Well stash (hidden in destroyed well)
	var well_marker: Marker3D = interactables.get_node_or_null("Chest_WellCache")
	if well_marker:
		var well_stash := Chest.spawn_chest(
			self,
			well_marker.global_position,
			"Well Cache",
			true, 10,
			false, ""
		)
		if well_stash:
			well_stash.setup_with_loot(LootTables.LootTier.UNCOMMON)

	print("[Dusty Hollow] Spawned loot")


## Setup flickering for smolder lights
func _setup_smolder_flickering() -> void:
	var lights_node: Node3D = get_node_or_null("Lights")
	if not lights_node:
		return

	for child in lights_node.get_children():
		if child is OmniLight3D:
			var base_energy: float = child.light_energy
			var tween := create_tween().set_loops()
			tween.tween_property(child, "light_energy", base_energy * 0.7, randf_range(0.3, 0.6))
			tween.tween_property(child, "light_energy", base_energy * 1.2, randf_range(0.25, 0.5))
