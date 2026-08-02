class_name AudioSynth
extends RefCounted

## Procedural audio. Every sound in the game is synthesised into an
## AudioStreamWAV at startup - no sample files, matching the rest of the project.
##
## Ambience loops run at a low rate (they are all low-frequency content) and are
## built so their LFOs complete a whole number of cycles per loop; only the noise
## floor needs the crossfade in _seamless(), so the loop point is inaudible.

const LOOP_RATE := 16000
const SFX_RATE := 24000


# --- buffer helpers -----------------------------------------------------------

static func _wav(buf: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var n := buf.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


static func _noise(n: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		b[i] = rng.randf_range(-1.0, 1.0)
	return b


static func _lowpass(b: PackedFloat32Array, rate: int, cutoff: float) -> void:
	var dt := 1.0 / float(rate)
	var rc := 1.0 / (TAU * cutoff)
	var a := dt / (rc + dt)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] = y


static func _highpass(b: PackedFloat32Array, rate: int, cutoff: float) -> void:
	var dt := 1.0 / float(rate)
	var rc := 1.0 / (TAU * cutoff)
	var a := rc / (rc + dt)
	var prev_x := b[0]
	var y := 0.0
	for i in b.size():
		var x := b[i]
		y = a * (y + x - prev_x)
		prev_x = x
		b[i] = y


## RBJ biquad band-pass (unity gain at the centre). q around 1 is broad, 6+ is
## whistly. A biquad rather than a state-variable filter because the SVF form
## goes unstable above roughly fs/6, which silences the brighter sounds.
static func _bandpass(b: PackedFloat32Array, rate: int, freq: float, q: float) -> void:
	var w0 := TAU * clampf(freq, 20.0, rate * 0.45) / float(rate)
	var alpha := sin(w0) / (2.0 * maxf(q, 0.05))
	var a0 := 1.0 + alpha
	var b0 := alpha / a0
	var b2 := -alpha / a0
	var a1 := -2.0 * cos(w0) / a0
	var a2 := (1.0 - alpha) / a0

	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in b.size():
		var x := b[i]
		var y := b0 * x + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		b[i] = y


## Same filter with the centre frequency swept from `f_start` to `f_end`.
static func _sweep_bandpass(b: PackedFloat32Array, rate: int, f_start: float,
		f_end: float, q: float, curve := 1.0) -> void:
	var n := b.size()
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in n:
		var u := pow(float(i) / float(n), curve)
		var w0 := TAU * clampf(lerpf(f_start, f_end, u), 20.0, rate * 0.45) / float(rate)
		var alpha := sin(w0) / (2.0 * maxf(q, 0.05))
		var a0 := 1.0 + alpha
		var x := b[i]
		var y := (alpha * x - alpha * x2 + 2.0 * cos(w0) * y1 - (1.0 - alpha) * y2) / a0
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		b[i] = y


static func _normalize(b: PackedFloat32Array, peak := 0.9) -> void:
	var m := 0.0
	for i in b.size():
		m = maxf(m, absf(b[i]))
	if m < 0.000001:
		return
	var g := peak / m
	for i in b.size():
		b[i] *= g


## Crossfade the extra tail back over the head so the loop seam disappears.
## `b` must be (loop length + fade) samples long.
static func _seamless(b: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := b.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = b[i]
	for i in fade:
		var t := float(i) / float(fade)
		out[i] = out[i] * t + b[n + i] * (1.0 - t)
	return out


## Sawtooth-ish glottal buzz: the basis of every animal voice here.
static func _buzz(phase: float, harmonics: int) -> float:
	var v := 0.0
	for k in range(1, harmonics + 1):
		v += sin(phase * k) / float(k)
	return v


# --- ambience loops -----------------------------------------------------------

static func wind(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var rate := LOOP_RATE
	var dur := 6.0
	var fade := int(rate * 0.6)
	var n := int(rate * dur) + fade

	var body := _noise(n, rng)
	var leaves := body.duplicate()
	_bandpass(body, rate, 380.0, 1.2)
	_bandpass(leaves, rate, 2700.0, 0.9)

	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(rate)
		# 1 and 3 cycles per loop, so the gusting is periodic across the seam.
		var gust := 0.50 + 0.32 * sin(TAU * t / dur) + 0.18 * sin(TAU * 3.0 * t / dur + 1.3)
		var rustle := 0.34 + 0.26 * sin(TAU * 2.0 * t / dur + 2.1)
		out[i] = body[i] * gust + leaves[i] * rustle * 0.55
	var res := _seamless(out, fade)
	_normalize(res, 0.72)
	return _wav(res, rate, true)


static func lake(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var rate := LOOP_RATE
	var dur := 5.0
	var fade := int(rate * 0.5)
	var n := int(rate * dur) + fade

	var wash := _noise(n, rng)
	_lowpass(wash, rate, 900.0)
	_highpass(wash, rate, 120.0)

	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(rate)
		var lap := 0.40 + 0.34 * sin(TAU * 2.0 * t / dur) + 0.20 * sin(TAU * 5.0 * t / dur + 0.9)
		out[i] = wash[i] * lap
	var res := _seamless(out, fade)
	_normalize(res, 0.55)
	return _wav(res, rate, true)


## Daytime bed: faint high shimmer plus a lazy insect drone.
static func day_ambience(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var rate := LOOP_RATE
	var dur := 4.0
	var fade := int(rate * 0.4)
	var n := int(rate * dur) + fade

	var shimmer := _noise(n, rng)
	_bandpass(shimmer, rate, 5200.0, 2.5)

	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(rate)
		var breathe := 0.45 + 0.30 * sin(TAU * t / dur + 0.4)
		# Slow cicada-ish pulsing at 14 Hz, whole cycles per loop.
		var pulse := 0.55 + 0.45 * sin(TAU * 56.0 * t / dur)
		out[i] = shimmer[i] * breathe * pulse * 0.5
	var res := _seamless(out, fade)
	_normalize(res, 0.34)
	return _wav(res, rate, true)


## Night bed: two overlapping cricket populations at different rates.
static func night_ambience(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var rate := LOOP_RATE
	var dur := 4.0
	var fade := int(rate * 0.35)
	var n := int(rate * dur) + fade

	var hiss := _noise(n, rng)
	_bandpass(hiss, rate, 4600.0, 6.0)
	var hiss2 := _noise(n, rng)
	_bandpass(hiss2, rate, 3300.0, 7.0)

	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(rate)
		# Chirp groups: 8 and 12 per loop, each a short burst of fast pulses.
		var g1 := maxf(sin(TAU * 8.0 * t / dur), 0.0)
		var g2 := maxf(sin(TAU * 12.0 * t / dur + 1.1), 0.0)
		var p1 := 0.5 + 0.5 * sin(TAU * 240.0 * t / dur)
		var p2 := 0.5 + 0.5 * sin(TAU * 320.0 * t / dur + 0.7)
		out[i] = hiss[i] * pow(g1, 5.0) * p1 + hiss2[i] * pow(g2, 6.0) * p2 * 0.7
	var res := _seamless(out, fade)
	_normalize(res, 0.42)
	return _wav(res, rate, true)


# --- birds --------------------------------------------------------------------

## A short song: `notes` chirps, each sweeping from f0 to f1.
static func bird(rng: RandomNumberGenerator, f0: float, f1: float, notes: int,
		note_dur: float, gap: float, warble := 0.0) -> AudioStreamWAV:
	var rate := SFX_RATE
	var span := note_dur + gap
	var n := int(rate * (span * notes + 0.12))
	var out := PackedFloat32Array()
	out.resize(n)

	var detune := rng.randf_range(0.94, 1.06)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(rate)
		var idx := int(t / span)
		if idx >= notes:
			break
		var local := t - idx * span
		if local > note_dur:
			continue
		var u := local / note_dur
		# Each successive note sits a little higher and shorter.
		var bend := (1.0 + 0.06 * idx) * detune
		var f := lerpf(f0, f1, u) * bend
		if warble > 0.0:
			f += sin(TAU * 38.0 * t) * warble
		phase += TAU * f / float(rate)
		var env := sin(PI * clampf(u, 0.0, 1.0))
		env = pow(env, 0.55)
		out[i] = (sin(phase) * 0.8 + sin(phase * 2.0) * 0.2) * env
	_normalize(out, 0.85)
	return _wav(out, rate, false)


static func owl(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var rate := SFX_RATE
	var n := int(rate * 1.35)
	var out := PackedFloat32Array()
	out.resize(n)
	var base := rng.randf_range(352.0, 392.0)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(rate)
		var env := 0.0
		if t < 0.34:
			env = sin(PI * t / 0.34)
		elif t > 0.55 and t < 0.98:
			env = sin(PI * (t - 0.55) / 0.43) * 0.85
		var f := base + sin(TAU * 5.5 * t) * 6.0
		phase += TAU * f / float(rate)
		out[i] = (sin(phase) + sin(phase * 2.0) * 0.22 + sin(phase * 3.0) * 0.07) * pow(env, 1.3)
	_lowpass(out, rate, 1400.0)
	_normalize(out, 0.8)
	return _wav(out, rate, false)


# --- animal voices ------------------------------------------------------------

## Generic voiced call: a buzz swept in pitch, coloured by a formant band-pass
## and blended with breath noise. Every land animal is a preset of this.
static func voice(rng: RandomNumberGenerator, dur: float, f_start: float, f_mid: float,
		f_end: float, harmonics: int, formant: float, breath: float,
		vibrato_hz := 0.0, vibrato_depth := 0.0, drive := 1.0) -> AudioStreamWAV:
	var rate := SFX_RATE
	var n := int(rate * dur)
	var tone := PackedFloat32Array()
	tone.resize(n)
	var air := _noise(n, rng)
	_bandpass(air, rate, formant * 1.8, 1.0)

	var detune := rng.randf_range(0.97, 1.03)
	var phase := 0.0
	for i in n:
		var u := float(i) / float(n)
		var t := float(i) / float(rate)
		var f := 0.0
		if u < 0.5:
			f = lerpf(f_start, f_mid, u * 2.0) * detune
		else:
			f = lerpf(f_mid, f_end, (u - 0.5) * 2.0) * detune
		if vibrato_hz > 0.0:
			f += sin(TAU * vibrato_hz * t) * vibrato_depth
		phase += TAU * f / float(rate)
		# Fast attack, long-ish decay.
		var env := pow(clampf(u / 0.06, 0.0, 1.0), 1.2) * pow(1.0 - u, 1.1)
		tone[i] = (_buzz(phase, harmonics) * (1.0 - breath) + air[i] * breath) * env

	_bandpass(tone, rate, formant, 1.4)
	if drive > 1.0:
		for i in n:
			tone[i] = tanh(tone[i] * drive)
	_normalize(tone, 0.88)
	return _wav(tone, rate, false)


static func deer_call(rng: RandomNumberGenerator) -> AudioStreamWAV:
	return voice(rng, 0.44, 340.0, 300.0, 250.0, 7, 950.0, 0.16, 19.0, 9.0)


static func hare_call(rng: RandomNumberGenerator) -> AudioStreamWAV:
	return voice(rng, 0.26, 1150.0, 1450.0, 900.0, 4, 1900.0, 0.22, 34.0, 60.0)


static func fox_call(rng: RandomNumberGenerator) -> AudioStreamWAV:
	return voice(rng, 0.62, 780.0, 900.0, 520.0, 9, 1450.0, 0.20, 13.0, 40.0, 1.6)


static func boar_call(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var rate := SFX_RATE
	var n := int(rate * 0.52)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(rate)
		# Three short grunts.
		var idx := int(t / 0.17)
		var local := t - idx * 0.17
		var env := 0.0
		if local < 0.085:
			env = sin(PI * local / 0.085)
		var f := 128.0 - idx * 8.0
		phase += TAU * f / float(rate)
		out[i] = _buzz(phase, 8) * pow(env, 1.4)
	_bandpass(out, rate, 620.0, 1.1)
	_lowpass(out, rate, 2200.0)
	_normalize(out, 0.85)
	return _wav(out, rate, false)


static func bear_growl(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var rate := SFX_RATE
	var n := int(rate * 1.25)
	var out := PackedFloat32Array()
	var air := _noise(n, rng)
	_lowpass(air, rate, 900.0)
	out.resize(n)
	var phase := 0.0
	for i in n:
		var u := float(i) / float(n)
		var t := float(i) / float(rate)
		var f := 78.0 + sin(TAU * 3.1 * t) * 4.0
		phase += TAU * f / float(rate)
		var tremolo := 0.72 + 0.28 * sin(TAU * 21.0 * t)
		var env := pow(clampf(u / 0.10, 0.0, 1.0), 1.0) * pow(1.0 - u, 0.9)
		out[i] = (_buzz(phase, 10) * 0.78 + air[i] * 0.22) * tremolo * env
	_bandpass(out, rate, 420.0, 1.0)
	for i in n:
		out[i] = tanh(out[i] * 2.2)
	_normalize(out, 0.9)
	return _wav(out, rate, false)


static func bear_roar(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var rate := SFX_RATE
	var n := int(rate * 1.75)
	var out := PackedFloat32Array()
	var air := _noise(n, rng)
	_bandpass(air, rate, 1100.0, 0.8)
	out.resize(n)
	var phase := 0.0
	for i in n:
		var u := float(i) / float(n)
		var t := float(i) / float(rate)
		var f := 96.0 + sin(PI * u) * 52.0 + sin(TAU * 6.5 * t) * 5.0
		phase += TAU * f / float(rate)
		var env := pow(clampf(u / 0.07, 0.0, 1.0), 1.0) * pow(1.0 - u, 0.75)
		out[i] = (_buzz(phase, 12) * 0.70 + air[i] * 0.30) * env
	_bandpass(out, rate, 560.0, 0.9)
	for i in n:
		out[i] = tanh(out[i] * 3.0)
	_normalize(out, 0.95)
	return _wav(out, rate, false)


## Distress cry, pitched per species by the caller.
static func pain_cry(rng: RandomNumberGenerator) -> AudioStreamWAV:
	return voice(rng, 0.58, 700.0, 820.0, 330.0, 10, 1250.0, 0.28, 26.0, 55.0, 1.8)


# --- impacts and footfalls ----------------------------------------------------

static func swipe(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var rate := SFX_RATE
	var n := int(rate * 0.34)
	var out := _noise(n, rng)
	# Sweeping the band downward gives the whoosh a sense of direction.
	_sweep_bandpass(out, rate, 3400.0, 520.0, 1.4)
	for i in n:
		out[i] *= pow(1.0 - float(i) / float(n), 2.2)
	_normalize(out, 0.9)
	return _wav(out, rate, false)


static func splash(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var rate := SFX_RATE
	var n := int(rate * 0.62)
	var out := _noise(n, rng)
	_sweep_bandpass(out, rate, 6200.0, 700.0, 1.1, 0.6)
	for i in n:
		out[i] *= pow(1.0 - float(i) / float(n), 1.8)
	# Add the hollow thump of displaced water.
	var phase := 0.0
	for i in n:
		var u := float(i) / float(n)
		phase += TAU * lerpf(190.0, 90.0, u) / float(rate)
		out[i] += sin(phase) * pow(1.0 - u, 5.0) * 0.45
	_normalize(out, 0.88)
	return _wav(out, rate, false)


static func footstep(rng: RandomNumberGenerator, wet: bool) -> AudioStreamWAV:
	var rate := SFX_RATE
	var n := int(rate * (0.26 if wet else 0.15))
	var out := _noise(n, rng)
	if wet:
		_bandpass(out, rate, 1500.0, 0.7)
	else:
		_lowpass(out, rate, 1100.0)
		_highpass(out, rate, 140.0)
	for i in n:
		var u := float(i) / float(n)
		out[i] *= pow(1.0 - u, 3.2 if wet else 4.5)
	_normalize(out, 0.75)
	return _wav(out, rate, false)


## Undergrowth being pushed through - played when something runs past nearby.
static func rustle(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var rate := SFX_RATE
	var n := int(rate * 0.55)
	var out := _noise(n, rng)
	_bandpass(out, rate, 3100.0, 0.8)
	for i in n:
		var u := float(i) / float(n)
		var burst := 0.55 + 0.45 * sin(TAU * 11.0 * u)
		out[i] *= sin(PI * u) * burst
	_normalize(out, 0.7)
	return _wav(out, rate, false)
