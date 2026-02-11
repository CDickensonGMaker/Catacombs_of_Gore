## town_generator.gd - Procedural town/city generator
## Generates settlements based on location type, biome, and population tier
## Similar to wilderness_room.gd but for inhabited areas
class_name TownGenerator
extends Node3D

signal town_generated(town: TownGenerator)

## Town configuration from WorldData
var location_type: WorldData.LocationType = WorldData.LocationType.VILLAGE
var biome: WorldData.Biome = WorldData.Biome.FOREST
var location_id: String = ""
var location_name: String = ""
var region_name: String = ""
var grid_coords: Vector2i = Vector2i.ZERO

## Generation seed (consistent per character)
var town_seed: int = 0

## Get town size based on location type
static func get_town_size(loc_type: int) -> float:
	match loc_type:
		WorldData.LocationType.VILLAGE: return 60.0
		WorldData.LocationType.TOWN: return 80.0
		WorldData.LocationType.CITY: return 100.0
		WorldData.LocationType.CAPITAL: return 120.0
		_: return 60.0


## Get building counts by location type
static func get_building_counts(loc_type: int) -> Dictionary:
	match loc_type:
		WorldData.LocationType.VILLAGE: return {"houses": 3, "shops": 1, "special": 0}
		WorldData.LocationType.TOWN: return {"houses": 5, "shops": 3, "special": 1}
		WorldData.LocationType.CITY: return {"houses": 8, "shops": 5, "special": 2}
		WorldData.LocationType.CAPITAL: return {"houses": 12, "shops": 8, "special": 4}
		_: return {"houses": 3, "shops": 1, "special": 0}


## Get NPC counts by location type
static func get_npc_counts(loc_type: int) -> Dictionary:
	match loc_type:
		WorldData.LocationType.VILLAGE: return {"civilians": 5, "guards": 1}
		WorldData.LocationType.TOWN: return {"civilians": 10, "guards": 3}
		WorldData.LocationType.CITY: return {"civilians": 15, "guards": 6}
		WorldData.LocationType.CAPITAL: return {"civilians": 25, "guards": 10}
		_: return {"civilians": 5, "guards": 1}


## Get shop types available by location type
static func get_shop_types(loc_type: int) -> Array[String]:
	match loc_type:
		WorldData.LocationType.VILLAGE: return ["general_store", "inn"]
		WorldData.LocationType.TOWN: return ["general_store", "inn", "blacksmith", "temple"]
		WorldData.LocationType.CITY: return ["general_store", "inn", "blacksmith", "temple", "magic_shop", "armorer"]
		WorldData.LocationType.CAPITAL: return ["general_store", "inn", "blacksmith", "temple", "magic_shop", "armorer", "jeweler", "guild_hall"]
		_: return ["general_store", "inn"]

## Generated content
var buildings: Array[Node3D] = []
var npcs: Array[Node3D] = []
var props: Array[Node3D] = []
var spawn_points: Array[Node3D] = []

## RNG for consistent generation
var rng: RandomNumberGenerator

## Town bounds
var town_size: float = 60.0
var half_size: float = 30.0

## Preloaded resources
var house_texture: Texture2D
var stone_texture: Texture2D
var wood_texture: Texture2D


func _ready() -> void:
	add_to_group("town")
	add_to_group("level")


## Generate town from WorldData cell
func generate_from_cell(cell: WorldData.CellData, coords: Vector2i, seed_value: int) -> void:
	location_type = cell.location_type
	biome = cell.biome
	location_id = cell.location_id
	location_name = cell.location_name
	region_name = cell.region_name
	grid_coords = coords
	town_seed = seed_value

	generate()


## Generate the town
func generate() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = town_seed

	# Set town size based on type
	town_size = get_town_size(location_type)
	half_size = town_size / 2.0

	print("[TownGenerator] Generating %s '%s' at %s (seed: %d)" % [
		WorldData.LocationType.keys()[location_type],
		location_name,
		grid_coords,
		town_seed
	])

	_load_textures()
	_create_ground()
	_create_sky_environment()
	_create_walls()
	_create_town_center()
	_create_buildings()
	_create_exits()
	_spawn_npcs()
	_spawn_props()
	_create_spawn_points()

	town_generated.emit(self)
	print("[TownGenerator] Town generation complete: %d buildings, %d NPCs" % [buildings.size(), npcs.size()])


