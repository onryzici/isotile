class_name EventCard
extends Control
## Kart Olayı görünümü (gelistirme §15.5): ortada büyük FİZİKSEL kart — üstte
## başlık, altında art paneli (şimdilik ikonlu placeholder sahne), hikaye metni,
## en altta seçenekler + ödül ikonları. Kart kenarı grungy/yırtık, hafif eğik
## duruş; arka plan halftone puslu karartma. Beliriş: yatay flip hissi veren
## scale-x tween. Metin menüsü DEĞİL, elde tutulan kart hissi.

signal choice_made(opt: Dictionary)

const CARD_W := 520.0
const CARD_H := 660.0
const MARGIN := 34.0
const TILT_DEG := -1.4

const IC_BOOK := preload("res://assets/icons/book.svg")
const ETKI_ICON := {
	"recruit_mizrak": preload("res://assets/icons/pack.svg"),
	"yagma": preload("res://assets/icons/gold.svg"),
	"relic_kan": preload("res://assets/icons/gem.svg"),
	"heal_flag": preload("res://assets/icons/medic.svg"),
	"buy_relic": preload("res://assets/icons/gem.svg"),
	"heal_squad_paid": preload("res://assets/icons/medic.svg"),
	"riziko": preload("res://assets/icons/dice.svg"),
	"gold_m3": preload("res://assets/icons/gold.svg"),
}

var _card: _CardBody
var _backdrop_mat: ShaderMaterial
var _buttons: Array[Button] = []
var _closing := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # arkadaki haritayı kilitle

## ev: map_screen.EVENTS girdisi. Kartı kurar ve flip-in ile açar.
func open(ev: Dictionary) -> void:
	var bd := ColorRect.new()
	bd.set_anchors_preset(Control.PRESET_FULL_RECT)
	bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_mat = ShaderMaterial.new()
	_backdrop_mat.shader = preload("res://shaders/event_backdrop.gdshader")
	_backdrop_mat.set_shader_parameter("screen_size",
		get_viewport().get_visible_rect().size)
	_backdrop_mat.set_shader_parameter("strength", 0.0)
	bd.material = _backdrop_mat
	add_child(bd)

	_card = _CardBody.new()
	_card.art_icon = _art_icon_for(ev)
	_card.size = Vector2(CARD_W, CARD_H)
	_card.pivot_offset = _card.size * 0.5
	# viewport'a göre elle ortala (open() anında kendi size'ımız henüz 0 olabilir)
	var vp := get_viewport().get_visible_rect().size
	_card.position = (vp - _card.size) * 0.5
	add_child(_card)

	var title := Label.new()
	title.theme_type_variation = "Title"
	title.text = ev["baslik"]
	title.add_theme_font_size_override("font_size", 27)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.position = Vector2(MARGIN, 22)
	title.size = Vector2(CARD_W - MARGIN * 2, 62)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(title)

	var body := Label.new()
	body.text = ev["metin"]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.85, 0.80, 0.68))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.position = Vector2(MARGIN, 318)
	body.size = Vector2(CARD_W - MARGIN * 2, 130)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(body)

	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 10)
	opts.position = Vector2(MARGIN, CARD_H - 194)
	opts.size = Vector2(CARD_W - MARGIN * 2, 160)
	_card.add_child(opts)
	for opt: Dictionary in ev["secenekler"]:
		var b := _option_button(opt)
		opts.add_child(b)
		_buttons.append(b)

	# ── Beliriş: flip hissi (dar scale-x → BACK açılım) + eğim oturması ──
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.06, 0.86)
	_card.rotation_degrees = -9.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(v: float) -> void:
		_backdrop_mat.set_shader_parameter("strength", v), 0.0, 1.0, 0.4)
	tw.tween_property(_card, "modulate:a", 1.0, 0.16).set_delay(0.08)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.42) \
		.set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "rotation_degrees", TILT_DEG, 0.42) \
		.set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	AudioDirector.play_sfx(&"deploy_clunk", 0.06)

## Art paneli placeholder'ı: ilk anlamlı seçeneğin ikonu (sahne çizimi gelene dek)
func _art_icon_for(ev: Dictionary) -> Texture2D:
	for opt: Dictionary in ev["secenekler"]:
		if ETKI_ICON.has(opt.get("etki", "")):
			return ETKI_ICON[opt["etki"]]
	return IC_BOOK

func _option_button(opt: Dictionary) -> Button:
	var b := Button.new()
	b.text = opt["ad"]
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 17)
	var ic: Texture2D = ETKI_ICON.get(opt.get("etki", ""), null)
	if ic:
		b.icon = ic
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 22)
	b.disabled = GameState.gold < int(opt.get("sart", 0))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(_choose.bind(opt))
	return b

func _choose(opt: Dictionary) -> void:
	if _closing:
		return
	_closing = true
	for b in _buttons:
		b.disabled = true
	AudioDirector.play_sfx(&"deploy_clunk", 0.1)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_card, "scale", Vector2(0.8, 0.8), 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_card, "modulate:a", 0.0, 0.18)
	tw.tween_method(func(v: float) -> void:
		_backdrop_mat.set_shader_parameter("strength", v), 1.0, 0.0, 0.22)
	tw.chain().tween_callback(func() -> void: choice_made.emit(opt))

