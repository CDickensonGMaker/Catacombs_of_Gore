## guard_npc.gd - Town guard NPCs
## Guards that can optionally patrol and have guard-specific dialogue
## Uses static billboard sprites (dwarf guard or roman soldier variants)
## Handles bounty detection, arrests, and combat with criminals
class_name GuardNPC
extends CivilianNPC

## Guard AI states
enum GuardState {
	PATROL,     # Normal patrol/wander behavior
	ALERT,      # Noticed player has bounty, moving to investigate
	CHASE,      # Pursuing fleeing player
	COMBAT,     # Fighting player who resisted arrest
	ARRESTING   # Initiating arrest dialogue
}

## Optional patrol points for guard patrol behavior
@export var patrol_points: Array[Vector3] = []

## Region ID for bounty checking (set based on current zone)
@export var region_id: String = "elder_moor"

## NPC identification for unified quest turn-in system
## npc_id inherited from CivilianNPC
var npc_type: String = "guard"  # Type for NPC_TYPE_IN_REGION turn-ins

## Preload default guard dialogue (fallback)
var _default_guard_dialogue: DialogueData = preload("res://data/dialogues/guard_generic.tres")

## Use topic-based conversation instead of scripted dialogue
@export var use_conversation_system: bool = true

## Guard uses billboard sprite (not 3D mesh)
const GUARD_HEIGHT := 1.8
const GUARD_RADIUS := 0.35

## Guard sprite variants - single frame static images
const GUARD_SPRITE_DWARF := "res://assets/sprites/npcs/civilians/guard_civilian.png"
const GUARD_SPRITE_ROMAN := "res://assets/sprites/npcs/civilians/guard2_civilian.png"

## All available guard sprites for random selection
const GUARD_SPRITES: Array[String] = [
	GUARD_SPRITE_DWARF,
	GUARD_SPRITE_ROMAN
]

## Pixel size for guard sprites - 96px frame height, same as other NPCs
const PIXEL_SIZE_GUARD := 0.0256

## Export to allow specifying which sprite variant to use (0=dwarf, 1=roman, -1=random)
@export var guard_sprite_variant: int = -1  # -1 = random selection

## Combat state
var is_in_combat: bool = false
var is_attacking: bool = false

## Guard-specific combat stats (override parent)
## Guards are tougher than regular civilians
const GUARD_MAX_HEALTH := 80
const GUARD_ARMOR := 15
const GUARD_DAMAGE := 15
var attack_cooldown: float = 0.0
const ATTACK_COOLDOWN_TIME := 1.5

## Guard visual - now uses billboard sprite from parent class
## guard_mesh removed - using billboard sprite instead

## Guard AI state
var guard_state: GuardState = GuardState.PATROL
var _previous_state: GuardState = GuardState.PATROL

## Detection ranges
const DETECTION_RANGE := 15.0      # Distance to notice player has bounty
const ARREST_RANGE := 3.0          # Distance to initiate arrest dialogue
const CHASE_SPEED := 4.0           # Speed when chasing
const NORMAL_SPEED := 1.5          # Normal patrol speed
const ALERT_SPEED := 2.5           # Speed when approaching suspect
const BACKUP_CALL_RANGE := 30.0    # Range to call other guards for backup

## Target tracking
var _target_player: Node3D = null
var _chase_timer: float = 0.0
const CHASE_TIMEOUT := 30.0        # Give up chase after this many seconds
var _alert_cooldown: float = 0.0   # Cooldown before checking bounty again
const ALERT_COOLDOWN_TIME := 5.0

## Arrest dialogue active
var _arrest_dialogue_active: bool = false


func _ready() -> void:
	# Set guard-specific properties before parent _ready
	add_to_group("guards")

	# Set default dialogue if none assigned
	if not dialogue_data:
		dialogue_data = _default_guard_dialogue

	npc_name = "Town Guard"

	# Generate unique npc_id if not set
	if npc_id.is_empty():
		npc_id = "guard_%d" % get_instance_id()

	# Set guard-specific stats BEFORE parent _ready
	max_health = GUARD_MAX_HEALTH
	gold_carried = randi_range(20, 50)  # Guards have more gold

	# Setup guard sprite - select variant and load texture
	_setup_guard_sprite()

	# Call parent _ready which creates collision, billboard sprite, etc.
	super._ready()

	# Debug logging for quest system debugging
	print("[Guard] npc_id=%s, npc_type=%s, region_id=%s" % [npc_id, npc_type, region_id])


