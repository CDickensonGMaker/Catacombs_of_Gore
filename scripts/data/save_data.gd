## save_data.gd - Typed structure for save data
class_name SaveData
extends Resource

## Current save format version - increment when structure changes
const SAVE_VERSION := 1

## Metadata
@export var version: int = SAVE_VERSION
@export var timestamp: float = 0.0
@export var datetime_string: String = ""
@export var game_version: String = "1.0.0"

## Player data section
var player = null  # PlayerSaveData

## Inventory section
var inventory = null  # InventorySaveData

## World state section
var world = null  # WorldSaveData

## Quest state section
var quests = null  # QuestSaveData

## Time tracking section
var time_data = null  # TimeSaveData (renamed to avoid conflict with Time singleton)

## Crime/bounty section
var crime_data = null  # CrimeSaveData

## Dialogue flags section
var dialogue_data = null  # DialogueSaveData

## Conversation memory section
var conversation_data = null  # ConversationSaveData

## Errand quest section
var errand_data = null  # ErrandSaveData

## World manager (location discovery) section
var world_manager_data = null  # WorldManagerSaveData

## Encounter manager section
var encounter_data = null  # EncounterSaveData

## Audio settings section
@export_group("Settings")
@export var audio_settings: Dictionary = {}

func _init() -> void:
	player = PlayerSaveData.new()
	inventory = InventorySaveData.new()
	world = WorldSaveData.new()
	quests = QuestSaveData.new()
	time_data = TimeSaveData.new()
	crime_data = CrimeSaveData.new()
	dialogue_data = DialogueSaveData.new()
	conversation_data = ConversationSaveData.new()
	errand_data = ErrandSaveData.new()
	world_manager_data = WorldManagerSaveData.new()
	encounter_data = EncounterSaveData.new()

## Convert to dictionary for JSON serialization
func to_dict() -> Dictionary:
	return {
		"version": version,
		"timestamp": timestamp,
		"datetime_string": datetime_string,
		"game_version": game_version,
		"player": player.to_dict() if player else {},
		"inventory": inventory.to_dict() if inventory else {},
		"world": world.to_dict() if world else {},
		"quests": quests.to_dict() if quests else {},
		"time": time_data.to_dict() if time_data else {},
		"crime": crime_data.to_dict() if crime_data else {},
		"dialogue": dialogue_data.to_dict() if dialogue_data else {},
		"conversation": conversation_data.to_dict() if conversation_data else {},
		"errands": errand_data.to_dict() if errand_data else {},
		"world_manager": world_manager_data.to_dict() if world_manager_data else {},
		"encounters": encounter_data.to_dict() if encounter_data else {},
		"audio_settings": audio_settings
	}

## Load from dictionary
func from_dict(data: Dictionary) -> void:
	version = data.get("version", 1)
	timestamp = data.get("timestamp", 0.0)
	datetime_string = data.get("datetime_string", "")
	game_version = data.get("game_version", "1.0.0")

	if player:
		player.from_dict(data.get("player", {}))
	if inventory:
		inventory.from_dict(data.get("inventory", {}))
	if world:
		world.from_dict(data.get("world", {}))
	if quests:
		quests.from_dict(data.get("quests", {}))
	if time_data:
		time_data.from_dict(data.get("time", {}))
	if crime_data:
		crime_data.from_dict(data.get("crime", {}))
	if dialogue_data:
		dialogue_data.from_dict(data.get("dialogue", {}))
	if conversation_data:
		conversation_data.from_dict(data.get("conversation", {}))
	if errand_data:
		errand_data.from_dict(data.get("errands", {}))
	if world_manager_data:
		world_manager_data.from_dict(data.get("world_manager", {}))
	if encounter_data:
		encounter_data.from_dict(data.get("encounters", {}))

	audio_settings = data.get("audio_settings", {})

## Validate save data structure
func is_valid() -> bool:
	if version < 1:
		return false
	if not player:
		return false
	return true

## Get display info for save slot UI
func get_display_info() -> Dictionary:
	return {
		"character_name": player.character_name if player else "Unknown",
		"level": player.level if player else 1,
		"play_time": time_data.play_time if time_data else 0.0,
		"datetime": datetime_string,
		"location": world.current_zone_name if world else "Unknown",
		"current_scene": player.current_scene if player else ""
	}


