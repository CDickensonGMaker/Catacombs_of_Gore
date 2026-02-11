## east_hollow.gd - Fallen/conquered town, overrun by enemies
## Once a peaceful settlement, now a massacre site with hostile forces
## Contains: Defiled shrine, destroyed buildings, enemy patrols, no NPCs
extends Node3D

const ZONE_ID := "town_east_hollow"

## Navigation
var nav_region: NavigationRegion3D

## Fire effect positions for burning buildings
var fire_positions: Array[Vector3] = []


func _ready() -> void:
	_setup_navigation()
	_create_terrain()
	_create_town_walls()
	_spawn_destroyed_buildings()
	_spawn_defiled_shrine()
	_spawn_battle_debris()
	_spawn_fire_effects()
	_spawn_enemies()
	_spawn_portals()
	print("[EastHollow] Fallen town loaded - hostile zone")


func _setup_navigation() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	add_child(nav_region)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.cell_size = 0.3
	nav_mesh.cell_height = 0.2
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0

	nav_region.navigation_mesh = nav_mesh
	call_deferred("_bake_navigation")


func _bake_navigation() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()
		print("[EastHollow] Navigation mesh baked")


## Create blood-stained, scorched terrain
func _create_terrain() -> void:
	# Scorched earth - dark with red-brown stains
	var scorched_mat := StandardMaterial3D.new()
	scorched_mat.albedo_color = Color(0.15, 0.1, 0.08)
	scorched_mat.roughness = 0.95

	# Blood-stained patches
	var blood_mat := StandardMaterial3D.new()
	blood_mat.albedo_color = Color(0.25, 0.08, 0.05)
	blood_mat.roughness = 0.85

	# Ash-covered road
	var ash_mat := StandardMaterial3D.new()
	ash_mat.albedo_color = Color(0.12, 0.11, 0.1)
	ash_mat.roughness = 0.9

	# Main ground
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(100, 1, 100)
	ground.position = Vector3(0, -0.5, 0)
	ground.material = scorched_mat
	ground.use_collision = true
	add_child(ground)

	# Main road through town (covered in ash)
	var main_road := CSGBox3D.new()
	main_road.name = "MainRoad"
	main_road.size = Vector3(7, 0.1, 100)
	main_road.position = Vector3(0, 0.05, 0)
	main_road.material = ash_mat
	main_road.use_collision = false
	add_child(main_road)

	# Blood pools scattered around - abstract representation of massacre
	var blood_positions := [
		Vector3(-12, 0.03, -8),
		Vector3(15, 0.03, 5),
		Vector3(-8, 0.03, 18),
		Vector3(10, 0.03, -20),
		Vector3(-20, 0.03, -15),
		Vector3(5, 0.03, 25),
		Vector3(-15, 0.03, 10),
		Vector3(18, 0.03, -12),
	]

	for i in range(blood_positions.size()):
		var blood := CSGBox3D.new()
		blood.name = "BloodPool_%d" % i
		var size_x := randf_range(1.5, 4.0)
		var size_z := randf_range(1.5, 4.0)
		blood.size = Vector3(size_x, 0.05, size_z)
		blood.position = blood_positions[i]
		blood.rotation.y = randf_range(0, TAU)
		blood.material = blood_mat
		blood.use_collision = false
		add_child(blood)


