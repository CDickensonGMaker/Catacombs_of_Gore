## falkenhaften.gd - Falkenhaften Capital City (Tier 5 Capital)
## The main capital city, destination for cart delivery quest
## Grand, prosperous city with multiple districts
## Contains: Grond Stoneheart NPC, Multiple Inns, All Merchant Types,
## Guild Halls, Fast Travel Shrine, Grand Monument Plaza
##
## RUNTIME ONLY - All terrain, buildings, and decorations are pre-placed in .tscn
extends Node3D

const ZONE_ID := "capital_falkenhafen"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Falkenhaften Capital")

	_setup_spawn_point_metadata()
	_spawn_merchants()
	_spawn_inns()
	_spawn_guild_halls()
	_spawn_npcs()
	_spawn_grond_stoneheart()
	_spawn_guard_posts()
	_spawn_fast_travel_shrine()
	_spawn_portals()
	_setup_day_night_cycle()
	_bake_navigation()
	print("[Falkenhaften] Capital city loaded - Tier 5 Capital")


## Setup dynamic day/night lighting
func _setup_day_night_cycle() -> void:
	DayNightCycle.add_to_level(self)


## Setup spawn point metadata for pre-placed Marker3D nodes
func _setup_spawn_point_metadata() -> void:
	var spawn_points := $SpawnPoints
	for child in spawn_points.get_children():
		if child is Marker3D:
			child.set_meta("spawn_id", child.name)


## Spawn merchant shops
func _spawn_merchants() -> void:
	# Capital has all merchant types with EPIC tier loot
	var merchant_configs := [
		# Market District merchants
		{"pos": Vector3(35, 0, 35), "name": "Crown General Goods", "type": "general"},
		{"pos": Vector3(35, 0, 48), "name": "Royal Armory", "type": "armor"},
		{"pos": Vector3(48, 0, 35), "name": "King's Forge Blacksmith", "type": "blacksmith"},
		{"pos": Vector3(48, 0, 48), "name": "Imperial Alchemist", "type": "alchemist"},

		# Craftsman Quarter merchants
		{"pos": Vector3(-55, 0, 35), "name": "Master Weaponsmith", "type": "weapon"},
		{"pos": Vector3(-42, 0, 35), "name": "Artisan Leather Works", "type": "armor"},
		{"pos": Vector3(-55, 0, 48), "name": "Capital Provisions", "type": "general"},

		# Noble Quarter - specialty shops
		{"pos": Vector3(55, 0, -35), "name": "Arcane Emporium", "type": "enchanter"},
		{"pos": Vector3(42, 0, -35), "name": "Royal Jeweler", "type": "jeweler"},
		{"pos": Vector3(55, 0, -48), "name": "Noble's Apothecary", "type": "alchemist"},
	]

	for config in merchant_configs:
		Merchant.spawn_merchant(
			self,
			config.pos,
			config.name,
			LootTables.LootTier.EPIC,  # Capital has best loot
			config.type
		)

	print("[Falkenhaften] Spawned %d merchant shops" % merchant_configs.size())


## Spawn multiple inns
func _spawn_inns() -> void:
	# Three inns in the capital
	var inn_configs := [
		{"pos": Vector3(-25, 0, 25), "name": "The Golden Crown Inn", "door_rotation": PI/2},
		{"pos": Vector3(25, 0, -25), "name": "The Royal Rest", "door_rotation": -PI/2},
		{"pos": Vector3(-60, 0, -25), "name": "The Traveler's Haven", "door_rotation": PI/2},
	]

	for config in inn_configs:
		_create_inn_door(config.pos, config.name, config.door_rotation)

	print("[Falkenhaften] Spawned %d inns" % inn_configs.size())


## Create inn door and rest spot (building geometry is in .tscn)
func _create_inn_door(pos: Vector3, inn_name: String, door_rotation: float) -> void:
	var width := 14.0

	# Door position based on rotation
	var door_offset := Vector3(width/2 + 0.5, 0, 0) if abs(door_rotation - PI/2) < 0.1 else Vector3(-width/2 - 0.5, 0, 0)
	var door_pos := pos + door_offset

	var inn_door := ZoneDoor.spawn_door(
		self,
		door_pos,
		"res://scenes/levels/inn_interior.tscn",
		"from_falkenhaften",
		inn_name
	)
	inn_door.rotation.y = door_rotation

	# Return spawn point
	var spawn_offset := door_offset.normalized() * 2
	var return_spawn := Node3D.new()
	return_spawn.name = "from_inn_" + inn_name.to_lower().replace(" ", "_").replace("'", "")
	return_spawn.position = door_pos + spawn_offset + Vector3(0, 0.1, 0)
	return_spawn.add_to_group("spawn_points")
	return_spawn.set_meta("spawn_id", return_spawn.name)
	add_child(return_spawn)

	# Rest spot outside
	RestSpot.spawn_rest_spot(self, pos + Vector3(5, 0, 5), inn_name + " Bench")

	# Bounty board inside one of the inns
	if inn_name == "The Golden Crown Inn":
		BountyBoard.spawn_bounty_board(self, pos + Vector3(-5, 0, -3), "Capital Bounty Board")


