## save_manager.gd - Handles saving and loading game state with versioned structure
extends Node

const SaveDataClass = preload("res://scripts/data/save_data.gd")

signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_failed(slot: int, error: String)
signal load_failed(slot: int, error: String)

const SAVE_DIR := "user://saves/"
const SAVE_FILE_PREFIX := "save_"
const SAVE_FILE_EXT := ".sav"
const DUNGEON_SEEDS_FILE := "user://saves/dungeon_seeds.cache"
const MAX_SAVE_SLOTS := 10

## Current save format version - increment when structure changes
const SAVE_VERSION := 1

## Currently loaded save slot
var current_slot: int = -1

## Autosave settings - dual save system
const AUTOSAVE_PERIODIC_SLOT: int = 8  # "30 Second Auto Save"
const AUTOSAVE_EXIT_SLOT: int = 9      # "Auto Save Menu Close"
var autosave_enabled: bool = true
var autosave_interval: float = 30.0   # 30 seconds
var autosave_timer: float = 0.0

## Play time tracking
var session_start_time: float = 0.0
var total_play_time: float = 0.0
var rest_count: int = 0
var death_count: int = 0

## World state tracking
var discovered_locations: Dictionary = {}
var killed_enemies: Dictionary = {}
var dropped_items: Dictionary = {}
var world_flags: Dictionary = {}
var opened_containers: Dictionary = {}
var unlocked_shortcuts: Dictionary = {}
var current_zone_id: String = ""
var current_zone_name: String = ""

## Persistent chest contents (town storage chests)
## Format: { "chest_id": [ {item_id, quantity, quality}, ... ] }
var persistent_chest_contents: Dictionary = {}

## Dungeon seeds for procedural generation persistence
## Format: { "zone_id": seed_int }
var dungeon_seeds: Dictionary = {}

## Pending data to apply after scene load
var pending_known_spells: Array = []

func _ready() -> void:
	_ensure_save_directory()
	_load_dungeon_seeds_cache()
	session_start_time = Time.get_unix_time_from_system()
	# Connect to scene load completed to apply pending data
	if SceneManager:
		SceneManager.scene_load_completed.connect(_on_scene_load_completed)
	# Setup quick save/load keybindings
	_setup_save_keybindings()
	# Enable exit notification handling
	get_tree().set_auto_accept_quit(false)


## Handle window close / quit notifications
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Auto-save on exit (with error protection)
		_safe_autosave_on_exit()
		# Allow quit
		if get_tree():
			get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Mobile back button - also autosave
		_safe_autosave_on_exit()


## Safely attempt autosave, catching any errors
func _safe_autosave_on_exit() -> void:
	# Wrap in error handling to prevent crashes on exit
	if not get_tree():
		return
	if not is_instance_valid(self):
		return

	# Try to autosave, but don't crash if it fails
	autosave_on_exit()

func _setup_save_keybindings() -> void:
	# Add quick_save action (F5)
	if not InputMap.has_action("quick_save"):
		InputMap.add_action("quick_save")
		var f5_event := InputEventKey.new()
		f5_event.physical_keycode = KEY_F5
		InputMap.action_add_event("quick_save", f5_event)

	# Add quick_load action (F9)
	if not InputMap.has_action("quick_load"):
		InputMap.add_action("quick_load")
		var f9_event := InputEventKey.new()
		f9_event.physical_keycode = KEY_F9
		InputMap.action_add_event("quick_load", f9_event)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		_do_quick_save()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		_do_quick_load()
		get_viewport().set_input_as_handled()

func _do_quick_save() -> void:
	# Prevent saving during scene transitions to avoid corrupted state
	if SceneManager and SceneManager.is_loading:
		_show_save_notification("Cannot save during scene transition")
		return

	if quick_save():
		_show_save_notification("Game Saved")
	else:
		_show_save_notification("Save Failed!")

func _do_quick_load() -> void:
	if save_exists(0):
		# Get save info BEFORE loading to get scene path
		var save_info := get_save_info(0)
		var scene_path: String = save_info.get("current_scene", "")

		if quick_load():
			_show_save_notification("Game Loaded")
			# Change to the saved scene
			if not scene_path.is_empty():
				SceneManager.change_scene(scene_path)
			else:
				push_warning("[SaveManager] Quick load has no current_scene")
		else:
			_show_save_notification("Load Failed!")
	else:
		_show_save_notification("No Save Found")

