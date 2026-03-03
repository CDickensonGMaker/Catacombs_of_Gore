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

## Emitted when farewell is delivered (before conversation actually ends)
signal farewell_delivered(farewell_text: String)

## Emitted when a persuasion attempt is made
signal persuasion_performed(action: String, success: bool, disposition_change: int, roll_data: Dictionary)

## Emitted when a skill check is performed in dialogue
signal skill_check_performed(skill: int, dc: int, success: bool, roll_data: Dictionary)

## Emitted when a topic is unlocked (Morrowind-style topic discovery)
signal topic_unlocked(topic_id: String)

## Emitted when a scripted line is shown
signal scripted_line_shown(line: Dictionary, index: int)

## Emitted when scripted dialogue ends
signal scripted_dialogue_ended()


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

## Conversation flags (persisted via SaveManager)
## These track dialogue-specific state like "talked_to_npc_about_quest"
## Migrated from DialogueManager for centralized flag management
var conversation_flags: Dictionary = {}

## Quest turn-in response variants by archetype
## Format: archetype_key -> Array[String]
var quest_turnin_responses: Dictionary = {}

## Player's discovered topics (Morrowind-style topic discovery)
## Topics are unlocked by hearing certain responses and can then be asked to other NPCs
var player_known_topics: Array[String] = []

## Context variables for placeholder substitution in flag names
## Example: {"merchant_id": "blacksmith_01"} allows flags like "{merchant_id}:befriend"
var context_variables: Dictionary = {}

## Scripted dialogue state
var is_scripted_mode: bool = false
var scripted_lines: Array[Dictionary] = []  # Array of ScriptedLine dictionaries
var scripted_current_index: int = 0
var scripted_callback: Callable  # Called when scripted dialogue ends

## Greeting responses (separate from standard topic pools)
## These are shown at conversation start based on disposition
var greeting_pool: Array[ConversationResponse] = []

## Farewell responses (separate from standard topic pools)
## These are shown when player selects GOODBYE
var farewell_pool: Array[ConversationResponse] = []


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

	# Connect to scene manager to clear node references before scene changes
	if SceneManager:
		SceneManager.scene_load_started.connect(_on_scene_load_started)


## Called when a scene change begins - clear all node references to prevent stale casts
func _on_scene_load_started(_scene_path: String) -> void:
	_clear_node_references()


## Clear all node references to prevent "Trying to cast a freed object" errors
## Called at the START of scene transitions, before the old scene is freed
func _clear_node_references() -> void:
	# End any active conversation first
	if is_active:
		# Don't emit signals during cleanup to avoid accessing freed objects
		is_active = false
		is_scripted_mode = false

	current_npc = null
	current_context = null
	scripted_lines.clear()
	scripted_current_index = 0
	scripted_callback = Callable()
	context_variables.clear()


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
	var pool_id: String = pool_data.get("pool_id", "")
	var count := 0

	# Load quest turn-in response variants if present (quests.json)
	if pool_id == "quests" and pool_data.has("quest_turnin_responses"):
		var turnin_data: Dictionary = pool_data.get("quest_turnin_responses", {})
		for archetype_key: String in turnin_data:
			var variants: Array = turnin_data[archetype_key]
			quest_turnin_responses[archetype_key] = []
			for variant: Variant in variants:
				quest_turnin_responses[archetype_key].append(str(variant))
		print("ConversationSystem: Loaded %d quest turn-in archetype variants" % quest_turnin_responses.size())

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

		# Route greetings and farewells to their separate pools
		if pool_id == "greetings":
			greeting_pool.append(response)
		elif pool_id == "farewells":
			farewell_pool.append(response)
		else:
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

	# Play NPC greeting bark sound (gender-matched)
	if AudioManager:
		var is_female: bool = false
		if "is_female" in npc:
			is_female = npc.is_female
		elif npc_name.begins_with("Lady") or npc_name.begins_with("Sister") or npc_name.contains("ella") or npc_name.contains("ina"):
			is_female = true
		var npc_pos: Vector3 = npc.global_position if npc is Node3D else Vector3.ZERO
		AudioManager.play_npc_bark(is_female, npc_pos, -5.0)

	return true


## End the current conversation
func end_conversation() -> void:
	# If in scripted mode, use the scripted dialogue end instead
	if is_scripted_mode:
		_end_scripted_dialogue()
		return

	if not is_active:
		return

	# Store reference before clearing (check validity before emitting signal)
	var finished_npc: Node = current_npc if is_instance_valid(current_npc) else null

	# Clear state
	current_context = null
	current_npc = null
	is_active = false

	# Resume game
	GameManager.end_dialogue()

	# Emit signal (finished_npc may be null if it was freed)
	conversation_ended.emit(finished_npc)


## Get available topics for an NPC based on their knowledge profile
## Topics are filtered by archetype:
##   - Guards: DIRECTIONS + GOODBYE only (they're on duty)
##   - Merchants/Innkeepers: All standard topics + TRADE
##   - Others: Standard topics based on profile
func get_available_topics(profile: NPCKnowledgeProfile) -> Array[ConversationTopic.TopicType]:
	var topics: Array[ConversationTopic.TopicType] = []

	# Guards have restricted topics (they're on duty, not here to chat)
	if profile and profile.archetype == NPCKnowledgeProfile.Archetype.GUARD:
		topics.append(ConversationTopic.TopicType.DIRECTIONS)
		topics.append(ConversationTopic.TopicType.GOODBYE)
		return topics

	# Standard topics for most NPCs
	topics.append(ConversationTopic.TopicType.LOCAL_NEWS)  # What's happening here?
	topics.append(ConversationTopic.TopicType.PERSONAL)     # About the NPC

	# RUMORS topic only for NPCs with the "rumors" knowledge tag
	if profile and profile.knowledge_tags.has("rumors"):
		topics.append(ConversationTopic.TopicType.RUMORS)

	# DIRECTIONS available to most NPCs (they know the area)
	if profile and profile.has_knowledge("local_area"):
		topics.append(ConversationTopic.TopicType.DIRECTIONS)

	# TRADE topic for merchants, innkeepers, and blacksmiths
	if profile and profile.archetype in [
		NPCKnowledgeProfile.Archetype.MERCHANT,
		NPCKnowledgeProfile.Archetype.INNKEEPER,
		NPCKnowledgeProfile.Archetype.BLACKSMITH
	]:
		topics.append(ConversationTopic.TopicType.TRADE)

	# Also add TRADE if NPC is in merchants group
	if is_instance_valid(current_npc) and current_npc.is_in_group("merchants"):
		if ConversationTopic.TopicType.TRADE not in topics:
			topics.append(ConversationTopic.TopicType.TRADE)

	# Add QUESTS topic if this NPC has quests to give or receive
	if is_instance_valid(current_npc) and _npc_has_quests(current_npc):
		topics.append(ConversationTopic.TopicType.QUESTS)

	# GOODBYE is always last
	topics.append(ConversationTopic.TopicType.GOODBYE)

	return topics


