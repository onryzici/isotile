// Inverse-hull outline (CLAUDE.md §16.2 yöntem A).
// Mesh'in ikinci materyali: cull_front + vertex'i büyüt + düz siyah.
// Not: sert kenarlı kutularda normal-boyunca büyütme köşe açar;
// origin-merkezli konveks primitiflerde uniform ölçek daha temiz sonuç verir.
shader_type spatial;
render_mode unshaded, cull_front;

uniform float grow : hint_range(0.0, 0.15) = 0.04;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void vertex() {
	VERTEX *= 1.0 + grow;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
