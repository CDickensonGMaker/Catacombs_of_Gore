## enchantment_manager.gd - Manages enchantments, soulstones, and enchanting process
extends Node

signal enchantment_applied(item_id: String, slot: String, enchantment_id: String)
signal soulstone_filled(soulstone_item_id: String, tier: int)
signal soul_captured(enemy_level: int, soul_value: int)

## Enchantment database (loaded from resources)
var enchantment_database: Dictionary = {}  # id -> EnchantmentData

## Soulstone item IDs that are empty and can capture souls
const EMPTY_SOULSTONE_IDS: Array[String] = [
	"soulstone_petty_empty",
	"soulstone_lesser_empty",
	"soulstone_common_empty",
	"soulstone_greater_empty",
	"soulstone_grand_empty"
]

## Filled soulstone item IDs (parallel to empty)
const FILLED_SOULSTONE_IDS: Array[String] = [
	"soulstone_petty_filled",
	"soulstone_lesser_filled",
	"soulstone_common_filled",
	"soulstone_greater_filled",
	"soulstone_grand_filled"
]

## Soulstone tier data (threshold to fill, enchant power)
const SOULSTONE_TIERS: Dictionary = {
	1: {"name": "Petty", "threshold": 5, "power": 1.0},
	2: {"name": "Lesser", "threshold": 15, "power": 1.5},
	3: {"name": "Common", "threshold": 30, "power": 2.0},
	4: {"name": "Greater", "threshold": 60, "power": 3.0},
	5: {"name": "Grand", "threshold": 100, "power": 5.0}
}

## Track soul energy accumulation for each empty soulstone in inventory
## Format: {"item_id": current_energy}
var soulstone_energy: Dictionary = {}

func _ready() -> void:
	_load_enchantment_database()

	# Connect to CombatManager for enemy kill tracking
	if CombatManager:
		CombatManager.entity_killed.connect(_on_entity_killed)

## Load all enchantment resources
func _load_enchantment_database() -> void:
	var enchantment_files: Array[String] = [
		"lesser_flame", "greater_flame", "frost_touch", "shocking",
		"vampiric", "fortify_grit", "fortify_agility", "fortify_will",
		"resist_fire", "resist_frost", "resist_poison",
		"keen_edge", "protection"
	]

	for ench_id in enchantment_files:
		var path := "res://data/enchantments/%s.tres" % ench_id
		if ResourceLoader.exists(path):
			var ench: EnchantmentData = load(path) as EnchantmentData
			if ench and ench.id:
				enchantment_database[ench.id] = ench
				print("[EnchantmentManager] Loaded enchantment: ", ench.id)

	print("[EnchantmentManager] Loaded %d enchantments" % enchantment_database.size())

## Get enchantment by ID
func get_enchantment(enchantment_id: String) -> EnchantmentData:
	return enchantment_database.get(enchantment_id)

## Get all enchantments applicable to a slot
func get_enchantments_for_slot(slot: String) -> Array[EnchantmentData]:
	var result: Array[EnchantmentData] = []
	for ench_id in enchantment_database:
		var ench: EnchantmentData = enchantment_database[ench_id]
		if ench.can_apply_to_slot(slot):
			result.append(ench)
	return result

## Get all available enchantments (player meets requirements)
func get_available_enchantments(slot: String) -> Array[EnchantmentData]:
	var result: Array[EnchantmentData] = []
	var player_arcana: int = 0
	if GameManager and GameManager.player_data:
		player_arcana = GameManager.player_data.get_skill(Enums.Skill.ARCANA_LORE)

	for ench_id in enchantment_database:
		var ench: EnchantmentData = enchantment_database[ench_id]
		if ench.can_apply_to_slot(slot) and player_arcana >= ench.required_arcana:
			result.append(ench)
	return result

