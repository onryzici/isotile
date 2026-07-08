// Birim altı yumuşak blob gölge — billboard sprite'lar gerçek gölge
// düşüremediği için siyah karaltı (radyal gradyan, kenarı yumuşak).
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never;

uniform float opacity : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.0);
	// Ayak dibinde koyu dolgun çekirdek + yumuşak kenar (kontakt gölge):
	// merkez tamamen siyah, dışa doğru süzülür.
	float core = 1.0 - smoothstep(0.0, 0.55, d);   // yoğun iç karaltı
	float halo = 1.0 - smoothstep(0.35, 1.0, d);   // yumuşak dış hale
	ALPHA = max(core, halo * 0.55) * opacity;
}
