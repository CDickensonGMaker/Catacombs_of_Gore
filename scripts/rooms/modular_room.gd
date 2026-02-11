## modular_room.gd - Base class for hand-crafted modular rooms
## Used by Kazan-Dun and other modular dungeon systems
## Handles NPC spawning, enemy spawning, chest spawning, and door connections
class_name ModularRoom
extends Node3D

## Room identification
@export var room_id: String = ""
@export var room_type: String = "generic"  ## residential, market, forge, bridge, vault, etc.
@export var room_name: String = "Room"

## Room dimensions (used for bounds checking)
@export var room_width: float = 20.0
@export var room_depth: float = 20.0
@export var room_height: float = 8.0

## Connection points for doors (populated from DoorConnection markers)
var door_connections: Dictionary = {}  ## door_id -> {target_room_id, target_door_id, door_node}

## Spawned entities tracking
var spawned_npcs: Array[Node] = []
var spawned_enemies: Array[Node] = []
var spawned_chests: Array[Node] = []

## State
var is_initialized: bool = false
var is_player_inside: bool = false

## Signals
signal room_entered(room: ModularRoom)
signal room_exited(room: ModularRoom)
signal room_cleared(room: ModularRoom)
signal npc_spawned(npc: Node, room: ModularRoom)
signal enemy_spawned(enemy: Node, room: ModularRoom)


func _ready() -> void:
	add_to_group("modular_rooms")
	_initialize_room()


## Initialize the room - finds markers and spawns entities
func _initialize_room() -> void:
	if is_initialized:
		return

	_process_npc_markers()
	_process_enemy_markers()
	_process_chest_markers()
	_process_door_markers()
	_setup_room_trigger()

	is_initialized = true
	print("[ModularRoom] %s initialized (NPCs: %d, Enemies: %d, Chests: %d)" % [
		room_id if room_id else name,
		spawned_npcs.size(),
		spawned_enemies.size(),
		spawned_chests.size()
	])


## Process NPC spawn markers (Marker3D nodes with npc_type metadata)
func _process_npc_markers() -> void:
	var npc_spawns := get_node_or_null("NPCSpawns")
	if not npc_spawns:
		return

	for marker in npc_spawns.get_children():
		if not (marker is Marker3D or marker is Node3D):
			continue

		var npc := _spawn_npc_from_marker(marker)
		if npc:
			spawned_npcs.append(npc)
			npc_spawned.emit(npc, self)


## Spawn an NPC from a marker's metadata
## Expected metadata:
##   npc_type: String (civilian, guard, merchant, quest_giver, etc.)
##   npc_name: String (display name)
##   npc_id: String (unique persistent ID)
##   dialogue_id: String (optional dialogue data path)
##   archetype: String (optional NPC archetype for conversation system)
func _spawn_npc_from_marker(marker: Node3D) -> Node:
	var npc_type: String = marker.get_meta("npc_type", "civilian")
	var npc_name: String = marker.get_meta("npc_name", "NPC")
	var npc_id: String = marker.get_meta("npc_id", "%s_%s" % [room_id, marker.name])
	var dialogue_id: String = marker.get_meta("dialogue_id", "")
	var archetype: String = marker.get_meta("archetype", "commoner")
	var sprite_path: String = marker.get_meta("sprite_path", "")
	var zone_id: String = marker.get_meta("zone_id", room_id)

	var spawn_pos: Vector3 = marker.global_position

	var npc: Node = null

	match npc_type:
		"civilian", "dwarf_civilian":
			npc = _spawn_civilian_npc(spawn_pos, npc_name, npc_id, zone_id)
		"guard", "dwarf_guard":
			npc = _spawn_guard_npc(spawn_pos, npc_name, npc_id, zone_id)
		"merchant":
			npc = _spawn_merchant_npc(marker, spawn_pos)
		"quest_giver":
			npc = _spawn_quest_giver(marker, spawn_pos)
		"dwarf_warrior":
			npc = _spawn_dwarf_warrior(spawn_pos, npc_name, npc_id, zone_id)
		"dwarf_refugee":
			npc = _spawn_dwarf_refugee(spawn_pos, npc_name, npc_id, zone_id)
		"dwarf_wounded":
			npc = _spawn_dwarf_wounded(spawn_pos, npc_name, npc_id, zone_id)
		_:
			# Generic NPC spawn
			npc = _spawn_civilian_npc(spawn_pos, npc_name, npc_id, zone_id)

	if npc and not dialogue_id.is_empty():
		if npc.has_method("set_dialogue_data"):
			npc.set_dialogue_data(dialogue_id)
		elif "dialogue_data_path" in npc:
			npc.dialogue_data_path = dialogue_id

	return npc


