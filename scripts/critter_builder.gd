class_name CritterBuilder
extends RefCounted

## Builds a low-poly quadruped out of primitives from a Species config.
## The returned dictionary exposes the pieces the AI needs to animate:
## body (pitch/roll), legs (hip pivots), neck, head, tail.
##
## Convention: the creature faces -Z, y = 0 is the ground under its feet.

static var _mesh_cache := {}
static var _mat_cache := {}


static func _mat(c: Color, rough := 0.92) -> StandardMaterial3D:
	var key := "%d_%.2f" % [c.to_rgba32(), rough]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.0
	m.metallic_specular = 0.14
	_mat_cache[key] = m
	return m


static func _capsule(radius: float, length: float) -> CapsuleMesh:
	var h := maxf(length, radius * 2.0 + 0.001)
	var key := "cap_%.3f_%.3f" % [radius, h]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = h
	m.radial_segments = 8
	m.rings = 3
	_mesh_cache[key] = m
	return m


static func _sphere(radius: float) -> SphereMesh:
	var key := "sph_%.3f" % radius
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 9
	m.rings = 5
	_mesh_cache[key] = m
	return m


static func _cyl(top: float, bottom: float, height: float, seg := 6) -> CylinderMesh:
	var key := "cyl_%.3f_%.3f_%.3f_%d" % [top, bottom, height, seg]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = seg
	m.rings = 1
	_mesh_cache[key] = m
	return m


static func _box(size: Vector3) -> BoxMesh:
	var key := "box_%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := BoxMesh.new()
	m.size = size
	_mesh_cache[key] = m
	return m


