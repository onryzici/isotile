extends SceneTree
## CombatResolver testleri — M0 çekirdek + M1 tabya/statü sistemi.
## Çalıştırma: godot --headless --path . --script res://tests/run_combat_test.gd

var failures := 0

func _init() -> void:
	_test_damage_formula()
	_test_trait_nisan()
	_test_trait_kanat_ve_lanet()
	_test_trait_kalkan_durusu()
	_test_trait_kan_kaybi_zehir_tick()
	_test_trait_sarsici_stun()
	_test_trait_ofke_birikim()
	_test_trait_kizil_ziyafet()
	_test_trait_son_nefes()
	_test_yukselti_bonus()
	_test_terrain_kutsal_ve_pus_tile()
	_test_terrain_lav()
	_test_terrain_diken()
	_test_terrain_duvar_dolasma()
	_test_full_battle_and_determinism()
	_test_pus_pressure_breaks_stall()
	_test_flag_victory()
	if failures == 0:
		print("\n=== TÜM TESTLER GEÇTİ ===")
	else:
		print("\n=== %d TEST BAŞARISIZ ===" % failures)
	quit(1 if failures > 0 else 0)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("  [OK] %s" % label)
	else:
		failures += 1
		print("  [FAIL] %s" % label)

func _make_unit(atk: int, hp: int, spd: int, sinif: int, side: int, coord: Vector2i, uid: int, ad := "") -> CombatUnit:
	var p := PieceData.new()
	p.id = StringName("test_%d" % uid)
	p.ad = ad if ad != "" else "Birim%d" % uid
	p.sinif = sinif
	p.saldiri = atk
	p.can = hp
	p.hiz = spd
	return CombatUnit.from_piece(p, side, coord, uid)

func _make_trait(tetik: int, props: Dictionary = {}) -> TraitData:
	var t := TraitData.new()
	t.tetik = tetik
	for key in props:
		t.set(key, props[key])
	if t.id == &"":
		t.id = &"test_trait"
		t.ad = "TestTabya"
	return t

# ---------------------------------------------------------------- çekirdek

func _test_damage_formula() -> void:
	print("\n[Güç×Kat hasar formülü — §3.6]")
	var src := _make_unit(3, 10, 5, PieceData.Sinif.MELEE, 0, Vector2i(0, 0), 1)
	src.ek_guc = 2      # chips
	src.kat = 1.5       # mult
	var dst := _make_unit(1, 10, 3, PieceData.Sinif.MELEE, 1, Vector2i(0, 1), 2)
	dst.zirh = 1
	dst.kalkan = 3
	var events: Array = []
	CombatResolver._attack(src, dst, [src, dst], {}, events)
	var ev: Dictionary = events[0]
	_check(ev["raw"] == 7, "raw = floor((3+2)×1.5) = 7 → %d" % ev["raw"])
	_check(ev["final"] == 6, "final = raw − zırh = 6 → %d" % ev["final"])
	_check(dst.kalkan == 0, "kalkan önce tükendi → %d" % dst.kalkan)
	_check(dst.hp == 7, "hp 10 → 7 (kalkan 3 emdi) → %d" % dst.hp)

# ---------------------------------------------------------------- tabyalar (§5.3)

func _test_trait_nisan() -> void:
	print("\n[Nişan: aynı satır/kolonda ×1.5 Kat]")
	var src := _make_unit(4, 10, 5, PieceData.Sinif.RANGED, 0, Vector2i(2, 0), 1)
	src.traits = [_make_trait(TraitData.Tetik.PASSIVE,
		{"kosul": TraitData.Kosul.HEDEF_AYNI_SATIR_KOLON, "kat": 1.5})]
	var ayni_kolon := _make_unit(1, 20, 3, PieceData.Sinif.MELEE, 1, Vector2i(2, 4), 2)
	var capraz := _make_unit(1, 20, 3, PieceData.Sinif.MELEE, 1, Vector2i(3, 4), 3)
	var e1: Array = []
	CombatResolver._attack(src, ayni_kolon, [src, ayni_kolon], {}, e1)
	_check(e1[0]["raw"] == 6, "aynı kolonda: floor(4×1.5) = 6 → %d" % e1[0]["raw"])
	var e2: Array = []
	CombatResolver._attack(src, capraz, [src, capraz], {}, e2)
	_check(e2[0]["raw"] == 4, "çaprazda: kat işlemez, 4 → %d" % e2[0]["raw"])

