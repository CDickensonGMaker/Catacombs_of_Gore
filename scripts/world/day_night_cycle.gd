## day_night_cycle.gd - Visual day/night cycle based on GameManager time
## Add this to any level that should have dynamic lighting
## GRIM DARK / DARK FANTASY aesthetic - muted colors, heavy atmosphere
class_name DayNightCycle
extends Node3D

## The directional light (sun/moon)
var sun_light: DirectionalLight3D

## The world environment
var world_environment: WorldEnvironment

## PS1-style distance fog settings (tight visibility for retro feel)
const FOG_START := 8.0     # Distance where fog begins (units) - closer for heavier fog
const FOG_END := 35.0      # Distance where fog is fully opaque (units) - tighter visibility

## ============================================================================
## GRIM DARK COLOR PALETTE - Muted, desaturated, atmospheric
## ============================================================================

## Light colors for different times of day (desaturated, muted tones)
const DAWN_COLOR := Color(0.75, 0.55, 0.45)     # Muted rust/amber sunrise
const MORNING_COLOR := Color(0.85, 0.8, 0.7)    # Pale overcast white
const NOON_COLOR := Color(0.9, 0.88, 0.82)      # Slightly warm grey-white (not pure white)
const AFTERNOON_COLOR := Color(0.8, 0.75, 0.65) # Dusty amber
const DUSK_COLOR := Color(0.7, 0.4, 0.3)        # Blood red sunset
const NIGHT_COLOR := Color(0.25, 0.28, 0.4)     # Cold blue moonlight
const MIDNIGHT_COLOR := Color(0.12, 0.14, 0.22) # Deep oppressive darkness

## Light intensities - significantly reduced for darker feel
const DAWN_ENERGY := 0.4
const MORNING_ENERGY := 0.6
const NOON_ENERGY := 0.75      # Even noon is not too bright
const AFTERNOON_ENERGY := 0.6
const DUSK_ENERGY := 0.35
const NIGHT_ENERGY := 0.06     # Much darker at night
const MIDNIGHT_ENERGY := 0.03  # Nearly pitch black at midnight

## Ambient light colors - darker, more oppressive
const DAWN_AMBIENT := Color(0.25, 0.22, 0.2)
const MORNING_AMBIENT := Color(0.32, 0.3, 0.28)
const NOON_AMBIENT := Color(0.38, 0.36, 0.32)   # Grey-brown, not bright
const AFTERNOON_AMBIENT := Color(0.32, 0.28, 0.25)
const DUSK_AMBIENT := Color(0.22, 0.18, 0.2)
const NIGHT_AMBIENT := Color(0.04, 0.04, 0.06)  # Much darker ambient at night
const MIDNIGHT_AMBIENT := Color(0.02, 0.02, 0.03)  # Nearly no ambient at midnight

## PS1-style fog colors - cold grey, oppressive atmosphere
const DAWN_FOG := Color(0.3, 0.28, 0.28)        # Grey with slight warmth
const MORNING_FOG := Color(0.32, 0.32, 0.32)    # Neutral grey mist
const NOON_FOG := Color(0.35, 0.35, 0.33)       # Grey haze
const AFTERNOON_FOG := Color(0.32, 0.3, 0.3)    # Cooling grey
const DUSK_FOG := Color(0.22, 0.2, 0.22)        # Dark grey-purple
const NIGHT_FOG := Color(0.06, 0.06, 0.1)       # Deep blue-grey
const MIDNIGHT_FOG := Color(0.03, 0.03, 0.05)   # Near black

## Sun rotation angles (degrees from horizon)
const DAWN_ANGLE := -10.0       # Just below horizon
const MORNING_ANGLE := 30.0     # Rising
const NOON_ANGLE := 70.0        # High in sky
const AFTERNOON_ANGLE := 45.0   # Descending
const DUSK_ANGLE := 5.0         # Near horizon
const NIGHT_ANGLE := -30.0      # Below horizon (moonlight from opposite)
const MIDNIGHT_ANGLE := -45.0   # Deep below

## Transition speed (how fast lighting changes)
@export var transition_speed: float = 2.0

