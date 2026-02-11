## fast_travel_shrine.gd - Interactable shrine for fast travel discovery
## When interacted with, discovers the current location via MapTracker
## Registers as a compass POI for easy navigation
class_name FastTravelShrine
extends StaticBody3D

@export var display_name: String = "Shrine of Passage"
@export var shrine_id: String = "shrine_01"

## Visual components
var pillar_mesh: MeshInstance3D
var altar_mesh: MeshInstance3D
var glow_light: OmniLight3D
var particle_effect: GPUParticles3D

## Interaction area
var interaction_area: Area3D

## State
var is_discovered: bool = false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("fast_travel_shrines")

	# Only create visuals/areas if not already present (supports scene instancing)
	if not get_node_or_null("Pillar"):
		_create_visual()
	else:
		pillar_mesh = get_node_or_null("Pillar")
		altar_mesh = get_node_or_null("AltarBase")
		glow_light = get_node_or_null("ShrineGlow")

	if not get_node_or_null("InteractionArea"):
		_create_interaction_area()
	else:
		interaction_area = get_node_or_null("InteractionArea")

	if not get_node_or_null("Collision"):
		_create_collision()

	_register_compass_poi()

	# Check if already discovered
	var zone_id := _get_current_zone_id()
	if MapTracker.is_location_discovered(zone_id):
		is_discovered = true
		_set_discovered_visual()


## Register this shrine as a compass POI
## Uses instance ID for guaranteed uniqueness across scenes
func _register_compass_poi() -> void:
	add_to_group("compass_poi")
	# Use instance_id for guaranteed uniqueness - prevents ghost markers across scenes
	set_meta("poi_id", "shrine_%d" % get_instance_id())
	set_meta("poi_name", display_name)
	set_meta("poi_color", Color(0.4, 0.7, 1.0))  # Mystical blue for shrines


## Create the visual representation (stone pillar/altar with mystical glow)
func _create_visual() -> void:
	# Load shrine texture
	var shrine_texture: Texture2D = load("res://Sprite folders grab bag/shrinetexture.png")

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

	# Rune markings on the base (simple flat quads arranged in circle)
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


## Create interaction area
func _create_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.5  # Interaction range
	collision.shape = shape
	collision.position.y = 1.0
	interaction_area.add_child(collision)

	add_child(interaction_area)


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


## Interaction interface
func interact(_interactor: Node) -> void:
	var zone_id := _get_current_zone_id()

	if not is_discovered:
		# First time discovering this shrine
		is_discovered = true
		MapTracker.discover_location(zone_id)
		_set_discovered_visual()
		_show_discovery_message()
		AudioManager.play_ui_confirm()

	# Always open fast travel UI (discovery happens first if needed)
	_open_fast_travel_ui(zone_id)


func get_interaction_prompt() -> String:
	if is_discovered:
		return "Press [E] to meditate at " + display_name
	return "Press [E] to attune to " + display_name


## Get the current zone ID
func _get_current_zone_id() -> String:
	# Try to find zone ID from parent level
	var parent := get_parent()
	while parent:
		if "ZONE_ID" in parent:
			return parent.get("ZONE_ID")
		parent = parent.get_parent()

	# Fallback to MapTracker's current zone
	return MapTracker.get_current_zone()


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


## Show discovery notification
func _show_discovery_message() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("%s discovered! Location added to map." % display_name)


## Show already discovered message
func _show_already_discovered_message() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		var zone_name := _get_current_zone_id().replace("_", " ").capitalize()
		hud.show_notification("You feel the shrine's power. %s is marked on your map." % zone_name)


## Open the fast travel UI
func _open_fast_travel_ui(zone_id: String) -> void:
	var FastTravelUIClass = load("res://scripts/ui/fast_travel_ui.gd")
	if FastTravelUIClass:
		var ui: FastTravelUI = FastTravelUIClass.get_or_create()
		ui.show_ui(zone_id)


## Static factory method
static func spawn_shrine(parent: Node, pos: Vector3, shrine_name: String = "Shrine of Passage", id: String = "") -> FastTravelShrine:
	var shrine := FastTravelShrine.new()
	shrine.display_name = shrine_name
	shrine.shrine_id = id if not id.is_empty() else shrine_name.to_lower().replace(" ", "_")
	shrine.position = pos
	parent.add_child(shrine)
	return shrine
