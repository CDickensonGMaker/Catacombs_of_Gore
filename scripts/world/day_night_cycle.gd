## day_night_cycle.gd - Visual day/night cycle based on GameManager time
## Add this to any level that should have dynamic lighting
class_name DayNightCycle
extends Node3D

## The directional light (sun/moon)
var sun_light: DirectionalLight3D

## The world environment
var world_environment: WorldEnvironment

## PS1-style distance fog settings (tight visibility for retro feel)
const FOG_START := 8.0    # Distance where fog begins (units)
const FOG_END := 15.0     # Distance where fog is fully opaque (units)

## Light colors for different times of day
const DAWN_COLOR := Color(1.0, 0.7, 0.5)       # Warm orange sunrise
const MORNING_COLOR := Color(1.0, 0.95, 0.9)   # Bright warm white
const NOON_COLOR := Color(1.0, 1.0, 1.0)       # Pure white sun
const AFTERNOON_COLOR := Color(1.0, 0.95, 0.85) # Slightly warm
const DUSK_COLOR := Color(1.0, 0.5, 0.3)       # Deep orange sunset
const NIGHT_COLOR := Color(0.3, 0.35, 0.5)     # Cool blue moonlight
const MIDNIGHT_COLOR := Color(0.15, 0.18, 0.3) # Deep blue darkness

## Light intensities for different times
const DAWN_ENERGY := 0.6
const MORNING_ENERGY := 0.9
const NOON_ENERGY := 1.2
const AFTERNOON_ENERGY := 1.0
const DUSK_ENERGY := 0.5
const NIGHT_ENERGY := 0.2
const MIDNIGHT_ENERGY := 0.1

## Ambient light colors
const DAWN_AMBIENT := Color(0.4, 0.35, 0.3)
const MORNING_AMBIENT := Color(0.5, 0.5, 0.5)
const NOON_AMBIENT := Color(0.6, 0.6, 0.6)
const AFTERNOON_AMBIENT := Color(0.5, 0.5, 0.5)
const DUSK_AMBIENT := Color(0.35, 0.3, 0.35)
const NIGHT_AMBIENT := Color(0.15, 0.15, 0.25)
const MIDNIGHT_AMBIENT := Color(0.08, 0.08, 0.15)

## PS1-style fog colors (match ambient but slightly muted)
const DAWN_FOG := Color(0.5, 0.4, 0.35)
const MORNING_FOG := Color(0.55, 0.55, 0.6)
const NOON_FOG := Color(0.6, 0.65, 0.7)
const AFTERNOON_FOG := Color(0.55, 0.55, 0.55)
const DUSK_FOG := Color(0.4, 0.3, 0.35)
const NIGHT_FOG := Color(0.12, 0.12, 0.2)
const MIDNIGHT_FOG := Color(0.06, 0.06, 0.12)

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

## Current target values
var target_color: Color = MORNING_COLOR
var target_energy: float = MORNING_ENERGY
var target_ambient: Color = MORNING_AMBIENT
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
	# Create directional light if not exists
	sun_light = DirectionalLight3D.new()
	sun_light.name = "SunMoonLight"
	sun_light.light_color = MORNING_COLOR
	sun_light.light_energy = MORNING_ENERGY
	sun_light.shadow_enabled = true
	sun_light.shadow_bias = 0.1
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun_light.rotation_degrees = Vector3(-30, -45, 0)
	add_child(sun_light)

	# Create world environment if not exists in scene
	var existing_env := get_tree().get_first_node_in_group("world_environment")
	if existing_env and existing_env is WorldEnvironment:
		world_environment = existing_env
	else:
		world_environment = WorldEnvironment.new()
		world_environment.name = "DayNightEnvironment"
		world_environment.add_to_group("world_environment")

		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.3, 0.4, 0.5)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = MORNING_AMBIENT
		env.ambient_light_energy = 0.5
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

		# PS1-style depth-based distance fog
		env.fog_enabled = true
		env.fog_light_color = MORNING_FOG
		env.fog_light_energy = 1.0
		env.fog_sun_scatter = 0.0  # No sun scattering for cleaner PS1 look
		env.fog_density = 0.0  # Disable density fog
		env.fog_aerial_perspective = 0.0  # No aerial perspective
		env.fog_sky_affect = 1.0  # Fog affects sky too
		env.fog_depth_curve = 1.0  # Linear falloff
		env.fog_depth_begin = FOG_START  # Fog starts at 20 units
		env.fog_depth_end = FOG_END  # Fully opaque at 40 units
		env.volumetric_fog_enabled = false

		world_environment.environment = env
		add_child(world_environment)

