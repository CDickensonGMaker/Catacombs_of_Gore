## shop_ui.gd - Barter-style shop UI for buying and selling items
## Uses cart-based selection system with transaction summary
class_name ShopUI
extends Control

signal ui_closed

# Dark gothic colors (matching game_menu.gd and repair_station_ui.gd)
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

# Reference to merchant
var merchant: Node = null

# UI element references
var title_label: Label
var gold_label: Label
var weight_label: Label
var speech_label: Label
var shop_list: VBoxContainer
var player_list: VBoxContainer
var shop_scroll: ScrollContainer
var player_scroll: ScrollContainer
var sell_summary_list: VBoxContainer
var buy_summary_list: VBoxContainer
var sell_total_label: Label
var buy_total_label: Label
var balance_label: Label
var confirm_btn: Button
var clear_btn: Button

# Cart data
# sell_cart: {inventory_index, quantity, item_id, quality, unit_value}
var sell_cart: Array[Dictionary] = []
# buy_cart: {shop_index, quantity, item_id, quality, unit_price}
var buy_cart: Array[Dictionary] = []

# Track checkboxes for updating
var player_checkboxes: Dictionary = {}  # inventory_index -> CheckBox
var shop_checkboxes: Dictionary = {}    # shop_index -> CheckBox
var player_spinners: Dictionary = {}    # inventory_index -> SpinBox
var shop_spinners: Dictionary = {}      # shop_index -> SpinBox

