class_name Bear
extends Node3D

## The predator. Picks the nearest prey it can see, closes the distance,
## swipes when in range, then feeds on the kill before hunting again.

enum State { PATROL, STALK, CHASE, ATTACK, FEED, ROAR }

signal struck(victim, at)
signal made_kill(victim)

const HUNT_RADIUS := 105.0
const CHASE_RADIUS := 52.0
const ATTACK_RANGE := 2.9
const ATTACK_DAMAGE := 55.0
const ATTACK_COOLDOWN := 1.35
const FEED_TIME := 9.0

var cfg: Dictionary
var terrain: ForestTerrain
var manager: WildlifeManager

var state: int = State.PATROL
var target: Animal = null
var velocity := Vector3.ZERO
var move_target := Vector3.ZERO

var _think_timer := 0.0
var _state_timer := 0.0
var _cooldown := 0.0
var _attack_t := -1.0
var _feed_t := 0.0
var _roar_t := 0.0
var _gait := 0.0
var _voice_timer := 0.0
var _ground_y := 0.0
var _pitch := 0.0
var _stamina := 1.0

var body: Node3D
var neck: Node3D
var head: Node3D
var legs: Array[Node3D] = []
var _neck_base := 0.0

var _rng := RandomNumberGenerator.new()

const LEG_PHASE := [0.0, PI, PI, 0.0]


func setup(t: ForestTerrain, m: WildlifeManager, spawn: Vector3) -> void:
	terrain = t
	manager = m
	cfg = Species.get_cfg("bear")
	_rng.randomize()

	var parts := CritterBuilder.build(cfg, self)
	body = parts.body
	legs = parts.legs
	neck = parts.neck
	head = parts.head
	_neck_base = neck.rotation.x
	scale = Vector3.ONE * 1.15

	position = spawn
	_ground_y = spawn.y
	move_target = spawn


func state_name() -> String:
	match state:
		State.PATROL: return "roaming"
		State.STALK: return "stalking"
		State.CHASE: return "charging"
		State.ATTACK: return "attacking"
		State.FEED: return "feeding"
		State.ROAR: return "roaring"
	return "?"


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_think(delta)
	_move(delta)
	_animate(delta)


# --- brain --------------------------------------------------------------------

func _think(delta: float) -> void:
	_think_timer -= delta
	_state_timer -= delta
	_voice_timer -= delta

	# Working growls while running down or eating something.
	if _voice_timer <= 0.0 and (state == State.CHASE or state == State.FEED):
		_voice_timer = _rng.randf_range(1.8, 4.5)
		manager.bear_voice("growl", global_position)

	if state == State.FEED:
		_feed_t -= delta
		if _feed_t <= 0.0:
			target = null
			state = State.PATROL
			_pick_patrol_target()
		return

	if state == State.ATTACK:
		_attack_t += delta
		if _attack_t > 0.20 and _attack_t - delta <= 0.20:
			_land_hit()
		if _attack_t >= 0.75:
			_attack_t = -1.0
			state = State.CHASE
		return

	if state == State.ROAR:
		if _state_timer <= 0.0:
			state = State.PATROL
			_pick_patrol_target()
		return

	# Drop a dead or vanished target.
	if target != null and (not is_instance_valid(target) or not target.is_alive()):
		if target != null and is_instance_valid(target):
			state = State.FEED
			_feed_t = FEED_TIME
			move_target = target.global_position
		else:
			target = null
			state = State.PATROL
			_pick_patrol_target()
		return

	if _think_timer <= 0.0:
		_think_timer = 0.4
		var prey: Animal = manager.nearest_prey(global_position, HUNT_RADIUS)
		if prey != target:
			target = prey

	if target == null:
		if state != State.PATROL:
			state = State.PATROL
			_pick_patrol_target()
		var flat := Vector2(move_target.x - global_position.x, move_target.z - global_position.z)
		if flat.length() < 3.0 or _state_timer <= 0.0:
			if _rng.randf() < 0.18:
				state = State.ROAR
				_state_timer = 2.2
				_roar_t = 0.0
				manager.bear_voice("roar", global_position)
			else:
				_pick_patrol_target()
		return

	var d := global_position.distance_to(target.global_position)
	move_target = target.global_position

	if d <= ATTACK_RANGE and _cooldown <= 0.0:
		state = State.ATTACK
		_attack_t = 0.0
		_cooldown = ATTACK_COOLDOWN
		manager.bear_voice("swipe", global_position)
		var lunge := (target.global_position - global_position)
		lunge.y = 0.0
		velocity = lunge.normalized() * 7.0
	elif d <= CHASE_RADIUS:
		state = State.CHASE
	else:
		state = State.STALK


func _pick_patrol_target() -> void:
	_state_timer = _rng.randf_range(8.0, 18.0)
	for i in 14:
		var ang := _rng.randf_range(0.0, TAU)
		var dist := _rng.randf_range(25.0, 90.0)
		var p := global_position + Vector3(cos(ang), 0.0, sin(ang)) * dist
		if not terrain.in_bounds(p.x, p.z):
			continue
		if not terrain.is_land(p.x, p.z, 1.4):
			continue
		if terrain.sample_normal(p.x, p.z).y < 0.76:
			continue
		move_target = Vector3(p.x, terrain.sample_height(p.x, p.z), p.z)
		return
	move_target = Vector3.ZERO


