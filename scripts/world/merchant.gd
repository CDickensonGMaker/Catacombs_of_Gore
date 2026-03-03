## merchant.gd - Merchant NPC for buying/selling items
## Follows RepairStation pattern for interaction
class_name Merchant
extends StaticBody3D

const DEBUG := false

## Visual representation
var mesh_root: Node3D
var body_mesh: MeshInstance3D
var billboard_sprite: BillboardSprite
var interaction_area: Area3D

## Sprite configuration (if using billboard sprite instead of mesh)
var sprite_texture: Texture2D = null
var sprite_h_frames: int = 3
var sprite_v_frames: int = 3
var sprite_pixel_size: float = 0.027  # (was 0.0384 - reduced 30%)

## Shop UI instance
var shop_ui: Control = null
var shop_ui_script = preload("res://scripts/ui/shop_ui.gd")

## Merchant configuration
@export var merchant_name: String = "Merchant"
@export var merchant_id: String = ""  # Unique ID for dialogue flag matching (uses merchant_name if empty)
@export var is_female: bool = false  # Whether this merchant is female (affects default sprite)
@export var buy_price_multiplier: float = 1.0  # Price markup when player buys

## NPC properties for central turn-in system
var npc_id: String:
	get:
		return get_npc_id()
var npc_type: String = "merchant"  # For NPC_TYPE_IN_REGION turn-ins
@export var region_id: String = ""  # Set by zone when spawned or in scene
@export var sell_price_multiplier: float = 0.5  # Price when player sells (50% of value)
@export var shop_tier: LootTables.LootTier = LootTables.LootTier.UNCOMMON
@export var shop_type: String = "general"
@export var dialogue_data: DialogueData
## Knowledge profile for topic-based conversations (if no dialogue_data)
@export var knowledge_profile: NPCKnowledgeProfile
## Use topic-based conversation instead of direct shop
@export var use_conversation_system: bool = false

## Shop inventory: Array of {item_id, price, quantity, quality}
## quantity of -1 means infinite stock
var shop_inventory: Array[Dictionary] = []

## PS1-style material
var merchant_material: StandardMaterial3D

## Health and combat
var max_health: int = 50
var current_health: int = 50
var _is_dead: bool = false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("merchants")
	add_to_group("shops")
	add_to_group("npcs")
	add_to_group("attackable")

	current_health = max_health

	# Add to specific shop type groups for minimap icons
	match shop_type:
		"blacksmith":
			add_to_group("blacksmiths")
		"weapon":
			add_to_group("blacksmiths")  # Weapon shops show as blacksmith
		"armor":
			add_to_group("blacksmiths")  # Armor shops show as blacksmith
		"alchemist":
			add_to_group("alchemists")
		"temple":
			add_to_group("temples")

	# Setup collision for player interaction detection
	collision_layer = 1  # World layer for physics
	collision_mask = 0   # Don't collide with anything

	# Only create visuals/areas if not already present (supports scene instancing)
	if not get_node_or_null("MeshRoot"):
		_create_merchant_mesh()
	else:
		# Find existing billboard sprite for reference
		mesh_root = get_node_or_null("MeshRoot")
		billboard_sprite = get_node_or_null("MeshRoot/BillboardSprite")

	if not get_node_or_null("InteractionArea"):
		_create_interaction_area()
	else:
		interaction_area = get_node_or_null("InteractionArea")

	_register_compass_poi()
	_register_with_world_data()

	# Initialize default inventory if empty
	if shop_inventory.is_empty():
		_setup_default_inventory()


## Register this merchant as a compass POI
## Uses instance ID for guaranteed uniqueness across scenes
func _register_compass_poi() -> void:
	add_to_group("compass_poi")
	# Use instance_id for guaranteed uniqueness - prevents ghost markers across scenes
	set_meta("poi_id", "merchant_%d" % get_instance_id())
	set_meta("poi_name", merchant_name)
	set_meta("poi_color", Color(0.2, 0.9, 0.3))  # Green for merchants


