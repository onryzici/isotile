// PUS toon/cel shader — ışığı bandlara quantize eder (CLAUDE.md §16.2).
// Referans ton (Master of Piece): desatüre, el boyaması benekli üst yüzler,
// simsiyaha yakın yan yüzler, düşük doygunluk. Benekleme world-space value
// noise ile — doku asset'i gerektirmez.
shader_type spatial;
render_mode cull_back;

uniform vec4 top_color : source_color = vec4(0.30, 0.36, 0.17, 1.0);
uniform vec4 side_color : source_color = vec4(0.10, 0.08, 0.07, 1.0);
uniform bool use_side_split = false;
uniform int band_count : hint_range(2, 4) = 3;
uniform float band_softness : hint_range(0.0, 0.2) = 0.02;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 4.0) = 0.0;
uniform float mottle_strength : hint_range(0.0, 1.0) = 0.45;   // el boyaması benek şiddeti
uniform float mottle_scale : hint_range(0.2, 8.0) = 2.3;
uniform bool is_ground = false;   // sadece zemin tile'ları: çim/toprak detay + kenar çerçevesi

varying vec3 world_pos;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 base = top_color.rgb;
	if (use_side_split && wn.y < 0.7) {
		// KAYALIK TAŞ YAN YÜZ (tileset benzeri): açık/koyu taş blokları + derz + yosun
		vec3 sc = world_pos;
		float rock = vnoise(sc.xz * 2.6 + sc.y * 2.2) * 0.6
			+ vnoise(sc.xz * 7.0 + sc.y * 6.0 + 11.0) * 0.4;
		vec3 stone_d = side_color.rgb + vec3(0.02);
		vec3 stone_l = side_color.rgb * 3.6 + vec3(0.07, 0.065, 0.06);
		base = mix(stone_d, stone_l, rock);
		// koyu derz/çatlak çizgileri (taş bloklar arası)
		float grout = smoothstep(0.44, 0.5, vnoise(sc.xz * 5.5 + sc.y * 4.5 + 30.0));
		base *= 1.0 - 0.42 * grout;
		// üstten sızan yosun
		float moss = smoothstep(0.66, 0.9, vnoise(sc.xz * 4.0 + sc.y * 2.5 + 60.0));
		base = mix(base, vec3(0.16, 0.24, 0.10), moss * 0.55);
	} else {
		// hafif iki-oktav benek (muddy koyu yama YOK — temiz stilize taban)
		float n = vnoise(world_pos.xz * mottle_scale) * 0.65
			+ vnoise(world_pos.xz * mottle_scale * 3.1 + 13.7) * 0.35;
		base *= mix(1.0 - mottle_strength * 0.28, 1.0 + mottle_strength * 0.18, n);

		if (is_ground) {
			// KOYU · DESATÜRE · PAINTERLY (referans ton: cırtlak renk YOK, benek YOK)
			// hafif desatürasyon → muted yüzey
			float luma = dot(base, vec3(0.30, 0.60, 0.10));
			base = mix(base, vec3(luma), 0.22) * 0.92;
			// yumuşak düşük-kontrast ton kırılması (painterly)
			vec3 g_lo = base * vec3(0.86, 0.90, 0.86);
			vec3 g_hi = base * vec3(1.04, 1.07, 0.98);
			float g = smoothstep(0.32, 0.72, vnoise(world_pos.xz * 1.3 + 20.0));
			base = mix(g_lo, g_hi, g);
			// ince painterly çatlak/damar (kuru toprak-taş — koyu ince çizgiler)
			float veins = smoothstep(0.68, 0.86, vnoise(world_pos.xz * 5.2 + 77.0));
			base *= 1.0 - 0.14 * veins;
			float veins2 = smoothstep(0.74, 0.9, vnoise(world_pos.xz * 9.0 + 133.0));
			base *= 1.0 - 0.08 * veins2;
			// çok seyrek, MUTED açık çim tutamı (kendi renginin hafif açığı — cırtlak değil)
			float blade = smoothstep(0.955, 0.99, vnoise(world_pos.xz * 22.0 + 61.0));
			base = mix(base, base * vec3(1.14, 1.20, 1.02), blade * 0.45);
			// ince painterly gren
			base *= 0.97 + 0.05 * vnoise(world_pos.xz * 10.0);
			// hafif domlu aydınlatma (stilize kabartma — düşük şiddet)
			vec2 fp = abs(fract(world_pos.xz) - 0.5);
			float d = max(fp.x, fp.y);
			base *= 0.95 + 0.08 * (1.0 - d * 1.6);
			// inset çerçeve (tile ayrımı) — koyu cel kenar, neon değil
			float frame = smoothstep(0.42, 0.487, d);
			base *= 1.0 - 0.30 * frame;
		}
	}
	ALBEDO = base;
	EMISSION = emission_color.rgb * emission_strength;
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float bands = float(band_count);
	float banded = 0.0;
	for (int i = 1; i < band_count; i++) {
		float edge = float(i) / bands;
		banded += smoothstep(edge - band_softness, edge + band_softness, ndotl);
	}
	banded /= (bands - 1.0);
	// Karanlık-moody ton: gölge tabanı düşük, tepe hafif kısık (cıvıllık yok)
	float lit = mix(0.3, 1.05, banded);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * lit / PI;
}
