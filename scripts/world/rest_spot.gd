## rest_spot.gd - A safe spot where players can rest to heal and spend XP
class_name RestSpot
extends StaticBody3D

const FIREPLACE_TEXTURE := "res://Sprite folders grab bag/fireplace.png"

## Type of rest spot - determines if level up is available
enum RestSpotType {
	WILD_FIREPLACE,    # Full recovery, no level up
	TAVERN_FIREPLACE,  # Full recovery + level up (town hearths)
	INN_BED            # Full recovery + level up (paid beds)
}

@export var display_name: String = "Fireplace"
@export var rest_spot_id: String = "rest_spot_01"
@export var rest_type: RestSpotType = RestSpotType.WILD_FIREPLACE

## Visual representation
var billboard_sprite: BillboardSprite

## Interaction area
var interaction_area: Area3D

## Rest UI reference
var rest_ui: Control = null

## Level up UI reference
var level_up_ui: Control = null
var xp_label: Label = null

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("rest_spots")

	# Only create visuals/areas if not already present (supports scene instancing)
	if not get_node_or_null("FireplaceSprite") and not get_node_or_null("FallbackMesh"):
		_create_visual()
	else:
		billboard_sprite = get_node_or_null("FireplaceSprite")

	if not get_node_or_null("InteractionArea"):
		_create_interaction_area()
	else:
		interaction_area = get_node_or_null("InteractionArea")

	if not get_node_or_null("Collision"):
		_create_collision()

	_register_compass_poi()


## Register this rest spot as a compass POI
## Uses instance ID for guaranteed uniqueness across scenes
func _register_compass_poi() -> void:
	add_to_group("compass_poi")
	# Use instance_id for guaranteed uniqueness - prevents ghost markers across scenes
	set_meta("poi_id", "rest_%d" % get_instance_id())
	set_meta("poi_name", display_name)
	set_meta("poi_color", Color(1.0, 0.8, 0.4))  # Warm orange/yellow for rest spots

## Create the visual representation (animated fireplace billboard sprite)
func _create_visual() -> void:
	var texture: Texture2D = load(FIREPLACE_TEXTURE)
	if texture:
		# Create animated billboard sprite for the fireplace
		billboard_sprite = BillboardSprite.new()
		billboard_sprite.name = "FireplaceSprite"
		billboard_sprite.sprite_sheet = texture
		billboard_sprite.h_frames = 4
		billboard_sprite.v_frames = 4
		billboard_sprite.pixel_size = 0.025  # Good size for fireplace
		billboard_sprite.offset_y = 0.0  # Standard positioning - sprite bottom at ground level
		billboard_sprite.idle_frames = 4  # Use all columns for fire animation
		billboard_sprite.idle_fps = 8.0  # Flickering fire animation
		add_child(billboard_sprite)
	else:
		# Fallback to simple mesh if texture not found
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "FallbackMesh"
		var base_mesh := CylinderMesh.new()
		base_mesh.top_radius = 0.3
		base_mesh.bottom_radius = 0.5
		base_mesh.height = 0.3
		mesh_instance.mesh = base_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.4, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.4, 0.0)
		mesh_instance.material_override = mat
		add_child(mesh_instance)

	# Add bright warm point light for fire ambiance
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 2.5  # Bright fire light
	light.omni_range = 8.0  # Large warm glow radius
	light.omni_attenuation = 1.2
	light.position.y = 1.0
	add_child(light)

	# Add secondary flickering light for realism
	var flicker_light := OmniLight3D.new()
	flicker_light.name = "FlickerLight"
	flicker_light.light_color = Color(1.0, 0.4, 0.1)
	flicker_light.light_energy = 1.0
	flicker_light.omni_range = 4.0
	flicker_light.position.y = 0.5
	add_child(flicker_light)

## Create interaction area
func _create_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.0  # Interaction range
	collision.shape = shape
	interaction_area.add_child(collision)

	add_child(interaction_area)

## Create collision shape for the base
func _create_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 0.3
	collision.shape = shape
	collision.position.y = 0.15
	add_child(collision)

## Interaction interface
func interact(_interactor: Node) -> void:
	_open_rest_ui()

func get_interaction_prompt() -> String:
	return "Press [E] to rest at " + display_name

