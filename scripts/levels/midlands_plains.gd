## midlands_plains.gd - The Midlands Plains region (placeholder)
## Open grassland plains south of Elder Moor
extends Node3D

const ZONE_ID := "region_midlands_plains"
const ZONE_SIZE := 300.0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	_setup_navigation()
	_setup_day_night_cycle()
	_setup_spawn_point_metadata()
	print("[Midlands Plains] Region initialized (placeholder)")


func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Midlands Plains] NavigationRegion3D not found")
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


func _setup_day_night_cycle() -> void:
	# Only setup day/night lighting when this is the main scene (has Player node)
	# When loaded as a streamed cell, CellStreamer strips lighting to prevent doubling
	var is_main_scene: bool = get_node_or_null("Player") != null
	if is_main_scene:
		DayNightCycle.add_to_level(self)


func _setup_spawn_point_metadata() -> void:
	var spawn_points := get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	for child in spawn_points.get_children():
		if child.is_in_group("spawn_points"):
			child.set_meta("spawn_id", child.name)