func _load_textures() -> void:
	house_texture = load("res://Sprite folders grab bag/house textures.png")
	stone_texture = load("res://Sprite folders grab bag/stonewall.png")
	wood_texture = load("res://Sprite folders grab bag/wood wall.png")


func _create_ground() -> void:
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(town_size + 20, 1.0, town_size + 20)
	ground.position = Vector3(0, -0.5, 0)
	ground.use_collision = true

	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9

	# Ground color/texture based on biome
	match biome:
		WorldData.Biome.COAST:
			mat.albedo_color = Color(0.6, 0.55, 0.4)  # Sandy
		WorldData.Biome.ROCKY, WorldData.Biome.MOUNTAINS:
			mat.albedo_color = Color(0.4, 0.38, 0.35)  # Stone
			if stone_texture:
				mat.albedo_texture = stone_texture
				mat.uv1_scale = Vector3(town_size / 8.0, town_size / 8.0, 1.0)
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		WorldData.Biome.SWAMP:
			mat.albedo_color = Color(0.25, 0.3, 0.2)  # Muddy
		_:
			mat.albedo_color = Color(0.35, 0.3, 0.25)  # Dirt/cobble

	ground.material = mat
	add_child(ground)


func _create_sky_environment() -> void:
	# Use BackgroundManager for static background image
	if BackgroundManager:
		BackgroundManager.set_background_for_world_biome(biome)
		BackgroundManager.show_background()
		print("[TownGenerator] Set background for biome: %s" % WorldData.Biome.keys()[biome])

	# Create WorldEnvironment for lighting/fog only (no procedural sky)
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.4, 0.5, 0.6)  # Fallback color (won't be visible behind CanvasLayer)

	# Ambient light
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.7)
	env.ambient_light_energy = 0.5

	world_env.environment = env
	add_child(world_env)

	# Directional light (sun)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)


func _create_walls() -> void:
	# Create simple wall segments around town perimeter
	var wall_height := 4.0
	var wall_thickness := 1.0
	var gap_size := 8.0  # Size of entrance gaps

	# Wall material
	var wall_mat := StandardMaterial3D.new()
	wall_mat.roughness = 0.85
	if stone_texture:
		wall_mat.albedo_texture = stone_texture
		wall_mat.uv1_scale = Vector3(0.25, 0.25, 1.0)
		wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	else:
		wall_mat.albedo_color = Color(0.4, 0.38, 0.35)

	# Create walls with gaps for exits
	var wall_positions := [
		{"pos": Vector3(0, wall_height/2, -half_size), "size": Vector3(town_size - gap_size, wall_height, wall_thickness), "dir": "north"},
		{"pos": Vector3(0, wall_height/2, half_size), "size": Vector3(town_size - gap_size, wall_height, wall_thickness), "dir": "south"},
		{"pos": Vector3(-half_size, wall_height/2, 0), "size": Vector3(wall_thickness, wall_height, town_size - gap_size), "dir": "west"},
		{"pos": Vector3(half_size, wall_height/2, 0), "size": Vector3(wall_thickness, wall_height, town_size - gap_size), "dir": "east"},
	]

	for wall_data: Dictionary in wall_positions:
		var wall := CSGBox3D.new()
		wall.name = "Wall_" + wall_data.dir
		wall.size = wall_data.size
		wall.position = wall_data.pos
		wall.use_collision = true
		wall.material = wall_mat
		add_child(wall)


func _create_town_center() -> void:
	# Central plaza with fireplace/hearth
	var plaza_size := 12.0

	# Fireplace in center
	var fireplace := _create_fireplace()
	fireplace.position = Vector3(0, 0, 0)
	add_child(fireplace)

	# Fast travel shrine near center (if town or larger)
	if location_type in [WorldData.LocationType.TOWN, WorldData.LocationType.CITY, WorldData.LocationType.CAPITAL]:
		var shrine := _create_shrine()
		shrine.position = Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5))
		add_child(shrine)

	# Bounty board
	var bounty_board := _create_bounty_board()
	bounty_board.position = Vector3(6, 0, -3)
	add_child(bounty_board)


