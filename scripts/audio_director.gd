class_name AudioDirector
extends Node

## Owns the synthesised sound bank, the looping ambience beds, and the one-shot
## players for animal voices and impacts.
##
## Ambience beds are non-positional and cross-faded by context (time of day,
## distance to the lake). Everything else is an AudioStreamPlayer3D placed in the
## world so it pans and attenuates around the listener.

const BIRD_KEYS := ["bird_a", "bird_b", "bird_c"]

## Species -> [stream key, base pitch, base volume dB, audible range].
const VOICES := {
	"deer": ["deer", 1.00, -5.0, 130.0],
	"rabbit": ["hare", 1.00, -9.0, 80.0],
	"fox": ["fox", 1.00, -4.0, 150.0],
	"boar": ["boar", 1.00, -5.0, 120.0],
}

var terrain: ForestTerrain
var world: Node3D

var muted := false
var day_factor := 1.0
var rain_level := 0.0      # 0..1, set by Weather
var sheltered := false     # listener is under a roof: rain sounds muffled

var _bank := {}
var _wind: AudioStreamPlayer
var _day: AudioStreamPlayer
var _night: AudioStreamPlayer
var _water: AudioStreamPlayer
var _rain: AudioStreamPlayer

var _bird_timer := 2.0
var _live := 0                       # active one-shot players, for a hard cap
var _rng := RandomNumberGenerator.new()

const MAX_LIVE_ONESHOTS := 28


func setup(t: ForestTerrain, w: Node3D, world_seed: int) -> void:
	terrain = t
	world = w
	_rng.seed = world_seed + 5150
	_setup_buses()
	_build_bank()
	_start_ambience()


# --- bus routing --------------------------------------------------------------

func _setup_buses() -> void:
	if AudioServer.get_bus_index("Ambience") == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Ambience")
		AudioServer.set_bus_send(i, "Master")
		AudioServer.set_bus_volume_db(i, -6.0)

	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var j := AudioServer.bus_count - 1
		AudioServer.set_bus_name(j, "SFX")
		AudioServer.set_bus_send(j, "Master")
		AudioServer.set_bus_volume_db(j, -3.0)
		# A little forest reverb glues the calls into the space.
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.62
		rev.damping = 0.58
		rev.spread = 0.9
		rev.dry = 0.90
		rev.wet = 0.22
		rev.predelay_msec = 28.0
		AudioServer.add_bus_effect(j, rev)


# --- sound bank ---------------------------------------------------------------

func _build_bank() -> void:
	var r := _rng
	_bank["wind"] = AudioSynth.wind(r)
	_bank["lake"] = AudioSynth.lake(r)
	_bank["day"] = AudioSynth.day_ambience(r)
	_bank["night"] = AudioSynth.night_ambience(r)

	_bank["bird_a"] = AudioSynth.bird(r, 2600.0, 3900.0, 4, 0.075, 0.055, 0.0)
	_bank["bird_b"] = AudioSynth.bird(r, 4200.0, 2900.0, 3, 0.10, 0.07, 90.0)
	_bank["bird_c"] = AudioSynth.bird(r, 1900.0, 2400.0, 6, 0.05, 0.04, 0.0)
	_bank["owl"] = AudioSynth.owl(r)

	_bank["deer"] = AudioSynth.deer_call(r)
	_bank["hare"] = AudioSynth.hare_call(r)
	_bank["fox"] = AudioSynth.fox_call(r)
	_bank["boar"] = AudioSynth.boar_call(r)
	_bank["pain"] = AudioSynth.pain_cry(r)

	_bank["growl"] = AudioSynth.bear_growl(r)
	_bank["roar"] = AudioSynth.bear_roar(r)
	_bank["swipe"] = AudioSynth.swipe(r)
	_bank["splash"] = AudioSynth.splash(r)
	_bank["rustle"] = AudioSynth.rustle(r)
	_bank["step"] = AudioSynth.footstep(r, false)
	_bank["step_wet"] = AudioSynth.footstep(r, true)
	_bank["rain"] = AudioSynth.rain(r)
	_bank["fire"] = AudioSynth.fire(r)
	_bank["chop"] = AudioSynth.chop(r)
	_bank["thud"] = AudioSynth.thud(r)


func _start_ambience() -> void:
	_wind = _bed("wind", -8.0)
	_day = _bed("day", -14.0)
	_night = _bed("night", -60.0)
	_water = _bed("lake", -60.0)
	_rain = _bed("rain", -60.0)


## Release the looping playbacks on shutdown, otherwise the AudioServer is still
## holding them when the engine does its leaked-instance check.
func _exit_tree() -> void:
	for p in [_wind, _day, _night, _water, _rain]:
		if is_instance_valid(p):
			p.stop()
			p.stream = null


