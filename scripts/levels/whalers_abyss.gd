## whalers_abyss.gd - Whalers Abyss Chasm Town
## Town built on/around a deep chasm with rope bridges connecting platforms
## Dramatic vertical geometry with precarious buildings on cliff edges
## Connects Aberdeen to Pola Perron - key mountain pass
## Size: Medium-large with multi-level feel
##
## CONVERTED: Terrain, platforms, buildings, and decorations are now pre-placed in .tscn
## This script only handles: spawn points, NPCs, merchants, doors, navigation, interactables
extends Node3D

const ZONE_ID := "town_whalers_abyss"

## Elevation constants for reference
const LOWER_LEVEL := 0.0
const MIDDLE_LEVEL := 12.0
const UPPER_LEVEL := 24.0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Whalers Abyss")
	_setup_spawn_points()
	_spawn_npcs()
	_spawn_merchants()
	_spawn_interactables()
	_spawn_doors()
	_setup_navigation()
	DayNightCycle.add_to_level(self)
	print("[Whalers Abyss] Chasm town loaded (Multi-level)")


## Setup spawn point metadata from markers in scene
func _setup_spawn_points() -> void:
	var spawn_points_node: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points_node:
		push_warning("[Whalers Abyss] SpawnPoints node not found")
		return

	for child in spawn_points_node.get_children():
		if child is Marker3D:
			child.add_to_group("spawn_points")
			var spawn_id: String = child.name.replace("SpawnPoint_", "")
			child.set_meta("spawn_id", spawn_id)
			if spawn_id == "default":
				child.add_to_group("default_spawn")


## Spawn NPCs from marker positions
func _spawn_npcs() -> void:
	var npc_spawns: Node3D = get_node_or_null("NPCSpawnPoints")
	if not npc_spawns:
		push_warning("[Whalers Abyss] NPCSpawnPoints node not found")
		return

	# Bridge Keeper - Old Tersa
	var tersa_marker: Marker3D = npc_spawns.get_node_or_null("NPC_OldTersa")
	if tersa_marker:
		var bridge_keeper := QuestGiver.new()
		bridge_keeper.display_name = "Old Tersa"
		bridge_keeper.npc_id = "old_tersa"
		bridge_keeper.quest_ids = []
		bridge_keeper.position = tersa_marker.global_position
		bridge_keeper.no_quest_dialogue = "Mind your step on them bridges, stranger.\nThe abyss has claimed many a careless soul.\nOne wrong step and you're gone forever.\nBut the views... the views are worth the risk."
		add_child(bridge_keeper)

	# Prospector - Finn Deepdelve
	var finn_marker: Marker3D = npc_spawns.get_node_or_null("NPC_FinnDeepdelve")
	if finn_marker:
		var prospector := QuestGiver.new()
		prospector.display_name = "Finn Deepdelve"
		prospector.npc_id = "finn_deepdelve"
		prospector.quest_ids = []
		prospector.position = finn_marker.global_position
		prospector.no_quest_dialogue = "The cliffs here are rich with ore, friend.\nBut getting it out? That's the trick.\nMining on a cliff edge ain't for the faint of heart."
		add_child(prospector)

	# Civilians
	var civilian1_marker: Marker3D = npc_spawns.get_node_or_null("NPC_Civilian1")
	if civilian1_marker:
		CivilianNPC.spawn_man(self, civilian1_marker.global_position, ZONE_ID)

	var civilian2_marker: Marker3D = npc_spawns.get_node_or_null("NPC_Civilian2")
	if civilian2_marker:
		CivilianNPC.spawn_woman(self, civilian2_marker.global_position, ZONE_ID)

	var civilian3_marker: Marker3D = npc_spawns.get_node_or_null("NPC_Civilian3")
	if civilian3_marker:
		CivilianNPC.spawn_man(self, civilian3_marker.global_position, ZONE_ID)

	print("[Whalers Abyss] Spawned NPCs")


