## encounter_manager.gd - Daggerfall Unity-style time-based random encounter system
## Checks for encounters at regular intervals based on biome danger, time of day, and road status
extends Node

signal encounter_triggered(encounter_data: Dictionary)
signal encounter_spawned(enemies: Array[Node])  # Emitted when enemies are actually spawned
signal encounter_avoided()

# =============================================================================
# CONSTANTS
# =============================================================================

## Time between encounter checks (in game seconds, 60 = 1 game hour)
const ENCOUNTER_CHECK_INTERVAL := 60.0

## Base encounter chance (4% = 1-in-25)
const BASE_ENCOUNTER_CHANCE := 0.04

## Minimum time between forced encounters (prevent spam)
const MIN_ENCOUNTER_COOLDOWN := 30.0

# =============================================================================
# DANGER MODIFIERS
# =============================================================================

## Biome danger multipliers
const BIOME_DANGER: Dictionary = {
	"plains": 0.8,
	"forest": 1.0,
	"swamp": 1.4,
	"hills": 1.1,
	"rocky": 1.2,
	"mountains": 1.5,
	"desert": 1.3,
	"coast": 0.7,
	"undead": 2.0,
	"horde": 1.8
}

## Road safety modifier (multiplies danger when on roads)
const ROAD_SAFETY_MODIFIER := 0.4  # 60% safer on roads

## Day/night danger modifiers
const DAY_DANGER_MODIFIER := 0.8
const NIGHT_DANGER_MODIFIER := 1.5
const DUSK_DAWN_DANGER_MODIFIER := 1.2

## Weather danger modifiers (if weather system exists)
const WEATHER_DANGER: Dictionary = {
	"clear": 1.0,
	"rain": 1.1,
	"storm": 1.3,
	"fog": 1.4
}

# =============================================================================
# ENCOUNTER TABLES
# =============================================================================

## Encounter tables by biome - each entry is {enemy_type, weight, min_count, max_count}
const ENCOUNTER_TABLES: Dictionary = {
	"plains": [
		{"enemy_type": "wolf", "weight": 30, "min": 1, "max": 3},
		{"enemy_type": "human_bandit", "weight": 25, "min": 1, "max": 4},
		{"enemy_type": "wild_boar", "weight": 20, "min": 1, "max": 2},
		{"enemy_type": "goblin", "weight": 15, "min": 2, "max": 5},
		{"enemy_type": "merchant_caravan", "weight": 10, "min": 1, "max": 1}  # Friendly
	],
	"forest": [
		{"enemy_type": "wolf", "weight": 35, "min": 2, "max": 4},
		{"enemy_type": "giant_spider", "weight": 25, "min": 1, "max": 3},
		{"enemy_type": "human_bandit", "weight": 20, "min": 2, "max": 5},
		{"enemy_type": "goblin", "weight": 15, "min": 3, "max": 6},
		{"enemy_type": "bear", "weight": 5, "min": 1, "max": 1}
	],
	"swamp": [
		{"enemy_type": "giant_spider", "weight": 30, "min": 2, "max": 4},
		{"enemy_type": "skeleton", "weight": 25, "min": 2, "max": 5},
		{"enemy_type": "zombie", "weight": 20, "min": 1, "max": 3},
		{"enemy_type": "wolf", "weight": 15, "min": 1, "max": 2},
		{"enemy_type": "will_o_wisp", "weight": 10, "min": 1, "max": 2}
	],
	"hills": [
		{"enemy_type": "wolf", "weight": 30, "min": 2, "max": 4},
		{"enemy_type": "human_bandit", "weight": 30, "min": 2, "max": 5},
		{"enemy_type": "goblin", "weight": 25, "min": 3, "max": 6},
		{"enemy_type": "orc", "weight": 15, "min": 1, "max": 3}
	],
	"rocky": [
		{"enemy_type": "human_bandit", "weight": 35, "min": 2, "max": 5},
		{"enemy_type": "orc", "weight": 25, "min": 2, "max": 4},
		{"enemy_type": "goblin", "weight": 25, "min": 3, "max": 6},
		{"enemy_type": "troll", "weight": 10, "min": 1, "max": 1},
		{"enemy_type": "giant", "weight": 5, "min": 1, "max": 1}
	],
	"mountains": [
		{"enemy_type": "orc", "weight": 35, "min": 2, "max": 5},
		{"enemy_type": "troll", "weight": 25, "min": 1, "max": 2},
		{"enemy_type": "goblin", "weight": 20, "min": 3, "max": 6},
		{"enemy_type": "giant", "weight": 10, "min": 1, "max": 1},
		{"enemy_type": "harpy", "weight": 10, "min": 2, "max": 4}
	],
	"desert": [
		{"enemy_type": "human_bandit", "weight": 40, "min": 2, "max": 6},
		{"enemy_type": "giant_scorpion", "weight": 30, "min": 1, "max": 3},
		{"enemy_type": "snake", "weight": 20, "min": 2, "max": 4},
		{"enemy_type": "sand_wurm", "weight": 10, "min": 1, "max": 1}
	],
	"undead": [
		{"enemy_type": "skeleton", "weight": 35, "min": 3, "max": 6},
		{"enemy_type": "zombie", "weight": 30, "min": 2, "max": 5},
		{"enemy_type": "ghost", "weight": 20, "min": 1, "max": 3},
		{"enemy_type": "vampire", "weight": 10, "min": 1, "max": 1},
		{"enemy_type": "lich", "weight": 5, "min": 1, "max": 1}
	]
}

