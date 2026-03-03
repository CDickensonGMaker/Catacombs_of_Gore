## spell_maker_ui.gd - UI for creating custom spells at spell making altars
class_name SpellMakerUI
extends CanvasLayer

signal closed

## Reference to the altar that opened this UI
var altar: Node = null

## UI components
var root_panel: PanelContainer
var title_label: Label
var effects_library_list: ItemList
var spell_effects_list: ItemList
var add_effect_button: Button
var remove_effect_button: Button
var magnitude_slider: HSlider
var magnitude_label: Label
var duration_slider: HSlider
var duration_label: Label
var delivery_option: OptionButton
var spell_name_edit: LineEdit
var cost_label: Label
var requirements_label: Label
var preview_label: Label
var create_button: Button
var close_button: Button

## Current spell configuration
var current_effects: Array[Dictionary] = []  # {effect_id, magnitude, duration, delivery}
var selected_library_effect: SpellEffectData = null
var selected_spell_effect_index: int = -1
var current_delivery: SpellEffectData.DeliveryType = SpellEffectData.DeliveryType.PROJECTILE

## Style colors
const COL_PURPLE := Color(0.5, 0.3, 0.8)
const COL_DARK_PURPLE := Color(0.15, 0.1, 0.2, 0.95)
const COL_GOLD := Color(1.0, 0.85, 0.3)
const COL_RED := Color(0.8, 0.4, 0.4)
const COL_GREEN := Color(0.4, 0.8, 0.4)

func _ready() -> void:
	_create_ui()
	_populate_effects_library()
	_update_preview()

