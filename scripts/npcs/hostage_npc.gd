## hostage_npc.gd - Hostage NPCs for rescue quests
## Interactable NPCs that complete "talk" objectives when rescued
class_name HostageNPC
extends StaticBody3D

## Quest tracking
var quest_id: String = ""
var objective_id: String = ""
var hostage_id: String = ""  # e.g., "hostage_merchant_daughter"

## Display
var hostage_name: String = "Hostage"
var sprite: Sprite3D
var interaction_area: Area3D

## State
var is_rescued: bool = false

## Hostage sprite textures (civilians in distress)
const HOSTAGE_TEXTURES: Dictionary = {
	"merchant_daughter": "res://assets/sprites/npcs/civilians/Hostages/red_dress_hostage.png",
	"woodsman": "res://assets/sprites/npcs/civilians/Hostages/woodsman_hostage.png",
	"little_girl": "res://assets/sprites/npcs/civilians/Hostages/littlegirl_hostage.png",
	"woman": "res://assets/sprites/npcs/civilians/Hostages/green_dress_hostage.png",
	"wizard": "res://assets/sprites/npcs/civilians/Hostages/old_man_or_wizard_hostage.png",
	"soldier": "res://assets/sprites/npcs/civilians/Hostages/soldier_hostage.png",
	"default": "res://assets/sprites/npcs/civilians/Hostages/green_dress_hostage.png",
}

## Specific texture path (set during spawn for quest-specific hostages)
var texture_path: String = ""

const PIXEL_SIZE := 0.0256  # Standard humanoid size


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("hostages")

	_setup_collision()
	_setup_interaction_area()
	_setup_visual()


func _setup_collision() -> void:
	collision_layer = 1  # World layer
	collision_mask = 0

	var col := CollisionShape3D.new()
	col.name = "Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	col.shape = capsule
	col.position.y = 0.9
	add_child(col)


func _setup_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0

	var area_col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.0
	area_col.shape = sphere
	interaction_area.add_child(area_col)
	add_child(interaction_area)


func _setup_visual() -> void:
	sprite = Sprite3D.new()
	sprite.name = "HostageSprite"
	sprite.pixel_size = PIXEL_SIZE
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.transparent = true
	sprite.shaded = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD

	# Determine texture path based on hostage_id or explicit texture_path
	var tex_path: String = texture_path
	if tex_path.is_empty():
		tex_path = _get_texture_for_hostage_id()

	var tex := load(tex_path) as Texture2D
	if tex:
		sprite.texture = tex
		var height: float = tex.get_height() * PIXEL_SIZE
		sprite.position.y = height / 2.0

	# Tint slightly to show distress (pale/scared)
	sprite.modulate = Color(0.9, 0.85, 0.85)

	add_child(sprite)


## Get appropriate texture based on hostage_id
func _get_texture_for_hostage_id() -> String:
	# Check for keywords in hostage_id to match texture
	var id_lower: String = hostage_id.to_lower()

	if "merchant" in id_lower or "daughter" in id_lower:
		return HOSTAGE_TEXTURES["merchant_daughter"]
	elif "woodsman" in id_lower or "logger" in id_lower:
		return HOSTAGE_TEXTURES["woodsman"]
	elif "girl" in id_lower or "child" in id_lower:
		return HOSTAGE_TEXTURES["little_girl"]
	elif "wizard" in id_lower or "mage" in id_lower or "old" in id_lower:
		return HOSTAGE_TEXTURES["wizard"]
	elif "soldier" in id_lower or "guard" in id_lower or "knight" in id_lower:
		return HOSTAGE_TEXTURES["soldier"]
	elif "woman" in id_lower or "lady" in id_lower:
		return HOSTAGE_TEXTURES["woman"]
	else:
		return HOSTAGE_TEXTURES["default"]


## Interaction interface
func interact(_interactor: Node) -> void:
	if is_rescued:
		return

	_rescue()


func get_interaction_prompt() -> String:
	if is_rescued:
		return ""
	return "Rescue " + hostage_name


## Rescue the hostage - complete the quest objective
func _rescue() -> void:
	is_rescued = true

	# Remove from interactable so prompt disappears
	remove_from_group("interactable")

	# Complete the talk objective in QuestManager
	if not quest_id.is_empty() and not hostage_id.is_empty():
		QuestManager.on_npc_talked(hostage_id)
		print("[HostageNPC] Rescued %s - notified QuestManager" % hostage_name)

	# Show notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Rescued: %s" % hostage_name)

	# Play rescue sound
	AudioManager.play_ui_confirm()

	# Visual feedback - hostage looks relieved
	if sprite:
		sprite.modulate = Color.WHITE

	# After a short delay, the hostage "leaves" (despawns)
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(_on_rescue_complete)


func _on_rescue_complete() -> void:
	# Hostage has been rescued and leaves the area
	queue_free()


## Static factory method for spawning hostages
static func spawn_hostage(
	parent: Node,
	pos: Vector3,
	p_hostage_id: String,
	p_hostage_name: String,
	p_quest_id: String = "",
	p_objective_id: String = ""
) -> HostageNPC:
	var instance := HostageNPC.new()
	instance.hostage_id = p_hostage_id
	instance.hostage_name = p_hostage_name
	instance.quest_id = p_quest_id
	instance.objective_id = p_objective_id
	instance.position = pos

	parent.add_child(instance)
	print("[HostageNPC] Spawned hostage '%s' at %s" % [p_hostage_name, pos])
	return instance
