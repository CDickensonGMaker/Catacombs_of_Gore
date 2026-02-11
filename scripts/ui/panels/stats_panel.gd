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
	_update_character_info()
	_update_core_stats()
	_update_derived_stats()
	_update_skills()

func _update_character_info() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return

	if name_label:
		name_label.text = player.character_name if player.has_method("get") and "character_name" in player else "Unknown"
	if race_label:
		race_label.text = "Race: " + (player.race if "race" in player else "Human")
	if career_label:
		career_label.text = "Career: " + (player.career if "career" in player else "Adventurer")
	if level_label:
		level_label.text = "Level: %d" % (player.level if "level" in player else 1)

func _update_core_stats() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Get stats from player or use defaults
	var stats: Dictionary = player.stats if "stats" in player else {}

	if strength_label:
		strength_label.text = "Strength: %d" % stats.get("strength", 10)
	if agility_label:
		agility_label.text = "Agility: %d" % stats.get("agility", 10)
	if toughness_label:
		toughness_label.text = "Toughness: %d" % stats.get("toughness", 10)
	if intelligence_label:
		intelligence_label.text = "Intelligence: %d" % stats.get("intelligence", 10)
	if willpower_label:
		willpower_label.text = "Willpower: %d" % stats.get("willpower", 10)
	if fellowship_label:
		fellowship_label.text = "Fellowship: %d" % stats.get("fellowship", 10)

func _update_derived_stats() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return

	if health_label:
		var hp: int = player.current_health if "current_health" in player else 100
		var max_hp: int = player.max_health if "max_health" in player else 100
		health_label.text = "Health: %d / %d" % [hp, max_hp]

	if stamina_label:
		var sp: int = player.current_stamina if "current_stamina" in player else 100
		var max_sp: int = player.max_stamina if "max_stamina" in player else 100
		stamina_label.text = "Stamina: %d / %d" % [sp, max_sp]

	if mana_label:
		var mp: int = player.current_mana if "current_mana" in player else 50
		var max_mp: int = player.max_mana if "max_mana" in player else 50
		mana_label.text = "Mana: %d / %d" % [mp, max_mp]

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

	var player := get_tree().get_first_node_in_group("player")
	if not player or not "skills" in player:
		# Add some default skills for display
		skills_list.add_item("Melee Combat: 1")
		skills_list.add_item("Dodge: 1")
		skills_list.add_item("Block: 1")
		return

	var skills: Dictionary = player.skills
	for skill_name in skills:
		var skill_level: int = skills[skill_name]
		skills_list.add_item("%s: %d" % [skill_name, skill_level])