# Hover tooltip for item comparison
var hover_tooltip: PanelContainer = null
var hovered_player_idx: int = -1
var hovered_shop_idx: int = -1

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
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

	# Main panel
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
	vbox.add_theme_constant_override("separation", 8)
	main.add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "MERCHANT"
	title_label.add_theme_color_override("font_color", COL_GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	vbox.add_child(_make_separator())

	# Info row: Gold, Weight, Speech Bonus
	var info_row = HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 40)
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(info_row)

	# Gold display
	var gold_box = HBoxContainer.new()
	gold_box.add_theme_constant_override("separation", 5)
	info_row.add_child(gold_box)

	var gold_title = Label.new()
	gold_title.text = "Gold: "
	gold_title.add_theme_color_override("font_color", COL_TEXT)
	gold_box.add_child(gold_title)

	gold_label = Label.new()
	gold_label.text = "0"
	gold_label.add_theme_color_override("font_color", COL_GOLD)
	gold_box.add_child(gold_label)

	# Weight display
	var weight_box = HBoxContainer.new()
	weight_box.add_theme_constant_override("separation", 5)
	info_row.add_child(weight_box)

	var weight_title = Label.new()
	weight_title.text = "Weight: "
	weight_title.add_theme_color_override("font_color", COL_TEXT)
	weight_box.add_child(weight_title)

	weight_label = Label.new()
	weight_label.text = "0 / 0"
	weight_label.add_theme_color_override("font_color", COL_TEXT)
	weight_box.add_child(weight_label)

	# Speech bonus display
	var speech_box = HBoxContainer.new()
	speech_box.add_theme_constant_override("separation", 5)
	info_row.add_child(speech_box)

	var speech_title = Label.new()
	speech_title.text = "Speech Bonus: "
	speech_title.add_theme_color_override("font_color", COL_TEXT)
	speech_box.add_child(speech_title)

	speech_label = Label.new()
	speech_label.text = "+0%"
	speech_label.add_theme_color_override("font_color", COL_GREEN)
	speech_box.add_child(speech_label)

	vbox.add_child(_make_separator())

	# Two-column layout for player items and shop items
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.custom_minimum_size.y = 120
	vbox.add_child(columns)

	# Player column (left) - items player can sell
	var player_col_data: Dictionary = _create_column("YOUR ITEMS", true)
	columns.add_child(player_col_data.column)
	player_scroll = player_col_data.scroll
	player_list = player_col_data.list

	# Shop column (right) - items for sale
	var shop_col_data: Dictionary = _create_column("FOR SALE", false)
	columns.add_child(shop_col_data.column)
	shop_scroll = shop_col_data.scroll
	shop_list = shop_col_data.list

	vbox.add_child(_make_separator())

	# Transaction Summary section
	var summary_label = Label.new()
	summary_label.text = "TRANSACTION SUMMARY"
	summary_label.add_theme_color_override("font_color", COL_GOLD)
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(summary_label)

	# Summary columns
	var summary_columns = HBoxContainer.new()
	summary_columns.add_theme_constant_override("separation", 15)
	summary_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(summary_columns)

	# Sell summary (left)
	var sell_panel_data: Dictionary = _create_summary_panel("SELLING", true)
	summary_columns.add_child(sell_panel_data.panel)
	sell_summary_list = sell_panel_data.list
	sell_total_label = sell_panel_data.total

	# Buy summary (right)
	var buy_panel_data: Dictionary = _create_summary_panel("BUYING", false)
	summary_columns.add_child(buy_panel_data.panel)
	buy_summary_list = buy_panel_data.list
	buy_total_label = buy_panel_data.total

	vbox.add_child(_make_separator())

	# Balance and buttons row
	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 20)
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(bottom_row)

	# Balance display
	var balance_box = HBoxContainer.new()
	balance_box.add_theme_constant_override("separation", 5)
	bottom_row.add_child(balance_box)

	var balance_title = Label.new()
	balance_title.text = "Balance: "
	balance_title.add_theme_color_override("font_color", COL_TEXT)
	balance_box.add_child(balance_title)

	balance_label = Label.new()
	balance_label.text = "0 gold"
	balance_label.add_theme_color_override("font_color", COL_GOLD)
	balance_box.add_child(balance_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 50
	bottom_row.add_child(spacer)

	# Confirm button
	confirm_btn = Button.new()
	confirm_btn.text = "CONFIRM"
	confirm_btn.pressed.connect(_on_confirm_pressed)
	_style_button(confirm_btn)
	bottom_row.add_child(confirm_btn)

	# Clear cart button
	clear_btn = Button.new()
	clear_btn.text = "CLEAR"
	clear_btn.pressed.connect(_on_clear_pressed)
	_style_button(clear_btn)
	bottom_row.add_child(clear_btn)

	# Cancel button
	var close_btn = Button.new()
	close_btn.text = "CANCEL"
	close_btn.pressed.connect(close)
	_style_button(close_btn)
	bottom_row.add_child(close_btn)

	# Create hover tooltip last so it's on top of everything
	_create_hover_tooltip()

## Returns {column: VBoxContainer, scroll: ScrollContainer, list: VBoxContainer}
func _create_column(title_text: String, is_player: bool) -> Dictionary:
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)

	# Column header
	var header = Label.new()
	header.text = title_text
	header.add_theme_color_override("font_color", COL_GOLD)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(header)

	# Column header row (Checkbox, Name, Price, Qty)
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 5)
	column.add_child(header_row)

	# Checkbox spacer
	var h_check = Control.new()
	h_check.custom_minimum_size.x = 24
	header_row.add_child(h_check)

	var h_name = Label.new()
	h_name.text = "Item"
	h_name.custom_minimum_size.x = 140
	h_name.add_theme_color_override("font_color", COL_DIM)
	header_row.add_child(h_name)

	var h_price = Label.new()
	h_price.text = "Price" if not is_player else "Value"
	h_price.custom_minimum_size.x = 50
	h_price.add_theme_color_override("font_color", COL_DIM)
	header_row.add_child(h_price)

	var h_qty = Label.new()
	h_qty.text = "Qty"
	h_qty.custom_minimum_size.x = 50
	h_qty.add_theme_color_override("font_color", COL_DIM)
	header_row.add_child(h_qty)

	# Scrollable list with panel background
	var scroll_panel = PanelContainer.new()
	scroll_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_panel.custom_minimum_size = Vector2(200, 100)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = COL_PANEL
	panel_style.border_color = COL_BORDER
	panel_style.set_border_width_all(1)
	scroll_panel.add_theme_stylebox_override("panel", panel_style)
	column.add_child(scroll_panel)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(190, 80)
	scroll_panel.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)

	return {"column": column, "scroll": scroll, "list": list}

## Returns {panel: PanelContainer, list: VBoxContainer, total: Label}
func _create_summary_panel(title_text: String, is_sell: bool) -> Dictionary:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = COL_PANEL
	panel_style.border_color = COL_BORDER
	panel_style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", panel_style)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	panel.add_child(content)

	# Header with title
	var header = Label.new()
	header.text = title_text
	header.add_theme_color_override("font_color", COL_GREEN if is_sell else COL_RED)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(header)

	# Scrollable list for items
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 1)
	scroll.add_child(list)

	# Total row
	var total = Label.new()
	total.text = "+0" if is_sell else "-0"
	total.add_theme_color_override("font_color", COL_GREEN if is_sell else COL_RED)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(total)

	return {"panel": panel, "list": list, "total": total}

