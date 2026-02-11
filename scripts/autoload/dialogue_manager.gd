## dialogue_manager.gd - Manages dialogue state, conditions, actions, and skill checks
extends Node

signal dialogue_started(dialogue_data: DialogueData, speaker_name: String)
signal dialogue_ended(dialogue_data: DialogueData)
signal node_changed(node: DialogueNode)
signal choice_made(choice: DialogueChoice, node: DialogueNode)
signal skill_check_performed(skill: int, dc: float, success: bool, roll_data: Dictionary)

## Current dialogue state
var current_dialogue: DialogueData = null
var current_node: DialogueNode = null
var current_speaker_name: String = ""

## Context variables for placeholder substitution in flag names
## Example: {"merchant_id": "blacksmith_01"} allows flags like "{merchant_id}:befriend"
## to be substituted to "blacksmith_01:befriend"
var context_variables: Dictionary = {}

## Dialogue flags (persisted via SaveManager)
## These track dialogue-specific state like "talked_to_npc_about_quest"
var dialogue_flags: Dictionary = {}

## Flag for whether dialogue is active
var is_dialogue_active: bool = false

## Pending skill check result (for branching after skill check action)
var _pending_skill_check_result: bool = false
var _pending_skill_check_action: DialogueAction = null

## Delayed transition support for skill check visual feedback
var _pending_transition_node_id: String = ""
var _transition_delayed: bool = false

## Reference to the dialogue UI
var dialogue_box: Node = null


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Continue processing while game is paused (for dialogue input handling)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Instantiate the DialogueBox UI
	var dialogue_box_scene := load("res://scenes/ui/dialogue_box.tscn")
	if dialogue_box_scene:
		dialogue_box = dialogue_box_scene.instantiate()
		add_child(dialogue_box)
		print("DialogueManager: DialogueBox UI instantiated")
	else:
		# Create from script if scene doesn't exist
		var DialogueBoxScript = load("res://scripts/ui/dialogue_box.gd")
		if DialogueBoxScript:
			dialogue_box = DialogueBoxScript.new()
			add_child(dialogue_box)
			print("DialogueManager: DialogueBox UI created from script")
		else:
			push_error("DialogueManager: Could not load DialogueBox")


# =============================================================================
# DIALOGUE LIFECYCLE
# =============================================================================

## Start a dialogue with an NPC
## Returns true if dialogue started successfully
## context: Optional dictionary of variables for placeholder substitution in flag names
##          Example: {"merchant_id": "blacksmith_01"} substitutes {merchant_id} in flags
func start_dialogue(dialogue_data: DialogueData, speaker_name: String = "", context: Dictionary = {}) -> bool:
	if is_dialogue_active:
		push_warning("DialogueManager: Dialogue already active, cannot start new dialogue")
		return false

	if not dialogue_data:
		push_warning("DialogueManager: No dialogue data provided")
		return false

	# Validate dialogue structure
	var errors := dialogue_data.validate()
	if not errors.is_empty():
		for err in errors:
			push_warning("DialogueManager: Validation error - " + err)
		return false

	# Get start node
	var start_node := dialogue_data.get_start_node()
	if not start_node:
		push_warning("DialogueManager: No start node found in dialogue '%s'" % dialogue_data.id)
		return false

	# Store dialogue state
	current_dialogue = dialogue_data
	current_speaker_name = speaker_name if not speaker_name.is_empty() else dialogue_data.display_name
	context_variables = context.duplicate()
	is_dialogue_active = true

	# Pause game for dialogue
	GameManager.start_dialogue()

	# Emit start signal
	dialogue_started.emit(dialogue_data, current_speaker_name)

	# Navigate to start node
	go_to_node(start_node.id)

	return true

## End the current dialogue
func end_dialogue() -> void:
	if not is_dialogue_active:
		return

	var finished_dialogue := current_dialogue

	# Clear state
	current_dialogue = null
	current_node = null
	current_speaker_name = ""
	context_variables.clear()
	is_dialogue_active = false
	_pending_skill_check_result = false
	_pending_skill_check_action = null
	_pending_transition_node_id = ""
	_transition_delayed = false

	# Resume game
	GameManager.end_dialogue()

	# Emit end signal
	dialogue_ended.emit(finished_dialogue)

## Navigate to a specific node by ID
func go_to_node(node_id: String) -> void:
	if not current_dialogue:
		push_warning("DialogueManager: No active dialogue")
		return

	if node_id.is_empty():
		# Empty node ID means end dialogue
		end_dialogue()
		return

	var node := current_dialogue.get_node_by_id(node_id)
	if not node:
		push_warning("DialogueManager: Node '%s' not found in dialogue '%s'" % [node_id, current_dialogue.id])
		end_dialogue()
		return

	current_node = node
	node_changed.emit(node)

	# Check for auto-continue (nodes without choices that auto-advance)
	if node.is_end_node:
		# UI will handle ending dialogue when player clicks
		pass
	elif node.choices.is_empty() and not node.auto_continue_to.is_empty():
		# Auto-continue after text is shown (UI handles timing)
		pass

