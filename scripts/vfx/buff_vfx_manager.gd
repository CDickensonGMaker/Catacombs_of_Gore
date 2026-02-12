## buff_vfx_manager.gd - Manages persistent VFX for buffs on the player
## Attach this as a child of the player controller
class_name BuffVFXManager
extends Node

## Reference to the entity this manager belongs to
@export var owner_entity: Node3D

## Active buff VFX nodes (keyed by condition)
var active_vfx: Dictionary = {}

## VFX configuration for each buff type
const BUFF_VFX_CONFIG := {
	Enums.Condition.ARMORED: {
		"type": "shield",
		"color": Color(0.6, 0.3, 0.8, 0.4),  # Translucent purple
		"emission_color": Color(0.5, 0.2, 0.7),
		"scale": 1.2,
		"pulse": true
	},
	Enums.Condition.HASTED: {
		"type": "trail",
		"color": Color(1.0, 0.85, 0.2, 0.6),  # Yellow-gold
		"emission_color": Color(1.0, 0.8, 0.1),
		"particle_count": 25
	},
	# Iron Guard uses ARMORED condition but with stronger visuals
}

func _ready() -> void:
	# Auto-set owner_entity to parent if not configured
	if not owner_entity:
		var parent := get_parent()
		if parent is Node3D:
			owner_entity = parent as Node3D

	# Connect to character data condition signals if available
	_connect_condition_signals()

func _connect_condition_signals() -> void:
	# Try to connect to player_data condition changes
	if GameManager.player_data and GameManager.player_data.has_signal("condition_applied"):
		if not GameManager.player_data.is_connected("condition_applied", _on_condition_applied):
			GameManager.player_data.connect("condition_applied", _on_condition_applied)
	if GameManager.player_data and GameManager.player_data.has_signal("condition_removed"):
		if not GameManager.player_data.is_connected("condition_removed", _on_condition_removed):
			GameManager.player_data.connect("condition_removed", _on_condition_removed)

func _process(_delta: float) -> void:
	# Update trail VFX positions if owner is moving
	if owner_entity and active_vfx.has(Enums.Condition.HASTED):
		var trail_node: Node3D = active_vfx[Enums.Condition.HASTED]
		if is_instance_valid(trail_node):
			trail_node.global_position = owner_entity.global_position + Vector3(0, 0.5, 0)

## Called when a condition is applied (from SpellCaster or signals)
func on_condition_applied(condition: Enums.Condition, duration: float) -> void:
	_on_condition_applied(condition, duration)

func _on_condition_applied(condition: Enums.Condition, duration: float) -> void:
	# Remove existing VFX for this condition first
	if active_vfx.has(condition):
		_remove_vfx(condition)

	# Spawn appropriate VFX
	match condition:
		Enums.Condition.ARMORED:
			_spawn_shield_vfx(condition, false)  # Normal armor
		Enums.Condition.HASTED:
			_spawn_trail_vfx(condition)
		_:
			return  # No VFX for other conditions

	# Schedule removal when duration expires
	if duration > 0:
		get_tree().create_timer(duration).timeout.connect(func():
			_remove_vfx(condition)
		)

func _on_condition_removed(condition: Enums.Condition) -> void:
	_remove_vfx(condition)

## Spawn shield/aura VFX (for Armor, Iron Guard)
func _spawn_shield_vfx(condition: Enums.Condition, is_iron_guard: bool = false) -> void:
	if not owner_entity:
		return

	var config: Dictionary = BUFF_VFX_CONFIG.get(condition, {})
	if config.is_empty():
		config = {
			"color": Color(0.6, 0.3, 0.8, 0.4),
			"emission_color": Color(0.5, 0.2, 0.7),
			"scale": 1.2
		}

	# Create shield sphere
	var shield := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = config.get("scale", 1.2)
	sphere.height = config.get("scale", 1.2) * 2.0
	shield.mesh = sphere

	var mat := StandardMaterial3D.new()
	var base_color: Color = config.get("color", Color(0.6, 0.3, 0.8, 0.4))

	# Iron Guard is more opaque and metallic
	if is_iron_guard:
		base_color = Color(0.6, 0.6, 0.7, 0.6)  # Metallic gray
		mat.metallic = 0.8
		mat.roughness = 0.3

	mat.albedo_color = base_color
	mat.emission_enabled = true
	mat.emission = config.get("emission_color", Color(0.5, 0.2, 0.7))
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_FRONT  # Render inside of sphere
	shield.material_override = mat

	# Attach to owner
	owner_entity.add_child(shield)
	shield.position = Vector3(0, 1.0, 0)  # Center on character

	active_vfx[condition] = shield

	# Add pulse animation if configured
	if config.get("pulse", false):
		_add_pulse_animation(shield, mat)

