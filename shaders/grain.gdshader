// Global film grain — ekranı okuyup işaretli gürültü ekler (analog/eski film hissi).
// Tam ekran ColorRect'e uygulanır (yüksek CanvasLayer).
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float strength : hint_range(0.0, 0.4) = 0.14;
uniform float vignette : hint_range(0.0, 1.0) = 0.28;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	// animasyonlu işaretli gürültü (-0.5..0.5)
	float t = fract(TIME) * 137.13;
	float n = hash(FRAGCOORD.xy + vec2(t, t * 1.7)) - 0.5;
	c += n * strength;
	// hafif kenar karartması (vinyet)
	vec2 q = SCREEN_UV - 0.5;
	float v = 1.0 - dot(q, q) * vignette * 2.2;
	c *= clamp(v, 0.0, 1.0);
	COLOR = vec4(c, 1.0);
}
