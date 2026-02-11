## riverside_village.gd - Rotherhine / Riverside Village
## Dwarven-influenced trade town with river, temple, and merchants
## Runtime-only logic - all geometry is pre-placed in riverside_village.tscn
extends Node3D

const ZONE_ID := "village_riverside"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Rotherhine")
	_setup_spawn_points()
	_spawn_merchants()
	_spawn_quest_npcs()
	_spawn_priests()
	_spawn_villagers()
	_spawn_inn_door()
	_spawn_fast_travel_shrine()
	_spawn_rest_spot()
	_spawn_portal()
	_setup_temple_group()
	_setup_navigation()
	print("[Rotherhine] Dwarf hold loaded")


## Configure spawn points from pre-placed markers
func _setup_spawn_points() -> void:
	var spawn_points := $SpawnPoints

	for child in spawn_points.get_children():
		if child is Marker3D:
			child.add_to_group("spawn_points")
			var spawn_id: String = child.name.replace("SpawnPoint_", "")
			child.set_meta("spawn_id", spawn_id)
			if spawn_id == "default":
				child.add_to_group("default_spawn")


## Spawn merchants from pre-placed NPC markers
func _spawn_merchants() -> void:
	var npc_spawns := $NPCSpawnPoints

	# Helena - General Store
	var helena_marker := npc_spawns.get_node_or_null("MerchantSpawn_Helena")
	if helena_marker:
		Merchant.spawn_merchant(
			self,
			helena_marker.position,
			"Helena's General Store",
			LootTables.LootTier.UNCOMMON,
			"general"
		)

	# Tormund - Blacksmith
	var tormund_marker := npc_spawns.get_node_or_null("MerchantSpawn_Tormund")
	if tormund_marker:
		Merchant.spawn_merchant(
			self,
			tormund_marker.position,
			"Tormund's Smithy",
			LootTables.LootTier.UNCOMMON,
			"blacksmith"
		)

	# Martha - Innkeeper
	var martha_marker := npc_spawns.get_node_or_null("MerchantSpawn_Martha")
	if martha_marker:
		Merchant.spawn_merchant(
			self,
			martha_marker.position,
			"Martha's Inn",
			LootTables.LootTier.COMMON,
			"general"
		)

	print("[Rotherhine] Spawned merchants")


## Spawn quest-giving NPCs from pre-placed markers
func _spawn_quest_npcs() -> void:
	var npc_spawns := $NPCSpawnPoints

	# Old Barret - Crafting mentor
	var barret_marker := npc_spawns.get_node_or_null("NPCSpawn_OldBarret")
	if barret_marker:
		var barret := CivilianNPC.spawn_man(self, barret_marker.position, ZONE_ID)
		barret.npc_name = "Old Barret"
		barret.npc_id = "old_barret"
		barret.tint_color = Color(0.8, 0.75, 0.7)
		if barret.wander:
			barret.wander.wander_radius = 4.0

	# Gareth - Fisherman near dock
	var gareth_marker := npc_spawns.get_node_or_null("NPCSpawn_Gareth")
	if gareth_marker:
		var fisherman := CivilianNPC.spawn_man(self, gareth_marker.position, ZONE_ID)
		fisherman.npc_name = "Gareth the Fisherman"
		fisherman.npc_id = "gareth_fisherman"
		fisherman.tint_color = Color(0.75, 0.7, 0.65)
		if fisherman.wander:
			fisherman.wander.wander_radius = 5.0

	# Elise - Miller's daughter
	var elise_marker := npc_spawns.get_node_or_null("NPCSpawn_Elise")
	if elise_marker:
		var millers_daughter := CivilianNPC.spawn_woman(self, elise_marker.position, ZONE_ID)
		millers_daughter.npc_name = "Elise"
		millers_daughter.npc_id = "elise_miller"
		if millers_daughter.wander:
			millers_daughter.wander.wander_radius = 3.0

	print("[Rotherhine] Spawned quest NPCs")


