## gladiator_npc.gd - Arena fighter enemy for tournament combat
## Spawned by TournamentManager during arena rounds
class_name GladiatorNPC
extends CharacterBody3D

## Enemy data resource
var enemy_data: EnemyData

## Tournament tier this gladiator belongs to
var tournament_tier: TournamentManager.TournamentTier = TournamentManager.TournamentTier.NOVICE

## Combat stats (scaled by tier)
var max_hp: int = 50
var current_hp: int = 50
var armor_value: int = 10
var damage_min: int = 5
var damage_max: int = 12
var attack_cooldown: float = 1.5
var attack_range: float = 2.0
var aggro_range: float = 15.0
var movement_speed: float = 4.0

## State
var is_dead: bool = false
var target: Node = null
var _attack_timer: float = 0.0
var _is_attacking: bool = false

## Visual components
var billboard: BillboardSprite


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("attackable")
	add_to_group("tournament_enemy")

	# Setup collision
	collision_layer = 4  # Layer 3 (enemies)
	collision_mask = 1 | 2  # World + Player

	_create_collision()
	_create_visual()
	_scale_stats_by_tier()

	current_hp = max_hp


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta
		move_and_slide()

	# Update attack timer
	if _attack_timer > 0:
		_attack_timer -= delta

	# Find and track player
	if not target or not is_instance_valid(target):
		_find_target()

	if target and is_instance_valid(target):
		_update_combat(delta)


## Create collision shape
func _create_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)


## Create visual representation
func _create_visual() -> void:
	# Use bandit sprite as base for gladiators
	var tex: Texture2D
	if enemy_data and not enemy_data.icon_path.is_empty():
		tex = load(enemy_data.icon_path) as Texture2D

	if not tex:
		tex = load("res://assets/sprites/enemies/human_bandit.png") as Texture2D

	if not tex:
		tex = load("res://assets/sprites/npcs/civilians/man_civilian.png") as Texture2D

	if not tex:
		push_warning("[GladiatorNPC] No sprite texture available")
		return

	billboard = BillboardSprite.new()
	billboard.sprite_sheet = tex
	# human_bandit.png is a single image (1x1), other sprites may vary
	billboard.h_frames = 1
	billboard.v_frames = 1
	billboard.pixel_size = 0.01
	billboard.idle_frames = 3
	billboard.walk_frames = 3
	billboard.idle_fps = 3.0
	billboard.walk_fps = 6.0
	billboard.name = "Billboard"
	add_child(billboard)

	# Tint based on tier
	if billboard.sprite:
		match tournament_tier:
			TournamentManager.TournamentTier.NOVICE:
				billboard.sprite.modulate = Color(0.9, 0.9, 0.85)  # Pale
			TournamentManager.TournamentTier.VETERAN:
				billboard.sprite.modulate = Color(0.85, 0.8, 0.7)  # Tanned
			TournamentManager.TournamentTier.CHAMPION:
				billboard.sprite.modulate = Color(1.0, 0.85, 0.7)  # Bronze
			TournamentManager.TournamentTier.LEGEND:
				billboard.sprite.modulate = Color(1.0, 0.9, 0.5)  # Gold


## Scale stats based on tournament tier
func _scale_stats_by_tier() -> void:
	var tier_multiplier: float = 1.0

	match tournament_tier:
		TournamentManager.TournamentTier.NOVICE:
			tier_multiplier = 1.0
		TournamentManager.TournamentTier.VETERAN:
			tier_multiplier = 1.5
		TournamentManager.TournamentTier.CHAMPION:
			tier_multiplier = 2.0
		TournamentManager.TournamentTier.LEGEND:
			tier_multiplier = 3.0

	# Apply multiplier to stats
	if enemy_data:
		max_hp = int(enemy_data.max_hp * tier_multiplier)
		armor_value = int(enemy_data.armor_value * tier_multiplier)
		movement_speed = enemy_data.movement_speed
		aggro_range = enemy_data.aggro_range
		attack_range = enemy_data.attack_range

		# Get damage from first attack
		if not enemy_data.attacks.is_empty():
			var attack: EnemyAttackData = enemy_data.attacks[0]
			damage_min = int(attack.damage[0] * tier_multiplier)
			damage_max = int(attack.damage[1] * tier_multiplier)
			attack_cooldown = attack.cooldown
	else:
		# Default scaling
		max_hp = int(50 * tier_multiplier)
		armor_value = int(10 * tier_multiplier)
		damage_min = int(5 * tier_multiplier)
		damage_max = int(12 * tier_multiplier)


