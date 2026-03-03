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
const ZONE_SIZE := Vector2(160.0, 172.0)  # Actual scene dimensions (width, depth)
const ZONE_SIZE_LEGACY := 172.0  # For backwards compatibility (use larger dimension)
const TOWN_AMBIENT_PATH := "res://assets/audio/Ambiance/cities/port_city_1.wav"

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
		# Play town ambient sound and village music
		AudioManager.play_ambient(TOWN_AMBIENT_PATH)
		AudioManager.play_zone_music("village")

	_setup_spawn_point_metadata()
	_setup_navigation()
	_setup_building_collision()  # Add collision to GLB buildings
	_spawn_npcs()
	_spawn_locked_doors()
	_spawn_thieves()
	_setup_cell_streaming()
	# Setup western coastline decoration (runs for both main scene and streamed cells)
	_setup_western_coastline()
	# Spawn forest border around the town edges (lush trees/bushes around perimeter)
	_spawn_forest_border()
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


## Add collision to GLB buildings (ModularHouses) so player can't walk through them
func _setup_building_collision() -> void:
	var modular_houses: Node3D = get_node_or_null("ModularHouses")
	if not modular_houses:
		return

	var collision_added: int = 0

	for house in modular_houses.get_children():
		if not house is Node3D:
			continue

		# Find all MeshInstance3D nodes in the house (GLB imports create these)
		var meshes: Array[MeshInstance3D] = []
		_find_mesh_instances(house, meshes)

		for mesh_instance: MeshInstance3D in meshes:
			# Skip if collision already exists
			if mesh_instance.get_child_count() > 0:
				var has_collision: bool = false
				for child in mesh_instance.get_children():
					if child is StaticBody3D:
						has_collision = true
						break
				if has_collision:
					continue

			# Create collision from mesh
			mesh_instance.create_trimesh_collision()
			collision_added += 1

	if collision_added > 0:
		print("[Dalhurst] Added collision to %d building meshes" % collision_added)


