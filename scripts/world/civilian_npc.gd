## civilian_npc.gd - Wandering civilian NPCs for towns
## Non-hostile NPCs that wander around and add life to the world
class_name CivilianNPC
extends CharacterBody3D

## Dialogue data for this NPC (optional - for scripted dialogue trees)
@export var dialogue_data: DialogueData

## Knowledge profile for topic-based conversations (optional - if null, uses default)
@export var knowledge_profile: NPCKnowledgeProfile

## Stable NPC ID for quest tracking (e.g., "barmaid_elder_moor")
@export var npc_id: String = ""

## Visual representation
var billboard: BillboardSprite
var collision_shape: CollisionShape3D
var wander: WanderBehavior
var interaction_area: Area3D

## Sprite configuration
## Target height for humanoids in units (roughly 1.8m)
const TARGET_HEIGHT := 2.46

## Per-sprite pixel sizes - calculated from TARGET_HEIGHT / frame_height
## Most sprites are 96px tall, target height 2.46 units = 0.0256 pixel_size
const PIXEL_SIZE_MAN := 0.0256              # 96px frame, 2.46m target
const PIXEL_SIZE_LADY_RED := 0.0256         # 96px frame, 2.46m target
const PIXEL_SIZE_WIZARD := 0.0256           # 96px frame, 2.46m target
const PIXEL_SIZE_BARMAID_BLONDE := 0.0256   # 96px frame, 2.46m target
const PIXEL_SIZE_BARMAID_BRUNETTE := 0.0256 # 96px frame, 2.46m target
## Dwarf sprites are shorter and stockier - roughly 75% of human height
const DWARF_TARGET_HEIGHT := 1.85  # Dwarves are shorter
const PIXEL_SIZE_DWARF := 0.0193            # 96px frame, 1.85m target (shorter)

## New civilian sprite pixel sizes - 96px frame height
const PIXEL_SIZE_GUY_CIVILIAN := 0.0256     # 96px frame, 2.46m target
const PIXEL_SIZE_PINK_LADY := 0.0256        # 96px frame, 2.46m target
const PIXEL_SIZE_MAGIC_SHOP := 0.0256       # 96px frame, 2.46m target
const PIXEL_SIZE_SEDUCTRESS := 0.0256       # 96px frame, 2.46m target
const PIXEL_SIZE_SEDUCTRESS2 := 0.0256      # 96px frame, 2.46m target

## Newer single-frame reference sprites - 96px frame height
const PIXEL_SIZE_NOBLE := 0.0256            # 96px frame, 2.46m target
const PIXEL_SIZE_GLADIATOR := 0.0256        # 96px frame, 2.46m target
const PIXEL_SIZE_HUNTER := 0.0256           # 96px frame, 2.46m target
const PIXEL_SIZE_GUARD_CIV := 0.0256        # 96px frame, 2.46m target
const PIXEL_SIZE_WIZARD_CIV := 0.0256       # 96px frame, 2.46m target
const PIXEL_SIZE_BARD := 0.0256             # 96px frame, 2.46m target
const PIXEL_SIZE_MERCHANT := 0.0256         # 96px frame, 2.46m target
const PIXEL_SIZE_BANDIT := 0.0256           # 96px frame, 2.46m target

var sprite_texture: Texture2D
var sprite_h_frames: int = 1  # Default: single frame (48x96 sprites)
var sprite_v_frames: int = 1  # Default: single frame (48x96 sprites)
var sprite_pixel_size: float = PIXEL_SIZE_MAN  # Default to man size
var sprite_offset_y: float = 0.0  # Vertical offset adjustment

## Color tint for variety
var tint_color: Color = Color.WHITE

## NPC name (for potential dialogue)
var npc_name: String = "Villager"

## Disposition system - personal modifier from player interactions
## Range: -50 to +50, added to calculated disposition
var disposition_modifier: int = 0

## Base disposition before any modifiers (50 = neutral)
var base_disposition: int = 50

## NPC's faction affiliation (if any)
var faction_id: String = ""

## NPC's moral alignment (-100 to 100, 0 = neutral)
var alignment: int = 0

## Region this NPC belongs to (for bounty checks)
var region: String = ""

## Gender for audio/dialogue purposes
var is_female: bool = false

## ============================================================================
## HEALTH & COMBAT SYSTEM
## All NPCs can be attacked and killed with consequences
## ============================================================================

## Health values
@export var max_health: int = 30
var current_health: int = 30

## Is this NPC dead?
var _is_dead: bool = false

## Is this NPC essential (cannot be killed, goes unconscious instead)?
## Set to true for critical quest NPCs
@export var is_essential: bool = false

## Gold carried by this NPC (dropped on death)
@export var gold_carried: int = 0

## Items carried by this NPC (dropped on death)
## Format: [{item_id: String, quantity: int}]
var carried_items: Array[Dictionary] = []

## Witness detection radius (how far NPCs can witness crimes)
const WITNESS_RADIUS := 20.0

## Fleeing behavior when attacked
var is_fleeing: bool = false
var flee_target: Vector3 = Vector3.ZERO
const FLEE_SPEED := 4.0
const FLEE_DURATION := 10.0
var flee_timer: float = 0.0

## Color variations for female NPCs (dress tints)
const DRESS_COLORS := [
	Color(1.0, 1.0, 1.0),      # Original red
	Color(0.7, 0.85, 1.0),     # Blue tint
	Color(0.85, 1.0, 0.7),     # Green tint
	Color(1.0, 0.9, 0.7),      # Yellow/gold tint
	Color(1.0, 0.75, 0.9),     # Pink tint
	Color(0.8, 0.7, 1.0),      # Purple tint
	Color(0.9, 0.9, 0.9),      # White/grey tint
	Color(1.0, 0.85, 0.75),    # Peach tint
]

## Color variations for male NPCs (clothing tints)
const MALE_COLORS := [
	Color(1.0, 1.0, 1.0),      # Original brown/tan
	Color(0.85, 0.9, 1.0),     # Cooler blue-grey
	Color(1.0, 0.95, 0.85),    # Warmer tan
	Color(0.9, 0.85, 0.8),     # Dusty brown
	Color(0.95, 0.9, 0.95),    # Faded purple-grey
	Color(0.85, 0.95, 0.85),   # Sage green tint
	Color(1.0, 0.9, 0.85),     # Rust/orange tint
	Color(0.8, 0.8, 0.85),     # Dark grey
]

## Color variations for wizard/mage robes
const WIZARD_COLORS := [
	Color(1.0, 1.0, 1.0),      # Original black/gold
	Color(0.7, 0.8, 1.0),      # Blue robes
	Color(0.6, 0.4, 0.5),      # Dark maroon
	Color(0.5, 0.7, 0.5),      # Forest green
	Color(0.8, 0.7, 1.0),      # Purple/violet
	Color(0.6, 0.5, 0.4),      # Brown robes
	Color(1.0, 0.9, 0.8),      # Cream/white
	Color(0.5, 0.5, 0.6),      # Dark grey
]

## Dwarf name prefixes and suffixes for procedural name generation
const DWARF_MALE_NAMES := [
	"Thorin", "Balin", "Dwalin", "Gimli", "Gloin", "Oin", "Bifur", "Bofur",
	"Bombur", "Dori", "Nori", "Ori", "Fili", "Kili", "Durin", "Thrain",
	"Borin", "Grimjaw", "Stonefoot", "Ironbeard", "Goldhand", "Hammerfall"
]

const DWARF_FEMALE_NAMES := [
	"Disa", "Gilda", "Thorina", "Brunhild", "Helga", "Ingrid", "Freya",
	"Sigrid", "Astrid", "Ragna", "Hilda", "Gudrun", "Embla", "Thyra"
]

