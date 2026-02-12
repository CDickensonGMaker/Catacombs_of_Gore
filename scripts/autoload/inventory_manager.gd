## inventory_manager.gd - Manages player inventory, equipment, and items
extends Node

signal item_added(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)
signal item_used(item_id: String)
signal equipment_changed(slot: String, old_item: Dictionary, new_item: Dictionary)
signal gold_changed(old_amount: int, new_amount: int)
signal quick_slot_changed(slot_index: int, item_id: String)
signal item_degraded(slot: String, item_id: String, new_quality: Enums.ItemQuality)
signal item_repaired(slot: String, item_id: String, durability_restored: int)
signal hotbar_changed(slot: int, data: Dictionary)
signal equipped_spell_changed(old_spell: SpellData, new_spell: SpellData)

## Inventory storage: Array of {item_id, quantity, quality, instance_data}
var inventory: Array[Dictionary] = []

## Equipment slots
var equipment: Dictionary = {
	"main_hand": {},
	"off_hand": {},
	"head": {},
	"body": {},
	"hands": {},
	"feet": {},
	"ring_1": {},
	"ring_2": {},
	"amulet": {}
}

## Quick slots (1-4) - DEPRECATED: Use hotbar instead
var quick_slots: Array[String] = ["", "", "", ""]

## Universal hotbar (10 slots, keys 1-9 and 0)
## Each slot: {"type": "weapon"|"spell"|"item"|"", "id": String}
var hotbar: Array[Dictionary] = []

## Currently equipped spell (like main_hand for spells)
var equipped_spell: SpellData = null

## Gold
var gold: int = 300  # Starting gold

## Item database references (loaded from resources)
var weapon_database: Dictionary = {}
var armor_database: Dictionary = {}
var item_database: Dictionary = {}
var spell_database: Dictionary = {}

## No hard limit on inventory slots - use encumbrance penalty instead
## Items can always be picked up, but being overencumbered has penalties

func _ready() -> void:
	_initialize_hotbar()
	_load_item_databases()
	# Give player 3 random starter items
	call_deferred("_give_starter_items")

## Initialize hotbar with 10 empty slots
func _initialize_hotbar() -> void:
	hotbar.clear()
	for i in range(10):
		hotbar.append({"type": "", "id": ""})

## Load all item resources into databases
func _load_item_databases() -> void:
	print("[InventoryManager] Starting database loading...")

	# Load weapons - explicitly list known weapon files for reliability
	# Use direct load() instead of ResourceLoader.exists() which can be unreliable
	var weapon_files := [
		"dagger", "longsword", "battleaxe", "flamebrand",
		"hunting_bow", "crossbow", "musket",
		"iron_sword", "steel_sword", "iron_dagger"
	]
	for weapon_id in weapon_files:
		var path := "res://data/weapons/%s.tres" % weapon_id
		var weapon = load(path)
		if weapon and weapon is WeaponData and weapon.id:
			weapon_database[weapon.id] = weapon
			print("[InventoryManager] Loaded weapon: %s (id=%s)" % [path, weapon.id])
		else:
			print("[InventoryManager] FAILED to load weapon: %s" % path)

	# Load armor - explicitly list known armor files
	var armor_files := [
		"leather_armor", "chainmail", "wooden_shield",
		"ring_of_protection", "ring_of_strength",
		"amulet_of_vitality", "amulet_of_wisdom"
	]
	for armor_id in armor_files:
		var path := "res://data/armor/%s.tres" % armor_id
		var armor = load(path)
		if armor and armor is ArmorData and armor.id:
			armor_database[armor.id] = armor
			print("[InventoryManager] Loaded armor: %s (id=%s)" % [path, armor.id])
		else:
			print("[InventoryManager] FAILED to load armor: %s" % path)

	# Load items - explicitly list known item files
	var item_files := [
		"health_potion", "stamina_potion", "mana_potion", "antidote",
		"arrows", "bolts", "lead_balls",
		# Original scrolls
		"scroll_magic_missile", "scroll_lightning_bolt",
		"scroll_healing_light", "scroll_soul_drain",
		# New scrolls
		"scroll_armor", "scroll_blind", "scroll_dispel_magic",
		"scroll_fireball", "scroll_haste", "scroll_slow",
		"scroll_ice_storm", "scroll_fire_gate",
		"scroll_cone_of_cold", "scroll_iron_guard", "scroll_chain_lightning",
		# Quest items
		"corrupted_totem_shard", "goblin_war_horn", "bandit_bounty_note",
		# Materials
		"iron_ore", "iron_ingot", "gold_ore", "stone_block",
		"steel_ingot", "coal", "leather", "leather_strip",
		"wood_plank", "red_herb", "empty_vial",
		# Food and consumables
		"bread", "cheese", "cooked_meat", "ale",
		# Tools
		"lockpick", "repair_kit", "bedroll"
	]
	for item_id in item_files:
		var path := "res://data/items/%s.tres" % item_id
		var item = load(path)
		if item and item is ItemData and item.id:
			item_database[item.id] = item
			print("[InventoryManager] Loaded item: %s (id=%s)" % [path, item.id])
		else:
			print("[InventoryManager] FAILED to load item: %s" % path)

	# Load spells - explicitly list known spell files
	var spell_files := [
		# Original spells
		"magic_missile", "lightning_bolt", "healing_light", "soul_drain",
		# New spells
		"armor", "blind", "dispel_magic", "fireball", "haste", "slow",
		"ice_storm", "fire_gate", "cone_of_cold", "iron_guard", "chain_lightning"
	]
	for spell_id in spell_files:
		var path := "res://data/spells/%s.tres" % spell_id
		var spell = load(path)
		if spell and spell is SpellData and spell.id:
			spell_database[spell.id] = spell
			print("[InventoryManager] Loaded spell: %s (id=%s)" % [path, spell.id])
		else:
			print("[InventoryManager] FAILED to load spell: %s" % path)

	print("[InventoryManager] Database loading complete:")
	print("[InventoryManager]   Loaded %d weapons, %d armor, %d items, %d spells" % [
		weapon_database.size(), armor_database.size(), item_database.size(), spell_database.size()
	])
	print("[InventoryManager] Weapon IDs: %s" % str(weapon_database.keys()))
	print("[InventoryManager] Armor IDs: %s" % str(armor_database.keys()))
	print("[InventoryManager] Item IDs: %s" % str(item_database.keys()))

