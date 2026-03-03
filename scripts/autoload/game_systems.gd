## game_systems.gd - Central coordinator for cross-system events
## Autoload singleton that wires together all game systems
## Provides unified access, initialization ordering, and cross-system event coordination
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when all systems have been initialized and connected
signal systems_ready

## Generic system event bus for cross-system communication
signal system_event(event_type: String, data: Dictionary)

## Specific cross-system events
signal player_killed_enemy(enemy_data: Dictionary)
signal player_reputation_changed(system_name: String, old_value: int, new_value: int)
signal player_committed_crime(crime_type: int, region: String)
signal bounty_status_changed(bounty_id: String, status: String)
signal dialogue_flag_changed(flag_name: String, value: bool)
signal item_acquired(item_id: String, quantity: int)
signal item_lost(item_id: String, quantity: int)

# =============================================================================
# SYSTEM STATE
# =============================================================================

## System initialization state
var _initialized: bool = false

## Returns true if all systems have been initialized and connected
var is_ready: bool:
	get:
		return _initialized

# =============================================================================
# SUBSYSTEM ACCESSORS (typed for autocomplete)
# =============================================================================
## These provide cleaner, typed access to subsystems via GameSystems.combat, etc.

var game: Node:
	get: return GameManager if GameManager else null

var combat: Node:
	get: return CombatManager if CombatManager else null

var inventory: Node:
	get: return InventoryManager if InventoryManager else null

var quest: Node:
	get: return QuestManager if QuestManager else null

var dialogue: Node:
	get: return DialogueManager if DialogueManager else null

var conversation: Node:
	get: return ConversationSystem if ConversationSystem else null

var crime: Node:
	get: return CrimeManager if CrimeManager else null

var bounty: Node:
	get: return BountyManager if BountyManager else null

var morality: Node:
	get: return MoralityManager if MoralityManager else null

var faction: Node:
	get: return FactionManager if FactionManager else null

var save: Node:
	get: return SaveManager if SaveManager else null

var audio: Node:
	get: return AudioManager if AudioManager else null

var scene: Node:
	get: return SceneManager if SceneManager else null

var gps: Node:
	get: return PlayerGPS if PlayerGPS else null

var cell_streamer: Node:
	get: return CellStreamer if CellStreamer else null

var fast_travel: Node:
	get: return FastTravelManager if FastTravelManager else null

var encounter: Node:
	get: return EncounterManager if EncounterManager else null

var crafting: Node:
	get: return CraftingManager if CraftingManager else null

var rest: Node:
	get: return RestManager if RestManager else null

var dice: Node:
	get: return DiceManager if DiceManager else null

var codex: Node:
	get: return CodexManager if CodexManager else null

var takeover: Node:
	get: return TakeoverManager if TakeoverManager else null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Defer initialization to ensure all autoloads are ready
	call_deferred("_initialize_systems")


## Initialize and connect all game systems
func _initialize_systems() -> void:
	if _initialized:
		return

	print("[GameSystems] Initializing cross-system connections...")

	# Connect CrimeManager to MoralityManager
	_connect_crime_to_morality()

	# Connect QuestManager to Morality and Faction
	_connect_quest_to_reputation()

	# Connect FactionManager signals for cascading effects
	_connect_faction_signals()

	# Connect MoralityManager signals
	_connect_morality_signals()

	# Connect CombatManager for kill tracking
	_connect_combat_signals()

	# Connect BountyManager for bounty events
	_connect_bounty_signals()

	# Connect InventoryManager for item events
	_connect_inventory_signals()

	# Connect DialogueManager for flag tracking
	_connect_dialogue_signals()

	_initialized = true
	print("[GameSystems] All systems connected.")
	systems_ready.emit()


# =============================================================================
# SYSTEM CONNECTIONS
# =============================================================================

## Connect crime events to morality changes
func _connect_crime_to_morality() -> void:
	if not CrimeManager:
		push_warning("[GameSystems] CrimeManager not found")
		return

	if CrimeManager.has_signal("crime_reported"):
		CrimeManager.crime_reported.connect(_on_crime_reported)
		print("[GameSystems] Connected CrimeManager.crime_reported -> MoralityManager")


