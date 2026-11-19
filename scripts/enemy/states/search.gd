extends EnemyState
## Unconfirmed contact. Blackboard `search_mode` (set by SquadCoordinator):
##   advance - bound toward the shared lkp (move, hold, repeat)
##   hold    - stay in cover and scan
##   cover   - go to cover and scan (used when alert stays high)
## Sees the player -> dispatch &"contact".

@export var bound_distance: float = 8.0
@export var hold_time: float = 2.0
@export var lkp_reach_distance: float = 3.0
@export var bound_timeout: float = 5.0
@export var scan_arc_degrees: float = 70.0
@export var scan_speed: float = 0.8

var _target: Vector3 = Vector3.ZERO
var _has_target: bool = false
var _hold_left: float = 0.0
var _move_time: float = 0.0
var _scan_t: float = 0.0
var _cover: Node3D = null


func enter(_data: Dictionary = {}) -> void:
	_has_target = false
	_hold_left = 0.0
	_move_time = 0.0
	_scan_t = randf() * TAU
	_cover = null
	enemy.set_crouched(false)


func physics_update(delta: float) -> void:
	if enemy.sees_player:
		dispatch(&"contact")
		return
	var lkp: Vector3 = blackboard.get_var(&"lkp", enemy.global_position)
	var mode: StringName = blackboard.get_var(&"search_mode", &"hold")
	_scan_t += delta
	if mode == &"advance":
		_advance(lkp, delta)
	elif mode == &"cover" or not enemy.in_cover:
		_go_to_cover(lkp, delta)
	else:
		enemy.stop(delta)
		_scan(lkp, delta)


func _advance(lkp: Vector3, delta: float) -> void:
	enemy.in_cover = false
	enemy.set_crouched(false)
	if _hold_left > 0.0:
		_hold_left -= delta
		enemy.stop(delta)
		_scan(lkp, delta)
		return
	if not _has_target:
		var d := lkp - enemy.global_position
		d.y = 0.0
		if d.length() <= lkp_reach_distance:
			enemy.stop(delta)
			_scan(lkp, delta)
			return
		_target = enemy.snap_to_nav(enemy.global_position + d.normalized() * minf(bound_distance, d.length()))
		_has_target = true
		_move_time = 0.0
	_move_time += delta
	if enemy.is_at(_target, 1.0) or _move_time >= bound_timeout:
		_has_target = false
		_hold_left = hold_time
		enemy.stop(delta)
	else:
		enemy.move_to(_target, enemy.run_speed, delta)


func _go_to_cover(lkp: Vector3, delta: float) -> void:
	if _cover == null and enemy.coordinator:
		_cover = enemy.coordinator.reserve_cover(enemy, lkp)
		if _cover == null:
			_cover = enemy.coordinator.reserve_cover_near(enemy)
	if _cover != null and not enemy.is_at(_cover.global_position, 1.0):
		enemy.in_cover = false
		enemy.move_to(_cover.global_position, enemy.run_speed, delta)
		return
	enemy.in_cover = true
	var low := _cover == null or str(_cover.get_meta("height", "low")) == "low"
	enemy.set_crouched(low)
	enemy.stop(delta)
	_scan(lkp, delta)


func _scan(lkp: Vector3, delta: float) -> void:
	var d := lkp - enemy.global_position
	d.y = 0.0
	var base := atan2(-d.x, -d.z) if d.length() > 0.1 else enemy.rotation.y
	var yaw := base + sin(_scan_t * scan_speed) * deg_to_rad(scan_arc_degrees)
	enemy.face_direction(Vector3(-sin(yaw), 0.0, -cos(yaw)), delta)
