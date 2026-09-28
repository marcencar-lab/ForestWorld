class_name PlayerController
extends CharacterBody3D

## The player. In survival mode they walk, sneak, swim, get hungry and can be
## mauled; in sandbox mode (god_mode) they are an invulnerable observer who can
## fly. Uses physical key polling so no InputMap is needed.

signal hurt(amount)
signal died(cause)
signal ate(kind, sick)
signal status(text)

const WALK := 5.0
const SPRINT := 9.0            # deliberately slower than the bear's charge
const CROUCH := 2.4
const SWIM := 3.0
const SWIM_FAST := 4.6
const FLY := 26.0
const FLY_FAST := 85.0
const JUMP := 8.0
const GRAVITY := 26.0
const ACCEL_GROUND := 14.0
const ACCEL_AIR := 4.0
const MOUSE_SENS := 0.0024

## Water deeper than this (at the player's column) means swimming.
const SWIM_DEPTH := 1.15
## Body origin sits this far under the surface while swimming (eyes just above).
const SWIM_SINK := 1.45

const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0
const MAX_HUNGER := 100.0
const HUNGER_RATE := MAX_HUNGER / 480.0   # full to empty in 8 minutes
const STARVE_DAMAGE := 1.5                # per second once hunger hits zero
const DROWN_DAMAGE := 12.0                # per second, swimming with no stamina
const REGEN := 1.2                        # health per second when fed and unhurt
const SPRINT_DRAIN := 10.0
const SWIM_DRAIN := 3.2
const STAMINA_REGEN := 16.0
const EXHAUSTED_UNTIL := 30.0             # stamina needed before sprinting again

const MAX_WARMTH := 100.0
const FREEZE_DAMAGE := 2.0               # per second once warmth hits zero
const RAIN_CHILL := 0.9                  # warmth per second lost in full rain, unsheltered
const NIGHT_CHILL := 0.3                 # ...and out in the open at night
const WATER_CHILL := 0.8
const FIRE_HEAT := 4.0
const SHELTER_HEAT := 0.8
const SUN_HEAT := 0.4

const MAX_THIRST := 100.0
const THIRST_RATE := MAX_THIRST / 420.0  # full to empty in 7 minutes
const THIRST_DAMAGE := 2.0
const SIP := 25.0                         # thirst per mouthful from a bottle
const LAKE_DRINK := 35.0
const SIPS_PER_BOTTLE := 4
const BLEED_DAMAGE := 1.2                 # per second while bleeding
const BLEED_TIME := 22.0                  # seconds a bear wound bleeds unbandaged
const BANDAGE_HEAL := 25.0
const SICK_TIME := 90.0

var flying := false
var god_mode := false
var head: Node3D
var camera: Camera3D
var rod: FishingRod
var hand: ToolHand
var pitch := 0.0

var alive := true
var health := MAX_HEALTH
var stamina := MAX_STAMINA
var hunger := MAX_HUNGER
var crouching := false
var swimming := false
var sprinting := false
var exhausted := false
var warmth := MAX_WARMTH
var thirst := MAX_THIRST
var bleeding := 0.0             # seconds of bleeding left
var sick := 0.0                 # seconds of food poisoning left
var water_sips := 0             # carried in bottles
var inv := {
	"rock": 0, "branch": 0, "log": 0, "plank": 0,
	"raw_trout": 0, "cooked_trout": 0, "raw_pike": 0, "cooked_pike": 0,
	"raw_meat": 0, "cooked_meat": 0, "canned_food": 0,
	"bandage": 0, "bottle": 0, "arrow": 0,
}
## Tools and weapons owned, name -> remaining uses.
var tools := {}
var held := "rod"               # "rod", "rock", or a key of `tools`
var fish_caught := 0
var death_cause := ""

# Set by the world every frame - what the surroundings are doing to you.
var env_rain := 0.0
var env_night := 0.0
var sheltered := false
var fire_heat := 0.0

var audio: AudioDirector
var terrain: ForestTerrain
var _step_accum := 0.0
var _since_hurt := 99.0
var _since_sprint := 99.0
var _shake := 0.0
var _death_t := 0.0
var _head_y := 1.65

const STEP_STRIDE := 2.3   # metres of travel per footfall
const HEAD_STAND := 1.65
const HEAD_CROUCH := 1.0


