## vampire_crypt.gd - Hidden dungeon for the vampire cult questline finale
## Location: Northeast of Whaeler's Drake in the mountains
## A dark crypt where the cult is attempting to awaken an ancient vampire
extends Node3D

const ZONE_ID := "vampire_crypt"

## Floor heights - multiple levels descending into darkness
const ENTRY_LEVEL := 0.0
const CORRIDOR_LEVEL := -4.0
const RITUAL_LEVEL := -8.0
const INNER_SANCTUM_LEVEL := -12.0

## Navigation
var nav_region: NavigationRegion3D

## Materials (created once, reused)
var stone_mat: StandardMaterial3D
var floor_mat: StandardMaterial3D
var blood_stone_mat: StandardMaterial3D
var metal_mat: StandardMaterial3D
var coffin_mat: StandardMaterial3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Vampire Crypt")

	_create_materials()
	_setup_navigation()
	_create_entry_chamber()
	_create_west_corridor()
	_create_east_corridor()
	_create_ritual_chamber()
	_create_inner_sanctum()
	_create_trapped_areas()
	_spawn_cult_decorations()
	_spawn_lighting()
	_spawn_enemies()
	_spawn_loot()
	_spawn_portals()

	# Quest trigger for entering crypt
	QuestManager.on_location_reached("vampire_crypt_entered")

	print("[VampireCrypt] Hidden dungeon loaded - Cult questline finale")


func _create_materials() -> void:
	# Dark stone walls
	stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.12, 0.1, 0.14)  # Very dark purple-gray
	stone_mat.roughness = 0.95

	# Floor - even darker
	floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.08, 0.06, 0.1)
	floor_mat.roughness = 0.9

	# Blood-stained stone for ritual areas
	blood_stone_mat = StandardMaterial3D.new()
	blood_stone_mat.albedo_color = Color(0.15, 0.05, 0.08)  # Dark crimson
	blood_stone_mat.roughness = 0.85

	# Rusted metal for bars and gates
	metal_mat = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.25, 0.18, 0.15)
	metal_mat.roughness = 0.7
	metal_mat.metallic = 0.4

	# Coffin wood - ancient and dark
	coffin_mat = StandardMaterial3D.new()
	coffin_mat.albedo_color = Color(0.18, 0.12, 0.08)
	coffin_mat.roughness = 0.9


func _setup_navigation() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	add_child(nav_region)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.2
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0

	nav_region.navigation_mesh = nav_mesh
	call_deferred("_bake_navigation")


func _bake_navigation() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()
		print("[VampireCrypt] Navigation mesh baked!")


## Entry chamber - where player arrives from the mountain passage
func _create_entry_chamber() -> void:
	var chamber_center := Vector3(0, ENTRY_LEVEL, 0)
	var width := 12.0
	var depth := 12.0
	var height := 5.0

	# Floor
	var floor_mesh := CSGBox3D.new()
	floor_mesh.name = "Entry_Floor"
	floor_mesh.size = Vector3(width, 1, depth)
	floor_mesh.position = chamber_center + Vector3(0, -0.5, 0)
	floor_mesh.material = floor_mat
	floor_mesh.use_collision = true
	add_child(floor_mesh)

	# Ceiling
	var ceiling := CSGBox3D.new()
	ceiling.name = "Entry_Ceiling"
	ceiling.size = Vector3(width, 0.5, depth)
	ceiling.position = chamber_center + Vector3(0, height, 0)
	ceiling.material = stone_mat
	ceiling.use_collision = true
	add_child(ceiling)

	# North wall (solid)
	_create_wall(chamber_center + Vector3(0, height / 2.0, -depth / 2.0 - 0.5), Vector3(width, height, 1))

	# South wall with doorway (to outside)
	_create_wall_with_doorway(chamber_center, Vector3(width, height, depth), "south", 4.0)

	# East wall with doorway (to east corridor)
	_create_wall_with_doorway(chamber_center, Vector3(width, height, depth), "east", 4.0)

	# West wall with doorway (to west corridor)
	_create_wall_with_doorway(chamber_center, Vector3(width, height, depth), "west", 4.0)

	# Decorative coffins in alcoves
	_create_coffin(chamber_center + Vector3(-4, 0, -4), 0)
	_create_coffin(chamber_center + Vector3(4, 0, -4), 0)

	print("[VampireCrypt] Entry chamber created")


