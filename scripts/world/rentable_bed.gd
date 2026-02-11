## rentable_bed.gd - A bed that can be rented for rest (usually through innkeeper)
## Similar to RestSpot but typically requires prior payment
class_name RentableBed
extends StaticBody3D

@export var bed_name: String = "Bed"
@export var is_available: bool = false  # Set to true after paying innkeeper

## Interaction area
var interaction_area: Area3D

## Rest UI reference
var rest_ui: Control = null

## Level up UI reference
var level_up_ui: Control = null
var xp_label: Label = null

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("beds")

	_create_interaction_area()

## Create interaction area
func _create_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 2.0, 2.5)
	collision.shape = shape
	collision.position = Vector3(0, 1.0, 0)
	interaction_area.add_child(collision)

	add_child(interaction_area)

## Interaction interface
func interact(_interactor: Node) -> void:
	if not is_available:
		_show_notification("You need to rent a room first.")
		return

	_open_rest_ui()

func get_interaction_prompt() -> String:
	if not is_available:
		return "Rent room to use " + bed_name
	return "Rest in " + bed_name

## Make bed available (called after innkeeper payment)
func make_available() -> void:
	is_available = true

## Open the rest UI
func _open_rest_ui() -> void:
	if rest_ui:
		return

	get_tree().paused = true
	GameManager.enter_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	rest_ui = _create_rest_panel()

	var canvas := CanvasLayer.new()
	canvas.name = "BedRestUICanvas"
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	canvas.add_child(rest_ui)

## Create the rest panel
func _create_rest_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "RestPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -150
	panel.offset_right = 150
	panel.offset_top = -120
	panel.offset_bottom = 120
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06)
	style.border_color = Color(0.4, 0.3, 0.2)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "REST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	# Message
	var message := Label.new()
	message.text = "A comfortable bed awaits.\nWhat would you like to do?"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	vbox.add_child(message)

	# Buttons
	var btn_container := VBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_container)

	var rest_btn := Button.new()
	rest_btn.text = "Rest (Full Heal)"
	rest_btn.custom_minimum_size = Vector2(180, 35)
	rest_btn.pressed.connect(_on_rest_confirmed)
	rest_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(rest_btn)
	btn_container.add_child(rest_btn)

	var level_btn := Button.new()
	level_btn.text = "Level Up Skills"
	level_btn.custom_minimum_size = Vector2(180, 35)
	level_btn.pressed.connect(_open_level_up_ui)
	level_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(level_btn)
	btn_container.add_child(level_btn)

	var leave_btn := Button.new()
	leave_btn.text = "Get Up"
	leave_btn.custom_minimum_size = Vector2(180, 35)
	leave_btn.pressed.connect(_close_rest_ui)
	leave_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(leave_btn)
	btn_container.add_child(leave_btn)

	return panel

## Style a button with tavern theme
func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.12, 0.08)
	normal.border_color = Color(0.4, 0.3, 0.2)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.3, 0.2, 0.12)
	hover.border_color = Color(0.9, 0.7, 0.4)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(0.9, 0.7, 0.4))

## Handle rest confirmation
func _on_rest_confirmed() -> void:
	if GameManager.player_data:
		GameManager.player_data.current_hp = GameManager.player_data.max_hp
		GameManager.player_data.current_mana = GameManager.player_data.max_mana
		GameManager.player_data.current_stamina = GameManager.player_data.max_stamina
		GameManager.player_data.current_spell_slots = GameManager.player_data.max_spell_slots
		GameManager.player_data.conditions.clear()
		SaveManager.increment_rest_count()

	_show_notification("You feel well rested!")
	SaveManager.save_game(SaveManager.AUTOSAVE_EXIT_SLOT)
	AudioManager.play_ui_confirm()
	_close_rest_ui()

## Show notification
func _show_notification(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)

## Close the rest UI
func _close_rest_ui() -> void:
	if level_up_ui:
		level_up_ui.queue_free()
		level_up_ui = null
		xp_label = null

	if rest_ui:
		var canvas := rest_ui.get_parent()
		rest_ui.queue_free()
		if canvas:
			canvas.queue_free()
		rest_ui = null

	get_tree().paused = false
	GameManager.exit_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Open level up UI
func _open_level_up_ui() -> void:
	if level_up_ui:
		return

	if rest_ui:
		rest_ui.visible = false

	level_up_ui = _create_level_up_panel()

	var canvas := get_node_or_null("BedRestUICanvas")
	if canvas:
		canvas.add_child(level_up_ui)

