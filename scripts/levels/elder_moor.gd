## elder_moor.gd - Elder Moor (Logging Camp Starter Town)
## Small logging hamlet in the forests of Kreigstan - player's starting location
## Scene-based layout with runtime navigation baking and day/night cycle
extends Node3D

const ZONE_ID := "elder_moor"
const ZONE_SIZE := Vector2(242.0, 219.0)  # Actual scene dimensions (width, depth)
const ZONE_SIZE_LEGACY := 242.0  # For backwards compatibility (use larger dimension)

## Town center radius - buildings are kept within this area
const TOWN_RADIUS := 80.0  # Expanded for larger scene

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	# Only register with PlayerGPS if we're the main scene (have Player node)
	# When loaded as a streaming cell, Player is stripped - don't touch GPS
	var is_main_scene: bool = get_node_or_null("Player") != null

	if is_main_scene:
		if PlayerGPS:
			PlayerGPS.set_position(Vector2i.ZERO, true)  # Elder Moor is at (0, 0), skip_discovery=true (already handled by reset)
		# Legacy starter quest disabled - using new quest system
		#_start_starter_quest()

	_setup_navigation()
	if is_main_scene:
		_setup_day_night_cycle()
	_setup_spawn_point_metadata()
	_generate_terrain_collision()
	_spawn_enemy_spawners()
	_spawn_harvestable_herbs()
	_spawn_civilian_population()
	# Spawn tutorial NPCs (Grom, Martha, Brennan) with correct sprites
	_spawn_tutorial_npcs()

	# Register with CellStreamer and start streaming
	_setup_cell_streaming()

	print("[Elder Moor] Logging camp initialized")


## Legacy starter quest - disabled, using new quest system
#func _start_starter_quest() -> void:
#	if not QuestManager:
#		return
#
#	# Only start if not already active or completed
#	if not QuestManager.quests.has("road_to_thornfield"):
#		if QuestManager.start_quest("road_to_thornfield"):
#			print("[Elder Moor] Started starter quest: Road to Thornfield")


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


## Generate collision shapes for terrain and building meshes
func _generate_terrain_collision() -> void:
	# Find the terrain node
	var terrain := get_node_or_null("Terrain/ElderMoorTerrain")
	if terrain:
		_add_collision_to_meshes(terrain)
		print("[Elder Moor] Generated collision for terrain")

	# Also check for any modular house GLB instances
	var buildings := get_node_or_null("Buildings")
	if buildings:
		_add_collision_to_meshes(buildings)


## Recursively add collision to all MeshInstance3D nodes
func _add_collision_to_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		# Check if collision already exists
		var has_collision := false
		for child in mesh_instance.get_children():
			if child is StaticBody3D:
				has_collision = true
				break

		if not has_collision and mesh_instance.mesh:
			# Create static body with trimesh collision
			mesh_instance.create_trimesh_collision()

	# Recurse into children
	for child in node.get_children():
		_add_collision_to_meshes(child)


