## conversation_ui.gd - UI component for topic-based NPC conversations
## Displays NPC responses and topic selection menu with gothic styling
class_name ConversationUI
extends CanvasLayer

## Dark gothic colors (matching DialogueBox and other UI)
const COL_BG = Color(0.08, 0.08, 0.1)
const COL_PANEL = Color(0.12, 0.12, 0.15)
const COL_BORDER = Color(0.3, 0.25, 0.2)
const COL_TEXT = Color(0.9, 0.85, 0.75)
const COL_DIM = Color(0.5, 0.5, 0.5)
const COL_GOLD = Color(0.9, 0.7, 0.4)
const COL_SELECT = Color(0.25, 0.2, 0.15)
const COL_REMINDER = Color(0.15, 0.12, 0.1)
const COL_REMINDER_BORDER = Color(0.5, 0.4, 0.3)

## Typewriter effect settings
const TYPEWRITER_SPEED := 0.03
const TYPEWRITER_FAST_SPEED := 0.005

## Topic menu configuration - all available topics with display text
## Topics are filtered dynamically based on NPC profile
const ALL_TOPICS: Dictionary = {
	ConversationTopic.TopicType.LOCAL_NEWS: "What's happening here?",
	ConversationTopic.TopicType.RUMORS: "Heard any rumors?",
	ConversationTopic.TopicType.PERSONAL: "Tell me about yourself.",
	ConversationTopic.TopicType.DIRECTIONS: "Can you give me directions?",
	ConversationTopic.TopicType.TRADE: "Let's trade.",
	ConversationTopic.TopicType.QUESTS: "Any work available?",
	ConversationTopic.TopicType.GOODBYE: "Goodbye"
}

## Maximum topic buttons to create (can be extended with custom topics)
const MAX_TOPIC_BUTTONS := 8

## Dynamic topic menu built per conversation (populated in _build_dynamic_topic_menu)
var dynamic_topic_menu: Array[Dictionary] = []


# =============================================================================
# UI ELEMENT REFERENCES
# =============================================================================

var root_control: Control
var panel: PanelContainer
var name_label: Label
var response_text: RichTextLabel
var reminder_panel: PanelContainer
var reminder_label: RichTextLabel
var topic_container: VBoxContainer
var topic_buttons: Array[Button] = []
var hint_label: Label
var bounty_container: HBoxContainer
var accept_button: Button
var decline_button: Button
var click_outside_overlay: Control  # Overlay to detect clicks outside panel
var copy_to_journal_button: Button  # Button to copy current response to journal
var journal_confirmation_label: Label  # Shows "Added to Journal" flash
var persuasion_container: HBoxContainer  # Persuasion action buttons
var admire_button: Button
var intimidate_button: Button
var bribe_button: Button
var taunt_button: Button
var disposition_label: Label  # Shows current disposition
var persuasion_result_label: Label  # Shows result of persuasion attempt

# =============================================================================
# STATE
# =============================================================================

var is_open: bool = false
var player_start_position: Vector3 = Vector3.ZERO  # Track player position when dialogue opens
const MOVEMENT_CLOSE_THRESHOLD := 0.5  # How far player needs to move to close dialogue
var is_typing: bool = false
var full_text: String = ""
var visible_chars: int = 0
var typewriter_timer: float = 0.0
var skip_typewriter: bool = false
var current_context: ConversationContext = null
var available_topics: Array[ConversationTopic.TopicType] = []
var is_showing_bounty_offer: bool = false
var is_showing_quest_offer: bool = false
var current_response: ConversationResponse = null  # Store current response for journal
var journal_flash_timer: float = 0.0  # Timer for "Added to Journal" flash
var persuasion_result_timer: float = 0.0  # Timer for persuasion result display
var is_showing_bribe_input: bool = false  # Whether bribe amount popup is showing
var is_showing_farewell: bool = false  # Whether farewell message is being shown
var farewell_timer: float = 0.0  # Timer before auto-closing after farewell
var is_scripted_mode: bool = false  # Track scripted dialogue state
var scripted_choices: Array = []  # Choices for scripted dialogue


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_hide_ui()

	# Connect to ConversationSystem signals
	ConversationSystem.conversation_started.connect(_on_conversation_started)
	ConversationSystem.response_delivered.connect(_on_response_delivered)
	ConversationSystem.memory_reminder.connect(_on_memory_reminder)
	ConversationSystem.conversation_ended.connect(_on_conversation_ended)
	ConversationSystem.farewell_delivered.connect(_on_farewell_delivered)
	# Scripted dialogue signals
	ConversationSystem.scripted_line_shown.connect(_on_scripted_line_shown)
	ConversationSystem.scripted_dialogue_ended.connect(_on_scripted_dialogue_ended)


