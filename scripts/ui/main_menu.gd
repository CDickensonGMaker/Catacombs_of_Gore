## main_menu.gd - Main menu with New Game, Continue, Load Game options
extends Control

## Colors matching title screen
const TITLE_COLOR := Color(0.8, 0.1, 0.1)
const SUBTITLE_COLOR := Color(0.7, 0.65, 0.55)
const BUTTON_NORMAL := Color(0.15, 0.12, 0.1)
const BUTTON_HOVER := Color(0.25, 0.15, 0.12)
const BUTTON_DISABLED := Color(0.1, 0.1, 0.1)

## UI References
var menu_container: VBoxContainer
var continue_button: Button
var load_game_panel: Panel
var save_list_container: VBoxContainer
var fade_overlay: ColorRect

## State
var is_transitioning: bool = false

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

	# Decorative blood drips on sides (static)
	_create_decorative_drips()

	# Title at top
	var title_container := VBoxContainer.new()
	title_container.name = "TitleContainer"
	title_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_container.anchor_top = 0.08
	title_container.anchor_bottom = 0.08
	title_container.offset_left = -200
	title_container.offset_right = 200
	title_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(title_container)

	var title_label := Label.new()
	title_label.text = "CATACOMBS OF GORE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", TITLE_COLOR)
	title_label.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.0))
	title_label.add_theme_constant_override("outline_size", 3)
	title_container.add_child(title_label)

	# Menu container (centered)
	menu_container = VBoxContainer.new()
	menu_container.name = "MenuContainer"
	menu_container.set_anchors_preset(Control.PRESET_CENTER)
	menu_container.offset_left = -140
	menu_container.offset_right = 140
	menu_container.offset_top = -80
	menu_container.offset_bottom = 120
	menu_container.add_theme_constant_override("separation", 15)
	add_child(menu_container)

	# NEW GAME button
	var new_game_btn := _create_menu_button("NEW GAME")
	new_game_btn.pressed.connect(_on_new_game)
	menu_container.add_child(new_game_btn)

	# CONTINUE button (loads last autosave)
	continue_button = _create_menu_button("CONTINUE")
	continue_button.pressed.connect(_on_continue)
	menu_container.add_child(continue_button)

	# Check if autosave exists
	_update_continue_button()

	# LOAD GAME button
	var load_btn := _create_menu_button("LOAD GAME")
	load_btn.pressed.connect(_on_load_game)
	menu_container.add_child(load_btn)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	menu_container.add_child(spacer)

	# QUIT button
	var quit_btn := _create_menu_button("QUIT")
	quit_btn.pressed.connect(_on_quit)
	menu_container.add_child(quit_btn)

	# Create load game panel (hidden by default)
	_create_load_game_panel()

	# Fade overlay
	fade_overlay = ColorRect.new()
	fade_overlay.name = "FadeOverlay"
	fade_overlay.color = Color(0, 0, 0, 1)  # Start black
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_overlay)

	# Fade in from black
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, 0.5)

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


func _create_menu_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 50)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", SUBTITLE_COLOR)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))

	# Create stylebox for normal state
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = BUTTON_NORMAL
	style_normal.border_color = Color(0.4, 0.2, 0.15)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(4)
	style_normal.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", style_normal)

	# Hover state
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = BUTTON_HOVER
	style_hover.border_color = Color(0.6, 0.3, 0.2)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(4)
	style_hover.set_content_margin_all(10)
	btn.add_theme_stylebox_override("hover", style_hover)

	# Pressed state
	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.3, 0.15, 0.1)
	style_pressed.border_color = Color(0.7, 0.35, 0.25)
	style_pressed.set_border_width_all(2)
	style_pressed.set_corner_radius_all(4)
	style_pressed.set_content_margin_all(10)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	# Disabled state
	var style_disabled := StyleBoxFlat.new()
	style_disabled.bg_color = BUTTON_DISABLED
	style_disabled.border_color = Color(0.2, 0.2, 0.2)
	style_disabled.set_border_width_all(2)
	style_disabled.set_corner_radius_all(4)
	style_disabled.set_content_margin_all(10)
	btn.add_theme_stylebox_override("disabled", style_disabled)

	return btn


func _create_decorative_drips() -> void:
	# Create static blood drip decorations on the sides
	var drip_canvas := Control.new()
	drip_canvas.name = "DecorativeDrips"
	drip_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	drip_canvas.draw.connect(_draw_decorative_drips.bind(drip_canvas))
	add_child(drip_canvas)


func _draw_decorative_drips(canvas: Control) -> void:
	var viewport_size := get_viewport_rect().size
	var blood_color := Color(0.5, 0.05, 0.05, 0.6)

	# Left side drips
	var left_drip_x := [30.0, 50.0, 75.0, 45.0, 60.0]
	var left_drip_lengths := [150.0, 200.0, 120.0, 180.0, 90.0]

	for i in range(left_drip_x.size()):
		var x: float = left_drip_x[i]
		var length: float = left_drip_lengths[i]
		canvas.draw_line(Vector2(x, 0), Vector2(x, length), blood_color, 3.0)
		canvas.draw_circle(Vector2(x, length), 5.0, blood_color)

	# Right side drips
	for i in range(left_drip_x.size()):
		var x: float = viewport_size.x - left_drip_x[i]
		var length: float = left_drip_lengths[i] * 0.8
		canvas.draw_line(Vector2(x, 0), Vector2(x, length), blood_color, 3.0)
		canvas.draw_circle(Vector2(x, length), 5.0, blood_color)