func _show_save_notification(message: String) -> void:
	# Try to show via HUD
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(message)

func _process(delta: float) -> void:
	if autosave_enabled:
		autosave_timer += delta
		if autosave_timer >= autosave_interval:
			autosave_timer = 0.0
			_do_autosave()

## Perform periodic autosave (every 30 seconds)
func _do_autosave() -> void:
	# Only autosave if player exists (in gameplay, not menus)
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Don't autosave if player is dead - prevents save loop on death
	if player.has_method("is_dead") and player.is_dead():
		return

	# Also check GameManager death state
	if GameManager and GameManager.player_data:
		if GameManager.player_data.current_hp <= 0:
			return

	# Don't autosave if game is paused (in menu)
	if get_tree().paused:
		return

	# Don't autosave during scene transitions
	if SceneManager and SceneManager.is_loading:
		return

	if save_game(AUTOSAVE_PERIODIC_SLOT):
		_show_save_notification("30s Autosave")


## Perform exit/menu close autosave - call when game is closing or pausing
func autosave_on_exit() -> void:
	# Safety check for tree validity
	if not get_tree():
		return

	# Only save if player exists
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Don't save if player is dead
	if player.has_method("is_dead") and player.is_dead():
		return

	if GameManager and GameManager.player_data:
		if GameManager.player_data.current_hp <= 0:
			return

	# Don't save during scene transitions
	if SceneManager and SceneManager.is_loading:
		return

	if save_game(AUTOSAVE_EXIT_SLOT):
		print("[SaveManager] Exit autosave completed")

## Ensure save directory exists
func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

## Get save file path for slot
func _get_save_path(slot: int) -> String:
	return SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT

## Save the game to a slot
func save_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		save_failed.emit(slot, "Invalid slot number")
		return false

	var save_data = _collect_save_data()

	var json_string: String = JSON.stringify(save_data.to_dict(), "\t")
	var file := FileAccess.open(_get_save_path(slot), FileAccess.WRITE)

	if not file:
		var error := FileAccess.get_open_error()
		save_failed.emit(slot, "Failed to open file: " + str(error))
		return false

	file.store_string(json_string)
	file.close()

	current_slot = slot
	save_completed.emit(slot)
	return true

## Load a game from a slot
func load_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		load_failed.emit(slot, "Invalid slot number")
		return false

	var path := _get_save_path(slot)
	if not FileAccess.file_exists(path):
		load_failed.emit(slot, "Save file not found")
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		var error := FileAccess.get_open_error()
		load_failed.emit(slot, "Failed to open file: " + str(error))
		return false

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		load_failed.emit(slot, "Failed to parse save data")
		return false

	var raw_data: Dictionary = json.data

	# Check version and migrate if needed
	var version: int = raw_data.get("version", 0)
	if version < SAVE_VERSION:
		raw_data = _migrate_save_data(raw_data, version)

	var save_data = SaveDataClass.new()
	save_data.from_dict(raw_data)

	if not save_data.is_valid():
		load_failed.emit(slot, "Invalid save data structure")
		return false

	_apply_save_data(save_data)

	current_slot = slot
	session_start_time = Time.get_unix_time_from_system()
	load_completed.emit(slot)
	return true

## Delete a save slot
func delete_save(slot: int) -> bool:
	var path := _get_save_path(slot)
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		return err == OK
	return true

## Check if a save slot exists
func save_exists(slot: int) -> bool:
	return FileAccess.file_exists(_get_save_path(slot))

## Get save metadata for a slot (for save select screen)
func get_save_info(slot: int) -> Dictionary:
	if not save_exists(slot):
		return {}

	var file := FileAccess.open(_get_save_path(slot), FileAccess.READ)
	if not file:
		return {}

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		return {}

	var raw_data: Dictionary = json.data
	var save_data = SaveDataClass.new()
	save_data.from_dict(raw_data)

	return save_data.get_display_info()

