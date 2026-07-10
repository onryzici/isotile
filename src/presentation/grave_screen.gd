class_name GraveScreen
extends NodeDiorama
## Gri Mezar (gelistirme §11, MoP "Gray grave" diyoraması): mezarlık adası —
## mezar taşları, ölü ağaçlar, sis, kızıl sancak. Seçenekler mezarların üstünde
## yüzen elmaslar: bedeli öde (sancak −2) → nadir yadigar; 1 zar → teklifi çevir.

signal closed

const FLAG_COST := 2
const IC_PACK := preload("res://assets/icons/pack.svg")
const IC_DICE := preload("res://assets/icons/dice.svg")

var _offer: RelicData
var _accept_d: Control
var _reroll_d: Control

func _ready() -> void:
	super()
	# ada: köşeleri kırık 5×5, arkada yükselti
	var cells := {}
	for y in 5:
		for x in 5:
			if Vector2i(x, y) in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(0, 4)]:
				continue
			cells[Vector2i(x, y)] = 0
	cells[Vector2i(3, 3)] = 1
	cells[Vector2i(4, 4)] = 1
	build_island(cells)

	# prop'lar: ana mezar (kutsal, seçim burada) + yan mezarlar + ağaç + sancak + sis
	add_glow_slab(Vector2i(2, 2), Color(0.08, 0.07, 0.10), Color(0.45, 0.42, 0.62), 0.5)
	add_tombstone(Vector2i(2, 2), 1, true)
	add_tombstone(Vector2i(1, 3), 2)
	add_tombstone(Vector2i(3, 1), 3)
	add_tombstone(Vector2i(3, 3), 4)
	add_dead_tree(Vector2i(0, 3), 1)
	add_dead_tree(Vector2i(4, 1), 2)
	# DİKKAT: yaw 45'te (x−z) sabit hücreler AYNI ekran kolonuna düşer —
	# sancak/elmas çipalarını farklı köşegenlere dağıt (üst üste binmesin)
	add_flag(Vector2i(4, 2), false)
	add_mist(Vector2i(0, 2))
	add_mist(Vector2i(4, 3))
	add_mist(Vector2i(2, 4))
	add_omni(Vector2i(2, 2), Color(0.55, 0.5, 0.85), 1.6, 1.0)

	set_description("GRİ MEZAR",
		"Sancak dayanıklılığı kaybet — karşılığında taşın altındaki emaneti al.")
	_roll_offer()

	# elmas seçenekler: ana mezarın üstünde KABUL, yan mezarın üstünde ZAR
	_accept_d = add_choice(cell_point(Vector2i(2, 2), 1.15), IC_PACK,
		"⚑ −%d" % FLAG_COST, Color(0.83, 0.66, 0.28), "Emaneti al — sancak −%d" % FLAG_COST,
		_accept)
	_reroll_d = add_choice(cell_point(Vector2i(1, 3), 1.15), IC_DICE,
		"1 zar", Color(0.34, 0.55, 0.86), "Zar bas — teklifi yeniden çevir", _reroll)
	add_footer_button("Geç →", func() -> void:
		closed.emit()
		queue_free())
	_refresh()

func _roll_offer() -> void:
	var owned := {}
	for r in GameState.relics:
		owned[r.id] = true
	var avail: Array = []
	for r: RelicData in Database.get_all("relics"):
		if not owned.has(r.id):
			avail.append(r)
	_offer = RNG.pick(avail) if not avail.is_empty() else null

func _refresh() -> void:
	if _offer == null:
		set_footer("Mezar boş — alınacak emanet kalmadı.\nSancak: %d/%d" % [
			GameState.player_flag_hp, GameState.flag_cap()])
	else:
		set_footer("✦ %s — %s\nSancak: %d/%d   ·   Zar: %d" % [_offer.ad, _offer.aciklama,
			GameState.player_flag_hp, GameState.flag_cap(), GameState.zar])
	set_choice_enabled(_accept_d,
		_offer != null and GameState.player_flag_hp - FLAG_COST >= 1)
	set_choice_enabled(_reroll_d, _offer != null and GameState.zar > 0)

## Bedeli öde → yadigar kadroya → altın pop → kapan
func _accept() -> void:
	if _offer == null or not GameState.spend_flag(FLAG_COST):
		return
	GameState.relics.append(_offer)
	AudioDirector.play_sfx(&"deploy_clunk", 0.1)
	clear_choices()
	var pop := Label.new()
	pop.text = "✦ %s" % _offer.ad
	pop.add_theme_font_size_override("font_size", 46)
	pop.add_theme_color_override("font_color", Color(0.93, 0.82, 0.5))
	pop.scale = Vector2(0.4, 0.4)
	_ui_root().add_child(pop)
	pop.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	pop.pivot_offset = pop.get_minimum_size() * 0.5
	var tw := create_tween()
	tw.tween_property(pop, "scale", Vector2(1.2, 1.2), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pop, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.45)
	tw.tween_property(pop, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free())

## 1 zar → zar animasyonu → teklif yeniden çekilir
func _reroll() -> void:
	if not GameState.spend_zar():
		return
	set_choice_enabled(_accept_d, false)
	set_choice_enabled(_reroll_d, false)
	DiceRoll.play(self, 1 + randi() % 6, func() -> void:
		_roll_offer()
		_refresh())
