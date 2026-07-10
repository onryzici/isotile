// İzometrik taş blok tile'ı: kameraya bakan billboard quad, AMA derinlik tamponuna
// quad'ın düz derinliğini değil, temsil ettiği GERÇEK KÜBİK BLOĞUN derinliğini yazar.
//
// Neden: billboard quad tek bir derinlik düzlemidir (tile merkezinin derinliği). Üstünde
// duran gerçek 3B nesneler (diken konileri, lav/pus slab'ları, duvar, bayrak) derinliği
// yüzey boyunca DEĞİŞEN nesnelerdir. İkisi karşılaşınca sabit-derinlikli quad, 3B nesnenin
// bir yarısını kesip diğer yarısının üstüne çiziliyordu → "bir kat yukarı çıkan tile
// gelince diken bloğun üstüne taşıyor, yarısı kayboluyor" (Onur).
//
// Çözüm: fragment'in ekran ışınını, tile'ın temsil ettiği eksen-hizalı kutuyla kesiştir;
// ilk kesişim noktasının derinliğini DEPTH'e yaz. Ortografik kamerada tüm ışınlar paralel,
// bu yüzden tek yön yeterli. Kutu, node konumundan türetilir (node zaten görüş ekseni
// boyunca SPRITE_DEPTH_PUSH kadar itilmiştir; ortoda ekran konumu değişmez, sadece
// derinlik kayar — birimler kendi tile'ının önünde kalsın diye).
shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_opaque, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear;
uniform float cutoff : hint_range(0.0, 1.0) = 0.5;
uniform float block_h = 0.95;      // bloğun tam yüksekliği (üst yüzden aşağı)
uniform float half_xz = 0.5;       // tile yarı genişliği (dünya)
uniform bool write_depth = true;   // hata ayıklama anahtarı (kapalı = eski düz derinlik)

void vertex() {
	// Billboard: kameraya bak. VERTEX zaten pixel_size ile boyutlanmış.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < cutoff) {
		discard;   // elmasın dışı: silüet doku alfasından gelir
	}
	// ALPHA'ya ASLA yazma: Godot, ALPHA'ya atama gören spatial shader'ı saydam
	// kuyruğa alır. Tile'lar opak kalmalı — yoksa bayrak/rozet gibi saydam
	// billboard'lar tile'lardan sonra çizilip yanlış sıralanır.
	ALBEDO = c.rgb;

	// --- gerçek blok derinliği ---
	// EPS: kutuyu bir tık şişir. Tam kenarda ışın kutuyu sayısal olarak ıskalayıp
	// varsayılan quad derinliğine düşünce, komşu tile kazanıp saç teli kalınlığında
	// koyu dikişler oluşuyordu.
	const float EPS = 0.004;
	vec3 anchor = MODEL_MATRIX[3].xyz;                 // üst yüz elmasının merkezi
	vec3 bmin = anchor - vec3(half_xz + EPS, block_h + EPS, half_xz + EPS);
	vec3 bmax = anchor + vec3(half_xz + EPS, EPS, half_xz + EPS);

	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 dir = -normalize(INV_VIEW_MATRIX[2].xyz);     // kamera ileri yönü (ortho: sabit)
	vec3 origin = world - dir * 64.0;                  // kutunun kesin önünden başla

	// Işın-kutu (slab) kesişimi
	vec3 inv = 1.0 / dir;
	vec3 t0 = (bmin - origin) * inv;
	vec3 t1 = (bmax - origin) * inv;
	vec3 tsmall = min(t0, t1);
	vec3 tbig = max(t0, t1);
	float tmin = max(max(tsmall.x, tsmall.y), tsmall.z);
	float tmax = min(min(tbig.x, tbig.y), tbig.z);

	// KRİTİK: DEPTH'e HER YOLDA yazılmalı. Vulkan'da fragment shader gl_FragDepth'i
	// bildiriyorsa, ona yazmayan dallar TANIMSIZ derinlik bırakır — ışın kutuyu
	// kenarda ıskaladığında ekranda köşegen "cızırtı" çizgileri çıkıyordu (Onur).
	// Iskalama durumunda quad'ın kendi düzlem derinliğine düş.
	vec3 shade_point = (tmax >= max(tmin, 0.0) && write_depth)
		? origin + dir * tmin
		: world;
	vec3 view_pos = (VIEW_MATRIX * vec4(shade_point, 1.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * vec4(view_pos, 1.0);
	DEPTH = clip.z / clip.w;
}
