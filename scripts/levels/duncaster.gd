## duncaster.gd - Duncaster Mountain Town
## Mountain settlement near Elder Moor - main route BLOCKED by massive rockslide
## This forces players to take the long southern route through Rotherhine
## Contains: Inn, merchants, fast travel shrine, NPCs discussing the blockage
extends Node3D

const ZONE_ID := "town_duncaster"

var nav_region: NavigationRegion3D

func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Duncaster")

	_create_terrain()
	_create_mountain_walls()
	_create_rockslide_blockage()
	_spawn_buildings()
	_spawn_merchants()
	_spawn_inn()
	_spawn_npcs()
	_spawn_fast_travel_shrine()
	_spawn_portal_to_elder_moor()
	_setup_navigation()
	_setup_day_night_cycle()

	print("[Duncaster] Mountain town loaded - route blocked by rockslide")


## Setup dynamic day/night lighting
func _setup_day_night_cycle() -> void:
	DayNightCycle.add_to_level(self)


## Create mountain terrain - rocky ground with snow patches
func _create_terrain() -> void:
	# Load textures
	var stone_floor_tex: Texture2D = load("res://Sprite folders grab bag/stonefloor.png")

	# Materials
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.45, 0.42, 0.4)
	stone_mat.roughness = 0.95
	if stone_floor_tex:
		stone_mat.albedo_texture = stone_floor_tex
		stone_mat.uv1_scale = Vector3(15, 15, 1)
		stone_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var path_mat := StandardMaterial3D.new()
	path_mat.albedo_color = Color(0.38, 0.35, 0.32)
	path_mat.roughness = 0.9
	if stone_floor_tex:
		path_mat.albedo_texture = stone_floor_tex
		path_mat.uv1_scale = Vector3(8, 20, 1)
		path_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var snow_mat := StandardMaterial3D.new()
	snow_mat.albedo_color = Color(0.85, 0.88, 0.9)
	snow_mat.roughness = 0.8

	# Main town ground (smaller mountain town area)
	var town_ground := CSGBox3D.new()
	town_ground.name = "TownGround"
	town_ground.size = Vector3(70, 1, 80)
	town_ground.position = Vector3(0, -0.5, 0)
	town_ground.material = stone_mat
	town_ground.use_collision = true
	add_child(town_ground)

	# Main path running north-south (leads to blocked passage)
	var main_path := CSGBox3D.new()
	main_path.name = "MainPath"
	main_path.size = Vector3(8, 0.05, 80)
	main_path.position = Vector3(0, 0.03, 0)
	main_path.material = path_mat
	main_path.use_collision = false
	add_child(main_path)

	# Snow patches on the edges (mountain altitude)
	_create_snow_patch(Vector3(-28, 0, 25), Vector3(12, 0.05, 15), snow_mat)
	_create_snow_patch(Vector3(28, 0, 30), Vector3(10, 0.05, 12), snow_mat)
	_create_snow_patch(Vector3(-25, 0, -20), Vector3(8, 0.05, 10), snow_mat)
	_create_snow_patch(Vector3(30, 0, -15), Vector3(12, 0.05, 14), snow_mat)


func _create_snow_patch(pos: Vector3, size: Vector3, mat: Material) -> void:
	var snow := CSGBox3D.new()
	snow.name = "SnowPatch"
	snow.size = size
	snow.position = pos
	snow.material = mat
	snow.use_collision = false
	add_child(snow)


## Create mountain walls surrounding the town
func _create_mountain_walls() -> void:
	var mountain_mat := StandardMaterial3D.new()
	mountain_mat.albedo_color = Color(0.4, 0.38, 0.35)
	mountain_mat.roughness = 0.95

	var snow_cap_mat := StandardMaterial3D.new()
	snow_cap_mat.albedo_color = Color(0.9, 0.92, 0.95)
	snow_cap_mat.roughness = 0.7

	# East mountain wall
	_create_mountain_section(Vector3(38, 0, 0), Vector3(8, 20, 80), mountain_mat, snow_cap_mat)

	# West mountain wall
	_create_mountain_section(Vector3(-38, 0, 0), Vector3(8, 18, 80), mountain_mat, snow_cap_mat)

	# South entrance area - lower walls with gap for portal
	_create_mountain_section(Vector3(-28, 0, 42), Vector3(12, 12, 8), mountain_mat, snow_cap_mat)
	_create_mountain_section(Vector3(28, 0, 42), Vector3(12, 12, 8), mountain_mat, snow_cap_mat)

	# Jagged mountain peaks in background (north - behind the rockslide)
	_create_mountain_peak(Vector3(-20, 0, -50), 25.0, mountain_mat, snow_cap_mat)
	_create_mountain_peak(Vector3(0, 0, -55), 30.0, mountain_mat, snow_cap_mat)
	_create_mountain_peak(Vector3(20, 0, -48), 22.0, mountain_mat, snow_cap_mat)


