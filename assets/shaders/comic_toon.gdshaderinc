// Toon stand-in for StandardMaterial3D. scripts/comic_style.gd builds the material from the
// original one (colour, texture, vertex colours, UVs, cutout) and adds the cull / cutout header.
#include "res://assets/shaders/comic_light.gdshaderinc"
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform bool use_vertex_color = false;
uniform bool vertex_color_srgb = false;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
// Pre-lit billboards (distant trees) take light as if they faced up, so they match nearby trees.
uniform bool flat_up_normal = false;
uniform float alpha_scissor = 0.5;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
}

void fragment() {
	vec4 color = albedo;
	if (use_texture) {
		color *= texture(albedo_texture, UV);
	}
	if (use_vertex_color) {
		vec4 vc = COLOR;
		if (vertex_color_srgb) {
			vc.rgb = mix(vc.rgb / 12.92, pow((vc.rgb + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), vc.rgb));
		}
		color *= vc;
	}
	ALBEDO = color.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (flat_up_normal) {
		NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	}
#ifdef COMIC_CUTOUT
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
#endif
}
