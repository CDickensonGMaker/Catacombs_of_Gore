## cell_streamer.gd - Daggerfall-style cell streaming system
## Loads/unloads cells in a ring around the player
## Player walks seamlessly across cell boundaries - NO teleport, NO rotation reset
extends Node

## Emitted when a cell finishes loading
signal cell_loaded(coords: Vector2i)

## Emitted when a cell is unloaded
signal cell_unloaded(coords: Vector2i)

## Emitted when streaming is paused (entering interior)
signal streaming_paused

## Emitted when streaming resumes (exiting interior)
signal streaming_resumed

## Emitted when floating origin shifts - entities must update stored positions
signal origin_shifted(shift: Vector3)


## Streaming configuration
const LOAD_RADIUS := 1       ## Load cells within this radius of player
const UNLOAD_RADIUS := 2     ## Unload cells beyond this radius
const CELL_SIZE := 100.0     ## World units per cell (matches WorldGrid)

## Floating origin configuration
const ORIGIN_SHIFT_THRESHOLD := 2000.0  ## Shift origin when player exceeds this distance (increased for stability)

## Currently loaded cells: Vector2i -> Node3D (the cell scene/room)
var loaded_cells: Dictionary = {}

## The cell the player is currently standing in
var active_cell: Vector2i = Vector2i.ZERO

## Cumulative world offset for floating origin
var world_offset: Vector3 = Vector3.ZERO

## Is streaming active? (disabled when in interiors)
var streaming_enabled: bool = false

## Reference to player node
var _player: Node3D = null

## Cells currently being loaded (async)
var _loading_cells: Dictionary = {}

## Parent node for all loaded cells
var _cell_container: Node3D = null

## Preloaded WildernessRoom scene for procedural cells
var _wilderness_room_scene: PackedScene = null

## The "main scene" cell that should NEVER be unloaded (contains environment/lighting)
var _main_scene_cell: Vector2i = Vector2i(-9999, -9999)  # Invalid until set

## Cells that were externally registered (not loaded by CellStreamer)
var _external_cells: Dictionary = {}

## PERFORMANCE: Cached camera reference - updated each frame
## Use CellStreamer.cached_camera instead of get_viewport().get_camera_3d()
var cached_camera: Camera3D = null


func _ready() -> void:
	# Create container for cells
	_cell_container = Node3D.new()
	_cell_container.name = "CellContainer"
	add_child(_cell_container)

	# Initialize WorldGrid
	WorldGrid.initialize()

	print("[CellStreamer] Ready")


func _physics_process(_delta: float) -> void:
	# PERFORMANCE: Cache camera reference each frame for billboard sprites
	cached_camera = get_viewport().get_camera_3d()

	if not streaming_enabled:
		return

	if not _player:
		_find_player()
		return

	# Check if player crossed into a new cell
	_check_cell_boundary()

	# Check if we need to shift the floating origin
	_check_floating_origin()


## Find the player node in the scene
func _find_player() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node3D


## Check if player has crossed into a new cell
func _check_cell_boundary() -> void:
	if not _player:
		return

	# Calculate player's actual world position (accounting for origin offset)
	var player_world_pos: Vector3 = _player.global_position + world_offset
	var new_cell: Vector2i = WorldGrid.world_to_cell(player_world_pos)

	if new_cell != active_cell:
		var old_cell: Vector2i = active_cell
		active_cell = new_cell

		# Notify PlayerGPS
		if PlayerGPS:
			PlayerGPS.update_cell(new_cell)

		# Update SceneManager's region tracking for UI compatibility
		var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(new_cell)
		if cell_info and SceneManager:
			# Update location ID if entering a named location
			if not cell_info.location_id.is_empty():
				SceneManager.current_region_id = cell_info.location_id
				# Notify QuestManager that we reached this location
				if QuestManager:
					QuestManager.on_location_reached(cell_info.location_id)
			else:
				# In wilderness - use region name as fallback
				SceneManager.current_region_id = cell_info.region_name.to_snake_case()
			SceneManager.current_room_coords = new_cell

		# Update loaded cells
		_update_loaded_cells()

		print("[CellStreamer] Player crossed into cell %s (%s)" % [new_cell,
			cell_info.location_name if cell_info and not cell_info.location_name.is_empty() else "wilderness"])


## Check and perform floating origin shift if needed
func _check_floating_origin() -> void:
	if not _player:
		return

	var player_pos: Vector3 = _player.global_position
	player_pos.y = 0  # Ignore vertical distance

	if player_pos.length() > ORIGIN_SHIFT_THRESHOLD:
		_shift_floating_origin(player_pos)


## Shift the floating origin to keep player near world origin
func _shift_floating_origin(shift: Vector3) -> void:
	shift.y = 0  # Don't shift vertically

	# Shift all loaded cells
	for cell_node: Node3D in loaded_cells.values():
		cell_node.global_position -= shift

	# Shift the player
	if _player:
		_player.global_position -= shift

	# Track cumulative offset
	world_offset += shift

	print("[CellStreamer] Origin shifted by %s (cumulative: %s)" % [shift, world_offset])

	# Notify all entities to update their stored positions (spawn_position, patrol_points, etc.)
	origin_shifted.emit(shift)