## Recursively find all MeshInstance3D nodes
func _find_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_find_mesh_instances(child, result)


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
	# Near HarbormasterOffice at (-50, 0, 38)
	var harbor_master := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(-50, 0, 38),
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

	# === TEMPLE PRIESTS (Quest Givers) ===
	# Temple of the Three Gods is at (8, 0, -15) - priests stand near the altar
	# Priest of Chronos (God of Time) - Left side of altar
	var priest_chronos_quests: Array[String] = ["temple_prophecy_chronos"]
	var priest_chronos := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(5, 0, -18),
		"Priest of Chronos",
		"priest_chronos_dalhurst",
		null,  # Uses default sprite - will be overridden
		4, 1,  # monk sprite frames
		priest_chronos_quests
	)
	priest_chronos.region_id = ZONE_ID
	priest_chronos.faction_id = "church_of_three"
	priest_chronos.no_quest_dialogue = "The sands of time flow ever onward, child. May Chronos guide your steps."
	var chronos_profile := NPCKnowledgeProfile.priest()
	chronos_profile.knowledge_tags = ["dalhurst", "temple", "religion", "priest_chronos", "time", "fate", "prophecy"]
	chronos_profile.personality_traits = ["pious", "mysterious", "patient"]
	priest_chronos.npc_profile = chronos_profile
	print("[Dalhurst] Spawned Priest of Chronos at Temple of the Three Gods")

	# Priestess of Gaela (Goddess of the Harvest) - Center of altar
	var priest_gaela_quests: Array[String] = ["temple_blessing_quest"]
	var priest_gaela := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(8, 0, -18),
		"Priestess of Gaela",
		"priest_gaela_dalhurst",
		null,  # Uses default sprite
		8, 2,
		priest_gaela_quests
	)
	priest_gaela.region_id = ZONE_ID
	priest_gaela.faction_id = "church_of_three"
	priest_gaela.no_quest_dialogue = "Gaela's blessings upon you, traveler. May your harvests be bountiful and your spirit nourished."
	var gaela_profile := NPCKnowledgeProfile.priest()
	gaela_profile.knowledge_tags = ["dalhurst", "temple", "religion", "priest_gaela", "harvest", "nature", "blessings"]
	gaela_profile.personality_traits = ["pious", "nurturing", "kind"]
	priest_gaela.npc_profile = gaela_profile
	print("[Dalhurst] Spawned Priestess of Gaela at Temple of the Three Gods")

	# Priest of Morthane (God/Goddess of Death & Rebirth) - Right side of altar
	var priest_morthane_quests: Array[String] = ["temple_undead_menace"]
	var priest_morthane := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(11, 0, -18),
		"Priest of Morthane",
		"priest_morthane_dalhurst",
		null,  # Uses default sprite
		4, 1,  # monk sprite frames
		priest_morthane_quests
	)
	priest_morthane.region_id = ZONE_ID
	priest_morthane.faction_id = "church_of_three"
	priest_morthane.no_quest_dialogue = "Death comes to all, but through Morthane's grace, rebirth follows. The cycle must be protected."
	var morthane_profile := NPCKnowledgeProfile.priest()
	morthane_profile.knowledge_tags = ["dalhurst", "temple", "religion", "priest_morthane", "death", "rebirth", "undead"]
	morthane_profile.personality_traits = ["pious", "solemn", "wise"]
	priest_morthane.npc_profile = morthane_profile
	print("[Dalhurst] Spawned Priest of Morthane at Temple of the Three Gods")

	# Temple acolyte (wanders around temple area - not a quest giver)
	var acolyte := CivilianNPC.spawn_monk_brown(npcs_container, Vector3(8, 0, -12), ZONE_ID)
	acolyte.npc_id = "temple_acolyte_dalhurst"
	acolyte.npc_name = "Temple Acolyte"
	acolyte.wander_radius = 6.0  # Stays within temple
	var acolyte_profile := NPCKnowledgeProfile.priest()
	acolyte_profile.knowledge_tags = ["dalhurst", "temple", "religion"]
	acolyte_profile.personality_traits = ["pious", "humble", "helpful"]
	acolyte_profile.base_disposition = 60  # Friendly
	acolyte.knowledge_profile = acolyte_profile
	print("[Dalhurst] Spawned Temple Acolyte")

	# === ADVENTURER'S GUILD NPCs ===
	# Guild Hall is at (65, 0, 25)
	# Guild Master - main NPC inside the guild
	var guild_quests: Array[String] = ["guild_initiation", "guild_contract_bandits"]
	var guild_master := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(65, 0, 23),  # Behind the counter area
		"Guildmaster Vorn",
		"guildmaster_vorn_dalhurst",
		null,  # Default sprite
		8, 2,
		guild_quests,
		false  # is_talk_target = false, he gives quests
	)
	guild_master.region_id = ZONE_ID
	guild_master.faction_id = "adventurers_guild"
	guild_master.no_quest_dialogue = "Looking for work? Check the bounty board outside, or speak with me about official guild contracts."
	var gm_profile := NPCKnowledgeProfile.new()
	gm_profile.archetype = NPCKnowledgeProfile.Archetype.MERCHANT
	gm_profile.personality_traits = ["experienced", "gruff", "fair"]
	gm_profile.knowledge_tags = ["dalhurst", "adventurers_guild", "bounties", "dungeons", "monsters", "local_area"]
	gm_profile.base_disposition = 50
	gm_profile.speech_style = "formal"
	guild_master.npc_profile = gm_profile
	print("[Dalhurst] Spawned Guildmaster Vorn at Adventurer's Guild")

	# Guild clerk - handles paperwork
	var guild_clerk := CivilianNPC.spawn_man(npcs_container, Vector3(62, 0, 22), ZONE_ID)
	guild_clerk.npc_id = "guild_clerk_dalhurst"
	guild_clerk.npc_name = "Guild Clerk"
	guild_clerk.enable_wandering = false  # Stays at desk
	var clerk_profile := NPCKnowledgeProfile.new()
	clerk_profile.archetype = NPCKnowledgeProfile.Archetype.MERCHANT
	clerk_profile.personality_traits = ["efficient", "bookish", "helpful"]
	clerk_profile.knowledge_tags = ["dalhurst", "adventurers_guild", "contracts", "local_area"]
	clerk_profile.base_disposition = 55
	guild_clerk.knowledge_profile = clerk_profile
	print("[Dalhurst] Spawned Guild Clerk")

	# Adventurers hanging out at the guild (2-3)
	var adventurer1 := CivilianNPC.spawn_male_gladiator(npcs_container, Vector3(68, 0, 27), ZONE_ID)
	adventurer1.npc_id = "adventurer_1_dalhurst"
	adventurer1.wander_radius = 5.0
	var adventurer2 := CivilianNPC.spawn_female_hunter(npcs_container, Vector3(63, 0, 28), ZONE_ID)
	adventurer2.npc_id = "adventurer_2_dalhurst"
	adventurer2.wander_radius = 5.0
	var adventurer3 := CivilianNPC.spawn_wizard_civilian(npcs_container, Vector3(66, 0, 26), ZONE_ID)
	adventurer3.npc_id = "adventurer_3_dalhurst"
	adventurer3.wander_radius = 4.0
	print("[Dalhurst] Spawned adventurers at Guild Hall")

	# === INNKEEPER ===
	# Near DalhurstInn at (75, 0, -66)
	var innkeeper := CivilianNPC.spawn_man(npcs_container, Vector3(75, 0, -66), ZONE_ID)
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

	# === WIZARD (lost_apprentice quest giver) ===
	var wizard_quests: Array[String] = ["lost_apprentice"]
	var wizard := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(52, 0, -8),  # Near magic shop / mage quarter
		"Master Aldric",
		"wizard_dalhurst",
		null,  # Default sprite
		8, 2,
		wizard_quests
	)
	wizard.region_id = ZONE_ID
	wizard.faction_id = "human_empire"
	wizard.no_quest_dialogue = "My apprentice Marcus... I should never have let him go to those cursed ruins alone. Thank you for finding him, even if the news was grim."
	var wizard_profile := NPCKnowledgeProfile.new()
	wizard_profile.archetype = NPCKnowledgeProfile.Archetype.PRIEST
	wizard_profile.personality_traits = ["scholarly", "worried", "protective"]
	wizard_profile.knowledge_tags = ["dalhurst", "magic", "willow_dale", "undead"]
	wizard_profile.base_disposition = 60
	wizard.npc_profile = wizard_profile
	print("[Dalhurst] Spawned Wizard (lost_apprentice quest)")

	# === ALDRIC VANE - THE KEEPERS CONTACT (keepers_initiation quest giver) ===
	var aldric_quests: Array[String] = ["keepers_initiation"]
	var aldric := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(60, 0, 18),  # Near adventurer's guild area
		"Aldric Vane",
		"aldric_vane",
		null,  # Default sprite
		8, 2,
		aldric_quests
	)
	aldric.region_id = ZONE_ID
	aldric.faction_id = "keepers"
	aldric.no_quest_dialogue = "You've proven yourself a trusted ally of the Keepers. Should you need guidance, speak with me again."
	var aldric_profile := NPCKnowledgeProfile.new()
	aldric_profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
	aldric_profile.personality_traits = ["mysterious", "calculating", "secretive"]
	aldric_profile.knowledge_tags = ["dalhurst", "keepers", "secrets", "willow_dale", "cultists"]
	aldric_profile.base_disposition = 45
	aldric.npc_profile = aldric_profile
	print("[Dalhurst] Spawned Aldric Vane (keepers_initiation quest)")

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

	# === CONAN EASTER EGG ===
	# The Mighty Barbarian is partying at The Gilded Grog Tavern at (-9, 0, -39)
	var conan := ConanEasterEgg.spawn_conan(
		npcs_container,
		Vector3(-9, 0, -39)  # Inside the tavern area
	)
	print("[Dalhurst] The Mighty Barbarian has arrived at The Gilded Grog!")

	# === TAVERN WENCHES ===
	# Barmaids for Conan to party with
	var wench1 := CivilianNPC.spawn_barmaid(npcs_container, Vector3(-10, 0, -38), ZONE_ID)
	wench1.wander_radius = 4.0  # Stay near Conan
	var wench2 := CivilianNPC.spawn_barmaid(npcs_container, Vector3(-8, 0, -40), ZONE_ID)
	wench2.wander_radius = 4.0  # Stay near Conan
	print("[Dalhurst] Spawned tavern wenches at The Gilded Grog")

	# === LADY NIGHTSHADE'S CURIOSITIES (Magic Shop) ===
	# Building is at (35, 0, 15) - sells magical items, weapons, and spell scrolls
	var nightshade: Merchant = Merchant.spawn_merchant(
		npcs_container,
		Vector3(35, 0, 15),
		"Lady Nightshade",
		LootTables.LootTier.RARE,
		"magic"
	)
	if nightshade:
		nightshade.region_id = ZONE_ID
		nightshade.npc_id = "lady_nightshade_dalhurst"
		var nightshade_profile := NPCKnowledgeProfile.new()
		nightshade_profile.archetype = NPCKnowledgeProfile.Archetype.MERCHANT
		nightshade_profile.personality_traits = ["mysterious", "knowledgeable", "cryptic"]
		nightshade_profile.knowledge_tags = ["dalhurst", "magic", "enchanting", "artifacts", "spells", "curses"]
		nightshade_profile.base_disposition = 40  # Aloof
		nightshade_profile.speech_style = "formal"
		nightshade.npc_profile = nightshade_profile
		print("[Dalhurst] Spawned Lady Nightshade at Shop of Curiosities")

	# Enchanting Table inside Lady Nightshade's shop
	var enchanting_table := EnchantingStation.new()
	enchanting_table.position = Vector3(33, 0, 13)  # Inside the shop
	npcs_container.add_child(enchanting_table)  # Add first so _ready() runs
	enchanting_table.name = "EnchantingTable"
	enchanting_table.station_name = "Arcane Enchanting Table"
	print("[Dalhurst] Spawned Enchanting Table at Lady Nightshade's Curiosities")

	# === TEMPLE MONKS (Magic Teachers) ===
	# Temple is at (8, 0, -15) - monks who teach spells and sell scrolls
	# Brother Aldwin - Fire/Combat magic specialist
	var monk_aldwin: Merchant = Merchant.spawn_merchant(
		npcs_container,
		Vector3(12, 0, -10),  # Right side of temple courtyard
		"Brother Aldwin",
		LootTables.LootTier.UNCOMMON,
		"magic"  # Sells spell scrolls
	)
	if monk_aldwin:
		monk_aldwin.region_id = ZONE_ID
		monk_aldwin.npc_id = "monk_aldwin_dalhurst"
		var aldwin_profile := NPCKnowledgeProfile.new()
		aldwin_profile.archetype = NPCKnowledgeProfile.Archetype.PRIEST
		aldwin_profile.personality_traits = ["scholarly", "patient", "devout"]
		aldwin_profile.knowledge_tags = ["dalhurst", "temple", "magic", "fire_magic", "combat_spells", "teaching"]
		aldwin_profile.base_disposition = 55
		aldwin_profile.speech_style = "formal"
		monk_aldwin.npc_profile = aldwin_profile
		print("[Dalhurst] Spawned Brother Aldwin (Fire Magic Teacher) at Temple")

	# Sister Maeve - Healing/Restoration magic specialist
	var monk_maeve: Merchant = Merchant.spawn_merchant(
		npcs_container,
		Vector3(4, 0, -10),  # Left side of temple courtyard
		"Sister Maeve",
		LootTables.LootTier.UNCOMMON,
		"magic"  # Sells spell scrolls
	)
	if monk_maeve:
		monk_maeve.region_id = ZONE_ID
		monk_maeve.npc_id = "monk_maeve_dalhurst"
		var maeve_profile := NPCKnowledgeProfile.new()
		maeve_profile.archetype = NPCKnowledgeProfile.Archetype.PRIEST
		maeve_profile.personality_traits = ["compassionate", "gentle", "wise"]
		maeve_profile.knowledge_tags = ["dalhurst", "temple", "magic", "healing_magic", "restoration", "teaching"]
		maeve_profile.base_disposition = 65
		maeve_profile.speech_style = "formal"
		monk_maeve.npc_profile = maeve_profile
		print("[Dalhurst] Spawned Sister Maeve (Healing Magic Teacher) at Temple")

	# === SEAFARER'S SUPPLIES (Hodgepodge Shop by the Docks) ===
	# Position around (-46, 0, -12) near harbor - sells miscellaneous adventuring goods
	# NOTE: Merchant_Supplies exists in scene at (-42, 0, 11.8) but is basic tier
	# Spawn additional shopkeeper NPC to manage it with better inventory
	var supplies_keeper: Merchant = Merchant.spawn_merchant(
		npcs_container,
		Vector3(-46, 0, -10),  # Near the Shop_SeafarersSupplies building
		"Old Salt Morley",
		LootTables.LootTier.COMMON,
		"general"  # Hodgepodge of items
	)
	if supplies_keeper:
		supplies_keeper.region_id = ZONE_ID
		supplies_keeper.npc_id = "old_salt_morley_dalhurst"
		var morley_profile := NPCKnowledgeProfile.new()
		morley_profile.archetype = NPCKnowledgeProfile.Archetype.MERCHANT
		morley_profile.personality_traits = ["gruff", "weathered", "practical"]
		morley_profile.knowledge_tags = ["dalhurst", "harbor", "ships", "trade", "supplies", "sea_tales"]
		morley_profile.base_disposition = 45
		morley_profile.speech_style = "casual"
		supplies_keeper.npc_profile = morley_profile
		print("[Dalhurst] Spawned Old Salt Morley at Seafarer's Supplies")

	# === GENERIC CIVILIAN NPCs (100+ wandering townsfolk) ===
	_spawn_civilian_population(npcs_container)


