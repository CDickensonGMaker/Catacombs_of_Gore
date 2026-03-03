## arena_master.gd - Arena Master NPC who manages tournament entry
## Gormund the Pitmaster - runs the Bloodsand Arena tournaments
class_name ArenaMaster
extends StaticBody3D

@export var npc_id: String = "arena_master_bloodsand"
@export var display_name: String = "Gormund the Pitmaster"

## Alias for ConversationSystem compatibility
var npc_name: String:
	get: return display_name
	set(value): display_name = value

## NPC type and region for NPC registration
var npc_type: String = "arena_master"
@export var region_id: String = "bloodsand_arena"

## Faction affiliation
@export var faction_id: String = "human_empire"

## Visual components
var billboard: BillboardSprite
var interaction_area: Area3D

## Sprite configuration (large intimidating figure)
var sprite_h_frames: int = 8
var sprite_v_frames: int = 2
var sprite_pixel_size: float = 0.045  # Slightly larger than normal

## Health and combat
var max_health: int = 200
var current_health: int = 200
var _is_dead: bool = false

## Guard against multiple interact() calls on same frame
var _is_interacting: bool = false

## Pending tournament to start after dialogue
var _pending_tournament_id: String = ""


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npcs")
	add_to_group("arena_masters")
	add_to_group("attackable")

	current_health = max_health

	# Create visual components
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
	_register_with_player_gps()

	# Connect to TournamentManager signals
	if TournamentManager:
		TournamentManager.wave_complete.connect(_on_wave_complete)
		TournamentManager.tournament_won.connect(_on_tournament_won)
		TournamentManager.tournament_lost.connect(_on_tournament_lost)


## Create the visual representation (billboard sprite)
func _create_visual() -> void:
	# Load a burly gladiator/pitmaster sprite
	var tex: Texture2D = load("res://assets/sprites/npcs/civilians/man_civilian.png") as Texture2D
	if not tex:
		push_warning("[ArenaMaster] No sprite texture available")
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

	# Give him a reddish tint (blood-stained armor look)
	if billboard.sprite:
		billboard.sprite.modulate = Color(1.0, 0.85, 0.8)


## Create interaction area
func _create_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 3.0  # Larger interaction range
	collision.shape = shape
	collision.position.y = 1.0
	interaction_area.add_child(collision)

	add_child(interaction_area)


## Create collision shape
func _create_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4  # Larger collision
	shape.height = 2.0
	collision.shape = shape
	collision.position.y = 1.0
	add_child(collision)


## Register as compass POI
func _register_compass_poi() -> void:
	add_to_group("compass_poi")
	set_meta("poi_id", "npc_%d" % get_instance_id())
	set_meta("poi_name", display_name)
	set_meta("poi_color", Color(0.9, 0.4, 0.2))  # Orange-red for arena


## Register with PlayerGPS
func _register_with_player_gps() -> void:
	var cell: Vector2i = WorldGrid.world_to_cell(global_position)
	PlayerGPS.register_npc(self, npc_id, npc_type, region_id)
	print("[ArenaMaster] Registered with PlayerGPS: %s at cell %s" % [npc_id, cell])


## Interaction interface
func interact(_interactor: Node) -> void:
	if _is_interacting:
		return
	_is_interacting = true

	if ConversationSystem.is_active or ConversationSystem.is_scripted_mode:
		_is_interacting = false
		return

	# Show appropriate dialogue based on tournament state
	if TournamentManager.is_tournament_active:
		# Player is mid-tournament, show status
		_show_tournament_status_dialogue()
	else:
		# Show tournament entry dialogue
		_show_tournament_dialogue()

	_is_interacting = false


func get_interaction_prompt() -> String:
	if TournamentManager.is_tournament_active:
		return "Press [E] to talk to " + display_name + " [Tournament Active]"
	return "Press [E] to talk to " + display_name + " [Arena]"