## Default encounter table for unmapped biomes
const DEFAULT_ENCOUNTERS: Array = [
	{"enemy_type": "wolf", "weight": 40, "min": 1, "max": 3},
	{"enemy_type": "human_bandit", "weight": 35, "min": 1, "max": 4},
	{"enemy_type": "goblin", "weight": 25, "min": 2, "max": 4}
]

## Enemy spawning config - maps enemy_type to spawn data
const ENEMY_SPAWN_CONFIG: Dictionary = {
	"wolf": {
		"data_path": "res://data/enemies/wolf.tres",
		"sprite_path": "res://Sprite folders grab bag/wolf_moving.png",
		"h_frames": 6,
		"v_frames": 1,
		"is_skeleton": false
	},
	"giant_spider": {
		"data_path": "res://data/enemies/giant_spider.tres",
		"sprite_path": "res://Sprite folders grab bag/evilspider.png",
		"h_frames": 1,
		"v_frames": 1,
		"is_skeleton": false
	},
	"skeleton": {
		"data_path": "res://data/enemies/skeleton.tres",
		"is_skeleton": true
	},
	"goblin": {
		"data_path": "res://data/enemies/goblin_soldier.tres",
		"sprite_path": "res://Sprite folders grab bag/goblin_idle.png",
		"h_frames": 6,
		"v_frames": 1,
		"is_skeleton": false
	},
	"human_bandit": {
		"data_path": "res://data/enemies/human_bandit.tres",
		"sprite_path": "res://Sprite folders grab bag/bandit_idle.png",
		"h_frames": 6,
		"v_frames": 1,
		"is_skeleton": false
	},
	"zombie": {
		"data_path": "res://data/enemies/zombie.tres",
		"sprite_path": "res://Sprite folders grab bag/zombie_idle.png",
		"h_frames": 6,
		"v_frames": 1,
		"is_skeleton": false
	},
	"orc": {
		"data_path": "res://data/enemies/orc.tres",
		"sprite_path": "res://Sprite folders grab bag/orc_idle.png",
		"h_frames": 6,
		"v_frames": 1,
		"is_skeleton": false
	}
}

## Spawn distance from player (outside immediate FOV but nearby)
const SPAWN_DISTANCE_MIN := 15.0
const SPAWN_DISTANCE_MAX := 25.0
const SPAWN_SPREAD := 5.0  # Spread between multiple enemies

# =============================================================================
# STATE
# =============================================================================

## Timer for encounter checks
var _encounter_timer: float = 0.0

## Cooldown timer to prevent encounter spam
var _cooldown_timer: float = 0.0

## RNG for encounter rolls
var _rng: RandomNumberGenerator

## Whether the system is active
var _active: bool = false

## Reference to player for position checks
var _player: Node3D = null

## Last hex where encounter was checked (avoid double-checks)
var _last_check_hex: Vector2i = Vector2i.ZERO

## Statistics
var encounters_triggered: int = 0
var encounters_avoided: int = 0


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

	# Connect to WorldManager for hex change notifications
	# Deferred to ensure WorldManager is ready
	call_deferred("_connect_signals")


