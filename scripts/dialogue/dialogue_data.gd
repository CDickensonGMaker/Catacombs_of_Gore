## dialogue_data.gd - Resource class for NPC dialogue trees
## Supports branching dialogue with conditions and actions
@tool
class_name DialogueData
extends Resource

## Unique identifier for this dialogue tree
@export var id: String = ""
## Display name for editor reference
@export var display_name: String = ""
## Description of this dialogue (editor only)
@export_multiline var description: String = ""

@export_group("Dialogue Tree")
## The ID of the starting node when dialogue begins
@export var start_node_id: String = "start"
## All dialogue nodes in this tree
@export var nodes: Array[DialogueNode] = []

## Condition types for dialogue choices
enum ConditionType {
	NONE,               ## No condition - always available
	QUEST_STATE,        ## Check if quest is in a specific state
	QUEST_COMPLETE,     ## Check if quest has been completed
	HAS_ITEM,           ## Check if player has item (and quantity)
	HAS_GOLD,           ## Check if player has enough gold
	FLAG_SET,           ## Check if a global flag is set
	FLAG_NOT_SET,       ## Check if a global flag is NOT set
	STAT_CHECK,         ## Check if player stat meets threshold
	SKILL_CHECK,        ## Check if player skill meets threshold
	TIME_OF_DAY,        ## Check current time of day
	REPUTATION,         ## Check faction reputation (future)
	RANDOM_CHANCE       ## Random percentage chance
}

## Action types that can trigger when a choice is selected
enum ActionType {
	NONE,               ## No action
	GIVE_ITEM,          ## Give item to player
	TAKE_ITEM,          ## Remove item from player inventory
	GIVE_GOLD,          ## Give gold to player
	TAKE_GOLD,          ## Remove gold from player
	START_QUEST,        ## Start a quest
	COMPLETE_QUEST,     ## Complete/turn in a quest
	ADVANCE_QUEST,      ## Advance quest objective
	SET_FLAG,           ## Set a global flag
	CLEAR_FLAG,         ## Clear a global flag
	SKILL_CHECK,        ## Perform skill check (success/fail branching)
	MODIFY_REPUTATION,  ## Modify faction reputation (future)
	GIVE_XP,            ## Award experience points
	HEAL_PLAYER,        ## Restore player HP
	TELEPORT,           ## Teleport player to location
	OPEN_SHOP,          ## Open shop interface
	PLAY_SOUND,         ## Play a sound effect
	SET_NPC_STATE,      ## Change NPC state/behavior
	SPAWN_ERRAND        ## Spawn an errand quest from a rumor
}


# =============================================================================
# DIALOGUE TREE HELPER METHODS
# =============================================================================

## Get a node by its ID
func get_node_by_id(node_id: String) -> DialogueNode:
	for node in nodes:
		if node.id == node_id:
			return node
	return null

## Get the starting node
func get_start_node() -> DialogueNode:
	return get_node_by_id(start_node_id)

## Get all node IDs in this dialogue
func get_all_node_ids() -> Array[String]:
	var ids: Array[String] = []
	for node in nodes:
		ids.append(node.id)
	return ids

## Validate the dialogue tree structure
## Returns an array of error messages (empty if valid)
func validate() -> Array[String]:
	var errors: Array[String] = []

	if id.is_empty():
		errors.append("Dialogue has no ID")

	if nodes.is_empty():
		errors.append("Dialogue has no nodes")
		return errors

	# Check start node exists
	if not get_start_node():
		errors.append("Start node '%s' not found" % start_node_id)

	# Check for duplicate IDs
	var seen_ids: Dictionary = {}
	for node in nodes:
		if node.id in seen_ids:
			errors.append("Duplicate node ID: %s" % node.id)
		seen_ids[node.id] = true

	# Check all next_node_ids point to valid nodes
	for node in nodes:
		if node.auto_continue_to and not get_node_by_id(node.auto_continue_to):
			errors.append("Node '%s' auto_continue_to '%s' not found" % [node.id, node.auto_continue_to])

		for choice in node.choices:
			if choice.next_node_id and not get_node_by_id(choice.next_node_id):
				errors.append("Node '%s' choice points to missing node '%s'" % [node.id, choice.next_node_id])

			# Check skill check action branching
			for action in choice.actions:
				if action.type == ActionType.SKILL_CHECK:
					if action.success_node_id and not get_node_by_id(action.success_node_id):
						errors.append("Skill check success node '%s' not found" % action.success_node_id)
					if action.failure_node_id and not get_node_by_id(action.failure_node_id):
						errors.append("Skill check failure node '%s' not found" % action.failure_node_id)

	return errors

## Get a summary string for editor display
func get_summary() -> String:
	var node_count := nodes.size()
	var choice_count := 0
	for node in nodes:
		choice_count += node.choices.size()

	return "%d nodes, %d choices" % [node_count, choice_count]
