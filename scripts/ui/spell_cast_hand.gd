## spell_cast_hand.gd - Shows hand animation when player casts magic spells
class_name SpellCastHand
extends Control

## The sprite showing the casting hand (5-frame animation)
@onready var hand_sprite: Sprite2D = $HandSprite

## How long to display the animation
const DISPLAY_DURATION := 0.8

## Timer for auto-hide
var hide_timer: float = 0.0
var is_showing: bool = false

## Frame animation settings
var current_frame: int = 0
var frame_timer: float = 0.0
const FRAME_DURATION := 0.16  # Time per frame (5 frames in ~0.8 seconds)
const TOTAL_FRAMES := 5

func _ready() -> void:
	# Start hidden
	visible = false

	# Connect to player's spell caster if available
	await get_tree().process_frame
	_connect_to_spell_caster()

func _process(delta: float) -> void:
	if is_showing:
		# Animate frames
		frame_timer += delta
		if frame_timer >= FRAME_DURATION:
			frame_timer = 0.0
			current_frame += 1
			if current_frame >= TOTAL_FRAMES:
				current_frame = TOTAL_FRAMES - 1  # Hold on last frame
			if hand_sprite:
				hand_sprite.frame = current_frame

		# Auto-hide timer
		hide_timer += delta
		if hide_timer >= DISPLAY_DURATION:
			hide_hand()

func _connect_to_spell_caster() -> void:
	# Find player node
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Find spell caster component
	var spell_caster: SpellCaster = null
	if player.has_node("SpellCaster"):
		spell_caster = player.get_node("SpellCaster") as SpellCaster

	if spell_caster:
		if not spell_caster.cast_started.is_connected(_on_cast_started):
			spell_caster.cast_started.connect(_on_cast_started)
		if not spell_caster.cast_completed.is_connected(_on_cast_completed):
			spell_caster.cast_completed.connect(_on_cast_completed)
		if not spell_caster.cast_interrupted.is_connected(_on_cast_interrupted):
			spell_caster.cast_interrupted.connect(_on_cast_interrupted)

func _on_cast_started(spell: SpellData) -> void:
	# Show the hand animation
	show_cast_animation(spell)

func _on_cast_completed(_spell: SpellData) -> void:
	# Can extend animation on completion if desired
	pass

func _on_cast_interrupted() -> void:
	# Hide immediately on interrupt
	hide_hand()

func show_cast_animation(_spell: SpellData = null) -> void:
	is_showing = true
	visible = true
	hide_timer = 0.0
	frame_timer = 0.0
	current_frame = 0

	if hand_sprite:
		hand_sprite.frame = 0

func hide_hand() -> void:
	is_showing = false
	visible = false
	hide_timer = 0.0