## Connect to other autoloads (deferred to ensure they're ready)
func _connect_signals() -> void:
	# Connect to WorldManager.hex_changed for forced encounter checks
	if WorldManager and WorldManager.has_signal("hex_changed"):
		if not WorldManager.hex_changed.is_connected(_on_hex_changed):
			WorldManager.hex_changed.connect(_on_hex_changed)
			print("[EncounterManager] Connected to WorldManager.hex_changed")


## Called when player enters a new hex - force encounter check
func _on_hex_changed(_old_hex: Vector2i, _new_hex: Vector2i) -> void:
	# Force an encounter check when entering a new hex
	force_check()


func _process(delta: float) -> void:
	if not _active or not _player:
		return

	# Update cooldown
	if _cooldown_timer > 0:
		_cooldown_timer -= delta

	# Update encounter timer
	_encounter_timer += delta

	if _encounter_timer >= ENCOUNTER_CHECK_INTERVAL:
		_encounter_timer = 0.0
		_check_for_encounter()


# =============================================================================
# PUBLIC API
# =============================================================================

## Start the encounter system (call when entering wilderness)
func start(player: Node3D) -> void:
	_player = player
	_active = true
	_encounter_timer = 0.0
	_last_check_hex = WorldData.world_to_axial(player.global_position)
	print("[EncounterManager] Started - checking every %.0f seconds" % ENCOUNTER_CHECK_INTERVAL)


## Stop the encounter system (call when entering towns/dungeons)
func stop() -> void:
	_active = false
	_player = null
	print("[EncounterManager] Stopped")


## Force an encounter check (e.g., when entering new hex)
func force_check() -> void:
	if not _active or not _player:
		return

	# Respect cooldown
	if _cooldown_timer > 0:
		return

	_check_for_encounter()


## Get current danger level for the player's position
func get_current_danger_level() -> float:
	if not _player:
		return 1.0

	var hex: Vector2i = WorldData.world_to_axial(_player.global_position)
	return _calculate_danger_level(hex)


## Check if player is in a safe zone (town, building, etc.)
func is_in_safe_zone() -> bool:
	if not _player:
		return true

	var hex: Vector2i = WorldData.world_to_axial(_player.global_position)
	var cell: WorldData.CellData = WorldData.get_cell(hex)

	if not cell:
		return false

	# Towns and settlements are safe
	if cell.location_type in [WorldData.LocationType.VILLAGE, WorldData.LocationType.TOWN,
							   WorldData.LocationType.CITY, WorldData.LocationType.CAPITAL]:
		return true

	return false


# =============================================================================
# INTERNAL LOGIC
# =============================================================================

## Check for a random encounter
func _check_for_encounter() -> void:
	if not _player:
		return

	var hex: Vector2i = WorldData.world_to_axial(_player.global_position)

	# Don't check in safe zones
	if is_in_safe_zone():
		return

	# Calculate encounter chance
	var danger_level: float = _calculate_danger_level(hex)
	var encounter_chance: float = BASE_ENCOUNTER_CHANCE * danger_level

	# Roll for encounter
	var roll: float = _rng.randf()

	print("[EncounterManager] Encounter check at hex %s - danger: %.2f, chance: %.2f%%, roll: %.2f" % [
		hex, danger_level, encounter_chance * 100, roll
	])

	if roll < encounter_chance:
		_trigger_encounter(hex)
	else:
		encounters_avoided += 1
		encounter_avoided.emit()


## Calculate danger level for a hex
func _calculate_danger_level(hex: Vector2i) -> float:
	var danger: float = 1.0

	# Get cell data
	var cell: WorldData.CellData = WorldData.get_cell(hex)

	# Biome modifier
	if cell:
		var biome_name: String = WorldData.Biome.keys()[cell.biome].to_lower()
		danger *= BIOME_DANGER.get(biome_name, 1.0)

		# Road safety
		if cell.is_road:
			danger *= ROAD_SAFETY_MODIFIER

	# Time of day modifier
	danger *= _get_time_danger_modifier()

	# Weather modifier (if weather system exists)
	danger *= _get_weather_danger_modifier()

	return danger