## Override parent registration to use guard-specific type
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

	# Use region_id if zone_id not found
	if zone_id.is_empty():
		zone_id = region_id if not region_id.is_empty() else "town_unknown"

	PlayerGPS.register_npc(self, effective_id, "guard", zone_id)


func _exit_tree() -> void:
	var effective_id: String = npc_id if not npc_id.is_empty() else name
	PlayerGPS.unregister_npc(effective_id)


## Setup guard billboard sprite before parent _ready is called
func _setup_guard_sprite() -> void:
	# Select sprite variant
	var sprite_path: String
	if guard_sprite_variant < 0 or guard_sprite_variant >= GUARD_SPRITES.size():
		# Random selection
		sprite_path = GUARD_SPRITES[randi() % GUARD_SPRITES.size()]
	else:
		sprite_path = GUARD_SPRITES[guard_sprite_variant]

	# Load the sprite texture
	var tex: Texture2D = load(sprite_path)
	if tex:
		sprite_texture = tex
		sprite_h_frames = 1  # Single frame static image
		sprite_v_frames = 1  # Single frame static image
		sprite_pixel_size = PIXEL_SIZE_GUARD
	else:
		push_error("[GuardNPC] Failed to load guard sprite: %s" % sprite_path)


func _process(delta: float) -> void:
	# Update guard AI state machine
	_update_guard_ai(delta)

	# Call parent for wander behavior updates (only in PATROL state)
	if guard_state == GuardState.PATROL:
		super._process(delta)

	# Update sprite tint based on combat state
	_update_guard_visual()


func _physics_process(delta: float) -> void:
	# Handle movement based on state
	match guard_state:
		GuardState.ALERT:
			_move_towards_player(delta, ALERT_SPEED)
		GuardState.CHASE:
			_move_towards_player(delta, CHASE_SPEED)
			_chase_timer += delta
			if _chase_timer >= CHASE_TIMEOUT:
				_give_up_chase()
		GuardState.COMBAT:
			_combat_behavior(delta)


## Update guard AI state machine
func _update_guard_ai(delta: float) -> void:
	# Update cooldowns
	if _alert_cooldown > 0:
		_alert_cooldown -= delta

	# Skip AI if in arrest dialogue or player is jailed
	if _arrest_dialogue_active or CrimeManager.is_jailed:
		return

	# Get player reference
	_target_player = get_tree().get_first_node_in_group("player") as Node3D
	if not _target_player:
		return

	var distance_to_player := global_position.distance_to(_target_player.global_position)

	match guard_state:
		GuardState.PATROL:
			_patrol_state_logic(distance_to_player)
		GuardState.ALERT:
			_alert_state_logic(distance_to_player)
		GuardState.CHASE:
			_chase_state_logic(distance_to_player)
		GuardState.ARRESTING:
			_arresting_state_logic(distance_to_player)
		GuardState.COMBAT:
			_combat_state_logic(distance_to_player)


## Patrol state - check for player bounty
func _patrol_state_logic(distance: float) -> void:
	# Check if player is in detection range and has bounty
	if distance <= DETECTION_RANGE and _alert_cooldown <= 0:
		var bounty: int = CrimeManager.get_bounty(region_id)
		if bounty > 0:
			_change_state(GuardState.ALERT)
			print("[Guard] Noticed player has bounty of %d in %s" % [bounty, region_id])
			# Disable wander behavior
			if wander:
				wander.pause()


## Alert state - approach player
func _alert_state_logic(distance: float) -> void:
	# Check if player left detection range
	if distance > DETECTION_RANGE * 1.5:
		_give_up_chase()
		return

	# Check if player is in arrest range
	if distance <= ARREST_RANGE:
		_change_state(GuardState.ARRESTING)
		_initiate_arrest()


