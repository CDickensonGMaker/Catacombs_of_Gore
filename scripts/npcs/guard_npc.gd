## guard_npc.gd - Town guard NPCs
## Guards that can optionally patrol and have guard-specific dialogue
## Uses directional sprites (front/back) based on camera angle and attack sprite for combat
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

## Guard uses 3D mesh instead of 2D sprite
const GUARD_HEIGHT := 1.8
const GUARD_RADIUS := 0.35

## Combat state
var is_in_combat: bool = false
var is_attacking: bool = false

## Guard 3D mesh visual
var guard_mesh: MeshInstance3D
var guard_material: StandardMaterial3D

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

	# Don't set sprite_texture - we'll create our own 3D mesh
	sprite_texture = null

	# Call parent _ready which creates collision, etc. but no visual since sprite_texture is null
	super._ready()

	# Create guard 3D mesh after parent setup
	_create_guard_mesh()

	# Debug logging for quest system debugging
	print("[Guard] npc_id=%s, npc_type=%s, region_id=%s" % [npc_id, npc_type, region_id])


## Override parent registration to use guard-specific type
func _register_with_world_data() -> void:
	var effective_id: String = npc_id if not npc_id.is_empty() else name
	var hex: Vector2i = WorldData.world_to_axial(global_position)
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

	WorldData.register_npc(effective_id, hex, zone_id, "guard")


func _exit_tree() -> void:
	var effective_id: String = npc_id if not npc_id.is_empty() else name
	WorldData.unregister_npc(effective_id)


func _create_guard_mesh() -> void:
	# Create a capsule mesh for the guard body
	guard_mesh = MeshInstance3D.new()
	guard_mesh.name = "GuardMesh"

	var capsule := CapsuleMesh.new()
	capsule.radius = GUARD_RADIUS
	capsule.height = GUARD_HEIGHT
	guard_mesh.mesh = capsule

	# Position mesh so bottom is at node origin
	guard_mesh.position = Vector3(0, GUARD_HEIGHT / 2.0, 0)

	# Create guard material - dark iron/steel armor look
	guard_material = StandardMaterial3D.new()
	guard_material.albedo_color = Color(0.25, 0.28, 0.32)  # Dark steel gray
	guard_material.metallic = 0.7
	guard_material.roughness = 0.4
	guard_mesh.material_override = guard_material

	add_child(guard_mesh)

	# Add a head sphere
	var head_mesh := MeshInstance3D.new()
	head_mesh.name = "GuardHead"
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	head_mesh.mesh = head
	head_mesh.position = Vector3(0, GUARD_HEIGHT + 0.1, 0)

	# Skin-colored head
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color(0.85, 0.7, 0.55)  # Skin tone
	head_material.roughness = 0.8
	head_mesh.material_override = head_material

	add_child(head_mesh)

	# Add a helmet (cone on top)
	var helmet_mesh := MeshInstance3D.new()
	helmet_mesh.name = "GuardHelmet"
	var helmet := CylinderMesh.new()
	helmet.top_radius = 0.05
	helmet.bottom_radius = 0.22
	helmet.height = 0.25
	helmet_mesh.mesh = helmet
	helmet_mesh.position = Vector3(0, GUARD_HEIGHT + 0.35, 0)

	# Helmet same as armor
	var helmet_material := StandardMaterial3D.new()
	helmet_material.albedo_color = Color(0.3, 0.32, 0.35)
	helmet_material.metallic = 0.8
	helmet_material.roughness = 0.3
	helmet_mesh.material_override = helmet_material

	add_child(helmet_mesh)


func _process(delta: float) -> void:
	# Update guard AI state machine
	_update_guard_ai(delta)

	# Call parent for wander behavior updates (only in PATROL state)
	if guard_state == GuardState.PATROL:
		super._process(delta)

	# Update mesh color based on combat state
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
func _combat_behavior(_delta: float) -> void:
	# Basic combat - approach and attack
	if not _target_player:
		return

	var distance := global_position.distance_to(_target_player.global_position)

	if distance > 2.0:
		# Move towards player
		var direction := (_target_player.global_position - global_position).normalized()
		direction.y = 0
		velocity = direction * CHASE_SPEED
		move_and_slide()
	else:
		# Attack
		if not is_attacking:
			play_attack()
			# Deal damage to player (would connect to combat system)
			_attack_player()


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


