extends EnemyState
## Base of fire: hold cover and pin the shared last known position.

var _t: float = 0.0


func enter(_data: Dictionary = {}) -> void:
	_t = randf_range(0.2, enemy.suppress_fire_interval)


func physics_update(delta: float) -> void:
	enemy.stop(delta)
	var target := enemy.coordinator.shared_lkp if enemy.coordinator else enemy.global_position
	enemy.face_toward(target, delta)
	_t -= delta
	if _t <= 0.0:
		_t = enemy.suppress_fire_interval * randf_range(0.8, 1.3)
		enemy.fire_at(target + Vector3.UP, enemy.suppress_spread_degrees)
