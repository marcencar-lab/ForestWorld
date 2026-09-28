class_name Bear
extends Node3D

## The predator. Picks the nearest prey it can see, closes the distance,
## swipes when in range, then feeds on the kill before hunting again.
## The player counts as prey once the bear can hear or smell them.

enum State { PATROL, STALK, CHASE, ATTACK, FEED, ROAR, FLEE, DEAD }

signal struck(victim, at)
signal made_kill(victim)
signal noticed_player
signal lost_player(reason)
signal hurt(amount)
signal died(bear)

const HUNT_RADIUS := 105.0
const CHASE_RADIUS := 52.0
const ATTACK_RANGE := 2.9
const ATTACK_DAMAGE := 55.0
const ATTACK_COOLDOWN := 1.35
const FEED_TIME := 9.0

## Base distance at which the bear notices the player, scaled by how much
## noise they make and widened by the fish they carry.
const PLAYER_DETECT := 34.0
## Once locked on, the bear keeps tracking out to this multiple of that radius.
const PLAYER_TRACK := 1.8
const PLAYER_DAMAGE := 34.0
## The bear takes the player over an animal unless the animal is this much closer.
const PLAYER_PREFERENCE := 1.2
## The bear wades into water up to this deep and no further.
const WADE_DEPTH := 0.9
const GIVE_UP_TIME := 9.0
## Below this fraction of health it breaks off and runs.
const FLEE_AT := 0.35
const FLEE_TIME := 22.0
const FLEE_IGNORE := 60.0
const HEAL_RATE := 3.0          # health per second while calm
## Walls: how close it must be to claw one, how hard it hits, and how long it
## keeps at it before losing interest.
const BODY_RADIUS := 1.0
const WALL_REACH := 1.9
const WALL_DAMAGE := 30.0
const FRUSTRATION_TIME := 14.0
const WALLED_OUT_IGNORE := 30.0

var cfg: Dictionary
var terrain: ForestTerrain
var manager: WildlifeManager

var state: int = State.PATROL
## An Animal or the PlayerController - anything with is_alive() / take_damage().
var target: Node3D = null
var _ignore_player_t := 0.0
var _player_block := ""
var health := 600.0
var max_health := 600.0
var _flee_t := 0.0
var _death_t := 0.0
var _attack_structure: Structure = null
var _frustration := 0.0
var _clawing := false
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
	max_health = float(cfg.health)
	health = max_health
	add_to_group("hostile")

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
		State.FLEE: return "fleeing"
		State.DEAD: return "dead"
	return "?"


func is_alive() -> bool:
	return state != State.DEAD


## Hit by the player (or anything else). Hurting it makes it come for you,
## until it's hurt badly enough to run.
func take_damage(amount: float, from: Vector3) -> void:
	if state == State.DEAD:
		return
	health -= amount
	hurt.emit(amount)
	if health <= 0.0:
		_die()
		return
	if health < max_health * FLEE_AT:
		if state != State.FLEE:
			_start_flee(from)
		return
	manager.bear_voice("growl", global_position)
	# Provoked: turn on whoever hit it if that's the player.
	var p: PlayerController = manager.player
	if p != null and p.alive and from.distance_to(p.global_position) < 40.0 and not _hunting_player():
		_ignore_player_t = 0.0
		target = p
		noticed_player.emit()
		if state == State.FEED or state == State.PATROL or state == State.ROAR:
			state = State.CHASE


func _start_flee(from: Vector3) -> void:
	var was_player := _hunting_player()
	state = State.FLEE
	_flee_t = FLEE_TIME
	_ignore_player_t = FLEE_IGNORE
	target = null
	_attack_structure = null
	_clawing = false
	var away := global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var dest := global_position + away * 80.0
	dest.x = clampf(dest.x, -ForestTerrain.PLAY_BOUND, ForestTerrain.PLAY_BOUND)
	dest.z = clampf(dest.z, -ForestTerrain.PLAY_BOUND, ForestTerrain.PLAY_BOUND)
	move_target = dest
	manager.bear_voice("roar", global_position)
	if was_player:
		lost_player.emit("fled")


