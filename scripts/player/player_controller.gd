# File: scripts/player/player_controller.gd
# Attach to: Player (CharacterBody3D)
extends CharacterBody3D
class_name PlayerController

const DEBUG := false
const DEBUG_UNLIMITED_STAMINA := true  # For testing - disable stamina drain

# --- Movement tuning ---
@export var walk_speed: float = 6.0  # Increased 50% for testing (was 4.0)
@export var run_speed: float = 7.0
@export var acceleration: float = 18.0
@export var gravity: float = 24.0
@export var turn_speed: float = 10.0 # higher = snappier turning
@export var jump_velocity: float = 8.0  # Jump strength

# --- Sprint tuning ---
var sprint_stamina_cost: float = 15.0  # Stamina drain per second while sprinting
var stamina_regen_delay: float = 1.0   # Seconds to wait before regen starts after sprinting
var time_since_sprint: float = 0.0     # Timer for regen delay
var is_sprinting: bool = false
var stamina_drain_accumulator: float = 0.0  # Accumulates fractional stamina drain
var stamina_regen_accumulator: float = 0.0  # Accumulates fractional stamina regen

# --- Dodge tuning ---
var dodge_stamina_cost: float = 20.0
var base_iframe_duration: float = 0.3  # Seconds of invulnerability
var roll_distance: float = 4.0
var sidestep_distance: float = 2.0
var is_dodging: bool = false
var iframe_timer: float = 0.0
var dodge_velocity: Vector3 = Vector3.ZERO
var dodge_timer: float = 0.0
var dodge_duration: float = 0.3  # How long the dodge movement lasts

# --- Combat tuning (light attack) ---
@export var light_attack_damage: int = 10
@export var light_attack_duration: float = 0.12
@export var light_attack_cooldown: float = 0.25

# --- Interaction tuning ---
@export var interaction_range: float = 2.5  # How far player can interact

@onready var camera_pivot: Node3D = $CameraPivot
@onready var model: Node3D = $MeshRoot
@onready var melee_hitbox: Area3D = $MeshRoot/MeleeHitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var spell_caster: SpellCaster = $SpellCaster

var can_attack: bool = true
var lock_on_target: Node3D = null  # Current lock-on target for combat
var current_interactable: Node = null  # Currently highlighted interactable
var mana_regen_accumulator: float = 0.0  # Accumulates fractional mana regen

## Buff VFX manager for visual effects on conditions
var buff_vfx_manager: BuffVFXManager = null

func _ready() -> void:
	# Add to player group
	add_to_group("player")

	# Make sure the hitbox starts off.
	melee_hitbox.monitoring = false

	# Set up hurtbox so enemies can damage us
	if hurtbox:
		hurtbox.set_owner_entity(self)
		if DEBUG:
			print("[Player] Hurtbox set up with owner_entity")

	# Create and attach buff VFX manager
	buff_vfx_manager = BuffVFXManager.new()
	buff_vfx_manager.name = "BuffVFXManager"
	buff_vfx_manager.owner_entity = self
	add_child(buff_vfx_manager)

func _unhandled_input(event: InputEvent) -> void:
	# Don't process input if in menu or dialogue
	if GameManager.is_in_menu or GameManager.is_in_dialogue:
		return

	# Light attack input (also casts equipped spell)
	if event.is_action_pressed("light_attack") and can_attack:
		_do_light_attack()

	# Interaction input
	if event.is_action_pressed("interact"):
		_try_interact()

	# Hotbar inputs (keys 1-9, 0)
	for i in range(10):
		var action_name := "hotbar_%d" % ((i + 1) % 10)  # hotbar_1 through hotbar_9, then hotbar_0
		if event.is_action_pressed(action_name):
			InventoryManager.use_hotbar_slot(i)
			break