## Spawn enemy spawners at marker positions in the wilderness
## Only spawns 1 goblin totem (randomly selected) with patrolling goblins
func _spawn_enemy_spawners() -> void:
	var spawners_container := get_node_or_null("EnemySpawners")
	if not spawners_container:
		return

	var goblin_markers: Array[Node] = []
	var wolf_markers: Array[Node] = []

	# Sort markers by type
	for marker in spawners_container.get_children():
		if "Goblin" in marker.name:
			goblin_markers.append(marker)
		elif "Wolf" in marker.name:
			wolf_markers.append(marker)

	# Only spawn 1 goblin totem (randomly selected) with more goblins that patrol
	if goblin_markers.size() > 0:
		var chosen_idx: int = randi() % goblin_markers.size()
		var marker: Node = goblin_markers[chosen_idx]

		var spawner := EnemySpawner.new()
		spawner.position = marker.global_position
		spawner.spawner_id = "goblin_totem_main"
		spawner.display_name = "Goblin Totem"
		spawner.max_hp = 600  # Slightly tougher since it's the only one
		spawner.armor_value = 8
		spawner.spawn_interval_min = 45.0  # Slower spawning
		spawner.spawn_interval_max = 60.0
		spawner.max_spawned_enemies = 8  # More max goblins since it's the only totem
		spawner.spawn_count_min = 1
		spawner.spawn_count_max = 2
		spawner.spawned_wander_radius = 40.0  # Much larger wander radius for patrols
		spawner.spawned_leash_radius = 80.0   # Allow goblins to roam far
		spawner.spawned_patrol_radius = 50.0  # Large patrol radius for cell-spanning patrols
		spawner.enable_patrols = true         # Enable patrol behavior
		spawner.enemy_data_path = "res://data/enemies/goblin_soldier.tres"
		spawner.secondary_enemy_enabled = true
		spawner.secondary_enemy_chance = 0.25
		spawner.secondary_data_path = "res://data/enemies/goblin_archer.tres"
		spawner.tertiary_enemy_enabled = true
		spawner.tertiary_enemy_chance = 0.10
		spawner.tertiary_data_path = "res://data/enemies/goblin_mage.tres"

		add_child(spawner)
		print("[Elder Moor] Spawned single goblin totem at %s with patrol radius" % marker.global_position)

	# Spawn wolf dens (keep all of them but reduce count)
	for marker in wolf_markers:
		var spawner := EnemySpawner.new()
		spawner.position = marker.global_position
		spawner.spawner_id = "wolf_den_%s" % marker.name.to_lower()
		spawner.display_name = "Wolf Den"
		spawner.max_hp = 250
		spawner.armor_value = 3
		spawner.spawn_interval_min = 60.0  # Slower spawning
		spawner.spawn_interval_max = 90.0
		spawner.max_spawned_enemies = 3  # Fewer wolves
		spawner.spawn_count_min = 1
		spawner.spawn_count_max = 1
		spawner.spawned_wander_radius = 25.0  # Wolves patrol their territory
		spawner.spawned_leash_radius = 40.0
		spawner.enemy_data_path = "res://data/enemies/wolf.tres"
		spawner.secondary_enemy_enabled = false

		add_child(spawner)
		print("[Elder Moor] Spawned wolf den at %s" % marker.global_position)

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


## Spawn ~20 civilian NPCs that wander around from 9am to 9pm
func _spawn_civilian_population() -> void:
	var civilians_container := Node3D.new()
	civilians_container.name = "CivilianPopulation"
	add_child(civilians_container)

	# Spawn area definitions for Elder Moor logging camp
	# Each area: center position, spawn radius, number of NPCs
	var spawn_areas: Array[Dictionary] = [
		# Central camp area (near general shop and cabins)
		{"pos": Vector3(-5, 0, 10), "radius": 8.0, "count": 4},
		# Foreman's cabin area
		{"pos": Vector3(-12, 0, -28), "radius": 6.0, "count": 2},
		# Worker cabin area (east side)
		{"pos": Vector3(15, 0, -5), "radius": 5.0, "count": 3},
		# Worker cabin area (west/central)
		{"pos": Vector3(-8, 0, 20), "radius": 6.0, "count": 3},
		# Sawmill area (south)
		{"pos": Vector3(5, 0, 50), "radius": 10.0, "count": 5},
		# Sawmill area (north)
		{"pos": Vector3(26, 0, -22), "radius": 6.0, "count": 3},
	]

	var total_spawned: int = 0

	for spawn_def: Dictionary in spawn_areas:
		var center: Vector3 = spawn_def["pos"]
		var radius: float = spawn_def["radius"]
		var count: int = spawn_def["count"]

		for i in range(count):
			# Random position within radius
			var angle: float = randf() * TAU
			var dist: float = randf() * radius
			var spawn_pos := Vector3(
				center.x + cos(angle) * dist,
				0.0,
				center.z + sin(angle) * dist
			)

			# Spawn random civilian type (loggers, workers - no nobles/gladiators)
			var npc: CivilianNPC = CivilianNPC.spawn_worker_random(
				civilians_container,
				spawn_pos,
				ZONE_ID
			)

			# Configure wander behavior - loggers move around their work area
			npc.wander_radius = radius * 0.8
			npc.wander_speed = randf_range(1.2, 2.0)

			total_spawned += 1

	print("[Elder Moor] Spawned %d civilian NPCs (loggers and workers)" % total_spawned)

	# Store reference for day/night management
	set_meta("civilians_container", civilians_container)

	# Connect to GameManager's time of day changes for visibility management
	if GameManager:
		GameManager.time_of_day_changed.connect(_on_time_of_day_changed)
		# Initial visibility check
		_update_civilian_visibility()