## Add an item to inventory
func add_item(item_id: String, quantity: int = 1, quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE) -> bool:
	# Check if item exists in any database
	if not _item_exists(item_id):
		push_warning("Item not found: " + item_id)
		return false

	# Only weapons and armor can have quality modifiers
	# All other items (consumables, materials, tools) are always AVERAGE
	if not _is_equipment(item_id):
		quality = Enums.ItemQuality.AVERAGE

	# No hard limit - items can always be picked up
	# Encumbrance penalty applies if player is overweight

	# Try to stack with existing item
	for i in range(inventory.size()):
		var slot: Dictionary = inventory[i]
		if slot.item_id == item_id and slot.quality == quality:
			if _is_stackable(item_id):
				var max_stack := _get_max_stack(item_id)
				var space: int = max_stack - slot.quantity
				if space > 0:
					var to_add: int = min(quantity, space)
					slot.quantity += to_add
					quantity -= to_add
					item_added.emit(item_id, to_add)
					if quantity <= 0:
						return true

	# Add as new slot(s) - no limit, just add until all quantity is placed
	while quantity > 0:
		var max_stack := _get_max_stack(item_id)
		var to_add: int = min(quantity, max_stack)
		inventory.append({
			"item_id": item_id,
			"quantity": to_add,
			"quality": quality,
			"instance_data": {}
		})
		quantity -= to_add
		item_added.emit(item_id, to_add)

	return true

## Remove an item from inventory
## NOTE: Quality must match EXACTLY - no wildcards allowed to prevent selling exploits
func remove_item(item_id: String, quantity: int = 1, quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE) -> bool:
	if quantity <= 0:
		push_warning("remove_item: Invalid quantity %d (must be positive)" % quantity)
		return false

	var removed := 0

	for i in range(inventory.size() - 1, -1, -1):
		if removed >= quantity:
			break

		var slot: Dictionary = inventory[i]
		# Quality must match exactly - no AVERAGE wildcard
		if slot.item_id == item_id and slot.quality == quality:
			var to_remove: int = min(quantity - removed, slot.quantity)
			slot.quantity -= to_remove
			removed += to_remove

			if slot.quantity <= 0:
				inventory.remove_at(i)

	if removed > 0:
		item_removed.emit(item_id, removed)

	return removed >= quantity

## Remove an item regardless of quality (for crafting materials)
## Will consume from any quality stack, preferring lower quality first
func remove_item_any_quality(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		push_warning("remove_item_any_quality: Invalid quantity %d (must be positive)" % quantity)
		return false

	# First check if we have enough total
	if get_item_count(item_id) < quantity:
		return false

	var remaining := quantity

	# Sort inventory indices by quality (lowest first) so we consume poor quality items before good ones
	var slots_with_item: Array[Dictionary] = []
	for i in range(inventory.size()):
		var slot: Dictionary = inventory[i]
		if slot.item_id == item_id:
			slots_with_item.append({"index": i, "quality": slot.quality, "quantity": slot.quantity})

	# Sort by quality (ascending - poor first)
	slots_with_item.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.quality < b.quality
	)

	# Remove from lowest quality first
	for slot_info in slots_with_item:
		if remaining <= 0:
			break

		var idx: int = slot_info.index
		# Re-fetch slot since indices may shift after removal
		if idx >= inventory.size():
			continue

		var slot: Dictionary = inventory[idx]
		if slot.item_id != item_id:
			continue

		var to_remove: int = mini(remaining, slot.quantity)
		slot.quantity -= to_remove
		remaining -= to_remove

		if slot.quantity <= 0:
			inventory.remove_at(idx)
			# Adjust indices for remaining slots
			for j in range(slots_with_item.size()):
				if slots_with_item[j].index > idx:
					slots_with_item[j].index -= 1

	if remaining <= 0:
		item_removed.emit(item_id, quantity)
		return true

	return false


## Remove an item by inventory index (safer for shop transactions)
## Returns true if successfully removed
func remove_item_at_index(index: int, quantity: int = 1) -> bool:
	if index < 0 or index >= inventory.size():
		push_warning("remove_item_at_index: Invalid index %d" % index)
		return false

	if quantity <= 0:
		push_warning("remove_item_at_index: Invalid quantity %d (must be positive)" % quantity)
		return false

	var slot: Dictionary = inventory[index]
	if slot.quantity < quantity:
		push_warning("remove_item_at_index: Not enough quantity. Have %d, need %d" % [slot.quantity, quantity])
		return false

	var item_id: String = slot.item_id
	slot.quantity -= quantity

	if slot.quantity <= 0:
		inventory.remove_at(index)

	item_removed.emit(item_id, quantity)
	return true

## Get quantity of an item in inventory
func get_item_count(item_id: String) -> int:
	var count := 0
	for slot in inventory:
		if slot.item_id == item_id:
			count += slot.quantity
	return count

## Check if player has item
func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_count(item_id) >= quantity

## Equip an item from inventory
func equip_item(inventory_index: int) -> bool:
	if inventory_index < 0 or inventory_index >= inventory.size():
		return false

	var item_slot: Dictionary = inventory[inventory_index]
	var item_id: String = item_slot.item_id
	var quality: Enums.ItemQuality = item_slot.quality

	# Determine which equipment slot
	var equip_slot := ""
	var item_data: Resource = null

	if weapon_database.has(item_id):
		item_data = weapon_database[item_id]
		equip_slot = "main_hand"
		# Two-handed weapons clear off-hand
		if (item_data as WeaponData).two_handed:
			_unequip_to_inventory("off_hand")
	elif armor_database.has(item_id):
		item_data = armor_database[item_id]
		var armor := item_data as ArmorData
		match armor.slot:
			Enums.ArmorSlot.HEAD: equip_slot = "head"
			Enums.ArmorSlot.BODY: equip_slot = "body"
			Enums.ArmorSlot.HANDS: equip_slot = "hands"
			Enums.ArmorSlot.FEET: equip_slot = "feet"
			Enums.ArmorSlot.RING_1: equip_slot = "ring_1"
			Enums.ArmorSlot.RING_2:
				# If ring_1 is empty, use that
				if equipment.ring_1.is_empty():
					equip_slot = "ring_1"
				else:
					equip_slot = "ring_2"
			Enums.ArmorSlot.AMULET: equip_slot = "amulet"
			Enums.ArmorSlot.SHIELD: equip_slot = "off_hand"
	else:
		return false  # Not equippable

	if equip_slot.is_empty():
		return false

	# Unequip current item in slot
	var old_item: Dictionary = equipment[equip_slot].duplicate()
	_unequip_to_inventory(equip_slot)

	# Equip new item
	equipment[equip_slot] = {
		"item_id": item_id,
		"quality": quality,
		"data": item_data,
		"durability": get_max_durability(quality),
		"max_durability": get_max_durability(quality)
	}

	# Remove from inventory
	item_slot.quantity -= 1
	if item_slot.quantity <= 0:
		inventory.remove_at(inventory_index)

	equipment_changed.emit(equip_slot, old_item, equipment[equip_slot])
	return true

## Unequip an item to inventory
func unequip_item(slot: String) -> bool:
	return _unequip_to_inventory(slot)

func _unequip_to_inventory(slot: String) -> bool:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return true  # Already empty

	var item: Dictionary = equipment[slot]
	var old_item := item.duplicate()

	# Add to inventory
	if not add_item(item.item_id, 1, item.quality):
		return false  # Inventory full

	equipment[slot] = {}
	equipment_changed.emit(slot, old_item, {})
	return true

