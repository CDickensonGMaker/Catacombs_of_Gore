## corpse_loot_ui.gd - UI for searching corpses (Fallout-style loot interface)
## Shows corpse contents with gold display, take all button, and close button
## Supports radius-based combined looting of multiple nearby corpses
extends Control

signal ui_closed

## Reference to the primary corpse we're looting (for backward compatibility)
var corpse: Node = null

## Array of all corpses being looted (within radius)
var corpses: Array = []

## UI colors (matching game_menu style)
const COL_BG = Color(0.08, 0.06, 0.05)  # Darker, more gore-ish
const COL_PANEL = Color(0.12, 0.10, 0.08)
const COL_BORDER = Color(0.4, 0.2, 0.15)  # Reddish-brown border
const COL_TEXT = Color(0.9, 0.85, 0.75)
const COL_DIM = Color(0.5, 0.45, 0.4)
const COL_GOLD = Color(0.85, 0.7, 0.3)
const COL_HOVER = Color(0.25, 0.15, 0.12)
const COL_BLOOD = Color(0.5, 0.15, 0.1)  # Blood red accent
const COL_SOURCE = Color(0.6, 0.55, 0.5)  # Dimmer color for source labels

## UI elements
var contents_list: VBoxContainer
var gold_label: Label
var title_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Close on escape, pause, or tab menu key
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("menu"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_refresh_contents()


func close() -> void:
	visible = false
	ui_closed.emit()


func _build_ui() -> void:
	# Click-outside overlay - clicking this closes the UI
	var click_outside := Button.new()
	click_outside.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_outside.flat = true
	click_outside.focus_mode = Control.FOCUS_NONE
	click_outside.mouse_filter = Control.MOUSE_FILTER_STOP
	click_outside.pressed.connect(close)
	add_child(click_outside)

	# Dark overlay (visual only)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# Main panel - centered, smaller than full screen
	var main_panel := PanelContainer.new()
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks from reaching overlay
	main_panel.offset_left = 150
	main_panel.offset_right = -150
	main_panel.offset_top = 100
	main_panel.offset_bottom = -100

	var main_style := StyleBoxFlat.new()
	main_style.bg_color = COL_BG
	main_style.border_color = COL_BORDER
	main_style.set_border_width_all(3)
	main_style.set_corner_radius_all(4)
	main_panel.add_theme_stylebox_override("panel", main_style)
	add_child(main_panel)

	# Main vertical layout
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 15
	main_vbox.offset_top = 15
	main_vbox.offset_right = -15
	main_vbox.offset_bottom = -15
	main_vbox.add_theme_constant_override("separation", 12)
	main_panel.add_child(main_vbox)

	# Title with blood red accent
	title_label = Label.new()
	title_label.text = "SEARCH BODY"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", COL_BLOOD)
	title_label.add_theme_font_size_override("font_size", 20)
	main_vbox.add_child(title_label)

	# Separator line
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = COL_BORDER
	main_vbox.add_child(sep)

	# Gold display row
	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 10)
	main_vbox.add_child(gold_row)

	var gold_icon := Label.new()
	gold_icon.text = "GOLD:"
	gold_icon.add_theme_color_override("font_color", COL_GOLD)
	gold_icon.add_theme_font_size_override("font_size", 14)
	gold_row.add_child(gold_icon)

	gold_label = Label.new()
	gold_label.text = "0"
	gold_label.add_theme_color_override("font_color", COL_GOLD)
	gold_label.add_theme_font_size_override("font_size", 14)
	gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_row.add_child(gold_label)

	var take_gold_btn := Button.new()
	take_gold_btn.text = "TAKE GOLD"
	take_gold_btn.custom_minimum_size = Vector2(100, 28)
	take_gold_btn.pressed.connect(_on_take_gold)
	take_gold_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(take_gold_btn)
	gold_row.add_child(take_gold_btn)

	# Items label
	var items_label := Label.new()
	items_label.text = "CONTENTS:"
	items_label.add_theme_color_override("font_color", COL_TEXT)
	items_label.add_theme_font_size_override("font_size", 13)
	main_vbox.add_child(items_label)

	# Scrollable contents panel
	var scroll_panel := PanelContainer.new()
	scroll_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_panel.custom_minimum_size = Vector2(360, 280)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COL_PANEL
	panel_style.border_color = COL_BORDER
	panel_style.set_border_width_all(1)
	scroll_panel.add_theme_stylebox_override("panel", panel_style)
	main_vbox.add_child(scroll_panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(340, 260)
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	scroll_panel.add_child(scroll)

	contents_list = VBoxContainer.new()
	contents_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents_list.add_theme_constant_override("separation", 3)
	scroll.add_child(contents_list)

	# Bottom buttons row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	main_vbox.add_child(btn_row)

	var take_all_btn := Button.new()
	take_all_btn.text = "TAKE ALL"
	take_all_btn.custom_minimum_size = Vector2(110, 32)
	take_all_btn.pressed.connect(_on_take_all)
	take_all_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(take_all_btn)
	btn_row.add_child(take_all_btn)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(110, 32)
	close_btn.pressed.connect(close)
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(close_btn)
	btn_row.add_child(close_btn)


func _refresh_contents() -> void:
	# Use corpses array if available, otherwise fall back to single corpse
	var all_corpses: Array = corpses if not corpses.is_empty() else ([corpse] if corpse else [])

	# Update title - show count if multiple corpses
	if all_corpses.size() > 1:
		title_label.text = "SEARCH BODIES (%d)" % all_corpses.size()
	elif all_corpses.size() == 1 and all_corpses[0]:
		title_label.text = all_corpses[0].corpse_name.to_upper()
	else:
		title_label.text = "SEARCH BODY"

	# Calculate total gold from all corpses
	var total_gold: int = 0
	for c in all_corpses:
		if c and is_instance_valid(c):
			total_gold += c.gold
	gold_label.text = str(total_gold)

	# Clear existing items
	for child in contents_list.get_children():
		child.queue_free()

	# Check if all corpses are empty
	var has_any_contents := false
	for c in all_corpses:
		if c and is_instance_valid(c) and not c.contents.is_empty():
			has_any_contents = true
			break

	if not has_any_contents:
		var empty_label := Label.new()
		empty_label.text = "Nothing else of value..."
		empty_label.add_theme_color_override("font_color", COL_DIM)
		empty_label.add_theme_font_size_override("font_size", 12)
		contents_list.add_child(empty_label)
		return

	# Add each item from all corpses as a clickable row
	# Track items with their source corpse for proper take/remove
	for corpse_idx in range(all_corpses.size()):
		var c = all_corpses[corpse_idx]
		if not c or not is_instance_valid(c):
			continue

		var show_source: bool = all_corpses.size() > 1

		for i in range(c.contents.size()):
			var slot: Dictionary = c.contents[i]
			var row := _create_item_row_multi(corpse_idx, i, slot, c.corpse_name if show_source else "")
			contents_list.add_child(row)


## Legacy function for single-corpse mode (backward compatibility)
func _create_item_row(index: int, slot: Dictionary) -> Control:
	return _create_item_row_multi(0, index, slot, "")


## Create an item row for multi-corpse mode
func _create_item_row_multi(corpse_idx: int, slot_idx: int, slot: Dictionary, source_name: String) -> Control:
	var item_id: String = slot.item_id
	var quantity: int = slot.quantity
	var quality: Enums.ItemQuality = slot.quality

	# Get item name
	var item_name := InventoryManager.get_item_name(item_id)

	# Quality prefix and color
	var quality_prefix := ""
	var quality_color := COL_TEXT
	match quality:
		Enums.ItemQuality.POOR:
			quality_prefix = "[Poor] "
			quality_color = Color(0.5, 0.5, 0.5)
		Enums.ItemQuality.BELOW_AVERAGE:
			quality_prefix = "[Worn] "
			quality_color = Color(0.7, 0.65, 0.6)
		Enums.ItemQuality.ABOVE_AVERAGE:
			quality_prefix = "[Fine] "
			quality_color = Color(0.4, 0.75, 0.9)
		Enums.ItemQuality.PERFECT:
			quality_prefix = "[Perfect] "
			quality_color = Color(1.0, 0.85, 0.3)

	var display_text := quality_prefix + item_name
	if quantity > 1:
		display_text += " x%d" % quantity

	# Container for item row with optional source label
	var row_container := VBoxContainer.new()
	row_container.add_theme_constant_override("separation", 0)

	# Clickable row button
	var row_btn := Button.new()
	row_btn.flat = true
	row_btn.custom_minimum_size.y = 24
	row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_btn.text = display_text
	row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row_btn.process_mode = Node.PROCESS_MODE_ALWAYS

	row_btn.add_theme_color_override("font_color", quality_color)
	row_btn.add_theme_color_override("font_hover_color", COL_GOLD)
	row_btn.add_theme_font_size_override("font_size", 12)

	# Hover style
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = COL_HOVER
	row_btn.add_theme_stylebox_override("hover", hover_style)

	row_btn.pressed.connect(_on_item_clicked_multi.bind(corpse_idx, slot_idx))
	row_container.add_child(row_btn)

	# Add source label if showing multiple corpses
	if not source_name.is_empty():
		var source_label := Label.new()
		source_label.text = "  from: " + source_name
		source_label.add_theme_color_override("font_color", COL_SOURCE)
		source_label.add_theme_font_size_override("font_size", 10)
		row_container.add_child(source_label)

	return row_container


## Legacy function for single-corpse mode
func _on_item_clicked(index: int) -> void:
	_on_item_clicked_multi(0, index)


## Take single item from specific corpse
func _on_item_clicked_multi(corpse_idx: int, slot_idx: int) -> void:
	var all_corpses: Array = corpses if not corpses.is_empty() else ([corpse] if corpse else [])

	if corpse_idx < 0 or corpse_idx >= all_corpses.size():
		return

	var target_corpse = all_corpses[corpse_idx]
	if not target_corpse or not is_instance_valid(target_corpse):
		return

	if slot_idx < 0 or slot_idx >= target_corpse.contents.size():
		return

	var slot: Dictionary = target_corpse.contents[slot_idx]
	var item_id: String = slot.item_id
	var quality: Enums.ItemQuality = slot.quality

	# Add to player inventory
	if InventoryManager.add_item(item_id, 1, quality):
		# Remove from corpse
		target_corpse.remove_item(item_id, 1, quality)

		# Play pickup sound
		AudioManager.play_item_pickup()

		# Check encumbrance
		if InventoryManager.is_overencumbered():
			_show_notification("You are overencumbered!")

		# Refresh
		_refresh_contents()
	else:
		AudioManager.play_ui_cancel()
		_show_notification("Unknown item: " + item_id)


func _on_take_gold() -> void:
	## Take all gold from all corpses
	var all_corpses: Array = corpses if not corpses.is_empty() else ([corpse] if corpse else [])

	var total_gold_taken: int = 0
	for c in all_corpses:
		if not c or not is_instance_valid(c):
			continue
		if c.gold > 0:
			total_gold_taken += c.take_gold()

	if total_gold_taken <= 0:
		AudioManager.play_ui_cancel()
		return

	InventoryManager.add_gold(total_gold_taken)
	AudioManager.play_item_pickup()
	_show_notification("Took %d gold" % total_gold_taken)
	_refresh_contents()


func _on_take_all() -> void:
	## Take everything from all nearby corpses
	var all_corpses: Array = corpses if not corpses.is_empty() else ([corpse] if corpse else [])

	var items_taken := 0

	for c in all_corpses:
		if not c or not is_instance_valid(c):
			continue

		# Take gold first
		if c.gold > 0:
			var gold_taken: int = c.take_gold()
			InventoryManager.add_gold(gold_taken)
			items_taken += 1

		# Take all items
		var contents_copy: Array = c.contents.duplicate(true)

		for slot in contents_copy:
			var item_id: String = slot.item_id
			var quantity: int = slot.quantity
			var quality: Enums.ItemQuality = slot.quality

			for i in range(quantity):
				if InventoryManager.add_item(item_id, 1, quality):
					c.remove_item(item_id, 1, quality)
					items_taken += 1
				else:
					break

	if items_taken > 0:
		AudioManager.play_item_pickup()
		_show_notification("Looted %d items" % items_taken)

		# Check encumbrance after taking all
		if InventoryManager.is_overencumbered():
			_show_notification("You are overencumbered!")
	else:
		AudioManager.play_ui_cancel()
		_show_notification("Nothing to take")

	_refresh_contents()


func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COL_PANEL
	normal.border_color = COL_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)

	var hover := StyleBoxFlat.new()
	hover.bg_color = COL_HOVER
	hover.border_color = COL_GOLD
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(2)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = COL_BLOOD
	pressed.border_color = COL_GOLD
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", COL_GOLD)


func _show_notification(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)
