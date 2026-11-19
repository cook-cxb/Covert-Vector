extends Node3D
## Bolt-action style rifle. Fires a Bullet and announces every shot on GameEvents.

@export var bullet_scene: PackedScene
@export var muzzle_velocity: float = 820.0  ## m/s
@export var base_damage: float = 50.0
@export var shot_loudness: float = 120.0  ## metres; how far the shot carries
@export var fire_interval: float = 0.6  ## seconds between shots

var _cooldown: float = 0.0

@onready var muzzle: Marker3D = $Muzzle
@onready var shot_audio: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var flash: GPUParticles3D = $GPUParticles3D


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed("fire"):
		_fire()


func _fire() -> void:
	if _cooldown > 0.0 or bullet_scene == null:
		return
	_cooldown = fire_interval

	var shooter := get_parent()
	var bullet := bullet_scene.instantiate() as Bullet
	get_tree().current_scene.add_child(bullet)
	var dir := -muzzle.global_transform.basis.z
	bullet.setup(muzzle.global_position, dir * muzzle_velocity, base_damage, shooter)

	GameEvents.shot_fired.emit(muzzle.global_position, shot_loudness, shooter)

	if shot_audio.stream:
		shot_audio.play()
	flash.restart()
