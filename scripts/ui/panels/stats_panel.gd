## stats_panel.gd - Character stats display panel
class_name StatsPanel
extends Control

## Character info labels
@export var name_label: Label
@export var race_label: Label
@export var career_label: Label
@export var level_label: Label

## Core stats labels
@export var strength_label: Label
@export var agility_label: Label
@export var toughness_label: Label
@export var intelligence_label: Label
@export var willpower_label: Label
@export var fellowship_label: Label

## Derived stats labels
@export var health_label: Label
@export var stamina_label: Label
@export var mana_label: Label
@export var armor_label: Label
@export var damage_label: Label

## Skills list
@export var skills_list: ItemList

func _ready() -> void:
	refresh()

func refresh() -> void:
	# DEBUG: Print what we're reading
	if GameManager.player_data:
		print("STATS PANEL REFRESH - Will: %d, Knowledge: %d, Arcana Lore: %d" % [
			GameManager.player_data.will,
			GameManager.player_data.knowledge,
			GameManager.player_data.get_skill(Enums.Skill.ARCANA_LORE)
		])
	else:
		print("STATS PANEL REFRESH - No player_data!")

	_update_character_info()
	_update_core_stats()
	_update_derived_stats()
	_update_skills()

func _update_character_info() -> void:
	var char_data: CharacterData = GameManager.player_data
	if not char_data:
		return

	if name_label:
		name_label.text = char_data.character_name
	if race_label:
		race_label.text = "Race: " + Enums.Race.keys()[char_data.race]
	if career_label:
		career_label.text = "Career: " + Enums.Career.keys()[char_data.career]
	if level_label:
		level_label.text = "Level: %d" % char_data.level

func _update_core_stats() -> void:
	var char_data: CharacterData = GameManager.player_data
	if not char_data:
		return

	# Use actual CharacterData attributes
	if strength_label:
		strength_label.text = "Grit: %d" % char_data.grit
	if agility_label:
		agility_label.text = "Agility: %d" % char_data.agility
	if toughness_label:
		toughness_label.text = "Vitality: %d" % char_data.vitality
	if intelligence_label:
		intelligence_label.text = "Knowledge: %d" % char_data.knowledge
	if willpower_label:
		willpower_label.text = "Will: %d" % char_data.will
	if fellowship_label:
		fellowship_label.text = "Speech: %d" % char_data.speech

func _update_derived_stats() -> void:
	var char_data: CharacterData = GameManager.player_data
	if not char_data:
		return

	if health_label:
		health_label.text = "Health: %d / %d" % [char_data.current_hp, char_data.max_hp]

	if stamina_label:
		stamina_label.text = "Stamina: %d / %d" % [char_data.current_stamina, char_data.max_stamina]

	if mana_label:
		mana_label.text = "Mana: %d / %d" % [char_data.current_mana, char_data.max_mana]

	if armor_label:
		var armor: int = _calculate_total_armor()
		armor_label.text = "Armor: %d" % armor

	if damage_label:
		var dmg := _get_weapon_damage()
		damage_label.text = "Damage: %s" % dmg

func _calculate_total_armor() -> int:
	var total: int = 0

	# Check equipped armor pieces
	var equipment := InventoryManager.equipment
	for slot in ["head", "body", "hands", "legs", "feet"]:
		var item: Dictionary = equipment.get(slot, {})
		if not item.is_empty() and InventoryManager.armor_database.has(item.item_id):
			var armor: ArmorData = InventoryManager.armor_database[item.item_id]
			var quality: Enums.ItemQuality = item.get("quality", Enums.ItemQuality.AVERAGE)
			total += armor.get_armor_value(quality)

	return total

func _get_weapon_damage() -> String:
	var weapon_slot: Dictionary = InventoryManager.equipment.get("main_hand", {})
	if weapon_slot.is_empty():
		return "1-3 (Unarmed)"

	var item_id: String = weapon_slot.item_id
	if InventoryManager.weapon_database.has(item_id):
		var weapon: WeaponData = InventoryManager.weapon_database[item_id]
		return weapon.get_damage_string()

	return "???"

func _update_skills() -> void:
	if not skills_list:
		return

	skills_list.clear()

	var char_data: CharacterData = GameManager.player_data
	if not char_data:
		return

	# Display all skills with level > 0
	for skill_enum in Enums.Skill.values():
		var skill_level: int = char_data.get_skill(skill_enum)
		if skill_level > 0:
			var skill_name: String = Enums.Skill.keys()[skill_enum].capitalize().replace("_", " ")
			skills_list.add_item("%s: %d" % [skill_name, skill_level])
