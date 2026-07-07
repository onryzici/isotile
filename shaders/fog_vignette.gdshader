// Pus atmosferi + vinyet (CLAUDE.md §16.6): ekran kenarlarından içeri sızan
// mor/gri sis. Tam ekran ColorRect üzerinde çalışır; TIME ile yavaşça akar.
shader_type canvas_item;

uniform vec4 mist_color : source_color = vec4(0.38, 0.22, 0.5, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float inner_radius : hint_range(0.0, 1.0) = 0.32;
uniform float outer_radius : hint_range(0.0, 1.5) = 0.78;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float d = distance(UV, vec2(0.5, 0.45));
	float vig = smoothstep(inner_radius, outer_radius, d);
	// yavaş akan iki oktav sis
	float n = vnoise(UV * 4.0 + vec2(TIME * 0.05, -TIME * 0.03)) * 0.6
		+ vnoise(UV * 9.0 - vec2(TIME * 0.02, TIME * 0.015)) * 0.4;
	float mist = vig * mix(0.6, 1.35, n);
	vec3 col = mix(vec3(0.012, 0.012, 0.03), mist_color.rgb, clamp(n * vig * 1.4, 0.0, 1.0));
	COLOR = vec4(col, clamp(mist * strength, 0.0, 0.9));
}