func _create_ui() -> void:
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Main panel
	root_panel = PanelContainer.new()
	root_panel.anchors_preset = Control.PRESET_CENTER
	root_panel.anchor_left = 0.5
	root_panel.anchor_right = 0.5
	root_panel.anchor_top = 0.5
	root_panel.anchor_bottom = 0.5
	root_panel.offset_left = -400
	root_panel.offset_right = 400
	root_panel.offset_top = -300
	root_panel.offset_bottom = 300
	add_child(root_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = COL_DARK_PURPLE
	style.border_color = COL_PURPLE
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	root_panel.add_theme_stylebox_override("panel", style)

	# Main VBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	root_panel.add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "SPELL MAKER"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", COL_PURPLE)
	vbox.add_child(title_label)

	# Main content HBox (library + spell effects + config)
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 12)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_hbox)

	# Left panel - Effects Library
	var library_vbox := VBoxContainer.new()
	library_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(library_vbox)

	var library_label := Label.new()
	library_label.text = "Effects Library"
	library_label.add_theme_font_size_override("font_size", 14)
	library_vbox.add_child(library_label)

	effects_library_list = ItemList.new()
	effects_library_list.custom_minimum_size = Vector2(180, 200)
	effects_library_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effects_library_list.item_selected.connect(_on_library_effect_selected)
	library_vbox.add_child(effects_library_list)

	add_effect_button = Button.new()
	add_effect_button.text = "Add Effect >>"
	add_effect_button.disabled = true
	add_effect_button.pressed.connect(_on_add_effect_pressed)
	library_vbox.add_child(add_effect_button)

	# Center panel - Your Spell Effects
	var spell_vbox := VBoxContainer.new()
	spell_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(spell_vbox)

	var spell_label := Label.new()
	spell_label.text = "Your Spell (Max %d Effects)" % SpellCreator.MAX_EFFECTS_PER_SPELL
	spell_label.add_theme_font_size_override("font_size", 14)
	spell_vbox.add_child(spell_label)

	spell_effects_list = ItemList.new()
	spell_effects_list.custom_minimum_size = Vector2(200, 200)
	spell_effects_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spell_effects_list.item_selected.connect(_on_spell_effect_selected)
	spell_vbox.add_child(spell_effects_list)

	remove_effect_button = Button.new()
	remove_effect_button.text = "Remove Effect"
	remove_effect_button.disabled = true
	remove_effect_button.pressed.connect(_on_remove_effect_pressed)
	spell_vbox.add_child(remove_effect_button)

	# Right panel - Configuration
	var config_vbox := VBoxContainer.new()
	config_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_vbox.add_theme_constant_override("separation", 8)
	content_hbox.add_child(config_vbox)

	var config_label := Label.new()
	config_label.text = "Effect Settings"
	config_label.add_theme_font_size_override("font_size", 14)
	config_vbox.add_child(config_label)

	# Magnitude slider
	var mag_hbox := HBoxContainer.new()
	config_vbox.add_child(mag_hbox)
	var mag_text := Label.new()
	mag_text.text = "Magnitude:"
	mag_text.custom_minimum_size = Vector2(80, 0)
	mag_hbox.add_child(mag_text)
	magnitude_slider = HSlider.new()
	magnitude_slider.min_value = 5
	magnitude_slider.max_value = 50
	magnitude_slider.value = 10
	magnitude_slider.custom_minimum_size = Vector2(100, 0)
	magnitude_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	magnitude_slider.value_changed.connect(_on_magnitude_changed)
	mag_hbox.add_child(magnitude_slider)
	magnitude_label = Label.new()
	magnitude_label.text = "10"
	magnitude_label.custom_minimum_size = Vector2(30, 0)
	mag_hbox.add_child(magnitude_label)

	# Duration slider
	var dur_hbox := HBoxContainer.new()
	config_vbox.add_child(dur_hbox)
	var dur_text := Label.new()
	dur_text.text = "Duration:"
	dur_text.custom_minimum_size = Vector2(80, 0)
	dur_hbox.add_child(dur_text)
	duration_slider = HSlider.new()
	duration_slider.min_value = 0
	duration_slider.max_value = 30
	duration_slider.value = 5
	duration_slider.custom_minimum_size = Vector2(100, 0)
	duration_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration_slider.value_changed.connect(_on_duration_changed)
	dur_hbox.add_child(duration_slider)
	duration_label = Label.new()
	duration_label.text = "5s"
	duration_label.custom_minimum_size = Vector2(30, 0)
	dur_hbox.add_child(duration_label)

	# Delivery type
	var delivery_hbox := HBoxContainer.new()
	config_vbox.add_child(delivery_hbox)
	var delivery_text := Label.new()
	delivery_text.text = "Delivery:"
	delivery_text.custom_minimum_size = Vector2(80, 0)
	delivery_hbox.add_child(delivery_text)
	delivery_option = OptionButton.new()
	delivery_option.add_item("Self", SpellEffectData.DeliveryType.SELF)
	delivery_option.add_item("Touch", SpellEffectData.DeliveryType.TOUCH)
	delivery_option.add_item("Projectile", SpellEffectData.DeliveryType.PROJECTILE)
	delivery_option.add_item("Area (AOE)", SpellEffectData.DeliveryType.AOE)
	delivery_option.select(2)  # Default to Projectile
	delivery_option.item_selected.connect(_on_delivery_changed)
	delivery_hbox.add_child(delivery_option)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	config_vbox.add_child(spacer)

	# Preview panel
	var preview_panel := PanelContainer.new()
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	preview_style.set_border_width_all(1)
	preview_style.border_color = Color(0.4, 0.3, 0.5)
	preview_style.content_margin_left = 8
	preview_style.content_margin_right = 8
	preview_style.content_margin_top = 6
	preview_style.content_margin_bottom = 6
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	vbox.add_child(preview_panel)

	var preview_vbox := VBoxContainer.new()
	preview_vbox.add_theme_constant_override("separation", 4)
	preview_panel.add_child(preview_vbox)

	preview_label = Label.new()
	preview_label.text = "Add effects to create your spell"
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_vbox.add_child(preview_label)

	cost_label = Label.new()
	cost_label.text = "Mana Cost: 0"
	cost_label.add_theme_color_override("font_color", COL_GOLD)
	preview_vbox.add_child(cost_label)

	requirements_label = Label.new()
	requirements_label.text = ""
	requirements_label.add_theme_color_override("font_color", COL_RED)
	preview_vbox.add_child(requirements_label)

	# Spell name input
	var name_hbox := HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(name_hbox)

	var name_label := Label.new()
	name_label.text = "Spell Name:"
	name_hbox.add_child(name_label)

	spell_name_edit = LineEdit.new()
	spell_name_edit.placeholder_text = "Enter spell name..."
	spell_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spell_name_edit.text_changed.connect(_on_name_changed)
	name_hbox.add_child(spell_name_edit)

	# Button row
	var button_hbox := HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 16)
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_hbox)

	create_button = Button.new()
	create_button.text = "Create Spell"
	create_button.custom_minimum_size = Vector2(140, 40)
	create_button.disabled = true
	create_button.pressed.connect(_on_create_pressed)
	button_hbox.add_child(create_button)

	close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(100, 40)
	close_button.pressed.connect(_on_close_pressed)
	button_hbox.add_child(close_button)