## Create the level up panel (copied from RestSpot pattern)
func _create_level_up_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "LevelUpPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -220
	panel.offset_bottom = 220
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06)
	style.border_color = Color(0.4, 0.3, 0.2)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)

	# Header
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(header)

	var title := Label.new()
	title.text = "SPEND XP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	xp_label = Label.new()
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	xp_label.add_theme_font_size_override("font_size", 16)
	_update_xp_label()
	header.add_child(xp_label)

	# Scroll container
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
	stats_label.text = "- STATS -"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	content_vbox.add_child(stats_label)

	for stat in Enums.Stat.values():
		var row := _create_stat_row(stat)
		content_vbox.add_child(row)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 15
	content_vbox.add_child(spacer)

	# Skills section
	var skills_label := Label.new()
	skills_label.text = "- SKILLS -"
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

	var name_label := Label.new()
	name_label.text = _get_stat_name(stat)
	name_label.custom_minimum_size.x = 100
	name_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	row.add_child(name_label)

	var current_value := char_data.get_stat(stat) if char_data else 3
	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = str(current_value)
	value_label.custom_minimum_size.x = 30
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	row.add_child(value_label)

	var cost := char_data.get_stat_ip_cost(current_value) if char_data else 50
	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "(%d XP)" % cost if current_value < 15 else "(MAX)"
	cost_label.custom_minimum_size.x = 100
	cost_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	cost_label.add_theme_font_size_override("font_size", 12)
	row.add_child(cost_label)

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

	var name_label := Label.new()
	name_label.text = _get_skill_name(skill)
	name_label.custom_minimum_size.x = 100
	name_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	row.add_child(name_label)

	var current_value := char_data.get_skill(skill) if char_data else 0
	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = str(current_value)
	value_label.custom_minimum_size.x = 30
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	row.add_child(value_label)

	var next_level := current_value + 1
	var cost := Enums.get_skill_ip_cost(next_level) if current_value < 10 else 0
	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "(%d XP)" % cost if current_value < 10 else "(MAX)"
	cost_label.custom_minimum_size.x = 100
	cost_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	cost_label.add_theme_font_size_override("font_size", 12)
	row.add_child(cost_label)

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

## Refresh all upgrade buttons
func _refresh_all_buttons() -> void:
	if not level_up_ui:
		return

	var char_data := GameManager.player_data
	if not char_data:
		return

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
					var cost_str := cost_text.replace("(", "").replace(" XP)", "")
					var cost := int(cost_str) if cost_str.is_valid_int() else 99999
					btn.disabled = char_data.improvement_points < cost

## Close level up UI
func _close_level_up_ui() -> void:
	if level_up_ui:
		level_up_ui.queue_free()
		level_up_ui = null
		xp_label = null

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
		Enums.Skill.MELEE: return "Melee"
		Enums.Skill.RANGED: return "Ranged"
		Enums.Skill.DODGE: return "Dodge"
		Enums.Skill.STEALTH: return "Stealth"
		Enums.Skill.ARCANA_LORE: return "Arcana"
		Enums.Skill.FIRST_AID: return "First Aid"
		Enums.Skill.ENDURANCE: return "Endurance"
		Enums.Skill.ATHLETICS: return "Athletics"
		Enums.Skill.PERCEPTION: return "Perception"
		Enums.Skill.INTIMIDATION: return "Intimidation"
		Enums.Skill.PERSUASION: return "Persuasion"
		Enums.Skill.DECEPTION: return "Deception"
		Enums.Skill.LOCKPICKING: return "Lockpicking"
		Enums.Skill.ALCHEMY: return "Alchemy"
		Enums.Skill.SMITHING: return "Smithing"
		Enums.Skill.SURVIVAL: return "Survival"
		Enums.Skill.HISTORY: return "History"
		Enums.Skill.RELIGION: return "Religion"
		Enums.Skill.NATURE: return "Nature"
		Enums.Skill.INVESTIGATION: return "Investigation"
		Enums.Skill.ACROBATICS: return "Acrobatics"
		Enums.Skill.BRAVERY: return "Bravery"
		_: return "Unknown"

## Static factory method
static func spawn_bed(parent: Node, pos: Vector3, name: String = "Bed", available: bool = false) -> RentableBed:
	var bed := RentableBed.new()
	bed.bed_name = name
	bed.position = pos
	bed.is_available = available
	parent.add_child(bed)
	return bed