## Register this NPC with WorldData for quest navigation/tracking
func _register_with_world_data() -> void:
	var effective_id: String = get_npc_id()
	var cell: Vector2i = WorldGrid.world_to_cell(global_position)
	var zone_id: String = ""

	# Try to get zone_id from parent scene
	var parent: Node = get_parent()
	while parent:
		if "zone_id" in parent:
			zone_id = parent.zone_id
			break
		parent = parent.get_parent()

	# Use region_id if zone_id not found
	if zone_id.is_empty():
		zone_id = region_id if not region_id.is_empty() else "shop_unknown"

	PlayerGPS.register_npc(self, effective_id, npc_type, zone_id)


## Unregister from PlayerGPS when removed from scene
func _exit_tree() -> void:
	PlayerGPS.unregister_npc(get_npc_id())

func _create_merchant_mesh() -> void:
	## Create visual representation - billboard sprite if texture provided, otherwise capsule mesh

	mesh_root = Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)

	# Use provided texture or fall back to available human sprites
	var texture_to_use: Texture2D = sprite_texture
	var h_frames_to_use: int = sprite_h_frames
	var v_frames_to_use: int = sprite_v_frames

	# Check ActorRegistry for Zoo patches (applies to scene-instanced merchants)
	# Determine actor_id to check - use merchant_id, merchant_name snake_case, or shop_type
	var registry_id: String = merchant_id
	if registry_id.is_empty():
		registry_id = merchant_name.to_lower().replace(" ", "_")
	# Also try shop type based IDs
	var shop_registry_id: String = ""
	match shop_type:
		"blacksmith", "weapon", "armor":
			shop_registry_id = "blacksmith"
		"general":
			shop_registry_id = "merchant_civilian"
		"magic", "alchemist":
			shop_registry_id = "magic_shop_worker"

	# Check ActorRegistry for actor configuration (base ZooRegistry + any patches)
	# ZooRegistry is the source of truth - scene file values are only fallback
	if ActorRegistry:
		# Try merchant-specific ID first, then shop type ID
		for check_id in [registry_id, shop_registry_id]:
			if check_id.is_empty():
				continue
			if ActorRegistry.has_actor(check_id):
				var config: Dictionary = ActorRegistry.get_sprite_config(check_id)
				if not config.is_empty():
					var registry_path: String = config.get("sprite_path", "")
					if not registry_path.is_empty() and ResourceLoader.exists(registry_path):
						texture_to_use = load(registry_path) as Texture2D
						h_frames_to_use = config.get("h_frames", h_frames_to_use)
						v_frames_to_use = config.get("v_frames", v_frames_to_use)
						sprite_pixel_size = config.get("pixel_size", sprite_pixel_size)
						if DEBUG:
							print("[Merchant] Using ActorRegistry sprite for %s (id: %s)" % [merchant_name, check_id])
						break

	if not texture_to_use:
		# Try fallback paths based on gender
		var fallback_paths: Array[Dictionary]
		if is_female:
			fallback_paths = [
				{"path": "res://assets/sprites/npcs/civilians/lady_in_red.png", "h": 8, "v": 1, "size": 0.0182},
				{"path": "res://assets/sprites/npcs/civilians/barmaid_3x3.png", "h": 3, "v": 1, "size": 0.0234},
				{"path": "res://assets/sprites/npcs/merchants/merchant_civilian.png", "h": 1, "v": 1, "size": 0.0115},
			]
		else:
			fallback_paths = [
				{"path": "res://assets/sprites/npcs/merchants/merchant_civilian.png", "h": 1, "v": 1, "size": 0.0384},
				{"path": "res://assets/sprites/npcs/civilians/man_civilian.png", "h": 8, "v": 2, "size": 0.0384},
			]

		for fallback: Dictionary in fallback_paths:
			var tex: Texture2D = load(fallback["path"]) as Texture2D
			if tex:
				texture_to_use = tex
				h_frames_to_use = fallback["h"]
				v_frames_to_use = fallback["v"]
				sprite_pixel_size = fallback.get("size", sprite_pixel_size)
				if DEBUG:
					print("[Merchant] Using fallback sprite %s for %s" % [fallback["path"], merchant_name])
				break

	if not texture_to_use:
		push_warning("[Merchant] No sprite found for %s" % merchant_name)
		return

	# Always use billboard sprite
	billboard_sprite = BillboardSprite.new()
	billboard_sprite.sprite_sheet = texture_to_use
	billboard_sprite.h_frames = h_frames_to_use
	billboard_sprite.v_frames = v_frames_to_use
	billboard_sprite.pixel_size = sprite_pixel_size
	billboard_sprite.offset_y = 0.0  # Standard positioning - sprite bottom at ground level
	billboard_sprite.idle_frames = h_frames_to_use  # Use all columns for idle animation
	billboard_sprite.idle_fps = 4.0  # Slow idle animation
	billboard_sprite.name = "BillboardSprite"
	mesh_root.add_child(billboard_sprite)
	if DEBUG:
		print("[Merchant] Created billboard sprite for %s" % merchant_name)

