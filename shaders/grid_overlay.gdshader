// Emissive grid overlay — tile üstü vurgu (CLAUDE.md §16.4).
// Referans screenshot stili: tile KENARLARI akkor çizgi gibi parlar,
// iç dolgu hafif. Yeşil = deployment, kırmızı = tehlike, sarı = seçim.
// QuadMesh/PlaneMesh üzerinde çalışır (UV 0-1 temiz olmalı).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque;

uniform vec4 color : source_color = vec4(1.0, 0.15, 0.1, 0.9);
uniform float border_width : hint_range(0.01, 0.3) = 0.07;
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.12;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.2;
uniform float emission_strength : hint_range(0.0, 6.0) = 1.0;

void fragment() {
	vec2 d = min(UV, 1.0 - UV);
	float edge_dist = min(d.x, d.y);
	float border = 1.0 - smoothstep(border_width * 0.5, border_width, edge_dist);
	float pulse = 0.9 + 0.1 * sin(TIME * pulse_speed);
	ALBEDO = color.rgb;
	EMISSION = color.rgb * emission_strength * pulse * max(border, fill_alpha * 0.35);
	ALPHA = color.a * max(border, fill_alpha) * pulse;
}