## Called when time of day changes
func _on_time_of_day_changed(_new_time: Enums.TimeOfDay) -> void:
	_update_civilian_visibility()


## Show/hide civilians based on time of day (active during daytime: DAWN through DUSK)
func _update_civilian_visibility() -> void:
	var civilians_container: Node3D = get_meta("civilians_container", null) as Node3D
	if not civilians_container:
		return

	var current_time: Enums.TimeOfDay = GameManager.current_time_of_day if GameManager else Enums.TimeOfDay.NOON

	# Civilians active during daytime hours (DAWN through DUSK, not NIGHT or MIDNIGHT)
	var is_daytime: bool = current_time in [
		Enums.TimeOfDay.DAWN,
		Enums.TimeOfDay.MORNING,
		Enums.TimeOfDay.NOON,
		Enums.TimeOfDay.AFTERNOON,
		Enums.TimeOfDay.DUSK
	]

	for child in civilians_container.get_children():
		if child is CivilianNPC:
			child.visible = is_daytime
			child.set_physics_process(is_daytime)
			child.set_process(is_daytime)
			# Enable/disable wandering
			if child.wander:
				child.wander.set_physics_process(is_daytime)


## Spawn NPCs (merchants, quest givers, civilians)
func _spawn_npcs() -> void:
	# Spawn general merchant inside the GeneralShop building
	# Building is at (-12, 0, 5), place merchant inside facing the open front
	var general_shop_pos := Vector3(-12.0, 0.0, 4.0)  # Slightly forward in the shop
	var merchant := Merchant.spawn_merchant(
		self,
		general_shop_pos,
		"Grimwald",  # Name
		LootTables.LootTier.COMMON,  # Starter town has basic goods
		"general"  # General store type
	)
	merchant.merchant_id = "grimwald_eldermoor"
	merchant.region_id = "elder_moor"
	print("[Elder Moor] Spawned merchant: Grimwald at GeneralShop")

	# Spawn Tharin Ironbeard near the ForemansCabin
	# ForemansCabin is at (-15, 0, -10), place Tharin in front of it
	var tharin_scene: PackedScene = load("res://scenes/npcs/tharin_ironbeard_instance.tscn")
	if tharin_scene:
		var tharin: TharinIronbeard = tharin_scene.instantiate()
		tharin.position = Vector3(-15.0, 0.0, -7.0)  # In front of ForemansCabin
		add_child(tharin)
		print("[Elder Moor] Spawned NPC: Tharin Ironbeard at ForemansCabin")
	else:
		push_warning("[Elder Moor] Failed to load tharin_ironbeard_instance.tscn")

	# Old Harlan disabled - no quests configured yet
	# Uncomment when quest giver has quests to offer
	#var quest_giver_pos := Vector3(3.0, 0.0, 2.0)
	#var quest_giver := QuestGiver.spawn_quest_giver(
	#	self, quest_giver_pos, "Old Harlan", "old_harlan_eldermoor",
	#	null, 8, 2
	#)
	#quest_giver.region_id = "elder_moor"


## Spawn crafting stations (blacksmith anvil, cooking fire, alchemy table)
func _spawn_crafting_stations() -> void:
	# Blacksmith anvil - near the forge/blacksmith area
	# Position next to Grom the Smith's workspace
	var anvil_pos := Vector3(-8.0, 0.0, -12.0)
	var anvil := RepairStation.spawn_station(self, anvil_pos)
	print("[Elder Moor] Spawned blacksmith anvil at %s" % anvil_pos)

	# Cooking fire - south of the elder moor terrain
	# Position at the gathering area where travelers rest
	var cooking_pos := Vector3(5.0, 0.0, 30.0)
	var cooking := CookingStation.spawn_cooking_station(self, cooking_pos)
	print("[Elder Moor] Spawned cooking station at %s" % cooking_pos)

	# Alchemy table - near the herbalist's tent/workspace
	# Position where Old Sage Brennan works
	var alchemy_pos := Vector3(10.0, 0.0, -5.0)
	var alchemy := AlchemyStation.spawn_alchemy_station(self, alchemy_pos)
	print("[Elder Moor] Spawned alchemy station at %s" % alchemy_pos)


