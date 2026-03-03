## conan_easter_egg.gd - Easter egg NPC: A mighty barbarian partying in the tavern
## Found in The Gilded Grog Tavern in Dalhurst, enjoying ale and wenches
class_name ConanEasterEgg
extends CharacterBody3D

const NPC_ID := "conan_barbarian"
const DISPLAY_NAME := "Mighty Barbarian"
const SPRITE_PATH := "res://assets/sprites/npcs/named/conan_easter_egg.png"

## Visual components
var sprite: Sprite3D
var interaction_area: Area3D

## Dialogue state
var dialogue_index: int = 0
var dialogue_lines: Array[String] = []

## Track if player has heard all dialogue
var has_heard_all: bool = false


func _ready() -> void:
	add_to_group("npcs")
	add_to_group("interactable")

	_setup_sprite()
	_setup_collision()
	_setup_interaction_area()
	_setup_dialogue()


func _setup_sprite() -> void:
	sprite = Sprite3D.new()
	sprite.name = "ConanSprite"
	sprite.texture = load(SPRITE_PATH)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = 0.026  # Big barbarian - taller than normal NPCs (114px sprite)
	sprite.no_depth_test = false

	# Position sprite with feet on ground
	if sprite.texture:
		sprite.position.y = sprite.texture.get_height() * sprite.pixel_size * 0.5

	add_child(sprite)


func _setup_collision() -> void:
	# Physical collision for the NPC
	collision_layer = 1
	collision_mask = 1

	var coll := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 2.0
	coll.shape = capsule
	coll.position = Vector3(0, 1.0, 0)
	add_child(coll)


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
	# Classic Conan-inspired dialogue
	dialogue_lines = [
		"*takes a long drink* Crom! This ale is worthy of a king's table!",
		"What is best in life? To crush your enemies, see them driven before you, and hear the lamentation of their women!",
		"I have known many gods. He who denies them is as blind as he who trusts them too deeply.",
		"*laughs heartily* Civilized men are more discourteous than savages because they know they can be impolite without having their skulls split!",
		"Let teachers and priests and philosophers brood over questions of reality and illusion. I know this: if life is an illusion, then I am no less an illusion, and being thus, the illusion is real to me.",
		"*flexes* I live, I burn with life, I love, I slay, and I am content.",
		"To the fires of the underworld with your 'civilization'! When I get my strength back, I will live as I please!",
		"*raises mug* The battlefield is a woman's breast, and I have loved many! But tonight, I drink! Join me, or begone!",
		"I have been in many lands and have drunk the blood of many foes. Yet here I sit, drinking ale with strangers. *grins* Life is strange.",
		"*belches loudly* Crom laughs at your four winds! He laughs from his mountain! HA!",
		"Do you not know that courage is the greatest of virtues? Without it, man is nothing!",
		"Steal? I am not a thief. I am a reaver, a slayer... with gigantic melancholies and gigantic mirth!",
	]
	# Shuffle for variety
	dialogue_lines.shuffle()


func interact(_interactor: Node) -> void:
	var hud = get_tree().get_first_node_in_group("hud")

	if dialogue_index >= dialogue_lines.size():
		# Reset and reshuffle if player has heard everything
		dialogue_index = 0
		dialogue_lines.shuffle()
		has_heard_all = true

	if hud and hud.has_method("show_notification"):
		hud.show_notification("\"%s\"" % dialogue_lines[dialogue_index])

	dialogue_index += 1

	# Play a sound if available (drinking/laughing)
	if AudioManager and AudioManager.has_method("play_ui_select"):
		AudioManager.play_ui_select()


func get_interaction_prompt() -> String:
	if has_heard_all:
		return "Drink with " + DISPLAY_NAME
	return "Talk to " + DISPLAY_NAME


## Static factory method
static func spawn_conan(parent: Node, pos: Vector3) -> ConanEasterEgg:
	var instance := ConanEasterEgg.new()
	instance.position = pos
	parent.add_child(instance)
	print("[ConanEasterEgg] The Mighty Barbarian has entered the tavern!")
	return instance
