## enemy_spawner.gd - Destructible spawner that creates enemies periodically
class_name EnemySpawner
extends StaticBody3D

const DEBUG := false  ## Enable debug prints

signal damaged(amount: int, damage_type: Enums.DamageType, attacker: Node)
signal destroyed(destroyer: Node)

## Configuration
@export var spawner_id: String = "goblin_totem"
@export var display_name: String = "Goblin Totem"
@export var max_hp: int = 1000
@export var armor_value: int = 10

## Spawning configuration
@export var spawn_interval_min: float = 20.0  ## Minimum seconds between spawns
@export var spawn_interval_max: float = 30.0  ## Maximum seconds between spawns
@export var max_spawned_enemies: int = 20  ## Max enemies alive from this spawner (increased for demo)
@export var spawn_radius: float = 3.0     ## Radius around spawner to spawn enemies
@export var spawn_count_min: int = 3  ## Minimum enemies to spawn at once (increased for demo)
@export var spawn_count_max: int = 5  ## Maximum enemies to spawn at once (increased for demo)
@export var enemy_scene: PackedScene      ## The enemy scene to spawn
@export var enemy_data_path: String = "res://data/enemies/goblin_soldier.tres"

## Secondary billboard enemy (e.g., goblin archer)
@export var secondary_enemy_enabled: bool = true
@export var secondary_enemy_chance: float = 0.30  ## 30% chance to spawn secondary (archer)
@export var secondary_data_path: String = "res://data/enemies/goblin_archer.tres"

## Tertiary billboard enemy (e.g., goblin mage) - rarer spellcaster
@export var tertiary_enemy_enabled: bool = true
@export var tertiary_enemy_chance: float = 0.15  ## 15% chance to spawn tertiary (mage)
@export var tertiary_data_path: String = "res://data/enemies/goblin_mage.tres"

## Visual configuration
@export var mesh_height: float = 2.0
@export var mesh_radius: float = 0.5

## Spawned enemy behavior configuration
@export var spawned_wander_radius: float = 8.0   ## How far spawned enemies wander from totem
@export var spawned_leash_radius: float = 15.0   ## Max distance before spawned enemies return
@export var spawned_patrol_radius: float = 15.0  ## Patrol point generation radius
@export var enable_patrols: bool = true          ## Whether spawned enemies should patrol

## Runtime state
var current_hp: int
var is_destroyed: bool = false
var spawn_timer: float = 0.0
var current_spawn_interval: float = 25.0  ## Current randomized interval target
var spawned_enemies: Array[Node] = []

## Warboss spawn state
var warboss_spawned: bool = false
var warboss_hp_threshold: float = 0.25  ## Spawn warboss when totem below 25% HP
var warboss: EnemyBase = null

## Components (created at runtime)
var mesh_instance: MeshInstance3D
var hurtbox: Hurtbox
var collision_shape: CollisionShape3D
var health_bar: Node  ## EnemyHealthBar3D

func _ready() -> void:
	add_to_group("spawners")
	add_to_group("destructibles")
	add_to_group("enemies")  # Required for projectiles to recognize as valid target

	current_hp = max_hp

	if DEBUG:
		print("[EnemySpawner] _ready() called for ", display_name)
		print("[EnemySpawner] max_hp=", max_hp, " spawn_interval=", spawn_interval_min, "-", spawn_interval_max, "s max_spawned=", max_spawned_enemies)

	# Create visual mesh
	_create_mesh()

	# Create collision for physics body
	_create_collision()

	# Create hurtbox for receiving damage
	_create_hurtbox()

	# Create health bar
	_create_health_bar()

	# Note: We now use billboard sprites loaded from enemy_data.sprite_path
	# The enemy_scene variable is kept for backwards compatibility but not used

	# Initial spawn delay (don't spawn immediately, use half of a random interval)
	current_spawn_interval = _get_random_spawn_interval() * 0.5
	spawn_timer = 0.0
	if DEBUG:
		print("[EnemySpawner] Initial spawn in ", snapped(current_spawn_interval, 0.1), " seconds")

