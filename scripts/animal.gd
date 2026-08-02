class_name Animal
extends Node3D

## A prey animal. Wanders and grazes on its own, bolts when the bear closes in,
## tires out if it runs too long, and can be killed.
##
## Movement is kinematic and snapped to ForestTerrain.sample_height(), which is
## far cheaper than physics for a few dozen agents and never jitters on slopes.

enum State { IDLE, WANDER, FLEE, DEAD }

signal died(animal)

var species := "deer"
var cfg: Dictionary
var terrain: ForestTerrain
var manager: WildlifeManager

var state: int = State.WANDER
var alive := true
var health := 100.0
var max_health := 100.0

var velocity := Vector3.ZERO
var target := Vector3.ZERO
var _state_timer := 0.0
var _repath_timer := 0.0
var _stamina := 1.0
var _panic := 0.0
var _gait := 0.0
var _ground_y := 0.0
var _pitch := 0.0
var _death_t := 0.0
var _flank := 1.0
var _voice_timer := 0.0
var _rustle_timer := 0.0

var body: Node3D
var neck: Node3D
var head: Node3D
var tail: Node3D
var legs: Array[Node3D] = []
var _body_y := 0.0
var _neck_base := 0.0

var _rng := RandomNumberGenerator.new()

const LEG_PHASE := [0.0, PI, PI, 0.0]


func setup(species_name: String, t: ForestTerrain, m: WildlifeManager, spawn: Vector3) -> void:
	species = species_name
	cfg = Species.get_cfg(species_name)
	terrain = t
	manager = m
	_rng.randomize()
	_flank = 1.0 if _rng.randf() < 0.5 else -1.0

	max_health = cfg.health
	health = max_health
	_stamina = 1.0

	var parts := CritterBuilder.build(cfg, self)
	body = parts.body
	legs = parts.legs
	neck = parts.neck
	head = parts.head
	tail = parts.tail
	_body_y = parts.body_y
	_neck_base = neck.rotation.x

	position = spawn
	_ground_y = spawn.y
	rotation.y = _rng.randf_range(0.0, TAU)
	_pick_wander_target()
	_state_timer = _rng.randf_range(0.0, 3.0)


func _physics_process(delta: float) -> void:
	if not alive:
		_death_anim(delta)
		return
	_think(delta)
	_move(delta)
	_animate(delta)


# --- brain --------------------------------------------------------------------

func _think(delta: float) -> void:
	_state_timer -= delta
	_repath_timer -= delta
	_voice_timer -= delta
	_rustle_timer -= delta

	# Crashing through the undergrowth while running.
	if state == State.FLEE and _rustle_timer <= 0.0:
		_rustle_timer = _rng.randf_range(0.35, 0.75)
		manager.rustle(global_position)

	if _voice_timer <= 0.0:
		_voice_timer = _rng.randf_range(18.0, 55.0)
		if state == State.IDLE or state == State.WANDER:
			manager.animal_voice(self, "idle")

	var threat: Vector3 = manager.threat_position(global_position, cfg.flee_radius)
	if threat != Vector3.INF:
		if state != State.FLEE:
			state = State.FLEE
			_panic = 1.0
			manager.animal_voice(self, "alarm")
			_voice_timer = _rng.randf_range(4.0, 9.0)
		_panic = 1.0
		var away := global_position - threat
		away.y = 0.0
		if away.length() < 0.01:
			away = Vector3(1, 0, 0)
		away = away.normalized()
		# Break in a slight arc rather than a dead-straight line.
		var side := Vector3(-away.z, 0.0, away.x) * _flank * 0.45
		var dir := (away + side).normalized()
		if _repath_timer <= 0.0:
			_repath_timer = 0.35
			target = global_position + _safe_direction(dir) * 26.0
		return

	# Recovering from a scare.
	if state == State.FLEE:
		_panic -= delta * 0.5
		if _panic <= 0.0:
			state = State.WANDER
			_pick_wander_target()
		return

	if state == State.WANDER:
		var flat := Vector2(target.x - global_position.x, target.z - global_position.z)
		if flat.length() < 2.2 or _state_timer <= 0.0:
			if _rng.randf() < 0.45:
				state = State.IDLE
				_state_timer = _rng.randf_range(2.5, 7.0)
			else:
				_pick_wander_target()
	elif state == State.IDLE:
		if _state_timer <= 0.0:
			state = State.WANDER
			_pick_wander_target()


func _pick_wander_target() -> void:
	state = State.WANDER
	_state_timer = _rng.randf_range(6.0, 16.0)
	for i in 12:
		var ang := _rng.randf_range(0.0, TAU)
		var dist := _rng.randf_range(8.0, 34.0)
		var p := global_position + Vector3(cos(ang), 0.0, sin(ang)) * dist
		if not terrain.in_bounds(p.x, p.z):
			continue
		if not terrain.is_land(p.x, p.z, 1.4):
			continue
		if terrain.sample_normal(p.x, p.z).y < 0.78:
			continue
		target = Vector3(p.x, terrain.sample_height(p.x, p.z), p.z)
		return
	# Nothing good nearby: head back toward the middle of the map.
	var c := -global_position.normalized() * 20.0
	target = global_position + Vector3(c.x, 0.0, c.z)


## Nudge a desired heading until it points at walkable ground.
func _safe_direction(dir: Vector3) -> Vector3:
	var probes := [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6, 2.3, -2.3, PI]
	for a in probes:
		var d := dir.rotated(Vector3.UP, a)
		var p := global_position + d * 11.0
		if terrain.in_bounds(p.x, p.z) and terrain.is_land(p.x, p.z, 1.0):
			return d
	return dir


