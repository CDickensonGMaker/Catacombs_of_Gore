## cursed_totem.gd - Necromantic spawn point for skeletons
## Place near ruins or in dungeons - skeletons only spawn from these
class_name CursedTotem
extends StaticBody3D

signal damaged(amount: int, damage_type: Enums.DamageType, attacker: Node)
signal destroyed(destroyer: Node)

## Configuration
@export var spawner_id: String = "cursed_totem"
@export var display_name: String = "Cursed Totem"
@export var max_hp: int = 150
@export var armor_value: int = 5

## Spawning configuration
@export var spawn_interval_min: float = 45.0
@export var spawn_interval_max: float = 75.0
@export var max_spawned_enemies: int = 2
@export var spawn_radius: float = 4.0
@export var spawn_count_min: int = 1
@export var spawn_count_max: int = 1

## Enemy data paths
const SKELETON_WARRIOR_PATH := "res://data/enemies/skeleton_warrior.tres"

## Visual
const PENTAGRAM_SPRITE_PATH := "res://Sprite folders grab bag/candlepentagram.png"

## Runtime state
var current_hp: int
var is_destroyed: bool = false
var spawn_timer: float = 0.0
var current_spawn_interval: float = 30.0
var spawned_enemies: Array[Node] = []

## Components
var sprite: Sprite3D
var hurtbox: Hurtbox
var collision_shape: CollisionShape3D
var glow_light: OmniLight3D

func _ready() -> void:
	add_to_group("spawners")
	add_to_group("destructibles")
	add_to_group("cursed_totems")

	current_hp = max_hp

	_create_visual()
	_create_collision()
	_create_hurtbox()
	_create_glow()

	# Initial spawn delay
	current_spawn_interval = randf_range(spawn_interval_min, spawn_interval_max) * 0.5
	spawn_timer = 0.0

	print("[CursedTotem] Initialized at ", global_position)


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return

	_cleanup_dead_enemies()

	spawn_timer += delta
	if spawn_timer >= current_spawn_interval:
		spawn_timer = 0.0
		current_spawn_interval = randf_range(spawn_interval_min, spawn_interval_max)
		_try_spawn_skeleton()


## Create the pentagram sprite visual - billboard style like trees/bushes
func _create_visual() -> void:
	sprite = Sprite3D.new()
	sprite.name = "PentagramSprite"

	var tex: Texture2D = load(PENTAGRAM_SPRITE_PATH)
	if tex:
		sprite.texture = tex
		sprite.pixel_size = 0.012  # Scale for visibility
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y  # Face player, stay upright
		# Position sprite so bottom is at ground level
		var sprite_height: float = tex.get_height() * sprite.pixel_size
		sprite.position = Vector3(0, sprite_height * 0.5, 0)
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.no_depth_test = false
	else:
		push_warning("[CursedTotem] Failed to load pentagram sprite")

	add_child(sprite)


## Create collision shape
func _create_collision() -> void:
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "Collision"

	var shape := CylinderShape3D.new()
	shape.radius = 1.5
	shape.height = 0.5
	collision_shape.shape = shape
	collision_shape.position.y = 0.25

	add_child(collision_shape)


## Create hurtbox for receiving damage
func _create_hurtbox() -> void:
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"

	hurtbox.collision_layer = 128  # enemy_hurtbox
	hurtbox.collision_mask = 8 + 512  # player_hitbox + projectile
	hurtbox.monitoring = true
	hurtbox.monitorable = true

	var shape := CollisionShape3D.new()
	shape.name = "HurtboxShape"
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 1.0, 3.0)
	shape.shape = box
	shape.position.y = 0.5
	hurtbox.add_child(shape)

	add_child(hurtbox)

	hurtbox.set_owner_entity(self)
	hurtbox.add_to_group("enemy_hurtbox")
	hurtbox.add_to_group("hurtbox")
	hurtbox.hurt.connect(_on_hurtbox_hurt)


## Create eerie glow effect
func _create_glow() -> void:
	glow_light = OmniLight3D.new()
	glow_light.name = "CursedGlow"
	glow_light.light_color = Color(0.6, 0.2, 0.8)  # Purple glow
	glow_light.light_energy = 1.5
	glow_light.omni_range = 6.0
	glow_light.position = Vector3(0, 1.0, 0)
	add_child(glow_light)