## Create damaged town walls with red markings
func _create_town_walls() -> void:
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.2, 0.18, 0.15)
	wall_mat.roughness = 0.95

	var damaged_mat := StandardMaterial3D.new()
	damaged_mat.albedo_color = Color(0.15, 0.12, 0.1)
	damaged_mat.roughness = 0.9

	# Red marking material - abstract representation of gruesome decorations
	var marking_mat := StandardMaterial3D.new()
	marking_mat.albedo_color = Color(0.4, 0.08, 0.05)
	marking_mat.roughness = 0.8
	marking_mat.emission_enabled = true
	marking_mat.emission = Color(0.3, 0.05, 0.02)
	marking_mat.emission_energy_multiplier = 0.3

	var wall_height := 5.0
	var wall_thickness := 1.0

	# North wall (damaged, with gaps)
	_create_wall_section(Vector3(-30, wall_height / 2, -45), Vector3(25, wall_height, wall_thickness), wall_mat)
	_create_wall_section(Vector3(20, wall_height / 2, -45), Vector3(30, wall_height, wall_thickness), wall_mat)
	# Gap in north wall (breach point)

	# South wall
	_create_wall_section(Vector3(0, wall_height / 2, 45), Vector3(90, wall_height, wall_thickness), wall_mat)

	# East wall (partially collapsed)
	_create_wall_section(Vector3(45, wall_height / 2, -15), Vector3(wall_thickness, wall_height, 55), wall_mat)
	_create_wall_section(Vector3(45, wall_height / 2, 25), Vector3(wall_thickness, wall_height, 35), damaged_mat)

	# West wall
	_create_wall_section(Vector3(-45, wall_height / 2, 0), Vector3(wall_thickness, wall_height, 90), wall_mat)

	# Red markings on walls - abstract smears/symbols
	_create_wall_marking(Vector3(-44.4, 2.5, -10), Vector3(0.1, 2.0, 3.0), marking_mat)
	_create_wall_marking(Vector3(-44.4, 3.0, 15), Vector3(0.1, 1.5, 2.5), marking_mat)
	_create_wall_marking(Vector3(44.4, 2.0, -5), Vector3(0.1, 2.5, 2.0), marking_mat)
	_create_wall_marking(Vector3(0, 2.5, 44.4), Vector3(4.0, 2.0, 0.1), marking_mat)
	_create_wall_marking(Vector3(-20, 3.0, 44.4), Vector3(3.0, 1.5, 0.1), marking_mat)

	# Collapsed rubble near breach
	for i in range(5):
		var rubble := CSGBox3D.new()
		rubble.name = "WallRubble_%d" % i
		rubble.size = Vector3(randf_range(1.0, 3.0), randf_range(0.5, 1.5), randf_range(1.0, 3.0))
		rubble.position = Vector3(randf_range(-5.0, 5.0), rubble.size.y / 2.0, randf_range(-47.0, -43.0))
		rubble.rotation = Vector3(randf_range(-0.2, 0.2), randf_range(0, TAU), randf_range(-0.2, 0.2))
		rubble.material = damaged_mat
		rubble.use_collision = true
		add_child(rubble)


func _create_wall_section(pos: Vector3, size: Vector3, mat: Material) -> void:
	var wall := CSGBox3D.new()
	wall.name = "WallSection"
	wall.size = size
	wall.position = pos
	wall.material = mat
	wall.use_collision = true
	add_child(wall)


func _create_wall_marking(pos: Vector3, size: Vector3, mat: Material) -> void:
	var marking := CSGBox3D.new()
	marking.name = "WallMarking"
	marking.size = size
	marking.position = pos
	marking.material = mat
	marking.use_collision = false
	add_child(marking)


## Spawn destroyed and burning buildings
func _spawn_destroyed_buildings() -> void:
	var charred_mat := StandardMaterial3D.new()
	charred_mat.albedo_color = Color(0.1, 0.08, 0.06)
	charred_mat.roughness = 0.95

	var burnt_wood_mat := StandardMaterial3D.new()
	burnt_wood_mat.albedo_color = Color(0.15, 0.1, 0.08)
	burnt_wood_mat.roughness = 0.9

	var destroyed_roof_mat := StandardMaterial3D.new()
	destroyed_roof_mat.albedo_color = Color(0.12, 0.08, 0.05)
	destroyed_roof_mat.roughness = 0.95

	# Building positions - mix of destroyed and burning
	var building_data := [
		{"pos": Vector3(-20, 0, -20), "burning": true, "collapsed": false},
		{"pos": Vector3(-20, 0, 0), "burning": false, "collapsed": true},
		{"pos": Vector3(-20, 0, 20), "burning": true, "collapsed": false},
		{"pos": Vector3(20, 0, -25), "burning": false, "collapsed": true},
		{"pos": Vector3(20, 0, -5), "burning": true, "collapsed": false},
		{"pos": Vector3(20, 0, 15), "burning": false, "collapsed": true},
		{"pos": Vector3(-10, 0, -35), "burning": true, "collapsed": false},
		{"pos": Vector3(10, 0, 30), "burning": false, "collapsed": true},
	]

	for i in range(building_data.size()):
		var data: Dictionary = building_data[i]
		var pos: Vector3 = data["pos"]
		var burning: bool = data["burning"]
		var collapsed: bool = data["collapsed"]

		if collapsed:
			_create_collapsed_building(pos, "CollapsedBuilding_%d" % i, charred_mat, destroyed_roof_mat)
		else:
			_create_burning_building(pos, "BurningBuilding_%d" % i, burnt_wood_mat, destroyed_roof_mat, burning)


