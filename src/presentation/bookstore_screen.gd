class_name BookstoreScreen
extends NodeDiorama
## KİTAPÇI / OZAN (gelistirme §5): altınla item satın alınan diyorama.
## Gezgin ozanın tezgah adası — 3 seed'li item kaidesi, üstlerinde ad+fiyat
## elmasları. Altın yetmiyorsa ya da çanta doluysa elmas soluk. Stok Çevir: 1 zar.

signal closed

const IC_BOOK := preload("res://assets/icons/book.svg")
const IC_MEDIC := preload("res://assets/icons/medic.svg")
const IC_SHIELD := preload("res://assets/icons/shield.svg")
const IC_DICE := preload("res://assets/icons/dice.svg")
const IC_ATK := preload("res://assets/icons/attack.svg")
const IC_GEM := preload("res://assets/icons/gem.svg")
const IC_SPD := preload("res://assets/icons/speed.svg")

const PEDESTALS: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 1), Vector2i(3, 2)]

var _offers: Array = []
var _reroll_btn: Button
var _left := false

func _ready() -> void:
	super()
	var cells := {}
	for y in 4:
		for x in 5:
			if Vector2i(x, y) in [Vector2i(0, 3), Vector2i(4, 0)]:
				continue
			cells[Vector2i(x, y)] = 0
	cells[Vector2i(0, 0)] = 1
	build_island(cells)

	add_tent(Vector2i(0, 0), Color(0.36, 0.30, 0.44))              # ozanın çadırı
	add_sprite_prop("res://assets/units/priest.png", Vector2i(1, 0), 1.05)
	add_dead_tree(Vector2i(4, 3), 11)
	add_mist(Vector2i(4, 1))
	add_mist(Vector2i(0, 2))
	add_omni(Vector2i(0, 0), Color(1.0, 0.8, 0.5), 1.6, 1.2)
	for c in PEDESTALS:
		add_glow_slab(c, Color(0.06, 0.06, 0.08), Color(0.85, 0.75, 0.45), 0.4, 0.25)

	set_description("KİTAPÇI",
		"Gezgin ozanın tezgahı. Altınla eşya al; kuşanılanlar sonraki savaşta işler.")
	_roll_offers()
	_reroll_btn = add_footer_button("Stok Çevir (1 zar)", _reroll)
	add_footer_button("Geç →", func() -> void:
		if not _left:
			_left = true
			closed.emit()
			queue_free())
	_refresh()

## Seed'li 3 item teklifi (RNG run-seed'li → determinizm korunur)
func _roll_offers() -> void:
	var pool: Array = Database.get_all("items").duplicate()
	RNG.shuffle(pool)
	_offers = pool.slice(0, mini(3, pool.size()))

func _reroll() -> void:
	if GameState.zar < 1:
		return
	GameState.zar -= 1
	AudioDirector.play_sfx(&"deploy_clunk", 0.12)
	_roll_offers()
	_refresh()

func _refresh() -> void:
	clear_choices()
	for i in _offers.size():
		var it: ItemData = _offers[i]
		if it == null:
			continue   # kaide boşaldı (satın alındı)
		var d := add_choice(cell_point(PEDESTALS[i], 1.15), _icon_for(it),
			"%s · %d" % [it.ad, it.fiyat], Color(0.86, 0.72, 0.36),
			it.aciklama, _buy.bind(i))
		if GameState.gold < it.fiyat or GameState.items.size() >= GameState.ITEM_CAP:
			set_choice_enabled(d, false)
	var dolu := GameState.items.size() >= GameState.ITEM_CAP
	set_footer("Altın: %d  ·  Çanta: %d/%d%s  ·  Zar: %d" % [GameState.gold,
		GameState.items.size(), GameState.ITEM_CAP,
		"  (DOLU)" if dolu else "", GameState.zar])
	if _reroll_btn:
		_reroll_btn.disabled = GameState.zar < 1

func _buy(i: int) -> void:
	var it: ItemData = _offers[i]
	if it == null or GameState.gold < it.fiyat:
		return
	if not GameState.add_item(it):
		return
	GameState.gold -= it.fiyat
	_offers[i] = null
	AudioDirector.play_sfx(&"deploy_clunk", 0.08)
	_refresh()

## Item ikonu: baskın etkiden seçilir (ayrı ikon sanatı gelene dek)
func _icon_for(it: ItemData) -> Texture2D:
	if it.heal_suru:
		return IC_MEDIC
	if it.zar_ver > 0:
		return IC_DICE
	if it.bayrak_onar > 0:
		return IC_SHIELD
	if it.global_kat > 1.0:
		return IC_GEM
	if it.global_ek_guc > 0:
		return IC_ATK
	if it.mevzi_bonus > 0:
		return IC_SPD
	if it.baslangic_kalkan > 0:
		return IC_SHIELD
	return IC_BOOK
