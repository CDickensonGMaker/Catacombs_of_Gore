## stats_tracker.gd - Tracks all gameplay statistics
## Autoload that persists and saves player accomplishments
extends Node

## Emitted when any stat changes
signal stat_changed(stat_name: String, new_value: Variant)

## All tracked statistics
var stats: Dictionary = {
	# Combat
	"enemies_killed": 0,
	"enemies_killed_by_type": {},    # {"undead": 47, "beast": 23}
	"toughest_enemy": "",
	"toughest_enemy_level": 0,
	"deaths": 0,
	"damage_dealt": 0,
	"damage_taken": 0,
	"critical_hits": 0,
	"blocks": 0,
	"dodges": 0,

	# Exploration
	"locations_discovered": 0,
	"cells_explored": 0,
	"dungeons_entered": 0,
	"dungeons_cleared": 0,
	"distance_traveled": 0.0,
	"hidden_areas_found": 0,
	"chests_opened": 0,
	"doors_unlocked": 0,

	# Social
	"quests_completed_main": 0,
	"quests_completed_secondary": 0,
	"quests_failed": 0,
	"npcs_talked_to": 0,
	"unique_npcs_met": [],  # Array of NPC IDs
	"persuasions_success": 0,
	"persuasions_failed": 0,
	"intimidations_success": 0,
	"intimidations_failed": 0,
	"bribes_success": 0,
	"bribes_failed": 0,
	"factions_joined": 0,
	"factions_hostile": 0,

	# Crime
	"items_stolen": 0,
	"times_caught_stealing": 0,
	"pickpockets_success": 0,
	"pickpockets_failed": 0,
	"murders": 0,
	"assaults": 0,
	"bounty_paid": 0,
	"times_arrested": 0,
	"times_escaped": 0,

	# Economy
	"gold_earned": 0,
	"gold_spent": 0,
	"most_expensive_purchase": "",
	"most_expensive_purchase_cost": 0,
	"items_crafted": 0,
	"potions_consumed": 0,
	"food_consumed": 0,
	"recipes_discovered": 0,
	"items_sold": 0,
	"items_bought": 0,

	# Time
	"play_time_seconds": 0,
	"days_passed": 0,
	"times_rested": 0,
	"times_waited": 0,
}


func _ready() -> void:
	# Connect to relevant signals from other systems
	_connect_signals()


func _connect_signals() -> void:
	# Connect to InventoryManager signals
	if InventoryManager:
		if InventoryManager.has_signal("gold_changed"):
			InventoryManager.gold_changed.connect(_on_gold_changed)

	# Connect to QuestManager signals
	if QuestManager:
		if QuestManager.has_signal("quest_completed"):
			QuestManager.quest_completed.connect(_on_quest_completed)
		if QuestManager.has_signal("quest_failed"):
			QuestManager.quest_failed.connect(_on_quest_failed)

	# Connect to PlayerGPS for exploration
	if PlayerGPS:
		if PlayerGPS.has_signal("cell_revealed"):
			PlayerGPS.cell_revealed.connect(_on_cell_revealed)
		if PlayerGPS.has_signal("location_discovered"):
			PlayerGPS.location_discovered.connect(_on_location_discovered)


## Increment a numeric stat by amount (default 1)
func track_stat(stat_name: String, amount: int = 1) -> void:
	if stat_name in stats:
		if stats[stat_name] is int:
			stats[stat_name] += amount
			stat_changed.emit(stat_name, stats[stat_name])
		elif stats[stat_name] is float:
			stats[stat_name] += float(amount)
			stat_changed.emit(stat_name, stats[stat_name])


## Track a float stat (like distance)
func track_stat_float(stat_name: String, amount: float) -> void:
	if stat_name in stats and stats[stat_name] is float:
		stats[stat_name] += amount
		stat_changed.emit(stat_name, stats[stat_name])


## Set a string stat (like toughest enemy)
func set_stat_string(stat_name: String, value: String) -> void:
	if stat_name in stats:
		stats[stat_name] = value
		stat_changed.emit(stat_name, value)


## Track enemy kill by type
func track_enemy_kill(enemy_type: String, enemy_name: String, enemy_level: int) -> void:
	track_stat("enemies_killed")

	# Track by type
	var by_type: Dictionary = stats["enemies_killed_by_type"]
	var type_lower: String = enemy_type.to_lower()
	if type_lower in by_type:
		by_type[type_lower] += 1
	else:
		by_type[type_lower] = 1

	# Check if toughest enemy
	if enemy_level > stats["toughest_enemy_level"]:
		stats["toughest_enemy"] = enemy_name
		stats["toughest_enemy_level"] = enemy_level
		stat_changed.emit("toughest_enemy", enemy_name)


