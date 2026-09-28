extends SceneTree

## Headless playtest: gather -> craft -> chop -> planks -> build -> weather -> bear.

var world
var p: PlayerController
var ter: ForestTerrain
var fails := 0


func _initialize() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	_run()


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		fails += 1


func stand(at: Vector3) -> void:
	p.global_position = Vector3(at.x, ter.sample_height(at.x, at.z) + 0.1, at.z)
	p.velocity = Vector3.ZERO


func aim_at(point: Vector3) -> void:
	var eye := p.global_position + Vector3(0, p.HEAD_STAND, 0)
	var d := point - eye
	p.rotation.y = atan2(-d.x, -d.z)
	p.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	p.head.rotation.x = p.pitch


func use_until(cond: Callable, tries: int) -> int:
	for i in tries:
		world._use_cd = 0.0
		world._use_tool()
		if cond.call():
			return i + 1
	return -1


func _run() -> void:
	await wait(0.5)
	p = world.player
	ter = world.terrain
	var bear: Bear = world.wildlife.bear
	bear._ignore_player_t = 1e9
	world.weather.auto = false

	# --- rocks ------------------------------------------------------------------
	print("GATHERING")
	var rocks: LooseRocks = world.rocks
	var ri := 0
	var rp := rocks.positions[ri]
	var off := Vector3(1.4, 0, 0.3)
	stand(rp + off)
	await wait(0.3)
	aim_at(rp + Vector3(0, 0.1, 0))
	check(world._prompt().begins_with("E   pick up"), "prompt offers the rock ('%s')" % world._prompt())
	world._interact()
	check(p.inv.rock == 1 and rocks.taken[ri] == 1, "picked up a rock")
	p.inv.rock = 2

	# --- branches -----------------------------------------------------------------
	var trees: TreeRegistry = world.trees
	var tid := -1
	for i in trees.trees.size():
		var tp: Vector3 = trees.position_of(i)
		var side := tp + Vector3(1.9, 0, 0)
		if ter.sample_normal(side.x, side.z).y > 0.93 and absf(ter.sample_height(side.x, side.z) - tp.y) < 0.6:
			tid = i
			break
	var tpos: Vector3 = trees.position_of(tid)
	stand(tpos + Vector3(1.9, 0, 0))
	await wait(0.3)
	aim_at(tpos + Vector3(0, 1.3, 0))
	check(trees.find_target(p.camera.global_position, -p.camera.global_transform.basis.z, 2.8) == tid,
		"crosshair finds the tree trunk")
	p.equip("rock")
	check(p.held == "rock", "holding a rock")
	var hits := use_until(func() -> bool: return p.inv.branch >= 3, 60)
	check(hits > 0, "knocked 3 branches off in %d rock hits" % hits)
	print("  prompt: " + world._prompt())

	# --- axe ------------------------------------------------------------------
	print("CRAFTING")
	world._craft(0)
	check(p.tools.has("axe") and p.held == "axe" and p.inv.branch == 0 and p.inv.rock == 1,
		"crafted a stone axe (rock %d, branches %d)" % [p.inv.rock, p.inv.branch])
	world._craft(1)
	check(p.inv.plank == 0, "can't make planks without logs")

	# --- felling -----------------------------------------------------------------
	var chops := use_until(func() -> bool: return p.inv.log > 0, 10)
	check(chops == 4 and not trees.trees[tid].alive, "tree felled in %d chops, %d logs" % [chops, p.inv.log])
	check(trees.trees[tid].collider == null, "felled tree's collider is gone")
	check(p.tools.axe == 56, "axe wore down (%d uses left)" % p.tools.axe)
	await wait(0.2)
	world._craft(1)
	check(p.inv.plank == 4, "sawed a log into 4 planks")

	# --- building ------------------------------------------------------------------
	print("BUILDING")
	var build: BuildSystem = world.build
	p.inv.plank = 60
	p.inv.branch = 20
	p.inv.rock = 5
	# Find a flat, dry cell well away from the lake.
	var cell := Vector2i.ZERO
	var found := false
	for gx in range(-30, 30):
		for gz in range(-30, 30):
			var c := Vector2i(gx, gz)
			var r: Vector2 = build._ground_range(build._cell_corners(c))
			var cc := BuildSystem.cell_center(c)
			if r.y - r.x < 0.5 and ter.is_land(cc.x, cc.z, 3.0) and ter.in_bounds(cc.x, cc.z) \
					and Vector2(cc.x, cc.z).distance_to(ter.lake_center) > ter.lake_radius + 20.0 \
					and trees.find_target(cc + Vector3(-3, 1, 0), Vector3.RIGHT, 6.0) < 0:
				cell = c
				found = true
				break
		if found:
			break
	var center := BuildSystem.cell_center(cell)
	stand(center)
	await wait(0.3)
	var x0 := cell.x * BuildSystem.CELL
	var z0 := cell.y * BuildSystem.CELL

	var place := func(kind: String, hit: Vector3) -> Dictionary:
		var plan: Dictionary = build._plan(kind, Vector3(hit.x, ter.sample_height(hit.x, hit.z), hit.z), p)
		build.plan = plan
		var s: Structure = build.try_place(p.inv)
		return {"plan": plan, "s": s}

	var roof_early: Dictionary = place.call("roof", center)
	check(roof_early.s == null and "wall" in roof_early.plan.reason, "roof refused without walls: '%s'" % roof_early.plan.reason)
	var fl: Dictionary = place.call("floor", center)
	check(fl.s != null, "floor placed")
	stand(center)
	await wait(0.3)
	var walls := []
	var edges := [Vector3(x0 + 1.5, 0, z0 + 0.2), Vector3(x0 + 1.5, 0, z0 + 2.8),
		Vector3(x0 + 0.2, 0, z0 + 1.5), Vector3(x0 + 2.8, 0, z0 + 1.5)]
	for i in 4:
		var kind := "door" if i == 1 else "wall"
		var w: Dictionary = place.call(kind, edges[i])
		check(w.s != null, "%s placed on edge %d (%s)" % [kind, i, w.plan.reason])
		walls.append(w.s)
	var dup: Dictionary = place.call("wall", edges[0])
	check(dup.s == null, "can't stack two walls on one edge ('%s')" % dup.plan.reason)
	var rf: Dictionary = place.call("roof", center)
	check(rf.s != null, "roof placed on the walls")
	var spent: int = 60 - int(p.inv.plank)
	check(spent == 3 + 4 * 3 + 5 + 4, "planks spent: %d" % spent)
	check(build.is_sheltered(p.global_position), "standing inside counts as sheltered")

	# Door via the E key and the physics ray.
	var door: Structure = walls[1]
	stand(center)
	await wait(0.3)
	aim_at(door.global_position + Vector3(0, 1.2, 0))
	print("  door prompt: " + world._prompt())
	world._interact()
	check(door.open, "E opens the door")
	world._interact()
	await wait(0.5)
	check(not door.open, "E closes it again")

	# --- weather & warmth -------------------------------------------------------------
	print("WEATHER")
	world.weather.start_rain()
	await wait(11.0)
	check(world.weather.intensity > 0.95, "rain at full strength (%.2f)" % world.weather.intensity)
	p.warmth = 60.0
	await wait(5.0)
	check(p.warmth >= 60.0, "warmth holds under the roof (%.1f)" % p.warmth)
	var outside := center + Vector3(0, 0, -8)
	stand(outside)
	p.warmth = 60.0
	await wait(5.0)
	check(p.warmth < 57.0, "rain chills you outside (%.1f)" % p.warmth)

	# Campfire
	var fire: Dictionary = {}
	for off2 in [Vector3(0, 0, -9), Vector3(0, 0, 9), Vector3(-9, 0, 0), Vector3(9, 0, 3), Vector3(-6, 0, -6)]:
		fire = place.call("campfire", center + off2)
		if fire.s != null:
			break
	check(fire.s != null and fire.s.is_lit(), "campfire built and lit (%s)" % fire.plan.reason)
	if fire.s == null:
		quit(1)
		return
	stand(fire.s.global_position + Vector3(1.5, 0, 0))
	p.warmth = 40.0
	await wait(3.0)
	check(p.fire_heat > 0.0 and p.warmth > 45.0, "fire warms you even in the rain (%.1f)" % p.warmth)

	# Lean-to
	var lt: Dictionary = place.call("leanto", center + Vector3(6, 0, 0))
	check(lt.s != null, "lean-to built (%s)" % lt.plan.reason)
	if lt.s != null:
		stand(lt.s.global_position)
		await wait(0.2)
		check(build.is_sheltered(p.global_position), "under the lean-to counts as sheltered")
	world.weather.stop_rain()

	# Freezing
	p.warmth = 0.0
	stand(center + Vector3(24, 0, 24))
	world.weather.start_rain()
	var hp0: float = p.health
	await wait(2.0)
	check(p.health < hp0, "at zero warmth you start freezing (%.1f -> %.1f)" % [hp0, p.health])
	world.weather.stop_rain()
	p.health = 100.0
	p.warmth = 100.0

	# --- bear vs walls -----------------------------------------------------------------
	print("BEAR VS CABIN")
	stand(center)
	await wait(0.3)
	var lost := [""]
	bear.lost_player.connect(func(r: String, _p: Node3D) -> void: lost[0] = r)
	bear._ignore_player_t = 0.0
	var bp := center + Vector3(10, 0, 0)
	bear.global_position = Vector3(bp.x, ter.sample_height(bp.x, bp.z), bp.z)
	bear._ground_y = bear.global_position.y
	var total_hp_before := 0.0
	for w in walls:
		total_hp_before += w.hp
	var t := 0.0
	while t < 22.0 and lost[0] == "":
		await wait(0.25)
		t += 0.25
	var total_hp_after := 0.0
	for w in walls:
		if is_instance_valid(w):
			total_hp_after += w.hp
	print("  after %.1f s: player hp %.0f, wall hp %.0f -> %.0f, bear gave up: '%s'" % [
		t, p.health, total_hp_before, total_hp_after, lost[0]])
	check(p.health == 100.0, "the bear can't hurt you inside the cabin")
	check(total_hp_after < total_hp_before, "the bear clawed at the walls")
	check(lost[0] == "walls", "the bear gives up on a closed cabin")
	var inside_d: float = Vector2(bear.global_position.x, bear.global_position.z).distance_to(Vector2(center.x, center.z))
	check(inside_d > 1.8, "the bear stayed outside (%.1f m from the centre)" % inside_d)

	# Open door lets it in.
	door.set_open(true)
	await wait(0.4)
	var me := Vector2(center.x, center.z)
	var through := Vector2(door.global_position.x, door.global_position.z) + (Vector2(door.global_position.x, door.global_position.z) - me)
	check(build.blocking(through, me, 0.3) == null, "an open door leaves a gap in the wall")
	door.set_open(false)

	# Destruction frees the slot.
	var w0: Structure = walls[0]
	var key: String = w0.slot_key
	build.damage(w0, 99999.0)
	await wait(0.1)
	check(not build.slots.has(key), "a destroyed wall frees its edge")

	print("\n%s (%d failed)" % ["ALL PASSED" if fails == 0 else "FAILURES", fails])
	quit(1 if fails > 0 else 0)
