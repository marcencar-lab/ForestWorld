class_name BuildSystem
extends Node3D

## Grid-snapped construction. Floors, roofs, lean-tos and campfires occupy a
## 3 m cell; walls and doors sit on a cell edge. A translucent ghost previews
## the piece under the crosshair, green when it can be placed.
##
## Also answers the world's questions about buildings: is this spot under a
## roof, is there a fire nearby, and is a wall in the bear's way.

signal placed(structure)
signal destroyed(structure)
signal hp_changed(structure)

const CELL := 3.0
const WALL_H := 2.6
const FLOOR_H := 0.25
const MAX_SLOPE := 1.8        # metres of height change a footprint may span
const REACH := 9.0
const FIRE_WARM_RADIUS := 6.0
const FIRE_START_FUEL := 240.0
const STRUCT_LAYER := 2       # physics layer bit used for interaction rays

const PIECES := {
	"leanto": {"label": "Lean-to", "cost": {"branch": 8}, "hp": 60.0, "slot": "cell",
		"desc": "keeps the rain off; won't stop the bear"},
	"campfire": {"label": "Campfire", "cost": {"rock": 3, "branch": 4}, "hp": 40.0, "slot": "fire",
		"desc": "warmth and light; E to add fuel"},
	"floor": {"label": "Floor", "cost": {"plank": 3}, "hp": 300.0, "slot": "floor",
		"desc": "level foundation"},
	"wall": {"label": "Wall", "cost": {"plank": 4}, "hp": 600.0, "slot": "edge",
		"desc": "blocks the bear"},
	"door": {"label": "Door", "cost": {"plank": 5}, "hp": 450.0, "slot": "edge",
		"desc": "E to open / close"},
	"roof": {"label": "Roof", "cost": {"plank": 4}, "hp": 300.0, "slot": "roof",
		"desc": "needs a wall to rest on"},
	"bedroll": {"label": "Bedroll", "cost": {"branch": 4, "plank": 2}, "hp": 60.0, "slot": "bed",
		"desc": "E to sleep through the night when sheltered"},
	# Not buildable - found in abandoned cabins.
	"crate": {"label": "Supply crate", "cost": {}, "hp": 200.0, "slot": "crate", "desc": ""},
}
const ORDER := ["leanto", "campfire", "floor", "wall", "door", "roof", "bedroll"]

var terrain: ForestTerrain
var audio: AudioDirector
var free_build := false           # sandbox: no costs

var active := false
var piece_idx := 0
var structures: Array[Structure] = []
var slots := {}                   # slot key -> Structure

var plan := {}                    # the current ghost placement
var _ghost: Node3D
var _ghost_kind := ""
var _ghost_mat: StandardMaterial3D
var _mats := {}
var _rng := RandomNumberGenerator.new()
var _weathered := false           # building a ruin: grey, rotten wood
var _crate_id := 0


func setup(t: ForestTerrain, a: AudioDirector) -> void:
	terrain = t
	audio = a
	_rng.randomize()
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.35)
	_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func current_kind() -> String:
	return ORDER[piece_idx]


func set_active(on: bool) -> void:
	active = on
	if not on and _ghost != null:
		_ghost.visible = false
	plan = {}


func cycle(step: int) -> void:
	piece_idx = posmod(piece_idx + step, ORDER.size())


func select(i: int) -> void:
	if i >= 0 and i < ORDER.size():
		piece_idx = i


## "1 plank", "4 planks", "3 branches".
static func plural(n: int, item: String) -> String:
	if n == 1:
		return "1 " + item
	return "%d %s%s" % [n, item, "es" if item.ends_with("ch") or item.ends_with("sh") else "s"]


static func cost_text(kind: String) -> String:
	var parts := []
	var cost: Dictionary = PIECES[kind].cost
	for k in cost:
		parts.append(plural(cost[k], k))
	return ", ".join(parts)


func can_afford(kind: String, inv: Dictionary) -> bool:
	if free_build:
		return true
	var cost: Dictionary = PIECES[kind].cost
	for k in cost:
		if int(inv.get(k, 0)) < int(cost[k]):
			return false
	return true


# --- grid helpers -------------------------------------------------------------

static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL), floori(z / CELL))