var _debug_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if is_destroyed:
		return

	# Clean up dead enemies from tracking list
	_cleanup_dead_enemies()

	# Spawn timer
	spawn_timer += delta

	# Debug output every 10 seconds
	if DEBUG:
		_debug_timer += delta
		if _debug_timer >= 10.0:
			_debug_timer = 0.0
			print("[EnemySpawner] Status: spawn_timer=", snapped(spawn_timer, 0.1), "/", snapped(current_spawn_interval, 0.1), " spawned_enemies=", spawned_enemies.size(), "/", max_spawned_enemies, " HP=", current_hp, "/", max_hp)

	if spawn_timer >= current_spawn_interval:
		spawn_timer = 0.0
		current_spawn_interval = _get_random_spawn_interval()  # Randomize next interval
		_try_spawn_enemy()

## Create the visual mesh (totem pillar)
func _create_mesh() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "TotemMesh"

	# Create a cylinder mesh for the totem
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = mesh_radius * 0.8
	cylinder.bottom_radius = mesh_radius
	cylinder.height = mesh_height
	mesh_instance.mesh = cylinder
	mesh_instance.position.y = mesh_height / 2.0

	# Dark stone material with greenish tint (goblin aesthetic)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.3, 0.2)  # Dark greenish stone
	mat.roughness = 0.9
	mesh_instance.material_override = mat

	add_child(mesh_instance)

	# Add a skull decoration on top
	var skull := MeshInstance3D.new()
	skull.name = "SkullDecor"
	var sphere := SphereMesh.new()
	sphere.radius = mesh_radius * 0.4
	skull.mesh = sphere
	skull.position.y = mesh_height + mesh_radius * 0.3

	var skull_mat := StandardMaterial3D.new()
	skull_mat.albedo_color = Color(0.8, 0.75, 0.65)  # Bone color
	skull.material_override = skull_mat

	add_child(skull)

## Create collision shape for physics body
func _create_collision() -> void:
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "Collision"

	var shape := CylinderShape3D.new()
	shape.radius = mesh_radius
	shape.height = mesh_height
	collision_shape.shape = shape
	collision_shape.position.y = mesh_height / 2.0

	add_child(collision_shape)

## Create hurtbox for receiving damage
func _create_hurtbox() -> void:
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"

	# Collision layer 128 = enemy_hurtbox (layer 8) - matches projectile collision mask
	# Collision mask 8 = player_hitbox (layer 4) - detects player melee attacks
	# Collision mask 512 = projectile layer (layer 10) - detects spell/ranged projectiles
	hurtbox.collision_layer = 128
	hurtbox.collision_mask = 8 + 512
	hurtbox.monitoring = true
	hurtbox.monitorable = true

	var shape := CollisionShape3D.new()
	shape.name = "HurtboxShape"
	var capsule := CapsuleShape3D.new()
	capsule.radius = mesh_radius + 0.1
	capsule.height = mesh_height
	shape.shape = capsule
	shape.position.y = mesh_height / 2.0
	hurtbox.add_child(shape)

	add_child(hurtbox)

	# Set owner and connect signals
	hurtbox.set_owner_entity(self)
	hurtbox.add_to_group("enemy_hurtbox")
	hurtbox.add_to_group("hurtbox")
	hurtbox.hurt.connect(_on_hurtbox_hurt)

## Create health bar above spawner
func _create_health_bar() -> void:
	var health_bar_scene := load("res://scenes/ui/enemy_health_bar_3d.tscn")
	if health_bar_scene:
		health_bar = health_bar_scene.instantiate()
		health_bar.position.y = mesh_height + 1.0
		add_child(health_bar)

		# Initialize health bar if it has the method
		if health_bar.has_method("set_target"):
			health_bar.set_target(self)

## Clean up references to dead enemies
func _cleanup_dead_enemies() -> void:
	var to_remove: Array[Node] = []
	for enemy in spawned_enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			to_remove.append(enemy)
		elif enemy.has_method("is_dead") and enemy.is_dead():
			to_remove.append(enemy)

	for enemy in to_remove:
		spawned_enemies.erase(enemy)

## Get a randomized spawn interval between min and max
func _get_random_spawn_interval() -> float:
	return randf_range(spawn_interval_min, spawn_interval_max)

