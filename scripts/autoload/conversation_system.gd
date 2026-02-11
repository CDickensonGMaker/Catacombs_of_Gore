## conversation_system.gd - Orchestrates topic-based NPC conversations
## Manages response selection, memory tracking, and disposition
## NOTE: This is an autoload singleton - access via ConversationSystem global
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a conversation begins with an NPC
signal conversation_started(npc: Node, context: ConversationContext)

## Emitted when the player selects a topic to discuss
signal topic_selected(topic_type: ConversationTopic.TopicType)

## Emitted when an NPC delivers a response
signal response_delivered(response: ConversationResponse, context: ConversationContext)

## Emitted when the NPC has already said this before (UI shows reminder)
signal memory_reminder(response_id: String, original_text: String)

## Emitted when conversation ends
signal conversation_ended(npc: Node)


# =============================================================================
# CONSTANTS
# =============================================================================

## Default disposition for NPCs (50 = neutral)
const DEFAULT_DISPOSITION: int = 50

## Minimum and maximum disposition values
const MIN_DISPOSITION: int = 0
const MAX_DISPOSITION: int = 100

## Disposition thresholds for response filtering
const DISPOSITION_HOSTILE: int = 10
const DISPOSITION_UNFRIENDLY: int = 25
const DISPOSITION_NEUTRAL: int = 40
const DISPOSITION_WARM: int = 60
const DISPOSITION_FRIENDLY: int = 75
const DISPOSITION_ALLIED: int = 90


# =============================================================================
# STATE
# =============================================================================

## Whether a conversation is currently active
var is_active: bool = false

## Current conversation context (null when not in conversation)
var current_context: ConversationContext = null

## Current NPC being talked to
var current_npc: Node = null

## Response pools organized by topic type
## Format: TopicType -> Array[ConversationResponse]
var response_pools: Dictionary = {}

## Response pools organized by archetype, then topic
## Format: Archetype -> {TopicType -> Array[ConversationResponse]}
var archetype_pools: Dictionary = {}

## Unique responses for specific NPCs
## Format: npc_id -> {TopicType -> Array[ConversationResponse]}
var unique_responses: Dictionary = {}

## Memory - tracks what each NPC has told the player
## Format: "npc_id:response_id" -> original_text
var npc_memory: Dictionary = {}

## Reference to the conversation UI
var conversation_ui: Node = null


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Continue processing while game is paused (for conversation input handling)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Defer pool loading to ensure all script classes are registered first
	# This fixes the issue where pools fail to load because ConversationResponsePool
	# and ConversationResponse classes aren't registered when autoload runs
	call_deferred("_load_response_pools")
	_instantiate_conversation_ui()


func _instantiate_conversation_ui() -> void:
	# Instantiate the ConversationUI
	var conversation_ui_scene := load("res://scenes/ui/conversation_ui.tscn")
	if conversation_ui_scene:
		conversation_ui = conversation_ui_scene.instantiate()
		add_child(conversation_ui)
		print("ConversationSystem: ConversationUI instantiated")
	else:
		# Create from script if scene doesn't exist
		var ConversationUIScript = load("res://scripts/ui/conversation_ui.gd")
		if ConversationUIScript:
			conversation_ui = ConversationUIScript.new()
			add_child(conversation_ui)
			print("ConversationSystem: ConversationUI created from script")
		else:
			push_error("ConversationSystem: Could not load ConversationUI")