func _ready() -> void:
	add_to_group("players")
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, HEAD_STAND, 0)
	add_child(head)

	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.fov = 72.0
	camera.near = 0.08
	camera.far = 1200.0
	head.add_child(camera)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func setup_rod(m: WildlifeManager) -> void:
	rod = FishingRod.new()
	rod.name = "FishingRod"
	camera.add_child(rod)
	rod.setup(self, terrain, m)
	hand = ToolHand.new()
	hand.name = "ToolHand"
	camera.add_child(hand)


## Switch the held tool, if the player actually has it.
func equip(item: String) -> bool:
	match item:
		"rock":
			if int(inv.rock) <= 0:
				return false
		"rod":
			pass
		_:
			if not tools.has(item):
				return false
	if held == item:
		return true
	if held == "rod" and rod != null:
		rod.cancel()
	held = item
	hand.show_item(item if item != "rod" else "")
	return true


func is_alive() -> bool:
	return alive


func set_god_mode(on: bool) -> void:
	god_mode = on
	if not on and flying:
		flying = false


## How loud the player is right now, as a multiplier on the bear's hearing.
func noise_level() -> float:
	if swimming:
		return 0.8
	if crouching:
		return 0.45
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.5:
		return 0.7
	if sprinting:
		return 1.6
	return 1.0


func smelly_count() -> int:
	var n := 0
	for k in Items.SMELLY:
		n += int(inv[k])
	return n


## Extra metres of detection radius from the fish and meat the player carries.
func scent_bonus() -> float:
	return minf(smelly_count() * 9.0, 36.0)


func add_fish(kind: String) -> void:
	inv["raw_" + kind] += 1
	fish_caught += 1


## Add loot or crafted goods. Tools replace a worn copy with a fresh one.
func add_item(key: String, n := 1) -> void:
	if Items.TOOLS.has(key):
		tools[key] = maxi(int(tools.get(key, 0)), int(Items.TOOLS[key].uses))
		return
	inv[key] = int(inv.get(key, 0)) + n


func food_count() -> int:
	var n := 0
	for k in Items.FOOD:
		n += int(inv[k])
	return n


## Eat the best food carried. Returns what was eaten, or "".
func eat() -> String:
	if not alive:
		return ""
	var kind := ""
	for k in Items.FOOD:
		if int(inv[k]) > 0:
			kind = k
			break
	if kind == "":
		return ""
	inv[kind] -= 1
	var food: Dictionary = Items.FOOD[kind]
	hunger = minf(hunger + float(food.hunger), MAX_HUNGER)
	health = minf(health + float(food.health), MAX_HEALTH)
	thirst = minf(thirst + float(food.get("thirst", 0.0)), MAX_THIRST)
	var got_sick := randf() < float(food.sick)
	if got_sick:
		sick = SICK_TIME
	ate.emit(kind, got_sick)
	return kind


## Drink from the lake (unlimited) or a bottle (one sip).
func drink_lake() -> void:
	thirst = minf(thirst + LAKE_DRINK, MAX_THIRST)


func drink_bottle() -> bool:
	if water_sips <= 0 or not alive:
		return false
	water_sips -= 1
	thirst = minf(thirst + SIP, MAX_THIRST)
	return true


func fill_bottles() -> bool:
	var cap := int(inv.bottle) * SIPS_PER_BOTTLE
	if cap <= 0 or water_sips >= cap:
		return false
	water_sips = cap
	return true


func use_bandage() -> bool:
	if int(inv.bandage) <= 0 or not alive:
		return false
	if bleeding <= 0.0 and health >= MAX_HEALTH:
		return false
	inv.bandage -= 1
	bleeding = 0.0
	health = minf(health + BANDAGE_HEAL, MAX_HEALTH)
	return true


## Hotbar order: only what the player actually has.
func hotbar() -> Array:
	var out := ["rod"]
	if int(inv.rock) > 0:
		out.append("rock")
	for t in Items.HOTBAR_ORDER:
		if tools.has(t):
			out.append(t)
	return out


## Spend one use of the held tool; drops back to bare hands when it breaks.
func wear_tool() -> bool:
	if not tools.has(held):
		return false
	tools[held] -= 1
	if tools[held] <= 0:
		tools.erase(held)
		equip("rod")
		return true
	return false