## Clean up dead enemies
func _cleanup_dead_enemies() -> void:
	var to_remove: Array[Node] = []
	for enemy in spawned_enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			to_remove.append(enemy)
		elif enemy.has_method("is_dead") and enemy.is_dead():
			to_remove.append(enemy)

	for enemy in to_remove:
		spawned_enemies.erase(enemy)


## Spawn skeleton enemies
func _try_spawn_skeleton() -> void:
	if spawned_enemies.size() >= max_spawned_enemies:
		return

	var desired_count := randi_range(spawn_count_min, spawn_count_max)
	var available_slots := max_spawned_enemies - spawned_enemies.size()
	var actual_count := mini(desired_count, available_slots)

	var parent := get_tree().current_scene

	for i in actual_count:
		var angle := randf() * TAU
		var distance := randf_range(2.0, spawn_radius)
		var spawn_offset := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var spawn_pos := global_position + spawn_offset

		# Spawn skeleton using the skeleton spawner
		var enemy: Node = EnemyBase.spawn_skeleton_enemy(
			parent,
			spawn_pos,
			SKELETON_WARRIOR_PATH
		)

		if enemy:
			spawned_enemies.append(enemy)

			# Configure to stay near totem
			if "wander_radius" in enemy:
				enemy.wander_radius = 10.0
			if "leash_radius" in enemy:
				enemy.leash_radius = 20.0
			if "spawn_position" in enemy:
				enemy.spawn_position = global_position

			if enemy.has_signal("died"):
				enemy.died.connect(_on_spawned_enemy_died.bind(enemy))

			print("[CursedTotem] Spawned skeleton at ", spawn_pos)

	if actual_count > 0:
		# Play spawn effect - pulse the glow
		_pulse_glow()


## Visual effect when spawning
func _pulse_glow() -> void:
	if not glow_light:
		return

	var original_energy := glow_light.light_energy
	glow_light.light_energy = 4.0

	var tween := create_tween()
	tween.tween_property(glow_light, "light_energy", original_energy, 0.5)


## Handle spawned enemy death
func _on_spawned_enemy_died(_killer: Node, enemy: Node) -> void:
	if enemy in spawned_enemies:
		spawned_enemies.erase(enemy)


## Damage handling
func take_damage(amount: int, damage_type: Enums.DamageType, attacker: Node) -> int:
	if is_destroyed:
		return 0

	# Holy damage is extra effective against cursed objects
	if damage_type == Enums.DamageType.HOLY:
		amount = int(amount * 1.5)

	# Apply armor
	if damage_type == Enums.DamageType.PHYSICAL:
		amount = int(amount * (100.0 / (100.0 + armor_value)))

	amount = max(1, amount)
	current_hp -= amount

	damaged.emit(amount, damage_type, attacker)

	_flash_damage()

	if current_hp <= 0:
		_on_destroyed(attacker)

	return amount


func get_armor_value() -> int:
	return armor_value


## Flash sprite when damaged
func _flash_damage() -> void:
	if not sprite:
		return

	sprite.modulate = Color(1.0, 0.3, 0.3)

	get_tree().create_timer(0.1).timeout.connect(func():
		if is_instance_valid(sprite):
			sprite.modulate = Color.WHITE
	)


## Called when hurtbox receives hit
func _on_hurtbox_hurt(damage: int, damage_type: Enums.DamageType, attacker: Node) -> void:
	pass  # Hurtbox already calls take_damage


## Destroyed
func _on_destroyed(destroyer: Node) -> void:
	is_destroyed = true

	if hurtbox:
		hurtbox.disable()

	destroyed.emit(destroyer)

	QuestManager.on_interact(spawner_id)
	QuestManager.update_progress("destroy", spawner_id, 1)

	print("[CursedTotem] Destroyed by ", str(destroyer.name) if destroyer else "unknown")

	_play_destruction_effect()


## Destruction effect
func _play_destruction_effect() -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.5)

	if glow_light:
		tween.tween_property(glow_light, "light_energy", 0.0, 0.3)

	if sprite:
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)

	tween.chain().tween_callback(queue_free)


## Static factory
static func spawn_totem(parent: Node, pos: Vector3, id: String = "") -> CursedTotem:
	var totem := CursedTotem.new()
	if id != "":
		totem.spawner_id = id
	totem.position = pos
	parent.add_child(totem)
	return totem
