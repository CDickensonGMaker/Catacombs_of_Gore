## billboard_sprite.gd - Doom/Wolfenstein-style billboard sprite that always faces camera
## Supports directional sprites (8 angles) and animation states
class_name BillboardSprite
extends Node3D

## Animation states
enum AnimState {
	IDLE,
	WALK,
	ATTACK,
	HURT,
	DEATH
}

## Ground sink offset - lower sprites slightly to prevent floating appearance
const GROUND_SINK: float = -0.05  ## Lower sprites 5cm below origin to sit into ground

## Configuration
@export var sprite_sheet: Texture2D
@export var h_frames: int = 4  ## Columns in sprite sheet
@export var v_frames: int = 4  ## Rows in sprite sheet
@export var pixel_size: float = 0.0384  ## Size of each pixel in world units (standardized humanoid size)
@export var offset_y: float = 0.0  ## Additional vertical offset (added to GROUND_SINK)

## Separate textures per state (optional - uses sprite_sheet if not set)
@export_group("State Textures")
@export var idle_texture: Texture2D       ## Separate texture for idle state
@export var idle_texture_h_frames: int = 4
@export var idle_texture_v_frames: int = 1
@export var walk_texture: Texture2D       ## Separate texture for walking
@export var walk_texture_h_frames: int = 4
@export var walk_texture_v_frames: int = 1
@export var attack_texture: Texture2D     ## Separate texture for attack (or use idle)
@export var attack_texture_h_frames: int = 4
@export var attack_texture_v_frames: int = 1
@export var death_texture: Texture2D      ## Separate texture for death
@export var death_texture_h_frames: int = 4
@export var death_texture_v_frames: int = 1

## Animation configuration
## Maps AnimState to row indices in sprite sheet
## Each row can have multiple frames for animation
@export_group("Animation Rows")
@export var idle_row: int = 0
@export var idle_frames: int = 1
@export var walk_row: int = 1
@export var walk_frames: int = 2
@export var attack_row: int = 2
@export var attack_frames: int = 2
@export var hurt_row: int = 3
@export var hurt_frames: int = 1
@export var death_row: int = 3
@export var death_frames: int = 4

## Animation speeds (frames per second)
@export var idle_fps: float = 2.0
@export var walk_fps: float = 8.0
@export var attack_fps: float = 10.0
@export var death_fps: float = 6.0

## Components
var sprite: Sprite3D
var current_state: AnimState = AnimState.IDLE
var current_frame: int = 0
var animation_timer: float = 0.0
var is_dead: bool = false

## Direction tracking (for 8-directional sprites)
var use_directional_sprites: bool = false
var direction_count: int = 8
var facing_direction: Vector3 = Vector3.FORWARD

## Owner enemy reference
var owner_enemy: Node = null

func _ready() -> void:
	_create_sprite()

func _process(delta: float) -> void:
	if not sprite:
		return

	# Billboard: always face camera
	_face_camera()

	# Animate
	if not is_dead or current_state == AnimState.DEATH:
		_animate(delta)

## Create the Sprite3D node
func _create_sprite() -> void:
	sprite = Sprite3D.new()
	sprite.name = "Sprite"
	sprite.pixel_size = pixel_size

	# Use centered=true for horizontal centering - prevents frame jumping between animation frames
	# Then use offset to position the bottom of the sprite at the node origin
	sprite.centered = true

	# Billboard settings
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.no_depth_test = false
	sprite.shaded = true

	# Alpha scissor for clean edges (PS1 style)
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.alpha_scissor_threshold = 0.5

	# Set texture
	if sprite_sheet:
		sprite.texture = sprite_sheet
		sprite.hframes = h_frames
		sprite.vframes = v_frames

	# Calculate vertical offset to put bottom at node position
	# With centered=true, the sprite center is at origin, so we lift by half frame height
	if sprite_sheet:
		var frame_height := sprite_sheet.get_height() / float(v_frames)
		# Lift by half frame height so bottom of sprite sits at origin
		sprite.offset = Vector2(0, frame_height / 2.0)

	# Apply ground sink + any additional vertical offset via position
	# GROUND_SINK lowers sprite slightly to prevent floating appearance
	sprite.position = Vector3(0, GROUND_SINK + offset_y, 0)

	add_child(sprite)

	# Set initial frame
	_update_frame()

## Make sprite face the camera
func _face_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	# The billboard setting handles facing, but we might want to select
	# a different sprite frame based on view angle for 8-directional sprites
	if use_directional_sprites and owner_enemy:
		_update_directional_frame(camera)

