## dialogue_choice.gd - A player choice/response option in a dialogue node
@tool
class_name DialogueChoice
extends Resource

## Text displayed for this choice
@export var text: String = ""
## Node ID to go to when this choice is selected
@export var next_node_id: String = ""

@export_group("Conditions")
## Conditions that must be met for this choice to appear
@export var conditions: Array[DialogueCondition] = []
## If true, choice appears but is disabled when conditions fail
@export var show_when_unavailable: bool = false
## Text to show in tooltip when unavailable
@export var unavailable_reason: String = ""

@export_group("Actions")
## Actions to execute when this choice is selected
@export var actions: Array[DialogueAction] = []

## Create a simple choice
static func create(choice_text: String, next_id: String) -> DialogueChoice:
	var choice := DialogueChoice.new()
	choice.text = choice_text
	choice.next_node_id = next_id
	return choice

## Create a choice with a single condition
static func create_conditional(choice_text: String, next_id: String,
							   condition: DialogueCondition) -> DialogueChoice:
	var choice := DialogueChoice.new()
	choice.text = choice_text
	choice.next_node_id = next_id
	choice.conditions.append(condition)
	return choice
