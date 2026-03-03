## wilderness_room.gd - Procedural wilderness room generator
## Creates outdoor areas with ruins, dungeon entrances, and environmental props
## Each room is 100x100 units with full-wall edge triggers
class_name WildernessRoom
extends Node3D

## Zone ID for quest tracking
const ZONE_ID := "open_world"

signal room_generated(room: WildernessRoom)
signal edge_triggered(direction: int)  # CellEdge.Direction

## Seamless streaming mode - when true, edge triggers are disabled (CellStreamer handles transitions)
var seamless_mode: bool = false

## Room configuration
@export var room_size: float = 100.0
@export var room_seed: int = 0  # 0 = random

## Biome types
enum Biome { FOREST, PLAINS, SWAMP, HILLS, ROCKY }
@export var biome: Biome = Biome.FOREST

## Static texture cache - loaded once, reused across all instances
## This prevents repeated load() calls that cause stutter
static var _grass_textures: Array[Texture2D] = []
static var _tree_textures_forest: Array[Texture2D] = []
static var _tree_textures_swamp: Array[Texture2D] = []
static var _tree_textures_plains: Array[Texture2D] = []
static var _textures_initialized: bool = false

## PERFORMANCE: General-purpose texture cache for any path
static var _texture_cache: Dictionary = {}

## Ancient statue spawn limit - only 15 can exist in the entire world
static var _statues_spawned: int = 0
const MAX_STATUES: int = 15

## Tile template scenes for biome-based tile selection
## Maps Biome enum to array of scene paths for hand-crafted tile variations
const TILE_TEMPLATES: Dictionary = {
	Biome.FOREST: [
		"res://scenes/wilderness/tile_forest_01.tscn",
		"res://scenes/wilderness/tile_forest_02.tscn"
	],
	Biome.PLAINS: [
		"res://scenes/wilderness/tile_plains_01.tscn",
		"res://scenes/wilderness/tile_plains_02.tscn"
	],
	Biome.SWAMP: [
		"res://scenes/wilderness/tile_swamp_01.tscn"
	],
	Biome.HILLS: [
		"res://scenes/wilderness/tile_plains_01.tscn"  # Fallback to plains
	],
	Biome.ROCKY: [
		"res://scenes/wilderness/tile_plains_02.tscn"  # Fallback to plains
	]
}

## 3D tree models for decorative (non-harvestable) trees
const TREE_3D_MODELS: Array[String] = [
	"res://assets/models/trees/big_fabulous_tree_001.fbx",
	"res://assets/models/trees/fabulous_tree_001.fbx",
	"res://assets/models/trees/fir_001.fbx",
	"res://assets/models/trees/tree_001.fbx"
]

## 3D mushroom models for decorative (non-harvestable) mushrooms
const MUSHROOM_3D_MODELS: Array[String] = [
	"res://assets/models/mushrooms/fabulous_mushroom_001.fbx",
	"res://assets/models/mushrooms/fabulous_mushroom_002.fbx",
	"res://assets/models/mushrooms/fabulous_mushroom_003.fbx",
	"res://assets/models/mushrooms/fabulous_mushroom_004.fbx"
]

## Content settings (from plan: 1-3 ruins, 0-1 dungeons at 30%)
@export var min_ruins: int = 1
@export var max_ruins: int = 3
@export var fireplace_chance: float = 0.15
@export var traveling_merchant_chance: float = 0.04  # 4% chance per room (rare encounter)
@export var enemy_count_min: int = 4  # Base enemies per wilderness cell (increased for danger)
@export var enemy_count_max: int = 10  # Max base enemies per cell (scales with danger level)
@export var cursed_totem_chance: float = 0.05  # 5% chance for cursed totem near ruins (reduced to prevent skeleton spam)

## Road visualization settings
@export var road_width: float = 8.0  # Width of dirt road
@export var road_prop_density_multiplier: float = 0.3  # Reduce props to 30% on roads

## Terrain settings (Daggerfall-style discrete heights)
@export var use_heightmap: bool = true  # Daggerfall-style stepped terrain

## Terrain height data for prop placement (stored after generation)
var _terrain_heights: PackedFloat32Array

## Room grid coordinates (set by SceneManager)
var grid_coords: Vector2i = Vector2i.ZERO

## Direction player entered from (-1 = unknown, 0=N, 1=S, 2=E, 3=W)
## Used to prevent mountain barriers from blocking the return path
var entry_direction: int = -1

## Generated content references
var edges: Dictionary = {}  # Direction -> boundary info
var ruins: Array[Node3D] = []
var cursed_totems: Array[CursedTotem] = []  # Skeleton spawners near ruins
var enemies: Array[Node3D] = []
var props: Array[Node3D] = []
var traveling_merchant: TravelingMerchant = null
var spock_easter_egg: SpockEasterEgg = null  # Rare easter egg NPC
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


## Initialize static texture cache (called once per game session)
static func _init_texture_cache() -> void:
	if _textures_initialized:
		return
	_textures_initialized = true

	# Grass textures
	var grass_paths: Array[String] = [
		"res://assets/sprites/environment/ground/grassland_1.png",
		"res://assets/sprites/environment/ground/grassland_2.png",
		"res://assets/sprites/environment/ground/grassland_3.png"
	]
	for path: String in grass_paths:
		if ResourceLoader.exists(path):
			_grass_textures.append(load(path) as Texture2D)

	# Forest tree textures (autumn trees)
	var forest_tree_paths: Array[String] = [
		"res://assets/sprites/environment/trees/autumn_tree_1.png",
		"res://assets/sprites/environment/trees/autumn_tree_2.png"
	]
	for path: String in forest_tree_paths:
		if ResourceLoader.exists(path):
			_tree_textures_forest.append(load(path) as Texture2D)

	# Swamp tree textures
	var swamp_tree_paths: Array[String] = [
		"res://assets/sprites/environment/trees/swamp_tree1.png",
		"res://assets/sprites/environment/trees/swamp_tree2.png",
		"res://assets/sprites/environment/trees/swamp_fallen_1.png",
		"res://assets/sprites/environment/trees/swamp_fallen_2.png"
	]
	for path: String in swamp_tree_paths:
		if ResourceLoader.exists(path):
			_tree_textures_swamp.append(load(path) as Texture2D)

	# Plains tree textures (same as forest)
	_tree_textures_plains = _tree_textures_forest.duplicate()

	print("[WildernessRoom] Texture cache initialized: %d grass, %d forest trees, %d swamp trees" % [
		_grass_textures.size(), _tree_textures_forest.size(), _tree_textures_swamp.size()])


## PERFORMANCE: Get a cached texture by path (avoids repeated load() calls)
static func _get_cached_texture(path: String) -> Texture2D:
	if not _texture_cache.has(path):
		if ResourceLoader.exists(path):
			_texture_cache[path] = load(path)
		else:
			push_warning("[WildernessRoom] Texture not found: %s" % path)
			return null
	return _texture_cache[path]


func _ready() -> void:
	add_to_group("wilderness_room")


func _process(_delta: float) -> void:
	pass


## Generate the room with given seed
func generate(seed_value: int = 0, coords: Vector2i = Vector2i.ZERO) -> void:
	# Initialize texture cache once (static, shared across all rooms)
	_init_texture_cache()

	grid_coords = coords
	room_seed = seed_value if seed_value != 0 else randi()

	rng = RandomNumberGenerator.new()
	rng.seed = room_seed

	# Check terrain type - don't generate land over water
	if WorldGrid.is_in_bounds(coords):
		var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(coords)
		if cell_info:
			# WATER cells: flat water surface only
			if cell_info.terrain == WorldGrid.Terrain.WATER:
				_create_water_cell()
				room_generated.emit(self)
				return
			# COAST cells: sandy beach with water on water-adjacent edges
			if cell_info.terrain == WorldGrid.Terrain.COAST:
				_create_coast_cell(coords)
				room_generated.emit(self)
				return

	# Check if this cell has a hand-crafted scene (scene_path set in WorldGrid)
	# If so, skip procedural content spawning entirely - the hand-crafted scene handles everything
	var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(coords)
	var is_handcrafted: bool = cell_info != null and cell_info.scene_path != ""
	if is_handcrafted:
		print("[WildernessRoom] Skipping procedural content for hand-crafted cell %s (%s)" % [
			coords, cell_info.location_name])
		room_generated.emit(self)
		return

	# Check if this cell is covered by another scene's physical area
	# (e.g., Elder Moor is 242x219 units at (0,0), so cells (1,0) and (0,1) fall within its bounds)
	# If covered, we still generate terrain/trees but skip enemies/ruins/dungeons
	var is_covered_by_handcrafted: bool = false
	var coverage: Dictionary = WorldGrid.is_covered_by_scene(coords)
	if coverage.get("covered", false):
		is_covered_by_handcrafted = true
		print("[WildernessRoom] Cell %s covered by %s - will generate terrain but skip enemies/ruins" % [
			coords, coverage.get("by_location", "unknown")])

	# Check if this is a road cell
	is_road_cell = WorldGrid.is_road(coords)

	print("[WildernessRoom] Generating room at %s with seed %d, biome: %s, is_road: %s, seamless: %s, covered: %s" % [
		coords, room_seed, Biome.keys()[biome], is_road_cell, seamless_mode, is_covered_by_handcrafted
	])

	_setup_materials()
	_create_ground()
	_create_road_if_needed()  # Add dirt road on road cells

	# Only create environment and edges when NOT in seamless mode
	# In seamless mode, the main scene provides lighting and CellStreamer handles boundaries
	if not seamless_mode:
		_create_sky_environment()
		_create_edges()

	_create_spawn_points()  # Directional spawn points for cell transitions

	# ALWAYS spawn terrain/environment (trees, grass, props)
	_spawn_environment()
	_create_boundary_props()
	_create_edge_transitions()  # Blend terrain at edges with adjacent biomes

	# SKIP enemies/ruins/dungeons if covered by hand-crafted zone
	if not is_covered_by_handcrafted:
		_spawn_ruins()
		_spawn_cursed_totems()  # Skeleton spawners near ruins
		_spawn_enemies()
		_spawn_fireplace()
		_spawn_traveling_merchant()
		_spawn_spock_easter_egg()  # Rare Spock easter egg
		_spawn_signposts_if_road()  # Add signposts pointing to destinations

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
	var stone_tex: Texture2D = load("res://assets/textures/environment/walls/stonewall.png")
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
## When use_heightmap is true, creates terrain with noise-based height variation
## Cells adjacent to towns/hand-crafted scenes use flat ground as a buffer zone
func _create_ground() -> void:
	var use_terrain: bool = use_heightmap and not is_road_cell and not _is_adjacent_to_scene()

	if use_terrain:
		_create_heightmap_terrain()
	else:
		_create_flat_ground()

	# Spawn environmental props on the ground
	_spawn_ground_props()


