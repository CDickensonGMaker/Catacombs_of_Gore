## conversation_topic.gd - Topic category resource for topic-based dialogue system
## Represents a conversation topic that NPCs can respond to
@tool
class_name ConversationTopic
extends Resource

## Types of conversation topics available to the player
enum TopicType {
	LOCAL_NEWS,      ## What's happening in this area
	RUMORS,          ## Dungeons, treasures, dangers
	PERSONAL,        ## NPC's life, job, family
	DIRECTIONS,      ## Where is X?
	TRADE,           ## Economy, buying/selling
	WEATHER,         ## Weather and environment
	QUESTS,          ## Seeking work, bounties
	GOODBYE          ## End conversation
}

## The type of topic this represents
@export var topic_type: TopicType = TopicType.LOCAL_NEWS
## Display name shown in menus/UI
@export var display_name: String = ""
## Full menu text shown to player (e.g., "What's been happening around here?")
@export var menu_text: String = ""
## Knowledge tags required for this topic to be available
@export var required_knowledge_tags: Array[String] = []
## Additional conditions that must be met for this topic to be available
@export var conditions: Array[DialogueCondition] = []


# =============================================================================
# STATIC FACTORY METHODS
# =============================================================================

## Create a local news topic
static func local_news(menu_text: String = "What's been happening around here?") -> ConversationTopic:
	var topic := ConversationTopic.new()
	topic.topic_type = TopicType.LOCAL_NEWS
	topic.display_name = "Local News"
	topic.menu_text = menu_text
	return topic

## Create a rumors topic
static func rumors(menu_text: String = "Heard any interesting rumors?") -> ConversationTopic:
	var topic := ConversationTopic.new()
	topic.topic_type = TopicType.RUMORS
	topic.display_name = "Rumors"
	topic.menu_text = menu_text
	return topic

## Create a personal topic
static func personal(menu_text: String = "Tell me about yourself.") -> ConversationTopic:
	var topic := ConversationTopic.new()
	topic.topic_type = TopicType.PERSONAL
	topic.display_name = "Personal"
	topic.menu_text = menu_text
	return topic

## Create a directions topic
static func directions(menu_text: String = "Can you give me directions?") -> ConversationTopic:
	var topic := ConversationTopic.new()
	topic.topic_type = TopicType.DIRECTIONS
	topic.display_name = "Directions"
	topic.menu_text = menu_text
	return topic

## Create a trade topic
static func trade(menu_text: String = "What can you tell me about trade here?") -> ConversationTopic:
	var topic := ConversationTopic.new()
	topic.topic_type = TopicType.TRADE
	topic.display_name = "Trade"
	topic.menu_text = menu_text
	return topic

## Create a weather topic
static func weather(menu_text: String = "How's the weather been?") -> ConversationTopic:
	var topic := ConversationTopic.new()
	topic.topic_type = TopicType.WEATHER
	topic.display_name = "Weather"
	topic.menu_text = menu_text
	return topic

## Create a quests topic
static func quests(menu_text: String = "Looking for any help around here?") -> ConversationTopic:
	var topic := ConversationTopic.new()
	topic.topic_type = TopicType.QUESTS
	topic.display_name = "Quests"
	topic.menu_text = menu_text
	return topic

## Create a goodbye topic
static func goodbye(menu_text: String = "Farewell.") -> ConversationTopic:
	var topic := ConversationTopic.new()
	topic.topic_type = TopicType.GOODBYE
	topic.display_name = "Goodbye"
	topic.menu_text = menu_text
	return topic

# =============================================================================
# HELPER METHODS
# =============================================================================

## Get the default menu text for a topic type
static func get_default_menu_text(type: TopicType) -> String:
	match type:
		TopicType.LOCAL_NEWS:
			return "What's been happening around here?"
		TopicType.RUMORS:
			return "Heard any interesting rumors?"
		TopicType.PERSONAL:
			return "Tell me about yourself."
		TopicType.DIRECTIONS:
			return "Can you give me directions?"
		TopicType.TRADE:
			return "What can you tell me about trade here?"
		TopicType.WEATHER:
			return "How's the weather been?"
		TopicType.QUESTS:
			return "Looking for any help around here?"
		TopicType.GOODBYE:
			return "Farewell."
		_:
			return ""

## Get a human-readable name for a topic type
static func get_topic_name(type: TopicType) -> String:
	match type:
		TopicType.LOCAL_NEWS:
			return "Local News"
		TopicType.RUMORS:
			return "Rumors"
		TopicType.PERSONAL:
			return "Personal"
		TopicType.DIRECTIONS:
			return "Directions"
		TopicType.TRADE:
			return "Trade"
		TopicType.WEATHER:
			return "Weather"
		TopicType.QUESTS:
			return "Quests"
		TopicType.GOODBYE:
			return "Goodbye"
		_:
			return "Unknown"
