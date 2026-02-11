## kazan_dun_modular_base.gd - Base class for Kazan-Dun modular levels
## Manages room instances, navigation, NPC/enemy tracking, and door connections
## Extend this class for each Kazan-Dun level (Level 1-5)
class_name KazanDunModularBase
extends Node3D

## Zone configuration
@export var zone_id: String = "kazan_dun_level"
@export var zone_display_name: String = "Kazan-Dun"
@export var zone_size: float = 100.0

## Room management
var room_instances: Dictionary = {}  ## room_id -> ModularRoom
var room_scenes: Dictionary = {}     ## room_id -> PackedScene (for lazy loading)
var active_rooms: Array[ModularRoom] = []

## Entity tracking across all rooms
var all_npcs: Array[Node] = []
var all_enemies: Array[Node] = []

## Navigation
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

## Player tracking
var current_room: ModularRoom = null
var player: Node3D = null

## Signals
signal level_initialized
signal room_changed(from_room: ModularRoom, to_room: ModularRoom)
signal level_cleared


func _ready() -> void:
	add_to_group("level_managers")
	_initialize_level()


## Initialize the level - override in subclasses to register rooms
func _initialize_level() -> void:
	SaveManager.set_current_zone(zone_id, zone_display_name)

	_setup_environment()
	_register_rooms()
	_connect_room_doors()
	_setup_navigation()
	_setup_spawn_points()
	_find_player()

	level_initialized.emit()
	print("[KazanDunModularBase] %s initialized with %d rooms" % [zone_display_name, room_instances.size()])


## Setup environment (WorldEnvironment, lighting)
## Override in subclasses for level-specific atmosphere
func _setup_environment() -> void:
	if has_node("WorldEnvironment"):
		return

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.11, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.48, 0.4)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color(0.35, 0.3, 0.25)
	env.fog_density = 0.012

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	if not has_node("DirectionalLight3D"):
		var light := DirectionalLight3D.new()
		light.name = "DirectionalLight3D"
		light.light_color = Color(0.85, 0.8, 0.75)
		light.light_energy = 0.3
		light.rotation_degrees = Vector3(-45, 30, 0)
		light.shadow_enabled = true
		light.shadow_bias = 0.02
		add_child(light)


## Register all rooms in this level - OVERRIDE in subclasses
## Call register_room() or register_room_scene() for each room
func _register_rooms() -> void:
	# Example registration (override in subclass):
	# register_room_scene("great_hall", "res://scenes/rooms/kazan_dun/great_hall.tscn")
	# register_room_scene("kitchen", "res://scenes/rooms/kazan_dun/kitchen.tscn")
	pass


## Register a room scene for lazy loading
func register_room_scene(room_id: String, scene_path: String) -> void:
	room_scenes[room_id] = scene_path


## Register an already-loaded room instance
func register_room(room_id: String, room: ModularRoom) -> void:
	room.room_id = room_id
	room_instances[room_id] = room

	# Connect room signals
	room.room_entered.connect(_on_room_entered)
	room.room_exited.connect(_on_room_exited)
	room.room_cleared.connect(_on_room_cleared)
	room.npc_spawned.connect(_on_npc_spawned)
	room.enemy_spawned.connect(_on_enemy_spawned)


## Load and instantiate a room from its scene
func load_room(room_id: String) -> ModularRoom:
	if room_instances.has(room_id):
		return room_instances[room_id]

	if not room_scenes.has(room_id):
		push_error("[KazanDunModularBase] Room scene not registered: %s" % room_id)
		return null

	var scene_path: String = room_scenes[room_id]
	var scene: PackedScene = load(scene_path)
	if not scene:
		push_error("[KazanDunModularBase] Failed to load room scene: %s" % scene_path)
		return null

	var room: ModularRoom = scene.instantiate()
	room.room_id = room_id
	add_child(room)
	register_room(room_id, room)

	return room


## Unload a room to free memory (optional for large dungeons)
func unload_room(room_id: String) -> void:
	if not room_instances.has(room_id):
		return

	var room: ModularRoom = room_instances[room_id]

	# Remove from active tracking
	active_rooms.erase(room)

	# Cleanup and remove
	room.cleanup()
	room.queue_free()
	room_instances.erase(room_id)


## Get a room by ID
func get_room(room_id: String) -> ModularRoom:
	if room_instances.has(room_id):
		return room_instances[room_id]

	# Try lazy loading
	if room_scenes.has(room_id):
		return load_room(room_id)

	return null


## Connect doors between rooms - OVERRIDE in subclasses for specific connections
## Call connect_rooms() for each door connection
func _connect_room_doors() -> void:
	# Example (override in subclass):
	# connect_rooms("great_hall", "door_to_kitchen", "kitchen", "door_from_hall")
	pass


## Connect two rooms via their doors
func connect_rooms(room1_id: String, door1_id: String, room2_id: String, door2_id: String) -> void:
	var room1 := get_room(room1_id)
	var room2 := get_room(room2_id)

	if room1 and room2:
		room1.connect_to_room(door1_id, room2, door2_id)
		room2.connect_to_room(door2_id, room1, door1_id)


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		nav_region = get_node_or_null("NavigationRegion3D")

	if not nav_region:
		# Create navigation region if not present
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

	# Defer baking to allow geometry to settle
	call_deferred("_bake_navigation")


## Bake navigation mesh
func _bake_navigation() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()
		print("[KazanDunModularBase] Navigation mesh baked")


## Rebake navigation after room changes
func rebake_navigation() -> void:
	call_deferred("_bake_navigation")


## Setup spawn point metadata
func _setup_spawn_points() -> void:
	var spawn_points := get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	for child in spawn_points.get_children():
		if child.is_in_group("spawn_points"):
			var spawn_id: String = child.name
			child.set_meta("spawn_id", spawn_id)


