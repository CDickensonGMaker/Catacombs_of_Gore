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

## Topic menu configuration - simplified to 3 essential topics
const TOPIC_MENU: Array[Dictionary] = [
	{"key": 1, "type": ConversationTopic.TopicType.LOCAL_NEWS, "text": "What's happening here?"},
	{"key": 2, "type": ConversationTopic.TopicType.RUMORS, "text": "Heard any rumors?"},
	{"key": 3, "type": ConversationTopic.TopicType.GOODBYE, "text": "Goodbye"}
]


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


func _process(delta: float) -> void:
	if not is_open:
		return

	# Check if player has moved - close dialogue if they start walking
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


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	# Handle escape to exit conversation - always process in _input
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
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

	# Handle Y/N keys for bounty accept/decline
	if event is InputEventKey and event.pressed and not is_typing and is_showing_bounty_offer:
		match event.keycode:
			KEY_Y:
				_on_accept_bounty()
				get_viewport().set_input_as_handled()
				return
			KEY_N:
				_on_decline_bounty()
				get_viewport().set_input_as_handled()
				return

	# Handle number keys for topic selection (1-3)
	# Process in _input to ensure it runs before GUI focus consumes the event
	if event is InputEventKey and event.pressed and not is_typing and not is_showing_bounty_offer:
		var key_num := -1
		match event.keycode:
			KEY_1: key_num = 0
			KEY_2: key_num = 1
			KEY_3: key_num = 2

		if key_num >= 0 and key_num < topic_buttons.size():
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

	response_text = RichTextLabel.new()
	response_text.name = "ResponseText"
	response_text.bbcode_enabled = true
	response_text.fit_content = false
	response_text.scroll_active = true
	response_text.add_theme_color_override("default_color", COL_TEXT)
	response_text.add_theme_font_size_override("normal_font_size", 12)
	response_panel.add_child(response_text)

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

	# Create topic buttons for all 8 topics
	for i in range(TOPIC_MENU.size()):
		var topic_data: Dictionary = TOPIC_MENU[i]
		var btn := _create_topic_button(i, topic_data)
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

	# Hint label at bottom
	hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "[1-3] Select Topic  |  [ESC] Exit"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_color", COL_DIM)
	hint_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(hint_label)


func _create_topic_button(index: int, topic_data: Dictionary) -> Button:
	var btn := Button.new()
	btn.name = "Topic%d" % (index + 1)
	var key_num: int = topic_data["key"]
	var text: String = topic_data["text"]
	btn.text = "[%d] %s" % [key_num, text]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = Vector2(0, 28)  # Ensure clickable height
	btn.pressed.connect(_on_topic_pressed.bind(index))
	_style_topic_button(btn)
	return btn


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
	available_topics.clear()
	reminder_panel.visible = false
	is_showing_bounty_offer = false
	bounty_container.visible = false
	topic_container.visible = true
	# Note: GameManager.end_dialogue() handles is_in_dialogue flag
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


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


func _update_topic_availability() -> void:
	# Update which topics are available based on NPC profile
	for i in range(topic_buttons.size()):
		var btn: Button = topic_buttons[i]
		var topic_data: Dictionary = TOPIC_MENU[i]
		var topic_type: ConversationTopic.TopicType = topic_data["type"]

		# Check if this topic is available
		var is_available: bool = topic_type in available_topics
		btn.disabled = not is_available
		btn.visible = true  # Always show, just disable if unavailable


func _set_topics_enabled(enabled: bool) -> void:
	for i in range(topic_buttons.size()):
		var btn: Button = topic_buttons[i]
		var topic_data: Dictionary = TOPIC_MENU[i]
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

	if index < 0 or index >= TOPIC_MENU.size():
		print("ConversationUI: _on_topic_pressed blocked - invalid index")
		return

	var topic_data: Dictionary = TOPIC_MENU[index]
	var topic_type: ConversationTopic.TopicType = topic_data["type"]

	# Check if topic is available
	if topic_type not in available_topics:
		return

	# Hide reminder when selecting new topic
	reminder_panel.visible = false

	# Select the topic in ConversationSystem
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

	# Get available topics (always the same 3 simplified topics)
	available_topics = ConversationSystem.get_available_topics(context.npc_profile)

	# Update topic button availability
	_update_topic_availability()

	# Show greeting
	var greeting := _get_greeting(context)
	response_text.text = greeting
	response_text.visible_characters = -1

	# Hide reminder
	reminder_panel.visible = false

	# Show UI
	_show_ui()


func _on_response_delivered(response: ConversationResponse, context: ConversationContext) -> void:
	if not is_open:
		return

	# Inject variables into response text
	var final_text := context.inject_variables(response.text)

	# Check if this is a bounty offer (has pending bounty)
	if context.pending_bounty_id and not context.pending_bounty_id.is_empty():
		is_showing_bounty_offer = true
		topic_container.visible = false
		bounty_container.visible = true
		hint_label.text = "[Y] Accept  |  [N] Decline  |  [ESC] Exit"
	else:
		is_showing_bounty_offer = false
		topic_container.visible = true
		bounty_container.visible = false
		hint_label.text = "[1-3] Select Topic  |  [ESC] Exit"

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


# =============================================================================
# BOUNTY HANDLERS
# =============================================================================

func _on_accept_bounty() -> void:
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
	hint_label.text = "[1-3] Select Topic  |  [ESC] Exit"
	_update_topic_availability()


func _on_decline_bounty() -> void:
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
	hint_label.text = "[1-3] Select Topic  |  [ESC] Exit"
	_update_topic_availability()


# =============================================================================
# HELPERS
# =============================================================================

func _get_greeting(context: ConversationContext) -> String:
	# Generate a contextual greeting based on disposition and time
	var disposition := context.disposition
	var time := context.time_of_day

	# Time-based greetings
	var time_greeting: String
	match time:
		"morning":
			time_greeting = "Good morning"
		"afternoon":
			time_greeting = "Good afternoon"
		"evening":
			time_greeting = "Good evening"
		"night":
			time_greeting = "A late hour for visitors"
		_:
			time_greeting = "Greetings"

	# Disposition-based tone
	if disposition >= 75:
		return "%s, friend! What can I do for you?" % time_greeting
	elif disposition >= 60:
		return "%s. What brings you here?" % time_greeting
	elif disposition >= 40:
		return "%s. What do you want?" % time_greeting
	elif disposition >= 25:
		return "What do you want?"
	else:
		return "Make it quick."
