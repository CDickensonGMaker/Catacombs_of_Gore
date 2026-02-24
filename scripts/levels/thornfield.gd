## thornfield.gd - Thornfield Forest Hamlet (Tier 1 Hamlet)
## Small forest hamlet northeast of Elder Moor
## Theme: Woodcutters and hunters living on the forest edge
## Contains: General Store, Blacksmith, Hunter's Lodge, and quest giver Marek
##
## NOTE: All terrain, buildings, and decorations are pre-placed in the .tscn file
## This script only handles: NPC spawning, door connections, interactables, navigation
extends Node3D

const ZONE_ID := "thornfield"
const ZONE_SIZE := 100.0  # Matches WorldGrid.CELL_SIZE

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	# Only register with PlayerGPS if we're the main scene (have Player node)
	# When loaded as a streaming cell, Player is stripped - don't touch GPS
	var is_main_scene: bool = get_node_or_null("Player") != null

	if is_main_scene:
		if PlayerGPS:
			var coords := WorldGrid.get_location_coords(ZONE_ID)
			PlayerGPS.set_position(coords)

		# Track location for quest objectives (only if main scene)
		if QuestManager:
			QuestManager.on_location_reached(ZONE_ID)

		# Day/night only needed when we're the main scene
		DayNightCycle.force_takeover(self)

	# Apply materials to CSG nodes (they default to white in .tscn)
	_apply_materials()
	_spawn_npcs()
	_spawn_interactables()
	_spawn_doors()
	_setup_spawn_point_metadata()
	_setup_navigation()
	_setup_cell_streaming()
	print("[Thornfield] Forest hamlet loaded - Woodcutters & Hunters Theme")


## Apply materials to all CSG geometry in the scene
## The .tscn file has CSG nodes but no materials assigned (default white)
func _apply_materials() -> void:
	# Create materials for forest hamlet theme
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.28, 0.35, 0.22)  # Forest grass green
	ground_mat.roughness = 0.9
	ground_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.42, 0.38, 0.32)  # Dirt path brown
	road_mat.roughness = 0.95
	road_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.45, 0.32, 0.22)  # Wood brown
	wood_mat.roughness = 0.85
	wood_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.45, 0.43, 0.40)  # Stone gray
	stone_mat.roughness = 0.9
	stone_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.35, 0.28, 0.22)  # Dark wood/thatch
	roof_mat.roughness = 0.85
	roof_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var tree_trunk_mat := StandardMaterial3D.new()
	tree_trunk_mat.albedo_color = Color(0.35, 0.25, 0.18)  # Bark brown
	tree_trunk_mat.roughness = 0.9
	tree_trunk_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var tree_foliage_mat := StandardMaterial3D.new()
	tree_foliage_mat.albedo_color = Color(0.18, 0.35, 0.15)  # Dark forest green
	tree_foliage_mat.roughness = 0.8
	tree_foliage_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.55, 0.42, 0.30)  # Cut lumber
	log_mat.roughness = 0.85
	log_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var stump_mat := StandardMaterial3D.new()
	stump_mat.albedo_color = Color(0.40, 0.30, 0.22)  # Stump brown
	stump_mat.roughness = 0.9
	stump_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.48, 0.46, 0.44)  # Gray rock
	rock_mat.roughness = 0.95
	rock_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.35, 0.35, 0.38)  # Iron gray
	metal_mat.roughness = 0.6
	metal_mat.metallic = 0.4
	metal_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var pelt_mat := StandardMaterial3D.new()
	pelt_mat.albedo_color = Color(0.5, 0.4, 0.32)  # Fur/hide color
	pelt_mat.roughness = 0.95
	pelt_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var campfire_stone_mat := StandardMaterial3D.new()
	campfire_stone_mat.albedo_color = Color(0.25, 0.24, 0.23)  # Fire-darkened stone
	campfire_stone_mat.roughness = 0.95
	campfire_stone_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Apply to Terrain
	var terrain: Node3D = get_node_or_null("Terrain")
	if terrain:
		var ground: CSGBox3D = terrain.get_node_or_null("Ground")
		if ground:
			ground.material = ground_mat

		var main_road: CSGBox3D = terrain.get_node_or_null("MainRoad")
		if main_road:
			main_road.material = road_mat

		var cross_path: CSGBox3D = terrain.get_node_or_null("CrossPath")
		if cross_path:
			cross_path.material = road_mat

		var lodge_path: CSGBox3D = terrain.get_node_or_null("LodgePath")
		if lodge_path:
			lodge_path.material = road_mat

	# Apply to Buildings
	var buildings: Node3D = get_node_or_null("Buildings")
	if buildings:
		for building in buildings.get_children():
			if building is Node3D:
				_apply_building_materials(building, wood_mat, stone_mat, roof_mat)

		# Special handling for anvil
		var anvil: Node3D = buildings.get_node_or_null("Anvil")
		if anvil:
			for part in anvil.get_children():
				if part is CSGBox3D:
					part.material = metal_mat

	# Apply to Decorations
	var decorations: Node3D = get_node_or_null("Decorations")
	if decorations:
		# Trees
		var trees: Node3D = decorations.get_node_or_null("Trees")
		if trees:
			for tree in trees.get_children():
				_apply_tree_materials(tree, tree_trunk_mat, tree_foliage_mat)

		# Stumps
		var stumps: Node3D = decorations.get_node_or_null("Stumps")
		if stumps:
			for stump_node in stumps.get_children():
				_apply_stump_materials(stump_node, stump_mat, wood_mat, metal_mat)

		# Lumber piles
		var lumber_piles: Node3D = decorations.get_node_or_null("LumberPiles")
		if lumber_piles:
			for pile in lumber_piles.get_children():
				for log in pile.get_children():
					if log is CSGCylinder3D:
						log.material = log_mat

		# Rocks
		var rocks: Node3D = decorations.get_node_or_null("Rocks")
		if rocks:
			for rock in rocks.get_children():
				if rock is CSGSphere3D:
					rock.material = rock_mat

		# Hunting racks
		var hunting_racks: Node3D = decorations.get_node_or_null("HuntingRacks")
		if hunting_racks:
			for rack in hunting_racks.get_children():
				_apply_hunting_rack_materials(rack, wood_mat, pelt_mat)

	# Apply to Lights (campfire stones)
	var lights: Node3D = get_node_or_null("Lights")
	if lights:
		for campfire in lights.get_children():
			var stone_ring: CSGTorus3D = campfire.get_node_or_null("StoneRing")
			if stone_ring:
				stone_ring.material = campfire_stone_mat

	print("[Thornfield] Applied materials to CSG geometry")


