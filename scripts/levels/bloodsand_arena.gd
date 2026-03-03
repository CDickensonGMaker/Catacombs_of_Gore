## bloodsand_arena.gd - Bloodsand Arena (Combat Arena south of Elder Moor)
## Gladiatorial combat arena where players fight in tournaments for fame and rewards
## Scene-based layout with runtime navigation baking
extends Node3D

const ZONE_ID := "bloodsand_arena"
const ZONE_SIZE := Vector2(100.0, 100.0)  # Standard cell size

## Grid coordinates (south of Elder Moor)
const GRID_COORDS := Vector2i(0, 3)

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

## Arena barrier reference (created at runtime or from scene)
var arena_barrier: StaticBody3D


func _ready() -> void:
	# Add to group so TournamentManager can find the arena
	add_to_group("bloodsand_arena")
	add_to_group("level_root")

	# Only register with PlayerGPS if we're the main scene (have Player node)
	# When loaded as a streaming cell, Player is stripped - don't touch GPS
	var is_main_scene: bool = get_node_or_null("Player") != null

	if is_main_scene:
		if PlayerGPS:
			PlayerGPS.set_position(GRID_COORDS, true)
		# Play combat arena ambient sounds
		AudioManager.play_zone_ambiance("combat_arena")

	_setup_ground_plane()  # Add base ground plane for cell grid connectivity
	_setup_navigation()
	if is_main_scene:
		_setup_day_night_cycle()
	_setup_spawn_point_metadata()
	# Generate collision ONLY for walls from the GLB model (not decorative elements)
	_generate_wall_collision()
	_spawn_arena_master()
	_spawn_shops()
	_setup_arena_barrier()

	# Connect to TournamentManager signals
	_connect_tournament_signals()

	# Register with CellStreamer and start streaming
	_setup_cell_streaming()

	print("[Bloodsand Arena] Combat arena initialized")


## Spike pit radius - center area with no floor
const SPIKE_PIT_RADIUS := 4.0

## Arena fighting area radius
const ARENA_RADIUS := 18.0

## Create arena floor with a hole in the center for the spike pit
func _setup_ground_plane() -> void:
	var ground_container := Node3D.new()
	ground_container.name = "ArenaFloor"
	add_child(ground_container)

	# Create rock material for arena floor
	var material := StandardMaterial3D.new()
	material.roughness = 0.95

	# Load rock texture for arena
	var floor_tex: Texture2D = load("res://assets/textures/environment/floors/rockhill_floor1.png")
	if floor_tex:
		material.albedo_texture = floor_tex
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 style
		material.uv1_scale = Vector3(8.0, 8.0, 1.0)  # Tile the texture
	else:
		material.albedo_color = Color(0.4, 0.35, 0.3)  # Rock brown fallback

	# Create 4 floor sections around the spike pit (leaving center open)
	# Each section is a rectangular piece that together form a floor with a square hole
	var half_size: float = ARENA_RADIUS
	var pit_half: float = SPIKE_PIT_RADIUS

	# Section positions and sizes: [position, size]
	# North section (behind pit)
	_create_floor_section(ground_container, material,
		Vector3(0, 0, -(half_size + pit_half) / 2),
		Vector2(half_size * 2, half_size - pit_half))

	# South section (in front of pit)
	_create_floor_section(ground_container, material,
		Vector3(0, 0, (half_size + pit_half) / 2),
		Vector2(half_size * 2, half_size - pit_half))

	# West section (left of pit, between north and south)
	_create_floor_section(ground_container, material,
		Vector3(-(half_size + pit_half) / 2, 0, 0),
		Vector2(half_size - pit_half, pit_half * 2))

	# East section (right of pit, between north and south)
	_create_floor_section(ground_container, material,
		Vector3((half_size + pit_half) / 2, 0, 0),
		Vector2(half_size - pit_half, pit_half * 2))

	# Add outer ground plane for the rest of the cell (outside arena)
	_create_outer_ground(ground_container, material)

	print("[Bloodsand Arena] Arena floor created with spike pit hole (radius %.1f)" % SPIKE_PIT_RADIUS)


