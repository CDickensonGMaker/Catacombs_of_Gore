## millbrook.gd - Mill Brook Hamlet
## Simple farming/milling hamlet between Dalhurst and Kazan-Dun
## Runtime-only logic - geometry is pre-placed in millbrook.tscn
extends Node3D

const ZONE_ID := "hamlet_millbrook"
const ZONE_SIZE := 40.0  # Millbrook is 40x40 units

## Millbrook grid coordinates (from WorldData GRID_DATA)
const GRID_COORDS := Vector2i(3, 9)

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

## Edge triggers for wilderness transitions
var edge_triggers: Dictionary = {}


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Mill Brook")

	_setup_spawn_points()
	_spawn_merchants()
	_spawn_npcs()
	_spawn_fast_travel_shrine()
	_spawn_rest_spot()
	_setup_navigation()
	_setup_day_night_cycle()
	_create_invisible_border_walls()
	_setup_edge_exits()
	print("[Mill Brook] Farming hamlet loaded at %s" % GRID_COORDS)


## Setup dynamic day/night lighting
func _setup_day_night_cycle() -> void:
	DayNightCycle.add_to_level(self)


## Register pre-placed spawn points with groups and metadata
func _setup_spawn_points() -> void:
	var spawn_points_node: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points_node:
		return

	for child in spawn_points_node.get_children():
		if child is Marker3D:
			var spawn_id: String = child.name.replace("SpawnPoint_", "")
			child.add_to_group("spawn_points")
			child.set_meta("spawn_id", spawn_id)
			if spawn_id == "default":
				child.add_to_group("default_spawn")


## Spawn merchants at NPC marker positions
func _spawn_merchants() -> void:
	var merchant_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_Merchant")
	var pos: Vector3 = merchant_marker.global_position if merchant_marker else Vector3(3, 0, 6)

	Merchant.spawn_merchant(
		self,
		pos,
		"Hamlet General Store",
		LootTables.LootTier.COMMON,
		"general"
	)
	print("[Mill Brook] Spawned general store merchant")


## Spawn NPCs at marker positions
func _spawn_npcs() -> void:
	# Miller NPC (near the water mill)
	var miller_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_MillerOswin")
	var miller_pos: Vector3 = miller_marker.global_position if miller_marker else Vector3(-5, 0, -10)

	var miller := QuestGiver.new()
	miller.display_name = "Miller Oswin"
	miller.npc_id = "miller_oswin"
	miller.quest_ids = []
	miller.no_quest_dialogue = "Welcome to Mill Brook, traveler.\nOur mill grinds grain for the whole region.\nThe brook has powered this wheel for generations."
	miller.position = miller_pos
	add_child(miller)

	# Farmer NPC
	var farmer_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_FarmerEdda")
	var farmer_pos: Vector3 = farmer_marker.global_position if farmer_marker else Vector3(12, 0, 8)

	var farmer := QuestGiver.new()
	farmer.display_name = "Farmer Edda"
	farmer.npc_id = "farmer_edda"
	farmer.quest_ids = []
	farmer.no_quest_dialogue = "The harvest has been good this year.\nGaela blesses these fields.\nWe send our grain to Dalhurst and the capital."
	farmer.position = farmer_pos
	add_child(farmer)

	print("[Mill Brook] Spawned NPCs")


## Spawn fast travel shrine at marker position
func _spawn_fast_travel_shrine() -> void:
	var shrine_marker: Marker3D = get_node_or_null("Interactables/FastTravelShrine")
	var pos: Vector3 = shrine_marker.global_position if shrine_marker else Vector3(5, 0, 2)

	FastTravelShrine.spawn_shrine(
		self,
		pos,
		"Mill Brook Shrine",
		"millbrook_shrine"
	)
	print("[Mill Brook] Spawned fast travel shrine")


## Spawn rest spot at marker position
func _spawn_rest_spot() -> void:
	var rest_marker: Marker3D = get_node_or_null("Interactables/RestSpot")
	var pos: Vector3 = rest_marker.global_position if rest_marker else Vector3(-2, 0, 8)

	RestSpot.spawn_rest_spot(self, pos, "Mill Brook Bench")
	print("[Mill Brook] Spawned rest spot")


## Setup edge exits for transitioning to adjacent wilderness cells
## Millbrook at (3, 9) - all directions should be passable
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
			print("[Mill Brook] Created %s edge exit to %s" % [RoomEdge.Direction.keys()[direction], adjacent_coords])
		else:
			print("[Mill Brook] %s edge blocked (impassable terrain at %s)" % [RoomEdge.Direction.keys()[direction], adjacent_coords])


## Handle player entering an edge trigger
func _on_edge_entered(direction: RoomEdge.Direction) -> void:
	print("[Mill Brook] Player entered %s edge, transitioning to wilderness" % RoomEdge.Direction.keys()[direction])

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


## Create invisible collision walls at borders
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

	# West wall
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


## Setup navigation mesh
func _setup_navigation() -> void:
	if not nav_region:
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
		print("[Mill Brook] Navigation mesh baked!")
