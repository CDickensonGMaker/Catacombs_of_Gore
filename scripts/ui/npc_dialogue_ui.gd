## npc_dialogue_ui.gd - PS1-styled UI for NPC dialogue with portrait support
## Displays speaker name, portrait area, dialogue text with typewriter effect,
## and response options. Integrates with TakeoverManager and DialogueManager.
class_name NPCDialogueUI
extends CanvasLayer

# =============================================================================
# PS1 GOTHIC COLOR PALETTE
# =============================================================================

const COL_BG = Color(0.08, 0.08, 0.1)
const COL_PANEL = Color(0.12, 0.12, 0.15)
const COL_BORDER = Color(0.3, 0.25, 0.2)
const COL_TEXT = Color(0.9, 0.85, 0.75)
const COL_DIM = Color(0.5, 0.5, 0.5)
const COL_GOLD = Color(0.9, 0.7, 0.4)
const COL_SELECT = Color(0.25, 0.2, 0.15)
const COL_UNAVAILABLE = Color(0.4, 0.35, 0.3)
const COL_PORTRAIT_BG = Color(0.06, 0.06, 0.08)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Typewriter effect settings
const TYPEWRITER_SPEED := 0.03  ## Seconds per character (normal)
const TYPEWRITER_FAST_SPEED := 0.005  ## Speed when holding action key

## Portrait settings
const PORTRAIT_SIZE := Vector2(64, 64)  ## PS1-style small portrait

## Skill check display
const SKILL_CHECK_DISPLAY_TIME := 1.5  ## Seconds to show result

## Maximum choices shown
const MAX_CHOICES := 4

# =============================================================================
# UI ELEMENT REFERENCES
# =============================================================================

var root_control: Control
var main_panel: PanelContainer
var portrait_container: PanelContainer
var portrait_texture_rect: TextureRect
var name_label: Label
var text_label: RichTextLabel
var choice_container: VBoxContainer
var continue_indicator: Label
var choice_buttons: Array[Button] = []
var skill_check_overlay: PanelContainer
var skill_check_label: Label

# =============================================================================
# STATE
# =============================================================================

var is_open: bool = false
var is_typing: bool = false
var full_text: String = ""
var visible_chars: int = 0
var typewriter_timer: float = 0.0
var skip_typewriter: bool = false
var typewriter_enabled: bool = true

## Skill check display state
var is_showing_skill_check: bool = false
var skill_check_timer: float = 0.0
var pending_skill_check_choice: int = -1

## Current portrait texture (can be null)
var current_portrait: Texture2D = null

## Portrait cache for loaded portraits
var _portrait_cache: Dictionary = {}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_hide_ui()

	# Connect to DialogueManager signals
	if DialogueManager:
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
			if pending_skill_check_choice >= 0:
				var choice_index := pending_skill_check_choice
				pending_skill_check_choice = -1
				DialogueManager.select_choice(choice_index)
		return

	# Handle typewriter effect
	if is_typing and typewriter_enabled:
		var speed := TYPEWRITER_FAST_SPEED if skip_typewriter else TYPEWRITER_SPEED
		typewriter_timer += delta

		while typewriter_timer >= speed and visible_chars < full_text.length():
			typewriter_timer -= speed
			visible_chars += 1
			text_label.visible_characters = visible_chars

		if visible_chars >= full_text.length():
			is_typing = false
			_on_typing_complete()


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	# Block input while showing skill check (except mouse for buttons)
	if is_showing_skill_check:
		if not event is InputEventMouse:
			get_viewport().set_input_as_handled()
		return

	# Handle escape to cancel dialogue
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_close_dialogue()
		get_viewport().set_input_as_handled()
		return

	# Track held interact for fast typewriter
	if event.is_action("interact") or event.is_action("ui_accept"):
		skip_typewriter = event.is_pressed()

	# Handle interact/confirm
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if is_typing:
			_complete_typewriter()
			get_viewport().set_input_as_handled()
		elif _has_no_choices():
			DialogueManager.continue_dialogue()
			get_viewport().set_input_as_handled()
		return

	# Handle number keys for choice selection (1-4)
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
				_on_choice_pressed(key_num)
				get_viewport().set_input_as_handled()
				return


# =============================================================================
# UI CONSTRUCTION
# =============================================================================

