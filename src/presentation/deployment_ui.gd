class_name DeploymentUI
extends CanvasLayer
## Savaş ekranı UI'ı (CLAUDE.md §19).
## Deployment modu: bölük kartları + Mevzi + SAVAŞ butonu.
## Savaş modu: 1x/2x/Atla kontrolleri + tur göstergesi.
## Sonuç: ZAFER/YENİLGİ + tekrar butonu.

signal card_pressed(index: int)
signal battle_pressed
signal speed_selected(mult: float)
signal skip_pressed
signal restart_pressed
signal commander_pressed

const SINIF_AD := ["Yakın", "Menzilli", "Destek"]

const IC_GOLD := preload("res://assets/icons/gold.svg")
const IC_HOUR := preload("res://assets/icons/hourglass.svg")
const IC_MEVZI := preload("res://assets/icons/shield.svg")
const IC_MAP := preload("res://assets/icons/map.svg")
const IC_BOOK := preload("res://assets/icons/book.svg")
const IC_MENU := preload("res://assets/icons/menu.svg")
const IC_PACK := preload("res://assets/icons/pack.svg")
const IC_SKULL := preload("res://assets/icons/skull.svg")

const BAR_BG := Color(0.05, 0.05, 0.075, 0.94)

var battle_button: Button
var _cmd_button: Button      # kumandan yeteneği (§B.0/4)

var _root: Control
var _cards: Array[Button] = []
var _mevzi_label: Label      # üst bar Mevzi değeri
var _gold_label: Label       # üst bar Altın değeri
var _round_label: Label      # üst bar Tur değeri
var _title_label: Label      # üst bar orta başlık
var _hint: Label
var _bar: HBoxContainer
var _speed_box: HBoxContainer
var _result_panel: Control
var _topbar: Panel
var _botbar: Panel
var _log_box: VBoxContainer   # savaş logu içeriği
var _log_panel: PanelContainer
var _log_toggle: Button
var _log_open := false
var _log_count := 0