## Ambient light energy values for each time period
const DAWN_AMBIENT_ENERGY := 0.25
const MORNING_AMBIENT_ENERGY := 0.35
const NOON_AMBIENT_ENERGY := 0.4
const AFTERNOON_AMBIENT_ENERGY := 0.35
const DUSK_AMBIENT_ENERGY := 0.2
const NIGHT_AMBIENT_ENERGY := 0.08   # Very dark ambient at night
const MIDNIGHT_AMBIENT_ENERGY := 0.03  # Nearly no ambient at midnight

## Current target values
var target_color: Color = MORNING_COLOR
var target_energy: float = MORNING_ENERGY
var target_ambient: Color = MORNING_AMBIENT
var target_ambient_energy: float = MORNING_AMBIENT_ENERGY
var target_angle: float = MORNING_ANGLE
var target_fog: Color = MORNING_FOG

func _ready() -> void:
	_setup_lighting()

	# Connect to time changes
	GameManager.time_of_day_changed.connect(_on_time_of_day_changed)

	# Set initial state based on current time
	_on_time_of_day_changed(GameManager.current_time_of_day)

	# Apply immediately on start
	_apply_lighting_instant()

func _setup_lighting() -> void:
	# Remove any existing static DirectionalLight3D in the parent scene to avoid conflicts
	# Static lights override dynamic day/night cycle
	var parent_node: Node = get_parent()
	if parent_node:
		for child in parent_node.get_children():
			if child is DirectionalLight3D and child != self:
				print("[DayNightCycle] Removing static DirectionalLight3D '%s' to enable dynamic lighting" % child.name)
				child.queue_free()

	# Create our dynamic directional light (sun/moon)
	sun_light = DirectionalLight3D.new()
	sun_light.name = "SunMoonLight"
	sun_light.light_color = MORNING_COLOR
	sun_light.light_energy = MORNING_ENERGY
	sun_light.shadow_enabled = true
	sun_light.shadow_bias = 0.1
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun_light.rotation_degrees = Vector3(-30, -45, 0)
	add_child(sun_light)

	# Find existing world environment in scene (must be in "world_environment" group)
	# If found, we'll modify it dynamically. If not, we create our own.
	var existing_env := get_tree().get_first_node_in_group("world_environment")
	if existing_env and existing_env is WorldEnvironment:
		world_environment = existing_env
		_apply_grim_dark_postprocess(world_environment.environment)
		return

	# Also check for any WorldEnvironment not in the group (common in hand-crafted scenes)
	# and add it to the group so we can control it
	var scene_env: WorldEnvironment = null
	if parent_node:
		for child in parent_node.get_children():
			if child is WorldEnvironment:
				scene_env = child
				break

	if scene_env:
		# Found an existing WorldEnvironment, use it
		scene_env.add_to_group("world_environment")
		world_environment = scene_env
		_apply_grim_dark_postprocess(world_environment.environment)
		print("[DayNightCycle] Using existing WorldEnvironment from scene")
		return

	# No existing environment found, create a completely new one
	world_environment = WorldEnvironment.new()
	world_environment.name = "DayNightEnvironment"
	world_environment.add_to_group("world_environment")

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.15, 0.12, 0.1)  # Dark murky background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = MORNING_AMBIENT
	env.ambient_light_energy = 0.3  # Low ambient for darker, moodier feel

	# ====================================================================
	# GRIM DARK TONEMAPPING - Crushed blacks, muted highlights
	# ====================================================================
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85  # Slightly underexposed
	env.tonemap_white = 1.2  # Compress highlights

	# ====================================================================
	# PS1-STYLE ATMOSPHERIC FOG - Heavy, oppressive
	# ====================================================================
	env.fog_enabled = true
	env.fog_light_color = MORNING_FOG
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0  # No sun scattering for cleaner PS1 look
	env.fog_density = 0.02  # Heavier fog density for oppressive atmosphere
	env.fog_aerial_perspective = 0.0  # No aerial perspective
	env.fog_sky_affect = 1.0  # Fog affects sky too
	env.fog_depth_curve = 1.2  # Slightly curved for more gradual falloff
	env.fog_depth_begin = FOG_START
	env.fog_depth_end = FOG_END
	env.volumetric_fog_enabled = false

	# ====================================================================
	# COLOR GRADING - Desaturated, grim dark look
	# ====================================================================
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.82  # Darker overall for grim atmosphere
	env.adjustment_contrast = 1.2  # More contrast for that gritty look
	env.adjustment_saturation = 0.6  # More desaturated - mutes colors significantly

	# ====================================================================
	# GLOW - Subtle, for atmosphere (not bright bloom)
	# ====================================================================
	env.glow_enabled = true
	env.glow_intensity = 0.3  # Subtle glow
	env.glow_strength = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.2  # Only very bright things glow
	env.glow_hdr_scale = 1.5

	world_environment.environment = env
	add_child(world_environment)