func _build_ui() -> void:
	# Root control for full screen coverage
	root_control = Control.new()
	root_control.name = "NPCDialogueUIRoot"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_PASS
	root_control.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root_control)

	# Main dialogue panel at bottom of screen
	main_panel = PanelContainer.new()
	main_panel.name = "DialoguePanel"
	main_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	main_panel.anchor_top = 0.68
	main_panel.offset_left = 20
	main_panel.offset_right = -20
	main_panel.offset_top = 0
	main_panel.offset_bottom = -15
	main_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COL_BG
	panel_style.border_color = COL_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_content_margin_all(10)
	main_panel.add_theme_stylebox_override("panel", panel_style)
	root_control.add_child(main_panel)

	# Horizontal layout: portrait on left, content on right
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	main_panel.add_child(hbox)

	# Portrait container (PS1-style square)
	_build_portrait_area(hbox)

	# Content area (name, text, choices)
	var content_vbox := VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 6)
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(content_vbox)

	# Top row: speaker name + continue indicator
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_row.mouse_filter = Control.MOUSE_FILTER_PASS
	content_vbox.add_child(top_row)

	name_label = Label.new()
	name_label.name = "SpeakerName"
	name_label.text = "NPC NAME"
	name_label.add_theme_color_override("font_color", COL_GOLD)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_label)

	continue_indicator = Label.new()
	continue_indicator.name = "ContinueIndicator"
	continue_indicator.text = "[E] Continue"
	continue_indicator.add_theme_color_override("font_color", COL_DIM)
	continue_indicator.add_theme_font_size_override("font_size", 10)
	continue_indicator.visible = false
	top_row.add_child(continue_indicator)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = COL_BORDER
	sep_style.set_content_margin_all(1)
	sep.add_theme_stylebox_override("separator", sep_style)
	content_vbox.add_child(sep)

	# Dialogue text area
	text_label = RichTextLabel.new()
	text_label.name = "DialogueText"
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.custom_minimum_size.y = 36
	text_label.add_theme_color_override("default_color", COL_TEXT)
	text_label.add_theme_font_size_override("normal_font_size", 12)
	text_label.mouse_filter = Control.MOUSE_FILTER_PASS
	content_vbox.add_child(text_label)

	# Choice container
	choice_container = VBoxContainer.new()
	choice_container.name = "ChoiceContainer"
	choice_container.add_theme_constant_override("separation", 4)
	choice_container.mouse_filter = Control.MOUSE_FILTER_PASS
	choice_container.visible = false
	content_vbox.add_child(choice_container)

	# Pre-create choice buttons
	for i in range(MAX_CHOICES):
		var btn := _create_choice_button(i)
		choice_container.add_child(btn)
		choice_buttons.append(btn)

	# Skill check overlay
	_build_skill_check_overlay()


func _build_portrait_area(parent: Node) -> void:
	portrait_container = PanelContainer.new()
	portrait_container.name = "PortraitContainer"
	portrait_container.custom_minimum_size = PORTRAIT_SIZE + Vector2(8, 8)

	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = COL_PORTRAIT_BG
	portrait_style.border_color = COL_BORDER
	portrait_style.set_border_width_all(2)
	portrait_style.set_content_margin_all(2)
	portrait_container.add_theme_stylebox_override("panel", portrait_style)
	parent.add_child(portrait_container)

	# Center container for the texture
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_container.add_child(center)

	portrait_texture_rect = TextureRect.new()
	portrait_texture_rect.name = "PortraitTexture"
	portrait_texture_rect.custom_minimum_size = PORTRAIT_SIZE
	portrait_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # PS1 pixel look
	center.add_child(portrait_texture_rect)


func _build_skill_check_overlay() -> void:
	skill_check_overlay = PanelContainer.new()
	skill_check_overlay.name = "SkillCheckOverlay"
	skill_check_overlay.set_anchors_preset(Control.PRESET_CENTER)
	skill_check_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	skill_check_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	skill_check_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var overlay_style := StyleBoxFlat.new()
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
	var btn := Button.new()
	btn.name = "Choice%d" % (index + 1)
	btn.text = "[%d] Choice text" % (index + 1)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.clip_text = true
	btn.custom_minimum_size = Vector2(0, 28)
	btn.pressed.connect(_on_choice_pressed.bind(index))
	_style_choice_button(btn)
	btn.visible = false
	return btn