func _physics_process(delta: float) -> void:
	# Don't process if dead
	if is_dead:
		return

	# --- Dodge input ---
	if Input.is_action_just_pressed("dodge"):
		_try_dodge()

	# --- Process active dodge ---
	if is_dodging:
		dodge_timer -= delta
		iframe_timer -= delta

		if iframe_timer <= 0:
			_set_invulnerable(false)

		if dodge_timer <= 0:
			is_dodging = false
			dodge_velocity = Vector3.ZERO
		else:
			velocity.x = dodge_velocity.x
			velocity.z = dodge_velocity.z
			# Skip normal movement processing during dodge

			# Still apply gravity
			if not is_on_floor():
				velocity.y -= gravity * delta
			else:
				if velocity.y < 0:
					velocity.y = -0.1

			move_and_slide()
			_regenerate_mana(delta)
			_update_interaction()
			return

	# --- Check encumbrance ---
	var is_overencumbered := InventoryManager.is_overencumbered()

	# --- Build a 2D input vector from our Input Map actions ---
	# X: left/right, Y: forward/back
	var input_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var input_y := Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	var input_vec := Vector2(input_x, input_y)

	# Normalize so diagonal isn't faster
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()

	# --- Convert input into world direction relative to camera yaw ---
	# Use the pivot's LOCAL yaw so rotating the player body doesn't affect movement direction.
	var yaw := camera_pivot.rotation.y
	var forward := Vector3(sin(yaw), 0.0, cos(yaw)) * -1.0
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))

	var desired_dir := (right * input_vec.x + forward * input_vec.y)
	if desired_dir.length() > 0.001:
		desired_dir = desired_dir.normalized()

	# --- Choose speed (with sprint/stamina system) ---
	var speed := walk_speed
	var wants_to_sprint := Input.is_action_pressed("sprint") and desired_dir.length() > 0.001 and not is_overencumbered
	var has_stamina := DEBUG_UNLIMITED_STAMINA or (GameManager.player_data and GameManager.player_data.current_stamina > 0)

	if wants_to_sprint and has_stamina:
		# Sprinting: 35% speed boost
		speed = walk_speed * 1.35
		is_sprinting = true
		time_since_sprint = 0.0

		# Drain stamina over time (reduced by ENDURANCE skill) - skip if unlimited
		if not DEBUG_UNLIMITED_STAMINA:
			var drain_mult := 1.0
			if GameManager.player_data:
				drain_mult = GameManager.player_data.get_stamina_drain_multiplier()
			stamina_drain_accumulator += sprint_stamina_cost * drain_mult * delta
			if stamina_drain_accumulator >= 1.0:
				var drain_amount := int(stamina_drain_accumulator)
				stamina_drain_accumulator -= drain_amount
				GameManager.player_data.use_stamina(drain_amount)
	else:
		# Not sprinting
		is_sprinting = false
		stamina_drain_accumulator = 0.0

		# Increment time since last sprint for regen delay
		time_since_sprint += delta

		# Regenerate stamina after delay
		if time_since_sprint >= stamina_regen_delay and GameManager.player_data:
			var char_data := GameManager.player_data
			if char_data.current_stamina < char_data.max_stamina:
				var regen_rate := char_data.get_stamina_regen()
				stamina_regen_accumulator += regen_rate * delta

				if stamina_regen_accumulator >= 1.0:
					var regen_amount := int(stamina_regen_accumulator)
					stamina_regen_accumulator -= regen_amount
					char_data.restore_stamina(regen_amount)
			else:
				stamina_regen_accumulator = 0.0

	# --- Apply overencumbered penalty ---
	if is_overencumbered:
		speed *= 0.5

	# --- Apply HASTED condition bonus (+50% speed) ---
	if GameManager.player_data and GameManager.player_data.has_condition(Enums.Condition.HASTED):
		speed *= 1.5

	# --- Apply SLOWED condition penalty (-50% speed) ---
	if GameManager.player_data and GameManager.player_data.has_condition(Enums.Condition.SLOWED):
		speed *= 0.5

	# --- Apply FROZEN condition penalty (-75% speed, worse than slowed) ---
	if GameManager.player_data and GameManager.player_data.has_condition(Enums.Condition.FROZEN):
		speed *= 0.25

	# --- Horizontal velocity with acceleration ---
	var target_vel := desired_dir * speed
	velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)

	# --- Jump ---
	if is_on_floor() and Input.is_action_just_pressed("jump") and not is_overencumbered:
		velocity.y = jump_velocity

	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Keep grounded (prevents tiny bouncing) unless jumping
		if velocity.y < 0:
			velocity.y = -0.1

	move_and_slide()

	# --- Mana regeneration ---
	_regenerate_mana(delta)

	# --- Update conditions and apply DOT damage ---
	_update_conditions(delta)

	# --- Smoothly rotate ONLY the visuals (Model) toward movement direction ---
	if desired_dir.length() > 0.001:
		var target_yaw := atan2(desired_dir.x, desired_dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, turn_speed * delta)

	# --- Update interaction detection ---
	_update_interaction()

