## thornfield.gd - Thornfield Forest Hamlet (Tier 1 Hamlet)
## Small forest hamlet northeast of Elder Moor
## Theme: Woodcutters and hunters living on the forest edge
## Contains: General Store, Blacksmith, Hunter's Lodge, and quest giver Marek
##
## NOTE: All terrain, buildings, and decorations are pre-placed in the .tscn file
## This script only handles: NPC spawning, door connections, interactables, navigation
extends Node3D

const ZONE_ID := "hamlet_thornfield"
const ZONE_SIZE := 50.0  # Thornfield is 50x50 units

## Thornfield grid coordinates (from WorldData GRID_DATA)
const GRID_COORDS := Vector2i(9, 4)

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

## Edge triggers for wilderness transitions
var edge_triggers: Dictionary = {}


func _ready() -> void:
	_setup_environment()
	_spawn_npcs()
	_spawn_interactables()
	_spawn_doors()
	_setup_spawn_point_metadata()
	_setup_navigation()
	_create_invisible_border_walls()
	_setup_edge_exits()  # Add edge triggers for wilderness transitions
	DayNightCycle.add_to_level(self)
	print("[Thornfield] Forest hamlet loaded at %s - Woodcutters & Hunters Theme" % GRID_COORDS)


## Setup the WorldEnvironment with proper settings
func _setup_environment() -> void:
	var world_env: WorldEnvironment = $WorldEnvironment
	if world_env:
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.28, 0.38, 0.28)  # Forest green
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.45, 0.52, 0.4)  # Dappled forest light
		env.ambient_light_energy = 0.55
		env.fog_enabled = true
		env.fog_light_color = Color(0.32, 0.42, 0.32)
		env.fog_density = 0.01
		env.fog_sky_affect = 0.3
		world_env.environment = env


## Spawn NPCs using positions from Marker3D nodes in NPCSpawnPoints
func _spawn_npcs() -> void:
	var npcs := Node3D.new()
	npcs.name = "NPCs"
	add_child(npcs)

	var npc_spawn_points: Node3D = get_node_or_null("NPCSpawnPoints")
	if not npc_spawn_points:
		push_warning("[Thornfield] NPCSpawnPoints node not found")
		return

	# General Store merchant
	var general_store_pos: Marker3D = npc_spawn_points.get_node_or_null("Merchant_GeneralStore")
	if general_store_pos:
		Merchant.spawn_merchant(
			npcs,
			general_store_pos.global_position,
			"Thornfield General Store",
			LootTables.LootTier.COMMON,
			"general"
		)

	# Blacksmith merchant
	var blacksmith_pos: Marker3D = npc_spawn_points.get_node_or_null("Merchant_Blacksmith")
	if blacksmith_pos:
		Merchant.spawn_merchant(
			npcs,
			blacksmith_pos.global_position,
			"Thornfield Smithy",
			LootTables.LootTier.COMMON,
			"blacksmith"
		)

	# Hunter's Lodge keeper
	var lodge_pos: Marker3D = npc_spawn_points.get_node_or_null("Merchant_HuntersLodge")
	if lodge_pos:
		Merchant.spawn_merchant(
			npcs,
			lodge_pos.global_position,
			"Hunter's Lodge",
			LootTables.LootTier.COMMON,
			"general"
		)

	# Quest giver: Marek the Hunter
	var marek_pos: Marker3D = npc_spawn_points.get_node_or_null("QuestGiver_Marek")
	if marek_pos:
		var marek := CivilianNPC.spawn_man(npcs, marek_pos.global_position, ZONE_ID)
		marek.npc_name = "Marek the Hunter"
		marek.npc_id = "marek_hunter"
		marek.tint_color = Color(0.85, 0.75, 0.65)  # Weathered look
		if marek.wander:
			marek.wander.wander_radius = 4.0

	# Woodcutter 1
	var woodcutter1_pos: Marker3D = npc_spawn_points.get_node_or_null("Civilian_Woodcutter1")
	if woodcutter1_pos:
		var woodcutter1 := CivilianNPC.spawn_man(npcs, woodcutter1_pos.global_position, ZONE_ID)
		woodcutter1.npc_name = "Woodcutter"
		if woodcutter1.wander:
			woodcutter1.wander.wander_radius = 6.0

	# Woodcutter 2
	var woodcutter2_pos: Marker3D = npc_spawn_points.get_node_or_null("Civilian_Woodcutter2")
	if woodcutter2_pos:
		var woodcutter2 := CivilianNPC.spawn_man(npcs, woodcutter2_pos.global_position, ZONE_ID)
		woodcutter2.npc_name = "Woodcutter"
		if woodcutter2.wander:
			woodcutter2.wander.wander_radius = 5.0

	# Hunter
	var hunter_pos: Marker3D = npc_spawn_points.get_node_or_null("Civilian_Hunter")
	if hunter_pos:
		var hunter := CivilianNPC.spawn_man(npcs, hunter_pos.global_position, ZONE_ID)
		hunter.npc_name = "Hunter"
		if hunter.wander:
			hunter.wander.wander_radius = 8.0

	# Villager
	var villager_pos: Marker3D = npc_spawn_points.get_node_or_null("Civilian_Villager")
	if villager_pos:
		var villager := CivilianNPC.spawn_woman(npcs, villager_pos.global_position, ZONE_ID)
		villager.npc_name = "Villager"
		if villager.wander:
			villager.wander.wander_radius = 4.0

	print("[Thornfield] Spawned NPCs")


