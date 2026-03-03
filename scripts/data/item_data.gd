## item_data.gd - Resource class for consumables and misc items
##
## ============================================================================
## ITEM CREATION CHECKLIST
## ============================================================================
## When adding a new item to the game, complete ALL of these steps:
##
## 1. CREATE THE .TRES FILE
##    - Create a new .tres file in res://data/items/
##    - File name should match the item id (e.g., wolf_pelt.tres for id="wolf_pelt")
##    - Set ALL required fields:
##      - id: Unique identifier (snake_case, no spaces)
##      - display_name: Human-readable name shown to player
##      - description: Explains what the item is and its purpose
##      - item_type: CONSUMABLE, MATERIAL, QUEST, KEY, SCROLL, etc.
##      - base_value: Gold value for buying/selling
##      - weight: Encumbrance weight
##
## 2. REGISTER IN INVENTORY_MANAGER
##    - Open scripts/autoload/inventory_manager.gd
##    - Add the item id string to the item_files array
##    - Place it in the appropriate category section with a comment
##
## 3. VERIFY THE ITEM PURPOSE
##    Every item MUST serve a gameplay purpose:
##    - CONSUMABLE: Has a consumable_effect that benefits the player
##    - MATERIAL: Used in crafting recipes OR sells to specific merchants
##    - QUEST: Required for quest completion
##    - KEY: Opens specific doors/containers
##    - SCROLL: Teaches a spell (set teaches_spell_id)
##    - AMMUNITION: Used by ranged weapons
##    - REPAIR_KIT: Restores equipment durability
##    - MISC: Only if truly no other category fits
##
## 4. IF REFERENCED BY ENEMIES
##    - Ensure the item id in enemy .tres drop_table matches exactly
##    - Test that looting the enemy works correctly
##
## 5. TEST THE ITEM
##    - Verify it loads without errors
##    - Verify it appears correctly in inventory
##    - Verify it can be bought/sold if applicable
##    - Verify its effect works if consumable
## ============================================================================
@tool
class_name ItemData
extends Resource

enum ItemType {
	CONSUMABLE,
	MATERIAL,
	QUEST,
	KEY,
	SCROLL,
	BOOK,
	MISC,
	REPAIR_KIT,
	AMMUNITION,
	BEDROLL,  # Single-use camping item for wilderness rest
	TORCH     # Light source - equippable in off-hand, depletes while equipped
}

enum ConsumableEffect {
	NONE,
	HEAL_HP,
	RESTORE_STAMINA,
	RESTORE_MANA,
	RESTORE_SPELL_SLOTS,
	CURE_POISON,
	CURE_ALL_CONDITIONS,
	BUFF_STRENGTH,
	BUFF_AGILITY,
	BUFF_WILL,
	BUFF_ARMOR,
	BUFF_DAMAGE,
	RESIST_FIRE,
	RESIST_FROST,
	RESIST_POISON,
	INVISIBILITY
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Classification")
@export var item_type: ItemType = ItemType.CONSUMABLE
@export var is_stackable: bool = true
@export var max_stack: int = 99
@export var shop_bundle_size: int = 1  # How many you get when buying from a shop

@export_group("Consumable Effects")
@export var consumable_effect: ConsumableEffect = ConsumableEffect.NONE
@export var effect_value: Array[int] = [0, 0, 0]  # Dice or flat value
@export var effect_duration: float = 0.0  # For buffs
@export var effect_percent: float = 0.0  # For percentage-based effects

@export_group("Scroll Properties")
@export var teaches_spell_id: String = ""  # For spell scrolls
@export var requires_literacy: bool = true
@export var literacy_dc: int = 10  # Difficulty check to read

@export_group("Repair Kit Properties")
@export var repair_amount: int = 30  # How much durability to restore
@export var repairs_quality: bool = false  # If true, can restore quality tier instead

@export_group("Book Properties")
@export var unlocks_bestiary: Array[String] = []  # Creature IDs to unlock in bestiary
@export var book_tier: int = 1  # Book tier 1-10 (affects price and rarity)

@export_group("Economy")
@export var base_value: int = 10
@export var weight: float = 0.1

@export_group("Visuals")
@export var icon_path: String = ""
@export var mesh_path: String = ""
@export var use_sound: String = ""

## Roll effect value (for potions etc.)
func roll_effect() -> int:
	if effect_value[0] <= 0:
		return effect_value[2]  # Just flat value

	var total := 0
	for i in range(effect_value[0]):
		total += randi_range(1, effect_value[1])
	total += effect_value[2]
	return max(1, total)

## Get effect description string
func get_effect_string() -> String:
	match consumable_effect:
		ConsumableEffect.HEAL_HP:
			return "Restores %s HP" % _get_dice_string()
		ConsumableEffect.RESTORE_STAMINA:
			return "Restores %s Stamina" % _get_dice_string()
		ConsumableEffect.RESTORE_MANA:
			return "Restores %s Mana" % _get_dice_string()
		ConsumableEffect.RESTORE_SPELL_SLOTS:
			return "Restores %d spell slots" % effect_value[2]
		ConsumableEffect.CURE_POISON:
			return "Cures poison"
		ConsumableEffect.CURE_ALL_CONDITIONS:
			return "Cures all conditions"
		ConsumableEffect.BUFF_STRENGTH:
			return "+%d Grit for %.0fs" % [effect_value[2], effect_duration]
		ConsumableEffect.BUFF_AGILITY:
			return "+%d Agility for %.0fs" % [effect_value[2], effect_duration]
		ConsumableEffect.BUFF_WILL:
			return "+%d Will for %.0fs" % [effect_value[2], effect_duration]
		ConsumableEffect.BUFF_ARMOR:
			return "+%d Armor for %.0fs" % [effect_value[2], effect_duration]
		ConsumableEffect.BUFF_DAMAGE:
			return "+%d%% Damage for %.0fs" % [int(effect_percent * 100), effect_duration]
		ConsumableEffect.RESIST_FIRE:
			return "Fire resistance for %.0fs" % effect_duration
		ConsumableEffect.RESIST_FROST:
			return "Frost resistance for %.0fs" % effect_duration
		ConsumableEffect.RESIST_POISON:
			return "Poison resistance for %.0fs" % effect_duration
		ConsumableEffect.INVISIBILITY:
			return "Invisibility for %.0fs" % effect_duration
	return ""

## Get repair kit effect description
func get_repair_effect_string() -> String:
	if item_type != ItemType.REPAIR_KIT:
		return ""
	if repairs_quality:
		return "Restores equipment quality tier"
	return "Restores %d durability" % repair_amount

func _get_dice_string() -> String:
	if effect_value[0] <= 0:
		return str(effect_value[2])
	var s := "%dd%d" % [effect_value[0], effect_value[1]]
	if effect_value[2] > 0:
		s += "+%d" % effect_value[2]
	elif effect_value[2] < 0:
		s += "%d" % effect_value[2]
	return s
