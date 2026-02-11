## lootable_corpse.gd - Dead enemy body that can be searched for loot
## Works like Fallout - player searches the body and takes what they want
## Loot is tiered based on enemy level (1-100 scale)
class_name LootableCorpse
extends StaticBody3D

const DEBUG := false

signal looted

## Visual representation
var mesh_root: Node3D
var body_mesh: MeshInstance3D
var interaction_area: Area3D

## Corpse configuration
@export var corpse_name: String = "Body"
@export var enemy_id: String = ""  # What enemy type this was
@export var enemy_level: int = 1   # Level determines loot tier

## Contents: Array of {item_id: String, quantity: int, quality: Enums.ItemQuality}
var contents: Array[Dictionary] = []

## Gold on the body
var gold: int = 0

## Has this corpse been searched?
var has_been_looted: bool = false

## Reference to open UI canvas
var _active_ui_canvas: CanvasLayer = null

## Despawn timer (corpses disappear after being fully looted or after timeout)
var despawn_timer: float = 300.0  # 5 minutes if not looted
const LOOTED_DESPAWN_TIME := 30.0  # 30 seconds after being emptied

## Loot tier thresholds based on enemy level
## Level 1-10: Tier 1 (basic), 11-25: Tier 2 (common), 26-50: Tier 3 (uncommon)
## 51-75: Tier 4 (rare), 76-90: Tier 5 (epic), 91-100: Tier 6 (legendary)
enum LootTier { BASIC, COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("corpses")

	collision_layer = 1
	collision_mask = 0

	_create_corpse_mesh()
	_create_interaction_area()


func _process(delta: float) -> void:
	# Despawn timer
	despawn_timer -= delta
	if despawn_timer <= 0:
		queue_free()


func _create_corpse_mesh() -> void:
	## Create a gore-themed corpse mesh (flattened body with blood pool effect)
	mesh_root = Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)

	# Blood pool underneath (dark red disc)
	var blood_pool := MeshInstance3D.new()
	blood_pool.name = "BloodPool"
	var blood_mesh := CylinderMesh.new()
	blood_mesh.height = 0.02
	blood_mesh.top_radius = 0.7
	blood_mesh.bottom_radius = 0.8
	blood_pool.mesh = blood_mesh

	var blood_mat := StandardMaterial3D.new()
	blood_mat.albedo_color = Color(0.3, 0.05, 0.05)  # Dark blood red
	blood_mat.roughness = 0.6
	blood_mat.metallic = 0.2  # Slight sheen
	blood_pool.material_override = blood_mat
	blood_pool.position = Vector3(0, 0.01, 0)
	mesh_root.add_child(blood_pool)

	# Body mesh (flattened corpse shape)
	body_mesh = MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.12, 1.0)  # Flat body shape
	body_mesh.mesh = box

	var mat := StandardMaterial3D.new()
	# Try to load gore texture if available
	var gore_tex_path := "res://assets/sprites/textures/dungeon/gore_dungeon_wall.png"
	if ResourceLoader.exists(gore_tex_path):
		mat.albedo_texture = load(gore_tex_path)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	else:
		mat.albedo_color = Color(0.4, 0.2, 0.15)  # Brownish-red fallback
	mat.roughness = 0.9
	body_mesh.material_override = mat
	body_mesh.position = Vector3(0, 0.08, 0)
	mesh_root.add_child(body_mesh)

	# Random slight rotation for more natural look
	mesh_root.rotation.y = randf_range(-0.3, 0.3)


func _create_interaction_area() -> void:
	## Create Area3D for raycast detection by player
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.5, 1.5)
	area_shape.shape = box
	area_shape.position = Vector3(0, 0.25, 0)
	interaction_area.add_child(area_shape)


## Called by player interaction system
func interact(_interactor: Node) -> void:
	_open_loot_ui()


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	if has_been_looted and contents.is_empty() and gold <= 0:
		return "Search " + corpse_name + " (Empty)"
	return "Search " + corpse_name


