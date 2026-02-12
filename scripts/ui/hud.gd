## hud.gd - Main game HUD
class_name GameHUD
extends CanvasLayer

## Node references
@export var health_bar: ProgressBar
@export var health_label: Label
@export var stamina_bar: ProgressBar
@export var mana_bar: ProgressBar
@export var spell_slots_container: HBoxContainer
@export var quick_slots_container: HBoxContainer
@export var enemy_health_container: Control
@export var enemy_health_bar: ProgressBar
@export var enemy_name_label: Label
@export var damage_numbers_container: Control
@export var notification_label: Label
## Minimap moved to code-generated var below
@export var crosshair: Control
@export var condition_icons_container: HBoxContainer
@export var gold_label: Label
@export var time_label: Label
@export var ammo_container: Control
@export var ammo_label: Label
@export var equipped_label: Label

## Menu references
@onready var game_menu: GameMenu = $GameMenu
var pause_menu: PauseMenu

## Spell slot icons (generated)
var spell_slot_icons: Array[TextureRect] = []

## Quick slot icons
var quick_slot_icons: Array[Control] = []

## Target tracking
var current_target: Node = null
var target_health_visible: bool = false

## Notification queue
var notification_queue: Array[String] = []
var notification_timer: float = 0.0
const NOTIFICATION_DURATION := 3.0

## Damage number scene
var damage_number_scene: PackedScene

## Interaction prompt
var interaction_prompt_label: Label

## Death screen
var death_screen: ColorRect
var death_load_autosave_button: Button
var death_load_save_button: Button
var death_restart_button: Button
var death_save_select_panel: Control

## Durability warning
var durability_warning_label: Label
var durability_check_timer: float = 0.0
const DURABILITY_CHECK_INTERVAL := 1.0
const LOW_DURABILITY_THRESHOLD := 0.25

## Game log (side panel for events)
var game_log_container: VBoxContainer
var game_log_entries: Array[Control] = []
const MAX_LOG_ENTRIES := 8
const LOG_FADE_DURATION := 4.0
const LOG_FADE_START := 3.0  # Start fading after this many seconds

## Compass
var compass_container: Control
var compass_strip: Control
var compass_markers: Array[Label] = []
var compass_poi_markers: Dictionary = {}  # poi_id -> Label
var compass_quest_marker: Label = null  # Quest objective marker
var compass_enemy_markers: Dictionary = {}  # enemy instance_id -> Label (INTUITION-based radar)
var compass_plant_markers: Dictionary = {}  # plant instance_id -> Label (HERBALISM-based detection)

## Bounty indicator
var bounty_indicator: Label
var bounty_flash_timer: float = 0.0
const BOUNTY_FLASH_SPEED := 3.0
const COMPASS_WIDTH := 300.0

## Quest tracker (shows tracked quest at top of screen)
var quest_tracker_container: Control
var quest_tracker_title: Label
var quest_tracker_progress: Label

## Minimap with quest markers
var minimap: Minimap = null
var minimap_coord_label: Label = null

## Conditions display (below mana bar)
var conditions_container: HBoxContainer = null
var condition_labels: Dictionary = {}  # Condition enum -> PanelContainer

## Town/settlement zone IDs - used for quest routing and turn-in
const TOWN_ZONES: Array[String] = [
	"elder_moor", "village_elder_moor",
	"dalhurst", "city_dalhurst",
	"riverside_village",
	"town_aberdeen", "aberdeen",
	"town_larton", "larton",
	"town_whalers_abyss", "whalers_abyss",
	"town_east_hollow", "east_hollow",
	"city_rotherhine", "rotherhine",
	"capital_falkenhafen", "falkenhafen",
	"village_elven_outpost", "elven_outpost"
]

## Check if a zone ID represents a town/settlement
static func _is_town_zone(zone: String) -> bool:
	return zone in TOWN_ZONES
const COMPASS_HEIGHT := 24.0
const POI_FADE_DISTANCE := 90.0   # Distance at which POI markers start fading
const POI_MAX_DISTANCE := 120.0   # Distance at which POI markers are fully hidden
const ENEMY_DETECTION_BASE := 15.0  # Base detection range for enemies
const ENEMY_DETECTION_PER_INTUITION := 5.0  # Additional range per INTUITION level
const PLANT_DETECTION_MIN_HERBALISM := 5  # Minimum HERBALISM level to see plants on compass
const PLANT_DETECTION_RANGE := 30.0  # Range at which plants appear on compass

## Zone connection map for quest tracking - maps zone IDs to exit door target scenes
## Used to find which door to point to when quest objective is in another zone
var zone_connections: Dictionary = {
	# Format: "current_zone": [{"target_zone": "zone_id", "door_scene": "res://..."}, ...]
	# This is populated dynamically from zone doors in the scene
}

## Track connected player_data to properly disconnect signals when it changes
var _connected_player_data: CharacterData = null

## Cached player reference for safety checks
var _cached_player: Node3D = null

func _ready() -> void:
	# Add to hud group so other scripts can find us
	add_to_group("hud")

	# Fallback: get nodes by path if exports weren't resolved
	if not health_bar:
		health_bar = get_node_or_null("TopLeft/HealthBar") as ProgressBar
	if not health_label:
		health_label = get_node_or_null("TopLeft/HealthLabel") as Label
	if not stamina_bar:
		stamina_bar = get_node_or_null("TopLeft/StaminaBar") as ProgressBar
	if not mana_bar:
		mana_bar = get_node_or_null("TopLeft/ManaBar") as ProgressBar
	if not ammo_container:
		ammo_container = get_node_or_null("BottomRight/AmmoContainer") as Control
	if not ammo_label:
		ammo_label = get_node_or_null("BottomRight/AmmoContainer/AmmoLabel") as Label
	if not quick_slots_container:
		quick_slots_container = get_node_or_null("BottomCenter/QuickSlots") as HBoxContainer
	if not enemy_health_container:
		enemy_health_container = get_node_or_null("EnemyHealthContainer") as Control
	if not enemy_health_bar:
		enemy_health_bar = get_node_or_null("EnemyHealthContainer/EnemyHealthBar") as ProgressBar
	if not enemy_name_label:
		enemy_name_label = get_node_or_null("EnemyHealthContainer/EnemyNameLabel") as Label
	if not notification_label:
		notification_label = get_node_or_null("BottomCenter/NotificationLabel") as Label
	if not gold_label:
		gold_label = get_node_or_null("TopRight/GoldLabel") as Label
	if not equipped_label:
		equipped_label = get_node_or_null("BottomLeft/EquippedLabel") as Label

	_setup_spell_slots()
	_setup_quick_slots()
	_setup_interaction_prompt()
	_setup_death_screen()
	_setup_durability_warning()
	_setup_game_log()
	_setup_compass()
	_setup_minimap()
	_setup_bounty_indicator()
	_setup_quest_tracker()
	_setup_conditions_display()
	_connect_signals()
	_setup_menus()
	_connect_scene_signals()

	# Try to load damage number scene
	if ResourceLoader.exists("res://scenes/ui/damage_number.tscn"):
		damage_number_scene = load("res://scenes/ui/damage_number.tscn")

	# Hide enemy health by default
	if enemy_health_container:
		enemy_health_container.visible = false

func _input(event: InputEvent) -> void:
	# Don't process if already in a menu
	if _is_menu_open():
		return

	# Escape opens the pause menu
	if event.is_action_pressed("pause"):
		_open_pause_menu()
		get_viewport().set_input_as_handled()
		return

	# Tab opens the game menu (inventory, spells, etc.)
	if event.is_action_pressed("menu"):
		_open_game_menu()
		get_viewport().set_input_as_handled()
		return

func _setup_menus() -> void:
	# Setup game menu (loaded via @onready)
	if game_menu:
		game_menu.visible = false
		if game_menu.has_signal("menu_closed"):
			game_menu.menu_closed.connect(_on_menu_closed)
	else:
		push_error("[HUD] GameMenu not found!")

	# Load and setup pause menu
	var pause_menu_scene := load("res://scenes/ui/pause_menu.tscn")
	if pause_menu_scene:
		pause_menu = pause_menu_scene.instantiate() as PauseMenu
		pause_menu.visible = false
		add_child(pause_menu)
		if pause_menu.has_signal("menu_closed"):
			pause_menu.menu_closed.connect(_on_menu_closed)
	else:
		push_error("[HUD] Failed to load PauseMenu!")

func _is_menu_open() -> bool:
	if game_menu and game_menu.visible:
		return true
	if pause_menu and pause_menu.visible:
		return true
	# Check if dialogue or conversation is active
	if DialogueManager.is_dialogue_active:
		return true
	if ConversationSystem.is_active:
		return true
	return false

func _open_game_menu() -> void:
	if game_menu:
		game_menu.open()

func _open_pause_menu() -> void:
	if pause_menu:
		pause_menu.open()

func _on_menu_closed() -> void:
	# Menu handles GameManager.exit_menu() itself
	pass

## Connect to scene manager signals for zone transition cleanup
func _connect_scene_signals() -> void:
	if SceneManager.has_signal("scene_load_started"):
		SceneManager.scene_load_started.connect(_on_scene_load_started)
	if SceneManager.has_signal("scene_load_completed"):
		SceneManager.scene_load_completed.connect(_on_scene_load_completed)

## Called when a new scene starts loading - clean up POI markers
func _on_scene_load_started(_scene_path: String) -> void:
	_clear_all_poi_markers()

## Called when scene loading completes - rebuild zone connections
func _on_scene_load_completed(_scene_path: String) -> void:
	# Defer to let the scene fully initialize
	call_deferred("_rebuild_zone_connections")

## Clear all POI markers from the compass (used on zone transitions)
## This is called when a new scene starts loading to prevent ghost markers
func _clear_all_poi_markers() -> void:
	# Store IDs first, then clear dictionary BEFORE queue_free
	# This prevents race conditions where new markers might use stale IDs
	var markers_to_free: Array[Label] = []
	for poi_id in compass_poi_markers:
		var marker: Label = compass_poi_markers[poi_id]
		if is_instance_valid(marker):
			markers_to_free.append(marker)

	# Clear dictionary first (prevents ghost references)
	compass_poi_markers.clear()

	# Now queue_free the markers
	for marker in markers_to_free:
		marker.queue_free()

	# Also clear quest marker
	if compass_quest_marker and is_instance_valid(compass_quest_marker):
		compass_quest_marker.queue_free()
		compass_quest_marker = null

	# Also clear enemy radar markers
	var enemy_markers_to_free: Array[Label] = []
	for enemy_id in compass_enemy_markers:
		var marker = compass_enemy_markers[enemy_id]
		if marker and is_instance_valid(marker):
			enemy_markers_to_free.append(marker)
	compass_enemy_markers.clear()
	for marker in enemy_markers_to_free:
		marker.queue_free()

	# Also clear plant markers
	var plant_markers_to_free: Array[Label] = []
	for plant_id in compass_plant_markers:
		var marker = compass_plant_markers[plant_id]
		if marker and is_instance_valid(marker):
			plant_markers_to_free.append(marker)
	compass_plant_markers.clear()
	for marker in plant_markers_to_free:
		marker.queue_free()

	print("[HUD] Cleared all POI, enemy, and plant markers for scene transition")

## Rebuild zone connection map from doors in current scene
## Now stores ARRAY of doors per zone to handle multiple exits
func _rebuild_zone_connections() -> void:
	zone_connections.clear()

	# Find all zone doors and map their targets
	var doors := get_tree().get_nodes_in_group("doors")
	for door in doors:
		if door is ZoneDoor:
			var zone_door := door as ZoneDoor
			if not zone_door.target_scene.is_empty():
				# Extract zone ID from target scene path
				var target_zone := _scene_path_to_zone_id(zone_door.target_scene)
				# Store as array to handle multiple doors to same zone
				if not zone_connections.has(target_zone):
					zone_connections[target_zone] = []
				zone_connections[target_zone].append({
					"door": zone_door,
					"scene_path": zone_door.target_scene
				})

## Convert a scene path to a zone ID (extracts from path)
func _scene_path_to_zone_id(scene_path: String) -> String:
	# Extract filename without extension as zone ID
	# e.g., "res://scenes/levels/goblin_cave.tscn" -> "goblin_cave"
	var filename := scene_path.get_file().get_basename()

	# Map common scene names to their ZONE_IDs (use actual zone names, not generic "town")
	match filename:
		"elder_moor": return "elder_moor"
		"dalhurst": return "dalhurst"
		"aberdeen": return "aberdeen"
		"larton": return "larton"
		"rotherhine": return "rotherhine"
		"falkenhafen": return "falkenhafen"
		"whalers_abyss": return "whalers_abyss"
		"east_hollow": return "east_hollow"
		"open_world": return "open_world"
		"goblin_cave": return "goblin_cave"
		"dark_crypt": return "dark_crypt"
		"random_cave": return "random_cave"
		"riverside_village": return "riverside_village"
		"inn_interior": return "inn_interior"
		"test_dungeon": return "test_dungeon"
		_: return filename