## Update which cells should be loaded/unloaded
func _update_loaded_cells() -> void:
	# Calculate which cells should be loaded
	var should_be_loaded: Array[Vector2i] = []
	for dx: int in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dy: int in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var coords: Vector2i = active_cell + Vector2i(dx, dy)
			if WorldGrid.is_in_bounds(coords):
				should_be_loaded.append(coords)

	# Unload cells that are too far
	var cells_to_unload: Array[Vector2i] = []
	for coords: Vector2i in loaded_cells.keys():
		var distance: int = WorldGrid.grid_distance(coords, active_cell)
		if distance > UNLOAD_RADIUS:
			cells_to_unload.append(coords)

	for coords: Vector2i in cells_to_unload:
		_unload_cell(coords)

	# Load cells that aren't loaded yet
	for coords: Vector2i in should_be_loaded:
		if not loaded_cells.has(coords) and not _loading_cells.has(coords):
			_load_cell(coords)


## Load a cell at the given coordinates
func _load_cell(coords: Vector2i) -> void:
	# Skip if this cell is already registered as the main scene
	# This prevents double-loading on save/load when the main scene is already present
	if coords == _main_scene_cell and loaded_cells.has(coords):
		print("[CellStreamer] Skipping cell %s - already registered as main scene" % coords)
		return

	# Mark as loading
	_loading_cells[coords] = true

	var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(coords)
	if not cell_info:
		_loading_cells.erase(coords)
		return

	var cell_node: Node3D

	# Check if this is an inactive goblin camp - treat as wilderness if not active
	var effective_scene_path: String = cell_info.scene_path
	if cell_info.location_id.begins_with("goblin_camp_"):
		if not GameManager.is_goblin_camp_active(cell_info.location_id):
			effective_scene_path = ""  # Treat as wilderness
			print("[CellStreamer] Goblin camp '%s' not active this playthrough, generating wilderness" % cell_info.location_id)

	# Debug: Log what type of cell we're loading
	if effective_scene_path != "":
		var exists: bool = ResourceLoader.exists(effective_scene_path)
		print("[CellStreamer] Cell %s has scene_path '%s', exists=%s, location='%s'" % [
			coords, effective_scene_path, exists, cell_info.location_id])
		if exists:
			# Hand-crafted scene - pass effective path to loader
			cell_node = await _load_handcrafted_cell_with_path(coords, cell_info, effective_scene_path)
		else:
			push_warning("[CellStreamer] Scene path doesn't exist: %s" % effective_scene_path)
			cell_node = _generate_procedural_cell(coords, cell_info)
	elif cell_info.location_type in [
		WorldGrid.LocationType.VILLAGE,
		WorldGrid.LocationType.TOWN,
		WorldGrid.LocationType.CITY,
		WorldGrid.LocationType.CAPITAL,
		WorldGrid.LocationType.OUTPOST
	] and effective_scene_path == "":
		# Procedural settlement - use TownGenerator
		cell_node = _generate_procedural_town(coords, cell_info)
	else:
		# Procedural wilderness - always generate the cell
		# WildernessRoom will handle skipping enemies/ruins for covered cells
		cell_node = _generate_procedural_cell(coords, cell_info)

	if not cell_node:
		_loading_cells.erase(coords)
		return

	cell_node.name = "Cell_%d_%d" % [coords.x, coords.y]

	# Add to container first (must be in tree before setting global_position)
	# Note: procedural towns are already added to tree before generation (NPC spawning requires it)
	if not cell_node.is_inside_tree():
		_cell_container.add_child(cell_node)
	loaded_cells[coords] = cell_node

	# Position the cell in world space (after adding to tree)
	var world_pos: Vector3 = WorldGrid.cell_to_world(coords) - world_offset
	cell_node.global_position = world_pos
	_loading_cells.erase(coords)

	# Create boundary walls for impassable edges
	_create_cell_boundaries(cell_node, coords)

	cell_loaded.emit(coords)
	print("[CellStreamer] Loaded cell %s (%s)" % [coords,
		cell_info.location_name if cell_info.location_name != "" else "wilderness"])


## Load a hand-crafted scene
func _load_handcrafted_cell(coords: Vector2i, cell_info: WorldGrid.CellInfo) -> Node3D:
	return await _load_handcrafted_cell_with_path(coords, cell_info, cell_info.scene_path)


