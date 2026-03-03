## tharin_ironbeard.gd - Tharin Ironbeard, Logging Camp Master
## Dwarf NPC who serves as the player's boss at Elder Moor
## Secretly works for the king's intelligence network
## Triggers "The Letter" quest when player tries to leave town
class_name TharinIronbeard
extends StaticBody3D

## NPC identification
@export var npc_id: String = "tharin_ironbeard"
@export var display_name: String = "Tharin Ironbeard"

## Alias for ConversationSystem compatibility
var npc_name: String:
	get: return display_name
	set(value): display_name = value

## Region for quest system
var region_id: String = "elder_moor"
var npc_type: String = "quest_giver"

## Visual components
var billboard: BillboardSprite
var interaction_area: Area3D

## Quest state
var has_given_quest: bool = false
var quest_id: String = "keepers_letter_delivery"

## Quest IDs this NPC can offer (for ConversationSystem QUESTS topic)
## Quests are offered in order - player must complete each before the next unlocks
var quest_ids: Array[String] = ["tharins_message", "tharins_supplies", "tharins_wolf_problem", "keepers_letter_delivery"]

## Current quest in the chain (tracks progression)
var current_chain_quest: String = "tharins_message"

## NPC knowledge profile (created on demand)
var knowledge_profile: NPCKnowledgeProfile

## Wandering behavior
var wander_enabled: bool = true
var wander_radius: float = 6.0
var wander_speed: float = 1.2
var home_position: Vector3
var wander_target: Vector3
var wander_timer: float = 0.0
var wander_wait_time: float = 3.0
var is_waiting: bool = true

## Dialogue content for scripted sequences (first quest in chain)
var dialogue_quest_offer := "Hold up there! Before ye go wanderin' off into the wilds, I've got a task for ye. I need a message delivered to Elder Vorn in Thornfield - it's about our timber shipments. Simple enough work, but it'll let me see if ye can be trusted. What do ye say?"
var dialogue_quest_active := "Have ye delivered that message to Elder Vorn in Thornfield yet? It's northeast of here, follow the road."
var dialogue_quest_complete := "Good work. Ye've proven yerself reliable. Come talk to me - I've got more work for ye."

## Exit interception
var _player_near_exit: bool = false
var _exit_dialogue_shown: bool = false

## Health and combat
var max_health: int = 80  # Dwarves are tough
var current_health: int = 80
var _is_dead: bool = false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npcs")
	add_to_group("quest_givers")  # Important: enables QUESTS topic in ConversationSystem
	add_to_group("attackable")

	current_health = max_health
	home_position = position
	wander_target = position

	_create_visual()
	_create_interaction_area()
	_create_collision()
	_register_compass_poi()
	_register_with_world_data()

	# Connect to wilderness exit signals
	_setup_exit_detection()

	# Check if any quest in chain already started (from save)
	for q_id: String in quest_ids:
		if QuestManager.is_quest_active(q_id) or QuestManager.is_quest_completed(q_id):
			has_given_quest = true
			print("[TharinIronbeard] Quest '%s' already active/completed - has_given_quest = true" % q_id)
			break

	print("[TharinIronbeard] Initialized. has_given_quest: %s" % has_given_quest)

	# Connect to ConversationSystem signals for quest handling
	if not ConversationSystem.conversation_ended.is_connected(_on_conversation_ended):
		ConversationSystem.conversation_ended.connect(_on_conversation_ended)


## Distance threshold for exit detection (from world origin / town center)
const EXIT_DISTANCE_THRESHOLD := 40.0


## Check if any quest in the chain is currently active
func _is_any_quest_active() -> bool:
	for q_id: String in quest_ids:
		if QuestManager.is_quest_active(q_id):
			return true
	return false

func _physics_process(delta: float) -> void:
	# Check for player leaving town (simple distance check)
	# Only show popup if quest not yet given AND not already active (prevents re-showing after accept)
	if not has_given_quest and not _exit_dialogue_shown and not _is_any_quest_active():
		_check_player_exit_distance()

	# Skip wandering if intercepting player
	if not wander_enabled or _player_near_exit:
		return

	_update_wander(delta)


## Check if player is too far from town center and intercept if needed
func _check_player_exit_distance() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Check distance from town center (world origin)
	var player_pos: Vector3 = player.global_position
	var distance_from_center: float = Vector2(player_pos.x, player_pos.z).length()

	if distance_from_center > EXIT_DISTANCE_THRESHOLD:
		if not _player_near_exit:
			_player_near_exit = true
			print("[TharinIronbeard] Player at distance %.1f - intercepting!" % distance_from_center)
			_intercept_player()
	else:
		_player_near_exit = false


