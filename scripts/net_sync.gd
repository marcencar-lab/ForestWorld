class_name NetSync
extends Node

## Online play. One player hosts; the host's game runs the world (wildlife,
## weather, time, buildings, trees, loot) and everyone else mirrors it.
## Each player simulates their own body and vitals and reports where they are.
##
## Changes to the shared world go through the host: clients ask with
## request(), the host applies them in World._do() and broadcasts the result.
## This node must sit at the same path on every machine (/root/World/Net).

signal status_changed(text)

const PLAYER_RATE := 0.05      # seconds between our position updates
const WILD_RATE := 0.1         # host: seconds between wildlife snapshots
const ENV_RATE := 1.0          # host: time of day / weather

var world: Node3D
var peers := {}                # peer id -> {"name": String, "avatar": RemotePlayer}
var status := ""
var external_ip := ""
var lan_ip := ""

var _player_t := 0.0
var _wild_t := 0.0
var _env_t := 0.0
var _upnp: UPNP
var _upnp_thread: Thread
var _joined := false


func is_online() -> bool:
	return Session.online()


func is_host() -> bool:
	return Session.mode == "host"


func is_client() -> bool:
	return Session.mode == "client"


func my_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


func player_count() -> int:
	return peers.size() + 1


# --- connection ---------------------------------------------------------------

func start() -> void:
	if not is_online():
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)

	var peer := ENetMultiplayerPeer.new()
	if is_host():
		var err := peer.create_server(Session.port, Session.MAX_PLAYERS)
		if err != OK:
			_back_to_menu("Couldn't host on port %d (is another copy already hosting?)" % Session.port)
			return
		multiplayer.multiplayer_peer = peer
		lan_ip = _lan_address()
		if Session.use_upnp:
			_set_status("Hosting on port %d. Opening your router..." % Session.port)
			_upnp_thread = Thread.new()
			_upnp_thread.start(_open_port)
		else:
			_port_result(false, "")
	else:
		var err2 := peer.create_client(Session.address, Session.port)
		if err2 != OK:
			_back_to_menu("Couldn't reach %s:%d" % [Session.address, Session.port])
			return
		multiplayer.multiplayer_peer = peer
		_set_status("Connecting to %s:%d..." % [Session.address, Session.port])


func _set_status(t: String) -> void:
	status = t
	status_changed.emit(t)


func _lan_address() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and a.count(".") == 3):
			return a
	return ""