## Load a hand-crafted scene with explicit path (for goblin camp overrides)
func _load_handcrafted_cell_with_path(coords: Vector2i, cell_info: WorldGrid.CellInfo, scene_path: String) -> Node3D:
	var scene: PackedScene = load(scene_path)
	if not scene:
		push_error("[CellStreamer] Failed to load scene: %s" % scene_path)
		return null

	var instance: Node3D = scene.instantiate()

	# Hide cell initially to prevent lighting flash during stripping
	# The cell will be shown after all stripping is complete
	instance.visible = false

	# Strip Player and HUD - they belong to the main scene, not streaming cells
	# When a hand-crafted scene is loaded AS A CELL (adjacent to player), it shouldn't
	# have its own Player or HUD since those already exist in the main scene
	var embedded_player: Node = instance.get_node_or_null("Player")
	if embedded_player:
		embedded_player.queue_free()
		print("[CellStreamer] Stripped embedded Player from cell %s" % coords)

	var embedded_hud: Node = instance.get_node_or_null("HUD")
	if embedded_hud:
		embedded_hud.queue_free()
		print("[CellStreamer] Stripped embedded HUD from cell %s" % coords)

	# Strip ALL lighting nodes - only the main scene should own lighting
	# This prevents light doubling when crossing cell boundaries
	_strip_lighting_recursive(instance, coords)

	# Strip ZoneDoors - streamed cells shouldn't have zone transition doors
	# The player navigates between cells by walking, not via doors
	# This prevents doors like "To Willow Dale" appearing when cell is loaded as neighbor
	_strip_zone_doors(instance, coords)

	# Also strip any DayNightCycle that the level script creates in _ready()
	# Must be deferred because DayNightCycle.add_to_level() runs during _ready
	# Run stripping AGAIN after _ready() to catch anything added by level scripts
	instance.ready.connect(func():
		_strip_lighting_recursive(instance, coords)
		# Show cell after stripping is complete (deferred to ensure it runs last)
		call_deferred("_show_cell_after_strip", instance)
	, CONNECT_ONE_SHOT)

	# Double-check after a frame delay to catch any late additions
	instance.ready.connect(func():
		call_deferred("_deferred_strip_lighting", instance, coords)
	, CONNECT_ONE_SHOT)

	# Add extended ground plane to ensure full cell coverage
	# Hand-crafted scenes may have gaps at edges - this catches fallen players
	_add_cell_ground_extension(instance, coords, cell_info)

	return instance


## Add an extended ground plane beneath hand-crafted cells to prevent falling through gaps
## This covers the full cell area (100x100) plus a ring extension (20 units) to connect to adjacent cells
## Placed at Y=-0.5 so it's below scene geometry but catches players who fall through gaps
func _add_cell_ground_extension(instance: Node3D, coords: Vector2i, cell_info: WorldGrid.CellInfo) -> void:
	# Extension size: full cell + 20 unit ring on each side for seamless connection
	var extension_size: float = CELL_SIZE + 40.0  # 140x140 units total

	# Create ground plane
	var ground: CSGBox3D = CSGBox3D.new()
	ground.name = "CellGroundExtension"
	ground.size = Vector3(extension_size, 1.0, extension_size)
	ground.position = Vector3(0, -0.5, 0)  # Below normal ground level
	ground.use_collision = true

	# Match biome color for visual consistency
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.roughness = 0.9
	material.albedo_color = _get_biome_ground_color(cell_info.biome)

	# Try to use floor texture for better visuals
	var floor_tex: Texture2D = _get_biome_floor_texture(cell_info.biome)
	if floor_tex:
		material.albedo_texture = floor_tex
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.uv1_scale = Vector3(10.0, 10.0, 1.0)

	ground.material = material
	instance.add_child(ground)

	print("[CellStreamer] Added ground extension (%.0fx%.0f) to cell %s" % [
		extension_size, extension_size, coords])


## Generate a procedural wilderness cell
func _generate_procedural_cell(coords: Vector2i, cell_info: WorldGrid.CellInfo) -> Node3D:
	# Try to use WildernessRoom if available
	if not _wilderness_room_scene:
		_wilderness_room_scene = load("res://scenes/generation/wilderness_room.tscn") as PackedScene

	if _wilderness_room_scene:
		var room: Node = _wilderness_room_scene.instantiate()

		# Configure the room
		if room.has_method("set_seamless_mode"):
			room.call("set_seamless_mode", true)

		# Set biome - WildernessRoom has this as an @export
		room.set("biome", WorldGrid.to_wilderness_biome(cell_info.biome))

		# Generate with deterministic seed (world_seed ensures different worlds per playthrough)
		var seed_value: int = GameManager.world_seed + (coords.x * 10000) + coords.y
		if room.has_method("generate"):
			room.call("generate", seed_value, coords)

		return room as Node3D

	# Fallback: create a simple ground plane
	return _create_simple_cell(coords, cell_info)


## Generate a procedural town/village/settlement
func _generate_procedural_town(coords: Vector2i, cell_info: WorldGrid.CellInfo) -> Node3D:
	var TownGeneratorClass = load("res://scripts/generation/town_generator.gd")
	if not TownGeneratorClass:
		push_warning("[CellStreamer] TownGenerator not found, falling back to wilderness")
		return _generate_procedural_cell(coords, cell_info)

	var town: Node3D = TownGeneratorClass.new()
	town.name = "ProceduralTown_%s" % cell_info.location_id
	town.set("is_streamed_cell", true)

	# Seed persistence: first visit generates seed, subsequent visits reuse it
	var seed_value: int = SaveManager.get_dungeon_seed(cell_info.location_id)
	if seed_value < 0:
		# First visit - generate deterministic seed from world seed + location
		seed_value = GameManager.world_seed + hash(cell_info.location_id)
		SaveManager.set_dungeon_seed(cell_info.location_id, seed_value)

	# Add to tree BEFORE generating - NPCs need the node in the tree for spawn validation
	_cell_container.add_child(town)

	# Generate the town with persistent seed
	if town.has_method("generate_from_cell"):
		town.call("generate_from_cell", cell_info, coords, seed_value)

	print("[CellStreamer] Generated procedural %s '%s' at %s (seed: %d)" % [
		WorldGrid.LocationType.keys()[cell_info.location_type],
		cell_info.location_name,
		coords,
		seed_value
	])

	return town


