## enchanting_ui.gd - UI for enchanting equipment at enchanting stations
class_name EnchantingUI
extends CanvasLayer

signal closed

## Reference to the station that opened this UI
var station: Node = null

## UI components
var root_panel: PanelContainer
var title_label: Label
var equipment_list: ItemList
var enchantment_list: ItemList
var preview_panel: PanelContainer
var preview_label: Label
var cost_label: Label
var requirements_label: Label
var apply_button: Button
var close_button: Button
var soulstone_label: Label

## Currently selected equipment slot
var selected_slot: String = ""
## Currently selected enchantment
var selected_enchantment: EnchantmentData = null

## Equipment slot display names
const SLOT_NAMES: Dictionary = {
	"main_hand": "Weapon",
	"off_hand": "Shield/Off-hand",
	"head": "Head",
	"body": "Body",
	"hands": "Hands",
	"feet": "Feet",
	"ring_1": "Ring 1",
	"ring_2": "Ring 2",
	"amulet": "Amulet"
}

func _ready() -> void:
	_create_ui()
	_populate_equipment()
	_update_soulstone_display()

func _create_ui() -> void:
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Main panel
	root_panel = PanelContainer.new()
	root_panel.anchors_preset = Control.PRESET_CENTER
	root_panel.anchor_left = 0.5
	root_panel.anchor_right = 0.5
	root_panel.anchor_top = 0.5
	root_panel.anchor_bottom = 0.5
	root_panel.offset_left = -350
	root_panel.offset_right = 350
	root_panel.offset_top = -250
	root_panel.offset_bottom = 250
	add_child(root_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.15, 0.95)
	style.border_color = Color(0.5, 0.3, 0.7)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	root_panel.add_theme_stylebox_override("panel", style)

	# Main VBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	root_panel.add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "ENCHANTING TABLE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	vbox.add_child(title_label)

	# Soulstone display
	soulstone_label = Label.new()
	soulstone_label.text = "Soulstones: None"
	soulstone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soulstone_label.add_theme_font_size_override("font_size", 14)
	soulstone_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(soulstone_label)

	# Content HBox (equipment list + enchantment list)
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 16)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_hbox)

	# Equipment list panel
	var equip_vbox := VBoxContainer.new()
	equip_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(equip_vbox)

	var equip_label := Label.new()
	equip_label.text = "Select Equipment"
	equip_label.add_theme_font_size_override("font_size", 16)
	equip_vbox.add_child(equip_label)

	equipment_list = ItemList.new()
	equipment_list.custom_minimum_size = Vector2(180, 200)
	equipment_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_list.item_selected.connect(_on_equipment_selected)
	equip_vbox.add_child(equipment_list)

	# Enchantment list panel
	var ench_vbox := VBoxContainer.new()
	ench_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(ench_vbox)

	var ench_label := Label.new()
	ench_label.text = "Select Enchantment"
	ench_label.add_theme_font_size_override("font_size", 16)
	ench_vbox.add_child(ench_label)

	enchantment_list = ItemList.new()
	enchantment_list.custom_minimum_size = Vector2(180, 200)
	enchantment_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enchantment_list.item_selected.connect(_on_enchantment_selected)
	ench_vbox.add_child(enchantment_list)

	# Preview panel
	preview_panel = PanelContainer.new()
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	preview_style.set_border_width_all(1)
	preview_style.border_color = Color(0.4, 0.3, 0.5)
	preview_style.content_margin_left = 12
	preview_style.content_margin_right = 12
	preview_style.content_margin_top = 8
	preview_style.content_margin_bottom = 8
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	vbox.add_child(preview_panel)

	var preview_vbox := VBoxContainer.new()
	preview_vbox.add_theme_constant_override("separation", 4)
	preview_panel.add_child(preview_vbox)

	preview_label = Label.new()
	preview_label.text = "Select equipment and enchantment"
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_vbox.add_child(preview_label)

	cost_label = Label.new()
	cost_label.text = ""
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	preview_vbox.add_child(cost_label)

	requirements_label = Label.new()
	requirements_label.text = ""
	requirements_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
	preview_vbox.add_child(requirements_label)

	# Button row
	var button_hbox := HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 16)
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_hbox)

	apply_button = Button.new()
	apply_button.text = "Apply Enchantment"
	apply_button.custom_minimum_size = Vector2(160, 40)
	apply_button.disabled = true
	apply_button.pressed.connect(_on_apply_pressed)
	button_hbox.add_child(apply_button)

	close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(100, 40)
	close_button.pressed.connect(_on_close_pressed)
	button_hbox.add_child(close_button)

