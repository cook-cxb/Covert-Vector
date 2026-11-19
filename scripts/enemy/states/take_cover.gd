extends EnemyState
## "Cover first, confirm second": run to a reserved cover point and hold fire.
## Blackboard in: lkp, role, after_cover. Blackboard out: cover_point.
## Events out: cover_reached (spotter) or the event named in after_cover (e.g. confirmed).

var _cover: Node3D = null
var _threat: Vector3 = Vector3.ZERO
var _arrived: bool = false


func enter(_data: Dictionary = {}) -> void:
	_arrived = false
	_threat = blackboard.get_var(&"lkp", enemy.global_position)
	enemy.in_cover = false
	enemy.set_crouched(false)
	_cover = null
	if enemy.coordinator:
		_cover = enemy.coordinator.reserve_cover(enemy, _threat)
	blackboard.set_var(&"cover_point", _cover)


func physics_update(delta: float) -> void:
	if not _arrived:
		if _cover != null and not enemy.is_at(_cover.global_position, 1.0):
			enemy.move_to(_cover.global_position, enemy.run_speed, delta)
			return
		_arrived = true
		enemy.in_cover = true
		var low := _cover == null or str(_cover.get_meta("height", "low")) == "low"
		enemy.set_crouched(low)
		if enemy.coordinator:
			enemy.coordinator.on_in_cover(enemy)
		var role: String = blackboard.get_var(&"role", "")
		var after: StringName = blackboard.get_var(&"after_cover", &"")
		if role == "spotter":
			dispatch(&"cover_reached")
			return
		if after != &"":
			blackboard.set_var(&"after_cover", &"")
			dispatch(after)
			return
	enemy.stop(delta)
	var look_at_pos: Vector3 = blackboard.get_var(&"lkp", _threat)
	enemy.face_toward(look_at_pos, delta)
