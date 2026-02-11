## goblin_cave.gd - Hand-crafted goblin dungeon
## Layout: Entrance -> Hallway Fork -> Boss Zone (left) + Artifact Zone (right)
extends Node3D

const ZONE_ID := "goblin_cave"

## Materials
var floor_mat: StandardMaterial3D
var wall_mat: StandardMaterial3D
var rock_mat: StandardMaterial3D

## Navigation
var nav_region: NavigationRegion3D

## Goblin projectile for archers
var goblin_bolt: ProjectileData


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Goblin Cave")

	_load_resources()
	_create_materials()
	_setup_navigation()
	_create_cave_layout()
	_spawn_spawn_points()
	_spawn_exit_portal()
	_spawn_goblins()
	_spawn_loot()
	_create_lighting()

	# Quest trigger for entering cave
	QuestManager.on_location_reached("goblin_cave_entrance")

	print("[GoblinCave] Dungeon initialized!")


func _load_resources() -> void:
	goblin_bolt = load("res://resources/projectiles/goblin_bolt.tres")
	if not goblin_bolt:
		push_warning("[GoblinCave] Failed to load goblin_bolt projectile!")


func _create_materials() -> void:
	# Cave floor - dark stone
	floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.18, 0.16, 0.14)
	floor_mat.roughness = 0.95

	# Cave walls - slightly lighter
	wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.22, 0.2, 0.18)
	wall_mat.roughness = 0.9

	# Rocks/stalagmites
	rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.28, 0.25, 0.22)
	rock_mat.roughness = 0.85


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
		print("[GoblinCave] Navigation mesh baked!")


## ============================================================================
## CAVE LAYOUT
## ============================================================================
## Layout Overview (top-down, north = -Z):
##
##              [BOSS ZONE]          [ARTIFACT ZONE]
##                 (left)                (right)
##                   |                      |
##            +------+------+        +------+------+
##            |             |        |             |
##            +------+------+        +------+------+
##                   |                      |
##                   +----------+-----------+
##                              |
##                       [FORK CHAMBER]
##                              |
##                       [ENTRY HALLWAY]
##                              |
##                       [ENTRANCE]
##                           (south)
## ============================================================================

func _create_cave_layout() -> void:
	_create_entrance_chamber()
	_create_entry_hallway()
	_create_fork_chamber()
	_create_left_corridor()  # To boss
	_create_right_corridor()  # To artifact
	_create_boss_zone()
	_create_artifact_zone()
	_add_stalagmites()


## ENTRANCE CHAMBER - Where player spawns (south)
func _create_entrance_chamber() -> void:
	var pos := Vector3(0, 0, 40)  # South end
	# Door to south (exit portal) and north (to hallway)
	_create_room(pos, Vector3(16, 6, 16), "Entrance", ["south", "north"])


## ENTRY HALLWAY - Connects entrance to fork
func _create_entry_hallway() -> void:
	var pos := Vector3(0, 0, 24)
	# Door to south (entrance) and north (fork)
	_create_room(pos, Vector3(8, 5, 16), "EntryHall", ["south", "north"])


## FORK CHAMBER - Central hub with two paths
func _create_fork_chamber() -> void:
	var pos := Vector3(0, 0, 8)
	# Door to south (hallway), west (left corridor), east (right corridor)
	_create_room(pos, Vector3(20, 6, 12), "ForkChamber", ["south", "west", "east"])


## LEFT CORRIDOR - Path to boss zone
func _create_left_corridor() -> void:
	var pos := Vector3(-16, 0, -4)
	# Door to east (fork) and north (boss zone)
	_create_room(pos, Vector3(12, 5, 16), "LeftCorridor", ["east", "north"])


## RIGHT CORRIDOR - Path to artifact zone
func _create_right_corridor() -> void:
	var pos := Vector3(16, 0, -4)
	# Door to west (fork) and north (artifact zone)
	_create_room(pos, Vector3(12, 5, 16), "RightCorridor", ["west", "north"])


