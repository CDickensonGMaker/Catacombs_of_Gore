## enchanting_station.gd - World interactable for enchanting equipment
## NOTE: Should only be placed in Dalhurst, near the Wizard/Sage NPC
class_name EnchantingStation
extends Node3D

signal station_opened
signal station_closed

@export var station_name: String = "Enchanting Table"
@export var interaction_prompt: String = "[E] Use Enchanting Table"

## Minimum Arcana Lore required to use the station
const MIN_ARCANA_LORE: int = 3

## Visual components
@onready var mesh: MeshInstance3D = $Mesh
@onready var interaction_area: Area3D = $InteractionArea
@onready var particle_effect: GPUParticles3D = $ParticleEffect

## UI reference (created when opened)
var enchanting_ui: Control = null
var is_open: bool = false

func _ready() -> void:
	add_to_group("interactable")

	# Setup interaction area
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

	# Create visual mesh if not present
	if not mesh:
		_create_visual()

## Create default visual representation
func _create_visual() -> void:
	mesh = MeshInstance3D.new()
	mesh.name = "Mesh"

	# Create a simple table-like shape
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 0.9, 1.0)
	mesh.mesh = box

	# Add magical material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.2, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.3, 0.8)
	mat.emission_energy_multiplier = 0.5
	mesh.material_override = mat

	mesh.position = Vector3(0, 0.45, 0)
	add_child(mesh)

	# Add collision for interaction
	if not interaction_area:
		interaction_area = Area3D.new()
		interaction_area.name = "InteractionArea"
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 2.5
		collision.shape = shape
		interaction_area.add_child(collision)
		add_child(interaction_area)
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		# Player is near, show interaction hint via HUD
		pass

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and is_open:
		close()

## Called when player interacts
func interact(player: Node) -> void:
	# Check Arcana Lore requirement
	var arcana: int = 0
	if GameManager and GameManager.player_data:
		arcana = GameManager.player_data.get_skill(Enums.Skill.ARCANA_LORE)

	if arcana < MIN_ARCANA_LORE:
		_show_message("You need at least %d Arcana Lore to use this." % MIN_ARCANA_LORE)
		return

	open()

## Get interaction prompt for HUD
func get_interaction_prompt() -> String:
	return interaction_prompt

## Open the enchanting UI
func open() -> void:
	if is_open:
		return

	is_open = true
	GameManager.enter_menu()

	# Load and show enchanting UI
	var ui_scene := load("res://scenes/ui/enchanting_ui.tscn")
	if ui_scene:
		enchanting_ui = ui_scene.instantiate()
		enchanting_ui.station = self
		get_tree().root.add_child(enchanting_ui)
		if enchanting_ui.has_method("open"):
			enchanting_ui.open()

	station_opened.emit()

## Close the enchanting UI
func close() -> void:
	if not is_open:
		return

	is_open = false
	GameManager.exit_menu()

	if enchanting_ui and is_instance_valid(enchanting_ui):
		if enchanting_ui.has_method("close"):
			enchanting_ui.close()
		enchanting_ui.queue_free()
		enchanting_ui = null

	station_closed.emit()

## Show a message to the player
func _show_message(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)

## Static factory method
static func spawn_station(parent: Node, pos: Vector3) -> EnchantingStation:
	var station := EnchantingStation.new()
	station.position = pos
	parent.add_child(station)
	return station
