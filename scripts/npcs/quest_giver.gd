## quest_giver.gd - NPC that gives and completes quests
## Supports multiple quests - offers the next available quest after completing previous ones
class_name QuestGiver
extends StaticBody3D

## Shop UI script for merchant functionality
const ShopUIScript = preload("res://scripts/ui/shop_ui.gd")

@export var npc_id: String = "quest_giver_01"
@export var display_name: String = "Mysterious Stranger"

## Alias for ConversationSystem compatibility
var npc_name: String:
	get: return display_name
	set(value): display_name = value

## Alias for ShopUI compatibility - returns display_name
var merchant_name: String:
	get:
		return display_name

## NPC type and region for central turn-in system (NPC_TYPE_IN_REGION)
var npc_type: String = "quest_giver"  # Can be overridden for specific NPC types
@export var region_id: String = ""  # Set by zone when spawned or in scene

## List of quests this NPC can offer (in order of priority)
## If empty, will auto-detect available quests from QuestManager
@export var quest_ids: Array[String] = []

## Faction affiliation (e.g., "human_empire", "the_keepers", "merchants_guild")
## Used for quest tracking and faction reputation
@export var faction_id: String = "human_empire"

## NPC knowledge profile for ConversationSystem (uses generic_villager if not set)
@export var npc_profile: NPCKnowledgeProfile

## ============================================================================
## MERCHANT FUNCTIONALITY (Optional)
## Enable to let this quest giver also sell items
## ============================================================================
@export var has_shop: bool = false
@export var shop_type: String = "general"
@export var shop_tier: LootTables.LootTier = LootTables.LootTier.UNCOMMON

## Shop inventory: Array of {item_id, price, quantity, quality}
## Generated automatically when has_shop is true
var shop_inventory: Array[Dictionary] = []

## Shop UI instance (used when opening shop)
var shop_ui: Control = null

## Optional pre-quest dialogue (shown before quest offer when quest is NOT_STARTED)
## If set, uses DialogueManager instead of ConversationSystem for this initial dialogue
@export var dialogue_data: DialogueData

## If true, uses legacy hardcoded dialogue instead of ConversationSystem
## Set to false to use the new topic-based conversation system
@export var use_legacy_dialogue: bool = false

## Sprite texture for billboard display (PS1-style)
## If not set, defaults based on is_female setting
@export var sprite_texture: Texture2D

## Whether this NPC is female (affects default sprite if no texture set)
@export var is_female: bool = false

## Current quest being discussed (determined dynamically)
var current_quest_id: String = ""

## Quest state tracking
enum QuestState { NO_QUESTS, NOT_STARTED, ACTIVE, READY_TO_COMPLETE, COMPLETED_ALL }
var quest_state: QuestState = QuestState.NO_QUESTS

## Visual components
var billboard: BillboardSprite
var interaction_area: Area3D

## Sprite configuration
var sprite_h_frames: int = 1  # Single frame (48x96)
var sprite_v_frames: int = 1  # Single frame
var sprite_pixel_size: float = 0.0256  # 96px frame, 2.46m target

## Dialogue UI reference
var dialogue_ui: Control = null

## Track if intro dialogue has been shown (for optional pre-quest dialogue)
var _intro_dialogue_shown: bool = false

## Guard against multiple interact() calls on same frame
var _is_interacting: bool = false

## Dialogue content per quest (keyed by quest_id)
## Falls back to generic dialogue if quest not found
## Legacy quest dialogues removed - use DialogueTree resources instead
var quest_dialogues := {}

## Health and combat
var max_health: int = 50
var current_health: int = 50
var _is_dead: bool = false

## Generic dialogue for unknown quests
var generic_dialogues := {
	"offer": "I have a task for you, if you're willing.",
	"active": "Have you completed the task yet?",
	"complete": "Well done! Here is your reward."
}

