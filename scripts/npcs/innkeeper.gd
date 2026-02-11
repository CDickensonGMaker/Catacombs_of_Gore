## innkeeper.gd - Tavern innkeeper NPC that sells food and offers room rental
## Extends Merchant to provide shop functionality plus rest/healing services
class_name Innkeeper
extends "res://scripts/world/merchant.gd"

## Sprite assets for random gender selection
const INNKEEPER_SPRITE_MALE := "res://Sprite folders grab bag/Innkeeper_man.png"
const INNKEEPER_SPRITE_FEMALE := "res://Sprite folders grab bag/Innkeeper_woman.png"

## Normalized pixel sizes (target height 2.46 units / frame height)
const PIXEL_SIZE_MALE := 0.0234  # ~105px frame height
const PIXEL_SIZE_FEMALE := 0.0378  # ~65px frame height

## Gender-specific names (optional - can be overridden via merchant_name export)
const MALE_NAMES: Array[String] = ["Gareth", "Brom", "Aldric", "Thom", "Willem"]
const FEMALE_NAMES: Array[String] = ["Marta", "Helga", "Greta", "Elspeth", "Brynn"]

## Track selected gender for reference
var is_male: bool = true

## Innkeeper-specific configuration
@export var room_cost: int = 25  # Gold cost to rent a room
@export var innkeeper_greeting: String = "Welcome to my tavern, traveler!"
@export var use_random_gender: bool = true  # Set false to use manual sprite assignment

## Rest UI reference
var rest_ui: Control = null

## Level up UI reference
var level_up_ui: Control = null
var xp_label: Label = null

## Track currently open panel for escape key handling
var current_panel: Control = null

## Bed references passed from inn_interior
var inn_beds: Array = []

## Reference to the inn level (for unlocking rental room)
var inn_level: Node = null

## Set the inn level reference
func set_inn_level(level: Node) -> void:
	inn_level = level

func _ready() -> void:
	# Setup random gender and sprite BEFORE parent _ready creates the visual
	if use_random_gender:
		_setup_random_gender()

	# Set innkeeper-specific npc_type before parent _ready registers with WorldData
	npc_type = "innkeeper"

	# Call parent _ready for basic merchant setup
	super._ready()

	# Add to innkeeper group
	add_to_group("innkeepers")

	# Override material color to be more tavern-like (warm brown)
	if merchant_material:
		merchant_material.albedo_color = Color(0.5, 0.35, 0.2)

	# Allow input processing while paused (for escape key)
	process_mode = Node.PROCESS_MODE_ALWAYS


## Setup random gender selection for sprite and optionally name
func _setup_random_gender() -> void:
	# Randomly choose gender
	is_male = randf() < 0.5

	# Load appropriate sprite texture
	var sprite_path: String = INNKEEPER_SPRITE_MALE if is_male else INNKEEPER_SPRITE_FEMALE
	var texture: Texture2D = load(sprite_path)

	if texture:
		# Set sprite properties for parent Merchant class to use
		sprite_texture = texture
		if is_male:
			sprite_h_frames = 4
			sprite_pixel_size = PIXEL_SIZE_MALE
		else:
			sprite_h_frames = 5  # Female sprite has 5 frames
			sprite_pixel_size = PIXEL_SIZE_FEMALE
		sprite_v_frames = 1  # Single row for both

	# Assign random gendered name if merchant_name is still default
	if merchant_name == "Merchant" or merchant_name == "Innkeeper":
		var names: Array[String] = MALE_NAMES if is_male else FEMALE_NAMES
		merchant_name = names[randi() % names.size()]


## Handle escape key to close menus
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if current_panel and is_instance_valid(current_panel):
			_close_menu()
			get_viewport().set_input_as_handled()


## Close the currently open menu (Escape key closes everything)
func _close_menu() -> void:
	# Close level up UI first if open
	if level_up_ui and is_instance_valid(level_up_ui):
		level_up_ui.queue_free()
		level_up_ui = null
		xp_label = null

	# Close the innkeeper/rest menu and restore game state
	_close_innkeeper_menu()