## Use a consumable item or scroll
func use_item(inventory_index: int) -> bool:
	if inventory_index < 0 or inventory_index >= inventory.size():
		return false

	var item_slot: Dictionary = inventory[inventory_index]
	var item_id: String = item_slot.item_id

	if not item_database.has(item_id):
		return false

	var item: ItemData = item_database[item_id]

	var success := false

	match item.item_type:
		ItemData.ItemType.CONSUMABLE:
			success = _apply_item_effect(item)
		ItemData.ItemType.SCROLL:
			success = _use_scroll(item)
		ItemData.ItemType.REPAIR_KIT:
			success = _use_repair_kit(item)
		ItemData.ItemType.BEDROLL:
			success = _use_bedroll()
		_:
			return false  # Other item types cannot be used

	if not success:
		return false

	# Remove item
	item_slot.quantity -= 1
	if item_slot.quantity <= 0:
		inventory.remove_at(inventory_index)

	item_used.emit(item_id)
	return true

## Use a spell scroll to learn the spell
func _use_scroll(item: ItemData) -> bool:
	print("[InventoryManager] _use_scroll called for: %s" % item.id)

	if item.teaches_spell_id.is_empty():
		push_warning("Scroll has no teaches_spell_id: " + item.id)
		return false

	print("[InventoryManager] Scroll teaches spell: %s" % item.teaches_spell_id)

	# Get player's SpellCaster component
	var player := GameManager.get_tree().get_first_node_in_group("player")
	if not player:
		print("[InventoryManager] ERROR: No player found!")
		return false

	var spell_caster: SpellCaster = player.get_node_or_null("SpellCaster")
	if not spell_caster:
		# Try to find it as a child
		for child in player.get_children():
			if child is SpellCaster:
				spell_caster = child
				break

	if not spell_caster:
		push_warning("Player has no SpellCaster component")
		print("[InventoryManager] ERROR: No SpellCaster component found on player!")
		return false

	print("[InventoryManager] Found SpellCaster at path: %s, current known spells: %d" % [spell_caster.get_path(), spell_caster.known_spells.size()])

	# Check if already knows the spell
	for known in spell_caster.known_spells:
		if known and known.id == item.teaches_spell_id:
			push_warning("Player already knows spell: " + item.teaches_spell_id)
			# Show notification that spell is already known
			var hud = GameManager.get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_notification"):
				hud.show_notification("You already know this spell!")
			return false

	# REMOVED: Arcana Lore skill check - scrolls can now be read without skill requirements
	# var player_data := GameManager.player_data
	# if player_data:
	# 	var arcana_lore: int = player_data.get_skill(Enums.Skill.ARCANA_LORE)
	# 	# Simple check: arcana_lore must be >= literacy_dc / 5 (scaled down)
	# 	@warning_ignore("integer_division")
	# 	var required_skill := item.literacy_dc / 5
	# 	if arcana_lore < required_skill:
	# 		push_warning("Insufficient Arcana Lore to read scroll. Need: %d, Have: %d" % [required_skill, arcana_lore])
	# 		# Show notification for insufficient skill
	# 		var hud = GameManager.get_tree().get_first_node_in_group("hud")
	# 		if hud and hud.has_method("show_notification"):
	# 			hud.show_notification("You lack the Arcana Lore to read this scroll!")
	# 		return false

	# Learn the spell
	print("[InventoryManager] Attempting to learn spell: %s" % item.teaches_spell_id)
	if spell_caster.learn_spell_by_id(item.teaches_spell_id):
		print("[InventoryManager] SUCCESS: Spell learned!")
		# Show notification for new spell learned
		var hud = GameManager.get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			var spell: SpellData = spell_database.get(item.teaches_spell_id)
			var spell_name: String = spell.display_name if spell else item.teaches_spell_id
			hud.show_notification("NEW SPELL LEARNED: " + spell_name)
		return true

	print("[InventoryManager] FAILED: learn_spell_by_id returned false")
	return false

## Apply consumable effect
func _apply_item_effect(item: ItemData) -> bool:
	var player_data := GameManager.player_data
	if not player_data:
		return false

	match item.consumable_effect:
		ItemData.ConsumableEffect.HEAL_HP:
			var heal_amount := item.roll_effect()
			# Apply First Aid skill bonus
			var first_aid := player_data.get_skill(Enums.Skill.FIRST_AID)
			heal_amount = int(heal_amount * (1.0 + first_aid * 0.1))
			player_data.heal(heal_amount)
			return true

		ItemData.ConsumableEffect.RESTORE_STAMINA:
			var restore := item.roll_effect()
			player_data.current_stamina = min(player_data.max_stamina, player_data.current_stamina + restore)
			return true

		ItemData.ConsumableEffect.RESTORE_MANA:
			var restore := item.roll_effect()
			player_data.restore_mana(restore)
			return true

		ItemData.ConsumableEffect.RESTORE_SPELL_SLOTS:
			player_data.restore_spell_slots(item.effect_value[2])
			return true

		ItemData.ConsumableEffect.CURE_POISON:
			player_data.remove_condition(Enums.Condition.POISONED)
			return true

		ItemData.ConsumableEffect.CURE_ALL_CONDITIONS:
			for cond in player_data.conditions.keys():
				player_data.remove_condition(cond)
			return true

		# Buff effects would need a buff system on the player
		_:
			return false

## Use a repair kit on equipped items
## Repairs the most damaged piece of equipment
func _use_repair_kit(item: ItemData) -> bool:
	# Find the equipment slot with lowest durability percentage
	var worst_slot: String = ""
	var worst_durability_pct: float = 1.0

	for slot in equipment.keys():
		if equipment[slot].is_empty():
			continue

		var dur_pct := get_equipment_durability_percent(slot)
		if dur_pct < worst_durability_pct:
			worst_durability_pct = dur_pct
			worst_slot = slot

	if worst_slot.is_empty():
		push_warning("No equipment to repair")
		return false

	if worst_durability_pct >= 1.0:
		push_warning("All equipment is at full durability")
		return false

	# Apply repair
	if item.repairs_quality:
		# Quality restoration kit
		return restore_equipment_quality(worst_slot)
	else:
		# Standard repair kit
		return repair_with_kit(worst_slot, item.repair_amount)

## Use a bedroll for wilderness rest
## Provides 25% recovery and resets diminishing returns
func _use_bedroll() -> bool:
	# Delegate to RestManager
	if RestManager:
		return RestManager.use_bedroll()
	else:
		push_warning("RestManager not available")
		return false

## Set quick slot
func set_quick_slot(slot_index: int, item_id: String) -> void:
	if slot_index < 0 or slot_index >= 4:
		return
	quick_slots[slot_index] = item_id
	quick_slot_changed.emit(slot_index, item_id)

## Use quick slot
func use_quick_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= 4:
		return false

	var item_id: String = quick_slots[slot_index]
	if item_id.is_empty():
		return false

	# Find item in inventory
	for i in range(inventory.size()):
		var slot: Dictionary = inventory[i]
		if slot.item_id == item_id:
			return use_item(i)

	return false