func _populate_effects_library() -> void:
	effects_library_list.clear()

	var available_effects: Array[SpellEffectData] = SpellCreator.get_available_effects()

	for effect in available_effects:
		var idx: int = effects_library_list.add_item(effect.display_name)
		effects_library_list.set_item_metadata(idx, effect.id)
		effects_library_list.set_item_tooltip(idx, effect.description)

func _refresh_spell_effects_list() -> void:
	spell_effects_list.clear()

	for i in range(current_effects.size()):
		var config: Dictionary = current_effects[i]
		var effect: SpellEffectData = SpellCreator.effect_database.get(config.effect_id)
		if effect:
			var text: String = "%d. %s (Mag: %d" % [i + 1, effect.display_name, config.magnitude]
			if effect.has_duration():
				text += ", Dur: %.1fs" % config.duration
			text += ")"
			var idx: int = spell_effects_list.add_item(text)
			spell_effects_list.set_item_metadata(idx, i)

func _update_preview() -> void:
	if current_effects.is_empty():
		preview_label.text = "Add effects to create your spell"
		cost_label.text = "Mana Cost: 0"
		requirements_label.text = ""
		create_button.disabled = true
		return

	# Build description
	var desc_parts: Array[String] = []
	for config in current_effects:
		var effect: SpellEffectData = SpellCreator.effect_database.get(config.effect_id)
		if effect:
			desc_parts.append(effect.get_effect_string(config.magnitude, config.duration))

	preview_label.text = ". ".join(desc_parts) + "."

	# Calculate cost
	var total_cost: int = SpellCreator.calculate_spell_cost(current_effects)
	cost_label.text = "Mana Cost: %d" % total_cost

	# Check if can create
	var can_create: bool = true
	var issues: Array[String] = []

	if spell_name_edit.text.strip_edges().is_empty():
		can_create = false
		issues.append("Enter a spell name")

	if current_effects.is_empty():
		can_create = false
		issues.append("Add at least one effect")

	# Validate each effect
	for config in current_effects:
		var validation: Dictionary = SpellCreator.validate_effect_config(config)
		if not validation.valid:
			can_create = false
			issues.append(validation.reason)

	if issues.is_empty():
		requirements_label.text = ""
		requirements_label.add_theme_color_override("font_color", COL_GREEN)
		requirements_label.text = "Ready to create!"
	else:
		requirements_label.add_theme_color_override("font_color", COL_RED)
		requirements_label.text = "; ".join(issues)

	create_button.disabled = not can_create

func _update_sliders_for_effect(effect: SpellEffectData) -> void:
	if not effect:
		magnitude_slider.editable = false
		duration_slider.editable = false
		return

	magnitude_slider.editable = true
	magnitude_slider.min_value = effect.base_magnitude
	magnitude_slider.max_value = effect.max_magnitude
	magnitude_slider.value = effect.base_magnitude
	magnitude_label.text = str(int(magnitude_slider.value))

	if effect.has_duration():
		duration_slider.editable = true
		duration_slider.min_value = 1
		duration_slider.max_value = effect.max_duration
		duration_slider.value = effect.base_duration
		duration_label.text = "%.1fs" % duration_slider.value
	else:
		duration_slider.editable = false
		duration_slider.value = 0
		duration_label.text = "N/A"

	# Update delivery options based on allowed delivery types
	for i in range(delivery_option.item_count):
		var delivery_type: int = delivery_option.get_item_id(i)
		var allowed: bool = effect.is_delivery_allowed(delivery_type)
		delivery_option.set_item_disabled(i, not allowed)

func _on_library_effect_selected(index: int) -> void:
	var effect_id: String = effects_library_list.get_item_metadata(index)
	selected_library_effect = SpellCreator.effect_database.get(effect_id)
	add_effect_button.disabled = (selected_library_effect == null) or (current_effects.size() >= SpellCreator.MAX_EFFECTS_PER_SPELL)
	_update_sliders_for_effect(selected_library_effect)

func _on_spell_effect_selected(index: int) -> void:
	selected_spell_effect_index = spell_effects_list.get_item_metadata(index)
	remove_effect_button.disabled = false

	# Load the selected effect's settings into sliders
	if selected_spell_effect_index >= 0 and selected_spell_effect_index < current_effects.size():
		var config: Dictionary = current_effects[selected_spell_effect_index]
		var effect: SpellEffectData = SpellCreator.effect_database.get(config.effect_id)
		if effect:
			_update_sliders_for_effect(effect)
			magnitude_slider.value = config.magnitude
			duration_slider.value = config.duration
			# Find delivery option index
			for i in range(delivery_option.item_count):
				if delivery_option.get_item_id(i) == config.delivery:
					delivery_option.select(i)
					break

