## character_creation.gd - Character creation screen
class_name CharacterCreation
extends Control

signal character_created

# Background image
const BG_TEXTURE_PATH := "res://assets/ui/char_creation_bg.png"

# Dark gothic colors (matching game_menu)
const COL_BG = Color(0.08, 0.08, 0.1)
const COL_PANEL = Color(0.12, 0.12, 0.15, 0.85)  # Slightly transparent for layering
const COL_BORDER = Color(0.3, 0.25, 0.2)
const COL_TEXT = Color(0.9, 0.85, 0.75)
const COL_DIM = Color(0.5, 0.5, 0.5)
const COL_GOLD = Color(0.8, 0.6, 0.2)
const COL_SELECT = Color(0.25, 0.2, 0.15)
const COL_RED = Color(0.8, 0.3, 0.3)

# Race data
const RACE_DATA = {
	Enums.Race.HUMAN: {
		"name": "Human",
		"description": "Versatile and adaptable, humans thrive in any role. Their determination and ambition drive them to excel where other races might falter.",
		"bonuses": "+1d4 Grit, Will, Speech",
		"traits": "Adaptable, Determined, Ambitious"
	},
	Enums.Race.ELF: {
		"name": "Elf",
		"description": "Graceful and long-lived, elves possess an innate connection to magic. Their patience and wisdom make them formidable spellcasters.",
		"bonuses": "+2+1d4 Vitality, Will, Speech",
		"traits": "Graceful, Magical Affinity, Long-lived"
	},
	Enums.Race.HALFLING: {
		"name": "Halfling",
		"description": "Small but quick-witted, halflings rely on agility and cunning. Their nimble fingers and silver tongues get them out of trouble.",
		"bonuses": "+1+1d4 Agility, Speech, Knowledge",
		"traits": "Quick, Cunning, Lucky"
	},
	Enums.Race.DWARF: {
		"name": "Dwarf",
		"description": "Stout and unyielding, dwarves are born of stone and steel. Their legendary endurance and craftsmanship are unmatched.",
		"bonuses": "+3+1d4 Grit, Knowledge, Vitality",
		"traits": "Tough, Stubborn, Master Crafters"
	}
}

# Career data
const CAREER_DATA = {
	Enums.Career.APPRENTICE: {
		"name": "Apprentice",
		"description": "Trained in the arcane arts under a master wizard. You know the basics of magic and ancient lore.",
		"skills": "Arcana Lore +2, History +1",
		"equipment": "Worn robes, Spellbook, Candles"
	},
	Enums.Career.FARMER: {
		"name": "Farmer",
		"description": "Hard labor has made you strong and resilient. You know how to survive off the land.",
		"skills": "Endurance +2, Survival +1",
		"equipment": "Pitchfork, Work clothes, Dried rations"
	},
	Enums.Career.GRAVE_DIGGER: {
		"name": "Grave Digger",
		"description": "You've spent your nights among the dead. Little frightens you now, and you know the rites of burial.",
		"skills": "Endurance +1, Religion +1, Bravery +1",
		"equipment": "Shovel, Lantern, Holy symbol"
	},
	Enums.Career.SCOUT: {
		"name": "Scout",
		"description": "Eyes sharp and feet silent, you've ranged far ahead of armies and caravans. You see what others miss.",
		"skills": "Perception +2, Stealth +1",
		"equipment": "Shortbow, Leather armor, Rope"
	},
	Enums.Career.SOLDIER: {
		"name": "Soldier",
		"description": "Trained for war, you know how to fight and how to march. Combat is your trade.",
		"skills": "Melee +2, Athletics +1",
		"equipment": "Longsword, Chain shirt, Shield"
	},
	Enums.Career.MERCHANT: {
		"name": "Merchant",
		"description": "You've haggled in markets from here to the coast. You know the value of things and how to talk people into deals.",
		"skills": "Persuasion +2, Deception +1",
		"equipment": "Fine clothes, Coin purse (extra gold), Scales"
	},
	Enums.Career.PRIEST: {
		"name": "Priest",
		"description": "Devoted to the gods, you bring their light to the faithful and their wrath to the wicked. You can tend wounds and souls.",
		"skills": "Religion +2, First Aid +1",
		"equipment": "Holy symbol, Robes, Healing herbs"
	},
	Enums.Career.THIEF: {
		"name": "Thief",
		"description": "Locks yield to your picks and shadows hide your passage. You take what you want from those who have too much.",
		"skills": "Stealth +2, Lockpicking +1",
		"equipment": "Dagger, Lockpicks, Dark cloak"
	},
	Enums.Career.NOBLE: {
		"name": "Noble",
		"description": "Born to privilege but cast down by fate. Your education and social graces remain, even if your fortune does not.",
		"skills": "Persuasion +2, Negotiation +1",
		"equipment": "Dagger, Wealthy purse"
	},
	Enums.Career.CULTIST: {
		"name": "Cultist",
		"description": "You have delved into forbidden texts and dark rituals. The old gods whisper secrets to those who listen.",
		"skills": "Arcana Lore +2, Religion +1",
		"equipment": "Dagger, Health potions"
	},
	Enums.Career.ALCHEMIST: {
		"name": "Alchemist",
		"description": "Trained in the art of brewing potions and identifying herbs. You prefer science over swords.",
		"skills": "Alchemy +2, Herbalism +1",
		"equipment": "Health potions, Healing herbs"
	},
	Enums.Career.BEGGAR: {
		"name": "Beggar",
		"description": "Life on the streets taught you to survive with nothing. Your fists and wits are all you have.",
		"skills": "Survival +2, Endurance +1",
		"equipment": "Bread, Empty pockets"
	}
}