func _test_trait_kanat_ve_lanet() -> void:
	print("\n[Kanat (+3 dış kolonda) ve Lanet (×0.5)]")
	var src := _make_unit(3, 10, 5, PieceData.Sinif.MELEE, 0, Vector2i(0, 0), 1)
	src.traits = [_make_trait(TraitData.Tetik.PASSIVE,
		{"kosul": TraitData.Kosul.DIS_KOLON, "ek_guc": 3})]
	var dst := _make_unit(1, 30, 3, PieceData.Sinif.MELEE, 1, Vector2i(0, 1), 2)
	var e1: Array = []
	CombatResolver._attack(src, dst, [src, dst], {}, e1)
	_check(e1[0]["raw"] == 6, "A kolonunda: 3+3 = 6 → %d" % e1[0]["raw"])
	src.coord = Vector2i(2, 0)
	var e2: Array = []
	CombatResolver._attack(src, dst, [src, dst], {}, e2)
	_check(e2[0]["raw"] == 3, "iç kolonda: 3 → %d" % e2[0]["raw"])
	src.coord = Vector2i(0, 0)
	src.lanet_sure = 2
	var e3: Array = []
	CombatResolver._attack(src, dst, [src, dst], {}, e3)
	_check(e3[0]["raw"] == 3, "Lanetli: floor(6×0.5) = 3 → %d" % e3[0]["raw"])

func _test_trait_kalkan_durusu() -> void:
	print("\n[Kalkan Duruşu: deploy'da CAN kadar Kalkan]")
	var u := _make_unit(3, 10, 5, PieceData.Sinif.MELEE, 0, Vector2i(0, 0), 1)
	u.traits = [_make_trait(TraitData.Tetik.ON_DEPLOY, {"statu": &"kalkan", "statu_deger": 0})]
	var enemy := _make_unit(2, 40, 1, PieceData.Sinif.RANGED, 1, Vector2i(5, 4), 2)
	var r := CombatResolver.resolve([u, enemy])
	var kalkan_ev: Array = r["events"].filter(func(e): return e["t"] == "STATUS" and e["status"] == "kalkan")
	_check(not kalkan_ev.is_empty() and kalkan_ev[0]["stacks"] == 10,
		"savaş başı kalkan = 10 → %s" % str(kalkan_ev[0]["stacks"] if not kalkan_ev.is_empty() else "yok"))

func _test_trait_kan_kaybi_zehir_tick() -> void:
	print("\n[Kan Kaybı → Zehir tick (X hasar, X→X−1) — §6]")
	var src := _make_unit(1, 30, 9, PieceData.Sinif.MELEE, 0, Vector2i(2, 2), 1)
	src.traits = [_make_trait(TraitData.Tetik.ON_HIT,
		{"statu": &"zehir", "statu_deger": 2, "hedef": TraitData.Hedef.VURULAN})]
	var dst := _make_unit(0, 10, 1, PieceData.Sinif.SUPPORT, 1, Vector2i(2, 3), 2)
	var r := CombatResolver.resolve([src, dst])
	# Tur1: vur(1) + zehir 2 | Tur2 başı: zehir tick 2 (hp: 10-1-2=7), zehir→1, vur(1)+2 yeni zehir→3
	var ticks: Array = r["events"].filter(func(e): return e["t"] == "STATUS_DAMAGE" and e["status"] == "zehir")
	_check(ticks.size() >= 2, "zehir en az 2 kez tick etti (%d)" % ticks.size())
	_check(ticks[0]["damage"] == 2, "ilk tick 2 hasar → %d" % ticks[0]["damage"])
	_check(r["kazanan"] == "PLAYER", "zehir + vuruş hedefi eritti (kazanan %s)" % r["kazanan"])