## Apply materials to a building structure
func _apply_building_materials(building: Node3D, wood_mat: StandardMaterial3D, stone_mat: StandardMaterial3D, roof_mat: StandardMaterial3D) -> void:
	for child in building.get_children():
		if child is CSGBox3D:
			var child_name: String = child.name.to_lower()
			if "roof" in child_name:
				child.material = roof_mat
			elif "floor" in child_name:
				child.material = stone_mat
			else:
				# Walls, posts
				child.material = wood_mat


## Apply materials to a tree
func _apply_tree_materials(tree: Node3D, trunk_mat: StandardMaterial3D, foliage_mat: StandardMaterial3D) -> void:
	for child in tree.get_children():
		if child is CSGCylinder3D:
			var child_name: String = child.name.to_lower()
			if "trunk" in child_name:
				child.material = trunk_mat
			elif "foliage" in child_name:
				child.material = foliage_mat


## Apply materials to tree stump with axe
func _apply_stump_materials(stump_node: Node3D, stump_mat: StandardMaterial3D, wood_mat: StandardMaterial3D, metal_mat: StandardMaterial3D) -> void:
	for child in stump_node.get_children():
		if child is CSGCylinder3D:
			var child_name: String = child.name.to_lower()
			if "stump" in child_name:
				child.material = stump_mat
			elif "handle" in child_name:
				child.material = wood_mat
		elif child is CSGBox3D:
			if "head" in child.name.to_lower():
				child.material = metal_mat


## Apply materials to hunting rack
func _apply_hunting_rack_materials(rack: Node3D, wood_mat: StandardMaterial3D, pelt_mat: StandardMaterial3D) -> void:
	for child in rack.get_children():
		if child is CSGCylinder3D:
			child.material = wood_mat
		elif child is CSGBox3D:
			if "pelt" in child.name.to_lower():
				child.material = pelt_mat


