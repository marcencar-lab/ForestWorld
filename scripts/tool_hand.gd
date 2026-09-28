class_name ToolHand
extends Node3D

## First-person view of whatever the player is holding, plus the swing / draw
## animation. The fishing rod draws itself.

var _pivot: Node3D
var _items := {}
var _swing := -1.0
var _held := ""

const SWING_TIME := 0.38
const REST := Vector3(-0.15, 0.35, 0.0)
const BOW_REST := Vector3(0.0, 0.05, 0.12)
const SPEAR_REST := Vector3(-1.35, 0.12, 0.0)


func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.name = "HandPivot"
	_pivot.position = Vector3(0.40, -0.42, -0.62)
	_pivot.rotation = REST
	_pivot.scale = Vector3.ONE * 0.72
	add_child(_pivot)

	var wood := CritterBuilder.material(Color(0.45, 0.32, 0.19), 0.8)
	var stone := CritterBuilder.material(Color(0.42, 0.42, 0.40), 0.95)
	var steel := CritterBuilder.material(Color(0.62, 0.64, 0.66), 0.35)
	var lashing := CritterBuilder.material(Color(0.55, 0.47, 0.30), 0.9)
	var dark := CritterBuilder.material(Color(0.12, 0.10, 0.09), 0.7)

	var rock := _item("rock")
	var rmi := _part(rock, Flora.rock(71), null, Vector3.ZERO)
	rmi.scale = Vector3(0.11, 0.09, 0.11)

	var axe := _item("axe")
	_part(axe, _cyl(0.018, 0.022, 0.62), wood, Vector3(0, 0.18, 0))
	_part(axe, _boxm(Vector3(0.05, 0.11, 0.2)), stone, Vector3(0, 0.44, -0.07))
	_part(axe, _boxm(Vector3(0.06, 0.05, 0.06)), lashing, Vector3(0, 0.44, 0))

	var hatchet := _item("hatchet")
	_part(hatchet, _cyl(0.016, 0.02, 0.5), wood, Vector3(0, 0.14, 0))
	_part(hatchet, _boxm(Vector3(0.025, 0.1, 0.17)), steel, Vector3(0, 0.36, -0.07))

	var knife := _item("knife")
	_part(knife, _boxm(Vector3(0.03, 0.12, 0.035)), dark, Vector3(0, 0.02, 0))
	_part(knife, _boxm(Vector3(0.008, 0.2, 0.04)), steel, Vector3(0, 0.18, 0))

	var spear := _item("spear")
	_part(spear, _cyl(0.016, 0.02, 1.6), wood, Vector3(0, 0.45, 0))
	var tip := _part(spear, _cyl(0.0, 0.03, 0.14), stone, Vector3(0, 1.32, 0))
	tip.scale = Vector3(1.0, 1.0, 0.5)

	# Bow: two limbs bending away from the archer, a grip, and the string.
	var bow := _item("bow")
	var grip := Vector3(0, 0, -0.13)
	for sy in [-1.0, 1.0]:
		var mid := Vector3(0, sy * 0.3, -0.1)
		var end := Vector3(0, sy * 0.56, 0.0)
		_stick(bow, grip, mid, 0.016, wood)
		_stick(bow, mid, end, 0.012, wood)
	_part(bow, _cyl(0.022, 0.022, 0.14), dark, grip)
	_stick(bow, Vector3(0, 0.56, 0.0), Vector3(0, -0.56, 0.0), 0.003, lashing)

	show_item("")


func _item(key: String) -> Node3D:
	var n := Node3D.new()
	n.name = key
	_pivot.add_child(n)
	_items[key] = n
	return n


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if mat != null:
		mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A cylinder from `a` to `b`.
func _stick(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var mi := _part(parent, _cyl(r, r, a.distance_to(b)), mat, (a + b) * 0.5)
	var up := (b - a).normalized()
	var side := up.cross(Vector3.RIGHT)
	if side.length() < 0.01:
		side = up.cross(Vector3.FORWARD)
	side = side.normalized()
	mi.basis = Basis(up.cross(side), up, side)


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 6
	c.rings = 1
	return c


static func _boxm(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func show_item(item: String) -> void:
	_held = item
	for k in _items:
		_items[k].visible = k == item
	_pivot.rotation = _rest()


func _rest() -> Vector3:
	match _held:
		"bow": return BOW_REST
		"spear": return SPEAR_REST
	return REST


func swing() -> void:
	_swing = 0.0


func _process(delta: float) -> void:
	var rest := _rest()
	if _swing < 0.0:
		_pivot.rotation = _pivot.rotation.lerp(rest, clampf(delta * 10.0, 0.0, 1.0))
		return
	_swing += delta
	var t := clampf(_swing / SWING_TIME, 0.0, 1.0)
	if _held == "bow":
		# Kick back on release.
		_pivot.rotation = rest + Vector3(0.25 * (1.0 - t), 0, 0)
	elif _held == "spear":
		# Thrust forward.
		var k := sin(t * PI)
		_pivot.rotation = rest
		_pivot.position = Vector3(0.40, -0.42, -0.62 - 0.35 * k)
	else:
		# Wind up, then chop forward and down.
		var arc: float
		if t < 0.35:
			arc = -0.9 * (t / 0.35)
		else:
			arc = lerpf(-0.9, 1.2, smoothstep(0.35, 0.7, t)) * (1.0 - smoothstep(0.75, 1.0, t))
		_pivot.rotation = rest + Vector3(-arc, arc * 0.25, arc * 0.2)
	if t >= 1.0:
		_swing = -1.0
