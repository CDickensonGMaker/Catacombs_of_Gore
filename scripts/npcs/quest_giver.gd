## quest_giver.gd - NPC that gives and completes quests
## Supports multiple quests - offers the next available quest after completing previous ones
class_name QuestGiver
extends StaticBody3D

@export var npc_id: String = "quest_giver_01"
@export var display_name: String = "Mysterious Stranger"

## NPC type and region for central turn-in system (NPC_TYPE_IN_REGION)
var npc_type: String = "quest_giver"  # Can be overridden for specific NPC types
var region_id: String = ""  # Set by zone when spawned

## List of quests this NPC can offer (in order of priority)
## If empty, will auto-detect available quests from QuestManager
@export var quest_ids: Array[String] = ["knight_intro", "road_to_dalhurst", "prove_yourself", "scout_the_cave", "thin_the_herd", "gather_intel", "destroy_goblin_totem"]

## Optional pre-quest dialogue (shown before quest offer when quest is NOT_STARTED)
@export var dialogue_data: DialogueData

## Sprite texture for billboard display (PS1-style)
## If not set, defaults to man_civilian sprite
@export var sprite_texture: Texture2D

## Current quest being discussed (determined dynamically)
var current_quest_id: String = ""

## Quest state tracking
enum QuestState { NO_QUESTS, NOT_STARTED, ACTIVE, READY_TO_COMPLETE, COMPLETED_ALL }
var quest_state: QuestState = QuestState.NO_QUESTS

## Visual components
var billboard: BillboardSprite
var interaction_area: Area3D

## Sprite configuration
var sprite_h_frames: int = 8
var sprite_v_frames: int = 2
var sprite_pixel_size: float = 0.0384  # Match man_civilian size

## Dialogue UI reference
var dialogue_ui: Control = null

## Track if intro dialogue has been shown (for optional pre-quest dialogue)
var _intro_dialogue_shown: bool = false

## Dialogue content per quest (keyed by quest_id)
## Falls back to generic dialogue if quest not found
var quest_dialogues := {
	"knight_intro": {
		"offer": "Hail, traveler! The road to Dalhurst has grown\ndangerous. Bandits prey on anyone who passes.\nClear out 5 of these rogues to make the road safe.",
		"active": "The bandits still prowl the wilderness.\nReturn when you've dealt with them.",
		"complete": "Well done! The road is safer thanks to you.\nI have another task - travel to Dalhurst and meet\nmy contact there. He has vital information."
	},
	"road_to_dalhurst": {
		"offer": "My contact waits in Dalhurst, near the south gate.\nSeek him out - he has news of a growing threat\nthat concerns us all.",
		"active": "Have you spoken with my contact in Dalhurst?\nHe awaits you near the city's south gate.",
		"complete": "You've met with my contact. Good.\nThe information he shared is troubling indeed."
	},
	"prove_yourself": {
		"offer": "Words are wind. Show me your skill with a blade.\nSlay 5 goblins in the open world and return.\nThen I'll know you're ready for greater challenges.",
		"active": "The goblins still roam freely.\nProve your worth in battle.",
		"complete": "Impressive! You handle yourself well.\nPerhaps you are the ally I've been seeking."
	},
	"scout_the_cave": {
		"offer": "Intelligence reports speak of a cave where goblins gather.\nFind this cave and report back its location.\nDo not engage - just scout.",
		"active": "Have you located the goblin cave?\nWe need to know what we're dealing with.",
		"complete": "So the cave exists. This confirms my suspicions.\nThe goblins are more organized than we thought."
	},
	"thin_the_herd": {
		"offer": "Before we can strike at the heart of their lair,\nwe must weaken their numbers. Slay 10 goblins\nto thin their ranks before our assault.",
		"active": "Keep culling their numbers.\nEvery goblin slain makes our task easier.",
		"complete": "Their forces are weakened.\nNow we can proceed with the next phase."
	},
	"gather_intel": {
		"offer": "I need proof of goblin leadership - military organization.\nTheir commanders carry war horns of bone and brass.\nBring me one of these horns.",
		"active": "Have you found a war horn?\nIt will prove they're being coordinated.",
		"complete": "This horn... I recognize the markings.\nThey serve something darker within that cave."
	},
	"destroy_goblin_totem": {
		"offer": "The time has come. Deep in the cave stands a dark totem\nthat spawns endless goblins. Destroy it\nand bring me the corrupted shard as proof.",
		"active": "The totem still stands. Destroy it and bring me\nthe corrupted shard that remains.",
		"complete": "You have the shard! I can feel its dark energy.\nThe totem is truly destroyed. Here is your reward."
	},
	"dungeon_clear": {
		"offer": "These catacombs are infested with undead.\nI've been trapped here, unable to escape.\nSlay 3 of these wretched creatures and I'll reward you.",
		"active": "The undead still lurk in these halls.\nI can hear their bones rattling...",
		"complete": "The air feels lighter already.\nTake this - you've earned it."
	},
	"journey_to_kazandun": {
		"offer": "You made it. Good. I have troubling news.\nStrange activity has been reported on the mountain road\ntoward Kazan-Dun. Travel south and investigate.",
		"active": "The mountain road awaits. Head south toward\nKazan-Dun and see what stirs in those peaks.",
		"complete": "You've made it to Kazan-Dun? The dwarves there\nmay have more information about these disturbances."
	},
	"willow_dale_investigation": {
		"offer": "Please, you must help! Strange lights have been seen\nat the old Willow Dale ruins northwest of the city.\nTravelers have gone missing. Someone must investigate!",
		"active": "Have you ventured to Willow Dale yet?\nThe ruins are to the northwest. Be careful!",
		"complete": "You survived! The ruins were dangerous?\nHere, take this reward. You've earned it."
	}
}

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

