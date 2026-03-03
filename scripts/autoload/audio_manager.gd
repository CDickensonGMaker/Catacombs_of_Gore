## audio_manager.gd - Handles all audio playback with PS1-style compression feel
extends Node

## Audio buses
const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const AMBIENT_BUS := "Ambient"

## Standardized audio event names
## Use these constants when playing sounds to ensure consistency
const EVENTS := {
	# Player events
	"player_hit": "res://assets/audio/sfx/player_hit.wav",
	"player_attack": "res://assets/audio/sfx/player_attack.wav",

	# Melee weapon hit sounds (sword clanks)
	"melee_hit_1": "res://assets/audio/sfx/weapons/sword_clank_1.wav",
	"melee_hit_2": "res://assets/audio/sfx/weapons/sword_clank_2.wav",
	"melee_hit_3": "res://assets/audio/sfx/weapons/sword_clank_3.wav",

	# UI accept/click sound
	"ui_accept": "res://assets/audio/sfx/ui/Accepting_Click_Noise.wav",
	"player_death": "res://assets/audio/sfx/player_death.wav",
	"player_dodge": "res://assets/audio/sfx/player_dodge.wav",
	"player_block": "res://assets/audio/sfx/player_block.wav",
	"player_parry": "res://assets/audio/sfx/player_parry.wav",
	"player_stagger": "res://assets/audio/sfx/player_stagger.wav",
	"player_heal": "res://assets/audio/sfx/player_heal.wav",
	"player_level_up": "res://assets/audio/sfx/player_level_up.wav",

	# Enemy events
	"enemy_hit": "res://assets/audio/sfx/enemy_hit.wav",
	"enemy_death": "res://assets/audio/sfx/enemy_death.wav",
	"enemy_attack": "res://assets/audio/sfx/enemy_attack.wav",
	"enemy_alert": "res://assets/audio/sfx/enemy_alert.wav",
	"enemy_aggro": "res://assets/audio/sfx/enemy_aggro.wav",
	"enemy_stagger": "res://assets/audio/sfx/enemy_stagger.wav",
	"enemy_spawn": "res://assets/audio/sfx/enemy_spawn.wav",

	# Monster-specific sounds (wolves, beasts)
	"monster_growl_low": "res://assets/audio/sfx/monsters/low_growl.wav",
	"monster_growl_mid": "res://assets/audio/sfx/monsters/mid_growl.wav",
	# Goblin sounds
	"goblin_screech": "res://assets/audio/sfx/monsters/goblin_screech.wav",
	# Cultist sounds
	"cultist_chant_1": "res://assets/audio/sfx/monsters/cultist_1.wav",
	"cultist_chant_2": "res://assets/audio/sfx/monsters/cultist_2.wav",
	# Undead/skeleton sounds
	"undead_groan_1": "res://assets/audio/sfx/monsters/undead_1.wav",
	"undead_groan_2": "res://assets/audio/sfx/monsters/undead_2.wav",

	# Projectile events
	"projectile_fire": "res://assets/audio/sfx/projectile_fire.wav",
	"projectile_hit": "res://assets/audio/sfx/projectile_hit.wav",
	"projectile_miss": "res://assets/audio/sfx/projectile_miss.wav",
	"projectile_explode": "res://assets/audio/sfx/projectile_explode.wav",

	# Item events
	"item_pickup": "res://assets/audio/sfx/item_pickup.wav",
	"item_drop": "res://assets/audio/sfx/item_drop.wav",
	"item_use": "res://assets/audio/sfx/item_use.wav",
	"item_equip": "res://assets/audio/sfx/item_equip.wav",
	"item_unequip": "res://assets/audio/sfx/item_unequip.wav",
	"item_break": "res://assets/audio/sfx/item_break.wav",
	"gold_pickup": "res://assets/audio/sfx/gold_pickup.wav",

	# Menu/UI events
	"menu_open": "res://assets/audio/sfx/menu_open.wav",
	"menu_close": "res://assets/audio/sfx/menu_close.wav",
	"menu_select": "res://assets/audio/sfx/menu_select.wav",
	"menu_confirm": "res://assets/audio/sfx/menu_confirm.wav",
	"menu_cancel": "res://assets/audio/sfx/menu_cancel.wav",
	"menu_error": "res://assets/audio/sfx/menu_error.wav",
	"menu_hover": "res://assets/audio/sfx/menu_hover.wav",

	# Combat events
	"critical_hit": "res://assets/audio/sfx/critical_hit.wav",
	"miss": "res://assets/audio/sfx/miss.wav",
	"block": "res://assets/audio/sfx/block.wav",
	"parry": "res://assets/audio/sfx/parry.wav",

	# Spell events
	"spell_cast": "res://assets/audio/sfx/spell_cast.wav",
	"spell_fail": "res://assets/audio/sfx/spell_fail.wav",
	"spell_impact": "res://assets/audio/sfx/spell_impact.wav",

	# Environment/World events
	"door_open": "res://assets/audio/sfx/door_open.wav",
	"door_close": "res://assets/audio/sfx/door_close.wav",
	"door_locked": "res://assets/audio/sfx/door_locked.wav",
	"door_unlock": "res://assets/audio/sfx/door_unlock.wav",
	"chest_open": "res://assets/audio/sfx/chest_open.wav",
	"lever_pull": "res://assets/audio/sfx/lever_pull.wav",
	"secret_found": "res://assets/audio/sfx/secret_found.wav",
	"trap_trigger": "res://assets/audio/sfx/trap_trigger.wav",

	# Footstep events (by terrain)
	"footstep_stone": "res://assets/audio/sfx/footstep_stone.wav",
	"footstep_wood": "res://assets/audio/sfx/footstep_wood.wav",
	"footstep_grass": "res://assets/audio/sfx/footstep_grass.wav",
	"footstep_water": "res://assets/audio/sfx/footstep_water.wav",
	"footstep_metal": "res://assets/audio/sfx/footstep_metal.wav",
	"footstep_dirt": "res://assets/audio/sfx/footstep_dirt.wav",
	"footstep_generic": "res://assets/audio/sfx/walking and movement/footstep_1.wav",
	"footstep_loop": "res://assets/audio/sfx/walking and movement/footstep_1_walking_loop_long.wav",

	# Status effect events
	"effect_poison": "res://assets/audio/sfx/effect_poison.wav",
	"effect_burn": "res://assets/audio/sfx/effect_burn.wav",
	"effect_freeze": "res://assets/audio/sfx/effect_freeze.wav",
	"effect_stun": "res://assets/audio/sfx/effect_stun.wav",
	"effect_bleed": "res://assets/audio/sfx/effect_bleed.wav",
	"effect_cure": "res://assets/audio/sfx/effect_cure.wav",

	# Notification events
	"quest_start": "res://assets/audio/sfx/quest_start.wav",
	"quest_complete": "res://assets/audio/sfx/quest_complete.wav",
	"quest_fail": "res://assets/audio/sfx/quest_fail.wav",
	"objective_complete": "res://assets/audio/sfx/objective_complete.wav",
	"save_game": "res://assets/audio/sfx/save_game.wav",
	"load_game": "res://assets/audio/sfx/load_game.wav",

	# NPC response sounds (conversation barks)
	"npc_male_hmm": "res://assets/audio/sfx/npc/npc_male_response_hmm.wav",
	"npc_male_yeah": "res://assets/audio/sfx/npc/npc_male_response_02 low yeeeh.wav",
	"npc_female_eyh": "res://assets/audio/sfx/npc/npc_female_response_01_eyyh.wav",
	"npc_female_response": "res://assets/audio/sfx/npc/npc_female_response_02_3s.wav",

	# Foraging sounds
	"wood_chop_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/foraging/wood_chop_01.wav",
	"wood_chop_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/foraging/wood_chop_02.wav",
	"wood_chop_3": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/foraging/wood_chop_03.wav",
	"wood_chop_heavy": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/foraging/wood_chop_heavy_01.wav",
	"bush_pick_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/foraging/bush_pick_01.wav",
	"bush_pick_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/foraging/bush_pick_02.wav",
	"bush_forage": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/foraging/bush_pick_forage_01.wav",

	# Blacksmith/Crafting sounds
	"anvil_hit_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_anvil_hit_01.wav",
	"anvil_hit_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_anvil_hit_02.wav",
	"anvil_hit_3": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_anvil_hit_03.wav",
	"anvil_hit_4": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_anvil_hit_04.wav",
	"metal_strike_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_hot_metal_strike_01.wav",
	"metal_strike_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_hot_metal_strike_02.wav",
	"metal_strike_3": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_hot_metal_strike_03.wav",
	"anvil_heavy_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_anvil_heavy_01.wav",
	"anvil_heavy_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_anvil_heavy_02.wav",
	"tongs_handle_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_tongs_handle_01.wav",
	"tongs_handle_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_tongs_handle_03.wav",

	# Enchanting sounds
	"enchant_charge": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/enchanting/enchant_charge_01.wav",
	"enchant_release": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/enchanting/enchant_cast_release_02.wav",
	"enchant_success_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/enchanting/enchant_success_01.wav",
	"enchant_success_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/enchanting/enchant_success_02.wav",
	"enchant_fail_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/enchanting/enchant_fail_01.wav",
	"enchant_fail_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/enchanting/enchant_fail_02.wav",
	"enchant_dark": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/enchanting/enchant_dark_01.wav",

	# Alchemy/Potion sounds
	"alchemy_clink": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/potion making/alchemy_glass_clink_01.wav",
	"alchemy_success": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/potion making/alchemy_potion_success_01.wav",

	# Cooking sounds
	"cooking_sizzle": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/cooking/cooking_crafting_pan_sizzle.wav",
	"cooking_chop": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/cooking/cooking_crafting_chop_prep.wav",
}

