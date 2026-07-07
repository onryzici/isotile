// Birim altı yumuşak blob gölge — billboard sprite'lar gerçek gölge
// düşüremediği için siyah karaltı (radyal gradyan, kenarı yumuşak).
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never;

uniform float opacity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - smoothstep(0.45, 1.0, d)) * opacity;
}
