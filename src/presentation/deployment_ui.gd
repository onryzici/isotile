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
	for ic: Texture2D in [IC_MAP, IC_BOOK, IC_MENU]:
		right.add_child(_make_icon(ic))

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

## Sağ menü ikonu (dekoratif — harita/kitap/menü)
func _make_icon(icon: Texture2D) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = icon
	tr.custom_minimum_size = Vector2(26, 26)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = Color(0.72, 0.67, 0.57, 0.8)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

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
	while _log_box.get_child_count() > 12:
		_log_box.get_child(0).queue_free()

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