## Spawn guild halls
func _spawn_guild_halls() -> void:
	# Fighter's Guild HEADQUARTERS - largest building
	_spawn_fighters_guild_master(Vector3(-55, 0, -35))

	# Other guild masters
	_spawn_guild_master(Vector3(-55, 0, -60), "Mage's Guild")
	_spawn_guild_master(Vector3(-35, 0, -50), "Merchant's Guild")

	print("[Falkenhaften] Spawned guild halls (Fighters Guild HQ + 2 other guilds)")


## Spawn the Fighters Guild headquarters NPCs
func _spawn_fighters_guild_master(pos: Vector3) -> void:
	var depth := 18.0

	# Spawn Guild Master NPC
	var guild_master := QuestGiver.new()
	guild_master.display_name = "Guildmaster Aldric"
	guild_master.npc_id = "fighters_guild_master"
	guild_master.quest_ids = []
	guild_master.no_quest_dialogue = "Welcome to the Fighter's Guild Headquarters.\nThis is where warriors are forged into legends.\nSpeak to our trainers if you wish to hone your skills,\nor check our contracts board for work."
	guild_master.position = pos + Vector3(0, 0, depth/2 - 4)
	add_child(guild_master)

	# Spawn Trainer NPC
	var width := 22.0
	var trainer := QuestGiver.new()
	trainer.display_name = "Combat Trainer Mira"
	trainer.npc_id = "fighters_guild_trainer"
	trainer.quest_ids = []
	trainer.no_quest_dialogue = "Looking to improve your combat skills?\nThe training yard is open to all guild members.\nPractice makes perfect, warrior."
	trainer.position = pos + Vector3(width/2 + 6, 0, 2)
	add_child(trainer)


## Spawn a guild master NPC
func _spawn_guild_master(pos: Vector3, guild_name: String) -> void:
	var depth := 14.0
	var quest_giver := QuestGiver.new()
	quest_giver.display_name = guild_name + " Master"
	quest_giver.npc_id = guild_name.to_lower().replace(" ", "_").replace("'", "") + "_master"
	quest_giver.quest_ids = []
	quest_giver.no_quest_dialogue = "Welcome to the " + guild_name + ".\nWe serve the capital with honor."
	quest_giver.position = pos + Vector3(0, 0, depth/2 - 2)
	add_child(quest_giver)


## Spawn NPCs
func _spawn_npcs() -> void:
	# Town crier in plaza
	QuestGiver.spawn_quest_giver(self, Vector3(12, 0, 5), "Town Crier")

	# Noble in noble quarter
	QuestGiver.spawn_quest_giver(self, Vector3(45, 0, -50), "Lord Ashworth")

	# Temple priests
	_spawn_temple_priests()

	print("[Falkenhaften] Spawned NPCs")


## Spawn priests for each temple
func _spawn_temple_priests() -> void:
	var temple_center := Vector3(65, 0, 0)

	# Priest of Time (Chronos)
	var priest_time := QuestGiver.new()
	priest_time.display_name = "Priest of Chronos"
	priest_time.npc_id = "priest_of_time"
	priest_time.quest_ids = []
	priest_time.no_quest_dialogue = "Time flows ever onward, traveler.\nChronos sees all that was and all that shall be.\nMay your moments be blessed with purpose."
	priest_time.position = temple_center + Vector3(0, 0, -10)
	add_child(priest_time)

	# Priest of Harvest (Gaela)
	var priest_harvest := QuestGiver.new()
	priest_harvest.display_name = "Priest of Gaela"
	priest_harvest.npc_id = "priest_of_harvest"
	priest_harvest.quest_ids = []
	priest_harvest.no_quest_dialogue = "Gaela's blessing upon you, traveler.\nThe earth provides for all who respect her gifts.\nMay your fields be ever bountiful."
	priest_harvest.position = temple_center + Vector3(-15, 0, 16)
	add_child(priest_harvest)

	# Priest of Rebirth (Morthane)
	var priest_rebirth := QuestGiver.new()
	priest_rebirth.display_name = "Priest of Morthane"
	priest_rebirth.npc_id = "priest_of_rebirth"
	priest_rebirth.quest_ids = []
	priest_rebirth.no_quest_dialogue = "Welcome, child of the cycle.\nMorthane watches over all transitions.\nIn endings, find new beginnings.\nIn death, find the seeds of rebirth."
	priest_rebirth.position = temple_center + Vector3(15, 0, 16)
	add_child(priest_rebirth)