## Dialogue when NPC has no more quests
var no_quest_dialogue := "You've done well, traveler.\nMay your path be clear."

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npcs")
	add_to_group("quest_givers")
	add_to_group("attackable")

	# If this NPC also has a shop, add to merchant groups
	if has_shop:
		add_to_group("merchants")
		add_to_group("shops")
		# Add to specific shop type groups for minimap icons
		match shop_type:
			"blacksmith", "basic_blacksmith", "weapon", "armor":
				add_to_group("blacksmiths")
			"alchemist":
				add_to_group("alchemists")

	current_health = max_health

	# Only create visuals/areas if not already present (supports scene instancing)
	if not get_node_or_null("Billboard"):
		_create_visual()
	else:
		billboard = get_node_or_null("Billboard")

	if not get_node_or_null("InteractionArea"):
		_create_interaction_area()
	else:
		interaction_area = get_node_or_null("InteractionArea")

	if not get_node_or_null("Collision"):
		_create_collision()

	_register_compass_poi()
	_register_with_world_data()

	# Connect to quest updates
	if QuestManager.has_signal("quest_updated"):
		QuestManager.quest_updated.connect(_on_quest_updated)
	if QuestManager.has_signal("objective_completed"):
		QuestManager.objective_completed.connect(_on_objective_completed)

	# Check if quest is already active or completed
	_update_quest_state()

	# Initialize shop inventory if this NPC has a shop
	if has_shop and shop_inventory.is_empty():
		_setup_shop_inventory()

## Create the visual representation (billboard sprite - PS1 style)
func _create_visual() -> void:
	# Load fallback texture if none assigned - pick based on gender
	var tex: Texture2D = sprite_texture
	var h_frames: int = sprite_h_frames
	var v_frames: int = sprite_v_frames
	var pixel_size: float = sprite_pixel_size

	# Check ActorRegistry for actor configuration (base ZooRegistry + any patches)
	# ZooRegistry is the source of truth - scene file values are only fallback
	if ActorRegistry and not npc_id.is_empty() and ActorRegistry.has_actor(npc_id):
		var config: Dictionary = ActorRegistry.get_sprite_config(npc_id)
		if not config.is_empty():
			var registry_path: String = config.get("sprite_path", "")
			if not registry_path.is_empty() and ResourceLoader.exists(registry_path):
				tex = load(registry_path) as Texture2D
				h_frames = config.get("h_frames", h_frames)
				v_frames = config.get("v_frames", v_frames)
				pixel_size = config.get("pixel_size", pixel_size)

	if not tex:
		if is_female:
			# Use lady in red sprite for female NPCs
			tex = load("res://assets/sprites/npcs/civilians/lady_in_red.png") as Texture2D
			h_frames = 8  # lady_in_red is 8-frame sheet
			v_frames = 1
			pixel_size = 0.0256  # 96px frame, 2.46m target
		else:
			# Use man_civilian sprite for male NPCs
			tex = load("res://assets/sprites/npcs/civilians/man_civilian.png") as Texture2D
			h_frames = 1  # Single frame (48x96)
			v_frames = 1
			pixel_size = 0.0256  # 96px frame, 2.46m target

	if not tex:
		push_warning("QuestGiver: No sprite texture available for " + display_name)
		return

	billboard = BillboardSprite.new()
	billboard.sprite_sheet = tex
	billboard.h_frames = h_frames
	billboard.v_frames = v_frames
	billboard.pixel_size = pixel_size
	billboard.idle_frames = h_frames
	billboard.walk_frames = h_frames
	billboard.idle_fps = 3.0
	billboard.walk_fps = 6.0
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
	shape.radius = 2.5  # Interaction range
	collision.shape = shape
	collision.position.y = 1.0
	interaction_area.add_child(collision)

	add_child(interaction_area)

## Create collision shape
func _create_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.6
	collision.shape = shape
	collision.position.y = 0.8
	add_child(collision)

## Update quest state based on QuestManager
## Finds the current quest to focus on (active > available > none)
func _update_quest_state() -> void:
	current_quest_id = ""

	# First check for any active quest from our list that's ready to complete
	for qid in quest_ids:
		if QuestManager.is_quest_active(qid):
			current_quest_id = qid
			if QuestManager.are_objectives_complete(qid):
				quest_state = QuestState.READY_TO_COMPLETE
			else:
				quest_state = QuestState.ACTIVE
			return

	# No active quests - check for available quests
	for qid in quest_ids:
		if QuestManager.is_quest_available(qid):
			current_quest_id = qid
			quest_state = QuestState.NOT_STARTED
			return

	# No available quests - all completed or none configured
	quest_state = QuestState.COMPLETED_ALL

