## kazan_dun_level_5.gd - The Deep Mines of Kazan-Dun
## Level 5: Ancient mine shafts, ritual chamber (100x100 units)
## GOBLIN STRONGHOLD - The dead dwarf king's body is held here for a dark ritual
## Heavily defended by goblins, including their war leader
## Connects to: Level_4 (Great Bridge), Exit (back passages)
extends Node3D

const ZONE_ID := "kazan_dun_level_5"
const ZONE_SIZE := 100.0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var enemies_node: Node3D = $NPCs

## Enemy data resources
var goblin_soldier_data: EnemyData
var goblin_archer_data: EnemyData
var goblin_mage_data: EnemyData
var goblin_warboss_data: EnemyData


func _ready() -> void:
	_load_enemy_data()
	_setup_navigation()
	_setup_spawn_point_metadata()
	_spawn_goblin_enemies()
	print("[Kazan-Dun Level 5] The Deep Mines initialized - GOBLIN STRONGHOLD (Zone size: %dx%d)" % [ZONE_SIZE, ZONE_SIZE])


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Kazan-Dun Level 5] NavigationRegion3D not found in scene")
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
		print("[Kazan-Dun Level 5] Navigation mesh baked")


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
	goblin_warboss_data = load("res://data/enemies/goblin_warboss.tres")


## Spawn goblin enemies in the deep mines - their stronghold
func _spawn_goblin_enemies() -> void:
	if not enemies_node:
		enemies_node = get_node_or_null("NPCs")
		if not enemies_node:
			enemies_node = Node3D.new()
			enemies_node.name = "NPCs"
			add_child(enemies_node)

	# Entrance from level 4 - heavy guard
	_spawn_goblin_soldier(Vector3(-8, 0, 45))
	_spawn_goblin_soldier(Vector3(8, 0, 45))
	_spawn_goblin_archer(Vector3(-15, 0, 40))
	_spawn_goblin_archer(Vector3(15, 0, 40))

	# Main chamber - goblin forces surrounding the ritual area
	_spawn_goblin_soldier(Vector3(-25, 0, 0))
	_spawn_goblin_soldier(Vector3(25, 0, 0))
	_spawn_goblin_soldier(Vector3(-20, 0, 15))
	_spawn_goblin_soldier(Vector3(20, 0, 15))
	_spawn_goblin_soldier(Vector3(-20, 0, -15))
	_spawn_goblin_soldier(Vector3(20, 0, -15))

	# Archers on elevated positions
	_spawn_goblin_archer(Vector3(-35, 0, 25))
	_spawn_goblin_archer(Vector3(35, 0, 25))
	_spawn_goblin_archer(Vector3(-35, 0, -25))
	_spawn_goblin_archer(Vector3(35, 0, -25))

	# Ritual circle - shamans conducting the dark rite
	_spawn_goblin_mage(Vector3(-10, 0, -5))
	_spawn_goblin_mage(Vector3(10, 0, -5))
	_spawn_goblin_mage(Vector3(0, 0, 5))  # Lead shaman

	# Warboss guarding the king's body at the ritual center
	_spawn_goblin_warboss(Vector3(0, 0, -20))

	# Back passage guards (toward exit)
	_spawn_goblin_soldier(Vector3(-5, 0, -40))
	_spawn_goblin_soldier(Vector3(5, 0, -40))

	print("[Kazan-Dun Level 5] Spawned goblin stronghold forces with warboss")


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
		if enemy:
			enemy.is_ranged = true
			enemy.preferred_range = 18.0
			enemy.min_range = 6.0
			enemy.ranged_attack_cooldown = 2.0


## Spawn the goblin warboss (mini-boss) with billboard sprite
func _spawn_goblin_warboss(pos: Vector3) -> void:
	if not goblin_warboss_data:
		push_warning("[Kazan-Dun Level 5] Goblin warboss data not found, spawning soldier instead")
		_spawn_goblin_soldier(pos)
		return

	# Check if warboss has sprite info, otherwise use soldier sprite scaled up
	var sprite_path: String = goblin_warboss_data.sprite_path if not goblin_warboss_data.sprite_path.is_empty() else goblin_soldier_data.sprite_path
	var sprite_tex: Texture2D = load(sprite_path)
	if sprite_tex:
		var enemy := EnemyBase.spawn_billboard_enemy(
			enemies_node,
			pos,
			"res://data/enemies/goblin_warboss.tres",
			sprite_tex,
			goblin_warboss_data.sprite_hframes if goblin_warboss_data.sprite_hframes > 0 else 4,
			goblin_warboss_data.sprite_vframes if goblin_warboss_data.sprite_vframes > 0 else 2
		)
		if enemy and enemy.billboard_sprite:
			# Make the warboss larger
			enemy.billboard_sprite.pixel_size = 0.035
