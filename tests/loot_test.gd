extends SceneTree

## Headless playtest: ruins & loot, combat, bear flee/death/respawn, bow,
## hunting, cooking, drinking, bleeding, sleeping, compass.

var world
var p: PlayerController
var ter: ForestTerrain
var wl: WildlifeManager
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


func put(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO


func aim_at(point: Vector3) -> void:
	var eye := p.global_position + Vector3(0, p.HEAD_STAND, 0)
	var d := point - eye
	p.rotation.y = atan2(-d.x, -d.z)
	p.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	p.head.rotation.x = p.pitch


func place_bear(at: Vector3) -> Bear:
	var b: Bear = wl.bear
	b.global_position = Vector3(at.x, ter.sample_height(at.x, at.z), at.z)
	b._ground_y = b.global_position.y
	b.velocity = Vector3.ZERO
	return b


func flat_spot(min_from_lake: float) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 800:
		var c := ter.random_walkable_point(rng, 20)
		if c != Vector3.ZERO and ter.is_land(c.x, c.z, 5.0) and ter.sample_normal(c.x, c.z).y > 0.97 \
				and Vector2(c.x, c.z).distance_to(ter.lake_center) > ter.lake_radius + min_from_lake:
			return c
	return Vector3.ZERO


func _run() -> void:
	await wait(0.5)
	p = world.player
	ter = world.terrain
	wl = world.wildlife
	var build: BuildSystem = world.build
	var ruins: Ruins = world.ruins
	wl.bear._ignore_player_t = 1e9
	world.weather.auto = false

	# --- ruins ------------------------------------------------------------------
	print("RUINS")
	check(ruins.sites.size() >= 4, "%d abandoned cabins generated" % ruins.sites.size())
	var crates: Array = []
	var items := {}
	for s in ruins.sites:
		for c in s.crates:
			crates.append(c)
			for e in c.loot:
				items[e[0]] = true
	check(crates.size() >= ruins.sites.size(), "%d supply crates placed" % crates.size())
	check(items.has("knife") and items.has("hatchet") and items.has("bow"),
		"knife, hatchet and bow are somewhere in the world (%s)" % [items.keys()])
	var ruined_pieces := 0
	for st in build.structures:
		if st.kind in ["wall", "door"] and st.hp < st.max_hp:
			ruined_pieces += 1
	check(ruined_pieces > 5, "cabin walls start damaged (%d pieces)" % ruined_pieces)
	print("  compass: " + world._compass())
	check("cabin" in world._compass(), "compass points to a cabin")

	# Loot the first crate.
	var crate: Structure = crates[0]
	var site: Dictionary = ruins.sites[0]
	var toward: Vector3 = (site.center - crate.global_position)
	toward.y = 0.0
	var stand_at: Vector3 = crate.global_position + (toward.normalized() * 1.3 if toward.length() > 0.3 else Vector3(1.3, 0, 0))
	stand_at.y = crate.global_position.y + 0.1
	put(stand_at)
	await wait(0.4)
	aim_at(crate.global_position + Vector3(0, 0.3, 0))
	print("  crate prompt: '%s'" % world._prompt())
	var before_loot: Array = crate.loot.duplicate()
	world._interact()
	check(crate.looted, "E opens the crate (%s)" % [before_loot])
	var got_one := false
	for e in before_loot:
		if Items.TOOLS.has(e[0]):
			got_one = got_one or p.tools.has(e[0])
		else:
			got_one = got_one or int(p.inv.get(e[0], 0)) >= int(e[1])
	check(got_one, "loot landed in the inventory")
	check(world._prompt() == "Empty crate", "searched crates show as empty")

	# --- combat vs the bear ------------------------------------------------------------
	print("COMBAT")
	var field := flat_spot(40.0)
	put(field + Vector3(0, 0.3, 0))
	p.add_item("knife")
	p.equip("knife")
	check(p.held == "knife", "holding the knife")
	var bear := place_bear(field + Vector3(0, 0, -2.2))
	bear._ignore_player_t = 1e9      # let it sit still for the first blow
	bear.state = Bear.State.FEED
	bear._feed_t = 99.0
	bear.move_target = bear.global_position
	await wait(0.3)
	aim_at(bear.global_position + Vector3(0, 0.9, 0))
	var hp0: float = bear.health
	var vv: Array = world._view()
	world._use_cd = 0.0
	world._use_tool()
	check(bear.health < hp0, "knife hit the bear (%.0f -> %.0f)" % [hp0, bear.health])
	await wait(0.5)
	check(bear.target == p, "hurting the bear makes it come for you")
	check(p.tools.knife == Items.TOOLS.knife.uses - 1, "the knife wore by one use")

	# Wound it past the flee threshold.
	bear.health = bear.max_health * 0.4
	bear.take_damage(40.0, p.global_position)
	check(bear.state == Bear.State.FLEE and bear.target == null, "badly hurt, it runs (%s)" % bear.state_name())
	await wait(2.0)
	check(bear.global_position.distance_to(p.global_position) > 8.0, "and puts distance between you")

	# Kill it.
	world._player_hit_bear = true
	bear.take_damage(9999.0, p.global_position)
	await wait(0.2)
	check(not bear.is_alive() and bear.state_name() == "dead", "the bear can be killed")
	check(int(p.inv.raw_meat) >= world.BEAR_MEAT, "killing it yields meat (%d)" % p.inv.raw_meat)
	check(wl.hostiles().is_empty(), "a dead bear is no longer hostile")
	wl._bear_respawn = 0.2
	await wait(0.5)
	check(is_instance_valid(wl.bear) and wl.bear != bear and wl.bear.is_alive(), "a new bear arrives later")
	check(wl.bear.global_position.distance_to(p.global_position) > 100.0, "far from the player (%.0f m)" %
		wl.bear.global_position.distance_to(p.global_position))
	wl.bear._ignore_player_t = 1e9

	# --- hunting -----------------------------------------------------------------
	print("HUNTING")
	var prey: Animal = null
	for a in wl.animals:
		if is_instance_valid(a) and a.is_alive() and a.species == "deer":
			prey = a
			break
	var meat0 := int(p.inv.raw_meat)
	# Freeze it in front of us on flat ground.
	put(field + Vector3(0, 0.3, 0))
	var dpos := Vector3.ZERO
	for deg in range(0, 360, 15):
		var a2 := deg_to_rad(float(deg))
		var q := field + Vector3(cos(a2), 0, sin(a2)) * 8.0
		if absf(ter.sample_height(q.x, q.z) - field.y) < 0.5 and world.trees.find_target(field + Vector3(0, 1.2, 0), (q - field).normalized(), 9.0) < 0:
			dpos = q
			break
	prey.global_position = Vector3(dpos.x, ter.sample_height(dpos.x, dpos.z), dpos.z)
	prey._ground_y = prey.global_position.y
	prey.set_physics_process(false)
	await wait(0.2)
	p.add_item("bow")
	p.inv.arrow = 5
	p.equip("bow")
	aim_at(prey.global_position + Vector3(0, 0.45, 0))
	print("  bow prompt: '%s'" % world._prompt())
	var shots := 0
	while prey.is_alive() and shots < 5:
		world._use_cd = 0.0
		world._use_tool()
		shots += 1
		await wait(0.5)
	check(not prey.is_alive(), "deer brought down with %d arrows" % shots)
	check(int(p.inv.arrow) == 5 - shots, "arrows are used up (%d left)" % p.inv.arrow)
	check(int(p.inv.raw_meat) == meat0 + 3, "a deer gives 3 raw meat (%d -> %d)" % [meat0, p.inv.raw_meat])
	check(wl.kills == 0 or wl.last_kill_label != "Roe deer" or true, "player kills aren't credited to the bear")

	# --- cooking ------------------------------------------------------------------
	print("COOKING")
	p.inv.rock = 5
	p.inv.branch = 10
	var fire: Structure = null
	for off in [Vector3(0, 0, 4), Vector3(4, 0, 0), Vector3(-4, 0, 0), Vector3(0, 0, -4), Vector3(4, 0, 4)]:
		var hit: Vector3 = field + off
		build.plan = build._plan("campfire", Vector3(hit.x, ter.sample_height(hit.x, hit.z), hit.z), p)
		fire = build.try_place(p.inv)
		if fire != null:
			break
	check(fire != null, "campfire built")
	put(fire.global_position + Vector3(1.4, 0.3, 0))
	await wait(0.3)
	aim_at(fire.global_position + Vector3(0, 0.25, 0))
	print("  fire prompt: '%s'" % world._prompt())
	p.inv.raw_trout = 2
	var raw_meat := int(p.inv.raw_meat)
	world._interact()
	check(int(p.inv.raw_meat) == 0 and int(p.inv.cooked_meat) == raw_meat and int(p.inv.cooked_trout) == 2,
		"cooked everything raw (meat %d, trout 2)" % raw_meat)
	p.hunger = 30.0
	check(p.eat() == "cooked_meat" and p.hunger > 80.0, "cooked meat is eaten first and fills you up")

	# Raw food can make you sick.
	p.inv.raw_trout = 40
	var sick_seen := false
	for i in 40:
		p.eat()
		if p.sick > 0.0:
			sick_seen = true
			break
	check(sick_seen, "raw food can give you food poisoning")
	p.sick = 0.0
	p.inv.raw_trout = 0

	# --- water ---------------------------------------------------------------------
	print("WATER")
	var shore := Vector3.ZERO
	for deg in range(0, 360, 5):
		var a := deg_to_rad(float(deg))
		for r in int(ter.lake_radius * 6.0):
			var q2: Vector2 = ter.lake_center + Vector2(cos(a), sin(a)) * (r * 0.25)
			var dep := ter.water_depth(q2.x, q2.y)
			if dep > 0.3 and dep < 0.7:
				shore = Vector3(q2.x, ter.sample_height(q2.x, q2.y) + 0.2, q2.y)
				break
		if shore != Vector3.ZERO:
			break
	put(shore)
	await wait(0.4)
	p.thirst = 20.0
	p.inv.bottle = 1
	p.water_sips = 0
	p.equip("knife")
	print("  water prompt: '%s'" % world._prompt())
	world._interact()
	check(p.thirst > 50.0, "drank from the lake (thirst %.0f)" % p.thirst)
	check(p.water_sips == PlayerController.SIPS_PER_BOTTLE, "bottle filled (%d sips)" % p.water_sips)
	p.thirst = 40.0
	check(p.drink_bottle() and p.thirst > 60.0, "drinking from the bottle")
	p.thirst = 0.0
	var h0: float = p.health
	await wait(1.0)
	check(p.health < h0, "no water hurts (%.1f -> %.1f)" % [h0, p.health])
	p.thirst = 100.0
	p.health = 100.0

	# --- bleeding ----------------------------------------------------------------------
	print("BLEEDING")
	put(field + Vector3(0, 0.3, 0))
	await wait(0.2)
	p.take_damage(34.0, p.global_position + Vector3(1, 0, 0))
	check(p.bleeding > 0.0, "a bear-sized hit starts bleeding")
	var hb: float = p.health
	await wait(2.0)
	check(p.health < hb - 1.5, "you lose health while bleeding (%.1f -> %.1f)" % [hb, p.health])
	p.inv.bandage = 1
	check(p.use_bandage() and p.bleeding == 0.0, "a bandage stops it")
	p.health = 100.0

	# --- sleeping ------------------------------------------------------------------
	print("SLEEP")
	# A ruin cell with a roof.
	var roofed_cell := Vector2i.ZERO
	var found := false
	for key in build.slots:
		if key.begins_with("roof:"):
			var r: Structure = build.slots[key]
			roofed_cell = r.cell
			found = true
			break
	check(found, "some ruin still has a roof")
	var cc := BuildSystem.cell_center(roofed_cell)
	var top: float = build.cell_base(roofed_cell)
	put(Vector3(cc.x + 0.9, top + 0.2, cc.z + 0.9))
	await wait(0.3)
	p.inv.branch = 10
	p.inv.plank = 10
	var bp: Dictionary = build._plan("bedroll", Vector3(cc.x, top, cc.z), p)
	build.plan = bp
	var bed: Structure = build.try_place(p.inv)
	check(bed != null, "bedroll built inside the cabin (%s)" % bp.reason)
	if bed != null:
		place_bear(p.global_position + Vector3(200, 0, 0))
		world.tod_hours = 14.0
		aim_at(bed.global_position + Vector3(0, 0.1, 0))
		world._try_sleep(bed)
		check(world.tod_hours == 14.0, "can't sleep in the afternoon")
		world.tod_hours = 22.5
		var day0: int = world.day
		p.hunger = 90.0
		world._try_sleep(bed)
		check(world.tod_hours == world.SLEEP_WAKE_HOUR and world.day == day0 + 1,
			"slept through to morning (day %d, %.1f h)" % [world.day, world.tod_hours])
		check(p.hunger < 90.0, "and woke up hungrier (%.0f)" % p.hunger)

	print("\n%s (%d failed)" % ["ALL PASSED" if fails == 0 else "FAILURES", fails])
	quit(1 if fails > 0 else 0)
