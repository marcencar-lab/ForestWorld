extends Node3D

## Builds the whole open world at runtime: terrain, lake, forest, wildlife,
## lighting and the observer camera. Everything is procedural - no imported
## assets - so the project runs straight from a fresh checkout.

const WORLD_SEED := 20260801

const TREE_TARGET := 1500
const BUSH_TARGET := 900
const ROCK_TARGET := 480
const STUMP_TARGET := 220
const GRASS_TARGET := 22000
const REED_TARGET := 2200

const GRASS_VIEW := 115.0
const BUSH_VIEW := 220.0

var terrain: ForestTerrain
var wildlife: WildlifeManager
var player: PlayerController
var hud: ForestHUD
var audio: AudioDirector

var sun: DirectionalLight3D
var fill: DirectionalLight3D
var world_env: WorldEnvironment
var sky_mat: ShaderMaterial
var spec_cam: Camera3D

var camera_mode := 0          # 0 player, 1 bear, 2 prey
var tod_running := false
var tod_hours := 15.2
var _spec_pos := Vector3.ZERO
var _stat_timer := 0.0
var _last_kills := 0

var _rng := RandomNumberGenerator.new()
var _tree_shapes := {}
var _tree_body: StaticBody3D


func _ready() -> void:
	_rng.seed = WORLD_SEED
	var t0 := Time.get_ticks_msec()

	terrain = ForestTerrain.new()
	terrain.name = "Terrain"
	terrain.configure(WORLD_SEED)
	add_child(terrain)
	terrain.generate()

	_build_environment()
	_build_water()
	_build_forest()
	_build_ground_cover()

	audio = AudioDirector.new()
	audio.name = "Audio"
	add_child(audio)
	audio.setup(terrain, self, WORLD_SEED)

	wildlife = WildlifeManager.new()
	wildlife.name = "Wildlife"
	add_child(wildlife)
	wildlife.setup(terrain, WORLD_SEED)
	wildlife.audio = audio
	wildlife.populate()

	_build_player()
	wildlife.player = player
	player.audio = audio
	player.terrain = terrain

	spec_cam = Camera3D.new()
	spec_cam.name = "SpectatorCamera"
	spec_cam.fov = 65.0
	spec_cam.far = 1200.0
	add_child(spec_cam)

	hud = ForestHUD.new()
	hud.name = "HUD"
	add_child(hud)

	_update_sun()
	print("Forest World generated in %d ms" % (Time.get_ticks_msec() - t0))


# --- lighting & atmosphere ----------------------------------------------------

func _build_environment() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")

	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 3.0
	env.tonemap_exposure = 1.0

	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6

	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.05

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.62, 0.71, 0.80)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.18
	env.fog_density = 0.0009
	env.fog_aerial_perspective = 0.12
	env.fog_sky_affect = 0.0
	env.fog_height = 0.0
	env.fog_height_density = 0.0

	# Just enough to catch shafts of sun between the trunks - any denser and
	# it bleaches the whole palette.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0022
	env.volumetric_fog_albedo = Color(0.86, 0.90, 0.92)
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_gi_inject = 0.25

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.20
	env.adjustment_brightness = 1.0

	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 260.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.16
	sun.directional_shadow_split_3 = 0.42
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.6
	sun.light_volumetric_fog_energy = 1.2
	add_child(sun)

	fill = DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.light_energy = 0.22
	fill.light_color = Color(0.62, 0.72, 0.92)
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-32.0, 140.0, 0.0)
	add_child(fill)


