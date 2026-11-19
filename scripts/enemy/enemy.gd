class_name Enemy
extends CharacterBody3D
## Squad soldier. Layer 3, group "enemy". Behaviour is a LimboHSM built in code.

signal player_spotted(pos: Vector3)

const IdleState := preload("res://scripts/enemy/states/idle.gd")
const PatrolState := preload("res://scripts/enemy/states/patrol.gd")
const TakeCoverState := preload("res://scripts/enemy/states/take_cover.gd")
const ConfirmState := preload("res://scripts/enemy/states/confirm.gd")
const SuppressState := preload("res://scripts/enemy/states/suppress.gd")
const FlankState := preload("res://scripts/enemy/states/flank.gd")
const SurrenderState := preload("res://scripts/enemy/states/surrender.gd")
const FleeState := preload("res://scripts/enemy/states/flee.gd")
const LastStandState := preload("res://scripts/enemy/states/last_stand.gd")
const SearchState := preload("res://scripts/enemy/states/search.gd")

@export_group("Movement")
@export var walk_speed: float = 1.8
@export var run_speed: float = 4.8
@export var turn_speed: float = 6.0
@export var acceleration: float = 12.0
@export var gravity: float = 9.8
@export var arrive_distance: float = 0.9
@export var crouch_head_drop: float = 0.6

@export_group("Vision")
@export var vision_range: float = 90.0
@export var vision_fov_degrees: float = 100.0
@export var vision_vertical_fov_degrees: float = 60.0
@export var detection_rate: float = 2.0  ## awareness gained per second at visibility 1.0
@export var awareness_decay: float = 0.6
@export var perception_interval: float = 0.1
@export var spot_report_interval: float = 0.5

@export_group("Hearing")
@export var hearing_scale: float = 1.0  ## hearing radius = shot loudness * this
@export var heard_position_error: float = 6.0

@export_group("Combat")
@export var bullet_scene: PackedScene
@export var muzzle_velocity: float = 650.0
@export var bullet_damage: float = 15.0
@export var shot_loudness: float = 100.0
@export var suppress_fire_interval: float = 0.7
@export var suppress_spread_degrees: float = 3.0
@export var last_stand_fire_interval: float = 0.25
@export var last_stand_spread_degrees: float = 9.0
@export var lkp_error: float = 12.0  ## metres of error on the contact position when hit
@export var log_transitions: bool = false  ## print every state change

var coordinator: SquadCoordinator
var patrol_points: Array[Node3D] = []
var patrol_index: int = 0
var role: String = ""
var in_cover: bool = false
var awareness: float = 0.0
var sees_player: bool = false
var alive: bool = true
var surrendered: bool = false
var routed: bool = false

var _player: Node3D
var _player_head: Node3D
var _visibility: VisibilityComponent
var _perception_timer: float = 0.0
var _spot_timer: float = 0.0
var _started: bool = false
var _head_base_y: float = 1.6
var _cone_base_y: float = 1.6

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var head: Node3D = $Head
@onready var los_ray: RayCast3D = $Head/RayCast3D
@onready var vision_cone: Area3D = $VisionCone
@onready var vision_shape: CollisionShape3D = $VisionCone/CollisionShape3D
@onready var hearing_area: Area3D = $HearingArea
@onready var hearing_shape: CollisionShape3D = $HearingArea/CollisionShape3D
@onready var head_hitbox: Hitbox = $HeadHitbox
@onready var body_hitbox: Hitbox = $BodyHitbox
@onready var health: HealthComponent = $HealthComponent
@onready var morale: MoraleComponent = $MoraleComponent
@onready var hsm: LimboHSM = $LimboHSM
@onready var muzzle: Marker3D = $Muzzle
@onready var barks: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var label: Label3D = $Label3D


func _ready() -> void:
	add_to_group("enemy")
	_head_base_y = head.position.y
	_cone_base_y = vision_cone.position.y
	_build_vision_cone()
	los_ray.add_exception(self)
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	GameEvents.shot_fired.connect(_on_shot_fired)
	call_deferred("start")

func start() -> void:
	if _started:
		return
	_started = true
	_build_hsm()

