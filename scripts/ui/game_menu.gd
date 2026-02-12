## game_menu.gd - Unified game menu opened with Tab
## 4 Tabs: Character, Items, Magic, Journal
class_name GameMenu
extends Control

signal menu_closed

enum MenuTab { CHARACTER, ITEMS, MAGIC, JOURNAL, MAP }
var current_tab: MenuTab = MenuTab.CHARACTER

const TAB_NAMES = ["Character", "Items", "Magic", "Journal", "Map"]

# Dark gothic colors
const COL_BG = Color(0.08, 0.08, 0.1)
const COL_PANEL = Color(0.12, 0.12, 0.15)
const COL_BORDER = Color(0.3, 0.25, 0.2)
const COL_TEXT = Color(0.9, 0.85, 0.75)
const COL_DIM = Color(0.5, 0.5, 0.5)
const COL_GOLD = Color(0.8, 0.6, 0.2)
const COL_SELECT = Color(0.25, 0.2, 0.15)
const COL_GREEN = Color(0.3, 0.8, 0.3)
const COL_RED = Color(0.8, 0.3, 0.3)

# UI elements
var tab_buttons: Array = []
var tab_panels: Array = []
var selected_item_idx: int = -1
var selected_skill_idx: int = 0
var selected_equip_slot: String = ""  # Currently selected equipment slot for unequip/drop

# Hover tooltip for item comparison
var hover_tooltip: PanelContainer = null
var hovered_item_idx: int = -1
var item_list_ref: ItemList = null  # Reference to current ItemList

# Hotbar context menu
var hotbar_context_menu: PopupMenu = null
var context_menu_target: Dictionary = {}  # {type: "weapon"|"spell"|"item", id: String}
var spell_list_ref: ItemList = null
var hovered_spell_idx: int = -1

