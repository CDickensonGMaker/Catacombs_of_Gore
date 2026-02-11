# File: scripts/player/first_person_arms.gd
# Attach to: Player/CameraPivot/Camera3D/FirstPersonArms (CanvasLayer)
# Handles first-person weapon/spell sprites and animations (DOOM-style)
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

	# Position weapon sprite at bottom center
	_position_sprites()


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


func _process(delta: float) -> void:
	# Hide weapon sprite when menus are open
	var should_show := _should_be_visible and not GameManager.is_in_menu

	if weapon_sprite:
		weapon_sprite.visible = should_show and weapon_atlas != null

	if not should_show:
		return

	time_elapsed += delta

	# Handle animation state
	match current_state:
		ArmState.IDLE:
			_process_idle(delta)
		ArmState.ATTACKING:
			_process_attack(delta)
		ArmState.CASTING:
			_process_cast(delta)
		ArmState.RELOADING:
			_process_reload(delta)

	# Update sprite frame based on animation
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


## Update the displayed weapon based on inventory
func update_equipped_weapon() -> void:
	var weapon: WeaponData = InventoryManager.get_equipped_weapon()
	print("[FPSArms] update_equipped_weapon - weapon: %s, fps_path: %s" % [
		weapon.display_name if weapon else "NONE",
		weapon.fps_sprite_path if weapon else "N/A"
	])

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
	_update_sprite_frame()


## Trigger spell cast animation
func play_cast(spell: SpellData = null) -> void:
	if animation_playing:
		return

	animation_playing = true
	current_state = ArmState.CASTING
	animation_timer = cast_duration
	current_frame = 0

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