## Check if this cell is adjacent to a hand-crafted scene (town, dungeon, etc.)
## Used to create flat buffer zones around towns
func _is_adjacent_to_scene() -> bool:
	var neighbors: Array[Vector2i] = [
		grid_coords + Vector2i(0, -1),   # North
		grid_coords + Vector2i(0, 1),    # South
		grid_coords + Vector2i(1, 0),    # East
		grid_coords + Vector2i(-1, 0),   # West
		grid_coords + Vector2i(1, -1),   # Northeast
		grid_coords + Vector2i(-1, -1),  # Northwest
		grid_coords + Vector2i(1, 1),    # Southeast
		grid_coords + Vector2i(-1, 1),   # Southwest
	]

	for neighbor_coords: Vector2i in neighbors:
		var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(neighbor_coords)
		if cell_info and cell_info.scene_path != "":
			return true

	return false


## Create a water-only cell (deep water, no land)
func _create_water_cell() -> void:
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.15, 0.25, 0.40, 0.85)
	water_mat.roughness = 0.2
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var water := MeshInstance3D.new()
	water.name = "WaterSurface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(room_size, room_size)
	water.mesh = plane
	water.material_override = water_mat
	water.position = Vector3(0, -0.5, 0)
	add_child(water)

	# Create boundary walls (impassable water)
	CellEdge.create_boundary_walls(self, grid_coords, room_size)
	print("[WildernessRoom] Created water cell at %s" % grid_coords)


## Create a coastal cell (sandy beach with water on water-adjacent edges)
func _create_coast_cell(coords: Vector2i) -> void:
	_setup_materials()

	# Sandy ground material
	var sand_mat := StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.76, 0.70, 0.50)  # Sandy tan
	sand_mat.roughness = 0.95

	# Create sandy flat ground
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(room_size, 1.0, room_size)
	ground.position = Vector3(0, 0, 0)
	ground.material = sand_mat
	ground.use_collision = true
	add_child(ground)

	# Water material for edges
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.15, 0.25, 0.40, 0.85)
	water_mat.roughness = 0.2
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Check each direction for water adjacency and add water planes
	var directions: Array[Vector2i] = [
		Vector2i(-1, 0),  # West
		Vector2i(1, 0),   # East
		Vector2i(0, -1),  # North
		Vector2i(0, 1)    # South
	]

	for dir: Vector2i in directions:
		var adj: Vector2i = coords + dir
		var adj_cell: WorldGrid.CellInfo = WorldGrid.get_cell(adj)
		if adj_cell and adj_cell.terrain == WorldGrid.Terrain.WATER:
			_add_water_edge(dir, water_mat)

	# Spawn minimal vegetation (0-2 scraggly trees/palms)
	var tree_count: int = rng.randi_range(0, 2)
	for i in range(tree_count):
		var pos := Vector3(
			rng.randf_range(-room_size / 3.0, room_size / 3.0),
			0.5,
			rng.randf_range(-room_size / 3.0, room_size / 3.0)
		)
		_spawn_coastal_tree(pos)

	# Create edges where needed
	CellEdge.create_boundary_walls(self, grid_coords, room_size)
	print("[WildernessRoom] Created coast cell at %s" % coords)


## Add a water plane along a specific edge direction
func _add_water_edge(dir: Vector2i, water_mat: StandardMaterial3D) -> void:
	var water := MeshInstance3D.new()
	water.name = "WaterEdge_%d_%d" % [dir.x, dir.y]

	var plane := PlaneMesh.new()
	var edge_width: float = 20.0  # Width of water extending into the cell
	var half_size: float = room_size / 2.0

	# Position and size water based on direction
	if dir.x == -1:  # West edge
		plane.size = Vector2(edge_width, room_size)
		water.position = Vector3(-half_size + edge_width / 2.0, -0.5, 0)
	elif dir.x == 1:  # East edge
		plane.size = Vector2(edge_width, room_size)
		water.position = Vector3(half_size - edge_width / 2.0, -0.5, 0)
	elif dir.y == -1:  # North edge
		plane.size = Vector2(room_size, edge_width)
		water.position = Vector3(0, -0.5, -half_size + edge_width / 2.0)
	elif dir.y == 1:  # South edge
		plane.size = Vector2(room_size, edge_width)
		water.position = Vector3(0, -0.5, half_size - edge_width / 2.0)

	water.mesh = plane
	water.material_override = water_mat
	add_child(water)


## Spawn a scraggly coastal tree/palm
func _spawn_coastal_tree(pos: Vector3) -> void:
	# Use existing tree textures but fewer/scraggly
	if _tree_textures_forest.is_empty():
		return

	var tree_tex: Texture2D = _tree_textures_forest[rng.randi() % _tree_textures_forest.size()]
	var tree := Sprite3D.new()
	tree.name = "CoastalTree"
	tree.texture = tree_tex
	tree.pixel_size = 0.04
	tree.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tree.position = pos
	tree.modulate = Color(0.8, 0.85, 0.7)  # Slightly faded coastal look
	add_child(tree)


## Create flat ground (original method, used for roads)
func _create_flat_ground() -> void:
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	# Use exact room size (no overlap) to prevent z-fighting with adjacent cells
	ground.size = Vector3(room_size, 1.0, room_size)

	# Match terrain base level (y=0) to prevent step/cliff at cell transitions
	var y_offset: float = 0.0
	if _is_adjacent_to_scene():
		y_offset = -0.05  # Slightly lower to avoid Z-fighting with scene floors
	ground.position = Vector3(0, y_offset, 0)
	ground.use_collision = true

	# Use textured material with biome-appropriate floor texture
	var simple_mat := StandardMaterial3D.new()
	simple_mat.roughness = 0.95

	# Try to load floor texture, fall back to solid color if not found
	var floor_tex: Texture2D = _get_floor_texture()
	if floor_tex:
		simple_mat.albedo_texture = floor_tex
		simple_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 style
		simple_mat.uv1_scale = Vector3(10.0, 10.0, 1.0)  # Tile the texture across the ground
	else:
		simple_mat.albedo_color = ground_material.albedo_color

	ground.material = simple_mat
	add_child(ground)


## Create terrain with Daggerfall-style discrete height levels
func _create_heightmap_terrain() -> void:
	# Create terrain material with floor texture
	var terrain_mat := StandardMaterial3D.new()
	terrain_mat.roughness = 0.95
	terrain_mat.cull_mode = BaseMaterial3D.CULL_BACK

	# Use floor texture for terrain
	var floor_tex: Texture2D = _get_floor_texture()
	if floor_tex:
		terrain_mat.albedo_texture = floor_tex
		terrain_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 style
		terrain_mat.uv1_scale = Vector3(10.0, 10.0, 1.0)  # Tile the texture
	else:
		terrain_mat.albedo_color = ground_material.albedo_color

	# Calculate which edges need to blend to flat ground (y=0)
	# This creates smooth transitions to roads, hand-crafted scenes, and boundaries
	var blend_edges: Dictionary = {
		"north": _neighbor_is_flat(grid_coords + Vector2i(0, -1)),
		"south": _neighbor_is_flat(grid_coords + Vector2i(0, 1)),
		"east": _neighbor_is_flat(grid_coords + Vector2i(1, 0)),
		"west": _neighbor_is_flat(grid_coords + Vector2i(-1, 0)),
	}

	# Generate Daggerfall-style terrain with edge blending
	var result: Dictionary = DaggerfallTerrain.generate(
		grid_coords.x,
		grid_coords.y,
		biome,
		terrain_mat,
		blend_edges
	)

	# Store heights for prop placement
	_terrain_heights = result.heights

	# Add terrain node to scene
	var terrain_node: Node3D = result.node
	add_child(terrain_node)


## Check if a neighboring cell uses flat ground (roads, hand-crafted scenes, blocked)
func _neighbor_is_flat(coords: Vector2i) -> bool:
	var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(coords)
	if not cell_info:
		return true  # Out of bounds = treat as flat/blocked

	# Roads use flat ground
	if cell_info.is_road:
		return true

	# Hand-crafted scenes (towns, dungeons, etc.) use their own flat ground
	if cell_info.scene_path != "":
		return true

	# Blocked/impassable cells should blend to flat
	if not cell_info.passable:
		return true

	return false


## Get terrain height at a world position (relative to room center)
## Returns 0.0 if no terrain heights or position is outside bounds
func get_terrain_height_at(local_x: float, local_z: float) -> float:
	if _terrain_heights.is_empty():
		return 0.0

	return DaggerfallTerrain.get_height_at(_terrain_heights, local_x, local_z)