func _test_trait_sarsici_stun() -> void:
	print("\n[Sarsıcı: her 2. vuruşta Sersem; Sersem aktivasyon atlatır — §6]")
	var src := _make_unit(1, 50, 9, PieceData.Sinif.MELEE, 0, Vector2i(2, 2), 1)
	src.traits = [_make_trait(TraitData.Tetik.ON_HIT,
		{"kosul_deger": 2, "statu": &"sersem", "statu_deger": 1, "hedef": TraitData.Hedef.VURULAN})]
	var dst := _make_unit(1, 12, 5, PieceData.Sinif.MELEE, 1, Vector2i(2, 3), 2)
	var r := CombatResolver.resolve([src, dst])
	var stuns: Array = r["events"].filter(func(e): return e["t"] == "STATUS" and e["status"] == "sersem" and e["stacks"] > 0)
	var skips: Array = r["events"].filter(func(e): return e["t"] == "STUN_SKIP")
	_check(not stuns.is_empty(), "sersem uygulandı (%d kez)" % stuns.size())
	_check(not skips.is_empty(), "sersemleyen aktivasyon atladı (%d kez)" % skips.size())

func _test_trait_ofke_birikim() -> void:
	print("\n[Öfke: tur başı +1 Güç birikir]")
	var src := _make_unit(2, 40, 9, PieceData.Sinif.RANGED, 0, Vector2i(0, 0), 1)
	src.traits = [_make_trait(TraitData.Tetik.ROUND_START, {"kalici_ek_guc": 1})]
	var dst := _make_unit(0, 60, 1, PieceData.Sinif.SUPPORT, 1, Vector2i(5, 4), 2)
	var r := CombatResolver.resolve([src, dst])
	var attacks: Array = r["events"].filter(func(e): return e["t"] == "ATTACK")
	_check(attacks[0]["raw"] == 3, "tur 1: 2+1 = 3 → %d" % attacks[0]["raw"])
	_check(attacks[2]["raw"] == 5, "tur 3: 2+3 = 5 → %d" % attacks[2]["raw"])

func _test_trait_kizil_ziyafet() -> void:
	print("\n[Kızıl Ziyafet: öldürünce kalıcı +0.2 Kat]")
	var src := _make_unit(5, 50, 9, PieceData.Sinif.RANGED, 0, Vector2i(0, 0), 1)
	src.traits = [_make_trait(TraitData.Tetik.ON_KILL, {"kalici_kat": 0.2})]
	var kurban := _make_unit(0, 3, 5, PieceData.Sinif.SUPPORT, 1, Vector2i(0, 4), 2)
	var tank := _make_unit(0, 40, 1, PieceData.Sinif.SUPPORT, 1, Vector2i(5, 4), 3)
	var r := CombatResolver.resolve([src, kurban, tank])
	var attacks: Array = r["events"].filter(func(e): return e["t"] == "ATTACK")
	_check(attacks[0]["raw"] == 5, "kill öncesi: 5 → %d" % attacks[0]["raw"])
	_check(attacks[1]["raw"] == 6, "kill sonrası: floor(5×1.2) = 6 → %d" % attacks[1]["raw"])

func _test_trait_son_nefes() -> void:
	print("\n[Son Nefes: ölünce komşu düşmanlara %50 max CAN hasar]")
	var bomba := _make_unit(0, 10, 1, PieceData.Sinif.SUPPORT, 1, Vector2i(2, 3), 1)
	bomba.traits = [_make_trait(TraitData.Tetik.ON_DEATH,
		{"hasar_yuzde_can": 0.5, "hedef": TraitData.Hedef.KOMSU_DUSMANLAR})]
	var katil := _make_unit(10, 20, 9, PieceData.Sinif.MELEE, 0, Vector2i(2, 2), 2)
	var r := CombatResolver.resolve([katil, bomba])
	var patlama: Array = r["events"].filter(func(e): return e["t"] == "STATUS_DAMAGE" and e["status"] == "patlama")
	_check(not patlama.is_empty() and patlama[0]["damage"] == 5,
		"patlama 5 hasar (10×0.5) → %s" % str(patlama[0]["damage"] if not patlama.is_empty() else "yok"))