## Find the player target
func _find_target() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var dist: float = global_position.distance_to(player.global_position)
		if dist <= aggro_range:
			target = player


## Update combat behavior
func _update_combat(delta: float) -> void:
	var target_pos: Vector3 = target.global_position
	var dist: float = global_position.distance_to(target_pos)

	# Face target
	var look_dir: Vector3 = (target_pos - global_position).normalized()
	look_dir.y = 0
	if look_dir.length_squared() > 0.01:
		var target_basis := Basis.looking_at(look_dir, Vector3.UP)
		basis = basis.slerp(target_basis, delta * 5.0)

	# Move toward target if too far
	if dist > attack_range:
		var move_dir: Vector3 = (target_pos - global_position).normalized()
		move_dir.y = 0
		velocity.x = move_dir.x * movement_speed
		velocity.z = move_dir.z * movement_speed

		if billboard:
			billboard.set_walking(true)

		move_and_slide()
	else:
		# In attack range
		velocity.x = 0
		velocity.z = 0

		if billboard:
			billboard.set_walking(false)

		# Try to attack
		if _attack_timer <= 0 and not _is_attacking:
			_perform_attack()


## Perform an attack on the target
func _perform_attack() -> void:
	if not target or not is_instance_valid(target):
		return

	_is_attacking = true
	_attack_timer = attack_cooldown

	# Play attack animation
	if billboard:
		billboard.play_attack()

	# Damage after brief delay (windup)
	get_tree().create_timer(0.3).timeout.connect(_deal_damage)


## Deal damage to target
func _deal_damage() -> void:
	_is_attacking = false

	if not target or not is_instance_valid(target):
		return

	var dist: float = global_position.distance_to(target.global_position)
	if dist > attack_range + 0.5:
		return  # Target moved away

	var damage: int = randi_range(damage_min, damage_max)

	if target.has_method("take_damage"):
		target.take_damage(damage, Enums.DamageType.PHYSICAL, self)

	if AudioManager:
		AudioManager.play_sfx("enemy_attack")


## Take damage
func take_damage(amount: int, damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null) -> int:
	if is_dead:
		return 0

	# Apply armor reduction
	var reduced_amount: int = maxi(1, amount - int(armor_value / 4))
	var actual_damage: int = mini(reduced_amount, current_hp)
	current_hp -= actual_damage

	# Visual feedback
	if billboard:
		billboard.play_hurt()

	if AudioManager:
		AudioManager.play_sfx("enemy_hit")

	# Check death
	if current_hp <= 0:
		_die(attacker)

	return actual_damage


func get_armor_value() -> int:
	return armor_value


## Handle death
func _die(killer: Node = null) -> void:
	if is_dead:
		return

	is_dead = true

	print("[GladiatorNPC] Gladiator defeated!")

	# Play death animation
	if billboard:
		billboard.play_death()

	# Remove from groups
	remove_from_group("enemies")
	remove_from_group("attackable")
	remove_from_group("tournament_enemy")

	# Emit kill signal
	CombatManager.entity_killed.emit(self, killer)

	# Give XP
	if killer and killer.is_in_group("player") and GameManager and GameManager.player_data:
		var xp_reward: int = 50
		match tournament_tier:
			TournamentManager.TournamentTier.VETERAN:
				xp_reward = 100
			TournamentManager.TournamentTier.CHAMPION:
				xp_reward = 200
			TournamentManager.TournamentTier.LEGEND:
				xp_reward = 500

		GameManager.player_data.add_ip(xp_reward)

	if AudioManager:
		AudioManager.play_sfx("enemy_death")

	# Delay removal for death animation
	get_tree().create_timer(1.5).timeout.connect(queue_free)


## Static factory method to spawn a gladiator
static func spawn_gladiator(parent: Node, pos: Vector3, data: EnemyData, tier: TournamentManager.TournamentTier) -> GladiatorNPC:
	var gladiator := GladiatorNPC.new()
	gladiator.enemy_data = data
	gladiator.tournament_tier = tier
	gladiator.position = pos

	parent.add_child(gladiator)

	return gladiator