func _create_interaction_area() -> void:
	## Create Area3D for raycast detection by player
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables (2^8)
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.6
	capsule.height = 2.0
	area_shape.shape = capsule
	area_shape.position = Vector3(0, 1.0, 0)
	interaction_area.add_child(area_shape)

## Setup default inventory using LootTables system
func _setup_default_inventory() -> void:
	if DEBUG:
		print("[Merchant] Setting up inventory...")
		print("[Merchant] Shop tier: %d, Shop type: %s" % [shop_tier, shop_type])

	# General store uses fixed inventory (tools and supplies)
	if shop_type == "general":
		# Required inventory - always available (infinite stock)
		_add_shop_item("lockpick", 25, -1, Enums.ItemQuality.AVERAGE)  # Infinite stock
		_add_shop_item("repair_kit", 50, -1, Enums.ItemQuality.AVERAGE)  # Infinite stock
		_add_shop_item("pickaxe", 80, -1, Enums.ItemQuality.AVERAGE)  # Mining tool
		_add_shop_item("axe", 150, -1, Enums.ItemQuality.AVERAGE)  # Woodcutting/combat
		_add_shop_item("torch", 15, -1, Enums.ItemQuality.AVERAGE)  # Light source
		_add_shop_item("empty_vial", 10, -1, Enums.ItemQuality.AVERAGE)  # Alchemy supplies

		# Optional inventory - small chance to have potions (marked up vs magic shops)
		# Use RNG seeded by merchant position for consistent stock per merchant
		var stock_rng := RandomNumberGenerator.new()
		stock_rng.seed = hash(merchant_name + str(global_position))

		# 35% chance for each potion type, limited stock, marked up prices
		if stock_rng.randf() < 0.35:
			var health_qty: int = stock_rng.randi_range(1, 3)
			_add_shop_item("health_potion", 75, health_qty, Enums.ItemQuality.AVERAGE)  # 50% markup
		if stock_rng.randf() < 0.35:
			var stamina_qty: int = stock_rng.randi_range(1, 3)
			_add_shop_item("stamina_potion", 60, stamina_qty, Enums.ItemQuality.AVERAGE)  # 50% markup
		if stock_rng.randf() < 0.35:
			var mana_qty: int = stock_rng.randi_range(1, 3)
			_add_shop_item("mana_potion", 110, mana_qty, Enums.ItemQuality.AVERAGE)  # ~47% markup

		# Bestiary books - general stores carry tiers 1-5 (common creatures)
		_add_random_bestiary_books(stock_rng, 1, 5, 0.4)

		if DEBUG:
			print("[Merchant] General store: tools, supplies, and possibly potions")
		return

	# All shop types (including alchemist) use LootTables random generation
	if DEBUG:
		print("[Merchant] InventoryManager database sizes: weapons=%d, armor=%d, items=%d" % [
			InventoryManager.weapon_database.size(),
			InventoryManager.armor_database.size(),
			InventoryManager.item_database.size()
		])

	var generated := LootTables.generate_shop_inventory(shop_tier, shop_type)

	if DEBUG:
		print("[Merchant] LootTables returned %d items" % generated.size())

	for item in generated:
		shop_inventory.append({
			"item_id": item.item_id,
			"item_type": item.item_type,
			"price": item.price,
			"quantity": item.quantity,
			"quality": item.get("quality", Enums.ItemQuality.AVERAGE)
		})

	# Add bestiary books to magic shops and alchemists (tiers 1-10, higher chance for rare books)
	if shop_type == "magic" or shop_type == "alchemist":
		var book_rng := RandomNumberGenerator.new()
		book_rng.seed = hash(merchant_name + str(global_position) + "books")
		_add_random_bestiary_books(book_rng, 1, 10, 0.5)  # Higher chance, all tiers

	if DEBUG:
		print("[Merchant] Final shop_inventory count: %d item types" % shop_inventory.size())
		if shop_inventory.is_empty():
			print("[Merchant] WARNING: Shop inventory is empty! Check LootTables output above.")