## Open the corpse loot UI
func _open_loot_ui() -> void:
	has_been_looted = true

	# Load and instantiate corpse loot UI
	var loot_ui_script := preload("res://scripts/ui/corpse_loot_ui.gd")
	var loot_ui := Control.new()
	loot_ui.set_script(loot_ui_script)
	loot_ui.name = "CorpseLootUI"

	# Pass corpse reference
	loot_ui.set("corpse", self)

	# Add to CanvasLayer
	var canvas := CanvasLayer.new()
	canvas.name = "CorpseLootUICanvas"
	canvas.layer = 100
	get_tree().current_scene.add_child(canvas)
	canvas.add_child(loot_ui)

	_active_ui_canvas = canvas

	# Connect close signal
	if loot_ui.has_signal("ui_closed"):
		loot_ui.ui_closed.connect(_on_loot_ui_closed.bind(canvas))

	# Enter menu mode
	GameManager.enter_menu()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if loot_ui.has_method("open"):
		loot_ui.open()


func _on_loot_ui_closed(canvas: CanvasLayer) -> void:
	GameManager.exit_menu()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if canvas and is_instance_valid(canvas):
		canvas.queue_free()

	_active_ui_canvas = null

	# Check if corpse should despawn (empty)
	_check_if_should_despawn()


## Add an item to the corpse
func add_item(item_id: String, quantity: int = 1, quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE) -> void:
	# Check if stackable and already exists
	for slot in contents:
		if slot.item_id == item_id and slot.quality == quality:
			slot.quantity += quantity
			return

	contents.append({
		"item_id": item_id,
		"quantity": quantity,
		"quality": quality
	})


## Remove an item from the corpse (player took it)
func remove_item(item_id: String, quantity: int = 1, quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE) -> bool:
	for i in range(contents.size()):
		var slot: Dictionary = contents[i]
		if slot.item_id == item_id and slot.quality == quality:
			if slot.quantity >= quantity:
				slot.quantity -= quantity
				if slot.quantity <= 0:
					contents.remove_at(i)
				_check_if_should_despawn()
				return true
			return false
	return false


## Take all gold from corpse
func take_gold() -> int:
	var taken := gold
	gold = 0
	_check_if_should_despawn()
	return taken


## Take all items from corpse (loot all)
func take_all() -> void:
	# Take gold
	if gold > 0:
		InventoryManager.add_gold(gold)
		gold = 0

	# Take all items
	for slot in contents:
		InventoryManager.add_item(slot.item_id, slot.quantity, slot.quality)

	contents.clear()
	_check_if_should_despawn()


## Check if corpse should despawn (empty after being looted)
func _check_if_should_despawn() -> void:
	if has_been_looted and contents.is_empty() and gold <= 0:
		# Set short despawn timer
		despawn_timer = LOOTED_DESPAWN_TIME

		if DEBUG:
			print("[LootableCorpse] %s is empty, will despawn in %.1f seconds" % [corpse_name, LOOTED_DESPAWN_TIME])


## Get loot tier based on enemy level
static func get_loot_tier(level: int) -> LootTier:
	if level <= 10:
		return LootTier.BASIC
	elif level <= 25:
		return LootTier.COMMON
	elif level <= 50:
		return LootTier.UNCOMMON
	elif level <= 75:
		return LootTier.RARE
	elif level <= 90:
		return LootTier.EPIC
	else:
		return LootTier.LEGENDARY


## Static factory method for spawning corpses
static func spawn_corpse(parent: Node, pos: Vector3, p_corpse_name: String, p_enemy_id: String = "", p_level: int = 1) -> LootableCorpse:
	var instance := LootableCorpse.new()
	instance.position = pos
	instance.corpse_name = p_corpse_name
	instance.enemy_id = p_enemy_id
	instance.enemy_level = p_level

	# Add collision shape
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.15, 1.2)
	col_shape.shape = box
	col_shape.position = Vector3(0, 0.075, 0)
	instance.add_child(col_shape)

	parent.add_child(instance)
	return instance


