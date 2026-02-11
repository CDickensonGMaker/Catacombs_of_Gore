## dungeon_room.gd - Runtime room instance generated from RoomTemplate
## Works with grid-based dungeon generator for seamless geometry
class_name DungeonRoom
extends Node3D

const TorchProp = preload("res://scripts/props/torch_prop.gd")

## Enemy spawner decoration textures
const SPAWNER_TEXTURES := [
	"res://Sprite folders grab bag/pile of skulls.png",
	"res://Sprite folders grab bag/candlepentagram.png",
	"res://Sprite folders grab bag/skullpillar.png",
]
const BOSS_SPAWNER_TEXTURE := "res://Sprite folders grab bag/coffinskeleton.png"

signal room_entered(room: DungeonRoom)
signal room_cleared(room: DungeonRoom)

## The template this room was created from
var template: RoomTemplate

## Room state
var room_id: String = ""
var room_index: int = 0
var is_explored: bool = false
var is_cleared: bool = false
var enemies_spawned: Array[Node] = []

## World position of room center
var room_center: Vector3 = Vector3.ZERO

## Connected rooms (via doors)
var connected_rooms: Dictionary = {}  # direction -> DungeonRoom

## Consistent wall thickness (set by generator)
var wall_thickness: float = 1.0

## Materials (created once, shared)
var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var ceiling_material: StandardMaterial3D

## Quest NPC reference (if this is a quest room)
var quest_npc: Node = null


## Initialize room from template at given position
func setup(room_template: RoomTemplate, world_position: Vector3, index: int) -> void:
	template = room_template
	room_center = world_position
	room_index = index
	room_id = "%s_%d" % [template.room_id, index]
	position = world_position

	_create_materials()
	_create_geometry()
	_create_decorations()


## Create materials based on template colors and textures
func _create_materials() -> void:
	# Load textures
	var floor_texture: Texture2D = load("res://Sprite folders grab bag/stonefloor.png")
	var wall_texture: Texture2D = load("res://Sprite folders grab bag/stonewall.png")

	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = template.floor_color
	floor_material.roughness = 0.9
	if floor_texture:
		floor_material.albedo_texture = floor_texture
		floor_material.uv1_scale = Vector3(2, 2, 1)  # Tile the texture
		floor_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 pixelated look

	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = template.wall_color
	wall_material.roughness = 0.95
	if wall_texture:
		wall_material.albedo_texture = wall_texture
		wall_material.uv1_scale = Vector3(2, 2, 1)  # Tile the texture
		wall_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 pixelated look

	ceiling_material = StandardMaterial3D.new()
	ceiling_material.albedo_color = template.ceiling_color
	ceiling_material.roughness = 0.9
	if wall_texture:
		ceiling_material.albedo_texture = wall_texture
		ceiling_material.uv1_scale = Vector3(2, 2, 1)
		ceiling_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


## Create the room geometry using CSG
## Uses consistent wall thickness and creates door gaps only where connected
func _create_geometry() -> void:
	var w := float(template.width)
	var d := float(template.depth)
	var h := float(template.height)
	var floor_y := template.floor_y

	# Floor - solid, no gaps
	var floor_csg := CSGBox3D.new()
	floor_csg.name = "Floor"
	floor_csg.size = Vector3(w, 1.0, d)
	floor_csg.position = Vector3(0, floor_y - 0.5, 0)
	floor_csg.material = floor_material
	floor_csg.use_collision = true
	add_child(floor_csg)

	# Ceiling - solid
	var ceiling := CSGBox3D.new()
	ceiling.name = "Ceiling"
	ceiling.size = Vector3(w, 0.5, d)
	ceiling.position = Vector3(0, floor_y + h, 0)
	ceiling.material = ceiling_material
	ceiling.use_collision = true
	add_child(ceiling)

	# Create walls with door gaps for template doors
	# Gaps will be sealed later if not connected
	_create_walls(w, d, h, floor_y)


