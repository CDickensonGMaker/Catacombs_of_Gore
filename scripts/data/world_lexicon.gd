## world_lexicon.gd - Single source of truth for all world content
## Used by BountyManager and NPC dialogue for consistent world references
class_name WorldLexicon
extends RefCounted

# =============================================================================
# REGIONS - Tied to actual world map locations with specific directions
# =============================================================================

## Region data with creatures that spawn there and specific directions to real locations
const REGIONS := {
	"kreigstan_forest": {
		"name": "Kreigstan Wilds",
		"creatures": ["wolf", "giant_rat", "giant_spider", "human_bandit"],
		"directions": [
			"Head into the forest east of Elder Moor - one or two cells out",
			"Check the woods west of town, toward Dalhurst",
			"Search the forest south of Elder Moor, before the swamps"
		]
	},
	"southern_swamps": {
		"name": "Southern Swamps",
		"creatures": ["giant_rat", "giant_spider", "drowned_dead"],
		"directions": [
			"Go south from Elder Moor - the swamps start after two cells",
			"Head toward Aberdeen, you'll find them in the marshes along the way",
			"The swamps between Elder Moor and Aberdeen are infested"
		]
	},
	"dalhurst_plains": {
		"name": "Dalhurst Coast",
		"creatures": ["wolf", "human_bandit", "dire_wolf"],
		"directions": [
			"Travel west toward Dalhurst - the plains start after three cells",
			"Check the roads between Elder Moor and Dalhurst",
			"The coastal plains near Dalhurst Bay are hunting grounds"
		]
	},
	"whaeler_hills": {
		"name": "Whaeler's Canyon",
		"creatures": ["goblin_soldier", "goblin_archer", "wolf", "ogre"],
		"directions": [
			"Head south to Aberdeen, then east toward Whaeler's Drake",
			"The hills east of Aberdeen, on the way to Whaeler's Drake",
			"Travel the eastern path past Aberdeen - takes about five cells"
		]
	},
	"willow_dale_area": {
		"name": "Willow Dale",
		"creatures": ["giant_spider", "wolf", "skeleton_warrior"],
		"directions": [
			"Go northwest from Elder Moor - Willow Dale dungeon is three cells out",
			"Head west then north - past the first forest cells",
			"The old Willow Dale ruins northwest of town"
		]
	},
	"undead_lands": {
		"name": "Undead Lands",
		"creatures": ["skeleton_warrior", "skeleton_shade", "drowned_dead", "cultist"],
		"directions": [
			"Far northwest, past Willow Dale - cursed lands begin there",
			"Beyond the forests northwest of Elder Moor lies cursed territory",
			"Travel northwest past Willow Dale dungeon - dangerous territory"
		]
	},
	"mountain_pass": {
		"name": "Mountain Pass",
		"creatures": ["goblin_soldier", "goblin_leader", "troll", "ogre"],
		"directions": [
			"The Keerzhar Pass - go east to Whaeler's Drake, then north through the mountains",
			"Take the eastern route to the mountain pass - long journey via Aberdeen",
			"Mountains block the direct path north - must go east through Whaeler's first"
		]
	},
	"elven_woods": {
		"name": "Elven Lands",
		"creatures": ["wolf", "dire_wolf", "tree_ent"],
		"directions": [
			"Far east, past Whaeler's Drake - the Elven Woods",
			"Travel east through Whaeler's Canyon to reach the elven territory",
			"The forests east of Whaeler's Drake belong to the elves"
		]
	}
}

# =============================================================================
# CREATURES
# =============================================================================

## Creature display names and IDs (must match enemy .tres file IDs)
const CREATURES := {
	"wolf": {"display": "Wolves", "singular": "wolf", "tier": 1},
	"dire_wolf": {"display": "Dire Wolves", "singular": "dire wolf", "tier": 2},
	"giant_rat": {"display": "Giant Rats", "singular": "giant rat", "tier": 1},
	"giant_spider": {"display": "Giant Spiders", "singular": "giant spider", "tier": 1},
	"goblin_soldier": {"display": "Goblin Soldiers", "singular": "goblin", "tier": 1},
	"goblin_archer": {"display": "Goblin Archers", "singular": "goblin archer", "tier": 1},
	"goblin_leader": {"display": "Goblin Leaders", "singular": "goblin leader", "tier": 2},
	"human_bandit": {"display": "Bandits", "singular": "bandit", "tier": 1},
	"drowned_dead": {"display": "Drowned Dead", "singular": "drowned corpse", "tier": 2},
	"skeleton_warrior": {"display": "Skeleton Warriors", "singular": "skeleton", "tier": 2},
	"skeleton_shade": {"display": "Skeleton Shades", "singular": "shade", "tier": 3},
	"ogre": {"display": "Ogres", "singular": "ogre", "tier": 3},
	"troll": {"display": "Trolls", "singular": "troll", "tier": 3},
	"tree_ent": {"display": "Tree Ents", "singular": "ent", "tier": 3},
	"cultist": {"display": "Cultists", "singular": "cultist", "tier": 2},
	"cult_leader": {"display": "Cult Leaders", "singular": "cult leader", "tier": 3},
	"abomination": {"display": "Abominations", "singular": "abomination", "tier": 4},
	"vampire_lord": {"display": "Vampire Lords", "singular": "vampire", "tier": 4},
	"wyvern": {"display": "Wyverns", "singular": "wyvern", "tier": 4},
	"basilisk": {"display": "Basilisks", "singular": "basilisk", "tier": 4}
}

