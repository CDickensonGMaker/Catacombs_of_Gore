## game_manager.gd - Central game state management
extends Node

signal game_paused
signal game_resumed
signal time_of_day_changed(new_time: Enums.TimeOfDay)
signal day_changed(new_day: int)
signal weather_changed(new_weather: Enums.Weather)
signal player_died

## Current player character data
var player_data: CharacterData

## Game time tracking (in-game hours)
var game_time: float = 8.0  # Start at 8 AM
var time_scale: float = 60.0  # 1 real second = 1 game minute

## Day tracking
var current_day: int = 1  # Start on Day 1

## Current time of day
var current_time_of_day: Enums.TimeOfDay = Enums.TimeOfDay.MORNING

## Current weather
var current_weather: Enums.Weather = Enums.Weather.CLEAR

## Game state
var is_paused: bool = false
var is_in_menu: bool = false
var is_in_dialogue: bool = false
var is_in_combat: bool = false

## Difficulty settings
var damage_multiplier: float = 1.0  # Damage TO player
var enemy_hp_multiplier: float = 1.0

## Debug mode
var debug_mode: bool = false

func _ready() -> void:
	# Set default UI scale to 68%
	get_tree().root.content_scale_factor = 0.68

	# Create default player data if none exists
	if not player_data:
		player_data = CharacterData.new()
		player_data.recalculate_derived_stats()
		player_data.current_hp = player_data.max_hp
		player_data.current_stamina = player_data.max_stamina

func _process(delta: float) -> void:
	if is_paused or is_in_menu:
		return

	_update_game_time(delta)

func _update_game_time(delta: float) -> void:
	# Advance game time
	game_time += (delta * time_scale) / 3600.0  # Convert to hours

	# Wrap around at 24 hours and advance day
	if game_time >= 24.0:
		game_time -= 24.0
		current_day += 1
		day_changed.emit(current_day)

	# Update time of day
	var new_time := _get_time_of_day()
	if new_time != current_time_of_day:
		current_time_of_day = new_time
		time_of_day_changed.emit(current_time_of_day)

func _get_time_of_day() -> Enums.TimeOfDay:
	if game_time >= 5.0 and game_time < 7.0:
		return Enums.TimeOfDay.DAWN
	elif game_time >= 7.0 and game_time < 11.0:
		return Enums.TimeOfDay.MORNING
	elif game_time >= 11.0 and game_time < 14.0:
		return Enums.TimeOfDay.NOON
	elif game_time >= 14.0 and game_time < 18.0:
		return Enums.TimeOfDay.AFTERNOON
	elif game_time >= 18.0 and game_time < 21.0:
		return Enums.TimeOfDay.DUSK
	elif game_time >= 21.0 or game_time < 1.0:
		return Enums.TimeOfDay.NIGHT
	else:
		return Enums.TimeOfDay.MIDNIGHT

## Get formatted time string (e.g., "8:30 AM")
func get_time_string() -> String:
	var hour := int(game_time)
	var minute := int((game_time - hour) * 60)
	var am_pm := "AM" if hour < 12 else "PM"
	var display_hour := hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%d:%02d %s" % [display_hour, minute, am_pm]

## Get time of day name
func get_time_of_day_name() -> String:
	match current_time_of_day:
		Enums.TimeOfDay.DAWN: return "Dawn"
		Enums.TimeOfDay.MORNING: return "Morning"
		Enums.TimeOfDay.NOON: return "Noon"
		Enums.TimeOfDay.AFTERNOON: return "Afternoon"
		Enums.TimeOfDay.DUSK: return "Dusk"
		Enums.TimeOfDay.NIGHT: return "Night"
		Enums.TimeOfDay.MIDNIGHT: return "Midnight"
		_: return "Unknown"

## Check if it's currently night (for gameplay purposes)
func is_night() -> bool:
	return current_time_of_day == Enums.TimeOfDay.NIGHT or current_time_of_day == Enums.TimeOfDay.MIDNIGHT