# ============================================================================
# HOTBAR SYSTEM (Skyrim-style universal hotkeys)
# ============================================================================

## Set a hotbar slot (0-9 for keys 1-9,0)
## type: "weapon", "spell", or "item"
## id: the item/spell ID
func set_hotbar_slot(slot_index: int, type: String, id: String) -> void:
	if slot_index < 0 or slot_index >= 10:
		return

	hotbar[slot_index] = {"type": type, "id": id}
	hotbar_changed.emit(slot_index, hotbar[slot_index])

## Clear a hotbar slot
func clear_hotbar_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= 10:
		return

	hotbar[slot_index] = {"type": "", "id": ""}
	hotbar_changed.emit(slot_index, hotbar[slot_index])

## Use a hotbar slot (Skyrim-style toggle behavior)
## - Weapon: equips to main_hand; if already equipped, unequips (sheathe)
## - Spell: equips spell; if already equipped, unequips (back to weapon)
## - Item: uses immediately (consumable)
func use_hotbar_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= 10:
		return false

	var slot_data: Dictionary = hotbar[slot_index]
	if slot_data.type.is_empty() or slot_data.id.is_empty():
		return false

	match slot_data.type:
		"weapon":
			# Check if this weapon is already equipped - toggle off
			var current_weapon := get_equipped_weapon()
			if current_weapon and current_weapon.id == slot_data.id:
				# Already equipped - unequip (sheathe)
				_unequip_weapon()
				return true
			return _equip_weapon_from_hotbar(slot_data.id)
		"spell":
			# Check if this spell is already equipped - toggle off
			if equipped_spell and equipped_spell.id == slot_data.id:
				# Already equipped - unequip (back to weapon)
				clear_equipped_spell()
				return true
			return equip_spell(slot_data.id)
		"item":
			return _use_item_from_hotbar(slot_data.id)

	return false

## Unequip current weapon (sheathe/go to unarmed)
func _unequip_weapon() -> void:
	# Clear equipped spell first if any
	if equipped_spell:
		clear_equipped_spell()
	# Note: Could also unequip from main_hand here if desired
	# For now, clearing spell is enough to "sheathe"

## Equip weapon from hotbar by ID
func _equip_weapon_from_hotbar(weapon_id: String) -> bool:
	# Clear equipped spell when equipping weapon
	if equipped_spell:
		clear_equipped_spell()

	# Check if already equipped
	if not equipment.main_hand.is_empty() and equipment.main_hand.item_id == weapon_id:
		return true  # Already equipped

	# Find weapon in inventory and equip it
	for i in range(inventory.size()):
		if inventory[i].item_id == weapon_id:
			return equip_item(i)

	# Weapon not in inventory - check if it's in our database at least
	if weapon_database.has(weapon_id):
		push_warning("Weapon %s not in inventory" % weapon_id)
	return false

## Use item from hotbar by ID
func _use_item_from_hotbar(item_id: String) -> bool:
	# Find item in inventory and use it
	for i in range(inventory.size()):
		if inventory[i].item_id == item_id:
			return use_item(i)

	push_warning("Item %s not in inventory" % item_id)
	return false

## Equip a spell by ID (sets as active spell for casting via left-click)
func equip_spell(spell_id: String) -> bool:
	var spell: SpellData = null

	# Try to find in spell database
	if spell_database.has(spell_id):
		spell = spell_database[spell_id]
	else:
		# Try to load directly
		var spell_path := "res://data/spells/%s.tres" % spell_id
		if ResourceLoader.exists(spell_path):
			spell = load(spell_path) as SpellData

	if not spell:
		push_warning("Spell not found: " + spell_id)
		return false

	# Check if player knows this spell (via SpellCaster)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var spell_caster: SpellCaster = player.get_node_or_null("SpellCaster")
		if spell_caster:
			var knows_spell := false
			for known in spell_caster.known_spells:
				if known and known.id == spell_id:
					knows_spell = true
					break
			if not knows_spell:
				push_warning("Player doesn't know spell: " + spell_id)
				return false

	var old_spell := equipped_spell
	equipped_spell = spell
	equipped_spell_changed.emit(old_spell, equipped_spell)

	return true

## Clear the equipped spell (revert to weapon attacks)
func clear_equipped_spell() -> void:
	var old_spell := equipped_spell
	equipped_spell = null
	equipped_spell_changed.emit(old_spell, null)

## Cast the currently equipped spell directly (called from hotbar)
func _cast_equipped_spell() -> bool:
	if not equipped_spell:
		return false

	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return false

	# Check if player can attack (not already attacking/casting)
	if player.has_method("can_perform_action") and not player.can_perform_action():
		return false

	# Also check the can_attack flag directly
	if "can_attack" in player and not player.can_attack:
		return false

	var spell_caster: SpellCaster = player.get_node_or_null("SpellCaster")
	if not spell_caster:
		return false

	# Check mana and stamina (spell costs 2/3 mana, 1/3 stamina)
	var char_data := GameManager.player_data
	var total_cost := equipped_spell.get_mana_cost()
	@warning_ignore("integer_division")
	var mana_cost := (total_cost * 2) / 3
	@warning_ignore("integer_division")
	var stamina_cost := total_cost / 3
	if char_data and char_data.current_mana < mana_cost:
		return false
	if char_data and char_data.current_stamina < stamina_cost:
		return false

	# Cast the spell via player's spell attack method if available
	if player.has_method("_do_spell_attack"):
		player._do_spell_attack(equipped_spell)
		return true
	else:
		# Fallback to direct casting
		return spell_caster.start_cast(equipped_spell)

## Get currently equipped spell
func get_equipped_spell() -> SpellData:
	return equipped_spell

## Set equipped spell by ID without checking known_spells (for save/load restoration)
## Use equip_spell() for normal gameplay which validates the player knows the spell
func set_equipped_spell_by_id(spell_id: String) -> bool:
	if spell_id.is_empty():
		equipped_spell = null
		return true

	var spell: SpellData = null

	# Try to find in spell database
	if spell_database.has(spell_id):
		spell = spell_database[spell_id]
	else:
		# Try to load directly
		var spell_path := "res://data/spells/%s.tres" % spell_id
		if ResourceLoader.exists(spell_path):
			spell = load(spell_path) as SpellData

	if not spell:
		push_warning("set_equipped_spell_by_id: Spell not found: " + spell_id)
		return false

	var old_spell := equipped_spell
	equipped_spell = spell
	equipped_spell_changed.emit(old_spell, equipped_spell)
	return true

## Get hotbar slot data
func get_hotbar_slot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= 10:
		return {"type": "", "id": ""}
	return hotbar[slot_index]

## Add gold
func add_gold(amount: int) -> void:
	var old := gold
	gold += amount
	gold_changed.emit(old, gold)

## Remove gold
func remove_gold(amount: int) -> bool:
	if gold < amount:
		return false
	var old := gold
	gold -= amount
	gold_changed.emit(old, gold)
	return true