func _process(delta: float) -> void:
	# Skip processing if player is dead or not valid (prevents crash after death)
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player") as Node3D
	if not _cached_player or not is_instance_valid(_cached_player) or not _cached_player.is_inside_tree():
		return

	_update_bars()
	_update_target_health()
	_update_notifications(delta)
	_update_conditions()
	_update_time()
	_update_durability_warning(delta)
	_update_game_log(delta)
	_update_compass()
	_update_minimap_coordinates()
	_update_bounty_indicator(delta)
	_update_quest_tracker()

func _setup_spell_slots() -> void:
	# Spell slots deprecated - mana bar is used instead
	if spell_slots_container:
		spell_slots_container.visible = false
	return

func _setup_quick_slots() -> void:
	# Quick slots disabled for now - feature not ready
	if quick_slots_container:
		quick_slots_container.visible = false
		return

	# Code below preserved for future use
	if not quick_slots_container:
		return

	# Clear existing
	for child in quick_slots_container.get_children():
		child.queue_free()

	# Create 4 quick slot displays
	for i in range(4):
		var slot_panel := Panel.new()
		slot_panel.custom_minimum_size = Vector2(48, 48)

		var key_label := Label.new()
		key_label.text = str(i + 1)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		slot_panel.add_child(key_label)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.set_anchors_preset(Control.PRESET_CENTER)
		icon.custom_minimum_size = Vector2(32, 32)
		slot_panel.add_child(icon)

		var count_label := Label.new()
		count_label.name = "Count"
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		slot_panel.add_child(count_label)

		quick_slots_container.add_child(slot_panel)
		quick_slot_icons.append(slot_panel)

func _connect_signals() -> void:
	# Disconnect old player_data signals if we were connected to a different one
	_disconnect_player_data_signals()

	# Connect to game signals - with error handling
	if GameManager.player_data:
		_connected_player_data = GameManager.player_data
		if GameManager.player_data.has_signal("hp_changed"):
			GameManager.player_data.hp_changed.connect(_on_hp_changed)
		if GameManager.player_data.has_signal("condition_applied"):
			GameManager.player_data.condition_applied.connect(_on_condition_applied)
		if GameManager.player_data.has_signal("condition_removed"):
			GameManager.player_data.condition_removed.connect(_on_condition_removed)
		if GameManager.player_data.has_signal("level_up"):
			GameManager.player_data.level_up.connect(_on_level_up)
		if GameManager.player_data.has_signal("ip_gained"):
			GameManager.player_data.ip_gained.connect(_on_xp_gained)

	if InventoryManager.has_signal("gold_changed"):
		InventoryManager.gold_changed.connect(_on_gold_changed)
	if InventoryManager.has_signal("quick_slot_changed"):
		InventoryManager.quick_slot_changed.connect(_on_quick_slot_changed)
	if InventoryManager.has_signal("item_added"):
		InventoryManager.item_added.connect(_on_item_added)
	if InventoryManager.has_signal("item_degraded"):
		InventoryManager.item_degraded.connect(_on_item_degraded)
	if InventoryManager.has_signal("item_repaired"):
		InventoryManager.item_repaired.connect(_on_item_repaired)

	if CombatManager.has_signal("damage_dealt"):
		CombatManager.damage_dealt.connect(_on_damage_dealt)
	if CombatManager.has_signal("critical_hit"):
		CombatManager.critical_hit.connect(_on_critical_hit)

	# Quest signals
	if QuestManager.has_signal("quest_started"):
		QuestManager.quest_started.connect(_on_quest_started)
	if QuestManager.has_signal("quest_completed"):
		QuestManager.quest_completed.connect(_on_quest_completed)
	if QuestManager.has_signal("objective_completed"):
		QuestManager.objective_completed.connect(_on_objective_completed)

## Disconnect signals from old player_data to prevent "signal connected to freed object" errors
func _disconnect_player_data_signals() -> void:
	if _connected_player_data and is_instance_valid(_connected_player_data):
		if _connected_player_data.hp_changed.is_connected(_on_hp_changed):
			_connected_player_data.hp_changed.disconnect(_on_hp_changed)
		if _connected_player_data.condition_applied.is_connected(_on_condition_applied):
			_connected_player_data.condition_applied.disconnect(_on_condition_applied)
		if _connected_player_data.condition_removed.is_connected(_on_condition_removed):
			_connected_player_data.condition_removed.disconnect(_on_condition_removed)
		if _connected_player_data.level_up.is_connected(_on_level_up):
			_connected_player_data.level_up.disconnect(_on_level_up)
		if _connected_player_data.ip_gained.is_connected(_on_xp_gained):
			_connected_player_data.ip_gained.disconnect(_on_xp_gained)
	_connected_player_data = null

## Reconnect signals when player_data changes (e.g., new game, load game)
func reconnect_player_signals() -> void:
	_connect_signals()

func _update_bars() -> void:
	var char_data := GameManager.player_data
	if not char_data:
		return

	# Health bar
	if health_bar:
		health_bar.max_value = char_data.max_hp
		health_bar.value = char_data.current_hp

	if health_label:
		health_label.text = "%d / %d" % [char_data.current_hp, char_data.max_hp]

	# Stamina bar
	if stamina_bar:
		stamina_bar.max_value = char_data.max_stamina
		stamina_bar.value = char_data.current_stamina

	# Mana bar
	if mana_bar:
		mana_bar.max_value = char_data.max_mana
		mana_bar.value = char_data.current_mana

	# Ammo display
	_update_ammo_display()

	# Equipped item display (bottom-left)
	_update_equipped_display()

	# Spell slots deprecated - mana is shown via mana_bar
	# _update_spell_slots(char_data.current_spell_slots, char_data.max_spell_slots)

	# Gold
	if gold_label:
		gold_label.text = "%d G" % InventoryManager.gold

func _update_spell_slots(current: int, maximum: int) -> void:
	for i in range(spell_slot_icons.size()):
		var icon: TextureRect = spell_slot_icons[i]
		if i < maximum:
			icon.visible = true
			# Could use different colors/textures for filled vs empty
			icon.modulate = Color.CYAN if i < current else Color(0.3, 0.3, 0.3)
		else:
			icon.visible = false

## Update ammo display based on equipped weapon
func _update_ammo_display() -> void:
	if not ammo_container:
		return

	# Get equipped weapon
	var weapon: WeaponData = InventoryManager.get_equipped_weapon()

	# Hide if no weapon or melee weapon
	if not weapon or not weapon.is_ranged or weapon.ammo_type.is_empty():
		ammo_container.visible = false
		return

	# Show ammo count
	ammo_container.visible = true
	var ammo_count := InventoryManager.get_item_count(weapon.ammo_type)
	var ammo_name := _get_ammo_display_name(weapon.ammo_type)

	if ammo_label:
		ammo_label.text = "%s: %d" % [ammo_name, ammo_count]

## Get display name for ammo type
func _get_ammo_display_name(ammo_type: String) -> String:
	match ammo_type:
		"arrows": return "Arrows"
		"bolts": return "Bolts"
		"lead_balls": return "Lead Balls"
		_: return ammo_type.capitalize()

## Update equipped item display (bottom-left corner)
func _update_equipped_display() -> void:
	if not equipped_label:
		return

	# Check for equipped spell first (takes priority)
	var spell := InventoryManager.get_equipped_spell()
	if spell:
		equipped_label.text = spell.display_name
		equipped_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))  # Blue for magic
		return

	# Check for equipped weapon
	var weapon := InventoryManager.get_equipped_weapon()
	if weapon:
		equipped_label.text = weapon.display_name
		equipped_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))  # Warm white
		return

	# Nothing equipped
	equipped_label.text = "Unarmed"
	equipped_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))  # Gray

func _update_target_health() -> void:
	if not enemy_health_container:
		return

	# Get player's lock-on target
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player and player.lock_on_target:
		current_target = player.lock_on_target
	else:
		current_target = null

	if current_target and current_target.has_method("is_dead") and not current_target.is_dead():
		enemy_health_container.visible = true

		if enemy_name_label and current_target is EnemyBase:
			var enemy := current_target as EnemyBase
			enemy_name_label.text = enemy.enemy_data.display_name if enemy.enemy_data else "Enemy"

		if enemy_health_bar and current_target is EnemyBase:
			var enemy := current_target as EnemyBase
			enemy_health_bar.max_value = enemy.max_hp
			enemy_health_bar.value = enemy.current_hp
	else:
		enemy_health_container.visible = false

func _update_notifications(delta: float) -> void:
	if not notification_label:
		return

	if notification_timer > 0:
		notification_timer -= delta
		if notification_timer <= 0:
			notification_label.text = ""
			_show_next_notification()

## Setup the conditions display container below mana bar
func _setup_conditions_display() -> void:
	# Find or create parent container (TopLeft VBox)
	var top_left := get_node_or_null("TopLeft")
	if not top_left:
		return

	# Create conditions container below existing bars
	conditions_container = HBoxContainer.new()
	conditions_container.name = "ConditionsContainer"
	conditions_container.add_theme_constant_override("separation", 8)
	top_left.add_child(conditions_container)

	# Move it to be after mana bar if possible
	if mana_bar:
		var mana_idx := mana_bar.get_index()
		top_left.move_child(conditions_container, mana_idx + 1)

func _update_conditions() -> void:
	if not conditions_container:
		return

	var char_data := GameManager.player_data
	if not char_data:
		return

	# CharacterData.conditions is a Dictionary of { Condition -> time_remaining }
	var active_conditions: Dictionary = char_data.conditions

	# Track which conditions we need to add/update/remove
	var conditions_to_remove: Array = []
	for condition in condition_labels.keys():
		if not active_conditions.has(condition):
			conditions_to_remove.append(condition)

	# Remove labels for expired conditions
	for condition in conditions_to_remove:
		var label_panel: Control = condition_labels[condition]
		if is_instance_valid(label_panel):
			label_panel.queue_free()
		condition_labels.erase(condition)

	# Update or add labels for active conditions
	for condition in active_conditions.keys():
		var time_left: float = active_conditions[condition]

		if condition_labels.has(condition):
			# Update existing label
			_update_condition_label(condition, time_left)
		else:
			# Create new label
			_create_condition_label(condition, time_left)

## Create a condition label with colored panel
func _create_condition_label(condition: Enums.Condition, time_left: float) -> void:
	var panel := PanelContainer.new()

	# Create stylebox for background color
	var style := StyleBoxFlat.new()
	var is_buff := _is_buff_condition(condition)
	if is_buff:
		style.bg_color = Color(0.1, 0.3, 0.1, 0.8)  # Dark green for buffs
	else:
		style.bg_color = Color(0.3, 0.1, 0.1, 0.8)  # Dark red for debuffs
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

	# Create label
	var label := Label.new()
	label.name = "ConditionLabel"
	var condition_name := _get_condition_name(condition)
	label.text = "%s %.1fs" % [condition_name, time_left]
	label.add_theme_color_override("font_color", _get_condition_text_color(condition))
	label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)

	conditions_container.add_child(panel)
	condition_labels[condition] = panel

## Update an existing condition label's time display
func _update_condition_label(condition: Enums.Condition, time_left: float) -> void:
	if not condition_labels.has(condition):
		return

	var panel: PanelContainer = condition_labels[condition]
	if not is_instance_valid(panel):
		condition_labels.erase(condition)
		return

	var label := panel.get_node_or_null("ConditionLabel") as Label
	if label:
		var condition_name := _get_condition_name(condition)
		label.text = "%s %.1fs" % [condition_name, time_left]

## Check if a condition is a buff (beneficial) or debuff (harmful)
func _is_buff_condition(condition: Enums.Condition) -> bool:
	match condition:
		Enums.Condition.ARMORED: return true
		Enums.Condition.HASTED: return true
		_: return false

## Get display name for a condition
func _get_condition_name(condition: Enums.Condition) -> String:
	match condition:
		Enums.Condition.NONE: return ""
		Enums.Condition.KNOCKED_DOWN: return "DOWNED"
		Enums.Condition.POISONED: return "POISONED"
		Enums.Condition.BURNING: return "BURNING"
		Enums.Condition.FROZEN: return "FROZEN"
		Enums.Condition.HORRIFIED: return "FEARED"
		Enums.Condition.BLEEDING: return "BLEEDING"
		Enums.Condition.STUNNED: return "STUNNED"
		Enums.Condition.SILENCED: return "SILENCED"
		Enums.Condition.ARMORED: return "ARMORED"
		Enums.Condition.BLINDED: return "BLINDED"
		Enums.Condition.SLOWED: return "SLOWED"
		Enums.Condition.HASTED: return "HASTED"
		_: return "UNKNOWN"

func _update_time() -> void:
	if time_label:
		time_label.text = "Day %d - %s" % [GameManager.current_day, GameManager.get_time_string()]