## Open the rest UI
func _open_rest_ui() -> void:
	if rest_ui:
		return  # Already open

	# Pause the game
	get_tree().paused = true
	GameManager.enter_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Create rest UI
	rest_ui = _create_rest_panel()

	# Add to CanvasLayer for proper rendering
	var canvas := CanvasLayer.new()
	canvas.name = "RestUICanvas"
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	canvas.add_child(rest_ui)

## Target rest time (set by button selection)
var rest_target_hour: float = 6.0  # Default to dawn

## Create the rest confirmation panel
func _create_rest_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "RestPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = -160
	panel.offset_bottom = 160
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	# Dark gothic style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1)
	style.border_color = Color(0.3, 0.25, 0.2)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = display_name.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	# Current time info
	var time_info := Label.new()
	time_info.text = "Current: %s - Day %d" % [GameManager.get_time_string(), GameManager.current_day]
	time_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_info.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	time_info.add_theme_font_size_override("font_size", 14)
	vbox.add_child(time_info)

	# Message
	var message := Label.new()
	if rest_type == RestSpotType.TAVERN_FIREPLACE or rest_type == RestSpotType.INN_BED:
		message.text = "Rest to restore HP, Mana, and Stamina.\nYou may also spend XP to level up here.\nChoose when to wake:"
	else:
		message.text = "Rest to restore HP, Mana, and Stamina.\nChoose when to wake:"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	vbox.add_child(message)

	# Time selection buttons
	var time_container := HBoxContainer.new()
	time_container.alignment = BoxContainer.ALIGNMENT_CENTER
	time_container.add_theme_constant_override("separation", 8)
	vbox.add_child(time_container)

	# Dawn (6 AM)
	var dawn_btn := Button.new()
	dawn_btn.text = "Dawn\n6:00 AM"
	dawn_btn.custom_minimum_size = Vector2(75, 50)
	dawn_btn.pressed.connect(_on_rest_until.bind(6.0, "Dawn"))
	dawn_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_time_button(dawn_btn)
	time_container.add_child(dawn_btn)

	# Morning (9 AM)
	var morning_btn := Button.new()
	morning_btn.text = "Morning\n9:00 AM"
	morning_btn.custom_minimum_size = Vector2(75, 50)
	morning_btn.pressed.connect(_on_rest_until.bind(9.0, "Morning"))
	morning_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_time_button(morning_btn)
	time_container.add_child(morning_btn)

	# Noon (12 PM)
	var noon_btn := Button.new()
	noon_btn.text = "Noon\n12:00 PM"
	noon_btn.custom_minimum_size = Vector2(75, 50)
	noon_btn.pressed.connect(_on_rest_until.bind(12.0, "Noon"))
	noon_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_time_button(noon_btn)
	time_container.add_child(noon_btn)

	# Dusk (6 PM)
	var dusk_btn := Button.new()
	dusk_btn.text = "Dusk\n6:00 PM"
	dusk_btn.custom_minimum_size = Vector2(75, 50)
	dusk_btn.pressed.connect(_on_rest_until.bind(18.0, "Dusk"))
	dusk_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_time_button(dusk_btn)
	time_container.add_child(dusk_btn)

	# Bottom buttons (Level Up and Cancel)
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_container)

	# Level Up button only available at hearths (TAVERN_FIREPLACE) or inn beds
	if rest_type == RestSpotType.TAVERN_FIREPLACE or rest_type == RestSpotType.INN_BED:
		var level_btn := Button.new()
		level_btn.text = "Level Up"
		level_btn.custom_minimum_size = Vector2(100, 35)
		level_btn.pressed.connect(_open_level_up_ui)
		level_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		_style_button(level_btn)
		btn_container.add_child(level_btn)

	var no_btn := Button.new()
	no_btn.text = "Cancel"
	no_btn.custom_minimum_size = Vector2(100, 35)
	no_btn.pressed.connect(_close_rest_ui)
	no_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(no_btn)
	btn_container.add_child(no_btn)

	return panel

