## spell_effect_data.gd - Individual spell effect component for custom spell creation
@tool
class_name SpellEffectData
extends Resource

## Effect types
enum EffectType {
	DAMAGE,           # Deal damage
	HEAL,             # Restore health
	RESTORE_STAMINA,  # Restore stamina
	RESTORE_MANA,     # Restore mana
	APPLY_CONDITION,  # Apply a status condition
	REMOVE_CONDITION, # Remove a status condition
	SUMMON,           # Summon creature
	FORTIFY_STAT,     # Temporarily increase a stat
	DRAIN_STAT,       # Temporarily decrease enemy stat
	ABSORB            # Steal health/mana from target
}

## Delivery methods
enum DeliveryType {
	SELF,       # Affects caster only
	TOUCH,      # Requires melee range
	PROJECTILE, # Ranged projectile
	AOE         # Area of effect
}

## Unique identifier
@export var id: String = ""

## Display name
@export var display_name: String = ""

## Description
@export_multiline var description: String = ""

@export_group("Effect Configuration")
## Type of effect
@export var effect_type: EffectType = EffectType.DAMAGE

## Damage type (for DAMAGE/ABSORB effects)
@export var damage_type: Enums.DamageType = Enums.DamageType.FIRE

## Condition to apply/remove
@export var condition: Enums.Condition = Enums.Condition.NONE

## Stat to fortify/drain
@export var stat: Enums.Stat = Enums.Stat.GRIT

## Allowed delivery methods for this effect
@export var allowed_delivery: Array[int] = [0, 1, 2, 3]  # All by default

@export_group("Magnitude Scaling")
## Base magnitude (minimum value)
@export var base_magnitude: int = 5

## Maximum magnitude player can set
@export var max_magnitude: int = 50

## Base duration in seconds (for applicable effects)
@export var base_duration: float = 0.0

## Maximum duration
@export var max_duration: float = 30.0

@export_group("Cost Calculation")
## Base mana cost for this effect
@export var base_cost: int = 5

## Cost multiplier per magnitude point above base
@export var magnitude_cost_mult: float = 0.5

## Cost multiplier per second of duration
@export var duration_cost_mult: float = 1.0

## Cost multiplier per unit of AOE radius
@export var aoe_cost_mult: float = 2.0

@export_group("Requirements")
## Minimum Arcana Lore required to use this effect
@export var required_arcana: int = 0

@export_group("Visuals")
## Icon path for UI
@export var icon_path: String = ""

## Color for effect display
@export var effect_color: Color = Color(1.0, 1.0, 1.0, 1.0)

## Calculate the mana cost for this effect with given parameters
func calculate_cost(magnitude: int, duration: float, aoe_radius: float, delivery: DeliveryType) -> int:
	var cost: float = float(base_cost)

	# Add magnitude cost (above base)
	if magnitude > base_magnitude:
		cost += float(magnitude - base_magnitude) * magnitude_cost_mult

	# Add duration cost
	if duration > 0 and has_duration():
		cost += duration * duration_cost_mult

	# Apply delivery type multipliers
	match delivery:
		DeliveryType.SELF:
			cost *= 0.8  # Cheaper for self-only
		DeliveryType.TOUCH:
			cost *= 1.0  # Base cost
		DeliveryType.PROJECTILE:
			cost *= 1.2  # Slightly more expensive
		DeliveryType.AOE:
			cost *= 1.5  # More expensive base
			cost += aoe_radius * aoe_cost_mult  # Plus per-unit radius

	return maxi(1, int(cost))

## Check if this effect uses duration
func has_duration() -> bool:
	match effect_type:
		EffectType.APPLY_CONDITION, EffectType.FORTIFY_STAT, EffectType.DRAIN_STAT, EffectType.SUMMON:
			return true
		_:
			return false

## Check if delivery type is allowed
func is_delivery_allowed(delivery: DeliveryType) -> bool:
	return int(delivery) in allowed_delivery

## Get effect string for UI
func get_effect_string(magnitude: int, duration: float) -> String:
	match effect_type:
		EffectType.DAMAGE:
			return "%d %s damage" % [magnitude, EnchantmentData._damage_type_name(damage_type)]
		EffectType.HEAL:
			return "Heal %d HP" % magnitude
		EffectType.RESTORE_STAMINA:
			return "Restore %d stamina" % magnitude
		EffectType.RESTORE_MANA:
			return "Restore %d mana" % magnitude
		EffectType.APPLY_CONDITION:
			return "Apply %s for %.1fs" % [EnchantmentData._condition_name(condition), duration]
		EffectType.REMOVE_CONDITION:
			return "Remove %s" % EnchantmentData._condition_name(condition)
		EffectType.FORTIFY_STAT:
			return "+%d %s for %.1fs" % [magnitude, EnchantmentData._stat_name(stat), duration]
		EffectType.DRAIN_STAT:
			return "-%d %s for %.1fs" % [magnitude, EnchantmentData._stat_name(stat), duration]
		EffectType.ABSORB:
			return "Absorb %d HP" % magnitude
		EffectType.SUMMON:
			return "Summon for %.1fs" % duration
	return "Unknown effect"

## Get delivery type name
static func get_delivery_name(delivery: DeliveryType) -> String:
	match delivery:
		DeliveryType.SELF: return "Self"
		DeliveryType.TOUCH: return "Touch"
		DeliveryType.PROJECTILE: return "Projectile"
		DeliveryType.AOE: return "Area"
	return "Unknown"
