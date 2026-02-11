## whaelers_drake.gd - Whaeler's Drake Canyon Town (Tier 3 Town)
## Town built into cliff edges of a Grand Canyon-type abyss
## Large bridge connecting two sides, rickety rope bridges throughout
## Vampire cult secretly taking over, missing dwarf prospectors located here
extends Node3D

const ZONE_ID := "town_whaelers_drake"

## Elevation constants for vertical layout
const CANYON_DEPTH := -50.0  # How deep the canyon goes (hidden by fog)
const LOWER_LEVEL := 0.0     # Canyon floor level (not accessible)
const MIDDLE_LEVEL := 8.0    # Middle cliff platforms
const UPPER_LEVEL := 16.0    # Upper cliff platforms
const BRIDGE_LEVEL := 12.0   # Main bridge height

var nav_region: NavigationRegion3D

func _ready() -> void:
	_create_canyon_terrain()
	_create_main_bridge()
	_create_rickety_bridges()
	_create_west_cliff_buildings()
	_create_east_cliff_buildings()
	_spawn_tavern()
	_spawn_inn()
	_spawn_cult_hints()
	_spawn_npcs()
	_spawn_fast_travel_shrine()
	_spawn_portals()
	_setup_navigation()
	_setup_day_night_cycle()
	print("[Whaeler's Drake] Canyon town loaded - Tier 3 Town")


## Setup dynamic day/night lighting
func _setup_day_night_cycle() -> void:
	DayNightCycle.add_to_level(self)


## Create the canyon terrain - two cliff sides with an abyss between
func _create_canyon_terrain() -> void:
	# Load textures
	var stone_wall_tex: Texture2D = load("res://Sprite folders grab bag/stonewall.png")
	var stone_floor_tex: Texture2D = load("res://Sprite folders grab bag/stonefloor.png")

	# Cliff face material - rugged canyon stone
	var cliff_mat := StandardMaterial3D.new()
	cliff_mat.albedo_color = Color(0.45, 0.38, 0.32)
	cliff_mat.roughness = 0.95
	if stone_wall_tex:
		cliff_mat.albedo_texture = stone_wall_tex
		cliff_mat.uv1_scale = Vector3(8, 8, 1)
		cliff_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Canyon floor material (darker, barely visible through fog)
	var abyss_mat := StandardMaterial3D.new()
	abyss_mat.albedo_color = Color(0.15, 0.12, 0.1)
	abyss_mat.roughness = 1.0

	# Path/platform material
	var path_mat := StandardMaterial3D.new()
	path_mat.albedo_color = Color(0.5, 0.45, 0.4)
	path_mat.roughness = 0.9
	if stone_floor_tex:
		path_mat.albedo_texture = stone_floor_tex
		path_mat.uv1_scale = Vector3(10, 10, 1)
		path_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# WEST CLIFF SIDE (main cliff face)
	var west_cliff := CSGBox3D.new()
	west_cliff.name = "WestCliff"
	west_cliff.size = Vector3(50, 60, 80)
	west_cliff.position = Vector3(-40, -10, 0)
	west_cliff.material = cliff_mat
	west_cliff.use_collision = true
	add_child(west_cliff)

	# West cliff walkable ledge (lower level)
	var west_ledge_lower := CSGBox3D.new()
	west_ledge_lower.name = "WestLedgeLower"
	west_ledge_lower.size = Vector3(12, 1, 60)
	west_ledge_lower.position = Vector3(-9, LOWER_LEVEL - 0.5, 0)
	west_ledge_lower.material = path_mat
	west_ledge_lower.use_collision = true
	add_child(west_ledge_lower)

	# West cliff walkable ledge (middle level)
	var west_ledge_mid := CSGBox3D.new()
	west_ledge_mid.name = "WestLedgeMid"
	west_ledge_mid.size = Vector3(10, 1, 50)
	west_ledge_mid.position = Vector3(-10, MIDDLE_LEVEL - 0.5, 0)
	west_ledge_mid.material = path_mat
	west_ledge_mid.use_collision = true
	add_child(west_ledge_mid)

	# West cliff walkable ledge (upper level)
	var west_ledge_upper := CSGBox3D.new()
	west_ledge_upper.name = "WestLedgeUpper"
	west_ledge_upper.size = Vector3(8, 1, 40)
	west_ledge_upper.position = Vector3(-11, UPPER_LEVEL - 0.5, 0)
	west_ledge_upper.material = path_mat
	west_ledge_upper.use_collision = true
	add_child(west_ledge_upper)

	# EAST CLIFF SIDE
	var east_cliff := CSGBox3D.new()
	east_cliff.name = "EastCliff"
	east_cliff.size = Vector3(50, 60, 80)
	east_cliff.position = Vector3(40, -10, 0)
	east_cliff.material = cliff_mat
	east_cliff.use_collision = true
	add_child(east_cliff)

	# East cliff walkable ledge (lower level)
	var east_ledge_lower := CSGBox3D.new()
	east_ledge_lower.name = "EastLedgeLower"
	east_ledge_lower.size = Vector3(12, 1, 60)
	east_ledge_lower.position = Vector3(9, LOWER_LEVEL - 0.5, 0)
	east_ledge_lower.material = path_mat
	east_ledge_lower.use_collision = true
	add_child(east_ledge_lower)

	# East cliff walkable ledge (middle level)
	var east_ledge_mid := CSGBox3D.new()
	east_ledge_mid.name = "EastLedgeMid"
	east_ledge_mid.size = Vector3(10, 1, 50)
	east_ledge_mid.position = Vector3(10, MIDDLE_LEVEL - 0.5, 0)
	east_ledge_mid.material = path_mat
	east_ledge_mid.use_collision = true
	add_child(east_ledge_mid)

	# East cliff walkable ledge (upper level)
	var east_ledge_upper := CSGBox3D.new()
	east_ledge_upper.name = "EastLedgeUpper"
	east_ledge_upper.size = Vector3(8, 1, 40)
	east_ledge_upper.position = Vector3(11, UPPER_LEVEL - 0.5, 0)
	east_ledge_upper.material = path_mat
	east_ledge_upper.use_collision = true
	add_child(east_ledge_upper)

	# CANYON FLOOR (hidden by fog, but provides boundary)
	var canyon_floor := CSGBox3D.new()
	canyon_floor.name = "CanyonFloor"
	canyon_floor.size = Vector3(30, 5, 80)
	canyon_floor.position = Vector3(0, CANYON_DEPTH, 0)
	canyon_floor.material = abyss_mat
	canyon_floor.use_collision = true
	add_child(canyon_floor)

	# Cliff walls (to prevent seeing through the sides)
	_create_canyon_walls(cliff_mat)

	# Ramps connecting levels on each side
	_create_cliff_ramps(path_mat)