func _create_mountain_section(pos: Vector3, size: Vector3, rock_mat: Material, snow_mat: Material) -> void:
	# Main rock body
	var rock := CSGBox3D.new()
	rock.name = "MountainRock"
	rock.size = size
	rock.position = pos + Vector3(0, size.y / 2.0, 0)
	rock.material = rock_mat
	rock.use_collision = true
	add_child(rock)

	# Snow cap on top
	var cap := CSGBox3D.new()
	cap.name = "SnowCap"
	cap.size = Vector3(size.x + 0.5, 1.5, size.z + 0.5)
	cap.position = pos + Vector3(0, size.y + 0.75, 0)
	cap.material = snow_mat
	cap.use_collision = false
	add_child(cap)


func _create_mountain_peak(pos: Vector3, height: float, rock_mat: Material, snow_mat: Material) -> void:
	# Jagged peak (approximated with stacked boxes)
	var base_size := height * 0.6

	# Base
	var base := CSGBox3D.new()
	base.name = "PeakBase"
	base.size = Vector3(base_size, height * 0.4, base_size)
	base.position = pos + Vector3(0, height * 0.2, 0)
	base.material = rock_mat
	base.use_collision = true
	add_child(base)

	# Middle section
	var mid := CSGBox3D.new()
	mid.name = "PeakMid"
	mid.size = Vector3(base_size * 0.7, height * 0.35, base_size * 0.7)
	mid.position = pos + Vector3(0, height * 0.575, 0)
	mid.material = rock_mat
	mid.use_collision = true
	add_child(mid)

	# Peak
	var peak := CSGBox3D.new()
	peak.name = "PeakTop"
	peak.size = Vector3(base_size * 0.4, height * 0.25, base_size * 0.4)
	peak.position = pos + Vector3(0, height * 0.875, 0)
	peak.material = snow_mat
	peak.use_collision = false
	add_child(peak)


## Create the MASSIVE rockslide blocking the northern passage
## This is the KEY feature - explains why players must take the southern route
func _create_rockslide_blockage() -> void:
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.35, 0.32, 0.3)
	rock_mat.roughness = 0.95

	var dark_rock_mat := StandardMaterial3D.new()
	dark_rock_mat.albedo_color = Color(0.28, 0.25, 0.22)
	dark_rock_mat.roughness = 0.98

	var debris_mat := StandardMaterial3D.new()
	debris_mat.albedo_color = Color(0.4, 0.38, 0.35)
	debris_mat.roughness = 0.9

	# Main blockage wall - massive pile of boulders
	var main_blockage := CSGBox3D.new()
	main_blockage.name = "RockslideMain"
	main_blockage.size = Vector3(50, 15, 12)
	main_blockage.position = Vector3(0, 7.5, -38)
	main_blockage.material = rock_mat
	main_blockage.use_collision = true
	add_child(main_blockage)

	# Large boulders scattered on top and front
	var boulder_positions := [
		# Top boulders
		Vector3(-15, 15, -38),
		Vector3(-5, 16, -36),
		Vector3(8, 14, -38),
		Vector3(18, 15, -37),
		Vector3(-8, 17, -35),
		Vector3(12, 16, -35),
		# Front boulders (spilling into the path)
		Vector3(-10, 3, -30),
		Vector3(0, 4, -28),
		Vector3(8, 2, -29),
		Vector3(-5, 5, -32),
		Vector3(15, 3, -31),
		Vector3(-18, 2, -30),
		# Medium scattered debris
		Vector3(-12, 1, -26),
		Vector3(5, 1.5, -25),
		Vector3(10, 1, -27),
		Vector3(-3, 2, -24),
	]

	for i in boulder_positions.size():
		var pos: Vector3 = boulder_positions[i]
		_create_boulder(pos, i, rock_mat if i % 2 == 0 else dark_rock_mat)

	# Smaller debris and rubble scattered around
	_create_debris_field(Vector3(0, 0, -25), debris_mat)

	# Warning sign near the blockage
	_create_warning_sign(Vector3(0, 0, -20))

	print("[Duncaster] Created rockslide blockage at northern passage")


