// Arka plan radyal gradyanı — koyu mavi-gri (referans hissi) + yavaş KAYAN IŞIKLAR.
// Tam ekran ColorRect'e uygulanır; merkez biraz açık, kenarlar koyu. Üstüne birkaç
// yumuşak ışık lekesi TIME ile ağır ağır süzülür (moody atmosfer, Onur isteği).
shader_type canvas_item;

// Referans (Master of Piece): neredeyse siyah, çok ince merkez parıltısı — moody.
uniform vec4 center_col : source_color = vec4(0.055, 0.062, 0.09, 1.0);
uniform vec4 edge_col : source_color = vec4(0.012, 0.014, 0.022, 1.0);

// Yumuşak dairesel ışık lekesi (0..1 falloff)
float blob(vec2 p, vec2 c, float r) {
	return smoothstep(r, 0.0, length((p - c) * vec2(1.4, 1.0)));
}

void fragment() {
	vec2 uv = UV - vec2(0.5, 0.44);   // merkez biraz yukarıda (board arkası)
	uv.x *= 1.5;                       // yatay ovalize
	float d = length(uv);
	vec3 c = mix(center_col.rgb, edge_col.rgb, smoothstep(0.0, 0.62, d));

	// yavaş kayan ışıklar — düşük yoğunluk, soğuk mavi + soluk mor tonlar
	float t = TIME * 0.035;
	vec3 g = vec3(0.0);
	g += vec3(0.10, 0.13, 0.22) * blob(UV, vec2(0.30 + 0.12 * sin(t * 1.1),
		0.34 + 0.08 * cos(t * 0.9)), 0.33);
	g += vec3(0.15, 0.10, 0.20) * blob(UV, vec2(0.72 + 0.13 * sin(t * 0.7 + 2.0),
		0.42 + 0.10 * cos(t * 1.3)), 0.38);
	g += vec3(0.09, 0.13, 0.19) * blob(UV, vec2(0.52 + 0.16 * cos(t * 0.5),
		0.72 + 0.07 * sin(t * 1.0 + 1.0)), 0.30);
	// merkeze doğru sönümle (kenarlarda daha görünür, ortada UI/board var)
	c += g * (0.5 + 0.5 * smoothstep(0.1, 0.6, d));

	COLOR = vec4(c, 1.0);
}
