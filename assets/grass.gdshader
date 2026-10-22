shader_type spatial;
render_mode cull_disabled;
#include "res://assets/shaders/comic_light.gdshaderinc"
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float stripes=smoothstep(-0.2,0.2,sin(world_position.x*0.16+world_position.z*0.035));
    float grain=fract(sin(dot(floor(world_position.xz*3.0),vec2(12.9898,78.233)))*43758.5453);
    ALBEDO=mix(vec3(0.135,0.255,0.07),vec3(0.155,0.285,0.085),stripes)+(grain-0.5)*0.009;
    ROUGHNESS=0.95;
}