func _style_choice_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COL_PANEL
	normal.border_color = COL_BORDER
	normal.set_border_width_all(1)
	normal.set_content_margin_all(6)

	var hover := StyleBoxFlat.new()
	hover.bg_color = COL_SELECT
	hover.border_color = COL_GOLD
	hover.set_border_width_all(1)
	hover.set_content_margin_all(6)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = COL_SELECT
	pressed.border_color = COL_GOLD
	pressed.set_border_width_all(2)
	pressed.set_content_margin_all(6)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.1, 0.1, 0.1)
	disabled.border_color = COL_DIM
	disabled.set_border_width_all(1)
	disabled.set_content_margin_all(6)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", COL_GOLD)
	btn.add_theme_color_override("font_pressed_color", COL_GOLD)
	btn.add_theme_color_override("font_disabled_color", COL_UNAVAILABLE)
	btn.add_theme_font_size_override("font_size", 11)


# =============================================================================
# UI STATE MANAGEMENT
# =============================================================================

func _show_ui() -> void:
	root_control.visible = true
	is_open = true

	# Register with TakeoverManager if available
	if TakeoverManager:
		TakeoverManager.start_dialogue(self)
	else:
		# Fallback to direct GameManager control
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	call_deferred("_focus_first_button")


func _hide_ui() -> void:
	root_control.visible = false
	is_open = false
	is_typing = false
	skip_typewriter = false
	is_showing_skill_check = false
	pending_skill_check_choice = -1

	if skill_check_overlay:
		skill_check_overlay.visible = false

	# Unregister with TakeoverManager if available
	if TakeoverManager:
		TakeoverManager.end_dialogue()
	else:
		# Fallback to direct control
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _focus_first_button() -> void:
	for btn in choice_buttons:
		if btn.visible and not btn.disabled:
			btn.grab_focus()
			break


func _close_dialogue() -> void:
	if DialogueManager:
		DialogueManager.end_dialogue()


# =============================================================================
# TYPEWRITER EFFECT
# =============================================================================

func _start_typewriter(text: String) -> void:
	full_text = text
	visible_chars = 0
	typewriter_timer = 0.0
	is_typing = true
	skip_typewriter = false

	text_label.text = text

	if typewriter_enabled:
		text_label.visible_characters = 0
	else:
		text_label.visible_characters = -1
		is_typing = false
		_on_typing_complete()

	choice_container.visible = false
	continue_indicator.visible = false


func _complete_typewriter() -> void:
	skip_typewriter = true
	visible_chars = full_text.length()
	text_label.visible_characters = visible_chars
	is_typing = false
	_on_typing_complete()


func _on_typing_complete() -> void:
	text_label.visible_characters = -1
	_update_choices()
	call_deferred("_focus_first_button")


# =============================================================================
# CHOICE MANAGEMENT
# =============================================================================

func _update_choices() -> void:
	if not DialogueManager:
		return

	var available_choices := DialogueManager.get_available_choices()

	if available_choices.is_empty():
		choice_container.visible = false
		continue_indicator.visible = true

		if DialogueManager.is_at_end_node():
			continue_indicator.text = "[E] End Conversation"
		else:
			continue_indicator.text = "[E] Continue"
	else:
		choice_container.visible = true
		continue_indicator.visible = false

		for i in range(choice_buttons.size()):
			var btn: Button = choice_buttons[i]

			if i < available_choices.size():
				var choice: DialogueChoice = available_choices[i]
				var is_available := DialogueManager.is_choice_available(choice)

				btn.visible = true
				btn.text = "[%d] %s" % [i + 1, choice.text]
				btn.disabled = not is_available

				if not is_available:
					var reason := DialogueManager.get_choice_unavailable_reason(choice)
					btn.tooltip_text = reason
					btn.text = "[%d] %s (%s)" % [i + 1, choice.text, reason]
				else:
					btn.tooltip_text = ""
			else:
				btn.visible = false


func _has_no_choices() -> bool:
	if not DialogueManager:
		return true
	var available := DialogueManager.get_available_choices()
	return available.is_empty()