func _process(delta: float) -> void:
	if not is_open:
		return

	# Check if player has moved - close dialogue if they start walking
	# Skip this check for scripted dialogue (quest turn-ins, etc.) - let them complete
	if not is_scripted_mode:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player and player_start_position != Vector3.ZERO:
			var distance_moved: float = player.global_position.distance_to(player_start_position)
			if distance_moved > MOVEMENT_CLOSE_THRESHOLD:
				ConversationSystem.end_conversation()
				return

	# Handle typewriter effect
	if is_typing:
		var speed := TYPEWRITER_FAST_SPEED if skip_typewriter else TYPEWRITER_SPEED
		typewriter_timer += delta

		while typewriter_timer >= speed and visible_chars < full_text.length():
			typewriter_timer -= speed
			visible_chars += 1
			response_text.visible_characters = visible_chars

		# Check if typing complete
		if visible_chars >= full_text.length():
			is_typing = false
			_on_typing_complete()

	# Handle journal confirmation flash timer
	if journal_flash_timer > 0.0:
		journal_flash_timer -= delta
		if journal_flash_timer <= 0.0:
			journal_confirmation_label.visible = false

	# Handle persuasion result timer
	if persuasion_result_timer > 0.0:
		persuasion_result_timer -= delta
		if persuasion_result_timer <= 0.0:
			persuasion_result_label.visible = false

	# Handle farewell timer - auto-close after showing farewell
	if is_showing_farewell and farewell_timer > 0.0:
		farewell_timer -= delta
		if farewell_timer <= 0.0:
			is_showing_farewell = false
			ConversationSystem.end_conversation()


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	# During farewell, any key/click closes the conversation immediately
	if is_showing_farewell:
		if event is InputEventKey and event.pressed:
			is_showing_farewell = false
			ConversationSystem.end_conversation()
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventMouseButton and event.pressed:
			is_showing_farewell = false
			ConversationSystem.end_conversation()
			get_viewport().set_input_as_handled()
			return

	# During scripted dialogue without choices, any key/click continues or closes
	if is_scripted_mode and scripted_choices.is_empty():
		if event is InputEventKey and event.pressed:
			ConversationSystem.continue_scripted_dialogue()
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventMouseButton and event.pressed:
			ConversationSystem.continue_scripted_dialogue()
			get_viewport().set_input_as_handled()
			return

	# Handle escape to exit conversation/scripted dialogue - always process in _input
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if is_scripted_mode:
			# End the scripted dialogue
			ConversationSystem.end_scripted_dialogue()
		else:
			ConversationSystem.end_conversation()
		get_viewport().set_input_as_handled()
		return

	# Handle held interact for fast typewriter (track hold state only)
	if event.is_action("interact") or event.is_action("ui_accept"):
		skip_typewriter = event.is_pressed()

	# Handle interact/confirm to skip typewriter (keyboard only - mouse handled by buttons)
	# Process in _input to ensure it runs before GUI focus consumes the event
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if is_typing:
			skip_typewriter = true
			visible_chars = full_text.length()
			response_text.visible_characters = visible_chars
			is_typing = false
			_on_typing_complete()
			get_viewport().set_input_as_handled()
			return

	# Handle Y/N keys for bounty or quest accept/decline
	if event is InputEventKey and event.pressed and not is_typing:
		if is_showing_bounty_offer:
			match event.keycode:
				KEY_Y:
					_on_accept_bounty()
					get_viewport().set_input_as_handled()
					return
				KEY_N:
					_on_decline_bounty()
					get_viewport().set_input_as_handled()
					return
		elif is_showing_quest_offer:
			match event.keycode:
				KEY_Y:
					_on_accept_quest()
					get_viewport().set_input_as_handled()
					return
				KEY_N:
					_on_decline_quest()
					get_viewport().set_input_as_handled()
					return

	# Handle J key for Copy to Journal
	if event is InputEventKey and event.pressed and not is_typing:
		if event.keycode == KEY_J:
			_on_copy_to_journal_pressed()
			get_viewport().set_input_as_handled()
			return

	# Handle number keys for topic/choice selection (1-8)
	# Process in _input to ensure it runs before GUI focus consumes the event
	if event is InputEventKey and event.pressed and not is_typing and not is_showing_bounty_offer and not is_showing_quest_offer:
		var key_num := -1
		match event.keycode:
			KEY_1: key_num = 0
			KEY_2: key_num = 1
			KEY_3: key_num = 2
			KEY_4: key_num = 3
			KEY_5: key_num = 4
			KEY_6: key_num = 5
			KEY_7: key_num = 6
			KEY_8: key_num = 7

		# Handle scripted dialogue choices
		if is_scripted_mode and key_num >= 0 and key_num < scripted_choices.size():
			_on_scripted_choice_pressed(key_num)
			get_viewport().set_input_as_handled()
			return

		# Handle normal topic selection
		if key_num >= 0 and key_num < dynamic_topic_menu.size() and key_num < topic_buttons.size():
			var btn: Button = topic_buttons[key_num]
			if btn.visible and not btn.disabled:
				_on_topic_pressed(key_num)
				get_viewport().set_input_as_handled()
				return


## Use _unhandled_input for input that might have been consumed by GUI
## This is now mostly a fallback since key handling moved to _input
func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return

	# Fallback for any input not caught in _input
	pass


# =============================================================================
# UI CONSTRUCTION
# =============================================================================

