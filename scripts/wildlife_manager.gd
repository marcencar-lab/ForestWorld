class_name WildlifeManager
extends Node3D

## Owns every creature: spawning, the shared "who can see whom" queries,
## corpse cleanup and repopulation.

const CORPSE_TIME := 18.0
const RESPAWN_DELAY := 6.0
const MIN_RESPAWN_DIST_FROM_BEAR := 90.0

const TROUT_SCHOOLS := 7
const TROUT_PER_SCHOOL := 12
const PIKE_COUNT := 6
const FISH_RESTOCK_TIME := 40.0   # a caught fish is replaced after this long
const BEAR_CORPSE_TIME := 90.0
const BEAR_RESPAWN_TIME := 300.0  # a new bear wanders in after the last one dies
const BEAR_RESPAWN_DIST := 150.0  # ...this far from the player

signal bear_spawned(bear)
signal player_killed(animal)
## Sounds and particles, so a host can echo them to other players.
signal fx(kind, a, pos)

var terrain: ForestTerrain
var audio: AudioDirector
var bear: Bear
var animals: Array[Animal] = []
var fish: Array[Fish] = []
var player: PlayerController
var build: BuildSystem

# Each school is {anchor, target, timer, speed, members}; fish steer to a
# personal slot around their school's anchor instead of true boid flocking.
var _schools: Array = []

var kills := 0
## On a client the host runs the wildlife; we only mirror its snapshots.
var puppet_mode := false
var _next_id := 1
var _bear_target_peer := 0
var player_kills := 0
var _bear_respawn := -1.0
var last_kill_label := ""

var _rng := RandomNumberGenerator.new()
var _corpses: Array = []   # [animal, timer]
var _respawns: Array = []  # [species, timer]
var _restocks: Array = []  # [fish kind, timer]


func setup(t: ForestTerrain, world_seed: int) -> void:
	terrain = t
	_rng.seed = world_seed + 7717


func populate() -> void:
	for species_name in Species.PREY:
		var cfg: Dictionary = Species.get_cfg(species_name)
		for i in int(cfg.count):
			_spawn_animal(species_name, _random_spawn())

	_spawn_bear(_random_spawn())

	_populate_lake()


func _new_id() -> int:
	_next_id += 1
	return _next_id


func _spawn_bear(pos: Vector3, id := 0) -> void:
	bear = Bear.new()
	bear.name = "Bear"
	bear.net_id = id if id > 0 else _new_id()
	add_child(bear)
	bear.setup(terrain, self, pos)
	bear.struck.connect(_on_bear_struck)
	bear.made_kill.connect(_on_bear_kill)
	bear.died.connect(_on_bear_died)
	bear_spawned.emit(bear)


func _on_bear_died(b: Bear) -> void:
	_bear_respawn = BEAR_RESPAWN_TIME
	get_tree().create_timer(BEAR_CORPSE_TIME).timeout.connect(func() -> void:
		if is_instance_valid(b):
			b.queue_free())


## Everyone playing (this machine's player and remote players).
func players() -> Array:
	var out := []
	for p in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p):
			out.append(p)
	return out


