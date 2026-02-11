## crafting_recipe.gd - Resource definition for crafting recipes
## Defines what materials are needed and what item is produced
class_name CraftingRecipe
extends Resource

## Recipe identification
@export var recipe_id: String = ""
@export var display_name: String = ""
@export var description: String = ""

## Category for UI organization
@export_enum("Weapon", "Armor", "Consumable", "Tool", "Material") var category: String = "Weapon"

## Required materials - Dictionary of item_id -> quantity
@export var materials: Dictionary = {}

## Required gold cost
@export var gold_cost: int = 0

## Required skill levels (0 = no requirement)
@export var required_engineering: int = 0
@export var required_arcana: int = 0  # For magical items

## Output item
@export var output_item_id: String = ""
@export var output_quantity: int = 1

## Base quality of crafted item (Engineering modifies this)
@export var base_quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE

## Whether this recipe can critically succeed for higher quality
@export var can_crit: bool = true

## Time to craft (for future animation)
@export var craft_time: float = 1.0


## Check if player has required materials and gold
func can_craft() -> bool:
	# Check gold
	if InventoryManager.gold < gold_cost:
		return false

	# Check materials
	for item_id in materials:
		var required: int = materials[item_id]
		var have: int = InventoryManager.get_item_count(item_id)
		if have < required:
			return false

	return true


## Check if player meets skill requirements
func meets_requirements() -> bool:
	if not GameManager.player_data:
		return false

	var eng := GameManager.player_data.get_skill(Enums.Skill.ENGINEERING)
	var arc := GameManager.player_data.get_skill(Enums.Skill.ARCANA_LORE)

	return eng >= required_engineering and arc >= required_arcana


## Get the quality result based on Engineering skill and dice roll
func get_crafted_quality() -> Enums.ItemQuality:
	if not GameManager.player_data:
		return base_quality

	var eng := GameManager.player_data.get_skill(Enums.Skill.ENGINEERING)

	# Roll d10
	var roll := randi_range(1, 10)

	# Critical success on 10
	if roll == 10 and can_crit:
		# Jump up 2 quality levels
		return _quality_up(base_quality, 2)

	# Engineering bonus
	var bonus := eng / 3  # Every 3 Engineering = +1 quality chance

	# Total check
	var total := roll + bonus

	if total >= 15:
		return _quality_up(base_quality, 2)
	elif total >= 10:
		return _quality_up(base_quality, 1)
	elif total >= 5:
		return base_quality
	else:
		return _quality_down(base_quality, 1)


func _quality_up(q: Enums.ItemQuality, levels: int) -> Enums.ItemQuality:
	var result := q + levels
	return mini(result, Enums.ItemQuality.PERFECT) as Enums.ItemQuality


func _quality_down(q: Enums.ItemQuality, levels: int) -> Enums.ItemQuality:
	var result := q - levels
	return maxi(result, Enums.ItemQuality.POOR) as Enums.ItemQuality


## Execute the craft - consume materials and produce item
func craft() -> Dictionary:
	if not can_craft():
		return {"success": false, "reason": "Missing materials or gold"}

	if not meets_requirements():
		return {"success": false, "reason": "Insufficient skill"}

	# Consume gold
	InventoryManager.remove_gold(gold_cost)

	# Consume materials - use remove_item_any_quality to handle mixed quality stacks
	for item_id in materials:
		var qty: int = materials[item_id]
		if not InventoryManager.remove_item_any_quality(item_id, qty):
			# This shouldn't happen since can_craft() passed, but log a warning
			push_warning("[CraftingRecipe] Failed to remove %d x %s - crafting may have produced unexpected results" % [qty, item_id])

	# Determine quality - only weapons and armor get quality modifiers
	var quality := Enums.ItemQuality.AVERAGE
	if _output_is_weapon_or_armor():
		quality = get_crafted_quality()

	# Add crafted item
	InventoryManager.add_item(output_item_id, output_quantity, quality)

	return {
		"success": true,
		"item_id": output_item_id,
		"quantity": output_quantity,
		"quality": quality
	}


## Check if the output item is a weapon or armor (only these get quality modifiers)
func _output_is_weapon_or_armor() -> bool:
	# Check by category first (fast path)
	if category == "Weapon" or category == "Armor":
		return true

	# Also check against InventoryManager databases for edge cases
	if InventoryManager.weapon_database.has(output_item_id):
		return true
	if InventoryManager.armor_database.has(output_item_id):
		return true

	return false