## West corridor - leads to ritual chamber with traps
func _create_west_corridor() -> void:
	var corridor_start := Vector3(-10, ENTRY_LEVEL, 0)
	var corridor_end := Vector3(-10, CORRIDOR_LEVEL, -20)

	# Descending corridor
	_create_corridor_segment(corridor_start, Vector3(6, 4, 8), "WestCorridor_1")

	# Stairs down
	_create_stairs(Vector3(-10, ENTRY_LEVEL, -6), Vector3(-10, CORRIDOR_LEVEL, -14), 8)

	# Lower corridor section
	_create_corridor_segment(Vector3(-10, CORRIDOR_LEVEL, -18), Vector3(6, 4, 8), "WestCorridor_2")

	# Coffin alcoves along corridor
	_create_coffin(Vector3(-12, ENTRY_LEVEL, 2), PI / 2)
	_create_coffin(Vector3(-12, CORRIDOR_LEVEL, -16), PI / 2)

	print("[VampireCrypt] West corridor created")


## East corridor - locked gate, leads to inner sanctum
func _create_east_corridor() -> void:
	var corridor_start := Vector3(10, ENTRY_LEVEL, 0)

	# Upper corridor
	_create_corridor_segment(corridor_start, Vector3(6, 4, 8), "EastCorridor_1")

	# Stairs down
	_create_stairs(Vector3(10, ENTRY_LEVEL, -6), Vector3(10, CORRIDOR_LEVEL, -14), 8)

	# Lower corridor - this section has the locked gate
	_create_corridor_segment(Vector3(10, CORRIDOR_LEVEL, -18), Vector3(6, 4, 12), "EastCorridor_2")

	# More stairs to inner sanctum
	_create_stairs(Vector3(10, CORRIDOR_LEVEL, -26), Vector3(10, INNER_SANCTUM_LEVEL, -34), 8)

	# Final corridor to sanctum
	_create_corridor_segment(Vector3(10, INNER_SANCTUM_LEVEL, -38), Vector3(6, 4, 8), "EastCorridor_3")

	# Coffins
	_create_coffin(Vector3(12, ENTRY_LEVEL, 2), -PI / 2)
	_create_coffin(Vector3(12, CORRIDOR_LEVEL, -20), -PI / 2)

	print("[VampireCrypt] East corridor created")


## Central ritual chamber - where cult performs awakening ritual
func _create_ritual_chamber() -> void:
	var chamber_center := Vector3(0, RITUAL_LEVEL, -30)
	var width := 20.0
	var depth := 20.0
	var height := 8.0

	# Blood-stained floor
	var floor_mesh := CSGBox3D.new()
	floor_mesh.name = "Ritual_Floor"
	floor_mesh.size = Vector3(width, 1, depth)
	floor_mesh.position = chamber_center + Vector3(0, -0.5, 0)
	floor_mesh.material = blood_stone_mat
	floor_mesh.use_collision = true
	add_child(floor_mesh)

	# High vaulted ceiling
	var ceiling := CSGBox3D.new()
	ceiling.name = "Ritual_Ceiling"
	ceiling.size = Vector3(width, 0.5, depth)
	ceiling.position = chamber_center + Vector3(0, height, 0)
	ceiling.material = stone_mat
	ceiling.use_collision = true
	add_child(ceiling)

	# Walls with connections
	# North wall - passage to west corridor
	_create_wall(chamber_center + Vector3(-7, height / 2.0, -depth / 2.0 - 0.5), Vector3(6, height, 1))
	_create_wall(chamber_center + Vector3(7, height / 2.0, -depth / 2.0 - 0.5), Vector3(6, height, 1))

	# South wall - solid
	_create_wall(chamber_center + Vector3(0, height / 2.0, depth / 2.0 + 0.5), Vector3(width, height, 1))

	# East wall - solid
	_create_wall(chamber_center + Vector3(width / 2.0 + 0.5, height / 2.0, 0), Vector3(1, height, depth))

	# West wall - connection from west corridor
	_create_wall(chamber_center + Vector3(-width / 2.0 - 0.5, height / 2.0, -5), Vector3(1, height, 10))
	_create_wall(chamber_center + Vector3(-width / 2.0 - 0.5, height / 2.0, 5), Vector3(1, height, 10))

	# Central ritual altar/platform
	var altar := CSGBox3D.new()
	altar.name = "RitualAltar"
	altar.size = Vector3(6, 1.5, 6)
	altar.position = chamber_center + Vector3(0, 0.75, 0)
	altar.material = blood_stone_mat
	altar.use_collision = true
	add_child(altar)

	# Pillars around the chamber
	var pillar_positions := [
		chamber_center + Vector3(-7, 0, -7),
		chamber_center + Vector3(7, 0, -7),
		chamber_center + Vector3(-7, 0, 7),
		chamber_center + Vector3(7, 0, 7),
	]

	for i in range(pillar_positions.size()):
		_create_pillar(pillar_positions[i], height, "RitualPillar_%d" % i)

	# Coffins around the edges - cult members' resting places
	_create_coffin(chamber_center + Vector3(-8, 0, 0), PI / 2)
	_create_coffin(chamber_center + Vector3(8, 0, 0), -PI / 2)
	_create_coffin(chamber_center + Vector3(0, 0, 8), 0)

	print("[VampireCrypt] Ritual chamber created")