func _on_add_effect_pressed() -> void:
	if not selected_library_effect:
		return
	if current_effects.size() >= SpellCreator.MAX_EFFECTS_PER_SPELL:
		return

	# Find first allowed delivery type
	var delivery: int = SpellEffectData.DeliveryType.PROJECTILE
	for d in [SpellEffectData.DeliveryType.PROJECTILE, SpellEffectData.DeliveryType.TOUCH, SpellEffectData.DeliveryType.SELF, SpellEffectData.DeliveryType.AOE]:
		if selected_library_effect.is_delivery_allowed(d):
			delivery = d
			break

	var config: Dictionary = {
		"effect_id": selected_library_effect.id,
		"magnitude": int(magnitude_slider.value),
		"duration": duration_slider.value,
		"delivery": delivery,
		"aoe_radius": 5.0 if delivery == SpellEffectData.DeliveryType.AOE else 0.0
	}

	current_effects.append(config)
	_refresh_spell_effects_list()
	_update_preview()

	# Disable add if at max
	add_effect_button.disabled = current_effects.size() >= SpellCreator.MAX_EFFECTS_PER_SPELL

func _on_remove_effect_pressed() -> void:
	if selected_spell_effect_index < 0 or selected_spell_effect_index >= current_effects.size():
		return

	current_effects.remove_at(selected_spell_effect_index)
	selected_spell_effect_index = -1
	remove_effect_button.disabled = true
	_refresh_spell_effects_list()
	_update_preview()

	# Re-enable add button
	add_effect_button.disabled = selected_library_effect == null

func _on_magnitude_changed(value: float) -> void:
	magnitude_label.text = str(int(value))

	# Update selected spell effect if one is selected
	if selected_spell_effect_index >= 0 and selected_spell_effect_index < current_effects.size():
		current_effects[selected_spell_effect_index].magnitude = int(value)
		_refresh_spell_effects_list()
		_update_preview()

func _on_duration_changed(value: float) -> void:
	duration_label.text = "%.1fs" % value

	# Update selected spell effect if one is selected
	if selected_spell_effect_index >= 0 and selected_spell_effect_index < current_effects.size():
		current_effects[selected_spell_effect_index].duration = value
		_refresh_spell_effects_list()
		_update_preview()

func _on_delivery_changed(index: int) -> void:
	var delivery: int = delivery_option.get_item_id(index)
	current_delivery = delivery as SpellEffectData.DeliveryType

	# Update selected spell effect if one is selected
	if selected_spell_effect_index >= 0 and selected_spell_effect_index < current_effects.size():
		current_effects[selected_spell_effect_index].delivery = delivery
		current_effects[selected_spell_effect_index].aoe_radius = 5.0 if delivery == SpellEffectData.DeliveryType.AOE else 0.0
		_refresh_spell_effects_list()
		_update_preview()

func _on_name_changed(_new_text: String) -> void:
	_update_preview()

func _on_create_pressed() -> void:
	var spell_name: String = spell_name_edit.text.strip_edges()
	if spell_name.is_empty():
		return
	if current_effects.is_empty():
		return

	# Determine primary delivery from first effect
	var primary_delivery: SpellEffectData.DeliveryType = current_effects[0].delivery as SpellEffectData.DeliveryType

	var spell: CustomSpellData = SpellCreator.create_spell(spell_name, current_effects, primary_delivery)

	if spell:
		# Show success notification
		var hud: Node = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Spell '%s' created! (Cost: %d mana)" % [spell.display_name, spell.mana_cost])

		# Add to player's spellbook via SpellCaster
		var player: Node = get_tree().get_first_node_in_group("player")
		if player:
			var spell_caster: Node = player.get_node_or_null("SpellCaster")
			if spell_caster and spell_caster.has_method("learn_spell"):
				spell_caster.learn_spell(spell)

		# Clear the form for another spell
		current_effects.clear()
		spell_name_edit.text = ""
		selected_spell_effect_index = -1
		_refresh_spell_effects_list()
		_update_preview()

func _on_close_pressed() -> void:
	close()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	_populate_effects_library()
	_update_preview()

func close() -> void:
	if altar and altar.has_method("close"):
		altar.close()
	else:
		closed.emit()
		queue_free()