## Get text color for condition display
func _get_condition_text_color(condition: Enums.Condition) -> Color:
	match condition:
		Enums.Condition.POISONED: return Color(0.4, 0.9, 0.3)  # Bright green
		Enums.Condition.BURNING: return Color(1.0, 0.6, 0.2)  # Orange
		Enums.Condition.FROZEN: return Color(0.5, 0.9, 1.0)  # Cyan
		Enums.Condition.BLEEDING: return Color(0.9, 0.3, 0.3)  # Red
		Enums.Condition.HORRIFIED: return Color(0.7, 0.3, 0.9)  # Purple
		Enums.Condition.STUNNED: return Color(1.0, 0.9, 0.3)  # Yellow
		Enums.Condition.SILENCED: return Color(0.6, 0.6, 0.8)  # Pale blue
		Enums.Condition.ARMORED: return Color(1.0, 0.85, 0.3)  # Gold
		Enums.Condition.BLINDED: return Color(1.0, 1.0, 0.8)  # White-yellow
		Enums.Condition.SLOWED: return Color(0.6, 0.4, 0.9)  # Purple
		Enums.Condition.HASTED: return Color(1.0, 0.85, 0.3)  # Gold
		Enums.Condition.KNOCKED_DOWN: return Color(0.8, 0.5, 0.3)  # Brown
		_: return Color.WHITE

func _get_condition_color(condition: Enums.Condition) -> Color:
	# Legacy function kept for compatibility
	return _get_condition_text_color(condition)

## Show a notification message
func show_notification(message: String) -> void:
	notification_queue.append(message)
	if notification_timer <= 0:
		_show_next_notification()

func _show_next_notification() -> void:
	if notification_queue.is_empty():
		return

	var message: String = notification_queue.pop_front()
	if notification_label:
		notification_label.text = message
	notification_timer = NOTIFICATION_DURATION

## Spawn a floating damage number
func spawn_damage_number(world_position: Vector3, damage: int, is_crit: bool = false, is_heal: bool = false) -> void:
	if not damage_number_scene:
		return

	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	# Convert world position to screen position
	var screen_pos := camera.unproject_position(world_position)

	# Check if on screen
	if not camera.is_position_behind(world_position):
		var dmg_num := damage_number_scene.instantiate()
		if damage_numbers_container:
			damage_numbers_container.add_child(dmg_num)
		else:
			add_child(dmg_num)

		if dmg_num is Control:
			(dmg_num as Control).position = screen_pos

		if dmg_num.has_method("setup"):
			dmg_num.setup(damage, is_heal, is_crit)

## Signal handlers

func _on_hp_changed(_old: int, _new: int, _max: int) -> void:
	# Bars update in process, but could trigger effects here
	pass

func _on_level_up(new_level: int) -> void:
	show_notification("LEVEL UP!")
	log_level_up(new_level)
	AudioManager.play_ui_confirm()

func _on_condition_applied(condition: Enums.Condition) -> void:
	var condition_name := _get_condition_name(condition)
	show_notification(condition_name + " applied!")

func _on_condition_removed(condition: Enums.Condition) -> void:
	var condition_name := _get_condition_name(condition)
	show_notification(condition_name + " removed")

func _on_gold_changed(old_amount: int, new_amount: int) -> void:
	var diff := new_amount - old_amount
	if diff > 0:
		log_gold_gained(diff)
	elif diff < 0:
		log_gold_spent(-diff)

func _on_item_added(item_id: String, quantity: int) -> void:
	var item_name := InventoryManager.get_item_name(item_id)
	log_item_received(item_name, quantity)

func _on_quick_slot_changed(slot: int, _item_id: String) -> void:
	_update_quick_slot(slot)

func _on_damage_dealt(_attacker: Node, target: Node, damage: int, _type: Enums.DamageType) -> void:
	if target is Node3D:
		spawn_damage_number((target as Node3D).global_position + Vector3.UP * 2, damage)

func _on_critical_hit(_attacker: Node, target: Node) -> void:
	if target is Node3D:
		spawn_damage_number((target as Node3D).global_position + Vector3.UP * 2.5, 0, true)

func _on_xp_gained(amount: int) -> void:
	log_xp_gained(amount)

func _on_quest_started(quest_id: String) -> void:
	var quest := QuestManager.get_quest(quest_id)
	if quest:
		log_quest_started(quest.title)

func _on_quest_completed(quest_id: String) -> void:
	var quest := QuestManager.get_quest(quest_id)
	if quest:
		log_quest_completed(quest.title)

func _on_objective_completed(quest_id: String, _objective_id: String) -> void:
	var quest := QuestManager.get_quest(quest_id)
	if quest:
		# Count remaining objectives
		var remaining := 0
		for obj in quest.objectives:
			if not obj.is_completed and not obj.is_optional:
				remaining += 1
		if remaining > 0:
			log_quest_updated("Objective complete (%d remaining)" % remaining)
		else:
			log_quest_updated("All objectives complete!")

func _update_quick_slot(slot: int) -> void:
	if slot < 0 or slot >= quick_slot_icons.size():
		return

	var item_id: String = InventoryManager.quick_slots[slot]
	var slot_ui: Control = quick_slot_icons[slot]

	if item_id.is_empty():
		var icon := slot_ui.get_node_or_null("Icon") as TextureRect
		if icon:
			icon.texture = null
		var count := slot_ui.get_node_or_null("Count") as Label
		if count:
			count.text = ""
	else:
		# Load item data and display
		var count := InventoryManager.get_item_count(item_id)
		var count_label := slot_ui.get_node_or_null("Count") as Label
		if count_label:
			count_label.text = str(count) if count > 1 else ""

## Setup interaction prompt label
func _setup_interaction_prompt() -> void:
	interaction_prompt_label = Label.new()
	interaction_prompt_label.name = "InteractionPrompt"
	interaction_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Position at bottom center of screen
	interaction_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_prompt_label.offset_top = -60
	interaction_prompt_label.offset_bottom = -40
	interaction_prompt_label.offset_left = -200
	interaction_prompt_label.offset_right = 200

	# Style it
	interaction_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	interaction_prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	interaction_prompt_label.add_theme_constant_override("outline_size", 2)

	interaction_prompt_label.visible = false
	add_child(interaction_prompt_label)

## Show interaction prompt
func show_interaction_prompt(text: String) -> void:
	if interaction_prompt_label:
		interaction_prompt_label.text = "[E] " + text
		interaction_prompt_label.visible = true

## Hide interaction prompt
func hide_interaction_prompt() -> void:
	if interaction_prompt_label:
		interaction_prompt_label.visible = false

## Setup death screen
func _setup_death_screen() -> void:
	# Design resolution - canvas renders at this size with viewport stretch mode
	const DESIGN_WIDTH := 640
	const DESIGN_HEIGHT := 480

	# Create full-screen black background at design resolution
	death_screen = ColorRect.new()
	death_screen.name = "DeathScreen"
	death_screen.color = Color(0, 0, 0, 0.95)
	death_screen.position = Vector2.ZERO
	death_screen.size = Vector2(DESIGN_WIDTH, DESIGN_HEIGHT)
	death_screen.visible = false
	death_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(death_screen)

	# Create "YOU DIED" label - centered horizontally, slightly above center vertically
	var death_label := Label.new()
	death_label.name = "DeathLabel"
	death_label.text = "YOU DIED"
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))  # Dark red
	death_label.add_theme_font_size_override("font_size", 72)
	death_label.size = Vector2(400, 100)
	death_label.position = Vector2((DESIGN_WIDTH - 400) / 2, (DESIGN_HEIGHT / 2) - 140)
	death_screen.add_child(death_label)

	# Button container for vertical stacking
	var button_container := VBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.size = Vector2(220, 180)
	button_container.position = Vector2((DESIGN_WIDTH - 220) / 2, (DESIGN_HEIGHT / 2) - 20)
	button_container.add_theme_constant_override("separation", 10)
	death_screen.add_child(button_container)

	# Load Last Autosave button (primary option)
	death_load_autosave_button = Button.new()
	death_load_autosave_button.name = "LoadAutosaveButton"
	death_load_autosave_button.text = "Load Last Autosave"
	death_load_autosave_button.custom_minimum_size = Vector2(220, 40)
	death_load_autosave_button.pressed.connect(_on_death_load_autosave)
	button_container.add_child(death_load_autosave_button)

	# Load Save button (opens save select)
	death_load_save_button = Button.new()
	death_load_save_button.name = "LoadSaveButton"
	death_load_save_button.text = "Load Save..."
	death_load_save_button.custom_minimum_size = Vector2(220, 40)
	death_load_save_button.pressed.connect(_on_death_load_save)
	button_container.add_child(death_load_save_button)

	# New Game button (full restart)
	death_restart_button = Button.new()
	death_restart_button.name = "NewGameButton"
	death_restart_button.text = "New Game"
	death_restart_button.custom_minimum_size = Vector2(220, 40)
	death_restart_button.pressed.connect(_on_death_new_game)
	button_container.add_child(death_restart_button)

	# Create save select panel (hidden by default)
	_setup_death_save_select()

	# Connect to player death signal
	if GameManager.has_signal("player_died"):
		GameManager.player_died.connect(_on_player_died)

## Setup save select panel for death screen
func _setup_death_save_select() -> void:
	const DESIGN_WIDTH := 640
	const DESIGN_HEIGHT := 480

	death_save_select_panel = Panel.new()
	death_save_select_panel.name = "SaveSelectPanel"
	death_save_select_panel.size = Vector2(400, 350)
	death_save_select_panel.position = Vector2((DESIGN_WIDTH - 400) / 2, (DESIGN_HEIGHT - 350) / 2)
	death_save_select_panel.visible = false
	death_screen.add_child(death_save_select_panel)

	# Title
	var title := Label.new()
	title.text = "Select Save to Load"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.position = Vector2(0, 10)
	title.size = Vector2(400, 30)
	death_save_select_panel.add_child(title)

	# Scroll container for saves
	var scroll := ScrollContainer.new()
	scroll.name = "SaveScroll"
	scroll.position = Vector2(10, 50)
	scroll.size = Vector2(380, 240)
	death_save_select_panel.add_child(scroll)

	var save_list := VBoxContainer.new()
	save_list.name = "SaveList"
	save_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(save_list)

	# Back button
	var back_button := Button.new()
	back_button.text = "Back"
	back_button.position = Vector2(150, 300)
	back_button.size = Vector2(100, 35)
	back_button.pressed.connect(_on_death_save_select_back)
	death_save_select_panel.add_child(back_button)

## Show death screen
func show_death_screen() -> void:
	if death_screen:
		# Track death
		SaveManager.increment_death_count()

		# Update autosave button availability - check both autosave slots
		if death_load_autosave_button:
			var has_autosave: bool = SaveManager.save_exists(SaveManager.AUTOSAVE_EXIT_SLOT) or SaveManager.save_exists(SaveManager.AUTOSAVE_PERIODIC_SLOT)
			death_load_autosave_button.disabled = not has_autosave
			if not has_autosave:
				death_load_autosave_button.text = "No Autosave Found"
			else:
				death_load_autosave_button.text = "Load Last Autosave"

		death_screen.visible = true
		if death_save_select_panel:
			death_save_select_panel.visible = false

		# Show mouse cursor for button interaction
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# Pause the game
		get_tree().paused = true

## Handle player death signal
func _on_player_died() -> void:
	show_death_screen()

## Load autosave on death - prefer exit autosave, fallback to periodic
func _on_death_load_autosave() -> void:
	# Determine which autosave slot to load (prefer exit, fallback to periodic)
	var slot_to_load: int = -1
	if SaveManager.save_exists(SaveManager.AUTOSAVE_EXIT_SLOT):
		slot_to_load = SaveManager.AUTOSAVE_EXIT_SLOT
	elif SaveManager.save_exists(SaveManager.AUTOSAVE_PERIODIC_SLOT):
		slot_to_load = SaveManager.AUTOSAVE_PERIODIC_SLOT

	if slot_to_load < 0:
		push_warning("[HUD] No autosave found to load")
		return

	_load_save_slot(slot_to_load)

## Shared function to load a save slot from death screen
func _load_save_slot(slot: int) -> void:
	# Get save info BEFORE loading to get the scene path
	var save_info: Dictionary = SaveManager.get_save_info(slot)
	var scene_path: String = save_info.get("current_scene", "")

	if scene_path.is_empty():
		push_warning("[HUD] Save has no current_scene, falling back to Elder Moor")
		scene_path = "res://scenes/levels/elder_moor.tscn"

	# Hide death screen and unpause
	if death_screen:
		death_screen.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Load the save data (restores player stats, inventory, etc.)
	if not SaveManager.load_game(slot):
		push_error("[HUD] Failed to load save slot %d" % slot)
		# Show death screen again on failure
		show_death_screen()
		return

	# Change to the saved scene
	print("[HUD] Loading save - changing to scene: %s" % scene_path)
	SceneManager.change_scene(scene_path)

## Open save select panel
func _on_death_load_save() -> void:
	if not death_save_select_panel:
		return

	# Populate save list
	_populate_death_save_list()
	death_save_select_panel.visible = true

