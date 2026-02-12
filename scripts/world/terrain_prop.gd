## terrain_prop.gd - 3D terrain props with PS1-style texturing
## Loads GLB models and applies appropriate materials based on biome
class_name TerrainProp
extends Node3D

## Path to the GLB model
@export_file("*.glb") var model_path: String = ""

## Prop type for material selection
@export_enum("hill", "rock", "cliff", "stump", "log", "boulder", "statue") var prop_type: String = "rock"

## Scale multiplier
@export var prop_scale: float = 1.0

## Random rotation on Y axis
@export var random_rotation: bool = true

## Apply PS1-style material
@export var use_ps1_material: bool = true

## Biome for material tinting
@export_enum("forest", "plains", "swamp", "hills", "rocky", "desert", "coast", "undead") var biome: String = "plains"

## The loaded mesh instance
var mesh_instance: Node3D = null


func _ready() -> void:
	if not model_path.is_empty():
		_load_model()

	if random_rotation:
		rotation.y = randf() * TAU


## Load and setup the 3D model
func _load_model() -> void:
	if not ResourceLoader.exists(model_path):
		push_error("[TerrainProp] Model not found: %s" % model_path)
		return

	var scene: PackedScene = load(model_path)
	if not scene:
		push_error("[TerrainProp] Failed to load model: %s" % model_path)
		return

	mesh_instance = scene.instantiate()
	mesh_instance.scale = Vector3.ONE * prop_scale
	add_child(mesh_instance)
	print("[TerrainProp] Loaded model: %s at scale %.2f" % [model_path, prop_scale])

	if use_ps1_material:
		_apply_ps1_material()


## Apply PS1-style material to all meshes
func _apply_ps1_material() -> void:
	if not mesh_instance:
		return

	var material := _create_biome_material()
	_apply_material_recursive(mesh_instance, material)


## Recursively apply material to all MeshInstance3D nodes
func _apply_material_recursive(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		mi.material_override = material

	for child in node.get_children():
		_apply_material_recursive(child, material)


## Create PS1-style material based on biome and prop type
func _create_biome_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.95
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Base color by prop type
	var base_color: Color
	match prop_type:
		"hill":
			base_color = Color(0.35, 0.4, 0.25)  # Grassy hill
		"rock", "boulder":
			base_color = Color(0.45, 0.42, 0.38)  # Gray rock
		"cliff":
			base_color = Color(0.4, 0.38, 0.35)  # Darker rock
		"stump", "log":
			base_color = Color(0.35, 0.25, 0.15)  # Wood brown
		"statue":
			base_color = Color(0.6, 0.58, 0.55)  # Stone gray for statues
		_:
			base_color = Color(0.4, 0.4, 0.4)

	# Tint by biome
	match biome:
		"forest":
			base_color = base_color * Color(0.9, 1.0, 0.85)  # Greenish tint
		"swamp":
			base_color = base_color * Color(0.7, 0.8, 0.65)  # Murky green
		"desert":
			base_color = base_color * Color(1.1, 1.0, 0.8)  # Sandy warm
		"rocky":
			base_color = base_color * Color(0.9, 0.9, 0.95)  # Cool gray
		"undead":
			base_color = base_color * Color(0.7, 0.7, 0.8)  # Desaturated
		"coast":
			base_color = base_color * Color(0.95, 0.95, 0.85)  # Slightly bleached

	mat.albedo_color = base_color

	# Try to load a texture based on prop type
	var tex_path: String = _get_texture_for_prop()
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
		mat.uv1_scale = Vector3(2, 2, 2)  # Tile texture

	return mat


## Statue texture options
const STATUE_TEXTURES: Array[String] = [
	"res://assets/sprites/decorations/sword_statue1.png",
	"res://assets/sprites/decorations/sword_statue2.png",
	"res://assets/sprites/decorations/sword_statue3.png"
]


## Get texture path based on prop type
func _get_texture_for_prop() -> String:
	match prop_type:
		"hill":
			# Use grass or ground texture
			return ""  # Solid color for now
		"rock", "boulder", "cliff":
			return "res://Sprite folders grab bag/stonewall.png"
		"stump", "log":
			return "res://Sprite folders grab bag/wood.png"
		"statue":
			# Randomly pick one of the statue textures
			return STATUE_TEXTURES[randi() % STATUE_TEXTURES.size()]
		_:
			return ""


## Static factory to spawn a terrain prop
static func spawn_prop(parent: Node, pos: Vector3, p_model_path: String,
		p_prop_type: String = "rock", p_biome: String = "plains",
		p_scale: float = 1.0) -> TerrainProp:
	var prop := TerrainProp.new()
	prop.model_path = p_model_path
	prop.prop_type = p_prop_type
	prop.biome = p_biome
	prop.prop_scale = p_scale
	prop.position = pos
	parent.add_child(prop)
	return prop
