class_name FishingRod
extends Node3D

## A hand-held rod parented to the player camera. E casts a bobber onto open
## water in front of the player; a real fish swimming near the bobber will
## eventually bite, and pressing E again inside the bite window lands it.
##
## The bobber and line live in world space (top_level) so they stay put on the
## water while the view moves.

enum State { IDLE, CAST, WAIT, BITE }

signal caught(kind)
signal message(text)

const CAST_MIN := 5.0
const CAST_MAX := 16.0
const MIN_WATER := 0.9        # the bobber needs at least this much depth
const BITE_RADIUS := 9.0      # a fish this close to the bobber can take the bait
const BITE_WINDOW := 1.15
const CAST_TIME := 0.55
const LEASH := 2.5            # walk further than this and the line comes in
const ROD_LENGTH := 1.3

## Set by the world so a catch can be confirmed by the host when online.
var catch_handler: Callable
var player: PlayerController
var terrain: ForestTerrain
var manager: WildlifeManager

var state: int = State.IDLE
var _bob := Vector3.ZERO
var _bob_start := Vector3.ZERO
var _cast_from := Vector3.ZERO
var _t := 0.0
var _bite_timer := -1.0
var _scan_timer := 0.0
var _quiet_t := 0.0
var _hinted := false
var _hooked: Fish = null

var _pivot: Node3D
var _bobber: MeshInstance3D
var _line: ImmediateMesh
var _line_inst: MeshInstance3D
var _line_mat: StandardMaterial3D

var _rng := RandomNumberGenerator.new()


func setup(p: PlayerController, t: ForestTerrain, m: WildlifeManager) -> void:
	player = p
	terrain = t
	manager = m
	_rng.randomize()
	_build()


func _build() -> void:
	# Rod: a tapered cylinder from the lower right of the view, angled forward and up.
	_pivot = Node3D.new()
	_pivot.name = "RodPivot"
	_pivot.position = Vector3(0.30, -0.34, -0.42)
	_pivot.rotation = Vector3(-(PI * 0.5 - 0.45), 0.12, 0.0)
	add_child(_pivot)

	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.006
	cyl.bottom_radius = 0.016
	cyl.height = ROD_LENGTH
	cyl.radial_segments = 6
	cyl.rings = 1
	var rod_mi := MeshInstance3D.new()
	rod_mi.mesh = cyl
	rod_mi.material_override = CritterBuilder.material(Color(0.30, 0.20, 0.12), 0.5)
	rod_mi.position = Vector3(0, ROD_LENGTH * 0.5, 0)
	rod_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(rod_mi)

	var grip := CylinderMesh.new()
	grip.top_radius = 0.022
	grip.bottom_radius = 0.022
	grip.height = 0.28
	grip.radial_segments = 6
	var grip_mi := MeshInstance3D.new()
	grip_mi.mesh = grip
	grip_mi.material_override = CritterBuilder.material(Color(0.10, 0.09, 0.08), 0.8)
	grip_mi.position = Vector3(0, 0.12, 0)
	grip_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(grip_mi)

	# Bobber: red over white, floating on the surface.
	_bobber = MeshInstance3D.new()
	_bobber.name = "Bobber"
	_bobber.top_level = true
	var top := SphereMesh.new()
	top.radius = 0.07
	top.height = 0.14
	top.radial_segments = 10
	top.rings = 5
	_bobber.mesh = top
	_bobber.material_override = CritterBuilder.material(Color(0.85, 0.12, 0.08), 0.35)
	var belly := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.066
	bm.height = 0.10
	bm.radial_segments = 10
	bm.rings = 4
	belly.mesh = bm
	belly.material_override = CritterBuilder.material(Color(0.93, 0.93, 0.90), 0.35)
	belly.position = Vector3(0, -0.035, 0)
	_bobber.add_child(belly)
	_bobber.visible = false
	add_child(_bobber)

	# Line: redrawn every frame from the rod tip to the bobber.
	_line = ImmediateMesh.new()
	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.albedo_color = Color(0.86, 0.86, 0.82)
	_line_inst = MeshInstance3D.new()
	_line_inst.name = "Line"
	_line_inst.top_level = true
	_line_inst.mesh = _line
	_line_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line_inst)


func _tip() -> Vector3:
	return _pivot.global_transform * Vector3(0, ROD_LENGTH, 0)


# --- actions ------------------------------------------------------------------

func use() -> void:
	match state:
		State.IDLE:
			_try_cast()
		State.WAIT:
			cancel()
			message.emit("Reeled in.")
		State.BITE:
			_land()


func cancel() -> void:
	state = State.IDLE
	_hooked = null
	_bite_timer = -1.0
	_bobber.visible = false
	_line.clear_surfaces()


## Where a cast from here would land, or Vector3.INF if there is no open water.
func cast_spot() -> Vector3:
	if player == null or player.swimming:
		return Vector3.INF
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return Vector3.INF
	fwd = fwd.normalized()
	# Look down to cast short, look level to cast long.
	var reach := remap(clampf(player.pitch, -0.7, 0.15), -0.7, 0.15, CAST_MIN, CAST_MAX)
	var from := player.global_position
	var d := reach
	while d <= CAST_MAX + 3.0:
		var p := from + fwd * d
		if terrain.water_depth(p.x, p.z) >= MIN_WATER:
			return Vector3(p.x, ForestTerrain.WATER_LEVEL, p.z)
		d += 1.0
	d = reach - 1.0
	while d >= CAST_MIN:
		var p2 := from + fwd * d
		if terrain.water_depth(p2.x, p2.z) >= MIN_WATER:
			return Vector3(p2.x, ForestTerrain.WATER_LEVEL, p2.z)
		d -= 1.0
	return Vector3.INF


