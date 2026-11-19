class_name Bullet
extends Node3D
## Stepped ballistic projectile: one RayCast3D sweep per physics frame,
## gravity + wind drift. Damages anything with apply_hit() (Hitbox).

@export var gravity: float = 9.81
@export var wind_influence: float = 0.04  ## lateral m/s^2 per m/s of wind
@export var max_lifetime: float = 4.0
@export var min_world_y: float = -100.0

var velocity: Vector3 = Vector3.ZERO
var damage: float = 50.0
var shooter: Node = null

var _age: float = 0.0

@onready var ray: RayCast3D = $RayCast3D


func setup(pos: Vector3, vel: Vector3, dmg: float, from: Node) -> void:
	global_position = pos
	velocity = vel
	damage = dmg
	shooter = from


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > max_lifetime or global_position.y < min_world_y:
		queue_free()
		return

	velocity += Vector3.DOWN * gravity * delta
	velocity += Wind.vector * wind_influence * delta

	var step := velocity * delta
	ray.target_position = ray.to_local(global_position + step)
	ray.force_raycast_update()

	if ray.is_colliding():
		var point := ray.get_collision_point()
		global_position = point
		var collider := ray.get_collider()
		if collider and collider.has_method("apply_hit"):
			collider.call("apply_hit", damage, shooter, point)
		queue_free()
	else:
		global_position += step
