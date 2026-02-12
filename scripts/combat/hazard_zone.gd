## hazard_zone.gd - Persistent ground hazard that damages enemies over time
## Used for Fire Gate and Ice Storm spells
class_name HazardZone
extends Area3D

## Configuration
@export var hazard_radius: float = 5.0
@export var hazard_duration: float = 60.0
@export var tick_interval: float = 1.0
@export var damage_dice: Array[int] = [2, 6, 0]  # [num_dice, die_size, flat_bonus]
@export var damage_type: Enums.DamageType = Enums.DamageType.FIRE
@export var condition_to_apply: Enums.Condition = Enums.Condition.BURNING
@export var condition_chance: float = 0.5
@export var condition_duration: float = 5.0

## Visual configuration
@export var particle_color: Color = Color(1.0, 0.5, 0.2, 0.8)
@export var decal_color: Color = Color(0.8, 0.3, 0.1, 0.6)

## Internal state
var caster: Node = null
var entities_inside: Array[Node] = []
var tick_timer: float = 0.0
var life_timer: float = 0.0
var is_active: bool = true

## VFX nodes
var particles: GPUParticles3D = null
var ground_decal: MeshInstance3D = null
var collision_shape: CollisionShape3D = null

func _ready() -> void:
	# Set up collision
	collision_layer = 0
	collision_mask = 4 + 64  # Enemy body (4) + enemy hurtbox (64)
	monitoring = true
	monitorable = false

	# Create collision shape
	collision_shape = CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = hazard_radius
	cylinder.height = 3.0  # Tall enough to catch enemies
	collision_shape.shape = cylinder
	add_child(collision_shape)

	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Create VFX
	_create_particles()
	_create_ground_decal()

func _process(delta: float) -> void:
	if not is_active:
		return

	# Update life timer
	life_timer += delta
	if life_timer >= hazard_duration:
		_expire()
		return

	# Update tick timer
	tick_timer += delta
	if tick_timer >= tick_interval:
		tick_timer = 0.0
		_apply_damage_tick()

	# Fade out in last 3 seconds
	if life_timer > hazard_duration - 3.0:
		var fade_t: float = (life_timer - (hazard_duration - 3.0)) / 3.0
		if particles:
			particles.amount_ratio = 1.0 - fade_t
		if ground_decal and ground_decal.material_override:
			var mat: StandardMaterial3D = ground_decal.material_override
			mat.albedo_color.a = decal_color.a * (1.0 - fade_t)

## Called when an entity enters the zone
func _on_body_entered(body: Node3D) -> void:
	if not is_active:
		return

	# Check if it's an enemy
	if body.is_in_group("enemies") or body.get_parent().is_in_group("enemies"):
		var enemy: Node = body if body.is_in_group("enemies") else body.get_parent()
		if enemy not in entities_inside:
			entities_inside.append(enemy)
			# Apply condition on entry
			_try_apply_condition(enemy)

## Called when an entity exits the zone
func _on_body_exited(body: Node3D) -> void:
	var enemy: Node = body if body.is_in_group("enemies") else body.get_parent()
	entities_inside.erase(enemy)

## Apply damage to all entities inside
func _apply_damage_tick() -> void:
	# Clean up invalid references
	var valid_entities: Array[Node] = []
	for entity in entities_inside:
		if is_instance_valid(entity):
			valid_entities.append(entity)
	entities_inside = valid_entities

	# Apply damage to each entity
	for entity in entities_inside:
		var damage := _roll_damage()
		if entity.has_method("take_damage"):
			entity.take_damage(damage, damage_type, caster)
		elif entity.get_parent().has_method("take_damage"):
			entity.get_parent().take_damage(damage, damage_type, caster)

		# Try to apply condition
		_try_apply_condition(entity)

## Roll damage based on dice configuration
func _roll_damage() -> int:
	var total := 0
	for i in range(damage_dice[0]):
		total += randi_range(1, damage_dice[1])
	total += damage_dice[2]
	return max(1, total)

## Try to apply the condition based on chance
func _try_apply_condition(entity: Node) -> void:
	if condition_to_apply == Enums.Condition.NONE:
		return

	if randf() > condition_chance:
		return

	if entity.has_method("apply_condition"):
		entity.apply_condition(condition_to_apply, condition_duration)
	elif entity.get_parent().has_method("apply_condition"):
		entity.get_parent().apply_condition(condition_to_apply, condition_duration)

## Create particle effect
func _create_particles() -> void:
	particles = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = false
	particles.amount = int(hazard_radius * 20)  # More particles for larger zones
	particles.lifetime = 1.5
	particles.visibility_aabb = AABB(Vector3(-hazard_radius, -1, -hazard_radius), Vector3(hazard_radius * 2, 4, hazard_radius * 2))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = hazard_radius * 0.9

	mat.direction = Vector3(0, 1, 0)  # Rise upward
	mat.spread = 15.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.0
	mat.gravity = Vector3(0, -0.5, 0)
	mat.damping_min = 0.5
	mat.damping_max = 1.0

	mat.color = particle_color

	mat.scale_min = 0.15
	mat.scale_max = 0.35

	particles.process_material = mat

	# Particle mesh
	var draw_pass := SphereMesh.new()
	draw_pass.radius = 0.12
	draw_pass.height = 0.24
	particles.draw_pass_1 = draw_pass

	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = particle_color
	mesh_mat.emission_enabled = true
	mesh_mat.emission = Color(particle_color.r, particle_color.g, particle_color.b)
	mesh_mat.emission_energy_multiplier = 3.0
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_pass.material = mesh_mat

	add_child(particles)

## Create ground decal effect
func _create_ground_decal() -> void:
	ground_decal = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = hazard_radius
	disc.bottom_radius = hazard_radius
	disc.height = 0.05
	ground_decal.mesh = disc

	var mat := StandardMaterial3D.new()
	mat.albedo_color = decal_color
	mat.emission_enabled = true
	mat.emission = Color(decal_color.r, decal_color.g, decal_color.b)
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground_decal.material_override = mat

	add_child(ground_decal)
	ground_decal.position.y = 0.03  # Slightly above ground

## Expire and clean up
func _expire() -> void:
	is_active = false
	monitoring = false

	# Stop particles
	if particles:
		particles.emitting = false

	# Fade out and cleanup
	var tween := get_tree().create_tween()
	if ground_decal and ground_decal.material_override:
		var mat: StandardMaterial3D = ground_decal.material_override
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)

	tween.tween_callback(queue_free)

## Static factory method to spawn a hazard zone
static func spawn_hazard_zone(
	parent: Node,
	pos: Vector3,
	p_caster: Node,
	p_radius: float,
	p_duration: float,
	p_tick_interval: float,
	p_damage_dice: Array[int],
	p_damage_type: Enums.DamageType,
	p_condition: Enums.Condition,
	p_condition_chance: float,
	p_condition_duration: float,
	p_particle_color: Color,
	p_decal_color: Color
) -> HazardZone:
	var zone := HazardZone.new()
	zone.caster = p_caster
	zone.hazard_radius = p_radius
	zone.hazard_duration = p_duration
	zone.tick_interval = p_tick_interval
	zone.damage_dice = p_damage_dice
	zone.damage_type = p_damage_type
	zone.condition_to_apply = p_condition
	zone.condition_chance = p_condition_chance
	zone.condition_duration = p_condition_duration
	zone.particle_color = p_particle_color
	zone.decal_color = p_decal_color

	parent.add_child(zone)
	zone.global_position = pos

	return zone
