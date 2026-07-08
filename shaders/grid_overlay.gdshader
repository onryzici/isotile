// Tile overlay — referans stili: merkez ŞEFFAF (zemin görünür), parlak NEON
// kenar (glow bloom'la parlar). Yeşil = deployment, kırmızı = tehlike,
// turuncu = hareket hedefi, sarı = seçim. QuadMesh/PlaneMesh (UV 0-1).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.15, 0.1, 0.9);
uniform float border_width : hint_range(0.01, 0.3) = 0.055;
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.05;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.4;
uniform float emission_strength : hint_range(0.0, 8.0) = 3.2;

void fragment() {
	vec2 d = min(UV, 1.0 - UV);
	float edge_dist = min(d.x, d.y);
	// keskin iç çizgi + yumuşak dış hale (bloom için)
	float line = 1.0 - smoothstep(0.0, border_width, edge_dist);
	float glow = 1.0 - smoothstep(0.0, border_width * 3.2, edge_dist);
	float pulse = 0.90 + 0.10 * sin(TIME * pulse_speed);
	ALBEDO = color.rgb;
	EMISSION = color.rgb * emission_strength * pulse * max(line, glow * 0.45);
	ALPHA = color.a * max(line, max(glow * 0.3, fill_alpha)) * pulse;
}
