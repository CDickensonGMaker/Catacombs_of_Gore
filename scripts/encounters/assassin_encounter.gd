## assassin_encounter.gd - Scripted assassin encounter that plays dialogue before combat
## Use this for unique assassination attempts like Ratfang Snotcheeze
##
## Usage:
## 1. Place a Marker3D in your scene where the assassin should appear
## 2. Attach this script to a Node (or add AssassinEncounter.spawn_encounter() to level script)
## 3. Call trigger_encounter() when player enters the trigger area
##
## The encounter will:
## 1. Pause player movement/combat
## 2. Play the assassin's dialogue
## 3. When dialogue ends, spawn the enemy and start combat
class_name AssassinEncounter
extends Node3D

signal encounter_started()
signal dialogue_finished()
signal combat_started(enemy: EnemyBase)
signal encounter_completed(enemy_killed: bool)

## Enemy data path for this assassin
@export var enemy_data_path: String = "res://data/enemies/ratfang_snotcheeze.tres"

## Dialogue JSON path for pre-battle exposition
@export var dialogue_path: String = "res://data/dialogue/ratfang_snotcheeze.json"

## Spawn position for the assassin (relative to this node or absolute)
@export var spawn_offset: Vector3 = Vector3(0, 0, -3)

## Whether encounter has been triggered (one-shot by default)
@export var one_shot: bool = true

## Internal state
var _triggered: bool = false
var _spawned_enemy: EnemyBase = null
var _player: Node3D = null


func _ready() -> void:
	# Connect to dialogue_ended to know when to start combat
	if DialogueManager:
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


## Trigger the encounter - call this from a trigger zone or manual placement
func trigger_encounter(player: Node3D = null) -> void:
	if _triggered and one_shot:
		return

	_triggered = true
	_player = player if player else get_tree().get_first_node_in_group("player")

	if not _player:
		push_warning("[AssassinEncounter] No player found!")
		return

	encounter_started.emit()

	# Start the pre-battle dialogue
	_start_dialogue()


## Start the assassin's monologue
func _start_dialogue() -> void:
	var dialogue_data: DialogueData = DialogueLoader.get_dialogue(dialogue_path)

	if not dialogue_data:
		push_warning("[AssassinEncounter] Failed to load dialogue from: %s" % dialogue_path)
		# Skip dialogue and go straight to combat
		_spawn_and_fight()
		return

	# Start dialogue through DialogueManager
	DialogueManager.start_dialogue(dialogue_data, "Ratfang Snotcheeze")


## Called when any dialogue ends - check if it's ours
func _on_dialogue_ended(dialogue_data: DialogueData) -> void:
	if not dialogue_data:
		return

	# Check if this was our dialogue
	if dialogue_data.id == "ratfang_snotcheeze_encounter":
		dialogue_finished.emit()
		# Small delay before combat starts
		await get_tree().create_timer(0.5).timeout
		_spawn_and_fight()


## Spawn the assassin enemy and start combat
func _spawn_and_fight() -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")

	if not _player:
		push_warning("[AssassinEncounter] Cannot spawn - no player!")
		return

	# Calculate spawn position in front of player
	var spawn_pos: Vector3
	if spawn_offset != Vector3.ZERO:
		# Use offset relative to player facing direction
		var player_forward: Vector3 = -_player.global_transform.basis.z.normalized()
		spawn_pos = _player.global_position + player_forward * spawn_offset.length()
		spawn_pos.y = _player.global_position.y  # Keep on same level
	else:
		# Use this node's position
		spawn_pos = global_position

	# Load enemy data
	var enemy_data: EnemyData = load(enemy_data_path)
	if not enemy_data:
		push_warning("[AssassinEncounter] Failed to load enemy data: %s" % enemy_data_path)
		return

	# Load sprites
	var idle_sprite: Texture2D = load(enemy_data.sprite_path)
	if not idle_sprite:
		push_warning("[AssassinEncounter] Failed to load sprite: %s" % enemy_data.sprite_path)
		return

	# Spawn the enemy using EnemyBase factory
	var parent: Node3D = get_tree().current_scene
	_spawned_enemy = EnemyBase.spawn_billboard_enemy(
		parent,
		spawn_pos,
		enemy_data_path,
		idle_sprite,
		enemy_data.sprite_hframes,
		enemy_data.sprite_vframes
	)

	if not _spawned_enemy:
		push_warning("[AssassinEncounter] Failed to spawn enemy!")
		return

	# Mark as scripted encounter
	_spawned_enemy.set_meta("scripted_encounter", true)
	_spawned_enemy.set_meta("encounter_node", self)

	# Face the player
	_spawned_enemy.look_at(_player.global_position, Vector3.UP)

	# Connect to death signal
	if _spawned_enemy.has_signal("died"):
		_spawned_enemy.died.connect(_on_enemy_died)

	# Add to enemies group
	_spawned_enemy.add_to_group("enemies")

	combat_started.emit(_spawned_enemy)

	print("[AssassinEncounter] Spawned %s at %s" % [enemy_data.display_name, spawn_pos])


## Called when the assassin dies
func _on_enemy_died() -> void:
	encounter_completed.emit(true)

	# Show notification about the contract
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("The assassin has been slain. Search the body for clues.")


## Static factory method for easy spawning in level scripts
## Returns the encounter node for signal connections
static func spawn_encounter(
	parent: Node,
	spawn_position: Vector3,
	p_enemy_data_path: String = "res://data/enemies/ratfang_snotcheeze.tres",
	p_dialogue_path: String = "res://data/dialogue/ratfang_snotcheeze.json"
) -> AssassinEncounter:
	var encounter := AssassinEncounter.new()
	encounter.enemy_data_path = p_enemy_data_path
	encounter.dialogue_path = p_dialogue_path
	encounter.global_position = spawn_position
	parent.add_child(encounter)
	return encounter


## Call this to manually place an assassin spawn point in the editor
## Creates a trigger area that starts the encounter when player enters
func create_trigger_area(radius: float = 5.0) -> Area3D:
	var area := Area3D.new()
	area.name = "AssassinTrigger"

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	collision.shape = sphere
	area.add_child(collision)

	# Set collision layer/mask for player detection only
	area.collision_layer = 0
	area.collision_mask = 2  # Player layer

	area.body_entered.connect(_on_trigger_body_entered)

	add_child(area)
	return area


func _on_trigger_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		trigger_encounter(body)