## Create canyon end walls
func _create_canyon_walls(cliff_mat: Material) -> void:
	# North canyon wall
	var north_wall := CSGBox3D.new()
	north_wall.name = "NorthCanyonWall"
	north_wall.size = Vector3(90, 60, 10)
	north_wall.position = Vector3(0, -10, 45)
	north_wall.material = cliff_mat
	north_wall.use_collision = true
	add_child(north_wall)

	# South canyon wall
	var south_wall := CSGBox3D.new()
	south_wall.name = "SouthCanyonWall"
	south_wall.size = Vector3(90, 60, 10)
	south_wall.position = Vector3(0, -10, -45)
	south_wall.material = cliff_mat
	south_wall.use_collision = true
	add_child(south_wall)


## Create ramps connecting different elevation levels
func _create_cliff_ramps(path_mat: Material) -> void:
	# West side ramp: Lower to Middle
	var west_ramp_1 := CSGBox3D.new()
	west_ramp_1.name = "WestRamp_LowerToMid"
	west_ramp_1.size = Vector3(4, 0.5, 12)
	west_ramp_1.position = Vector3(-12, (LOWER_LEVEL + MIDDLE_LEVEL) / 2.0, -20)
	west_ramp_1.rotation.x = -atan2(MIDDLE_LEVEL - LOWER_LEVEL, 12)
	west_ramp_1.material = path_mat
	west_ramp_1.use_collision = true
	add_child(west_ramp_1)

	# West side ramp: Middle to Upper
	var west_ramp_2 := CSGBox3D.new()
	west_ramp_2.name = "WestRamp_MidToUpper"
	west_ramp_2.size = Vector3(4, 0.5, 12)
	west_ramp_2.position = Vector3(-12, (MIDDLE_LEVEL + UPPER_LEVEL) / 2.0, 15)
	west_ramp_2.rotation.x = -atan2(UPPER_LEVEL - MIDDLE_LEVEL, 12)
	west_ramp_2.material = path_mat
	west_ramp_2.use_collision = true
	add_child(west_ramp_2)

	# East side ramp: Lower to Middle
	var east_ramp_1 := CSGBox3D.new()
	east_ramp_1.name = "EastRamp_LowerToMid"
	east_ramp_1.size = Vector3(4, 0.5, 12)
	east_ramp_1.position = Vector3(12, (LOWER_LEVEL + MIDDLE_LEVEL) / 2.0, 20)
	east_ramp_1.rotation.x = atan2(MIDDLE_LEVEL - LOWER_LEVEL, 12)
	east_ramp_1.material = path_mat
	east_ramp_1.use_collision = true
	add_child(east_ramp_1)

	# East side ramp: Middle to Upper
	var east_ramp_2 := CSGBox3D.new()
	east_ramp_2.name = "EastRamp_MidToUpper"
	east_ramp_2.size = Vector3(4, 0.5, 12)
	east_ramp_2.position = Vector3(12, (MIDDLE_LEVEL + UPPER_LEVEL) / 2.0, -15)
	east_ramp_2.rotation.x = atan2(UPPER_LEVEL - MIDDLE_LEVEL, 12)
	east_ramp_2.material = path_mat
	east_ramp_2.use_collision = true
	add_child(east_ramp_2)


