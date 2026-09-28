class_name RemotePlayer
extends Node3D

## Another person in the game, as seen on this machine. Moves smoothly toward
## the last state they sent. On the host it also stands in for them in the
## bear's senses: noise, scent, and taking hits (forwarded to their machine).

var peer_id := 0
var player_name := ""
var alive := true
var god_mode := false
var swimming := false
var crouching := false
var noise := 1.0
var scent := 0.0
var held := ""
var net: NetSync

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _pitch := 0.0
var _has_state := false
var _body: Node3D
var _head: Node3D
var _label: Label3D
var _item: MeshInstance3D
var _bob := 0.0

const COLORS := [Color(0.80, 0.33, 0.25), Color(0.25, 0.50, 0.80), Color(0.85, 0.70, 0.25),
	Color(0.45, 0.70, 0.35), Color(0.65, 0.40, 0.75), Color(0.30, 0.70, 0.70), Color(0.85, 0.50, 0.60)]


func setup(id: int, name_text: String, n: NetSync) -> void:
	peer_id = id
	player_name = name_text
	net = n
	add_to_group("players")
	var col: Color = COLORS[absi(id) % COLORS.size()]

	_body = Node3D.new()
	add_child(_body)
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.35
	torso.mesh = cap
	torso.material_override = CritterBuilder.material(col, 0.8)
	torso.position = Vector3(0, 0.78, 0)
	_body.add_child(torso)
	var legs := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.42, 0.5, 0.26)
	legs.mesh = lb
	legs.material_override = CritterBuilder.material(Color(0.22, 0.24, 0.28), 0.9)
	legs.position = Vector3(0, 0.25, 0)
	_body.add_child(legs)

	_head = Node3D.new()
	_head.position = Vector3(0, 1.62, 0)
	_body.add_child(_head)
	var skull := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.17
	sm.height = 0.34
	skull.mesh = sm
	skull.material_override = CritterBuilder.material(Color(0.86, 0.72, 0.60), 0.7)
	_head.add_child(skull)
	var hat := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.12
	hm.bottom_radius = 0.2
	hm.height = 0.12
	hat.mesh = hm
	hat.material_override = CritterBuilder.material(col.darkened(0.3), 0.8)
	hat.position = Vector3(0, 0.15, 0)
	_head.add_child(hat)
	# Nose so you can tell which way they're facing.
	var nose := MeshInstance3D.new()
	var nb := BoxMesh.new()
	nb.size = Vector3(0.05, 0.05, 0.08)
	nose.mesh = nb
	nose.material_override = skull.material_override
	nose.position = Vector3(0, -0.02, -0.18)
	_head.add_child(nose)

	_item = MeshInstance3D.new()
	var ib := BoxMesh.new()
	ib.size = Vector3(0.05, 0.05, 0.6)
	_item.mesh = ib
	_item.material_override = CritterBuilder.material(Color(0.45, 0.32, 0.19), 0.8)
	_item.position = Vector3(0.32, 1.0, -0.3)
	_body.add_child(_item)

	_label = Label3D.new()
	_label.text = player_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0022
	_label.font_size = 28
	_label.outline_size = 8
	_label.position = Vector3(0, 2.15, 0)
	add_child(_label)


func is_alive() -> bool:
	return alive


func noise_level() -> float:
	return noise


func scent_bonus() -> float:
	return scent


## Only happens on the host: pass the blow on to that player's own game.
func take_damage(amount: float, from: Vector3) -> void:
	if net != null and alive:
		net.send_hurt(peer_id, amount, from)


func apply_state(pos: Vector3, yaw: float, pitch: float, flags: int, n: float, sc: float, item: String) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_pitch = pitch
	alive = flags & 1 != 0
	crouching = flags & 2 != 0
	swimming = flags & 4 != 0
	noise = n
	scent = sc
	held = item
	if not _has_state:
		_has_state = true
		global_position = pos
		rotation.y = yaw


func _process(delta: float) -> void:
	if not _has_state:
		return
	var prev := global_position
	global_position = global_position.lerp(_target_pos, clampf(delta * 12.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(delta * 12.0, 0.0, 1.0))
	_head.rotation.x = lerpf(_head.rotation.x, clampf(_pitch, -0.8, 0.8), clampf(delta * 10.0, 0.0, 1.0))
	var speed := (global_position - prev).length() / maxf(delta, 0.0001)
	_bob += delta * speed * 2.2
	_body.position.y = absf(sin(_bob)) * 0.05 * clampf(speed / 5.0, 0.0, 1.0)
	var lie := 0.0 if alive else 1.4
	_body.rotation.z = lerpf(_body.rotation.z, lie, clampf(delta * 4.0, 0.0, 1.0))
	var crouch_scale := 0.72 if crouching else 1.0
	_body.scale.y = lerpf(_body.scale.y, crouch_scale, clampf(delta * 10.0, 0.0, 1.0))
	_item.visible = held != "" and held != "rod"
	_label.text = player_name if alive else player_name + " (down)"
