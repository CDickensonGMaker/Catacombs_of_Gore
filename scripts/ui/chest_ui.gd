## chest_ui.gd - UI for interacting with containers (chests, crates, etc.)
## Left side: Player inventory, Right side: Chest contents
## Click items to transfer between the two
extends Control

signal ui_closed

## Reference to the chest we're interacting with
var chest: Node = null

## UI colors (matching game_menu style)
const COL_BG = Color(0.08, 0.08, 0.1)
const COL_PANEL = Color(0.12, 0.12, 0.15)
const COL_BORDER = Color(0.3, 0.25, 0.2)
const COL_TEXT = Color(0.9, 0.85, 0.75)
const COL_DIM = Color(0.5, 0.5, 0.5)
const COL_GOLD = Color(0.8, 0.6, 0.2)
const COL_HOVER = Color(0.2, 0.18, 0.15)

## UI elements
var player_list: VBoxContainer
var chest_list: VBoxContainer
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
	_refresh_lists()


func close() -> void:
	visible = false
	ui_closed.emit()


func _build_ui() -> void:
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.75)
	add_child(overlay)

	# Main panel - full screen with margins (matching shop UI)
	var main_panel := PanelContainer.new()
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel.offset_left = 20
	main_panel.offset_right = -20
	main_panel.offset_top = 20
	main_panel.offset_bottom = -20

	var main_style := StyleBoxFlat.new()
	main_style.bg_color = COL_BG
	main_style.border_color = COL_BORDER
	main_style.set_border_width_all(2)
	main_panel.add_theme_stylebox_override("panel", main_style)
	add_child(main_panel)

	# Main vertical layout
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 10
	main_vbox.offset_top = 10
	main_vbox.offset_right = -10
	main_vbox.offset_bottom = -10
	main_vbox.add_theme_constant_override("separation", 10)
	main_panel.add_child(main_vbox)

	# Title
	title_label = Label.new()
	title_label.text = chest.chest_name.to_upper() if chest else "CONTAINER"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", COL_GOLD)
	title_label.add_theme_font_size_override("font_size", 18)
	main_vbox.add_child(title_label)

	# Columns container
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	main_vbox.add_child(columns)

	# Left column - Player inventory
	var player_column := _create_column("YOUR INVENTORY", true)
	columns.add_child(player_column["column"])
	player_list = player_column["list"]

	# Right column - Chest contents
	var chest_column := _create_column("CONTENTS", false)
	columns.add_child(chest_column["column"])
	chest_list = chest_column["list"]

	# Bottom buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	main_vbox.add_child(btn_row)

	var take_all_btn := Button.new()
	take_all_btn.text = "TAKE ALL"
	take_all_btn.custom_minimum_size = Vector2(100, 30)
	take_all_btn.pressed.connect(_on_take_all)
	take_all_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(take_all_btn)
	btn_row.add_child(take_all_btn)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(100, 30)
	close_btn.pressed.connect(close)
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(close_btn)
	btn_row.add_child(close_btn)


func _create_column(title_text: String, is_player: bool) -> Dictionary:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size = Vector2(300, 350)

	# Column title
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 14)
	column.add_child(title)

	# Scrollable list panel
	var scroll_panel := PanelContainer.new()
	scroll_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_panel.custom_minimum_size = Vector2(280, 300)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COL_PANEL
	panel_style.border_color = COL_BORDER
	panel_style.set_border_width_all(1)
	scroll_panel.add_theme_stylebox_override("panel", panel_style)
	column.add_child(scroll_panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(270, 290)
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	scroll_panel.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)

	return {"column": column, "scroll": scroll, "list": list}


func _refresh_lists() -> void:
	_refresh_player_list()
	_refresh_chest_list()


func _refresh_player_list() -> void:
	# Clear existing items
	for child in player_list.get_children():
		child.queue_free()

	if InventoryManager.inventory.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Empty"
		empty_label.add_theme_color_override("font_color", COL_DIM)
		player_list.add_child(empty_label)
		return

	for i in range(InventoryManager.inventory.size()):
		var slot: Dictionary = InventoryManager.inventory[i]
		var row := _create_item_row(i, slot, true)
		player_list.add_child(row)