func _create_boulder(pos: Vector3, index: int, mat: Material) -> void:
	var boulder := CSGBox3D.new()
	boulder.name = "Boulder_%d" % index

	# Randomize size for natural look
	var base_size := randf_range(2.5, 5.0)
	boulder.size = Vector3(
		base_size * randf_range(0.8, 1.2),
		base_size * randf_range(0.6, 1.0),
		base_size * randf_range(0.8, 1.2)
	)

	boulder.position = pos
	boulder.rotation.y = randf_range(0, TAU)
	boulder.rotation.x = randf_range(-0.2, 0.2)
	boulder.rotation.z = randf_range(-0.15, 0.15)
	boulder.material = mat
	boulder.use_collision = true
	add_child(boulder)


func _create_debris_field(center: Vector3, mat: Material) -> void:
	# Scatter small rocks and rubble
	for i in range(20):
		var debris := CSGBox3D.new()
		debris.name = "Debris_%d" % i
		debris.size = Vector3(
			randf_range(0.3, 1.2),
			randf_range(0.2, 0.6),
			randf_range(0.3, 1.2)
		)
		debris.position = center + Vector3(
			randf_range(-12, 12),
			debris.size.y / 2.0,
			randf_range(-5, 5)
		)
		debris.rotation.y = randf_range(0, TAU)
		debris.material = mat
		debris.use_collision = true
		add_child(debris)


func _create_warning_sign(pos: Vector3) -> void:
	var sign_root := Node3D.new()
	sign_root.name = "WarningSign"
	sign_root.position = pos
	add_child(sign_root)

	# Post
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.35, 0.28, 0.2)
	post_mat.roughness = 0.9

	var post := CSGCylinder3D.new()
	post.name = "SignPost"
	post.radius = 0.1
	post.height = 2.5
	post.sides = 6
	post.position.y = 1.25
	post.material = post_mat
	post.use_collision = true
	sign_root.add_child(post)

	# Sign board
	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.6, 0.5, 0.35)
	board_mat.roughness = 0.85

	var board := CSGBox3D.new()
	board.name = "SignBoard"
	board.size = Vector3(1.8, 1.0, 0.1)
	board.position = Vector3(0, 2.3, 0)
	board.material = board_mat
	board.use_collision = false
	sign_root.add_child(board)

	# Red warning stripe
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.7, 0.2, 0.15)
	stripe_mat.roughness = 0.7

	var stripe := CSGBox3D.new()
	stripe.name = "WarningStripe"
	stripe.size = Vector3(1.6, 0.2, 0.12)
	stripe.position = Vector3(0, 2.5, 0)
	stripe.material = stripe_mat
	stripe.use_collision = false
	sign_root.add_child(stripe)


## Spawn town buildings
func _spawn_buildings() -> void:
	var stone_wall_tex: Texture2D = load("res://Sprite folders grab bag/stonewall.png")

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.5, 0.48, 0.45)
	wall_mat.roughness = 0.9
	if stone_wall_tex:
		wall_mat.albedo_texture = stone_wall_tex
		wall_mat.uv1_scale = Vector3(2, 2, 1)
		wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.3, 0.28, 0.25)
	roof_mat.roughness = 0.85

	# Town buildings (smaller mountain settlement)
	_create_building(Vector3(-18, 0, 10), "StorageHouse", wall_mat, roof_mat, 7.0, 5.0, 5.0)
	_create_building(Vector3(18, 0, 15), "MinersCottage", wall_mat, roof_mat, 6.0, 5.0, 4.5)
	_create_building(Vector3(-20, 0, -8), "TownHall", wall_mat, roof_mat, 10.0, 8.0, 6.0)


