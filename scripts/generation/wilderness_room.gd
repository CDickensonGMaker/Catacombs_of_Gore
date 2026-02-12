## wilderness_room.gd - Procedural wilderness room generator
## Creates outdoor areas with ruins, dungeon entrances, and environmental props
## Each room is 100x100 units with full-wall edge triggers
class_name WildernessRoom
extends Node3D

## Zone ID for quest tracking - tells MapTracker the player is in wilderness
const ZONE_ID := "open_world"

signal room_generated(room: WildernessRoom)
signal edge_triggered(direction: RoomEdge.Direction)

## Seamless streaming mode - when true, edge triggers are disabled (WorldManager handles transitions)
var seamless_mode: bool = false

## Room configuration
@export var room_size: float = 100.0
@export var room_seed: int = 0  # 0 = random

## Biome types
enum Biome { FOREST, PLAINS, SWAMP, HILLS, ROCKY }
@export var biome: Biome = Biome.FOREST

## Content settings (from plan: 1-3 ruins, 0-1 dungeons at 30%)
@export var min_ruins: int = 1
@export var max_ruins: int = 3
@export var dungeon_chance: float = 0.3
@export var fireplace_chance: float = 0.15
@export var traveling_merchant_chance: float = 0.15  # 15% chance per room
@export var enemy_count_min: int = 2
@export var enemy_count_max: int = 5
@export var cursed_totem_chance: float = 0.25  # 25% chance for cursed totem near ruins

## 3D Terrain prop settings
@export var terrain_prop_chance: float = 0.4  # 40% chance to spawn 3D terrain props
@export var terrain_prop_count_min: int = 1
@export var terrain_prop_count_max: int = 3

## 3D terrain model paths by prop type
const TERRAIN_MODELS: Dictionary = {
	"hill": [
		"res://assets/models/terrain/low_hills.glb"
	],
	"rock": [],  # Add rock GLB models here
	"boulder": [],  # Add boulder GLB models here
	"cliff": [],  # Add cliff GLB models here
	"stump": [],  # Add stump GLB models here
	"log": []  # Add log GLB models here
}

## 3D statue model paths
const STATUE_MODELS: Array[String] = [
	"res://assets/models/statues/sword_statue.glb"
]

## Statue spawn settings
@export var statue_near_ruins_chance: float = 0.8  # 80% chance per ruin
@export var statue_standalone_chance: float = 0.5  # 50% chance for standalone statue
@export var statue_near_dungeon_chance: float = 0.9  # 90% chance near dungeon entrance

## Road visualization settings
@export var road_width: float = 8.0  # Width of dirt road
@export var road_prop_density_multiplier: float = 0.3  # Reduce props to 30% on roads

## Room grid coordinates (set by SceneManager)
var grid_coords: Vector2i = Vector2i.ZERO

## Direction player entered from (-1 = unknown, 0=N, 1=S, 2=E, 3=W)
## Used to prevent mountain barriers from blocking the return path
var entry_direction: int = -1

## Generated content references
var edges: Dictionary = {}  # Direction -> RoomEdge
var ruins: Array[Node3D] = []
var cursed_totems: Array[CursedTotem] = []  # Skeleton spawners near ruins
var dungeon_entrance: Node3D = null
var enemies: Array[Node3D] = []
var props: Array[Node3D] = []
var traveling_merchant: TravelingMerchant = null
var signposts: Array[Node3D] = []  # Direction signposts on road cells

## Whether this cell is a road cell
var is_road_cell: bool = false

## Player reference (used for various systems)
var player_ref: Node3D = null

## RNG for consistent generation
var rng: RandomNumberGenerator

## Materials
var ground_material: StandardMaterial3D
var rock_material: StandardMaterial3D
var ruin_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("wilderness_room")
	# Initialize zone tracking for quest markers
	if MapTracker:
		MapTracker.init_zone(ZONE_ID)


func _process(_delta: float) -> void:
	# Background is now handled by BackgroundManager autoload
	pass


## Reference to loaded hand-placed cell scene (if any)
var hand_placed_cell: Node3D = null


## Generate the room with given seed
func generate(seed_value: int = 0, coords: Vector2i = Vector2i.ZERO) -> void:
	grid_coords = coords
	room_seed = seed_value if seed_value != 0 else randi()

	rng = RandomNumberGenerator.new()
	rng.seed = room_seed

	# Check if this is a road cell
	is_road_cell = WorldData.is_road(coords)

	# Check for hand-placed cell scene
	var cell_scene_path: String = WorldData.get_cell_scene(coords)
	if not cell_scene_path.is_empty() and ResourceLoader.exists(cell_scene_path):
		print("[WildernessRoom] Loading hand-placed cell at %s: %s" % [coords, cell_scene_path])
		_load_hand_placed_cell(cell_scene_path)
		return

	print("[WildernessRoom] Generating procedural room at %s with seed %d, biome: %s, is_road: %s" % [
		coords, room_seed, Biome.keys()[biome], is_road_cell
	])

	_setup_materials()
	_create_ground()
	_create_road_if_needed()  # Add dirt road on road cells
	_create_sky_environment()
	_create_edges()
	_create_spawn_points()  # Directional spawn points for cell transitions
	_set_background_for_biome()  # Set static background via BackgroundManager
	_spawn_ruins()
	_spawn_cursed_totems()  # Skeleton spawners near ruins
	_spawn_dungeon_entrance()
	_spawn_statues()  # Decorative statues near ruins and dungeons
	_spawn_environment()
	_spawn_enemies()
	_spawn_fireplace()
	_spawn_traveling_merchant()
	_spawn_signposts_if_road()  # Add signposts pointing to destinations
	_create_boundary_props()

	room_generated.emit(self)


## Load and instantiate a hand-placed cell scene
func _load_hand_placed_cell(scene_path: String) -> void:
	var cell_scene: PackedScene = load(scene_path)
	if not cell_scene:
		push_error("[WildernessRoom] Failed to load hand-placed cell: %s" % scene_path)
		# Fall back to procedural generation
		_generate_procedural()
		return

	hand_placed_cell = cell_scene.instantiate()
	hand_placed_cell.name = "HandPlacedCell"
	add_child(hand_placed_cell)

	# Check if it's a WildernessTile with proper structure
	if hand_placed_cell is WildernessTile:
		var tile: WildernessTile = hand_placed_cell as WildernessTile
		tile.apply_biome_effects()
		print("[WildernessRoom] Loaded hand-placed tile: %s" % tile.get_tile_info())

		# Spawn enemies at designated points
		_spawn_enemies_at_tile_markers(tile)

	# Still need basic infrastructure (edges, spawn points, walls, environment)
	_setup_materials()
	_create_sky_environment()
	_create_edges()
	_create_spawn_points()
	_set_background_for_biome()
	_create_invisible_walls()

	room_generated.emit(self)


## Spawn enemies at hand-placed tile's enemy spawn markers
func _spawn_enemies_at_tile_markers(tile: WildernessTile) -> void:
	var spawn_points: Array[Node3D] = tile.get_enemy_spawn_points()
	if spawn_points.is_empty():
		return

	for spawn_point in spawn_points:
		# Get enemy config for this biome
		var enemy_config: Dictionary = _get_enemy_config_for_biome()

		var enemy: Node = null
		var pos: Vector3 = spawn_point.global_position

		# Check if this is a skeleton enemy
		if enemy_config.get("is_skeleton", false):
			enemy = EnemyBase.spawn_skeleton_enemy(
				self,
				pos,
				enemy_config.data_path
			)
		else:
			# Load sprite texture for regular enemies
			var sprite_tex: Texture2D = load(enemy_config.sprite_path)
			if not sprite_tex:
				push_warning("[WildernessRoom] Failed to load sprite: %s" % enemy_config.sprite_path)
				continue

			# Spawn regular billboard enemy
			enemy = EnemyBase.spawn_billboard_enemy(
				self,
				pos,
				enemy_config.data_path,
				sprite_tex,
				enemy_config.h_frames,
				enemy_config.v_frames
			)

		if enemy:
			enemies.append(enemy)
			print("[WildernessRoom] Spawned %s at marker %s" % [enemy_config.display_name, pos])


## Generate procedural room (extracted for fallback use)
func _generate_procedural() -> void:
	_setup_materials()
	_create_ground()
	_create_road_if_needed()
	_create_sky_environment()
	_create_edges()
	_create_spawn_points()
	_set_background_for_biome()
	_spawn_ruins()
	_spawn_cursed_totems()
	_spawn_dungeon_entrance()
	_spawn_statues()  # Decorative statues near ruins and dungeons
	_spawn_environment()
	_spawn_enemies()
	_spawn_fireplace()
	_spawn_traveling_merchant()
	_spawn_signposts_if_road()
	_create_boundary_props()

	room_generated.emit(self)


## Setup materials based on biome
func _setup_materials() -> void:
	ground_material = StandardMaterial3D.new()
	ground_material.roughness = 0.9

	rock_material = StandardMaterial3D.new()
	rock_material.roughness = 0.95

	# Ruin material uses stone wall texture
	ruin_material = StandardMaterial3D.new()
	ruin_material.roughness = 0.85
	var stone_tex: Texture2D = load("res://Sprite folders grab bag/stonewall.png")
	if stone_tex:
		ruin_material.albedo_texture = stone_tex
		ruin_material.uv1_scale = Vector3(0.5, 0.5, 1.0)  # Tile the texture
		ruin_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	match biome:
		Biome.FOREST:
			ground_material.albedo_color = Color(0.2, 0.35, 0.15)  # Green grass
			rock_material.albedo_color = Color(0.4, 0.38, 0.35)   # Gray rock
		Biome.PLAINS:
			ground_material.albedo_color = Color(0.45, 0.4, 0.25)  # Dry grass
			rock_material.albedo_color = Color(0.5, 0.45, 0.4)
		Biome.SWAMP:
			ground_material.albedo_color = Color(0.15, 0.2, 0.12)  # Dark murky
			rock_material.albedo_color = Color(0.25, 0.28, 0.22)   # Mossy
			# Tint ruins green for swamp
			ruin_material.albedo_color = Color(0.7, 0.8, 0.7)
		Biome.HILLS:
			ground_material.albedo_color = Color(0.35, 0.38, 0.25)  # Hilly grass
			rock_material.albedo_color = Color(0.45, 0.42, 0.38)
		Biome.ROCKY:
			ground_material.albedo_color = Color(0.3, 0.28, 0.25)  # Rocky ground
			rock_material.albedo_color = Color(0.35, 0.32, 0.3)