## Apply grim dark post-processing to an existing environment
func _apply_grim_dark_postprocess(env: Environment) -> void:
	if not env:
		return

	# Tonemapping
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.tonemap_white = 1.2

	# Color grading - the key to grim dark aesthetic
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.92
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 0.7  # This is what kills the bright greens

	# Subtle glow
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_strength = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.2
	env.glow_hdr_scale = 1.5

func _process(delta: float) -> void:
	if not sun_light:
		return

	# Calculate sun angle based on actual game time (continuous movement)
	var sun_angle: float = _calculate_sun_angle_from_time(GameManager.game_time)

	# Smoothly interpolate to target values
	sun_light.light_color = sun_light.light_color.lerp(target_color, delta * transition_speed)
	sun_light.light_energy = lerpf(sun_light.light_energy, target_energy, delta * transition_speed)

	# Interpolate sun angle toward calculated position
	var current_angle := sun_light.rotation_degrees.x
	sun_light.rotation_degrees.x = lerpf(current_angle, sun_angle, delta * transition_speed)

	# Update environment ambient
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.ambient_light_color = env.ambient_light_color.lerp(target_ambient, delta * transition_speed)

		# Update ambient light ENERGY - this is critical for dark nights!
		env.ambient_light_energy = lerpf(env.ambient_light_energy, target_ambient_energy, delta * transition_speed)

		# Update background color to match ambient
		env.background_color = env.background_color.lerp(target_ambient * 0.8, delta * transition_speed)

		# Update PS1-style fog color
		env.fog_light_color = env.fog_light_color.lerp(target_fog, delta * transition_speed)


## Calculate sun angle based on actual game time (0-24 hours)
## Returns continuous angle from below horizon at night to peak at noon
func _calculate_sun_angle_from_time(game_time: float) -> float:
	# Time periods and their sun angles
	# Dawn: 5-7, Morning: 7-10, Noon: 10-14, Afternoon: 14-17, Dusk: 17-20, Night: 20-5
	var time := fmod(game_time, 24.0)

	# Define keyframes: [time, angle]
	var keyframes: Array[Array] = [
		[0.0, MIDNIGHT_ANGLE],   # Midnight
		[5.0, DAWN_ANGLE],       # Dawn start
		[7.0, MORNING_ANGLE],    # Morning start
		[10.0, NOON_ANGLE],      # Approaching noon
		[12.0, NOON_ANGLE],      # Solar noon (peak)
		[14.0, AFTERNOON_ANGLE], # Afternoon start
		[17.0, DUSK_ANGLE],      # Dusk start
		[20.0, NIGHT_ANGLE],     # Night start
		[24.0, MIDNIGHT_ANGLE],  # Back to midnight
	]

	# Find which two keyframes we're between and interpolate
	for i in range(keyframes.size() - 1):
		var kf1: Array = keyframes[i]
		var kf2: Array = keyframes[i + 1]
		var t1: float = kf1[0]
		var t2: float = kf2[0]
		var a1: float = kf1[1]
		var a2: float = kf2[1]

		if time >= t1 and time < t2:
			var t: float = (time - t1) / (t2 - t1)
			return lerpf(a1, a2, t)

	# Fallback (should not reach)
	return MIDNIGHT_ANGLE

