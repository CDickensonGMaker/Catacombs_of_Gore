## viewmodel_editor_3rd_person.gd - Interactive third-person weapon positioning tool
extends Node3D

## Weapon to preview
@export var weapon_data_path: String = "res://data/weapons/longsword.tres"

## UI References
@onready var camera: Camera3D = $Camera3D
@onready var player_model: Node3D = $PlayerModel
@onready var weapon_attachment: Node3D = $PlayerModel/WeaponAttachment
@onready var position_label: Label = $CanvasLayer/PositionPanel/PositionLabel
@onready var instructions_label: Label = $CanvasLayer/InstructionsPanel/InstructionsLabel
@onready var copy_feedback: Label = $CanvasLayer/CopyFeedback
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

## Camera orbit
var camera_distance: float = 3.0
var camera_angle_h: float = 0.0  # Horizontal angle (yaw)
var camera_angle_v: float = 0.3  # Vertical angle (pitch)
var orbit_speed: float = 2.0

## Movement speeds
const MOVE_SPEED: float = 0.5
const ROTATE_SPEED: float = 45.0
const SCALE_SPEED: float = 0.5

## Copy feedback
var copy_feedback_timer: float = 0.0
var _copy_key_held: bool = false

## Mouse orbit
var _mouse_captured: bool = false

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
	if ResourceLoader.exists(weapon_data_path):
		weapon_data = load(weapon_data_path)
		if weapon_data:
			print("[TP ViewmodelEditor] Weapon data loaded: %s" % weapon_data.display_name)
			# Select it in dropdown
			for i in range(available_weapons.size()):
				if available_weapons[i].id == weapon_data.id:
					weapon_selector.select(i)
					break
			_load_weapon()
	elif available_weapons.size() > 0:
		weapon_data = available_weapons[0]
		_load_weapon()

	# Set instructions
	if instructions_label:
		instructions_label.text = _get_instructions()

	# Connect copy button
	if copy_button:
		copy_button.pressed.connect(_on_copy_values)

	# Update camera position
	_update_camera()


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
				if weapon:
					available_weapons.append(weapon)
					print("[TP ViewmodelEditor] Found weapon: %s" % weapon.display_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	print("[TP ViewmodelEditor] Loaded %d weapons" % available_weapons.size())


func _on_weapon_selected(index: int) -> void:
	if index >= 0 and index < available_weapons.size():
		weapon_data = available_weapons[index]
		print("[TP ViewmodelEditor] Selected: %s" % weapon_data.display_name)
		_load_weapon()


func _process(delta: float) -> void:
	_handle_input(delta)
	_update_position_display()
	_update_copy_feedback(delta)


func _input(event: InputEvent) -> void:
	# Right-click to orbit camera
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_captured = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseMotion and _mouse_captured:
		camera_angle_h -= event.relative.x * 0.005
		camera_angle_v -= event.relative.y * 0.005
		camera_angle_v = clampf(camera_angle_v, -1.2, 1.2)
		_update_camera()

	# Scroll to zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(1.0, camera_distance - 0.2)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(10.0, camera_distance + 0.2)
			_update_camera()


func _update_camera() -> void:
	if not camera:
		return
	# Orbit camera around player
	var x: float = sin(camera_angle_h) * cos(camera_angle_v) * camera_distance
	var y: float = sin(camera_angle_v) * camera_distance + 1.0  # Look at chest height
	var z: float = cos(camera_angle_h) * cos(camera_angle_v) * camera_distance
	camera.position = Vector3(x, y, z)
	camera.look_at(Vector3(0, 1.0, 0))


func _handle_input(delta: float) -> void:
	if not weapon_model:
		return

	# Position adjustments (WASD + Q/E for up/down)
	var move_input := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move_input.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		move_input.z += 1.0
	if Input.is_key_pressed(KEY_A):
		move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move_input.x += 1.0
	if Input.is_key_pressed(KEY_Q):
		move_input.y -= 1.0
	if Input.is_key_pressed(KEY_E):
		move_input.y += 1.0

	# Rotation adjustments (Arrow keys + Page Up/Down)
	var rot_input := Vector3.ZERO
	if Input.is_key_pressed(KEY_UP):
		rot_input.x -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		rot_input.x += 1.0
	if Input.is_key_pressed(KEY_LEFT):
		rot_input.y -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		rot_input.y += 1.0
	if Input.is_key_pressed(KEY_PAGEUP):
		rot_input.z -= 1.0
	if Input.is_key_pressed(KEY_PAGEDOWN):
		rot_input.z += 1.0

	# Scale adjustments (+ / -)
	var scale_input: float = 0.0
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
		scale_input = 1.0
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
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

	# Play attack animation with Space
	if Input.is_action_just_pressed("ui_accept"):
		_play_test_swing()


func _load_weapon() -> void:
	# Remove old model
	if weapon_model:
		weapon_model.queue_free()
		weapon_model = null

	if not weapon_data:
		print("[TP ViewmodelEditor] No weapon data")
		return

	var mesh_path: String = weapon_data.mesh_path
	if mesh_path.is_empty():
		# Try fps_mesh_path as fallback
		mesh_path = weapon_data.fps_mesh_path

	if mesh_path.is_empty():
		print("[TP ViewmodelEditor] No mesh path set")
		return

	print("[TP ViewmodelEditor] Loading: %s" % mesh_path)

	var resource = load(mesh_path)
	if resource is PackedScene:
		weapon_model = resource.instantiate()
		weapon_attachment.add_child(weapon_model)
		_reset_position()
		print("[TP ViewmodelEditor] Loaded weapon model (scene)")
	elif resource is Mesh:
		# OBJ files load as Mesh - wrap in MeshInstance3D
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = resource
		weapon_model = mesh_instance
		weapon_attachment.add_child(weapon_model)
		_reset_position()
		print("[TP ViewmodelEditor] Loaded weapon model (mesh)")
	else:
		print("[TP ViewmodelEditor] Failed to load: %s" % mesh_path)


func _reset_position() -> void:
	if not weapon_data:
		edit_position = Vector3(0, 0, 0)
		edit_rotation = Vector3(90, 0, 0)
		edit_scale = Vector3(1.2, 1.2, 1.2)
	else:
		# Match transforms from third_person_weapon.gd based on weapon type
		match weapon_data.weapon_type:
			Enums.WeaponType.MUSKET:
				# Musket (tuned in viewmodel editor)
				edit_rotation = Vector3(-1.9, 101.3, 1.3)
				edit_position = Vector3(-0.025, 0.510, -0.283)
				edit_scale = Vector3(1.50, 1.50, 1.50)
			Enums.WeaponType.BOW:
				# Bow (tuned in viewmodel editor)
				edit_rotation = Vector3(-18.8, -104.1, 13.4)
				edit_position = Vector3(-0.713, 0.240, -0.054)
				edit_scale = Vector3(1.50, 1.50, 1.50)
			Enums.WeaponType.CROSSBOW:
				# Crossbow (tuned in viewmodel editor)
				edit_rotation = Vector3(0.0, 188.4, -10.0)
				edit_position = Vector3(-0.046, 0.542, 0.081)
				edit_scale = Vector3(1.50, 1.50, 1.50)
			Enums.WeaponType.SWORD:
				# Swords - held at side
				edit_rotation = Vector3(8.4, -98.4, 0.0)
				edit_position = Vector3(-0.271, 0.375, -0.698)
				edit_scale = Vector3(1.2, 1.2, 1.2)
			Enums.WeaponType.DAGGER:
				# Daggers (tuned in viewmodel editor)
				edit_rotation = Vector3(8.4, -65.6, 0.0)
				edit_position = Vector3(-0.188, 0.292, -0.427)
				edit_scale = Vector3(1.20, 1.20, 1.20)
			Enums.WeaponType.AXE:
				# Axes (tuned in viewmodel editor)
				edit_rotation = Vector3(0.9, -95.6, 0.0)
				edit_position = Vector3(-0.489, 0.521, -0.583)
				edit_scale = Vector3(1.20, 1.20, 1.20)
			_:
				# Default
				edit_rotation = Vector3(0, 90, 0)
				edit_position = Vector3.ZERO
				edit_scale = Vector3(1.5, 1.5, 1.5)

	if weapon_model:
		weapon_model.position = edit_position
		weapon_model.rotation_degrees = edit_rotation
		weapon_model.scale = edit_scale


func _play_test_swing() -> void:
	if not weapon_model:
		return
	# Simple test swing animation
	var tween: Tween = create_tween()
	var start_rot: Vector3 = edit_rotation
	tween.tween_property(weapon_model, "rotation_degrees", start_rot + Vector3(-45, 0, 0), 0.1)
	tween.tween_property(weapon_model, "rotation_degrees", start_rot + Vector3(90, 0, 0), 0.2)
	tween.tween_property(weapon_model, "rotation_degrees", start_rot, 0.15)


func _update_position_display() -> void:
	if not position_label:
		return

	var pos_str: String = "Vector3(%.3f, %.3f, %.3f)" % [edit_position.x, edit_position.y, edit_position.z]
	var rot_str: String = "Vector3(%.1f, %.1f, %.1f)" % [edit_rotation.x, edit_rotation.y, edit_rotation.z]
	var scale_str: String = "Vector3(%.2f, %.2f, %.2f)" % [edit_scale.x, edit_scale.y, edit_scale.z]

	position_label.text = "3RD PERSON EDITOR\n\nPosition:\n%s\n\nRotation:\n%s\n\nScale:\n%s" % [pos_str, rot_str, scale_str]


func _on_copy_values() -> void:
	# Note: Add +180 to Y rotation when pasting into third_person_weapon.gd
	# because the editor faces the model but in-game the player faces away
	var adjusted_y: float = edit_rotation.y + 180.0
	var text := """# Third-person weapon transform (paste into third_person_weapon.gd)
# NOTE: Y rotation already has +180 added for in-game orientation
node.rotation_degrees = Vector3(%.1f, %.1f, %.1f)
node.position = Vector3(%.3f, %.3f, %.3f)
node.scale = Vector3(%.2f, %.2f, %.2f)""" % [
		edit_rotation.x, adjusted_y, edit_rotation.z,
		edit_position.x, edit_position.y, edit_position.z,
		edit_scale.x, edit_scale.y, edit_scale.z
	]

	DisplayServer.clipboard_set(text)
	print("[TP ViewmodelEditor] Copied to clipboard:\n%s" % text)

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
	return """3RD PERSON EDITOR

NOTE: Copy adds +180 to Y
rotation for in-game use.

POSITION:
  W/S - Forward/Back
  A/D - Left/Right
  Q/E - Down/Up

ROTATION:
  Arrow Keys - Pitch/Yaw
  PgUp/PgDn - Roll

SCALE:
  +/- Keys

CAMERA:
  Right-click drag - Orbit
  Scroll - Zoom

OTHER:
  Space - Test swing
  Shift - Fine adjust
  R - Reset
  C - Copy values
  F5 - Reload"""