## Get danger modifier based on time of day
func _get_time_danger_modifier() -> float:
	# GameManager has game_time (float 0-24) property
	if GameManager:
		var hour: int = int(GameManager.game_time)

		# Night (22:00 - 05:00)
		if hour >= 22 or hour < 5:
			return NIGHT_DANGER_MODIFIER

		# Dusk/Dawn (05:00 - 07:00 and 19:00 - 22:00)
		if hour < 7 or hour >= 19:
			return DUSK_DAWN_DANGER_MODIFIER

		# Day (07:00 - 19:00)
		return DAY_DANGER_MODIFIER

	# Default to day modifier if no time system
	return DAY_DANGER_MODIFIER


## Get danger modifier based on weather
func _get_weather_danger_modifier() -> float:
	# GameManager has current_weather (Enums.Weather) property
	if GameManager:
		var weather_enum: Enums.Weather = GameManager.current_weather
		var weather_name: String = Enums.Weather.keys()[weather_enum].to_lower()
		return WEATHER_DANGER.get(weather_name, 1.0)

	# Default to clear weather
	return 1.0


## Trigger an encounter
func _trigger_encounter(hex: Vector2i) -> void:
	# Set cooldown
	_cooldown_timer = MIN_ENCOUNTER_COOLDOWN

	# Get biome for encounter table
	var cell: WorldData.CellData = WorldData.get_cell(hex)
	var biome_name: String = "plains"
	if cell:
		biome_name = WorldData.Biome.keys()[cell.biome].to_lower()

	# Select encounter from table
	var encounter_table: Array = ENCOUNTER_TABLES.get(biome_name, DEFAULT_ENCOUNTERS)
	var selected: Dictionary = _weighted_random_select(encounter_table)

	if selected.is_empty():
		return

	# Determine count
	var count: int = _rng.randi_range(selected.get("min", 1), selected.get("max", 1))

	# Build encounter data
	var encounter_data: Dictionary = {
		"enemy_type": selected.get("enemy_type", "wolf"),
		"count": count,
		"hex": hex,
		"biome": biome_name,
		"is_road": cell.is_road if cell else false,
		"danger_level": _calculate_danger_level(hex)
	}

	encounters_triggered += 1
	print("[EncounterManager] ENCOUNTER TRIGGERED: %d x %s at hex %s" % [
		count, encounter_data.enemy_type, hex
	])

	encounter_triggered.emit(encounter_data)

	# Actually spawn the enemies
	var spawned_enemies: Array[Node] = _spawn_encounter_enemies(encounter_data)
	if not spawned_enemies.is_empty():
		encounter_spawned.emit(spawned_enemies)
		# Alert the player
		_alert_player_to_encounter(spawned_enemies[0])


## Weighted random selection from encounter table
func _weighted_random_select(table: Array) -> Dictionary:
	if table.is_empty():
		return {}

	# Calculate total weight
	var total_weight: int = 0
	for entry: Dictionary in table:
		total_weight += entry.get("weight", 1)

	# Roll
	var roll: int = _rng.randi_range(1, total_weight)
	var cumulative: int = 0

	for entry: Dictionary in table:
		cumulative += entry.get("weight", 1)
		if roll <= cumulative:
			return entry

	# Fallback to first entry
	return table[0]


# =============================================================================
# ENEMY SPAWNING
# =============================================================================

## Spawn enemies for an encounter at a position outside player's FOV
func _spawn_encounter_enemies(encounter_data: Dictionary) -> Array[Node]:
	var spawned: Array[Node] = []

	if not _player:
		return spawned

	var enemy_type: String = encounter_data.get("enemy_type", "wolf")
	var count: int = encounter_data.get("count", 1)

	# Get spawn config for this enemy type
	var config: Dictionary = ENEMY_SPAWN_CONFIG.get(enemy_type, {})
	if config.is_empty():
		push_warning("[EncounterManager] No spawn config for enemy type: %s" % enemy_type)
		return spawned

	# Calculate spawn position behind player or to the side
	var spawn_center: Vector3 = _calculate_spawn_position()

	# Get the current wilderness room or scene root as parent
	var parent: Node3D = _get_spawn_parent()
	if not parent:
		push_warning("[EncounterManager] No valid spawn parent found")
		return spawned

	# Spawn each enemy
	for i in range(count):
		# Spread enemies around the spawn center
		var offset := Vector3(
			_rng.randf_range(-SPAWN_SPREAD, SPAWN_SPREAD),
			0,
			_rng.randf_range(-SPAWN_SPREAD, SPAWN_SPREAD)
		)
		var spawn_pos: Vector3 = spawn_center + offset

		var enemy: Node = _spawn_single_enemy(parent, spawn_pos, config)
		if enemy:
			spawned.append(enemy)
			print("[EncounterManager] Spawned %s at %s" % [enemy_type, spawn_pos])

	return spawned


