## fast_travel_shrine.gd - Decorative shrine (visual/puzzle asset)
## World map now handles fast travel. Shrines remain as visual landmarks
## and potential puzzle elements for dungeons (e.g., Willow Dale).
class_name FastTravelShrine
extends StaticBody3D

@export var display_name: String = "Shrine of Passage"
@export var shrine_id: String = "shrine_01"

## Visual components
var pillar_mesh: MeshInstance3D
var altar_mesh: MeshInstance3D
var glow_light: OmniLight3D

## State (for visual appearance only)
var is_discovered: bool = false


func _ready() -> void:
	# Shrine is now decorative only - world map handles fast travel
	add_to_group("fast_travel_shrines")
	add_to_group("puzzle_element")

	# Remove from interactable group - no longer interactive
	if is_in_group("interactable"):
		remove_from_group("interactable")

	# Only create visuals if not already present (supports scene instancing)
	if not get_node_or_null("Pillar"):
		_create_visual()
	else:
		pillar_mesh = get_node_or_null("Pillar")
		altar_mesh = get_node_or_null("AltarBase")
		glow_light = get_node_or_null("ShrineGlow")

	# Disable interaction area if it exists (from scene instancing)
	var interaction_area: Area3D = get_node_or_null("InteractionArea")
	if interaction_area:
		interaction_area.monitoring = false
		interaction_area.monitorable = false

	if not get_node_or_null("Collision"):
		_create_collision()

	# Check if already discovered (for visual state only)
	var zone_id := _get_current_zone_id()
	if PlayerGPS and PlayerGPS.is_location_discovered(zone_id):
		is_discovered = true
		_set_discovered_visual()


## Create the visual representation (stone pillar/altar with mystical glow)
func _create_visual() -> void:
	# Load shrine texture
	var shrine_texture: Texture2D = load("res://assets/sprites/props/furniture/shrine.png")

	# Materials - PS1 aesthetic with texture
	var stone_mat := StandardMaterial3D.new()
	if shrine_texture:
		stone_mat.albedo_texture = shrine_texture
		stone_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 pixelated look
	else:
		stone_mat.albedo_color = Color(0.45, 0.42, 0.4)
	stone_mat.roughness = 0.95
	stone_mat.metallic = 0.0

	var altar_mat := StandardMaterial3D.new()
	if shrine_texture:
		altar_mat.albedo_texture = shrine_texture
		altar_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		altar_mat.albedo_color = Color(0.85, 0.82, 0.8)  # Slightly darker tint
	else:
		altar_mat.albedo_color = Color(0.35, 0.32, 0.3)
	altar_mat.roughness = 0.9
	altar_mat.metallic = 0.1

	# Stone pillar - central column
	pillar_mesh = MeshInstance3D.new()
	pillar_mesh.name = "Pillar"
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.3
	pillar.bottom_radius = 0.4
	pillar.height = 2.5
	pillar.radial_segments = 6  # Low poly for PS1 look
	pillar_mesh.mesh = pillar
	pillar_mesh.material_override = stone_mat
	pillar_mesh.position.y = 1.25
	add_child(pillar_mesh)

	# Altar base - wider base platform
	altar_mesh = MeshInstance3D.new()
	altar_mesh.name = "AltarBase"
	var altar := CylinderMesh.new()
	altar.top_radius = 0.8
	altar.bottom_radius = 1.0
	altar.height = 0.4
	altar.radial_segments = 6
	altar_mesh.mesh = altar
	altar_mesh.material_override = altar_mat
	altar_mesh.position.y = 0.2
	add_child(altar_mesh)

	# Top cap - glowing crystal holder
	var cap_mesh := MeshInstance3D.new()
	cap_mesh.name = "PillarCap"
	var cap := CylinderMesh.new()
	cap.top_radius = 0.15
	cap.bottom_radius = 0.35
	cap.height = 0.3
	cap.radial_segments = 6
	cap_mesh.mesh = cap
	cap_mesh.material_override = altar_mat
	cap_mesh.position.y = 2.65
	add_child(cap_mesh)

	# Mystical glow orb on top
	var orb_mesh := MeshInstance3D.new()
	orb_mesh.name = "GlowOrb"
	var orb := SphereMesh.new()
	orb.radius = 0.2
	orb.height = 0.4
	orb.radial_segments = 8
	orb.rings = 4
	orb_mesh.mesh = orb

	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.3, 0.6, 0.9)
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(0.4, 0.7, 1.0)
	orb_mat.emission_energy_multiplier = 2.0
	orb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb_mat.albedo_color.a = 0.8
	orb_mesh.material_override = orb_mat
	orb_mesh.position.y = 2.9
	add_child(orb_mesh)

	# Mystical glow light
	glow_light = OmniLight3D.new()
	glow_light.name = "ShrineGlow"
	glow_light.light_color = Color(0.4, 0.7, 1.0)
	glow_light.light_energy = 1.5
	glow_light.omni_range = 6.0
	glow_light.omni_attenuation = 1.5
	glow_light.position.y = 2.9
	add_child(glow_light)

	# Secondary ambient light at base
	var base_light := OmniLight3D.new()
	base_light.name = "BaseGlow"
	base_light.light_color = Color(0.3, 0.5, 0.8)
	base_light.light_energy = 0.5
	base_light.omni_range = 3.0
	base_light.position.y = 0.5
	add_child(base_light)

	# Rune markings on the base
	_create_rune_markings()


## Create simple rune markings around the base
func _create_rune_markings() -> void:
	var rune_mat := StandardMaterial3D.new()
	rune_mat.albedo_color = Color(0.3, 0.5, 0.8, 0.6)
	rune_mat.emission_enabled = true
	rune_mat.emission = Color(0.4, 0.7, 1.0)
	rune_mat.emission_energy_multiplier = 1.0
	rune_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Create 4 rune markers around the base
	for i in range(4):
		var angle := i * (TAU / 4.0)
		var rune := MeshInstance3D.new()
		rune.name = "Rune%d" % i

		var quad := QuadMesh.new()
		quad.size = Vector2(0.3, 0.3)
		rune.mesh = quad
		rune.material_override = rune_mat

		rune.position = Vector3(cos(angle) * 0.9, 0.02, sin(angle) * 0.9)
		rune.rotation.x = -PI / 2  # Flat on ground
		add_child(rune)


## Create collision shape for the pillar
func _create_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 2.5
	collision.shape = shape
	collision.position.y = 1.25
	add_child(collision)


## Get the current zone ID
func _get_current_zone_id() -> String:
	# Try to find zone ID from parent level
	var parent := get_parent()
	while parent:
		if "ZONE_ID" in parent:
			return parent.get("ZONE_ID")
		parent = parent.get_parent()

	# Fallback to PlayerGPS's current zone
	return PlayerGPS.current_location_id if PlayerGPS else ""


## Update visual to discovered state (brighter glow)
func _set_discovered_visual() -> void:
	if glow_light:
		glow_light.light_energy = 2.5
		glow_light.light_color = Color(0.5, 0.8, 1.0)

	# Make orb brighter
	var orb := get_node_or_null("GlowOrb") as MeshInstance3D
	if orb and orb.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = orb.material_override
		mat.emission_energy_multiplier = 4.0


## Static factory method
static func spawn_shrine(parent: Node, pos: Vector3, shrine_name: String = "Shrine of Passage", id: String = "") -> FastTravelShrine:
	var shrine := FastTravelShrine.new()
	shrine.display_name = shrine_name
	shrine.shrine_id = id if not id.is_empty() else shrine_name.to_lower().replace(" ", "_")
	shrine.position = pos
	parent.add_child(shrine)
	return shrine
