extends SceneTree

## Multiplayer playtest, host side. Start this first, then tests/mp_client.gd:
##   godot --path . --headless --fixed-fps 60 -s tests/mp_host.gd
##   godot --path . --headless --fixed-fps 60 -s tests/mp_client.gd

const PORT := 24555

var world
var fails := 0


func _initialize() -> void:
	Session.mode = "host"
	Session.port = PORT
	Session.player_name = "HostPlayer"
	Session.use_upnp = false
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	_run()


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + "[host] " + what)
	if not ok:
		fails += 1


func wait_for(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await wait(0.2)
		t += 0.2
	return cond.call()


func _run() -> void:
	await wait(0.5)
	var net: NetSync = world.net
	var p: PlayerController = world.player
	world.weather.auto = false
	world.wildlife.bear._ignore_player_t = 1e9
	# Park the host player out of the way.
	p.set_god_mode(false)
	print("[host] listening on %d" % PORT)

	var joined := await wait_for(func() -> bool: return not net.peers.is_empty(), 60.0)
	check(joined, "a client joined")
	if not joined:
		quit(1)
		return
	var pid: int = net.peers.keys()[0]
	var av: RemotePlayer = net.avatar(pid)
	check(av != null and av.player_name == "ClientPlayer", "remote player avatar created with their name")
	var moved := await wait_for(func() -> bool: return av._has_state, 10.0)
	check(moved, "receiving the client's position (%s)" % av.global_position)

	var rocks_before: int = world.rocks.taken.count(1)
	var trees_before: int = world.trees.felled_ids().size()
	var pieces_before: int = world.build.structures.size()

	# The client picks up a rock, builds a wall, fells a tree and loots a crate.
	check(await wait_for(func() -> bool: return world.rocks.taken.count(1) > rocks_before, 40.0),
		"client's rock pickup went through the host")
	check(await wait_for(func() -> bool: return world.build.structures.size() > pieces_before, 30.0),
		"client's wall exists in the host's world")
	check(await wait_for(func() -> bool: return world.trees.felled_ids().size() > trees_before, 30.0),
		"client felled a tree on the host")
	var looted := func() -> bool:
		for s in world.ruins.sites:
			for c in s.crates:
				if c.looted:
					return true
		return false
	check(await wait_for(looted, 30.0), "client looted a crate on the host")

	# Send the bear after the client (once they've stepped outside).
	await wait(2.5)
	var bear: Bear = world.wildlife.bear
	bear._ignore_player_t = 0.0
	var ap := av.global_position
	var bp := ap + Vector3(5, 0, 0)
	bear.global_position = Vector3(bp.x, world.terrain.sample_height(bp.x, bp.z), bp.z)
	bear._ground_y = bear.global_position.y
	bear.velocity = Vector3.ZERO
	bear.state = Bear.State.PATROL
	bear.target = null
	var targeted := await wait_for(func() -> bool: return bear.target == av, 5.0)
	check(targeted, "the bear hunts the remote player")
	var struck := [false]
	bear.struck.connect(func(v: Node3D, _at: Vector3) -> void:
		if v == av:
			struck[0] = true)
	check(await wait_for(func() -> bool: return struck[0], 15.0), "the bear swiped at the remote player")

	# Wait for the client to finish and disconnect.
	await wait_for(func() -> bool: return net.peers.is_empty(), 40.0)
	check(net.peers.is_empty(), "client left cleanly and the avatar was removed")
	print("\n[host] %s (%d failed)" % ["ALL PASSED" if fails == 0 else "FAILURES", fails])
	quit(1 if fails > 0 else 0)