func _do_light_attack() -> void:
	can_attack = false

	# Check if spell is equipped (takes priority over weapon)
	var equipped_spell: SpellData = InventoryManager.get_equipped_spell()
	print("[Player] _do_light_attack - equipped_spell: ", equipped_spell.display_name if equipped_spell else "NONE")
	if equipped_spell:
		_do_spell_attack(equipped_spell)
		return

	var weapon: WeaponData = InventoryManager.get_equipped_weapon()

	# Check if weapon is broken - if so, use unarmed attack instead
	if weapon and InventoryManager.is_equipment_broken("main_hand"):
		weapon = null  # Force unarmed attack
		# Show warning (only occasionally to avoid spam)
		if randi() % 5 == 0:  # 20% chance to show message
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Your weapon is BROKEN!")

	# Check if weapon is ranged - use ranged attack instead
	if weapon and weapon.is_ranged:
		_do_ranged_attack(weapon)
		return

	# Trigger first-person attack animation
	if camera_pivot and camera_pivot.has_method("play_attack_animation"):
		camera_pivot.play_attack_animation()

	# Calculate damage from equipped weapon or use unarmed
	var damage: int = light_attack_damage
	var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL

	if weapon:
		var quality: Enums.ItemQuality = InventoryManager.get_equipped_weapon_quality()
		damage = weapon.roll_damage(quality)
		damage_type = weapon.damage_type
	else:
		# Unarmed: 1d4 + effective grit
		var grit: int = GameManager.player_data.get_effective_stat(Enums.Stat.GRIT) if GameManager.player_data else 3
		damage = randi_range(1, 4) + grit

	# Configure hitbox with damage values and owner
	if melee_hitbox is Hitbox:
		melee_hitbox.set_owner_entity(self)
		melee_hitbox.set_damage_values(damage, damage_type)
		melee_hitbox.activate()
	else:
		# Fallback for non-Hitbox Area3D
		melee_hitbox.monitoring = true

	# Degrade weapon with each attack (1 durability per attack)
	InventoryManager.degrade_weapon(1)

	# Keep hitbox active for attack duration
	await get_tree().create_timer(light_attack_duration).timeout

	# Deactivate hitbox
	if melee_hitbox is Hitbox:
		melee_hitbox.deactivate()
	else:
		melee_hitbox.monitoring = false

	# Cooldown before next attack
	await get_tree().create_timer(light_attack_cooldown).timeout
	can_attack = true