func take_damage(amount: float, from: Vector3) -> void:
	if god_mode or not alive:
		return
	health -= amount
	_since_hurt = 0.0
	_shake = minf(_shake + amount / 40.0, 1.0)
	var knock := global_position - from
	knock.y = 0.0
	if knock.length() > 0.01:
		velocity += knock.normalized() * 9.0
	velocity.y = maxf(velocity.y, 3.5)
	# Claws open wounds that keep bleeding until bandaged.
	if amount >= 15.0:
		bleeding = maxf(bleeding, BLEED_TIME)
	hurt.emit(amount)
	if health <= 0.0:
		_die("bear")


## Online respawn: fresh vitals, empty pockets.
func respawn_at(pos: Vector3) -> void:
	alive = true
	health = MAX_HEALTH
	stamina = MAX_STAMINA
	hunger = MAX_HUNGER
	thirst = MAX_THIRST
	warmth = MAX_WARMTH
	bleeding = 0.0
	sick = 0.0
	water_sips = 0
	exhausted = false
	for k in inv:
		inv[k] = 0
	tools.clear()
	held = "rod"
	hand.show_item("")
	death_cause = ""
	_death_t = 0.0
	pitch = 0.0
	_head_y = HEAD_STAND
	head.position.y = HEAD_STAND
	head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	global_position = pos