## Create a single floor section with mesh and collision
func _create_floor_section(parent: Node3D, material: Material, pos: Vector3, size: Vector2) -> void:
	var section := Node3D.new()
	section.name = "FloorSection"
	section.position = pos
	parent.add_child(section)

	# Create mesh
	var mesh_instance := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = size
	mesh_instance.mesh = plane_mesh
	mesh_instance.material_override = material
	section.add_child(mesh_instance)

	# Create collision
	var static_body := StaticBody3D.new()
	static_body.collision_layer = 1
	static_body.collision_mask = 0

	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(size.x, 0.5, size.y)
	collision.shape = box_shape
	collision.position.y = -0.25
	static_body.add_child(collision)
	section.add_child(static_body)


## Create outer ground for the cell (outside the arena area)
## Creates collision ONLY for the perimeter, leaving the arena center open
func _create_outer_ground(parent: Node3D, material: Material) -> void:
	var outer := Node3D.new()
	outer.name = "OuterGround"
	outer.position.y = -0.1  # Slightly below arena floor
	parent.add_child(outer)

	# Create outer material
	var outer_material := StandardMaterial3D.new()
	outer_material.roughness = 0.95
	var outer_tex: Texture2D = load("res://assets/textures/environment/floors/rockhill_floor2.png")
	if outer_tex:
		outer_material.albedo_texture = outer_tex
		outer_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		outer_material.uv1_scale = Vector3(12.0, 12.0, 1.0)
	else:
		outer_material.albedo_color = Color(0.3, 0.28, 0.25)

	# Create 4 collision strips around the arena perimeter (frame shape)
	# This leaves the arena center OPEN so player can fall into spike pit
	var half_cell: float = ZONE_SIZE.x / 2.0
	var strip_width: float = half_cell - ARENA_RADIUS  # Width of outer strip

	# North strip (behind arena)
	_create_outer_strip(outer, outer_material,
		Vector3(0, 0, -(half_cell - strip_width / 2.0)),
		Vector2(ZONE_SIZE.x, strip_width))

	# South strip (in front of arena)
	_create_outer_strip(outer, outer_material,
		Vector3(0, 0, (half_cell - strip_width / 2.0)),
		Vector2(ZONE_SIZE.x, strip_width))

	# West strip (left of arena, between north and south)
	_create_outer_strip(outer, outer_material,
		Vector3(-(half_cell - strip_width / 2.0), 0, 0),
		Vector2(strip_width, ARENA_RADIUS * 2))

	# East strip (right of arena, between north and south)
	_create_outer_strip(outer, outer_material,
		Vector3((half_cell - strip_width / 2.0), 0, 0),
		Vector2(strip_width, ARENA_RADIUS * 2))


## Create a single outer ground strip with collision
func _create_outer_strip(parent: Node3D, material: Material, pos: Vector3, size: Vector2) -> void:
	var strip := Node3D.new()
	strip.position = pos
	parent.add_child(strip)

	# Collision
	var static_body := StaticBody3D.new()
	static_body.collision_layer = 1
	static_body.collision_mask = 0

	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(size.x, 0.5, size.y)
	collision.shape = box_shape
	collision.position.y = -0.25
	static_body.add_child(collision)
	strip.add_child(static_body)

	# Visual mesh
	var mesh_instance := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = size
	mesh_instance.mesh = plane_mesh
	mesh_instance.material_override = material
	strip.add_child(mesh_instance)


## Register this scene with CellStreamer and start streaming
func _setup_cell_streaming() -> void:
	if not CellStreamer:
		push_warning("[Bloodsand Arena] CellStreamer not found")
		return

	# Register this scene as a cell
	CellStreamer.register_main_scene_cell(GRID_COORDS, self)

	# Start streaming from this cell
	CellStreamer.start_streaming(GRID_COORDS)


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Bloodsand Arena] NavigationRegion3D not found in scene")
		return

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
		print("[Bloodsand Arena] Navigation mesh baked")


## Setup dynamic day/night lighting
func _setup_day_night_cycle() -> void:
	DayNightCycle.add_to_level(self)


## Add metadata to spawn points for proper identification
func _setup_spawn_point_metadata() -> void:
	var spawn_points: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	for child: Node in spawn_points.get_children():
		if child.is_in_group("spawn_points"):
			child.set_meta("spawn_id", child.name)


## Generate collision ONLY for wall meshes (not floors or decorative elements)
## Walls are identified by name containing "wall", "pillar", "column", etc.
func _generate_wall_collision() -> void:
	var terrain: Node3D = get_node_or_null("Terrain")
	if not terrain:
		print("[Bloodsand Arena] No Terrain node found for wall collision")
		return

	var wall_count: int = _add_wall_collision_recursive(terrain)
	print("[Bloodsand Arena] Generated collision for %d wall meshes" % wall_count)