func _try_cast() -> void:
	if player.swimming:
		message.emit("You can't fish while swimming.")
		return
	var spot := cast_spot()
	if spot == Vector3.INF:
		message.emit("Face open water to cast.")
		return
	state = State.CAST
	_t = 0.0
	_bob = spot
	_bob_start = _tip()
	_cast_from = player.global_position
	_bite_timer = -1.0
	_quiet_t = 0.0
	_hinted = false
	_bobber.visible = true


func _land() -> void:
	if _hooked != null and is_instance_valid(_hooked):
		if catch_handler.is_valid():
			catch_handler.call(_hooked, _bob)
		else:
			var kind := _hooked.kind
			manager.catch_fish(_hooked)
			manager.splash(_bob)
			player.add_fish(kind)
			caught.emit(kind)
	cancel()


# --- update -------------------------------------------------------------------

func _process(delta: float) -> void:
	var active := player != null and player.alive and not player.god_mode and player.held == "rod"
	_pivot.visible = active
	if not active:
		if state != State.IDLE:
			cancel()
		return

	var bend := 0.0
	match state:
		State.CAST:
			_t += delta
			var k := clampf(_t / CAST_TIME, 0.0, 1.0)
			var p := _bob_start.lerp(_bob, k)
			p.y += sin(k * PI) * 3.0
			_bobber.global_position = p
			bend = -0.25 * (1.0 - k)
			if k >= 1.0:
				state = State.WAIT
				if manager.audio != null:
					manager.audio.bobber_plop(_bob)
		State.WAIT:
			if _check_leash():
				return
			bend = _wait_step(delta)
		State.BITE:
			if _check_leash():
				return
			_t -= delta
			_bobber.global_position = _bob + Vector3(0, -0.2 + sin(Time.get_ticks_msec() * 0.03) * 0.04, 0)
			bend = 0.22
			if _t <= 0.0:
				if _hooked != null and is_instance_valid(_hooked):
					_hooked.scare()
				_hooked = null
				_bite_timer = -1.0
				_scan_timer = 2.5   # the school needs a moment before the next bite
				state = State.WAIT
				message.emit("It got away...")

	_pivot.rotation.x = lerpf(_pivot.rotation.x, -(PI * 0.5 - 0.45) + bend, clampf(delta * 12.0, 0.0, 1.0))
	_draw_line()


func _check_leash() -> bool:
	var moved := Vector2(player.global_position.x - _cast_from.x, player.global_position.z - _cast_from.z).length()
	if moved > LEASH or player.swimming:
		cancel()
		message.emit("Line reeled in.")
		return true
	return false


## Idle on the water: find a fish, count down to its bite, twitch beforehand.
## Returns how much the rod tip should bend.
func _wait_step(delta: float) -> float:
	var bob_y := sin(Time.get_ticks_msec() * 0.0025) * 0.02
	var bend := 0.0

	if _hooked != null and not is_instance_valid(_hooked):
		_hooked = null
		_bite_timer = -1.0

	if _bite_timer < 0.0:
		_scan_timer -= delta
		if _scan_timer <= 0.0:
			_scan_timer = 0.5
			var f := manager.nearest_fish(_bob, BITE_RADIUS)
			if f != null:
				_hooked = f
				_bite_timer = _rng.randf_range(2.5, 7.0) * (1.5 if f.kind == "pike" else 1.0)
			else:
				_quiet_t += 0.5
				if _quiet_t > 14.0 and not _hinted:
					_hinted = true
					message.emit("Nothing's biting here. Try another spot.")
	else:
		_bite_timer -= delta
		if _bite_timer < 1.3:
			# Nibbles before the real take.
			var n := sin(Time.get_ticks_msec() * 0.018)
			if n > 0.6:
				bob_y -= 0.05
				bend = 0.06
		if _bite_timer <= 0.0:
			state = State.BITE
			_t = BITE_WINDOW
			if manager.audio != null:
				manager.audio.bobber_plop(_bob)

	_bobber.global_position = _bob + Vector3(0, bob_y, 0)
	return bend


func _draw_line() -> void:
	_line.clear_surfaces()
	if state == State.IDLE:
		return
	var a := _tip()
	var b := _bobber.global_position + Vector3(0, 0.06, 0)
	var sag := 0.0 if state == State.CAST else a.distance_to(b) * 0.07
	if state == State.BITE:
		sag = 0.0   # line snaps taut when a fish takes it
	_line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _line_mat)
	var segs := 16
	for i in segs + 1:
		var k := float(i) / segs
		var p := a.lerp(b, k)
		p.y -= sin(k * PI) * sag
		_line.surface_add_vertex(p)
	_line.surface_end()


func prompt_text() -> String:
	if player == null or not player.alive or player.god_mode or player.held != "rod":
		return ""
	match state:
		State.IDLE:
			if cast_spot() != Vector3.INF:
				return "E   cast line"
		State.CAST, State.WAIT:
			return "Waiting for a bite...    E   reel in"
		State.BITE:
			return "BITE!   Press E"
	return ""