## Get all save slot infos
func get_all_save_infos() -> Array[Dictionary]:
	var infos: Array[Dictionary] = []
	for i in range(MAX_SAVE_SLOTS):
		if save_exists(i):
			var info := get_save_info(i)
			info["slot"] = i
			# Label autosave slots
			if i == AUTOSAVE_PERIODIC_SLOT:
				info["slot_name"] = "30 Second Auto Save"
			elif i == AUTOSAVE_EXIT_SLOT:
				info["slot_name"] = "Auto Save Menu Close"
			else:
				info["slot_name"] = "Save Slot %d" % (i + 1)
			infos.append(info)
		else:
			var empty_info: Dictionary = {"slot": i, "empty": true}
			if i == AUTOSAVE_PERIODIC_SLOT:
				empty_info["slot_name"] = "30 Second Auto Save"
			elif i == AUTOSAVE_EXIT_SLOT:
				empty_info["slot_name"] = "Auto Save Menu Close"
			else:
				empty_info["slot_name"] = "Save Slot %d" % (i + 1)
			infos.append(empty_info)
	return infos

## Collect all data to save
func _collect_save_data():
	var save_data = SaveDataClass.new()

	# Metadata
	save_data.version = SAVE_VERSION
	save_data.timestamp = Time.get_unix_time_from_system()
	save_data.datetime_string = Time.get_datetime_string_from_system()
	save_data.game_version = ProjectSettings.get_setting("application/config/version", "1.0.0")

	# Player data
	if save_data.player:
		_collect_player_data(save_data.player)

	# Inventory data
	if save_data.inventory:
		_collect_inventory_data(save_data.inventory)

	# World data
	if save_data.world:
		_collect_world_data(save_data.world)

	# Quest data
	if save_data.quests:
		_collect_quest_data(save_data.quests)

	# Time data
	if save_data.time_data:
		_collect_time_data(save_data.time_data)

	# Audio settings
	save_data.audio_settings = AudioManager.get_settings()

	# Crime/bounty data
	if save_data.crime_data:
		_collect_crime_data(save_data.crime_data)

	# Dialogue flags data
	if save_data.dialogue_data:
		_collect_dialogue_data(save_data.dialogue_data)

	# Conversation memory data
	if save_data.conversation_data:
		_collect_conversation_data(save_data.conversation_data)

	# Errand quest data
	if save_data.errand_data:
		_collect_errand_data(save_data.errand_data)

	# World manager (location discovery) data
	if save_data.world_manager_data:
		_collect_world_manager_data(save_data.world_manager_data)

	# Encounter manager data
	if save_data.encounter_data:
		_collect_encounter_data(save_data.encounter_data)

	return save_data

## Collect player data
func _collect_player_data(player_data) -> void:
	if not GameManager.player_data:
		return

	var pd := GameManager.player_data

	player_data.character_name = pd.character_name
	player_data.race = pd.race
	player_data.career = pd.career
	player_data.grit = pd.grit
	player_data.agility = pd.agility
	player_data.will = pd.will
	player_data.speech = pd.speech
	player_data.knowledge = pd.knowledge
	player_data.vitality = pd.vitality
	player_data.current_hp = pd.current_hp
	player_data.max_hp = pd.max_hp
	player_data.current_stamina = pd.current_stamina
	player_data.max_stamina = pd.max_stamina
	player_data.current_mana = pd.current_mana
	player_data.max_mana = pd.max_mana
	player_data.current_spell_slots = pd.current_spell_slots
	player_data.max_spell_slots = pd.max_spell_slots
	player_data.level = pd.level
	player_data.improvement_points = pd.improvement_points
	player_data.skills = pd.skills.duplicate()
	player_data.conditions = pd.conditions.duplicate()

	# Known spells from SpellCaster
	var player: Node = null
	if get_tree():
		player = get_tree().get_first_node_in_group("player")
	if player:
		var spell_caster: SpellCaster = player.get_node_or_null("SpellCaster")
		if spell_caster:
			player_data.known_spells = []
			for spell in spell_caster.known_spells:
				if spell:
					player_data.known_spells.append(spell.id)

	# Player position
	if player and player is Node3D:
		player_data.position = (player as Node3D).global_position
		if player.has_node("MeshRoot"):
			player_data.rotation_y = player.get_node("MeshRoot").rotation.y

	if get_tree() and get_tree().current_scene:
		player_data.current_scene = get_tree().current_scene.scene_file_path
	else:
		player_data.current_scene = ""

## Collect inventory data
func _collect_inventory_data(inv_data) -> void:
	var inv_dict := InventoryManager.to_dict()
	inv_data.items = inv_dict.get("inventory", [])
	inv_data.equipment = inv_dict.get("equipment", {})
	inv_data.gold = inv_dict.get("gold", 0)
	inv_data.quickslots = inv_dict.get("quick_slots", [])
	inv_data.hotbar = inv_dict.get("hotbar", [])
	inv_data.equipped_spell_id = inv_dict.get("equipped_spell_id", "")