func _create_building(pos: Vector3, building_name: String, wall_mat: Material, roof_mat: Material, width: float, depth: float, height: float) -> void:
	var building_root := Node3D.new()
	building_root.name = building_name
	add_child(building_root)

	# Walls
	var walls := CSGBox3D.new()
	walls.name = "Walls"
	walls.size = Vector3(width, height, depth)
	walls.position = pos + Vector3(0, height / 2.0, 0)
	walls.material = wall_mat
	walls.use_collision = true
	building_root.add_child(walls)

	# Roof
	var roof := CSGBox3D.new()
	roof.name = "Roof"
	roof.size = Vector3(width + 0.8, 0.6, depth + 0.8)
	roof.position = pos + Vector3(0, height + 0.3, 0)
	roof.material = roof_mat
	roof.use_collision = true
	building_root.add_child(roof)

	# Interior light
	var light := OmniLight3D.new()
	light.name = "BuildingLight"
	light.light_color = Color(1.0, 0.85, 0.6)
	light.light_energy = 1.2
	light.omni_range = 8.0
	light.position = pos + Vector3(0, height - 1.0, 0)
	building_root.add_child(light)


## Spawn merchants
func _spawn_merchants() -> void:
	# General store
	_create_merchant_shop(Vector3(18, 0, 0), "Mountain Provisions", "general", Color(0.5, 0.45, 0.38))

	# Blacksmith (mining tools, weapons)
	_create_merchant_shop(Vector3(-18, 0, 25), "Stonepick Smithy", "blacksmith", Color(0.4, 0.35, 0.4))

	print("[Duncaster] Spawned 2 merchant shops")


func _create_merchant_shop(pos: Vector3, shop_name: String, shop_type: String, trim_color: Color) -> void:
	var shop_root := Node3D.new()
	shop_root.name = "Shop_" + shop_name.replace(" ", "_")
	add_child(shop_root)

	var stone_wall_tex: Texture2D = load("res://Sprite folders grab bag/stonewall.png")
	var wood_floor_tex: Texture2D = load("res://Sprite folders grab bag/woodenfloor.png")

	var width := 7.0
	var depth := 7.0
	var height := 4.5
	var wall_thickness := 0.4

	# Wall material
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.55, 0.52, 0.48)
	wall_mat.roughness = 0.9
	if stone_wall_tex:
		wall_mat.albedo_texture = stone_wall_tex
		wall_mat.uv1_scale = Vector3(2, 2, 1)
		wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Floor material
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.6, 0.5, 0.4)
	floor_mat.roughness = 0.95
	if wood_floor_tex:
		floor_mat.albedo_texture = wood_floor_tex
		floor_mat.uv1_scale = Vector3(3, 3, 1)
		floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Trim material
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = trim_color
	trim_mat.roughness = 0.7

	# Floor
	var floor_mesh := CSGBox3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.size = Vector3(width, 0.2, depth)
	floor_mesh.position = pos + Vector3(0, 0.1, 0)
	floor_mesh.material = floor_mat
	floor_mesh.use_collision = true
	shop_root.add_child(floor_mesh)

	# Back wall
	var back_wall := CSGBox3D.new()
	back_wall.name = "BackWall"
	back_wall.size = Vector3(width, height, wall_thickness)
	back_wall.position = pos + Vector3(0, height / 2.0, -depth / 2.0 + wall_thickness / 2.0)
	back_wall.material = wall_mat
	back_wall.use_collision = true
	shop_root.add_child(back_wall)

	# Left wall
	var left_wall := CSGBox3D.new()
	left_wall.name = "LeftWall"
	left_wall.size = Vector3(wall_thickness, height, depth - wall_thickness)
	left_wall.position = pos + Vector3(-width / 2.0 + wall_thickness / 2.0, height / 2.0, wall_thickness / 2.0)
	left_wall.material = wall_mat
	left_wall.use_collision = true
	shop_root.add_child(left_wall)

	# Right wall
	var right_wall := CSGBox3D.new()
	right_wall.name = "RightWall"
	right_wall.size = Vector3(wall_thickness, height, depth - wall_thickness)
	right_wall.position = pos + Vector3(width / 2.0 - wall_thickness / 2.0, height / 2.0, wall_thickness / 2.0)
	right_wall.material = wall_mat
	right_wall.use_collision = true
	shop_root.add_child(right_wall)

	# Front doorway posts
	var doorway_width := 2.5
	var post_width := (width - doorway_width) / 2.0 - wall_thickness

	var front_left := CSGBox3D.new()
	front_left.name = "FrontLeftPost"
	front_left.size = Vector3(post_width, height, wall_thickness)
	front_left.position = pos + Vector3(-width / 2.0 + wall_thickness + post_width / 2.0, height / 2.0, depth / 2.0 - wall_thickness / 2.0)
	front_left.material = wall_mat
	front_left.use_collision = true
	shop_root.add_child(front_left)

	var front_right := CSGBox3D.new()
	front_right.name = "FrontRightPost"
	front_right.size = Vector3(post_width, height, wall_thickness)
	front_right.position = pos + Vector3(width / 2.0 - wall_thickness - post_width / 2.0, height / 2.0, depth / 2.0 - wall_thickness / 2.0)
	front_right.material = wall_mat
	front_right.use_collision = true
	shop_root.add_child(front_right)

	# Awning
	var awning := CSGBox3D.new()
	awning.name = "Awning"
	awning.size = Vector3(doorway_width + 1.5, 0.3, 1.5)
	awning.position = pos + Vector3(0, height - 0.5, depth / 2.0 + 0.5)
	awning.material = trim_mat
	awning.use_collision = false
	shop_root.add_child(awning)

	# Roof
	var roof := CSGBox3D.new()
	roof.name = "Roof"
	roof.size = Vector3(width + 0.5, 0.5, depth + 0.5)
	roof.position = pos + Vector3(0, height + 0.25, 0)
	roof.material = trim_mat
	roof.use_collision = false
	shop_root.add_child(roof)

	# Shop light
	var shop_light := OmniLight3D.new()
	shop_light.name = "ShopLight"
	shop_light.light_color = Color(1.0, 0.85, 0.6)
	shop_light.light_energy = 1.5
	shop_light.omni_range = 7.0
	shop_light.position = pos + Vector3(0, height - 1.0, 0)
	shop_root.add_child(shop_light)

	# Spawn merchant inside
	var merchant_pos := pos + Vector3(0, 0, -1.5)
	Merchant.spawn_merchant(
		self,
		merchant_pos,
		shop_name,
		LootTables.LootTier.UNCOMMON,
		shop_type
	)


