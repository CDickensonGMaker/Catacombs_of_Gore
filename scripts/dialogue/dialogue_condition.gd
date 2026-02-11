## dialogue_condition.gd - A condition that must be met for a choice to be available
@tool
class_name DialogueCondition
extends Resource

## Type of condition to check
@export var type: DialogueData.ConditionType = DialogueData.ConditionType.NONE
## Primary parameter (quest_id, item_id, flag_name, stat enum value, etc.)
@export var param_string: String = ""
## Secondary parameter (quantity, threshold value, quest state enum, etc.)
@export var param_int: int = 0
## For random chance: 0.0-1.0 probability
@export var param_float: float = 0.0
## Whether to invert the condition result
@export var invert: bool = false

## Create a quest state condition
static func quest_state(quest_id: String, state: int) -> DialogueCondition:
	var cond := DialogueCondition.new()
	cond.type = DialogueData.ConditionType.QUEST_STATE
	cond.param_string = quest_id
	cond.param_int = state
	return cond

## Create a "has item" condition
static func has_item(item_id: String, quantity: int = 1) -> DialogueCondition:
	var cond := DialogueCondition.new()
	cond.type = DialogueData.ConditionType.HAS_ITEM
	cond.param_string = item_id
	cond.param_int = quantity
	return cond

## Create a "has gold" condition
static func has_gold(amount: int) -> DialogueCondition:
	var cond := DialogueCondition.new()
	cond.type = DialogueData.ConditionType.HAS_GOLD
	cond.param_int = amount
	return cond

## Create a flag check condition
static func flag_set(flag_name: String) -> DialogueCondition:
	var cond := DialogueCondition.new()
	cond.type = DialogueData.ConditionType.FLAG_SET
	cond.param_string = flag_name
	return cond

## Create a stat check condition (stat enum as int, threshold)
static func stat_check(stat_enum: int, threshold: int) -> DialogueCondition:
	var cond := DialogueCondition.new()
	cond.type = DialogueData.ConditionType.STAT_CHECK
	cond.param_int = stat_enum
	cond.param_float = float(threshold)
	return cond

## Create a skill check condition (skill enum as int, threshold)
static func skill_check(skill_enum: int, threshold: int) -> DialogueCondition:
	var cond := DialogueCondition.new()
	cond.type = DialogueData.ConditionType.SKILL_CHECK
	cond.param_int = skill_enum
	cond.param_float = float(threshold)
	return cond

## Create a random chance condition
static func random_chance(probability: float) -> DialogueCondition:
	var cond := DialogueCondition.new()
	cond.type = DialogueData.ConditionType.RANDOM_CHANCE
	cond.param_float = clampf(probability, 0.0, 1.0)
	return cond
