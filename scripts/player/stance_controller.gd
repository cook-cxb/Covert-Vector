class_name StanceController
extends Node
## Stand / crouch / prone. Resizes the parent's capsule and moves the Head.

signal stance_changed(new_stance: int)

enum Stance { STAND, CROUCH, PRONE }

@export_group("Heights")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.2
@export var prone_height: float = 0.6
@export var eye_offset: float = 0.15  ## eye is this far below the top of the capsule
@export var transition_speed: float = 8.0

@export_group("Speed multipliers")
@export var stand_speed_mult: float = 1.0
@export var crouch_speed_mult: float = 0.55
@export var prone_speed_mult: float = 0.25

@export_group("Footstep noise multipliers")
@export var stand_noise_mult: float = 1.0
@export var crouch_noise_mult: float = 0.5
@export var prone_noise_mult: float = 0.2

@export_group("Visibility multipliers")
@export var stand_visibility_mult: float = 1.0
@export var crouch_visibility_mult: float = 0.6
@export var prone_visibility_mult: float = 0.3

@export_group("Camouflage")
@export var ghillie: bool = false  ## ghillie suit equipped

var current: Stance = Stance.STAND

var _height: float = 1.8
var _body: CharacterBody3D
var _col: CollisionShape3D
var _shape: CapsuleShape3D
var _head: Node3D


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	_col = _body.get_node("CollisionShape3D") as CollisionShape3D
	_shape = _col.shape as CapsuleShape3D
	_head = _body.get_node("Head") as Node3D
	_height = stand_height
	_apply_height(_height)


func _process(delta: float) -> void:
	_height = lerpf(_height, get_target_height(), clampf(transition_speed * delta, 0.0, 1.0))
	_apply_height(_height)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("crouch"):
		set_stance(Stance.STAND if current == Stance.CROUCH else Stance.CROUCH)
	elif event.is_action_pressed("prone"):
		set_stance(Stance.STAND if current == Stance.PRONE else Stance.PRONE)


func set_stance(new_stance: Stance) -> void:
	if new_stance == current:
		return
	current = new_stance
	stance_changed.emit(current)


func get_target_height() -> float:
	match current:
		Stance.CROUCH:
			return crouch_height
		Stance.PRONE:
			return prone_height
	return stand_height


func get_speed_multiplier() -> float:
	match current:
		Stance.CROUCH:
			return crouch_speed_mult
		Stance.PRONE:
			return prone_speed_mult
	return stand_speed_mult


func get_noise_multiplier() -> float:
	match current:
		Stance.CROUCH:
			return crouch_noise_mult
		Stance.PRONE:
			return prone_noise_mult
	return stand_noise_mult


func get_visibility_multiplier() -> float:
	match current:
		Stance.CROUCH:
			return crouch_visibility_mult
		Stance.PRONE:
			return prone_visibility_mult
	return stand_visibility_mult


func _apply_height(h: float) -> void:
	_shape.height = h
	_col.position.y = h * 0.5
	_head.position.y = h - eye_offset