func _create_fireplace() -> Node3D:
	var fireplace := Node3D.new()
	fireplace.name = "TownHearth"
	fireplace.add_to_group("rest_spots")

	# Stone base
	var base := CSGCylinder3D.new()
	base.name = "Base"
	base.radius = 1.5
	base.height = 0.5
	base.position = Vector3(0, 0.25, 0)
	base.use_collision = true

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.35, 0.32, 0.3)
	base.material = stone_mat
	fireplace.add_child(base)

	# Fire visual (simple orange box for now)
	var fire := CSGBox3D.new()
	fire.name = "Fire"
	fire.size = Vector3(0.8, 1.2, 0.8)
	fire.position = Vector3(0, 1.0, 0)

	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.5, 0.1)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.4, 0.1)
	fire_mat.emission_energy_multiplier = 2.0
	fire.material = fire_mat
	fireplace.add_child(fire)

	# Light
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.position = Vector3(0, 1.5, 0)
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 1.5
	light.omni_range = 15.0
	fireplace.add_child(light)

	# Interaction area
	var area := Area3D.new()
	area.name = "InteractArea"
	area.add_to_group("interactables")
	area.set_meta("interaction_type", "rest")
	area.set_meta("rest_type", "tavern_fireplace")
	area.set_meta("display_name", "Town Hearth")

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	col.shape = sphere
	col.position = Vector3(0, 1, 0)
	area.add_child(col)
	fireplace.add_child(area)

	return fireplace


func _create_shrine() -> Node3D:
	var shrine := Node3D.new()
	shrine.name = "FastTravelShrine"
	shrine.add_to_group("fast_travel_shrines")

	# Stone pillar
	var pillar := CSGCylinder3D.new()
	pillar.name = "Pillar"
	pillar.radius = 0.5
	pillar.height = 3.0
	pillar.position = Vector3(0, 1.5, 0)
	pillar.use_collision = true

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.55, 0.6)
	pillar.material = mat
	shrine.add_child(pillar)

	# Glowing top
	var orb := CSGSphere3D.new()
	orb.name = "Orb"
	orb.radius = 0.4
	orb.position = Vector3(0, 3.2, 0)

	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.4, 0.7, 1.0)
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(0.3, 0.6, 1.0)
	orb_mat.emission_energy_multiplier = 1.5
	orb.material = orb_mat
	shrine.add_child(orb)

	# Interaction
	var area := Area3D.new()
	area.name = "InteractArea"
	area.add_to_group("interactables")
	area.set_meta("interaction_type", "fast_travel")
	area.set_meta("location_id", location_id)
	area.set_meta("display_name", "Travel Shrine")

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.5
	col.shape = sphere
	col.position = Vector3(0, 1.5, 0)
	area.add_child(col)
	shrine.add_child(area)

	return shrine


func _create_bounty_board() -> Node3D:
	var board := Node3D.new()
	board.name = "BountyBoard"

	# Wooden post
	var post := CSGBox3D.new()
	post.name = "Post"
	post.size = Vector3(0.2, 2.5, 0.2)
	post.position = Vector3(0, 1.25, 0)
	post.use_collision = true

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.4, 0.3, 0.2)
	post.material = wood_mat
	board.add_child(post)

	# Board
	var panel := CSGBox3D.new()
	panel.name = "Panel"
	panel.size = Vector3(1.5, 1.2, 0.1)
	panel.position = Vector3(0, 2.0, 0.15)
	panel.material = wood_mat
	board.add_child(panel)

	# Interaction
	var area := Area3D.new()
	area.name = "InteractArea"
	area.add_to_group("interactables")
	area.set_meta("interaction_type", "bounty_board")
	area.set_meta("display_name", "Bounty Board")

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 2)
	col.shape = box
	col.position = Vector3(0, 1.5, 0)
	area.add_child(col)
	board.add_child(area)

	return board