## Generate loot for a humanoid enemy (bandits, guards, soldiers, etc.)
## Loot scales with enemy level using tier system
func generate_humanoid_loot(enemy_data: EnemyData) -> void:
	if not enemy_data:
		return

	var tier: LootTier = get_loot_tier(enemy_level)

	# Gold scales with level (level 1 = 10-30, level 100 = 500-1500)
	var gold_mult := 1.0 + (enemy_level * 0.1)
	var base_gold := enemy_data.roll_gold()
	gold = int(base_gold * gold_mult)

	# Determine quality distribution based on tier
	var quality_func: Callable = _get_quality_roller_for_tier(tier)

	# Check what attack types the enemy has
	var has_melee := false
	var has_ranged := false
	for attack in enemy_data.attacks:
		if attack.is_ranged:
			has_ranged = true
		else:
			has_melee = true

	# Generate weapon based on tier and attack type
	if has_melee:
		var weapon_id := _get_melee_weapon_for_tier(tier)
		if not weapon_id.is_empty() and InventoryManager.weapon_database.has(weapon_id):
			add_item(weapon_id, 1, quality_func.call())

	if has_ranged:
		var ranged_data: Dictionary = _get_ranged_weapon_for_tier(tier)
		if not ranged_data.is_empty():
			add_item(ranged_data.weapon, 1, quality_func.call())
			# Add ammo for ranged weapon
			var ammo_qty: int = randi_range(ranged_data.ammo_min, ranged_data.ammo_max)
			add_item(ranged_data.ammo, ammo_qty, Enums.ItemQuality.AVERAGE)

	# Armor chance increases with tier
	var armor_chance := 0.2 + (int(tier) * 0.1)
	if randf() < armor_chance:
		var armor_id := _get_armor_for_tier(tier)
		if not armor_id.is_empty():
			add_item(armor_id, 1, quality_func.call())

	# Consumables (food, potions)
	_add_consumables_for_tier(tier, quality_func)

	# Misc utility items
	_add_utility_items_for_tier(tier)

	# Guaranteed drops from enemy data
	for item_id in enemy_data.guaranteed_drops:
		add_item(item_id, 1, quality_func.call())

	# Random drops from enemy's drop table
	for item_id in enemy_data.drop_table:
		var chance: float = enemy_data.drop_table[item_id]
		if randf() < chance:
			add_item(item_id, 1, quality_func.call())

	if DEBUG:
		print("[LootableCorpse] Generated humanoid loot for %s (level %d, tier %d): %d gold, %d items" % [
			corpse_name, enemy_level, tier, gold, contents.size()
		])


## Generate loot for a creature/animal (wolves, spiders, bears, etc.)
func generate_creature_loot(enemy_data: EnemyData) -> void:
	if not enemy_data:
		return

	# Creatures typically don't carry gold
	gold = 0

	# Get quality roller based on level tier
	var tier: LootTier = get_loot_tier(enemy_level)
	var quality_func: Callable = _get_quality_roller_for_tier(tier)

	# Guaranteed drops (pelts, fangs, claws, etc.)
	for item_id in enemy_data.guaranteed_drops:
		var qty := 1
		# Higher tier creatures drop more materials
		if tier >= LootTier.UNCOMMON:
			qty = randi_range(1, 2)
		if tier >= LootTier.RARE:
			qty = randi_range(2, 3)
		add_item(item_id, qty, quality_func.call())

	# Random drops - chance improved by tier
	for item_id in enemy_data.drop_table:
		var base_chance: float = enemy_data.drop_table[item_id]
		var tier_bonus := int(tier) * 0.05  # +5% per tier
		var adjusted_chance: float = minf(base_chance + tier_bonus, 0.9)  # Cap at 90%

		if randf() < adjusted_chance:
			var qty := 1
			# Multiple drops for common materials
			if item_id.contains("fang") or item_id.contains("claw") or item_id.contains("scale"):
				qty = randi_range(1, 2 + int(tier))
			add_item(item_id, qty, quality_func.call())

	if DEBUG:
		print("[LootableCorpse] Generated creature loot for %s (level %d): %d items" % [
			corpse_name, enemy_level, contents.size()
		])