# --- motion -------------------------------------------------------------------

func _move(delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.05 else Vector3.ZERO

	var speed := 0.0
	match state:
		State.IDLE:
			speed = 0.0
		State.WANDER:
			speed = cfg.walk_speed
		State.FLEE:
			speed = cfg.run_speed
			_stamina = maxf(_stamina - delta / float(cfg.stamina), 0.0)
			# Blown animals slow down - this is what lets the bear ever win.
			speed *= lerpf(0.55, 1.0, smoothstep(0.0, 0.45, _stamina))

	if state != State.FLEE:
		_stamina = minf(_stamina + delta * 0.09, 1.0)

	var desired := dir * speed
	velocity = velocity.move_toward(desired, float(cfg.accel) * delta)

	var next := global_position + velocity * delta
	# Keep them on dry land and inside the playfield.
	if not terrain.in_bounds(next.x, next.z) or not terrain.is_land(next.x, next.z, 0.4):
		velocity = velocity.rotated(Vector3.UP, PI * 0.5) * 0.6
		next = global_position + velocity * delta
		if not terrain.in_bounds(next.x, next.z):
			next = global_position

	var gy := terrain.sample_height(next.x, next.z)
	_ground_y = lerpf(_ground_y, gy, clampf(delta * 18.0, 0.0, 1.0))
	global_position = Vector3(next.x, _ground_y, next.z)

	if velocity.length() > 0.25:
		var yaw := atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(float(cfg.turn) * delta, 0.0, 1.0))


# --- animation ----------------------------------------------------------------

func _animate(delta: float) -> void:
	var spd := velocity.length()
	_gait += delta * spd * float(cfg.gait_scale)

	var moving := spd > 0.3
	var amp: float = cfg.step_amp * clampf(spd / float(cfg.run_speed) + 0.25, 0.0, 1.0)

	if cfg.gait == "hop":
		var bound := absf(sin(_gait * 0.5))
		for i in legs.size():
			var front := i < 2
			legs[i].rotation.x = (bound * 1.15 - 0.4) * (1.0 if front else -1.0) * amp
		body.position.y = pow(bound, 1.5) * 0.30 * amp
		body.rotation.x = lerpf(body.rotation.x, _pitch + sin(_gait * 0.5) * 0.22 * amp, 0.35)
	else:
		for i in legs.size():
			legs[i].rotation.x = sin(_gait + LEG_PHASE[i]) * amp
		body.position.y = absf(sin(_gait)) * 0.035 * amp
		body.rotation.x = lerpf(body.rotation.x, _pitch, 0.2)

	# Follow the ground slope with the torso.
	var fwd := -global_transform.basis.z
	var d := 0.9
	var hf := terrain.sample_height(global_position.x + fwd.x * d, global_position.z + fwd.z * d)
	var hb := terrain.sample_height(global_position.x - fwd.x * d, global_position.z - fwd.z * d)
	_pitch = clampf(atan2(hf - hb, d * 2.0), -0.6, 0.6)

	# Head down to graze while idle, up and alert while fleeing.
	var want := _neck_base
	if state == State.IDLE and not moving:
		want = _neck_base + 1.15 + sin(_gait * 0.7 + 1.0) * 0.05
	elif state == State.FLEE:
		want = _neck_base - 0.28
	neck.rotation.x = lerpf(neck.rotation.x, want, clampf(delta * 3.0, 0.0, 1.0))
	head.rotation.y = sin(_gait * 0.35 + 0.7) * (0.35 if not moving else 0.06)

	if tail:
		tail.rotation.x = float(cfg.tail_pitch) + sin(_gait * 1.3) * (0.35 if moving else 0.12)
		tail.rotation.z = sin(_gait * 0.9) * 0.15
		if state == State.FLEE:
			tail.rotation.x = float(cfg.tail_pitch) - 0.9


func _death_anim(delta: float) -> void:
	_death_t += delta
	var t := clampf(_death_t / 0.7, 0.0, 1.0)
	body.rotation.z = lerpf(body.rotation.z, PI * 0.5, t * 0.25)
	body.rotation.x = lerpf(body.rotation.x, 0.0, 0.15)
	body.position.y = lerpf(body.position.y, -float(cfg.leg_len) * 0.55, 0.12)
	for l in legs:
		l.rotation.x = lerpf(l.rotation.x, -0.6, 0.08)
	neck.rotation.x = lerpf(neck.rotation.x, _neck_base + 0.6, 0.08)
	var gy := terrain.sample_height(global_position.x, global_position.z)
	global_position.y = lerpf(global_position.y, gy, clampf(delta * 6.0, 0.0, 1.0))


# --- damage -------------------------------------------------------------------

func take_damage(amount: float, from: Vector3) -> void:
	if not alive:
		return
	health -= amount
	_panic = 1.0
	_stamina = maxf(_stamina - 0.18, 0.0)
	state = State.FLEE
	var knock := (global_position - from)
	knock.y = 0.0
	if knock.length() > 0.01:
		velocity += knock.normalized() * 4.5
	if health <= 0.0:
		_die()
	else:
		manager.animal_voice(self, "pain")


func _die() -> void:
	alive = false
	state = State.DEAD
	velocity = Vector3.ZERO
	_death_t = 0.0
	manager.animal_voice(self, "death")
	died.emit(self)


func is_alive() -> bool:
	return alive
