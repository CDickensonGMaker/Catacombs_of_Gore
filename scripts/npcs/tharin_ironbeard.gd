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

## Sprite configuration (dwarf - shorter and stockier)
var sprite_h_frames: int = 5
var sprite_v_frames: int = 1
var sprite_pixel_size: float = 0.032  # Shorter than standard human

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

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npcs")
	add_to_group("quest_givers")  # Important: enables QUESTS topic in ConversationSystem

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
			break

	# Connect to ConversationSystem signals for quest handling
	if not ConversationSystem.conversation_ended.is_connected(_on_conversation_ended):
		ConversationSystem.conversation_ended.connect(_on_conversation_ended)


func _physics_process(delta: float) -> void:
	if not wander_enabled or has_given_quest == false and _player_near_exit:
		return

	_update_wander(delta)


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
	# Try to load dwarf sprite, fall back to civilian
	var tex: Texture2D = load("res://Sprite folders grab bag/man_civilian.png")

	if not tex:
		push_warning("[TharinIronbeard] No sprite texture available")
		return

	billboard = BillboardSprite.new()
	billboard.sprite_sheet = tex
	billboard.h_frames = 8  # man_civilian uses 8x2
	billboard.v_frames = 2
	billboard.pixel_size = sprite_pixel_size
	billboard.idle_frames = 8
	billboard.walk_frames = 8
	billboard.idle_fps = 3.0
	billboard.walk_fps = 6.0
	billboard.name = "Billboard"

	add_child(billboard)

	# Tint to distinguish as dwarf (reddish-brown for beard/hair)
	# Must be set after add_child since sprite is created in _ready
	if billboard.sprite:
		billboard.sprite.modulate = Color(0.9, 0.75, 0.65)


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
func _setup_exit_detection() -> void:
	# We'll check for player near exit each frame via Area3D overlap
	# Create a large detection area around the south exit
	var exit_detector := Area3D.new()
	exit_detector.name = "ExitDetector"
	exit_detector.collision_layer = 0
	exit_detector.collision_mask = 2  # Player layer
	exit_detector.monitoring = true

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12, 4, 8)
	col.shape = box
	# Position at south exit (Z = 30 for 60-unit zone)
	col.position = Vector3(0, 2, 30)
	exit_detector.add_child(col)

	# Make detector global (not relative to Tharin's position)
	exit_detector.top_level = true
	add_child(exit_detector)

	exit_detector.body_entered.connect(_on_player_near_exit)
	exit_detector.body_exited.connect(_on_player_left_exit)


func _on_player_near_exit(body: Node3D) -> void:
	if body.is_in_group("player") and not has_given_quest:
		_player_near_exit = true
		_intercept_player()


func _on_player_left_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_near_exit = false


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
