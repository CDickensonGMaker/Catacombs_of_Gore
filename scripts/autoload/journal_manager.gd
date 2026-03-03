## journal_manager.gd - Manages player journal notes and bestiary entries
## Autoload for tracking discovered information
extends Node

## Emitted when a note is added
signal note_added(note: Dictionary)
## Emitted when a bestiary entry is created or updated
signal bestiary_updated(creature_id: String, entry: Dictionary)
## Emitted when a codex entry is unlocked
signal codex_entry_unlocked(entry_id: String, category: String)


# =============================================================================
# NOTES SYSTEM
# =============================================================================

## All journal notes (chronological, most recent first when displayed)
var notes: Array[Dictionary] = []
## Auto-incrementing note ID
var next_note_id: int = 1


## Add a note to the journal
## Returns the created note dictionary
func add_note(text: String, source_npc: String = "Player", source_location: String = "",
			  is_auto: bool = false, tags: Array[String] = []) -> Dictionary:
	var note: Dictionary = {
		"note_id": next_note_id,
		"text": text,
		"source_npc": source_npc,
		"source_location": source_location,
		"game_day": _get_current_game_day(),
		"is_auto": is_auto,
		"tags": tags,
		"timestamp": Time.get_unix_time_from_system()
	}

	notes.append(note)
	next_note_id += 1

	note_added.emit(note)
	print("[Journal] Note added: %s" % text.substr(0, 50))
	return note


## Add an auto-logged note from dialogue
func add_dialogue_note(dialogue_text: String, npc_name: String, location: String = "",
					   quest_tag: String = "") -> Dictionary:
	var tags: Array[String] = []
	if not quest_tag.is_empty():
		tags.append("quest:" + quest_tag)
	if not location.is_empty():
		tags.append("location:" + location)

	return add_note(dialogue_text, npc_name, location, true, tags)


## Add a manual note (player copied from dialogue)
func add_manual_note(dialogue_text: String, npc_name: String, location: String = "") -> Dictionary:
	return add_note(dialogue_text, npc_name, location, false, [])


## Get all notes (most recent first)
func get_notes() -> Array[Dictionary]:
	var sorted_notes: Array[Dictionary] = notes.duplicate()
	sorted_notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["timestamp"] > b["timestamp"]
	)
	return sorted_notes


## Get notes filtered by tag
func get_notes_by_tag(tag: String) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for note: Dictionary in notes:
		var note_tags: Array = note.get("tags", [])
		for t: String in note_tags:
			if t.contains(tag):
				filtered.append(note)
				break
	return filtered


## Delete a note by ID
func delete_note(note_id: int) -> bool:
	for i: int in range(notes.size()):
		if notes[i]["note_id"] == note_id:
			notes.remove_at(i)
			return true
	return false


# =============================================================================
# BESTIARY SYSTEM
# =============================================================================

## Bestiary entries: creature_id -> entry data
var bestiary: Dictionary = {}

## Kill thresholds for revealing information
const KILL_THRESHOLD_BASIC := 1       # Name and type only
const KILL_THRESHOLD_DESCRIPTION := 3 # Basic description unlocked
const KILL_THRESHOLD_WEAKNESSES := 5  # Weaknesses/resistances revealed
const KILL_THRESHOLD_FULL := 10       # Full lore entry


## Record a creature encounter/kill
## Called when player kills an enemy
func record_creature_kill(creature_id: String, creature_name: String, creature_type: String,
						  location: String, lore: String = "",
						  weaknesses: Array[String] = [], resistances: Array[String] = []) -> void:
	if creature_id not in bestiary:
		# First encounter - create entry
		bestiary[creature_id] = {
			"creature_id": creature_id,
			"creature_name": creature_name,
			"creature_type": creature_type,
			"first_encounter_location": location,
			"kill_count": 0,
			"lore_description": lore,
			"weaknesses": weaknesses,
			"resistances": resistances,
			"discovered_time": Time.get_unix_time_from_system()
		}
		print("[Journal] Bestiary entry created: %s" % creature_name)

	# Increment kill count
	bestiary[creature_id]["kill_count"] += 1

	# Track in stats
	if StatsTracker:
		StatsTracker.track_enemy_kill(creature_type, creature_name, 1)

	bestiary_updated.emit(creature_id, bestiary[creature_id])


## Get bestiary entry for a creature
func get_bestiary_entry(creature_id: String) -> Dictionary:
	return bestiary.get(creature_id, {})


## Get all bestiary entries
func get_all_bestiary_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id: String in bestiary.keys():
		entries.append(bestiary[id])
	# Sort by creature name
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["creature_name"] < b["creature_name"]
	)
	return entries