## Get equipped weapon
func get_equipped_weapon() -> WeaponData:
	if equipment.main_hand.is_empty():
		return null
	return equipment.main_hand.get("data") as WeaponData

## Get equipped weapon quality
func get_equipped_weapon_quality() -> Enums.ItemQuality:
	if equipment.main_hand.is_empty():
		return Enums.ItemQuality.AVERAGE
	return equipment.main_hand.get("quality", Enums.ItemQuality.AVERAGE)

## Get total armor value
func get_total_armor_value() -> int:
	var total := 0
	for slot in ["head", "body", "hands", "feet", "off_hand", "ring_1", "ring_2", "amulet"]:
		if not equipment[slot].is_empty():
			var armor: ArmorData = equipment[slot].get("data")
			if armor:
				var quality: Enums.ItemQuality = equipment[slot].get("quality", Enums.ItemQuality.AVERAGE)
				total += armor.get_armor_value(quality)
	return total

## Get total stat bonus from all equipped items
## stat_name should be one of: "grit", "agility", "will", "vitality", "knowledge", "speech"
func get_equipment_stat_bonus(stat_name: String) -> int:
	var total := 0
	for slot_name in equipment.keys():
		var equip: Dictionary = equipment[slot_name]
		if equip.is_empty():
			continue
		var armor: ArmorData = equip.get("data") as ArmorData
		if not armor:
			continue
		match stat_name:
			"grit": total += armor.grit_bonus
			"agility": total += armor.agility_bonus
			"will": total += armor.will_bonus
			"vitality": total += armor.vitality_bonus
			"knowledge": total += armor.knowledge_bonus
			"speech": total += armor.speech_bonus
	return total

## Get total resistance from all equipped items for a specific damage type
## Returns a float from 0.0 (no resistance) to 1.0+ (immune or better)
## Negative values indicate weakness
func get_equipment_resistance(damage_type: Enums.DamageType) -> float:
	var total := 0.0
	for slot_name in equipment.keys():
		var equip: Dictionary = equipment[slot_name]
		if equip.is_empty():
			continue
		var armor: ArmorData = equip.get("data") as ArmorData
		if not armor:
			continue
		match damage_type:
			Enums.DamageType.PHYSICAL:
				# Physical resistance comes from armor value, not a resistance field
				pass
			Enums.DamageType.FIRE:
				total += armor.fire_resistance
			Enums.DamageType.FROST:
				total += armor.frost_resistance
			Enums.DamageType.LIGHTNING:
				total += armor.lightning_resistance
			Enums.DamageType.POISON:
				total += armor.poison_resistance
			Enums.DamageType.NECROTIC:
				total += armor.necrotic_resistance
			Enums.DamageType.HOLY:
				total += armor.magic_resistance  # Use magic_resistance for holy
	return total

## Get total block value (shield)
func get_block_value() -> int:
	if equipment.off_hand.is_empty():
		return 0
	var shield: ArmorData = equipment.off_hand.get("data")
	if shield and shield.is_shield:
		var quality: Enums.ItemQuality = equipment.off_hand.get("quality", Enums.ItemQuality.AVERAGE)
		return shield.get_block_value(quality)
	return 0

## Check helpers
func _item_exists(item_id: String) -> bool:
	return weapon_database.has(item_id) or armor_database.has(item_id) or item_database.has(item_id)

## Check if item is equipment (weapon or armor) that can have quality modifiers
func _is_equipment(item_id: String) -> bool:
	return weapon_database.has(item_id) or armor_database.has(item_id)

func _is_stackable(item_id: String) -> bool:
	if item_database.has(item_id):
		return (item_database[item_id] as ItemData).is_stackable
	return false  # Weapons and armor don't stack

func _can_stack(item_id: String, quality: Enums.ItemQuality) -> bool:
	if not _is_stackable(item_id):
		return false
	for slot in inventory:
		if slot.item_id == item_id and slot.quality == quality:
			if slot.quantity < _get_max_stack(item_id):
				return true
	return false


## Check if an item can be added to inventory (no slot limit - just check if item exists)
func _can_add_item(item_id: String, _quantity: int = 1, _quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE) -> bool:
	return _item_exists(item_id)


func _get_max_stack(item_id: String) -> int:
	if item_database.has(item_id):
		return (item_database[item_id] as ItemData).max_stack
	return 1

## Give player fixed starter items for testing
func _give_starter_items() -> void:
	print("[InventoryManager] _give_starter_items called")
	print("[InventoryManager] Database sizes at starter: weapons=%d, armor=%d, items=%d" % [
		weapon_database.size(), armor_database.size(), item_database.size()
	])

	# Give fixed starter loadout
	add_item("longsword", 1, Enums.ItemQuality.ABOVE_AVERAGE)  # Fine longsword
	add_item("hunting_bow", 1, Enums.ItemQuality.AVERAGE)
	add_item("arrows", 20, Enums.ItemQuality.AVERAGE)

## Random quality with weighted distribution:
## Poor: 10%, Below Average: 25%, Average: 40%, Above Average: 20%, Perfect: 5%
func _random_quality() -> Enums.ItemQuality:
	var roll := randf()
	if roll < 0.10:
		return Enums.ItemQuality.POOR          # 10%
	elif roll < 0.35:
		return Enums.ItemQuality.BELOW_AVERAGE # 25% (0.10 to 0.35)
	elif roll < 0.75:
		return Enums.ItemQuality.AVERAGE       # 40% (0.35 to 0.75)
	elif roll < 0.95:
		return Enums.ItemQuality.ABOVE_AVERAGE # 20% (0.75 to 0.95)
	else:
		return Enums.ItemQuality.PERFECT       # 5%  (0.95 to 1.0)

## Drop an item from inventory into the world
func drop_item(inventory_index: int, drop_position: Vector3 = Vector3.ZERO) -> bool:
	if inventory_index < 0 or inventory_index >= inventory.size():
		return false

	var item_slot: Dictionary = inventory[inventory_index]
	var item_id: String = item_slot.item_id
	var quality: Enums.ItemQuality = item_slot.quality

	# Spawn world item if position provided and scene exists
	if drop_position != Vector3.ZERO:
		_spawn_world_item(item_id, quality, drop_position)

	# Remove from inventory
	item_slot.quantity -= 1
	if item_slot.quantity <= 0:
		inventory.remove_at(inventory_index)

	item_removed.emit(item_id, 1)
	return true

## Spawn a world item at position
func _spawn_world_item(item_id: String, quality: Enums.ItemQuality, pos: Vector3) -> void:
	if not ResourceLoader.exists("res://scenes/world/world_item.tscn"):
		push_warning("World item scene not found")
		return

	var world_item_scene := load("res://scenes/world/world_item.tscn")
	var world_item: Node3D = world_item_scene.instantiate()

	# Set item data
	if world_item.has_method("setup"):
		world_item.setup(item_id, quality)
	else:
		world_item.set("item_id", item_id)
		world_item.set("item_quality", quality)

	# Add to scene
	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(world_item)
		world_item.global_position = pos

