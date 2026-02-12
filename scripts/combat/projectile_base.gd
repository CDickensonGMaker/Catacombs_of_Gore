## projectile_base.gd - Base projectile with movement, collision, lifetime, damage, homing, trail/impact effects
class_name ProjectileBase
extends Area3D

signal hit_target(target: Node, damage: int)
signal expired
signal returned_to_pool

## Projectile configuration
var projectile_data: ProjectileData
var owner_entity: Node = null
var direction: Vector3 = Vector3.FORWARD
var current_speed: float = 20.0

## State tracking
var is_active: bool = false
var lifetime_timer: float = 0.0
var homing_delay_timer: float = 0.0
var homing_target: Node3D = null

## Piercing/chaining state
var pierce_count: int = 0
var chain_count: int = 0
var hit_targets: Array[Node] = []

## Components (created dynamically)
var collision_shape: CollisionShape3D
var mesh_instance: MeshInstance3D
var trail: GPUParticles3D = null
var travel_audio: AudioStreamPlayer3D = null

## Physics
var gravity_value: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var velocity: Vector3 = Vector3.ZERO

## Pool reference
var _pool: Node = null

func _ready() -> void:
	# Set up collision
	monitoring = true
	monitorable = false
	collision_layer = 512  # Projectile layer (layer 10)
	collision_mask = 0

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# Create collision shape
	collision_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	collision_shape.shape = sphere
	add_child(collision_shape)

	# Create mesh instance for visual
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)

	# Start inactive
	deactivate()

## Initialize projectile with data
func initialize(data: ProjectileData, source: Node, dir: Vector3, target: Node3D = null) -> void:
	projectile_data = data
	owner_entity = source
	direction = dir.normalized()
	homing_target = target

	# Apply data settings
	current_speed = data.speed
	lifetime_timer = 0.0
	homing_delay_timer = 0.0
	pierce_count = 0
	chain_count = 0
	hit_targets.clear()

	# Update collision shape radius
	if collision_shape and collision_shape.shape is SphereShape3D:
		(collision_shape.shape as SphereShape3D).radius = data.collision_radius

	# Set collision mask based on what we hit
	collision_mask = 0
	if data.hits_enemies:
		collision_mask |= 4  # Enemy layer
		collision_mask |= 128  # Enemy hurtbox layer
	if data.hits_players:
		collision_mask |= 2  # Player layer
		collision_mask |= 16  # Player hurtbox layer
	if data.hits_world:
		collision_mask |= 1  # World layer

	# Setup visuals
	_setup_visuals()

	# Setup trail
	if data.has_trail:
		_setup_trail()

	# Setup travel sound
	if not data.travel_sound.is_empty():
		_setup_travel_audio()

	# Find homing target if enabled but none provided
	if data.is_homing and not homing_target:
		_acquire_homing_target()

	# Play fire sound
	if not data.fire_sound.is_empty():
		AudioManager.play_sfx_3d(data.fire_sound, global_position)

	# Spawn muzzle effect (smoke puff, flash, etc.)
	if not data.muzzle_effect_path.is_empty():
		_spawn_muzzle_effect()

	# Initialize velocity
	velocity = direction * current_speed

func _setup_visuals() -> void:
	if not projectile_data:
		return

	# Load mesh if specified
	if not projectile_data.mesh_path.is_empty():
		var mesh_res = load(projectile_data.mesh_path)
		if mesh_res is PackedScene:
			# Replace default mesh_instance with loaded scene
			if mesh_instance:
				mesh_instance.queue_free()
			var scene_instance: Node3D = mesh_res.instantiate()
			scene_instance.name = "ProjectileMesh"
			scene_instance.scale = projectile_data.scale
			add_child(scene_instance)
			mesh_instance = scene_instance
		elif mesh_res is Mesh:
			mesh_instance.mesh = mesh_res
			mesh_instance.scale = projectile_data.scale
	else:
		# Default sphere mesh
		var sphere := SphereMesh.new()
		sphere.radius = projectile_data.collision_radius
		sphere.height = projectile_data.collision_radius * 2
		mesh_instance.mesh = sphere
		mesh_instance.scale = projectile_data.scale

	# Load material if specified (only for MeshInstance3D)
	if mesh_instance is MeshInstance3D and not projectile_data.material_path.is_empty():
		var mat_res = load(projectile_data.material_path)
		if mat_res is Material:
			(mesh_instance as MeshInstance3D).material_override = mat_res