func _test_yukselti_bonus() -> void:
	print("\n[Yükselti zemini: üstündeki herkese +1 Güç — §7]")
	var src := _make_unit(3, 10, 5, PieceData.Sinif.RANGED, 0, Vector2i(1, 1), 1)
	var dst := _make_unit(1, 30, 1, PieceData.Sinif.MELEE, 1, Vector2i(1, 4), 2)
	var e1: Array = []
	CombatResolver._attack(src, dst, [src, dst], {"heights": {Vector2i(1, 1): 1}}, e1)
	_check(e1[0]["raw"] == 4, "yükseltide: 3+1 = 4 → %d" % e1[0]["raw"])
	var e2: Array = []
	CombatResolver._attack(src, dst, [src, dst], {"heights": {}}, e2)
	_check(e2[0]["raw"] == 3, "düz zeminde: 3 → %d" % e2[0]["raw"])

# ---------------------------------------------------------------- zemin (§7)

func _test_terrain_kutsal_ve_pus_tile() -> void:
	print("\n[Kutsal Zemin (+2 Güç) ve Pus Tile (×0.75 Kat)]")
	var src := _make_unit(4, 10, 5, PieceData.Sinif.RANGED, 0, Vector2i(1, 1), 1)
	var dst := _make_unit(1, 30, 1, PieceData.Sinif.MELEE, 1, Vector2i(4, 4), 2)
	var e1: Array = []
	CombatResolver._attack(src, dst, [src, dst], {"terrain": {Vector2i(1, 1): &"kutsal"}}, e1)
	_check(e1[0]["raw"] == 6, "kutsalda: 4+2 = 6 → %d" % e1[0]["raw"])
	var e2: Array = []
	CombatResolver._attack(src, dst, [src, dst], {"terrain": {Vector2i(1, 1): &"pus"}}, e2)
	_check(e2[0]["raw"] == 3, "pus tile'da: floor(4×0.75) = 3 → %d" % e2[0]["raw"])

func _test_terrain_lav() -> void:
	print("\n[Lav: üstünde duran tur başı 3 hasar]")
	var lavdaki := _make_unit(0, 9, 5, PieceData.Sinif.SUPPORT, 0, Vector2i(2, 2), 1)
	var uzak := _make_unit(0, 60, 1, PieceData.Sinif.SUPPORT, 1, Vector2i(5, 4), 2)
	var r := CombatResolver.resolve([lavdaki, uzak], {"terrain": {Vector2i(2, 2): &"lav"}})
	var lav_ticks: Array = r["events"].filter(func(e): return e["t"] == "STATUS_DAMAGE" and e["status"] == "lav")
	_check(lav_ticks.size() == 3, "3 turda eridi (9 HP / 3) → %d tick" % lav_ticks.size())

func _test_terrain_diken() -> void:
	print("\n[Diken: ilk girene 2 hasar, sonra tükenir]")
	# Melee düşmana yürürken dikenden geçmek zorunda kalacak dar koridor
	var kosan := _make_unit(1, 20, 9, PieceData.Sinif.MELEE, 0, Vector2i(2, 0), 1)
	var hedef := _make_unit(0, 40, 1, PieceData.Sinif.SUPPORT, 1, Vector2i(2, 4), 2)
	var terrain := {Vector2i(2, 1): &"diken", Vector2i(1, 1): &"duvar", Vector2i(3, 1): &"duvar",
		Vector2i(0, 1): &"duvar", Vector2i(4, 1): &"duvar", Vector2i(5, 1): &"duvar"}
	var r := CombatResolver.resolve([kosan, hedef], {"terrain": terrain})
	var diken_ev: Array = r["events"].filter(func(e): return e["t"] == "TERRAIN" and e["terrain"] == "diken")
	_check(diken_ev.size() == 1, "diken tam 1 kez tetiklendi → %d" % diken_ev.size())
	_check(diken_ev[0]["damage"] == 2, "diken 2 hasar verdi → %d" % diken_ev[0]["damage"])