## Spawn a civilian NPC
func _spawn_civilian_npc(pos: Vector3, npc_name: String, npc_id: String, zone_id: String) -> Node:
	if not ClassDB.class_exists("CivilianNPC"):
		push_warning("[ModularRoom] CivilianNPC class not found")
		return null

	var npc = CivilianNPC.spawn_dwarf_civilian(self, pos, zone_id)
	if npc:
		npc.npc_name = npc_name
		npc.npc_id = npc_id
	return npc


## Spawn a guard NPC
func _spawn_guard_npc(pos: Vector3, npc_name: String, npc_id: String, zone_id: String) -> Node:
	if not ClassDB.class_exists("CivilianNPC"):
		push_warning("[ModularRoom] CivilianNPC class not found")
		return null

	var npc = CivilianNPC.spawn_dwarf_guard(self, pos, zone_id)
	if npc:
		npc.npc_name = npc_name
		npc.npc_id = npc_id
	return npc


## Spawn a dwarf warrior NPC
func _spawn_dwarf_warrior(pos: Vector3, npc_name: String, npc_id: String, zone_id: String) -> Node:
	if not ClassDB.class_exists("CivilianNPC"):
		return null

	var npc = CivilianNPC.spawn_dwarf_warrior(self, pos, zone_id)
	if npc:
		npc.npc_name = npc_name
		npc.npc_id = npc_id
	return npc


## Spawn a dwarf refugee NPC
func _spawn_dwarf_refugee(pos: Vector3, npc_name: String, npc_id: String, zone_id: String) -> Node:
	if not ClassDB.class_exists("CivilianNPC"):
		return null

	var npc = CivilianNPC.spawn_dwarf_refugee(self, pos, zone_id)
	if npc:
		npc.npc_name = npc_name
		npc.npc_id = npc_id
	return npc


## Spawn a wounded dwarf NPC
func _spawn_dwarf_wounded(pos: Vector3, npc_name: String, npc_id: String, zone_id: String) -> Node:
	if not ClassDB.class_exists("CivilianNPC"):
		return null

	var npc = CivilianNPC.spawn_dwarf_wounded(self, pos, zone_id)
	if npc:
		npc.npc_name = npc_name
		npc.npc_id = npc_id
	return npc


## Spawn a merchant NPC from marker metadata
func _spawn_merchant_npc(marker: Node3D, pos: Vector3) -> Node:
	var merchant_name: String = marker.get_meta("merchant_name", "Merchant")
	var shop_tier: int = marker.get_meta("shop_tier", 2)
	var merchant_type: String = marker.get_meta("merchant_type", "general")

	# Use Merchant scene if available
	var merchant_scene: PackedScene = load("res://scenes/world/merchant_instance.tscn")
	if merchant_scene:
		var merchant: Node = merchant_scene.instantiate()
		merchant.position = pos
		if "merchant_name" in merchant:
			merchant.merchant_name = merchant_name
		if "shop_tier" in merchant:
			merchant.shop_tier = shop_tier
		add_child(merchant)
		return merchant

	return null


## Spawn a quest giver NPC from marker metadata
func _spawn_quest_giver(marker: Node3D, pos: Vector3) -> Node:
	var quest_ids: Array = marker.get_meta("quest_ids", [])
	var npc_name: String = marker.get_meta("npc_name", "Quest Giver")
	var npc_id: String = marker.get_meta("npc_id", "%s_quest_giver" % room_id)

	if not ClassDB.class_exists("QuestGiver"):
		push_warning("[ModularRoom] QuestGiver class not found")
		return null

	var quest_giver = QuestGiver.spawn_quest_giver(self, pos, npc_name, npc_id)
	if quest_giver and not quest_ids.is_empty():
		quest_giver.quest_ids = quest_ids
	return quest_giver


## Process enemy spawn markers
## Expected metadata:
##   enemy_data: String (path to .tres enemy data file)
##   sprite_path: String (path to sprite texture)
##   h_frames: int (sprite sheet columns)
##   v_frames: int (sprite sheet rows)
##   patrol_radius: float (optional patrol area)
##   aggro_range: float (optional detection range)
func _process_enemy_markers() -> void:
	var enemy_spawns := get_node_or_null("EnemySpawns")
	if not enemy_spawns:
		return

	for marker in enemy_spawns.get_children():
		if not (marker is Marker3D or marker is Node3D):
			continue

		var enemy := _spawn_enemy_from_marker(marker)
		if enemy:
			spawned_enemies.append(enemy)
			enemy_spawned.emit(enemy, self)
			_connect_enemy_signals(enemy)