func _refresh_chest_list() -> void:
	# Clear existing items
	for child in chest_list.get_children():
		child.queue_free()

	if not chest or chest.contents.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Empty"
		empty_label.add_theme_color_override("font_color", COL_DIM)
		chest_list.add_child(empty_label)
		return

	for i in range(chest.contents.size()):
		var slot: Dictionary = chest.contents[i]
		var row := _create_item_row(i, slot, false)
		chest_list.add_child(row)


func _create_item_row(index: int, slot: Dictionary, is_player: bool) -> Control:
	var item_id: String = slot.item_id
	var quantity: int = slot.quantity
	var quality: Enums.ItemQuality = slot.quality

	# Get item name
	var item_name := InventoryManager.get_item_name(item_id)

	# Quality prefix
	var quality_prefix := ""
	var quality_color := COL_TEXT
	match quality:
		Enums.ItemQuality.POOR:
			quality_prefix = "[Poor] "
			quality_color = Color(0.5, 0.5, 0.5)
		Enums.ItemQuality.BELOW_AVERAGE:
			quality_prefix = "[Worn] "
			quality_color = Color(0.7, 0.7, 0.7)
		Enums.ItemQuality.ABOVE_AVERAGE:
			quality_prefix = "[Fine] "
			quality_color = Color(0.3, 0.8, 1.0)
		Enums.ItemQuality.PERFECT:
			quality_prefix = "[Perfect] "
			quality_color = Color(1.0, 0.8, 0.2)

	var display_text := quality_prefix + item_name
	if quantity > 1:
		display_text += " x%d" % quantity

	# Clickable row button
	var row_btn := Button.new()
	row_btn.flat = true
	row_btn.custom_minimum_size.y = 22
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

	if is_player:
		row_btn.pressed.connect(_on_player_item_clicked.bind(index))
	else:
		row_btn.pressed.connect(_on_chest_item_clicked.bind(index))

	return row_btn


func _on_player_item_clicked(index: int) -> void:
	## Transfer item from player inventory to chest
	if index < 0 or index >= InventoryManager.inventory.size():
		return

	if not chest:
		return

	var slot: Dictionary = InventoryManager.inventory[index]
	var item_id: String = slot.item_id
	var quality: Enums.ItemQuality = slot.quality

	# Add to chest
	chest.add_item(item_id, 1, quality)

	# Remove from player (1 at a time)
	InventoryManager.remove_item(item_id, 1, quality)

	# Play sound
	AudioManager.play_ui_confirm()

	# Refresh
	_refresh_lists()


func _on_chest_item_clicked(index: int) -> void:
	## Transfer item from chest to player inventory
	if not chest:
		return

	if index < 0 or index >= chest.contents.size():
		return

	var slot: Dictionary = chest.contents[index]
	var item_id: String = slot.item_id
	var quality: Enums.ItemQuality = slot.quality

	# Check if player inventory has space
	if not InventoryManager._can_add_item(item_id, 1, quality):
		_show_notification("Inventory full!")
		AudioManager.play_ui_cancel()
		return

	# Add to player
	InventoryManager.add_item(item_id, 1, quality)

	# Remove from chest
	chest.remove_item(item_id, 1, quality)

	# Play sound
	AudioManager.play_item_pickup()

	# Refresh
	_refresh_lists()


func _on_take_all() -> void:
	## Take all items from chest
	if not chest:
		return

	var items_taken := 0

	# Copy contents array since we'll be modifying it
	var contents_copy: Array = chest.contents.duplicate(true)

	for slot in contents_copy:
		var item_id: String = slot.item_id
		var quantity: int = slot.quantity
		var quality: Enums.ItemQuality = slot.quality

		# Try to add each item
		for i in range(quantity):
			if InventoryManager._can_add_item(item_id, 1, quality):
				InventoryManager.add_item(item_id, 1, quality)
				chest.remove_item(item_id, 1, quality)
				items_taken += 1
			else:
				break  # Inventory full

	if items_taken > 0:
		AudioManager.play_item_pickup()
		_show_notification("Took %d items" % items_taken)
	else:
		AudioManager.play_ui_cancel()
		_show_notification("Inventory full!")

	_refresh_lists()


func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COL_PANEL
	normal.border_color = COL_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)

	var hover := StyleBoxFlat.new()
	hover.bg_color = COL_HOVER
	hover.border_color = COL_GOLD
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(3)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", COL_GOLD)


func _show_notification(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)