## Override to provide innkeeper-specific inventory (food and basic supplies)
func _setup_default_inventory() -> void:
	# Food items
	_add_shop_item("bread", 5, -1, Enums.ItemQuality.AVERAGE)  # Infinite stock
	_add_shop_item("cheese", 8, -1, Enums.ItemQuality.AVERAGE)
	_add_shop_item("cooked_meat", 15, -1, Enums.ItemQuality.AVERAGE)
	_add_shop_item("ale", 10, -1, Enums.ItemQuality.AVERAGE)

	# Basic potions
	_add_shop_item("health_potion", 50, -1, Enums.ItemQuality.AVERAGE)
	_add_shop_item("stamina_potion", 40, -1, Enums.ItemQuality.AVERAGE)
	_add_shop_item("antidote", 30, 10, Enums.ItemQuality.AVERAGE)

## Override interact to show innkeeper menu instead of direct shop
func interact(_interactor: Node) -> void:
	if dialogue_data:
		# Start dialogue first - dialogue can use OPEN_SHOP action with "inn_menu" to open innkeeper menu
		# Pass merchant_id context for per-merchant flag substitution
		var resolved_id: String = merchant_id if not merchant_id.is_empty() else merchant_name.to_snake_case()
		var context := {"merchant_id": resolved_id}
		DialogueManager.start_dialogue(dialogue_data, merchant_name, context)
		# Connect to dialogue_ended signal if not already connected
		if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
			DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	else:
		# No dialogue, open innkeeper menu directly
		_open_innkeeper_menu()

## Handle dialogue ending - check if we should open the innkeeper menu
func _on_dialogue_ended(_data: DialogueData) -> void:
	# Disconnect immediately to avoid repeat calls
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)

	# Check if dialogue requested opening the inn menu
	var pending_shop: String = DialogueManager.pop_pending_shop()
	if pending_shop == "inn_menu":
		_open_innkeeper_menu()

## Override interaction prompt
func get_interaction_prompt() -> String:
	return "Talk to " + merchant_name + " (Innkeeper)"

## Open the innkeeper menu with options
func _open_innkeeper_menu() -> void:
	if rest_ui and is_instance_valid(rest_ui):
		return  # Already open

	# Pause the game
	get_tree().paused = true
	GameManager.enter_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Create innkeeper menu UI
	rest_ui = _create_innkeeper_panel()
	current_panel = rest_ui  # Track for escape key

	# Add to CanvasLayer for proper rendering
	var canvas := CanvasLayer.new()
	canvas.name = "InnkeeperUICanvas"
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	canvas.add_child(rest_ui)

## Create the innkeeper menu panel
func _create_innkeeper_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "InnkeeperPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = -150
	panel.offset_bottom = 150
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	# Dark gothic style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06)
	style.border_color = Color(0.4, 0.3, 0.2)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = merchant_name.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	# Greeting
	var greeting := Label.new()
	greeting.text = innkeeper_greeting
	greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	greeting.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	greeting.add_theme_font_size_override("font_size", 14)
	vbox.add_child(greeting)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	vbox.add_child(spacer)

	# Menu buttons
	var browse_btn := Button.new()
	browse_btn.text = "Browse Wares"
	browse_btn.custom_minimum_size = Vector2(200, 40)
	browse_btn.pressed.connect(_on_browse_wares)
	browse_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(browse_btn)
	vbox.add_child(browse_btn)

	var rent_btn := Button.new()
	rent_btn.text = "Rent Room (%d gold)" % room_cost
	rent_btn.custom_minimum_size = Vector2(200, 40)
	rent_btn.pressed.connect(_on_rent_room)
	rent_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(rent_btn)
	vbox.add_child(rent_btn)

	# Show player gold
	var gold_label := Label.new()
	gold_label.text = "Your gold: %d" % InventoryManager.gold
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	gold_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(gold_label)

	var leave_btn := Button.new()
	leave_btn.text = "Leave"
	leave_btn.custom_minimum_size = Vector2(200, 40)
	leave_btn.pressed.connect(_close_innkeeper_menu)
	leave_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(leave_btn)
	vbox.add_child(leave_btn)

	return panel