## Perform a spell attack with the equipped spell
func _do_spell_attack(spell: SpellData) -> void:
	print("[Player] _do_spell_attack called with: ", spell.display_name)
	if not spell_caster:
		print("[Player] ERROR: No spell_caster node!")
		_show_cast_feedback("No spell caster!")
		can_attack = true
		return

	var char_data := GameManager.player_data
	if not char_data:
		_show_cast_feedback("No character data!")
		can_attack = true
		return

	# Check mana cost
	var mana_cost := spell.get_mana_cost()
	print("[Player] Mana check: current=%d, cost=%d" % [char_data.current_mana, mana_cost])
	if char_data.current_mana < mana_cost:
		_show_cast_feedback("Not enough mana! (%d/%d)" % [char_data.current_mana, mana_cost])
		can_attack = true
		return

	# Check requirements and show specific failure messages
	var player_know := char_data.get_effective_stat(Enums.Stat.KNOWLEDGE)
	var player_will := char_data.get_effective_stat(Enums.Stat.WILL)
	var player_arcana := char_data.get_skill(Enums.Skill.ARCANA_LORE)

	if player_know < spell.required_knowledge:
		_show_cast_feedback("Need %d Knowledge (have %d)" % [spell.required_knowledge, player_know])
		can_attack = true
		return
	if player_will < spell.required_will:
		_show_cast_feedback("Need %d Will (have %d)" % [spell.required_will, player_will])
		can_attack = true
		return
	if player_arcana < spell.required_arcana_lore:
		_show_cast_feedback("Need %d Arcana Lore (have %d)" % [spell.required_arcana_lore, player_arcana])
		can_attack = true
		return

	# Trigger first-person cast animation
	if camera_pivot and camera_pivot.has_method("play_cast_animation"):
		camera_pivot.play_cast_animation(spell)

	# Start casting the spell
	print("[Player] Calling spell_caster.start_cast...")
	var success := spell_caster.start_cast(spell)
	print("[Player] start_cast returned: ", success)
	if not success:
		_show_cast_feedback("Cannot cast right now")
		can_attack = true
		return

	# Use spell cooldown or default attack cooldown
	var cooldown := spell.cooldown if spell.cooldown > 0 else light_attack_cooldown
	await get_tree().create_timer(cooldown).timeout
	can_attack = true

## Perform a ranged attack with the equipped ranged weapon
func _do_ranged_attack(weapon: WeaponData) -> void:
	# Check if weapon requires ammo
	if not weapon.ammo_type.is_empty():
		# Check if player has required ammo
		if not InventoryManager.has_item(weapon.ammo_type):
			_show_out_of_ammo_message(weapon.ammo_type)
			can_attack = true
			return
		# Consume 1 ammo
		InventoryManager.remove_item(weapon.ammo_type, 1)

	# Check for backfire (musket mechanic) - roll before firing
	if weapon.backfire_chance > 0 and randf() < weapon.backfire_chance:
		_handle_backfire(weapon)
		# Still continue with attack, but player takes damage

	# Trigger first-person attack animation for firing
	if camera_pivot and camera_pivot.has_method("play_attack_animation"):
		camera_pivot.play_attack_animation()

	# Load projectile data
	var projectile_data: ProjectileData = null
	if not weapon.projectile_data_path.is_empty():
		projectile_data = load(weapon.projectile_data_path) as ProjectileData

	if not projectile_data:
		if DEBUG:
			print("[Player] No projectile data for ranged weapon: ", weapon.id)
		# Fallback to default arrow
		projectile_data = load("res://resources/projectiles/arrow_basic.tres") as ProjectileData

	if not projectile_data:
		if DEBUG:
			print("[Player] Could not load any projectile data!")
		can_attack = true
		return

	# Calculate spawn position (in front of player at chest height)
	var spawn_offset := Vector3.FORWARD.rotated(Vector3.UP, model.rotation.y) * 1.0
	spawn_offset.y = 1.2  # Chest height
	var spawn_pos := global_position + spawn_offset

	# Raycast from camera through screen center to find aim point
	var camera := get_viewport().get_camera_3d()
	var screen_center := get_viewport().get_visible_rect().size / 2
	var ray_origin := camera.project_ray_origin(screen_center)
	var ray_end := ray_origin + camera.project_ray_normal(screen_center) * 100.0

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)

	var target_point: Vector3
	if result:
		target_point = result.position
	else:
		target_point = ray_end

	# Calculate direction from projectile spawn to target point
	var direction := (target_point - spawn_pos).normalized()

	# Spawn projectile via CombatManager
	CombatManager.spawn_projectile(projectile_data, self, spawn_pos, direction, null)

	# Play fire sound event
	AudioManager.play_sfx_3d("projectile_fire", spawn_pos)

	# Heavy recoil for musket - screen shake, knockback, and weapon kick
	if weapon.weapon_type == Enums.WeaponType.MUSKET:
		_apply_screen_shake(0.5, 0.25)
		_apply_musket_recoil(direction)

	# Degrade weapon with each attack
	InventoryManager.degrade_weapon(1)

	# Reload time as cooldown (ranged weapons have reload_time)
	var cooldown := weapon.reload_time if weapon.reload_time > 0 else light_attack_cooldown
	await get_tree().create_timer(cooldown).timeout
	can_attack = true

