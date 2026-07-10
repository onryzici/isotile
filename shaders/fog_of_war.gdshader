// KARA PUS fog-of-war (gelistirme.md §4, §15.3 — imza shader).
// Journey map'te keşfedilmemiş alan halftone/dither NOKTALI karanlıkla örtülür:
// açık bölgelerin (ziyaret edilmiş + mevcut katman düğümleri) etrafında pus,
// Bayer ordered-dither eşiğiyle nokta nokta çözülür. TIME ile kenar dalgalanır
// (pus canlı). Yeni açılan noktalar reveal_t ile büyür (pus çekilme animasyonu).
shader_type canvas_item;

// xy = MANTIKSAL canvas pikseli (map_screen _iso uzayı), z = açıklık yarıçapı,
// w = 1 ise yarıçap reveal_t ile çarpılır (yeni açılan bölge animasyonu).
// FRAGCOORD KULLANILMAZ: pencere ölçekleme/stretch altında fiziksel piksel döner,
// düğüm koordinatlarıyla uyuşmaz (açıklıklar sol üste kayıyordu). SCREEN_UV ×
// screen_size mantıksal uzayı her ölçekte korur.
uniform vec4 points[48];
uniform int point_count = 0;
uniform vec2 screen_size = vec2(1920.0, 1080.0);
uniform float reveal_t : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fog_color : source_color = vec4(0.055, 0.045, 0.10, 1.0);
uniform float fog_alpha : hint_range(0.0, 1.0) = 0.93;
uniform float cell_px = 4.0;   // halftone hücre boyu (px) — büyük = iri noktalar

// 4×4 Bayer matrisi: hücreye kararlı, düzenli eşik → klasik halftone deseni
float bayer(vec2 px) {
	int x = int(mod(px.x / cell_px, 4.0));
	int y = int(mod(px.y / cell_px, 4.0));
	int m[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

void fragment() {
	vec2 px = SCREEN_UV * screen_size;
	// Kenar dalgalanması: iki farklı frekans üst üste → organik, yaşayan sis sınırı
	float wob = sin(TIME * 0.9 + px.x * 0.013 + px.y * 0.011) * 16.0
			+ sin(TIME * 0.5 - px.y * 0.021 + px.x * 0.007) * 11.0;
	float vis = 0.0;
	for (int i = 0; i < point_count; i++) {
		vec4 p = points[i];
		float r = p.z * mix(1.0, reveal_t, p.w);
		float d = distance(px, p.xy) + wob;
		vis = max(vis, 1.0 - smoothstep(r * 0.45, r, d));
	}
	float fog = 1.0 - vis;
	// Halftone: fog kısmi olduğu bantta Bayer eşiğini geçen hücreler nokta olur;
	// derin pusta tüm hücreler geçer → dolu örtü.
	float m = step(bayer(px), fog);
	COLOR = vec4(fog_color.rgb, m * fog_alpha * smoothstep(0.02, 0.18, fog));
}