func _create_buildings() -> void:
	var counts: Dictionary = get_building_counts(location_type)
	var available_shops: Array[String] = get_shop_types(location_type)

	# Track placed building positions to avoid overlap
	var placed_positions: Array[Vector3] = []
	var min_distance := 12.0

	# Place shops first (more important)
	var shops_to_place: Array[String] = []
	for shop_type in available_shops:
		shops_to_place.append(shop_type)

	# Shuffle shops
	for i in range(shops_to_place.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var temp: String = shops_to_place[i]
		shops_to_place[i] = shops_to_place[j]
		shops_to_place[j] = temp

	# Limit to shop count
	var num_shops: int = mini(counts.shops, shops_to_place.size())
	for i in range(num_shops):
		var pos := _find_building_position(placed_positions, min_distance)
		if pos != Vector3.ZERO:
			var building := _create_shop_building(shops_to_place[i], pos)
			if building:
				buildings.append(building)
				placed_positions.append(pos)

	# Place houses
	for i in range(counts.houses):
		var pos := _find_building_position(placed_positions, min_distance)
		if pos != Vector3.ZERO:
			var building := _create_house(pos)
			if building:
				buildings.append(building)
				placed_positions.append(pos)


func _find_building_position(existing: Array[Vector3], min_dist: float) -> Vector3:
	var attempts := 0
	var max_attempts := 20

	while attempts < max_attempts:
		# Random position within town bounds, avoiding center plaza
		var x := rng.randf_range(-half_size + 8, half_size - 8)
		var z := rng.randf_range(-half_size + 8, half_size - 8)

		# Skip if too close to center (plaza area)
		if abs(x) < 10 and abs(z) < 10:
			attempts += 1
			continue

		var pos := Vector3(x, 0, z)
		var valid := true

		for other: Vector3 in existing:
			if pos.distance_to(other) < min_dist:
				valid = false
				break

		if valid:
			return pos

		attempts += 1

	return Vector3.ZERO


func _create_shop_building(shop_type: String, pos: Vector3) -> Node3D:
	var shop := Node3D.new()
	shop.name = shop_type.capitalize().replace("_", "")
	shop.position = pos
	shop.add_to_group("buildings")

	# Building size varies by type
	var building_size := Vector3(8, 4, 6)
	if shop_type == "inn":
		building_size = Vector3(10, 5, 8)
	elif shop_type == "temple":
		building_size = Vector3(8, 6, 10)
	elif shop_type == "guild_hall":
		building_size = Vector3(12, 5, 10)

	# Main structure
	var structure := CSGBox3D.new()
	structure.name = "Structure"
	structure.size = building_size
	structure.position = Vector3(0, building_size.y / 2, 0)
	structure.use_collision = true

	var mat := StandardMaterial3D.new()
	if house_texture:
		mat.albedo_texture = house_texture
		mat.uv1_scale = Vector3(0.25, 0.25, 1.0)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	else:
		mat.albedo_color = Color(0.6, 0.5, 0.4)
	structure.material = mat
	shop.add_child(structure)

	# Roof
	var roof := CSGBox3D.new()
	roof.name = "Roof"
	roof.size = Vector3(building_size.x + 1, 0.5, building_size.z + 1)
	roof.position = Vector3(0, building_size.y + 0.25, 0)

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.35, 0.25, 0.2)
	roof.material = roof_mat
	shop.add_child(roof)

	# Sign/label
	var sign_label := Label3D.new()
	sign_label.name = "Sign"
	sign_label.text = _get_shop_display_name(shop_type)
	sign_label.position = Vector3(0, building_size.y + 1.0, building_size.z / 2 + 0.1)
	sign_label.font_size = 48
	sign_label.modulate = Color(0.9, 0.85, 0.7)
	shop.add_child(sign_label)

	# Interaction area for shop
	var area := Area3D.new()
	area.name = "ShopArea"
	area.add_to_group("interactables")
	area.add_to_group("shops")
	area.set_meta("interaction_type", "shop")
	area.set_meta("shop_type", shop_type)
	area.set_meta("display_name", _get_shop_display_name(shop_type))

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(building_size.x + 4, 4, building_size.z + 4)
	col.shape = box
	col.position = Vector3(0, 2, 0)
	area.add_child(col)
	shop.add_child(area)

	add_child(shop)
	return shop


func _get_shop_display_name(shop_type: String) -> String:
	match shop_type:
		"general_store": return "General Store"
		"inn": return "The Traveler's Rest"
		"blacksmith": return "Blacksmith"
		"temple": return "Temple"
		"magic_shop": return "Arcane Emporium"
		"armorer": return "Armorer"
		"jeweler": return "Jeweler"
		"guild_hall": return "Adventurer's Guild"
		_: return shop_type.capitalize()