## Handle crime reported event
func _on_crime_reported(crime_type: CrimeManager.CrimeType, region_id: String) -> void:
	# Emit cross-system signal
	player_committed_crime.emit(crime_type, region_id)

	if not MoralityManager:
		return

	# Map crime types to morality actions
	match crime_type:
		CrimeManager.CrimeType.MURDER:
			MoralityManager.record_action("murder_innocent")
		CrimeManager.CrimeType.ASSAULT:
			MoralityManager.record_action("assault_innocent")
		CrimeManager.CrimeType.THEFT:
			MoralityManager.record_action("theft")
		CrimeManager.CrimeType.PICKPOCKET:
			MoralityManager.modify_morality(-5, "pickpocketing")
		CrimeManager.CrimeType.TRESPASSING:
			MoralityManager.modify_morality(-2, "trespassing")


## Connect quest completion to reputation changes
func _connect_quest_to_reputation() -> void:
	if not QuestManager:
		push_warning("[GameSystems] QuestManager not found")
		return

	if QuestManager.has_signal("quest_completed"):
		QuestManager.quest_completed.connect(_on_quest_completed)
		print("[GameSystems] Connected QuestManager.quest_completed -> Faction/Morality")


## Handle quest completion - apply faction and morality rewards
func _on_quest_completed(quest_id: String) -> void:
	var quest: QuestManager.Quest = QuestManager.get_quest(quest_id)
	if not quest:
		return

	# Check for faction reputation rewards in quest rewards
	var rewards: Dictionary = quest.rewards
	if rewards.has("faction_rep"):
		var faction_rep: Dictionary = rewards["faction_rep"]
		for faction_id: String in faction_rep:
			var amount: int = faction_rep[faction_id]
			if FactionManager:
				FactionManager.modify_reputation(faction_id, amount, "completed quest: " + quest.title)

	# Check for morality changes based on quest type
	if rewards.has("morality"):
		var morality_change: int = rewards["morality"]
		if MoralityManager:
			MoralityManager.modify_morality(morality_change, "completed quest: " + quest.title)

	# Emit system event
	system_event.emit("quest_completed", {
		"quest_id": quest_id,
		"title": quest.title,
		"rewards": rewards
	})


## Connect faction signals for UI updates and cascading effects
func _connect_faction_signals() -> void:
	if not FactionManager:
		push_warning("[GameSystems] FactionManager not found")
		return

	if FactionManager.has_signal("reputation_changed"):
		FactionManager.reputation_changed.connect(_on_faction_rep_changed)

	if FactionManager.has_signal("faction_status_changed"):
		FactionManager.faction_status_changed.connect(_on_faction_status_changed)


## Handle faction reputation change
func _on_faction_rep_changed(faction_id: String, old_rep: int, new_rep: int) -> void:
	# Emit cross-system signal
	player_reputation_changed.emit("faction:" + faction_id, old_rep, new_rep)

	# Emit system event for UI updates
	system_event.emit("faction_rep_changed", {
		"faction_id": faction_id,
		"old_rep": old_rep,
		"new_rep": new_rep
	})


## Handle faction status change (threshold crossed)
func _on_faction_status_changed(faction_id: String, _old_status: int, new_status: int) -> void:
	# Show notification for significant status changes
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		var faction_data: FactionData = FactionManager.get_faction(faction_id)
		if faction_data:
			var status_name: String = FactionData.get_status_name(new_status as FactionData.ReputationStatus)
			var message: String = "Reputation with %s: %s" % [faction_data.display_name, status_name]
			hud.show_notification(message)


## Connect morality signals
func _connect_morality_signals() -> void:
	if not MoralityManager:
		push_warning("[GameSystems] MoralityManager not found")
		return

	if MoralityManager.has_signal("tier_changed"):
		MoralityManager.tier_changed.connect(_on_morality_tier_changed)

	if MoralityManager.has_signal("morality_changed"):
		MoralityManager.morality_changed.connect(_on_morality_changed)


## Handle morality tier change
func _on_morality_tier_changed(old_tier: MoralityManager.MoralityTier, new_tier: MoralityManager.MoralityTier) -> void:
	# Show notification for morality tier changes
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		var tier_name: String = MoralityManager.get_tier_name(new_tier)
		var direction: String = "risen to" if new_tier > old_tier else "fallen to"
		var message: String = "Your reputation has %s: %s" % [direction, tier_name]
		hud.show_notification(message)


