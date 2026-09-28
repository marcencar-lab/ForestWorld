class_name Weather
extends Node3D

## Rain showers on a timer. Drops are GPU particles that follow the camera and
## die against a heightfield captured around it, so they stop at roofs and the
## ground instead of falling through your shelter.
##
## `intensity` (0..1) is read by the world to grey out the sky and by the
## player's warmth.

signal rain_started
signal rain_stopped

const FIRST_RAIN := Vector2(150.0, 260.0)   # seconds of calm before the first shower
const CLEAR_SPELL := Vector2(240.0, 480.0)
const RAIN_SPELL := Vector2(100.0, 200.0)
const FADE_TIME := 10.0

var raining := false
var intensity := 0.0
var auto := true                 # scheduled showers; off lets a caller drive it
var follow: Node3D

var _timer := 0.0
var _rng := RandomNumberGenerator.new()
var _drops: GPUParticles3D
var _catcher: GPUParticlesCollisionHeightField3D


func setup(world_seed: int) -> void:
	_rng.seed = world_seed + 991
	_timer = _rng.randf_range(FIRST_RAIN.x, FIRST_RAIN.y)
	_build()


func _build() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24, 0.5, 24)
	pm.direction = Vector3(0.08, -1, 0.03)
	pm.spread = 2.0
	pm.initial_velocity_min = 20.0
	pm.initial_velocity_max = 25.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	pm.collision_use_scale = false

	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.55)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.78, 0.84, 0.92, 0.42)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = m

	_drops = GPUParticles3D.new()
	_drops.name = "Rain"
	_drops.amount = 6000
	_drops.lifetime = 1.25
	_drops.preprocess = 1.0
	_drops.local_coords = false
	_drops.process_material = pm
	_drops.draw_pass_1 = quad
	_drops.visibility_aabb = AABB(Vector3(-30, -40, -30), Vector3(60, 50, 60))
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_drops.amount_ratio = 0.0
	_drops.emitting = false
	add_child(_drops)

	# Captures roofs and terrain from above around the camera.
	_catcher = GPUParticlesCollisionHeightField3D.new()
	_catcher.name = "RainCatcher"
	_catcher.size = Vector3(56, 60, 56)
	_catcher.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	_catcher.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_ALWAYS
	_catcher.follow_camera_enabled = true
	add_child(_catcher)


func start_rain() -> void:
	if raining:
		return
	raining = true
	_timer = _rng.randf_range(RAIN_SPELL.x, RAIN_SPELL.y)
	rain_started.emit()


func stop_rain() -> void:
	if not raining:
		return
	raining = false
	_timer = _rng.randf_range(CLEAR_SPELL.x, CLEAR_SPELL.y)
	rain_stopped.emit()


func toggle() -> void:
	if raining:
		stop_rain()
	else:
		start_rain()


func _process(delta: float) -> void:
	if auto:
		_timer -= delta
		if _timer <= 0.0:
			toggle()

	intensity = move_toward(intensity, 1.0 if raining else 0.0, delta / FADE_TIME)
	_drops.amount_ratio = intensity
	_drops.emitting = intensity > 0.01

	if follow != null and is_instance_valid(follow):
		var f := follow.global_position
		_drops.global_position = Vector3(f.x, f.y + 16.0, f.z)