## Update frame based on camera angle (for 8-directional sprites)
func _update_directional_frame(camera: Camera3D) -> void:
	# Get direction from enemy to camera
	var to_camera: Vector3 = (camera.global_position - global_position).normalized()
	to_camera.y = 0
	to_camera = to_camera.normalized()

	# Get enemy's facing direction
	var facing: Vector3 = facing_direction
	facing.y = 0
	facing = facing.normalized()

	# Calculate angle between facing and camera direction
	var angle := facing.signed_angle_to(to_camera, Vector3.UP)

	# Convert to 8 directions (0 = front, 1 = front-right, etc.)
	# Angle is -PI to PI, 0 is front
	var direction_index := int(round((angle + PI) / (TAU / direction_count))) % direction_count

	# This would be used to select a different column in the sprite sheet
	# For now, we use single-direction sprites
	pass

## Animate the sprite
func _animate(delta: float) -> void:
	var row: int
	var frame_count: int
	var fps: float

	match current_state:
		AnimState.IDLE:
			row = idle_row
			frame_count = idle_frames
			fps = idle_fps
		AnimState.WALK:
			row = walk_row
			frame_count = walk_frames
			fps = walk_fps
		AnimState.ATTACK:
			row = attack_row
			frame_count = attack_frames
			fps = attack_fps
		AnimState.HURT:
			row = hurt_row
			frame_count = hurt_frames
			fps = idle_fps  # Quick hurt flash
		AnimState.DEATH:
			row = death_row
			frame_count = death_frames
			fps = death_fps

	# Advance animation timer
	animation_timer += delta
	var frame_time := 1.0 / fps

	if animation_timer >= frame_time:
		animation_timer -= frame_time

		if current_state == AnimState.DEATH:
			# Death animation plays once
			if current_frame < frame_count - 1:
				current_frame += 1
		elif current_state == AnimState.HURT:
			# Hurt is a single frame, return to idle
			set_state(AnimState.IDLE)
		elif current_state == AnimState.ATTACK:
			# Attack plays once then returns to idle
			current_frame += 1
			if current_frame >= frame_count:
				current_frame = 0
				set_state(AnimState.IDLE)
		else:
			# Loop animation
			current_frame = (current_frame + 1) % frame_count

		_update_frame()

## Update the sprite frame index
func _update_frame() -> void:
	if not sprite:
		return

	# Check if using separate textures for this state
	var using_separate_texture := false
	var current_h_frames := h_frames

	match current_state:
		AnimState.IDLE:
			if idle_texture:
				using_separate_texture = true
				current_h_frames = idle_texture_h_frames
		AnimState.WALK:
			if walk_texture:
				using_separate_texture = true
				current_h_frames = walk_texture_h_frames
		AnimState.ATTACK:
			if attack_texture or idle_texture:
				using_separate_texture = true
				current_h_frames = attack_texture_h_frames if attack_texture else idle_texture_h_frames
		AnimState.HURT:
			if idle_texture:
				using_separate_texture = true
				current_h_frames = idle_texture_h_frames
		AnimState.DEATH:
			if death_texture:
				using_separate_texture = true
				current_h_frames = death_texture_h_frames

	var row: int
	if using_separate_texture:
		# Separate textures use row 0 (single row per texture)
		row = 0
	else:
		# Single sprite sheet uses configured rows
		match current_state:
			AnimState.IDLE:
				row = idle_row
			AnimState.WALK:
				row = walk_row
			AnimState.ATTACK:
				row = attack_row
			AnimState.HURT:
				row = hurt_row
			AnimState.DEATH:
				row = death_row
			_:
				row = idle_row

	# Calculate frame index (row * columns + column)
	var frame_index: int = row * current_h_frames + current_frame
	var max_frames := sprite.hframes * sprite.vframes
	frame_index = clampi(frame_index, 0, max_frames - 1)
	sprite.frame = frame_index

## Set animation state
func set_state(new_state: AnimState) -> void:
	if current_state == AnimState.DEATH:
		return  # Can't change state once dead

	if new_state != current_state:
		current_state = new_state
		current_frame = 0
		animation_timer = 0.0
		_swap_texture_for_state(new_state)
		_update_frame()


## Swap texture if using separate state textures
func _swap_texture_for_state(state: AnimState) -> void:
	if not sprite:
		return

	var new_texture: Texture2D = null
	var new_h_frames: int = h_frames
	var new_v_frames: int = v_frames

	match state:
		AnimState.IDLE:
			if idle_texture:
				new_texture = idle_texture
				new_h_frames = idle_texture_h_frames
				new_v_frames = idle_texture_v_frames
		AnimState.WALK:
			if walk_texture:
				new_texture = walk_texture
				new_h_frames = walk_texture_h_frames
				new_v_frames = walk_texture_v_frames
		AnimState.ATTACK:
			# Attack can use attack_texture, or fall back to idle_texture
			if attack_texture:
				new_texture = attack_texture
				new_h_frames = attack_texture_h_frames
				new_v_frames = attack_texture_v_frames
			elif idle_texture:
				new_texture = idle_texture
				new_h_frames = idle_texture_h_frames
				new_v_frames = idle_texture_v_frames
		AnimState.HURT:
			# Hurt uses idle texture
			if idle_texture:
				new_texture = idle_texture
				new_h_frames = idle_texture_h_frames
				new_v_frames = idle_texture_v_frames
		AnimState.DEATH:
			if death_texture:
				new_texture = death_texture
				new_h_frames = death_texture_h_frames
				new_v_frames = death_texture_v_frames

	# Apply new texture if we have one
	if new_texture and new_texture != sprite.texture:
		sprite.texture = new_texture
		sprite.hframes = new_h_frames
		sprite.vframes = new_v_frames

		# Recalculate vertical offset for new texture size
		var frame_height := new_texture.get_height() / float(new_v_frames)
		sprite.offset = Vector2(0, frame_height / 2.0)

