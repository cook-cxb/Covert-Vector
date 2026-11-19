class_name MoraleComponent
extends Node
## Morale falls as the squad takes casualties. When the squad breaks,
## roll_outcome() picks Surrender / Flee / Last Stand by weighted chance.

enum Outcome { SURRENDER, FLEE, LAST_STAND }

@export_range(0.0, 1.0) var morale: float = 1.0
@export_range(0.0, 1.0) var discipline: float = 0.4  ## high = holds the line
@export var casualty_penalty: float = 0.9  ## morale lost at 100% squad casualties
@export var surrender_bias: float = 1.0
@export var flee_bias: float = 1.0
@export var last_stand_bias: float = 1.0


func on_squad_casualties(dead: int, total: int) -> void:
	morale = clampf(1.0 - casualty_penalty * float(dead) / float(maxi(total, 1)), 0.0, 1.0)


func roll_outcome() -> Outcome:
	var fear := 1.0 - morale
	var w_surrender := surrender_bias * fear * (1.0 - discipline) + 0.05
	var w_flee := flee_bias * fear * (1.0 - discipline * 0.5) + 0.05
	var w_stand := last_stand_bias * (discipline + (1.0 - fear) * 0.5) + 0.05
	var r := randf() * (w_surrender + w_flee + w_stand)
	if r < w_surrender:
		return Outcome.SURRENDER
	r -= w_surrender
	if r < w_flee:
		return Outcome.FLEE
	return Outcome.LAST_STAND
