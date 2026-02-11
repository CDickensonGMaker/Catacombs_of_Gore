## bounty_board_ui.gd - UI for viewing and accepting bounties
extends Control

signal ui_closed

## Reference to the bounty board
var bounty_board: Node = null  # BountyBoard type

## UI components
var main_panel: PanelContainer
var tabs_container: HBoxContainer
var content_container: VBoxContainer
var bounty_list_container: VBoxContainer
var bounty_detail_panel: PanelContainer

## Current view mode
enum ViewMode { AVAILABLE, ACTIVE }
var current_mode: ViewMode = ViewMode.AVAILABLE

## Currently selected bounty
var selected_bounty = null  # BountyBoard.Bounty type

func _ready() -> void:
	_create_ui()
	_refresh_display()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

## Create the UI layout
func _create_ui() -> void:
	# Set root control to fill viewport (matching shop_ui.gd)
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Dark overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Main panel - full rect with margins (matching shop_ui.gd)
	main_panel = PanelContainer.new()
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel.offset_left = 20
	main_panel.offset_top = 20
	main_panel.offset_right = -20
	main_panel.offset_bottom = -20
	main_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1)
	style.border_color = Color(0.3, 0.25, 0.2)
	style.set_border_width_all(2)
	main_panel.add_theme_stylebox_override("panel", style)
	add_child(main_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	main_panel.add_child(main_vbox)

	# Title
	var title_label := Label.new()
	title_label.text = "BOUNTY BOARD"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	title_label.add_theme_font_size_override("font_size", 24)
	main_vbox.add_child(title_label)

	# Separator
	var sep := HSeparator.new()
	main_vbox.add_child(sep)

	# Tabs
	tabs_container = HBoxContainer.new()
	tabs_container.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_container.add_theme_constant_override("separation", 20)
	main_vbox.add_child(tabs_container)

	_create_tab_button("Available", ViewMode.AVAILABLE)
	_create_tab_button("Active", ViewMode.ACTIVE)

	# Separator
	var sep2 := HSeparator.new()
	main_vbox.add_child(sep2)

	# Content area (split view)
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 15)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)

	# Left side - Bounty list (scrollable)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(280, 0)
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(list_scroll)

	bounty_list_container = VBoxContainer.new()
	bounty_list_container.add_theme_constant_override("separation", 5)
	bounty_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(bounty_list_container)

	# Right side - Bounty details
	bounty_detail_panel = PanelContainer.new()
	bounty_detail_panel.custom_minimum_size = Vector2(320, 0)
	bounty_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.06, 0.06, 0.08)
	detail_style.border_color = Color(0.3, 0.25, 0.2)
	detail_style.set_border_width_all(1)
	bounty_detail_panel.add_theme_stylebox_override("panel", detail_style)
	content_hbox.add_child(bounty_detail_panel)

	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 8)
	bounty_detail_panel.add_child(content_container)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close [ESC]"
	close_btn.custom_minimum_size = Vector2(0, 35)
	close_btn.pressed.connect(_close)
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(close_btn)
	main_vbox.add_child(close_btn)

## Create a tab button
func _create_tab_button(text: String, mode: ViewMode) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(100, 30)
	btn.pressed.connect(_on_tab_selected.bind(mode))
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(btn)
	tabs_container.add_child(btn)

## Style a button
func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.12, 0.15)
	normal.border_color = Color(0.3, 0.25, 0.2)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.2, 0.15)
	hover.border_color = Color(0.8, 0.6, 0.2)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	btn.add_theme_color_override("font_hover_color", Color(0.9, 0.75, 0.4))

## Handle tab selection
func _on_tab_selected(mode: ViewMode) -> void:
	current_mode = mode
	selected_bounty = null
	_refresh_display()
	AudioManager.play_ui_select()

## Refresh the display
func _refresh_display() -> void:
	_refresh_bounty_list()
	_refresh_detail_panel()

## Refresh the bounty list
func _refresh_bounty_list() -> void:
	# Clear existing
	for child in bounty_list_container.get_children():
		child.queue_free()

	if not bounty_board:
		return

	var bounties: Array = []
	match current_mode:
		ViewMode.AVAILABLE:
			bounties = bounty_board.available_bounties
		ViewMode.ACTIVE:
			bounties = bounty_board.active_bounties

	if bounties.is_empty():
		var empty_label := Label.new()
		match current_mode:
			ViewMode.AVAILABLE:
				empty_label.text = "No bounties available.\nCheck back later!"
			ViewMode.ACTIVE:
				empty_label.text = "No active bounties.\nAccept one from Available tab."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		bounty_list_container.add_child(empty_label)
		return

	for bounty in bounties:
		_create_bounty_list_item(bounty)

