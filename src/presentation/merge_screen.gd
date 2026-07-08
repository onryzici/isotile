class_name MergeScreen
extends CanvasLayer
## Tabya birleştirme ekranı (gelistirme B.0/5): iki birim seç → ortak trait
## havuzundan HANGİLERİNİN kalacağını OYUNCU seçer (MoP'ta seçtiremiyor — fark).
## Tek-tık, hover'da açıklama. Sonuç: iki birim yerine tek güçlendirilmiş birim.

signal closed

const SINIF_AD := ["Yakın", "Menzilli", "Destek"]

var _root: Control
var _squad_row: HBoxContainer
var _trait_box: VBoxContainer
var _info: Label
var _merge_btn: Button
var _result_label: Label

var _sel: Array[int] = []          # seçili squad index'leri (max 2)
var _kept: Array = []              # tutulacak TraitData'lar
var _slot_max := 2

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.make()
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.035, 0.05, 0.9)
	_root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.custom_minimum_size = Vector2(720, 0)
	center.add_child(col)

	var title := Label.new()
	title.theme_type_variation = "Title"
	title.text = "TABYA BİRLEŞTİRME"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var hint := Label.new()
	hint.text = "İki birim seç → ortak tabyalardan tutmak istediğin ≤2 tanesini seç"
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

	_squad_row = HBoxContainer.new()
	_squad_row.add_theme_constant_override("separation", 8)
	_squad_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_squad_row)

	var sep := HSeparator.new()
	col.add_child(sep)

	_trait_box = VBoxContainer.new()
	_trait_box.add_theme_constant_override("separation", 6)
	col.add_child(_trait_box)

	_info = Label.new()
	_info.custom_minimum_size = Vector2(0, 44)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.modulate = Color(0.85, 0.9, 1.0)
	col.add_child(_info)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	_merge_btn = Button.new()
	_merge_btn.text = "BİRLEŞTİR"
	_merge_btn.custom_minimum_size = Vector2(180, 52)
	_merge_btn.focus_mode = Control.FOCUS_NONE
	_merge_btn.disabled = true
	_merge_btn.pressed.connect(_do_merge)
	row.add_child(_merge_btn)
	var close_btn := Button.new()
	close_btn.text = "KAPAT"
	close_btn.custom_minimum_size = Vector2(120, 52)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func(): closed.emit(); queue_free())
	row.add_child(close_btn)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.modulate = Color(1.0, 0.85, 0.4)
	col.add_child(_result_label)

	_rebuild_squad()

func _rebuild_squad() -> void:
	for c in _squad_row.get_children():
		c.queue_free()
	for i in GameState.squad.size():
		var p: PieceData = GameState.squad[i]
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_pressed = i in _sel
		btn.text = "%s\n%s\n%s" % [p.ad, p.stat_text(), p.trait_names() if p.trait_names() != "" else "—"]
		btn.custom_minimum_size = Vector2(150, 92)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_squad_toggle.bind(i))
		_squad_row.add_child(btn)

func _on_squad_toggle(i: int) -> void:
	if i in _sel:
		_sel.erase(i)
	else:
		_sel.append(i)
		if _sel.size() > 2:
			_sel.pop_front()   # en fazla 2 birim
	_kept.clear()
	_rebuild_squad()
	_rebuild_traits()

func _rebuild_traits() -> void:
	for c in _trait_box.get_children():
		c.queue_free()
	_info.text = ""
	if _sel.size() != 2:
		_merge_btn.disabled = true
		return
	# ortak trait havuzu (iki birimin tüm base_traits'i)
	var pool: Array = []
	for i in _sel:
		for t: TraitData in GameState.squad[i].base_traits:
			if t not in pool:
				pool.append(t)
	if pool.is_empty():
		var l := Label.new()
		l.text = "(bu iki birimde tabya yok)"
		_trait_box.add_child(l)
	for t: TraitData in pool:
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = t in _kept
		b.text = "%s%s" % ["✔ " if t in _kept else "   ", t.ad]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(_on_trait_toggle.bind(t))
		b.mouse_entered.connect(func(): _info.text = "%s: %s" % [t.ad, t.aciklama])
		_trait_box.add_child(b)
	_update_merge_btn()

func _on_trait_toggle(t: TraitData) -> void:
	if t in _kept:
		_kept.erase(t)
	elif _kept.size() < _slot_max:
		_kept.append(t)
	_rebuild_traits()

func _update_merge_btn() -> void:
	_merge_btn.disabled = _sel.size() != 2 or _kept.is_empty()

## Birleştir: ilk birimin statlarını temel al, seçili tabyaları ver;
## iki kaynağı kadrodan çıkar, birleşiği ekle.
func _do_merge() -> void:
	if _sel.size() != 2 or _kept.is_empty():
		return
	var a: PieceData = GameState.squad[_sel[0]]
	var b: PieceData = GameState.squad[_sel[1]]
	var merged := PieceData.new()
	merged.id = StringName("%s_%s_merge" % [a.id, b.id])
	merged.ad = "%s+%s" % [a.ad, b.ad]
	merged.sinif = a.sinif
	merged.saldiri = maxi(a.saldiri, b.saldiri)
	merged.can = maxi(a.can, b.can)
	merged.hiz = maxi(a.hiz, b.hiz)
	merged.zirh = maxi(a.zirh, b.zirh)
	merged.mevzi_maliyeti = maxi(a.mevzi_maliyeti, b.mevzi_maliyeti)
	merged.tabya_slotu = _slot_max
	merged.base_traits = _kept.duplicate()
	merged.etiketler = a.etiketler.duplicate()
	for e in b.etiketler:
		if e not in merged.etiketler:
			merged.etiketler.append(e)
	merged.tier = maxi(a.tier, b.tier)
	# kadroyu güncelle: iki kaynağı çıkar, birleşiği ekle
	var keep: Array = []
	for i in GameState.squad.size():
		if i not in _sel:
			keep.append(GameState.squad[i])
	keep.append(merged)
	GameState.squad = keep
	GameState.squad_hp.clear()
	for i in GameState.squad.size():
		GameState.squad_hp[i] = GameState.squad[i].can
	_result_label.text = "★ %s oluşturuldu (%s)" % [merged.ad, merged.trait_names()]
	_sel.clear()
	_kept.clear()
	_rebuild_squad()
	_rebuild_traits()