## Create a simple cell as fallback
func _create_simple_cell(_coords: Vector2i, cell_info: WorldGrid.CellInfo) -> Node3D:
	var cell: Node3D = Node3D.new()

	# Create ground mesh - exact size to prevent z-fighting with adjacent cells
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = Vector2(CELL_SIZE, CELL_SIZE)  # Exact cell size, no overlap
	ground.mesh = plane_mesh

	# Set material based on biome with floor texture
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.roughness = 0.9

	# Try to use floor texture, fall back to solid color
	var floor_tex: Texture2D = _get_biome_floor_texture(cell_info.biome)
	if floor_tex:
		material.albedo_texture = floor_tex
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 style
		material.uv1_scale = Vector3(10.0, 10.0, 1.0)  # Tile the texture
	else:
		material.albedo_color = _get_biome_ground_color(cell_info.biome)

	ground.material_override = material

	cell.add_child(ground)

	# Add collision - exact size to prevent z-fighting
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.collision_layer = 1  # World layer
	static_body.collision_mask = 0   # Ground doesn't need to detect anything
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(CELL_SIZE, 1.0, CELL_SIZE)  # Exact cell size
	collision.shape = box_shape
	collision.position.y = -0.5  # Match Elder Moor's ground level
	static_body.add_child(collision)
	cell.add_child(static_body)

	return cell


## Get ground color for a biome (must match wilderness_room.gd _setup_materials exactly)
func _get_biome_ground_color(biome: WorldGrid.Biome) -> Color:
	match biome:
		WorldGrid.Biome.FOREST:
			return Color(0.2, 0.35, 0.15)  # Green grass
		WorldGrid.Biome.PLAINS:
			return Color(0.45, 0.4, 0.25)  # Dry grass
		WorldGrid.Biome.SWAMP:
			return Color(0.15, 0.2, 0.12)  # Dark murky
		WorldGrid.Biome.HILLS:
			return Color(0.35, 0.38, 0.25)  # Hilly grass
		WorldGrid.Biome.ROCKY, WorldGrid.Biome.MOUNTAINS:
			return Color(0.3, 0.28, 0.25)  # Rocky ground
		WorldGrid.Biome.COAST, WorldGrid.Biome.DESERT:
			return Color(0.55, 0.50, 0.40)  # Sandy
		_:
			return Color(0.2, 0.35, 0.15)  # Default forest


## Get floor texture for a biome (randomly picks from available textures)
## Textures in: assets/textures/environment/floors/ and assets/sprites/environment/ground/
func _get_biome_floor_texture(biome: WorldGrid.Biome) -> Texture2D:
	var textures: Array[String] = []

	match biome:
		WorldGrid.Biome.FOREST:
			textures = [
				"res://assets/textures/environment/floors/leaves_full.png",
				"res://assets/textures/environment/floors/leaves_half.png",
				"res://assets/sprites/environment/ground/grassland_1.png",
				"res://assets/sprites/environment/ground/grassland_2.png",
				"res://assets/sprites/environment/ground/grassland_3.png",
			]
		WorldGrid.Biome.PLAINS:
			textures = [
				"res://assets/textures/environment/floors/plains_floor1.png",
				"res://assets/textures/environment/floors/plains_floor2.png",
				"res://assets/textures/environment/floors/plains_floor3.png",
				"res://assets/sprites/environment/ground/grassland_1.png",
				"res://assets/sprites/environment/ground/grassland_2.png",
			]
		WorldGrid.Biome.SWAMP:
			textures = [
				"res://assets/textures/environment/floors/swamp_flood1.png",
				"res://assets/textures/environment/floors/swamp_flood2.png",
				"res://assets/textures/environment/floors/leaves_half.png",
			]
		WorldGrid.Biome.HILLS:
			textures = [
				"res://assets/textures/environment/floors/plains_floor2.png",
				"res://assets/sprites/environment/ground/grassland_1.png",
				"res://assets/textures/environment/floors/rockhill_floor1.png",
			]
		WorldGrid.Biome.ROCKY, WorldGrid.Biome.MOUNTAINS:
			textures = [
				"res://assets/textures/environment/floors/rockhill_floor1.png",
				"res://assets/textures/environment/floors/rockhill_floor2.png",
				"res://assets/textures/environment/floors/rockhill_floor3.png",
			]
		WorldGrid.Biome.COAST, WorldGrid.Biome.DESERT:
			textures = [
				"res://assets/textures/environment/floors/plains_floor1.png",
				"res://assets/textures/environment/floors/plains_floor2.png",
			]
		_:
			textures = [
				"res://assets/textures/environment/floors/plains_floor1.png",
				"res://assets/sprites/environment/ground/grassland_1.png",
			]

	# Randomly pick a texture
	if textures.is_empty():
		return null

	var idx: int = randi() % textures.size()
	var tex_path: String = textures[idx]

	if ResourceLoader.exists(tex_path):
		return load(tex_path) as Texture2D

	return null


