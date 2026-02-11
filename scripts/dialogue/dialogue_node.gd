## dialogue_node.gd - A single node in a dialogue tree
@tool
class_name DialogueNode
extends Resource

## Unique identifier for this node within the dialogue tree
@export var id: String = ""
## Name of the speaker (NPC name, "Player", or empty for narration)
@export var speaker_name: String = ""
## The dialogue text to display
@export_multiline var text: String = ""
## Available choices/responses at this node
@export var choices: Array[DialogueChoice] = []

## If true, this node ends the dialogue after displaying
@export var is_end_node: bool = false
## Optional: automatically continue to this node if no choices
@export var auto_continue_to: String = ""
## Optional: portrait/emotion for the speaker
@export var portrait_id: String = ""

## Create a simple node with text and optional choices
static func create(node_id: String, speaker: String, dialogue_text: String,
				   node_choices: Array[DialogueChoice] = []) -> DialogueNode:
	var node := DialogueNode.new()
	node.id = node_id
	node.speaker_name = speaker
	node.text = dialogue_text
	node.choices = node_choices
	return node
