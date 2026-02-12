# File: scripts/player/first_person_arms.gd
# Attach to: Player/CameraPivot/Camera3D/FirstPersonArms (CanvasLayer)
# Handles first-person weapon/spell sprites and animations (DOOM-style)
# Also supports 3D weapon meshes rendered via SubViewport
extends CanvasLayer
class_name FirstPersonArms

## Animation states for the arms
enum ArmState { IDLE, ATTACKING, CASTING, BLOCKING, RELOADING }

## Current state
var current_state: ArmState = ArmState.IDLE

## References
var weapon_sprite: TextureRect
var spell_sprite: TextureRect  # For magic hand effects
var animation_timer: float = 0.0
var current_frame: int = 0

## The base texture (full sprite sheet) and atlas for frame display
var weapon_base_texture: Texture2D = null
var weapon_atlas: AtlasTexture = null

## Configuration
@export var idle_bob_amount: float = 4.0  # Pixels of idle bobbing
@export var idle_bob_speed: float = 2.0   # Bob cycles per second
@export var attack_duration: float = 0.5  # Seconds for full attack animation (16 frames)
@export var cast_duration: float = 0.5    # Seconds for spell cast animation

## Sprite sheet configuration (can be overridden per weapon)
var weapon_h_frames: int = 4  # Columns in sprite sheet
var weapon_v_frames: int = 4  # Rows
var total_frames: int = 16    # Total animation frames

## Frame margin - crops each frame inward by this percentage (0.0-0.5) to hide adjacent frame bleed
var frame_margin_percent: float = 0.10  # 10% crop from each edge

## Animation tracking
var time_elapsed: float = 0.0
var animation_playing: bool = false
var frame_duration: float = 0.03  # Seconds per frame (~30fps animation)

## Base positions for weapon/spell sprites
var weapon_base_position: Vector2 = Vector2(0, 0)
var spell_base_position: Vector2 = Vector2(0, 0)

## Track if arms should be shown (set by camera_pivot)
var _should_be_visible: bool = false

## 3D Weapon System
var using_3d_weapon: bool = false
var weapon_viewport: SubViewport
var weapon_viewport_container: Control  # TextureRect that displays the weapon viewport
var weapon_camera: Camera3D
var weapon_3d_root: Node3D
var weapon_mesh_instance: Node3D  # The loaded GLB scene
var weapon_3d_base_position: Vector3 = Vector3.ZERO
var weapon_3d_base_rotation: Vector3 = Vector3.ZERO

## Debug visualization
@export var show_viewmodel_debug: bool = false  # Toggle in Inspector to show debug box
var debug_box: ColorRect
var debug_cube: MeshInstance3D

## 3D Weapon Configuration
@export var idle_bob_3d_amount: float = 0.02  # Units of 3D bobbing
@export var idle_bob_3d_speed: float = 2.0    # Bob cycles per second
@export var attack_swing_angle: float = 90.0  # Degrees of swing during attack
@export var attack_swing_speed: float = 3.0   # Speed multiplier for attack swing

## Signals
signal attack_animation_finished
signal cast_animation_finished


func _ready() -> void:
	# Set layer to render on top of 3D but below UI (layer 1 = just above 3D, below UI text)
	layer = 1

	# Create the UI structure
	_setup_ui()

	# Start hidden until first person mode activates
	visible = false

	# Connect to viewport resize to update 3D weapon viewport size
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	# Connect to inventory changes to update weapon display
	# Use call_deferred to ensure InventoryManager is ready
	call_deferred("_connect_inventory_signals")


func _connect_inventory_signals() -> void:
	# Check if InventoryManager has signals for equipment changes
	if InventoryManager.has_signal("equipment_changed"):
		InventoryManager.equipment_changed.connect(_on_equipment_changed)
	if InventoryManager.has_signal("spell_equipped"):
		InventoryManager.spell_equipped.connect(_on_spell_equipped)


func _on_equipment_changed(_slot: String, _old_item: Dictionary, _new_item: Dictionary) -> void:
	if _should_be_visible:
		update_equipped_weapon()


func _on_spell_equipped(_spell: SpellData) -> void:
	if _should_be_visible:
		update_equipped_weapon()


