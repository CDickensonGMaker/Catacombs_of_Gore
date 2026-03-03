## millbrook.gd - Mill Brook Hamlet
## Simple farming/milling hamlet between Dalhurst and Kazan-Dun
## Runtime-only logic - geometry is pre-placed in millbrook.tscn
extends Node3D

const ZONE_ID := "millbrook"
const ZONE_SIZE := 100.0  # Matches WorldGrid.CELL_SIZE
const TOWN_AMBIENT_PATH := "res://assets/audio/Ambiance/towns/town_murmur_medieval_mix_60s_ps1_retro.wav"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	# Only register with PlayerGPS if we're the main scene (have Player node)
	# When loaded as a streaming cell, Player is stripped - don't touch GPS
	var is_main_scene: bool = get_node_or_null("Player") != null

	if is_main_scene:
		if PlayerGPS:
			var coords := WorldGrid.get_location_coords(ZONE_ID)
			PlayerGPS.set_position(coords)
		SaveManager.set_current_zone(ZONE_ID, "Mill Brook")
		DayNightCycle.add_to_level(self)
		# Play town ambient sound and village music
		AudioManager.play_ambient(TOWN_AMBIENT_PATH)
		AudioManager.play_zone_music("village")

	_setup_spawn_points()
	_spawn_merchants()
	_spawn_npcs()
	_spawn_fast_travel_shrine()
	_spawn_rest_spot()
	_spawn_locked_doors()
	_setup_navigation()
	_setup_cell_streaming()
	print("[Mill Brook] Farming hamlet loaded")


## Register pre-placed spawn points with groups and metadata
func _setup_spawn_points() -> void:
	var spawn_points_node: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points_node:
		return

	for child in spawn_points_node.get_children():
		if child is Marker3D:
			var spawn_id: String = child.name.replace("SpawnPoint_", "")
			child.add_to_group("spawn_points")
			child.set_meta("spawn_id", spawn_id)
			if spawn_id == "default":
				child.add_to_group("default_spawn")


## Spawn merchants at NPC marker positions
func _spawn_merchants() -> void:
	var merchant_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_Merchant")
	var pos: Vector3 = merchant_marker.global_position if merchant_marker else Vector3(3, 0, 6)

	Merchant.spawn_merchant(
		self,
		pos,
		"Hamlet General Store",
		LootTables.LootTier.COMMON,
		"general"
	)
	print("[Mill Brook] Spawned general store merchant")