## Create ground plane with simple solid color (PS1 style - no complex textures)
func _create_ground() -> void:
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(room_size + 20, 1.0, room_size + 20)
	ground.position = Vector3(0, -0.5, 0)
	ground.use_collision = true

	# Simple solid color material - biome colors are set in _setup_materials()
	var simple_mat := StandardMaterial3D.new()
	simple_mat.roughness = 0.95
	simple_mat.albedo_color = ground_material.albedo_color

	ground.material = simple_mat
	add_child(ground)

	# Spawn environmental props on the ground
	_spawn_ground_props()

	# Spawn 3D terrain props (hills, rocks, etc.)
	_spawn_terrain_props()


## Create dirt road mesh if this is a road cell
func _create_road_if_needed() -> void:
	if not is_road_cell:
		return

	var road_container := Node3D.new()
	road_container.name = "DirtRoad"
	add_child(road_container)

	# Determine road direction based on neighboring road cells
	var north_road := WorldData.is_road(grid_coords + Vector2i(0, 1))
	var south_road := WorldData.is_road(grid_coords + Vector2i(0, -1))
	var east_road := WorldData.is_road(grid_coords + Vector2i(1, 0))
	var west_road := WorldData.is_road(grid_coords + Vector2i(-1, 0))

	# Create road segments based on connections
	var half_size: float = room_size / 2.0

	# Road material - dirt/packed earth color
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.45, 0.35, 0.25)  # Brown dirt color
	road_mat.roughness = 1.0
	road_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# North-South road segment
	if north_road or south_road:
		var ns_road := CSGBox3D.new()
		ns_road.name = "RoadNS"
		ns_road.size = Vector3(road_width, 0.05, room_size + 10)
		ns_road.position = Vector3(0, 0.02, 0)  # Slightly above ground
		ns_road.material = road_mat
		road_container.add_child(ns_road)

	# East-West road segment
	if east_road or west_road:
		var ew_road := CSGBox3D.new()
		ew_road.name = "RoadEW"
		ew_road.size = Vector3(room_size + 10, 0.05, road_width)
		ew_road.position = Vector3(0, 0.02, 0)
		ew_road.material = road_mat
		road_container.add_child(ew_road)

	# If this is a crossroads (both directions), add center intersection
	if (north_road or south_road) and (east_road or west_road):
		var center := CSGBox3D.new()
		center.name = "RoadCenter"
		center.size = Vector3(road_width + 2, 0.06, road_width + 2)
		center.position = Vector3(0, 0.03, 0)
		center.material = road_mat
		road_container.add_child(center)

	# If only one connection (dead end or start/end of road), create stub
	var connection_count: int = 0
	if north_road: connection_count += 1
	if south_road: connection_count += 1
	if east_road: connection_count += 1
	if west_road: connection_count += 1

	if connection_count == 0:
		# Road cell with no connections - create a small clearing/rest area
		var clearing := CSGCylinder3D.new()
		clearing.name = "RoadClearing"
		clearing.radius = road_width
		clearing.height = 0.05
		clearing.position = Vector3(0, 0.02, 0)
		clearing.material = road_mat
		road_container.add_child(clearing)
	elif connection_count == 1:
		# Single connection - extend road to center
		if north_road:
			var stub := CSGBox3D.new()
			stub.size = Vector3(road_width, 0.05, half_size)
			stub.position = Vector3(0, 0.02, -half_size / 2.0)
			stub.material = road_mat
			road_container.add_child(stub)
		elif south_road:
			var stub := CSGBox3D.new()
			stub.size = Vector3(road_width, 0.05, half_size)
			stub.position = Vector3(0, 0.02, half_size / 2.0)
			stub.material = road_mat
			road_container.add_child(stub)
		elif east_road:
			var stub := CSGBox3D.new()
			stub.size = Vector3(half_size, 0.05, road_width)
			stub.position = Vector3(half_size / 2.0, 0.02, 0)
			stub.material = road_mat
			road_container.add_child(stub)
		elif west_road:
			var stub := CSGBox3D.new()
			stub.size = Vector3(half_size, 0.05, road_width)
			stub.position = Vector3(-half_size / 2.0, 0.02, 0)
			stub.material = road_mat
			road_container.add_child(stub)

	print("[WildernessRoom] Created dirt road (N:%s S:%s E:%s W:%s)" % [
		north_road, south_road, east_road, west_road
	])


## Spawn environmental props (trees, grass, gravestones) based on biome
func _spawn_ground_props() -> void:
	var props_container := Node3D.new()
	props_container.name = "GroundProps"
	add_child(props_container)

	var half_size: float = room_size / 2.0 - 5.0  # Keep away from edges
	var num_grass: int = rng.randi_range(15, 30)
	var num_trees: int = rng.randi_range(8, 15)
	var num_special: int = rng.randi_range(3, 8)  # Gravestones, fallen trees, etc.

	# Grass clumps
	for i in range(num_grass):
		var pos := Vector3(
			rng.randf_range(-half_size, half_size),
			0.0,
			rng.randf_range(-half_size, half_size)
		)
		_spawn_grass_prop(props_container, pos)

	# Trees
	for i in range(num_trees):
		var pos := Vector3(
			rng.randf_range(-half_size, half_size),
			0.0,
			rng.randf_range(-half_size, half_size)
		)
		_spawn_tree_prop(props_container, pos)

	# Special props based on biome
	for i in range(num_special):
		var pos := Vector3(
			rng.randf_range(-half_size, half_size),
			0.0,
			rng.randf_range(-half_size, half_size)
		)
		_spawn_special_prop(props_container, pos)


## Spawn a grass clump billboard
func _spawn_grass_prop(parent: Node3D, pos: Vector3) -> void:
	var grass_textures: Array[String] = [
		"res://Sprite folders grab bag/grassland_1.png",
		"res://Sprite folders grab bag/grassland_2.png",
		"res://Sprite folders grab bag/grassland_3.png"
	]

	var tex_path: String = grass_textures[rng.randi() % grass_textures.size()]
	if not ResourceLoader.exists(tex_path):
		return

	var grass := Sprite3D.new()
	grass.name = "Grass"
	grass.texture = load(tex_path)
	grass.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	grass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	grass.pixel_size = rng.randf_range(0.015, 0.025)
	grass.position = pos + Vector3(0, grass.texture.get_height() * grass.pixel_size * 0.5, 0)
	grass.modulate = _get_biome_prop_tint()
	parent.add_child(grass)


## Spawn a tree billboard based on biome
func _spawn_tree_prop(parent: Node3D, pos: Vector3) -> void:
	var tree_textures: Array[String] = []

	match biome:
		Biome.SWAMP:
			tree_textures = [
				"res://Sprite folders grab bag/swamp_tree1.png",
				"res://Sprite folders grab bag/swamp_tree2.png",
				"res://Sprite folders grab bag/swamp_downtree1.png",
				"res://Sprite folders grab bag/swamp_downtree2.png"
			]
		Biome.FOREST:
			tree_textures = [
				"res://Sprite folders grab bag/autumntree.png",
				"res://Sprite folders grab bag/autumntree2.png"
			]
		_:
			tree_textures = [
				"res://Sprite folders grab bag/autumntree.png"
			]

	if tree_textures.is_empty():
		return

	var tex_path: String = tree_textures[rng.randi() % tree_textures.size()]
	if not ResourceLoader.exists(tex_path):
		return

	var tree := Sprite3D.new()
	tree.name = "Tree"
	tree.texture = load(tex_path)
	tree.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tree.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	tree.pixel_size = rng.randf_range(0.03, 0.05)
	tree.position = pos + Vector3(0, tree.texture.get_height() * tree.pixel_size * 0.5, 0)
	tree.modulate = _get_biome_prop_tint()
	parent.add_child(tree)


## Spawn special props (gravestones for swamp/undead, flood patches, etc.)
func _spawn_special_prop(parent: Node3D, pos: Vector3) -> void:
	var special_textures: Array[String] = []

	match biome:
		Biome.SWAMP:
			# Swamp gets gravestones, flood patches, and dead things
			special_textures = [
				"res://Sprite folders grab bag/gravehead_1.png",
				"res://Sprite folders grab bag/gravehead_2.png",
				"res://Sprite folders grab bag/gravehead_3.png",
				"res://Sprite folders grab bag/swamp_flood1.png",
				"res://Sprite folders grab bag/swamp_flood2.png"
			]
		Biome.ROCKY, Biome.HILLS:
			# Rocky areas might have some fallen trees or rocks
			special_textures = [
				"res://Sprite folders grab bag/swamp_downtree1.png"
			]
		_:
			return  # No special props for other biomes

	if special_textures.is_empty():
		return

	var tex_path: String = special_textures[rng.randi() % special_textures.size()]
	if not ResourceLoader.exists(tex_path):
		return

	var prop := Sprite3D.new()
	prop.name = "SpecialProp"
	prop.texture = load(tex_path)
	prop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prop.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	prop.pixel_size = rng.randf_range(0.02, 0.035)
	prop.position = pos + Vector3(0, prop.texture.get_height() * prop.pixel_size * 0.5, 0)
	prop.modulate = _get_biome_prop_tint()
	parent.add_child(prop)


## Get tint color for props based on biome
func _get_biome_prop_tint() -> Color:
	match biome:
		Biome.SWAMP:
			return Color(0.7, 0.8, 0.65)  # Murky green tint
		Biome.FOREST:
			return Color(0.9, 0.95, 0.85)  # Slight green
		Biome.PLAINS:
			return Color(1.0, 0.95, 0.85)  # Warm yellow
		Biome.ROCKY:
			return Color(0.85, 0.85, 0.9)  # Cool gray
		_:
			return Color.WHITE