## Create walls with gaps for doors
## Initially creates gaps for ALL template doors
## Call seal_unused_doors() after dungeon generation to close unconnected doors
func _create_walls(w: float, d: float, h: float, floor_y: float) -> void:
	var half_w := w / 2.0
	var half_d := d / 2.0

	# Check which sides have template doors
	var has_north := template.has_door_on_side(Vector3.FORWARD)
	var has_south := template.has_door_on_side(Vector3.BACK)
	var has_east := template.has_door_on_side(Vector3.RIGHT)
	var has_west := template.has_door_on_side(Vector3.LEFT)

	# North wall (positive Z)
	if has_north:
		var door := template.get_door_on_side(Vector3.FORWARD)
		var door_width: float = door.get("width", 4.0)
		_create_wall_with_gap(
			Vector3(0, floor_y + h / 2.0, half_d + wall_thickness / 2.0),
			Vector3(w, h, wall_thickness),
			door_width,
			true,  # Horizontal gap
			"WallNorth"
		)
	else:
		_create_solid_wall(
			Vector3(0, floor_y + h / 2.0, half_d + wall_thickness / 2.0),
			Vector3(w, h, wall_thickness),
			"WallNorth"
		)

	# South wall (negative Z)
	if has_south:
		var door := template.get_door_on_side(Vector3.BACK)
		var door_width: float = door.get("width", 4.0)
		_create_wall_with_gap(
			Vector3(0, floor_y + h / 2.0, -half_d - wall_thickness / 2.0),
			Vector3(w, h, wall_thickness),
			door_width,
			true,
			"WallSouth"
		)
	else:
		_create_solid_wall(
			Vector3(0, floor_y + h / 2.0, -half_d - wall_thickness / 2.0),
			Vector3(w, h, wall_thickness),
			"WallSouth"
		)

	# East wall (positive X)
	if has_east:
		var door := template.get_door_on_side(Vector3.RIGHT)
		var door_width: float = door.get("width", 4.0)
		_create_wall_with_gap(
			Vector3(half_w + wall_thickness / 2.0, floor_y + h / 2.0, 0),
			Vector3(wall_thickness, h, d),
			door_width,
			false,  # Vertical gap (along Z)
			"WallEast"
		)
	else:
		_create_solid_wall(
			Vector3(half_w + wall_thickness / 2.0, floor_y + h / 2.0, 0),
			Vector3(wall_thickness, h, d),
			"WallEast"
		)

	# West wall (negative X)
	if has_west:
		var door := template.get_door_on_side(Vector3.LEFT)
		var door_width: float = door.get("width", 4.0)
		_create_wall_with_gap(
			Vector3(-half_w - wall_thickness / 2.0, floor_y + h / 2.0, 0),
			Vector3(wall_thickness, h, d),
			door_width,
			false,
			"WallWest"
		)
	else:
		_create_solid_wall(
			Vector3(-half_w - wall_thickness / 2.0, floor_y + h / 2.0, 0),
			Vector3(wall_thickness, h, d),
			"WallWest"
		)


## Create a solid wall segment
func _create_solid_wall(pos: Vector3, size: Vector3, wall_name: String) -> void:
	var wall := CSGBox3D.new()
	wall.name = wall_name
	wall.size = size
	wall.position = pos
	wall.material = wall_material
	wall.use_collision = true
	add_child(wall)


## Create wall with door gap in center
func _create_wall_with_gap(pos: Vector3, size: Vector3, gap_width: float, horizontal_gap: bool, base_name: String) -> void:
	var half_gap := gap_width / 2.0

	if horizontal_gap:
		# Gap along X axis - create left and right wall segments
		var segment_width := (size.x - gap_width) / 2.0
		if segment_width > 0:
			# Left segment
			var left := CSGBox3D.new()
			left.name = base_name + "_Left"
			left.size = Vector3(segment_width, size.y, size.z)
			left.position = pos + Vector3(-half_gap - segment_width / 2.0, 0, 0)
			left.material = wall_material
			left.use_collision = true
			add_child(left)

			# Right segment
			var right := CSGBox3D.new()
			right.name = base_name + "_Right"
			right.size = Vector3(segment_width, size.y, size.z)
			right.position = pos + Vector3(half_gap + segment_width / 2.0, 0, 0)
			right.material = wall_material
			right.use_collision = true
			add_child(right)
	else:
		# Gap along Z axis - create front and back wall segments
		var segment_depth := (size.z - gap_width) / 2.0
		if segment_depth > 0:
			# Front segment (positive Z)
			var front := CSGBox3D.new()
			front.name = base_name + "_Front"
			front.size = Vector3(size.x, size.y, segment_depth)
			front.position = pos + Vector3(0, 0, half_gap + segment_depth / 2.0)
			front.material = wall_material
			front.use_collision = true
			add_child(front)

			# Back segment (negative Z)
			var back := CSGBox3D.new()
			back.name = base_name + "_Back"
			back.size = Vector3(size.x, size.y, segment_depth)
			back.position = pos + Vector3(0, 0, -half_gap - segment_depth / 2.0)
			back.material = wall_material
			back.use_collision = true
			add_child(back)