func _create_collapsed_building(pos: Vector3, building_name: String, wall_mat: Material, roof_mat: Material) -> void:
	var building_root := Node3D.new()
	building_root.name = building_name
	building_root.position = pos
	add_child(building_root)

	var width := randf_range(5.0, 7.0)
	var depth := randf_range(5.0, 7.0)

	# Remaining wall fragments
	for j in range(randi_range(2, 4)):
		var fragment := CSGBox3D.new()
		fragment.name = "WallFragment_%d" % j
		var frag_height := randf_range(1.0, 3.0)
		fragment.size = Vector3(randf_range(1.0, 3.0), frag_height, randf_range(0.3, 0.5))
		fragment.position = Vector3(
			randf_range(-width / 2, width / 2),
			frag_height / 2.0,
			randf_range(-depth / 2, depth / 2)
		)
		fragment.rotation.y = randf_range(0, TAU)
		fragment.rotation.z = randf_range(-0.2, 0.2)
		fragment.material = wall_mat
		fragment.use_collision = true
		building_root.add_child(fragment)

	# Collapsed roof pieces on ground
	for j in range(randi_range(2, 4)):
		var roof_piece := CSGBox3D.new()
		roof_piece.name = "RoofPiece_%d" % j
		roof_piece.size = Vector3(randf_range(1.5, 3.0), 0.3, randf_range(1.5, 3.0))
		roof_piece.position = Vector3(
			randf_range(-width / 2, width / 2),
			randf_range(0.2, 0.8),
			randf_range(-depth / 2, depth / 2)
		)
		roof_piece.rotation = Vector3(randf_range(-0.3, 0.3), randf_range(0, TAU), randf_range(-0.3, 0.3))
		roof_piece.material = roof_mat
		roof_piece.use_collision = true
		building_root.add_child(roof_piece)

	# Debris pile
	var debris := CSGBox3D.new()
	debris.name = "DebrisPile"
	debris.size = Vector3(width * 0.7, 1.0, depth * 0.7)
	debris.position = Vector3(0, 0.5, 0)
	debris.material = wall_mat
	debris.use_collision = true
	building_root.add_child(debris)


func _create_burning_building(pos: Vector3, building_name: String, wall_mat: Material, roof_mat: Material, is_burning: bool) -> void:
	var building_root := Node3D.new()
	building_root.name = building_name
	building_root.position = pos
	add_child(building_root)

	var width := randf_range(5.0, 7.0)
	var depth := randf_range(5.0, 7.0)
	var height := randf_range(3.0, 4.5)

	# Damaged walls (still standing but damaged)
	var walls := CSGBox3D.new()
	walls.name = "Walls"
	walls.size = Vector3(width, height, depth)
	walls.position = Vector3(0, height / 2.0, 0)
	walls.rotation.z = randf_range(-0.05, 0.05)
	walls.material = wall_mat
	walls.use_collision = true
	building_root.add_child(walls)

	# Partially destroyed roof (holes)
	var roof := CSGBox3D.new()
	roof.name = "DamagedRoof"
	roof.size = Vector3(width + 0.5, 0.4, depth + 0.5)
	roof.position = Vector3(randf_range(-0.3, 0.3), height + 0.2, randf_range(-0.3, 0.3))
	roof.rotation = Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1))
	roof.material = roof_mat
	roof.use_collision = true
	building_root.add_child(roof)

	# Record fire position if burning
	if is_burning:
		# Fire on roof
		fire_positions.append(pos + Vector3(0, height + 0.5, 0))
		# Fire inside (visible through damage)
		fire_positions.append(pos + Vector3(randf_range(-1, 1), height * 0.5, randf_range(-1, 1)))