static func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0.0, (c.y + 0.5) * CELL)


func _ground_range(points: Array) -> Vector2:
	var lo := INF
	var hi := -INF
	for p in points:
		var h := terrain.sample_height(p.x, p.y)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	return Vector2(lo, hi)


func _cell_corners(c: Vector2i) -> Array:
	var x0 := c.x * CELL
	var z0 := c.y * CELL
	return [Vector2(x0, z0), Vector2(x0 + CELL, z0), Vector2(x0, z0 + CELL),
		Vector2(x0 + CELL, z0 + CELL), Vector2(x0 + CELL * 0.5, z0 + CELL * 0.5)]


## Where a piece standing in this cell starts: the floor top, or the highest
## ground under the cell.
func cell_base(c: Vector2i) -> float:
	var key := "floor:%d:%d" % [c.x, c.y]
	if slots.has(key):
		return slots[key].base_y + FLOOR_H
	return _ground_range(_cell_corners(c)).y


func _edge_cells(axis: String, ex: int, ez: int) -> Array:
	if axis == "x":
		return [Vector2i(ex, ez - 1), Vector2i(ex, ez)]
	return [Vector2i(ex - 1, ez), Vector2i(ex, ez)]


func _cell_edges(c: Vector2i) -> Array:
	return ["edge:x:%d:%d" % [c.x, c.y], "edge:x:%d:%d" % [c.x, c.y + 1],
		"edge:z:%d:%d" % [c.x, c.y], "edge:z:%d:%d" % [c.x + 1, c.y]]


# --- aiming & validation ------------------------------------------------------

## March the view ray until it dips under the terrain (or a floor top).
func _aim_point(eye: Vector3, dir: Vector3) -> Vector3:
	var t := 0.3
	while t <= REACH:
		var p := eye + dir * t
		var ground := terrain.sample_height(p.x, p.z)
		var fk := "floor:%d:%d" % [cell_of(p.x, p.z).x, cell_of(p.x, p.z).y]
		if slots.has(fk):
			ground = maxf(ground, slots[fk].base_y + FLOOR_H)
		if p.y <= ground:
			return Vector3(p.x, ground, p.z)
		t += 0.15
	return Vector3.INF


func update_ghost(eye: Vector3, dir: Vector3, player: PlayerController) -> void:
	if not active:
		return
	var kind := current_kind()
	if _ghost_kind != kind:
		if _ghost != null:
			_ghost.queue_free()
		_ghost = Node3D.new()
		_ghost.name = "Ghost"
		add_child(_ghost)
		_build_visual(kind, _ghost, _ghost_mat)
		_ghost_kind = kind

	var hit := _aim_point(eye, dir)
	if hit == Vector3.INF:
		plan = {"ok": false, "reason": "Aim at the ground nearby", "kind": kind}
		_ghost.visible = false
		return
	plan = _plan(kind, hit, player)
	_ghost.visible = true
	_ghost.global_transform = plan.xf
	_ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.35) if plan.ok else Color(1.0, 0.25, 0.2, 0.35)