func _apply_lighting_instant() -> void:
	if sun_light:
		sun_light.light_color = target_color
		sun_light.light_energy = target_energy
		# Use actual time-based sun angle instead of period target
		sun_light.rotation_degrees.x = _calculate_sun_angle_from_time(GameManager.game_time)

	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.ambient_light_color = target_ambient
		env.ambient_light_energy = target_ambient_energy
		env.background_color = target_ambient * 0.8
		env.fog_light_color = target_fog

func _on_time_of_day_changed(time_of_day: Enums.TimeOfDay) -> void:
	match time_of_day:
		Enums.TimeOfDay.DAWN:
			target_color = DAWN_COLOR
			target_energy = DAWN_ENERGY
			target_ambient = DAWN_AMBIENT
			target_ambient_energy = DAWN_AMBIENT_ENERGY
			target_angle = DAWN_ANGLE
			target_fog = DAWN_FOG
		Enums.TimeOfDay.MORNING:
			target_color = MORNING_COLOR
			target_energy = MORNING_ENERGY
			target_ambient = MORNING_AMBIENT
			target_ambient_energy = MORNING_AMBIENT_ENERGY
			target_angle = MORNING_ANGLE
			target_fog = MORNING_FOG
		Enums.TimeOfDay.NOON:
			target_color = NOON_COLOR
			target_energy = NOON_ENERGY
			target_ambient = NOON_AMBIENT
			target_ambient_energy = NOON_AMBIENT_ENERGY
			target_angle = NOON_ANGLE
			target_fog = NOON_FOG
		Enums.TimeOfDay.AFTERNOON:
			target_color = AFTERNOON_COLOR
			target_energy = AFTERNOON_ENERGY
			target_ambient = AFTERNOON_AMBIENT
			target_ambient_energy = AFTERNOON_AMBIENT_ENERGY
			target_angle = AFTERNOON_ANGLE
			target_fog = AFTERNOON_FOG
		Enums.TimeOfDay.DUSK:
			target_color = DUSK_COLOR
			target_energy = DUSK_ENERGY
			target_ambient = DUSK_AMBIENT
			target_ambient_energy = DUSK_AMBIENT_ENERGY
			target_angle = DUSK_ANGLE
			target_fog = DUSK_FOG
		Enums.TimeOfDay.NIGHT:
			target_color = NIGHT_COLOR
			target_energy = NIGHT_ENERGY
			target_ambient = NIGHT_AMBIENT
			target_ambient_energy = NIGHT_AMBIENT_ENERGY
			target_angle = NIGHT_ANGLE
			target_fog = NIGHT_FOG
		Enums.TimeOfDay.MIDNIGHT:
			target_color = MIDNIGHT_COLOR
			target_energy = MIDNIGHT_ENERGY
			target_ambient = MIDNIGHT_AMBIENT
			target_ambient_energy = MIDNIGHT_AMBIENT_ENERGY
			target_angle = MIDNIGHT_ANGLE
			target_fog = MIDNIGHT_FOG

## Static spawner for adding to levels
static func add_to_level(parent: Node) -> DayNightCycle:
	var cycle := DayNightCycle.new()
	cycle.name = "DayNightCycle"
	parent.add_child(cycle)
	return cycle


## Force DayNightCycle to take over lighting (removes existing lights)
## Use this when entering hand-crafted areas that may have their own static lighting
static func force_takeover(parent: Node) -> DayNightCycle:
	# Remove any existing WorldEnvironment and DirectionalLight3D
	for child in parent.get_children():
		if child is WorldEnvironment:
			child.queue_free()
		elif child is DirectionalLight3D:
			child.queue_free()

	# Also check for existing DayNightCycle and remove it
	var existing_cycle: Node = parent.get_node_or_null("DayNightCycle")
	if existing_cycle:
		existing_cycle.queue_free()

	# Create fresh DayNightCycle
	var cycle := DayNightCycle.new()
	cycle.name = "DayNightCycle"
	parent.add_child(cycle)
	return cycle