## Show tournament entry dialogue
func _show_tournament_dialogue() -> void:
	var lines: Array = []

	# Check if player was sent by Varn (meet_the_arena_master quest)
	var sent_by_varn: bool = QuestManager.is_quest_active("meet_the_arena_master")
	if sent_by_varn:
		# Complete the quest objective by notifying QuestManager
		QuestManager.on_npc_talked("arena_master_bloodsand")

	# Greeting based on fame
	var fame: int = TournamentManager.arena_fame
	var fame_title: String = TournamentManager.get_fame_title()
	var greeting: String

	if sent_by_varn and fame == 0:
		# Special greeting for players sent by Varn
		greeting = "Ah, Varn sent you, did he? That old scarred warrior has a good eye for potential fighters. Welcome to the Bloodsand Arena! Here, glory is won through blood and steel. Think you've got what it takes to survive 5 waves of combat?"
	elif fame == 0:
		greeting = "Fresh meat! Welcome to the Bloodsand Arena, stranger. Here, glory is won through blood and steel. Think you've got what it takes to survive 5 waves of combat?"
	elif fame < 75:
		greeting = "Back for more, %s? Good. The crowd loves a returning fighter. Ready for another 5 waves?" % fame_title
	elif fame < 150:
		greeting = "The %s returns! The crowd roars for you already. Shall we begin the tournament?" % fame_title
	else:
		greeting = "%s! Your name echoes through these halls. The arena trembles at your return!" % fame_title

	# Add tournament info
	greeting += "\n\nThe tournament is 5 waves of increasingly deadly combat. You cannot change equipment while fighting. Death means starting over from wave 1."

	# Line 0: Greeting with tournament options
	lines.append(ConversationSystem.create_scripted_line(
		display_name,
		greeting,
		[
			ConversationSystem.create_scripted_choice("Enter the arena!", 1),
			ConversationSystem.create_scripted_choice("Tell me about the waves.", 2),
			ConversationSystem.create_scripted_choice("Nevermind.", -1)
		]
	))

	# Line 1: Confirm entry
	lines.append(ConversationSystem.create_scripted_line(
		display_name,
		"Once you step into the arena, your equipment will be locked. No switching weapons, armor, or spells until the tournament ends or you leave between waves.\n\nGold rewards increase with each wave. Are you ready?",
		[
			ConversationSystem.create_scripted_choice("Let's do this!", -1),
			ConversationSystem.create_scripted_choice("I need to prepare first.", -1)
		]
	))
	lines[1]["_start_tournament"] = true

	# Line 2: Wave info
	lines.append(ConversationSystem.create_scripted_line(
		display_name,
		"Wave 1: Two novice gladiators - easy warm-up.\nWave 2: Three swordsmen and two archers.\nWave 3: Wolves, soldiers, and archers together.\nWave 4: Four abominations - twisted horrors.\nWave 5: ALL previous waves at once!\n\nBetween waves, you can continue or leave with your winnings.",
		[
			ConversationSystem.create_scripted_choice("I'm ready!", 1),
			ConversationSystem.create_scripted_choice("I need more time.", -1)
		]
	))

	# Track which line we're on for the callback
	if not ConversationSystem.scripted_line_shown.is_connected(_on_entry_line_shown):
		ConversationSystem.scripted_line_shown.connect(_on_entry_line_shown)

	_pending_start_tournament = false
	ConversationSystem.start_scripted_dialogue(lines, _on_entry_dialogue_ended)


## Track if we should start tournament
var _pending_start_tournament: bool = false


## Called when a scripted line is shown during entry dialogue
func _on_entry_line_shown(line: Dictionary, _index: int) -> void:
	if line.has("_start_tournament"):
		_pending_start_tournament = true
	else:
		_pending_start_tournament = false


## Called when entry dialogue ends
func _on_entry_dialogue_ended() -> void:
	if ConversationSystem.scripted_line_shown.is_connected(_on_entry_line_shown):
		ConversationSystem.scripted_line_shown.disconnect(_on_entry_line_shown)

	if _pending_start_tournament:
		_start_tournament_after_dialogue()
		_pending_start_tournament = false


