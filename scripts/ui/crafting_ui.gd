## crafting_ui.gd - Crafting interface at anvil/forge
## Shows available recipes, required materials, and crafting results
class_name CraftingUI
extends Control

signal ui_closed

# Dark gothic colors (matching game_menu.gd)
const COL_BG = Color(0.08, 0.08, 0.1)
const COL_PANEL = Color(0.12, 0.12, 0.15)
const COL_BORDER = Color(0.3, 0.25, 0.2)
const COL_TEXT = Color(0.9, 0.85, 0.75)
const COL_DIM = Color(0.5, 0.5, 0.5)
const COL_GOLD = Color(0.8, 0.6, 0.2)
const COL_SELECT = Color(0.25, 0.2, 0.15)
const COL_GREEN = Color(0.3, 0.8, 0.3)
const COL_RED = Color(0.8, 0.3, 0.3)
const COL_BLUE = Color(0.4, 0.6, 0.9)

# UI references
var category_tabs: HBoxContainer
var recipe_list: VBoxContainer
var recipe_scroll: ScrollContainer
var detail_panel: PanelContainer
var detail_name: Label
var detail_desc: Label
var materials_list: VBoxContainer
var requirements_label: Label
var craft_button: Button
var result_label: Label
var gold_label: Label

# State
var current_category: String = "Weapon"
var selected_recipe: CraftingRecipe = null
var category_buttons: Dictionary = {}  # category -> Button

# Station type filtering - limits which categories are shown
# "blacksmith" = Weapon, Armor, Tool, Material (no potions)
# "alchemy" = Consumable only
# "" = all categories
var station_type: String = ""

const STATION_CATEGORIES := {
	"blacksmith": ["Weapon", "Armor", "Tool", "Material"],
	"alchemy": ["Consumable"],
}


func _ready() -> void:
	visible = false
	_build_ui()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.75)
	add_child(overlay)

	# Main panel
	var main = PanelContainer.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.offset_left = 40
	main.offset_top = 30
	main.offset_right = -40
	main.offset_bottom = -30
	var main_style = StyleBoxFlat.new()
	main_style.bg_color = COL_BG
	main_style.border_color = COL_BORDER
	main_style.set_border_width_all(2)
	main.add_theme_stylebox_override("panel", main_style)
	add_child(main)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 15
	vbox.offset_top = 10
	vbox.offset_right = -15
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 8)
	main.add_child(vbox)

	# Header row with title and gold
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	vbox.add_child(header)

	var title = Label.new()
	title.text = "CRAFTING"
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var gold_row = HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 5)
	header.add_child(gold_row)

	var gold_title = Label.new()
	gold_title.text = "Gold:"
	gold_title.add_theme_color_override("font_color", COL_TEXT)
	gold_row.add_child(gold_title)

	gold_label = Label.new()
	gold_label.text = "0"
	gold_label.add_theme_color_override("font_color", COL_GOLD)
	gold_row.add_child(gold_label)

	vbox.add_child(_make_separator())

	# Category tabs - filter based on station type
	category_tabs = HBoxContainer.new()
	category_tabs.add_theme_constant_override("separation", 5)
	vbox.add_child(category_tabs)

	var allowed_cats: Array = _get_allowed_categories()

	# Set default category to first allowed
	if allowed_cats.size() > 0 and current_category not in allowed_cats:
		current_category = allowed_cats[0]

	for cat in allowed_cats:
		var btn = Button.new()
		btn.text = cat
		btn.toggle_mode = true
		btn.button_pressed = (cat == current_category)
		btn.pressed.connect(_on_category_selected.bind(cat))
		_style_tab_button(btn)
		category_tabs.add_child(btn)
		category_buttons[cat] = btn

	vbox.add_child(_make_separator())

	# Main content - split between recipe list and details
	var content = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 15)
	vbox.add_child(content)

	# Left side - Recipe list
	var list_panel = PanelContainer.new()
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_stretch_ratio = 0.4
	var list_style = StyleBoxFlat.new()
	list_style.bg_color = COL_PANEL
	list_style.border_color = COL_BORDER
	list_style.set_border_width_all(1)
	list_panel.add_theme_stylebox_override("panel", list_style)
	content.add_child(list_panel)

	recipe_scroll = ScrollContainer.new()
	recipe_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(recipe_scroll)

	recipe_list = VBoxContainer.new()
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_list.add_theme_constant_override("separation", 2)
	recipe_scroll.add_child(recipe_list)

	# Right side - Recipe details
	detail_panel = PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_stretch_ratio = 0.6
	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = COL_PANEL
	detail_style.border_color = COL_BORDER
	detail_style.set_border_width_all(1)
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	content.add_child(detail_panel)

	var detail_vbox = VBoxContainer.new()
	detail_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_vbox.offset_left = 10
	detail_vbox.offset_top = 10
	detail_vbox.offset_right = -10
	detail_vbox.offset_bottom = -10
	detail_vbox.add_theme_constant_override("separation", 8)
	detail_panel.add_child(detail_vbox)

	detail_name = Label.new()
	detail_name.text = "Select a recipe"
	detail_name.add_theme_color_override("font_color", COL_GOLD)
	detail_name.add_theme_font_size_override("font_size", 16)
	detail_vbox.add_child(detail_name)

	detail_desc = Label.new()
	detail_desc.text = ""
	detail_desc.add_theme_color_override("font_color", COL_TEXT)
	detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_vbox.add_child(detail_desc)

	detail_vbox.add_child(_make_separator())

	var mat_header = Label.new()
	mat_header.text = "Required Materials:"
	mat_header.add_theme_color_override("font_color", COL_DIM)
	detail_vbox.add_child(mat_header)

	materials_list = VBoxContainer.new()
	materials_list.add_theme_constant_override("separation", 4)
	detail_vbox.add_child(materials_list)

	requirements_label = Label.new()
	requirements_label.text = ""
	requirements_label.add_theme_color_override("font_color", COL_DIM)
	detail_vbox.add_child(requirements_label)

	# Spacer
	var detail_spacer = Control.new()
	detail_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(detail_spacer)

	# Result label (shows crafting outcome)
	result_label = Label.new()
	result_label.text = ""
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 14)
	detail_vbox.add_child(result_label)

	# Craft button
	craft_button = Button.new()
	craft_button.text = "CRAFT"
	craft_button.disabled = true
	craft_button.pressed.connect(_on_craft_pressed)
	_style_button(craft_button)
	detail_vbox.add_child(craft_button)

	vbox.add_child(_make_separator())

	# Bottom buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 15)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var close_btn = Button.new()
	close_btn.text = "Close [Esc]"
	close_btn.pressed.connect(close)
	_style_button(close_btn)
	btn_row.add_child(close_btn)