## Chase state - pursue fleeing player
func _chase_state_logic(distance: float) -> void:
	# Check if caught up to player
	if distance <= ARREST_RANGE:
		_change_state(GuardState.ARRESTING)
		_initiate_arrest()
		return

	# Check if player escaped
	if distance > DETECTION_RANGE * 2.0:
		_give_up_chase()


## Arresting state - handle arrest dialogue
func _arresting_state_logic(distance: float) -> void:
	# If player moves away during arrest dialogue, chase them
	if distance > ARREST_RANGE * 2.0 and not _arrest_dialogue_active:
		_change_state(GuardState.CHASE)
		_call_for_backup()


## Combat state - fight the player
func _combat_state_logic(distance: float) -> void:
	# Combat AI handled separately
	pass


## Move towards player position
func _move_towards_player(delta: float, speed: float) -> void:
	if not _target_player:
		return

	var direction := (_target_player.global_position - global_position).normalized()
	direction.y = 0  # Stay on ground level

	velocity = direction * speed
	move_and_slide()

	# Update facing direction for sprite
	if wander:
		wander.set_facing_direction(direction)


## Combat behavior
func _combat_behavior(delta: float) -> void:
	# Update attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta

	# Basic combat - approach and attack
	if not _target_player:
		return

	# Check if player is dead - return to patrol
	if _target_player.has_method("is_dead") and _target_player.is_dead():
		_give_up_chase()
		return

	var distance := global_position.distance_to(_target_player.global_position)

	if distance > 2.0:
		# Move towards player
		var direction := (_target_player.global_position - global_position).normalized()
		direction.y = 0
		velocity = direction * CHASE_SPEED
		move_and_slide()
	else:
		# Stop moving when in range
		velocity = Vector3.ZERO

		# Attack if cooldown is ready
		if attack_cooldown <= 0 and not is_attacking:
			play_attack()
			_attack_player()
			attack_cooldown = ATTACK_COOLDOWN_TIME


## Attack the player
func _attack_player() -> void:
	if not _target_player:
		return

	# Get player damage from guard stats (use CombatManager)
	var damage := 15  # Base guard damage
	if _target_player.has_method("take_damage"):
		_target_player.take_damage(damage, Enums.DamageType.PHYSICAL, self)
		print("[Guard] Attacked player for %d damage" % damage)


## Give up chase and return to patrol
func _give_up_chase() -> void:
	print("[Guard] Lost sight of suspect, returning to patrol")
	_change_state(GuardState.PATROL)
	_chase_timer = 0.0
	_alert_cooldown = ALERT_COOLDOWN_TIME

	# Re-enable wander behavior
	if wander:
		wander.resume()


## Change guard state
func _change_state(new_state: GuardState) -> void:
	_previous_state = guard_state
	guard_state = new_state

	# State change effects
	match new_state:
		GuardState.COMBAT:
			is_in_combat = true
			_call_for_backup()
		GuardState.PATROL:
			is_in_combat = false
		GuardState.CHASE:
			_chase_timer = 0.0


## Initiate arrest dialogue with player
func _initiate_arrest() -> void:
	_arrest_dialogue_active = true

	var bounty: int = CrimeManager.get_bounty(region_id)
	var crime_name: String = CrimeManager.get_last_crime_name(region_id)

	# Show arrest dialogue
	_show_arrest_dialogue(bounty, crime_name)