func _clear_children_immediate(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # Allow menu to work while game is paused
	_build_menu()
	_connect_inventory_signals()

func _connect_inventory_signals() -> void:
	InventoryManager.item_added.connect(_on_inventory_changed)
	InventoryManager.item_removed.connect(_on_inventory_changed)
	InventoryManager.equipment_changed.connect(_on_equipment_changed)

func _on_inventory_changed(_item_id: String, _quantity: int) -> void:
	if visible and current_tab == MenuTab.ITEMS:
		_refresh_items()

func _on_equipment_changed(_slot: String, _old: Dictionary, _new: Dictionary) -> void:
	if visible and current_tab == MenuTab.ITEMS:
		_refresh_items()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("menu") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("menu_prev_tab"):
		_change_tab(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_next_tab"):
		_change_tab(1)
		get_viewport().set_input_as_handled()

	# X key to drop selected equipped item
	if event is InputEventKey and event.pressed and event.keycode == KEY_X:
		if not selected_equip_slot.is_empty():
			_on_drop_equipped(selected_equip_slot)
			get_viewport().set_input_as_handled()

func _change_tab(dir: int) -> void:
	var new_tab = (current_tab + dir) % MenuTab.size()
	if new_tab < 0:
		new_tab = MenuTab.size() - 1
	current_tab = new_tab as MenuTab
	_update_tabs()

func _update_tabs() -> void:
	for i in range(tab_buttons.size()):
		tab_buttons[i].button_pressed = (i == current_tab)
	for i in range(tab_panels.size()):
		tab_panels[i].visible = (i == current_tab)
	_refresh_tab()

func _build_menu() -> void:
	# Dark overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.75)
	add_child(overlay)

	# Main container
	var main = PanelContainer.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.offset_left = 20
	main.offset_top = 20
	main.offset_right = -20
	main.offset_bottom = -20
	var main_style = StyleBoxFlat.new()
	main_style.bg_color = COL_BG
	main_style.border_color = COL_BORDER
	main_style.set_border_width_all(2)
	main.add_theme_stylebox_override("panel", main_style)
	add_child(main)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	main.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "CATACOMBS OF GORE"
	title.add_theme_color_override("font_color", COL_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Tab buttons
	var tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_bar)

	tab_buttons.clear()
	for i in range(TAB_NAMES.size()):
		var btn = Button.new()
		btn.text = TAB_NAMES[i].to_upper()
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.button_pressed = (i == 0)
		btn.pressed.connect(_on_tab_clicked.bind(i))
		_style_button(btn)
		tab_bar.add_child(btn)
		tab_buttons.append(btn)

	# Stats bar (HP/Mana/Stamina) - visible on all tabs
	var stats_bar := _create_stats_bar()
	vbox.add_child(stats_bar)

	# Content area - locked minimum size to prevent resizing
	var content = PanelContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(500, 400)  # Lock minimum content size
	var content_style = StyleBoxFlat.new()
	content_style.bg_color = COL_PANEL
	content.add_theme_stylebox_override("panel", content_style)
	vbox.add_child(content)

	# Create each tab panel
	tab_panels.clear()
	for i in range(TAB_NAMES.size()):
		var panel = _create_tab_panel(i)
		panel.visible = (i == 0)
		content.add_child(panel)
		tab_panels.append(panel)

	# Create hover tooltip last so it's on top of everything
	_create_hover_tooltip()

	# Create hotbar context menu
	_create_hotbar_context_menu()

func _style_button(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = COL_PANEL
	normal.border_color = COL_BORDER
	normal.set_border_width_all(1)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = COL_SELECT
	pressed.border_color = COL_GOLD
	pressed.set_border_width_all(2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_pressed_color", COL_GOLD)

# Stats bar labels for updating
var stats_hp_label: Label
var stats_mana_label: Label
var stats_stamina_label: Label

## Create stats bar showing HP/Mana/Stamina
func _create_stats_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.name = "StatsBar"
	bar.add_theme_constant_override("separation", 20)

	# HP
	var hp_container := HBoxContainer.new()
	hp_container.add_theme_constant_override("separation", 5)
	var hp_icon := Label.new()
	hp_icon.text = "HP:"
	hp_icon.add_theme_color_override("font_color", COL_RED)
	hp_container.add_child(hp_icon)
	stats_hp_label = Label.new()
	stats_hp_label.text = "100/100"
	stats_hp_label.add_theme_color_override("font_color", COL_TEXT)
	hp_container.add_child(stats_hp_label)
	bar.add_child(hp_container)

	# Mana
	var mana_container := HBoxContainer.new()
	mana_container.add_theme_constant_override("separation", 5)
	var mana_icon := Label.new()
	mana_icon.text = "MANA:"
	mana_icon.add_theme_color_override("font_color", Color(0.3, 0.5, 1.0))
	mana_container.add_child(mana_icon)
	stats_mana_label = Label.new()
	stats_mana_label.text = "50/50"
	stats_mana_label.add_theme_color_override("font_color", COL_TEXT)
	mana_container.add_child(stats_mana_label)
	bar.add_child(mana_container)

	# Stamina
	var stamina_container := HBoxContainer.new()
	stamina_container.add_theme_constant_override("separation", 5)
	var stamina_icon := Label.new()
	stamina_icon.text = "STAMINA:"
	stamina_icon.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	stamina_container.add_child(stamina_icon)
	stats_stamina_label = Label.new()
	stats_stamina_label.text = "100/100"
	stats_stamina_label.add_theme_color_override("font_color", COL_TEXT)
	stamina_container.add_child(stats_stamina_label)
	bar.add_child(stamina_container)

	return bar

## Refresh stats bar with current player values
func _refresh_stats_bar() -> void:
	var player := GameManager.player_data
	if not player:
		return
	if stats_hp_label:
		stats_hp_label.text = "%d/%d" % [player.current_hp, player.max_hp]
	if stats_mana_label:
		stats_mana_label.text = "%d/%d" % [player.current_mana, player.max_mana]
	if stats_stamina_label:
		stats_stamina_label.text = "%d/%d" % [player.current_stamina, player.max_stamina]

func _on_tab_clicked(idx: int) -> void:
	current_tab = idx as MenuTab
	_update_tabs()

# ==================== HOTBAR CONTEXT MENU ====================

func _create_hotbar_context_menu() -> void:
	hotbar_context_menu = PopupMenu.new()
	hotbar_context_menu.name = "HotbarContextMenu"

	# Add items for slots 1-9 and 0 (displayed as 1-9, 0)
	for i in range(10):
		var display_key := str((i + 1) % 10)  # 1,2,3...9,0
		hotbar_context_menu.add_item("Assign to Hotbar [%s]" % display_key, i)

	# Style the menu
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = COL_BG
	menu_style.border_color = COL_BORDER
	menu_style.set_border_width_all(2)
	menu_style.set_content_margin_all(4)
	hotbar_context_menu.add_theme_stylebox_override("panel", menu_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = COL_SELECT
	hotbar_context_menu.add_theme_stylebox_override("hover", hover_style)

	hotbar_context_menu.add_theme_color_override("font_color", COL_TEXT)
	hotbar_context_menu.add_theme_color_override("font_hover_color", COL_GOLD)

	hotbar_context_menu.id_pressed.connect(_on_hotbar_menu_selected)
	add_child(hotbar_context_menu)

func _show_hotbar_context_menu(type: String, id: String, pos: Vector2) -> void:
	context_menu_target = {"type": type, "id": id}
	hotbar_context_menu.position = pos
	hotbar_context_menu.popup()

func _on_hotbar_menu_selected(slot_idx: int) -> void:
	if context_menu_target.is_empty():
		return

	var type: String = context_menu_target.get("type", "")
	var id: String = context_menu_target.get("id", "")

	if type.is_empty() or id.is_empty():
		return

	InventoryManager.set_hotbar_slot(slot_idx, type, id)
	AudioManager.play_ui_confirm()
	context_menu_target = {}

func _create_tab_panel(idx: int) -> Control:
	var panel = MarginContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_constant_override("margin_left", 10)
	panel.add_theme_constant_override("margin_top", 10)
	panel.add_theme_constant_override("margin_right", 10)
	panel.add_theme_constant_override("margin_bottom", 10)

	match idx:
		MenuTab.CHARACTER:
			panel.add_child(_build_character_panel())
		MenuTab.ITEMS:
			panel.add_child(_build_items_panel())
		MenuTab.MAGIC:
			panel.add_child(_build_magic_panel())
		MenuTab.JOURNAL:
			panel.add_child(_build_journal_panel())
		MenuTab.MAP:
			panel.add_child(_build_map_panel())

	return panel

# ==================== CHARACTER TAB ====================
func _build_character_panel() -> Control:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox = VBoxContainer.new()
	vbox.name = "CharContent"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Will be populated in _refresh_character()
	return scroll

func _refresh_character() -> void:
	var panel = tab_panels[MenuTab.CHARACTER]
	var vbox = panel.find_child("CharContent", true, false)
	if not vbox:
		return

	# Clear old content
	_clear_children_immediate(vbox)

	if not GameManager.player_data:
		var lbl = Label.new()
		lbl.text = "No character data"
		lbl.add_theme_color_override("font_color", COL_TEXT)
		vbox.add_child(lbl)
		return

	var data = GameManager.player_data

	# === HEADER ===
	var header = _make_label(data.character_name.to_upper(), COL_GOLD)
	vbox.add_child(header)

	var race_str = Enums.Race.keys()[data.race] as String
	var career_str = Enums.Career.keys()[data.career] as String
	vbox.add_child(_make_label("%s %s    Level %d" % [race_str.capitalize(), career_str.capitalize().replace("_", " "), data.level], COL_DIM))

	vbox.add_child(HSeparator.new())

	# === MAIN STATS AREA (3 columns) ===
	var main_cols = HBoxContainer.new()
	main_cols.add_theme_constant_override("separation", 30)
	vbox.add_child(main_cols)

	# --- Column 1: Vital Resources ---
	var vitals_vbox = VBoxContainer.new()
	main_cols.add_child(vitals_vbox)
	vitals_vbox.add_child(_make_label("VITALS", COL_GOLD))

	# HP with color based on percentage
	var hp_pct = float(data.current_hp) / max(data.max_hp, 1)
	var hp_color = COL_TEXT
	if hp_pct <= 0.25:
		hp_color = Color(1.0, 0.3, 0.3)  # Red
	elif hp_pct <= 0.5:
		hp_color = Color(1.0, 0.8, 0.3)  # Yellow
	vitals_vbox.add_child(_make_label("Health: %d / %d" % [data.current_hp, data.max_hp], hp_color))

	vitals_vbox.add_child(_make_label("Stamina: %d / %d" % [data.current_stamina, data.max_stamina], COL_TEXT))
	vitals_vbox.add_child(_make_label("Mana: %d / %d" % [data.current_mana, data.max_mana], Color(0.4, 0.6, 1.0)))
	# Mana already shown above, spell slots deprecated
	# vitals_vbox.add_child(_make_label("Spell Slots: %d / %d" % [data.current_spell_slots, data.max_spell_slots], Color(0.6, 0.4, 0.8)))

	vitals_vbox.add_child(_make_label("", COL_TEXT))  # Spacer
	vitals_vbox.add_child(_make_label("REGENERATION", COL_GOLD))
	vitals_vbox.add_child(_make_label("HP Regen: %.1f/s" % data.get_hp_regen(), COL_DIM))
	vitals_vbox.add_child(_make_label("Stamina Regen: %.1f/s" % data.get_stamina_regen(), COL_DIM))
	vitals_vbox.add_child(_make_label("Mana Regen: %.1f/s" % data.get_mana_regen(), COL_DIM))

	# --- Column 2: Combat Stats ---
	var combat_vbox = VBoxContainer.new()
	main_cols.add_child(combat_vbox)
	combat_vbox.add_child(_make_label("OFFENSE", COL_GOLD))

	# Get equipped weapon info
	var weapon = InventoryManager.get_equipped_weapon()
	var weapon_quality = InventoryManager.get_equipped_weapon_quality()
	if weapon:
		var quality_mod = Enums.get_quality_modifier(weapon_quality)
		var damage_str = weapon.get_damage_string()
		if quality_mod != 0:
			damage_str += " %+d" % quality_mod
		combat_vbox.add_child(_make_label("Weapon: %s" % weapon.display_name, COL_TEXT))
		combat_vbox.add_child(_make_label("Damage: %s" % damage_str, COL_TEXT))
		combat_vbox.add_child(_make_label("Attack Speed: %.2fx" % (weapon.attack_speed * data.get_attack_speed_multiplier()), COL_DIM))
	else:
		combat_vbox.add_child(_make_label("Weapon: Unarmed", COL_DIM))
		combat_vbox.add_child(_make_label("Damage: 1d4 + %d" % data.get_effective_stat(Enums.Stat.GRIT), COL_DIM))

	# Melee skill bonus
	var melee_skill = data.get_skill(Enums.Skill.MELEE)
	if melee_skill > 0:
		combat_vbox.add_child(_make_label("Melee Bonus: +%d%%" % (melee_skill * 5), COL_DIM))

	combat_vbox.add_child(_make_label("", COL_TEXT))  # Spacer
	combat_vbox.add_child(_make_label("DEFENSE", COL_GOLD))

	var armor_value = InventoryManager.get_total_armor_value()
	var block_value = InventoryManager.get_block_value()
	combat_vbox.add_child(_make_label("Armor: %d" % armor_value, COL_TEXT))
	if block_value > 0:
		combat_vbox.add_child(_make_label("Block: %d" % block_value, COL_TEXT))
	combat_vbox.add_child(_make_label("Magic Resist: %d%%" % int(data.get_magic_resistance() * 100), COL_DIM))

	# Dodge skill bonus
	var dodge_skill = data.get_skill(Enums.Skill.DODGE)
	if dodge_skill > 0:
		combat_vbox.add_child(_make_label("Dodge Bonus: +%d%%" % (dodge_skill * 3), COL_DIM))

	# --- Column 3: Attributes ---
	var attr_vbox = VBoxContainer.new()
	main_cols.add_child(attr_vbox)
	attr_vbox.add_child(_make_label("ATTRIBUTES", COL_GOLD))
	attr_vbox.add_child(_make_label("Grit: %d" % data.get_effective_stat(Enums.Stat.GRIT), COL_TEXT))
	attr_vbox.add_child(_make_label("Agility: %d" % data.get_effective_stat(Enums.Stat.AGILITY), COL_TEXT))
	attr_vbox.add_child(_make_label("Will: %d" % data.get_effective_stat(Enums.Stat.WILL), COL_TEXT))
	attr_vbox.add_child(_make_label("Speech: %d" % data.get_effective_stat(Enums.Stat.SPEECH), COL_TEXT))
	attr_vbox.add_child(_make_label("Knowledge: %d" % data.get_effective_stat(Enums.Stat.KNOWLEDGE), COL_TEXT))
	attr_vbox.add_child(_make_label("Vitality: %d" % data.get_effective_stat(Enums.Stat.VITALITY), COL_TEXT))

	attr_vbox.add_child(_make_label("", COL_TEXT))  # Spacer
	attr_vbox.add_child(_make_label("BONUSES", COL_GOLD))
	attr_vbox.add_child(_make_label("Move Speed: %.0f%%" % (data.get_movement_multiplier() * 100), COL_DIM))
	attr_vbox.add_child(_make_label("XP Bonus: +%d%%" % int((data.get_xp_multiplier() - 1.0) * 100), COL_DIM))

	vbox.add_child(HSeparator.new())

	# === PROGRESSION ===
	var prog_hbox = HBoxContainer.new()
	prog_hbox.add_theme_constant_override("separation", 40)
	vbox.add_child(prog_hbox)

	prog_hbox.add_child(_make_label("PROGRESSION", COL_GOLD))
	prog_hbox.add_child(_make_label("Level: %d" % data.level, COL_TEXT))
	prog_hbox.add_child(_make_label("XP Available: %d" % data.improvement_points, COL_GOLD if data.improvement_points > 0 else COL_DIM))
	prog_hbox.add_child(_make_label("Gold: %d" % InventoryManager.gold, COL_GOLD))

	vbox.add_child(HSeparator.new())

	# === SKILLS (Compact Grid) ===
	vbox.add_child(_make_label("SKILLS", COL_GOLD))

	var skill_grid = GridContainer.new()
	skill_grid.columns = 4
	skill_grid.add_theme_constant_override("h_separation", 15)
	skill_grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(skill_grid)

	for skill_enum in Enums.Skill.values():
		var skill_name = Enums.Skill.keys()[skill_enum] as String
		var skill_level = data.get_skill(skill_enum)
		var display_name = skill_name.capitalize().replace("_", " ")
		# Truncate long names
		if display_name.length() > 12:
			display_name = display_name.substr(0, 11) + "."
		var skill_color = COL_DIM
		if skill_level >= 7:
			skill_color = COL_GOLD  # Master level
		elif skill_level >= 4:
			skill_color = COL_TEXT  # Proficient
		elif skill_level > 0:
			skill_color = Color(0.7, 0.7, 0.7)  # Some training
		var lbl = _make_label("%s: %d" % [display_name, skill_level], skill_color)
		skill_grid.add_child(lbl)

	# === CONDITIONS ===
	if not data.conditions.is_empty():
		vbox.add_child(HSeparator.new())
		vbox.add_child(_make_label("ACTIVE CONDITIONS", Color(1.0, 0.5, 0.5)))
		var cond_hbox = HBoxContainer.new()
		cond_hbox.add_theme_constant_override("separation", 15)
		vbox.add_child(cond_hbox)
		for cond in data.conditions:
			var cond_name = Enums.Condition.keys()[cond] as String
			var time_left = data.conditions[cond]
			var cond_color = _get_condition_display_color(cond)
			cond_hbox.add_child(_make_label("[%s %.0fs]" % [cond_name.capitalize().replace("_", " "), time_left], cond_color))

func _get_condition_display_color(condition: Enums.Condition) -> Color:
	match condition:
		Enums.Condition.POISONED: return Color(0.3, 0.9, 0.3)
		Enums.Condition.BURNING: return Color(1.0, 0.5, 0.2)
		Enums.Condition.FROZEN: return Color(0.5, 0.8, 1.0)
		Enums.Condition.BLEEDING: return Color(0.8, 0.2, 0.2)
		Enums.Condition.HORRIFIED: return Color(0.7, 0.3, 0.9)
		Enums.Condition.STUNNED: return Color(1.0, 1.0, 0.3)
		_: return COL_TEXT

# ==================== ITEMS TAB ====================
func _build_items_panel() -> Control:
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 15)

	# Left: Equipment
	var equip_vbox = VBoxContainer.new()
	equip_vbox.name = "EquipVBox"
	equip_vbox.custom_minimum_size.x = 160
	hbox.add_child(equip_vbox)

	# Right: Inventory list
	var inv_vbox = VBoxContainer.new()
	inv_vbox.name = "InvVBox"
	inv_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(inv_vbox)

	return hbox

func _refresh_items() -> void:
	var panel = tab_panels[MenuTab.ITEMS]
	var equip_vbox = panel.find_child("EquipVBox", true, false)
	var inv_vbox = panel.find_child("InvVBox", true, false)

	if not equip_vbox or not inv_vbox:
		push_warning("[GameMenu] Could not find EquipVBox or InvVBox")
		return

	# Clear
	_clear_children_immediate(equip_vbox)
	_clear_children_immediate(inv_vbox)

	# Equipment section
	equip_vbox.add_child(_make_label("EQUIPMENT", COL_GOLD))

	var slots = ["main_hand", "off_hand", "head", "body", "hands", "feet", "ring_1", "ring_2", "amulet"]
	var slot_names = ["Weapon", "Off-Hand", "Head", "Body", "Hands", "Feet", "Ring 1", "Ring 2", "Amulet"]

	for i in range(slots.size()):
		var slot_id = slots[i]
		var equip = InventoryManager.equipment.get(slot_id, {})
		var text = slot_names[i] + ": "
		if equip.is_empty():
			text += "-"
			equip_vbox.add_child(_make_label(text, COL_DIM))
		else:
			text += InventoryManager.get_item_name(equip.item_id)
			# Add durability percentage display
			var durability_pct := InventoryManager.get_equipment_durability_percent(slot_id)
			var durability_int := int(durability_pct * 100)
			text += " (%d%%)" % durability_int

			# Determine durability color
			var durability_color: Color = COL_GREEN
			if durability_pct < 0.25:
				durability_color = COL_RED
			elif durability_pct <= 0.5:
				durability_color = Color(1.0, 0.8, 0.3)  # Yellow

			# Make equipped items clickable buttons
			var btn = Button.new()
			btn.text = text
			btn.flat = true
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.focus_mode = Control.FOCUS_NONE  # Prevent focus stealing
			# Highlight if selected, otherwise use durability color for text
			if selected_equip_slot == slot_id:
				btn.add_theme_color_override("font_color", COL_GOLD)
				btn.add_theme_color_override("font_hover_color", COL_GOLD)
			else:
				btn.add_theme_color_override("font_color", durability_color)
				btn.add_theme_color_override("font_hover_color", COL_GOLD)
			btn.pressed.connect(_on_equip_slot_clicked.bind(slot_id))
			# Connect hover signals for equipment tooltip
			btn.mouse_entered.connect(_on_equipment_hover_entered.bind(slot_id, btn))
			btn.mouse_exited.connect(_on_equipment_hover_exited)
			# Connect right-click for hotbar assignment
			btn.gui_input.connect(_on_equipment_button_gui_input.bind(slot_id, equip.item_id))
			equip_vbox.add_child(btn)

			# If this slot is selected, show action buttons
			if selected_equip_slot == slot_id:
				var action_row = HBoxContainer.new()
				action_row.add_theme_constant_override("separation", 4)
				equip_vbox.add_child(action_row)

				var unequip_btn = Button.new()
				unequip_btn.text = "Unequip"
				unequip_btn.focus_mode = Control.FOCUS_NONE
				unequip_btn.pressed.connect(_on_unequip_slot.bind(slot_id))
				_style_button(unequip_btn)
				action_row.add_child(unequip_btn)

				var drop_btn = Button.new()
				drop_btn.text = "Drop [X]"
				drop_btn.focus_mode = Control.FOCUS_NONE
				drop_btn.pressed.connect(_on_drop_equipped.bind(slot_id))
				_style_button(drop_btn)
				action_row.add_child(drop_btn)
	equip_vbox.add_child(HSeparator.new())
	equip_vbox.add_child(_make_label("Gold: %d" % InventoryManager.gold, COL_GOLD))

	# Weight display
	var total_weight: float = InventoryManager.get_total_weight()
	var max_weight: float = InventoryManager.get_max_carry_weight()
	var weight_color: Color = COL_TEXT
	if total_weight > max_weight:
		weight_color = Color(1.0, 0.3, 0.3)  # Red for overencumbered
	equip_vbox.add_child(_make_label("Weight: %.1f / %.1f" % [total_weight, max_weight], weight_color))

	# Inventory section
	inv_vbox.add_child(_make_label("INVENTORY", COL_GOLD))

	if InventoryManager.inventory.is_empty():
		inv_vbox.add_child(_make_label("Empty", COL_DIM))
	else:
		var item_list = ItemList.new()
		item_list.name = "ItemList"
		item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		item_list.item_selected.connect(_on_item_selected)
		item_list.mouse_exited.connect(_on_item_list_mouse_exited)
		item_list.gui_input.connect(_on_item_list_gui_input)
		_style_item_list(item_list)
		inv_vbox.add_child(item_list)
		item_list_ref = item_list  # Store reference for hover tracking

		for slot in InventoryManager.inventory:
			var item_name = InventoryManager.get_item_name(slot.item_id)
			var quality = slot.quality as Enums.ItemQuality
			var prefix = ""
			match quality:
				Enums.ItemQuality.POOR: prefix = "[Poor] "
				Enums.ItemQuality.BELOW_AVERAGE: prefix = "[Worn] "
				Enums.ItemQuality.ABOVE_AVERAGE: prefix = "[Fine] "
				Enums.ItemQuality.PERFECT: prefix = "[Perfect] "

			var display = prefix + item_name
			if slot.quantity > 1:
				display += " x%d" % slot.quantity
			item_list.add_item(display)

		# Details label
		var details = Label.new()
		details.name = "ItemDetails"
		details.text = "Select an item"
		details.autowrap_mode = TextServer.AUTOWRAP_WORD
		details.add_theme_color_override("font_color", COL_TEXT)
		details.custom_minimum_size.y = 50
		inv_vbox.add_child(details)

		# Buttons
		var btn_row = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 8)
		inv_vbox.add_child(btn_row)

		var use_btn = Button.new()
		use_btn.text = "Use"
		use_btn.pressed.connect(_on_use_item)
		_style_button(use_btn)
		btn_row.add_child(use_btn)

		var equip_btn = Button.new()
		equip_btn.text = "Equip"
		equip_btn.pressed.connect(_on_equip_item)
		_style_button(equip_btn)
		btn_row.add_child(equip_btn)

		var drop_btn = Button.new()
		drop_btn.text = "Drop"
		drop_btn.pressed.connect(_on_drop_item)
		_style_button(drop_btn)
		btn_row.add_child(drop_btn)

func _on_item_selected(idx: int) -> void:
	selected_item_idx = idx
	selected_equip_slot = ""  # Deselect equipment when selecting inventory item
	var panel = tab_panels[MenuTab.ITEMS]
	var details = panel.find_child("ItemDetails", true, false)
	if not details:
		return

	if idx < 0 or idx >= InventoryManager.inventory.size():
		details.text = "Select an item"
		return

	var slot = InventoryManager.inventory[idx]
	var item_name = InventoryManager.get_item_name(slot.item_id)
	var desc = InventoryManager.get_item_description(slot.item_id)

	# Get weight and value for display
	var item_data = InventoryManager.get_item_data(slot.item_id)
	var weight: float = 0.0
	var value: int = InventoryManager.get_item_value(slot.item_id, slot.quality)

	if item_data:
		weight = item_data.weight

	details.text = item_name + "\n" + desc + "\nWeight: %.1f    Value: %d gold" % [weight, value]
	# Note: Comparison now shown via hover tooltip, not click-based panel

func _on_use_item() -> void:
	if selected_item_idx >= 0 and selected_item_idx < InventoryManager.inventory.size():
		InventoryManager.use_item(selected_item_idx)
		_refresh_items()

func _on_equip_item() -> void:
	if selected_item_idx >= 0 and selected_item_idx < InventoryManager.inventory.size():
		if InventoryManager.equip_item(selected_item_idx):
			AudioManager.play_ui_confirm()
		else:
			AudioManager.play_ui_cancel()
		selected_item_idx = -1
		_refresh_items()

func _on_drop_item() -> void:
	if selected_item_idx < 0 or selected_item_idx >= InventoryManager.inventory.size():
		return

	# Get player position for dropping the item
	var drop_pos := Vector3.ZERO
	var player := get_tree().get_first_node_in_group("player")
	if player and player is Node3D:
		# Drop slightly in front of player
		drop_pos = (player as Node3D).global_position + Vector3(0, 0.5, 1.0)

	InventoryManager.drop_item(selected_item_idx, drop_pos)
	selected_item_idx = -1
	_refresh_items()

func _on_equip_slot_clicked(slot_id: String) -> void:
	# Toggle selection - click again to deselect
	if selected_equip_slot == slot_id:
		selected_equip_slot = ""
	else:
		selected_equip_slot = slot_id
		selected_item_idx = -1  # Deselect inventory item when selecting equipment
		_hide_hover_tooltip()  # Hide tooltip when switching to equipment
	_refresh_items()

func _on_unequip_slot(slot_id: String) -> void:
	if InventoryManager.unequip_item(slot_id):
		AudioManager.play_ui_confirm()
	else:
		AudioManager.play_ui_cancel()
	selected_equip_slot = ""
	_refresh_items()

func _on_drop_equipped(slot_id: String) -> void:
	var equip = InventoryManager.equipment.get(slot_id, {})
	if equip.is_empty():
		return

	# Get player position for dropping
	var drop_pos := Vector3.ZERO
	var player := get_tree().get_first_node_in_group("player")
	if player and player is Node3D:
		var p3d := player as Node3D
		drop_pos = p3d.global_position + Vector3(0, 0.5, 1.0)
		# Try to drop in front of player if they have a MeshRoot
		if player.has_node("MeshRoot"):
			var mesh_root: Node3D = player.get_node("MeshRoot")
			drop_pos = p3d.global_position - mesh_root.global_transform.basis.z * 1.5 + Vector3(0, 1.0, 0)

	# Spawn world item
	var world := get_tree().current_scene
	if not world:
		AudioManager.play_ui_cancel()
		return

	var item_id: String = equip.item_id
	var quality: Enums.ItemQuality = equip.quality
	var world_item := WorldItem.spawn_item(world, drop_pos, item_id, quality, 1)

	if world_item:
		# Clear the equipment slot - don't emit signal to avoid double refresh
		var old_item: Dictionary = equip.duplicate()
		InventoryManager.equipment[slot_id] = {}
		# Manually emit since we want to notify other systems
		InventoryManager.equipment_changed.emit(slot_id, old_item, {})
		AudioManager.play_ui_confirm()
	else:
		AudioManager.play_ui_cancel()

	selected_equip_slot = ""
	# Note: equipment_changed signal already triggered _refresh_items via _on_equipment_changed
	# But call it again to ensure UI is updated
	_refresh_items()

# ==================== HOVER TOOLTIP FOR ITEM COMPARISON ====================

func _create_hover_tooltip() -> void:
	hover_tooltip = PanelContainer.new()
	hover_tooltip.name = "HoverTooltip"
	hover_tooltip.visible = false
	hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse
	hover_tooltip.z_index = 100  # Always on top

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	panel_style.border_color = COL_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_content_margin_all(8)
	hover_tooltip.add_theme_stylebox_override("panel", panel_style)

	var content = VBoxContainer.new()
	content.name = "TooltipContent"
	hover_tooltip.add_child(content)

	add_child(hover_tooltip)

func _hide_hover_tooltip() -> void:
	if hover_tooltip:
		hover_tooltip.visible = false
	hovered_item_idx = -1
	hovered_spell_idx = -1

func _update_hover_tooltip(item_idx: int, mouse_pos: Vector2) -> void:
	if item_idx < 0 or item_idx >= InventoryManager.inventory.size():
		_hide_hover_tooltip()
		return

	var slot = InventoryManager.inventory[item_idx]
	var item_data = InventoryManager.get_item_data(slot.item_id)

	if not item_data:
		_hide_hover_tooltip()
		return

	# Only show for equippable items (weapons and armor)
	if not (item_data is WeaponData or item_data is ArmorData):
		_hide_hover_tooltip()
		return

	# Determine equipment slot for comparison
	var equip_slot := ""
	var is_weapon := false
	var is_armor := false

	if item_data is WeaponData:
		equip_slot = "main_hand"
		is_weapon = true
	elif item_data is ArmorData:
		is_armor = true
		var armor := item_data as ArmorData
		match armor.slot:
			Enums.ArmorSlot.HEAD: equip_slot = "head"
			Enums.ArmorSlot.BODY: equip_slot = "body"
			Enums.ArmorSlot.HANDS: equip_slot = "hands"
			Enums.ArmorSlot.FEET: equip_slot = "feet"
			Enums.ArmorSlot.RING_1, Enums.ArmorSlot.RING_2:
				if not InventoryManager.equipment.ring_1.is_empty():
					equip_slot = "ring_1"
				elif not InventoryManager.equipment.ring_2.is_empty():
					equip_slot = "ring_2"
				else:
					equip_slot = "ring_1"  # Default slot name for display
			Enums.ArmorSlot.AMULET: equip_slot = "amulet"
			Enums.ArmorSlot.SHIELD: equip_slot = "off_hand"

	# Build tooltip content
	var content: VBoxContainer = hover_tooltip.get_node("TooltipContent")
	_clear_children_immediate(content)

	# Item name header
	var item_name = InventoryManager.get_item_name(slot.item_id)
	var quality_prefix = ""
	match slot.quality:
		Enums.ItemQuality.POOR: quality_prefix = "[Poor] "
		Enums.ItemQuality.BELOW_AVERAGE: quality_prefix = "[Worn] "
		Enums.ItemQuality.ABOVE_AVERAGE: quality_prefix = "[Fine] "
		Enums.ItemQuality.PERFECT: quality_prefix = "[Perfect] "

	content.add_child(_make_label(quality_prefix + item_name, COL_GOLD))
	content.add_child(_make_tooltip_separator())

	# Check if something is equipped to compare against
	var equipped = InventoryManager.equipment.get(equip_slot, {})

	if equipped.is_empty():
		# No item equipped - show item stats only
		content.add_child(_make_label("No %s equipped" % equip_slot.replace("_", " "), COL_DIM))
		content.add_child(_make_tooltip_separator())
		if is_weapon:
			_build_weapon_stats_only(content, item_data as WeaponData, slot.quality)
		elif is_armor:
			_build_armor_stats_only(content, item_data as ArmorData, slot.quality)
	else:
		# Show comparison
		var equipped_data = equipped.get("data")
		var equipped_quality: Enums.ItemQuality = equipped.get("quality", Enums.ItemQuality.AVERAGE)

		if equipped_data:
			var equipped_name = InventoryManager.get_item_name(equipped.item_id)
			content.add_child(_make_label("vs " + equipped_name, COL_DIM))
			content.add_child(_make_tooltip_separator())

			if is_weapon and equipped_data is WeaponData:
				_build_weapon_comparison_tooltip(content, item_data as WeaponData, slot.quality, equipped_data as WeaponData, equipped_quality)
			elif is_armor and equipped_data is ArmorData:
				_build_armor_comparison_tooltip(content, item_data as ArmorData, slot.quality, equipped_data as ArmorData, equipped_quality, equip_slot)

	# Position tooltip near mouse, keeping it on screen
	hover_tooltip.visible = true
	hover_tooltip.reset_size()  # Recalculate size based on content

	# Wait a frame for size to update, then position
	await get_tree().process_frame
	_position_tooltip(mouse_pos)

func _position_tooltip(mouse_pos: Vector2) -> void:
	if not hover_tooltip or not hover_tooltip.visible:
		return

	var viewport_size = get_viewport_rect().size
	var tooltip_size = hover_tooltip.size
	var offset := Vector2(20, 10)  # Offset from cursor

	var pos := mouse_pos + offset

	# Keep tooltip on screen
	if pos.x + tooltip_size.x > viewport_size.x:
		pos.x = mouse_pos.x - tooltip_size.x - 10
	if pos.y + tooltip_size.y > viewport_size.y:
		pos.y = viewport_size.y - tooltip_size.y - 10
	if pos.x < 0:
		pos.x = 10
	if pos.y < 0:
		pos.y = 10

	hover_tooltip.position = pos

func _make_tooltip_separator() -> Control:
	var sep = Label.new()
	sep.text = String.chr(0x2500).repeat(20)  # Box drawing horizontal line
	sep.add_theme_color_override("font_color", COL_BORDER)
	return sep

func _build_weapon_stats_only(vbox: VBoxContainer, weapon: WeaponData, quality: Enums.ItemQuality) -> void:
	var mod := Enums.get_quality_modifier(quality)
	var avg_dmg := (weapon.base_damage[0] * (weapon.base_damage[1] + 1.0) / 2.0) + weapon.base_damage[2] + mod
	var dps := avg_dmg * weapon.attack_speed

	vbox.add_child(_make_label("Damage: %.1f" % avg_dmg, COL_TEXT))
	vbox.add_child(_make_label("Speed: %.2f" % weapon.attack_speed, COL_TEXT))
	vbox.add_child(_make_label("Reach: %.1f" % weapon.reach, COL_TEXT))
	vbox.add_child(_make_label("DPS: %.1f" % dps, COL_TEXT))
	# Durability - inventory items are at full durability for their quality
	var max_dur := InventoryManager.get_max_durability(quality)
	vbox.add_child(_make_durability_label(max_dur, max_dur))

func _build_armor_stats_only(vbox: VBoxContainer, armor: ArmorData, quality: Enums.ItemQuality) -> void:
	var armor_val := armor.get_armor_value(quality)
	vbox.add_child(_make_label("Armor: %d" % armor_val, COL_TEXT))
	vbox.add_child(_make_label("Weight: %.1f" % armor.weight, COL_TEXT))
	if armor.is_shield:
		var block_val := armor.get_block_value(quality)
		vbox.add_child(_make_label("Block: %d" % block_val, COL_TEXT))
	# Durability - inventory items are at full durability for their quality
	var max_dur := InventoryManager.get_max_durability(quality)
	vbox.add_child(_make_durability_label(max_dur, max_dur))

func _build_weapon_comparison_tooltip(vbox: VBoxContainer, selected: WeaponData, sel_quality: Enums.ItemQuality, equipped: WeaponData, eq_quality: Enums.ItemQuality) -> void:
	var sel_mod := Enums.get_quality_modifier(sel_quality)
	var eq_mod := Enums.get_quality_modifier(eq_quality)

	var sel_avg_dmg := (selected.base_damage[0] * (selected.base_damage[1] + 1.0) / 2.0) + selected.base_damage[2] + sel_mod
	var eq_avg_dmg := (equipped.base_damage[0] * (equipped.base_damage[1] + 1.0) / 2.0) + equipped.base_damage[2] + eq_mod

	var sel_dps := sel_avg_dmg * selected.attack_speed
	var eq_dps := eq_avg_dmg * equipped.attack_speed

	vbox.add_child(_make_stat_tooltip_row("Damage", sel_avg_dmg, eq_avg_dmg, "%.1f"))
	vbox.add_child(_make_stat_tooltip_row("Speed", selected.attack_speed, equipped.attack_speed, "%.2f"))
	vbox.add_child(_make_stat_tooltip_row("Reach", selected.reach, equipped.reach, "%.1f"))
	vbox.add_child(_make_stat_tooltip_row("DPS", sel_dps, eq_dps, "%.1f"))

	# Durability comparison - selected item is at full durability, equipped may be worn
	var sel_max_dur := InventoryManager.get_max_durability(sel_quality)
	var eq_cur_dur := InventoryManager.get_equipment_durability("main_hand")
	var eq_max_dur := InventoryManager.get_equipment_max_durability("main_hand")
	vbox.add_child(_make_durability_comparison_row(sel_max_dur, sel_max_dur, eq_cur_dur, eq_max_dur))

func _build_armor_comparison_tooltip(vbox: VBoxContainer, selected: ArmorData, sel_quality: Enums.ItemQuality, equipped: ArmorData, eq_quality: Enums.ItemQuality, equip_slot: String) -> void:
	var sel_armor := selected.get_armor_value(sel_quality)
	var eq_armor := equipped.get_armor_value(eq_quality)
	vbox.add_child(_make_stat_tooltip_row("Armor", sel_armor, eq_armor, "%d"))

	# Weight - lower is better
	vbox.add_child(_make_stat_tooltip_row_inverted("Weight", selected.weight, equipped.weight, "%.1f"))

	if selected.is_shield or equipped.is_shield:
		var sel_block := selected.get_block_value(sel_quality)
		var eq_block := equipped.get_block_value(eq_quality)
		vbox.add_child(_make_stat_tooltip_row("Block", sel_block, eq_block, "%d"))

	# Durability comparison - selected item is at full durability, equipped may be worn
	var sel_max_dur := InventoryManager.get_max_durability(sel_quality)
	var eq_cur_dur := InventoryManager.get_equipment_durability(equip_slot)
	var eq_max_dur := InventoryManager.get_equipment_max_durability(equip_slot)
	vbox.add_child(_make_durability_comparison_row(sel_max_dur, sel_max_dur, eq_cur_dur, eq_max_dur))

func _make_stat_tooltip_row(stat_name: String, sel_val: float, eq_val: float, format: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_lbl = Label.new()
	name_lbl.text = stat_name + ":"
	name_lbl.custom_minimum_size.x = 55
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(name_lbl)

	var val_lbl = Label.new()
	val_lbl.text = format % sel_val
	val_lbl.custom_minimum_size.x = 45
	val_lbl.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(val_lbl)

	# Indicator
	var diff := sel_val - eq_val
	var indicator_lbl = Label.new()
	indicator_lbl.custom_minimum_size.x = 25

	if abs(diff) < 0.01:
		indicator_lbl.text = " -"
		indicator_lbl.add_theme_color_override("font_color", COL_DIM)
	elif diff > 0:
		indicator_lbl.text = " " + String.chr(0x25B2)  # Up triangle
		indicator_lbl.add_theme_color_override("font_color", COL_GREEN)
	else:
		indicator_lbl.text = " " + String.chr(0x25BC)  # Down triangle
		indicator_lbl.add_theme_color_override("font_color", COL_RED)

	row.add_child(indicator_lbl)
	return row

func _make_stat_tooltip_row_inverted(stat_name: String, sel_val: float, eq_val: float, format: String) -> HBoxContainer:
	# For stats where lower is better (like weight)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_lbl = Label.new()
	name_lbl.text = stat_name + ":"
	name_lbl.custom_minimum_size.x = 55
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(name_lbl)

	var val_lbl = Label.new()
	val_lbl.text = format % sel_val
	val_lbl.custom_minimum_size.x = 45
	val_lbl.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(val_lbl)

	# Indicator (inverted logic)
	var diff := sel_val - eq_val
	var indicator_lbl = Label.new()
	indicator_lbl.custom_minimum_size.x = 25

	if abs(diff) < 0.01:
		indicator_lbl.text = " -"
		indicator_lbl.add_theme_color_override("font_color", COL_DIM)
	elif diff < 0:  # Lower is better
		indicator_lbl.text = " " + String.chr(0x25B2)  # Up triangle (good)
		indicator_lbl.add_theme_color_override("font_color", COL_GREEN)
	else:
		indicator_lbl.text = " " + String.chr(0x25BC)  # Down triangle (bad)
		indicator_lbl.add_theme_color_override("font_color", COL_RED)

	row.add_child(indicator_lbl)
	return row

## Get durability display color based on percentage (0.0-1.0)
## Green >50%, Yellow 25-50%, Red <25%
func _get_durability_color(percent: float) -> Color:
	if percent > 0.5:
		return COL_GREEN
	elif percent >= 0.25:
		return Color(1.0, 0.8, 0.3)  # Yellow
	else:
		return COL_RED

## Build durability display label for tooltip
func _make_durability_label(current: int, maximum: int) -> Label:
	var percent := 0.0
	if maximum > 0:
		percent = float(current) / float(maximum)
	var percent_int := int(percent * 100)
	var color := _get_durability_color(percent)
	return _make_label("Durability: %d/%d (%d%%)" % [current, maximum, percent_int], color)

## Build durability comparison row for tooltip (selected vs equipped)
func _make_durability_comparison_row(sel_cur: int, sel_max: int, eq_cur: int, eq_max: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_lbl = Label.new()
	name_lbl.text = "Durability:"
	name_lbl.custom_minimum_size.x = 55
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(name_lbl)

	# Selected item durability (inventory items are at full)
	var sel_pct := 0.0
	if sel_max > 0:
		sel_pct = float(sel_cur) / float(sel_max)
	var sel_pct_int := int(sel_pct * 100)
	var sel_color := _get_durability_color(sel_pct)

	var val_lbl = Label.new()
	val_lbl.text = "%d%%" % sel_pct_int
	val_lbl.custom_minimum_size.x = 45
	val_lbl.add_theme_color_override("font_color", sel_color)
	row.add_child(val_lbl)

	# Comparison indicator
	var eq_pct := 0.0
	if eq_max > 0:
		eq_pct = float(eq_cur) / float(eq_max)
	var diff := sel_pct - eq_pct

	var indicator_lbl = Label.new()
	indicator_lbl.custom_minimum_size.x = 25

	if abs(diff) < 0.01:
		indicator_lbl.text = " -"
		indicator_lbl.add_theme_color_override("font_color", COL_DIM)
	elif diff > 0:
		indicator_lbl.text = " " + String.chr(0x25B2)  # Up triangle (better)
		indicator_lbl.add_theme_color_override("font_color", COL_GREEN)
	else:
		indicator_lbl.text = " " + String.chr(0x25BC)  # Down triangle (worse)
		indicator_lbl.add_theme_color_override("font_color", COL_RED)

	row.add_child(indicator_lbl)
	return row

func _on_item_list_mouse_motion(event: InputEventMouseMotion) -> void:
	if not item_list_ref or not is_instance_valid(item_list_ref):
		return

	# Get item at mouse position
	var local_pos = item_list_ref.get_local_mouse_position()
	var item_idx = item_list_ref.get_item_at_position(local_pos, true)

	if item_idx != hovered_item_idx:
		hovered_item_idx = item_idx
		if item_idx >= 0:
			_update_hover_tooltip(item_idx, event.global_position)
		else:
			_hide_hover_tooltip()
	elif item_idx >= 0 and hover_tooltip and hover_tooltip.visible:
		# Just update position
		_position_tooltip(event.global_position)

func _on_item_list_mouse_exited() -> void:
	_hide_hover_tooltip()

func _on_item_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_on_item_list_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_handle_inventory_right_click(mb.global_position)

func _handle_inventory_right_click(global_pos: Vector2) -> void:
	if not item_list_ref or not is_instance_valid(item_list_ref):
		return

	var local_pos := item_list_ref.get_local_mouse_position()
	var item_idx := item_list_ref.get_item_at_position(local_pos, true)

	if item_idx < 0 or item_idx >= InventoryManager.inventory.size():
		return

	var slot: Dictionary = InventoryManager.inventory[item_idx]
	var item_id: String = slot.get("item_id", "")
	if item_id.is_empty():
		return

	# Determine item type for hotbar
	var item_data = InventoryManager.get_item_data(item_id)
	var type := "item"
	if item_data is WeaponData:
		type = "weapon"

	_show_hotbar_context_menu(type, item_id, global_pos)

# ==================== EQUIPMENT HOVER TOOLTIP ====================

func _on_equipment_button_gui_input(event: InputEvent, slot_id: String, item_id: String) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# Determine if this is a weapon slot
			var type := "item"
			if slot_id == "main_hand":
				type = "weapon"
			_show_hotbar_context_menu(type, item_id, mb.global_position)

func _on_equipment_hover_entered(slot_id: String, btn: Button) -> void:
	var mouse_pos := btn.get_global_mouse_position()
	_update_equipment_hover_tooltip(slot_id, mouse_pos)

func _on_equipment_hover_exited() -> void:
	_hide_hover_tooltip()

func _update_equipment_hover_tooltip(slot: String, mouse_pos: Vector2) -> void:
	var equip: Dictionary = InventoryManager.equipment.get(slot, {})
	if equip.is_empty():
		_hide_hover_tooltip()
		return

	var item_id: String = equip.get("item_id", "")
	var quality: Enums.ItemQuality = equip.get("quality", Enums.ItemQuality.AVERAGE)
	var item_data: Resource = equip.get("data")

	if not item_data:
		_hide_hover_tooltip()
		return

	# Build tooltip content
	var content: VBoxContainer = hover_tooltip.get_node("TooltipContent")
	_clear_children_immediate(content)

	# Quality prefix
	var quality_prefix := ""
	match quality:
		Enums.ItemQuality.POOR: quality_prefix = "[Poor] "
		Enums.ItemQuality.BELOW_AVERAGE: quality_prefix = "[Worn] "
		Enums.ItemQuality.ABOVE_AVERAGE: quality_prefix = "[Fine] "
		Enums.ItemQuality.PERFECT: quality_prefix = "[Perfect] "

	# Item name with quality
	var item_name: String = InventoryManager.get_item_name(item_id)
	content.add_child(_make_label(quality_prefix + item_name, COL_GOLD))
	content.add_child(_make_tooltip_separator())

	# Description / flavor text with word wrap
	var description: String = InventoryManager.get_item_description(item_id)
	if not description.is_empty():
		var desc_label := Label.new()
		desc_label.text = description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size.x = 220
		desc_label.add_theme_color_override("font_color", COL_DIM)
		content.add_child(desc_label)
		content.add_child(_make_tooltip_separator())

	# Stats based on item type
	if item_data is WeaponData:
		_build_equipment_weapon_stats(content, item_data as WeaponData, quality)
	elif item_data is ArmorData:
		_build_equipment_armor_stats(content, item_data as ArmorData, quality)

	# Durability
	var cur_dur: int = equip.get("durability", 0)
	var max_dur: int = equip.get("max_durability", 0)
	content.add_child(_make_durability_label(cur_dur, max_dur))

	# Special effects
	_build_equipment_special_effects(content, item_data)

	# Show and position tooltip
	hover_tooltip.visible = true
	hover_tooltip.reset_size()

	await get_tree().process_frame
	_position_tooltip(mouse_pos)

func _build_equipment_weapon_stats(vbox: VBoxContainer, weapon: WeaponData, quality: Enums.ItemQuality) -> void:
	var mod := Enums.get_quality_modifier(quality)

	# Primary damage
	var damage_str := weapon.get_damage_string()
	if mod != 0:
		damage_str += " %+d" % mod
	vbox.add_child(_make_label("Damage: %s" % damage_str, COL_TEXT))

	# Damage type
	var dmg_type_name: String = Enums.DamageType.keys()[weapon.damage_type]
	vbox.add_child(_make_label("Type: %s" % dmg_type_name.capitalize(), COL_DIM))

	# Secondary damage (elemental)
	if weapon.secondary_damage[0] > 0:
		var sec_str := "%dd%d" % [weapon.secondary_damage[0], weapon.secondary_damage[1]]
		if weapon.secondary_damage[2] != 0:
			sec_str += "%+d" % weapon.secondary_damage[2]
		var sec_type_name: String = Enums.DamageType.keys()[weapon.secondary_damage_type]
		vbox.add_child(_make_label("+ %s %s" % [sec_str, sec_type_name.capitalize()], Color(1.0, 0.6, 0.2)))

	# Combat stats
	vbox.add_child(_make_label("Speed: %.2fx" % weapon.attack_speed, COL_TEXT))
	vbox.add_child(_make_label("Reach: %.1fm" % weapon.reach, COL_TEXT))

	if weapon.armor_pierce > 0:
		vbox.add_child(_make_label("Armor Pierce: %d%%" % int(weapon.armor_pierce * 100), COL_GREEN))

	if weapon.crit_chance > 0.05:
		vbox.add_child(_make_label("Crit Chance: %d%%" % int(weapon.crit_chance * 100), COL_GREEN))

	if weapon.crit_multiplier > 2.0:
		vbox.add_child(_make_label("Crit Damage: %.1fx" % weapon.crit_multiplier, COL_GREEN))

	# Ranged properties
	if weapon.is_ranged:
		vbox.add_child(_make_label("Range: %.0f" % weapon.max_range, COL_DIM))
		if weapon.reload_time > 0:
			vbox.add_child(_make_label("Reload: %.1fs" % weapon.reload_time, COL_DIM))

	# Weight
	vbox.add_child(_make_label("Weight: %.1f" % weapon.weight, COL_DIM))

func _build_equipment_armor_stats(vbox: VBoxContainer, armor: ArmorData, quality: Enums.ItemQuality) -> void:
	# Armor value
	var armor_val := armor.get_armor_value(quality)
	vbox.add_child(_make_label("Armor: %d" % armor_val, COL_TEXT))

	# Block value for shields
	if armor.is_shield:
		var block_val := armor.get_block_value(quality)
		vbox.add_child(_make_label("Block: %d" % block_val, COL_TEXT))

	# Weight class
	var weight_class_name: String = Enums.ArmorWeight.keys()[armor.weight_class]
	vbox.add_child(_make_label("Class: %s" % weight_class_name.capitalize(), COL_DIM))

	# Weight
	vbox.add_child(_make_label("Weight: %.1f" % armor.weight, COL_DIM))

	# Stat bonuses
	var stat_bonuses: Array[String] = []
	if armor.grit_bonus != 0:
		stat_bonuses.append("Grit %+d" % armor.grit_bonus)
	if armor.agility_bonus != 0:
		stat_bonuses.append("Agility %+d" % armor.agility_bonus)
	if armor.will_bonus != 0:
		stat_bonuses.append("Will %+d" % armor.will_bonus)
	if armor.vitality_bonus != 0:
		stat_bonuses.append("Vitality %+d" % armor.vitality_bonus)
	if armor.knowledge_bonus != 0:
		stat_bonuses.append("Knowledge %+d" % armor.knowledge_bonus)
	if armor.speech_bonus != 0:
		stat_bonuses.append("Speech %+d" % armor.speech_bonus)

	if not stat_bonuses.is_empty():
		vbox.add_child(_make_tooltip_separator())
		vbox.add_child(_make_label("STAT BONUSES", COL_GOLD))
		for bonus in stat_bonuses:
			var color := COL_GREEN if bonus.contains("+") else COL_RED
			vbox.add_child(_make_label(bonus, color))

	# Resistances
	var resistances: Array[String] = []
	if armor.fire_resistance != 0:
		resistances.append("Fire %+d%%" % int(armor.fire_resistance * 100))
	if armor.frost_resistance != 0:
		resistances.append("Frost %+d%%" % int(armor.frost_resistance * 100))
	if armor.lightning_resistance != 0:
		resistances.append("Lightning %+d%%" % int(armor.lightning_resistance * 100))
	if armor.poison_resistance != 0:
		resistances.append("Poison %+d%%" % int(armor.poison_resistance * 100))
	if armor.necrotic_resistance != 0:
		resistances.append("Necrotic %+d%%" % int(armor.necrotic_resistance * 100))
	if armor.magic_resistance != 0:
		resistances.append("Magic %+d%%" % int(armor.magic_resistance * 100))

	if not resistances.is_empty():
		vbox.add_child(_make_tooltip_separator())
		vbox.add_child(_make_label("RESISTANCES", COL_GOLD))
		for res in resistances:
			var color := COL_GREEN if res.contains("+") else COL_RED
			vbox.add_child(_make_label(res, color))

	# Penalties
	var penalties: Array[String] = []
	if armor.agility_penalty > 0:
		penalties.append("Agility -%d" % armor.agility_penalty)
	if armor.stealth_penalty > 0:
		penalties.append("Stealth -%d" % armor.stealth_penalty)
	if armor.spell_failure_chance > 0:
		penalties.append("Spell Failure %d%%" % int(armor.spell_failure_chance * 100))

	if not penalties.is_empty():
		vbox.add_child(_make_tooltip_separator())
		vbox.add_child(_make_label("PENALTIES", Color(1.0, 0.5, 0.5)))
		for penalty in penalties:
			vbox.add_child(_make_label(penalty, COL_RED))

func _build_equipment_special_effects(vbox: VBoxContainer, item_data: Resource) -> void:
	var effects: Array[String] = []

	if item_data is WeaponData:
		var weapon := item_data as WeaponData
		# Condition infliction
		if weapon.inflicts_condition != Enums.Condition.NONE and weapon.condition_chance > 0:
			var cond_name: String = Enums.Condition.keys()[weapon.inflicts_condition]
			effects.append("Inflicts %s (%d%% chance, %.1fs)" % [
				cond_name.capitalize().replace("_", " "),
				int(weapon.condition_chance * 100),
				weapon.condition_duration
			])
		# Lifesteal
		if weapon.lifesteal_percent > 0:
			effects.append("Lifesteal %d%%" % int(weapon.lifesteal_percent * 100))
		# Homing projectiles
		if weapon.is_homing:
			effects.append("Homing Projectiles")
		# Two-handed
		if weapon.two_handed:
			effects.append("Two-Handed")

	if not effects.is_empty():
		vbox.add_child(_make_tooltip_separator())
		vbox.add_child(_make_label("SPECIAL", Color(0.6, 0.4, 0.8)))
		for effect in effects:
			vbox.add_child(_make_label(effect, Color(0.8, 0.6, 1.0)))

# ==================== MAGIC TAB ====================
func _build_magic_panel() -> Control:
	# Wrap in ScrollContainer to match other tabs and prevent expansion
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox = VBoxContainer.new()
	vbox.name = "MagicContent"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	return scroll

func _refresh_magic() -> void:
	print("[GameMenu] _refresh_magic called")
	var panel = tab_panels[MenuTab.MAGIC]
	var vbox = panel.find_child("MagicContent", true, false)
	if not vbox:
		print("[GameMenu] ERROR: MagicContent vbox not found!")
		return

	_clear_children_immediate(vbox)

	spell_list_ref = null
	hovered_spell_idx = -1

	if not GameManager.player_data:
		vbox.add_child(_make_label("No character data", COL_TEXT))
		return

	var data = GameManager.player_data

	vbox.add_child(_make_label("SPELLS    Mana: %d / %d" % [data.current_mana, data.max_mana], COL_GOLD))
	vbox.add_child(HSeparator.new())

	# Get player's SpellCaster to show known spells
	var spell_caster: SpellCaster = _get_player_spell_caster()
	print("[GameMenu] SpellCaster found: %s" % (spell_caster != null))
	if spell_caster:
		print("[GameMenu] SpellCaster.known_spells.size() = %d" % spell_caster.known_spells.size())

	if spell_caster and spell_caster.known_spells.size() > 0:
		print("[GameMenu] Creating spell list with %d spells" % spell_caster.known_spells.size())
		# Use ItemList for better mouse tracking
		var spell_list := ItemList.new()
		spell_list.name = "SpellList"
		spell_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spell_list.custom_minimum_size.y = 350  # More room for spell list
		spell_list.mouse_exited.connect(_on_spell_list_mouse_exited)
		spell_list.gui_input.connect(_on_spell_list_gui_input)
		_style_item_list(spell_list)
		vbox.add_child(spell_list)
		spell_list_ref = spell_list

		for spell in spell_caster.known_spells:
			print("[GameMenu] Processing spell: %s (is null: %s)" % [spell, spell == null])
			if spell:
				# Display: "Spell Name [X slots]"
				var spell_text := "%s [%s]" % [spell.display_name, spell.get_cost_string()]
				print("[GameMenu] Adding spell to list: %s" % spell_text)
				spell_list.add_item(spell_text)
			else:
				print("[GameMenu] WARNING: Null spell in known_spells!")
		print("[GameMenu] Spell list now has %d items" % spell_list.item_count)
	else:
		print("[GameMenu] No spells known, showing empty message")
		vbox.add_child(_make_label("No spells known yet.", COL_DIM))
		vbox.add_child(_make_label("Learn spells from scrolls or trainers.", COL_DIM))

	# Show equipped spell in compact format (saves vertical space)
	var equipped_spell := InventoryManager.get_equipped_spell()
	var equipped_text: String = "Equipped: " + (equipped_spell.display_name if equipped_spell else "None")
	var equipped_color: Color = COL_GOLD if equipped_spell else COL_DIM
	vbox.add_child(_make_label(equipped_text, equipped_color))

func _get_player_spell_caster() -> SpellCaster:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		print("[GameMenu] _get_player_spell_caster: No player in group!")
		return null

	print("[GameMenu] _get_player_spell_caster: Found player: %s" % player.name)

	var spell_caster: SpellCaster = player.get_node_or_null("SpellCaster")
	if not spell_caster:
		print("[GameMenu] SpellCaster not direct child, searching all children...")
		for child in player.get_children():
			print("[GameMenu]   Child: %s (%s)" % [child.name, child.get_class()])
			if child is SpellCaster:
				print("[GameMenu]   Found SpellCaster as child!")
				return child
		print("[GameMenu] No SpellCaster found in any child!")
	else:
		print("[GameMenu] Found SpellCaster at path: %s, known_spells=%d" % [spell_caster.get_path(), spell_caster.known_spells.size()])
	return spell_caster

func _on_spell_list_mouse_exited() -> void:
	_hide_hover_tooltip()
	hovered_spell_idx = -1

func _on_spell_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_on_spell_list_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_handle_spell_left_click()  # Equip spell directly
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_handle_spell_right_click(mb.global_position)

func _on_spell_list_mouse_motion(event: InputEventMouseMotion) -> void:
	if not spell_list_ref or not is_instance_valid(spell_list_ref):
		return

	var local_pos := spell_list_ref.get_local_mouse_position()
	var spell_idx := spell_list_ref.get_item_at_position(local_pos, true)

	if spell_idx != hovered_spell_idx:
		hovered_spell_idx = spell_idx
		if spell_idx >= 0:
			_update_spell_hover_tooltip(spell_idx, event.global_position)
		else:
			_hide_hover_tooltip()
	elif spell_idx >= 0 and hover_tooltip and hover_tooltip.visible:
		_position_tooltip(event.global_position)

func _handle_spell_left_click() -> void:
	if not spell_list_ref or not is_instance_valid(spell_list_ref):
		return
	var spell_idx := spell_list_ref.get_selected_items()
	if spell_idx.is_empty():
		return

	var spell_caster := _get_player_spell_caster()
	if not spell_caster or spell_idx[0] >= spell_caster.known_spells.size():
		return

	var spell: SpellData = spell_caster.known_spells[spell_idx[0]]
	if not spell:
		return

	InventoryManager.equip_spell(spell.id)
	AudioManager.play_ui_confirm()
	_refresh_magic()  # Update "EQUIPPED SPELL" section

func _handle_spell_right_click(global_pos: Vector2) -> void:
	if not spell_list_ref or not is_instance_valid(spell_list_ref):
		return

	var local_pos := spell_list_ref.get_local_mouse_position()
	var spell_idx := spell_list_ref.get_item_at_position(local_pos, true)

	var spell_caster := _get_player_spell_caster()
	if not spell_caster or spell_idx < 0 or spell_idx >= spell_caster.known_spells.size():
		return

	var spell: SpellData = spell_caster.known_spells[spell_idx]
	if not spell:
		return

	_show_hotbar_context_menu("spell", spell.id, global_pos)

# ==================== SPELL TOOLTIP ====================

func _update_spell_hover_tooltip(spell_idx: int, mouse_pos: Vector2) -> void:
	var spell_caster := _get_player_spell_caster()
	if not spell_caster or spell_idx < 0 or spell_idx >= spell_caster.known_spells.size():
		_hide_hover_tooltip()
		return

	var spell: SpellData = spell_caster.known_spells[spell_idx]
	if not spell:
		_hide_hover_tooltip()
		return

	# Get equipped spell for comparison
	var equipped_spell := InventoryManager.get_equipped_spell()

	# Build tooltip content
	var content: VBoxContainer = hover_tooltip.get_node("TooltipContent")
	_clear_children_immediate(content)

	# Spell name header
	content.add_child(_make_label(spell.display_name, COL_GOLD))
	content.add_child(_make_tooltip_separator())

	# School and level
	var school_name: String = Enums.SpellSchool.keys()[spell.school]
	content.add_child(_make_label("%s - Level %d" % [school_name.capitalize(), spell.spell_level], COL_DIM))
	content.add_child(_make_tooltip_separator())

	# Description with word wrap
	if not spell.description.is_empty():
		var desc_label := Label.new()
		desc_label.text = spell.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size.x = 250
		desc_label.add_theme_color_override("font_color", COL_DIM)
		content.add_child(desc_label)
		content.add_child(_make_tooltip_separator())

	# Effect section
	_build_spell_effect_section(content, spell, equipped_spell)
	content.add_child(_make_tooltip_separator())

	# Cost & Range section
	_build_spell_cost_section(content, spell, equipped_spell)

	# Requirements section (if any)
	if spell.required_knowledge > 0 or spell.required_will > 0 or spell.required_arcana_lore > 0:
		content.add_child(_make_tooltip_separator())
		_build_spell_requirements_section(content, spell)

	# Special section (if any)
	if spell.is_homing or spell.piercing or spell.chain_targets > 0 or spell.inflicts_condition != Enums.Condition.NONE or spell.lifesteal_percent > 0 or spell.manasteal_percent > 0:
		content.add_child(_make_tooltip_separator())
		_build_spell_special_section(content, spell)

	# Show and position tooltip
	hover_tooltip.visible = true
	hover_tooltip.reset_size()

	await get_tree().process_frame
	_position_tooltip(mouse_pos)

func _build_spell_effect_section(vbox: VBoxContainer, spell: SpellData, equipped: SpellData) -> void:
	vbox.add_child(_make_label("EFFECT", COL_GOLD))

	var avg_effect := _calculate_spell_avg_effect(spell)
	var effect_type := "Healing" if spell.is_healing else "Damage"

	# Build damage/healing row with comparison
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = effect_type + ":"
	name_lbl.custom_minimum_size.x = 70
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(name_lbl)

	var dice_str := spell.get_effect_string().split(" ")[0]  # Just the dice notation
	var val_lbl := Label.new()
	val_lbl.text = "%s (avg %.1f)" % [dice_str, avg_effect]
	val_lbl.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(val_lbl)

	# Comparison indicator if spell is equipped
	if equipped and equipped != spell:
		var eq_avg := _calculate_spell_avg_effect(equipped)
		var diff := avg_effect - eq_avg
		var indicator := Label.new()
		indicator.custom_minimum_size.x = 60
		if abs(diff) < 0.1:
			indicator.text = ""
		elif diff > 0:
			indicator.text = "  [+%.1f]" % diff
			indicator.add_theme_color_override("font_color", COL_GREEN)
		else:
			indicator.text = "  [%.1f]" % diff
			indicator.add_theme_color_override("font_color", COL_RED)
		row.add_child(indicator)

	vbox.add_child(row)

	# Damage type (if not healing)
	if not spell.is_healing:
		var dmg_type_name: String = Enums.DamageType.keys()[spell.damage_type]
		vbox.add_child(_make_label("Type: %s" % dmg_type_name.capitalize(), COL_DIM))

func _build_spell_cost_section(vbox: VBoxContainer, spell: SpellData, equipped: SpellData) -> void:
	vbox.add_child(_make_label("COST & RANGE", COL_GOLD))

	# Mana cost with comparison (lower is better)
	var spell_mana := spell.get_mana_cost()
	var equipped_mana := equipped.get_mana_cost() if equipped else -1
	_add_spell_stat_row(vbox, "Mana", spell_mana, equipped_mana, "%d", true)

	# Cast time (lower is better)
	vbox.add_child(_make_label("Cast Time: %.1fs" % spell.cast_time, COL_TEXT))

	# Range (higher is better)
	vbox.add_child(_make_label("Range: %.0fm" % spell.range_distance, COL_TEXT))

	# Cooldown (lower is better)
	if spell.cooldown > 0:
		vbox.add_child(_make_label("Cooldown: %.1fs" % spell.cooldown, COL_TEXT))

func _build_spell_requirements_section(vbox: VBoxContainer, spell: SpellData) -> void:
	vbox.add_child(_make_label("REQUIREMENTS", COL_GOLD))

	var data = GameManager.player_data

	if spell.required_knowledge > 0:
		var player_val := data.get_effective_stat(Enums.Stat.KNOWLEDGE) if data else 0
		var met := player_val >= spell.required_knowledge
		var color := COL_GREEN if met else COL_RED
		vbox.add_child(_make_label("Knowledge: %d" % spell.required_knowledge, color))

	if spell.required_will > 0:
		var player_val := data.get_effective_stat(Enums.Stat.WILL) if data else 0
		var met := player_val >= spell.required_will
		var color := COL_GREEN if met else COL_RED
		vbox.add_child(_make_label("Will: %d" % spell.required_will, color))

	if spell.required_arcana_lore > 0:
		var player_val := data.get_skill(Enums.Skill.ARCANA_LORE) if data else 0
		var met := player_val >= spell.required_arcana_lore
		var color := COL_GREEN if met else COL_RED
		vbox.add_child(_make_label("Arcana Lore: %d" % spell.required_arcana_lore, color))

func _build_spell_special_section(vbox: VBoxContainer, spell: SpellData) -> void:
	vbox.add_child(_make_label("SPECIAL", Color(0.6, 0.4, 0.8)))

	if spell.is_homing:
		vbox.add_child(_make_label("Homing", Color(0.8, 0.6, 1.0)))

	if spell.piercing:
		vbox.add_child(_make_label("Piercing", Color(0.8, 0.6, 1.0)))

	if spell.chain_targets > 0:
		vbox.add_child(_make_label("Chains to %d targets" % spell.chain_targets, Color(0.8, 0.6, 1.0)))

	if spell.lifesteal_percent > 0:
		vbox.add_child(_make_label("Lifesteal %d%%" % int(spell.lifesteal_percent * 100), Color(0.8, 0.6, 1.0)))

	if spell.manasteal_percent > 0:
		vbox.add_child(_make_label("Manasteal %d%%" % int(spell.manasteal_percent * 100), Color(0.4, 0.6, 1.0)))

	if spell.inflicts_condition != Enums.Condition.NONE and spell.condition_chance > 0:
		var cond_name: String = Enums.Condition.keys()[spell.inflicts_condition]
		vbox.add_child(_make_label("Inflicts %s (%d%%, %.1fs)" % [
			cond_name.capitalize().replace("_", " "),
			int(spell.condition_chance * 100),
			spell.condition_duration
		], Color(0.8, 0.6, 1.0)))

	if spell.aoe_radius > 0:
		vbox.add_child(_make_label("AOE Radius: %.1fm" % spell.aoe_radius, Color(0.8, 0.6, 1.0)))

func _add_spell_stat_row(vbox: VBoxContainer, stat_name: String, value: float, equipped_value: float, format: String, lower_is_better: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = stat_name + ":"
	name_lbl.custom_minimum_size.x = 70
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = format % value
	val_lbl.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(val_lbl)

	# Comparison if equipped_value is valid (>= 0)
	if equipped_value >= 0:
		var diff := value - equipped_value
		if lower_is_better:
			diff = -diff  # Invert for "lower is better" stats
		var indicator := Label.new()
		indicator.custom_minimum_size.x = 50
		if abs(value - equipped_value) < 0.01:
			indicator.text = ""
		elif diff > 0:
			var actual_diff := value - equipped_value
			if lower_is_better:
				indicator.text = "  [%+d]" % int(actual_diff)
			else:
				indicator.text = "  [%+d]" % int(actual_diff)
			indicator.add_theme_color_override("font_color", COL_GREEN if diff > 0 else COL_RED)
		else:
			var actual_diff := value - equipped_value
			indicator.text = "  [%+d]" % int(actual_diff)
			indicator.add_theme_color_override("font_color", COL_RED if diff < 0 else COL_GREEN)
		row.add_child(indicator)

	vbox.add_child(row)

func _calculate_spell_avg_effect(spell: SpellData) -> float:
	if spell.base_effect.size() < 3:
		return 0.0
	var dice: int = spell.base_effect[0]
	var sides: int = spell.base_effect[1]
	var bonus: int = spell.base_effect[2]
	return (dice * (sides + 1.0) / 2.0) + bonus

# ==================== JOURNAL TAB ====================
func _build_journal_panel() -> Control:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox = VBoxContainer.new()
	vbox.name = "JournalContent"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	return scroll

func _refresh_journal() -> void:
	var panel = tab_panels[MenuTab.JOURNAL]
	var vbox = panel.find_child("JournalContent", true, false)
	if not vbox:
		return

	_clear_children_immediate(vbox)

	var tracked_id := QuestManager.get_tracked_quest_id()

	vbox.add_child(_make_label("ACTIVE QUESTS", COL_GOLD))
	var hint := _make_label("Click a quest to track it on your compass", COL_DIM)
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)
	vbox.add_child(HSeparator.new())

	var active_quests = QuestManager.get_active_quests()
	if active_quests.is_empty():
		vbox.add_child(_make_label("No active quests.", COL_DIM))
	else:
		for quest in active_quests:
			var is_tracked: bool = (quest.id == tracked_id)
			# Create clickable quest header button
			var quest_btn := Button.new()
			quest_btn.flat = true
			quest_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var track_indicator := "[>] " if is_tracked else "    "
			quest_btn.text = track_indicator + quest.title
			quest_btn.add_theme_color_override("font_color", COL_GOLD if is_tracked else COL_TEXT)
			quest_btn.add_theme_color_override("font_hover_color", COL_GOLD)
			quest_btn.add_theme_color_override("font_pressed_color", COL_GOLD)
			quest_btn.pressed.connect(_on_quest_track_clicked.bind(quest.id))
			quest_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			vbox.add_child(quest_btn)

			vbox.add_child(_make_label("  " + quest.description, COL_DIM))
			for obj in quest.objectives:
				var check := "[X]" if obj.is_completed else "[ ]"
				var progress := ""
				if obj.required_count > 1:
					progress = " (%d/%d)" % [obj.current_count, obj.required_count]
				var col := COL_GREEN if obj.is_completed else COL_TEXT
				vbox.add_child(_make_label("  %s %s%s" % [check, obj.description, progress], col))
			vbox.add_child(HSeparator.new())

	vbox.add_child(_make_label("COMPLETED QUESTS", COL_GOLD))
	vbox.add_child(HSeparator.new())

	var completed_quests = QuestManager.get_completed_quests()
	if completed_quests.is_empty():
		vbox.add_child(_make_label("No completed quests.", COL_DIM))
	else:
		for quest in completed_quests:
			vbox.add_child(_make_label(quest.title + " [DONE]", COL_DIM))

## Handle quest tracking button click
func _on_quest_track_clicked(quest_id: String) -> void:
	QuestManager.set_tracked_quest(quest_id)
	AudioManager.play_ui_confirm()
	_refresh_journal()  # Refresh to update visual indicator

# ==================== HELPERS ====================
func _make_label(text: String, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _style_item_list(list: ItemList) -> void:
	var bg = StyleBoxFlat.new()
	bg.bg_color = COL_BG
	bg.border_color = COL_BORDER
	bg.set_border_width_all(1)
	list.add_theme_stylebox_override("panel", bg)

	var sel = StyleBoxFlat.new()
	sel.bg_color = COL_SELECT
	list.add_theme_stylebox_override("selected", sel)
	list.add_theme_stylebox_override("selected_focus", sel)
	list.add_theme_color_override("font_color", COL_TEXT)
	list.add_theme_color_override("font_selected_color", COL_GOLD)

func _refresh_tab() -> void:
	match current_tab:
		MenuTab.CHARACTER:
			_refresh_character()
		MenuTab.ITEMS:
			_refresh_items()
		MenuTab.MAGIC:
			_refresh_magic()
		MenuTab.JOURNAL:
			_refresh_journal()
		MenuTab.MAP:
			_refresh_map()


# ==================== MAP TAB ====================

## Map display constants
const MAP_CELL_SIZE := 20  # Pixels per grid cell
const MAP_COLORS := {
	"undiscovered": Color(0.15, 0.15, 0.18),
	"discovered": Color(0.25, 0.25, 0.3),
	"road": Color(0.4, 0.35, 0.25),
	"settlement": Color(0.6, 0.5, 0.3),
	"dungeon": Color(0.5, 0.3, 0.3),
	"current": Color(0.3, 0.8, 0.3),
	"water": Color(0.2, 0.3, 0.5),
	"mountain": Color(0.35, 0.35, 0.4),
	"forest": Color(0.2, 0.35, 0.2),
	"swamp": Color(0.2, 0.25, 0.18),
	"desert": Color(0.5, 0.45, 0.3),
	"plains": Color(0.4, 0.45, 0.3)
}

func _build_map_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	var vbox := VBoxContainer.new()
	vbox.name = "MapContent"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	return scroll


func _refresh_map() -> void:
	var panel: Control = tab_panels[MenuTab.MAP]
	var vbox: VBoxContainer = panel.find_child("MapContent", true, false)
	if not vbox:
		return

	_clear_children_immediate(vbox)

	# Title
	var title := _make_label("WORLD MAP", COL_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Current location info
	var current_coords := SceneManager.current_room_coords if SceneManager else Vector2i.ZERO
	var current_cell := WorldData.get_cell(current_coords)
	var location_text := "Current Location: "
	if current_cell and not current_cell.location_name.is_empty():
		location_text += current_cell.location_name
	else:
		location_text += WorldData.get_cell_name(current_coords)
	location_text += " (%d, %d)" % [current_coords.x, current_coords.y]

	var location_label := _make_label(location_text, COL_TEXT)
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(location_label)

	# Region info
	var region_label := _make_label("Region: " + WorldData.get_region_name(current_coords), COL_DIM)
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(region_label)

	vbox.add_child(HSeparator.new())

	# Map container (centered)
	var map_container := CenterContainer.new()
	map_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(map_container)

	# Create the actual map grid
	var map_grid := _create_map_grid(current_coords)
	map_container.add_child(map_grid)

	# Legend
	vbox.add_child(HSeparator.new())
	var legend := _create_map_legend()
	vbox.add_child(legend)


func _create_map_grid(current_coords: Vector2i) -> Control:
	# Get world bounds
	var bounds := WorldData.get_world_bounds()
	var min_coords: Vector2i = bounds["min"]
	var max_coords: Vector2i = bounds["max"]

	# Add padding around the map
	min_coords -= Vector2i(1, 1)
	max_coords += Vector2i(1, 1)

	var width: int = max_coords.x - min_coords.x + 1
	var height: int = max_coords.y - min_coords.y + 1

	# Create grid container
	var grid := GridContainer.new()
	grid.columns = width
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)

	# Y axis is flipped in display (north at top, south at bottom)
	# But in our world data, negative Y is south, so we iterate from max to min
	for y in range(max_coords.y, min_coords.y - 1, -1):
		for x in range(min_coords.x, max_coords.x + 1):
			var coords := Vector2i(x, y)
			var cell_panel := _create_map_cell(coords, current_coords)
			grid.add_child(cell_panel)

	return grid


func _create_map_cell(coords: Vector2i, current_coords: Vector2i) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(MAP_CELL_SIZE, MAP_CELL_SIZE)

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(2)

	var cell := WorldData.get_cell(coords)
	var is_current: bool = (coords == current_coords)
	var is_discovered: bool = WorldData.is_discovered(coords)

	# Determine cell color
	var cell_color: Color = MAP_COLORS["undiscovered"]

	if cell:
		if is_current:
			cell_color = MAP_COLORS["current"]
		elif not cell.is_passable:
			# Impassable terrain (mountains, water)
			if cell.biome == WorldData.Biome.COAST:
				cell_color = MAP_COLORS["water"]
			else:
				cell_color = MAP_COLORS["mountain"]
		elif is_discovered or _is_adjacent_to_current(coords, current_coords):
			# Show terrain type for discovered or adjacent cells
			match cell.location_type:
				WorldData.LocationType.VILLAGE, WorldData.LocationType.TOWN, WorldData.LocationType.CITY, WorldData.LocationType.CAPITAL, WorldData.LocationType.OUTPOST:
					cell_color = MAP_COLORS["settlement"]
				WorldData.LocationType.DUNGEON:
					cell_color = MAP_COLORS["dungeon"]
				_:
					if cell.is_road:
						cell_color = MAP_COLORS["road"]
					else:
						# Biome-based color
						match cell.biome:
							WorldData.Biome.FOREST:
								cell_color = MAP_COLORS["forest"]
							WorldData.Biome.SWAMP:
								cell_color = MAP_COLORS["swamp"]
							WorldData.Biome.DESERT:
								cell_color = MAP_COLORS["desert"]
							WorldData.Biome.PLAINS, WorldData.Biome.COAST:
								cell_color = MAP_COLORS["plains"]
							_:
								cell_color = MAP_COLORS["discovered"]
		else:
			cell_color = MAP_COLORS["undiscovered"]
	else:
		# Undefined cell - unexplored wilderness
		cell_color = MAP_COLORS["undiscovered"]

	style.bg_color = cell_color

	# Add border for current location
	if is_current:
		style.border_color = COL_GOLD
		style.set_border_width_all(2)

	panel.add_theme_stylebox_override("panel", style)

	# Add tooltip with cell info
	if cell and (is_discovered or is_current or _is_adjacent_to_current(coords, current_coords)):
		var tooltip := ""
		if not cell.location_name.is_empty():
			tooltip = cell.location_name
		else:
			tooltip = WorldData.Biome.keys()[cell.biome].capitalize()
		tooltip += "\n(%d, %d)" % [coords.x, coords.y]
		if not cell.region_name.is_empty():
			tooltip += "\n" + cell.region_name
		panel.tooltip_text = tooltip

	return panel


func _is_adjacent_to_current(coords: Vector2i, current: Vector2i) -> bool:
	var diff := coords - current
	return abs(diff.x) <= 1 and abs(diff.y) <= 1


func _create_map_legend() -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)

	var legend_items := [
		{"color": MAP_COLORS["current"], "text": "You"},
		{"color": MAP_COLORS["settlement"], "text": "Settlement"},
		{"color": MAP_COLORS["dungeon"], "text": "Dungeon"},
		{"color": MAP_COLORS["road"], "text": "Road"},
		{"color": MAP_COLORS["water"], "text": "Water"},
		{"color": MAP_COLORS["mountain"], "text": "Mountain"}
	]

	for item: Dictionary in legend_items:
		var item_hbox := HBoxContainer.new()
		item_hbox.add_theme_constant_override("separation", 4)

		var color_rect := ColorRect.new()
		color_rect.custom_minimum_size = Vector2(12, 12)
		color_rect.color = item["color"]
		item_hbox.add_child(color_rect)

		var label := Label.new()
		label.text = item["text"]
		label.add_theme_color_override("font_color", COL_DIM)
		label.add_theme_font_size_override("font_size", 12)
		item_hbox.add_child(label)

		hbox.add_child(item_hbox)

	return hbox


# ==================== OPEN / CLOSE ====================
func open() -> void:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GameManager.enter_menu()
	get_tree().paused = true
	_refresh_stats_bar()
	_refresh_tab()

func close() -> void:
	visible = false
	# Hide tooltip and reset selection state
	_hide_hover_tooltip()
	selected_item_idx = -1
	selected_equip_slot = ""
	item_list_ref = null  # Clear reference
	spell_list_ref = null  # Clear spell list reference
	hovered_spell_idx = -1
	context_menu_target = {}
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameManager.exit_menu()
	get_tree().paused = false
	menu_closed.emit()
