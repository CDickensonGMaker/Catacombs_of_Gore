## disposition_calculator.gd - Calculates NPC disposition toward player
## Disposition affects dialogue options, prices, and NPC behavior
class_name DispositionCalculator
extends RefCounted

## Disposition thresholds for behavior gating
const THRESHOLD_HOSTILE: int = 20
const THRESHOLD_UNFRIENDLY: int = 40
const THRESHOLD_NEUTRAL: int = 60
const THRESHOLD_FRIENDLY: int = 80

## Disposition status enum
enum DispositionStatus {
	HOSTILE,    # 0-19: Will attack or refuse interaction
	UNFRIENDLY, # 20-39: Minimal cooperation, worst prices
	NEUTRAL,    # 40-59: Standard interaction
	FRIENDLY,   # 60-79: Better prices, more dialogue options
	ALLY        # 80-100: Best prices, full cooperation, special options
}

## Factor weights for disposition calculation
const WEIGHT_BASE: float = 1.0
const WEIGHT_FACTION_REP: float = 0.4
const WEIGHT_MORALITY: float = 0.15
const WEIGHT_RACE_MATCH: float = 0.1
const WEIGHT_BOUNTY: float = 0.2
const WEIGHT_WEAPON_DRAWN: float = 0.15
const WEIGHT_PERSONAL: float = 1.0

## Calculate overall disposition of an NPC toward the player
## Returns a value from 0-100
static func calculate_disposition(npc: Node, player: Node = null) -> int:
	var disposition: float = 50.0  # Start neutral

	# Get player controller if not provided
	if not player:
		player = _get_player()
	if not player:
		return 50

	# Get player data
	var player_data: CharacterData = GameManager.player_data
	if not player_data:
		return 50

	# Factor 1: NPC's base disposition (from their data)
	var base_disposition: int = _get_npc_base_disposition(npc)
	disposition = base_disposition

	# Factor 2: Faction reputation
	var faction_modifier: float = _calculate_faction_modifier(npc, player_data)
	disposition += faction_modifier * WEIGHT_FACTION_REP * 100.0

	# Factor 3: Morality alignment match
	var morality_modifier: float = _calculate_morality_modifier(npc, player_data)
	disposition += morality_modifier * WEIGHT_MORALITY * 100.0

	# Factor 4: Race match bonus
	var race_modifier: float = _calculate_race_modifier(npc, player_data)
	disposition += race_modifier * WEIGHT_RACE_MATCH * 100.0

	# Factor 5: Player bounty penalty
	var bounty_modifier: float = _calculate_bounty_modifier(npc)
	disposition += bounty_modifier * WEIGHT_BOUNTY * 100.0

	# Factor 6: Weapon drawn penalty
	var weapon_modifier: float = _calculate_weapon_modifier(player)
	disposition += weapon_modifier * WEIGHT_WEAPON_DRAWN * 100.0

	# Factor 7: Personal disposition modifier (from previous interactions)
	var personal_modifier: int = _get_personal_modifier(npc)
	disposition += personal_modifier * WEIGHT_PERSONAL

	# Clamp to valid range
	return clampi(int(disposition), 0, 100)

## Get disposition status from value
static func get_disposition_status(disposition: int) -> DispositionStatus:
	if disposition < THRESHOLD_HOSTILE:
		return DispositionStatus.HOSTILE
	elif disposition < THRESHOLD_UNFRIENDLY:
		return DispositionStatus.UNFRIENDLY
	elif disposition < THRESHOLD_NEUTRAL:
		return DispositionStatus.NEUTRAL
	elif disposition < THRESHOLD_FRIENDLY:
		return DispositionStatus.FRIENDLY
	else:
		return DispositionStatus.ALLY

## Get display name for disposition status
static func get_status_name(status: DispositionStatus) -> String:
	match status:
		DispositionStatus.HOSTILE:
			return "Hostile"
		DispositionStatus.UNFRIENDLY:
			return "Unfriendly"
		DispositionStatus.NEUTRAL:
			return "Neutral"
		DispositionStatus.FRIENDLY:
			return "Friendly"
		DispositionStatus.ALLY:
			return "Ally"
		_:
			return "Unknown"

## Get color for disposition status
static func get_status_color(status: DispositionStatus) -> Color:
	match status:
		DispositionStatus.HOSTILE:
			return Color(0.8, 0.2, 0.2)  # Red
		DispositionStatus.UNFRIENDLY:
			return Color(0.9, 0.5, 0.2)  # Orange
		DispositionStatus.NEUTRAL:
			return Color(0.7, 0.7, 0.7)  # Gray
		DispositionStatus.FRIENDLY:
			return Color(0.2, 0.7, 0.2)  # Green
		DispositionStatus.ALLY:
			return Color(0.2, 0.6, 0.9)  # Blue
		_:
			return Color.WHITE

