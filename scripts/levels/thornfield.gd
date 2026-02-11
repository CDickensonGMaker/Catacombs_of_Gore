## thornfield.gd - Thornfield Forest Hamlet (Tier 1 Hamlet)
## Small forest hamlet northeast of Elder Moor
## Theme: Woodcutters and hunters living on the forest edge
## Contains: General Store, Blacksmith, Hunter's Lodge, and quest giver Marek
##
## NOTE: All terrain, buildings, and decorations are pre-placed in the .tscn file
## This script only handles: NPC spawning, door connections, interactables, navigation
extends Node3D

const ZONE_ID := "hamlet_thornfield"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	_setup_environment()
	_spawn_npcs()
	_spawn_interactables()
	_spawn_doors()
	_setup_spawn_point_metadata()
	_setup_navigation()
	_create_invisible_border_walls()
	DayNightCycle.add_to_level(self)
	print("[Thornfield] Forest hamlet loaded - Woodcutters & Hunters Theme")


## Setup the WorldEnvironment with proper settings
func _setup_environment() -> void:
	var world_env: WorldEnvironment = $WorldEnvironment
	if world_env:
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.28, 0.38, 0.28)  # Forest green
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.45, 0.52, 0.4)  # Dappled forest light
		env.ambient_light_energy = 0.55
		env.fog_enabled = true
		env.fog_light_color = Color(0.32, 0.42, 0.32)
		env.fog_density = 0.01
		env.fog_sky_affect = 0.3
		world_env.environment = env


## Spawn NPCs using positions from Marker3D nodes in NPCSpawnPoints
func _spawn_npcs() -> void:
	var npcs := Node3D.new()
	npcs.name = "NPCs"
	add_child(npcs)

	var npc_spawn_points: Node3D = get_node_or_null("NPCSpawnPoints")
	if not npc_spawn_points:
		push_warning("[Thornfield] NPCSpawnPoints node not found")
		return

	# General Store merchant
	var general_store_pos: Marker3D = npc_spawn_points.get_node_or_null("Merchant_GeneralStore")
	if general_store_pos:
		Merchant.spawn_merchant(
			npcs,
			general_store_pos.global_position,
			"Thornfield General Store",
			LootTables.LootTier.COMMON,
			"general"
		)

	# Blacksmith merchant
	var blacksmith_pos: Marker3D = npc_spawn_points.get_node_or_null("Merchant_Blacksmith")
	if blacksmith_pos:
		Merchant.spawn_merchant(
			npcs,
			blacksmith_pos.global_position,
			"Thornfield Smithy",
			LootTables.LootTier.COMMON,
			"blacksmith"
		)

	# Hunter's Lodge keeper
	var lodge_pos: Marker3D = npc_spawn_points.get_node_or_null("Merchant_HuntersLodge")
	if lodge_pos:
		Merchant.spawn_merchant(
			npcs,
			lodge_pos.global_position,
			"Hunter's Lodge",
			LootTables.LootTier.COMMON,
			"general"
		)

	# Quest giver: Marek the Hunter
	var marek_pos: Marker3D = npc_spawn_points.get_node_or_null("QuestGiver_Marek")
	if marek_pos:
		var marek := CivilianNPC.spawn_man(npcs, marek_pos.global_position, ZONE_ID)
		marek.npc_name = "Marek the Hunter"
		marek.npc_id = "marek_hunter"
		marek.tint_color = Color(0.85, 0.75, 0.65)  # Weathered look
		if marek.wander:
			marek.wander.wander_radius = 4.0

	# Woodcutter 1
	var woodcutter1_pos: Marker3D = npc_spawn_points.get_node_or_null("Civilian_Woodcutter1")
	if woodcutter1_pos:
		var woodcutter1 := CivilianNPC.spawn_man(npcs, woodcutter1_pos.global_position, ZONE_ID)
		woodcutter1.npc_name = "Woodcutter"
		if woodcutter1.wander:
			woodcutter1.wander.wander_radius = 6.0

	# Woodcutter 2
	var woodcutter2_pos: Marker3D = npc_spawn_points.get_node_or_null("Civilian_Woodcutter2")
	if woodcutter2_pos:
		var woodcutter2 := CivilianNPC.spawn_man(npcs, woodcutter2_pos.global_position, ZONE_ID)
		woodcutter2.npc_name = "Woodcutter"
		if woodcutter2.wander:
			woodcutter2.wander.wander_radius = 5.0

	# Hunter
	var hunter_pos: Marker3D = npc_spawn_points.get_node_or_null("Civilian_Hunter")
	if hunter_pos:
		var hunter := CivilianNPC.spawn_man(npcs, hunter_pos.global_position, ZONE_ID)
		hunter.npc_name = "Hunter"
		if hunter.wander:
			hunter.wander.wander_radius = 8.0

	# Villager
	var villager_pos: Marker3D = npc_spawn_points.get_node_or_null("Civilian_Villager")
	if villager_pos:
		var villager := CivilianNPC.spawn_woman(npcs, villager_pos.global_position, ZONE_ID)
		villager.npc_name = "Villager"
		if villager.wander:
			villager.wander.wander_radius = 4.0

	print("[Thornfield] Spawned NPCs")


