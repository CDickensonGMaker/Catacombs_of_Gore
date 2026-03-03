## custom_spell_data.gd - Player-created spell data (extends SpellData)
class_name CustomSpellData
extends SpellData

## Configuration for each effect in this custom spell
## Array of {effect_id, magnitude, duration, delivery, aoe_radius}
var effects_config: Array[Dictionary] = []

## Is this a custom (player-created) spell?
var is_custom: bool = true

## Creation timestamp for sorting
var created_at: int = 0

## Create a custom spell from effect configurations
static func create_custom_spell(
	spell_name: String,
	effect_configs: Array[Dictionary],
	primary_delivery: SpellEffectData.DeliveryType
) -> CustomSpellData:
	var spell := CustomSpellData.new()
	spell.is_custom = true
	spell.created_at = Time.get_unix_time_from_system()

	# Generate unique ID
	spell.id = "custom_%s_%d" % [spell_name.to_snake_case(), spell.created_at]
	spell.display_name = spell_name

	# Store effect configurations
	spell.effects_config = effect_configs.duplicate(true)

	# Set delivery type based on primary delivery
	match primary_delivery:
		SpellEffectData.DeliveryType.SELF:
			spell.target_type = Enums.SpellTargetType.SELF
		SpellEffectData.DeliveryType.TOUCH:
			spell.target_type = Enums.SpellTargetType.SINGLE_ENEMY
			spell.range_distance = 3.0
		SpellEffectData.DeliveryType.PROJECTILE:
			spell.target_type = Enums.SpellTargetType.PROJECTILE
			spell.range_distance = 30.0
		SpellEffectData.DeliveryType.AOE:
			spell.target_type = Enums.SpellTargetType.AOE_POINT
			spell.range_distance = 20.0
			# Get AOE radius from first AOE effect config
			for config in effect_configs:
				if config.has("aoe_radius") and config.aoe_radius > 0:
					spell.aoe_radius = config.aoe_radius
					break

	# Calculate total mana cost
	var total_cost: int = 0
	for config in effect_configs:
		var effect: SpellEffectData = SpellCreator.get_effect(config.effect_id)
		if effect:
			total_cost += effect.calculate_cost(
				config.get("magnitude", effect.base_magnitude),
				config.get("duration", effect.base_duration),
				config.get("aoe_radius", 0.0),
				config.get("delivery", SpellEffectData.DeliveryType.PROJECTILE)
			)
	spell.mana_cost = total_cost

	# Generate description
	spell.description = spell._generate_description()

	# Determine primary damage type and effect values from first damage effect
	spell._set_primary_effect_values()

	return spell

## Generate description from effects
func _generate_description() -> String:
	var parts: Array[String] = []
	for config in effects_config:
		var effect: SpellEffectData = SpellCreator.get_effect(config.effect_id)
		if effect:
			parts.append(effect.get_effect_string(
				config.get("magnitude", effect.base_magnitude),
				config.get("duration", effect.base_duration)
			))
	return ". ".join(parts) + "."

## Set primary effect values for spell casting
func _set_primary_effect_values() -> void:
	for config in effects_config:
		var effect: SpellEffectData = SpellCreator.get_effect(config.effect_id)
		if not effect:
			continue

		match effect.effect_type:
			SpellEffectData.EffectType.DAMAGE:
				damage_type = effect.damage_type
				# Convert magnitude to dice notation (approximate)
				var mag: int = config.get("magnitude", effect.base_magnitude)
				base_effect = [1, mag, 0]  # 1d[mag] for simplicity
				is_healing = false
				break

			SpellEffectData.EffectType.HEAL:
				is_healing = true
				var mag: int = config.get("magnitude", effect.base_magnitude)
				base_effect = [1, mag, 0]
				break

			SpellEffectData.EffectType.APPLY_CONDITION:
				inflicts_condition = effect.condition
				condition_chance = 1.0
				condition_duration = config.get("duration", effect.base_duration)

## Roll effect for custom spells (called when casting)
func roll_custom_effect(_caster_knowledge: int = 0, _caster_arcana: int = 0) -> Dictionary:
	var results: Dictionary = {
		"damage": {},      # DamageType -> amount
		"heal": 0,
		"restore_stamina": 0,
		"restore_mana": 0,
		"conditions_apply": [],  # Array of {condition, duration}
		"conditions_remove": [],
		"stat_buffs": [],  # Array of {stat, value, duration}
		"stat_debuffs": [],
		"absorb": 0
	}

	for config in effects_config:
		var effect: SpellEffectData = SpellCreator.get_effect(config.effect_id)
		if not effect:
			continue

		var mag: int = config.get("magnitude", effect.base_magnitude)
		var dur: float = config.get("duration", effect.base_duration)

		match effect.effect_type:
			SpellEffectData.EffectType.DAMAGE:
				if not results.damage.has(effect.damage_type):
					results.damage[effect.damage_type] = 0
				results.damage[effect.damage_type] += randi_range(1, mag)

			SpellEffectData.EffectType.HEAL:
				results.heal += randi_range(1, mag)

			SpellEffectData.EffectType.RESTORE_STAMINA:
				results.restore_stamina += mag

			SpellEffectData.EffectType.RESTORE_MANA:
				results.restore_mana += mag

			SpellEffectData.EffectType.APPLY_CONDITION:
				results.conditions_apply.append({
					"condition": effect.condition,
					"duration": dur
				})

			SpellEffectData.EffectType.REMOVE_CONDITION:
				results.conditions_remove.append(effect.condition)

			SpellEffectData.EffectType.FORTIFY_STAT:
				results.stat_buffs.append({
					"stat": effect.stat,
					"value": mag,
					"duration": dur
				})

			SpellEffectData.EffectType.DRAIN_STAT:
				results.stat_debuffs.append({
					"stat": effect.stat,
					"value": mag,
					"duration": dur
				})

			SpellEffectData.EffectType.ABSORB:
				results.absorb += randi_range(1, mag)

	return results

## Serialize for saving
func to_save_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"effects_config": effects_config.duplicate(true),
		"mana_cost": mana_cost,
		"target_type": int(target_type),
		"range_distance": range_distance,
		"aoe_radius": aoe_radius,
		"created_at": created_at
	}

## Deserialize from save
static func from_save_dict(data: Dictionary) -> CustomSpellData:
	var spell := CustomSpellData.new()
	spell.id = data.get("id", "custom_unknown")
	spell.display_name = data.get("display_name", "Unknown Spell")
	spell.description = data.get("description", "")
	spell.effects_config = data.get("effects_config", [])
	spell.mana_cost = data.get("mana_cost", 10)
	spell.target_type = data.get("target_type", Enums.SpellTargetType.PROJECTILE)
	spell.range_distance = data.get("range_distance", 20.0)
	spell.aoe_radius = data.get("aoe_radius", 0.0)
	spell.created_at = data.get("created_at", 0)
	spell.is_custom = true

	spell._set_primary_effect_values()
	return spell
