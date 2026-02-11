## armor_data.gd - Resource class for armor definitions
@tool
class_name ArmorData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Classification")
@export var slot: Enums.ArmorSlot = Enums.ArmorSlot.BODY
@export var weight_class: Enums.ArmorWeight = Enums.ArmorWeight.CLOTH
@export var is_shield: bool = false

@export_group("Defense")
@export var armor_value: int = 7  # Base AV from PDF
@export var block_value: int = 0  # Additional AV when blocking (shields)

@export_group("Resistances")
## Resistance values: 0.0 = no resistance, 1.0 = immune, negative = weakness
@export var fire_resistance: float = 0.0
@export var frost_resistance: float = 0.0
@export var lightning_resistance: float = 0.0
@export var poison_resistance: float = 0.0
@export var necrotic_resistance: float = 0.0
@export var magic_resistance: float = 0.0

@export_group("Stat Modifiers")
@export var grit_bonus: int = 0
@export var agility_bonus: int = 0
@export var will_bonus: int = 0
@export var speech_bonus: int = 0
@export var knowledge_bonus: int = 0
@export var vitality_bonus: int = 0

@export_group("Penalties")
@export var agility_penalty: int = 0  # Heavy armor reduces agility
@export var stealth_penalty: int = 0  # Noisy armor
@export var spell_failure_chance: float = 0.0  # Heavy armor interferes with casting

@export_group("Requirements")
@export var required_grit: int = 0

@export_group("Economy")
@export var base_value: int = 50
@export var weight: float = 2.0

@export_group("Visuals")
@export var mesh_path: String = ""
@export var icon_path: String = ""

## Get total AV considering quality
func get_armor_value(quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE) -> int:
	var modifier := Enums.get_quality_modifier(quality)
	return max(0, armor_value + modifier)

## Get block value (for shields)
func get_block_value(quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE) -> int:
	if not is_shield:
		return 0
	var modifier := Enums.get_quality_modifier(quality)
	return max(0, block_value + modifier)

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

## Check if this armor can stack with another piece
func can_stack_with(other: ArmorData) -> bool:
	if slot != other.slot:
		return false
	# Only body armor can stack: Cloth + Leather + Chain allowed
	if slot != Enums.ArmorSlot.BODY:
		return false
	# Define stacking order
	var stackable := [Enums.ArmorWeight.CLOTH, Enums.ArmorWeight.LEATHER, Enums.ArmorWeight.CHAIN]
	return weight_class in stackable and other.weight_class in stackable and weight_class != other.weight_class