## Add random bestiary books based on tier range and chance
func _add_random_bestiary_books(rng: RandomNumberGenerator, min_tier: int, max_tier: int, base_chance: float) -> void:
	var book_data: Array[Dictionary] = [
		{"id": "bestiary_vol_1_vermin", "tier": 1, "price": 50},
		{"id": "bestiary_vol_2_predators", "tier": 2, "price": 75},
		{"id": "bestiary_vol_3_arachnids", "tier": 3, "price": 100},
		{"id": "bestiary_vol_4_goblins", "tier": 4, "price": 150},
		{"id": "bestiary_vol_5_bandits", "tier": 5, "price": 200},
		{"id": "bestiary_vol_6_undead", "tier": 6, "price": 250},
		{"id": "bestiary_vol_7_cultists", "tier": 7, "price": 300},
		{"id": "bestiary_vol_8_monsters", "tier": 8, "price": 400},
		{"id": "bestiary_vol_9_tengers", "tier": 9, "price": 500},
		{"id": "bestiary_vol_10_legendary", "tier": 10, "price": 750}
	]

	for book: Dictionary in book_data:
		var tier: int = book["tier"]
		if tier < min_tier or tier > max_tier:
			continue

		# Higher tier books have lower chance to appear
		var tier_modifier: float = 1.0 - (tier - min_tier) * 0.08
		var chance: float = base_chance * tier_modifier

		if rng.randf() < chance:
			var marked_up_price: int = int(book["price"] * buy_price_multiplier * 1.2)  # 20% book markup
			_add_shop_item(book["id"], marked_up_price, 1, Enums.ItemQuality.AVERAGE)


## Helper to add items to shop inventory
func _add_shop_item(item_id: String, base_price: int, quantity: int, quality: Enums.ItemQuality) -> void:
	# Verify item exists in InventoryManager databases
	if not InventoryManager._item_exists(item_id):
		push_warning("[Merchant] Item not found in database: " + item_id)
		return

	var price := int(base_price * buy_price_multiplier)
	shop_inventory.append({
		"item_id": item_id,
		"price": price,
		"quantity": quantity,
		"quality": quality
	})

## Called by player interaction system
func interact(_interactor: Node) -> void:
	# Priority 0: Check for quest turn-ins using central turn-in system
	var turnin_quests := QuestManager.get_turnin_quests_for_entity(self)
	if not turnin_quests.is_empty():
		_show_quest_turnin_dialogue(turnin_quests[0])
		return

	# Use topic-based ConversationSystem (TRADE topic opens shop)
	var profile := knowledge_profile
	if not profile:
		profile = _get_merchant_profile()
	if profile:
		ConversationSystem.start_conversation(self, profile)
		return

	# Fallback: Open shop directly if no profile
	_open_shop_ui()


## Pending quest to complete after dialogue
var _pending_quest_turnin: String = ""