## Interaction interface
func interact(_interactor: Node) -> void:
	# Guard against multiple calls - set immediately before any other checks
	if _is_interacting:
		return
	_is_interacting = true

	# Block interaction if already in a conversation or scripted dialogue
	if ConversationSystem.is_active or ConversationSystem.is_scripted_mode:
		_is_interacting = false
		return

	_update_quest_state()
	# Notify quest system that player talked to this NPC (for "talk" objectives)
	QuestManager.on_npc_talked(npc_id)

	# Priority 0: Check for quest turn-ins using central turn-in system
	var turnin_quests := QuestManager.get_turnin_quests_for_entity(self)
	if not turnin_quests.is_empty():
		# If we have custom dialogue_data, use DialogueManager for richer turn-in experience
		if dialogue_data:
			DialogueManager.start_dialogue(dialogue_data, display_name)
		else:
			# Use generic scripted turn-in dialogue
			_show_quest_turnin_dialogue(turnin_quests[0])
		_is_interacting = false
		return

	# Use ConversationSystem for all other NPC interactions
	_open_conversation()
	_is_interacting = false


## Open ConversationSystem topic-based dialogue
func _open_conversation() -> void:
	# Create or use existing profile
	var profile: NPCKnowledgeProfile = npc_profile
	if not profile:
		# Generate a basic profile for quest givers
		profile = NPCKnowledgeProfile.new()
		profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
		profile.personality_traits = ["helpful"]
		profile.knowledge_tags = ["local_area", "quests"]
		profile.base_disposition = 60
		profile.speech_style = "casual"

	# Start conversation through ConversationSystem
	ConversationSystem.start_conversation(self, profile)

func get_interaction_prompt() -> String:
	_update_quest_state()
	match quest_state:
		QuestState.NOT_STARTED:
			return "Press [E] to talk to " + display_name + " [!]"
		QuestState.ACTIVE:
			return "Press [E] to talk to " + display_name
		QuestState.READY_TO_COMPLETE:
			return "Press [E] to talk to " + display_name + " [?]"
		QuestState.COMPLETED_ALL:
			return "Press [E] to talk to " + display_name
		_:
			return "Press [E] to talk to " + display_name

## Open optional intro dialogue (uses DialogueManager system)
func _open_intro_dialogue() -> void:
	if not dialogue_data:
		return

	# Connect to dialogue end signal to mark intro as shown
	if not DialogueManager.dialogue_ended.is_connected(_on_intro_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_intro_dialogue_ended)

	DialogueManager.start_dialogue(dialogue_data, display_name)

## Called when intro dialogue ends
func _on_intro_dialogue_ended(_data: DialogueData) -> void:
	# Disconnect to avoid repeat calls
	if DialogueManager.dialogue_ended.is_connected(_on_intro_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_intro_dialogue_ended)

	_intro_dialogue_shown = true

## Open dialogue UI
func _open_dialogue() -> void:
	if dialogue_ui:
		return

	# Pause game
	get_tree().paused = true
	GameManager.enter_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Create dialogue UI
	dialogue_ui = _create_dialogue_panel()

	var canvas := CanvasLayer.new()
	canvas.name = "DialogueCanvas"
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	canvas.add_child(dialogue_ui)

## Get dialogue text for current state and quest
func _get_dialogue_text() -> String:
	if quest_state == QuestState.COMPLETED_ALL:
		return no_quest_dialogue

	var quest_dlg: Dictionary = quest_dialogues.get(current_quest_id, {})

	match quest_state:
		QuestState.NOT_STARTED:
			return quest_dlg.get("offer", generic_dialogues["offer"])
		QuestState.ACTIVE:
			return quest_dlg.get("active", generic_dialogues["active"])
		QuestState.READY_TO_COMPLETE:
			return quest_dlg.get("complete", generic_dialogues["complete"])
		_:
			return no_quest_dialogue