## Try to spawn enemies if under the limit
func _try_spawn_enemy() -> void:
	if spawned_enemies.size() >= max_spawned_enemies:
		if DEBUG:
			print("[EnemySpawner] At max capacity (", spawned_enemies.size(), "/", max_spawned_enemies, "), skipping spawn")
		return

	# Determine how many enemies to spawn this wave
	var desired_count := randi_range(spawn_count_min, spawn_count_max)
	var available_slots := max_spawned_enemies - spawned_enemies.size()
	var actual_count := mini(desired_count, available_slots)

	if DEBUG:
		print("[EnemySpawner] Spawning ", actual_count, " enemies (wanted ", desired_count, ", ", available_slots, " slots available)")

	# Pre-load enemy data resources for all types
	var primary_data: EnemyData = load(enemy_data_path) as EnemyData
	if not primary_data:
		push_error("[EnemySpawner] Failed to load primary enemy data: %s" % enemy_data_path)
		return

	var secondary_data: EnemyData = null
	var tertiary_data: EnemyData = null

	if secondary_enemy_enabled:
		secondary_data = load(secondary_data_path) as EnemyData
	if tertiary_enemy_enabled:
		tertiary_data = load(tertiary_data_path) as EnemyData

	var parent: Node = get_tree().current_scene
	if not parent:
		push_error("[EnemySpawner] No current scene available for spawning")
		return

	# Spawn each enemy at a different random position
	for i in actual_count:
		# Calculate spawn position (random point around spawner)
		var angle := randf() * TAU
		var distance := randf_range(1.5, spawn_radius)
		var spawn_offset := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var spawn_pos := global_position + spawn_offset

		# Decide enemy type based on random rolls (tertiary first since it's rarer)
		var roll := randf()
		var selected_data: EnemyData
		var selected_path: String
		var enemy_type: String

		if tertiary_enemy_enabled and tertiary_data and roll < tertiary_enemy_chance:
			selected_data = tertiary_data
			selected_path = tertiary_data_path
			enemy_type = "MAGE"
		elif secondary_enemy_enabled and secondary_data and roll < (tertiary_enemy_chance + secondary_enemy_chance):
			selected_data = secondary_data
			selected_path = secondary_data_path
			enemy_type = "ARCHER"
		else:
			selected_data = primary_data
			selected_path = enemy_data_path
			enemy_type = "SOLDIER"

		# Spawn billboard enemy using sprite from enemy_data
		var enemy: EnemyBase = _spawn_billboard_from_data(parent, spawn_pos, selected_path, selected_data)

		if not enemy:
			push_warning("[EnemySpawner] Failed to spawn %s at %s" % [enemy_type, spawn_pos])
			continue

		if DEBUG:
			print("[EnemySpawner] Spawned %s at %s" % [enemy_type, spawn_pos])

		# Configure spawned enemy behavior
		if "wander_radius" in enemy:
			enemy.wander_radius = spawned_wander_radius
		if "leash_radius" in enemy:
			enemy.leash_radius = spawned_leash_radius
		if "spawn_position" in enemy:
			enemy.spawn_position = global_position  # Anchor to the totem, not spawn point

		# Enable patrol mode for wider area coverage
		if enable_patrols:
			if "patrol_radius" in enemy:
				enemy.patrol_radius = spawned_patrol_radius
			if "patrol_point_count" in enemy:
				enemy.patrol_point_count = 4  # 4 patrol waypoints
			if "auto_generate_patrol_points" in enemy:
				enemy.auto_generate_patrol_points = true
			# Set behavior mode to use weighted selection (includes patrol)
			if "behavior_mode" in enemy:
				enemy.behavior_mode = 0  # BehaviorMode.WEIGHTED
			if "patrol_weight" in enemy:
				enemy.patrol_weight = 3.0  # Higher chance to patrol

		# Track the spawned enemy
		spawned_enemies.append(enemy)

		# Connect to death signal if available
		if enemy.has_signal("died"):
			enemy.died.connect(_on_spawned_enemy_died.bind(enemy))

	print("[EnemySpawner] Spawned ", actual_count, " enemies (", spawned_enemies.size(), "/", max_spawned_enemies, " total)")


