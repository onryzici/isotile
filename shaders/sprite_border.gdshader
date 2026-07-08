// Sprite iç-kenar (inside border): silüetin İÇİNE doğru siyah rim.
// Billboard sprite'a uygulanır; alfa kenarına yakın opak pikseller siyaha boyanır.
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_opaque, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear;
uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float border_px : hint_range(0.0, 40.0) = 12.0;
uniform float cutoff : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	// Billboard (kameraya bak) — Sprite3D.billboard kapalı olmalı.
	// VERTEX zaten pixel_size ile boyutlanmış; sadece yönlendiriyoruz.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < cutoff) {
		discard;
	}
	vec2 texel = 1.0 / vec2(textureSize(tex, 0));
	// 8 yön × 4 halka — kaynak-texel'de dolgun iç border (oyun zoom'unda görünür)
	float edge = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7853982;   // 45°
		vec2 dir = vec2(cos(ang), sin(ang));
		for (int r = 1; r <= 4; r++) {
			float rr = border_px * float(r) / 4.0;
			if (texture(tex, UV + dir * rr * texel).a < cutoff) {
				edge = 1.0;
			}
		}
	}
	ALBEDO = mix(c.rgb, border_color.rgb, edge);
	ALBEDO *= COLOR.rgb;   // Sprite3D.modulate (hit_flash kırmızısı) korunur
	ALPHA = 1.0;
}