## Spawn merchants from marker positions
func _spawn_merchants() -> void:
	var merchant_positions: Node3D = get_node_or_null("MerchantPositions")
	if not merchant_positions:
		push_warning("[Whalers Abyss] MerchantPositions node not found")
		return

	# General Store
	var general_marker: Marker3D = merchant_positions.get_node_or_null("Merchant_GeneralStore")
	if general_marker:
		Merchant.spawn_merchant(
			self,
			general_marker.global_position,
			"Abyss General Goods",
			LootTables.LootTier.COMMON,
			"general"
		)

	# Blacksmith
	var blacksmith_marker: Marker3D = merchant_positions.get_node_or_null("Merchant_Blacksmith")
	if blacksmith_marker:
		Merchant.spawn_merchant(
			self,
			blacksmith_marker.global_position,
			"Cliffside Forge",
			LootTables.LootTier.UNCOMMON,
			"blacksmith"
		)

	print("[Whalers Abyss] Spawned merchants")


## Spawn interactable objects from markers
func _spawn_interactables() -> void:
	var interactables: Node3D = get_node_or_null("Interactables")
	if not interactables:
		push_warning("[Whalers Abyss] Interactables node not found")
		return

	# Bounty Board
	var bounty_marker: Marker3D = interactables.get_node_or_null("BountyBoard")
	if bounty_marker:
		BountyBoard.spawn_bounty_board(
			self,
			bounty_marker.global_position,
			"Abyss Bounty Board"
		)

	# Rest Spot
	var rest_marker: Marker3D = interactables.get_node_or_null("RestSpot")
	if rest_marker:
		RestSpot.spawn_rest_spot(self, rest_marker.global_position, "Tavern Bench")

	# Fast Travel Shrine
	var shrine_marker: Marker3D = interactables.get_node_or_null("FastTravelShrine")
	if shrine_marker:
		FastTravelShrine.spawn_shrine(
			self,
			shrine_marker.global_position,
			"Abyss Shrine",
			"whalers_abyss_shrine"
		)

	print("[Whalers Abyss] Spawned interactables")


## Spawn zone doors from marker positions
func _spawn_doors() -> void:
	var door_positions: Node3D = get_node_or_null("DoorPositions")
	if not door_positions:
		push_warning("[Whalers Abyss] DoorPositions node not found")
		return

	# Aberdeen door (south exit)
	var aberdeen_marker: Marker3D = door_positions.get_node_or_null("Door_Aberdeen")
	if aberdeen_marker:
		var aberdeen_portal := ZoneDoor.spawn_door(
			self,
			aberdeen_marker.global_position,
			"res://scenes/levels/aberdeen.tscn",
			"from_whalers_abyss",
			"Mountain Road to Aberdeen"
		)
		aberdeen_portal.show_frame = false
		aberdeen_portal.add_to_group("compass_poi")
		aberdeen_portal.set_meta("poi_id", "aberdeen_road")
		aberdeen_portal.set_meta("poi_name", "Aberdeen")
		aberdeen_portal.set_meta("poi_color", Color(0.6, 0.7, 0.85))

	# Pola Perron door (north exit)
	var pola_marker: Marker3D = door_positions.get_node_or_null("Door_PolaPerron")
	if pola_marker:
		var pola_portal := ZoneDoor.spawn_door(
			self,
			pola_marker.global_position,
			"res://scenes/levels/pola_perron.tscn",
			"from_whalers_abyss",
			"Mountain Trail to Pola Perron"
		)
		pola_portal.rotation = pola_marker.rotation
		pola_portal.show_frame = false
		pola_portal.add_to_group("compass_poi")
		pola_portal.set_meta("poi_id", "pola_perron_road")
		pola_portal.set_meta("poi_name", "Pola Perron")
		pola_portal.set_meta("poi_color", Color(0.5, 0.6, 0.5))

	# Inn door
	var inn_marker: Marker3D = door_positions.get_node_or_null("Door_Inn")
	if inn_marker:
		var inn_door := ZoneDoor.spawn_door(
			self,
			inn_marker.global_position,
			"res://scenes/levels/inn_interior.tscn",
			"from_whalers_abyss",
			"Cliff's Edge Inn"
		)
		inn_door.rotation = inn_marker.rotation

	print("[Whalers Abyss] Spawned doors")


## Setup navigation mesh
func _setup_navigation() -> void:
	if nav_region:
		var nav_mesh := NavigationMesh.new()
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
		print("[Whalers Abyss] Navigation mesh baked!")