## Get quality roller function for given tier
func _get_quality_roller_for_tier(tier: LootTier) -> Callable:
	match tier:
		LootTier.BASIC:
			return _roll_basic_quality
		LootTier.COMMON:
			return _roll_common_quality
		LootTier.UNCOMMON:
			return _roll_uncommon_quality
		LootTier.RARE:
			return _roll_rare_quality
		LootTier.EPIC:
			return _roll_epic_quality
		LootTier.LEGENDARY:
			return _roll_legendary_quality
	return _roll_common_quality


## Quality rollers for each tier
## Basic (level 1-10): Mostly poor/below average
func _roll_basic_quality() -> Enums.ItemQuality:
	var roll := randf()
	if roll < 0.30:
		return Enums.ItemQuality.POOR          # 30%
	if roll < 0.70:
		return Enums.ItemQuality.BELOW_AVERAGE # 40%
	if roll < 0.95:
		return Enums.ItemQuality.AVERAGE       # 25%
	return Enums.ItemQuality.ABOVE_AVERAGE     # 5%

## Common (level 11-25): Below average to average
func _roll_common_quality() -> Enums.ItemQuality:
	var roll := randf()
	if roll < 0.15:
		return Enums.ItemQuality.POOR          # 15%
	if roll < 0.45:
		return Enums.ItemQuality.BELOW_AVERAGE # 30%
	if roll < 0.85:
		return Enums.ItemQuality.AVERAGE       # 40%
	if roll < 0.98:
		return Enums.ItemQuality.ABOVE_AVERAGE # 13%
	return Enums.ItemQuality.PERFECT           # 2%

## Uncommon (level 26-50): Average with chance for good
func _roll_uncommon_quality() -> Enums.ItemQuality:
	var roll := randf()
	if roll < 0.10:
		return Enums.ItemQuality.POOR          # 10%
	if roll < 0.30:
		return Enums.ItemQuality.BELOW_AVERAGE # 20%
	if roll < 0.70:
		return Enums.ItemQuality.AVERAGE       # 40%
	if roll < 0.92:
		return Enums.ItemQuality.ABOVE_AVERAGE # 22%
	return Enums.ItemQuality.PERFECT           # 8%

## Rare (level 51-75): Good quality common
func _roll_rare_quality() -> Enums.ItemQuality:
	var roll := randf()
	if roll < 0.05:
		return Enums.ItemQuality.POOR          # 5%
	if roll < 0.20:
		return Enums.ItemQuality.BELOW_AVERAGE # 15%
	if roll < 0.55:
		return Enums.ItemQuality.AVERAGE       # 35%
	if roll < 0.85:
		return Enums.ItemQuality.ABOVE_AVERAGE # 30%
	return Enums.ItemQuality.PERFECT           # 15%

## Epic (level 76-90): Above average common
func _roll_epic_quality() -> Enums.ItemQuality:
	var roll := randf()
	if roll < 0.05:
		return Enums.ItemQuality.BELOW_AVERAGE # 5%
	if roll < 0.30:
		return Enums.ItemQuality.AVERAGE       # 25%
	if roll < 0.70:
		return Enums.ItemQuality.ABOVE_AVERAGE # 40%
	return Enums.ItemQuality.PERFECT           # 30%

## Legendary (level 91-100): High quality guaranteed
func _roll_legendary_quality() -> Enums.ItemQuality:
	var roll := randf()
	if roll < 0.15:
		return Enums.ItemQuality.AVERAGE       # 15%
	if roll < 0.55:
		return Enums.ItemQuality.ABOVE_AVERAGE # 40%
	return Enums.ItemQuality.PERFECT           # 45%