## Unload a cell
func _unload_cell(coords: Vector2i) -> void:
	if not loaded_cells.has(coords):
		return

	# NEVER unload the main scene cell - it contains environment/lighting
	if coords == _main_scene_cell:
		return

	# Don't unload externally registered cells (they weren't loaded by us)
	if _external_cells.has(coords):
		return

	var cell_node: Node3D = loaded_cells[coords]
	loaded_cells.erase(coords)

	# Clear NPC names used in this zone to prevent name exhaustion on re-entry
	var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(coords)
	if cell_info and not cell_info.location_id.is_empty():
		WorldLexicon.clear_zone_names(cell_info.location_id)

	# Clean up the cell
	if is_instance_valid(cell_node):
		cell_node.queue_free()

	cell_unloaded.emit(coords)
	print("[CellStreamer] Unloaded cell %s" % coords)


## Create boundary walls for edges with impassable adjacent cells
## Now creates VISIBLE rock meshes instead of invisible collision walls
func _create_cell_boundaries(cell_node: Node3D, coords: Vector2i) -> void:
	var directions: Array[Vector2i] = [
		Vector2i(0, -1),  # North
		Vector2i(0, 1),   # South
		Vector2i(1, 0),   # East
		Vector2i(-1, 0)   # West
	]

	for dir: Vector2i in directions:
		var adjacent: Vector2i = coords + dir
		var adjacent_cell: WorldGrid.CellInfo = WorldGrid.get_cell(adjacent)

		if not WorldGrid.is_passable(adjacent):
			# Check if adjacent is water (W) or blocked terrain (B/mountains)
			var is_water: bool = adjacent_cell != null and adjacent_cell.terrain == WorldGrid.Terrain.WATER
			_create_boundary_wall(cell_node, dir, coords, is_water)

			# Add coastal decoration (sand, water plane) if adjacent to water
			if is_water:
				_add_coastal_decoration(cell_node, dir, coords)


## Create a VISIBLE rock wall on one edge with collision
## For water edges: creates LOW coastal rocks (not tall walls) + invisible collision
## For mountain edges: creates tall impassable cliff walls
func _create_boundary_wall(cell_node: Node3D, direction: Vector2i, coords: Vector2i, is_water_edge: bool) -> void:
	var half_size: float = CELL_SIZE / 2.0

	# Container for wall geometry
	var wall_container: Node3D = Node3D.new()
	wall_container.name = "BoundaryWall_%s" % _dir_name(direction)
	cell_node.add_child(wall_container)

	if is_water_edge:
		# WATER EDGE: Low coastal rocks scattered along the shoreline
		# These are decorative beach rocks, NOT tall walls
		var num_rocks: int = 6
		var segment_length: float = CELL_SIZE / float(num_rocks)

		# Rock material - brown/gray beach rocks
		var rock_mat: StandardMaterial3D = StandardMaterial3D.new()
		rock_mat.albedo_color = Color(0.45, 0.40, 0.35)  # Brown-gray beach rocks
		rock_mat.roughness = 0.95

		for i in range(num_rocks):
			var rock: CSGBox3D = CSGBox3D.new()
			rock.name = "CoastalRock_%d" % i

			# Small, low rocks - NOT tall walls
			var rock_height: float = randf_range(0.5, 1.5)
			var rock_width: float = randf_range(2.0, 4.0)
			var rock_depth: float = randf_range(2.0, 4.0)

			rock.material = rock_mat
			rock.use_collision = true

			# Position scattered along edge with some randomness
			var seg_offset: float = -half_size + segment_length * (i + 0.5) + randf_range(-3.0, 3.0)

			if direction.x != 0:
				# East/West edge
				rock.size = Vector3(rock_depth, rock_height, rock_width)
				rock.position = Vector3(
					direction.x * (half_size - 5.0 + randf_range(-2.0, 2.0)),
					rock_height / 2.0,
					seg_offset
				)
			else:
				# North/South edge
				rock.size = Vector3(rock_width, rock_height, rock_depth)
				rock.position = Vector3(
					seg_offset,
					rock_height / 2.0,
					-direction.y * (half_size - 5.0 + randf_range(-2.0, 2.0))
				)

			wall_container.add_child(rock)

		# Add invisible collision wall to prevent player walking into water
		var collision_wall: StaticBody3D = StaticBody3D.new()
		collision_wall.name = "WaterCollision"
		var collision_shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()

		if direction.x != 0:
			box.size = Vector3(2.0, 10.0, CELL_SIZE)
			collision_shape.position = Vector3(direction.x * half_size, 5.0, 0)
		else:
			box.size = Vector3(CELL_SIZE, 10.0, 2.0)
			collision_shape.position = Vector3(0, 5.0, -direction.y * half_size)

		collision_shape.shape = box
		collision_wall.add_child(collision_shape)
		wall_container.add_child(collision_wall)

	else:
		# MOUNTAIN EDGE: Tall impassable cliff walls
		var wall_thickness: float = 4.0
		var wall_height: float = 12.0
		var num_segments: int = 8
		var segment_length: float = CELL_SIZE / float(num_segments)

		for i in range(num_segments):
			var rock: CSGBox3D = CSGBox3D.new()
			rock.name = "CliffSegment_%d" % i

			# Random height variation for each segment
			var seg_height: float = wall_height * randf_range(0.7, 1.3)
			var seg_thickness: float = wall_thickness * randf_range(0.8, 1.2)

			# Create rock material - gray mountain rocks
			var rock_mat: StandardMaterial3D = StandardMaterial3D.new()
			rock_mat.albedo_color = Color(0.35, 0.33, 0.30)
			rock_mat.roughness = 0.95
			rock.material = rock_mat
			rock.use_collision = true

			# Position based on direction
			var seg_offset: float = -half_size + segment_length * (i + 0.5)

			if direction.x != 0:
				# East/West wall
				rock.size = Vector3(seg_thickness, seg_height, segment_length * 0.95)
				rock.position = Vector3(
					direction.x * (half_size + seg_thickness * 0.3),
					seg_height / 2.0,
					seg_offset
				)
			else:
				# North/South wall
				rock.size = Vector3(segment_length * 0.95, seg_height, seg_thickness)
				rock.position = Vector3(
					seg_offset,
					seg_height / 2.0,
					-direction.y * (half_size + seg_thickness * 0.3)
				)

			wall_container.add_child(rock)

	print("[CellStreamer] Created boundary on %s edge of cell %s (water=%s)" % [
		_dir_name(direction), coords, is_water_edge])