## Add pulsing animation to shield VFX
func _add_pulse_animation(shield: MeshInstance3D, mat: StandardMaterial3D) -> void:
	var tween := get_tree().create_tween()
	tween.set_loops()

	# Pulse alpha and emission
	tween.tween_property(mat, "albedo_color:a", 0.6, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mat, "albedo_color:a", 0.3, 0.8).set_trans(Tween.TRANS_SINE)

## Spawn speed trail VFX (for Haste)
func _spawn_trail_vfx(condition: Enums.Condition) -> void:
	if not owner_entity:
		return

	var config: Dictionary = BUFF_VFX_CONFIG.get(condition, {})

	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = false
	particles.amount = config.get("particle_count", 25)
	particles.lifetime = 0.8

	var proc_mat := ParticleProcessMaterial.new()
	proc_mat.direction = Vector3(0, 0, 0)
	proc_mat.spread = 180.0
	proc_mat.initial_velocity_min = 0.2
	proc_mat.initial_velocity_max = 0.5
	proc_mat.gravity = Vector3(0, -0.5, 0)
	proc_mat.damping_min = 1.0
	proc_mat.damping_max = 2.0

	var trail_color: Color = config.get("color", Color(1.0, 0.85, 0.2, 0.6))
	proc_mat.color = trail_color

	proc_mat.scale_min = 0.05
	proc_mat.scale_max = 0.12

	particles.process_material = proc_mat

	# Simple sphere mesh for particles
	var draw_pass := SphereMesh.new()
	draw_pass.radius = 0.05
	draw_pass.height = 0.1
	particles.draw_pass_1 = draw_pass

	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = trail_color
	mesh_mat.emission_enabled = true
	mesh_mat.emission = config.get("emission_color", Color(1.0, 0.8, 0.1))
	mesh_mat.emission_energy_multiplier = 3.0
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_pass.material = mesh_mat

	# Add to scene (not parented to player so particles trail behind)
	get_tree().current_scene.add_child(particles)
	particles.global_position = owner_entity.global_position + Vector3(0, 0.5, 0)

	active_vfx[condition] = particles

## Remove VFX for a condition
func _remove_vfx(condition: Enums.Condition) -> void:
	if not active_vfx.has(condition):
		return

	var vfx_node: Node = active_vfx[condition]
	if is_instance_valid(vfx_node):
		# Fade out for particles
		if vfx_node is GPUParticles3D:
			(vfx_node as GPUParticles3D).emitting = false
			get_tree().create_timer(1.0).timeout.connect(vfx_node.queue_free)
		else:
			# Quick fade for meshes
			var mat := (vfx_node as MeshInstance3D).material_override as StandardMaterial3D
			if mat:
				var tween := get_tree().create_tween()
				tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
				tween.tween_callback(vfx_node.queue_free)
			else:
				vfx_node.queue_free()

	active_vfx.erase(condition)

## Spawn Iron Guard VFX (heavier, more opaque shield)
func spawn_iron_guard_vfx(duration: float) -> void:
	_spawn_shield_vfx(Enums.Condition.ARMORED, true)

	# Schedule removal
	if duration > 0:
		get_tree().create_timer(duration).timeout.connect(func():
			_remove_vfx(Enums.Condition.ARMORED)
		)

## Clean up all VFX
func clear_all_vfx() -> void:
	for condition in active_vfx.keys():
		_remove_vfx(condition)