func _test_terrain_duvar_dolasma() -> void:
	print("\n[Duvar: hareketi bloklar, melee etrafından dolaşır]")
	var kosan := _make_unit(5, 30, 9, PieceData.Sinif.MELEE, 0, Vector2i(2, 0), 1)
	var hedef := _make_unit(0, 12, 1, PieceData.Sinif.SUPPORT, 1, Vector2i(2, 4), 2)
	var duvar := Vector2i(2, 2)
	var r := CombatResolver.resolve([kosan, hedef], {"terrain": {duvar: &"duvar"}})
	var duvara_giren: Array = r["events"].filter(func(e): return e["t"] == "MOVE" and e["to"] == duvar)
	var moves: Array = r["events"].filter(func(e): return e["t"] == "MOVE")
	_check(duvara_giren.is_empty(), "hiçbir hamle duvar tile'ına girmedi")
	_check(not moves.is_empty() and r["kazanan"] == "PLAYER", "dolaşıp hedefe ulaştı (kazanan %s)" % r["kazanan"])

# ---------------------------------------------------------------- entegrasyon

func _load_squad_scenario() -> Array:
	# Gerçek .tres verileriyle (tabyalar dahil) sahne kurulumu
	var units: Array = []
	var uid := 0
	var player_setup := {
		"res://data/pieces/mizrakli.tres": Vector2i(1, 1),
		"res://data/pieces/okcu.tres": Vector2i(2, 0),
		"res://data/pieces/sifaci.tres": Vector2i(3, 0),
		"res://data/pieces/serdengecti.tres": Vector2i(4, 1),
	}
	for path in player_setup:
		uid += 1
		units.append(CombatUnit.from_piece(load(path), CombatResolver.SIDE_PLAYER, player_setup[path], uid))
	var enemy_setup := {
		"res://data/enemies/pus_yuruyucu.tres": Vector2i(1, 3),
		"res://data/enemies/zirhli.tres": Vector2i(2, 3),
		"res://data/enemies/nisanci.tres": Vector2i(3, 4),
	}
	for path in enemy_setup:
		uid += 1
		units.append(CombatUnit.from_piece(load(path), CombatResolver.SIDE_ENEMY, enemy_setup[path], uid))
	uid += 1
	units.append(CombatUnit.from_piece(load("res://data/enemies/pus_yuruyucu.tres"),
		CombatResolver.SIDE_ENEMY, Vector2i(4, 3), uid))
	return units

func _test_full_battle_and_determinism() -> void:
	print("\n[Tam savaş (.tres tabyalar + zemin) + determinizm — §1.2]")
	var ctx := {
		"heights": {Vector2i(1, 3): 1, Vector2i(4, 2): 1},
		"terrain": {Vector2i(0, 2): &"duvar", Vector2i(2, 2): &"lav",
			Vector2i(3, 2): &"diken", Vector2i(5, 2): &"pus", Vector2i(1, 1): &"kutsal"},
	}
	var r1: Dictionary = CombatResolver.resolve(_load_squad_scenario(), ctx)
	var r2: Dictionary = CombatResolver.resolve(_load_squad_scenario(), ctx)
	_check(JSON.stringify(r1["events"]) == JSON.stringify(r2["events"]),
		"aynı kurulum = birebir aynı event listesi (%d event)" % r1["events"].size())
	_check(r1["rounds"] <= BoardDefs.MAX_ROUND, "tur limiti aşılmadı (%d tur)" % r1["rounds"])
	var procs: Array = r1["events"].filter(func(e): return e["t"] == "TRAIT_PROC")
	_check(not procs.is_empty(), "tabyalar tetiklendi (%d proc)" % procs.size())
	_print_battle_log(r1)