## Create dirt road mesh if this is a road cell
func _create_road_if_needed() -> void:
	if not is_road_cell:
		return

	var road_container := Node3D.new()
	road_container.name = "DirtRoad"
	add_child(road_container)

	# Determine road direction based on neighboring road cells
	var north_road := WorldGrid.is_road(grid_coords + Vector2i(0, 1))
	var south_road := WorldGrid.is_road(grid_coords + Vector2i(0, -1))
	var east_road := WorldGrid.is_road(grid_coords + Vector2i(1, 0))
	var west_road := WorldGrid.is_road(grid_coords + Vector2i(-1, 0))

	# Create road segments based on connections
	var half_size: float = room_size / 2.0

	# Road material - use stone floor textures for cobblestone paths
	var road_mat := StandardMaterial3D.new()
	road_mat.roughness = 1.0
	road_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Use stone floor texture for roads
	var road_tex: Texture2D = _get_road_texture()
	if road_tex:
		road_mat.albedo_texture = road_tex
		road_mat.uv1_scale = Vector3(4.0, 4.0, 1.0)  # Tile the texture
	else:
		road_mat.albedo_color = Color(0.45, 0.35, 0.25)  # Fallback brown dirt color

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
		var x: float = rng.randf_range(-half_size, half_size)
		var z: float = rng.randf_range(-half_size, half_size)
		var y: float = get_terrain_height_at(x, z)
		var pos := Vector3(x, y, z)
		_spawn_grass_prop(props_container, pos)

	# Trees
	for i in range(num_trees):
		var x: float = rng.randf_range(-half_size, half_size)
		var z: float = rng.randf_range(-half_size, half_size)
		var y: float = get_terrain_height_at(x, z)
		var pos := Vector3(x, y, z)
		_spawn_tree_prop(props_container, pos)

	# Special props based on biome
	for i in range(num_special):
		var x: float = rng.randf_range(-half_size, half_size)
		var z: float = rng.randf_range(-half_size, half_size)
		var y: float = get_terrain_height_at(x, z)
		var pos := Vector3(x, y, z)
		_spawn_special_prop(props_container, pos)


## Spawn a grass clump billboard (uses cached textures)
func _spawn_grass_prop(parent: Node3D, pos: Vector3) -> void:
	if _grass_textures.is_empty():
		return

	var tex: Texture2D = _grass_textures[rng.randi() % _grass_textures.size()]
	if not tex:
		return

	var grass := Sprite3D.new()
	grass.name = "Grass"
	grass.texture = tex
	grass.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	grass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	grass.pixel_size = rng.randf_range(0.015, 0.025)
	grass.position = pos + Vector3(0, tex.get_height() * grass.pixel_size * 0.5, 0)
	grass.modulate = _get_biome_prop_tint()
	parent.add_child(grass)


## Spawn a tree billboard based on biome (uses cached textures)
func _spawn_tree_prop(parent: Node3D, pos: Vector3) -> void:
	var tree_cache: Array[Texture2D]

	match biome:
		Biome.SWAMP:
			tree_cache = _tree_textures_swamp
		Biome.FOREST:
			tree_cache = _tree_textures_forest
		_:
			tree_cache = _tree_textures_plains

	if tree_cache.is_empty():
		return

	var tex: Texture2D = tree_cache[rng.randi() % tree_cache.size()]
	if not tex:
		return

	var tree := Sprite3D.new()
	tree.name = "Tree"
	tree.texture = tex
	tree.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tree.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Occasionally spawn super tall ancient trees (10% chance) for depth and atmosphere
	var is_giant: bool = rng.randf() < 0.10
	if is_giant:
		tree.name = "GiantTree"
		tree.pixel_size = rng.randf_range(0.08, 0.12)  # Much taller trees
		# Darker, older looking tint for ancient trees
		tree.modulate = _get_biome_prop_tint() * Color(0.7, 0.75, 0.65)
	else:
		tree.pixel_size = rng.randf_range(0.03, 0.05)
		tree.modulate = _get_biome_prop_tint()

	tree.position = pos + Vector3(0, tex.get_height() * tree.pixel_size * 0.5, 0)
	parent.add_child(tree)


## Spawn special props (gravestones for swamp/undead, flood patches, statues, etc.)
func _spawn_special_prop(parent: Node3D, pos: Vector3) -> void:
	var special_textures: Array[String] = []
	var is_statue: bool = false

	# Ancient 3D statue model (rare landmark) - DISABLED FOR NOW
	# const STATUE_MODEL := "res://assets/models/decorations/ancient_statue.glb"
	# var statue_chance: float = 0.03  # 3% of special props are 3D statues (rare)
	# if _statues_spawned < MAX_STATUES and rng.randf() < statue_chance and ResourceLoader.exists(STATUE_MODEL):
	#	_spawn_ancient_statue_3d(parent, pos)
	#	_statues_spawned += 1
	#	return

	if true:
		match biome:
			Biome.SWAMP:
				# Swamp gets gravestones, flood patches, and dead things
				special_textures = [
					"res://assets/sprites/props/dungeon/gravehead_1.png",
					"res://assets/sprites/props/dungeon/gravehead_2.png",
					"res://assets/sprites/props/dungeon/gravehead_3.png",
					"res://assets/textures/environment/floors/swamp_flood1.png",
					"res://assets/textures/environment/floors/swamp_flood2.png"
				]
			Biome.ROCKY, Biome.HILLS:
				# Rocky areas might have some fallen trees or rocks
				special_textures = [
					"res://assets/sprites/environment/trees/swamp_fallen_1.png"
				]
			Biome.FOREST, Biome.PLAINS:
				# Forest and plains statues - DISABLED FOR NOW
				return
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
	prop.modulate = _get_biome_prop_tint()

	prop.position = pos + Vector3(0, prop.texture.get_height() * prop.pixel_size * 0.5, 0)
	parent.add_child(prop)


## Spawn a 3D ancient statue model as a rare landmark
func _spawn_ancient_statue_3d(parent: Node3D, pos: Vector3) -> void:
	const STATUE_MODEL := "res://assets/models/decorations/ancient_statue.glb"

	var statue_scene: PackedScene = load(STATUE_MODEL) as PackedScene
	if not statue_scene:
		push_warning("[WildernessRoom] Failed to load ancient statue model")
		return

	var statue: Node3D = statue_scene.instantiate()
	statue.name = "AncientStatue"

	# Random scale variation (tall imposing statues)
	var scale_factor: float = rng.randf_range(1.5, 2.5)
	statue.scale = Vector3(scale_factor, scale_factor, scale_factor)

	# Random rotation for variety
	statue.rotation.y = rng.randf() * TAU

	# Position on ground
	statue.position = pos

	# Apply weathered stone material look
	_apply_stone_material(statue)

	# Add collision so players can't walk through
	var static_body := StaticBody3D.new()
	static_body.name = "StatueCollision"
	var collision_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.6 * scale_factor
	capsule.height = 2.5 * scale_factor
	collision_shape.shape = capsule
	collision_shape.position.y = capsule.height * 0.5
	static_body.add_child(collision_shape)
	statue.add_child(static_body)

	parent.add_child(statue)


## Apply weathered stone material to a 3D model
func _apply_stone_material(node: Node3D) -> void:
	# Create a weathered stone material
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.6, 0.58, 0.55)  # Gray stone color
	stone_mat.roughness = 0.9  # Very rough weathered surface
	stone_mat.metallic = 0.0
	# Add slight variation for weathering
	stone_mat.albedo_color = stone_mat.albedo_color.lerp(Color(0.5, 0.52, 0.48), rng.randf() * 0.3)

	# Apply to all mesh instances in the model
	_apply_material_recursive(node, stone_mat)


## Recursively apply material to all MeshInstance3D children
func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		mesh_instance.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)


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

	# Road cells have better visibility - push fog back
	if is_road_cell:
		env.fog_depth_begin = FOG_START * 2.5  # 20 units on roads
		env.fog_depth_end = FOG_END * 2.0      # 30 units on roads
	else:
		env.fog_depth_begin = FOG_START
		env.fog_depth_end = FOG_END

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


## Create boundary walls for impassable edges using CellEdge
func _create_edges() -> void:
	# In the new cell streaming system, edge transitions are handled by CellStreamer
	# We only create boundary walls for impassable adjacent cells
	CellEdge.create_boundary_walls(self, grid_coords, room_size)

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


## Handle player entering an edge (legacy - kept for compatibility)
func _on_edge_entered(direction: int) -> void:
	# In seamless mode, CellStreamer handles transitions - don't emit edge signals
	if seamless_mode:
		return

	print("[WildernessRoom] Edge triggered: %s" % CellEdge.Direction.keys()[direction])
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


## Set the background - BackgroundManager removed, handled by environment
func _set_background_for_biome() -> void:
	# Background now handled by WorldEnvironment settings
	pass


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

	# Observation towers DISABLED - buggy, players get stuck
	# _spawn_observation_tower(placed_positions)


## Spawn a guaranteed observation tower with loot chest
func _spawn_observation_tower(existing_positions: Array[Vector3]) -> void:
	var min_distance := 15.0
	var attempts := 0
	var max_attempts := 30
	var pos: Vector3

	while attempts < max_attempts:
		pos = _get_random_content_position()
		var valid := true

		# Check distance from other ruins
		for other_pos: Vector3 in existing_positions:
			if pos.distance_to(other_pos) < min_distance:
				valid = false
				break

		if valid:
			break
		attempts += 1

	# Load the observation tower scene
	var tower_scene: PackedScene = load("res://scenes/structures/observation_tower.tscn")
	if not tower_scene:
		push_error("[WildernessRoom] Failed to load observation_tower.tscn")
		return

	var tower: Node3D = tower_scene.instantiate()
	tower.position = pos
	add_child(tower)
	ruins.append(tower)

	# Spawn chest at the marker position
	var chest_marker: Marker3D = tower.get_node_or_null("ChestSpawnPoint")
	if chest_marker:
		var chest_id: String = "tower_chest_%d_%d" % [grid_coords.x, grid_coords.y]
		var chest: Chest = Chest.spawn_chest(
			tower,
			chest_marker.position,
			"Tower Chest",
			false,
			0,
			false,
			chest_id
		)
		if chest:
			chest.setup_with_loot(LootTables.LootTier.UNCOMMON)

	print("[WildernessRoom] Spawned Observation Tower at %s" % pos)


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


## Create a ruin structure
func _create_ruin(index: int) -> Node3D:
	var ruin := Node3D.new()
	ruin.name = "Ruin_%d" % index

	var ruin_type := rng.randi() % 4  # 0-3 only, observation towers spawn separately

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