# Current selections
var selected_race: Enums.Race = Enums.Race.HUMAN
var selected_career: Enums.Career = Enums.Career.SOLDIER
var character_name: String = ""

# UI references
var name_input: LineEdit
var race_buttons: Array[Button] = []
var career_buttons: Array[Button] = []
var race_description: RichTextLabel
var career_description: RichTextLabel
var preview_label: Label
var start_button: Button

func _ready() -> void:
	_build_ui()
	_update_selection_display()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _build_ui() -> void:
	# Full screen dark background (base layer)
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COL_BG
	add_child(bg)

	# Background image (stretched to fit with pixelated look)
	if ResourceLoader.exists(BG_TEXTURE_PATH):
		var bg_tex = TextureRect.new()
		bg_tex.texture = load(BG_TEXTURE_PATH)
		bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_tex.stretch_mode = TextureRect.STRETCH_SCALE
		bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # Pixelated look
		add_child(bg_tex)

	# Main container - compact margins with extra bottom padding to keep buttons visible
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 4)
	main_vbox.offset_left = 15
	main_vbox.offset_top = 10
	main_vbox.offset_right = -15
	main_vbox.offset_bottom = -50  # Extra bottom padding to ensure buttons stay visible
	add_child(main_vbox)

	# Title
	var title = Label.new()
	title.text = "CREATE YOUR CHARACTER"
	title.add_theme_color_override("font_color", COL_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	main_vbox.add_child(title)

	# Name input section - inline with title area
	var name_hbox = HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 8)
	name_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(name_hbox)

	var name_label = Label.new()
	name_label.text = "NAME:"
	name_label.add_theme_color_override("font_color", COL_GOLD)
	name_label.add_theme_font_size_override("font_size", 18)
	name_hbox.add_child(name_label)

	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter name..."
	name_input.custom_minimum_size.x = 220
	name_input.custom_minimum_size.y = 32
	name_input.text_changed.connect(_on_name_changed)
	_style_line_edit(name_input)
	name_hbox.add_child(name_input)

	main_vbox.add_child(HSeparator.new())

	# Main content area (two columns)
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 15)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)

	# Left column: Race selection
	var race_vbox = _build_selection_panel("RACE", RACE_DATA, true)
	race_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(race_vbox)

	# Right column: Career selection
	var career_vbox = _build_selection_panel("ARCHETYPE", CAREER_DATA, false)
	career_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(career_vbox)

	# Preview + Buttons row (combined to save space)
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 15)
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.custom_minimum_size.y = 50  # Ensure minimum height for buttons
	main_vbox.add_child(bottom_hbox)

	# Preview label
	preview_label = Label.new()
	preview_label.add_theme_color_override("font_color", COL_TEXT)
	preview_label.add_theme_font_size_override("font_size", 18)
	preview_label.custom_minimum_size.x = 250
	bottom_hbox.add_child(preview_label)

	var random_btn = Button.new()
	random_btn.text = "RANDOM"
	random_btn.custom_minimum_size = Vector2(100, 36)
	random_btn.add_theme_font_size_override("font_size", 16)
	random_btn.pressed.connect(_on_randomize_pressed)
	_style_button(random_btn)
	bottom_hbox.add_child(random_btn)

	start_button = Button.new()
	start_button.text = "BEGIN"
	start_button.custom_minimum_size = Vector2(120, 36)
	start_button.add_theme_font_size_override("font_size", 16)
	start_button.pressed.connect(_on_start_pressed)
	_style_button(start_button, true)
	bottom_hbox.add_child(start_button)

