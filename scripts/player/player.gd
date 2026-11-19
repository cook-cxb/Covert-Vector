extends CharacterBody3D
## First-person player. Layer 2, group "player".

signal scope_toggled(active: bool)

@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var acceleration: float = 10.0
@export var gravity: float = 9.8
@export var mouse_sensitivity: float = 0.0025
@export var normal_fov: float = 75.0
@export var scope_fov: float = 12.0
@export var max_pitch_degrees: float = 85.0
@export var footstep_base_db: float = -12.0
@export var rifle_offset: Vector3 = Vector3(0.18, -0.18, -0.4)

@export var respawn_delay: float = 2.0
@export var flash_alpha: float = 0.5
@export var flash_fade: float = 0.35

var scoped: bool = false
var dead: bool = false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var scope_camera: Camera3D = $ScopeCamera
@onready var rifle: Node3D = $Rifle
@onready var stance: StanceController = $StanceController
@onready var visibility: VisibilityComponent = $VisibilityComponent
@onready var footsteps: AudioStreamPlayer3D = $Footsteps
@onready var health: HealthComponent = $HealthComponent
@onready var flash_rect: ColorRect = $DamageFlash/Rect


func _ready() -> void:
	add_to_group("player")
	_ensure_input_actions()
	camera.fov = normal_fov
	scope_camera.fov = scope_fov
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func _on_damaged(_amount: float, _source: Node) -> void:
	flash_rect.color.a = flash_alpha
	var t := create_tween()
	t.tween_property(flash_rect, "color:a", 0.0 if not dead else flash_alpha, flash_fade)


func _on_died(_source: Node) -> void:
	dead = true
	flash_rect.color.a = flash_alpha
	get_tree().create_timer(respawn_delay).timeout.connect(func() -> void: get_tree().reload_current_scene())


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	var motion := event as InputEventMouseMotion
	if motion:
		var s := mouse_sensitivity * (scope_fov / normal_fov if scoped else 1.0)
		rotate_y(-motion.relative.x * s)
		head.rotate_x(-motion.relative.y * s)
		var limit := deg_to_rad(max_pitch_degrees)
		head.rotation.x = clampf(head.rotation.x, -limit, limit)
	elif event.is_action_pressed("aim"):
		set_scoped(not scoped)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (global_transform.basis * Vector3(input.x, 0.0, input.y)).normalized()

	var speed := walk_speed
	if Input.is_action_pressed("sprint") and stance.current == StanceController.Stance.STAND:
		speed = sprint_speed
	speed *= stance.get_speed_multiplier()

	var flat := Vector3(velocity.x, 0.0, velocity.z).lerp(dir * speed, clampf(acceleration * delta, 0.0, 1.0))
	velocity.x = flat.x
	velocity.z = flat.z
	move_and_slide()
	_update_footsteps(flat.length())


func _process(_delta: float) -> void:
	# ScopeCamera and Rifle are siblings of Head, so follow the head every frame.
	scope_camera.global_transform = camera.global_transform
	rifle.global_transform = head.global_transform * Transform3D(Basis.IDENTITY, rifle_offset)


func set_scoped(on: bool) -> void:
	scoped = on
	scope_camera.current = on
	camera.current = not on
	scope_toggled.emit(on)


func get_active_camera() -> Camera3D:
	return scope_camera if scoped else camera


func _update_footsteps(horizontal_speed: float) -> void:
	var loud := maxf(0.01, stance.get_noise_multiplier() * horizontal_speed / sprint_speed)
	footsteps.volume_db = footstep_base_db + linear_to_db(loud)
	if footsteps.stream and horizontal_speed > 0.5 and not footsteps.playing:
		footsteps.play()


func _ensure_input_actions() -> void:
	var keys: Dictionary = {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"sprint": KEY_SHIFT,
		"crouch": KEY_C,
		"prone": KEY_Z,
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action] as Key
		InputMap.action_add_event(action, ev)

	var mouse: Dictionary = {"fire": MOUSE_BUTTON_LEFT, "aim": MOUSE_BUTTON_RIGHT}
	for action in mouse:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var mev := InputEventMouseButton.new()
		mev.button_index = mouse[action] as MouseButton
		InputMap.action_add_event(action, mev)
