## traveling_merchant.gd - Traveling merchant with cart that wanders the wilderness
## Special general merchant that can have items from various shop types
class_name TravelingMerchant
extends CharacterBody3D

signal merchant_interacted(merchant: TravelingMerchant)

## Dialogue
@export var dialogue_data: DialogueData

## Movement settings
@export var move_speed: float = 1.5
@export var wander_radius: float = 30.0
@export var pause_time_min: float = 3.0
@export var pause_time_max: float = 8.0

## Shop settings - chance to have items from each shop type
const SHOP_ITEM_CHANCES := {
	"general_store": 1.0,    # Always has general store items
	"blacksmith": 0.4,       # 40% chance for weapons/armor
	"magic_shop": 0.25,      # 25% chance for magic items
	"armorer": 0.3,          # 30% chance for armor
	"temple": 0.2,           # 20% chance for holy items
	"jeweler": 0.15,         # 15% chance for jewelry
}

## Visual components
var sprite: Sprite3D
var cart: Node3D
var cart_body: CSGBox3D
var wheels: Array[CSGCylinder3D] = []

## State
var origin_position: Vector3
var target_position: Vector3
var is_paused: bool = false
var pause_timer: float = 0.0
var current_direction: Vector3 = Vector3.ZERO

## Shop inventory (generated on spawn)
var available_shop_types: Array[String] = []
var merchant_name: String = "Traveling Merchant"

## RNG
var rng: RandomNumberGenerator


## NPC properties for central turn-in system
var npc_type: String = "traveling_merchant"
var region_id: String = ""  # Set by zone when spawned


func _ready() -> void:
	add_to_group("npcs")
	add_to_group("merchants")
	add_to_group("traveling_merchants")
	add_to_group("interactable")

	rng = RandomNumberGenerator.new()
	rng.randomize()

	origin_position = global_position

	_setup_visuals()
	_setup_collision()
	_setup_interaction()
	_generate_shop_inventory()
	_pick_new_target()
	_register_with_world_data()

	# Start with a pause
	is_paused = true
	pause_timer = rng.randf_range(1.0, 3.0)


func _physics_process(delta: float) -> void:
	if is_paused:
		pause_timer -= delta
		if pause_timer <= 0:
			is_paused = false
			_pick_new_target()
		return

	# Move toward target
	var to_target := target_position - global_position
	to_target.y = 0  # Stay on ground plane

	if to_target.length() < 1.0:
		# Reached target, pause
		is_paused = true
		pause_timer = rng.randf_range(pause_time_min, pause_time_max)
		return

	current_direction = to_target.normalized()
	velocity = current_direction * move_speed

	move_and_slide()

	# Update sprite facing
	_update_sprite_facing()

	# Update cart position (follows behind)
	_update_cart_position(delta)


func _setup_visuals() -> void:
	# Merchant sprite (billboard)
	sprite = Sprite3D.new()
	sprite.name = "MerchantSprite"

	# Try to load a merchant sprite, fallback to generic NPC
	var merchant_tex: Texture2D = load("res://Sprite folders grab bag/3x4humanbandit.png")
	if merchant_tex:
		sprite.texture = merchant_tex
		sprite.hframes = 4
		sprite.vframes = 1
		sprite.frame = 0  # Front facing

	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.pixel_size = 0.0384  # Standardized humanoid pixel size
	# Position sprite so feet are at ground level
	var sprite_height := 0.0
	if merchant_tex:
		sprite_height = merchant_tex.get_height() * sprite.pixel_size
	sprite.position = Vector3(0, sprite_height / 2.0, 0)  # Bottom at ground (was 1.0)
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	# Create cart
	_create_cart()