## Collect world data
func _collect_world_data(world_data) -> void:
	world_data.current_zone_id = current_zone_id
	world_data.current_zone_name = current_zone_name
	world_data.discovered_locations = discovered_locations.duplicate()
	world_data.killed_enemies = killed_enemies.duplicate()
	world_data.dropped_items = _collect_dropped_items()
	world_data.flags = world_flags.duplicate()
	world_data.opened_containers = opened_containers.duplicate()
	world_data.unlocked_shortcuts = unlocked_shortcuts.duplicate()
	world_data.dungeon_seeds = dungeon_seeds.duplicate()

	# RestManager data (diminishing returns, respawn tracking)
	if RestManager:
		world_data.rest_manager = RestManager.get_save_data()

## Collect dropped items in current zone
func _collect_dropped_items() -> Dictionary:
	var items := dropped_items.duplicate()

	# Also collect any currently spawned world items
	var world_items := get_tree().get_nodes_in_group("world_items")
	var zone_items: Array = []

	for item in world_items:
		if item.has_method("to_save_dict"):
			zone_items.append(item.to_save_dict())

	if zone_items.size() > 0:
		items[current_zone_id] = zone_items

	return items

## Collect quest data
func _collect_quest_data(quest_data) -> void:
	var quest_dict := QuestManager.to_dict()
	quest_data.active = quest_dict.get("active", {})
	quest_data.completed = quest_dict.get("completed", {})
	quest_data.failed = quest_dict.get("failed", {})
	quest_data.variables = quest_dict.get("variables", {})

## Collect time data
func _collect_time_data(time_data) -> void:
	# Calculate total play time including current session
	var current_session := Time.get_unix_time_from_system() - session_start_time
	time_data.play_time = total_play_time + current_session
	time_data.game_time = GameManager.game_time if GameManager else 8.0
	time_data.current_day = GameManager.current_day if GameManager else 1
	time_data.rest_count = rest_count
	time_data.death_count = death_count
	time_data.session_start = session_start_time


## Collect crime/bounty data
func _collect_crime_data(crime_data) -> void:
	if not CrimeManager:
		return

	var crime_dict := CrimeManager.to_dict()
	crime_data.bounties = crime_dict.get("bounties", {})
	crime_data.last_crimes = crime_dict.get("last_crimes", {})
	crime_data.is_jailed = crime_dict.get("is_jailed", false)
	crime_data.jail_region = crime_dict.get("jail_region", "")
	crime_data.jail_time_remaining = crime_dict.get("jail_time_remaining", 0.0)
	crime_data.confiscated_items = crime_dict.get("confiscated_items", {})


## Collect dialogue flags data
func _collect_dialogue_data(dialogue_data) -> void:
	if not DialogueManager:
		return

	var dialogue_dict := DialogueManager.to_dict()
	dialogue_data.flags = dialogue_dict.get("dialogue_flags", {})


## Collect conversation memory data
func _collect_conversation_data(conversation_data) -> void:
	if not ConversationSystem:
		return

	var conversation_dict := ConversationSystem.to_dict()
	conversation_data.npc_memory = conversation_dict.get("npc_memory", {})


## Collect bounty quest data
func _collect_errand_data(errand_data) -> void:
	if not has_node("/root/BountyManager"):
		return

	var bounty_manager := get_node("/root/BountyManager")
	var bounty_dict: Dictionary = bounty_manager.to_dict()
	errand_data.bounties = bounty_dict.get("bounties", {})
	errand_data.npc_offered_bounties = bounty_dict.get("npc_offered_bounties", {})
	errand_data.completed_bounty_ids = bounty_dict.get("completed_bounty_ids", [])
	errand_data.bounty_counter = bounty_dict.get("bounty_counter", 0)
	errand_data.current_settlement = bounty_dict.get("current_settlement", "elder_moor")

