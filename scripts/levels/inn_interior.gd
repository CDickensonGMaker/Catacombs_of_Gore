## inn_interior.gd - Single-floor tavern interior with locked rental room
## Main area: Bar with innkeeper, tables, fireplace
## Rental room: Small room behind locked door (unlocks after payment)
extends Node3D

## Zone identifier for save system
const ZONE_ID := "inn_interior"

## References created at runtime
var innkeeper: Innkeeper
var nav_region: NavigationRegion3D
var rental_room_bed: RentableBed = null

func _ready() -> void:
	_setup_navigation()
	_setup_spawn_point_meta()
	_setup_main_bar_area()
	_spawn_innkeeper()
	_spawn_town_storage()
	_spawn_tavern_fireplace()
	_create_rental_room()
	_create_ambient_lighting()

## Set meta data on spawn points for SceneManager to find them
func _setup_spawn_point_meta() -> void:
	var spawn_points := get_tree().get_nodes_in_group("spawn_points")
	for point in spawn_points:
		if point.name == "from_elder_moor":
			point.set_meta("spawn_id", "from_elder_moor")

## Setup navigation (minimal for interior)
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
		print("[InnInterior] Navigation mesh baked")

## Setup the main bar area geometry (walls, floor, bar counter)
func _setup_main_bar_area() -> void:
	# Floor material (dark wood)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.25, 0.18, 0.12)
	floor_mat.roughness = 0.9

	# Wall material (stone)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.35, 0.32, 0.28)
	wall_mat.roughness = 0.95

	# Bar counter material (polished wood)
	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.4, 0.28, 0.18)
	bar_mat.roughness = 0.6

	# Floor (12x12 main area)
	var floor_mesh := CSGBox3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.size = Vector3(12, 0.2, 12)
	floor_mesh.position = Vector3(0, -0.1, 0)
	floor_mesh.material = floor_mat
	floor_mesh.use_collision = true
	add_child(floor_mesh)

	# North wall
	var north_wall := CSGBox3D.new()
	north_wall.name = "NorthWall"
	north_wall.size = Vector3(12, 4, 0.3)
	north_wall.position = Vector3(0, 2, -6)
	north_wall.material = wall_mat
	north_wall.use_collision = true
	add_child(north_wall)

	# South wall
	var south_wall := CSGBox3D.new()
	south_wall.name = "SouthWall"
	south_wall.size = Vector3(12, 4, 0.3)
	south_wall.position = Vector3(0, 2, 6)
	south_wall.material = wall_mat
	south_wall.use_collision = true
	add_child(south_wall)

	# West wall
	var west_wall := CSGBox3D.new()
	west_wall.name = "WestWall"
	west_wall.size = Vector3(0.3, 4, 12)
	west_wall.position = Vector3(-6, 2, 0)
	west_wall.material = wall_mat
	west_wall.use_collision = true
	add_child(west_wall)

	# East wall (with door gap for rental room)
	# Upper part above door
	var east_wall_upper := CSGBox3D.new()
	east_wall_upper.name = "EastWallUpper"
	east_wall_upper.size = Vector3(0.3, 1, 12)
	east_wall_upper.position = Vector3(6, 3.5, 0)
	east_wall_upper.material = wall_mat
	east_wall_upper.use_collision = true
	add_child(east_wall_upper)

	# East wall left of door
	var east_wall_left := CSGBox3D.new()
	east_wall_left.name = "EastWallLeft"
	east_wall_left.size = Vector3(0.3, 3, 5)
	east_wall_left.position = Vector3(6, 1.5, -3.5)
	east_wall_left.material = wall_mat
	east_wall_left.use_collision = true
	add_child(east_wall_left)

	# East wall right of door
	var east_wall_right := CSGBox3D.new()
	east_wall_right.name = "EastWallRight"
	east_wall_right.size = Vector3(0.3, 3, 5)
	east_wall_right.position = Vector3(6, 1.5, 3.5)
	east_wall_right.material = wall_mat
	east_wall_right.use_collision = true
	add_child(east_wall_right)

	# Bar counter (L-shaped, against west wall)
	var bar_main := CSGBox3D.new()
	bar_main.name = "BarMain"
	bar_main.size = Vector3(3, 1.1, 0.6)
	bar_main.position = Vector3(-4.5, 0.55, -3)
	bar_main.material = bar_mat
	bar_main.use_collision = true
	add_child(bar_main)

	var bar_side := CSGBox3D.new()
	bar_side.name = "BarSide"
	bar_side.size = Vector3(0.6, 1.1, 3)
	bar_side.position = Vector3(-3.3, 0.55, -4.5)
	bar_side.material = bar_mat
	bar_side.use_collision = true
	add_child(bar_side)

	# Ceiling
	var ceiling := CSGBox3D.new()
	ceiling.name = "Ceiling"
	ceiling.size = Vector3(12, 0.2, 12)
	ceiling.position = Vector3(0, 4.1, 0)
	ceiling.material = wall_mat
	ceiling.use_collision = true
	add_child(ceiling)

	print("[InnInterior] Main bar area created")