func _ready() -> void:
	add_to_group("civilians")
	add_to_group("npcs")
	add_to_group("interactable")
	add_to_group("attackable")  # Can be attacked by player

	# Setup collision - NPCs collide with world geometry (same layers as player)
	collision_layer = 1
	collision_mask = 5  # Layers 1 and 3 (world geometry + static objects)

	# Initialize health
	current_health = max_health

	# Random gold (poor civilians have little, merchants have more)
	if gold_carried <= 0:
		gold_carried = randi_range(1, 15)

	_create_visual()
	_create_collision()
	_create_interaction_area()
	_setup_wandering()

	# Register with WorldData for tracking
	_register_with_world_data()


## Register this NPC with WorldData for tracking
func _register_with_world_data() -> void:
	var effective_id: String = npc_id if not npc_id.is_empty() else name
	var cell: Vector2i = WorldGrid.world_to_cell(global_position)
	var zone_id: String = ""

	# Try to get zone_id from parent scene
	var parent: Node = get_parent()
	while parent:
		if "zone_id" in parent:
			zone_id = parent.zone_id
			break
		parent = parent.get_parent()

	# Default zone if not found
	if zone_id.is_empty():
		zone_id = "town_unknown"

	PlayerGPS.register_npc(self, effective_id, "civilian", zone_id)


func _exit_tree() -> void:
	var effective_id: String = npc_id if not npc_id.is_empty() else name
	PlayerGPS.unregister_npc(effective_id)


func _create_visual() -> void:
	if not sprite_texture:
		return

	billboard = BillboardSprite.new()
	billboard.sprite_sheet = sprite_texture
	billboard.h_frames = sprite_h_frames
	billboard.v_frames = sprite_v_frames
	billboard.pixel_size = sprite_pixel_size
	billboard.idle_frames = sprite_h_frames
	billboard.walk_frames = sprite_h_frames
	billboard.idle_fps = 3.0
	billboard.walk_fps = 6.0
	billboard.name = "Billboard"
	billboard.offset_y = sprite_offset_y  # Configurable per NPC type
	add_child(billboard)

	# Apply color tint
	call_deferred("_apply_tint")


func _apply_tint() -> void:
	if billboard and billboard.sprite:
		billboard.sprite.modulate = tint_color


func _create_collision() -> void:
	collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	collision_shape.shape = capsule
	collision_shape.position = Vector3(0, 0.8, 0)
	add_child(collision_shape)


func _create_interaction_area() -> void:
	## Create Area3D for raycast detection by player
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables (2^8)
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.8
	area_shape.shape = capsule
	area_shape.position = Vector3(0, 0.9, 0)
	interaction_area.add_child(area_shape)


## Called by player interaction system
func interact(_interactor: Node) -> void:
	# Always use topic-based ConversationSystem
	var profile := knowledge_profile
	if not profile:
		# Create default civilian profile if none assigned
		profile = _get_default_profile()

	if profile:
		ConversationSystem.start_conversation(self, profile)


## Get the default knowledge profile for this NPC type
func _get_default_profile() -> NPCKnowledgeProfile:
	# Try to load default civilian profile
	var default_path := "res://data/npc_profiles/civilian_default.tres"
	if ResourceLoader.exists(default_path):
		return load(default_path) as NPCKnowledgeProfile

	# Create a basic one on the fly
	return NPCKnowledgeProfile.generic_villager()


## Get unique NPC ID for conversation system
func get_npc_id() -> String:
	return name if name else "civilian_" + str(get_instance_id())


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	return "Talk to " + npc_name


## Modify this NPC's personal disposition toward the player
## amount: positive = like more, negative = like less
func modify_disposition(amount: int) -> void:
	var old_modifier: int = disposition_modifier
	disposition_modifier = clampi(disposition_modifier + amount, -50, 50)
	if disposition_modifier != old_modifier:
		print("[NPC] %s disposition changed by %d: %d -> %d" % [npc_name, amount, old_modifier, disposition_modifier])


## Get the NPC's current disposition toward the player
## Uses DispositionCalculator for full calculation
func get_disposition() -> int:
	return DispositionCalculator.calculate_disposition(self)


## Get the disposition status (HOSTILE, UNFRIENDLY, NEUTRAL, FRIENDLY, ALLY)
func get_disposition_status() -> DispositionCalculator.DispositionStatus:
	var disp: int = get_disposition()
	return DispositionCalculator.get_disposition_status(disp)


## Check if NPC will interact with player (not hostile)
func will_interact() -> bool:
	return get_disposition_status() != DispositionCalculator.DispositionStatus.HOSTILE


## Wander behavior configuration (can be overridden per NPC)
@export var wander_radius: float = 12.0      ## How far from spawn to wander
@export var wander_speed: float = 1.8        ## Walking speed
@export var wander_min_wait: float = 0.5     ## Minimum pause at destination
@export var wander_max_wait: float = 2.5     ## Maximum pause at destination
@export var enable_wandering: bool = true    ## Set false for stationary NPCs

func _setup_wandering() -> void:
	if not enable_wandering:
		return

	wander = WanderBehavior.new()
	wander.wander_radius = wander_radius
	wander.move_speed = wander_speed
	wander.min_wait_time = wander_min_wait
	wander.max_wait_time = wander_max_wait
	wander.min_wander_dist = 3.0  # Don't pick targets too close
	add_child(wander)

	# Connect signals for animation
	wander.started_moving.connect(_on_started_moving)
	wander.stopped_moving.connect(_on_stopped_moving)


func _on_started_moving() -> void:
	if billboard:
		billboard.set_state(BillboardSprite.AnimState.WALK)


func _on_stopped_moving() -> void:
	if billboard:
		billboard.set_state(BillboardSprite.AnimState.IDLE)


func _process(delta: float) -> void:
	# Handle fleeing behavior
	if is_fleeing:
		_update_fleeing(delta)
		return

	# Update billboard facing direction
	if billboard and wander:
		billboard.facing_direction = wander.get_facing_direction()


## Update fleeing behavior
func _update_fleeing(delta: float) -> void:
	flee_timer -= delta
	if flee_timer <= 0:
		is_fleeing = false
		if wander:
			wander.resume()
		return

	# Move away from danger
	var direction: Vector3 = (flee_target - global_position).normalized()
	direction.y = 0
	velocity = direction * FLEE_SPEED
	move_and_slide()

	# Update facing direction
	if billboard:
		billboard.facing_direction = direction


## ============================================================================
## COMBAT & DAMAGE SYSTEM
## ============================================================================

## Take damage from an attacker
## Returns actual damage taken
func take_damage(amount: int, damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null) -> int:
	if _is_dead:
		return 0

	# Apply damage
	var actual_damage: int = mini(amount, current_health)
	current_health -= actual_damage

	# Visual feedback - flash red
	if billboard and billboard.sprite:
		var original_color: Color = billboard.sprite.modulate
		billboard.sprite.modulate = Color(1.0, 0.3, 0.3)
		get_tree().create_timer(0.15).timeout.connect(func():
			if billboard and billboard.sprite:
				billboard.sprite.modulate = original_color
		)

	# Report crime if attacker is the player
	if attacker and attacker.is_in_group("player"):
		_report_attack_crime(attacker)

	# Start fleeing from attacker
	if not is_fleeing and attacker and attacker is Node3D:
		_start_fleeing(attacker as Node3D)

	# Check for death
	if current_health <= 0:
		if is_essential:
			# Essential NPCs go unconscious instead
			current_health = 1
			_go_unconscious()
		else:
			_die(attacker)

	var damage_type_name: String = Enums.DamageType.keys()[damage_type] if damage_type < Enums.DamageType.size() else "UNKNOWN"
	var attacker_name: String = attacker.name if attacker else "unknown"
	print("[NPC] %s took %d %s damage from %s (HP: %d/%d)" % [
		npc_name,
		actual_damage,
		damage_type_name,
		attacker_name,
		current_health,
		max_health
	])

	return actual_damage


## Check if this NPC is dead
func is_dead() -> bool:
	return _is_dead