func _setup_ui() -> void:
	# Create a Control node to hold our sprites with clipping
	var container := Control.new()
	container.name = "ArmsContainer"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.clip_contents = true  # Clip anything outside the viewport
	add_child(container)

	# Create weapon sprite (centered at bottom of screen)
	weapon_sprite = TextureRect.new()
	weapon_sprite.name = "WeaponSprite"
	weapon_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_sprite.custom_minimum_size = Vector2(256, 256)  # Base size
	container.add_child(weapon_sprite)

	# Create spell effect sprite (for magic casting hands)
	spell_sprite = TextureRect.new()
	spell_sprite.name = "SpellSprite"
	spell_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spell_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spell_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spell_sprite.custom_minimum_size = Vector2(200, 200)
	spell_sprite.visible = false
	container.add_child(spell_sprite)

	# Setup 3D weapon viewport system
	_setup_3d_weapon_viewport(container)

	# Setup debug visualization
	_setup_debug_box(container)

	# Position weapon sprite at bottom center
	_position_sprites()
	# Position 3D weapon display in lower-right
	_position_3d_weapon_display()


func _setup_3d_weapon_viewport(container: Control) -> void:
	# Create a TextureRect to display the viewport
	var texture_rect := TextureRect.new()
	texture_rect.name = "Weapon3DTextureRect"
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.visible = false  # Hidden until 3D weapon equipped
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	container.add_child(texture_rect)

	# Store reference
	weapon_viewport_container = texture_rect

	# Create SubViewport with transparency
	weapon_viewport = SubViewport.new()
	weapon_viewport.name = "WeaponViewport"
	weapon_viewport.transparent_bg = true
	weapon_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	weapon_viewport.handle_input_locally = false
	weapon_viewport.size = Vector2i(512, 512)
	# Use own world so it doesn't render the main scene
	weapon_viewport.own_world_3d = true
	add_child(weapon_viewport)

	# Connect the viewport texture to the TextureRect
	texture_rect.texture = weapon_viewport.get_texture()

	# Create Camera3D for the weapon viewport
	weapon_camera = Camera3D.new()
	weapon_camera.name = "WeaponCamera"
	weapon_camera.fov = 70.0
	weapon_camera.near = 0.01
	weapon_camera.far = 10.0
	weapon_camera.current = true
	weapon_camera.position = Vector3(0, 0, 1.0)  # Camera pulled back to see weapon
	weapon_viewport.add_child(weapon_camera)

	# Create root node for 3D weapon at origin
	weapon_3d_root = Node3D.new()
	weapon_3d_root.name = "Weapon3DRoot"
	weapon_viewport.add_child(weapon_3d_root)

	# Add lighting for the weapon
	var weapon_light := DirectionalLight3D.new()
	weapon_light.name = "WeaponLight"
	weapon_light.light_energy = 1.2
	weapon_light.rotation_degrees = Vector3(-30, 45, 0)
	weapon_viewport.add_child(weapon_light)

	# Add fill light from below/front
	var fill_light := DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.light_energy = 0.4
	fill_light.rotation_degrees = Vector3(30, -30, 0)
	weapon_viewport.add_child(fill_light)


## Setup debug visualization (outline around viewport area)
func _setup_debug_box(container: Control) -> void:
	debug_box = ColorRect.new()
	debug_box.name = "DebugBox"
	debug_box.color = Color(1, 0, 0, 0.3)  # Semi-transparent red
	debug_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_box.visible = show_viewmodel_debug
	container.add_child(debug_box)


## Handle viewport resize - position the 3D weapon display
func _on_viewport_size_changed() -> void:
	_position_sprites()
	_position_3d_weapon_display()


## Horizontal offset to adjust weapon centering (positive = shift right)
var weapon_x_offset: float = 22.0  # Slight shift right to keep sword centered

func _position_sprites() -> void:
	if not weapon_sprite:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var weapon_size := weapon_sprite.custom_minimum_size

	# Center horizontally with offset, anchor to bottom but raised for visibility
	weapon_base_position = Vector2(
		(viewport_size.x - weapon_size.x) / 2.0 + weapon_x_offset,
		viewport_size.y - weapon_size.y - 30  # Raised higher so weapon is more visible
	)
	weapon_sprite.position = weapon_base_position
	weapon_sprite.size = weapon_size

	# Spell sprite centered but higher
	if spell_sprite:
		var spell_size := spell_sprite.custom_minimum_size
		spell_base_position = Vector2(
			(viewport_size.x - spell_size.x) / 2.0,
			viewport_size.y - spell_size.y - 50
		)
		spell_sprite.position = spell_base_position
		spell_sprite.size = spell_size