func _build_ui() -> void:
	# Root control for full screen coverage
	root_control = Control.new()
	root_control.name = "ConversationUIRoot"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_PASS
	root_control.process_mode = Node.PROCESS_MODE_ALWAYS  # Ensure GUI works when paused
	add_child(root_control)

	# Click-outside overlay - closes dialogue when clicking outside the panel
	click_outside_overlay = Control.new()
	click_outside_overlay.name = "ClickOutsideOverlay"
	click_outside_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_outside_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Catch all clicks
	click_outside_overlay.gui_input.connect(_on_overlay_clicked)
	root_control.add_child(click_outside_overlay)

	# Main panel - takes up most of the screen
	panel = PanelContainer.new()
	panel.name = "ConversationPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.15
	panel.anchor_right = 0.85
	panel.anchor_top = 0.15
	panel.anchor_bottom = 0.85
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COL_BG
	panel_style.border_color = COL_BORDER
	panel_style.set_border_width_all(3)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	root_control.add_child(panel)

	# Main vertical container
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(vbox)

	# NPC name at top
	name_label = Label.new()
	name_label.name = "NPCName"
	name_label.text = "NPC NAME"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", COL_GOLD)
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	# Separator
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = COL_BORDER
	sep_style.set_content_margin_all(1)
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Response text area
	var response_panel := PanelContainer.new()
	response_panel.name = "ResponsePanel"
	response_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	response_panel.custom_minimum_size.y = 120

	var response_style := StyleBoxFlat.new()
	response_style.bg_color = COL_PANEL
	response_style.border_color = COL_BORDER
	response_style.set_border_width_all(1)
	response_style.set_content_margin_all(15)
	response_panel.add_theme_stylebox_override("panel", response_style)
	vbox.add_child(response_panel)

	# Response text area container (VBox for text + journal button)
	var response_vbox := VBoxContainer.new()
	response_vbox.add_theme_constant_override("separation", 8)
	response_panel.add_child(response_vbox)

	response_text = RichTextLabel.new()
	response_text.name = "ResponseText"
	response_text.bbcode_enabled = true
	response_text.fit_content = false
	response_text.scroll_active = true
	response_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	response_text.add_theme_color_override("default_color", COL_TEXT)
	response_text.add_theme_font_size_override("normal_font_size", 12)
	response_vbox.add_child(response_text)

	# Copy to Journal button + confirmation label (bottom of response panel)
	var journal_hbox := HBoxContainer.new()
	journal_hbox.alignment = BoxContainer.ALIGNMENT_END
	journal_hbox.add_theme_constant_override("separation", 10)
	response_vbox.add_child(journal_hbox)

	# Journal confirmation label (hidden by default)
	journal_confirmation_label = Label.new()
	journal_confirmation_label.name = "JournalConfirmation"
	journal_confirmation_label.text = "Added to Journal"
	journal_confirmation_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	journal_confirmation_label.add_theme_font_size_override("font_size", 10)
	journal_confirmation_label.visible = false
	journal_hbox.add_child(journal_confirmation_label)

	# Copy to Journal button
	copy_to_journal_button = Button.new()
	copy_to_journal_button.name = "CopyToJournalButton"
	copy_to_journal_button.text = "[J] Copy to Journal"
	copy_to_journal_button.focus_mode = Control.FOCUS_NONE
	copy_to_journal_button.mouse_filter = Control.MOUSE_FILTER_STOP
	copy_to_journal_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	copy_to_journal_button.custom_minimum_size = Vector2(120, 24)
	copy_to_journal_button.pressed.connect(_on_copy_to_journal_pressed)
	_style_journal_button(copy_to_journal_button)
	journal_hbox.add_child(copy_to_journal_button)

	# Memory reminder panel (hidden by default)
	reminder_panel = PanelContainer.new()
	reminder_panel.name = "ReminderPanel"
	reminder_panel.visible = false

	var reminder_style := StyleBoxFlat.new()
	reminder_style.bg_color = COL_REMINDER
	reminder_style.border_color = COL_REMINDER_BORDER
	reminder_style.set_border_width_all(2)
	reminder_style.set_content_margin_all(10)
	reminder_panel.add_theme_stylebox_override("panel", reminder_style)
	vbox.add_child(reminder_panel)

	reminder_label = RichTextLabel.new()
	reminder_label.name = "ReminderLabel"
	reminder_label.bbcode_enabled = true
	reminder_label.fit_content = true
	reminder_label.add_theme_color_override("default_color", COL_DIM)
	reminder_label.add_theme_font_size_override("normal_font_size", 10)
	reminder_panel.add_child(reminder_label)

	# Separator before topic menu
	var sep2 := HSeparator.new()
	sep2.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep2)

	# Topic menu container - use 2 column grid for compact layout
	topic_container = VBoxContainer.new()
	topic_container.name = "TopicContainer"
	topic_container.add_theme_constant_override("separation", 5)
	topic_container.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(topic_container)

	# Create placeholder topic buttons (will be populated dynamically per conversation)
	for i in range(MAX_TOPIC_BUTTONS):
		var btn := _create_topic_button_placeholder(i)
		topic_container.add_child(btn)
		topic_buttons.append(btn)

	# Bounty accept/decline container (hidden by default)
	bounty_container = HBoxContainer.new()
	bounty_container.name = "BountyContainer"
	bounty_container.visible = false
	bounty_container.add_theme_constant_override("separation", 20)
	bounty_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(bounty_container)

	accept_button = _create_bounty_button("[Y] Accept Bounty", true)
	accept_button.pressed.connect(_on_accept_bounty)
	bounty_container.add_child(accept_button)

	decline_button = _create_bounty_button("[N] Decline", false)
	decline_button.pressed.connect(_on_decline_bounty)
	bounty_container.add_child(decline_button)

	# Persuasion bar with disposition display and action buttons
	var persuasion_vbox := VBoxContainer.new()
	persuasion_vbox.name = "PersuasionSection"
	persuasion_vbox.add_theme_constant_override("separation", 5)
	vbox.add_child(persuasion_vbox)

	# Disposition display
	var disposition_hbox := HBoxContainer.new()
	disposition_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	disposition_hbox.add_theme_constant_override("separation", 10)
	persuasion_vbox.add_child(disposition_hbox)

	var disp_title := Label.new()
	disp_title.text = "Disposition:"
	disp_title.add_theme_color_override("font_color", COL_DIM)
	disp_title.add_theme_font_size_override("font_size", 10)
	disposition_hbox.add_child(disp_title)

	disposition_label = Label.new()
	disposition_label.name = "DispositionLabel"
	disposition_label.text = "50 (Neutral)"
	disposition_label.add_theme_color_override("font_color", COL_GOLD)
	disposition_label.add_theme_font_size_override("font_size", 10)
	disposition_hbox.add_child(disposition_label)

	# Persuasion result label (hidden by default)
	persuasion_result_label = Label.new()
	persuasion_result_label.name = "PersuasionResultLabel"
	persuasion_result_label.text = ""
	persuasion_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	persuasion_result_label.add_theme_font_size_override("font_size", 10)
	persuasion_result_label.visible = false
	persuasion_vbox.add_child(persuasion_result_label)

	# Persuasion buttons
	persuasion_container = HBoxContainer.new()
	persuasion_container.name = "PersuasionContainer"
	persuasion_container.add_theme_constant_override("separation", 8)
	persuasion_container.alignment = BoxContainer.ALIGNMENT_CENTER
	persuasion_vbox.add_child(persuasion_container)

	admire_button = _create_persuasion_button("Admire", Color(0.3, 0.5, 0.3))
	admire_button.pressed.connect(_on_admire_pressed)
	persuasion_container.add_child(admire_button)

	intimidate_button = _create_persuasion_button("Intimidate", Color(0.5, 0.3, 0.3))
	intimidate_button.pressed.connect(_on_intimidate_pressed)
	persuasion_container.add_child(intimidate_button)

	bribe_button = _create_persuasion_button("Bribe", Color(0.5, 0.45, 0.2))
	bribe_button.pressed.connect(_on_bribe_pressed)
	persuasion_container.add_child(bribe_button)

	taunt_button = _create_persuasion_button("Taunt", Color(0.4, 0.3, 0.4))
	taunt_button.pressed.connect(_on_taunt_pressed)
	persuasion_container.add_child(taunt_button)

	# Hint label at bottom
	hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "[1-4] Select Topic  |  [ESC] Exit"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_color", COL_DIM)
	hint_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(hint_label)