## Create decorations from template
func _create_decorations() -> void:
	for dec in template.decorations:
		var dec_type: String = dec.get("type", "")
		var dec_pos: Vector3 = dec.get("position", Vector3.ZERO)
		var dec_rot: float = dec.get("rotation_y", 0.0)

		match dec_type:
			"coffin":
				_create_coffin(dec_pos, dec_rot)
			"pillar":
				_create_pillar(dec_pos)
			"altar":
				_create_altar(dec_pos, dec_rot)

	# Add room-type specific decorations
	_create_room_type_decorations()


## Create decorations based on room type (guard rooms, combat rooms, etc.)
func _create_room_type_decorations() -> void:
	match template.room_type:
		"guard":
			_create_guard_room_decorations()
		"prison":
			# Prison rooms also get guard-style decorations
			_create_guard_room_decorations()
		"combat":
			_create_combat_room_decorations()


## Guard room: Two skull pillars flanking a skull pentagram on the wall
func _create_guard_room_decorations() -> void:
	var half_w := template.width / 2.0
	var half_d := template.depth / 2.0

	# Find the wall opposite the main door (back wall for pentagram)
	var back_wall_dir := Vector3.BACK  # Default
	var pentagram_z := -half_d + 1.5

	# Check which wall has the least doors for pentagram placement
	if not template.has_door_on_side(Vector3.BACK):
		back_wall_dir = Vector3.BACK
		pentagram_z = -half_d + 1.5
	elif not template.has_door_on_side(Vector3.FORWARD):
		back_wall_dir = Vector3.FORWARD
		pentagram_z = half_d - 1.5

	# Skull pentagram on back wall (centered)
	var pentagram_pos := Vector3(0, template.height * 0.5, pentagram_z)
	_create_wall_decoration(pentagram_pos, "res://Sprite folders grab bag/candlepentagram.png", 1.0, back_wall_dir)

	# Two skull pillars flanking the pentagram
	var pillar_offset := 3.0  # Distance from center
	var pillar_z := pentagram_z + (1.5 if back_wall_dir == Vector3.BACK else -1.5)  # Slightly in front of wall

	# Left pillar
	var left_pillar_pos := Vector3(-pillar_offset, 0, pillar_z)
	_create_skull_pillar_decoration(left_pillar_pos)

	# Right pillar
	var right_pillar_pos := Vector3(pillar_offset, 0, pillar_z)
	_create_skull_pillar_decoration(right_pillar_pos)


## Combat room: Skull pentagram in each corner (20% smaller)
func _create_combat_room_decorations() -> void:
	var half_w := template.width / 2.0
	var half_d := template.depth / 2.0
	var corner_offset := 2.0  # Distance from walls
	var pentagram_height := template.height * 0.4  # Lower on wall
	var corner_scale := 0.8  # 20% smaller

	# Define corners and their facing directions
	var corners := [
		{"pos": Vector3(-half_w + corner_offset, pentagram_height, -half_d + corner_offset), "facing": Vector3(1, 0, 1).normalized()},
		{"pos": Vector3(half_w - corner_offset, pentagram_height, -half_d + corner_offset), "facing": Vector3(-1, 0, 1).normalized()},
		{"pos": Vector3(-half_w + corner_offset, pentagram_height, half_d - corner_offset), "facing": Vector3(1, 0, -1).normalized()},
		{"pos": Vector3(half_w - corner_offset, pentagram_height, half_d - corner_offset), "facing": Vector3(-1, 0, -1).normalized()}
	]

	for corner in corners:
		# Check if this corner is near a door - skip if so
		if _is_near_door(corner.pos):
			continue
		_create_corner_pentagram(corner.pos, corner_scale)


## Create a wall decoration (billboard sprite on wall)
func _create_wall_decoration(local_pos: Vector3, texture_path: String, scale_factor: float, facing_dir: Vector3) -> void:
	var texture: Texture2D = load(texture_path)
	if not texture:
		return

	var sprite := Sprite3D.new()
	sprite.name = "WallDecoration"
	sprite.texture = texture
	sprite.pixel_size = 0.01 * scale_factor
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED  # Fixed on wall
	sprite.transparent = true
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.alpha_scissor_threshold = 0.5
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position = local_pos

	# Rotate to face into the room
	if facing_dir == Vector3.BACK:
		sprite.rotation.y = 0
	elif facing_dir == Vector3.FORWARD:
		sprite.rotation.y = PI
	elif facing_dir == Vector3.LEFT:
		sprite.rotation.y = PI / 2
	elif facing_dir == Vector3.RIGHT:
		sprite.rotation.y = -PI / 2

	add_child(sprite)