## Select a choice from the current node
## Returns true if choice was valid and processed
## If delay_for_skill_check is true, skill check transitions will be delayed
## until complete_delayed_transition() is called
func select_choice(choice_index: int, delay_for_skill_check: bool = false) -> bool:
	if not current_node:
		push_warning("DialogueManager: No current node")
		return false

	var available_choices := get_available_choices()
	if choice_index < 0 or choice_index >= available_choices.size():
		push_warning("DialogueManager: Invalid choice index %d" % choice_index)
		return false

	var choice: DialogueChoice = available_choices[choice_index]

	# Check if this choice has a skill check action
	var has_skill_check := false
	for action in choice.actions:
		if action.type == DialogueData.ActionType.SKILL_CHECK:
			has_skill_check = true
			break

	# Emit choice signal
	choice_made.emit(choice, current_node)

	# Execute actions
	var next_node_id := choice.next_node_id
	for action in choice.actions:
		var result := execute_action(action)
		# Skill check actions can override next node
		if action.type == DialogueData.ActionType.SKILL_CHECK:
			if _pending_skill_check_action == action:
				next_node_id = result
				_pending_skill_check_action = null

	# If delaying for skill check display, store the pending transition
	if delay_for_skill_check and has_skill_check:
		_pending_transition_node_id = next_node_id
		_transition_delayed = true
		return true

	# Navigate to next node immediately
	go_to_node(next_node_id)

	return true


## Complete a delayed transition (called after skill check visual feedback)
func complete_delayed_transition() -> void:
	if _transition_delayed and not _pending_transition_node_id.is_empty():
		var node_id := _pending_transition_node_id
		_pending_transition_node_id = ""
		_transition_delayed = false
		go_to_node(node_id)
	elif _transition_delayed:
		# Empty node ID means end dialogue
		_pending_transition_node_id = ""
		_transition_delayed = false
		end_dialogue()


## Check if there's a pending delayed transition
func has_delayed_transition() -> bool:
	return _transition_delayed

## Continue to next node (for auto-continue or end nodes)
func continue_dialogue() -> void:
	if not current_node:
		end_dialogue()
		return

	if current_node.is_end_node:
		end_dialogue()
		return

	if not current_node.auto_continue_to.is_empty():
		go_to_node(current_node.auto_continue_to)
		return

	# If we have choices, wait for player selection
	if not current_node.choices.is_empty():
		return

	# No choices and no auto-continue, end dialogue
	end_dialogue()


# =============================================================================
# CHOICE AVAILABILITY
# =============================================================================

## Get all available choices for current node (respecting conditions)
func get_available_choices() -> Array[DialogueChoice]:
	var available: Array[DialogueChoice] = []

	if not current_node:
		return available

	for choice in current_node.choices:
		var conditions_met := evaluate_conditions(choice.conditions)
		if conditions_met or choice.show_when_unavailable:
			available.append(choice)

	return available

## Check if a specific choice is available (conditions met)
func is_choice_available(choice: DialogueChoice) -> bool:
	return evaluate_conditions(choice.conditions)

## Get the reason why a choice is unavailable
func get_choice_unavailable_reason(choice: DialogueChoice) -> String:
	if choice.unavailable_reason.is_empty():
		# Generate a default reason based on failed conditions
		for condition in choice.conditions:
			if not evaluate_condition(condition):
				return _get_condition_failure_reason(condition)
	return choice.unavailable_reason


# =============================================================================
# CONDITION EVALUATION
# =============================================================================

## Evaluate all conditions (AND logic - all must pass)
func evaluate_conditions(conditions: Array[DialogueCondition]) -> bool:
	for condition in conditions:
		if not evaluate_condition(condition):
			return false
	return true

