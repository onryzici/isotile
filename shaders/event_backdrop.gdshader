// Kart Olayı arka karartması (gelistirme §15.5): kart ortadayken harita halftone
// puslu karartmayla geri çekilir — fog_of_war ile aynı Bayer dither dili, radyal
// (merkez daha açık) + TIME ile hafif dalgalı. strength beliriş animasyonu içindir.
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint : source_color = vec4(0.045, 0.038, 0.085, 1.0);
uniform vec2 screen_size = vec2(1920.0, 1080.0);
uniform float cell_px = 4.0;

// 4×4 Bayer matrisi (fog_of_war ile aynı) — klasik halftone deseni
float bayer(vec2 px) {
	int x = int(mod(px.x / cell_px, 4.0));
	int y = int(mod(px.y / cell_px, 4.0));
	int m[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

void fragment() {
	vec2 px = SCREEN_UV * screen_size;
	vec2 c = screen_size * 0.5;
	float d = distance(px, c) / (length(screen_size) * 0.5);
	// canlı pus sınırı: iki frekanslı dalgalanma
	float wob = sin(TIME * 0.7 + px.x * 0.012 + px.y * 0.010) * 0.05
			+ sin(TIME * 0.45 - px.y * 0.018 + px.x * 0.006) * 0.04;
	float fog = clamp(0.5 + d * 0.65 + wob, 0.0, 1.0) * strength;
	float m = step(bayer(px), fog);
	// düz taban karartma + üstüne halftone noktalar
	float a = clamp(0.42 * strength + m * 0.45, 0.0, 0.94) * strength;
	COLOR = vec4(tint.rgb, a);
}
