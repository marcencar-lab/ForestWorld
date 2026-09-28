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

## Game hours per real second. Survival days last 20 minutes; the sandbox
## cycle is a quick 96-second time-lapse.
const TOD_SPEED_SURVIVAL := 0.02
const TOD_SPEED_SANDBOX := 0.25
const SURVIVAL_START_HOUR := 7.5
const SAFE_SPAWN_FROM_BEAR := 120.0
const SAVE_PATH := "user://forest_world.cfg"

var terrain: ForestTerrain
var wildlife: WildlifeManager
var player: PlayerController
var hud: ForestHUD
var audio: AudioDirector
var trees: TreeRegistry
var rocks: LooseRocks
var build: BuildSystem
var weather: Weather
var ruins: Ruins
var net: NetSync

var sun: DirectionalLight3D
var fill: DirectionalLight3D
var world_env: WorldEnvironment
var sky_mat: ShaderMaterial
var spec_cam: Camera3D

var camera_mode := 0          # 0 player, 1 bear, 2 prey
var survival := true
var tod_running := true
var tod_hours := SURVIVAL_START_HOUR
var day := 1
var survived := 0.0
var game_over := false
var best_time := 0.0
var best_fish := 0
var night_factor := 0.0
var craft_open := false
var _use_cd := 0.0
var _player_hit_bear := false
var _bears_seen := 0
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
	# Online clients mirror the host's wildlife instead of running their own.
	wildlife.puppet_mode = not Session.authority()
	if Session.authority():
		wildlife.populate()

	net = NetSync.new()
	net.name = "Net"
	net.world = self
	add_child(net)

	_build_player()
	wildlife.player = player
	player.audio = audio
	player.terrain = terrain
	player.setup_rod(wildlife)
	trees.audio = audio

	rocks = LooseRocks.new()
	rocks.name = "LooseRocks"
	add_child(rocks)
	rocks.setup(terrain, WORLD_SEED, player.global_position)

	build = BuildSystem.new()
	build.name = "Buildings"
	add_child(build)
	build.setup(terrain, audio)
	build.destroyed.connect(_on_structure_destroyed)
	wildlife.build = build

	weather = Weather.new()
	weather.name = "Weather"
	add_child(weather)
	weather.setup(WORLD_SEED)
	weather.follow = player

	ruins = Ruins.new()
	ruins.name = "Ruins"
	add_child(ruins)
	ruins.generate(terrain, build, trees, WORLD_SEED, player.global_position)

	spec_cam = Camera3D.new()
	spec_cam.name = "SpectatorCamera"
	spec_cam.fov = 65.0
	spec_cam.far = 1200.0
	add_child(spec_cam)

	hud = ForestHUD.new()
	hud.name = "HUD"
	add_child(hud)

	player.hurt.connect(_on_player_hurt)
	player.died.connect(_on_player_died)
	player.ate.connect(_on_player_ate)
	player.rod.caught.connect(_on_fish_caught)
	player.rod.message.connect(hud.toast)
	player.rod.catch_handler = _catch
	if wildlife.bear != null:
		_hook_bear(wildlife.bear)
	wildlife.bear_spawned.connect(_hook_bear)
	wildlife.player_killed.connect(_on_player_killed_animal)
	player.status.connect(hud.toast)
	weather.rain_started.connect(func() -> void: hud.toast("It's starting to rain. Find shelter."))
	weather.rain_stopped.connect(func() -> void: hud.toast("The rain is easing off."))

	# Online: the host echoes world changes to everyone; clients take orders.
	trees.felled.connect(func(id: int, from: Vector3) -> void: net.broadcast("tree_felled", [id, from]))
	rocks.respawned.connect(func(i: int, p: Vector3) -> void: net.broadcast("rock_placed", [i, p]))
	build.placed.connect(func(st: Structure) -> void: net.broadcast("piece", [BuildSystem.describe(st)]))
	build.hp_changed.connect(func(st: Structure) -> void: net.broadcast("piece_hp", [st.slot_key, st.hp]))
	build.destroyed.connect(func(st: Structure) -> void: net.broadcast("piece_removed", [st.slot_key]))
	wildlife.fx.connect(net.broadcast_fx)
	if net.is_client():
		weather.auto = false
		rocks.authority = false
	net.start()

	_load_best()
	hud.set_mode(true)
	if net.is_client():
		hud.toast("Joining %s..." % Session.address)
	else:
		hud.toast("Survive. Fish the lake to eat (E), and stay away from the bear.")

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
	night_factor = night
	# Overcast: rain dims the sun and greys out the sky.
	var rain := weather.intensity if weather != null else 0.0
	var grey := Color(0.42, 0.45, 0.48)

	var noon_col := Color(1.0, 0.96, 0.88)
	var dusk_col := Color(1.0, 0.62, 0.34)
	sun.light_color = noon_col.lerp(dusk_col, dusk)
	sun.light_energy = lerpf(0.04, 0.95, day) * (1.0 - 0.7 * rain)

	fill.light_energy = lerpf(0.04, 0.20, day)

	if audio != null:
		audio.day_factor = day

	var env := world_env.environment
	env.ambient_light_energy = lerpf(0.08, 0.52, day) * (1.0 - 0.3 * rain)
	env.fog_light_color = Color(0.62, 0.71, 0.80).lerp(Color(0.90, 0.58, 0.36), dusk * 0.7) \
		.lerp(grey, rain * 0.8).lerp(Color(0.05, 0.07, 0.12), night)
	env.fog_density = lerpf(0.0009, 0.0030, night) + 0.0035 * rain

	sky_mat.set_shader_parameter("top_color", Color(0.16, 0.34, 0.66).lerp(grey * 0.8, rain) \
		.lerp(Color(0.02, 0.03, 0.09), night))
	sky_mat.set_shader_parameter("horizon_color",
		Color(0.70, 0.80, 0.87).lerp(Color(0.95, 0.55, 0.28), dusk).lerp(grey, rain) \
		.lerp(Color(0.05, 0.07, 0.14), night))
	sky_mat.set_shader_parameter("cloud_color",
		Color(1.0, 0.99, 0.97).lerp(Color(1.0, 0.72, 0.48), dusk).lerp(grey * 0.9, rain) \
		.lerp(Color(0.10, 0.12, 0.18), night))


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
			# Trees carry their registry id so they can be felled later.
			if arr[i].size() > 2 and trees != null:
				trees.bind_instance(arr[i][2], mm, i)
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

	trees = TreeRegistry.new()
	trees.name = "Trees"
	add_child(trees)

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

		var col := _add_tree_collider(pos, 0.42 * sv.x, 5.5 * sv.y)
		var id := trees.add(kind, xf, 0.42 * sv.x, col)
		match kind:
			0: pines.append([xf, tint, id])
			1: broads.append([xf, tint, id])
			2: birches.append([xf, tint, id])
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