## BOSS ZONE - Warboss arena (northwest)
func _create_boss_zone() -> void:
	var pos := Vector3(-20, 0, -24)
	# Door to south (left corridor)
	_create_room(pos, Vector3(24, 8, 20), "BossZone", ["south"])

	# Add pillars for cover
	var pillar_positions := [
		Vector3(-28, 0, -18),
		Vector3(-12, 0, -18),
		Vector3(-28, 0, -30),
		Vector3(-12, 0, -30),
	]
	for i in pillar_positions.size():
		_create_pillar(pillar_positions[i], "BossPillar_%d" % i)


## ARTIFACT ZONE - Totem chamber (northeast)
func _create_artifact_zone() -> void:
	var pos := Vector3(20, 0, -24)
	# Door to south (right corridor)
	_create_room(pos, Vector3(20, 7, 20), "ArtifactZone", ["south"])

	# Raised platform for the totem
	var platform := CSGBox3D.new()
	platform.name = "TotemPlatform"
	platform.size = Vector3(8, 1, 8)
	platform.position = Vector3(20, 0.5, -28)
	platform.material = rock_mat
	platform.use_collision = true
	add_child(platform)


## Helper: Create a room with floor, ceiling, and walls
## door_sides: Array of sides that have doorways ("north", "south", "east", "west")
func _create_room(center: Vector3, size: Vector3, room_name: String, door_sides: Array = []) -> void:
	var half_x := size.x / 2.0
	var half_z := size.z / 2.0
	var height := size.y
	var wall_thickness := 1.0
	var door_width := 6.0  # Width of doorway openings

	# Floor
	var floor := CSGBox3D.new()
	floor.name = room_name + "_Floor"
	floor.size = Vector3(size.x + wall_thickness * 2, 1, size.z + wall_thickness * 2)
	floor.position = Vector3(center.x, -0.5, center.z)
	floor.material = floor_mat
	floor.use_collision = true
	add_child(floor)

	# Ceiling
	var ceiling := CSGBox3D.new()
	ceiling.name = room_name + "_Ceiling"
	ceiling.size = Vector3(size.x + wall_thickness * 2, 1, size.z + wall_thickness * 2)
	ceiling.position = Vector3(center.x, height, center.z)
	ceiling.material = wall_mat
	ceiling.use_collision = true
	add_child(ceiling)

	# North wall (at -Z)
	if "north" in door_sides:
		_create_wall_with_door(center, size, height, "north", room_name, door_width)
	else:
		var wall := CSGBox3D.new()
		wall.name = room_name + "_NorthWall"
		wall.size = Vector3(size.x + wall_thickness * 2, height, wall_thickness)
		wall.position = Vector3(center.x, height / 2, center.z - half_z - wall_thickness / 2)
		wall.material = wall_mat
		wall.use_collision = true
		add_child(wall)

	# South wall (at +Z)
	if "south" in door_sides:
		_create_wall_with_door(center, size, height, "south", room_name, door_width)
	else:
		var wall := CSGBox3D.new()
		wall.name = room_name + "_SouthWall"
		wall.size = Vector3(size.x + wall_thickness * 2, height, wall_thickness)
		wall.position = Vector3(center.x, height / 2, center.z + half_z + wall_thickness / 2)
		wall.material = wall_mat
		wall.use_collision = true
		add_child(wall)

	# East wall (at +X)
	if "east" in door_sides:
		_create_wall_with_door(center, size, height, "east", room_name, door_width)
	else:
		var wall := CSGBox3D.new()
		wall.name = room_name + "_EastWall"
		wall.size = Vector3(wall_thickness, height, size.z)
		wall.position = Vector3(center.x + half_x + wall_thickness / 2, height / 2, center.z)
		wall.material = wall_mat
		wall.use_collision = true
		add_child(wall)

	# West wall (at -X)
	if "west" in door_sides:
		_create_wall_with_door(center, size, height, "west", room_name, door_width)
	else:
		var wall := CSGBox3D.new()
		wall.name = room_name + "_WestWall"
		wall.size = Vector3(wall_thickness, height, size.z)
		wall.position = Vector3(center.x - half_x - wall_thickness / 2, height / 2, center.z)
		wall.material = wall_mat
		wall.use_collision = true
		add_child(wall)