## Start fleeing from a threat
func _start_fleeing(threat: Node3D) -> void:
	is_fleeing = true
	flee_timer = FLEE_DURATION

	# Calculate flee direction (away from threat)
	var direction: Vector3 = (global_position - threat.global_position).normalized()
	direction.y = 0
	flee_target = global_position + direction * 20.0

	# Pause normal wandering
	if wander:
		wander.pause()

	# Alert nearby NPCs
	_alert_nearby_npcs(threat)


## Alert nearby NPCs about danger
func _alert_nearby_npcs(threat: Node3D) -> void:
	var nearby_npcs := get_tree().get_nodes_in_group("npcs")
	for npc in nearby_npcs:
		if npc == self:
			continue
		if not npc is Node3D:
			continue

		var distance: float = global_position.distance_to((npc as Node3D).global_position)
		if distance <= WITNESS_RADIUS:
			if npc.has_method("on_npc_attacked"):
				npc.on_npc_attacked(self, threat)


## Called when a nearby NPC is attacked
func on_npc_attacked(victim: Node, attacker: Node) -> void:
	if _is_dead or is_fleeing:
		return

	# Witness the crime
	if attacker and attacker.is_in_group("player") and attacker is Node3D:
		_start_fleeing(attacker as Node3D)


## Report attack crime to CrimeManager
func _report_attack_crime(attacker: Node) -> void:
	# Find witnesses (other NPCs who can see this)
	var witnesses: Array = _get_witnesses()

	# Always include self as witness if still alive
	if not _is_dead:
		witnesses.append(self)

	# Determine region
	var crime_region: String = region
	if crime_region.is_empty():
		crime_region = _get_current_region()

	# Report assault
	CrimeManager.report_crime(CrimeManager.CrimeType.ASSAULT, crime_region, witnesses)


## Report murder crime when NPC dies
func _report_murder_crime(attacker: Node) -> void:
	# Find witnesses (other NPCs who can see this)
	var witnesses: Array = _get_witnesses()

	# Determine region
	var crime_region: String = region
	if crime_region.is_empty():
		crime_region = _get_current_region()

	# Report murder (more serious than assault)
	CrimeManager.report_crime(CrimeManager.CrimeType.MURDER, crime_region, witnesses)

	# Apply faction reputation penalty
	_apply_murder_faction_penalty(attacker)


## Get all NPCs who can witness this crime
func _get_witnesses() -> Array:
	var witnesses: Array = []
	var nearby_npcs := get_tree().get_nodes_in_group("npcs")

	for npc in nearby_npcs:
		if npc == self:
			continue
		if not npc is Node3D:
			continue
		if npc.has_method("is_dead") and npc.is_dead():
			continue

		var distance: float = global_position.distance_to((npc as Node3D).global_position)
		if distance <= WITNESS_RADIUS:
			# Check line of sight (optional, can be simplified)
			witnesses.append(npc)

	# Also check for guards specifically
	var guards := get_tree().get_nodes_in_group("guards")
	for guard in guards:
		if guard in witnesses:
			continue
		if not guard is Node3D:
			continue

		var distance: float = global_position.distance_to((guard as Node3D).global_position)
		if distance <= WITNESS_RADIUS * 1.5:  # Guards have better detection
			witnesses.append(guard)

	return witnesses


## Get current region based on position
func _get_current_region() -> String:
	# Try to get region from WorldGrid
	var cell: Vector2i = WorldGrid.world_to_cell(global_position)
	var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(cell)
	if cell_info and not cell_info.region_name.is_empty():
		return cell_info.region_name.to_lower().replace(" ", "_")

	# Fallback to parent zone_id
	var parent: Node = get_parent()
	while parent:
		if "zone_id" in parent:
			return parent.zone_id
		parent = parent.get_parent()

	return "unknown"


## Apply faction reputation penalty for murder
func _apply_murder_faction_penalty(attacker: Node) -> void:
	if not attacker or not attacker.is_in_group("player"):
		return

	# Penalty to local faction
	if not faction_id.is_empty() and FactionManager:
		FactionManager.modify_reputation(faction_id, -25, "murdered %s" % npc_name)

	# General civilian penalty
	if FactionManager and FactionManager.factions.has("civilians"):
		FactionManager.modify_reputation("civilians", -10, "murdered innocent")


## Handle NPC death
func _die(killer: Node = null) -> void:
	if _is_dead:
		return

	_is_dead = true

	print("[NPC] %s has been killed by %s" % [npc_name, killer.name if killer else "unknown"])

	# Report murder crime
	if killer and killer.is_in_group("player"):
		_report_murder_crime(killer)

	# Remove from groups
	remove_from_group("interactable")
	remove_from_group("npcs")
	remove_from_group("attackable")

	# Stop any movement
	if wander:
		wander.queue_free()
		wander = null
	is_fleeing = false
	velocity = Vector3.ZERO

	# Spawn lootable corpse
	_spawn_corpse()

	# Emit killed signal via CombatManager
	CombatManager.entity_killed.emit(self, killer)

	# Play death sound
	if AudioManager:
		AudioManager.play_sfx("npc_death")

	# Queue removal after short delay (let corpse spawn)
	get_tree().create_timer(0.1).timeout.connect(queue_free)


## Spawn a lootable corpse at death position
func _spawn_corpse() -> void:
	var corpse: LootableCorpse = LootableCorpse.spawn_corpse(
		get_parent(),
		global_position,
		npc_name,
		npc_id,
		1  # Level 1 civilian
	)

	# Add gold
	corpse.gold = gold_carried

	# Add any carried items
	for item: Dictionary in carried_items:
		var item_id: String = item.get("item_id", "") as String
		var qty: int = item.get("quantity", 1) as int
		if not item_id.is_empty():
			corpse.add_item(item_id, qty, Enums.ItemQuality.AVERAGE)

	# Maybe add some random civilian items
	if randf() < 0.3:
		corpse.add_item("bread", 1, Enums.ItemQuality.AVERAGE)
	if randf() < 0.2:
		corpse.add_item("cheese", 1, Enums.ItemQuality.AVERAGE)
	if randf() < 0.1:
		var random_jewelry: Array[String] = ["iron_ring", "copper_amulet"]
		var jewelry_id: String = random_jewelry[randi() % random_jewelry.size()]
		if InventoryManager.armor_database.has(jewelry_id):
			corpse.add_item(jewelry_id, 1, Enums.ItemQuality.AVERAGE)


## Handle essential NPC going unconscious
func _go_unconscious() -> void:
	print("[NPC] %s (essential) has been knocked unconscious" % npc_name)

	# Visual feedback - darken sprite
	if billboard and billboard.sprite:
		billboard.sprite.modulate = Color(0.4, 0.4, 0.4)

	# Stop movement
	if wander:
		wander.pause()
	is_fleeing = false

	# Recover after some time
	get_tree().create_timer(30.0).timeout.connect(_recover_from_unconscious)


## Recover from unconscious state
func _recover_from_unconscious() -> void:
	if _is_dead:
		return

	current_health = max_health / 2  # Recover to half health

	# Restore visual
	if billboard and billboard.sprite:
		billboard.sprite.modulate = tint_color

	# Resume behavior
	if wander:
		wander.resume()

	print("[NPC] %s has recovered" % npc_name)


## Heal this NPC
func heal(amount: int) -> int:
	if _is_dead:
		return 0

	var actual_heal: int = mini(amount, max_health - current_health)
	current_health += actual_heal
	return actual_heal


## Get armor value (civilians have no armor)
func get_armor_value() -> int:
	return 0


## Get damage type multiplier (no special resistances)
func get_damage_type_multiplier(_damage_type: Enums.DamageType) -> float:
	return 1.0


## Validate a spawn position is not inside an object
static func validate_spawn_position(parent: Node, pos: Vector3, check_radius: float = 0.5) -> Vector3:
	# Get a Node3D to access the world space state for collision checking
	var world_node := parent.get_tree().get_first_node_in_group("player")
	if not world_node:
		# Try to get world from parent
		if parent is Node3D:
			var world := (parent as Node3D).get_world_3d()
			if world:
				var direct_state := world.direct_space_state
				if direct_state:
					return _find_valid_position(direct_state, pos, check_radius)
		return pos

	# Use player's world to get space state
	if world_node is Node3D:
		var world := (world_node as Node3D).get_world_3d()
		if world:
			var direct_state := world.direct_space_state
			if direct_state:
				return _find_valid_position(direct_state, pos, check_radius)

	return pos


