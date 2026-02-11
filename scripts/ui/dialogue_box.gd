## dialogue_box.gd - UI component for displaying NPC dialogue
## Connects to DialogueManager for dialogue flow control
## Features: typewriter text effect, response choices, gothic styling
class_name DialogueBox
extends CanvasLayer

## Dark gothic colors (matching game_menu.gd and shop_ui.gd)
const COL_BG = Color(0.08, 0.08, 0.1)
const COL_PANEL = Color(0.12, 0.12, 0.15)
const COL_BORDER = Color(0.3, 0.25, 0.2)
const COL_TEXT = Color(0.9, 0.85, 0.75)
const COL_DIM = Color(0.5, 0.5, 0.5)
const COL_GOLD = Color(0.9, 0.7, 0.4)
const COL_SELECT = Color(0.25, 0.2, 0.15)
const COL_UNAVAILABLE = Color(0.4, 0.35, 0.3)

## Typewriter effect settings
const TYPEWRITER_SPEED := 0.03  ## Seconds per character
const TYPEWRITER_FAST_SPEED := 0.005  ## Speed when holding action key

## Skill check display settings
const SKILL_CHECK_DISPLAY_TIME := 1.5  ## Seconds to show skill check result

## UI element references
var root_control: Control
var panel: PanelContainer
var name_label: Label
var text_label: RichTextLabel
var choice_container: GridContainer
var continue_indicator: Label
var choice_buttons: Array[Button] = []
var skill_check_overlay: PanelContainer
var skill_check_label: Label

## State
var is_open: bool = false
var is_typing: bool = false
var full_text: String = ""
var visible_chars: int = 0
var typewriter_timer: float = 0.0
var skip_typewriter: bool = false

## Skill check display state
var is_showing_skill_check: bool = false
var skill_check_timer: float = 0.0
var pending_skill_check_choice: int = -1


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_hide_ui()

	# Connect to DialogueManager signals
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.node_changed.connect(_on_node_changed)
	DialogueManager.skill_check_performed.connect(_on_skill_check_performed)


func _process(delta: float) -> void:
	if not is_open:
		return

	# Handle skill check display timer
	if is_showing_skill_check:
		skill_check_timer -= delta
		if skill_check_timer <= 0.0:
			_hide_skill_check_overlay()
			# Now actually process the choice that triggered the skill check
			if pending_skill_check_choice >= 0:
				var choice_index := pending_skill_check_choice
				pending_skill_check_choice = -1
				DialogueManager.select_choice(choice_index)
		return  # Don't process other input while showing skill check

	# Handle typewriter effect
	if is_typing:
		var speed := TYPEWRITER_FAST_SPEED if skip_typewriter else TYPEWRITER_SPEED
		typewriter_timer += delta

		while typewriter_timer >= speed and visible_chars < full_text.length():
			typewriter_timer -= speed
			visible_chars += 1
			text_label.visible_characters = visible_chars

		# Check if typing complete
		if visible_chars >= full_text.length():
			is_typing = false
			_on_typing_complete()


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	# Block keyboard input while showing skill check result, but NOT mouse (let buttons work)
	if is_showing_skill_check:
		if not event is InputEventMouse:
			get_viewport().set_input_as_handled()
		return

	# Handle escape to cancel dialogue - always process this in _input
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		DialogueManager.end_dialogue()
		get_viewport().set_input_as_handled()
		return

	# Handle held interact for fast typewriter (track hold state)
	if event.is_action("interact") or event.is_action("ui_accept"):
		skip_typewriter = event.is_pressed()

	# Handle interact/confirm input (keyboard only - mouse handled by buttons)
	# Process in _input to ensure it runs before GUI focus consumes the event
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if is_typing:
			# Skip to end of text
			skip_typewriter = true
			visible_chars = full_text.length()
			text_label.visible_characters = visible_chars
			is_typing = false
			_on_typing_complete()
			get_viewport().set_input_as_handled()
		elif _has_no_choices():
			# Continue to next node
			DialogueManager.continue_dialogue()
			get_viewport().set_input_as_handled()
		return

	# Handle number keys for choice selection (1-4)
	# Process in _input to ensure it runs before GUI focus consumes the event
	if event is InputEventKey and event.pressed and not is_typing:
		var key_num := -1
		match event.keycode:
			KEY_1: key_num = 0
			KEY_2: key_num = 1
			KEY_3: key_num = 2
			KEY_4: key_num = 3

		if key_num >= 0 and key_num < choice_buttons.size():
			var btn: Button = choice_buttons[key_num]
			if btn.visible and not btn.disabled:
				print("DialogueBox: Number key %d pressed, selecting choice" % (key_num + 1))
				_on_choice_pressed(key_num)
				get_viewport().set_input_as_handled()
				return