func _load_response_pools() -> void:
	# Load response pools from JSON files (more reliable than .tres resources)
	# JSON doesn't depend on script class registration timing
	var pool_dir := "res://data/conversation_pools/"
	var pool_files: Array[String] = [
		"greetings.json",
		"farewells.json",
		"local_news.json",
		"rumors.json",
		"personal.json",
		"trade.json",
		"quests.json",
		"directions.json"
	]

	var total_responses := 0
	for file_name: String in pool_files:
		var pool_path := pool_dir + file_name
		if not FileAccess.file_exists(pool_path):
			push_warning("ConversationSystem: Pool file not found: %s" % pool_path)
			continue

		var file := FileAccess.open(pool_path, FileAccess.READ)
		if not file:
			push_warning("ConversationSystem: Could not open: %s" % pool_path)
			continue

		var json_text := file.get_as_text()
		file.close()

		var json := JSON.new()
		var error := json.parse(json_text)
		if error != OK:
			push_warning("ConversationSystem: JSON parse error in %s: %s" % [pool_path, json.get_error_message()])
			continue

		var pool_data: Dictionary = json.data
		var responses_loaded := _load_responses_from_dict(pool_data)
		total_responses += responses_loaded
		print("ConversationSystem: Loaded pool '%s' with %d responses" % [file_name, responses_loaded])

	print("ConversationSystem: Total responses loaded - %d topics, %d responses" % [response_pools.size(), total_responses])


## Register all responses from a pool (legacy .tres support)
func _register_pool(pool: ConversationResponsePool) -> void:
	for response: ConversationResponse in pool.responses:
		var topic_type: ConversationTopic.TopicType = response.topic_type
		register_response(topic_type, response)


## Parse responses from a JSON pool dictionary and register them
func _load_responses_from_dict(pool_data: Dictionary) -> int:
	var responses: Array = pool_data.get("responses", [])
	var count := 0

	for resp_data: Variant in responses:
		if not resp_data is Dictionary:
			continue

		var resp_dict: Dictionary = resp_data
		var response := ConversationResponse.new()

		response.response_id = resp_dict.get("response_id", "")
		response.text = resp_dict.get("text", "")
		response.topic_type = resp_dict.get("topic_type", 0) as ConversationTopic.TopicType
		response.min_disposition = resp_dict.get("min_disposition", 0)
		response.max_disposition = resp_dict.get("max_disposition", 100)
		response.weight = resp_dict.get("weight", 1.0)

		# Parse personality_affinity array
		var affinity: Array = resp_dict.get("personality_affinity", [])
		for trait_val: Variant in affinity:
			response.personality_affinity.append(str(trait_val))

		# Parse required_knowledge array
		var knowledge: Array = resp_dict.get("required_knowledge", [])
		for tag: Variant in knowledge:
			response.required_knowledge.append(str(tag))

		# Parse actions (if any)
		var actions_data: Array = resp_dict.get("actions", [])
		for action_data: Variant in actions_data:
			if action_data is Dictionary:
				var action := _parse_action(action_data)
				if action:
					response.actions.append(action)

		# Parse conditions (if any)
		var conditions_data: Array = resp_dict.get("conditions", [])
		for cond_data: Variant in conditions_data:
			if cond_data is Dictionary:
				var condition := _parse_condition(cond_data)
				if condition:
					response.conditions.append(condition)

		register_response(response.topic_type, response)
		count += 1

	return count


## Parse a DialogueAction from a JSON dictionary
func _parse_action(data: Dictionary) -> DialogueAction:
	var action := DialogueAction.new()
	action.type = data.get("action_type", 0) as DialogueData.ActionType
	action.param_string = data.get("string_value", "")
	action.param_int = data.get("int_value", 0)
	action.param_float = data.get("float_value", 0.0)
	action.success_node_id = data.get("success_node_id", "")
	action.failure_node_id = data.get("failure_node_id", "")
	return action


## Parse a DialogueCondition from a JSON dictionary
func _parse_condition(data: Dictionary) -> DialogueCondition:
	var condition := DialogueCondition.new()
	condition.type = data.get("condition_type", 0) as DialogueData.ConditionType
	condition.param_string = data.get("string_value", "")
	condition.param_int = data.get("int_value", 0)
	condition.param_float = data.get("float_value", 0.0)
	condition.invert = data.get("negate", false)
	return condition


# =============================================================================
# CONVERSATION LIFECYCLE
# =============================================================================