## Find a valid spawn position near the desired position
static func _find_valid_position(space_state: PhysicsDirectSpaceState3D, pos: Vector3, radius: float) -> Vector3:
	# Check if original position is clear
	if _is_position_clear(space_state, pos, radius):
		return pos

	# Try offsets around the original position
	var offsets: Array[Vector3] = [
		Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0),
		Vector3(0, 0, 1.5), Vector3(0, 0, -1.5),
		Vector3(1.0, 0, 1.0), Vector3(-1.0, 0, 1.0),
		Vector3(1.0, 0, -1.0), Vector3(-1.0, 0, -1.0),
		Vector3(2.0, 0, 0), Vector3(-2.0, 0, 0),
		Vector3(0, 0, 2.0), Vector3(0, 0, -2.0),
	]

	for offset: Vector3 in offsets:
		var test_pos: Vector3 = pos + offset
		if _is_position_clear(space_state, test_pos, radius):
			return test_pos

	# If no valid position found, return original (will be handled by stuck detection)
	return pos


## Check if a position is clear of obstacles
static func _is_position_clear(space_state: PhysicsDirectSpaceState3D, pos: Vector3, radius: float) -> bool:
	# Create a sphere shape query
	var shape := SphereShape3D.new()
	shape.radius = radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), pos + Vector3(0, 0.8, 0))  # Check at chest height
	query.collision_mask = 1  # World layer only

	var results := space_state.intersect_shape(query, 1)
	return results.is_empty()


## Helper to get ActorRegistry sprite config with fallback to defaults
## Returns [sprite_path, h_frames, v_frames, pixel_size] or null if not in registry
static func _get_registry_sprite_config(parent: Node, actor_id: String) -> Variant:
	var actor_registry: Node = Engine.get_singleton("ActorRegistry") if Engine.has_singleton("ActorRegistry") else null
	if not actor_registry:
		actor_registry = parent.get_node_or_null("/root/ActorRegistry")

	if actor_registry and actor_registry.has_actor(actor_id):
		var config: Dictionary = actor_registry.get_sprite_config(actor_id)
		if not config.is_empty():
			var sprite_path: String = config.get("sprite_path", "")
			if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
				return {
					"sprite_path": sprite_path,
					"h_frames": config.get("h_frames", 1),
					"v_frames": config.get("v_frames", 1),
					"pixel_size": config.get("pixel_size", PIXEL_SIZE_MAN),
					"offset_y": config.get("offset_y", 0.0)
				}
	return null


## Static factory method for spawning civilians
static func spawn_civilian(parent: Node, pos: Vector3, sprite_path: String,
		h_frames: int = 1, v_frames: int = 1, random_color: bool = true,
		pixel_size: float = PIXEL_SIZE_MAN) -> CivilianNPC:  # Default to man size
	var npc := CivilianNPC.new()

	# Validate spawn position to avoid spawning inside objects
	var validated_pos := validate_spawn_position(parent, pos)
	npc.position = validated_pos

	# Load sprite
	var tex := load(sprite_path) as Texture2D
	if tex:
		npc.sprite_texture = tex
		npc.sprite_h_frames = h_frames
		npc.sprite_v_frames = v_frames

	npc.sprite_pixel_size = pixel_size

	# Apply random color tint
	if random_color:
		npc.tint_color = DRESS_COLORS[randi() % DRESS_COLORS.size()]

	parent.add_child(npc)
	return npc


## Spawn an NPC using configuration from ActorRegistry
## This applies any Zoo patches automatically
## actor_id: The actor ID from ZooRegistry (e.g., "woman_civilian", "dwarf_guard")
## Falls back to spawn_random if actor not found in registry
static func spawn_from_registry(parent: Node, pos: Vector3, actor_id: String, zone_id: String = "") -> CivilianNPC:
	# Get ActorRegistry autoload (static functions cannot access autoloads directly)
	var actor_registry: Node = Engine.get_singleton("ActorRegistry") if Engine.has_singleton("ActorRegistry") else null
	if not actor_registry:
		actor_registry = parent.get_node_or_null("/root/ActorRegistry")

	# Check if ActorRegistry has this actor
	if not actor_registry or not actor_registry.has_actor(actor_id):
		push_warning("[CivilianNPC] Actor not found in registry: %s - using random" % actor_id)
		return spawn_random(parent, pos, zone_id)

	var config: Dictionary = actor_registry.get_sprite_config(actor_id)
	if config.is_empty():
		return spawn_random(parent, pos, zone_id)

	var sprite_path: String = config.get("sprite_path", "")
	if sprite_path.is_empty() or not ResourceLoader.exists(sprite_path):
		push_warning("[CivilianNPC] Sprite not found for actor: %s" % actor_id)
		return spawn_random(parent, pos, zone_id)

	var npc := spawn_civilian(
		parent,
		pos,
		sprite_path,
		config.get("h_frames", 1),
		config.get("v_frames", 1),
		false,  # No random color - let registry control it
		config.get("pixel_size", PIXEL_SIZE_MAN)
	)

	# Apply offset_y if specified
	npc.sprite_offset_y = config.get("offset_y", 0.0)

	# Get actor data for name generation hints
	var actor_data: Dictionary = actor_registry.get_actor_config(actor_id)
	var is_female: bool = _is_female_actor(actor_data)
	var title: String = _get_actor_title(actor_data)

	_assign_unique_name(npc, zone_id, is_female, title)

	return npc


## Helper to determine if an actor is female (for name generation)
static func _is_female_actor(actor_data: Dictionary) -> bool:
	var actor_id: String = actor_data.get("id", "")
	var actor_name: String = actor_data.get("name", "")

	# Check for female keywords
	var female_keywords: Array[String] = ["woman", "female", "lady", "barmaid", "seductress", "girl", "priestess"]
	for keyword: String in female_keywords:
		if keyword in actor_id.to_lower() or keyword in actor_name.to_lower():
			return true

	return false


## Helper to get a title from actor data (for name generation)
static func _get_actor_title(actor_data: Dictionary) -> String:
	var subcategory: String = actor_data.get("subcategory", "")

	# Map subcategories to titles
	match subcategory:
		"merchant":
			return "Merchant"
		"combat":
			return ""
		"temple":
			return "Monk"
		"dwarf":
			return ""
		_:
			return ""


