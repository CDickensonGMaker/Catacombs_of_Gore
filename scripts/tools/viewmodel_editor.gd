## viewmodel_editor.gd - Interactive viewmodel positioning tool for melee weapons
extends Node3D

## Weapon to preview
@export var weapon_data_path: String = "res://data/weapons/longsword.tres"

## UI References
@onready var camera: Camera3D = $Camera3D
@onready var weapon_holder: Node3D = $WeaponHolder
@onready var position_label: Label = $CanvasLayer/PositionPanel/PositionLabel
@onready var instructions_label: Label = $CanvasLayer/InstructionsPanel/InstructionsLabel
@onready var copy_feedback: Label = $CanvasLayer/CopyFeedback
@onready var crosshair: Control = $CanvasLayer/Crosshair
@onready var copy_button: Button = $CanvasLayer/CopyButton
@onready var weapon_selector: OptionButton = $CanvasLayer/WeaponSelector

## State
var weapon_data: WeaponData = null
var weapon_model: Node3D = null
var available_weapons: Array[WeaponData] = []

## Position editing
var edit_position: Vector3 = Vector3.ZERO
var edit_rotation: Vector3 = Vector3.ZERO
var edit_scale: Vector3 = Vector3.ONE

## Movement speeds
const MOVE_SPEED: float = 0.5
const ROTATE_SPEED: float = 45.0
const SCALE_SPEED: float = 0.5

## Copy feedback
var copy_feedback_timer: float = 0.0
var _copy_key_held: bool = false

func _ready() -> void:
	# Load all available weapons
	_load_available_weapons()

	# Setup weapon selector
	if weapon_selector:
		weapon_selector.clear()
		for i in range(available_weapons.size()):
			weapon_selector.add_item(available_weapons[i].display_name, i)
		weapon_selector.item_selected.connect(_on_weapon_selected)

	# Load initial weapon
	print("[ViewmodelEditor] Loading weapon data from: %s" % weapon_data_path)
	if ResourceLoader.exists(weapon_data_path):
		weapon_data = load(weapon_data_path)
		if weapon_data:
			print("[ViewmodelEditor] Weapon data loaded: %s" % weapon_data.display_name)
			print("[ViewmodelEditor] Mesh path: %s" % weapon_data.fps_mesh_path)
			# Select it in dropdown
			for i in range(available_weapons.size()):
				if available_weapons[i].id == weapon_data.id:
					weapon_selector.select(i)
					break
			_load_weapon()
		else:
			print("[ViewmodelEditor] ERROR: Failed to load weapon data")
	elif available_weapons.size() > 0:
		weapon_data = available_weapons[0]
		_load_weapon()

	# Set instructions
	if instructions_label:
		instructions_label.text = _get_instructions()

	# Connect copy button
	if copy_button:
		copy_button.pressed.connect(_on_copy_values)

	# Ensure mouse is visible and usable
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _load_available_weapons() -> void:
	available_weapons.clear()
	var dir := DirAccess.open("res://data/weapons")
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path: String = "res://data/weapons/" + file_name
				var weapon: WeaponData = load(path)
				if weapon and not weapon.fps_mesh_path.is_empty():
					available_weapons.append(weapon)
					print("[ViewmodelEditor] Found weapon: %s" % weapon.display_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	print("[ViewmodelEditor] Loaded %d weapons with FPS meshes" % available_weapons.size())


func _on_weapon_selected(index: int) -> void:
	if index >= 0 and index < available_weapons.size():
		weapon_data = available_weapons[index]
		print("[ViewmodelEditor] Selected: %s" % weapon_data.display_name)
		_load_weapon()


func _process(delta: float) -> void:
	_handle_input(delta)
	_update_position_display()
	_update_copy_feedback(delta)


func _handle_input(delta: float) -> void:
	if not weapon_model:
		return

	# Position adjustments (WASD + Q/E for up/down)
	var move_input := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move_input.z -= 1.0  # Forward (toward camera's -Z)
	if Input.is_key_pressed(KEY_S):
		move_input.z += 1.0  # Back
	if Input.is_key_pressed(KEY_A):
		move_input.x -= 1.0  # Left
	if Input.is_key_pressed(KEY_D):
		move_input.x += 1.0  # Right
	if Input.is_key_pressed(KEY_Q):
		move_input.y -= 1.0  # Down
	if Input.is_key_pressed(KEY_E):
		move_input.y += 1.0  # Up

	# Rotation adjustments (Arrow keys + Page Up/Down)
	var rot_input := Vector3.ZERO
	if Input.is_key_pressed(KEY_UP):
		rot_input.x -= 1.0  # Pitch up
	if Input.is_key_pressed(KEY_DOWN):
		rot_input.x += 1.0  # Pitch down
	if Input.is_key_pressed(KEY_LEFT):
		rot_input.y -= 1.0  # Yaw left
	if Input.is_key_pressed(KEY_RIGHT):
		rot_input.y += 1.0  # Yaw right
	if Input.is_key_pressed(KEY_PAGEUP):
		rot_input.z -= 1.0  # Roll
	if Input.is_key_pressed(KEY_PAGEDOWN):
		rot_input.z += 1.0  # Roll

	# Scale adjustments (+ / -)
	var scale_input: float = 0.0
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):  # +
		scale_input = 1.0
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):  # -
		scale_input = -1.0

	# Fine adjustment with Shift
	var speed_mult: float = 0.1 if Input.is_key_pressed(KEY_SHIFT) else 1.0

	# Apply movement
	edit_position += move_input * MOVE_SPEED * speed_mult * delta
	edit_rotation += rot_input * ROTATE_SPEED * speed_mult * delta
	edit_scale += Vector3.ONE * scale_input * SCALE_SPEED * speed_mult * delta
	edit_scale = edit_scale.clamp(Vector3(0.1, 0.1, 0.1), Vector3(10, 10, 10))

	# Update weapon transform
	weapon_model.position = edit_position
	weapon_model.rotation_degrees = edit_rotation
	weapon_model.scale = edit_scale

	# Reset position with R
	if Input.is_key_pressed(KEY_R) and not Input.is_key_pressed(KEY_CTRL):
		_reset_position()

	# Copy with C key
	if Input.is_key_pressed(KEY_C) and not Input.is_key_pressed(KEY_CTRL):
		if not _copy_key_held:
			_copy_key_held = true
			_on_copy_values()
	else:
		_copy_key_held = false

	# Reload with F5
	if Input.is_key_pressed(KEY_F5):
		_load_weapon()


