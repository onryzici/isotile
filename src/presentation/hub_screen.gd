class_name HubScreen
extends NodeDiorama
## AĞIL MEYDANI (gelistirme §2 — MoP "Departure Ground"): sefer öncesi hub adası.
## Ortada şenlik ateşi — üstündeki elmas SEFERE ÇIK. Solda garnizon çadırı (meta
## tesisler), sağda kilitli Lonca/Arşiv plakaları (roadmap). Sürünün kuzuları
## ateşin başında bekler. Menü butonlarının yerini alan diyorama.

signal depart(ordeal_lv: int)
signal open_garrison
signal back

const IC_MAP := preload("res://assets/icons/map.svg")
const IC_PACK := preload("res://assets/icons/pack.svg")
const IC_BOOK := preload("res://assets/icons/book.svg")
const IC_TRAIT := preload("res://assets/icons/trait.svg")

var _left := false
var _ordeal := 0
var _ordeal_btn: Button

## Çile etkileri (gelistirme §12 Ordeal — kademeli üst üste biner)
const ORDEAL_DESC := [
	"normal sefer",
	"düşmanlar +1 SALDIRI, +2 CAN",
	"+ düşman sancak/boss CAN ×1.3",
	"+ her savaşta 1 ekstra düşman",
]

func _ready() -> void:
	force_home_biome = true
	GameState.load_meta()   # hub run dışı açılabilir; çile kilidi metadan okunur
	super()
	var cells := {}
	for y in 5:
		for x in 6:
			# köşeler kırık → ada hissi
			if Vector2i(x, y) in [Vector2i(0, 0), Vector2i(5, 0), Vector2i(0, 4), Vector2i(5, 4)]:
				continue
			cells[Vector2i(x, y)] = 0
	cells[Vector2i(4, 0)] = 1
	cells[Vector2i(0, 1)] = 1
	build_island(cells)

	# ── Prop'lar ──
	add_campfire(Vector2i(2, 2))                                  # meydanın kalbi
	add_tent(Vector2i(0, 1), Color(0.42, 0.33, 0.22))             # garnizon çadırı
	add_tent(Vector2i(4, 0), Color(0.34, 0.26, 0.30))             # lonca çadırı (kilitli)
	add_glow_slab(Vector2i(4, 3), Color(0.07, 0.07, 0.06),
		Color(0.85, 0.75, 0.45), 0.35, 0.2)                       # arşiv taşı (kilitli)
	add_flag(Vector2i(3, 0), true)                                 # sürünün sancağı
	add_dead_tree(Vector2i(5, 3), 5)
	add_dead_tree(Vector2i(1, 0), 9)
	add_mist(Vector2i(0, 3))
	add_mist(Vector2i(5, 2))
	# sürüden kuzular ateşin başında (sanatı olan sabit yüzler)
	add_sprite_prop("res://assets/units/kuzu.png", Vector2i(1, 2), 1.0)
	add_sprite_prop("res://assets/units/okcu.png", Vector2i(3, 3), 1.0)
	add_sprite_prop("res://assets/units/sifaci.png", Vector2i(2, 3), 1.0)
	add_omni(Vector2i(0, 1), Color(1.0, 0.75, 0.4), 1.4, 1.2)     # çadır feneri

	# ── Elmas seçenekler ──
	add_choice(cell_point(Vector2i(2, 2), 1.75), IC_MAP, "SEFERE ÇIK",
		Color(0.86, 0.72, 0.36), "Pusa dal — yeni sefer başlar", _on_depart)
	add_choice(cell_point(Vector2i(0, 1), 1.85), IC_PACK, "GARNİZON",
		Color(0.45, 0.65, 0.90), "Kalıntı harca — kalıcı tesis kur", _on_garrison)
	var lonca := add_choice(cell_point(Vector2i(4, 0), 1.85), IC_TRAIT, "LONCA",
		Color(0.5, 0.45, 0.4), "Kumandan ve başlangıç bölüğü seçimi — yakında", func() -> void: pass)
	set_choice_enabled(lonca, false)
	var arsiv := add_choice(cell_point(Vector2i(4, 3), 1.15), IC_BOOK, "ARŞİV",
		Color(0.5, 0.45, 0.4), "Kara Pus'un hikayesi — yakında", func() -> void: pass)
	set_choice_enabled(arsiv, false)

	set_description("AĞIL MEYDANI",
		"Son ağılın meydanı. Ateşin başında sürünü topla; hazır olunca pusa çık.")
	_refresh_footer()
	# Çile seçici (§12 Ordeal): ilk zaferden sonra açılır, tıkla → seviye döner
	if GameState.ordeal_cap() > 0:
		_ordeal_btn = add_footer_button("", func() -> void:
			_ordeal = (_ordeal + 1) % (GameState.ordeal_cap() + 1)
			_refresh_footer())
	add_footer_button("← Menü", func() -> void:
		if not _left:
			_left = true
			back.emit()
			queue_free())

func _refresh_footer() -> void:
	var txt := "Kalıntı: %d  ·  soluk elmaslar henüz kilitli" % GameState.meta_kalinti
	if _ordeal > 0:
		txt += "\nÇile %d: %s  ·  Kalıntı ödülü ×%.1f" % [_ordeal,
			"; ".join(ORDEAL_DESC.slice(1, _ordeal + 1)), 1.0 + 0.5 * _ordeal]
	set_footer(txt)
	if _ordeal_btn:
		_ordeal_btn.text = "Çile: %d ↻" % _ordeal
		_ordeal_btn.tooltip_text = ORDEAL_DESC[_ordeal]

func _on_depart() -> void:
	if _left:
		return
	_left = true
	AudioDirector.play_sfx(&"battle_start")
	clear_choices()
	depart.emit(_ordeal)
	queue_free()

func _on_garrison() -> void:
	if _left:
		return
	_left = true
	AudioDirector.play_sfx(&"deploy_clunk", 0.08)
	open_garrison.emit()
	queue_free()