## Spawn NPCs at marker positions
func _spawn_npcs() -> void:
	# Miller NPC (near the water mill)
	var miller_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_MillerOswin")
	var miller_pos: Vector3 = miller_marker.global_position if miller_marker else Vector3(-5, 0, -10)

	var miller := QuestGiver.new()
	miller.display_name = "Miller Oswin"
	miller.npc_id = "miller_oswin"
	miller.quest_ids = []
	miller.faction_id = "human_empire"
	miller.no_quest_dialogue = "Welcome to Mill Brook, traveler.\nOur mill grinds grain for the whole region.\nThe brook has powered this wheel for generations."
	miller.position = miller_pos
	add_child(miller)

	# Farmer NPC
	var farmer_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_FarmerEdda")
	var farmer_pos: Vector3 = farmer_marker.global_position if farmer_marker else Vector3(12, 0, 8)

	var farmer := QuestGiver.new()
	farmer.display_name = "Farmer Edda"
	farmer.npc_id = "farmer_edda"
	farmer.quest_ids = []
	farmer.faction_id = "human_empire"
	farmer.no_quest_dialogue = "The harvest has been good this year.\nGaela blesses these fields.\nWe send our grain to Dalhurst and the capital."
	farmer.position = farmer_pos
	add_child(farmer)

	# Millbrook Elder - Quest giver for millbrook_bandits quest
	var elder_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_MillbrookElder")
	var elder_pos: Vector3 = elder_marker.global_position if elder_marker else Vector3(0, 0, 10)

	var elder_quests: Array[String] = ["millbrook_bandits"]
	var elder := QuestGiver.spawn_quest_giver(
		self,
		elder_pos,
		"Elder Bram",
		"millbrook_elder",
		null,  # use default sprite
		8, 2,  # h_frames, v_frames
		elder_quests
	)
	elder.region_id = ZONE_ID
	elder.faction_id = "human_empire"
	elder.no_quest_dialogue = "You've done a great service for our hamlet.\nMay Gaela bless your travels, stranger."

	# Victim NPCs for millbrook_bandits quest (speak_victims objective)
	# Victim 1 - near the farmhouses
	var victim1_pos := Vector3(10, 0, 2)
	var victim1 := QuestGiver.spawn_quest_giver(
		self,
		victim1_pos,
		"Frightened Farmer",
		"millbrook_victim",
		null, 8, 2, []  # No quests, just a talk target
	)
	victim1.region_id = ZONE_ID
	victim1.faction_id = "human_empire"
	victim1.npc_type = "millbrook_victim"  # For quest objective matching
	victim1.no_quest_dialogue = "Those bandits took everything!\nThey came at dawn, armed and dangerous.\nThey headed into the woods to the east."

	# Victim 2 - near the mill
	var victim2_pos := Vector3(-10, 0, -5)
	var victim2 := QuestGiver.spawn_quest_giver(
		self,
		victim2_pos,
		"Shaken Villager",
		"millbrook_victim_2",
		null, 8, 2, []  # No quests, just a talk target
	)
	victim2.region_id = ZONE_ID
	victim2.faction_id = "human_empire"
	victim2.npc_type = "millbrook_victim"  # Same type for quest counting
	victim2.no_quest_dialogue = "I saw the bandit captain - scarred face, black cloak.\nThey've made camp somewhere in the eastern woods.\nPlease, someone has to stop them!"

	print("[Mill Brook] Spawned NPCs including Elder Bram and quest victims")


## Spawn fast travel shrine at marker position
func _spawn_fast_travel_shrine() -> void:
	var shrine_marker: Marker3D = get_node_or_null("Interactables/FastTravelShrine")
	var pos: Vector3 = shrine_marker.global_position if shrine_marker else Vector3(5, 0, 2)

	FastTravelShrine.spawn_shrine(
		self,
		pos,
		"Mill Brook Shrine",
		"millbrook_shrine"
	)
	print("[Mill Brook] Spawned fast travel shrine")


## Spawn rest spot at marker position
func _spawn_rest_spot() -> void:
	var rest_marker: Marker3D = get_node_or_null("Interactables/RestSpot")
	var pos: Vector3 = rest_marker.global_position if rest_marker else Vector3(-2, 0, 8)

	RestSpot.spawn_rest_spot(self, pos, "Mill Brook Bench")
	print("[Mill Brook] Spawned rest spot")


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
		print("[Mill Brook] Spawned %d locked doors from markers" % doors_spawned)


## Setup navigation mesh
func _setup_navigation() -> void:
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
		print("[Mill Brook] Navigation mesh baked!")


## Setup cell streaming if we're the main scene (has Player/HUD)
## When loaded as a streaming cell, this will be skipped (Player/HUD stripped by CellStreamer)
func _setup_cell_streaming() -> void:
	# Only setup streaming if we're the main scene (we have Player/HUD)
	var player: Node = get_node_or_null("Player")
	if not player:
		# We're a streaming cell, not main scene - skip streaming setup
		return

	if not CellStreamer:
		push_warning("[%s] CellStreamer not found" % ZONE_ID)
		return

	var my_coords: Vector2i = WorldGrid.get_location_coords(ZONE_ID)
	CellStreamer.register_main_scene_cell(my_coords, self)
	CellStreamer.start_streaming(my_coords)
	print("[%s] Registered as main scene, streaming started at %s" % [ZONE_ID, my_coords])