## Style a button with tavern theme
func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.12, 0.08)
	normal.border_color = Color(0.4, 0.3, 0.2)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.3, 0.2, 0.12)
	hover.border_color = Color(0.9, 0.7, 0.4)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(0.9, 0.7, 0.4))

## Handle browse wares button
func _on_browse_wares() -> void:
	# Close innkeeper menu first
	_close_innkeeper_menu_silent()

	# Open the shop UI (from parent Merchant class)
	_open_shop_ui()

## Handle rent room button
func _on_rent_room() -> void:
	# Check if player has enough gold
	if InventoryManager.gold < room_cost:
		_show_notification("You don't have enough gold!")
		return

	# Deduct gold
	InventoryManager.remove_gold(room_cost)

	# Make the rental room bed available
	if inn_level and inn_level.has_method("make_bed_available"):
		inn_level.make_bed_available()

	# Close innkeeper menu and show rest options
	_close_innkeeper_menu_silent()
	_open_rest_options()

## Show notification
func _show_notification(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)

## Open rest options panel (heal or level up)
func _open_rest_options() -> void:
	rest_ui = _create_rest_options_panel()
	current_panel = rest_ui  # Track for escape key

	var canvas := CanvasLayer.new()
	canvas.name = "RestOptionsCanvas"
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	canvas.add_child(rest_ui)

## Create rest options panel
func _create_rest_options_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "RestOptionsPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = -120
	panel.offset_bottom = 120
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06)
	style.border_color = Color(0.4, 0.3, 0.2)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "YOUR ROOM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# Message
	var message := Label.new()
	message.text = "A warm bed awaits.\nWhat would you like to do?"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	vbox.add_child(message)

	# Buttons
	var btn_container := VBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_container)

	var rest_btn := Button.new()
	rest_btn.text = "Rest (Full Heal)"
	rest_btn.custom_minimum_size = Vector2(180, 35)
	rest_btn.pressed.connect(_on_rest_confirmed)
	rest_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(rest_btn)
	btn_container.add_child(rest_btn)

	var level_btn := Button.new()
	level_btn.text = "Level Up Skills"
	level_btn.custom_minimum_size = Vector2(180, 35)
	level_btn.pressed.connect(_open_level_up_ui)
	level_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(level_btn)
	btn_container.add_child(level_btn)

	var back_btn := Button.new()
	back_btn.text = "Leave Room"
	back_btn.custom_minimum_size = Vector2(180, 35)
	back_btn.pressed.connect(_close_innkeeper_menu)
	back_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(back_btn)
	btn_container.add_child(back_btn)

	return panel

## Handle rest confirmation - full heal
func _on_rest_confirmed() -> void:
	# Restore player resources
	if GameManager.player_data:
		GameManager.player_data.current_hp = GameManager.player_data.max_hp
		GameManager.player_data.current_mana = GameManager.player_data.max_mana
		GameManager.player_data.current_stamina = GameManager.player_data.max_stamina
		GameManager.player_data.current_spell_slots = GameManager.player_data.max_spell_slots

		# Clear temporary conditions
		GameManager.player_data.conditions.clear()

		# Track rest for save data
		SaveManager.increment_rest_count()

	# Show notification
	_show_notification("You feel well rested!")

	# Trigger autosave
	SaveManager.save_game(SaveManager.AUTOSAVE_EXIT_SLOT)

	# Play rest sound
	AudioManager.play_ui_confirm()

	# Close UI
	_close_innkeeper_menu()

