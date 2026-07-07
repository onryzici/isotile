// PUS toon/cel shader — ışığı bandlara quantize eder (CLAUDE.md §16.2).
// Referans ton (Master of Piece): desatüre, el boyaması benekli üst yüzler,
// simsiyaha yakın yan yüzler, düşük doygunluk. Benekleme world-space value
// noise ile — doku asset'i gerektirmez.
shader_type spatial;
render_mode cull_back;

uniform vec4 top_color : source_color = vec4(0.30, 0.36, 0.17, 1.0);
uniform vec4 side_color : source_color = vec4(0.10, 0.08, 0.07, 1.0);
uniform bool use_side_split = false;
uniform int band_count : hint_range(2, 4) = 3;
uniform float band_softness : hint_range(0.0, 0.2) = 0.02;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 4.0) = 0.0;
uniform float mottle_strength : hint_range(0.0, 1.0) = 0.45;   // el boyaması benek şiddeti
uniform float mottle_scale : hint_range(0.2, 8.0) = 2.3;

varying vec3 world_pos;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 base = top_color.rgb;
	if (use_side_split && wn.y < 0.7) {
		base = side_color.rgb;
	} else {
		// iki oktav benek + seyrek koyu yama: boyalı zemin hissi
		float n = vnoise(world_pos.xz * mottle_scale) * 0.65
			+ vnoise(world_pos.xz * mottle_scale * 3.1 + 13.7) * 0.35;
		base *= mix(1.0 - mottle_strength * 0.45, 1.0 + mottle_strength * 0.2, n);
		float patch = smoothstep(0.66, 0.8, vnoise(world_pos.xz * 1.15 + 47.0));
		base = mix(base, base * 0.7, patch * mottle_strength);
	}
	ALBEDO = base;
	EMISSION = emission_color.rgb * emission_strength;
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float bands = float(band_count);
	float banded = 0.0;
	for (int i = 1; i < band_count; i++) {
		float edge = float(i) / bands;
		banded += smoothstep(edge - band_softness, edge + band_softness, ndotl);
	}
	banded /= (bands - 1.0);
	// Karanlık-moody ton: gölge tabanı düşük, tepe hafif kısık (cıvıllık yok)
	float lit = mix(0.3, 1.05, banded);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * lit / PI;
}
