## zoo_card.gd - A single actor card in the Actor Zoo
## Wraps BillboardSprite with state override for QA preview
class_name ZooCard
extends Node3D

signal selected(card: ZooCard)
signal deselected(card: ZooCard)

## The actor data this card displays
var actor_data: Dictionary = {}

## BillboardSprite instance
var billboard: BillboardSprite

## UI Labels
var name_label: Label3D
var state_label: Label3D
var id_label: Label3D
var missing_tag: Label3D

## Selection highlight
var select_highlight: MeshInstance3D

## Baseline marker (Y=0 reference line)
var baseline_marker: MeshInstance3D

## Click detection (handled by actor_zoo.gd raycast now)
var click_area: Area3D  # Kept for potential future use

## State
var is_selected: bool = false
var is_missing_sprite: bool = false

## Zoo override mode - forces animation states to loop
var zoo_forced_state: BillboardSprite.AnimState = BillboardSprite.AnimState.IDLE
var zoo_force_loop: bool = true

## Modified values (for saving patches)
var modified_values: Dictionary = {}


func _ready() -> void:
	# Click detection is handled by actor_zoo.gd via raycasting
	pass


func _process(_delta: float) -> void:
	if not billboard or not zoo_force_loop:
		return

	# If BillboardSprite auto-transitioned back to IDLE but we want a different state,
	# re-trigger it. This makes ATTACK and HURT loop for preview.
	if billboard.current_state != zoo_forced_state:
		# For DEATH: must reset is_dead flag first or set_state() will be blocked
		if zoo_forced_state == BillboardSprite.AnimState.DEATH:
			billboard.is_dead = false
		billboard.current_state = BillboardSprite.AnimState.IDLE  # Unblock set_state
		billboard.set_state(zoo_forced_state)


## Initialize the card with actor data
func setup(data: Dictionary) -> void:
	actor_data = data

	var sprite_path: String = data.get("sprite_path", "")

	# Check for missing/empty sprite
	if sprite_path.is_empty():
		is_missing_sprite = true
		_create_missing_placeholder()
		_create_labels()
		return

	# Try to load sprite
	var texture: Texture2D = null
	if ResourceLoader.exists(sprite_path):
		texture = load(sprite_path)

	if not texture:
		is_missing_sprite = true
		_create_missing_placeholder()
		_create_labels()
		return

	# Create BillboardSprite
	_create_billboard(texture, data)
	_create_labels()
	_create_selection_highlight()
	_create_baseline_marker()


## Create the BillboardSprite
func _create_billboard(texture: Texture2D, data: Dictionary) -> void:
	billboard = BillboardSprite.new()
	billboard.sprite_sheet = texture
	billboard.h_frames = data.get("h_frames", 1)
	billboard.v_frames = data.get("v_frames", 1)
	billboard.pixel_size = data.get("pixel_size", 0.03)
	billboard.offset_y = data.get("offset_y", 0.0)

	# Animation settings
	billboard.idle_frames = data.get("idle_frames", billboard.h_frames)
	billboard.walk_frames = data.get("walk_frames", billboard.h_frames)
	billboard.idle_fps = data.get("idle_fps", 3.0)
	billboard.walk_fps = data.get("walk_fps", 6.0)

	# Separate attack texture if provided
	var attack_path: String = data.get("attack_sprite_path", "")
	if not attack_path.is_empty() and ResourceLoader.exists(attack_path):
		var attack_tex: Texture2D = load(attack_path)
		if attack_tex:
			billboard.attack_texture = attack_tex
			billboard.attack_texture_h_frames = data.get("attack_h_frames", 4)
			billboard.attack_texture_v_frames = data.get("attack_v_frames", 1)
			billboard.attack_frames = data.get("attack_frames", 4)
			billboard.attack_fps = 10.0

	# Separate death texture if provided
	var death_path: String = data.get("death_sprite_path", "")
	if not death_path.is_empty() and ResourceLoader.exists(death_path):
		var death_tex: Texture2D = load(death_path)
		if death_tex:
			billboard.death_texture = death_tex
			billboard.death_texture_h_frames = data.get("death_h_frames", 4)
			billboard.death_texture_v_frames = data.get("death_v_frames", 1)
			billboard.death_frames = data.get("death_frames", 4)
			billboard.death_fps = 6.0

	add_child(billboard)


## Create a red placeholder box for missing sprites
func _create_missing_placeholder() -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 2.0, 0.1)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.2)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = mat

	mesh_instance.mesh = box
	mesh_instance.position = Vector3(0, 1.0, 0)
	add_child(mesh_instance)


## Create name, state, and ID labels
func _create_labels() -> void:
	var actor_name: String = actor_data.get("name", "Unknown")
	var actor_id: String = actor_data.get("id", "unknown")
	var category: String = actor_data.get("category", "")

	# Name label - below the sprite
	name_label = Label3D.new()
	name_label.text = actor_name
	name_label.font_size = 48
	name_label.pixel_size = 0.01
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.position = Vector3(0, -0.3, 0)
	name_label.modulate = Color.RED if is_missing_sprite else Color.WHITE
	add_child(name_label)

	# State label - small text showing current animation state
	state_label = Label3D.new()
	state_label.text = "(IDLE)"
	state_label.font_size = 32
	state_label.pixel_size = 0.008
	state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	state_label.no_depth_test = true
	state_label.position = Vector3(0, -0.5, 0)
	state_label.modulate = Color(0.7, 0.7, 0.7)
	state_label.visible = false  # Hidden by default
	add_child(state_label)

	# ID label - shows actor ID and category
	id_label = Label3D.new()
	id_label.text = "%s (%s)" % [actor_id, category]
	id_label.font_size = 28
	id_label.pixel_size = 0.007
	id_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	id_label.no_depth_test = true
	id_label.position = Vector3(0, -0.7, 0)
	id_label.modulate = Color(0.5, 0.5, 0.5)
	id_label.visible = false  # Hidden by default
	add_child(id_label)

	# Missing sprite tag
	if is_missing_sprite:
		missing_tag = Label3D.new()
		missing_tag.text = "MISSING SPRITE"
		missing_tag.font_size = 36
		missing_tag.pixel_size = 0.01
		missing_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		missing_tag.no_depth_test = true
		missing_tag.position = Vector3(0, 1.5, 0)
		missing_tag.modulate = Color.RED
		add_child(missing_tag)