## The closest living player within `radius` of `pos`, or null.
func nearest_player(pos: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for p in players():
		if not p.alive:
			continue
		var d := pos.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


## Every living thing that fights back, for weapons and future enemies.
func hostiles() -> Array:
	var out := []
	for h in get_tree().get_nodes_in_group("hostile"):
		if is_instance_valid(h) and h.is_alive():
			out.append(h)
	return out


func _populate_lake() -> void:
	for s in TROUT_SCHOOLS:
		var sid := _new_school("trout", _rng.randf_range(0.9, 1.35))
		if sid < 0:
			continue
		for i in TROUT_PER_SCHOOL:
			_spawn_fish("trout", sid)

	# Pike are loners: one "school" each, drifting slowly through deep water.
	for i in PIKE_COUNT:
		var sid := _new_school("pike", _rng.randf_range(0.5, 0.8), 2.2)
		if sid < 0:
			continue
		_spawn_fish("pike", sid)


func _new_school(kind: String, speed: float, min_depth := 1.6) -> int:
	var start := terrain.random_lake_point(_rng, min_depth, 90)
	if start == Vector3.ZERO:
		return -1
	_schools.append({
		"kind": kind,
		"anchor": start,
		"target": start,
		"timer": _rng.randf_range(2.0, 12.0),
		"speed": speed,
		"min_depth": min_depth,
		"members": [],
	})
	return _schools.size() - 1


func _spawn_fish(kind: String, sid: int) -> void:
	var anchor: Vector3 = _schools[sid].anchor
	var jitter := Vector3(_rng.randf_range(-2.0, 2.0), _rng.randf_range(-0.6, 0.6), _rng.randf_range(-2.0, 2.0))
	var pos := anchor + jitter
	if terrain.water_depth(pos.x, pos.z) < Fish.MIN_DEPTH:
		pos = anchor
	var f := Fish.new()
	f.name = "%s_%d_%d" % [kind, sid, fish.size()]
	f.net_id = _new_id()
	add_child(f)
	f.setup(kind, terrain, self, sid, pos)
	fish.append(f)
	_schools[sid].members.append(f)


func school_anchor(sid: int) -> Vector3:
	if sid < 0 or sid >= _schools.size():
		return Vector3.ZERO
	return _schools[sid].anchor


func school_members(sid: int) -> Array:
	if sid < 0 or sid >= _schools.size():
		return []
	return _schools[sid].members


func _update_schools(delta: float) -> void:
	for s in _schools:
		s.timer -= delta
		if s.timer <= 0.0 or s.anchor.distance_to(s.target) < 1.5:
			var p := terrain.random_lake_point(_rng, s.min_depth, 40)
			if p != Vector3.ZERO:
				s.target = p
			s.timer = _rng.randf_range(9.0, 24.0)
		s.anchor = s.anchor.move_toward(s.target, s.speed * delta)


func _random_spawn() -> Vector3:
	var p := terrain.random_walkable_point(_rng, 60)
	if p == Vector3.ZERO:
		p = Vector3(0.0, terrain.sample_height(0.0, 0.0), 0.0)
	return p


func _spawn_animal(species_name: String, pos: Vector3) -> Animal:
	var a := Animal.new()
	a.name = "%s_%d" % [species_name, animals.size()]
	a.net_id = _new_id()
	add_child(a)
	a.setup(species_name, terrain, self, pos)
	a.died.connect(_on_animal_died)
	animals.append(a)
	return a


# --- shared queries -----------------------------------------------------------

## Nearest living prey to `from`, or null.
func nearest_prey(from: Vector3, max_dist: float) -> Animal:
	var best: Animal = null
	var best_d := max_dist * max_dist
	for a in animals:
		if not is_instance_valid(a) or not a.is_alive():
			continue
		var d := from.distance_squared_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


## Nearest fish to `from` (not mid-breach), or null.
func nearest_fish(from: Vector3, max_dist: float) -> Fish:
	var best: Fish = null
	var best_d := max_dist * max_dist
	for f in fish:
		if not is_instance_valid(f):
			continue
		var d := from.distance_squared_to(f.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best


## Take a fish out of the lake for good; the lake restocks after a while.
func catch_fish(f: Fish) -> void:
	if not is_instance_valid(f):
		return
	fish.erase(f)
	if f.school_id >= 0 and f.school_id < _schools.size():
		_schools[f.school_id].members.erase(f)
	_restocks.append([f.kind, FISH_RESTOCK_TIME])
	f.queue_free()


func _restock(kind: String) -> void:
	# Refill the emptiest school of that kind so the lake evens back out.
	var best := -1
	var fewest := 1 << 30
	for sid in _schools.size():
		var s: Dictionary = _schools[sid]
		if s.kind != kind:
			continue
		if s.members.size() < fewest:
			fewest = s.members.size()
			best = sid
	if best >= 0:
		_spawn_fish(kind, best)


## Position of whatever is scaring an animal at `pos`, or Vector3.INF.
func threat_position(pos: Vector3, radius: float) -> Vector3:
	if radius <= 0.0:
		return Vector3.INF
	var best := Vector3.INF
	var best_d := radius * radius
	if bear != null and is_instance_valid(bear) and bear.is_alive():
		var db := pos.distance_squared_to(bear.global_position)
		if db < best_d:
			best_d = db
			best = bear.global_position
	var pr := radius * 0.45
	for p in players():
		var dp := pos.distance_squared_to(p.global_position)
		if dp < pr * pr and dp < best_d:
			best_d = dp
			best = p.global_position
	return best


# --- audio passthrough --------------------------------------------------------
# Creatures route their voices through here so nothing else needs to know
# whether an AudioDirector exists.

func animal_voice(a: Animal, kind: String) -> void:
	if audio != null:
		audio.animal_voice(a.species, kind, a.global_position)
	fx.emit("voice", "%s:%s" % [a.species, kind], a.global_position)


func bear_voice(kind: String, pos: Vector3) -> void:
	if audio != null:
		audio.bear_voice(kind, pos)
	fx.emit("bear", kind, pos)


func rustle(pos: Vector3) -> void:
	if audio != null:
		audio.rustle_at(pos)
	fx.emit("rustle", "", pos)


func fish_count() -> int:
	var n := 0
	for f in fish:
		if is_instance_valid(f):
			n += 1
	return n


func alive_count() -> int:
	var n := 0
	for a in animals:
		if is_instance_valid(a) and a.is_alive():
			n += 1
	return n


# --- lifecycle ----------------------------------------------------------------

func _on_animal_died(a: Animal) -> void:
	if a.get_meta("player_hit", false):
		player_kills += 1
		player_killed.emit(a)
	else:
		kills += 1
		last_kill_label = Species.get_cfg(a.species).label
	_corpses.append([a, CORPSE_TIME])
	_respawns.append([a.species, CORPSE_TIME + RESPAWN_DELAY])


func _on_bear_struck(_victim: Node3D, at: Vector3) -> void:
	_impact_burst(at)


func _on_bear_kill(_victim: Node3D) -> void:
	pass


func _process(delta: float) -> void:
	if puppet_mode:
		return
	_update_schools(delta)

	for i in range(_corpses.size() - 1, -1, -1):
		_corpses[i][1] -= delta
		if _corpses[i][1] <= 0.0:
			var a: Animal = _corpses[i][0]
			if is_instance_valid(a):
				animals.erase(a)
				a.queue_free()
			_corpses.remove_at(i)

	for i in range(_respawns.size() - 1, -1, -1):
		_respawns[i][1] -= delta
		if _respawns[i][1] <= 0.0:
			_respawn(_respawns[i][0])
			_respawns.remove_at(i)

	if _bear_respawn > 0.0:
		_bear_respawn -= delta
		if _bear_respawn <= 0.0:
			var pos := Vector3.ZERO
			for attempt in 40:
				var q := terrain.random_walkable_point(_rng, 30)
				if q != Vector3.ZERO and (player == null or q.distance_to(player.global_position) > BEAR_RESPAWN_DIST):
					pos = q
					break
			if pos == Vector3.ZERO:
				pos = _random_spawn()
			_spawn_bear(pos)

	for i in range(_restocks.size() - 1, -1, -1):
		_restocks[i][1] -= delta
		if _restocks[i][1] <= 0.0:
			_restock(_restocks[i][0])
			_restocks.remove_at(i)


func _respawn(species_name: String) -> void:
	var pos := Vector3.ZERO
	for attempt in 24:
		var p := terrain.random_walkable_point(_rng, 30)
		if p == Vector3.ZERO:
			continue
		if bear != null and is_instance_valid(bear):
			if p.distance_to(bear.global_position) < MIN_RESPAWN_DIST_FROM_BEAR:
				continue
		pos = p
		break
	if pos == Vector3.ZERO:
		pos = _random_spawn()
	_spawn_animal(species_name, pos)


# --- feedback -----------------------------------------------------------------

func _impact_burst(at: Vector3) -> void:
	fx.emit("impact", "", at)
	impact_local(at)


func impact_local(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 26
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.mesh = _burst_mesh()
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.2
	p.color = Color(0.42, 0.33, 0.22)
	add_child(p)
	p.global_position = at + Vector3.UP * 0.5
	p.emitting = true
	get_tree().create_timer(2.4).timeout.connect(p.queue_free)


## Ring of droplets where a fish breaks the surface.
func splash(at: Vector3) -> void:
	fx.emit("splash", "", at)
	splash_local(at)


func splash_local(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 22
	p.lifetime = 1.1
	p.explosiveness = 0.95
	p.mesh = _burst_mesh()
	p.direction = Vector3.UP
	p.spread = 48.0
	p.initial_velocity_min = 1.6
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -12.0, 0)
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.9
	p.color = Color(0.82, 0.92, 0.96, 0.9)
	add_child(p)
	p.global_position = Vector3(at.x, ForestTerrain.WATER_LEVEL + 0.05, at.z)
	p.emitting = true
	get_tree().create_timer(2.4).timeout.connect(p.queue_free)
	if audio != null:
		audio.splash_at(p.global_position)


static var _burst_mesh_cache: Mesh = null

static func _burst_mesh() -> Mesh:
	if _burst_mesh_cache == null:
		var q := QuadMesh.new()
		q.size = Vector2(0.09, 0.09)
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(0.45, 0.35, 0.24)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		q.material = m
		_burst_mesh_cache = q
	return _burst_mesh_cache


# --- online: snapshots ----------------------------------------------------------

const SPECIES_ORDER := ["deer", "rabbit", "fox", "boar"]


func find_entity(id: int) -> Node3D:
	if bear != null and is_instance_valid(bear) and bear.net_id == id:
		return bear
	for a in animals:
		if is_instance_valid(a) and a.net_id == id:
			return a
	for f in fish:
		if is_instance_valid(f) and f.net_id == id:
			return f
	return null


## Host: pack every creature's position and state for the clients.
func snapshot() -> Array:
	var an := PackedFloat32Array()
	for a in animals:
		if not is_instance_valid(a):
			continue
		var p := a.global_position
		an.append_array([a.net_id, SPECIES_ORDER.find(a.species), p.x, p.y, p.z, a.rotation.y,
			a.state + (100 if not a.alive else 0)])
	var br := PackedFloat32Array()
	if bear != null and is_instance_valid(bear):
		var bp := bear.global_position
		var tp := 0
		if bear.target != null and is_instance_valid(bear.target) and bear.target.is_in_group("players"):
			tp = bear.target.peer_id if bear.target is RemotePlayer else 1
		br.append_array([bear.net_id, bp.x, bp.y, bp.z, bear.rotation.y, bear.state, tp])
	var fs := PackedFloat32Array()
	for f in fish:
		if not is_instance_valid(f):
			continue
		var fp := f.global_position
		fs.append_array([f.net_id, 0 if f.kind == "trout" else 1, fp.x, fp.y, fp.z, f.rotation.y, f.rotation.x])
	return [an, br, fs]


## Client: make the local puppets match the host's snapshot.
func apply_snapshot(an: PackedFloat32Array, br: PackedFloat32Array, fs: PackedFloat32Array, me: int) -> void:
	# Animals
	var seen := {}
	var by_id := {}
	for a in animals:
		if is_instance_valid(a):
			by_id[a.net_id] = a
	for i in range(0, an.size(), 7):
		var id := int(an[i])
		seen[id] = true
		var pos := Vector3(an[i + 2], an[i + 3], an[i + 4])
		var st := int(an[i + 6])
		var a: Animal = by_id.get(id)
		if a == null:
			a = Animal.new()
			a.net_id = id
			a.puppet = true
			add_child(a)
			a.setup(SPECIES_ORDER[int(an[i + 1])], terrain, self, pos)
			animals.append(a)
		a.net_update(pos, an[i + 5], st % 100, st >= 100)
	for id in by_id:
		if not seen.has(id):
			var gone: Animal = by_id[id]
			animals.erase(gone)
			gone.queue_free()

	# Bear
	if br.size() >= 7:
		var bid := int(br[0])
		if bear == null or not is_instance_valid(bear) or bear.net_id != bid:
			if bear != null and is_instance_valid(bear):
				bear.queue_free()
			bear = Bear.new()
			bear.name = "Bear"
			bear.net_id = bid
			bear.puppet = true
			add_child(bear)
			bear.setup(terrain, self, Vector3(br[1], br[2], br[3]))
			bear_spawned.emit(bear)
		bear.net_update(Vector3(br[1], br[2], br[3]), br[4], int(br[5]))
		_bear_target_peer = int(br[6])
	elif bear != null and is_instance_valid(bear):
		bear.queue_free()
		bear = null

	# Fish
	var fseen := {}
	var fby := {}
	for f in fish:
		if is_instance_valid(f):
			fby[f.net_id] = f
	for i in range(0, fs.size(), 7):
		var id := int(fs[i])
		fseen[id] = true
		var pos2 := Vector3(fs[i + 2], fs[i + 3], fs[i + 4])
		var f: Fish = fby.get(id)
		if f == null:
			f = Fish.new()
			f.net_id = id
			f.puppet = true
			add_child(f)
			f.setup("trout" if int(fs[i + 1]) == 0 else "pike", terrain, self, -1, pos2)
			fish.append(f)
		f.net_update(pos2, fs[i + 5], fs[i + 6])
	for id in fby:
		if not fseen.has(id):
			var gf: Fish = fby[id]
			fish.erase(gf)
			gf.queue_free()


## Client: is the bear after this machine's player?
func bear_hunting_peer(me: int) -> bool:
	return _bear_target_peer == me