## Show arrest dialogue options
func _show_arrest_dialogue(bounty: int, crime_name: String) -> void:
	# Create arrest dialogue data
	var dialogue := DialogueData.new()
	dialogue.title = "Arrest"

	# Create root node
	var root_node := DialogueNode.new()
	root_node.id = "arrest_root"
	root_node.speaker = "Town Guard"
	root_node.text = "Halt, criminal! You are wanted for %s. Your bounty is %d gold. What say you?" % [crime_name, bounty]

	# Create choices
	var choice_pay := DialogueChoice.new()
	choice_pay.text = "I'll pay the fine. (%d gold)" % bounty
	choice_pay.next_node_id = "pay_fine"

	var choice_jail := DialogueChoice.new()
	choice_jail.text = "I'll serve my time."
	choice_jail.next_node_id = "go_to_jail"

	var choice_resist := DialogueChoice.new()
	choice_resist.text = "You'll never take me alive!"
	choice_resist.next_node_id = "resist_arrest"

	root_node.choices = [choice_pay, choice_jail, choice_resist]

	# Create response nodes
	var pay_node := DialogueNode.new()
	pay_node.id = "pay_fine"
	pay_node.speaker = "Town Guard"
	pay_node.text = "Very well. Consider this a warning."
	pay_node.is_end_node = true

	var jail_node := DialogueNode.new()
	jail_node.id = "go_to_jail"
	jail_node.speaker = "Town Guard"
	jail_node.text = "You'll serve your time. Follow me to the jail."
	jail_node.is_end_node = true

	var resist_node := DialogueNode.new()
	resist_node.id = "resist_arrest"
	resist_node.speaker = "Town Guard"
	resist_node.text = "Then you choose death!"
	resist_node.is_end_node = true

	# Build dialogue tree
	dialogue.nodes = [root_node, pay_node, jail_node, resist_node]
	dialogue.start_node_id = "arrest_root"

	# Connect to dialogue ended signal
	if not DialogueManager.dialogue_ended.is_connected(_on_arrest_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_arrest_dialogue_ended)

	# Store which choice was made (we'll check the last node)
	if not DialogueManager.node_changed.is_connected(_on_arrest_node_changed):
		DialogueManager.node_changed.connect(_on_arrest_node_changed)

	# Start dialogue
	DialogueManager.start_dialogue(dialogue, "Town Guard")


## Track which arrest option was chosen
var _arrest_choice: String = ""

func _on_arrest_node_changed(node: DialogueNode) -> void:
	if node:
		_arrest_choice = node.id


## Handle arrest dialogue completion
func _on_arrest_dialogue_ended(_dialogue_data: DialogueData) -> void:
	# Disconnect signals
	if DialogueManager.dialogue_ended.is_connected(_on_arrest_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_arrest_dialogue_ended)
	if DialogueManager.node_changed.is_connected(_on_arrest_node_changed):
		DialogueManager.node_changed.disconnect(_on_arrest_node_changed)

	_arrest_dialogue_active = false

	# Process the choice
	match _arrest_choice:
		"pay_fine":
			_handle_pay_fine()
		"go_to_jail":
			_handle_go_to_jail()
		"resist_arrest":
			_handle_resist_arrest()
		_:
			# Dialogue cancelled - treat as resist
			_handle_resist_arrest()

	_arrest_choice = ""


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


## Update guard visual based on state
func _update_guard_visual() -> void:
	if not guard_material:
		return

	# Change armor color based on state
	match guard_state:
		GuardState.PATROL:
			guard_material.albedo_color = Color(0.25, 0.28, 0.32)  # Normal steel
		GuardState.ALERT:
			guard_material.albedo_color = Color(0.35, 0.32, 0.25)  # Yellowish alert
		GuardState.CHASE, GuardState.COMBAT:
			guard_material.albedo_color = Color(0.4, 0.25, 0.25)  # Reddish combat
		GuardState.ARRESTING:
			guard_material.albedo_color = Color(0.3, 0.3, 0.4)  # Blueish