## Spawn ~42 generic civilian NPCs distributed throughout the town (reduced from 130+)
## They wander during daytime hours (9am to 9pm)
## Total target: ~76 NPCs including merchants, guards, quest givers
func _spawn_civilian_population(parent: Node3D) -> void:
	# Create container for civilian NPCs
	var civilians_container := Node3D.new()
	civilians_container.name = "CivilianPopulation"
	parent.add_child(civilians_container)

	# === BUILDING EXCLUSION ZONES ===
	# NPCs will not spawn inside these rectangular areas (center, half_width, half_depth)
	var exclusion_zones: Array[Dictionary] = [
		# Modular House Blocks (GLB buildings)
		{"center": Vector3(40.47, 0, 60.34), "half_size": Vector2(12, 12)},   # HouseBlock_0
		{"center": Vector3(29.95, 0, 10.04), "half_size": Vector2(10, 10)},   # HouseBlock_1
		{"center": Vector3(41.87, 0, -30.26), "half_size": Vector2(12, 12)},  # HouseBlock_2/3
		{"center": Vector3(-11.58, 0, 26.18), "half_size": Vector2(10, 10)},  # HouseBlock_One
		{"center": Vector3(-20.68, 0, 65.34), "half_size": Vector2(10, 10)},  # HouseBlock_One2
		{"center": Vector3(54.92, 0, -8.83), "half_size": Vector2(10, 10)},   # HouseBlock_One4
		{"center": Vector3(-43.51, 0, 98.51), "half_size": Vector2(10, 10)},  # HouseBlock_One3
		{"center": Vector3(88.84, 0, -70.0), "half_size": Vector2(15, 20)},   # HouseBlock_One5/6/7 cluster
		# CSG Buildings
		{"center": Vector3(-50, 0, 38), "half_size": Vector2(8, 6)},           # HarbormasterOffice
		{"center": Vector3(-47, 0, -60), "half_size": Vector2(10, 8)},        # ShipwrightGuild
		{"center": Vector3(-25, 0, 15), "half_size": Vector2(6, 5)},          # LadyNightshadesCuriosities
		{"center": Vector3(-9, 0, -39), "half_size": Vector2(10, 10)},        # TheGildedGrog
		{"center": Vector3(75, 0, -66), "half_size": Vector2(8, 8)},          # DalhurstInn
		{"center": Vector3(48, 0, 33), "half_size": Vector2(8, 6)},           # Shop_DalhurstGeneralGoods
		{"center": Vector3(-15, 0, 8), "half_size": Vector2(8, 6)},           # Shop_HarborBlacksmith area
		{"center": Vector3(8, 0, -15), "half_size": Vector2(10, 8)},          # Temple of Three Gods
		{"center": Vector3(65, 0, 25), "half_size": Vector2(10, 8)},          # Adventurer's Guild
	]

	# === SPAWN AREA DEFINITIONS (REDUCED COUNTS) ===
	# Each area has: center position, spawn radius, number of NPCs

	# Market/Commercial District (reduced from 45 to 10)
	var market_spawns: Array[Dictionary] = [
		{"pos": Vector3(25, 0, 5), "radius": 8.0, "count": 5},    # Main market square
		{"pos": Vector3(-5, 0, 0), "radius": 6.0, "count": 3},    # Near blacksmith
		{"pos": Vector3(48, 0, 25), "radius": 5.0, "count": 2},   # East market
	]

	# Harbor District (reduced from 37 to 10)
	var harbor_spawns: Array[Dictionary] = [
		{"pos": Vector3(-55, 0, 0), "radius": 10.0, "count": 5},  # Main dock area
		{"pos": Vector3(-48, 0, -20), "radius": 6.0, "count": 3}, # North harbor
		{"pos": Vector3(-48, 0, 30), "radius": 6.0, "count": 2},  # South harbor
	]

	# Tavern/Inn District (reduced from 16 to 5)
	var tavern_spawns: Array[Dictionary] = [
		{"pos": Vector3(50, 0, 5), "radius": 6.0, "count": 3},    # Near inn exterior
		{"pos": Vector3(35, 0, -5), "radius": 5.0, "count": 2},   # Street area
	]

	# Residential Areas (reduced from 40 to 8) - OUTSIDE buildings only
	var residential_spawns: Array[Dictionary] = [
		{"pos": Vector3(30, 0, 50), "radius": 6.0, "count": 2},   # Southeast road
		{"pos": Vector3(20, 0, 18), "radius": 5.0, "count": 2},   # Central road
		{"pos": Vector3(-25, 0, 35), "radius": 5.0, "count": 2},  # West road
		{"pos": Vector3(60, 0, -20), "radius": 5.0, "count": 2},  # East road
	]

	# Temple Area (reduced from 12 to 4) - courtyard only
	var temple_spawns: Array[Dictionary] = [
		{"pos": Vector3(8, 0, -5), "radius": 6.0, "count": 4},    # Temple courtyard/entrance
	]

	# Guild Area (reduced from 6 to 2) - outside only
	var guild_spawns: Array[Dictionary] = [
		{"pos": Vector3(65, 0, 35), "radius": 4.0, "count": 2},   # Guild exterior
	]

	# Gate Areas (reduced from 12 to 3)
	var gate_spawns: Array[Dictionary] = [
		{"pos": Vector3(0, 0, 42), "radius": 4.0, "count": 1},    # South gate
		{"pos": Vector3(0, 0, -45), "radius": 4.0, "count": 1},   # North gate
		{"pos": Vector3(55, 0, 0), "radius": 4.0, "count": 1},    # East entrance
	]

	# Combine all spawn definitions
	var all_spawns: Array[Dictionary] = []
	all_spawns.append_array(market_spawns)
	all_spawns.append_array(harbor_spawns)
	all_spawns.append_array(tavern_spawns)
	all_spawns.append_array(residential_spawns)
	all_spawns.append_array(temple_spawns)
	all_spawns.append_array(guild_spawns)
	all_spawns.append_array(gate_spawns)

	var total_spawned: int = 0
	var max_attempts_per_spawn: int = 10

	# Spawn NPCs at each area
	for spawn_def: Dictionary in all_spawns:
		var center: Vector3 = spawn_def["pos"]
		var radius: float = spawn_def["radius"]
		var count: int = spawn_def["count"]

		for i in range(count):
			var spawn_pos: Vector3 = Vector3.ZERO
			var valid_pos: bool = false

			# Try to find a valid spawn position outside all exclusion zones
			for attempt in range(max_attempts_per_spawn):
				var angle: float = randf() * TAU
				var dist: float = randf() * radius
				var test_pos := Vector3(
					center.x + cos(angle) * dist,
					0.0,
					center.z + sin(angle) * dist
				)

				# Check against all exclusion zones
				var inside_exclusion: bool = false
				for zone: Dictionary in exclusion_zones:
					var zone_center: Vector3 = zone["center"]
					var half_size: Vector2 = zone["half_size"]
					if abs(test_pos.x - zone_center.x) < half_size.x and abs(test_pos.z - zone_center.z) < half_size.y:
						inside_exclusion = true
						break

				if not inside_exclusion:
					spawn_pos = test_pos
					valid_pos = true
					break

			# Skip this spawn if no valid position found
			if not valid_pos:
				continue

			# Spawn a random civilian type
			var npc: CivilianNPC = CivilianNPC.spawn_gendered_random(
				civilians_container,
				spawn_pos,
				ZONE_ID
			)

			# Configure wander behavior
			npc.wander_radius = radius * 0.8  # Stay mostly in their area
			npc.wander_speed = randf_range(1.4, 2.2)  # Slight speed variation

			# Add zone-specific knowledge to civilians for town-appropriate dialogue
			if not npc.knowledge_profile:
				npc.knowledge_profile = NPCKnowledgeProfile.generic_villager()
			npc.knowledge_profile.knowledge_tags.append(ZONE_ID)
			npc.knowledge_profile.knowledge_tags.append("local_area")

			total_spawned += 1

	print("[Dalhurst] Spawned %d civilian NPCs across the town" % total_spawned)

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
		print("[Dalhurst] Spawned %d locked doors from markers" % doors_spawned)


