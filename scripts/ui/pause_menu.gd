## pause_menu.gd - Pause menu with Save/Load functionality
class_name PauseMenu
extends Control

signal menu_closed

enum MenuState { MAIN, SAVE_SELECT, LOAD_SELECT, OPTIONS }
var current_state: MenuState = MenuState.MAIN

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

# UI References
var main_panel: PanelContainer
var save_panel: PanelContainer
var load_panel: PanelContainer
var options_panel: PanelContainer
var slot_buttons: Array[Button] = []
var selected_slot: int = -1
var confirm_dialog: ConfirmationDialog

# Options UI elements
var dice_roll_checkbox: CheckBox
var ui_scale_slider: HSlider
var ui_scale_label: Label

func _ready() -> void:
	visible = false
	_build_menu()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if current_state == MenuState.MAIN:
			close()
		else:
			_show_main_menu()
		get_viewport().set_input_as_handled()

func _build_menu() -> void:
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.8)
	add_child(overlay)

	# Main menu panel
	main_panel = _create_main_panel()
	add_child(main_panel)

	# Save slot selection panel
	save_panel = _create_slot_panel("SAVE GAME", true)
	save_panel.visible = false
	add_child(save_panel)

	# Load slot selection panel
	load_panel = _create_slot_panel("LOAD GAME", false)
	load_panel.visible = false
	add_child(load_panel)

	# Options panel
	options_panel = _create_options_panel()
	options_panel.visible = false
	add_child(options_panel)

	# Confirmation dialog
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Confirm"
	add_child(confirm_dialog)

func _create_main_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -150
	panel.offset_right = 150
	panel.offset_top = -180
	panel.offset_bottom = 180

	var style := StyleBoxFlat.new()
	style.bg_color = COL_BG
	style.border_color = COL_BORDER
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	vbox.add_child(spacer)

	# Menu buttons
	var resume_btn := _create_menu_button("Resume")
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)

	var save_btn := _create_menu_button("Save Game")
	save_btn.pressed.connect(_on_save_pressed)
	vbox.add_child(save_btn)

	var load_btn := _create_menu_button("Load Game")
	load_btn.pressed.connect(_on_load_pressed)
	vbox.add_child(load_btn)

	var options_btn := _create_menu_button("Options")
	options_btn.pressed.connect(_on_options_pressed)
	vbox.add_child(options_btn)

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 10
	vbox.add_child(spacer2)

	var quit_btn := _create_menu_button("Quit to Desktop")
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

	return panel