## Calculate spawn position outside player's immediate FOV
func _calculate_spawn_position() -> Vector3:
	if not _player:
		return Vector3.ZERO

	var player_pos: Vector3 = _player.global_position
	var camera: Camera3D = _get_player_camera()

	# Calculate direction behind or to the side of the player
	var spawn_direction: Vector3
	if camera:
		# Get direction behind player (opposite of camera forward)
		var forward: Vector3 = -camera.global_transform.basis.z.normalized()
		# Rotate to be behind/side (random angle between 90 and 270 degrees from forward)
		var angle: float = _rng.randf_range(1.57, 4.71)  # 90 to 270 degrees in radians
		spawn_direction = forward.rotated(Vector3.UP, angle).normalized()
	else:
		# Random direction if no camera
		var angle: float = _rng.randf_range(0, TAU)
		spawn_direction = Vector3(cos(angle), 0, sin(angle))

	# Calculate spawn distance
	var distance: float = _rng.randf_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)

	return player_pos + spawn_direction * distance


## Get the parent node to spawn enemies into
func _get_spawn_parent() -> Node3D:
	# First try to find wilderness room
	var wilderness_rooms: Array[Node] = get_tree().get_nodes_in_group("wilderness_room")
	if not wilderness_rooms.is_empty():
		return wilderness_rooms[0] as Node3D

	# Fall back to scene root
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		if tree.current_scene is Node3D:
			return tree.current_scene as Node3D

	return null


## Get player camera for FOV calculations
func _get_player_camera() -> Camera3D:
	var viewport: Viewport = get_viewport()
	if viewport:
		return viewport.get_camera_3d()
	return null


## Spawn a single enemy
func _spawn_single_enemy(parent: Node3D, pos: Vector3, config: Dictionary) -> Node:
	var enemy: Node = null

	if config.get("is_skeleton", false):
		# Use skeleton spawner
		if EnemyBase:
			enemy = EnemyBase.spawn_skeleton_enemy(
				parent,
				pos,
				config.get("data_path", "")
			)
	else:
		# Load sprite texture
		var sprite_path: String = config.get("sprite_path", "")
		if not ResourceLoader.exists(sprite_path):
			push_warning("[EncounterManager] Sprite not found: %s" % sprite_path)
			return null

		var sprite_tex: Texture2D = load(sprite_path)
		if not sprite_tex:
			return null

		# Spawn billboard enemy
		if EnemyBase:
			enemy = EnemyBase.spawn_billboard_enemy(
				parent,
				pos,
				config.get("data_path", ""),
				sprite_tex,
				config.get("h_frames", 1),
				config.get("v_frames", 1)
			)

	# Tag as encounter spawn for potential special handling
	if enemy:
		enemy.set_meta("encounter_spawn", true)

	return enemy


## Alert player to the encounter (sound, UI notification)
func _alert_player_to_encounter(first_enemy: Node) -> void:
	# Play alert sound
	if AudioManager:
		AudioManager.play_sfx("enemy_alert")

	# Show notification
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Enemies nearby!", Color(1.0, 0.3, 0.3))

	# Optional: Make first enemy roar or give audio cue
	if first_enemy and first_enemy.has_method("play_alert_sound"):
		first_enemy.play_alert_sound()


# =============================================================================
# SAVE/LOAD
# =============================================================================

## Serialize for saving
func to_dict() -> Dictionary:
	return {
		"encounters_triggered": encounters_triggered,
		"encounters_avoided": encounters_avoided
	}


## Deserialize from save
func from_dict(data: Dictionary) -> void:
	encounters_triggered = data.get("encounters_triggered", 0)
	encounters_avoided = data.get("encounters_avoided", 0)


## Reset for new game
func reset_for_new_game() -> void:
	stop()
	encounters_triggered = 0
	encounters_avoided = 0
	_encounter_timer = 0.0
	_cooldown_timer = 0.0