## Background music tracks
const MUSIC := {
	"menu": "res://assets/audio/background music/game_menu_intro_3min_medieval_trumpets_war_drums.wav",
	"village": "res://assets/audio/background music/general_game_music_village_120s_ps1_retro.wav",
	"wilderness": "res://assets/audio/background music/general_game_music_wilderness_120s_ps1_retro.wav",
	"dungeon": "res://assets/audio/background music/general_game_music_dungeon_lofi_120s_ps1_retro.wav",
	"ruins": "res://assets/audio/background music/ruins_game_music_dungeon_lofi_120s_v2_ps1_retro.wav",
}

## Ambient sound loops by zone type
const AMBIANCE := {
	"town": "res://assets/audio/Ambiance/towns/town_murmur_medieval_mix_60s_ps1_retro.wav",
	"port_city": "res://assets/audio/Ambiance/cities/port_city_1.wav",
	"ruins": "res://assets/audio/Ambiance/ruins/ruins_creepy_ambience.wav",
	"combat_arena_1": "res://assets/audio/Ambiance/combat arena/kling_20260303_Text_to_Audio_90s_retro__1451_1.wav",
	"combat_arena_2": "res://assets/audio/Ambiance/combat arena/kling_20260303_Text_to_Audio_90s_retro__1451_3.wav",
}

