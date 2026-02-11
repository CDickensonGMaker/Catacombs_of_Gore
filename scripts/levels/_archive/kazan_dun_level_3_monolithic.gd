## kazan_dun_level_3.gd - Forge District of Kazan-Dun
## Level 3: Smithies, armories, workshops (100x100 units)
## CONTESTED ZONE - Front line against goblin invasion
## Contains forge workers, defensive positions, barricades
## Connects to: Level_2, Level_4 (goblin-held)
extends Node3D

const ZONE_ID := "kazan_dun_level_3"
const ZONE_SIZE := 100.0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var npcs_node: Node3D = $NPCs


func _ready() -> void:
	_setup_navigation()
	_setup_spawn_point_metadata()
	_spawn_dwarf_npcs()
	print("[Kazan-Dun Level 3] Forge District initialized (Zone size: %dx%d)" % [ZONE_SIZE, ZONE_SIZE])


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Kazan-Dun Level 3] NavigationRegion3D not found in scene")
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
		print("[Kazan-Dun Level 3] Navigation mesh baked")


## Add metadata to spawn points for proper identification
func _setup_spawn_point_metadata() -> void:
	var spawn_points := get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	for child in spawn_points.get_children():
		if child.is_in_group("spawn_points"):
			child.set_meta("spawn_id", child.name)


## Spawn forge dwarf NPCs in the contested forge district
func _spawn_dwarf_npcs() -> void:
	if not npcs_node:
		npcs_node = Node3D.new()
		npcs_node.name = "NPCs"
		add_child(npcs_node)

	# This is a contested zone - fewer NPCs, more defensive positions
	# Forge workers have pulled back to the safe side

	# Forge Master - key NPC near the main forge (safe side)
	var forge_master := CivilianNPC.spawn_dwarf_forge_master(npcs_node, Vector3(-25, 0, 35), ZONE_ID)
	forge_master.npc_name = "Forge Master Durgan Coalbeard"
	forge_master.npc_id = "forge_master_durgan"

	# Forge workers still maintaining the forges (safe northern half)
	CivilianNPC.spawn_dwarf_forge_worker(npcs_node, Vector3(-35, 0, 30), ZONE_ID)
	CivilianNPC.spawn_dwarf_forge_worker(npcs_node, Vector3(-40, 0, 25), ZONE_ID)
	CivilianNPC.spawn_dwarf_forge_worker(npcs_node, Vector3(30, 0, 35), ZONE_ID)

	# Forge guards at defensive line (center of room)
	CivilianNPC.spawn_dwarf_forge_guard(npcs_node, Vector3(-15, 0, 0), ZONE_ID)
	CivilianNPC.spawn_dwarf_forge_guard(npcs_node, Vector3(15, 0, 0), ZONE_ID)
	CivilianNPC.spawn_dwarf_forge_guard(npcs_node, Vector3(0, 0, -5), ZONE_ID)

	# Guards at the safe entrance (to Level 2)
	CivilianNPC.spawn_dwarf_forge_guard(npcs_node, Vector3(-8, 0, 45), ZONE_ID)
	CivilianNPC.spawn_dwarf_forge_guard(npcs_node, Vector3(8, 0, 45), ZONE_ID)

	# Heavy guard at the dangerous entrance (to Level 4 - goblin territory)
	CivilianNPC.spawn_dwarf_forge_guard(npcs_node, Vector3(-12, 0, -42), ZONE_ID)
	CivilianNPC.spawn_dwarf_forge_guard(npcs_node, Vector3(12, 0, -42), ZONE_ID)
	CivilianNPC.spawn_dwarf_warrior(npcs_node, Vector3(0, 0, -40), ZONE_ID)

	print("[Kazan-Dun Level 3] Spawned forge district NPCs (contested zone)")
