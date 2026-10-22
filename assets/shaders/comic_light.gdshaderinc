// Comic / cel lighting shared by every lit material in the game.
// Each light is snapped to three flat bands; the unlit band is the environment's navy ambient.
// The comic_amount global (project settings > shader globals) blends back to smooth lighting.
global uniform float comic_amount;
uniform float comic_gloss = 0.0;

float comic_bands(float lit) {
	return smoothstep(0.02, 0.07, lit) * 0.55 + smoothstep(0.3, 0.36, lit) * 0.3 + smoothstep(0.68, 0.74, lit) * 0.15;
}

void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(lit, comic_bands(lit), comic_amount);
	if (comic_gloss > 0.0) {
		float spec = pow(clamp(dot(NORMAL, normalize(VIEW + LIGHT)), 0.0, 1.0), 40.0) * ATTENUATION;
		SPECULAR_LIGHT += LIGHT_COLOR / PI * comic_gloss * mix(spec, smoothstep(0.45, 0.5, spec), comic_amount);
	}
}