## Spawn 3D terrain props (hills, rocks, boulders) using GLB models
func _spawn_terrain_props() -> void:
	# Check if we should spawn terrain props at all
	if rng.randf() > terrain_prop_chance:
		return

	# On road cells, reduce terrain prop spawning
	if is_road_cell:
		return  # Skip terrain props on roads

	var terrain_container := Node3D.new()
	terrain_container.name = "TerrainProps"
	add_child(terrain_container)

	# Determine which prop types to spawn based on biome
	var prop_types: Array[String] = _get_terrain_prop_types_for_biome()
	if prop_types.is_empty():
		return

	var num_props: int = rng.randi_range(terrain_prop_count_min, terrain_prop_count_max)
	var half_size: float = room_size / 2.0 - 10.0  # Keep away from edges

	for i in range(num_props):
		var prop_type: String = prop_types[rng.randi() % prop_types.size()]
		var models: Array = TERRAIN_MODELS.get(prop_type, [])
		if models.is_empty():
			continue

		var model_path: String = models[rng.randi() % models.size()]
		if not ResourceLoader.exists(model_path):
			continue

		var pos := Vector3(
			rng.randf_range(-half_size, half_size),
			0.0,
			rng.randf_range(-half_size, half_size)
		)

		# Use TerrainProp class to spawn and texture the model
		var biome_name: String = _get_biome_name_string()
		var scale_val: float = rng.randf_range(0.8, 1.5)

		var prop: TerrainProp = TerrainProp.spawn_prop(
			terrain_container,
			pos,
			model_path,
			prop_type,
			biome_name,
			scale_val
		)

		if prop:
			props.append(prop)


## Get terrain prop types appropriate for current biome
func _get_terrain_prop_types_for_biome() -> Array[String]:
	match biome:
		Biome.HILLS, Biome.ROCKY:
			return ["hill", "rock", "boulder", "cliff"]
		Biome.FOREST:
			return ["hill", "stump", "log", "rock"]
		Biome.PLAINS:
			return ["hill", "rock"]
		Biome.SWAMP:
			return ["log", "stump"]
		_:
			return ["hill", "rock"]


## Convert biome enum to string for TerrainProp
func _get_biome_name_string() -> String:
	match biome:
		Biome.FOREST:
			return "forest"
		Biome.PLAINS:
			return "plains"
		Biome.SWAMP:
			return "swamp"
		Biome.HILLS:
			return "hills"
		Biome.ROCKY:
			return "rocky"
		_:
			return "plains"


## PS1-style distance fog settings (tight visibility for retro feel)
const FOG_START := 8.0    # Distance where fog begins
const FOG_END := 15.0     # Distance where fog is fully opaque

## Create sky and environment
func _create_sky_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.add_to_group("world_environment")

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()

	# Default fog color (will be overridden per biome)
	var fog_color := Color(0.55, 0.55, 0.6)

	match biome:
		Biome.FOREST:
			sky_mat.sky_top_color = Color(0.3, 0.5, 0.7)
			sky_mat.sky_horizon_color = Color(0.6, 0.7, 0.8)
			sky_mat.ground_horizon_color = Color(0.4, 0.5, 0.3)
			fog_color = Color(0.5, 0.55, 0.45)  # Greenish fog
		Biome.SWAMP:
			sky_mat.sky_top_color = Color(0.25, 0.3, 0.35)
			sky_mat.sky_horizon_color = Color(0.4, 0.45, 0.4)
			sky_mat.ground_horizon_color = Color(0.2, 0.25, 0.2)
			fog_color = Color(0.25, 0.3, 0.25)  # Murky green fog
		Biome.ROCKY:
			sky_mat.sky_top_color = Color(0.4, 0.4, 0.5)
			sky_mat.sky_horizon_color = Color(0.55, 0.5, 0.55)
			sky_mat.ground_horizon_color = Color(0.35, 0.32, 0.3)
			fog_color = Color(0.4, 0.38, 0.4)  # Dusty gray fog
		Biome.HILLS:
			sky_mat.sky_top_color = Color(0.35, 0.5, 0.65)
			sky_mat.sky_horizon_color = Color(0.6, 0.65, 0.7)
			sky_mat.ground_horizon_color = Color(0.4, 0.42, 0.35)
			fog_color = Color(0.5, 0.5, 0.55)  # Light gray fog
		_:  # PLAINS and default
			sky_mat.sky_top_color = Color(0.35, 0.55, 0.75)
			sky_mat.sky_horizon_color = Color(0.65, 0.75, 0.85)
			sky_mat.ground_horizon_color = Color(0.45, 0.5, 0.35)
			fog_color = Color(0.55, 0.55, 0.5)  # Neutral fog

	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.4

	# PS1-style depth-based distance fog
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0  # No sun scattering for cleaner PS1 look
	env.fog_density = 0.0  # Disable density fog
	env.fog_aerial_perspective = 0.0  # No aerial perspective
	env.fog_sky_affect = 1.0  # Fog affects sky too
	env.fog_depth_curve = 1.0  # Linear falloff
	env.fog_depth_begin = FOG_START  # Fog starts at 20 units
	env.fog_depth_end = FOG_END  # Fully opaque at 40 units

	world_env.environment = env
	add_child(world_env)

	# Directional sun light
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)


## Create full-wall edge triggers
func _create_edges() -> void:
	edges = RoomEdge.create_room_edges(self, room_size)

	# Connect edge signals
	for dir: int in edges:
		var edge: RoomEdge = edges[dir]
		edge.edge_entered.connect(_on_edge_entered)

	# Add invisible walls at all 4 edges to prevent falling off
	_create_invisible_walls()


## Create invisible collision walls at all edges - prevents falling off world
func _create_invisible_walls() -> void:
	var half_size := room_size / 2.0
	var wall_height := 10.0
	var wall_thickness := 2.0
	var wall_distance := half_size + 15.0  # Just past the edge triggers

	var wall_container := Node3D.new()
	wall_container.name = "InvisibleWalls"
	add_child(wall_container)

	# Create 4 walls (N, S, E, W)
	for side in range(4):
		var wall := StaticBody3D.new()
		wall.name = "Wall_%d" % side

		var col_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()

		match side:
			0:  # North (-Z)
				box.size = Vector3(room_size + 40, wall_height, wall_thickness)
				wall.position = Vector3(0, wall_height / 2.0, -wall_distance)
			1:  # South (+Z)
				box.size = Vector3(room_size + 40, wall_height, wall_thickness)
				wall.position = Vector3(0, wall_height / 2.0, wall_distance)
			2:  # East (+X)
				box.size = Vector3(wall_thickness, wall_height, room_size + 40)
				wall.position = Vector3(wall_distance, wall_height / 2.0, 0)
			3:  # West (-X)
				box.size = Vector3(wall_thickness, wall_height, room_size + 40)
				wall.position = Vector3(-wall_distance, wall_height / 2.0, 0)

		col_shape.shape = box
		wall.add_child(col_shape)
		wall_container.add_child(wall)

	print("[WildernessRoom] Created invisible boundary walls")


## Handle player entering an edge
func _on_edge_entered(direction: RoomEdge.Direction) -> void:
	# In seamless mode, WorldManager handles transitions - don't emit edge signals
	if seamless_mode:
		return

	print("[WildernessRoom] Edge triggered: %s" % RoomEdge.Direction.keys()[direction])
	edge_triggered.emit(direction)


## Create directional spawn points for cell transitions
## These are placed at edges so player spawns at correct side when entering from a direction
func _create_spawn_points() -> void:
	var half_size: float = room_size / 2.0
	var margin: float = 15.0  # Distance from edge to place spawn point

	# Spawn point data: {id, position}
	# When player exits NORTH, they enter next cell and spawn at "from_south" (south side)
	# When player exits SOUTH, they enter next cell and spawn at "from_north" (north side)
	# When player exits EAST, they enter next cell and spawn at "from_west" (west side)
	# When player exits WEST, they enter next cell and spawn at "from_east" (east side)
	var spawn_data: Array[Dictionary] = [
		{"id": "from_north", "pos": Vector3(0, 0.5, -half_size + margin)},  # Spawn at north edge
		{"id": "from_south", "pos": Vector3(0, 0.5, half_size - margin)},   # Spawn at south edge
		{"id": "from_east", "pos": Vector3(half_size - margin, 0.5, 0)},    # Spawn at east edge
		{"id": "from_west", "pos": Vector3(-half_size + margin, 0.5, 0)},   # Spawn at west edge
	]

	var spawn_container := Node3D.new()
	spawn_container.name = "SpawnPoints"
	add_child(spawn_container)

	for data: Dictionary in spawn_data:
		var point := Node3D.new()
		point.name = data["id"]
		point.set_meta("spawn_id", data["id"])  # Set metadata for SceneManager
		point.add_to_group("spawn_points")
		point.position = data["pos"]
		spawn_container.add_child(point)

	print("[WildernessRoom] Created 4 directional spawn points with metadata")


## Set the static background image via BackgroundManager autoload
func _set_background_for_biome() -> void:
	if BackgroundManager:
		BackgroundManager.set_background_for_biome(biome)
		BackgroundManager.show_background()
		print("[WildernessRoom] Set background for biome: %s" % Biome.keys()[biome])


## Spawn 1-3 ruins (small explorable structures)
func _spawn_ruins() -> void:
	var ruin_count := rng.randi_range(min_ruins, max_ruins)
	var placed_positions: Array[Vector3] = []
	var min_distance := 20.0  # Minimum distance between ruins

	for i in range(ruin_count):
		var attempts := 0
		var max_attempts := 20
		var pos: Vector3

		while attempts < max_attempts:
			pos = _get_random_content_position()
			var valid := true

			# Check distance from other ruins
			for other_pos: Vector3 in placed_positions:
				if pos.distance_to(other_pos) < min_distance:
					valid = false
					break

			if valid:
				break
			attempts += 1

		if attempts < max_attempts:
			var ruin := _create_ruin(i)
			ruin.position = pos
			add_child(ruin)
			ruins.append(ruin)
			placed_positions.append(pos)


