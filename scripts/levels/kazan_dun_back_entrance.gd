## kazan_dun_back_entrance.gd - Grand Southern Entrance of Kazan-Dun
## Secondary grand entrance to the dwarven stronghold (80x60 units)
## As magnificent as the northern entrance, guarding the southern approach
## Connects to: Kazan-Dun Entrance, South Road
extends Node3D

const ZONE_ID := "kazan_dun_back_entrance"
const ZONE_SIZE_X := 80.0
const ZONE_SIZE_Z := 60.0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var npcs_node: Node3D = $NPCs


func _ready() -> void:
	_setup_navigation()
	_setup_spawn_point_metadata()
	_spawn_dwarf_npcs()
	print("[Kazan-Dun South Entrance] Grand southern entrance initialized (Zone size: %dx%d)" % [ZONE_SIZE_X, ZONE_SIZE_Z])


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Kazan-Dun Back Entrance] NavigationRegion3D not found in scene")
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
		print("[Kazan-Dun Back Entrance] Navigation mesh baked")


## Add metadata to spawn points for proper identification
func _setup_spawn_point_metadata() -> void:
	var spawn_points := get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	for child in spawn_points.get_children():
		if child.is_in_group("spawn_points"):
			child.set_meta("spawn_id", child.name)


## Spawn dwarf NPCs at the south entrance
func _spawn_dwarf_npcs() -> void:
	if not npcs_node:
		npcs_node = Node3D.new()
		npcs_node.name = "NPCs"
		add_child(npcs_node)

	# Guards at the grand southern gate
	CivilianNPC.spawn_dwarf_guard(npcs_node, Vector3(-15, 0, 25), ZONE_ID)
	CivilianNPC.spawn_dwarf_guard(npcs_node, Vector3(15, 0, 25), ZONE_ID)

	# Guards at the inner passage to main entrance
	CivilianNPC.spawn_dwarf_guard(npcs_node, Vector3(-8, 0, -25), ZONE_ID)
	CivilianNPC.spawn_dwarf_guard(npcs_node, Vector3(8, 0, -25), ZONE_ID)

	# Checkpoint attendant
	CivilianNPC.spawn_dwarf_civilian(npcs_node, Vector3(0, 0, 0), ZONE_ID)

	# Wandering guards on patrol
	CivilianNPC.spawn_dwarf_warrior(npcs_node, Vector3(-20, 0, 0), ZONE_ID)
	CivilianNPC.spawn_dwarf_warrior(npcs_node, Vector3(20, 0, 10), ZONE_ID)

	print("[Kazan-Dun South Entrance] Spawned dwarf guards")
