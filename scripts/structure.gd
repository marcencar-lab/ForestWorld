class_name Structure
extends StaticBody3D

## One placed building piece. Walls and doors keep 2D segments so the bear
## (which moves kinematically, not through physics) can test whether it is
## walking into one or trying to reach the player through one.

var kind := ""
var slot_key := ""
var cell := Vector2i.ZERO
var base_y := 0.0
var hp := 100.0
var max_hp := 100.0
var ruined := false
var seg_ab: Array = []           # the [a, b] edge a wall or door was built on

## Wall segments in world XZ: [a: Vector2, b: Vector2, closes_with_door: bool]
var segments: Array = []

# Door
var is_door := false
var open := false
var door_pivot: Node3D
var door_shape: CollisionShape3D

# Loot crate
var loot: Array = []
var looted := false
var lid: Node3D

# Campfire
var fuel := 0.0
var light: OmniLight3D
var flames: Node3D
var fire_audio: AudioStreamPlayer3D
var _flicker := 0.0

const WALL_HALF_THICK := 0.12


func is_lit() -> bool:
	return kind == "campfire" and fuel > 0.0


func set_open(v: bool) -> void:
	open = v
	if door_pivot != null:
		var tw := create_tween()
		tw.tween_property(door_pivot, "rotation:y", -1.75 if open else 0.0, 0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if door_shape != null:
		door_shape.set_deferred("disabled", open)


## Empty the crate; returns what was inside.
func open_crate() -> Array:
	if looted:
		return []
	looted = true
	if lid != null:
		var tw := create_tween()
		tw.tween_property(lid, "rotation:x", 1.9, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var out := loot
	loot = []
	return out


func add_fuel(seconds: float) -> void:
	fuel = minf(fuel + seconds, 900.0)
	_update_fire()


## Distance from a path (from `a` to `b`) to the nearest blocking segment.
func path_distance(a: Vector2, b: Vector2) -> float:
	var best := INF
	for s in segments:
		if s[2] and open:
			continue
		var d: float
		if a.is_equal_approx(b):
			d = a.distance_to(Geometry2D.get_closest_point_to_segment(a, s[0], s[1]))
		else:
			var pts := Geometry2D.get_closest_points_between_segments(a, b, s[0], s[1])
			d = pts[0].distance_to(pts[1])
		best = minf(best, d)
	return best - WALL_HALF_THICK


func _process(delta: float) -> void:
	if kind != "campfire":
		set_process(false)
		return
	if fuel > 0.0:
		fuel = maxf(fuel - delta, 0.0)
		if fuel <= 0.0:
			_update_fire()
		_flicker += delta
		if light != null:
			light.light_energy = 2.2 + sin(_flicker * 13.0) * 0.25 + sin(_flicker * 31.0) * 0.15
		if flames != null:
			var s := 1.0 + sin(_flicker * 17.0) * 0.08
			flames.scale = Vector3(s, 1.0 + sin(_flicker * 11.0 + 1.0) * 0.14, s)
			# Dying embers shrink over the last half-minute.
			flames.scale *= clampf(fuel / 30.0, 0.35, 1.0)


func _update_fire() -> void:
	var lit := fuel > 0.0
	if light != null:
		light.visible = lit
	if flames != null:
		flames.visible = lit
	if fire_audio != null:
		if lit and not fire_audio.playing:
			fire_audio.play()
		elif not lit:
			fire_audio.stop()