## Spawn thieves that lurk in the city
## Dalhurst is a major port city - more thieves here
func _spawn_thieves() -> void:
	# Larger city = more thieves (2-4 thieves)
	var thief_count: int = randi_range(2, 4)

	# Thief spawn locations (back alleys, crowded areas, harbor)
	var thief_positions: Array[Vector3] = [
		Vector3(35, 0, 15),    # Near market (crowded, easy pickings)
		Vector3(-48, 0, 10),   # Harbor area (busy docks)
		Vector3(42, 0, 55),    # Residential southeast
		Vector3(-15, 0, -35),  # Near tavern (drunk targets)
		Vector3(60, 0, 28),    # Near adventurer's guild
	]

	# Shuffle and pick
	thief_positions.shuffle()

	var npcs_container: Node3D = get_node_or_null("NPCs")
	if not npcs_container:
		npcs_container = self

	for i in range(mini(thief_count, thief_positions.size())):
		var skill: int = randi_range(5, 8)  # Higher skill in bigger city
		var thief := ThiefNPC.spawn_thief(npcs_container, thief_positions[i], ZONE_ID, skill)

	print("[Dalhurst] %d thieves lurk in the shadows..." % thief_count)


## Spawn lush forest border around the perimeter of Dalhurst
## Trees and bushes are placed OUTSIDE the town interior, creating a forest edge
func _spawn_forest_border() -> void:
	var forest_container: Node3D = Node3D.new()
	forest_container.name = "ForestBorder"
	add_child(forest_container)

	# Town interior bounds (no trees/bushes inside this area)
	# Based on CityGround at (20, 0, 10) with size (160, 1, 172)
	var town_center_x: float = 20.0
	var town_center_z: float = 10.0
	var town_half_width: float = 80.0  # 160/2
	var town_half_depth: float = 86.0  # 172/2

	# Define the forest border strip (15-30 units outside the town edge)
	var border_inner: float = 5.0   # Start spawning 5 units outside town edge
	var border_outer: float = 35.0  # Spawn up to 35 units outside town edge

	# Tree textures (forest/autumn style)
	var tree_textures: Array[String] = [
		"res://assets/sprites/environment/trees/autumn_tree_1.png",
		"res://assets/sprites/environment/trees/autumn_tree_2.png",
		"res://assets/sprites/environment/trees/green_tree1.png",
		"res://assets/sprites/environment/trees/green_tree2.png",
		"res://assets/sprites/environment/trees/green_tree3.png"
	]

	# Bush textures
	var bush_textures: Array[String] = [
		"res://assets/sprites/environment/trees/bush_1.png",
		"res://assets/sprites/environment/trees/bush_2.png",
		"res://assets/sprites/environment/trees/autumn_bush.png"
	]

	# Spawn trees heavily on NORTH, EAST, and SOUTH edges (not west - that's the coast)
	# North edge
	_spawn_edge_vegetation(forest_container, tree_textures, bush_textures,
		town_center_x - town_half_width, town_center_x + town_half_width,  # X range (full width)
		town_center_z - town_half_depth - border_outer, town_center_z - town_half_depth - border_inner,  # Z range (north of town)
		40, 25, "North")  # tree_count, bush_count

	# South edge
	_spawn_edge_vegetation(forest_container, tree_textures, bush_textures,
		town_center_x - town_half_width, town_center_x + town_half_width,
		town_center_z + town_half_depth + border_inner, town_center_z + town_half_depth + border_outer,
		40, 25, "South")

	# East edge (narrower to avoid overlap)
	_spawn_edge_vegetation(forest_container, tree_textures, bush_textures,
		town_center_x + town_half_width + border_inner, town_center_x + town_half_width + border_outer,
		town_center_z - town_half_depth, town_center_z + town_half_depth,
		35, 20, "East")

	print("[Dalhurst] Forest border spawned around town perimeter")