## Handle resting until a specific time
func _on_rest_until(target_hour: float, time_name: String) -> void:
	# Calculate hours to sleep
	var hours_slept: float = 0.0
	if GameManager.game_time < target_hour:
		hours_slept = target_hour - GameManager.game_time
	else:
		# Sleep through to next day
		hours_slept = (24.0 - GameManager.game_time) + target_hour

	# Convert rest spot type to RestManager type
	var rm_rest_type: RestManager.RestType
	match rest_type:
		RestSpotType.WILD_FIREPLACE:
			rm_rest_type = RestManager.RestType.WILD_FIREPLACE
		RestSpotType.TAVERN_FIREPLACE:
			rm_rest_type = RestManager.RestType.TAVERN_FIREPLACE
		RestSpotType.INN_BED:
			rm_rest_type = RestManager.RestType.INN_BED
		_:
			rm_rest_type = RestManager.RestType.WILD_FIREPLACE

	# Use RestManager for proper recovery calculation
	var result := RestManager.perform_rest(rm_rest_type, hours_slept)

	# Show notification based on rest type
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		var hours_int: int = int(hours_slept)
		if rest_type == RestSpotType.TAVERN_FIREPLACE:
			hud.show_notification("Waited %d hours until %s. Day %d" % [hours_int, time_name, GameManager.current_day])
		else:
			hud.show_notification("Rested %d hours (+%d HP, +%d Mana). Day %d" % [
				hours_int, result.hp_restored, result.mana_restored, GameManager.current_day
			])

	SaveManager.save_game(SaveManager.AUTOSAVE_EXIT_SLOT)
	AudioManager.play_ui_confirm()
	_close_rest_ui()

## Style a time selection button
func _style_time_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.12, 0.1)
	normal.border_color = Color(0.4, 0.35, 0.25)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.2, 0.15)
	hover.border_color = Color(0.8, 0.6, 0.2)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.6))
	btn.add_theme_font_size_override("font_size", 12)

## Style a button with gothic theme
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
	btn.add_theme_color_override("font_hover_color", Color(0.8, 0.6, 0.2))

## Close the rest UI
func _close_rest_ui() -> void:
	if rest_ui:
		var canvas := rest_ui.get_parent()
		rest_ui.queue_free()
		if canvas:
			canvas.queue_free()
		rest_ui = null

	# Unpause and return control
	get_tree().paused = false
	GameManager.exit_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Open level up UI
func _open_level_up_ui() -> void:
	if level_up_ui:
		return  # Already open

	# Hide rest panel while level up is open
	if rest_ui:
		rest_ui.visible = false

	level_up_ui = _create_level_up_panel()

	# Add to same canvas layer
	var canvas := get_node_or_null("RestUICanvas")
	if canvas:
		canvas.add_child(level_up_ui)

## Create the level up panel
func _create_level_up_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "LevelUpPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -220
	panel.offset_bottom = 220
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	# Dark gothic style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1)
	style.border_color = Color(0.3, 0.25, 0.2)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)

	# Header with title and XP
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(header)

	var title := Label.new()
	title.text = "SPEND XP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	xp_label = Label.new()
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	xp_label.add_theme_font_size_override("font_size", 16)
	_update_xp_label()
	header.add_child(xp_label)

	# Scroll container for stats and skills
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 350)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	main_vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(content_vbox)

	# Stats section
	var stats_label := Label.new()
	stats_label.text = "— STATS —"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	content_vbox.add_child(stats_label)

	for stat in Enums.Stat.values():
		var row := _create_stat_row(stat)
		content_vbox.add_child(row)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 15
	content_vbox.add_child(spacer)

	# Skills section
	var skills_label := Label.new()
	skills_label.text = "— SKILLS —"
	skills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skills_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	content_vbox.add_child(skills_label)

	for skill in Enums.Skill.values():
		var row := _create_skill_row(skill)
		content_vbox.add_child(row)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(100, 35)
	back_btn.pressed.connect(_close_level_up_ui)
	back_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(back_btn)
	main_vbox.add_child(back_btn)

	return panel

## Create a row for a stat
func _create_stat_row(stat: Enums.Stat) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var char_data := GameManager.player_data

	# Stat name
	var name_label := Label.new()
	name_label.text = _get_stat_name(stat)
	name_label.custom_minimum_size.x = 100
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	row.add_child(name_label)

	# Current value
	var current_value := char_data.get_stat(stat) if char_data else 3
	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = str(current_value)
	value_label.custom_minimum_size.x = 30
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	row.add_child(value_label)

	# Cost
	var cost := char_data.get_stat_ip_cost(current_value) if char_data else 50
	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "(%d XP)" % cost if current_value < 15 else "(MAX)"
	cost_label.custom_minimum_size.x = 100
	cost_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	cost_label.add_theme_font_size_override("font_size", 12)
	row.add_child(cost_label)

	# Upgrade button
	var btn := Button.new()
	btn.name = "UpgradeBtn"
	btn.text = "+"
	btn.custom_minimum_size = Vector2(30, 25)
	btn.disabled = not char_data or char_data.improvement_points < cost or current_value >= 15
	btn.pressed.connect(_on_stat_upgrade.bind(stat, row))
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_small_button(btn)
	row.add_child(btn)

	return row