## Get location-aware custom topics from WorldLexicon based on NPC knowledge
## Returns topics for nearby regions, settlements, and creatures the NPC knows about
func get_location_custom_topics(profile: NPCKnowledgeProfile) -> Array[Dictionary]:
	var topics: Array[Dictionary] = []

	if not profile:
		return topics

	# Get current settlement from PlayerGPS
	var settlement_id: String = ""
	if PlayerGPS and not PlayerGPS.current_location_id.is_empty():
		# Map location_id to WorldLexicon settlement format
		# WorldLexicon uses "village_elder_moor", PlayerGPS uses "elder_moor"
		var location_id: String = PlayerGPS.current_location_id
		for key: String in WorldLexicon.SETTLEMENTS.keys():
			if key.ends_with(location_id) or key.contains(location_id):
				settlement_id = key
				break

	# If we found a settlement, add nearby region topics
	if not settlement_id.is_empty() and WorldLexicon.SETTLEMENTS.has(settlement_id):
		var settlement_data: Dictionary = WorldLexicon.SETTLEMENTS[settlement_id]
		var nearby_regions: Array = settlement_data.get("nearby_regions", [])

		# Add topics for regions the NPC knows about
		for region_id: String in nearby_regions:
			if not WorldLexicon.REGIONS.has(region_id):
				continue

			var region_data: Dictionary = WorldLexicon.REGIONS[region_id]
			var region_name: String = region_data.get("name", region_id)

			# Check if NPC has knowledge to discuss this region
			var can_discuss: bool = false
			if profile.has_knowledge("local_area"):
				can_discuss = true
			elif profile.has_knowledge("wilderness") and region_id != settlement_data.get("region", ""):
				can_discuss = true
			elif profile.has_knowledge("creatures"):
				can_discuss = true

			if can_discuss:
				# Get a direction hint for this region
				var directions: Array = region_data.get("directions", [])
				var direction_hint: String = directions[randi() % directions.size()] if not directions.is_empty() else "Somewhere in the wilds."

				# Get creature info for this region
				var creatures: Array = region_data.get("creatures", [])
				var creature_names: Array[String] = []
				for creature_id: String in creatures:
					creature_names.append(WorldLexicon.get_creature_display(creature_id))

				var creature_text: String = ""
				if not creature_names.is_empty():
					creature_text = " You might encounter %s there." % ", ".join(creature_names.slice(0, 2))

				topics.append({
					"id": "region_" + region_id,
					"display_text": region_name,
					"text": region_name,
					"type": ConversationTopic.TopicType.DIRECTIONS,
					"response": "%s%s" % [direction_hint, creature_text],
					"is_location_topic": true
				})

	return topics


## Select a custom topic (defined by NPC profile)
func select_custom_topic(custom_id: String, topic_data: Dictionary) -> void:
	if not is_active or not current_context:
		push_warning("ConversationSystem: No active conversation for custom topic")
		return

	# Emit topic selected signal with the base type
	var base_type: ConversationTopic.TopicType = topic_data.get("type", ConversationTopic.TopicType.PERSONAL)
	topic_selected.emit(base_type)

	# Check if NPC has a custom handler for this topic
	if is_instance_valid(current_npc) and current_npc.has_method("handle_custom_topic"):
		var handled: bool = current_npc.handle_custom_topic(custom_id, topic_data)
		if handled:
			return

	# Fallback - deliver a generic response
	var response := ConversationResponse.new()
	response.response_id = "custom_" + custom_id
	response.text = topic_data.get("response", "I don't have much to say about that.")
	response.topic_type = base_type
	response_delivered.emit(response, current_context)


## Check if NPC has quests to offer, complete, or is a turn-in target
## NOTE: QUESTS topic is restricted to designated quest sources to prevent "task bloat":
##   - NPCs in "quest_givers" group (main story NPCs, dedicated quest givers)
##   - Bounty boards, Guilds, Temples
func _npc_has_quests(npc: Node) -> bool:
	# DESIGN CONSTRAINT: Only show QUESTS topic for designated quest sources
	# This prevents every NPC from becoming a quest giver
	if not npc.is_in_group("quest_givers") and not npc.is_in_group("guilds") and not npc.is_in_group("temples") and not npc.is_in_group("bounty_boards"):
		return false

	var npc_id := _get_npc_id(npc)
	if npc_id.is_empty():
		return false

	# Check if NPC has quest_ids property (QuestGiver nodes)
	if "quest_ids" in npc:
		var quest_ids: Array = npc.quest_ids
		if not quest_ids.is_empty():
			return true

	# Check if any quest has this NPC as turn-in target
	if QuestManager.has_active_quest_for_npc(npc_id):
		return true

	# Check if any available quest has this NPC as giver
	if QuestManager.has_available_quest_from_npc(npc_id):
		return true

	return false


## Select a topic and get an NPC response
func select_topic(topic_type: ConversationTopic.TopicType) -> void:
	if not is_active or not current_context:
		push_warning("ConversationSystem: No active conversation")
		return

	# Handle goodbye specially - show farewell before ending
	if topic_type == ConversationTopic.TopicType.GOODBYE:
		topic_selected.emit(topic_type)
		var farewell: String = get_farewell()
		farewell_delivered.emit(farewell)
		# UI will handle showing farewell and then calling end_conversation()
		return

	# Handle RUMORS topic with bounty system
	if topic_type == ConversationTopic.TopicType.RUMORS:
		topic_selected.emit(topic_type)
		_handle_bounty_topic()
		return

	# Handle QUESTS topic with quest system
	if topic_type == ConversationTopic.TopicType.QUESTS:
		topic_selected.emit(topic_type)
		_handle_quest_topic()
		return

	# Handle TRADE topic for merchants - open their shop
	if topic_type == ConversationTopic.TopicType.TRADE:
		if current_npc and current_npc.is_in_group("merchants"):
			topic_selected.emit(topic_type)
			_handle_merchant_trade()
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
		execute_action(action)

	# Check for topic unlocks (Morrowind-style topic discovery)
	if response.unlock_topics and not response.unlock_topics.is_empty():
		for topic_id: String in response.unlock_topics:
			unlock_topic(topic_id)

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


## Get a greeting based on current context (disposition, personality, time)
## Called at conversation start to select an appropriate greeting from the pool
func get_greeting() -> String:
	if not current_context:
		return "Greetings."

	var profile: NPCKnowledgeProfile = current_context.npc_profile
	var disposition: int = current_context.disposition

	# Filter greetings by disposition
	var filtered := _filter_responses(greeting_pool, profile, disposition)
	if filtered.is_empty():
		# Fallback if no matching greeting
		return _get_fallback_greeting(disposition)

	# Select using weighted random with personality matching
	var selected: ConversationResponse = _weighted_select(filtered, profile)
	if selected:
		# Inject context variables into greeting text
		return current_context.inject_variables(selected.text)

	return _get_fallback_greeting(disposition)


## Fallback greeting when pool is empty or no match
func _get_fallback_greeting(disposition: int) -> String:
	if disposition >= 75:
		return "Well met, friend! What can I do for you?"
	elif disposition >= 50:
		return "Greetings. What brings you here?"
	elif disposition >= 25:
		return "What do you want?"
	else:
		return "Make it quick."