## Player save data structure
class PlayerSaveData:
	## Identity
	var character_name: String = "Unnamed"
	var race: int = 0  # Enums.Race
	var career: int = 0  # Enums.Career

	## Core stats
	var grit: int = 3
	var agility: int = 3
	var will: int = 3
	var speech: int = 3
	var knowledge: int = 3
	var vitality: int = 3

	## Resources
	var current_hp: int = 100
	var max_hp: int = 100
	var current_stamina: int = 100
	var max_stamina: int = 100
	var current_mana: int = 50
	var max_mana: int = 50
	var current_spell_slots: int = 5
	var max_spell_slots: int = 5

	## Progression
	var level: int = 1
	var improvement_points: int = 0

	## Skills dictionary (skill_id -> level)
	var skills: Dictionary = {}

	## Active conditions (condition_id -> time_remaining)
	var conditions: Dictionary = {}

	## Known spell IDs
	var known_spells: Array = []

	## Position and rotation
	var position: Vector3 = Vector3.ZERO
	var rotation_y: float = 0.0
	var current_scene: String = ""

	func to_dict() -> Dictionary:
		return {
			"character_name": character_name,
			"race": race,
			"career": career,
			"grit": grit,
			"agility": agility,
			"will": will,
			"speech": speech,
			"knowledge": knowledge,
			"vitality": vitality,
			"current_hp": current_hp,
			"max_hp": max_hp,
			"current_stamina": current_stamina,
			"max_stamina": max_stamina,
			"current_mana": current_mana,
			"max_mana": max_mana,
			"current_spell_slots": current_spell_slots,
			"max_spell_slots": max_spell_slots,
			"level": level,
			"improvement_points": improvement_points,
			"skills": skills,
			"conditions": conditions,
			"known_spells": known_spells,
			"position": {"x": position.x, "y": position.y, "z": position.z},
			"rotation_y": rotation_y,
			"current_scene": current_scene
		}

	func from_dict(data: Dictionary) -> void:
		character_name = data.get("character_name", "Unnamed")
		race = data.get("race", 0)
		career = data.get("career", 0)
		grit = data.get("grit", 3)
		agility = data.get("agility", 3)
		will = data.get("will", 3)
		speech = data.get("speech", 3)
		knowledge = data.get("knowledge", 3)
		vitality = data.get("vitality", 3)
		current_hp = data.get("current_hp", 100)
		max_hp = data.get("max_hp", 100)
		current_stamina = data.get("current_stamina", 100)
		max_stamina = data.get("max_stamina", 100)
		current_mana = data.get("current_mana", 50)
		max_mana = data.get("max_mana", 50)
		current_spell_slots = data.get("current_spell_slots", 5)
		max_spell_slots = data.get("max_spell_slots", 5)
		level = data.get("level", 1)
		improvement_points = data.get("improvement_points", 0)
		skills = data.get("skills", {})
		conditions = data.get("conditions", {})
		known_spells = data.get("known_spells", [])

		var pos_data: Dictionary = data.get("position", {})
		position = Vector3(
			pos_data.get("x", 0.0),
			pos_data.get("y", 0.0),
			pos_data.get("z", 0.0)
		)
		rotation_y = data.get("rotation_y", 0.0)
		current_scene = data.get("current_scene", "")


## Inventory save data structure
class InventorySaveData:
	## Items in inventory (array of item data dicts)
	var items: Array = []

	## Currently equipped items (slot_id -> item_data)
	var equipment: Dictionary = {}

	## Gold/currency
	var gold: int = 0

	## Quickslot assignments (slot_index -> item_id or spell_id)
	var quickslots: Array = []

	## Hotbar assignments (10 slots, each {type, id})
	var hotbar: Array = []

	## Currently equipped spell ID
	var equipped_spell_id: String = ""

	func to_dict() -> Dictionary:
		return {
			"items": items,
			"equipment": equipment,
			"gold": gold,
			"quickslots": quickslots,
			"hotbar": hotbar,
			"equipped_spell_id": equipped_spell_id
		}

	func from_dict(data: Dictionary) -> void:
		items = data.get("items", [])
		equipment = data.get("equipment", {})
		gold = data.get("gold", 0)
		quickslots = data.get("quickslots", [])
		hotbar = data.get("hotbar", [])
		equipped_spell_id = data.get("equipped_spell_id", "")


