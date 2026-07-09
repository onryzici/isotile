// Tile overlay — referans (Master of Piece) stili: düz renk değil, ÖRGÜLÜ KAFES.
// Çift çerçeve + iç crosshatch lattice + köşe artıları → detaylı "bölge" hissi.
// Yeşil = deployment, kırmızı = tehlike, turuncu = hareket, sarı = seçim.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.15, 0.1, 0.9);
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.06;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.2;
uniform float emission_strength : hint_range(0.0, 8.0) = 2.6;
uniform float lattice_freq : hint_range(1.0, 10.0) = 4.0;

float line_soft(float x, float w) {
	return 1.0 - smoothstep(0.0, w, x);
}

void fragment() {
	vec2 uv = UV;
	vec2 d = min(uv, 1.0 - uv);
	float edge = min(d.x, d.y);

	// ── Çift çerçeve (kenardan hafif içeride) ──
	float frame = line_soft(abs(edge - 0.055), 0.016);        // iç çizgi
	frame = max(frame, line_soft(abs(edge - 0.09), 0.010));   // ikinci ince çizgi

	// ── İç crosshatch kafes (örgü hissi) — yalnız kenarın içinde ──
	float inside = smoothstep(0.075, 0.12, edge);
	float a = abs(fract((uv.x + uv.y) * lattice_freq) - 0.5);
	float b = abs(fract((uv.x - uv.y) * lattice_freq) - 0.5);
	float lat = max(line_soft(a, 0.05), line_soft(b, 0.05)) * inside;

	// ── Merkez artı işareti ──
	float cx = line_soft(abs(uv.x - 0.5), 0.02) * line_soft(abs(uv.y - 0.5), 0.10);
	float cy = line_soft(abs(uv.y - 0.5), 0.02) * line_soft(abs(uv.x - 0.5), 0.10);
	float cross = max(cx, cy) * 0.6;

	float pattern = max(frame, max(lat * 0.55, cross));
	float pulse = 0.86 + 0.14 * sin(TIME * pulse_speed);

	ALBEDO = color.rgb;
	EMISSION = color.rgb * emission_strength * pulse * pattern;
	ALPHA = color.a * max(pattern, fill_alpha) * pulse;
}
