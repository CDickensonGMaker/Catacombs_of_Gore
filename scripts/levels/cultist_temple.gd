## cultist_temple.gd - Cultist Temple Ruins level script
## A dark temple where cultists perform their rituals
extends Node3D

const ZONE_ID := "cultist_temple"

## Tree textures for the overgrown ruins
const WILLOW_TEXTURE := "res://assets/sprites/environment/trees/swamp_willow.png"
const SWAMP_TREE_TEXTURES: Array[String] = [
	"res://assets/sprites/environment/trees/swamp_tree1.png",
	"res://assets/sprites/environment/trees/swamp_tree2.png",
]
const FALLEN_LOG_TEXTURES: Array[String] = [
	"res://assets/sprites/environment/trees/swamp_fallen_1.png",
	"res://assets/sprites/environment/trees/swamp_fallen_2.png",
]

## Container for spawned vegetation
var vegetation_container: Node3D
var wildlife_container: Node3D

@onready var spawn_points: Node3D = $SpawnPoints
@onready var enemy_spawns: Node3D = $EnemySpawns
@onready var door_positions: Node3D = $DoorPositions
@onready var chest_positions: Node3D = $ChestPositions


func _ready() -> void:
	add_to_group("level")

	# Register with PlayerGPS
	if PlayerGPS:
		PlayerGPS.set_position(Vector2i(-5, 2))

	# Play ruins ambient and dungeon music (only when main scene)
	var is_main_scene: bool = get_node_or_null("Player") != null
	if is_main_scene:
		AudioManager.play_zone_ambiance("ruins")
		AudioManager.play_zone_music("dungeon")

	_setup_spawn_point()
	_setup_enemies()
	_setup_doors()
	_setup_chests()
	_setup_vegetation()
	_setup_wildlife()

	print("[CultistTemple] Level initialized")


func _setup_spawn_point() -> void:
	if not spawn_points:
		return

	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Get spawn ID from SceneManager
	var spawn_id: String = "default"
	if SceneManager:
		spawn_id = SceneManager.spawn_point_id

	# Find matching spawn point
	for child in spawn_points.get_children():
		if child is Marker3D:
			var marker_id: String = child.get_meta("spawn_id", "default")
			if marker_id == spawn_id or (spawn_id == "default" and marker_id == "default"):
				player.global_position = child.global_position
				player.global_rotation = child.global_rotation
				print("[CultistTemple] Player spawned at: %s (spawn_id: %s)" % [child.name, marker_id])
				return

	# Fallback to first spawn point
	for child in spawn_points.get_children():
		if child is Marker3D:
			player.global_position = child.global_position
			player.global_rotation = child.global_rotation
			print("[CultistTemple] Player spawned at fallback: %s" % child.name)
			return


func _setup_enemies() -> void:
	if not enemy_spawns:
		return

	for child in enemy_spawns.get_children():
		if child is Marker3D:
			_spawn_enemy_at_marker(child)


func _spawn_enemy_at_marker(marker: Marker3D) -> void:
	var enemy_data_path: String = marker.get_meta("enemy_data", "res://data/enemies/cultist.tres")
	var enemy_type: String = marker.get_meta("enemy_type", "cultist")

	# Try to get sprite config from ActorRegistry (includes Zoo patches)
	var sprite_path: String = marker.get_meta("sprite_path", "res://assets/sprites/enemies/humanoid/cultist_red.png")
	var h_frames: int = marker.get_meta("h_frames", 4)
	var v_frames: int = marker.get_meta("v_frames", 1)

	if ActorRegistry:
		var sprite_config: Dictionary = ActorRegistry.get_sprite_config(enemy_type)
		if not sprite_config.is_empty():
			sprite_path = sprite_config.get("sprite_path", sprite_path)
			h_frames = sprite_config.get("h_frames", h_frames)
			v_frames = sprite_config.get("v_frames", v_frames)

	var sprite_texture: Texture2D = load(sprite_path)
	if not sprite_texture:
		push_error("[CultistTemple] Failed to load sprite: %s" % sprite_path)
		return

	var enemy = EnemyBase.spawn_billboard_enemy(
		self,
		marker.global_position,
		enemy_data_path,
		sprite_texture,
		h_frames,
		v_frames
	)

	if enemy:
		enemy.add_to_group("enemies")
		print("[CultistTemple] Spawned enemy at %s" % marker.name)