func _create_cart() -> void:
	cart = Node3D.new()
	cart.name = "Cart"
	cart.position = Vector3(0, 0, 1.5)  # Behind the merchant
	add_child(cart)

	# Load wood texture
	var wood_tex: Texture2D = load("res://Sprite folders grab bag/wood wall.png")

	# Cart body (wooden box)
	cart_body = CSGBox3D.new()
	cart_body.name = "CartBody"
	cart_body.size = Vector3(1.8, 1.2, 2.0)
	cart_body.position = Vector3(0, 0.9, 0)
	cart_body.use_collision = true

	var wood_mat := StandardMaterial3D.new()
	wood_mat.roughness = 0.85
	if wood_tex:
		wood_mat.albedo_texture = wood_tex
		wood_mat.uv1_scale = Vector3(0.5, 0.5, 1.0)
		wood_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	else:
		wood_mat.albedo_color = Color(0.5, 0.35, 0.2)
	cart_body.material = wood_mat
	cart.add_child(cart_body)

	# Cart top/cover (slightly larger, different color)
	var cart_cover := CSGBox3D.new()
	cart_cover.name = "CartCover"
	cart_cover.size = Vector3(2.0, 0.15, 2.2)
	cart_cover.position = Vector3(0, 1.55, 0)

	var cover_mat := StandardMaterial3D.new()
	cover_mat.albedo_color = Color(0.4, 0.3, 0.2)
	cart_cover.material = cover_mat
	cart.add_child(cart_cover)

	# Wheels (4 corners)
	var wheel_positions := [
		Vector3(-0.9, 0.35, -0.8),   # Back left
		Vector3(0.9, 0.35, -0.8),    # Back right
		Vector3(-0.9, 0.35, 0.8),    # Front left
		Vector3(0.9, 0.35, 0.8),     # Front right
	]

	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.35, 0.25, 0.15)

	for pos: Vector3 in wheel_positions:
		var wheel: CSGCylinder3D = CSGCylinder3D.new()
		wheel.name = "Wheel"
		wheel.radius = 0.35
		wheel.height = 0.15
		wheel.position = pos
		wheel.rotation_degrees = Vector3(0, 0, 90)  # Rotate to be horizontal
		wheel.material = wheel_mat
		cart.add_child(wheel)
		wheels.append(wheel)

	# Axles
	var axle_mat := StandardMaterial3D.new()
	axle_mat.albedo_color = Color(0.3, 0.25, 0.2)

	var front_axle := CSGCylinder3D.new()
	front_axle.name = "FrontAxle"
	front_axle.radius = 0.08
	front_axle.height = 2.0
	front_axle.position = Vector3(0, 0.35, 0.8)
	front_axle.rotation_degrees = Vector3(0, 0, 90)
	front_axle.material = axle_mat
	cart.add_child(front_axle)

	var back_axle := CSGCylinder3D.new()
	back_axle.name = "BackAxle"
	back_axle.radius = 0.08
	back_axle.height = 2.0
	back_axle.position = Vector3(0, 0.35, -0.8)
	back_axle.rotation_degrees = Vector3(0, 0, 90)
	back_axle.material = axle_mat
	cart.add_child(back_axle)

	# Handle/pulling bar
	var handle := CSGBox3D.new()
	handle.name = "Handle"
	handle.size = Vector3(0.1, 0.1, 1.5)
	handle.position = Vector3(0.4, 0.5, -1.7)
	handle.material = axle_mat
	cart.add_child(handle)

	var handle2 := CSGBox3D.new()
	handle2.name = "Handle2"
	handle2.size = Vector3(0.1, 0.1, 1.5)
	handle2.position = Vector3(-0.4, 0.5, -1.7)
	handle2.material = axle_mat
	cart.add_child(handle2)


func _setup_collision() -> void:
	# Merchant body collision
	var col := CollisionShape3D.new()
	col.name = "BodyCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	col.shape = capsule
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

	# Set collision layers (NPC layer)
	collision_layer = 4
	collision_mask = 1  # Collide with world


func _setup_interaction() -> void:
	var area := Area3D.new()
	area.name = "InteractArea"
	area.collision_layer = 256  # Layer 9 - interactable layer for player raycast
	area.collision_mask = 0
	area.add_to_group("interactable")  # Match other interactables
	area.set_meta("interaction_type", "shop")
	area.set_meta("shop_type", "traveling_merchant")
	area.set_meta("display_name", merchant_name)
	area.set_meta("merchant_ref", self)

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	col.shape = sphere
	col.position = Vector3(0, 1, 0)
	area.add_child(col)
	add_child(area)


