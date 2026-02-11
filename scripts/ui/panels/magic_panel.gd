## magic_panel.gd - Spell management and quick slot assignment
class_name MagicPanel
extends Control

## Spell list
@export var spell_list: ItemList
@export var spell_name_label: Label
@export var spell_description_label: RichTextLabel
@export var spell_cost_label: Label
@export var spell_school_label: Label

## Quick slots display
@export var quick_slot_1_label: Label
@export var quick_slot_2_label: Label
@export var quick_slot_3_label: Label
@export var quick_slot_4_label: Label

## Buttons
@export var assign_slot_1_button: Button
@export var assign_slot_2_button: Button
@export var assign_slot_3_button: Button
@export var assign_slot_4_button: Button

## State
var known_spells: Array = []
var selected_index: int = -1

func _ready() -> void:
	_connect_buttons()
	refresh()

func _connect_buttons() -> void:
	if spell_list:
		spell_list.item_selected.connect(_on_spell_selected)

	if assign_slot_1_button:
		assign_slot_1_button.pressed.connect(func(): _assign_to_slot(0))
	if assign_slot_2_button:
		assign_slot_2_button.pressed.connect(func(): _assign_to_slot(1))
	if assign_slot_3_button:
		assign_slot_3_button.pressed.connect(func(): _assign_to_slot(2))
	if assign_slot_4_button:
		assign_slot_4_button.pressed.connect(func(): _assign_to_slot(3))

func refresh() -> void:
	_load_known_spells()
	_refresh_spell_list()
	_update_quick_slots_display()

func _load_known_spells() -> void:
	known_spells.clear()

	# Get player's known spells
	var player := get_tree().get_first_node_in_group("player")
	if player and "known_spells" in player:
		known_spells = player.known_spells.duplicate()
	else:
		# Load from spell database as fallback (show all available spells)
		var spell_dir := "res://data/spells/"
		if DirAccess.dir_exists_absolute(spell_dir):
			var dir := DirAccess.open(spell_dir)
			if dir:
				dir.list_dir_begin()
				var file_name := dir.get_next()
				while file_name != "":
					if file_name.ends_with(".tres") or file_name.ends_with(".res"):
						var spell_path := spell_dir + file_name
						var spell := load(spell_path)
						if spell:
							known_spells.append(spell)
					file_name = dir.get_next()

func _refresh_spell_list() -> void:
	if not spell_list:
		return

	spell_list.clear()
	selected_index = -1

	for spell in known_spells:
		var spell_name: String = spell.spell_name if "spell_name" in spell else spell.get("name", "Unknown Spell")
		spell_list.add_item(spell_name)

	if known_spells.is_empty():
		spell_list.add_item("No spells known")

	_clear_spell_details()

func _on_spell_selected(index: int) -> void:
	if index < 0 or index >= known_spells.size():
		_clear_spell_details()
		return

	selected_index = index
	_display_spell_details(known_spells[index])
	_update_assign_buttons(true)

func _display_spell_details(spell) -> void:
	if spell_name_label:
		spell_name_label.text = spell.spell_name if "spell_name" in spell else "Unknown"

	if spell_description_label:
		spell_description_label.text = spell.description if "description" in spell else "No description."

	if spell_cost_label:
		var mana_cost: int = spell.mana_cost if "mana_cost" in spell else 0
		spell_cost_label.text = "Mana Cost: %d" % mana_cost

	if spell_school_label:
		var school: String = spell.school if "school" in spell else "Unknown"
		spell_school_label.text = "School: %s" % school

func _clear_spell_details() -> void:
	if spell_name_label:
		spell_name_label.text = "Select a Spell"
	if spell_description_label:
		spell_description_label.text = ""
	if spell_cost_label:
		spell_cost_label.text = ""
	if spell_school_label:
		spell_school_label.text = ""

	_update_assign_buttons(false)

func _update_assign_buttons(enabled: bool) -> void:
	if assign_slot_1_button:
		assign_slot_1_button.disabled = not enabled
	if assign_slot_2_button:
		assign_slot_2_button.disabled = not enabled
	if assign_slot_3_button:
		assign_slot_3_button.disabled = not enabled
	if assign_slot_4_button:
		assign_slot_4_button.disabled = not enabled

func _assign_to_slot(slot_index: int) -> void:
	if selected_index < 0 or selected_index >= known_spells.size():
		return

	var spell = known_spells[selected_index]
	var spell_id: String = spell.id if "id" in spell else ""

	if spell_id.is_empty():
		return

	# Store in InventoryManager's spell slots (or create spell slot system)
	if InventoryManager.has_method("set_spell_slot"):
		InventoryManager.set_spell_slot(slot_index, spell_id)
	else:
		# Fallback: store in player
		var player := get_tree().get_first_node_in_group("player")
		if player:
			if not "spell_slots" in player:
				player.set("spell_slots", ["", "", "", ""])
			player.spell_slots[slot_index] = spell_id

	AudioManager.play_ui_confirm()
	_update_quick_slots_display()

func _update_quick_slots_display() -> void:
	var slot_labels := [quick_slot_1_label, quick_slot_2_label, quick_slot_3_label, quick_slot_4_label]

	for i in range(4):
		if not slot_labels[i]:
			continue

		var spell_id := _get_spell_slot(i)
		if spell_id.is_empty():
			slot_labels[i].text = "%d: Empty" % (i + 1)
		else:
			var spell_name := _get_spell_name(spell_id)
			slot_labels[i].text = "%d: %s" % [i + 1, spell_name]

func _get_spell_slot(slot_index: int) -> String:
	if InventoryManager.has_method("get_spell_slot"):
		return InventoryManager.get_spell_slot(slot_index)

	var player := get_tree().get_first_node_in_group("player")
	if player and "spell_slots" in player:
		var slots: Array = player.spell_slots
		if slot_index < slots.size():
			var slot_value: String = slots[slot_index]
			return slot_value

	return ""

func _get_spell_name(spell_id: String) -> String:
	for spell in known_spells:
		var id: String = spell.id if "id" in spell else ""
		if id == spell_id:
			return spell.spell_name if "spell_name" in spell else spell_id

	return spell_id