## Show dialogue for quest turn-in using ConversationSystem scripted dialogue
func _show_quest_turnin_dialogue(quest_id: String) -> void:
	var quest := QuestManager.get_quest(quest_id)
	if not quest:
		return

	# Format reward text
	var rewards: Array[String] = []
	if quest.rewards.has("gold") and quest.rewards["gold"] > 0:
		rewards.append("%d gold" % quest.rewards["gold"])
	if quest.rewards.has("xp") and quest.rewards["xp"] > 0:
		rewards.append("%d XP" % quest.rewards["xp"])
	if quest.rewards.has("items"):
		for item in quest.rewards["items"]:
			var item_name: String = item.get("id", "item")
			var quantity: int = item.get("quantity", 1)
			rewards.append("%dx %s" % [quantity, item_name])

	var reward_text: String = "You received: " + ", ".join(rewards) if not rewards.is_empty() else "Thank you for your help!"

	# Build scripted dialogue lines
	var lines: Array = []

	# Line 0: Quest complete acknowledgment
	lines.append(ConversationSystem.create_scripted_line(
		merchant_name,
		"Ah, you've completed '%s'. Well done! Here's your reward." % quest.title,
		[ConversationSystem.create_scripted_choice("Accept reward", 1)]
	))

	# Line 1: Reward given
	lines.append(ConversationSystem.create_scripted_line(
		merchant_name,
		reward_text,
		[],
		true  # is_end
	))

	# Store quest ID to complete when dialogue ends
	_pending_quest_turnin = quest_id

	# Start scripted dialogue with callback
	ConversationSystem.start_scripted_dialogue(lines, _on_quest_turnin_ended)


## Handle quest turn-in dialogue completion
func _on_quest_turnin_ended() -> void:
	if not _pending_quest_turnin.is_empty():
		var result: Dictionary = QuestManager.try_turnin(self, _pending_quest_turnin)

		if result.get("success", false):
			_show_notification("Quest completed!")
		else:
			# Fallback: Direct completion if turn-in system failed
			QuestManager.complete_quest(_pending_quest_turnin)
			_show_notification("Quest completed!")

		_pending_quest_turnin = ""


## Show notification via HUD
func _show_notification(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)


## Get merchant-specific knowledge profile
func _get_merchant_profile() -> NPCKnowledgeProfile:
	var default_path := "res://data/npc_profiles/merchant_default.tres"
	if ResourceLoader.exists(default_path):
		return load(default_path) as NPCKnowledgeProfile
	return NPCKnowledgeProfile.merchant()


## Get unique NPC ID for conversation system
func get_npc_id() -> String:
	if not merchant_id.is_empty():
		return merchant_id
	return merchant_name.to_snake_case() if merchant_name else "merchant_" + str(get_instance_id())

## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	return "Talk to " + merchant_name

func _open_shop_ui() -> void:
	## Create and show the shop UI
	if shop_ui and is_instance_valid(shop_ui):
		shop_ui.queue_free()

	# Create the UI
	shop_ui = Control.new()
	shop_ui.set_script(shop_ui_script)
	shop_ui.name = "ShopUI"

	# Pass merchant reference
	shop_ui.set("merchant", self)

	# Add to scene tree (as child of canvas layer)
	var canvas := CanvasLayer.new()
	canvas.name = "ShopUICanvas"
	canvas.layer = 100
	get_tree().current_scene.add_child(canvas)
	canvas.add_child(shop_ui)

	# Connect close signal
	if shop_ui.has_signal("ui_closed"):
		shop_ui.ui_closed.connect(_on_shop_ui_closed.bind(canvas))

	# Enter menu mode and pause
	GameManager.enter_menu()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Open the UI (pass self as merchant)
	if shop_ui.has_method("open"):
		shop_ui.open(self)

func _on_shop_ui_closed(canvas: CanvasLayer) -> void:
	## Handle shop UI close
	GameManager.exit_menu()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if canvas and is_instance_valid(canvas):
		canvas.queue_free()

	shop_ui = null

	# Sound effect hook for later
	# AudioManager.play_ui_close()

## Buy an item from the shop
## Returns true if purchase successful
func buy_item(shop_index: int) -> bool:
	if shop_index < 0 or shop_index >= shop_inventory.size():
		return false

	var shop_item: Dictionary = shop_inventory[shop_index]
	var item_id: String = shop_item.item_id
	var price: int = shop_item.price
	var quality: Enums.ItemQuality = shop_item.quality

	# Check stock
	if shop_item.quantity == 0:
		push_warning("[Merchant] Item out of stock: " + item_id)
		return false

	# Check player gold
	if InventoryManager.gold < price:
		push_warning("[Merchant] Not enough gold. Need: %d, Have: %d" % [price, InventoryManager.gold])
		return false

	# Complete purchase (no hard inventory limit - encumbrance system handles weight)
	InventoryManager.remove_gold(price)
	InventoryManager.add_item(item_id, 1, quality)

	# Reduce stock (unless infinite)
	if shop_item.quantity > 0:
		shop_item.quantity -= 1

	# Sound effect hook
	# AudioManager.play_item_pickup()

	return true