# =============================================================================
# SETTLEMENTS - Matches actual world_data.gd locations
# =============================================================================

## Settlement data with region for bounty generation
const SETTLEMENTS := {
	"village_elder_moor": {
		"name": "Elder Moor",
		"region": "kreigstan_forest",
		"nearby_regions": ["kreigstan_forest", "southern_swamps", "willow_dale_area"]
	},
	"city_dalhurst": {
		"name": "Dalhurst",
		"region": "dalhurst_plains",
		"nearby_regions": ["dalhurst_plains", "kreigstan_forest"]
	},
	"town_larton": {
		"name": "Larton",
		"region": "dalhurst_plains",
		"nearby_regions": ["dalhurst_plains", "southern_swamps"]
	},
	"town_aberdeen": {
		"name": "Aberdeen",
		"region": "southern_swamps",
		"nearby_regions": ["southern_swamps", "whaeler_hills"]
	},
	"town_east_hollow": {
		"name": "East Hollow",
		"region": "southern_swamps",
		"nearby_regions": ["southern_swamps", "whaeler_hills"]
	},
	"town_whalers_abyss": {
		"name": "Whalers Abyss",
		"region": "whaeler_hills",
		"nearby_regions": ["whaeler_hills", "mountain_pass", "elven_woods"]
	},
	"city_rotherhine": {
		"name": "Rotherhine",
		"region": "mountain_pass",
		"nearby_regions": ["mountain_pass"]
	},
	"capital_falkenhafen": {
		"name": "Falkenhafen",
		"region": "mountain_pass",
		"nearby_regions": ["mountain_pass"]
	},
	"village_elven_outpost": {
		"name": "Elven Outpost",
		"region": "elven_woods",
		"nearby_regions": ["elven_woods", "whaeler_hills"]
	}
}

# =============================================================================
# NPC NAMES
# =============================================================================

## Names for randomly generated NPCs (25 per sex)
const MALE_NAMES := [
	"Aldric", "Borin", "Cedric", "Dunstan", "Edmund", "Gareth", "Harald", "Osric",
	"Godwin", "Leofric", "Wulfric", "Beorn", "Cynric", "Eadric", "Aelfric", "Thurstan",
	"Grimwald", "Roderick", "Sigurd", "Torsten", "Ulrich", "Viktor", "Werner", "Yorick",
	"Magnus"
]

const FEMALE_NAMES := [
	"Elara", "Mira", "Gwendolyn", "Isolde", "Rowena", "Thalia", "Wren", "Astrid",
	"Brunhild", "Cordelia", "Dagny", "Edith", "Freya", "Gunhild", "Helga", "Ingrid",
	"Sigrid", "Thyra", "Valdis", "Ylva", "Adelheid", "Britta", "Carina", "Dagmar",
	"Solveig"
]

## Tracks used names per zone to prevent duplicates
## Format: { "zone_id": { "male": ["Aldric", "Borin"], "female": ["Elara"] } }
static var _used_names_by_zone: Dictionary = {}

const SURNAMES := [
	"Ironhand", "Blackwood", "Stonehelm", "Ashford", "Brightwater", "Coldstream",
	"Darkhollow", "Frostborn", "Goldsmith", "Hawkwind", "Longstride", "Moorwalker",
	"Northwind", "Oakenshield", "Ravencrest", "Silvermane", "Thornwood", "Whitehall"
]

# =============================================================================
# BOUNTY TEMPLATES
# =============================================================================