func build(squad: Array) -> void:
	_root = Control.new()
	_root.name = "UIRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.make()
	add_child(_root)

	# ── Alt bar çerçevesi (kartların/kontrollerin arkasında durur) ──
	_botbar = _make_bar(Control.PRESET_BOTTOM_WIDE, 98, true)
	_root.add_child(_botbar)

	# ── Üst bar: altın · mevzi (sol) | başlık (orta) | tur · menü (sağ) ──
	_topbar = _make_bar(Control.PRESET_TOP_WIDE, 64, false)
	_root.add_child(_topbar)

	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 22)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Tam yükseklik (0..bar) → çipler dikey ortalanır (başlıkla aynı hizada)
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE, Control.PRESET_MODE_MINSIZE)
	left.offset_left = 18
	_topbar.add_child(left)
	var gold_chip := _make_chip(IC_GOLD, Color(0.86, 0.72, 0.34))
	_gold_label = gold_chip.get_child(1)
	left.add_child(gold_chip)
	var mevzi_chip := _make_chip(IC_MEVZI, Color(0.55, 0.70, 0.85))
	_mevzi_label = mevzi_chip.get_child(1)
	left.add_child(mevzi_chip)

	_title_label = Label.new()
	_title_label.theme_type_variation = "Title"
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Tüm bar genişliğine yay + metni ortala → ekranda gerçekten ortalı
	_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_topbar.add_child(_title_label)

	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE, Control.PRESET_MODE_MINSIZE)
	right.offset_right = -18
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_topbar.add_child(right)
	var turn_chip := _make_chip(IC_HOUR, Color(0.72, 0.82, 0.90))
	_round_label = turn_chip.get_child(1)
	_round_label.text = "1"
	right.add_child(turn_chip)
	# İşlevsel menü ikonları: sefer durumu · kılavuz · menü
	right.add_child(_make_icon_button(IC_MAP, _open_status, "Sefer Durumu"))
	right.add_child(_make_icon_button(IC_BOOK, _open_codex, "Kılavuz"))
	right.add_child(_make_icon_button(IC_MENU, _open_menu, "Menü"))

	_hint = Label.new()
	_hint.text = "Karttan birim seç → yeşil tile'a tıkla  •  Yerleşmiş birime tıkla: taşı  •  Sağ tık: geri al  •  Q/E: kamera, tekerlek: zoom"
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.modulate = Color(1, 1, 1, 0.7)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 76)
	_root.add_child(_hint)

	_build_log_widget()

	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 10)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 16)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_bar)

	for i in squad.size():
		var piece: PieceData = squad[i]
		var btn := Button.new()
		var traits_line := piece.trait_names()
		btn.text = "%s\n%s  (%s)\n%s\nMevzi %d" % [piece.ad, piece.stat_text(),
			SINIF_AD[piece.sinif], traits_line if traits_line != "" else "—", piece.mevzi_maliyeti]
		btn.custom_minimum_size = Vector2(165, 108)
		btn.focus_mode = Control.FOCUS_NONE
		# Tooltip: tabya açıklamaları (canlı Güç×Kat dökümü M1 cilasında — §19)
		var tips: Array[String] = []
		for t in piece.base_traits:
			tips.append("%s: %s" % [t.ad, t.aciklama])
		btn.tooltip_text = "\n".join(tips)
		btn.pressed.connect(_on_card_button.bind(i))
		_bar.add_child(btn)
		_cards.append(btn)

	battle_button = Button.new()
	battle_button.text = "SAVAŞ"
	battle_button.custom_minimum_size = Vector2(160, 64)
	battle_button.focus_mode = Control.FOCUS_NONE
	battle_button.disabled = true
	battle_button.tooltip_text = "En az bir birim yerleştir"
	battle_button.add_theme_font_size_override("font_size", 24)
	battle_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	battle_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	battle_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	battle_button.pressed.connect(func(): battle_pressed.emit())
	_root.add_child(battle_button)

	# Kumandan yeteneği butonu (§B.0/4) — savaş başlayınca aktifleşir
	_cmd_button = Button.new()
	_cmd_button.text = "⚡ Yıldırım"
	_cmd_button.custom_minimum_size = Vector2(150, 52)
	_cmd_button.focus_mode = Control.FOCUS_NONE
	_cmd_button.disabled = true
	_cmd_button.tooltip_text = "Kumandan: bir düşmana yıldırım (cooldown 2 tur)"
	_cmd_button.add_theme_font_size_override("font_size", 18)
	_cmd_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	_cmd_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cmd_button.pressed.connect(func(): commander_pressed.emit())
	_root.add_child(_cmd_button)

	_build_speed_controls()

func _build_speed_controls() -> void:
	_speed_box = HBoxContainer.new()
	_speed_box.add_theme_constant_override("separation", 8)
	_speed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 16)
	_speed_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_speed_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_speed_box.visible = false
	_root.add_child(_speed_box)
	for cfg in [["1x", 1.0], ["2x", 2.0]]:
		var btn := Button.new()
		btn.text = cfg[0]
		btn.custom_minimum_size = Vector2(70, 48)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func(): speed_selected.emit(cfg[1]))
		_speed_box.add_child(btn)
	var skip_btn := Button.new()
	skip_btn.text = "Atla ≫"
	skip_btn.custom_minimum_size = Vector2(90, 48)
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.pressed.connect(func(): skip_pressed.emit())
	_speed_box.add_child(skip_btn)

func _on_card_button(index: int) -> void:
	card_pressed.emit(index)

# ------------------------------------------------------------- HUD bar yardımcıları

## Üst/alt çerçeve şeridi: koyu panel + tek kenar çizgisi (warm)
func _make_bar(preset: int, height: float, border_top: bool) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = BAR_BG
	# Düz çizgi kaldırıldı → süslü ayraç (aşağıda) çizilir
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	if border_top:
		p.offset_top = -height   # BOTTOM_WIDE
	else:
		p.offset_bottom = height  # TOP_WIDE
	# Bar'ın iç kenarına (üst bar → alt kenar, alt bar → üst kenar) süslü ayraç
	var div := _make_divider()
	if border_top:
		div.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE)
		div.offset_bottom = DIVIDER_H
	else:
		div.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE)
		div.offset_top = -DIVIDER_H
	p.add_child(div)
	return p

