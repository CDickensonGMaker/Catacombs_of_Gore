## background_manager.gd - Static background using a far Sprite3D
## Renders behind all 3D content by positioning far from camera
## Autoload: BackgroundManager
extends Node

var background_sprite: Sprite3D
var current_camera: Camera3D

## Biome enum matches WildernessRoom.Biome and WorldData.Biome
enum Biome { FOREST, PLAINS, SWAMP, HILLS, ROCKY, COAST, MOUNTAINS, DESERT, UNDEAD }

## Background texture paths by biome
const BIOME_BACKGROUNDS := {
	Biome.FOREST: "res://Sprite folders grab bag/edge_zone.png",
	Biome.PLAINS: "res://Sprite folders grab bag/plains_background.png",
	Biome.SWAMP: "res://Sprite folders grab bag/swampbackground.png",
	Biome.HILLS: "res://Sprite folders grab bag/rockhill_background.png",
	Biome.ROCKY: "res://Sprite folders grab bag/rockhill_background.png",
	Biome.COAST: "res://Sprite folders grab bag/seaport_city_background.png",
	Biome.MOUNTAINS: "res://Sprite folders grab bag/mountianforest_background.png",
	Biome.DESERT: "res://Sprite folders grab bag/desertcity_background.png",
	Biome.UNDEAD: "res://Sprite folders grab bag/spookygraveyard_background.png",
}

## Default background for unknown biomes
const DEFAULT_BACKGROUND := "res://Sprite folders grab bag/edge_zone.png"

## How far behind the camera the background sits
const BACKGROUND_DISTANCE := 400.0
## How large the background sprite is (covers entire view)
const BACKGROUND_SCALE := 500.0


func _ready() -> void:
	# We'll create the sprite when we first need it
	print("[BackgroundManager] Initialized - will create background sprite on first use")


func _process(_delta: float) -> void:
	if background_sprite and is_instance_valid(background_sprite):
		_update_background_position()


func _update_background_position() -> void:
	# Find the current camera if we don't have one
	if not current_camera or not is_instance_valid(current_camera):
		current_camera = get_viewport().get_camera_3d()
		if not current_camera:
			return

	# Position the background far behind the camera, facing it
	var cam_transform: Transform3D = current_camera.global_transform
	var behind_pos: Vector3 = cam_transform.origin - cam_transform.basis.z * BACKGROUND_DISTANCE
	background_sprite.global_position = behind_pos

	# Make the sprite face the camera
	background_sprite.look_at(cam_transform.origin, Vector3.UP)
	background_sprite.rotate_object_local(Vector3.UP, PI)  # Flip to face camera


func _ensure_sprite_exists() -> void:
	if background_sprite and is_instance_valid(background_sprite):
		return

	# Create the background sprite
	background_sprite = Sprite3D.new()
	background_sprite.name = "BackgroundSprite"

	# Make it huge to fill the view
	background_sprite.pixel_size = 1.0  # 1 pixel = 1 unit

	# Render settings - always behind everything
	background_sprite.no_depth_test = true  # Ignore depth, always visible
	background_sprite.render_priority = -1000  # Render first (behind everything)

	# Don't use billboard - we manually position it
	background_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED

	# PS1 style filtering
	background_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Add to scene tree at root level
	get_tree().root.add_child.call_deferred(background_sprite)

	print("[BackgroundManager] Created background sprite")


## Set background directly from a texture path
func set_background(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("[BackgroundManager] Background texture not found: %s" % path)
		return

	_ensure_sprite_exists()

	var texture: Texture2D = load(path)
	if texture:
		background_sprite.texture = texture
		print("[BackgroundManager] Set background: %s" % path)
	else:
		push_warning("[BackgroundManager] Failed to load background texture: %s" % path)


## Set background based on biome enum (WildernessRoom.Biome values)
func set_background_for_biome(biome: int) -> void:
	var path: String = BIOME_BACKGROUNDS.get(biome, DEFAULT_BACKGROUND)
	set_background(path)


## Set background based on WorldData.Biome enum
## This maps WorldData biomes to our background images
func set_background_for_world_biome(world_biome: int) -> void:
	# WorldData.Biome: PLAINS, FOREST, HILLS, MOUNTAINS, SWAMP, COAST, DESERT, ROCKY, UNDEAD
	# Map to our local Biome enum
	var biome_map := {
		0: Biome.PLAINS,     # WorldData.Biome.PLAINS
		1: Biome.FOREST,     # WorldData.Biome.FOREST
		2: Biome.HILLS,      # WorldData.Biome.HILLS
		3: Biome.MOUNTAINS,  # WorldData.Biome.MOUNTAINS
		4: Biome.SWAMP,      # WorldData.Biome.SWAMP
		5: Biome.COAST,      # WorldData.Biome.COAST
		6: Biome.DESERT,     # WorldData.Biome.DESERT
		7: Biome.ROCKY,      # WorldData.Biome.ROCKY
		8: Biome.UNDEAD,     # WorldData.Biome.UNDEAD
	}

	var local_biome: int = biome_map.get(world_biome, Biome.FOREST)
	set_background_for_biome(local_biome)


## Show the background
func show_background() -> void:
	if background_sprite and is_instance_valid(background_sprite):
		background_sprite.visible = true


## Hide the background (for indoor areas that don't need it)
func hide_background() -> void:
	if background_sprite and is_instance_valid(background_sprite):
		background_sprite.visible = false


## Set a custom tint/modulate for atmosphere effects
func set_tint(color: Color) -> void:
	if background_sprite and is_instance_valid(background_sprite):
		background_sprite.modulate = color


## Reset tint to default white
func reset_tint() -> void:
	if background_sprite and is_instance_valid(background_sprite):
		background_sprite.modulate = Color.WHITE
