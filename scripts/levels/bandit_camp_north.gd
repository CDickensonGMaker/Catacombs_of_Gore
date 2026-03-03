## bandit_camp_north.gd - Northern Bandit Camp
## A rough camp of brigands hidden in the northern forest
## Located at grid coords (-2, -5) near Thornfield
extends Node3D

const ZONE_ID := "bandit_camp_north"

var nav_region: NavigationRegion3D


func _ready() -> void:
	if SceneManager:
		SceneManager.set_current_region(ZONE_ID)

	_setup_environment()
	_spawn_enemies_from_markers()
	_spawn_chests_from_markers()
	_spawn_doors_from_markers()
	_setup_navigation()
	_setup_cell_streaming()
	# Only setup day/night lighting when this is the main scene (has Player node)
	# When loaded as a streamed cell, CellStreamer strips lighting to prevent doubling
	var is_main_scene: bool = get_node_or_null("Player") != null
	if is_main_scene:
		DayNightCycle.add_to_level(self)
	print("[BanditCampNorth] Camp loaded")


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.25, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.38, 0.28)
	env.ambient_light_energy = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.28, 0.2)
	env.fog_density = 0.015
	env.fog_sky_affect = 0.4

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.light_color = Color(0.85, 0.82, 0.72)
	light.light_energy = 0.5
	light.rotation_degrees = Vector3(-40, 30, 0)
	light.shadow_enabled = true
	light.shadow_bias = 0.02
	add_child(light)


func _spawn_enemies_from_markers() -> void:
	var enemy_spawns := get_node_or_null("EnemySpawns")
	if not enemy_spawns:
		push_warning("[BanditCampNorth] EnemySpawns node not found")
		return

	var enemies_container := Node3D.new()
	enemies_container.name = "Enemies"
	add_child(enemies_container)

	for marker in enemy_spawns.get_children():
		if marker is Marker3D:
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
				# Fall back to defaults
				sprite_path = "res://assets/sprites/enemies/human_bandit.png"
				h_frames = 4
				v_frames = 1

			var sprite_texture: Texture2D = load(sprite_path)
			if not sprite_texture:
				push_error("[BanditCampNorth] Failed to load sprite: %s" % sprite_path)
				continue

			EnemyBase.spawn_billboard_enemy(
				enemies_container,
				marker.global_position,
				enemy_data_path,
				sprite_texture,
				h_frames,
				v_frames
			)

	print("[BanditCampNorth] Spawned enemies from %d markers" % enemy_spawns.get_child_count())


func _spawn_chests_from_markers() -> void:
	var chest_positions := get_node_or_null("ChestPositions")
	if not chest_positions:
		return

	var interactables := Node3D.new()
	interactables.name = "Interactables"
	add_child(interactables)

	for marker in chest_positions.get_children():
		if marker is Marker3D:
			var chest_name: String = marker.get_meta("chest_name", "Chest")
			var is_locked: bool = marker.get_meta("is_locked", false)
			var lock_difficulty: int = marker.get_meta("lock_difficulty", 10)
			var randomize_loot: bool = marker.get_meta("randomize_loot", true)
			var persistent_id: String = marker.get_meta("persistent_id", "")

			Chest.spawn_chest(
				interactables,
				marker.global_position,
				chest_name,
				is_locked,
				lock_difficulty,
				randomize_loot,
				persistent_id
			)


func _spawn_doors_from_markers() -> void:
	var door_positions := get_node_or_null("DoorPositions")
	if not door_positions:
		return

	var doors := Node3D.new()
	doors.name = "Doors"
	add_child(doors)

	for marker in door_positions.get_children():
		if marker is Marker3D:
			var target_scene: String = marker.get_meta("target_scene", "")
			var spawn_id: String = marker.get_meta("spawn_id", "default")
			var door_label: String = marker.get_meta("door_label", "Exit")
			var show_frame: bool = marker.get_meta("show_frame", true)

			if target_scene == "RETURN_TO_WILDERNESS":
				target_scene = SceneManager.RETURN_TO_WILDERNESS

			var door := ZoneDoor.spawn_door(
				doors,
				marker.global_position,
				target_scene,
				spawn_id,
				door_label
			)
			if door:
				door.rotation = marker.rotation
				door.show_frame = show_frame


func _setup_navigation() -> void:
	nav_region = get_node_or_null("NavigationRegion3D")
	if not nav_region:
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


func _setup_cell_streaming() -> void:
	var player: Node = get_node_or_null("Player")
	if not player:
		return

	if not CellStreamer:
		return

	var my_coords: Vector2i = WorldGrid.get_location_coords("bandit_camp_north")
	CellStreamer.register_main_scene_cell(my_coords, self)
	CellStreamer.start_streaming(my_coords)
	print("[BanditCampNorth] Streaming started at %s" % my_coords)