## Süslü yatay ayraç: ince altın çizgi + uçlarda/ortada elmas düğüm (referans stil).
const DIVIDER_H := 14.0

func _make_divider() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.clip_contents = false
	c.draw.connect(_draw_divider.bind(c))
	c.resized.connect(c.queue_redraw)
	return c

func _draw_divider(c: Control) -> void:
	var w := c.size.x
	var y := c.size.y * 0.5
	var col := Color(0.66, 0.57, 0.38, 0.60)
	var edge := 26.0
	# ana çizgi (uçlara doğru hafif solar)
	c.draw_line(Vector2(edge, y), Vector2(w - edge, y), col, 1.0, true)
	c.draw_line(Vector2(10, y), Vector2(edge, y), Color(col.r, col.g, col.b, 0.25), 1.0, true)
	c.draw_line(Vector2(w - edge, y), Vector2(w - 10, y), Color(col.r, col.g, col.b, 0.25), 1.0, true)
	# elmas düğümler: iki uç + orta
	var bright := Color(0.82, 0.72, 0.48, 0.9)
	for x: float in [edge, w * 0.5, w - edge]:
		var d := 4.0
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(x, y - d), Vector2(x + d, y), Vector2(x, y + d), Vector2(x - d, y)]), bright)

## İkon + değer çipi (HBox). get_child(1) = değer Label'ı.
func _make_chip(icon: Texture2D, tint: Color, font_size: int = 20) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.texture = icon
	tr.custom_minimum_size = Vector2(24, 24)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = tint
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tr)
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	return box

## Sağ menü ikonu — tıklanabilir buton (harita/kitap/menü overlay'lerini açar)
func _make_icon_button(icon: Texture2D, cb: Callable, tip: String) -> Button:
	var b := Button.new()
	b.icon = icon
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = true
	b.custom_minimum_size = Vector2(32, 32)
	# Arka plan yok — hover'da SADECE ikon rengi değişir (kutu/opaklık gelmez)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, empty)
	b.add_theme_color_override("icon_normal_color", Color(0.70, 0.65, 0.55))
	b.add_theme_color_override("icon_hover_color", Color(1.0, 0.9, 0.6))
	b.add_theme_color_override("icon_pressed_color", Color(1.0, 0.82, 0.45))
	b.pressed.connect(cb)
	return b

# ------------------------------------------------------------- üst menü overlay'leri

var _modal: Control

## ESC → açık overlay'i kapat
func _input(event: InputEvent) -> void:
	if _modal and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		_close_modal()
		get_viewport().set_input_as_handled()

func _close_modal() -> void:
	if _modal and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null

## Ortak modal iskeleti: karartıcı + ortalı panel + başlık + kapat (✕).
## build_body.call(içerik_vbox) ile içerik doldurulur. Dışına tıkla = kapat.
func _open_modal(title_text: String, min_w: float, build_body: Callable) -> void:
	_close_modal()
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_modal)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_modal())
	_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_w, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var pad := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + m, 22)
	panel.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	pad.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	var t := Label.new()
	t.theme_type_variation = "Title"
	t.text = title_text
	t.add_theme_font_size_override("font_size", 30)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	var x := Button.new()
	x.text = "✕"
	x.focus_mode = Control.FOCUS_NONE
	x.custom_minimum_size = Vector2(38, 38)
	x.add_theme_font_size_override("font_size", 18)
	x.pressed.connect(_close_modal)
	header.add_child(x)

	var div := _make_divider()
	div.custom_minimum_size = Vector2(0, DIVIDER_H)
	col.add_child(div)

	build_body.call(col)

# ---- Menü (duraklat / ayarlar) ----

func _open_menu() -> void:
	_open_modal("Menü", 360, func(col: VBoxContainer) -> void:
		_menu_button(col, "▶   Devam Et", _close_modal)
		var muted := AudioServer.is_bus_mute(0)
		_menu_button(col, "🔊   Ses: %s" % ("Kapalı" if muted else "Açık"), func() -> void:
			AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
			_open_menu())   # etiketi tazelemek için yeniden çiz
		_menu_button(col, "⏻   Masaüstüne Çık", func() -> void:
			get_tree().quit()))