## Show arrest dialogue options using scripted dialogue mode
func _show_arrest_dialogue(bounty: int, crime_name: String) -> void:
	# Build scripted dialogue lines
	var lines: Array = []

	# Line 0: Guard's arrest statement with choices
	lines.append(ConversationSystem.create_scripted_line(
		"Town Guard",
		"Halt, criminal! You are wanted for %s. Your bounty is %d gold. What say you?" % [crime_name, bounty],
		[
			ConversationSystem.create_scripted_choice("I'll pay the fine. (%d gold)" % bounty, 1),
			ConversationSystem.create_scripted_choice("I'll serve my time.", 2),
			ConversationSystem.create_scripted_choice("You'll never take me alive!", 3)
		]
	))

	# Line 1: Pay fine response
	lines.append(ConversationSystem.create_scripted_line(
		"Town Guard",
		"Very well. Consider this a warning.",
		[],
		true  # is_end
	))

	# Line 2: Go to jail response
	lines.append(ConversationSystem.create_scripted_line(
		"Town Guard",
		"You'll serve your time. Follow me to the jail.",
		[],
		true  # is_end
	))

	# Line 3: Resist arrest response
	lines.append(ConversationSystem.create_scripted_line(
		"Town Guard",
		"Then you choose death!",
		[],
		true  # is_end
	))

	# Store the bounty for later processing
	_current_arrest_bounty = bounty

	# Connect to scripted line signal to track which line we end on
	if not ConversationSystem.scripted_line_shown.is_connected(_on_arrest_line_shown):
		ConversationSystem.scripted_line_shown.connect(_on_arrest_line_shown)

	# Start scripted dialogue with callback
	ConversationSystem.start_scripted_dialogue(lines, _on_arrest_scripted_ended)


## Store arrest bounty for processing
var _current_arrest_bounty: int = 0


## Track which arrest line was shown (to determine player choice)
var _last_arrest_line_index: int = 0

func _on_arrest_line_shown(_line: Dictionary, index: int) -> void:
	_last_arrest_line_index = index


## Handle arrest scripted dialogue completion
func _on_arrest_scripted_ended() -> void:
	# Disconnect signal
	if ConversationSystem.scripted_line_shown.is_connected(_on_arrest_line_shown):
		ConversationSystem.scripted_line_shown.disconnect(_on_arrest_line_shown)

	_arrest_dialogue_active = false

	# Process the choice based on which line we ended on
	match _last_arrest_line_index:
		1:  # Pay fine
			_handle_pay_fine()
		2:  # Go to jail
			_handle_go_to_jail()
		3:  # Resist arrest
			_handle_resist_arrest()
		_:
			# Dialogue cancelled or unknown - treat as resist
			_handle_resist_arrest()

	_last_arrest_line_index = 0


## Handle player paying fine
func _handle_pay_fine() -> void:
	var bounty: int = CrimeManager.get_bounty(region_id)

	if InventoryManager.gold >= bounty:
		CrimeManager.pay_bounty(region_id)
		_show_notification("You paid %d gold. Your bounty is cleared." % bounty)
		_change_state(GuardState.PATROL)
		_alert_cooldown = ALERT_COOLDOWN_TIME
		if wander:
			wander.resume()
	else:
		# Not enough gold
		_show_notification("You don't have enough gold! To jail with you!")
		_handle_go_to_jail()


## Handle player going to jail
func _handle_go_to_jail() -> void:
	var jail_time: float = CrimeManager.calculate_jail_time(region_id)

	_show_notification("You will serve %.1f hours in jail." % jail_time)

	# Start jail process
	CrimeManager.serve_time(region_id)
	CrimeManager.player_arrested.emit(region_id)

	# Find prison and teleport player
	_teleport_player_to_jail()

	# Return to patrol
	_change_state(GuardState.PATROL)
	_alert_cooldown = ALERT_COOLDOWN_TIME
	if wander:
		wander.resume()


## Handle player resisting arrest
func _handle_resist_arrest() -> void:
	_show_notification("Guards! The criminal is resisting arrest!")

	# Enter combat
	_change_state(GuardState.COMBAT)
	_call_for_backup()

	# Add additional bounty for resisting
	CrimeManager.report_crime(CrimeManager.CrimeType.ASSAULT, region_id, [self])


## Call nearby guards for backup
func _call_for_backup() -> void:
	var guards := get_tree().get_nodes_in_group("guards")

	for guard in guards:
		if guard == self:
			continue

		if guard is GuardNPC:
			var distance: float = global_position.distance_to(guard.global_position)
			if distance <= BACKUP_CALL_RANGE:
				guard.respond_to_backup_call(global_position, _target_player)


## Respond to backup call from another guard
func respond_to_backup_call(crime_location: Vector3, suspect: Node3D) -> void:
	if guard_state == GuardState.PATROL or guard_state == GuardState.ALERT:
		_target_player = suspect
		_change_state(GuardState.CHASE)
		print("[Guard] Responding to backup call!")

		# Disable wander
		if wander:
			wander.pause()