## Play death animation
func play_death() -> void:
	is_dead = true
	set_state(AnimState.DEATH)

## Play hurt flash
func play_hurt() -> void:
	if not is_dead:
		set_state(AnimState.HURT)
		# Flash red
		if sprite:
			var tween := create_tween()
			sprite.modulate = Color(1.5, 0.3, 0.3)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

## Play attack animation
func play_attack() -> void:
	if not is_dead:
		set_state(AnimState.ATTACK)

## Set walking state
func set_walking(is_walking: bool) -> void:
	if is_dead:
		return
	if is_walking and current_state == AnimState.IDLE:
		set_state(AnimState.WALK)
	elif not is_walking and current_state == AnimState.WALK:
		set_state(AnimState.IDLE)

## Update facing direction (for directional sprites)
func set_facing_direction(dir: Vector3) -> void:
	facing_direction = dir

## Setup from configuration dictionary
func setup(config: Dictionary) -> void:
	if config.has("sprite_sheet"):
		sprite_sheet = config.sprite_sheet
	if config.has("h_frames"):
		h_frames = config.h_frames
	if config.has("v_frames"):
		v_frames = config.v_frames
	if config.has("pixel_size"):
		pixel_size = config.pixel_size
	if config.has("offset_y"):
		offset_y = config.offset_y

	# Recreate sprite with new settings
	if sprite:
		sprite.queue_free()
	_create_sprite()

## Static helper to create and configure a billboard sprite
## Note: y_offset defaults to 0.0 since sprite bottom naturally sits at ground level
static func create_billboard(parent: Node3D, texture: Texture2D, h: int = 4, v: int = 4, size: float = 0.0384, y_offset: float = 0.0) -> BillboardSprite:
	var billboard := BillboardSprite.new()
	billboard.sprite_sheet = texture
	billboard.h_frames = h
	billboard.v_frames = v
	billboard.pixel_size = size
	billboard.offset_y = y_offset
	parent.add_child(billboard)
	return billboard


## Setup separate textures for different animation states
## Use this for enemies with separate sprite sheets per state (like vampire lord)
func setup_state_textures(
	p_idle_texture: Texture2D, p_idle_h: int, p_idle_v: int, p_idle_frames: int,
	p_walk_texture: Texture2D, p_walk_h: int, p_walk_v: int, p_walk_frames: int,
	p_death_texture: Texture2D, p_death_h: int, p_death_v: int, p_death_frames: int,
	p_attack_texture: Texture2D = null, p_attack_h: int = 0, p_attack_v: int = 0, p_attack_frames: int = 0
) -> void:
	# Idle texture (also used for hurt)
	idle_texture = p_idle_texture
	idle_texture_h_frames = p_idle_h
	idle_texture_v_frames = p_idle_v
	idle_frames = p_idle_frames

	# Walk texture
	walk_texture = p_walk_texture
	walk_texture_h_frames = p_walk_h
	walk_texture_v_frames = p_walk_v
	walk_frames = p_walk_frames

	# Death texture
	death_texture = p_death_texture
	death_texture_h_frames = p_death_h
	death_texture_v_frames = p_death_v
	death_frames = p_death_frames

	# Attack texture (optional - falls back to idle)
	if p_attack_texture:
		attack_texture = p_attack_texture
		attack_texture_h_frames = p_attack_h
		attack_texture_v_frames = p_attack_v
		attack_frames = p_attack_frames
	else:
		attack_texture = p_idle_texture
		attack_texture_h_frames = p_idle_h
		attack_texture_v_frames = p_idle_v
		attack_frames = p_idle_frames

	# Set initial texture
	if sprite and idle_texture:
		sprite.texture = idle_texture
		sprite.hframes = idle_texture_h_frames
		sprite.vframes = idle_texture_v_frames
		var frame_height := idle_texture.get_height() / float(idle_texture_v_frames)
		sprite.offset = Vector2(0, frame_height / 2.0)
		sprite.position = Vector3(0, GROUND_SINK + offset_y, 0)
