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

var squad: Array = []                     # PieceData listesi (kadro, run içinde büyür)
var squad_hp: Dictionary = {}             # squad index -> güncel CAN
var mevzi: int = 6                        # savaş başı Mevzi (AP) (§21)
var relics: Array = []                    # RelicData listesi (run boyu global pasif)
var commander_id: StringName = &"cesur"   # seçili kumandan (§B.0/4)

## Relic alanları toplamı (global_ek_guc, mevzi_bonus, altin_bonus...)
func relic_sum(field: StringName) -> int:
	var t := 0
	for r in relics:
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
const META_PATH := "user://garrison.json"

func save_meta() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"kalinti": meta_kalinti,
			"gold_lv": meta_gold_lv, "flag_lv": meta_flag_lv, "mevzi_lv": meta_mevzi_lv}))

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
	run_over = false
	relics = []
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

## Savaş sonu: oyuncu bayrağının kalan CAN'ını kalıcı olarak yaz. 0 = run biter.
func apply_flag_result(remaining_hp: int) -> void:
	player_flag_hp = maxi(0, remaining_hp)
	if player_flag_hp <= 0:
		run_over = true

func add_unit(piece: PieceData) -> void:
	squad.append(piece)
	squad_hp[squad.size() - 1] = piece.can

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
		"squad_ids": squad.map(func(p: PieceData) -> String: return String(p.id)),
		"relic_ids": relics.map(func(r: RelicData) -> String: return String(r.id)),
		"squad_hp": hp,
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
	squad = []
	for pid in data.get("squad_ids", []):
		var p := Database.get_resource("pieces", StringName(pid))
		if p:
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
