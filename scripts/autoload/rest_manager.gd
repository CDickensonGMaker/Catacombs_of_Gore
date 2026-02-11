## rest_manager.gd - Centralized rest and respawn management
## Handles all rest types, diminishing returns, and respawn rules
extends Node

signal rest_completed(rest_type: RestType, hp_restored: int, mana_restored: int)
signal respawn_triggered(zone_id: String)

## Rest types available in the game
enum RestType {
	WILDERNESS_WAIT,   # Free, diminishing returns
	BEDROLL,           # Consumable, resets DR
	WILD_FIREPLACE,    # Free rare spawn, always 25%
	TAVERN_FIREPLACE,  # Level up + wait only, NO healing
	INN_BED            # Paid, full rest
}

## Respawn modes for different area types
enum RespawnMode {
	EXPEDITION,  # Dungeons - only respawn on full zone exit/re-entry
	TIME_BASED,  # Wilderness - respawn after 24 game hours
	NEVER        # Bosses/unique NPCs
}

## Base recovery percentages per rest type
## All rest types now give full recovery - rest anywhere, anytime
const REST_RECOVERY: Dictionary = {
	RestType.WILDERNESS_WAIT: 1.0,   # Full recovery
	RestType.BEDROLL: 1.0,           # Full recovery
	RestType.WILD_FIREPLACE: 1.0,    # Full recovery
	RestType.TAVERN_FIREPLACE: 1.0,  # Full recovery (hearth also allows level up)
	RestType.INN_BED: 1.0            # Full recovery
}

## Diminishing returns DISABLED - rest anywhere gives full recovery
## Kept for save compatibility but no longer used
const WILDERNESS_DIMINISHING_RETURNS: Array[float] = [1.0, 1.0, 1.0, 1.0]

## Hours required to pass for wilderness respawn
const WILDERNESS_RESPAWN_HOURS: float = 24.0

## Survival skill bonus per level (15% per level)
const SURVIVAL_BONUS_PER_LEVEL: float = 0.15

## Current wilderness wait count (resets on bedroll, fireplace, or inn)
var wilderness_wait_count: int = 0

## Zone respawn tracking
## Key: zone_id, Value: {last_cleared_time: float, mode: RespawnMode}
var zone_respawn_data: Dictionary = {}

## Dungeon entry tracking (for expedition-based respawn)
## Key: zone_id, Value: timestamp of last entry
var dungeon_entries: Dictionary = {}

func _ready() -> void:
	# Connect to scene changes for respawn tracking
	if SceneManager.has_signal("scene_load_completed"):
		SceneManager.scene_load_completed.connect(_on_scene_loaded)

## Perform a rest action
## Returns Dictionary with {success: bool, hp_restored: int, mana_restored: int, stamina_restored: int}
func perform_rest(rest_type: RestType, hours_to_wait: float = 8.0) -> Dictionary:
	var result := {
		"success": false,
		"hp_restored": 0,
		"mana_restored": 0,
		"stamina_restored": 0,
		"can_level_up": false
	}

	if not GameManager.player_data:
		return result

	var player := GameManager.player_data

	# Calculate recovery percentage based on rest type
	var recovery_pct := _get_recovery_percentage(rest_type)

	# Apply Survival skill bonus for wilderness-type rests
	if rest_type in [RestType.WILDERNESS_WAIT, RestType.BEDROLL, RestType.WILD_FIREPLACE]:
		var survival_level: int = player.get_skill(Enums.Skill.SURVIVAL)
		recovery_pct += survival_level * SURVIVAL_BONUS_PER_LEVEL
		recovery_pct = minf(recovery_pct, 1.0)  # Cap at 100%

	# Calculate actual restoration amounts
	if recovery_pct > 0:
		var hp_to_restore := int(player.max_hp * recovery_pct)
		var mana_to_restore := int(player.max_mana * recovery_pct)
		var stamina_to_restore := int(player.max_stamina * recovery_pct)

		var old_hp := player.current_hp
		var old_mana := player.current_mana

		player.current_hp = mini(player.current_hp + hp_to_restore, player.max_hp)
		player.current_mana = mini(player.current_mana + mana_to_restore, player.max_mana)
		player.current_stamina = mini(player.current_stamina + stamina_to_restore, player.max_stamina)

		result.hp_restored = player.current_hp - old_hp
		result.mana_restored = player.current_mana - old_mana
		result.stamina_restored = stamina_to_restore

	# Handle diminishing returns
	if rest_type == RestType.WILDERNESS_WAIT:
		wilderness_wait_count += 1
	elif rest_type in [RestType.BEDROLL, RestType.WILD_FIREPLACE, RestType.INN_BED]:
		# These reset the diminishing returns counter
		wilderness_wait_count = 0

	# Clear conditions on full rest or fireplace rest
	if rest_type in [RestType.INN_BED, RestType.WILD_FIREPLACE]:
		player.conditions.clear()

	# Advance game time
	GameManager.advance_time(hours_to_wait)

	# Check for respawns in wilderness zones
	_check_time_based_respawns()

	# Track rest for stats
	SaveManager.increment_rest_count()

	# Level up is available at tavern fireplace or inn
	result.can_level_up = rest_type in [RestType.TAVERN_FIREPLACE, RestType.INN_BED]
	result.success = true

	rest_completed.emit(rest_type, result.hp_restored, result.mana_restored)
	return result

