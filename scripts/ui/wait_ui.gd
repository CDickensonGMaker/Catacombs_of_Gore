## wait_ui.gd - UI for waiting/passing time anywhere in the world
## Opens with T key, uses slider to select hours, shows dynamic sun movement
class_name WaitUI
extends CanvasLayer

signal wait_completed(hours_waited: float)
signal wait_cancelled

## UI Components
var panel: PanelContainer
var title_label: Label
var time_label: Label
var slider: HSlider
var hours_label: Label
var wait_button: Button
var cancel_button: Button

## Waiting animation state
var is_waiting: bool = false
var wait_start_time: float = 0.0
var wait_start_day: int = 0
var wait_target_time: float = 0.0
var wait_target_day: int = 0
var wait_hours_total: float = 0.0
var wait_speed: float = 8.0  # Hours per second of animation

## Singleton pattern
static var instance: WaitUI = null


static func get_or_create() -> WaitUI:
	if instance and is_instance_valid(instance):
		return instance

	var ui := WaitUI.new()
	ui.name = "WaitUI"
	ui.layer = 100
	ui.process_mode = Node.PROCESS_MODE_ALWAYS

	# Add to scene tree via autoload
	if GameManager:
		GameManager.add_child(ui)

	instance = ui
	return ui


func _ready() -> void:
	_create_ui()
	visible = false


func _create_ui() -> void:
	# Main panel
	panel = PanelContainer.new()
	panel.name = "WaitPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -150
	panel.offset_bottom = 150
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	# Dark gothic style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.border_color = Color(0.4, 0.35, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "WAIT"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	title_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title_label)

	# Current time display
	time_label = Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	time_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(time_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	vbox.add_child(spacer)

	# Slider label
	hours_label = Label.new()
	hours_label.text = "Wait for: 1 hour"
	hours_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hours_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	hours_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(hours_label)

	# Hour slider (1-24 hours)
	slider = HSlider.new()
	slider.min_value = 1
	slider.max_value = 24
	slider.step = 1
	slider.value = 1
	slider.custom_minimum_size = Vector2(350, 30)
	slider.value_changed.connect(_on_slider_changed)
	slider.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_slider(slider)
	vbox.add_child(slider)

	# Time preview (what time it will be after waiting)
	var preview_label := Label.new()
	preview_label.name = "PreviewLabel"
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.5))
	preview_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(preview_label)

	# Button container
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 30)
	vbox.add_child(btn_container)

	# Wait button
	wait_button = Button.new()
	wait_button.text = "Wait"
	wait_button.custom_minimum_size = Vector2(100, 40)
	wait_button.pressed.connect(_on_wait_pressed)
	wait_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(wait_button, true)
	btn_container.add_child(wait_button)

	# Cancel button
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(100, 40)
	cancel_button.pressed.connect(_on_cancel_pressed)
	cancel_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(cancel_button, false)
	btn_container.add_child(cancel_button)

	add_child(panel)

	_update_time_display()
	_on_slider_changed(1)


func _style_slider(s: HSlider) -> void:
	# Custom slider style
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.8, 0.6, 0.2)
	grabber.set_corner_radius_all(8)

	var grabber_highlight := StyleBoxFlat.new()
	grabber_highlight.bg_color = Color(1.0, 0.8, 0.3)
	grabber_highlight.set_corner_radius_all(8)

	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.15, 0.15, 0.18)
	slider_bg.set_corner_radius_all(4)

	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = Color(0.4, 0.35, 0.25)
	slider_fill.set_corner_radius_all(4)

	s.add_theme_stylebox_override("grabber_area", slider_fill)
	s.add_theme_stylebox_override("grabber_area_highlight", slider_fill)
	s.add_theme_stylebox_override("slider", slider_bg)


func _style_button(btn: Button, is_primary: bool) -> void:
	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()

	if is_primary:
		normal.bg_color = Color(0.2, 0.25, 0.15)
		normal.border_color = Color(0.4, 0.5, 0.3)
		hover.bg_color = Color(0.3, 0.4, 0.2)
		hover.border_color = Color(0.6, 0.8, 0.4)
	else:
		normal.bg_color = Color(0.15, 0.12, 0.12)
		normal.border_color = Color(0.3, 0.25, 0.25)
		hover.bg_color = Color(0.25, 0.18, 0.18)
		hover.border_color = Color(0.5, 0.3, 0.3)

	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.6))
	btn.add_theme_font_size_override("font_size", 16)


func _update_time_display() -> void:
	if time_label:
		time_label.text = "Current: %s - Day %d" % [GameManager.get_time_string(), GameManager.current_day]


