## kazan_dun_level_1.gd - The Great Hall of Kazan-Dun
## Level 1: Feasting hall, kitchens, common areas (100x100 units)
## Contains general goods merchant, dwarven NPCs
## Connects to: Entrance, Level_2
extends Node3D

const ZONE_ID := "kazan_dun_level_1"
const ZONE_SIZE := 100.0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var npcs_node: Node3D = $NPCs


func _ready() -> void:
	_setup_navigation()
	_setup_spawn_point_metadata()
	_spawn_dwarf_npcs()
	print("[Kazan-Dun Level 1] Great Hall initialized (Zone size: %dx%d)" % [ZONE_SIZE, ZONE_SIZE])


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Kazan-Dun Level 1] NavigationRegion3D not found in scene")
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
		print("[Kazan-Dun Level 1] Navigation mesh baked")


## Add metadata to spawn points for proper identification
func _setup_spawn_point_metadata() -> void:
	var spawn_points := get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	for child in spawn_points.get_children():
		if child.is_in_group("spawn_points"):
			child.set_meta("spawn_id", child.name)


## Spawn dwarf NPCs in the Great Hall
func _spawn_dwarf_npcs() -> void:
	if not npcs_node:
		npcs_node = Node3D.new()
		npcs_node.name = "NPCs"
		add_child(npcs_node)

	# Political NPCs at the war council table
	# Regent Borin - traditionalist (blue armor, royal guard sprite)
	var regent := CivilianNPC.spawn_dwarf_guard(npcs_node, Vector3(-8, 0, -30), ZONE_ID)
	regent.npc_name = "Regent Borin Stonehelm"
	regent.npc_id = "regent_borin"

	# Thane Grimjaw - rite-seeker (red armor, warrior sprite)
	var thane := CivilianNPC.spawn_dwarf_warrior(npcs_node, Vector3(8, 0, -30), ZONE_ID)
	thane.npc_name = "Thane Grimjaw Ironforge"
	thane.npc_id = "thane_grimjaw"

	# Refugees in the great hall (displaced from lower levels)
	CivilianNPC.spawn_dwarf_refugee(npcs_node, Vector3(-20, 0, 20), ZONE_ID)
	CivilianNPC.spawn_dwarf_refugee(npcs_node, Vector3(-15, 0, 25), ZONE_ID)
	CivilianNPC.spawn_dwarf_refugee(npcs_node, Vector3(20, 0, 20), ZONE_ID)
	CivilianNPC.spawn_dwarf_refugee(npcs_node, Vector3(25, 0, 10), ZONE_ID)

	# Wounded soldiers recovering
	CivilianNPC.spawn_dwarf_wounded(npcs_node, Vector3(-35, 0, -10), ZONE_ID)
	CivilianNPC.spawn_dwarf_wounded(npcs_node, Vector3(-38, 0, -5), ZONE_ID)
	CivilianNPC.spawn_dwarf_wounded(npcs_node, Vector3(35, 0, -15), ZONE_ID)

	# Kitchen staff and servants
	CivilianNPC.spawn_dwarf_civilian(npcs_node, Vector3(-40, 0, -30), ZONE_ID)
	CivilianNPC.spawn_dwarf_civilian(npcs_node, Vector3(-38, 0, -38), ZONE_ID)

	# Guards near doors
	CivilianNPC.spawn_dwarf_guard(npcs_node, Vector3(-10, 0, 45), ZONE_ID)
	CivilianNPC.spawn_dwarf_guard(npcs_node, Vector3(10, 0, 45), ZONE_ID)
	CivilianNPC.spawn_dwarf_guard(npcs_node, Vector3(-10, 0, -45), ZONE_ID)
	CivilianNPC.spawn_dwarf_guard(npcs_node, Vector3(10, 0, -45), ZONE_ID)

	# Additional dwarves wandering the feast tables
	CivilianNPC.spawn_dwarf_random(npcs_node, Vector3(-10, 0, -15), ZONE_ID)
	CivilianNPC.spawn_dwarf_random(npcs_node, Vector3(10, 0, 0), ZONE_ID)
	CivilianNPC.spawn_dwarf_random(npcs_node, Vector3(-5, 0, 15), ZONE_ID)

	print("[Kazan-Dun Level 1] Spawned dwarf NPCs including political figures")
