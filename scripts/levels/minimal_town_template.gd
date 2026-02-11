## minimal_town_template.gd - Base template for minimal procedural towns
## Just ground + fast travel shrine + spawn points
## Copy and modify ZONE_ID for new towns
class_name MinimalTownTemplate
extends Node3D

## Override this in subclasses or set via scene
@export var zone_id: String = "minimal_town"
@export var zone_name: String = "Minimal Town"
@export var ground_size: float = 60.0
@export var ground_color: Color = Color(0.35, 0.32, 0.28)

var nav_region: NavigationRegion3D


func _ready() -> void:
	_create_terrain()
	_spawn_fast_travel_shrine()
	_create_spawn_points()
	_setup_navigation()
	print("[%s] Minimal town loaded" % zone_name)


func _create_terrain() -> void:
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = ground_color
	ground_mat.roughness = 0.9

	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(ground_size, 1, ground_size)
	ground.position = Vector3(0, -0.5, 0)
	ground.material = ground_mat
	ground.use_collision = true
	add_child(ground)


func _spawn_fast_travel_shrine() -> void:
	FastTravelShrine.spawn_shrine(
		self,
		Vector3(0, 0, 0),
		zone_name + " Shrine",
		zone_id + "_shrine"
	)


func _create_spawn_points() -> void:
	var half_size: float = ground_size / 2.0 - 5.0

	var spawn_data := [
		{"id": "default", "pos": Vector3(0, 0.1, 5)},
		{"id": "from_fast_travel", "pos": Vector3(0, 0.1, 3)},
		{"id": "from_wilderness", "pos": Vector3(0, 0.1, 5)},
		{"id": "from_north", "pos": Vector3(0, 0.1, -half_size)},
		{"id": "from_south", "pos": Vector3(0, 0.1, half_size)},
		{"id": "from_east", "pos": Vector3(half_size, 0.1, 0)},
		{"id": "from_west", "pos": Vector3(-half_size, 0.1, 0)},
	]

	for data: Dictionary in spawn_data:
		var spawn := Node3D.new()
		spawn.name = "SpawnPoint_" + data.id
		spawn.position = data.pos
		spawn.add_to_group("spawn_points")
		spawn.set_meta("spawn_id", data.id)
		add_child(spawn)

	# Mark default spawn
	var default_spawn := get_node_or_null("SpawnPoint_default")
	if default_spawn:
		default_spawn.add_to_group("default_spawn")


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