## Create a placeholder topic button (will be configured per conversation)
func _create_topic_button_placeholder(index: int) -> Button:
	var btn := Button.new()
	btn.name = "Topic%d" % (index + 1)
	btn.text = "[%d] ..." % (index + 1)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = Vector2(0, 28)  # Ensure clickable height
	btn.pressed.connect(_on_topic_pressed.bind(index))
	btn.visible = false  # Hidden until configured
	_style_topic_button(btn)
	return btn


## Configure a topic button with actual topic data
func _configure_topic_button(btn: Button, index: int, topic_data: Dictionary) -> void:
	var key_num: int = index + 1
	var text: String = topic_data.get("text", "...")
	btn.text = "[%d] %s" % [key_num, text]
	btn.visible = true
	btn.disabled = false


func _create_bounty_button(text: String, is_accept: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = Vector2(150, 35)

	var normal := StyleBoxFlat.new()
	normal.bg_color = COL_PANEL if not is_accept else Color(0.15, 0.2, 0.15)
	normal.border_color = COL_BORDER if not is_accept else Color(0.3, 0.5, 0.3)
	normal.set_border_width_all(2)
	normal.set_content_margin_all(10)

	var hover := StyleBoxFlat.new()
	hover.bg_color = COL_SELECT if not is_accept else Color(0.2, 0.3, 0.2)
	hover.border_color = COL_GOLD if not is_accept else Color(0.4, 0.7, 0.4)
	hover.set_border_width_all(2)
	hover.set_content_margin_all(10)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", COL_TEXT if not is_accept else Color(0.7, 0.9, 0.7))
	btn.add_theme_color_override("font_hover_color", COL_GOLD if not is_accept else Color(0.8, 1.0, 0.8))

	return btn


func _style_journal_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.12, 0.1)
	normal.border_color = Color(0.3, 0.4, 0.3)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(4)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.15, 0.2, 0.15)
	hover.border_color = Color(0.4, 0.6, 0.4)
	hover.set_border_width_all(1)
	hover.set_content_margin_all(4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_font_size_override("font_size", 9)
	btn.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
	btn.add_theme_color_override("font_hover_color", Color(0.7, 0.9, 0.7))


func _create_persuasion_button(text: String, tint: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = Vector2(80, 26)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(tint.r * 0.5, tint.g * 0.5, tint.b * 0.5)
	normal.border_color = tint
	normal.set_border_width_all(1)
	normal.set_content_margin_all(5)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(tint.r * 0.7, tint.g * 0.7, tint.b * 0.7)
	hover.border_color = Color(tint.r * 1.2, tint.g * 1.2, tint.b * 1.2)
	hover.set_border_width_all(1)
	hover.set_content_margin_all(5)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.1, 0.1, 0.1)
	disabled.border_color = COL_DIM
	disabled.set_border_width_all(1)
	disabled.set_content_margin_all(5)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", COL_GOLD)
	btn.add_theme_color_override("font_disabled_color", COL_DIM)

	return btn


func _style_topic_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COL_PANEL
	normal.border_color = COL_BORDER
	normal.set_border_width_all(1)
	normal.set_content_margin_all(8)

	var hover := StyleBoxFlat.new()
	hover.bg_color = COL_SELECT
	hover.border_color = COL_GOLD
	hover.set_border_width_all(1)
	hover.set_content_margin_all(8)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = COL_SELECT
	pressed.border_color = COL_GOLD
	pressed.set_border_width_all(2)
	pressed.set_content_margin_all(8)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.1, 0.1, 0.1)
	disabled.border_color = COL_DIM
	disabled.set_border_width_all(1)
	disabled.set_content_margin_all(8)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", COL_GOLD)
	btn.add_theme_color_override("font_pressed_color", COL_GOLD)
	btn.add_theme_color_override("font_disabled_color", COL_DIM)


# =============================================================================
# UI STATE MANAGEMENT
# =============================================================================

func _show_ui() -> void:
	root_control.visible = true
	is_open = true
	# Note: GameManager.start_dialogue() handles is_in_dialogue flag
	# Player controller checks this flag to block input
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GameManager.set_menu_cursor()  # Use menu cursor for dialogue
	call_deferred("_focus_first_topic")


func _focus_first_topic() -> void:
	for btn in topic_buttons:
		if btn.visible and not btn.disabled:
			btn.grab_focus()
			break