## Start a conversation with an NPC
## Returns true if conversation started successfully
func start_conversation(npc: Node, profile: NPCKnowledgeProfile) -> bool:
	if is_active:
		push_warning("ConversationSystem: Already in conversation")
		return false

	if not npc or not profile:
		push_warning("ConversationSystem: Invalid NPC or profile")
		return false

	# Get NPC name
	var npc_name: String = "Stranger"
	if "npc_name" in npc:
		npc_name = npc.npc_name
	elif npc.has_method("get_npc_name"):
		npc_name = npc.get_npc_name()

	# Build conversation context
	current_context = ConversationContext.create_basic(npc, npc_name, profile)
	current_context.disposition = get_disposition(_get_npc_id(npc))

	# Try to get location context from scene manager or current scene
	_populate_location_context(current_context)

	# Store current NPC reference
	current_npc = npc
	is_active = true

	# Pause game for conversation
	GameManager.start_dialogue()

	# Emit signal for UI to respond
	conversation_started.emit(npc, current_context)

	return true


## End the current conversation
func end_conversation() -> void:
	if not is_active:
		return

	var finished_npc := current_npc

	# Clear state
	current_context = null
	current_npc = null
	is_active = false

	# Resume game
	GameManager.end_dialogue()

	# Emit signal
	conversation_ended.emit(finished_npc)


## Get available topics for an NPC based on their knowledge profile
## Simplified to 3 core topics: LOCAL_NEWS, RUMORS (bounties), GOODBYE
func get_available_topics(_profile: NPCKnowledgeProfile) -> Array[ConversationTopic.TopicType]:
	var topics: Array[ConversationTopic.TopicType] = []

	# All NPCs have the same 3 topics
	topics.append(ConversationTopic.TopicType.LOCAL_NEWS)  # What's happening here?
	topics.append(ConversationTopic.TopicType.RUMORS)       # Bounty work
	topics.append(ConversationTopic.TopicType.GOODBYE)      # Exit

	return topics


## Select a topic and get an NPC response
func select_topic(topic_type: ConversationTopic.TopicType) -> void:
	if not is_active or not current_context:
		push_warning("ConversationSystem: No active conversation")
		return

	# Handle goodbye specially
	if topic_type == ConversationTopic.TopicType.GOODBYE:
		topic_selected.emit(topic_type)
		end_conversation()
		return

	# Handle RUMORS topic with bounty system
	if topic_type == ConversationTopic.TopicType.RUMORS:
		topic_selected.emit(topic_type)
		_handle_bounty_topic()
		return

	# Emit topic selected signal
	topic_selected.emit(topic_type)

	# Select appropriate response
	var response: ConversationResponse = select_response(topic_type)

	if not response:
		push_warning("ConversationSystem: No response found for topic %d" % topic_type)
		return

	# Check memory - has NPC already said this?
	var npc_id := _get_npc_id(current_npc)
	if not response.response_id.is_empty():
		var memory_key := _get_memory_key(npc_id, response.response_id)
		if npc_memory.has(memory_key):
			# NPC already said this - emit reminder signal
			var original_text: String = npc_memory[memory_key]
			memory_reminder.emit(response.response_id, original_text)
			# Still deliver the response (UI may show both reminder and new text)

		# Store in memory
		var injected_text := current_context.inject_variables(response.text)
		npc_memory[memory_key] = injected_text

		# Mark as discussed in context
		current_context.mark_response_discussed(response.response_id)

	# Execute any actions attached to the response
	for action in response.actions:
		DialogueManager.execute_action(action)

	# Emit response delivered signal
	response_delivered.emit(response, current_context)


