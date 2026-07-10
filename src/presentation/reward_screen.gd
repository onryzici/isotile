class_name RewardScreen
extends CanvasLayer
## Zafer ödülü (gelistirme B.2): savaş kazanınca 3 seçenekten biri —
## Altın / Recruit birim / Relic. Tek-tık seç → uygula → devam.
## Zar (§6): 1 zar harcayıp teklifleri YENİDEN ÇEVİREBİLİRSİN (birim + relic
## yeniden çekilir; şansı zorlama kaynağı).

signal done

const REWARD_GOLD := 18

var _root: Control
var _row: HBoxContainer
var _reroll_btn: Button

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.make()
	add_child(_root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.035, 0.05, 0.92)
	_root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.custom_minimum_size = Vector2(760, 0)
	center.add_child(col)

	var title := Label.new()
	title.theme_type_variation = "Title"
	title.text = "ZAFER ÖDÜLÜ"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var hint := Label.new()
	hint.text = "Bir ödül seç"
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 16)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_row)
	_build_offers()

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(bottom)

	_reroll_btn = Button.new()
	_reroll_btn.custom_minimum_size = Vector2(240, 44)
	_reroll_btn.focus_mode = Control.FOCUS_NONE
	_reroll_btn.pressed.connect(_reroll)
	bottom.add_child(_reroll_btn)
	_update_reroll()

	var skip := Button.new()
	skip.text = "Atla"
	skip.custom_minimum_size = Vector2(140, 44)
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(_finish)
	bottom.add_child(skip)

## Teklif kartlarını (yeniden) kur: Altın sabit, birim + relic havuzdan çekilir
func _build_offers() -> void:
	for c in _row.get_children():
		c.queue_free()

	# 1) Altın
	_row.add_child(_card("💰 Altın", "+%d altın" % REWARD_GOLD, func():
		GameState.gold += REWARD_GOLD
		_finish()))

	# 2) Recruit birim (havuzdan rastgele)
	var pool: Array = GameState.recruit_pool()
	if not pool.is_empty():
		var unit: PieceData = RNG.pick(pool)
		_row.add_child(_card("⚔ %s" % unit.ad, "%s\n%s\nBölüğe katılır" % [
			unit.stat_text(), unit.trait_names() if unit.trait_names() != "" else "—"],
			func():
				GameState.add_unit(unit)
				_finish()))

	# 3) Relic (sahip olunmayanlardan rastgele)
	var relic := _random_relic()
	if relic != null:
		_row.add_child(_card("✦ %s" % relic.ad, relic.aciklama, func():
			GameState.relics.append(relic)
			_finish()))

func _update_reroll() -> void:
	_reroll_btn.text = "Yeniden Çevir — 1 zar (kalan %d)" % GameState.zar
	_reroll_btn.disabled = GameState.zar <= 0

## 1 zar harca → zar animasyonu → teklifler yeniden çekilir
func _reroll() -> void:
	if not GameState.spend_zar():
		return
	_reroll_btn.disabled = true
	DiceRoll.play(self, 1 + randi() % 6, func() -> void:
		_build_offers()
		_update_reroll())

func _card(baslik: String, alt: String, on_pick: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(220, 150)
	b.focus_mode = Control.FOCUS_NONE
	b.text = "%s\n\n%s" % [baslik, alt]
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(on_pick)
	return b

func _random_relic() -> RelicData:
	var owned := {}
	for r in GameState.relics:
		owned[r.id] = true
	var avail: Array = []
	for r: RelicData in Database.get_all("relics"):
		if not owned.has(r.id):
			avail.append(r)
	return RNG.pick(avail) if not avail.is_empty() else null

func _finish() -> void:
	done.emit()
	queue_free()