## Create a skull pillar decoration (3D pillar + skull billboard on top)
func _create_skull_pillar_decoration(local_pos: Vector3) -> void:
	var texture: Texture2D = load("res://Sprite folders grab bag/skullpillar.png")
	if not texture:
		return

	# Create billboard sprite
	var sprite := Sprite3D.new()
	sprite.name = "SkullPillarDecoration"
	sprite.texture = texture
	sprite.pixel_size = 0.01
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.alpha_scissor_threshold = 0.5
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Position at floor, sprite extends upward
	var sprite_height := texture.get_height() * sprite.pixel_size
	sprite.position = local_pos + Vector3(0, sprite_height / 2.0, 0)

	add_child(sprite)


## Create a corner pentagram (smaller, angled into corner)
func _create_corner_pentagram(local_pos: Vector3, scale_factor: float) -> void:
	var texture: Texture2D = load("res://Sprite folders grab bag/candlepentagram.png")
	if not texture:
		return

	var sprite := Sprite3D.new()
	sprite.name = "CornerPentagram"
	sprite.texture = texture
	sprite.pixel_size = 0.008 * scale_factor  # Smaller base size + scale
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # Always face player
	sprite.transparent = true
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.alpha_scissor_threshold = 0.5
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position = local_pos

	add_child(sprite)


## Create a coffin decoration
func _create_coffin(local_pos: Vector3, rot_y: float) -> void:
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.25, 0.18, 0.12)
	wood_mat.roughness = 0.85

	var coffin := CSGBox3D.new()
	coffin.name = "Coffin"
	coffin.size = Vector3(1.2, 0.6, 2.5)
	coffin.position = local_pos + Vector3(0, 0.3, 0)
	coffin.rotation.y = rot_y
	coffin.material = wood_mat
	coffin.use_collision = true
	add_child(coffin)


## Create a pillar decoration
func _create_pillar(local_pos: Vector3) -> void:
	var pillar := CSGCylinder3D.new()
	pillar.name = "Pillar"
	pillar.radius = 0.5
	pillar.height = template.height - 0.5
	pillar.position = local_pos + Vector3(0, template.height / 2.0, 0)
	pillar.material = wall_material
	pillar.use_collision = true
	add_child(pillar)


## Create an altar decoration
func _create_altar(local_pos: Vector3, rot_y: float) -> void:
	var altar := CSGBox3D.new()
	altar.name = "Altar"
	altar.size = Vector3(3, 1.2, 2)
	altar.position = local_pos + Vector3(0, 0.6, 0)
	altar.rotation.y = rot_y
	altar.material = wall_material
	altar.use_collision = true
	add_child(altar)


## Validate that a spawn position is not inside walls or decorations
func _is_valid_spawn_position(local_pos: Vector3) -> bool:
	var margin := 1.5  # Wall thickness + buffer
	var half_w := template.width / 2.0 - margin
	var half_d := template.depth / 2.0 - margin

	if abs(local_pos.x) > half_w or abs(local_pos.z) > half_d:
		return false

	for deco in template.decorations:
		var deco_pos: Vector3 = deco.get("position", Vector3.ZERO)
		if local_pos.distance_to(deco_pos) < 1.5:
			return false

	return true


## Create a spawner decoration (billboard sprite) at the given position
func _create_spawner_decoration(local_pos: Vector3, is_boss: bool = false) -> void:
	var texture_path: String
	if is_boss:
		texture_path = BOSS_SPAWNER_TEXTURE
	else:
		texture_path = SPAWNER_TEXTURES[randi() % SPAWNER_TEXTURES.size()]

	var texture: Texture2D = load(texture_path)
	if not texture:
		return

	# Create billboard sprite for the spawner
	var spawner := Sprite3D.new()
	spawner.name = "SpawnerDecoration"
	spawner.texture = texture
	spawner.pixel_size = 0.008  # Smaller size for spawner props
	spawner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spawner.transparent = true
	spawner.shaded = true
	spawner.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spawner.alpha_scissor_threshold = 0.5
	spawner.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Position at floor level, offset up by half sprite height
	var sprite_height := texture.get_height() * spawner.pixel_size
	spawner.position = local_pos + Vector3(0, sprite_height / 2.0, 0)

	add_child(spawner)