## Create a wall with a doorway opening in the center
func _create_wall_with_door(center: Vector3, size: Vector3, height: float, side: String, room_name: String, door_width: float) -> void:
	var half_x := size.x / 2.0
	var half_z := size.z / 2.0
	var wall_thickness := 1.0

	match side:
		"north":
			var wall_z := center.z - half_z - wall_thickness / 2
			var side_width := (size.x - door_width) / 2.0
			if side_width > 0:
				# Left segment
				var left := CSGBox3D.new()
				left.name = room_name + "_NorthWall_Left"
				left.size = Vector3(side_width, height, wall_thickness)
				left.position = Vector3(center.x - half_x + side_width / 2, height / 2, wall_z)
				left.material = wall_mat
				left.use_collision = true
				add_child(left)
				# Right segment
				var right := CSGBox3D.new()
				right.name = room_name + "_NorthWall_Right"
				right.size = Vector3(side_width, height, wall_thickness)
				right.position = Vector3(center.x + half_x - side_width / 2, height / 2, wall_z)
				right.material = wall_mat
				right.use_collision = true
				add_child(right)

		"south":
			var wall_z := center.z + half_z + wall_thickness / 2
			var side_width := (size.x - door_width) / 2.0
			if side_width > 0:
				var left := CSGBox3D.new()
				left.name = room_name + "_SouthWall_Left"
				left.size = Vector3(side_width, height, wall_thickness)
				left.position = Vector3(center.x - half_x + side_width / 2, height / 2, wall_z)
				left.material = wall_mat
				left.use_collision = true
				add_child(left)
				var right := CSGBox3D.new()
				right.name = room_name + "_SouthWall_Right"
				right.size = Vector3(side_width, height, wall_thickness)
				right.position = Vector3(center.x + half_x - side_width / 2, height / 2, wall_z)
				right.material = wall_mat
				right.use_collision = true
				add_child(right)

		"east":
			var wall_x := center.x + half_x + wall_thickness / 2
			var side_depth := (size.z - door_width) / 2.0
			if side_depth > 0:
				var front := CSGBox3D.new()
				front.name = room_name + "_EastWall_Front"
				front.size = Vector3(wall_thickness, height, side_depth)
				front.position = Vector3(wall_x, height / 2, center.z - half_z + side_depth / 2)
				front.material = wall_mat
				front.use_collision = true
				add_child(front)
				var back := CSGBox3D.new()
				back.name = room_name + "_EastWall_Back"
				back.size = Vector3(wall_thickness, height, side_depth)
				back.position = Vector3(wall_x, height / 2, center.z + half_z - side_depth / 2)
				back.material = wall_mat
				back.use_collision = true
				add_child(back)

		"west":
			var wall_x := center.x - half_x - wall_thickness / 2
			var side_depth := (size.z - door_width) / 2.0
			if side_depth > 0:
				var front := CSGBox3D.new()
				front.name = room_name + "_WestWall_Front"
				front.size = Vector3(wall_thickness, height, side_depth)
				front.position = Vector3(wall_x, height / 2, center.z - half_z + side_depth / 2)
				front.material = wall_mat
				front.use_collision = true
				add_child(front)
				var back := CSGBox3D.new()
				back.name = room_name + "_WestWall_Back"
				back.size = Vector3(wall_thickness, height, side_depth)
				back.position = Vector3(wall_x, height / 2, center.z + half_z - side_depth / 2)
				back.material = wall_mat
				back.use_collision = true
				add_child(back)