func _add_tree_collider(pos: Vector3, radius: float, height: float) -> CollisionShape3D:
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
	return col


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
			# Give the player a head start on the bear.
			if i < 150 and wildlife.bear != null \
					and Vector2(x, z).distance_to(Vector2(wildlife.bear.position.x, wildlife.bear.position.z)) < SAFE_SPAWN_FROM_BEAR:
				continue
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

## Things that can be crafted from the Tab menu. `tool` recipes give a tool
## with that many uses; the rest add `gives` of the item to the inventory.
const RECIPES := [
	{"id": "axe", "label": "Stone axe", "cost": {"rock": 1, "branch": 3}, "tool": 60},
	{"id": "plank", "label": "4 planks", "cost": {"log": 1}, "gives": 4, "needs": "axe|hatchet"},
	{"id": "spear", "label": "Wooden spear", "cost": {"branch": 3, "rock": 1}, "tool": 40},
	{"id": "arrow", "label": "4 arrows", "cost": {"branch": 1, "rock": 1}, "gives": 4},
]

const ROCK_DAMAGE := 6.0
const SLEEP_WAKE_HOUR := 6.5
## Raw meat from animals you kill yourself.
const MEAT := {"rabbit": 1, "fox": 1, "deer": 3, "boar": 4}
const BEAR_MEAT := 6

const USE_REACH := 2.8
const ROCK_COOLDOWN := 0.45
const AXE_COOLDOWN := 0.6
const AXE_DAMAGE := 25.0
const REPAIR_WOOD := 150.0
const REPAIR_BRANCH := 40.0
const FUEL_BRANCH := 120.0
const FUEL_LOG := 300.0


