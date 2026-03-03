## thief_npc.gd - NPC that stalks and pickpockets the player
## Sneaky thieves that lurk in back alleys and crowds
## They approach the player from behind and attempt to steal gold/items
class_name ThiefNPC
extends CharacterBody3D

## Thief states
enum ThiefState {
	WANDERING,      # Normal wandering, looking for opportunity
	STALKING,       # Following player, waiting for chance
	PICKPOCKETING,  # Attempting to steal
	FLEEING,        # Running away after steal/detection
	CAUGHT          # Player caught the thief
}

## Visual representation
var billboard: BillboardSprite
var collision_shape: CollisionShape3D
var interaction_area: Area3D

## NPC identification
var npc_id: String = ""
var npc_name: String = "Suspicious Figure"
var region: String = ""

## State tracking
var current_state: ThiefState = ThiefState.WANDERING
var state_timer: float = 0.0

## Movement
var move_speed: float = 2.5
var flee_speed: float = 5.0
var stalk_distance: float = 8.0  # Distance to follow player from
var pickpocket_range: float = 2.0

## Thief stats
var thievery_skill: int = 5  # Base skill level
var perception_check_dc: int = 12  # Base DC for player to notice

## Stolen goods tracking
var stolen_gold: int = 0
var stolen_items: Array[Dictionary] = []

## Cooldowns
var attempt_cooldown: float = 0.0
const ATTEMPT_COOLDOWN_TIME := 30.0  # Seconds between steal attempts
var wander_cooldown: float = 0.0

## Targets
var target_player: Node3D = null
var flee_direction: Vector3 = Vector3.ZERO

## Health (thieves are weak but fast)
var max_health: int = 25
var current_health: int = 25
var _is_dead: bool = false

## Sprite configuration
const PIXEL_SIZE := 0.0256  # 96px frame, 2.46m target
var sprite_texture: Texture2D

## Detection
var detection_radius: float = 20.0  # How far thief can spot player


func _ready() -> void:
	add_to_group("npcs")
	add_to_group("attackable")
	add_to_group("thieves")

	# NPCs collide with world geometry (same layers as player)
	collision_layer = 1
	collision_mask = 5  # Layers 1 and 3 (world geometry + static objects)

	current_health = max_health

	_create_visual()
	_create_collision()
	_create_interaction_area()

	# Find player
	await get_tree().process_frame
	target_player = get_tree().get_first_node_in_group("player")


func _create_visual() -> void:
	billboard = BillboardSprite.new()

	# Use bandit sprite for thieves (dark, hooded look)
	var tex: Texture2D = load("res://assets/sprites/npcs/combat/thief.png")
	if tex:
		billboard.sprite_sheet = tex
		billboard.h_frames = 1
		billboard.v_frames = 1

	billboard.pixel_size = PIXEL_SIZE
	billboard.idle_frames = 1
	billboard.walk_frames = 1
	billboard.idle_fps = 2.0
	billboard.walk_fps = 4.0
	billboard.name = "Billboard"
	add_child(billboard)

	# Dark tint to look sneaky
	call_deferred("_apply_tint")


func _apply_tint() -> void:
	if billboard and billboard.sprite:
		billboard.sprite.modulate = Color(0.7, 0.65, 0.6)  # Dark, shadowy


func _create_collision() -> void:
	collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.4
	collision_shape.shape = capsule
	collision_shape.position = Vector3(0, 0.7, 0)
	add_child(collision_shape)


func _create_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	area_shape.shape = capsule
	area_shape.position = Vector3(0, 0.8, 0)
	interaction_area.add_child(area_shape)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Update cooldowns
	if attempt_cooldown > 0:
		attempt_cooldown -= delta

	# State machine
	match current_state:
		ThiefState.WANDERING:
			_update_wandering(delta)
		ThiefState.STALKING:
			_update_stalking(delta)
		ThiefState.PICKPOCKETING:
			_update_pickpocketing(delta)
		ThiefState.FLEEING:
			_update_fleeing(delta)
		ThiefState.CAUGHT:
			_update_caught(delta)


