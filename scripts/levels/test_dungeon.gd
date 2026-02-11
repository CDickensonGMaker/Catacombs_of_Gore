## test_dungeon.gd - Procedural test dungeon for development
## Accessible from town portal for testing generation and map systems
extends Node3D

const ZONE_ID := "test_dungeon"

var generator: DungeonGenerator
var dungeon_seed: int = 0


func _ready() -> void:
	# Register this zone with SaveManager for proper autosave tracking
	SaveManager.set_current_zone(ZONE_ID, "Test Dungeon")

	_initialize_seed()
	_create_environment()
	_setup_generator()
	_run_generation()


## Initialize the random seed for consistent dungeon generation
func _initialize_seed() -> void:
	var saved_seed := SaveManager.get_dungeon_seed(ZONE_ID)
	if saved_seed >= 0:
		# Use existing seed for persistence
		dungeon_seed = saved_seed
	else:
		# Generate new seed and save it (auto-persists to cache)
		dungeon_seed = randi()
		SaveManager.set_dungeon_seed(ZONE_ID, dungeon_seed)

	print("[TestDungeon] Using seed: %d" % dungeon_seed)


## Run the dungeon generation after generator is set up
func _run_generation() -> void:
	# Connect to generation complete signal
	if generator and generator.has_signal("generation_complete"):
		generator.generation_complete.connect(_on_generator_complete)

	generator.generate(dungeon_seed)

	# Create spawn point IMMEDIATELY after generation (not deferred)
	# This ensures the spawn point exists when SceneManager looks for it
	_create_spawn_point()


## Create ambient lighting and environment
func _create_environment() -> void:
	# World environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.12, 0.18)
	env.ambient_light_energy = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.08, 0.12)
	env.fog_density = 0.015

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Directional light (dim, from above)
	var light := DirectionalLight3D.new()
	light.light_color = Color(0.6, 0.5, 0.7)
	light.light_energy = 0.3
	light.rotation_degrees = Vector3(-60, 30, 0)
	light.shadow_enabled = true
	add_child(light)


## Setup dungeon generator with templates
func _setup_generator() -> void:
	generator = DungeonGenerator.new()
	generator.zone_id = ZONE_ID
	generator.max_rooms = 8
	generator.min_rooms = 5
	add_child(generator)

	# Create room templates programmatically
	_create_entrance_template()
	_create_corridor_template()
	_create_guard_room_template()
	_create_empty_room_template()  # Empty variant for variety
	_create_treasure_room_template()
	_create_shrine_template()
	_create_quest_room_template()  # NPC with dungeon quest
	_create_boss_template()


## Create entrance room template
func _create_entrance_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "entrance"
	template.room_type = "entrance"
	template.width = 12
	template.depth = 12
	template.height = 5

	# Doors on three sides (not the entrance side)
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, 6), Vector3.FORWARD, 4.0),
		RoomTemplate.make_door(Vector3(6, 0, 0), Vector3.RIGHT, 4.0),
		RoomTemplate.make_door(Vector3(-6, 0, 0), Vector3.LEFT, 4.0),
	]

	# Portal back to town
	template.has_portal = true
	template.portal_target_scene = "res://scenes/levels/elder_moor.tscn"
	template.portal_spawn_id = "from_test_dungeon"
	template.portal_display_name = "Return to Town"

	# Dark stone colors
	template.floor_color = Color(0.12, 0.1, 0.14)
	template.wall_color = Color(0.18, 0.15, 0.2)
	template.ceiling_color = Color(0.15, 0.12, 0.17)

	generator.add_template(template)


## Create corridor template
func _create_corridor_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "corridor"
	template.room_type = "corridor"
	template.width = 4
	template.depth = 12
	template.height = 4

	# Doors on both ends
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, 6), Vector3.FORWARD, 4.0),
		RoomTemplate.make_door(Vector3(0, 0, -6), Vector3.BACK, 4.0),
	]

	# Maybe one enemy
	template.min_enemies = 0
	template.max_enemies = 1
	template.enemy_spawn_zones = [Vector3(0, 0, 0)]
	template.enemy_data_paths = [
		"res://data/enemies/skeleton_shade.tres",
		"res://data/enemies/skeleton_warrior.tres"
	]
	template.enemy_sprite_paths = [
		"res://assets/sprites/enemies/skeleton_shade.png",
		"res://Sprite folders grab bag/skeleton_warrior.png"
	]
	template.enemy_h_frames = [4, 8]
	template.enemy_v_frames = [4, 12]

	template.floor_color = Color(0.1, 0.08, 0.12)
	template.wall_color = Color(0.15, 0.12, 0.17)

	generator.add_template(template)