## Music players
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

## Dedicated crafting player (stops previous sound on new play, no overlap)
var crafting_player: AudioStreamPlayer

## SFX pool for overlapping sounds
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_pool_size: int = 16

## Volume settings (0-1 linear, stored as dB internally)
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 1.0
var ambient_volume: float = 0.5

## Current playing tracks
var current_music: String = ""
var current_ambient: String = ""

## Music fade
var fade_duration: float = 1.0
var is_fading: bool = false

## Sound cache
var sound_cache: Dictionary = {}

func _ready() -> void:
	_setup_audio_buses()
	_create_players()

func _setup_audio_buses() -> void:
	# Create audio buses if they don't exist
	# In a real project, you'd set these up in project settings
	pass

func _create_players() -> void:
	# Music player - keeps playing during pause (dialogue, menus)
	music_player = AudioStreamPlayer.new()
	music_player.bus = MUSIC_BUS
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)

	# Ambient player - keeps playing during pause
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = AMBIENT_BUS
	ambient_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ambient_player)

	# Crafting player - dedicated player for crafting sounds (stops previous on new play)
	crafting_player = AudioStreamPlayer.new()
	crafting_player.bus = SFX_BUS
	crafting_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(crafting_player)

	# SFX pool
	for i in range(sfx_pool_size):
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		sfx_pool.append(player)