## Spawn a billboard enemy using sprite info from EnemyData
func _spawn_billboard_from_data(parent: Node, pos: Vector3, data_path: String, data: EnemyData) -> EnemyBase:
	if not data:
		push_error("[EnemySpawner] Cannot spawn enemy - no data provided")
		return null

	# Get sprite info from enemy_data
	var sprite_path: String = data.sprite_path
	if sprite_path.is_empty():
		push_warning("[EnemySpawner] Enemy data '%s' has no sprite_path, cannot spawn billboard" % data.id)
		return null

	var sprite_texture: Texture2D = load(sprite_path)
	if not sprite_texture:
		push_warning("[EnemySpawner] Failed to load sprite: %s" % sprite_path)
		return null

	var h_frames: int = data.sprite_hframes if data.sprite_hframes > 0 else 4
	var v_frames: int = data.sprite_vframes if data.sprite_vframes > 0 else 4

	var enemy := EnemyBase.spawn_billboard_enemy(
		parent,
		pos,
		data_path,
		sprite_texture,
		h_frames,
		v_frames
	)

	if enemy:
		# Apply undead/monster glow if applicable
		enemy.call_deferred("_check_and_apply_undead_glow", data_path)

	return enemy

## Called when a spawned enemy dies
func _on_spawned_enemy_died(_killer: Node, enemy: Node) -> void:
	if enemy in spawned_enemies:
		spawned_enemies.erase(enemy)


## Spawn the Goblin Warboss when totem is critically damaged
func _spawn_warboss(attacker: Node) -> void:
	warboss_spawned = true

	var sprite_texture: Texture2D = load("res://assets/sprites/enemies/goblin_warboss.png")
	if not sprite_texture:
		push_warning("[EnemySpawner] Failed to load goblin_warboss sprite")
		return

	# Spawn position in front of totem
	var spawn_pos := global_position + Vector3(0, 0, 3)

	warboss = EnemyBase.spawn_billboard_enemy(
		get_tree().current_scene,
		spawn_pos,
		"res://data/enemies/goblin_warboss.tres",
		sprite_texture,
		4,  # h_frames
		5   # v_frames (5 rows for this sprite sheet)
	)

	if warboss:
		# Configure warboss to defend the totem (no leash)
		warboss.defending_totem = true
		warboss.totem_position = global_position

		# Add health bar above the warboss (bosses should have visible HP)
		var health_bar_scene: PackedScene = load("res://scenes/ui/enemy_health_bar_3d.tscn")
		if health_bar_scene:
			var boss_hp_bar: EnemyHealthBar3D = health_bar_scene.instantiate()
			boss_hp_bar.position.y = 3.0  # Above the warboss sprite
			boss_hp_bar.bar_width = 1.5  # Wider bar for boss
			warboss.add_child(boss_hp_bar)
			boss_hp_bar.set_target(warboss)
			boss_hp_bar.show_bar(999.0)  # Show for a very long time

		# Alert warboss to the attacker
		if attacker and attacker is Node3D:
			warboss.call_deferred("alert_to_target", attacker, global_position)

		# Start the attack speed buff aura
		_start_warboss_buff_aura()

		spawned_enemies.append(warboss)
		print("[EnemySpawner] WARBOSS SPAWNED! The Goblin Warchief has arrived to defend the totem!")


## Buff nearby goblins with attack speed boost
func _start_warboss_buff_aura() -> void:
	# Create a timer that periodically applies the buff
	var buff_timer := Timer.new()
	buff_timer.name = "WarbossBuffTimer"
	buff_timer.wait_time = 2.0
	buff_timer.autostart = true
	buff_timer.timeout.connect(_apply_warboss_buff)
	add_child(buff_timer)


## Apply attack speed buff to nearby goblin allies
func _apply_warboss_buff() -> void:
	if not is_instance_valid(warboss) or warboss.is_dead():
		# Warboss is dead, stop buffing
		var timer := get_node_or_null("WarbossBuffTimer")
		if timer:
			timer.queue_free()
		return

	# Buff all nearby goblin faction enemies
	var buff_radius := 15.0
	for enemy in spawned_enemies:
		if not is_instance_valid(enemy) or enemy == warboss:
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue

		var dist := warboss.global_position.distance_to(enemy.global_position)
		if dist <= buff_radius:
			# Apply attack speed buff (reduce attack cooldown)
			if "attack_cooldown" in enemy:
				enemy.attack_cooldown = max(0, enemy.attack_cooldown - 0.5)
			# Visual indicator - brief red flash
			if enemy.has_method("_flash_damage"):
				# Use a different color for buff (green tint would be better but this works)
				pass

