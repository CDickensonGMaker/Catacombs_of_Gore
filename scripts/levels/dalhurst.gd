## dalhurst.gd - Dalhurst Port City (Tier 4 Major City)
## Major port city on the bay, largest commercial port for the capital Emmenburg
## 18 warships in harbor, 2600 troops garrison
## Contains: The Gilded Grog Tavern, Shipwright Guild, Lady Nightshade's Curiosities,
## Harbormaster's Office, Bounty Board, Multiple Merchants, Harbor Area
##
## NOTE: All static geometry and NPCs are defined in dalhurst.tscn
## This script only handles runtime setup like navigation and day/night cycle
extends Node3D

const ZONE_ID := "dalhurst"
const ZONE_SIZE := 100.0  # Matches WorldGrid.CELL_SIZE

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	# Only register with PlayerGPS if we're the main scene (have Player node)
	# When loaded as a streaming cell, Player is stripped - don't touch GPS
	var is_main_scene: bool = get_node_or_null("Player") != null

	if is_main_scene:
		if PlayerGPS:
			var coords := WorldGrid.get_location_coords(ZONE_ID)
			PlayerGPS.set_position(coords)
		_setup_day_night_cycle()
		DayNightCycle.add_to_level(self)

	_setup_spawn_point_metadata()
	_setup_navigation()
	_spawn_npcs()
	_setup_cell_streaming()
	print("[Dalhurst] Port city loaded - Tier 4 Major City")


## Setup spawn point metadata for spawn points defined in .tscn
func _setup_spawn_point_metadata() -> void:
	var spawn_points := $SpawnPoints
	for child in spawn_points.get_children():
		child.set_meta("spawn_id", child.name)


## Setup navigation mesh for NPCs
func _setup_navigation() -> void:
	if not nav_region:
		nav_region = $NavigationRegion3D

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
		print("[Dalhurst] Navigation mesh baked!")


## Setup day/night cycle (placeholder - actual setup done by DayNightCycle autoload)
func _setup_day_night_cycle() -> void:
	# Day/night cycle is managed by DayNightCycle autoload
	# This function exists for any level-specific lighting setup
	pass


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


