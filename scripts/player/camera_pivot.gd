# File: scripts/player/camera_pivot.gd
# Attach to: Player/CameraPivot (Node3D)
# Handles camera rotation, mouse free-look, and first/third person switching
extends Node3D

# --- Camera Mode ---
enum CameraMode { THIRD_PERSON, FIRST_PERSON }
var current_mode: CameraMode = CameraMode.THIRD_PERSON

# --- Node References (set in scene) ---
@export var spring_arm: NodePath
@export var camera: NodePath
@export var player: NodePath
@export var player_mesh: NodePath

# --- Camera Settings ---
@export var mouse_sensitivity: float = 0.003
@export var stick_sensitivity: float = 2.2
@export var invert_y: bool = false
@export var min_pitch_degrees: float = -60.0
@export var max_pitch_degrees: float = 35.0
@export var stick_deadzone: float = 0.15

# --- Third Person Settings ---
@export var third_person_distance: float = 4.0
@export var third_person_fov: float = 70.0
@export var shoulder_offset: Vector3 = Vector3(0.8, 0.0, 0.0)  # Right shoulder offset for third person

# --- First Person Settings ---
@export var first_person_height_offset: float = 0.2  # Offset from pivot (which is at 1.5)
@export var first_person_fov: float = 80.0

# --- Internal State ---
var yaw: float = 0.0   # radians
var pitch: float = 0.0 # radians

# --- Cached Node References ---
var _spring_arm: SpringArm3D
var _camera: Camera3D
var _player_mesh_node: Node3D

# --- First Person Arms ---
var _fps_arms: FirstPersonArms

# --- Third Person Weapon ---
var _tp_weapon: ThirdPersonWeapon

func _ready() -> void:
	# Cache node references
	if spring_arm:
		_spring_arm = get_node(spring_arm)
	if camera:
		_camera = get_node(camera)
	if player_mesh:
		_player_mesh_node = get_node(player_mesh)

	# Cache third-person weapon reference
	if _player_mesh_node:
		_tp_weapon = _player_mesh_node.get_node_or_null("WeaponAttachment") as ThirdPersonWeapon

	# Create first-person arms system
	_setup_fps_arms()

	# Capture mouse for gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Initialize to third person
	_apply_camera_mode()


func _setup_fps_arms() -> void:
	# Create the FPS arms as a child of the camera (so it moves with view)
	_fps_arms = FirstPersonArms.new()
	_fps_arms.name = "FirstPersonArms"

	# Add to camera so it follows the view
	if _camera:
		_camera.add_child(_fps_arms)
	else:
		add_child(_fps_arms)

	# Start hidden (third person default)
	_fps_arms.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Toggle mouse capture with Esc (ui_cancel)
	if event.is_action_pressed("ui_cancel"):
		var mode := Input.get_mouse_mode()
		if mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	# Toggle camera mode with V key
	if event.is_action_pressed("toggle_camera_mode"):
		_toggle_camera_mode()
		return

	# Mouse free-look (only when mouse is captured)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_apply_look(mm.relative.x, mm.relative.y, mouse_sensitivity)

func _process(delta: float) -> void:
	# Right stick look (controller)
	var rx: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)

	# Apply deadzone
	if abs(rx) < stick_deadzone:
		rx = 0.0
	if abs(ry) < stick_deadzone:
		ry = 0.0

	if rx != 0.0 or ry != 0.0:
		# Multiply by delta so stick is "per second"
		_apply_look(rx * delta, ry * delta, stick_sensitivity)

func _apply_look(dx: float, dy: float, sensitivity: float) -> void:
	# dx/dy are "units" (mouse pixels or stick axis). sensitivity scales them into radians.
	yaw -= dx * sensitivity

	var pitch_delta: float = dy * sensitivity
	if invert_y:
		pitch += pitch_delta
	else:
		pitch -= pitch_delta

	_clamp_and_apply()

func _clamp_and_apply() -> void:
	var min_pitch: float = deg_to_rad(min_pitch_degrees)
	var max_pitch: float = deg_to_rad(max_pitch_degrees)
	pitch = clamp(pitch, min_pitch, max_pitch)

	# Apply to pivot: X = pitch, Y = yaw
	rotation = Vector3(pitch, yaw, 0.0)

func _toggle_camera_mode() -> void:
	if current_mode == CameraMode.THIRD_PERSON:
		current_mode = CameraMode.FIRST_PERSON
	else:
		current_mode = CameraMode.THIRD_PERSON

	_apply_camera_mode()

func _apply_camera_mode() -> void:
	match current_mode:
		CameraMode.FIRST_PERSON:
			_set_first_person()
		CameraMode.THIRD_PERSON:
			_set_third_person()

func _set_first_person() -> void:
	# Move camera to head position (no spring arm distance)
	if _spring_arm:
		_spring_arm.spring_length = 0.0
		# Reset spring arm rotation so camera looks straight from pivot
		_spring_arm.rotation = Vector3.ZERO
		_spring_arm.position = Vector3.ZERO

	# Adjust camera position for first person
	if _camera:
		_camera.position = Vector3(0.0, first_person_height_offset, 0.0)
		_camera.fov = first_person_fov

	# Hide player mesh so we don't see inside our own body
	if _player_mesh_node:
		_player_mesh_node.visible = false

	# Hide third-person weapon
	if _tp_weapon:
		_tp_weapon.set_weapon_visible(false)

	# Show first-person arms
	if _fps_arms:
		_fps_arms.show_arms()

func _set_third_person() -> void:
	# Set spring arm to orbit distance
	if _spring_arm:
		_spring_arm.spring_length = third_person_distance
		# Slight downward angle for better third person view
		_spring_arm.rotation = Vector3(deg_to_rad(20.0), 0.0, 0.0)
		_spring_arm.position = shoulder_offset

	# Reset camera to end of spring arm
	if _camera:
		_camera.position = Vector3.ZERO
		_camera.fov = third_person_fov

	# Show player mesh
	if _player_mesh_node:
		_player_mesh_node.visible = true

	# Show third-person weapon
	if _tp_weapon:
		_tp_weapon.set_weapon_visible(true)
		_tp_weapon.update_weapon_display()

	# Hide first-person arms
	if _fps_arms:
		_fps_arms.hide_arms()

# --- Public API ---

func get_camera_mode() -> CameraMode:
	return current_mode

func is_first_person() -> bool:
	return current_mode == CameraMode.FIRST_PERSON

func is_third_person() -> bool:
	return current_mode == CameraMode.THIRD_PERSON

## Trigger attack animation on first-person arms or third-person weapon
func play_attack_animation() -> void:
	if is_first_person():
		if _fps_arms:
			_fps_arms.play_attack()
	else:
		# Third-person mode - animate the weapon swing
		if _tp_weapon and _tp_weapon.has_method("play_attack_swing"):
			_tp_weapon.play_attack_swing()

## Trigger spell cast animation on first-person arms
func play_cast_animation(spell: SpellData = null) -> void:
	if _fps_arms and is_first_person():
		_fps_arms.play_cast(spell)

## Trigger reload animation on first-person arms
func play_reload_animation(duration: float = 1.0) -> void:
	if _fps_arms and is_first_person():
		_fps_arms.play_reload(duration)

## Update the displayed weapon in first-person arms
func update_fps_weapon() -> void:
	if _fps_arms:
		_fps_arms.update_equipped_weapon()

## Get the FPS arms node for direct access
func get_fps_arms() -> FirstPersonArms:
	return _fps_arms