## Select an appropriate response using three-tier system
## Priority: unique (per-NPC) -> archetype -> generic
func select_response(topic_type: ConversationTopic.TopicType) -> ConversationResponse:
	if not current_context:
		return null

	var profile: NPCKnowledgeProfile = current_context.npc_profile
	var npc_id: String = _get_npc_id(current_npc)
	var disposition: int = current_context.disposition

	# Tier 1: Check for unique NPC-specific responses
	if unique_responses.has(npc_id):
		var npc_pool: Dictionary = unique_responses[npc_id]
		if npc_pool.has(topic_type):
			var candidates: Array = npc_pool[topic_type]
			var filtered := _filter_responses(candidates, profile, disposition)
			if not filtered.is_empty():
				return _weighted_select(filtered, profile)

	# Tier 2: Check archetype-specific responses
	if profile and archetype_pools.has(profile.archetype):
		var archetype_pool: Dictionary = archetype_pools[profile.archetype]
		if archetype_pool.has(topic_type):
			var candidates: Array = archetype_pool[topic_type]
			var filtered := _filter_responses(candidates, profile, disposition)
			if not filtered.is_empty():
				return _weighted_select(filtered, profile)

	# Tier 3: Fall back to generic responses
	if response_pools.has(topic_type):
		var candidates: Array = response_pools[topic_type]
		var filtered := _filter_responses(candidates, profile, disposition)
		if not filtered.is_empty():
			return _weighted_select(filtered, profile)

	# Fallback: Create a generic response if all pools are empty
	# This ensures the game doesn't break even if pool loading fails
	push_warning("ConversationSystem: No response found for topic %d, using fallback" % topic_type)
	var fallback := ConversationResponse.new()
	fallback.text = "I'm not sure what to say about that."
	fallback.topic_type = topic_type
	return fallback


## Check if NPC has already said this response
## Returns true if already said, also emits memory_reminder signal
func check_memory(response: ConversationResponse) -> bool:
	if not current_context or not response:
		return false

	if response.response_id.is_empty():
		return false

	var npc_id := _get_npc_id(current_npc)
	var memory_key := _get_memory_key(npc_id, response.response_id)
	if npc_memory.has(memory_key):
		var original_text: String = npc_memory[memory_key]
		memory_reminder.emit(response.response_id, original_text)
		return true

	return false


# =============================================================================
# DISPOSITION MANAGEMENT
# =============================================================================

## Get disposition value for an NPC
func get_disposition(npc_id: String) -> int:
	var flag_key := "disposition:" + npc_id
	var value: Variant = DialogueManager.get_flag(flag_key, null)

	# If no stored disposition, check for base disposition from profile
	if value == null:
		return DEFAULT_DISPOSITION

	if value is int:
		return value
	elif value is float:
		return int(value)

	return DEFAULT_DISPOSITION


## Modify disposition for an NPC
func modify_disposition(npc_id: String, delta: int) -> void:
	var current := get_disposition(npc_id)
	var new_value := clampi(current + delta, MIN_DISPOSITION, MAX_DISPOSITION)
	var flag_key := "disposition:" + npc_id
	DialogueManager.set_flag(flag_key, new_value)


## Set disposition to a specific value
func set_disposition(npc_id: String, value: int) -> void:
	var clamped := clampi(value, MIN_DISPOSITION, MAX_DISPOSITION)
	var flag_key := "disposition:" + npc_id
	DialogueManager.set_flag(flag_key, clamped)


## Get disposition category name for an NPC
func get_disposition_category(npc_id: String) -> String:
	var disposition := get_disposition(npc_id)
	if disposition < DISPOSITION_HOSTILE:
		return "hostile"
	elif disposition < DISPOSITION_UNFRIENDLY:
		return "unfriendly"
	elif disposition < DISPOSITION_NEUTRAL:
		return "cool"
	elif disposition < DISPOSITION_WARM:
		return "neutral"
	elif disposition < DISPOSITION_FRIENDLY:
		return "warm"
	elif disposition < DISPOSITION_ALLIED:
		return "friendly"
	else:
		return "allied"


# =============================================================================
# RESPONSE POOL MANAGEMENT
# =============================================================================