## Create guard room template
func _create_guard_room_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "guard_room"
	template.room_type = "guard"
	template.width = 14
	template.depth = 14
	template.height = 5

	# Doors on all four sides
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, 7), Vector3.FORWARD, 4.0),
		RoomTemplate.make_door(Vector3(0, 0, -7), Vector3.BACK, 4.0),
		RoomTemplate.make_door(Vector3(7, 0, 0), Vector3.RIGHT, 4.0),
		RoomTemplate.make_door(Vector3(-7, 0, 0), Vector3.LEFT, 4.0),
	]

	# 2-3 enemies
	template.min_enemies = 2
	template.max_enemies = 3
	template.enemy_spawn_zones = [
		Vector3(-4, 0, -4),
		Vector3(4, 0, -4),
		Vector3(0, 0, 4),
	]
	template.enemy_data_paths = [
		"res://data/enemies/skeleton_shade.tres",
		"res://data/enemies/skeleton_warrior.tres"
	]
	template.enemy_sprite_paths = [
		"res://assets/sprites/enemies/skeleton_shade.png",
		"res://Sprite folders grab bag/skeleton_warrior.png"
	]
	template.enemy_h_frames = [4, 8]
	template.enemy_v_frames = [4, 12]

	# Decorations
	template.decorations = [
		RoomTemplate.make_decoration("pillar", Vector3(-5, 0, -5)),
		RoomTemplate.make_decoration("pillar", Vector3(5, 0, -5)),
		RoomTemplate.make_decoration("pillar", Vector3(-5, 0, 5)),
		RoomTemplate.make_decoration("pillar", Vector3(5, 0, 5)),
	]

	template.floor_color = Color(0.12, 0.1, 0.14)
	template.wall_color = Color(0.18, 0.15, 0.2)

	generator.add_template(template)


## Create empty room template (same layout as guard room, but no enemies)
## Used to add variety - not every room needs combat
func _create_empty_room_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "empty_hall"
	template.room_type = "empty"  # No enemies by default
	template.width = 12
	template.depth = 12
	template.height = 5

	# Doors on three sides
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, 6), Vector3.FORWARD, 4.0),
		RoomTemplate.make_door(Vector3(0, 0, -6), Vector3.BACK, 4.0),
		RoomTemplate.make_door(Vector3(6, 0, 0), Vector3.RIGHT, 4.0),
	]

	# No enemies - this is a transition/exploration room
	template.min_enemies = 0
	template.max_enemies = 0

	# But still has enemy data in case generator wants to spawn here
	template.enemy_data_paths = ["res://data/enemies/skeleton_shade.tres"]
	template.enemy_sprite_paths = ["res://assets/sprites/enemies/skeleton_shade.png"]
	template.enemy_h_frames = [4]
	template.enemy_v_frames = [4]

	# Decorations for atmosphere
	template.decorations = [
		RoomTemplate.make_decoration("pillar", Vector3(-4, 0, 0)),
		RoomTemplate.make_decoration("pillar", Vector3(4, 0, 0)),
	]

	template.floor_color = Color(0.11, 0.09, 0.13)
	template.wall_color = Color(0.17, 0.14, 0.19)

	generator.add_template(template)


## Create treasure room template
func _create_treasure_room_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "treasure_room"
	template.room_type = "treasure"
	template.width = 10
	template.depth = 10
	template.height = 4

	# One or two doors
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, -5), Vector3.BACK, 4.0),
		RoomTemplate.make_door(Vector3(5, 0, 0), Vector3.RIGHT, 4.0),
	]

	# 1 chest, 1 enemy guard
	template.chest_count = 1
	template.chest_locked = true
	template.chest_lock_dc = 12
	template.loot_tier = 2  # UNCOMMON
	template.loot_spawn_zones = [Vector3(0, 0, 3)]

	template.min_enemies = 1
	template.max_enemies = 1
	template.enemy_spawn_zones = [Vector3(0, 0, 0)]
	template.enemy_data_paths = ["res://data/enemies/skeleton_shade.tres"]
	template.enemy_sprite_paths = ["res://assets/sprites/enemies/skeleton_shade.png"]
	template.enemy_h_frames = [4]
	template.enemy_v_frames = [4]

	# Coffin decorations
	template.decorations = [
		RoomTemplate.make_decoration("coffin", Vector3(-3, 0, 2), PI / 2),
		RoomTemplate.make_decoration("coffin", Vector3(3, 0, 2), -PI / 2),
	]

	template.floor_color = Color(0.14, 0.12, 0.16)
	template.wall_color = Color(0.2, 0.17, 0.22)

	generator.add_template(template)


## Create shrine/rest room template
func _create_shrine_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "shrine"
	template.room_type = "shrine"
	template.width = 10
	template.depth = 10
	template.height = 6

	# Two doors
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, -5), Vector3.BACK, 4.0),
		RoomTemplate.make_door(Vector3(0, 0, 5), Vector3.FORWARD, 4.0),
	]

	# Rest spot
	template.has_rest_spot = true
	template.rest_spot_name = "Ancient Shrine"

	# Altar decoration
	template.decorations = [
		RoomTemplate.make_decoration("altar", Vector3(0, 0, 3)),
	]

	# Lighter colors (holy place)
	template.floor_color = Color(0.15, 0.14, 0.18)
	template.wall_color = Color(0.22, 0.2, 0.25)

	generator.add_template(template)