func _load_weapon() -> void:
	# Remove old model
	if weapon_model:
		weapon_model.queue_free()
		weapon_model = null

	if not weapon_data or weapon_data.fps_mesh_path.is_empty():
		print("[ViewmodelEditor] No weapon mesh path set")
		return

	var mesh_path: String = weapon_data.fps_mesh_path
	print("[ViewmodelEditor] Attempting to load: %s" % mesh_path)
	print("[ViewmodelEditor] File exists: %s" % ResourceLoader.exists(mesh_path))

	# Load the model (GLB files are PackedScene, OBJ files are Mesh)
	var resource = load(mesh_path)
	if resource:
		print("[ViewmodelEditor] Resource type: %s" % resource.get_class())
		if resource is PackedScene:
			weapon_model = resource.instantiate()
			weapon_holder.add_child(weapon_model)
			_reset_position()
			print("[ViewmodelEditor] Loaded scene: %s" % mesh_path)
		elif resource is Mesh:
			# OBJ files load as Mesh - wrap in MeshInstance3D
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.mesh = resource
			weapon_model = mesh_instance
			weapon_holder.add_child(weapon_model)
			_reset_position()
			print("[ViewmodelEditor] Loaded mesh: %s" % mesh_path)
		else:
			print("[ViewmodelEditor] Resource is not a PackedScene or Mesh: %s" % resource.get_class())
	else:
		print("[ViewmodelEditor] Failed to load resource: %s" % mesh_path)


func _reset_position() -> void:
	if not weapon_data:
		return

	edit_position = weapon_data.fps_mesh_position
	edit_rotation = weapon_data.fps_mesh_rotation
	edit_scale = weapon_data.fps_mesh_scale

	if weapon_model:
		weapon_model.position = edit_position
		weapon_model.rotation_degrees = edit_rotation
		weapon_model.scale = edit_scale


func _update_position_display() -> void:
	if not position_label:
		return

	var pos_str: String = "Vector3(%.3f, %.3f, %.3f)" % [edit_position.x, edit_position.y, edit_position.z]
	var rot_str: String = "Vector3(%.1f, %.1f, %.1f)" % [edit_rotation.x, edit_rotation.y, edit_rotation.z]
	var scale_str: String = "Vector3(%.2f, %.2f, %.2f)" % [edit_scale.x, edit_scale.y, edit_scale.z]

	position_label.text = "VIEWMODEL EDITOR\n\nPosition:\n%s\n\nRotation:\n%s\n\nScale:\n%s" % [pos_str, rot_str, scale_str]


func _on_copy_values() -> void:
	var text := """fps_mesh_position = Vector3(%.3f, %.3f, %.3f)
fps_mesh_rotation = Vector3(%.1f, %.1f, %.1f)
fps_mesh_scale = Vector3(%.2f, %.2f, %.2f)""" % [
		edit_position.x, edit_position.y, edit_position.z,
		edit_rotation.x, edit_rotation.y, edit_rotation.z,
		edit_scale.x, edit_scale.y, edit_scale.z
	]

	DisplayServer.clipboard_set(text)
	print("[ViewmodelEditor] Copied to clipboard:\n%s" % text)

	# Show feedback
	copy_feedback_timer = 2.0
	if copy_feedback:
		copy_feedback.text = "COPIED!\n\n" + text
		copy_feedback.visible = true


func _update_copy_feedback(delta: float) -> void:
	if copy_feedback_timer > 0.0:
		copy_feedback_timer -= delta
		if copy_feedback_timer <= 0.0 and copy_feedback:
			copy_feedback.visible = false


func _get_instructions() -> String:
	return """VIEWMODEL EDITOR CONTROLS

POSITION:
  W/S - Forward/Back
  A/D - Left/Right
  Q/E - Down/Up

ROTATION:
  Arrow Keys - Pitch/Yaw
  PgUp/PgDn - Roll

SCALE:
  +/- Keys - Bigger/Smaller

OTHER:
  Shift - Fine adjustment
  R - Reset to saved values
  C - Copy values to clipboard
  F5 - Reload model

Paste copied values into your
weapon's .tres file."""