## Spawn environmental props (trees, rocks, bushes, grass, mushrooms)
func _spawn_environment() -> void:
	var tree_count := 0
	var rock_count := 0
	var bush_count := 0
	var grass_count := 0
	var swamp_tree_count := 0
	var fallen_tree_count := 0
	var hillcross_count := 0
	var mushroom_count := 0  # Harvestable mushrooms

	match biome:
		Biome.FOREST:
			tree_count = rng.randi_range(40, 60)  # Dense forest
			bush_count = rng.randi_range(20, 35)  # Harvestable bushes
			rock_count = rng.randi_range(3, 8)    # Few rocks
			grass_count = rng.randi_range(18, 25) # Moderate grass, scattered among trees
			mushroom_count = rng.randi_range(8, 15)  # Forests have lots of mushrooms
			hillcross_count = 1 if rng.randf() < 0.05 else 0  # 5% chance for memorial cross (reduced)
		Biome.PLAINS:
			tree_count = rng.randi_range(3, 8)    # Sparse trees
			bush_count = rng.randi_range(10, 20)  # Some bushes to harvest
			rock_count = rng.randi_range(5, 10)   # Scattered rocks
			grass_count = rng.randi_range(28, 38) # Dense grass coverage
			mushroom_count = rng.randi_range(2, 5)   # Few mushrooms in open areas
			hillcross_count = 1 if rng.randf() < 0.08 else 0  # 8% chance - reduced spawn rate
		Biome.SWAMP:
			tree_count = rng.randi_range(15, 25)  # Fewer regular trees
			bush_count = rng.randi_range(15, 25)  # Harvestable
			rock_count = rng.randi_range(3, 6)    # Few rocks
			grass_count = rng.randi_range(10, 16) # Sparse grass in murky water
			mushroom_count = rng.randi_range(10, 20)  # Swamps have many mushrooms
			swamp_tree_count = rng.randi_range(4, 7)   # Standing swamp trees
			fallen_tree_count = rng.randi_range(3, 5)  # Fallen/dead trees
			hillcross_count = 1 if rng.randf() < 0.03 else 0  # 3% chance - very rare in swamps (reduced)
		Biome.HILLS:
			tree_count = rng.randi_range(8, 15)   # Moderate trees
			bush_count = rng.randi_range(10, 18)  # Harvestable
			rock_count = rng.randi_range(12, 20)  # Rocky terrain
			grass_count = rng.randi_range(15, 22) # Moderate grass
			mushroom_count = rng.randi_range(3, 7)   # Some mushrooms in shaded areas
			hillcross_count = 1 if rng.randf() < 0.06 else 0  # 6% chance - hilltop crosses (reduced)
		Biome.ROCKY:
			tree_count = rng.randi_range(2, 5)    # Very sparse
			bush_count = rng.randi_range(5, 10)   # Few bushes
			rock_count = rng.randi_range(20, 35)  # Lots of rocks
			grass_count = rng.randi_range(5, 10)  # Very sparse grass
			mushroom_count = rng.randi_range(1, 3)   # Very few mushrooms
			hillcross_count = 1 if rng.randf() < 0.04 else 0  # 4% chance - rare mountain memorial (reduced)

	# Reduce prop density on road cells
	if is_road_cell:
		tree_count = int(tree_count * road_prop_density_multiplier)
		bush_count = int(bush_count * road_prop_density_multiplier)
		rock_count = int(rock_count * road_prop_density_multiplier)
		grass_count = int(grass_count * road_prop_density_multiplier)
		mushroom_count = int(mushroom_count * road_prop_density_multiplier)
		swamp_tree_count = int(swamp_tree_count * road_prop_density_multiplier)
		fallen_tree_count = int(fallen_tree_count * road_prop_density_multiplier)
		# Hillcrosses can appear near roads (roadside memorials are thematic)

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

	# Spawn hillcrosses (memorial crosses - rare atmospheric prop)
	for i in range(hillcross_count):
		var cross := _create_hillcross()
		cross.position = _get_random_content_position()  # Use content position to keep away from edges
		add_child(cross)
		props.append(cross)
		print("[WildernessRoom] Spawned hillcross at %s" % cross.position)

	# Spawn mushrooms (harvestable without tools)
	for i in range(mushroom_count):
		var mushroom := _create_mushroom()
		mushroom.position = _get_random_prop_position()
		add_child(mushroom)
		props.append(mushroom)

	# Spawn decorative 3D trees (non-harvestable, 30-50% of harvestable tree count)
	var decorative_tree_count: int = int(tree_count * rng.randf_range(0.3, 0.5))
	for i in range(decorative_tree_count):
		var pos: Vector3 = _get_random_prop_position()
		var deco_tree: Node3D = _create_decorative_tree_3d(pos)
		add_child(deco_tree)
		props.append(deco_tree)

	# Spawn decorative 3D mushrooms near trees or in random positions
	var decorative_mushroom_count: int = int(mushroom_count * rng.randf_range(0.4, 0.6))
	for i in range(decorative_mushroom_count):
		var pos: Vector3 = _get_random_prop_position()
		var deco_mushroom: Node3D = _create_decorative_mushroom_3d(pos)
		add_child(deco_mushroom)
		props.append(deco_mushroom)


## Create a harvestable mushroom (no tool required)
func _create_mushroom() -> Node3D:
	# Use HarvestableMushroom class - can be picked with E key, no tools needed
	var mushroom := HarvestableMushroom.spawn_mushroom(self, Vector3.ZERO)
	# Remove from parent since spawn_mushroom adds it - we'll re-add it in the caller
	if mushroom.get_parent():
		mushroom.get_parent().remove_child(mushroom)
	return mushroom


## Create a harvestable tree (requires axe to harvest for wood)
func _create_tree() -> Node3D:
	# Use HarvestableTree class for proper interact() and get_interaction_prompt() support
	var tree := HarvestableTree.new()
	tree.name = "HarvestableTree"
	tree.display_name = "Tree"
	tree.yield_min = 2
	tree.yield_max = 3
	return tree


## Create a decorative 3D tree (non-harvestable, uses FBX models)
func _create_decorative_tree_3d(pos: Vector3) -> Node3D:
	var container := Node3D.new()
	container.name = "DecorativeTree3D"
	container.position = pos

	# Pick a random tree model
	var model_path: String = TREE_3D_MODELS[rng.randi() % TREE_3D_MODELS.size()]

	# Try to load the model
	if ResourceLoader.exists(model_path):
		var scene: PackedScene = load(model_path)
		if scene:
			var tree_instance: Node3D = scene.instantiate()

			# Apply random Y rotation
			tree_instance.rotation.y = rng.randf() * TAU

			# Scale appropriately
			tree_instance.scale = Vector3(0.5, 0.5, 0.5)

			container.add_child(tree_instance)

			# Add collision for trunk (StaticBody3D with cylinder shape)
			var static_body := StaticBody3D.new()
			static_body.name = "TrunkCollision"

			var collision_shape := CollisionShape3D.new()
			var cylinder := CylinderShape3D.new()
			cylinder.radius = 0.4
			cylinder.height = 3.0
			collision_shape.shape = cylinder
			collision_shape.position = Vector3(0, 1.5, 0)  # Center the cylinder vertically

			static_body.add_child(collision_shape)
			container.add_child(static_body)
	else:
		# Fallback: create a simple placeholder if model not found
		var placeholder := CSGCylinder3D.new()
		placeholder.radius = 0.3
		placeholder.height = 4.0
		placeholder.position = Vector3(0, 2.0, 0)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.25, 0.15)  # Brown trunk color
		placeholder.material = mat

		container.add_child(placeholder)

	return container


## Create a decorative 3D mushroom (non-harvestable, uses FBX models)
func _create_decorative_mushroom_3d(pos: Vector3) -> Node3D:
	var container := Node3D.new()
	container.name = "DecorativeMushroom3D"
	container.position = pos

	# Pick a random mushroom model
	var model_path: String = MUSHROOM_3D_MODELS[rng.randi() % MUSHROOM_3D_MODELS.size()]

	# Try to load the model
	if ResourceLoader.exists(model_path):
		var scene: PackedScene = load(model_path)
		if scene:
			var mushroom_instance: Node3D = scene.instantiate()

			# Apply random Y rotation
			mushroom_instance.rotation.y = rng.randf() * TAU

			# Small scale for mushrooms
			mushroom_instance.scale = Vector3(0.3, 0.3, 0.3)

			container.add_child(mushroom_instance)
	else:
		# Fallback: create a simple placeholder if model not found
		var cap := CSGSphere3D.new()
		cap.radius = 0.15
		cap.position = Vector3(0, 0.2, 0)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.2, 0.2)  # Red mushroom cap
		cap.material = mat

		var stem := CSGCylinder3D.new()
		stem.radius = 0.05
		stem.height = 0.2
		stem.position = Vector3(0, 0.1, 0)

		var stem_mat := StandardMaterial3D.new()
		stem_mat.albedo_color = Color(0.9, 0.9, 0.85)  # White stem
		stem.material = stem_mat

		container.add_child(cap)
		container.add_child(stem)

	return container


## Get tree texture based on biome
## PERFORMANCE: Uses static texture cache to avoid repeated load() calls
func _get_tree_texture() -> Texture2D:
	# Ensure cache is initialized
	_init_texture_cache()

	match biome:
		Biome.FOREST:
			# PERFORMANCE: Use cached textures instead of load()
			if _tree_textures_forest.size() > 0:
				return _tree_textures_forest[rng.randi() % _tree_textures_forest.size()]
			return load("res://assets/sprites/environment/trees/autumn_tree_1.png")
		Biome.SWAMP:
			# Use swamp trees from cache
			if _tree_textures_swamp.size() > 0:
				return _tree_textures_swamp[rng.randi() % _tree_textures_swamp.size()]
			return load("res://assets/sprites/environment/trees/autumn_tree_2.png")
		Biome.PLAINS:
			# Sparse trees - use forest tree from cache
			if _tree_textures_forest.size() > 0:
				return _tree_textures_forest[0]
			return load("res://assets/sprites/environment/trees/autumn_tree_1.png")
		_:
			# Default to first forest tree
			if _tree_textures_forest.size() > 0:
				return _tree_textures_forest[0]
			return load("res://assets/sprites/environment/trees/autumn_tree_1.png")