## Use _unhandled_input for input that might have been consumed by GUI
## This is now mostly a fallback since key handling moved to _input
func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return

	# Don't process if showing skill check
	if is_showing_skill_check:
		return

	# Fallback for any input not caught in _input
	pass


func _build_ui() -> void:
	# Root control for full screen coverage
	root_control = Control.new()
	root_control.name = "DialogueBoxRoot"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass to children
	root_control.process_mode = Node.PROCESS_MODE_ALWAYS  # Ensure GUI works when paused
	add_child(root_control)

	# Main dialogue panel - positioned at bottom of screen, compact height
	panel = PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.anchor_top = 0.72  # Higher up - more compact
	panel.offset_left = 20
	panel.offset_right = -20
	panel.offset_top = 0
	panel.offset_bottom = -15
	panel.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass to children (buttons)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = COL_BG
	panel_style.border_color = COL_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	root_control.add_child(panel)

	# Main vertical container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass to children
	panel.add_child(vbox)

	# Top row: Speaker name on left, continue indicator on right
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(top_row)

	# Speaker name label
	name_label = Label.new()
	name_label.name = "SpeakerName"
	name_label.text = "NPC Name"
	name_label.add_theme_color_override("font_color", COL_GOLD)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_label)

	# Continue indicator (shown when no choices) - in top row
	continue_indicator = Label.new()
	continue_indicator.name = "ContinueIndicator"
	continue_indicator.text = "[E] Continue"
	continue_indicator.add_theme_color_override("font_color", COL_DIM)
	continue_indicator.add_theme_font_size_override("font_size", 10)
	continue_indicator.visible = false
	top_row.add_child(continue_indicator)

	# Separator line
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 3)
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = COL_BORDER
	sep_style.set_content_margin_all(1)
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Dialogue text area - compact
	text_label = RichTextLabel.new()
	text_label.name = "DialogueText"
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.custom_minimum_size.y = 40
	text_label.add_theme_color_override("default_color", COL_TEXT)
	text_label.add_theme_font_size_override("normal_font_size", 12)
	text_label.mouse_filter = Control.MOUSE_FILTER_PASS  # Don't block mouse events
	vbox.add_child(text_label)

	# Choice container - 2 column grid layout
	choice_container = GridContainer.new()
	choice_container.name = "ChoiceContainer"
	choice_container.columns = 2
	choice_container.add_theme_constant_override("h_separation", 10)
	choice_container.add_theme_constant_override("v_separation", 6)
	choice_container.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass to children
	choice_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_container.visible = false
	vbox.add_child(choice_container)

	# Pre-create 4 choice buttons (2x2 grid)
	for i in range(4):
		var btn := _create_choice_button(i)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		choice_container.add_child(btn)
		choice_buttons.append(btn)

	# Skill check result overlay (centered on screen)
	_build_skill_check_overlay()


func _build_skill_check_overlay() -> void:
	skill_check_overlay = PanelContainer.new()
	skill_check_overlay.name = "SkillCheckOverlay"
	skill_check_overlay.set_anchors_preset(Control.PRESET_CENTER)
	skill_check_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	skill_check_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	skill_check_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse clicks

	var overlay_style = StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	overlay_style.border_color = COL_GOLD
	overlay_style.set_border_width_all(3)
	overlay_style.set_content_margin_all(20)
	overlay_style.set_corner_radius_all(4)
	skill_check_overlay.add_theme_stylebox_override("panel", overlay_style)

	skill_check_label = Label.new()
	skill_check_label.name = "SkillCheckLabel"
	skill_check_label.text = "Persuasion: 15 vs DC 12 - Success!"
	skill_check_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_check_label.add_theme_font_size_override("font_size", 16)
	skill_check_label.add_theme_color_override("font_color", COL_TEXT)
	skill_check_overlay.add_child(skill_check_label)

	skill_check_overlay.visible = false
	root_control.add_child(skill_check_overlay)