## Populate save list in death screen
func _populate_death_save_list() -> void:
	var save_list := death_save_select_panel.get_node_or_null("SaveScroll/SaveList") as VBoxContainer
	if not save_list:
		return

	# Clear existing entries
	for child in save_list.get_children():
		child.queue_free()

	# Get all saves
	var saves := SaveManager.get_all_save_infos()
	var has_any_save := false

	for save_info in saves:
		var slot: int = save_info.get("slot", -1)
		if save_info.get("empty", true):
			continue

		has_any_save = true

		var entry := Button.new()
		var char_name: String = save_info.get("character_name", "Unknown")
		var level: int = save_info.get("level", 1)
		var location: String = save_info.get("location", "Unknown")
		var datetime: String = save_info.get("datetime", "")

		# Format slot name
		var slot_name: String = "Slot %d" % slot
		if slot == SaveManager.AUTOSAVE_EXIT_SLOT:
			slot_name = "Exit Autosave"
		elif slot == SaveManager.AUTOSAVE_PERIODIC_SLOT:
			slot_name = "30s Autosave"
		elif slot == 0:
			slot_name = "Quick Save"

		entry.text = "%s - %s (Lv.%d) - %s" % [slot_name, char_name, level, location]
		entry.tooltip_text = datetime
		entry.custom_minimum_size = Vector2(360, 35)
		entry.pressed.connect(_on_death_load_slot.bind(slot))
		save_list.add_child(entry)

	if not has_any_save:
		var no_saves := Label.new()
		no_saves.text = "No saves found"
		no_saves.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_saves.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		save_list.add_child(no_saves)

## Load specific save slot from death screen
func _on_death_load_slot(slot: int) -> void:
	_load_save_slot(slot)

## Go back from save select panel
func _on_death_save_select_back() -> void:
	if death_save_select_panel:
		death_save_select_panel.visible = false

## Start a completely new game
func _on_death_new_game() -> void:
	# Unpause first
	get_tree().paused = false

	# Reset all game state
	GameManager.reset_for_new_game()
	InventoryManager.reset_for_new_game()
	QuestManager.reset_for_new_game()
	SaveManager.reset_world_state()

	# Go to character creation for a fresh start
	get_tree().change_scene_to_file("res://scenes/ui/character_creation.tscn")

## Setup durability warning label
func _setup_durability_warning() -> void:
	durability_warning_label = Label.new()
	durability_warning_label.name = "DurabilityWarning"
	durability_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	durability_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Position at top-left, below the health/stamina bars
	durability_warning_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	durability_warning_label.offset_top = 80
	durability_warning_label.offset_left = 10
	durability_warning_label.offset_right = 250
	durability_warning_label.offset_bottom = 100

	# Style with red warning color
	durability_warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	durability_warning_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	durability_warning_label.add_theme_constant_override("outline_size", 2)

	durability_warning_label.visible = false
	add_child(durability_warning_label)

## Update durability warning (called every frame, but checks every DURABILITY_CHECK_INTERVAL)
## Only shows warnings for LOW (about to break) or BROKEN items
func _update_durability_warning(delta: float) -> void:
	durability_check_timer += delta
	if durability_check_timer < DURABILITY_CHECK_INTERVAL:
		return

	durability_check_timer = 0.0

	if not durability_warning_label:
		return

	# Check all equipment slots for LOW or BROKEN durability
	var low_slots: Array[String] = []
	var broken_slots: Array[String] = []
	var slot_display_names: Dictionary = {
		"main_hand": "Weapon",
		"off_hand": "Shield",
		"head": "Helm",
		"body": "Armor",
		"hands": "Gloves",
		"feet": "Boots"
	}

	for slot in ["main_hand", "off_hand", "head", "body", "hands", "feet"]:
		if InventoryManager.equipment[slot].is_empty():
			continue

		var state: InventoryManager.DurabilityState = InventoryManager.get_equipment_durability_state(slot)
		var display_name: String = slot_display_names.get(slot, slot)

		if state == InventoryManager.DurabilityState.BROKEN:
			broken_slots.append(display_name)
		elif state == InventoryManager.DurabilityState.LOW:
			low_slots.append(display_name)

	if low_slots.is_empty() and broken_slots.is_empty():
		durability_warning_label.visible = false
	else:
		# Flash effect using time-based modulation
		var flash_alpha := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.005)
		durability_warning_label.modulate.a = flash_alpha

		# Build warning text - BROKEN takes priority over LOW
		var warning_text := ""
		if not broken_slots.is_empty():
			# Red warning for broken items
			durability_warning_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
			warning_text = "!! " + " / ".join(broken_slots) + " BROKEN!"
		elif not low_slots.is_empty():
			# Orange-red for low items
			durability_warning_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
			warning_text = "! " + " / ".join(low_slots) + " Low!"

		durability_warning_label.text = warning_text
		durability_warning_label.visible = true

## Handle item degradation notification
func _on_item_degraded(_slot: String, item_id: String, new_quality: Enums.ItemQuality) -> void:
	var item_name := InventoryManager.get_item_name(item_id)
	var quality_name := _get_quality_display_name(new_quality)
	show_notification("Your %s has degraded to %s quality!" % [item_name, quality_name])

## Handle item repair notification
func _on_item_repaired(_slot: String, item_id: String, _durability_restored: int) -> void:
	var item_name := InventoryManager.get_item_name(item_id)
	show_notification("%s repaired!" % item_name)

## Get human-readable quality name
func _get_quality_display_name(quality: Enums.ItemQuality) -> String:
	match quality:
		Enums.ItemQuality.POOR:
			return "Poor"
		Enums.ItemQuality.BELOW_AVERAGE:
			return "Worn"
		Enums.ItemQuality.AVERAGE:
			return "Average"
		Enums.ItemQuality.ABOVE_AVERAGE:
			return "Fine"
		Enums.ItemQuality.PERFECT:
			return "Perfect"
		_:
			return "Unknown"

## Setup game log container (bottom-right side panel)
func _setup_game_log() -> void:
	game_log_container = VBoxContainer.new()
	game_log_container.name = "GameLog"

	# Position at bottom-right
	game_log_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	game_log_container.anchor_left = 1.0
	game_log_container.anchor_right = 1.0
	game_log_container.anchor_top = 1.0
	game_log_container.anchor_bottom = 1.0
	game_log_container.offset_left = -280
	game_log_container.offset_right = -10
	game_log_container.offset_top = -200
	game_log_container.offset_bottom = -10

	# Align entries to bottom (newest at bottom)
	game_log_container.alignment = BoxContainer.ALIGNMENT_END
	game_log_container.add_theme_constant_override("separation", 2)

	add_child(game_log_container)

## Add an entry to the game log
func add_log_entry(message: String, color: Color = Color.WHITE) -> void:
	if not game_log_container:
		return

	var label := Label.new()
	label.text = message
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 260

	# Store timestamp for fading
	label.set_meta("spawn_time", Time.get_ticks_msec() / 1000.0)

	game_log_container.add_child(label)
	game_log_entries.append(label)

	# Remove oldest entries if over limit
	while game_log_entries.size() > MAX_LOG_ENTRIES:
		var old_entry: Control = game_log_entries.pop_front()
		old_entry.queue_free()

## Update game log (fade out old entries)
func _update_game_log(_delta: float) -> void:
	if not game_log_container:
		return

	var current_time := Time.get_ticks_msec() / 1000.0
	var entries_to_remove: Array[Control] = []

	for entry in game_log_entries:
		if not is_instance_valid(entry):
			entries_to_remove.append(entry)
			continue

		var spawn_time: float = entry.get_meta("spawn_time", current_time)
		var age := current_time - spawn_time

		if age > LOG_FADE_DURATION:
			entries_to_remove.append(entry)
		elif age > LOG_FADE_START:
			# Fade out
			var fade_progress := (age - LOG_FADE_START) / (LOG_FADE_DURATION - LOG_FADE_START)
			entry.modulate.a = 1.0 - fade_progress

	# Remove expired entries
	for entry in entries_to_remove:
		game_log_entries.erase(entry)
		if is_instance_valid(entry):
			entry.queue_free()

## Convenience methods for different log types
func log_xp_gained(amount: int) -> void:
	add_log_entry("+%d XP" % amount, Color(0.4, 0.8, 1.0))  # Light blue

func log_gold_gained(amount: int) -> void:
	add_log_entry("+%d Gold" % amount, Color(1.0, 0.85, 0.3))  # Gold color

func log_gold_spent(amount: int) -> void:
	add_log_entry("-%d Gold" % amount, Color(0.8, 0.6, 0.2))  # Darker gold

func log_item_received(item_name: String, quantity: int = 1) -> void:
	if quantity > 1:
		add_log_entry("+ %s x%d" % [item_name, quantity], Color(0.7, 0.9, 0.7))
	else:
		add_log_entry("+ %s" % item_name, Color(0.7, 0.9, 0.7))

func log_quest_started(quest_name: String) -> void:
	add_log_entry("Quest: %s" % quest_name, Color(1.0, 0.9, 0.5))

func log_quest_updated(message: String) -> void:
	add_log_entry(message, Color(0.9, 0.85, 0.6))

func log_quest_completed(quest_name: String) -> void:
	add_log_entry("Completed: %s" % quest_name, Color(0.5, 1.0, 0.5))

func log_level_up(new_level: int) -> void:
	add_log_entry("LEVEL UP! Now level %d" % new_level, Color(1.0, 1.0, 0.3))

func log_combat(message: String) -> void:
	add_log_entry(message, Color(0.9, 0.5, 0.5))  # Light red

## Setup compass at top-center of screen
func _setup_compass() -> void:
	# Container with clipping mask
	compass_container = Control.new()
	compass_container.name = "CompassContainer"
	compass_container.clip_contents = true
	compass_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass_container.offset_left = -COMPASS_WIDTH / 2
	compass_container.offset_right = COMPASS_WIDTH / 2
	compass_container.offset_top = 8
	compass_container.offset_bottom = 8 + COMPASS_HEIGHT
	add_child(compass_container)

	# Background panel
	var bg := ColorRect.new()
	bg.name = "CompassBG"
	bg.color = Color(0.1, 0.1, 0.12, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	compass_container.add_child(bg)

	# Center tick mark (indicates current heading)
	var center_tick := ColorRect.new()
	center_tick.name = "CenterTick"
	center_tick.color = Color(1.0, 0.9, 0.6)
	center_tick.size = Vector2(2, COMPASS_HEIGHT)
	center_tick.position = Vector2(COMPASS_WIDTH / 2 - 1, 0)
	compass_container.add_child(center_tick)

	# Strip that holds the direction markers (wider than container, scrolls)
	compass_strip = Control.new()
	compass_strip.name = "CompassStrip"
	compass_strip.size = Vector2(COMPASS_WIDTH * 2, COMPASS_HEIGHT)
	compass_strip.position = Vector2(-COMPASS_WIDTH / 2, 0)
	compass_container.add_child(compass_strip)

	# Create direction markers for the strip
	# Full rotation = 360 degrees, strip covers 720 degrees worth for seamless wrapping
	var directions: Array[Dictionary] = [
		{"label": "N", "angle": 0.0, "is_cardinal": true},
		{"label": "NE", "angle": 45.0, "is_cardinal": false},
		{"label": "E", "angle": 90.0, "is_cardinal": true},
		{"label": "SE", "angle": 135.0, "is_cardinal": false},
		{"label": "S", "angle": 180.0, "is_cardinal": true},
		{"label": "SW", "angle": 225.0, "is_cardinal": false},
		{"label": "W", "angle": 270.0, "is_cardinal": true},
		{"label": "NW", "angle": 315.0, "is_cardinal": false},
	]

	# Create two sets of markers for seamless wrap
	for offset in [0.0, 360.0]:
		for dir_data in directions:
			var marker := Label.new()
			marker.text = dir_data.label
			marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

			# Cardinals are larger and brighter
			if dir_data.is_cardinal:
				marker.add_theme_font_size_override("font_size", 14)
				marker.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
			else:
				marker.add_theme_font_size_override("font_size", 10)
				marker.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))

			marker.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			marker.add_theme_constant_override("outline_size", 1)

			# Store the angle for positioning
			marker.set_meta("compass_angle", dir_data.angle + offset)

			marker.size = Vector2(30, COMPASS_HEIGHT)
			compass_strip.add_child(marker)
			compass_markers.append(marker)

	# Add tick marks between directions
	for offset in [0.0, 360.0]:
		for i in range(16):
			var tick_angle: float = i * 22.5 + offset
			# Skip where labels are
			if int(tick_angle) % 45 == 0:
				continue
			var tick := ColorRect.new()
			tick.color = Color(0.5, 0.5, 0.5, 0.5)
			tick.size = Vector2(1, 6)
			tick.set_meta("compass_angle", tick_angle)
			compass_strip.add_child(tick)
			# We don't track ticks in compass_markers since they use same update logic


## Setup minimap with quest markers and cell coordinates
func _setup_minimap() -> void:
	# Create minimap instance
	minimap = Minimap.new()
	minimap.name = "Minimap"
	add_child(minimap)

	# Create cell coordinates label below minimap
	minimap_coord_label = Label.new()
	minimap_coord_label.name = "CellCoordinates"
	minimap_coord_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap_coord_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap_coord_label.offset_left = -130
	minimap_coord_label.offset_right = -10
	minimap_coord_label.offset_top = 165  # Below minimap
	minimap_coord_label.offset_bottom = 185
	minimap_coord_label.add_theme_font_size_override("font_size", 14)
	minimap_coord_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	minimap_coord_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	minimap_coord_label.add_theme_constant_override("outline_size", 2)
	minimap_coord_label.text = "(0, 0)"
	add_child(minimap_coord_label)


