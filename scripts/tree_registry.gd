class_name TreeRegistry
extends Node3D

## Keeps a record of every tree so the player can knock branches off it with a
## rock and fell it with an axe. Trees are drawn through chunked MultiMeshes,
## so felling one hides its instance, frees its collider and swaps in a falling
## trunk and a stump.

enum Kind { PINE, BROADLEAF, BIRCH }

const BRANCH_STOCK := 3          # branches a tree can drop before it is bare
const BRANCH_CHANCE := 0.45      # per rock hit
const TREE_HP := 100.0
const LOGS := [3, 4, 2]          # per kind
const TRUNK_HEIGHT := 5.0        # the part of a trunk you can actually hit
const GRID := 8.0                # spatial hash cell size

var audio: AudioDirector
var meshes: Array[Mesh] = []

## Each tree: {kind, xf, radius, collider, hp, branches, alive, mm, idx}
var trees: Array = []
var _grid := {}
var _bark_mat: StandardMaterial3D


func _init() -> void:
	meshes = [Flora.pine(), Flora.broadleaf(), Flora.birch()]
	_bark_mat = CritterBuilder.material(Color(0.36, 0.27, 0.19), 0.95)


func add(kind: int, xf: Transform3D, radius: float, collider: CollisionShape3D) -> int:
	var id := trees.size()
	trees.append({
		"kind": kind, "xf": xf, "radius": radius, "collider": collider,
		"hp": TREE_HP, "branches": BRANCH_STOCK, "alive": true, "mm": null, "idx": -1,
	})
	var key := _cell(xf.origin.x, xf.origin.z)
	if not _grid.has(key):
		_grid[key] = []
	_grid[key].append(id)
	return id


## Called by the scatterer once the tree's MultiMesh slot is known.
func bind_instance(id: int, mm: MultiMesh, idx: int) -> void:
	trees[id].mm = mm
	trees[id].idx = idx


func _cell(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / GRID), floori(z / GRID))


func count_alive() -> int:
	var n := 0
	for t in trees:
		if t.alive:
			n += 1
	return n


func position_of(id: int) -> Vector3:
	return trees[id].xf.origin


## The standing tree whose trunk the ray from `eye` along `dir` hits first
## within `reach` metres, or -1.
func find_target(eye: Vector3, dir: Vector3, reach: float) -> int:
	var best := -1
	var best_t := reach
	var c := _cell(eye.x, eye.z)
	var span := int(ceil(reach / GRID)) + 1
	for gx in range(c.x - span, c.x + span + 1):
		for gz in range(c.y - span, c.y + span + 1):
			var key := Vector2i(gx, gz)
			if not _grid.has(key):
				continue
			for id in _grid[key]:
				var t: Dictionary = trees[id]
				if not t.alive:
					continue
				var hit := _ray_trunk(eye, dir, t.xf.origin, float(t.radius) + 0.15)
				if hit >= 0.0 and hit < best_t:
					var y := eye.y + dir.y * hit
					if y > t.xf.origin.y - 0.5 and y < t.xf.origin.y + TRUNK_HEIGHT:
						best_t = hit
						best = id
	return best


## Distance along the ray to a vertical cylinder at `base`, or -1.
static func _ray_trunk(eye: Vector3, dir: Vector3, base: Vector3, r: float) -> float:
	var ox := eye.x - base.x
	var oz := eye.z - base.z
	var a := dir.x * dir.x + dir.z * dir.z
	if a < 0.000001:
		return -1.0
	var b := 2.0 * (ox * dir.x + oz * dir.z)
	var cc := ox * ox + oz * oz - r * r
	if cc <= 0.0:
		return 0.0   # already touching the trunk
	var disc := b * b - 4.0 * a * cc
	if disc < 0.0:
		return -1.0
	var t := (-b - sqrt(disc)) / (2.0 * a)
	return t if t >= 0.0 else -1.0


## A rock blow. Returns true when a branch comes down.
func hit_with_rock(id: int, rng: RandomNumberGenerator) -> bool:
	var t: Dictionary = trees[id]
	if audio != null:
		audio.chop_at(t.xf.origin + Vector3.UP * 1.5, true)
	if t.branches <= 0:
		return false
	if rng.randf() < BRANCH_CHANCE:
		t.branches -= 1
		return true
	return false


func branches_left(id: int) -> int:
	return trees[id].branches


## An axe blow. Returns the logs gained (0 until the tree comes down).
func chop(id: int, damage: float, from: Vector3) -> int:
	var t: Dictionary = trees[id]
	if not t.alive:
		return 0
	t.hp -= damage
	if audio != null:
		audio.chop_at(t.xf.origin + Vector3.UP * 1.2)
	if t.hp > 0.0:
		return 0
	_fell(id, from)
	return LOGS[t.kind]


## Remove standing trees around a point without any felling effects - used
## to clear a site for generated buildings.
func clear_area(center: Vector3, radius: float) -> void:
	var c := _cell(center.x, center.z)
	var span := int(ceil(radius / GRID)) + 1
	for gx in range(c.x - span, c.x + span + 1):
		for gz in range(c.y - span, c.y + span + 1):
			var key := Vector2i(gx, gz)
			if not _grid.has(key):
				continue
			for id in _grid[key]:
				var t: Dictionary = trees[id]
				if not t.alive:
					continue
				var o: Vector3 = t.xf.origin
				if Vector2(o.x - center.x, o.z - center.z).length() > radius:
					continue
				t.alive = false
				if t.mm != null:
					t.mm.set_instance_transform(t.idx, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), o))
				if t.collider != null and is_instance_valid(t.collider):
					t.collider.queue_free()
					t.collider = null


func health_of(id: int) -> float:
	return trees[id].hp / TREE_HP


func _fell(id: int, from: Vector3) -> void:
	var t: Dictionary = trees[id]
	t.alive = false
	var xf: Transform3D = t.xf

	# Hide the baked instance and drop its collider.
	if t.mm != null:
		var mm: MultiMesh = t.mm
		mm.set_instance_transform(t.idx, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), xf.origin))
	if t.collider != null and is_instance_valid(t.collider):
		t.collider.queue_free()
		t.collider = null

	# Stump left behind.
	var stump := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	var r: float = t.radius
	cyl.top_radius = r * 0.95
	cyl.bottom_radius = r * 1.15
	cyl.height = 0.9
	cyl.radial_segments = 7
	stump.mesh = cyl
	stump.material_override = _bark_mat
	add_child(stump)
	stump.global_position = xf.origin + Vector3(0, 0.2, 0)

	# The trunk topples away from whoever cut it.
	var away := xf.origin - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var axis := Vector3.UP.cross(away).normalized()
	var falling := MeshInstance3D.new()
	falling.mesh = meshes[t.kind]
	falling.transform = xf
	add_child(falling)

	var basis0 := xf.basis
	var origin := xf.origin
	var tw := create_tween()
	tw.tween_method(func(a: float) -> void:
		falling.transform = Transform3D(Basis(axis, a) * basis0, origin), 0.0, PI * 0.47, 1.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if audio != null:
			audio.thud_at(origin + away * 4.0))
	tw.tween_interval(3.0)
	# Sink it into the ground rather than leaving a permanent log across the path.
	tw.tween_property(falling, "position:y", origin.y - 2.0, 2.5)
	tw.tween_callback(falling.queue_free)