func _hide_ui() -> void:
	root_control.visible = false
	is_open = false
	is_typing = false
	skip_typewriter = false
	current_context = null
	current_response = null
	available_topics.clear()
	reminder_panel.visible = false
	is_showing_bounty_offer = false
	is_showing_quest_offer = false
	is_showing_farewell = false
	farewell_timer = 0.0
	bounty_container.visible = false
	topic_container.visible = true
	journal_confirmation_label.visible = false
	journal_flash_timer = 0.0
	persuasion_result_label.visible = false
	persuasion_result_timer = 0.0
	# Note: GameManager.end_dialogue() handles is_in_dialogue flag
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameManager.set_default_cursor()  # Restore default cursor


func _start_typewriter(text: String) -> void:
	full_text = text
	visible_chars = 0
	typewriter_timer = 0.0
	is_typing = true
	skip_typewriter = false

	response_text.text = text
	response_text.visible_characters = 0

	# Disable topic buttons while typing
	_set_topics_enabled(false)


func _on_typing_complete() -> void:
	response_text.visible_characters = -1  # Show all
	_set_topics_enabled(true)


## Build the dynamic topic menu based on NPC profile and available topics
func _build_dynamic_topic_menu(profile: NPCKnowledgeProfile) -> void:
	dynamic_topic_menu.clear()

	# Hide all buttons first
	for btn in topic_buttons:
		btn.visible = false
		btn.disabled = true

	var menu_index := 0

	# PRIORITY: Add quest turn-in option at the TOP if there's a pending turn-in
	if current_context and not current_context.pending_quest_turnin.is_empty():
		var turnin_info: Dictionary = current_context.pending_quest_turnin
		var quest_title: String = turnin_info.get("quest_title", "Quest")
		dynamic_topic_menu.append({
			"key": menu_index + 1,
			"type": ConversationTopic.TopicType.QUESTS,
			"text": "Turn in: %s" % quest_title,
			"is_custom": true,
			"custom_id": "quest_turnin",
			"is_quest_turnin": true
		})
		menu_index += 1

	# Get topics from ConversationSystem
	var topics_to_show: Array[ConversationTopic.TopicType] = available_topics.duplicate()

	# Add custom topics from NPC profile if available
	var custom_topics: Array[Dictionary] = []
	if profile and profile.has_method("get_custom_topics"):
		custom_topics = profile.get_custom_topics()

	# Add location-aware topics from WorldLexicon (regions, settlements, creatures)
	var location_topics: Array[Dictionary] = ConversationSystem.get_location_custom_topics(profile)
	for loc_topic: Dictionary in location_topics:
		custom_topics.append(loc_topic)

	# Build menu entries for standard topics
	for topic_type: ConversationTopic.TopicType in topics_to_show:
		if menu_index >= MAX_TOPIC_BUTTONS:
			break

		var text: String = ALL_TOPICS.get(topic_type, "Unknown")
		dynamic_topic_menu.append({
			"key": menu_index + 1,
			"type": topic_type,
			"text": text,
			"is_custom": false
		})
		menu_index += 1

	# Add custom topics from profile
	for custom_topic: Dictionary in custom_topics:
		if menu_index >= MAX_TOPIC_BUTTONS:
			break
		dynamic_topic_menu.append({
			"key": menu_index + 1,
			"type": custom_topic.get("type", ConversationTopic.TopicType.PERSONAL),
			"text": custom_topic.get("text", "..."),
			"is_custom": true,
			"custom_id": custom_topic.get("id", ""),
			"response": custom_topic.get("response", ""),  # Preserve response for location topics
			"is_location_topic": custom_topic.get("is_location_topic", false)
		})
		menu_index += 1

	# Configure visible buttons
	for i in range(dynamic_topic_menu.size()):
		if i < topic_buttons.size():
			_configure_topic_button(topic_buttons[i], i, dynamic_topic_menu[i])

	# Update hint label with correct key range
	var max_key: int = mini(dynamic_topic_menu.size(), 9)
	if max_key > 0:
		hint_label.text = "[1-%d] Select Topic  |  [ESC] Exit" % max_key
	else:
		hint_label.text = "[ESC] Exit"


func _update_topic_availability() -> void:
	# Update which topics are available based on dynamic menu
	for i in range(dynamic_topic_menu.size()):
		if i >= topic_buttons.size():
			break
		var btn: Button = topic_buttons[i]
		var topic_data: Dictionary = dynamic_topic_menu[i]

		# Quest turn-in and custom topics are always available
		if topic_data.get("is_quest_turnin", false) or topic_data.get("is_custom", false):
			btn.disabled = false
			btn.visible = true
			continue

		var topic_type: ConversationTopic.TopicType = topic_data["type"]
		# Check if this topic is available
		var is_available: bool = topic_type in available_topics
		btn.disabled = not is_available
		btn.visible = true


func _set_topics_enabled(enabled: bool) -> void:
	for i in range(dynamic_topic_menu.size()):
		if i >= topic_buttons.size():
			break
		var btn: Button = topic_buttons[i]
		var topic_data: Dictionary = dynamic_topic_menu[i]

		# Quest turn-in and custom topics follow the enabled flag directly
		if topic_data.get("is_quest_turnin", false) or topic_data.get("is_custom", false):
			btn.disabled = not enabled
			continue

		var topic_type: ConversationTopic.TopicType = topic_data["type"]
		# Only enable if both enabled flag is true AND topic is available
		if enabled:
			btn.disabled = topic_type not in available_topics
		else:
			btn.disabled = true


# =============================================================================
# TOPIC SELECTION
# =============================================================================