func _plan(kind: String, hit: Vector3, player: PlayerController) -> Dictionary:
	var def: Dictionary = PIECES[kind]
	var c := cell_of(hit.x, hit.z)
	var center := cell_center(c)
	var out := {"ok": true, "reason": "", "kind": kind, "cell": c, "yaw": 0.0}

	match def.slot:
		"floor":
			out.key = "floor:%d:%d" % [c.x, c.y]
			var r := _ground_range(_cell_corners(c))
			out.base = r.y
			if r.y - r.x > MAX_SLOPE:
				out.reason = "Ground is too steep here"
		"roof":
			out.key = "roof:%d:%d" % [c.x, c.y]
			var top := -INF
			for ek in _cell_edges(c):
				if slots.has(ek):
					top = maxf(top, slots[ek].base_y)
			if top == -INF:
				out.reason = "A roof needs a wall or door to rest on"
				top = cell_base(c)
			out.base = top + WALL_H
		"cell":
			out.key = "cell:%d:%d" % [c.x, c.y]
			out.base = cell_base(c)
			var r2 := _ground_range(_cell_corners(c))
			if r2.y - r2.x > MAX_SLOPE and not slots.has("floor:%d:%d" % [c.x, c.y]):
				out.reason = "Ground is too steep here"
			# Open side faces the builder.
			out.yaw = snappedf(player.rotation.y + PI, PI * 0.5)
		"bed":
			out.key = "bed:%d:%d" % [c.x, c.y]
			out.base = cell_base(c)
			out.yaw = snappedf(player.rotation.y, PI * 0.5)
			var rb := _ground_range(_cell_corners(c))
			if rb.y - rb.x > 0.9 and not slots.has("floor:%d:%d" % [c.x, c.y]):
				out.reason = "Needs level ground or a floor"
		"fire":
			out.key = "fire:%d:%d" % [c.x, c.y]
			out.base = terrain.sample_height(center.x, center.z)
			if slots.has("floor:%d:%d" % [c.x, c.y]):
				out.reason = "Not on a wooden floor!"
			# Only the fire's own small footprint needs to be flat-ish.
			var fc := Vector2(center.x, center.z)
			var r3 := _ground_range([fc + Vector2(-0.7, -0.7), fc + Vector2(0.7, -0.7),
				fc + Vector2(-0.7, 0.7), fc + Vector2(0.7, 0.7), fc])
			if r3.y - r3.x > 0.9:
				out.reason = "Ground is too steep here"
		"edge":
			var u := hit.x / CELL - c.x
			var v := hit.z / CELL - c.y
			var ds := [v, 1.0 - v, u, 1.0 - u]
			var side := ds.find(ds.min())
			var axis := "x" if side < 2 else "z"
			var ex := c.x + (1 if side == 3 else 0)
			var ez := c.y + (1 if side == 1 else 0)
			out.key = "edge:%s:%d:%d" % [axis, ex, ez]
			var a: Vector2
			var b: Vector2
			if axis == "x":
				center = Vector3((ex + 0.5) * CELL, 0.0, ez * CELL)
				a = Vector2(ex * CELL, ez * CELL)
				b = Vector2((ex + 1) * CELL, ez * CELL)
				out.yaw = 0.0
			else:
				center = Vector3(ex * CELL, 0.0, (ez + 0.5) * CELL)
				a = Vector2(ex * CELL, ez * CELL)
				b = Vector2(ex * CELL, (ez + 1) * CELL)
				out.yaw = PI * 0.5
			var gr := _ground_range([a, b, (a + b) * 0.5])
			var base := gr.y
			for ec in _edge_cells(axis, ex, ez):
				var fk := "floor:%d:%d" % [ec.x, ec.y]
				if slots.has(fk):
					base = maxf(base, slots[fk].base_y + FLOOR_H)
			out.base = base
			out.seg = [a, b]
			if gr.y - gr.x > MAX_SLOPE:
				out.reason = "Ground is too steep here"
			var pp := Vector2(player.global_position.x, player.global_position.z)
			if pp.distance_to(Geometry2D.get_closest_point_to_segment(pp, a, b)) < 0.75:
				out.reason = "Step out of the way first"

	out.xf = Transform3D(Basis(Vector3.UP, out.yaw), Vector3(center.x, out.base, center.z))

	if not terrain.in_bounds(center.x, center.z):
		out.reason = "Too close to the edge of the world"
	elif not terrain.is_land(center.x, center.z, 0.3):
		out.reason = "Can't build in the water"
	elif slots.has(out.key):
		out.reason = "Something is already built there"
	elif out.reason == "" and not can_afford(kind, player.inv):
		out.reason = "Need " + cost_text(kind)
	out.ok = out.reason == ""
	return out


## Place whatever the ghost shows. Spends from `inv`; returns the new piece.
func try_place(inv: Dictionary) -> Structure:
	if plan.is_empty() or not plan.ok:
		return null
	var kind: String = plan.kind
	if not free_build:
		var cost: Dictionary = PIECES[kind].cost
		for k in cost:
			inv[k] = int(inv.get(k, 0)) - int(cost[k])
	var s := spawn_piece(kind, plan)
	plan = {}
	return s


