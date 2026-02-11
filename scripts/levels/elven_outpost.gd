## elven_outpost.gd - Elven forest settlement
## Accessible by boat from Larton
extends Node3D

const ZONE_ID := "village_elven_outpost"

var nav_region: NavigationRegion3D


func _ready() -> void:
	_create_terrain()
	_spawn_fast_travel_shrine()
	_create_spawn_points()
	_setup_navigation()
	print("[Elven Outpost] Elven settlement loaded")


func _create_terrain() -> void:
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.25, 0.35, 0.2)
	ground_mat.roughness = 0.9

	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(60, 1, 60)
	ground.position = Vector3(0, -0.5, 0)
	ground.material = ground_mat
	ground.use_collision = true
	add_child(ground)


func _spawn_fast_travel_shrine() -> void:
	FastTravelShrine.spawn_shrine(
		self,
		Vector3(0, 0, 0),
		"Elven Outpost Shrine",
		"elven_outpost_shrine"
	)


func _create_spawn_points() -> void:
	var spawn_data := [
		{"id": "default", "pos": Vector3(0, 0.1, 5)},
		{"id": "from_fast_travel", "pos": Vector3(0, 0.1, 3)},
		{"id": "from_wilderness", "pos": Vector3(0, 0.1, 5)},
		{"id": "from_north", "pos": Vector3(0, 0.1, -25)},
		{"id": "from_south", "pos": Vector3(0, 0.1, 25)},
		{"id": "from_east", "pos": Vector3(25, 0.1, 0)},
		{"id": "from_west", "pos": Vector3(-25, 0.1, 0)},
	]

	for data: Dictionary in spawn_data:
		var spawn := Node3D.new()
		spawn.name = "SpawnPoint_" + data.id
		spawn.position = data.pos
		spawn.add_to_group("spawn_points")
		spawn.set_meta("spawn_id", data.id)
		add_child(spawn)


func _setup_navigation() -> void:
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