## Inner sanctum - ancient vampire's resting place
func _create_inner_sanctum() -> void:
	var chamber_center := Vector3(0, INNER_SANCTUM_LEVEL, -50)
	var width := 16.0
	var depth := 16.0
	var height := 10.0

	# Floor
	var floor_mesh := CSGBox3D.new()
	floor_mesh.name = "Sanctum_Floor"
	floor_mesh.size = Vector3(width, 1, depth)
	floor_mesh.position = chamber_center + Vector3(0, -0.5, 0)
	floor_mesh.material = blood_stone_mat
	floor_mesh.use_collision = true
	add_child(floor_mesh)

	# Domed ceiling effect (simple approximation)
	var ceiling := CSGBox3D.new()
	ceiling.name = "Sanctum_Ceiling"
	ceiling.size = Vector3(width, 0.5, depth)
	ceiling.position = chamber_center + Vector3(0, height, 0)
	ceiling.material = stone_mat
	ceiling.use_collision = true
	add_child(ceiling)

	# Walls - entrance from east corridor only
	# North wall - solid
	_create_wall(chamber_center + Vector3(0, height / 2.0, -depth / 2.0 - 0.5), Vector3(width, height, 1))

	# South wall - solid
	_create_wall(chamber_center + Vector3(0, height / 2.0, depth / 2.0 + 0.5), Vector3(width, height, 1))

	# West wall - solid
	_create_wall(chamber_center + Vector3(-width / 2.0 - 0.5, height / 2.0, 0), Vector3(1, height, depth))

	# East wall - with entrance from corridor
	_create_wall(chamber_center + Vector3(width / 2.0 + 0.5, height / 2.0, -4), Vector3(1, height, 8))
	_create_wall(chamber_center + Vector3(width / 2.0 + 0.5, height / 2.0, 4), Vector3(1, height, 8))

	# ANCIENT VAMPIRE'S SARCOPHAGUS - centerpiece
	_create_sarcophagus(chamber_center + Vector3(0, 0, -2))

	# Smaller coffins for vampire spawn/thralls
	_create_coffin(chamber_center + Vector3(-5, 0, 4), PI / 4)
	_create_coffin(chamber_center + Vector3(5, 0, 4), -PI / 4)

	# Pillars
	var pillar_positions := [
		chamber_center + Vector3(-5, 0, -5),
		chamber_center + Vector3(5, 0, -5),
	]

	for i in range(pillar_positions.size()):
		_create_pillar(pillar_positions[i], height, "SanctumPillar_%d" % i)

	print("[VampireCrypt] Inner sanctum created")


## Create trapped/locked areas
func _create_trapped_areas() -> void:
	# Locked gate to inner sanctum (east corridor)
	var gate_pos := Vector3(10, CORRIDOR_LEVEL, -22)
	var locked_gate := ZoneDoor.new()
	locked_gate.name = "SanctumGate"
	locked_gate.position = gate_pos
	locked_gate.door_name = "Ancient Iron Gate"
	locked_gate.is_locked = true
	locked_gate.lock_difficulty = 15  # High difficulty lock
	locked_gate.target_scene = ""  # Not a zone door, just a barrier
	locked_gate.show_frame = false
	add_child(locked_gate)

	# Create actual gate bars visual
	_create_gate_bars(gate_pos, Vector3(4, 4, 0.3))

	# Pressure plate trap in west corridor
	_create_trap_trigger(Vector3(-10, CORRIDOR_LEVEL, -10), "poison_dart_trap")

	# Spike trap near ritual chamber entrance
	_create_trap_trigger(Vector3(-6, RITUAL_LEVEL, -22), "spike_trap")

	print("[VampireCrypt] Trapped areas created")


## Spawn cult decorations - ritual circles, candles, symbols
func _spawn_cult_decorations() -> void:
	# Ritual circle on altar (emissive floor decal simulation)
	var ritual_circle := _create_ritual_circle(Vector3(0, RITUAL_LEVEL + 1.51, -30), 5.0)
	add_child(ritual_circle)

	# Cult symbols on walls (crimson glowing)
	var symbol_positions := [
		Vector3(-9, RITUAL_LEVEL + 3, -30),  # West wall of ritual chamber
		Vector3(9, RITUAL_LEVEL + 3, -30),   # East wall
		Vector3(0, RITUAL_LEVEL + 5, -39),   # North wall
		Vector3(-7, INNER_SANCTUM_LEVEL + 4, -50),  # Sanctum west
		Vector3(7, INNER_SANCTUM_LEVEL + 4, -50),   # Sanctum east
	]

	for i in range(symbol_positions.size()):
		_create_cult_symbol(symbol_positions[i], "CultSymbol_%d" % i)

	# Candle clusters
	var candle_positions := [
		Vector3(-3, RITUAL_LEVEL + 1.5, -33),  # Altar corners
		Vector3(3, RITUAL_LEVEL + 1.5, -33),
		Vector3(-3, RITUAL_LEVEL + 1.5, -27),
		Vector3(3, RITUAL_LEVEL + 1.5, -27),
		Vector3(0, INNER_SANCTUM_LEVEL, -54),  # Around sarcophagus
		Vector3(-2, INNER_SANCTUM_LEVEL, -52),
		Vector3(2, INNER_SANCTUM_LEVEL, -52),
	]

	for i in range(candle_positions.size()):
		_create_candle_cluster(candle_positions[i], "CandleCluster_%d" % i)

	print("[VampireCrypt] Cult decorations spawned")


