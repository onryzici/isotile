class_name MainMenuScreen
extends Node
## Açılış menüsü (referans: "Rise of the Lambs" mock'u): tam ekran mezarlık
## art'ı, solda YANDAN KAYARAK gelen kuzu şövalye (hızlı→yavaş), sol üstte
## Halther display başlık, sağda dikey menü şeritleri. main.gd sinyalleri bağlar.

signal new_run
signal continue_run
signal open_garrison

const BG := preload("res://assets/ui/menu_bg.png")
const KUZU := preload("res://assets/ui/menu_kuzu.png")
const HALTHER_TTF := "res://assets/fonts/Halther.otf"

static var _halther: Font

## Halther + Türkçe glif eksiklerine karşı Grenze Gotisch fallback
static func halther() -> Font:
	if _halther == null:
		var fv := FontVariation.new()
		fv.base_font = load(HALTHER_TTF)
		fv.fallbacks = [load("res://assets/fonts/GrenzeGotisch.ttf")]
		_halther = fv
	return _halther

## Halther İ/ı gliflerinde bozuk (nokta ayrı düşüyor / ı kayboluyor) — display
## metinde İ→I, ı→I yaz (font zaten caps-only, okuma bozulmuyor)
static func disp(t: String) -> String:
	return t.replace("İ", "I").replace("ı", "I")

var _ui: CanvasLayer
var _root: Control
var _kuzu: TextureRect

func _ready() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.make()
	_ui.add_child(_root)

	# ── Arka plan: mezarlık art'ı (cover) ──
	var bg := TextureRect.new()
	bg.texture = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	# ── Kuzu şövalye: aynı 2560x1440 kadrajda (art solda konumlu) —
	#    soldan kayarak gelir, hızlı başlar yavaş oturur (QUINT ease-out) ──
	_kuzu = TextureRect.new()
	_kuzu.texture = KUZU
	_kuzu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_kuzu.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_kuzu.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_kuzu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_kuzu)
	var vp := _root.get_viewport_rect().size
	# biraz küçük dursun (Onur) — sol-alt köşe pivotuyla ölçekle: ayaklar yerde kalır
	_kuzu.pivot_offset = Vector2(0.0, vp.y)
	_kuzu.scale = Vector2(0.82, 0.82)
	_kuzu.position.x = -vp.x * 0.55
	_kuzu.modulate.a = 0.0
	var ktw := create_tween().set_parallel(true)
	ktw.tween_property(_kuzu, "position:x", 0.0, 1.05) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	ktw.tween_property(_kuzu, "modulate:a", 1.0, 0.35)

	# ── Başlık: RISE / of the / LAMBS — üç katman (referans yerleşimi) ──
	var t_rise := _title_label("RISE", 118, Vector2(92, 34))
	var t_ofthe := _title_label("OF THE", 30, Vector2(212, 172))
	var t_lambs := _title_label("LAMBS", 118, Vector2(58, 206))
	# başlık girişi: hafif yukarıdan süzülme + sıralı fade
	var ti := 0
	for n: Control in [t_rise, t_ofthe, t_lambs]:
		n.modulate.a = 0.0
		var tp: Vector2 = n.position
		n.position.y -= 16
		var ttw := create_tween().set_parallel(true)
		ttw.tween_property(n, "modulate:a", 1.0, 0.45).set_delay(0.25 + ti * 0.12)
		ttw.tween_property(n, "position:y", tp.y, 0.5) \
			.set_delay(0.25 + ti * 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ti += 1

	# ── Sağ menü: dikey, ortadan hafif yukarıda (referans yerleşimi) ──
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 18)
	menu.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	menu.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	menu.offset_right = -vp.x * 0.10
	menu.offset_top = -vp.y * 0.16
	_root.add_child(menu)

	var has_save := FileAccess.file_exists(GameState.SAVE_PATH)
	var items: Array = []
	if has_save:
		items.append(["DEVAM ET", func() -> void: continue_run.emit()])
	items.append(["YENİ SEFER", func() -> void:
		if has_save:
			_confirm_new_run()
		else:
			new_run.emit()])
	items.append(["GARNİZON", func() -> void: open_garrison.emit()])
	items.append(["ÇIKIŞ", func() -> void: get_tree().quit()])
	for i in items.size():
		var b := _menu_item(items[i][0], items[i][1])
		menu.add_child(b)
		# sağdan sıralı süzülme
		b.modulate.a = 0.0
		var btw := create_tween()
		btw.tween_property(b, "modulate:a", 1.0, 0.4).set_delay(0.45 + i * 0.12)

	var ver := Label.new()
	ver.text = "erken geliştirme sürümü"
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5, 0.6))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(ver)


## Başlık katmanı: Halther, beyaz, kalın koyu kontur + gölge
func _title_label(text: String, size_px: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = disp(text)
	l.add_theme_font_override("font", halther())
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", Color(0.94, 0.92, 0.88))
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02, 0.9))
	l.add_theme_constant_override("outline_size", maxi(6, size_px / 10))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 5)
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l

## Menü kalemi (referans dili): Halther beyaz yazı + arkasında yarı saydam
## koyu şerit; hover'da yazı parlar, şerit hafif açılır, kalem sola süzülür.
func _menu_item(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = disp(text)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(340, 64)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", halther())
	b.add_theme_font_size_override("font_size", 44)
	b.add_theme_color_override("font_color", Color(0.93, 0.90, 0.86))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.94))
	b.add_theme_color_override("font_pressed_color", Color(0.85, 0.78, 0.7))
	b.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.03, 0.85))
	b.add_theme_constant_override("outline_size", 8)
	b.add_theme_stylebox_override("normal", _strip(Color(0, 0, 0, 0.34)))
	b.add_theme_stylebox_override("hover", _strip(Color(0.05, 0.02, 0.02, 0.52)))
	b.add_theme_stylebox_override("pressed", _strip(Color(0.02, 0.01, 0.01, 0.6)))
	b.pressed.connect(cb)
	b.mouse_entered.connect(func() -> void:
		create_tween().tween_property(b, "position:x", -10.0, 0.12) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func() -> void:
		create_tween().tween_property(b, "position:x", 0.0, 0.15) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))
	return b

## Yazının arkasındaki yumuşak koyu şerit (referanstaki dikdörtgen bantlar)
func _strip(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(0)
	box.set_corner_radius_all(2)
	box.content_margin_left = 30
	box.content_margin_right = 30
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box

## Kayıt varken "Yeni Sefer": mevcut seferi silme onayı
func _confirm_new_run() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var pad := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + m, 18)
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(380, 0)
	pad.add_child(col)
	var q := Label.new()
	q.text = "Mevcut sefer silinecek. Emin misin?"
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.add_theme_font_size_override("font_size", 20)
	col.add_child(q)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var yes := _menu_item("YENİ SEFER", func() -> void: new_run.emit())
	yes.custom_minimum_size = Vector2(200, 52)
	yes.add_theme_font_size_override("font_size", 26)
	row.add_child(yes)
	var no := _menu_item("VAZGEÇ", func() -> void: dim.queue_free())
	no.custom_minimum_size = Vector2(170, 52)
	no.add_theme_font_size_override("font_size", 26)
	row.add_child(no)