## Spawn interactables using positions from Marker3D nodes
func _spawn_interactables() -> void:
	var interactables_node: Node3D = get_node_or_null("Interactables")
	if not interactables_node:
		push_warning("[Thornfield] Interactables node not found")
		return

	# Fast travel shrine
	var shrine_pos: Marker3D = interactables_node.get_node_or_null("ShrinePosition")
	if shrine_pos:
		FastTravelShrine.spawn_shrine(
			interactables_node,
			shrine_pos.global_position,
			"Thornfield Shrine",
			"thornfield_shrine"
		)

	# Rest spot
	var rest_pos: Marker3D = interactables_node.get_node_or_null("RestSpotPosition")
	if rest_pos:
		RestSpot.spawn_rest_spot(
			interactables_node,
			rest_pos.global_position,
			"Lodge Bench"
		)

	print("[Thornfield] Spawned interactables")


## Spawn zone doors for exits
func _spawn_doors() -> void:
	var doors := Node3D.new()
	doors.name = "Doors"
	add_child(doors)

	# Exit to wilderness (south - main entrance)
	var south_exit := ZoneDoor.spawn_door(
		doors,
		Vector3(0, 0, 24),
		SceneManager.RETURN_TO_WILDERNESS,
		"from_thornfield",
		"Road to Wilderness"
	)
	south_exit.rotation.y = PI  # Face south
	south_exit.show_frame = false

	# Exit to Elder Moor (west - connects to Elder Moor)
	var elder_moor_exit := ZoneDoor.spawn_door(
		doors,
		Vector3(-24, 0, 0),
		"res://scenes/levels/elder_moor.tscn",
		"from_thornfield",
		"Road to Elder Moor"
	)
	elder_moor_exit.rotation.y = PI / 2  # Face west
	elder_moor_exit.show_frame = false

	# Exit to bandit hideout area (north - leads to bandit territory)
	var bandit_exit := ZoneDoor.spawn_door(
		doors,
		Vector3(0, 0, -24),
		"res://scenes/levels/bandit_hideout_exterior.tscn",
		"from_thornfield",
		"Forest Path (Bandit Territory)"
	)
	bandit_exit.show_frame = false

	print("[Thornfield] Spawned doors")


## Setup metadata on spawn points from the scene
func _setup_spawn_point_metadata() -> void:
	var spawn_points_node: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points_node:
		push_warning("[Thornfield] SpawnPoints node not found")
		return

	for child in spawn_points_node.get_children():
		if child is Marker3D:
			child.add_to_group("spawn_points")
			# Extract spawn_id from name (e.g., "SpawnPoint_default" -> "default")
			var spawn_id: String = child.name.replace("SpawnPoint_", "")
			child.set_meta("spawn_id", spawn_id)


## Setup navigation mesh for NPCs
func _setup_navigation() -> void:
	if nav_region:
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
		print("[Thornfield] Navigation mesh baked!")


