class_name Hitbox
extends Area3D
## Damage zone (layer 4). Bullets call apply_hit(). No friendly fire between enemies.

@export var damage_multiplier: float = 1.0

var _health: HealthComponent


func _ready() -> void:
	var n: Node = get_parent()
	while n != null and _health == null:
		_health = n.get_node_or_null("HealthComponent") as HealthComponent
		n = n.get_parent()


func apply_hit(damage: float, source: Node, _point: Vector3) -> void:
	if _health == null:
		return
	var victim := _health.get_parent()
	if source != null and source.is_in_group("enemy") and victim.is_in_group("enemy"):
		return
	_health.take_damage(damage * damage_multiplier, source)
