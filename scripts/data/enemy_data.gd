## enemy_data.gd - Resource class for enemy definitions
@tool
class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var level: int = 1  ## Enemy level (1-100) - determines loot tier and XP scaling

@export_group("Stats")
@export var max_hp: int = 25
@export var armor_value: int = 8
@export var movement_speed: float = 4.0
@export var turn_speed: float = 5.0

@export_group("Attributes")
@export var grit: int = 5
@export var agility: int = 5
@export var will: int = 5
@export var knowledge: int = 5
@export var bravery: int = 3  ## Resistance to intimidation (0-10)

@export_group("AI Behavior")
@export var behavior: Enums.AIBehavior = Enums.AIBehavior.MELEE_AGGRESSIVE
@export var faction: Enums.Faction = Enums.Faction.NEUTRAL  # Determines inter-enemy hostility
@export var aggro_range: float = 15.0
@export var attack_range: float = 2.0
@export var preferred_distance: float = 2.0  # For ranged, keeps this distance
@export var flee_hp_threshold: float = 0.2  # Flee below 20% HP
@export var is_boss: bool = false
@export var allows_dialogue: bool = false  ## If true, shows FIGHT/BRIBE/NEGOTIATE/INTIMIDATE options

@export_group("Combat")
@export var attacks: Array[EnemyAttackData] = []
@export var can_block: bool = false
@export var block_chance: float = 0.2
@export var stagger_resistance: float = 0.0  # 0-1, reduces stagger duration

@export_group("Resistances")
@export var fire_resistance: float = 0.0
@export var frost_resistance: float = 0.0
@export var lightning_resistance: float = 0.0
@export var poison_resistance: float = 0.0
@export var necrotic_resistance: float = 0.0
@export var physical_resistance: float = 0.0

@export_group("Weaknesses")
@export var fire_weakness: float = 0.0  # Extra damage multiplier
@export var frost_weakness: float = 0.0
@export var lightning_weakness: float = 0.0
@export var holy_weakness: float = 0.0

@export_group("Horror")
@export var causes_horror: bool = false
@export var horror_difficulty: int = 10  # DC for horror check

@export_group("Loot")
@export var loot_table_av: int = 5  # Which loot table to use (based on AV from PDF)
@export var gold_drop: Array[int] = [50, 150]  # Min/max gold
@export var guaranteed_drops: Array[String] = []  # Item IDs always dropped
@export var drop_table: Dictionary = {}  # {"item_id": drop_chance}

@export_group("Experience")
@export var xp_reward: int = 100  # IP (Improvement Points)

@export_group("Visuals")
@export var scene_path: String = ""
@export var icon_path: String = ""
@export var scale: float = 1.0
@export var sprite_path: String = ""  ## Path to idle/main sprite sheet
@export var attack_sprite_path: String = ""  ## Path to attack sprite sheet (optional)
@export var sprite_hframes: int = 1  ## Horizontal frames in sprite sheet
@export var sprite_vframes: int = 1  ## Vertical frames in sprite sheet
@export var attack_hframes: int = 1  ## Horizontal frames in attack sprite
@export var attack_vframes: int = 1  ## Vertical frames in attack sprite
@export var sprite_pixel_size: float = 0.01  ## Pixel size for billboard sprite

@export_group("Audio")
@export var idle_sounds: Array[String] = []
@export var attack_sounds: Array[String] = []
@export var hurt_sounds: Array[String] = []
@export var death_sounds: Array[String] = []

## Calculate damage resistance for a type
func get_damage_multiplier(damage_type: Enums.DamageType) -> float:
	var resistance := 0.0
	var weakness := 0.0

	match damage_type:
		Enums.DamageType.PHYSICAL:
			resistance = physical_resistance
		Enums.DamageType.FIRE:
			resistance = fire_resistance
			weakness = fire_weakness
		Enums.DamageType.FROST:
			resistance = frost_resistance
			weakness = frost_weakness
		Enums.DamageType.LIGHTNING:
			resistance = lightning_resistance
			weakness = lightning_weakness
		Enums.DamageType.POISON:
			resistance = poison_resistance
		Enums.DamageType.NECROTIC:
			resistance = necrotic_resistance
		Enums.DamageType.HOLY:
			weakness = holy_weakness

	# Resistance reduces damage, weakness increases it
	return (1.0 - resistance) * (1.0 + weakness)

## Roll gold drop
func roll_gold() -> int:
	return randi_range(gold_drop[0], gold_drop[1])

## Get random attack from available attacks
func get_random_attack() -> EnemyAttackData:
	if attacks.is_empty():
		return null
	return attacks[randi() % attacks.size()]
