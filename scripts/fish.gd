class_name Fish
extends Node3D

## Lake fish. Trout hold loose schools around a drifting anchor point and
## occasionally breach; pike cruise the deeper water alone.
##
## Swimming is fully kinematic and clamped between the lake bed and the surface.
## Convention: the fish faces -Z, and its origin sits at the middle of its body.

const CFG := {
	"trout": {
		"label": "Trout",
		"length": 0.36,
		"back_color": Color(0.24, 0.30, 0.26),
		"flank_color": Color(0.62, 0.64, 0.58),
		"fin_color": Color(0.42, 0.36, 0.28),
		"cruise": 1.5, "dart": 5.4, "accel": 7.0, "turn": 4.5,
		"tail_rate": 5.0, "sep": 0.85, "slot": 2.6,
		"can_breach": true,
	},
	"pike": {
		"label": "Pike",
		"length": 0.92,
		"back_color": Color(0.20, 0.26, 0.14),
		"flank_color": Color(0.52, 0.55, 0.35),
		"fin_color": Color(0.30, 0.30, 0.20),
		"cruise": 1.1, "dart": 6.2, "accel": 9.0, "turn": 3.2,
		"tail_rate": 3.2, "sep": 2.2, "slot": 0.6,
		"can_breach": false,
	},
}

const MIN_DEPTH := 0.9
const FLEE_RADIUS := 10.0

var kind := "trout"
var cfg: Dictionary
var terrain: ForestTerrain
var manager: WildlifeManager
var school_id := 0

var velocity := Vector3.ZERO
var slot := Vector3.ZERO
var _phase := 0.0
var _dart := 0.0
var _breach := 0.0
var _breach_vy := 0.0
var _splashed := false

var body: Node3D
var tail: Node3D
var _pectorals: Array[Node3D] = []

var _rng := RandomNumberGenerator.new()


func setup(kind_name: String, t: ForestTerrain, m: WildlifeManager, sid: int, spawn: Vector3) -> void:
	kind = kind_name
	cfg = CFG[kind_name]
	terrain = t
	manager = m
	school_id = sid
	_rng.randomize()
	_phase = _rng.randf_range(0.0, TAU)

	var s: float = float(cfg.slot)
	slot = Vector3(_rng.randf_range(-s, s), _rng.randf_range(-s * 0.35, s * 0.35), _rng.randf_range(-s, s))

	_build()
	position = spawn
	rotation.y = _rng.randf_range(0.0, TAU)
	velocity = -global_transform.basis.z * float(cfg.cruise)


# --- body ---------------------------------------------------------------------

func _build() -> void:
	var L: float = cfg.length
	var back := CritterBuilder.material(cfg.back_color, 0.42)
	var flank := CritterBuilder.material(cfg.flank_color, 0.30)
	var fin := CritterBuilder.material(cfg.fin_color, 0.55)
	var dark := CritterBuilder.material(Color(0.05, 0.05, 0.06), 0.25)

	body = Node3D.new()
	body.name = "Body"
	add_child(body)

	# Flattened ellipsoid trunk, with a paler belly poking out underneath.
	CritterBuilder.attach(body, CritterBuilder.sphere_mesh(0.5), back,
		Transform3D(Basis().scaled(Vector3(L * 0.30, L * 0.44, L * 1.05)), Vector3.ZERO))
	CritterBuilder.attach(body, CritterBuilder.sphere_mesh(0.5), flank,
		Transform3D(Basis().scaled(Vector3(L * 0.29, L * 0.30, L * 0.92)), Vector3(0, -L * 0.07, L * 0.02)))
	# Snout
	CritterBuilder.attach(body, CritterBuilder.cone_mesh(L * 0.14, L * 0.22, 6), back,
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -L * 0.52)))
	# Eyes
	for sx in [-1.0, 1.0]:
		CritterBuilder.attach(body, CritterBuilder.sphere_mesh(L * 0.045), dark,
			Transform3D(Basis(), Vector3(sx * L * 0.11, L * 0.06, -L * 0.34)))

	# Dorsal fin
	CritterBuilder.attach(body, CritterBuilder.cone_mesh(L * 0.16, L * 0.20, 5), fin,
		Transform3D(Basis(Vector3.RIGHT, -0.5).scaled(Vector3(0.22, 1.0, 1.0)), Vector3(0, L * 0.20, L * 0.02)))
	# Pelvic fin
	CritterBuilder.attach(body, CritterBuilder.cone_mesh(L * 0.10, L * 0.13, 5), fin,
		Transform3D(Basis(Vector3.RIGHT, PI - 0.4).scaled(Vector3(0.22, 1.0, 1.0)), Vector3(0, -L * 0.17, L * 0.14)))

	# Pectoral fins, angled back along the flanks.
	for sx2 in [-1.0, 1.0]:
		var pec := Node3D.new()
		pec.position = Vector3(sx2 * L * 0.13, -L * 0.04, -L * 0.16)
		body.add_child(pec)
		CritterBuilder.attach(pec, CritterBuilder.cone_mesh(L * 0.09, L * 0.20, 5), fin,
			Transform3D(Basis(Vector3.FORWARD, sx2 * -1.35).scaled(Vector3(1.0, 1.0, 0.22)),
				Vector3(sx2 * L * 0.09, 0, L * 0.02)))
		_pectorals.append(pec)

	# Tail pivot at the caudal peduncle so the whole fin sweeps.
	tail = Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0, L * 0.48)
	body.add_child(tail)
	CritterBuilder.attach(tail, CritterBuilder.cone_mesh(L * 0.10, L * 0.16, 5), back,
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, L * 0.08)))
	CritterBuilder.attach(tail, CritterBuilder.cone_mesh(L * 0.26, L * 0.28, 5), fin,
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3(0.20, 1.0, 1.0)), Vector3(0, 0, L * 0.28)))