## Create a row for a skill
func _create_skill_row(skill: Enums.Skill) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var char_data := GameManager.player_data

	# Skill name
	var name_label := Label.new()
	name_label.text = _get_skill_name(skill)
	name_label.custom_minimum_size.x = 100
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	row.add_child(name_label)

	# Current value
	var current_value := char_data.get_skill(skill) if char_data else 0
	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = str(current_value)
	value_label.custom_minimum_size.x = 30
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	row.add_child(value_label)

	# Cost
	var next_level := current_value + 1
	var cost := Enums.get_skill_ip_cost(next_level) if current_value < 10 else 0
	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "(%d XP)" % cost if current_value < 10 else "(MAX)"
	cost_label.custom_minimum_size.x = 100
	cost_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	cost_label.add_theme_font_size_override("font_size", 12)
	row.add_child(cost_label)

	# Upgrade button
	var btn := Button.new()
	btn.name = "UpgradeBtn"
	btn.text = "+"
	btn.custom_minimum_size = Vector2(30, 25)
	btn.disabled = not char_data or char_data.improvement_points < cost or current_value >= 10
	btn.pressed.connect(_on_skill_upgrade.bind(skill, row))
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_small_button(btn)
	row.add_child(btn)

	return row

## Handle stat upgrade
func _on_stat_upgrade(stat: Enums.Stat, row: HBoxContainer) -> void:
	var char_data := GameManager.player_data
	if not char_data:
		return

	if char_data.increase_stat(stat):
		AudioManager.play_ui_confirm()
		_update_stat_row(stat, row)
		_update_xp_label()
		_refresh_all_buttons()

## Handle skill upgrade
func _on_skill_upgrade(skill: Enums.Skill, row: HBoxContainer) -> void:
	var char_data := GameManager.player_data
	if not char_data:
		return

	if char_data.increase_skill(skill):
		AudioManager.play_ui_confirm()
		_update_skill_row(skill, row)
		_update_xp_label()
		_refresh_all_buttons()

## Update a stat row after upgrade
func _update_stat_row(stat: Enums.Stat, row: HBoxContainer) -> void:
	var char_data := GameManager.player_data
	if not char_data:
		return

	var current_value := char_data.get_stat(stat)
	var cost := char_data.get_stat_ip_cost(current_value)

	var value_label := row.get_node_or_null("ValueLabel") as Label
	if value_label:
		value_label.text = str(current_value)

	var cost_label := row.get_node_or_null("CostLabel") as Label
	if cost_label:
		cost_label.text = "(%d XP)" % cost if current_value < 15 else "(MAX)"

	var btn := row.get_node_or_null("UpgradeBtn") as Button
	if btn:
		btn.disabled = char_data.improvement_points < cost or current_value >= 15

## Update a skill row after upgrade
func _update_skill_row(skill: Enums.Skill, row: HBoxContainer) -> void:
	var char_data := GameManager.player_data
	if not char_data:
		return

	var current_value := char_data.get_skill(skill)
	var next_level := current_value + 1
	var cost := Enums.get_skill_ip_cost(next_level) if current_value < 10 else 0

	var value_label := row.get_node_or_null("ValueLabel") as Label
	if value_label:
		value_label.text = str(current_value)

	var cost_label := row.get_node_or_null("CostLabel") as Label
	if cost_label:
		cost_label.text = "(%d XP)" % cost if current_value < 10 else "(MAX)"

	var btn := row.get_node_or_null("UpgradeBtn") as Button
	if btn:
		btn.disabled = char_data.improvement_points < cost or current_value >= 10

## Update XP label
func _update_xp_label() -> void:
	if xp_label and GameManager.player_data:
		xp_label.text = "XP: %d" % GameManager.player_data.improvement_points