## Spawn a single enemy with optional roaming behavior
func spawn_single_enemy(parent: Node, generator: Node, roaming: bool = false) -> void:
	if template.enemy_data_paths.is_empty():
		return

	var spawn_pos := _get_random_spawn_position()
	if spawn_pos == Vector3.INF:
		return

	var enemy_idx := enemies_spawned.size()
	var enemy_id := "%s_enemy_%d" % [room_id, enemy_idx]

	# Create spawner decoration at this position (even if enemy was killed)
	_create_spawner_decoration(spawn_pos, false)

	if SaveManager.was_enemy_killed(enemy_id):
		return

	var enemy_config := template.get_random_enemy()
	var world_pos: Vector3 = room_center + spawn_pos + Vector3(0, 0.5, 0)  # Lift enemy off floor

	var enemy: Node3D = null

	if enemy_config.sprite_path.is_empty():
		# No sprite path - use skeleton spawner as fallback (has walk/attack sprites)
		enemy = EnemyBase.spawn_skeleton_enemy(
			parent,
			world_pos,
			enemy_config.data_path
		)
		if enemy:
			enemy.persistent_id = enemy_id
	else:
		# Billboard sprite enemy
		var sprite_texture: Texture2D = load(enemy_config.sprite_path)
		if sprite_texture:
			enemy = EnemyBase.spawn_billboard_enemy(
				parent,
				world_pos,
				enemy_config.data_path,
				sprite_texture,
				enemy_config.h_frames,
				enemy_config.v_frames
			)
			if enemy:
				enemy.persistent_id = enemy_id

	if enemy:
		enemies_spawned.append(enemy)
		_connect_enemy_death(enemy)
		_apply_undead_glow(enemy, enemy_config.data_path)

		# Configure roaming behavior
		if roaming and enemy.has_method("set") and enemy.get("behavior_mode") != null:
			# Set to WANDER or PATROL mode for roaming
			enemy.behavior_mode = 2  # BehaviorMode.WANDER
			enemy.wander_radius = minf(template.width, template.depth) / 2.0 - 2.0
			enemy.randomize_behavior = false  # Don't override our setting
			print("[DungeonRoom] Enemy set to roam with radius %.1f" % enemy.wander_radius)


## Spawn enemies based on template configuration
func spawn_enemies(parent: Node) -> void:
	if template.enemy_data_paths.is_empty():
		return

	var count := template.get_enemy_spawn_count()
	var spawn_zones := template.enemy_spawn_zones.duplicate()

	while spawn_zones.size() < count:
		var random_pos: Vector3 = Vector3.ZERO
		var found_valid := false

		for _attempt in range(10):
			random_pos = Vector3(
				randf_range(-template.width / 3.0, template.width / 3.0),
				template.floor_y,
				randf_range(-template.depth / 3.0, template.depth / 3.0)
			)
			if _is_valid_spawn_position(random_pos):
				found_valid = true
				break

		if found_valid:
			spawn_zones.append(random_pos)
		else:
			count -= 1

	spawn_zones.shuffle()

	for i in range(count):
		var enemy_id := "%s_enemy_%d" % [room_id, i]

		# Create spawner decoration at this position (even if enemy was killed)
		_create_spawner_decoration(spawn_zones[i], false)

		if SaveManager.was_enemy_killed(enemy_id):
			continue

		var enemy_config := template.get_random_enemy()
		var spawn_pos: Vector3 = room_center + spawn_zones[i] + Vector3(0, 0.5, 0)  # Lift enemy off floor

		var enemy: EnemyBase = null
		if enemy_config.sprite_path.is_empty():
			# No sprite path - use skeleton spawner as fallback (has walk/attack sprites)
			enemy = EnemyBase.spawn_skeleton_enemy(
				parent,
				spawn_pos,
				enemy_config.data_path
			)
		else:
			var sprite_texture: Texture2D = load(enemy_config.sprite_path)
			if sprite_texture:
				enemy = EnemyBase.spawn_billboard_enemy(
					parent,
					spawn_pos,
					enemy_config.data_path,
					sprite_texture,
					enemy_config.h_frames,
					enemy_config.v_frames
				)

		if enemy:
			enemy.persistent_id = enemy_id
			enemies_spawned.append(enemy)
			_connect_enemy_death(enemy)
			enemy.call_deferred("_check_and_apply_undead_glow", enemy_config.data_path)