## Trigger attack (visual feedback via mesh color flash)
func play_attack() -> void:
	is_attacking = true
	# Brief color flash for attack
	if guard_material:
		guard_material.albedo_color = Color(0.6, 0.3, 0.3)  # Flash red
		# Reset after short delay
		get_tree().create_timer(0.2).timeout.connect(func(): is_attacking = false)


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

	# Normal conversation
	if use_conversation_system:
		var profile := _get_guard_profile()
		if profile:
			ConversationSystem.start_conversation(self, profile)
			return

	# Fall back to scripted dialogue
	if dialogue_data:
		DialogueManager.start_dialogue(dialogue_data, npc_name)


## Get quests that can be turned in to this guard using the central turn-in system
func _get_completable_guard_quests() -> Array[String]:
	# Use the new central turn-in system
	var result := QuestManager.get_turnin_quests_for_entity(self)
	print("[Guard] Checking turn-in quests for npc_type='%s', region='%s' -> found %d quests" % [npc_type, region_id, result.size()])
	return result


## Show dialogue for quest completion
func _show_quest_completion_dialogue(completable_quests: Array[String]) -> void:
	if completable_quests.is_empty():
		return

	# For simplicity, handle the first completable quest
	# Could be expanded to show a menu if multiple quests are ready
	var quest_id: String = completable_quests[0]
	var quest: QuestManager.Quest = QuestManager.get_quest(quest_id)
	if not quest:
		return

	# Create turn-in dialogue
	var dialogue := DialogueData.new()
	dialogue.title = "Quest Complete"

	var root_node := DialogueNode.new()
	root_node.id = "turnin_root"
	root_node.speaker = npc_name
	root_node.text = "Ah, you've completed '%s'. Well done. Here's your reward." % quest.title

	# Create accept choice
	var choice_accept := DialogueChoice.new()
	choice_accept.text = "Accept reward"
	choice_accept.next_node_id = "turnin_accept"

	root_node.choices = [choice_accept]

	# Create accept node
	var accept_node := DialogueNode.new()
	accept_node.id = "turnin_accept"
	accept_node.speaker = npc_name

	# Format reward text
	var reward_text := "You received: "
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

	accept_node.text = reward_text + ", ".join(rewards) if not rewards.is_empty() else "The city thanks you for your service."
	accept_node.is_end_node = true

	dialogue.nodes = [root_node, accept_node]
	dialogue.start_node_id = "turnin_root"

	# Store quest ID to complete when dialogue ends
	_pending_quest_completion = quest_id

	# Connect to dialogue ended signal
	if not DialogueManager.dialogue_ended.is_connected(_on_quest_turnin_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_quest_turnin_dialogue_ended)

	DialogueManager.start_dialogue(dialogue, npc_name)


## Pending quest to complete after dialogue
var _pending_quest_completion: String = ""


## Handle quest turn-in dialogue completion
func _on_quest_turnin_dialogue_ended(_dialogue_data: DialogueData) -> void:
	if DialogueManager.dialogue_ended.is_connected(_on_quest_turnin_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_quest_turnin_dialogue_ended)

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
			# (for backwards compatibility with old quest format)
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


## Static factory method for spawning guards
static func spawn_guard(parent: Node, pos: Vector3, patrol: Array[Vector3] = [], p_region_id: String = "elder_moor") -> GuardNPC:
	var guard := GuardNPC.new()

	# Validate spawn position
	var validated_pos := CivilianNPC.validate_spawn_position(parent, pos)
	guard.position = validated_pos

	# Set patrol points if provided
	guard.patrol_points = patrol

	# Set region ID
	guard.region_id = p_region_id

	parent.add_child(guard)
	return guard
