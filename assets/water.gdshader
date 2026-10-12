shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float waves = sin(world_position.x*0.23+TIME*0.65)*sin(world_position.z*0.31-TIME*0.4);
    ALBEDO = mix(vec3(0.025,0.12,0.15),vec3(0.065,0.23,0.27),waves*0.5+0.5);
    ROUGHNESS = 0.35;
    METALLIC = 0.15;
}