func _setup_trail() -> void:
	if trail:
		trail.queue_free()

	trail = GPUParticles3D.new()
	trail.emitting = true
	trail.amount = 20
	trail.lifetime = projectile_data.trail_lifetime
	trail.one_shot = false
	trail.explosiveness = 0.0

	# Create simple trail process material
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 0.0
	mat.initial_velocity_min = 0.1
	mat.initial_velocity_max = 0.2
	mat.gravity = Vector3.ZERO
	mat.scale_min = projectile_data.trail_width
	mat.scale_max = projectile_data.trail_width
	mat.color = projectile_data.trail_color
	trail.process_material = mat

	# Simple mesh for particles
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	trail.draw_pass_1 = quad

	add_child(trail)

func _setup_travel_audio() -> void:
	if travel_audio:
		travel_audio.queue_free()

	travel_audio = AudioStreamPlayer3D.new()
	var stream = load(projectile_data.travel_sound)
	if stream is AudioStream:
		travel_audio.stream = stream
		travel_audio.autoplay = true
		travel_audio.bus = "SFX"
		add_child(travel_audio)

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# Update lifetime
	lifetime_timer += delta
	if lifetime_timer >= projectile_data.lifetime:
		_expire()
		return

	# Update homing delay
	if projectile_data.is_homing and homing_delay_timer < projectile_data.homing_delay:
		homing_delay_timer += delta

	# Apply homing
	if projectile_data.is_homing and homing_delay_timer >= projectile_data.homing_delay:
		_update_homing(delta)

	# Apply acceleration
	if projectile_data.acceleration != 0:
		current_speed += projectile_data.acceleration * delta
		current_speed = clamp(current_speed, projectile_data.min_speed, projectile_data.max_speed)

	# Apply gravity
	if projectile_data.gravity_scale > 0:
		velocity.y -= gravity_value * projectile_data.gravity_scale * delta

	# Update velocity from direction and speed
	var horizontal_dir := Vector3(direction.x, 0, direction.z).normalized()
	velocity.x = horizontal_dir.x * current_speed
	velocity.z = horizontal_dir.z * current_speed
	if projectile_data.gravity_scale == 0:
		velocity.y = direction.y * current_speed

	# Move
	global_position += velocity * delta

	# Face movement direction
	if velocity.length() > 0.1:
		look_at(global_position + velocity.normalized())

	# Apply rotation spin if configured
	if projectile_data.rotation_speed != 0:
		rotate_object_local(Vector3.FORWARD, projectile_data.rotation_speed * delta)

func _update_homing(delta: float) -> void:
	if not homing_target or not is_instance_valid(homing_target):
		_acquire_homing_target()
		return

	var to_target := (homing_target.global_position - global_position).normalized()
	direction = direction.lerp(to_target, projectile_data.homing_strength * delta).normalized()

func _acquire_homing_target() -> void:
	if not projectile_data.hits_enemies:
		return

	var closest := CombatManager.get_closest_enemy(global_position, projectile_data.homing_acquire_range)
	if closest and closest is Node3D and closest not in hit_targets:
		homing_target = closest as Node3D

func _on_area_entered(area: Area3D) -> void:
	var target := area.get_parent()
	_handle_collision(target)

func _on_body_entered(body: Node3D) -> void:
	_handle_collision(body)

func _handle_collision(target: Node) -> void:
	if not is_active or not target:
		return

	# Don't hit owner
	if target == owner_entity:
		return

	# Don't hit same target twice
	if target in hit_targets:
		return

	# Check if valid target type
	var is_enemy := target.is_in_group("enemies")
	var is_player := target.is_in_group("player")
	var is_world := not is_enemy and not is_player

	if is_world:
		if projectile_data.hits_world:
			_on_hit_world()
		return

	if is_enemy and not projectile_data.hits_enemies:
		return
	if is_player and not projectile_data.hits_players:
		return

	# Apply damage
	hit_targets.append(target)
	var damage := projectile_data.roll_damage(pierce_count, chain_count)

	if target.has_method("take_damage"):
		target.take_damage(damage, projectile_data.damage_type, owner_entity)
		hit_target.emit(target, damage)

	# Apply stagger
	if projectile_data.stagger_power > 0 and target.has_method("apply_stagger"):
		target.apply_stagger(projectile_data.stagger_power)

	# Apply knockback
	if projectile_data.knockback_force > 0 and target is CharacterBody3D:
		var knockback_dir: Vector3 = (target.global_position - global_position).normalized()
		knockback_dir.y = 0.2
		target.velocity += knockback_dir * projectile_data.knockback_force

	# Apply condition
	if projectile_data.inflicts_condition != Enums.Condition.NONE:
		if randf() < projectile_data.condition_chance:
			if target.has_method("apply_condition"):
				target.apply_condition(projectile_data.inflicts_condition, projectile_data.condition_duration)

	# Play impact effect and sound
	_spawn_impact_effect()
	if not projectile_data.impact_sound.is_empty():
		AudioManager.play_sfx_3d(projectile_data.impact_sound, global_position)

	# Handle piercing
	if projectile_data.is_piercing and pierce_count < projectile_data.max_pierces:
		pierce_count += 1
		# Continue traveling
		return

	# Handle chaining
	if projectile_data.chain_targets > 0 and chain_count < projectile_data.chain_targets:
		_chain_to_next_target()
		return

	# AOE damage
	if projectile_data.aoe_radius > 0:
		_apply_aoe_damage()

	# Expire
	_expire()

