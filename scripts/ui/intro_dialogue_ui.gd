## intro_dialogue_ui.gd - Centered intro dialogue box for new game
## Features: centered panel, typewriter effect, Accept button, dismiss on click/movement
class_name IntroDialogueUI
extends CanvasLayer

## Dark gothic colors
const COL_BG = Color(0.08, 0.08, 0.1, 0.95)
const COL_BORDER = Color(0.4, 0.35, 0.25)
const COL_TEXT = Color(0.9, 0.85, 0.75)
const COL_GOLD = Color(0.9, 0.7, 0.4)
const COL_PANEL = Color(0.12, 0.12, 0.15)

## Typewriter settings
const TYPEWRITER_SPEED := 0.02
const TYPEWRITER_FAST_SPEED := 0.002

## Signals
signal dialogue_finished

## UI elements
var root_control: Control
var panel: PanelContainer
var text_label: RichTextLabel
var accept_button: Button

## State
var is_open: bool = false
var is_typing: bool = false
var full_text: String = ""
var visible_chars: int = 0
var typewriter_timer: float = 0.0
var text_complete: bool = false
var player_initial_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide_ui()


func _process(delta: float) -> void:
	if not is_open:
		return

	# Handle typewriter effect
	if is_typing:
		typewriter_timer += delta
		var speed := TYPEWRITER_SPEED

		while typewriter_timer >= speed and visible_chars < full_text.length():
			typewriter_timer -= speed
			visible_chars += 1
			text_label.visible_characters = visible_chars

		if visible_chars >= full_text.length():
			_complete_typing()

	# Check for player movement to dismiss (only after text complete)
	if text_complete and _has_player_moved():
		_dismiss()


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	# Handle click or interact
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if is_typing:
			# First click - complete the text
			_complete_typing()
		elif text_complete:
			# Second click - dismiss
			_dismiss()
		get_viewport().set_input_as_handled()
		return

	# Handle mouse click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_typing:
			_complete_typing()
		elif text_complete:
			_dismiss()
		get_viewport().set_input_as_handled()
		return

	# Block escape during intro
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		return


func _build_ui() -> void:
	# Root control for full screen
	root_control = Control.new()
	root_control.name = "IntroDialogueRoot"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks behind
	add_child(root_control)

	# Semi-transparent background
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	root_control.add_child(bg)

	# Centered panel container
	var center_container = CenterContainer.new()
	center_container.name = "CenterContainer"
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_PASS
	root_control.add_child(center_container)

	# Main panel - centered, fixed width
	panel = PanelContainer.new()
	panel.name = "IntroPanel"
	panel.custom_minimum_size = Vector2(700, 0)  # Fixed width, auto height
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = COL_BG
	panel_style.border_color = COL_BORDER
	panel_style.set_border_width_all(3)
	panel_style.set_content_margin_all(25)
	panel_style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", panel_style)
	center_container.add_child(panel)

	# Vertical layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "YOUR JOURNEY BEGINS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	# Separator
	var sep = HSeparator.new()
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = COL_BORDER
	sep_style.set_content_margin_all(1)
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Text area
	text_label = RichTextLabel.new()
	text_label.name = "IntroText"
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.custom_minimum_size = Vector2(650, 150)
	text_label.add_theme_color_override("default_color", COL_TEXT)
	text_label.add_theme_font_size_override("normal_font_size", 14)
	text_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(text_label)

	# Bottom container for button and hint
	var bottom_box = VBoxContainer.new()
	bottom_box.add_theme_constant_override("separation", 10)
	vbox.add_child(bottom_box)

	# Accept button - centered
	var btn_container = CenterContainer.new()
	bottom_box.add_child(btn_container)

	accept_button = Button.new()
	accept_button.name = "AcceptButton"
	accept_button.text = "  Accept  "
	accept_button.custom_minimum_size = Vector2(150, 40)
	accept_button.focus_mode = Control.FOCUS_ALL
	accept_button.mouse_filter = Control.MOUSE_FILTER_STOP
	accept_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	accept_button.pressed.connect(_on_accept_pressed)
	accept_button.visible = false  # Hidden until text complete
	_style_button(accept_button)
	btn_container.add_child(accept_button)

	# Click hint
	var hint = Label.new()
	hint.name = "ClickHint"
	hint.text = "Click or press [E] to continue"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.add_theme_font_size_override("font_size", 11)
	bottom_box.add_child(hint)


func _style_button(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = COL_PANEL
	normal.border_color = COL_BORDER
	normal.set_border_width_all(2)
	normal.set_content_margin_all(10)
	normal.set_corner_radius_all(3)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.16, 0.14)
	hover.border_color = COL_GOLD
	hover.set_border_width_all(2)
	hover.set_content_margin_all(10)
	hover.set_corner_radius_all(3)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.25, 0.22, 0.18)
	pressed.border_color = COL_GOLD
	pressed.set_border_width_all(2)
	pressed.set_content_margin_all(10)
	pressed.set_corner_radius_all(3)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", COL_GOLD)
	btn.add_theme_color_override("font_pressed_color", COL_GOLD)
	btn.add_theme_font_size_override("font_size", 14)


func show_intro(text: String) -> void:
	full_text = text
	visible_chars = 0
	typewriter_timer = 0.0
	is_typing = true
	text_complete = false

	text_label.text = text
	text_label.visible_characters = 0
	accept_button.visible = false

	# Store player position for movement detection
	_store_player_position()

	root_control.visible = true
	is_open = true

	# Pause game and show cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GameManager.set_menu_cursor()
	get_tree().paused = true


func hide_ui() -> void:
	root_control.visible = false
	is_open = false
	is_typing = false
	text_complete = false

	# Unpause and restore cursor
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameManager.set_default_cursor()


func _complete_typing() -> void:
	is_typing = false
	visible_chars = full_text.length()
	text_label.visible_characters = -1  # Show all
	text_complete = true
	accept_button.visible = true
	accept_button.grab_focus()


func _dismiss() -> void:
	hide_ui()
	dialogue_finished.emit()


func _on_accept_pressed() -> void:
	_dismiss()


func _store_player_position() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player_initial_pos = player.global_position


func _has_player_moved() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return false

	var current_pos: Vector3 = player.global_position
	var distance: float = player_initial_pos.distance_to(current_pos)
	return distance > 0.5  # Threshold for movement detection
