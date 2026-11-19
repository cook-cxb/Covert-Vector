extends EnemyState

@export var idle_time_min: float = 2.0
@export var idle_time_max: float = 5.0

var _t: float = 0.0


func enter(_data: Dictionary = {}) -> void:
	enemy.set_crouched(false)
	_t = randf_range(idle_time_min, idle_time_max)


func physics_update(delta: float) -> void:
	if enemy.alert_paused():
		enemy.hold_in_cover(delta)
		return
	enemy.release_pause_cover()
	enemy.stop(delta)
	_t -= delta
	if _t <= 0.0 and not enemy.patrol_points.is_empty():
		dispatch(&"finished")