## Position the 3D weapon display centered at bottom of screen
func _position_3d_weapon_display() -> void:
	if not weapon_viewport_container:
		return

	var viewport_size := get_viewport().get_visible_rect().size

	# Large display area to show full weapon
	var display_size := Vector2(800, 600)

	# Position centered horizontally, at bottom of screen
	weapon_viewport_container.position = Vector2(
		(viewport_size.x - display_size.x) / 2.0,
		viewport_size.y - display_size.y
	)
	weapon_viewport_container.size = display_size

	# Update debug box to match viewport area
	if debug_box:
		debug_box.position = weapon_viewport_container.position
		debug_box.size = display_size
		debug_box.visible = show_viewmodel_debug


func _process(delta: float) -> void:
	# Hide weapon when menus are open
	var should_show := _should_be_visible and not GameManager.is_in_menu

	# Handle visibility based on weapon type
	if using_3d_weapon:
		if weapon_sprite:
			weapon_sprite.visible = false
		if weapon_viewport_container:
			weapon_viewport_container.visible = should_show
	else:
		if weapon_sprite:
			weapon_sprite.visible = should_show and weapon_atlas != null
		if weapon_viewport_container:
			weapon_viewport_container.visible = false

	if not should_show:
		return

	time_elapsed += delta

	# Handle animation state
	match current_state:
		ArmState.IDLE:
			if using_3d_weapon:
				_process_idle_3d(delta)
			else:
				_process_idle(delta)
		ArmState.ATTACKING:
			if using_3d_weapon:
				_process_attack_3d(delta)
			else:
				_process_attack(delta)
		ArmState.CASTING:
			_process_cast(delta)
		ArmState.RELOADING:
			_process_reload(delta)

	# Update sprite frame based on animation (only for 2D)
	if not using_3d_weapon:
		_update_sprite_frame()


func _process_idle(delta: float) -> void:
	# Gentle bobbing motion
	var bob_offset := sin(time_elapsed * idle_bob_speed * TAU) * idle_bob_amount

	if weapon_sprite and weapon_sprite.visible:
		weapon_sprite.position.y = weapon_base_position.y + bob_offset

	# Show first frame (idle pose) when not attacking
	current_frame = 0
	_update_sprite_frame()


func _process_attack(delta: float) -> void:
	animation_timer -= delta

	# Calculate current frame based on progress through all frames
	var progress := 1.0 - (animation_timer / attack_duration)
	current_frame = int(progress * total_frames)
	current_frame = clampi(current_frame, 0, total_frames - 1)

	# Weapon swings forward during attack (subtle movement)
	var swing_offset := sin(progress * PI) * 30.0
	if weapon_sprite:
		weapon_sprite.position.y = weapon_base_position.y - swing_offset

	# Update the displayed frame
	_update_sprite_frame()

	if animation_timer <= 0:
		_finish_attack()


func _process_cast(delta: float) -> void:
	animation_timer -= delta

	# Calculate current frame based on progress
	var progress := 1.0 - (animation_timer / cast_duration)
	current_frame = int(progress * total_frames)
	current_frame = clampi(current_frame, 0, total_frames - 1)

	# Hands raise up during cast
	var raise_offset := sin(progress * PI) * 60.0
	if spell_sprite:
		spell_sprite.position.y = spell_base_position.y - raise_offset

	# Also animate weapon if visible (casting with weapon equipped)
	_update_sprite_frame()

	if animation_timer <= 0:
		_finish_cast()


func _process_reload(delta: float) -> void:
	animation_timer -= delta

	# Weapon dips down during reload
	var progress := 1.0 - (animation_timer / attack_duration)
	var dip_offset := sin(progress * PI) * 80.0
	if weapon_sprite:
		weapon_sprite.position.y = weapon_base_position.y + dip_offset

	if animation_timer <= 0:
		current_state = ArmState.IDLE


## 3D Weapon idle animation - gentle bobbing
func _process_idle_3d(_delta: float) -> void:
	if not weapon_mesh_instance:
		return

	# Gentle bobbing motion in Y axis
	var bob_offset := sin(time_elapsed * idle_bob_3d_speed * TAU) * idle_bob_3d_amount
	# Slight sway in X axis
	var sway_offset := sin(time_elapsed * idle_bob_3d_speed * 0.7 * TAU) * (idle_bob_3d_amount * 0.5)

	weapon_mesh_instance.position = weapon_3d_base_position + Vector3(sway_offset, bob_offset, 0)
	weapon_mesh_instance.rotation_degrees = weapon_3d_base_rotation