## Handle morality value change
func _on_morality_changed(old_value: int, new_value: int) -> void:
	player_reputation_changed.emit("morality", old_value, new_value)


## Connect combat signals for kill tracking
func _connect_combat_signals() -> void:
	if not CombatManager:
		push_warning("[GameSystems] CombatManager not found")
		return

	if CombatManager.has_signal("entity_killed"):
		CombatManager.entity_killed.connect(_on_entity_killed)
		print("[GameSystems] Connected CombatManager.entity_killed -> Kill tracking")


## Handle entity killed event
func _on_entity_killed(entity: Node, killer: Node) -> void:
	# Only process if player killed an enemy
	if not killer or not killer.is_in_group("player"):
		return

	if not entity:
		return

	# Build enemy data dictionary
	var enemy_data: Dictionary = {}

	if entity.has_method("get_enemy_data"):
		var data = entity.get_enemy_data()
		if data:
			enemy_data["enemy_id"] = data.id if "id" in data else ""
			enemy_data["display_name"] = data.display_name if "display_name" in data else "Unknown"
			enemy_data["faction"] = data.faction if "faction" in data else ""
			enemy_data["creature_type"] = data.creature_type if "creature_type" in data else ""
			enemy_data["xp_reward"] = data.xp_reward if "xp_reward" in data else 0

	# Emit cross-system signal
	player_killed_enemy.emit(enemy_data)

	# Handle faction reputation impact from killing
	_process_kill_faction_impact(enemy_data)

	# Emit system event
	system_event.emit("entity_killed", {
		"enemy_data": enemy_data,
		"killer": "player"
	})


## Process faction reputation changes from killing
func _process_kill_faction_impact(enemy_data: Dictionary) -> void:
	if not FactionManager:
		return

	var faction_id: String = enemy_data.get("faction", "")
	if faction_id.is_empty():
		return

	# Killing a faction member decreases reputation with that faction
	# Skip for universally hostile factions (bandits, undead, etc.)
	var hostile_factions: Array[String] = ["bandits", "undead", "demons", "monsters", "wildlife"]
	if faction_id in hostile_factions:
		return

	# Decrease reputation with the victim's faction
	FactionManager.modify_reputation(faction_id, -5, "killed faction member", false)


## Connect bounty signals
func _connect_bounty_signals() -> void:
	if not BountyManager:
		push_warning("[GameSystems] BountyManager not found")
		return

	if BountyManager.has_signal("bounty_accepted"):
		BountyManager.bounty_accepted.connect(_on_bounty_accepted)

	if BountyManager.has_signal("bounty_completed"):
		BountyManager.bounty_completed.connect(_on_bounty_completed)

	if BountyManager.has_signal("bounty_turned_in"):
		BountyManager.bounty_turned_in.connect(_on_bounty_turned_in)

	print("[GameSystems] Connected BountyManager signals")


## Handle bounty accepted
func _on_bounty_accepted(bounty) -> void:
	bounty_status_changed.emit(bounty.id, "accepted")
	system_event.emit("bounty_accepted", {
		"bounty_id": bounty.id,
		"target": bounty.target_creature,
		"count": bounty.target_count,
		"reward": bounty.reward_gold
	})


## Handle bounty completed (kills done, ready for turn-in)
func _on_bounty_completed(bounty) -> void:
	bounty_status_changed.emit(bounty.id, "completed")
	system_event.emit("bounty_completed", {
		"bounty_id": bounty.id
	})


## Handle bounty turned in (rewards given)
func _on_bounty_turned_in(bounty) -> void:
	bounty_status_changed.emit(bounty.id, "turned_in")

	# Give small faction boost to guards/law enforcement for completing bounties
	if FactionManager:
		FactionManager.modify_reputation("town_guard", 2, "completed bounty", false)

	system_event.emit("bounty_turned_in", {
		"bounty_id": bounty.id,
		"gold": bounty.reward_gold,
		"xp": bounty.reward_xp
	})


## Connect inventory signals
func _connect_inventory_signals() -> void:
	if not InventoryManager:
		push_warning("[GameSystems] InventoryManager not found")
		return

	if InventoryManager.has_signal("item_added"):
		InventoryManager.item_added.connect(_on_item_added)

	if InventoryManager.has_signal("item_removed"):
		InventoryManager.item_removed.connect(_on_item_removed)

	print("[GameSystems] Connected InventoryManager signals")