func _die(cause: String) -> void:
	if not alive:
		return
	alive = false
	health = 0.0
	death_cause = cause
	crouching = false
	if rod != null:
		rod.cancel()
	died.emit(cause)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if not alive:
			return
		rotate_y(-event.relative.x * MOUSE_SENS)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -1.45, 1.45)
		head.rotation.x = pitch
	elif event is InputEventMouseButton and event.pressed:
		if alive and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			# The click only recaptures the mouse - don't also swing or build.
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_F:
				if god_mode:
					flying = not flying
					if flying:
						velocity.y = 0.0
			KEY_Q:
				if alive and eat() == "":
					status.emit("You have nothing to eat")
			KEY_X:
				if alive:
					if drink_bottle():
						status.emit("You drink from your bottle")
					elif int(inv.bottle) > 0:
						status.emit("Your bottles are empty. Fill them at the lake (E)")
			KEY_Z:
				if alive:
					if use_bandage():
						status.emit("You bandage your wounds")
					elif int(inv.bandage) <= 0:
						status.emit("You have no bandages")


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
	_since_hurt += delta
	_since_sprint += delta

	if not alive:
		_death_step(delta)
		return

	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var wish := _wish_dir() if captured else Vector3.ZERO
	var fast := captured and Input.is_physical_key_pressed(KEY_SHIFT)

	if flying:
		_fly(wish, fast, captured, delta)
		_update_head(delta)
		return

	var depth := 0.0
	if terrain != null:
		depth = terrain.water_depth(global_position.x, global_position.z)
	swimming = depth > SWIM_DEPTH
	crouching = captured and not swimming and Input.is_physical_key_pressed(KEY_C)

	var moving := wish != Vector3.ZERO
	sprinting = fast and moving and not crouching and not swimming and not exhausted and stamina > 0.0

	var dir_flat := (global_transform.basis * wish)
	dir_flat.y = 0.0
	dir_flat = dir_flat.normalized()

	var target_speed := WALK
	if swimming:
		target_speed = SWIM_FAST if (fast and stamina > 0.0) else SWIM
	elif crouching:
		target_speed = CROUCH
	elif sprinting:
		target_speed = SPRINT

	var accel := ACCEL_GROUND if (is_on_floor() or swimming) else ACCEL_AIR
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	horiz = horiz.move_toward(dir_flat * target_speed, accel * target_speed * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z

	if swimming:
		# Float with the eyes just above the surface.
		var want_y := ForestTerrain.WATER_LEVEL - SWIM_SINK
		velocity.y = clampf((want_y - global_position.y) * 5.0, -4.0, 4.0)
	elif is_on_floor():
		if captured and Input.is_physical_key_pressed(KEY_SPACE) and not crouching:
			velocity.y = JUMP
		else:
			velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta

	move_and_slide()
	_vitals(delta, fast and swimming and moving)
	_update_head(delta)
	_footsteps(delta)


func _fly(wish: Vector3, fast: bool, captured: bool, delta: float) -> void:
	swimming = false
	crouching = false
	sprinting = false
	var basis_cam := head.global_transform.basis
	var dir := (basis_cam * wish).normalized() if wish != Vector3.ZERO else Vector3.ZERO
	if captured and Input.is_physical_key_pressed(KEY_SPACE):
		dir += Vector3.UP
	if captured and Input.is_physical_key_pressed(KEY_CTRL):
		dir += Vector3.DOWN
	var speed := FLY_FAST if fast else FLY
	velocity = velocity.move_toward(dir.normalized() * speed if dir != Vector3.ZERO else Vector3.ZERO, 60.0 * delta)
	move_and_slide()


func _vitals(delta: float, swim_hard: bool) -> void:
	if god_mode:
		health = MAX_HEALTH
		stamina = MAX_STAMINA
		hunger = MAX_HUNGER
		warmth = MAX_WARMTH
		thirst = MAX_THIRST
		bleeding = 0.0
		sick = 0.0
		exhausted = false
		return

	# Stamina: spent sprinting and swimming, recovered on dry land.
	if sprinting:
		stamina -= SPRINT_DRAIN * delta
		_since_sprint = 0.0
	elif swimming:
		stamina -= SWIM_DRAIN * (2.0 if swim_hard else 1.0) * delta
		_since_sprint = 0.0
	elif _since_sprint > 0.8:
		stamina += STAMINA_REGEN * delta * (1.4 if crouching else 1.0)
	stamina = clampf(stamina, 0.0, MAX_STAMINA)
	if stamina <= 0.0:
		exhausted = true
	elif exhausted and stamina >= EXHAUSTED_UNTIL:
		exhausted = false

	# Food poisoning makes you burn through food and water and stops healing.
	var drain := 1.8 if sick > 0.0 else 1.0
	sick = maxf(sick - delta, 0.0)
	hunger = maxf(hunger - HUNGER_RATE * drain * delta, 0.0)
	thirst = maxf(thirst - THIRST_RATE * drain * delta, 0.0)

	if bleeding > 0.0:
		bleeding = maxf(bleeding - delta, 0.0)
		health -= BLEED_DAMAGE * delta
		_since_hurt = 0.0
		if health <= 0.0:
			_die("bled")
			return
	if thirst <= 0.0:
		health -= THIRST_DAMAGE * delta
		if health <= 0.0:
			_die("dehydrated")
			return

	# Warmth: rain, night air and the lake chill you; fire, shelter and sun warm you.
	var dw := 0.0
	if not sheltered:
		dw -= RAIN_CHILL * env_rain + NIGHT_CHILL * env_night
	if swimming:
		dw -= WATER_CHILL
	if fire_heat > 0.0:
		dw += FIRE_HEAT * fire_heat
	elif sheltered:
		dw += SHELTER_HEAT
	elif env_rain < 0.05 and env_night < 0.3:
		dw += SUN_HEAT
	warmth = clampf(warmth + dw * delta, 0.0, MAX_WARMTH)
	if warmth <= 0.0:
		health -= FREEZE_DAMAGE * delta
		_since_hurt = 0.0
		if health <= 0.0:
			_die("froze")
			return

	if swimming and stamina <= 0.0:
		health -= DROWN_DAMAGE * delta
		_since_hurt = 0.0
		if health <= 0.0:
			_die("drowned")
			return
	if hunger <= 0.0:
		health -= STARVE_DAMAGE * delta
		if health <= 0.0:
			_die("starved")
			return
	elif hunger > 40.0 and thirst > 25.0 and sick <= 0.0 and _since_hurt > 6.0:
		health = minf(health + REGEN * delta, MAX_HEALTH)


func _update_head(delta: float) -> void:
	var want := HEAD_CROUCH if crouching else HEAD_STAND
	_head_y = lerpf(_head_y, want, clampf(delta * 10.0, 0.0, 1.0))
	head.position.y = _head_y
	_apply_shake(delta)


func _apply_shake(delta: float) -> void:
	_shake = maxf(_shake - delta * 1.8, 0.0)
	var s := _shake * _shake * 0.18
	camera.h_offset = randf_range(-s, s)
	camera.v_offset = randf_range(-s, s)


## Slump to the ground and roll the view onto its side.
func _death_step(delta: float) -> void:
	_death_t += delta
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	if death_cause == "drowned":
		velocity.y = -0.6
	elif is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	var t := clampf(_death_t / 1.2, 0.0, 1.0)
	head.position.y = lerpf(_head_y, 0.35, t)
	head.rotation.z = lerpf(0.0, 1.2, t)
	head.rotation.x = lerpf(pitch, 0.15, t)
	_apply_shake(delta)


func _footsteps(delta: float) -> void:
	if audio == null or not is_on_floor() or swimming:
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
	# Sneaking is quieter.
	audio.footstep_at(global_position, wet, -8.0 if crouching else 0.0)