## Get melee weapon ID appropriate for tier
func _get_melee_weapon_for_tier(tier: LootTier) -> String:
	var weapons: Array[String] = []
	match tier:
		LootTier.BASIC:
			weapons = ["dagger", "club", "rusty_sword"]
		LootTier.COMMON:
			weapons = ["iron_dagger", "iron_sword", "iron_axe", "mace"]
		LootTier.UNCOMMON:
			weapons = ["steel_sword", "steel_axe", "steel_mace", "longsword"]
		LootTier.RARE:
			weapons = ["fine_longsword", "war_axe", "flanged_mace", "bastard_sword"]
		LootTier.EPIC:
			weapons = ["masterwork_sword", "great_axe", "war_hammer", "claymore"]
		LootTier.LEGENDARY:
			weapons = ["legendary_blade", "executioner_axe", "champion_sword"]

	# Filter to weapons that exist in database
	var valid_weapons: Array[String] = []
	for w in weapons:
		if InventoryManager.weapon_database.has(w):
			valid_weapons.append(w)

	if valid_weapons.is_empty():
		# Fallback to any available weapon
		var all_weapons: Array = InventoryManager.weapon_database.keys()
		if not all_weapons.is_empty():
			return all_weapons[randi() % all_weapons.size()]
		return ""

	return valid_weapons[randi() % valid_weapons.size()]


## Get ranged weapon + ammo data appropriate for tier
func _get_ranged_weapon_for_tier(tier: LootTier) -> Dictionary:
	var options: Array[Dictionary] = []
	match tier:
		LootTier.BASIC:
			options = [
				{"weapon": "shortbow", "ammo": "arrows", "ammo_min": 5, "ammo_max": 10},
				{"weapon": "sling", "ammo": "stones", "ammo_min": 8, "ammo_max": 15}
			]
		LootTier.COMMON:
			options = [
				{"weapon": "hunting_bow", "ammo": "arrows", "ammo_min": 8, "ammo_max": 15},
				{"weapon": "light_crossbow", "ammo": "bolts", "ammo_min": 5, "ammo_max": 10}
			]
		LootTier.UNCOMMON:
			options = [
				{"weapon": "longbow", "ammo": "arrows", "ammo_min": 10, "ammo_max": 20},
				{"weapon": "crossbow", "ammo": "bolts", "ammo_min": 8, "ammo_max": 15}
			]
		LootTier.RARE:
			options = [
				{"weapon": "composite_bow", "ammo": "arrows", "ammo_min": 12, "ammo_max": 25},
				{"weapon": "heavy_crossbow", "ammo": "bolts", "ammo_min": 10, "ammo_max": 18},
				{"weapon": "musket", "ammo": "lead_balls", "ammo_min": 5, "ammo_max": 10}
			]
		LootTier.EPIC:
			options = [
				{"weapon": "masterwork_bow", "ammo": "arrows", "ammo_min": 15, "ammo_max": 30},
				{"weapon": "repeating_crossbow", "ammo": "bolts", "ammo_min": 12, "ammo_max": 24}
			]
		LootTier.LEGENDARY:
			options = [
				{"weapon": "legendary_bow", "ammo": "arrows", "ammo_min": 20, "ammo_max": 40}
			]

	# Filter to weapons that exist
	var valid_options: Array[Dictionary] = []
	for opt in options:
		if InventoryManager.weapon_database.has(opt.weapon):
			valid_options.append(opt)

	if valid_options.is_empty():
		# Fallback
		if InventoryManager.weapon_database.has("hunting_bow"):
			return {"weapon": "hunting_bow", "ammo": "arrows", "ammo_min": 5, "ammo_max": 15}
		return {}

	return valid_options[randi() % valid_options.size()]