## Alert all spawned enemies that the totem is under attack
func _alert_spawned_enemies(attacker: Node) -> void:
	if not attacker or not attacker is Node3D:
		return

	var alerted_count := 0
	for enemy in spawned_enemies:
		if is_instance_valid(enemy) and enemy.has_method("alert_to_target"):
			enemy.alert_to_target(attacker, global_position)
			alerted_count += 1

	if DEBUG and alerted_count > 0:
		print("[EnemySpawner] Alerted ", alerted_count, " goblins to defend totem against ", attacker.name)

## Damage handling
func take_damage(amount: int, damage_type: Enums.DamageType, attacker: Node) -> int:
	if is_destroyed:
		return 0

	# Apply armor reduction for physical damage
	if damage_type == Enums.DamageType.PHYSICAL:
		amount = int(amount * (100.0 / (100.0 + armor_value)))

	amount = max(1, amount)
	current_hp -= amount

	damaged.emit(amount, damage_type, attacker)

	# Alert all spawned enemies to defend the totem
	if attacker:
		_alert_spawned_enemies(attacker)

	# Flash the mesh red briefly
	_flash_damage()

	# Check if we should spawn the Warboss (low HP threshold)
	if not warboss_spawned and float(current_hp) / max_hp <= warboss_hp_threshold:
		_spawn_warboss(attacker)

	# Check destruction
	if current_hp <= 0:
		_on_destroyed(attacker)

	return amount

## Get armor value (for compatibility with combat systems)
func get_armor_value() -> int:
	return armor_value

## Flash mesh red when damaged
func _flash_damage() -> void:
	if not mesh_instance:
		return

	var original_mat := mesh_instance.material_override
	if not original_mat:
		return

	# Create flash material
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.2, 0.2)
	mesh_instance.material_override = flash_mat

	# Reset after brief delay
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_instance_valid(mesh_instance):
			mesh_instance.material_override = original_mat
	)

## Called when the hurtbox receives a hit
func _on_hurtbox_hurt(damage: int, damage_type: Enums.DamageType, attacker: Node) -> void:
	# Hurtbox already calls take_damage on owner, but we connect this for any additional effects
	pass

## Called when spawner is destroyed
func _on_destroyed(destroyer: Node) -> void:
	is_destroyed = true

	# Disable hurtbox
	if hurtbox:
		hurtbox.disable()

	# Emit signal
	destroyed.emit(destroyer)

	# Notify QuestManager
	QuestManager.on_interact(spawner_id)
	# Also use a "destroy" type for quest objectives
	QuestManager.update_progress("destroy", spawner_id, 1)

	print("[EnemySpawner] ", display_name, " destroyed by ", str(destroyer.name) if destroyer else "unknown")

	# Drop quest item (Corrupted Totem Shard)
	_drop_quest_item()

	# Play destruction effect (simple scale down + fade)
	_play_destruction_effect()

## Drop a quest item when destroyed
func _drop_quest_item() -> void:
	var drop_item_id := "corrupted_totem_shard"

	# Check if item exists in database
	if not InventoryManager.item_database.has(drop_item_id):
		push_warning("[EnemySpawner] Quest item not found in database: " + drop_item_id)
		return

	# Spawn the item slightly above ground at totem position
	var drop_pos := global_position + Vector3(0, 0.5, 0)
	WorldItem.spawn_item(get_tree().current_scene, drop_pos, drop_item_id, Enums.ItemQuality.AVERAGE, 1)

	print("[EnemySpawner] Dropped quest item: " + drop_item_id)

## Play destruction visual effect
func _play_destruction_effect() -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	# Scale down
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.5)

	# Fade mesh if possible
	if mesh_instance and mesh_instance.material_override:
		var mat := mesh_instance.material_override as StandardMaterial3D
		if mat:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)

	# Queue free after effect
	tween.chain().tween_callback(queue_free)

## Static factory method
static func spawn_spawner(parent: Node, pos: Vector3, id: String = "goblin_totem") -> EnemySpawner:
	var spawner := EnemySpawner.new()
	spawner.spawner_id = id
	spawner.position = pos
	parent.add_child(spawner)
	return spawner
