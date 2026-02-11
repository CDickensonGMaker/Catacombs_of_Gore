## conversation_response.gd - Response template with variable injection for topic-based dialogue
## Contains text with placeholders that get filled at runtime
@tool
class_name ConversationResponse
extends Resource

## Text with placeholders: {npc_name}, {town_name}, {dungeon_name}, {player_name}, etc.
@export_multiline var text: String = ""
## Which topic type this response applies to
@export var topic_type: ConversationTopic.TopicType = ConversationTopic.TopicType.LOCAL_NEWS
## Personality traits that favor this response (e.g., "grumpy", "friendly", "nervous")
@export var personality_affinity: Array[String] = []
## Minimum disposition required to give this response (0-100)
@export_range(0, 100) var min_disposition: int = 0
## Maximum disposition for this response (0-100)
@export_range(0, 100) var max_disposition: int = 100
## Knowledge tags the NPC must have to give this response
@export var required_knowledge: Array[String] = []
## Weight for random selection when multiple responses match (higher = more likely)
@export var weight: float = 1.0
## Actions to execute when this response is given
@export var actions: Array[DialogueAction] = []
## Conditions that must be met for this response to be available
@export var conditions: Array[DialogueCondition] = []
## Unique ID for memory system - tracks if this response was already said
@export var response_id: String = ""


# =============================================================================
# STATIC FACTORY METHODS
# =============================================================================

## Create a basic response for a topic
static func create(response_text: String, topic: ConversationTopic.TopicType) -> ConversationResponse:
	var response := ConversationResponse.new()
	response.text = response_text
	response.topic_type = topic
	return response

## Create a response with personality affinity
static func create_with_personality(response_text: String, topic: ConversationTopic.TopicType,
									personalities: Array[String]) -> ConversationResponse:
	var response := ConversationResponse.new()
	response.text = response_text
	response.topic_type = topic
	response.personality_affinity = personalities
	return response

## Create a response requiring specific disposition range
static func create_with_disposition(response_text: String, topic: ConversationTopic.TopicType,
									min_disp: int, max_disp: int) -> ConversationResponse:
	var response := ConversationResponse.new()
	response.text = response_text
	response.topic_type = topic
	response.min_disposition = min_disp
	response.max_disposition = max_disp
	return response

## Create a response requiring specific knowledge
static func create_with_knowledge(response_text: String, topic: ConversationTopic.TopicType,
								  knowledge_tags: Array[String]) -> ConversationResponse:
	var response := ConversationResponse.new()
	response.text = response_text
	response.topic_type = topic
	response.required_knowledge = knowledge_tags
	return response


# =============================================================================
# VALIDATION METHODS
# =============================================================================

## Check if this response can be given by an NPC with the given profile and context
func matches_context(profile: NPCKnowledgeProfile, disposition: int) -> bool:
	# Check disposition range
	if disposition < min_disposition or disposition > max_disposition:
		return false

	# Check required knowledge tags
	for tag: String in required_knowledge:
		if tag not in profile.knowledge_tags:
			return false

	return true

## Calculate affinity score based on personality match (0.0 to 1.0+)
func calculate_personality_score(profile: NPCKnowledgeProfile) -> float:
	if personality_affinity.is_empty():
		return 1.0  # No preference, neutral score

	var matches: int = 0
	for trait_name: String in personality_affinity:
		if trait_name in profile.personality_traits:
			matches += 1

	if personality_affinity.size() > 0:
		return 1.0 + (float(matches) / float(personality_affinity.size()))

	return 1.0

## Get the final weighted score for selection
func get_selection_weight(profile: NPCKnowledgeProfile) -> float:
	return weight * calculate_personality_score(profile)


# =============================================================================
# HELPER METHODS
# =============================================================================

## Get a summary for editor display
func get_summary() -> String:
	var preview: String = text.substr(0, 50)
	if text.length() > 50:
		preview += "..."
	return "[%s] %s" % [ConversationTopic.get_topic_name(topic_type), preview]

## Check if this response has been said before (using discussed_responses array)
func was_already_said(discussed_responses: Array[String]) -> bool:
	if response_id.is_empty():
		return false
	return response_id in discussed_responses