## Update minimap cell coordinates display
func _update_minimap_coordinates() -> void:
	if not minimap_coord_label or not _cached_player:
		return

	# Get current wilderness room if in open world
	var wilderness_room := get_tree().get_first_node_in_group("wilderness_room")
	if wilderness_room and "grid_coords" in wilderness_room:
		var coords: Vector2i = wilderness_room.grid_coords
		minimap_coord_label.text = "(%d, %d)" % [coords.x, coords.y]
		minimap_coord_label.visible = true
	else:
		# In a dungeon or town - show zone name instead
		var zone_name: String = MapTracker.get_current_zone() if MapTracker else ""
		if zone_name.is_empty():
			minimap_coord_label.visible = false
		else:
			minimap_coord_label.text = zone_name.replace("_", " ").capitalize()
			minimap_coord_label.visible = true


## Update compass based on player rotation
func _update_compass() -> void:
	if not compass_strip:
		return

	# Use cached player reference (validated in _process)
	if not _cached_player or not is_instance_valid(_cached_player) or not _cached_player.is_inside_tree():
		return
	var player: Node3D = _cached_player

	# Get camera yaw if available, otherwise player yaw
	var camera := get_viewport().get_camera_3d()
	var yaw_degrees: float = 0.0
	if camera:
		yaw_degrees = rad_to_deg(-camera.global_rotation.y)
	else:
		yaw_degrees = rad_to_deg(-player.global_rotation.y)

	# Normalize to 0-360
	yaw_degrees = fmod(yaw_degrees + 360.0, 360.0)

	# Position markers based on current heading
	# Pixels per degree
	var ppd := COMPASS_WIDTH / 90.0  # Show 90 degrees of view in the compass

	for child in compass_strip.get_children():
		if not child.has_meta("compass_angle"):
			continue

		var marker_angle: float = child.get_meta("compass_angle")

		# Calculate relative angle from current heading
		var rel_angle := marker_angle - yaw_degrees

		# Wrap to -180 to 180 for the first set
		while rel_angle < -180.0:
			rel_angle += 360.0
		while rel_angle > 180.0:
			rel_angle -= 360.0

		# Position on strip (center is at COMPASS_WIDTH / 2 relative to strip's position in container)
		# Since strip is offset by -COMPASS_WIDTH/2, and container clips to COMPASS_WIDTH,
		# marker at center of container should be at strip position COMPASS_WIDTH
		var x_pos := COMPASS_WIDTH + rel_angle * ppd

		if child is Label:
			child.position.x = x_pos - child.size.x / 2
			child.position.y = (COMPASS_HEIGHT - child.size.y) / 2
		else:
			# Tick marks
			child.position.x = x_pos
			child.position.y = COMPASS_HEIGHT - child.size.y - 2

	# Update POI markers (currently disabled)
	_update_compass_pois(player, yaw_degrees, ppd)

	# Update enemy radar markers (INTUITION skill)
	_update_compass_enemies(player, yaw_degrees, ppd)

	# Update harvestable plant markers (HERBALISM skill 5+)
	_update_compass_plants(player, yaw_degrees, ppd)

	# Update compass quest marker (points to objective or door)
	_update_compass_quest_marker(player, yaw_degrees, ppd)


## Update POI markers on compass
## DISABLED: POI markers were cluttering the compass - disabled for now
func _update_compass_pois(_player: Node3D, _yaw_degrees: float, _ppd: float) -> void:
	# POI markers disabled - return early
	# Clear any existing markers
	for poi_id: String in compass_poi_markers:
		var marker: Label = compass_poi_markers[poi_id]
		if is_instance_valid(marker):
			marker.queue_free()
	compass_poi_markers.clear()
	# Note: POI marker code removed - can restore from git if needed


## Create a POI marker for the compass
func _create_poi_marker(poi_node: Node3D) -> Label:
	var marker := Label.new()
	var poi_name: String = poi_node.get_meta("display_name", poi_node.get_meta("poi_name", "?"))
	var poi_color: Color = poi_node.get_meta("poi_color", Color.WHITE)
	var poi_icon: String = poi_node.get_meta("poi_icon", "◆")  # Default diamond

	# Use custom icon or default diamond
	marker.text = poi_icon
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 14)
	marker.add_theme_color_override("font_color", poi_color)
	marker.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	marker.add_theme_constant_override("outline_size", 2)
	marker.tooltip_text = poi_name
	marker.size = Vector2(20, COMPASS_HEIGHT)

	compass_strip.add_child(marker)
	return marker


## Update enemy radar markers on compass (INTUITION skill)
## Shows red dots for nearby enemies based on player's INTUITION skill level
func _update_compass_enemies(player: Node3D, yaw_degrees: float, ppd: float) -> void:
	# Get player's INTUITION skill to determine detection range
	var intuition_level: int = 0
	if GameManager.player_data:
		intuition_level = GameManager.player_data.get_skill(Enums.Skill.INTUITION)

	# Calculate detection range: base + (INTUITION * bonus per level)
	var detection_range: float = ENEMY_DETECTION_BASE + (intuition_level * ENEMY_DETECTION_PER_INTUITION)

	# Get all enemies in the scene
	var enemies := get_tree().get_nodes_in_group("enemies")

	# Track which enemy IDs are still valid this frame
	var valid_enemy_ids: Dictionary = {}

	for enemy in enemies:
		if not enemy is Node3D:
			continue

		var enemy_node := enemy as Node3D

		# Skip dead enemies
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue

		var enemy_id: int = enemy_node.get_instance_id()
		valid_enemy_ids[enemy_id] = true

		# Calculate distance to enemy
		var to_enemy := enemy_node.global_position - player.global_position
		var distance := to_enemy.length()

		# Skip if too far (beyond detection range)
		if distance > detection_range:
			if compass_enemy_markers.has(enemy_id):
				compass_enemy_markers[enemy_id].visible = false
			continue

		# Calculate angle to enemy (in degrees, 0 = north/+Z)
		var enemy_angle := rad_to_deg(atan2(-to_enemy.x, -to_enemy.z))
		enemy_angle = fmod(enemy_angle + 360.0, 360.0)

		# Get or create marker
		var marker: Label
		if compass_enemy_markers.has(enemy_id):
			marker = compass_enemy_markers[enemy_id]
			# Validate the marker is still valid
			if not is_instance_valid(marker):
				marker = _create_enemy_marker()
				compass_enemy_markers[enemy_id] = marker
		else:
			marker = _create_enemy_marker()
			compass_enemy_markers[enemy_id] = marker

		# Calculate relative angle
		var rel_angle := enemy_angle - yaw_degrees
		while rel_angle < -180.0:
			rel_angle += 360.0
		while rel_angle > 180.0:
			rel_angle -= 360.0

		# Position marker
		var x_pos := COMPASS_WIDTH + rel_angle * ppd
		marker.position.x = x_pos - marker.size.x / 2
		marker.position.y = COMPASS_HEIGHT - 10  # Position at bottom of compass

		# Fade based on distance (closer = more opaque)
		var alpha := 1.0 - (distance / detection_range) * 0.5  # Fade from 1.0 to 0.5
		marker.modulate.a = alpha

		# Only show if within view arc (roughly 90 degrees)
		marker.visible = abs(rel_angle) < 50.0

	# Clean up stale enemy markers
	var stale_ids: Array[int] = []
	for enemy_id in compass_enemy_markers:
		var marker = compass_enemy_markers[enemy_id]
		if not valid_enemy_ids.has(enemy_id) or not is_instance_valid(marker):
			stale_ids.append(enemy_id)

	# Remove stale entries
	for enemy_id in stale_ids:
		var marker = compass_enemy_markers.get(enemy_id)
		compass_enemy_markers.erase(enemy_id)
		if marker and is_instance_valid(marker):
			marker.queue_free()


## Create an enemy radar marker for the compass (red dot)
func _create_enemy_marker() -> Label:
	var marker := Label.new()

	# Small red circle/dot for enemy
	marker.text = "●"  # Filled circle
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 10)
	marker.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))  # Red for enemies
	marker.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	marker.add_theme_constant_override("outline_size", 1)
	marker.tooltip_text = "Enemy"
	marker.size = Vector2(16, COMPASS_HEIGHT)

	compass_strip.add_child(marker)
	return marker


## Update harvestable plant markers on compass (HERBALISM skill)
## Shows green dots for nearby plants if player has HERBALISM 5+
func _update_compass_plants(player: Node3D, yaw_degrees: float, ppd: float) -> void:
	# Check if player has minimum HERBALISM skill
	var herbalism_level: int = 0
	if GameManager.player_data:
		herbalism_level = GameManager.player_data.get_skill(Enums.Skill.HERBALISM)

	# If HERBALISM is below threshold, hide all plant markers and return
	if herbalism_level < PLANT_DETECTION_MIN_HERBALISM:
		for plant_id in compass_plant_markers:
			var marker = compass_plant_markers[plant_id]
			if is_instance_valid(marker):
				marker.visible = false
		return

	# Get all harvestable plants in the scene
	var plants := get_tree().get_nodes_in_group("harvestable_plants")

	# Track which plant IDs are still valid this frame
	var valid_plant_ids: Dictionary = {}

	for plant in plants:
		if not plant is Node3D:
			continue

		var plant_node := plant as Node3D

		# Skip harvested plants
		if "has_been_harvested" in plant and plant.has_been_harvested:
			continue

		var plant_id: int = plant_node.get_instance_id()
		valid_plant_ids[plant_id] = true

		# Calculate distance to plant
		var to_plant := plant_node.global_position - player.global_position
		var distance := to_plant.length()

		# Skip if too far
		if distance > PLANT_DETECTION_RANGE:
			if compass_plant_markers.has(plant_id):
				compass_plant_markers[plant_id].visible = false
			continue

		# Calculate angle to plant (in degrees, 0 = north/+Z)
		var plant_angle := rad_to_deg(atan2(-to_plant.x, -to_plant.z))
		plant_angle = fmod(plant_angle + 360.0, 360.0)

		# Get or create marker
		var marker: Label
		if compass_plant_markers.has(plant_id):
			marker = compass_plant_markers[plant_id]
			if not is_instance_valid(marker):
				marker = _create_plant_marker()
				compass_plant_markers[plant_id] = marker
		else:
			marker = _create_plant_marker()
			compass_plant_markers[plant_id] = marker

		# Calculate relative angle
		var rel_angle := plant_angle - yaw_degrees
		while rel_angle < -180.0:
			rel_angle += 360.0
		while rel_angle > 180.0:
			rel_angle -= 360.0

		# Position marker
		var x_pos := COMPASS_WIDTH + rel_angle * ppd
		marker.position.x = x_pos - marker.size.x / 2
		marker.position.y = COMPASS_HEIGHT - 10  # Position at bottom of compass

		# Fade based on distance (closer = more opaque)
		var alpha := 1.0 - (distance / PLANT_DETECTION_RANGE) * 0.5
		marker.modulate.a = alpha

		# Only show if within view arc
		marker.visible = abs(rel_angle) < 50.0

	# Clean up stale plant markers
	var stale_ids: Array[int] = []
	for plant_id in compass_plant_markers:
		var marker = compass_plant_markers[plant_id]
		if not valid_plant_ids.has(plant_id) or not is_instance_valid(marker):
			stale_ids.append(plant_id)

	for plant_id in stale_ids:
		var marker = compass_plant_markers.get(plant_id)
		compass_plant_markers.erase(plant_id)
		if marker and is_instance_valid(marker):
			marker.queue_free()


## Create a plant marker for the compass (green dot)
func _create_plant_marker() -> Label:
	var marker := Label.new()

	# Small green circle for plant
	marker.text = "●"  # Filled circle
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 8)  # Smaller than enemies
	marker.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))  # Green for plants
	marker.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	marker.add_theme_constant_override("outline_size", 1)
	marker.tooltip_text = "Herb"
	marker.size = Vector2(14, COMPASS_HEIGHT)

	compass_strip.add_child(marker)
	return marker


