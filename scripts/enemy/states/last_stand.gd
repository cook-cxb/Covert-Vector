extends EnemyState
## Desperate: either rushes the last known position or blind-fires while strafing erratically.

@export var rush_chance: float = 0.5
@export var strafe_interval: float = 0.8
@export var strafe_speed_factor: float = 0.6

var _rush: bool = false
var _fire_t: float = 0.0
var _strafe_t: float = 0.0
var _strafe_dir: Vector3 = Vector3.ZERO


func enter(_data: Dictionary = {}) -> void:
	_rush = randf() < rush_chance
	_fire_t = 0.3
	_strafe_t = 0.0
	enemy.set_crouched(false)
	enemy.in_cover = false
	if enemy.coordinator:
		enemy.coordinator.release_cover(enemy)


func physics_update(delta: float) -> void:
	var target := _target()
	if _rush:
		enemy.move_to(target, enemy.run_speed, delta)
	else:
		enemy.face_toward(target, delta)
		_strafe_t -= delta
		if _strafe_t <= 0.0:
			_strafe_t = strafe_interval * randf_range(0.5, 1.5)
			var ang := randf() * TAU
			_strafe_dir = Vector3(cos(ang), 0.0, sin(ang))
		enemy.move_dir(_strafe_dir, enemy.walk_speed * strafe_speed_factor, delta)
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = enemy.last_stand_fire_interval
		enemy.fire_at(target + Vector3.UP, enemy.last_stand_spread_degrees)


func _target() -> Vector3:
	var p := enemy.get_player()
	if enemy.sees_player and p != null:
		return p.global_position
	if enemy.coordinator:
		return enemy.coordinator.shared_lkp
	return enemy.global_position
