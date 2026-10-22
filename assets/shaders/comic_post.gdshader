shader_type spatial;
// Full-screen comic pass, drawn on a quad attached to the camera (scripts/comic_style.gd).
// Reads the opaque scene's colour and depth and adds:
//  - ink outlines from depth jumps, surface creases and strong colour edges
//  - world-anchored hatching and ink speckle in the darkest areas (no "shower door" swimming)
//  - a light grade towards the navy / warm-yellow palette
// The sky keeps its own look. Transparent effects (labels, particles) draw on top of this pass.
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

uniform vec3 ink_color : source_color = vec3(0.025, 0.03, 0.06);
uniform float line_width = 1.4;
uniform float depth_edge = 0.045;
uniform float crease_edge = 0.55;
uniform float color_edge = 0.28;
uniform float line_fade_start = 90.0;
uniform float line_fade_end = 260.0;
uniform float hatch_strength = 0.55;
uniform float hatch_threshold = 0.12;
uniform float hatch_density = 9.0;
uniform float hatch_fade_start = 10.0;
uniform float hatch_fade_end = 26.0;
uniform float saturation = 0.92;
uniform vec3 highlight_tint = vec3(1.06, 1.0, 0.88);

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

vec3 view_position(vec2 uv, mat4 inv_projection) {
	float depth = texture(depth_tex, uv).r;
	vec4 view = inv_projection * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
	return view.xyz / view.w;
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = line_width * max(VIEWPORT_SIZE.y / 800.0, 1.0) / VIEWPORT_SIZE;
	vec3 color = texture(screen_tex, uv).rgb;
	float raw_depth = texture(depth_tex, uv).r;
	bool sky = raw_depth >= 0.99999;

	vec3 p = view_position(uv, INV_PROJECTION_MATRIX);
	vec3 pl = view_position(uv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	vec3 pr = view_position(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	vec3 pu = view_position(uv - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	vec3 pd = view_position(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float dist = -p.z;

	// Silhouettes: depth jumps, relative to distance so far trees still get lines.
	float d = -p.z, dl = -pl.z, dr = -pr.z, du = -pu.z, dd = -pd.z;
	float jump = (abs(dl + dr - 2.0 * d) + abs(du + dd - 2.0 * d)) / max(d, 0.5);
	float depth_line = smoothstep(depth_edge, depth_edge * 2.0, jump);
	// Creases: the surface turns sharply between neighbouring pixels.
	vec3 n_a = normalize(cross(pr - p, pd - p));
	vec3 n_b = normalize(cross(p - pl, p - pu));
	float crease_line = (1.0 - smoothstep(crease_edge, crease_edge + 0.15, dot(n_a, n_b))) * (1.0 - smoothstep(25.0, 60.0, dist));
	// Strong colour edges: faces, clothing, weapon parts.
	float ll = luma(texture(screen_tex, uv - vec2(px.x, 0.0)).rgb);
	float lr = luma(texture(screen_tex, uv + vec2(px.x, 0.0)).rgb);
	float lu = luma(texture(screen_tex, uv - vec2(0.0, px.y)).rgb);
	float ld = luma(texture(screen_tex, uv + vec2(0.0, px.y)).rgb);
	float l = luma(color);
	float contrast = length(vec2(lr - ll, ld - lu)) / max(l + 0.1, 0.1);
	float color_line = smoothstep(color_edge, color_edge * 2.0, contrast) * (1.0 - smoothstep(30.0, 70.0, dist));

	float line = max(depth_line, max(crease_line, color_line)) * (1.0 - smoothstep(line_fade_start, line_fade_end, dist));
	if (sky) {
		// Only the outline of whatever stands against the sky.
		line = depth_line;
	}

	// Grade: slightly calmer colours, warm lift in the brightest areas.
	vec3 graded = mix(vec3(l), color, saturation);
	graded *= mix(vec3(1.0), highlight_tint, smoothstep(0.35, 0.8, l));

	if (!sky) {
		// Ink in the darkest band, anchored to the world: diagonal hatching plus round speckles.
		vec3 world = (INV_VIEW_MATRIX * vec4(p, 1.0)).xyz;
		vec3 w = abs((INV_VIEW_MATRIX * vec4(n_a, 0.0)).xyz);
		vec2 plane = w.y > max(w.x, w.z) ? world.xz : (w.x > w.z ? world.zy : world.xy);
		float shadow = 1.0 - smoothstep(hatch_threshold * 0.5, hatch_threshold, l);
		float near = 1.0 - smoothstep(hatch_fade_start, hatch_fade_end, dist);
		float hatch = step(0.78, fract((plane.x + plane.y) * hatch_density));
		vec2 cell = floor(plane * hatch_density * 2.2);
		vec2 inside = fract(plane * hatch_density * 2.2) - 0.5;
		float rnd = hash12(cell);
		float speckle = step(0.9, rnd) * step(length(inside), 0.32);
		// A few finer dots in the mid-tones too, so lit ground still reads as inked paper.
		float midtone = 1.0 - smoothstep(0.2, 0.45, l);
		float fine = step(0.975, rnd) * step(length(inside), 0.2) * midtone * (1.0 - shadow);
		graded = mix(graded, ink_color, (max(hatch * 0.55, speckle) * shadow + fine * 0.7) * near * hatch_strength);
	} else {
		graded = color;
	}

	ALBEDO = mix(graded, ink_color, line);
}