## Called when a crime is reported in this region
func on_crime_reported(crime_region_id: String) -> void:
	if crime_region_id != region_id:
		return

	# If patrolling, become alert
	if guard_state == GuardState.PATROL:
		_alert_cooldown = 0  # Reset cooldown to check immediately
		print("[Guard] Heard about crime in %s, becoming alert" % region_id)


## Teleport player to jail
func _teleport_player_to_jail() -> void:
	# Find prison in scene
	var prisons := get_tree().get_nodes_in_group("prisons")
	if prisons.is_empty():
		push_warning("[Guard] No prison found in scene!")
		return

	var prison: Node3D = prisons[0]
	if prison.has_method("jail_player"):
		prison.jail_player(_target_player)
	elif "cell_spawn_point" in prison:
		_target_player.global_position = prison.cell_spawn_point


## Show notification via HUD
func _show_notification(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)


## Update guard visual based on state (using billboard sprite modulate)
func _update_guard_visual() -> void:
	if not billboard or not billboard.sprite:
		return

	# Change sprite tint based on state
	match guard_state:
		GuardState.PATROL:
			billboard.sprite.modulate = Color.WHITE  # Normal
		GuardState.ALERT:
			billboard.sprite.modulate = Color(1.1, 1.0, 0.8)  # Slight yellow tint
		GuardState.CHASE, GuardState.COMBAT:
			billboard.sprite.modulate = Color(1.2, 0.85, 0.85)  # Reddish tint
		GuardState.ARRESTING:
			billboard.sprite.modulate = Color(0.9, 0.9, 1.1)  # Slight blue tint


## Trigger attack (visual feedback via sprite flash)
func play_attack() -> void:
	is_attacking = true
	# Brief color flash for attack
	if billboard and billboard.sprite:
		billboard.sprite.modulate = Color(1.5, 0.6, 0.6)  # Flash red
		# Reset after short delay
		get_tree().create_timer(0.2).timeout.connect(func():
			is_attacking = false
			_update_guard_visual()  # Restore state-appropriate color
		)


## Set combat state
func set_combat_state(in_combat: bool) -> void:
	is_in_combat = in_combat
	if in_combat:
		_change_state(GuardState.COMBAT)
	else:
		_change_state(GuardState.PATROL)
		is_attacking = false


## Override interact to use conversation system for guards (limited topics)
## If player has bounty, initiate arrest instead
## Also checks for completable quests that can be turned in to any guard
func interact(_interactor: Node) -> void:
	# Check if player has bounty - initiate arrest
	var bounty: int = CrimeManager.get_bounty(region_id)
	if bounty > 0:
		_change_state(GuardState.ARRESTING)
		_initiate_arrest()
		return

	# Check for completable quests that can be turned in to guards
	var completable := _get_completable_guard_quests()
	if not completable.is_empty():
		_show_quest_completion_dialogue(completable)
		return

	# Normal conversation - guards always use ConversationSystem with restricted topics
	var profile := _get_guard_profile()
	if profile:
		ConversationSystem.start_conversation(self, profile)


## Get quests that can be turned in to this guard using the central turn-in system
func _get_completable_guard_quests() -> Array[String]:
	# Use the new central turn-in system
	var result := QuestManager.get_turnin_quests_for_entity(self)
	print("[Guard] Checking turn-in quests for npc_type='%s', region='%s' -> found %d quests" % [npc_type, region_id, result.size()])
	return result


