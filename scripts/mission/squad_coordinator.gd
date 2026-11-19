class_name SquadCoordinator
extends Node
## Shared squad brain. Owns the shared last known position (LKP), cover reservations,
## role assignment and the morale break. Writes blackboard values on each Enemy and
## dispatches LimboHSM events: contact, cover_reached (by TakeCover), confirmed, flank,
## target_lost, morale_break_*.

signal phase_changed(new_phase: int)

enum Phase { CALM, CONTACT, CONFIRMING, ENGAGING, BROKEN }

@export var squad_path: NodePath = ^"../EnemySquad"
@export var patrol_root_path: NodePath = ^"../Outpost"
@export var confirm_time: float = 5.0  ## seconds the spotter has to confirm a contact
@export var min_flankers: int = 2
@export var flank_distance: float = 30.0
@export var cover_search_radius: float = 50.0
@export var min_cover_distance_from_lkp: float = 8.0
@export var engage_timeout: float = 40.0  ## seconds without LKP refresh before standing down
@export var morale_break_casualties: int = 7  ## squad breaks when this many are dead (7 of 8)
@export var patrol_points_per_enemy: int = 3

var shared_lkp: Vector3 = Vector3.ZERO
var lkp_age: float = 0.0
var has_lkp: bool = false
var phase: Phase = Phase.CALM
var cover_reservations: Dictionary = {}  ## cover Marker3D -> Enemy
var squad: Array[Enemy] = []
var spotter: Enemy = null
var casualties: int = 0

var _confirm_left: float = 0.0
var _squad_size: int = 0
var _morale_done: bool = false
var _cover_points: Array[Node3D] = []


func _ready() -> void:
	GameEvents.contact_reported.connect(on_contact)
	GameEvents.enemy_died.connect(_on_enemy_died)
	call_deferred("_setup")


func _setup() -> void:
	var squad_node := get_node_or_null(squad_path)
	if squad_node == null:
		return
	for c in squad_node.get_children():
		var e := c as Enemy
		if e:
			squad.append(e)
	_squad_size = squad.size()

	for n in get_tree().get_nodes_in_group("cover"):
		var nd := n as Node3D
		if nd:
			_cover_points.append(nd)

	var markers: Array[Node3D] = []
	var root := get_node_or_null(patrol_root_path)
	if root:
		_collect_markers(root, markers)

	for i in squad.size():
		var e := squad[i]
		e.coordinator = self
		e.player_spotted.connect(on_spotted.bind(e))
		e.patrol_points.clear()
		if not markers.is_empty():
			for k in patrol_points_per_enemy:
				e.patrol_points.append(markers[(i + k) % markers.size()])
		e.patrol_index = 0
		e.start()


func _collect_markers(node: Node, out: Array[Node3D]) -> void:
	for c in node.get_children():
		if c is Marker3D:
			out.append(c as Marker3D)
		_collect_markers(c, out)


func _process(delta: float) -> void:
	if has_lkp:
		lkp_age += delta
	match phase:
		Phase.CONFIRMING:
			_confirm_left -= delta
			if _confirm_left <= 0.0:
				_stand_down()
		Phase.ENGAGING:
			if lkp_age > engage_timeout:
				_stand_down()


# --- Queries ----------------------------------------------------------------

func get_alive() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in squad:
		if e.is_combatant():
			out.append(e)
	return out


func get_phase_name() -> String:
	return String(Phase.keys()[phase])


# --- Contact / confirmation ---------------------------------------------------

func on_contact(pos: Vector3, _reporter: Node) -> void:
	if phase == Phase.BROKEN or squad.is_empty():
		return
	_update_lkp(pos)
	if phase == Phase.CALM:
		_start_contact()


func on_spotted(pos: Vector3, enemy: Enemy) -> void:
	if squad.is_empty():
		return
	_update_lkp(pos)
	match phase:
		Phase.CALM:
			_start_contact()
			_on_confirmed()
		Phase.CONTACT, Phase.CONFIRMING:
			_on_confirmed()
		_:
			pass


func on_in_cover(e: Enemy) -> void:
	if phase == Phase.CONTACT and e == spotter:
		_set_phase(Phase.CONFIRMING)
		_confirm_left = confirm_time


func on_routed(e: Enemy) -> void:
	release_cover(e)


func _start_contact() -> void:
	_set_phase(Phase.CONTACT)
	for e in get_alive():
		e.set_role("")
		e.set_bb(&"after_cover", &"")
		e.send(&"contact")
	_pick_spotter()


