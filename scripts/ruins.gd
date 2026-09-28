class_name Ruins
extends Node

## Abandoned cabins scattered through the forest. They are built from the same
## pieces as player buildings (so they block the bear, keep the rain off and
## can be repaired into a base), but weathered, damaged and partly collapsed,
## with supply crates inside.

const COUNT := 5
const MIN_FROM_SPAWN := 70.0
const MIN_APART := 90.0
const CELL := BuildSystem.CELL

## [site centre, cells footprint, crates]
var sites: Array = []

var _rng := RandomNumberGenerator.new()


func generate(terrain: ForestTerrain, build: BuildSystem, trees: TreeRegistry,
		world_seed: int, spawn: Vector3) -> void:
	_rng.seed = world_seed + 5150
	var all_crates: Array[Structure] = []
	var tries := 0
	while sites.size() < COUNT and tries < 4000:
		tries += 1
		var p := terrain.random_walkable_point(_rng, 10)
		if p == Vector3.ZERO:
			continue
		if p.distance_to(spawn) < MIN_FROM_SPAWN:
			continue
		if Vector2(p.x, p.z).distance_to(terrain.lake_center) < terrain.lake_radius + 18.0:
			continue
		var too_close := false
		for s in sites:
			if s.center.distance_to(p) < MIN_APART:
				too_close = true
				break
		if too_close:
			continue
		var big := _rng.randf() < 0.5
		var w := 2
		var d := 2 if big else 1
		var origin := BuildSystem.cell_of(p.x, p.z)
		var cells: Array[Vector2i] = []
		for cx in w:
			for cz in d:
				cells.append(origin + Vector2i(cx, cz))
		if not _flat(terrain, build, cells):
			continue
		var center := Vector3((origin.x + w * 0.5) * CELL, 0.0, (origin.y + d * 0.5) * CELL)
		center.y = terrain.sample_height(center.x, center.z)
		trees.clear_area(center, maxf(w, d) * CELL * 0.5 + 3.0)
		var crates := _build_cabin(build, cells, origin, w, d)
		all_crates.append_array(crates)
		sites.append({"center": center, "cells": cells, "crates": crates})

	_guarantee(all_crates, ["knife", "hatchet", "bow"])


func _flat(terrain: ForestTerrain, build: BuildSystem, cells: Array[Vector2i]) -> bool:
	var lo := INF
	var hi := -INF
	for c in cells:
		for q in build._cell_corners(c):
			var h := terrain.sample_height(q.x, q.y)
			lo = minf(lo, h)
			hi = maxf(hi, h)
			if not terrain.is_land(q.x, q.y, 1.0) or not terrain.in_bounds(q.x, q.y):
				return false
		for k in ["floor", "cell", "roof", "fire", "bed"]:
			if build.slots.has("%s:%d:%d" % [k, c.x, c.y]):
				return false
	return hi - lo < 1.4


func _plan(build: BuildSystem, kind: String, key: String, cell: Vector2i, base: float,
		xf: Transform3D, seg := []) -> Dictionary:
	var p := {"key": key, "cell": cell, "base": base, "xf": xf, "ruined": true, "silent": true,
		"hp_frac": _rng.randf_range(0.35, 0.75)}
	if not seg.is_empty():
		p.seg = seg
	return p


func _build_cabin(build: BuildSystem, cells: Array[Vector2i], origin: Vector2i, w: int, d: int) -> Array[Structure]:
	# Level floors across the whole footprint.
	var base := -INF
	for c in cells:
		base = maxf(base, build._ground_range(build._cell_corners(c)).y)
	for c in cells:
		var cc := BuildSystem.cell_center(c)
		build.spawn_piece("floor", _plan(build, "floor", "floor:%d:%d" % [c.x, c.y], c, base,
			Transform3D(Basis(), Vector3(cc.x, base, cc.z))))
	var top := base + BuildSystem.FLOOR_H

	# Perimeter edges; one becomes the doorway, a couple have rotted away.
	var edges := []
	for cx in w:
		edges.append(["x", origin.x + cx, origin.y])
		edges.append(["x", origin.x + cx, origin.y + d])
	for cz in d:
		edges.append(["z", origin.x, origin.y + cz])
		edges.append(["z", origin.x + w, origin.y + cz])
	var door_i := _rng.randi_range(0, edges.size() - 1)
	var missing := []
	for m in _rng.randi_range(1, 2):
		var mi := _rng.randi_range(0, edges.size() - 1)
		if mi != door_i:
			missing.append(mi)
	for i in edges.size():
		if i in missing:
			continue
		var e: Array = edges[i]
		var axis: String = e[0]
		var ex: int = e[1]
		var ez: int = e[2]
		var a: Vector2
		var b: Vector2
		var mid: Vector3
		var yaw := 0.0
		if axis == "x":
			a = Vector2(ex * CELL, ez * CELL)
			b = Vector2((ex + 1) * CELL, ez * CELL)
			mid = Vector3((ex + 0.5) * CELL, top, ez * CELL)
		else:
			a = Vector2(ex * CELL, ez * CELL)
			b = Vector2(ex * CELL, (ez + 1) * CELL)
			mid = Vector3(ex * CELL, top, (ez + 0.5) * CELL)
			yaw = PI * 0.5
		var kind := "door" if i == door_i else "wall"
		var key := "edge:%s:%d:%d" % [axis, ex, ez]
		var s := build.spawn_piece(kind, _plan(build, kind, key, BuildSystem.cell_of(mid.x, mid.z), top,
			Transform3D(Basis(Vector3.UP, yaw), mid), [a, b]))
		if kind == "door" and _rng.randf() < 0.6:
			s.set_open(true)   # left hanging open

	# Roof survives over some of the cells.
	var roofed := 0
	for c in cells:
		if roofed == 0 or _rng.randf() < 0.45:
			var cc2 := BuildSystem.cell_center(c)
			build.spawn_piece("roof", _plan(build, "roof", "roof:%d:%d" % [c.x, c.y], c,
				top + BuildSystem.WALL_H, Transform3D(Basis(), Vector3(cc2.x, top + BuildSystem.WALL_H, cc2.z))))
			roofed += 1

	# Crates against the inside of the walls.
	var crates: Array[Structure] = []
	var shuffled := cells.duplicate()
	shuffled.shuffle()
	for i in mini(_rng.randi_range(1, 3), shuffled.size()):
		var c2: Vector2i = shuffled[i]
		var cc3 := BuildSystem.cell_center(c2)
		var off := Vector3(_rng.randf_range(-0.7, 0.7), 0.0, _rng.randf_range(-0.7, 0.7))
		var pos := Vector3(cc3.x, top, cc3.z) + off
		crates.append(build.spawn_crate(pos, _rng.randf_range(0.0, TAU), Items.roll_crate(_rng)))
	return crates


## Make sure the key items exist somewhere in the world.
func _guarantee(crates: Array[Structure], items: Array) -> void:
	if crates.is_empty():
		return
	for item in items:
		var present := false
		for c in crates:
			for e in c.loot:
				if e[0] == item:
					present = true
		if not present:
			crates[_rng.randi_range(0, crates.size() - 1)].loot.append([item, 1])
	# Arrows wherever there's a bow.
	for c in crates:
		for e in c.loot:
			if e[0] == "bow":
				c.loot.append(["arrow", 8])
				break


## Nearest site that still has unopened crates, or {}.
func nearest_unexplored(from: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	for s in sites:
		var any := false
		for c in s.crates:
			if is_instance_valid(c) and not c.looted:
				any = true
		if not any:
			continue
		var d := from.distance_to(s.center)
		if d < best_d:
			best_d = d
			best = s
	return best