func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			if net.is_online():
				_respawn()
			else:
				get_tree().reload_current_scene()
		return

	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and captured and player.alive:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if build.active:
					_place_piece()
				else:
					_use_tool()
			MOUSE_BUTTON_RIGHT:
				if build.active:
					_set_build(false)
			MOUSE_BUTTON_WHEEL_UP:
				if build.active:
					build.cycle(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if build.active:
					build.cycle(1)
		return

	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	# Number keys: craft, pick a build piece, or choose the held item.
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var n: int = event.keycode - KEY_1
		if craft_open:
			_craft(n)
		elif build.active:
			build.select(n)
		else:
			var bar := player.hotbar()
			if n < bar.size():
				player.equip(bar[n])
		return

	match event.keycode:
		KEY_P:
			if net.is_online():
				hud.toast("Sandbox mode isn't available in online games")
			elif survival:
				_enter_sandbox()
			else:
				# Back to survival means a fresh, fair start.
				get_tree().reload_current_scene()
		KEY_TAB:
			if survival:
				craft_open = not craft_open
				if craft_open:
					_set_build(false)
			else:
				camera_mode = (camera_mode + 1) % 3
				_apply_camera_mode()
		KEY_B:
			_set_build(not build.active)
		KEY_E:
			if player.alive and captured:
				_interact()
		KEY_R:
			if not survival and is_instance_valid(wildlife.bear):
				var b := wildlife.bear.global_position
				player.global_position = b + Vector3(6, 4, 6)
				hud.toast("Teleported to the bear")
			elif player.alive:
				_repair()
		KEY_G:
			if not survival:
				weather.toggle()
		KEY_T:
			tod_running = not tod_running
			hud.toast("Day cycle %s" % ("on" if tod_running else "off"))
		KEY_V:
			if not survival:
				var env := world_env.environment
				env.volumetric_fog_enabled = not env.volumetric_fog_enabled
				hud.toast("Volumetric fog %s" % ("on" if env.volumetric_fog_enabled else "off"))
		KEY_M:
			hud.toast("Audio %s" % ("muted" if audio.toggle_mute() else "on"))
		KEY_H:
			hud.toggle_help()


func _enter_sandbox() -> void:
	survival = false
	craft_open = false
	player.set_god_mode(true)
	build.free_build = true
	hud.set_mode(false)
	hud.toast("Sandbox mode: invulnerable, F to fly, free building. P restarts survival.")


func _set_build(on: bool) -> void:
	build.set_active(on)
	if on:
		craft_open = false


func _view() -> Array:
	var cam := player.camera
	return [cam.global_position, -cam.global_transform.basis.z]


# --- tools, crafting & interaction --------------------------------------------

func _wear() -> void:
	var name := Items.label(player.held)
	if player.wear_tool():
		hud.toast("Your %s broke" % name)


## The creature in front of the crosshair within `reach`, or null.
func _melee_target(eye: Vector3, dir: Vector3, reach: float) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	var cands := wildlife.hostiles()
	for a in wildlife.animals:
		if is_instance_valid(a) and a.is_alive():
			cands.append(a)
	for c in cands:
		var big: bool = c is Bear
		var center: Vector3 = c.global_position + Vector3.UP * (0.9 if big else 0.4)
		var to := center - eye
		var d := to.length()
		var r := 1.1 if big else 0.5
		if d > reach + r:
			continue
		# Within a cone that widens for big targets up close.
		var cone := clampf(r / maxf(d, 0.1), 0.25, 0.9)
		if to.normalized().dot(dir) < cos(cone):
			continue
		if d < best_d:
			best_d = d
			best = c
	return best


func _craft(i: int) -> void:
	if i < 0 or i >= RECIPES.size():
		return
	var r: Dictionary = RECIPES[i]
	if r.has("needs") and not _has_any_tool(r.needs):
		hud.toast("You need a %s for that" % r.needs.replace("|", " or "))
		return
	for k in r.cost:
		if int(player.inv.get(k, 0)) < int(r.cost[k]):
			hud.toast("Need %s" % _cost_text(r.cost))
			return
	for k in r.cost:
		player.inv[k] -= int(r.cost[k])
	if r.has("tool"):
		player.tools[r.id] = int(r.tool)
		player.equip(r.id)
	else:
		player.inv[r.id] = int(player.inv.get(r.id, 0)) + int(r.gives)
	if player.held == "rock" and int(player.inv.rock) <= 0:
		player.equip("rod")
	audio.build_at(player.global_position)
	hud.toast("Crafted: %s" % r.label)


## `needs` may list alternatives: "axe|hatchet".
func _has_any_tool(needs: String) -> bool:
	for t in needs.split("|"):
		if player.tools.has(t):
			return true
	return false


static func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append(BuildSystem.plural(cost[k], k))
	return ", ".join(parts)


## The building piece under the crosshair, via a physics ray on the structure layer.
func _structure_target(reach := 3.4) -> Structure:
	var v := _view()
	var q := PhysicsRayQueryParameters3D.create(v[0], v[0] + v[1] * reach, 1 << (BuildSystem.STRUCT_LAYER - 1))
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	return hit.collider as Structure


## True when the crosshair is on the lake surface close by, or you're standing in it.
func _at_water() -> bool:
	var pp := player.global_position
	if terrain.water_depth(pp.x, pp.z) > 0.25:
		return true
	var v := _view()
	var t := 0.3
	while t < 4.5:
		var p: Vector3 = v[0] + v[1] * t
		if p.y <= terrain.sample_height(p.x, p.z):
			return false
		if p.y <= ForestTerrain.WATER_LEVEL:
			return true
		t += 0.2
	return false


func _raw_food() -> int:
	var n := 0
	for k in Items.COOKS_TO:
		n += int(player.inv[k])
	return n


func _use_tool() -> void:
	if _use_cd > 0.0:
		return
	var v := _view()
	var held := player.held
	if held == "rod":
		return
	if held == "rock":
		_use_cd = ROCK_COOLDOWN
		player.hand.swing()
		var victim := _melee_target(v[0], v[1], 2.2)
		if victim != null:
			_hit(victim, ROCK_DAMAGE)
			return
		var id := trees.find_target(v[0], v[1], USE_REACH)
		if id < 0:
			return
		if net.is_client():
			audio.chop_at(trees.position_of(id) + Vector3.UP * 1.5, true)
		_act("tree_rock", [id])
		return

	var stats: Dictionary = Items.TOOLS[held]
	_use_cd = float(stats.cooldown)
	player.hand.swing()

	if held == "bow":
		if int(player.inv.arrow) <= 0:
			hud.toast("No arrows. Craft some from branches and rocks")
			return
		player.inv.arrow -= 1
		var arrow := Arrow.new()
		arrow.terrain = terrain
		arrow.manager = wildlife
		arrow.trees = trees
		arrow.damage = float(stats.damage)
		arrow.on_hit = _arrow_hit
		add_child(arrow)
		arrow.fire(v[0] + v[1] * 0.6 + Vector3.DOWN * 0.05, v[1])
		audio.play_at("swipe", v[0], -8.0, 1.6, 30.0)
		_wear()
		return

	var victim2 := _melee_target(v[0], v[1], float(stats.reach))
	if victim2 != null:
		_hit(victim2, float(stats.damage))
		_wear()
		return
	if float(stats.wood) > 0.0:
		var tid := trees.find_target(v[0], v[1], USE_REACH)
		if tid >= 0:
			if net.is_client():
				audio.chop_at(trees.position_of(tid) + Vector3.UP * 1.2)
			_act("chop", [tid, float(stats.wood)])
			_wear()


## Local feedback for a blow, then let the authority apply it.
func _hit(victim: Node3D, damage: float) -> void:
	audio.chop_at(victim.global_position + Vector3.UP * 0.8)
	wildlife.impact_local(victim.global_position + Vector3.UP * 0.6)
	_act("hit", [victim.net_id, damage])


func _arrow_hit(target: Node3D, damage: float) -> void:
	hud.toast("Hit!")
	_act("hit", [target.net_id, damage])


func _catch(f: Fish, bob: Vector3) -> void:
	_act("catch", [f.net_id, bob])


# --- the shared-world action layer --------------------------------------------

## Change the shared world: straight away in single player or on the host,
## via the host when we're a client.
func _act(action: String, args: Array) -> void:
	if net.is_client():
		net.request(action, args)
	else:
		_do(net.my_id(), action, args)


## Runs where the world is simulated. `peer` is who asked.
func _do(peer: int, action: String, args: Array) -> void:
	match action:
		"rock":
			var i: int = args[0]
			if i < 0 or i >= rocks.taken.size() or rocks.taken[i] == 1:
				return
			rocks.take(i)
			net.broadcast("rock_taken", [i])
			_give(peer, "rock", 1, "Picked up a rock")
		"tree_rock":
			var id: int = args[0]
			if not trees.trees[id].alive:
				return
			if trees.hit_with_rock(id, _rng):
				_give(peer, "branch", 1, "A branch fell  (+1 branch)")
			elif trees.branches_left(id) == 0:
				_msg(peer, "No reachable branches left on this tree")
		"chop":
			var tid: int = args[0]
			var from := net.position_of(peer)
			if from == Vector3.INF or not trees.trees[tid].alive:
				return
			var logs := trees.chop(tid, float(args[1]), from)
			if logs > 0:
				_give(peer, "log", logs, "Timber!  (+%d logs)" % logs)
		"hit":
			var e := wildlife.find_entity(int(args[0]))
			if e == null or e is Fish or not e.call("is_alive"):
				return
			_apply_hit(peer, e, float(args[1]))
		"catch":
			var f := wildlife.find_entity(int(args[0]))
			if not (f is Fish):
				_msg(peer, "It got away...")
				return
			var kind: String = f.kind
			wildlife.catch_fish(f)
			wildlife.splash(args[1])
			_give(peer, "fish:" + kind, 1, "Caught a %s!" % kind)
		"place":
			var plan: Dictionary = args[0]
			if build.slots.has(plan.key):
				if peer != net.my_id() and not build.free_build:
					var cost: Dictionary = BuildSystem.PIECES[plan.kind].cost
					for k in cost:
						_give(peer, k, int(cost[k]), "")
				_msg(peer, "Someone already built there")
				return
			var s := build.spawn_piece(plan.kind, plan)
			_msg(peer, "Built: %s" % BuildSystem.PIECES[s.kind].label)
		"door":
			var d: Structure = build.slots.get(args[0])
			if d == null or not d.is_door:
				return
			d.set_open(not d.open)
			audio.build_at(d.global_position)
			net.broadcast("door", [d.slot_key, d.open])
		"fuel":
			var fire: Structure = build.slots.get(args[0])
			if fire == null:
				return
			fire.add_fuel(float(args[1]))
			net.broadcast("fuel", [fire.slot_key, fire.fuel])
		"crate":
			var c: Structure = build.slots.get(args[0])
			if c == null:
				return
			if c.looted:
				_msg(peer, "Empty")
				return
			var got := c.open_crate()
			var parts := []
			for e in got:
				_give(peer, e[0], e[1], "")
				parts.append(Items.label(e[0]) if Items.TOOLS.has(e[0]) else Items.count_label(e[0], e[1]))
			audio.build_at(c.global_position)
			net.broadcast("crate", [c.slot_key])
			_msg(peer, "Found: " + (", ".join(parts) if not parts.is_empty() else "nothing"))
		"repair":
			var r: Structure = build.slots.get(args[0])
			if r == null:
				return
			build.repair(r, float(args[1]))
			_msg(peer, "Repaired  (%d%%)" % int(100.0 * r.hp / r.max_hp))


func _apply_hit(peer: int, e: Node3D, damage: float) -> void:
	var from := net.position_of(peer)
	if from == Vector3.INF:
		return
	if e is Animal:
		e.set_meta("player_hit", true)
		e.set_meta("attacker_peer", peer)
	if e is Bear:
		e.set_meta("last_attacker", peer)
		if peer == net.my_id():
			_player_hit_bear = true
	e.call("take_damage", damage, from)
	if peer != net.my_id():
		wildlife.impact_local(e.global_position + Vector3.UP * 0.6)


## Hand a reward (or just a message) to whoever earned it.
func _give(peer: int, item: String, n: int, msg: String) -> void:
	if peer == net.my_id():
		receive(item, n, msg)
	else:
		net.give(peer, item, n, msg)


func _msg(peer: int, text: String) -> void:
	_give(peer, "", 0, text)


## Something arrived for this player (locally or from the host).
func receive(item: String, n: int, msg: String) -> void:
	if item.begins_with("fish:"):
		player.add_fish(item.substr(5))
	elif item != "":
		player.add_item(item, n)
	if msg != "":
		hud.toast(msg)


func _place_piece() -> void:
	var plan := build.plan
	if plan.is_empty() or not plan.ok:
		if not plan.is_empty() and plan.reason != "":
			hud.toast(plan.reason)
		return
	if not build.free_build:
		var cost: Dictionary = BuildSystem.PIECES[plan.kind].cost
		for k in cost:
			player.inv[k] = int(player.inv.get(k, 0)) - int(cost[k])
	build.plan = {}
	_act("place", [plan])


func _interact() -> void:
	var v := _view()
	var ri := rocks.find_target(v[0], v[1], USE_REACH)
	if ri >= 0:
		_act("rock", [ri])
		return
	var s := _structure_target()
	if s != null:
		if s.is_door:
			_act("door", [s.slot_key])
			return
		match s.kind:
			"campfire":
				if s.is_lit() and _raw_food() > 0:
					var n := 0
					for k in Items.COOKS_TO:
						var c := int(player.inv[k])
						if c > 0:
							player.inv[Items.COOKS_TO[k]] += c
							player.inv[k] = 0
							n += c
					hud.toast("Cooked %d %s over the fire" % [n, "item" if n == 1 else "items"])
				elif int(player.inv.log) > 0:
					player.inv.log -= 1
					_act("fuel", [s.slot_key, FUEL_LOG])
					hud.toast("Added a log to the fire")
				elif int(player.inv.branch) > 0:
					player.inv.branch -= 1
					_act("fuel", [s.slot_key, FUEL_BRANCH])
					hud.toast("Added a branch to the fire")
				else:
					hud.toast("You need branches or logs to fuel the fire")
				return
			"crate":
				if s.looted:
					hud.toast("Empty")
				else:
					_act("crate", [s.slot_key])
				return
			"bedroll":
				_try_sleep(s)
				return
	if _at_water() and (player.held != "rod" or player.crouching or player.rod.cast_spot() == Vector3.INF):
		player.drink_lake()
		var filled := player.fill_bottles()
		hud.toast("You drink from the lake%s" % (" and fill your bottles" if filled else ""))
		return
	if player.held == "rod":
		player.rod.use()


## Night, under a roof, nothing hunting you: sleep until morning.
func _try_sleep(bed: Structure) -> void:
	var night := tod_hours >= 20.0 or tod_hours < 5.5
	if not night:
		hud.toast("You can only sleep at night")
		return
	if not build.is_sheltered(bed.global_position + Vector3.UP * 0.2):
		hud.toast("Too exposed to sleep here - it needs a roof")
		return
	for h in wildlife.hostiles():
		if h.global_position.distance_to(player.global_position) < 40.0:
			hud.toast("You can't sleep with danger this close")
			return
	if net.is_online() and net.player_count() > 1:
		# The night can't be skipped for everyone; a rest still helps.
		player.health = minf(player.health + 15.0, PlayerController.MAX_HEALTH)
		player.warmth = PlayerController.MAX_WARMTH
		player.bleeding = 0.0
		hud.fade_sleep()
		hud.toast("You rest a while. (Others are still awake, so the night goes on.)")
		return
	if tod_hours >= 20.0:
		day += 1
	tod_hours = SLEEP_WAKE_HOUR
	player.hunger = maxf(player.hunger - 20.0, 5.0)
	player.thirst = maxf(player.thirst - 25.0, 5.0)
	player.health = minf(player.health + 35.0, PlayerController.MAX_HEALTH)
	player.warmth = PlayerController.MAX_WARMTH
	player.bleeding = 0.0
	hud.fade_sleep()
	_update_sun()
	hud.toast("You slept until morning  (day %d)" % day)


func _repair() -> void:
	var s := _structure_target()
	if s == null or s.kind == "campfire" or s.kind == "crate":
		return
	if s.hp >= s.max_hp:
		hud.toast("%s is in good shape" % BuildSystem.PIECES[s.kind].label)
		return
	var amount := REPAIR_WOOD
	if s.kind == "leanto" or s.kind == "bedroll":
		if not build.free_build and int(player.inv.branch) < 2:
			hud.toast("Need 2 branches to patch it")
			return
		if not build.free_build:
			player.inv.branch -= 2
		amount = REPAIR_BRANCH
	else:
		if not build.free_build and int(player.inv.plank) < 1:
			hud.toast("Need a plank to repair it")
			return
		if not build.free_build:
			player.inv.plank -= 1
	_act("repair", [s.slot_key, amount])


## What the crosshair is on, for the prompt line.
func _prompt() -> String:
	if not player.alive:
		return ""
	if build.active:
		var kind := build.current_kind()
		var line := "%s  (%s)" % [BuildSystem.PIECES[kind].label, BuildSystem.cost_text(kind)]
		if build.plan.is_empty():
			return line
		if build.plan.ok:
			return "LMB  build " + line
		return "%s   -   %s" % [line, build.plan.reason]

	var v := _view()
	if rocks.find_target(v[0], v[1], USE_REACH) >= 0:
		return "E   pick up rock"
	var s := _structure_target()
	if s != null:
		var label: String = BuildSystem.PIECES[s.kind].label
		var hp := "%d%%" % int(100.0 * s.hp / s.max_hp)
		if s.is_door:
			return "E   %s door    R   repair (%s)" % ["close" if s.open else "open", hp]
		match s.kind:
			"campfire":
				if s.is_lit() and _raw_food() > 0:
					return "E   cook your raw food"
				if s.is_lit():
					return "E   add fuel    (burning %s)" % _fmt_time(s.fuel)
				return "E   relight with a branch or log"
			"crate":
				return "Empty crate" if s.looted else "E   search the crate"
			"bedroll":
				return "E   sleep until morning    R   repair (%s)" % hp
		if s.hp < s.max_hp:
			return "%s   R   repair (%s)" % [label, hp]

	var held := player.held
	var reach := USE_REACH
	if Items.TOOLS.has(held) and held != "bow":
		reach = float(Items.TOOLS[held].reach)
	var foe := _melee_target(v[0], v[1], reach if held != "rod" else 2.5)
	if foe != null and held != "rod" and held != "bow":
		return "LMB   attack"
	if held == "bow":
		return "LMB   shoot   (%s)" % Items.count_label("arrow", int(player.inv.arrow))

	var tree := trees.find_target(v[0], v[1], USE_REACH)
	if tree >= 0:
		if held == "rock":
			return "LMB   knock off branches  (%d left)" % trees.branches_left(tree)
		if Items.TOOLS.has(held) and float(Items.TOOLS[held].wood) > 0.0:
			return "LMB   chop   (%d%%)" % int(100.0 * trees.health_of(tree))
		if player.tools.has("axe") or player.tools.has("hatchet"):
			return "Hold an axe to chop"
		if int(player.inv.rock) > 0:
			return "Hold a rock to knock off branches"
	if _at_water():
		if held == "rod" and player.rod.cast_spot() != Vector3.INF and not player.crouching:
			var rp := player.rod.prompt_text()
			return rp + ("    C+E   drink" if player.rod.state == FishingRod.State.IDLE else "")
		return "E   drink" + ("  and fill bottles" if int(player.inv.bottle) > 0 else "")
	return player.rod.prompt_text()


func _side_panel() -> String:
	if craft_open:
		var t := "CRAFTING   (Tab to close)\n"
		for i in RECIPES.size():
			var r: Dictionary = RECIPES[i]
			var ok := true
			for k in r.cost:
				if int(player.inv.get(k, 0)) < int(r.cost[k]):
					ok = false
			if r.has("needs") and not _has_any_tool(r.needs):
				ok = false
			var need: String = "   needs %s" % r.needs.replace("|", " or ") if r.has("needs") else ""
			t += "\n%s %d  %s   -   %s%s" % ["+" if ok else " ", i + 1, r.label, _cost_text(r.cost), need]
		return t
	if build.active:
		var t2 := "BUILD   (B / RMB to close)\n"
		for i in BuildSystem.ORDER.size():
			var kind: String = BuildSystem.ORDER[i]
			var mark := ">" if i == build.piece_idx else " "
			t2 += "\n%s %d  %s   -   %s" % [mark, i + 1, BuildSystem.PIECES[kind].label, BuildSystem.cost_text(kind)]
		t2 += "\n\n" + BuildSystem.PIECES[build.current_kind()].desc
		return t2
	return ""


func _on_structure_destroyed(s: Structure) -> void:
	if survival and not game_over:
		hud.toast("The bear tore down your %s!" % BuildSystem.PIECES[s.kind].label.to_lower())


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
	_use_cd = maxf(_use_cd - delta, 0.0)
	if tod_running:
		var speed := TOD_SPEED_SURVIVAL if survival else TOD_SPEED_SANDBOX
		tod_hours += delta * speed
		if tod_hours >= 24.0:
			tod_hours -= 24.0
			if survival and not game_over:
				day += 1
				hud.toast("Day %d" % day)
	_update_sun()

	# What the surroundings are doing to the player.
	var pp := player.global_position
	player.env_rain = weather.intensity
	player.env_night = night_factor
	player.sheltered = build.is_sheltered(pp)
	player.fire_heat = build.fire_warmth(pp)
	audio.rain_level = weather.intensity
	audio.sheltered = player.sheltered

	if build.active:
		var v := _view()
		build.update_ghost(v[0], v[1], player)

	if not game_over:
		if survival:
			survived += delta
			hud.set_vitals(player)
			hud.set_compass(_compass())
			_update_warning()
		hud.set_prompt(_prompt())
		hud.set_side_panel(_side_panel())

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

	if wildlife.kills != _last_kills and Session.authority():
		_last_kills = wildlife.kills
		hud.toast("The bear brought down a %s" % wildlife.last_kill_label.to_lower())


## Heading plus a pointer toward the nearest cabin you haven't searched.
func _compass() -> String:
	var fwd := -player.global_transform.basis.z
	var heading := fposmod(rad_to_deg(atan2(fwd.x, -fwd.z)), 360.0)
	var names := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var line := "%s  %03d" % [names[int(round(heading / 45.0)) % 8], int(heading)]
	var site := ruins.nearest_unexplored(player.global_position)
	if not site.is_empty():
		var to: Vector3 = site.center - player.global_position
		var bearing := fposmod(rad_to_deg(atan2(to.x, -to.z)), 360.0)
		var rel := wrapf(bearing - heading, -180.0, 180.0)
		var arrow := "^"
		if rel < -20.0:
			arrow = "<"
		elif rel > 20.0:
			arrow = ">"
		line += "      cabin %s %d m" % [arrow, int(Vector2(to.x, to.z).length())]
	return line


func _update_warning() -> void:
	var bear := wildlife.bear
	if bear == null or not is_instance_valid(bear) or not bear.is_alive():
		hud.set_warning("")
		return
	var d := player.global_position.distance_to(bear.global_position)
	var hunting := wildlife.bear_hunting_peer(net.my_id()) if net.is_client() else bear.target == player
	if hunting:
		hud.set_warning("THE BEAR IS HUNTING YOU   %.0f m" % d)
	elif d < 45.0:
		hud.set_warning("You can hear the bear nearby")
	else:
		hud.set_warning("")


func _update_stats() -> void:
	var lines := "%d FPS\n" % Engine.get_frames_per_second()
	var clock := "%02d:%02d" % [int(tod_hours), int(fmod(tod_hours, 1.0) * 60.0)]
	if survival:
		lines += "survived: %s\n" % _fmt_time(survived)
		lines += "day %d   %s%s\n" % [day, clock, "" if tod_running else " (paused)"]
		lines += "fish caught: %d\n" % player.fish_caught
		lines += "fish in lake: %d\n" % wildlife.fish_count()
		lines += "best: %s" % (_fmt_time(best_time) if best_time > 0.0 else "-")
		if net.is_online():
			lines += "\n\n%d player%s online" % [net.player_count(), "" if net.player_count() == 1 else "s"]
			for pid in net.peers:
				lines += "\n" + str(net.peers[pid].name)
		hud.set_stats(lines)
		hud.set_net(net.status if net.is_online() else "")
		return

	var bear_state := "-"
	var bear_dist := 0.0
	if wildlife.bear != null and is_instance_valid(wildlife.bear):
		bear_state = wildlife.bear.state_name()
		bear_dist = player.global_position.distance_to(wildlife.bear.global_position)
	var mode_names := ["player", "bear", "prey"]
	lines += "animals alive: %d\n" % wildlife.alive_count()
	lines += "fish in lake: %d\n" % wildlife.fish_count()
	lines += "kills: %d\n" % wildlife.kills
	lines += "bear: %s (%.0f m)\n" % [bear_state, bear_dist]
	lines += "camera: %s\n" % mode_names[camera_mode]
	lines += "time: %s%s" % [clock, "" if tod_running else " (paused)"]
	hud.set_stats(lines)


static func _fmt_time(secs: float) -> String:
	var s := int(secs)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


# --- survival events ----------------------------------------------------------

func _on_player_hurt(amount: float) -> void:
	hud.flash_hurt(amount)
	audio.player_hurt(player.global_position)


func _on_player_ate(kind: String, got_sick: bool) -> void:
	if got_sick:
		hud.toast("You ate %s... your stomach turns. Food poisoning!" % Items.label(kind))
	else:
		hud.toast("You ate %s" % Items.label(kind))


func _hook_bear(b: Bear) -> void:
	if b == null:
		return
	b.noticed_player.connect(_on_bear_noticed)
	b.lost_player.connect(_on_bear_lost)
	b.died.connect(_on_bear_died)
	_bears_seen += 1
	if _bears_seen > 1 and survival and not game_over:
		hud.toast("You hear a new bear moving through the forest...")


## Tell a particular player something about the bear.
func _bear_msg(p: Node3D, text: String) -> void:
	if p == player:
		if survival and not game_over:
			hud.toast(text)
	elif p is RemotePlayer and net.is_host():
		net.send_msg(p.peer_id, text)


func _on_bear_noticed(p: Node3D) -> void:
	_bear_msg(p, "The bear has caught your scent!")


func _on_bear_lost(reason: String, p: Node3D) -> void:
	match reason:
		"water": _bear_msg(p, "The bear can't reach you out here")
		"walls": _bear_msg(p, "The bear gave up on your walls")
		"fled": _bear_msg(p, "The bear is running away!")
		_: _bear_msg(p, "You lost the bear... for now")


func _on_bear_died(b: Bear) -> void:
	var peer := int(b.get_meta("last_attacker", 0))
	if peer == 0 and _player_hit_bear:
		peer = net.my_id()
	_player_hit_bear = false
	if peer != 0:
		_give(peer, "raw_meat", BEAR_MEAT, "You killed the bear!  (+%d raw meat)" % BEAR_MEAT)


func _on_player_killed_animal(a: Animal) -> void:
	var n: int = MEAT.get(a.species, 1)
	var peer := int(a.get_meta("attacker_peer", net.my_id()))
	_give(peer, "raw_meat", n, "You killed a %s  (+%d raw meat)" % [Species.get_cfg(a.species).label.to_lower(), n])


func _on_fish_caught(kind: String) -> void:
	hud.toast("Caught a %s!" % kind)


func _on_player_died(cause: String) -> void:
	if not survival:
		return
	game_over = true
	var record := survived > best_time
	if record:
		best_time = survived
	best_fish = maxi(best_fish, player.fish_caught)
	_save_best()

	var how := "You were killed by the bear."
	match cause:
		"drowned": how = "You drowned."
		"starved": how = "You starved."
		"froze": how = "You froze to death."
		"dehydrated": how = "You died of thirst."
		"bled": how = "You bled out."
	var text := "%s\n\n" % how
	text += "Survived  %s   (day %d)\n" % [_fmt_time(survived), day]
	text += "Fish caught  %d\n\n" % player.fish_caught
	text += "NEW BEST TIME!\n\n" if record else "Best  %s\n\n" % _fmt_time(best_time)
	if net.is_online():
		text += "Press Enter to respawn  (you lose what you were carrying)"
	else:
		text += "Press Enter to try again"
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if game_over:
			hud.show_game_over(text)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)


