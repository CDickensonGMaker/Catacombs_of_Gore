## dalhurst.gd - Dalhurst Port City (Tier 4 Major City)
## Major port city on the bay, largest commercial port for the capital Emmenburg
## 18 warships in harbor, 2600 troops garrison
## Contains: The Gilded Grog Tavern, Shipwright Guild, Lady Nightshade's Curiosities,
## Harbormaster's Office, Bounty Board, Multiple Merchants, Harbor Area
##
## NOTE: All static geometry and NPCs are defined in dalhurst.tscn
## This script only handles runtime setup like navigation and day/night cycle
extends Node3D

const ZONE_ID := "city_dalhurst"
const ZONE_SIZE := 60.0  # Dalhurst is 60x60 units

## Dalhurst grid coordinates (from WorldData GRID_DATA)
const GRID_COORDS := Vector2i(3, 4)

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

## Edge triggers for wilderness transitions
var edge_triggers: Dictionary = {}


func _ready() -> void:
	_setup_spawn_point_metadata()
	_setup_navigation()
	_setup_day_night_cycle()
	_create_invisible_border_walls()
	_setup_edge_exits()
	print("[Dalhurst] Port city loaded at %s - Tier 4 Major City" % GRID_COORDS)


## Setup spawn point metadata for spawn points defined in .tscn
func _setup_spawn_point_metadata() -> void:
	var spawn_points := $SpawnPoints
	for child in spawn_points.get_children():
		child.set_meta("spawn_id", child.name)


## Setup dynamic day/night lighting
func _setup_day_night_cycle() -> void:
	DayNightCycle.add_to_level(self)


## Setup navigation mesh for NPCs
func _setup_navigation() -> void:
	if not nav_region:
		nav_region = $NavigationRegion3D

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
		print("[Dalhurst] Navigation mesh baked!")


## Setup edge exits for transitioning to adjacent wilderness cells
## Dalhurst at (3, 4) - East/North/South are passable, West is blocked (water)
func _setup_edge_exits() -> void:
	var edges_container := Node3D.new()
	edges_container.name = "EdgeExits"
	add_child(edges_container)

	var directions: Array[Dictionary] = [
		{"dir": RoomEdge.Direction.NORTH, "offset": Vector2i(0, -1)},
		{"dir": RoomEdge.Direction.SOUTH, "offset": Vector2i(0, 1)},
		{"dir": RoomEdge.Direction.EAST, "offset": Vector2i(1, 0)},
		{"dir": RoomEdge.Direction.WEST, "offset": Vector2i(-1, 0)}
	]

	var distance: float = ZONE_SIZE / 2.0

	for dir_data: Dictionary in directions:
		var direction: int = dir_data["dir"]
		var offset: Vector2i = dir_data["offset"]
		var adjacent_coords: Vector2i = GRID_COORDS + offset

		if WorldData.is_passable(adjacent_coords):
			var edge := RoomEdge.new()
			edge.direction = direction
			edge.room_size = ZONE_SIZE

			match direction:
				RoomEdge.Direction.NORTH:
					edge.position = Vector3(0, 0, -distance - 5)
					edge.name = "NorthEdge"
				RoomEdge.Direction.SOUTH:
					edge.position = Vector3(0, 0, distance + 5)
					edge.name = "SouthEdge"
				RoomEdge.Direction.EAST:
					edge.position = Vector3(distance + 5, 0, 0)
					edge.name = "EastEdge"
				RoomEdge.Direction.WEST:
					edge.position = Vector3(-distance - 5, 0, 0)
					edge.name = "WestEdge"

			edges_container.add_child(edge)
			edge.setup_collision()
			edge.edge_entered.connect(_on_edge_entered)
			edge_triggers[direction] = edge
			print("[Dalhurst] Created %s edge exit to %s" % [RoomEdge.Direction.keys()[direction], adjacent_coords])
		else:
			print("[Dalhurst] %s edge blocked (impassable terrain at %s)" % [RoomEdge.Direction.keys()[direction], adjacent_coords])