func _bed(key: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _bank[key]
	p.bus = "Ambience"
	p.volume_db = db
	add_child(p)
	p.play()
	return p


# --- playback -----------------------------------------------------------------

func play_at(key: String, pos: Vector3, db := 0.0, pitch := 1.0, max_dist := 120.0) -> void:
	if muted or not _bank.has(key) or _live >= MAX_LIVE_ONESHOTS:
		return
	# Don't spend a player on something the listener could never hear.
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.global_position.distance_to(pos) > max_dist:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _bank[key]
	p.bus = "SFX"
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = 14.0
	p.max_distance = max_dist
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(p)
	p.global_position = pos
	p.play()
	_live += 1
	p.finished.connect(_on_oneshot_done.bind(p))


func _on_oneshot_done(p: Node) -> void:
	_live -= 1
	if is_instance_valid(p):
		p.queue_free()


## `kind` is one of idle / alarm / pain / death.
func animal_voice(species: String, kind: String, pos: Vector3) -> void:
	if not VOICES.has(species):
		return
	var v: Array = VOICES[species]
	var key: String = v[0]
	var pitch: float = v[1] * _rng.randf_range(0.94, 1.07)
	var db: float = v[2]
	var reach: float = v[3]

	match kind:
		"idle":
			db -= 5.0
			reach *= 0.7
		"alarm":
			pitch *= 1.14
			db += 3.0
		"pain":
			key = "pain"
			pitch *= v[1] * 1.05
			db += 4.0
			reach *= 1.2
		"death":
			key = "pain"
			pitch *= v[1] * 0.78
			db += 3.0
			reach *= 1.2
	play_at(key, pos, db, pitch, reach)


func bear_voice(kind: String, pos: Vector3) -> void:
	match kind:
		"roar":
			play_at("roar", pos, 2.0, _rng.randf_range(0.94, 1.04), 260.0)
		"growl":
			play_at("growl", pos, -3.0, _rng.randf_range(0.90, 1.08), 150.0)
		"swipe":
			play_at("swipe", pos, -1.0, _rng.randf_range(0.92, 1.10), 110.0)
			play_at("growl", pos, -4.0, _rng.randf_range(1.02, 1.14), 150.0)


func splash_at(pos: Vector3) -> void:
	play_at("splash", pos, -6.0, _rng.randf_range(0.85, 1.25), 90.0)


func rustle_at(pos: Vector3) -> void:
	play_at("rustle", pos, -12.0, _rng.randf_range(0.85, 1.2), 55.0)


func footstep_at(pos: Vector3, wet: bool, db_offset := 0.0) -> void:
	play_at("step_wet" if wet else "step", pos, -16.0 + db_offset, _rng.randf_range(0.88, 1.14), 25.0)


## The player's own grunt when the bear lands a hit.
func player_hurt(pos: Vector3) -> void:
	play_at("pain", pos, -4.0, _rng.randf_range(0.42, 0.50), 40.0)


func bobber_plop(pos: Vector3) -> void:
	play_at("splash", pos, -14.0, _rng.randf_range(1.5, 1.8), 40.0)


func chop_at(pos: Vector3, stone := false) -> void:
	play_at("chop", pos, -3.0, _rng.randf_range(1.25, 1.45) if stone else _rng.randf_range(0.9, 1.08), 70.0)


func thud_at(pos: Vector3) -> void:
	play_at("thud", pos, 3.0, _rng.randf_range(0.85, 1.05), 160.0)


func build_at(pos: Vector3) -> void:
	play_at("chop", pos, -2.0, _rng.randf_range(0.7, 0.8), 60.0)
	play_at("thud", pos, -10.0, 1.6, 60.0)


## A looping positional crackle for a campfire; the caller parents and frees it.
func make_fire_player() -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _bank["fire"]
	p.bus = "SFX"
	p.volume_db = -6.0
	p.unit_size = 5.0
	p.max_distance = 35.0
	p.autoplay = true
	return p


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
	return muted


# --- ambience mixing ----------------------------------------------------------

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var ear := cam.global_position

	# Day/night crossfade of the insect beds.
	var d := clampf(day_factor, 0.0, 1.0)
	_day.volume_db = lerpf(-60.0, -14.0, d)
	_night.volume_db = lerpf(-13.0, -60.0, d)

	# Wind gets stronger with altitude and out in the open.
	var ground := terrain.sample_height(ear.x, ear.z)
	var exposure := clampf((ground - 12.0) / 40.0, 0.0, 1.0)
	_wind.volume_db = lerpf(-13.0, -4.0, exposure)

	# Lake wash fades in as you approach the shoreline.
	var to_shore := Vector2(ear.x, ear.z).distance_to(terrain.lake_center) - terrain.lake_radius
	_water.volume_db = lerpf(-7.0, -60.0, clampf(to_shore / 55.0, 0.0, 1.0))

	# Rain drowns out the insects and gets duller under a roof.
	var r := clampf(rain_level, 0.0, 1.0)
	_rain.volume_db = -60.0 if r < 0.01 else lerpf(-30.0, -3.0, r) - (7.0 if sheltered else 0.0)
	_day.volume_db -= r * 12.0

	_bird_timer -= delta
	if _bird_timer <= 0.0 and r < 0.4:
		_schedule_bird(ear)


## Drop a bird call at a random spot in the canopy around the listener.
func _schedule_bird(ear: Vector3) -> void:
	var night := 1.0 - clampf(day_factor, 0.0, 1.0)
	_bird_timer = _rng.randf_range(1.6, 5.5) + night * 6.0

	var ang := _rng.randf_range(0.0, TAU)
	var dist := _rng.randf_range(10.0, 48.0)
	var x := ear.x + cos(ang) * dist
	var z := ear.z + sin(ang) * dist
	if not terrain.in_bounds(x, z):
		return
	var y := terrain.sample_height(x, z) + _rng.randf_range(4.0, 9.0)

	if night > 0.55:
		if _rng.randf() < 0.5:
			play_at("owl", Vector3(x, y, z), -7.0, _rng.randf_range(0.93, 1.07), 180.0)
	else:
		var key: String = BIRD_KEYS[_rng.randi_range(0, BIRD_KEYS.size() - 1)]
		play_at(key, Vector3(x, y, z), -9.0, _rng.randf_range(0.88, 1.16), 110.0)
