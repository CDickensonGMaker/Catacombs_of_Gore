## map_fog_of_war.gd - Fog of war system for painted world map (Square Grid)
## Reveals areas as the player explores, with circular reveal around visited cells
## Uses grayscale image for fog opacity - white = visible, black = hidden
class_name MapFogOfWar
extends RefCounted

## Reveal settings
const REVEAL_RADIUS_CELLS := 2  ## Number of cells around player to reveal
const REVEAL_FEATHER := 0.3  ## Edge softness (0-1)

## Grid dimensions (must match WorldData)
const GRID_COLS := 20
const GRID_ROWS := 20

## Fog image (grayscale, R channel = opacity where 255 = visible, 0 = hidden)
var fog_image: Image
var fog_texture: ImageTexture
var image_size: Vector2i

## Cell size in pixels (calculated from image size / grid size)
var cell_size: float = 54.0

## Explored cells (set for fast lookup)
var explored_hexes: Dictionary = {}  ## "x,y" -> true (kept as "hexes" for save compatibility)

## Whether fog is dirty and needs texture update
var _fog_dirty: bool = true


func _init(p_image_size: Vector2i) -> void:
	image_size = p_image_size
	cell_size = float(image_size.x) / float(GRID_COLS)
	_create_fog_image()


## Create initial fog image (fully opaque = all hidden)
func _create_fog_image() -> void:
	fog_image = Image.create(image_size.x, image_size.y, false, Image.FORMAT_L8)
	fog_image.fill(Color(0, 0, 0, 1))  # Black = fully fogged

	fog_texture = ImageTexture.create_from_image(fog_image)
	print("[MapFogOfWar] Created fog image: %dx%d" % [image_size.x, image_size.y])


## Reveal area around a cell coordinate
func reveal_hex(cell: Vector2i) -> void:
	var key: String = "%d,%d" % [cell.x, cell.y]
	if explored_hexes.has(key):
		return  # Already explored

	explored_hexes[key] = true
	_paint_revealed_area(cell)
	_fog_dirty = true


## Convert grid coords to pixel position (center of cell)
func _grid_to_pixel(coords: Vector2i) -> Vector2:
	var pixel_x: float = float(coords.x) * cell_size + cell_size / 2.0
	var pixel_y: float = float(coords.y) * cell_size + cell_size / 2.0
	return Vector2(pixel_x, pixel_y)


## Paint revealed area on fog image around a cell
func _paint_revealed_area(center_cell: Vector2i) -> void:
	# Get pixel position of cell center
	var center_pixel: Vector2 = _grid_to_pixel(center_cell)

	# Calculate reveal radius in pixels (cells * cell_size)
	var pixel_radius: float = float(REVEAL_RADIUS_CELLS) * cell_size

	# Calculate bounding box for painting
	var min_x: int = maxi(0, int(center_pixel.x - pixel_radius) - 1)
	var max_x: int = mini(image_size.x - 1, int(center_pixel.x + pixel_radius) + 1)
	var min_y: int = maxi(0, int(center_pixel.y - pixel_radius) - 1)
	var max_y: int = mini(image_size.y - 1, int(center_pixel.y + pixel_radius) + 1)

	# Paint circular reveal
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var pixel_pos := Vector2(x, y)
			var dist: float = pixel_pos.distance_to(center_pixel)

			if dist <= pixel_radius:
				# Calculate opacity based on distance (feathered edge)
				var inner_radius: float = pixel_radius * (1.0 - REVEAL_FEATHER)
				var alpha: float
				if dist <= inner_radius:
					alpha = 1.0
				else:
					# Smooth falloff from inner to outer radius
					alpha = 1.0 - (dist - inner_radius) / (pixel_radius - inner_radius)
					alpha = smoothstep(0.0, 1.0, alpha)

				# Only increase visibility (don't re-fog explored areas)
				var current: Color = fog_image.get_pixel(x, y)
				var new_value: float = maxf(current.r, alpha)
				fog_image.set_pixel(x, y, Color(new_value, new_value, new_value, 1.0))


## Update the texture if fog has changed
func update_texture() -> void:
	if _fog_dirty:
		fog_texture.update(fog_image)
		_fog_dirty = false


## Get the fog texture for rendering
func get_texture() -> ImageTexture:
	update_texture()
	return fog_texture


## Get the raw fog image
func get_image() -> Image:
	return fog_image


## Check if a hex has been explored
func is_explored(hex: Vector2i) -> bool:
	var key: String = "%d,%d" % [hex.x, hex.y]
	return explored_hexes.has(key)


## Get visibility at a pixel position (0 = hidden, 1 = visible)
func get_visibility_at_pixel(pixel: Vector2) -> float:
	if pixel.x < 0 or pixel.x >= image_size.x or pixel.y < 0 or pixel.y >= image_size.y:
		return 0.0
	return fog_image.get_pixel(int(pixel.x), int(pixel.y)).r


## Mark all explored hexes and rebuild fog
func bulk_reveal(hexes: Array) -> void:
	for hex: Vector2i in hexes:
		var key: String = "%d,%d" % [hex.x, hex.y]
		if not explored_hexes.has(key):
			explored_hexes[key] = true
			_paint_revealed_area(hex)
	_fog_dirty = true


## Clear all explored state (for new game)
func reset() -> void:
	explored_hexes.clear()
	fog_image.fill(Color(0, 0, 0, 1))
	_fog_dirty = true


## Reveal entire map (dev mode or for debugging)
func reveal_all() -> void:
	fog_image.fill(Color(1, 1, 1, 1))
	_fog_dirty = true


## Convert to dictionary for saving
func to_dict() -> Dictionary:
	# Convert explored hexes to array of coordinates
	var explored_list: Array = []
	for key: String in explored_hexes:
		var parts: PackedStringArray = key.split(",")
		if parts.size() == 2:
			explored_list.append([int(parts[0]), int(parts[1])])

	return {
		"explored_hexes": explored_list,
		"image_size": [image_size.x, image_size.y]
	}


## Load from dictionary
func from_dict(data: Dictionary) -> void:
	# Clear current state
	reset()

	# Restore explored hexes
	var explored_list: Array = data.get("explored_hexes", [])
	var hexes_to_reveal: Array = []

	for coord: Array in explored_list:
		if coord.size() >= 2:
			hexes_to_reveal.append(Vector2i(int(coord[0]), int(coord[1])))

	# Bulk reveal all previously explored hexes
	if hexes_to_reveal.size() > 0:
		bulk_reveal(hexes_to_reveal)
		print("[MapFogOfWar] Restored %d explored hexes" % hexes_to_reveal.size())


## Get count of explored hexes
func get_explored_count() -> int:
	return explored_hexes.size()