## Spawn the inn
func _spawn_inn() -> void:
	var inn_pos := Vector3(20, 0, -10)

	var inn_root := Node3D.new()
	inn_root.name = "DuncasterInn"
	add_child(inn_root)

	var stone_wall_tex: Texture2D = load("res://Sprite folders grab bag/stonewall.png")
	var wood_floor_tex: Texture2D = load("res://Sprite folders grab bag/woodenfloor.png")

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.52, 0.48, 0.44)
	wall_mat.roughness = 0.9
	if stone_wall_tex:
		wall_mat.albedo_texture = stone_wall_tex
		wall_mat.uv1_scale = Vector3(3, 2, 1)
		wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.55, 0.45, 0.35)
	floor_mat.roughness = 0.95
	if wood_floor_tex:
		floor_mat.albedo_texture = wood_floor_tex
		floor_mat.uv1_scale = Vector3(4, 4, 1)
		floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.32, 0.28, 0.24)
	roof_mat.roughness = 0.85

	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.5, 0.4, 0.3)
	trim_mat.roughness = 0.7

	var width := 12.0
	var depth := 10.0
	var height := 5.5
	var wall_thickness := 0.5

	# Floor
	var floor_mesh := CSGBox3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.size = Vector3(width, 0.2, depth)
	floor_mesh.position = inn_pos + Vector3(0, 0.1, 0)
	floor_mesh.material = floor_mat
	floor_mesh.use_collision = true
	inn_root.add_child(floor_mesh)

	# Back wall
	var back_wall := CSGBox3D.new()
	back_wall.name = "BackWall"
	back_wall.size = Vector3(width, height, wall_thickness)
	back_wall.position = inn_pos + Vector3(0, height / 2.0, -depth / 2.0 + wall_thickness / 2.0)
	back_wall.material = wall_mat
	back_wall.use_collision = true
	inn_root.add_child(back_wall)

	# Right wall
	var right_wall := CSGBox3D.new()
	right_wall.name = "RightWall"
	right_wall.size = Vector3(wall_thickness, height, depth - wall_thickness)
	right_wall.position = inn_pos + Vector3(width / 2.0 - wall_thickness / 2.0, height / 2.0, wall_thickness / 2.0)
	right_wall.material = wall_mat
	right_wall.use_collision = true
	inn_root.add_child(right_wall)

	# Front wall
	var front_wall := CSGBox3D.new()
	front_wall.name = "FrontWall"
	front_wall.size = Vector3(width - wall_thickness, height, wall_thickness)
	front_wall.position = inn_pos + Vector3(-wall_thickness / 2.0, height / 2.0, depth / 2.0 - wall_thickness / 2.0)
	front_wall.material = wall_mat
	front_wall.use_collision = true
	inn_root.add_child(front_wall)

	# Left wall with doorway
	var door_height := 3.5
	var door_width := 2.5
	var wall_above := height - door_height
	var wall_beside := (depth - wall_thickness - door_width) / 2.0

	var left_above := CSGBox3D.new()
	left_above.name = "LeftWallAbove"
	left_above.size = Vector3(wall_thickness, wall_above, depth - wall_thickness)
	left_above.position = inn_pos + Vector3(-width / 2.0 + wall_thickness / 2.0, height - wall_above / 2.0, wall_thickness / 2.0)
	left_above.material = wall_mat
	left_above.use_collision = true
	inn_root.add_child(left_above)

	var left_front := CSGBox3D.new()
	left_front.name = "LeftWallFront"
	left_front.size = Vector3(wall_thickness, door_height, wall_beside)
	left_front.position = inn_pos + Vector3(-width / 2.0 + wall_thickness / 2.0, door_height / 2.0, depth / 2.0 - wall_thickness - wall_beside / 2.0)
	left_front.material = wall_mat
	left_front.use_collision = true
	inn_root.add_child(left_front)

	var left_back := CSGBox3D.new()
	left_back.name = "LeftWallBack"
	left_back.size = Vector3(wall_thickness, door_height, wall_beside)
	left_back.position = inn_pos + Vector3(-width / 2.0 + wall_thickness / 2.0, door_height / 2.0, -depth / 2.0 + wall_thickness + wall_beside / 2.0)
	left_back.material = wall_mat
	left_back.use_collision = true
	inn_root.add_child(left_back)

	# Roof
	var roof := CSGBox3D.new()
	roof.name = "Roof"
	roof.size = Vector3(width + 0.8, 0.5, depth + 0.8)
	roof.position = inn_pos + Vector3(0, height + 0.25, 0)
	roof.material = roof_mat
	roof.use_collision = true
	inn_root.add_child(roof)

	# Awning over door
	var awning := CSGBox3D.new()
	awning.name = "Awning"
	awning.size = Vector3(1.8, 0.3, door_width + 1.5)
	awning.position = inn_pos + Vector3(-width / 2.0 - 0.7, door_height, 0)
	awning.material = trim_mat
	awning.use_collision = false
	inn_root.add_child(awning)

	# Inn light
	var inn_light := OmniLight3D.new()
	inn_light.name = "InnLight"
	inn_light.light_color = Color(1.0, 0.8, 0.5)
	inn_light.light_energy = 2.0
	inn_light.omni_range = 10.0
	inn_light.position = inn_pos + Vector3(0, height - 1.0, 0)
	inn_root.add_child(inn_light)

	# Door position (on west side of inn)
	var door_pos := inn_pos + Vector3(-width / 2.0 - 0.5, 0, 0)

	var inn_door := ZoneDoor.spawn_door(
		self,
		door_pos,
		"res://scenes/levels/inn_interior.tscn",
		"from_duncaster",
		"The Snowpeak Lodge"
	)
	inn_door.rotation.y = PI / 2  # Face west

	# Return spawn point
	var return_spawn := Node3D.new()
	return_spawn.name = "from_inn"
	return_spawn.position = door_pos + Vector3(-2, 0.1, 0)
	return_spawn.add_to_group("spawn_points")
	return_spawn.set_meta("spawn_id", "from_inn")
	add_child(return_spawn)

	# Rest spot inside/near inn
	RestSpot.spawn_rest_spot(self, inn_pos + Vector3(3, 0, 2), "Lodge Hearth")

	print("[Duncaster] Spawned The Snowpeak Lodge Inn")