## Apply loaded save data
func _apply_save_data(save_data) -> void:
	# Reset GameManager interaction state flags to prevent stuck states after load
	GameManager.is_paused = false
	GameManager.is_in_menu = false
	GameManager.is_in_dialogue = false
	GameManager.is_in_combat = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Restore player character
	if save_data.player:
		_apply_player_data(save_data.player)

	# Restore inventory
	if save_data.inventory:
		_apply_inventory_data(save_data.inventory)

	# Restore world state
	if save_data.world:
		_apply_world_data(save_data.world)

	# Restore quest state
	if save_data.quests:
		_apply_quest_data(save_data.quests)

	# Restore time data
	if save_data.time_data:
		_apply_time_data(save_data.time_data)

	# Restore audio settings
	AudioManager.load_settings(save_data.audio_settings)

	# Restore crime/bounty data
	if save_data.crime_data:
		_apply_crime_data(save_data.crime_data)

	# Restore dialogue flags
	if save_data.dialogue_data:
		_apply_dialogue_data(save_data.dialogue_data)

	# Restore conversation memory
	if save_data.conversation_data:
		_apply_conversation_data(save_data.conversation_data)

	# Restore errand quests
	if save_data.errand_data:
		_apply_errand_data(save_data.errand_data)

	# Restore world manager (location discovery) data
	if save_data.world_manager_data:
		_apply_world_manager_data(save_data.world_manager_data)

	# Restore encounter manager data
	if save_data.encounter_data:
		_apply_encounter_data(save_data.encounter_data)

## Apply player data
func _apply_player_data(player_data) -> void:
	if not GameManager.player_data:
		GameManager.player_data = CharacterData.new()

	var pd := GameManager.player_data

	pd.character_name = player_data.character_name
	pd.race = player_data.race
	pd.career = player_data.career
	pd.grit = player_data.grit
	pd.agility = player_data.agility
	pd.will = player_data.will
	pd.speech = player_data.speech
	pd.knowledge = player_data.knowledge
	pd.vitality = player_data.vitality
	pd.current_hp = player_data.current_hp
	pd.max_hp = player_data.max_hp
	pd.current_stamina = player_data.current_stamina
	pd.max_stamina = player_data.max_stamina
	pd.current_mana = player_data.current_mana
	pd.max_mana = player_data.max_mana
	pd.current_spell_slots = player_data.current_spell_slots
	pd.max_spell_slots = player_data.max_spell_slots
	pd.level = player_data.level
	pd.improvement_points = player_data.improvement_points
	pd.skills = player_data.skills.duplicate()
	pd.conditions = player_data.conditions.duplicate()

	# Store known spells to apply after scene loads
	pending_known_spells = player_data.known_spells.duplicate()

	# Store position for scene loader to apply
	SceneManager.set_player_position(player_data.position, player_data.rotation_y)

## Apply inventory data
func _apply_inventory_data(inv_data) -> void:
	InventoryManager.from_dict({
		"inventory": inv_data.items,
		"equipment": inv_data.equipment,
		"gold": inv_data.gold,
		"quick_slots": inv_data.quickslots,
		"hotbar": inv_data.hotbar,
		"equipped_spell_id": inv_data.equipped_spell_id
	})

## Apply world data
func _apply_world_data(world_data) -> void:
	current_zone_id = world_data.current_zone_id
	current_zone_name = world_data.current_zone_name
	discovered_locations = world_data.discovered_locations.duplicate()
	killed_enemies = world_data.killed_enemies.duplicate()
	dropped_items = world_data.dropped_items.duplicate()
	world_flags = world_data.flags.duplicate()
	opened_containers = world_data.opened_containers.duplicate()
	unlocked_shortcuts = world_data.unlocked_shortcuts.duplicate()
	dungeon_seeds = world_data.dungeon_seeds.duplicate()

	# RestManager data
	if RestManager and not world_data.rest_manager.is_empty():
		RestManager.load_save_data(world_data.rest_manager)

## Apply quest data
func _apply_quest_data(quest_data) -> void:
	QuestManager.from_dict({
		"active": quest_data.active,
		"completed": quest_data.completed,
		"failed": quest_data.failed,
		"variables": quest_data.variables
	})

## Apply time data
func _apply_time_data(time_data) -> void:
	total_play_time = time_data.play_time
	if GameManager:
		GameManager.game_time = time_data.game_time
		# Handle old saves that don't have current_day property
		var day_value: int = 1
		if "current_day" in time_data:
			day_value = time_data.current_day
		# Update time of day based on loaded time - use set_time to trigger updates
		GameManager.set_time(GameManager.game_time, day_value)
	rest_count = time_data.rest_count
	death_count = time_data.death_count