func _on_topic_pressed(index: int) -> void:
	print("ConversationUI: _on_topic_pressed called with index %d" % index)
	if is_typing:
		print("ConversationUI: _on_topic_pressed blocked - is_typing=true")
		return

	if index < 0 or index >= dynamic_topic_menu.size():
		print("ConversationUI: _on_topic_pressed blocked - invalid index")
		return

	var topic_data: Dictionary = dynamic_topic_menu[index]
	var topic_type: ConversationTopic.TopicType = topic_data["type"]

	# Hide reminder when selecting new topic
	reminder_panel.visible = false

	# Handle quest turn-in specially - this completes the quest
	if topic_data.get("is_quest_turnin", false):
		ConversationSystem.complete_pending_quest_turnin()
		# Rebuild the menu to remove the turn-in option
		if current_context:
			_build_dynamic_topic_menu(current_context.npc_profile)
			_update_topic_availability()
		return

	# Check if topic is available (skip for custom topics which may not be in available_topics)
	if not topic_data.get("is_custom", false) and topic_type not in available_topics:
		return

	# Handle custom topics differently
	if topic_data.get("is_custom", false):
		var custom_id: String = topic_data.get("custom_id", "")
		ConversationSystem.select_custom_topic(custom_id, topic_data)
	else:
		# Select the standard topic in ConversationSystem
		ConversationSystem.select_topic(topic_type)


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

## Handle clicks on the overlay (outside the dialogue panel) - closes dialogue
func _on_overlay_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if click is outside the panel
		var panel_rect: Rect2 = panel.get_global_rect()
		if not panel_rect.has_point(event.position):
			ConversationSystem.end_conversation()


func _on_conversation_started(npc: Node, context: ConversationContext) -> void:
	current_context = context

	# Record player position for movement detection
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player_start_position = player.global_position
	else:
		player_start_position = Vector3.ZERO

	# Set NPC name
	name_label.text = context.npc_name.to_upper()

	# Get available topics based on NPC profile
	available_topics = ConversationSystem.get_available_topics(context.npc_profile)

	# Build the dynamic topic menu based on available topics and NPC profile
	_build_dynamic_topic_menu(context.npc_profile)

	# Update topic button availability
	_update_topic_availability()

	# Update disposition display
	_update_disposition_display()

	# Show greeting
	var greeting := _get_greeting(context)
	response_text.text = greeting
	response_text.visible_characters = -1

	# Hide reminder and persuasion result
	reminder_panel.visible = false
	persuasion_result_label.visible = false

	# Always show persuasion container and enable buttons
	# Persuasion is always available - it's how you FIX bad reputation
	persuasion_container.visible = true
	_set_persuasion_enabled(true)

	# Show UI
	_show_ui()


func _on_response_delivered(response: ConversationResponse, context: ConversationContext) -> void:
	if not is_open:
		return

	# Store current response for journal copying
	current_response = response

	# Inject variables into response text
	var final_text := context.inject_variables(response.text)

	# Check if this response should be auto-logged to journal
	if response.auto_log_to_journal:
		_copy_response_to_journal(response, context, final_text)

	# Check if this is a bounty offer (has pending bounty)
	if context.pending_bounty_id and not context.pending_bounty_id.is_empty():
		is_showing_bounty_offer = true
		is_showing_quest_offer = false
		topic_container.visible = false
		bounty_container.visible = true
		accept_button.text = "[Y] Accept Bounty"
		hint_label.text = "[Y] Accept  |  [N] Decline  |  [ESC] Exit"
	# Check if this is a quest offer (has pending quest)
	elif context.pending_quest_id and not context.pending_quest_id.is_empty():
		is_showing_quest_offer = true
		is_showing_bounty_offer = false
		topic_container.visible = false
		bounty_container.visible = true
		accept_button.text = "[Y] Accept Quest"
		hint_label.text = "[Y] Accept  |  [N] Decline  |  [ESC] Exit"
	else:
		is_showing_bounty_offer = false
		is_showing_quest_offer = false
		topic_container.visible = true
		bounty_container.visible = false
		hint_label.text = "[1-4] Select Topic  |  [J] Copy to Journal  |  [ESC] Exit"

		# Rebuild the topic menu to include "Turn in" option if there's a pending turn-in
		if not context.pending_quest_turnin.is_empty():
			_build_dynamic_topic_menu(context.npc_profile)
			_update_topic_availability()

	# Start typewriter effect
	_start_typewriter(final_text)


func _on_memory_reminder(_response_id: String, original_text: String) -> void:
	if not is_open:
		return

	# Show the reminder panel with the original text
	reminder_label.text = "[Reminder: %s]" % original_text
	reminder_panel.visible = true


func _on_conversation_ended(_npc: Node) -> void:
	_hide_ui()


func _on_farewell_delivered(farewell_text: String) -> void:
	if not is_open:
		return

	# Show the farewell text in the response area
	is_showing_farewell = true
	response_text.text = farewell_text
	response_text.visible_characters = -1

	# Hide topic buttons during farewell
	_set_topics_enabled(false)
	for btn: Button in topic_buttons:
		btn.visible = false

	# Hide any open panels
	reminder_panel.visible = false
	bounty_container.visible = false
	persuasion_container.visible = false

	# Update hint to show how to close
	hint_label.text = "[Any key] or [Click] to leave"

	# Start a short timer then auto-close (player can also click/press any key)
	farewell_timer = 1.5  # Auto-close after 1.5 seconds


# =============================================================================
# SCRIPTED DIALOGUE HANDLERS
# =============================================================================

