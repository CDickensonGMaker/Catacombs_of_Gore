## rest_spot.gd - A safe spot where players can rest to heal and spend XP
class_name RestSpot
extends StaticBody3D

const FIREPLACE_TEXTURE := "res://assets/sprites/props/furniture/fireplace.png"

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
var tooltip_panel: PanelContainer = null
var tooltip_label: Label = null

## Stat descriptions for tooltips (matches game_menu.gd)
const STAT_DESCRIPTIONS := {
	Enums.Stat.GRIT: "Raw physical power. Increases melee damage, carry weight, and intimidation.",
	Enums.Stat.AGILITY: "Speed and reflexes. Improves dodge chance, attack speed, and movement.",
	Enums.Stat.WILL: "Mental fortitude. Boosts spell power, mana pool, and resistance to fear.",
	Enums.Stat.SPEECH: "Social ability. Affects persuasion, bartering prices, and NPC reactions.",
	Enums.Stat.KNOWLEDGE: "Learning and lore. Improves crafting, spell learning, and identifying items.",
	Enums.Stat.VITALITY: "Physical endurance. Increases health, stamina, and poison resistance.",
}

## Skill descriptions for tooltips (matches game_menu.gd)
const SKILL_DESCRIPTIONS := {
	# GRIT-based
	Enums.Skill.MELEE: "+5% melee damage per level. +1% crit chance per level.",
	Enums.Skill.INTIMIDATION: "+5% fear chance per level. Can force enemies to flee.",
	# AGILITY-based
	Enums.Skill.RANGED: "+5% ranged damage per level. +3% accuracy per level.",
	Enums.Skill.DODGE: "+3% dodge chance per level. Reduces incoming damage.",
	Enums.Skill.STEALTH: "-5% detection per level. +10% backstab damage per level.",
	Enums.Skill.ENDURANCE: "+2% max stamina per level. -5% fall damage. +5% jump height.",
	Enums.Skill.THIEVERY: "+5% pickpocket success per level. Better theft checks.",
	Enums.Skill.ATHLETICS: "+2% movement speed per level. -2% stamina cost per level.",
	# WILL-based
	Enums.Skill.CONCENTRATION: "+3% max mana per level. Reduces spell interrupt chance.",
	Enums.Skill.RESIST: "+3% magic resistance per level. Reduces curse duration.",
	Enums.Skill.BRAVERY: "+5% fear resistance per level. +2% damage vs undead.",
	# SPEECH-based
	Enums.Skill.PERSUASION: "+5% disposition per level. Unlocks dialogue options.",
	Enums.Skill.DECEPTION: "+5% bluff success per level. Better disguise checks.",
	Enums.Skill.NEGOTIATION: "+3% better prices per level. +5% quest rewards.",
	# KNOWLEDGE-based
	Enums.Skill.ARCANA_LORE: "+3% spell power per level. Better spell learning.",
	Enums.Skill.HISTORY: "+5% artifact identify chance. Unlocks lore dialogue.",
	Enums.Skill.INTUITION: "+5 enemy radar range per level. Detects ambushes and traps.",
	Enums.Skill.ENGINEERING: "+5% crafting success per level. +3% trap disarm.",
	Enums.Skill.INVESTIGATION: "Press NPCs for info. Find hidden clues and items.",
	Enums.Skill.RELIGION: "+5% temple blessing duration. +3% vs undead.",
	Enums.Skill.NATURE: "+5% animal calm chance. Better foraging yields.",
	# VITALITY-based
	Enums.Skill.FIRST_AID: "+10% healing item effectiveness per level.",
	Enums.Skill.HERBALISM: "+5% potion brewing success. +3% foraging yield.",
	Enums.Skill.SURVIVAL: "+3% weather resistance per level. Better camping rest.",
	# CRAFTING-related
	Enums.Skill.ALCHEMY: "+5% potion strength per level. +3% crafting success.",
	Enums.Skill.SMITHING: "+5% crafted item quality per level. Repair efficiency.",
	Enums.Skill.LOCKPICKING: "+1 lock difficulty per level. Silent lock attempts.",
}

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("rest_spots")

	# Add to specific groups for minimap icons
	match rest_type:
		RestSpotType.WILD_FIREPLACE:
			add_to_group("fireplaces")
			add_to_group("campfires")
		RestSpotType.TAVERN_FIREPLACE:
			add_to_group("fireplaces")
			add_to_group("taverns")
		RestSpotType.INN_BED:
			add_to_group("inns")

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

