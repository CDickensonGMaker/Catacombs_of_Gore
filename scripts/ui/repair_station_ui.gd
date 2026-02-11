## repair_station_ui.gd - Repair station menu UI
## Allows player to repair equipment durability and restore quality
class_name RepairStationUI
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
const COL_YELLOW = Color(1.0, 0.8, 0.3)

# Equipment slots to display (excluding accessories)
const EQUIPMENT_SLOTS = ["main_hand", "off_hand", "head", "body", "hands", "feet"]
const SLOT_NAMES = {
	"main_hand": "Weapon",
	"off_hand": "Off-Hand",
	"head": "Head",
	"body": "Body",
	"hands": "Hands",
	"feet": "Feet"
}

# UI element references
var equipment_rows: Dictionary = {}  # slot -> {row, name_label, durability_label, repair_btn, restore_btn}
var gold_label: Label
var total_cost_label: Label
var repair_all_btn: Button

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
	# Set root control to fill viewport
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.75)
	add_child(overlay)

	# Main panel (same layout as game_menu.gd)
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
	vbox.add_theme_constant_override("separation", 10)
	main.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "REPAIR STATION"
	title.add_theme_color_override("font_color", COL_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_make_separator())

	# Gold display
	var gold_row = HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 10)
	vbox.add_child(gold_row)

	var gold_title = Label.new()
	gold_title.text = "Gold: "
	gold_title.add_theme_color_override("font_color", COL_TEXT)
	gold_row.add_child(gold_title)

	gold_label = Label.new()
	gold_label.text = "0"
	gold_label.add_theme_color_override("font_color", COL_GOLD)
	gold_row.add_child(gold_label)

	vbox.add_child(_make_separator())

	# Equipment header
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	vbox.add_child(header)

	var h_slot = Label.new()
	h_slot.text = "Slot"
	h_slot.custom_minimum_size.x = 80
	h_slot.add_theme_color_override("font_color", COL_DIM)
	header.add_child(h_slot)

	var h_name = Label.new()
	h_name.text = "Item"
	h_name.custom_minimum_size.x = 120
	h_name.add_theme_color_override("font_color", COL_DIM)
	header.add_child(h_name)

	var h_dur = Label.new()
	h_dur.text = "Durability"
	h_dur.custom_minimum_size.x = 80
	h_dur.add_theme_color_override("font_color", COL_DIM)
	header.add_child(h_dur)

	var h_actions = Label.new()
	h_actions.text = "Actions"
	h_actions.add_theme_color_override("font_color", COL_DIM)
	header.add_child(h_actions)

	# Equipment rows
	for slot in EQUIPMENT_SLOTS:
		var row_data := _create_equipment_row(slot)
		vbox.add_child(row_data.row)
		equipment_rows[slot] = row_data

	vbox.add_child(_make_separator())

	# Total repair cost
	var total_row = HBoxContainer.new()
	total_row.add_theme_constant_override("separation", 10)
	vbox.add_child(total_row)

	var total_title = Label.new()
	total_title.text = "Total Repair Cost: "
	total_title.add_theme_color_override("font_color", COL_TEXT)
	total_row.add_child(total_title)

	total_cost_label = Label.new()
	total_cost_label.text = "0"
	total_cost_label.add_theme_color_override("font_color", COL_GOLD)
	total_row.add_child(total_cost_label)

	# Bottom buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 15)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	repair_all_btn = Button.new()
	repair_all_btn.text = "Repair All"
	repair_all_btn.pressed.connect(_on_repair_all)
	_style_button(repair_all_btn)
	btn_row.add_child(repair_all_btn)

	var close_btn = Button.new()
	close_btn.text = "Close [Esc]"
	close_btn.pressed.connect(close)
	_style_button(close_btn)
	btn_row.add_child(close_btn)

func _create_equipment_row(slot: String) -> Dictionary:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)

	# Slot name
	var slot_label = Label.new()
	slot_label.text = SLOT_NAMES.get(slot, slot)
	slot_label.custom_minimum_size.x = 80
	slot_label.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(slot_label)

	# Item name
	var name_label = Label.new()
	name_label.text = "-"
	name_label.custom_minimum_size.x = 120
	name_label.add_theme_color_override("font_color", COL_DIM)
	row.add_child(name_label)

	# Durability display
	var durability_label = Label.new()
	durability_label.text = "-"
	durability_label.custom_minimum_size.x = 80
	durability_label.add_theme_color_override("font_color", COL_DIM)
	row.add_child(durability_label)

	# Action buttons container
	var action_box = HBoxContainer.new()
	action_box.add_theme_constant_override("separation", 5)
	row.add_child(action_box)

	# Repair button
	var repair_btn = Button.new()
	repair_btn.text = "Repair"
	repair_btn.visible = false
	repair_btn.pressed.connect(_on_repair_slot.bind(slot))
	_style_small_button(repair_btn)
	action_box.add_child(repair_btn)

	# Restore Quality button
	var restore_btn = Button.new()
	restore_btn.text = "Restore"
	restore_btn.visible = false
	restore_btn.pressed.connect(_on_restore_quality.bind(slot))
	_style_small_button(restore_btn)
	action_box.add_child(restore_btn)

	return {
		"row": row,
		"slot_label": slot_label,
		"name_label": name_label,
		"durability_label": durability_label,
		"repair_btn": repair_btn,
		"restore_btn": restore_btn
	}

