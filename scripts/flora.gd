class_name Flora
extends RefCounted

## Static builders for the low-poly vegetation meshes used by the MultiMeshes.
## Each mesh keeps its parts on separate surfaces so bark/leaf materials differ,
## while MultiMesh instance colours tint the whole plant for variety.


static func _mat(c: Color, rough := 0.94, double_sided := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.0
	m.metallic_specular = 0.12
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _cone(bottom: float, height: float, segments := 7) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


static func _cyl(top: float, bottom: float, height: float, segments := 6) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


static func _sphere(radius: float, rings := 3, radial := 7) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.rings = rings
	s.radial_segments = radial
	return s


## Merge a list of [Mesh, Transform3D] pairs into one surface of `out`.
static func _add_surface(out: ArrayMesh, parts: Array, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		st.append_from(p[0], 0, p[1])
	st.index()
	st.commit(out)
	out.surface_set_material(out.get_surface_count() - 1, mat)


# --- trees --------------------------------------------------------------------

## Tall conifer: layered cones on a tapered trunk.
static func pine() -> ArrayMesh:
	var out := ArrayMesh.new()
	_add_surface(out, [
		[_cyl(0.13, 0.32, 6.2), Transform3D(Basis(), Vector3(0, 3.1, 0))],
	], _mat(Color(0.34, 0.24, 0.17)))

	var canopy := []
	for k in 5:
		var y := 2.4 + k * 1.32
		var r := 2.35 - k * 0.38
		canopy.append([_cone(r, 2.4, 8), Transform3D(Basis(), Vector3(0, y + 1.2, 0))])
	_add_surface(out, canopy, _mat(Color(0.11, 0.26, 0.15)))
	return out


## Broadleaf: thick trunk, two forking limbs, clustered blobs of leaves.
static func broadleaf() -> ArrayMesh:
	var out := ArrayMesh.new()
	var wood := [
		[_cyl(0.20, 0.42, 4.2), Transform3D(Basis(), Vector3(0, 2.1, 0))],
		[_cyl(0.10, 0.20, 2.2), Transform3D(Basis(Vector3.FORWARD, 0.55), Vector3(0.55, 4.6, 0))],
		[_cyl(0.10, 0.20, 2.2), Transform3D(Basis(Vector3.FORWARD, -0.5), Vector3(-0.5, 4.7, 0))],
		[_cyl(0.09, 0.18, 2.0), Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0.0, 4.6, 0.5))],
	]
	_add_surface(out, wood, _mat(Color(0.37, 0.27, 0.19)))

	var leaves := []
	var blobs := [
		[Vector3(0.0, 6.5, 0.0), 2.05],
		[Vector3(1.35, 5.7, 0.25), 1.45],
		[Vector3(-1.30, 5.85, -0.30), 1.40],
		[Vector3(0.20, 5.5, 1.35), 1.30],
		[Vector3(-0.15, 5.6, -1.30), 1.25],
		[Vector3(0.0, 7.6, 0.0), 1.25],
	]
	for b in blobs:
		var t := Transform3D(Basis().scaled(Vector3(1.0, 0.78, 1.0)), b[0])
		leaves.append([_sphere(b[1], 3, 7), t])
	_add_surface(out, leaves, _mat(Color(0.20, 0.36, 0.15)))
	return out


## Birch: slim pale trunk, narrow upright crown.
static func birch() -> ArrayMesh:
	var out := ArrayMesh.new()
	_add_surface(out, [
		[_cyl(0.12, 0.19, 7.0), Transform3D(Basis(), Vector3(0, 3.5, 0))],
	], _mat(Color(0.78, 0.76, 0.70)))

	var leaves := []
	var blobs := [
		[Vector3(0.0, 6.6, 0.0), 1.55],
		[Vector3(0.65, 5.7, 0.20), 1.10],
		[Vector3(-0.60, 5.9, -0.25), 1.05],
		[Vector3(0.0, 7.8, 0.0), 1.05],
	]
	for b in blobs:
		var t := Transform3D(Basis().scaled(Vector3(1.0, 1.25, 1.0)), b[0])
		leaves.append([_sphere(b[1], 3, 7), t])
	_add_surface(out, leaves, _mat(Color(0.33, 0.47, 0.19)))
	return out