func _refresh_display() -> void:
	# Update title with merchant name
	if merchant:
		title_label.text = merchant.merchant_name.to_upper()

	# Update gold
	gold_label.text = str(InventoryManager.gold)

	# Update weight
	var current_weight := InventoryManager.get_total_weight()
	var max_weight := InventoryManager.get_max_carry_weight()
	weight_label.text = "%.1f / %.1f" % [current_weight, max_weight]

	# Color weight based on encumbrance
	if InventoryManager.is_overencumbered():
		weight_label.add_theme_color_override("font_color", COL_RED)
	elif current_weight > max_weight * 0.8:
		weight_label.add_theme_color_override("font_color", COL_YELLOW)
	else:
		weight_label.add_theme_color_override("font_color", COL_TEXT)

	# Update speech bonus display
	if merchant:
		var sell_mod: float = merchant.get_speech_sell_modifier()
		var sell_bonus: int = int((sell_mod - 1.0) * 100)
		speech_label.text = "+%d%%" % sell_bonus
		if sell_bonus > 0:
			speech_label.add_theme_color_override("font_color", COL_GREEN)
		else:
			speech_label.add_theme_color_override("font_color", COL_DIM)

	# Clear tracking dictionaries
	player_checkboxes.clear()
	shop_checkboxes.clear()
	player_spinners.clear()
	shop_spinners.clear()

	# Refresh item lists
	_refresh_player_list()
	_refresh_shop_list()

	# Update transaction summary
	_update_transaction_summary()

func _refresh_player_list() -> void:
	# Clear existing items
	for child in player_list.get_children():
		child.queue_free()

	if not merchant:
		print("[ShopUI] _refresh_player_list: No merchant!")
		return

	# Get merchant buy categories
	var buy_categories := _get_merchant_buy_categories()
	print("[ShopUI] Player inventory size: %d, buy_categories: %s, shop_type: %s" % [InventoryManager.inventory.size(), str(buy_categories), merchant.shop_type])

	# Add player inventory items (filtered by what merchant buys)
	var added_count: int = 0
	for i in range(InventoryManager.inventory.size()):
		var inv_item: Dictionary = InventoryManager.inventory[i]
		var item_type := LootTables._get_item_type(inv_item.item_id)

		# Check if merchant will buy this item
		if not _merchant_will_buy(inv_item.item_id, buy_categories):
			print("[ShopUI]   Item %d: %s (type=%s) - FILTERED" % [i, inv_item.item_id, item_type])
			continue

		print("[ShopUI]   Item %d: %s (type=%s) - ADDING" % [i, inv_item.item_id, item_type])
		var row := _create_player_row(i, inv_item)
		player_list.add_child(row)
		added_count += 1

	print("[ShopUI] Added %d player items to list" % added_count)

func _refresh_shop_list() -> void:
	# Clear existing items
	for child in shop_list.get_children():
		child.queue_free()

	if not merchant:
		return

	# Add shop items
	for i in range(merchant.shop_inventory.size()):
		var shop_item: Dictionary = merchant.shop_inventory[i]

		# Skip out of stock items
		if shop_item.quantity == 0:
			continue

		var row := _create_shop_row(i, shop_item)
		shop_list.add_child(row)

func _create_player_row(index: int, inv_item: Dictionary) -> Control:
	# Use a Button as the row container for full row clicking
	var row_btn = Button.new()
	row_btn.flat = true
	row_btn.custom_minimum_size.y = 22
	row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_btn.pressed.connect(_on_player_row_clicked.bind(index))
	row_btn.mouse_entered.connect(_on_player_row_hover_enter.bind(index, inv_item))
	row_btn.mouse_exited.connect(_on_row_hover_exit)

	# Style for hover effect
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.2, 0.18, 0.15)
	row_btn.add_theme_stylebox_override("hover", hover_style)
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.25, 0.22, 0.18)
	row_btn.add_theme_stylebox_override("pressed", pressed_style)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_btn.add_child(row)

	# Checkbox (visual indicator only - clicking row toggles it)
	var checkbox = CheckBox.new()
	checkbox.custom_minimum_size = Vector2(18, 18)
	checkbox.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let row handle clicks
	row.add_child(checkbox)
	player_checkboxes[index] = checkbox

	# Check if already in cart
	for cart_item in sell_cart:
		if cart_item.inventory_index == index:
			checkbox.button_pressed = true
			break

	# Item name with quality prefix
	var name_label = Label.new()
	var item_name := InventoryManager.get_item_name(inv_item.item_id)
	var quality_prefix := _get_quality_prefix(inv_item.quality)
	name_label.text = quality_prefix + item_name
	name_label.custom_minimum_size.x = 110
	name_label.clip_text = true
	name_label.add_theme_color_override("font_color", COL_TEXT)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	# Sell price (with Speech modifier)
	var sell_price: int = merchant.get_sell_price_with_speech(index)
	var price_label = Label.new()
	price_label.text = str(sell_price)
	price_label.custom_minimum_size.x = 35
	price_label.add_theme_color_override("font_color", COL_GOLD)
	price_label.add_theme_font_size_override("font_size", 12)
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price_label)

	# Quantity - show spinner if qty > 1
	if inv_item.quantity > 1:
		var spinner = SpinBox.new()
		spinner.min_value = 1
		spinner.max_value = inv_item.quantity
		spinner.value = 1
		spinner.allow_greater = false  # Prevent typing values above max
		spinner.allow_lesser = false   # Prevent typing values below min
		spinner.custom_minimum_size.x = 50
		spinner.value_changed.connect(_on_player_qty_changed.bind(index))
		row.add_child(spinner)
		player_spinners[index] = spinner

		# If in cart, set spinner to cart quantity (clamped to actual inventory)
		for cart_item in sell_cart:
			if cart_item.inventory_index == index:
				spinner.value = mini(cart_item.quantity, inv_item.quantity)
				cart_item.quantity = int(spinner.value)  # Update cart if clamped
				break
	else:
		var qty_label = Label.new()
		qty_label.text = "1"
		qty_label.custom_minimum_size.x = 40
		qty_label.add_theme_color_override("font_color", COL_DIM)
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(qty_label)

	return row_btn