## Get dialogue options for current state
func _get_dialogue_options() -> Array:
	match quest_state:
		QuestState.NOT_STARTED:
			return [
				{"text": "I'll do it.", "action": "accept_quest"},
				{"text": "Not interested.", "action": "close"}
			]
		QuestState.ACTIVE:
			return [
				{"text": "Working on it.", "action": "close"}
			]
		QuestState.READY_TO_COMPLETE:
			return [
				{"text": "Thank you.", "action": "complete_quest"}
			]
		_:
			return [
				{"text": "Farewell.", "action": "close"}
			]

## Create the dialogue panel
func _create_dialogue_panel() -> Control:
	var text: String = _get_dialogue_text()
	var options: Array = _get_dialogue_options()

	var panel := PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -120
	panel.offset_bottom = 120
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	# Dark gothic style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1)
	style.border_color = Color(0.3, 0.25, 0.2)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# NPC Name
	var name_label := Label.new()
	name_label.text = display_name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_label)

	# Dialogue text
	var text_label := Label.new()
	text_label.text = text
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	vbox.add_child(text_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	vbox.add_child(spacer)

	# Response buttons
	for option in options:
		var btn := Button.new()
		btn.text = option["text"]
		btn.custom_minimum_size = Vector2(200, 35)
		btn.pressed.connect(_on_option_selected.bind(option["action"]))
		btn.process_mode = Node.PROCESS_MODE_ALWAYS
		_style_button(btn)
		vbox.add_child(btn)

	return panel

## Style a button
func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.12, 0.15)
	normal.border_color = Color(0.3, 0.25, 0.2)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.2, 0.15)
	hover.border_color = Color(0.8, 0.6, 0.2)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	btn.add_theme_color_override("font_hover_color", Color(0.8, 0.6, 0.2))

## Handle dialogue option selection
func _on_option_selected(action: String) -> void:
	match action:
		"accept_quest":
			_accept_quest()
			_close_dialogue()
		"complete_quest":
			_complete_quest()
			_close_dialogue()
		"close":
			_close_dialogue()

## Accept the quest
func _accept_quest() -> void:
	if current_quest_id.is_empty():
		return

	if QuestManager.start_quest(current_quest_id):
		quest_state = QuestState.ACTIVE

		# Get quest title for notification
		var quest := QuestManager.get_quest(current_quest_id)
		var quest_title := quest.title if quest else current_quest_id

		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Quest Started: " + quest_title)
		AudioManager.play_ui_confirm()

## Complete the quest and give rewards
func _complete_quest() -> void:
	if current_quest_id.is_empty():
		return

	QuestManager.complete_quest(current_quest_id)

	# Update state to check for next quest
	_update_quest_state()

	# Rewards (gold, XP) will show in game log via signals
	AudioManager.play_ui_confirm()

## Close dialogue UI
func _close_dialogue() -> void:
	if dialogue_ui:
		var canvas := dialogue_ui.get_parent()
		dialogue_ui.queue_free()
		if canvas:
			canvas.queue_free()
		dialogue_ui = null

	get_tree().paused = false
	GameManager.exit_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Quest update callbacks
func _on_quest_updated(updated_quest_id: String, _objective_id: String) -> void:
	if updated_quest_id in quest_ids:
		_update_quest_state()

func _on_objective_completed(completed_quest_id: String, _objective_id: String) -> void:
	if completed_quest_id in quest_ids:
		_update_quest_state()

## Register this NPC as a compass POI
## Uses instance ID for guaranteed uniqueness across scenes
func _register_compass_poi() -> void:
	add_to_group("compass_poi")
	# Use instance_id for guaranteed uniqueness - prevents ghost markers across scenes
	set_meta("poi_id", "npc_%d" % get_instance_id())
	set_meta("poi_name", display_name)
	set_meta("poi_color", Color(0.4, 0.8, 1.0))  # Light blue for NPCs


