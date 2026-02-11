## crafting_manager.gd - Manages crafting recipes and crafting operations
## Autoload singleton for crafting system
extends Node

signal recipe_crafted(recipe_id: String, result: Dictionary)

## All available recipes
var recipes: Dictionary = {}  # recipe_id -> CraftingRecipe

## Recipe categories for UI filtering
var categories: Array[String] = ["Weapon", "Armor", "Consumable", "Tool", "Material"]


func _ready() -> void:
	_register_recipes()


## Register all crafting recipes
func _register_recipes() -> void:
	# === WEAPONS ===

	# Iron Sword
	_add_recipe({
		"recipe_id": "craft_iron_sword",
		"display_name": "Iron Sword",
		"description": "A sturdy iron blade",
		"category": "Weapon",
		"materials": {"iron_ingot": 3, "leather_strip": 1},
		"gold_cost": 25,
		"required_engineering": 1,
		"output_item_id": "iron_sword",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# Steel Sword
	_add_recipe({
		"recipe_id": "craft_steel_sword",
		"display_name": "Steel Sword",
		"description": "A well-crafted steel blade",
		"category": "Weapon",
		"materials": {"steel_ingot": 3, "leather_strip": 2},
		"gold_cost": 75,
		"required_engineering": 3,
		"output_item_id": "steel_sword",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# Iron Dagger
	_add_recipe({
		"recipe_id": "craft_iron_dagger",
		"display_name": "Iron Dagger",
		"description": "A simple iron dagger",
		"category": "Weapon",
		"materials": {"iron_ingot": 1},
		"gold_cost": 10,
		"required_engineering": 0,
		"output_item_id": "iron_dagger",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# Wooden Bow
	_add_recipe({
		"recipe_id": "craft_wooden_bow",
		"display_name": "Wooden Bow",
		"description": "A hunting bow made from flexible wood",
		"category": "Weapon",
		"materials": {"wood_plank": 2, "leather_strip": 1},
		"gold_cost": 20,
		"required_engineering": 1,
		"output_item_id": "hunting_bow",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# === ARMOR ===

	# Leather Armor
	_add_recipe({
		"recipe_id": "craft_leather_armor",
		"display_name": "Leather Armor",
		"description": "Basic leather protection",
		"category": "Armor",
		"materials": {"leather": 4, "leather_strip": 2},
		"gold_cost": 30,
		"required_engineering": 1,
		"output_item_id": "leather_armor",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# Chain Mail
	_add_recipe({
		"recipe_id": "craft_chain_mail",
		"display_name": "Chain Mail",
		"description": "Interlocking metal rings for solid protection",
		"category": "Armor",
		"materials": {"iron_ingot": 5, "leather_strip": 2},
		"gold_cost": 100,
		"required_engineering": 4,
		"output_item_id": "chainmail",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# === CONSUMABLES ===

	# Health Potion
	_add_recipe({
		"recipe_id": "craft_health_potion",
		"display_name": "Health Potion",
		"description": "Brew a basic healing potion",
		"category": "Consumable",
		"materials": {"red_herb": 2, "empty_vial": 1},
		"gold_cost": 5,
		"required_engineering": 0,
		"output_item_id": "health_potion",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# Arrows (10)
	_add_recipe({
		"recipe_id": "craft_arrows",
		"display_name": "Arrows (10)",
		"description": "Craft a bundle of arrows",
		"category": "Consumable",
		"materials": {"wood_plank": 1, "iron_ingot": 1},
		"gold_cost": 5,
		"required_engineering": 0,
		"output_item_id": "arrows",
		"output_quantity": 10,
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# === TOOLS ===

	# Lockpick
	_add_recipe({
		"recipe_id": "craft_lockpick",
		"display_name": "Lockpick",
		"description": "A thin metal tool for opening locks",
		"category": "Tool",
		"materials": {"iron_ingot": 1},
		"gold_cost": 5,
		"required_engineering": 1,
		"output_item_id": "lockpick",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# Repair Kit
	_add_recipe({
		"recipe_id": "craft_repair_kit",
		"display_name": "Repair Kit",
		"description": "Tools and materials for field repairs",
		"category": "Tool",
		"materials": {"iron_ingot": 1, "leather": 1},
		"gold_cost": 15,
		"required_engineering": 2,
		"output_item_id": "repair_kit",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# === MATERIALS ===

	# Iron Ingot (from ore)
	_add_recipe({
		"recipe_id": "smelt_iron",
		"display_name": "Smelt Iron Ingot",
		"description": "Smelt iron ore into a usable ingot",
		"category": "Material",
		"materials": {"iron_ore": 2},
		"gold_cost": 0,
		"required_engineering": 0,
		"output_item_id": "iron_ingot",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# Steel Ingot
	_add_recipe({
		"recipe_id": "forge_steel",
		"display_name": "Forge Steel Ingot",
		"description": "Combine iron and coal to create steel",
		"category": "Material",
		"materials": {"iron_ingot": 2, "coal": 1},
		"gold_cost": 5,
		"required_engineering": 2,
		"output_item_id": "steel_ingot",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# Leather Strip
	_add_recipe({
		"recipe_id": "cut_leather_strip",
		"display_name": "Cut Leather Strips",
		"description": "Cut leather into usable strips",
		"category": "Material",
		"materials": {"leather": 1},
		"gold_cost": 0,
		"required_engineering": 0,
		"output_item_id": "leather_strip",
		"output_quantity": 3,
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	print("[CraftingManager] Registered %d recipes" % recipes.size())


## Helper to create and register a recipe from dictionary
func _add_recipe(data: Dictionary) -> void:
	var recipe := CraftingRecipe.new()
	recipe.recipe_id = data.get("recipe_id", "")
	recipe.display_name = data.get("display_name", "Unknown")
	recipe.description = data.get("description", "")
	recipe.category = data.get("category", "Weapon")
	recipe.materials = data.get("materials", {})
	recipe.gold_cost = data.get("gold_cost", 0)
	recipe.required_engineering = data.get("required_engineering", 0)
	recipe.required_arcana = data.get("required_arcana", 0)
	recipe.output_item_id = data.get("output_item_id", "")
	recipe.output_quantity = data.get("output_quantity", 1)
	recipe.base_quality = data.get("base_quality", Enums.ItemQuality.AVERAGE)
	recipe.can_crit = data.get("can_crit", true)

	recipes[recipe.recipe_id] = recipe


## Get all recipes in a category
func get_recipes_by_category(category: String) -> Array[CraftingRecipe]:
	var result: Array[CraftingRecipe] = []
	for recipe_id in recipes:
		var recipe: CraftingRecipe = recipes[recipe_id]
		if recipe.category == category:
			result.append(recipe)
	return result


## Get recipes the player can currently craft
func get_craftable_recipes() -> Array[CraftingRecipe]:
	var result: Array[CraftingRecipe] = []
	for recipe_id in recipes:
		var recipe: CraftingRecipe = recipes[recipe_id]
		if recipe.meets_requirements() and recipe.can_craft():
			result.append(recipe)
	return result


## Craft a recipe by ID
func craft_recipe(recipe_id: String) -> Dictionary:
	if not recipes.has(recipe_id):
		return {"success": false, "reason": "Recipe not found"}

	var recipe: CraftingRecipe = recipes[recipe_id]
	var result := recipe.craft()

	if result.success:
		recipe_crafted.emit(recipe_id, result)

	return result


## Get a specific recipe
func get_recipe(recipe_id: String) -> CraftingRecipe:
	return recipes.get(recipe_id, null)
