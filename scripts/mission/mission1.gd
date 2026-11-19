extends Node3D
## Mission 1 bootstrap: makes sure the Terrain3D has data, bakes the navmesh from it,
## and drops the player on the ground at HideSpawn.

@export var nav_bake_size: float = 200.0

@onready var terrain: Terrain3D = $Terrain3D
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var hide_spawn: Marker3D = $HideSpawn
@onready var player: Node3D = $Player


func _ready() -> void:
	_ensure_regions()
	_bake_navigation()
	_place_player()


func _ensure_regions() -> void:
	if terrain.data.get_region_count() > 0:
		return
	# Flat 2x2 blank regions (512x512 m at the default 256 region size).
	for x in [-1, 0]:
		for z in [-1, 0]:
			terrain.data.add_region_blank(Vector2i(x, z))


func _bake_navigation() -> void:
	if not terrain.has_method("generate_nav_mesh_source_geometry"):
		push_error("Mission1: Terrain3D has no generate_nav_mesh_source_geometry")
		return
	var nm := nav_region.navigation_mesh
	if nm == null:
		nm = NavigationMesh.new()
	var half := nav_bake_size * 0.5
	var box := AABB(Vector3(-half, -10.0, -half), Vector3(nav_bake_size, 80.0, nav_bake_size))
	var faces: PackedVector3Array = terrain.generate_nav_mesh_source_geometry(box, false)
	var src := NavigationMeshSourceGeometryData3D.new()
	src.add_faces(faces, Transform3D.IDENTITY)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	nav_region.navigation_mesh = nm


func _place_player() -> void:
	var p := hide_spawn.global_position
	var h: float = terrain.data.get_height(p)
	if is_nan(h):
		h = 0.0
	player.global_position = Vector3(p.x, h + 1.0, p.z)
	player.global_rotation.y = hide_spawn.global_rotation.y