func _create_house(pos: Vector3) -> Node3D:
	var house := Node3D.new()
	house.name = "House_%d" % buildings.size()
	house.position = pos
	house.add_to_group("buildings")
	house.add_to_group("houses")

	# Random house size
	var w := rng.randf_range(5, 8)
	var h := rng.randf_range(3, 4.5)
	var d := rng.randf_range(5, 7)

	# Structure
	var structure := CSGBox3D.new()
	structure.name = "Structure"
	structure.size = Vector3(w, h, d)
	structure.position = Vector3(0, h / 2, 0)
	structure.use_collision = true

	var mat := StandardMaterial3D.new()
	if house_texture:
		mat.albedo_texture = house_texture
		mat.uv1_scale = Vector3(0.2, 0.2, 1.0)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	else:
		mat.albedo_color = Color(0.55, 0.45, 0.35)
	structure.material = mat
	house.add_child(structure)

	# Roof
	var roof := CSGBox3D.new()
	roof.name = "Roof"
	roof.size = Vector3(w + 0.8, 0.4, d + 0.8)
	roof.position = Vector3(0, h + 0.2, 0)

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.3 + rng.randf() * 0.1, 0.22, 0.18)
	roof.material = roof_mat
	house.add_child(roof)

	# Lockable door (for crime system)
	var lock_dc := rng.randi_range(8, 15)
	var door_area := Area3D.new()
	door_area.name = "DoorArea"
	door_area.add_to_group("interactables")
	door_area.add_to_group("lockable_doors")
	door_area.set_meta("interaction_type", "locked_door")
	door_area.set_meta("lock_dc", lock_dc)
	door_area.set_meta("display_name", "Locked Door (DC %d)" % lock_dc)
	door_area.set_meta("is_locked", true)

	var door_col := CollisionShape3D.new()
	var door_box := BoxShape3D.new()
	door_box.size = Vector3(2, 3, 2)
	door_col.shape = door_box
	door_col.position = Vector3(0, 1.5, d / 2 + 1)
	door_area.add_child(door_col)
	house.add_child(door_area)

	add_child(house)
	return house


func _create_exits() -> void:
	# Create zone edge triggers for each cardinal direction
	var exit_positions := {
		"north": Vector3(0, 0, -half_size - 2),
		"south": Vector3(0, 0, half_size + 2),
		"east": Vector3(half_size + 2, 0, 0),
		"west": Vector3(-half_size - 2, 0, 0),
	}

	for dir_name: String in exit_positions:
		var exit := Area3D.new()
		exit.name = "Exit_" + dir_name
		exit.position = exit_positions[dir_name]
		exit.add_to_group("zone_exits")

		var direction: int
		match dir_name:
			"north": direction = 0
			"south": direction = 1
			"east": direction = 2
			"west": direction = 3
			_: direction = 0

		exit.set_meta("exit_direction", direction)

		# Collision shape covering the gap
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		if dir_name in ["north", "south"]:
			box.size = Vector3(12, 4, 4)
		else:
			box.size = Vector3(4, 4, 12)
		col.shape = box
		col.position = Vector3(0, 2, 0)
		exit.add_child(col)

		exit.collision_layer = 0
		exit.collision_mask = 2  # Player layer
		exit.monitoring = true
		exit.body_entered.connect(_on_exit_entered.bind(direction))

		add_child(exit)


func _on_exit_entered(body: Node3D, direction: int) -> void:
	if not body.is_in_group("player"):
		return

	print("[TownGenerator] Player exiting town via direction %d" % direction)
	# Transition to wilderness
	if SceneManager:
		SceneManager.transition_to_adjacent_room(direction)


func _spawn_npcs() -> void:
	var counts: Dictionary = get_npc_counts(location_type)

	# Spawn civilians
	for i in range(counts.civilians):
		var pos := _get_random_npc_position()
		var civilian := _create_civilian_npc(pos)
		if civilian:
			npcs.append(civilian)

	# Spawn guards
	for i in range(counts.guards):
		var pos := _get_random_npc_position()
		var guard := _create_guard_npc(pos)
		if guard:
			npcs.append(guard)


func _get_random_npc_position() -> Vector3:
	var x := rng.randf_range(-half_size + 5, half_size - 5)
	var z := rng.randf_range(-half_size + 5, half_size - 5)
	return Vector3(x, 0, z)


func _create_civilian_npc(pos: Vector3) -> Node3D:
	# Try to use the CivilianNPC class if available
	var CivilianNPCClass = load("res://scripts/world/civilian_npc.gd")
	if CivilianNPCClass:
		var npc: Node3D = CivilianNPCClass.new()
		npc.position = pos
		add_child(npc)
		return npc

	# Fallback: simple placeholder using cylinder (capsule shape)
	var npc := Node3D.new()
	npc.name = "Civilian_%d" % npcs.size()
	npc.position = pos
	npc.add_to_group("npcs")

	var body: CSGCylinder3D = CSGCylinder3D.new()
	body.radius = 0.3
	body.height = 1.8
	body.position = Vector3(0, 0.9, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.5, 0.4)
	body.material = mat
	npc.add_child(body)

	add_child(npc)
	return npc