## Spawn defiled/damaged fast travel shrine
func _spawn_defiled_shrine() -> void:
	# Create a damaged shrine instead of using the standard one
	var shrine_pos := Vector3(0, 0, -10)

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.25, 0.2, 0.18)
	stone_mat.roughness = 0.95

	# Defiled marking material
	var defile_mat := StandardMaterial3D.new()
	defile_mat.albedo_color = Color(0.35, 0.08, 0.05)
	defile_mat.roughness = 0.8

	var shrine_root := Node3D.new()
	shrine_root.name = "DefiledShrine"
	shrine_root.position = shrine_pos
	add_child(shrine_root)

	# Cracked/tilted pillar
	var pillar := CSGCylinder3D.new()
	pillar.name = "DamagedPillar"
	pillar.radius = 0.35
	pillar.height = 2.0  # Shorter - broken
	pillar.sides = 6
	pillar.position = Vector3(0, 1.0, 0)
	pillar.rotation.z = 0.15  # Tilted
	pillar.material = stone_mat
	pillar.use_collision = true
	shrine_root.add_child(pillar)

	# Damaged base
	var base := CSGCylinder3D.new()
	base.name = "CrackedBase"
	base.radius = 0.9
	base.height = 0.3
	base.sides = 6
	base.position = Vector3(0, 0.15, 0)
	base.material = stone_mat
	base.use_collision = true
	shrine_root.add_child(base)

	# Broken top piece on ground
	var broken_top := CSGCylinder3D.new()
	broken_top.name = "BrokenTop"
	broken_top.radius = 0.25
	broken_top.height = 0.8
	broken_top.sides = 6
	broken_top.position = Vector3(0.8, 0.2, 0.5)
	broken_top.rotation = Vector3(PI / 2, 0.3, 0)
	broken_top.material = stone_mat
	broken_top.use_collision = true
	shrine_root.add_child(broken_top)

	# Red defilement markings smeared on shrine
	var marking1 := CSGBox3D.new()
	marking1.name = "DefileMarking1"
	marking1.size = Vector3(0.1, 1.2, 0.8)
	marking1.position = Vector3(0.35, 1.0, 0)
	marking1.rotation.z = 0.15
	marking1.material = defile_mat
	marking1.use_collision = false
	shrine_root.add_child(marking1)

	var marking2 := CSGBox3D.new()
	marking2.name = "DefileMarking2"
	marking2.size = Vector3(0.8, 0.6, 0.1)
	marking2.position = Vector3(0, 0.8, 0.35)
	marking2.material = defile_mat
	marking2.use_collision = false
	shrine_root.add_child(marking2)

	# Dim, sickly light instead of normal shrine glow
	var sick_light := OmniLight3D.new()
	sick_light.name = "DefiledGlow"
	sick_light.light_color = Color(0.5, 0.2, 0.15)
	sick_light.light_energy = 0.8
	sick_light.omni_range = 4.0
	sick_light.position = Vector3(0, 1.5, 0)
	shrine_root.add_child(sick_light)

	# Still register as fast travel (but defiled state noted)
	shrine_root.add_to_group("interactable")
	shrine_root.add_to_group("compass_poi")
	shrine_root.add_to_group("shrines")  # For minimap POI detection
	shrine_root.set_meta("poi_id", "defiled_shrine_east_hollow")
	shrine_root.set_meta("poi_name", "Defiled Shrine")
	shrine_root.set_meta("display_name", "Defiled Shrine")
	shrine_root.set_meta("poi_color", Color(0.5, 0.2, 0.15))

	# Spawn actual working fast travel shrine (hidden behind the visuals)
	FastTravelShrine.spawn_shrine(
		self,
		shrine_pos + Vector3(0, 0, 0),
		"East Hollow Shrine (Defiled)",
		"east_hollow_shrine"
	)

	print("[EastHollow] Spawned defiled shrine")


