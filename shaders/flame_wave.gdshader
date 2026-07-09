shader_type spatial;
// depth_draw_never: saydam, derinlik YAZMAZ; ama derinlik TESTİ açık → yakındaki
// karakterlerin arkasında kalır (perspektif doğru). Kendi biriminin önünde
// görünmesi GDScript'te kameraya doğru küçük offset ile sağlanır.
render_mode cull_disabled, unshaded, blend_mix, depth_draw_never;
// Boyalı alevi dalgalandırır + rengini ANLIK titreştirir (dipte kızıl, ortada
// turuncu, sıcak noktalar sarı-beyaz — bölge bölge bağımsız oynar → yaşayan ateş).
// Tam billboard (ölçeği korur). poison için yeşil rampa GDScript'ten verilir.

uniform sampler2D tex : source_color, filter_linear;
uniform float wave_speed = 3.2;
uniform float wave_amp = 0.05;
uniform float flicker_speed = 10.0;
uniform float color_speed = 7.0;
uniform vec3 col_low : source_color = vec3(0.70, 0.12, 0.03);   // dip: koyu kızıl
uniform vec3 col_mid : source_color = vec3(1.0, 0.50, 0.10);    // orta: turuncu
uniform vec3 col_hot : source_color = vec3(1.0, 0.95, 0.60);    // sıcak: sarı-beyaz
uniform float brightness = 1.3;
uniform float fade = 1.0;   // spawn/despawn alpha çarpanı
uniform float seed = 0.0;   // katmanlar/örnekler arası faz farkı

void vertex() {
	// Y-DİK billboard: alev dünya-dik durur, yalnız Y ekseninde kameraya döner
	// (izometrik yapıya uyar; tam-billboard gibi geriye yatmaz). Ölçek korunur.
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 obj = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 fwd = normalize(vec3(cam.x - obj.x, 0.0, cam.z - obj.z));
	vec3 right = vec3(fwd.z, 0.0, -fwd.x);
	vec3 up = vec3(0.0, 1.0, 0.0);
	mat4 model = mat4(vec4(right * sx, 0.0), vec4(up * sy, 0.0), vec4(fwd, 0.0), vec4(obj, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * model;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * wave_speed + seed;
	float tip = 1.0 - uv.y;   // uv.y=0 (tepe) → 1, kök → 0
	float sway = sin(uv.y * 6.0 + t) * wave_amp * tip;
	sway += sin(uv.y * 13.0 - t * 1.7) * wave_amp * 0.5 * tip;
	uv.x += sway;
	uv.y += sin(t * 0.7 + uv.x * 3.0) * 0.015 * tip;
	vec4 c = texture(tex, uv);

	// Doku yoğunluğunu ateş rampasına eşle; rampayı zamanla + konuma göre titret
	float L = max(c.r, max(c.g, c.b));
	float fn = 0.5 + 0.5 * sin(TIME * color_speed + uv.x * 18.0 + seed);
	fn *= 0.6 + 0.4 * sin(TIME * color_speed * 0.6 + uv.y * 7.0 - seed);
	float h = clamp(L * (0.72 + 0.62 * fn), 0.0, 1.0);
	vec3 fire = mix(col_low, col_mid, smoothstep(0.18, 0.55, h));
	fire = mix(fire, col_hot, smoothstep(0.60, 0.95, h));

	float fl = 0.85 + 0.15 * sin(TIME * flicker_speed + seed * 3.1);
	ALBEDO = fire * brightness;
	ALPHA = c.a * fl * fade;
}