func _update_sun() -> void:
	var elev := sin((tod_hours - 6.0) / 12.0 * PI) * 62.0
	var azim := tod_hours / 24.0 * 360.0 - 90.0
	sun.rotation_degrees = Vector3(-elev, azim, 0.0)

	var day := clampf(elev / 12.0, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(elev) / 14.0, 0.0, 1.0)
	var night := clampf(-elev / 8.0, 0.0, 1.0)

	var noon_col := Color(1.0, 0.96, 0.88)
	var dusk_col := Color(1.0, 0.62, 0.34)
	sun.light_color = noon_col.lerp(dusk_col, dusk)
	sun.light_energy = lerpf(0.04, 0.95, day)

	fill.light_energy = lerpf(0.04, 0.20, day)

	if audio != null:
		audio.day_factor = day

	var env := world_env.environment
	env.ambient_light_energy = lerpf(0.08, 0.52, day)
	env.fog_light_color = Color(0.62, 0.71, 0.80).lerp(Color(0.90, 0.58, 0.36), dusk * 0.7) \
		.lerp(Color(0.05, 0.07, 0.12), night)
	env.fog_density = lerpf(0.0009, 0.0030, night)

	sky_mat.set_shader_parameter("top_color", Color(0.16, 0.34, 0.66).lerp(Color(0.02, 0.03, 0.09), night))
	sky_mat.set_shader_parameter("horizon_color",
		Color(0.70, 0.80, 0.87).lerp(Color(0.95, 0.55, 0.28), dusk).lerp(Color(0.05, 0.07, 0.14), night))
	sky_mat.set_shader_parameter("cloud_color",
		Color(1.0, 0.99, 0.97).lerp(Color(1.0, 0.72, 0.48), dusk).lerp(Color(0.10, 0.12, 0.18), night))