## Register a response in the generic pool
func register_response(topic_type: ConversationTopic.TopicType, response: ConversationResponse) -> void:
	if not response_pools.has(topic_type):
		response_pools[topic_type] = []
	response_pools[topic_type].append(response)


## Register a response for a specific archetype
func register_archetype_response(archetype: NPCKnowledgeProfile.Archetype, topic_type: ConversationTopic.TopicType, response: ConversationResponse) -> void:
	if not archetype_pools.has(archetype):
		archetype_pools[archetype] = {}
	if not archetype_pools[archetype].has(topic_type):
		archetype_pools[archetype][topic_type] = []
	archetype_pools[archetype][topic_type].append(response)


## Register a unique response for a specific NPC
func register_unique_response(npc_id: String, topic_type: ConversationTopic.TopicType, response: ConversationResponse) -> void:
	if not unique_responses.has(npc_id):
		unique_responses[npc_id] = {}
	if not unique_responses[npc_id].has(topic_type):
		unique_responses[npc_id][topic_type] = []
	unique_responses[npc_id][topic_type].append(response)


## Clear all response pools (for reloading)
func clear_response_pools() -> void:
	response_pools.clear()
	archetype_pools.clear()
	unique_responses.clear()


# =============================================================================
# SAVE/LOAD
# =============================================================================

## Serialize conversation state for saving
func to_dict() -> Dictionary:
	return {
		"npc_memory": npc_memory.duplicate()
	}


## Deserialize conversation state from save
func from_dict(data: Dictionary) -> void:
	npc_memory = data.get("npc_memory", {}).duplicate()


## Reset state for new game
func reset_for_new_game() -> void:
	# End any active conversation
	if is_active:
		end_conversation()

	# Clear memory (dispositions are stored in DialogueManager.dialogue_flags)
	npc_memory.clear()


# =============================================================================
# BOUNTY HANDLING
# =============================================================================

## Handle the RUMORS topic - offer bounties or process turn-ins
func _handle_bounty_topic() -> void:
	if not current_npc or not current_context:
		return

	var npc_id := _get_npc_id(current_npc)
	var npc_name := current_context.npc_name

	# Check if player can turn in a bounty to this NPC
	if BountyManager and BountyManager.can_turn_in_bounty(npc_id):
		var bounty: BountyManager.Bounty = BountyManager.get_turnin_bounty(npc_id)
		if bounty:
			# Turn in the bounty
			var turnin_text: String = BountyManager.get_turnin_text(bounty)
			BountyManager.turn_in_bounty(bounty.id)

			# Create and deliver response
			var response := ConversationResponse.new()
			response.response_id = "bounty_turnin_" + bounty.id
			response.text = turnin_text
			response.topic_type = ConversationTopic.TopicType.RUMORS
			response_delivered.emit(response, current_context)
			return

	# Generate or retrieve a bounty offer
	if BountyManager:
		var bounty: BountyManager.Bounty = BountyManager.generate_bounty_for_npc(npc_id, npc_name)
		if bounty and not bounty.is_accepted:
			var offer_text: String = BountyManager.get_bounty_offer_text(bounty)

			# Create and deliver response with accept action
			var response := ConversationResponse.new()
			response.response_id = "bounty_offer_" + bounty.id
			response.text = offer_text
			response.topic_type = ConversationTopic.TopicType.RUMORS

			# Store bounty ID in context for acceptance
			current_context.pending_bounty_id = bounty.id

			response_delivered.emit(response, current_context)
			return

	# Fallback - no bounty available
	var response := ConversationResponse.new()
	response.response_id = "no_work_available"
	response.text = "Haven't heard anything interesting lately. Check back another time."
	response.topic_type = ConversationTopic.TopicType.RUMORS
	response_delivered.emit(response, current_context)


## Accept the pending bounty offer
func accept_pending_bounty() -> bool:
	if not current_context or current_context.pending_bounty_id.is_empty():
		return false

	if BountyManager:
		var success := BountyManager.accept_bounty(current_context.pending_bounty_id)
		if success:
			current_context.pending_bounty_id = ""
			return true

	return false