## Play a sound effect
func play_sfx(sound_path: String, volume_db: float = 0.0, pitch_variance: float = 0.0) -> void:
	var stream := _load_sound(sound_path)
	if not stream:
		return

	var player := _get_free_sfx_player()
	if not player:
		return

	player.stream = stream
	player.volume_db = volume_db + _linear_to_db(sfx_volume)

	# Add pitch variance for variety
	if pitch_variance > 0:
		player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	else:
		player.pitch_scale = 1.0

	player.play()

## Play a 3D positioned sound
func play_sfx_3d(sound_path: String, position: Vector3, volume_db: float = 0.0) -> void:
	var stream := _load_sound(sound_path)
	if not stream:
		return

	# Create a temporary 3D player
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db + _linear_to_db(sfx_volume)
	player.bus = SFX_BUS

	# PS1-style: simple distance attenuation
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 5.0
	player.max_distance = 50.0

	get_tree().current_scene.add_child(player)
	player.global_position = position
	player.play()

	# Auto-cleanup
	player.finished.connect(player.queue_free)


## Play an enemy sound from their data arrays (attack_sounds, hurt_sounds, death_sounds)
## Returns true if a sound was played
func play_enemy_sound(sound_array: Array, position: Vector3, volume_db: float = 0.0) -> bool:
	if sound_array.is_empty():
		return false

	# Pick a random sound from the array
	var sound_path: String = sound_array[randi() % sound_array.size()]
	if sound_path.is_empty():
		return false

	play_sfx_3d(sound_path, position, volume_db)
	return true


## Play music with optional crossfade
func play_music(music_path: String, crossfade: bool = true) -> void:
	if music_path == current_music:
		return

	var stream := _load_sound(music_path)
	if not stream:
		return

	if crossfade and music_player.playing:
		_crossfade_music(stream)
	else:
		music_player.stream = stream
		music_player.volume_db = _linear_to_db(music_volume)
		music_player.play()

	current_music = music_path

## Stop music with fade
func stop_music(fade: bool = true) -> void:
	if not music_player.playing:
		return

	if fade:
		var tween := create_tween()
		tween.tween_property(music_player, "volume_db", -80.0, fade_duration)
		tween.tween_callback(music_player.stop)
	else:
		music_player.stop()

	current_music = ""


## Called when music finishes - restart to loop
func _on_music_finished() -> void:
	if current_music != "" and music_player:
		music_player.play()


## Play music for a specific zone type
## zone_type can be: "village", "wilderness", "dungeon", "ruins"
func play_zone_music(zone_type: String, crossfade: bool = true) -> void:
	if MUSIC.has(zone_type):
		play_music(MUSIC[zone_type], crossfade)
	else:
		# Default to wilderness for unknown zone types
		play_music(MUSIC["wilderness"], crossfade)


## Play ambient for a specific zone type
## zone_type can be: "town", "port_city", "ruins", "combat_arena"
func play_zone_ambiance(zone_type: String) -> void:
	if zone_type == "combat_arena":
		# Random arena ambient
		var arena_sounds: Array[String] = [AMBIANCE["combat_arena_1"], AMBIANCE["combat_arena_2"]]
		play_ambient(arena_sounds[randi() % arena_sounds.size()])
	elif AMBIANCE.has(zone_type):
		play_ambient(AMBIANCE[zone_type])
	else:
		# Default to town for unknown zone types
		play_ambient(AMBIANCE["town"])


