## aberdeen.gd - Aberdeen Mountain Town
## Snowy mountain town south of Kazan-Dun, suffering from cut-off supply chains
## North: Road blocked by goblin invasion in Kazan-Dun
## West: Larton taken over by ghost pirates
## Town is struggling, low on supplies, desperate atmosphere
##
## NOTE: All static geometry and NPCs are defined in aberdeen.tscn
## This script handles runtime setup: navigation, day/night cycle, dynamic NPC spawning
extends Node3D

const ZONE_ID := "town_aberdeen"
const ZONE_SIZE := 90.0  # 90x90 unit zone

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

# NPC spawn configuration - struggling town, fewer NPCs than normal
var civilian_spawn_count := 4  # Reduced due to hardship
var guard_spawn_count := 2  # Under-equipped guards


func _ready() -> void:
	_setup_spawn_point_metadata()
	_setup_navigation()
	_setup_day_night_cycle()
	_create_invisible_border_walls()
	_spawn_dynamic_npcs()
	# NOTE: Frozen corpse decorations are now pre-placed in aberdeen.tscn
	# under the Decorations node (FrozenCorpse_0 through FrozenCorpse_4)
	print("[Aberdeen] Snowy mountain town loaded (Zone size: %dx%d)" % [ZONE_SIZE, ZONE_SIZE])


## Setup spawn point metadata for spawn points defined in .tscn
func _setup_spawn_point_metadata() -> void:
	var spawn_points := $SpawnPoints
	for child in spawn_points.get_children():
		child.set_meta("spawn_id", child.name)


## Setup dynamic day/night lighting
func _setup_day_night_cycle() -> void:
	DayNightCycle.add_to_level(self)


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		nav_region = $NavigationRegion3D

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
		print("[Aberdeen] Navigation mesh baked")


## Create invisible collision walls at borders to prevent player leaving except through exits
func _create_invisible_border_walls() -> void:
	var distance := ZONE_SIZE / 2.0  # 45 units
	var wall_height := 6.0
	var wall_thickness := 1.0
	var exit_gap := 6.0  # Gap for exits

	# North wall sections (with gap for Kazan-Dun road)
	var north_section_len := (ZONE_SIZE - exit_gap) / 2.0
	_create_border_wall("NorthWestBorder", Vector3(-distance + north_section_len / 2.0, wall_height / 2.0, -distance), Vector3(north_section_len, wall_height, wall_thickness))
	_create_border_wall("NorthEastBorder", Vector3(distance - north_section_len / 2.0, wall_height / 2.0, -distance), Vector3(north_section_len, wall_height, wall_thickness))

	# South wall (full)
	_create_border_wall("SouthBorder", Vector3(0, wall_height / 2.0, distance), Vector3(ZONE_SIZE, wall_height, wall_thickness))

	# East wall sections (with gap for wilderness exit)
	var east_section_len := (ZONE_SIZE - exit_gap) / 2.0
	_create_border_wall("EastNorthBorder", Vector3(distance, wall_height / 2.0, -distance + east_section_len / 2.0), Vector3(wall_thickness, wall_height, east_section_len))
	_create_border_wall("EastSouthBorder", Vector3(distance, wall_height / 2.0, distance - east_section_len / 2.0), Vector3(wall_thickness, wall_height, east_section_len))

	# West wall sections (with gap for Larton road)
	_create_border_wall("WestNorthBorder", Vector3(-distance, wall_height / 2.0, -distance + east_section_len / 2.0), Vector3(wall_thickness, wall_height, east_section_len))
	_create_border_wall("WestSouthBorder", Vector3(-distance, wall_height / 2.0, distance - east_section_len / 2.0), Vector3(wall_thickness, wall_height, east_section_len))


func _create_border_wall(wall_name: String, position: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.name = wall_name
	wall.collision_layer = 1
	wall.collision_mask = 0
	add_child(wall)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = position
	wall.add_child(col)


## Spawn dynamic NPCs - civilians looking cold and desperate, under-equipped guards
func _spawn_dynamic_npcs() -> void:
	var npc_container := $NPCs

	# Spawn struggling civilians around the town
	_spawn_civilians(npc_container)

	# Spawn under-equipped guards at exits
	_spawn_guards(npc_container)

	print("[Aberdeen] Spawned %d civilians and %d guards" % [civilian_spawn_count, guard_spawn_count])


func _spawn_civilians(container: Node3D) -> void:
	# Civilian spawn positions - near hearth, around town center, near shops
	# Fewer civilians than normal - town is struggling

	# Near the hearth (gathering for warmth)
	CivilianNPC.spawn_man(container, Vector3(-5, 0, 8), ZONE_ID)
	CivilianNPC.spawn_woman(container, Vector3(-3, 0, 6), ZONE_ID)

	# Town square
	CivilianNPC.spawn_man(container, Vector3(5, 0, 3), ZONE_ID)

	# Near the shops (hoping for supplies)
	CivilianNPC.spawn_woman(container, Vector3(-12, 0, 2), ZONE_ID)


func _spawn_guards(container: Node3D) -> void:
	# Under-equipped guards at the exits - fewer than normal
	# North exit guard (watching the Kazan-Dun road)
	CivilianNPC.spawn_man(container, Vector3(0, 0, -40), ZONE_ID)

	# West exit guard (watching the dangerous Larton road)
	CivilianNPC.spawn_man(container, Vector3(-40, 0, 5), ZONE_ID)


## Get spawn point metadata for scene transitions
func get_spawn_point(spawn_id: String) -> Node3D:
	var spawn_points := $SpawnPoints
	for child in spawn_points.get_children():
		if child.name == spawn_id or child.get_meta("spawn_id", "") == spawn_id:
			return child
	# Return default spawn if not found
	return spawn_points.get_node_or_null("DefaultSpawn")


## Create frozen corpse/creature decorations for the harsh snowy environment
func _create_frozen_corpse_decorations() -> void:
	var decorations := $Decorations

	# Frost monster texture (frozen creature corpse)
	var frost_monster_tex: Texture2D = load("res://Sprite folders grab bag/frost_monster.png")
	if not frost_monster_tex:
		push_warning("[Aberdeen] Failed to load frost_monster.png")
		return

	# Positions for frozen corpse decorations - outside the town walls
	# These represent travelers or creatures frozen in the harsh winter
	var frozen_positions: Array[Vector3] = [
		Vector3(-38, 0, -32),    # Northwest, near border
		Vector3(35, 0, -38),     # Northeast, along mountain pass
		Vector3(-42, 0, 15),     # West, near Larton road
		Vector3(42, 0, -5),      # East, in the wilderness
		Vector3(15, 0, 42),      # South, near town edge
	]

	for i in frozen_positions.size():
		var pos: Vector3 = frozen_positions[i]
		var billboard := BillboardSprite.create_billboard(decorations, frost_monster_tex, 1, 1, 0.045, 0.0)
		billboard.name = "FrozenCorpse_%d" % i
		billboard.position = pos
		# Apply a slight blue tint to make it look frozen
		if billboard.sprite:
			billboard.sprite.modulate = Color(0.8, 0.85, 1.0, 1.0)

	print("[Aberdeen] Spawned %d frozen corpse decorations" % frozen_positions.size())