## Handle weapon backfire (musket mechanic)
func _handle_backfire(weapon: WeaponData) -> void:
	if DEBUG:
		print("[Player] Weapon backfired!")

	# Player takes a portion of the weapon's damage
	var backfire_damage := randi_range(2, 6)  # 2-6 damage on backfire
	take_damage(backfire_damage, Enums.DamageType.FIRE, self)

	# Screen shake for backfire
	_apply_screen_shake(0.5, 0.2)

	# Could play a backfire sound here
	AudioManager.play_sfx_3d("player_hit", global_position)

## Apply screen shake effect
func _apply_screen_shake(intensity: float, duration: float) -> void:
	if camera_pivot and camera_pivot.has_method("apply_shake"):
		camera_pivot.apply_shake(intensity, duration)
	elif camera_pivot:
		# Simple fallback shake using tween
		var original_pos := camera_pivot.position
		var tween := create_tween()
		var shake_time := 0.0
		while shake_time < duration:
			var offset := Vector3(
				randf_range(-intensity, intensity),
				randf_range(-intensity, intensity),
				0
			)
			tween.tween_property(camera_pivot, "position", original_pos + offset, 0.02)
			shake_time += 0.02
		tween.tween_property(camera_pivot, "position", original_pos, 0.02)


## Apply heavy musket recoil - knockback and camera kick
func _apply_musket_recoil(fire_direction: Vector3) -> void:
	# Knockback - push player backward
	var knockback_direction := -fire_direction
	knockback_direction.y = 0.0
	knockback_direction = knockback_direction.normalized()
	velocity += knockback_direction * 8.0  # Strong backward push

	# Camera kick - pitch up sharply then recover
	if camera_pivot:
		var original_rotation := camera_pivot.rotation_degrees.x
		var kick_tween := create_tween()
		kick_tween.set_ease(Tween.EASE_OUT)
		kick_tween.set_trans(Tween.TRANS_EXPO)
		# Kick up sharply
		kick_tween.tween_property(camera_pivot, "rotation_degrees:x", original_rotation - 12.0, 0.08)
		# Recover slowly
		kick_tween.set_ease(Tween.EASE_IN_OUT)
		kick_tween.set_trans(Tween.TRANS_QUAD)
		kick_tween.tween_property(camera_pivot, "rotation_degrees:x", original_rotation, 0.35)

	# FPS arms recoil - kick the weapon model back
	if camera_pivot and camera_pivot.has_method("get_fps_arms"):
		var fps_arms: FirstPersonArms = camera_pivot.get_fps_arms()
		if fps_arms and fps_arms.has_method("apply_recoil"):
			fps_arms.apply_recoil(0.15, 0.4)