## Create quest room with NPC that gives dungeon-achievable quests
func _create_quest_room_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "quest_room"
	template.room_type = "quest"  # Triggers QuestGiver NPC spawn
	template.width = 10
	template.depth = 10
	template.height = 5

	# Two doors for accessibility
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, -5), Vector3.BACK, 4.0),
		RoomTemplate.make_door(Vector3(5, 0, 0), Vector3.RIGHT, 4.0),
	]

	# No enemies - this is a safe room for quest interaction
	template.min_enemies = 0
	template.max_enemies = 0

	# Quest NPC configuration
	template.has_quest_npc = true
	template.quest_npc_name = "Dungeon Wanderer"
	template.quest_data_path = "res://data/quests/dungeon_clear.json"
	template.quest_npc_position = Vector3(0, 0, 2)

	# Atmospheric decorations - campfire feel
	template.decorations = [
		RoomTemplate.make_decoration("pillar", Vector3(-3, 0, -3)),
		RoomTemplate.make_decoration("pillar", Vector3(3, 0, -3)),
	]

	# Warmer colors to feel safe
	template.floor_color = Color(0.14, 0.12, 0.1)
	template.wall_color = Color(0.2, 0.17, 0.15)
	template.ceiling_color = Color(0.16, 0.13, 0.11)

	generator.add_template(template)


## Create boss room template
func _create_boss_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "boss_arena"
	template.room_type = "boss"
	template.width = 14
	template.depth = 14
	template.height = 7
	template.is_boss_room = true

	# Single entrance
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, -7), Vector3.BACK, 5.0),
	]

	# Boss: Vampire Lord
	template.boss_data_path = "res://data/enemies/vampire_lord.tres"
	template.boss_sprite_path = "res://Sprite folders grab bag/vampirelord.png"
	template.boss_h_frames = 5
	template.boss_v_frames = 3

	# Additional minions
	template.min_enemies = 2
	template.max_enemies = 3
	template.enemy_spawn_zones = [
		Vector3(-4, 0, 0),
		Vector3(4, 0, 0),
		Vector3(0, 0, 4),
	]
	template.enemy_data_paths = ["res://data/enemies/skeleton_shade.tres"]
	template.enemy_sprite_paths = ["res://assets/sprites/enemies/skeleton_shade.png"]
	template.enemy_h_frames = [4]
	template.enemy_v_frames = [4]

	# Boss loot
	template.chest_count = 1
	template.chest_locked = true
	template.chest_lock_dc = 15
	template.loot_tier = 3  # RARE
	template.loot_spawn_zones = [Vector3(0, 0, 5)]

	# Throne/altar for boss
	template.decorations = [
		RoomTemplate.make_decoration("altar", Vector3(0, 0, 5)),
		RoomTemplate.make_decoration("pillar", Vector3(-5, 0, -4)),
		RoomTemplate.make_decoration("pillar", Vector3(5, 0, -4)),
		RoomTemplate.make_decoration("pillar", Vector3(-5, 0, 4)),
		RoomTemplate.make_decoration("pillar", Vector3(5, 0, 4)),
	]

	# Dark purple colors
	template.floor_color = Color(0.1, 0.08, 0.12)
	template.wall_color = Color(0.15, 0.1, 0.18)
	template.ceiling_color = Color(0.12, 0.08, 0.15)

	generator.add_template(template)


## Create spawn point for player arrival
func _create_spawn_point() -> void:
	var entrance := generator.get_entrance_room()

	var spawn := Node3D.new()
	spawn.name = "from_town"
	spawn.add_to_group("spawn_points")
	spawn.set_meta("spawn_id", "from_town")

	if entrance:
		# Position in entrance room
		spawn.position = entrance.room_center + Vector3(0, 1.0, -2)
		print("[TestDungeon] Spawn point created at: %s" % spawn.position)
	else:
		# Fallback to origin with safety floor
		spawn.position = Vector3(0, 1.0, 0)
		_create_fallback_floor()
		push_warning("[TestDungeon] No entrance room found! Using fallback spawn at origin.")

	add_child(spawn)

	# Also create a default spawn point in case ZoneDoor doesn't find ours
	var default_spawn := Node3D.new()
	default_spawn.name = "default_spawn"
	default_spawn.position = spawn.position
	default_spawn.add_to_group("spawn_points")
	default_spawn.set_meta("spawn_id", "default")
	add_child(default_spawn)


## Create a fallback floor in case dungeon generation fails
func _create_fallback_floor() -> void:
	var floor_mesh := CSGBox3D.new()
	floor_mesh.name = "FallbackFloor"
	floor_mesh.size = Vector3(20, 1, 20)
	floor_mesh.position = Vector3(0, -0.5, 0)
	floor_mesh.use_collision = true

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.1, 0.1)  # Red to indicate error
	floor_mesh.material = mat

	add_child(floor_mesh)
	print("[TestDungeon] Created fallback floor due to generation failure!")


func _on_generator_complete(_dungeon: DungeonGenerator) -> void:
	# Note: spawn point is already created in _run_generation() after generate()
	# Don't create duplicate spawn points here
	print("[TestDungeon] Dungeon generation complete!")
