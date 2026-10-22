shader_type spatial;
render_mode cull_disabled;
#include "res://assets/shaders/comic_light.gdshaderinc"
uniform sampler2D leaf_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.55, 0.72, 0.46, 1.0);
uniform float wind_strength = 0.065;
uniform bool near_grass = false;
varying vec3 vegetation_world;
void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vegetation_world=world;
    float height = max(VERTEX.y, 0.0);
    float phase = TIME * 1.1 + world.x * 0.13 + world.z * 0.09;
    VERTEX.x += sin(phase) * wind_strength * min(height, 2.0);
    VERTEX.z += cos(phase * 0.77) * wind_strength * min(height, 2.0) * 0.45;
}
void fragment() {
    if (near_grass) {
        float distance_to_camera=distance(vegetation_world.xz,INV_VIEW_MATRIX[3].xz);
        float fade=1.0-smoothstep(22.0,40.0,distance_to_camera);
        float grain=fract(sin(dot(floor(vegetation_world.xz*30.0),vec2(12.9898,78.233)))*43758.5453);
        if(grain>fade)discard;
    }
    vec4 sample_color = texture(leaf_texture, UV);
    ALBEDO = sample_color.rgb * tint.rgb;
    ALPHA = sample_color.a;
    ALPHA_SCISSOR_THRESHOLD = 0.4;
    ROUGHNESS = 0.95;
    BACKLIGHT = vec3(0.16);
}
