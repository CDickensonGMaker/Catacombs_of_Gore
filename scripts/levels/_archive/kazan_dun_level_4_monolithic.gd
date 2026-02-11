## kazan_dun_level_4.gd - The Great Bridge of Kazan-Dun
## Level 4: Massive stone bridge connecting the north and south mountains (240x160 units)
## GOBLIN TERRITORY - Fallen to the goblin invasion
## Contains goblin soldiers, archers, and a shaman
## Connects to: Level_3 (dwarf frontier), Level_5 (deep mines)
extends Node3D

const ZONE_ID := "kazan_dun_level_4"
const ZONE_SIZE_X := 240.0
const ZONE_SIZE_Z := 160.0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var enemies_node: Node3D = $NPCs

## Enemy data resources
var goblin_soldier_data: EnemyData
var goblin_archer_data: EnemyData
var goblin_mage_data: EnemyData


func _ready() -> void:
	_load_enemy_data()
	_setup_navigation()
	_setup_spawn_point_metadata()
	_spawn_goblin_enemies()
	print("[Kazan-Dun Level 4] The Great Bridge initialized - GOBLIN TERRITORY (Zone size: %dx%d)" % [ZONE_SIZE_X, ZONE_SIZE_Z])


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Kazan-Dun Level 4] NavigationRegion3D not found in scene")
		return

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
		print("[Kazan-Dun Level 4] Navigation mesh baked")


## Add metadata to spawn points for proper identification
func _setup_spawn_point_metadata() -> void:
	var spawn_points := get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	for child in spawn_points.get_children():
		if child.is_in_group("spawn_points"):
			child.set_meta("spawn_id", child.name)


## Load enemy data resources
func _load_enemy_data() -> void:
	goblin_soldier_data = load("res://data/enemies/goblin_soldier.tres")
	goblin_archer_data = load("res://data/enemies/goblin_archer.tres")
	goblin_mage_data = load("res://data/enemies/goblin_mage.tres")


## Spawn goblin enemies throughout the bridge level
func _spawn_goblin_enemies() -> void:
	if not enemies_node:
		enemies_node = get_node_or_null("NPCs")
		if not enemies_node:
			enemies_node = Node3D.new()
			enemies_node.name = "NPCs"
			add_child(enemies_node)

	# Bridge entrance guards (from level 3 side)
	_spawn_goblin_soldier(Vector3(-10, 0, 70))
	_spawn_goblin_soldier(Vector3(10, 0, 70))
	_spawn_goblin_archer(Vector3(0, 0, 65))

	# Bridge center - main goblin force
	_spawn_goblin_soldier(Vector3(-30, 0, 0))
	_spawn_goblin_soldier(Vector3(30, 0, 0))
	_spawn_goblin_soldier(Vector3(-15, 0, 10))
	_spawn_goblin_soldier(Vector3(15, 0, -10))
	_spawn_goblin_archer(Vector3(-40, 0, 20))
	_spawn_goblin_archer(Vector3(40, 0, -20))
	_spawn_goblin_mage(Vector3(0, 0, 0))  # Shaman in the center

	# Far side of bridge (level 5 side)
	_spawn_goblin_soldier(Vector3(-20, 0, -60))
	_spawn_goblin_soldier(Vector3(20, 0, -60))
	_spawn_goblin_archer(Vector3(0, 0, -55))

	# Patrol groups on the bridge sides
	_spawn_goblin_soldier(Vector3(-50, 0, 30))
	_spawn_goblin_soldier(Vector3(50, 0, -30))

	print("[Kazan-Dun Level 4] Spawned goblin enemies on the Great Bridge")


## Spawn a goblin soldier with billboard sprite
func _spawn_goblin_soldier(pos: Vector3) -> void:
	if not goblin_soldier_data:
		return
	var sprite_tex: Texture2D = load(goblin_soldier_data.sprite_path)
	if sprite_tex:
		EnemyBase.spawn_billboard_enemy(
			enemies_node,
			pos,
			"res://data/enemies/goblin_soldier.tres",
			sprite_tex,
			goblin_soldier_data.sprite_hframes,
			goblin_soldier_data.sprite_vframes
		)


## Spawn a goblin archer with billboard sprite
func _spawn_goblin_archer(pos: Vector3) -> void:
	if not goblin_archer_data:
		return
	var sprite_tex: Texture2D = load(goblin_archer_data.sprite_path)
	if sprite_tex:
		var enemy := EnemyBase.spawn_billboard_enemy(
			enemies_node,
			pos,
			"res://data/enemies/goblin_archer.tres",
			sprite_tex,
			goblin_archer_data.sprite_hframes,
			goblin_archer_data.sprite_vframes
		)
		# Configure as ranged enemy
		if enemy:
			enemy.is_ranged = true
			enemy.preferred_range = 20.0
			enemy.min_range = 8.0
			enemy.ranged_attack_cooldown = 1.5


## Spawn a goblin mage/shaman with billboard sprite
func _spawn_goblin_mage(pos: Vector3) -> void:
	if not goblin_mage_data:
		return
	var sprite_tex: Texture2D = load(goblin_mage_data.sprite_path)
	if sprite_tex:
		var enemy := EnemyBase.spawn_billboard_enemy(
			enemies_node,
			pos,
			"res://data/enemies/goblin_mage.tres",
			sprite_tex,
			goblin_mage_data.sprite_hframes,
			goblin_mage_data.sprite_vframes
		)
		# Configure as ranged magical enemy
		if enemy:
			enemy.is_ranged = true
			enemy.preferred_range = 18.0
			enemy.min_range = 6.0
			enemy.ranged_attack_cooldown = 2.0