## Open level up UI (similar to RestSpot)
func _open_level_up_ui() -> void:
	if level_up_ui:
		return  # Already open

	# Hide rest options while level up is open
	if rest_ui:
		rest_ui.visible = false

	level_up_ui = _create_level_up_panel()
	current_panel = level_up_ui  # Track for escape key

	# Add to existing canvas layer or create new one
	var canvas := get_node_or_null("RestOptionsCanvas")
	if not canvas:
		canvas = CanvasLayer.new()
		canvas.name = "LevelUpCanvas"
		canvas.layer = 100
		canvas.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(canvas)
	canvas.add_child(level_up_ui)

## Create the level up panel
func _create_level_up_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "LevelUpPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -220
	panel.offset_bottom = 220
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06)
	style.border_color = Color(0.4, 0.3, 0.2)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)

	# Header with title and XP
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(header)

	var title := Label.new()
	title.text = "SPEND XP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	xp_label = Label.new()
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	xp_label.add_theme_font_size_override("font_size", 16)
	_update_xp_label()
	header.add_child(xp_label)

	# Scroll container for stats and skills
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 350)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	main_vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(content_vbox)

	# Stats section
	var stats_label := Label.new()
	stats_label.text = "- STATS -"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	content_vbox.add_child(stats_label)

	for stat in Enums.Stat.values():
		var row := _create_stat_row(stat)
		content_vbox.add_child(row)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 15
	content_vbox.add_child(spacer)

	# Skills section
	var skills_label := Label.new()
	skills_label.text = "- SKILLS -"
	skills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skills_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	content_vbox.add_child(skills_label)

	for skill in Enums.Skill.values():
		var row := _create_skill_row(skill)
		content_vbox.add_child(row)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(100, 35)
	back_btn.pressed.connect(_close_level_up_ui)
	back_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(back_btn)
	main_vbox.add_child(back_btn)

	return panel

## Create a row for a stat
func _create_stat_row(stat: Enums.Stat) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var char_data := GameManager.player_data

	# Stat name
	var name_label := Label.new()
	name_label.text = _get_stat_name(stat)
	name_label.custom_minimum_size.x = 100
	name_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	row.add_child(name_label)

	# Current value
	var current_value := char_data.get_stat(stat) if char_data else 3
	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = str(current_value)
	value_label.custom_minimum_size.x = 30
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	row.add_child(value_label)

	# Cost
	var cost := char_data.get_stat_ip_cost(current_value) if char_data else 50
	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "(%d XP)" % cost if current_value < 15 else "(MAX)"
	cost_label.custom_minimum_size.x = 100
	cost_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	cost_label.add_theme_font_size_override("font_size", 12)
	row.add_child(cost_label)

	# Upgrade button
	var btn := Button.new()
	btn.name = "UpgradeBtn"
	btn.text = "+"
	btn.custom_minimum_size = Vector2(30, 25)
	btn.disabled = not char_data or char_data.improvement_points < cost or current_value >= 15
	btn.pressed.connect(_on_stat_upgrade.bind(stat, row))
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_small_button(btn)
	row.add_child(btn)

	return row

## Create a row for a skill
func _create_skill_row(skill: Enums.Skill) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var char_data := GameManager.player_data

	# Skill name
	var name_label := Label.new()
	name_label.text = _get_skill_name(skill)
	name_label.custom_minimum_size.x = 100
	name_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	row.add_child(name_label)

	# Current value
	var current_value := char_data.get_skill(skill) if char_data else 0
	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = str(current_value)
	value_label.custom_minimum_size.x = 30
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	row.add_child(value_label)

	# Cost
	var next_level := current_value + 1
	var cost := Enums.get_skill_ip_cost(next_level) if current_value < 10 else 0
	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "(%d XP)" % cost if current_value < 10 else "(MAX)"
	cost_label.custom_minimum_size.x = 100
	cost_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	cost_label.add_theme_font_size_override("font_size", 12)
	row.add_child(cost_label)

	# Upgrade button
	var btn := Button.new()
	btn.name = "UpgradeBtn"
	btn.text = "+"
	btn.custom_minimum_size = Vector2(30, 25)
	btn.disabled = not char_data or char_data.improvement_points < cost or current_value >= 10
	btn.pressed.connect(_on_skill_upgrade.bind(skill, row))
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_small_button(btn)
	row.add_child(btn)

	return row