func _on_player_row_clicked(index: int) -> void:
	# Toggle the checkbox
	if player_checkboxes.has(index):
		var checkbox: CheckBox = player_checkboxes[index]
		checkbox.button_pressed = not checkbox.button_pressed
		_on_player_item_toggled(checkbox.button_pressed, index)

func _create_shop_row(index: int, shop_item: Dictionary) -> Control:
	# Use a Button as the row container for full row clicking
	var row_btn = Button.new()
	row_btn.flat = true
	row_btn.custom_minimum_size.y = 22
	row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_btn.pressed.connect(_on_shop_row_clicked.bind(index))
	row_btn.mouse_entered.connect(_on_shop_row_hover_enter.bind(index, shop_item))
	row_btn.mouse_exited.connect(_on_row_hover_exit)

	# Style for hover effect
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.2, 0.18, 0.15)
	row_btn.add_theme_stylebox_override("hover", hover_style)
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.25, 0.22, 0.18)
	row_btn.add_theme_stylebox_override("pressed", pressed_style)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_btn.add_child(row)

	# Checkbox (visual indicator only - clicking row toggles it)
	var checkbox = CheckBox.new()
	checkbox.custom_minimum_size = Vector2(18, 18)
	checkbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(checkbox)
	shop_checkboxes[index] = checkbox

	# Check if already in cart
	for cart_item in buy_cart:
		if cart_item.shop_index == index:
			checkbox.button_pressed = true
			break

	# Item name with quality prefix
	var name_label = Label.new()
	var item_name := InventoryManager.get_item_name(shop_item.item_id)
	var quality_prefix := _get_quality_prefix(shop_item.quality)
	name_label.text = quality_prefix + item_name
	name_label.custom_minimum_size.x = 110
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Color based on affordability (considering current cart)
	var buy_price: int = merchant.get_buy_price_with_speech(index)
	if _get_balance() >= buy_price:
		name_label.add_theme_color_override("font_color", COL_TEXT)
	else:
		name_label.add_theme_color_override("font_color", COL_RED)

	row.add_child(name_label)

	# Buy price (with Speech modifier)
	var price_label = Label.new()
	price_label.text = str(buy_price)
	price_label.custom_minimum_size.x = 35
	price_label.add_theme_color_override("font_color", COL_GOLD)
	price_label.add_theme_font_size_override("font_size", 12)
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price_label)

	# Quantity - show spinner if qty > 1 or infinite
	var max_qty: int = shop_item.quantity if shop_item.quantity > 0 else 99
	if max_qty > 1:
		var spinner = SpinBox.new()
		spinner.min_value = 1
		spinner.max_value = max_qty
		spinner.value = 1
		spinner.allow_greater = false  # Prevent typing values above max
		spinner.allow_lesser = false   # Prevent typing values below min
		spinner.custom_minimum_size.x = 50
		spinner.value_changed.connect(_on_shop_qty_changed.bind(index))
		row.add_child(spinner)
		shop_spinners[index] = spinner

		# If in cart, set spinner to cart quantity (clamped to actual stock)
		for cart_item in buy_cart:
			if cart_item.shop_index == index:
				spinner.value = mini(cart_item.quantity, max_qty)
				cart_item.quantity = int(spinner.value)  # Update cart if clamped
				break
	else:
		var qty_label = Label.new()
		if shop_item.quantity < 0:
			qty_label.text = "inf"
		else:
			qty_label.text = str(shop_item.quantity)
		qty_label.custom_minimum_size.x = 40
		qty_label.add_theme_color_override("font_color", COL_DIM)
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(qty_label)

	return row_btn