## UI components for slider-based rest
var rest_slider: HSlider
var rest_hours_label: Label
var rest_preview_label: Label
var rest_title_label: Label
var is_resting: bool = false
var rest_hours_total: float = 0.0
var rest_speed: float = 8.0  # Hours per second of animation

## Create the rest confirmation panel (slider-based)
func _create_rest_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "RestPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -180
	panel.offset_bottom = 180
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	# Dark gothic style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1)
	style.border_color = Color(0.3, 0.25, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	rest_title_label = Label.new()
	rest_title_label.name = "TitleLabel"
	rest_title_label.text = display_name.to_upper()
	rest_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rest_title_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	rest_title_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(rest_title_label)

	# Current time info
	var time_info := Label.new()
	time_info.name = "TimeInfo"
	time_info.text = "Current: %s - Day %d" % [GameManager.get_time_string(), GameManager.current_day]
	time_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_info.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	time_info.add_theme_font_size_override("font_size", 14)
	vbox.add_child(time_info)

	# Message
	var message := Label.new()
	if rest_type == RestSpotType.TAVERN_FIREPLACE or rest_type == RestSpotType.INN_BED:
		message.text = "Rest to restore HP, Mana, and Stamina.\nYou may also spend XP to level up here."
	else:
		message.text = "Rest to restore HP, Mana, and Stamina."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	message.add_theme_font_size_override("font_size", 12)
	vbox.add_child(message)

	# Hours label
	rest_hours_label = Label.new()
	rest_hours_label.name = "HoursLabel"
	rest_hours_label.text = "Rest for: 1 hour"
	rest_hours_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rest_hours_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	rest_hours_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(rest_hours_label)

	# Hour slider (1-24 hours)
	rest_slider = HSlider.new()
	rest_slider.name = "RestSlider"
	rest_slider.min_value = 1
	rest_slider.max_value = 24
	rest_slider.step = 1
	rest_slider.value = 8  # Default to 8 hours
	rest_slider.custom_minimum_size = Vector2(350, 30)
	rest_slider.value_changed.connect(_on_rest_slider_changed)
	rest_slider.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_rest_slider(rest_slider)
	vbox.add_child(rest_slider)

	# Preview label
	rest_preview_label = Label.new()
	rest_preview_label.name = "PreviewLabel"
	rest_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rest_preview_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.5))
	rest_preview_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(rest_preview_label)

	# Update preview
	_on_rest_slider_changed(8)

	# Bottom buttons
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 15)
	vbox.add_child(btn_container)

	# Rest button
	var rest_btn := Button.new()
	rest_btn.name = "RestBtn"
	rest_btn.text = "Rest"
	rest_btn.custom_minimum_size = Vector2(80, 35)
	rest_btn.pressed.connect(_on_rest_slider_confirmed)
	rest_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(rest_btn)
	btn_container.add_child(rest_btn)

	# Level Up button available at hearths (TAVERN_FIREPLACE) or inn beds
	# View Stats button available at wild fireplaces (view only, no upgrades)
	if rest_type == RestSpotType.TAVERN_FIREPLACE or rest_type == RestSpotType.INN_BED:
		var level_btn := Button.new()
		level_btn.text = "Level Up"
		level_btn.custom_minimum_size = Vector2(80, 35)
		level_btn.pressed.connect(_open_level_up_ui)
		level_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		_style_button(level_btn)
		btn_container.add_child(level_btn)
	else:
		# Wild fireplace - view stats only (no upgrades)
		var view_stats_btn := Button.new()
		view_stats_btn.text = "View Stats"
		view_stats_btn.custom_minimum_size = Vector2(80, 35)
		view_stats_btn.pressed.connect(_open_view_stats_ui)
		view_stats_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		_style_button(view_stats_btn)
		btn_container.add_child(view_stats_btn)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelBtn"
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 35)
	cancel_btn.pressed.connect(_close_rest_ui)
	cancel_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(cancel_btn)
	btn_container.add_child(cancel_btn)

	return panel


