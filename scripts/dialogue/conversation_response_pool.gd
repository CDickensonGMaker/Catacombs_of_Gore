## conversation_response_pool.gd - Container resource for arrays of ConversationResponse
## Used to store pools of responses for topic-based dialogue system
@tool
class_name ConversationResponsePool
extends Resource

## Array of ConversationResponse resources in this pool
@export var responses: Array[ConversationResponse] = []

## Optional identifier for this pool (e.g., "greetings", "local_news")
@export var pool_id: String = ""

## Description of what this pool contains
@export var description: String = ""


# =============================================================================
# HELPER METHODS
# =============================================================================

## Get responses filtered by disposition range
func get_responses_for_disposition(disposition: int) -> Array[ConversationResponse]:
	var filtered: Array[ConversationResponse] = []
	for response: ConversationResponse in responses:
		if disposition >= response.min_disposition and disposition <= response.max_disposition:
			filtered.append(response)
	return filtered


## Get responses that match a personality trait
func get_responses_for_personality(trait_name: String) -> Array[ConversationResponse]:
	var matched: Array[ConversationResponse] = []
	for response: ConversationResponse in responses:
		if trait_name in response.personality_affinity:
			matched.append(response)
	return matched


## Get responses for a specific topic type
func get_responses_for_topic(topic_type: ConversationTopic.TopicType) -> Array[ConversationResponse]:
	var filtered: Array[ConversationResponse] = []
	for response: ConversationResponse in responses:
		if response.topic_type == topic_type:
			filtered.append(response)
	return filtered


## Get total number of responses
func get_response_count() -> int:
	return responses.size()


## Check if pool has any responses
func is_empty() -> bool:
	return responses.is_empty()