func _on_shop_row_clicked(index: int) -> void:
	# Toggle the checkbox
	if shop_checkboxes.has(index):
		var checkbox: CheckBox = shop_checkboxes[index]
		checkbox.button_pressed = not checkbox.button_pressed
		_on_shop_item_toggled(checkbox.button_pressed, index)

func _on_player_item_toggled(toggled: bool, inventory_index: int) -> void:
	if toggled:
		_add_to_sell_cart(inventory_index)
	else:
		_remove_from_sell_cart(inventory_index)
	_update_transaction_summary()

func _on_shop_item_toggled(toggled: bool, shop_index: int) -> void:
	if toggled:
		_add_to_buy_cart(shop_index)
	else:
		_remove_from_buy_cart(shop_index)
	_update_transaction_summary()

func _on_player_qty_changed(value: float, inventory_index: int) -> void:
	# Validate against actual inventory quantity
	if inventory_index >= InventoryManager.inventory.size():
		return

	var inv_item: Dictionary = InventoryManager.inventory[inventory_index]
	var clamped_qty: int = mini(int(value), inv_item.quantity)

	# Update spinner if value was clamped
	if clamped_qty != int(value) and player_spinners.has(inventory_index):
		player_spinners[inventory_index].value = clamped_qty

	# Update quantity in sell cart
	for cart_item in sell_cart:
		if cart_item.inventory_index == inventory_index:
			cart_item.quantity = clamped_qty
			_update_transaction_summary()
			return

func _on_shop_qty_changed(value: float, shop_index: int) -> void:
	# Update quantity in buy cart
	for cart_item in buy_cart:
		if cart_item.shop_index == shop_index:
			cart_item.quantity = int(value)
			_update_transaction_summary()
			return

func _add_to_sell_cart(inventory_index: int) -> void:
	# Check if already in cart
	for cart_item in sell_cart:
		if cart_item.inventory_index == inventory_index:
			return

	var inv_item: Dictionary = InventoryManager.inventory[inventory_index]
	var unit_value: int = merchant.get_sell_price_with_speech(inventory_index)
	var qty: int = 1
	if player_spinners.has(inventory_index):
		qty = int(player_spinners[inventory_index].value)

	sell_cart.append({
		"inventory_index": inventory_index,
		"quantity": qty,
		"item_id": inv_item.item_id,
		"quality": inv_item.quality,
		"unit_value": unit_value
	})

func _remove_from_sell_cart(inventory_index: int) -> void:
	for i in range(sell_cart.size() - 1, -1, -1):
		if sell_cart[i].inventory_index == inventory_index:
			sell_cart.remove_at(i)
			return

func _add_to_buy_cart(shop_index: int) -> void:
	# Check if already in cart
	for cart_item in buy_cart:
		if cart_item.shop_index == shop_index:
			return

	var shop_item: Dictionary = merchant.shop_inventory[shop_index]
	var unit_price: int = merchant.get_buy_price_with_speech(shop_index)
	var qty: int = 1
	if shop_spinners.has(shop_index):
		qty = int(shop_spinners[shop_index].value)

	buy_cart.append({
		"shop_index": shop_index,
		"quantity": qty,
		"item_id": shop_item.item_id,
		"quality": shop_item.quality,
		"unit_price": unit_price
	})

func _remove_from_buy_cart(shop_index: int) -> void:
	for i in range(buy_cart.size() - 1, -1, -1):
		if buy_cart[i].shop_index == shop_index:
			buy_cart.remove_at(i)
			return

func _get_sell_total() -> int:
	var total := 0
	for item in sell_cart:
		total += item.unit_value * item.quantity
	return total

func _get_buy_total() -> int:
	var total := 0
	for item in buy_cart:
		total += item.unit_price * item.quantity
	return total

func _get_balance() -> int:
	return InventoryManager.gold + _get_sell_total() - _get_buy_total()

func _can_complete_transaction() -> bool:
	return _get_balance() >= 0 and (sell_cart.size() > 0 or buy_cart.size() > 0)