func _setup_doors() -> void:
	if not door_positions:
		return

	for child in door_positions.get_children():
		if child is Marker3D:
			_spawn_door_at_marker(child)


func _spawn_door_at_marker(marker: Marker3D) -> void:
	var target_scene: String = marker.get_meta("target_scene", "RETURN_TO_WILDERNESS")
	var spawn_id: String = marker.get_meta("spawn_id", "default")
	var door_label: String = marker.get_meta("door_label", "Exit")
	var show_frame: bool = marker.get_meta("show_frame", false)

	var door := ZoneDoor.spawn_door(
		self,
		marker.global_position,
		target_scene,
		spawn_id,
		door_label,
		show_frame
	)

	if door:
		door.rotation = marker.rotation
		print("[CultistTemple] Spawned door: %s -> %s" % [door_label, target_scene])


func _setup_chests() -> void:
	if not chest_positions:
		return

	for child in chest_positions.get_children():
		if child is Marker3D:
			_spawn_chest_at_marker(child)


func _spawn_chest_at_marker(marker: Marker3D) -> void:
	var chest_name: String = marker.get_meta("chest_name", "Chest")
	var is_locked: bool = marker.get_meta("is_locked", false)
	var lock_difficulty: int = marker.get_meta("lock_difficulty", 10)
	var persistent_id: String = marker.get_meta("persistent_id", "")
	var loot_tier_str: String = marker.get_meta("loot_tier", "uncommon")

	var chest := Chest.spawn_chest(
		self,
		marker.global_position,
		chest_name,
		is_locked,
		lock_difficulty,
		not persistent_id.is_empty(),
		persistent_id
	)

	if chest:
		chest.rotation = marker.rotation
		var tier: LootTables.LootTier = _parse_loot_tier(loot_tier_str)
		chest.setup_with_loot(tier)
		print("[CultistTemple] Spawned chest: %s" % chest_name)


func _parse_loot_tier(tier_str: String) -> LootTables.LootTier:
	match tier_str.to_lower():
		"junk": return LootTables.LootTier.JUNK
		"common": return LootTables.LootTier.COMMON
		"uncommon": return LootTables.LootTier.UNCOMMON
		"rare": return LootTables.LootTier.RARE
		"epic": return LootTables.LootTier.EPIC
		"legendary": return LootTables.LootTier.LEGENDARY
		_: return LootTables.LootTier.UNCOMMON


## Setup vegetation - willows, dead trees, and lots of fallen logs
func _setup_vegetation() -> void:
	vegetation_container = Node3D.new()
	vegetation_container.name = "Vegetation"
	add_child(vegetation_container)

	# Spawn willow trees around the edges (6-8 willows)
	var willow_positions: Array[Vector3] = [
		Vector3(-35, 0, -25),
		Vector3(-40, 0, 10),
		Vector3(-30, 0, 35),
		Vector3(35, 0, -30),
		Vector3(40, 0, 15),
		Vector3(30, 0, 40),
		Vector3(-20, 0, -40),
		Vector3(25, 0, -35),
	]
	for pos in willow_positions:
		_spawn_tree(pos, WILLOW_TEXTURE, 0.03, "Willow")

	# Spawn dead/swamp trees scattered around (10-12 trees)
	var dead_tree_positions: Array[Vector3] = [
		Vector3(-25, 0, -15),
		Vector3(-18, 0, 20),
		Vector3(22, 0, -18),
		Vector3(28, 0, 25),
		Vector3(-12, 0, 30),
		Vector3(15, 0, -28),
		Vector3(-38, 0, -8),
		Vector3(38, 0, -5),
		Vector3(-8, 0, -35),
		Vector3(10, 0, 38),
		Vector3(-32, 0, 28),
		Vector3(18, 0, 12),
	]
	for pos in dead_tree_positions:
		var tex: String = SWAMP_TREE_TEXTURES[randi() % SWAMP_TREE_TEXTURES.size()]
		_spawn_tree(pos, tex, 0.025, "Dead Tree")

	# Spawn LOTS of fallen logs (15-20 logs for that overgrown, decaying feel)
	var fallen_log_positions: Array[Vector3] = [
		Vector3(-15, 0, -10),
		Vector3(-8, 0, 5),
		Vector3(12, 0, -8),
		Vector3(5, 0, 15),
		Vector3(-22, 0, 8),
		Vector3(20, 0, -22),
		Vector3(-5, 0, -20),
		Vector3(8, 0, 28),
		Vector3(-28, 0, -5),
		Vector3(25, 0, 8),
		Vector3(-10, 0, 25),
		Vector3(15, 0, -15),
		Vector3(-18, 0, -28),
		Vector3(30, 0, -12),
		Vector3(-35, 0, 18),
		Vector3(10, 0, -32),
		Vector3(-25, 0, 32),
		Vector3(35, 0, 28),
		Vector3(-3, 0, 35),
		Vector3(22, 0, 35),
	]
	for pos in fallen_log_positions:
		_spawn_fallen_log(pos)

	print("[CultistTemple] Spawned vegetation: willows, dead trees, fallen logs")