## Handle stat upgrade
func _on_stat_upgrade(stat: Enums.Stat, row: HBoxContainer) -> void:
	var char_data := GameManager.player_data
	if not char_data:
		return

	if char_data.increase_stat(stat):
		AudioManager.play_ui_confirm()
		_update_stat_row(stat, row)
		_update_xp_label()
		_refresh_all_buttons()

## Handle skill upgrade
func _on_skill_upgrade(skill: Enums.Skill, row: HBoxContainer) -> void:
	var char_data := GameManager.player_data
	if not char_data:
		return

	if char_data.increase_skill(skill):
		AudioManager.play_ui_confirm()
		_update_skill_row(skill, row)
		_update_xp_label()
		_refresh_all_buttons()

## Update a stat row after upgrade
func _update_stat_row(stat: Enums.Stat, row: HBoxContainer) -> void:
	var char_data := GameManager.player_data
	if not char_data:
		return

	var current_value := char_data.get_stat(stat)
	var cost := char_data.get_stat_ip_cost(current_value)

	var value_label := row.get_node_or_null("ValueLabel") as Label
	if value_label:
		value_label.text = str(current_value)

	var cost_label := row.get_node_or_null("CostLabel") as Label
	if cost_label:
		cost_label.text = "(%d XP)" % cost if current_value < 15 else "(MAX)"

	var btn := row.get_node_or_null("UpgradeBtn") as Button
	if btn:
		btn.disabled = char_data.improvement_points < cost or current_value >= 15

## Update a skill row after upgrade
func _update_skill_row(skill: Enums.Skill, row: HBoxContainer) -> void:
	var char_data := GameManager.player_data
	if not char_data:
		return

	var current_value := char_data.get_skill(skill)
	var next_level := current_value + 1
	var cost := Enums.get_skill_ip_cost(next_level) if current_value < 10 else 0

	var value_label := row.get_node_or_null("ValueLabel") as Label
	if value_label:
		value_label.text = str(current_value)

	var cost_label := row.get_node_or_null("CostLabel") as Label
	if cost_label:
		cost_label.text = "(%d XP)" % cost if current_value < 10 else "(MAX)"

	var btn := row.get_node_or_null("UpgradeBtn") as Button
	if btn:
		btn.disabled = char_data.improvement_points < cost or current_value >= 10

## Update XP label
func _update_xp_label() -> void:
	if xp_label and GameManager.player_data:
		xp_label.text = "XP: %d" % GameManager.player_data.improvement_points

## Refresh all upgrade buttons (after spending XP)
func _refresh_all_buttons() -> void:
	if not level_up_ui:
		return

	var char_data := GameManager.player_data
	if not char_data:
		return

	# Find all upgrade buttons and update their disabled state
	var scroll := level_up_ui.get_node_or_null("VBoxContainer/ScrollContainer")
	if not scroll:
		return

	var content := scroll.get_child(0)
	if not content:
		return

	for child in content.get_children():
		if child is HBoxContainer:
			var btn := child.get_node_or_null("UpgradeBtn") as Button
			var cost_label := child.get_node_or_null("CostLabel") as Label
			if btn and cost_label:
				var cost_text: String = cost_label.text
				if "(MAX)" in cost_text:
					btn.disabled = true
				else:
					# Parse cost from "(XXX XP)"
					var cost_str := cost_text.replace("(", "").replace(" XP)", "")
					var cost := int(cost_str) if cost_str.is_valid_int() else 99999
					btn.disabled = char_data.improvement_points < cost

## Close level up UI
func _close_level_up_ui() -> void:
	if level_up_ui:
		level_up_ui.queue_free()
		level_up_ui = null
		xp_label = null

	# Show rest panel again and update current_panel tracker
	if rest_ui:
		rest_ui.visible = true
		current_panel = rest_ui
	else:
		current_panel = null

