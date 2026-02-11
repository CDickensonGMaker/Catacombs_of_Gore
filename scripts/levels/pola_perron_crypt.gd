## pola_perron_crypt.gd - Pola Perron Crypt Dungeon
## Evil 3-level crypt beneath the peaceful monastery
## Runtime-only logic - all geometry is pre-placed in pola_perron_crypt.tscn
extends Node3D

const ZONE_ID := "dungeon_pola_perron_crypt"

## Level depth constants
const LEVEL_1_DEPTH := 0.0      # Entry level (burial chambers)
const LEVEL_2_DEPTH := -12.0    # Ossuary level
const LEVEL_3_DEPTH := -24.0    # Ancient evil level (boss area)

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "The Crypt of Pola Perron")
	_setup_spawn_points()
	_setup_enemy_spawns()
	_setup_chest_spawns()
	_spawn_portals()
	_setup_navigation()
	print("[Pola Perron Crypt] Evil crypt dungeon loaded (3 levels)")


## Configure spawn points from pre-placed markers
func _setup_spawn_points() -> void:
	var spawn_points := $SpawnPoints

	for child in spawn_points.get_children():
		if child is Marker3D:
			child.add_to_group("spawn_points")
			var spawn_id: String = child.name.replace("SpawnPoint_", "")
			child.set_meta("spawn_id", spawn_id)
			if spawn_id == "default":
				child.add_to_group("default_spawn")


## Configure enemy spawn points from pre-placed markers
func _setup_enemy_spawns() -> void:
	var enemy_spawns := $EnemySpawnPoints

	# Enemy type configuration based on spawn name
	var enemy_configs: Dictionary = {
		# Level 1 - Skeletons
		"Level1_Spawn_0": {"type": "skeleton", "respawn": 180.0},
		"Level1_Spawn_1": {"type": "skeleton", "respawn": 180.0},
		"Level1_Spawn_2": {"type": "skeleton", "respawn": 180.0},
		"Level1_Spawn_3": {"type": "skeleton", "respawn": 180.0},
		"Level1_Spawn_4": {"type": "skeleton", "respawn": 180.0},
		# Level 2 - Mixed skeletons and ghosts
		"Level2_Spawn_0": {"type": "ghost", "respawn": 180.0},
		"Level2_Spawn_1": {"type": "skeleton", "respawn": 180.0},
		"Level2_Spawn_2": {"type": "ghost", "respawn": 180.0},
		"Level2_Spawn_3": {"type": "skeleton", "respawn": 180.0},
		"Level2_Spawn_4": {"type": "ghost", "respawn": 180.0},
		"Level2_Spawn_5": {"type": "skeleton", "respawn": 180.0},
		"Level2_Spawn_6": {"type": "ghost", "respawn": 180.0},
		# Level 3 - Wraiths and boss
		"Level3_Spawn_0": {"type": "wraith", "respawn": 300.0},
		"Level3_Spawn_1": {"type": "wraith", "respawn": 300.0},
		"Level3_Spawn_2": {"type": "wraith", "respawn": 300.0},
		"Level3_Spawn_3": {"type": "wraith", "respawn": 300.0},
		"Level3_Spawn_4": {"type": "wraith", "respawn": 300.0},
		"Level3_Spawn_5": {"type": "wraith", "respawn": 300.0},
		"BossSpawn": {"type": "lich", "respawn": 600.0, "is_boss": true},
	}

	for child in enemy_spawns.get_children():
		if child is Marker3D:
			child.add_to_group("enemy_spawn")
			var config: Dictionary = enemy_configs.get(child.name, {"type": "skeleton", "respawn": 180.0})
			child.set_meta("enemy_type", config.get("type", "skeleton"))
			child.set_meta("respawn_time", config.get("respawn", 180.0))
			if config.get("is_boss", false):
				child.set_meta("is_boss", true)

	print("[Pola Perron Crypt] Configured %d enemy spawn points" % enemy_spawns.get_child_count())


## Configure chest spawn points from pre-placed markers
func _setup_chest_spawns() -> void:
	var chest_positions := $ChestPositions

	# Chest tier configuration based on location
	var chest_configs: Dictionary = {
		"Chest_Level1_0": "common",
		"Chest_Level1_1": "common",
		"Chest_Level2_0": "uncommon",
		"Chest_Level2_1": "uncommon",
		"Chest_Level3_Boss": "rare",
	}

	for child in chest_positions.get_children():
		if child is Marker3D:
			child.add_to_group("loot_chest")
			var tier: String = chest_configs.get(child.name, "common")
			child.set_meta("tier", tier)

	print("[Pola Perron Crypt] Configured %d loot chest positions" % chest_positions.get_child_count())


## Spawn portal connections
func _spawn_portals() -> void:
	var door_marker := $Interactables/DoorPosition_Monastery

	# Exit to monastery (Level 1 entrance)
	var monastery_portal := ZoneDoor.spawn_door(
		self,
		door_marker.position,
		"res://scenes/levels/pola_perron.tscn",
		"from_crypt",
		"Return to Monastery"
	)
	monastery_portal.rotation.y = PI

	print("[Pola Perron Crypt] Spawned portal connections")


## Setup navigation mesh
func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Pola Perron Crypt] NavigationRegion3D not found")
		return

	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.cell_size = 0.3
	nav_mesh.cell_height = 0.2
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0

	nav_region.navigation_mesh = nav_mesh
	call_deferred("_bake_navigation")


func _bake_navigation() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()
		print("[Pola Perron Crypt] Navigation mesh baked!")