func _create_load_game_panel() -> void:
	load_game_panel = Panel.new()
	load_game_panel.name = "LoadGamePanel"
	load_game_panel.set_anchors_preset(Control.PRESET_CENTER)
	load_game_panel.offset_left = -220
	load_game_panel.offset_right = 220
	load_game_panel.offset_top = -200
	load_game_panel.offset_bottom = 200
	load_game_panel.visible = false

	# Style the panel
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.06, 0.98)
	panel_style.border_color = Color(0.4, 0.2, 0.15)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(8)
	load_game_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(load_game_panel)

	# Title
	var panel_title := Label.new()
	panel_title.text = "LOAD GAME"
	panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel_title.offset_top = 15
	panel_title.offset_bottom = 45
	panel_title.add_theme_font_size_override("font_size", 24)
	panel_title.add_theme_color_override("font_color", TITLE_COLOR)
	load_game_panel.add_child(panel_title)

	# Scroll container for save list
	var scroll := ScrollContainer.new()
	scroll.name = "SaveScroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 15
	scroll.offset_right = -15
	scroll.offset_top = 55
	scroll.offset_bottom = -60
	load_game_panel.add_child(scroll)

	save_list_container = VBoxContainer.new()
	save_list_container.name = "SaveList"
	save_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_list_container.add_theme_constant_override("separation", 8)
	scroll.add_child(save_list_container)

	# Back button
	var back_btn := _create_menu_button("BACK")
	back_btn.custom_minimum_size = Vector2(120, 40)
	back_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back_btn.offset_left = -60
	back_btn.offset_right = 60
	back_btn.offset_top = -50
	back_btn.offset_bottom = -10
	back_btn.pressed.connect(_on_load_game_back)
	load_game_panel.add_child(back_btn)


func _update_continue_button() -> void:
	if continue_button:
		# Check both autosave slots, prefer exit autosave
		var has_autosave: bool = SaveManager.save_exists(SaveManager.AUTOSAVE_EXIT_SLOT) or SaveManager.save_exists(SaveManager.AUTOSAVE_PERIODIC_SLOT)
		continue_button.disabled = not has_autosave
		if not has_autosave:
			continue_button.tooltip_text = "No save data found"
		else:
			# Get info from exit autosave if available, otherwise periodic
			var slot_to_check: int = SaveManager.AUTOSAVE_EXIT_SLOT if SaveManager.save_exists(SaveManager.AUTOSAVE_EXIT_SLOT) else SaveManager.AUTOSAVE_PERIODIC_SLOT
			var save_info: Dictionary = SaveManager.get_save_info(slot_to_check)
			var char_name: String = save_info.get("character_name", "Unknown")
			var level: int = save_info.get("level", 1)
			continue_button.tooltip_text = "%s - Level %d" % [char_name, level]


func _populate_save_list() -> void:
	if not save_list_container:
		return

	# Clear existing entries
	for child in save_list_container.get_children():
		child.queue_free()

	# Get all saves
	var saves := SaveManager.get_all_save_infos()
	var has_any_save := false

	for save_info in saves:
		var slot: int = save_info.get("slot", -1)
		if save_info.get("empty", true):
			continue

		has_any_save = true

		var entry := _create_save_entry(save_info, slot)
		save_list_container.add_child(entry)

	if not has_any_save:
		var no_saves := Label.new()
		no_saves.text = "No saved games found"
		no_saves.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_saves.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		no_saves.add_theme_font_size_override("font_size", 16)
		save_list_container.add_child(no_saves)


func _create_save_entry(save_info: Dictionary, slot: int) -> Control:
	var entry := Button.new()

	var char_name: String = save_info.get("character_name", "Unknown")
	var level: int = save_info.get("level", 1)
	var location: String = save_info.get("location", "Unknown")
	var datetime: String = save_info.get("datetime", "")

	# Format slot name
	var slot_name: String = "Slot %d" % slot
	if slot == SaveManager.AUTOSAVE_EXIT_SLOT:
		slot_name = "Exit Autosave"
	elif slot == SaveManager.AUTOSAVE_PERIODIC_SLOT:
		slot_name = "30s Autosave"
	elif slot == 0:
		slot_name = "Quick Save"

	entry.text = "%s\n%s (Lv.%d) - %s" % [slot_name, char_name, level, location]
	entry.tooltip_text = datetime
	entry.custom_minimum_size = Vector2(400, 55)
	entry.add_theme_font_size_override("font_size", 14)

	# Style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08)
	style.border_color = Color(0.3, 0.2, 0.15)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	entry.add_theme_stylebox_override("normal", style)

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.2, 0.15, 0.1)
	style_hover.border_color = Color(0.5, 0.3, 0.2)
	style_hover.set_border_width_all(1)
	style_hover.set_corner_radius_all(4)
	style_hover.set_content_margin_all(8)
	entry.add_theme_stylebox_override("hover", style_hover)

	entry.pressed.connect(_on_load_slot.bind(slot))

	return entry