func _menu_button(parent: VBoxContainer, label: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	parent.add_child(b)

# ---- Kılavuz (codex — metin tabanlı referans) ----

func _open_codex() -> void:
	_open_modal("Kılavuz", 640, func(col: VBoxContainer) -> void:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(600, 470)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col.add_child(scroll)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 18)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(body)

		_codex_para(body, "Güç × Kat",
			"Her vuruşun ham hasarı: (SALDIRI + toplam Güç) × tüm Kat çarpanları, "
			+ "sonra hedefin Zırh'ı düşülür. Güç kaynakları ucuz ve boldur; Kat "
			+ "kaynakları nadirdir. Kat'ı üst üste yığmak hasarı üstel patlatır — "
			+ "asıl derinlik doğru komşuluk ve tabya dizilimiyle Kat'ı beslemektir.")

		_codex_list(body, "Statü Efektleri", [
			["Zehir", "Tur başı X hasar, sonra X bir azalır. Sayaç toplanır."],
			["Yanık", "Y tur boyunca tur başı sabit X hasar. Süre yenilenir."],
			["Sersem", "Bir aktivasyon atlatır. Süre toplanır."],
			["Kök", "Hareket edemez ama saldırabilir."],
			["Zırh", "Her vuruşta gelen hasardan sabit X düşer."],
			["Kalkan", "CAN'dan önce tükenen geçici HP. Toplanır."],
			["Güçlenme", "Geçici +Güç veya ×Kat."],
			["Lanet", "×0.5 Kat zayıflatma. Süre yenilenir."],
		])

		_codex_list(body, "Zemin & Engeller", [
			["Duvar", "Hareketi ve görüşü bloklar. Melee etrafından dolaşır."],
			["Lav", "Üstünde biten birim tur başı 3 hasar alır."],
			["Diken", "Üzerine ilk giren 2 hasar alır, sonra tükenir."],
			["Kutsal Zemin", "Üstündeki dost +2 Güç."],
			["Pus Tile", "Üstündeki birim ×0.75 Kat (lanetli sis)."],
			["Yükselti", "Yüksek zemin: herkese +1 Güç, menzilliye +1 kolon menzil."],
		])

		var trait_rows: Array = []
		for tr in Database.get_all("traits"):
			trait_rows.append([tr.ad, tr.aciklama])
		if not trait_rows.is_empty():
			_codex_list(body, "Tabyalar", trait_rows)

		var relic_rows: Array = []
		for r in Database.get_all("relics"):
			relic_rows.append([r.ad, r.aciklama])
		if not relic_rows.is_empty():
			_codex_list(body, "Yadigarlar", relic_rows))

# ---- Sefer Durumu (harita ikonu) ----

func _open_status() -> void:
	_open_modal("Sefer Durumu", 560, func(col: VBoxContainer) -> void:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(520, 430)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col.add_child(scroll)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 18)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(body)

		var total_layers: int = Encounters.MAP_TEMPLATE.size()
		_codex_para(body, "Özet",
			"Altın: %d\nBayrak CAN: %d / %d\nKatman: %d / %d" % [
				GameState.gold, GameState.player_flag_hp,
				GameState.PLAYER_FLAG_MAX + GameState.meta_flag_lv * 5,
				GameState.layer_index + 1, total_layers])

		var squad_rows: Array = []
		for i in GameState.squad.size():
			var p = GameState.squad[i]
			var hp: int = GameState.squad_hp.get(i, p.can)
			var traits: String = p.trait_names()
			var line := "%s • %s • CAN %d/%d" % [
				p.stat_text(), SINIF_AD[p.sinif], hp, p.can]
			if traits != "":
				line += "\nTabya: " + traits
			squad_rows.append([p.ad, line])
		_codex_list(body, "Bölük", squad_rows)

		if GameState.relics.is_empty():
			_codex_para(body, "Yadigarlar", "Henüz yadigar toplanmadı.")
		else:
			var relic_rows: Array = []
			for r in GameState.relics:
				relic_rows.append([r.ad, r.aciklama])
			_codex_list(body, "Yadigarlar", relic_rows))