func _refresh_display() -> void:
	# Update gold
	gold_label.text = str(InventoryManager.gold)

	var total_cost := 0

	# Update each equipment row
	for slot in EQUIPMENT_SLOTS:
		var row_data: Dictionary = equipment_rows[slot]
		var equip: Dictionary = InventoryManager.equipment.get(slot, {})

		if equip.is_empty():
			row_data.name_label.text = "-"
			row_data.name_label.add_theme_color_override("font_color", COL_DIM)
			row_data.durability_label.text = "-"
			row_data.durability_label.add_theme_color_override("font_color", COL_DIM)
			row_data.repair_btn.visible = false
			row_data.restore_btn.visible = false
			continue

		# Item name with quality prefix
		var item_name := InventoryManager.get_item_name(equip.item_id)
		var quality: Enums.ItemQuality = equip.get("quality", Enums.ItemQuality.AVERAGE)
		var quality_prefix := ""
		match quality:
			Enums.ItemQuality.POOR: quality_prefix = "[Poor] "
			Enums.ItemQuality.BELOW_AVERAGE: quality_prefix = "[Worn] "
			Enums.ItemQuality.ABOVE_AVERAGE: quality_prefix = "[Fine] "
			Enums.ItemQuality.PERFECT: quality_prefix = "[Perfect] "

		row_data.name_label.text = quality_prefix + item_name
		row_data.name_label.add_theme_color_override("font_color", COL_TEXT)

		# Durability with color coding
		var durability_pct := InventoryManager.get_equipment_durability_percent(slot)
		var current_dur := InventoryManager.get_equipment_durability(slot)
		var max_dur := InventoryManager.get_equipment_max_durability(slot)

		row_data.durability_label.text = "%d%% (%d/%d)" % [int(durability_pct * 100), current_dur, max_dur]

		# Color based on durability percentage
		var dur_color := COL_GREEN
		if durability_pct < 0.25:
			dur_color = COL_RED
		elif durability_pct < 0.5:
			dur_color = COL_YELLOW
		row_data.durability_label.add_theme_color_override("font_color", dur_color)

		# Repair button
		var repair_cost := InventoryManager.get_repair_cost(slot)
		if repair_cost > 0:
			row_data.repair_btn.text = "Repair (%d)" % repair_cost
			row_data.repair_btn.visible = true
			row_data.repair_btn.disabled = InventoryManager.gold < repair_cost
			total_cost += repair_cost
		else:
			row_data.repair_btn.visible = false

		# Restore Quality button
		var restore_cost := InventoryManager.get_quality_restore_cost(slot)
		if restore_cost > 0:
			row_data.restore_btn.text = "Restore (%d)" % restore_cost
			row_data.restore_btn.visible = true
			row_data.restore_btn.disabled = InventoryManager.gold < restore_cost
		else:
			row_data.restore_btn.visible = false

	# Update total cost
	total_cost_label.text = str(total_cost)

	# Update repair all button
	repair_all_btn.disabled = total_cost <= 0 or InventoryManager.gold < total_cost

func _on_repair_slot(slot: String) -> void:
	if InventoryManager.repair_equipment(slot):
		# Sound effect hook for later
		# AudioManager.play_repair()
		_refresh_display()
	else:
		# Sound effect hook for later
		# AudioManager.play_ui_cancel()
		pass

func _on_restore_quality(slot: String) -> void:
	if InventoryManager.restore_equipment_quality(slot):
		# Sound effect hook for later
		# AudioManager.play_restore_quality()
		_refresh_display()
	else:
		# Sound effect hook for later
		# AudioManager.play_ui_cancel()
		pass

func _on_repair_all() -> void:
	var total_spent := InventoryManager.repair_all_equipment()
	if total_spent > 0:
		# Sound effect hook for later
		# AudioManager.play_repair()
		_refresh_display()

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

func _style_small_button(btn: Button) -> void:
	_style_button(btn)
	# Reduce padding for small buttons
	for style_name in ["normal", "pressed", "hover", "disabled"]:
		var style: StyleBoxFlat = btn.get_theme_stylebox(style_name)
		if style:
			style.set_content_margin_all(4)

func _make_separator() -> Control:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 5)
	return sep

func open() -> void:
	visible = true
	_refresh_display()

func close() -> void:
	visible = false
	ui_closed.emit()
