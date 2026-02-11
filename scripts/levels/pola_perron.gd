## pola_perron.gd - Pola Perron Mountain Monastery
## Peaceful monk monastery high in the mountains
## Runtime-only logic - geometry is pre-placed in pola_perron.tscn
extends Node3D

const ZONE_ID := "monastery_pola_perron"

## Elevation constants for NPC spawning
const BASE_LEVEL := 0.0
const TERRACE_LEVEL := 3.0
const MONASTERY_LEVEL := 6.0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Pola Perron Monastery")

	_setup_spawn_points()
	_spawn_monks()
	_spawn_merchant()
	_spawn_rest_spot()
	_spawn_fast_travel_shrine()
	_spawn_portals()
	_setup_navigation()
	_setup_day_night_cycle()
	print("[Pola Perron] Mountain monastery loaded")


## Setup dynamic day/night lighting
func _setup_day_night_cycle() -> void:
	DayNightCycle.add_to_level(self)


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


## Spawn monks throughout the monastery
func _spawn_monks() -> void:
	# Head Monk (main NPC)
	var abbot_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_AbbotSerenian")
	var abbot_pos: Vector3 = abbot_marker.global_position if abbot_marker else Vector3(0, MONASTERY_LEVEL, -20)

	var head_monk := QuestGiver.new()
	head_monk.display_name = "Abbot Serenian"
	head_monk.npc_id = "abbot_serenian"
	head_monk.quest_ids = []
	head_monk.position = abbot_pos
	head_monk.no_quest_dialogue = "Welcome, traveler, to Pola Perron.\nThis is a place of peace and contemplation.\nThe mountains teach us patience.\nThe silence teaches us wisdom.\nRest here as long as you need."
	add_child(head_monk)

	# Librarian monk
	var aldric_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_BrotherAldric")
	var aldric_pos: Vector3 = aldric_marker.global_position if aldric_marker else Vector3(-12, MONASTERY_LEVEL, -8)

	var librarian := QuestGiver.new()
	librarian.display_name = "Brother Aldric"
	librarian.npc_id = "brother_aldric"
	librarian.quest_ids = []
	librarian.position = aldric_pos
	librarian.no_quest_dialogue = "The library holds many ancient texts.\nKnowledge from ages past, preserved.\nIf you seek wisdom, the answers\nmay lie within these walls."
	add_child(librarian)

	# Meditating monk
	var mei_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_SisterMei")
	var mei_pos: Vector3 = mei_marker.global_position if mei_marker else Vector3(0, TERRACE_LEVEL, 6)

	var meditating := QuestGiver.new()
	meditating.display_name = "Sister Mei"
	meditating.npc_id = "sister_mei"
	meditating.quest_ids = []
	meditating.position = mei_pos
	meditating.no_quest_dialogue = "Shhh... listen to the mountain wind.\nIt carries the voices of those who came before.\nFind your center, traveler.\nPeace begins within."
	add_child(meditating)

	# Pilgrim guide
	var fenwick_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_BrotherFenwick")
	var fenwick_pos: Vector3 = fenwick_marker.global_position if fenwick_marker else Vector3(0, BASE_LEVEL, 15)

	var guide := QuestGiver.new()
	guide.display_name = "Brother Fenwick"
	guide.npc_id = "brother_fenwick"
	guide.quest_ids = []
	guide.position = fenwick_pos
	guide.no_quest_dialogue = "Greetings, pilgrim! Welcome to the monastery.\nThe path to enlightenment is long,\nbut every step brings you closer.\nThe stairs lead to the meditation garden,\nand beyond that, the temple itself."
	add_child(guide)

	# Spawn some civilian monks
	var civ0_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_Civilian_0")
	var civ1_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_Civilian_1")
	var civ2_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_Civilian_2")

	CivilianNPC.spawn_man(self, civ0_marker.global_position if civ0_marker else Vector3(8, MONASTERY_LEVEL, -18), ZONE_ID)
	CivilianNPC.spawn_woman(self, civ1_marker.global_position if civ1_marker else Vector3(-5, TERRACE_LEVEL, 3), ZONE_ID)
	CivilianNPC.spawn_man(self, civ2_marker.global_position if civ2_marker else Vector3(-18, BASE_LEVEL, 24), ZONE_ID)

	print("[Pola Perron] Spawned monastery NPCs")