func _create_pillar(pos: Vector3, pillar_name: String) -> void:
	var pillar := CSGCylinder3D.new()
	pillar.name = pillar_name
	pillar.radius = 1.0
	pillar.height = 7.0
	pillar.position = Vector3(pos.x, 3.5, pos.z)
	pillar.material = rock_mat
	pillar.use_collision = true
	add_child(pillar)


func _add_stalagmites() -> void:
	var positions := [
		Vector3(-5, 0, 38),
		Vector3(5, 0, 42),
		Vector3(-8, 0, 6),
		Vector3(8, 0, 10),
		Vector3(-22, 0, -8),
		Vector3(22, 0, -8),
	]

	for i in positions.size():
		var rock := CSGCylinder3D.new()
		rock.name = "Stalagmite_%d" % i
		rock.radius = randf_range(0.4, 0.8)
		rock.height = randf_range(1.5, 3.0)
		rock.position = Vector3(positions[i].x, rock.height / 2, positions[i].z)
		rock.material = rock_mat
		rock.use_collision = true
		add_child(rock)


## Create the enclosing walls for the entire cave
func _create_cave_walls() -> void:
	# This creates the outer boundary walls
	# Individual rooms connect through gaps in walls

	# Main outer boundary
	var wall_height := 8.0
	var wall_thickness := 2.0

	# We'll create walls segment by segment to allow connections
	# For simplicity, create a big bounding box with internal structure
	pass  # Rooms handle their own walls for now


## ============================================================================
## SPAWN POINTS
## ============================================================================

func _spawn_spawn_points() -> void:
	# Player spawn (from open world) - inside entrance chamber
	var from_world := Node3D.new()
	from_world.name = "from_open_world"
	from_world.position = Vector3(0, 1.0, 42)  # Near south end of entrance, raised Y
	from_world.add_to_group("spawn_points")
	from_world.set_meta("spawn_id", "from_open_world")
	add_child(from_world)

	# Default spawn
	var default_spawn := Node3D.new()
	default_spawn.name = "default_spawn"
	default_spawn.position = Vector3(0, 1.0, 42)
	default_spawn.add_to_group("spawn_points")
	default_spawn.set_meta("spawn_id", "default")
	add_child(default_spawn)

	print("[GoblinCave] Spawn point at: ", from_world.position)


func _spawn_exit_portal() -> void:
	# Portal at south end of entrance chamber (z=40 center, z=48 edge, plus wall)
	var portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, 0, 49),  # Just outside south wall of entrance
		SceneManager.RETURN_TO_WILDERNESS,
		"from_goblin_cave",
		"Exit Cave"
	)
	portal.rotation.y = PI  # Face into cave
	print("[GoblinCave] Spawned exit portal")


## ============================================================================
## GOBLIN SPAWNS
## ============================================================================

func _spawn_goblins() -> void:
	_spawn_entrance_guards()
	_spawn_hallway_patrol()
	_spawn_fork_defenders()
	_spawn_left_corridor_goblins()
	_spawn_right_corridor_goblins()
	_spawn_boss_zone_enemies()
	_spawn_artifact_defenders()


## Entrance guards - light resistance
func _spawn_entrance_guards() -> void:
	# 2 soldiers near entrance
	_spawn_goblin_soldier(Vector3(-4, 0, 36))
	_spawn_goblin_soldier(Vector3(4, 0, 36))


## Hallway patrol
func _spawn_hallway_patrol() -> void:
	# 1 archer in the hallway
	_spawn_goblin_archer(Vector3(0, 0, 22))


## Fork chamber - heavier presence
func _spawn_fork_defenders() -> void:
	# 2 soldiers + 1 archer
	_spawn_goblin_soldier(Vector3(-6, 0, 8))
	_spawn_goblin_soldier(Vector3(6, 0, 8))
	_spawn_goblin_archer(Vector3(0, 0, 4))