## Handle item added to inventory
func _on_item_added(item_id: String, quantity: int) -> void:
	item_acquired.emit(item_id, quantity)
	system_event.emit("item_acquired", {
		"item_id": item_id,
		"quantity": quantity
	})


## Handle item removed from inventory
func _on_item_removed(item_id: String, quantity: int) -> void:
	item_lost.emit(item_id, quantity)
	system_event.emit("item_lost", {
		"item_id": item_id,
		"quantity": quantity
	})


## Connect dialogue signals
func _connect_dialogue_signals() -> void:
	if not DialogueManager:
		push_warning("[GameSystems] DialogueManager not found")
		return

	if DialogueManager.has_signal("flag_changed"):
		DialogueManager.flag_changed.connect(_on_dialogue_flag_changed)
		print("[GameSystems] Connected DialogueManager.flag_changed")


## Handle dialogue flag change
func _on_dialogue_flag_changed(flag_name: String, value: bool) -> void:
	dialogue_flag_changed.emit(flag_name, value)
	system_event.emit("dialogue_flag_changed", {
		"flag": flag_name,
		"value": value
	})


# =============================================================================
# HELPER METHODS FOR CROSS-SYSTEM OPERATIONS
# =============================================================================

## Modify NPC disposition and optionally affect faction reputation
## npc: The NPC node (must have faction_id property)
## amount: Disposition change amount
## affect_faction: If true, also affects faction reputation (scaled down)
func modify_npc_disposition_with_faction(npc: Node, amount: int, affect_faction: bool = false) -> void:
	# Modify personal disposition
	DispositionCalculator.modify_npc_disposition(npc, amount)

	# Optionally affect faction reputation
	if affect_faction and FactionManager:
		var faction_id: String = ""
		if "faction_id" in npc:
			faction_id = npc.faction_id
		elif "faction" in npc:
			faction_id = npc.faction

		if not faction_id.is_empty():
			# Faction effect is much smaller than personal disposition
			var faction_amount: int = int(amount * 0.1)
			if faction_amount != 0:
				FactionManager.modify_reputation(faction_id, faction_amount, "NPC interaction", false)


## Calculate disposition for an NPC (convenience wrapper)
func get_npc_disposition(npc: Node) -> int:
	return DispositionCalculator.calculate_disposition(npc)


## Check if player can access disposition-gated content
func can_access_content(npc: Node, content_type: String) -> bool:
	var disposition: int = DispositionCalculator.calculate_disposition(npc)
	return DispositionCalculator.allows_interaction(disposition, content_type)


## Process persuasion attempt on NPC
## Returns: {success: bool, disposition_change: int, message: String}
func attempt_persuasion(npc: Node, action_type: String) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"disposition_change": 0,
		"message": ""
	}

	var disposition: int = DispositionCalculator.calculate_disposition(npc)
	var player_data: CharacterData = GameManager.player_data
	if not player_data:
		result["message"] = "No player data"
		return result

	match action_type:
		"admire":
			# Admire is relatively easy and gives small boost
			var chance: float = DispositionCalculator.calculate_persuasion_chance(npc, player_data, disposition) + 0.2
			if randf() < chance:
				result["success"] = true
				result["disposition_change"] = randi_range(3, 8)
				result["message"] = "They seem flattered by your attention."
			else:
				result["disposition_change"] = -1
				result["message"] = "They seem unimpressed."

		"joke":
			# Joke is medium difficulty, medium reward
			var chance: float = DispositionCalculator.calculate_persuasion_chance(npc, player_data, disposition)
			if randf() < chance:
				result["success"] = true
				result["disposition_change"] = randi_range(5, 12)
				result["message"] = "They laugh at your wit!"
			else:
				result["disposition_change"] = randi_range(-3, -1)
				result["message"] = "Your joke falls flat."

		"intimidate":
			# Intimidate uses different stat and can backfire badly
			var chance: float = DispositionCalculator.calculate_intimidation_chance(npc, player_data)
			if randf() < chance:
				result["success"] = true
				result["disposition_change"] = randi_range(8, 15)
				result["message"] = "They back down, cowed by your presence."
				# Intimidation affects morality
				if MoralityManager:
					MoralityManager.record_action("intimidation")
			else:
				result["disposition_change"] = randi_range(-10, -5)
				result["message"] = "They stand their ground, angered by your threats."

		"bribe":
			# Bribe requires gold and disposition check
			var bribe_cost: int = 50 - int(disposition / 2)  # 50 gold at 0 disp, 25 at 50, etc.
			bribe_cost = maxi(10, bribe_cost)

			if InventoryManager.get_gold() < bribe_cost:
				result["message"] = "You don't have enough gold (%d required)." % bribe_cost
				return result

			var chance: float = 0.5 + disposition / 200.0  # 50% at 0, 75% at 50, etc.
			if randf() < chance:
				InventoryManager.remove_gold(bribe_cost)
				result["success"] = true
				result["disposition_change"] = randi_range(10, 20)
				result["message"] = "They accept your gold with a knowing nod."
			else:
				result["disposition_change"] = randi_range(-5, -2)
				result["message"] = "They refuse your gold, offended."

	# Apply disposition change
	if result["disposition_change"] != 0:
		DispositionCalculator.modify_npc_disposition(npc, result["disposition_change"])

	return result