func _update_transaction_summary() -> void:
	# Clear sell summary
	for child in sell_summary_list.get_children():
		child.queue_free()

	# Clear buy summary
	for child in buy_summary_list.get_children():
		child.queue_free()

	# Populate sell summary
	for item in sell_cart:
		var row = Label.new()
		var item_name: String = InventoryManager.get_item_name(item.item_id)
		var total: int = item.unit_value * item.quantity
		if item.quantity > 1:
			row.text = "%s x%d  +%d" % [item_name, item.quantity, total]
		else:
			row.text = "%s  +%d" % [item_name, total]
		row.add_theme_color_override("font_color", COL_GREEN)
		sell_summary_list.add_child(row)

	# Populate buy summary
	for item in buy_cart:
		var row = Label.new()
		var item_name: String = InventoryManager.get_item_name(item.item_id)
		var total: int = item.unit_price * item.quantity
		if item.quantity > 1:
			row.text = "%s x%d  -%d" % [item_name, item.quantity, total]
		else:
			row.text = "%s  -%d" % [item_name, total]
		row.add_theme_color_override("font_color", COL_RED)
		buy_summary_list.add_child(row)

	# Update totals
	var sell_total := _get_sell_total()
	var buy_total := _get_buy_total()

	sell_total_label.text = "+%d" % sell_total
	buy_total_label.text = "-%d" % buy_total

	# Update balance
	var balance := _get_balance()
	var current_gold := InventoryManager.gold
	if sell_total > 0 or buy_total > 0:
		balance_label.text = "%d gold (%d + %d - %d)" % [balance, current_gold, sell_total, buy_total]
	else:
		balance_label.text = "%d gold" % balance

	# Color balance based on validity
	if balance < 0:
		balance_label.add_theme_color_override("font_color", COL_RED)
	else:
		balance_label.add_theme_color_override("font_color", COL_GREEN)

	# Update confirm button state
	confirm_btn.disabled = not _can_complete_transaction()

func _on_confirm_pressed() -> void:
	if not _can_complete_transaction():
		return

	# Execute sells first (to get gold)
	# Sort sell_cart by inventory_index descending so we remove from end first
	# This prevents index shifting from affecting earlier removals
	var sorted_sells := sell_cart.duplicate()
	sorted_sells.sort_custom(func(a, b): return a.inventory_index > b.inventory_index)

	for item in sorted_sells:
		var idx: int = item.inventory_index

		# CRITICAL: Validate the item still exists at this index with matching data
		if idx >= InventoryManager.inventory.size():
			push_warning("[ShopUI] Sell validation failed: index %d out of bounds (size=%d)" % [idx, InventoryManager.inventory.size()])
			continue

		var inv_item: Dictionary = InventoryManager.inventory[idx]
		if inv_item.item_id != item.item_id or inv_item.quality != item.quality:
			push_warning("[ShopUI] Sell validation failed: item mismatch at index %d. Expected %s/%s, got %s/%s" % [
				idx, item.item_id, item.quality, inv_item.item_id, inv_item.quality
			])
			continue

		if inv_item.quantity < item.quantity:
			push_warning("[ShopUI] Sell validation failed: insufficient quantity at index %d. Need %d, have %d" % [
				idx, item.quantity, inv_item.quantity
			])
			# Show notification to user
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Not enough %s to sell!" % InventoryManager.get_item_name(item.item_id))
			continue

		# Calculate sell price per unit
		var sell_price: int = item.unit_value

		# Remove from player inventory using safe index-based removal
		if not InventoryManager.remove_item_at_index(idx, item.quantity):
			push_warning("[ShopUI] Failed to remove item at index %d" % idx)
			continue

		# Give player gold
		InventoryManager.add_gold(sell_price * item.quantity)

		# Add to shop stock
		if merchant.has_method("_add_to_shop_stock"):
			for _n in range(item.quantity):
				merchant._add_to_shop_stock(item.item_id, item.quality)

	# Execute buys
	for item in buy_cart:
		var shop_item: Dictionary = merchant.shop_inventory[item.shop_index]
		var buy_price: int = item.unit_price

		# Check stock
		if shop_item.quantity >= 0 and shop_item.quantity < item.quantity:
			continue  # Not enough stock

		# Deduct gold
		InventoryManager.remove_gold(buy_price * item.quantity)

		# Add to player inventory
		InventoryManager.add_item(item.item_id, item.quantity, item.quality)

		# Reduce shop stock
		if shop_item.quantity > 0:
			shop_item.quantity -= item.quantity

	# Clear carts and refresh
	_clear_carts()
	_refresh_display()

	# Sound effect hook
	# AudioManager.play_menu_select()

func _on_clear_pressed() -> void:
	_clear_carts()
	_refresh_display()

func _clear_carts() -> void:
	sell_cart.clear()
	buy_cart.clear()

func _get_merchant_buy_categories() -> Array[String]:
	if not merchant:
		return ["all"]

	# Determine what categories this merchant buys based on shop_type
	match merchant.shop_type:
		"weapon":
			return ["weapon"]
		"armor":
			return ["armor"]
		"blacksmith":
			return ["weapon", "armor", "material"]
		"alchemist":
			return ["consumable", "scroll", "material"]
		"general":
			return ["all"]
		_:
			return ["all"]

func _merchant_will_buy(item_id: String, categories: Array[String]) -> bool:
	if "all" in categories:
		return true

	var item_type := LootTables._get_item_type(item_id)
	return item_type in categories