## Spawn lighting - very dark with red accents
func _spawn_lighting() -> void:
	# World environment - extremely dark, PS1 horror atmosphere
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.005, 0.015)  # Near black with slight purple
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.02, 0.03)  # Very dim red-purple ambient
	env.ambient_light_energy = 0.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.01, 0.02)
	env.fog_density = 0.04  # Heavy fog for limited visibility

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Entry chamber - dim torch light
	_spawn_torch_light(Vector3(0, ENTRY_LEVEL + 3, 4), Color(1.0, 0.6, 0.3), 0.8, 8.0)

	# West corridor - sparse lighting
	_spawn_torch_light(Vector3(-10, ENTRY_LEVEL + 2, -2), Color(1.0, 0.5, 0.3), 0.6, 6.0)
	_spawn_torch_light(Vector3(-10, CORRIDOR_LEVEL + 2, -16), Color(0.8, 0.3, 0.2), 0.5, 5.0)

	# East corridor - even darker
	_spawn_torch_light(Vector3(10, ENTRY_LEVEL + 2, -2), Color(0.9, 0.4, 0.3), 0.5, 5.0)
	_spawn_torch_light(Vector3(10, CORRIDOR_LEVEL + 2, -20), Color(0.7, 0.2, 0.2), 0.4, 4.0)

	# Ritual chamber - crimson glow from ritual
	_spawn_torch_light(Vector3(0, RITUAL_LEVEL + 4, -30), Color(0.8, 0.1, 0.1), 1.5, 12.0)  # Central ritual glow
	_spawn_torch_light(Vector3(-7, RITUAL_LEVEL + 2, -37), Color(1.0, 0.4, 0.2), 0.6, 6.0)
	_spawn_torch_light(Vector3(7, RITUAL_LEVEL + 2, -37), Color(1.0, 0.4, 0.2), 0.6, 6.0)

	# Inner sanctum - ominous red glow from sarcophagus
	_spawn_torch_light(Vector3(0, INNER_SANCTUM_LEVEL + 2, -52), Color(0.9, 0.05, 0.1), 2.0, 10.0)  # Sarcophagus glow
	_spawn_torch_light(Vector3(-6, INNER_SANCTUM_LEVEL + 3, -50), Color(0.6, 0.1, 0.15), 0.8, 6.0)
	_spawn_torch_light(Vector3(6, INNER_SANCTUM_LEVEL + 3, -50), Color(0.6, 0.1, 0.15), 0.8, 6.0)

	print("[VampireCrypt] Lighting spawned")


