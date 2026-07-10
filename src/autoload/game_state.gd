extends Node
## GameState — aktif run durumu (CLAUDE.md §17.4). M2: Altın, harita ilerlemesi,
## bölük CAN kalıcılığı. M3'te GarnisonState + kaydetme eklenecek.
##
## Açık kural (M2 kararı): savaşta ölen birim kadrodan ÇIKMAZ, "yaralı"
## döner (1 CAN). Şifahane/dükkan iyileştirmesi bu yüzden değerli.

var run_seed: int = 0
var gold := 0
var layer_index := 0                      # haritada sıradaki katman
var current_encounter: StringName = &"orta"
var current_node_type: StringName = &"savas"

var zar := 4                              # sefer boyu taşınan zar (gelistirme §6): reroll kaynağı
var squad: Array = []                     # PieceData listesi (kadro, run içinde büyür)
var squad_hp: Dictionary = {}             # squad index -> güncel CAN
var mevzi: int = 6                        # savaş başı Mevzi (AP) (§21)
var relics: Array = []                    # RelicData listesi (run boyu global pasif)
var items: Array = []                     # ItemData listesi (tek kullanımlık, ≤ ITEM_CAP)
var armed_items: Array = []               # kuşanılmış SONRAKI_SAVAS item'ları — tek savaşlık relic
const ITEM_CAP := 3
var commander_id: StringName = &"cesur"   # seçili kumandan (§B.0/4)

## Relic alanları toplamı (global_ek_guc, mevzi_bonus, altin_bonus...)
func relic_sum(field: StringName) -> int:
	var t := 0
	for r in relics + armed_items:   # kuşanılmış item = tek savaşlık relic
		t += r.get(field)
	return t

func relic_kat() -> float:
	var k := 1.0
	for r in relics:
		k *= r.global_kat
	return k

## Kalıcı bayrak CAN'ı (gelistirme B.0/2): run boyu taşınır, yenilenmez,
## 0 = run biter (Slay the Spire'daki oyuncu HP'sinin karşılığı).
const PLAYER_FLAG_MAX := 30
var player_flag_hp: int = PLAYER_FLAG_MAX
var run_over := false                      # oyuncu bayrağı düştü = sefer bitti

## Garnizon meta (§B.3, A.10) — RUNLAR ARASI kalıcı (ayrı kayıt). Sefer başarısızlığı
## kayıp değil tohum: kazanılan Kalıntı ile kalıcı upgrade seviyeleri alınır.
var meta_kalinti := 0                       # meta para birimi
var meta_gold_lv := 0                        # +5 başlangıç altını / seviye
var meta_flag_lv := 0                        # +5 başlangıç bayrak CAN / seviye
var meta_mevzi_lv := 0                        # +1 başlangıç Mevzi / seviye
var meta_degirmen_lv := 0                    # +2 sefer başı zar / seviye (Değirmen §6/§12)
const META_PATH := "user://garrison.json"

func save_meta() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"kalinti": meta_kalinti,
			"gold_lv": meta_gold_lv, "flag_lv": meta_flag_lv, "mevzi_lv": meta_mevzi_lv,
			"degirmen_lv": meta_degirmen_lv}))

