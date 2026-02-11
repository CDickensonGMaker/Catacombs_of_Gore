## torch_prop.gd - Animated torch with dynamic lighting
## Uses billboard sprite for PS1-style appearance
class_name TorchProp
extends Node3D

## Configuration
@export var lit: bool = true:
	set(value):
		lit = value
		_update_lit_state()

## Sprite settings
const SPRITE_PATH := "res://assets/sprites/props/torch_animated.png"
const H_FRAMES := 4  ## Columns in sprite sheet
const V_FRAMES := 4  ## Rows in sprite sheet
const TOTAL_FRAMES := 16
const ANIMATION_FPS := 12.0
const PIXEL_SIZE := 0.011  ## Size of each pixel in world units (27% smaller than original)

## Light settings
const LIGHT_COLOR := Color(1.0, 0.7, 0.3)
const LIGHT_RANGE := 8.0
const LIGHT_ENERGY_BASE := 1.5
const LIGHT_ENERGY_MIN := 1.3
const LIGHT_ENERGY_MAX := 1.7
const LIGHT_ATTENUATION := 1.2
const FLICKER_SPEED := 8.0  ## How fast the light flickers

## Components
var sprite: Sprite3D
var light: OmniLight3D

## Animation state
var current_frame: int = 0
var animation_timer: float = 0.0
var flicker_time: float = 0.0


func _ready() -> void:
	add_to_group("props")
	add_to_group("torches")

	_create_sprite()
	_create_light()
	_update_lit_state()

	# Randomize initial state for variety
	current_frame = randi() % TOTAL_FRAMES
	flicker_time = randf() * TAU
	animation_timer = randf() * (1.0 / ANIMATION_FPS)


func _process(delta: float) -> void:
	if not lit:
		return

	_animate_sprite(delta)
	_animate_light(delta)


## Create the billboard sprite
func _create_sprite() -> void:
	sprite = Sprite3D.new()
	sprite.name = "TorchSprite"

	# Load texture
	var texture := load(SPRITE_PATH) as Texture2D
	if texture:
		sprite.texture = texture

	# Sprite sheet setup
	sprite.hframes = H_FRAMES
	sprite.vframes = V_FRAMES
	sprite.pixel_size = PIXEL_SIZE

	# Billboard mode - always faces camera
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	# Rendering settings
	sprite.transparent = true
	sprite.no_depth_test = false
	sprite.shaded = false  # Unshaded so emission is visible

	# Alpha scissor for clean edges (PS1 style)
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.alpha_scissor_threshold = 0.5

	# Create emissive material so the flame glows
	var glow_mat := StandardMaterial3D.new()
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	glow_mat.alpha_scissor_threshold = 0.5
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_texture = texture
	glow_mat.emission_enabled = true
	glow_mat.emission = LIGHT_COLOR  # Orange glow matching the light
	glow_mat.emission_energy_multiplier = 2.0
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.material_override = glow_mat

	# Use centered=true for horizontal centering - prevents frame jumping between animation frames
	# Then use offset to position the bottom of the sprite at the node origin
	sprite.centered = true

	# Calculate vertical offset to put bottom at node position
	if texture:
		var frame_height := texture.get_height() / float(V_FRAMES)
		# Lift by half frame height so bottom of sprite sits at origin
		sprite.offset = Vector2(0, frame_height / 2.0)

	add_child(sprite)


## Create the omni light for torch glow
func _create_light() -> void:
	light = OmniLight3D.new()
	light.name = "TorchLight"

	light.light_color = LIGHT_COLOR
	light.light_energy = LIGHT_ENERGY_BASE
	light.omni_range = LIGHT_RANGE
	light.omni_attenuation = LIGHT_ATTENUATION

	# Position light at flame height (roughly upper portion of sprite)
	# Assuming torch sprite has flame at top, offset upward
	var texture := load(SPRITE_PATH) as Texture2D
	if texture:
		var frame_height := (texture.get_height() / float(V_FRAMES)) * PIXEL_SIZE
		# Place light at about 75% of sprite height (where flame would be)
		light.position = Vector3(0, frame_height * 0.75, 0)
	else:
		light.position = Vector3(0, 0.5, 0)

	add_child(light)


## Animate sprite through frames
func _animate_sprite(delta: float) -> void:
	if not sprite:
		return

	animation_timer += delta
	var frame_time := 1.0 / ANIMATION_FPS

	if animation_timer >= frame_time:
		animation_timer -= frame_time
		current_frame = (current_frame + 1) % TOTAL_FRAMES
		sprite.frame = current_frame


## Animate light flicker
func _animate_light(delta: float) -> void:
	if not light:
		return

	flicker_time += delta * FLICKER_SPEED

	# Use noise-like pattern for natural flicker
	var flicker := sin(flicker_time) * 0.3 + sin(flicker_time * 2.3) * 0.2 + sin(flicker_time * 4.7) * 0.1
	var normalized_flicker := (flicker + 0.6) / 1.2  # Normalize to roughly 0-1

	light.light_energy = lerp(LIGHT_ENERGY_MIN, LIGHT_ENERGY_MAX, normalized_flicker)


## Update visual state based on lit property
func _update_lit_state() -> void:
	if sprite:
		sprite.visible = lit
		if not lit:
			sprite.frame = 0  # Reset to first frame when unlit

	if light:
		light.visible = lit


## Light the torch
func ignite() -> void:
	lit = true


## Extinguish the torch
func extinguish() -> void:
	lit = false


## Toggle lit state
func toggle() -> void:
	lit = not lit


## Static helper to spawn a torch
## parent: Node to add torch to
## pos: World position for torch
## wall_mounted: If true, offsets slightly from wall position
static func spawn_torch(parent: Node, pos: Vector3, wall_mounted: bool = true) -> TorchProp:
	var torch := TorchProp.new()

	if wall_mounted:
		# Offset slightly away from wall (assumes pos is at wall surface)
		# The offset direction would depend on wall orientation
		# For simplicity, we just push it slightly inward on all axes
		torch.position = pos
	else:
		torch.position = pos

	parent.add_child(torch)
	return torch


## Static helper to spawn a wall-mounted torch with specific facing direction
## facing: The direction the torch should face (away from wall)
static func spawn_wall_torch(parent: Node, pos: Vector3, facing: Vector3) -> TorchProp:
	var torch := TorchProp.new()

	# Offset position away from wall to prevent sprite clipping into wall surface
	var wall_offset := 0.4
	torch.position = pos + facing.normalized() * wall_offset

	parent.add_child(torch)
	return torch
