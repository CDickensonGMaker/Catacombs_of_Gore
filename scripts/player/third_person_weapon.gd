## third_person_weapon.gd - Displays equipped weapon mesh in third person
## Attach to: Player/MeshRoot/WeaponAttachment (Node3D)
extends Node3D
class_name ThirdPersonWeapon

## Signal emitted when attack animation finishes
signal attack_finished

## Currently displayed weapon - can be MeshInstance3D or scene root Node3D
var weapon_mesh_instance: Node3D = null
var weapon_scene_root: Node3D = null  # The root node to animate and free
var current_weapon_id: String = ""

## Material for weapons (simple shaded look)
var weapon_material: StandardMaterial3D

## Animation state
enum AnimState { IDLE, ATTACKING }
var anim_state: AnimState = AnimState.IDLE
var anim_timer: float = 0.0
var attack_duration: float = 0.4  # Total swing time

## Store base transform for animation
var base_rotation: Vector3 = Vector3.ZERO
var base_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Create a simple material for weapons
	weapon_material = StandardMaterial3D.new()
	weapon_material.albedo_color = Color(0.5, 0.45, 0.4)  # Brownish metal
	weapon_material.metallic = 0.4
	weapon_material.roughness = 0.6

	# Connect to inventory changes
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	if InventoryManager.has_signal("equipment_changed"):
		InventoryManager.equipment_changed.connect(_on_equipment_changed)

	# Initial update
	update_weapon_display()


func _on_equipment_changed(slot: String, _old_item: Dictionary, _new_item: Dictionary) -> void:
	if slot == "main_hand":
		update_weapon_display()


## Update the displayed weapon based on equipped item
func update_weapon_display() -> void:
	var weapon: WeaponData = InventoryManager.get_equipped_weapon()

	# Clear existing weapon if different or no weapon equipped
	if weapon == null or (weapon and weapon.id != current_weapon_id):
		_clear_weapon()

	if weapon == null:
		current_weapon_id = ""
		return

	# Don't reload if same weapon
	if weapon.id == current_weapon_id and weapon_mesh_instance != null:
		return

	current_weapon_id = weapon.id

	# Try to load the weapon mesh
	if weapon.mesh_path.is_empty():
		print("[TPWeapon] No mesh_path for weapon: %s" % weapon.display_name)
		return

	var mesh_resource = load(weapon.mesh_path)
	if mesh_resource == null:
		print("[TPWeapon] Failed to load mesh: %s" % weapon.mesh_path)
		return

	# Handle different resource types
	if mesh_resource is PackedScene:
		# GLB/GLTF files load as PackedScene
		var scene_instance: Node3D = mesh_resource.instantiate()
		if scene_instance:
			scene_instance.name = "WeaponMesh"
			_apply_weapon_transform_node(weapon, scene_instance)
			add_child(scene_instance)
			# Store scene root for cleanup and animation
			weapon_scene_root = scene_instance
			weapon_mesh_instance = scene_instance  # Animate the root
			print("[TPWeapon] Displayed weapon (GLB): %s" % weapon.display_name)
		return

	# Create mesh instance for direct Mesh resources
	weapon_mesh_instance = MeshInstance3D.new()
	weapon_mesh_instance.name = "WeaponMesh"

	if mesh_resource is Mesh:
		weapon_mesh_instance.mesh = mesh_resource
	elif mesh_resource is ArrayMesh:
		weapon_mesh_instance.mesh = mesh_resource
	else:
		print("[TPWeapon] Unsupported mesh type: %s" % mesh_resource.get_class())
		weapon_mesh_instance.queue_free()
		weapon_mesh_instance = null
		return

	# Apply material
	weapon_mesh_instance.material_override = weapon_material

	# Adjust transform based on weapon type
	_apply_weapon_transform(weapon)

	add_child(weapon_mesh_instance)
	print("[TPWeapon] Displayed weapon: %s" % weapon.display_name)


func _apply_weapon_transform(weapon: WeaponData) -> void:
	if not weapon_mesh_instance:
		return
	_apply_weapon_transform_node(weapon, weapon_mesh_instance)


