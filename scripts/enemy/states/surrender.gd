extends EnemyState
## Kneels with hands raised. Stops perceiving and fighting.


func enter(_data: Dictionary = {}) -> void:
	enemy.surrendered = true
	enemy.sees_player = false
	enemy.awareness = 0.0
	enemy.in_cover = false
	enemy.set_crouched(true)
	if enemy.coordinator:
		enemy.coordinator.release_cover(enemy)


func physics_update(delta: float) -> void:
	enemy.stop(delta)
