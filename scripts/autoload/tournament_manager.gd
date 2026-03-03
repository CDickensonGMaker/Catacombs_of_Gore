## tournament_manager.gd - Manages Combat Arena tournament at Bloodsand Arena
## Handles 5-wave tournament, equipment locking, barriers, and rewards
## NOTE: This is an autoload singleton - do not use class_name
extends Node

## Preload scripts for spawning arena enemies (avoids class resolution issues in autoloads)
const GladiatorNPCScript = preload("res://scripts/npcs/gladiator_npc.gd")
## EnemyBase is loaded lazily at runtime to avoid circular dependency issues
var _enemy_base_script: GDScript = null

## Tournament tier levels
enum TournamentTier { NOVICE, VETERAN, CHAMPION, LEGEND }

## Signals for tournament events
signal tournament_started()
signal wave_started(wave_number: int, total_waves: int)
signal wave_complete(wave_number: int, gold_earned: int)
signal tournament_won(total_gold: int)
signal tournament_lost()
signal barrier_enabled()
signal barrier_disabled()
signal equipment_lock_changed(is_locked: bool)

## Wave definition structure
## Each wave is an array of dictionaries: {"enemy_type": String, "count": int}
const WAVE_DEFINITIONS: Array = [
	# Wave 1: 2 foot swordsmen
	[
		{"enemy_type": "arena_gladiator_novice", "count": 2}
	],
	# Wave 2: 3 swordsmen + 2 archers
	[
		{"enemy_type": "arena_gladiator_novice", "count": 3},
		{"enemy_type": "goblin_archer", "count": 2}
	],
	# Wave 3: 2 wolves + 2 foot soldiers + 3 archers
	[
		{"enemy_type": "wolf", "count": 2},
		{"enemy_type": "arena_gladiator_novice", "count": 2},
		{"enemy_type": "goblin_archer", "count": 3}
	],
	# Wave 4: 4 abominations
	[
		{"enemy_type": "abomination", "count": 4}
	],
	# Wave 5: All previous waves back to back (spawns all at once for intensity)
	[
		{"enemy_type": "arena_gladiator_novice", "count": 2},  # From wave 1
		{"enemy_type": "arena_gladiator_novice", "count": 3},  # From wave 2
		{"enemy_type": "goblin_archer", "count": 2},          # From wave 2
		{"enemy_type": "wolf", "count": 2},                   # From wave 3
		{"enemy_type": "arena_gladiator_novice", "count": 2},  # From wave 3
		{"enemy_type": "goblin_archer", "count": 3},          # From wave 3
		{"enemy_type": "abomination", "count": 4}             # From wave 4
	]
]

## Base gold reward per wave (multiplied by wave number and random factor)
const BASE_GOLD_REWARD: int = 50

## Total number of waves
const TOTAL_WAVES: int = 5

## Tournament state
var is_tournament_active: bool = false
var current_wave: int = 0
var is_equipment_locked: bool = false
var total_gold_earned: int = 0

## Active enemies in current wave
var current_wave_enemies: Array[Node] = []

## Arena fame (legacy support - kept for save compatibility)
var arena_fame: int = 0


func _ready() -> void:
	# Connect to combat signals to track kills
	if CombatManager:
		CombatManager.entity_killed.connect(_on_entity_killed)

	# Connect to scene manager to clear node references before scene changes
	if SceneManager:
		SceneManager.scene_load_started.connect(_on_scene_load_started)


## Called when a scene change begins - clear all node references to prevent stale casts
func _on_scene_load_started(_scene_path: String) -> void:
	_clear_node_references()


## Clear all node references to prevent "Trying to cast a freed object" errors
## Called at the START of scene transitions, before the old scene is freed
func _clear_node_references() -> void:
	# Clear enemy references since they will be freed with the old scene
	current_wave_enemies.clear()

	# If tournament was active, reset state (player is leaving the arena)
	if is_tournament_active:
		is_tournament_active = false
		current_wave = 0
		is_equipment_locked = false


## Check if player can enter the tournament
func can_enter_tournament() -> Dictionary:
	if is_tournament_active:
		return {"can_enter": false, "reason": "Already in tournament"}
	return {"can_enter": true, "reason": ""}


## Start a new tournament from wave 1
func start_tournament() -> bool:
	var check: Dictionary = can_enter_tournament()
	if not check.get("can_enter", false):
		push_warning("[TournamentManager] Cannot start tournament: %s" % check.get("reason", "unknown"))
		return false

	# Reset tournament state
	is_tournament_active = true
	current_wave = 0
	total_gold_earned = 0

	# Lock equipment
	_set_equipment_locked(true)

	print("[TournamentManager] Tournament started!")
	tournament_started.emit()

	# Start first wave
	start_next_wave()

	return true