## Weathered stump / deadfall, adds forest-floor clutter.
static func stump() -> ArrayMesh:
	var out := ArrayMesh.new()
	_add_surface(out, [
		[_cyl(0.30, 0.42, 1.1), Transform3D(Basis(), Vector3(0, 0.55, 0))],
		[_cyl(0.13, 0.17, 2.6), Transform3D(Basis(Vector3.FORWARD, 1.45), Vector3(1.15, 0.35, 0.2))],
	], _mat(Color(0.36, 0.29, 0.22)))
	return out


# --- ground cover -------------------------------------------------------------

static func bush() -> ArrayMesh:
	var out := ArrayMesh.new()
	var parts := []
	var blobs := [
		[Vector3(0.0, 0.42, 0.0), 0.60],
		[Vector3(0.40, 0.30, 0.15), 0.42],
		[Vector3(-0.35, 0.32, -0.20), 0.44],
		[Vector3(0.05, 0.30, 0.42), 0.38],
	]
	for b in blobs:
		parts.append([_sphere(b[1], 3, 6), Transform3D(Basis().scaled(Vector3(1.0, 0.85, 1.0)), b[0])])
	_add_surface(out, parts, _mat(Color(0.17, 0.31, 0.14)))
	return out


static func rock(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := ArrayMesh.new()
	var parts := []
	var lumps := rng.randi_range(2, 4)
	for i in lumps:
		var r := rng.randf_range(0.45, 0.95)
		var off := Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.15, 0.25), rng.randf_range(-0.4, 0.4))
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
			Vector3(rng.randf_range(0.8, 1.4), rng.randf_range(0.55, 0.95), rng.randf_range(0.8, 1.4)))
		parts.append([_sphere(r, 2, 6), Transform3D(basis, off)])
	_add_surface(out, parts, _mat(Color(0.40, 0.39, 0.37), 0.98))
	return out


## A tuft of tapered blades. Built by hand so we can put a colour gradient
## from dark root to bright tip on the vertices.
static func grass_tuft(blade_count := 5, height := 0.55, width := 0.055,
		root := Color(0.13, 0.22, 0.09), tip := Color(0.44, 0.58, 0.22)) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337 + blade_count * 31 + int(height * 100.0)

	for b in blade_count:
		var yaw := TAU * float(b) / float(blade_count) + rng.randf_range(-0.4, 0.4)
		var lean := rng.randf_range(0.12, 0.42)
		var hgt := height * rng.randf_range(0.7, 1.3)
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-dir.z, 0.0, dir.x) * width
		var base := dir * rng.randf_range(0.0, 0.09)
		var top := base + dir * lean * hgt + Vector3.UP * hgt
		var mid := base + dir * lean * hgt * 0.35 + Vector3.UP * hgt * 0.55

		# two triangles: base quad + pointed tip
		st.set_color(root)
		st.add_vertex(base - side)
		st.set_color(root)
		st.add_vertex(base + side)
		st.set_color(root.lerp(tip, 0.55))
		st.add_vertex(mid + side * 0.5)

		st.set_color(root)
		st.add_vertex(base - side)
		st.set_color(root.lerp(tip, 0.55))
		st.add_vertex(mid + side * 0.5)
		st.set_color(root.lerp(tip, 0.55))
		st.add_vertex(mid - side * 0.5)

		st.set_color(root.lerp(tip, 0.55))
		st.add_vertex(mid - side * 0.5)
		st.set_color(root.lerp(tip, 0.55))
		st.add_vertex(mid + side * 0.5)
		st.set_color(tip)
		st.add_vertex(top)

	st.generate_normals()
	st.index()
	var out: ArrayMesh = st.commit()
	out.surface_set_material(0, _mat(Color.WHITE, 0.95, true))
	return out