func _die() -> void:
	health = 0.0
	state = State.DEAD
	target = null
	velocity = Vector3.ZERO
	_death_t = 0.0
	remove_from_group("hostile")
	manager.bear_voice("roar", global_position)
	died.emit(self)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_death_anim(delta)
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if state != State.FLEE and not _hunting_player():
		health = minf(health + HEAL_RATE * delta, max_health)
	_think(delta)
	_move(delta)
	_animate(delta)


func _death_anim(delta: float) -> void:
	_death_t += delta
	var t := clampf(_death_t / 1.1, 0.0, 1.0)
	body.rotation.z = lerpf(body.rotation.z, 1.45, t)
	body.position.y = lerpf(body.position.y, -0.35, t)
	for l in legs:
		l.rotation.x = lerpf(l.rotation.x, 0.0, t)


# --- brain --------------------------------------------------------------------

func _think(delta: float) -> void:
	_think_timer -= delta
	_state_timer -= delta
	_voice_timer -= delta

	# Working growls while running down or eating something.
	if _voice_timer <= 0.0 and (state == State.CHASE or state == State.FEED):
		_voice_timer = _rng.randf_range(1.8, 4.5)
		manager.bear_voice("growl", global_position)

	if state == State.FLEE:
		_flee_t -= delta
		var fd := Vector2(move_target.x - global_position.x, move_target.z - global_position.z).length()
		if _flee_t <= 0.0 or fd < 3.0:
			state = State.PATROL
			_pick_patrol_target()
		return

	if state == State.FEED:
		_feed_t -= delta
		if _feed_t <= 0.0:
			target = null
			state = State.PATROL
			_pick_patrol_target()
		return

	if state == State.ATTACK:
		_attack_t += delta
		if _clawing:
			_frustration += delta   # the whole swipe counts as time spent walled out
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
	if target != null and not _alive(target):
		if is_instance_valid(target):
			state = State.FEED
			_feed_t = FEED_TIME
			move_target = target.global_position
		else:
			target = null
			state = State.PATROL
			_pick_patrol_target()
		return

	_ignore_player_t = maxf(_ignore_player_t - delta, 0.0)
	if _think_timer <= 0.0:
		_think_timer = 0.4
		_choose_target()

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

	# A wall between us and the player: claw at it, and eventually give up.
	if _hunting_player() and _wall_toward_player(delta):
		return

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


## Deals with a wall standing between the bear and the player. Returns true
## when that took over this think step.
func _wall_toward_player(delta: float) -> bool:
	var build: BuildSystem = manager.build
	if build == null:
		return false
	var me := Vector2(global_position.x, global_position.z)
	var tp := Vector2(target.global_position.x, target.global_position.z)
	var wall := build.blocking(me, tp, 0.35)
	if wall == null:
		_frustration = maxf(_frustration - delta * 0.5, 0.0)
		_clawing = false
		return false
	_frustration += delta
	if _frustration > FRUSTRATION_TIME:
		_frustration = 0.0
		_ignore_player_t = WALLED_OUT_IGNORE
		_clawing = false
		target = null
		state = State.ROAR
		_state_timer = 2.2
		_roar_t = 0.0
		manager.bear_voice("roar", global_position)
		lost_player.emit("walls")
		return true
	if wall.path_distance(me, me) <= WALL_REACH:
		if _cooldown <= 0.0:
			state = State.ATTACK
			_attack_t = 0.0
			_cooldown = ATTACK_COOLDOWN
			_attack_structure = wall
			_clawing = true
			velocity = Vector3.ZERO
			manager.bear_voice("swipe", global_position)
		return true
	state = State.CHASE
	return true


static func _alive(n: Node3D) -> bool:
	return n != null and is_instance_valid(n) and n.call("is_alive")


func _hunting_player() -> bool:
	return target != null and manager.player != null and target == manager.player