func _populate_equipment() -> void:
	equipment_list.clear()

	for slot in SLOT_NAMES:
		var equip_data: Dictionary = InventoryManager.equipment.get(slot, {})
		if equip_data.is_empty() or not equip_data.has("item_id"):
			continue

		var item_name: String = InventoryManager.get_item_name(equip_data.item_id)
		var has_enchant: bool = equip_data.has("enchantments") and not equip_data.enchantments.is_empty()

		var display_text: String = "%s: %s" % [SLOT_NAMES[slot], item_name]
		if has_enchant:
			display_text += " [ENCHANTED]"

		var idx: int = equipment_list.add_item(display_text)
		equipment_list.set_item_metadata(idx, slot)

		# Gray out already enchanted items
		if has_enchant:
			equipment_list.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5))

func _populate_enchantments() -> void:
	enchantment_list.clear()
	selected_enchantment = null

	if selected_slot.is_empty():
		return

	var available: Array[EnchantmentData] = EnchantmentManager.get_enchantments_for_slot(selected_slot)

	for ench in available:
		var idx: int = enchantment_list.add_item(ench.display_name)
		enchantment_list.set_item_metadata(idx, ench.id)

		# Check if player meets requirements
		var check := EnchantmentManager.can_apply_enchantment(ench.id, selected_slot)
		if not check.can_apply:
			enchantment_list.set_item_custom_fg_color(idx, Color(0.6, 0.4, 0.4))

func _update_soulstone_display() -> void:
	var filled_count: int = 0
	for i in range(5):
		if InventoryManager.has_item(EnchantmentManager.FILLED_SOULSTONE_IDS[i]):
			filled_count += InventoryManager.get_item_count(EnchantmentManager.FILLED_SOULSTONE_IDS[i])

	if filled_count > 0:
		soulstone_label.text = "Filled Soulstones: %d" % filled_count
		soulstone_label.add_theme_color_override("font_color", Color(0.6, 0.4, 1.0))
	else:
		soulstone_label.text = "No filled soulstones"
		soulstone_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func _update_preview() -> void:
	if selected_slot.is_empty() or not selected_enchantment:
		preview_label.text = "Select equipment and enchantment"
		cost_label.text = ""
		requirements_label.text = ""
		apply_button.disabled = true
		return

	var equip_data: Dictionary = InventoryManager.equipment.get(selected_slot, {})
	var item_name: String = InventoryManager.get_item_name(equip_data.get("item_id", ""))

	preview_label.text = "%s -> %s\n%s" % [
		selected_enchantment.display_name,
		item_name,
		selected_enchantment.get_effect_string()
	]

	cost_label.text = "Cost: %d gold + %s soulstone" % [
		selected_enchantment.gold_cost,
		SoulstoneData.get_tier_name(selected_enchantment.min_soulstone_tier)
	]

	var check := EnchantmentManager.can_apply_enchantment(selected_enchantment.id, selected_slot)
	if check.can_apply:
		requirements_label.text = ""
		apply_button.disabled = false
	else:
		requirements_label.text = check.reason
		apply_button.disabled = true

func _on_equipment_selected(index: int) -> void:
	selected_slot = equipment_list.get_item_metadata(index)
	selected_enchantment = null
	_populate_enchantments()
	_update_preview()

func _on_enchantment_selected(index: int) -> void:
	var ench_id: String = enchantment_list.get_item_metadata(index)
	selected_enchantment = EnchantmentManager.get_enchantment(ench_id)
	_update_preview()

func _on_apply_pressed() -> void:
	if selected_slot.is_empty() or not selected_enchantment:
		return

	var success := EnchantmentManager.apply_enchantment(selected_enchantment.id, selected_slot)
	if success:
		# Refresh displays
		_populate_equipment()
		_populate_enchantments()
		_update_soulstone_display()
		_update_preview()

		# Show success message
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Enchantment applied!")

func _on_close_pressed() -> void:
	close()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	_populate_equipment()
	_update_soulstone_display()

func close() -> void:
	if station and station.has_method("close"):
		station.close()
	else:
		closed.emit()
		queue_free()