## Spawn battle debris - broken weapons, overturned carts, rubble
func _spawn_battle_debris() -> void:
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.2, 0.15, 0.1)
	wood_mat.roughness = 0.9

	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.25, 0.22, 0.2)
	metal_mat.roughness = 0.7
	metal_mat.metallic = 0.4

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.22, 0.2, 0.18)
	stone_mat.roughness = 0.95

	# Overturned carts
	_create_overturned_cart(Vector3(-8, 0, 5), wood_mat)
	_create_overturned_cart(Vector3(12, 0, -15), wood_mat)

	# Broken weapon piles (abstract - just angular shapes)
	var weapon_positions := [
		Vector3(-5, 0, -5),
		Vector3(8, 0, 10),
		Vector3(-15, 0, -25),
		Vector3(15, 0, 20),
		Vector3(0, 0, 15),
	]

	for i in range(weapon_positions.size()):
		_create_weapon_debris(weapon_positions[i], "WeaponDebris_%d" % i, metal_mat, wood_mat)

	# Rubble piles
	var rubble_positions := [
		Vector3(-25, 0, 5),
		Vector3(25, 0, -10),
		Vector3(-5, 0, -30),
		Vector3(10, 0, 35),
	]

	for i in range(rubble_positions.size()):
		var rubble := CSGBox3D.new()
		rubble.name = "Rubble_%d" % i
		rubble.size = Vector3(randf_range(2.0, 4.0), randf_range(0.5, 1.2), randf_range(2.0, 4.0))
		rubble.position = rubble_positions[i] + Vector3(0, rubble.size.y / 2.0, 0)
		rubble.rotation.y = randf_range(0, TAU)
		rubble.material = stone_mat
		rubble.use_collision = true
		add_child(rubble)


func _create_overturned_cart(pos: Vector3, mat: Material) -> void:
	var cart_root := Node3D.new()
	cart_root.name = "OverturnedCart"
	cart_root.position = pos
	cart_root.rotation.y = randf_range(0, TAU)
	add_child(cart_root)

	# Cart bed (on its side)
	var bed := CSGBox3D.new()
	bed.name = "CartBed"
	bed.size = Vector3(2.5, 0.2, 1.5)
	bed.position = Vector3(0, 0.8, 0)
	bed.rotation.z = PI / 2 + randf_range(-0.2, 0.2)
	bed.rotation.x = randf_range(-0.1, 0.1)
	bed.material = mat
	bed.use_collision = true
	cart_root.add_child(bed)

	# Broken wheels nearby
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.18, 0.14, 0.1)

	for i in range(randi_range(1, 3)):
		var wheel := CSGCylinder3D.new()
		wheel.name = "BrokenWheel_%d" % i
		wheel.radius = 0.35
		wheel.height = 0.1
		wheel.sides = 8
		wheel.position = Vector3(randf_range(-1.5, 1.5), 0.1, randf_range(-1.5, 1.5))
		wheel.rotation.x = PI / 2
		wheel.rotation.z = randf_range(0, TAU)
		wheel.material = wheel_mat
		wheel.use_collision = false
		cart_root.add_child(wheel)