## Nearest animal, unless the player is close and loud enough to be worth it.
func _choose_target() -> void:
	var was_player := _hunting_player()
	var pick: Node3D = manager.nearest_prey(global_position, HUNT_RADIUS)
	var pd := _player_distance(was_player)
	if pd < INF:
		var prey_d := INF
		if pick != null:
			prey_d = global_position.distance_to(pick.global_position)
		# Once committed to the player it takes a much easier meal to distract it.
		var pref := PLAYER_PREFERENCE * (2.5 if was_player else 1.0)
		if pd < prey_d * pref:
			pick = manager.player

	if pick == target:
		return
	target = pick
	if _hunting_player():
		noticed_player.emit()
		manager.bear_voice("roar", global_position)
	elif was_player:
		if _player_block == "water":
			# Pace the shoreline for a while rather than instantly re-locking.
			_ignore_player_t = GIVE_UP_TIME
			manager.bear_voice("roar", global_position)
		lost_player.emit(_player_block)


## Distance to the player if the bear can sense and reach them, else INF.
## Leaves the reason in _player_block when the player is out of reach.
func _player_distance(tracking: bool) -> float:
	_player_block = ""
	var p: PlayerController = manager.player
	if p == null or not p.alive or p.god_mode:
		return INF
	var pos := p.global_position
	if not terrain.is_land(pos.x, pos.z, -WADE_DEPTH):
		_player_block = "water"
		return INF
	if _ignore_player_t > 0.0:
		return INF
	var d := global_position.distance_to(pos)
	var radius := PLAYER_DETECT * p.noise_level() + p.scent_bonus()
	if tracking:
		radius *= PLAYER_TRACK
	if d > radius:
		_player_block = "far"
		return INF
	return d


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
	if _attack_structure != null:
		var wall := _attack_structure
		_attack_structure = null
		if is_instance_valid(wall):
			var me := Vector2(global_position.x, global_position.z)
			var at2 := Vector2.INF
			for sg in wall.segments:
				var q := Geometry2D.get_closest_point_to_segment(me, sg[0], sg[1])
				if at2 == Vector2.INF or q.distance_to(me) < at2.distance_to(me):
					at2 = q
			if at2 == Vector2.INF:
				at2 = me
			struck.emit(wall, Vector3(at2.x, global_position.y + 1.0, at2.y))
			manager.build.damage(wall, WALL_DAMAGE)
		return
	if not _alive(target):
		return
	if global_position.distance_to(target.global_position) > ATTACK_RANGE * 1.9:
		return
	var at: Vector3 = target.global_position
	var victim := target
	var dmg := PLAYER_DAMAGE if _hunting_player() else ATTACK_DAMAGE
	victim.call("take_damage", dmg, global_position)
	struck.emit(victim, at)
	if not _alive(victim):
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
		State.FLEE:
			speed = float(cfg.run_speed) * 0.85
		State.FEED, State.ROAR:
			speed = 0.0 if dist < 1.6 else 2.0

	if state != State.CHASE:
		_stamina = minf(_stamina + delta * 0.12, 1.0)

	if state == State.ATTACK:
		velocity = velocity.move_toward(Vector3.ZERO, 22.0 * delta)
	else:
		velocity = velocity.move_toward(dir * speed, float(cfg.accel) * delta)

	var next := global_position + velocity * delta
	# Only wades in after the player; heading back up the bank is always allowed.
	var margin := -WADE_DEPTH if _hunting_player() else 0.2
	var into_water := not terrain.is_land(next.x, next.z, margin) \
		and terrain.sample_height(next.x, next.z) <= terrain.sample_height(global_position.x, global_position.z)
	if _walled(next):
		# Slide along the wall if we can, otherwise stop against it.
		var slid := false
		for turn in [PI * 0.5, -PI * 0.5]:
			var v2 := velocity.rotated(Vector3.UP, turn) * 0.5
			var n2 := global_position + v2 * delta
			if not _walled(n2) and not _hunting_player():
				velocity = v2
				next = n2
				slid = true
				break
		if not slid:
			velocity = Vector3.ZERO
			next = global_position
	elif not terrain.in_bounds(next.x, next.z) or into_water:
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


func _walled(p: Vector3) -> bool:
	var build: BuildSystem = manager.build
	if build == null:
		return false
	var q := Vector2(p.x, p.z)
	var here := Vector2(global_position.x, global_position.z)
	var s := build.blocking(q, q, BODY_RADIUS)
	if s == null:
		return false
	# Always let it back away from a wall it is already pressed against.
	return s.path_distance(q, q) < s.path_distance(here, here)


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