func spawn_piece(kind: String, p: Dictionary) -> Structure:
	var s := Structure.new()
	s.name = "%s_%d" % [kind, structures.size()]
	s.kind = kind
	s.slot_key = p.key
	s.cell = p.cell
	s.base_y = p.base
	s.max_hp = PIECES[kind].hp
	s.hp = s.max_hp * float(p.get("hp_frac", 1.0))
	s.collision_layer = 1 | STRUCT_LAYER
	s.collision_mask = 0
	add_child(s)
	s.global_transform = p.xf
	_weathered = p.get("ruined", false)
	s.ruined = _weathered
	if p.has("seg"):
		s.seg_ab = p.seg
	_build_visual(kind, s, null)
	_weathered = false
	_build_collision(kind, s)
	if kind == "bedroll":
		s.collision_layer = STRUCT_LAYER   # lie-on-able, not a wall
	if p.has("seg"):
		var a: Vector2 = p.seg[0]
		var b: Vector2 = p.seg[1]
		if kind == "door":
			var dir := (b - a).normalized()
			s.segments = [
				[a, a + dir * 0.95, false],
				[b - dir * 0.95, b, false],
				[a + dir * 0.95, b - dir * 0.95, true],
			]
		else:
			s.segments = [[a, b, false]]
	if kind == "campfire":
		s.collision_layer = STRUCT_LAYER   # interactable, but you can step over it
		s.fuel = FIRE_START_FUEL
		if audio != null:
			s.fire_audio = audio.make_fire_player()
			s.fire_audio.position = Vector3(0, 0.4, 0)
			s.add_child(s.fire_audio)
		s._update_fire()
	structures.append(s)
	slots[s.slot_key] = s
	if audio != null and not p.get("silent", false):
		audio.build_at(s.global_position)
	placed.emit(s)
	return s


## Drop a loot crate (world-generation only).
func spawn_crate(pos: Vector3, yaw: float, loot: Array) -> Structure:
	_crate_id += 1
	var s := spawn_piece("crate", {
		"key": "crate:%d" % _crate_id, "cell": cell_of(pos.x, pos.z), "base": pos.y,
		"xf": Transform3D(Basis(Vector3.UP, yaw), pos), "silent": true,
	})
	s.loot = loot
	return s


# --- queries used by the world, the player and the bear -----------------------

## Is `pos` under a roof or a lean-to?
func is_sheltered(pos: Vector3) -> bool:
	var c := cell_of(pos.x, pos.z)
	var rk := "roof:%d:%d" % [c.x, c.y]
	if slots.has(rk) and slots[rk].base_y > pos.y + 1.2:
		return true
	var lk := "cell:%d:%d" % [c.x, c.y]
	if slots.has(lk) and pos.y < slots[lk].base_y + 2.5:
		return true
	return false


## 0..1 warmth from lit campfires near `pos`.
func fire_warmth(pos: Vector3) -> float:
	var best := 0.0
	for s in structures:
		if s.is_lit():
			var d := s.global_position.distance_to(pos)
			if d < FIRE_WARM_RADIUS:
				best = maxf(best, 1.0 - d / FIRE_WARM_RADIUS * 0.6)
	return best


## The first wall or door the path from `a` to `b` (XZ) comes within
## `radius` of, or null.
func blocking(a: Vector2, b: Vector2, radius: float) -> Structure:
	var best: Structure = null
	var best_d := radius
	for s in structures:
		if s.segments.is_empty():
			continue
		var d := s.path_distance(a, b)
		if d < best_d:
			best_d = d
			best = s
	return best


func damage(s: Structure, amount: float) -> void:
	if s == null or not is_instance_valid(s):
		return
	s.hp -= amount
	if s.hp <= 0.0:
		remove(s)
	else:
		hp_changed.emit(s)


func remove(s: Structure) -> void:
	structures.erase(s)
	if slots.get(s.slot_key) == s:
		slots.erase(s.slot_key)
	if audio != null:
		audio.thud_at(s.global_position)
	destroyed.emit(s)
	s.queue_free()


## Restore health; returns false if nothing needed fixing.
func repair(s: Structure, amount: float) -> bool:
	if s.hp >= s.max_hp:
		return false
	s.hp = minf(s.hp + amount, s.max_hp)
	if audio != null:
		audio.build_at(s.global_position)
	hp_changed.emit(s)
	return true