## Create the main stone bridge spanning the canyon
func _create_main_bridge() -> void:
	var stone_wall_tex: Texture2D = load("res://Sprite folders grab bag/stonewall.png")

	# Bridge material - sturdy stone
	var bridge_mat := StandardMaterial3D.new()
	bridge_mat.albedo_color = Color(0.5, 0.45, 0.4)
	bridge_mat.roughness = 0.9
	if stone_wall_tex:
		bridge_mat.albedo_texture = stone_wall_tex
		bridge_mat.uv1_scale = Vector3(5, 2, 1)
		bridge_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var bridge_root := Node3D.new()
	bridge_root.name = "MainBridge"
	add_child(bridge_root)

	# Bridge deck - main walkable surface
	var bridge_deck := CSGBox3D.new()
	bridge_deck.name = "BridgeDeck"
	bridge_deck.size = Vector3(30, 1.5, 8)
	bridge_deck.position = Vector3(0, BRIDGE_LEVEL, 0)
	bridge_deck.material = bridge_mat
	bridge_deck.use_collision = true
	bridge_root.add_child(bridge_deck)

	# Bridge supports (pillars descending into the abyss)
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.4, 0.35, 0.3)
	pillar_mat.roughness = 0.95
	if stone_wall_tex:
		pillar_mat.albedo_texture = stone_wall_tex
		pillar_mat.uv1_scale = Vector3(2, 6, 1)
		pillar_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# West support pillar
	var west_pillar := CSGBox3D.new()
	west_pillar.name = "WestPillar"
	west_pillar.size = Vector3(4, 40, 4)
	west_pillar.position = Vector3(-10, BRIDGE_LEVEL - 20, 0)
	west_pillar.material = pillar_mat
	west_pillar.use_collision = true
	bridge_root.add_child(west_pillar)

	# East support pillar
	var east_pillar := CSGBox3D.new()
	east_pillar.name = "EastPillar"
	east_pillar.size = Vector3(4, 40, 4)
	east_pillar.position = Vector3(10, BRIDGE_LEVEL - 20, 0)
	east_pillar.material = pillar_mat
	east_pillar.use_collision = true
	bridge_root.add_child(east_pillar)

	# Bridge railings
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.45, 0.4, 0.35)
	rail_mat.roughness = 0.85

	# North railing
	var north_rail := CSGBox3D.new()
	north_rail.name = "NorthRailing"
	north_rail.size = Vector3(30, 1.2, 0.3)
	north_rail.position = Vector3(0, BRIDGE_LEVEL + 1.35, 3.7)
	north_rail.material = rail_mat
	north_rail.use_collision = true
	bridge_root.add_child(north_rail)

	# South railing
	var south_rail := CSGBox3D.new()
	south_rail.name = "SouthRailing"
	south_rail.size = Vector3(30, 1.2, 0.3)
	south_rail.position = Vector3(0, BRIDGE_LEVEL + 1.35, -3.7)
	south_rail.material = rail_mat
	south_rail.use_collision = true
	bridge_root.add_child(south_rail)

	# Railing posts
	for i in range(7):
		var x_pos := -12.0 + i * 4.0

		var north_post := CSGBox3D.new()
		north_post.name = "NorthPost_%d" % i
		north_post.size = Vector3(0.4, 1.8, 0.4)
		north_post.position = Vector3(x_pos, BRIDGE_LEVEL + 1.65, 3.7)
		north_post.material = rail_mat
		north_post.use_collision = true
		bridge_root.add_child(north_post)

		var south_post := CSGBox3D.new()
		south_post.name = "SouthPost_%d" % i
		south_post.size = Vector3(0.4, 1.8, 0.4)
		south_post.position = Vector3(x_pos, BRIDGE_LEVEL + 1.65, -3.7)
		south_post.material = rail_mat
		south_post.use_collision = true
		bridge_root.add_child(south_post)

	# Bridge torches
	var torch_positions := [Vector3(-8, BRIDGE_LEVEL + 2.5, 3.7), Vector3(8, BRIDGE_LEVEL + 2.5, 3.7),
							Vector3(-8, BRIDGE_LEVEL + 2.5, -3.7), Vector3(8, BRIDGE_LEVEL + 2.5, -3.7)]

	for i in range(torch_positions.size()):
		var torch := OmniLight3D.new()
		torch.name = "BridgeTorch_%d" % i
		torch.light_color = Color(1.0, 0.7, 0.4)
		torch.light_energy = 1.5
		torch.omni_range = 8.0
		torch.position = torch_positions[i]
		bridge_root.add_child(torch)


## Create rickety rope/wood bridges connecting cliff buildings
func _create_rickety_bridges() -> void:
	var wood_tex: Texture2D = load("res://Sprite folders grab bag/woodenfloor.png")

	# Rickety bridge material - worn wood
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.4, 0.32, 0.22)
	wood_mat.roughness = 0.9
	if wood_tex:
		wood_mat.albedo_texture = wood_tex
		wood_mat.uv1_scale = Vector3(4, 2, 1)
		wood_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Rope material
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = Color(0.35, 0.28, 0.2)
	rope_mat.roughness = 0.95

	# Bridge 1: West middle to East middle (smaller crossing north of main bridge)
	_create_rope_bridge(
		Vector3(-5, MIDDLE_LEVEL, 18),
		Vector3(5, MIDDLE_LEVEL, 18),
		"RopeBridge_North",
		wood_mat,
		rope_mat
	)

	# Bridge 2: West middle to East middle (smaller crossing south of main bridge)
	_create_rope_bridge(
		Vector3(-5, MIDDLE_LEVEL, -18),
		Vector3(5, MIDDLE_LEVEL, -18),
		"RopeBridge_South",
		wood_mat,
		rope_mat
	)

	# Bridge 3: Connecting West upper to a platform (for inn access)
	_create_rope_bridge(
		Vector3(-7, UPPER_LEVEL, -8),
		Vector3(-3, BRIDGE_LEVEL + 2, -8),
		"RopeBridge_WestUpper",
		wood_mat,
		rope_mat
	)


## Create a single rickety rope bridge
func _create_rope_bridge(start_pos: Vector3, end_pos: Vector3, bridge_name: String, wood_mat: Material, rope_mat: Material) -> void:
	var bridge_root := Node3D.new()
	bridge_root.name = bridge_name
	add_child(bridge_root)

	var direction := end_pos - start_pos
	var length := direction.length()
	var center := (start_pos + end_pos) / 2.0

	# Bridge planks (the walkway)
	var planks := CSGBox3D.new()
	planks.name = "Planks"
	planks.size = Vector3(length, 0.15, 2.0)
	planks.position = center
	planks.material = wood_mat
	planks.use_collision = true

	# Rotate to face the correct direction
	var angle := atan2(direction.x, direction.z)
	planks.rotation.y = angle + PI / 2

	# Slight sag in the middle for rickety effect
	planks.rotation.x = 0.02
	bridge_root.add_child(planks)

	# Rope railings (just thin boxes)
	var rope_offset := 0.9

	var left_rope := CSGBox3D.new()
	left_rope.name = "LeftRope"
	left_rope.size = Vector3(length, 0.08, 0.08)
	left_rope.position = center + Vector3(0, 0.8, rope_offset).rotated(Vector3.UP, angle + PI / 2)
	left_rope.rotation.y = angle + PI / 2
	left_rope.material = rope_mat
	left_rope.use_collision = false
	bridge_root.add_child(left_rope)

	var right_rope := CSGBox3D.new()
	right_rope.name = "RightRope"
	right_rope.size = Vector3(length, 0.08, 0.08)
	right_rope.position = center + Vector3(0, 0.8, -rope_offset).rotated(Vector3.UP, angle + PI / 2)
	right_rope.rotation.y = angle + PI / 2
	right_rope.material = rope_mat
	right_rope.use_collision = false
	bridge_root.add_child(right_rope)


