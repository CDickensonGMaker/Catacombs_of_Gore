## sea_encounter.gd - Resource class for sea encounter definitions
## Defines encounters that can occur during boat travel
@tool
class_name SeaEncounter
extends Resource

## Types of sea encounters
enum EncounterType {
	PIRATE,          # Human pirates seeking plunder
	GHOST_PIRATE,    # Undead ship crews, more dangerous
	SEA_MONSTER,     # Kraken, sea serpent, etc.
	MERCHANT_SHIP,   # Trading opportunity
	STORM,           # Weather hazard, no combat
	ISLAND_DISCOVERY # Discovered uncharted island, exploration opportunity
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Encounter Type")
@export var encounter_type: EncounterType = EncounterType.PIRATE
## Whether this encounter requires combat
@export var is_combat: bool = true
## Whether player can attempt to flee
@export var can_flee: bool = true
## Difficulty of flee check (1-10, higher = harder)
@export var flee_difficulty: int = 5

@export_group("Combat Spawns")
## Enemy IDs to spawn for this encounter (references enemy_data resources)
@export var enemy_spawns: Array[String] = []
## Number of each enemy type to spawn [min, max]
@export var enemy_counts: Array[Vector2i] = []
## Whether enemies spawn in waves
@export var is_wave_encounter: bool = false
## Number of waves (if wave encounter)
@export var wave_count: int = 1

@export_group("Non-Combat NPCs")
## NPC IDs for non-combat encounters (merchants, stranded sailors, etc.)
@export var npc_spawns: Array[String] = []

@export_group("Rewards")
## Gold reward range [min, max]
@export var gold_reward: Vector2i = Vector2i(50, 150)
## Guaranteed item drops (item IDs)
@export var guaranteed_loot: Array[String] = []
## Loot table tier to use (LootTables.LootTier enum value)
@export var loot_tier: int = 2  # UNCOMMON by default
## Number of loot rolls from table
@export var loot_rolls: int = 2
## Experience reward for completing encounter
@export var xp_reward: int = 100

@export_group("Difficulty")
## Difficulty rating 1-10 (affects recommended level)
@export var difficulty_rating: int = 3
## Minimum player level for this encounter to appear
@export var min_player_level: int = 1
## Maximum player level for this encounter (0 = no max)
@export var max_player_level: int = 0

@export_group("Dialogue")
## Dialogue ID for encounter introduction (for pirates, merchants, etc.)
@export var intro_dialogue_id: String = ""
## Dialogue ID for peaceful resolution option
@export var peaceful_dialogue_id: String = ""
## Whether this encounter can be resolved through dialogue
@export var can_resolve_peacefully: bool = false
## Skill used for peaceful resolution (Enums.Skill value)
@export var peaceful_skill: int = 13  # PERSUASION by default
## Difficulty of peaceful skill check
@export var peaceful_skill_dc: int = 12

@export_group("Storm Effects")
## For STORM encounters: damage dealt to player
@export var storm_damage: int = 10
## Chance to lose cargo/items in storm
@export var cargo_loss_chance: float = 0.2
## Duration of storm in game hours
@export var storm_duration_hours: float = 1.0

@export_group("Island Discovery")
## For ISLAND_DISCOVERY: Location ID to create
@export var discovered_location_id: String = ""
## Coordinates for the discovered island (if fixed)
@export var island_coords: Vector2i = Vector2i(-999, -999)
## Whether the island is procedurally placed
@export var procedural_island: bool = true

@export_group("Visuals")
## Scene to load for this encounter
@export var encounter_scene_path: String = ""
## Background image for encounter introduction
@export var background_path: String = ""
## Icon for the encounter type
@export var icon_path: String = ""

@export_group("Audio")
## Music to play during encounter
@export var music_track: String = ""
## Ambient sound for encounter
@export var ambient_sound: String = ""


## Roll how many of each enemy to spawn
func get_enemy_spawn_counts() -> Dictionary:
	var result: Dictionary = {}

	for i in range(enemy_spawns.size()):
		var enemy_id: String = enemy_spawns[i]
		var count_range: Vector2i = Vector2i(1, 1)
		if i < enemy_counts.size():
			count_range = enemy_counts[i]

		var count: int = randi_range(count_range.x, count_range.y)
		result[enemy_id] = count

	return result


## Roll gold reward
func roll_gold_reward() -> int:
	return randi_range(gold_reward.x, gold_reward.y)


## Check if encounter is valid for player level
func is_valid_for_level(player_level: int) -> bool:
	if player_level < min_player_level:
		return false
	if max_player_level > 0 and player_level > max_player_level:
		return false
	return true


## Get encounter type as display string
func get_type_name() -> String:
	match encounter_type:
		EncounterType.PIRATE:
			return "Pirates"
		EncounterType.GHOST_PIRATE:
			return "Ghost Ship"
		EncounterType.SEA_MONSTER:
			return "Sea Monster"
		EncounterType.MERCHANT_SHIP:
			return "Merchant Vessel"
		EncounterType.STORM:
			return "Storm"
		EncounterType.ISLAND_DISCOVERY:
			return "Island Discovery"
	return "Unknown"


## Get recommended player level based on difficulty
func get_recommended_level() -> int:
	return maxi(1, difficulty_rating)


## Check if this is a non-combat encounter
func is_peaceful_encounter() -> bool:
	return encounter_type in [EncounterType.MERCHANT_SHIP, EncounterType.ISLAND_DISCOVERY] or not is_combat


## Apply storm damage and effects (returns Dictionary with results)
func apply_storm_effects() -> Dictionary:
	var results: Dictionary = {
		"damage_dealt": 0,
		"items_lost": [],
		"duration": storm_duration_hours
	}

	if encounter_type != EncounterType.STORM:
		return results

	results.damage_dealt = storm_damage

	# Cargo loss is handled by the caller (BoatTravelManager)
	# since it needs access to player inventory
	results.cargo_loss_chance = cargo_loss_chance

	return results