func _on_scripted_line_shown(line: Dictionary, _index: int) -> void:
	is_scripted_mode = true
	scripted_choices = line.get("choices", [])

	# Show the UI if not already open
	if not is_open:
		_show_ui()
		is_open = true

	# Set the speaker name
	var speaker: String = line.get("speaker", "")
	name_label.text = speaker.to_upper()

	# Set the dialogue text
	var text: String = line.get("text", "")
	response_text.text = text
	response_text.visible_characters = -1  # Show all immediately

	# Hide normal topic buttons
	for btn: Button in topic_buttons:
		btn.visible = false
	topic_container.visible = false
	bounty_container.visible = false
	persuasion_container.visible = false
	reminder_panel.visible = false

	# Show scripted choices if any, or show continue hint
	if scripted_choices.is_empty():
		# No choices - show "continue" or "end" hint
		if line.get("is_end", false):
			hint_label.text = "[Any key] or [Click] to close"
		else:
			hint_label.text = "[Any key] or [Click] to continue"
	else:
		# Show choices as temporary buttons
		_show_scripted_choices(scripted_choices)
		hint_label.text = "[1-%d] Select choice" % scripted_choices.size()


func _show_scripted_choices(choices: Array) -> void:
	# Repurpose topic buttons for scripted choices
	for i in range(topic_buttons.size()):
		var btn: Button = topic_buttons[i]
		if i < choices.size():
			var choice: Dictionary = choices[i]
			btn.text = choice.get("text", "...")
			btn.visible = true
			# Disconnect any existing connections and reconnect for scripted choice
			if btn.pressed.is_connected(_on_topic_pressed):
				btn.pressed.disconnect(_on_topic_pressed)
			if not btn.pressed.is_connected(_on_scripted_choice_pressed.bind(i)):
				btn.pressed.connect(_on_scripted_choice_pressed.bind(i))
		else:
			btn.visible = false

	topic_container.visible = true


func _on_scripted_choice_pressed(choice_index: int) -> void:
	if not is_scripted_mode:
		return

	# Restore topic button connections
	_restore_topic_button_connections()

	ConversationSystem.select_scripted_choice(choice_index)


func _restore_topic_button_connections() -> void:
	for i in range(topic_buttons.size()):
		var btn: Button = topic_buttons[i]
		# Disconnect scripted choice handler
		if btn.pressed.is_connected(_on_scripted_choice_pressed.bind(i)):
			btn.pressed.disconnect(_on_scripted_choice_pressed.bind(i))
		# Reconnect topic handler
		if not btn.pressed.is_connected(_on_topic_pressed):
			btn.pressed.connect(_on_topic_pressed.bind(i))


func _on_scripted_dialogue_ended() -> void:
	is_scripted_mode = false
	scripted_choices.clear()
	_restore_topic_button_connections()
	_hide_ui()
	is_open = false


# =============================================================================
# BOUNTY HANDLERS
# =============================================================================

func _on_accept_bounty() -> void:
	# Also handle quest offers since we reuse the same buttons
	if is_showing_quest_offer:
		_on_accept_quest()
		return

	if not is_showing_bounty_offer:
		return

	if ConversationSystem.accept_pending_bounty():
		# Show acceptance confirmation
		response_text.text = "Good. Get to work, and return when you're done."
		response_text.visible_characters = -1

	# Hide bounty buttons, show topics again
	is_showing_bounty_offer = false
	bounty_container.visible = false
	topic_container.visible = true
	hint_label.text = "[1-4] Select Topic  |  [ESC] Exit"
	_update_topic_availability()


func _on_decline_bounty() -> void:
	# Also handle quest offers since we reuse the same buttons
	if is_showing_quest_offer:
		_on_decline_quest()
		return

	if not is_showing_bounty_offer:
		return

	ConversationSystem.decline_pending_bounty()

	# Show decline response
	response_text.text = "Suit yourself. Come back if you change your mind."
	response_text.visible_characters = -1

	# Hide bounty buttons, show topics again
	is_showing_bounty_offer = false
	bounty_container.visible = false
	topic_container.visible = true
	hint_label.text = "[1-4] Select Topic  |  [ESC] Exit"
	_update_topic_availability()


# =============================================================================
# QUEST HANDLERS
# =============================================================================

func _on_accept_quest() -> void:
	if not is_showing_quest_offer:
		return

	if ConversationSystem.accept_pending_quest():
		# Show acceptance confirmation
		response_text.text = "Very well. I trust you'll see it done."
		response_text.visible_characters = -1

	# Hide buttons, show topics again
	is_showing_quest_offer = false
	bounty_container.visible = false
	topic_container.visible = true
	hint_label.text = "[1-4] Select Topic  |  [ESC] Exit"
	_update_topic_availability()


func _on_decline_quest() -> void:
	if not is_showing_quest_offer:
		return

	ConversationSystem.decline_pending_quest()

	# Show decline response
	response_text.text = "Perhaps another time, then."
	response_text.visible_characters = -1

	# Hide buttons, show topics again
	is_showing_quest_offer = false
	bounty_container.visible = false
	topic_container.visible = true
	hint_label.text = "[1-4] Select Topic  |  [ESC] Exit"
	_update_topic_availability()


# =============================================================================
# HELPERS
# =============================================================================

func _get_greeting(_context: ConversationContext) -> String:
	# Use ConversationSystem's pool-based greeting selection
	# This provides personality-aware greetings from greetings.json
	return ConversationSystem.get_greeting()


# =============================================================================
# JOURNAL HANDLERS
# =============================================================================

## Handle copy to journal button press
func _on_copy_to_journal_pressed() -> void:
	if not current_response or not current_context:
		return

	# Get the final text with variables injected
	var final_text := current_context.inject_variables(current_response.text)
	_copy_response_to_journal(current_response, current_context, final_text)