## Create buildings built into the west cliff face
func _create_west_cliff_buildings() -> void:
	var stone_wall_tex: Texture2D = load("res://Sprite folders grab bag/stonewall.png")
	var wood_tex: Texture2D = load("res://Sprite folders grab bag/woodenfloor.png")

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.5, 0.45, 0.4)
	stone_mat.roughness = 0.9
	if stone_wall_tex:
		stone_mat.albedo_texture = stone_wall_tex
		stone_mat.uv1_scale = Vector3(2, 2, 1)
		stone_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.4, 0.32, 0.24)
	wood_mat.roughness = 0.85
	if wood_tex:
		wood_mat.albedo_texture = wood_tex
		wood_mat.uv1_scale = Vector3(3, 3, 1)
		wood_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# General Store (lower level)
	_create_cliff_building(
		Vector3(-10, LOWER_LEVEL, -8),
		"General_Store",
		stone_mat,
		wood_mat,
		Vector3(7, 4, 6)
	)

	# Blacksmith (lower level)
	_create_cliff_building(
		Vector3(-10, LOWER_LEVEL, 8),
		"Blacksmith",
		stone_mat,
		wood_mat,
		Vector3(8, 4, 7)
	)

	# Miner's Guild (middle level)
	_create_cliff_building(
		Vector3(-11, MIDDLE_LEVEL, -12),
		"Miners_Guild",
		stone_mat,
		wood_mat,
		Vector3(6, 5, 8)
	)

	# Spawn merchants
	Merchant.spawn_merchant(
		self,
		Vector3(-6, LOWER_LEVEL, -8),
		"Drake's General Goods",
		LootTables.LootTier.UNCOMMON,
		"general"
	)

	Merchant.spawn_merchant(
		self,
		Vector3(-6, LOWER_LEVEL, 8),
		"Canyon Forge",
		LootTables.LootTier.UNCOMMON,
		"blacksmith"
	)


## Create buildings built into the east cliff face
func _create_east_cliff_buildings() -> void:
	var stone_wall_tex: Texture2D = load("res://Sprite folders grab bag/stonewall.png")
	var wood_tex: Texture2D = load("res://Sprite folders grab bag/woodenfloor.png")

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.5, 0.45, 0.4)
	stone_mat.roughness = 0.9
	if stone_wall_tex:
		stone_mat.albedo_texture = stone_wall_tex
		stone_mat.uv1_scale = Vector3(2, 2, 1)
		stone_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.4, 0.32, 0.24)
	wood_mat.roughness = 0.85
	if wood_tex:
		wood_mat.albedo_texture = wood_tex
		wood_mat.uv1_scale = Vector3(3, 3, 1)
		wood_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Alchemist (lower level)
	_create_cliff_building(
		Vector3(10, LOWER_LEVEL, 10),
		"Alchemist",
		stone_mat,
		wood_mat,
		Vector3(6, 4, 6)
	)

	# Abandoned Mine Office (middle level) - cult meeting spot hint
	_create_cliff_building(
		Vector3(11, MIDDLE_LEVEL, -10),
		"Old_Mine_Office",
		stone_mat,
		wood_mat,
		Vector3(7, 5, 7),
		true  # Abandoned/suspicious
	)

	# Prospector's Supplies (middle level)
	_create_cliff_building(
		Vector3(11, MIDDLE_LEVEL, 12),
		"Prospector_Supplies",
		stone_mat,
		wood_mat,
		Vector3(6, 4, 6)
	)

	# Spawn merchants
	Merchant.spawn_merchant(
		self,
		Vector3(6, LOWER_LEVEL, 10),
		"Cliff's Edge Alchemy",
		LootTables.LootTier.UNCOMMON,
		"alchemist"
	)