func _create_guard_npc(pos: Vector3) -> Node3D:
	# Use the GuardNPC class
	var GuardNPCClass = load("res://scripts/npcs/guard_npc.gd")
	if GuardNPCClass:
		var guard: Node3D = GuardNPCClass.spawn_guard(self, pos)
		return guard

	# Fallback: simple placeholder using cylinder
	var npc := Node3D.new()
	npc.name = "Guard_%d" % npcs.size()
	npc.position = pos
	npc.add_to_group("npcs")
	npc.add_to_group("guards")

	var body: CSGCylinder3D = CSGCylinder3D.new()
	body.radius = 0.35
	body.height = 2.0
	body.position = Vector3(0, 1.0, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.35, 0.5)  # Blue-ish armor
	body.material = mat
	npc.add_child(body)

	add_child(npc)
	return npc


func _spawn_props() -> void:
	# Add environmental props based on biome
	var prop_count := rng.randi_range(5, 15)

	for i in range(prop_count):
		var x := rng.randf_range(-half_size + 3, half_size - 3)
		var z := rng.randf_range(-half_size + 3, half_size - 3)

		# Skip center area
		if abs(x) < 8 and abs(z) < 8:
			continue

		var prop: Node3D
		var prop_type := rng.randi() % 4
		match prop_type:
			0: prop = _create_barrel(Vector3(x, 0, z))
			1: prop = _create_crate(Vector3(x, 0, z))
			2: prop = _create_torch(Vector3(x, 0, z))
			3: prop = _create_bench(Vector3(x, 0, z))

		if prop:
			props.append(prop)


func _create_barrel(pos: Vector3) -> Node3D:
	var barrel := CSGCylinder3D.new()
	barrel.name = "Barrel"
	barrel.radius = 0.4
	barrel.height = 1.0
	barrel.position = pos + Vector3(0, 0.5, 0)
	barrel.use_collision = true

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.3, 0.2)
	barrel.material = mat

	add_child(barrel)
	return barrel


func _create_crate(pos: Vector3) -> Node3D:
	var crate := CSGBox3D.new()
	crate.name = "Crate"
	crate.size = Vector3(0.8, 0.8, 0.8)
	crate.position = pos + Vector3(0, 0.4, 0)
	crate.use_collision = true

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.4, 0.25)
	crate.material = mat

	add_child(crate)
	return crate


func _create_torch(pos: Vector3) -> Node3D:
	var torch := Node3D.new()
	torch.name = "Torch"
	torch.position = pos

	var post := CSGCylinder3D.new()
	post.radius = 0.1
	post.height = 2.5
	post.position = Vector3(0, 1.25, 0)
	torch.add_child(post)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.6, 0)
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 1.0
	light.omni_range = 8.0
	torch.add_child(light)

	add_child(torch)
	return torch


func _create_bench(pos: Vector3) -> Node3D:
	var bench := CSGBox3D.new()
	bench.name = "Bench"
	bench.size = Vector3(2.0, 0.5, 0.6)
	bench.position = pos + Vector3(0, 0.25, 0)
	bench.use_collision = true

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.35, 0.25)
	bench.material = mat

	add_child(bench)
	return bench


func _create_spawn_points() -> void:
	# Create spawn points for each direction
	var spawn_data := [
		{"id": "from_north", "pos": Vector3(0, 0.5, -half_size + 5)},
		{"id": "from_south", "pos": Vector3(0, 0.5, half_size - 5)},
		{"id": "from_east", "pos": Vector3(half_size - 5, 0.5, 0)},
		{"id": "from_west", "pos": Vector3(-half_size + 5, 0.5, 0)},
		{"id": "default", "pos": Vector3(0, 0.5, 5)},
		{"id": "from_wilderness", "pos": Vector3(0, 0.5, 5)},
		{"id": "from_fast_travel", "pos": Vector3(0, 0.5, 0)},
	]

	for data: Dictionary in spawn_data:
		var spawn := Node3D.new()
		spawn.name = "SpawnPoint_" + data.id
		spawn.position = data.pos
		spawn.add_to_group("spawn_points")
		spawn.set_meta("spawn_id", data.id)
		add_child(spawn)
		spawn_points.append(spawn)

	# Mark default spawn
	if spawn_points.size() > 0:
		spawn_points[0].add_to_group("default_spawn")
