shader_type sky;

// Gradient sky with drifting procedural clouds and a sun disc.

uniform vec3 top_color : source_color = vec3(0.16, 0.34, 0.66);
uniform vec3 horizon_color : source_color = vec3(0.70, 0.80, 0.87);
uniform vec3 ground_color : source_color = vec3(0.20, 0.19, 0.17);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.99, 0.97);
uniform vec3 cloud_shadow : source_color = vec3(0.55, 0.60, 0.68);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.44;
uniform float cloud_scale = 1.7;
uniform float cloud_speed = 0.0045;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;

	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}

	if (h > 0.015) {
		// Project the view ray onto a flat cloud plane above the camera.
		vec2 uv = dir.xz / max(h, 0.015) * 0.05;
		uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.55);
		float n = fbm(uv * cloud_scale);
		float dens = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.30, n);
		dens *= smoothstep(0.015, 0.20, h);
		// Fake self shadowing by sampling slightly offset.
		float lit = smoothstep(0.30, 0.75, fbm(uv * cloud_scale + vec2(0.12, 0.08)));
		vec3 cc = mix(cloud_shadow, cloud_color, lit);
		col = mix(col, cc, dens * 0.9);
	}

	if (LIGHT0_ENABLED) {
		float s = max(dot(dir, LIGHT0_DIRECTION), 0.0);
		col += LIGHT0_COLOR * pow(s, 900.0) * 12.0;   // disc
		col += LIGHT0_COLOR * pow(s, 8.0) * 0.20;     // bloom around sun
		col += LIGHT0_COLOR * pow(s, 2.0) * 0.05 * clamp(1.0 - h * 3.0, 0.0, 1.0);
	}

	COLOR = col;
}
