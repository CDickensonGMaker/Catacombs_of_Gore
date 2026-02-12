## projectile_data.gd - Resource definition for projectile types
@tool
class_name ProjectileData
extends Resource

@export var id: String = ""
@export var display_name: String = ""

@export_group("Movement")
@export var speed: float = 20.0
@export var acceleration: float = 0.0  ## Speed change per second (negative = decelerate)
@export var max_speed: float = 50.0
@export var min_speed: float = 5.0
@export var gravity_scale: float = 0.0  ## 0 = no gravity, 1 = full gravity
@export var lifetime: float = 5.0  ## Max time before expiring

@export_group("Homing")
@export var is_homing: bool = false
@export var homing_strength: float = 5.0  ## Turn rate when homing
@export var homing_acquire_range: float = 30.0  ## Range to acquire homing target
@export var homing_delay: float = 0.0  ## Delay before homing activates

@export_group("Damage")
@export var base_damage: Array[int] = [2, 6, 0]  ## [num_dice, die_size, flat_bonus] e.g., 2d6+0
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
@export var can_crit: bool = true
@export var crit_multiplier: float = 2.0

@export_group("Status Effects")
@export var inflicts_condition: Enums.Condition = Enums.Condition.NONE
@export var condition_chance: float = 0.0  ## 0-1
@export var condition_duration: float = 5.0
@export var stagger_power: float = 0.0
@export var knockback_force: float = 0.0

@export_group("Piercing & Chaining")
@export var is_piercing: bool = false
@export var max_pierces: int = 3
@export var pierce_damage_falloff: float = 0.2  ## Damage reduction per pierce (0.2 = 20% less each)
@export var chain_targets: int = 0  ## 0 = no chaining
@export var chain_range: float = 5.0
@export var chain_damage_falloff: float = 0.3  ## Damage reduction per chain

@export_group("Area of Effect")
@export var aoe_radius: float = 0.0  ## 0 = no AOE
@export var aoe_damage_falloff: bool = true  ## Damage reduces with distance from center

@export_group("Collision")
@export var collision_radius: float = 0.3
@export var hits_enemies: bool = true
@export var hits_players: bool = false
@export var hits_world: bool = true  ## Stops on world geometry

@export_group("Visuals")
@export var mesh_path: String = ""
@export var material_path: String = ""
@export var scale: Vector3 = Vector3.ONE
@export var rotation_speed: float = 0.0  ## Spin on forward axis (radians/sec)

@export_group("Trail Effect")
@export var has_trail: bool = false
@export var trail_color: Color = Color.WHITE
@export var trail_length: float = 1.0
@export var trail_width: float = 0.1
@export var trail_lifetime: float = 0.5

@export_group("Impact Effect")
@export var impact_effect_path: String = ""
@export var impact_scale: float = 1.0

@export_group("Muzzle Effect")
@export var muzzle_effect_path: String = ""  ## Particle effect at spawn point (smoke, flash)
@export var muzzle_effect_scale: float = 1.0

@export_group("Audio")
@export var fire_sound: String = ""
@export var travel_sound: String = ""  ## Looping sound while in flight
@export var impact_sound: String = ""

## Roll damage for this projectile
func roll_damage(pierce_count: int = 0, chain_count: int = 0) -> int:
	var total := 0

	# Roll base dice
	for i in range(base_damage[0]):
		total += randi_range(1, base_damage[1])
	total += base_damage[2]

	# Apply pierce falloff
	if pierce_count > 0:
		total = int(total * pow(1.0 - pierce_damage_falloff, pierce_count))

	# Apply chain falloff
	if chain_count > 0:
		total = int(total * pow(1.0 - chain_damage_falloff, chain_count))

	return max(1, total)

## Get damage string for UI
func get_damage_string() -> String:
	var s := "%dd%d" % [base_damage[0], base_damage[1]]
	if base_damage[2] > 0:
		s += "+%d" % base_damage[2]
	elif base_damage[2] < 0:
		s += "%d" % base_damage[2]
	return s