## Create invisible collision walls at borders
func _create_invisible_border_walls() -> void:
	var zone_size := 50.0
	var distance := zone_size / 2.0
	var wall_height := 4.0
	var wall_thickness := 1.0
	var gap_half := 5.0  # Half-width of exit gaps

	# North wall (with gap for bandit path exit)
	var section_length := distance - gap_half

	# North-west section
	var nw := StaticBody3D.new()
	nw.name = "NorthWestBorder"
	nw.collision_layer = 1
	nw.collision_mask = 0
	add_child(nw)
	var nw_col := CollisionShape3D.new()
	var nw_box := BoxShape3D.new()
	nw_box.size = Vector3(section_length, wall_height, wall_thickness)
	nw_col.shape = nw_box
	nw_col.position = Vector3(-distance + section_length / 2.0, wall_height / 2.0, -distance)
	nw.add_child(nw_col)

	# North-east section
	var ne := StaticBody3D.new()
	ne.name = "NorthEastBorder"
	ne.collision_layer = 1
	ne.collision_mask = 0
	add_child(ne)
	var ne_col := CollisionShape3D.new()
	var ne_box := BoxShape3D.new()
	ne_box.size = Vector3(section_length, wall_height, wall_thickness)
	ne_col.shape = ne_box
	ne_col.position = Vector3(distance - section_length / 2.0, wall_height / 2.0, -distance)
	ne.add_child(ne_col)

	# South wall (with gap for main entrance)
	var sw := StaticBody3D.new()
	sw.name = "SouthWestBorder"
	sw.collision_layer = 1
	sw.collision_mask = 0
	add_child(sw)
	var sw_col := CollisionShape3D.new()
	var sw_box := BoxShape3D.new()
	sw_box.size = Vector3(section_length, wall_height, wall_thickness)
	sw_col.shape = sw_box
	sw_col.position = Vector3(-distance + section_length / 2.0, wall_height / 2.0, distance)
	sw.add_child(sw_col)

	var se := StaticBody3D.new()
	se.name = "SouthEastBorder"
	se.collision_layer = 1
	se.collision_mask = 0
	add_child(se)
	var se_col := CollisionShape3D.new()
	var se_box := BoxShape3D.new()
	se_box.size = Vector3(section_length, wall_height, wall_thickness)
	se_col.shape = se_box
	se_col.position = Vector3(distance - section_length / 2.0, wall_height / 2.0, distance)
	se.add_child(se_col)

	# West wall (with gap for Elder Moor exit)
	var wn := StaticBody3D.new()
	wn.name = "WestNorthBorder"
	wn.collision_layer = 1
	wn.collision_mask = 0
	add_child(wn)
	var wn_col := CollisionShape3D.new()
	var wn_box := BoxShape3D.new()
	wn_box.size = Vector3(wall_thickness, wall_height, section_length)
	wn_col.shape = wn_box
	wn_col.position = Vector3(-distance, wall_height / 2.0, -distance + section_length / 2.0)
	wn.add_child(wn_col)

	var ws := StaticBody3D.new()
	ws.name = "WestSouthBorder"
	ws.collision_layer = 1
	ws.collision_mask = 0
	add_child(ws)
	var ws_col := CollisionShape3D.new()
	var ws_box := BoxShape3D.new()
	ws_box.size = Vector3(wall_thickness, wall_height, section_length)
	ws_col.shape = ws_box
	ws_col.position = Vector3(-distance, wall_height / 2.0, distance - section_length / 2.0)
	ws.add_child(ws_col)

	# East wall (solid - no exit on east side)
	var east := StaticBody3D.new()
	east.name = "EastBorder"
	east.collision_layer = 1
	east.collision_mask = 0
	add_child(east)
	var east_col := CollisionShape3D.new()
	var east_box := BoxShape3D.new()
	east_box.size = Vector3(wall_thickness, wall_height, distance * 2)
	east_col.shape = east_box
	east_col.position = Vector3(distance, wall_height / 2.0, 0)
	east.add_child(east_col)