# --- geometry -----------------------------------------------------------------

func _mat(key: String, c: Color) -> StandardMaterial3D:
	if _weathered:
		key = "w_" + key
		c = c.lerp(Color(0.36, 0.36, 0.33), 0.72).darkened(0.12)
	if not _mats.has(key):
		_mats[key] = CritterBuilder.material(c, 0.9)
	return _mats[key]


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, basis := Basis()) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.transform = Transform3D(basis, pos)
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r: float, h: float, xf: Transform3D, mat: Material) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 1.1
	cm.height = h
	cm.radial_segments = 6
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.transform = xf
	parent.add_child(mi)
	return mi


func _plank_mat(i: int) -> StandardMaterial3D:
	var shades := [Color(0.62, 0.45, 0.28), Color(0.57, 0.41, 0.25), Color(0.66, 0.49, 0.31), Color(0.53, 0.38, 0.23)]
	return _mat("plank%d" % (i % shades.size()), shades[i % shades.size()])


## A row of horizontal boards filling x0..x1, y0..y1 in the parent's space.
func _boards(parent: Node3D, x0: float, x1: float, y0: float, y1: float, override: Material) -> void:
	var n := maxi(int(round((y1 - y0) / 0.43)), 1)
	var bh := (y1 - y0) / n
	for k in n:
		var m: Material = override if override else _plank_mat(k + int(x0 * 7.0))
		_box(parent, Vector3(x1 - x0, bh - 0.025, 0.12), Vector3((x0 + x1) * 0.5, y0 + bh * (k + 0.5), 0), m)


