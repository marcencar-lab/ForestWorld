shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

// Lake surface: gerstner-ish vertex waves, depth tinting, shoreline foam,
// and a cheap screen-space refraction.

uniform vec3 shallow_color : source_color = vec3(0.30, 0.55, 0.52);
uniform vec3 deep_color : source_color = vec3(0.03, 0.12, 0.18);
uniform vec3 foam_color : source_color = vec3(0.90, 0.95, 0.95);
uniform float depth_fade = 8.0;
uniform float foam_width = 0.9;
uniform float wave_height = 0.13;
uniform float wave_speed = 0.55;
uniform float refraction = 0.035;
uniform float water_roughness : hint_range(0.0, 1.0) = 0.06;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_pos;

float wave(vec2 p, float t) {
	float w = 0.0;
	w += sin(p.x * 0.28 + t * 1.0) * 0.45;
	w += sin(p.y * 0.21 - t * 0.8) * 0.40;
	w += sin((p.x + p.y) * 0.55 + t * 1.7) * 0.20;
	w += sin((p.x - p.y * 0.6) * 1.10 - t * 2.3) * 0.10;
	return w;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	VERTEX.y += wave(world_pos.xz, t) * wave_height;
}

void fragment() {
	float t = TIME * wave_speed;
	float e = 0.45;
	float hl = wave(world_pos.xz - vec2(e, 0.0), t);
	float hr = wave(world_pos.xz + vec2(e, 0.0), t);
	float hd = wave(world_pos.xz - vec2(0.0, e), t);
	float hu = wave(world_pos.xz + vec2(0.0, e), t);

	vec3 n = normalize(vec3(
		-(hr - hl) * wave_height / (2.0 * e),
		1.0,
		-(hu - hd) * wave_height / (2.0 * e)
	));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// Linear scene depth behind the water surface.
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float scene_dist = -view.z;
	float water_depth = max(scene_dist + VERTEX.z, 0.0);

	float fade = clamp(water_depth / depth_fade, 0.0, 1.0);
	vec3 tint = mix(shallow_color, deep_color, fade);

	vec2 ruv = SCREEN_UV + n.xz * refraction * (1.0 - fade * 0.6);
	vec3 behind = texture(screen_tex, clamp(ruv, vec2(0.001), vec2(0.999))).rgb;

	// Keep the water readable enough to watch the fish underneath.
	vec3 col = mix(behind * mix(vec3(1.0), shallow_color, 0.45), tint, clamp(fade * 0.95, 0.0, 0.80));

	// Shoreline foam ring plus a little crest foam.
	float shore = 1.0 - smoothstep(0.0, foam_width, water_depth);
	float crest = smoothstep(0.55, 0.95, (hl + hr + hd + hu) * 0.25 + 0.5);
	float foam = clamp(shore + crest * shore * 0.6, 0.0, 1.0);
	col = mix(col, foam_color, foam * 0.75);

	ALBEDO = col;
	ROUGHNESS = water_roughness;
	METALLIC = 0.0;
	SPECULAR = 0.65;
	ALPHA = clamp(mix(0.40, 0.84, fade) + foam * 0.45, 0.0, 1.0);
}