## Get item display name
func get_item_name(item_id: String) -> String:
	if weapon_database.has(item_id):
		return (weapon_database[item_id] as WeaponData).display_name
	elif armor_database.has(item_id):
		return (armor_database[item_id] as ArmorData).display_name
	elif item_database.has(item_id):
		return (item_database[item_id] as ItemData).display_name
	return item_id

## Get item description
func get_item_description(item_id: String) -> String:
	if weapon_database.has(item_id):
		return (weapon_database[item_id] as WeaponData).description
	elif armor_database.has(item_id):
		return (armor_database[item_id] as ArmorData).description
	elif item_database.has(item_id):
		return (item_database[item_id] as ItemData).description
	return ""

## Get item data resource
func get_item_data(item_id: String) -> Resource:
	if weapon_database.has(item_id):
		return weapon_database[item_id]
	elif armor_database.has(item_id):
		return armor_database[item_id]
	elif item_database.has(item_id):
		return item_database[item_id]
	return null

## Compare two items (returns stat differences)
func compare_items(item_id_a: String, quality_a: Enums.ItemQuality, item_id_b: String, quality_b: Enums.ItemQuality) -> Dictionary:
	var comparison := {
		"damage_diff": 0,
		"armor_diff": 0,
		"stat_diffs": {}
	}

	var data_a := get_item_data(item_id_a)
	var data_b := get_item_data(item_id_b)

	if not data_a or not data_b:
		return comparison

	# Compare weapons
	if data_a is WeaponData and data_b is WeaponData:
		var wa := data_a as WeaponData
		var wb := data_b as WeaponData
		var mod_a := Enums.get_quality_modifier(quality_a)
		var mod_b := Enums.get_quality_modifier(quality_b)
		# Average damage comparison using base_damage array [dice_count, die_sides, flat_bonus]
		var avg_a := (wa.base_damage[0] * (wa.base_damage[1] + 1) / 2.0) + wa.base_damage[2] + mod_a
		var avg_b := (wb.base_damage[0] * (wb.base_damage[1] + 1) / 2.0) + wb.base_damage[2] + mod_b
		comparison.damage_diff = int(avg_a - avg_b)

	# Compare armor
	if data_a is ArmorData and data_b is ArmorData:
		var aa := data_a as ArmorData
		var ab := data_b as ArmorData
		comparison.armor_diff = aa.get_armor_value(quality_a) - ab.get_armor_value(quality_b)

		# Stat bonuses
		comparison.stat_diffs["grit"] = aa.grit_bonus - ab.grit_bonus
		comparison.stat_diffs["agility"] = aa.agility_bonus - ab.agility_bonus
		comparison.stat_diffs["will"] = aa.will_bonus - ab.will_bonus
		comparison.stat_diffs["vitality"] = aa.vitality_bonus - ab.vitality_bonus
		comparison.stat_diffs["knowledge"] = aa.knowledge_bonus - ab.knowledge_bonus

	return comparison

## Get total weight of all items in inventory
func get_total_weight() -> float:
	var total: float = 0.0

	for slot in inventory:
		var item_id: String = slot.item_id
		var qty: int = slot.quantity
		var weight: float = _get_item_weight(item_id)
		total += weight * qty

	# Add equipped item weights
	for slot_name in equipment.keys():
		var equip: Dictionary = equipment[slot_name]
		if not equip.is_empty():
			var weight: float = _get_item_weight(equip.item_id)
			total += weight

	return total

## Get weight of a single item by ID
func _get_item_weight(item_id: String) -> float:
	if weapon_database.has(item_id):
		return (weapon_database[item_id] as WeaponData).weight
	elif armor_database.has(item_id):
		return (armor_database[item_id] as ArmorData).weight
	elif item_database.has(item_id):
		return (item_database[item_id] as ItemData).weight
	return 0.0

## Get maximum carry weight based on player Grit (uses effective stat)
func get_max_carry_weight() -> float:
	var base_weight: float = 50.0
	var grit: int = 3  # Default if no player data

	if GameManager.player_data:
		grit = GameManager.player_data.get_effective_stat(Enums.Stat.GRIT)

	return base_weight + (grit * 10.0)

## Check if player is overencumbered
func is_overencumbered() -> bool:
	return get_total_weight() > get_max_carry_weight()

## Get item value adjusted for quality
func get_item_value(item_id: String, quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE) -> int:
	var base_value: int = 0

	if weapon_database.has(item_id):
		base_value = (weapon_database[item_id] as WeaponData).base_value
	elif armor_database.has(item_id):
		base_value = (armor_database[item_id] as ArmorData).base_value
	elif item_database.has(item_id):
		base_value = (item_database[item_id] as ItemData).base_value

	# Apply quality multiplier
	var multiplier: float = 1.0
	match quality:
		Enums.ItemQuality.POOR:
			multiplier = 0.25
		Enums.ItemQuality.BELOW_AVERAGE:
			multiplier = 0.5
		Enums.ItemQuality.AVERAGE:
			multiplier = 1.0
		Enums.ItemQuality.ABOVE_AVERAGE:
			multiplier = 2.0
		Enums.ItemQuality.PERFECT:
			multiplier = 4.0

	return int(base_value * multiplier)

## Serialize for saving
func to_dict() -> Dictionary:
	# Convert hotbar for saving
	var hotbar_save: Array = []
	for slot in hotbar:
		hotbar_save.append(slot.duplicate())

	return {
		"inventory": inventory.duplicate(true),
		"equipment": equipment.duplicate(true),
		"quick_slots": quick_slots.duplicate(),
		"hotbar": hotbar_save,
		"equipped_spell_id": equipped_spell.id if equipped_spell else "",
		"gold": gold
	}

## Deserialize from save
func from_dict(data: Dictionary) -> void:
	# Load inventory (convert untyped array to typed)
	inventory.clear()
	for item in data.get("inventory", []):
		if item is Dictionary:
			inventory.append(item.duplicate(true))

	# Load equipment
	for slot in equipment.keys():
		var slot_data = data.get("equipment", {}).get(slot, {})
		if slot_data is Dictionary:
			equipment[slot] = slot_data.duplicate(true)
		else:
			equipment[slot] = {}
		# Restore data reference and ensure durability exists
		if not equipment[slot].is_empty():
			var item_id: String = equipment[slot].get("item_id", "")
			if weapon_database.has(item_id):
				equipment[slot].data = weapon_database[item_id]
			elif armor_database.has(item_id):
				equipment[slot].data = armor_database[item_id]
			else:
				# Item no longer exists in database - clear this equipment slot
				push_warning("from_dict: Equipment item '%s' in slot '%s' not found in database. Clearing slot." % [item_id, slot])
				equipment[slot] = {}
				continue
			# Ensure durability fields exist (backward compatibility)
			if not equipment[slot].has("durability"):
				var quality: Enums.ItemQuality = equipment[slot].get("quality", Enums.ItemQuality.AVERAGE)
				equipment[slot]["durability"] = get_max_durability(quality)
				equipment[slot]["max_durability"] = get_max_durability(quality)

	# Load quick_slots (convert untyped array to typed Array[String])
	quick_slots = ["", "", "", ""]
	var qs_data: Array = data.get("quick_slots", [])
	for i in range(min(qs_data.size(), 4)):
		quick_slots[i] = str(qs_data[i]) if qs_data[i] else ""

	gold = data.get("gold", 300)

	# Load hotbar (initialize first, then populate)
	_initialize_hotbar()
	var hotbar_data: Array = data.get("hotbar", [])
	for i in range(min(hotbar_data.size(), 10)):
		if hotbar_data[i] is Dictionary:
			hotbar[i] = hotbar_data[i].duplicate()

	# Load equipped spell (use set_equipped_spell_by_id to bypass known_spells check during restoration)
	var spell_id: String = data.get("equipped_spell_id", "")
	if not spell_id.is_empty():
		set_equipped_spell_by_id(spell_id)