## Spawn NPCs talking about the rockslide
func _spawn_npcs() -> void:
	# Create several ambient NPCs with rockslide-related dialog
	_spawn_ambient_npc(Vector3(-5, 0, -15), "Worried Traveler", [
		"The mountain pass has been blocked for weeks now.",
		"That rockslide came down without warning... took the whole road with it.",
		"If you need to go north, you'll have to take the long way through the south."
	])

	_spawn_ambient_npc(Vector3(5, 0, 5), "Local Miner", [
		"Aye, I was there when it happened. Sounded like thunder from the mountain itself.",
		"Some say it wasn't natural... dark forces at work.",
		"The road to Falkenhaften is completely impassable now."
	])

	_spawn_ambient_npc(Vector3(-8, 0, 20), "Merchant's Guard", [
		"Our caravan's been stuck here for days.",
		"We were headed north, but now we'll have to go all the way around.",
		"The southern route through Rotherhine is the only way now."
	])

	print("[Duncaster] Spawned NPCs discussing the rockslide")


func _spawn_ambient_npc(pos: Vector3, npc_name: String, dialog_lines: Array) -> void:
	var npc := StaticBody3D.new()
	npc.name = npc_name.replace(" ", "_")
	npc.position = pos
	npc.collision_layer = 1
	npc.collision_mask = 0
	add_child(npc)

	# Collision
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	col.shape = capsule
	col.position.y = 0.9
	npc.add_child(col)

	# Visual (simple capsule for now)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.35
	capsule_mesh.height = 1.6
	mesh.mesh = capsule_mesh
	mesh.position.y = 0.8

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.45, 0.4)
	mat.roughness = 0.9
	mesh.material_override = mat
	npc.add_child(mesh)

	# Interaction area
	var interaction := Area3D.new()
	interaction.name = "InteractionArea"
	interaction.collision_layer = 256  # Layer 9
	interaction.collision_mask = 0
	npc.add_child(interaction)

	var area_col := CollisionShape3D.new()
	var area_shape := CapsuleShape3D.new()
	area_shape.radius = 0.6
	area_shape.height = 2.0
	area_col.shape = area_shape
	area_col.position.y = 1.0
	interaction.add_child(area_col)

	# Store dialog data
	npc.add_to_group("interactable")
	npc.set_meta("npc_name", npc_name)
	npc.set_meta("dialog_lines", dialog_lines)
	npc.set_meta("dialog_index", 0)

	# Add interaction script
	npc.set_script(_create_npc_script())


