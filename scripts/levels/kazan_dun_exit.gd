## kazan_dun_exit.gd - Back Exit of Kazan-Dun
## Back exit from the mountain, opens to different wilderness area (60x60 units)
## Smaller and less grand than main entrance
## Connects to: Level_5, Open World (different region)
extends Node3D

const ZONE_ID := "kazan_dun_exit"
const ZONE_SIZE := 60.0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	_setup_navigation()
	_setup_spawn_point_metadata()
	print("[Kazan-Dun Exit] Back Exit initialized (Zone size: %dx%d)" % [ZONE_SIZE, ZONE_SIZE])


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Kazan-Dun Exit] NavigationRegion3D not found in scene")
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
		print("[Kazan-Dun Exit] Navigation mesh baked")


## Add metadata to spawn points for proper identification
func _setup_spawn_point_metadata() -> void:
	var spawn_points := get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	for child in spawn_points.get_children():
		if child.is_in_group("spawn_points"):
			child.set_meta("spawn_id", child.name)