func _build_hsm() -> void:
	var idle: LimboState = IdleState.new()
	var patrol: LimboState = PatrolState.new()
	var take_cover: LimboState = TakeCoverState.new()
	var confirm: LimboState = ConfirmState.new()
	var suppress: LimboState = SuppressState.new()
	var flank: LimboState = FlankState.new()
	var surrender: LimboState = SurrenderState.new()
	var flee: LimboState = FleeState.new()
	var last_stand: LimboState = LastStandState.new()
	var search: LimboState = SearchState.new()
	idle.name = &"Idle"
	patrol.name = &"Patrol"
	take_cover.name = &"TakeCover"
	confirm.name = &"Confirm"
	suppress.name = &"Suppress"
	flank.name = &"Flank"
	surrender.name = &"Surrender"
	flee.name = &"Flee"
	last_stand.name = &"LastStand"
	search.name = &"Search"
	for s: LimboState in [idle, patrol, take_cover, confirm, suppress, flank, surrender, flee, last_stand, search]:
		hsm.add_child(s)

	hsm.initial_state = idle

	hsm.add_transition(idle, patrol, &"finished")
	hsm.add_transition(patrol, idle, &"finished")
	hsm.add_transition(idle, take_cover, &"contact")
	hsm.add_transition(patrol, take_cover, &"contact")
	hsm.add_transition(take_cover, confirm, &"cover_reached")
	hsm.add_transition(hsm.ANYSTATE, suppress, &"confirmed")
	hsm.add_transition(hsm.ANYSTATE, flank, &"flank")
	hsm.add_transition(hsm.ANYSTATE, patrol, &"target_lost")
	hsm.add_transition(hsm.ANYSTATE, search, &"unconfirmed")
	hsm.add_transition(search, take_cover, &"contact")
	hsm.add_transition(hsm.ANYSTATE, surrender, &"morale_break_surrender")
	hsm.add_transition(hsm.ANYSTATE, flee, &"morale_break_flee")
	hsm.add_transition(hsm.ANYSTATE, last_stand, &"morale_break_last_stand")

	hsm.active_state_changed.connect(_on_active_state_changed)
	hsm.initialize(self)
	hsm.set_active(true)


# --- Blackboard / events -------------------------------------------------

func set_bb(key: StringName, value: Variant) -> void:
	if hsm.blackboard:
		hsm.blackboard.set_var(key, value)


func send(event: StringName) -> bool:
	return hsm.dispatch(event)


func set_role(r: String) -> void:
	role = r
	set_bb(&"role", r)
	_refresh_label()


func current_state_name() -> StringName:
	var s := hsm.get_active_state()
	return s.name if s else &""


func is_combatant() -> bool:
	return alive and not surrendered and not routed

var _pause_cover: Node3D = null


func alert_paused() -> bool:
	if coordinator == null:
		return false
	var lvl: Variant = coordinator.get(&"alert_level")
	if lvl == null:
		return false
	var limit: Variant = coordinator.get(&"patrol_pause_alert")
	return int(lvl) >= (int(limit) if limit != null else 2)


func hold_in_cover(delta: float) -> void:
	if coordinator == null:
		stop(delta)
		return
	if _pause_cover == null:
		if coordinator.has_method(&"reserve_cover_near"):
			_pause_cover = coordinator.reserve_cover_near(self)
		else:
			_pause_cover = coordinator.reserve_cover(self, global_position)
	if _pause_cover != null and not is_at(_pause_cover.global_position, 1.0):
		in_cover = false
		move_to(_pause_cover.global_position, run_speed, delta)
		return
	in_cover = true
	var low := _pause_cover == null or str(_pause_cover.get_meta("height", "low")) == "low"
	set_crouched(low)
	stop(delta)


func release_pause_cover() -> void:
	if _pause_cover != null:
		if coordinator:
			coordinator.release_cover(self)
		_pause_cover = null

func get_player() -> Node3D:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player:
			_player_head = _player.get_node_or_null("Head") as Node3D
			_visibility = _player.get_node_or_null("VisibilityComponent") as VisibilityComponent
	return _player


func _on_active_state_changed(current: LimboState, previous: LimboState) -> void:
	if log_transitions:
		print("[FSM %s] %s -> %s @ %.2fs" % [name, previous.name if previous else &"-", current.name, Time.get_ticks_msec() / 1000.0])
	_refresh_label()


func _refresh_label() -> void:
	var s := current_state_name()
	label.text = "%s%s" % [s, (" [" + role + "]") if role != "" else ""]


# --- Perception ----------------------------------------------------------

func _build_vision_cone() -> void:
	var half_h := tan(deg_to_rad(vision_fov_degrees * 0.5)) * vision_range
	var half_v := tan(deg_to_rad(vision_vertical_fov_degrees * 0.5)) * vision_range
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3.ZERO,
		Vector3(-half_h, -half_v, -vision_range),
		Vector3(half_h, -half_v, -vision_range),
		Vector3(half_h, half_v, -vision_range),
		Vector3(-half_h, half_v, -vision_range),
	])
	vision_shape.shape = shape


func _physics_process(delta: float) -> void:
	_perception_timer -= delta
	if _perception_timer <= 0.0:
		_perception_timer = perception_interval
		_perceive(perception_interval)


func _perceive(dt: float) -> void:
	if not is_combatant():
		sees_player = false
		return
	var p := get_player()
	if p == null:
		return
	var seen := false
	if vision_cone.overlaps_body(p) and _has_los():
		var vis := _visibility.compute_for(head.global_position) if _visibility else 1.0
		awareness = minf(1.0, awareness + vis * detection_rate * dt)
		seen = true
	else:
		awareness = maxf(0.0, awareness - awareness_decay * dt)
	sees_player = seen and awareness >= 1.0
	_spot_timer -= dt
	if sees_player and _spot_timer <= 0.0:
		_spot_timer = spot_report_interval
		player_spotted.emit(p.global_position)