## Spawn Cursed Totems near ruins (skeleton spawners)
func _spawn_cursed_totems() -> void:
	if ruins.is_empty():
		return

	# Chance to spawn a totem near each ruin
	for ruin in ruins:
		if rng.randf() > cursed_totem_chance:
			continue

		# Spawn totem offset from ruin
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(4.0, 8.0)
		var offset := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var totem_pos: Vector3 = ruin.position + offset

		# Create unique ID based on room coords
		var totem_id := "cursed_totem_%d_%d_%d" % [grid_coords.x, grid_coords.y, cursed_totems.size()]

		var totem := CursedTotem.spawn_totem(self, totem_pos, totem_id)
		if totem:
			cursed_totems.append(totem)
			print("[WildernessRoom] Spawned Cursed Totem near ruin at %s" % totem_pos)


## Spawn decorative statues near ruins, dungeons, and standalone
func _spawn_statues() -> void:
	if STATUE_MODELS.is_empty():
		push_warning("[WildernessRoom] No statue models defined")
		return

	var statues_container := Node3D.new()
	statues_container.name = "Statues"
	add_child(statues_container)

	var biome_name: String = _get_biome_name_string()
	var statues_spawned: int = 0

	# Spawn statues near ruins
	for ruin in ruins:
		if rng.randf() > statue_near_ruins_chance:
			continue

		var angle := rng.randf() * TAU
		var distance := rng.randf_range(5.0, 10.0)
		var offset := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var statue_pos: Vector3 = ruin.position + offset

		var model_path: String = STATUE_MODELS[rng.randi() % STATUE_MODELS.size()]
		var scale_val: float = rng.randf_range(1.0, 1.5)

		var statue: TerrainProp = TerrainProp.spawn_prop(
			statues_container,
			statue_pos,
			model_path,
			"statue",
			biome_name,
			scale_val
		)
		if statue:
			props.append(statue)
			statues_spawned += 1

	# Spawn statue near dungeon entrance
	if dungeon_entrance and rng.randf() <= statue_near_dungeon_chance:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(4.0, 8.0)
		var offset := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var statue_pos: Vector3 = dungeon_entrance.position + offset

		var model_path: String = STATUE_MODELS[rng.randi() % STATUE_MODELS.size()]
		var scale_val: float = rng.randf_range(1.2, 1.8)  # Slightly larger near dungeons

		var statue: TerrainProp = TerrainProp.spawn_prop(
			statues_container,
			statue_pos,
			model_path,
			"statue",
			biome_name,
			scale_val
		)
		if statue:
			props.append(statue)
			statues_spawned += 1

	# Chance for standalone statue in the wilderness
	if rng.randf() <= statue_standalone_chance:
		var pos := _get_random_content_position()
		var model_path: String = STATUE_MODELS[rng.randi() % STATUE_MODELS.size()]
		var scale_val: float = rng.randf_range(0.8, 1.3)

		var statue: TerrainProp = TerrainProp.spawn_prop(
			statues_container,
			pos,
			model_path,
			"statue",
			biome_name,
			scale_val
		)
		if statue:
			props.append(statue)
			statues_spawned += 1

	if statues_spawned > 0:
		print("[WildernessRoom] Spawned %d statue(s)" % statues_spawned)


## Create a ruin structure
func _create_ruin(index: int) -> Node3D:
	var ruin := Node3D.new()
	ruin.name = "Ruin_%d" % index

	var ruin_type := rng.randi() % 4

	match ruin_type:
		0:  # Broken tower
			_create_broken_tower(ruin)
		1:  # Ruined walls
			_create_ruined_walls(ruin)
		2:  # Collapsed building
			_create_collapsed_building(ruin)
		3:  # Stone circle
			_create_stone_circle(ruin)

	return ruin


## Create a broken tower ruin
func _create_broken_tower(parent: Node3D) -> void:
	# Base
	var base := CSGCylinder3D.new()
	base.name = "TowerBase"
	base.radius = 3.0
	base.height = rng.randf_range(4.0, 8.0)
	base.sides = 8
	base.position = Vector3(0, base.height / 2.0, 0)
	base.material = ruin_material
	base.use_collision = true
	parent.add_child(base)

	# Broken top (tilted cylinder)
	if rng.randf() > 0.3:
		var top := CSGCylinder3D.new()
		top.name = "BrokenTop"
		top.radius = 2.8
		top.height = 2.0
		top.sides = 8
		top.position = Vector3(rng.randf_range(-0.5, 0.5), base.height + 0.5, rng.randf_range(-0.5, 0.5))
		top.rotation_degrees = Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15))
		top.material = ruin_material
		top.use_collision = true
		parent.add_child(top)


## Create ruined walls
func _create_ruined_walls(parent: Node3D) -> void:
	var wall_count := rng.randi_range(2, 4)

	for i in range(wall_count):
		var wall := CSGBox3D.new()
		wall.name = "Wall_%d" % i
		wall.size = Vector3(
			rng.randf_range(4.0, 8.0),
			rng.randf_range(2.0, 5.0),
			rng.randf_range(0.5, 1.0)
		)
		wall.position = Vector3(
			rng.randf_range(-4, 4),
			wall.size.y / 2.0,
			rng.randf_range(-4, 4)
		)
		wall.rotation_degrees.y = rng.randf_range(0, 360)
		wall.material = ruin_material
		wall.use_collision = true
		parent.add_child(wall)


## Create collapsed building
func _create_collapsed_building(parent: Node3D) -> void:
	# Foundation
	var foundation := CSGBox3D.new()
	foundation.name = "Foundation"
	foundation.size = Vector3(8, 0.5, 6)
	foundation.position = Vector3(0, 0.25, 0)
	foundation.material = ruin_material
	foundation.use_collision = true
	parent.add_child(foundation)

	# Partial walls
	var wall1 := CSGBox3D.new()
	wall1.size = Vector3(8, 3, 0.5)
	wall1.position = Vector3(0, 1.5, -2.75)
	wall1.material = ruin_material
	wall1.use_collision = true
	parent.add_child(wall1)

	# Collapsed debris
	for i in range(rng.randi_range(3, 6)):
		var debris := CSGBox3D.new()
		debris.name = "Debris_%d" % i
		debris.size = Vector3(
			rng.randf_range(0.5, 2.0),
			rng.randf_range(0.3, 1.0),
			rng.randf_range(0.5, 2.0)
		)
		debris.position = Vector3(
			rng.randf_range(-3, 3),
			debris.size.y / 2.0,
			rng.randf_range(-2, 3)
		)
		debris.rotation_degrees = Vector3(
			rng.randf_range(-20, 20),
			rng.randf_range(0, 360),
			rng.randf_range(-20, 20)
		)
		debris.material = ruin_material
		debris.use_collision = true
		parent.add_child(debris)


## Create stone circle
func _create_stone_circle(parent: Node3D) -> void:
	var stone_count := rng.randi_range(5, 8)
	var radius := 5.0

	for i in range(stone_count):
		var angle := (float(i) / stone_count) * TAU
		var stone := CSGBox3D.new()
		stone.name = "Stone_%d" % i
		stone.size = Vector3(
			rng.randf_range(0.8, 1.5),
			rng.randf_range(2.0, 4.0),
			rng.randf_range(0.4, 0.8)
		)
		stone.position = Vector3(
			cos(angle) * radius,
			stone.size.y / 2.0,
			sin(angle) * radius
		)
		stone.rotation_degrees.y = rad_to_deg(angle) + 90
		stone.material = ruin_material
		stone.use_collision = true
		parent.add_child(stone)

	# Center altar
	var altar := CSGBox3D.new()
	altar.name = "Altar"
	altar.size = Vector3(2.0, 0.8, 2.0)
	altar.position = Vector3(0, 0.4, 0)
	altar.material = rock_material
	altar.use_collision = true
	parent.add_child(altar)


## Spawn dungeon entrance (30% chance)
func _spawn_dungeon_entrance() -> void:
	if rng.randf() > dungeon_chance:
		return

	var pos := _get_random_content_position()

	# Check distance from ruins
	for ruin: Node3D in ruins:
		if pos.distance_to(ruin.position) < 15.0:
			pos = _get_random_content_position()  # Try again

	dungeon_entrance = _create_dungeon_entrance()
	dungeon_entrance.position = pos
	add_child(dungeon_entrance)
	print("[WildernessRoom] Spawned dungeon entrance at %s" % pos)


## Create dungeon entrance structure with proper ZoneDoor
func _create_dungeon_entrance() -> Node3D:
	var entrance := Node3D.new()
	entrance.name = "DungeonEntrance"
	entrance.add_to_group("dungeon_entrance")

	# Stone archway
	var left_pillar := CSGBox3D.new()
	left_pillar.size = Vector3(1.0, 4.0, 1.0)
	left_pillar.position = Vector3(-1.5, 2.0, 0)
	left_pillar.material = rock_material
	left_pillar.use_collision = true
	entrance.add_child(left_pillar)

	var right_pillar := CSGBox3D.new()
	right_pillar.size = Vector3(1.0, 4.0, 1.0)
	right_pillar.position = Vector3(1.5, 2.0, 0)
	right_pillar.material = rock_material
	right_pillar.use_collision = true
	entrance.add_child(right_pillar)

	var arch := CSGBox3D.new()
	arch.size = Vector3(4.0, 0.8, 1.0)
	arch.position = Vector3(0, 4.4, 0)
	arch.material = rock_material
	arch.use_collision = true
	entrance.add_child(arch)

	# Dark pit (visual indicator)
	var pit := CSGBox3D.new()
	pit.size = Vector3(2.0, 0.5, 2.0)
	pit.position = Vector3(0, -0.25, 0)
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.05, 0.05, 0.08)
	pit.material = dark_mat
	pit.use_collision = true
	entrance.add_child(pit)

	# Stairs going down
	for i in range(4):
		var step := CSGBox3D.new()
		step.size = Vector3(2.0, 0.3, 0.6)
		step.position = Vector3(0, -0.15 - i * 0.3, -0.3 - i * 0.6)
		step.material = rock_material
		step.use_collision = true
		entrance.add_child(step)

	# Create proper ZoneDoor for dungeon entry (interactable)
	var dungeon_door := ZoneDoor.spawn_door(
		entrance,
		Vector3(0, 0.5, -1.0),  # Position in front of stairs
		"res://scenes/levels/random_cave.tscn",  # Procedural dungeon
		"entrance",
		"Enter Cave"
	)
	dungeon_door.rotation.y = PI  # Face outward

	return entrance