## Add coastal decoration (sand strip and LARGE water plane) on edges adjacent to water
## Water plane is flat at Y=-0.5 and extends far enough to fill view to fog distance
func _add_coastal_decoration(cell_node: Node3D, direction: Vector2i, coords: Vector2i) -> void:
	var half_size: float = CELL_SIZE / 2.0
	var sand_width: float = 15.0  # Width of sandy beach area
	var water_extent: float = 300.0  # How far water extends (to reach fog distance)

	var coast_container: Node3D = Node3D.new()
	coast_container.name = "CoastalDecoration_%s" % _dir_name(direction)
	cell_node.add_child(coast_container)

	# Sand strip material
	var sand_mat: StandardMaterial3D = StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.76, 0.70, 0.50)  # Sandy tan
	sand_mat.roughness = 0.95

	# Water plane material - flat horizontal surface
	var water_mat: StandardMaterial3D = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.12, 0.30, 0.40, 0.90)  # Deeper blue-green
	water_mat.roughness = 0.15
	water_mat.metallic = 0.4
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Create sand strip along the edge
	var sand: CSGBox3D = CSGBox3D.new()
	sand.name = "SandStrip"
	sand.material = sand_mat
	sand.use_collision = false

	# Create LARGE water plane that extends to fog distance
	# This is a flat horizontal plane at Y=-0.5
	var water: CSGBox3D = CSGBox3D.new()
	water.name = "WaterPlane"
	water.material = water_mat
	water.use_collision = false

	# Water extends perpendicular to the coast AND along it for full coverage
	var water_length: float = CELL_SIZE * 3.0  # Extend along coast to cover adjacent cells

	if direction.x != 0:
		# East/West coast - water extends East or West
		sand.size = Vector3(sand_width, 0.2, CELL_SIZE)
		sand.position = Vector3(
			direction.x * (half_size - sand_width / 2.0),
			0.02,
			0
		)
		# Water plane: wide (extends to fog), thin (0.1 height), long (covers adjacent)
		water.size = Vector3(water_extent, 0.1, water_length)
		water.position = Vector3(
			direction.x * (half_size + water_extent / 2.0),
			-0.5,  # Below ground level
			0
		)
	else:
		# North/South coast - water extends North or South
		sand.size = Vector3(CELL_SIZE, 0.2, sand_width)
		sand.position = Vector3(
			0,
			0.02,
			-direction.y * (half_size - sand_width / 2.0)
		)
		# Water plane: long (covers adjacent), thin (0.1 height), wide (extends to fog)
		water.size = Vector3(water_length, 0.1, water_extent)
		water.position = Vector3(
			0,
			-0.5,  # Below ground level
			-direction.y * (half_size + water_extent / 2.0)
		)

	coast_container.add_child(sand)
	coast_container.add_child(water)

	print("[CellStreamer] Added coastal decoration on %s edge of cell %s (water extends %s units)" % [
		_dir_name(direction), coords, water_extent])


## Strip ALL lighting nodes recursively from a cell instance
## This prevents light doubling when cells are loaded as neighbors
func _strip_lighting_recursive(instance: Node3D, coords: Vector2i) -> void:
	var stripped: int = 0

	# Get all descendants, not just direct children
	var nodes_to_check: Array[Node] = [instance]
	while not nodes_to_check.is_empty():
		var current: Node = nodes_to_check.pop_back()

		# Check if this node should be stripped
		var should_strip: bool = false
		if current is WorldEnvironment:
			should_strip = true
		elif current is DirectionalLight3D:
			should_strip = true
		elif current.get_class() == "DayNightCycle" or current.name == "DayNightCycle":
			should_strip = true

		if should_strip and current != instance:
			current.queue_free()
			stripped += 1
		else:
			# Add children to check (only if not stripping this node)
			for child in current.get_children():
				nodes_to_check.append(child)

	if stripped > 0:
		print("[CellStreamer] Stripped %d lighting nodes from cell %s" % [stripped, coords])