func load_meta() -> void:
	if not FileAccess.file_exists(META_PATH):
		return
	var f := FileAccess.open(META_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	meta_kalinti = int(d.get("kalinti", 0))
	meta_gold_lv = int(d.get("gold_lv", 0))
	meta_flag_lv = int(d.get("flag_lv", 0))
	meta_mevzi_lv = int(d.get("mevzi_lv", 0))
	meta_degirmen_lv = int(d.get("degirmen_lv", 0))

## Sefer sonu meta kaynak ver (geçilen katmana göre) + kalıcı kaydet
func award_meta(layers_cleared: int, won: bool) -> int:
	var earned := layers_cleared * 2 + (10 if won else 0)
	meta_kalinti += earned
	save_meta()
	return earned

func start_new_run(seed_value: int = 0) -> void:
	run_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	RNG.reseed(run_seed)
	load_meta()                                  # Garnizon kalıcı upgrade'leri
	gold = 25 + meta_gold_lv * 5
	layer_index = 0
	mevzi = 6 + meta_mevzi_lv
	player_flag_hp = PLAYER_FLAG_MAX + meta_flag_lv * 5
	zar = 4 + meta_degirmen_lv * 2   # Değirmen (§6): sefer başı zar
	run_over = false
	relics = []
	items = []
	armed_items = []
	squad = []
	for p: PieceData in Database.get_all("pieces"):
		if p.starter:
			squad.append(p)
	squad_hp.clear()
	for i in squad.size():
		squad_hp[i] = squad[i].can

## Recruit havuzu (starter olmayan tüm birimler) — ödül/dükkan çeker
func recruit_pool() -> Array:
	var pool: Array = []
	for p: PieceData in Database.get_all("pieces"):
		if not p.starter:
			pool.append(p)
	return pool

## Bayrak CAN tavanı (meta seviyesi dahil) — onarım/heal bu değeri aşamaz
func flag_cap() -> int:
	return PLAYER_FLAG_MAX + meta_flag_lv * 5

## Bayrak dayanıklılığı harca (Gri Mezar riski §11). 1'in altına düşürmez;
## bedel ödenemiyorsa false (bayrak zaten ölümün eşiğinde).
func spend_flag(n: int) -> bool:
	if player_flag_hp - n < 1:
		return false
	player_flag_hp -= n
	return true

## Item envanteri (gelistirme §5 Kitapçı). Kapasite ITEM_CAP; doluysa alınamaz.
func add_item(it: ItemData) -> bool:
	if items.size() >= ITEM_CAP:
		return false
	items.append(it)
	return true

## Haritadan kullanım: ANINDA hemen işler, SONRAKI_SAVAS kuşanılır (armed).
func use_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var it: ItemData = items[index]
	items.remove_at(index)
	if it.tur == ItemData.Tur.SONRAKI_SAVAS:
		armed_items.append(it)
		return
	if it.heal_suru:
		heal_all()
	if it.bayrak_onar > 0:
		player_flag_hp = mini(flag_cap(), player_flag_hp + it.bayrak_onar)
	if it.zar_ver > 0:
		zar += it.zar_ver

## Savaş bitti (zafer/yenilgi fark etmez): kuşanılmış item'lar tükendi
func consume_armed_items() -> void:
	armed_items.clear()

## Savaş sonu: oyuncu bayrağının kalan CAN'ını kalıcı olarak yaz. 0 = run biter.
func apply_flag_result(remaining_hp: int) -> void:
	player_flag_hp = maxi(0, remaining_hp)
	if player_flag_hp <= 0:
		run_over = true

## Zar harca (reroll noktaları §6). Yetmiyorsa false.
func spend_zar(n: int = 1) -> bool:
	if zar < n:
		return false
	zar -= n
	return true

func add_unit(piece: PieceData) -> void:
	squad.append(piece)
	squad_hp[squad.size() - 1] = piece.can

## Şaman Çadırı (§9): kadro birimine kalıcı stat yükseltmesi. Database kaynağını
## KİRLETMEMEK için birim ilk yükseltmede kopyalanır (runlar arası sızıntı olmaz).
## alan: &"saldiri" | &"can" | &"hiz"
func upgrade_unit(index: int, alan: StringName, miktar: int) -> void:
	var p: PieceData = squad[index]
	if p.resource_path != "":           # hâlâ paylaşılan .tres → kopyala
		p = p.duplicate()
		squad[index] = p
	p.set(alan, p.get(alan) + miktar)
	p.upgrades += 1
	if alan == &"can":                  # tavan büyüdü: mevcut CAN da aynı kadar artar
		squad_hp[index] = clampi(int(squad_hp.get(index, p.can)) + miktar, 1, p.can)

## Nitelik Dükkanı / Darağacı (§5): kadro birimine tabya ver. Slot doluysa false.
## Paylaşılan .tres kirlenmesin diye ilk değişimde kopyalanır (upgrade_unit gibi).
func give_trait(index: int, t: TraitData) -> bool:
	var p: PieceData = squad[index]
	if p.base_traits.size() >= p.tabya_slotu:
		return false
	if p.resource_path != "":
		p = p.duplicate()
		p.base_traits = p.base_traits.duplicate()
		squad[index] = p
	p.base_traits.append(t)
	return true

## Meydan kumarı (§7): statları yeniden dağıt + söylenti/upgrade ver. Kopyala-önce.
func apply_gamble(index: int, yeni_a: int, yeni_c: int, yeni_h: int) -> void:
	var p: PieceData = squad[index]
	if p.resource_path != "":
		p = p.duplicate()
		squad[index] = p
	p.saldiri = yeni_a
	p.can = yeni_c
	p.hiz = yeni_h
	squad_hp[index] = clampi(int(squad_hp.get(index, yeni_c)), 1, yeni_c)

## Söylenti tak (§14): birim başına 1 — yenisi eskisinin yerine geçer
func set_rumor(index: int, r: TraitData) -> void:
	var p: PieceData = squad[index]
	if p.resource_path != "":
		p = p.duplicate()
		squad[index] = p
	p.rumor = r

## Darağacı (§5): birimi kadrodan çıkar — kalan birimlerin CAN durumu KORUNUR
## (indeksler kayar; shop sürgünündeki "herkes iyileşir" yan etkisi burada yok).
func remove_unit(index: int) -> void:
	squad.remove_at(index)
	var yeni := {}
	for i in squad.size():
		var eski_i := i if i < index else i + 1
		yeni[i] = clampi(int(squad_hp.get(eski_i, squad[i].can)), 1, squad[i].can)
	squad_hp = yeni

func heal_all() -> void:
	for i in squad.size():
		squad_hp[i] = squad[i].can

func current_hp(index: int) -> int:
	return clampi(squad_hp.get(index, squad[index].can), 1, squad[index].can)

# ------------------------------------------------------------- kaydetme (B.5)

const SAVE_PATH := "user://save.json"

func save_run() -> void:
	var hp := {}
	for k in squad_hp:
		hp[str(k)] = squad_hp[k]
	var data := {
		"gold": gold, "layer_index": layer_index, "player_flag_hp": player_flag_hp,
		"run_seed": run_seed, "commander_id": String(commander_id), "run_over": run_over,
		"zar": zar,
		"squad_ids": squad.map(func(p: PieceData) -> String: return String(p.id)),
		"relic_ids": relics.map(func(r: RelicData) -> String: return String(r.id)),
		"item_ids": items.map(func(it: ItemData) -> String: return String(it.id)),
		"armed_item_ids": armed_items.map(func(it: ItemData) -> String: return String(it.id)),
		"squad_hp": hp,
		# Şaman yükseltmeleri (§9): id'den yüklenen taban statların üstüne yazılır
		"squad_stats": squad.map(func(p: PieceData) -> Dictionary:
			return {"a": p.saldiri, "c": p.can, "h": p.hiz, "u": p.upgrades}),
		# Nitelik Dükkanı / Darağacı tabyaları (§5): id listesi olarak saklanır
		"squad_traits": squad.map(func(p: PieceData) -> Array:
			return p.base_traits.map(func(t: TraitData) -> String: return String(t.id))),
		# Söylentiler (§14): birim başına 1 id ("" = yok)
		"squad_rumors": squad.map(func(p: PieceData) -> String:
			return String(p.rumor.id) if p.rumor else ""),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

## Kayıt yükle. Başarısız/bozuksa false → yeni run başlatılır.
func load_run() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	gold = int(data.get("gold", 25))
	layer_index = int(data.get("layer_index", 0))
	player_flag_hp = int(data.get("player_flag_hp", PLAYER_FLAG_MAX))
	run_seed = int(data.get("run_seed", 0))
	RNG.reseed(run_seed)
	commander_id = StringName(data.get("commander_id", "cesur"))
	run_over = data.get("run_over", false)
	zar = int(data.get("zar", 4))
	items = []
	for iid in data.get("item_ids", []):
		var it := Database.get_resource("items", StringName(iid))
		if it:
			items.append(it)
	armed_items = []
	for iid in data.get("armed_item_ids", []):
		var ait := Database.get_resource("items", StringName(iid))
		if ait:
			armed_items.append(ait)
	squad = []
	var stats: Array = data.get("squad_stats", [])
	var traits: Array = data.get("squad_traits", [])
	for pid in data.get("squad_ids", []):
		var p := Database.get_resource("pieces", StringName(pid))
		if p == null:
			continue
		var si := squad.size()
		# Şaman yükseltmesi varsa (statlar tabandan sapmış) kopyala + uygula
		if si < stats.size() and typeof(stats[si]) == TYPE_DICTIONARY:
			var s: Dictionary = stats[si]
			if int(s.get("u", 0)) > 0:
				p = p.duplicate()
				p.saldiri = int(s.get("a", p.saldiri))
				p.can = int(s.get("c", p.can))
				p.hiz = int(s.get("h", p.hiz))
				p.upgrades = int(s.get("u", 0))
		# Söylenti varsa uygula (birim başına 1)
		var rumors: Array = data.get("squad_rumors", [])
		if si < rumors.size() and String(rumors[si]) != "":
			var r := Database.get_resource("rumors", StringName(rumors[si]))
			if r:
				if p.resource_path != "":
					p = p.duplicate()
				p.rumor = r
		# Tabya listesi tabandan farklıysa (Nitelik Dükkanı/Darağacı) uygula
		if si < traits.size() and typeof(traits[si]) == TYPE_ARRAY:
			var ids: Array = traits[si]
			var base_ids: Array = p.base_traits.map(
				func(t: TraitData) -> String: return String(t.id))
			if ids != base_ids:
				if p.resource_path != "":
					p = p.duplicate()
				p.base_traits = []
				for tid in ids:
					var t := Database.get_resource("traits", StringName(tid))
					if t:
						p.base_traits.append(t)
		squad.append(p)
	if squad.is_empty():
		for p: PieceData in Database.get_all("pieces"):
			if p.starter:
				squad.append(p)
	relics = []
	for rid in data.get("relic_ids", []):
		var r := Database.get_resource("relics", StringName(rid))
		if r:
			relics.append(r)
	squad_hp.clear()
	var hp = data.get("squad_hp", {})
	for i in squad.size():
		squad_hp[i] = int(hp.get(str(i), squad[i].can))
	return layer_index < Encounters.MAP_TEMPLATE.size()