## Get price multiplier based on disposition
static func get_price_multiplier(disposition: int, is_buying: bool) -> float:
	var status: DispositionStatus = get_disposition_status(disposition)

	if is_buying:
		# Player is buying - lower is better
		match status:
			DispositionStatus.HOSTILE:
				return 2.0  # 200% price
			DispositionStatus.UNFRIENDLY:
				return 1.5  # 150% price
			DispositionStatus.NEUTRAL:
				return 1.0  # Normal price
			DispositionStatus.FRIENDLY:
				return 0.9  # 10% discount
			DispositionStatus.ALLY:
				return 0.75  # 25% discount
			_:
				return 1.0
	else:
		# Player is selling - higher is better
		match status:
			DispositionStatus.HOSTILE:
				return 0.25  # 25% of value
			DispositionStatus.UNFRIENDLY:
				return 0.4  # 40% of value
			DispositionStatus.NEUTRAL:
				return 0.5  # 50% of value
			DispositionStatus.FRIENDLY:
				return 0.6  # 60% of value
			DispositionStatus.ALLY:
				return 0.75  # 75% of value
			_:
				return 0.5

## Check if disposition allows a specific interaction
static func allows_interaction(disposition: int, interaction_type: String) -> bool:
	var status: DispositionStatus = get_disposition_status(disposition)

	match interaction_type:
		"trade":
			# Can trade if not hostile
			return status != DispositionStatus.HOSTILE
		"quest":
			# Need at least neutral for quests
			return status >= DispositionStatus.NEUTRAL
		"rumor":
			# Need friendly for rumors
			return status >= DispositionStatus.FRIENDLY
		"secret":
			# Need ally for secrets
			return status >= DispositionStatus.ALLY
		"bribe":
			# Can always attempt bribe (except hostile)
			return status != DispositionStatus.HOSTILE
		"intimidate":
			# Can always attempt intimidation
			return true
		"persuade":
			# Can always attempt persuasion (except hostile)
			return status != DispositionStatus.HOSTILE
		_:
			return true

## Get the player node
static func _get_player() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		return tree.get_first_node_in_group("player")
	return null

## Get NPC's base disposition (from their character data or default)
static func _get_npc_base_disposition(npc: Node) -> int:
	# Check for base_disposition property
	if "base_disposition" in npc:
		return npc.base_disposition

	# Check for character_data with disposition
	if "character_data" in npc and npc.character_data:
		if "base_disposition" in npc.character_data:
			return npc.character_data.base_disposition

	# Default to neutral
	return 50

## Calculate faction reputation modifier (-1.0 to 1.0)
static func _calculate_faction_modifier(npc: Node, _player_data: CharacterData) -> float:
	# Get NPC's faction
	var npc_faction: String = ""
	if "faction" in npc:
		npc_faction = npc.faction
	elif "faction_id" in npc:
		npc_faction = npc.faction_id

	if npc_faction.is_empty():
		return 0.0

	# Get player's reputation with that faction
	var reputation: int = FactionManager.get_reputation(npc_faction)

	# Convert reputation (-100 to 100) to modifier (-1.0 to 1.0)
	return reputation / 100.0

## Calculate morality alignment modifier (-1.0 to 1.0)
static func _calculate_morality_modifier(npc: Node, player_data: CharacterData) -> float:
	# Get NPC's alignment
	var npc_alignment: int = 0
	if "alignment" in npc:
		npc_alignment = npc.alignment
	elif "faction" in npc or "faction_id" in npc:
		var faction_id: String = npc.faction if "faction" in npc else npc.faction_id
		var faction: FactionData = FactionManager.get_faction(faction_id)
		if faction:
			npc_alignment = faction.alignment

	# Get player's morality
	var player_morality: int = player_data.morality_score

	# Calculate alignment match
	# Same sign = positive modifier, opposite signs = negative
	var alignment_diff: int = abs(npc_alignment - player_morality)

	# Max difference is 200 (-100 to 100), convert to -1.0 to 1.0
	# Close alignment = positive, far alignment = negative
	return (100.0 - alignment_diff) / 100.0 - 0.5