## Show out of ammo feedback message
func _show_out_of_ammo_message(ammo_type: String) -> void:
	var ammo_name := InventoryManager.get_item_name(ammo_type)
	if ammo_name == ammo_type:
		# Fallback to capitalize the id if no display name found
		ammo_name = ammo_type.capitalize()

	print("[Player] Out of ammo: ", ammo_name)

	# Try to show message via HUD
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.show_message("Out of %s!" % ammo_name)
	elif hud and hud.has_method("show_interaction_prompt"):
		# Fallback to interaction prompt if show_message doesn't exist
		hud.show_interaction_prompt("Out of %s!" % ammo_name)
		# Clear after a moment
		get_tree().create_timer(1.5).timeout.connect(func():
			if hud and hud.has_method("hide_interaction_prompt"):
				hud.hide_interaction_prompt()
		)

## Find the nearest interactable within range
func _find_nearest_interactable() -> Node:
	var nearest: Node = null
	var nearest_dist: float = interaction_range

	# Check all interactables in the scene
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node is Node3D:
			continue

		var dist: float = global_position.distance_to((node as Node3D).global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = node

	return nearest

## Try to interact with the nearest interactable
func _try_interact() -> void:
	var target := _find_nearest_interactable()
	if target and target.has_method("interact"):
		target.interact(self)

## Update interaction detection (called each frame)
func _update_interaction() -> void:
	var nearest := _find_nearest_interactable()

	# Update current interactable
	if nearest != current_interactable:
		current_interactable = nearest
		_update_interaction_prompt()

func _update_interaction_prompt() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if not hud:
		return

	if current_interactable and current_interactable.has_method("get_interaction_prompt"):
		var prompt: String = current_interactable.get_interaction_prompt()
		if hud.has_method("show_interaction_prompt"):
			hud.show_interaction_prompt(prompt)
	else:
		if hud.has_method("hide_interaction_prompt"):
			hud.hide_interaction_prompt()

## Attempt to perform a dodge (roll or sidestep)
func _try_dodge() -> void:
	# Can't dodge if overencumbered
	if InventoryManager.is_overencumbered():
		return

	# Can't dodge if already dodging, or no stamina
	if is_dodging:
		return

	if not GameManager.player_data:
		return

	var stamina := GameManager.player_data.current_stamina
	if not DEBUG_UNLIMITED_STAMINA and stamina < dodge_stamina_cost:
		return

	# Get DODGE skill for i-frame bonus
	var dodge_skill: int = 0
	if GameManager.player_data:
		dodge_skill = GameManager.player_data.get_skill(Enums.Skill.DODGE)
	var iframe_bonus := dodge_skill * 0.05  # +0.05s per skill level

	# Check movement direction
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	if input_dir.length() > 0.1:
		# ROLL - direction held, longer i-frames
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		_perform_dodge(direction, roll_distance, base_iframe_duration + iframe_bonus)
	else:
		# SIDESTEP - no direction, shorter i-frames, dodge backward
		var direction := -transform.basis.z  # Backward
		_perform_dodge(direction, sidestep_distance, base_iframe_duration * 0.5 + iframe_bonus * 0.5)

	if GameManager.player_data and not DEBUG_UNLIMITED_STAMINA:
		GameManager.player_data.use_stamina(int(dodge_stamina_cost))

## Execute the dodge movement and i-frames
func _perform_dodge(direction: Vector3, distance: float, iframe_time: float) -> void:
	is_dodging = true
	iframe_timer = iframe_time
	dodge_timer = dodge_duration
	dodge_velocity = direction * (distance / dodge_duration)

	# Disable hurtbox for i-frames
	_set_invulnerable(true)

## Toggle player invulnerability by enabling/disabling hurtbox
func _set_invulnerable(invulnerable: bool) -> void:
	# Use the existing hurtbox reference
	if hurtbox:
		hurtbox.monitoring = not invulnerable
		hurtbox.monitorable = not invulnerable

## Combat - Receive damage from enemies
func take_damage(amount: int, damage_type: Enums.DamageType, attacker: Node) -> int:
	# Don't take damage if already dead
	if is_dead:
		return 0

	if DEBUG:
		print("[Player] take_damage called! amount=", amount, " type=", damage_type, " from=", str(attacker.name) if attacker else "unknown")
	if not GameManager.player_data:
		return 0

	var player_data := GameManager.player_data

	# Apply armor reduction for physical damage only
	if damage_type == Enums.DamageType.PHYSICAL:
		var armor := InventoryManager.get_total_armor_value()
		amount = int(amount * (100.0 / (100.0 + armor)))

	# Apply equipment resistance for the damage type
	var equip_resist := InventoryManager.get_equipment_resistance(damage_type)
	if equip_resist != 0.0:
		amount = int(amount * (1.0 - equip_resist))

	# Apply magic resistance from Will stat for non-physical damage
	if damage_type != Enums.DamageType.PHYSICAL:
		var will_resist := player_data.get_magic_resistance()
		amount = int(amount * (1.0 - will_resist))

	# Minimum 1 damage
	amount = max(1, amount)

	# Apply damage to player data
	var actual_damage := player_data.take_damage(amount)

	# Degrade armor when taking hits (1 durability per 10 damage, minimum 1)
	var degrade_amount: int = maxi(1, actual_damage / 10)
	InventoryManager.degrade_armor(degrade_amount)

	# Show damage feedback
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("spawn_damage_number"):
		hud.spawn_damage_number(global_position + Vector3.UP * 2, actual_damage)

	# Check for death
	if player_data.is_dead():
		_on_death()

	return actual_damage

## Apply stagger effect
func apply_stagger(power: float) -> void:
	# Could implement stagger animation/state here
	# For now, brief movement interrupt
	can_attack = false
	await get_tree().create_timer(0.3 * power).timeout
	can_attack = true

## Apply a condition (poison, burning, etc.)
func apply_condition(condition: Enums.Condition, duration: float) -> void:
	if GameManager.player_data:
		GameManager.player_data.apply_condition(condition, duration)

## Get character data for spell/combat systems
func get_character_data() -> CharacterData:
	return GameManager.player_data

## Heal the player
func heal(amount: int) -> int:
	if GameManager.player_data:
		return GameManager.player_data.heal(amount)
	return 0

## Show spell casting feedback
func _show_cast_feedback(message: String) -> void:
	if DEBUG:
		print("[Player] ", message)

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(message)

## Update conditions and apply DOT damage
func _update_conditions(delta: float) -> void:
	if not GameManager.player_data:
		return

	# Update conditions and get any DOT damage to apply
	var dot_damage: Dictionary = GameManager.player_data.update_conditions(delta)

	# Apply DOT damage
	for damage_type in dot_damage:
		var amount: int = dot_damage[damage_type]
		if amount > 0:
			take_damage(amount, damage_type, null)
			if DEBUG:
				print("[Player] DOT damage: ", amount, " type: ", damage_type)

## Regenerate mana over time
func _regenerate_mana(delta: float) -> void:
	var char_data := GameManager.player_data
	if not char_data:
		return

	# Don't regen if at max
	if char_data.current_mana >= char_data.max_mana:
		mana_regen_accumulator = 0.0
		return

	# Mana regen formula: 1.0 + (Will * 0.5) + (Knowledge * 0.25) per second
	# With base stats (Will=3, Knowledge=3): ~3.25 mana/sec
	var regen_rate := char_data.get_mana_regen()

	# Accumulate fractional regen over time
	mana_regen_accumulator += regen_rate * delta

	# Only restore whole mana points
	if mana_regen_accumulator >= 1.0:
		var whole_mana := int(mana_regen_accumulator)
		mana_regen_accumulator -= whole_mana
		char_data.restore_mana(whole_mana)

## Track if player is dead
var is_dead: bool = false

## Handle player death
func _on_death() -> void:
	if is_dead:
		return  # Already dead, don't process again

	is_dead = true
	if DEBUG:
		print("[Player] Player has died!")

	# Disable hurtbox so we stop taking damage
	if hurtbox:
		hurtbox.disable()

	# Stop movement
	velocity = Vector3.ZERO
	can_attack = false

	# Notify game manager
	GameManager.on_player_death()