## Wander around the camp
func _update_wander(delta: float) -> void:
	if is_waiting:
		wander_timer -= delta
		if wander_timer <= 0:
			_pick_new_wander_target()
			is_waiting = false
	else:
		var direction := (wander_target - position).normalized()
		direction.y = 0

		var distance := position.distance_to(wander_target)
		if distance > 0.5:
			position += direction * wander_speed * delta
			if billboard:
				billboard.set_walking(true)
		else:
			is_waiting = true
			wander_timer = randf_range(2.0, wander_wait_time)
			if billboard:
				billboard.set_walking(false)


func _pick_new_wander_target() -> void:
	var angle := randf() * TAU
	var radius := randf() * wander_radius
	wander_target = home_position + Vector3(cos(angle) * radius, 0, sin(angle) * radius)


## Create visual representation (dwarf sprite)
func _create_visual() -> void:
	# Get sprite config from ActorRegistry for consistent values
	var config: Dictionary = ActorRegistry.get_sprite_config("tharin_ironbeard")

	var tex: Texture2D = null
	if not config.is_empty() and config.get("sprite_path", "") != "":
		tex = load(config.get("sprite_path", ""))

	if not tex:
		push_warning("[TharinIronbeard] No sprite texture found in ActorRegistry")
		return

	billboard = BillboardSprite.new()
	billboard.sprite_sheet = tex
	billboard.h_frames = config.get("h_frames", 1)
	billboard.v_frames = config.get("v_frames", 1)
	billboard.pixel_size = config.get("pixel_size", 0.0193)
	billboard.idle_frames = config.get("idle_frames", 1)
	billboard.walk_frames = config.get("walk_frames", 1)
	billboard.idle_fps = config.get("idle_fps", 2.0)
	billboard.walk_fps = config.get("walk_fps", 6.0)
	billboard.name = "Billboard"

	add_child(billboard)


## Create interaction area
func _create_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.5
	collision.shape = shape
	collision.position.y = 1.0
	interaction_area.add_child(collision)

	add_child(interaction_area)


## Create collision shape
func _create_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35  # Slightly wider for dwarf
	shape.height = 1.4   # Shorter for dwarf
	collision.shape = shape
	collision.position.y = 0.7
	add_child(collision)


## Setup detection for when player approaches wilderness exit
## Simple distance-based check instead of complex Area3D zones
func _setup_exit_detection() -> void:
	# No complex Area3D setup needed - we check distance in _physics_process
	print("[TharinIronbeard] Exit detection initialized (distance-based)")


## Intercept player trying to leave without the quest
func _intercept_player() -> void:
	if _exit_dialogue_shown or has_given_quest:
		return

	_exit_dialogue_shown = true

	# Stop wandering and move toward player
	wander_enabled = false

	# Show notification to draw attention
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Tharin: Hold on there!")

	# Small delay then trigger dialogue
	await get_tree().create_timer(0.5).timeout
	_open_quest_scripted_dialogue()


## Interaction interface
func interact(_interactor: Node) -> void:
	# Notify quest system that player talked to this NPC
	QuestManager.on_npc_talked(npc_id)

	# If quest not given yet and player near exit, use scripted intercept dialogue
	if not has_given_quest and _player_near_exit:
		_open_quest_scripted_dialogue()
		return

	# Otherwise use ConversationSystem for topic-based dialogue
	var profile := _get_or_create_profile()
	ConversationSystem.start_conversation(self, profile)


func get_interaction_prompt() -> String:
	if not has_given_quest:
		return "Talk to " + display_name + " [!]"
	elif QuestManager.is_quest_active(quest_id):
		return "Talk to " + display_name
	else:
		return "Talk to " + display_name


## Get or create the NPC knowledge profile
func _get_or_create_profile() -> NPCKnowledgeProfile:
	if not knowledge_profile:
		knowledge_profile = NPCKnowledgeProfile.new()
		# Tharin is a logging camp foreman with connections
		knowledge_profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
		knowledge_profile.personality_traits = ["gruff", "secretive", "dutiful"]
		knowledge_profile.knowledge_tags = ["local_area", "logging", "dwarves", "the_keepers"]
		knowledge_profile.base_disposition = 55
		knowledge_profile.speech_style = "casual"  # Dwarven accent handled in dialogue text
	return knowledge_profile


## Handle conversation ending - check if we need to offer quest via QUESTS topic
func _on_conversation_ended(npc: Node) -> void:
	if npc != self:
		return
	# Quest acceptance is handled by ConversationSystem's QUESTS topic handler