func _on_slider_changed(value: float) -> void:
	var hours := int(value)
	if hours == 1:
		hours_label.text = "Wait for: 1 hour"
	else:
		hours_label.text = "Wait for: %d hours" % hours

	# Update preview
	var preview := panel.get_node_or_null("VBoxContainer/PreviewLabel") as Label
	if preview:
		var future_time: float = GameManager.game_time + value
		var future_day: int = GameManager.current_day
		while future_time >= 24.0:
			future_time -= 24.0
			future_day += 1

		var hour := int(future_time)
		var minute := int((future_time - hour) * 60)
		var am_pm := "AM" if hour < 12 else "PM"
		var display_hour := hour % 12
		if display_hour == 0:
			display_hour = 12

		var time_str := "%d:%02d %s" % [display_hour, minute, am_pm]
		if future_day != GameManager.current_day:
			preview.text = "Until: %s (Day %d)" % [time_str, future_day]
		else:
			preview.text = "Until: %s" % time_str


func _on_wait_pressed() -> void:
	var hours := slider.value
	_start_waiting(hours)


func _on_cancel_pressed() -> void:
	hide_ui()
	wait_cancelled.emit()


func _start_waiting(hours: float) -> void:
	is_waiting = true
	wait_start_time = GameManager.game_time
	wait_start_day = GameManager.current_day
	wait_hours_total = hours

	# Calculate target time and day (handling midnight wraparound)
	wait_target_time = GameManager.game_time + hours
	wait_target_day = GameManager.current_day
	while wait_target_time >= 24.0:
		wait_target_time -= 24.0
		wait_target_day += 1

	# Update UI to show waiting state
	title_label.text = "WAITING..."
	slider.editable = false
	wait_button.disabled = true
	cancel_button.text = "Stop"

	# Unpause game so time can advance visually
	get_tree().paused = false


func _process(delta: float) -> void:
	if not visible:
		return

	if is_waiting:
		_process_waiting(delta)
	else:
		_update_time_display()


func _process_waiting(delta: float) -> void:
	# Advance time at accelerated rate
	var hours_to_advance: float = delta * wait_speed

	# Calculate hours remaining accounting for day changes
	var hours_remaining: float = _calculate_hours_remaining()

	if hours_remaining <= hours_to_advance or hours_remaining <= 0.01:
		# Finish waiting - advance exactly the remaining time
		if hours_remaining > 0:
			GameManager.advance_time(hours_remaining)
		_finish_waiting()
	else:
		# Continue waiting - advance time
		GameManager.advance_time(hours_to_advance)
		_update_time_display()

		# Update title with progress
		var new_hours_remaining: float = _calculate_hours_remaining()
		var progress: float = 1.0 - (new_hours_remaining / wait_hours_total)
		title_label.text = "WAITING... %d%%" % int(progress * 100)


## Calculate hours remaining until target time/day
func _calculate_hours_remaining() -> float:
	var current_day: int = GameManager.current_day
	var current_time: float = GameManager.game_time

	# Calculate total hours from current to target
	var days_diff: int = wait_target_day - current_day
	var time_diff: float = wait_target_time - current_time

	# Total hours remaining
	var hours_remaining: float = (days_diff * 24.0) + time_diff
	return hours_remaining


func _finish_waiting() -> void:
	is_waiting = false

	# Show completion notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Waited %d hours. Day %d, %s" % [
			int(wait_hours_total), GameManager.current_day, GameManager.get_time_string()
		])

	AudioManager.play_ui_confirm()
	wait_completed.emit(wait_hours_total)
	hide_ui()


func show_ui() -> void:
	# Check if player is in combat
	if CombatManager.is_in_combat():
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Cannot wait during combat!")
		return

	# Check if player is in tournament combat
	if TournamentManager and TournamentManager.is_tournament_active:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Cannot wait during gladiator combat!")
		return

	visible = true
	is_waiting = false

	# Reset UI state
	title_label.text = "WAIT"
	slider.editable = true
	slider.value = 1
	wait_button.disabled = false
	cancel_button.text = "Cancel"

	_update_time_display()
	_on_slider_changed(1)

	# Pause game and show cursor
	get_tree().paused = true
	GameManager.enter_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func hide_ui() -> void:
	visible = false
	is_waiting = false

	# Unpause and capture mouse
	get_tree().paused = false
	GameManager.exit_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# ESC to cancel
	if event.is_action_pressed("ui_cancel"):
		if is_waiting:
			# Stop waiting early
			is_waiting = false
			title_label.text = "WAIT"
			slider.editable = true
			wait_button.disabled = false
			cancel_button.text = "Cancel"
			_update_time_display()
		else:
			hide_ui()
			wait_cancelled.emit()
		get_viewport().set_input_as_handled()


## Static method to open the wait UI
static func open_wait_menu() -> void:
	var ui := get_or_create()
	ui.show_ui()
