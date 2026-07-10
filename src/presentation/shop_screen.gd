class_name ShopScreen
extends CanvasLayer
## Dükkan / Outpost (gelistirme B.2, A.7): altınla relic/birim al, bölük iyileştir,
## birim sürgün, tabya birleştir (oyuncu seçimli — MergeScreen). Tek-tık.

signal closed

const HEAL_COST := 10

var _root: Control
var _gold_label: Label
var _relic_row: HBoxContainer
var _unit_row: HBoxContainer
var _stock_relics: Array = []
var _stock_units: Array = []
var _bought_relics := {}
var _bought_units := {}
var _reroll_btn: Button

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.make()
	add_child(_root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.035, 0.05, 0.94)
	_root.add_child(bg)
	_roll_stock()
	_build()

func _roll_stock() -> void:
	var relics: Array = Database.get_all("relics").duplicate()
	var owned := {}
	for r in GameState.relics:
		owned[r.id] = true
	relics = relics.filter(func(r): return not owned.has(r.id))
	RNG.shuffle(relics)
	_stock_relics = relics.slice(0, 3)
	var units: Array = GameState.recruit_pool()
	RNG.shuffle(units)
	_stock_units = units.slice(0, 2)

func _build() -> void:
	for c in _root.get_children():
		if c is CenterContainer:
			c.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(820, 0)
	center.add_child(col)

	var title := Label.new()
	title.theme_type_variation = "Title"
	title.text = "DÜKKAN"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_color_override("font_color", Color(0.86, 0.72, 0.34))
	col.add_child(_gold_label)

	col.add_child(_section("Yadigarlar"))
	_relic_row = HBoxContainer.new()
	_relic_row.add_theme_constant_override("separation", 12)
	_relic_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_relic_row)

	col.add_child(_section("Paralı Askerler"))
	_unit_row = HBoxContainer.new()
	_unit_row.add_theme_constant_override("separation", 12)
	_unit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_unit_row)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(actions)
	actions.add_child(_btn("Bölüğü İyileştir (%d)" % HEAL_COST, func(): _heal()))
	actions.add_child(_btn("Tabya Birleştir", func(): _open_merge()))
	actions.add_child(_btn("Birim Sürgün", func(): _open_banish()))
	_reroll_btn = _btn("", func(): _reroll_stock())
	actions.add_child(_reroll_btn)
	var leave := _btn("ÇIK →", func(): closed.emit(); queue_free())
	leave.custom_minimum_size = Vector2(140, 48)
	actions.add_child(leave)

	_refresh()

## Zar (§6): 1 zar harca → satılmamış stok yeniden çekilir (şansı zorlama)
func _reroll_stock() -> void:
	if not GameState.spend_zar():
		return
	_reroll_btn.disabled = true
	DiceRoll.play(self, 1 + randi() % 6, func() -> void:
		_roll_stock()
		_refresh())

func _section(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.modulate = Color(1, 1, 1, 0.65)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _refresh() -> void:
	_gold_label.text = "Altın: %d  ·  Zar: %d" % [GameState.gold, GameState.zar]
	if _reroll_btn:
		_reroll_btn.text = "Stok Çevir — 1 zar"
		_reroll_btn.disabled = GameState.zar <= 0
	for c in _relic_row.get_children():
		c.queue_free()
	for r: RelicData in _stock_relics:
		var sold: bool = _bought_relics.has(r.id)
		var b := _shop_card("✦ %s" % r.ad, r.aciklama, r.fiyat, sold, GameState.gold >= r.fiyat)
		if not sold:
			b.pressed.connect(_buy_relic.bind(r))
		_relic_row.add_child(b)
	for c in _unit_row.get_children():
		c.queue_free()
	for u: PieceData in _stock_units:
		var sold: bool = _bought_units.has(u.id)
		var b := _shop_card("⚔ %s" % u.ad, "%s\n%s" % [u.stat_text(),
			u.trait_names() if u.trait_names() != "" else "—"], u.fiyat, sold, GameState.gold >= u.fiyat)
		if not sold:
			b.pressed.connect(_buy_unit.bind(u))
		_unit_row.add_child(b)

func _shop_card(baslik: String, alt: String, fiyat: int, sold: bool, afford: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(230, 130)
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text = "%s\n%s\n\n%s" % [baslik, alt, "SATILDI" if sold else "%d altın" % fiyat]
	b.disabled = sold or not afford
	return b

func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _buy_relic(r: RelicData) -> void:
	if GameState.gold < r.fiyat or _bought_relics.has(r.id):
		return
	GameState.gold -= r.fiyat
	GameState.relics.append(r)
	_bought_relics[r.id] = true
	_refresh()

func _buy_unit(u: PieceData) -> void:
	if GameState.gold < u.fiyat or _bought_units.has(u.id):
		return
	GameState.gold -= u.fiyat
	GameState.add_unit(u)
	_bought_units[u.id] = true
	_refresh()

func _heal() -> void:
	if GameState.gold < HEAL_COST:
		return
	GameState.gold -= HEAL_COST
	GameState.heal_all()
	_refresh()

func _open_merge() -> void:
	var ms := MergeScreen.new()
	ms.layer = layer + 1
	ms.closed.connect(func(): ms.queue_free(); _refresh())
	add_child(ms)

## Birim sürgün: bir squad birimi seçip kadrodan çıkar (deste inceltme, A.7)
func _open_banish() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = layer + 1
	var ctrl := Control.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.theme = UITheme.make()
	overlay.add_child(ctrl)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	ctrl.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	cc.add_child(v)
	var t := Label.new()
	t.theme_type_variation = "Title"
	t.text = "SÜRGÜN — birim seç"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 8)
	v.add_child(grid)
	for i in GameState.squad.size():
		var p: PieceData = GameState.squad[i]
		var b := Button.new()
		b.text = "%s\n%s" % [p.ad, p.stat_text()]
		b.custom_minimum_size = Vector2(130, 80)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			if GameState.squad.size() > 1:
				GameState.squad.remove_at(i)
				GameState.squad_hp.clear()
				for j in GameState.squad.size():
					GameState.squad_hp[j] = GameState.squad[j].can
			overlay.queue_free())
		grid.add_child(b)
	var cancel := Button.new()
	cancel.text = "Vazgeç"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func(): overlay.queue_free())
	v.add_child(cancel)
	add_child(overlay)
