## spell_making_altar.gd - World interactable for creating custom spells
## NOTE: Should only be placed in Dalhurst, near the Wizard/Sage NPC
class_name SpellMakingAltar
extends Node3D

signal altar_opened
signal altar_closed

@export var altar_name: String = "Spell Making Altar"
@export var interaction_prompt: String = "[E] Use Spell Making Altar"

## Visual components
@onready var mesh: MeshInstance3D = $Mesh
@onready var interaction_area: Area3D = $InteractionArea
@onready var particle_effect: GPUParticles3D = $ParticleEffect

## UI reference
var spell_maker_ui: Control = null
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

	# Create altar-like shape (cylinder base with crystal on top)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.6
	cylinder.bottom_radius = 0.8
	cylinder.height = 1.0
	mesh.mesh = cylinder

	# Add magical material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.4, 0.8)
	mat.emission_energy_multiplier = 0.7
	mesh.material_override = mat

	mesh.position = Vector3(0, 0.5, 0)
	add_child(mesh)

	# Add floating crystal above
	var crystal := MeshInstance3D.new()
	crystal.name = "Crystal"
	var prism := PrismMesh.new()
	prism.size = Vector3(0.3, 0.5, 0.3)
	crystal.mesh = prism
	crystal.position = Vector3(0, 1.5, 0)

	var crystal_mat := StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(0.5, 0.6, 1.0, 0.8)
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color(0.4, 0.5, 1.0)
	crystal_mat.emission_energy_multiplier = 1.5
	crystal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crystal.material_override = crystal_mat
	add_child(crystal)

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

func _on_body_entered(_body: Node3D) -> void:
	pass

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and is_open:
		close()

## Called when player interacts
func interact(_player: Node) -> void:
	if not SpellCreator.can_use_spell_altar():
		_show_message(SpellCreator.get_altar_requirement_message())
		return

	open()

## Get interaction prompt for HUD
func get_interaction_prompt() -> String:
	return interaction_prompt

## Open the spell maker UI
func open() -> void:
	if is_open:
		return

	is_open = true
	GameManager.enter_menu()

	# Load and show spell maker UI
	var ui_scene := load("res://scenes/ui/spell_maker_ui.tscn")
	if ui_scene:
		spell_maker_ui = ui_scene.instantiate()
		spell_maker_ui.altar = self
		get_tree().root.add_child(spell_maker_ui)
		if spell_maker_ui.has_method("open"):
			spell_maker_ui.open()

	altar_opened.emit()

## Close the spell maker UI
func close() -> void:
	if not is_open:
		return

	is_open = false
	GameManager.exit_menu()

	if spell_maker_ui and is_instance_valid(spell_maker_ui):
		if spell_maker_ui.has_method("close"):
			spell_maker_ui.close()
		spell_maker_ui.queue_free()
		spell_maker_ui = null

	altar_closed.emit()

## Show a message to the player
func _show_message(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)

## Static factory method
static func spawn_altar(parent: Node, pos: Vector3) -> SpellMakingAltar:
	var altar := SpellMakingAltar.new()
	altar.position = pos
	parent.add_child(altar)
	return altar