# ============================================================================
# DURABILITY AND DEGRADATION SYSTEM
# ============================================================================

## Durability states (visual indicators based on percentage)
## Good: 75%-100%, Worn: 50%-74%, Low: 25%-49%, Broken: 0%
enum DurabilityState { GOOD, WORN, LOW, BROKEN }

## Thresholds for durability states (percentage of max)
const DURABILITY_THRESHOLD_GOOD := 0.75
const DURABILITY_THRESHOLD_WORN := 0.50
const DURABILITY_THRESHOLD_LOW := 0.25
const DURABILITY_THRESHOLD_BROKEN := 0.0

## Base durability per quality tier
const DURABILITY_PER_QUALITY: Dictionary = {
	Enums.ItemQuality.POOR: 20,
	Enums.ItemQuality.BELOW_AVERAGE: 40,
	Enums.ItemQuality.AVERAGE: 60,
	Enums.ItemQuality.ABOVE_AVERAGE: 80,
	Enums.ItemQuality.PERFECT: 100
}

## Get max durability for a quality tier
func get_max_durability(quality: Enums.ItemQuality) -> int:
	return DURABILITY_PER_QUALITY.get(quality, 60)

## Get quality tier one level below current (for degradation)
func get_lower_quality(quality: Enums.ItemQuality) -> Enums.ItemQuality:
	match quality:
		Enums.ItemQuality.PERFECT:
			return Enums.ItemQuality.ABOVE_AVERAGE
		Enums.ItemQuality.ABOVE_AVERAGE:
			return Enums.ItemQuality.AVERAGE
		Enums.ItemQuality.AVERAGE:
			return Enums.ItemQuality.BELOW_AVERAGE
		Enums.ItemQuality.BELOW_AVERAGE:
			return Enums.ItemQuality.POOR
		_:
			return Enums.ItemQuality.POOR  # Already at lowest

## Get quality tier one level above current (for quality restoration)
func get_higher_quality(quality: Enums.ItemQuality) -> Enums.ItemQuality:
	match quality:
		Enums.ItemQuality.POOR:
			return Enums.ItemQuality.BELOW_AVERAGE
		Enums.ItemQuality.BELOW_AVERAGE:
			return Enums.ItemQuality.AVERAGE
		Enums.ItemQuality.AVERAGE:
			return Enums.ItemQuality.ABOVE_AVERAGE
		Enums.ItemQuality.ABOVE_AVERAGE:
			return Enums.ItemQuality.PERFECT
		_:
			return Enums.ItemQuality.PERFECT  # Already at highest

## Degrade weapon durability (call when attacking)
## Returns true if item degraded to lower quality tier
func degrade_weapon(damage_amount: int = 1) -> bool:
	if equipment.main_hand.is_empty():
		return false

	return _degrade_equipment_slot("main_hand", damage_amount)

## Degrade armor durability (call when taking damage)
## damage_amount: how much durability to lose (scales with hit taken)
## Returns true if any armor degraded to lower quality tier
func degrade_armor(damage_amount: int = 1) -> bool:
	var any_degraded := false

	# Degrade all worn armor pieces (not rings/amulets - they don't take physical wear)
	for slot in ["head", "body", "hands", "feet", "off_hand"]:
		if not equipment[slot].is_empty():
			if _degrade_equipment_slot(slot, damage_amount):
				any_degraded = true

	return any_degraded

## Degrade a specific equipment slot
## Returns true if item degraded to lower quality tier or became broken
func _degrade_equipment_slot(slot: String, amount: int) -> bool:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return false

	var equip: Dictionary = equipment[slot]

	# Can't degrade a broken item further
	if equip.get("is_broken", false):
		return false

	# Initialize durability if not present (for backward compatibility)
	if not equip.has("durability"):
		var quality: Enums.ItemQuality = equip.get("quality", Enums.ItemQuality.AVERAGE)
		equip["durability"] = get_max_durability(quality)
		equip["max_durability"] = get_max_durability(quality)

	# Reduce durability (reduced by 25% to make items last longer)
	var reduced_amount: int = maxi(1, int(amount * 0.75))
	equip["durability"] = max(0, equip["durability"] - reduced_amount)

	# Check if durability hit zero - degrade quality or break
	if equip["durability"] <= 0:
		var current_quality: Enums.ItemQuality = equip.get("quality", Enums.ItemQuality.AVERAGE)

		# At lowest quality with 0 durability = BROKEN (unusable)
		if current_quality == Enums.ItemQuality.POOR:
			equip["durability"] = 0
			equip["is_broken"] = true
			item_degraded.emit(slot, equip["item_id"], current_quality)
			# Show special notification for broken items
			var hud := GameManager.get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_notification"):
				var item_name := get_item_name(equip["item_id"])
				hud.show_notification("Your %s has BROKEN! Visit a blacksmith to repair." % item_name)
			return true

		# Drop quality tier
		var new_quality: Enums.ItemQuality = get_lower_quality(current_quality)
		equip["quality"] = new_quality
		equip["max_durability"] = get_max_durability(new_quality)
		equip["durability"] = equip["max_durability"]  # Reset durability at new tier

		item_degraded.emit(slot, equip["item_id"], new_quality)
		return true

	return false

## Get current durability of an equipped item
func get_equipment_durability(slot: String) -> int:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return 0
	return equipment[slot].get("durability", 0)

## Get max durability of an equipped item
func get_equipment_max_durability(slot: String) -> int:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return 0
	return equipment[slot].get("max_durability", 0)

## Get durability percentage (0.0 to 1.0) of an equipped item
func get_equipment_durability_percent(slot: String) -> float:
	var max_dur := get_equipment_max_durability(slot)
	if max_dur <= 0:
		return 0.0
	return float(get_equipment_durability(slot)) / float(max_dur)