## Spawn undead enemies
func _spawn_enemies() -> void:
	# Entry chamber - Soul Shades guard the entrance
	_spawn_undead_enemy(Vector3(-3, ENTRY_LEVEL, -3), "skeleton_shade", "Soul Shade")
	_spawn_undead_enemy(Vector3(3, ENTRY_LEVEL, -3), "skeleton_shade", "Soul Shade")

	# West corridor
	_spawn_undead_enemy(Vector3(-10, ENTRY_LEVEL, 2), "skeleton_shade", "Soul Shade")
	_spawn_undead_enemy(Vector3(-10, CORRIDOR_LEVEL, -18), "skeleton_shade", "Soul Shade")

	# East corridor
	_spawn_undead_enemy(Vector3(10, ENTRY_LEVEL, 2), "skeleton_shade", "Soul Shade")
	_spawn_undead_enemy(Vector3(10, CORRIDOR_LEVEL, -16), "skeleton_shade", "Soul Shade")

	# Ritual chamber - multiple enemies including cult leaders
	_spawn_undead_enemy(Vector3(-6, RITUAL_LEVEL, -25), "skeleton_shade", "Soul Shade")
	_spawn_undead_enemy(Vector3(6, RITUAL_LEVEL, -25), "skeleton_shade", "Soul Shade")
	_spawn_undead_enemy(Vector3(-5, RITUAL_LEVEL, -35), "skeleton_shade", "Soul Shade")
	_spawn_undead_enemy(Vector3(5, RITUAL_LEVEL, -35), "skeleton_shade", "Soul Shade")

	# Inner sanctum - the ancient vampire and thralls
	_spawn_undead_enemy(Vector3(-4, INNER_SANCTUM_LEVEL, -46), "skeleton_shade", "Vampire Thrall")
	_spawn_undead_enemy(Vector3(4, INNER_SANCTUM_LEVEL, -46), "skeleton_shade", "Vampire Thrall")

	# BOSS: Ancient Vampire (uses vampire_lord data with separate state sprites)
	var idle_tex: Texture2D = load("res://Sprite folders grab bag/vampirelord_pointing.png")
	var walk_tex: Texture2D = load("res://Sprite folders grab bag/vampirelord_walking.png")
	var death_tex: Texture2D = load("res://Sprite folders grab bag/vampirelord_dying.png")

	if idle_tex:
		var boss := EnemyBase.spawn_billboard_enemy(
			self,
			Vector3(0, INNER_SANCTUM_LEVEL, -52),
			"res://data/enemies/vampire_lord.tres",
			idle_tex,
			5, 1  # 5x1 sprite sheet for idle/pointing
		)
		if boss:
			boss.name = "AncientVampire"
			# Setup separate textures for walk and death states
			if boss.billboard_sprite:
				boss.billboard_sprite.setup_state_textures(
					idle_tex, 5, 1, 5,   # idle: 5 frames
					walk_tex, 5, 1, 5,   # walk: 5 frames
					death_tex, 5, 1, 5,  # death: 5 frames
					idle_tex, 5, 1, 5    # attack: use idle/pointing
				)
			# Apply crimson undead glow
			boss.call_deferred("_check_and_apply_undead_glow", "res://data/enemies/vampire_lord.tres")
			print("[VampireCrypt] Spawned Ancient Vampire boss with state-based sprites!")

	print("[VampireCrypt] Enemies spawned")


## Spawn loot chests
func _spawn_loot() -> void:
	# Entry chamber - basic loot
	var entry_chest := Chest.spawn_chest(
		self,
		Vector3(5, ENTRY_LEVEL, 4),
		"Dusty Crypt Chest",
		false, 0,
		false, ""
	)
	if entry_chest:
		entry_chest.setup_with_loot(LootTables.LootTier.COMMON)

	# West corridor - trapped chest
	var trapped_chest := Chest.spawn_chest(
		self,
		Vector3(-12, CORRIDOR_LEVEL, -20),
		"Suspicious Offering Box",
		true, 12,
		true, ""  # is_trapped = true
	)
	if trapped_chest:
		trapped_chest.is_trapped = true
		trapped_chest.trap_damage = 25
		trapped_chest.setup_with_loot(LootTables.LootTier.UNCOMMON)

	# Ritual chamber - cult treasure
	var ritual_chest := Chest.spawn_chest(
		self,
		Vector3(-8, RITUAL_LEVEL, -38),
		"Cult Tribute Chest",
		true, 14,
		false, ""
	)
	if ritual_chest:
		ritual_chest.setup_with_loot(LootTables.LootTier.RARE)

	# Inner sanctum - ancient vampire's hoard (boss loot)
	var boss_chest := Chest.spawn_chest(
		self,
		Vector3(0, INNER_SANCTUM_LEVEL, -58),
		"Ancient Vampire's Hoard",
		true, 16,
		false, ""
	)
	if boss_chest:
		boss_chest.setup_with_loot(LootTables.LootTier.EPIC)

	print("[VampireCrypt] Loot chests spawned")


## Spawn portals - exit back to Whaeler's Drake area
func _spawn_portals() -> void:
	# Exit portal at entry chamber (south wall)
	var exit_portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, ENTRY_LEVEL, 7),
		"res://scenes/levels/whalers_abyss.tscn",
		"from_vampire_crypt",
		"Exit to Mountain Pass"
	)
	exit_portal.rotation.y = PI  # Face into crypt
	exit_portal.show_frame = true

	# Spawn point for arriving from Whalers Abyss
	var from_whalers := Node3D.new()
	from_whalers.name = "from_whalers_abyss"
	from_whalers.position = Vector3(0, ENTRY_LEVEL + 0.1, 4)
	from_whalers.add_to_group("spawn_points")
	from_whalers.set_meta("spawn_id", "from_whalers_abyss")
	add_child(from_whalers)

	# Default spawn
	var default_spawn := Node3D.new()
	default_spawn.name = "default"
	default_spawn.position = Vector3(0, ENTRY_LEVEL + 0.1, 4)
	default_spawn.add_to_group("spawn_points")
	default_spawn.set_meta("spawn_id", "default")
	add_child(default_spawn)

	print("[VampireCrypt] Portals spawned")


## ============================================================================
## HELPER FUNCTIONS
## ============================================================================

func _create_wall(pos: Vector3, size: Vector3) -> void:
	var wall := CSGBox3D.new()
	wall.name = "Wall"
	wall.size = size
	wall.position = pos
	wall.material = stone_mat
	wall.use_collision = true
	add_child(wall)


