extends SceneTree

## Headless playtest for survival mode. Run from the project folder with:
##   godot --path <project> --headless --fixed-fps 60 -s tests/survival_test.gd

var world
var p: PlayerController
var wl: WildlifeManager
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


func _shore_spot() -> Array:
	for deg in range(0, 360, 7):
		var a := deg_to_rad(float(deg))
		var dir := Vector2(cos(a), sin(a))
		for r in range(int(ter.lake_radius * 0.5), int(ter.lake_radius * 1.4)):
			var q: Vector2 = ter.lake_center + dir * r
			if ter.water_depth(q.x, q.y) < -0.4 and ter.in_bounds(q.x, q.y):
				var probe: Vector2 = q - dir * 9.0
				if ter.water_depth(probe.x, probe.y) > 1.3:
					return [Vector3(q.x, ter.sample_height(q.x, q.y) + 0.3, q.y), -dir]
				break
	return []


func _face(dir: Vector2) -> void:
	p.rotation.y = atan2(-dir.x, -dir.y)
	p.pitch = -0.15
	p.head.rotation.x = p.pitch


func _revive() -> void:
	p.alive = true
	p.health = 100.0
	p.stamina = 100.0
	p.hunger = 100.0
	p.death_cause = ""
	p._death_t = 0.0
	p.head.rotation = Vector3.ZERO
	world.game_over = false
	world.hud.game_over.visible = false


