shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform float clock=0.0;
uniform float lifetime=65.0;
varying vec4 tread_data;
void vertex(){tread_data=INSTANCE_CUSTOM;}
void fragment(){
    float age=clock-tread_data.x;
    float fade=1.0-smoothstep(lifetime*.65,lifetime,age);
    float edges=smoothstep(0.0,.14,UV.x)*smoothstep(0.0,.14,1.0-UV.x);
    float grooves=mix(.55,1.0,step(.22,fract(UV.y*10.0)));
    grooves=mix(grooves,1.0,smoothstep(.6,.9,tread_data.y));
    ALBEDO=mix(vec3(.035,.034,.031),vec3(.14,.095,.047),tread_data.z);
    ALPHA=edges*grooves*tread_data.y*fade;
    ROUGHNESS=1.0;
}