## Apply transform to any Node3D (for GLB scenes)
func _apply_weapon_transform_node(weapon: WeaponData, node: Node3D) -> void:
	if not node:
		return

	# Default transform - weapon held at side, pointing forward
	# Adjust rotation so weapon barrel/blade points forward (-Z)

	# NOTE: All Y rotations have +180 added because models face backward in editor
	# When using viewmodel editor, subtract 180 from Y to get the value to paste here
	match weapon.weapon_type:
		Enums.WeaponType.MUSKET:
			# Musket (tuned in viewmodel editor, +180 Y flip)
			node.rotation_degrees = Vector3(-1.9, 281.3, 1.3)
			node.position = Vector3(-0.025, 0.510, -0.283)
			node.scale = Vector3(1.50, 1.50, 1.50)
		Enums.WeaponType.BOW:
			# Bow (tuned in viewmodel editor, +180 Y flip)
			node.rotation_degrees = Vector3(-18.8, 75.9, 13.4)
			node.position = Vector3(-0.713, 0.240, -0.054)
			node.scale = Vector3(1.50, 1.50, 1.50)
		Enums.WeaponType.CROSSBOW:
			# Crossbow (tuned in viewmodel editor, +180 Y flip)
			node.rotation_degrees = Vector3(0.0, 368.4, -10.0)
			node.position = Vector3(-0.046, 0.542, 0.081)
			node.scale = Vector3(1.50, 1.50, 1.50)
		Enums.WeaponType.SWORD:
			# Swords (tuned in viewmodel editor, +180 Y flip)
			node.rotation_degrees = Vector3(8.4, 81.6, 0.0)
			node.position = Vector3(-0.271, 0.375, -0.698)
			node.scale = Vector3(1.2, 1.2, 1.2)
		Enums.WeaponType.DAGGER:
			# Daggers (tuned in viewmodel editor, +180 Y flip)
			node.rotation_degrees = Vector3(8.4, 114.4, 0.0)
			node.position = Vector3(-0.188, 0.292, -0.427)
			node.scale = Vector3(1.20, 1.20, 1.20)
		Enums.WeaponType.AXE:
			# Axes (tuned in viewmodel editor, +180 Y flip)
			node.rotation_degrees = Vector3(0.9, 84.4, 0.0)
			node.position = Vector3(-0.489, 0.521, -0.583)
			node.scale = Vector3(1.20, 1.20, 1.20)
		_:
			# Default (with +180 Y flip)
			node.rotation_degrees = Vector3(0, 270, 0)
			node.position = Vector3.ZERO
			node.scale = Vector3(1.5, 1.5, 1.5)


## Find the first MeshInstance3D in a scene tree
func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found: MeshInstance3D = _find_mesh_instance(child)
		if found:
			return found
	return null


func _clear_weapon() -> void:
	# Clear scene root first (for GLB scenes)
	if weapon_scene_root:
		weapon_scene_root.queue_free()
		weapon_scene_root = null
		weapon_mesh_instance = null
	elif weapon_mesh_instance:
		# Direct mesh instance (non-GLB)
		weapon_mesh_instance.queue_free()
		weapon_mesh_instance = null


## Show/hide the weapon (for first person mode switching)
func set_weapon_visible(is_visible: bool) -> void:
	if weapon_mesh_instance:
		weapon_mesh_instance.visible = is_visible


func _process(delta: float) -> void:
	if anim_state == AnimState.ATTACKING:
		_process_attack(delta)


## Play third-person attack swing animation
func play_attack_swing() -> void:
	if not weapon_mesh_instance:
		return

	# Store the idle pose
	base_rotation = weapon_mesh_instance.rotation_degrees
	base_position = weapon_mesh_instance.position

	anim_state = AnimState.ATTACKING
	anim_timer = 0.0


## Process attack swing animation
func _process_attack(delta: float) -> void:
	if not weapon_mesh_instance:
		_finish_attack()
		return

	anim_timer += delta
	var progress: float = anim_timer / attack_duration

	if progress >= 1.0:
		_finish_attack()
		return

	# Swing phases:
	# 0.0-0.2: Wind up (raise weapon back)
	# 0.2-0.6: Swing down/forward (main attack)
	# 0.6-1.0: Follow through and return to idle

	var swing_angle: float = 0.0
	var forward_offset: float = 0.0

	if progress < 0.2:
		# Wind up - pull weapon back
		var t: float = progress / 0.2
		swing_angle = -45.0 * t  # Rotate back
		forward_offset = 0.1 * t  # Pull back slightly
	elif progress < 0.6:
		# Main swing - fast forward rotation
		var t: float = (progress - 0.2) / 0.4
		var eased: float = 1.0 - pow(1.0 - t, 3)  # Ease out for impact
		swing_angle = -45.0 + 135.0 * eased  # Swing from -45 to +90
		forward_offset = 0.1 - 0.3 * eased  # Thrust forward
	else:
		# Return to idle
		var t: float = (progress - 0.6) / 0.4
		var eased: float = t * t  # Ease in
		swing_angle = 90.0 * (1.0 - eased)  # Return from +90 to 0
		forward_offset = -0.2 * (1.0 - eased)

	# Apply animation - rotate around X axis for vertical swing
	weapon_mesh_instance.rotation_degrees = base_rotation + Vector3(swing_angle, 0, 0)
	weapon_mesh_instance.position = base_position + Vector3(0, 0, forward_offset)


func _finish_attack() -> void:
	anim_state = AnimState.IDLE
	anim_timer = 0.0

	# Reset to base pose
	if weapon_mesh_instance:
		weapon_mesh_instance.rotation_degrees = base_rotation
		weapon_mesh_instance.position = base_position

	attack_finished.emit()