## 3D Weapon attack animation - swing motion
func _process_attack_3d(delta: float) -> void:
	if not weapon_mesh_instance:
		_finish_attack()
		return

	animation_timer -= delta

	# Calculate attack progress (0 to 1)
	var progress := 1.0 - (animation_timer / attack_duration)
	progress = clampf(progress, 0.0, 1.0)

	# Swing animation phases:
	# 0.0-0.2: Wind up (pull back)
	# 0.2-0.6: Swing forward
	# 0.6-1.0: Follow through and return

	var swing_rotation := 0.0
	var forward_offset := 0.0
	var side_offset := 0.0

	if progress < 0.2:
		# Wind up - pull back and rotate slightly back
		var wind_up := progress / 0.2
		swing_rotation = -20.0 * wind_up  # Rotate back
		forward_offset = 0.1 * wind_up    # Pull back slightly
		side_offset = -0.05 * wind_up     # Pull to side
	elif progress < 0.6:
		# Main swing - fast forward rotation
		var swing := (progress - 0.2) / 0.4
		var eased := 1.0 - pow(1.0 - swing, 3)  # Ease out for impact feel
		swing_rotation = -20.0 + (attack_swing_angle + 20.0) * eased
		forward_offset = 0.1 - 0.25 * eased  # Thrust forward
		side_offset = -0.05 + 0.15 * eased   # Swing across
	else:
		# Follow through and return
		var return_progress := (progress - 0.6) / 0.4
		var eased := return_progress * return_progress  # Ease in for smooth return
		swing_rotation = attack_swing_angle * (1.0 - eased)
		forward_offset = -0.15 * (1.0 - eased)
		side_offset = 0.1 * (1.0 - eased)

	# Apply the swing animation
	weapon_mesh_instance.position = weapon_3d_base_position + Vector3(side_offset, 0, forward_offset)
	weapon_mesh_instance.rotation_degrees = weapon_3d_base_rotation + Vector3(swing_rotation, 0, 0)

	if animation_timer <= 0:
		_finish_attack()


func _update_sprite_frame() -> void:
	# Update the atlas texture region to show the correct frame
	if not weapon_atlas or not weapon_base_texture:
		return

	var tex_width := weapon_base_texture.get_width()
	var tex_height := weapon_base_texture.get_height()
	var frame_width := float(tex_width) / weapon_h_frames
	var frame_height := float(tex_height) / weapon_v_frames

	# Calculate row and column from frame index
	var col := current_frame % weapon_h_frames
	var row := current_frame / weapon_h_frames

	# Calculate margin in pixels (crop inward from each edge)
	var margin_x := frame_width * frame_margin_percent
	var margin_y := frame_height * frame_margin_percent

	# Set the atlas region with margins applied (cropped inward)
	weapon_atlas.region = Rect2(
		col * frame_width + margin_x,
		row * frame_height + margin_y,
		frame_width - (margin_x * 2),
		frame_height - (margin_y * 2)
	)

	# Force the TextureRect to update
	if weapon_sprite:
		weapon_sprite.texture = weapon_atlas
		weapon_sprite.queue_redraw()


func _finish_attack() -> void:
	current_state = ArmState.IDLE
	animation_playing = false
	emit_signal("attack_animation_finished")


func _finish_cast() -> void:
	current_state = ArmState.IDLE
	animation_playing = false
	spell_sprite.visible = false

	# Show weapon again after casting
	if weapon_sprite and not using_3d_weapon:
		weapon_sprite.visible = true
	if weapon_mesh_instance and using_3d_weapon:
		weapon_mesh_instance.visible = true

	emit_signal("cast_animation_finished")


## --- Public API ---

## Show the arms (called when entering first person)
func show_arms() -> void:
	print("[FPSArms] show_arms called")
	_should_be_visible = true
	visible = true  # Make the CanvasLayer visible
	_position_sprites()
	update_equipped_weapon()


## Hide the arms (called when entering third person)
func hide_arms() -> void:
	_should_be_visible = false
	visible = false  # Hide the CanvasLayer
	if weapon_sprite:
		weapon_sprite.visible = false
	if weapon_viewport_container:
		weapon_viewport_container.visible = false


