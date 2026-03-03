## post_process.gd - Global screen-space post-processing effects
## Autoload that applies PS1/grim dark visual effects to the entire game
extends CanvasLayer

## The ColorRect that displays the post-process shader
var effect_rect: ColorRect

## Shader material
var shader_material: ShaderMaterial

## Whether post-processing is enabled
var enabled: bool = true:
	set(value):
		enabled = value
		if effect_rect:
			effect_rect.visible = enabled

## Preset configurations
enum Preset { GRIM_DARK, RETRO_PS1, BRIGHT, CUSTOM }
var current_preset: Preset = Preset.GRIM_DARK

func _ready() -> void:
	# Set to highest layer so it renders on top of everything
	layer = 100

	# Create the effect ColorRect
	effect_rect = ColorRect.new()
	effect_rect.name = "PostProcessRect"
	effect_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Load and apply shader
	var shader: Shader = load("res://assets/shaders/ps1_post_process.gdshader")
	if shader:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		effect_rect.material = shader_material

		# Apply default grim dark preset
		apply_preset(Preset.GRIM_DARK)
	else:
		push_warning("[PostProcess] Failed to load ps1_post_process.gdshader")

	add_child(effect_rect)
	print("[PostProcess] Initialized with GRIM_DARK preset")


func _process(_delta: float) -> void:
	# Update time uniform for animated grain
	if shader_material:
		shader_material.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)


## Apply a preset configuration
func apply_preset(preset: Preset) -> void:
	current_preset = preset
	if not shader_material:
		return

	match preset:
		Preset.GRIM_DARK:
			_apply_grim_dark()
		Preset.RETRO_PS1:
			_apply_retro_ps1()
		Preset.BRIGHT:
			_apply_bright()


func _apply_grim_dark() -> void:
	# Grim dark fantasy aesthetic - dark, desaturated, atmospheric
	shader_material.set_shader_parameter("enable_vignette", true)
	shader_material.set_shader_parameter("vignette_intensity", 0.45)
	shader_material.set_shader_parameter("vignette_smoothness", 0.5)

	shader_material.set_shader_parameter("enable_grain", true)
	shader_material.set_shader_parameter("grain_strength", 0.025)  # Subtle grain

	shader_material.set_shader_parameter("enable_color_grading", true)
	shader_material.set_shader_parameter("saturation", 0.62)  # Desaturated
	shader_material.set_shader_parameter("contrast", 1.18)
	shader_material.set_shader_parameter("brightness", 0.85)  # Darker
	shader_material.set_shader_parameter("tint_color", Vector3(0.95, 0.9, 0.85))
	shader_material.set_shader_parameter("tint_strength", 0.12)

	shader_material.set_shader_parameter("enable_dithering", true)
	shader_material.set_shader_parameter("dither_strength", 0.3)
	shader_material.set_shader_parameter("color_levels", 24.0)

	shader_material.set_shader_parameter("enable_aberration", true)
	shader_material.set_shader_parameter("aberration_amount", 0.0008)

	shader_material.set_shader_parameter("enable_scanlines", false)


func _apply_retro_ps1() -> void:
	# Classic PS1 look - more color banding, scanlines
	shader_material.set_shader_parameter("enable_vignette", true)
	shader_material.set_shader_parameter("vignette_intensity", 0.25)
	shader_material.set_shader_parameter("vignette_smoothness", 0.6)

	shader_material.set_shader_parameter("enable_grain", true)
	shader_material.set_shader_parameter("grain_strength", 0.04)

	shader_material.set_shader_parameter("enable_color_grading", true)
	shader_material.set_shader_parameter("saturation", 0.85)
	shader_material.set_shader_parameter("contrast", 1.1)
	shader_material.set_shader_parameter("brightness", 0.95)
	shader_material.set_shader_parameter("tint_strength", 0.0)

	shader_material.set_shader_parameter("enable_dithering", true)
	shader_material.set_shader_parameter("dither_strength", 0.5)
	shader_material.set_shader_parameter("color_levels", 16.0)

	shader_material.set_shader_parameter("enable_aberration", true)
	shader_material.set_shader_parameter("aberration_amount", 0.002)

	shader_material.set_shader_parameter("enable_scanlines", true)
	shader_material.set_shader_parameter("scanline_strength", 0.15)


func _apply_bright() -> void:
	# Brighter look for comparison or player preference
	shader_material.set_shader_parameter("enable_vignette", true)
	shader_material.set_shader_parameter("vignette_intensity", 0.2)
	shader_material.set_shader_parameter("vignette_smoothness", 0.6)

	shader_material.set_shader_parameter("enable_grain", false)

	shader_material.set_shader_parameter("enable_color_grading", true)
	shader_material.set_shader_parameter("saturation", 1.0)
	shader_material.set_shader_parameter("contrast", 1.05)
	shader_material.set_shader_parameter("brightness", 1.0)
	shader_material.set_shader_parameter("tint_strength", 0.0)

	shader_material.set_shader_parameter("enable_dithering", true)
	shader_material.set_shader_parameter("dither_strength", 0.25)
	shader_material.set_shader_parameter("color_levels", 32.0)

	shader_material.set_shader_parameter("enable_aberration", false)
	shader_material.set_shader_parameter("enable_scanlines", false)


## Set individual parameters
func set_vignette(intensity: float, smoothness: float = 0.5) -> void:
	if shader_material:
		shader_material.set_shader_parameter("vignette_intensity", intensity)
		shader_material.set_shader_parameter("vignette_smoothness", smoothness)


func set_grain(strength: float) -> void:
	if shader_material:
		shader_material.set_shader_parameter("grain_strength", strength)


func set_saturation(value: float) -> void:
	if shader_material:
		shader_material.set_shader_parameter("saturation", value)


func set_brightness(value: float) -> void:
	if shader_material:
		shader_material.set_shader_parameter("brightness", value)


func set_contrast(value: float) -> void:
	if shader_material:
		shader_material.set_shader_parameter("contrast", value)


## Toggle post-processing on/off
func toggle() -> void:
	enabled = not enabled


## Cycle through presets
func cycle_preset() -> void:
	var next_preset: int = (current_preset + 1) % 3
	apply_preset(next_preset as Preset)
	print("[PostProcess] Switched to preset: %s" % Preset.keys()[current_preset])