## Templates for bounty dialogue completion
const BOUNTY_TEMPLATES := {
	"completion": [
		"Well done. Here's your pay.",
		"Good work. The gold is yours.",
		"Impressive. Take your reward.",
		"That's the job done. Here you go.",
		"You've done well. Here's what I promised."
	]
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

## Get a random creature for a region
static func get_random_creature_for_region(region_id: String) -> String:
	if not REGIONS.has(region_id):
		return "wolf"

	var creatures: Array = REGIONS[region_id].creatures
	if creatures.is_empty():
		return "wolf"

	return creatures[randi() % creatures.size()]


## Get creature display name
static func get_creature_display(creature_id: String, plural: bool = true) -> String:
	if not CREATURES.has(creature_id):
		return creature_id.capitalize()

	if plural:
		return CREATURES[creature_id].display
	else:
		return CREATURES[creature_id].singular


## Get creature tier (1-4, higher = more dangerous)
static func get_creature_tier(creature_id: String) -> int:
	if not CREATURES.has(creature_id):
		return 1
	return CREATURES[creature_id].tier


## Get a random direction hint for a region
static func get_random_direction(region_id: String) -> String:
	if not REGIONS.has(region_id):
		return "out in the wilds"

	var directions: Array = REGIONS[region_id].directions
	if directions.is_empty():
		return "out in the wilds"

	return directions[randi() % directions.size()]


## Get region name for display
static func get_region_name(region_id: String) -> String:
	if not REGIONS.has(region_id):
		return region_id.replace("_", " ").capitalize()
	return REGIONS[region_id].name


## Get settlement's primary region
static func get_settlement_region(settlement_id: String) -> String:
	if not SETTLEMENTS.has(settlement_id):
		return "kreigstan_forest"
	return SETTLEMENTS[settlement_id].region


## Get a random nearby region for a settlement (for variety in bounties)
static func get_random_nearby_region(settlement_id: String) -> String:
	if not SETTLEMENTS.has(settlement_id):
		return "kreigstan_forest"

	var nearby: Array = SETTLEMENTS[settlement_id].nearby_regions
	if nearby.is_empty():
		return SETTLEMENTS[settlement_id].region

	return nearby[randi() % nearby.size()]


## Get a random NPC name (not zone-aware, may produce duplicates)
static func get_random_name(is_female: bool = false) -> String:
	var first_names: Array = FEMALE_NAMES if is_female else MALE_NAMES
	var first: String = first_names[randi() % first_names.size()]

	# 30% chance to include surname
	if randf() < 0.3:
		var surname: String = SURNAMES[randi() % SURNAMES.size()]
		return first + " " + surname

	return first


## Get a unique NPC name for a specific zone (no duplicates within same zone)
## Returns empty string if all 25 names for that sex are used in the zone
static func get_unique_name_for_zone(zone_id: String, is_female: bool = false) -> String:
	# Initialize zone tracking if needed
	if not _used_names_by_zone.has(zone_id):
		_used_names_by_zone[zone_id] = {"male": [], "female": []}

	var sex_key: String = "female" if is_female else "male"
	var first_names: Array = FEMALE_NAMES if is_female else MALE_NAMES
	var used_in_zone: Array = _used_names_by_zone[zone_id][sex_key]

	# Find available names
	var available: Array[String] = []
	for name: String in first_names:
		if name not in used_in_zone:
			available.append(name)

	# If all names used, return empty (caller should handle this)
	if available.is_empty():
		push_warning("WorldLexicon: All %s names exhausted in zone '%s'" % [sex_key, zone_id])
		return ""

	# Pick a random available name
	var chosen: String = available[randi() % available.size()]

	# Mark as used
	used_in_zone.append(chosen)

	# 30% chance to include surname
	if randf() < 0.3:
		var surname: String = SURNAMES[randi() % SURNAMES.size()]
		return chosen + " " + surname

	return chosen


## Check if a name is available in a zone
static func is_name_available_in_zone(zone_id: String, name: String, is_female: bool = false) -> bool:
	if not _used_names_by_zone.has(zone_id):
		return true

	var sex_key: String = "female" if is_female else "male"
	var used_in_zone: Array = _used_names_by_zone[zone_id][sex_key]

	# Extract first name (in case full name with surname was passed)
	var first_name: String = name.split(" ")[0]
	return first_name not in used_in_zone


## Reserve a specific name in a zone (for named NPCs that shouldn't be duplicated)
static func reserve_name_in_zone(zone_id: String, name: String, is_female: bool = false) -> void:
	if not _used_names_by_zone.has(zone_id):
		_used_names_by_zone[zone_id] = {"male": [], "female": []}

	var sex_key: String = "female" if is_female else "male"
	var used_in_zone: Array = _used_names_by_zone[zone_id][sex_key]

	# Extract first name
	var first_name: String = name.split(" ")[0]
	if first_name not in used_in_zone:
		used_in_zone.append(first_name)


## Clear all used names for a zone (call when zone is unloaded/reset)
static func clear_zone_names(zone_id: String) -> void:
	if _used_names_by_zone.has(zone_id):
		_used_names_by_zone.erase(zone_id)


## Clear all used names across all zones (call on new game)
static func clear_all_zone_names() -> void:
	_used_names_by_zone.clear()


## Get count of available names remaining for a zone
static func get_available_name_count(zone_id: String, is_female: bool = false) -> int:
	if not _used_names_by_zone.has(zone_id):
		return FEMALE_NAMES.size() if is_female else MALE_NAMES.size()

	var sex_key: String = "female" if is_female else "male"
	var used_count: int = _used_names_by_zone[zone_id][sex_key].size()
	var total: int = FEMALE_NAMES.size() if is_female else MALE_NAMES.size()
	return total - used_count


## Get all regions as an array of IDs
static func get_all_region_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: String in REGIONS.keys():
		ids.append(key)
	return ids


## Get bounty template text
static func get_bounty_template(category: String) -> String:
	if not BOUNTY_TEMPLATES.has(category):
		return ""

	var templates: Array = BOUNTY_TEMPLATES[category]
	if templates.is_empty():
		return ""

	return templates[randi() % templates.size()]