## Show dialogue for quest completion using scripted dialogue
func _show_quest_completion_dialogue(completable_quests: Array[String]) -> void:
	if completable_quests.is_empty():
		return

	# For simplicity, handle the first completable quest
	var quest_id: String = completable_quests[0]
	var quest: QuestManager.Quest = QuestManager.get_quest(quest_id)
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

	var reward_text: String = "You received: " + ", ".join(rewards) if not rewards.is_empty() else "The city thanks you for your service."

	# Build scripted dialogue lines
	var lines: Array = []

	# Line 0: Quest complete acknowledgment
	lines.append(ConversationSystem.create_scripted_line(
		npc_name,
		"Ah, you've completed '%s'. Well done. Here's your reward." % quest.title,
		[ConversationSystem.create_scripted_choice("Accept reward", 1)]
	))

	# Line 1: Reward given
	lines.append(ConversationSystem.create_scripted_line(
		npc_name,
		reward_text,
		[],
		true  # is_end
	))

	# Store quest ID to complete when dialogue ends
	_pending_quest_completion = quest_id

	# Start scripted dialogue with callback
	ConversationSystem.start_scripted_dialogue(lines, _on_quest_turnin_scripted_ended)


## Pending quest to complete after dialogue
var _pending_quest_completion: String = ""


## Handle quest turn-in scripted dialogue completion
func _on_quest_turnin_scripted_ended() -> void:
	if not _pending_quest_completion.is_empty():
		# Use the central turn-in system
		var result: Dictionary = QuestManager.try_turnin(self, _pending_quest_completion)

		if result.get("success", false):
			_show_notification("Quest completed!")

			# Also handle BountyManager tracking for bounty quests
			if _pending_quest_completion.begins_with("quest_bounty"):
				var bounty := _find_bounty_by_quest_id(_pending_quest_completion)
				if bounty:
					BountyManager.turn_in_bounty(bounty.id)
		else:
			# Fallback: If central turn-in failed, try direct completion
			if _pending_quest_completion.begins_with("quest_bounty"):
				var bounty := _find_bounty_by_quest_id(_pending_quest_completion)
				if bounty:
					BountyManager.turn_in_bounty(bounty.id)
				else:
					QuestManager.complete_quest(_pending_quest_completion)
			else:
				QuestManager.complete_quest(_pending_quest_completion)
			_show_notification("Quest completed!")

		_pending_quest_completion = ""


## Find bounty by its quest ID
func _find_bounty_by_quest_id(quest_id: String) -> BountyManager.Bounty:
	for bounty_id: String in BountyManager.bounties:
		var bounty: BountyManager.Bounty = BountyManager.bounties[bounty_id]
		if bounty.quest_id == quest_id:
			return bounty
	return null


## Get guard-specific knowledge profile (limited to DIRECTIONS + GOODBYE)
func _get_guard_profile() -> NPCKnowledgeProfile:
	# Try to load default guard profile
	var default_path := "res://data/npc_profiles/guard_default.tres"
	if ResourceLoader.exists(default_path):
		return load(default_path) as NPCKnowledgeProfile

	# Create guard profile on the fly
	return NPCKnowledgeProfile.guard()


## ============================================================================
## GUARD COMBAT OVERRIDES
## Guards fight back instead of fleeing
## ============================================================================

## Override take_damage - guards fight back
func take_damage(amount: int, damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null) -> int:
	if _is_dead:
		return 0

	# Apply armor reduction
	var armor_mult: float = 100.0 / (100.0 + float(GUARD_ARMOR))
	var reduced_amount: int = int(float(amount) * armor_mult)
	reduced_amount = maxi(1, reduced_amount)

	# Apply damage
	var actual_damage: int = mini(reduced_amount, current_health)
	current_health -= actual_damage

	# Visual feedback - flash red on sprite
	if billboard and billboard.sprite:
		billboard.sprite.modulate = Color(1.5, 0.4, 0.4)  # Flash red
		get_tree().create_timer(0.15).timeout.connect(func():
			if billboard and billboard.sprite:
				_update_guard_visual()  # Restore state-appropriate color
		)

	# Report crime if attacker is the player
	if attacker and attacker.is_in_group("player"):
		_report_attack_crime(attacker)

	# Enter combat instead of fleeing (guards don't run!)
	if attacker and attacker is Node3D and guard_state != GuardState.COMBAT:
		_target_player = attacker as Node3D
		_change_state(GuardState.COMBAT)
		_call_for_backup()

	# Check for death
	if current_health <= 0:
		_die(attacker)

	var damage_type_name: String = Enums.DamageType.keys()[damage_type] if damage_type < Enums.DamageType.size() else "UNKNOWN"
	var attacker_name: String = attacker.name if attacker else "unknown"
	print("[Guard] %s took %d %s damage (reduced from %d) from %s (HP: %d/%d)" % [
		npc_name,
		actual_damage,
		damage_type_name,
		amount,
		attacker_name,
		current_health,
		max_health
	])

	return actual_damage