## Spawn the innkeeper behind the bar
func _spawn_innkeeper() -> void:
	# Innkeeper stands behind the bar on west side
	innkeeper = Innkeeper.spawn_innkeeper(self, Vector3(-4.5, 0, -4.5), "Barkeep Mira")
	innkeeper.innkeeper_greeting = "Welcome, traveler! Rest your weary bones."
	innkeeper.room_cost = 25
	# Give innkeeper reference to this level so they can unlock the door
	innkeeper.set_inn_level(self)
	print("[InnInterior] Spawned innkeeper: Barkeep Mira")

## Spawn the universal town storage chest
func _spawn_town_storage() -> void:
	# Universal persistent storage - accessible from anywhere using same ID
	# Placed against south wall in main bar area
	var storage := Chest.spawn_chest(
		self,
		Vector3(-4, 0, 4.5),  # South wall, west side
		"Town Storage",
		false, 0,  # Not locked
		true,  # Persistent
		"town_storage_main"  # Universal ID - same everywhere
	)
	print("[InnInterior] Spawned universal Town Storage chest")


## Spawn the tavern fireplace (full rest + level up)
func _spawn_tavern_fireplace() -> void:
	# Tavern fireplace in northwest corner near the bar
	# Full recovery + allows leveling up (spending XP)
	var fireplace := RestSpot.spawn_rest_spot(self, Vector3(-4, 0, -4), "Tavern Hearth")
	fireplace.rest_type = RestSpot.RestSpotType.TAVERN_FIREPLACE
	print("[InnInterior] Spawned tavern fireplace (full rest + level up)")


## Create the small rental room (4x4 with bed)
func _create_rental_room() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.22, 0.15)
	floor_mat.roughness = 0.9

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.35, 0.32, 0.28)
	wall_mat.roughness = 0.95

	# Rental room floor (4x4, offset east of main room)
	var room_floor := CSGBox3D.new()
	room_floor.name = "RentalRoomFloor"
	room_floor.size = Vector3(4, 0.2, 4)
	room_floor.position = Vector3(8.5, -0.1, 0)
	room_floor.material = floor_mat
	room_floor.use_collision = true
	add_child(room_floor)

	# Rental room north wall
	var room_north := CSGBox3D.new()
	room_north.name = "RentalRoomNorth"
	room_north.size = Vector3(4, 4, 0.3)
	room_north.position = Vector3(8.5, 2, -2)
	room_north.material = wall_mat
	room_north.use_collision = true
	add_child(room_north)

	# Rental room south wall
	var room_south := CSGBox3D.new()
	room_south.name = "RentalRoomSouth"
	room_south.size = Vector3(4, 4, 0.3)
	room_south.position = Vector3(8.5, 2, 2)
	room_south.material = wall_mat
	room_south.use_collision = true
	add_child(room_south)

	# Rental room east wall
	var room_east := CSGBox3D.new()
	room_east.name = "RentalRoomEast"
	room_east.size = Vector3(0.3, 4, 4)
	room_east.position = Vector3(10.5, 2, 0)
	room_east.material = wall_mat
	room_east.use_collision = true
	add_child(room_east)

	# Rental room ceiling
	var room_ceiling := CSGBox3D.new()
	room_ceiling.name = "RentalRoomCeiling"
	room_ceiling.size = Vector3(4, 0.2, 4)
	room_ceiling.position = Vector3(8.5, 4.1, 0)
	room_ceiling.material = wall_mat
	room_ceiling.use_collision = true
	add_child(room_ceiling)

	# Bed in the rental room (against east wall)
	rental_room_bed = RentableBed.spawn_bed(self, Vector3(9.5, 0, 0), "Inn Bed", false)
	print("[InnInterior] Created rental room with bed")

## Make the rental room bed available (called by innkeeper after payment)
func make_bed_available() -> void:
	if rental_room_bed:
		rental_room_bed.make_available()
		print("[InnInterior] Rental room bed now available")

## Create warm tavern lighting
func _create_ambient_lighting() -> void:
	# Main fireplace light (warm orange) - northwest corner
	var fireplace_light := OmniLight3D.new()
	fireplace_light.name = "FireplaceLight"
	fireplace_light.light_color = Color(1.0, 0.6, 0.3)
	fireplace_light.light_energy = 2.0
	fireplace_light.omni_range = 8.0
	fireplace_light.position = Vector3(-4, 1.5, -4)
	add_child(fireplace_light)

	# Bar area light
	var bar_light := OmniLight3D.new()
	bar_light.name = "BarLight"
	bar_light.light_color = Color(1.0, 0.7, 0.4)
	bar_light.light_energy = 1.5
	bar_light.omni_range = 6.0
	bar_light.position = Vector3(-3, 2.5, -3)
	add_child(bar_light)

	# Center room light
	var center_light := OmniLight3D.new()
	center_light.name = "CenterLight"
	center_light.light_color = Color(0.9, 0.7, 0.5)
	center_light.light_energy = 1.2
	center_light.omni_range = 7.0
	center_light.position = Vector3(0, 3, 0)
	add_child(center_light)

	# Rental room light (dimmer, cozy)
	var rental_light := OmniLight3D.new()
	rental_light.name = "RentalRoomLight"
	rental_light.light_color = Color(0.8, 0.6, 0.4)
	rental_light.light_energy = 0.8
	rental_light.omni_range = 4.0
	rental_light.position = Vector3(8.5, 2.5, 0)
	add_child(rental_light)