## Spawn NPCs using positions from Marker3D nodes in NPCSpawnPoints
func _spawn_npcs() -> void:
	var npcs := Node3D.new()
	npcs.name = "NPCs"
	add_child(npcs)

	var npc_spawn_points: Node3D = get_node_or_null("NPCSpawnPoints")
	if not npc_spawn_points:
		push_warning("[Thornfield] NPCSpawnPoints node not found")
		return

	# General Store merchant
	var general_store_pos: Marker3D = npc_spawn_points.get_node_or_null("Merchant_GeneralStore")
	if general_store_pos:
		Merchant.spawn_merchant(
			npcs,
			general_store_pos.global_position,
			"Thornfield General Store",
			LootTables.LootTier.COMMON,
			"general"
		)

	# Blacksmith merchant
	var blacksmith_pos: Marker3D = npc_spawn_points.get_node_or_null("Merchant_Blacksmith")
	if blacksmith_pos:
		Merchant.spawn_merchant(
			npcs,
			blacksmith_pos.global_position,
			"Thornfield Smithy",
			LootTables.LootTier.COMMON,
			"blacksmith"
		)

	# Hunter's Lodge keeper
	var lodge_pos: Marker3D = npc_spawn_points.get_node_or_null("Merchant_HuntersLodge")
	if lodge_pos:
		Merchant.spawn_merchant(
			npcs,
			lodge_pos.global_position,
			"Hunter's Lodge",
			LootTables.LootTier.COMMON,
			"general"
		)

	# Quest giver: Marek the Hunter
	var marek_pos: Marker3D = npc_spawn_points.get_node_or_null("QuestGiver_Marek")
	if marek_pos:
		var marek_quests: Array[String] = ["wolf_pack_menace"]
		var marek := QuestGiver.spawn_quest_giver(
			npcs,
			marek_pos.global_position,
			"Marek the Hunter",
			"marek_hunter",
			null,  # use default sprite
			8, 2,  # h_frames, v_frames
			marek_quests
		)
		marek.region_id = ZONE_ID
		marek.faction_id = "human_empire"

	# Elder Vorn - Town Leader (talk target for Tharin's quest chain)
	var elder_vorn := QuestGiver.spawn_quest_giver(
		npcs,
		Vector3(0, 0, 5),  # Near town center
		"Elder Vorn",
		"elder_vorn_thornfield",
		null,  # use default sprite
		8, 2,
		[],  # No quests to give, just receives messages
		true  # is_talk_target
	)
	elder_vorn.region_id = ZONE_ID
	elder_vorn.faction_id = "human_empire"
	elder_vorn.no_quest_dialogue = "Ah, greetings traveler. I am Vorn, elder of this humble settlement. What brings you to Thornfield?"
	var elder_profile := NPCKnowledgeProfile.new()
	elder_profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
	elder_profile.personality_traits = ["wise", "cautious", "hospitable"]
	elder_profile.knowledge_tags = ["thornfield", "local_area", "logging", "trade", "authority"]
	elder_profile.base_disposition = 60
	elder_profile.speech_style = "formal"
	elder_vorn.npc_profile = elder_profile
	print("[Thornfield] Spawned Elder Vorn (town leader)")

	# Woodcutter 1 (green vest guy - fits woodcutter theme)
	var woodcutter1_pos: Marker3D = npc_spawn_points.get_node_or_null("Civilian_Woodcutter1")
	if woodcutter1_pos:
		var woodcutter1 := CivilianNPC.spawn_guy_green_vest(npcs, woodcutter1_pos.global_position, ZONE_ID)
		woodcutter1.npc_name = "Woodcutter"
		if woodcutter1.wander:
			woodcutter1.wander.wander_radius = 6.0

	# Woodcutter 2 (original man sprite for variety)
	var woodcutter2_pos: Marker3D = npc_spawn_points.get_node_or_null("Civilian_Woodcutter2")
	if woodcutter2_pos:
		var woodcutter2 := CivilianNPC.spawn_man(npcs, woodcutter2_pos.global_position, ZONE_ID)
		woodcutter2.npc_name = "Woodcutter"
		if woodcutter2.wander:
			woodcutter2.wander.wander_radius = 5.0

	# Hunter (original man sprite)
	var hunter_pos: Marker3D = npc_spawn_points.get_node_or_null("Civilian_Hunter")
	if hunter_pos:
		var hunter := CivilianNPC.spawn_man(npcs, hunter_pos.global_position, ZONE_ID)
		hunter.npc_name = "Hunter"
		if hunter.wander:
			hunter.wander.wander_radius = 8.0

	# Villager woman (pink lady sprite)
	var villager_pos: Marker3D = npc_spawn_points.get_node_or_null("Civilian_Villager")
	if villager_pos:
		var villager := CivilianNPC.spawn_pink_lady(npcs, villager_pos.global_position, ZONE_ID)
		villager.npc_name = "Villager"
		if villager.wander:
			villager.wander.wander_radius = 4.0

	# Additional random civilians for ambiance (spawn 3 more)
	var random_positions: Array[Vector3] = [
		Vector3(2, 0, 6),   # Near main road
		Vector3(-4, 0, -4), # Between buildings
		Vector3(6, 0, -2),  # Near blacksmith
	]
	for spawn_pos: Vector3 in random_positions:
		var civilian := CivilianNPC.spawn_gendered_random(npcs, spawn_pos, ZONE_ID)
		if civilian.wander:
			civilian.wander.wander_radius = 5.0

	print("[Thornfield] Spawned NPCs")


