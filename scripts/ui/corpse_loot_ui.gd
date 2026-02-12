## corpse_loot_ui.gd - UI for searching corpses (Fallout-style loot interface)
## Shows corpse contents with gold display, take all button, and close button
extends Control

signal ui_closed

## Reference to the corpse we're looting
var corpse: Node = null

## UI colors (matching game_menu style)
const COL_BG = Color(0.08, 0.06, 0.05)  # Darker, more gore-ish
const COL_PANEL = Color(0.12, 0.10, 0.08)
const COL_BORDER = Color(0.4, 0.2, 0.15)  # Reddish-brown border
const COL_TEXT = Color(0.9, 0.85, 0.75)
const COL_DIM = Color(0.5, 0.45, 0.4)
const COL_GOLD = Color(0.85, 0.7, 0.3)
const COL_HOVER = Color(0.25, 0.15, 0.12)
const COL_BLOOD = Color(0.5, 0.15, 0.1)  # Blood red accent

## UI elements
var contents_list: VBoxContainer
var gold_label: Label
var title_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_refresh_contents()


func close() -> void:
	visible = false
	ui_closed.emit()


func _build_ui() -> void:
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.8)
	add_child(overlay)

	# Main panel - centered, smaller than full screen
	var main_panel := PanelContainer.new()
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	if corpse:
		title_label.text = corpse.corpse_name.to_upper()
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
	# Update title
	if corpse:
		title_label.text = corpse.corpse_name.to_upper()

	# Update gold display
	if corpse:
		gold_label.text = str(corpse.gold)
	else:
		gold_label.text = "0"

	# Clear existing items
	for child in contents_list.get_children():
		child.queue_free()

	if not corpse or corpse.contents.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Nothing else of value..."
		empty_label.add_theme_color_override("font_color", COL_DIM)
		empty_label.add_theme_font_size_override("font_size", 12)
		contents_list.add_child(empty_label)
		return

	# Add each item as a clickable row
	for i in range(corpse.contents.size()):
		var slot: Dictionary = corpse.contents[i]
		var row := _create_item_row(i, slot)
		contents_list.add_child(row)


func _create_item_row(index: int, slot: Dictionary) -> Control:
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

	row_btn.pressed.connect(_on_item_clicked.bind(index))

	return row_btn


func _on_item_clicked(index: int) -> void:
	## Take single item from corpse
	if not corpse:
		return

	if index < 0 or index >= corpse.contents.size():
		return

	var slot: Dictionary = corpse.contents[index]
	var item_id: String = slot.item_id
	var quality: Enums.ItemQuality = slot.quality

	# Add to player inventory
	if InventoryManager.add_item(item_id, 1, quality):
		# Remove from corpse
		corpse.remove_item(item_id, 1, quality)

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
	## Take all gold from corpse
	if not corpse:
		return

	if corpse.gold <= 0:
		AudioManager.play_ui_cancel()
		return

	var gold_taken: int = corpse.take_gold()
	InventoryManager.add_gold(gold_taken)
	AudioManager.play_item_pickup()
	_show_notification("Took %d gold" % gold_taken)
	_refresh_contents()


func _on_take_all() -> void:
	## Take everything from corpse
	if not corpse:
		return

	var items_taken := 0

	# Take gold first
	if corpse.gold > 0:
		var gold_taken: int = corpse.take_gold()
		InventoryManager.add_gold(gold_taken)
		items_taken += 1

	# Take all items
	var contents_copy: Array = corpse.contents.duplicate(true)

	for slot in contents_copy:
		var item_id: String = slot.item_id
		var quantity: int = slot.quantity
		var quality: Enums.ItemQuality = slot.quality

		for i in range(quantity):
			if InventoryManager.add_item(item_id, 1, quality):
				corpse.remove_item(item_id, 1, quality)
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