## Play random NPC conversation bark sound
func play_npc_bark(is_female: bool = false, position: Vector3 = Vector3.ZERO, volume_db: float = -3.0) -> void:
	var sounds: Array[String] = []
	if is_female:
		sounds = [EVENTS["npc_female_eyh"], EVENTS["npc_female_response"]]
	else:
		sounds = [EVENTS["npc_male_hmm"], EVENTS["npc_male_yeah"]]

	var sound: String = sounds[randi() % sounds.size()]
	if position != Vector3.ZERO:
		play_sfx_3d(sound, position, volume_db)
	else:
		play_sfx(sound, volume_db)


## Play random foraging sound
## resource_type: "wood", "plant", or "bush"
func play_foraging_sound(resource_type: String = "plant", position: Vector3 = Vector3.ZERO) -> void:
	var sound: String = ""
	match resource_type:
		"wood":
			var wood_sounds: Array[String] = [EVENTS["wood_chop_1"], EVENTS["wood_chop_2"], EVENTS["wood_chop_3"]]
			sound = wood_sounds[randi() % wood_sounds.size()]
		"heavy_wood":
			sound = EVENTS["wood_chop_heavy"]
		_:  # plant, bush, herb
			var bush_sounds: Array[String] = [EVENTS["bush_pick_1"], EVENTS["bush_pick_2"], EVENTS["bush_forage"]]
			sound = bush_sounds[randi() % bush_sounds.size()]

	if position != Vector3.ZERO:
		play_sfx_3d(sound, position)
	else:
		play_sfx(sound)


## Play a crafting-type sound on the dedicated crafting player
## Stops any previous crafting sound to prevent overlap
## Max duration is 1 second
var _crafting_sound_id: int = 0  # Track which sound we're playing

func _play_crafting_type_sound(sound_path: String) -> void:
	if not crafting_player:
		return
	var stream := _load_sound(sound_path)
	if not stream:
		return
	# Stop any currently playing crafting sound
	crafting_player.stop()
	crafting_player.stream = stream
	crafting_player.volume_db = _linear_to_db(sfx_volume)
	crafting_player.play()

	# Increment ID so old timers know to ignore
	_crafting_sound_id += 1
	var my_sound_id: int = _crafting_sound_id

	# Auto-stop after 1 second to keep sounds short
	get_tree().create_timer(1.0).timeout.connect(func():
		# Only stop if this is still the current sound
		if is_instance_valid(crafting_player) and _crafting_sound_id == my_sound_id and crafting_player.playing:
			crafting_player.stop()
	)


## Play random crafting/blacksmith sound (stops previous, max 1 second)
func play_crafting_sound(_position: Vector3 = Vector3.ZERO) -> void:
	var sounds: Array[String] = [
		EVENTS["anvil_hit_1"], EVENTS["anvil_hit_2"], EVENTS["anvil_hit_3"], EVENTS["anvil_hit_4"],
		EVENTS["metal_strike_1"], EVENTS["metal_strike_2"], EVENTS["metal_strike_3"],
		EVENTS["anvil_heavy_1"], EVENTS["anvil_heavy_2"],
	]
	var sound: String = sounds[randi() % sounds.size()]
	_play_crafting_type_sound(sound)


## Play enchanting sound (stops previous, max 1 second)
## success: true for successful enchant, false for failure
func play_enchant_sound(success: bool, _position: Vector3 = Vector3.ZERO) -> void:
	var sound: String = ""
	if success:
		var success_sounds: Array[String] = [EVENTS["enchant_success_1"], EVENTS["enchant_success_2"]]
		sound = success_sounds[randi() % success_sounds.size()]
	else:
		var fail_sounds: Array[String] = [EVENTS["enchant_fail_1"], EVENTS["enchant_fail_2"]]
		sound = fail_sounds[randi() % fail_sounds.size()]
	_play_crafting_type_sound(sound)


