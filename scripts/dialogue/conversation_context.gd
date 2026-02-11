## conversation_context.gd - Runtime context for variable injection in conversations
## Holds all the data needed to personalize dialogue at runtime
class_name ConversationContext
extends RefCounted

## Reference to the NPC node (for accessing additional data if needed)
var npc: Node = null
## The NPC's display name
var npc_name: String = ""
## The NPC's knowledge and personality profile
var npc_profile: NPCKnowledgeProfile = null
## Name of the current town/settlement
var town_name: String = ""
## Name of the current region/area
var region_name: String = ""
## Name of a nearby dungeon (if any)
var nearby_dungeon_name: String = ""
## Current disposition toward the player (0-100)
var disposition: int = 50
## Response IDs that have already been said in this conversation
var discussed_responses: Array[String] = []
## Player's name for dialogue injection
var player_name: String = "Adventurer"
## Current time of day for context-sensitive responses
var time_of_day: String = "day"
## Current weather for context-sensitive responses
var weather: String = "clear"
## Pending bounty ID for accept/decline workflow
var pending_bounty_id: String = ""
## Additional custom variables for injection
var custom_variables: Dictionary = {}


# =============================================================================
# VARIABLE INJECTION
# =============================================================================

## Replace placeholders in text with actual values
## Supported placeholders:
## {npc_name}, {town_name}, {region_name}, {dungeon_name}, {player_name},
## {time_of_day}, {weather}, and any custom variables
func inject_variables(text: String) -> String:
	var result: String = text

	# Core variables
	result = result.replace("{npc_name}", npc_name)
	result = result.replace("{town_name}", town_name)
	result = result.replace("{region_name}", region_name)
	result = result.replace("{dungeon_name}", nearby_dungeon_name)
	result = result.replace("{player_name}", player_name)
	result = result.replace("{time_of_day}", time_of_day)
	result = result.replace("{weather}", weather)

	# Archetype name if profile exists
	if npc_profile:
		result = result.replace("{archetype}", npc_profile.get_archetype_name())
	else:
		result = result.replace("{archetype}", "person")

	# Custom variables
	for key: String in custom_variables.keys():
		var placeholder: String = "{%s}" % key
		var value: String = str(custom_variables[key])
		result = result.replace(placeholder, value)

	return result


# =============================================================================
# STATIC FACTORY METHODS
# =============================================================================

## Create a basic context with minimal info
static func create_basic(npc_node: Node, name: String, profile: NPCKnowledgeProfile) -> ConversationContext:
	var context := ConversationContext.new()
	context.npc = npc_node
	context.npc_name = name
	context.npc_profile = profile
	if profile:
		context.disposition = profile.base_disposition
	return context

## Create a full context with location info
static func create_full(npc_node: Node, name: String, profile: NPCKnowledgeProfile,
						town: String, region: String, dungeon: String = "") -> ConversationContext:
	var context := ConversationContext.new()
	context.npc = npc_node
	context.npc_name = name
	context.npc_profile = profile
	context.town_name = town
	context.region_name = region
	context.nearby_dungeon_name = dungeon
	if profile:
		context.disposition = profile.base_disposition
	return context


# =============================================================================
# MEMORY MANAGEMENT
# =============================================================================

## Mark a response as having been said
func mark_response_discussed(response_id: String) -> void:
	if response_id.is_empty():
		return
	if response_id not in discussed_responses:
		discussed_responses.append(response_id)

## Check if a response has already been said
func was_response_discussed(response_id: String) -> bool:
	if response_id.is_empty():
		return false
	return response_id in discussed_responses

## Clear all discussed responses (e.g., for a new conversation)
func clear_discussed_responses() -> void:
	discussed_responses.clear()


# =============================================================================
# CUSTOM VARIABLE MANAGEMENT
# =============================================================================

## Set a custom variable for injection
func set_custom_variable(key: String, value: Variant) -> void:
	custom_variables[key] = value

## Get a custom variable
func get_custom_variable(key: String, default: Variant = "") -> Variant:
	return custom_variables.get(key, default)

## Check if a custom variable exists
func has_custom_variable(key: String) -> bool:
	return key in custom_variables

## Remove a custom variable
func remove_custom_variable(key: String) -> void:
	custom_variables.erase(key)


# =============================================================================
# DISPOSITION MANAGEMENT
# =============================================================================

## Modify disposition by an amount (clamped to 0-100)
func modify_disposition(amount: int) -> void:
	disposition = clampi(disposition + amount, 0, 100)

## Get a human-readable disposition description
func get_disposition_label() -> String:
	if disposition >= 90:
		return "Adoring"
	elif disposition >= 75:
		return "Friendly"
	elif disposition >= 60:
		return "Warm"
	elif disposition >= 40:
		return "Neutral"
	elif disposition >= 25:
		return "Cool"
	elif disposition >= 10:
		return "Unfriendly"
	else:
		return "Hostile"


# =============================================================================
# DEBUG / UTILITY
# =============================================================================

## Get a debug summary of this context
func get_debug_summary() -> String:
	var lines: Array[String] = []
	lines.append("=== Conversation Context ===")
	lines.append("NPC: %s" % npc_name)
	lines.append("Town: %s, Region: %s" % [town_name, region_name])
	lines.append("Nearby Dungeon: %s" % nearby_dungeon_name if nearby_dungeon_name else "Nearby Dungeon: None")
	lines.append("Disposition: %d (%s)" % [disposition, get_disposition_label()])
	lines.append("Discussed: %d responses" % discussed_responses.size())
	if npc_profile:
		lines.append("Profile: %s" % npc_profile.get_summary())
	return "\n".join(lines)