# ---- codex/status ortak içerik yapıcıları ----

## Başlık + tek paragraf açıklama
func _codex_para(parent: VBoxContainer, heading: String, text: String) -> void:
	_codex_heading(parent, heading)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", UITheme.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)

## Başlık + [ad, açıklama] satır listesi (ad vurgulu, açıklama soluk)
func _codex_list(parent: VBoxContainer, heading: String, rows: Array) -> void:
	_codex_heading(parent, heading)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 9)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(list)
	for row in rows:
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 1)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(entry)
		var name_lbl := Label.new()
		name_lbl.text = str(row[0])
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.45))
		entry.add_child(name_lbl)
		var desc_lbl := Label.new()
		desc_lbl.text = str(row[1])
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_child(desc_lbl)

func _codex_heading(parent: VBoxContainer, text: String) -> void:
	var h := Label.new()
	h.theme_type_variation = "Title"
	h.text = text
	h.add_theme_font_size_override("font_size", 21)
	h.add_theme_color_override("font_color", Color(0.85, 0.65, 0.3))
	parent.add_child(h)

# ------------------------------------------------------------- canlı Güç×Kat dökümü (§19)

var _breakdown_panel: PanelContainer
const GUC_COL := Color(0.93, 0.66, 0.28)   # Güç = toplamsal (turuncu)
const KAT_COL := Color(0.90, 0.38, 0.32)   # Kat = çarpımsal (kızıl)

func hide_breakdown() -> void:
	if _breakdown_panel and is_instance_valid(_breakdown_panel):
		_breakdown_panel.queue_free()
	_breakdown_panel = null

## Bir birimin vuruş hasarını kaynak kaynak göster: (Taban + Güç) × Kat = hasar.
## bd: CombatResolver.compute_breakdown() çıktısı.
func show_breakdown(unit_name: String, bd: Dictionary) -> void:
	hide_breakdown()
	_breakdown_panel = PanelContainer.new()
	_breakdown_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breakdown_panel.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE)
	_breakdown_panel.offset_left = 16
	_breakdown_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_breakdown_panel)

	var pad := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + m, 14)
	_breakdown_panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.custom_minimum_size = Vector2(232, 0)
	pad.add_child(col)

	var head := Label.new()
	head.theme_type_variation = "Title"
	head.text = unit_name
	head.add_theme_font_size_override("font_size", 20)
	col.add_child(head)
	var sub := Label.new()
	sub.text = "vuruş dökümü"
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	col.add_child(sub)
	_bd_gap(col, 4)

	# GÜÇ (toplamsal) satırları
	for line in bd["guc_lines"]:
		_bd_row(col, str(line[0]), "+%d" % int(line[1]), GUC_COL)
	_bd_rule(col)
	_bd_row(col, "Güç", str(int(bd["guc"])), GUC_COL, true)

	# KAT (çarpımsal) satırları — varsa
	if not bd["kat_lines"].is_empty():
		_bd_gap(col, 6)
		for line in bd["kat_lines"]:
			_bd_row(col, str(line[0]), "×%s" % _fmt_kat(float(line[1])), KAT_COL)
		_bd_rule(col)
		_bd_row(col, "Kat", "×%s" % _fmt_kat(float(bd["kat"])), KAT_COL, true)

	# SONUÇ — vuruş başına hasar
	_bd_gap(col, 8)
	var result := Label.new()
	result.text = "Vuruş  =  %d" % int(bd["raw"])
	result.theme_type_variation = "Title"
	result.add_theme_font_size_override("font_size", 26)
	result.add_theme_color_override("font_color", Color(1.0, 0.86, 0.4))
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(result)

	# KOŞULLU — konuma/hedefe bağlı, henüz aktif olmayan bonuslar
	if not bd["kosullu"].is_empty():
		_bd_gap(col, 6)
		var kh := Label.new()
		kh.text = "Koşullu"
		kh.add_theme_font_size_override("font_size", 12)
		kh.add_theme_color_override("font_color", Color(0.55, 0.7, 0.85))
		col.add_child(kh)
		for s in bd["kosullu"]:
			var l := Label.new()
			l.text = "• " + str(s)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.add_theme_font_size_override("font_size", 12)
			l.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.85))
			l.custom_minimum_size = Vector2(204, 0)
			col.add_child(l)

