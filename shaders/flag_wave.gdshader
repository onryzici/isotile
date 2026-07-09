// Bayrak sancağı: yalnız KUMAŞ bandı (cloth_top..cloth_bottom UV.y aralığı) yatayda
// dalgalanır — üstten (gönder/crossbar) sabit, alta doğru salınım artar. Gönder ucu,
// crossbar ve taş kaide kıpırdamaz. Art zaten elle-boyalı outline'lı; ek rim YOK
// (rim, dalga sırasında kenarda gezen küçük siyahlık yapıyordu — Onur geri bildirimi).
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_opaque, shadows_disabled;

// repeat_disable: dalgada UV [0,1] dışına taşınca karşı kenardan (siyah/şeffaf)
// örnek almasın — clamp'lansın. "dalgalanınca küçük siyahlık" bunu çözüyor.
uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform float cutoff : hint_range(0.0, 1.0) = 0.5;
// kumaş bandı (görselin üstünden UV): §ölçüm 0.264..0.716
uniform float cloth_top : hint_range(0.0, 1.0) = 0.28;
uniform float cloth_bottom : hint_range(0.0, 1.0) = 0.70;
uniform float wave_amp : hint_range(0.0, 0.2) = 0.028;   // UV genliği (küçük = hafif)
uniform float wave_speed : hint_range(0.0, 10.0) = 2.2;
uniform float wave_freq : hint_range(0.0, 20.0) = 7.0;

void vertex() {
	// DİKEY (Y-eksen) billboard: kamera yönüne yatayda döner ama dik kalır. Tam
	// view-plane billboard (unit shader'daki) uzun sancağın TÜM quad'ını tek
	// derinliğe (taban) çöktürüyor → tepe (mızrak ucu), üstünde durduğu tile
	// tarafından derinlikte örtülüp KESİLİYORDU. Y-billboard yerel Y'yi dünya
	// Y'sinde tutar → gerçek yükseklik+derinlik, doğru sıralama, kesilme yok.
	vec3 r = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 u = vec3(0.0, 1.0, 0.0);
	vec3 f = normalize(cross(r, u));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(r, 0.0), vec4(u, 0.0), vec4(f, 0.0), MODEL_MATRIX[3]);
}

// Kumaş için yatay UV kayması: KUMAŞ bandı DIŞINDA (üst crossbar/tip + alt TAŞ
// kaide) tam sabit; band yalnız [cloth_top, cloth_bottom] arasında 0->1 artar,
// altta (taş) sert 0.
vec2 warp(vec2 uv) {
	float band = uv.y < cloth_bottom ? smoothstep(cloth_top, cloth_bottom, uv.y) : 0.0;
	float phase = TIME * wave_speed + uv.y * wave_freq;
	uv.x += sin(phase) * wave_amp * band;
	return uv;
}

void fragment() {
	vec2 wuv = warp(UV);
	vec4 c = texture(tex, wuv);
	if (c.a < cutoff) {
		discard;
	}
	ALBEDO = c.rgb * COLOR.rgb;   // Sprite3D.modulate (hit_flash) korunur
	ALPHA = 1.0;
}