## Deferred stripping - runs after a frame to catch late additions
func _deferred_strip_lighting(instance: Node3D, coords: Vector2i) -> void:
	if not is_instance_valid(instance):
		return
	_strip_lighting_recursive(instance, coords)


## Show cell after all lighting stripping is complete
## This prevents the lighting flash that occurs when competing lights briefly exist
func _show_cell_after_strip(instance: Node3D) -> void:
	if is_instance_valid(instance):
		instance.visible = true


## Strip ZoneDoor nodes from a cell instance
## These are scene transition doors that shouldn't exist in streamed cells
## Player navigates between cells by walking, not through door interactions
func _strip_zone_doors(instance: Node3D, coords: Vector2i) -> void:
	var doors_stripped: int = 0

	# Check direct children for ZoneDoor instances
	for child in instance.get_children():
		if child.get_class() == "Node3D" and child.has_method("_on_interaction_attempted"):
			# Likely a ZoneDoor - check if it has target_scene property
			if "target_scene" in child:
				child.queue_free()
				doors_stripped += 1

	# Also check common container names
	var doors_container: Node = instance.get_node_or_null("Doors")
	if doors_container:
		for child in doors_container.get_children():
			child.queue_free()
			doors_stripped += 1

	var door_positions: Node = instance.get_node_or_null("DoorPositions")
	if door_positions:
		# Don't delete the markers, but the level script may spawn doors from them
		# We'll rely on the script not spawning doors when not the main scene
		pass

	if doors_stripped > 0:
		print("[CellStreamer] Stripped %d ZoneDoors from cell %s" % [doors_stripped, coords])


## Helper to get direction name for debug output
func _dir_name(direction: Vector2i) -> String:
	if direction == Vector2i(0, -1):
		return "north"
	elif direction == Vector2i(0, 1):
		return "south"
	elif direction == Vector2i(1, 0):
		return "east"
	elif direction == Vector2i(-1, 0):
		return "west"
	return "unknown"


## ============================================================================
## PUBLIC API
## ============================================================================

## Start streaming from a given cell (called when game starts or exiting interior)
func start_streaming(start_coords: Vector2i) -> void:
	active_cell = start_coords
	streaming_enabled = true

	# Ensure cell container exists (may have been freed during scene change)
	if not is_instance_valid(_cell_container):
		_cell_container = Node3D.new()
		_cell_container.name = "CellContainer"
		add_child(_cell_container)

	# Load initial cells
	_update_loaded_cells()

	# Start the EncounterManager for random wilderness encounters
	_start_encounter_manager()

	streaming_resumed.emit()
	print("[CellStreamer] Streaming started at %s" % start_coords)


## Stop streaming (called when entering interior or changing scenes)
func stop_streaming() -> void:
	streaming_enabled = false

	# Stop the EncounterManager when leaving wilderness
	_stop_encounter_manager()

	# Actually free all loaded cell nodes to prevent doubling on save/load
	# Previously we only cleared the dictionary, leaving orphaned nodes in the tree
	for coords: Vector2i in loaded_cells.keys():
		var cell_node = loaded_cells[coords]
		if is_instance_valid(cell_node) and not _external_cells.has(coords):
			cell_node.queue_free()

	loaded_cells.clear()
	_loading_cells.clear()
	_external_cells.clear()
	_main_scene_cell = Vector2i(-9999, -9999)

	# Reset world offset for next streaming session
	world_offset = Vector3.ZERO

	# Reset player reference
	_player = null

	# Clear all NPC zone names to prevent name exhaustion across scene changes
	WorldLexicon.clear_all_zone_names()

	# Safety: clear any remaining children from cell container
	if is_instance_valid(_cell_container):
		for child in _cell_container.get_children():
			child.queue_free()

	streaming_paused.emit()
	print("[CellStreamer] Streaming stopped and state reset")


## Pause streaming without unloading (for menus, etc.)
func pause_streaming() -> void:
	streaming_enabled = false
	streaming_paused.emit()


## Resume streaming
func resume_streaming() -> void:
	streaming_enabled = true
	streaming_resumed.emit()


## Check if streaming is active
func is_streaming() -> bool:
	return streaming_enabled


## Get the current active cell
func get_active_cell() -> Vector2i:
	return active_cell


## Get the world offset (for coordinate calculations)
func get_world_offset() -> Vector3:
	return world_offset


## Check if a cell is currently loaded
func is_cell_loaded(coords: Vector2i) -> bool:
	return loaded_cells.has(coords)


## Get the node for a loaded cell
func get_cell_node(coords: Vector2i) -> Node3D:
	return loaded_cells.get(coords, null)


## Force reload of a specific cell
func reload_cell(coords: Vector2i) -> void:
	if loaded_cells.has(coords):
		_unload_cell(coords)
	_load_cell(coords)


