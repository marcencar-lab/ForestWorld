extends SceneTree

## Multiplayer playtest, client side. Start tests/mp_host.gd first.

const PORT := 24555

var world
var p: PlayerController
var ter: ForestTerrain
var fails := 0


func _initialize() -> void:
	Session.mode = "client"
	Session.address = "127.0.0.1"
	Session.port = PORT
	Session.player_name = "ClientPlayer"
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	_run()


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + "[client] " + what)
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


func aim_at(point: Vector3) -> void:
	var eye := p.global_position + Vector3(0, p.HEAD_STAND, 0)
	var d := point - eye
	p.rotation.y = atan2(-d.x, -d.z)
	p.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	p.head.rotation.x = p.pitch


func put(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO


func _run() -> void:
	await wait(0.5)
	p = world.player
	ter = world.terrain
	var net: NetSync = world.net
	var joined := await wait_for(func() -> bool: return net._joined, 30.0)
	check(joined, "connected and received the world")
	if not joined:
		quit(1)
		return
	check(net.peers.has(1) and net.peers[1].name == "HostPlayer", "sees the host player")
	var wl: WildlifeManager = world.wildlife
	check(await wait_for(func() -> bool: return wl.animals.size() > 30 and wl.fish.size() > 60, 5.0),
		"wildlife mirrored from the host (%d animals, %d fish)" % [wl.animals.size(), wl.fish.size()])
	check(wl.bear != null and wl.bear.puppet, "the bear is a mirror of the host's")
	check(world.build.structures.size() > 40, "ruins arrived with the world (%d pieces)" % world.build.structures.size())
	check("cabin" in world._compass(), "compass still points to a cabin after the world sync")

	# Rock
	var ri := -1
	for i in world.rocks.positions.size():
		if world.rocks.taken[i] == 0:
			ri = i
			break
	var rp: Vector3 = world.rocks.positions[ri]
	put(rp + Vector3(1.4, 0.3, 0.3))
	await wait(0.3)
	aim_at(rp + Vector3(0, 0.1, 0))
	world._interact()
	check(await wait_for(func() -> bool: return int(p.inv.rock) == 1, 5.0), "picked up a rock (host confirmed)")
	check(world.rocks.taken[ri] == 1, "the rock is gone locally too")

	# Wall
	var build: BuildSystem = world.build
	p.inv.plank = 10
	var spot := Vector3.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 400:
		var c := ter.random_walkable_point(rng, 20)
		if c != Vector3.ZERO and ter.sample_normal(c.x, c.z).y > 0.97 and ter.is_land(c.x, c.z, 4.0):
			spot = c
			break
	put(spot + Vector3(0, 0.3, 0))
	await wait(0.3)
	var hit := spot + Vector3(1.0, 0, 1.0)
	var plan: Dictionary = build._plan("wall", Vector3(hit.x, ter.sample_height(hit.x, hit.z), hit.z), p)
	build.plan = plan
	world._place_piece()
	check(await wait_for(func() -> bool: return build.slots.has(plan.key), 5.0),
		"built a wall (%s)" % ("placed" if build.slots.has(plan.key) else plan.reason))
	check(int(p.inv.plank) == 6, "planks spent (%d left)" % p.inv.plank)

	# Tree
	var trees: TreeRegistry = world.trees
	var tid := -1
	for i in trees.trees.size():
		if not trees.trees[i].alive:
			continue
		var tp: Vector3 = trees.position_of(i)
		var side := tp + Vector3(1.9, 0, 0)
		if ter.sample_normal(side.x, side.z).y > 0.93 and absf(ter.sample_height(side.x, side.z) - tp.y) < 0.6:
			tid = i
			break
	var tpos: Vector3 = trees.position_of(tid)
	put(Vector3(tpos.x + 1.9, ter.sample_height(tpos.x + 1.9, tpos.z) + 0.2, tpos.z))
	await wait(0.4)
	aim_at(tpos + Vector3(0, 1.3, 0))
	p.add_item("hatchet")
	p.equip("hatchet")
	for i in 4:
		world._use_cd = 0.0
		world._use_tool()
		await wait(0.2)
	check(await wait_for(func() -> bool: return int(p.inv.log) > 0, 5.0), "felled a tree (%d logs)" % p.inv.log)
	check(not trees.trees[tid].alive, "the tree came down locally")

	# Crate
	var crate: Structure = null
	for s in build.structures:
		if s.kind == "crate" and not s.looted:
			crate = s
			break
	var at: Vector3 = crate.global_position + Vector3(1.2, 0.1, 0)
	put(at)
	await wait(0.3)
	var found_ray := false
	for off in [Vector3(1.2, 0, 0), Vector3(-1.2, 0, 0), Vector3(0, 0, 1.2), Vector3(0, 0, -1.2)]:
		put(crate.global_position + off + Vector3(0, 0.1, 0))
		await wait(0.15)
		aim_at(crate.global_position + Vector3(0, 0.3, 0))
		if world._structure_target() == crate:
			found_ray = true
			break
	world._interact()
	check(await wait_for(func() -> bool: return crate.looted, 5.0), "looted a crate (host confirmed)")

	# Out into the open and stand still: the host sends the bear.
	put(spot + Vector3(-7, 0.3, -7))
	await wait(0.2)
	var hp0 := p.health
	check(await wait_for(func() -> bool: return p.health < hp0, 25.0), "the host's bear hurt us (%.0f hp)" % p.health)
	check(p.bleeding > 0.0, "and we're bleeding")

	print("\n[client] %s (%d failed)" % ["ALL PASSED" if fails == 0 else "FAILURES", fails])
	quit(1 if fails > 0 else 0)
