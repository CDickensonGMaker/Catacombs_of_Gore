## title_screen.gd - Game title screen with logo image
extends Control

## Colors
const SUBTITLE_COLOR := Color(0.7, 0.65, 0.55)

## State
var press_start_label: Label
var press_start_timer: float = 0.0
var can_proceed: bool = false
var fade_overlay: ColorRect
var is_fading: bool = false

## Title logo path
const TITLE_LOGO_PATH := "res://assets/ui/title_logo.png"

func _ready() -> void:
	# Make sure mouse is visible on title screen
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Use menu cursor on title screen
	if GameManager:
		GameManager.set_menu_cursor()

	# Play main menu music (loops automatically)
	if AudioManager:
		AudioManager.play_zone_music("menu")

	# Set up full screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Dark background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title logo image (stretched full screen with pixelated look)
	if ResourceLoader.exists(TITLE_LOGO_PATH):
		var logo := TextureRect.new()
		logo.name = "TitleLogo"
		logo.texture = load(TITLE_LOGO_PATH)
		logo.set_anchors_preset(Control.PRESET_FULL_RECT)
		logo.stretch_mode = TextureRect.STRETCH_SCALE
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Pixelated look - nearest neighbor filtering
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(logo)

	# Press Start label
	press_start_label = Label.new()
	press_start_label.name = "PressStart"
	press_start_label.text = "CLICK TO CONTINUE"
	press_start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press_start_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	press_start_label.anchor_top = 0.88
	press_start_label.anchor_bottom = 0.88
	press_start_label.offset_left = -200
	press_start_label.offset_right = 200
	press_start_label.add_theme_font_size_override("font_size", 20)
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

	# Enable input after a delay
	get_tree().create_timer(1.0).timeout.connect(func(): can_proceed = true)

	# Fade in press start text
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(press_start_label, "modulate:a", 1.0, 0.5)


func _process(delta: float) -> void:
	# Pulse the "Click to Continue" text
	if can_proceed and press_start_label and not is_fading:
		press_start_timer += delta
		var pulse := 0.5 + 0.5 * sin(press_start_timer * 3.0)
		press_start_label.modulate.a = 0.5 + 0.5 * pulse


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