## Online: back into the running world with empty pockets.
func _respawn() -> void:
	game_over = false
	survived = 0.0
	hud.game_over.visible = false
	player.respawn_at(_shore_spawn())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.toast("You wake up by the lake with nothing but your rod.")


func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		best_time = float(cf.get_value("survival", "best_time", 0.0))
		best_fish = int(cf.get_value("survival", "best_fish", 0))


func _save_best() -> void:
	var cf := ConfigFile.new()
	cf.set_value("survival", "best_time", best_time)
	cf.set_value("survival", "best_fish", best_fish)
	cf.save(SAVE_PATH)


# --- online: world state ------------------------------------------------------

## Host: everything a player joining late needs to catch up.
func snapshot_world() -> Dictionary:
	var pieces := []
	for s in build.structures:
		pieces.append(BuildSystem.describe(s))
	return {
		"tod": tod_hours, "day": day, "raining": weather.raining,
		"felled": trees.felled_ids(),
		"rock_pos": rocks.positions, "rock_taken": rocks.taken,
		"pieces": pieces,
	}


## Client: catch up with the host's world.
func apply_world(state: Dictionary) -> void:
	apply_env(state.tod, state.day, state.raining)
	for id in state.felled:
		trees.remove_felled(id)
	var pos: PackedVector3Array = state.rock_pos
	var taken: PackedByteArray = state.rock_taken
	for i in mini(pos.size(), rocks.positions.size()):
		if taken[i] == 1:
			rocks.take(i)
		elif pos[i] != rocks.positions[i]:
			rocks.place_at(i, pos[i])
	# Rebuild every piece from the host's copy, then re-link the ruins' crates
	# (same keys on both machines, since ruins come from the shared seed).
	var crate_keys := []
	for site in ruins.sites:
		var keys := []
		for c in site.crates:
			keys.append(c.slot_key)
		crate_keys.append(keys)
	build.clear_all()
	for d in state.pieces:
		build.spawn_described(d)
	for i in ruins.sites.size():
		var relinked: Array[Structure] = []
		for k in crate_keys[i]:
			if build.slots.has(k):
				relinked.append(build.slots[k])
		ruins.sites[i].crates = relinked