func _create_wall_with_doorway(center: Vector3, room_size: Vector3, side: String, door_width: float) -> void:
	var half_x := room_size.x / 2.0
	var half_z := room_size.z / 2.0
	var height := room_size.y
	var wall_thickness := 1.0

	match side:
		"south":
			var wall_z := center.z + half_z + wall_thickness / 2.0
			var side_width := (room_size.x - door_width) / 2.0
			if side_width > 0:
				var left := CSGBox3D.new()
				left.name = "SouthWall_Left"
				left.size = Vector3(side_width, height, wall_thickness)
				left.position = Vector3(center.x - half_x + side_width / 2.0, center.y + height / 2.0, wall_z)
				left.material = stone_mat
				left.use_collision = true
				add_child(left)

				var right := CSGBox3D.new()
				right.name = "SouthWall_Right"
				right.size = Vector3(side_width, height, wall_thickness)
				right.position = Vector3(center.x + half_x - side_width / 2.0, center.y + height / 2.0, wall_z)
				right.material = stone_mat
				right.use_collision = true
				add_child(right)

		"east":
			var wall_x := center.x + half_x + wall_thickness / 2.0
			var side_depth := (room_size.z - door_width) / 2.0
			if side_depth > 0:
				var front := CSGBox3D.new()
				front.name = "EastWall_Front"
				front.size = Vector3(wall_thickness, height, side_depth)
				front.position = Vector3(wall_x, center.y + height / 2.0, center.z - half_z + side_depth / 2.0)
				front.material = stone_mat
				front.use_collision = true
				add_child(front)

				var back := CSGBox3D.new()
				back.name = "EastWall_Back"
				back.size = Vector3(wall_thickness, height, side_depth)
				back.position = Vector3(wall_x, center.y + height / 2.0, center.z + half_z - side_depth / 2.0)
				back.material = stone_mat
				back.use_collision = true
				add_child(back)

		"west":
			var wall_x := center.x - half_x - wall_thickness / 2.0
			var side_depth := (room_size.z - door_width) / 2.0
			if side_depth > 0:
				var front := CSGBox3D.new()
				front.name = "WestWall_Front"
				front.size = Vector3(wall_thickness, height, side_depth)
				front.position = Vector3(wall_x, center.y + height / 2.0, center.z - half_z + side_depth / 2.0)
				front.material = stone_mat
				front.use_collision = true
				add_child(front)

				var back := CSGBox3D.new()
				back.name = "WestWall_Back"
				back.size = Vector3(wall_thickness, height, side_depth)
				back.position = Vector3(wall_x, center.y + height / 2.0, center.z + half_z - side_depth / 2.0)
				back.material = stone_mat
				back.use_collision = true
				add_child(back)


func _create_corridor_segment(center: Vector3, size: Vector3, corridor_name: String) -> void:
	# Floor
	var floor_mesh := CSGBox3D.new()
	floor_mesh.name = corridor_name + "_Floor"
	floor_mesh.size = Vector3(size.x, 1, size.z)
	floor_mesh.position = center + Vector3(0, -0.5, 0)
	floor_mesh.material = floor_mat
	floor_mesh.use_collision = true
	add_child(floor_mesh)

	# Ceiling
	var ceiling := CSGBox3D.new()
	ceiling.name = corridor_name + "_Ceiling"
	ceiling.size = Vector3(size.x, 0.5, size.z)
	ceiling.position = center + Vector3(0, size.y, 0)
	ceiling.material = stone_mat
	ceiling.use_collision = true
	add_child(ceiling)

	# Side walls
	var wall_left := CSGBox3D.new()
	wall_left.name = corridor_name + "_LeftWall"
	wall_left.size = Vector3(0.5, size.y, size.z)
	wall_left.position = center + Vector3(-size.x / 2.0 - 0.25, size.y / 2.0, 0)
	wall_left.material = stone_mat
	wall_left.use_collision = true
	add_child(wall_left)

	var wall_right := CSGBox3D.new()
	wall_right.name = corridor_name + "_RightWall"
	wall_right.size = Vector3(0.5, size.y, size.z)
	wall_right.position = center + Vector3(size.x / 2.0 + 0.25, size.y / 2.0, 0)
	wall_right.material = stone_mat
	wall_right.use_collision = true
	add_child(wall_right)


func _create_stairs(start_pos: Vector3, end_pos: Vector3, num_steps: int) -> void:
	var step_height: float = (start_pos.y - end_pos.y) / num_steps
	var step_depth: float = abs(end_pos.z - start_pos.z) / num_steps
	var direction: float = sign(end_pos.z - start_pos.z)

	for i in range(num_steps):
		var step := CSGBox3D.new()
		step.name = "Stair_%d" % i
		step.size = Vector3(4, step_height, step_depth)
		step.position = Vector3(
			start_pos.x,
			start_pos.y - (i + 0.5) * step_height,
			start_pos.z + direction * (i + 0.5) * step_depth
		)
		step.material = stone_mat
		step.use_collision = true
		add_child(step)