## Update compass quest marker (points to objective or exit door)
## This is separate from the HUD quest tracker display
var _compass_debug_timer: float = 0.0
const COMPASS_DEBUG_ENABLED := false  # Set to true to enable compass debug logging
func _update_compass_quest_marker(player: Node3D, yaw_degrees: float, ppd: float) -> void:
	# Safety check - ensure player and tree are valid
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		if compass_quest_marker and is_instance_valid(compass_quest_marker):
			compass_quest_marker.visible = false
		return

	# Debug: Log tracking state periodically (every 5 seconds) - disabled by default
	_compass_debug_timer += get_process_delta_time()
	var should_log: bool = COMPASS_DEBUG_ENABLED and _compass_debug_timer >= 5.0
	if should_log:
		_compass_debug_timer = 0.0

	var tracked_id := QuestManager.get_tracked_quest_id()
	if should_log and not tracked_id.is_empty():
		print("[Compass] Tracking quest ID: %s" % tracked_id)

	# Get the tracked quest (user-selected from journal)
	var target_quest := QuestManager.get_tracked_quest()
	if not target_quest:
		if not tracked_id.is_empty():
			print("[Compass] WARNING: Quest ID '%s' is tracked but quest not found in quests dict" % tracked_id)
		if compass_quest_marker and is_instance_valid(compass_quest_marker):
			compass_quest_marker.visible = false
		return

	# Determine target position based on objective type and location
	var target_pos: Vector3 = Vector3.ZERO
	var has_target := false
	var target_name: String = ""

	# CRITICAL FIX: Check if ALL objectives are complete FIRST - should point to turn-in NPC
	var all_objectives_complete: bool = QuestManager.are_objectives_complete(target_quest.id)

	if all_objectives_complete:
		# Quest is ready for turn-in - point to quest giver
		if should_log:
			print("[Compass] All objectives complete for quest '%s', finding turn-in NPC" % target_quest.id)

		# Try to find turn-in NPC in current zone first
		var turnin_location := _find_turnin_npc_in_current_zone(target_quest)
		if turnin_location.found:
			target_pos = turnin_location.position
			has_target = true
			target_name = "Return to " + turnin_location.name
			if should_log:
				print("[Compass] Found turn-in NPC in zone: %s at %s" % [target_name, target_pos])
		else:
			# Turn-in NPC not in current zone - find exit to their zone
			var giver_zone := _get_quest_giver_zone(target_quest)
			if not giver_zone.is_empty():
				var exit_door := _find_exit_door_to_zone(giver_zone)
				if exit_door:
					target_pos = exit_door.global_position
					has_target = true
					target_name = "Return to turn in quest"
					if should_log:
						print("[Compass] Found exit to turn-in zone: %s at %s" % [giver_zone, target_pos])
	else:
		# Quest not complete - find first incomplete objective
		var target_objective: QuestManager.Objective = null

		for obj in target_quest.objectives:
			if not obj.is_completed and not obj.is_optional:
				target_objective = obj
				break

		if not target_objective:
			if compass_quest_marker and is_instance_valid(compass_quest_marker):
				compass_quest_marker.visible = false
			return

		target_name = target_objective.description

		# Check if objective can be found in current zone (pass quest for turn-in NPC lookup)
		var objective_location := _find_objective_in_current_zone(target_objective, target_quest)

		if objective_location.found:
			# Objective is in current zone - point directly to it
			target_pos = objective_location.position
			has_target = true
			target_name = objective_location.name
			if should_log:
				var turnin_status: String = " (TURN-IN)" if objective_location.get("is_turnin", false) else ""
				print("[Compass] Found objective in zone: %s at %s%s" % [target_name, target_pos, turnin_status])
		else:
			# Objective is not in current zone - determine where to go
			var target_zone: String = ""

			# Check if current objective is effectively complete (for multi-step)
			var objective_complete: bool = _is_objective_effectively_complete(target_objective)
			if objective_complete and target_quest:
				# Need to find quest giver's zone (usually town)
				var giver_zone := _get_quest_giver_zone(target_quest)
				if not giver_zone.is_empty():
					target_zone = giver_zone
					target_name = "Return to turn-in NPC"
					if should_log:
						print("[Compass] Objective complete, pointing to turn-in zone: %s" % target_zone)

			# If not complete (or no giver zone found), find the objective's zone
			if target_zone.is_empty():
				target_zone = _get_objective_target_zone(target_objective)
				if should_log:
					print("[Compass] Objective type: %s, target: %s, target_zone: %s" % [target_objective.type, target_objective.target, target_zone])

			# Fallback: if target_zone is empty and we're in town, point to wilderness
			if target_zone.is_empty():
				var current_zone := MapTracker.get_current_zone() if MapTracker else ""
				if current_zone in ["town", "riverside_village", "elder_moor", "village_elder_moor"]:
					target_zone = "open_world"
					if should_log:
						print("[Compass] Fallback: pointing to open_world from town")

			if not target_zone.is_empty():
				var exit_door := _find_exit_door_to_zone(target_zone)
				if exit_door and is_instance_valid(exit_door) and exit_door.is_inside_tree():
					target_pos = exit_door.global_position
					has_target = true
					target_name = "Exit: " + exit_door.door_name
					if should_log:
						print("[Compass] Found exit door: %s at %s" % [target_name, target_pos])
				# Note: No error print here - in wilderness, it's normal to not find doors
				# The compass marker will be hidden until player approaches an exit

	if not has_target:
		if compass_quest_marker and is_instance_valid(compass_quest_marker):
			compass_quest_marker.visible = false
		return

	# Determine if this is a main quest or side quest
	var is_main := target_quest.is_main_quest if target_quest else false

	# Create or update quest marker
	if not compass_quest_marker or not is_instance_valid(compass_quest_marker):
		compass_quest_marker = _create_quest_marker(is_main)
	else:
		# Update marker color based on current quest type
		if is_main:
			compass_quest_marker.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))  # Gold
		else:
			compass_quest_marker.add_theme_color_override("font_color", Color(0.2, 0.8, 0.8))  # Teal

	# Calculate angle to target
	var to_target := target_pos - player.global_position
	var target_angle := rad_to_deg(atan2(-to_target.x, -to_target.z))
	target_angle = fmod(target_angle + 360.0, 360.0)

	# Calculate relative angle
	var rel_angle := target_angle - yaw_degrees
	while rel_angle < -180.0:
		rel_angle += 360.0
	while rel_angle > 180.0:
		rel_angle -= 360.0

	# Position marker - center it on the compass strip
	var x_pos := COMPASS_WIDTH + rel_angle * ppd
	compass_quest_marker.position.x = x_pos - compass_quest_marker.size.x / 2
	compass_quest_marker.position.y = (COMPASS_HEIGHT - compass_quest_marker.size.y) / 2  # Center vertically

	# Update tooltip
	compass_quest_marker.tooltip_text = target_name

	# Quest markers visible when within compass FOV (50 degrees from center)
	var marker_visible: bool = abs(rel_angle) < 50.0
	compass_quest_marker.visible = marker_visible

	if should_log:
		print("[Compass] Marker for '%s' at angle %.1f deg, visible: %s, position: %.1f" % [
			target_name, rel_angle, marker_visible, compass_quest_marker.position.x
		])


## Create the quest tracker marker (distinct from POI markers)
## is_main_quest: true = gold marker (main story), false = teal marker (side quests/bounties)
func _create_quest_marker(is_main_quest: bool = true) -> Label:
	var marker := Label.new()
	marker.name = "QuestMarker"
	marker.text = "◆"  # Diamond - more visible than down arrow
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 16)

	# Color based on quest type - bright, high contrast colors
	if is_main_quest:
		marker.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))  # Gold for main quests
	else:
		marker.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8))  # Cyan for side/bounties

	marker.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	marker.add_theme_constant_override("outline_size", 2)
	marker.custom_minimum_size = Vector2(20, COMPASS_HEIGHT)
	marker.size = Vector2(20, COMPASS_HEIGHT)

	compass_strip.add_child(marker)
	return marker


## Find turn-in NPC for a complete quest in the current zone
## Wrapper around _find_quest_giver_position for consistency
func _find_turnin_npc_in_current_zone(quest: QuestManager.Quest) -> Dictionary:
	return _find_quest_giver_position(quest)


## Find the quest giver NPC position for turn-in
## Returns {found: bool, position: Vector3, name: String} or null if not found in current zone
func _find_quest_giver_position(quest: QuestManager.Quest) -> Dictionary:
	var result := {"found": false, "position": Vector3.ZERO, "name": "Quest Giver"}

	# First check if quest has a giver_npc_id
	var giver_id: String = quest.giver_npc_id
	var giver_name: String = ""

	# If no giver_npc_id on quest, check if this is a bounty quest via BountyManager
	if giver_id.is_empty() and quest.id.begins_with("quest_bounty"):
		# Extract bounty info from BountyManager
		for bounty_id: String in BountyManager.bounties:
			var bounty: BountyManager.Bounty = BountyManager.bounties[bounty_id]
			if bounty.quest_id == quest.id:
				giver_id = bounty.giver_npc_id
				giver_name = bounty.giver_npc_name
				result.name = giver_name
				break

	# Search for the NPC in current zone
	var npcs := get_tree().get_nodes_in_group("npcs")

	# First pass: try matching by npc_id (most reliable)
	if not giver_id.is_empty():
		for npc in npcs:
			if npc is Node3D:
				var npc_id_val: String = ""
				if "npc_id" in npc:
					npc_id_val = str(npc.get("npc_id"))

				if npc_id_val == giver_id:
					result.found = true
					result.position = (npc as Node3D).global_position
					if "display_name" in npc:
						result.name = str(npc.get("display_name"))
					elif "npc_name" in npc:
						result.name = str(npc.get("npc_name"))
					return result

	# Second pass: fallback to matching by npc_name or display_name (case-insensitive)
	# Use giver_name from bounty, or giver_id as a name if available
	var search_name: String = giver_name if not giver_name.is_empty() else giver_id
	if not search_name.is_empty():
		var search_lower: String = search_name.to_lower()
		for npc in npcs:
			if npc is Node3D:
				var npc_name_val: String = ""
				if "npc_name" in npc:
					npc_name_val = str(npc.get("npc_name"))
				elif "display_name" in npc:
					npc_name_val = str(npc.get("display_name"))

				if not npc_name_val.is_empty() and npc_name_val.to_lower() == search_lower:
					result.found = true
					result.position = (npc as Node3D).global_position
					result.name = npc_name_val
					return result

	return result


## Check if an objective is effectively complete (for turn-in purposes)
## For "collect" objectives, checks inventory; for others, checks current_count
func _is_objective_effectively_complete(objective: QuestManager.Objective) -> bool:
	match objective.type:
		"collect":
			# Check inventory for items
			var inventory_count: int = InventoryManager.get_item_count(objective.target)
			return inventory_count >= objective.required_count
		"kill", "destroy":
			return objective.current_count >= objective.required_count
		_:
			return objective.is_completed


## Get the zone where the quest giver NPC is located
## Returns the zone ID or empty string if unknown
func _get_quest_giver_zone(quest: QuestManager.Quest) -> String:
	# Check if quest has a giver_npc_id
	var giver_id: String = quest.giver_npc_id

	# If no giver_npc_id on quest, check if this is a bounty quest via BountyManager
	if giver_id.is_empty() and quest.id.begins_with("quest_bounty"):
		for bounty_id: String in BountyManager.bounties:
			var bounty: BountyManager.Bounty = BountyManager.bounties[bounty_id]
			if bounty.quest_id == quest.id:
				var settlement: String = bounty.giver_settlement
				if not settlement.is_empty():
					return _normalize_zone_id(settlement)
				break

	# For non-bounty quests, use quest metadata or lookup table
	if not giver_id.is_empty():
		# Check if quest has giver_zone metadata
		if "giver_zone" in quest and not quest.giver_zone.is_empty():
			return _normalize_zone_id(quest.giver_zone)

		# Common quest giver IDs and their zones
		var giver_zones: Dictionary = {
			# Elder Moor NPCs
			"wandering_knight": "elder_moor",
			"elder": "elder_moor",
			"village_elder": "elder_moor",
			"elder_moor_guard": "elder_moor",
			"mysterious_stranger": "elder_moor",
			# Guards can be in multiple zones - check quest origin
			"guard": "elder_moor",
			"town_guard": "elder_moor",
			# Dalhurst NPCs
			"dalhurst_contact": "dalhurst",
			"dalhurst_merchant": "dalhurst",
			"harbor_master": "dalhurst",
			# Other settlements
			"kazan_dun_smith": "kazan_dun",
			"aberdeen_mayor": "aberdeen",
		}

		if giver_zones.has(giver_id):
			return _normalize_zone_id(giver_zones[giver_id])

		# Check if giver_id contains a zone hint
		if "elder_moor" in giver_id or "elder" in giver_id:
			return "elder_moor"
		if "dalhurst" in giver_id:
			return "dalhurst"
		if "kazan" in giver_id:
			return "kazan_dun"

		# Default to starting town
		return "elder_moor"

	# Last resort - check if quest ID hints at origin
	if "elder_moor" in quest.id:
		return "elder_moor"

	return "elder_moor"  # Default fallback


## Normalize zone ID to a consistent format
func _normalize_zone_id(zone: String) -> String:
	var zone_lower: String = zone.to_lower()

	# Map various formats to canonical IDs
	if "elder" in zone_lower and "moor" in zone_lower:
		return "elder_moor"
	if "dalhurst" in zone_lower:
		return "dalhurst"
	if "kazan" in zone_lower:
		return "kazan_dun"
	if "aberdeen" in zone_lower:
		return "aberdeen"
	if "larton" in zone_lower:
		return "larton"
	if "falkenhafen" in zone_lower:
		return "falkenhafen"
	if "riverside" in zone_lower:
		return "riverside_village"

	return zone