## Spawn a woman NPC specifically (uses lady in red sprite with color variations)
## zone_id: Optional zone for unique name generation
static func spawn_woman(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	# Check ActorRegistry for Zoo patches first
	var registry_config: Variant = _get_registry_sprite_config(parent, "woman_civilian")
	var sprite_path: String = "res://assets/sprites/npcs/civilians/lady_in_red.png"
	var h_frames: int = 8
	var v_frames: int = 1
	var pixel_size: float = PIXEL_SIZE_LADY_RED

	if registry_config != null:
		sprite_path = registry_config["sprite_path"]
		h_frames = registry_config["h_frames"]
		v_frames = registry_config["v_frames"]
		pixel_size = registry_config["pixel_size"]

	var npc := spawn_civilian(
		parent,
		pos,
		sprite_path,
		h_frames,
		v_frames,
		false,  # Don't use default colors
		pixel_size
	)
	npc.tint_color = DRESS_COLORS[randi() % DRESS_COLORS.size()]
	_assign_unique_name(npc, zone_id, true)
	return npc


## Spawn a man NPC specifically
## zone_id: Optional zone for unique name generation
static func spawn_man(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	# Check ActorRegistry for Zoo patches first
	var registry_config: Variant = _get_registry_sprite_config(parent, "man_civilian")
	var sprite_path: String = "res://assets/sprites/npcs/civilians/man_civilian.png"
	var h_frames: int = 1
	var v_frames: int = 1
	var pixel_size: float = PIXEL_SIZE_MAN

	if registry_config != null:
		sprite_path = registry_config["sprite_path"]
		h_frames = registry_config["h_frames"]
		v_frames = registry_config["v_frames"]
		pixel_size = registry_config["pixel_size"]

	var npc := spawn_civilian(
		parent,
		pos,
		sprite_path,
		h_frames,
		v_frames,
		false,   # Don't use default colors
		pixel_size
	)
	npc.tint_color = MALE_COLORS[randi() % MALE_COLORS.size()]
	_assign_unique_name(npc, zone_id, false)
	return npc


## Spawn a barmaid NPC (randomly picks between variants)
## zone_id: Optional zone for unique name generation
static func spawn_barmaid(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	if randf() < 0.5:
		return spawn_barmaid_blonde(parent, pos, zone_id)
	else:
		return spawn_barmaid_brunette(parent, pos, zone_id)


## Spawn blonde barmaid (blue dress)
## zone_id: Optional zone for unique name generation
static func spawn_barmaid_blonde(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	# Check ActorRegistry for Zoo patches first
	var registry_config: Variant = _get_registry_sprite_config(parent, "barmaid_blonde")
	var sprite_path: String = "res://assets/sprites/npcs/civilians/barmaid_4x4.png"
	var h_frames: int = 1
	var v_frames: int = 1
	var pixel_size: float = PIXEL_SIZE_BARMAID_BLONDE

	if registry_config != null:
		sprite_path = registry_config["sprite_path"]
		h_frames = registry_config["h_frames"]
		v_frames = registry_config["v_frames"]
		pixel_size = registry_config["pixel_size"]

	var npc := spawn_civilian(
		parent,
		pos,
		sprite_path,
		h_frames,
		v_frames,
		false,   # Don't use default colors
		pixel_size
	)
	npc.tint_color = Color.WHITE  # Keep original colors (blue dress)
	_assign_unique_name(npc, zone_id, true, "Barmaid")
	return npc


## Spawn brunette barmaid (brown dress)
## zone_id: Optional zone for unique name generation
static func spawn_barmaid_brunette(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	# Check ActorRegistry for Zoo patches first
	var registry_config: Variant = _get_registry_sprite_config(parent, "barmaid_brunette")
	var sprite_path: String = "res://assets/sprites/npcs/civilians/barmaid_3x3.png"
	var h_frames: int = 1
	var v_frames: int = 1
	var pixel_size: float = PIXEL_SIZE_BARMAID_BRUNETTE

	if registry_config != null:
		sprite_path = registry_config["sprite_path"]
		h_frames = registry_config["h_frames"]
		v_frames = registry_config["v_frames"]
		pixel_size = registry_config["pixel_size"]

	var npc := spawn_civilian(
		parent,
		pos,
		sprite_path,
		h_frames,
		v_frames,
		false,   # Don't use default colors
		pixel_size
	)
	npc.tint_color = Color.WHITE  # Keep original colors (brown dress)
	_assign_unique_name(npc, zone_id, true, "Barmaid")
	return npc


## Spawn a wizard/mage NPC
## zone_id: Optional zone for unique name generation
static func spawn_wizard(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	# Check ActorRegistry for Zoo patches first
	var registry_config: Variant = _get_registry_sprite_config(parent, "wizard_mage")
	var sprite_path: String = "res://assets/sprites/npcs/civilians/wizard_mage.png"
	var h_frames: int = 1
	var v_frames: int = 1
	var pixel_size: float = PIXEL_SIZE_WIZARD

	if registry_config != null:
		sprite_path = registry_config["sprite_path"]
		h_frames = registry_config["h_frames"]
		v_frames = registry_config["v_frames"]
		pixel_size = registry_config["pixel_size"]

	var npc := spawn_civilian(
		parent,
		pos,
		sprite_path,
		h_frames,
		v_frames,
		false,
		pixel_size
	)
	npc.tint_color = WIZARD_COLORS[randi() % WIZARD_COLORS.size()]
	_assign_unique_name(npc, zone_id, false, "Mage")
	return npc


## Spawn a lady in red NPC
## zone_id: Optional zone for unique name generation
static func spawn_lady_in_red(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	# Check ActorRegistry for Zoo patches first (same actor as woman_civilian)
	var registry_config: Variant = _get_registry_sprite_config(parent, "woman_civilian")
	var sprite_path: String = "res://assets/sprites/npcs/civilians/lady_in_red.png"
	var h_frames: int = 8
	var v_frames: int = 1
	var pixel_size: float = PIXEL_SIZE_LADY_RED

	if registry_config != null:
		sprite_path = registry_config["sprite_path"]
		h_frames = registry_config["h_frames"]
		v_frames = registry_config["v_frames"]
		pixel_size = registry_config["pixel_size"]

	var npc := spawn_civilian(
		parent,
		pos,
		sprite_path,
		h_frames,
		v_frames,
		false,   # Don't use default colors
		pixel_size
	)
	npc.tint_color = Color.WHITE  # Keep original colors
	_assign_unique_name(npc, zone_id, true)
	return npc


## Spawn a random civilian (man, woman, barmaid, wizard, or lady in red)
## zone_id: Optional zone for unique name generation
static func spawn_random(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var roll := randf()
	if roll < 0.30:
		return spawn_woman(parent, pos, zone_id)
	elif roll < 0.60:
		return spawn_man(parent, pos, zone_id)
	elif roll < 0.75:
		return spawn_barmaid(parent, pos, zone_id)  # 15% chance for barmaid
	elif roll < 0.90:
		return spawn_lady_in_red(parent, pos, zone_id)  # 15% chance for lady in red
	else:
		return spawn_wizard(parent, pos, zone_id)   # 10% chance for wizard


## Helper to assign a unique name and npc_id to an NPC
## zone_id: Zone for unique name tracking (empty = use random name without tracking)
## is_female: Whether to use female names
## title: Optional title to append (e.g., "Barmaid" -> "Elara the Barmaid")
static func _assign_unique_name(npc: CivilianNPC, zone_id: String, is_female: bool, title: String = "") -> void:
	# Set gender property for audio/dialogue
	npc.is_female = is_female

	var first_name: String
	if zone_id.is_empty():
		# No zone tracking - use random name
		first_name = WorldLexicon.get_random_name(is_female)
	else:
		# Zone tracking - get unique name
		first_name = WorldLexicon.get_unique_name_for_zone(zone_id, is_female)
		if first_name.is_empty():
			# Fallback if all names exhausted
			first_name = WorldLexicon.get_random_name(is_female)

	# Set npc_id to first name only (for quest tracking)
	# Extract just the first name if surname was included
	var base_name: String = first_name.split(" ")[0]
	npc.npc_id = base_name.to_lower() + "_" + zone_id if not zone_id.is_empty() else base_name.to_lower()

	# Set display name with optional title
	if title.is_empty():
		npc.npc_name = first_name
	else:
		npc.npc_name = first_name + " the " + title


## ============================================================================
## DWARF NPC SPAWNING METHODS
## ============================================================================

## Spawn a dwarf guard/warrior NPC (uses blue armored sprite - dwarf_2.png)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_guard(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://assets/sprites/npcs/dwarves/dwarf_2.png",
		1,  # Single frame (48x96)
		1,  # Single frame
		false,
		PIXEL_SIZE_DWARF
	)
	npc.tint_color = Color.WHITE  # Keep original blue/purple armor colors
	_assign_dwarf_name(npc, zone_id, false, "Guard")
	return npc


## Spawn a dwarf warrior/soldier NPC (uses red armored sprite - dwarf_3.png)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_warrior(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://assets/sprites/npcs/dwarves/dwarf_3.png",
		1,  # Single frame (48x96)
		1,  # Single frame
		false,
		PIXEL_SIZE_DWARF
	)
	npc.tint_color = Color.WHITE  # Keep original red/maroon armor colors
	_assign_dwarf_name(npc, zone_id, false, "Warrior")
	return npc


## Spawn a random dwarf civilian (either guard or warrior type)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_civilian(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var sprite_path: String
	var title: String
	if randf() < 0.5:
		sprite_path = "res://assets/sprites/npcs/dwarves/dwarf_2.png"
		title = ""  # Just a regular dwarf
	else:
		sprite_path = "res://assets/sprites/npcs/dwarves/dwarf_3.png"
		title = ""

	var npc := spawn_civilian(
		parent,
		pos,
		sprite_path,
		1,  # Single frame (48x96)
		1,  # Single frame
		false,
		PIXEL_SIZE_DWARF
	)
	npc.tint_color = Color.WHITE
	_assign_dwarf_name(npc, zone_id, randf() < 0.3)  # 30% chance female
	return npc


## Spawn a dwarf refugee (wounded, displaced - slightly muted colors)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_refugee(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var sprite_path: String = "res://assets/sprites/npcs/dwarves/dwarf_3.png" if randf() < 0.5 else "res://assets/sprites/npcs/dwarves/dwarf_2.png"

	var npc := spawn_civilian(
		parent,
		pos,
		sprite_path,
		4,  # 4 columns
		1,  # 1 row
		false,
		PIXEL_SIZE_DWARF
	)
	# Muted, dusty colors for refugees
	npc.tint_color = Color(0.85, 0.8, 0.75)
	_assign_dwarf_name(npc, zone_id, randf() < 0.4, "Refugee")  # 40% chance female
	return npc


## Spawn a wounded dwarf soldier (darkened/muted colors to show injury)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_wounded(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := CivilianNPC.new()
	npc.position = pos
	npc.enable_wandering = false  # Wounded soldiers can't move
	npc.sprite_texture = load("res://assets/sprites/npcs/dwarves/dwarf_3.png")
	npc.sprite_h_frames = 1  # Single frame (48x96)
	npc.sprite_v_frames = 1  # Single frame
	npc.sprite_pixel_size = PIXEL_SIZE_DWARF
	# Pale, injured look
	npc.tint_color = Color(0.75, 0.7, 0.7)
	parent.add_child(npc)
	_assign_dwarf_name(npc, zone_id, false, "Wounded Soldier")
	return npc


## Spawn a random dwarf for the hold (variety of types)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_random(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var roll := randf()
	if roll < 0.35:
		return spawn_dwarf_guard(parent, pos, zone_id)  # 35% guards
	elif roll < 0.70:
		return spawn_dwarf_warrior(parent, pos, zone_id)  # 35% warriors
	else:
		return spawn_dwarf_civilian(parent, pos, zone_id)  # 30% civilians


## Helper to assign a dwarf name to an NPC
static func _assign_dwarf_name(npc: CivilianNPC, zone_id: String, is_female: bool, title: String = "") -> void:
	# Set gender property for audio/dialogue
	npc.is_female = is_female

	var first_name: String
	if is_female:
		first_name = DWARF_FEMALE_NAMES[randi() % DWARF_FEMALE_NAMES.size()]
	else:
		first_name = DWARF_MALE_NAMES[randi() % DWARF_MALE_NAMES.size()]

	# Set npc_id
	npc.npc_id = first_name.to_lower() + "_" + zone_id if not zone_id.is_empty() else first_name.to_lower()

	# Set display name with optional title
	if title.is_empty():
		npc.npc_name = first_name
	else:
		npc.npc_name = first_name + " the " + title


## ============================================================================
## MOLTEN/FORGE DWARF NPC SPAWNING METHODS
## For use in forge levels, foundries, and hot metalwork areas
## ============================================================================

## Spawn a molten forge master (uses dwarf_molten1.png - brightest/most ornate)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_forge_master(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://assets/sprites/npcs/dwarves/dwarf_molten1.png",
		1,  # Single frame (48x96)
		1,  # Single frame
		false,
		PIXEL_SIZE_DWARF
	)
	npc.tint_color = Color.WHITE  # Keep original molten orange/gold colors
	_assign_dwarf_name(npc, zone_id, false, "Forge Master")
	return npc


## Spawn a molten forge worker (uses dwarf_molten2.png)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_forge_worker(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://assets/sprites/npcs/dwarves/dwarf_molten2.png",
		1,  # Single frame (48x96)
		1,  # Single frame
		false,
		PIXEL_SIZE_DWARF
	)
	npc.tint_color = Color.WHITE  # Keep original molten colors
	_assign_dwarf_name(npc, zone_id, false, "Smith")
	return npc


## Spawn a molten forge guard (uses dwarf_molten3.png)
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_forge_guard(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://assets/sprites/npcs/dwarves/dwarf_molten3.png",
		1,  # Single frame (48x96)
		1,  # Single frame
		false,
		PIXEL_SIZE_DWARF
	)
	npc.tint_color = Color.WHITE  # Keep original molten colors
	_assign_dwarf_name(npc, zone_id, false, "Forge Guard")
	return npc


## Spawn a random forge dwarf
## zone_id: Optional zone for unique name generation
static func spawn_dwarf_forge_random(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var roll := randf()
	if roll < 0.15:
		return spawn_dwarf_forge_master(parent, pos, zone_id)  # 15% forge masters
	elif roll < 0.60:
		return spawn_dwarf_forge_worker(parent, pos, zone_id)  # 45% workers
	else:
		return spawn_dwarf_forge_guard(parent, pos, zone_id)   # 40% guards


## ============================================================================
## NEW CIVILIAN NPC SPAWNING METHODS (Reference Sheet Style)
## These sprites have 2-4 viewing angles, used as static or minimal animation
## ============================================================================

## Spawn a guy in green vest (single frame)
## zone_id: Optional zone for unique name generation
static func spawn_guy_green_vest(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://assets/sprites/npcs/civilians/guy_civilian1.png",
		1,  # Single frame (48x96)
		1,  # Single frame
		false,
		PIXEL_SIZE_GUY_CIVILIAN
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, false)
	return npc


## Spawn a pink lady civilian (single frame)
## zone_id: Optional zone for unique name generation
static func spawn_pink_lady(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://assets/sprites/npcs/civilians/pinklady.png",
		1,  # Single frame (48x96)
		1,  # Single frame
		false,
		PIXEL_SIZE_PINK_LADY
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, true)
	return npc


## Spawn a magic shop worker (single frame)
## zone_id: Optional zone for unique name generation
static func spawn_magic_shop_worker(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://assets/sprites/npcs/merchants/magic_shop_worker.png",
		1,  # Single frame (48x96)
		1,  # Single frame
		false,
		PIXEL_SIZE_MAGIC_SHOP
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, true, "Enchantress")
	return npc


## Spawn a seductress civilian - dark hair variant (front/back directional)
## zone_id: Optional zone for unique name generation
static func spawn_seductress(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://assets/sprites/npcs/civilians/seductress_civilian_Front.png",
		1,  # 1 column (single frame)
		1,  # 1 row
		false,
		PIXEL_SIZE_SEDUCTRESS
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, true)

	# Setup front/back directional sprites
	if npc.billboard:
		var front_tex: Texture2D = load("res://assets/sprites/npcs/civilians/seductress_civilian_Front.png")
		var back_tex: Texture2D = load("res://assets/sprites/npcs/civilians/seductress_civilian_back.png")
		if front_tex and back_tex:
			npc.billboard.setup_front_back_textures(front_tex, 1, 1, back_tex, 1, 1)

	return npc


## Spawn a seductress civilian - blue dress variant (single frame)
## zone_id: Optional zone for unique name generation
static func spawn_blue_dress_lady(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent,
		pos,
		"res://assets/sprites/npcs/civilians/seductress2_civilian.png",
		1,  # Single frame (48x96)
		1,  # Single frame
		false,
		PIXEL_SIZE_SEDUCTRESS2
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, true)
	return npc


## Spawn a random new-style civilian (uses the newer reference sheet sprites)
## zone_id: Optional zone for unique name generation
static func spawn_random_new(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var roll := randf()
	if roll < 0.20:
		return spawn_guy_green_vest(parent, pos, zone_id)    # 20% green vest guy
	elif roll < 0.40:
		return spawn_pink_lady(parent, pos, zone_id)         # 20% pink lady
	elif roll < 0.55:
		return spawn_magic_shop_worker(parent, pos, zone_id) # 15% magic shop worker
	elif roll < 0.75:
		return spawn_seductress(parent, pos, zone_id)        # 20% seductress dark
	else:
		return spawn_blue_dress_lady(parent, pos, zone_id)   # 25% blue dress


## Spawn any random civilian (combines old and new sprite types)
## zone_id: Optional zone for unique name generation
static func spawn_any_random(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	if randf() < 0.5:
		return spawn_random(parent, pos, zone_id)      # 50% old animated sprites
	else:
		return spawn_random_new(parent, pos, zone_id)  # 50% new reference sprites


# =============================================================================
# NEWER SINGLE-FRAME REFERENCE SPRITES
# =============================================================================

## Spawn a female noble NPC
static func spawn_female_noble(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent, pos,
		"res://assets/sprites/npcs/civilians/female_noble1.png",
		1, 1, false, PIXEL_SIZE_NOBLE
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, true, "Noble")
	return npc


## Spawn a male noble NPC
static func spawn_male_noble(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent, pos,
		"res://assets/sprites/npcs/civilians/man_noble1.png",
		1, 1, false, PIXEL_SIZE_NOBLE
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, false, "Noble")
	return npc


## Spawn a female gladiator NPC
static func spawn_female_gladiator(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent, pos,
		"res://assets/sprites/npcs/combat/female_gladiator1.png",
		1, 1, false, PIXEL_SIZE_GLADIATOR
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, true, "Gladiator")
	return npc


## Spawn a male gladiator NPC
static func spawn_male_gladiator(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent, pos,
		"res://assets/sprites/npcs/combat/male_gladiator1.png",
		1, 1, false, PIXEL_SIZE_GLADIATOR
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, false, "Gladiator")
	return npc


## Spawn a female hunter NPC (single frame image)
static func spawn_female_hunter(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent, pos,
		"res://assets/sprites/npcs/civilians/female_hunter.png",
		1, 1, false, PIXEL_SIZE_HUNTER
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, true, "Hunter")
	return npc


## Spawn a guard (dwarf style - stocky armored) NPC - male
static func spawn_guard_civilian(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent, pos,
		"res://assets/sprites/npcs/civilians/guard_civilian.png",
		1, 1, false, PIXEL_SIZE_GUARD_CIV
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, false, "Guard")
	return npc


## Spawn a guard (roman style - spear and shield) NPC - male
static func spawn_guard_roman_civilian(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent, pos,
		"res://assets/sprites/npcs/civilians/guard2_civilian.png",
		1, 1, false, PIXEL_SIZE_GUARD_CIV
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, false, "Soldier")
	return npc


## Spawn a random guard civilian (either dwarf or roman style)
static func spawn_guard_civilian_random(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	if randf() < 0.5:
		return spawn_guard_civilian(parent, pos, zone_id)
	else:
		return spawn_guard_roman_civilian(parent, pos, zone_id)


## Spawn a wild wizard NPC - male
static func spawn_wizard_wild(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent, pos,
		"res://assets/sprites/npcs/civilians/wizard_wild.png",
		1, 1, false, PIXEL_SIZE_WIZARD_CIV
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, false, "Hermit")
	return npc


## Spawn a civilian wizard NPC - male
static func spawn_wizard_civilian(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent, pos,
		"res://assets/sprites/npcs/civilians/wizard_civilian.png",
		1, 1, false, PIXEL_SIZE_WIZARD_CIV
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, false, "Mage")
	return npc


## Spawn a bard NPC - female
static func spawn_bard(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent, pos,
		"res://assets/sprites/npcs/civilians/bard_civilian.png",
		1, 1, false, PIXEL_SIZE_BARD
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, true, "Bard")
	return npc


## Spawn a merchant NPC - male
static func spawn_merchant_civilian(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var npc := spawn_civilian(
		parent, pos,
		"res://assets/sprites/npcs/merchants/merchant_civilian.png",
		1, 1, false, PIXEL_SIZE_MERCHANT
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, false, "Merchant")
	return npc


## Spawn a bandit civilian (reformed bandits in towns) - male
static func spawn_bandit_civilian(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var sprite: String = "res://assets/sprites/npcs/combat/thief.png" if randf() < 0.5 else "res://assets/sprites/npcs/combat/bandit_3.png"
	var npc := spawn_civilian(
		parent, pos,
		sprite,
		1, 1, false, PIXEL_SIZE_BANDIT
	)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, false)
	return npc


## Spawn any of the newer reference sprites randomly
static func spawn_random_newest(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var roll: float = randf()
	if roll < 0.1:
		return spawn_female_noble(parent, pos, zone_id)
	elif roll < 0.2:
		return spawn_male_noble(parent, pos, zone_id)
	elif roll < 0.3:
		return spawn_female_gladiator(parent, pos, zone_id)
	elif roll < 0.4:
		return spawn_male_gladiator(parent, pos, zone_id)
	elif roll < 0.5:
		return spawn_female_hunter(parent, pos, zone_id)
	elif roll < 0.6:
		return spawn_guard_civilian(parent, pos, zone_id)
	elif roll < 0.7:
		return spawn_wizard_civilian(parent, pos, zone_id)
	elif roll < 0.8:
		return spawn_bard(parent, pos, zone_id)
	elif roll < 0.9:
		return spawn_merchant_civilian(parent, pos, zone_id)
	else:
		return spawn_bandit_civilian(parent, pos, zone_id)


## Spawn any civilian from ALL available sprite types
static func spawn_truly_random(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var roll: float = randf()
	if roll < 0.33:
		return spawn_random(parent, pos, zone_id)          # Old animated sprites
	elif roll < 0.66:
		return spawn_random_new(parent, pos, zone_id)      # Newer reference sprites
	else:
		return spawn_random_newest(parent, pos, zone_id)   # Newest reference sprites


## Spawn a random FEMALE civilian from all available female sprites
static func spawn_random_female(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var roll: float = randf()
	if roll < 0.12:
		return spawn_woman(parent, pos, zone_id)
	elif roll < 0.24:
		return spawn_barmaid(parent, pos, zone_id)
	elif roll < 0.36:
		return spawn_lady_in_red(parent, pos, zone_id)
	elif roll < 0.48:
		return spawn_pink_lady(parent, pos, zone_id)
	elif roll < 0.56:
		return spawn_magic_shop_worker(parent, pos, zone_id)
	elif roll < 0.68:
		return spawn_seductress(parent, pos, zone_id)
	elif roll < 0.80:
		return spawn_blue_dress_lady(parent, pos, zone_id)
	elif roll < 0.88:
		return spawn_female_noble(parent, pos, zone_id)
	elif roll < 0.94:
		return spawn_female_gladiator(parent, pos, zone_id)
	elif roll < 0.97:
		return spawn_female_hunter(parent, pos, zone_id)
	else:
		return spawn_bard(parent, pos, zone_id)


## Spawn a random MALE civilian from all available male sprites
static func spawn_random_male(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var roll: float = randf()
	if roll < 0.18:
		return spawn_man(parent, pos, zone_id)
	elif roll < 0.30:
		return spawn_wizard(parent, pos, zone_id)
	elif roll < 0.40:
		return spawn_guy_green_vest(parent, pos, zone_id)
	elif roll < 0.48:
		return spawn_male_noble(parent, pos, zone_id)
	elif roll < 0.56:
		return spawn_male_gladiator(parent, pos, zone_id)
	elif roll < 0.64:
		return spawn_guard_civilian(parent, pos, zone_id)
	elif roll < 0.72:
		return spawn_wizard_wild(parent, pos, zone_id)
	elif roll < 0.78:
		return spawn_wizard_civilian(parent, pos, zone_id)
	elif roll < 0.84:
		return spawn_merchant_civilian(parent, pos, zone_id)
	elif roll < 0.92:
		return spawn_monk_random(parent, pos, zone_id)
	else:
		return spawn_bandit_civilian(parent, pos, zone_id)


## Spawn a random civilian with proper gender (50/50 male/female)
static func spawn_gendered_random(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	if randf() < 0.5:
		return spawn_random_female(parent, pos, zone_id)
	else:
		return spawn_random_male(parent, pos, zone_id)


## Spawn a random WORKING CLASS female (no nobles, gladiators, seductresses)
## For logging camps, villages, and rural areas
static func spawn_worker_female(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var roll: float = randf()
	if roll < 0.25:
		return spawn_woman(parent, pos, zone_id)
	elif roll < 0.50:
		return spawn_barmaid(parent, pos, zone_id)
	elif roll < 0.70:
		return spawn_pink_lady(parent, pos, zone_id)
	elif roll < 0.85:
		return spawn_female_hunter(parent, pos, zone_id)
	else:
		return spawn_lady_in_red(parent, pos, zone_id)


## Spawn a random WORKING CLASS male (no nobles, gladiators, wizards)
## For logging camps, villages, and rural areas
static func spawn_worker_male(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var roll: float = randf()
	if roll < 0.35:
		return spawn_man(parent, pos, zone_id)
	elif roll < 0.55:
		return spawn_guy_green_vest(parent, pos, zone_id)
	elif roll < 0.70:
		return spawn_guard_civilian(parent, pos, zone_id)
	elif roll < 0.85:
		return spawn_merchant_civilian(parent, pos, zone_id)
	else:
		return spawn_bandit_civilian(parent, pos, zone_id)


## Spawn a random WORKING CLASS civilian (50/50 male/female)
## Excludes nobles, gladiators, wizards, seductresses - for rural/working areas
static func spawn_worker_random(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	if randf() < 0.5:
		return spawn_worker_female(parent, pos, zone_id)
	else:
		return spawn_worker_male(parent, pos, zone_id)


# =============================================================================
# MONK/PRIEST NPC SPAWNING METHODS
# =============================================================================

## Pixel size for monk sprites - 96px frame, 2.46m target
const PIXEL_SIZE_MONK := 0.0256

## Spawn a temple monk (tan robes variant)
static func spawn_monk_tan(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	# Check ActorRegistry for Zoo patches first
	var registry_config: Variant = _get_registry_sprite_config(parent, "monk_tan")
	var sprite_path: String = "res://assets/sprites/npcs/temple/monk_1.png"
	var h_frames: int = 1
	var v_frames: int = 1
	var pixel_size: float = PIXEL_SIZE_MONK

	if registry_config != null:
		sprite_path = registry_config["sprite_path"]
		h_frames = registry_config["h_frames"]
		v_frames = registry_config["v_frames"]
		pixel_size = registry_config["pixel_size"]

	var npc := spawn_civilian(parent, pos, sprite_path, h_frames, v_frames, false, pixel_size)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, false, "Monk")
	return npc


## Spawn a temple monk (brown robes variant)
static func spawn_monk_brown(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	# Check ActorRegistry for Zoo patches first
	var registry_config: Variant = _get_registry_sprite_config(parent, "monk_brown")
	var sprite_path: String = "res://assets/sprites/npcs/temple/monk_2.png"
	var h_frames: int = 1
	var v_frames: int = 1
	var pixel_size: float = PIXEL_SIZE_MONK

	if registry_config != null:
		sprite_path = registry_config["sprite_path"]
		h_frames = registry_config["h_frames"]
		v_frames = registry_config["v_frames"]
		pixel_size = registry_config["pixel_size"]

	var npc := spawn_civilian(parent, pos, sprite_path, h_frames, v_frames, false, pixel_size)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, false, "Monk")
	return npc


## Spawn a temple monk (purple robes variant - more mystical)
static func spawn_monk_purple(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	# Check ActorRegistry for Zoo patches first
	var registry_config: Variant = _get_registry_sprite_config(parent, "monk_purple")
	var sprite_path: String = "res://assets/sprites/npcs/temple/monk_3_purple.png"
	var h_frames: int = 1
	var v_frames: int = 1
	var pixel_size: float = PIXEL_SIZE_MONK

	if registry_config != null:
		sprite_path = registry_config["sprite_path"]
		h_frames = registry_config["h_frames"]
		v_frames = registry_config["v_frames"]
		pixel_size = registry_config["pixel_size"]

	var npc := spawn_civilian(parent, pos, sprite_path, h_frames, v_frames, false, pixel_size)
	npc.tint_color = Color.WHITE
	_assign_unique_name(npc, zone_id, false, "Priest")
	return npc


## Spawn a random monk (any of the three variants)
static func spawn_monk_random(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	var roll: float = randf()
	if roll < 0.4:
		return spawn_monk_tan(parent, pos, zone_id)
	elif roll < 0.8:
		return spawn_monk_brown(parent, pos, zone_id)
	else:
		return spawn_monk_purple(parent, pos, zone_id)


# =============================================================================
# INNKEEPER NPC SPAWNING METHODS
# =============================================================================

## Pixel size for innkeeper sprites - 96px frame, 2.46m target
const PIXEL_SIZE_INNKEEPER := 0.0256

## Spawn a male innkeeper (stationary - stays behind counter)
static func spawn_innkeeper_male(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	# Check ActorRegistry for Zoo patches first
	var registry_config: Variant = _get_registry_sprite_config(parent, "innkeeper_male")
	var sprite_path: String = "res://assets/sprites/npcs/merchants/Innkeeper_man.png"
	var h_frames: int = 1
	var v_frames: int = 1
	var pixel_size: float = PIXEL_SIZE_INNKEEPER

	if registry_config != null:
		sprite_path = registry_config["sprite_path"]
		h_frames = registry_config["h_frames"]
		v_frames = registry_config["v_frames"]
		pixel_size = registry_config["pixel_size"]

	var npc := CivilianNPC.new()
	npc.position = pos
	npc.enable_wandering = false  # Innkeepers stay put
	npc.sprite_texture = load(sprite_path)
	npc.sprite_h_frames = h_frames
	npc.sprite_v_frames = v_frames
	npc.sprite_pixel_size = pixel_size
	npc.tint_color = Color.WHITE
	parent.add_child(npc)
	_assign_unique_name(npc, zone_id, false, "Innkeeper")
	return npc


## Spawn a female innkeeper (stationary - stays behind counter)
static func spawn_innkeeper_female(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	# Check ActorRegistry for Zoo patches first
	var registry_config: Variant = _get_registry_sprite_config(parent, "innkeeper_female")
	var sprite_path: String = "res://assets/sprites/npcs/merchants/Innkeeper_woman.png"
	var h_frames: int = 1
	var v_frames: int = 1
	var pixel_size: float = PIXEL_SIZE_INNKEEPER

	if registry_config != null:
		sprite_path = registry_config["sprite_path"]
		h_frames = registry_config["h_frames"]
		v_frames = registry_config["v_frames"]
		pixel_size = registry_config["pixel_size"]

	var npc := CivilianNPC.new()
	npc.position = pos
	npc.enable_wandering = false  # Innkeepers stay put
	npc.sprite_texture = load(sprite_path)
	npc.sprite_h_frames = h_frames
	npc.sprite_v_frames = v_frames
	npc.sprite_pixel_size = pixel_size
	npc.tint_color = Color.WHITE
	parent.add_child(npc)
	_assign_unique_name(npc, zone_id, true, "Innkeeper")
	return npc


## Spawn a random innkeeper (male or female)
static func spawn_innkeeper_random(parent: Node, pos: Vector3, zone_id: String = "") -> CivilianNPC:
	if randf() < 0.5:
		return spawn_innkeeper_male(parent, pos, zone_id)
	else:
		return spawn_innkeeper_female(parent, pos, zone_id)