func _bd_row(parent: VBoxContainer, label: String, value: String, col: Color, bold: bool = false) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 15 if bold else 14)
	l.add_theme_color_override("font_color", col if bold else UITheme.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 16 if bold else 14)
	v.add_theme_color_override("font_color", col)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)

func _bd_rule(parent: VBoxContainer) -> void:
	var r := ColorRect.new()
	r.color = Color(0.5, 0.45, 0.35, 0.4)
	r.custom_minimum_size = Vector2(0, 1)
	parent.add_child(r)

func _bd_gap(parent: VBoxContainer, h: int) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	parent.add_child(g)

## Kat çarpanını kısa göster: 1.5, 0.75, 2 (tam sayıysa noktasız)
func _fmt_kat(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return "%.2f" % v

# ------------------------------------------------------------- savaş kaydı widget'ı

## Özel-stilli savaş kaydı: kompakt kızıl-aksanlı toggle + koyu yuvarlak açılır panel
func _build_log_widget() -> void:
	_log_toggle = Button.new()
	_log_toggle.focus_mode = Control.FOCUS_NONE
	_log_toggle.text = "⚔  Savaş Kaydı"
	_log_toggle.add_theme_font_size_override("font_size", 14)
	_log_toggle.add_theme_stylebox_override("normal", _sbox(Color(0.09, 0.075, 0.09, 0.96), Color(0.5, 0.24, 0.2), 7, 1))
	_log_toggle.add_theme_stylebox_override("hover", _sbox(Color(0.15, 0.10, 0.11, 0.98), Color(0.85, 0.42, 0.32), 7, 2))
	_log_toggle.add_theme_stylebox_override("pressed", _sbox(Color(0.17, 0.11, 0.12, 0.98), Color(0.85, 0.42, 0.32), 7, 2))
	_log_toggle.add_theme_color_override("icon_normal_color", Color(0.82, 0.34, 0.28))
	_log_toggle.add_theme_color_override("icon_hover_color", Color(0.98, 0.5, 0.4))
	_log_toggle.add_theme_color_override("font_color", Color(0.86, 0.8, 0.7))
	_log_toggle.add_theme_color_override("font_hover_color", Color(1, 0.92, 0.8))
	_log_toggle.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_log_toggle.offset_top += 60
	_log_toggle.offset_bottom += 60
	_log_toggle.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_log_toggle.visible = false
	_log_toggle.pressed.connect(_toggle_log)
	_root.add_child(_log_toggle)

	_log_panel = PanelContainer.new()
	var pbox := _sbox(Color(0.055, 0.05, 0.065, 0.98), Color(0.36, 0.28, 0.2), 8, 1)
	pbox.set_content_margin_all(14)
	pbox.shadow_size = 10
	pbox.shadow_color = Color(0, 0, 0, 0.55)
	_log_panel.add_theme_stylebox_override("panel", pbox)
	_log_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_log_panel.offset_top += 100
	_log_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_log_panel.custom_minimum_size = Vector2(280, 0)
	_log_panel.visible = false
	_root.add_child(_log_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_log_panel.add_child(col)
	var title := Label.new()
	title.theme_type_variation = "Title"
	title.text = "⚔  SAVAŞ KAYDI"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.86, 0.5, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var div := ColorRect.new()
	div.color = Color(0.5, 0.28, 0.22, 0.6)
	div.custom_minimum_size = Vector2(0, 2)
	col.add_child(div)
	_log_box = VBoxContainer.new()
	_log_box.add_theme_constant_override("separation", 5)
	_log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_log_box)

func _sbox(bg: Color, border: Color, radius: int, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(9)
	return s

## Savaş kaydına satır ekle; ölüm satırı kızıl vurgulu, panel kapalıysa birikir
func add_log(text: String) -> void:
	if _log_box == null:
		return
	_log_toggle.visible = true
	_log_count += 1
	_log_toggle.text = "⚔  Savaş Kaydı  ·  %d" % _log_count
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	var is_death := text.begins_with("☠")
	l.add_theme_color_override("font_color",
		Color(0.9, 0.44, 0.38) if is_death else Color(0.85, 0.81, 0.71))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_box.add_child(l)
	# queue_free kare sonuna ertelenir, sayaç düşmez — önce remove_child şart
	while _log_box.get_child_count() > 12:
		var old := _log_box.get_child(0)
		_log_box.remove_child(old)
		old.queue_free()

## Toggle → paneli yukarıdan aşağı animasyonla aç/kapa
func _toggle_log() -> void:
	_log_open = not _log_open
	if _log_open:
		_log_panel.visible = true
		_log_panel.pivot_offset = Vector2.ZERO
		_log_panel.scale = Vector2(1.0, 0.02)
		var tw := create_tween()
		tw.tween_property(_log_panel, "scale:y", 1.0, 0.24) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		var tw := create_tween()
		tw.tween_property(_log_panel, "scale:y", 0.02, 0.15) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: _log_panel.visible = false)

# ------------------------------------------------------------- durum geçişleri

## Tur çözülürken: kartlar/buton gizli, hız kontrolleri görünür
func enter_battle_mode() -> void:
	_bar.visible = false
	battle_button.visible = false
	_cmd_button.visible = false
	_hint.visible = false
	_speed_box.visible = true
	_log_toggle.visible = true

## Tur arası planlama (§B.0/3): kartlar + "TUR ✓" geri gelir, hız gizlenir
func enter_planning_mode(ap: int) -> void:
	_speed_box.visible = false
	_bar.visible = true
	battle_button.visible = true
	battle_button.disabled = false
	battle_button.text = "TUR ✓"
	_cmd_button.visible = true
	set_mevzi(ap)

var _cmd_name := "⚡ Yıldırım"

func set_commander_name(n: String) -> void:
	_cmd_name = n
	if _cmd_button:
		_cmd_button.text = n

## Kumandan yeteneği durumu: hazırsa aktif, değilse cooldown göster
func set_commander(ready: bool, cd: int) -> void:
	if _cmd_button == null:
		return
	_cmd_button.disabled = not ready
	_cmd_button.text = _cmd_name if ready else "%s (%d)" % [_cmd_name, cd]

func set_round(round_no: int) -> void:
	_round_label.text = str(round_no)

func show_result(player_won: bool) -> void:
	_speed_box.visible = false
	_result_panel = CenterContainer.new()
	_result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_result_panel)
	var panel := PanelContainer.new()
	_result_panel.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.custom_minimum_size = Vector2(340, 0)
	panel.add_child(vbox)
	var title := Label.new()
	title.theme_type_variation = "Title"
	title.text = "ZAFER" if player_won else "YENİLGİ"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.3) if player_won else Color(0.9, 0.25, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var sub := Label.new()
	sub.text = "Düşman bayrağı yıkıldı — sefere devam." if player_won \
		else "Bozgun — bayrağın yara aldı. Yol devam ediyor."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)
	var again := Button.new()
	again.text = "DEVAM →"
	again.custom_minimum_size = Vector2(0, 52)
	again.focus_mode = Control.FOCUS_NONE
	again.add_theme_font_size_override("font_size", 22)
	again.pressed.connect(func(): restart_pressed.emit())
	vbox.add_child(again)

# ------------------------------------------------------------- deployment durumu

func set_mevzi(value: int) -> void:
	_mevzi_label.text = str(value)

func set_gold(value: int) -> void:
	_gold_label.text = str(value)

func set_title(text: String) -> void:
	_title_label.text = text

func set_selected(index: int) -> void:
	for i in _cards.size():
		_cards[i].modulate = Color(1.0, 0.95, 0.5) if i == index else Color.WHITE

func set_card_deployed(index: int, deployed: bool) -> void:
	_cards[index].disabled = deployed
	_cards[index].modulate = Color(1, 1, 1, 0.5) if deployed else Color.WHITE
