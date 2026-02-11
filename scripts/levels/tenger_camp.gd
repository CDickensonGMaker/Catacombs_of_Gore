## tenger_camp.gd - Tenger marauder base camp
## The main encampment of the Tenger horde in this region.
## Yurts, horse pens, war banners, trophy displays, and many enemies.
## FULLY HOSTILE - No merchants, no safe areas, no fast travel.
##
## NOTE: All terrain, yurts, structures, and decorations are pre-placed in the .tscn file
## This script only handles: spawn point metadata, navigation, zone exits, enemies, loot, lights
extends Node3D

const ZONE_ID := "outpost_tenger_camp"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Tenger War Camp")
	_setup_spawn_point_metadata()
	_setup_navigation()
	_spawn_zone_exits()
	_spawn_tenger_enemies()
	_spawn_loot()
	_setup_light_flickering()
	print("[Tenger Camp] Marauder base loaded - FULLY HOSTILE")


## Setup metadata on spawn points from the scene
func _setup_spawn_point_metadata() -> void:
	var spawn_points_node: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points_node:
		push_warning("[Tenger Camp] SpawnPoints node not found")
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
		print("[Tenger Camp] Navigation mesh baked!")


## Zone exits (hostile - retreat only)
func _spawn_zone_exits() -> void:
	# Exit to Dusty Hollow (west - retreat)
	var to_dusty_hollow := ZoneDoor.spawn_door(
		self,
		Vector3(-29, 0, 0),
		"res://scenes/levels/dusty_hollow.tscn",
		"from_tenger_camp",
		"Retreat to Dusty Hollow"
	)
	to_dusty_hollow.rotation.y = PI / 2
	to_dusty_hollow.show_frame = false

	# Exit to wilderness (north)
	var to_wilderness_north := ZoneDoor.spawn_door(
		self,
		Vector3(0, 0, -29),
		"res://scenes/levels/wilderness_room.tscn",
		"from_tenger_camp",
		"Escape North"
	)
	to_wilderness_north.rotation.y = PI
	to_wilderness_north.show_frame = false

	# Exit deeper into desert (south - future expansion)
	var to_desert := ZoneDoor.spawn_door(
		self,
		Vector3(0, 0, 29),
		"res://scenes/levels/wilderness_room.tscn",
		"from_tenger_camp",
		"Southern Desert"
	)
	to_desert.rotation.y = 0
	to_desert.show_frame = false

	print("[Tenger Camp] Spawned zone exits")


## Spawn Tenger enemies from markers - this is their base!
func _spawn_tenger_enemies() -> void:
	var enemy_spawn_points: Node3D = get_node_or_null("EnemySpawnPoints")
	if not enemy_spawn_points:
		push_warning("[Tenger Camp] EnemySpawnPoints node not found")
		return

	var enemy_count := 0

	for child in enemy_spawn_points.get_children():
		if child is Marker3D:
			var enemy_type: String = ""
			var enemy_path: String = ""
			var is_boss: bool = false

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
			elif child.name.begins_with("Warlord_"):
				enemy_path = "res://data/enemies/tenger_warlord.tres"
				enemy_type = "warlord"
				is_boss = true

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
					enemy.add_to_group("tenger_camp")
					if is_boss:
						enemy.add_to_group("boss")
					enemy_count += 1

	print("[Tenger Camp] Spawned %d Tenger enemies (including Warlord)" % enemy_count)


## Spawn loot from markers (stolen goods, supply crates)
func _spawn_loot() -> void:
	var interactables: Node3D = get_node_or_null("Interactables")
	if not interactables:
		push_warning("[Tenger Camp] Interactables node not found")
		return

	# Warlord's treasure chest
	var warlord_marker: Marker3D = interactables.get_node_or_null("Chest_WarlordTreasure")
	if warlord_marker:
		var warlord_chest := Chest.spawn_chest(
			self,
			warlord_marker.global_position,
			"Warlord's War Chest",
			true, 18,
			false, ""
		)
		if warlord_chest:
			warlord_chest.setup_with_loot(LootTables.LootTier.RARE)

	# Supply crates
	var supply1_marker: Marker3D = interactables.get_node_or_null("Chest_Supply1")
	if supply1_marker:
		var supply1 := Chest.spawn_chest(
			self,
			supply1_marker.global_position,
			"Tenger Supplies",
			false, 0,
			false, ""
		)
		if supply1:
			supply1.setup_with_loot(LootTables.LootTier.COMMON)

	var supply2_marker: Marker3D = interactables.get_node_or_null("Chest_Supply2")
	if supply2_marker:
		var supply2 := Chest.spawn_chest(
			self,
			supply2_marker.global_position,
			"Raider Supplies",
			false, 0,
			false, ""
		)
		if supply2:
			supply2.setup_with_loot(LootTables.LootTier.COMMON)

	# Stolen village goods
	var stolen1_marker: Marker3D = interactables.get_node_or_null("Chest_Stolen1")
	if stolen1_marker:
		var stolen1 := Chest.spawn_chest(
			self,
			stolen1_marker.global_position,
			"Stolen Goods",
			false, 0,
			false, ""
		)
		if stolen1:
			stolen1.setup_with_loot(LootTables.LootTier.UNCOMMON)

	var stolen2_marker: Marker3D = interactables.get_node_or_null("Chest_Stolen2")
	if stolen2_marker:
		var stolen2 := Chest.spawn_chest(
			self,
			stolen2_marker.global_position,
			"Plundered Valuables",
			false, 0,
			false, ""
		)
		if stolen2:
			stolen2.setup_with_loot(LootTables.LootTier.UNCOMMON)

	# Shaman's ritual chest
	var shaman_marker: Marker3D = interactables.get_node_or_null("Chest_ShamanRelics")
	if shaman_marker:
		var shaman_chest := Chest.spawn_chest(
			self,
			shaman_marker.global_position,
			"Shaman's Relics",
			true, 15,
			false, ""
		)
		if shaman_chest:
			shaman_chest.setup_with_loot(LootTables.LootTier.RARE)

	print("[Tenger Camp] Spawned loot")


## Setup flickering for lights
func _setup_light_flickering() -> void:
	var lights_node: Node3D = get_node_or_null("Lights")
	if not lights_node:
		return

	# Central fire light - more dramatic flickering
	var central_fire: OmniLight3D = lights_node.get_node_or_null("CentralFireLight")
	if central_fire:
		var tween := create_tween().set_loops()
		tween.tween_property(central_fire, "light_energy", randf_range(1.5, 2.2), randf_range(0.15, 0.3))
		tween.tween_property(central_fire, "light_energy", randf_range(1.8, 2.5), randf_range(0.1, 0.25))

	# Shaman light - eerie pulsing
	var shaman_light: OmniLight3D = lights_node.get_node_or_null("ShamanLight")
	if shaman_light:
		var tween := create_tween().set_loops()
		tween.tween_property(shaman_light, "light_energy", randf_range(1.0, 1.3), randf_range(0.8, 1.2))
		tween.tween_property(shaman_light, "light_energy", randf_range(1.5, 1.8), randf_range(0.6, 1.0))

	# Warlord yurt interior light - subtle
	var warlord_light: OmniLight3D = lights_node.get_node_or_null("WarlordLight")
	if warlord_light:
		var tween := create_tween().set_loops()
		tween.tween_property(warlord_light, "light_energy", 0.4, randf_range(0.4, 0.7))
		tween.tween_property(warlord_light, "light_energy", 0.6, randf_range(0.35, 0.6))