## Calculate race match modifier (-0.5 to 0.5)
static func _calculate_race_modifier(npc: Node, player_data: CharacterData) -> float:
	# Get NPC's race
	var npc_race: int = -1
	if "race" in npc:
		# NPC race is stored as a String, convert to Enums.Race
		var race_value: Variant = npc.race
		if race_value is String:
			match race_value.to_lower():
				"human":
					npc_race = Enums.Race.HUMAN
				"elf":
					npc_race = Enums.Race.ELF
				"halfling":
					npc_race = Enums.Race.HALFLING
				"dwarf":
					npc_race = Enums.Race.DWARF
		elif race_value is int:
			npc_race = race_value

	if npc_race < 0:
		return 0.0

	# Check for exact match
	if npc_race == player_data.race:
		return 0.5  # Same race bonus

	# Check for allied/enemy races
	# (Could expand this with race relationship data)
	return 0.0

## Calculate bounty penalty (-1.0 to 0.0)
static func _calculate_bounty_modifier(npc: Node) -> float:
	# Get current region
	var region: String = ""
	if "region" in npc:
		region = npc.region

	if region.is_empty():
		# Use current world region
		if PlayerGPS:
			region = PlayerGPS.current_region

	# Get player's bounty in this region
	var bounty: int = CrimeManager.get_bounty(region)

	if bounty <= 0:
		return 0.0

	# Calculate penalty (max -1.0 at 1000+ bounty)
	var penalty: float = minf(bounty / 1000.0, 1.0)
	return -penalty

## Calculate weapon drawn penalty (-1.0 to 0.0)
static func _calculate_weapon_modifier(player: Node) -> float:
	if not player:
		return 0.0

	# Check if player has weapon drawn
	if "weapon_drawn" in player and player.weapon_drawn:
		return -0.5  # Significant penalty for having weapon out

	return 0.0

## Get personal disposition modifier from NPC's individual memory
static func _get_personal_modifier(npc: Node) -> int:
	# Check for disposition_modifier property
	if "disposition_modifier" in npc:
		return npc.disposition_modifier

	# Check via NPC ID in a global tracker
	var npc_id: String = ""
	if "npc_id" in npc:
		npc_id = npc.npc_id
	elif npc.has_method("get_npc_id"):
		npc_id = npc.get_npc_id()

	if npc_id.is_empty():
		return 0

	# Could check a global NPC disposition tracker here
	# For now, return 0 if no personal modifier found
	return 0

## Modify an NPC's personal disposition toward the player
static func modify_npc_disposition(npc: Node, amount: int) -> void:
	if "disposition_modifier" in npc:
		npc.disposition_modifier = clampi(npc.disposition_modifier + amount, -50, 50)
	elif npc.has_method("modify_disposition"):
		npc.modify_disposition(amount)

## Get dialogue options available at a disposition level
static func get_available_dialogue_options(disposition: int) -> Array[String]:
	var options: Array[String] = ["greeting", "goodbye"]

	var status: DispositionStatus = get_disposition_status(disposition)

	match status:
		DispositionStatus.HOSTILE:
			# Minimal options
			options.append("beg_mercy")
		DispositionStatus.UNFRIENDLY:
			options.append_array(["trade", "ask_directions"])
		DispositionStatus.NEUTRAL:
			options.append_array(["trade", "ask_directions", "local_news", "weather"])
		DispositionStatus.FRIENDLY:
			options.append_array(["trade", "ask_directions", "local_news", "weather", "rumors", "quests", "personal"])
		DispositionStatus.ALLY:
			options.append_array(["trade", "ask_directions", "local_news", "weather", "rumors", "quests", "personal", "secrets", "favor"])

	return options

## Calculate intimidation success chance based on player stats vs NPC
static func calculate_intimidation_chance(npc: Node, player_data: CharacterData) -> float:
	var player_intimidation: int = player_data.get_intimidation_bonus()

	# Get NPC's resistance (Will or specific stat)
	var npc_resistance: int = 10  # Default
	if "will" in npc:
		npc_resistance = npc.will
	elif "intimidation_resistance" in npc:
		npc_resistance = npc.intimidation_resistance

	# Calculate success chance
	var chance: float = 0.5 + (player_intimidation - npc_resistance) * 0.05
	return clampf(chance, 0.1, 0.9)

## Calculate persuasion success chance based on player stats vs NPC
static func calculate_persuasion_chance(_npc: Node, player_data: CharacterData, disposition: int) -> float:
	var player_speech: int = player_data.get_effective_stat(Enums.Stat.SPEECH)
	var player_persuasion: int = player_data.get_skill(Enums.Skill.PERSUASION)

	# Base chance from disposition
	var base_chance: float = disposition / 100.0 * 0.5

	# Modifier from player stats
	var skill_modifier: float = (player_speech + player_persuasion * 2) * 0.02

	return clampf(base_chance + skill_modifier, 0.1, 0.95)