## Check if player can apply an enchantment
func can_apply_enchantment(enchantment_id: String, slot: String) -> Dictionary:
	var result := {
		"can_apply": false,
		"reason": ""
	}

	var ench: EnchantmentData = get_enchantment(enchantment_id)
	if not ench:
		result.reason = "Enchantment not found"
		return result

	# Check slot compatibility
	if not ench.can_apply_to_slot(slot):
		result.reason = "Cannot apply to this item type"
		return result

	# Check Arcana requirement
	var player_arcana: int = 0
	if GameManager and GameManager.player_data:
		player_arcana = GameManager.player_data.get_skill(Enums.Skill.ARCANA_LORE)
	if player_arcana < ench.required_arcana:
		result.reason = "Requires Arcana Lore %d (have %d)" % [ench.required_arcana, player_arcana]
		return result

	# Check gold
	if InventoryManager.gold < ench.gold_cost:
		result.reason = "Not enough gold (%d required)" % ench.gold_cost
		return result

	# Check for filled soulstone of required tier
	if not _has_filled_soulstone(ench.min_soulstone_tier):
		result.reason = "Requires %s soulstone or higher" % SoulstoneData.get_tier_name(ench.min_soulstone_tier)
		return result

	# Check if item already has max enchantments (1 for now)
	var equip_data: Dictionary = InventoryManager.equipment.get(slot, {})
	if equip_data.has("enchantments") and equip_data.enchantments.size() >= 1:
		result.reason = "Item already enchanted"
		return result

	result.can_apply = true
	return result

## Apply an enchantment to equipped item
func apply_enchantment(enchantment_id: String, slot: String) -> bool:
	var check := can_apply_enchantment(enchantment_id, slot)
	if not check.can_apply:
		push_warning("[EnchantmentManager] Cannot apply: " + check.reason)
		return false

	var ench: EnchantmentData = get_enchantment(enchantment_id)

	# Deduct gold
	InventoryManager.remove_gold(ench.gold_cost)

	# Consume soulstone
	_consume_soulstone(ench.min_soulstone_tier)

	# Add enchantment to equipment
	var equip_data: Dictionary = InventoryManager.equipment[slot]
	if not equip_data.has("enchantments"):
		equip_data["enchantments"] = []
	equip_data.enchantments.append(enchantment_id)

	# Emit signal
	enchantment_applied.emit(equip_data.get("item_id", ""), slot, enchantment_id)

	print("[EnchantmentManager] Applied %s to %s" % [enchantment_id, slot])
	return true

## Get enchantments on an equipped item
func get_item_enchantments(slot: String) -> Array[EnchantmentData]:
	var result: Array[EnchantmentData] = []
	var equip_data: Dictionary = InventoryManager.equipment.get(slot, {})
	if equip_data.has("enchantments"):
		for ench_id in equip_data.enchantments:
			var ench: EnchantmentData = get_enchantment(ench_id)
			if ench:
				result.append(ench)
	return result

## Calculate total bonus from enchantments on item
## Returns Dictionary with bonus values
func get_enchantment_bonuses(slot: String) -> Dictionary:
	var bonuses := {
		"damage_bonus": {},     # DamageType -> value
		"resistance": {},       # DamageType -> value
		"stat_bonus": {},       # Stat -> value
		"lifesteal": 0,
		"armor_bonus": 0,
		"crit_bonus": 0,
		"mana_bonus": 0,
		"stamina_bonus": 0,
		"health_bonus": 0,
		"conditions_on_hit": []  # Array of {condition, chance, duration}
	}

	var enchantments := get_item_enchantments(slot)
	for ench in enchantments:
		match ench.enchantment_type:
			EnchantmentData.EnchantmentType.DAMAGE_BONUS:
				if not bonuses.damage_bonus.has(ench.damage_type):
					bonuses.damage_bonus[ench.damage_type] = 0
				bonuses.damage_bonus[ench.damage_type] += ench.effect_value

			EnchantmentData.EnchantmentType.RESISTANCE:
				if not bonuses.resistance.has(ench.damage_type):
					bonuses.resistance[ench.damage_type] = 0
				bonuses.resistance[ench.damage_type] += ench.effect_value

			EnchantmentData.EnchantmentType.STAT_BONUS:
				if not bonuses.stat_bonus.has(ench.stat_type):
					bonuses.stat_bonus[ench.stat_type] = 0
				bonuses.stat_bonus[ench.stat_type] += ench.effect_value

			EnchantmentData.EnchantmentType.LIFESTEAL:
				bonuses.lifesteal += ench.effect_value

			EnchantmentData.EnchantmentType.ARMOR_BONUS:
				bonuses.armor_bonus += ench.effect_value

			EnchantmentData.EnchantmentType.CRIT_BONUS:
				bonuses.crit_bonus += ench.effect_value

			EnchantmentData.EnchantmentType.MANA_BONUS:
				bonuses.mana_bonus += ench.effect_value

			EnchantmentData.EnchantmentType.STAMINA_BONUS:
				bonuses.stamina_bonus += ench.effect_value

			EnchantmentData.EnchantmentType.HEALTH_BONUS:
				bonuses.health_bonus += ench.effect_value

			EnchantmentData.EnchantmentType.CONDITION_ON_HIT:
				bonuses.conditions_on_hit.append({
					"condition": ench.inflicts_condition,
					"chance": ench.proc_chance,
					"duration": ench.condition_duration
				})

	return bonuses