func _process(delta: float) -> void:
	if not sun_light:
		return

	# Smoothly interpolate to target values
	sun_light.light_color = sun_light.light_color.lerp(target_color, delta * transition_speed)
	sun_light.light_energy = lerpf(sun_light.light_energy, target_energy, delta * transition_speed)

	# Interpolate sun angle
	var current_angle := sun_light.rotation_degrees.x
	sun_light.rotation_degrees.x = lerpf(current_angle, target_angle, delta * transition_speed)

	# Update environment ambient
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.ambient_light_color = env.ambient_light_color.lerp(target_ambient, delta * transition_speed)

		# Update background color to match ambient
		env.background_color = env.background_color.lerp(target_ambient * 0.8, delta * transition_speed)

		# Update PS1-style fog color
		env.fog_light_color = env.fog_light_color.lerp(target_fog, delta * transition_speed)

func _apply_lighting_instant() -> void:
	if sun_light:
		sun_light.light_color = target_color
		sun_light.light_energy = target_energy
		sun_light.rotation_degrees.x = target_angle

	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.ambient_light_color = target_ambient
		env.background_color = target_ambient * 0.8
		env.fog_light_color = target_fog

func _on_time_of_day_changed(time_of_day: Enums.TimeOfDay) -> void:
	match time_of_day:
		Enums.TimeOfDay.DAWN:
			target_color = DAWN_COLOR
			target_energy = DAWN_ENERGY
			target_ambient = DAWN_AMBIENT
			target_angle = DAWN_ANGLE
			target_fog = DAWN_FOG
		Enums.TimeOfDay.MORNING:
			target_color = MORNING_COLOR
			target_energy = MORNING_ENERGY
			target_ambient = MORNING_AMBIENT
			target_angle = MORNING_ANGLE
			target_fog = MORNING_FOG
		Enums.TimeOfDay.NOON:
			target_color = NOON_COLOR
			target_energy = NOON_ENERGY
			target_ambient = NOON_AMBIENT
			target_angle = NOON_ANGLE
			target_fog = NOON_FOG
		Enums.TimeOfDay.AFTERNOON:
			target_color = AFTERNOON_COLOR
			target_energy = AFTERNOON_ENERGY
			target_ambient = AFTERNOON_AMBIENT
			target_angle = AFTERNOON_ANGLE
			target_fog = AFTERNOON_FOG
		Enums.TimeOfDay.DUSK:
			target_color = DUSK_COLOR
			target_energy = DUSK_ENERGY
			target_ambient = DUSK_AMBIENT
			target_angle = DUSK_ANGLE
			target_fog = DUSK_FOG
		Enums.TimeOfDay.NIGHT:
			target_color = NIGHT_COLOR
			target_energy = NIGHT_ENERGY
			target_ambient = NIGHT_AMBIENT
			target_angle = NIGHT_ANGLE
			target_fog = NIGHT_FOG
		Enums.TimeOfDay.MIDNIGHT:
			target_color = MIDNIGHT_COLOR
			target_energy = MIDNIGHT_ENERGY
			target_ambient = MIDNIGHT_AMBIENT
			target_angle = MIDNIGHT_ANGLE
			target_fog = MIDNIGHT_FOG

## Static spawner for adding to levels
static func add_to_level(parent: Node) -> DayNightCycle:
	var cycle := DayNightCycle.new()
	cycle.name = "DayNightCycle"
	parent.add_child(cycle)
	return cycle