## World state save data structure
class WorldSaveData:
	## Current zone/scene info
	var current_zone_id: String = ""
	var current_zone_name: String = ""

	## Discovered locations (zone_id -> discovery_data)
	var discovered_locations: Dictionary = {}

	## Killed enemies that should stay dead (enemy_unique_id -> kill_data)
	var killed_enemies: Dictionary = {}

	## Dropped items in world (zone_id -> array of item_data)
	var dropped_items: Dictionary = {}

	## World flags (flag_name -> value)
	## Used for: unlocked doors, pulled levers, triggered events, etc.
	var flags: Dictionary = {}

	## Opened containers (container_id -> true)
	var opened_containers: Dictionary = {}

	## Unlocked shortcuts (shortcut_id -> true)
	var unlocked_shortcuts: Dictionary = {}

	## Dungeon seeds for procedural generation (zone_id -> seed_int)
	var dungeon_seeds: Dictionary = {}

	## Rest manager state (diminishing returns, respawn tracking)
	var rest_manager: Dictionary = {}

	func to_dict() -> Dictionary:
		return {
			"current_zone_id": current_zone_id,
			"current_zone_name": current_zone_name,
			"discovered_locations": discovered_locations,
			"killed_enemies": killed_enemies,
			"dropped_items": dropped_items,
			"flags": flags,
			"opened_containers": opened_containers,
			"unlocked_shortcuts": unlocked_shortcuts,
			"dungeon_seeds": dungeon_seeds,
			"rest_manager": rest_manager
		}

	func from_dict(data: Dictionary) -> void:
		current_zone_id = data.get("current_zone_id", "")
		current_zone_name = data.get("current_zone_name", "")
		discovered_locations = data.get("discovered_locations", {})
		killed_enemies = data.get("killed_enemies", {})
		dropped_items = data.get("dropped_items", {})
		flags = data.get("flags", {})
		opened_containers = data.get("opened_containers", {})
		unlocked_shortcuts = data.get("unlocked_shortcuts", {})
		dungeon_seeds = data.get("dungeon_seeds", {})
		rest_manager = data.get("rest_manager", {})


## Quest save data structure
class QuestSaveData:
	## Active quests (quest_id -> quest_progress_data)
	var active: Dictionary = {}

	## Completed quests (quest_id -> completion_data)
	var completed: Dictionary = {}

	## Failed quests (quest_id -> failure_data)
	var failed: Dictionary = {}

	## Quest-related flags/variables
	var variables: Dictionary = {}

	func to_dict() -> Dictionary:
		return {
			"active": active,
			"completed": completed,
			"failed": failed,
			"variables": variables
		}

	func from_dict(data: Dictionary) -> void:
		active = data.get("active", {})
		completed = data.get("completed", {})
		failed = data.get("failed", {})
		variables = data.get("variables", {})


## Time tracking save data structure
class TimeSaveData:
	## Total play time in seconds
	var play_time: float = 0.0

	## In-game time (hour of day, 0-24)
	var game_time: float = 8.0

	## Number of times player has rested
	var rest_count: int = 0

	## Number of deaths
	var death_count: int = 0

	## Session start timestamp (for calculating play time delta)
	var session_start: float = 0.0

	## Current in-game day
	var current_day: int = 1

	func to_dict() -> Dictionary:
		return {
			"play_time": play_time,
			"game_time": game_time,
			"rest_count": rest_count,
			"death_count": death_count,
			"session_start": session_start,
			"current_day": current_day
		}

	func from_dict(data: Dictionary) -> void:
		play_time = data.get("play_time", 0.0)
		game_time = data.get("game_time", 8.0)
		rest_count = data.get("rest_count", 0)
		death_count = data.get("death_count", 0)
		session_start = data.get("session_start", 0.0)
		current_day = data.get("current_day", 1)


## Crime/bounty save data structure
class CrimeSaveData:
	## Bounties per region (region_id -> bounty_amount)
	var bounties: Dictionary = {}

	## Last known crimes per region (region_id -> CrimeType)
	var last_crimes: Dictionary = {}

	## Whether player is currently in jail
	var is_jailed: bool = false

	## Current jail region if jailed
	var jail_region: String = ""

	## Remaining jail time in game hours
	var jail_time_remaining: float = 0.0

	## Confiscated items while in jail (region_id -> items array)
	var confiscated_items: Dictionary = {}

	func to_dict() -> Dictionary:
		return {
			"bounties": bounties,
			"last_crimes": last_crimes,
			"is_jailed": is_jailed,
			"jail_region": jail_region,
			"jail_time_remaining": jail_time_remaining,
			"confiscated_items": confiscated_items
		}

	func from_dict(data: Dictionary) -> void:
		bounties = data.get("bounties", {})
		last_crimes = data.get("last_crimes", {})
		is_jailed = data.get("is_jailed", false)
		jail_region = data.get("jail_region", "")
		jail_time_remaining = data.get("jail_time_remaining", 0.0)
		confiscated_items = data.get("confiscated_items", {})


