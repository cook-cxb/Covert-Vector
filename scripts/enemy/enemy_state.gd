class_name EnemyState
extends LimboState
## Adapter: lets state scripts use enter/exit/physics_update on top of LimboState.

var enemy: Enemy


func _setup() -> void:
	enemy = agent as Enemy


func _enter() -> void:
	enter({})


func _exit() -> void:
	exit()


func _update(delta: float) -> void:
	physics_update(delta)


# Override these in the state scripts.
func enter(_data: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