## Get durability state of an equipped item
## Returns: GOOD, WORN, LOW, or BROKEN
func get_equipment_durability_state(slot: String) -> DurabilityState:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return DurabilityState.GOOD

	# Check if explicitly marked as broken
	if equipment[slot].get("is_broken", false):
		return DurabilityState.BROKEN

	var pct := get_equipment_durability_percent(slot)
	if pct <= DURABILITY_THRESHOLD_BROKEN:
		return DurabilityState.BROKEN
	elif pct < DURABILITY_THRESHOLD_LOW:
		return DurabilityState.LOW
	elif pct < DURABILITY_THRESHOLD_WORN:
		return DurabilityState.WORN
	else:
		return DurabilityState.GOOD

## Check if an equipped item is broken (unusable)
func is_equipment_broken(slot: String) -> bool:
	return get_equipment_durability_state(slot) == DurabilityState.BROKEN

## Check if weapon is usable (not broken)
func is_weapon_usable() -> bool:
	if equipment.main_hand.is_empty():
		return true  # Unarmed is always usable
	return not is_equipment_broken("main_hand")

# ============================================================================
# REPAIR SYSTEM
# ============================================================================

## Cost to repair 1 point of durability (in gold)
const REPAIR_COST_PER_DURABILITY: int = 2

## Cost to restore one quality tier (in gold) - expensive!
const QUALITY_RESTORE_COST: Dictionary = {
	Enums.ItemQuality.POOR: 500,         # Poor -> Below Average
	Enums.ItemQuality.BELOW_AVERAGE: 1000,  # Below Average -> Average
	Enums.ItemQuality.AVERAGE: 2500,     # Average -> Above Average
	Enums.ItemQuality.ABOVE_AVERAGE: 5000   # Above Average -> Perfect
}

## Calculate repair cost for an equipment slot (durability only)
## Broken items cost extra to fix (50% premium)
func get_repair_cost(slot: String) -> int:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return 0

	var equip: Dictionary = equipment[slot]
	var current_dur: int = equip.get("durability", 0)
	var max_dur: int = equip.get("max_durability", 0)
	var missing_dur: int = max_dur - current_dur
	var is_broken: bool = equip.get("is_broken", false)

	var base_cost := missing_dur * REPAIR_COST_PER_DURABILITY

	# Broken items cost 50% more to repair (penalty for letting them break)
	if is_broken:
		base_cost = int(base_cost * 1.5)
		# Minimum cost for broken items even if durability was at max
		base_cost = maxi(base_cost, 50)

	return base_cost

## Calculate cost to restore quality tier for an equipment slot
func get_quality_restore_cost(slot: String) -> int:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return 0

	var quality: Enums.ItemQuality = equipment[slot].get("quality", Enums.ItemQuality.AVERAGE)
	if quality == Enums.ItemQuality.PERFECT:
		return 0  # Already at max quality

	return QUALITY_RESTORE_COST.get(quality, 0)

## Repair an equipment slot at blacksmith (restores durability, fixes broken items)
## Returns true if repair was successful
func repair_equipment(slot: String) -> bool:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return false

	var equip: Dictionary = equipment[slot]
	var is_broken: bool = equip.get("is_broken", false)

	var cost := get_repair_cost(slot)
	if cost <= 0 and not is_broken:
		return false  # Already at full durability and not broken

	if gold < cost:
		push_warning("Not enough gold to repair. Need: %d, Have: %d" % [cost, gold])
		return false

	# Deduct gold and restore durability
	remove_gold(cost)

	var restored: int = equip["max_durability"] - equip["durability"]
	equip["durability"] = equip["max_durability"]

	# Clear broken flag (blacksmith can fix broken items)
	if is_broken:
		equip["is_broken"] = false

	item_repaired.emit(slot, equip["item_id"], restored)
	return true

## Restore quality tier of an equipment slot (expensive)
## Returns true if restoration was successful
func restore_equipment_quality(slot: String) -> bool:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return false

	var cost := get_quality_restore_cost(slot)
	if cost <= 0:
		return false  # Already at max quality

	if gold < cost:
		push_warning("Not enough gold to restore quality. Need: %d, Have: %d" % [cost, gold])
		return false

	# Deduct gold and restore quality
	remove_gold(cost)

	var equip: Dictionary = equipment[slot]
	var old_quality: Enums.ItemQuality = equip["quality"]
	var new_quality: Enums.ItemQuality = get_higher_quality(old_quality)

	equip["quality"] = new_quality
	equip["max_durability"] = get_max_durability(new_quality)
	equip["durability"] = equip["max_durability"]  # Full durability at new tier

	equipment_changed.emit(slot, equip.duplicate(), equip)
	return true

## Repair equipment using a repair kit item (no gold cost)
## repair_amount: how much durability to restore
## NOTE: Repair kits CANNOT fix broken items - must visit blacksmith
## Returns true if repair was applied
func repair_with_kit(slot: String, repair_amount: int) -> bool:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return false

	var equip: Dictionary = equipment[slot]

	# Broken items require blacksmith repair - kits won't work
	if equip.get("is_broken", false):
		var hud := GameManager.get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("This item is BROKEN - visit a blacksmith to repair!")
		return false

	# Initialize durability if not present
	if not equip.has("durability"):
		var quality: Enums.ItemQuality = equip.get("quality", Enums.ItemQuality.AVERAGE)
		equip["durability"] = get_max_durability(quality)
		equip["max_durability"] = get_max_durability(quality)

	var current_dur: int = equip["durability"]
	var max_dur: int = equip["max_durability"]

	if current_dur >= max_dur:
		return false  # Already at full durability

	var restored: int = min(repair_amount, max_dur - current_dur)
	equip["durability"] = current_dur + restored

	item_repaired.emit(slot, equip["item_id"], restored)
	return true

## Repair all equipped items (convenience function)
## Returns total gold spent
func repair_all_equipment() -> int:
	var total_cost := 0

	for slot in equipment.keys():
		if not equipment[slot].is_empty():
			var cost := get_repair_cost(slot)
			if cost > 0 and gold >= cost:
				if repair_equipment(slot):
					total_cost += cost

	return total_cost

## Get total repair cost for all equipped items
func get_total_repair_cost() -> int:
	var total := 0
	for slot in equipment.keys():
		total += get_repair_cost(slot)
	return total


## Reset inventory for a new game (called from death screen "New Game")
func reset_for_new_game() -> void:
	# Clear inventory
	inventory.clear()

	# Clear equipment
	for slot in equipment.keys():
		equipment[slot] = {}

	# Reset gold to starting amount
	gold = 300

	# Clear quick slots
	quick_slots = ["", "", "", ""]

	# Reinitialize hotbar
	_initialize_hotbar()

	# Clear equipped spell
	equipped_spell = null

	# Give starting items
	add_item("longsword", 1, Enums.ItemQuality.ABOVE_AVERAGE)  # Fine longsword
	add_item("hunting_bow", 1, Enums.ItemQuality.AVERAGE)
	add_item("arrows", 20, Enums.ItemQuality.AVERAGE)