## Register this NPC with WorldData for quest navigation/tracking
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

	PlayerGPS.register_npc(self, effective_id, npc_type, zone_id)
	print("[QuestGiver] Registered with PlayerGPS: npc_id='%s', cell=%s, zone='%s', type='%s'" % [
		effective_id, cell, zone_id, npc_type
	])


## Unregister from PlayerGPS when removed from scene
func _exit_tree() -> void:
	var effective_id: String = npc_id if not npc_id.is_empty() else name
	PlayerGPS.unregister_npc(effective_id)


## Constants for spawn collision avoidance
const SPAWN_CHECK_RADIUS := 1.5  # Radius to check for obstacles
const SPAWN_MAX_ATTEMPTS := 8    # Max attempts to find clear ground
const SPAWN_OFFSET_DISTANCE := 3.0  # How far to offset if blocked
const BEACON_HEIGHT := 4.0  # Height of beacon effect above NPC


## Static factory method using ActorRegistry for sprite configuration
## actor_id: The actor ID from ZooRegistry (e.g., "elder_vorn_thornfield")
## Falls back to default sprites if actor not found in registry
static func spawn_from_registry(parent: Node, pos: Vector3, npc_name: String, npc_id: String, actor_id: String, quest_list: Array[String] = [], is_talk_target: bool = false) -> QuestGiver:
	# Get ActorRegistry autoload (static functions cannot access autoloads directly)
	var actor_registry: Node = Engine.get_singleton("ActorRegistry") if Engine.has_singleton("ActorRegistry") else null
	if not actor_registry:
		actor_registry = parent.get_node_or_null("/root/ActorRegistry")

	# Try to get sprite config from ActorRegistry
	var sprite_tex: Texture2D = null
	var h_frames: int = 1
	var v_frames: int = 1
	var pixel_size: float = 0.0

	if actor_registry and actor_registry.has_actor(actor_id):
		var config: Dictionary = actor_registry.get_sprite_config(actor_id)
		if not config.is_empty():
			var sprite_path: String = config.get("sprite_path", "")
			if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
				sprite_tex = load(sprite_path)
				h_frames = config.get("h_frames", 1)
				v_frames = config.get("v_frames", 1)
				pixel_size = config.get("pixel_size", 0.0384)

	return spawn_quest_giver(parent, pos, npc_name, npc_id, sprite_tex, h_frames, v_frames, quest_list, is_talk_target, pixel_size)


## Static factory method
## quest_list: Optional array of quest IDs this NPC can give.
## is_talk_target: If true, this NPC gives no quests (just a "talk to" objective target).
## pixel_size: Size of sprite in world units (0.0 = use default 0.0384)
## actor_id: Optional actor ID for ActorRegistry lookup (e.g., "tharin_ironbeard")
static func spawn_quest_giver(parent: Node, pos: Vector3, npc_name: String = "Mysterious Stranger", id: String = "", custom_sprite: Texture2D = null, h_frames: int = 8, v_frames: int = 2, quest_list: Array[String] = [], is_talk_target: bool = false, pixel_size: float = 0.0, actor_id: String = "") -> QuestGiver:
	var npc := QuestGiver.new()
	npc.display_name = npc_name
	# Set npc_id - use provided id, or convert name to snake_case
	if id.is_empty():
		npc.npc_id = npc_name.to_lower().replace(" ", "_")
	else:
		npc.npc_id = id
	# Set quest list: talk targets have no quests, otherwise use provided list or defaults
	if is_talk_target:
		npc.quest_ids = []
	elif not quest_list.is_empty():
		npc.quest_ids = quest_list

	# Check ActorRegistry for Zoo patches if actor_id is provided or can be derived
	var actual_sprite: Texture2D = custom_sprite
	var actual_h_frames: int = h_frames
	var actual_v_frames: int = v_frames
	var actual_pixel_size: float = pixel_size

	# Determine actor_id to check - use explicit ID or derive from npc_id
	var registry_id: String = actor_id
	if registry_id.is_empty():
		registry_id = npc.npc_id

	# Check ActorRegistry for patched sprite
	var actor_registry: Node = Engine.get_singleton("ActorRegistry") if Engine.has_singleton("ActorRegistry") else null
	if not actor_registry:
		actor_registry = parent.get_node_or_null("/root/ActorRegistry")

	if actor_registry and actor_registry.has_actor(registry_id):
		var config: Dictionary = actor_registry.get_sprite_config(registry_id)
		if not config.is_empty():
			var registry_path: String = config.get("sprite_path", "")
			if not registry_path.is_empty() and ResourceLoader.exists(registry_path):
				actual_sprite = load(registry_path)
				actual_h_frames = config.get("h_frames", h_frames)
				actual_v_frames = config.get("v_frames", v_frames)
				actual_pixel_size = config.get("pixel_size", pixel_size if pixel_size > 0.0 else 0.0384)

	# Set custom sprite before adding to tree (before _ready)
	if actual_sprite:
		npc.sprite_texture = actual_sprite
		npc.sprite_h_frames = actual_h_frames
		npc.sprite_v_frames = actual_v_frames
		if actual_pixel_size > 0.0:
			npc.sprite_pixel_size = actual_pixel_size

	# Find clear ground position to avoid spawning inside trees/obstacles
	var clear_pos := _find_clear_spawn_position(parent, pos)
	npc.position = clear_pos

	parent.add_child(npc)

	# Add beacon effect for visibility through obstacles
	npc._add_beacon_effect()

	return npc