func _build_visual(kind: String, parent: Node3D, override: Material) -> void:
	var wood: Material = override if override else _mat("beam", Color(0.40, 0.28, 0.17))
	var dark: Material = override if override else _mat("footing", Color(0.28, 0.21, 0.15))
	var branch: Material = override if override else _mat("branch", Color(0.36, 0.26, 0.17))
	var thatch: Material = override if override else _mat("thatch", Color(0.30, 0.36, 0.16))
	var stone: Material = override if override else _mat("stone", Color(0.46, 0.45, 0.43))
	var half := CELL * 0.5

	match kind:
		"floor":
			_box(parent, Vector3(CELL - 0.1, 1.6, CELL - 0.1), Vector3(0, -0.8 + FLOOR_H - 0.08, 0), dark)
			for k in 6:
				var m: Material = override if override else _plank_mat(k)
				_box(parent, Vector3(CELL, 0.08, 0.47), Vector3(0, FLOOR_H - 0.04, -half + 0.25 + k * 0.5), m)
		"wall":
			_box(parent, Vector3(CELL, 1.2, 0.14), Vector3(0, -0.6, 0), dark)
			_boards(parent, -half, half, 0.0, WALL_H, override)
			for sx in [-1.0, 1.0]:
				_box(parent, Vector3(0.16, WALL_H + 0.1, 0.2), Vector3(sx * (half - 0.08), WALL_H * 0.5, 0), wood)
		"door":
			_box(parent, Vector3(CELL, 1.2, 0.14), Vector3(0, -0.6, 0), dark)
			_boards(parent, -half, -0.55, 0.0, WALL_H, override)
			_boards(parent, 0.55, half, 0.0, WALL_H, override)
			_boards(parent, -0.55, 0.55, 2.15, WALL_H, override)
			for sx in [-1.0, 1.0]:
				_box(parent, Vector3(0.16, WALL_H + 0.1, 0.2), Vector3(sx * (half - 0.08), WALL_H * 0.5, 0), wood)
				_box(parent, Vector3(0.1, 2.15, 0.18), Vector3(sx * 0.6, 1.075, 0), wood)
			var pivot := Node3D.new()
			pivot.name = "DoorPivot"
			pivot.position = Vector3(-0.55, 0, 0)
			parent.add_child(pivot)
			for k in 4:
				var m2: Material = override if override else _plank_mat(k + 2)
				_box(pivot, Vector3(0.27, 2.1, 0.07), Vector3(0.14 + k * 0.275, 1.06, 0), m2)
			_box(pivot, Vector3(1.05, 0.12, 0.09), Vector3(0.55, 0.5, 0.05), wood)
			_box(pivot, Vector3(1.05, 0.12, 0.09), Vector3(0.55, 1.6, 0.05), wood)
			if parent is Structure:
				parent.door_pivot = pivot
		"roof":
			for k in 7:
				var m3: Material = override if override else _plank_mat(k + 1)
				_box(parent, Vector3(CELL + 0.3, 0.09, 0.47), Vector3(0, 0.14, -half - 0.1 + 0.25 + k * 0.48), m3)
			for sx2 in [-1.0, 0.0, 1.0]:
				_box(parent, Vector3(0.14, 0.14, CELL + 0.2), Vector3(sx2 * (half - 0.2), 0.03, 0), wood)
		"leanto":
			var front_h := 2.1
			var back_h := 0.15
			var run := Vector2(CELL - 0.4, front_h - back_h)
			var slope := atan2(run.y, run.x)
			var length := run.length() + 0.3
			for sx3 in [-1.0, 1.0]:
				_cyl(parent, 0.07, front_h, Transform3D(Basis(), Vector3(sx3 * (half - 0.2), front_h * 0.5, -half + 0.2)), branch)
			# Poles laid from the front crossbar down to the ground at the back.
			var mid := Vector3(0, (front_h + back_h) * 0.5, 0)
			for k in 9:
				var x := -half + 0.2 + k * (CELL - 0.4) / 8.0
				var b := Basis(Vector3.RIGHT, slope - PI * 0.5)
				_cyl(parent, 0.05, length, Transform3D(b, Vector3(x, mid.y, mid.z)), branch)
			_cyl(parent, 0.06, CELL - 0.2, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, front_h, -half + 0.2)), branch)
			_box(parent, Vector3(CELL - 0.2, 0.12, length), mid + Vector3(0, 0.1, 0), thatch,
				Basis(Vector3.RIGHT, slope))
		"bedroll":
			var cloth: Material = override if override else _mat("cloth", Color(0.36, 0.40, 0.26))
			var pillow: Material = override if override else _mat("pillow", Color(0.62, 0.58, 0.48))
			_box(parent, Vector3(0.9, 0.12, 2.0), Vector3(0, 0.06, 0), cloth)
			_box(parent, Vector3(0.55, 0.12, 0.3), Vector3(0, 0.16, 0.75), pillow)
			_box(parent, Vector3(0.92, 0.05, 1.2), Vector3(0, 0.14, -0.35), cloth)
		"crate":
			var crate_w: Material = override if override else _mat("crate", Color(0.42, 0.33, 0.22))
			var band: Material = override if override else _mat("band", Color(0.25, 0.25, 0.26))
			_box(parent, Vector3(0.95, 0.5, 0.6), Vector3(0, 0.25, 0), crate_w)
			for bx in [-0.35, 0.35]:
				_box(parent, Vector3(0.06, 0.52, 0.62), Vector3(bx, 0.25, 0), band)
			var lid := Node3D.new()
			lid.name = "Lid"
			lid.position = Vector3(0, 0.5, 0.3)     # hinged along the back edge
			parent.add_child(lid)
			_box(lid, Vector3(0.97, 0.08, 0.62), Vector3(0, 0.04, -0.3), crate_w)
			if parent is Structure:
				parent.lid = lid
		"campfire":
			for k in 8:
				var a := TAU * k / 8.0
				_box(parent, Vector3(0.22, 0.16, 0.2), Vector3(cos(a) * 0.5, 0.08, sin(a) * 0.5), stone,
					Basis(Vector3.UP, a))
			for k2 in 3:
				var a2 := TAU * k2 / 3.0
				var lb := Basis(Vector3.UP, a2) * Basis(Vector3.RIGHT, 1.1)
				_cyl(parent, 0.06, 0.8, Transform3D(lb, Vector3(cos(a2) * 0.12, 0.2, sin(a2) * 0.12)), wood)
			if override == null and parent is Structure:
				_add_fire(parent)


