## dalhurst.gd - Dalhurst Port City (Tier 4 Major City)
## Major port city on the bay, largest commercial port for the capital Emmenburg
## 18 warships in harbor, 2600 troops garrison
## Contains: The Gilded Grog Tavern, Shipwright Guild, Lady Nightshade's Curiosities,
## Harbormaster's Office, Bounty Board, Multiple Merchants, Harbor Area
##
## NOTE: All static geometry and NPCs are defined in dalhurst.tscn
## This script only handles runtime setup like navigation and day/night cycle
extends Node3D

const ZONE_ID := "city_dalhurst"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	_setup_spawn_point_metadata()
	_setup_navigation()
	_setup_day_night_cycle()
	print("[Dalhurst] Port city loaded - Tier 4 Major City")


## Setup spawn point metadata for spawn points defined in .tscn
func _setup_spawn_point_metadata() -> void:
	var spawn_points := $SpawnPoints
	for child in spawn_points.get_children():
		child.set_meta("spawn_id", child.name)


## Setup dynamic day/night lighting
func _setup_day_night_cycle() -> void:
	DayNightCycle.add_to_level(self)


## Setup navigation mesh for NPCs
func _setup_navigation() -> void:
	if not nav_region:
		nav_region = $NavigationRegion3D

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
		print("[Dalhurst] Navigation mesh baked!")