## Advance time by a specific number of hours
func advance_time(hours: float) -> void:
	var old_day := current_day
	game_time += hours

	# Handle day rollover
	while game_time >= 24.0:
		game_time -= 24.0
		current_day += 1

	# Emit day changed if day advanced
	if current_day != old_day:
		day_changed.emit(current_day)

	# Update time of day
	var new_time := _get_time_of_day()
	if new_time != current_time_of_day:
		current_time_of_day = new_time
		time_of_day_changed.emit(current_time_of_day)

## Rest until morning (6 AM) - returns hours slept
func rest_until_morning() -> float:
	var target_hour := 6.0  # Wake up at 6 AM
	var hours_slept: float

	if game_time < target_hour:
		# Still same day, just advance to morning
		hours_slept = target_hour - game_time
	else:
		# Sleep through to next morning
		hours_slept = (24.0 - game_time) + target_hour
		current_day += 1
		day_changed.emit(current_day)

	game_time = target_hour

	# Update time of day
	var new_time := _get_time_of_day()
	if new_time != current_time_of_day:
		current_time_of_day = new_time
		time_of_day_changed.emit(current_time_of_day)

	return hours_slept

## Set time directly (for debugging or special events)
func set_time(hour: float, day: int = -1) -> void:
	game_time = clampf(hour, 0.0, 23.99)
	if day > 0:
		current_day = day
		day_changed.emit(current_day)

	var new_time := _get_time_of_day()
	if new_time != current_time_of_day:
		current_time_of_day = new_time
		time_of_day_changed.emit(current_time_of_day)

## Set weather
func set_weather(weather: Enums.Weather) -> void:
	if weather != current_weather:
		current_weather = weather
		weather_changed.emit(current_weather)

## Pause the game
func pause_game() -> void:
	is_paused = true
	get_tree().paused = true
	game_paused.emit()

## Resume the game
func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	game_resumed.emit()

## Toggle pause
func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()

## Enter menu (doesn't fully pause, just flags)
func enter_menu() -> void:
	is_in_menu = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

## Exit menu
func exit_menu() -> void:
	is_in_menu = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Start dialogue - pauses game world
func start_dialogue() -> void:
	is_in_dialogue = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

## End dialogue - resumes game world
func end_dialogue() -> void:
	is_in_dialogue = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Check if player can act (not in menu/dialogue/paused)
func can_player_act() -> bool:
	return not is_paused and not is_in_menu and not is_in_dialogue

## Handle player death
func on_player_death() -> void:
	player_died.emit()
	# Death screen is handled by HUD

## Reset game state for a new game (called from death screen "New Game")
func reset_for_new_game() -> void:
	# Create fresh player data
	player_data = CharacterData.new()
	player_data.recalculate_derived_stats()
	player_data.current_hp = player_data.max_hp
	player_data.current_stamina = player_data.max_stamina
	player_data.current_mana = player_data.max_mana

	# Reset game state
	game_time = 8.0
	current_time_of_day = Enums.TimeOfDay.MORNING
	current_weather = Enums.Weather.CLEAR
	is_paused = false
	is_in_menu = false
	is_in_dialogue = false
	is_in_combat = false

## Create a new character
func create_new_character(char_name: String, race: Enums.Race, career: Enums.Career) -> void:
	player_data = CharacterData.new()
	player_data.character_name = char_name
	player_data.race = race
	player_data.career = career
	player_data.initialize_race_bonuses()
	player_data.initialize_career()
	player_data.recalculate_derived_stats()
	player_data.current_hp = player_data.max_hp
	player_data.current_stamina = player_data.max_stamina

## Get weather effects
func get_weather_effects() -> Dictionary:
	var effects := {
		"fire_resistance_bonus": 0.0,
		"frost_damage_bonus": 0.0,
		"movement_penalty": 0.0,
		"visibility_range": 100.0
	}

	match current_weather:
		Enums.Weather.RAIN:
			effects.fire_resistance_bonus = 0.25
			effects.visibility_range = 60.0
		Enums.Weather.STORM:
			effects.fire_resistance_bonus = 0.5
			effects.visibility_range = 40.0
		Enums.Weather.SNOW:
			effects.frost_damage_bonus = 0.25
			effects.movement_penalty = 0.2
			effects.visibility_range = 50.0
		Enums.Weather.FOG:
			effects.visibility_range = 20.0

	return effects