## Style the rest slider
func _style_rest_slider(s: HSlider) -> void:
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.15, 0.15, 0.18)
	slider_bg.set_corner_radius_all(4)

	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = Color(0.4, 0.35, 0.25)
	slider_fill.set_corner_radius_all(4)

	s.add_theme_stylebox_override("grabber_area", slider_fill)
	s.add_theme_stylebox_override("grabber_area_highlight", slider_fill)
	s.add_theme_stylebox_override("slider", slider_bg)


## Handle slider value change
func _on_rest_slider_changed(value: float) -> void:
	var hours := int(value)
	if hours == 1:
		rest_hours_label.text = "Rest for: 1 hour"
	else:
		rest_hours_label.text = "Rest for: %d hours" % hours

	# Update preview
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
		rest_preview_label.text = "Wake at: %s (Day %d)" % [time_str, future_day]
	else:
		rest_preview_label.text = "Wake at: %s" % time_str


## Handle rest button press - start animated rest
func _on_rest_slider_confirmed() -> void:
	var hours := rest_slider.value
	rest_hours_total = hours
	is_resting = true

	# Update UI to show resting state
	rest_title_label.text = "RESTING..."
	rest_slider.editable = false
	var rest_btn := rest_ui.get_node_or_null("VBoxContainer/HBoxContainer/RestBtn") as Button
	if rest_btn:
		rest_btn.disabled = true

	# Unpause to allow time to advance visually
	get_tree().paused = false


## Process resting animation and tooltip tracking
func _process(delta: float) -> void:
	# Update tooltip position if visible
	if is_instance_valid(tooltip_panel) and tooltip_panel.visible:
		_update_tooltip_position()

	if not is_resting or not rest_ui or not rest_ui.visible:
		return

	# Advance time at accelerated rate
	var hours_to_advance: float = delta * rest_speed
	rest_hours_total -= hours_to_advance

	if rest_hours_total <= 0:
		# Finish resting
		_finish_resting()
	else:
		# Continue resting - advance time
		GameManager.advance_time(hours_to_advance)

		# Update time display
		var time_info := rest_ui.get_node_or_null("VBoxContainer/TimeInfo") as Label
		if time_info:
			time_info.text = "Current: %s - Day %d" % [GameManager.get_time_string(), GameManager.current_day]

		# Update title with progress
		var original_hours := rest_slider.value
		var progress: float = 1.0 - (rest_hours_total / original_hours)
		rest_title_label.text = "RESTING... %d%%" % int(progress * 100)


## Finish the resting process
func _finish_resting() -> void:
	is_resting = false
	var hours_slept := rest_slider.value

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

	# Use RestManager for proper recovery calculation (time already advanced)
	var result := {
		"success": true,
		"hp_restored": 0,
		"mana_restored": 0,
		"stamina_restored": 0
	}

	# Calculate restoration manually since time is already advanced
	if GameManager.player_data:
		var player := GameManager.player_data
		var recovery_pct := 1.0  # Full recovery at rest spots

		var old_hp := player.current_hp
		var old_mana := player.current_mana

		player.current_hp = player.max_hp
		player.current_mana = player.max_mana
		player.current_stamina = player.max_stamina

		result.hp_restored = player.current_hp - old_hp
		result.mana_restored = player.current_mana - old_mana

		# Clear conditions
		player.conditions.clear()

	# Show notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Rested %d hours (+%d HP, +%d Mana). Day %d" % [
			int(hours_slept), result.hp_restored, result.mana_restored, GameManager.current_day
		])

	SaveManager.save_game(SaveManager.AUTOSAVE_EXIT_SLOT)
	AudioManager.play_ui_confirm()
	_close_rest_ui()

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