## Create a building built into the cliff face
func _create_cliff_building(pos: Vector3, building_name: String, wall_mat: Material, roof_mat: Material, size: Vector3, is_suspicious: bool = false) -> void:
	var building_root := Node3D.new()
	building_root.name = building_name
	building_root.position = pos
	add_child(building_root)

	var width := size.x
	var height := size.y
	var depth := size.z
	var wall_thickness := 0.4

	# Floor
	var floor_mesh := CSGBox3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.size = Vector3(width, 0.2, depth)
	floor_mesh.position = Vector3(0, 0.1, 0)
	floor_mesh.material = roof_mat
	floor_mesh.use_collision = true
	building_root.add_child(floor_mesh)

	# Front wall (facing canyon) with doorway
	var doorway_width := 2.0
	var post_width := (depth - doorway_width) / 2.0

	var front_left := CSGBox3D.new()
	front_left.name = "FrontLeft"
	front_left.size = Vector3(wall_thickness, height, post_width)
	front_left.position = Vector3(width / 2.0 - wall_thickness / 2.0, height / 2.0, -depth / 2.0 + post_width / 2.0)
	front_left.material = wall_mat
	front_left.use_collision = true
	building_root.add_child(front_left)

	var front_right := CSGBox3D.new()
	front_right.name = "FrontRight"
	front_right.size = Vector3(wall_thickness, height, post_width)
	front_right.position = Vector3(width / 2.0 - wall_thickness / 2.0, height / 2.0, depth / 2.0 - post_width / 2.0)
	front_right.material = wall_mat
	front_right.use_collision = true
	building_root.add_child(front_right)

	# Side walls
	var left_wall := CSGBox3D.new()
	left_wall.name = "LeftWall"
	left_wall.size = Vector3(width - wall_thickness, height, wall_thickness)
	left_wall.position = Vector3(-wall_thickness / 2.0, height / 2.0, -depth / 2.0 + wall_thickness / 2.0)
	left_wall.material = wall_mat
	left_wall.use_collision = true
	building_root.add_child(left_wall)

	var right_wall := CSGBox3D.new()
	right_wall.name = "RightWall"
	right_wall.size = Vector3(width - wall_thickness, height, wall_thickness)
	right_wall.position = Vector3(-wall_thickness / 2.0, height / 2.0, depth / 2.0 - wall_thickness / 2.0)
	right_wall.material = wall_mat
	right_wall.use_collision = true
	building_root.add_child(right_wall)

	# Roof/awning
	var roof := CSGBox3D.new()
	roof.name = "Roof"
	roof.size = Vector3(width + 0.5, 0.4, depth + 0.5)
	roof.position = Vector3(0, height + 0.2, 0)
	roof.material = roof_mat
	roof.use_collision = true
	building_root.add_child(roof)

	# Interior light
	var light := OmniLight3D.new()
	light.name = "InteriorLight"
	if is_suspicious:
		light.light_color = Color(0.8, 0.4, 0.4)  # Reddish for suspicious buildings
		light.light_energy = 0.8
	else:
		light.light_color = Color(1.0, 0.85, 0.6)
		light.light_energy = 1.2
	light.omni_range = 6.0
	light.position = Vector3(0, height - 1.0, 0)
	building_root.add_child(light)


## Spawn the tavern (where drunk dwarves are)
func _spawn_tavern() -> void:
	var tavern_pos := Vector3(-10, LOWER_LEVEL, 20)

	var tavern_root := Node3D.new()
	tavern_root.name = "TheDrunkProspector"
	add_child(tavern_root)

	var stone_wall_tex: Texture2D = load("res://Sprite folders grab bag/stonewall.png")
	var wood_floor_tex: Texture2D = load("res://Sprite folders grab bag/woodenfloor.png")

	# Materials
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.48, 0.42, 0.35)
	wall_mat.roughness = 0.9
	if stone_wall_tex:
		wall_mat.albedo_texture = stone_wall_tex
		wall_mat.uv1_scale = Vector3(4, 2, 1)
		wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.45, 0.38, 0.3)
	floor_mat.roughness = 0.95
	if wood_floor_tex:
		floor_mat.albedo_texture = wood_floor_tex
		floor_mat.uv1_scale = Vector3(5, 5, 1)
		floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.35, 0.28, 0.2)
	roof_mat.roughness = 0.85

	var width := 14.0
	var depth := 12.0
	var height := 5.0
	var wall_thickness := 0.5

	# Floor
	var floor_mesh := CSGBox3D.new()
	floor_mesh.name = "TavernFloor"
	floor_mesh.size = Vector3(width, 0.3, depth)
	floor_mesh.position = tavern_pos + Vector3(0, 0.15, 0)
	floor_mesh.material = floor_mat
	floor_mesh.use_collision = true
	tavern_root.add_child(floor_mesh)

	# Back wall (into cliff)
	var back_wall := CSGBox3D.new()
	back_wall.name = "BackWall"
	back_wall.size = Vector3(wall_thickness, height, depth)
	back_wall.position = tavern_pos + Vector3(-width / 2.0 + wall_thickness / 2.0, height / 2.0, 0)
	back_wall.material = wall_mat
	back_wall.use_collision = true
	tavern_root.add_child(back_wall)

	# Side walls
	var left_wall := CSGBox3D.new()
	left_wall.name = "LeftWall"
	left_wall.size = Vector3(width - wall_thickness, height, wall_thickness)
	left_wall.position = tavern_pos + Vector3(wall_thickness / 2.0, height / 2.0, -depth / 2.0 + wall_thickness / 2.0)
	left_wall.material = wall_mat
	left_wall.use_collision = true
	tavern_root.add_child(left_wall)

	var right_wall := CSGBox3D.new()
	right_wall.name = "RightWall"
	right_wall.size = Vector3(width - wall_thickness, height, wall_thickness)
	right_wall.position = tavern_pos + Vector3(wall_thickness / 2.0, height / 2.0, depth / 2.0 - wall_thickness / 2.0)
	right_wall.material = wall_mat
	right_wall.use_collision = true
	tavern_root.add_child(right_wall)

	# Front wall with large doorway
	var doorway_width := 3.5
	var door_height := 3.5
	var front_section := (depth - doorway_width) / 2.0

	# Front left section
	var front_left := CSGBox3D.new()
	front_left.name = "FrontLeft"
	front_left.size = Vector3(wall_thickness, height, front_section)
	front_left.position = tavern_pos + Vector3(width / 2.0 - wall_thickness / 2.0, height / 2.0, -depth / 2.0 + front_section / 2.0)
	front_left.material = wall_mat
	front_left.use_collision = true
	tavern_root.add_child(front_left)

	# Front right section
	var front_right := CSGBox3D.new()
	front_right.name = "FrontRight"
	front_right.size = Vector3(wall_thickness, height, front_section)
	front_right.position = tavern_pos + Vector3(width / 2.0 - wall_thickness / 2.0, height / 2.0, depth / 2.0 - front_section / 2.0)
	front_right.material = wall_mat
	front_right.use_collision = true
	tavern_root.add_child(front_right)

	# Above door section
	var front_above := CSGBox3D.new()
	front_above.name = "FrontAbove"
	front_above.size = Vector3(wall_thickness, height - door_height, doorway_width)
	front_above.position = tavern_pos + Vector3(width / 2.0 - wall_thickness / 2.0, height - (height - door_height) / 2.0, 0)
	front_above.material = wall_mat
	front_above.use_collision = true
	tavern_root.add_child(front_above)

	# Roof
	var roof := CSGBox3D.new()
	roof.name = "Roof"
	roof.size = Vector3(width + 1, 0.5, depth + 1)
	roof.position = tavern_pos + Vector3(0, height + 0.25, 0)
	roof.material = roof_mat
	roof.use_collision = true
	tavern_root.add_child(roof)

	# Tavern sign
	var sign_mat := StandardMaterial3D.new()
	sign_mat.albedo_color = Color(0.55, 0.4, 0.25)
	sign_mat.roughness = 0.7

	var sign_board := CSGBox3D.new()
	sign_board.name = "TavernSign"
	sign_board.size = Vector3(0.2, 1.5, 3.5)
	sign_board.position = tavern_pos + Vector3(width / 2.0 + 0.5, height - 0.5, 0)
	sign_board.material = sign_mat
	sign_board.use_collision = false
	tavern_root.add_child(sign_board)

	# Warm tavern lighting
	var tavern_light := OmniLight3D.new()
	tavern_light.name = "TavernLight"
	tavern_light.light_color = Color(1.0, 0.75, 0.45)
	tavern_light.light_energy = 2.5
	tavern_light.omni_range = 12.0
	tavern_light.position = tavern_pos + Vector3(0, height - 1.5, 0)
	tavern_root.add_child(tavern_light)

	# Bounty board inside tavern
	BountyBoard.spawn_bounty_board(
		self,
		tavern_pos + Vector3(-5, 0, -4),
		"Drake's Bounty Board"
	)

	# Rest spot (tavern table)
	RestSpot.spawn_rest_spot(self, tavern_pos + Vector3(2, 0, 2), "Tavern Bench")

	# Tavern keeper
	Merchant.spawn_merchant(
		self,
		tavern_pos + Vector3(-3, 0, 0),
		"The Drunk Prospector Bar",
		LootTables.LootTier.COMMON,
		"general"
	)

	print("[Whaeler's Drake] Spawned The Drunk Prospector Tavern")


