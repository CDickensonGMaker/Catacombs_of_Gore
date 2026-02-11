## tharin_ironbeard.gd - Tharin Ironbeard, Logging Camp Master
## Dwarf NPC who serves as the player's boss at Elder Moor
## Secretly works for the king's intelligence network
## Triggers "The Letter" quest when player tries to leave town
class_name TharinIronbeard
extends StaticBody3D

## NPC identification
@export var npc_id: String = "tharin_ironbeard"
@export var display_name: String = "Tharin Ironbeard"

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
var quest_id: String = "the_letter"

## Wandering behavior
var wander_enabled: bool = true
var wander_radius: float = 6.0
var wander_speed: float = 1.2
var home_position: Vector3
var wander_target: Vector3
var wander_timer: float = 0.0
var wander_wait_time: float = 3.0
var is_waiting: bool = true

## Dialogue content
var dialogue_intro := "Ah, there ye are! Been lookin' for ye.\nGot somethin' important to discuss."
var dialogue_quest_offer := "Listen close now. I need ye to deliver\nthis sealed letter to my contact in Falkenhaften.\nDon't open it, don't lose it. This is important\nbusiness - royal business, if ye catch my meaning.\nThere'll be coin in it for ye when it's done."
var dialogue_quest_active := "Ye still here? Get that letter to\nFalkenhaften! My contact will be waitin'\nnear the south gate. Don't dawdle!"
var dialogue_quest_complete := "Good work, lad. Ye've proven yerself\nreliable. There may be more work for ye yet."
var dialogue_casual := "Keep up the good work around camp.\nWe've got quotas to meet!"

## Exit interception
var _player_near_exit: bool = false
var _exit_dialogue_shown: bool = false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npcs")
	add_to_group("quest_givers")

	home_position = position
	wander_target = position

	_create_visual()
	_create_interaction_area()
	_create_collision()
	_register_compass_poi()
	_register_with_world_data()

	# Connect to wilderness exit signals
	_setup_exit_detection()

	# Check if quest already given (from save)
	if QuestManager.is_quest_active(quest_id) or QuestManager.is_quest_completed(quest_id):
		has_given_quest = true


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
	_open_quest_dialogue()


## Interaction interface
func interact(_interactor: Node) -> void:
	_open_dialogue()


func get_interaction_prompt() -> String:
	if not has_given_quest:
		return "Talk to " + display_name + " [!]"
	elif QuestManager.is_quest_active(quest_id):
		return "Talk to " + display_name
	else:
		return "Talk to " + display_name


## Open standard dialogue
func _open_dialogue() -> void:
	if not has_given_quest:
		_open_quest_dialogue()
	elif QuestManager.is_quest_active(quest_id):
		_show_simple_dialogue(dialogue_quest_active)
	elif QuestManager.is_quest_complete(quest_id):
		_show_simple_dialogue(dialogue_quest_complete)
	else:
		_show_simple_dialogue(dialogue_casual)


## Open the quest offer dialogue
func _open_quest_dialogue() -> void:
	get_tree().paused = true
	GameManager.enter_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var dialogue_ui := _create_quest_dialogue_panel()

	var canvas := CanvasLayer.new()
	canvas.name = "TharinDialogueCanvas"
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	canvas.add_child(dialogue_ui)


## Create the quest dialogue panel
func _create_quest_dialogue_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -140
	panel.offset_bottom = 140
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1)
	style.border_color = Color(0.4, 0.3, 0.2)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# NPC Name
	var name_label := Label.new()
	name_label.text = display_name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	# Dialogue text
	var text_label := Label.new()
	text_label.text = dialogue_quest_offer
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	vbox.add_child(text_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)

	# Accept button
	var accept_btn := Button.new()
	accept_btn.text = "I'll deliver the letter."
	accept_btn.custom_minimum_size = Vector2(200, 35)
	accept_btn.pressed.connect(_on_accept_quest.bind(panel))
	accept_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(accept_btn)
	vbox.add_child(accept_btn)

	# Decline button (just closes dialogue, can talk again)
	var decline_btn := Button.new()
	decline_btn.text = "I need to prepare first."
	decline_btn.custom_minimum_size = Vector2(200, 35)
	decline_btn.pressed.connect(_on_decline_quest.bind(panel))
	decline_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(decline_btn)
	vbox.add_child(decline_btn)

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


func _on_accept_quest(panel: Control) -> void:
	has_given_quest = true

	# Start the quest
	if QuestManager.start_quest(quest_id):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Quest Started: The Letter")
		AudioManager.play_ui_confirm()

	# Give player the letter item
	InventoryManager.add_item("tharins_letter", 1)

	_close_dialogue(panel)

	# Resume wandering
	wander_enabled = true


func _on_decline_quest(panel: Control) -> void:
	_close_dialogue(panel)
	_exit_dialogue_shown = false  # Allow showing again
	wander_enabled = true


func _close_dialogue(panel: Control) -> void:
	var canvas := panel.get_parent()
	panel.queue_free()
	if canvas:
		canvas.queue_free()

	get_tree().paused = false
	GameManager.exit_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Show simple dialogue (no choices)
func _show_simple_dialogue(text: String) -> void:
	get_tree().paused = true
	GameManager.enter_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var panel := PanelContainer.new()
	panel.name = "SimpleDialogue"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -100
	panel.offset_bottom = 100
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1)
	style.border_color = Color(0.4, 0.3, 0.2)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = display_name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	vbox.add_child(name_label)

	var text_label := Label.new()
	text_label.text = text
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	vbox.add_child(text_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "Farewell."
	close_btn.custom_minimum_size = Vector2(150, 35)
	close_btn.pressed.connect(_close_dialogue.bind(panel))
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(close_btn)
	vbox.add_child(close_btn)

	var canvas := CanvasLayer.new()
	canvas.name = "SimpleDialogueCanvas"
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	canvas.add_child(panel)


## Register as compass POI
func _register_compass_poi() -> void:
	add_to_group("compass_poi")
	set_meta("poi_id", "npc_%d" % get_instance_id())
	set_meta("poi_name", display_name)
	set_meta("poi_color", Color(0.9, 0.7, 0.3))  # Gold for important NPC


## Register with WorldData
func _register_with_world_data() -> void:
	var hex: Vector2i = WorldData.world_to_axial(global_position)
	WorldData.register_npc(npc_id, hex, "village_elder_moor", npc_type)


func _exit_tree() -> void:
	WorldData.unregister_npc(npc_id)
