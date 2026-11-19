class_name VisibilityComponent
extends Node
## visibility_score = Distance * Lighting * Speed * Stance * CamoMatch (all factors 0..1).
## Enemies call compute_for(observer_position); visibility_score is the cached value
## against the nearest enemy (used by the HUD debug label).

@export var max_distance: float = 150.0  ## beyond this the distance factor is 0
@export var lighting: float = 1.0  ## 0 = pitch dark, 1 = full daylight
@export var min_speed_factor: float = 0.2  ## factor when standing still
@export var camo_open: float = 1.0  ## BiomeCamoMatch without ghillie
@export var camo_ghillie: float = 0.35  ## BiomeCamoMatch with ghillie

var visibility_score: float = 0.0

var _player: CharacterBody3D
var _stance: StanceController


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	_stance = _player.get_node("StanceController") as StanceController


func _physics_process(_delta: float) -> void:
	var nearest: Node3D = null
	var best := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		var n := e as Node3D
		if n == null:
			continue
		var d := _player.global_position.distance_squared_to(n.global_position)
		if d < best:
			best = d
			nearest = n
	visibility_score = compute_for(nearest.global_position) if nearest else 0.0


func compute_for(observer_pos: Vector3) -> float:
	var dist := _player.global_position.distance_to(observer_pos)
	var distance_f := clampf(1.0 - dist / max_distance, 0.0, 1.0)
	var sprint := maxf(0.01, float(_player.get("sprint_speed")))
	var flat := Vector2(_player.velocity.x, _player.velocity.z).length()
	var speed_f := lerpf(min_speed_factor, 1.0, clampf(flat / sprint, 0.0, 1.0))
	var camo := camo_ghillie if _stance.ghillie else camo_open
	return distance_f * lighting * speed_f * _stance.get_visibility_multiplier() * camo
