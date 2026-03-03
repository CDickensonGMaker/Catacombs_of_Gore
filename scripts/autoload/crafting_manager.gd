## crafting_manager.gd - Manages crafting recipes and crafting operations
## Autoload singleton for crafting system
extends Node

signal recipe_crafted(recipe_id: String, result: Dictionary)

## All available recipes
var recipes: Dictionary = {}  # recipe_id -> CraftingRecipe

## Recipe categories for UI filtering
var categories: Array[String] = ["Weapon", "Armor", "Alchemy", "Consumable", "Tool", "Material", "Food", "Ammo"]


func _ready() -> void:
	_register_recipes()
	# Connect to quest system for craft objectives
	recipe_crafted.connect(_on_recipe_crafted)


## Notify quest system when a recipe is crafted
func _on_recipe_crafted(recipe_id: String, _result: Dictionary) -> void:
	if QuestManager:
		QuestManager.update_progress("craft", recipe_id, 1)


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

	# === ALCHEMY (Potions) ===

	# Health Potion
	_add_recipe({
		"recipe_id": "craft_health_potion",
		"display_name": "Health Potion",
		"description": "Brew a basic healing potion from red herbs",
		"category": "Alchemy",
		"materials": {"red_herb": 2, "empty_vial": 1},
		"gold_cost": 5,
		"required_engineering": 0,
		"output_item_id": "health_potion",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# Stamina Potion
	_add_recipe({
		"recipe_id": "craft_stamina_potion",
		"display_name": "Stamina Potion",
		"description": "An energizing draught brewed from forest mushrooms",
		"category": "Alchemy",
		"materials": {"mushroom": 2, "empty_vial": 1},
		"gold_cost": 10,
		"required_engineering": 0,
		"output_item_id": "stamina_potion",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# Mana Potion
	_add_recipe({
		"recipe_id": "craft_mana_potion",
		"display_name": "Mana Potion",
		"description": "A shimmering blue elixir that restores magical energy",
		"category": "Alchemy",
		"materials": {"blue_flower": 2, "empty_vial": 1},
		"gold_cost": 15,
		"required_arcana": 1,
		"output_item_id": "mana_potion",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# Antidote
	_add_recipe({
		"recipe_id": "craft_antidote",
		"display_name": "Antidote",
		"description": "A bitter herbal remedy that cures poison - made from venom itself",
		"category": "Alchemy",
		"materials": {"spider_venom": 1, "healing_herb": 1, "empty_vial": 1},
		"gold_cost": 10,
		"required_engineering": 0,
		"output_item_id": "antidote",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# Regeneration Potion (advanced)
	_add_recipe({
		"recipe_id": "craft_regeneration_potion",
		"display_name": "Regeneration Potion",
		"description": "A powerful healing draught that regenerates wounds over time",
		"category": "Alchemy",
		"materials": {"healing_herb": 2, "red_herb": 1, "mushroom": 1, "empty_vial": 1},
		"gold_cost": 30,
		"required_arcana": 2,
		"output_item_id": "regeneration_potion",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# Agility Elixir (advanced - uses bat wings per item description)
	_add_recipe({
		"recipe_id": "craft_agility_elixir",
		"display_name": "Agility Elixir",
		"description": "A dark, fizzing elixir brewed from bat wings that enhances reflexes",
		"category": "Alchemy",
		"materials": {"bat_wing": 2, "blue_flower": 1, "empty_vial": 1},
		"gold_cost": 25,
		"required_arcana": 2,
		"output_item_id": "agility_elixir",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# Strength Tonic (advanced - uses beast heart per item description)
	_add_recipe({
		"recipe_id": "craft_strength_tonic",
		"display_name": "Strength Tonic",
		"description": "A potent brew made from beast heart essence that grants raw strength",
		"category": "Alchemy",
		"materials": {"beast_heart": 1, "red_herb": 1, "empty_vial": 1},
		"gold_cost": 35,
		"required_arcana": 2,
		"output_item_id": "strength_tonic",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# === AMMO ===

	# Arrows (10)
	_add_recipe({
		"recipe_id": "craft_arrows",
		"display_name": "Arrows (10)",
		"description": "Craft a bundle of arrows",
		"category": "Ammo",
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

	# Silver Ingot (from ore)
	_add_recipe({
		"recipe_id": "smelt_silver",
		"display_name": "Smelt Silver Ingot",
		"description": "Smelt silver ore into a precious metal ingot",
		"category": "Material",
		"materials": {"silver_ore": 2},
		"gold_cost": 0,
		"required_engineering": 1,
		"output_item_id": "silver_ingot",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# Gold Ingot (from ore)
	_add_recipe({
		"recipe_id": "smelt_gold",
		"display_name": "Smelt Gold Ingot",
		"description": "Smelt gold ore into a precious metal ingot",
		"category": "Material",
		"materials": {"gold_ore": 2},
		"gold_cost": 0,
		"required_engineering": 2,
		"output_item_id": "gold_ingot",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# === JEWELRY (Basic - no stats, for enchanting) ===

	# Iron Ring
	_add_recipe({
		"recipe_id": "craft_iron_ring",
		"display_name": "Iron Ring",
		"description": "A simple iron band, perfect for enchanting",
		"category": "Armor",
		"materials": {"iron_ingot": 1},
		"gold_cost": 5,
		"required_engineering": 1,
		"output_item_id": "iron_ring",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# Silver Ring
	_add_recipe({
		"recipe_id": "craft_silver_ring",
		"display_name": "Silver Ring",
		"description": "A polished silver band that holds enchantments well",
		"category": "Armor",
		"materials": {"silver_ingot": 1},
		"gold_cost": 15,
		"required_engineering": 2,
		"output_item_id": "silver_ring",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# Gold Ring
	_add_recipe({
		"recipe_id": "craft_gold_ring",
		"display_name": "Gold Ring",
		"description": "A gleaming gold band, ideal for powerful enchantments",
		"category": "Armor",
		"materials": {"gold_ingot": 1},
		"gold_cost": 30,
		"required_engineering": 3,
		"output_item_id": "gold_ring",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# Copper Amulet
	_add_recipe({
		"recipe_id": "craft_copper_amulet",
		"display_name": "Copper Amulet",
		"description": "A simple copper pendant on a leather cord",
		"category": "Armor",
		"materials": {"iron_ingot": 1, "leather_strip": 1},
		"gold_cost": 10,
		"required_engineering": 1,
		"output_item_id": "copper_amulet",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# Silver Amulet
	_add_recipe({
		"recipe_id": "craft_silver_amulet",
		"display_name": "Silver Amulet",
		"description": "A silver pendant ready for enchantment",
		"category": "Armor",
		"materials": {"silver_ingot": 1, "leather_strip": 1},
		"gold_cost": 20,
		"required_engineering": 2,
		"output_item_id": "silver_amulet",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# Gold Amulet
	_add_recipe({
		"recipe_id": "craft_gold_amulet",
		"display_name": "Gold Amulet",
		"description": "A fine gold pendant for powerful enchantments",
		"category": "Armor",
		"materials": {"gold_ingot": 1, "leather_strip": 1},
		"gold_cost": 40,
		"required_engineering": 3,
		"output_item_id": "gold_amulet",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# === JEWELRY (Special - with unique effects) ===

	# Bone Ring
	_add_recipe({
		"recipe_id": "craft_bone_ring",
		"display_name": "Bone Ring",
		"description": "A ring carved from bone with necromantic properties",
		"category": "Armor",
		"materials": {"iron_ingot": 1, "soul_essence": 1},
		"gold_cost": 25,
		"required_engineering": 2,
		"required_arcana": 2,
		"output_item_id": "bone_ring",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# Serpent Ring
	_add_recipe({
		"recipe_id": "craft_serpent_ring",
		"display_name": "Serpent Ring",
		"description": "A coiled silver serpent that grants agility",
		"category": "Armor",
		"materials": {"silver_ingot": 2, "basilisk_scale": 1},
		"gold_cost": 50,
		"required_engineering": 3,
		"output_item_id": "serpent_ring",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# Flame Heart Ring
	_add_recipe({
		"recipe_id": "craft_flame_heart_ring",
		"display_name": "Flame Heart Ring",
		"description": "A gold ring with a ruby that burns with inner fire",
		"category": "Armor",
		"materials": {"gold_ingot": 1, "ember_dust": 3},
		"gold_cost": 75,
		"required_engineering": 3,
		"required_arcana": 3,
		"output_item_id": "flame_heart_ring",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# Wolf Fang Necklace
	_add_recipe({
		"recipe_id": "craft_wolf_fang_necklace",
		"display_name": "Wolf Fang Necklace",
		"description": "A primal necklace strung with wolf fangs",
		"category": "Armor",
		"materials": {"wolf_fang": 3, "leather_strip": 2},
		"gold_cost": 15,
		"required_engineering": 1,
		"output_item_id": "wolf_fang_necklace",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# Spider Silk Pendant
	_add_recipe({
		"recipe_id": "craft_spider_silk_pendant",
		"display_name": "Spider Silk Pendant",
		"description": "A pendant wrapped in enchanted spider silk",
		"category": "Armor",
		"materials": {"silver_ingot": 1, "spider_silk": 3, "spider_venom": 1},
		"gold_cost": 40,
		"required_engineering": 2,
		"required_arcana": 2,
		"output_item_id": "spider_silk_pendant",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# Frost Crystal Pendant
	_add_recipe({
		"recipe_id": "craft_frost_crystal_pendant",
		"display_name": "Frost Crystal Pendant",
		"description": "A pendant containing an eternally frozen crystal",
		"category": "Armor",
		"materials": {"silver_ingot": 2, "soul_essence": 1},
		"gold_cost": 60,
		"required_engineering": 3,
		"required_arcana": 3,
		"output_item_id": "frost_crystal_pendant",
		"base_quality": Enums.ItemQuality.AVERAGE
	})

	# === FOOD (Cooking) ===

	# Cooked Meat
	_add_recipe({
		"recipe_id": "cook_meat",
		"display_name": "Cooked Meat",
		"description": "Roast raw meat over the fire for a filling meal that restores health over time",
		"category": "Food",
		"materials": {"raw_meat": 1},
		"gold_cost": 0,
		"required_engineering": 0,
		"output_item_id": "cooked_meat",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# Hearty Stew
	_add_recipe({
		"recipe_id": "cook_stew",
		"display_name": "Hearty Stew",
		"description": "A nourishing stew that restores both health and stamina",
		"category": "Food",
		"materials": {"raw_meat": 1, "potato": 1, "carrot": 1},
		"gold_cost": 0,
		"required_engineering": 0,
		"output_item_id": "hearty_stew",
		"base_quality": Enums.ItemQuality.AVERAGE,
		"can_crit": false
	})

	# Bread
	_add_recipe({
		"recipe_id": "bake_bread",
		"display_name": "Bread",
		"description": "Simple bread - a cheap way to restore a small amount of health",
		"category": "Food",
		"materials": {"flour": 1, "water": 1},
		"gold_cost": 0,
		"required_engineering": 0,
		"output_item_id": "bread",
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


## XP rewards for crafting (varies by category/difficulty)
const CRAFTING_XP_MIN := 5
const CRAFTING_XP_MAX := 15

## Craft a recipe by ID
func craft_recipe(recipe_id: String) -> Dictionary:
	if not recipes.has(recipe_id):
		return {"success": false, "reason": "Recipe not found"}

	var recipe: CraftingRecipe = recipes[recipe_id]
	var result := recipe.craft()

	if result.success:
		recipe_crafted.emit(recipe_id, result)

		# Award XP for crafting (5-15 based on recipe complexity)
		var xp_reward: int = _calculate_crafting_xp(recipe)
		if GameManager and GameManager.player_data:
			GameManager.player_data.add_ip(xp_reward)
			print("[CraftingManager] Awarded %d XP for crafting %s" % [xp_reward, recipe.display_name])

	return result


## Calculate XP reward based on recipe complexity
func _calculate_crafting_xp(recipe: CraftingRecipe) -> int:
	# Base XP varies by number of materials and category
	var base_xp: int = CRAFTING_XP_MIN

	# More materials = more XP
	var material_count: int = recipe.materials.size()
	base_xp += material_count * 2

	# Category bonus
	match recipe.category:
		"Weapon", "Armor":
			base_xp += 5  # Smithing is harder
		"Consumable", "Tool":
			base_xp += 3
		"Food":
			base_xp += 1  # Cooking is simpler

	return clampi(base_xp, CRAFTING_XP_MIN, CRAFTING_XP_MAX)


## Get a specific recipe
func get_recipe(recipe_id: String) -> CraftingRecipe:
	return recipes.get(recipe_id, null)


## Discover all recipes the player meets requirements for and add them to the codex
## Call this when crafting UI opens or when skills change
func discover_available_recipes() -> void:
	if not CodexManager:
		return

	for recipe_id: String in recipes:
		var recipe: CraftingRecipe = recipes[recipe_id]
		# If player meets skill requirements, add to codex
		if recipe.meets_requirements():
			# Map crafting category to codex category
			var codex_category: String = _get_codex_category(recipe.category)
			# Create recipe data for codex
			var recipe_data: Dictionary = {
				"id": recipe.recipe_id,
				"name": recipe.display_name,
				"description": recipe.description,
				"category": codex_category,
				"materials": recipe.materials,
				"output": recipe.output_item_id,
				"skill_required": max(recipe.required_engineering, recipe.required_arcana)
			}
			# Add to codex all_recipes if not already there
			if not CodexManager.all_recipes.has(recipe.recipe_id):
				CodexManager.all_recipes[recipe.recipe_id] = recipe_data
			# Discover it
			CodexManager.discover_recipe(recipe.recipe_id)


## Map crafting category to codex category
func _get_codex_category(crafting_category: String) -> String:
	match crafting_category:
		"Weapon", "Armor":
			return "smithing"
		"Alchemy", "Consumable":
			return "alchemy"
		"Food":
			return "cooking"
		"Tool", "Material", "Ammo":
			return "engineering"
		_:
			return "misc"
