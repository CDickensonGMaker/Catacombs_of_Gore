## soulstone_data.gd - Resource class for soul gem definitions
@tool
class_name SoulstoneData
extends Resource

## Unique identifier
@export var id: String = ""

## Display name shown to player
@export var display_name: String = ""

## Description
@export_multiline var description: String = ""

## Tier level (1-5)
## Higher tier = more powerful enchantments possible
@export_range(1, 5) var tier: int = 1

## Enchant power multiplier (applied to enchantment effect_value)
@export var enchant_power: float = 1.0

## Soul energy threshold to fill this gem from empty
@export var fill_threshold: int = 5

## Whether this soulstone is currently filled with a soul
@export var is_filled: bool = false

## Current soul energy (for empty gems being charged)
@export var current_energy: int = 0

## Icon texture path
@export var icon_path: String = ""

## Glow color when filled
@export var filled_color: Color = Color(0.6, 0.3, 1.0, 1.0)

## Get display name with filled status
func get_display_name() -> String:
	if is_filled:
		return display_name + " (Filled)"
	elif current_energy > 0:
		return "%s (%d/%d)" % [display_name, current_energy, fill_threshold]
	else:
		return display_name + " (Empty)"

## Add soul energy from a killed enemy
## Returns true if gem became filled
func add_soul_energy(energy: int) -> bool:
	if is_filled:
		return false  # Already filled

	current_energy += energy
	if current_energy >= fill_threshold:
		current_energy = fill_threshold
		is_filled = true
		return true
	return false

## Consume the soul (when used for enchanting)
func consume_soul() -> bool:
	if not is_filled:
		return false
	is_filled = false
	current_energy = 0
	return true

## Clone this soulstone data
func duplicate_soulstone() -> SoulstoneData:
	var copy := SoulstoneData.new()
	copy.id = id
	copy.display_name = display_name
	copy.description = description
	copy.tier = tier
	copy.enchant_power = enchant_power
	copy.fill_threshold = fill_threshold
	copy.is_filled = is_filled
	copy.current_energy = current_energy
	copy.icon_path = icon_path
	copy.filled_color = filled_color
	return copy

## Soulstone tier definitions (static reference)
const TIER_DATA: Dictionary = {
	1: {"name": "Petty", "power": 1.0, "threshold": 5},
	2: {"name": "Lesser", "power": 1.5, "threshold": 15},
	3: {"name": "Common", "power": 2.0, "threshold": 30},
	4: {"name": "Greater", "power": 3.0, "threshold": 60},
	5: {"name": "Grand", "power": 5.0, "threshold": 100}
}

## Get tier name by number
static func get_tier_name(tier_num: int) -> String:
	if TIER_DATA.has(tier_num):
		return TIER_DATA[tier_num]["name"]
	return "Unknown"

## Get enchant power by tier
static func get_tier_power(tier_num: int) -> float:
	if TIER_DATA.has(tier_num):
		return TIER_DATA[tier_num]["power"]
	return 1.0

## Get fill threshold by tier
static func get_tier_threshold(tier_num: int) -> int:
	if TIER_DATA.has(tier_num):
		return TIER_DATA[tier_num]["threshold"]
	return 5