## Sell an item to the shop
## Returns true if sale successful
func sell_item(inventory_index: int) -> bool:
	if inventory_index < 0 or inventory_index >= InventoryManager.inventory.size():
		return false

	var inv_item: Dictionary = InventoryManager.inventory[inventory_index]
	var item_id: String = inv_item.item_id
	var quality: Enums.ItemQuality = inv_item.quality

	# Calculate sell price
	var base_value := InventoryManager.get_item_value(item_id, quality)
	var sell_price := int(base_value * sell_price_multiplier)

	# Remove from player inventory
	if not InventoryManager.remove_item(item_id, 1, quality):
		return false

	# Emit item_sold signal for quest temptation tracking
	InventoryManager.item_sold.emit(item_id, 1, quality)

	# Give player gold
	InventoryManager.add_gold(sell_price)

	# Optionally add to shop stock (items sold to merchant become available)
	_add_to_shop_stock(item_id, quality)

	# Sound effect hook
	# AudioManager.play_item_drop()

	return true

## Add a sold item back to shop stock
func _add_to_shop_stock(item_id: String, quality: Enums.ItemQuality) -> void:
	# Check if item already exists in shop
	for item in shop_inventory:
		if item.item_id == item_id and item.quality == quality:
			if item.quantity >= 0:  # Don't modify infinite stock items
				item.quantity += 1
			return

	# Add as new item with calculated price
	var base_value := InventoryManager.get_item_value(item_id, quality)
	var buy_price := int(base_value * buy_price_multiplier)
	shop_inventory.append({
		"item_id": item_id,
		"price": buy_price,
		"quantity": 1,
		"quality": quality
	})

## Get sell price for a player inventory item
func get_sell_price(inventory_index: int) -> int:
	if inventory_index < 0 or inventory_index >= InventoryManager.inventory.size():
		return 0

	var inv_item: Dictionary = InventoryManager.inventory[inventory_index]
	var base_value := InventoryManager.get_item_value(inv_item.item_id, inv_item.quality)
	return int(base_value * sell_price_multiplier)

## Get the effective merchant ID for dialogue flag matching
func get_effective_merchant_id() -> String:
	if merchant_id.is_empty():
		# Convert merchant_name to snake_case for flag matching
		return merchant_name.to_lower().replace(" ", "_")
	return merchant_id

## Get dialogue-based price modifier from ConversationSystem flags
## Returns a multiplier: <1.0 = discount, >1.0 = markup
## Flag format: "{merchant_id}_{flag_name}" (e.g., "grimwald_haggle_success")
func get_dialogue_price_modifier() -> float:
	var mid := get_effective_merchant_id()
	var modifier := 1.0

	# Check for temporary discounts (from successful dialogue checks)
	# haggle_success = 10% discount
	if ConversationSystem.has_flag(mid + "_haggle_success"):
		modifier -= 0.10

	# intimidate_success = 15% discount
	if ConversationSystem.has_flag(mid + "_intimidate_success"):
		modifier -= 0.15

	# Check for permanent relationship modifiers
	# merchant_befriend = 5% permanent discount
	if ConversationSystem.has_flag(mid + "_befriend"):
		modifier -= 0.05

	# merchant_angered = 20% markup (penalty)
	if ConversationSystem.has_flag(mid + "_angered"):
		modifier += 0.20

	# Ensure modifier doesn't go below a minimum (can't get free items)
	return maxf(0.5, modifier)