## Spawn the inn
func _spawn_inn() -> void:
	var inn_pos := Vector3(10, LOWER_LEVEL, -15)
	var door_pos := inn_pos + Vector3(-6, 0, 0)

	var inn_door := ZoneDoor.spawn_door(
		self,
		door_pos,
		"res://scenes/levels/inn_interior.tscn",
		"from_whaelers_drake",
		"Cliffside Rest Inn"
	)
	inn_door.rotation.y = PI / 2  # Face west toward canyon

	_create_inn_building(inn_pos)

	# Return spawn point
	var return_spawn := Node3D.new()
	return_spawn.name = "from_inn"
	return_spawn.position = door_pos + Vector3(-2, 0.1, 0)
	return_spawn.add_to_group("spawn_points")
	return_spawn.set_meta("spawn_id", "from_inn")
	add_child(return_spawn)

	print("[Whaeler's Drake] Spawned Cliffside Rest Inn")


## Create the inn building structure
func _create_inn_building(pos: Vector3) -> void:
	var inn_root := Node3D.new()
	inn_root.name = "InnBuilding"
	add_child(inn_root)

	var stone_wall_tex: Texture2D = load("res://Sprite folders grab bag/stonewall.png")
	var wood_floor_tex: Texture2D = load("res://Sprite folders grab bag/woodenfloor.png")

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.5, 0.44, 0.38)
	wall_mat.roughness = 0.9
	if stone_wall_tex:
		wall_mat.albedo_texture = stone_wall_tex
		wall_mat.uv1_scale = Vector3(3, 2, 1)
		wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.5, 0.42, 0.35)
	floor_mat.roughness = 0.95
	if wood_floor_tex:
		floor_mat.albedo_texture = wood_floor_tex
		floor_mat.uv1_scale = Vector3(4, 4, 1)
		floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.38, 0.3, 0.22)
	roof_mat.roughness = 0.85

	var width := 10.0
	var depth := 8.0
	var height := 5.0
	var wall_thickness := 0.5

	# Floor
	var floor_mesh := CSGBox3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.size = Vector3(width, 0.2, depth)
	floor_mesh.position = pos + Vector3(0, 0.1, 0)
	floor_mesh.material = floor_mat
	floor_mesh.use_collision = true
	inn_root.add_child(floor_mesh)

	# Back wall (into cliff)
	var back_wall := CSGBox3D.new()
	back_wall.name = "BackWall"
	back_wall.size = Vector3(wall_thickness, height, depth)
	back_wall.position = pos + Vector3(width / 2.0 - wall_thickness / 2.0, height / 2.0, 0)
	back_wall.material = wall_mat
	back_wall.use_collision = true
	inn_root.add_child(back_wall)

	# Side walls
	var front_wall := CSGBox3D.new()
	front_wall.name = "FrontWall"
	front_wall.size = Vector3(width - wall_thickness, height, wall_thickness)
	front_wall.position = pos + Vector3(-wall_thickness / 2.0, height / 2.0, -depth / 2.0 + wall_thickness / 2.0)
	front_wall.material = wall_mat
	front_wall.use_collision = true
	inn_root.add_child(front_wall)

	var back_side := CSGBox3D.new()
	back_side.name = "BackSide"
	back_side.size = Vector3(width - wall_thickness, height, wall_thickness)
	back_side.position = pos + Vector3(-wall_thickness / 2.0, height / 2.0, depth / 2.0 - wall_thickness / 2.0)
	back_side.material = wall_mat
	back_side.use_collision = true
	inn_root.add_child(back_side)

	# West wall with doorway
	var doorway_width := 2.5
	var door_height := 3.5
	var west_section := (depth - doorway_width) / 2.0

	var west_front := CSGBox3D.new()
	west_front.name = "WestFront"
	west_front.size = Vector3(wall_thickness, height, west_section)
	west_front.position = pos + Vector3(-width / 2.0 + wall_thickness / 2.0, height / 2.0, -depth / 2.0 + west_section / 2.0)
	west_front.material = wall_mat
	west_front.use_collision = true
	inn_root.add_child(west_front)

	var west_back := CSGBox3D.new()
	west_back.name = "WestBack"
	west_back.size = Vector3(wall_thickness, height, west_section)
	west_back.position = pos + Vector3(-width / 2.0 + wall_thickness / 2.0, height / 2.0, depth / 2.0 - west_section / 2.0)
	west_back.material = wall_mat
	west_back.use_collision = true
	inn_root.add_child(west_back)

	var west_above := CSGBox3D.new()
	west_above.name = "WestAbove"
	west_above.size = Vector3(wall_thickness, height - door_height, doorway_width)
	west_above.position = pos + Vector3(-width / 2.0 + wall_thickness / 2.0, height - (height - door_height) / 2.0, 0)
	west_above.material = wall_mat
	west_above.use_collision = true
	inn_root.add_child(west_above)

	# Roof
	var roof := CSGBox3D.new()
	roof.name = "Roof"
	roof.size = Vector3(width + 0.8, 0.5, depth + 0.8)
	roof.position = pos + Vector3(0, height + 0.25, 0)
	roof.material = roof_mat
	roof.use_collision = true
	inn_root.add_child(roof)

	# Inn light
	var inn_light := OmniLight3D.new()
	inn_light.name = "InnLight"
	inn_light.light_color = Color(1.0, 0.85, 0.6)
	inn_light.light_energy = 1.8
	inn_light.omni_range = 8.0
	inn_light.position = pos + Vector3(0, height - 1.0, 0)
	inn_root.add_child(inn_light)