## Wandering - look for opportunity
func _update_wandering(delta: float) -> void:
	state_timer += delta

	# Check for player in range
	if target_player and is_instance_valid(target_player):
		var distance: float = global_position.distance_to(target_player.global_position)

		if distance < detection_radius and attempt_cooldown <= 0:
			# Player spotted! Start stalking
			_change_state(ThiefState.STALKING)
			return

	# Wander randomly
	wander_cooldown -= delta
	if wander_cooldown <= 0:
		wander_cooldown = randf_range(2.0, 5.0)
		# Pick random direction
		var angle: float = randf() * TAU
		velocity = Vector3(cos(angle), 0, sin(angle)) * move_speed * 0.5

	move_and_slide()
	_update_facing()


## Stalking - follow player and wait for opportunity
func _update_stalking(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		_change_state(ThiefState.WANDERING)
		return

	var to_player: Vector3 = target_player.global_position - global_position
	var distance: float = to_player.length()
	to_player = to_player.normalized()
	to_player.y = 0

	# If too far, give up
	if distance > detection_radius * 1.5:
		_change_state(ThiefState.WANDERING)
		attempt_cooldown = ATTEMPT_COOLDOWN_TIME * 0.5
		return

	# Try to stay behind player
	var player_facing: Vector3 = Vector3.ZERO
	if target_player.has_method("get_facing_direction"):
		player_facing = target_player.get_facing_direction()
	else:
		# Estimate from velocity
		if target_player is CharacterBody3D:
			player_facing = (target_player as CharacterBody3D).velocity.normalized()

	# Position behind player
	var ideal_pos: Vector3 = target_player.global_position - player_facing * stalk_distance
	var to_ideal: Vector3 = ideal_pos - global_position
	to_ideal.y = 0

	if to_ideal.length() > 1.0:
		velocity = to_ideal.normalized() * move_speed
	else:
		velocity = Vector3.ZERO

	move_and_slide()
	_update_facing()

	# Check if in range and player not looking
	if distance < pickpocket_range * 1.5:
		# Check if player is looking at us
		var player_to_thief: Vector3 = (global_position - target_player.global_position).normalized()
		var dot: float = player_facing.dot(player_to_thief)

		# dot > 0 means player is facing away from us
		if dot < 0.3:  # Player not looking at us
			_change_state(ThiefState.PICKPOCKETING)


## Pickpocketing - attempt to steal
func _update_pickpocketing(delta: float) -> void:
	state_timer += delta

	if state_timer > 0.5:  # Short delay for the attempt
		_attempt_steal()
		state_timer = 0.0


## Attempt to steal from player
func _attempt_steal() -> void:
	if not target_player or not is_instance_valid(target_player):
		_change_state(ThiefState.FLEEING)
		return

	# Roll thievery vs player's intuition skill (awareness)
	var player_intuition: int = 10
	if GameManager and GameManager.player_data:
		player_intuition = GameManager.player_data.get_skill(Enums.Skill.INTUITION)

	# Thief roll: d10 + thievery_skill
	var thief_roll: int = randi_range(1, 10) + thievery_skill

	# Player detection roll: intuition
	var detect_roll: int = player_intuition

	# Modifiers
	# Player moving = easier to steal
	if target_player is CharacterBody3D:
		var player_vel: Vector3 = (target_player as CharacterBody3D).velocity
		if player_vel.length() > 2.0:
			thief_roll += 3  # Distracted

	# In combat = much easier
	if CombatManager.is_in_combat():
		thief_roll += 5

	print("[Thief] Steal attempt: thief_roll=%d vs detect=%d" % [thief_roll, detect_roll])

	if thief_roll > detect_roll:
		# Success! Steal something
		_steal_from_player()
		_change_state(ThiefState.FLEEING)
	else:
		# Caught!
		_player_noticed()
		_change_state(ThiefState.FLEEING)


## Steal gold/items from player
func _steal_from_player() -> void:
	var player_gold: int = InventoryManager.gold

	# Steal 10-30% of player's gold (min 1, max 100)
	var steal_amount: int = clampi(int(player_gold * randf_range(0.1, 0.3)), 1, 100)

	if steal_amount > 0 and player_gold >= steal_amount:
		InventoryManager.remove_gold(steal_amount)
		stolen_gold += steal_amount

		# Notification with thief description and direction
		var direction_hint: String = _get_flee_direction_hint()
		_show_notification("A %s snatched %d gold and fled %s!" % [_get_thief_description(), steal_amount, direction_hint])
		print("[Thief] Stole %d gold from player!" % steal_amount)
	else:
		# Player has no gold, try to steal an item
		_steal_item_from_player()


## Steal a random item from player's inventory
func _steal_item_from_player() -> void:
	if InventoryManager.inventory.is_empty():
		return

	# Pick a random item (prefer small/valuable items)
	var stealable_items: Array[Dictionary] = []
	for slot: Dictionary in InventoryManager.inventory:
		var qty: int = slot.get("quantity", 0) as int
		var slot_item_id: String = slot.get("item_id", "") as String
		if qty > 0 and not slot_item_id.is_empty():
			# Don't steal weapons (check if it's in the weapon database)
			if not InventoryManager.weapon_database.has(slot_item_id):
				stealable_items.append(slot)

	if stealable_items.is_empty():
		return

	var target_slot: Dictionary = stealable_items[randi() % stealable_items.size()]
	var item_id: String = target_slot.get("item_id", "") as String

	if InventoryManager.remove_item(item_id, 1):
		stolen_items.append({"item_id": item_id, "quantity": 1})
		var item_name: String = InventoryManager.get_item_name(item_id)
		var direction_hint: String = _get_flee_direction_hint()
		_show_notification("A %s stole your %s and fled %s!" % [_get_thief_description(), item_name, direction_hint])
		print("[Thief] Stole %s from player!" % item_name)


## Player noticed the theft attempt
func _player_noticed() -> void:
	_show_notification("You catch a thief trying to pick your pocket!")

	# Make thief interactable (can confront)
	add_to_group("interactable")


## Fleeing - run away
func _update_fleeing(delta: float) -> void:
	state_timer += delta

	if not target_player or not is_instance_valid(target_player):
		if state_timer > 10.0:
			_change_state(ThiefState.WANDERING)
		return

	# Run away from player
	var away_dir: Vector3 = (global_position - target_player.global_position).normalized()
	away_dir.y = 0

	velocity = away_dir * flee_speed
	move_and_slide()
	_update_facing()

	# Check distance
	var distance: float = global_position.distance_to(target_player.global_position)

	if distance > detection_radius * 2 or state_timer > 15.0:
		# Got away! Despawn
		queue_free()


## Caught state
func _update_caught(delta: float) -> void:
	state_timer += delta
	velocity = Vector3.ZERO

	# Wait for player interaction or attack
	if state_timer > 5.0:
		# Try to flee
		_change_state(ThiefState.FLEEING)


func _change_state(new_state: ThiefState) -> void:
	current_state = new_state
	state_timer = 0.0

	if new_state == ThiefState.FLEEING:
		attempt_cooldown = ATTEMPT_COOLDOWN_TIME


func _update_facing() -> void:
	if billboard and velocity.length() > 0.1:
		billboard.facing_direction = velocity.normalized()


## Called by player interaction system
func interact(_interactor: Node) -> void:
	# Confront the thief
	if stolen_gold > 0 or not stolen_items.is_empty():
		_show_notification("\"Alright, alright! Here's your stuff back!\"")
		_return_stolen_goods()
		_change_state(ThiefState.FLEEING)
	else:
		_show_notification("\"I ain't done nothing! Leave me alone!\"")


func get_interaction_prompt() -> String:
	if stolen_gold > 0 or not stolen_items.is_empty():
		return "Confront " + npc_name
	return "Talk to " + npc_name


## Return stolen goods to player
func _return_stolen_goods() -> void:
	if stolen_gold > 0:
		InventoryManager.add_gold(stolen_gold)
		_show_notification("Recovered " + str(stolen_gold) + " gold!")
		stolen_gold = 0

	for item: Dictionary in stolen_items:
		var item_id: String = item.get("item_id", "") as String
		var qty: int = item.get("quantity", 1) as int
		if not item_id.is_empty():
			InventoryManager.add_item(item_id, qty)
			var item_name: String = InventoryManager.get_item_name(item_id)
			_show_notification("Recovered " + item_name + "!")

	stolen_items.clear()


## Take damage
func take_damage(amount: int, damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null) -> int:
	if _is_dead:
		return 0

	var actual_damage: int = mini(amount, current_health)
	current_health -= actual_damage

	# Visual feedback
	if billboard and billboard.sprite:
		var original_color: Color = billboard.sprite.modulate
		billboard.sprite.modulate = Color(1.0, 0.3, 0.3)
		get_tree().create_timer(0.15).timeout.connect(func():
			if billboard and billboard.sprite:
				billboard.sprite.modulate = original_color
		)

	# Start fleeing if not already
	if current_state != ThiefState.FLEEING:
		_change_state(ThiefState.FLEEING)

	# Check for death
	if current_health <= 0:
		_die(attacker)

	return actual_damage


func is_dead() -> bool:
	return _is_dead


func _die(killer: Node = null) -> void:
	if _is_dead:
		return

	_is_dead = true

	print("[Thief] %s has been killed" % npc_name)

	# Spawn corpse with stolen goods
	_spawn_corpse()

	# Killing a thief who stole from you is NOT a crime (self-defense/justice)
	# But if they hadn't stolen anything, it's murder
	if stolen_gold <= 0 and stolen_items.is_empty():
		if killer and killer.is_in_group("player"):
			var crime_region: String = region if not region.is_empty() else "unknown"
			CrimeManager.report_crime(CrimeManager.CrimeType.MURDER, crime_region, [])

	CombatManager.entity_killed.emit(self, killer)

	if AudioManager:
		AudioManager.play_sfx("enemy_death")

	queue_free()


func _spawn_corpse() -> void:
	var corpse: LootableCorpse = LootableCorpse.spawn_corpse(
		get_parent(),
		global_position,
		npc_name,
		npc_id,
		3  # Level 3 (decent loot)
	)

	# Add stolen gold
	corpse.gold = stolen_gold + randi_range(5, 20)  # Plus their own gold

	# Add stolen items
	for item: Dictionary in stolen_items:
		var item_id: String = item.get("item_id", "") as String
		var qty: int = item.get("quantity", 1) as int
		if not item_id.is_empty():
			corpse.add_item(item_id, qty, Enums.ItemQuality.AVERAGE)

	# Add thief's own items
	if randf() < 0.5:
		corpse.add_item("lockpick", randi_range(1, 3), Enums.ItemQuality.AVERAGE)
	if randf() < 0.3:
		corpse.add_item("health_potion", 1, Enums.ItemQuality.AVERAGE)


func get_armor_value() -> int:
	return 2  # Leather armor


func _show_notification(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)


## Get a description of the thief for notifications
func _get_thief_description() -> String:
	var descriptions: Array[String] = [
		"hooded figure",
		"shadowy figure",
		"cloaked stranger",
		"sneaky cutpurse",
		"nimble pickpocket"
	]
	return descriptions[randi() % descriptions.size()]


## Get a direction hint based on flee direction relative to player
func _get_flee_direction_hint() -> String:
	if not target_player or not is_instance_valid(target_player):
		return "into the crowd"

	# Calculate direction from player to thief (where they're fleeing)
	var to_thief: Vector3 = global_position - target_player.global_position
	to_thief.y = 0
	to_thief = to_thief.normalized()

	# Get player's forward direction for relative direction
	var player_forward: Vector3 = Vector3.FORWARD
	if target_player.has_method("get_facing_direction"):
		player_forward = target_player.get_facing_direction()
	elif target_player is CharacterBody3D:
		# Use player's rotation to determine forward
		player_forward = -target_player.global_transform.basis.z

	# Calculate angle between player forward and thief direction
	var right: Vector3 = player_forward.cross(Vector3.UP)
	var forward_dot: float = player_forward.dot(to_thief)
	var right_dot: float = right.dot(to_thief)

	# Determine cardinal direction
	if forward_dot > 0.7:
		return "ahead"
	elif forward_dot < -0.7:
		return "behind you"
	elif right_dot > 0.7:
		return "to the right"
	elif right_dot < -0.7:
		return "to the left"
	elif forward_dot > 0 and right_dot > 0:
		return "ahead and to the right"
	elif forward_dot > 0 and right_dot < 0:
		return "ahead and to the left"
	elif forward_dot < 0 and right_dot > 0:
		return "behind you to the right"
	else:
		return "behind you to the left"


## Static factory method
static func spawn_thief(parent: Node, pos: Vector3, p_region: String = "", skill_level: int = 5) -> ThiefNPC:
	var thief := ThiefNPC.new()
	thief.position = pos
	thief.region = p_region
	thief.thievery_skill = skill_level

	# Generate name
	var thief_names: Array[String] = [
		"Sneaky Pete", "Nimble Fingers", "Shadow", "Rat",
		"Cutpurse", "Pickpocket", "Sly", "Whisper"
	]
	thief.npc_name = thief_names[randi() % thief_names.size()]
	thief.npc_id = "thief_" + str(randi())

	parent.add_child(thief)
	return thief