func _on_choice_pressed(index: int) -> void:
	if is_typing or is_showing_skill_check:
		return

	if not DialogueManager:
		return

	var available_choices := DialogueManager.get_available_choices()
	if index < available_choices.size():
		var choice: DialogueChoice = available_choices[index]

		# Check for skill check action
		var has_skill_check := false
		for action in choice.actions:
			if action.type == DialogueData.ActionType.SKILL_CHECK:
				has_skill_check = true
				break

		if has_skill_check:
			DialogueManager.select_choice(index, true)
			return

	DialogueManager.select_choice(index)


# =============================================================================
# PORTRAIT MANAGEMENT
# =============================================================================

## Set the portrait texture (can be null to hide portrait)
func set_portrait(texture: Texture2D) -> void:
	current_portrait = texture
	portrait_texture_rect.texture = texture
	portrait_container.visible = (texture != null)


## Load and set portrait from a path
func set_portrait_from_path(path: String) -> void:
	if path.is_empty():
		set_portrait(null)
		return

	# Check cache first
	if _portrait_cache.has(path):
		set_portrait(_portrait_cache[path])
		return

	# Load and cache
	var texture: Texture2D = load(path) as Texture2D
	if texture:
		_portrait_cache[path] = texture
		set_portrait(texture)
	else:
		push_warning("[NPCDialogueUI] Failed to load portrait: %s" % path)
		set_portrait(null)


## Load portrait by NPC ID (looks in standard portrait directory)
func set_portrait_for_npc(npc_id: String) -> void:
	if npc_id.is_empty():
		set_portrait(null)
		return

	var portrait_path := "res://assets/portraits/%s.png" % npc_id
	if ResourceLoader.exists(portrait_path):
		set_portrait_from_path(portrait_path)
	else:
		# Try alternate locations
		portrait_path = "res://assets/ui/portraits/%s.png" % npc_id
		if ResourceLoader.exists(portrait_path):
			set_portrait_from_path(portrait_path)
		else:
			set_portrait(null)


## Clear portrait cache (for memory management)
func clear_portrait_cache() -> void:
	_portrait_cache.clear()


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

	choice_container.visible = false
	continue_indicator.visible = false


func _hide_skill_check_overlay() -> void:
	skill_check_overlay.visible = false
	is_showing_skill_check = false

	if DialogueManager and DialogueManager.has_delayed_transition():
		DialogueManager.complete_delayed_transition()


# =============================================================================
# DIALOGUE MANAGER SIGNAL HANDLERS
# =============================================================================

func _on_dialogue_started(_dialogue_data: DialogueData, speaker_name: String) -> void:
	name_label.text = speaker_name.to_upper()
	_show_ui()


func _on_dialogue_ended(_dialogue_data: DialogueData) -> void:
	_hide_ui()
	if is_showing_skill_check:
		skill_check_overlay.visible = false
		is_showing_skill_check = false


func _on_node_changed(node: DialogueNode) -> void:
	if not node:
		return

	# Update speaker name
	var speaker := DialogueManager.get_current_speaker()
	if not speaker.is_empty():
		name_label.text = speaker.to_upper()

	# Update portrait if node has portrait_id
	var portrait_id := DialogueManager.get_current_portrait()
	if not portrait_id.is_empty():
		set_portrait_for_npc(portrait_id)

	# Start typewriter effect
	_start_typewriter(node.text)


func _on_skill_check_performed(skill: int, dc: float, success: bool, roll_data: Dictionary) -> void:
	var skill_name: String = _get_skill_name(skill)

	if roll_data.has("modifiers"):
		var modifiers: Array = roll_data.modifiers
		if modifiers.size() >= 2:
			var skill_mod: Dictionary = modifiers[1]
			if skill_mod.has("name"):
				skill_name = skill_mod.name

	var roll_total: int = roll_data.get("total", 0)
	_show_skill_check_overlay(skill_name, roll_total, int(dc), success)


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
# PUBLIC API
# =============================================================================

## Enable or disable typewriter effect
func set_typewriter_enabled(enabled: bool) -> void:
	typewriter_enabled = enabled


## Get whether the dialogue UI is currently open
func is_dialogue_open() -> bool:
	return is_open


## Manually show a dialogue message (for simple messages without DialogueManager)
func show_message(speaker_name: String, message: String, portrait: Texture2D = null) -> void:
	name_label.text = speaker_name.to_upper()
	set_portrait(portrait)
	_start_typewriter(message)
	_show_ui()


## Hide the dialogue UI
func hide_dialogue() -> void:
	_hide_ui()
