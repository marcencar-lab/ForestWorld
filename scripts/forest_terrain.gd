class_name ForestTerrain
extends StaticBody3D

## Procedural heightmap terrain with a carved lake basin and a mountain rim.
## Height is defined analytically by sample_height() so gameplay code (animals,
## props, spawn points) can query the ground without any raycasts.

const SIZE := 440.0
const HALF := SIZE * 0.5
const VIS_GRID := 220   # visual mesh resolution (quads per side)
const COL_GRID := 110   # collision mesh resolution
const WATER_LEVEL := 3.0
const PLAY_BOUND := HALF - 28.0

var lake_center := Vector2(72.0, -54.0)
var lake_radius := 74.0

var _hills := FastNoiseLite.new()
var _mid := FastNoiseLite.new()
var _fine := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _forest := FastNoiseLite.new()

var mesh_instance: MeshInstance3D


func configure(world_seed: int) -> void:
	_hills.seed = world_seed
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 0.0032
	_hills.fractal_octaves = 4
	_hills.fractal_lacunarity = 2.1
	_hills.fractal_gain = 0.48

	_mid.seed = world_seed + 17
	_mid.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_mid.frequency = 0.013
	_mid.fractal_octaves = 3

	_fine.seed = world_seed + 91
	_fine.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_fine.frequency = 0.075
	_fine.fractal_octaves = 2

	_warp.seed = world_seed + 233
	_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_warp.frequency = 0.006
	_warp.fractal_octaves = 2

	_forest.seed = world_seed + 404
	_forest.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_forest.frequency = 0.009
	_forest.fractal_octaves = 3


# --- sampling -----------------------------------------------------------------

func sample_height(x: float, z: float) -> float:
	# Domain warp keeps the hills from looking like uniform blobs.
	var wx := x + _warp.get_noise_2d(x, z) * 26.0
	var wz := z + _warp.get_noise_2d(x + 1000.0, z - 1000.0) * 26.0

	var b := _hills.get_noise_2d(wx, wz) * 0.5 + 0.5
	var h := smoothstep(0.0, 1.0, b) * 42.0 + 8.0
	h += _mid.get_noise_2d(x, z) * 5.5
	h += _fine.get_noise_2d(x, z) * 1.4

	# Lake basin: blend the surrounding terrain down into a bowl.
	var wobble := _mid.get_noise_2d(x * 0.9 + 500.0, z * 0.9 - 500.0) * 11.0
	var d := Vector2(x, z).distance_to(lake_center) + wobble
	var tu := d / lake_radius
	h = lerpf(-9.5, h, smoothstep(0.0, 1.0, clampf(tu, 0.0, 1.0)))

	# Outside the basin, hold the ground above the waterline so the lake stays
	# the only body of water instead of the noise flooding every hollow.
	h = lerpf(h, maxf(h, WATER_LEVEL + 1.2), smoothstep(0.95, 1.40, tu))

	# Mountain rim so the playable area feels enclosed.
	var edge := maxf(absf(x), absf(z)) / HALF
	h += smoothstep(0.68, 1.02, edge) * 46.0
	return h