## Create a harvestable rock (requires pickaxe to mine for stone/iron)
## Uses rock type variants in highlands biomes
func _create_rock() -> Node3D:
	# Determine if this is a highlands area (more iron ore)
	var is_highlands: bool = (biome == Biome.ROCKY or biome == Biome.HILLS)

	# Use static factory method which handles rock type selection
	var rock := HarvestableRock.spawn_random_rock(self, Vector3.ZERO, is_highlands)
	# Remove from parent since spawn_random_rock adds it - we'll re-add it in the caller
	if rock.get_parent():
		rock.get_parent().remove_child(rock)
	return rock


## Decorative bush textures (non-harvestable)
const DECORATIVE_BUSH_TEXTURES: Array[String] = [
	"res://assets/sprites/environment/trees/bush_1.png",
	"res://assets/sprites/environment/trees/bush_2.png"
]


## Create a bush - 50% chance decorative, 50% harvestable
func _create_bush() -> Node3D:
	# 50% chance to be a decorative (non-harvestable) bush
	if rng.randf() < 0.5:
		return _create_decorative_bush()

	# Use HarvestablePlant class for proper interact() and get_interaction_prompt() support
	var plant := HarvestablePlant.spawn_random_plant(self, Vector3.ZERO)
	plant.name = "HarvestableBush"
	# Remove from parent since spawn_random_plant adds it - we'll re-add it in the caller
	if plant.get_parent():
		plant.get_parent().remove_child(plant)
	return plant


## Create a decorative bush (no interaction, just visual)
func _create_decorative_bush() -> Node3D:
	var bush := Node3D.new()
	bush.name = "DecorativeBush"

	# Pick random decorative bush texture
	# PERFORMANCE: Use cached texture instead of load()
	var tex_path: String = DECORATIVE_BUSH_TEXTURES[rng.randi() % DECORATIVE_BUSH_TEXTURES.size()]
	var bush_tex: Texture2D = _get_cached_texture(tex_path)
	if not bush_tex:
		return bush  # Return empty node if texture fails

	var sprite := Sprite3D.new()
	sprite.texture = bush_tex
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.no_depth_test = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 style

	# Bush size - similar to harvestable plants
	var base_pixel_size := 0.012
	var scale_var: float = rng.randf_range(0.8, 1.2)
	sprite.pixel_size = base_pixel_size * scale_var

	# Random Y rotation for variety
	bush.rotation_degrees.y = rng.randf_range(0, 360)

	# Position sprite so bottom is at ground level
	var approx_height: float = bush_tex.get_height() * sprite.pixel_size
	sprite.position = Vector3(0, approx_height / 2.0, 0)

	bush.add_child(sprite)

	# No collision - decorative bushes are just visual

	return bush


## Grassland texture paths for decorative grass clumps
const GRASSLAND_TEXTURES: Array[String] = [
	"res://assets/sprites/environment/ground/grassland_1.png",
	"res://assets/sprites/environment/ground/grassland_2.png",
	"res://assets/sprites/environment/ground/grassland_3.png"
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


## Hillcross model path
const HILLCROSS_MODEL_PATH := "res://assets/models/terrain/hillcross.glb"


## Create a hillcross memorial - 3D model prop
## These are medieval-style memorial crosses that add atmosphere to the wilderness
func _create_hillcross() -> Node3D:
	var cross := Node3D.new()
	cross.name = "Hillcross"

	# Load the GLB model
	if not ResourceLoader.exists(HILLCROSS_MODEL_PATH):
		push_warning("[WildernessRoom] Hillcross model not found: %s" % HILLCROSS_MODEL_PATH)
		return cross  # Return empty node

	var scene: PackedScene = load(HILLCROSS_MODEL_PATH)
	if not scene:
		push_warning("[WildernessRoom] Failed to load hillcross model")
		return cross

	var model: Node3D = scene.instantiate()

	# Random scale variation for variety (0.8 to 1.2)
	var scale_var: float = rng.randf_range(0.8, 1.2)
	model.scale = Vector3.ONE * scale_var

	# Random Y rotation
	cross.rotation_degrees.y = rng.randf_range(0, 360)

	cross.add_child(model)

	# Apply PS1-style material to the model
	_apply_hillcross_material(model)

	# Add collision for the cross (simple box approximation)
	var collision := StaticBody3D.new()
	collision.name = "HillcrossCollision"
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8 * scale_var, 3.0 * scale_var, 0.4 * scale_var)  # Tall thin box for cross
	col_shape.shape = box
	col_shape.position = Vector3(0, 1.5 * scale_var, 0)  # Center collision vertically
	collision.add_child(col_shape)
	cross.add_child(collision)

	return cross