## Spawn interactables using positions from Marker3D nodes
func _spawn_interactables() -> void:
	var interactables_node: Node3D = get_node_or_null("Interactables")
	if not interactables_node:
		push_warning("[Thornfield] Interactables node not found")
		return

	# Fast travel shrine
	var shrine_pos: Marker3D = interactables_node.get_node_or_null("ShrinePosition")
	if shrine_pos:
		FastTravelShrine.spawn_shrine(
			interactables_node,
			shrine_pos.global_position,
			"Thornfield Shrine",
			"thornfield_shrine"
		)

	# Rest spot
	var rest_pos: Marker3D = interactables_node.get_node_or_null("RestSpotPosition")
	if rest_pos:
		RestSpot.spawn_rest_spot(
			interactables_node,
			rest_pos.global_position,
			"Lodge Bench"
		)

	print("[Thornfield] Spawned interactables")


## Spawn zone doors for interiors only (not edge exits)
func _spawn_doors() -> void:
	var doors := Node3D.new()
	doors.name = "Doors"
	add_child(doors)

	# Only spawn doors for INTERIOR connections (buildings, dungeons)
	# Edge exits to wilderness are handled by _setup_edge_exits()

	print("[Thornfield] Spawned interior doors")


## Setup edge exits for transitioning to adjacent wilderness cells
## Thornfield at (9, 4) - West/North/South are passable, East is blocked (collapsed pass)
func _setup_edge_exits() -> void:
	var edges_container := Node3D.new()
	edges_container.name = "EdgeExits"
	add_child(edges_container)

	# Check each direction and create edge trigger if passable
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

		# Check if adjacent cell is passable
		if WorldData.is_passable(adjacent_coords):
			var edge := RoomEdge.new()
			edge.direction = direction
			edge.room_size = ZONE_SIZE

			# Position edge at boundary
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
			print("[Thornfield] Created %s edge exit to %s" % [RoomEdge.Direction.keys()[direction], adjacent_coords])
		else:
			print("[Thornfield] %s edge blocked (impassable terrain at %s)" % [RoomEdge.Direction.keys()[direction], adjacent_coords])


## Handle player entering an edge trigger
func _on_edge_entered(direction: RoomEdge.Direction) -> void:
	print("[Thornfield] Player entered %s edge, transitioning to wilderness" % RoomEdge.Direction.keys()[direction])

	# Calculate target coords
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

	# Store current coords for potential return
	SceneManager.current_room_coords = GRID_COORDS

	# Enter wilderness at the adjacent cell
	SceneManager.enter_wilderness(direction, target_coords)


## Setup metadata on spawn points from the scene
func _setup_spawn_point_metadata() -> void:
	var spawn_points_node: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points_node:
		push_warning("[Thornfield] SpawnPoints node not found")
		return

	for child in spawn_points_node.get_children():
		if child is Marker3D:
			child.add_to_group("spawn_points")
			# Extract spawn_id from name (e.g., "SpawnPoint_default" -> "default")
			var spawn_id: String = child.name.replace("SpawnPoint_", "")
			child.set_meta("spawn_id", spawn_id)


## Setup navigation mesh for NPCs
func _setup_navigation() -> void:
	if nav_region:
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
		print("[Thornfield] Navigation mesh baked!")


## Create invisible collision walls at borders - with gaps for passable edges
func _create_invisible_border_walls() -> void:
	var distance: float = ZONE_SIZE / 2.0  # 25 units
	var wall_height: float = 4.0
	var wall_thickness: float = 1.0
	var gap_half: float = 5.0  # Gap width for passable exits
	var section_length: float = distance - gap_half

	# North wall - check if north is passable
	var north_passable: bool = WorldData.is_passable(GRID_COORDS + Vector2i(0, -1))
	if north_passable:
		# Create two sections with gap in center
		_create_wall_section("NorthWestBorder", Vector3(-distance + section_length / 2.0, wall_height / 2.0, -distance),
			Vector3(section_length, wall_height, wall_thickness))
		_create_wall_section("NorthEastBorder", Vector3(distance - section_length / 2.0, wall_height / 2.0, -distance),
			Vector3(section_length, wall_height, wall_thickness))
	else:
		_create_wall_section("NorthBorder", Vector3(0, wall_height / 2.0, -distance),
			Vector3(distance * 2, wall_height, wall_thickness))

	# South wall - check if south is passable
	var south_passable: bool = WorldData.is_passable(GRID_COORDS + Vector2i(0, 1))
	if south_passable:
		_create_wall_section("SouthWestBorder", Vector3(-distance + section_length / 2.0, wall_height / 2.0, distance),
			Vector3(section_length, wall_height, wall_thickness))
		_create_wall_section("SouthEastBorder", Vector3(distance - section_length / 2.0, wall_height / 2.0, distance),
			Vector3(section_length, wall_height, wall_thickness))
	else:
		_create_wall_section("SouthBorder", Vector3(0, wall_height / 2.0, distance),
			Vector3(distance * 2, wall_height, wall_thickness))

	# East wall - check if east is passable (should be blocked - collapsed pass)
	var east_passable: bool = WorldData.is_passable(GRID_COORDS + Vector2i(1, 0))
	if east_passable:
		_create_wall_section("EastNorthBorder", Vector3(distance, wall_height / 2.0, -distance + section_length / 2.0),
			Vector3(wall_thickness, wall_height, section_length))
		_create_wall_section("EastSouthBorder", Vector3(distance, wall_height / 2.0, distance - section_length / 2.0),
			Vector3(wall_thickness, wall_height, section_length))
	else:
		_create_wall_section("EastBorder", Vector3(distance, wall_height / 2.0, 0),
			Vector3(wall_thickness, wall_height, distance * 2))

	# West wall - check if west is passable (should be passable - wilderness)
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
func _create_wall_section(wall_name: String, position: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.name = wall_name
	wall.collision_layer = 1
	wall.collision_mask = 0
	add_child(wall)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = position
	wall.add_child(col)
