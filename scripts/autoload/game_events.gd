extends Node
## Global event bus (autoload "GameEvents").

signal shot_fired(pos: Vector3, loudness: float, shooter: Node)
signal enemy_died(enemy: Node)
signal contact_reported(pos: Vector3, reporter: Node)