## Find an objective target in the current zone
## Returns {found: bool, position: Vector3, name: String, is_turnin: bool}
## Enhanced to check inventory for "collect" objectives and point to turn-in NPC when ready
func _find_objective_in_current_zone(objective: QuestManager.Objective, quest: QuestManager.Quest = null) -> Dictionary:
	var result := {"found": false, "position": Vector3.ZERO, "name": "", "is_turnin": false}

	match objective.type:
		"kill":
			# Check if kill count is already met - point to turn-in NPC
			if objective.current_count >= objective.required_count:
				if quest:
					var giver_result := _find_quest_giver_position(quest)
					if giver_result.found:
						result.found = true
						result.position = giver_result.position
						result.name = "Return to " + giver_result.name
						result.is_turnin = true
						return result
			else:
				# Still need kills - look for enemies of the target type
				var enemies := get_tree().get_nodes_in_group("enemies")
				for enemy in enemies:
					if enemy is Node3D and enemy.has_method("get_enemy_data"):
						var enemy_data = enemy.get_enemy_data()
						if enemy_data and (enemy_data.id == objective.target or enemy_data.id.begins_with(objective.target)):
							result.found = true
							result.position = (enemy as Node3D).global_position
							result.name = enemy_data.display_name if not enemy_data.display_name.is_empty() else objective.target
							return result

		"collect":
			# CRITICAL FIX: First check if player already has required items in inventory
			var inventory_count: int = InventoryManager.get_item_count(objective.target)
			var needs_more: bool = inventory_count < objective.required_count

			if not needs_more:
				# Player has enough items - point to turn-in NPC
				if quest:
					var giver_result := _find_quest_giver_position(quest)
					if giver_result.found:
						result.found = true
						result.position = giver_result.position
						result.name = "Return to " + giver_result.name
						result.is_turnin = true
						return result

			# Player needs more items - look for sources in priority order:
			# 1. World items on ground
			var items := get_tree().get_nodes_in_group("world_items")
			for item in items:
				if item is Node3D and item.has_method("get_item_id"):
					if item.get_item_id() == objective.target:
						result.found = true
						result.position = (item as Node3D).global_position
						result.name = InventoryManager.get_item_name(objective.target)
						return result

			# 2. Merchants who sell the item
			var merchants := get_tree().get_nodes_in_group("merchants")
			for merchant in merchants:
				if merchant is Node3D and merchant.has_method("get_shop_inventory"):
					var shop_inv: Array = merchant.get_shop_inventory()
					for shop_item in shop_inv:
						if shop_item is Dictionary and shop_item.get("item_id", "") == objective.target:
							result.found = true
							result.position = (merchant as Node3D).global_position
							var merchant_name: String = str(merchant.get("display_name")) if "display_name" in merchant else "Merchant"
							result.name = merchant_name + " (sells " + objective.target + ")"
							return result

			# 3. Containers that might have the item
			var containers := get_tree().get_nodes_in_group("containers")
			for container in containers:
				if container is Node3D:
					# Check if container has been opened and has the item
					if container.has_method("has_item"):
						if container.has_item(objective.target):
							result.found = true
							result.position = (container as Node3D).global_position
							var container_name: String = str(container.get("container_name")) if "container_name" in container else "Container"
							result.name = container_name
							return result

			# 4. If we have some items but not enough, still show turn-in NPC as a secondary option
			# (Player might be able to buy/find rest elsewhere but this gives them direction)

		"talk":
			# Look for NPCs
			var npcs := get_tree().get_nodes_in_group("npcs")
			for npc in npcs:
				if npc is Node3D:
					var npc_id: String = ""
					# Try to get npc_id property directly
					if "npc_id" in npc:
						npc_id = str(npc.get("npc_id"))
					# Also try checking by display_name converted to snake_case
					var display_name_id := ""
					if "display_name" in npc:
						display_name_id = str(npc.get("display_name")).to_lower().replace(" ", "_")

					if npc_id == objective.target or display_name_id == objective.target:
						result.found = true
						result.position = (npc as Node3D).global_position
						var npc_name: String = str(npc.get("display_name")) if "display_name" in npc else objective.target
						result.name = npc_name
						return result

		"reach":
			# Look for location markers or spawn points
			var spawn_points := get_tree().get_nodes_in_group("spawn_points")
			for point in spawn_points:
				if point is Node3D:
					var spawn_id: String = point.get_meta("spawn_id", "")
					if spawn_id == objective.target or point.name == objective.target:
						result.found = true
						result.position = (point as Node3D).global_position
						result.name = objective.target
						return result

		"interact":
			# Look for interactable objects
			var interactables := get_tree().get_nodes_in_group("interactable")
			for obj in interactables:
				if obj is Node3D:
					var obj_id: String = ""
					if obj.has_method("get_interaction_id"):
						obj_id = obj.get_interaction_id()
					elif "object_id" in obj:
						obj_id = obj.get("object_id")
					if obj_id == objective.target:
						result.found = true
						result.position = (obj as Node3D).global_position
						result.name = objective.target
						return result

		"destroy":
			# Check if destroy count is already met - point to turn-in NPC
			if objective.current_count >= objective.required_count:
				if quest:
					var giver_result := _find_quest_giver_position(quest)
					if giver_result.found:
						result.found = true
						result.position = giver_result.position
						result.name = "Return to " + giver_result.name
						result.is_turnin = true
						return result
			else:
				# Look for spawners/totems/destructibles with matching ID
				var spawners := get_tree().get_nodes_in_group("spawners")
				for spawner in spawners:
					if spawner is Node3D:
						var spawner_id: String = ""
						if "spawner_id" in spawner:
							spawner_id = str(spawner.get("spawner_id"))
						if spawner_id == objective.target or spawner_id.begins_with(objective.target):
							result.found = true
							result.position = (spawner as Node3D).global_position
							var spawner_name: String = str(spawner.get("display_name")) if "display_name" in spawner else objective.target
							result.name = spawner_name
							return result
				# Also check cursed_totems group
				var totems := get_tree().get_nodes_in_group("cursed_totems")
				for totem in totems:
					if totem is Node3D:
						var totem_id: String = ""
						if "spawner_id" in totem:
							totem_id = str(totem.get("spawner_id"))
						if totem_id == objective.target or totem_id.begins_with(objective.target):
							result.found = true
							result.position = (totem as Node3D).global_position
							result.name = "Cursed Totem"
							return result

	return result


## Get the zone ID where an objective target is likely located
func _get_objective_target_zone(objective: QuestManager.Objective) -> String:
	# Map objective targets to their known zones
	# This is based on quest design knowledge
	match objective.type:
		"kill":
			match objective.target:
				# Goblins - wilderness and goblin cave
				"goblin", "goblin_soldier", "goblin_archer", "goblin_shaman", "goblin_leader":
					return "open_world"
				"goblin_totem":
					return "goblin_cave"
				# Common wilderness creatures (bounty targets)
				"wolf", "dire_wolf", "giant_rat", "giant_spider", "human_bandit":
					return "open_world"
				# Undead - dungeons and wilderness
				"skeleton_warrior", "skeleton_shade", "drowned_dead":
					return "open_world"
				# Larger creatures - wilderness
				"ogre", "troll", "tree_ent", "wyvern", "basilisk":
					return "open_world"
				# Cultists - dungeons
				"cultist", "cult_leader", "abomination", "vampire_lord":
					return "dark_crypt"
				_:
					return "open_world"  # Default to wilderness for kill quests

		"reach":
			match objective.target:
				"goblin_cave_entrance", "goblin_cave":
					return "goblin_cave"
				"elder_moor", "village_elder_moor":
					return "elder_moor"
				"dalhurst", "city_dalhurst":
					return "dalhurst"
				"open_world":
					return "open_world"
				_:
					return ""

		"collect":
			match objective.target:
				# Dungeon loot
				"goblin_war_horn", "corrupted_shard":
					return "goblin_cave"
				# Purchasable in town (use current zone if in town, else elder_moor)
				"health_potion", "mana_potion", "stamina_potion", "antidote":
					var current: String = MapTracker.get_current_zone() if MapTracker else ""
					return current if _is_town_zone(current) else "elder_moor"
				# Crafting materials - wilderness
				"wolf_pelt", "wolf_fang", "spider_silk", "raw_meat":
					return "open_world"
				# Herbs - wilderness
				"healing_herb", "mana_bloom", "nightshade":
					return "open_world"
				_:
					# Unknown items - check wilderness first
					return "open_world"

		"talk":
			# Check if NPC is in a specific location
			match objective.target:
				"wandering_knight":
					return "elder_moor"  # Knight is in starting town
				"innkeeper", "blacksmith", "merchant", "alchemist":
					# Use current zone if in town, else return elder_moor
					var current: String = MapTracker.get_current_zone() if MapTracker else ""
					return current if _is_town_zone(current) else "elder_moor"
				_:
					# For bounty turn-ins and other NPCs, default to starting town
					# Most NPCs live in settlements
					return "elder_moor"

		"interact":
			match objective.target:
				"goblin_totem":
					return "goblin_cave"
				_:
					return ""

		"destroy":
			# Spawners and totems are typically in wilderness or dungeons
			match objective.target:
				"goblin_totem":
					return "goblin_cave"
				"cursed_totem":
					return "open_world"  # Cursed totems spawn in wilderness near ruins
				_:
					return "open_world"  # Default to wilderness for destroy objectives

	return ""