func sample_normal(x: float, z: float) -> Vector3:
	var e := 1.25
	var hl := sample_height(x - e, z)
	var hr := sample_height(x + e, z)
	var hd := sample_height(x, z - e)
	var hu := sample_height(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()


func forest_density(x: float, z: float) -> float:
	return _forest.get_noise_2d(x, z) * 0.5 + 0.5


func is_land(x: float, z: float, margin := 1.0) -> bool:
	return sample_height(x, z) > WATER_LEVEL + margin


func in_bounds(x: float, z: float) -> bool:
	return absf(x) < PLAY_BOUND and absf(z) < PLAY_BOUND


## How deep the water is at this column (negative on dry land).
func water_depth(x: float, z: float) -> float:
	return WATER_LEVEL - sample_height(x, z)


## A random submerged point inside the lake, at a sensible swimming depth.
func random_lake_point(rng: RandomNumberGenerator, min_depth := 1.2, tries := 40) -> Vector3:
	for i in tries:
		var ang := rng.randf_range(0.0, TAU)
		# sqrt keeps the distribution even across the disc instead of clumping.
		var rad := lake_radius * sqrt(rng.randf()) * 0.92
		var x := lake_center.x + cos(ang) * rad
		var z := lake_center.y + sin(ang) * rad
		var d := water_depth(x, z)
		if d < min_depth:
			continue
		var bed := WATER_LEVEL - d
		return Vector3(x, rng.randf_range(bed + 0.4, WATER_LEVEL - 0.45), z)
	return Vector3.ZERO


## Rejection-sample a walkable point: on land, inside bounds, not too steep,
## not on the mountain rim. Returns Vector3.ZERO when it gives up.
func random_walkable_point(rng: RandomNumberGenerator, tries := 40) -> Vector3:
	for i in tries:
		var x := rng.randf_range(-PLAY_BOUND, PLAY_BOUND)
		var z := rng.randf_range(-PLAY_BOUND, PLAY_BOUND)
		var h := sample_height(x, z)
		if h < WATER_LEVEL + 1.2 or h > 46.0:
			continue
		if sample_normal(x, z).y < 0.80:
			continue
		return Vector3(x, h, z)
	return Vector3.ZERO


# --- mesh generation ----------------------------------------------------------

func generate() -> void:
	_build_visual()
	_build_collision()


func _sample_color(h: float, nrm: Vector3, x: float, z: float) -> Color:
	var slope := 1.0 - nrm.y
	var v := _fine.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5
	var patch := _mid.get_noise_2d(x * 0.55 + 900.0, z * 0.55 - 900.0) * 0.5 + 0.5

	var c := Color(0.115, 0.225, 0.088).lerp(Color(0.315, 0.425, 0.165), v)
	# Broad patches of dry meadow and deep shade so the ground isn't one flat tone.
	c = c.lerp(Color(0.40, 0.37, 0.17), smoothstep(0.56, 0.95, patch) * 0.60)
	c = c.lerp(Color(0.075, 0.150, 0.070), (1.0 - smoothstep(0.06, 0.44, patch)) * 0.50)
	# Drier, yellower grass as you climb.
	c = c.lerp(Color(0.46, 0.44, 0.26), clampf((h - 28.0) / 24.0, 0.0, 1.0) * 0.65)
	# Exposed rock on steep faces.
	var rock := Color(0.34, 0.33, 0.31).lerp(Color(0.52, 0.50, 0.46), v)
	c = c.lerp(rock, smoothstep(0.28, 0.58, slope))
	# Sandy shoreline.
	c = c.lerp(Color(0.74, 0.66, 0.48), 1.0 - smoothstep(WATER_LEVEL - 0.5, WATER_LEVEL + 2.2, h))
	# Dark silt on the lake bed.
	c = c.lerp(Color(0.24, 0.24, 0.19), 1.0 - smoothstep(WATER_LEVEL - 7.0, WATER_LEVEL - 0.5, h))
	# Bare stone on the high rim.
	c = c.lerp(Color(0.60, 0.60, 0.61), smoothstep(50.0, 72.0, h))
	return c


func _height_grid(n: int) -> PackedFloat32Array:
	var step := SIZE / float(n)
	var out := PackedFloat32Array()
	out.resize((n + 1) * (n + 1))
	for j in n + 1:
		var z := -HALF + j * step
		var row := j * (n + 1)
		for i in n + 1:
			out[row + i] = sample_height(-HALF + i * step, z)
	return out


func _grid_indices(n: int) -> PackedInt32Array:
	var idx := PackedInt32Array()
	idx.resize(n * n * 6)
	var k := 0
	for j in range(1, n + 1):
		var prevrow := (j - 1) * (n + 1)
		var thisrow := j * (n + 1)
		for i in range(1, n + 1):
			# Winding matches Godot's own PlaneMesh so back-face culling works.
			idx[k] = prevrow + i - 1
			idx[k + 1] = prevrow + i
			idx[k + 2] = thisrow + i - 1
			idx[k + 3] = prevrow + i
			idx[k + 4] = thisrow + i
			idx[k + 5] = thisrow + i - 1
			k += 6
	return idx


func _build_visual() -> void:
	var n := VIS_GRID
	var step := SIZE / float(n)
	var heights := _height_grid(n)
	var vc := (n + 1) * (n + 1)

	var verts := PackedVector3Array(); verts.resize(vc)
	var norms := PackedVector3Array(); norms.resize(vc)
	var cols := PackedColorArray(); cols.resize(vc)
	var uvs := PackedVector2Array(); uvs.resize(vc)

	for j in n + 1:
		var z := -HALF + j * step
		var row := j * (n + 1)
		var rowd := maxi(j - 1, 0) * (n + 1)
		var rowu := mini(j + 1, n) * (n + 1)
		for i in n + 1:
			var x := -HALF + i * step
			var h := heights[row + i]
			var nrm := Vector3(
				heights[row + maxi(i - 1, 0)] - heights[row + mini(i + 1, n)],
				2.0 * step,
				heights[rowd + i] - heights[rowu + i]
			).normalized()
			var vi := row + i
			verts[vi] = Vector3(x, h, z)
			norms[vi] = nrm
			cols[vi] = _sample_color(h, nrm, x, z)
			uvs[vi] = Vector2(x, z) * 0.125

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = _grid_indices(n)

	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	# The palette above is authored in sRGB; without this Godot would treat the
	# values as linear and the ground washes out to pale mint.
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.96
	mat.metallic = 0.0
	mat.metallic_specular = 0.15
	am.surface_set_material(0, mat)

	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = am
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)


func _build_collision() -> void:
	var n := COL_GRID
	var step := SIZE / float(n)
	var heights := _height_grid(n)
	var vc := (n + 1) * (n + 1)

	var verts := PackedVector3Array(); verts.resize(vc)
	for j in n + 1:
		var z := -HALF + j * step
		var row := j * (n + 1)
		for i in n + 1:
			verts[row + i] = Vector3(-HALF + i * step, heights[row + i], z)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = _grid_indices(n)

	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var col := CollisionShape3D.new()
	col.name = "TerrainCollision"
	col.shape = am.create_trimesh_shape()
	add_child(col)
