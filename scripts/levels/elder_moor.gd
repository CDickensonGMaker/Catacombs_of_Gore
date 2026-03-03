## elder_moor.gd - Elder Moor (Logging Camp Starter Town)
## Small logging hamlet in the forests of Kreigstan - player's starting location
## Scene-based layout with runtime navigation baking and day/night cycle
extends Node3D

## Emitted when navigation mesh is fully baked and ready for use
signal navigation_ready

const IntroDialogueUIScript = preload("res://scripts/ui/intro_dialogue_ui.gd")

const ZONE_ID := "elder_moor"
const ZONE_SIZE := Vector2(242.0, 219.0)  # Actual scene dimensions (width, depth)
const ZONE_SIZE_LEGACY := 242.0  # For backwards compatibility (use larger dimension)
const TOWN_AMBIENT_PATH := "res://assets/audio/Ambiance/towns/town_murmur_medieval_mix_60s_ps1_retro.wav"

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
		# Play town ambient sound and village music
		AudioManager.play_ambient(TOWN_AMBIENT_PATH)
		AudioManager.play_zone_music("village")

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
	# Spawn locked doors from markers (place LockedDoors container with Marker3D children in .tscn)
	_spawn_locked_doors()
	# Spawn thieves that lurk in the area
	_spawn_thieves()

	# Spawn fall leaves on the ground for forest atmosphere
	_spawn_fall_leaves()

	# Register with CellStreamer and start streaming
	_setup_cell_streaming()

	# Check if we should show the intro dialogue (new game only)
	if is_main_scene:
		_check_intro_dialogue()

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

	# Check if we're loading from a save with pending cell data
	# If so, use the saved cell coordinates instead of (0,0)
	var start_coords: Vector2i = Vector2i.ZERO
	if SaveManager and SaveManager.has_pending_cell_data():
		start_coords = SaveManager.get_pending_cell_coords()
		print("[Elder Moor] Loading from save - starting streaming at cell (%d, %d)" % [start_coords.x, start_coords.y])

	# Register this scene as the MAIN SCENE cell at (0, 0)
	# This tells CellStreamer that Elder Moor is already loaded AND should never be unloaded
	# (it contains the WorldEnvironment and lighting for the entire world)
	CellStreamer.register_main_scene_cell(Vector2i.ZERO, self)

	# Start streaming from the correct cell (saved position or default 0,0)
	CellStreamer.start_streaming(start_coords)


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
		# Wait for NavigationServer3D to synchronize (needs physics frames)
		await get_tree().physics_frame
		await get_tree().physics_frame
		navigation_ready.emit()
		print("[Elder Moor] Navigation ready signal emitted")


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


## Spawn fall leaves as ground decoration for forest atmosphere
func _spawn_fall_leaves() -> void:
	# Fall leaf textures
	var leaf_textures: Array[String] = [
		"res://assets/sprites/environment/ground/leaves_full.png",
		"res://assets/sprites/environment/ground/leaves_half.png"
	]

	# Container for leaves
	var leaves_container := Node3D.new()
	leaves_container.name = "FallLeaves"
	add_child(leaves_container)

	# Spawn leaves across the area (avoiding buildings)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("elder_moor_leaves")

	var leaf_count: int = 150  # Number of leaf patches

	for i in range(leaf_count):
		# Random position within town bounds
		var x: float = rng.randf_range(-TOWN_RADIUS * 1.2, TOWN_RADIUS * 1.2)
		var z: float = rng.randf_range(-TOWN_RADIUS * 1.2, TOWN_RADIUS * 1.2)

		# Skip center area where buildings are dense
		var dist_from_center: float = Vector2(x, z).length()
		if dist_from_center < 15.0:
			continue

		# Load random leaf texture
		var tex_path: String = leaf_textures[rng.randi() % leaf_textures.size()]
		var tex: Texture2D = load(tex_path)
		if not tex:
			continue

		# Create leaf decal sprite
		var leaf := Sprite3D.new()
		leaf.name = "LeafPatch_%d" % i
		leaf.texture = tex
		leaf.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 style

		# Lay flat on ground
		leaf.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		leaf.rotation_degrees.x = -90  # Face up

		# Random rotation around Y
		leaf.rotation_degrees.y = rng.randf() * 360.0

		# Random scale
		var scale_factor: float = rng.randf_range(0.015, 0.035)
		leaf.pixel_size = scale_factor

		# Position slightly above ground to avoid z-fighting
		leaf.position = Vector3(x, 0.02, z)

		# Autumn tint variations
		var tint_roll: float = rng.randf()
		if tint_roll < 0.3:
			leaf.modulate = Color(1.0, 0.85, 0.6)  # Golden yellow
		elif tint_roll < 0.6:
			leaf.modulate = Color(0.9, 0.5, 0.3)  # Orange-brown
		else:
			leaf.modulate = Color(0.8, 0.4, 0.25)  # Rusty red-brown

		leaves_container.add_child(leaf)

	print("[Elder Moor] Spawned %d fall leaf patches" % leaf_count)


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

			# Add zone-specific knowledge to civilians for town-appropriate dialogue
			if not npc.knowledge_profile:
				npc.knowledge_profile = NPCKnowledgeProfile.generic_villager()
			npc.knowledge_profile.knowledge_tags.append(ZONE_ID)
			npc.knowledge_profile.knowledge_tags.append("local_area")

			total_spawned += 1

	print("[Elder Moor] Spawned %d civilian NPCs (loggers and workers)" % total_spawned)

	# Store reference for day/night management
	set_meta("civilians_container", civilians_container)

	# Connect to GameManager's time of day changes for visibility management
	if GameManager:
		GameManager.time_of_day_changed.connect(_on_time_of_day_changed)
		# Defer initial visibility check to ensure scene is fully loaded (fixes fast travel/save load issues)
		call_deferred("_update_civilian_visibility")


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