## Spawn a standing tree billboard
func _spawn_tree(pos: Vector3, texture_path: String, pixel_size: float, tree_name: String) -> void:
	var tex := load(texture_path) as Texture2D
	if not tex:
		return

	var sprite := Sprite3D.new()
	sprite.name = tree_name.replace(" ", "_")
	sprite.texture = tex
	sprite.pixel_size = pixel_size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.transparent = true
	sprite.shaded = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD

	# Position tree with base at ground level
	var height: float = tex.get_height() * pixel_size
	sprite.position = pos + Vector3(0, height / 2.0, 0)

	# Random slight rotation for variety
	sprite.rotation_degrees.y = randf_range(0, 360)

	vegetation_container.add_child(sprite)


## Spawn a fallen log billboard
func _spawn_fallen_log(pos: Vector3) -> void:
	var tex_path: String = FALLEN_LOG_TEXTURES[randi() % FALLEN_LOG_TEXTURES.size()]
	var tex := load(tex_path) as Texture2D
	if not tex:
		return

	var sprite := Sprite3D.new()
	sprite.name = "FallenLog"
	sprite.texture = tex
	sprite.pixel_size = 0.022
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.transparent = true
	sprite.shaded = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD

	# Position log low to the ground
	var height: float = tex.get_height() * sprite.pixel_size
	sprite.position = pos + Vector3(0, height / 2.5, 0)

	# Random rotation for variety
	sprite.rotation_degrees.y = randf_range(0, 360)
	sprite.rotation_degrees.x = randf_range(-10, 10)

	vegetation_container.add_child(sprite)


## Setup ambient wildlife - rats scurrying around the ruins
func _setup_wildlife() -> void:
	wildlife_container = Node3D.new()
	wildlife_container.name = "Wildlife"
	add_child(wildlife_container)

	# Spawn ambient rats around the ruins (5-8 rats)
	var rat_positions: Array[Vector3] = [
		Vector3(-8, 0, -5),
		Vector3(6, 0, 8),
		Vector3(-15, 0, 12),
		Vector3(12, 0, -10),
		Vector3(-3, 0, 18),
		Vector3(18, 0, 5),
		Vector3(-20, 0, -15),
		Vector3(8, 0, -20),
	]

	for pos in rat_positions:
		_spawn_ambient_rat(pos)

	print("[CultistTemple] Spawned wildlife: %d rats" % rat_positions.size())


## Spawn an ambient rat (non-hostile, just visual atmosphere)
func _spawn_ambient_rat(pos: Vector3) -> void:
	var tex := load("res://assets/sprites/enemies/beasts/rat_moving_forward.png") as Texture2D
	if not tex:
		return

	# Use BillboardSprite for animated rat
	var billboard := BillboardSprite.new()
	billboard.name = "AmbientRat"
	billboard.sprite_sheet = tex
	billboard.h_frames = 4  # Rat sprite has 4 animation frames
	billboard.v_frames = 1
	billboard.pixel_size = 0.012  # Small rat
	billboard.idle_frames = 4
	billboard.walk_frames = 4
	billboard.idle_fps = 4.0  # Scurrying animation speed
	billboard.walk_fps = 8.0

	# Position rat at ground level
	var height: float = tex.get_height() * billboard.pixel_size
	billboard.position = pos + Vector3(0, height / 2.0, 0)

	# Random facing direction
	billboard.rotation_degrees.y = randf_range(0, 360)

	wildlife_container.add_child(billboard)