## Override _die for guard-specific death handling
func _die(killer: Node = null) -> void:
	if _is_dead:
		return

	_is_dead = true
	is_in_combat = false

	print("[Guard] %s has been killed by %s" % [npc_name, killer.name if killer else "unknown"])

	# Report murder crime (killing a guard is very serious)
	if killer and killer.is_in_group("player"):
		_report_murder_crime(killer)
		# Extra bounty for killing a guard
		var crime_region: String = region_id if not region_id.is_empty() else _get_current_region()
		CrimeManager.report_crime(CrimeManager.CrimeType.ASSAULT, crime_region, [])  # Add extra assault charge

	# Remove from groups
	remove_from_group("interactable")
	remove_from_group("npcs")
	remove_from_group("guards")
	remove_from_group("attackable")

	# Stop any movement
	if wander:
		wander.queue_free()
		wander = null
	velocity = Vector3.ZERO

	# Spawn lootable corpse with guard equipment
	_spawn_guard_corpse()

	# Emit killed signal via CombatManager
	CombatManager.entity_killed.emit(self, killer)

	# Play death sound
	if AudioManager:
		AudioManager.play_sfx("guard_death")

	# Queue removal after short delay
	get_tree().create_timer(0.1).timeout.connect(queue_free)


## Spawn guard-specific corpse with equipment
func _spawn_guard_corpse() -> void:
	var corpse: LootableCorpse = LootableCorpse.spawn_corpse(
		get_parent(),
		global_position,
		npc_name,
		npc_id,
		10  # Level 10 guard
	)

	# Add gold
	corpse.gold = gold_carried

	# Guards drop weapons and armor
	if InventoryManager.weapon_database.has("iron_sword"):
		corpse.add_item("iron_sword", 1, Enums.ItemQuality.AVERAGE)
	if InventoryManager.armor_database.has("chainmail"):
		corpse.add_item("chainmail", 1, Enums.ItemQuality.AVERAGE)
	elif InventoryManager.armor_database.has("leather_armor"):
		corpse.add_item("leather_armor", 1, Enums.ItemQuality.AVERAGE)

	# Maybe add a health potion
	if randf() < 0.4:
		if InventoryManager.item_database.has("health_potion"):
			corpse.add_item("health_potion", 1, Enums.ItemQuality.AVERAGE)


## Override armor value
func get_armor_value() -> int:
	return GUARD_ARMOR


## Static factory method for spawning guards
## sprite_variant: 0 = dwarf guard, 1 = roman soldier, -1 = random (default)
static func spawn_guard(parent: Node, pos: Vector3, patrol: Array[Vector3] = [], p_region_id: String = "elder_moor", sprite_variant: int = -1) -> GuardNPC:
	var guard := GuardNPC.new()

	# Set sprite variant before adding to scene (so _ready uses correct sprite)
	guard.guard_sprite_variant = sprite_variant

	# Validate spawn position
	var validated_pos := CivilianNPC.validate_spawn_position(parent, pos)
	guard.position = validated_pos

	# Set patrol points if provided
	guard.patrol_points = patrol

	# Set region ID
	guard.region_id = p_region_id

	parent.add_child(guard)
	return guard


## Spawn a dwarf-style guard (stocky armored) - named differently to avoid parent conflict
static func spawn_guard_dwarf(parent: Node, pos: Vector3, patrol: Array[Vector3] = [], p_region_id: String = "elder_moor") -> GuardNPC:
	return spawn_guard(parent, pos, patrol, p_region_id, 0)


## Spawn a roman-style guard (spear and shield) - named differently to avoid parent conflict
static func spawn_guard_roman(parent: Node, pos: Vector3, patrol: Array[Vector3] = [], p_region_id: String = "elder_moor") -> GuardNPC:
	return spawn_guard(parent, pos, patrol, p_region_id, 1)