## Recursively find wall meshes and add collision
func _add_wall_collision_recursive(node: Node) -> int:
	var count: int = 0

	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		var mesh_name: String = mesh_instance.name.to_lower()

		# Only add collision to wall-like meshes
		if _is_wall_mesh(mesh_name):
			# Check if collision already exists
			var has_collision := false
			for child in mesh_instance.get_children():
				if child is StaticBody3D:
					has_collision = true
					break

			if not has_collision and mesh_instance.mesh:
				mesh_instance.create_trimesh_collision()
				count += 1

	# Recurse into children
	for child in node.get_children():
		count += _add_wall_collision_recursive(child)

	return count


## Check if a mesh name indicates it's a wall (should have collision)
## NOTE: Be conservative - only add collision to explicitly named walls
func _is_wall_mesh(mesh_name: String) -> bool:
	# Skip floors, ground, arena surfaces - these should NOT have collision from GLB
	# (we create our own floor collision with the spike pit hole)
	var skip_keywords: Array[String] = [
		# Floor/ground surfaces
		"floor", "ground", "arena", "pit", "surface", "terrain",
		# Decorative elements
		"arch", "archway", "opening", "passage", "doorway",
		"railing", "rail", "handrail",
		"trim", "molding", "decoration", "decor",
		"banner", "flag", "cloth", "rope",
		"torch", "light", "lamp", "candle",
		"plant", "vine", "foliage",
		# Generic materials (too broad - could match floors)
		"stone", "brick", "concrete", "metal", "wood",
	]

	# Check for skip keywords first
	for keyword: String in skip_keywords:
		if keyword in mesh_name:
			return false

	# Only add collision to explicitly named walls/barriers
	var wall_keywords: Array[String] = [
		"wall", "pillar", "column", "barrier", "fence",
		"stand", "seating", "bench", "seat",
		"gate", "post", "buttress"
	]

	# Check for wall keywords
	for keyword: String in wall_keywords:
		if keyword in mesh_name:
			return true

	return false


## Generate collision shapes for terrain and building meshes
## WARNING: This creates trimesh collision for ALL geometry including decorative
## elements (archways, railings, window frames) which blocks player movement.
## For arenas with detailed GLB models, use manual collision shapes instead.
func _generate_terrain_collision() -> void:
	# Find the terrain node
	var terrain: Node3D = get_node_or_null("Terrain")
	if terrain:
		_add_collision_to_meshes(terrain)
		print("[Bloodsand Arena] Generated collision for terrain")


## Recursively add collision to all MeshInstance3D nodes
## WARNING: This will block ALL mesh geometry including passable areas like doorways.
## Only use on meshes that should be fully solid (floors, walls without openings).
func _add_collision_to_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		# Check if collision already exists
		var has_collision := false
		for child in mesh_instance.get_children():
			if child is StaticBody3D:
				has_collision = true
				break

		if not has_collision and mesh_instance.mesh:
			# Create static body with trimesh collision
			mesh_instance.create_trimesh_collision()

	# Recurse into children
	for child in node.get_children():
		_add_collision_to_meshes(child)


