// Tutorial spotlight (gelistirme §3): ekran yarı saydam siyahla kapanır,
// yalnız İLGİLİ bölge (yumuşak kenarlı yuvarlatılmış delik) açık kalır.
// hole = (x, y, w, h) mantıksal ekran pikseli. w<=0 → delik yok (düz karartma;
// koç istemiyorsa dim'i 0'a çeker).
shader_type canvas_item;

uniform vec4 hole = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec2 screen_size = vec2(1920.0, 1080.0);
uniform float dim : hint_range(0.0, 1.0) = 0.55;
uniform float feather = 34.0;
uniform float rounding = 16.0;

float sd_round_rect(vec2 p, vec2 c, vec2 half_sz, float r) {
	vec2 d = abs(p - c) - half_sz + vec2(r);
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

void fragment() {
	vec2 px = SCREEN_UV * screen_size;
	float a = dim;
	if (hole.z > 0.5) {
		float d = sd_round_rect(px, hole.xy + hole.zw * 0.5, hole.zw * 0.5, rounding);
		a = dim * smoothstep(0.0, feather, d);
	}
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
