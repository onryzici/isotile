// Tutorial spotlight (gelistirme §3): ekran KARA PUS diliyle kapanır — halftone
// dither karartma (fog_of_war/event_backdrop ile aynı Bayer dokusu), yalnız
// İLGİLİ bölge (yumuşak kenarlı yuvarlatılmış delik) açık kalır. Deliğin
// kenarında ince sıcak çizgi: kesik bilinçli, "ekran karardı" sanılmasın.
// hole = (x, y, w, h) mantıksal ekran pikseli. w<=0 → delik yok.
shader_type canvas_item;

uniform vec4 hole = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec2 screen_size = vec2(1920.0, 1080.0);
uniform float dim : hint_range(0.0, 1.0) = 0.6;
uniform float feather = 46.0;
uniform float rounding = 18.0;
uniform vec4 fog_color : source_color = vec4(0.03, 0.026, 0.055, 1.0);
uniform vec4 rim_color : source_color = vec4(0.92, 0.72, 0.34, 1.0);
uniform float cell_px = 4.0;

float bayer(vec2 px) {
	int x = int(mod(px.x / cell_px, 4.0));
	int y = int(mod(px.y / cell_px, 4.0));
	int m[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

float sd_round_rect(vec2 p, vec2 c, vec2 half_sz, float r) {
	vec2 d = abs(p - c) - half_sz + vec2(r);
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

void fragment() {
	vec2 px = SCREEN_UV * screen_size;
	float mask = 1.0;
	float d = 1e6;
	if (hole.z > 0.5) {
		// canlı sınır: pus kenarı hafif dalgalanır (fog_of_war dili)
		float wob = sin(TIME * 0.8 + px.x * 0.02 + px.y * 0.017) * 6.0;
		d = sd_round_rect(px, hole.xy + hole.zw * 0.5, hole.zw * 0.5, rounding) + wob;
		mask = smoothstep(0.0, feather, d);
	}
	float fog = dim * mask;
	// taban karartma + üstüne halftone noktalar (imza doku)
	float dots = step(bayer(px), fog);
	float a = clamp(fog * 0.72 + dots * fog * 0.38, 0.0, 0.92);
	// delik kenarında ince sıcak çizgi
	float rim = 0.0;
	if (hole.z > 0.5) {
		rim = (1.0 - smoothstep(1.0, 5.0, abs(d - 2.0))) * 0.75;
	}
	vec3 col = mix(fog_color.rgb, rim_color.rgb, rim);
	COLOR = vec4(col, max(a, rim));
}