## Apply crime/bounty data
func _apply_crime_data(crime_data) -> void:
	if not CrimeManager:
		return

	CrimeManager.from_dict({
		"bounties": crime_data.bounties,
		"last_crimes": crime_data.last_crimes,
		"is_jailed": crime_data.is_jailed,
		"jail_region": crime_data.jail_region,
		"jail_time_remaining": crime_data.jail_time_remaining,
		"confiscated_items": crime_data.confiscated_items
	})


## Apply dialogue flags data
func _apply_dialogue_data(dialogue_data) -> void:
	if not DialogueManager:
		return

	DialogueManager.from_dict({
		"dialogue_flags": dialogue_data.flags
	})


## Apply conversation memory data
func _apply_conversation_data(conversation_data) -> void:
	if not ConversationSystem:
		return

	ConversationSystem.from_dict({
		"npc_memory": conversation_data.npc_memory
	})


## Apply bounty quest data
func _apply_errand_data(errand_data) -> void:
	if not has_node("/root/BountyManager"):
		return

	var bounty_manager := get_node("/root/BountyManager")
	# errand_data is an ErrandSaveData object, access properties directly
	bounty_manager.from_dict({
		"bounties": errand_data.bounties if errand_data else {},
		"npc_offered_bounties": errand_data.npc_offered_bounties if errand_data else {},
		"completed_bounty_ids": errand_data.completed_bounty_ids if errand_data else [],
		"bounty_counter": errand_data.bounty_counter if errand_data else 0,
		"current_settlement": errand_data.current_settlement if errand_data else "elder_moor"
	})


## Collect world manager (location discovery) data
func _collect_world_manager_data(world_manager_data) -> void:
	if not has_node("/root/WorldManager"):
		return

	var wm := get_node("/root/WorldManager")
	var wm_dict: Dictionary = wm.to_dict()
	world_manager_data.discovered_locations = wm_dict.get("discovered_locations", {})
	world_manager_data.discovered_cells = wm_dict.get("discovered_cells", [])
	world_manager_data.current_cell = wm_dict.get("current_cell", {"x": 0, "y": 0})
	world_manager_data.current_region = wm_dict.get("current_region", "")
	world_manager_data.current_location_id = wm_dict.get("current_location_id", "")
	world_manager_data.cells_traveled = wm_dict.get("cells_traveled", 0)
	world_manager_data.locations_visited = wm_dict.get("locations_visited", 0)


## Apply world manager (location discovery) data
func _apply_world_manager_data(world_manager_data) -> void:
	if not has_node("/root/WorldManager"):
		return

	var wm := get_node("/root/WorldManager")
	wm.from_dict({
		"discovered_locations": world_manager_data.discovered_locations,
		"discovered_cells": world_manager_data.discovered_cells,
		"current_cell": world_manager_data.current_cell,
		"current_region": world_manager_data.current_region,
		"current_location_id": world_manager_data.current_location_id,
		"cells_traveled": world_manager_data.cells_traveled,
		"locations_visited": world_manager_data.locations_visited
	})


## Collect encounter manager data
func _collect_encounter_data(encounter_data) -> void:
	if not has_node("/root/EncounterManager"):
		return

	var em := get_node("/root/EncounterManager")
	var em_dict: Dictionary = em.to_dict()
	encounter_data.encounters_triggered = em_dict.get("encounters_triggered", 0)
	encounter_data.encounters_avoided = em_dict.get("encounters_avoided", 0)
	# Also save current cooldown and timer state
	if "cooldown_timer" in em:
		encounter_data.cooldown_remaining = em._cooldown_timer
	if "_encounter_timer" in em:
		encounter_data.encounter_timer = em._encounter_timer
	if "_last_check_hex" in em:
		var hex: Vector2i = em._last_check_hex
		encounter_data.last_check_hex = {"x": hex.x, "y": hex.y}


## Apply encounter manager data
func _apply_encounter_data(encounter_data) -> void:
	if not has_node("/root/EncounterManager"):
		return

	var em := get_node("/root/EncounterManager")
	em.from_dict({
		"encounters_triggered": encounter_data.encounters_triggered,
		"encounters_avoided": encounter_data.encounters_avoided
	})
	# Restore timer state
	if "_cooldown_timer" in em:
		em._cooldown_timer = encounter_data.cooldown_remaining
	if "_encounter_timer" in em:
		em._encounter_timer = encounter_data.encounter_timer
	if "_last_check_hex" in em:
		var hex_raw = encounter_data.last_check_hex
		# Handle both Dictionary and malformed data
		if hex_raw is Dictionary:
			em._last_check_hex = Vector2i(hex_raw.get("x", 0), hex_raw.get("y", 0))
		else:
			# Fallback for corrupted/string data
			em._last_check_hex = Vector2i.ZERO


