class_name Arrow
extends Node3D

## A fired arrow: flies under gravity, hits the first creature (hostile or
## animal) whose body sphere it passes through, or sticks in a tree or the
## ground and fades away.

signal hit(target, killed)

const SPEED := 48.0
const GRAVITY := 9.0
const LIFETIME := 6.0
const STUCK_TIME := 8.0

var velocity := Vector3.ZERO
var damage := 48.0
var terrain: ForestTerrain
var manager: WildlifeManager
var trees: TreeRegistry
var shooter_pos := Vector3.ZERO

var _age := 0.0
var _stuck := -1.0


func fire(from: Vector3, dir: Vector3) -> void:
	global_position = from
	shooter_pos = from
	velocity = dir.normalized() * SPEED
	_build()
	_orient()


func _build() -> void:
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.008
	shaft.bottom_radius = 0.008
	shaft.height = 0.7
	shaft.radial_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = shaft
	mi.material_override = CritterBuilder.material(Color(0.55, 0.42, 0.26), 0.8)
	mi.rotation.x = -PI * 0.5      # lie along -Z
	add_child(mi)
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.02
	cone.height = 0.07
	cone.radial_segments = 4
	tip.mesh = cone
	tip.material_override = CritterBuilder.material(Color(0.3, 0.3, 0.3), 0.6)
	tip.rotation.x = -PI * 0.5
	tip.position = Vector3(0, 0, -0.38)
	add_child(tip)
	var fletch := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.05, 0.05, 0.1)
	fletch.mesh = fb
	fletch.material_override = CritterBuilder.material(Color(0.85, 0.85, 0.8), 0.9)
	fletch.position = Vector3(0, 0, 0.3)
	add_child(fletch)


func _orient() -> void:
	if velocity.length() > 0.01:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)


func _physics_process(delta: float) -> void:
	if _stuck >= 0.0:
		_stuck += delta
		if _stuck > STUCK_TIME:
			queue_free()
		return
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return

	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta

	# Creatures first: segment vs body sphere.
	var best: Node3D = null
	var best_t := 2.0
	for c in _targets():
		var r := 1.1 if c is Bear else 0.55
		var center: Vector3 = c.global_position + Vector3.UP * (0.9 if c is Bear else 0.45)
		var t := _segment_sphere(from, to, center, r)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = c
	if best != null:
		if best is Animal:
			best.set_meta("player_hit", true)
		best.call("take_damage", damage, shooter_pos)
		var killed: bool = not best.call("is_alive")
		hit.emit(best, killed)
		queue_free()
		return

	# Trees and ground.
	var dir := to - from
	var seg := dir.length()
	if trees != null and seg > 0.0:
		var tid := trees.find_target(from, dir / seg, seg)
		if tid >= 0:
			_stick(from + dir / seg * maxf(seg * 0.5, 0.0))
			return
	if to.y <= terrain.sample_height(to.x, to.z):
		_stick(Vector3(to.x, terrain.sample_height(to.x, to.z) + 0.05, to.z))
		return

	global_position = to
	_orient()


func _targets() -> Array:
	var out := manager.hostiles()
	for a in manager.animals:
		if is_instance_valid(a) and a.is_alive():
			out.append(a)
	return out


## Parameter (0..1) along from->to where it first enters the sphere, or -1.
static func _segment_sphere(a: Vector3, b: Vector3, c: Vector3, r: float) -> float:
	var d := b - a
	var f := a - c
	var aa := d.dot(d)
	if aa < 0.000001:
		return 0.0 if f.length() <= r else -1.0
	var bb := 2.0 * f.dot(d)
	var cc := f.dot(f) - r * r
	if cc <= 0.0:
		return 0.0
	var disc := bb * bb - 4.0 * aa * cc
	if disc < 0.0:
		return -1.0
	var t := (-bb - sqrt(disc)) / (2.0 * aa)
	return t if t >= 0.0 and t <= 1.0 else -1.0


func _stick(at: Vector3) -> void:
	global_position = at
	_stuck = 0.0