## Get a farewell based on current context (disposition, personality)
## Called when player selects GOODBYE to show a proper sendoff
func get_farewell() -> String:
	if not current_context:
		return "Farewell."

	var profile: NPCKnowledgeProfile = current_context.npc_profile
	var disposition: int = current_context.disposition

	# Filter farewells by disposition
	var filtered := _filter_responses(farewell_pool, profile, disposition)
	if filtered.is_empty():
		# Fallback if no matching farewell
		return _get_fallback_farewell(disposition)

	# Select using weighted random with personality matching
	var selected: ConversationResponse = _weighted_select(filtered, profile)
	if selected:
		# Inject context variables into farewell text
		return current_context.inject_variables(selected.text)

	return _get_fallback_farewell(disposition)


## Fallback farewell when pool is empty or no match
func _get_fallback_farewell(disposition: int) -> String:
	if disposition >= 75:
		return "Farewell, friend. Safe travels!"
	elif disposition >= 50:
		return "Until next time."
	elif disposition >= 25:
		return "Be on your way."
	else:
		return "Good riddance."


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
	var value: Variant = get_flag(flag_key, null)

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
	set_flag(flag_key, new_value)


## Set disposition to a specific value
func set_disposition(npc_id: String, value: int) -> void:
	var clamped := clampi(value, MIN_DISPOSITION, MAX_DISPOSITION)
	var flag_key := "disposition:" + npc_id
	set_flag(flag_key, clamped)


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
# FLAG MANAGEMENT
# =============================================================================

## Substitute context variables in a string
## Replaces {variable_name} patterns with values from context_variables
## Example: "{merchant_id}:befriend" with context {"merchant_id": "blacksmith"} -> "blacksmith:befriend"
func _substitute_context_variables(text: String) -> String:
	var result := text
	for key in context_variables:
		var placeholder := "{%s}" % key
		if result.contains(placeholder):
			result = result.replace(placeholder, str(context_variables[key]))
	return result


## Set a conversation flag (supports context variable substitution)
func set_flag(flag_name: String, value: Variant = true) -> void:
	var resolved_name := _substitute_context_variables(flag_name)
	conversation_flags[resolved_name] = value


## Clear a conversation flag (supports context variable substitution)
func clear_flag(flag_name: String) -> void:
	var resolved_name := _substitute_context_variables(flag_name)
	if conversation_flags.has(resolved_name):
		conversation_flags.erase(resolved_name)


## Check if a flag is set (supports context variable substitution)
func has_flag(flag_name: String) -> bool:
	var resolved_name := _substitute_context_variables(flag_name)
	return conversation_flags.has(resolved_name)


## Get a flag value (supports context variable substitution)
func get_flag(flag_name: String, default: Variant = null) -> Variant:
	var resolved_name := _substitute_context_variables(flag_name)
	return conversation_flags.get(resolved_name, default)


## Set context variables for flag substitution
func set_context_variables(variables: Dictionary) -> void:
	context_variables = variables.duplicate()


## Clear context variables
func clear_context_variables() -> void:
	context_variables.clear()


## Check and clear a pending shop flag (returns shop ID or empty string)
func pop_pending_shop() -> String:
	var shop_id := ""
	for key in conversation_flags.keys():
		if key.begins_with("_pending_shop:"):
			shop_id = key.substr(len("_pending_shop:"))
			conversation_flags.erase(key)
			break
	return shop_id


# =============================================================================
# TOPIC DISCOVERY (Morrowind-style)
# =============================================================================

## Unlock a topic for the player (can now be asked to other NPCs)
func unlock_topic(topic_id: String) -> void:
	if topic_id.is_empty():
		return
	if topic_id not in player_known_topics:
		player_known_topics.append(topic_id)
		topic_unlocked.emit(topic_id)
		print("[ConversationSystem] Topic unlocked: %s" % topic_id)


## Check if player knows a topic
func has_topic(topic_id: String) -> bool:
	return topic_id in player_known_topics


## Get all known topics
func get_known_topics() -> Array[String]:
	return player_known_topics.duplicate()


## Check if a custom topic should be available (based on discovery)
## Returns true if topic doesn't require discovery OR if player has discovered it
func is_topic_available(topic_id: String, requires_discovery: bool = false) -> bool:
	if not requires_discovery:
		return true
	return has_topic(topic_id)


## Clear all known topics (for new game)
func clear_known_topics() -> void:
	player_known_topics.clear()


# =============================================================================
# SAVE/LOAD
# =============================================================================

## Serialize conversation state for saving
func to_dict() -> Dictionary:
	return {
		"npc_memory": npc_memory.duplicate(),
		"conversation_flags": conversation_flags.duplicate(),
		"player_known_topics": player_known_topics.duplicate()
	}


## Deserialize conversation state from save
func from_dict(data: Dictionary) -> void:
	npc_memory = data.get("npc_memory", {}).duplicate()
	conversation_flags = data.get("conversation_flags", {}).duplicate()
	# Load known topics (convert to typed array)
	var topics_data: Array = data.get("player_known_topics", [])
	player_known_topics.clear()
	for topic: Variant in topics_data:
		if topic is String:
			player_known_topics.append(topic)


## Reset state for new game
func reset_for_new_game() -> void:
	# End any active conversation
	if is_active:
		end_conversation()

	# Clear memory, flags, and known topics
	npc_memory.clear()
	conversation_flags.clear()
	context_variables.clear()
	player_known_topics.clear()


# =============================================================================
# SCRIPTED DIALOGUE MODE
# =============================================================================

## Create a scripted line dictionary
## speaker: Name of the speaker (empty for NPC, "Player" for player lines)
## text: The dialogue text
## choices: Array of choice dictionaries [{text, next_index, actions}] (optional)
## is_end: If true, this line ends the dialogue
static func create_scripted_line(speaker: String, text: String, choices: Array = [], is_end: bool = false) -> Dictionary:
	return {
		"speaker": speaker,
		"text": text,
		"choices": choices,
		"is_end": is_end
	}


## Create a scripted choice dictionary
## text: Display text for the choice
## next_index: Index of the next line to jump to (-1 for end)
## actions: Array of action dictionaries to execute (optional)
static func create_scripted_choice(text: String, next_index: int, actions: Array = []) -> Dictionary:
	return {
		"text": text,
		"next_index": next_index,
		"actions": actions
	}


## Start a scripted dialogue sequence
## lines: Array of ScriptedLine dictionaries
## callback: Optional callable to run when dialogue ends
func start_scripted_dialogue(lines: Array, callback: Callable = Callable()) -> void:
	# Guard against re-entry - if already active, ignore
	if is_active or is_scripted_mode:
		push_warning("ConversationSystem: start_scripted_dialogue called while already in dialogue (is_active=%s, is_scripted_mode=%s)" % [is_active, is_scripted_mode])
		return

	if lines.is_empty():
		push_warning("ConversationSystem: Cannot start scripted dialogue with no lines")
		return

	# Set flags FIRST before any other operations to prevent re-entry
	is_active = true
	is_scripted_mode = true

	scripted_lines.clear()
	for line: Variant in lines:
		if line is Dictionary:
			scripted_lines.append(line)
	scripted_current_index = 0
	scripted_callback = callback

	# Pause game
	GameManager.start_dialogue()

	# Show the first line
	_show_scripted_line(0)