func _run() -> void:
	await wait(0.5)
	p = world.player
	wl = world.wildlife
	ter = world.terrain
	var bear: Bear = wl.bear
	print("start: player %s  bear %s  dist %.0f m" % [p.global_position, bear.global_position,
		p.global_position.distance_to(bear.global_position)])
	check(p.global_position.distance_to(bear.global_position) > 100.0, "player spawns well away from the bear")

	# --- fishing -------------------------------------------------------------
	print("FISHING")
	bear._ignore_player_t = 1e9
	var spot := _shore_spot()
	check(not spot.is_empty(), "found a shoreline spot facing open water")
	p.global_position = spot[0]
	_face(spot[1])
	await wait(0.6)
	check(p.rod.cast_spot() != Vector3.INF, "cast_spot finds water (prompt: '%s')" % p.rod.prompt_text())
	var before: int = wl.fish_count()
	var landed := false
	var tries := 0
	while not landed and tries < 6:
		tries += 1
		p.rod.use()
		var t := 0.0
		while t < 25.0 and p.rod.state != FishingRod.State.BITE:
			await wait(0.1)
			t += 0.1
		if p.rod.state == FishingRod.State.BITE:
			print("  bite after %.1f s (cast %d)" % [t, tries])
			p.rod.use()
			landed = true
		else:
			p.rod.cancel()
			# Swing round a little and try another patch of water.
			p.rotate_y(0.5)
	check(landed and p.fish_caught == 1, "landed a fish (raw trout %d, raw pike %d)" % [p.inv.raw_trout, p.inv.raw_pike])
	check(wl.fish_count() == before - 1, "the caught fish left the lake (%d -> %d)" % [before, wl.fish_count()])

	# Missed bite: let the window lapse.
	p.rod.use()
	var t2 := 0.0
	while t2 < 40.0 and p.rod.state != FishingRod.State.BITE:
		await wait(0.1)
		t2 += 0.1
	if p.rod.state == FishingRod.State.BITE:
		await wait(1.4)
		check(p.rod.state == FishingRod.State.WAIT, "an ignored bite gets away and the line stays out")
	p.rod.cancel()

	# Walking off reels the line in.
	p.rod.use()
	await wait(1.0)
	p.global_position += p.global_transform.basis.z * 4.0
	await wait(0.3)
	check(p.rod.state == FishingRod.State.IDLE, "walking away reels the line in")

	# --- eating ---------------------------------------------------------------
	print("EATING")
	p.hunger = 20.0
	var ate := p.eat()
	check(ate != "" and p.hunger > 30.0, "ate a %s, hunger now %.0f" % [ate, p.hunger])
	check(p.eat() == "", "can't eat with an empty bag")

	# --- the bear hunts the player -------------------------------------------
	print("BEAR HUNT")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var field := Vector3.ZERO
	for i in 400:
		var c := ter.random_walkable_point(rng, 20)
		if c != Vector3.ZERO and ter.is_land(c.x, c.z, 6.0) \
				and Vector2(c.x, c.z).distance_to(ter.lake_center) > ter.lake_radius + 40.0:
			field = c
			break
	p.global_position = field + Vector3(0, 0.5, 0)
	bear._ignore_player_t = 0.0
	bear.global_position = field + Vector3(18, 0, 0)
	bear._ground_y = ter.sample_height(bear.global_position.x, bear.global_position.z)
	var noticed := false
	var t3 := 0.0
	while t3 < 3.0:
		await wait(0.1)
		t3 += 0.1
		if bear.target == p:
			noticed = true
			break
	check(noticed, "bear locks onto a player 18 m away within %.1f s" % t3)
	var first_hit := -1.0
	var t4 := 0.0
	while t4 < 40.0 and p.alive:
		await wait(0.1)
		t4 += 0.1
		if first_hit < 0.0 and p.health < 100.0:
			first_hit = t4
	print("  first hit at %.1f s, dead at %.1f s, cause '%s'" % [first_hit, t4, p.death_cause])
	check(not p.alive and p.death_cause == "bear", "a player who stands still gets killed by the bear")
	await wait(2.0)
	check(world.game_over and world.hud.game_over.visible, "game-over card is shown")
	print("  card: " + world.hud.game_over_label.text.replace("\n", " | "))

	# --- sneaking ---------------------------------------------------------------
	print("SNEAKING")
	_revive()
	bear.state = Bear.State.PATROL
	bear.target = null
	bear._ignore_player_t = 0.0
	p.global_position = field + Vector3(0, 0.5, 0)
	bear.global_position = field + Vector3(26, 0, 0)
	for k in Items.SMELLY:
		p.inv[k] = 0
	# 26 m: heard when standing (34*0.7 = 23.8? no) - check radius maths directly.
	p.crouching = true
	var r_crouch: float = Bear.PLAYER_DETECT * p.noise_level()
	p.crouching = false
	p.sprinting = true
	p.velocity = Vector3(8, 0, 0)
	var r_sprint: float = Bear.PLAYER_DETECT * p.noise_level()
	p.sprinting = false
	p.velocity = Vector3.ZERO
	print("  detection radius: crouched %.0f m, sprinting %.0f m" % [r_crouch, r_sprint])
	check(r_crouch < 20.0 and r_sprint > 50.0, "sneaking shrinks and sprinting widens the bear's hearing")
	p.inv.raw_trout = 2
	p.inv.raw_pike = 1
	check(p.scent_bonus() >= 27.0, "carrying 3 fish adds %.0f m of scent" % p.scent_bonus())
	p.inv.raw_trout = 0
	p.inv.raw_pike = 0

	# --- deep water refuge and drowning ---------------------------------------
	print("DEEP WATER")
	var deep := ter.random_lake_point(rng, 3.0, 200)
	var dir2 := Vector2(deep.x, deep.z) - ter.lake_center
	var shore: Vector3 = Vector3.ZERO
	for r in range(0, 120):
		var q: Vector2 = Vector2(deep.x, deep.z) + dir2.normalized() * r
		if ter.is_land(q.x, q.y, 0.5):
			shore = Vector3(q.x, ter.sample_height(q.x, q.y), q.y)
			break
	p.global_position = Vector3(deep.x, ForestTerrain.WATER_LEVEL - 1.0, deep.z)
	bear.global_position = shore
	bear._ground_y = shore.y
	bear.target = p
	bear.state = Bear.State.CHASE
	await wait(1.5)
	check(p.swimming, "player is swimming in deep water")
	check(bear.target != p, "bear gives up on a player in deep water")
	var bd: float = ter.water_depth(bear.global_position.x, bear.global_position.z)
	check(bd < Bear.WADE_DEPTH + 0.1, "bear stays in the shallows (depth under it %.2f m)" % bd)
	var t5 := 0.0
	while t5 < 90.0 and p.alive:
		await wait(0.25)
		t5 += 0.25
	print("  drowned after %.0f s in the water" % t5)
	check(not p.alive and p.death_cause == "drowned", "staying out in deep water drowns you")

	# --- starving ---------------------------------------------------------------
	print("STARVING")
	_revive()
	bear._ignore_player_t = 1e9
	p.global_position = field + Vector3(0, 0.5, 0)
	p.hunger = 0.0
	p.health = 5.0
	await wait(5.0)
	check(not p.alive and p.death_cause == "starved", "empty food bar starves you")

	# --- sandbox --------------------------------------------------------------
	print("SANDBOX")
	_revive()
	world._enter_sandbox()
	bear._ignore_player_t = 0.0
	p.global_position = field + Vector3(0, 0.5, 0)
	bear.global_position = field + Vector3(5, 0, 0)
	await wait(4.0)
	check(p.alive and p.health == 100.0 and bear.target != p, "sandbox player is ignored and invulnerable")

	print("\n%s (%d failed)" % ["ALL PASSED" if fails == 0 else "FAILURES", fails])
	quit(1 if fails > 0 else 0)