## Find a clear position for spawning, avoiding obstacles
static func _find_clear_spawn_position(parent: Node, start_pos: Vector3) -> Vector3:
	# Need to defer physics query to next frame if not in tree yet
	# For now, use a simple approach: try multiple positions
	var test_pos := start_pos

	# Try the original position first, then spiral outward
	var offsets: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(SPAWN_OFFSET_DISTANCE, 0, 0),
		Vector3(-SPAWN_OFFSET_DISTANCE, 0, 0),
		Vector3(0, 0, SPAWN_OFFSET_DISTANCE),
		Vector3(0, 0, -SPAWN_OFFSET_DISTANCE),
		Vector3(SPAWN_OFFSET_DISTANCE, 0, SPAWN_OFFSET_DISTANCE),
		Vector3(-SPAWN_OFFSET_DISTANCE, 0, SPAWN_OFFSET_DISTANCE),
		Vector3(SPAWN_OFFSET_DISTANCE, 0, -SPAWN_OFFSET_DISTANCE),
	]

	for offset: Vector3 in offsets:
		test_pos = start_pos + offset
		if _is_position_clear(parent, test_pos):
			if offset != Vector3.ZERO:
				print("[QuestGiver] Moved spawn from %s to %s to avoid obstacle" % [start_pos, test_pos])
			return test_pos

	# If no clear position found, use original but print warning
	print("[QuestGiver] Warning: Could not find clear spawn position, using original: %s" % start_pos)
	return start_pos


## Check if a position is clear of obstacles
static func _is_position_clear(parent: Node, pos: Vector3) -> bool:
	# Check for static bodies (trees, rocks, walls) in the area
	# This is a simplified check - full physics query would need deferred execution
	if not parent.is_inside_tree():
		return true  # Can't check, assume clear

	var space_state: PhysicsDirectSpaceState3D = parent.get_world_3d().direct_space_state
	if not space_state:
		return true

	# Raycast down to check for ground
	var ray_params := PhysicsRayQueryParameters3D.new()
	ray_params.from = pos + Vector3(0, 2, 0)
	ray_params.to = pos + Vector3(0, -1, 0)
	ray_params.collision_mask = 1  # Static bodies only

	var result: Dictionary = space_state.intersect_ray(ray_params)
	if result.is_empty():
		return false  # No ground found

	# Check for obstacles at NPC height (capsule-like check using sphere)
	var sphere_params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = SPAWN_CHECK_RADIUS
	sphere_params.shape = sphere
	sphere_params.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0, 1, 0))
	sphere_params.collision_mask = 1  # Static bodies only

	var collisions: Array[Dictionary] = space_state.intersect_shape(sphere_params, 1)
	return collisions.is_empty()


