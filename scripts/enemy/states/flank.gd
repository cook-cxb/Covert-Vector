extends EnemyState
## Maneuver to a flank point beside the last known position, then fire.
## data: { "flank_point": Vector3 }

@export var flank_arrive_distance: float = 2.0

var _flank_point: Vector3 = Vector3.ZERO
var _fire_t: float = 0.0
var _arrived: bool = false


func enter(data: Dictionary = {}) -> void:
	_flank_point = blackboard.get_var(&"flank_point", enemy.global_position)
	_arrived = false
	_fire_t = 0.5
	enemy.in_cover = false
	enemy.set_crouched(false)
	if enemy.coordinator:
		enemy.coordinator.release_cover(enemy)


func physics_update(delta: float) -> void:
	var lkp := enemy.coordinator.shared_lkp if enemy.coordinator else enemy.global_position
	if not _arrived and not enemy.is_at(_flank_point, flank_arrive_distance):
		enemy.move_to(_flank_point, enemy.run_speed, delta)
		return
	_arrived = true
	enemy.stop(delta)
	enemy.face_toward(lkp, delta)
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = enemy.suppress_fire_interval
		enemy.fire_at(lkp + Vector3.UP, enemy.suppress_spread_degrees)