## Spawn cult presence hints (symbols, suspicious NPCs)
func _spawn_cult_hints() -> void:
	# Cult symbol material - dark red/crimson
	var cult_mat := StandardMaterial3D.new()
	cult_mat.albedo_color = Color(0.5, 0.15, 0.15, 0.8)
	cult_mat.emission_enabled = true
	cult_mat.emission = Color(0.6, 0.1, 0.1)
	cult_mat.emission_energy_multiplier = 0.5
	cult_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Cult symbols painted on walls (subtle, need to look for them)
	var symbol_positions := [
		Vector3(11, MIDDLE_LEVEL + 2, -10),   # On old mine office
		Vector3(-9, LOWER_LEVEL + 2, 22),      # Near tavern (back alley)
		Vector3(14, UPPER_LEVEL + 1, -5),      # Hidden on upper east cliff
	]

	for i in range(symbol_positions.size()):
		var symbol := MeshInstance3D.new()
		symbol.name = "CultSymbol_%d" % i

		var quad := QuadMesh.new()
		quad.size = Vector2(0.8, 0.8)
		symbol.mesh = quad
		symbol.material_override = cult_mat
		symbol.position = symbol_positions[i]

		# Random rotation on wall
		symbol.rotation.y = randf_range(0, TAU)
		add_child(symbol)

	# Suspicious red glow from old mine office basement
	var cult_glow := OmniLight3D.new()
	cult_glow.name = "CultGlow"
	cult_glow.light_color = Color(0.8, 0.2, 0.1)
	cult_glow.light_energy = 0.6
	cult_glow.omni_range = 5.0
	cult_glow.position = Vector3(11, MIDDLE_LEVEL - 2, -10)
	add_child(cult_glow)

	# Mysterious candles in a hidden alcove
	var candle_positions := [
		Vector3(12, MIDDLE_LEVEL + 0.2, -12),
		Vector3(12.3, MIDDLE_LEVEL + 0.2, -11.7),
		Vector3(11.7, MIDDLE_LEVEL + 0.2, -11.5),
	]

	for i in range(candle_positions.size()):
		var candle_light := OmniLight3D.new()
		candle_light.name = "CultCandle_%d" % i
		candle_light.light_color = Color(1.0, 0.5, 0.2)
		candle_light.light_energy = 0.4
		candle_light.omni_range = 2.0
		candle_light.position = candle_positions[i]
		add_child(candle_light)

	print("[Whaeler's Drake] Spawned cult presence hints")


## Spawn NPCs (quest givers, civilians)
func _spawn_npcs() -> void:
	# Quest giver - worried miner looking for missing colleagues
	var worried_miner := QuestGiver.new()
	worried_miner.display_name = "Greta Ironpick"
	worried_miner.npc_id = "greta_ironpick"
	worried_miner.quest_ids = ["missing_prospectors"]
	worried_miner.position = Vector3(-6, MIDDLE_LEVEL, -12)

	worried_miner.quest_dialogues = {
		"missing_prospectors": {
			"offer": "You there! You look capable. I'm Greta Ironpick.\nThree of my fellow prospectors have gone missing.\nTwo were last seen at the tavern, drinking away their sorrows.\nBut Durgan... he was investigating strange noises\nfrom the old mine office. Please, find them!",
			"active": "Have you found any of them?\nCheck the tavern for the drunks, but Durgan...\nI fear something darker happened to him.",
			"complete": "Thank the stone! You found them!\nDurgan was captured? By whom?\nThis is troubling news... but thank you, friend."
		}
	}
	worried_miner.no_quest_dialogue = "The canyon winds blow cold today.\nStay safe on those bridges, traveler."
	add_child(worried_miner)

	# Suspicious cult recruiter - charismatic NPC
	var recruiter := QuestGiver.new()
	recruiter.display_name = "Brother Malachar"
	recruiter.npc_id = "brother_malachar"
	recruiter.quest_ids = []  # No quests, just suspicious dialogue
	recruiter.position = Vector3(6, LOWER_LEVEL, 5)

	recruiter.no_quest_dialogue = "Greetings, weary traveler. You seem... tired.\nThe canyon takes its toll on all who dwell here.\nBut there is peace to be found, if you know where to look.\nPerhaps we shall speak again... when you are ready."
	add_child(recruiter)

	print("[Whaeler's Drake] Spawned NPCs")