## Spawn an enemy from marker metadata
func _spawn_enemy_from_marker(marker: Node3D) -> Node:
	var enemy_data_path: String = marker.get_meta("enemy_data", "res://data/enemies/human_bandit.tres")
	var sprite_path: String = marker.get_meta("sprite_path", "res://assets/sprites/enemies/human_bandit.png")
	var h_frames: int = marker.get_meta("h_frames", 3)
	var v_frames: int = marker.get_meta("v_frames", 1)
	var patrol_radius: float = marker.get_meta("patrol_radius", 0.0)
	var aggro_range: float = marker.get_meta("aggro_range", 10.0)

	# Generate persistent ID for save/load
	var enemy_id: String = marker.get_meta("enemy_id", "%s_%s" % [room_id, marker.name])

	# Check if enemy was already killed
	if SaveManager.was_enemy_killed(enemy_id):
		return null

	var sprite_texture: Texture2D = load(sprite_path)
	if not sprite_texture:
		push_error("[ModularRoom] Failed to load enemy sprite: %s" % sprite_path)
		return null

	var spawn_pos: Vector3 = marker.global_position + Vector3(0, 0.5, 0)

	var enemy = EnemyBase.spawn_billboard_enemy(
		self,
		spawn_pos,
		enemy_data_path,
		sprite_texture,
		h_frames,
		v_frames
	)

	if enemy:
		enemy.persistent_id = enemy_id
		enemy.add_to_group("enemies")

		# Configure patrol behavior if specified
		if patrol_radius > 0 and enemy.has_method("set"):
			if "behavior_mode" in enemy:
				enemy.behavior_mode = 2  # BehaviorMode.WANDER
			if "wander_radius" in enemy:
				enemy.wander_radius = patrol_radius
			if "aggro_range" in enemy:
				enemy.aggro_range = aggro_range

	return enemy


## Connect enemy death signals
func _connect_enemy_signals(enemy: Node) -> void:
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))


## Handle enemy death
func _on_enemy_died(_killer: Node, enemy: Node) -> void:
	spawned_enemies.erase(enemy)
	_check_room_cleared()


## Check if room is cleared of enemies
func _check_room_cleared() -> void:
	# Filter out invalid/dead enemies
	var valid_enemies: Array[Node] = []
	for enemy in spawned_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			if enemy.has_method("is_dead") and not enemy.is_dead():
				valid_enemies.append(enemy)
	spawned_enemies = valid_enemies

	if spawned_enemies.is_empty():
		room_cleared.emit(self)


## Process chest spawn markers
## Expected metadata:
##   chest_id: String (unique persistent ID)
##   chest_name: String (display name)
##   is_locked: bool
##   lock_difficulty: int (DC for lockpicking)
##   loot_tier: String (junk, common, uncommon, rare, epic, legendary)
##   is_persistent: bool (if true, chest remains after emptying)
func _process_chest_markers() -> void:
	var chest_positions := get_node_or_null("ChestPositions")
	if not chest_positions:
		return

	for marker in chest_positions.get_children():
		if not (marker is Marker3D or marker is Node3D):
			continue

		var chest := _spawn_chest_from_marker(marker)
		if chest:
			spawned_chests.append(chest)


## Spawn a chest from marker metadata
func _spawn_chest_from_marker(marker: Node3D) -> Node:
	var chest_id: String = marker.get_meta("chest_id", "%s_%s" % [room_id, marker.name])
	var chest_name: String = marker.get_meta("chest_name", "Chest")
	var is_locked: bool = marker.get_meta("is_locked", false)
	var lock_difficulty: int = marker.get_meta("lock_difficulty", 10)
	var loot_tier_str: String = marker.get_meta("loot_tier", "common")
	var is_persistent: bool = marker.get_meta("is_persistent", false)

	var chest := Chest.spawn_chest(
		self,
		marker.global_position,
		chest_name,
		is_locked,
		lock_difficulty,
		is_persistent,
		chest_id
	)

	if chest:
		chest.rotation = marker.rotation
		var tier: LootTables.LootTier = _get_loot_tier(loot_tier_str)
		chest.setup_with_loot(tier)

	return chest


## Convert loot tier string to enum
func _get_loot_tier(tier_name: String) -> LootTables.LootTier:
	match tier_name.to_lower():
		"junk":
			return LootTables.LootTier.JUNK
		"common":
			return LootTables.LootTier.COMMON
		"uncommon":
			return LootTables.LootTier.UNCOMMON
		"rare":
			return LootTables.LootTier.RARE
		"epic":
			return LootTables.LootTier.EPIC
		"legendary":
			return LootTables.LootTier.LEGENDARY
		_:
			return LootTables.LootTier.COMMON