## Create a bounty list item
func _create_bounty_list_item(bounty) -> void:
	var item_btn := Button.new()
	item_btn.custom_minimum_size = Vector2(0, 50)
	item_btn.pressed.connect(_on_bounty_selected.bind(bounty))
	item_btn.process_mode = Node.PROCESS_MODE_ALWAYS

	# Style based on tier and completion status
	var bg_color: Color = Color(0.1, 0.1, 0.12)
	var tier_color: Color = bounty.get_tier_color()
	var border_color: Color = tier_color.darkened(0.3)

	if bounty.is_complete:
		bg_color = Color(0.15, 0.2, 0.15)  # Greenish tint for complete
		border_color = Color(0.3, 0.8, 0.3)

	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_color = border_color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)

	var hover := StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.1)
	hover.border_color = bounty.get_tier_color()
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(4)

	item_btn.add_theme_stylebox_override("normal", normal)
	item_btn.add_theme_stylebox_override("hover", hover)
	item_btn.add_theme_stylebox_override("pressed", hover)

	# Button text layout
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_btn.add_child(vbox)

	var title := Label.new()
	title.text = bounty.title
	title.add_theme_color_override("font_color", bounty.get_tier_color())
	title.add_theme_font_size_override("font_size", 14)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var info := Label.new()
	var tier_text: String = bounty.tier.capitalize()
	if bounty.is_active:
		info.text = "[%s] %s" % [tier_text, bounty.get_progress_text()]
	else:
		info.text = "[%s] %d Gold, %d XP" % [tier_text, bounty.gold_reward, bounty.xp_reward]
	info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info.add_theme_font_size_override("font_size", 12)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(info)

	bounty_list_container.add_child(item_btn)

## Handle bounty selection
func _on_bounty_selected(bounty) -> void:
	selected_bounty = bounty
	_refresh_detail_panel()
	AudioManager.play_ui_select()

## Refresh the detail panel
func _refresh_detail_panel() -> void:
	# Clear existing
	for child in content_container.get_children():
		child.queue_free()

	if not selected_bounty:
		var empty_label := Label.new()
		empty_label.text = "Select a bounty to view details"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		content_container.add_child(empty_label)
		return

	# Title
	var title := Label.new()
	title.text = selected_bounty.title
	title.add_theme_color_override("font_color", selected_bounty.get_tier_color())
	title.add_theme_font_size_override("font_size", 18)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(title)

	# Tier badge
	var tier_label := Label.new()
	tier_label.text = "[ %s ]" % selected_bounty.tier.to_upper()
	tier_label.add_theme_color_override("font_color", selected_bounty.get_tier_color())
	content_container.add_child(tier_label)

	# Separator
	var sep := HSeparator.new()
	content_container.add_child(sep)

	# Description
	var desc := Label.new()
	desc.text = selected_bounty.description
	desc.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(desc)

	# Progress (if active)
	if selected_bounty.is_active:
		var progress_sep := HSeparator.new()
		content_container.add_child(progress_sep)

		var progress := Label.new()
		progress.text = "Progress: %s" % selected_bounty.get_progress_text()
		if selected_bounty.is_complete:
			progress.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		else:
			progress.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		content_container.add_child(progress)

	# Rewards
	var reward_sep := HSeparator.new()
	content_container.add_child(reward_sep)

	var rewards_title := Label.new()
	rewards_title.text = "Rewards:"
	rewards_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	content_container.add_child(rewards_title)

	var gold_label := Label.new()
	gold_label.text = "  Gold: %d" % selected_bounty.gold_reward
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	content_container.add_child(gold_label)

	var xp_label := Label.new()
	xp_label.text = "  Experience: %d" % selected_bounty.xp_reward
	xp_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	content_container.add_child(xp_label)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(spacer)

	# Action button
	if selected_bounty.is_active:
		if selected_bounty.is_complete:
			var turn_in_btn := Button.new()
			turn_in_btn.text = "Turn In Bounty"
			turn_in_btn.custom_minimum_size = Vector2(0, 40)
			turn_in_btn.pressed.connect(_on_turn_in_pressed)
			turn_in_btn.process_mode = Node.PROCESS_MODE_ALWAYS
			_style_action_button(turn_in_btn, Color(0.3, 0.7, 0.3))
			content_container.add_child(turn_in_btn)
		else:
			var abandon_btn := Button.new()
			abandon_btn.text = "Abandon Bounty"
			abandon_btn.custom_minimum_size = Vector2(0, 40)
			abandon_btn.pressed.connect(_on_abandon_pressed)
			abandon_btn.process_mode = Node.PROCESS_MODE_ALWAYS
			_style_action_button(abandon_btn, Color(0.7, 0.3, 0.3))
			content_container.add_child(abandon_btn)
	else:
		var accept_btn := Button.new()
		accept_btn.text = "Accept Bounty"
		accept_btn.custom_minimum_size = Vector2(0, 40)
		accept_btn.pressed.connect(_on_accept_pressed)
		accept_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		_style_action_button(accept_btn, Color(0.3, 0.5, 0.8))
		content_container.add_child(accept_btn)

## Style action button with color
func _style_action_button(btn: Button, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = color.darkened(0.5)
	normal.border_color = color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)

	var hover := StyleBoxFlat.new()
	hover.bg_color = color.darkened(0.3)
	hover.border_color = color.lightened(0.2)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color.WHITE)

## Accept bounty
func _on_accept_pressed() -> void:
	if not bounty_board or not selected_bounty:
		return

	if bounty_board.accept_bounty(selected_bounty):
		# Switch to active tab to see the bounty
		current_mode = ViewMode.ACTIVE
		_refresh_display()

## Turn in bounty
func _on_turn_in_pressed() -> void:
	if not bounty_board or not selected_bounty:
		return

	if bounty_board.turn_in_bounty(selected_bounty):
		selected_bounty = null
		_refresh_display()

## Abandon bounty
func _on_abandon_pressed() -> void:
	if not bounty_board or not selected_bounty:
		return

	bounty_board.abandon_bounty(selected_bounty)
	selected_bounty = null
	_refresh_display()

## Close the UI
func _close() -> void:
	ui_closed.emit()