# --- lake ---------------------------------------------------------------------

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(ForestTerrain.SIZE, ForestTerrain.SIZE)
	plane.subdivide_width = 140
	plane.subdivide_depth = 140

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")

	var mi := MeshInstance3D.new()
	mi.name = "Lake"
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(0, ForestTerrain.WATER_LEVEL, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(
		Vector3(-ForestTerrain.HALF, -2.0, -ForestTerrain.HALF),
		Vector3(ForestTerrain.SIZE, 4.0, ForestTerrain.SIZE))
	add_child(mi)


# --- scattering ---------------------------------------------------------------

## Split placements into a chunk grid so frustum culling and visibility ranges
## have something to work with, then bake each chunk into a MultiMesh.
func _scatter_layer(layer_name: String, mesh: Mesh, placements: Array, chunks: int,
		view_range: float, shadows: bool) -> void:
	if placements.is_empty():
		return
	var parent := Node3D.new()
	parent.name = layer_name
	add_child(parent)

	var cs := ForestTerrain.SIZE / float(chunks)
	var buckets := {}
	for pl in placements:
		var o: Vector3 = pl[0].origin
		var cx := clampi(int((o.x + ForestTerrain.HALF) / cs), 0, chunks - 1)
		var cz := clampi(int((o.z + ForestTerrain.HALF) / cs), 0, chunks - 1)
		var key := cz * chunks + cx
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(pl)

	var mesh_aabb := mesh.get_aabb()
	for key in buckets:
		var arr: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = arr.size()

		var bounds := AABB(arr[0][0].origin, Vector3.ZERO)
		for i in arr.size():
			var xf: Transform3D = arr[i][0]
			mm.set_instance_transform(i, xf)
			mm.set_instance_color(i, arr[i][1])
			bounds = bounds.merge(AABB(xf.origin + mesh_aabb.position * xf.basis.get_scale().y,
				mesh_aabb.size * xf.basis.get_scale().y))

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_chunk_%d" % [layer_name, key]
		mmi.multimesh = mm
		mmi.custom_aabb = bounds.grow(2.0)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if view_range > 0.0:
			mmi.visibility_range_end = view_range
			mmi.visibility_range_end_margin = view_range * 0.22
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		parent.add_child(mmi)


func _tint(base: float, spread: float) -> Color:
	var v := base + _rng.randf_range(-spread, spread)
	return Color(v * _rng.randf_range(0.94, 1.06), v * _rng.randf_range(0.94, 1.06), v * _rng.randf_range(0.92, 1.04))


func _upright(pos: Vector3, yaw: float, s: Vector3, tilt := 0.0) -> Transform3D:
	var b := Basis(Vector3.UP, yaw)
	if tilt > 0.0:
		b = b * Basis(Vector3(cos(yaw * 1.7), 0.0, sin(yaw * 1.7)), _rng.randf_range(-tilt, tilt))
	return Transform3D(b.scaled(s), pos)


func _build_forest() -> void:
	var pines := []
	var broads := []
	var birches := []
	var stumps := []

	_tree_body = StaticBody3D.new()
	_tree_body.name = "TreeColliders"
	add_child(_tree_body)

	var placed := 0
	var attempts := 0
	while placed < TREE_TARGET and attempts < TREE_TARGET * 25:
		attempts += 1
		var x := _rng.randf_range(-ForestTerrain.HALF + 6.0, ForestTerrain.HALF - 6.0)
		var z := _rng.randf_range(-ForestTerrain.HALF + 6.0, ForestTerrain.HALF - 6.0)
		var h := terrain.sample_height(x, z)
		if h < ForestTerrain.WATER_LEVEL + 2.0 or h > 52.0:
			continue
		var nrm := terrain.sample_normal(x, z)
		if nrm.y < 0.84:
			continue
		var dens := terrain.forest_density(x, z)
		if _rng.randf() > dens * 1.35:
			continue

		var pos := Vector3(x, h - 0.25, z)
		var yaw := _rng.randf_range(0.0, TAU)
		var kind := 0
		if h > 32.0 or dens > 0.62:
			kind = 0                      # conifers take the higher, denser ground
		elif dens > 0.42:
			kind = 1
		else:
			kind = 2

		var s := _rng.randf_range(0.75, 1.35)
		var sv := Vector3(s * _rng.randf_range(0.9, 1.1), s * _rng.randf_range(0.85, 1.2), s * _rng.randf_range(0.9, 1.1))
		var xf := _upright(pos, yaw, sv, 0.06)
		var tint := _tint(1.0, 0.13)

		match kind:
			0: pines.append([xf, tint])
			1: broads.append([xf, tint])
			2: birches.append([xf, tint])

		_add_tree_collider(pos, 0.42 * sv.x, 5.5 * sv.y)
		placed += 1

	# scattered deadwood
	for i in STUMP_TARGET:
		var p := terrain.random_walkable_point(_rng, 12)
		if p == Vector3.ZERO:
			continue
		stumps.append([_upright(p - Vector3(0, 0.15, 0), _rng.randf_range(0.0, TAU),
			Vector3.ONE * _rng.randf_range(0.7, 1.4), 0.15), _tint(0.95, 0.15)])

	_scatter_layer("Pines", Flora.pine(), pines, 8, 0.0, true)
	_scatter_layer("Broadleaves", Flora.broadleaf(), broads, 8, 0.0, true)
	_scatter_layer("Birches", Flora.birch(), birches, 8, 0.0, true)
	_scatter_layer("Stumps", Flora.stump(), stumps, 8, 260.0, true)


func _add_tree_collider(pos: Vector3, radius: float, height: float) -> void:
	var rk := snappedf(radius, 0.15)
	var hk := snappedf(height, 1.0)
	var key := "%.2f_%.1f" % [rk, hk]
	if not _tree_shapes.has(key):
		var cs := CylinderShape3D.new()
		cs.radius = maxf(rk, 0.15)
		cs.height = maxf(hk, 1.0)
		_tree_shapes[key] = cs
	var col := CollisionShape3D.new()
	col.shape = _tree_shapes[key]
	col.position = pos + Vector3(0, maxf(hk, 1.0) * 0.5, 0)
	_tree_body.add_child(col)


func _build_ground_cover() -> void:
	var bushes := []
	var rocks_a := []
	var rocks_b := []
	var grass := []
	var reeds := []

	for i in BUSH_TARGET:
		var p := terrain.random_walkable_point(_rng, 10)
		if p == Vector3.ZERO:
			continue
		bushes.append([_upright(p - Vector3(0, 0.1, 0), _rng.randf_range(0.0, TAU),
			Vector3.ONE * _rng.randf_range(0.7, 1.8)), _tint(1.0, 0.18)])

	for i in ROCK_TARGET:
		var x := _rng.randf_range(-ForestTerrain.HALF + 4.0, ForestTerrain.HALF - 4.0)
		var z := _rng.randf_range(-ForestTerrain.HALF + 4.0, ForestTerrain.HALF - 4.0)
		var h := terrain.sample_height(x, z)
		if h < ForestTerrain.WATER_LEVEL - 3.0:
			continue
		var s := _rng.randf_range(0.5, 2.6)
		var xf := _upright(Vector3(x, h - s * 0.25, z), _rng.randf_range(0.0, TAU),
			Vector3(s * _rng.randf_range(0.8, 1.3), s * _rng.randf_range(0.6, 1.0), s * _rng.randf_range(0.8, 1.3)))
		if i % 2 == 0:
			rocks_a.append([xf, _tint(1.0, 0.14)])
		else:
			rocks_b.append([xf, _tint(1.0, 0.14)])

	var placed := 0
	var attempts := 0
	while placed < GRASS_TARGET and attempts < GRASS_TARGET * 6:
		attempts += 1
		var x := _rng.randf_range(-ForestTerrain.HALF + 3.0, ForestTerrain.HALF - 3.0)
		var z := _rng.randf_range(-ForestTerrain.HALF + 3.0, ForestTerrain.HALF - 3.0)
		var h := terrain.sample_height(x, z)
		if h < ForestTerrain.WATER_LEVEL + 0.6 or h > 46.0:
			continue
		if terrain.sample_normal(x, z).y < 0.80:
			continue
		grass.append([_upright(Vector3(x, h - 0.05, z), _rng.randf_range(0.0, TAU),
			Vector3.ONE * _rng.randf_range(0.6, 1.15)), _tint(1.0, 0.22)])
		placed += 1

	# reed belt in the shallows around the lake
	var reeded := 0
	attempts = 0
	while reeded < REED_TARGET and attempts < REED_TARGET * 30:
		attempts += 1
		var ang := _rng.randf_range(0.0, TAU)
		var rad := terrain.lake_radius * _rng.randf_range(0.62, 1.12)
		var x2 := terrain.lake_center.x + cos(ang) * rad
		var z2 := terrain.lake_center.y + sin(ang) * rad
		var h2 := terrain.sample_height(x2, z2)
		if h2 < ForestTerrain.WATER_LEVEL - 1.3 or h2 > ForestTerrain.WATER_LEVEL + 0.9:
			continue
		reeds.append([_upright(Vector3(x2, h2 - 0.1, z2), _rng.randf_range(0.0, TAU),
			Vector3.ONE * _rng.randf_range(0.8, 1.6)), _tint(1.0, 0.15)])
		reeded += 1

	_scatter_layer("Bushes", Flora.bush(), bushes, 10, BUSH_VIEW, true)
	_scatter_layer("RocksA", Flora.rock(11), rocks_a, 8, 320.0, true)
	_scatter_layer("RocksB", Flora.rock(29), rocks_b, 8, 320.0, true)
	_scatter_layer("Grass", Flora.grass_tuft(5, 0.34, 0.045), grass, 12, GRASS_VIEW, false)
	_scatter_layer("Reeds", Flora.grass_tuft(6, 1.45, 0.038,
		Color(0.20, 0.26, 0.11), Color(0.62, 0.66, 0.30)), reeds, 8, 170.0, false)


# --- player -------------------------------------------------------------------

func _build_player() -> void:
	player = PlayerController.new()
	player.name = "Player"
	add_child(player)
	player.global_position = _shore_spawn()
	_add_pollen(player.head)


func _shore_spawn() -> Vector3:
	for i in 200:
		var ang := _rng.randf_range(0.0, TAU)
		var rad := terrain.lake_radius + _rng.randf_range(12.0, 45.0)
		var x := terrain.lake_center.x + cos(ang) * rad
		var z := terrain.lake_center.y + sin(ang) * rad
		if not terrain.in_bounds(x, z):
			continue
		var h := terrain.sample_height(x, z)
		if h > ForestTerrain.WATER_LEVEL + 1.5 and h < 26.0 and terrain.sample_normal(x, z).y > 0.88:
			return Vector3(x, h + 1.2, z)
	var p := terrain.random_walkable_point(_rng, 80)
	return p + Vector3(0, 1.2, 0)


func _add_pollen(parent: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.name = "Pollen"
	p.amount = 220
	p.lifetime = 9.0
	p.preprocess = 6.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(22, 9, 22)
	p.direction = Vector3(1, 0.2, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.55
	p.gravity = Vector3(0.05, -0.06, 0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.color = Color(1.0, 0.97, 0.75, 0.75)

	var q := QuadMesh.new()
	q.size = Vector2(0.045, 0.045)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.98, 0.80, 0.6)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	parent.add_child(p)


# --- runtime ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_TAB:
			camera_mode = (camera_mode + 1) % 3
			_apply_camera_mode()
		KEY_R:
			if wildlife.bear != null:
				var b := wildlife.bear.global_position
				player.global_position = b + Vector3(6, 4, 6)
				hud.toast("Teleported to the bear")
		KEY_T:
			tod_running = not tod_running
			hud.toast("Day cycle %s" % ("on" if tod_running else "off"))
		KEY_V:
			var env := world_env.environment
			env.volumetric_fog_enabled = not env.volumetric_fog_enabled
			hud.toast("Volumetric fog %s" % ("on" if env.volumetric_fog_enabled else "off"))
		KEY_M:
			hud.toast("Audio %s" % ("muted" if audio.toggle_mute() else "on"))
		KEY_H:
			hud.toggle_help()


func _apply_camera_mode() -> void:
	if camera_mode == 0:
		player.camera.current = true
		hud.toast("Camera: player")
	else:
		spec_cam.current = true
		_spec_pos = spec_cam.global_position
		hud.toast("Camera: %s" % ("bear" if camera_mode == 1 else "prey"))


func _spec_subject() -> Node3D:
	if camera_mode == 1:
		return wildlife.bear
	if wildlife.bear != null and wildlife.bear.target != null and is_instance_valid(wildlife.bear.target):
		return wildlife.bear.target
	return wildlife.nearest_prey(wildlife.bear.global_position if wildlife.bear else Vector3.ZERO, 400.0)


func _process(delta: float) -> void:
	if tod_running:
		tod_hours = fmod(tod_hours + delta * 0.25, 24.0)
		_update_sun()

	if camera_mode != 0:
		var subject := _spec_subject()
		if subject != null and is_instance_valid(subject):
			var back := subject.global_transform.basis.z
			var want := subject.global_position + back * 6.5 + Vector3.UP * 3.2
			var ground := terrain.sample_height(want.x, want.z) + 1.6
			want.y = maxf(want.y, ground)
			_spec_pos = _spec_pos.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
			spec_cam.global_position = _spec_pos
			spec_cam.look_at(subject.global_position + Vector3.UP * 1.0, Vector3.UP)

	_stat_timer -= delta
	if _stat_timer <= 0.0:
		_stat_timer = 0.2
		_update_stats()

	if wildlife.kills != _last_kills:
		_last_kills = wildlife.kills
		hud.toast("The bear brought down a %s" % wildlife.last_kill_label.to_lower())


func _update_stats() -> void:
	var bear_state := "-"
	var bear_dist := 0.0
	if wildlife.bear != null and is_instance_valid(wildlife.bear):
		bear_state = wildlife.bear.state_name()
		bear_dist = player.global_position.distance_to(wildlife.bear.global_position)

	var mode_names := ["player", "bear", "prey"]
	var lines := "%d FPS\n" % Engine.get_frames_per_second()
	lines += "animals alive: %d\n" % wildlife.alive_count()
	lines += "fish in lake: %d\n" % wildlife.fish_count()
	lines += "kills: %d\n" % wildlife.kills
	lines += "bear: %s (%.0f m)\n" % [bear_state, bear_dist]
	lines += "camera: %s\n" % mode_names[camera_mode]
	lines += "time: %02d:%02d%s" % [int(tod_hours), int(fmod(tod_hours, 1.0) * 60.0),
		"" if tod_running else " (paused)"]
	hud.set_stats(lines)