## Spawn locked doors from markers placed in the scene
## Add a Node3D container called "LockedDoors" with Marker3D children
## Set metadata on each marker: door_name (String), lock_dc (int)
func _spawn_locked_doors() -> void:
	var doors_container := get_node_or_null("LockedDoors")
	if not doors_container:
		return

	var doors_spawned: int = 0
	for marker in doors_container.get_children():
		if not marker is Marker3D:
			continue

		var door_name: String = marker.get_meta("door_name", "Locked Door")
		var lock_dc: int = marker.get_meta("lock_dc", 12)

		var door := LockableDoor.spawn_door(
			self,
			marker.global_position,
			door_name,
			lock_dc
		)
		door.rotation = marker.rotation
		doors_spawned += 1

	if doors_spawned > 0:
		print("[Elder Moor] Spawned %d locked doors from markers" % doors_spawned)


## Spawn thieves that lurk around looking to pickpocket
func _spawn_thieves() -> void:
	# Elder Moor is a small logging camp - low chance of thieves
	# Only spawn 1 thief occasionally (25% chance)
	if randf() > 0.25:
		return

	# Spawn near the edges of town where it's less populated
	var thief_positions: Array[Vector3] = [
		Vector3(20, 0, 35),   # Near sawmill (busy, easy to blend in)
		Vector3(-15, 0, 25),  # Near worker cabins
	]

	var spawn_pos: Vector3 = thief_positions[randi() % thief_positions.size()]
	var thief := ThiefNPC.spawn_thief(self, spawn_pos, ZONE_ID, 4)  # Low skill (4)
	print("[Elder Moor] A suspicious figure lurks nearby...")


## Spawn NPCs (merchants, quest givers, civilians)
## NOTE: Most NPCs are pre-placed in the scene file (elder_moor.tscn)
## This function only handles runtime-only spawns not in the scene
func _spawn_npcs() -> void:
	# All main NPCs (Grimwald, Tharin, Grom, Brennan) are now placed in the scene file
	# This avoids duplicates and allows precise positioning in the editor
	pass


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
## NOTE: Grom and Brennan are pre-placed in elder_moor.tscn
## Martha the Cook is spawned via code to avoid sprite sheet corruption issues
func _spawn_tutorial_npcs() -> void:
	# =========================================================================
	# IMPORTANT: These NPCs MUST be spawned via code, NOT placed in scene
	# Adding them directly to elder_moor.tscn causes sprite sheet corruption.
	# DO NOT remove this code or move them to the scene file!
	# =========================================================================
	_spawn_martha_the_cook()
	_spawn_varn_the_scarred()


## ============================================================================
## MARTHA THE COOK - Tutorial Cooking Quest Giver
## ============================================================================
## IMPORTANT: DO NOT DELETE THIS FUNCTION OR MOVE MARTHA TO THE SCENE FILE!
## Her sprite sheet gets corrupted when added directly to elder_moor.tscn.
## She MUST be spawned via code to display correctly.
## ============================================================================
func _spawn_martha_the_cook() -> void:
	# Load Martha's sprite texture
	var martha_sprite: Texture2D = load("res://assets/sprites/npcs/named/martha_cook.png")
	if not martha_sprite:
		push_error("[Elder Moor] Failed to load Martha the Cook sprite!")
		return

	# Position near the cooking fire (5.5, 0, 12.0)
	var martha_pos := Vector3(5.5, 0.0, 12.0)

	# Spawn using QuestGiver factory method
	var martha: QuestGiver = QuestGiver.spawn_quest_giver(
		self,                          # parent
		martha_pos,                    # position
		"Martha the Cook",             # display_name
		"martha_cook",                 # npc_id
		martha_sprite,                 # custom_sprite
		4,                             # h_frames (4 frame animation)
		1,                             # v_frames (single row)
		["tutorial_cooking"]           # quest_ids
	)

	if martha:
		martha.region_id = "elder_moor"
		print("[Elder Moor] Spawned Martha the Cook at %s (via code - sprite fix)" % martha_pos)
	else:
		push_error("[Elder Moor] Failed to spawn Martha the Cook!")