## Play enchanting charge-up sound (stops previous, max 1 second)
func play_enchant_charge(_position: Vector3 = Vector3.ZERO) -> void:
	_play_crafting_type_sound(EVENTS["enchant_charge"])


## Play alchemy sound (stops previous, max 1 second)
func play_alchemy_sound(success: bool = true, _position: Vector3 = Vector3.ZERO) -> void:
	var sound: String = EVENTS["alchemy_success"] if success else EVENTS["alchemy_clink"]
	_play_crafting_type_sound(sound)


## Play cooking sound (stops previous, max 1 second)
## sizzle: true for sizzle/cooking sound, false for chopping/prep sound
func play_cooking_sound(sizzle: bool = true, _position: Vector3 = Vector3.ZERO) -> void:
	var sound: String = EVENTS["cooking_sizzle"] if sizzle else EVENTS["cooking_chop"]
	_play_crafting_type_sound(sound)


## Play ambient loop
func play_ambient(ambient_path: String) -> void:
	if ambient_path == current_ambient:
		return

	var stream := _load_sound(ambient_path)
	if not stream:
		return

	ambient_player.stream = stream
	ambient_player.volume_db = _linear_to_db(ambient_volume)
	ambient_player.play()
	current_ambient = ambient_path

## Stop ambient
func stop_ambient() -> void:
	ambient_player.stop()
	current_ambient = ""

## Set master volume (0-1)
func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MASTER_BUS), _linear_to_db(master_volume))

## Set music volume (0-1)
func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	music_player.volume_db = _linear_to_db(music_volume)

## Set SFX volume (0-1)
func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)

## Set ambient volume (0-1)
func set_ambient_volume(value: float) -> void:
	ambient_volume = clamp(value, 0.0, 1.0)
	ambient_player.volume_db = _linear_to_db(ambient_volume)

## Common sound effect shortcuts
func play_hit_sound(is_critical: bool = false) -> void:
	if is_critical:
		play_sfx("res://assets/audio/sfx/hit_critical.wav", 3.0, 0.1)
	else:
		play_sfx("res://assets/audio/sfx/hit.wav", 0.0, 0.15)

func play_miss_sound() -> void:
	play_sfx("res://assets/audio/sfx/whoosh.wav", -3.0, 0.1)

func play_block_sound() -> void:
	play_sfx("res://assets/audio/sfx/block.wav", 0.0, 0.1)

func play_death_sound() -> void:
	play_sfx("res://assets/audio/sfx/death.wav", 0.0, 0.0)

func play_footstep() -> void:
	play_sfx("res://assets/audio/sfx/walking and movement/footstep_1.wav", -6.0, 0.15)

func play_ui_select() -> void:
	play_sfx("res://assets/audio/sfx/ui_select.wav", -3.0, 0.0)

func play_ui_confirm() -> void:
	# Use the accepting click noise for UI confirmations
	play_sfx("res://assets/audio/sfx/ui/Accepting_Click_Noise.wav", -3.0, 0.0)

func play_ui_cancel() -> void:
	play_sfx("res://assets/audio/sfx/ui_cancel.wav", -3.0, 0.0)

## Play a random melee weapon hit sound (sword clanks)
func play_melee_hit_sound() -> void:
	var sound_index := randi_range(1, 3)
	var sound_path := "res://assets/audio/sfx/weapons/sword_clank_%d.wav" % sound_index
	play_sfx(sound_path, 0.0, 0.1)

## Play a random melee weapon hit sound at a 3D position
func play_melee_hit_sound_3d(position: Vector3) -> void:
	var sound_index := randi_range(1, 3)
	var sound_path := "res://assets/audio/sfx/weapons/sword_clank_%d.wav" % sound_index
	play_sfx_3d(sound_path, position, 0.0)

func play_ui_open() -> void:
	play_sfx("res://assets/audio/sfx/ui_open.wav", -3.0, 0.0)

func play_ui_close() -> void:
	play_sfx("res://assets/audio/sfx/ui_close.wav", -3.0, 0.0)