## Open view-only stats UI (for wild fireplaces)
func _open_view_stats_ui() -> void:
	if level_up_ui:
		return  # Already open

	# Hide rest panel while viewing stats
	if rest_ui:
		rest_ui.visible = false

	level_up_ui = _create_view_stats_panel()

	# Add to same canvas layer
	var canvas := get_node_or_null("RestUICanvas")
	if canvas:
		canvas.add_child(level_up_ui)


## Create the view-only stats panel (no upgrade buttons)
func _create_view_stats_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "ViewStatsPanel"
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

	# Header with title and XP (view only)
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(header)

	var title := Label.new()
	title.text = "CHARACTER STATS"
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

	# Info label about needing town for upgrades
	var info_label := Label.new()
	info_label.text = "(Visit a town to spend XP)"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	info_label.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(info_label)

	# Scroll container for stats and skills
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	main_vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(content_vbox)

	# Stats section (view only)
	var stats_label := Label.new()
	stats_label.text = "— STATS —"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	content_vbox.add_child(stats_label)

	for stat in Enums.Stat.values():
		var row := _create_stat_row_view_only(stat)
		content_vbox.add_child(row)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 15
	content_vbox.add_child(spacer)

	# Skills section (view only)
	var skills_label := Label.new()
	skills_label.text = "— SKILLS —"
	skills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skills_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	content_vbox.add_child(skills_label)

	for skill in Enums.Skill.values():
		var row := _create_skill_row_view_only(skill)
		content_vbox.add_child(row)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(100, 35)
	back_btn.pressed.connect(_close_level_up_ui)
	back_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(back_btn)
	main_vbox.add_child(back_btn)

	# Create tooltip panel (starts hidden)
	tooltip_panel = _create_tooltip_panel()
	panel.add_child(tooltip_panel)

	return panel


## Create a view-only row for a stat (no upgrade button)
func _create_stat_row_view_only(stat: Enums.Stat) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_STOP

	var char_data := GameManager.player_data

	# Stat name
	var name_label := Label.new()
	name_label.text = _get_stat_name(stat)
	name_label.custom_minimum_size.x = 100
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(name_label)

	# Connect hover events for tooltip
	var description: String = STAT_DESCRIPTIONS.get(stat, "No description available.")
	row.mouse_entered.connect(_on_stat_row_hover.bind(stat, description))
	row.mouse_exited.connect(_hide_tooltip)
	name_label.mouse_entered.connect(_on_stat_row_hover.bind(stat, description))
	name_label.mouse_exited.connect(_hide_tooltip)

	# Current value
	var current_value := char_data.get_stat(stat) if char_data else 3
	var value_label := Label.new()
	value_label.text = str(current_value)
	value_label.custom_minimum_size.x = 50
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	row.add_child(value_label)

	return row


## Create a view-only row for a skill (no upgrade button)
func _create_skill_row_view_only(skill: Enums.Skill) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_STOP

	var char_data := GameManager.player_data

	# Skill name
	var name_label := Label.new()
	name_label.text = _get_skill_name(skill)
	name_label.custom_minimum_size.x = 100
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(name_label)

	# Connect hover events for tooltip
	var description: String = SKILL_DESCRIPTIONS.get(skill, "No description available.")
	row.mouse_entered.connect(_on_skill_row_hover.bind(skill, description))
	row.mouse_exited.connect(_hide_tooltip)
	name_label.mouse_entered.connect(_on_skill_row_hover.bind(skill, description))
	name_label.mouse_exited.connect(_hide_tooltip)

	# Current value
	var current_value := char_data.get_skill(skill) if char_data else 0
	var value_label := Label.new()
	value_label.text = str(current_value)
	value_label.custom_minimum_size.x = 50
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	row.add_child(value_label)

	return row


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

	# Create tooltip panel (starts hidden)
	tooltip_panel = _create_tooltip_panel()
	panel.add_child(tooltip_panel)

	return panel


