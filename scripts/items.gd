class_name Items
extends RefCounted

## Static data for everything the player can carry: food values, weapon and
## tool stats, and the loot tables for abandoned cabins.

## Display names for inventory keys.
const LABELS := {
	"rock": "rock", "branch": "branch", "log": "log", "plank": "plank",
	"raw_trout": "raw trout", "cooked_trout": "cooked trout",
	"raw_pike": "raw pike", "cooked_pike": "cooked pike",
	"raw_meat": "raw meat", "cooked_meat": "cooked meat",
	"canned_food": "canned food", "bandage": "bandage",
	"bottle": "water bottle", "arrow": "arrow",
}

## Food: hunger restored, health restored, and (raw only) the chance of
## food poisoning. Ordered best-first for auto-eating.
const FOOD := {
	"cooked_meat": {"hunger": 55.0, "health": 12.0, "sick": 0.0},
	"cooked_pike": {"hunger": 60.0, "health": 16.0, "sick": 0.0},
	"canned_food": {"hunger": 45.0, "health": 6.0, "sick": 0.0, "thirst": 10.0},
	"cooked_trout": {"hunger": 32.0, "health": 8.0, "sick": 0.0},
	"raw_meat": {"hunger": 22.0, "health": 0.0, "sick": 0.35},
	"raw_pike": {"hunger": 28.0, "health": 0.0, "sick": 0.25},
	"raw_trout": {"hunger": 15.0, "health": 0.0, "sick": 0.25},
}

## What cooking turns each raw food into.
const COOKS_TO := {
	"raw_trout": "cooked_trout", "raw_pike": "cooked_pike", "raw_meat": "cooked_meat",
}

## Anything in here attracts the bear's nose.
const SMELLY := ["raw_trout", "cooked_trout", "raw_pike", "cooked_pike", "raw_meat", "cooked_meat"]

## Held tools and weapons. `damage` is against creatures; `wood` against trees
## (0 = can't chop). `uses` is the durability of a fresh one.
const TOOLS := {
	"axe": {"label": "stone axe", "damage": 14.0, "wood": 25.0, "reach": 2.8, "cooldown": 0.6, "uses": 60},
	"hatchet": {"label": "steel hatchet", "damage": 26.0, "wood": 45.0, "reach": 2.8, "cooldown": 0.55, "uses": 160},
	"knife": {"label": "hunting knife", "damage": 18.0, "wood": 0.0, "reach": 2.3, "cooldown": 0.38, "uses": 120},
	"spear": {"label": "wooden spear", "damage": 24.0, "wood": 0.0, "reach": 3.4, "cooldown": 0.7, "uses": 40},
	"bow": {"label": "hunting bow", "damage": 48.0, "wood": 0.0, "reach": 0.0, "cooldown": 0.9, "uses": 90},
}

## Order tools appear on the hotbar.
const HOTBAR_ORDER := ["axe", "hatchet", "knife", "spear", "bow"]

## Loot tables: [item, min, max, weight]. Tools are given with full uses.
const LOOT_COMMON := [
	["canned_food", 1, 2, 10.0],
	["bandage", 1, 2, 8.0],
	["plank", 2, 5, 8.0],
	["bottle", 1, 1, 5.0],
	["arrow", 3, 8, 5.0],
	["rock", 2, 4, 3.0],
]
const LOOT_RARE := [
	["knife", 1, 1, 6.0],
	["hatchet", 1, 1, 4.0],
	["bow", 1, 1, 3.0],
	["spear", 1, 1, 3.0],
]
const RARE_CHANCE := 0.4


static func label(key: String) -> String:
	if TOOLS.has(key):
		return TOOLS[key].label
	return LABELS.get(key, key)


static func count_label(key: String, n: int) -> String:
	var name := label(key)
	if n == 1:
		return "1 " + name
	if name.ends_with("ch") or name.ends_with("sh"):
		return "%d %ses" % [n, name]
	if name.ends_with("food") or name.ends_with("meat") or name.begins_with("cooked") or name.begins_with("raw"):
		return "%d %s" % [n, name]
	return "%d %ss" % [n, name]


static func _pick(table: Array, rng: RandomNumberGenerator) -> Array:
	var total := 0.0
	for e in table:
		total += float(e[3])
	var r := rng.randf() * total
	for e in table:
		r -= float(e[3])
		if r <= 0.0:
			return e
	return table[table.size() - 1]


## Roll a crate: returns [[item, count], ...].
static func roll_crate(rng: RandomNumberGenerator) -> Array:
	var out := []
	for i in rng.randi_range(2, 3):
		var e := _pick(LOOT_COMMON, rng)
		out.append([e[0], rng.randi_range(e[1], e[2])])
	if rng.randf() < RARE_CHANCE:
		var r := _pick(LOOT_RARE, rng)
		out.append([r[0], 1])
	return out