## Show a specific scripted line
func _show_scripted_line(index: int) -> void:
	if index < 0 or index >= scripted_lines.size():
		_end_scripted_dialogue()
		return

	scripted_current_index = index
	var line: Dictionary = scripted_lines[index]

	# Emit signal for UI to display
	scripted_line_shown.emit(line, index)


## Handle player selecting a choice in scripted dialogue
func select_scripted_choice(choice_index: int) -> void:
	if not is_scripted_mode:
		return

	var current_line: Dictionary = scripted_lines[scripted_current_index]
	var choices: Array = current_line.get("choices", [])

	if choice_index < 0 or choice_index >= choices.size():
		# No valid choice, try to continue or end
		if current_line.get("is_end", false):
			_end_scripted_dialogue()
		else:
			# Auto-advance to next line
			_show_scripted_line(scripted_current_index + 1)
		return

	var choice: Dictionary = choices[choice_index]

	# Execute any actions attached to the choice
	var actions: Array = choice.get("actions", [])
	for action_data: Variant in actions:
		if action_data is Dictionary:
			_execute_scripted_action(action_data)

	# Navigate to next line
	var next_index: int = choice.get("next_index", -1)
	if next_index < 0:
		_end_scripted_dialogue()
	else:
		_show_scripted_line(next_index)


## Continue scripted dialogue (for lines without choices)
func continue_scripted_dialogue() -> void:
	if not is_scripted_mode:
		return

	var current_line: Dictionary = scripted_lines[scripted_current_index]

	if current_line.get("is_end", false):
		_end_scripted_dialogue()
	elif current_line.get("choices", []).is_empty():
		# Auto-advance to next line
		_show_scripted_line(scripted_current_index + 1)


## End the scripted dialogue
func _end_scripted_dialogue() -> void:
	is_scripted_mode = false
	scripted_lines.clear()
	scripted_current_index = 0
	is_active = false

	GameManager.end_dialogue()

	# Call the callback if provided
	if scripted_callback.is_valid():
		scripted_callback.call()
		scripted_callback = Callable()

	scripted_dialogue_ended.emit()


## Public method to end scripted dialogue (for escape key, etc.)
func end_scripted_dialogue() -> void:
	if is_scripted_mode:
		_end_scripted_dialogue()


## Execute an action from scripted dialogue
func _execute_scripted_action(action_data: Dictionary) -> void:
	var action_type: String = action_data.get("type", "")

	match action_type:
		"set_flag":
			var flag_name: String = action_data.get("flag", "")
			var value: Variant = action_data.get("value", true)
			if not flag_name.is_empty():
				set_flag(flag_name, value)

		"clear_flag":
			var flag_name: String = action_data.get("flag", "")
			if not flag_name.is_empty():
				clear_flag(flag_name)

		"give_gold":
			var amount: int = action_data.get("amount", 0)
			if amount > 0 and InventoryManager:
				InventoryManager.add_gold(amount)

		"take_gold":
			var amount: int = action_data.get("amount", 0)
			if amount > 0 and InventoryManager:
				InventoryManager.remove_gold(amount)

		"give_item":
			var item_id: String = action_data.get("item_id", "")
			var quantity: int = action_data.get("quantity", 1)
			if not item_id.is_empty() and InventoryManager:
				InventoryManager.add_item(item_id, quantity)

		"take_item":
			var item_id: String = action_data.get("item_id", "")
			var quantity: int = action_data.get("quantity", 1)
			if not item_id.is_empty() and InventoryManager:
				InventoryManager.remove_item(item_id, quantity)

		"start_quest":
			var quest_id: String = action_data.get("quest_id", "")
			if not quest_id.is_empty():
				QuestManager.start_quest(quest_id)

		"complete_quest":
			var quest_id: String = action_data.get("quest_id", "")
			if not quest_id.is_empty():
				QuestManager.complete_quest(quest_id)

		"modify_disposition":
			var npc_id: String = action_data.get("npc_id", "")
			var delta: int = action_data.get("delta", 0)
			if not npc_id.is_empty():
				modify_disposition(npc_id, delta)

		"turn_hostile":
			# Make the current NPC hostile
			if is_instance_valid(current_npc) and current_npc.has_method("turn_hostile"):
				current_npc.turn_hostile()

		"arrest":
			# Handle arrest logic - this would be NPC-specific
			if is_instance_valid(current_npc) and current_npc.has_method("arrest_player"):
				current_npc.arrest_player()


# =============================================================================
# BOUNTY HANDLING
# =============================================================================

## Handle the RUMORS topic - offer bounties or process turn-ins
func _handle_bounty_topic() -> void:
	if not is_instance_valid(current_npc) or not current_context:
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


## Handle QUESTS topic - quest offers and turn-ins
func _handle_quest_topic() -> void:
	if not is_instance_valid(current_npc) or not current_context:
		return

	var npc_id := _get_npc_id(current_npc)
	var npc_name := current_context.npc_name

	# Priority 0: Check for incomplete "talk" objectives targeting this NPC
	# This shows an explicit dialogue option for objectives like "Deliver message to Elder Vorn"
	var talk_objectives: Array[Dictionary] = _get_incomplete_talk_objectives_for_npc(npc_id)
	if not talk_objectives.is_empty():
		var obj_info: Dictionary = talk_objectives[0]  # Handle first matching objective
		current_context.pending_talk_objective = obj_info
		_show_talk_objective_dialogue(obj_info)
		return

	# Priority 1: Check if player can complete/turn-in a quest to this NPC
	# NOTE: We do NOT auto-complete here. Instead, we show a message and add
	# a "Turn in [Quest Name]" choice to the topic menu. The player must
	# explicitly select that option to complete the quest.
	var completable_quest := QuestManager.get_completable_quest_for_npc(npc_id)
	if completable_quest:
		var quest_title: String = completable_quest.title
		var quest_data: Dictionary = QuestManager.get_quest_data(completable_quest.id)
		var next_quest_id: String = quest_data.get("next_quest", "")

		# Store the pending turn-in info (do NOT complete yet)
		current_context.pending_quest_turnin = {
			"quest_id": completable_quest.id,
			"quest_title": quest_title,
			"next_quest_id": next_quest_id
		}

		# Show a message indicating the quest is ready to turn in
		# The UI will add a "Turn in [Quest Name]" option to the topic menu
		var response := ConversationResponse.new()
		response.response_id = "quest_ready_" + completable_quest.id
		response.text = "Ah, you've completed the task. Select 'Turn in: %s' when you're ready to collect your reward." % quest_title
		response.topic_type = ConversationTopic.TopicType.QUESTS
		response_delivered.emit(response, current_context)
		return

	# Priority 2: Check if NPC has quests to offer
	var quest_ids: Array = []
	if "quest_ids" in current_npc:
		quest_ids = current_npc.quest_ids

	# Find first available quest from this NPC's list
	for quest_id in quest_ids:
		if QuestManager.is_quest_available(quest_id):
			var quest := QuestManager.get_quest_data(quest_id)
			if quest:
				var offer_text := _get_quest_offer_text(quest)

				var response := ConversationResponse.new()
				response.response_id = "quest_offer_" + quest_id
				response.text = offer_text
				response.topic_type = ConversationTopic.TopicType.QUESTS

				# Store quest ID for acceptance
				current_context.pending_quest_id = quest_id

				response_delivered.emit(response, current_context)
				return

	# Priority 3: Check for active quests from this NPC (progress update)
	for quest_id in quest_ids:
		if QuestManager.is_quest_active(quest_id):
			var quest := QuestManager.get_quest(quest_id)
			if quest:
				var progress_text := "You're still working on the task.\n\n[%s - In Progress]" % quest.title

				var response := ConversationResponse.new()
				response.response_id = "quest_progress_" + quest_id
				response.text = progress_text
				response.topic_type = ConversationTopic.TopicType.QUESTS
				response_delivered.emit(response, current_context)
				return

	# Fallback - no quests available
	var response := ConversationResponse.new()
	response.response_id = "no_quests_available"
	response.text = "I don't have any tasks for you right now."
	response.topic_type = ConversationTopic.TopicType.QUESTS
	response_delivered.emit(response, current_context)