func _create_weapon_debris(pos: Vector3, debris_name: String, metal_mat: Material, wood_mat: Material) -> void:
	var debris_root := Node3D.new()
	debris_root.name = debris_name
	debris_root.position = pos
	add_child(debris_root)

	# Broken sword blade (flat box)
	var blade := CSGBox3D.new()
	blade.name = "BrokenBlade"
	blade.size = Vector3(0.08, 0.6, 0.02)
	blade.position = Vector3(randf_range(-0.3, 0.3), 0.05, randf_range(-0.3, 0.3))
	blade.rotation = Vector3(PI / 2 + randf_range(-0.3, 0.3), randf_range(0, TAU), 0)
	blade.material = metal_mat
	blade.use_collision = false
	debris_root.add_child(blade)

	# Broken spear shaft
	var shaft := CSGBox3D.new()
	shaft.name = "BrokenShaft"
	shaft.size = Vector3(0.05, 1.2, 0.05)
	shaft.position = Vector3(randf_range(-0.5, 0.5), 0.05, randf_range(-0.5, 0.5))
	shaft.rotation = Vector3(PI / 2 + randf_range(-0.1, 0.1), randf_range(0, TAU), 0)
	shaft.material = wood_mat
	shaft.use_collision = false
	debris_root.add_child(shaft)

	# Shield fragment
	if randf() > 0.5:
		var shield := CSGBox3D.new()
		shield.name = "ShieldFragment"
		shield.size = Vector3(0.4, 0.3, 0.05)
		shield.position = Vector3(randf_range(-0.4, 0.4), 0.08, randf_range(-0.4, 0.4))
		shield.rotation = Vector3(randf_range(-0.2, 0.2), randf_range(0, TAU), randf_range(-0.2, 0.2))
		shield.material = wood_mat
		shield.use_collision = false
		debris_root.add_child(shield)


## Spawn fire effects on burning buildings
func _spawn_fire_effects() -> void:
	for pos in fire_positions:
		_create_fire_effect(pos)

	# Additional scattered fires
	var extra_fire_positions := [
		Vector3(-12, 0.5, 8),
		Vector3(8, 0.3, -18),
		Vector3(-5, 0.4, 25),
	]

	for pos in extra_fire_positions:
		_create_fire_effect(pos)


func _create_fire_effect(pos: Vector3) -> void:
	# Use torch props for fire (they have animated flames)
	var fire := TorchProp.new()
	fire.position = pos
	add_child(fire)

	# Add extra light for larger fire feel
	var fire_light := OmniLight3D.new()
	fire_light.name = "FireLight"
	fire_light.light_color = Color(1.0, 0.5, 0.2)
	fire_light.light_energy = 2.0
	fire_light.omni_range = 10.0
	fire_light.position = pos + Vector3(0, 1.5, 0)
	add_child(fire_light)


## Spawn hostile enemies throughout the town
func _spawn_enemies() -> void:
	# Goblin patrol positions (they conquered this town)
	var goblin_positions := [
		Vector3(-15, 0, -15),
		Vector3(15, 0, -20),
		Vector3(-10, 0, 10),
		Vector3(18, 0, 5),
		Vector3(-25, 0, -5),
		Vector3(0, 0, 25),
		Vector3(25, 0, 15),
		Vector3(-8, 0, -30),
	]

	# Skeleton positions (risen from the massacre)
	var skeleton_positions := [
		Vector3(5, 0, -8),
		Vector3(-18, 0, 18),
		Vector3(12, 0, -35),
		Vector3(-30, 0, 10),
		Vector3(8, 0, 15),
	]

	# Goblin archers on elevated positions/walls
	var archer_positions := [
		Vector3(-40, 3.0, 0),  # On west wall
		Vector3(40, 3.0, -10),  # On east wall
		Vector3(0, 3.0, 40),  # On south wall
	]

	# Spawn goblin soldiers
	for pos in goblin_positions:
		_spawn_goblin_soldier(pos)

	# Spawn skeleton shades
	for pos in skeleton_positions:
		_spawn_skeleton(pos)

	# Spawn goblin archers
	for pos in archer_positions:
		_spawn_goblin_archer(pos)

	# Spawn a goblin leader near the defiled shrine (mini-boss)
	_spawn_goblin_leader(Vector3(5, 0, -12))

	print("[EastHollow] Spawned hostile enemies - %d goblins, %d skeletons, %d archers, 1 leader" % [
		goblin_positions.size(),
		skeleton_positions.size(),
		archer_positions.size()
	])