## Update the displayed weapon based on inventory
func update_equipped_weapon() -> void:
	var weapon: WeaponData = InventoryManager.get_equipped_weapon()
	print("[FPSArms] update_equipped_weapon - weapon: %s" % [
		weapon.display_name if weapon else "NONE"
	])

	# Check for 3D mesh first (takes priority over sprite)
	if weapon and not weapon.fps_mesh_path.is_empty():
		print("[FPSArms] Using 3D mesh: %s" % weapon.fps_mesh_path)
		_setup_3d_weapon(weapon)
		return

	# Fall back to 2D sprite system
	using_3d_weapon = false
	_clear_3d_weapon()

	if weapon and not weapon.fps_sprite_path.is_empty():
		# Load the FPS weapon sprite sheet
		print("[FPSArms] Loading texture: %s" % weapon.fps_sprite_path)
		var tex := load(weapon.fps_sprite_path) as Texture2D
		if tex:
			print("[FPSArms] Texture loaded OK: %dx%d" % [tex.get_width(), tex.get_height()])
			# Store base texture and create atlas for frame animation
			weapon_base_texture = tex
			weapon_h_frames = weapon.fps_h_frames if weapon.fps_h_frames > 0 else 4
			weapon_v_frames = weapon.fps_v_frames if weapon.fps_v_frames > 0 else 4
			total_frames = weapon_h_frames * weapon_v_frames

			# Create atlas texture for showing individual frames
			weapon_atlas = AtlasTexture.new()
			weapon_atlas.atlas = weapon_base_texture
			weapon_atlas.filter_clip = true

			# Set initial frame region (first frame) with margin applied
			var frame_width := float(tex.get_width()) / weapon_h_frames
			var frame_height := float(tex.get_height()) / weapon_v_frames
			var margin_x := frame_width * frame_margin_percent
			var margin_y := frame_height * frame_margin_percent
			weapon_atlas.region = Rect2(margin_x, margin_y, frame_width - (margin_x * 2), frame_height - (margin_y * 2))

			# Apply atlas to sprite
			weapon_sprite.texture = weapon_atlas

			# Use weapon-specific size if defined (15% larger for better visibility)
			if weapon.fps_sprite_size.x > 0 and weapon.fps_sprite_size.y > 0:
				weapon_sprite.custom_minimum_size = weapon.fps_sprite_size
			else:
				weapon_sprite.custom_minimum_size = Vector2(320, 320)

			weapon_sprite.visible = true
			current_frame = 0
			_position_sprites()
			_update_sprite_frame()
			print("[FPSArms] Setup complete - sprite.visible=%s, position=%s, size=%s, atlas_region=%s" % [
				weapon_sprite.visible,
				weapon_sprite.position,
				weapon_sprite.size,
				weapon_atlas.region
			])
		else:
			print("[FPSArms] ERROR: Failed to load texture!")
			_show_placeholder_weapon()
	else:
		print("[FPSArms] No weapon or empty fps_sprite_path")
		_show_placeholder_weapon()

	# Also check for spell (shows different sprite)
	var spell: SpellData = InventoryManager.get_equipped_spell()
	if spell and not spell.fps_sprite_path.is_empty():
		var spell_tex := load(spell.fps_sprite_path) as Texture2D
		if spell_tex and spell_sprite:
			spell_sprite.texture = spell_tex
			if spell.fps_sprite_size.x > 0 and spell.fps_sprite_size.y > 0:
				spell_sprite.custom_minimum_size = spell.fps_sprite_size
			_position_sprites()


