## spock_easter_egg.gd - Easter egg NPC: A logical stranger from beyond the stars
## Rare spawn in far wilderness, requires player level 10+
class_name SpockEasterEgg
extends Node3D

const NPC_ID := "spock_stranger"
const DISPLAY_NAME := "Pointed-Eared Stranger"
const SPRITE_PATH := "res://assets/sprites/npcs/named/spock.png"
const CRASHED_SHIP_PATH := "res://assets/sprites/world/crashed_ship.png"

## Spawn requirements
const MIN_PLAYER_LEVEL := 10
const MIN_DANGER_LEVEL := 4  # Far from Elder Moor
const SPAWN_CHANCE := 0.008  # 0.8% chance per eligible cell

## Cost to help him "return home"
const BEAM_COST := 1000

## Global tracking - only one Spock can exist in the world
static var has_spawned_this_session: bool = false
static var has_been_helped_globally: bool = false  # Persists if player helped him

## Visual components
var sprite: Sprite3D
var interaction_area: Area3D
var crashed_ship: Sprite3D

## State
var has_been_helped: bool = false
var is_beaming: bool = false
var beam_particles: GPUParticles3D
var beam_light: OmniLight3D
var beam_timer: float = 0.0

## Dialogue state
var dialogue_index: int = 0
var dialogue_lines: Array[String] = []

func _ready() -> void:
	add_to_group("npcs")
	add_to_group("interactable")

	_setup_sprite()
	_setup_crashed_ship()
	_setup_interaction_area()
	_setup_dialogue()

func _setup_sprite() -> void:
	sprite = Sprite3D.new()
	sprite.name = "SpockSprite"
	sprite.texture = load(SPRITE_PATH)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = 0.025
	sprite.no_depth_test = false

	# Position sprite with feet on ground
	if sprite.texture:
		sprite.position.y = sprite.texture.get_height() * sprite.pixel_size * 0.5

	add_child(sprite)

func _setup_crashed_ship() -> void:
	crashed_ship = Sprite3D.new()
	crashed_ship.name = "CrashedShip"
	crashed_ship.texture = load(CRASHED_SHIP_PATH)
	crashed_ship.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	crashed_ship.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	crashed_ship.pixel_size = 0.035  # Larger than Spock - it's a ship!
	crashed_ship.no_depth_test = false

	# Random offset 5-10 feet (units) away from Spock
	var angle := randf() * TAU  # Random direction
	var distance := randf_range(5.0, 10.0)
	var offset := Vector3(cos(angle) * distance, 0, sin(angle) * distance)

	# Position ship with bottom on ground
	if crashed_ship.texture:
		crashed_ship.position = offset
		crashed_ship.position.y = crashed_ship.texture.get_height() * crashed_ship.pixel_size * 0.5

	add_child(crashed_ship)

func _setup_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.5
	shape.shape = sphere
	interaction_area.add_child(shape)

func _setup_dialogue() -> void:
	dialogue_lines = [
		"Greetings. I am... not from this region. My vessel experienced a catastrophic malfunction during a routine survey mission.",
		"I have calculated a 97.3% probability that you are a native of this world. Fascinating. Your survival instincts appear adequate.",
		"This realm operates on principles that defy conventional physics. Magic, as you call it, is merely science not yet understood.",
		"I have observed the inhabitants of the 'Empty Throne' territories. Their political structure is... illogical, yet strangely familiar.",
		"The creatures here - trolls, wyverns, basilisks - would make excellent subjects for biological study. If I survive long enough to document them.",
		"I require exactly 1000 gold pieces to repair my... transportation device. The alloy composition of your currency is surprisingly compatible.",
		"Should you assist me, I would consider it a debt of honor. My people take such matters seriously.",
		"Live long and prosper, traveler. Though in these lands, simply 'living' appears to be the greater challenge."
	]