## Get Speech skill sell price modifier (better Speech = better sell prices)
## Formula: 1.0 + (speech * 0.02) + (persuasion * 0.02) + (negotiation * 0.05) + dialogue_modifier
func get_speech_sell_modifier() -> float:
	var speech := 0
	var persuasion := 0
	var negotiation := 0
	if GameManager.player_data:
		speech = GameManager.player_data.get_effective_stat(Enums.Stat.SPEECH)
		persuasion = GameManager.player_data.get_skill(Enums.Skill.PERSUASION)
		negotiation = GameManager.player_data.get_skill(Enums.Skill.NEGOTIATION)

	# Speech: +2% sell value per point
	# PERSUASION: +2% sell value per level (up to +20% at level 10)
	# NEGOTIATION: +5% sell value per level (up to +50% at level 10)
	var skill_modifier := 1.0 + (speech * 0.02) + (persuasion * 0.02) + (negotiation * 0.05)

	# Dialogue modifiers work inversely for selling (discounts = worse sell prices)
	# So we invert the dialogue modifier effect for sells
	var dialogue_mod := get_dialogue_price_modifier()
	# If dialogue gives 0.9 (10% discount on buys), sells get 1.1 (10% better)
	var inverted_dialogue := 2.0 - dialogue_mod

	return skill_modifier * inverted_dialogue

## Get Speech skill buy price modifier (better Speech = lower buy prices)
## Formula: Speech -1% per point, PERSUASION -1% per level, NEGOTIATION -3% per level, + dialogue modifiers, capped at 50% off
func get_speech_buy_modifier() -> float:
	var speech := 0
	var persuasion := 0
	var negotiation := 0
	if GameManager.player_data:
		speech = GameManager.player_data.get_effective_stat(Enums.Stat.SPEECH)
		persuasion = GameManager.player_data.get_skill(Enums.Skill.PERSUASION)
		negotiation = GameManager.player_data.get_skill(Enums.Skill.NEGOTIATION)

	# Speech: -1% buy price per point
	# PERSUASION: -1% buy price per level (up to -10% at level 10)
	# NEGOTIATION: -3% buy price per level (up to -30% at level 10)
	var skill_modifier := 1.0 - (speech * 0.01) - (persuasion * 0.01) - (negotiation * 0.03)

	# Apply dialogue-based modifier (haggle success, intimidate, befriend/angered)
	var dialogue_mod := get_dialogue_price_modifier()

	# Cap at 50% minimum (can't get items for less than half price)
	return maxf(0.5, skill_modifier * dialogue_mod)

## Get sell price with Speech skill modifier applied
func get_sell_price_with_speech(inventory_index: int) -> int:
	return int(get_sell_price(inventory_index) * get_speech_sell_modifier())

## Get buy price with Speech skill modifier applied
func get_buy_price_with_speech(shop_index: int) -> int:
	if shop_index < 0 or shop_index >= shop_inventory.size():
		return 0
	return int(shop_inventory[shop_index].price * get_speech_buy_modifier())

## Static factory method for spawning merchants
## sprite_path: Optional path to sprite sheet texture (e.g., "res://assets/sprites/npcs/merchant.png")
## h_frames/v_frames: Sprite sheet grid dimensions (default 3x3)
## pixel_size: Size of each pixel in world units (default 0.0384)
## actor_id: Optional actor ID for ActorRegistry lookup (e.g., "blacksmith", "merchant_civilian")
static func spawn_merchant(parent: Node, pos: Vector3, name: String = "Merchant", tier: LootTables.LootTier = LootTables.LootTier.UNCOMMON, type: String = "general", sprite_path: String = "", h_frames: int = 3, v_frames: int = 3, pixel_size: float = 0.0384, female: bool = false, actor_id: String = "") -> Merchant:
	var instance := Merchant.new()
	instance.position = pos
	instance.merchant_name = name
	instance.shop_tier = tier
	instance.shop_type = type
	instance.sprite_pixel_size = pixel_size
	instance.is_female = female

	# Check ActorRegistry for Zoo patches first
	var actual_sprite_path: String = sprite_path
	var actual_h_frames: int = h_frames
	var actual_v_frames: int = v_frames
	var actual_pixel_size: float = pixel_size

	# Determine actor_id to check - use explicit ID or derive from shop type
	var registry_id: String = actor_id
	if registry_id.is_empty():
		# Map shop types to actor IDs
		match type:
			"blacksmith", "weapon", "armor":
				registry_id = "blacksmith"
			"general":
				registry_id = "merchant_civilian"
			"magic", "alchemist":
				registry_id = "magic_shop_worker"
			_:
				registry_id = "merchant_civilian"

	# Check ActorRegistry for patched sprite
	var actor_registry: Node = Engine.get_singleton("ActorRegistry") if Engine.has_singleton("ActorRegistry") else null
	if not actor_registry:
		actor_registry = parent.get_node_or_null("/root/ActorRegistry")

	if actor_registry and actor_registry.has_actor(registry_id):
		var config: Dictionary = actor_registry.get_sprite_config(registry_id)
		if not config.is_empty():
			var registry_path: String = config.get("sprite_path", "")
			if not registry_path.is_empty() and ResourceLoader.exists(registry_path):
				actual_sprite_path = registry_path
				actual_h_frames = config.get("h_frames", h_frames)
				actual_v_frames = config.get("v_frames", v_frames)
				actual_pixel_size = config.get("pixel_size", pixel_size)

	# Load sprite texture if path provided or from registry
	if actual_sprite_path != "":
		var texture = load(actual_sprite_path)
		if texture:
			instance.sprite_texture = texture
			instance.sprite_h_frames = actual_h_frames
			instance.sprite_v_frames = actual_v_frames
			instance.sprite_pixel_size = actual_pixel_size

	# Add collision shape for world collision
	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	col_shape.shape = capsule
	col_shape.position = Vector3(0, 0.9, 0)
	instance.add_child(col_shape)

	parent.add_child(instance)
	return instance


