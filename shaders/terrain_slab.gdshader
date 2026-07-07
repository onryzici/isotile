// Zemin plakası shader'ı (§7): koyu taban + noise damarlarından sızan ışık.
// Liquid görünüm: 4 oktav fbm + domain warping (noise'u noise'la bük) —
// kare value-noise lekeleri yerine kıvrılan, akışkan damarlar.
shader_type spatial;
render_mode cull_back;

uniform vec4 base_color : source_color = vec4(0.08, 0.07, 0.06, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.35, 0.08, 1.0);
uniform float glow_strength : hint_range(0.0, 3.0) = 0.9;
uniform float vein_scale : hint_range(0.5, 16.0) = 3.0;
uniform float vein_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float anim_speed : hint_range(0.0, 2.0) = 0.12;
uniform float warp_amount : hint_range(0.0, 4.0) = 2.2;

varying vec3 wpos;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Damarlar YALNIZ üst yüzde — yan yüzlerde world-XZ noise'u dikeyde
	// yayılıp bozuk durur; yanlar düz koyu kenar olarak kalır.
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (world_normal.y < 0.7) {
		ALBEDO = base_color.rgb * 0.55;
		EMISSION = vec3(0.0);
	} else {
		vec2 p = wpos.xz * vein_scale;
		// domain warp: akışkan kıvrımlar
		vec2 q = vec2(
			fbm(p + vec2(TIME * anim_speed * 0.35, 0.0)),
			fbm(p + vec2(5.2, 1.3) - vec2(0.0, TIME * anim_speed * 0.25)));
		float f = fbm(p + q * warp_amount);
		// çekirdek damar + yumuşak hale
		float core = smoothstep(vein_threshold, vein_threshold + 0.09, f);
		float halo = smoothstep(vein_threshold - 0.14, vein_threshold + 0.12, f);
		ALBEDO = mix(base_color.rgb, glow_color.rgb * 0.5, halo * 0.55);
		EMISSION = glow_color.rgb * (core * glow_strength + halo * glow_strength * 0.3);
	}
}