## Start the next wave of the tournament
func start_next_wave() -> void:
	if not is_tournament_active:
		return

	current_wave += 1

	if current_wave > TOTAL_WAVES:
		# Tournament complete!
		_complete_tournament()
		return

	print("[TournamentManager] Starting wave %d/%d" % [current_wave, TOTAL_WAVES])

	# Enable arena barrier
	barrier_enabled.emit()

	# Emit wave started signal
	wave_started.emit(current_wave, TOTAL_WAVES)

	# Spawn enemies for this wave
	_spawn_wave_enemies()


## Spawn enemies for the current wave
func _spawn_wave_enemies() -> void:
	current_wave_enemies.clear()

	# Get arena reference
	var arena := _get_arena()
	if not arena:
		push_error("[TournamentManager] Cannot find arena to spawn enemies")
		return

	if not arena.has_method("get_gladiator_spawn_positions"):
		push_error("[TournamentManager] Arena missing get_gladiator_spawn_positions method")
		return

	var spawn_positions: Array[Vector3] = arena.get_gladiator_spawn_positions()
	if spawn_positions.is_empty():
		push_error("[TournamentManager] No gladiator spawn positions found")
		return

	# Get wave definition (0-indexed array)
	var wave_index: int = current_wave - 1
	if wave_index < 0 or wave_index >= WAVE_DEFINITIONS.size():
		push_error("[TournamentManager] Invalid wave index: %d" % wave_index)
		return

	var wave_def: Array = WAVE_DEFINITIONS[wave_index]
	var spawn_index: int = 0

	for group: Dictionary in wave_def:
		var enemy_type: String = group.get("enemy_type", "arena_gladiator_novice")
		var count: int = group.get("count", 1)

		for i in range(count):
			var spawn_pos: Vector3 = spawn_positions[spawn_index % spawn_positions.size()]
			spawn_index += 1

			# Add slight random offset to prevent enemies stacking
			spawn_pos.x += randf_range(-1.5, 1.5)
			spawn_pos.z += randf_range(-1.5, 1.5)

			_spawn_enemy(arena, spawn_pos, enemy_type)

	print("[TournamentManager] Spawned %d enemies for wave %d" % [current_wave_enemies.size(), current_wave])


## Spawn a single enemy
func _spawn_enemy(arena: Node, spawn_pos: Vector3, enemy_type: String) -> void:
	# Load enemy data
	var enemy_data_path: String = "res://data/enemies/%s.tres" % enemy_type
	var enemy_data: EnemyData = load(enemy_data_path) as EnemyData

	if not enemy_data:
		push_error("[TournamentManager] Cannot load enemy data for: %s" % enemy_type)
		return

	# Use GladiatorNPC if available, otherwise fall back to EnemyBase
	var enemy: Node = null

	if GladiatorNPCScript:
		enemy = GladiatorNPCScript.spawn_gladiator(
			arena,
			spawn_pos,
			enemy_data,
			TournamentTier.NOVICE  # Use enum instead of magic number
		)
	else:
		# Fallback to standard enemy spawning
		# Check ActorRegistry for Zoo patches first
		var sprite_path: String = enemy_data.sprite_path if enemy_data.sprite_path else enemy_data.icon_path
		var h_frames: int = enemy_data.sprite_hframes if enemy_data.sprite_hframes > 0 else 4
		var v_frames: int = enemy_data.sprite_vframes if enemy_data.sprite_vframes > 0 else 4

		if ActorRegistry:
			var sprite_config: Dictionary = ActorRegistry.get_sprite_config(enemy_type)
			if not sprite_config.is_empty():
				sprite_path = sprite_config.get("sprite_path", sprite_path)
				h_frames = sprite_config.get("h_frames", h_frames)
				v_frames = sprite_config.get("v_frames", v_frames)

		if sprite_path.is_empty():
			sprite_path = "res://assets/sprites/enemies/human_bandit.png"

		var sprite_texture: Texture2D = load(sprite_path) as Texture2D
		if sprite_texture:
			# Lazy load EnemyBase to avoid circular dependency at parse time
			if not _enemy_base_script:
				_enemy_base_script = load("res://scripts/enemies/enemy_base.gd")
			if _enemy_base_script:
				enemy = _enemy_base_script.spawn_billboard_enemy(
					arena,
					spawn_pos,
					enemy_data_path,
					sprite_texture,
					h_frames,
					v_frames
				)

	if enemy:
		enemy.add_to_group("tournament_enemy")
		current_wave_enemies.append(enemy)


## Get the arena node
func _get_arena() -> Node:
	var arena := get_tree().get_first_node_in_group("bloodsand_arena")
	if arena:
		return arena

	# Try to find by zone_id
	for node: Node in get_tree().get_nodes_in_group("level_root"):
		if "ZONE_ID" in node and node.ZONE_ID == "bloodsand_arena":
			return node

	return null


## Called when an entity is killed
func _on_entity_killed(victim: Node, _killer: Node) -> void:
	if not is_tournament_active:
		return

	# Check if victim is valid and is a tournament enemy
	if is_instance_valid(victim) and victim.is_in_group("tournament_enemy"):
		current_wave_enemies.erase(victim)

		# Clean up any other invalid enemies from the list
		_cleanup_invalid_enemies()

		# Check if wave is complete
		if current_wave_enemies.is_empty():
			_on_wave_complete()