## Spawn merchant
func _spawn_merchant() -> void:
	var merchant_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_Merchant")
	var pos: Vector3 = merchant_marker.global_position if merchant_marker else Vector3(12, BASE_LEVEL, 25)

	Merchant.spawn_merchant(
		self,
		pos,
		"Pilgrim's Supplies",
		LootTables.LootTier.COMMON,
		"general"
	)


## Spawn rest spot
func _spawn_rest_spot() -> void:
	var rest_marker: Marker3D = get_node_or_null("Interactables/RestSpot")
	var pos: Vector3 = rest_marker.global_position if rest_marker else Vector3(-10, BASE_LEVEL, 22)

	RestSpot.spawn_rest_spot(self, pos, "Pilgrim's Rest")


## Spawn fast travel shrine
func _spawn_fast_travel_shrine() -> void:
	var shrine_marker: Marker3D = get_node_or_null("Interactables/FastTravelShrine")
	var pos: Vector3 = shrine_marker.global_position if shrine_marker else Vector3(0, TERRACE_LEVEL, -8)

	FastTravelShrine.spawn_shrine(
		self,
		pos,
		"Pola Perron Shrine",
		"pola_perron_shrine"
	)
	print("[Pola Perron] Spawned fast travel shrine")


## Spawn portal connections
func _spawn_portals() -> void:
	# Crypt entrance
	var crypt_marker: Marker3D = get_node_or_null("Interactables/DoorPosition_Crypt")
	var crypt_pos: Vector3 = crypt_marker.global_position if crypt_marker else Vector3(0, MONASTERY_LEVEL, -33)

	var crypt_door := ZoneDoor.spawn_door(
		self,
		crypt_pos,
		"res://scenes/levels/pola_perron_crypt.tscn",
		"from_monastery",
		"Descend to the Crypt"
	)

	# South exit to Whalers Abyss
	var whalers_marker: Marker3D = get_node_or_null("Interactables/DoorPosition_Whalers")
	var whalers_pos: Vector3 = whalers_marker.global_position if whalers_marker else Vector3(0, BASE_LEVEL, 32)

	var whalers_portal := ZoneDoor.spawn_door(
		self,
		whalers_pos,
		"res://scenes/levels/whalers_abyss.tscn",
		"from_pola_perron",
		"Mountain Path to Whalers Abyss"
	)
	whalers_portal.rotation.y = PI
	whalers_portal.show_frame = false
	whalers_portal.add_to_group("compass_poi")
	whalers_portal.set_meta("poi_id", "whalers_road")
	whalers_portal.set_meta("poi_name", "Whalers Abyss")
	whalers_portal.set_meta("poi_color", Color(0.5, 0.4, 0.35))

	# East exit to wilderness
	var wilderness_marker: Marker3D = get_node_or_null("Interactables/DoorPosition_Wilderness")
	var wilderness_pos: Vector3 = wilderness_marker.global_position if wilderness_marker else Vector3(28, TERRACE_LEVEL, 0)

	var wilderness_portal := ZoneDoor.spawn_door(
		self,
		wilderness_pos,
		SceneManager.RETURN_TO_WILDERNESS,
		"from_pola_perron",
		"Mountain Wilderness"
	)
	wilderness_portal.rotation.y = -PI / 2
	wilderness_portal.show_frame = false

	print("[Pola Perron] Spawned portal connections")


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
		print("[Pola Perron] Navigation mesh baked!")