## Left corridor (to boss)
func _spawn_left_corridor_goblins() -> void:
	_spawn_goblin_soldier(Vector3(-16, 0, -2))
	_spawn_goblin_archer(Vector3(-16, 0, -8))


## Right corridor (to artifact)
func _spawn_right_corridor_goblins() -> void:
	_spawn_goblin_soldier(Vector3(16, 0, -2))
	_spawn_goblin_archer(Vector3(16, 0, -8))


## Boss zone - Warboss + minions
func _spawn_boss_zone_enemies() -> void:
	# Spawn the Goblin Warboss
	var warboss_sprite: Texture2D = load("res://assets/sprites/enemies/goblin_warboss.png")
	if warboss_sprite:
		var warboss := EnemyBase.spawn_billboard_enemy(
			self,
			Vector3(-20, 0, -26),
			"res://data/enemies/goblin_warboss.tres",
			warboss_sprite,
			4, 5  # 4x5 sprite sheet
		)
		if warboss:
			warboss.name = "GoblinWarboss"
			print("[GoblinCave] Spawned Goblin Warboss!")

	# Warboss minions
	_spawn_goblin_soldier(Vector3(-26, 0, -22))
	_spawn_goblin_soldier(Vector3(-14, 0, -22))
	_spawn_goblin_archer(Vector3(-20, 0, -18))


## Artifact zone - Totem + defenders
func _spawn_artifact_defenders() -> void:
	# Spawn the Goblin Totem (artifact/spawner)
	var totem := EnemySpawner.spawn_spawner(self, Vector3(20, 1, -28), "goblin_totem")
	totem.display_name = "Goblin Totem"
	totem.max_hp = 800
	totem.max_spawned_enemies = 4
	totem.spawn_radius = 5.0
	totem.spawn_interval_min = 15.0
	totem.spawn_interval_max = 25.0
	totem.secondary_enemy_enabled = true  # Enable archer spawns
	totem.secondary_enemy_chance = 0.3
	print("[GoblinCave] Spawned Goblin Totem (artifact)")

	# Static defenders
	_spawn_goblin_soldier(Vector3(14, 0, -22))
	_spawn_goblin_soldier(Vector3(26, 0, -22))
	_spawn_goblin_archer(Vector3(20, 0, -18))


## Helper: Spawn a goblin soldier (melee)
func _spawn_goblin_soldier(pos: Vector3) -> void:
	var sprite: Texture2D = load("res://assets/sprites/enemies/goblin_leader.png")
	if not sprite:
		push_warning("[GoblinCave] Missing goblin soldier sprite")
		return

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		"res://data/enemies/goblin_soldier.tres",
		sprite,
		4, 4
	)
	if enemy:
		enemy.add_to_group("cave_goblins")


## Helper: Spawn a goblin archer (ranged) - uses red capsule mesh, no sprite
func _spawn_goblin_archer(pos: Vector3) -> void:
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy_base.tscn")
	if not enemy_scene:
		push_warning("[GoblinCave] Failed to load enemy_base.tscn")
		return

	var enemy: EnemyBase = enemy_scene.instantiate()

	var data: EnemyData = load("res://data/enemies/goblin_archer.tres")
	if data:
		enemy.enemy_data = data

	add_child(enemy)
	enemy.global_position = pos

	# Apply red tint to the capsule mesh to distinguish archers
	if enemy.mesh_root:
		for child in enemy.mesh_root.get_children():
			if child is MeshInstance3D:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.8, 0.2, 0.2)  # Red pill
				child.material_override = mat

	enemy.add_to_group("cave_goblins")

	# Configure as ranged enemy
	enemy.is_ranged = true
	enemy.preferred_range = 10.0
	enemy.min_range = 4.0
	enemy.ranged_attack_cooldown = 2.0
	enemy.ranged_attack_windup = 0.4

	# Set the projectile - this is critical for ranged attacks to work!
	if goblin_bolt:
		enemy.ranged_attack_projectile = goblin_bolt
		print("[GoblinCave] Spawned ranged goblin archer at %s with projectile: %s" % [pos, goblin_bolt.id])
	else:
		# Fallback to basic arrow if goblin_bolt failed to load
		var fallback := load("res://resources/projectiles/arrow_basic.tres") as ProjectileData
		if fallback:
			enemy.ranged_attack_projectile = fallback
			print("[GoblinCave] Spawned ranged goblin archer at %s with fallback arrow" % pos)
		else:
			push_warning("[GoblinCave] No projectile available for goblin archer!")