func _create_choice_button(index: int) -> Button:
	var btn = Button.new()
	btn.name = "Choice%d" % (index + 1)
	btn.text = "[%d] Choice text" % (index + 1)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.clip_text = true  # Prevent text overflow
	btn.custom_minimum_size = Vector2(200, 32)  # Ensure clickable area
	btn.pressed.connect(_on_choice_pressed.bind(index))
	_style_choice_button(btn)
	btn.visible = false
	return btn


func _style_choice_button(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = COL_PANEL
	normal.border_color = COL_BORDER
	normal.set_border_width_all(1)
	normal.set_content_margin_all(8)

	var hover = StyleBoxFlat.new()
	hover.bg_color = COL_SELECT
	hover.border_color = COL_GOLD
	hover.set_border_width_all(1)
	hover.set_content_margin_all(8)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = COL_SELECT
	pressed.border_color = COL_GOLD
	pressed.set_border_width_all(2)
	pressed.set_content_margin_all(8)

	var disabled = StyleBoxFlat.new()
	disabled.bg_color = Color(0.1, 0.1, 0.1)
	disabled.border_color = COL_DIM
	disabled.set_border_width_all(1)
	disabled.set_content_margin_all(8)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", COL_GOLD)
	btn.add_theme_color_override("font_pressed_color", COL_GOLD)
	btn.add_theme_color_override("font_disabled_color", COL_UNAVAILABLE)
	btn.add_theme_font_size_override("font_size", 11)


func _show_ui() -> void:
	root_control.visible = true
	is_open = true
	# Note: GameManager.start_dialogue() handles is_in_dialogue flag
	# Player controller checks this flag to block input
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Grab focus on first visible button after a frame
	call_deferred("_focus_first_button")


func _focus_first_button() -> void:
	for btn in choice_buttons:
		if btn.visible and not btn.disabled:
			btn.grab_focus()
			break


func _hide_ui() -> void:
	root_control.visible = false
	is_open = false
	is_typing = false
	skip_typewriter = false
	is_showing_skill_check = false
	pending_skill_check_choice = -1
	if skill_check_overlay:
		skill_check_overlay.visible = false
	# Note: GameManager.end_dialogue() handles is_in_dialogue flag
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _start_typewriter(text: String) -> void:
	full_text = text
	visible_chars = 0
	typewriter_timer = 0.0
	is_typing = true
	skip_typewriter = false

	text_label.text = text
	text_label.visible_characters = 0

	# Hide choices and continue indicator while typing
	choice_container.visible = false
	continue_indicator.visible = false


func _on_typing_complete() -> void:
	text_label.visible_characters = -1  # Show all
	_update_choices()
	# Focus first available button
	call_deferred("_focus_first_button")


func _update_choices() -> void:
	var available_choices := DialogueManager.get_available_choices()
	print("DialogueBox: _update_choices called with %d choices" % available_choices.size())

	if available_choices.is_empty():
		# No choices - show continue indicator
		choice_container.visible = false
		continue_indicator.visible = true

		# Update indicator text based on node state
		if DialogueManager.is_at_end_node():
			continue_indicator.text = "[E] End Conversation"
		else:
			continue_indicator.text = "[E] Continue"
	else:
		# Has choices - show choice buttons in 2-column grid
		choice_container.visible = true
		continue_indicator.visible = false
		print("DialogueBox: Showing choice_container with %d columns" % choice_container.columns)

		# Update choice buttons
		for i in range(choice_buttons.size()):
			var btn: Button = choice_buttons[i]

			if i < available_choices.size():
				var choice: DialogueChoice = available_choices[i]
				var is_available := DialogueManager.is_choice_available(choice)

				btn.visible = true
				btn.text = "[%d] %s" % [i + 1, choice.text]
				btn.disabled = not is_available
				print("DialogueBox: Button %d visible=%s text=%s" % [i, btn.visible, btn.text])

				# Show unavailable reason as tooltip
				if not is_available:
					var reason := DialogueManager.get_choice_unavailable_reason(choice)
					btn.tooltip_text = reason
					btn.text = "[%d] %s (%s)" % [i + 1, choice.text, reason]
				else:
					btn.tooltip_text = ""
			else:
				btn.visible = false


func _has_no_choices() -> bool:
	var available := DialogueManager.get_available_choices()
	return available.is_empty()


func _on_choice_pressed(index: int) -> void:
	print("DialogueBox: _on_choice_pressed called with index %d" % index)
	if is_typing or is_showing_skill_check:
		print("DialogueBox: _on_choice_pressed blocked - is_typing=%s is_showing_skill_check=%s" % [is_typing, is_showing_skill_check])
		return

	# Check if this choice has a skill check - if so, use delayed transition
	var available_choices := DialogueManager.get_available_choices()
	if index < available_choices.size():
		var choice: DialogueChoice = available_choices[index]
		var has_skill_check := false
		for action in choice.actions:
			if action.type == DialogueData.ActionType.SKILL_CHECK:
				has_skill_check = true
				break

		if has_skill_check:
			# Use delayed transition - skill check overlay will trigger completion
			DialogueManager.select_choice(index, true)
			return

	# No skill check, proceed normally
	DialogueManager.select_choice(index)


# =============================================================================
# SKILL CHECK OVERLAY
# =============================================================================

func _show_skill_check_overlay(skill_name: String, roll_total: int, dc: int, success: bool) -> void:
	var result_text := "SUCCESS!" if success else "FAILED!"
	var result_color := Color(0.4, 0.9, 0.4) if success else Color(0.9, 0.4, 0.4)

	skill_check_label.text = "%s: %d vs DC %d - %s" % [skill_name, roll_total, dc, result_text]
	skill_check_label.add_theme_color_override("font_color", result_color)

	skill_check_overlay.visible = true
	is_showing_skill_check = true
	skill_check_timer = SKILL_CHECK_DISPLAY_TIME

	# Hide choices while showing skill check result
	choice_container.visible = false
	continue_indicator.visible = false


func _hide_skill_check_overlay() -> void:
	skill_check_overlay.visible = false
	is_showing_skill_check = false

	# Complete the delayed transition in dialogue manager
	if DialogueManager.has_delayed_transition():
		DialogueManager.complete_delayed_transition()


# =============================================================================
# DIALOGUE MANAGER SIGNAL HANDLERS
# =============================================================================

func _on_dialogue_started(_dialogue_data: DialogueData, speaker_name: String) -> void:
	name_label.text = speaker_name.to_upper()
	_show_ui()


func _on_dialogue_ended(_dialogue_data: DialogueData) -> void:
	_hide_ui()
	# Also hide skill check overlay if showing
	if is_showing_skill_check:
		skill_check_overlay.visible = false
		is_showing_skill_check = false


func _on_node_changed(node: DialogueNode) -> void:
	if not node:
		return

	# Update speaker name if node has a different speaker
	var speaker := DialogueManager.get_current_speaker()
	if not speaker.is_empty():
		name_label.text = speaker.to_upper()

	# Start typewriter effect with node text
	_start_typewriter(node.text)


func _on_skill_check_performed(skill: int, dc: float, success: bool, roll_data: Dictionary) -> void:
	# Get skill name from the modifiers in roll_data or look it up
	var skill_name: String = _get_skill_name(skill)

	# Try to get skill name from modifiers (second entry after stat)
	if roll_data.has("modifiers"):
		var modifiers: Array = roll_data.modifiers
		if modifiers.size() >= 2:
			var skill_mod: Dictionary = modifiers[1]
			if skill_mod.has("name"):
				skill_name = skill_mod.name

	# Get the total roll from roll_data
	var roll_total: int = roll_data.get("total", 0)

	_show_skill_check_overlay(skill_name, roll_total, int(dc), success)


## Get skill name from enum (simplified version matching DialogueManager)
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