## Spawn tutorial quest giver NPCs
func _spawn_tutorial_npcs() -> void:
	# Grom the Smith - blacksmith tutorial quest giver
	# Positioned near the anvil
	var grom_pos := Vector3(-10.0, 0.0, -12.0)
	var grom_quests: Array[String] = ["tutorial_crafting"]
	var grom_sprite: Texture2D = load("res://assets/sprites/npcs/blacksmith.png")
	var grom := QuestGiver.spawn_quest_giver(
		self,
		grom_pos,
		"Grom the Smith",
		"grom_the_smith",
		grom_sprite,
		5, 1,  # 5 horizontal frames (hammering animation), 1 row
		grom_quests
	)
	grom.region_id = "elder_moor"
	grom.faction_id = "human_empire"
	grom.generic_dialogues = {
		"offer": "Hail, traveler! I am Grom, the village smith.\nI can teach you the basics of metalworking if you're interested.\nI've got some spare iron - craft yourself a dagger at my anvil.",
		"active": "Have you crafted that iron dagger yet?\nThe anvil is right there - just use it and select the dagger recipe.",
		"complete": "Well done! That's a fine piece of work for a beginner.\nHere, take this repair kit - you'll need it to maintain your gear."
	}
	print("[Elder Moor] Spawned tutorial NPC: Grom the Smith")

	# Martha the Cook - cooking tutorial quest giver
	# Positioned near the cooking fire
	var martha_pos := Vector3(3.0, 0.0, 8.0)
	var martha_quests: Array[String] = ["tutorial_cooking"]
	var martha_sprite: Texture2D = load("res://assets/sprites/npcs/martha_cook.png")
	var martha := QuestGiver.spawn_quest_giver(
		self,
		martha_pos,
		"Martha",
		"martha_cook",
		martha_sprite,
		4, 1,  # 4 horizontal frames, 1 row
		martha_quests,
		false,  # is_talk_target
		0.018   # pixel_size - smaller for cook sprite
	)
	martha.region_id = "elder_moor"
	martha.faction_id = "human_empire"
	martha.generic_dialogues = {
		"offer": "Oh, hello dear! You look like you could use a good meal.\nI can teach you to cook if you'd like - it's a useful skill for any adventurer.\nHere's some raw meat. Cook it over the fire there.",
		"active": "Just use the cooking fire and roast that meat.\nNothing fancy, but it'll keep you alive out there.",
		"complete": "There you go! Simple but effective.\nTake these stews I made - they'll restore both health and stamina."
	}
	print("[Elder Moor] Spawned tutorial NPC: Martha")

	# Old Sage Brennan - alchemy tutorial quest giver
	# Positioned near the alchemy table
	var brennan_pos := Vector3(8.0, 0.0, -5.0)
	var brennan_quests: Array[String] = ["tutorial_alchemy"]
	var brennan_sprite: Texture2D = load("res://assets/sprites/npcs/old_man_sage.png")
	var brennan := QuestGiver.spawn_quest_giver(
		self,
		brennan_pos,
		"Old Sage Brennan",
		"sage_brennan",
		brennan_sprite,
		2, 1,  # 2 horizontal frames, 1 row
		brennan_quests
	)
	brennan.region_id = "elder_moor"
	brennan.faction_id = "human_empire"
	brennan.generic_dialogues = {
		"offer": "Ah, a young soul seeking knowledge. I am Brennan, the village herbalist.\nAlchemy is a powerful art - the ability to brew potions can save your life.\nI'll give you the ingredients to make a basic healing potion. Use the alchemy table.",
		"active": "The alchemy table is there. Combine two red herbs with an empty vial.\nThe art of potion-making requires patience and precision.",
		"complete": "Excellent work! You have a steady hand.\nHere, take these supplies - a mana potion and some vials for your future brews."
	}
	print("[Elder Moor] Spawned tutorial NPC: Old Sage Brennan")