## Style a small button
func _style_small_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.2, 0.15)
	normal.border_color = Color(0.3, 0.4, 0.3)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.2, 0.35, 0.2)
	hover.border_color = Color(0.5, 0.8, 0.5)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(3)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.1, 0.1, 0.1)
	disabled.border_color = Color(0.2, 0.2, 0.2)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(3)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	btn.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.7))
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))

## Get display name for stat
func _get_stat_name(stat: Enums.Stat) -> String:
	match stat:
		Enums.Stat.GRIT: return "Grit"
		Enums.Stat.AGILITY: return "Agility"
		Enums.Stat.WILL: return "Will"
		Enums.Stat.SPEECH: return "Speech"
		Enums.Stat.KNOWLEDGE: return "Knowledge"
		Enums.Stat.VITALITY: return "Vitality"
		_: return "Unknown"

## Get display name for skill
func _get_skill_name(skill: Enums.Skill) -> String:
	match skill:
		Enums.Skill.MELEE: return "Melee"
		Enums.Skill.RANGED: return "Ranged"
		Enums.Skill.DODGE: return "Dodge"
		Enums.Skill.STEALTH: return "Stealth"
		Enums.Skill.ARCANA_LORE: return "Arcana"
		Enums.Skill.FIRST_AID: return "First Aid"
		Enums.Skill.ENDURANCE: return "Endurance"
		Enums.Skill.ATHLETICS: return "Athletics"
		Enums.Skill.PERCEPTION: return "Perception"
		Enums.Skill.INTIMIDATION: return "Intimidation"
		Enums.Skill.PERSUASION: return "Persuasion"
		Enums.Skill.DECEPTION: return "Deception"
		Enums.Skill.LOCKPICKING: return "Lockpicking"
		Enums.Skill.ALCHEMY: return "Alchemy"
		Enums.Skill.SMITHING: return "Smithing"
		Enums.Skill.SURVIVAL: return "Survival"
		Enums.Skill.HISTORY: return "History"
		Enums.Skill.RELIGION: return "Religion"
		Enums.Skill.NATURE: return "Nature"
		Enums.Skill.INVESTIGATION: return "Investigation"
		Enums.Skill.ACROBATICS: return "Acrobatics"
		Enums.Skill.BRAVERY: return "Bravery"
		_: return "Unknown"

## Close innkeeper menu without resuming game (for transitioning to sub-menus)
func _close_innkeeper_menu_silent() -> void:
	if rest_ui:
		var canvas := rest_ui.get_parent()
		rest_ui.queue_free()
		if canvas:
			canvas.queue_free()
		rest_ui = null
		current_panel = null

## Close innkeeper menu and resume game
func _close_innkeeper_menu() -> void:
	# Close level up UI if open
	if level_up_ui:
		level_up_ui.queue_free()
		level_up_ui = null
		xp_label = null

	# Close main menu
	if rest_ui:
		var canvas := rest_ui.get_parent()
		rest_ui.queue_free()
		if canvas:
			canvas.queue_free()
		rest_ui = null

	# Clear panel tracker
	current_panel = null

	# Clean up any remaining canvases
	var innkeeper_canvas := get_node_or_null("InnkeeperUICanvas")
	if innkeeper_canvas:
		innkeeper_canvas.queue_free()
	var rest_canvas := get_node_or_null("RestOptionsCanvas")
	if rest_canvas:
		rest_canvas.queue_free()
	var level_canvas := get_node_or_null("LevelUpCanvas")
	if level_canvas:
		level_canvas.queue_free()

	# Unpause and return control
	get_tree().paused = false
	GameManager.exit_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Static factory method for spawning innkeepers
static func spawn_innkeeper(parent: Node, pos: Vector3, name: String = "Innkeeper") -> Innkeeper:
	var instance := Innkeeper.new()
	instance.position = pos
	instance.merchant_name = name

	# Add collision shape for world collision
	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	col_shape.shape = capsule
	col_shape.position = Vector3(0, 0.9, 0)
	instance.add_child(col_shape)

	parent.add_child(instance)
	return instance
