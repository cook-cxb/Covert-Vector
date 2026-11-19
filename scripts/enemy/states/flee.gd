extends EnemyState
## Panics and sprints away from the threat, then leaves the site.
## data: { "from": Vector3 }

@export var flee_distance: float = 120.0
@export var flee_timeout: float = 30.0
@export var exit_tolerance: float = 3.0

var _dest: Vector3 = Vector3.ZERO
var _t: float = 0.0


func enter(data: Dictionary = {}) -> void:
	_t = flee_timeout
	enemy.set_crouched(false)
	enemy.in_cover = false
	if enemy.coordinator:
		enemy.coordinator.release_cover(enemy)
	var from: Vector3 = data.get("from", enemy.global_position)
	if enemy.coordinator and not data.has("from"):
		from = enemy.coordinator.shared_lkp
	var away := enemy.global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.BACK
	_dest = enemy.snap_to_nav(enemy.global_position + away * flee_distance)


func physics_update(delta: float) -> void:
	_t -= delta
	if enemy.is_at(_dest, exit_tolerance) or _t <= 0.0:
		enemy.rout()
		return
	enemy.move_to(_dest, enemy.run_speed, delta)