## Evaluate a single condition
func evaluate_condition(condition: DialogueCondition) -> bool:
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
			return _check_quest_state(condition.param_string, condition.param_int)

		DialogueData.ConditionType.QUEST_COMPLETE:
			return QuestManager.is_quest_completed(condition.param_string)

		DialogueData.ConditionType.HAS_ITEM:
			return InventoryManager.has_item(condition.param_string, condition.param_int)

		DialogueData.ConditionType.HAS_GOLD:
			return InventoryManager.gold >= condition.param_int

		DialogueData.ConditionType.FLAG_SET:
			return has_flag(condition.param_string)

		DialogueData.ConditionType.FLAG_NOT_SET:
			return not has_flag(condition.param_string)

		DialogueData.ConditionType.STAT_CHECK:
			return _check_stat(condition.param_int, int(condition.param_float))

		DialogueData.ConditionType.SKILL_CHECK:
			return _check_skill(condition.param_int, int(condition.param_float))

		DialogueData.ConditionType.TIME_OF_DAY:
			return _check_time_of_day(condition.param_string)

		DialogueData.ConditionType.REPUTATION:
			# Future: check faction reputation
			return true

		DialogueData.ConditionType.RANDOM_CHANCE:
			return randf() <= condition.param_float

	return true

## Check quest state condition
func _check_quest_state(quest_id: String, expected_state: int) -> bool:
	var quest := QuestManager.get_quest(quest_id)
	if not quest:
		# Quest not started = UNAVAILABLE state
		return expected_state == Enums.QuestState.UNAVAILABLE
	return quest.state == expected_state

## Check stat threshold (passive check - no roll)
func _check_stat(stat_enum: int, threshold: int) -> bool:
	if not GameManager.player_data:
		return false

	var stat_value: int = 0
	match stat_enum:
		Enums.Stat.GRIT:
			stat_value = GameManager.player_data.get_effective_stat(Enums.Stat.GRIT)
		Enums.Stat.AGILITY:
			stat_value = GameManager.player_data.get_effective_stat(Enums.Stat.AGILITY)
		Enums.Stat.WILL:
			stat_value = GameManager.player_data.get_effective_stat(Enums.Stat.WILL)
		Enums.Stat.SPEECH:
			stat_value = GameManager.player_data.get_effective_stat(Enums.Stat.SPEECH)
		Enums.Stat.KNOWLEDGE:
			stat_value = GameManager.player_data.get_effective_stat(Enums.Stat.KNOWLEDGE)
		Enums.Stat.VITALITY:
			stat_value = GameManager.player_data.get_effective_stat(Enums.Stat.VITALITY)

	return stat_value >= threshold

## Check skill threshold (passive check - no roll)
func _check_skill(skill_enum: int, threshold: int) -> bool:
	if not GameManager.player_data:
		return false

	var skill_value: int = GameManager.player_data.get_skill(skill_enum)
	return skill_value >= threshold

## Check time of day
func _check_time_of_day(time_string: String) -> bool:
	var current_time := GameManager.current_time_of_day
	match time_string.to_lower():
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

## Get human-readable reason for condition failure
func _get_condition_failure_reason(condition: DialogueCondition) -> String:
	match condition.type:
		DialogueData.ConditionType.HAS_ITEM:
			var item_name := InventoryManager.get_item_name(condition.param_string)
			if condition.param_int > 1:
				return "Requires %d %s" % [condition.param_int, item_name]
			return "Requires %s" % item_name

		DialogueData.ConditionType.HAS_GOLD:
			return "Requires %d gold" % condition.param_int

		DialogueData.ConditionType.STAT_CHECK:
			var stat_name := _get_stat_name(condition.param_int)
			return "Requires %s %d" % [stat_name, int(condition.param_float)]

		DialogueData.ConditionType.SKILL_CHECK:
			var skill_name := _get_skill_name(condition.param_int)
			return "Requires %s %d" % [skill_name, int(condition.param_float)]

		DialogueData.ConditionType.QUEST_STATE:
			return "Quest requirements not met"

		_:
			return "Requirements not met"


# =============================================================================
# ACTION EXECUTION
# =============================================================================

## Execute a dialogue action
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
			return _execute_skill_check(action)

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
			# Bounties are now handled via ConversationSystem.select_topic(QUESTS)
			push_warning("[DialogueManager] SPAWN_ERRAND action is deprecated. Use bounty system instead.")

	return ""


# =============================================================================
# SKILL CHECKS WITH DICE ROLLS
# =============================================================================

## Execute a skill check action with dice roll
## Returns the next node ID (success or failure branch)
func _execute_skill_check(action: DialogueAction) -> String:
	var skill_enum: int = action.param_int
	var dc: float = action.param_float

	# Get player stats
	var player_data := GameManager.player_data
	if not player_data:
		# No player data, fail the check
		skill_check_performed.emit(skill_enum, dc, false, {})
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

	# Store for branching
	_pending_skill_check_result = success
	_pending_skill_check_action = action

	# Emit signal
	skill_check_performed.emit(skill_enum, dc, success, roll_data)

	# Return appropriate branch
	if success:
		return action.success_node_id
	else:
		return action.failure_node_id