## Spawn boss enemy (for boss rooms)
func spawn_boss(parent: Node) -> void:
	if not parent:
		push_error("[DungeonRoom] spawn_boss called with null parent")
		return
	if not template or not template.is_boss_room or template.boss_data_path.is_empty():
		return

	var boss_id := "%s_boss" % room_id
	var local_spawn_pos := Vector3(0, template.floor_y, -template.depth / 4.0)

	# Create coffin skeleton spawner decoration (even if boss was killed)
	_create_spawner_decoration(local_spawn_pos, true)

	if SaveManager.was_enemy_killed(boss_id):
		return

	var spawn_pos: Vector3 = room_center + local_spawn_pos + Vector3(0, 0.5, 0)  # Lift boss off floor

	var boss: EnemyBase = null
	if template.boss_sprite_path.is_empty():
		# No sprite path - use skeleton with multi-state sprites as fallback for boss
		boss = EnemyBase.spawn_skeleton_enemy(parent, spawn_pos, template.boss_data_path)
	else:
		var sprite_texture: Texture2D = load(template.boss_sprite_path)
		if sprite_texture:
			boss = EnemyBase.spawn_billboard_enemy(
				parent,
				spawn_pos,
				template.boss_data_path,
				sprite_texture,
				template.boss_h_frames,
				template.boss_v_frames
			)
		else:
			# Sprite failed to load - fallback to skeleton
			push_warning("[DungeonRoom] Failed to load boss sprite: %s, falling back to skeleton" % template.boss_sprite_path)
			boss = EnemyBase.spawn_skeleton_enemy(parent, spawn_pos, template.boss_data_path)

	if boss:
		boss.persistent_id = boss_id
		enemies_spawned.append(boss)
		_connect_enemy_death(boss)
		boss.call_deferred("_check_and_apply_undead_glow", template.boss_data_path)


## Spawn quest NPC for quest rooms
func spawn_quest_npc(parent: Node) -> void:
	if template.room_type != "quest":
		return
	if not template.has_quest_npc:
		return

	# Spawn NPC at configured position (or center of room if not set)
	var local_offset := template.quest_npc_position if template.quest_npc_position != Vector3.ZERO else Vector3.ZERO
	var npc_pos := room_center + local_offset + Vector3(0, template.floor_y, 0)

	# Spawn quest giver NPC
	var npc_name := template.quest_npc_name if template.quest_npc_name != "" else "Dungeon Wanderer"
	quest_npc = QuestGiver.spawn_quest_giver(
		parent,
		npc_pos,
		npc_name,
		"dungeon_quest_npc_%d" % room_index
	)
	# Configure dungeon-specific quests from template
	if quest_npc:
		# Extract quest ID from path (e.g., "res://data/quests/dungeon_clear.json" -> "dungeon_clear")
		var quest_path := template.quest_data_path
		var quest_id := quest_path.get_file().get_basename()
		quest_npc.quest_ids.clear()
		quest_npc.quest_ids.append(quest_id)
		print("[DungeonRoom] Spawned quest NPC '%s' in room %d with quest '%s'" % [npc_name, room_index, quest_id])


## Connect to enemy death signal
func _connect_enemy_death(enemy: Node) -> void:
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))


## Apply undead glow effect to enemies
func _apply_undead_glow(enemy: Node, data_path: String) -> void:
	if not enemy is EnemyBase:
		return
	var enemy_base := enemy as EnemyBase
	enemy_base._check_and_apply_undead_glow(data_path)


## Handle enemy death
func _on_enemy_died(_killer: Node, enemy: Node) -> void:
	enemies_spawned.erase(enemy)
	_check_room_cleared()


## Check if room is cleared
func _check_room_cleared() -> void:
	var valid_enemies: Array[Node] = []
	for enemy in enemies_spawned:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			if enemy.has_method("is_dead") and not enemy.is_dead():
				valid_enemies.append(enemy)
	enemies_spawned = valid_enemies

	if enemies_spawned.is_empty() and not is_cleared:
		is_cleared = true
		room_cleared.emit(self)


## Spawn loot chests
func spawn_loot(parent: Node) -> void:
	if template.chest_count <= 0:
		return

	var loot_zones := template.loot_spawn_zones.duplicate()

	while loot_zones.size() < template.chest_count:
		var random_pos := Vector3(
			randf_range(-template.width / 3.0, template.width / 3.0),
			template.floor_y,
			randf_range(-template.depth / 3.0, template.depth / 3.0)
		)
		loot_zones.append(random_pos)

	for i in range(template.chest_count):
		var chest_pos: Vector3 = room_center + loot_zones[i]
		var chest := Chest.spawn_chest(
			parent,
			chest_pos,
			"Dungeon Chest",
			template.chest_locked,
			template.chest_lock_dc,
			false,
			""
		)
		chest.setup_with_loot(template.loot_tier)