func _has_los() -> bool:
	if _player_head == null:
		return false
	los_ray.target_position = los_ray.to_local(_player_head.global_position)
	los_ray.force_raycast_update()
	return los_ray.is_colliding() and los_ray.get_collider() == _player


func _on_shot_fired(pos: Vector3, loudness: float, shooter: Node) -> void:
	if not is_combatant() or shooter == self:
		return
	if shooter != null and shooter.is_in_group("enemy"):
		return
	var radius := loudness * hearing_scale
	(hearing_shape.shape as SphereShape3D).radius = radius
	if global_position.distance_to(pos) <= radius:
		report_contact(pos + _random_offset(heard_position_error))


func report_contact(pos: Vector3) -> void:
	GameEvents.contact_reported.emit(pos, self)


func _random_offset(r: float) -> Vector3:
	var a := randf() * TAU
	var d := randf() * r
	return Vector3(cos(a) * d, 0.0, sin(a) * d)


# --- Health --------------------------------------------------------------

func _on_damaged(_amount: float, source: Node) -> void:
	var src := source as Node3D
	if src:
		report_contact(src.global_position + _random_offset(lkp_error))


func _on_died(_source: Node) -> void:
	alive = false
	sees_player = false
	remove_from_group("enemy")
	collision_layer = 0
	head_hitbox.set_deferred("collision_layer", 0)
	body_hitbox.set_deferred("collision_layer", 0)
	hsm.set_active(false)
	set_physics_process(false)
	label.text = "DEAD"
	var t := create_tween()
	t.tween_property(self, "rotation:x", -PI * 0.5, 0.4)
	GameEvents.enemy_died.emit(self)


func rout() -> void:
	routed = true
	sees_player = false
	remove_from_group("enemy")
	collision_layer = 0
	head_hitbox.set_deferred("collision_layer", 0)
	body_hitbox.set_deferred("collision_layer", 0)
	hsm.set_active(false)
	set_physics_process(false)
	visible = false
	if coordinator:
		coordinator.on_routed(self)


# --- Movement helpers (used by states) ------------------------------------

func set_crouched(on: bool) -> void:
	var drop := crouch_head_drop if on else 0.0
	head.position.y = _head_base_y - drop
	vision_cone.position.y = _cone_base_y - drop


func is_at(target: Vector3, tolerance: float = -1.0) -> bool:
	var tol := arrive_distance if tolerance < 0.0 else tolerance
	var d := target - global_position
	d.y = 0.0
	return d.length() <= tol


func move_to(target: Vector3, speed: float, delta: float) -> void:
	var dir := Vector3.ZERO
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
		if agent.target_position.distance_to(target) > 0.5:
			agent.target_position = target
		dir = agent.get_next_path_position() - global_position
	dir.y = 0.0
	if dir.length() < 0.05 and not is_at(target):
		dir = target - global_position
		dir.y = 0.0
	dir = dir.normalized()
	_apply_velocity(dir * speed, delta)
	if dir != Vector3.ZERO:
		face_direction(dir, delta)


func move_dir(dir: Vector3, speed: float, delta: float) -> void:
	_apply_velocity(dir.normalized() * speed, delta)


func stop(delta: float) -> void:
	_apply_velocity(Vector3.ZERO, delta)


func face_toward(pos: Vector3, delta: float) -> void:
	var d := pos - global_position
	d.y = 0.0
	if d.length() > 0.05:
		face_direction(d.normalized(), delta)


func face_direction(dir: Vector3, delta: float) -> void:
	var yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(turn_speed * delta, 0.0, 1.0))


func snap_to_nav(p: Vector3) -> Vector3:
	var map := agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return p
	return NavigationServer3D.map_get_closest_point(map, p)


func _apply_velocity(horizontal: Vector3, delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z).lerp(horizontal, clampf(acceleration * delta, 0.0, 1.0))
	velocity.x = flat.x
	velocity.z = flat.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()


# --- Combat --------------------------------------------------------------

func fire_at(target: Vector3, spread_deg: float) -> void:
	if bullet_scene == null:
		return
	var dir := (target - muzzle.global_position).normalized()
	var spread := deg_to_rad(spread_deg)
	var b := Basis.looking_at(dir, Vector3.UP)
	dir = (b * Vector3(tan(randf_range(-spread, spread)), tan(randf_range(-spread, spread)), -1.0)).normalized()
	var bullet := bullet_scene.instantiate() as Bullet
	get_tree().current_scene.add_child(bullet)
	bullet.setup(muzzle.global_position, dir * muzzle_velocity, bullet_damage, self)
	GameEvents.shot_fired.emit(muzzle.global_position, shot_loudness, self)