## Open scripted quest dialogue (for intercept scenario)
func _open_quest_scripted_dialogue() -> void:
	var lines: Array = []

	# Line 0: Quest offer with choices
	lines.append(ConversationSystem.create_scripted_line(
		display_name,
		dialogue_quest_offer,
		[
			ConversationSystem.create_scripted_choice("I'll deliver the letter.", 1),
			ConversationSystem.create_scripted_choice("I need to prepare first.", 2)
		]
	))

	# Line 1: Accept quest
	lines.append(ConversationSystem.create_scripted_line(
		display_name,
		"Good. Don't let me down.",
		[],
		true  # is_end
	))

	# Line 2: Decline (can talk again)
	lines.append(ConversationSystem.create_scripted_line(
		display_name,
		"Don't take too long. This is important.",
		[],
		true  # is_end
	))

	# Track which choice was made
	if not ConversationSystem.scripted_line_shown.is_connected(_on_quest_line_shown):
		ConversationSystem.scripted_line_shown.connect(_on_quest_line_shown)

	ConversationSystem.start_scripted_dialogue(lines, _on_quest_scripted_ended)


var _last_quest_line_index: int = 0

func _on_quest_line_shown(_line: Dictionary, index: int) -> void:
	_last_quest_line_index = index


func _on_quest_scripted_ended() -> void:
	if ConversationSystem.scripted_line_shown.is_connected(_on_quest_line_shown):
		ConversationSystem.scripted_line_shown.disconnect(_on_quest_line_shown)

	match _last_quest_line_index:
		1:  # Accepted
			_accept_quest()
		2:  # Declined
			_exit_dialogue_shown = false  # Allow showing again
			wander_enabled = true

	_last_quest_line_index = 0


func _accept_quest() -> void:
	has_given_quest = true

	# Start the first quest in the chain
	var first_quest := "tharins_message"
	if QuestManager.start_quest(first_quest):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Quest Started: A Message for Thornfield")
		AudioManager.play_ui_confirm()

	# Give player the trade message item
	InventoryManager.add_item("tharins_trade_message", 1)

	# Resume wandering
	wander_enabled = true


## Register as compass POI
func _register_compass_poi() -> void:
	add_to_group("compass_poi")
	set_meta("poi_id", "npc_%d" % get_instance_id())
	set_meta("poi_name", display_name)
	set_meta("poi_color", Color(0.9, 0.7, 0.3))  # Gold for important NPC


## Register with PlayerGPS
func _register_with_world_data() -> void:
	PlayerGPS.register_npc(self, npc_id, npc_type, "village_elder_moor")


func _exit_tree() -> void:
	PlayerGPS.unregister_npc(npc_id)
	# Disconnect signals
	if ConversationSystem.conversation_ended.is_connected(_on_conversation_ended):
		ConversationSystem.conversation_ended.disconnect(_on_conversation_ended)
	if ConversationSystem.scripted_line_shown.is_connected(_on_quest_line_shown):
		ConversationSystem.scripted_line_shown.disconnect(_on_quest_line_shown)


## Take damage from attacks
func take_damage(amount: int, _damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null) -> int:
	if _is_dead:
		return 0

	var actual_damage: int = mini(amount, current_health)
	current_health -= actual_damage

	# Visual feedback - flash red
	if billboard and billboard.sprite:
		var original_color: Color = billboard.sprite.modulate
		billboard.sprite.modulate = Color(1.0, 0.3, 0.3)
		get_tree().create_timer(0.15).timeout.connect(func():
			if billboard and billboard.sprite and not _is_dead:
				billboard.sprite.modulate = original_color
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


## Get armor value (Tharin has decent armor as a dwarf)
func get_armor_value() -> int:
	return 15


## Handle death
func _die(killer: Node = null) -> void:
	if _is_dead:
		return

	_is_dead = true

	print("[TharinIronbeard] Tharin Ironbeard has been killed!")

	# Report crime - killing Tharin is murder (and a major story consequence!)
	if killer and killer.is_in_group("player"):
		CrimeManager.report_crime(CrimeManager.CrimeType.MURDER, region_id, [])

	# Spawn corpse with loot
	_spawn_corpse()

	# Emit death signal
	CombatManager.entity_killed.emit(self, killer)

	# Play death sound
	if AudioManager:
		AudioManager.play_sfx("enemy_death")

	# Remove from groups
	remove_from_group("interactable")
	remove_from_group("npcs")
	remove_from_group("quest_givers")
	remove_from_group("attackable")
	remove_from_group("compass_poi")

	# Unregister from PlayerGPS
	PlayerGPS.unregister_npc(npc_id)

	queue_free()


## Spawn a lootable corpse
func _spawn_corpse() -> void:
	var corpse: LootableCorpse = LootableCorpse.spawn_corpse(
		get_parent(),
		global_position,
		display_name,
		npc_id,
		10  # Level 10 - he's an important NPC
	)

	# Add Tharin's gold
	corpse.gold = randi_range(100, 300)

	# Add some unique items
	corpse.add_item("health_potion", 2, Enums.ItemQuality.ABOVE_AVERAGE)
	corpse.add_item("ale", 3, Enums.ItemQuality.AVERAGE)