## Spawn rest spot
func spawn_rest_spot(parent: Node) -> void:
	if not template.has_rest_spot:
		return

	var rest_pos := room_center + Vector3(0, template.floor_y, 0)
	RestSpot.spawn_rest_spot(parent, rest_pos, template.rest_spot_name)


## Spawn portal
func spawn_portal(parent: Node) -> void:
	if not template.has_portal or template.portal_target_scene.is_empty():
		return

	var portal_pos := room_center + Vector3(0, template.floor_y, template.depth / 2.0 - 1)
	var portal := ZoneDoor.spawn_door(
		parent,
		portal_pos,
		template.portal_target_scene,
		template.portal_spawn_id,
		template.portal_display_name
	)
	portal.rotation.y = PI


## Get a random valid spawn position
func _get_random_spawn_position() -> Vector3:
	if not template.enemy_spawn_zones.is_empty():
		var zones := template.enemy_spawn_zones.duplicate()
		zones.shuffle()
		for zone in zones:
			if _is_valid_spawn_position(zone):
				return zone

	for _attempt in range(10):
		var random_pos := Vector3(
			randf_range(-template.width / 3.0, template.width / 3.0),
			template.floor_y,
			randf_range(-template.depth / 3.0, template.depth / 3.0)
		)
		if _is_valid_spawn_position(random_pos):
			return random_pos

	return Vector3.INF


## Spawn a single chest
func spawn_single_chest(parent: Node) -> void:
	var loot_pos := _get_random_loot_position()
	if loot_pos == Vector3.INF:
		return

	var chest_pos: Vector3 = room_center + loot_pos
	var chest := Chest.spawn_chest(
		parent,
		chest_pos,
		"Dungeon Chest",
		template.chest_locked,
		template.chest_lock_dc,
		false,
		""
	)
	chest.setup_with_loot(template.loot_tier)


## Get a random valid loot position
func _get_random_loot_position() -> Vector3:
	if not template.loot_spawn_zones.is_empty():
		var zones := template.loot_spawn_zones.duplicate()
		zones.shuffle()
		for zone in zones:
			if _is_valid_spawn_position(zone):
				return zone

	for _attempt in range(10):
		var random_pos := Vector3(
			randf_range(-template.width / 3.0, template.width / 3.0),
			template.floor_y,
			randf_range(-template.depth / 3.0, template.depth / 3.0)
		)
		if _is_valid_spawn_position(random_pos):
			return random_pos

	return Vector3.INF


## Get world bounds
func get_world_bounds() -> AABB:
	var half_w := template.width / 2.0
	var half_d := template.depth / 2.0
	return AABB(
		room_center + Vector3(-half_w, template.floor_y, -half_d),
		Vector3(template.width, template.height, template.depth)
	)


## Get 2D bounds for map
func get_map_bounds() -> Rect2:
	var half_w := template.width / 2.0
	var half_d := template.depth / 2.0
	return Rect2(
		Vector2(room_center.x - half_w, room_center.z - half_d),
		Vector2(template.width, template.depth)
	)


## Check if point is inside room
func contains_point(world_pos: Vector3) -> bool:
	var bounds := get_world_bounds()
	return bounds.has_point(world_pos)


## Mark room as explored
func mark_explored() -> void:
	if not is_explored:
		is_explored = true
		room_entered.emit(self)