## Add a simple box collision at a position (for manual collision placement)
func _add_box_collision(parent: Node3D, pos: Vector3, size: Vector3, name_suffix: String = "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "ManualCollision" + name_suffix
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	parent.add_child(body)
	return body


## Spawn the Arena Master NPC (Gormund the Pitmaster)
func _spawn_arena_master() -> void:
	var master_pos: Marker3D = get_node_or_null("ArenaMasterPosition") as Marker3D
	if not master_pos:
		push_warning("[Bloodsand Arena] ArenaMasterPosition marker not found")
		# Fallback position if marker missing
		_spawn_arena_master_at(Vector3(28, 0, 2))
		return

	_spawn_arena_master_at(master_pos.position)


## Actually spawn the arena master at a position
func _spawn_arena_master_at(pos: Vector3) -> void:
	# Spawn the arena master NPC
	var arena_master := ArenaMaster.new()
	arena_master.name = "ArenaMaster"
	arena_master.region_id = ZONE_ID
	add_child(arena_master)

	# Set position AFTER adding to tree (ensures proper transform)
	arena_master.position = pos

	print("[Bloodsand Arena] Arena Master (Gormund) spawned at %s" % pos)


## Spawn shops at positions defined in scene
func _spawn_shops() -> void:
	var shop_positions: Node3D = get_node_or_null("ShopPositions")
	if not shop_positions:
		push_warning("[Bloodsand Arena] ShopPositions node not found in scene")
		return

	var shops_container := Node3D.new()
	shops_container.name = "ArenaShops"
	add_child(shops_container)

	# Iterate through shop position markers and spawn appropriate NPCs
	for marker: Node in shop_positions.get_children():
		if not marker is Marker3D:
			continue

		var shop_type: String = marker.get_meta("shop_type", "")
		var npc_name: String = marker.get_meta("npc_name", "Merchant")
		var loot_tier_str: String = marker.get_meta("loot_tier", "common")
		var pos: Vector3 = marker.global_position

		# Convert tier string to enum
		var loot_tier: LootTables.LootTier = LootTables.LootTier.COMMON
		match loot_tier_str:
			"uncommon": loot_tier = LootTables.LootTier.UNCOMMON
			"rare": loot_tier = LootTables.LootTier.RARE
			"epic": loot_tier = LootTables.LootTier.EPIC

		match shop_type:
			"tavern":
				_spawn_tavern(shops_container, pos, npc_name)
			"general":
				_spawn_merchant_at(shops_container, pos, npc_name, loot_tier, "general")
			"blacksmith":
				_spawn_merchant_at(shops_container, pos, npc_name, loot_tier, "blacksmith")
			"armor":
				_spawn_merchant_at(shops_container, pos, npc_name, loot_tier, "armor")
			"alchemist":
				_spawn_alchemist(shops_container, pos, npc_name, loot_tier)
			_:
				push_warning("[Bloodsand Arena] Unknown shop type: %s" % shop_type)

	print("[Bloodsand Arena] Spawned arena shops")


## Spawn tavern with innkeeper
func _spawn_tavern(parent: Node3D, pos: Vector3, npc_name: String = "Innkeeper") -> void:
	var tavern := Node3D.new()
	tavern.name = "Tavern"
	tavern.position = pos
	parent.add_child(tavern)

	# Spawn innkeeper NPC
	var innkeeper: Innkeeper = Innkeeper.new()
	innkeeper.position = Vector3.ZERO
	innkeeper.merchant_name = npc_name

	# Check if name suggests female (Greta, etc.)
	var female_names: Array[String] = ["Greta", "Marta", "Helga", "Elspeth", "Brynn"]
	var is_female: bool = false
	for fname in female_names:
		if npc_name.begins_with(fname):
			is_female = true
			break

	if is_female:
		innkeeper.use_random_gender = false
		innkeeper.is_male = false
		var sprite_tex: Texture2D = load("res://assets/sprites/npcs/merchants/Innkeeper_woman.png")
		if sprite_tex:
			innkeeper.sprite_texture = sprite_tex
			innkeeper.sprite_h_frames = 5
			innkeeper.sprite_v_frames = 1
			innkeeper.sprite_pixel_size = 0.0378

	innkeeper.region_id = ZONE_ID
	tavern.add_child(innkeeper)

	# Add tavern light
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.5)
	light.light_energy = 1.0
	light.omni_range = 8.0
	light.position = Vector3(0, 3, 0)
	tavern.add_child(light)

	print("[Bloodsand Arena] Tavern spawned with innkeeper %s" % npc_name)


## Spawn a merchant at a position with given parameters
func _spawn_merchant_at(parent: Node3D, pos: Vector3, npc_name: String, tier: LootTables.LootTier, shop_type: String) -> void:
	var merchant: Merchant = Merchant.spawn_merchant(
		parent,
		pos,
		npc_name,
		tier,
		shop_type
	)
	if merchant:
		merchant.region_id = ZONE_ID
		print("[Bloodsand Arena] %s (%s) spawned" % [npc_name, shop_type])


## Spawn alchemist with purple glow
func _spawn_alchemist(parent: Node3D, pos: Vector3, npc_name: String, tier: LootTables.LootTier) -> void:
	var merchant: Merchant = Merchant.spawn_merchant(
		parent,
		pos,
		npc_name,
		tier,
		"alchemist"
	)
	if merchant:
		merchant.region_id = ZONE_ID

		# Add purple glow for alchemist shop
		var light := OmniLight3D.new()
		light.light_color = Color(0.6, 0.3, 0.8)
		light.light_energy = 0.8
		light.omni_range = 6.0
		light.position = Vector3(0, 2, 0)
		merchant.add_child(light)

		print("[Bloodsand Arena] Alchemist %s spawned" % npc_name)