## ============================================================================
## VARN THE SCARRED - Arena Quest Giver (Retired Gladiator)
## ============================================================================
## IMPORTANT: DO NOT DELETE THIS FUNCTION OR MOVE VARN TO THE SCENE FILE!
## His sprite sheet gets corrupted when added directly to elder_moor.tscn.
## He MUST be spawned via code to display correctly.
## ============================================================================
func _spawn_varn_the_scarred() -> void:
	# Load Varn's sprite texture (gladiator sprite)
	var varn_sprite: Texture2D = load("res://assets/sprites/npcs/combat/male_gladiator1.png")
	if not varn_sprite:
		push_error("[Elder Moor] Failed to load Varn the Scarred sprite!")
		return

	# Position near the camp (same as scene placement: 6.5, 0, 10.5)
	var varn_pos := Vector3(6.5, 0.0, 10.5)

	# Spawn using QuestGiver factory method
	var varn: QuestGiver = QuestGiver.spawn_quest_giver(
		self,                          # parent
		varn_pos,                      # position
		"Varn the Scarred",            # display_name
		"varn_the_scarred",            # npc_id
		varn_sprite,                   # custom_sprite
		1,                             # h_frames (single frame - 48x96)
		1,                             # v_frames (single row)
		["meet_the_arena_master"]      # quest_ids
	)

	if varn:
		varn.region_id = "elder_moor"
		varn.faction_id = "human_empire"
		# Give him a knowledge profile for conversation
		var varn_profile := NPCKnowledgeProfile.new()
		varn_profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
		varn_profile.personality_traits = ["gruff", "battle-hardened", "nostalgic"]
		varn_profile.knowledge_tags = ["elder_moor", "arena", "combat", "bloodsand_arena"]
		varn_profile.base_disposition = 50
		varn.npc_profile = varn_profile
		print("[Elder Moor] Spawned Varn the Scarred at %s (via code - sprite fix)" % varn_pos)
	else:
		push_error("[Elder Moor] Failed to spawn Varn the Scarred!")


# =============================================================================
# INTRO DIALOGUE SYSTEM
# =============================================================================

## Check if intro dialogue should be shown (new game, first time in Elder Moor)
func _check_intro_dialogue() -> void:
	# Don't show if DialogueManager isn't ready
	if not DialogueManager:
		return

	# Check if intro has already been shown
	if DialogueManager.has_flag("intro_shown"):
		return

	# Don't show if dialogue is already active
	if DialogueManager.is_dialogue_active:
		return

	# Don't show if player data isn't available
	if not GameManager or not GameManager.player_data:
		return

	# Defer the actual dialogue display to ensure scene is fully ready
	call_deferred("_show_intro_dialogue")


## Build and display the intro dialogue based on player race and career
## Uses centered IntroDialogueUI instead of standard DialogueBox
func _show_intro_dialogue() -> void:
	# Double-check flag hasn't been set in the meantime
	if DialogueManager.has_flag("intro_shown"):
		return

	# Get player race and career
	var player_race: Enums.Race = GameManager.player_data.race
	var player_career: Enums.Career = GameManager.player_data.career

	# Build the dialogue
	var intro_dialogue_result: Variant = IntroDialogueBuilder.build_intro_dialogue(player_race, player_career)

	if intro_dialogue_result == null or not intro_dialogue_result is DialogueData:
		push_error("[Elder Moor] Failed to build intro dialogue")
		# Set flag anyway to prevent repeated failures
		DialogueManager.set_flag("intro_shown")
		return

	# Cast to DialogueData (safe after type check above)
	var intro_dialogue: DialogueData = intro_dialogue_result as DialogueData

	# Set the flag BEFORE showing dialogue to prevent double-showing
	DialogueManager.set_flag("intro_shown")

	# Get the intro text from the dialogue node
	var intro_text: String = ""
	if intro_dialogue.nodes.size() > 0:
		intro_text = intro_dialogue.nodes[0].text

	if intro_text.is_empty():
		push_error("[Elder Moor] Intro dialogue has no text")
		return

	# Create and show the centered intro UI
	var intro_ui: Node = IntroDialogueUIScript.new()
	add_child(intro_ui)
	intro_ui.dialogue_finished.connect(_on_intro_dialogue_finished.bind(intro_ui))
	intro_ui.show_intro(intro_text)

	print("[Elder Moor] Showing intro dialogue for %s %s" % [
		Enums.Race.keys()[player_race],
		Enums.Career.keys()[player_career]
	])


## Called when intro dialogue is dismissed
func _on_intro_dialogue_finished(intro_ui: Node) -> void:
	if intro_ui:
		intro_ui.queue_free()
	print("[Elder Moor] Intro dialogue finished")
