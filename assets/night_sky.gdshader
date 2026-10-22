shader_type sky;
// Night sky: dark gradient, warm city glow on the horizon, static stars and a moon disc
// drawn where the first directional light (the moon) is.
// No TIME use, so Godot does not re-render the sky's reflection map every frame.
uniform vec3 zenith_color : source_color = vec3(0.010, 0.016, 0.040);
uniform vec3 horizon_color : source_color = vec3(0.050, 0.058, 0.090);
uniform vec3 ground_color : source_color = vec3(0.012, 0.014, 0.020);
uniform vec3 city_glow_color : source_color = vec3(0.30, 0.17, 0.08);
uniform float city_glow_strength = 0.28;
uniform float star_density : hint_range(0.0, 1.0) = 0.4;
uniform float star_brightness = 1.6;
uniform vec3 moon_color : source_color = vec3(0.86, 0.89, 0.96);
uniform float moon_radius = 0.024;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
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
			float d = length(dir - center) * GRID;
			float star = 1.0 - smoothstep(0.0, 0.32, d);
			float tint = hash13(cell + 9.1);
			vec3 star_color = mix(vec3(1.0, 0.86, 0.72), vec3(0.78, 0.86, 1.0), tint);
			col += star_color * star * smoothstep(0.03, 0.3, up) * star_brightness * (0.25 + 0.75 * fract(h * 97.0));
		}
	}
	if (LIGHT0_ENABLED) {
		float cos_angle = dot(dir, LIGHT0_DIRECTION);
		float disc = smoothstep(cos(moon_radius), cos(moon_radius * 0.8), cos_angle);
		float halo = pow(max(cos_angle, 0.0), 900.0) * 0.22 + pow(max(cos_angle, 0.0), 60.0) * 0.025;
		col += moon_color * (disc * 1.8 + halo);
	}
	COLOR = col;
}
