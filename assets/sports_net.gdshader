shader_type spatial;
render_mode cull_disabled;
void fragment(){
    vec2 cell=fract(UV*vec2(55.0,14.0));
    float wire=max(step(cell.x,.07),step(cell.y,.07));
    float band=step(UV.y,.035)+step(.975,UV.y);
    ALBEDO=mix(vec3(.08,.12,.10),vec3(.8,.82,.75),min(band,1.0));
    ALPHA=max(wire,min(band,1.0));
    ALPHA_SCISSOR_THRESHOLD=.5;
    ROUGHNESS=.95;
}