func interact(interactor: Node) -> void:
	if has_been_helped or is_beaming:
		return

	var hud = get_tree().get_first_node_in_group("hud")

	# Check if player has enough gold and wants to help
	if dialogue_index >= dialogue_lines.size() - 1:
		# Final dialogue - offer to help
		if InventoryManager.gold >= BEAM_COST:
			_show_help_choice(interactor)
		else:
			if hud and hud.has_method("show_notification"):
				hud.show_notification("\"You lack sufficient currency. %d gold required. Most... unfortunate.\"" % BEAM_COST)
	else:
		# Show next dialogue line
		if hud and hud.has_method("show_notification"):
			hud.show_notification("\"%s\"" % dialogue_lines[dialogue_index])
		dialogue_index += 1

func _show_help_choice(interactor: Node) -> void:
	var hud = get_tree().get_first_node_in_group("hud")

	# For now, just take the gold and beam up
	# In a full implementation, this would show a choice dialog
	if InventoryManager.remove_gold(BEAM_COST):
		if hud and hud.has_method("show_notification"):
			hud.show_notification("\"Your generosity is... logical. Live long and prosper.\"")

		# Start beam-up sequence
		_start_beam_up()

func _start_beam_up() -> void:
	is_beaming = true
	has_been_helped = true

	# Mark globally so he never spawns again this session
	SpockEasterEgg.has_been_helped_globally = true

	remove_from_group("interactable")

	# Create beam-up effect
	_create_beam_effect()

	# Play sound if available
	if AudioManager and AudioManager.has_method("play_ui_select"):
		AudioManager.play_ui_select()

func _create_beam_effect() -> void:
	# Create upward light beam
	beam_light = OmniLight3D.new()
	beam_light.light_color = Color(0.4, 0.6, 1.0)  # Blue-white
	beam_light.light_energy = 3.0
	beam_light.omni_range = 8.0
	beam_light.position = Vector3(0, 2, 0)
	add_child(beam_light)

	# Create particle effect for sparkles
	beam_particles = GPUParticles3D.new()
	beam_particles.amount = 50
	beam_particles.lifetime = 1.5
	beam_particles.one_shot = false
	beam_particles.explosiveness = 0.0
	beam_particles.position = Vector3(0, 1, 0)

	# Create particle material
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 15.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 0.1
	mat.scale_max = 0.3
	mat.color = Color(0.5, 0.7, 1.0, 1.0)
	beam_particles.process_material = mat

	# Simple quad mesh for particles
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	beam_particles.draw_pass_1 = quad

	add_child(beam_particles)
	beam_particles.emitting = true

func _process(delta: float) -> void:
	if is_beaming:
		beam_timer += delta

		# Fade out sprite and move up
		if sprite:
			sprite.modulate.a = max(0, 1.0 - beam_timer / 3.0)
			sprite.position.y += delta * 2.0

		# Pulse the light
		if beam_light:
			beam_light.light_energy = 3.0 + sin(beam_timer * 10.0) * 1.5

		# After 3 seconds, remove the NPC
		if beam_timer >= 3.0:
			queue_free()

func get_interaction_prompt() -> String:
	if has_been_helped or is_beaming:
		return ""
	if dialogue_index >= dialogue_lines.size() - 1:
		if InventoryManager.gold >= BEAM_COST:
			return "Help %s (1000 gold)" % DISPLAY_NAME
		else:
			return "Talk to %s (need 1000 gold)" % DISPLAY_NAME
	return "Talk to %s" % DISPLAY_NAME

## Static method to check if Spock should spawn in a cell
static func should_spawn(player_level: int, danger_level: int) -> bool:
	# Only one Spock can exist - check if already spawned or helped
	if has_spawned_this_session or has_been_helped_globally:
		return false

	# Must meet level requirement
	if player_level < MIN_PLAYER_LEVEL:
		return false

	# Must be in dangerous wilderness
	if danger_level < MIN_DANGER_LEVEL:
		return false

	# Random chance
	return randf() < SPAWN_CHANCE


## Reset spawn flag (call when starting new game)
static func reset_for_new_game() -> void:
	has_spawned_this_session = false
	has_been_helped_globally = false

## Static factory method
static func spawn_spock(parent: Node, pos: Vector3) -> SpockEasterEgg:
	# Mark as spawned globally - only one can exist
	has_spawned_this_session = true

	var instance := SpockEasterEgg.new()
	instance.position = pos
	parent.add_child(instance)
	print("[SpockEasterEgg] The Pointed-Eared Stranger has appeared!")
	return instance