## Get formatted quest offer text
func _get_quest_offer_text(quest_data: Dictionary) -> String:
	var title: String = quest_data.get("title", "Unknown Quest")
	var description: String = quest_data.get("description", "A task awaits.")
	var rewards: Dictionary = quest_data.get("rewards", {})

	var text := "%s\n\n%s" % [title, description]

	# Add reward info
	var reward_parts: Array[String] = []
	if rewards.get("gold", 0) > 0:
		reward_parts.append("%d gold" % rewards.gold)
	if rewards.get("xp", 0) > 0:
		reward_parts.append("%d XP" % rewards.xp)

	if not reward_parts.is_empty():
		text += "\n\n[Rewards: %s]" % ", ".join(reward_parts)

	return text


## Get personality-matched turn-in response based on NPC archetype
func _get_turnin_response(profile: NPCKnowledgeProfile, quest_title: String) -> String:
	var archetype_key := "default"

	# Map archetype enum to JSON key
	if profile:
		match profile.archetype:
			NPCKnowledgeProfile.Archetype.MERCHANT:
				archetype_key = "merchant"
			NPCKnowledgeProfile.Archetype.GUARD:
				archetype_key = "guard"
			NPCKnowledgeProfile.Archetype.SCHOLAR:
				archetype_key = "scholar"
			NPCKnowledgeProfile.Archetype.PRIEST:
				archetype_key = "priest"
			NPCKnowledgeProfile.Archetype.INNKEEPER:
				archetype_key = "innkeeper"
			NPCKnowledgeProfile.Archetype.FARMER, NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER:
				archetype_key = "farmer"

	# Get variants for this archetype (fall back to default)
	var variants: Array = quest_turnin_responses.get(archetype_key, [])
	if variants.is_empty():
		variants = quest_turnin_responses.get("default", [])
	if variants.is_empty():
		return "Quest complete.\n\n[Quest Complete: %s]" % quest_title

	# Pick a random variant
	var base_text: String = variants[randi() % variants.size()]

	# Append quest completion notice
	return "%s\n\n[Quest Complete: %s]" % [base_text, quest_title]


## Accept the pending quest offer
func accept_pending_quest() -> bool:
	if not current_context or current_context.pending_quest_id.is_empty():
		return false

	var quest_id: String = current_context.pending_quest_id
	if QuestManager.start_quest(quest_id):
		current_context.pending_quest_id = ""

		# Notify player talked to this NPC (for "talk" objectives)
		var npc_id := _get_npc_id(current_npc)
		QuestManager.on_npc_talked(npc_id)

		return true

	return false


## Decline the pending quest offer
func decline_pending_quest() -> void:
	if current_context:
		current_context.pending_quest_id = ""


## Complete the pending quest turn-in (called when player selects "Turn in [Quest]")
## This is the deliberate dialogue action that completes the quest and gives rewards
func complete_pending_quest_turnin() -> bool:
	if not current_context or current_context.pending_quest_turnin.is_empty():
		return false

	var turnin_info: Dictionary = current_context.pending_quest_turnin
	var quest_id: String = turnin_info.get("quest_id", "")
	var quest_title: String = turnin_info.get("quest_title", "")
	var next_quest_id: String = turnin_info.get("next_quest_id", "")

	if quest_id.is_empty():
		return false

	# Complete the quest (rewards given automatically by QuestManager)
	QuestManager.complete_quest(quest_id)

	# Clear the pending turn-in
	current_context.pending_quest_turnin = {}

	# Get personality-matched turn-in response
	var turnin_text := _get_turnin_response(current_context.npc_profile, quest_title)

	var response := ConversationResponse.new()
	response.response_id = "quest_complete_" + quest_id
	response.text = turnin_text
	response.topic_type = ConversationTopic.TopicType.QUESTS
	response_delivered.emit(response, current_context)

	# Check for next_quest in chain and offer it
	if not next_quest_id.is_empty() and QuestManager.is_quest_available(next_quest_id):
		current_context.pending_quest_id = next_quest_id
		# The UI should show an "Accept Next Quest" option

	return true


## Check if there's a pending quest turn-in available
func has_pending_quest_turnin() -> bool:
	if not current_context:
		return false
	return not current_context.pending_quest_turnin.is_empty()


## Get the pending quest turn-in info for UI display
func get_pending_quest_turnin_info() -> Dictionary:
	if not current_context:
		return {}
	return current_context.pending_quest_turnin


## Handle TRADE topic for merchant/innkeeper NPCs - opens their shop or inn menu
func _handle_merchant_trade() -> void:
	if not is_instance_valid(current_npc):
		return

	# Store reference to merchant/innkeeper before ending conversation
	var npc: Node = current_npc

	# End conversation first
	end_conversation()

	# Small delay to let conversation UI close, then open shop/inn
	await get_tree().create_timer(0.1).timeout

	if not is_instance_valid(npc):
		return

	# Check for innkeeper-specific method first
	if npc.has_method("_open_inn_menu"):
		npc._open_inn_menu()
	# Then check for shop UI (merchants, blacksmiths)
	elif npc.has_method("_open_shop_ui"):
		npc._open_shop_ui()
	# Fallback - check if NPC is in merchants group
	elif npc.is_in_group("merchants") and npc.has_method("open_shop"):
		npc.open_shop()


# =============================================================================
# TALK OBJECTIVE DIALOGUE SYSTEM
# =============================================================================