## Get recovery percentage for a rest type
func _get_recovery_percentage(rest_type: RestType) -> float:
	match rest_type:
		RestType.WILDERNESS_WAIT:
			# Diminishing returns based on wait count
			if wilderness_wait_count < WILDERNESS_DIMINISHING_RETURNS.size():
				return WILDERNESS_DIMINISHING_RETURNS[wilderness_wait_count]
			return 0.0  # No more recovery after exhausting returns
		_:
			return REST_RECOVERY.get(rest_type, 0.0)

## Get current wilderness wait recovery (for UI display)
func get_wilderness_wait_recovery() -> float:
	if wilderness_wait_count < WILDERNESS_DIMINISHING_RETURNS.size():
		var base := WILDERNESS_DIMINISHING_RETURNS[wilderness_wait_count]
		# Add Survival bonus
		if GameManager.player_data:
			var survival_level: int = GameManager.player_data.get_skill(Enums.Skill.SURVIVAL)
			base += survival_level * SURVIVAL_BONUS_PER_LEVEL
			base = minf(base, 1.0)
		return base
	return 0.0

## Get number of wilderness waits remaining with recovery
func get_wilderness_waits_remaining() -> int:
	return maxi(0, WILDERNESS_DIMINISHING_RETURNS.size() - wilderness_wait_count)

## Check if wilderness waiting still provides recovery
func can_wilderness_wait_recover() -> bool:
	return wilderness_wait_count < WILDERNESS_DIMINISHING_RETURNS.size() - 1 or \
		   WILDERNESS_DIMINISHING_RETURNS[mini(wilderness_wait_count, WILDERNESS_DIMINISHING_RETURNS.size() - 1)] > 0

## Reset diminishing returns (called by bedroll, fireplace, etc.)
func reset_diminishing_returns() -> void:
	wilderness_wait_count = 0

# ============================================================================
# RESPAWN SYSTEM
# ============================================================================

## Register a zone's respawn mode
func register_zone(zone_id: String, mode: RespawnMode) -> void:
	if not zone_respawn_data.has(zone_id):
		zone_respawn_data[zone_id] = {
			"mode": mode,
			"last_cleared_time": 0.0,
			"enemies_cleared": false
		}
	else:
		zone_respawn_data[zone_id].mode = mode

## Mark zone as cleared (all enemies killed)
func mark_zone_cleared(zone_id: String) -> void:
	if zone_respawn_data.has(zone_id):
		zone_respawn_data[zone_id].last_cleared_time = GameManager.game_time + (GameManager.current_day * 24.0)
		zone_respawn_data[zone_id].enemies_cleared = true