## Spawn environmental props (trees, rocks, bushes, grass)
func _spawn_environment() -> void:
	var tree_count := 0
	var rock_count := 0
	var bush_count := 0
	var grass_count := 0
	var swamp_tree_count := 0
	var fallen_tree_count := 0

	match biome:
		Biome.FOREST:
			tree_count = rng.randi_range(40, 60)  # Dense forest
			bush_count = rng.randi_range(20, 35)  # Harvestable bushes
			rock_count = rng.randi_range(3, 8)    # Few rocks
			grass_count = rng.randi_range(18, 25) # Moderate grass, scattered among trees
		Biome.PLAINS:
			tree_count = rng.randi_range(3, 8)    # Sparse trees
			bush_count = rng.randi_range(10, 20)  # Some bushes to harvest
			rock_count = rng.randi_range(5, 10)   # Scattered rocks
			grass_count = rng.randi_range(28, 38) # Dense grass coverage
		Biome.SWAMP:
			tree_count = rng.randi_range(15, 25)  # Fewer regular trees
			bush_count = rng.randi_range(15, 25)  # Harvestable
			rock_count = rng.randi_range(3, 6)    # Few rocks
			grass_count = rng.randi_range(10, 16) # Sparse grass in murky water
			swamp_tree_count = rng.randi_range(4, 7)   # Standing swamp trees
			fallen_tree_count = rng.randi_range(3, 5)  # Fallen/dead trees
		Biome.HILLS:
			tree_count = rng.randi_range(8, 15)   # Moderate trees
			bush_count = rng.randi_range(10, 18)  # Harvestable
			rock_count = rng.randi_range(12, 20)  # Rocky terrain
			grass_count = rng.randi_range(15, 22) # Moderate grass
		Biome.ROCKY:
			tree_count = rng.randi_range(2, 5)    # Very sparse
			bush_count = rng.randi_range(5, 10)   # Few bushes
			rock_count = rng.randi_range(20, 35)  # Lots of rocks
			grass_count = rng.randi_range(5, 10)  # Very sparse grass

	# Reduce prop density on road cells
	if is_road_cell:
		tree_count = int(tree_count * road_prop_density_multiplier)
		bush_count = int(bush_count * road_prop_density_multiplier)
		rock_count = int(rock_count * road_prop_density_multiplier)
		grass_count = int(grass_count * road_prop_density_multiplier)
		swamp_tree_count = int(swamp_tree_count * road_prop_density_multiplier)
		fallen_tree_count = int(fallen_tree_count * road_prop_density_multiplier)

	# Spawn trees
	for i in range(tree_count):
		var tree := _create_tree()
		tree.position = _get_random_prop_position()
		add_child(tree)
		props.append(tree)

	# Spawn rocks
	for i in range(rock_count):
		var rock := _create_rock()
		rock.position = _get_random_prop_position()
		add_child(rock)
		props.append(rock)

	# Spawn bushes
	for i in range(bush_count):
		var bush := _create_bush()
		bush.position = _get_random_prop_position()
		add_child(bush)
		props.append(bush)

	# Spawn grass clumps (decorative, no collision)
	for i in range(grass_count):
		var grass := _create_grass_clump()
		grass.position = _get_random_prop_position()
		add_child(grass)
		props.append(grass)

	# Spawn swamp-specific trees (standing swamp trees with collision)
	for i in range(swamp_tree_count):
		var swamp_tree := _create_swamp_tree()
		swamp_tree.position = _get_random_prop_position()
		add_child(swamp_tree)
		props.append(swamp_tree)

	# Spawn fallen trees in swamp (ground obstacles with collision)
	for i in range(fallen_tree_count):
		var fallen := _create_fallen_tree()
		fallen.position = _get_random_prop_position()
		add_child(fallen)
		props.append(fallen)


## Create a billboard sprite tree
func _create_tree() -> Node3D:
	var tree := Node3D.new()
	tree.name = "Tree"

	# Get tree texture based on biome
	var tree_tex: Texture2D = _get_tree_texture()
	if not tree_tex:
		return tree  # Return empty node if no texture

	var sprite := Sprite3D.new()
	sprite.texture = tree_tex
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.pixel_size = 0.025  # Scale to make trees ~8-12 units tall
	sprite.no_depth_test = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 style

	# Random scale variation (0.7 to 1.1 for variety)
	var scale_var := rng.randf_range(0.7, 1.1)
	sprite.scale = Vector3(scale_var, scale_var, 1.0)

	# Position sprite so bottom is at ground level
	# Tree sprites are roughly square, so height = width * pixel_size * scale
	var approx_height: float = tree_tex.get_height() * sprite.pixel_size * scale_var
	sprite.position = Vector3(0, approx_height / 2.0, 0)

	tree.add_child(sprite)

	# Add small collision cylinder at base for tree trunk
	var collision := StaticBody3D.new()
	var col_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.4
	cylinder.height = 2.0
	col_shape.shape = cylinder
	col_shape.position = Vector3(0, 1.0, 0)
	collision.add_child(col_shape)
	tree.add_child(collision)

	return tree


## Get tree texture based on biome
func _get_tree_texture() -> Texture2D:
	match biome:
		Biome.FOREST:
			# Randomly pick between autumn trees
			if rng.randf() > 0.5:
				return load("res://Sprite folders grab bag/autumntree.png")
			else:
				return load("res://Sprite folders grab bag/autumntree2.png")
		Biome.SWAMP:
			# Use autumn trees but could add dead tree sprites later
			return load("res://Sprite folders grab bag/autumntree2.png")
		Biome.PLAINS:
			# Sparse trees - use autumn tree
			return load("res://Sprite folders grab bag/autumntree.png")
		_:
			# Default to autumn tree
			return load("res://Sprite folders grab bag/autumntree.png")


## Create a rock using stone texture - small environmental prop
func _create_rock() -> Node3D:
	var rock := CSGBox3D.new()
	rock.name = "Rock"

	# Random rock size
	rock.size = Vector3(
		rng.randf_range(0.5, 2.0),
		rng.randf_range(0.3, 1.2),
		rng.randf_range(0.5, 2.0)
	)
	rock.position = Vector3(0, rock.size.y / 2.0, 0)
	rock.rotation_degrees = Vector3(
		rng.randf_range(-15, 15),
		rng.randf_range(0, 360),
		rng.randf_range(-15, 15)
	)

	# Use stone texture
	var rock_mat := StandardMaterial3D.new()
	var stone_tex: Texture2D = load("res://Sprite folders grab bag/stonewall.png")
	if stone_tex:
		rock_mat.albedo_texture = stone_tex
		rock_mat.uv1_scale = Vector3(0.3, 0.3, 0.3)
		rock_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	else:
		rock_mat.albedo_color = rock_material.albedo_color
	rock_mat.roughness = 0.95

	rock.material = rock_mat
	rock.use_collision = true

	return rock


## Create a bush - uses HarvestablePlant for proper interaction
func _create_bush() -> Node3D:
	# Use HarvestablePlant class for proper interact() and get_interaction_prompt() support
	var plant := HarvestablePlant.new()
	plant.name = "Bush"
	plant.plant_type = "red_herb"  # Currently only red_herb exists as an item
	plant.display_name = "Herb Bush"
	plant.base_yield = 1
	return plant


## Grassland texture paths for decorative grass clumps
const GRASSLAND_TEXTURES: Array[String] = [
	"res://Sprite folders grab bag/grassland_1.png",
	"res://Sprite folders grab bag/grassland_2.png",
	"res://Sprite folders grab bag/grassland_3.png"
]


## Create a decorative grass clump - small ground cover, no collision
func _create_grass_clump() -> Node3D:
	var grass := Node3D.new()
	grass.name = "GrassClump"

	# Pick random grass texture
	var tex_path: String = GRASSLAND_TEXTURES[rng.randi() % GRASSLAND_TEXTURES.size()]
	var grass_tex: Texture2D = load(tex_path)
	if not grass_tex:
		return grass  # Return empty node if texture fails

	var sprite := Sprite3D.new()
	sprite.texture = grass_tex
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y  # Rotate with camera but stay upright
	sprite.no_depth_test = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 style

	# Smaller pixel size for grass (ground cover, not tall vegetation)
	var base_pixel_size := 0.012

	# Random size variation for natural look (0.7 to 1.3 range)
	var scale_var: float = rng.randf_range(0.7, 1.3)
	sprite.pixel_size = base_pixel_size * scale_var

	# Random Y rotation for variety (full 360 degrees)
	grass.rotation_degrees.y = rng.randf_range(0, 360)

	# Position sprite so bottom is at ground level
	var approx_height: float = grass_tex.get_height() * sprite.pixel_size
	sprite.position = Vector3(0, approx_height / 2.0, 0)

	grass.add_child(sprite)

	# No collision - grass is just decorative ground cover

	return grass


## Swamp tree textures
const SWAMP_TREE_TEXTURE := "res://Sprite folders grab bag/swamp_tree1.png"