## Helper to spawn vegetation along an edge
func _spawn_edge_vegetation(parent: Node3D, tree_textures: Array[String], bush_textures: Array[String],
		x_min: float, x_max: float, z_min: float, z_max: float,
		tree_count: int, bush_count: int, edge_name: String) -> void:

	# Spawn trees
	for i in range(tree_count):
		var x: float = randf_range(x_min, x_max)
		var z: float = randf_range(z_min, z_max)
		var pos: Vector3 = Vector3(x, 0, z)

		var tree: Sprite3D = Sprite3D.new()
		tree.name = "Tree_%s_%d" % [edge_name, i]

		# Pick random tree texture
		var tex_path: String = tree_textures[randi() % tree_textures.size()]
		var tex: Texture2D = load(tex_path)
		if tex:
			tree.texture = tex
			tree.pixel_size = randf_range(0.018, 0.028)  # Varied sizes
			var tree_height: float = tex.get_height() * tree.pixel_size
			tree.position = Vector3(pos.x, tree_height / 2.0, pos.z)
		else:
			tree.position = pos

		tree.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		tree.transparent = true
		tree.shaded = false
		tree.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		tree.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD

		parent.add_child(tree)

	# Spawn bushes
	for i in range(bush_count):
		var x: float = randf_range(x_min, x_max)
		var z: float = randf_range(z_min, z_max)
		var pos: Vector3 = Vector3(x, 0, z)

		var bush: Sprite3D = Sprite3D.new()
		bush.name = "Bush_%s_%d" % [edge_name, i]

		# Pick random bush texture
		var tex_path: String = bush_textures[randi() % bush_textures.size()]
		var tex: Texture2D = load(tex_path)
		if tex:
			bush.texture = tex
			bush.pixel_size = randf_range(0.008, 0.015)  # Smaller than trees
			var bush_height: float = tex.get_height() * bush.pixel_size
			bush.position = Vector3(pos.x, bush_height / 2.0, pos.z)
		else:
			bush.position = pos

		bush.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		bush.transparent = true
		bush.shaded = false
		bush.billboard = BaseMaterial3D.BILLBOARD_ENABLED

		parent.add_child(bush)


