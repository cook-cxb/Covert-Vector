extends Node
## Global wind (autoload "Wind"). Slowly drifts toward random targets.

@export var max_speed: float = 8.0  ## m/s, upper bound of horizontal wind
@export var drift_rate: float = 0.35  ## how fast vector moves toward target (1/s)
@export var retarget_min: float = 6.0  ## seconds
@export var retarget_max: float = 14.0  ## seconds

var vector: Vector3 = Vector3.ZERO

var _target: Vector3 = Vector3.ZERO
var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_pick_target()
	vector = _target


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_pick_target()
	vector = vector.lerp(_target, clampf(drift_rate * delta, 0.0, 1.0))


func _pick_target() -> void:
	var angle := _rng.randf_range(0.0, TAU)
	var speed := _rng.randf_range(0.0, max_speed)
	_target = Vector3(cos(angle), 0.0, sin(angle)) * speed
	_timer = _rng.randf_range(retarget_min, retarget_max)