## Called by player interaction system
func interact(_interactor: Node) -> void:
	# Emit signal for any listeners
	merchant_interacted.emit(self)

	# Check if dialogue data exists - start dialogue first
	if dialogue_data:
		# Pass merchant_id context for per-merchant flag substitution
		var context := {"merchant_id": merchant_name.to_snake_case()}
		DialogueManager.start_dialogue(dialogue_data, merchant_name, context)
		return

	# Try to open shop UI directly
	var shop_ui := get_tree().get_first_node_in_group("shop_ui")
	if shop_ui and shop_ui.has_method("open_traveling_merchant"):
		shop_ui.open_traveling_merchant(self)
	elif shop_ui and shop_ui.has_method("open"):
		# Fallback to general shop open with first available type
		if available_shop_types.size() > 0:
			shop_ui.open(available_shop_types[0])
	else:
		print("[TravelingMerchant] %s: Shop UI not found or no open method" % merchant_name)


## Get interaction prompt for HUD
func get_interaction_prompt() -> String:
	return "Trade with " + merchant_name


func _generate_shop_inventory() -> void:
	# Always have general store
	available_shop_types.append("general_store")

	# Roll for other shop types
	for shop_type: String in SHOP_ITEM_CHANCES:
		if shop_type == "general_store":
			continue
		var chance: float = SHOP_ITEM_CHANCES[shop_type]
		if rng.randf() < chance:
			available_shop_types.append(shop_type)

	# Generate a fun merchant name
	var first_names := ["Old", "Wandering", "Lucky", "Honest", "Shrewd", "Jolly", "Silent"]
	var last_names := ["Pete", "Martha", "Gideon", "Nessa", "Korbin", "Yara", "Thom"]
	merchant_name = first_names[rng.randi() % first_names.size()] + " " + last_names[rng.randi() % last_names.size()]

	print("[TravelingMerchant] %s spawned with shops: %s" % [merchant_name, available_shop_types])


func _pick_new_target() -> void:
	# Pick a random point within wander radius of origin
	var angle := rng.randf() * TAU
	var distance := rng.randf_range(5.0, wander_radius)

	target_position = origin_position + Vector3(
		cos(angle) * distance,
		0,
		sin(angle) * distance
	)


func _update_sprite_facing() -> void:
	# Flip sprite based on movement direction
	if current_direction.x > 0.1:
		sprite.flip_h = false
	elif current_direction.x < -0.1:
		sprite.flip_h = true


func _update_cart_position(delta: float) -> void:
	# Cart follows behind merchant with slight delay
	var target_cart_pos := -current_direction * 2.5  # 2.5 units behind
	target_cart_pos.y = 0

	cart.position = cart.position.lerp(target_cart_pos, delta * 3.0)

	# Rotate cart to face direction of travel
	if current_direction.length() > 0.1:
		var target_angle := atan2(current_direction.x, current_direction.z)
		cart.rotation.y = lerp_angle(cart.rotation.y, target_angle + PI, delta * 2.0)

	# Rotate wheels based on movement
	var wheel_rotation_speed := velocity.length() * 2.0
	for wheel: CSGCylinder3D in wheels:
		wheel.rotation.x += wheel_rotation_speed * delta


## Get available shop types for this merchant
func get_shop_types() -> Array[String]:
	return available_shop_types


## Check if merchant has a specific shop type
func has_shop_type(shop_type: String) -> bool:
	return shop_type in available_shop_types


## Get display name
func get_display_name() -> String:
	return merchant_name


## Get unique NPC ID for quest/conversation system
func get_npc_id() -> String:
	return merchant_name.to_snake_case() if merchant_name else "traveling_merchant_%d" % get_instance_id()


## Register this NPC with WorldData for quest navigation/tracking
func _register_with_world_data() -> void:
	var effective_id: String = get_npc_id()
	var hex: Vector2i = WorldData.world_to_axial(global_position)
	var zone_id: String = ""

	# Try to get zone_id from parent scene
	var parent: Node = get_parent()
	while parent:
		if "zone_id" in parent:
			zone_id = parent.zone_id
			break
		parent = parent.get_parent()

	# Use region_id if zone_id not found
	if zone_id.is_empty():
		zone_id = region_id if not region_id.is_empty() else "wilderness"

	WorldData.register_npc(effective_id, hex, zone_id, npc_type)


## Unregister from WorldData when removed from scene
func _exit_tree() -> void:
	WorldData.unregister_npc(get_npc_id())


## Static factory to spawn a traveling merchant
static func spawn_merchant(parent: Node3D, pos: Vector3) -> TravelingMerchant:
	var merchant := TravelingMerchant.new()
	merchant.position = pos
	parent.add_child(merchant)
	return merchant