## Decline the pending bounty offer
func decline_pending_bounty() -> void:
	if current_context:
		current_context.pending_bounty_id = ""


# =============================================================================
# INTERNAL HELPERS
# =============================================================================

## Get unique ID for an NPC
func _get_npc_id(npc: Node) -> String:
	if not npc:
		return ""

	# Try to get ID from various sources
	if npc.has_method("get_npc_id"):
		return npc.get_npc_id()
	if "npc_id" in npc:
		return npc.npc_id
	if "unique_id" in npc:
		return npc.unique_id
	# Fall back to node name
	return npc.name


## Get memory key for NPC + response combination
func _get_memory_key(npc_id: String, response_id: String) -> String:
	return npc_id + ":" + response_id


## Populate location context from current scene/area
func _populate_location_context(context: ConversationContext) -> void:
	# Try to get town/region info from SceneManager or current scene
	# This can be extended based on how zones are tracked in the game
	context.town_name = "the area"
	context.region_name = "these lands"

	# Get time of day from GameManager
	context.time_of_day = GameManager.get_time_of_day_name().to_lower()

	# Get weather from GameManager
	match GameManager.current_weather:
		Enums.Weather.CLEAR:
			context.weather = "clear"
		Enums.Weather.CLOUDY:
			context.weather = "cloudy"
		Enums.Weather.RAIN:
			context.weather = "rainy"
		Enums.Weather.STORM:
			context.weather = "stormy"
		Enums.Weather.SNOW:
			context.weather = "snowy"
		Enums.Weather.FOG:
			context.weather = "foggy"

	# Get player name
	if GameManager.player_data:
		context.player_name = GameManager.player_data.character_name


## Filter responses based on disposition, knowledge, and other criteria
func _filter_responses(responses: Array, profile: NPCKnowledgeProfile, disposition: int) -> Array:
	var filtered: Array = []

	for response: Variant in responses:
		if not response is ConversationResponse:
			continue

		var resp: ConversationResponse = response

		# Check disposition requirements
		if disposition < resp.min_disposition or disposition > resp.max_disposition:
			continue

		# Check knowledge requirements
		if not _check_knowledge_requirements(resp, profile):
			continue

		# Check condition requirements
		if not _check_conditions(resp):
			continue

		# Check if already discussed (skip repeated responses)
		if current_context and resp.was_already_said(current_context.discussed_responses):
			continue

		filtered.append(resp)

	return filtered


## Check if NPC has required knowledge for response
func _check_knowledge_requirements(response: ConversationResponse, profile: NPCKnowledgeProfile) -> bool:
	# If no profile, allow responses that don't require specific knowledge
	if not profile:
		return response.required_knowledge.is_empty()

	# Check required knowledge tags
	for tag: String in response.required_knowledge:
		if not profile.has_knowledge(tag):
			return false

	return true


## Check condition requirements (flags, quests, etc.)
func _check_conditions(response: ConversationResponse) -> bool:
	# Check conditions array if present
	for condition: DialogueCondition in response.conditions:
		if not DialogueManager.evaluate_condition(condition):
			return false

	return true


## Select response using weighted random based on personality affinity
func _weighted_select(responses: Array, profile: NPCKnowledgeProfile) -> ConversationResponse:
	if responses.is_empty():
		return null

	if responses.size() == 1:
		return responses[0]

	# Calculate weights based on personality affinity
	var weights: Array[float] = []
	var total_weight: float = 0.0

	for response: Variant in responses:
		var resp: ConversationResponse = response
		var weight: float = resp.get_selection_weight(profile)

		weights.append(weight)
		total_weight += weight

	# Weighted random selection
	var roll := randf() * total_weight
	var cumulative: float = 0.0

	for i in range(responses.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return responses[i]

	# Fallback to last response
	return responses[responses.size() - 1]
