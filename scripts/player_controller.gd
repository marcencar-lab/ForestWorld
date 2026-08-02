class_name PlayerController
extends CharacterBody3D

## Free-roaming observer. Walks and jumps over the terrain collider, or flies
## for a quick look around. Uses physical key polling so no InputMap is needed.

const WALK := 6.5
const SPRINT := 15.0
const FLY := 26.0
const FLY_FAST := 85.0
const JUMP := 9.5
const GRAVITY := 26.0
const ACCEL_GROUND := 14.0
const ACCEL_AIR := 4.0
const MOUSE_SENS := 0.0024

var flying := false
var head: Node3D
var camera: Camera3D
var pitch := 0.0

var audio: AudioDirector
var terrain: ForestTerrain
var _step_accum := 0.0

const STEP_STRIDE := 2.3   # metres of travel per footfall


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.65, 0)
	add_child(head)

	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.fov = 72.0
	camera.near = 0.08
	camera.far = 1200.0
	head.add_child(camera)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -1.45, 1.45)
		head.rotation.x = pitch
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_F:
				flying = not flying
				if flying:
					velocity.y = 0.0


func _wish_dir() -> Vector3:
	var input := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input.x += 1.0
	return input.normalized()


func _physics_process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if not flying:
			velocity.y -= GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		move_and_slide()
		return

	var wish := _wish_dir()
	var fast := Input.is_physical_key_pressed(KEY_SHIFT)

	if flying:
		var basis_cam := head.global_transform.basis
		var dir := (basis_cam * wish).normalized() if wish != Vector3.ZERO else Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_SPACE):
			dir += Vector3.UP
		if Input.is_physical_key_pressed(KEY_CTRL):
			dir += Vector3.DOWN
		var speed := FLY_FAST if fast else FLY
		velocity = velocity.move_toward(dir.normalized() * speed if dir != Vector3.ZERO else Vector3.ZERO, 60.0 * delta)
		move_and_slide()
		return

	var dir_flat := (global_transform.basis * wish)
	dir_flat.y = 0.0
	dir_flat = dir_flat.normalized()

	var target_speed := SPRINT if fast else WALK
	var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	horiz = horiz.move_toward(dir_flat * target_speed, accel * target_speed * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z

	if is_on_floor():
		if Input.is_physical_key_pressed(KEY_SPACE):
			velocity.y = JUMP
		else:
			velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta

	move_and_slide()
	_footsteps(delta)


func _footsteps(delta: float) -> void:
	if audio == null or not is_on_floor():
		_step_accum = STEP_STRIDE * 0.6   # land with a step on the next stride
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.6:
		return
	_step_accum += speed * delta
	if _step_accum < STEP_STRIDE:
		return
	_step_accum = 0.0
	var wet := false
	if terrain != null:
		wet = terrain.water_depth(global_position.x, global_position.z) > -0.15
	audio.footstep_at(global_position, wet)