## Spawn Grond Stoneheart - quest completion target for cart delivery
func _spawn_grond_stoneheart() -> void:
	var grond := QuestGiver.new()
	grond.display_name = "Grond Stoneheart"
	grond.npc_id = "grond_stoneheart"
	grond.quest_ids = ["cart_delivery"]  # Cart delivery quest ends here

	grond.quest_dialogues = {
		"cart_delivery": {
			"offer": "Ah, you must be the one bringing my shipment.\nI've been expecting you. The capital needs supplies.",
			"active": "Have you delivered the cart safely?\nThe roads can be treacherous these days.",
			"complete": "Excellent! The supplies have arrived intact.\nYou've done the capital a great service.\nHere is your payment, well earned."
		}
	}
	grond.no_quest_dialogue = "The capital thanks you for your service.\nMay your travels be safe."

	# Position near the grand plaza
	grond.position = Vector3(-15, 0, -10)
	add_child(grond)

	print("[Falkenhaften] Spawned Grond Stoneheart (quest completion target)")


## Spawn guard posts
func _spawn_guard_posts() -> void:
	var guard_positions := [
		# Gate guards
		Vector3(0, 0, 75),      # Main gate south
		Vector3(-8, 0, 75),
		Vector3(8, 0, 75),
		Vector3(0, 0, -75),     # North gate
		Vector3(-5, 0, -75),
		Vector3(5, 0, -75),
		# Wall patrols
		Vector3(85, 0, 0),      # East wall
		Vector3(-85, 0, 0),     # West wall
		Vector3(85, 0, 40),
		Vector3(85, 0, -40),
		Vector3(-85, 0, 40),
		Vector3(-85, 0, -40),
		# Plaza guards
		Vector3(25, 0, 0),
		Vector3(-25, 0, 0),
		Vector3(0, 0, 25),
		Vector3(0, 0, -25),
		# District patrols
		Vector3(45, 0, 45),     # Market
		Vector3(-45, 0, 45),    # Craftsman
		Vector3(45, 0, -45),    # Noble
		Vector3(-45, 0, -45),   # Guild
	]

	for pos in guard_positions:
		_spawn_guard(pos)

	print("[Falkenhaften] Spawned %d guard posts" % guard_positions.size())


## Spawn a guard at position
func _spawn_guard(pos: Vector3) -> void:
	# Guards are spawned via the guard spawning system
	# The guard post decorations are in the .tscn
	pass


## Spawn fast travel shrine
func _spawn_fast_travel_shrine() -> void:
	# Place shrine near the grand plaza, highly visible
	FastTravelShrine.spawn_shrine(
		self,
		Vector3(0, 0, 30),
		"Falkenhaften Shrine",
		"falkenhaften_shrine"
	)
	print("[Falkenhaften] Spawned fast travel shrine")


## Spawn portal connections
func _spawn_portals() -> void:
	# Main south gate - to wilderness
	var south_portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, 0, 82),
		SceneManager.RETURN_TO_WILDERNESS,
		"from_falkenhaften",
		"Leave City (Wilderness)"
	)
	south_portal.rotation.y = PI

	# Register as compass POI
	south_portal.add_to_group("compass_poi")
	south_portal.set_meta("poi_id", "south_gate")
	south_portal.set_meta("poi_name", "Mountain Pass")
	south_portal.set_meta("poi_color", Color(0.4, 0.6, 0.3))

	# North gate - to King's Watch (royal castle area)
	var north_portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, 0, -82),
		"res://scenes/levels/kings_watch.tscn",
		"from_falkenhaften",
		"Road to King's Watch"
	)
	north_portal.rotation.y = 0

	north_portal.add_to_group("compass_poi")
	north_portal.set_meta("poi_id", "north_gate")
	north_portal.set_meta("poi_name", "King's Watch")
	north_portal.set_meta("poi_color", Color(0.7, 0.6, 0.2))

	print("[Falkenhaften] Spawned portals")


## Bake navigation mesh
func _bake_navigation() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()
		print("[Falkenhaften] Navigation mesh baked!")
