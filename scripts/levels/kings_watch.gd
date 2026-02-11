## kings_watch.gd - King's Watch Ancient Ruins
## Weathertop-style ancient ruins overlooking mountain passes near Aberdeen
## Atmospheric, windy, isolated outpost with crumbling stone and watchtower remains
## Hostile zone - undead and bandits patrol the ruins
## Size: 60x60
##
## CONVERTED: All geometry pre-placed in kings_watch.tscn
## This script handles: spawn point metadata, navigation, zone exits, enemy spawning, chests, light effects
extends Node3D

const ZONE_ID := "ruins_kings_watch"
const ZONE_SIZE := 60.0
const BASE_ELEVATION := 8.0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "King's Watch")
	_setup_spawn_point_metadata()
	_setup_navigation()
	_spawn_zone_exits()
	_spawn_enemies()
	_spawn_chests()
	_setup_light_effects()
	DayNightCycle.add_to_level(self)
	print("[Kings Watch] Ancient ruins loaded (Zone size: %dx%d)" % [ZONE_SIZE, ZONE_SIZE])


## Setup spawn point metadata from Marker3D nodes
func _setup_spawn_point_metadata() -> void:
	var spawn_points: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points:
		push_warning("[Kings Watch] SpawnPoints node not found")
		return

	for child in spawn_points.get_children():
		if child is Marker3D:
			child.add_to_group("spawn_points")
			var spawn_id: String = child.name.replace("SpawnPoint_", "")
			child.set_meta("spawn_id", spawn_id)
			if spawn_id == "default":
				child.add_to_group("default_spawn")


## Setup navigation mesh
func _setup_navigation() -> void:
	if not nav_region:
		nav_region = NavigationRegion3D.new()
		nav_region.name = "NavigationRegion3D"
		add_child(nav_region)

	var nav_mesh: NavigationMesh = NavigationMesh.new()
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
		print("[Kings Watch] Navigation mesh baked!")


## Spawn zone exit portals
func _spawn_zone_exits() -> void:
	var doors: Node3D = get_node_or_null("Doors")
	if not doors:
		doors = Node3D.new()
		doors.name = "Doors"
		add_child(doors)

	# South entrance - to Aberdeen region
	var south_portal: ZoneDoor = ZoneDoor.spawn_door(
		doors,
		Vector3(0, BASE_ELEVATION, 28),
		SceneManager.RETURN_TO_WILDERNESS,
		"from_kings_watch",
		"Mountain Path (to Aberdeen)"
	)
	south_portal.rotation.y = PI
	south_portal.show_frame = false
	south_portal.add_to_group("compass_poi")
	south_portal.set_meta("poi_id", "south_path")
	south_portal.set_meta("poi_name", "Aberdeen")
	south_portal.set_meta("poi_color", Color(0.6, 0.7, 0.8))

	# North exit - dangerous path deeper into mountains
	var north_portal: ZoneDoor = ZoneDoor.spawn_door(
		doors,
		Vector3(0, BASE_ELEVATION, -28),
		SceneManager.RETURN_TO_WILDERNESS,
		"from_kings_watch_north",
		"Ancient Path (Dangerous)"
	)
	north_portal.show_frame = false

	print("[Kings Watch] Spawned zone exits")


## Spawn enemies from EnemySpawnPoints markers
func _spawn_enemies() -> void:
	var enemy_spawn_points: Node3D = get_node_or_null("EnemySpawnPoints")
	if not enemy_spawn_points:
		push_warning("[Kings Watch] EnemySpawnPoints node not found")
		return

	var enemies_container: Node3D = get_node_or_null("Enemies")
	if not enemies_container:
		enemies_container = Node3D.new()
		enemies_container.name = "Enemies"
		add_child(enemies_container)

	var skeleton_texture: Texture2D = load("res://Sprite folders grab bag/skeleton_warrior.png")
	var bandit_texture: Texture2D = load("res://Sprite folders grab bag/bandit.png")

	var enemy_count: int = 0
	for child in enemy_spawn_points.get_children():
		if child is Marker3D:
			var enemy_data_path: String
			var texture: Texture2D
			var h_frames: int
			var v_frames: int

			if child.name.begins_with("Skeleton_"):
				enemy_data_path = "res://data/enemies/skeleton_warrior.tres"
				texture = skeleton_texture
				h_frames = 4
				v_frames = 4
			elif child.name.begins_with("Bandit_"):
				enemy_data_path = "res://data/enemies/bandit.tres"
				texture = bandit_texture
				h_frames = 4
				v_frames = 4
			else:
				continue

			if texture:
				var enemy: EnemyBase = EnemyBase.spawn_billboard_enemy(
					enemies_container,
					child.global_position,
					enemy_data_path,
					texture,
					h_frames,
					v_frames
				)

				if enemy:
					enemy.name = "RuinsEnemy_%d" % enemy_count
					enemy.behavior_mode = EnemyBase.BehaviorMode.WANDER
					enemy.wander_radius = 10.0
					enemy.leash_radius = 25.0
					enemy_count += 1

	print("[Kings Watch] Spawned %d enemies" % enemy_count)