## Register a cell as the main scene (will never be unloaded)
## Call this from hand-crafted levels that are loaded as the main scene
func register_main_scene_cell(coords: Vector2i, cell_node: Node3D) -> void:
	_main_scene_cell = coords
	_external_cells[coords] = true
	if not loaded_cells.has(coords):
		loaded_cells[coords] = cell_node
	print("[CellStreamer] Registered main scene cell at %s" % coords)


## Teleport player to a specific cell (used for fast travel)
## This WILL reposition the player
func teleport_to_cell(coords: Vector2i, spawn_position: Vector3 = Vector3.ZERO) -> void:
	print("[CellStreamer] Teleporting to cell %s (current main: %s)" % [coords, _main_scene_cell])

	# Check if we're returning to the current main scene
	var saved_main_cell: Vector2i = _main_scene_cell
	var is_returning_to_main: bool = (coords == saved_main_cell and saved_main_cell != Vector2i(-9999, -9999))
	var saved_main_node: Node3D = null

	if loaded_cells.has(saved_main_cell):
		saved_main_node = loaded_cells.get(saved_main_cell, null) as Node3D

	# Free ALL loaded cells EXCEPT the main scene if we're returning to it
	for cell_coords: Vector2i in loaded_cells.keys():
		var cell_node: Node3D = loaded_cells.get(cell_coords, null) as Node3D
		if is_instance_valid(cell_node):
			# Don't free the main scene node if we're returning to it
			if is_returning_to_main and cell_coords == saved_main_cell:
				continue
			cell_node.queue_free()

	# Clear all tracking
	loaded_cells.clear()
	_loading_cells.clear()
	_external_cells.clear()
	streaming_enabled = false
	world_offset = Vector3.ZERO

	# Clear all NPC zone names to prevent name exhaustion on fast travel
	WorldLexicon.clear_all_zone_names()

	# Safety: clear any remaining children from cell container
	if is_instance_valid(_cell_container):
		for child in _cell_container.get_children():
			# Don't free the main scene node if we're returning to it
			if is_returning_to_main and is_instance_valid(saved_main_node) and child == saved_main_node:
				continue
			child.queue_free()

	# Find player
	_find_player()
	if _player:
		# Position player at cell center or specified spawn position
		var cell_center: Vector3 = WorldGrid.cell_to_world(coords)
		if spawn_position != Vector3.ZERO:
			_player.global_position = spawn_position
		else:
			_player.global_position = cell_center + Vector3(0, 1, 0)

	# Restore main scene registration if returning to it
	if is_returning_to_main and is_instance_valid(saved_main_node):
		_main_scene_cell = saved_main_cell
		_external_cells[saved_main_cell] = true
		loaded_cells[saved_main_cell] = saved_main_node
		print("[CellStreamer] Restored main scene cell at %s" % saved_main_cell)
	else:
		# Not returning to main - clear main scene tracking and FREE the old node
		_main_scene_cell = Vector2i(-9999, -9999)
		# Free the old main scene node to prevent orphaning
		if is_instance_valid(saved_main_node):
			saved_main_node.queue_free()

	# Start streaming from new location
	active_cell = coords
	streaming_enabled = true

	# Ensure cell container exists
	if not is_instance_valid(_cell_container):
		_cell_container = Node3D.new()
		_cell_container.name = "CellContainer"
		add_child(_cell_container)

	# Load cells around new position
	# Defer loading until queue_free() has processed at end of frame
	call_deferred("_update_loaded_cells")

	streaming_resumed.emit()
	print("[CellStreamer] Teleported to cell %s" % coords)


## ============================================================================
## SAVE/LOAD
## ============================================================================

## Get save data
func get_save_data() -> Dictionary:
	return {
		"active_cell_x": active_cell.x,
		"active_cell_y": active_cell.y,
		"world_offset_x": world_offset.x,
		"world_offset_y": world_offset.y,
		"world_offset_z": world_offset.z,
		"streaming_enabled": streaming_enabled
	}


## Load save data
## NOTE: We only restore active_cell and world_offset here.
## start_streaming() is NOT called because the main scene's _setup_cell_streaming()
## will call it after the scene loads. Calling it here would cause duplicate cell loading.
func load_save_data(data: Dictionary) -> void:
	active_cell = Vector2i(
		data.get("active_cell_x", 0),
		data.get("active_cell_y", 0)
	)
	world_offset = Vector3(
		data.get("world_offset_x", 0.0),
		data.get("world_offset_y", 0.0),
		data.get("world_offset_z", 0.0)
	)
	# Do NOT call start_streaming() here - the main scene handles that


## ============================================================================
## ENCOUNTER MANAGER INTEGRATION
## ============================================================================

## Start the EncounterManager for random wilderness encounters
func _start_encounter_manager() -> void:
	if not EncounterManager:
		return

	# Find player
	_find_player()
	if not _player:
		push_warning("[CellStreamer] Cannot start EncounterManager - no player found")
		return

	EncounterManager.start(_player)
	print("[CellStreamer] EncounterManager started for wilderness encounters")


## Stop the EncounterManager when leaving wilderness
func _stop_encounter_manager() -> void:
	if not EncounterManager:
		return

	EncounterManager.stop()
	print("[CellStreamer] EncounterManager stopped")