## Spawn torches for lighting
func spawn_torches() -> void:
	var torch_spacing := 6.0
	var torch_height := template.height * 0.3  # Lowered from 50% to 30% to prevent ceiling clipping
	var half_w := template.width / 2.0 - 1.5
	var half_d := template.depth / 2.0 - 1.5

	var torch_positions: Array[Vector3] = []

	# North and South walls
	var torches_x := int(template.width / torch_spacing)
	for i in range(torches_x):
		var x_pos := -half_w + (i + 0.5) * (template.width / float(torches_x))
		if not _is_near_door(Vector3(x_pos, 0, half_d)):
			torch_positions.append(Vector3(x_pos, torch_height, half_d - 0.5))
		if not _is_near_door(Vector3(x_pos, 0, -half_d)):
			torch_positions.append(Vector3(x_pos, torch_height, -half_d + 0.5))

	# East and West walls
	var torches_z := int(template.depth / torch_spacing)
	for i in range(torches_z):
		var z_pos := -half_d + (i + 0.5) * (template.depth / float(torches_z))
		if not _is_near_door(Vector3(half_w, 0, z_pos)):
			torch_positions.append(Vector3(half_w - 0.5, torch_height, z_pos))
		if not _is_near_door(Vector3(-half_w, 0, z_pos)):
			torch_positions.append(Vector3(-half_w + 0.5, torch_height, z_pos))

	for local_pos in torch_positions:
		_create_torch(local_pos)

	# Central light for large rooms
	if template.width >= 12 and template.depth >= 12:
		var central_light := OmniLight3D.new()
		central_light.name = "CentralLight"
		central_light.light_color = Color(0.8, 0.6, 0.4)
		central_light.light_energy = 0.8
		central_light.omni_range = 10.0
		central_light.omni_attenuation = 1.2
		central_light.position = Vector3(0, torch_height, 0)
		add_child(central_light)


## Check if position is near a door
func _is_near_door(local_pos: Vector3) -> bool:
	for door in template.doors:
		var door_pos: Vector3 = door.get("position", Vector3.ZERO)
		var door_width: float = door.get("width", 4.0)
		if local_pos.distance_to(door_pos) < door_width:
			return true
	return false


## Seal doors that don't connect to other rooms
func seal_unused_doors() -> void:
	var w := float(template.width)
	var d := float(template.depth)
	var h := float(template.height)
	var floor_y := template.floor_y
	var half_w := w / 2.0
	var half_d := d / 2.0

	for dir in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		if template.has_door_on_side(dir) and not connected_rooms.has(dir):
			var door := template.get_door_on_side(dir)
			var door_width: float = door.get("width", 4.0)
			_seal_door_gap(dir, door_width, w, d, h, floor_y, half_w, half_d)


## Create wall segment to seal unused door
func _seal_door_gap(dir: Vector3, door_width: float, _w: float, _d: float, h: float, floor_y: float, half_w: float, half_d: float) -> void:
	var seal_wall := CSGBox3D.new()
	seal_wall.name = "SealedDoor_%s" % _dir_to_string(dir)
	seal_wall.material = wall_material
	seal_wall.use_collision = true

	match dir:
		Vector3.FORWARD:
			seal_wall.size = Vector3(door_width, h, wall_thickness)
			seal_wall.position = Vector3(0, floor_y + h / 2.0, half_d + wall_thickness / 2.0)
		Vector3.BACK:
			seal_wall.size = Vector3(door_width, h, wall_thickness)
			seal_wall.position = Vector3(0, floor_y + h / 2.0, -half_d - wall_thickness / 2.0)
		Vector3.RIGHT:
			seal_wall.size = Vector3(wall_thickness, h, door_width)
			seal_wall.position = Vector3(half_w + wall_thickness / 2.0, floor_y + h / 2.0, 0)
		Vector3.LEFT:
			seal_wall.size = Vector3(wall_thickness, h, door_width)
			seal_wall.position = Vector3(-half_w - wall_thickness / 2.0, floor_y + h / 2.0, 0)

	add_child(seal_wall)
	print("[DungeonRoom] Sealed unused door on %s side of %s" % [_dir_to_string(dir), room_id])


## Convert direction to string
func _dir_to_string(dir: Vector3) -> String:
	if dir == Vector3.FORWARD:
		return "North"
	elif dir == Vector3.BACK:
		return "South"
	elif dir == Vector3.RIGHT:
		return "East"
	elif dir == Vector3.LEFT:
		return "West"
	return "Unknown"


## Create torch at position
func _create_torch(local_pos: Vector3) -> void:
	var half_w := template.width / 2.0 - 1.5
	var half_d := template.depth / 2.0 - 1.5

	var facing := Vector3.ZERO
	if abs(local_pos.x - (half_w - 0.5)) < 0.1:
		facing = Vector3.LEFT
	elif abs(local_pos.x - (-half_w + 0.5)) < 0.1:
		facing = Vector3.RIGHT
	elif abs(local_pos.z - (half_d - 0.5)) < 0.1:
		facing = Vector3.BACK
	elif abs(local_pos.z - (-half_d + 0.5)) < 0.1:
		facing = Vector3.FORWARD
	else:
		facing = -local_pos.normalized()
		facing.y = 0

	TorchProp.spawn_wall_torch(self, local_pos, facing)