func _create_npc_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = """
extends StaticBody3D

func interact(_interactor: Node) -> void:
	var lines: Array = get_meta("dialog_lines")
	var index: int = get_meta("dialog_index")
	var npc_name: String = get_meta("npc_name")

	if lines.is_empty():
		return

	var line: String = lines[index]
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(npc_name + ": " + line)

	# Cycle through lines
	set_meta("dialog_index", (index + 1) % lines.size())

func get_interaction_prompt() -> String:
	var npc_name: String = get_meta("npc_name")
	return "Talk to " + npc_name
"""
	script.reload()
	return script


## Spawn fast travel shrine
func _spawn_fast_travel_shrine() -> void:
	FastTravelShrine.spawn_shrine(
		self,
		Vector3(-5, 0, 10),
		"Duncaster Shrine",
		"duncaster_shrine"
	)
	print("[Duncaster] Spawned fast travel shrine")


## Spawn portal back to Elder Moor
func _spawn_portal_to_elder_moor() -> void:
	# Exit through the southern passage
	var exit_portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, 0, 42),
		SceneManager.RETURN_TO_WILDERNESS,
		"from_duncaster",
		"Travel to Wilderness"
	)
	exit_portal.rotation.y = PI  # Face south

	# Spawn point for arriving from wilderness
	var from_world := Node3D.new()
	from_world.name = "from_wilderness"
	from_world.position = Vector3(0, 0.1, 38)
	from_world.add_to_group("spawn_points")
	from_world.set_meta("spawn_id", "from_wilderness")
	add_child(from_world)

	# Compatibility spawn point
	var from_world_compat := Node3D.new()
	from_world_compat.name = "from_open_world"
	from_world_compat.position = Vector3(0, 0.1, 38)
	from_world_compat.add_to_group("spawn_points")
	from_world_compat.set_meta("spawn_id", "from_open_world")
	add_child(from_world_compat)

	# Default spawn point
	var default_spawn := Node3D.new()
	default_spawn.name = "default"
	default_spawn.position = Vector3(0, 0.1, 30)
	default_spawn.add_to_group("spawn_points")
	default_spawn.set_meta("spawn_id", "default")
	add_child(default_spawn)

	# Register as compass POI
	exit_portal.add_to_group("compass_poi")
	exit_portal.set_meta("poi_id", "elder_moor_exit")
	exit_portal.set_meta("poi_name", "To Elder Moor")
	exit_portal.set_meta("poi_color", Color(0.4, 0.6, 0.3))

	print("[Duncaster] Spawned portal to Elder Moor")


## Setup navigation mesh
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
		print("[Duncaster] Navigation mesh baked!")