# ------------------------------------------------------------------ kart gövdesi

## Grungy fiziksel kart çizeri: yırtık kenarlı parşömen, iç çerçeve, mürekkep
## fırçası ayraçlar, köşe süsleri, art paneli (§15.4 çerçeve dili).
class _CardBody extends Control:
	var art_icon: Texture2D

	const PAPER := Color(0.152, 0.132, 0.100)
	const PAPER_EDGE := Color(0.075, 0.062, 0.048)
	const FRAME := Color(0.46, 0.37, 0.22, 0.85)
	const INK := Color(0.055, 0.045, 0.035, 0.9)

	## Kararlı kenar titremesi (her karede aynı yırtık)
	func _jit(i: int, amp: float) -> float:
		var h := absi((i * 73856093) ^ ((i + 7) * 19349663))
		return (float(h % 100) / 100.0 - 0.5) * 2.0 * amp

	func _torn_outline(rect: Rect2, step: float, amp: float, seed_v: int) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var corners := [rect.position, rect.position + Vector2(rect.size.x, 0),
			rect.end, rect.position + Vector2(0, rect.size.y)]
		var idx := seed_v
		for ci in 4:
			var a: Vector2 = corners[ci]
			var b: Vector2 = corners[(ci + 1) % 4]
			var n := maxi(2, int(a.distance_to(b) / step))
			var normal := (b - a).normalized().rotated(PI * 0.5)
			for i in n:
				var t := float(i) / float(n)
				var amp_t := amp * (0.5 + 0.5 * absf(sin(t * PI)))  # köşeler sakin
				pts.append(a.lerp(b, t) + normal * _jit(idx, amp_t))
				idx += 1
		return pts

	## Mürekkep fırçası yatay ayraç: kırık, kalınlığı değişen çizgi (§15.4)
	func _brush_line(y: float, x0: float, x1: float, seed_v: int) -> void:
		var idx := seed_v
		var segs := 9
		var prev := Vector2(x0, y + _jit(idx, 2.0))
		for i in range(1, segs + 1):
			idx += 1
			var t := float(i) / float(segs)
			var p := Vector2(lerpf(x0, x1, t), y + _jit(idx, 2.2))
			var w := 1.6 + absf(_jit(idx + 31, 1.4))
			draw_line(prev, p, INK.lerp(FRAME, 0.35), w, true)
			prev = p

	func _draw() -> void:
		var outer := _torn_outline(Rect2(Vector2.ZERO, size), 24.0, 5.0, 3)
		# gölge (kart masanın/haritanın üstünde yüzer)
		var sh := PackedVector2Array()
		for p in outer:
			sh.append(p + Vector2(9, 12))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.5))
		# parşömen gövde + koyu yırtık kenar bandı
		draw_colored_polygon(outer, PAPER_EDGE)
		var inner_body := _torn_outline(
			Rect2(Vector2(5, 5), size - Vector2(10, 10)), 26.0, 3.5, 17)
		draw_colored_polygon(inner_body, PAPER)
		# iç çerçeve çizgisi (hafif titrek, el çizimi hissi)
		var frame := _torn_outline(
			Rect2(Vector2(16, 16), size - Vector2(32, 32)), 34.0, 1.6, 41)
		frame.append(frame[0])
		draw_polyline(frame, FRAME, 2.0, true)
		# köşe süsleri: el-çizimi köşe parantezleri
		for c in 4:
			var cp := Vector2(24 if c % 2 == 0 else size.x - 24,
				24 if c < 2 else size.y - 24)
			var dx := 1.0 if c % 2 == 0 else -1.0
			var dy := 1.0 if c < 2 else -1.0
			draw_line(cp, cp + Vector2(16 * dx, 0), FRAME.lightened(0.15), 3.0, true)
			draw_line(cp, cp + Vector2(0, 16 * dy), FRAME.lightened(0.15), 3.0, true)
		# başlık altı ayraç
		_brush_line(86.0, 46.0, size.x - 46.0, 61)
		# ── Art paneli (placeholder sahne çizimi) ──
		var art := Rect2(Vector2(36, 100), Vector2(size.x - 72, 200))
		draw_rect(art, Color(0.055, 0.05, 0.075))
		var art_frame := _torn_outline(art.grow(2.0), 30.0, 1.8, 83)
		art_frame.append(art_frame[0])
		draw_polyline(art_frame, FRAME.darkened(0.2), 2.0, true)
		# panelde büyük soluk ikon + alt vinyet (illüstrasyon gelene dek)
		if art_icon:
			var isz := Vector2(104, 104)
			draw_texture_rect(art_icon,
				Rect2(art.get_center() - isz * 0.5, isz), false,
				Color(0.72, 0.66, 0.55, 0.55))
		for i in 3:
			var vr := art.grow(-2.0 - i * 2.0)
			draw_rect(vr, Color(0, 0, 0, 0.10), false, 4.0)
		# metin altı ayraç (seçeneklerin üstü)
		_brush_line(size.y - 210.0, 46.0, size.x - 46.0, 113)