## ============================================================================
## LOOT
## ============================================================================

func _spawn_loot() -> void:
	# Boss zone treasure
	var boss_chest := Chest.spawn_chest(
		self,
		Vector3(-20, 0, -32),
		"Warboss Hoard",
		true, 14,
		false, ""
	)
	if boss_chest:
		boss_chest.setup_with_loot(LootTables.LootTier.RARE)

	# Artifact zone treasure (behind totem)
	var artifact_chest := Chest.spawn_chest(
		self,
		Vector3(20, 0, -32),
		"Totem Offerings",
		true, 12,
		false, ""
	)
	if artifact_chest:
		artifact_chest.setup_with_loot(LootTables.LootTier.UNCOMMON)

	# Side loot in fork chamber
	var fork_chest := Chest.spawn_chest(
		self,
		Vector3(-8, 0, 12),
		"Goblin Stash",
		false, 0,
		false, ""
	)
	if fork_chest:
		fork_chest.setup_with_loot(LootTables.LootTier.COMMON)

	print("[GoblinCave] Spawned loot chests")


## ============================================================================
## LIGHTING
## ============================================================================

func _create_lighting() -> void:
	# World environment for cave atmosphere
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.08, 0.06)
	env.ambient_light_energy = 0.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.06, 0.05)
	env.fog_density = 0.03

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Entrance light (natural light from outside)
	var entrance_light := OmniLight3D.new()
	entrance_light.name = "EntranceLight"
	entrance_light.light_color = Color(0.9, 0.85, 0.7)
	entrance_light.light_energy = 1.5
	entrance_light.omni_range = 15.0
	entrance_light.position = Vector3(0, 4, 46)  # Near south entrance
	add_child(entrance_light)

	# Secondary light in entrance chamber
	var entrance_light2 := OmniLight3D.new()
	entrance_light2.name = "EntranceLight2"
	entrance_light2.light_color = Color(0.7, 0.6, 0.5)
	entrance_light2.light_energy = 1.0
	entrance_light2.omni_range = 10.0
	entrance_light2.position = Vector3(0, 4, 38)
	add_child(entrance_light2)

	# Fork chamber torches
	_spawn_torch(Vector3(-8, 2.5, 6))
	_spawn_torch(Vector3(8, 2.5, 6))

	# Left corridor torch
	_spawn_torch(Vector3(-16, 2.5, -6))

	# Right corridor torch
	_spawn_torch(Vector3(16, 2.5, -6))

	# Boss zone - eerie red lighting
	var boss_light := OmniLight3D.new()
	boss_light.name = "BossLight"
	boss_light.light_color = Color(0.8, 0.3, 0.2)
	boss_light.light_energy = 1.2
	boss_light.omni_range = 12.0
	boss_light.position = Vector3(-20, 5, -24)
	add_child(boss_light)

	# Artifact zone - green totem glow
	var totem_light := OmniLight3D.new()
	totem_light.name = "TotemGlow"
	totem_light.light_color = Color(0.2, 0.8, 0.3)
	totem_light.light_energy = 2.0
	totem_light.omni_range = 10.0
	totem_light.position = Vector3(20, 4, -28)
	add_child(totem_light)

	print("[GoblinCave] Created cave lighting")


func _spawn_torch(pos: Vector3) -> void:
	if not TorchProp:
		return
	var torch := TorchProp.new()
	torch.position = pos
	add_child(torch)