## Find player node
func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player = players[0]


## Handle room entered
func _on_room_entered(room: ModularRoom) -> void:
	var previous_room := current_room
	current_room = room

	if not active_rooms.has(room):
		active_rooms.append(room)

	room_changed.emit(previous_room, room)


## Handle room exited
func _on_room_exited(room: ModularRoom) -> void:
	# Keep room in active list until player is in a new room
	pass


## Handle room cleared
func _on_room_cleared(room: ModularRoom) -> void:
	_check_level_cleared()


## Handle NPC spawned
func _on_npc_spawned(npc: Node, _room: ModularRoom) -> void:
	if not all_npcs.has(npc):
		all_npcs.append(npc)


## Handle enemy spawned
func _on_enemy_spawned(enemy: Node, _room: ModularRoom) -> void:
	if not all_enemies.has(enemy):
		all_enemies.append(enemy)


## Check if entire level is cleared
func _check_level_cleared() -> void:
	for room_id in room_instances:
		var room: ModularRoom = room_instances[room_id]
		if not room.spawned_enemies.is_empty():
			return

	level_cleared.emit()


## Get all enemies in the level
func get_all_enemies() -> Array[Node]:
	var valid: Array[Node] = []
	for enemy in all_enemies:
		if is_instance_valid(enemy):
			valid.append(enemy)
	all_enemies = valid
	return valid


## Get all NPCs in the level
func get_all_npcs() -> Array[Node]:
	var valid: Array[Node] = []
	for npc in all_npcs:
		if is_instance_valid(npc):
			valid.append(npc)
	all_npcs = valid
	return valid


## Get room containing a world position
func get_room_at_position(world_pos: Vector3) -> ModularRoom:
	for room_id in room_instances:
		var room: ModularRoom = room_instances[room_id]
		if room.contains_point(world_pos):
			return room
	return null


## Teleport player to a specific room's door
func teleport_player_to_room(room_id: String, door_id: String = "") -> void:
	var room := get_room(room_id)
	if not room:
		push_error("[KazanDunModularBase] Cannot teleport: room %s not found" % room_id)
		return

	if not player:
		_find_player()
		if not player:
			push_error("[KazanDunModularBase] Cannot teleport: player not found")
			return

	var target_pos := room.global_position

	if not door_id.is_empty() and room.door_connections.has(door_id):
		target_pos = room.door_connections[door_id].get("position", room.global_position)

	player.global_position = target_pos + Vector3(0, 0.5, 0)


## Find room by predicate
func find_room(predicate: Callable) -> ModularRoom:
	for room_id in room_instances:
		var room: ModularRoom = room_instances[room_id]
		if predicate.call(room):
			return room
	return null


## Get rooms of a specific type
func get_rooms_by_type(room_type: String) -> Array[ModularRoom]:
	var result: Array[ModularRoom] = []
	for room_id in room_instances:
		var room: ModularRoom = room_instances[room_id]
		if room.room_type == room_type:
			result.append(room)
	return result


## Spawn additional enemies in a room (for reinforcements, events, etc.)
func spawn_enemy_in_room(room_id: String, enemy_data_path: String, sprite_path: String, position_offset: Vector3 = Vector3.ZERO) -> Node:
	var room := get_room(room_id)
	if not room:
		return null

	var sprite_texture: Texture2D = load(sprite_path)
	if not sprite_texture:
		return null

	var spawn_pos: Vector3 = room.global_position + position_offset + Vector3(0, 0.5, 0)
	var enemy_id: String = "%s_spawned_%d" % [room_id, all_enemies.size()]

	var enemy = EnemyBase.spawn_billboard_enemy(
		room,
		spawn_pos,
		enemy_data_path,
		sprite_texture,
		3, 1  # Default frames
	)

	if enemy:
		enemy.persistent_id = enemy_id
		enemy.add_to_group("enemies")
		room.spawned_enemies.append(enemy)
		all_enemies.append(enemy)

	return enemy


## Create a door connection between rooms at runtime
func create_door_connection(from_room_id: String, to_room_id: String, from_position: Vector3, to_position: Vector3, door_label: String = "Door") -> void:
	var from_room := get_room(from_room_id)
	var to_room := get_room(to_room_id)

	if not from_room or not to_room:
		return

	# Create a trigger area at from_position that teleports to to_position
	var trigger := Area3D.new()
	trigger.name = "DoorTo_%s" % to_room_id
	trigger.collision_layer = 0
	trigger.collision_mask = 2  # Player

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 1)
	shape.shape = box
	trigger.add_child(shape)

	trigger.position = from_position
	from_room.add_child(trigger)

	trigger.body_entered.connect(func(body):
		if body.is_in_group("player"):
			body.global_position = to_position + Vector3(0, 0.5, 0)
			_on_room_entered(to_room)
	)


## Save level state
func save_state() -> Dictionary:
	var state := {
		"zone_id": zone_id,
		"rooms": {}
	}

	for room_id in room_instances:
		var room: ModularRoom = room_instances[room_id]
		state.rooms[room_id] = {
			"enemies_remaining": room.spawned_enemies.size(),
			"is_cleared": room.spawned_enemies.is_empty()
		}

	return state


## Load level state (called by save system)
func load_state(state: Dictionary) -> void:
	if state.has("rooms"):
		for room_id in state.rooms:
			var room_state: Dictionary = state.rooms[room_id]
			# Room-specific state loading can be implemented here
			pass


## Cleanup level
func cleanup() -> void:
	for room_id in room_instances:
		var room: ModularRoom = room_instances[room_id]
		room.cleanup()

	room_instances.clear()
	room_scenes.clear()
	active_rooms.clear()
	all_npcs.clear()
	all_enemies.clear()