## Spawn fast travel shrine
func _spawn_fast_travel_shrine() -> void:
	# Place shrine on the main bridge, central and visible
	FastTravelShrine.spawn_shrine(
		self,
		Vector3(0, BRIDGE_LEVEL + 0.75, 0),
		"Drake's Crossing Shrine",
		"whaelers_drake_shrine"
	)
	print("[Whaeler's Drake] Spawned fast travel shrine")


## Spawn portal connections to other areas
func _spawn_portals() -> void:
	# Portal to Rotherhine (west exit)
	var rotherhine_portal := ZoneDoor.spawn_door(
		self,
		Vector3(-14, LOWER_LEVEL, -25),
		"res://scenes/levels/riverside_village.tscn",
		"from_whaelers_drake",
		"Road to Rotherhine"
	)
	rotherhine_portal.rotation.y = PI * 0.75
	rotherhine_portal.show_frame = false

	# Spawn point from Rotherhine
	var from_rotherhine := Node3D.new()
	from_rotherhine.name = "from_rotherhine"
	from_rotherhine.position = Vector3(-12, LOWER_LEVEL + 0.1, -22)
	from_rotherhine.add_to_group("spawn_points")
	from_rotherhine.set_meta("spawn_id", "from_rotherhine")
	add_child(from_rotherhine)

	rotherhine_portal.add_to_group("compass_poi")
	rotherhine_portal.set_meta("poi_id", "rotherhine_road")
	rotherhine_portal.set_meta("poi_name", "Rotherhine")
	rotherhine_portal.set_meta("poi_color", Color(0.3, 0.7, 0.3))

	# Portal to East Hollow (east exit)
	var east_hollow_portal := ZoneDoor.spawn_door(
		self,
		Vector3(14, LOWER_LEVEL, 25),
		"res://scenes/levels/east_hollow.tscn",
		"from_whaelers_drake",
		"Road to East Hollow"
	)
	east_hollow_portal.rotation.y = -PI * 0.25
	east_hollow_portal.show_frame = false

	# Spawn point from East Hollow
	var from_east_hollow := Node3D.new()
	from_east_hollow.name = "from_east_hollow"
	from_east_hollow.position = Vector3(12, LOWER_LEVEL + 0.1, 22)
	from_east_hollow.add_to_group("spawn_points")
	from_east_hollow.set_meta("spawn_id", "from_east_hollow")
	add_child(from_east_hollow)

	east_hollow_portal.add_to_group("compass_poi")
	east_hollow_portal.set_meta("poi_id", "east_hollow_road")
	east_hollow_portal.set_meta("poi_name", "East Hollow")
	east_hollow_portal.set_meta("poi_color", Color(0.5, 0.5, 0.7))

	# Portal to Pola Perron (north - up the mountain)
	var pola_perron_portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, UPPER_LEVEL, -22),
		"res://scenes/levels/pola_perron.tscn",
		"from_whaelers_drake",
		"Mountain Trail to Pola Perron"
	)
	pola_perron_portal.rotation.y = 0
	pola_perron_portal.show_frame = false

	# Spawn point from Pola Perron
	var from_pola_perron := Node3D.new()
	from_pola_perron.name = "from_pola_perron"
	from_pola_perron.position = Vector3(0, UPPER_LEVEL + 0.1, -18)
	from_pola_perron.add_to_group("spawn_points")
	from_pola_perron.set_meta("spawn_id", "from_pola_perron")
	add_child(from_pola_perron)

	pola_perron_portal.add_to_group("compass_poi")
	pola_perron_portal.set_meta("poi_id", "pola_perron_road")
	pola_perron_portal.set_meta("poi_name", "Pola Perron")
	pola_perron_portal.set_meta("poi_color", Color(0.5, 0.6, 0.5))

	# Hidden entrance to Vampire Crypt (northeast, in the mountain cliffs)
	# This is a hidden dungeon - no compass POI, harder to find
	var crypt_portal := ZoneDoor.spawn_door(
		self,
		Vector3(14, UPPER_LEVEL, -20),
		"res://scenes/levels/vampire_crypt.tscn",
		"from_whaelers_drake",
		"Dark Cave Entrance"
	)
	crypt_portal.rotation.y = PI * 0.25
	crypt_portal.show_frame = false

	# Spawn point returning from crypt
	var from_crypt := Node3D.new()
	from_crypt.name = "from_vampire_crypt"
	from_crypt.position = Vector3(12, UPPER_LEVEL + 0.1, -18)
	from_crypt.add_to_group("spawn_points")
	from_crypt.set_meta("spawn_id", "from_vampire_crypt")
	add_child(from_crypt)
	# NOTE: No compass_poi added - this is a hidden dungeon

	# Default spawn point (for fast travel)
	var default_spawn := Node3D.new()
	default_spawn.name = "default"
	default_spawn.position = Vector3(0, BRIDGE_LEVEL + 0.75 + 0.1, 5)
	default_spawn.add_to_group("spawn_points")
	default_spawn.set_meta("spawn_id", "default")
	add_child(default_spawn)

	print("[Whaeler's Drake] Spawned portal connections")


## Setup navigation mesh for NPCs
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
		print("[Whaeler's Drake] Navigation mesh baked!")