## Find an exit door that leads to the target zone (or toward it)
## Now finds the NEAREST door when multiple exist
## Also handles wilderness exits which use a special handler system
func _find_exit_door_to_zone(target_zone: String) -> ZoneDoor:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_pos: Vector3 = player.global_position if player else Vector3.ZERO
	var nearest_door: ZoneDoor = null
	var nearest_dist: float = INF

	# Get current zone to determine appropriate routing
	var current_zone := MapTracker.get_current_zone() if MapTracker else ""

	# SPECIAL CASE: Wilderness exits use a different system (wilderness_exit_handler)
	# They're not in the "doors" group - look for them separately
	if target_zone == "open_world":
		var wilderness_exit := _find_nearest_wilderness_exit(player_pos)
		if wilderness_exit:
			return wilderness_exit

	# SPECIAL CASE: When IN open_world and need to go to a town
	# The wilderness uses edge triggers, not doors - find the closest town exit
	if current_zone == "open_world" and _is_town_zone(target_zone):
		# Look for wilderness exit POIs that lead to settlements
		var wilderness_exit := _find_wilderness_exit_to_town(player_pos, target_zone)
		if wilderness_exit:
			return wilderness_exit
		# If no specific exit found, return null - compass will hide marker
		# Player needs to navigate via world map/exploration
		return null

	# Direct connection - check zone_connections first (now an array)
	if zone_connections.has(target_zone):
		var connections: Array = zone_connections[target_zone]
		if connections.size() > 0:
			# Find nearest door to player
			for connection in connections:
				var conn_dict: Dictionary = connection
				if conn_dict.has("door") and is_instance_valid(conn_dict.door):
					var door: ZoneDoor = conn_dict.door as ZoneDoor
					if door and door is Node3D:
						var dist: float = player_pos.distance_to(door.global_position)
						if dist < nearest_dist:
							nearest_dist = dist
							nearest_door = door
			if nearest_door:
				return nearest_door

	# Check all doors for one that leads to target zone
	var doors := get_tree().get_nodes_in_group("doors")
	nearest_door = null
	nearest_dist = INF
	for door in doors:
		if door is ZoneDoor:
			var zone_door := door as ZoneDoor
			var door_target_zone := _scene_path_to_zone_id(zone_door.target_scene)
			if door_target_zone == target_zone:
				var dist: float = player_pos.distance_to(zone_door.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_door = zone_door
	if nearest_door:
		return nearest_door

	# No direct connection - find intermediate zone
	# If we're in town and need to get to goblin_cave, point to open_world exit
	# If we're in goblin_cave and need to get to town, point to open_world exit
	# (current_zone already declared at top of function)

	# Zone path mapping (simplified pathfinding)
	# Towns route through open_world to reach wilderness/dungeon areas
	# Using actual zone names (elder_moor, dalhurst, etc.) instead of generic "town"
	var zone_paths: Dictionary = {
		"elder_moor": {
			"goblin_cave": "open_world",
			"dark_crypt": "open_world",
			"random_cave": "open_world",
			"riverside_village": "open_world",
			"dalhurst": "open_world",
			"open_world": "open_world"
		},
		"dalhurst": {
			"goblin_cave": "open_world",
			"elder_moor": "open_world",
			"dark_crypt": "open_world",
			"open_world": "open_world"
		},
		"aberdeen": {
			"goblin_cave": "open_world",
			"elder_moor": "open_world",
			"dalhurst": "open_world",
			"open_world": "open_world"
		},
		"larton": {
			"elder_moor": "open_world",
			"dalhurst": "open_world",
			"open_world": "open_world"
		},
		"rotherhine": {
			"elder_moor": "open_world",
			"dalhurst": "open_world",
			"open_world": "open_world"
		},
		"falkenhafen": {
			"elder_moor": "open_world",
			"dalhurst": "open_world",
			"open_world": "open_world"
		},
		"goblin_cave": {
			"elder_moor": "open_world",
			"dark_crypt": "open_world",
			"random_cave": "open_world",
			"riverside_village": "open_world",
			"dalhurst": "open_world"
		},
		"dark_crypt": {
			"elder_moor": "open_world",
			"goblin_cave": "open_world"
		},
		"random_cave": {
			"elder_moor": "open_world",
			"goblin_cave": "open_world"
		},
		"riverside_village": {
			"elder_moor": "open_world",
			"goblin_cave": "open_world"
		},
		"open_world": {
			# Open world has direct access to everything
		}
	}

	if zone_paths.has(current_zone) and zone_paths[current_zone].has(target_zone):
		var intermediate_zone: String = zone_paths[current_zone][target_zone]
		# Find door to intermediate zone
		for door in doors:
			if door is ZoneDoor:
				var zone_door := door as ZoneDoor
				var door_target_zone := _scene_path_to_zone_id(zone_door.target_scene)
				if door_target_zone == intermediate_zone:
					return zone_door

	# Fallback: If we're in a town and looking for wilderness targets,
	# return ANY door that leads outside (dungeon, wilderness, etc.)
	if _is_town_zone(current_zone):
		for door in doors:
			if door is ZoneDoor:
				var zone_door := door as ZoneDoor
				var door_target := _scene_path_to_zone_id(zone_door.target_scene)
				# Skip doors to other town interiors (inn, shops)
				if not door_target.contains("inn") and not door_target.contains("shop"):
					return zone_door

	return null


## Cached fake door for wilderness exits (avoids creating new nodes each frame)
var _cached_wilderness_door: ZoneDoor = null
var _cached_town_exit_door: ZoneDoor = null

## Find wilderness exit that leads to a specific town
## Used when player is in open_world and needs to go to a settlement
func _find_wilderness_exit_to_town(player_pos: Vector3, target_town: String) -> ZoneDoor:
	# First check for direct POIs/doors to the target
	var pois := get_tree().get_nodes_in_group("compass_poi")
	var nearest_exit: Node3D = null
	var nearest_dist: float = INF

	for poi in pois:
		if poi is Node3D:
			var poi_id: String = poi.get_meta("poi_id", "")
			var poi_target: String = poi.get_meta("target_zone", "")
			if poi_target == target_town or poi_id.contains(target_town):
				var dist: float = player_pos.distance_to(poi.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_exit = poi

	var doors := get_tree().get_nodes_in_group("doors")
	for door in doors:
		if door is ZoneDoor:
			var zone_door := door as ZoneDoor
			var door_target := _scene_path_to_zone_id(zone_door.target_scene)
			if door_target == target_town:
				var dist: float = player_pos.distance_to(zone_door.global_position)
				if dist < nearest_dist:
					return zone_door

	if nearest_exit:
		if not _cached_town_exit_door:
			_cached_town_exit_door = ZoneDoor.new()
		_cached_town_exit_door.global_position = nearest_exit.global_position
		_cached_town_exit_door.door_name = nearest_exit.get_meta("poi_name", "To " + target_town.capitalize())
		_cached_town_exit_door.target_scene = target_town
		return _cached_town_exit_door

	# No direct exit found - calculate direction using world grid
	return _calculate_direction_to_settlement(player_pos, target_town)


## Calculate direction to a settlement using the world grid system
## Returns a fake door at the edge of the current cell pointing toward the target
func _calculate_direction_to_settlement(player_pos: Vector3, target_zone: String) -> ZoneDoor:
	# Get current wilderness room to find grid coordinates
	var wilderness_room := get_tree().get_first_node_in_group("wilderness_room")
	if not wilderness_room or not "grid_coords" in wilderness_room:
		return null

	var current_coords: Vector2i = wilderness_room.grid_coords

	# Find target settlement coordinates from WorldData
	var target_coords: Vector2i = _find_settlement_coords(target_zone)
	if target_coords == Vector2i(-9999, -9999):  # Not found marker
		return null

	# Calculate direction from current cell to target
	var delta: Vector2i = target_coords - current_coords

	# Determine primary direction to travel
	var direction_name: String = ""
	var edge_offset: Vector3 = Vector3.ZERO
	var cell_size: float = 140.0  # Navigation marker distance (increased for better visibility)

	# Prioritize the axis with larger distance
	if abs(delta.x) >= abs(delta.y):
		# East/West movement primary
		if delta.x > 0:
			direction_name = "East"
			edge_offset = Vector3(cell_size / 2.0, 0, 0)
		else:
			direction_name = "West"
			edge_offset = Vector3(-cell_size / 2.0, 0, 0)
	else:
		# North/South movement primary (Y in grid = Z in world, negative Y = south)
		if delta.y < 0:  # Negative Y in grid = south in world
			direction_name = "South"
			edge_offset = Vector3(0, 0, cell_size / 2.0)
		else:
			direction_name = "North"
			edge_offset = Vector3(0, 0, -cell_size / 2.0)

	# Create fake door at the edge of the cell
	if not _cached_town_exit_door:
		_cached_town_exit_door = ZoneDoor.new()

	# Position at player position plus edge offset (points toward the edge of the cell)
	# This gives a direction for the compass to point, not an actual door location
	_cached_town_exit_door.global_position = player_pos + edge_offset
	_cached_town_exit_door.door_name = "Go %s toward %s" % [direction_name, _zone_id_to_display_name(target_zone)]
	_cached_town_exit_door.target_scene = target_zone

	return _cached_town_exit_door


## Find settlement coordinates from WorldData by zone ID
func _find_settlement_coords(zone_id: String) -> Vector2i:
	# Initialize WorldData if needed
	if WorldData.world_grid.is_empty():
		WorldData.initialize()

	# Search all cells for matching location_id
	for coords: Vector2i in WorldData.world_grid:
		var cell: WorldData.CellData = WorldData.world_grid[coords]
		if cell.location_id == zone_id:
			return coords
		# Also check partial matches (village_elder_moor matches elder_moor)
		if zone_id in cell.location_id or cell.location_id in zone_id:
			return coords

	# Check common aliases
	var aliases: Dictionary = {
		"elder_moor": Vector2i(0, 0),
		"village_elder_moor": Vector2i(0, 0),
		"dalhurst": Vector2i(0, -3),
		"city_dalhurst": Vector2i(0, -3),
		"kazan_dun": Vector2i(0, -6),
		"city_kazan_dun": Vector2i(0, -6),
		"aberdeen": Vector2i(0, -9),
		"town_aberdeen": Vector2i(0, -9),
		"larton": Vector2i(-3, -9),
		"town_larton": Vector2i(-3, -9),
		"falkenhafen": Vector2i(7, -9),
		"capital_falkenhafen": Vector2i(7, -9),
	}

	if aliases.has(zone_id):
		return aliases[zone_id]

	return Vector2i(-9999, -9999)  # Not found marker


## Convert zone ID to display name
func _zone_id_to_display_name(zone_id: String) -> String:
	var names: Dictionary = {
		"elder_moor": "Elder Moor",
		"village_elder_moor": "Elder Moor",
		"dalhurst": "Dalhurst",
		"city_dalhurst": "Dalhurst",
		"kazan_dun": "Kazan-Dun",
		"city_kazan_dun": "Kazan-Dun",
		"aberdeen": "Aberdeen",
		"town_aberdeen": "Aberdeen",
		"larton": "Larton",
		"town_larton": "Larton",
		"falkenhafen": "Falkenhafen",
		"capital_falkenhafen": "Falkenhafen",
	}
	if names.has(zone_id):
		return names[zone_id]
	return zone_id.replace("_", " ").capitalize()


## Find nearest wilderness exit (special handlers, not standard doors)
## Returns a fake "door" node with global_position and door_name for compass compatibility
func _find_nearest_wilderness_exit(player_pos: Vector3) -> ZoneDoor:
	# Safety check - ensure tree is valid
	if not is_inside_tree():
		return null

	var nearest_exit: Node3D = null
	var nearest_dist: float = INF

	# Look for compass POIs that are wilderness exits
	var pois := get_tree().get_nodes_in_group("compass_poi")
	for poi in pois:
		if poi is Node3D:
			var poi_id: String = poi.get_meta("poi_id", "")
			if poi_id.contains("wilderness_exit"):
				var dist: float = player_pos.distance_to(poi.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_exit = poi

	# If found, update the cached fake door (reuse to avoid memory allocation)
	if nearest_exit and is_instance_valid(nearest_exit) and nearest_exit.is_inside_tree():
		if not _cached_wilderness_door:
			_cached_wilderness_door = ZoneDoor.new()
			_cached_wilderness_door.target_scene = "wilderness"
		_cached_wilderness_door.global_position = nearest_exit.global_position
		_cached_wilderness_door.door_name = nearest_exit.get_meta("poi_name", "To Wilderness")
		return _cached_wilderness_door

	return null


## Setup bounty indicator (shows when player has active bounty)
func _setup_bounty_indicator() -> void:
	bounty_indicator = Label.new()
	bounty_indicator.name = "BountyIndicator"
	bounty_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bounty_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Position at top-right, below gold display
	bounty_indicator.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bounty_indicator.offset_top = 35
	bounty_indicator.offset_left = -150
	bounty_indicator.offset_right = -10
	bounty_indicator.offset_bottom = 55

	# Style with red warning color
	bounty_indicator.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	bounty_indicator.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	bounty_indicator.add_theme_constant_override("outline_size", 2)
	bounty_indicator.add_theme_font_size_override("font_size", 14)

	bounty_indicator.visible = false
	add_child(bounty_indicator)

	# Connect to CrimeManager signals
	if CrimeManager.has_signal("bounty_changed"):
		CrimeManager.bounty_changed.connect(_on_bounty_changed)


## Update bounty indicator display
func _update_bounty_indicator(delta: float) -> void:
	if not bounty_indicator:
		return

	var total_bounty: int = CrimeManager.get_total_bounty()

	if total_bounty <= 0:
		bounty_indicator.visible = false
		return

	# Show bounty indicator
	bounty_indicator.visible = true
	bounty_indicator.text = "WANTED: %d G" % total_bounty

	# Flash effect for high bounty
	if total_bounty >= 500:
		bounty_flash_timer += delta * BOUNTY_FLASH_SPEED
		var flash_alpha := 0.7 + 0.3 * sin(bounty_flash_timer)
		bounty_indicator.modulate.a = flash_alpha

		# Red color intensity based on bounty
		var intensity: float = minf(1.0, total_bounty / 1000.0)
		bounty_indicator.add_theme_color_override("font_color", Color(1.0, 0.3 - intensity * 0.2, 0.2 - intensity * 0.1))
	else:
		bounty_indicator.modulate.a = 1.0
		bounty_indicator.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))


## Handle bounty changed signal
func _on_bounty_changed(region_id: String, new_amount: int) -> void:
	if new_amount > 0:
		log_bounty_added(region_id, new_amount)


## Log bounty gained
func log_bounty_added(region_id: String, amount: int) -> void:
	add_log_entry("Bounty in %s: %d G" % [region_id.capitalize(), amount], Color(1.0, 0.4, 0.3))


## ============================================================================
## QUEST TRACKER (Top of screen - shows tracked quest title and progress)
## ============================================================================

## Setup quest tracker display at top of screen
func _setup_quest_tracker() -> void:
	quest_tracker_container = Control.new()
	quest_tracker_container.name = "QuestTracker"
	quest_tracker_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	quest_tracker_container.offset_left = 10
	quest_tracker_container.offset_top = 110  # Below health/stamina/mana bars
	quest_tracker_container.offset_right = 350
	quest_tracker_container.offset_bottom = 160
	add_child(quest_tracker_container)

	# Semi-transparent background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.0, 0.0, 0.0, 0.4)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	quest_tracker_container.add_child(bg)

	# Quest title label
	quest_tracker_title = Label.new()
	quest_tracker_title.name = "QuestTitle"
	quest_tracker_title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	quest_tracker_title.offset_left = 5
	quest_tracker_title.offset_top = 3
	quest_tracker_title.offset_right = 340
	quest_tracker_title.offset_bottom = 25
	quest_tracker_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))  # Gold
	quest_tracker_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	quest_tracker_title.add_theme_constant_override("outline_size", 2)
	quest_tracker_title.add_theme_font_size_override("font_size", 14)
	quest_tracker_title.text = ""
	quest_tracker_container.add_child(quest_tracker_title)

	# Quest progress label
	quest_tracker_progress = Label.new()
	quest_tracker_progress.name = "QuestProgress"
	quest_tracker_progress.set_anchors_preset(Control.PRESET_TOP_LEFT)
	quest_tracker_progress.offset_left = 5
	quest_tracker_progress.offset_top = 25
	quest_tracker_progress.offset_right = 340
	quest_tracker_progress.offset_bottom = 50
	quest_tracker_progress.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	quest_tracker_progress.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	quest_tracker_progress.add_theme_constant_override("outline_size", 1)
	quest_tracker_progress.add_theme_font_size_override("font_size", 12)
	quest_tracker_progress.text = ""
	quest_tracker_container.add_child(quest_tracker_progress)

	# Initially hidden
	quest_tracker_container.visible = false


## Update quest tracker with current tracked quest info
func _update_quest_tracker() -> void:
	if not quest_tracker_container:
		return

	var tracked_quest := QuestManager.get_tracked_quest()
	if not tracked_quest:
		quest_tracker_container.visible = false
		return

	quest_tracker_container.visible = true
	quest_tracker_title.text = tracked_quest.title

	# Build progress text from objectives
	var progress_parts: Array[String] = []
	for objective in tracked_quest.objectives:
		if objective.is_optional:
			continue  # Skip optional objectives
		var obj_text: String = objective.description
		var current: int = QuestManager.get_objective_progress(tracked_quest.id, objective.id)
		var required: int = objective.required_count
		if required > 1:
			obj_text += " (%d/%d)" % [current, required]
		elif current >= required:
			obj_text += " [DONE]"
		progress_parts.append(obj_text)

	quest_tracker_progress.text = " | ".join(progress_parts) if not progress_parts.is_empty() else ""