func _test_pus_pressure_breaks_stall() -> void:
	print("\n[Pus Basıncı sonsuz savaşı çözer — §3.7]")
	var units: Array = []
	units.append(_make_unit(0, 30, 5, PieceData.Sinif.SUPPORT, 0, Vector2i(0, 0), 1))
	units.append(_make_unit(0, 30, 5, PieceData.Sinif.SUPPORT, 1, Vector2i(5, 4), 2))
	var r: Dictionary = CombatResolver.resolve(units)
	var pus_events: int = r["events"].filter(func(e): return e["t"] == "PUS_DAMAGE").size()
	_check(pus_events > 0, "pus hasarı işledi (%d event)" % pus_events)
	_check(r["rounds"] <= BoardDefs.MAX_ROUND, "savaş sonlandı: %d turda, kazanan %s" % [r["rounds"], r["kazanan"]])

# ---------------------------------------------------------------- log

func _print_battle_log(result: Dictionary) -> void:
	var names := {}
	for u: CombatUnit in result["units"]:
		names[u.uid] = u.ad
	print("\n  --- SAVAŞ KAYDI (%s kazandı, %d tur) ---" % [result["kazanan"], result["rounds"]])
	for e: Dictionary in result["events"]:
		match e["t"]:
			"ROUND_START":
				print("  ── Tur %d ──" % e["round"])
			"MOVE":
				print("    %s: %s → %s" % [names[e["unit_id"]],
					BoardDefs.coord_name(e["from"]), BoardDefs.coord_name(e["to"])])
			"ATTACK":
				print("    %s ⚔ %s: %d hasar (raw %d)" % [names[e["src"]], names[e["dst"]], e["final"], e["raw"]])
			"HEAL":
				print("    %s ✚ %s: +%d" % [names[e["src"]], names[e["dst"]], e["amount"]])
			"TRAIT_PROC":
				print("    ★ %s: [%s]" % [names[e["unit_id"]], e["ad"]])
			"STATUS":
				print("      %s: %s = %d" % [names[e["target"]], e["status"], e["stacks"]])
			"STATUS_DAMAGE":
				print("    %s ← %s: −%d" % [names[e["unit_id"]], e["status"], e["damage"]])
			"STUN_SKIP":
				print("    %s sersem — tur atladı" % names[e["unit_id"]])
			"PUS_DAMAGE":
				print("    PUS → %s: −%d" % [names[e["unit_id"]], e["damage"]])
			"DEATH":
				print("    ☠ %s öldü" % names[e["unit_id"]])

## Bayrak-yıkma zafer koşulu + kalıcı bayrak (§B.0/1-2)
func _test_flag_victory() -> void:
	print("\n[Bayrak-yıkma zafer koşulu — §B.0/1]")
	var hero := _make_unit(5, 20, 5, PieceData.Sinif.MELEE, 0, Vector2i(2, 3), 1)
	var pflag := CombatUnit.make_flag(0, Vector2i(2, 0), 30, 2)
	var eflag := CombatUnit.make_flag(1, Vector2i(2, 4), 8, 3)
	var r := CombatResolver.resolve([hero, pflag, eflag], {}, 1)
	_check(r["kazanan"] == "PLAYER", "oyuncu düşman bayrağını yıktı")
	_check(not eflag.alive, "düşman bayrağı düştü")
	_check(pflag.alive and pflag.hp == 30, "oyuncu bayrağı sağlam kaldı")
	# Determinizm
	var r2 := CombatResolver.resolve([
		_make_unit(5, 20, 5, PieceData.Sinif.MELEE, 0, Vector2i(2, 3), 1),
		CombatUnit.make_flag(0, Vector2i(2, 0), 30, 2),
		CombatUnit.make_flag(1, Vector2i(2, 4), 8, 3)], {}, 1)
	_check(r["events"].size() == r2["events"].size(), "aynı kurulum = aynı event sayısı")