## Spawn NPCs (guards, civilians, service NPCs)
func _spawn_npcs() -> void:
	# Get or create NPCs container
	var npcs_container: Node3D = get_node_or_null("NPCs")
	if not npcs_container:
		npcs_container = Node3D.new()
		npcs_container.name = "NPCs"
		add_child(npcs_container)

	# === HARBOR MASTER ===
	# Near HarbormasterOffice at (44, 0, -16)
	var harbor_master := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(44, 0, -16),
		"Harbor Master",
		"harbor_master_dalhurst",
		null,  # Uses default sprite
		8, 2,
		[],  # No quests currently
		true  # is_talk_target
	)
	harbor_master.region_id = ZONE_ID
	harbor_master.faction_id = "human_empire"
	# Set knowledge profile for conversation
	var harbor_master_profile := NPCKnowledgeProfile.new()
	harbor_master_profile.archetype = NPCKnowledgeProfile.Archetype.MERCHANT
	harbor_master_profile.personality_traits = ["authoritative", "busy"]
	harbor_master_profile.knowledge_tags = ["dalhurst", "local_area", "guards", "trade", "authority"]
	harbor_master_profile.base_disposition = 45
	harbor_master_profile.speech_style = "formal"
	harbor_master.npc_profile = harbor_master_profile
	print("[Dalhurst] Spawned Harbor Master at HarbormasterOffice")

	# === GUARDS ===
	# Guard positions at key entry/watch points
	var guard_positions: Array[Vector3] = [
		Vector3(0, 0, 45),   # South gate
		Vector3(55, 0, 0),   # East post
		Vector3(0, 0, -48)   # North gate
	]
	for i in range(guard_positions.size()):
		var guard := GuardNPC.spawn_guard(
			npcs_container,
			guard_positions[i],
			[],  # No patrol points
			ZONE_ID
		)
		guard.npc_id = "guard_dalhurst_%d" % i
		# Guard knowledge profile is set by GuardNPC._get_guard_profile()
		# but we can add dalhurst-specific knowledge
		print("[Dalhurst] Spawned Guard at %s" % guard_positions[i])

	# === TEMPLE PRIESTS ===
	# Near fast travel shrine area at (8, 0, 0) - no temple building exists yet
	# Priest of Chronos (God of Time)
	var priest_chronos := CivilianNPC.spawn_wizard(npcs_container, Vector3(10, 0, -5), ZONE_ID)
	priest_chronos.npc_id = "priest_chronos_dalhurst"
	priest_chronos.npc_name = "Priest of Chronos"
	var chronos_profile := NPCKnowledgeProfile.priest()
	chronos_profile.knowledge_tags = ["dalhurst", "temple", "religion", "priest_chronos"]
	chronos_profile.personality_traits = ["pious", "mysterious"]
	priest_chronos.knowledge_profile = chronos_profile
	print("[Dalhurst] Spawned Priest of Chronos at temple area")

	# Priest of Gaela (Goddess of the Harvest)
	var priest_gaela := CivilianNPC.spawn_woman(npcs_container, Vector3(8, 0, -5), ZONE_ID)
	priest_gaela.npc_id = "priest_gaela_dalhurst"
	priest_gaela.npc_name = "Priestess of Gaela"
	var gaela_profile := NPCKnowledgeProfile.priest()
	gaela_profile.knowledge_tags = ["dalhurst", "temple", "religion", "priest_gaela"]
	gaela_profile.personality_traits = ["pious", "nurturing"]
	priest_gaela.knowledge_profile = gaela_profile
	print("[Dalhurst] Spawned Priestess of Gaela at temple area")

	# Priest of Morthane (God/Goddess of Death & Rebirth)
	var priest_morthane := CivilianNPC.spawn_wizard(npcs_container, Vector3(6, 0, -5), ZONE_ID)
	priest_morthane.npc_id = "priest_morthane_dalhurst"
	priest_morthane.npc_name = "Priest of Morthane"
	var morthane_profile := NPCKnowledgeProfile.priest()
	morthane_profile.knowledge_tags = ["dalhurst", "temple", "religion", "priest_morthane"]
	morthane_profile.personality_traits = ["pious", "solemn"]
	priest_morthane.knowledge_profile = morthane_profile
	print("[Dalhurst] Spawned Priest of Morthane at temple area")

	# === INNKEEPER ===
	# Near DalhurstInn at (40, 0, 0)
	var innkeeper := CivilianNPC.spawn_man(npcs_container, Vector3(40, 0, 0), ZONE_ID)
	innkeeper.npc_id = "innkeeper_dalhurst"
	innkeeper.npc_name = "Innkeeper"
	var innkeeper_profile := NPCKnowledgeProfile.innkeeper()
	innkeeper_profile.knowledge_tags = ["dalhurst", "innkeeper", "local_area", "rumors", "inn_location"]
	innkeeper.knowledge_profile = innkeeper_profile
	print("[Dalhurst] Spawned Innkeeper at DalhurstInn")

	# === BOUNTY BOARD ===
	var bounty_board := BountyBoard.spawn_bounty_board(
		npcs_container,
		Vector3(35, 0, 10),  # Near market area
		"Dalhurst Bounty Board"
	)
	print("[Dalhurst] Spawned Bounty Board")

	# === WORRIED MERCHANT (willow_dale_investigation quest giver) ===
	var worried_merchant_quests: Array[String] = ["willow_dale_investigation"]
	var worried_merchant := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(38, 0, 8),  # Near market area
		"Worried Merchant",
		"worried_merchant_dalhurst",
		null,  # Default sprite
		8, 2,
		worried_merchant_quests
	)
	worried_merchant.region_id = ZONE_ID
	worried_merchant.faction_id = "human_empire"
	worried_merchant.no_quest_dialogue = "Thank you for finding my caravan... What remains of it. The ruins of Willow Dale hold dark secrets."
	var worried_profile := NPCKnowledgeProfile.new()
	worried_profile.archetype = NPCKnowledgeProfile.Archetype.MERCHANT
	worried_profile.personality_traits = ["worried", "generous"]
	worried_profile.knowledge_tags = ["dalhurst", "trade", "local_area"]
	worried_profile.base_disposition = 55
	worried_merchant.npc_profile = worried_profile
	print("[Dalhurst] Spawned Worried Merchant (willow_dale_investigation quest)")

	# === HALVARD THE SUPPLIER (talk target for Tharin's supply run quest) ===
	var halvard := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(42, 0, 5),  # Near market/harbor area
		"Halvard the Supplier",
		"halvard_supplier_dalhurst",
		null,  # Default sprite
		8, 2,
		[],  # No quests to give, just a talk target
		true  # is_talk_target
	)
	halvard.region_id = ZONE_ID
	halvard.faction_id = "human_empire"
	halvard.no_quest_dialogue = "Need something? I deal in tools, supplies, and equipment for workers across the province. If Tharin sent you, his order should be ready."
	var halvard_profile := NPCKnowledgeProfile.new()
	halvard_profile.archetype = NPCKnowledgeProfile.Archetype.MERCHANT
	halvard_profile.personality_traits = ["practical", "efficient", "businesslike"]
	halvard_profile.knowledge_tags = ["dalhurst", "trade", "supplies", "tools", "local_area"]
	halvard_profile.base_disposition = 50
	halvard_profile.speech_style = "casual"
	halvard.npc_profile = halvard_profile
	print("[Dalhurst] Spawned Halvard the Supplier (Tharin's supply quest target)")