## Check if a zone's enemies should respawn
func should_zone_respawn(zone_id: String) -> bool:
	if not zone_respawn_data.has(zone_id):
		return false

	var data: Dictionary = zone_respawn_data[zone_id]

	match data.mode:
		RespawnMode.NEVER:
			return false

		RespawnMode.EXPEDITION:
			# Only respawn if player left and re-entered the dungeon
			if dungeon_entries.has(zone_id):
				var entry_time: float = dungeon_entries[zone_id]
				var current_time: float = GameManager.game_time + (GameManager.current_day * 24.0)
				# Check if this is a new entry (player left and came back)
				return entry_time > float(data.last_cleared_time)
			return false

		RespawnMode.TIME_BASED:
			if not data.enemies_cleared:
				return false
			var current_time: float = GameManager.game_time + (GameManager.current_day * 24.0)
			var hours_since_cleared: float = current_time - float(data.last_cleared_time)
			return hours_since_cleared >= WILDERNESS_RESPAWN_HOURS

	return false

## Called when entering a dungeon zone
func on_dungeon_entered(zone_id: String) -> void:
	var current_time: float = GameManager.game_time + (GameManager.current_day * 24.0)
	dungeon_entries[zone_id] = current_time

	# Check if enemies should respawn
	if should_zone_respawn(zone_id):
		_trigger_zone_respawn(zone_id)

## Called when scene loads
func _on_scene_loaded(scene_path: String) -> void:
	var zone_id := _scene_path_to_zone_id(scene_path)

	# Determine respawn mode based on zone type
	var mode := _get_zone_respawn_mode(zone_id)
	register_zone(zone_id, mode)

	# Handle dungeon entry
	if mode == RespawnMode.EXPEDITION:
		on_dungeon_entered(zone_id)

## Check time-based respawns (called during rest)
func _check_time_based_respawns() -> void:
	for zone_id in zone_respawn_data:
		if zone_respawn_data[zone_id].mode == RespawnMode.TIME_BASED:
			if should_zone_respawn(zone_id):
				zone_respawn_data[zone_id].enemies_cleared = false
				# Mark for respawn when player next visits
				respawn_triggered.emit(zone_id)

## Trigger respawn in a zone
func _trigger_zone_respawn(zone_id: String) -> void:
	zone_respawn_data[zone_id].enemies_cleared = false
	respawn_triggered.emit(zone_id)
	print("[RestManager] Triggered respawn for zone: %s" % zone_id)

## Get respawn mode for a zone based on its ID
func _get_zone_respawn_mode(zone_id: String) -> RespawnMode:
	# Dungeons use expedition-based respawn
	if zone_id.contains("dungeon") or zone_id.contains("cave") or zone_id.contains("crypt"):
		return RespawnMode.EXPEDITION

	# Boss zones never respawn
	if zone_id.contains("boss") or zone_id.contains("lair"):
		return RespawnMode.NEVER

	# Everything else (wilderness, towns) uses time-based
	return RespawnMode.TIME_BASED

## Convert scene path to zone ID
func _scene_path_to_zone_id(scene_path: String) -> String:
	return scene_path.get_file().get_basename()

# ============================================================================
# BEDROLL ITEM SUPPORT
# ============================================================================

## Use a bedroll item (called from InventoryManager)
## Returns true if bedroll was used successfully
func use_bedroll() -> bool:
	var result := perform_rest(RestType.BEDROLL, 6.0)  # 6 hours of rest

	if result.success:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Rested with bedroll (+%d HP, +%d Mana)" % [result.hp_restored, result.mana_restored])

	return result.success

# ============================================================================
# SAVE/LOAD
# ============================================================================

func get_save_data() -> Dictionary:
	return {
		"wilderness_wait_count": wilderness_wait_count,
		"zone_respawn_data": zone_respawn_data.duplicate(true),
		"dungeon_entries": dungeon_entries.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	wilderness_wait_count = data.get("wilderness_wait_count", 0)
	zone_respawn_data = data.get("zone_respawn_data", {})
	dungeon_entries = data.get("dungeon_entries", {})