# --- swimming -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _breach > 0.0:
		_breach_step(delta)
		_animate(delta, 2.0)
		return
	_steer(delta)
	_swim(delta)
	_animate(delta, 1.0)


func _steer(delta: float) -> void:
	_dart = maxf(_dart - delta, 0.0)

	var goal: Vector3 = manager.school_anchor(school_id) + slot
	var desired := goal - global_position
	if desired.length() > 0.001:
		desired = desired.normalized()

	# Keep a little personal space inside the school.
	var sep := Vector3.ZERO
	var sep_r: float = cfg.sep
	for m in manager.school_members(school_id):
		var other: Node3D = m
		if other == self or not is_instance_valid(other):
			continue
		var d: Vector3 = global_position - other.global_position
		var l: float = d.length()
		if l < sep_r and l > 0.0001:
			sep += d / l * (1.0 - l / sep_r)
	desired += sep * 1.6

	# Something big at the water's edge - scatter.
	var threat: Vector3 = manager.threat_position(global_position, FLEE_RADIUS)
	var speed: float = cfg.cruise
	if threat != Vector3.INF:
		var away := global_position - threat
		away.y = 0.0
		if away.length() > 0.001:
			desired = away.normalized() + Vector3.DOWN * 0.35
		_dart = 1.2
	if _dart > 0.0:
		speed = cfg.dart

	if desired.length() > 0.001:
		desired = desired.normalized()
	velocity = velocity.move_toward(desired * speed, float(cfg.accel) * delta)


func _swim(delta: float) -> void:
	var next := global_position + velocity * delta

	# Bounce off the shallows: steer back toward deeper water.
	if terrain.water_depth(next.x, next.z) < MIN_DEPTH:
		var inward := Vector3(terrain.lake_center.x, global_position.y, terrain.lake_center.y) - global_position
		inward.y = 0.0
		if inward.length() > 0.001:
			velocity = velocity.lerp(inward.normalized() * float(cfg.cruise) * 1.5, 0.35)
		next = global_position + velocity * delta
		if terrain.water_depth(next.x, next.z) < MIN_DEPTH * 0.5:
			next = global_position

	var bed := terrain.sample_height(next.x, next.z)
	var lo := bed + 0.30
	var hi := ForestTerrain.WATER_LEVEL - 0.35
	if lo > hi:
		lo = hi
	if next.y < lo or next.y > hi:
		velocity.y *= -0.4
	next.y = clampf(next.y, lo, hi)
	global_position = next

	if velocity.length() > 0.05:
		var v := velocity.normalized()
		var yaw := atan2(-v.x, -v.z)
		var pitch := clampf(asin(clampf(v.y, -1.0, 1.0)), -0.7, 0.7)
		var w := clampf(float(cfg.turn) * delta, 0.0, 1.0)
		rotation.y = lerp_angle(rotation.y, yaw, w)
		rotation.x = lerpf(rotation.x, pitch, w)
		# Bank into turns.
		var dyaw := wrapf(yaw - rotation.y, -PI, PI)
		rotation.z = lerpf(rotation.z, clampf(dyaw * 1.2, -0.6, 0.6), w)

	# A trout near the surface in calm water will sometimes jump.
	if cfg.can_breach and _dart <= 0.0 and _breach <= 0.0:
		if global_position.y > hi - 0.6 and _rng.randf() < delta * 0.035:
			_start_breach()


func _animate(delta: float, boost: float) -> void:
	var spd := velocity.length()
	_phase += delta * (1.2 + spd * 1.8) * float(cfg.tail_rate) * boost
	var amp := clampf(0.25 + spd * 0.10, 0.25, 0.7)
	tail.rotation.y = sin(_phase) * amp
	body.rotation.y = sin(_phase - 0.9) * amp * 0.16
	for i in _pectorals.size():
		var s := -1.0 if i == 0 else 1.0
		_pectorals[i].rotation.y = sin(_phase * 0.8 + i * PI) * 0.22 * s


# --- breaching ----------------------------------------------------------------

func _start_breach() -> void:
	_breach = 1.6
	_splashed = false
	_breach_vy = _rng.randf_range(3.6, 5.4)
	manager.splash(global_position)
	var fwd := -global_transform.basis.z
	velocity = Vector3(fwd.x, 0.0, fwd.z).normalized() * float(cfg.dart) * 0.7


func _breach_step(delta: float) -> void:
	_breach -= delta
	_breach_vy -= 16.0 * delta
	var next := global_position + Vector3(velocity.x, _breach_vy, velocity.z) * delta

	var surface := ForestTerrain.WATER_LEVEL
	if _breach_vy < 0.0 and next.y <= surface and not _splashed:
		_splashed = true
		manager.splash(Vector3(next.x, surface, next.z))

	# Nose over the top of the arc.
	rotation.x = lerpf(rotation.x, clampf(atan2(_breach_vy, maxf(velocity.length(), 0.5)), -1.2, 1.2), 0.25)
	rotation.z = lerpf(rotation.z, 0.0, 0.15)

	global_position = next

	if _breach <= 0.0 or (_splashed and next.y < surface - 0.5):
		_breach = 0.0
		var bed := terrain.sample_height(next.x, next.z)
		global_position.y = clampf(next.y, bed + 0.30, surface - 0.35)
		if terrain.water_depth(next.x, next.z) < MIN_DEPTH:
			var back := terrain.random_lake_point(_rng, MIN_DEPTH + 0.4)
			if back != Vector3.ZERO:
				global_position = back
		_breach_vy = 0.0
