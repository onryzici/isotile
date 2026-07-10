// Bayrak sancağı: yalnız İÇ KUMAŞ ALANI dalgalanır. Gönder ucu, crossbar, sol/sağ
// rijit direkler ve alt altın şerit KIPIRDAMAZ.
//
// Neden: eski sürüm [cloth_top, cloth_bottom] arasındaki HER ŞEYİ yatayda kaydırıyordu.
// Kayma uv.y'ye bağlı olduğundan dikey direkler MAKASLANIYOR, alt şeridin dış köşeleri
// silüetin dışına taşıp discard ile basamaklanıyordu → Onur'un gördüğü "kesik köşeler".
// Çözüm: kayma genliği, kumaş dikdörtgeninin DÖRT KENARINDA da 0'a inen bir pencereyle
// çarpılır (sin(pi*t) profili) → kumaş direklere çivilenmiş gibi ortadan şişer.
// Ölçüm (flag_blue.png, 143x250): mavi alan UV x[0.287..0.769] y[0.264..0.716].
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_opaque, shadows_disabled;

// repeat_disable: kayma sırasında UV [0,1] dışına çıkarsa karşı kenardan örnek almasın.
// Doku ayrıca 12px şeffaf yatay payla kaydedildi (ek güvenlik payı).
uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform float cutoff : hint_range(0.0, 1.0) = 0.5;

// Kumaş dikdörtgeni (dalga yalnız burada; kenarlarda genlik 0)
uniform float cloth_left : hint_range(0.0, 1.0) = 0.287;
uniform float cloth_right : hint_range(0.0, 1.0) = 0.769;
uniform float cloth_top : hint_range(0.0, 1.0) = 0.264;
uniform float cloth_bottom : hint_range(0.0, 1.0) = 0.716;

uniform float wave_amp : hint_range(0.0, 0.2) = 0.016;   // UV genliği (kumaş içinde tepe)
uniform float wave_speed : hint_range(0.0, 10.0) = 1.8;
uniform float wave_freq : hint_range(0.0, 20.0) = 5.0;
uniform float shade_strength : hint_range(0.0, 1.0) = 0.28;  // kıvrım gölgesi

void vertex() {
	// DİKEY (Y-eksen) billboard: kamera yönüne yatayda döner ama dik kalır. Tam
	// view-plane billboard uzun sancağın TÜM quad'ını tek derinliğe (taban)
	// çöktürüyor → tepe (mızrak ucu) üstünde durduğu tile tarafından örtülüp
	// kesiliyordu. Y-billboard yerel Y'yi dünya Y'sinde tutar → doğru sıralama.
	vec3 r = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 u = vec3(0.0, 1.0, 0.0);
	vec3 f = normalize(cross(r, u));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(r, 0.0), vec4(u, 0.0), vec4(f, 0.0), MODEL_MATRIX[3]);
}

// Kumaş dikdörtgeninde 0..1'e normalize edilmiş koordinat (dışarıda 0 veya 1'e clamp)
vec2 cloth_uv(vec2 uv) {
	return clamp(vec2(
		(uv.x - cloth_left) / max(cloth_right - cloth_left, 1e-4),
		(uv.y - cloth_top) / max(cloth_bottom - cloth_top, 1e-4)), 0.0, 1.0);
}

// Dört kenarda 0, ortada 1 olan pencere → rijit çerçeve asla oynamaz
float pin_window(vec2 c) {
	return sin(PI * c.x) * sin(PI * c.y);
}

// Kumaşın anlık yatay kayması (aynı formül gölge için türev almakta da kullanılır)
float wave_at(vec2 uv) {
	vec2 c = cloth_uv(uv);
	float phase = TIME * wave_speed + c.y * wave_freq + c.x * 2.0;
	return sin(phase) * wave_amp * pin_window(c);
}

void fragment() {
	float w = wave_at(UV);
	vec4 col = texture(tex, vec2(UV.x + w, UV.y));
	if (col.a < cutoff) {
		discard;
	}
	// Sahte kıvrım gölgesi: kaymanın yatay türevi = kumaşın eğimi. Işığa dönük
	// kıvrım aydınlanır, ters kıvrım koyulaşır → düz kaydırma yerine "şişme" hissi.
	float slope = (wave_at(UV + vec2(0.01, 0.0)) - wave_at(UV - vec2(0.01, 0.0))) / 0.02;
	float shade = 1.0 + clamp(slope, -1.0, 1.0) * shade_strength;

	ALBEDO = col.rgb * COLOR.rgb * shade;   // Sprite3D.modulate (hit_flash) korunur
	ALPHA = 1.0;
}
