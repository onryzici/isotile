class_name UnitCard
extends Button
## Deployment alt bar birim kartı — MİNİMAL (referans: Master of Piece). Kutu/panel/
## isim/tabya metni YOK: sadece ayakta BİRİM FİGÜRÜ + altında kompakt STAT PLAKALARI
## (ikon üstte, sayı koyu plakada) + en altta MALİYET ELMASLARI. İsim/tabya = hover
## tooltip. pressed → DeploymentUI.card_pressed. Seçim: yumuşak altın hale.

const ATK_COL := Color(0.92, 0.68, 0.36)   # SALDIRI = turuncu
const HP_COL  := Color(0.85, 0.42, 0.38)   # CAN = kızıl
const SPD_COL := Color(0.58, 0.72, 0.90)   # HIZ = mavi
const SEL_COL := Color(0.95, 0.80, 0.42)
const MEVZI_COL := Color(0.62, 0.45, 0.92)   # maliyet elması = mor

const IC_ATK := preload("res://assets/icons/attack.svg")
const IC_HP := preload("res://assets/icons/health.svg")
const IC_SPD := preload("res://assets/icons/speed.svg")

const SINIF_AD := ["Yakın", "Menzilli", "Destek"]
const CARD_SIZE := Vector2(84, 124)

var index := -1
var _deployed := false
var _selected := false
var _piece: PieceData
var _cost := 0
var _affordable := true

func setup(piece: PieceData, idx: int) -> void:
	index = idx
	_piece = piece
	_cost = piece.mevzi_maliyeti
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = CARD_SIZE
	clip_contents = false
	# Kutu YOK — buton stilleri tamamen boş
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, empty)

	var cls := piece.class_key()
	var cls_col: Color = PieceView.CLASS_COLORS.get(cls, Color.GRAY)
	pivot_offset = CARD_SIZE * Vector2(0.5, 1.0)   # alttan büyüsün (seçimde yükseliş hissi)

	# ── Dikey yığın: figür (üst) → stat plakaları → maliyet elmasları — ALTA yaslı ──
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 4)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	col.add_child(_figure(piece, cls_col))
	col.add_child(_stat_row(piece))
	col.add_child(_cost_pips(piece.mevzi_maliyeti))

	# Tooltip (isim + tabya) — özel panel
	tooltip_text = piece.ad

# ---------------------------------------------------------------- durumlar

## Seçim: figür belirgin BÜYÜR (alttan) + PARLAR, diğerleri sönük kalır → net.
func set_selected_state(sel: bool) -> void:
	_selected = sel
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.18, 1.18) if sel else Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	z_index = 1 if sel else 0
	_update_dim()

## Dizilince kart SİLİK KALMAZ — aşağıya küçülüp solarak KAYBOLUR (slot kapanır,
## alt bar seyrekleşir). Geri alınca tekrar belirir.
func set_deployed_state(dep: bool) -> void:
	_deployed = dep
	disabled = dep
	if dep:
		_selected = false
		pivot_offset = CARD_SIZE * 0.5   # ortadan (crush değil, yumuşak poof)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE)
		tw.tween_property(self, "scale", Vector2(1.1, 1.1), 0.16) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(func() -> void:
			visible = false
			scale = Vector2.ONE)
	else:
		visible = true
		pivot_offset = CARD_SIZE * Vector2(0.5, 1.0)   # seçim için alt-pivot geri
		scale = Vector2.ONE
		modulate = Color(1, 1, 1, 0.0)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(_update_dim)

func set_affordable(ok: bool) -> void:
	_affordable = ok
	if not _deployed:
		_update_dim()

func _update_dim() -> void:
	if _deployed:
		return   # dizili kart gizli
	elif _selected:
		modulate = Color(1.22, 1.18, 1.06)       # seçili → parlak
	elif not _affordable:
		modulate = Color(0.72, 0.72, 0.76, 0.6)   # Mevzi yetmiyor → soluk
	else:
		modulate = Color(0.82, 0.82, 0.84)        # normal (hafif sönük → seçili öne çıksın)

# ---------------------------------------------------------------- parçalar

