## elder_moor.gd - Elder Moor (Logging Camp Starter Town)
## Small logging hamlet in the forests of Kreigstan - player's starting location
## Scene-based layout with runtime navigation baking and day/night cycle
extends Node3D

const ZONE_ID := "village_elder_moor"
const ZONE_SIZE := 60.0  # 60x60 unit zone

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	_setup_navigation()
	_setup_day_night_cycle()
	_setup_spawn_point_metadata()
	_create_invisible_border_walls()
	print("[Elder Moor] Logging camp initialized (Zone size: %dx%d)" % [ZONE_SIZE, ZONE_SIZE])


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Elder Moor] NavigationRegion3D not found in scene")
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
		print("[Elder Moor] Navigation mesh baked")


## Setup dynamic day/night lighting
func _setup_day_night_cycle() -> void:
	DayNightCycle.add_to_level(self)


## Add metadata to spawn points for proper identification
func _setup_spawn_point_metadata() -> void:
	var spawn_points := get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	for child in spawn_points.get_children():
		if child.is_in_group("spawn_points"):
			child.set_meta("spawn_id", child.name)


## Create invisible collision walls at borders to prevent player leaving except through exit
func _create_invisible_border_walls() -> void:
	var distance := ZONE_SIZE / 2.0  # 30 units
	var wall_height := 4.0
	var wall_thickness := 1.0

	# North wall
	var north := StaticBody3D.new()
	north.name = "NorthBorder"
	north.collision_layer = 1
	north.collision_mask = 0
	add_child(north)
	var north_col := CollisionShape3D.new()
	var north_box := BoxShape3D.new()
	north_box.size = Vector3(distance * 2, wall_height, wall_thickness)
	north_col.shape = north_box
	north_col.position = Vector3(0, wall_height / 2.0, -distance)
	north.add_child(north_col)

	# East wall
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

	# West wall
	var west := StaticBody3D.new()
	west.name = "WestBorder"
	west.collision_layer = 1
	west.collision_mask = 0
	add_child(west)
	var west_col := CollisionShape3D.new()
	var west_box := BoxShape3D.new()
	west_box.size = Vector3(wall_thickness, wall_height, distance * 2)
	west_col.shape = west_box
	west_col.position = Vector3(-distance, wall_height / 2.0, 0)
	west.add_child(west_col)

	# South wall sections (with gap for exit)
	var gap_half := 5.0
	var section_length := distance - gap_half

	# South-west section
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

	# South-east section
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