## Copy a response to the journal
func _copy_response_to_journal(response: ConversationResponse, context: ConversationContext, final_text: String) -> void:
	# Format the journal entry
	var npc_name: String = context.npc_name
	var topic_name: String = ConversationTopic.get_topic_name(response.topic_type)
	var location: String = JournalManager.get_current_location_name() if JournalManager else ""

	# Try to add to journal via JournalManager
	if JournalManager:
		# For auto-logged important responses
		if response.auto_log_to_journal:
			# add_dialogue_note(dialogue_text, npc_name, location, quest_tag)
			JournalManager.add_dialogue_note(final_text, npc_name, location, topic_name)
		else:
			# For manual copies - add_manual_note(dialogue_text, npc_name, location)
			JournalManager.add_manual_note(final_text, npc_name, location)

		# Show confirmation flash
		_show_journal_confirmation()
	else:
		push_warning("ConversationUI: JournalManager not available")


## Show the "Added to Journal" confirmation flash
func _show_journal_confirmation() -> void:
	journal_confirmation_label.visible = true
	journal_flash_timer = 2.0  # Show for 2 seconds


# =============================================================================
# PERSUASION HANDLERS
# =============================================================================

## Handle Admire persuasion button
func _on_admire_pressed() -> void:
	if is_typing:
		return
	_perform_persuasion(ConversationSystem.PersuasionAction.ADMIRE)


## Handle Intimidate persuasion button
func _on_intimidate_pressed() -> void:
	if is_typing:
		return
	_perform_persuasion(ConversationSystem.PersuasionAction.INTIMIDATE)


## Handle Bribe persuasion button (simplified - uses 50 gold)
func _on_bribe_pressed() -> void:
	if is_typing:
		return

	# Check if player has enough gold
	var player_gold: int = InventoryManager.gold if InventoryManager else 0
	if player_gold < 10:
		_show_persuasion_result("Not enough gold to bribe!", Color(0.8, 0.5, 0.5))
		return

	# Use 50 gold or whatever the player has (minimum 10)
	var bribe_amount: int = mini(50, player_gold)
	_perform_persuasion(ConversationSystem.PersuasionAction.BRIBE, bribe_amount)


## Handle Taunt persuasion button
func _on_taunt_pressed() -> void:
	if is_typing:
		return
	_perform_persuasion(ConversationSystem.PersuasionAction.TAUNT)


## Perform a persuasion action and update UI
func _perform_persuasion(action: ConversationSystem.PersuasionAction, bribe_amount: int = 0) -> void:
	# Disable persuasion buttons during the action
	_set_persuasion_enabled(false)

	var result: Dictionary = ConversationSystem.perform_persuasion(action, bribe_amount)

	# Update disposition display
	_update_disposition_display()

	# Show result message
	var result_text: String = ""
	var result_color: Color = COL_TEXT

	var action_name: String = result.get("action", "")
	var success: bool = result.get("success", false)
	var disp_change: int = result.get("disposition_change", 0)
	var turned_hostile: bool = result.get("turned_hostile", false)

	if turned_hostile:
		result_text = "%s FAILED! They've turned hostile!" % action_name
		result_color = Color(1.0, 0.3, 0.3)
	elif success:
		if disp_change > 0:
			result_text = "%s SUCCESS! Disposition +%d" % [action_name, disp_change]
			result_color = Color(0.5, 0.9, 0.5)
		elif disp_change < 0:
			result_text = "%s SUCCESS! Disposition %d" % [action_name, disp_change]
			result_color = Color(0.9, 0.7, 0.3)  # Yellow for intentional decrease
		else:
			result_text = "%s SUCCESS!" % action_name
			result_color = Color(0.5, 0.9, 0.5)
	else:
		if disp_change < 0:
			result_text = "%s FAILED! Disposition %d" % [action_name, disp_change]
			result_color = Color(0.9, 0.5, 0.5)
		else:
			result_text = "%s FAILED!" % action_name
			result_color = Color(0.9, 0.5, 0.5)

	# Add bribe cost info
	if action == ConversationSystem.PersuasionAction.BRIBE and bribe_amount > 0:
		result_text += " (-%d gold)" % bribe_amount

	_show_persuasion_result(result_text, result_color)

	# Re-enable buttons after a short delay
	await get_tree().create_timer(1.5).timeout
	_set_persuasion_enabled(true)


## Show persuasion result message
func _show_persuasion_result(text: String, color: Color) -> void:
	persuasion_result_label.text = text
	persuasion_result_label.add_theme_color_override("font_color", color)
	persuasion_result_label.visible = true
	persuasion_result_timer = 3.0  # Show for 3 seconds


## Update the disposition display
func _update_disposition_display() -> void:
	if not current_context:
		disposition_label.text = "?? (Unknown)"
		return

	var disp: int = current_context.disposition
	var category: String = ""
	var color: Color = COL_TEXT

	if disp >= 90:
		category = "Allied"
		color = Color(0.3, 0.9, 0.3)
	elif disp >= 75:
		category = "Friendly"
		color = Color(0.5, 0.8, 0.5)
	elif disp >= 60:
		category = "Warm"
		color = Color(0.6, 0.7, 0.5)
	elif disp >= 40:
		category = "Neutral"
		color = COL_GOLD
	elif disp >= 25:
		category = "Cool"
		color = Color(0.7, 0.6, 0.4)
	elif disp >= 10:
		category = "Unfriendly"
		color = Color(0.8, 0.5, 0.4)
	else:
		category = "Hostile"
		color = Color(0.9, 0.3, 0.3)

	disposition_label.text = "%d (%s)" % [disp, category]
	disposition_label.add_theme_color_override("font_color", color)


## Enable/disable persuasion buttons
func _set_persuasion_enabled(enabled: bool) -> void:
	admire_button.disabled = not enabled
	intimidate_button.disabled = not enabled
	bribe_button.disabled = not enabled
	taunt_button.disabled = not enabled