func _on_category_selected(category: String) -> void:
	current_category = category

	# Update tab buttons
	for cat in category_buttons:
		category_buttons[cat].button_pressed = (cat == category)

	# Clear selection
	selected_recipe = null
	_update_detail_panel()

	# Refresh recipe list
	_refresh_recipe_list()


func _refresh_recipe_list() -> void:
	# Clear existing
	for child in recipe_list.get_children():
		child.queue_free()

	# Get recipes for current category
	var recipes := CraftingManager.get_recipes_by_category(current_category)

	for recipe in recipes:
		var row = _create_recipe_row(recipe)
		recipe_list.add_child(row)


func _create_recipe_row(recipe: CraftingRecipe) -> Control:
	var btn = Button.new()
	btn.text = recipe.display_name
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_recipe_selected.bind(recipe))

	# Style based on craftability
	var can_craft := recipe.can_craft() and recipe.meets_requirements()

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.1, 0.12)
	normal_style.set_content_margin_all(5)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = COL_SELECT
	hover_style.set_content_margin_all(5)

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)

	if can_craft:
		btn.add_theme_color_override("font_color", COL_GREEN)
	elif recipe.meets_requirements():
		btn.add_theme_color_override("font_color", COL_TEXT)
	else:
		btn.add_theme_color_override("font_color", COL_RED)

	return btn


func _on_recipe_selected(recipe: CraftingRecipe) -> void:
	selected_recipe = recipe
	_update_detail_panel()