## Dialogue flags save data structure
class DialogueSaveData:
	## Dialogue flags (flag_name -> value)
	## Tracks things like "talked_to_merchant_about_quest", "intimidated_guard", etc.
	var flags: Dictionary = {}

	func to_dict() -> Dictionary:
		return {
			"flags": flags
		}

	func from_dict(data: Dictionary) -> void:
		flags = data.get("flags", {})


## Conversation memory save data structure
class ConversationSaveData:
	## NPC memory (npc_id:response_id -> original_text)
	## Tracks what each NPC has told the player
	var npc_memory: Dictionary = {}

	func to_dict() -> Dictionary:
		return {
			"npc_memory": npc_memory
		}

	func from_dict(data: Dictionary) -> void:
		npc_memory = data.get("npc_memory", {})


## Bounty quest save data structure (replaces old ErrandSaveData)
class ErrandSaveData:
	## All bounties (active, pending, completed) as dict of bounty_id -> bounty data
	var bounties: Dictionary = {}

	## NPC's current offered bounty mapping (npc_id -> bounty_id)
	var npc_offered_bounties: Dictionary = {}

	## Completed bounty IDs (to prevent re-offering)
	var completed_bounty_ids: Array = []

	## Bounty ID counter
	var bounty_counter: int = 0

	## Current settlement for bounty generation
	var current_settlement: String = "village_elder_moor"

	func to_dict() -> Dictionary:
		return {
			"bounties": bounties,
			"npc_offered_bounties": npc_offered_bounties,
			"completed_bounty_ids": completed_bounty_ids,
			"bounty_counter": bounty_counter,
			"current_settlement": current_settlement
		}

	func from_dict(data: Dictionary) -> void:
		bounties = data.get("bounties", {})
		npc_offered_bounties = data.get("npc_offered_bounties", {})
		completed_bounty_ids = data.get("completed_bounty_ids", [])
		bounty_counter = data.get("bounty_counter", 0)
		current_settlement = data.get("current_settlement", "village_elder_moor")


## World manager (location discovery) save data structure
class WorldManagerSaveData:
	## Discovered locations (location_id -> {name, type, coords, discovered_time})
	var discovered_locations: Dictionary = {}

	## Discovered cells from WorldData (array of {x, y})
	var discovered_cells: Array = []

	## Current player position in world grid
	var current_cell: Dictionary = {"x": 0, "y": 0}

	## Current region name
	var current_region: String = ""

	## Current location ID (if at a location)
	var current_location_id: String = ""

	## Travel statistics
	var cells_traveled: int = 0
	var locations_visited: int = 0

	func to_dict() -> Dictionary:
		return {
			"discovered_locations": discovered_locations,
			"discovered_cells": discovered_cells,
			"current_cell": current_cell,
			"current_region": current_region,
			"current_location_id": current_location_id,
			"cells_traveled": cells_traveled,
			"locations_visited": locations_visited
		}

	func from_dict(data: Dictionary) -> void:
		discovered_locations = data.get("discovered_locations", {})
		discovered_cells = data.get("discovered_cells", [])
		current_cell = data.get("current_cell", {"x": 0, "y": 0})
		current_region = data.get("current_region", "")
		current_location_id = data.get("current_location_id", "")
		cells_traveled = data.get("cells_traveled", 0)
		locations_visited = data.get("locations_visited", 0)


## Encounter manager save data structure
class EncounterSaveData:
	## Total encounters triggered this playthrough
	var encounters_triggered: int = 0

	## Total encounters avoided this playthrough
	var encounters_avoided: int = 0

	## Cooldown timer remaining (to persist across saves)
	var cooldown_remaining: float = 0.0

	## Encounter timer state
	var encounter_timer: float = 0.0

	## Last hex where encounter was checked
	var last_check_hex: Dictionary = {"x": 0, "y": 0}

	func to_dict() -> Dictionary:
		return {
			"encounters_triggered": encounters_triggered,
			"encounters_avoided": encounters_avoided,
			"cooldown_remaining": cooldown_remaining,
			"encounter_timer": encounter_timer,
			"last_check_hex": last_check_hex
		}

	func from_dict(data: Dictionary) -> void:
		encounters_triggered = data.get("encounters_triggered", 0)
		encounters_avoided = data.get("encounters_avoided", 0)
		cooldown_remaining = data.get("cooldown_remaining", 0.0)
		encounter_timer = data.get("encounter_timer", 0.0)
		last_check_hex = data.get("last_check_hex", {"x": 0, "y": 0})
