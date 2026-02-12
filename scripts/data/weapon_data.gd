## weapon_data.gd - Resource class for weapon definitions
@tool
class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Classification")
@export var weapon_type: Enums.WeaponType = Enums.WeaponType.SWORD
@export var weapon_class: Enums.WeaponClass = Enums.WeaponClass.SIMPLE
@export var two_handed: bool = false

@export_group("Damage")
## Dice notation: [num_dice, die_size, flat_bonus] e.g. [3, 6, 4] = 3d6+4
@export var base_damage: Array[int] = [2, 6, 0]
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
@export var secondary_damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
@export var secondary_damage: Array[int] = [0, 0, 0]  # For elemental weapons

@export_group("Combat Properties")
@export var attack_speed: float = 1.0  # Multiplier (higher = faster)
@export var reach: float = 2.0  # Meters
@export var stagger_power: float = 1.0  # How much it staggers enemies
@export var armor_pierce: float = 0.0  # Percentage of armor ignored (0-1)
@export var crit_chance: float = 0.05  # Base 5%
@export var crit_multiplier: float = 2.0

@export_group("Ranged Properties")
@export var is_ranged: bool = false
@export var projectile_speed: float = 30.0
@export var max_range: float = 320.0  # In game units (roughly feet from PDF)
@export var reload_time: float = 0.0  # Seconds
@export var ammo_type: String = ""
@export var projectile_data_path: String = ""  # Path to ProjectileData resource
@export var backfire_chance: float = 0.0  # Chance (0-1) to damage self on crit fail (for muskets)

@export_group("Special Effects")
@export var inflicts_condition: Enums.Condition = Enums.Condition.NONE
@export var condition_chance: float = 0.0
@export var condition_duration: float = 0.0
@export var lifesteal_percent: float = 0.0  # For vampiric weapons
@export var is_homing: bool = false  # For magic projectiles

@export_group("Requirements")
@export var required_grit: int = 0
@export var required_agility: int = 0
@export var required_knowledge: int = 0

@export_group("Economy")
@export var base_value: int = 100
@export var weight: float = 1.0

@export_group("Visuals")
@export var mesh_path: String = ""
@export var icon_path: String = ""
@export var attack_animation: String = "attack_slash"
@export var heavy_attack_animation: String = "attack_heavy_slash"

@export_group("First Person (FPS) View")
## Path to the first-person weapon sprite (DOOM-style)
@export var fps_sprite_path: String = ""
## Number of horizontal frames in the FPS sprite sheet
@export var fps_h_frames: int = 4
## Number of vertical frames in the FPS sprite sheet
@export var fps_v_frames: int = 1
## Size of the weapon in first-person view (pixels)
@export var fps_sprite_size: Vector2 = Vector2(256, 256)

@export_group("First Person 3D Mesh")
## Path to a 3D mesh for first-person view (overrides sprite if set)
@export var fps_mesh_path: String = ""
## Scale of the 3D mesh in first-person view
@export var fps_mesh_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
## Position offset of the 3D mesh (local to camera)
@export var fps_mesh_position: Vector3 = Vector3(0.4, -0.3, -0.5)
## Rotation offset of the 3D mesh in degrees
@export var fps_mesh_rotation: Vector3 = Vector3(0.0, 0.0, 0.0)

## Roll damage using the dice notation
func roll_damage(quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE) -> int:
	var total := 0
	var modifier := Enums.get_quality_modifier(quality)

	# Roll primary damage
	for i in range(base_damage[0]):
		total += randi_range(1, base_damage[1])
	total += base_damage[2] + modifier

	return max(1, total)

## Roll secondary (elemental) damage if applicable
func roll_secondary_damage(quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE) -> int:
	if secondary_damage[0] <= 0:
		return 0

	var total := 0
	var modifier := Enums.get_quality_modifier(quality)

	for i in range(secondary_damage[0]):
		total += randi_range(1, secondary_damage[1])
	total += secondary_damage[2] + modifier

	return max(0, total)

## Get damage string for UI display (e.g., "3d6+4")
func get_damage_string() -> String:
	var s := "%dd%d" % [base_damage[0], base_damage[1]]
	if base_damage[2] > 0:
		s += "+%d" % base_damage[2]
	elif base_damage[2] < 0:
		s += "%d" % base_damage[2]
	return s

## Calculate value based on quality
func get_value(quality: Enums.ItemQuality) -> int:
	var multiplier := 1.0
	match quality:
		Enums.ItemQuality.POOR: multiplier = 0.25
		Enums.ItemQuality.BELOW_AVERAGE: multiplier = 0.5
		Enums.ItemQuality.AVERAGE: multiplier = 1.0
		Enums.ItemQuality.ABOVE_AVERAGE: multiplier = 2.0
		Enums.ItemQuality.PERFECT: multiplier = 4.0
	return int(base_value * multiplier)