func _land_hit() -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return
	if global_position.distance_to(target.global_position) > ATTACK_RANGE * 1.9:
		return
	var at: Vector3 = target.global_position
	var victim := target
	victim.take_damage(ATTACK_DAMAGE, global_position)
	struck.emit(victim, at)
	if not victim.is_alive():
		made_kill.emit(victim)
		state = State.FEED
		_feed_t = FEED_TIME
		_attack_t = -1.0


# --- motion -------------------------------------------------------------------

func _move(delta: float) -> void:
	var to := move_target - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.05 else Vector3.ZERO

	var speed := 0.0
	match state:
		State.PATROL:
			speed = cfg.walk_speed
		State.STALK:
			speed = float(cfg.walk_speed) * 1.9
		State.CHASE:
			speed = cfg.run_speed
			_stamina = maxf(_stamina - delta / float(cfg.stamina), 0.0)
			speed *= lerpf(0.78, 1.0, smoothstep(0.0, 0.35, _stamina))
		State.ATTACK:
			speed = 0.0
			dir = Vector3.ZERO
		State.FEED, State.ROAR:
			speed = 0.0 if dist < 1.6 else 2.0

	if state != State.CHASE:
		_stamina = minf(_stamina + delta * 0.12, 1.0)

	if state == State.ATTACK:
		velocity = velocity.move_toward(Vector3.ZERO, 22.0 * delta)
	else:
		velocity = velocity.move_toward(dir * speed, float(cfg.accel) * delta)

	var next := global_position + velocity * delta
	if not terrain.in_bounds(next.x, next.z) or not terrain.is_land(next.x, next.z, 0.2):
		velocity = velocity.rotated(Vector3.UP, PI * 0.5) * 0.6
		next = global_position + velocity * delta
		if not terrain.in_bounds(next.x, next.z):
			next = global_position

	var gy := terrain.sample_height(next.x, next.z)
	_ground_y = lerpf(_ground_y, gy, clampf(delta * 16.0, 0.0, 1.0))
	global_position = Vector3(next.x, _ground_y, next.z)

	var face := velocity
	if state == State.ATTACK or state == State.FEED:
		if target != null and is_instance_valid(target):
			face = target.global_position - global_position
	if face.length() > 0.25:
		var yaw := atan2(-face.x, -face.z)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(float(cfg.turn) * delta, 0.0, 1.0))


# --- animation ----------------------------------------------------------------

func _animate(delta: float) -> void:
	var spd := velocity.length()
	_gait += delta * spd * float(cfg.gait_scale)
	var amp: float = float(cfg.step_amp) * clampf(spd / float(cfg.run_speed) + 0.3, 0.0, 1.0)

	var fwd := -global_transform.basis.z
	var d := 1.1
	var hf := terrain.sample_height(global_position.x + fwd.x * d, global_position.z + fwd.z * d)
	var hb := terrain.sample_height(global_position.x - fwd.x * d, global_position.z - fwd.z * d)
	_pitch = clampf(atan2(hf - hb, d * 2.0), -0.55, 0.55)

	if state == State.ATTACK:
		# Rear up, swat down with the forelegs.
		var t := clampf(_attack_t / 0.75, 0.0, 1.0)
		var swing := sin(clampf(t, 0.0, 1.0) * PI)
		legs[0].rotation.x = -1.9 * swing
		legs[1].rotation.x = -1.5 * swing
		legs[2].rotation.x = 0.25 * swing
		legs[3].rotation.x = 0.25 * swing
		body.rotation.x = lerpf(body.rotation.x, _pitch - 0.55 * swing, 0.4)
		body.position.y = swing * 0.30
		neck.rotation.x = lerpf(neck.rotation.x, _neck_base - 0.45 * swing, 0.4)
		return

	for i in legs.size():
		legs[i].rotation.x = sin(_gait + LEG_PHASE[i]) * amp
	body.position.y = absf(sin(_gait)) * 0.05 * amp
	body.rotation.x = lerpf(body.rotation.x, _pitch, 0.2)
	body.rotation.z = lerpf(body.rotation.z, sin(_gait * 0.5) * 0.06 * amp, 0.2)

	var want := _neck_base
	if state == State.FEED:
		want = _neck_base + 1.25
		head.rotation.x = sin(Time.get_ticks_msec() * 0.004) * 0.12
	elif state == State.ROAR:
		_roar_t += delta
		want = _neck_base - 0.85
		head.rotation.x = -0.35 + sin(_roar_t * 14.0) * 0.07
	elif state == State.CHASE:
		want = _neck_base + 0.18
	neck.rotation.x = lerpf(neck.rotation.x, want, clampf(delta * 4.0, 0.0, 1.0))