## Spawn interactables using positions from Marker3D nodes
func _spawn_interactables() -> void:
	var interactables_node: Node3D = get_node_or_null("Interactables")
	if not interactables_node:
		push_warning("[Thornfield] Interactables node not found")
		return

	# Fast travel shrine
	var shrine_pos: Marker3D = interactables_node.get_node_or_null("ShrinePosition")
	if shrine_pos:
		FastTravelShrine.spawn_shrine(
			interactables_node,
			shrine_pos.global_position,
			"Thornfield Shrine",
			"thornfield_shrine"
		)

	# Rest spot
	var rest_pos: Marker3D = interactables_node.get_node_or_null("RestSpotPosition")
	if rest_pos:
		RestSpot.spawn_rest_spot(
			interactables_node,
			rest_pos.global_position,
			"Lodge Bench"
		)

	print("[Thornfield] Spawned interactables")


## Spawn zone doors for interiors only
func _spawn_doors() -> void:
	var doors := Node3D.new()
	doors.name = "Doors"
	add_child(doors)

	# Only spawn doors for INTERIOR connections (buildings, dungeons)
	# Cell boundary transitions are handled by CellStreamer

	print("[Thornfield] Spawned interior doors")




## Setup metadata on spawn points from the scene
func _setup_spawn_point_metadata() -> void:
	var spawn_points_node: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points_node:
		push_warning("[Thornfield] SpawnPoints node not found")
		return

	for child in spawn_points_node.get_children():
		if child is Marker3D:
			child.add_to_group("spawn_points")
			# Extract spawn_id from name (e.g., "SpawnPoint_default" -> "default")
			var spawn_id: String = child.name.replace("SpawnPoint_", "")
			child.set_meta("spawn_id", spawn_id)


## Setup navigation mesh for NPCs
func _setup_navigation() -> void:
	if nav_region:
		var nav_mesh := NavigationMesh.new()
		nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		nav_mesh.geometry_collision_mask = 1
		nav_mesh.cell_size = 0.25
		nav_mesh.cell_height = 0.25
		nav_mesh.agent_height = 2.0
		nav_mesh.agent_radius = 0.5
		nav_mesh.agent_max_climb = 0.5
		nav_mesh.agent_max_slope = 45.0
		nav_region.navigation_mesh = nav_mesh
		call_deferred("_bake_navigation")


func _bake_navigation() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()
		print("[Thornfield] Navigation mesh baked!")


## Setup cell streaming if we're the main scene (has Player/HUD)
## When loaded as a streaming cell, this will be skipped (Player/HUD stripped by CellStreamer)
func _setup_cell_streaming() -> void:
	# Only setup streaming if we're the main scene (we have Player/HUD)
	var player: Node = get_node_or_null("Player")
	if not player:
		# We're a streaming cell, not main scene - skip streaming setup
		return

	if not CellStreamer:
		push_warning("[%s] CellStreamer not found" % ZONE_ID)
		return

	var my_coords: Vector2i = WorldGrid.get_location_coords(ZONE_ID)
	CellStreamer.register_main_scene_cell(my_coords, self)
	CellStreamer.start_streaming(my_coords)
	print("[%s] Registered as main scene, streaming started at %s" % [ZONE_ID, my_coords])


