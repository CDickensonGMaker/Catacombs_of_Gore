## title_screen.gd - Game title screen with dripping blood effect
extends Control

## Drip configuration
const DRIP_COUNT := 15
const DRIP_MIN_LENGTH := 20.0
const DRIP_MAX_LENGTH := 80.0
const DRIP_MIN_SPEED := 30.0
const DRIP_MAX_SPEED := 80.0
const DRIP_WIDTH := 3.0

## Colors
const BLOOD_COLOR := Color(0.6, 0.05, 0.05)
const BLOOD_COLOR_DARK := Color(0.4, 0.02, 0.02)
const TITLE_COLOR := Color(0.8, 0.1, 0.1)
const SUBTITLE_COLOR := Color(0.7, 0.65, 0.55)

## State
var drips: Array[Dictionary] = []
var title_label: Label
var subtitle_label: Label
var press_start_label: Label
var press_start_timer: float = 0.0
var can_proceed: bool = false
var fade_overlay: ColorRect
var is_fading: bool = false

## Title text positions for drip spawning
var title_bottom_y: float = 0.0
var title_left_x: float = 0.0
var title_right_x: float = 0.0

func _ready() -> void:
	# Set up full screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Dark background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Blood drip canvas (drawn behind title)
	var drip_canvas := Control.new()
	drip_canvas.name = "DripCanvas"
	drip_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	drip_canvas.draw.connect(_draw_drips.bind(drip_canvas))
	add_child(drip_canvas)

	# Title container (centered)
	var title_container := VBoxContainer.new()
	title_container.name = "TitleContainer"
	title_container.set_anchors_preset(Control.PRESET_CENTER)
	title_container.anchor_left = 0.5
	title_container.anchor_right = 0.5
	title_container.anchor_top = 0.35
	title_container.anchor_bottom = 0.35
	title_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(title_container)

	# Main title - "CATACOMBS"
	var title_top := Label.new()
	title_top.name = "TitleTop"
	title_top.text = "CATACOMBS"
	title_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_top.add_theme_font_size_override("font_size", 72)
	title_top.add_theme_color_override("font_color", TITLE_COLOR)
	title_top.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.0))
	title_top.add_theme_constant_override("outline_size", 4)
	title_container.add_child(title_top)

	# "OF" text
	var title_of := Label.new()
	title_of.name = "TitleOf"
	title_of.text = "OF"
	title_of.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_of.add_theme_font_size_override("font_size", 36)
	title_of.add_theme_color_override("font_color", SUBTITLE_COLOR)
	title_of.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	title_of.add_theme_constant_override("outline_size", 2)
	title_container.add_child(title_of)

	# "GORE" text
	title_label = Label.new()
	title_label.name = "TitleBottom"
	title_label.text = "GORE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 96)
	title_label.add_theme_color_override("font_color", TITLE_COLOR)
	title_label.add_theme_color_override("font_outline_color", Color(0.2, 0.0, 0.0))
	title_label.add_theme_constant_override("outline_size", 6)
	title_container.add_child(title_label)

	# Press Start label
	press_start_label = Label.new()
	press_start_label.name = "PressStart"
	press_start_label.text = "PRESS ANY KEY"
	press_start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press_start_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	press_start_label.anchor_top = 0.85
	press_start_label.anchor_bottom = 0.85
	press_start_label.offset_left = -200
	press_start_label.offset_right = 200
	press_start_label.add_theme_font_size_override("font_size", 24)
	press_start_label.add_theme_color_override("font_color", SUBTITLE_COLOR)
	press_start_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	press_start_label.add_theme_constant_override("outline_size", 2)
	press_start_label.modulate.a = 0.0  # Start invisible
	add_child(press_start_label)

	# Version label
	var version_label := Label.new()
	version_label.name = "Version"
	version_label.text = "v" + ProjectSettings.get_setting("application/config/version", "1.0.0")
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version_label.offset_left = -100
	version_label.offset_right = -10
	version_label.offset_top = -30
	version_label.offset_bottom = -10
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	add_child(version_label)

	# Fade overlay (for transition)
	fade_overlay = ColorRect.new()
	fade_overlay.name = "FadeOverlay"
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_overlay)

	# Initialize drips after a short delay to get proper positions
	call_deferred("_initialize_drips")

	# Enable input after a delay
	get_tree().create_timer(1.5).timeout.connect(func(): can_proceed = true)

	# Fade in press start text
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(press_start_label, "modulate:a", 1.0, 0.5)


