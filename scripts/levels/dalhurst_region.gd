## dalhurst_region.gd - The Dalhurst region (northern port/trading hub)
## A coastal port city north of the Crossroads
extends Node3D

const ZONE_ID := "region_dalhurst"
const ZONE_SIZE := 300.0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	_setup_navigation()
	_setup_day_night_cycle()
	_setup_spawn_point_metadata()
	_spawn_enemies()
	_spawn_herbs()
	print("[Dalhurst Region] Region initialized")


func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Dalhurst Region] NavigationRegion3D not found")
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


func _setup_day_night_cycle() -> void:
	# Only setup day/night lighting when this is the main scene (has Player node)
	# When loaded as a streamed cell, CellStreamer strips lighting to prevent doubling
	var is_main_scene: bool = get_node_or_null("Player") != null
	if is_main_scene:
		DayNightCycle.add_to_level(self)


func _setup_spawn_point_metadata() -> void:
	var spawn_points := get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	for child in spawn_points.get_children():
		if child.is_in_group("spawn_points"):
			child.set_meta("spawn_id", child.name)


func _spawn_enemies() -> void:
	# Dalhurst is a civilized port - minimal wilderness enemies
	# Just a few bandits/thugs on the outskirts
	var enemy_spawns := get_node_or_null("EnemySpawns")
	if not enemy_spawns:
		return

	for marker in enemy_spawns.get_children():
		if marker is Marker3D:
			_spawn_enemy_at_marker(marker)


func _spawn_enemy_at_marker(marker: Marker3D) -> void:
	var enemy_data_path: String = marker.get_meta("enemy_data", "res://data/enemies/human_bandit.tres")

	# Extract enemy type ID from path (e.g., "human_bandit" from ".../human_bandit.tres")
	var enemy_type: String = enemy_data_path.get_file().get_basename()

	# Check ActorRegistry first for sprite config (includes zoo patches)
	var sprite_config: Dictionary = ActorRegistry.get_sprite_config(enemy_type)

	var sprite_path: String
	var h_frames: int
	var v_frames: int

	if not sprite_config.is_empty():
		# Use ActorRegistry values (includes zoo patches)
		sprite_path = sprite_config.get("sprite_path", "")
		h_frames = sprite_config.get("h_frames", 4)
		v_frames = sprite_config.get("v_frames", 1)
	else:
		# Fall back to marker metadata
		sprite_path = marker.get_meta("sprite_path", "res://assets/sprites/enemies/human_bandit.png")
		h_frames = marker.get_meta("h_frames", 4)
		v_frames = marker.get_meta("v_frames", 1)

	var sprite_texture: Texture2D = load(sprite_path)
	if not sprite_texture:
		push_error("[Dalhurst Region] Failed to load sprite: %s" % sprite_path)
		return

	var enemy: EnemyBase = EnemyBase.spawn_billboard_enemy(
		self,
		marker.global_position,
		enemy_data_path,
		sprite_texture,
		h_frames,
		v_frames
	)

	if enemy:
		enemy.add_to_group("enemies")


func _spawn_herbs() -> void:
	# Spawn some coastal herbs in the region outskirts
	var herb_spawns := get_node_or_null("HerbSpawns")
	if not herb_spawns:
		return

	for marker in herb_spawns.get_children():
		if marker is Marker3D:
			HarvestablePlant.spawn_random_plant(self, marker.global_position)