## Start tournament after dialogue closes
func _start_tournament_after_dialogue() -> void:
	# Delay slightly to let dialogue fully close
	get_tree().create_timer(0.5).timeout.connect(func():
		if TournamentManager.start_tournament():
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Tournament started! Wave 1 beginning...")
			AudioManager.play_ui_confirm()
	)


## Show tournament status dialogue (when already in tournament)
func _show_tournament_status_dialogue() -> void:
	var wave: int = TournamentManager.get_current_wave()
	var total: int = TournamentManager.get_total_waves()

	var lines: Array = []
	lines.append(ConversationSystem.create_scripted_line(
		display_name,
		"You're in wave %d of %d. Get back to fighting! The crowd grows restless." % [wave, total],
		[
			ConversationSystem.create_scripted_choice("Right, back to it!", -1)
		]
	))

	ConversationSystem.start_scripted_dialogue(lines)


## Called when a wave is complete - show continue/leave dialogue
func _on_wave_complete(wave_number: int, gold_earned: int) -> void:
	# Small delay before showing dialogue
	get_tree().create_timer(1.5).timeout.connect(func():
		_show_between_wave_dialogue(wave_number, gold_earned)
	)


## Show the between-wave dialogue popup
func _show_between_wave_dialogue(wave_number: int, gold_earned: int) -> void:
	var total_waves: int = TournamentManager.get_total_waves()
	var total_gold: int = TournamentManager.total_gold_earned

	var lines: Array = []

	if wave_number >= total_waves:
		# Tournament complete - this shouldn't happen here, handled by tournament_won
		return

	var next_wave: int = wave_number + 1
	var next_wave_desc: String = _get_wave_description(next_wave)

	lines.append(ConversationSystem.create_scripted_line(
		display_name,
		"Wave %d complete! You earned %d gold!\n\nTotal winnings so far: %d gold\n\nNext up - Wave %d: %s\n\nWhat will you do?" % [
			wave_number, gold_earned, total_gold, next_wave, next_wave_desc
		],
		[
			ConversationSystem.create_scripted_choice("Continue to wave %d!" % next_wave, 1),
			ConversationSystem.create_scripted_choice("Leave with my winnings.", 2)
		]
	))

	# Line 1: Continue
	lines.append(ConversationSystem.create_scripted_line(
		display_name,
		"The crowd cheers! Prepare yourself for wave %d!" % next_wave,
		[
			ConversationSystem.create_scripted_choice("For glory!", -1)
		]
	))
	lines[1]["_continue_tournament"] = true

	# Line 2: Leave
	lines.append(ConversationSystem.create_scripted_line(
		display_name,
		"A wise choice, perhaps. You leave with %d gold and your life. Return when you're ready for more." % total_gold,
		[
			ConversationSystem.create_scripted_choice("Until next time.", -1)
		]
	))
	lines[2]["_leave_tournament"] = true

	if not ConversationSystem.scripted_line_shown.is_connected(_on_between_wave_line_shown):
		ConversationSystem.scripted_line_shown.connect(_on_between_wave_line_shown)

	_pending_continue = false
	_pending_leave = false
	ConversationSystem.start_scripted_dialogue(lines, _on_between_wave_dialogue_ended)


var _pending_continue: bool = false
var _pending_leave: bool = false


func _on_between_wave_line_shown(line: Dictionary, _index: int) -> void:
	_pending_continue = line.has("_continue_tournament")
	_pending_leave = line.has("_leave_tournament")