## Create selection highlight (yellow wireframe box)
func _create_selection_highlight() -> void:
	select_highlight = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 3.0, 2.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.2, 0.5)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_FRONT  # Show back faces (wireframe effect)
	box.material = mat

	select_highlight.mesh = box
	select_highlight.position = Vector3(0, 1.5, 0)
	select_highlight.visible = false
	add_child(select_highlight)


## Create baseline marker (thin line at Y=0)
func _create_baseline_marker() -> void:
	baseline_marker = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 0.02, 2.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.8, 0.3, 0.7)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box.material = mat

	baseline_marker.mesh = box
	baseline_marker.position = Vector3(0, 0, 0)
	baseline_marker.visible = false  # Hidden by default
	add_child(baseline_marker)


## Create click detection area
func _create_click_area() -> void:
	click_area = Area3D.new()
	click_area.collision_layer = 1  # Must be on a layer for ray picking
	click_area.collision_mask = 0
	click_area.input_ray_pickable = true
	click_area.monitorable = false
	click_area.monitoring = false
	click_area.input_event.connect(_on_input_event)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 4.0)  # Larger clickable area
	shape.shape = box
	shape.position = Vector3(0, 1.5, 0)

	click_area.add_child(shape)
	add_child(click_area)


## Handle input events on the card
func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(self)


## Set the preview animation state
func set_preview_state(state: BillboardSprite.AnimState) -> void:
	zoo_forced_state = state

	# Reset death lock if switching away from death
	if billboard:
		billboard.is_dead = false
		billboard.current_state = BillboardSprite.AnimState.IDLE  # Unblock
		billboard.set_state(state)

	# Update state label
	if state_label:
		var state_names: Array[String] = ["IDLE", "WALK", "ATTACK", "HURT", "DEATH"]
		state_label.text = "(%s)" % state_names[state]


## Apply an edit to this card (live preview)
func apply_edit(field: String, value: Variant) -> void:
	if not billboard:
		return

	modified_values[field] = value

	match field:
		"pixel_size":
			billboard.pixel_size = value as float
			if billboard.sprite:
				billboard.sprite.pixel_size = value as float
		"offset_y":
			billboard.offset_y = value as float
			if billboard.sprite:
				billboard.sprite.position.y = value as float
		"h_frames":
			billboard.h_frames = value as int
			if billboard.sprite:
				billboard.sprite.hframes = value as int
		"v_frames":
			billboard.v_frames = value as int
			if billboard.sprite:
				billboard.sprite.vframes = value as int
		"scale":
			var s: float = value as float
			if billboard.sprite:
				billboard.sprite.scale = Vector3(s, s, s)


## Select this card
func select() -> void:
	is_selected = true
	if select_highlight:
		select_highlight.visible = true


## Deselect this card
func deselect() -> void:
	is_selected = false
	if select_highlight:
		select_highlight.visible = false
	deselected.emit(self)


## Toggle name label visibility
func show_name_label(show: bool) -> void:
	if name_label:
		name_label.visible = show


## Toggle ID label visibility
func show_id_label(show: bool) -> void:
	if id_label:
		id_label.visible = show


## Toggle state label visibility
func show_state_label(show: bool) -> void:
	if state_label:
		state_label.visible = show


## Toggle baseline marker visibility
func show_baseline(show: bool) -> void:
	if baseline_marker:
		baseline_marker.visible = show


## Get animation info for sidebar display
func get_animation_info() -> Dictionary:
	var info: Dictionary = {
		"idle": {"row": 0, "frames": actor_data.get("idle_frames", 1), "fps": actor_data.get("idle_fps", 2.0), "separate": false},
		"walk": {"row": 1, "frames": actor_data.get("walk_frames", 1), "fps": actor_data.get("walk_fps", 6.0), "separate": false},
		"attack": {"row": 2, "frames": actor_data.get("attack_frames", 1), "fps": 10.0, "separate": actor_data.has("attack_sprite_path")},
		"hurt": {"row": 3, "frames": 1, "fps": 2.0, "separate": false},
		"death": {"row": 3, "frames": actor_data.get("death_frames", 1), "fps": 6.0, "separate": actor_data.has("death_sprite_path")},
	}
	return info


## Get current values for sidebar
func get_current_values() -> Dictionary:
	var values: Dictionary = {
		"pixel_size": actor_data.get("pixel_size", 0.03),
		"offset_y": actor_data.get("offset_y", 0.0),
		"h_frames": actor_data.get("h_frames", 1),
		"v_frames": actor_data.get("v_frames", 1),
		"scale": 1.0,
	}

	# Apply any modifications
	for key: String in modified_values:
		values[key] = modified_values[key]

	return values


## Check if this card has been modified
func has_modifications() -> bool:
	return not modified_values.is_empty()


## Get patch data for saving
func get_patch_data() -> Dictionary:
	if modified_values.is_empty():
		return {}

	var patch: Dictionary = {}
	patch.merge(modified_values)
	return patch