## Spawn the three priests at Temple of the Three
func _spawn_priests() -> void:
	var npc_spawns := $NPCSpawnPoints

	# Load dialogue data
	var dialogue_time: DialogueData = load("res://data/dialogues/priest_of_time.tres") as DialogueData
	var dialogue_harvest: DialogueData = load("res://data/dialogues/priest_of_harvest.tres") as DialogueData
	var dialogue_rebirth: DialogueData = load("res://data/dialogues/priest_of_rebirth.tres") as DialogueData

	# Priest of Time - Aldren
	var aldren_marker := npc_spawns.get_node_or_null("NPCSpawn_PriestAldren")
	if aldren_marker:
		var priest_time := CivilianNPC.spawn_wizard(self, aldren_marker.position, ZONE_ID)
		priest_time.tint_color = Color(0.6, 0.7, 0.95)
		priest_time.npc_name = "Priest Aldren"
		priest_time.npc_id = "priest_aldren"
		priest_time.dialogue_data = dialogue_time
		if priest_time.wander:
			priest_time.wander.wander_radius = 3.0

	# Priest of Harvest - Elmara
	var elmara_marker := npc_spawns.get_node_or_null("NPCSpawn_PriestElmara")
	if elmara_marker:
		var priest_harvest := CivilianNPC.spawn_wizard(self, elmara_marker.position, ZONE_ID)
		priest_harvest.tint_color = Color(0.7, 0.9, 0.5)
		priest_harvest.npc_name = "Priest Elmara"
		priest_harvest.npc_id = "priest_elmara"
		priest_harvest.dialogue_data = dialogue_harvest
		if priest_harvest.wander:
			priest_harvest.wander.wander_radius = 3.0

	# Priest of Rebirth - Morwen
	var morwen_marker := npc_spawns.get_node_or_null("NPCSpawn_PriestMorwen")
	if morwen_marker:
		var priest_rebirth := CivilianNPC.spawn_wizard(self, morwen_marker.position, ZONE_ID)
		priest_rebirth.tint_color = Color(0.8, 0.6, 0.9)
		priest_rebirth.npc_name = "Priest Morwen"
		priest_rebirth.npc_id = "priest_morwen"
		priest_rebirth.dialogue_data = dialogue_rebirth
		if priest_rebirth.wander:
			priest_rebirth.wander.wander_radius = 3.0

	print("[Rotherhine] Spawned Temple priests")


## Spawn ambient villagers from pre-placed markers
func _spawn_villagers() -> void:
	var npc_spawns := $NPCSpawnPoints

	# Spawn random villagers at villager markers
	for i in range(5):
		var marker := npc_spawns.get_node_or_null("VillagerSpawn_%d" % i)
		if marker:
			if i % 2 == 0:
				CivilianNPC.spawn_random(self, marker.position, ZONE_ID)
			elif i == 3:
				CivilianNPC.spawn_woman(self, marker.position, ZONE_ID)
			else:
				CivilianNPC.spawn_man(self, marker.position, ZONE_ID)

	print("[Rotherhine] Spawned villagers")


## Spawn inn entrance door
func _spawn_inn_door() -> void:
	var door_marker := $Interactables/DoorPosition_InnEntrance

	var inn_door := ZoneDoor.spawn_door(
		self,
		door_marker.position,
		"res://scenes/levels/inn_interior.tscn",
		"from_riverside",
		"Riverside Inn"
	)
	inn_door.rotation.y = -PI / 2

	print("[Rotherhine] Spawned inn door")


## Spawn fast travel shrine
func _spawn_fast_travel_shrine() -> void:
	var shrine_marker := $Interactables/ShrinePosition

	FastTravelShrine.spawn_shrine(
		self,
		shrine_marker.position,
		"Rotherhine Shrine",
		"rotherhine_shrine"
	)

	print("[Rotherhine] Spawned fast travel shrine")


## Spawn rest spot
func _spawn_rest_spot() -> void:
	var rest_marker := $Interactables/RestSpotPosition

	RestSpot.spawn_rest_spot(self, rest_marker.position, "Riverside Inn Bench")

	print("[Rotherhine] Spawned rest spot")


## Spawn portal to wilderness
func _spawn_portal() -> void:
	var exit_marker := $Interactables/DoorPosition_Wilderness

	var exit_portal := ZoneDoor.spawn_door(
		self,
		exit_marker.position,
		SceneManager.RETURN_TO_WILDERNESS,
		"from_village",
		"Travel to Wilderness"
	)
	exit_portal.rotation.y = PI

	# Register as compass POI
	exit_portal.add_to_group("compass_poi")
	exit_portal.set_meta("poi_id", "open_world")
	exit_portal.set_meta("poi_name", "Open World")
	exit_portal.set_meta("poi_color", Color(0.3, 0.7, 0.3))

	print("[Rotherhine] Spawned wilderness portal")


## Setup Temple of the Three as a group for minimap
func _setup_temple_group() -> void:
	var temple := $Buildings/TempleOfTheThree
	if temple:
		temple.add_to_group("temples")
		temple.set_meta("display_name", "Temple of the Three")


## Setup navigation mesh
func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Rotherhine] NavigationRegion3D not found")
		return

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
		print("[Rotherhine] Navigation mesh baked!")