## Create a standing swamp tree - larger obstacle with collision
func _create_swamp_tree() -> Node3D:
	var tree := Node3D.new()
	tree.name = "SwampTree"

	var tree_tex: Texture2D = load(SWAMP_TREE_TEXTURE)
	if not tree_tex:
		return tree  # Return empty node if texture fails

	var sprite := Sprite3D.new()
	sprite.texture = tree_tex
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.no_depth_test = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 style

	# Swamp trees are larger, gnarled obstacles
	var base_pixel_size := 0.028

	# Random scale variation (0.8 to 1.2 for variety)
	var scale_var: float = rng.randf_range(0.8, 1.2)
	sprite.pixel_size = base_pixel_size * scale_var

	# Position sprite so bottom is at ground level
	var approx_height: float = tree_tex.get_height() * sprite.pixel_size
	sprite.position = Vector3(0, approx_height / 2.0, 0)

	tree.add_child(sprite)

	# Add collision cylinder at base for trunk (larger than regular trees)
	var collision := StaticBody3D.new()
	var col_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.6  # Wider trunk than regular trees
	cylinder.height = 2.5
	col_shape.shape = cylinder
	col_shape.position = Vector3(0, 1.25, 0)
	collision.add_child(col_shape)
	tree.add_child(collision)

	return tree


## Fallen/down tree textures for swamp
const FALLEN_TREE_TEXTURES: Array[String] = [
	"res://Sprite folders grab bag/swamp_downtree1.png",
	"res://Sprite folders grab bag/swamp_downtree2.png"
]


## Create a fallen/dead tree - ground obstacle, slightly tilted or flat
func _create_fallen_tree() -> Node3D:
	var fallen := Node3D.new()
	fallen.name = "FallenTree"

	# Pick random fallen tree texture
	var tex_path: String = FALLEN_TREE_TEXTURES[rng.randi() % FALLEN_TREE_TEXTURES.size()]
	var fallen_tex: Texture2D = load(tex_path)
	if not fallen_tex:
		return fallen  # Return empty node if texture fails

	var sprite := Sprite3D.new()
	sprite.texture = fallen_tex
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.no_depth_test = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 style

	# Fallen trees are lower to the ground
	var base_pixel_size := 0.022

	# Random scale variation
	var scale_var: float = rng.randf_range(0.85, 1.15)
	sprite.pixel_size = base_pixel_size * scale_var

	# Random Y rotation (full 360 - fallen trees can point any direction)
	fallen.rotation_degrees.y = rng.randf_range(0, 360)

	# Slight X tilt to make it look more fallen/collapsed (0-15 degrees)
	var tilt_angle: float = rng.randf_range(-12, 12)
	sprite.rotation_degrees.x = tilt_angle

	# Position sprite so bottom is near ground level (slightly embedded)
	var approx_height: float = fallen_tex.get_height() * sprite.pixel_size
	sprite.position = Vector3(0, approx_height / 2.5, 0)  # Lower than standing trees

	fallen.add_child(sprite)

	# Add collision box for fallen trunk (elongated obstacle)
	var collision := StaticBody3D.new()
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Fallen trees are longer horizontally, shorter vertically
	box.size = Vector3(2.0, 0.8, 0.6)
	col_shape.shape = box
	col_shape.position = Vector3(0, 0.4, 0)
	collision.add_child(col_shape)
	fallen.add_child(collision)

	return fallen


## Get floor texture based on biome (randomly picks from available)
func _get_floor_texture() -> Texture2D:
	var textures: Array[String] = []

	match biome:
		Biome.FOREST:
			# Forest floor uses fallen leaves textures
			textures = [
				"res://Sprite folders grab bag/fullelaves.png",
				"res://Sprite folders grab bag/half leaves.png"
			]
		Biome.SWAMP:
			textures = [
				"res://Sprite folders grab bag/swamp_flood1.png",
				"res://Sprite folders grab bag/swamp_flood2.png"
			]
		Biome.PLAINS:
			textures = [
				"res://Sprite folders grab bag/plains_floor1.png",
				"res://Sprite folders grab bag/plains_floor2.png",
				"res://Sprite folders grab bag/plains_floor3.png"
			]
		Biome.HILLS, Biome.ROCKY:
			textures = [
				"res://Sprite folders grab bag/rockhill_floor1.png",
				"res://Sprite folders grab bag/rockhill_floor2.png",
				"res://Sprite folders grab bag/rockhill_floor3.png"
			]
		_:
			textures = [
				"res://Sprite folders grab bag/plains_floor1.png"
			]

	if textures.is_empty():
		return null

	var path: String = textures[rng.randi() % textures.size()]
	return load(path)


## Spawn actual enemies using EnemyBase.spawn_billboard_enemy
func _spawn_enemies() -> void:
	var count := rng.randi_range(enemy_count_min, enemy_count_max)
	var placed_positions: Array[Vector3] = []
	var min_enemy_distance := 8.0  # Minimum distance between enemies

	for i in range(count):
		var attempts := 0
		var max_attempts := 15
		var pos: Vector3

		# Find valid position not too close to other enemies
		while attempts < max_attempts:
			pos = _get_random_content_position()
			var valid := true

			for other_pos: Vector3 in placed_positions:
				if pos.distance_to(other_pos) < min_enemy_distance:
					valid = false
					break

			# Also check distance from ruins
			for ruin: Node3D in ruins:
				if pos.distance_to(ruin.position) < 10.0:
					valid = false
					break

			if valid:
				break
			attempts += 1

		if attempts >= max_attempts:
			continue  # Skip this enemy if no valid position found

		# Get enemy config for this biome
		var enemy_config: Dictionary = _get_enemy_config_for_biome()

		var enemy: Node = null

		# Check if this is a skeleton enemy - use specialized spawner with walk/attack sprites
		if enemy_config.get("is_skeleton", false):
			enemy = EnemyBase.spawn_skeleton_enemy(
				self,
				pos,
				enemy_config.data_path
			)
		else:
			# Load sprite texture for regular enemies
			var sprite_tex: Texture2D = load(enemy_config.sprite_path)
			if not sprite_tex:
				push_warning("[WildernessRoom] Failed to load sprite: %s" % enemy_config.sprite_path)
				continue

			# Spawn regular billboard enemy
			enemy = EnemyBase.spawn_billboard_enemy(
				self,
				pos,
				enemy_config.data_path,
				sprite_tex,
				enemy_config.h_frames,
				enemy_config.v_frames
			)

		if enemy:
			enemies.append(enemy)
			placed_positions.append(pos)
			print("[WildernessRoom] Spawned %s at %s" % [enemy_config.display_name, pos])

	print("[WildernessRoom] Spawned %d enemies" % enemies.size())


## Get enemy configuration based on biome
## Returns dictionary with: data_path, sprite_path, h_frames, v_frames, display_name
## NOTE: Skeletons removed from open world - they only spawn from Cursed Totems
func _get_enemy_config_for_biome() -> Dictionary:
	var configs: Array[Dictionary] = []

	match biome:
		Biome.FOREST:
			configs = [
				{
					"data_path": "res://data/enemies/wolf.tres",
					"sprite_path": "res://Sprite folders grab bag/wolf_moving.png",
					"h_frames": 6,
					"v_frames": 1,
					"display_name": "Wolf",
					"is_skeleton": false
				},
				{
					"data_path": "res://data/enemies/giant_spider.tres",
					"sprite_path": "res://Sprite folders grab bag/evilspider.png",
					"h_frames": 1,
					"v_frames": 1,
					"display_name": "Giant Spider",
					"is_skeleton": false
				},
				{
					"data_path": "res://data/enemies/human_bandit.tres",
					"sprite_path": "res://Sprite folders grab bag/3x4humanbandit.png",
					"h_frames": 4,
					"v_frames": 1,
					"display_name": "Bandit",
					"is_skeleton": false
				}
			]
		Biome.SWAMP:
			configs = [
				{
					"data_path": "res://data/enemies/giant_spider.tres",
					"sprite_path": "res://Sprite folders grab bag/evilspider.png",
					"h_frames": 1,
					"v_frames": 1,
					"display_name": "Giant Spider",
					"is_skeleton": false
				},
				{
					"data_path": "res://data/enemies/wolf.tres",
					"sprite_path": "res://Sprite folders grab bag/wolf_moving.png",
					"h_frames": 6,
					"v_frames": 1,
					"display_name": "Wolf",
					"is_skeleton": false
				},
				{
					"data_path": "res://data/enemies/human_bandit.tres",
					"sprite_path": "res://Sprite folders grab bag/3x4humanbandit.png",
					"h_frames": 4,
					"v_frames": 1,
					"display_name": "Bandit",
					"is_skeleton": false
				}
			]
		Biome.HILLS, Biome.ROCKY:
			configs = [
				{
					"data_path": "res://data/enemies/wolf.tres",
					"sprite_path": "res://Sprite folders grab bag/wolf_moving.png",
					"h_frames": 6,
					"v_frames": 1,
					"display_name": "Wolf",
					"is_skeleton": false
				},
				{
					"data_path": "res://data/enemies/human_bandit.tres",
					"sprite_path": "res://Sprite folders grab bag/3x4humanbandit.png",
					"h_frames": 4,
					"v_frames": 1,
					"display_name": "Bandit",
					"is_skeleton": false
				}
			]
		Biome.PLAINS:
			configs = [
				{
					"data_path": "res://data/enemies/wolf.tres",
					"sprite_path": "res://Sprite folders grab bag/wolf_moving.png",
					"h_frames": 6,
					"v_frames": 1,
					"display_name": "Wolf",
					"is_skeleton": false
				},
				{
					"data_path": "res://data/enemies/human_bandit.tres",
					"sprite_path": "res://Sprite folders grab bag/3x4humanbandit.png",
					"h_frames": 4,
					"v_frames": 1,
					"display_name": "Bandit",
					"is_skeleton": false
				}
			]
		_:
			# Default fallback - wolves and spiders (wildlife)
			configs = [
				{
					"data_path": "res://data/enemies/wolf.tres",
					"sprite_path": "res://Sprite folders grab bag/wolf_moving.png",
					"h_frames": 6,
					"v_frames": 1,
					"display_name": "Wolf",
					"is_skeleton": false
				},
				{
					"data_path": "res://data/enemies/giant_spider.tres",
					"sprite_path": "res://Sprite folders grab bag/evilspider.png",
					"h_frames": 1,
					"v_frames": 1,
					"display_name": "Giant Spider",
					"is_skeleton": false
				}
			]

	# Return random config from available options
	return configs[rng.randi() % configs.size()]