## Get gladiator spawn positions for tournament fights
func get_gladiator_spawn_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var spawns: Node3D = get_node_or_null("GladiatorSpawns")
	if not spawns:
		return positions
	for child: Node in spawns.get_children():
		if child is Marker3D:
			positions.append(child.global_position)
	return positions


## Get the arena center position
func get_arena_center() -> Vector3:
	var center: Node3D = get_node_or_null("ArenaCenter")
	if center:
		return center.global_position
	return Vector3.ZERO


## Get the waiting area position (where player goes between waves)
func get_waiting_area_position() -> Vector3:
	var waiting: Node3D = get_node_or_null("WaitingArea")
	if waiting:
		return waiting.global_position

	# Fallback to arena master position if waiting area not defined
	var master_pos: Node3D = get_node_or_null("ArenaMasterPosition")
	if master_pos:
		return master_pos.global_position

	# Ultimate fallback
	return Vector3(5, 0, 40)


## Setup arena barrier (invisible wall during combat)
func _setup_arena_barrier() -> void:
	# Check if barrier exists in scene
	arena_barrier = get_node_or_null("ArenaBarrier") as StaticBody3D

	if not arena_barrier:
		# Create barrier programmatically
		arena_barrier = _create_arena_barrier()

	# Start with barrier disabled
	disable_arena_barrier()


## Create the arena barrier programmatically
func _create_arena_barrier() -> StaticBody3D:
	var barrier := StaticBody3D.new()
	barrier.name = "ArenaBarrier"

	# Get arena center for positioning
	var center: Vector3 = get_arena_center()
	barrier.global_position = center

	# Create invisible wall collision - a ring around the arena
	# We'll use 4 box colliders to form a square boundary
	var barrier_radius: float = 18.0  # Distance from center to barrier
	var barrier_height: float = 10.0  # Tall enough to prevent jumping over
	var barrier_thickness: float = 1.0

	# North wall
	var north_wall := _create_barrier_wall(
		Vector3(0, barrier_height / 2, -barrier_radius),
		Vector3(barrier_radius * 2, barrier_height, barrier_thickness)
	)
	barrier.add_child(north_wall)

	# South wall
	var south_wall := _create_barrier_wall(
		Vector3(0, barrier_height / 2, barrier_radius),
		Vector3(barrier_radius * 2, barrier_height, barrier_thickness)
	)
	barrier.add_child(south_wall)

	# East wall
	var east_wall := _create_barrier_wall(
		Vector3(barrier_radius, barrier_height / 2, 0),
		Vector3(barrier_thickness, barrier_height, barrier_radius * 2)
	)
	barrier.add_child(east_wall)

	# West wall
	var west_wall := _create_barrier_wall(
		Vector3(-barrier_radius, barrier_height / 2, 0),
		Vector3(barrier_thickness, barrier_height, barrier_radius * 2)
	)
	barrier.add_child(west_wall)

	# Set collision layer (layer 1 for world collision)
	barrier.collision_layer = 1
	barrier.collision_mask = 0

	add_child(barrier)
	return barrier


## Create a single barrier wall segment
func _create_barrier_wall(pos: Vector3, size: Vector3) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = pos
	return collision


## Connect to TournamentManager signals
func _connect_tournament_signals() -> void:
	if not TournamentManager:
		push_warning("[Bloodsand Arena] TournamentManager not found")
		return

	TournamentManager.barrier_enabled.connect(enable_arena_barrier)
	TournamentManager.barrier_disabled.connect(disable_arena_barrier)


## Enable the arena barrier (prevents leaving during combat)
func enable_arena_barrier() -> void:
	if arena_barrier:
		arena_barrier.collision_layer = 1  # Enable collision
		print("[Bloodsand Arena] Arena barrier ENABLED")


## Disable the arena barrier (allows leaving between waves)
func disable_arena_barrier() -> void:
	if arena_barrier:
		arena_barrier.collision_layer = 0  # Disable collision
		print("[Bloodsand Arena] Arena barrier DISABLED")


func _exit_tree() -> void:
	# Disconnect TournamentManager signals
	if TournamentManager:
		if TournamentManager.barrier_enabled.is_connected(enable_arena_barrier):
			TournamentManager.barrier_enabled.disconnect(enable_arena_barrier)
		if TournamentManager.barrier_disabled.is_connected(disable_arena_barrier):
			TournamentManager.barrier_disabled.disconnect(disable_arena_barrier)
