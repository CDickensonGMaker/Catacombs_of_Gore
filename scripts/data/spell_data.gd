## spell_data.gd - Resource class for spell definitions
@tool
class_name SpellData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Classification")
@export var school: Enums.SpellSchool = Enums.SpellSchool.EVOCATION
@export var spell_level: int = 1  # 1-5, affects slot cost
@export var target_type: Enums.SpellTargetType = Enums.SpellTargetType.PROJECTILE

@export_group("Cost")
## Mana cost - if 0, calculated as slot_cost * 10
@export var mana_cost: int = 0
## Legacy slot cost - used for mana calculation if mana_cost is 0
@export var slot_cost: int = 1
@export var stamina_cost: float = 0.0  # Some spells also cost stamina

@export_group("Casting")
@export var cast_time: float = 0.5  # Windup in seconds (interruptible)
@export var cooldown: float = 0.0  # Time before can cast again
@export var range_distance: float = 20.0  # Max range in meters
@export var aoe_radius: float = 0.0  # For AOE spells
@export var cone_angle: float = 45.0  # For cone spells (degrees)
@export var beam_width: float = 0.5  # For beam spells

@export_group("Damage/Healing")
## Dice notation: [num_dice, die_size, flat_bonus]
@export var base_effect: Array[int] = [3, 6, 4]  # e.g., Magic Missile = 3d6+4
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
@export var is_healing: bool = false
@export var scales_with_knowledge: bool = true  # Most spells scale with Knowledge

@export_group("Special Effects")
@export var inflicts_condition: Enums.Condition = Enums.Condition.NONE
@export var condition_chance: float = 1.0  # 0-1
@export var condition_duration: float = 5.0

@export_group("Projectile Properties")
@export var projectile_speed: float = 25.0
@export var is_homing: bool = false
@export var homing_strength: float = 5.0  # Turn rate
@export var piercing: bool = false  # Goes through enemies
@export var chain_targets: int = 0  # For Lightning Bolt etc.
@export var chain_range: float = 5.0

@export_group("Summon Properties")
@export var summon_scene_path: String = ""
@export var summon_duration: float = 60.0
@export var summon_leash_range: float = 6.0  # ~20 feet
@export var max_summons: int = 1

@export_group("DOT Properties")
@export var dot_damage: Array[int] = [0, 0, 0]
@export var dot_interval: float = 1.0  # Damage tick rate
@export var dot_duration: float = 0.0

@export_group("Lifesteal")
@export var lifesteal_percent: float = 0.0  # For Soul Drain etc.
@export var manasteal_percent: float = 0.0  # Restore mana based on damage dealt

@export_group("Hazard Zone (Fire Gate, Ice Storm)")
## If true, creates a persistent ground hazard zone instead of instant AOE
@export var creates_hazard_zone: bool = false
## Duration of the hazard zone in seconds (default 60s = 1 minute)
@export var hazard_duration: float = 60.0
## Time between damage ticks
@export var hazard_tick_interval: float = 1.0
## Damage per tick: [num_dice, die_size, flat_bonus]
@export var hazard_tick_damage: Array[int] = [2, 6, 0]

@export_group("Requirements")
@export var required_knowledge: int = 0
@export var required_will: int = 0
@export var required_arcana_lore: int = 0

@export_group("Visuals & Audio")
@export var cast_animation: String = "cast"
@export var projectile_scene_path: String = ""
@export var impact_effect_path: String = ""
@export var cast_sound: String = ""
@export var impact_sound: String = ""
@export var icon_path: String = ""

@export_group("First Person (FPS) View")
## Path to the first-person casting hands sprite (DOOM-style)
@export var fps_sprite_path: String = ""
## Number of horizontal frames in the FPS sprite sheet
@export var fps_h_frames: int = 4
## Number of vertical frames in the FPS sprite sheet
@export var fps_v_frames: int = 1
## Size of the hands in first-person view (pixels)
@export var fps_sprite_size: Vector2 = Vector2(200, 200)

## Roll spell effect (damage or healing)
func roll_effect(caster_knowledge: int = 0, caster_arcana: int = 0) -> int:
	var total := 0

	# Roll base dice
	for i in range(base_effect[0]):
		total += randi_range(1, base_effect[1])
	total += base_effect[2]

	# Apply Knowledge scaling if applicable
	if scales_with_knowledge:
		var knowledge_bonus := caster_knowledge * 0.1  # +10% per Knowledge point
		var arcana_bonus := caster_arcana * 0.05  # +5% per Arcana Lore
		total = int(total * (1.0 + knowledge_bonus + arcana_bonus))

	return max(1, total)

## Roll DOT damage per tick
func roll_dot_damage() -> int:
	if dot_damage[0] <= 0:
		return 0
	var total := 0
	for i in range(dot_damage[0]):
		total += randi_range(1, dot_damage[1])
	total += dot_damage[2]
	return max(1, total)

## Get effect string for UI
func get_effect_string() -> String:
	var s := "%dd%d" % [base_effect[0], base_effect[1]]
	if base_effect[2] > 0:
		s += "+%d" % base_effect[2]
	elif base_effect[2] < 0:
		s += "%d" % base_effect[2]
	if is_healing:
		s += " HP"
	else:
		s += " damage"
	return s

## Get effective mana cost (uses mana_cost if set, otherwise slot_cost * 10)
func get_mana_cost() -> int:
	if mana_cost > 0:
		return mana_cost
	return slot_cost * 10

## Get cost string for UI display
func get_cost_string() -> String:
	return "%d mana" % get_mana_cost()