func play_item_pickup() -> void:
	play_sfx("res://assets/audio/sfx/item_pickup.wav", 0.0, 0.1)

func play_gold_pickup() -> void:
	play_sfx("res://assets/audio/sfx/gold.wav", 0.0, 0.05)

func play_spell_cast(spell_school: Enums.SpellSchool) -> void:
	# Play magical chanting sound for all spell casts
	play_sfx("res://assets/audio/sfx/weapons/magical_chanting_cast.wav", -3.0, 0.05)
	# Then play school-specific sound
	match spell_school:
		Enums.SpellSchool.EVOCATION:
			play_sfx("res://assets/audio/sfx/spell_fire.wav", 0.0, 0.1)
		Enums.SpellSchool.RESTORATION:
			play_sfx("res://assets/audio/sfx/spell_heal.wav", 0.0, 0.1)
		Enums.SpellSchool.NECROMANCY:
			play_sfx("res://assets/audio/sfx/spell_dark.wav", 0.0, 0.1)
		_:
			play_sfx("res://assets/audio/sfx/spell_generic.wav", 0.0, 0.1)

## Helper: Load and cache sound
func _load_sound(path: String) -> AudioStream:
	if sound_cache.has(path):
		return sound_cache[path]

	if not ResourceLoader.exists(path):
		push_warning("Sound not found: " + path)
		return null

	var stream: AudioStream = load(path)
	sound_cache[path] = stream
	return stream

## Helper: Get available SFX player from pool
func _get_free_sfx_player() -> AudioStreamPlayer:
	for player in sfx_pool:
		if not player.playing:
			return player
	# All busy, use oldest (first in pool)
	return sfx_pool[0]

## Helper: Crossfade music
func _crossfade_music(new_stream: AudioStream) -> void:
	# Create temporary player for old music
	var old_player := AudioStreamPlayer.new()
	old_player.stream = music_player.stream
	old_player.volume_db = music_player.volume_db
	old_player.bus = MUSIC_BUS
	add_child(old_player)
	old_player.play(music_player.get_playback_position())

	# Fade out old
	var tween := create_tween()
	tween.tween_property(old_player, "volume_db", -80.0, fade_duration)
	tween.tween_callback(old_player.queue_free)

	# Start new music at low volume and fade in
	music_player.stream = new_stream
	music_player.volume_db = -80.0
	music_player.play()

	var tween2 := create_tween()
	tween2.tween_property(music_player, "volume_db", _linear_to_db(music_volume), fade_duration)

## Helper: Convert linear volume to dB
func _linear_to_db(value: float) -> float:
	if value <= 0:
		return -80.0
	return 20.0 * log(value) / log(10.0)

## Serialize settings
func get_settings() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ambient_volume": ambient_volume
	}

## Load settings
func load_settings(data: Dictionary) -> void:
	set_master_volume(data.get("master_volume", 1.0))
	set_music_volume(data.get("music_volume", 0.7))
	set_sfx_volume(data.get("sfx_volume", 1.0))
	set_ambient_volume(data.get("ambient_volume", 0.5))

## Play a sound by event name from EVENTS dictionary
## Returns false if event not found
func play_event(event_name: String, volume_db: float = 0.0, pitch_variance: float = 0.1) -> bool:
	if not EVENTS.has(event_name):
		push_warning("AudioManager: Unknown event '%s'" % event_name)
		return false

	play_sfx(EVENTS[event_name], volume_db, pitch_variance)
	return true

## Play a sound by event name at a 3D position
## Returns false if event not found
func play_event_3d(event_name: String, position: Vector3, volume_db: float = 0.0) -> bool:
	if not EVENTS.has(event_name):
		push_warning("AudioManager: Unknown event '%s'" % event_name)
		return false

	play_sfx_3d(EVENTS[event_name], position, volume_db)
	return true

## Check if an event exists
func has_event(event_name: String) -> bool:
	return EVENTS.has(event_name)

## Get the file path for an event (for custom handling)
func get_event_path(event_name: String) -> String:
	return EVENTS.get(event_name, "")