## Migrate old save data to current version
func _migrate_save_data(data: Dictionary, from_version: int) -> Dictionary:
	var migrated := data.duplicate(true)

	# Version 0 -> 1: Restructure to new format
	if from_version < 1:
		# Convert old format to new format
		var player_data := {}
		if migrated.has("character"):
			player_data = migrated["character"]
		if migrated.has("player_position"):
			player_data["position"] = migrated["player_position"]
		if migrated.has("game_state"):
			player_data["current_scene"] = migrated["game_state"].get("current_scene", "")

		migrated["player"] = player_data
		migrated["version"] = 1

		# Convert time data
		migrated["time"] = {
			"play_time": migrated.get("meta", {}).get("playtime", 0.0),
			"game_time": migrated.get("game_state", {}).get("game_time", 8.0),
			"current_day": migrated.get("game_state", {}).get("current_day", 1),
			"rest_count": 0,
			"death_count": 0,
			"session_start": 0.0
		}

		# World data
		var old_world: Dictionary = migrated.get("world_state", {})
		migrated["world"] = {
			"current_zone_id": "",
			"current_zone_name": "",
			"discovered_locations": {},
			"killed_enemies": {},
			"dropped_items": {},
			"flags": {},
			"opened_containers": {},
			"unlocked_shortcuts": old_world.get("unlocked_shortcuts", {})
		}

	return migrated

## Get current play time (including current session)
func get_total_playtime() -> float:
	var current_session := Time.get_unix_time_from_system() - session_start_time
	return total_play_time + current_session

## Format play time as string (HH:MM:SS)
func format_playtime(seconds: float) -> String:
	var hours := int(seconds / 3600)
	var minutes := int(fmod(seconds, 3600) / 60)
	var secs := int(fmod(seconds, 60))
	return "%02d:%02d:%02d" % [hours, minutes, secs]

## Quick save (slot 0)
func quick_save() -> bool:
	return save_game(0)

## Quick load (slot 0)
func quick_load() -> bool:
	return load_game(0)

## Called when scene finishes loading - apply pending data
func _on_scene_load_completed(_scene_path: String) -> void:
	# Apply pending known spells after a short delay to ensure player is ready
	if not pending_known_spells.is_empty():
		call_deferred("_apply_pending_known_spells")

## Apply pending known spells to player's SpellCaster
func _apply_pending_known_spells() -> void:
	if pending_known_spells.is_empty():
		return

	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return

	var spell_caster: SpellCaster = player.get_node_or_null("SpellCaster")
	if not spell_caster:
		return

	# Clear existing and learn saved spells
	spell_caster.known_spells.clear()
	for spell_id in pending_known_spells:
		spell_caster.learn_spell_by_id(spell_id)

	pending_known_spells.clear()

## World state tracking methods

## Set current zone (call when entering a new area)
func set_current_zone(zone_id: String, zone_name: String) -> void:
	current_zone_id = zone_id
	current_zone_name = zone_name

	# Update BountyManager if entering a settlement
	if BountyManager and WorldLexicon.SETTLEMENTS.has(zone_id):
		BountyManager.set_current_settlement(zone_id)

## Mark a location as discovered
func discover_location(location_id: String, location_data: Dictionary = {}) -> void:
	if not discovered_locations.has(location_id):
		discovered_locations[location_id] = {
			"discovered_at": Time.get_unix_time_from_system(),
			"data": location_data
		}

## Check if location is discovered
func is_location_discovered(location_id: String) -> bool:
	return discovered_locations.has(location_id)

## Mark an enemy as killed (for enemies that should stay dead)
func mark_enemy_killed(enemy_id: String, kill_data: Dictionary = {}) -> void:
	killed_enemies[enemy_id] = {
		"killed_at": Time.get_unix_time_from_system(),
		"data": kill_data
	}

## Check if enemy was killed
func was_enemy_killed(enemy_id: String) -> bool:
	return killed_enemies.has(enemy_id)

## Set a world flag
func set_world_flag(flag_name: String, value: Variant = true) -> void:
	world_flags[flag_name] = value