## Setup western coastline decoration (harbor side)
## Creates sand beach, LARGE water plane, and low coastal rocks along the western edge
func _setup_western_coastline() -> void:
	var coast_container: Node3D = Node3D.new()
	coast_container.name = "WesternCoastline"
	add_child(coast_container)

	var half_width: float = ZONE_SIZE.x / 2.0  # 80 units
	var half_depth: float = ZONE_SIZE.y / 2.0  # 86 units
	var water_extent: float = 350.0  # How far water extends to reach fog distance (extended)

	# Sand strip material (beach area along western edge)
	var sand_mat: StandardMaterial3D = StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.76, 0.70, 0.50)  # Sandy tan
	sand_mat.roughness = 0.95
	sand_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Water plane material - flat horizontal surface
	var water_mat: StandardMaterial3D = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.12, 0.30, 0.40, 0.90)  # Deeper blue-green
	water_mat.roughness = 0.15
	water_mat.metallic = 0.4
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Coastal rock material (brown-gray beach rocks)
	var rock_mat: StandardMaterial3D = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.45, 0.40, 0.35)  # Brown-gray beach rocks
	rock_mat.roughness = 0.95

	# === SAND BEACH STRIP ===
	# Runs along the entire western edge of Dalhurst (extended width)
	var sand_width: float = 35.0
	var sand: CSGBox3D = CSGBox3D.new()
	sand.name = "SandBeach"
	sand.size = Vector3(sand_width, 0.2, ZONE_SIZE.y + 20.0)
	sand.position = Vector3(-half_width + sand_width / 2.0 - 15.0, 0.02, 0)  # Shifted 10 more units west
	sand.material = sand_mat
	sand.use_collision = false
	coast_container.add_child(sand)

	# === WATER PLANE ===
	# LARGE flat plane at Y=-0.5, extends to fog distance
	var water: CSGBox3D = CSGBox3D.new()
	water.name = "WaterPlane"
	water.size = Vector3(water_extent, 0.1, ZONE_SIZE.y * 3.0)  # Very wide, covers adjacent cells
	water.position = Vector3(-half_width - water_extent / 2.0, -0.5, 0)
	water.material = water_mat
	water.use_collision = false
	coast_container.add_child(water)

	# === LOW COASTAL ROCKS ===
	# Scattered beach rocks along the shoreline (NOT tall walls)
	var num_rocks: int = 8
	var segment_length: float = (ZONE_SIZE.y + 20.0) / float(num_rocks)

	for i in range(num_rocks):
		var rock: CSGBox3D = CSGBox3D.new()
		rock.name = "CoastalRock_%d" % i

		# Low rocks, not tall walls
		var rock_height: float = randf_range(0.5, 1.5)
		var rock_width: float = randf_range(2.0, 4.0)
		var rock_depth: float = randf_range(2.0, 4.0)

		rock.size = Vector3(rock_depth, rock_height, rock_width)
		rock.position = Vector3(
			-half_width - 5.0 + randf_range(-2.0, 2.0),
			rock_height / 2.0,
			-half_depth - 10.0 + segment_length * (i + 0.5) + randf_range(-3.0, 3.0)
		)
		rock.material = rock_mat
		rock.use_collision = true
		coast_container.add_child(rock)

	# === INVISIBLE COLLISION WALL ===
	# Prevents player from walking into water
	var collision_wall: StaticBody3D = StaticBody3D.new()
	collision_wall.name = "WaterCollision"
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.0, 10.0, ZONE_SIZE.y + 40.0)
	collision_shape.shape = box
	collision_shape.position = Vector3(-half_width - 10.0, 5.0, 0)
	collision_wall.add_child(collision_shape)
	coast_container.add_child(collision_wall)

	print("[Dalhurst] Western coastline decoration added (water extends %d units)" % int(water_extent))