## Check if player has incomplete "talk" objectives targeting this NPC
## Returns array of dictionaries with quest/objective info for matching objectives
func _get_incomplete_talk_objectives_for_npc(npc_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for quest_id: String in QuestManager.quests:
		var quest: QuestManager.Quest = QuestManager.quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue
		for obj: QuestManager.Objective in quest.objectives:
			if obj.type == "talk" and obj.target == npc_id and not obj.is_completed:
				# Check prerequisites are met
				if QuestManager.are_prior_objectives_complete(quest, obj):
					results.append({
						"quest_id": quest_id,
						"quest_title": quest.title,
						"objective_id": obj.id,
						"objective_description": obj.description
					})
	return results


## Generate context-aware prompt text for a talk objective
func _generate_talk_objective_prompt(obj_info: Dictionary) -> String:
	var obj_desc: String = obj_info.get("objective_description", "Unknown objective")

	# Check for common patterns in objective description
	var obj_lower: String = obj_desc.to_lower()
	if "deliver" in obj_lower or "message" in obj_lower:
		return "[Complete: %s]\n\nI have something for you." % obj_desc
	elif "report" in obj_lower:
		return "[Complete: %s]\n\nI'm here to report." % obj_desc
	elif "speak" in obj_lower or "talk" in obj_lower:
		return "[Complete: %s]\n\nI need to speak with you." % obj_desc
	else:
		return "[Complete: %s]" % obj_desc


## Show dialogue prompt for completing a talk objective
func _show_talk_objective_dialogue(obj_info: Dictionary) -> void:
	var response := ConversationResponse.new()
	response.response_id = "talk_objective_" + obj_info.get("quest_id", "unknown")
	response.topic_type = ConversationTopic.TopicType.QUESTS

	# Generate context-aware prompt text
	response.text = _generate_talk_objective_prompt(obj_info)

	response_delivered.emit(response, current_context)


## Complete the pending talk objective and show NPC response
func complete_pending_talk_objective() -> void:
	if not current_context or current_context.pending_talk_objective.is_empty():
		return

	if not is_instance_valid(current_npc):
		return

	var obj_info: Dictionary = current_context.pending_talk_objective
	var npc_id: String = _get_npc_id(current_npc)

	# Complete the objective via QuestManager
	QuestManager.on_npc_talked(npc_id)

	# Clear pending
	current_context.pending_talk_objective = {}

	# Show NPC response to the completed objective
	_show_talk_objective_response(obj_info)


## Show NPC response after completing a talk objective
func _show_talk_objective_response(obj_info: Dictionary) -> void:
	var response := ConversationResponse.new()
	response.response_id = "talk_objective_response_" + obj_info.get("quest_id", "unknown")
	response.topic_type = ConversationTopic.TopicType.QUESTS

	# Get context-aware response based on objective description
	var obj_desc: String = obj_info.get("objective_description", "Unknown objective")
	var obj_lower: String = obj_desc.to_lower()

	# Select appropriate response based on keywords
	if "deliver" in obj_lower or "message" in obj_lower:
		response.text = "Ah, thank you for bringing this to me. You've done well.\n\n[Objective Complete: %s]" % obj_desc
	elif "report" in obj_lower or "news" in obj_lower or "inform" in obj_lower:
		response.text = "I see. Thank you for the report. This information is valuable.\n\n[Objective Complete: %s]" % obj_desc
	else:
		response.text = "Very good. I appreciate you taking the time to speak with me about this.\n\n[Objective Complete: %s]" % obj_desc

	response_delivered.emit(response, current_context)


# =============================================================================
# PERSUASION SYSTEM
# =============================================================================

## Persuasion action types
enum PersuasionAction {
	ADMIRE,      # Speech DC 12, success +5 to +15 disposition, fail -5
	INTIMIDATE,  # Grit+Speech DC 15, success +10 (fear-based), fail -10 may turn hostile
	BRIBE,       # Gold + Speech DC 10, success +5 to +20, fail -5 lose gold anyway
	TAUNT        # Speech DC 10, success -10 to -20 (intentional), fail no effect
}

## Perform a persuasion attempt on the current NPC
## Returns dictionary with: success, disposition_change, roll_data, turned_hostile
func perform_persuasion(action: PersuasionAction, bribe_amount: int = 0) -> Dictionary:
	if not is_active or not current_context or not is_instance_valid(current_npc):
		return {"success": false, "disposition_change": 0, "roll_data": {}, "turned_hostile": false}

	var npc_id := _get_npc_id(current_npc)
	var player_data := GameManager.player_data
	if not player_data:
		return {"success": false, "disposition_change": 0, "roll_data": {}, "turned_hostile": false}

	# Get player stats
	var speech: int = player_data.get_effective_stat(Enums.Stat.SPEECH)
	var grit: int = player_data.get_effective_stat(Enums.Stat.GRIT)
	var persuasion_skill: int = player_data.get_skill(Enums.Skill.PERSUASION)
	var intimidation_skill: int = player_data.get_skill(Enums.Skill.INTIMIDATION)

	var dc: int = 10
	var stat_to_use: int = speech
	var stat_name: String = "Speech"
	var skill_to_use: int = persuasion_skill
	var skill_name: String = "Persuasion"
	var action_name: String = ""

	# Configure based on action type
	match action:
		PersuasionAction.ADMIRE:
			dc = 12
			action_name = "ADMIRE"
		PersuasionAction.INTIMIDATE:
			dc = 15
			stat_to_use = (grit + speech) / 2  # Average of Grit and Speech
			stat_name = "Grit+Speech"
			skill_to_use = intimidation_skill
			skill_name = "Intimidation"
			action_name = "INTIMIDATE"
		PersuasionAction.BRIBE:
			dc = 10
			action_name = "BRIBE"
			# Bribe amount adds bonus to check
			if bribe_amount > 0:
				skill_to_use += bribe_amount / 10  # +1 per 10 gold
		PersuasionAction.TAUNT:
			dc = 10
			action_name = "TAUNT"

	# Make the skill check via DiceManager
	var roll_data := DiceManager.make_check(
		action_name,
		stat_to_use,
		stat_name,
		skill_to_use,
		skill_name,
		dc,
		[],
		true  # Active roll for prominent display
	)

	var success: bool = roll_data.success
	var is_crit: bool = roll_data.is_crit
	var disposition_change: int = 0
	var turned_hostile: bool = false

	# Calculate disposition change based on action and result
	match action:
		PersuasionAction.ADMIRE:
			if success:
				# Success: +5 to +15 (crit doubles it)
				disposition_change = randi_range(5, 15)
				if is_crit:
					disposition_change *= 2
			else:
				# Fail: -5
				disposition_change = -5

		PersuasionAction.INTIMIDATE:
			if success:
				# Success: +10 (fear-based, crit adds more)
				disposition_change = 10
				if is_crit:
					disposition_change = 20
			else:
				# Fail: -10, may turn hostile (20% chance)
				disposition_change = -10
				if randf() < 0.2:
					turned_hostile = true

		PersuasionAction.BRIBE:
			# Gold is lost regardless of outcome
			if bribe_amount > 0 and InventoryManager:
				InventoryManager.remove_gold(bribe_amount)
			if success:
				# Success: +5 to +20 based on bribe amount
				var base_change: int = 5 + mini(int(bribe_amount / 5), 15)  # +1 per 5 gold, max +15 bonus
				disposition_change = base_change
				if is_crit:
					disposition_change = int(disposition_change * 1.5)
			else:
				# Fail: -5 (insulted by bad bribe attempt)
				disposition_change = -5

		PersuasionAction.TAUNT:
			if success:
				# Success: -10 to -20 (intentional - for making enemies)
				disposition_change = -randi_range(10, 20)
				if is_crit:
					disposition_change = -30
			else:
				# Fail: no effect
				disposition_change = 0

	# Apply disposition change
	if disposition_change != 0:
		modify_disposition(npc_id, disposition_change)
		current_context.disposition = get_disposition(npc_id)

	# Handle hostile state
	if turned_hostile and is_instance_valid(current_npc) and current_npc.has_method("turn_hostile"):
		current_npc.turn_hostile()

	var result := {
		"success": success,
		"disposition_change": disposition_change,
		"roll_data": roll_data,
		"turned_hostile": turned_hostile,
		"action": action_name
	}

	# Emit signal
	persuasion_performed.emit(action_name, success, disposition_change, roll_data)

	return result


## Perform a skill check during dialogue
## Returns dictionary with: success, roll_data
func perform_skill_check(skill_enum: int, dc: int, context_text: String = "") -> Dictionary:
	var player_data := GameManager.player_data
	if not player_data:
		skill_check_performed.emit(skill_enum, dc, false, {})
		return {"success": false, "roll_data": {}}

	# Determine governing stat
	var governing_stat := _get_skill_governing_stat(skill_enum)
	var stat_value: int = player_data.get_effective_stat(governing_stat)
	var skill_value: int = player_data.get_skill(skill_enum)

	var stat_name := _get_stat_name(governing_stat)
	var skill_name := _get_skill_name(skill_enum)

	var title := skill_name.to_upper() + " CHECK"
	if not context_text.is_empty():
		title = context_text

	# Make the roll
	var roll_data := DiceManager.make_check(
		title,
		stat_value,
		stat_name,
		skill_value,
		skill_name,
		dc,
		[],
		true  # Active roll
	)

	skill_check_performed.emit(skill_enum, dc, roll_data.success, roll_data)

	return {
		"success": roll_data.success,
		"roll_data": roll_data
	}


## Get the governing stat for a skill (copy from DialogueManager for consistency)
func _get_skill_governing_stat(skill_enum: int) -> int:
	match skill_enum:
		Enums.Skill.MELEE, Enums.Skill.INTIMIDATION:
			return Enums.Stat.GRIT
		Enums.Skill.RANGED, Enums.Skill.DODGE, Enums.Skill.STEALTH, \
		Enums.Skill.ENDURANCE, Enums.Skill.THIEVERY, \
		Enums.Skill.ATHLETICS, Enums.Skill.LOCKPICKING:
			return Enums.Stat.AGILITY
		Enums.Skill.CONCENTRATION, Enums.Skill.RESIST, Enums.Skill.BRAVERY:
			return Enums.Stat.WILL
		Enums.Skill.PERSUASION, Enums.Skill.DECEPTION, Enums.Skill.NEGOTIATION:
			return Enums.Stat.SPEECH
		Enums.Skill.ARCANA_LORE, Enums.Skill.HISTORY, Enums.Skill.INTUITION, \
		Enums.Skill.ENGINEERING, Enums.Skill.INVESTIGATION, \
		Enums.Skill.RELIGION, Enums.Skill.NATURE, Enums.Skill.ALCHEMY, Enums.Skill.SMITHING:
			return Enums.Stat.KNOWLEDGE
		Enums.Skill.FIRST_AID, Enums.Skill.HERBALISM, Enums.Skill.SURVIVAL:
			return Enums.Stat.VITALITY
	return Enums.Stat.KNOWLEDGE


## Get stat name from enum
func _get_stat_name(stat_enum: int) -> String:
	match stat_enum:
		Enums.Stat.GRIT: return "Grit"
		Enums.Stat.AGILITY: return "Agility"
		Enums.Stat.WILL: return "Will"
		Enums.Stat.SPEECH: return "Speech"
		Enums.Stat.KNOWLEDGE: return "Knowledge"
		Enums.Stat.VITALITY: return "Vitality"
	return "Unknown"


## Get skill name from enum
func _get_skill_name(skill_enum: int) -> String:
	match skill_enum:
		Enums.Skill.MELEE: return "Melee"
		Enums.Skill.INTIMIDATION: return "Intimidation"
		Enums.Skill.RANGED: return "Ranged"
		Enums.Skill.DODGE: return "Dodge"
		Enums.Skill.STEALTH: return "Stealth"
		Enums.Skill.ENDURANCE: return "Endurance"
		Enums.Skill.THIEVERY: return "Thievery"
		Enums.Skill.ATHLETICS: return "Athletics"
		Enums.Skill.CONCENTRATION: return "Concentration"
		Enums.Skill.RESIST: return "Resist"
		Enums.Skill.BRAVERY: return "Bravery"
		Enums.Skill.PERSUASION: return "Persuasion"
		Enums.Skill.DECEPTION: return "Deception"
		Enums.Skill.NEGOTIATION: return "Negotiation"
		Enums.Skill.ARCANA_LORE: return "Arcana Lore"
		Enums.Skill.HISTORY: return "History"
		Enums.Skill.INTUITION: return "Intuition"
		Enums.Skill.ENGINEERING: return "Engineering"
		Enums.Skill.INVESTIGATION: return "Investigation"
		Enums.Skill.RELIGION: return "Religion"
		Enums.Skill.NATURE: return "Nature"
		Enums.Skill.FIRST_AID: return "First Aid"
		Enums.Skill.HERBALISM: return "Herbalism"
		Enums.Skill.SURVIVAL: return "Survival"
		Enums.Skill.ALCHEMY: return "Alchemy"
		Enums.Skill.SMITHING: return "Smithing"
		Enums.Skill.LOCKPICKING: return "Lockpicking"
	return "Unknown"


# =============================================================================
# ACTION EXECUTION
# =============================================================================

## Execute a dialogue action (migrated from DialogueManager)
## Returns the next node ID if action overrides it (skill checks), empty string otherwise
func execute_action(action: DialogueAction) -> String:
	match action.type:
		DialogueData.ActionType.NONE:
			pass

		DialogueData.ActionType.GIVE_ITEM:
			InventoryManager.add_item(action.param_string, action.param_int)

		DialogueData.ActionType.TAKE_ITEM:
			InventoryManager.remove_item(action.param_string, action.param_int)

		DialogueData.ActionType.GIVE_GOLD:
			InventoryManager.add_gold(action.param_int)

		DialogueData.ActionType.TAKE_GOLD:
			InventoryManager.remove_gold(action.param_int)

		DialogueData.ActionType.START_QUEST:
			QuestManager.start_quest(action.param_string)

		DialogueData.ActionType.COMPLETE_QUEST:
			QuestManager.complete_quest(action.param_string)

		DialogueData.ActionType.ADVANCE_QUEST:
			# Advance quest objective - param_string is "quest_id:objective_id"
			var parts := action.param_string.split(":")
			if parts.size() >= 2:
				QuestManager.update_progress(parts[1], parts[0], action.param_int)

		DialogueData.ActionType.SET_FLAG:
			set_flag(action.param_string)

		DialogueData.ActionType.CLEAR_FLAG:
			clear_flag(action.param_string)

		DialogueData.ActionType.SKILL_CHECK:
			return _execute_skill_check_action(action)

		DialogueData.ActionType.MODIFY_REPUTATION:
			# Future: modify faction reputation
			pass

		DialogueData.ActionType.GIVE_XP:
			if GameManager.player_data:
				GameManager.player_data.add_ip(action.param_int)

		DialogueData.ActionType.HEAL_PLAYER:
			if GameManager.player_data:
				GameManager.player_data.heal(action.param_int)

		DialogueData.ActionType.TELEPORT:
			# Future: teleport player to location
			pass

		DialogueData.ActionType.OPEN_SHOP:
			# Shop will be opened after dialogue ends
			# Store shop ID for scene to handle
			set_flag("_pending_shop:" + action.param_string)

		DialogueData.ActionType.PLAY_SOUND:
			AudioManager.play_ui_sound(action.param_string)

		DialogueData.ActionType.SET_NPC_STATE:
			# Future: change NPC behavior/state
			pass

		DialogueData.ActionType.SPAWN_ERRAND:
			# Legacy action - errands replaced by bounty system
			push_warning("[ConversationSystem] SPAWN_ERRAND action is deprecated. Use bounty system instead.")

	return ""


## Execute a skill check action with dice roll
## Returns the next node ID (success or failure branch)
func _execute_skill_check_action(action: DialogueAction) -> String:
	var skill_enum: int = action.param_int
	var dc: float = action.param_float

	# Get player stats
	var player_data := GameManager.player_data
	if not player_data:
		# No player data, fail the check
		skill_check_performed.emit(skill_enum, int(dc), false, {})
		return action.failure_node_id

	# Determine which stat governs this skill
	var governing_stat := _get_skill_governing_stat(skill_enum)
	var stat_value: int = player_data.get_effective_stat(governing_stat)
	var skill_value: int = player_data.get_skill(skill_enum)

	# Get names for display
	var stat_name := _get_stat_name(governing_stat)
	var skill_name := _get_skill_name(skill_enum)

	# Make the roll via DiceManager
	var roll_data := DiceManager.make_check(
		skill_name.to_upper() + " CHECK",
		stat_value,
		stat_name,
		skill_value,
		skill_name,
		int(dc),
		[],
		true  # Active roll (prominent display)
	)

	var success: bool = roll_data.success

	# Emit signal
	skill_check_performed.emit(skill_enum, int(dc), success, roll_data)

	# Return appropriate branch
	if success:
		return action.success_node_id
	else:
		return action.failure_node_id


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
	# Get location from PlayerGPS (player is always in same location as NPC during conversation)
	if PlayerGPS:
		context.region_name = PlayerGPS.current_region if PlayerGPS.current_region else "these lands"

		# Get town name from location ID if in a named location
		if not PlayerGPS.current_location_id.is_empty():
			var location_name: String = WorldGrid.get_location_name(PlayerGPS.current_location_id)
			context.town_name = location_name if location_name else PlayerGPS.current_region
		else:
			# In wilderness - use region name or "the wilderness"
			context.town_name = PlayerGPS.current_region if PlayerGPS.current_region else "the wilderness"
	else:
		# Fallback if PlayerGPS not available
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
		if not _evaluate_condition(condition):
			return false

	return true


## Evaluate a single condition
func _evaluate_condition(condition: DialogueCondition) -> bool:
	var result := _evaluate_condition_internal(condition)

	# Apply invert flag
	if condition.invert:
		result = not result

	return result


## Internal condition evaluation
func _evaluate_condition_internal(condition: DialogueCondition) -> bool:
	match condition.type:
		DialogueData.ConditionType.NONE:
			return true

		DialogueData.ConditionType.QUEST_STATE:
			var quest := QuestManager.get_quest(condition.param_string)
			if not quest:
				return condition.param_int == Enums.QuestState.UNAVAILABLE
			return quest.state == condition.param_int

		DialogueData.ConditionType.QUEST_COMPLETE:
			return QuestManager.is_quest_completed(condition.param_string)

		DialogueData.ConditionType.HAS_ITEM:
			return InventoryManager.has_item(condition.param_string, condition.param_int)

		DialogueData.ConditionType.HAS_GOLD:
			return InventoryManager.gold >= condition.param_int

		DialogueData.ConditionType.FLAG_SET:
			# Check ConversationSystem flags only (DialogueManager dependency removed)
			return has_flag(condition.param_string)

		DialogueData.ConditionType.FLAG_NOT_SET:
			# Check ConversationSystem flags only (DialogueManager dependency removed)
			return not has_flag(condition.param_string)

		DialogueData.ConditionType.STAT_CHECK:
			if not GameManager.player_data:
				return false
			var stat_value: int = GameManager.player_data.get_effective_stat(condition.param_int)
			return stat_value >= int(condition.param_float)

		DialogueData.ConditionType.SKILL_CHECK:
			if not GameManager.player_data:
				return false
			var skill_value: int = GameManager.player_data.get_skill(condition.param_int)
			return skill_value >= int(condition.param_float)

		DialogueData.ConditionType.TIME_OF_DAY:
			var current_time := GameManager.current_time_of_day
			match condition.param_string.to_lower():
				"dawn": return current_time == Enums.TimeOfDay.DAWN
				"morning": return current_time == Enums.TimeOfDay.MORNING
				"noon": return current_time == Enums.TimeOfDay.NOON
				"afternoon": return current_time == Enums.TimeOfDay.AFTERNOON
				"dusk": return current_time == Enums.TimeOfDay.DUSK
				"night": return current_time == Enums.TimeOfDay.NIGHT
				"midnight": return current_time == Enums.TimeOfDay.MIDNIGHT
				"day": return not GameManager.is_night()
				"night_any": return GameManager.is_night()
			return false

		DialogueData.ConditionType.REPUTATION:
			# Future: check faction reputation
			return true

		DialogueData.ConditionType.RANDOM_CHANCE:
			return randf() <= condition.param_float

		DialogueData.ConditionType.PLAYER_RACE:
			# Check player's race against param_string
			# Valid values: "human", "elf", "halfling", "dwarf"
			if not GameManager.player_data:
				return false
			var player_race: Enums.Race = GameManager.player_data.race
			var race_name: String = condition.param_string.to_lower().strip_edges()
			match race_name:
				"human": return player_race == Enums.Race.HUMAN
				"elf": return player_race == Enums.Race.ELF
				"halfling": return player_race == Enums.Race.HALFLING
				"dwarf": return player_race == Enums.Race.DWARF
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