## Get a world flag
func get_world_flag(flag_name: String, default: Variant = null) -> Variant:
	return world_flags.get(flag_name, default)

## Check if a world flag is set
func has_world_flag(flag_name: String) -> bool:
	return world_flags.has(flag_name)

## Mark a container as opened
func mark_container_opened(container_id: String) -> void:
	opened_containers[container_id] = true

## Check if container was opened
func was_container_opened(container_id: String) -> bool:
	return opened_containers.has(container_id)

## Unlock a shortcut
func unlock_shortcut(shortcut_id: String) -> void:
	unlocked_shortcuts[shortcut_id] = true

## Check if shortcut is unlocked
func is_shortcut_unlocked(shortcut_id: String) -> bool:
	return unlocked_shortcuts.has(shortcut_id)

## Increment rest count
func increment_rest_count() -> void:
	rest_count += 1

## Increment death count
func increment_death_count() -> void:
	death_count += 1


## Save persistent chest contents
func save_chest_contents(chest_id: String, contents: Array) -> void:
	if chest_id.is_empty():
		return
	persistent_chest_contents[chest_id] = contents.duplicate(true)


## Load persistent chest contents
func load_chest_contents(chest_id: String) -> Array:
	if chest_id.is_empty() or not persistent_chest_contents.has(chest_id):
		return []
	return persistent_chest_contents[chest_id].duplicate(true)


## Check if chest has saved contents
func has_chest_contents(chest_id: String) -> bool:
	return persistent_chest_contents.has(chest_id)


## Get saved dungeon seed for a zone (-1 if none exists)
func get_dungeon_seed(zone_id: String) -> int:
	if zone_id.is_empty() or not dungeon_seeds.has(zone_id):
		return -1
	return dungeon_seeds[zone_id]


## Set dungeon seed for a zone (auto-persists to cache file)
func set_dungeon_seed(zone_id: String, seed_value: int) -> void:
	if zone_id.is_empty():
		return
	dungeon_seeds[zone_id] = seed_value
	_save_dungeon_seeds_cache()


## Save dungeon seeds to a lightweight cache file (survives exit without full save)
func _save_dungeon_seeds_cache() -> void:
	var file := FileAccess.open(DUNGEON_SEEDS_FILE, FileAccess.WRITE)
	if not file:
		push_warning("[SaveManager] Failed to write dungeon seeds cache")
		return

	var json_string := JSON.stringify(dungeon_seeds)
	file.store_string(json_string)
	file.close()


## Load dungeon seeds from cache file on startup
func _load_dungeon_seeds_cache() -> void:
	if not FileAccess.file_exists(DUNGEON_SEEDS_FILE):
		return

	var file := FileAccess.open(DUNGEON_SEEDS_FILE, FileAccess.READ)
	if not file:
		return

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()

	if parse_result == OK and json.data is Dictionary:
		# Merge cached seeds with any already loaded (full save takes priority)
		for zone_id in json.data:
			if not dungeon_seeds.has(zone_id):
				dungeon_seeds[zone_id] = int(json.data[zone_id])


## Reset world state (for new game)
func reset_world_state() -> void:
	discovered_locations.clear()
	killed_enemies.clear()
	dropped_items.clear()
	world_flags.clear()
	opened_containers.clear()
	unlocked_shortcuts.clear()
	persistent_chest_contents.clear()
	dungeon_seeds.clear()
	current_zone_id = ""
	current_zone_name = ""
	total_play_time = 0.0
	rest_count = 0
	death_count = 0
	session_start_time = Time.get_unix_time_from_system()
	# Clear the dungeon seeds cache file for new game
	if FileAccess.file_exists(DUNGEON_SEEDS_FILE):
		DirAccess.remove_absolute(DUNGEON_SEEDS_FILE)

	# Reset crime/bounty data
	if CrimeManager:
		CrimeManager.reset_for_new_game()

	# Reset dialogue flags
	if DialogueManager:
		DialogueManager.dialogue_flags.clear()

	# Reset conversation memory
	if ConversationSystem:
		ConversationSystem.npc_memory.clear()

	# Reset bounty quests
	if has_node("/root/BountyManager"):
		var bounty_manager := get_node("/root/BountyManager")
		bounty_manager.reset_for_new_game()

	# Reset world manager (location discovery)
	if has_node("/root/WorldManager"):
		var wm := get_node("/root/WorldManager")
		wm.reset_for_new_game()