func _create_coffin(pos: Vector3, rotation_y: float) -> void:
	var coffin_root := Node3D.new()
	coffin_root.name = "Coffin"
	coffin_root.position = pos
	coffin_root.rotation.y = rotation_y
	add_child(coffin_root)

	# Main coffin body
	var body := CSGBox3D.new()
	body.name = "CoffinBody"
	body.size = Vector3(1.0, 0.5, 2.2)
	body.position = Vector3(0, 0.25, 0)
	body.material = coffin_mat
	body.use_collision = true
	coffin_root.add_child(body)

	# Coffin lid (slightly offset)
	var lid := CSGBox3D.new()
	lid.name = "CoffinLid"
	lid.size = Vector3(1.1, 0.15, 2.3)
	lid.position = Vector3(0, 0.575, 0)
	lid.material = coffin_mat
	lid.use_collision = true
	coffin_root.add_child(lid)


func _create_sarcophagus(pos: Vector3) -> void:
	var sarc_root := Node3D.new()
	sarc_root.name = "AncientSarcophagus"
	sarc_root.position = pos
	add_child(sarc_root)

	# Base platform
	var base := CSGBox3D.new()
	base.name = "SarcBase"
	base.size = Vector3(3.5, 0.5, 4.0)
	base.position = Vector3(0, 0.25, 0)
	base.material = blood_stone_mat
	base.use_collision = true
	sarc_root.add_child(base)

	# Main sarcophagus body
	var body := CSGBox3D.new()
	body.name = "SarcBody"
	body.size = Vector3(1.5, 1.0, 3.0)
	body.position = Vector3(0, 1.0, 0)
	body.material = stone_mat
	body.use_collision = true
	sarc_root.add_child(body)

	# Ornate lid
	var lid := CSGBox3D.new()
	lid.name = "SarcLid"
	lid.size = Vector3(1.6, 0.3, 3.1)
	lid.position = Vector3(0, 1.65, 0)
	lid.material = stone_mat
	lid.use_collision = true
	sarc_root.add_child(lid)

	# Glowing crimson aura effect (light positioned inside)
	var aura_light := OmniLight3D.new()
	aura_light.name = "SarcophagusAura"
	aura_light.light_color = Color(0.9, 0.1, 0.15)
	aura_light.light_energy = 1.5
	aura_light.omni_range = 4.0
	aura_light.position = Vector3(0, 1.0, 0)
	sarc_root.add_child(aura_light)


func _create_pillar(pos: Vector3, height: float, pillar_name: String) -> void:
	var pillar := CSGCylinder3D.new()
	pillar.name = pillar_name
	pillar.radius = 0.8
	pillar.height = height
	pillar.position = Vector3(pos.x, pos.y + height / 2.0, pos.z)
	pillar.material = stone_mat
	pillar.use_collision = true
	add_child(pillar)


func _create_gate_bars(pos: Vector3, size: Vector3) -> void:
	var gate_root := Node3D.new()
	gate_root.name = "GateBars"
	gate_root.position = pos
	add_child(gate_root)

	var num_bars := 5
	var bar_spacing := size.x / (num_bars + 1)

	for i in range(num_bars):
		var bar := CSGCylinder3D.new()
		bar.name = "Bar_%d" % i
		bar.radius = 0.08
		bar.height = size.y
		bar.position = Vector3(-size.x / 2.0 + (i + 1) * bar_spacing, size.y / 2.0, 0)
		bar.material = metal_mat
		bar.use_collision = true
		gate_root.add_child(bar)

	# Horizontal crossbars
	var crossbar_top := CSGBox3D.new()
	crossbar_top.name = "CrossbarTop"
	crossbar_top.size = Vector3(size.x, 0.1, 0.1)
	crossbar_top.position = Vector3(0, size.y - 0.3, 0)
	crossbar_top.material = metal_mat
	crossbar_top.use_collision = true
	gate_root.add_child(crossbar_top)

	var crossbar_bottom := CSGBox3D.new()
	crossbar_bottom.name = "CrossbarBottom"
	crossbar_bottom.size = Vector3(size.x, 0.1, 0.1)
	crossbar_bottom.position = Vector3(0, 0.3, 0)
	crossbar_bottom.material = metal_mat
	crossbar_bottom.use_collision = true
	gate_root.add_child(crossbar_bottom)