func _build_selection_panel(title: String, data: Dictionary, is_race: bool) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# Section title
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", COL_GOLD)
	title_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_label)

	# Button grid - compact
	var button_grid = GridContainer.new()
	button_grid.columns = 4 if not is_race else 2  # 4 columns for careers, 2 for races
	button_grid.add_theme_constant_override("h_separation", 4)
	button_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(button_grid)

	var buttons_array: Array[Button] = []
	for key in data.keys():
		var btn = Button.new()
		btn.text = data[key]["name"]
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(90, 30)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_selection_button_pressed.bind(key, is_race))
		_style_button(btn)
		button_grid.add_child(btn)
		buttons_array.append(btn)

	if is_race:
		race_buttons = buttons_array
	else:
		career_buttons = buttons_array

	# Description panel
	var desc_panel = PanelContainer.new()
	desc_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_panel.custom_minimum_size.y = 120
	var desc_style = StyleBoxFlat.new()
	desc_style.bg_color = COL_PANEL
	desc_style.border_color = COL_BORDER
	desc_style.set_border_width_all(1)
	desc_panel.add_theme_stylebox_override("panel", desc_style)
	vbox.add_child(desc_panel)

	var desc_margin = MarginContainer.new()
	desc_margin.add_theme_constant_override("margin_left", 6)
	desc_margin.add_theme_constant_override("margin_top", 4)
	desc_margin.add_theme_constant_override("margin_right", 6)
	desc_margin.add_theme_constant_override("margin_bottom", 4)
	desc_panel.add_child(desc_margin)

	var desc_text = RichTextLabel.new()
	desc_text.bbcode_enabled = true
	desc_text.fit_content = false
	desc_text.scroll_active = true
	desc_text.add_theme_color_override("default_color", COL_TEXT)
	desc_text.add_theme_font_size_override("normal_font_size", 16)
	desc_margin.add_child(desc_text)

	if is_race:
		race_description = desc_text
	else:
		career_description = desc_text

	return vbox

func _style_button(btn: Button, is_primary: bool = false) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = COL_PANEL if not is_primary else COL_SELECT
	normal.border_color = COL_BORDER if not is_primary else COL_GOLD
	normal.set_border_width_all(1 if not is_primary else 2)
	normal.set_corner_radius_all(2)

	var hover = StyleBoxFlat.new()
	hover.bg_color = COL_SELECT
	hover.border_color = COL_GOLD
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(2)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = COL_SELECT
	pressed.border_color = COL_GOLD
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", COL_GOLD)
	btn.add_theme_color_override("font_pressed_color", COL_GOLD)

func _style_line_edit(line_edit: LineEdit) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = COL_PANEL
	style.border_color = COL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)

	var focus_style = StyleBoxFlat.new()
	focus_style.bg_color = COL_PANEL
	focus_style.border_color = COL_GOLD
	focus_style.set_border_width_all(1)
	focus_style.set_corner_radius_all(2)

	line_edit.add_theme_stylebox_override("normal", style)
	line_edit.add_theme_stylebox_override("focus", focus_style)
	line_edit.add_theme_color_override("font_color", COL_TEXT)
	line_edit.add_theme_color_override("font_placeholder_color", COL_DIM)
	line_edit.add_theme_color_override("caret_color", COL_GOLD)
	line_edit.add_theme_font_size_override("font_size", 16)

func _on_selection_button_pressed(key: int, is_race: bool) -> void:
	if is_race:
		selected_race = key as Enums.Race
	else:
		selected_career = key as Enums.Career
	_update_selection_display()

func _on_name_changed(new_text: String) -> void:
	character_name = new_text.strip_edges()
	_update_preview()

func _update_selection_display() -> void:
	# Update race buttons
	var race_keys = RACE_DATA.keys()
	for i in range(race_buttons.size()):
		race_buttons[i].button_pressed = (race_keys[i] == selected_race)

	# Update career buttons
	var career_keys = CAREER_DATA.keys()
	for i in range(career_buttons.size()):
		career_buttons[i].button_pressed = (career_keys[i] == selected_career)

	# Update race description - compact format
	var race_info = RACE_DATA[selected_race]
	race_description.text = "[color=#%s]%s[/color] - %s\n[color=#%s]Stats:[/color] %s" % [
		COL_GOLD.to_html(false),
		race_info["name"],
		race_info["traits"],
		COL_GOLD.to_html(false),
		race_info["bonuses"]
	]

	# Update career description - compact format
	var career_info = CAREER_DATA[selected_career]
	career_description.text = "[color=#%s]%s[/color]\n%s\n[color=#%s]Skills:[/color] %s" % [
		COL_GOLD.to_html(false),
		career_info["name"],
		career_info["description"],
		COL_GOLD.to_html(false),
		career_info["skills"]
	]

	_update_preview()