## Create the visual representation (billboard sprite - PS1 style)
func _create_visual() -> void:
	# Load fallback texture if none assigned
	var tex: Texture2D = sprite_texture
	if not tex:
		tex = load("res://Sprite folders grab bag/man_civilian.png") as Texture2D

	if not tex:
		push_warning("QuestGiver: No sprite texture available for " + display_name)
		return

	billboard = BillboardSprite.new()
	billboard.sprite_sheet = tex
	billboard.h_frames = sprite_h_frames
	billboard.v_frames = sprite_v_frames
	billboard.pixel_size = sprite_pixel_size
	billboard.idle_frames = sprite_h_frames
	billboard.walk_frames = sprite_h_frames
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
	_update_quest_state()
	# Notify quest system that player talked to this NPC (for "talk" objectives)
	QuestManager.on_npc_talked(npc_id)

	# Check if we should show optional intro dialogue first
	if dialogue_data and quest_state == QuestState.NOT_STARTED and not _intro_dialogue_shown:
		_open_intro_dialogue()
	else:
		_open_dialogue()

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

	WorldData.register_npc(effective_id, hex, zone_id, npc_type)
	print("[QuestGiver] Registered with WorldData: npc_id='%s', hex=%s, zone='%s', type='%s'" % [
		effective_id, hex, zone_id, npc_type
	])


## Unregister from WorldData when removed from scene
func _exit_tree() -> void:
	var effective_id: String = npc_id if not npc_id.is_empty() else name
	WorldData.unregister_npc(effective_id)


## Constants for spawn collision avoidance
const SPAWN_CHECK_RADIUS := 1.5  # Radius to check for obstacles
const SPAWN_MAX_ATTEMPTS := 8    # Max attempts to find clear ground
const SPAWN_OFFSET_DISTANCE := 3.0  # How far to offset if blocked
const BEACON_HEIGHT := 4.0  # Height of beacon effect above NPC


## Static factory method
## quest_list: Optional array of quest IDs this NPC can give.
## is_talk_target: If true, this NPC gives no quests (just a "talk to" objective target).
static func spawn_quest_giver(parent: Node, pos: Vector3, npc_name: String = "Mysterious Stranger", id: String = "", custom_sprite: Texture2D = null, h_frames: int = 8, v_frames: int = 2, quest_list: Array[String] = [], is_talk_target: bool = false) -> QuestGiver:
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
	# Set custom sprite before adding to tree (before _ready)
	if custom_sprite:
		npc.sprite_texture = custom_sprite
		npc.sprite_h_frames = h_frames
		npc.sprite_v_frames = v_frames

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