## Process door connection markers
## Expected metadata:
##   target_room_id: String (room to connect to)
##   target_door_id: String (door in target room)
##   door_label: String (display name)
##   is_locked: bool
##   lock_difficulty: int
func _process_door_markers() -> void:
	var door_positions := get_node_or_null("DoorPositions")
	if not door_positions:
		return

	for marker in door_positions.get_children():
		if not (marker is Marker3D or marker is Node3D):
			continue

		var door_id: String = marker.get_meta("door_id", marker.name)
		var target_room_id: String = marker.get_meta("target_room_id", "")
		var target_door_id: String = marker.get_meta("target_door_id", "")
		var target_scene: String = marker.get_meta("target_scene", "")
		var spawn_id: String = marker.get_meta("spawn_id", "default")
		var door_label: String = marker.get_meta("door_label", "Door")
		var show_frame: bool = marker.get_meta("show_frame", true)
		var is_locked: bool = marker.get_meta("is_locked", false)
		var lock_difficulty: int = marker.get_meta("lock_difficulty", 10)

		# Store connection info
		door_connections[door_id] = {
			"target_room_id": target_room_id,
			"target_door_id": target_door_id,
			"position": marker.global_position,
			"rotation": marker.rotation
		}

		# If target_scene is specified, create a ZoneDoor for scene transitions
		if not target_scene.is_empty():
			var door := ZoneDoor.spawn_door(
				self,
				marker.global_position,
				target_scene,
				spawn_id,
				door_label,
				show_frame
			)
			if door:
				door.rotation = marker.rotation
				door.is_locked = is_locked
				door.lock_difficulty = lock_difficulty
				door_connections[door_id]["door_node"] = door


## Setup room boundary trigger for enter/exit detection
func _setup_room_trigger() -> void:
	# Check if a trigger already exists
	var existing_trigger := get_node_or_null("RoomTrigger")
	if existing_trigger:
		if existing_trigger is Area3D:
			existing_trigger.body_entered.connect(_on_body_entered_room)
			existing_trigger.body_exited.connect(_on_body_exited_room)
		return

	# Create a trigger area based on room dimensions
	var trigger := Area3D.new()
	trigger.name = "RoomTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 2  # Player layer

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(room_width, room_height, room_depth)
	shape.shape = box
	shape.position = Vector3(0, room_height / 2.0, 0)
	trigger.add_child(shape)

	trigger.body_entered.connect(_on_body_entered_room)
	trigger.body_exited.connect(_on_body_exited_room)

	add_child(trigger)


## Handle player entering room
func _on_body_entered_room(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_player_inside = true
		room_entered.emit(self)


## Handle player exiting room
func _on_body_exited_room(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_player_inside = false
		room_exited.emit(self)


## Get room bounds as AABB
func get_bounds() -> AABB:
	return AABB(
		global_position + Vector3(-room_width / 2.0, 0, -room_depth / 2.0),
		Vector3(room_width, room_height, room_depth)
	)


## Check if a world position is inside this room
func contains_point(world_pos: Vector3) -> bool:
	return get_bounds().has_point(world_pos)


## Get a door connection by ID
func get_door_connection(door_id: String) -> Dictionary:
	return door_connections.get(door_id, {})


## Connect two rooms via doors (called by level manager)
func connect_to_room(local_door_id: String, target_room: ModularRoom, target_door_id: String) -> void:
	if not door_connections.has(local_door_id):
		push_warning("[ModularRoom] Door %s not found in room %s" % [local_door_id, room_id])
		return

	door_connections[local_door_id]["connected_room"] = target_room
	door_connections[local_door_id]["target_door_id"] = target_door_id


## Get all active enemies in this room
func get_enemies() -> Array[Node]:
	var valid: Array[Node] = []
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			valid.append(enemy)
	return valid


## Get all NPCs in this room
func get_npcs() -> Array[Node]:
	var valid: Array[Node] = []
	for npc in spawned_npcs:
		if is_instance_valid(npc):
			valid.append(npc)
	return valid


## Cleanup room (call before removing)
func cleanup() -> void:
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	spawned_enemies.clear()

	for npc in spawned_npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	spawned_npcs.clear()

	for chest in spawned_chests:
		if is_instance_valid(chest):
			chest.queue_free()
	spawned_chests.clear()

	door_connections.clear()