func _get_quality_prefix(quality: Enums.ItemQuality) -> String:
	match quality:
		Enums.ItemQuality.POOR:
			return "[Poor] "
		Enums.ItemQuality.BELOW_AVERAGE:
			return "[Worn] "
		Enums.ItemQuality.ABOVE_AVERAGE:
			return "[Fine] "
		Enums.ItemQuality.PERFECT:
			return "[Perfect] "
		_:
			return ""

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

func open() -> void:
	visible = true
	_clear_carts()
	_refresh_display()

func close() -> void:
	visible = false
	_hide_hover_tooltip()
	ui_closed.emit()

# ==================== HOVER TOOLTIP SYSTEM ====================

func _create_hover_tooltip() -> void:
	hover_tooltip = PanelContainer.new()
	hover_tooltip.name = "HoverTooltip"
	hover_tooltip.visible = false
	hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_tooltip.z_index = 100

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
	hovered_player_idx = -1
	hovered_shop_idx = -1

func _on_player_row_hover_enter(index: int, inv_item: Dictionary) -> void:
	hovered_player_idx = index
	hovered_shop_idx = -1
	_update_player_tooltip(inv_item)

func _on_shop_row_hover_enter(index: int, shop_item: Dictionary) -> void:
	hovered_shop_idx = index
	hovered_player_idx = -1
	_update_shop_tooltip(shop_item)

func _on_row_hover_exit() -> void:
	_hide_hover_tooltip()

func _update_player_tooltip(inv_item: Dictionary) -> void:
	var item_data = InventoryManager.get_item_data(inv_item.item_id)
	if not item_data:
		_hide_hover_tooltip()
		return

	_build_tooltip_for_item(item_data, inv_item.quality, inv_item.item_id, true)

func _update_shop_tooltip(shop_item: Dictionary) -> void:
	var item_data = InventoryManager.get_item_data(shop_item.item_id)
	if not item_data:
		_hide_hover_tooltip()
		return

	_build_tooltip_for_item(item_data, shop_item.quality, shop_item.item_id, false)

func _build_tooltip_for_item(item_data: Resource, quality: Enums.ItemQuality, item_id: String, is_selling: bool) -> void:
	var content: VBoxContainer = hover_tooltip.get_node("TooltipContent")
	for child in content.get_children():
		child.queue_free()

	# Item name header
	var item_name := InventoryManager.get_item_name(item_id)
	var quality_prefix := _get_quality_prefix(quality)
	content.add_child(_make_tooltip_label(quality_prefix + item_name, COL_GOLD))

	# Description if available
	if item_data.has_method("get") and item_data.get("description"):
		var desc_label := _make_tooltip_label(item_data.description, COL_DIM)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.custom_minimum_size.x = 200
		content.add_child(desc_label)

	content.add_child(_make_tooltip_separator())

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
				equip_slot = "ring_1"
			Enums.ArmorSlot.AMULET: equip_slot = "amulet"
			Enums.ArmorSlot.SHIELD: equip_slot = "off_hand"

	if is_weapon:
		_build_weapon_tooltip(content, item_data as WeaponData, quality, equip_slot)
	elif is_armor:
		_build_armor_tooltip(content, item_data as ArmorData, quality, equip_slot)
	else:
		# Consumable or other item
		_build_generic_tooltip(content, item_data, quality)

	# Position and show tooltip
	hover_tooltip.visible = true
	hover_tooltip.reset_size()
	await get_tree().process_frame
	_position_tooltip()