## Apply PS1-style material to hillcross model
func _apply_hillcross_material(node: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.95
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 pixelated look

	# Stone/weathered wood color based on biome
	var base_color: Color
	match biome:
		Biome.FOREST:
			base_color = Color(0.45, 0.42, 0.38)  # Weathered gray stone
		Biome.PLAINS:
			base_color = Color(0.55, 0.50, 0.42)  # Sun-bleached stone
		Biome.SWAMP:
			base_color = Color(0.35, 0.38, 0.32)  # Mossy, damp
		Biome.HILLS:
			base_color = Color(0.50, 0.48, 0.45)  # Mountain stone
		Biome.ROCKY:
			base_color = Color(0.48, 0.46, 0.44)  # Granite gray
		_:
			base_color = Color(0.45, 0.43, 0.40)  # Default stone

	mat.albedo_color = base_color

	# Try to load stone texture for more detail
	var stone_tex: Texture2D = load("res://assets/textures/environment/walls/stonewall.png")
	if stone_tex:
		mat.albedo_texture = stone_tex
		mat.uv1_scale = Vector3(0.5, 0.5, 0.5)  # Tile texture appropriately

	# Apply material recursively to all mesh instances
	_apply_material_to_meshes(node, mat)


## Helper to apply material to all MeshInstance3D nodes recursively
func _apply_material_to_meshes(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		mi.material_override = material

	for child in node.get_children():
		_apply_material_to_meshes(child, material)


## Swamp tree textures
const SWAMP_TREE_TEXTURE := "res://assets/sprites/environment/trees/swamp_tree1.png"


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
	"res://assets/sprites/environment/trees/swamp_fallen_1.png",
	"res://assets/sprites/environment/trees/swamp_fallen_2.png"
]


## Create a harvestable fallen tree (requires axe to harvest for wood)
func _create_fallen_tree() -> Node3D:
	# Use HarvestableFallenTree class for proper interact() and get_interaction_prompt() support
	var fallen := HarvestableFallenTree.new()
	fallen.name = "HarvestableFallenTree"
	fallen.display_name = "Fallen Tree"
	fallen.yield_min = 1
	fallen.yield_max = 2
	return fallen


## Get floor texture based on biome (randomly picks from available)
## Uses only approved floor assets - NO plant/grass textures
func _get_floor_texture() -> Texture2D:
	# Only use the 5 approved floor textures across all biomes
	var textures: Array[String] = [
		"res://assets/textures/environment/floors/plains_floor1.png",
		"res://assets/textures/environment/floors/plains_floor2.png",
		"res://assets/textures/environment/floors/plains_floor3.png",
		"res://assets/textures/environment/floors/leaves_full.png",
		"res://assets/textures/environment/floors/leaves_half.png"
	]

	if textures.is_empty():
		return null

	var path: String = textures[rng.randi() % textures.size()]
	return load(path)


## Get road/cobblestone texture (randomly picks from stone floor textures)
func _get_road_texture() -> Texture2D:
	var textures: Array[String] = [
		"res://assets/textures/environment/floors/stonefloor.png",
		"res://assets/textures/environment/floors/stonefloor_2.png",
		"res://assets/textures/environment/floors/stonefloor_3.png",
		"res://assets/textures/environment/floors/stonefloor_4.png",
		"res://assets/textures/environment/floors/stonefloor_5.png",
	]

	if textures.is_empty():
		return null

	var path: String = textures[rng.randi() % textures.size()]
	if ResourceLoader.exists(path):
		return load(path)
	return null


## Extract enemy type ID from data path for ActorRegistry lookup
## e.g., "res://data/enemies/wolf.tres" -> "wolf"
func _get_enemy_type_from_data_path(data_path: String) -> String:
	if data_path.is_empty():
		return ""
	var filename: String = data_path.get_file()
	return filename.get_basename()


## Spawn actual enemies using EnemyBase.spawn_billboard_enemy
## Enemy count scales with danger level: base + (danger_level - 1) * 2
func _spawn_enemies() -> void:
	# Get danger level for scaling
	var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(grid_coords)
	var danger: int = 1
	if cell_info:
		danger = cell_info.danger_level

	# Scale enemy count with danger: base count + danger bonus
	# At danger 1: 4-10 enemies
	# At danger 5: 8-14 enemies (4 bonus)
	# At danger 10: 13-19 enemies (9 bonus)
	var danger_bonus: int = (danger - 1)
	var scaled_min: int = enemy_count_min + danger_bonus
	var scaled_max: int = enemy_count_max + danger_bonus

	# Cap at performance budget (max 20 per zone)
	scaled_max = mini(scaled_max, 20)

	var count := rng.randi_range(scaled_min, scaled_max)
	var placed_positions: Array[Vector3] = []
	var min_enemy_distance := 6.0  # Reduced from 8 to allow more enemies

	print("[WildernessRoom] Spawning %d enemies (danger %d, range %d-%d)" % [count, danger, scaled_min, scaled_max])

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

		# Apply height offset for flying enemies (bats, flaming skulls, etc.)
		var spawn_pos: Vector3 = pos
		if enemy_config.get("is_flying", false):
			spawn_pos.y += enemy_config.get("fly_height", 3.0)

		var enemy: Node = null

		# Check if this is a skeleton enemy - use specialized spawner with walk/attack sprites
		if enemy_config.get("is_skeleton", false):
			enemy = EnemyBase.spawn_skeleton_enemy(
				self,
				spawn_pos,
				enemy_config.data_path,
				danger  # Use danger level from start of function
			)
		else:
			# Check ActorRegistry for patched sprite configuration
			# This applies any Zoo patches automatically
			var sprite_path: String = enemy_config.sprite_path
			var h_frames: int = enemy_config.h_frames
			var v_frames: int = enemy_config.v_frames

			var enemy_type: String = _get_enemy_type_from_data_path(enemy_config.data_path)
			if ActorRegistry and not enemy_type.is_empty():
				var registry_config: Dictionary = ActorRegistry.get_sprite_config(enemy_type)
				if not registry_config.is_empty():
					sprite_path = registry_config.get("sprite_path", sprite_path)
					h_frames = registry_config.get("h_frames", h_frames)
					v_frames = registry_config.get("v_frames", v_frames)

			# PERFORMANCE: Use cached texture instead of load()
			var sprite_tex: Texture2D = _get_cached_texture(sprite_path)
			if not sprite_tex:
				push_warning("[WildernessRoom] Failed to load sprite: %s" % sprite_path)
				continue

			# Spawn regular billboard enemy with zone danger for stat scaling
			enemy = EnemyBase.spawn_billboard_enemy(
				self,
				spawn_pos,
				enemy_config.data_path,
				sprite_tex,
				h_frames,
				v_frames,
				danger
			)

		if enemy:
			enemies.append(enemy)
			placed_positions.append(pos)
			print("[WildernessRoom] Spawned %s at %s (zone_danger: %d)" % [enemy_config.display_name, pos, danger])

	print("[WildernessRoom] Spawned %d enemies" % enemies.size())


## Get enemy configuration based on biome AND danger level
## Returns dictionary with: data_path, sprite_path, h_frames, v_frames, display_name
## NOTE: Skeletons removed from open world - they only spawn from Cursed Totems
## Danger levels (distance from Elder Moor):
##   1-3: Basic wildlife (wolf, spider, rat, bat)
##   4-5: Mid-tier (dire wolf, goblin)
##   6-7: Dangerous (ogre, troll, tree_ent)
##   8-10: Exotic (wyvern, basilisk, abomination)
func _get_enemy_config_for_biome() -> Dictionary:
	# Get cell danger level from WorldGrid
	var cell: WorldGrid.CellInfo = WorldGrid.get_cell(grid_coords)
	var danger: int = 1
	if cell:
		danger = cell.danger_level

	var configs: Array[Dictionary] = []

	# === TIER 1: Basic enemies (danger 1-3) - Always available ===
	var tier1_configs: Array[Dictionary] = [
		{
			"data_path": "res://data/enemies/wolf.tres",
			"sprite_path": "res://assets/sprites/enemies/beasts/wolf_moving.png",
			"h_frames": 6, "v_frames": 1,
			"display_name": "Wolf", "is_skeleton": false
		},
		{
			"data_path": "res://data/enemies/giant_spider.tres",
			"sprite_path": "res://assets/sprites/enemies/beasts/spider.png",
			"h_frames": 1, "v_frames": 1,
			"display_name": "Giant Spider", "is_skeleton": false
		},
		{
			"data_path": "res://data/enemies/human_bandit.tres",
			"sprite_path": "res://assets/sprites/enemies/humanoid/human_bandit_alt.png",
			"h_frames": 4, "v_frames": 1,
			"display_name": "Bandit", "is_skeleton": false
		},
		{
			"data_path": "res://data/enemies/giant_rat.tres",
			"sprite_path": "res://assets/sprites/enemies/beasts/rat_moving_forward.png",
			"h_frames": 4, "v_frames": 1,
			"display_name": "Giant Rat", "is_skeleton": false
		},
		{
			"data_path": "res://data/enemies/bat.tres",
			"sprite_path": "res://assets/sprites/enemies/beasts/bat.png",
			"h_frames": 4, "v_frames": 1,
			"display_name": "Bat", "is_skeleton": false,
			"is_flying": true, "fly_height": 2.5
		}
	]

	# === TIER 2: Mid-tier enemies (danger 4+) ===
	var tier2_configs: Array[Dictionary] = [
		{
			"data_path": "res://data/enemies/dire_wolf.tres",
			"sprite_path": "res://assets/sprites/enemies/beasts/wolf_moving.png",
			"h_frames": 6, "v_frames": 1,
			"display_name": "Dire Wolf", "is_skeleton": false
		},
		{
			"data_path": "res://data/enemies/goblin_soldier.tres",
			"sprite_path": "res://assets/sprites/enemies/goblins/goblin_sword.png",
			"h_frames": 4, "v_frames": 2,
			"display_name": "Goblin Soldier", "is_skeleton": false
		},
		{
			"data_path": "res://data/enemies/bandit_captain.tres",
			"sprite_path": "res://assets/sprites/enemies/humanoid/human_bandit_alt.png",
			"h_frames": 4, "v_frames": 1,
			"display_name": "Bandit Captain", "is_skeleton": false
		}
	]

	# === TIER 3: Dangerous enemies (danger 6+) ===
	var tier3_configs: Array[Dictionary] = [
		{
			"data_path": "res://data/enemies/ogre.tres",
			"sprite_path": "res://assets/sprites/enemies/ogre_monster.png",
			"h_frames": 1, "v_frames": 1,
			"display_name": "Ogre", "is_skeleton": false
		},
		{
			"data_path": "res://data/enemies/troll.tres",
			"sprite_path": "res://assets/sprites/enemies/beasts/troll.png",
			"h_frames": 1, "v_frames": 1,
			"display_name": "Bridge Troll", "is_skeleton": false
		}
	]

	# === TIER 4: Exotic enemies (danger 8+) ===
	var tier4_configs: Array[Dictionary] = [
		{
			"data_path": "res://data/enemies/wyvern.tres",
			"sprite_path": "res://assets/sprites/enemies/beasts/wyvern.png",
			"h_frames": 6, "v_frames": 1,
			"display_name": "Wyvern", "is_skeleton": false,
			"is_flying": true, "fly_height": 4.0
		},
		{
			"data_path": "res://data/enemies/basilisk.tres",
			"sprite_path": "res://assets/sprites/enemies/beasts/basilisk.png",
			"h_frames": 4, "v_frames": 1,
			"display_name": "Basilisk", "is_skeleton": false
		},
		{
			"data_path": "res://data/enemies/abomination.tres",
			"sprite_path": "res://assets/sprites/abomination.png",
			"h_frames": 1, "v_frames": 1,
			"display_name": "Abomination", "is_skeleton": false
		}
	]

	# === BIOME-SPECIFIC ADDITIONS ===
	var biome_configs: Array[Dictionary] = []

	match biome:
		Biome.FOREST:
			# Forests can have tree ents at danger 5+
			if danger >= 5:
				biome_configs.append({
					"data_path": "res://data/enemies/tree_ent.tres",
					"sprite_path": "res://assets/sprites/enemies/tree_ent.png",
					"h_frames": 4, "v_frames": 4,
					"display_name": "Ancient Treant", "is_skeleton": false
				})
		Biome.SWAMP:
			# Swamps have more spiders and trolls
			tier1_configs.append({
				"data_path": "res://data/enemies/giant_spider.tres",
				"sprite_path": "res://assets/sprites/enemies/beasts/spider.png",
				"h_frames": 1, "v_frames": 1,
				"display_name": "Swamp Spider", "is_skeleton": false
			})
		Biome.HILLS, Biome.ROCKY:
			# Rocky areas have more wyverns and basilisks at high danger
			if danger >= 7:
				biome_configs.append({
					"data_path": "res://data/enemies/wyvern.tres",
					"sprite_path": "res://assets/sprites/enemies/beasts/wyvern.png",
					"h_frames": 6, "v_frames": 1,
					"display_name": "Wyvern", "is_skeleton": false,
					"is_flying": true, "fly_height": 4.0
				})
				biome_configs.append({
					"data_path": "res://data/enemies/basilisk.tres",
					"sprite_path": "res://assets/sprites/enemies/beasts/basilisk.png",
					"h_frames": 4, "v_frames": 1,
					"display_name": "Basilisk", "is_skeleton": false
				})

	# Build final pool based on danger level
	configs.append_array(tier1_configs)

	if danger >= 4:
		configs.append_array(tier2_configs)

	if danger >= 6:
		configs.append_array(tier3_configs)

	if danger >= 8:
		configs.append_array(tier4_configs)

	# Add biome-specific enemies
	configs.append_array(biome_configs)

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


## Spawn Spock easter egg (ultra rare encounter)
func _spawn_spock_easter_egg() -> void:
	# Get player level and danger level
	var player_level: int = 1
	if GameManager and GameManager.player_data:
		player_level = GameManager.player_data.level

	var danger_level: int = int(get_danger_level())

	# Check if Spock should spawn
	if not SpockEasterEgg.should_spawn(player_level, danger_level):
		return

	var pos := _get_random_content_position()

	# Spawn the Pointed-Eared Stranger
	spock_easter_egg = SpockEasterEgg.spawn_spock(self, pos)
	if spock_easter_egg:
		# Add to compass POI group
		spock_easter_egg.add_to_group("compass_poi")
		spock_easter_egg.set_meta("poi_id", "spock_stranger_%d" % rng.randi())
		spock_easter_egg.set_meta("poi_type", "npc")
		spock_easter_egg.set_meta("poi_icon", "?")  # Mystery icon
		spock_easter_egg.set_meta("poi_color", Color(0.4, 0.6, 1.0))  # Blue color
		spock_easter_egg.set_meta("display_name", "Pointed-Eared Stranger")
		print("[WildernessRoom] !!! RARE SPAWN: The Pointed-Eared Stranger has appeared at %s !!!" % pos)


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
		var adjacent_cell: WorldGrid.CellInfo = WorldGrid.get_cell(adjacent_coords)

		# Check what type of boundary to create based on terrain
		if adjacent_cell:
			if adjacent_cell.terrain == WorldGrid.Terrain.BLOCKED:
				# Mountains/blocked terrain - spawn mountain wall
				_spawn_mountain_wall(dir_data)
				print("[WildernessRoom] Added mountain barrier on %s edge (adjacent cell %s is BLOCKED)" % [
					["North", "South", "East", "West"][dir_data["dir"]],
					adjacent_coords
				])
			elif adjacent_cell.terrain == WorldGrid.Terrain.WATER or adjacent_cell.terrain == WorldGrid.Terrain.COAST:
				# Water/coast - spawn water boundary (visual only, collision handled by CellStreamer)
				_spawn_water_boundary(dir_data)
				print("[WildernessRoom] Added water boundary on %s edge (adjacent cell %s is water/coast)" % [
					["North", "South", "East", "West"][dir_data["dir"]],
					adjacent_coords
				])
		elif not WorldGrid.is_in_bounds(adjacent_coords):
			# Out of bounds - treat as blocked
			_spawn_mountain_wall(dir_data)
			print("[WildernessRoom] Added mountain barrier on %s edge (out of bounds)" % [
				["North", "South", "East", "West"][dir_data["dir"]]
			])


## Spawn a wall of mountain blocks along an edge
func _spawn_mountain_wall(dir_data: Dictionary) -> void:
	var half_size := room_size / 2.0
	var block_spacing := 5.0  # Space between mountain blocks (reduced from 8 to eliminate gaps)
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

	# Spawn rock and iron vein clusters along the mountain edge
	_spawn_mountain_edge_rocks(dir_data)


## Spawn water/coastal visuals along an edge bordering water
func _spawn_water_boundary(dir_data: Dictionary) -> void:
	var half_size := room_size / 2.0
	var water_spacing := 8.0  # Space between water visual elements
	var num_elements := int(room_size / water_spacing) + 1

	for i in range(num_elements):
		var offset := -half_size + i * water_spacing + rng.randf_range(-2, 2)
		var pos: Vector3

		if dir_data["axis"] == "x":
			# North or South edge
			var edge_z: float = dir_data["edge_z"]
			pos = Vector3(offset, -0.3, edge_z + sign(edge_z) * -2.0)  # Slightly below ground at edge
		else:
			# East or West edge
			var edge_x: float = dir_data["edge_x"]
			pos = Vector3(edge_x + sign(edge_x) * -2.0, -0.3, offset)

		# Create a simple water plane segment
		var water := _create_water_segment()
		water.position = pos
		add_child(water)

	# Spawn coastal rocks and driftwood along the water edge
	_spawn_coastal_decorations(dir_data)


## Create a single water segment for boundary visuals
func _create_water_segment() -> Node3D:
	var water := Node3D.new()
	water.name = "WaterSegment"

	# Create a flat water plane
	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.0, 8.0)
	mesh_instance.mesh = plane

	# Water material - dark blue/green tint
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.25, 0.35, 0.9)
	mat.roughness = 0.2
	mat.metallic = 0.1
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = mat

	water.add_child(mesh_instance)

	# Water doesn't need collision - CellStreamer's boundary walls handle that
	return water


