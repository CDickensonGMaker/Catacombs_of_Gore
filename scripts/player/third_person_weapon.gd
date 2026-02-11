## third_person_weapon.gd - Displays equipped weapon mesh in third person
## Attach to: Player/MeshRoot/WeaponAttachment (Node3D)
extends Node3D
class_name ThirdPersonWeapon

## Currently displayed weapon mesh instance
var weapon_mesh_instance: MeshInstance3D = null
var current_weapon_id: String = ""

## Material for weapons (simple shaded look)
var weapon_material: StandardMaterial3D


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

	# Create mesh instance
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

	# Default transform - weapon held at side, pointing forward
	# Adjust rotation so weapon barrel/blade points forward (-Z)

	match weapon.weapon_type:
		Enums.WeaponType.MUSKET, Enums.WeaponType.CROSSBOW, Enums.WeaponType.BOW:
			# Ranged weapons - held across body, barrel forward
			weapon_mesh_instance.rotation_degrees = Vector3(0, 90, -10)
			weapon_mesh_instance.position = Vector3(0.1, 0, -0.2)
			weapon_mesh_instance.scale = Vector3(1.5, 1.5, 1.5)
		Enums.WeaponType.SWORD, Enums.WeaponType.DAGGER:
			# Swords - blade pointing down when idle
			weapon_mesh_instance.rotation_degrees = Vector3(90, 0, 0)
			weapon_mesh_instance.position = Vector3(0, 0, 0)
			weapon_mesh_instance.scale = Vector3(1.2, 1.2, 1.2)
		_:
			# Default - weapon pointing forward
			weapon_mesh_instance.rotation_degrees = Vector3(0, 90, 0)
			weapon_mesh_instance.position = Vector3.ZERO
			weapon_mesh_instance.scale = Vector3(1.5, 1.5, 1.5)


func _clear_weapon() -> void:
	if weapon_mesh_instance:
		weapon_mesh_instance.queue_free()
		weapon_mesh_instance = null


## Show/hide the weapon (for first person mode switching)
func set_weapon_visible(is_visible: bool) -> void:
	if weapon_mesh_instance:
		weapon_mesh_instance.visible = is_visible