func _on_between_wave_dialogue_ended() -> void:
	if ConversationSystem.scripted_line_shown.is_connected(_on_between_wave_line_shown):
		ConversationSystem.scripted_line_shown.disconnect(_on_between_wave_line_shown)

	if _pending_continue:
		# Start next wave after short delay
		get_tree().create_timer(0.5).timeout.connect(func():
			TournamentManager.start_next_wave()
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_notification"):
				var wave: int = TournamentManager.get_current_wave()
				hud.show_notification("Wave %d beginning!" % wave)
		)
	elif _pending_leave:
		# Leave tournament
		TournamentManager.leave_tournament()
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("You have left the tournament.")

	_pending_continue = false
	_pending_leave = false


## Get description for a wave number
func _get_wave_description(wave: int) -> String:
	match wave:
		1:
			return "2 novice gladiators"
		2:
			return "3 swordsmen + 2 archers"
		3:
			return "2 wolves + 2 soldiers + 3 archers"
		4:
			return "4 abominations"
		5:
			return "ALL previous waves combined!"
		_:
			return "Unknown challenge"


## Called when tournament is won
func _on_tournament_won(total_gold: int) -> void:
	get_tree().create_timer(1.5).timeout.connect(func():
		_show_victory_dialogue(total_gold)
	)


## Show victory dialogue
func _show_victory_dialogue(total_gold: int) -> void:
	var lines: Array = []
	lines.append(ConversationSystem.create_scripted_line(
		display_name,
		"INCREDIBLE! You have conquered all 5 waves!\n\nTotal winnings: %d gold\n\nThe crowd chants your name! You are a true champion of the Bloodsand Arena!" % total_gold,
		[
			ConversationSystem.create_scripted_choice("Victory is mine!", -1)
		]
	))

	ConversationSystem.start_scripted_dialogue(lines)


## Called when tournament is lost
func _on_tournament_lost() -> void:
	# Show defeat notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Defeated! Tournament over.")


## Take damage from attacks
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
			if billboard and billboard.sprite and not _is_dead:
				billboard.sprite.modulate = original_color
		)

	if AudioManager:
		AudioManager.play_sfx("player_hit")

	if current_health <= 0:
		_die(attacker)

	return actual_damage


func is_dead() -> bool:
	return _is_dead


func get_armor_value() -> int:
	return 25  # Well armored


## Handle death
func _die(killer: Node = null) -> void:
	if _is_dead:
		return

	_is_dead = true
	print("[ArenaMaster] %s has been killed" % display_name)

	# Report crime
	if killer and killer.is_in_group("player"):
		CrimeManager.report_crime(CrimeManager.CrimeType.MURDER, region_id, [])

	_spawn_corpse()
	CombatManager.entity_killed.emit(self, killer)

	if AudioManager:
		AudioManager.play_sfx("enemy_death")

	remove_from_group("interactable")
	remove_from_group("npcs")
	remove_from_group("arena_masters")
	remove_from_group("attackable")
	remove_from_group("compass_poi")

	PlayerGPS.unregister_npc(npc_id)
	queue_free()


## Spawn a lootable corpse
func _spawn_corpse() -> void:
	var corpse: LootableCorpse = LootableCorpse.spawn_corpse(
		get_parent(),
		global_position,
		display_name,
		npc_id,
		15  # Higher level for tougher NPC
	)

	corpse.gold = randi_range(100, 300)

	if randf() < 0.7:
		corpse.add_item("health_potion", 2, Enums.ItemQuality.AVERAGE)
	if randf() < 0.5:
		corpse.add_item("strength_elixir", 1, Enums.ItemQuality.ABOVE_AVERAGE)


func _exit_tree() -> void:
	PlayerGPS.unregister_npc(npc_id)

	# Disconnect signals
	if TournamentManager:
		if TournamentManager.wave_complete.is_connected(_on_wave_complete):
			TournamentManager.wave_complete.disconnect(_on_wave_complete)
		if TournamentManager.tournament_won.is_connected(_on_tournament_won):
			TournamentManager.tournament_won.disconnect(_on_tournament_won)
		if TournamentManager.tournament_lost.is_connected(_on_tournament_lost):
			TournamentManager.tournament_lost.disconnect(_on_tournament_lost)