func _on_hit_world() -> void:
	_spawn_impact_effect()
	if not projectile_data.impact_sound.is_empty():
		AudioManager.play_sfx_3d(projectile_data.impact_sound, global_position)

	if projectile_data.aoe_radius > 0:
		_apply_aoe_damage()

	_expire()

func _chain_to_next_target() -> void:
	chain_count += 1

	# Find next target
	var enemies := CombatManager.get_enemies_in_range(global_position, projectile_data.chain_range)
	var next_target: Node3D = null
	var closest_dist := 999.0

	for enemy in enemies:
		if enemy in hit_targets:
			continue
		if enemy is Node3D:
			var dist := global_position.distance_to((enemy as Node3D).global_position)
			if dist < closest_dist:
				closest_dist = dist
				next_target = enemy as Node3D

	if next_target:
		direction = (next_target.global_position - global_position).normalized()
		homing_target = next_target
	else:
		_expire()

func _apply_aoe_damage() -> void:
	var enemies := CombatManager.get_enemies_in_range(global_position, projectile_data.aoe_radius)
	var base_damage := projectile_data.roll_damage(pierce_count, chain_count)

	for enemy in enemies:
		if enemy in hit_targets:
			continue
		if not enemy is Node3D:
			continue

		var dist := global_position.distance_to((enemy as Node3D).global_position)
		var damage := base_damage

		if projectile_data.aoe_damage_falloff:
			var falloff := 1.0 - (dist / projectile_data.aoe_radius)
			damage = int(damage * falloff)

		damage = max(1, damage)

		if enemy.has_method("take_damage"):
			enemy.take_damage(damage, projectile_data.damage_type, owner_entity)
			hit_targets.append(enemy)

func _spawn_impact_effect() -> void:
	if not projectile_data or projectile_data.impact_effect_path.is_empty():
		return

	var effect_scene := load(projectile_data.impact_effect_path) as PackedScene
	if not effect_scene:
		return

	var effect := effect_scene.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node3D:
		(effect as Node3D).global_position = global_position
		(effect as Node3D).scale = Vector3.ONE * projectile_data.impact_scale


func _spawn_muzzle_effect() -> void:
	if not projectile_data or projectile_data.muzzle_effect_path.is_empty():
		return

	var effect_scene := load(projectile_data.muzzle_effect_path) as PackedScene
	if not effect_scene:
		return

	var effect := effect_scene.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node3D:
		(effect as Node3D).global_position = global_position
		(effect as Node3D).scale = Vector3.ONE * projectile_data.muzzle_effect_scale
		# Face the direction of fire
		(effect as Node3D).look_at(global_position + direction)

func _expire() -> void:
	if not is_active:
		return

	expired.emit()

	# Stop trail emission
	if trail:
		trail.emitting = false

	# Stop travel sound
	if travel_audio:
		travel_audio.stop()

	# Return to pool or free
	if _pool:
		deactivate()
		returned_to_pool.emit()
	else:
		queue_free()

## Activate projectile (called by pool)
func activate() -> void:
	is_active = true
	visible = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	set_physics_process(true)
	set_deferred("monitoring", true)

	if trail:
		trail.emitting = true

## Deactivate projectile (called by pool)
func deactivate() -> void:
	is_active = false
	visible = false
	set_deferred("monitoring", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	set_physics_process(false)

	if trail:
		trail.emitting = false
	if travel_audio:
		travel_audio.stop()

	# Reset state
	hit_targets.clear()
	pierce_count = 0
	chain_count = 0
	homing_target = null
	lifetime_timer = 0.0
	homing_delay_timer = 0.0

## Set pool reference
func set_pool(pool: Node) -> void:
	_pool = pool
