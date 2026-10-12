shader_type spatial;
render_mode cull_back;
uniform sampler2D pose_positions : filter_nearest, repeat_disable;
uniform sampler2D pose_normals : filter_nearest, repeat_disable;
uniform vec3 pose_min;
uniform vec3 pose_extent;
uniform float animation_clock = 0.0;
uniform float row_stride;
uniform float frames_per_clip = 24.0;
uniform float clip_lengths[5];

void vertex() {
    int clip = clamp(int(INSTANCE_CUSTOM.z + 0.5), 0, 4);
    float frame = fract((animation_clock + INSTANCE_CUSTOM.x) * INSTANCE_CUSTOM.y / clip_lengths[clip]) * frames_per_clip;
    float first = floor(frame);
    float second = mod(first + 1.0, frames_per_clip);
    float base = float(clip) * frames_per_clip;
    vec2 uv_a = UV2 + vec2(0.0, (base + first) * row_stride);
    vec2 uv_b = UV2 + vec2(0.0, (base + second) * row_stride);
    VERTEX = pose_min + mix(texture(pose_positions, uv_a).xyz, texture(pose_positions, uv_b).xyz, fract(frame)) * pose_extent;
    NORMAL = normalize(mix(texture(pose_normals, uv_a).xyz, texture(pose_normals, uv_b).xyz, fract(frame)) * 2.0 - 1.0);
    // Preserve skin/hair; vary clothing using the baked vertex-color alpha mask.
    vec3 tint = mix(vec3(0.75, 0.86, 1.12), vec3(1.12, 0.90, 0.72), INSTANCE_CUSTOM.w);
    COLOR.rgb *= mix(vec3(1.0), tint, COLOR.a);
}

void fragment() {
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 0.88;
}