## Spawn coastal decorations (rocks, driftwood) along water edges
func _spawn_coastal_decorations(dir_data: Dictionary) -> void:
	var half_size := room_size / 2.0
	# Spawn 8-15 coastal decoration clusters
	var num_clusters := rng.randi_range(8, 15)

	for _c in range(num_clusters):
		var offset := rng.randf_range(-half_size + 5.0, half_size - 5.0)
		var base_pos: Vector3

		if dir_data["axis"] == "x":
			var edge_z: float = dir_data["edge_z"]
			var depth_offset := rng.randf_range(3.0, 12.0)
			base_pos = Vector3(offset, 0, edge_z + sign(edge_z) * -depth_offset)
		else:
			var edge_x: float = dir_data["edge_x"]
			var depth_offset := rng.randf_range(3.0, 12.0)
			base_pos = Vector3(edge_x + sign(edge_x) * -depth_offset, 0, offset)

		# Spawn 2-4 decorations in this cluster
		var cluster_size := rng.randi_range(2, 4)
		for _d in range(cluster_size):
			var scatter := Vector3(
				rng.randf_range(-3.0, 3.0),
				0,
				rng.randf_range(-3.0, 3.0)
			)
			var deco_pos := base_pos + scatter
			deco_pos.x = clampf(deco_pos.x, -half_size + 2.0, half_size - 2.0)
			deco_pos.z = clampf(deco_pos.z, -half_size + 2.0, half_size - 2.0)

			# 70% small coastal rock, 30% driftwood
			if rng.randf() < 0.7:
				var rock := _create_coastal_rock()
				rock.position = deco_pos
				add_child(rock)
				props.append(rock)
			else:
				var wood := _create_driftwood()
				wood.position = deco_pos
				add_child(wood)
				props.append(wood)


## Create a small coastal rock
func _create_coastal_rock() -> Node3D:
	var rock := Node3D.new()
	rock.name = "CoastalRock"

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	var size := rng.randf_range(0.4, 1.2)
	box.size = Vector3(size, size * 0.6, size * 0.8)
	mesh.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.32)  # Gray coastal rock
	mat.roughness = 0.95
	mesh.material_override = mat
	mesh.position.y = size * 0.3

	rock.add_child(mesh)
	rock.rotation_degrees.y = rng.randf_range(0, 360)
	return rock


## Create driftwood decoration
func _create_driftwood() -> Node3D:
	var wood := Node3D.new()
	wood.name = "Driftwood"

	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rng.randf_range(0.08, 0.15)
	cyl.bottom_radius = rng.randf_range(0.1, 0.2)
	cyl.height = rng.randf_range(1.5, 3.0)
	mesh.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.22, 0.18)  # Weathered wood
	mat.roughness = 0.9
	mesh.material_override = mat

	# Lay the wood on its side
	mesh.rotation_degrees.z = 90
	mesh.position.y = 0.1

	wood.add_child(mesh)
	wood.rotation_degrees.y = rng.randf_range(0, 360)
	return wood


## Rock textures for impassable mountain terrain
const MOUNTAIN_ROCK_TEXTURES := [
	"res://assets/textures/environment/walls/impass_rock.png",
	"res://assets/textures/environment/walls/impass_rock2.png"
]


## Spawn clusters of rocks and iron veins along mountain edges
func _spawn_mountain_edge_rocks(dir_data: Dictionary) -> void:
	var half_size := room_size / 2.0
	# Spawn 15-25 rock clusters along the mountain edge
	var num_clusters := rng.randi_range(15, 25)

	for _c in range(num_clusters):
		# Random position along the edge
		var offset := rng.randf_range(-half_size + 5.0, half_size - 5.0)
		var base_pos: Vector3

		if dir_data["axis"] == "x":
			# North or South edge
			var edge_z: float = dir_data["edge_z"]
			# Spawn 8-20 units inside the room from the mountain wall
			var depth_offset := rng.randf_range(8.0, 20.0)
			base_pos = Vector3(offset, 0, edge_z + sign(edge_z) * -depth_offset)
		else:
			# East or West edge
			var edge_x: float = dir_data["edge_x"]
			var depth_offset := rng.randf_range(8.0, 20.0)
			base_pos = Vector3(edge_x + sign(edge_x) * -depth_offset, 0, offset)

		# Spawn a cluster of 3-7 rocks at this position
		var cluster_size := rng.randi_range(3, 7)
		for _r in range(cluster_size):
			# Scatter within 3-5 units of cluster center
			var scatter := Vector3(
				rng.randf_range(-4.0, 4.0),
				0,
				rng.randf_range(-4.0, 4.0)
			)
			var rock_pos := base_pos + scatter

			# Keep within room bounds
			rock_pos.x = clampf(rock_pos.x, -half_size + 3.0, half_size - 3.0)
			rock_pos.z = clampf(rock_pos.z, -half_size + 3.0, half_size - 3.0)

			# 70% regular rock, 25% iron vein, 5% rich iron
			var rock := HarvestableRock.spawn_random_rock(self, rock_pos, true)  # highlands=true for more iron
			props.append(rock)


## Create a single 3D mountain/rock block
func _create_mountain_block() -> Node3D:
	var mountain := Node3D.new()
	mountain.name = "MountainBlock"

	# Create the main rock mesh (irregular box shape)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()

	# Random size for variety - min width >= spacing to ensure overlap
	var width := rng.randf_range(8.0, 14.0)
	var height := rng.randf_range(10.0, 20.0)
	var depth := rng.randf_range(6.0, 12.0)
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


## Check if a position is on the road
func _is_position_on_road(x: float, z: float) -> bool:
	if not is_road_cell:
		return false

	var road_half_width: float = road_width / 2.0 + 4.0  # Wide buffer to keep content off road

	# Check road directions
	var north_road: bool = WorldGrid.is_road(grid_coords + Vector2i(0, -1))
	var south_road: bool = WorldGrid.is_road(grid_coords + Vector2i(0, 1))
	var east_road: bool = WorldGrid.is_road(grid_coords + Vector2i(1, 0))
	var west_road: bool = WorldGrid.is_road(grid_coords + Vector2i(-1, 0))

	# North-South road runs through center (X near 0)
	if (north_road or south_road) and abs(x) < road_half_width:
		return true

	# East-West road runs through center (Z near 0)
	if (east_road or west_road) and abs(z) < road_half_width:
		return true

	return false


