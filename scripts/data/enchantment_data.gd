## enchantment_data.gd - Resource class for enchantment definitions
@tool
class_name EnchantmentData
extends Resource

## Enchantment effect types
enum EnchantmentType {
	DAMAGE_BONUS,      # +X damage of type
	RESISTANCE,        # +X% resistance
	STAT_BONUS,        # +X to stat
	CONDITION_ON_HIT,  # Chance to inflict condition
	LIFESTEAL,         # % damage healed
	ARMOR_BONUS,       # +X armor
	CRIT_BONUS,        # +X% crit
	MANA_BONUS,        # +X max mana
	STAMINA_BONUS,     # +X max stamina
	HEALTH_BONUS       # +X max health
}

## Unique identifier
@export var id: String = ""

## Display name shown to player
@export var display_name: String = ""

## Description of the effect
@export_multiline var description: String = ""

@export_group("Effect")
## Type of enchantment effect
@export var enchantment_type: EnchantmentType = EnchantmentType.DAMAGE_BONUS

## Numerical value of the effect (damage, resistance %, stat bonus, etc.)
@export var effect_value: int = 5

## For damage/resistance enchantments - what damage type
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL

## For stat bonus enchantments - which stat to boost
@export var stat_type: Enums.Stat = Enums.Stat.GRIT

## For condition-on-hit enchantments - which condition
@export var inflicts_condition: Enums.Condition = Enums.Condition.NONE

## Chance to proc condition (0.0 - 1.0)
@export var proc_chance: float = 0.2

## Duration of inflicted condition
@export var condition_duration: float = 5.0

@export_group("Requirements")
## Minimum soulstone tier required (1-5)
@export var min_soulstone_tier: int = 1

## Required Arcana Lore skill level
@export var required_arcana: int = 0

## Gold cost to apply this enchantment
@export var gold_cost: int = 100

## Which equipment slots can have this enchantment
## Use "weapon", "armor", "ring", "amulet", "shield"
@export var applicable_slots: Array[String] = ["weapon"]

@export_group("Visuals")
## Icon texture path
@export var icon_path: String = ""

## Particle color for enchantment glow
@export var glow_color: Color = Color(0.8, 0.8, 1.0, 1.0)

## Check if enchantment can be applied to a given slot
func can_apply_to_slot(slot: String) -> bool:
	# Map equipment slots to categories
	var slot_category: String = ""
	match slot:
		"main_hand": slot_category = "weapon"
		"off_hand": slot_category = "shield"  # or weapon if dual-wielding
		"head", "body", "hands", "feet": slot_category = "armor"
		"ring_1", "ring_2": slot_category = "ring"
		"amulet": slot_category = "amulet"

	return slot_category in applicable_slots

## Get effect description for UI
func get_effect_string() -> String:
	match enchantment_type:
		EnchantmentType.DAMAGE_BONUS:
			return "+%d %s damage" % [effect_value, _damage_type_name(damage_type)]
		EnchantmentType.RESISTANCE:
			return "+%d%% %s resistance" % [effect_value, _damage_type_name(damage_type)]
		EnchantmentType.STAT_BONUS:
			return "+%d %s" % [effect_value, _stat_name(stat_type)]
		EnchantmentType.CONDITION_ON_HIT:
			return "%d%% chance to inflict %s" % [int(proc_chance * 100), _condition_name(inflicts_condition)]
		EnchantmentType.LIFESTEAL:
			return "%d%% lifesteal" % effect_value
		EnchantmentType.ARMOR_BONUS:
			return "+%d armor" % effect_value
		EnchantmentType.CRIT_BONUS:
			return "+%d%% crit chance" % effect_value
		EnchantmentType.MANA_BONUS:
			return "+%d max mana" % effect_value
		EnchantmentType.STAMINA_BONUS:
			return "+%d max stamina" % effect_value
		EnchantmentType.HEALTH_BONUS:
			return "+%d max health" % effect_value
	return "Unknown effect"

## Helper: get damage type display name
static func _damage_type_name(dt: Enums.DamageType) -> String:
	match dt:
		Enums.DamageType.PHYSICAL: return "physical"
		Enums.DamageType.FIRE: return "fire"
		Enums.DamageType.LIGHTNING: return "lightning"
		Enums.DamageType.FROST: return "frost"
		Enums.DamageType.POISON: return "poison"
		Enums.DamageType.NECROTIC: return "necrotic"
		Enums.DamageType.HOLY: return "holy"
	return "unknown"

## Helper: get stat display name
static func _stat_name(stat: Enums.Stat) -> String:
	match stat:
		Enums.Stat.GRIT: return "Grit"
		Enums.Stat.AGILITY: return "Agility"
		Enums.Stat.WILL: return "Will"
		Enums.Stat.SPEECH: return "Speech"
		Enums.Stat.KNOWLEDGE: return "Knowledge"
		Enums.Stat.VITALITY: return "Vitality"
	return "Unknown"

## Helper: get condition display name
static func _condition_name(cond: Enums.Condition) -> String:
	match cond:
		Enums.Condition.POISONED: return "Poison"
		Enums.Condition.BURNING: return "Burn"
		Enums.Condition.FROZEN: return "Freeze"
		Enums.Condition.STUNNED: return "Stun"
		Enums.Condition.SLOWED: return "Slow"
		Enums.Condition.BLINDED: return "Blind"
		Enums.Condition.BLEEDING: return "Bleed"
	return "Unknown"