func _create_slot_panel(title_text: String, is_save: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -220
	panel.offset_bottom = 220

	var style := StyleBoxFlat.new()
	style.bg_color = COL_BG
	style.border_color = COL_BORDER
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	# Scroll container for slots
	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.custom_minimum_size = Vector2(380, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var slot_vbox := VBoxContainer.new()
	slot_vbox.name = "SlotContainer"
	slot_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(slot_vbox)

	# Bottom buttons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	if is_save:
		var new_save_btn := _create_menu_button("New Save", true)
		new_save_btn.pressed.connect(_on_new_save_pressed)
		btn_hbox.add_child(new_save_btn)

	var back_btn := _create_menu_button("Back", true)
	back_btn.pressed.connect(_show_main_menu)
	btn_hbox.add_child(back_btn)

	return panel

func _create_menu_button(text: String, small: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180 if not small else 100, 40 if not small else 32)

	var normal := StyleBoxFlat.new()
	normal.bg_color = COL_PANEL
	normal.border_color = COL_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)

	var hover := StyleBoxFlat.new()
	hover.bg_color = COL_SELECT
	hover.border_color = COL_GOLD
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = COL_SELECT
	pressed.border_color = COL_GOLD
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", COL_GOLD)

	return btn

func _create_slot_button(slot: int, info: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(360, 60)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var normal := StyleBoxFlat.new()
	normal.bg_color = COL_PANEL
	normal.border_color = COL_BORDER
	normal.set_border_width_all(1)

	var hover := StyleBoxFlat.new()
	hover.bg_color = COL_SELECT
	hover.border_color = COL_GOLD
	hover.set_border_width_all(1)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", COL_TEXT)

	# Check if this is an autosave slot
	var is_autosave: bool = (slot == SaveManager.AUTOSAVE_PERIODIC_SLOT or slot == SaveManager.AUTOSAVE_EXIT_SLOT)
	var slot_name: String = ""
	if slot == SaveManager.AUTOSAVE_PERIODIC_SLOT:
		slot_name = "30s Autosave"
	elif slot == SaveManager.AUTOSAVE_EXIT_SLOT:
		slot_name = "Exit Autosave"
	else:
		slot_name = "Slot %d" % (slot + 1)

	# Build slot text
	if info.get("empty", false):
		btn.text = "%s - Empty" % slot_name
		btn.add_theme_color_override("font_color", COL_DIM)
	else:
		var char_name: String = info.get("character_name", "Unknown")
		var level: int = info.get("level", 1)
		var location: String = info.get("location", "Unknown")
		var play_time: float = info.get("play_time", 0.0)

		var time_str := SaveManager.format_playtime(play_time)
		btn.text = "%s: %s (Lv.%d)\n%s | %s" % [slot_name, char_name, level, location, time_str]

	return btn

func open() -> void:
	visible = true
	_show_main_menu()
	GameManager.enter_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

func close() -> void:
	visible = false
	current_state = MenuState.MAIN
	GameManager.exit_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false
	menu_closed.emit()

func _show_main_menu() -> void:
	current_state = MenuState.MAIN
	main_panel.visible = true
	save_panel.visible = false
	load_panel.visible = false
	options_panel.visible = false

func _show_save_panel() -> void:
	current_state = MenuState.SAVE_SELECT
	main_panel.visible = false
	save_panel.visible = true
	load_panel.visible = false
	_populate_slots(save_panel, true)

func _show_load_panel() -> void:
	current_state = MenuState.LOAD_SELECT
	main_panel.visible = false
	save_panel.visible = false
	load_panel.visible = true
	_populate_slots(load_panel, false)

func _populate_slots(panel: PanelContainer, is_save: bool) -> void:
	var container: VBoxContainer = panel.get_node_or_null("VBoxContainer/ScrollContainer/SlotContainer")
	if not container:
		push_error("[PauseMenu] SlotContainer not found in panel!")
		return

	# Clear existing
	for child in container.get_children():
		child.queue_free()

	slot_buttons.clear()

	# Get all save infos
	var infos := SaveManager.get_all_save_infos()

	for info in infos:
		var slot: int = info.get("slot", 0)
		var btn := _create_slot_button(slot, info)

		if is_save:
			btn.pressed.connect(_on_save_slot_selected.bind(slot, info))
		else:
			# Only enable load if slot has data
			if info.get("empty", false):
				btn.disabled = true
			else:
				btn.pressed.connect(_on_load_slot_selected.bind(slot, info))

		container.add_child(btn)
		slot_buttons.append(btn)

		# Add delete button for non-empty slots
		if not info.get("empty", false):
			var delete_btn := Button.new()
			delete_btn.text = "X"
			delete_btn.custom_minimum_size = Vector2(30, 30)
			delete_btn.add_theme_color_override("font_color", COL_RED)
			delete_btn.pressed.connect(_on_delete_slot_pressed.bind(slot))

			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 4)

			# Re-parent button into hbox
			btn.get_parent().remove_child(btn)
			hbox.add_child(btn)
			hbox.add_child(delete_btn)
			container.add_child(hbox)

# Button handlers

func _on_resume_pressed() -> void:
	AudioManager.play_ui_confirm()
	close()

func _on_save_pressed() -> void:
	AudioManager.play_ui_confirm()
	_show_save_panel()

func _on_load_pressed() -> void:
	AudioManager.play_ui_confirm()
	_show_load_panel()

func _on_quit_pressed() -> void:
	AudioManager.play_ui_confirm()
	confirm_dialog.dialog_text = "Are you sure you want to quit?\nUnsaved progress will be lost."
	confirm_dialog.confirmed.connect(_do_quit, CONNECT_ONE_SHOT)
	confirm_dialog.popup_centered()

func _do_quit() -> void:
	get_tree().quit()

func _on_new_save_pressed() -> void:
	AudioManager.play_ui_confirm()
	# Find first empty slot
	var infos := SaveManager.get_all_save_infos()
	for info in infos:
		if info.get("empty", false):
			_do_save(info.get("slot", 0))
			return

	# No empty slots - overwrite oldest or show message
	_show_notification("All save slots are full!")

func _on_save_slot_selected(slot: int, info: Dictionary) -> void:
	AudioManager.play_ui_confirm()
	selected_slot = slot

	if info.get("empty", false):
		_do_save(slot)
	else:
		# Confirm overwrite
		confirm_dialog.dialog_text = "Overwrite save in Slot %d?" % (slot + 1)
		confirm_dialog.confirmed.connect(_do_save.bind(slot), CONNECT_ONE_SHOT)
		confirm_dialog.popup_centered()

func _on_load_slot_selected(slot: int, _info: Dictionary) -> void:
	AudioManager.play_ui_confirm()
	selected_slot = slot

	confirm_dialog.dialog_text = "Load save from Slot %d?\nUnsaved progress will be lost." % (slot + 1)
	confirm_dialog.confirmed.connect(_do_load.bind(slot), CONNECT_ONE_SHOT)
	confirm_dialog.popup_centered()

func _on_delete_slot_pressed(slot: int) -> void:
	AudioManager.play_ui_confirm()
	confirm_dialog.dialog_text = "Delete save in Slot %d?\nThis cannot be undone." % (slot + 1)
	confirm_dialog.confirmed.connect(_do_delete.bind(slot), CONNECT_ONE_SHOT)
	confirm_dialog.popup_centered()

func _do_save(slot: int) -> void:
	if SaveManager.save_game(slot):
		_show_notification("Game saved to Slot %d" % (slot + 1))
		_show_save_panel()  # Refresh
	else:
		_show_notification("Save failed!")

func _do_load(slot: int) -> void:
	# Close menu first
	visible = false
	get_tree().paused = false

	if SaveManager.load_game(slot):
		# Get scene to load
		var info := SaveManager.get_save_info(slot)
		var scene_path: String = info.get("current_scene", "")

		if not scene_path.is_empty():
			SceneManager.change_scene(scene_path)
		else:
			_show_notification("Load failed - no scene!")
			open()
	else:
		_show_notification("Load failed!")
		open()

func _do_delete(slot: int) -> void:
	if SaveManager.delete_save(slot):
		_show_notification("Slot %d deleted" % (slot + 1))
		# Refresh current panel
		if current_state == MenuState.SAVE_SELECT:
			_show_save_panel()
		elif current_state == MenuState.LOAD_SELECT:
			_show_load_panel()
	else:
		_show_notification("Delete failed!")

func _show_notification(message: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(message)

# ==================== OPTIONS PANEL ====================

func _create_options_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -200
	panel.offset_bottom = 200

	var style := StyleBoxFlat.new()
	style.bg_color = COL_BG
	style.border_color = COL_BORDER
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	# Dice Roll Toggle (first option as per plan)
	var dice_hbox := HBoxContainer.new()
	dice_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(dice_hbox)

	dice_roll_checkbox = CheckBox.new()
	dice_roll_checkbox.button_pressed = DiceManager.show_dice_rolls if DiceManager else true
	dice_roll_checkbox.toggled.connect(_on_dice_roll_toggled)
	dice_hbox.add_child(dice_roll_checkbox)

	var dice_label := Label.new()
	dice_label.text = "Show Dice Rolls"
	dice_label.add_theme_color_override("font_color", COL_TEXT)
	dice_hbox.add_child(dice_label)

	# Description
	var dice_desc := Label.new()
	dice_desc.text = "Display roll breakdowns for\nskill checks and combat"
	dice_desc.add_theme_color_override("font_color", COL_DIM)
	dice_desc.add_theme_font_size_override("font_size", 11)
	vbox.add_child(dice_desc)

	# Separator
	var sep1 := HSeparator.new()
	sep1.add_theme_color_override("separation", COL_BORDER)
	vbox.add_child(sep1)

	# UI Scale Slider
	var scale_title_hbox := HBoxContainer.new()
	scale_title_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(scale_title_hbox)

	var scale_title := Label.new()
	scale_title.text = "UI Scale"
	scale_title.add_theme_color_override("font_color", COL_TEXT)
	scale_title_hbox.add_child(scale_title)

	ui_scale_label = Label.new()
	ui_scale_label.text = "100%"
	ui_scale_label.add_theme_color_override("font_color", COL_GOLD)
	scale_title_hbox.add_child(ui_scale_label)

	ui_scale_slider = HSlider.new()
	ui_scale_slider.min_value = 0.5
	ui_scale_slider.max_value = 1.5
	ui_scale_slider.step = 0.05
	ui_scale_slider.value = _get_current_ui_scale()
	ui_scale_slider.custom_minimum_size = Vector2(250, 20)
	ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	vbox.add_child(ui_scale_slider)

	# Scale description
	var scale_desc := Label.new()
	scale_desc.text = "Adjusts the size of all UI elements"
	scale_desc.add_theme_color_override("font_color", COL_DIM)
	scale_desc.add_theme_font_size_override("font_size", 11)
	vbox.add_child(scale_desc)

	# Update label with current value
	_update_scale_label(ui_scale_slider.value)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	vbox.add_child(spacer)

	# Back button
	var back_btn := _create_menu_button("Back")
	back_btn.pressed.connect(_show_main_menu)
	vbox.add_child(back_btn)

	return panel

func _on_options_pressed() -> void:
	AudioManager.play_ui_confirm()
	_show_options_panel()

func _show_options_panel() -> void:
	current_state = MenuState.OPTIONS
	main_panel.visible = false
	save_panel.visible = false
	load_panel.visible = false
	options_panel.visible = true

	# Refresh checkbox state
	if dice_roll_checkbox and DiceManager:
		dice_roll_checkbox.button_pressed = DiceManager.show_dice_rolls

	# Refresh UI scale slider
	if ui_scale_slider:
		var current_scale := _get_current_ui_scale()
		ui_scale_slider.value = current_scale
		_update_scale_label(current_scale)

func _on_dice_roll_toggled(enabled: bool) -> void:
	if DiceManager:
		DiceManager.set_show_dice_rolls(enabled)
	AudioManager.play_ui_confirm()


func _get_current_ui_scale() -> float:
	var window := get_window()
	if window:
		return window.content_scale_factor
	return 1.0


func _on_ui_scale_changed(value: float) -> void:
	var window := get_window()
	if window:
		window.content_scale_factor = value
	_update_scale_label(value)
	AudioManager.play_ui_confirm()


func _update_scale_label(value: float) -> void:
	if ui_scale_label:
		ui_scale_label.text = "%d%%" % int(value * 100)