func _update_detail_panel() -> void:
	# Clear materials list
	for child in materials_list.get_children():
		child.queue_free()

	result_label.text = ""

	if not selected_recipe:
		detail_name.text = "Select a recipe"
		detail_desc.text = ""
		requirements_label.text = ""
		craft_button.disabled = true
		return

	# Update name and description
	detail_name.text = selected_recipe.display_name
	detail_desc.text = selected_recipe.description

	# Show materials
	for item_id in selected_recipe.materials:
		var required: int = selected_recipe.materials[item_id]
		var have: int = InventoryManager.get_item_count(item_id)
		var item_name := InventoryManager.get_item_name(item_id)

		var mat_row = HBoxContainer.new()
		mat_row.add_theme_constant_override("separation", 10)
		materials_list.add_child(mat_row)

		var mat_name = Label.new()
		mat_name.text = "- %s" % item_name
		mat_name.add_theme_color_override("font_color", COL_TEXT)
		mat_row.add_child(mat_name)

		var mat_qty = Label.new()
		mat_qty.text = "(%d/%d)" % [have, required]
		if have >= required:
			mat_qty.add_theme_color_override("font_color", COL_GREEN)
		else:
			mat_qty.add_theme_color_override("font_color", COL_RED)
		mat_row.add_child(mat_qty)

	# Show gold cost
	if selected_recipe.gold_cost > 0:
		var gold_row = HBoxContainer.new()
		gold_row.add_theme_constant_override("separation", 10)
		materials_list.add_child(gold_row)

		var gold_name = Label.new()
		gold_name.text = "- Gold"
		gold_name.add_theme_color_override("font_color", COL_GOLD)
		gold_row.add_child(gold_name)

		var gold_qty = Label.new()
		gold_qty.text = "(%d/%d)" % [InventoryManager.gold, selected_recipe.gold_cost]
		if InventoryManager.gold >= selected_recipe.gold_cost:
			gold_qty.add_theme_color_override("font_color", COL_GREEN)
		else:
			gold_qty.add_theme_color_override("font_color", COL_RED)
		gold_row.add_child(gold_qty)

	# Show skill requirements
	var req_text := ""
	if selected_recipe.required_engineering > 0:
		var eng := 0
		if GameManager.player_data:
			eng = GameManager.player_data.get_skill(Enums.Skill.ENGINEERING)
		var met := eng >= selected_recipe.required_engineering
		req_text += "Engineering %d/%d " % [eng, selected_recipe.required_engineering]
		if not met:
			req_text += "[NEED MORE]"

	if selected_recipe.required_arcana > 0:
		var arc := 0
		if GameManager.player_data:
			arc = GameManager.player_data.get_skill(Enums.Skill.ARCANA_LORE)
		var met := arc >= selected_recipe.required_arcana
		if req_text.length() > 0:
			req_text += "\n"
		req_text += "Arcana Lore %d/%d " % [arc, selected_recipe.required_arcana]
		if not met:
			req_text += "[NEED MORE]"

	requirements_label.text = req_text

	# Update craft button
	var can_craft := selected_recipe.can_craft() and selected_recipe.meets_requirements()
	craft_button.disabled = not can_craft

	if can_craft:
		craft_button.text = "CRAFT"
	elif not selected_recipe.meets_requirements():
		craft_button.text = "INSUFFICIENT SKILL"
	else:
		craft_button.text = "MISSING MATERIALS"


func _on_craft_pressed() -> void:
	if not selected_recipe:
		return

	var result := CraftingManager.craft_recipe(selected_recipe.recipe_id)

	if result.success:
		# Show success message with quality
		var quality_name := _get_quality_name(result.quality)
		var item_name := InventoryManager.get_item_name(result.item_id)

		if result.quantity > 1:
			result_label.text = "Crafted %d x %s %s!" % [result.quantity, quality_name, item_name]
		else:
			result_label.text = "Crafted %s %s!" % [quality_name, item_name]

		result_label.add_theme_color_override("font_color", COL_GREEN)

		# Play sound
		AudioManager.play_sfx("item_pickup")
	else:
		result_label.text = "Failed: %s" % result.reason
		result_label.add_theme_color_override("font_color", COL_RED)

	# Refresh display
	_refresh_display()


func _get_quality_name(quality: Enums.ItemQuality) -> String:
	match quality:
		Enums.ItemQuality.POOR:
			return "[Poor]"
		Enums.ItemQuality.BELOW_AVERAGE:
			return "[Worn]"
		Enums.ItemQuality.AVERAGE:
			return ""
		Enums.ItemQuality.ABOVE_AVERAGE:
			return "[Fine]"
		Enums.ItemQuality.PERFECT:
			return "[Perfect]"
	return ""


func _refresh_display() -> void:
	gold_label.text = str(InventoryManager.gold)
	_refresh_recipe_list()
	_update_detail_panel()


func _style_tab_button(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = COL_PANEL
	normal.border_color = COL_BORDER
	normal.set_border_width_all(1)
	normal.set_content_margin_all(6)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = COL_SELECT
	pressed.border_color = COL_GOLD
	pressed.set_border_width_all(2)
	pressed.set_content_margin_all(6)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_pressed_color", COL_GOLD)


func _style_button(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = COL_PANEL
	normal.border_color = COL_BORDER
	normal.set_border_width_all(1)
	normal.set_content_margin_all(8)

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
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_pressed_color", COL_GOLD)
	btn.add_theme_color_override("font_disabled_color", COL_DIM)


func _make_separator() -> Control:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 5)
	return sep


## Get allowed categories based on station type
func _get_allowed_categories() -> Array:
	if station_type != "" and STATION_CATEGORIES.has(station_type):
		return STATION_CATEGORIES[station_type]
	return CraftingManager.categories


func open() -> void:
	visible = true
	_refresh_display()


func close() -> void:
	visible = false
	ui_closed.emit()