## Get random position in content area (avoiding edges and roads)
## Uses terrain heightmap for Y position
func _get_random_content_position() -> Vector3:
	var margin := 20.0  # Stay away from edges
	var half_size := room_size / 2.0 - margin
	var max_attempts := 20

	for i in range(max_attempts):
		var x: float = rng.randf_range(-half_size, half_size)
		var z: float = rng.randf_range(-half_size, half_size)

		# Skip if on road
		if _is_position_on_road(x, z):
			continue

		var y: float = get_terrain_height_at(x, z)
		return Vector3(x, y, z)

	# Fallback - force position away from center (where roads are)
	var road_half_width: float = road_width / 2.0 + 6.0
	var side: int = rng.randi() % 4
	var fallback_x: float
	var fallback_z: float
	match side:
		0:  # Northeast quadrant
			fallback_x = rng.randf_range(road_half_width, half_size)
			fallback_z = rng.randf_range(-half_size, -road_half_width)
		1:  # Southeast quadrant
			fallback_x = rng.randf_range(road_half_width, half_size)
			fallback_z = rng.randf_range(road_half_width, half_size)
		2:  # Southwest quadrant
			fallback_x = rng.randf_range(-half_size, -road_half_width)
			fallback_z = rng.randf_range(road_half_width, half_size)
		_:  # Northwest quadrant
			fallback_x = rng.randf_range(-half_size, -road_half_width)
			fallback_z = rng.randf_range(-half_size, -road_half_width)
	var fallback_y: float = get_terrain_height_at(fallback_x, fallback_z)
	return Vector3(fallback_x, fallback_y, fallback_z)


## Get random position for props (can be closer to edges)
## On road cells, avoids the road area
## Uses terrain heightmap for Y position
func _get_random_prop_position() -> Vector3:
	var margin := 10.0
	var half_size := room_size / 2.0 - margin
	var max_attempts := 15

	for i in range(max_attempts):
		var x: float = rng.randf_range(-half_size, half_size)
		var z: float = rng.randf_range(-half_size, half_size)

		# Skip if on road
		if _is_position_on_road(x, z):
			continue

		var y: float = get_terrain_height_at(x, z)
		return Vector3(x, y, z)

	# Fallback - force position away from center (where roads are)
	var road_half_width: float = road_width / 2.0 + 6.0
	var side: int = rng.randi() % 4
	var fallback_x: float
	var fallback_z: float
	match side:
		0:  # Northeast quadrant
			fallback_x = rng.randf_range(road_half_width, half_size)
			fallback_z = rng.randf_range(-half_size, -road_half_width)
		1:  # Southeast quadrant
			fallback_x = rng.randf_range(road_half_width, half_size)
			fallback_z = rng.randf_range(road_half_width, half_size)
		2:  # Southwest quadrant
			fallback_x = rng.randf_range(-half_size, -road_half_width)
			fallback_z = rng.randf_range(road_half_width, half_size)
		_:  # Northwest quadrant
			fallback_x = rng.randf_range(-half_size, -road_half_width)
			fallback_z = rng.randf_range(-half_size, -road_half_width)
	var fallback_y: float = get_terrain_height_at(fallback_x, fallback_z)
	return Vector3(fallback_x, fallback_y, fallback_z)


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
		if not WorldGrid.is_road(adjacent):
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
		var cell: WorldGrid.CellInfo = WorldGrid.get_cell(check_coords)
		if not cell:
			break

		# If not passable, stop searching
		if not cell.passable:
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

## Get the world position for this room based on grid coordinates
## Used by CellStreamer to position chunks correctly
static func position_for_cell(cell_coords: Vector2i) -> Vector3:
	return WorldGrid.cell_to_world(cell_coords)


## Legacy alias for backwards compatibility
static func position_for_hex(hex_coords: Vector2i) -> Vector3:
	return position_for_cell(hex_coords)


## Enable seamless mode (disables edge triggers, CellStreamer handles transitions)
func set_seamless_mode(enabled: bool) -> void:
	seamless_mode = enabled

	# In cell streaming system, edge transitions are handled by CellStreamer
	# No need to toggle edge triggers - boundary walls are always present for impassable edges
	pass


## Reset the room for reuse (called by CellStreamer when recycling chunks)
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

	# Clear Spock easter egg
	if spock_easter_egg and is_instance_valid(spock_easter_egg):
		spock_easter_egg.queue_free()
	spock_easter_egg = null

	# Clear signposts
	for signpost: Node3D in signposts:
		if is_instance_valid(signpost):
			signpost.queue_free()
	signposts.clear()

	# Clear boundary walls (created by CellEdge)
	var boundary_walls := find_child("BoundaryWall*", true, false)
	if boundary_walls:
		for wall in get_children():
			if wall.name.begins_with("BoundaryWall"):
				wall.queue_free()
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
	var cell: WorldGrid.CellInfo = WorldGrid.get_cell(grid_coords)
	if cell:
		return cell.location_type != WorldGrid.LocationType.NONE
	return false


## Get the location ID if this chunk has one
func get_location_id() -> String:
	var cell: WorldGrid.CellInfo = WorldGrid.get_cell(grid_coords)
	if cell:
		return cell.location_id
	return ""


## Get the location type if this chunk has one
func get_location_type() -> WorldGrid.LocationType:
	var cell: WorldGrid.CellInfo = WorldGrid.get_cell(grid_coords)
	if cell:
		return cell.location_type
	return WorldGrid.LocationType.NONE


## ============================================================================
## EDGE TERRAIN BLENDING
## ============================================================================
## Creates visual transition elements at room edges where adjacent cells have
## different biomes. This helps make biome transitions feel more natural.

## Create edge transition effects based on adjacent cell biomes
func _create_edge_transitions() -> void:
	var half_size: float = room_size / 2.0
	var transition_depth: float = 15.0  # How far into the room the transition extends

	# Direction offsets for checking adjacent cells
	var directions: Array[Dictionary] = [
		{"offset": Vector2i(0, 1), "edge_z": -half_size, "axis": "x", "name": "North"},
		{"offset": Vector2i(0, -1), "edge_z": half_size, "axis": "x", "name": "South"},
		{"offset": Vector2i(1, 0), "edge_x": half_size, "axis": "z", "name": "East"},
		{"offset": Vector2i(-1, 0), "edge_x": -half_size, "axis": "z", "name": "West"}
	]

	for dir_data: Dictionary in directions:
		var adjacent_coords: Vector2i = grid_coords + dir_data["offset"]
		var adjacent_cell: WorldGrid.CellInfo = WorldGrid.get_cell(adjacent_coords)

		if not adjacent_cell:
			continue

		# Get adjacent biome
		var adjacent_biome: WorldGrid.Biome = adjacent_cell.biome

		# Convert to our local Biome enum for comparison
		var local_adjacent_biome: int = _world_biome_to_local(adjacent_biome)

		# If biomes are different, create transition props
		if local_adjacent_biome != biome:
			_spawn_transition_props(dir_data, local_adjacent_biome, transition_depth)


## Convert WorldGrid.Biome to local Biome enum
func _world_biome_to_local(world_biome: WorldGrid.Biome) -> int:
	match world_biome:
		WorldGrid.Biome.FOREST: return Biome.FOREST
		WorldGrid.Biome.PLAINS: return Biome.PLAINS
		WorldGrid.Biome.SWAMP: return Biome.SWAMP
		WorldGrid.Biome.HILLS: return Biome.HILLS
		WorldGrid.Biome.ROCKY, WorldGrid.Biome.MOUNTAINS: return Biome.ROCKY
		_: return Biome.PLAINS


## Spawn transition props along an edge based on adjacent biome
func _spawn_transition_props(dir_data: Dictionary, adjacent_biome: int, depth: float) -> void:
	var half_size: float = room_size / 2.0
	var num_props: int = rng.randi_range(5, 10)

	var transition_container := Node3D.new()
	transition_container.name = "EdgeTransition_%s" % dir_data["name"]
	add_child(transition_container)

	for i in range(num_props):
		var pos: Vector3

		if dir_data["axis"] == "x":
			# North or South edge
			var edge_z: float = dir_data["edge_z"]
			var inward: float = sign(edge_z) * -1  # Direction toward center
			pos = Vector3(
				rng.randf_range(-half_size + 10, half_size - 10),
				0,
				edge_z + inward * rng.randf_range(2, depth)
			)
		else:
			# East or West edge
			var edge_x: float = dir_data["edge_x"]
			var inward: float = sign(edge_x) * -1
			pos = Vector3(
				edge_x + inward * rng.randf_range(2, depth),
				0,
				rng.randf_range(-half_size + 10, half_size - 10)
			)

		# Spawn appropriate transition prop based on adjacent biome
		var prop: Node3D = _create_transition_prop(adjacent_biome)
		if prop:
			prop.position = pos
			transition_container.add_child(prop)


## Create a prop appropriate for transitioning to a specific biome
func _create_transition_prop(target_biome: int) -> Node3D:
	match target_biome:
		Biome.SWAMP:
			# Spawn murky puddle or dead vegetation
			return _create_swamp_transition_prop()
		Biome.FOREST:
			# Spawn extra trees or bushes
			return _create_tree()
		Biome.ROCKY:
			# Spawn rocks or boulders
			return _create_rock()
		Biome.PLAINS:
			# Spawn grass clumps
			return _create_grass_clump()
		_:
			return null


## Create a swamp transition prop (murky puddle or dead plant)
func _create_swamp_transition_prop() -> Node3D:
	var prop := Node3D.new()
	prop.name = "SwampTransition"

	# Create a small murky puddle
	var puddle := CSGCylinder3D.new()
	puddle.radius = rng.randf_range(1.0, 2.5)
	puddle.height = 0.1
	puddle.position = Vector3(0, 0.02, 0)

	var puddle_mat := StandardMaterial3D.new()
	puddle_mat.albedo_color = Color(0.15, 0.2, 0.12, 0.8)  # Murky green
	puddle_mat.roughness = 0.3
	puddle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puddle.material = puddle_mat

	prop.add_child(puddle)

	# Maybe add some dead grass
	if rng.randf() > 0.5:
		var dead_grass := _create_grass_clump()
		if dead_grass:
			dead_grass.position = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
			# Tint it brownish for dead appearance
			for child in dead_grass.get_children():
				if child is Sprite3D:
					child.modulate = Color(0.6, 0.5, 0.3)
			prop.add_child(dead_grass)

	return prop