func _add_fire(s: Structure) -> void:
	var flames := Node3D.new()
	flames.name = "Flames"
	flames.position = Vector3(0, 0.15, 0)
	s.add_child(flames)
	var cols := [Color(1.0, 0.45, 0.08), Color(1.0, 0.72, 0.2), Color(1.0, 0.9, 0.55)]
	for k in 3:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = cols[k]
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.85
		m.emission_enabled = true
		m.emission = cols[k]
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.28 - k * 0.07
		cone.height = 0.75 - k * 0.15
		cone.radial_segments = 6
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0, cone.height * 0.5, 0)
		flames.add_child(mi)
	s.flames = flames

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 2.2
	light.omni_range = 11.0
	light.position = Vector3(0, 0.8, 0)
	s.add_child(light)
	s.light = light


func _shape(s: Structure, size: Vector3, pos: Vector3, basis := Basis()) -> CollisionShape3D:
	var box := BoxShape3D.new()
	box.size = size
	var cs := CollisionShape3D.new()
	cs.shape = box
	cs.transform = Transform3D(basis, pos)
	s.add_child(cs)
	return cs


func _build_collision(kind: String, s: Structure) -> void:
	var half := CELL * 0.5
	match kind:
		"floor":
			_shape(s, Vector3(CELL, 1.6, CELL), Vector3(0, FLOOR_H - 0.8, 0))
		"wall":
			_shape(s, Vector3(CELL, WALL_H + 1.2, 0.24), Vector3(0, (WALL_H - 1.2) * 0.5, 0))
		"door":
			var side := half - 0.55
			_shape(s, Vector3(side, WALL_H + 1.2, 0.24), Vector3(-half + side * 0.5, (WALL_H - 1.2) * 0.5, 0))
			_shape(s, Vector3(side, WALL_H + 1.2, 0.24), Vector3(half - side * 0.5, (WALL_H - 1.2) * 0.5, 0))
			_shape(s, Vector3(1.1, WALL_H - 2.15, 0.24), Vector3(0, (WALL_H + 2.15) * 0.5, 0))
			s.is_door = true
			s.door_shape = _shape(s, Vector3(1.1, 2.15, 0.2), Vector3(0, 1.075, 0))
		"roof":
			_shape(s, Vector3(CELL + 0.3, 0.2, CELL + 0.3), Vector3(0, 0.12, 0))
		"leanto":
			var run := Vector2(CELL - 0.4, 2.1 - 0.15)
			_shape(s, Vector3(CELL - 0.2, 0.15, run.length() + 0.3), Vector3(0, 1.2, 0),
				Basis(Vector3.RIGHT, atan2(run.y, run.x)))
		"campfire":
			_shape(s, Vector3(1.2, 0.5, 1.2), Vector3(0, 0.25, 0))
		"bedroll":
			_shape(s, Vector3(0.9, 0.25, 2.0), Vector3(0, 0.12, 0))
		"crate":
			_shape(s, Vector3(0.95, 0.58, 0.6), Vector3(0, 0.29, 0))


# --- online ------------------------------------------------------------------

## Everything needed to rebuild a piece on another machine.
static func describe(s: Structure) -> Dictionary:
	var d := {"kind": s.kind, "key": s.slot_key, "cell": s.cell, "base": s.base_y,
		"xf": s.global_transform, "hp": s.hp, "open": s.open, "fuel": s.fuel,
		"looted": s.looted, "ruined": s.ruined, "silent": true}
	if not s.seg_ab.is_empty():
		d.seg = s.seg_ab
	return d


## Rebuild a piece from describe(); replaces whatever holds that slot.
func spawn_described(d: Dictionary) -> Structure:
	if slots.has(d.key):
		var old: Structure = slots[d.key]
		structures.erase(old)
		slots.erase(d.key)
		old.queue_free()
	var s: Structure
	if d.kind == "crate":
		s = spawn_crate(d.xf.origin, 0.0, [])
		# spawn_crate made its own key; re-key it to the host's.
		slots.erase(s.slot_key)
		s.slot_key = d.key
		slots[d.key] = s
		s.global_transform = d.xf
	else:
		s = spawn_piece(d.kind, d)
	s.hp = d.hp
	if d.open:
		s.set_open(true)
	if s.kind == "campfire":
		s.fuel = d.fuel
		s._update_fire()
	if d.looted:
		s.open_crate()
	return s


func clear_all() -> void:
	for s in structures:
		s.queue_free()
	structures.clear()
	slots.clear()
