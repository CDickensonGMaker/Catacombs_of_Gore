## millbrook.gd - Mill Brook Hamlet
## Simple farming/milling hamlet between Dalhurst and Kazan-Dun
## Runtime-only logic - geometry is pre-placed in millbrook.tscn
extends Node3D

const ZONE_ID := "hamlet_millbrook"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Mill Brook")

	_setup_spawn_points()
	_spawn_merchants()
	_spawn_npcs()
	_spawn_fast_travel_shrine()
	_spawn_rest_spot()
	_spawn_portals()
	_setup_navigation()
	_setup_day_night_cycle()
	print("[Mill Brook] Farming hamlet loaded")


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
	farmer.no_quest_dialogue = "The harvest has been good this year.\nGaela blesses these fields.\nWe send our grain to Dalhurst and the capital."
	farmer.position = farmer_pos
	add_child(farmer)

	print("[Mill Brook] Spawned NPCs")


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


## Spawn zone exit portals at marker positions
func _spawn_portals() -> void:
	var west_marker: Marker3D = get_node_or_null("Interactables/DoorPosition_West")
	var east_marker: Marker3D = get_node_or_null("Interactables/DoorPosition_East")

	var west_pos: Vector3 = west_marker.global_position if west_marker else Vector3(-20, 0, 0)
	var east_pos: Vector3 = east_marker.global_position if east_marker else Vector3(20, 0, 0)

	# West exit - Road to Dalhurst
	var west_portal := ZoneDoor.spawn_door(
		self,
		west_pos,
		SceneManager.RETURN_TO_WILDERNESS,
		"from_millbrook_east",
		"Road to Dalhurst (West)"
	)
	west_portal.rotation.y = PI / 2

	# East exit - Road to Kazan-Dun
	var east_portal := ZoneDoor.spawn_door(
		self,
		east_pos,
		SceneManager.RETURN_TO_WILDERNESS,
		"from_millbrook_west",
		"Road to Kazan-Dun (East)"
	)
	east_portal.rotation.y = -PI / 2

	print("[Mill Brook] Spawned zone portals")


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