## Setup a 3D weapon mesh
func _setup_3d_weapon(weapon: WeaponData) -> void:
	_clear_3d_weapon()

	# Load the mesh resource (GLB loads as PackedScene, OBJ loads as Mesh)
	var resource = load(weapon.fps_mesh_path)
	if not resource:
		print("[FPSArms] ERROR: Failed to load 3D mesh: %s" % weapon.fps_mesh_path)
		using_3d_weapon = false
		_show_placeholder_weapon()
		return

	# Handle different resource types
	if resource is PackedScene:
		weapon_mesh_instance = resource.instantiate()
	elif resource is Mesh:
		# OBJ files load as Mesh - wrap in MeshInstance3D
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = resource
		weapon_mesh_instance = mesh_inst
	else:
		print("[FPSArms] ERROR: Unsupported resource type: %s" % resource.get_class())
		using_3d_weapon = false
		_show_placeholder_weapon()
		return

	if not weapon_mesh_instance:
		print("[FPSArms] ERROR: Failed to create 3D mesh instance")
		using_3d_weapon = false
		_show_placeholder_weapon()
		return

	# Apply weapon-specific transforms
	weapon_mesh_instance.scale = weapon.fps_mesh_scale
	weapon_3d_base_position = weapon.fps_mesh_position
	weapon_3d_base_rotation = weapon.fps_mesh_rotation
	weapon_mesh_instance.position = weapon_3d_base_position
	weapon_mesh_instance.rotation_degrees = weapon_3d_base_rotation

	# Add to the 3D root
	weapon_3d_root.add_child(weapon_mesh_instance)

	using_3d_weapon = true
	weapon_sprite.visible = false
	weapon_viewport_container.visible = _should_be_visible

	print("[FPSArms] 3D weapon setup complete - scale: %s, pos: %s, rot: %s" % [
		weapon.fps_mesh_scale, weapon_3d_base_position, weapon_3d_base_rotation
	])


## Clear any existing 3D weapon
func _clear_3d_weapon() -> void:
	if weapon_mesh_instance and is_instance_valid(weapon_mesh_instance):
		weapon_mesh_instance.queue_free()
		weapon_mesh_instance = null


func _show_placeholder_weapon() -> void:
	# Show a placeholder or empty hands
	# For now, create a simple colored rectangle as placeholder
	weapon_sprite.texture = null
	weapon_sprite.visible = true  # Keep visible, could show fist sprite


## Trigger attack animation
func play_attack() -> void:
	if animation_playing:
		return

	animation_playing = true
	current_state = ArmState.ATTACKING
	animation_timer = attack_duration
	current_frame = 0

	if not using_3d_weapon:
		_update_sprite_frame()


## Trigger spell cast animation
func play_cast(spell: SpellData = null) -> void:
	if animation_playing:
		return

	animation_playing = true
	current_state = ArmState.CASTING
	animation_timer = cast_duration
	current_frame = 0

	# Hide weapon while casting
	if weapon_sprite:
		weapon_sprite.visible = false
	if weapon_mesh_instance and using_3d_weapon:
		weapon_mesh_instance.visible = false

	# Show spell hands
	spell_sprite.visible = true

	# Could load spell-specific hand texture
	if spell and not spell.fps_sprite_path.is_empty():
		var tex := load(spell.fps_sprite_path) as Texture2D
		if tex:
			spell_sprite.texture = tex


## Trigger reload animation (for ranged weapons)
func play_reload(duration: float = 1.0) -> void:
	if animation_playing:
		return

	animation_playing = true
	current_state = ArmState.RELOADING
	animation_timer = duration


## Check if currently animating
func is_animating() -> bool:
	return animation_playing


## Set weapon sprite size
func set_weapon_size(size: Vector2) -> void:
	if weapon_sprite:
		weapon_sprite.custom_minimum_size = size
		_position_sprites()


## Set spell sprite size
func set_spell_size(size: Vector2) -> void:
	if spell_sprite:
		spell_sprite.custom_minimum_size = size
		_position_sprites()


## Apply weapon recoil animation (for musket kick)
func apply_recoil(kick_back: float, duration: float) -> void:
	if not weapon_mesh_instance or not using_3d_weapon:
		return

	var original_pos := weapon_3d_base_position
	var original_rot := weapon_3d_base_rotation

	var recoil_tween := create_tween()
	recoil_tween.set_parallel(true)

	# Kick back and rotate up
	recoil_tween.tween_property(weapon_mesh_instance, "position",
		original_pos + Vector3(0, 0.05, kick_back), duration * 0.2).set_ease(Tween.EASE_OUT)
	recoil_tween.tween_property(weapon_mesh_instance, "rotation_degrees",
		original_rot + Vector3(-15, 0, 3), duration * 0.2).set_ease(Tween.EASE_OUT)

	# Return to original position
	recoil_tween.chain().tween_property(weapon_mesh_instance, "position",
		original_pos, duration * 0.8).set_ease(Tween.EASE_IN_OUT)
	recoil_tween.tween_property(weapon_mesh_instance, "rotation_degrees",
		original_rot, duration * 0.8).set_ease(Tween.EASE_IN_OUT)