## Called when an entity is killed - capture soul if player has empty soulstones
func _on_entity_killed(entity: Node, killer: Node) -> void:
	# Only capture souls when player kills enemies
	if not killer or not killer.is_in_group("player"):
		return

	# Get enemy level for soul value
	var enemy_level: int = 1
	if entity.has_method("get_enemy_data"):
		var enemy_data = entity.get_enemy_data()
		if enemy_data and enemy_data.level:
			enemy_level = enemy_data.level

	# Calculate soul value: ceil(enemy_level / 2)
	var soul_value: int = ceili(float(enemy_level) / 2.0)

	# Add soul energy to lowest tier empty soulstone
	_add_soul_energy(soul_value, enemy_level)

## Add soul energy to empty soulstones in inventory
func _add_soul_energy(energy: int, enemy_level: int) -> void:
	# Find lowest tier empty soulstone
	for tier in range(1, 6):
		var empty_id: String = EMPTY_SOULSTONE_IDS[tier - 1]
		if InventoryManager.has_item(empty_id):
			# Initialize tracking if needed
			if not soulstone_energy.has(empty_id):
				soulstone_energy[empty_id] = 0

			soulstone_energy[empty_id] += energy
			var threshold: int = SOULSTONE_TIERS[tier]["threshold"]

			# Check if filled
			if soulstone_energy[empty_id] >= threshold:
				# Convert empty to filled
				InventoryManager.remove_item(empty_id, 1)
				var filled_id: String = FILLED_SOULSTONE_IDS[tier - 1]
				InventoryManager.add_item(filled_id, 1)
				soulstone_energy.erase(empty_id)

				soulstone_filled.emit(filled_id, tier)
				print("[EnchantmentManager] Soulstone filled: %s" % filled_id)

				# Show notification
				var hud := get_tree().get_first_node_in_group("hud")
				if hud and hud.has_method("show_notification"):
					hud.show_notification("%s Soulstone filled!" % SoulstoneData.get_tier_name(tier))

			soul_captured.emit(enemy_level, energy)
			return  # Only charge one soulstone at a time

## Check if player has a filled soulstone of at least the given tier
func _has_filled_soulstone(min_tier: int) -> bool:
	for tier in range(min_tier, 6):
		var filled_id: String = FILLED_SOULSTONE_IDS[tier - 1]
		if InventoryManager.has_item(filled_id):
			return true
	return false

## Consume a filled soulstone of at least the given tier
func _consume_soulstone(min_tier: int) -> bool:
	for tier in range(min_tier, 6):
		var filled_id: String = FILLED_SOULSTONE_IDS[tier - 1]
		if InventoryManager.has_item(filled_id):
			InventoryManager.remove_item(filled_id, 1)
			return true
	return false

## Get soulstone charging progress
func get_soulstone_progress() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tier in range(1, 6):
		var empty_id: String = EMPTY_SOULSTONE_IDS[tier - 1]
		if InventoryManager.has_item(empty_id):
			var current: int = soulstone_energy.get(empty_id, 0)
			var threshold: int = SOULSTONE_TIERS[tier]["threshold"]
			result.append({
				"tier": tier,
				"name": SOULSTONE_TIERS[tier]["name"],
				"current": current,
				"threshold": threshold,
				"percent": float(current) / float(threshold) * 100.0
			})
	return result

## Save enchantment data
func get_save_data() -> Dictionary:
	return {
		"soulstone_energy": soulstone_energy.duplicate()
	}

## Load enchantment data
func load_save_data(data: Dictionary) -> void:
	soulstone_energy = data.get("soulstone_energy", {}).duplicate()