## Get armor ID appropriate for tier
func _get_armor_for_tier(tier: LootTier) -> String:
	var armors: Array[String] = []
	match tier:
		LootTier.BASIC:
			armors = ["padded_armor", "cloth_robe"]
		LootTier.COMMON:
			armors = ["leather_armor", "leather_cap", "leather_boots"]
		LootTier.UNCOMMON:
			armors = ["studded_leather", "chain_shirt", "iron_helm"]
		LootTier.RARE:
			armors = ["chainmail", "steel_helm", "steel_boots", "steel_gauntlets"]
		LootTier.EPIC:
			armors = ["plate_armor", "full_helm", "plate_gauntlets"]
		LootTier.LEGENDARY:
			armors = ["masterwork_plate", "champion_armor"]

	# Filter to armors that exist
	var valid_armors: Array[String] = []
	for a in armors:
		if InventoryManager.armor_database.has(a):
			valid_armors.append(a)

	if valid_armors.is_empty():
		var all_armors: Array = InventoryManager.armor_database.keys()
		if not all_armors.is_empty():
			return all_armors[randi() % all_armors.size()]
		return ""

	return valid_armors[randi() % valid_armors.size()]


## Add consumables based on tier
func _add_consumables_for_tier(tier: LootTier, quality_func: Callable) -> void:
	# Food (higher chance at lower tiers)
	var food_chance := 0.6 - (int(tier) * 0.05)
	if randf() < food_chance:
		var foods: Array[String] = []
		match tier:
			LootTier.BASIC, LootTier.COMMON:
				foods = ["bread", "cheese", "dried_meat"]
			LootTier.UNCOMMON, LootTier.RARE:
				foods = ["cooked_meat", "meat_pie", "wine"]
			LootTier.EPIC, LootTier.LEGENDARY:
				foods = ["fine_wine", "gourmet_meal", "aged_cheese"]

		var valid_foods: Array[String] = []
		for f in foods:
			if InventoryManager.item_database.has(f):
				valid_foods.append(f)

		if not valid_foods.is_empty():
			add_item(valid_foods[randi() % valid_foods.size()], randi_range(1, 2), Enums.ItemQuality.AVERAGE)

	# Potions (higher chance at higher tiers)
	var potion_chance := 0.1 + (int(tier) * 0.08)
	if randf() < potion_chance:
		var potions: Array[String] = []
		match tier:
			LootTier.BASIC:
				potions = ["minor_health_potion"]
			LootTier.COMMON:
				potions = ["health_potion", "minor_stamina_potion"]
			LootTier.UNCOMMON:
				potions = ["health_potion", "stamina_potion", "antidote"]
			LootTier.RARE:
				potions = ["greater_health_potion", "mana_potion", "cure_poison"]
			LootTier.EPIC:
				potions = ["superior_health_potion", "elixir_of_strength"]
			LootTier.LEGENDARY:
				potions = ["supreme_health_potion", "legendary_elixir"]

		var valid_potions: Array[String] = []
		for p in potions:
			if InventoryManager.item_database.has(p):
				valid_potions.append(p)

		if not valid_potions.is_empty():
			add_item(valid_potions[randi() % valid_potions.size()], 1, quality_func.call())


## Add utility items based on tier
func _add_utility_items_for_tier(tier: LootTier) -> void:
	# Lockpicks
	if randf() < 0.15:
		var qty := 1
		if tier >= LootTier.RARE:
			qty = randi_range(2, 4)
		if InventoryManager.item_database.has("lockpick"):
			add_item("lockpick", qty, Enums.ItemQuality.AVERAGE)

	# Repair kits (higher tiers)
	if tier >= LootTier.UNCOMMON and randf() < 0.1:
		if InventoryManager.item_database.has("repair_kit"):
			add_item("repair_kit", 1, Enums.ItemQuality.AVERAGE)

	# Torches (lower tiers)
	if tier <= LootTier.COMMON and randf() < 0.2:
		if InventoryManager.item_database.has("torch"):
			add_item("torch", randi_range(1, 3), Enums.ItemQuality.AVERAGE)

	# Rope (all tiers, low chance)
	if randf() < 0.08:
		if InventoryManager.item_database.has("rope"):
			add_item("rope", 1, Enums.ItemQuality.AVERAGE)