static func _mi(parent: Node3D, mesh: Mesh, mat: Material, xf: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	parent.add_child(mi)
	return mi


static func _rot_x(a: float) -> Basis:
	return Basis(Vector3.RIGHT, a)


# Public handles on the shared mesh/material caches, used by Fish too.

static func sphere_mesh(radius: float) -> SphereMesh:
	return _sphere(radius)


static func cone_mesh(bottom: float, height: float, seg := 6) -> CylinderMesh:
	return _cyl(0.0, bottom, height, seg)


static func material(c: Color, rough := 0.92) -> StandardMaterial3D:
	return _mat(c, rough)


static func attach(parent: Node3D, mesh: Mesh, mat: Material, xf: Transform3D) -> MeshInstance3D:
	return _mi(parent, mesh, mat, xf)


static func build(cfg: Dictionary, parent: Node3D) -> Dictionary:
	var coat := _mat(cfg.body_color)
	var belly := _mat(cfg.belly_color)
	var dark := _mat(cfg.dark_color)

	var body_len: float = cfg.body_len
	var body_rad: float = cfg.body_rad
	var leg_len: float = cfg.leg_len
	var leg_w: float = cfg.leg_w
	var body_y: float = leg_len + body_rad * 0.62

	var body := Node3D.new()
	body.name = "Body"
	parent.add_child(body)

	# torso -----------------------------------------------------------------
	_mi(body, _capsule(body_rad, body_len), coat,
		Transform3D(_rot_x(PI * 0.5), Vector3(0, body_y, 0)))
	# lighter underside
	_mi(body, _capsule(body_rad * 0.72, body_len * 0.88), belly,
		Transform3D(_rot_x(PI * 0.5), Vector3(0, body_y - body_rad * 0.42, 0)))

	if cfg.hump:
		_mi(body, _sphere(body_rad * 0.86), coat,
			Transform3D(Basis().scaled(Vector3(0.9, 0.62, 1.15)),
				Vector3(0, body_y + body_rad * 0.62, -body_len * 0.22)))

	# legs ------------------------------------------------------------------
	var legs: Array[Node3D] = []
	for i in 4:
		var sx := -1.0 if i % 2 == 0 else 1.0
		var sz := -1.0 if i < 2 else 1.0   # front pair sits at -Z
		var hip := Node3D.new()
		hip.name = "Hip%d" % i
		hip.position = Vector3(sx * body_rad * 0.70, leg_len, sz * body_len * 0.31)
		body.add_child(hip)
		_mi(hip, _cyl(leg_w * 0.55, leg_w * 0.95, leg_len, 5), coat,
			Transform3D(Basis(), Vector3(0, -leg_len * 0.5, 0)))
		_mi(hip, _box(Vector3(leg_w * 1.8, leg_w * 1.1, leg_w * 2.4)), dark,
			Transform3D(Basis(), Vector3(0, -leg_len + leg_w * 0.5, -leg_w * 0.2)))
		legs.append(hip)

	# neck & head -----------------------------------------------------------
	var neck := Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0, body_y + body_rad * 0.32, -body_len * 0.44)
	neck.rotation.x = cfg.neck_pitch
	body.add_child(neck)

	var neck_len: float = cfg.neck_len
	var neck_rad: float = body_rad * 0.44
	_mi(neck, _capsule(neck_rad, neck_len), coat,
		Transform3D(Basis(), Vector3(0, neck_len * 0.5, 0)))

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, neck_len, 0)
	head.rotation.x = -float(cfg.neck_pitch) * 0.75
	neck.add_child(head)

	var head_rad: float = cfg.head_rad
	_mi(head, _sphere(head_rad), coat,
		Transform3D(Basis().scaled(Vector3(0.95, 0.92, 1.18)), Vector3(0, head_rad * 0.4, 0)))
	# muzzle
	var snout: float = cfg.snout
	_mi(head, _cyl(head_rad * 0.42, head_rad * 0.70, snout, 9), coat,
		Transform3D(_rot_x(PI * 0.5), Vector3(0, head_rad * 0.22, -head_rad * 0.85 - snout * 0.45)))
	_mi(head, _sphere(head_rad * 0.24), dark,
		Transform3D(Basis(), Vector3(0, head_rad * 0.26, -head_rad * 0.85 - snout * 0.92)))
	# eyes
	for sx in [-1.0, 1.0]:
		_mi(head, _sphere(head_rad * 0.155), dark,
			Transform3D(Basis(), Vector3(sx * head_rad * 0.66, head_rad * 0.62, -head_rad * 0.42)))
	# ears
	var ear_len: float = cfg.ear_len
	var ear_rad: float = cfg.ear_rad
	for sx2 in [-1.0, 1.0]:
		var b := Basis(Vector3.FORWARD, sx2 * -0.30) * Basis(Vector3.RIGHT, -0.15)
		_mi(head, _cyl(ear_rad * 0.35, ear_rad, ear_len, 5), coat,
			Transform3D(b, Vector3(sx2 * head_rad * 0.62, head_rad * 1.05 + ear_len * 0.35, head_rad * 0.10)))

	if cfg.tusks:
		for sx3 in [-1.0, 1.0]:
			var tb := Basis(Vector3.RIGHT, -2.35) * Basis(Vector3.FORWARD, sx3 * 0.25)
			_mi(head, _cyl(0.0, 0.028, 0.19, 5), _mat(Color(0.88, 0.86, 0.78), 0.55),
				Transform3D(tb, Vector3(sx3 * head_rad * 0.46, head_rad * 0.02, -head_rad * 0.9 - snout * 0.6)))

	if cfg.antlers:
		_build_antlers(head, head_rad, _mat(Color(0.46, 0.38, 0.26), 0.75))

	# tail ------------------------------------------------------------------
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, body_y + body_rad * 0.28, body_len * 0.46)
	tail.rotation.x = cfg.tail_pitch
	body.add_child(tail)
	var tail_len: float = cfg.tail_len
	_mi(tail, _capsule(cfg.tail_rad, tail_len), coat,
		Transform3D(Basis(), Vector3(0, tail_len * 0.5, 0)))

	return {
		"body": body,
		"legs": legs,
		"neck": neck,
		"head": head,
		"tail": tail,
		"body_y": body_y,
	}


static func _build_antlers(head: Node3D, head_rad: float, mat: Material) -> void:
	for sx in [-1.0, 1.0]:
		var root := Node3D.new()
		root.position = Vector3(sx * head_rad * 0.42, head_rad * 1.05, head_rad * 0.05)
		root.rotation = Vector3(-0.25, 0.0, sx * 0.42)
		head.add_child(root)
		# main beam
		_mi(root, _cyl(0.018, 0.032, 0.46, 5), mat,
			Transform3D(Basis(), Vector3(0, 0.23, 0)))
		# tines
		var tines := [
			[Vector3(0, 0.20, 0), Vector3(-0.5, 0.0, sx * 0.35), 0.24],
			[Vector3(0, 0.38, 0), Vector3(-0.85, 0.0, sx * 0.15), 0.22],
			[Vector3(0, 0.44, 0), Vector3(0.35, 0.0, sx * 0.55), 0.20],
		]
		for t in tines:
			var b := Basis.from_euler(t[1])
			_mi(root, _cyl(0.0, 0.020, t[2], 5), mat,
				Transform3D(b, t[0] + b * Vector3(0, t[2] * 0.5, 0)))