## Take damage from attacks
func take_damage(amount: int, _damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null) -> int:
	if _is_dead:
		return 0

	var actual_damage: int = mini(amount, current_health)
	current_health -= actual_damage

	# Visual feedback - flash red
	if billboard_sprite and billboard_sprite.sprite:
		var original_color: Color = billboard_sprite.sprite.modulate
		billboard_sprite.sprite.modulate = Color(1.0, 0.3, 0.3)
		get_tree().create_timer(0.15).timeout.connect(func():
			if billboard_sprite and billboard_sprite.sprite and not _is_dead:
				billboard_sprite.sprite.modulate = original_color
		)

	# Play hurt sound
	if AudioManager:
		AudioManager.play_sfx("player_hit")

	# Check for death
	if current_health <= 0:
		_die(attacker)

	return actual_damage


## Check if dead
func is_dead() -> bool:
	return _is_dead


## Get armor value (merchants have minimal armor)
func get_armor_value() -> int:
	return 3


## Handle death
func _die(killer: Node = null) -> void:
	if _is_dead:
		return

	_is_dead = true

	print("[Merchant] %s has been killed" % merchant_name)

	# Report crime - killing a merchant is murder
	if killer and killer.is_in_group("player"):
		var crime_region: String = region_id if not region_id.is_empty() else "unknown"
		CrimeManager.report_crime(CrimeManager.CrimeType.MURDER, crime_region, [])

	# Close any open shop UI
	if shop_ui and is_instance_valid(shop_ui):
		var canvas: Node = shop_ui.get_parent()
		shop_ui.queue_free()
		if canvas:
			canvas.queue_free()
		shop_ui = null

	# Spawn corpse with loot
	_spawn_corpse()

	# Emit death signal
	CombatManager.entity_killed.emit(self, killer)

	# Play death sound
	if AudioManager:
		AudioManager.play_sfx("enemy_death")

	# Remove from groups
	remove_from_group("interactable")
	remove_from_group("merchants")
	remove_from_group("shops")
	remove_from_group("npcs")
	remove_from_group("attackable")
	remove_from_group("compass_poi")

	# Unregister from PlayerGPS
	PlayerGPS.unregister_npc(get_npc_id())

	queue_free()


## Spawn a lootable corpse
func _spawn_corpse() -> void:
	var corpse: LootableCorpse = LootableCorpse.spawn_corpse(
		get_parent(),
		global_position,
		merchant_name,
		get_npc_id(),
		5  # Level 5 - decent loot for merchants
	)

	# Add merchant's gold (they had some money)
	corpse.gold = randi_range(50, 200)

	# Add some of their shop inventory as loot
	var loot_count: int = mini(3, shop_inventory.size())
	for i in range(loot_count):
		var item: Dictionary = shop_inventory[randi() % shop_inventory.size()]
		var item_id: String = item.get("item_id", "")
		if not item_id.is_empty():
			corpse.add_item(item_id, 1, item.get("quality", Enums.ItemQuality.AVERAGE))