## Give an item to player and set world flags (for quest items)
func give_quest_item(item_id: String, quantity: int = 1, set_flag: String = "") -> bool:
	if InventoryManager.add_item(item_id, quantity):
		if not set_flag.is_empty():
			SaveManager.set_world_flag(set_flag, true)
		return true
	return false


## Complete a quest with standard handling
func complete_quest_with_rewards(quest_id: String) -> void:
	QuestManager.complete_quest(quest_id)


## Check if a system is available
func has_system(system_name: String) -> bool:
	match system_name:
		"game": return GameManager != null
		"combat": return CombatManager != null
		"inventory": return InventoryManager != null
		"quest": return QuestManager != null
		"dialogue": return DialogueManager != null
		"conversation": return ConversationSystem != null
		"crime": return CrimeManager != null
		"bounty": return BountyManager != null
		"morality": return MoralityManager != null
		"faction": return FactionManager != null
		"save": return SaveManager != null
		"audio": return AudioManager != null
		"scene": return SceneManager != null
		"gps": return PlayerGPS != null
		"cell_streamer": return CellStreamer != null
		"fast_travel": return FastTravelManager != null
		"encounter": return EncounterManager != null
		"crafting": return CraftingManager != null
		"rest": return RestManager != null
		"dice": return DiceManager != null
		"codex": return CodexManager != null
		"takeover": return TakeoverManager != null
		_: return false


## Get list of all initialized systems
func get_system_status() -> Dictionary:
	return {
		"game": GameManager != null,
		"combat": CombatManager != null,
		"inventory": InventoryManager != null,
		"quest": QuestManager != null,
		"dialogue": DialogueManager != null,
		"conversation": ConversationSystem != null,
		"crime": CrimeManager != null,
		"bounty": BountyManager != null,
		"morality": MoralityManager != null,
		"faction": FactionManager != null,
		"save": SaveManager != null,
		"audio": AudioManager != null,
		"scene": SceneManager != null,
		"gps": PlayerGPS != null,
		"cell_streamer": CellStreamer != null,
		"fast_travel": FastTravelManager != null,
		"encounter": EncounterManager != null,
		"crafting": CraftingManager != null,
		"rest": RestManager != null,
		"dice": DiceManager != null,
		"codex": CodexManager != null,
		"takeover": TakeoverManager != null,
		"_initialized": _initialized
	}


# =============================================================================
# SAVE/LOAD INTEGRATION
# =============================================================================

## Get save data for all connected systems (called by SaveManager)
func get_save_data() -> Dictionary:
	var data: Dictionary = {}

	# Morality data
	if MoralityManager:
		data["morality"] = MoralityManager.to_dict()

	# Faction data
	if FactionManager:
		data["factions"] = FactionManager.to_dict()

	return data


## Load save data for all connected systems (called by SaveManager)
func load_save_data(data: Dictionary) -> void:
	# Restore morality
	if MoralityManager and data.has("morality"):
		MoralityManager.from_dict(data["morality"])

	# Restore factions
	if FactionManager and data.has("factions"):
		FactionManager.from_dict(data["factions"])


## Reset all systems for new game
func reset_for_new_game() -> void:
	if MoralityManager:
		MoralityManager.reset()

	if FactionManager:
		FactionManager.reset()