## Get the governing stat for a skill
func _get_skill_governing_stat(skill_enum: int) -> int:
	match skill_enum:
		# GRIT-based
		Enums.Skill.MELEE, Enums.Skill.INTIMIDATION:
			return Enums.Stat.GRIT
		# AGILITY-based
		Enums.Skill.RANGED, Enums.Skill.DODGE, Enums.Skill.STEALTH, \
		Enums.Skill.ENDURANCE, Enums.Skill.THIEVERY, Enums.Skill.ACROBATICS, \
		Enums.Skill.ATHLETICS:
			return Enums.Stat.AGILITY
		# WILL-based
		Enums.Skill.CONCENTRATION, Enums.Skill.RESIST, Enums.Skill.BRAVERY:
			return Enums.Stat.WILL
		# SPEECH-based
		Enums.Skill.PERSUASION, Enums.Skill.DECEPTION, Enums.Skill.NEGOTIATION:
			return Enums.Stat.SPEECH
		# KNOWLEDGE-based
		Enums.Skill.ARCANA_LORE, Enums.Skill.HISTORY, Enums.Skill.INTUITION, \
		Enums.Skill.ENGINEERING, Enums.Skill.INVESTIGATION, Enums.Skill.PERCEPTION, \
		Enums.Skill.RELIGION, Enums.Skill.NATURE:
			return Enums.Stat.KNOWLEDGE
		# VITALITY-based
		Enums.Skill.FIRST_AID, Enums.Skill.HERBALISM, Enums.Skill.SURVIVAL:
			return Enums.Stat.VITALITY
		# CRAFTING (mixed - default to Knowledge)
		Enums.Skill.ALCHEMY, Enums.Skill.SMITHING:
			return Enums.Stat.KNOWLEDGE
		# LOCKPICKING - Agility
		Enums.Skill.LOCKPICKING:
			return Enums.Stat.AGILITY

	return Enums.Stat.KNOWLEDGE  # Default fallback

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
		Enums.Skill.ACROBATICS: return "Acrobatics"
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
		Enums.Skill.PERCEPTION: return "Perception"
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
# DIALOGUE FLAGS
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

## Set a dialogue flag (supports context variable substitution)
func set_flag(flag_name: String, value: Variant = true) -> void:
	var resolved_name := _substitute_context_variables(flag_name)
	dialogue_flags[resolved_name] = value

## Clear a dialogue flag (supports context variable substitution)
func clear_flag(flag_name: String) -> void:
	var resolved_name := _substitute_context_variables(flag_name)
	dialogue_flags.erase(resolved_name)

## Check if a flag is set (supports context variable substitution)
func has_flag(flag_name: String) -> bool:
	var resolved_name := _substitute_context_variables(flag_name)
	return dialogue_flags.has(resolved_name)

## Get a flag value (supports context variable substitution)
func get_flag(flag_name: String, default: Variant = null) -> Variant:
	var resolved_name := _substitute_context_variables(flag_name)
	return dialogue_flags.get(resolved_name, default)

## Check and clear a pending shop flag (returns shop ID or empty string)
func pop_pending_shop() -> String:
	var shop_id := ""
	for key in dialogue_flags.keys():
		if key.begins_with("_pending_shop:"):
			shop_id = key.substr(len("_pending_shop:"))
			dialogue_flags.erase(key)
			break
	return shop_id


# =============================================================================
# SAVE/LOAD INTEGRATION
# =============================================================================

## Serialize dialogue flags for saving
func to_dict() -> Dictionary:
	return {
		"dialogue_flags": dialogue_flags.duplicate()
	}

## Deserialize dialogue flags from save
func from_dict(data: Dictionary) -> void:
	dialogue_flags = data.get("dialogue_flags", {}).duplicate()

## Reset state for new game
func reset_for_new_game() -> void:
	# End any active dialogue
	if is_dialogue_active:
		end_dialogue()

	# Clear all flags
	dialogue_flags.clear()


# =============================================================================
# HELPER METHODS
# =============================================================================

## Get the current speaker name (from node or default)
func get_current_speaker() -> String:
	if current_node and not current_node.speaker_name.is_empty():
		return current_node.speaker_name
	return current_speaker_name

## Get current dialogue text
func get_current_text() -> String:
	if current_node:
		return current_node.text
	return ""

## Check if current node is an end node
func is_at_end_node() -> bool:
	if current_node:
		return current_node.is_end_node
	return false

## Check if current node has an auto-continue
func has_auto_continue() -> bool:
	if current_node:
		return not current_node.auto_continue_to.is_empty() and current_node.choices.is_empty()
	return false

## Get current portrait ID (for speaker portrait display)
func get_current_portrait() -> String:
	if current_node:
		return current_node.portrait_id
	return ""