## Runs on a thread: ask the router to forward our port (UPnP).
func _open_port() -> void:
	_upnp = UPNP.new()
	var ok := false
	var ext := ""
	if _upnp.discover(2500, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS:
		var gw := _upnp.get_gateway()
		if gw != null and gw.is_valid_gateway():
			if _upnp.add_port_mapping(Session.port, Session.port, "Forest World", "UDP") == UPNP.UPNP_RESULT_SUCCESS:
				ok = true
			ext = _upnp.query_external_address()
	call_deferred("_port_result", ok, ext)


func _port_result(ok: bool, ext: String) -> void:
	external_ip = ext
	if ok and ext != "":
		_set_status("Hosting. Friends join with  %s:%d" % [ext, Session.port])
	elif lan_ip != "":
		_set_status("Hosting. Same Wi-Fi: %s:%d  (router didn't open the port - see README for internet play)" % [lan_ip, Session.port])
	else:
		_set_status("Hosting on port %d (router didn't open the port - see README)" % Session.port)


func _exit_tree() -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
	if _upnp != null and is_host() and external_ip != "":
		_upnp.delete_port_mapping(Session.port, "UDP")
	if is_online() and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null


func _back_to_menu(msg: String) -> void:
	Session.menu_message = msg
	Session.mode = "single"
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	get_tree().call_deferred("change_scene_to_file", "res://scenes/menu.tscn")


func _on_connected() -> void:
	_set_status("Connected. Joining the world...")
	_rpc_hello.rpc_id(1, Session.player_name)


func _on_connect_failed() -> void:
	_back_to_menu("Couldn't connect to %s:%d. Check the address, and that the host's port is open." % [Session.address, Session.port])


func _on_server_gone() -> void:
	_back_to_menu("The host closed the game or the connection dropped.")


func _on_peer_connected(_id: int) -> void:
	pass   # wait for their hello


func _on_peer_disconnected(id: int) -> void:
	_remove_peer(id)
	if is_host():
		_rpc_player_left.rpc(id)


func _add_peer(id: int, pname: String) -> void:
	if id == my_id() or peers.has(id):
		return
	var av := RemotePlayer.new()
	av.name = "Remote_%d" % id
	world.add_child(av)
	av.setup(id, pname, self)
	peers[id] = {"name": pname, "avatar": av}
	world.hud.toast("%s joined the game" % pname)


func _remove_peer(id: int) -> void:
	if not peers.has(id):
		return
	var info: Dictionary = peers[id]
	peers.erase(id)
	if is_instance_valid(info.avatar):
		info.avatar.queue_free()
	world.hud.toast("%s left the game" % info.name)


func avatar(id: int) -> RemotePlayer:
	if peers.has(id):
		return peers[id].avatar
	return null


## Where a given player is standing (for hits, reach checks...).
func position_of(id: int) -> Vector3:
	if id == my_id():
		return world.player.global_position
	var av := avatar(id)
	return av.global_position if av != null else Vector3.INF


# --- handshake ------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(pname: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	_add_peer(id, pname)
	# Tell the newcomer about everyone already here, and everyone about them.
	_rpc_player_joined.rpc_id(id, 1, Session.player_name)
	for pid in peers:
		if pid != id:
			_rpc_player_joined.rpc_id(id, pid, peers[pid].name)
			_rpc_player_joined.rpc_id(pid, id, pname)
	_rpc_welcome.rpc_id(id, world.snapshot_world())


@rpc("authority", "call_remote", "reliable")
func _rpc_player_joined(id: int, pname: String) -> void:
	_add_peer(id, pname)


@rpc("authority", "call_remote", "reliable")
func _rpc_player_left(id: int) -> void:
	_remove_peer(id)


@rpc("authority", "call_remote", "reliable")
func _rpc_welcome(state: Dictionary) -> void:
	world.apply_world(state)
	_joined = true
	_set_status("Playing online with %s" % _host_name())


func _host_name() -> String:
	return peers[1].name if peers.has(1) else "the host"


# --- per-frame syncing --------------------------------------------------------

func _process(delta: float) -> void:
	if not is_online() or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if is_client() and not _joined:
		return

	_player_t -= delta
	if _player_t <= 0.0:
		_player_t = PLAYER_RATE
		var p: PlayerController = world.player
		var flags := (1 if p.alive else 0) | (2 if p.crouching else 0) | (4 if p.swimming else 0)
		_rpc_pstate.rpc(p.global_position, p.rotation.y, p.pitch, flags, p.noise_level(), p.scent_bonus(), p.held)

	if is_host() and not peers.is_empty():
		_wild_t -= delta
		if _wild_t <= 0.0:
			_wild_t = WILD_RATE
			var snap: Array = world.wildlife.snapshot()
			_rpc_wild.rpc(snap[0], snap[1], snap[2])
		_env_t -= delta
		if _env_t <= 0.0:
			_env_t = ENV_RATE
			_rpc_env.rpc(world.tod_hours, world.day, world.weather.raining)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_pstate(pos: Vector3, yaw: float, pitch: float, flags: int, noise: float, scent: float, held: String) -> void:
	var av := avatar(multiplayer.get_remote_sender_id())
	if av != null:
		av.apply_state(pos, yaw, pitch, flags, noise, scent, held)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_wild(animals: PackedFloat32Array, bear: PackedFloat32Array, fish: PackedFloat32Array) -> void:
	world.wildlife.apply_snapshot(animals, bear, fish, my_id())


@rpc("authority", "call_remote", "reliable")
func _rpc_env(tod: float, day: int, raining: bool) -> void:
	world.apply_env(tod, day, raining)


# --- requests and results -----------------------------------------------------

## Client -> host: please change the shared world.
func request(action: String, args: Array) -> void:
	_rpc_act.rpc_id(1, action, args)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_act(action: String, args: Array) -> void:
	if is_host():
		world._do(multiplayer.get_remote_sender_id(), action, args)


## Host -> one player: you got something.
func give(peer: int, item: String, n: int, msg: String) -> void:
	_rpc_give.rpc_id(peer, item, n, msg)


@rpc("authority", "call_remote", "reliable")
func _rpc_give(item: String, n: int, msg: String) -> void:
	world.receive(item, n, msg)


func send_msg(peer: int, text: String) -> void:
	_rpc_give.rpc_id(peer, "", 0, text)


func send_hurt(peer: int, amount: float, from: Vector3) -> void:
	_rpc_hurt.rpc_id(peer, amount, from)


@rpc("authority", "call_remote", "reliable")
func _rpc_hurt(amount: float, from: Vector3) -> void:
	world.player.take_damage(amount, from)


## Host -> everyone: something in the world changed. `event` names a
## World._on_net_event case.
func broadcast(event: String, args: Array) -> void:
	if is_host() and not peers.is_empty():
		_rpc_event.rpc(event, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_event(event: String, args: Array) -> void:
	world._on_net_event(event, args)


## Sounds and particles from the host's simulation (animal calls, splashes...).
func broadcast_fx(kind: String, a: String, pos: Vector3) -> void:
	if is_host() and not peers.is_empty():
		_rpc_fx.rpc(kind, a, pos)


@rpc("authority", "call_remote", "unreliable")
func _rpc_fx(kind: String, a: String, pos: Vector3) -> void:
	world._on_net_fx(kind, a, pos)