## Spawn wild fireplace (15% chance)
func _spawn_fireplace() -> void:
	if rng.randf() > fireplace_chance:
		return

	var pos := _get_random_content_position()

	# Create rest spot fireplace
	var fireplace := Node3D.new()
	fireplace.name = "WildFireplace"
	fireplace.position = pos
	fireplace.add_to_group("rest_spot")
	fireplace.add_to_group("interactable")

	# Fire pit stones
	for i in range(6):
		var angle := (float(i) / 6.0) * TAU
		var stone := CSGBox3D.new()
		stone.size = Vector3(0.4, 0.3, 0.4)
		stone.position = Vector3(cos(angle) * 0.6, 0.15, sin(angle) * 0.6)
		stone.material = rock_material
		stone.use_collision = true
		fireplace.add_child(stone)

	# Fire glow
	var fire := CSGSphere3D.new()
	fire.radius = 0.3
	fire.position = Vector3(0, 0.2, 0)
	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.5, 0.1)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.4, 0.0)
	fire_mat.emission_energy_multiplier = 2.0
	fire.material = fire_mat
	fireplace.add_child(fire)

	# Light
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 1.5
	light.omni_range = 10.0
	light.position = Vector3(0, 1.0, 0)
	fireplace.add_child(light)

	# Rest spot metadata
	fireplace.set_meta("rest_type", "wild_fireplace")
	fireplace.set_meta("display_name", "Wild Campfire")

	add_child(fireplace)
	print("[WildernessRoom] Spawned wild fireplace at %s" % pos)


## Spawn traveling merchant (rare encounter)
func _spawn_traveling_merchant() -> void:
	if rng.randf() > traveling_merchant_chance:
		return

	var pos := _get_random_content_position()

	# Use the TravelingMerchant class
	traveling_merchant = TravelingMerchant.spawn_merchant(self, pos)
	if traveling_merchant:
		# Add to compass POI group so it shows on compass
		traveling_merchant.add_to_group("compass_poi")
		# Set required meta for compass tracking
		traveling_merchant.set_meta("poi_id", "traveling_merchant_%d" % rng.randi())
		traveling_merchant.set_meta("poi_type", "merchant")
		traveling_merchant.set_meta("poi_icon", "$")  # Dollar sign for merchant
		traveling_merchant.set_meta("poi_color", Color(1.0, 0.85, 0.2))  # Gold color
		traveling_merchant.set_meta("display_name", traveling_merchant.get_display_name())
		print("[WildernessRoom] Spawned traveling merchant '%s' at %s" % [
			traveling_merchant.get_display_name(), pos
		])


## Create boundary props (trees/rocks at edges to indicate room boundary)
func _create_boundary_props() -> void:
	var half_size := room_size / 2.0
	var edge_offset := half_size - 5.0

	# Add dense trees near edges (creates enclosed feeling)
	# Only for biomes with trees (forest, swamp)
	if biome == Biome.FOREST or biome == Biome.SWAMP:
		for side in range(4):
			for i in range(10):  # More trees at boundary
				var pos: Vector3
				var offset := rng.randf_range(-half_size + 10, half_size - 10)

				match side:
					0:  # North
						pos = Vector3(offset, 0, -edge_offset + rng.randf_range(-3, 3))
					1:  # South
						pos = Vector3(offset, 0, edge_offset + rng.randf_range(-3, 3))
					2:  # East
						pos = Vector3(edge_offset + rng.randf_range(-3, 3), 0, offset)
					3:  # West
						pos = Vector3(-edge_offset + rng.randf_range(-3, 3), 0, offset)

				var tree := _create_tree()
				tree.position = pos
				add_child(tree)

	# For other biomes, add ground decoration at edges
	else:
		for side in range(4):
			for i in range(6):
				var pos: Vector3
				var offset := rng.randf_range(-half_size + 10, half_size - 10)

				match side:
					0:  # North
						pos = Vector3(offset, 0, -edge_offset + rng.randf_range(-3, 3))
					1:  # South
						pos = Vector3(offset, 0, edge_offset + rng.randf_range(-3, 3))
					2:  # East
						pos = Vector3(edge_offset + rng.randf_range(-3, 3), 0, offset)
					3:  # West
						pos = Vector3(-edge_offset + rng.randf_range(-3, 3), 0, offset)

				var decor := _create_rock()  # Ground decoration sprite
				decor.position = pos
				add_child(decor)

	# Add mountain blocks along edges bordering impassable terrain
	_create_mountain_barriers()


## Create 3D rocky mountain blocks along edges that border impassable terrain
func _create_mountain_barriers() -> void:
	var half_size := room_size / 2.0

	# Check each direction for impassable adjacent cells
	# Direction mappings: 0=North (+Y in grid, -Z in 3D), 1=South, 2=East, 3=West
	var directions := [
		{"dir": 0, "offset": Vector2i(0, 1), "edge_z": -half_size, "axis": "x"},   # North
		{"dir": 1, "offset": Vector2i(0, -1), "edge_z": half_size, "axis": "x"},   # South
		{"dir": 2, "offset": Vector2i(1, 0), "edge_x": half_size, "axis": "z"},    # East
		{"dir": 3, "offset": Vector2i(-1, 0), "edge_x": -half_size, "axis": "z"}   # West
	]

	for dir_data: Dictionary in directions:
		# Skip the direction the player entered from - don't block their return path
		if entry_direction >= 0 and dir_data["dir"] == entry_direction:
			print("[WildernessRoom] Skipping barrier on %s edge (player entry direction)" % [
				["North", "South", "East", "West"][dir_data["dir"]]
			])
			continue

		var adjacent_coords: Vector2i = grid_coords + dir_data["offset"]

		# Check if adjacent cell is impassable
		if not WorldData.is_passable(adjacent_coords):
			_spawn_mountain_wall(dir_data)
			print("[WildernessRoom] Added mountain barrier on %s edge (adjacent cell %s is impassable)" % [
				["North", "South", "East", "West"][dir_data["dir"]],
				adjacent_coords
			])


## Spawn a wall of mountain blocks along an edge
func _spawn_mountain_wall(dir_data: Dictionary) -> void:
	var half_size := room_size / 2.0
	var block_spacing := 8.0  # Space between mountain blocks
	var num_blocks := int(room_size / block_spacing) + 1

	for i in range(num_blocks):
		var offset := -half_size + i * block_spacing + rng.randf_range(-2, 2)
		var pos: Vector3

		if dir_data["axis"] == "x":
			# North or South edge
			var edge_z: float = dir_data["edge_z"]
			pos = Vector3(offset, 0, edge_z + sign(edge_z) * -3.0)  # Slightly inside the room
		else:
			# East or West edge
			var edge_x: float = dir_data["edge_x"]
			pos = Vector3(edge_x + sign(edge_x) * -3.0, 0, offset)

		var mountain := _create_mountain_block()
		mountain.position = pos
		add_child(mountain)


## Rock textures for impassable mountain terrain
const MOUNTAIN_ROCK_TEXTURES := [
	"res://Sprite folders grab bag/impass_rock.png",
	"res://Sprite folders grab bag/impass_rock2.png"
]


## Create a single 3D mountain/rock block
func _create_mountain_block() -> Node3D:
	var mountain := Node3D.new()
	mountain.name = "MountainBlock"

	# Create the main rock mesh (irregular box shape)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()

	# Random size for variety
	var width := rng.randf_range(6.0, 12.0)
	var height := rng.randf_range(8.0, 18.0)
	var depth := rng.randf_range(5.0, 10.0)
	box.size = Vector3(width, height, depth)
	mesh_instance.mesh = box

	# Rocky material with texture
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.95
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 style

	# Load random rock texture
	var tex_path: String = MOUNTAIN_ROCK_TEXTURES[rng.randi() % MOUNTAIN_ROCK_TEXTURES.size()]
	var rock_tex: Texture2D = load(tex_path)
	if rock_tex:
		mat.albedo_texture = rock_tex
		# Scale UV to tile texture across the rock face
		mat.uv1_scale = Vector3(width / 4.0, height / 4.0, depth / 4.0)
	else:
		# Fallback to gray color if texture fails to load
		mat.albedo_color = Color(0.4, 0.38, 0.35)

	mesh_instance.material_override = mat

	# Position so bottom is at ground level
	mesh_instance.position.y = height / 2.0

	# Random rotation for variety
	mountain.rotation_degrees.y = rng.randf_range(-15, 15)

	mountain.add_child(mesh_instance)

	# Add collision so player can't walk through
	var static_body := StaticBody3D.new()
	static_body.collision_layer = 1
	static_body.collision_mask = 0

	var col_shape := CollisionShape3D.new()
	var col_box := BoxShape3D.new()
	col_box.size = Vector3(width, height, depth)
	col_shape.shape = col_box
	col_shape.position.y = height / 2.0

	static_body.add_child(col_shape)
	mountain.add_child(static_body)

	return mountain


## Get random position in content area (avoiding edges)
func _get_random_content_position() -> Vector3:
	var margin := 20.0  # Stay away from edges
	var half_size := room_size / 2.0 - margin
	return Vector3(
		rng.randf_range(-half_size, half_size),
		0,
		rng.randf_range(-half_size, half_size)
	)


