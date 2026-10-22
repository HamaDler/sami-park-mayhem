shader_type sky;
// Comic night sky: navy gradient, faint city glow on the horizon, static stars, flat-toned
// clouds with ink edges (lit near the moon) and a cream moon with craters and an ink rim.
// The moon sits where the first directional light (the Moon node) is.
// No TIME use, so Godot does not re-render the sky's reflection map every frame.
uniform vec3 zenith_color : source_color = vec3(0.03, 0.05, 0.13);
uniform vec3 horizon_color : source_color = vec3(0.08, 0.12, 0.22);
uniform vec3 ground_color : source_color = vec3(0.012, 0.016, 0.03);
uniform vec3 city_glow_color : source_color = vec3(0.30, 0.17, 0.08);
uniform float city_glow_strength = 0.1;
uniform float star_density : hint_range(0.0, 1.0) = 0.4;
uniform float star_brightness = 1.4;
uniform vec3 moon_color : source_color = vec3(1.0, 0.94, 0.72);
uniform vec3 crater_color : source_color = vec3(0.78, 0.7, 0.5);
uniform float moon_radius = 0.045;
uniform vec3 cloud_color : source_color = vec3(0.06, 0.09, 0.2);
uniform vec3 cloud_lit_color : source_color = vec3(0.26, 0.32, 0.5);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.55;
uniform vec3 ink_color : source_color = vec3(0.02, 0.025, 0.06);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		total += value_noise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.3);
		amplitude *= 0.5;
	}
	return total;
}

void sky() {
	vec3 dir = EYEDIR;
	float up = dir.y;
	vec3 col = mix(horizon_color, zenith_color, smoothstep(-0.02, 0.45, up));
	col += city_glow_color * city_glow_strength * exp(-max(up, 0.0) * 12.0);
	col = mix(col, ground_color, smoothstep(0.0, 0.08, -up));
	if (!AT_CUBEMAP_PASS && up > 0.0) {
		const float GRID = 220.0;
		vec3 cell = floor(dir * GRID);
		float h = hash13(cell);
		if (h > 1.0 - star_density * 0.02) {
			vec3 jitter = vec3(hash13(cell + 1.7), hash13(cell + 3.1), hash13(cell + 5.3)) - 0.5;
			vec3 center = normalize((cell + 0.5 + jitter * 0.6) / GRID);
			float star = 1.0 - smoothstep(0.0, 0.32, length(dir - center) * GRID);
			col += vec3(0.95, 0.95, 1.0) * star * smoothstep(0.03, 0.3, up) * star_brightness * (0.3 + 0.7 * fract(h * 97.0));
		}
	}
	float moon_glow = 0.0;
	if (LIGHT0_ENABLED) {
		float cos_angle = dot(dir, LIGHT0_DIRECTION);
		moon_glow = pow(max(cos_angle, 0.0), 30.0);
		col += moon_color * (pow(max(cos_angle, 0.0), 900.0) * 0.25 + moon_glow * 0.04);
		float angle = acos(clamp(cos_angle, -1.0, 1.0));
		if (angle < moon_radius * 1.15) {
			vec3 side = normalize(cross(LIGHT0_DIRECTION, vec3(0.0, 1.0, 0.0)));
			vec3 top = cross(side, LIGHT0_DIRECTION);
			vec2 disc = vec2(dot(dir, side), dot(dir, top)) / moon_radius;
			float craters = smoothstep(0.55, 0.62, fbm(disc * 2.2 + vec2(4.0, 1.0)));
			vec3 face = mix(moon_color, crater_color, craters * 0.8);
			float inside = 1.0 - smoothstep(moon_radius * 0.97, moon_radius, angle);
			float rim = smoothstep(moon_radius * 0.9, moon_radius * 0.97, angle) * inside;
			col = mix(col, face * 1.6, inside);
			col = mix(col, ink_color, rim * 0.85);
		}
	}
	if (up > 0.02) {
		// Clouds on a flat ceiling: two flat tones, an ink edge, faded towards the horizon.
		vec2 ceiling = dir.xz / (up + 0.15);
		float density = fbm(ceiling * 0.9 + vec2(3.1, 7.7));
		float cloud = smoothstep(cloud_cover, cloud_cover + 0.02, density);
		float edge = cloud * (1.0 - smoothstep(cloud_cover + 0.02, cloud_cover + 0.045, density));
		float lit = smoothstep(0.15, 0.4, moon_glow * 3.0 + (density - cloud_cover) * 0.6);
		vec3 tone = mix(cloud_color, cloud_lit_color, step(0.5, lit));
		float fade = smoothstep(0.02, 0.25, up);
		col = mix(col, tone, cloud * fade);
		col = mix(col, ink_color, edge * fade * 0.9);
	}
	COLOR = col;
}