func _build_weapon_tooltip(content: VBoxContainer, weapon: WeaponData, quality: Enums.ItemQuality, equip_slot: String) -> void:
	var mod := Enums.get_quality_modifier(quality)
	var avg_dmg := (weapon.base_damage[0] * (weapon.base_damage[1] + 1.0) / 2.0) + weapon.base_damage[2] + mod
	var dps := avg_dmg * weapon.attack_speed

	# Check if something is equipped to compare against
	var equipped: Dictionary = InventoryManager.equipment.get(equip_slot, {})

	if equipped.is_empty():
		content.add_child(_make_tooltip_label("Damage: %.1f" % avg_dmg, COL_TEXT))
		content.add_child(_make_tooltip_label("Speed: %.2f" % weapon.attack_speed, COL_TEXT))
		content.add_child(_make_tooltip_label("Reach: %.1f" % weapon.reach, COL_TEXT))
		content.add_child(_make_tooltip_label("DPS: %.1f" % dps, COL_TEXT))
		content.add_child(_make_tooltip_label("Weight: %.1f" % weapon.weight, COL_TEXT))
	else:
		var eq_data = equipped.get("data")
		var eq_quality: Enums.ItemQuality = equipped.get("quality", Enums.ItemQuality.AVERAGE)
		if eq_data is WeaponData:
			var eq_weapon := eq_data as WeaponData
			var eq_mod := Enums.get_quality_modifier(eq_quality)
			var eq_avg_dmg := (eq_weapon.base_damage[0] * (eq_weapon.base_damage[1] + 1.0) / 2.0) + eq_weapon.base_damage[2] + eq_mod
			var eq_dps := eq_avg_dmg * eq_weapon.attack_speed

			var eq_name := InventoryManager.get_item_name(equipped.item_id)
			content.add_child(_make_tooltip_label("vs " + eq_name, COL_DIM))
			content.add_child(_make_tooltip_separator())

			content.add_child(_make_stat_row("Damage", avg_dmg, eq_avg_dmg, "%.1f"))
			content.add_child(_make_stat_row("Speed", weapon.attack_speed, eq_weapon.attack_speed, "%.2f"))
			content.add_child(_make_stat_row("Reach", weapon.reach, eq_weapon.reach, "%.1f"))
			content.add_child(_make_stat_row("DPS", dps, eq_dps, "%.1f"))
			content.add_child(_make_stat_row_inverted("Weight", weapon.weight, eq_weapon.weight, "%.1f"))
		else:
			content.add_child(_make_tooltip_label("Damage: %.1f" % avg_dmg, COL_TEXT))
			content.add_child(_make_tooltip_label("Speed: %.2f" % weapon.attack_speed, COL_TEXT))
			content.add_child(_make_tooltip_label("DPS: %.1f" % dps, COL_TEXT))

func _build_armor_tooltip(content: VBoxContainer, armor: ArmorData, quality: Enums.ItemQuality, equip_slot: String) -> void:
	var armor_val := armor.get_armor_value(quality)

	# Check if something is equipped to compare against
	var equipped: Dictionary = InventoryManager.equipment.get(equip_slot, {})

	if equipped.is_empty():
		content.add_child(_make_tooltip_label("Armor: %d" % armor_val, COL_TEXT))
		content.add_child(_make_tooltip_label("Weight: %.1f" % armor.weight, COL_TEXT))
		if armor.is_shield:
			var block_val := armor.get_block_value(quality)
			content.add_child(_make_tooltip_label("Block: %d" % block_val, COL_TEXT))
	else:
		var eq_data = equipped.get("data")
		var eq_quality: Enums.ItemQuality = equipped.get("quality", Enums.ItemQuality.AVERAGE)
		if eq_data is ArmorData:
			var eq_armor := eq_data as ArmorData
			var eq_armor_val := eq_armor.get_armor_value(eq_quality)

			var eq_name := InventoryManager.get_item_name(equipped.item_id)
			content.add_child(_make_tooltip_label("vs " + eq_name, COL_DIM))
			content.add_child(_make_tooltip_separator())

			content.add_child(_make_stat_row("Armor", armor_val, eq_armor_val, "%d"))
			content.add_child(_make_stat_row_inverted("Weight", armor.weight, eq_armor.weight, "%.1f"))

			if armor.is_shield or eq_armor.is_shield:
				var block_val := armor.get_block_value(quality)
				var eq_block_val := eq_armor.get_block_value(eq_quality)
				content.add_child(_make_stat_row("Block", block_val, eq_block_val, "%d"))
		else:
			content.add_child(_make_tooltip_label("Armor: %d" % armor_val, COL_TEXT))
			content.add_child(_make_tooltip_label("Weight: %.1f" % armor.weight, COL_TEXT))

func _build_generic_tooltip(content: VBoxContainer, item_data: Resource, quality: Enums.ItemQuality) -> void:
	# For consumables and other items, show basic info
	if item_data.has_method("get"):
		if item_data.get("weight"):
			content.add_child(_make_tooltip_label("Weight: %.1f" % item_data.weight, COL_TEXT))
		if item_data.get("value"):
			content.add_child(_make_tooltip_label("Base Value: %d" % item_data.value, COL_GOLD))

func _make_tooltip_label(text: String, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_tooltip_separator() -> Control:
	var sep = Label.new()
	sep.text = String.chr(0x2500).repeat(20)
	sep.add_theme_color_override("font_color", COL_BORDER)
	return sep

func _make_stat_row(stat_name: String, sel_val: float, eq_val: float, format: String) -> HBoxContainer:
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

func _make_stat_row_inverted(stat_name: String, sel_val: float, eq_val: float, format: String) -> HBoxContainer:
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

func _position_tooltip() -> void:
	if not hover_tooltip or not hover_tooltip.visible:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var tooltip_size: Vector2 = hover_tooltip.size
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var offset := Vector2(20, 10)

	var pos: Vector2 = mouse_pos + offset

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