## Get random position for props (can be closer to edges)
## On road cells, avoids the road area
func _get_random_prop_position() -> Vector3:
	var margin := 10.0
	var half_size := room_size / 2.0 - margin

	# If not a road cell, use full area
	if not is_road_cell:
		return Vector3(
			rng.randf_range(-half_size, half_size),
			0,
			rng.randf_range(-half_size, half_size)
		)

	# On road cells, try to avoid the road area
	var max_attempts := 10
	var road_half_width: float = road_width / 2.0 + 2.0  # Add buffer

	for i in range(max_attempts):
		var pos := Vector3(
			rng.randf_range(-half_size, half_size),
			0,
			rng.randf_range(-half_size, half_size)
		)

		# Check if position is on the road
		var on_road := false

		# Check road directions
		var north_road := WorldData.is_road(grid_coords + Vector2i(0, 1))
		var south_road := WorldData.is_road(grid_coords + Vector2i(0, -1))
		var east_road := WorldData.is_road(grid_coords + Vector2i(1, 0))
		var west_road := WorldData.is_road(grid_coords + Vector2i(-1, 0))

		# North-South road
		if (north_road or south_road) and abs(pos.x) < road_half_width:
			on_road = true

		# East-West road
		if (east_road or west_road) and abs(pos.z) < road_half_width:
			on_road = true

		if not on_road:
			return pos

	# Fallback - return position away from center
	var side: int = rng.randi() % 4
	match side:
		0:  # Northeast quadrant
			return Vector3(rng.randf_range(road_half_width + 5, half_size), 0, rng.randf_range(-half_size, -road_half_width - 5))
		1:  # Southeast quadrant
			return Vector3(rng.randf_range(road_half_width + 5, half_size), 0, rng.randf_range(road_half_width + 5, half_size))
		2:  # Southwest quadrant
			return Vector3(rng.randf_range(-half_size, -road_half_width - 5), 0, rng.randf_range(road_half_width + 5, half_size))
		_:  # Northwest quadrant
			return Vector3(rng.randf_range(-half_size, -road_half_width - 5), 0, rng.randf_range(-half_size, -road_half_width - 5))


## Spawn signposts on road cells pointing to destinations
func _spawn_signposts_if_road() -> void:
	if not is_road_cell:
		return

	var half_size: float = room_size / 2.0
	var signpost_distance: float = half_size - 15.0  # Place near edge but not at edge

	# Check each direction for road connections and get destination names
	var directions: Array[Dictionary] = [
		{"dir": Vector2i(0, 1), "pos": Vector3(0, 0, -signpost_distance), "rot": 0.0, "name": "North"},
		{"dir": Vector2i(0, -1), "pos": Vector3(0, 0, signpost_distance), "rot": PI, "name": "South"},
		{"dir": Vector2i(1, 0), "pos": Vector3(signpost_distance, 0, 0), "rot": -PI / 2.0, "name": "East"},
		{"dir": Vector2i(-1, 0), "pos": Vector3(-signpost_distance, 0, 0), "rot": PI / 2.0, "name": "West"}
	]

	for dir_data: Dictionary in directions:
		var adjacent: Vector2i = grid_coords + dir_data["dir"]

		# Only add signpost if there's a road in that direction
		if not WorldData.is_road(adjacent):
			continue

		# Find the destination in that direction (nearest named location)
		var destination: String = _find_destination_in_direction(dir_data["dir"])
		if destination.is_empty():
			destination = dir_data["name"]  # Fallback to compass direction

		var signpost := _create_signpost(destination)
		signpost.position = dir_data["pos"]
		signpost.rotation.y = dir_data["rot"]
		add_child(signpost)
		signposts.append(signpost)

	if signposts.size() > 0:
		print("[WildernessRoom] Spawned %d signposts" % signposts.size())


## Find the nearest named destination in a given direction
func _find_destination_in_direction(direction: Vector2i) -> String:
	var check_coords: Vector2i = grid_coords
	var max_search: int = 10  # Search up to 10 cells in that direction

	for i in range(max_search):
		check_coords = check_coords + direction

		# Get cell data
		var cell: WorldData.CellData = WorldData.get_cell(check_coords)
		if not cell:
			break

		# If not passable, stop searching
		if not cell.is_passable:
			break

		# If has a location name, return it
		if cell.location_name != "":
			return cell.location_name

	return ""  # No destination found


## Create a signpost pointing to a destination
func _create_signpost(destination: String) -> Node3D:
	var signpost := Node3D.new()
	signpost.name = "Signpost_" + destination.replace(" ", "_")

	# Wooden post
	var post := CSGCylinder3D.new()
	post.name = "Post"
	post.radius = 0.15
	post.height = 2.5
	post.sides = 6
	post.position = Vector3(0, 1.25, 0)

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.4, 0.25, 0.15)  # Dark wood
	wood_mat.roughness = 0.9
	post.material = wood_mat
	signpost.add_child(post)

	# Sign board (angled)
	var board := CSGBox3D.new()
	board.name = "Board"
	board.size = Vector3(1.5, 0.4, 0.1)
	board.position = Vector3(0.5, 2.0, 0)
	board.rotation_degrees = Vector3(0, 0, -10)  # Slight angle

	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.5, 0.35, 0.2)  # Lighter wood
	board_mat.roughness = 0.85
	board.material = board_mat
	signpost.add_child(board)

	# Text label (3D text)
	var label := Label3D.new()
	label.name = "DestinationLabel"
	label.text = destination
	label.font_size = 32
	label.pixel_size = 0.01
	label.position = Vector3(0.5, 2.0, 0.06)
	label.rotation_degrees = Vector3(0, 0, -10)
	label.modulate = Color(0.1, 0.05, 0.0)  # Dark text
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false
	signpost.add_child(label)

	# Add collision for interactability (could add inspect prompt later)
	var collision := StaticBody3D.new()
	collision.collision_layer = 1
	collision.collision_mask = 0

	var col_shape := CollisionShape3D.new()
	var col_box := BoxShape3D.new()
	col_box.size = Vector3(0.4, 2.5, 0.4)
	col_shape.shape = col_box
	col_shape.position = Vector3(0, 1.25, 0)
	collision.add_child(col_shape)
	signpost.add_child(collision)

	return signpost


## Get room center position
func get_center() -> Vector3:
	return global_position


## Check if position is within room bounds
func contains_point(world_pos: Vector3) -> bool:
	var local_pos := world_pos - global_position
	var half := room_size / 2.0
	return abs(local_pos.x) <= half and abs(local_pos.z) <= half


# =============================================================================
# SEAMLESS STREAMING SUPPORT
# =============================================================================

## Get the world position for this room based on hex coordinates
## Used by WorldManager to position chunks correctly
static func position_for_hex(hex_coords: Vector2i) -> Vector3:
	return WorldData.axial_to_world(hex_coords)


## Enable seamless mode (disables edge triggers, WorldManager handles transitions)
func set_seamless_mode(enabled: bool) -> void:
	seamless_mode = enabled

	# In seamless mode, we might want to hide/show edge triggers visually
	if enabled:
		# Disable edge trigger collision
		for dir: int in edges:
			var edge: RoomEdge = edges[dir]
			if edge:
				edge.set_deferred("monitoring", false)
	else:
		# Re-enable edge trigger collision
		for dir: int in edges:
			var edge: RoomEdge = edges[dir]
			if edge:
				edge.set_deferred("monitoring", true)


## Reset the room for reuse (called by WorldManager when recycling chunks)
func _reset_for_reuse() -> void:
	# Clear generated content
	_clear_content()

	# Reset state
	grid_coords = Vector2i.ZERO
	entry_direction = -1
	room_seed = 0
	seamless_mode = false


## Clear all generated content (for chunk recycling)
func _clear_content() -> void:
	# Clear hand-placed cell if present
	if hand_placed_cell and is_instance_valid(hand_placed_cell):
		hand_placed_cell.queue_free()
	hand_placed_cell = null

	# Clear ruins
	for ruin: Node3D in ruins:
		if is_instance_valid(ruin):
			ruin.queue_free()
	ruins.clear()

	# Clear cursed totems
	for totem in cursed_totems:
		if is_instance_valid(totem):
			totem.queue_free()
	cursed_totems.clear()

	# Clear dungeon entrance
	if dungeon_entrance and is_instance_valid(dungeon_entrance):
		dungeon_entrance.queue_free()
	dungeon_entrance = null

	# Clear enemies
	for enemy: Node3D in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()

	# Clear props
	for prop: Node3D in props:
		if is_instance_valid(prop):
			prop.queue_free()
	props.clear()

	# Clear traveling merchant
	if traveling_merchant and is_instance_valid(traveling_merchant):
		traveling_merchant.queue_free()
	traveling_merchant = null

	# Clear signposts
	for signpost: Node3D in signposts:
		if is_instance_valid(signpost):
			signpost.queue_free()
	signposts.clear()

	# Clear edges
	for dir: int in edges:
		var edge: RoomEdge = edges[dir]
		if edge and is_instance_valid(edge):
			edge.queue_free()
	edges.clear()

	# Remove all children except persistent ones
	for child in get_children():
		if child.name in ["Ground", "DirtRoad", "WorldEnvironment", "Sun", "InvisibleWalls", "SpawnPoints"]:
			child.queue_free()


## Get the danger level for this chunk (for encounter system)
func get_danger_level() -> float:
	var base_danger := 1.0

	# Biome modifiers
	match biome:
		Biome.SWAMP:
			base_danger *= 1.3  # Swamps are more dangerous
		Biome.ROCKY:
			base_danger *= 1.2  # Rocky terrain has ambush spots
		Biome.FOREST:
			base_danger *= 1.1  # Forests can hide enemies
		Biome.PLAINS:
			base_danger *= 0.9  # Open terrain is safer

	# Road safety - roads are patrolled
	if is_road_cell:
		base_danger *= 0.5  # 50% safer on roads

	return base_danger


## Check if this chunk has a location (town, dungeon, etc.)
func has_location() -> bool:
	var cell: WorldData.CellData = WorldData.get_cell(grid_coords)
	if cell:
		return cell.location_type != WorldData.LocationType.NONE
	return false


## Get the location ID if this chunk has one
func get_location_id() -> String:
	var cell: WorldData.CellData = WorldData.get_cell(grid_coords)
	if cell:
		return cell.location_id
	return ""


## Get the location type if this chunk has one
func get_location_type() -> WorldData.LocationType:
	var cell: WorldData.CellData = WorldData.get_cell(grid_coords)
	if cell:
		return cell.location_type
	return WorldData.LocationType.NONE
