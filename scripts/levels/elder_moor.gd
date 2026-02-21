## elder_moor.gd - Elder Moor (Logging Camp Starter Town)
## Small logging hamlet in the forests of Kreigstan - player's starting location
## Scene-based layout with runtime navigation baking and day/night cycle
extends Node3D

const ZONE_ID := "elder_moor"
const ZONE_SIZE := 100.0  # Matches WorldGrid.CELL_SIZE

## Town center radius - buildings are kept within this area
const TOWN_RADIUS := 35.0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	# Register with PlayerGPS
	if PlayerGPS:
		PlayerGPS.set_position(Vector2i.ZERO)  # Elder Moor is at (0, 0)

	_setup_navigation()
	_setup_day_night_cycle()
	_setup_spawn_point_metadata()
	_spawn_enemy_spawners()
	_spawn_harvestable_herbs()

	# Register with CellStreamer and start streaming
	_setup_cell_streaming()

	# Start the Road to Thornfield quest automatically for new players
	_start_starter_quest()

	print("[Elder Moor] Logging camp initialized")


## Start the introductory quest to guide players east to Thornfield
func _start_starter_quest() -> void:
	if not QuestManager:
		return

	# Only start if not already active or completed
	if not QuestManager.quests.has("road_to_thornfield"):
		if QuestManager.start_quest("road_to_thornfield"):
			print("[Elder Moor] Started starter quest: Road to Thornfield")


## Register this scene with CellStreamer and start streaming
func _setup_cell_streaming() -> void:
	if not CellStreamer:
		push_warning("[Elder Moor] CellStreamer not found")
		return

	# Register this scene as the MAIN SCENE cell at (0, 0)
	# This tells CellStreamer that Elder Moor is already loaded AND should never be unloaded
	# (it contains the WorldEnvironment and lighting for the entire world)
	var my_coords: Vector2i = Vector2i.ZERO
	CellStreamer.register_main_scene_cell(my_coords, self)

	# Start streaming from this cell - this will load adjacent wilderness cells
	CellStreamer.start_streaming(my_coords)


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Elder Moor] NavigationRegion3D not found in scene")
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
		print("[Elder Moor] Navigation mesh baked")


## Setup dynamic day/night lighting
func _setup_day_night_cycle() -> void:
	DayNightCycle.add_to_level(self)


## Add metadata to spawn points for proper identification
func _setup_spawn_point_metadata() -> void:
	var spawn_points := get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	for child in spawn_points.get_children():
		if child.is_in_group("spawn_points"):
			child.set_meta("spawn_id", child.name)


## Spawn enemy spawners at marker positions in the wilderness
func _spawn_enemy_spawners() -> void:
	var spawners_container := get_node_or_null("EnemySpawners")
	if not spawners_container:
		return

	for marker in spawners_container.get_children():
		var spawner := EnemySpawner.new()
		spawner.position = marker.global_position

		# Configure based on marker name
		if "Goblin" in marker.name:
			spawner.spawner_id = "goblin_totem_%s" % marker.name.to_lower()
			spawner.display_name = "Goblin Totem"
			spawner.max_hp = 500  # Starter level - easier to destroy
			spawner.armor_value = 5
			spawner.spawn_interval_min = 30.0
			spawner.spawn_interval_max = 45.0
			spawner.max_spawned_enemies = 6
			spawner.spawn_count_min = 1
			spawner.spawn_count_max = 2
			spawner.enemy_data_path = "res://data/enemies/goblin_soldier.tres"
			spawner.secondary_enemy_enabled = true
			spawner.secondary_enemy_chance = 0.3
			spawner.secondary_data_path = "res://data/enemies/goblin_archer.tres"
			spawner.secondary_sprite_path = "res://assets/sprites/enemies/goblin_archer.png"
		elif "Wolf" in marker.name:
			spawner.spawner_id = "wolf_den_%s" % marker.name.to_lower()
			spawner.display_name = "Wolf Den"
			spawner.max_hp = 300
			spawner.armor_value = 3
			spawner.spawn_interval_min = 40.0
			spawner.spawn_interval_max = 60.0
			spawner.max_spawned_enemies = 4
			spawner.spawn_count_min = 1
			spawner.spawn_count_max = 2
			spawner.enemy_data_path = "res://data/enemies/wolf.tres"
			spawner.secondary_enemy_enabled = false

		add_child(spawner)
		print("[Elder Moor] Spawned enemy spawner: %s at %s" % [spawner.display_name, marker.global_position])

	# Remove the marker container since we no longer need it
	spawners_container.queue_free()


## Spawn harvestable herb plants at marker positions
func _spawn_harvestable_herbs() -> void:
	var herbs_container := get_node_or_null("HarvestableHerbs")
	if not herbs_container:
		return

	for marker in herbs_container.get_children():
		var herb := HarvestablePlant.spawn_plant(
			self,
			marker.global_position,
			"red_herb",
			"Red Herb",
			1
		)
		print("[Elder Moor] Spawned herb at %s" % marker.global_position)

	# Remove the marker container
	herbs_container.queue_free()