## Remove any invalid/freed enemies from tracking array
func _cleanup_invalid_enemies() -> void:
	var valid_enemies: Array[Node] = []
	for enemy: Node in current_wave_enemies:
		if is_instance_valid(enemy):
			valid_enemies.append(enemy)
	current_wave_enemies = valid_enemies


## Called when all enemies in a wave are defeated
func _on_wave_complete() -> void:
	# Calculate wave rewards: base_gold * wave_number * random(1.0 to 2.0)
	var random_multiplier: float = randf_range(1.0, 2.0)
	var gold_earned: int = int(BASE_GOLD_REWARD * current_wave * random_multiplier)

	# Give gold reward
	if GameManager and GameManager.player_data:
		GameManager.player_data.gold += gold_earned
	total_gold_earned += gold_earned

	print("[TournamentManager] Wave %d complete! Earned %d gold" % [current_wave, gold_earned])

	# Disable arena barrier
	barrier_disabled.emit()

	# Emit wave complete signal
	wave_complete.emit(current_wave, gold_earned)

	# Move player to waiting area
	_teleport_player_to_waiting_area()

	# The arena master will handle showing the continue/leave dialogue
	# via the wave_complete signal


## Teleport player to the waiting area
func _teleport_player_to_waiting_area() -> void:
	var arena := _get_arena()
	if not arena:
		return

	if not arena.has_method("get_waiting_area_position"):
		push_warning("[TournamentManager] Arena missing get_waiting_area_position method")
		return

	var waiting_pos: Vector3 = arena.get_waiting_area_position()

	# Find player and teleport
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_global_position"):
		player.global_position = waiting_pos
	elif player:
		player.global_position = waiting_pos


## Called when player is defeated
func on_player_defeated() -> void:
	if not is_tournament_active:
		return

	print("[TournamentManager] Player defeated in wave %d" % current_wave)

	# Clean up remaining enemies
	for enemy: Node in current_wave_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	current_wave_enemies.clear()

	# Disable barrier
	barrier_disabled.emit()

	# Unlock equipment
	_set_equipment_locked(false)

	# End tournament
	is_tournament_active = false
	current_wave = 0

	tournament_lost.emit()


## Player chose to leave the tournament between waves
func leave_tournament() -> void:
	if not is_tournament_active:
		return

	print("[TournamentManager] Player left tournament after wave %d with %d gold" % [current_wave, total_gold_earned])

	# Unlock equipment
	_set_equipment_locked(false)

	# End tournament
	is_tournament_active = false
	current_wave = 0

	# Note: Gold was already given during wave completion, so no additional rewards


## Complete the tournament successfully
func _complete_tournament() -> void:
	print("[TournamentManager] Tournament complete! Total gold earned: %d" % total_gold_earned)

	# Unlock equipment
	_set_equipment_locked(false)

	# Give fame bonus
	var old_fame: int = arena_fame
	arena_fame += 50
	arena_fame = mini(arena_fame, 1000)

	# End tournament
	is_tournament_active = false

	tournament_won.emit(total_gold_earned)


## Set equipment lock state
func _set_equipment_locked(locked: bool) -> void:
	is_equipment_locked = locked
	equipment_lock_changed.emit(locked)
	print("[TournamentManager] Equipment lock: %s" % ("LOCKED" if locked else "UNLOCKED"))


## Check if equipment changes are allowed
func can_change_equipment() -> bool:
	return not is_equipment_locked


## Get current wave number (1-5, or 0 if not in tournament)
func get_current_wave() -> int:
	return current_wave if is_tournament_active else 0


## Get total waves
func get_total_waves() -> int:
	return TOTAL_WAVES


## Get fame title (legacy support)
func get_fame_title() -> String:
	if arena_fame >= 500:
		return "Legend"
	elif arena_fame >= 300:
		return "Champion"
	elif arena_fame >= 150:
		return "Warrior"
	elif arena_fame >= 75:
		return "Contender"
	elif arena_fame >= 25:
		return "Newcomer"
	return "Unknown"


## Save tournament data
func get_save_data() -> Dictionary:
	return {
		"arena_fame": arena_fame,
		"is_tournament_active": is_tournament_active,
		"current_wave": current_wave,
		"total_gold_earned": total_gold_earned,
		"is_equipment_locked": is_equipment_locked
	}


## Load tournament data
func load_save_data(data: Dictionary) -> void:
	arena_fame = data.get("arena_fame", 0)
	is_tournament_active = data.get("is_tournament_active", false)
	current_wave = data.get("current_wave", 0)
	total_gold_earned = data.get("total_gold_earned", 0)
	is_equipment_locked = data.get("is_equipment_locked", false)

	# If tournament was active when saved, reset it (player respawns outside)
	if is_tournament_active:
		is_tournament_active = false
		current_wave = 0
		is_equipment_locked = false
		_set_equipment_locked(false)