## Ayakta birim figürü: sprite varsa sprite, yoksa sınıf-renkli kapsül silüeti.
func _figure(piece: PieceData, cls_col: Color) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(CARD_SIZE.x, 70)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://assets/units/%s.png" % piece.mesh_id if piece.mesh_id != &"" else ""
	if path != "" and ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.add_child(tr)
	else:
		# Kutuyu doldurur, kapsülü kendi içinde ortalar. PRESET_CENTER kullanılmaz:
		# offsetler box.size henüz (0,0) iken hesaplanıp kapsül kutudan taşıyordu
		# (stat satırının üstüne biniyordu).
		var cap := _CapsuleGlyph.new()
		cap.tint = cls_col
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.add_child(cap)
	return box

## Kompakt stat satırı: 3 plaka (ikon üstte + sayı koyu plakada) — ⚔ ♥ ⚡
func _stat_row(piece: PieceData) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	# Üç stat TEK bir küme gibi okunsun: plakalar bitişik, aralarında ince nefes payı.
	h.add_theme_constant_override("separation", 2)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_stat_plate(IC_ATK, piece.saldiri, ATK_COL))
	h.add_child(_stat_plate(IC_HP, piece.can, HP_COL))
	h.add_child(_stat_plate(IC_SPD, piece.hiz, SPD_COL))
	return h

func _stat_plate(icon: Texture2D, val: int, col: Color) -> Control:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = icon
	ic.custom_minimum_size = Vector2(12, 12)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.modulate = col
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.055, 0.08, 0.95)
	box.set_corner_radius_all(3)
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 0
	box.content_margin_bottom = 1
	plate.add_theme_stylebox_override("panel", box)
	var lbl := Label.new()
	lbl.text = str(val)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", col.lightened(0.25))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(lbl)
	v.add_child(plate)
	return v

## Maliyet elmasları (Mevzi): mor dolu elmaslar — cost kadar.
func _cost_pips(cost: int) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in maxi(1, cost):
		var pip := _Diamond.new()
		pip.col = MEVZI_COL
		pip.custom_minimum_size = Vector2(9, 9)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(pip)
	return h

## Özel tooltip: şık panel — isim (altın başlık) + tabya adı/etkisi.
func _make_custom_tooltip(_for_text: String) -> Object:
	if _piece == null:
		return null
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.065, 0.095, 0.98)
	box.border_color = Color(0.42, 0.35, 0.24)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	col.custom_minimum_size = Vector2(250, 0)
	panel.add_child(col)
	var head := Label.new()
	head.text = "%s  ·  %s  ·  🛡%d" % [_piece.ad, SINIF_AD[_piece.sinif], _piece.mevzi_maliyeti]
	head.theme_type_variation = "Title"
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	col.add_child(head)
	for t in _piece.base_traits:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		col.add_child(row)
		var nm := Label.new()
		nm.text = "◆ " + t.ad
		nm.add_theme_font_size_override("font_size", 15)
		nm.add_theme_color_override("font_color", Color(0.92, 0.78, 0.45))
		row.add_child(nm)
		var desc := Label.new()
		desc.text = t.aciklama
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(238, 0)
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.72, 0.70, 0.62))
		row.add_child(desc)
	return panel

## Küçük dolu elmas (maliyet pip'i)
class _Diamond extends Control:
	var col := Color.WHITE
	func _draw() -> void:
		var w := size.x
		var hh := size.y
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.5, 0), Vector2(w, hh * 0.5),
			Vector2(w * 0.5, hh), Vector2(0, hh * 0.5)]), col)
		draw_polyline(PackedVector2Array([
			Vector2(w * 0.5, 0), Vector2(w, hh * 0.5), Vector2(w * 0.5, hh),
			Vector2(0, hh * 0.5), Vector2(w * 0.5, 0)]), Color(0, 0, 0, 0.5), 1.0)

## Sprite'sız birimler için kapsül silüeti — kendi rect'inin ortasına, sabit boyda çizer
class _CapsuleGlyph extends Control:
	const GLYPH := Vector2(38, 58)
	var tint := Color.GRAY
	func _draw() -> void:
		var o := (size - GLYPH) * 0.5
		var r := GLYPH.x * 0.5
		var col := tint.lightened(0.08)
		draw_circle(o + Vector2(r, r), r, col)
		draw_circle(o + Vector2(r, GLYPH.y - r), r, col)
		draw_rect(Rect2(o.x, o.y + r, GLYPH.x, GLYPH.y - r * 2.0), col)