func _update_preview() -> void:
	var race_name = RACE_DATA[selected_race]["name"]
	var career_name = CAREER_DATA[selected_career]["name"]
	var display_name = character_name if not character_name.is_empty() else "???"

	preview_label.text = "%s the %s %s" % [display_name, race_name, career_name]

	# Disable start button if no name
	start_button.disabled = character_name.is_empty()
	if character_name.is_empty():
		start_button.modulate = Color(0.5, 0.5, 0.5)
	else:
		start_button.modulate = Color.WHITE

func _on_randomize_pressed() -> void:
	# Random name from a pool
	var names = [
		"Aldric", "Bran", "Cedric", "Dorian", "Edmund", "Finnian", "Gareth", "Hadrian",
		"Isolde", "Jorah", "Kira", "Lyra", "Magnus", "Nadia", "Osric", "Petra",
		"Quinn", "Roland", "Sera", "Theron", "Una", "Vance", "Wren", "Xander",
		"Yara", "Zephyr", "Grimm", "Ash", "Raven", "Storm", "Wolf", "Crow"
	]
	name_input.text = names[randi() % names.size()]
	character_name = name_input.text

	# Random race and career
	var races = RACE_DATA.keys()
	var careers = CAREER_DATA.keys()
	selected_race = races[randi() % races.size()]
	selected_career = careers[randi() % careers.size()]

	_update_selection_display()

func _on_start_pressed() -> void:
	if character_name.is_empty():
		return

	# Create the character
	GameManager.create_new_character(character_name, selected_race, selected_career)
	GameManager.player_data.recalculate_derived_stats()

	# Starting equipment/gold is handled by career selection
	# Merchant gets bonus gold, others get relevant gear
	_apply_career_starting_equipment(selected_career)

	character_created.emit()

	# Transition to game - start at Elder Moor
	get_tree().change_scene_to_file("res://scenes/levels/elder_moor.tscn")


## Give starting equipment based on career
func _apply_career_starting_equipment(career: Enums.Career) -> void:
	# Everyone gets basic supplies
	InventoryManager.add_item("health_potion", 1)
	InventoryManager.add_gold(10)

	match career:
		Enums.Career.APPRENTICE:
			# Magic student - scrolls and robes
			InventoryManager.add_item("wooden_staff", 1)
			InventoryManager.add_gold(5)
		Enums.Career.FARMER:
			# Humble beginnings - tools and food
			InventoryManager.add_item("rusty_sword", 1)
			InventoryManager.add_item("bread", 2)
		Enums.Career.GRAVE_DIGGER:
			# Morbid work - shovel and lantern
			InventoryManager.add_item("rusty_sword", 1)
			InventoryManager.add_item("torch", 2)
		Enums.Career.SCOUT:
			# Wilderness survival - bow and supplies
			InventoryManager.add_item("hunting_bow", 1)
			InventoryManager.add_item("arrow", 20)
		Enums.Career.SOLDIER:
			# Military training - proper weapons
			InventoryManager.add_item("iron_sword", 1)
			InventoryManager.add_item("health_potion", 1)
		Enums.Career.MERCHANT:
			# Trading background - gold and goods
			InventoryManager.add_gold(40)  # Total 50 gold
		Enums.Career.PRIEST:
			# Holy calling - healing and faith
			InventoryManager.add_item("wooden_staff", 1)
			InventoryManager.add_item("health_potion", 2)
		Enums.Career.THIEF:
			# Street skills - tools of the trade
			InventoryManager.add_item("dagger", 1)
			InventoryManager.add_item("lockpick", 3)
		Enums.Career.NOBLE:
			# Fallen aristocrat - silver tongue and gold
			InventoryManager.add_item("dagger", 1)
			InventoryManager.add_gold(150)  # Total 160 gold
		Enums.Career.CULTIST:
			# Dark knowledge seeker
			InventoryManager.add_item("dagger", 1)
			InventoryManager.add_item("health_potion", 2)
		Enums.Career.ALCHEMIST:
			# Potion brewer
			InventoryManager.add_item("health_potion", 3)
			InventoryManager.add_item("healing_herb", 3)
		Enums.Career.BEGGAR:
			# Street survivor - starts with nothing
			InventoryManager.add_item("bread", 1)
			InventoryManager.remove_gold(10)  # Remove the base 10 gold - starts broke