## Refresh all upgrade buttons (after spending XP)
func _refresh_all_buttons() -> void:
	if not level_up_ui:
		return

	var char_data := GameManager.player_data
	if not char_data:
		return

	# Find all upgrade buttons and update their disabled state
	var scroll := level_up_ui.get_node_or_null("VBoxContainer/ScrollContainer")
	if not scroll:
		return

	var content := scroll.get_child(0)
	if not content:
		return

	for child in content.get_children():
		if child is HBoxContainer:
			var btn := child.get_node_or_null("UpgradeBtn") as Button
			var cost_label := child.get_node_or_null("CostLabel") as Label
			if btn and cost_label:
				var cost_text: String = cost_label.text
				if "(MAX)" in cost_text:
					btn.disabled = true
				else:
					# Parse cost from "(XXX XP)"
					var cost_str := cost_text.replace("(", "").replace(" XP)", "")
					var cost := int(cost_str) if cost_str.is_valid_int() else 99999
					btn.disabled = char_data.improvement_points < cost

## Close level up UI
func _close_level_up_ui() -> void:
	if level_up_ui:
		level_up_ui.queue_free()
		level_up_ui = null
		xp_label = null

	# Show rest panel again
	if rest_ui:
		rest_ui.visible = true

## Style a small button
func _style_small_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.2, 0.15)
	normal.border_color = Color(0.3, 0.4, 0.3)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.2, 0.35, 0.2)
	hover.border_color = Color(0.5, 0.8, 0.5)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(3)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.1, 0.1, 0.1)
	disabled.border_color = Color(0.2, 0.2, 0.2)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(3)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	btn.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.7))
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))

## Get display name for stat
func _get_stat_name(stat: Enums.Stat) -> String:
	match stat:
		Enums.Stat.GRIT: return "Grit"
		Enums.Stat.AGILITY: return "Agility"
		Enums.Stat.WILL: return "Will"
		Enums.Stat.SPEECH: return "Speech"
		Enums.Stat.KNOWLEDGE: return "Knowledge"
		Enums.Stat.VITALITY: return "Vitality"
		_: return "Unknown"

## Get display name for skill
func _get_skill_name(skill: Enums.Skill) -> String:
	match skill:
		# GRIT-based
		Enums.Skill.MELEE: return "Melee"
		Enums.Skill.INTIMIDATION: return "Intimidation"
		# AGILITY-based
		Enums.Skill.RANGED: return "Ranged"
		Enums.Skill.DODGE: return "Dodge"
		Enums.Skill.STEALTH: return "Stealth"
		Enums.Skill.ENDURANCE: return "Endurance"
		Enums.Skill.THIEVERY: return "Thievery"
		Enums.Skill.ACROBATICS: return "Acrobatics"
		Enums.Skill.ATHLETICS: return "Athletics"
		# WILL-based
		Enums.Skill.CONCENTRATION: return "Concentration"
		Enums.Skill.RESIST: return "Resist"
		Enums.Skill.BRAVERY: return "Bravery"
		# SPEECH-based
		Enums.Skill.PERSUASION: return "Persuasion"
		Enums.Skill.DECEPTION: return "Deception"
		Enums.Skill.NEGOTIATION: return "Negotiation"
		# KNOWLEDGE-based
		Enums.Skill.ARCANA_LORE: return "Arcana Lore"
		Enums.Skill.HISTORY: return "History"
		Enums.Skill.INTUITION: return "Intuition"
		Enums.Skill.ENGINEERING: return "Engineering"
		Enums.Skill.INVESTIGATION: return "Investigation"
		Enums.Skill.PERCEPTION: return "Perception"
		Enums.Skill.RELIGION: return "Religion"
		Enums.Skill.NATURE: return "Nature"
		# VITALITY-based
		Enums.Skill.FIRST_AID: return "First Aid"
		Enums.Skill.HERBALISM: return "Herbalism"
		Enums.Skill.SURVIVAL: return "Survival"
		# CRAFTING-related
		Enums.Skill.ALCHEMY: return "Alchemy"
		Enums.Skill.SMITHING: return "Smithing"
		Enums.Skill.LOCKPICKING: return "Lockpicking"
		_: return "Unknown"

## Static factory method
static func spawn_rest_spot(parent: Node, pos: Vector3, spot_name: String = "Campfire") -> RestSpot:
	var spot := RestSpot.new()
	spot.display_name = spot_name
	spot.position = pos
	parent.add_child(spot)
	return spot
