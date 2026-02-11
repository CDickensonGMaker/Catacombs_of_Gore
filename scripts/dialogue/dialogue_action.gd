## dialogue_action.gd - An action to execute when a dialogue choice is selected
@tool
class_name DialogueAction
extends Resource

## Type of action to perform
@export var type: DialogueData.ActionType = DialogueData.ActionType.NONE
## Primary string parameter (item_id, quest_id, flag_name, sound_name, etc.)
@export var param_string: String = ""
## Integer parameter (quantity, gold amount, XP amount, etc.)
@export var param_int: int = 0
## Float parameter (for skill checks: DC value)
@export var param_float: float = 0.0
## For skill checks: node to go to on success (overrides choice's next_node_id)
@export var success_node_id: String = ""
## For skill checks: node to go to on failure
@export var failure_node_id: String = ""

## Create a "give item" action
static func give_item(item_id: String, quantity: int = 1) -> DialogueAction:
	var action := DialogueAction.new()
	action.type = DialogueData.ActionType.GIVE_ITEM
	action.param_string = item_id
	action.param_int = quantity
	return action

## Create a "take item" action
static func take_item(item_id: String, quantity: int = 1) -> DialogueAction:
	var action := DialogueAction.new()
	action.type = DialogueData.ActionType.TAKE_ITEM
	action.param_string = item_id
	action.param_int = quantity
	return action

## Create a "give gold" action
static func give_gold(amount: int) -> DialogueAction:
	var action := DialogueAction.new()
	action.type = DialogueData.ActionType.GIVE_GOLD
	action.param_int = amount
	return action

## Create a "take gold" action
static func take_gold(amount: int) -> DialogueAction:
	var action := DialogueAction.new()
	action.type = DialogueData.ActionType.TAKE_GOLD
	action.param_int = amount
	return action

## Create a "start quest" action
static func start_quest(quest_id: String) -> DialogueAction:
	var action := DialogueAction.new()
	action.type = DialogueData.ActionType.START_QUEST
	action.param_string = quest_id
	return action

## Create a "complete quest" action
static func complete_quest(quest_id: String) -> DialogueAction:
	var action := DialogueAction.new()
	action.type = DialogueData.ActionType.COMPLETE_QUEST
	action.param_string = quest_id
	return action

## Create a "set flag" action
static func set_flag(flag_name: String) -> DialogueAction:
	var action := DialogueAction.new()
	action.type = DialogueData.ActionType.SET_FLAG
	action.param_string = flag_name
	return action

## Create a "clear flag" action
static func clear_flag(flag_name: String) -> DialogueAction:
	var action := DialogueAction.new()
	action.type = DialogueData.ActionType.CLEAR_FLAG
	action.param_string = flag_name
	return action

## Create a skill check action with success/fail branching
## skill_enum: The Enums.Skill value to check
## dc: Difficulty class to beat
## success_node: Node ID on success
## fail_node: Node ID on failure
static func skill_check(skill_enum: int, dc: float,
						success_node: String, fail_node: String) -> DialogueAction:
	var action := DialogueAction.new()
	action.type = DialogueData.ActionType.SKILL_CHECK
	action.param_int = skill_enum
	action.param_float = dc
	action.success_node_id = success_node
	action.failure_node_id = fail_node
	return action

## Create a "give XP" action
static func give_xp(amount: int) -> DialogueAction:
	var action := DialogueAction.new()
	action.type = DialogueData.ActionType.GIVE_XP
	action.param_int = amount
	return action

## Create an "open shop" action
static func open_shop(shop_id: String) -> DialogueAction:
	var action := DialogueAction.new()
	action.type = DialogueData.ActionType.OPEN_SHOP
	action.param_string = shop_id
	return action

## Create a "play sound" action
static func play_sound(sound_name: String) -> DialogueAction:
	var action := DialogueAction.new()
	action.type = DialogueData.ActionType.PLAY_SOUND
	action.param_string = sound_name
	return action
