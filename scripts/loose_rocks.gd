class_name LooseRocks
extends Node3D

## Hand-sized stones lying around the forest floor, drawn as one MultiMesh.
## Picking one up hides its instance; they slowly reappear elsewhere so the
## world never runs dry.

const COUNT := 320
const NEAR_SPAWN := 10          # guaranteed within easy reach of the start
const RESPAWN_TIME := 90.0

var terrain: ForestTerrain
var mm: MultiMesh
var positions := PackedVector3Array()
var taken := PackedByteArray()

var _rng := RandomNumberGenerator.new()
var _respawn: Array = []   # [index, timer]


func setup(t: ForestTerrain, world_seed: int, spawn: Vector3) -> void:
	terrain = t
	_rng.seed = world_seed + 3301

	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Flora.rock(71)
	mm.instance_count = COUNT
	positions.resize(COUNT)
	taken.resize(COUNT)

	for i in COUNT:
		var p := Vector3.ZERO
		if i < NEAR_SPAWN:
			p = _near(spawn, 6.0, 26.0)
		if p == Vector3.ZERO:
			p = terrain.random_walkable_point(_rng, 30)
		if p == Vector3.ZERO:
			p = spawn
		_place(i, p)

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "LooseRocks"
	mmi.multimesh = mm
	mmi.custom_aabb = AABB(Vector3(-ForestTerrain.HALF, -10.0, -ForestTerrain.HALF),
		Vector3(ForestTerrain.SIZE, 120.0, ForestTerrain.SIZE))
	mmi.visibility_range_end = 140.0
	add_child(mmi)


func _near(center: Vector3, rmin: float, rmax: float) -> Vector3:
	for k in 30:
		var a := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(rmin, rmax)
		var x := center.x + cos(a) * r
		var z := center.z + sin(a) * r
		if terrain.in_bounds(x, z) and terrain.is_land(x, z, 0.8) and terrain.sample_normal(x, z).y > 0.8:
			return Vector3(x, terrain.sample_height(x, z), z)
	return Vector3.ZERO


func _place(i: int, p: Vector3) -> void:
	positions[i] = p
	taken[i] = 0
	var s := _rng.randf_range(0.16, 0.24)
	var b := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(s, s * 0.8, s))
	mm.set_instance_transform(i, Transform3D(b, p + Vector3(0, s * 0.35, 0)))
	var v := _rng.randf_range(1.15, 1.45)   # a touch paler than the boulders
	mm.set_instance_color(i, Color(v, v, v * 0.97))


## Index of the stone the view ray points at within `reach`, or -1.
func find_target(eye: Vector3, dir: Vector3, reach: float) -> int:
	var best := -1
	var best_t := reach
	for i in COUNT:
		if taken[i] == 1:
			continue
		var c := positions[i] + Vector3(0, 0.1, 0)
		var to := c - eye
		if to.length_squared() > (reach + 0.5) * (reach + 0.5):
			continue
		var t := to.dot(dir)
		if t < 0.0 or t > best_t:
			continue
		# Generous pick radius - they're small and on the ground.
		if (eye + dir * t).distance_to(c) < 0.45:
			best_t = t
			best = i
	return best


func take(i: int) -> void:
	if i < 0 or taken[i] == 1:
		return
	taken[i] = 1
	mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), positions[i]))
	_respawn.append([i, RESPAWN_TIME])


func available() -> int:
	return COUNT - taken.count(1)


func _process(delta: float) -> void:
	for k in range(_respawn.size() - 1, -1, -1):
		_respawn[k][1] -= delta
		if _respawn[k][1] <= 0.0:
			var p := terrain.random_walkable_point(_rng, 30)
			if p != Vector3.ZERO:
				_place(_respawn[k][0], p)
			_respawn.remove_at(k)
