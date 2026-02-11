## enemy_attack_data.gd - Resource for individual enemy attack definitions
@tool
class_name EnemyAttackData
extends Resource

@export var id: String = ""
@export var display_name: String = ""

@export_group("Damage")
## Dice notation: [num_dice, die_size, flat_bonus]
@export var damage: Array[int] = [2, 6, 0]
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL

@export_group("Timing")
@export var windup_time: float = 0.5  # Telegraph before damage
@export var active_time: float = 0.2  # Hitbox active duration
@export var recovery_time: float = 0.3  # Vulnerable after attack
@export var cooldown: float = 1.0  # Time before using this attack again

@export_group("Range & Area")
@export var range_distance: float = 2.0
@export var is_ranged: bool = false
@export var is_aoe: bool = false
@export var aoe_radius: float = 0.0
@export var projectile_speed: float = 15.0

@export_group("Effects")
@export var inflicts_condition: Enums.Condition = Enums.Condition.NONE
@export var condition_chance: float = 0.0
@export var condition_duration: float = 0.0
@export var stagger_power: float = 1.0
@export var knockback_force: float = 0.0

@export_group("AI Usage")
@export var weight: float = 1.0  # Selection weight for AI
@export var min_range: float = 0.0  # Only use if target >= this range
@export var max_range: float = 100.0  # Only use if target <= this range
@export var requires_los: bool = true  # Requires line of sight

@export_group("Animation")
@export var animation_name: String = "attack"
@export var sound_effect: String = ""

## Roll damage
func roll_damage() -> int:
	var total := 0
	for i in range(damage[0]):
		total += randi_range(1, damage[1])
	total += damage[2]
	return max(1, total)

## Check if attack can be used at given range
func can_use_at_range(distance: float) -> bool:
	return distance >= min_range and distance <= max_range
