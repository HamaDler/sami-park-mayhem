shader_type spatial;
// First-person arms (scripts/first_person_arms.gd). Same toon lighting as the rest of the game,
// flat colour like the hoodie's own materials, and the torso cut away: everything within
// torso_radius of the spine (hips to neck) is discarded, so only the arms show in view.
render_mode cull_back;
#include "res://assets/shaders/comic_light.gdshaderinc"
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 spine_bottom = vec3(0.0);
uniform vec3 spine_top = vec3(0.0, 1.0, 0.0);
uniform float torso_radius = 0.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 axis = spine_top - spine_bottom;
	float along = clamp(dot(world_position - spine_bottom, axis) / max(dot(axis, axis), 0.00001), 0.0, 1.0);
	if (distance(world_position, spine_bottom + axis * along) < torso_radius) {
		discard;
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