## Handle player entering an edge trigger
func _on_edge_entered(direction: RoomEdge.Direction) -> void:
	print("[Dalhurst] Player entered %s edge, transitioning to wilderness" % RoomEdge.Direction.keys()[direction])

	var offset: Vector2i
	match direction:
		RoomEdge.Direction.NORTH:
			offset = Vector2i(0, -1)
		RoomEdge.Direction.SOUTH:
			offset = Vector2i(0, 1)
		RoomEdge.Direction.EAST:
			offset = Vector2i(1, 0)
		RoomEdge.Direction.WEST:
			offset = Vector2i(-1, 0)

	var target_coords: Vector2i = GRID_COORDS + offset

	SceneManager.current_room_coords = GRID_COORDS
	SceneManager.enter_wilderness(direction, target_coords)


## Create invisible collision walls at borders - with gaps for passable edges
func _create_invisible_border_walls() -> void:
	var distance: float = ZONE_SIZE / 2.0
	var wall_height: float = 4.0
	var wall_thickness: float = 1.0
	var gap_half: float = 5.0
	var section_length: float = distance - gap_half

	# North wall
	var north_passable: bool = WorldData.is_passable(GRID_COORDS + Vector2i(0, -1))
	if north_passable:
		_create_wall_section("NorthWestBorder", Vector3(-distance + section_length / 2.0, wall_height / 2.0, -distance),
			Vector3(section_length, wall_height, wall_thickness))
		_create_wall_section("NorthEastBorder", Vector3(distance - section_length / 2.0, wall_height / 2.0, -distance),
			Vector3(section_length, wall_height, wall_thickness))
	else:
		_create_wall_section("NorthBorder", Vector3(0, wall_height / 2.0, -distance),
			Vector3(distance * 2, wall_height, wall_thickness))

	# South wall
	var south_passable: bool = WorldData.is_passable(GRID_COORDS + Vector2i(0, 1))
	if south_passable:
		_create_wall_section("SouthWestBorder", Vector3(-distance + section_length / 2.0, wall_height / 2.0, distance),
			Vector3(section_length, wall_height, wall_thickness))
		_create_wall_section("SouthEastBorder", Vector3(distance - section_length / 2.0, wall_height / 2.0, distance),
			Vector3(section_length, wall_height, wall_thickness))
	else:
		_create_wall_section("SouthBorder", Vector3(0, wall_height / 2.0, distance),
			Vector3(distance * 2, wall_height, wall_thickness))

	# East wall
	var east_passable: bool = WorldData.is_passable(GRID_COORDS + Vector2i(1, 0))
	if east_passable:
		_create_wall_section("EastNorthBorder", Vector3(distance, wall_height / 2.0, -distance + section_length / 2.0),
			Vector3(wall_thickness, wall_height, section_length))
		_create_wall_section("EastSouthBorder", Vector3(distance, wall_height / 2.0, distance - section_length / 2.0),
			Vector3(wall_thickness, wall_height, section_length))
	else:
		_create_wall_section("EastBorder", Vector3(distance, wall_height / 2.0, 0),
			Vector3(wall_thickness, wall_height, distance * 2))

	# West wall (should be blocked - water)
	var west_passable: bool = WorldData.is_passable(GRID_COORDS + Vector2i(-1, 0))
	if west_passable:
		_create_wall_section("WestNorthBorder", Vector3(-distance, wall_height / 2.0, -distance + section_length / 2.0),
			Vector3(wall_thickness, wall_height, section_length))
		_create_wall_section("WestSouthBorder", Vector3(-distance, wall_height / 2.0, distance - section_length / 2.0),
			Vector3(wall_thickness, wall_height, section_length))
	else:
		_create_wall_section("WestBorder", Vector3(-distance, wall_height / 2.0, 0),
			Vector3(wall_thickness, wall_height, distance * 2))


## Helper to create an invisible wall section
func _create_wall_section(wall_name: String, pos: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.name = wall_name
	wall.collision_layer = 1
	wall.collision_mask = 0
	add_child(wall)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	wall.add_child(col)