## Spawn chests from ChestPositions markers
func _spawn_chests() -> void:
	var chest_positions: Node3D = get_node_or_null("ChestPositions")
	if not chest_positions:
		push_warning("[Kings Watch] ChestPositions node not found")
		return

	var interactables: Node3D = get_node_or_null("Interactables")
	if not interactables:
		interactables = Node3D.new()
		interactables.name = "Interactables"
		add_child(interactables)

	for marker in chest_positions.get_children():
		if marker is Marker3D:
			var chest_name: String = marker.get_meta("chest_name", "Chest")
			var is_locked: bool = marker.get_meta("is_locked", false)
			var lock_difficulty: int = marker.get_meta("lock_difficulty", 10)
			var persistent_id: String = marker.get_meta("persistent_id", "")

			Chest.spawn_chest(
				interactables,
				marker.global_position,
				chest_name,
				is_locked,
				lock_difficulty,
				true,  # randomize_loot
				persistent_id
			)

	print("[Kings Watch] Spawned chests")


## Setup light flickering effects
func _setup_light_effects() -> void:
	# Fire pit light in watchtower
	var watchtower: Node3D = get_node_or_null("RuinedWatchtower")
	if watchtower:
		var fire_light: OmniLight3D = watchtower.get_node_or_null("FireLight")
		if fire_light:
			_start_fire_flicker(fire_light, 3.0)

	# Torch sconces
	var props: Node3D = get_node_or_null("EnvironmentalProps")
	if props:
		for torch_node in ["TorchSconce_Left", "TorchSconce_Right"]:
			var torch: Node3D = props.get_node_or_null(torch_node)
			if torch:
				var light: OmniLight3D = torch.get_node_or_null("TorchLight")
				if light:
					_start_fire_flicker(light, 1.5)

	# Altar glow
	var altar: Node3D = get_node_or_null("EnvironmentalProps/StoneAltar")
	if altar:
		var glow: OmniLight3D = altar.get_node_or_null("AltarGlow")
		if glow:
			_start_eerie_pulse(glow)


func _start_fire_flicker(light: OmniLight3D, base_energy: float) -> void:
	var tween: Tween = create_tween()
	tween.set_loops()

	tween.tween_property(light, "light_energy", base_energy * 1.2, randf_range(0.1, 0.2))
	tween.tween_property(light, "light_energy", base_energy * 0.8, randf_range(0.1, 0.2))
	tween.tween_property(light, "light_energy", base_energy * 1.1, randf_range(0.15, 0.25))
	tween.tween_property(light, "light_energy", base_energy * 0.9, randf_range(0.1, 0.2))


func _start_eerie_pulse(light: OmniLight3D) -> void:
	var base_energy: float = light.light_energy
	var tween: Tween = create_tween()
	tween.set_loops()

	tween.tween_property(light, "light_energy", base_energy * 1.4, randf_range(1.5, 2.5))
	tween.tween_property(light, "light_energy", base_energy * 0.6, randf_range(1.5, 2.5))


## Get spawn point for scene transitions
func get_spawn_point(spawn_id: String) -> Node3D:
	var spawn_points: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points:
		return null

	for child in spawn_points.get_children():
		if child.name == spawn_id or child.name == "SpawnPoint_" + spawn_id:
			return child
		if child.get_meta("spawn_id", "") == spawn_id:
			return child

	return spawn_points.get_node_or_null("SpawnPoint_default")