func _pick_spotter() -> void:
	spotter = null
	var best := INF
	for e in get_alive():
		var d := e.global_position.distance_squared_to(shared_lkp)
		if d < best:
			best = d
			spotter = e
	if spotter == null:
		_stand_down()
		return
	spotter.set_role("spotter")
	if spotter.in_cover and phase == Phase.CONTACT:
		_set_phase(Phase.CONFIRMING)
		_confirm_left = confirm_time
		spotter.send(&"cover_reached")


func _on_confirmed() -> void:
	_set_phase(Phase.ENGAGING)
	spotter = null
	assign_roles()


func assign_roles() -> void:
	var alive := get_alive()
	if alive.is_empty():
		return
	alive.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_squared_to(shared_lkp) < b.global_position.distance_squared_to(shared_lkp))
	var n := alive.size()
	var flank_count := mini(min_flankers, maxi(0, n - 1))

	var centroid := Vector3.ZERO
	for e in alive:
		centroid += e.global_position
	centroid /= float(n)
	var axis := shared_lkp - centroid
	axis.y = 0.0
	axis = axis.normalized() if axis.length() > 0.1 else Vector3.FORWARD
	var lateral := axis.cross(Vector3.UP).normalized()

	var side := 1.0
	for i in n:
		var e := alive[i]
		if i >= n - flank_count:
			e.set_role("flank")
			var point := shared_lkp + lateral * side * flank_distance - axis * flank_distance * 0.25
			e.set_bb(&"flank_point", e.snap_to_nav(point))
			e.set_bb(&"after_cover", &"")
			side = -side
			e.send(&"flank")
		else:
			e.set_role("base")
			e.set_bb(&"after_cover", &"confirmed")
			if e.in_cover:
				e.send(&"confirmed")
			elif e.current_state_name() != &"TakeCover":
				e.send(&"contact")


func _stand_down() -> void:
	_set_phase(Phase.CALM)
	spotter = null
	for e in get_alive():
		e.set_role("")
		e.set_bb(&"after_cover", &"")
		release_cover(e)
		e.in_cover = false
		e.send(&"target_lost")


# --- LKP ----------------------------------------------------------------------

func _update_lkp(pos: Vector3) -> void:
	shared_lkp = pos
	lkp_age = 0.0
	has_lkp = true
	for e in squad:
		e.set_bb(&"lkp", pos)


# --- Cover --------------------------------------------------------------------

func reserve_cover(enemy: Enemy, threat: Vector3) -> Node3D:
	release_cover(enemy)
	var best: Node3D = null
	var best_score := INF
	var enemy_threat_dist := enemy.global_position.distance_to(threat)
	for c in _cover_points:
		if cover_reservations.has(c) and cover_reservations[c] != enemy:
			continue
		var d := enemy.global_position.distance_to(c.global_position)
		if d > cover_search_radius:
			continue
		var cover_threat_dist := c.global_position.distance_to(threat)
		if cover_threat_dist < min_cover_distance_from_lkp:
			continue
		var score := d + maxf(0.0, enemy_threat_dist - cover_threat_dist) * 0.5
		if score < best_score:
			best_score = score
			best = c
	if best:
		cover_reservations[best] = enemy
	return best


func release_cover(enemy: Enemy) -> void:
	for key in cover_reservations.keys():
		if cover_reservations[key] == enemy:
			cover_reservations.erase(key)


# --- Casualties / morale --------------------------------------------------------

func _on_enemy_died(enemy: Node) -> void:
	var e := enemy as Enemy
	if e == null or not squad.has(e):
		return
	casualties += 1
	release_cover(e)
	for s in get_alive():
		s.morale.on_squad_casualties(casualties, _squad_size)
	if casualties >= morale_break_casualties and not _morale_done:
		_morale_break()
		return
	if e == spotter and (phase == Phase.CONTACT or phase == Phase.CONFIRMING):
		_set_phase(Phase.CONTACT)
		_pick_spotter()


func _morale_break() -> void:
	_morale_done = true
	_set_phase(Phase.BROKEN)
	spotter = null
	for e in get_alive():
		e.set_role("")
		e.set_bb(&"flee_from", shared_lkp)
		match e.morale.roll_outcome():
			MoraleComponent.Outcome.SURRENDER:
				e.send(&"morale_break_surrender")
			MoraleComponent.Outcome.FLEE:
				e.send(&"morale_break_flee")
			MoraleComponent.Outcome.LAST_STAND:
				e.send(&"morale_break_last_stand")


func _set_phase(p: Phase) -> void:
	if p == phase:
		return
	phase = p
	phase_changed.emit(int(p))