## Get bestiary entries by type
func get_bestiary_by_type(creature_type: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id: String in bestiary.keys():
		if bestiary[id]["creature_type"].to_lower() == creature_type.to_lower():
			entries.append(bestiary[id])
	return entries


## Get the reveal level for a bestiary entry (based on kill count)
func get_reveal_level(creature_id: String) -> int:
	if creature_id not in bestiary:
		return 0

	var kills: int = bestiary[creature_id]["kill_count"]
	if kills >= KILL_THRESHOLD_FULL:
		return 4  # Full lore
	elif kills >= KILL_THRESHOLD_WEAKNESSES:
		return 3  # Weaknesses revealed
	elif kills >= KILL_THRESHOLD_DESCRIPTION:
		return 2  # Description unlocked
	elif kills >= KILL_THRESHOLD_BASIC:
		return 1  # Name and type
	return 0


## Check if weaknesses are revealed for a creature
func are_weaknesses_revealed(creature_id: String) -> bool:
	return get_reveal_level(creature_id) >= 3


## Check if full lore is revealed
func is_full_lore_revealed(creature_id: String) -> bool:
	return get_reveal_level(creature_id) >= 4


## Unlock bestiary entry from reading a book (gives full knowledge without kills)
## Returns true if new knowledge was gained, false if already known
func unlock_bestiary_from_book(creature_id: String) -> bool:
	# If already have full lore from kills, no new knowledge
	if creature_id in bestiary and bestiary[creature_id].get("from_book", false):
		return false

	# Get creature data from enemy database
	var creature_data: Dictionary = _get_creature_data_from_database(creature_id)

	if creature_id not in bestiary:
		# Create new entry with book knowledge
		bestiary[creature_id] = {
			"creature_id": creature_id,
			"creature_name": creature_data.get("name", creature_id.capitalize().replace("_", " ")),
			"creature_type": creature_data.get("type", "Unknown"),
			"first_encounter_location": "Learned from book",
			"kill_count": 0,
			"lore_description": creature_data.get("lore", "A creature described in scholarly texts."),
			"weaknesses": creature_data.get("weaknesses", []),
			"resistances": creature_data.get("resistances", []),
			"discovered_time": Time.get_unix_time_from_system(),
			"from_book": true  # Mark as learned from book
		}
		print("[Journal] Bestiary entry created from book: %s" % creature_id)
	else:
		# Already have entry from kills - mark as also learned from book for full knowledge
		bestiary[creature_id]["from_book"] = true

	bestiary_updated.emit(creature_id, bestiary[creature_id])
	return true


## Check if player has book knowledge of a creature (for XP bonus)
func has_book_knowledge(creature_id: String) -> bool:
	if creature_id not in bestiary:
		return false
	return bestiary[creature_id].get("from_book", false)


## Get XP multiplier for killing a creature (bonus for book knowledge)
## Returns 1.0 for no bonus, 1.25 for book knowledge
func get_creature_xp_multiplier(creature_id: String) -> float:
	if has_book_knowledge(creature_id):
		return 1.25  # 25% XP bonus for studying the creature beforehand
	return 1.0


## Helper to get creature data from EnemyData database
func _get_creature_data_from_database(creature_id: String) -> Dictionary:
	# Try to load the enemy data file
	var enemy_data_path := "res://data/enemies/%s.tres" % creature_id
	if ResourceLoader.exists(enemy_data_path):
		var enemy_data: Resource = load(enemy_data_path)
		if enemy_data:
			return {
				"name": enemy_data.get("display_name") if "display_name" in enemy_data else creature_id.capitalize().replace("_", " "),
				"type": enemy_data.get("enemy_type") if "enemy_type" in enemy_data else "Unknown",
				"lore": enemy_data.get("lore_description") if "lore_description" in enemy_data else "",
				"weaknesses": enemy_data.get("weaknesses") if "weaknesses" in enemy_data else [],
				"resistances": enemy_data.get("resistances") if "resistances" in enemy_data else []
			}

	# Return default data if not found
	return {
		"name": creature_id.capitalize().replace("_", " "),
		"type": "Unknown",
		"lore": "",
		"weaknesses": [],
		"resistances": []
	}


# =============================================================================
# CODEX UNLOCKS (Recipes/Knowledge)
# =============================================================================

## Track unlocked codex entries (works with CodexManager)
var unlocked_codex_entries: Array[String] = []


## Unlock a codex entry (called from dialogue actions)
func unlock_codex_entry(entry_id: String, category: String = "") -> bool:
	if entry_id in unlocked_codex_entries:
		return false  # Already unlocked

	unlocked_codex_entries.append(entry_id)

	# Also notify CodexManager if it exists
	if CodexManager and CodexManager.has_method("discover_recipe"):
		CodexManager.discover_recipe(entry_id)

	codex_entry_unlocked.emit(entry_id, category)
	print("[Journal] Codex entry unlocked: %s" % entry_id)

	if StatsTracker:
		StatsTracker.track_stat("recipes_discovered")

	return true


## Check if a codex entry is unlocked
func is_codex_unlocked(entry_id: String) -> bool:
	return entry_id in unlocked_codex_entries


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

## Get current in-game day (from GameManager)
func _get_current_game_day() -> int:
	if GameManager:
		return GameManager.current_day
	return 1


## Get current location name
func get_current_location_name() -> String:
	if PlayerGPS and PlayerGPS.current_location_id:
		var cell_info = WorldGrid.get_cell(PlayerGPS.current_cell)
		if cell_info and cell_info.location_name:
			return cell_info.location_name
	return "Unknown Location"


# =============================================================================
# SAVE/LOAD
# =============================================================================

func to_dict() -> Dictionary:
	return {
		"notes": notes.duplicate(true),
		"next_note_id": next_note_id,
		"bestiary": bestiary.duplicate(true),
		"unlocked_codex_entries": unlocked_codex_entries.duplicate()
	}


func from_dict(data: Dictionary) -> void:
	if "notes" in data:
		notes.clear()
		for note_data: Dictionary in data["notes"]:
			notes.append(note_data)

	if "next_note_id" in data:
		next_note_id = data["next_note_id"]

	if "bestiary" in data:
		bestiary = data["bestiary"].duplicate(true)

	if "unlocked_codex_entries" in data:
		unlocked_codex_entries.clear()
		for entry_id: String in data["unlocked_codex_entries"]:
			unlocked_codex_entries.append(entry_id)


func reset() -> void:
	notes.clear()
	next_note_id = 1
	bestiary.clear()
	unlocked_codex_entries.clear()