func _initialize_drips() -> void:
	# Get title position for drip spawning
	await get_tree().process_frame
	await get_tree().process_frame

	var viewport_size := get_viewport_rect().size

	# Calculate where the title text is
	title_bottom_y = viewport_size.y * 0.35 + 120  # Approximate bottom of GORE text
	title_left_x = viewport_size.x * 0.5 - 180
	title_right_x = viewport_size.x * 0.5 + 180

	# Create initial drips
	for i in range(DRIP_COUNT):
		_spawn_drip(true)


func _spawn_drip(random_progress: bool = false) -> void:
	var viewport_size := get_viewport_rect().size

	# Spawn drips along the title text area
	var drip := {
		"x": randf_range(title_left_x, title_right_x),
		"y": title_bottom_y + randf_range(-10, 10),
		"length": randf_range(DRIP_MIN_LENGTH, DRIP_MAX_LENGTH),
		"speed": randf_range(DRIP_MIN_SPEED, DRIP_MAX_SPEED),
		"progress": 0.0 if not random_progress else randf(),
		"width": randf_range(DRIP_WIDTH * 0.7, DRIP_WIDTH * 1.3),
		"alpha": randf_range(0.6, 1.0)
	}

	if random_progress:
		drip.y += drip.progress * drip.length

	drips.append(drip)


func _process(delta: float) -> void:
	# Update drips
	var viewport_size := get_viewport_rect().size
	var drips_to_remove: Array[int] = []

	for i in range(drips.size()):
		var drip: Dictionary = drips[i]
		drip.progress += delta * drip.speed / drip.length
		drip.y += delta * drip.speed

		# Remove drips that have finished
		if drip.y > viewport_size.y + drip.length:
			drips_to_remove.append(i)

	# Remove finished drips (reverse order to preserve indices)
	for i in range(drips_to_remove.size() - 1, -1, -1):
		drips.remove_at(drips_to_remove[i])
		# Spawn a new drip to replace it
		_spawn_drip(false)

	# Redraw drips
	var drip_canvas := get_node_or_null("DripCanvas")
	if drip_canvas:
		drip_canvas.queue_redraw()

	# Pulse the "Press Start" text
	if can_proceed and press_start_label and not is_fading:
		press_start_timer += delta
		var pulse := 0.5 + 0.5 * sin(press_start_timer * 3.0)
		press_start_label.modulate.a = 0.5 + 0.5 * pulse


func _draw_drips(canvas: Control) -> void:
	for drip in drips:
		var start_y: float = drip.y
		var end_y: float = drip.y + drip.length * min(drip.progress * 2.0, 1.0)

		# Main drip line
		var color := BLOOD_COLOR
		color.a = drip.alpha
		canvas.draw_line(
			Vector2(drip.x, start_y),
			Vector2(drip.x, end_y),
			color,
			drip.width
		)

		# Drip head (thicker bulb at the bottom)
		var head_radius: float = drip.width * 1.5
		canvas.draw_circle(
			Vector2(drip.x, end_y),
			head_radius,
			color
		)

		# Darker edge/shadow
		var shadow_color := BLOOD_COLOR_DARK
		shadow_color.a = drip.alpha * 0.5
		canvas.draw_line(
			Vector2(drip.x + drip.width * 0.3, start_y),
			Vector2(drip.x + drip.width * 0.3, end_y),
			shadow_color,
			drip.width * 0.3
		)


func _input(event: InputEvent) -> void:
	if not can_proceed or is_fading:
		return

	# Any key or mouse button proceeds
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			_proceed_to_game()
			get_viewport().set_input_as_handled()


func _proceed_to_game() -> void:
	is_fading = true
	can_proceed = false

	# Play a sound if available
	if AudioManager and AudioManager.has_method("play_ui_select"):
		AudioManager.play_ui_select()

	# Fade to black then change scene
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.5)
	tween.tween_callback(_go_to_main_menu)


func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