func _spawn_goblin_soldier(pos: Vector3) -> void:
	var sprite: Texture2D = load("res://assets/sprites/enemies/goblin_leader.png")
	if not sprite:
		push_warning("[EastHollow] Failed to load goblin sprite")
		return

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		"res://data/enemies/goblin_soldier.tres",
		sprite,
		4, 4
	)
	if enemy:
		enemy.add_to_group("east_hollow_enemies")


func _spawn_skeleton(pos: Vector3) -> void:
	var sprite: Texture2D = load("res://assets/sprites/enemies/skeleton_shade.png")
	if not sprite:
		push_warning("[EastHollow] Failed to load skeleton sprite")
		return

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		"res://data/enemies/skeleton_shade.tres",
		sprite,
		4, 4
	)
	if enemy:
		enemy.add_to_group("east_hollow_enemies")
		enemy.add_to_group("undead")


func _spawn_goblin_archer(pos: Vector3) -> void:
	var sprite: Texture2D = load("res://assets/sprites/enemies/goblin_archer.png")
	if not sprite:
		push_warning("[EastHollow] Failed to load goblin archer sprite")
		return

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		"res://data/enemies/goblin_archer.tres",
		sprite,
		4, 4
	)
	if enemy:
		enemy.add_to_group("east_hollow_enemies")


func _spawn_goblin_leader(pos: Vector3) -> void:
	var sprite: Texture2D = load("res://assets/sprites/enemies/goblin_leader.png")
	if not sprite:
		push_warning("[EastHollow] Failed to load goblin leader sprite")
		return

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		"res://data/enemies/goblin_leader.tres",
		sprite,
		4, 4
	)
	if enemy:
		enemy.add_to_group("east_hollow_enemies")
		enemy.add_to_group("miniboss")


## Spawn portal connections
func _spawn_portals() -> void:
	# Portal to Aberdeen (south - escape route)
	var aberdeen_portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, 0, 42),
		"res://scenes/levels/aberdeen.tscn",
		"from_east_hollow",
		"Road to Aberdeen"
	)
	aberdeen_portal.rotation.y = PI
	aberdeen_portal.show_frame = false

	# Spawn point from Aberdeen
	var from_aberdeen := Node3D.new()
	from_aberdeen.name = "from_aberdeen"
	from_aberdeen.position = Vector3(0, 0.1, 38)
	from_aberdeen.add_to_group("spawn_points")
	from_aberdeen.set_meta("spawn_id", "from_aberdeen")
	add_child(from_aberdeen)

	# Register as compass POI
	aberdeen_portal.add_to_group("compass_poi")
	aberdeen_portal.set_meta("poi_id", "aberdeen_road")
	aberdeen_portal.set_meta("poi_name", "Aberdeen")
	aberdeen_portal.set_meta("poi_color", Color(0.3, 0.6, 0.3))

	# Portal to Border Wars Graveyard (north through breach)
	var graveyard_portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, 0, -42),
		"res://scenes/levels/border_wars_graveyard.tscn",
		"from_east_hollow",
		"Path to Border Wars Graveyard"
	)
	graveyard_portal.rotation.y = 0
	graveyard_portal.show_frame = false

	# Spawn point from Graveyard
	var from_graveyard := Node3D.new()
	from_graveyard.name = "from_graveyard"
	from_graveyard.position = Vector3(0, 0.1, -38)
	from_graveyard.add_to_group("spawn_points")
	from_graveyard.set_meta("spawn_id", "from_graveyard")
	add_child(from_graveyard)

	# Register as compass POI
	graveyard_portal.add_to_group("compass_poi")
	graveyard_portal.set_meta("poi_id", "graveyard_path")
	graveyard_portal.set_meta("poi_name", "Border Wars Graveyard")
	graveyard_portal.set_meta("poi_color", Color(0.5, 0.3, 0.5))

	print("[EastHollow] Spawned portals to Aberdeen and Border Wars Graveyard")
