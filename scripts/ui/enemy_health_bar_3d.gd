## enemy_health_bar_3d.gd - Floating health bar above enemies
## Uses a simple colored mesh approach for reliability
extends Node3D
class_name EnemyHealthBar3D

var target_entity: Node = null  ## Can be EnemyBase or any node with current_hp/max_hp
var hide_timer: float = 0.0
var show_duration: float = 3.0

# Bar components
var bar_background: MeshInstance3D
var bar_fill: MeshInstance3D
var bar_width: float = 1.0
var bar_height: float = 0.1

# Materials
var bg_material: StandardMaterial3D
var fill_material: StandardMaterial3D

func _ready() -> void:
	# Create bar meshes
	_create_bar_meshes()

	# Initially hidden
	visible = false

	# Connect to parent if it has compatible signals and properties
	await get_tree().process_frame  # Wait for parent to be ready
	var parent := get_parent()
	_try_connect_to_entity(parent)

func _create_bar_meshes() -> void:
	# Background (dark)
	bar_background = MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(bar_width, bar_height)
	bar_background.mesh = bg_mesh

	bg_material = StandardMaterial3D.new()
	bg_material.albedo_color = Color(0.2, 0.2, 0.2, 0.8)
	bg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	bar_background.material_override = bg_material
	add_child(bar_background)

	# Fill (red/green)
	bar_fill = MeshInstance3D.new()
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(bar_width, bar_height)
	bar_fill.mesh = fill_mesh

	fill_material = StandardMaterial3D.new()
	fill_material.albedo_color = Color(0.8, 0.2, 0.2, 1.0)  # Red
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	bar_fill.material_override = fill_material
	bar_fill.position.z = -0.01  # Slightly in front
	add_child(bar_fill)

## Try to connect to an entity with compatible HP properties and signals
func _try_connect_to_entity(entity: Node) -> void:
	if not entity:
		return

	# Check if entity has required properties
	if not ("current_hp" in entity and "max_hp" in entity):
		return

	target_entity = entity

	# Connect to damage signal if available (check if not already connected)
	if entity.has_signal("damaged") and not entity.damaged.is_connected(_on_entity_damaged):
		entity.damaged.connect(_on_entity_damaged)

	# Connect to death/destroyed signal if available (check if not already connected)
	if entity.has_signal("died") and not entity.died.is_connected(_on_entity_died):
		entity.died.connect(_on_entity_died)
	elif entity.has_signal("destroyed") and not entity.destroyed.is_connected(_on_entity_destroyed):
		entity.destroyed.connect(_on_entity_destroyed)

## Set target entity manually (for spawners or other non-EnemyBase entities)
func set_target(entity: Node) -> void:
	_try_connect_to_entity(entity)

func _process(delta: float) -> void:
	if not visible:
		return

	# Update bar fill based on health
	if target_entity:
		var health_percent: float = float(target_entity.current_hp) / float(target_entity.max_hp)
		health_percent = clampf(health_percent, 0.0, 1.0)

		# Scale and reposition fill bar
		bar_fill.scale.x = health_percent
		bar_fill.position.x = (health_percent - 1.0) * bar_width * 0.5

		# Color based on health
		if health_percent > 0.6:
			fill_material.albedo_color = Color(0.2, 0.8, 0.2, 1.0)  # Green
		elif health_percent > 0.3:
			fill_material.albedo_color = Color(0.8, 0.8, 0.2, 1.0)  # Yellow
		else:
			fill_material.albedo_color = Color(0.8, 0.2, 0.2, 1.0)  # Red

	# Hide after timer
	if hide_timer > 0:
		hide_timer -= delta
		if hide_timer <= 0:
			visible = false

func _on_entity_damaged(_amount: int, _damage_type: Enums.DamageType, _attacker: Node) -> void:
	visible = true
	hide_timer = show_duration

func _on_entity_died(_killer: Node) -> void:
	visible = false

func _on_entity_destroyed(_destroyer: Node) -> void:
	visible = false

func show_bar(duration: float = 3.0) -> void:
	visible = true
	hide_timer = duration

func hide_bar() -> void:
	visible = false
	hide_timer = 0.0
