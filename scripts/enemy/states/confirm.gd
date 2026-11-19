extends EnemyState
## Spotter peeks from cover toward the last known position. Perception does the
## actual confirming (Enemy.player_spotted -> SquadCoordinator.on_spotted);
## the coordinator owns the confirm_time timeout.


func enter(_data: Dictionary = {}) -> void:
	enemy.set_crouched(false)  # stand up to peek


func physics_update(delta: float) -> void:
	enemy.stop(delta)
	if enemy.coordinator:
		enemy.face_toward(enemy.coordinator.shared_lkp, delta)