## Add a beacon effect (vertical light beam) for visibility through trees
func _add_beacon_effect() -> void:
	# Create a subtle vertical light beam above the NPC
	var beacon := Node3D.new()
	beacon.name = "Beacon"
	add_child(beacon)

	# Light source at top of beacon
	var light := OmniLight3D.new()
	light.name = "BeaconLight"
	light.light_color = Color(0.4, 0.8, 1.0)  # Light blue
	light.light_energy = 0.5
	light.omni_range = 8.0
	light.position = Vector3(0, BEACON_HEIGHT, 0)
	beacon.add_child(light)

	# Vertical beam sprite (subtle glow)
	var beam := Sprite3D.new()
	beam.name = "BeaconBeam"
	beam.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	beam.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	beam.pixel_size = 0.02

	# Create a simple gradient texture for the beam
	var img := Image.create(4, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		var alpha: float = 1.0 - (float(y) / 32.0)
		alpha = alpha * alpha  # Fade faster at top
		for x in range(4):
			img.set_pixel(x, y, Color(0.4, 0.8, 1.0, alpha * 0.3))
	var beam_tex := ImageTexture.create_from_image(img)
	beam.texture = beam_tex

	beam.position = Vector3(0, BEACON_HEIGHT / 2.0, 0)
	beam.scale = Vector3(0.5, BEACON_HEIGHT * 2.0, 1.0)
	beam.modulate = Color(0.4, 0.8, 1.0, 0.4)
	beacon.add_child(beam)


## Pending quest to complete after dialogue
var _pending_quest_turnin: String = ""


## Show generic dialogue for quest turn-in using ConversationSystem scripted dialogue
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
		display_name,
		"Ah, you've completed '%s'. Well done! Here's your reward." % quest.title,
		[ConversationSystem.create_scripted_choice("Accept reward", 1)]
	))

	# Line 1: Reward given
	lines.append(ConversationSystem.create_scripted_line(
		display_name,
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
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Quest completed!")
			AudioManager.play_ui_confirm()
		_pending_quest_turnin = ""

		# Update state to check for next quest
		_update_quest_state()


## Take damage from attacks
func take_damage(amount: int, damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null) -> int:
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


## Get armor value (NPCs have minimal armor)
func get_armor_value() -> int:
	return 5


## Handle death
func _die(killer: Node = null) -> void:
	if _is_dead:
		return

	_is_dead = true

	print("[QuestGiver] %s has been killed" % display_name)

	# Report crime - killing an NPC is murder
	if killer and killer.is_in_group("player"):
		var crime_region: String = region_id if not region_id.is_empty() else "unknown"
		CrimeManager.report_crime(CrimeManager.CrimeType.MURDER, crime_region, [])

	# Close any open dialogue
	_close_dialogue()

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
	var effective_id: String = npc_id if not npc_id.is_empty() else name
	PlayerGPS.unregister_npc(effective_id)

	queue_free()


## Spawn a lootable corpse
func _spawn_corpse() -> void:
	var corpse: LootableCorpse = LootableCorpse.spawn_corpse(
		get_parent(),
		global_position,
		display_name,
		npc_id,
		5  # Level 5 - decent loot for named NPCs
	)

	# Add some gold and items
	corpse.gold = randi_range(10, 50)

	# Maybe add some common items
	if randf() < 0.5:
		corpse.add_item("health_potion", 1, Enums.ItemQuality.AVERAGE)
	if randf() < 0.3:
		corpse.add_item("bread", randi_range(1, 3), Enums.ItemQuality.AVERAGE)


## ============================================================================
## SHOP FUNCTIONALITY
## ============================================================================

## Setup shop inventory using LootTables
func _setup_shop_inventory() -> void:
	if not has_shop:
		return

	if not LootTables:
		push_warning("[QuestGiver] LootTables not available for shop inventory")
		return

	shop_inventory = LootTables.generate_shop_inventory(shop_tier, shop_type)
	print("[QuestGiver] %s shop initialized with %d items (type: %s, tier: %d)" % [
		display_name, shop_inventory.size(), shop_type, shop_tier
	])


## Open the shop UI (called by ConversationSystem when player selects TRADE topic)
func _open_shop_ui() -> void:
	if not has_shop:
		push_warning("[QuestGiver] %s has no shop to open" % display_name)
		return

	# Clean up existing shop UI if any
	if shop_ui and is_instance_valid(shop_ui):
		shop_ui.queue_free()

	# Create the UI
	shop_ui = Control.new()
	shop_ui.set_script(ShopUIScript)
	shop_ui.name = "ShopUI"

	# Pass merchant reference (shop_ui expects a 'merchant' property)
	shop_ui.set("merchant", self)

	# Add to scene tree via canvas layer
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

	# Open the UI
	if shop_ui.has_method("open"):
		shop_ui.open(self)

	print("[QuestGiver] %s opened shop UI" % display_name)


## Called when shop UI is closed
func _on_shop_ui_closed(canvas: CanvasLayer) -> void:
	# Exit menu mode and unpause
	GameManager.exit_menu()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Clean up canvas
	if canvas and is_instance_valid(canvas):
		canvas.queue_free()

	shop_ui = null
	print("[QuestGiver] %s closed shop UI" % display_name)


## ============================================================================
## SHOP PRICE CALCULATION METHODS (Required by ShopUI)
## ============================================================================

## Get Speech-based sell price modifier (player selling to merchant)
## Higher Speech = better sell prices
func get_speech_sell_modifier() -> float:
	var speech: int = 0
	var persuasion: int = 0
	var negotiation: int = 0
	if GameManager.player_data:
		speech = GameManager.player_data.get_effective_stat(Enums.Stat.SPEECH)
		persuasion = GameManager.player_data.get_skill(Enums.Skill.PERSUASION)
		negotiation = GameManager.player_data.get_skill(Enums.Skill.NEGOTIATION)

	# Base: 50% of value, +1% per 2 Speech points, +1% per Negotiation level
	# Max bonus: +25% from Speech (50 points) + 10% from Negotiation (10 levels) = 85% max
	var speech_bonus: float = minf(speech * 0.005, 0.25)
	var negotiation_bonus: float = negotiation * 0.01
	var persuasion_bonus: float = persuasion * 0.005
	return 0.5 + speech_bonus + negotiation_bonus + persuasion_bonus


## Get Speech-based buy price modifier (player buying from merchant)
## Higher Speech = lower buy prices
func get_speech_buy_modifier() -> float:
	var speech: int = 0
	var persuasion: int = 0
	var negotiation: int = 0
	if GameManager.player_data:
		speech = GameManager.player_data.get_effective_stat(Enums.Stat.SPEECH)
		persuasion = GameManager.player_data.get_skill(Enums.Skill.PERSUASION)
		negotiation = GameManager.player_data.get_skill(Enums.Skill.NEGOTIATION)

	# Base: 150% of value (50% markup), -1% per 2 Speech points, -1% per Negotiation level
	# Min: 100% (no markup) at very high Speech/Negotiation
	var speech_discount: float = minf(speech * 0.005, 0.25)
	var negotiation_discount: float = negotiation * 0.01
	var persuasion_discount: float = persuasion * 0.005
	return maxf(1.5 - speech_discount - negotiation_discount - persuasion_discount, 1.0)


## Get base sell price for an inventory item (before Speech modifier)
func get_sell_price(inventory_index: int) -> int:
	if inventory_index < 0 or inventory_index >= InventoryManager.inventory.size():
		return 0

	var inv_item: Dictionary = InventoryManager.inventory[inventory_index]
	var base_value: int = InventoryManager.get_item_value(inv_item.item_id, inv_item.quality)
	return base_value


## Get sell price with Speech skill modifier applied
func get_sell_price_with_speech(inventory_index: int) -> int:
	return int(get_sell_price(inventory_index) * get_speech_sell_modifier())


## Get buy price with Speech skill modifier applied
func get_buy_price_with_speech(shop_index: int) -> int:
	if shop_index < 0 or shop_index >= shop_inventory.size():
		return 0
	return int(shop_inventory[shop_index].price * get_speech_buy_modifier())