func apply_env(tod: float, d: int, raining: bool) -> void:
	tod_hours = tod
	day = d
	if raining != weather.raining:
		if raining:
			weather.start_rain()
		else:
			weather.stop_rain()


## Client: the host says the world changed.
func _on_net_event(event: String, args: Array) -> void:
	match event:
		"rock_taken":
			rocks.take(args[0])
		"rock_placed":
			rocks.place_at(args[0], args[1])
		"tree_felled":
			trees.fell(args[0], args[1])
		"piece":
			build.spawn_described(args[0])
		"piece_hp":
			var s: Structure = build.slots.get(args[0])
			if s != null:
				s.hp = args[1]
		"piece_removed":
			var r: Structure = build.slots.get(args[0])
			if r != null:
				build.remove(r)
		"door":
			var d: Structure = build.slots.get(args[0])
			if d != null and d.open != args[1]:
				d.set_open(args[1])
		"fuel":
			var f: Structure = build.slots.get(args[0])
			if f != null:
				f.fuel = args[1]
				f._update_fire()
		"crate":
			var c: Structure = build.slots.get(args[0])
			if c != null:
				c.open_crate()


## Client: a sound or effect from the host's simulation.
func _on_net_fx(kind: String, a: String, pos: Vector3) -> void:
	match kind:
		"voice":
			var parts := a.split(":")
			if parts.size() == 2:
				audio.animal_voice(parts[0], parts[1], pos)
		"bear":
			audio.bear_voice(a, pos)
		"rustle":
			audio.rustle_at(pos)
		"impact":
			wildlife.impact_local(pos)
		"splash":
			wildlife.splash_local(pos)
