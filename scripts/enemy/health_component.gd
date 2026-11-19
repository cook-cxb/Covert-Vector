class_name HealthComponent
extends Node

signal damaged(amount: float, source: Node)
signal died(source: Node)

@export var max_hp: float = 100.0

var hp: float = 100.0
var dead: bool = false


func _ready() -> void:
	hp = max_hp


func take_damage(amount: float, source: Node = null) -> void:
	if dead:
		return
	hp = maxf(0.0, hp - amount)
	damaged.emit(amount, source)
	if hp <= 0.0:
		dead = true
		died.emit(source)