## Track unique NPC met
func track_npc_met(npc_id: String) -> void:
	var met_list: Array = stats["unique_npcs_met"]
	if npc_id not in met_list:
		met_list.append(npc_id)
		track_stat("npcs_talked_to")


## Track expensive purchase
func track_purchase(item_name: String, cost: int) -> void:
	track_stat("gold_spent", cost)
	track_stat("items_bought")

	if cost > stats["most_expensive_purchase_cost"]:
		stats["most_expensive_purchase"] = item_name
		stats["most_expensive_purchase_cost"] = cost
		stat_changed.emit("most_expensive_purchase", item_name)


## Get a stat value
func get_stat(stat_name: String) -> Variant:
	return stats.get(stat_name, 0)


## Get enemies killed by type
func get_kills_by_type(enemy_type: String) -> int:
	var by_type: Dictionary = stats["enemies_killed_by_type"]
	return by_type.get(enemy_type.to_lower(), 0)


## Get total unique NPCs met
func get_unique_npcs_count() -> int:
	return stats["unique_npcs_met"].size()


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_gold_changed(old_amount: int, new_amount: int) -> void:
	var diff: int = new_amount - old_amount
	if diff > 0:
		track_stat("gold_earned", diff)


func _on_quest_completed(quest_id: String) -> void:
	# Check if main quest or secondary
	if QuestManager:
		var quest = QuestManager.get_quest(quest_id)
		if quest and quest.is_main_quest:
			track_stat("quests_completed_main")
		else:
			track_stat("quests_completed_secondary")


func _on_quest_failed(_quest_id: String) -> void:
	track_stat("quests_failed")


func _on_cell_revealed(_coords: Vector2i) -> void:
	track_stat("cells_explored")


func _on_location_discovered(_location_id: String, _location_name: String) -> void:
	track_stat("locations_discovered")


# =============================================================================
# PLAY TIME TRACKING
# =============================================================================

func _process(delta: float) -> void:
	# Track play time (only when not paused)
	if not get_tree().paused:
		stats["play_time_seconds"] += delta


## Get formatted play time string
func get_play_time_formatted() -> String:
	var total_seconds: int = int(stats["play_time_seconds"])
	var hours: int = int(total_seconds / 3600)
	var minutes: int = int((total_seconds % 3600) / 60)
	var seconds: int = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


# =============================================================================
# SAVE/LOAD
# =============================================================================

func to_dict() -> Dictionary:
	return stats.duplicate(true)


func from_dict(data: Dictionary) -> void:
	for key: String in data.keys():
		if key in stats:
			stats[key] = data[key]


func reset() -> void:
	stats = {
		"enemies_killed": 0,
		"enemies_killed_by_type": {},
		"toughest_enemy": "",
		"toughest_enemy_level": 0,
		"deaths": 0,
		"damage_dealt": 0,
		"damage_taken": 0,
		"critical_hits": 0,
		"blocks": 0,
		"dodges": 0,
		"locations_discovered": 0,
		"cells_explored": 0,
		"dungeons_entered": 0,
		"dungeons_cleared": 0,
		"distance_traveled": 0.0,
		"hidden_areas_found": 0,
		"chests_opened": 0,
		"doors_unlocked": 0,
		"quests_completed_main": 0,
		"quests_completed_secondary": 0,
		"quests_failed": 0,
		"npcs_talked_to": 0,
		"unique_npcs_met": [],
		"persuasions_success": 0,
		"persuasions_failed": 0,
		"intimidations_success": 0,
		"intimidations_failed": 0,
		"bribes_success": 0,
		"bribes_failed": 0,
		"factions_joined": 0,
		"factions_hostile": 0,
		"items_stolen": 0,
		"times_caught_stealing": 0,
		"pickpockets_success": 0,
		"pickpockets_failed": 0,
		"murders": 0,
		"assaults": 0,
		"bounty_paid": 0,
		"times_arrested": 0,
		"times_escaped": 0,
		"gold_earned": 0,
		"gold_spent": 0,
		"most_expensive_purchase": "",
		"most_expensive_purchase_cost": 0,
		"items_crafted": 0,
		"potions_consumed": 0,
		"food_consumed": 0,
		"recipes_discovered": 0,
		"items_sold": 0,
		"items_bought": 0,
		"play_time_seconds": 0,
		"days_passed": 0,
		"times_rested": 0,
		"times_waited": 0,
	}
