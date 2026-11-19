extends EnemyState

@export var wait_at_point: float = 1.5
@export var point_tolerance: float = 1.2

var _wait: float = 0.0


func enter(_data: Dictionary = {}) -> void:
	enemy.set_crouched(false)
	enemy.in_cover = false
	_wait = 0.0


func physics_update(delta: float) -> void:
	if enemy.alert_paused():
		enemy.hold_in_cover(delta)
		return
	enemy.release_pause_cover()
	if enemy.patrol_points.is_empty():
		dispatch(&"finished")
		return
	var target := enemy.patrol_points[enemy.patrol_index].global_position
	if enemy.is_at(target, point_tolerance):
		enemy.stop(delta)
		_wait += delta
		if _wait >= wait_at_point:
			_wait = 0.0
			enemy.patrol_index = (enemy.patrol_index + 1) % enemy.patrol_points.size()
	else:
		enemy.move_to(target, enemy.walk_speed, delta)
