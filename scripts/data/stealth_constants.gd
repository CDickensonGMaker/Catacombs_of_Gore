## stealth_constants.gd - Visibility formulas and stealth constants
class_name StealthConstants

## Visibility thresholds
const HIDDEN_THRESHOLD: float = 0.3  # Below this = hidden (HUD indicator shows)
const UNDETECTABLE_THRESHOLD: float = 0.15  # Below this = cannot be detected at all

## Visibility base values
const BASE_VISIBILITY: float = 1.0
const CROUCH_VISIBILITY_MULT: float = 0.6  # Crouching reduces visibility by 40%
const MOVING_VISIBILITY_MULT: float = 1.3  # Moving increases visibility by 30%
const SPRINTING_VISIBILITY_MULT: float = 1.5  # Sprinting increases visibility by 50%
const STEALTH_SKILL_REDUCTION: float = 0.05  # -5% visibility per stealth skill level

## Light level multipliers (applied to final visibility)
const BRIGHT_LIGHT_MULT: float = 1.2  # Torch, daylight, magic light
const DIM_LIGHT_MULT: float = 0.7  # Dusk, indoor without torch
const DARKNESS_MULT: float = 0.4  # Night, caves without light

## Enemy awareness thresholds and rates
const ALERT_THRESHOLD: float = 0.3  # Awareness level to become alerted
const COMBAT_THRESHOLD: float = 0.7  # Awareness level to enter combat
const AWARENESS_BUILD_RATE_BASE: float = 0.5  # Base rate per second
const AWARENESS_DECAY_RATE: float = 0.2  # Decay when not seeing player

## Detection range modifiers
const BASE_DETECTION_RANGE: float = 15.0
const CROUCHING_DETECTION_RANGE_MULT: float = 0.5  # Halve detection range when crouching
const DARKNESS_DETECTION_RANGE_MULT: float = 0.6  # Reduced range in darkness

## Backstab bonuses
const STEALTH_BACKSTAB_BASE_MULT: float = 2.0  # Base backstab damage multiplier when hidden
const STEALTH_BACKSTAB_PER_SKILL: float = 0.15  # Additional +15% per stealth skill level

## Calculate player visibility based on current state
static func calculate_visibility(
	is_crouching: bool,
	is_moving: bool,
	is_sprinting: bool,
	stealth_skill: int,
	light_level: float  # 0.0 = darkness, 0.5 = dim, 1.0 = bright
) -> float:
	var vis: float = BASE_VISIBILITY

	# Apply crouch modifier
	if is_crouching:
		vis *= CROUCH_VISIBILITY_MULT

	# Apply movement modifiers (only one applies - highest)
	if is_sprinting:
		vis *= SPRINTING_VISIBILITY_MULT
	elif is_moving:
		vis *= MOVING_VISIBILITY_MULT

	# Apply stealth skill reduction
	vis *= (1.0 - stealth_skill * STEALTH_SKILL_REDUCTION)

	# Apply light level modifier
	var light_mult: float
	if light_level >= 0.8:
		light_mult = BRIGHT_LIGHT_MULT
	elif light_level >= 0.4:
		light_mult = lerpf(DIM_LIGHT_MULT, BRIGHT_LIGHT_MULT, (light_level - 0.4) / 0.4)
	else:
		light_mult = lerpf(DARKNESS_MULT, DIM_LIGHT_MULT, light_level / 0.4)
	vis *= light_mult

	return clampf(vis, 0.0, 1.0)

## Calculate awareness build rate based on player visibility
static func get_awareness_build_rate(player_visibility: float) -> float:
	# Higher visibility = faster awareness buildup
	return AWARENESS_BUILD_RATE_BASE * player_visibility

## Calculate backstab damage multiplier for stealth attacks
static func get_stealth_backstab_multiplier(stealth_skill: int, is_hidden: bool) -> float:
	if not is_hidden:
		return 1.0  # No bonus if not hidden
	return STEALTH_BACKSTAB_BASE_MULT + (stealth_skill * STEALTH_BACKSTAB_PER_SKILL)

## Check if visibility level counts as "hidden"
static func is_hidden(visibility: float) -> bool:
	return visibility < HIDDEN_THRESHOLD

## Check if visibility level makes player undetectable
static func is_undetectable(visibility: float) -> bool:
	return visibility < UNDETECTABLE_THRESHOLD