## Create the tooltip panel for hover info (follows mouse cursor)
func _create_tooltip_panel() -> PanelContainer:
	var tip := PanelContainer.new()
	tip.name = "TooltipPanel"
	tip.visible = false
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse
	tip.z_index = 100  # Above other elements
	tip.top_level = true  # Position relative to viewport, not parent
	tip.custom_minimum_size = Vector2(200, 0)  # Minimum width for readability

	# Dark tooltip style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	style.border_color = Color(0.5, 0.4, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(10)
	tip.add_theme_stylebox_override("panel", style)

	# Tooltip text
	tooltip_label = Label.new()
	tooltip_label.name = "TooltipText"
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.custom_minimum_size = Vector2(180, 0)
	tooltip_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	tooltip_label.add_theme_font_size_override("font_size", 13)
	tip.add_child(tooltip_label)

	return tip


## Show tooltip with text near mouse cursor
func _show_tooltip(text: String) -> void:
	if tooltip_label and tooltip_panel:
		tooltip_label.text = text
		tooltip_panel.visible = true
		_update_tooltip_position()


## Hide tooltip
func _hide_tooltip() -> void:
	if tooltip_panel:
		tooltip_panel.visible = false


## Update tooltip position to follow mouse cursor
func _update_tooltip_position() -> void:
	if not tooltip_panel or not tooltip_panel.visible:
		return

	var viewport: Viewport = get_viewport()
	if not viewport:
		return

	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	var tooltip_size: Vector2 = tooltip_panel.size

	# Offset from cursor (appear to bottom-right of cursor)
	var offset := Vector2(15, 15)
	var pos: Vector2 = mouse_pos + offset

	# Keep tooltip within viewport bounds
	if pos.x + tooltip_size.x > viewport_size.x:
		pos.x = mouse_pos.x - tooltip_size.x - 10  # Flip to left side
	if pos.y + tooltip_size.y > viewport_size.y:
		pos.y = mouse_pos.y - tooltip_size.y - 10  # Flip to top

	tooltip_panel.global_position = pos

## Create a row for a stat
func _create_stat_row(stat: Enums.Stat) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_STOP  # Capture mouse events

	var char_data := GameManager.player_data

	# Stat name (make it a button-like area for hover)
	var name_label := Label.new()
	name_label.text = _get_stat_name(stat)
	name_label.custom_minimum_size.x = 100
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(name_label)

	# Connect hover events for tooltip
	var description: String = STAT_DESCRIPTIONS.get(stat, "No description available.")
	row.mouse_entered.connect(_on_stat_row_hover.bind(stat, description))
	row.mouse_exited.connect(_hide_tooltip)
	name_label.mouse_entered.connect(_on_stat_row_hover.bind(stat, description))
	name_label.mouse_exited.connect(_hide_tooltip)

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
	row.mouse_filter = Control.MOUSE_FILTER_STOP  # Capture mouse events

	var char_data := GameManager.player_data

	# Skill name (make it a button-like area for hover)
	var name_label := Label.new()
	name_label.text = _get_skill_name(skill)
	name_label.custom_minimum_size.x = 100
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(name_label)

	# Connect hover events for tooltip
	var description: String = SKILL_DESCRIPTIONS.get(skill, "No description available.")
	row.mouse_entered.connect(_on_skill_row_hover.bind(skill, description))
	row.mouse_exited.connect(_hide_tooltip)
	name_label.mouse_entered.connect(_on_skill_row_hover.bind(skill, description))
	name_label.mouse_exited.connect(_hide_tooltip)

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
		tooltip_panel = null
		tooltip_label = null

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


## Handle stat row hover
func _on_stat_row_hover(_stat: Enums.Stat, description: String) -> void:
	_show_tooltip(description)


## Handle skill row hover
func _on_skill_row_hover(_skill: Enums.Skill, description: String) -> void:
	_show_tooltip(description)


## Static factory method
static func spawn_rest_spot(parent: Node, pos: Vector3, spot_name: String = "Campfire") -> RestSpot:
	var spot := RestSpot.new()
	spot.display_name = spot_name
	spot.position = pos
	parent.add_child(spot)
	return spot
