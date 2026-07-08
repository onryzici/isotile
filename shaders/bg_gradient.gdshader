// Arka plan radyal gradyanı — koyu mavi-gri (referans hissi).
// Tam ekran ColorRect'e uygulanır; merkez biraz açık, kenarlar koyu.
shader_type canvas_item;

uniform vec4 center_col : source_color = vec4(0.13, 0.15, 0.22, 1.0);
uniform vec4 edge_col : source_color = vec4(0.03, 0.035, 0.055, 1.0);

void fragment() {
	vec2 uv = UV - vec2(0.5, 0.42);   // merkez biraz yukarıda (board arkası)
	uv.x *= 1.5;                       // yatay ovalize
	float d = length(uv);
	vec3 c = mix(center_col.rgb, edge_col.rgb, smoothstep(0.0, 0.72, d));
	COLOR = vec4(c, 1.0);
}