func _create_trap_trigger(pos: Vector3, trap_type: String) -> void:
	# Visual pressure plate
	var plate := CSGBox3D.new()
	plate.name = "TrapPlate_" + trap_type
	plate.size = Vector3(2, 0.05, 2)
	plate.position = pos + Vector3(0, 0.025, 0)
	plate.material = stone_mat  # Blends with floor
	plate.use_collision = true
	add_child(plate)

	# Trigger area
	var trigger := Area3D.new()
	trigger.name = "TrapTrigger_" + trap_type
	trigger.position = pos
	trigger.set_meta("trap_type", trap_type)
	add_child(trigger)

	var trigger_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 1, 2)
	trigger_shape.shape = box
	trigger_shape.position = Vector3(0, 0.5, 0)
	trigger.add_child(trigger_shape)

	# Connect trap trigger
	trigger.body_entered.connect(_on_trap_triggered.bind(trap_type))


func _on_trap_triggered(body: Node3D, trap_type: String) -> void:
	if body.is_in_group("player"):
		match trap_type:
			"poison_dart_trap":
				print("[VampireCrypt] Poison dart trap triggered!")
				# TODO: Deal poison damage to player
			"spike_trap":
				print("[VampireCrypt] Spike trap triggered!")
				# TODO: Deal physical damage to player


func _create_ritual_circle(pos: Vector3, radius: float) -> Node3D:
	var circle_root := Node3D.new()
	circle_root.name = "RitualCircle"
	circle_root.position = pos

	# Create circle using thin cylinder
	var circle_mat := StandardMaterial3D.new()
	circle_mat.albedo_color = Color(0.6, 0.1, 0.1, 0.8)
	circle_mat.emission_enabled = true
	circle_mat.emission = Color(0.8, 0.1, 0.1)
	circle_mat.emission_energy_multiplier = 2.0
	circle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var outer_ring := CSGTorus3D.new()
	outer_ring.name = "OuterRing"
	outer_ring.inner_radius = radius - 0.1
	outer_ring.outer_radius = radius
	outer_ring.material = circle_mat
	outer_ring.rotation.x = PI / 2
	circle_root.add_child(outer_ring)

	var inner_ring := CSGTorus3D.new()
	inner_ring.name = "InnerRing"
	inner_ring.inner_radius = radius * 0.6 - 0.1
	inner_ring.outer_radius = radius * 0.6
	inner_ring.material = circle_mat
	inner_ring.rotation.x = PI / 2
	circle_root.add_child(inner_ring)

	return circle_root


func _create_cult_symbol(pos: Vector3, symbol_name: String) -> void:
	var symbol_mat := StandardMaterial3D.new()
	symbol_mat.albedo_color = Color(0.6, 0.1, 0.1, 0.9)
	symbol_mat.emission_enabled = true
	symbol_mat.emission = Color(0.7, 0.1, 0.1)
	symbol_mat.emission_energy_multiplier = 1.5
	symbol_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var symbol := MeshInstance3D.new()
	symbol.name = symbol_name

	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.2)
	symbol.mesh = quad
	symbol.material_override = symbol_mat
	symbol.position = pos

	add_child(symbol)


func _create_candle_cluster(pos: Vector3, cluster_name: String) -> void:
	var cluster := Node3D.new()
	cluster.name = cluster_name
	cluster.position = pos
	add_child(cluster)

	# 3 candles in a small cluster
	var offsets := [Vector3(0, 0, 0), Vector3(0.15, 0, 0.1), Vector3(-0.1, 0, 0.12)]
	var heights := [0.3, 0.25, 0.2]

	for i in range(3):
		var candle := CSGCylinder3D.new()
		candle.name = "Candle_%d" % i
		candle.radius = 0.04
		candle.height = heights[i]
		candle.position = offsets[i] + Vector3(0, heights[i] / 2.0, 0)

		var candle_mat := StandardMaterial3D.new()
		candle_mat.albedo_color = Color(0.9, 0.85, 0.7)
		candle.material = candle_mat
		cluster.add_child(candle)

	# Single flickering light for the cluster
	var light := OmniLight3D.new()
	light.name = "CandleLight"
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 0.4
	light.omni_range = 3.0
	light.position = Vector3(0, 0.4, 0)
	cluster.add_child(light)


func _spawn_torch_light(pos: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.name = "TorchLight"
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.position = pos
	add_child(light)


func _spawn_undead_enemy(pos: Vector3, enemy_id: String, display_name: String) -> void:
	var sprite_path := "res://assets/sprites/enemies/%s.png" % enemy_id
	var data_path := "res://data/enemies/%s.tres" % enemy_id

	var sprite_texture: Texture2D = load(sprite_path)
	if not sprite_texture:
		push_warning("[VampireCrypt] Failed to load sprite: %s" % sprite_path)
		return

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		data_path,
		sprite_texture,
		4, 4  # Standard 4x4 sprite sheet
	)

	if enemy:
		enemy.call_deferred("_check_and_apply_undead_glow", data_path)
		print("[VampireCrypt] Spawned %s at %s" % [display_name, pos])