func _on_new_game() -> void:
	if is_transitioning:
		return
	is_transitioning = true

	# Reset game state for new game
	GameManager.reset_for_new_game()
	InventoryManager.reset_for_new_game()
	QuestManager.reset_for_new_game()
	SaveManager.reset_world_state()

	# DEV MODE: Skip character creation, create random character
	_create_random_character_and_start()


## DEV: Create a random character and start game directly (skips character creation)
func _create_random_character_and_start() -> void:
	var char_data := CharacterData.new()

	# Random race
	var races := [Enums.Race.HUMAN, Enums.Race.ELF, Enums.Race.DWARF, Enums.Race.HALFLING]
	char_data.race = races[randi() % races.size()]

	# Random name based on race
	var names := {
		Enums.Race.HUMAN: ["Aldric", "Bran", "Caden", "Darius", "Elena", "Freya"],
		Enums.Race.ELF: ["Aelindra", "Caelum", "Lyria", "Thalas", "Sylvana"],
		Enums.Race.DWARF: ["Thorin", "Gimrik", "Bolin", "Durin", "Helga"],
		Enums.Race.HALFLING: ["Pippin", "Merry", "Rosie", "Tuck", "Bramble"]
	}
	var race_names: Array = names.get(char_data.race, ["Stranger"])
	char_data.character_name = race_names[randi() % race_names.size()]

	# Apply racial bonuses
	char_data.initialize_race_bonuses()

	# Distribute some random stat points
	var bonus_points := 5
	var stats := ["grit", "agility", "will", "speech", "knowledge", "vitality"]
	for i in range(bonus_points):
		var stat: String = stats[randi() % stats.size()]
		char_data.set(stat, char_data.get(stat) + 1)

	# Recalculate derived stats and set to full
	char_data.recalculate_derived_stats()
	char_data.current_hp = char_data.max_hp
	char_data.current_stamina = char_data.max_stamina
	char_data.current_mana = char_data.max_mana

	# Set as active character
	GameManager.player_data = char_data

	# Give starting equipment
	InventoryManager.add_item("iron_sword", 1)
	InventoryManager.add_item("health_potion", 3)
	InventoryManager.add_item("lockpick", 5)
	InventoryManager.add_gold(100)

	print("[MainMenu] Quick start COMPLETE: %s the %s" % [char_data.character_name, Enums.Race.keys()[char_data.race]])

	# Start in Elder Moor
	_fade_to_scene("res://scenes/levels/elder_moor.tscn")


func _on_continue() -> void:
	if is_transitioning:
		return

	# Determine which autosave slot to load (prefer exit, fallback to periodic)
	var slot_to_load: int = -1
	if SaveManager.save_exists(SaveManager.AUTOSAVE_EXIT_SLOT):
		slot_to_load = SaveManager.AUTOSAVE_EXIT_SLOT
	elif SaveManager.save_exists(SaveManager.AUTOSAVE_PERIODIC_SLOT):
		slot_to_load = SaveManager.AUTOSAVE_PERIODIC_SLOT

	if slot_to_load < 0:
		return

	is_transitioning = true

	# Load the autosave
	if SaveManager.load_game(slot_to_load):
		var save_info: Dictionary = SaveManager.get_save_info(slot_to_load)
		if save_info.has("current_scene") and not save_info.current_scene.is_empty():
			_fade_to_scene(save_info.current_scene)
		else:
			# Fallback to Elder Moor if no scene saved
			_fade_to_scene("res://scenes/levels/elder_moor.tscn")


func _on_load_game() -> void:
	if is_transitioning:
		return

	_populate_save_list()
	load_game_panel.visible = true
	menu_container.visible = false


func _on_load_game_back() -> void:
	load_game_panel.visible = false
	menu_container.visible = true


func _on_load_slot(slot: int) -> void:
	if is_transitioning:
		return
	is_transitioning = true

	# Load the save
	if SaveManager.load_game(slot):
		var save_info := SaveManager.get_save_info(slot)
		if save_info.has("current_scene") and not save_info.current_scene.is_empty():
			_fade_to_scene(save_info.current_scene)
		else:
			_fade_to_scene("res://scenes/levels/elder_moor.tscn")


func _on_quit() -> void:
	if is_transitioning:
		return
	is_transitioning = true

	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.5)
	tween.tween_callback(get_tree().quit)


func _fade_to_scene(scene_path: String) -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.5)
	tween.tween_callback(func(): get_tree().change_scene_to_file(scene_path))


func _input(event: InputEvent) -> void:
	# ESC closes load game panel
	if event.is_action_pressed("ui_cancel"):
		if load_game_panel and load_game_panel.visible:
			_on_load_game_back()
			get_viewport().set_input_as_handled()
