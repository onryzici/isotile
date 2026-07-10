class_name CombatResolver
extends RefCounted
## SAF, DETERMİNİSTİK savaş çözücü (CLAUDE.md §3, §5, §6, §17.2).
## Girdi: CombatUnit dizisi + ctx {heights: Dictionary}. Çıktı: sıralı event listesi.
## SAVAŞ İÇİ RASTLANTI YOK (§1.2): aynı kurulum = aynı event listesi, her zaman.
##
## Event şemaları (§17.2):
##   {t:"ROUND_START", round}
##   {t:"ACTIVATE", unit_id}
##   {t:"MOVE", unit_id, from, to}
##   {t:"ATTACK", src, dst, raw, final, crit}
##   {t:"HEAL", src, dst, amount}
##   {t:"STATUS", target, status, stacks}          # stacks = yeni toplam
##   {t:"STATUS_DAMAGE", unit_id, status, damage}  # Zehir/Yanık tick
##   {t:"TRAIT_PROC", unit_id, trait_id, ad}
##   {t:"STUN_SKIP", unit_id}
##   {t:"PUS_DAMAGE", unit_id, damage}
##   {t:"TERRAIN", terrain, coord, unit_id, damage}   # Diken tetiklendi vb.
##   {t:"DEATH", unit_id}
##   {t:"END", kazanan}
##
## ctx: {heights: {Vector2i: int}, terrain: {Vector2i: StringName}}
## Zemin tipleri (§7): duvar (hareket bloklar; yıkılabilirlik M2+),
## lav (tur başı 3), diken (ilk girene 2, tükenir), kutsal (+2 Güç),
## pus (×0.75 Kat), yükselti (heights>0: +1 Güç; menzil bonusu M2+).

const SIDE_PLAYER := 0
const SIDE_ENEMY := 1

const SUPPORT_HEAL := 2   # destek sınıfının aktivasyon iyileştirmesi (§3.4)
const BOSS_YANIK_HASAR := 3   # BOSS Alev Nefesi: vuruşta uygulanan Yanık hasarı

## 8 yön — sabit sıra = deterministik tie-break
const DIRS8: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1),
]

static func resolve(units: Array, ctx: Dictionary = {}, _seed: int = 0) -> Dictionary:
	var events: Array = []
	var state := {"diken": {}}   # savaş içi tüketilen zemin (ctx MUTASYONA UĞRAMAZ)
	_deploy_procs(units, ctx, events)   # ON_DEPLOY tabyaları (Kalkan Duruşu)
	var round_no := 0
	while not _battle_over(units) and round_no < BoardDefs.MAX_ROUND:
		round_no += 1
		events.append_array(resolve_round(units, ctx, round_no, state))
	var kazanan := _decide_winner(units)
	events.append({"t": "END", "kazanan": kazanan})
	return {"events": events, "kazanan": kazanan, "rounds": round_no, "units": units}

## TEK TUR çöz (§B.0/3 tur-tur döngüsü için): tur başı efektleri + aktivasyonlar.
## `state` diken gibi savaş-boyu tüketilenleri taşır (turlar arası korunmalı).
## Tur-tur modda battle_screen bunu her tur çağırır, aralarda AP planlaması yapar.
## player_reserves: piece-out (§13) erken-çıkışının oyuncu yedeğini bilmesi için —
## sahadaki son oyuncu birimi ölse de yedek varsa tur normal sürer (düşman yürür).
static func resolve_round(units: Array, ctx: Dictionary, round_no: int, state: Dictionary,
		player_reserves: int = 0) -> Array:
	var events: Array = []
	events.append({"t": "ROUND_START", "round": round_no})
	_round_start_effects(units, ctx, round_no, events)   # zemin, DoT, aura, birikim, pus (§3.3)
	if _battle_over(units, player_reserves):
		return events
	for unit: CombatUnit in _activation_order(units, ctx, events):
		if not unit.alive:
			continue
		_activate(unit, units, ctx, state, events)
		if _battle_over(units, player_reserves):
			break
	return events

## ON_DEPLOY tabyalarını yalnız verilen (yeni yerleştirilen) birimler için tetikle
## (§B.0/3: tur-tur deploy). Tüm-birim varyantı için _deploy_procs kullanılır.
static func deploy_procs_for(new_units: Array, all_units: Array, ctx: Dictionary) -> Array:
	var events: Array = []
	for unit: CombatUnit in _sorted_by_pos(new_units):
		for t: TraitData in unit.traits:
			if t.tetik == TraitData.Tetik.ON_DEPLOY:
				events.append({"t": "TRAIT_PROC", "unit_id": unit.uid, "trait_id": t.id, "ad": t.ad})
				if t.statu != &"":
					_apply_status(unit, t.statu, t.statu_deger, events)
	return events

# ------------------------------------------------------------- tur mekaniği

## HIZ azalan. Eşitlik: ZAR (gelistirme §6 — ctx'te seed'li rng varsa; savaş başına
## birim başı BİR kez atılır, tie_roll'da saklanır, SPEED_DICE event'i üretir).
## Zar da eşitse / rng yoksa: alt satır (küçük y), küçük kolon, uid (§3.3).
## Determinizm: rng savaş-sabit seed'le kurulur; rng verilmezse davranış eskisiyle birebir.
static func _activation_order(units: Array, ctx: Dictionary = {}, events: Array = []) -> Array:
	# Bayraklar sıraya girmez; BOSS bir bayraktır ama saldırır → istisna.
	var order := units.filter(func(u: CombatUnit) -> bool:
		return u.alive and (not u.is_flag or u.is_boss))
	var rng: RandomNumberGenerator = ctx.get("rng")
	if rng != null:
		_roll_speed_ties(order, rng, events)
	order.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		if a.spd != b.spd: return a.spd > b.spd
		if a.tie_roll != b.tie_roll: return a.tie_roll > b.tie_roll
		if a.coord.y != b.coord.y: return a.coord.y < b.coord.y
		if a.coord.x != b.coord.x: return a.coord.x < b.coord.x
		return a.uid < b.uid)
	return order

## Aynı HIZ'ı paylaşan ve henüz zarı olmayan birimlere d6 at. Kararlı sırayla
## (uid) atılır → seed sabitken sonuç sabit. Zar yalnız İLK eşitlikte atılır;
## sonraki turlarda aynı zar geçerli (MoP: kim önce vurur savaş boyu bellidir).
static func _roll_speed_ties(order: Array, rng: RandomNumberGenerator, events: Array) -> void:
	var by_spd := {}
	for u: CombatUnit in order:
		by_spd.get_or_add(u.spd, []).append(u)
	for spd in by_spd:
		var group: Array = by_spd[spd]
		if group.size() < 2:
			continue
		var fresh := group.filter(func(u: CombatUnit) -> bool: return u.tie_roll < 0)
		if fresh.is_empty():
			continue
		fresh.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool: return a.uid < b.uid)
		for u: CombatUnit in fresh:
			u.tie_roll = rng.randi_range(1, 6)
			events.append({"t": "SPEED_DICE", "unit_id": u.uid, "roll": u.tie_roll})

static func _deploy_procs(units: Array, ctx: Dictionary, events: Array) -> void:
	for unit: CombatUnit in _sorted_by_pos(units):
		for t: TraitData in unit.traits:
			if t.tetik == TraitData.Tetik.ON_DEPLOY:
				events.append({"t": "TRAIT_PROC", "unit_id": unit.uid, "trait_id": t.id, "ad": t.ad})
				if t.statu != &"":
					_apply_status(unit, t.statu, t.statu_deger, events)

## Tur başı efektleri (§3.3): zemin hasarı → DoT tick → statü süreleri → aura → birikimler → pus
static func _round_start_effects(units: Array, ctx: Dictionary, round_no: int, events: Array) -> void:
	# 0) Zemin hasarı: Lav üstünde duran tur başı 3 hasar (§7)
	for unit: CombatUnit in _sorted_by_pos(units):
		if unit.alive and not unit.is_flag and _terrain_at(ctx, unit.coord) == &"lav":
			events.append({"t": "STATUS_DAMAGE", "unit_id": unit.uid, "status": "lav", "damage": 3})
			_direct_damage(unit, 3, units, ctx, events)
	# 1) DoT: Zehir (X hasar, X→X−1) ve Yanık (sabit X, Y tur) — §6
	for unit: CombatUnit in _sorted_by_pos(units):
		# Bayrak DoT almaz; boss canlı bir yaratık → Zehir/Yanık ona da işler.
		if not unit.alive or (unit.is_flag and not unit.is_boss):
			continue
		if unit.zehir > 0:
			var z_dmg := unit.zehir
			unit.zehir -= 1
			events.append({"t": "STATUS_DAMAGE", "unit_id": unit.uid, "status": "zehir", "damage": z_dmg})
			events.append({"t": "STATUS", "target": unit.uid, "status": "zehir", "stacks": unit.zehir})
			_direct_damage(unit, z_dmg, units, ctx, events)
		if unit.alive and unit.yanik_sure > 0:
			unit.yanik_sure -= 1
			events.append({"t": "STATUS_DAMAGE", "unit_id": unit.uid, "status": "yanik", "damage": unit.yanik_hasar})
			events.append({"t": "STATUS", "target": unit.uid, "status": "yanik", "stacks": unit.yanik_sure})
			_direct_damage(unit, unit.yanik_hasar, units, ctx, events)
		# süre bazlı statüler erir
		if unit.alive and unit.kok > 0:
			unit.kok -= 1
			events.append({"t": "STATUS", "target": unit.uid, "status": "kok", "stacks": unit.kok})
		if unit.alive and unit.lanet_sure > 0:
			unit.lanet_sure -= 1
			events.append({"t": "STATUS", "target": unit.uid, "status": "lanet", "stacks": unit.lanet_sure})
	# 2) AURA tabyaları (Sargı): komşu dostları iyileştir
	for unit: CombatUnit in _sorted_by_pos(units):
		if not unit.alive:
			continue
		for t: TraitData in unit.traits:
			if t.tetik == TraitData.Tetik.AURA and t.heal > 0:
				_heal_neighbors(unit, t, units, events)
	# 3) ROUND_START tabyaları (Öfke): kalıcı birikimler
	for unit: CombatUnit in _sorted_by_pos(units):
		if not unit.alive:
			continue
		for t: TraitData in unit.traits:
			if t.tetik == TraitData.Tetik.ROUND_START:
				unit.kalici_ek_guc += t.kalici_ek_guc
				unit.kalici_kat += t.kalici_kat
				events.append({"t": "TRAIT_PROC", "unit_id": unit.uid, "trait_id": t.id, "ad": t.ad})
	# 4) Pus Basıncı (§3.7)
	_pus_pressure(units, ctx, round_no, events)

## Pus Basıncı: round >= 8'den itibaren HERKES (round-7)*2 HP kaybeder.
## Kalkan'ı BYPASS eder (basınç, vuruş değil) — sonsuz tank kırıcı.
static func _pus_pressure(units: Array, ctx: Dictionary, round_no: int, events: Array) -> void:
	if round_no < BoardDefs.SUDDEN_DEATH_ROUND:
		return
	var damage := (round_no - BoardDefs.SUDDEN_DEATH_ROUND + 1) * 2
	for unit: CombatUnit in _sorted_by_pos(units):
		if not unit.alive or unit.is_flag:
			continue
		unit.hp -= damage
		events.append({"t": "PUS_DAMAGE", "unit_id": unit.uid, "damage": damage})
		if unit.hp <= 0:
			_kill(unit, units, ctx, events)

# ------------------------------------------------------------- aktivasyon

static func _activate(unit: CombatUnit, units: Array, ctx: Dictionary, state: Dictionary, events: Array) -> void:
	if unit.sersem > 0:
		unit.sersem -= 1
		events.append({"t": "STUN_SKIP", "unit_id": unit.uid})
		events.append({"t": "STATUS", "target": unit.uid, "status": "sersem", "stacks": unit.sersem})
		return
	events.append({"t": "ACTIVATE", "unit_id": unit.uid})
	match unit.sinif:
		PieceData.Sinif.MELEE: _act_melee(unit, units, ctx, state, events)
		PieceData.Sinif.RANGED: _act_ranged(unit, units, ctx, events)
		PieceData.Sinif.SUPPORT: _act_support(unit, units, events)

## KISA MENZİL (§3.4): komşuda düşman varsa en zayıfına vur; yoksa ilerle
## (Kök varsa hareket edemez ama saldırabilir — §6).
static func _act_melee(unit: CombatUnit, units: Array, ctx: Dictionary, state: Dictionary, events: Array) -> void:
	var target := _pick_adjacent_target(unit, units)
	if target == null and unit.kok == 0:
		# Bayrak varsa düşman bayrağına doğru ilerle (lane-push §B.0/1);
		# yoksa eski davranış (en yakın düşmana).
		var goal_coord: Variant = null
		var flag := _enemy_flag(unit, units)
		if flag != null:
			goal_coord = flag.coord
		else:
			var nearest := _nearest_enemy(unit, units)
			if nearest != null:
				goal_coord = nearest.coord
		if goal_coord == null:
			return
		var step := _greedy_step(unit, goal_coord, units, ctx)
		if step != unit.coord:
			events.append({"t": "MOVE", "unit_id": unit.uid, "from": unit.coord, "to": step})
			unit.coord = step
			_check_diken(unit, units, ctx, state, events)
			if not unit.alive:
				return
		target = _pick_adjacent_target(unit, units)
	if target != null:
		_attack(unit, target, units, ctx, events)

## Diken (§7): üzerine İLK giren 2 hasar alır, diken tükenir.
static func _check_diken(unit: CombatUnit, units: Array, ctx: Dictionary, state: Dictionary, events: Array) -> void:
	if _terrain_at(ctx, unit.coord) != &"diken" or state["diken"].has(unit.coord):
		return
	state["diken"][unit.coord] = true
	events.append({"t": "TERRAIN", "terrain": "diken", "coord": unit.coord,
		"unit_id": unit.uid, "damage": 2})
	_direct_damage(unit, 2, units, ctx, events)

## UZAK MENZİL (§3.4): hareket etmez, en yakına vurur. line_only M1-C'de.
static func _act_ranged(unit: CombatUnit, units: Array, ctx: Dictionary, events: Array) -> void:
	var target := _nearest_enemy(unit, units)
	if target != null:
		_attack(unit, target, units, ctx, events)

## DESTEK (§3.4): saldırmaz; komşu yaralı dostları iyileştirir (sınıf davranışı;
## tabya iyileştirmeleri — Sargı — bundan AYRI, tur başında işler).
static func _act_support(unit: CombatUnit, units: Array, events: Array) -> void:
	for ally: CombatUnit in _sorted_by_pos(units):
		if not ally.alive or ally.side != unit.side or ally == unit:
			continue
		if BoardDefs.grid_distance(unit.coord, ally.coord) != 1:
			continue
		if ally.hp >= ally.max_hp:
			continue
		var amount := mini(SUPPORT_HEAL, ally.max_hp - ally.hp)
		ally.hp += amount
		events.append({"t": "HEAL", "src": unit.uid, "dst": ally.uid, "amount": amount})

# ------------------------------------------------------------- Güç×Kat hesabı

## Saldırı hasarı (§3.6) — dökümün `raw` alanı. Tek matematik kaynağı budur.
static func _compute_attack(src: CombatUnit, dst: CombatUnit, units: Array, ctx: Dictionary) -> int:
	return compute_breakdown(src, dst, units, ctx)["raw"]

## Canlı Güç×Kat dökümü (§3.6, §19 — build'i öğreten şey). Balatro çekirdeği:
## Güç = ATK + dış ek_guc + birikimler + koşullu tabyalar + zemin (toplamsal)
## Kat = dış kat × birikimler × koşullu tabyalar × etiket bağları × Lanet (çarpımsal)
##
## dst == null → hedefe-koşullu tabyalar (Nişan) uygulanmaz, "kosullu" listesine
## yazılır (deployment önizlemesi için). dst varsa davranış _attack ile birebir.
## Dönüş: {guc, kat, raw, guc_lines:[[ad,deger]], kat_lines:[[ad,carpan]], kosullu:[String]}
static func compute_breakdown(src: CombatUnit, dst: CombatUnit, units: Array, ctx: Dictionary) -> Dictionary:
	var guc := src.atk + src.ek_guc + src.kalici_ek_guc
	var kat := src.kat * src.kalici_kat
	var guc_lines: Array = [["Taban SALDIRI", src.atk]]
	var kat_lines: Array = []
	var kosullu: Array = []
	if src.ek_guc != 0: guc_lines.append(["Dış Güç", src.ek_guc])
	if src.kalici_ek_guc != 0: guc_lines.append(["Birikim (Güç)", src.kalici_ek_guc])
	if not is_equal_approx(src.kat, 1.0): kat_lines.append(["Dış Kat", src.kat])
	if not is_equal_approx(src.kalici_kat, 1.0): kat_lines.append(["Birikim (Kat)", src.kalici_kat])
	var heights: Dictionary = ctx.get("heights", {})
	for t: TraitData in src.traits:
		if t.tetik != TraitData.Tetik.PASSIVE:
			continue
		match t.kosul:
			TraitData.Kosul.YOK:
				guc += t.ek_guc
				kat *= t.kat
				if t.ek_guc != 0: guc_lines.append([t.ad, t.ek_guc])
				if not is_equal_approx(t.kat, 1.0): kat_lines.append([t.ad, t.kat])
			TraitData.Kosul.HEDEF_AYNI_SATIR_KOLON:
				if dst != null and (src.coord.x == dst.coord.x or src.coord.y == dst.coord.y):
					guc += t.ek_guc
					kat *= t.kat
					if t.ek_guc != 0: guc_lines.append([t.ad, t.ek_guc])
					if not is_equal_approx(t.kat, 1.0): kat_lines.append([t.ad, t.kat])
				else:
					kosullu.append("%s — aynı satır/kolonda hedefe" % t.ad)
			TraitData.Kosul.DIS_KOLON:
				if src.coord.x == 0 or src.coord.x == BoardDefs.COLS - 1:
					guc += t.ek_guc
					kat *= t.kat
					if t.ek_guc != 0: guc_lines.append([t.ad, t.ek_guc])
					if not is_equal_approx(t.kat, 1.0): kat_lines.append([t.ad, t.kat])
				else:
					kosullu.append("%s — en dış kolonda (A/F)" % t.ad)
			TraitData.Kosul.YUKSEK_ZEMIN:
				if heights.get(src.coord, 0) > 0:
					guc += t.ek_guc
					kat *= t.kat
					if t.ek_guc != 0: guc_lines.append([t.ad, t.ek_guc])
					if not is_equal_approx(t.kat, 1.0): kat_lines.append([t.ad, t.kat])
				else:
					kosullu.append("%s — yükselti zemininde" % t.ad)
			TraitData.Kosul.KOMSU_ETIKET_BASINA:
				var count := 0
				for ally: CombatUnit in units:
					if ally.alive and ally != src and ally.side == src.side \
							and t.kosul_etiket in ally.etiketler \
							and BoardDefs.grid_distance(src.coord, ally.coord) == 1:
						count += 1
				guc += t.ek_guc * count
				if count > 0:
					guc_lines.append(["%s (×%d)" % [t.ad, count], t.ek_guc * count])
				else:
					kosullu.append("%s — bitişik %s başına +%d" % [t.ad, t.kosul_etiket, t.ek_guc])
			TraitData.Kosul.SAHADA_ETIKET_MIN:
				pass   # global bağ: aşağıda taraf genelinde işlenir
	# Global etiket bağları (Kutsal Bağ): sahadaki HERHANGİ bir dost taşıyıcının
	# tabyası, koşul sağlanınca etiketli HERKESE işler — tabya id başına bir kez.
	var applied_bonds := {}
	for holder: CombatUnit in units:
		if not holder.alive or holder.side != src.side:
			continue
		for t: TraitData in holder.traits:
			if t.tetik != TraitData.Tetik.PASSIVE or t.kosul != TraitData.Kosul.SAHADA_ETIKET_MIN:
				continue
			if applied_bonds.has(t.id) or not (t.kosul_etiket in src.etiketler):
				continue
			var field_count := 0
			for u: CombatUnit in units:
				if u.alive and u.side == src.side and t.kosul_etiket in u.etiketler:
					field_count += 1
			applied_bonds[t.id] = true
			if field_count >= t.kosul_deger:
				guc += t.ek_guc
				kat *= t.kat
				if t.ek_guc != 0: guc_lines.append([t.ad, t.ek_guc])
				if not is_equal_approx(t.kat, 1.0): kat_lines.append([t.ad, t.kat])
			else:
				kosullu.append("%s — sahada %d+ %s (şu an %d)" % [t.ad, t.kosul_deger, t.kosul_etiket, field_count])
	# Zemin (§7): Yükselti +1 Güç; Kutsal Zemin +2 Güç; Pus Tile ×0.75 Kat
	if heights.get(src.coord, 0) > 0:
		guc += 1
		guc_lines.append(["Yükselti zemin", 1])
	match _terrain_at(ctx, src.coord):
		&"kutsal":
			guc += 2
			guc_lines.append(["Kutsal Zemin", 2])
		&"pus":
			kat *= 0.75
			kat_lines.append(["Pus Tile", 0.75])
	# Lanet: ×0.5 Kat (§6)
	if src.lanet_sure > 0:
		kat *= 0.5
		kat_lines.append(["Lanet", 0.5])
	# Relic global pasifleri — yalnız oyuncu tarafı (build motoru §B.9)
	if src.side == SIDE_PLAYER:
		for r: RelicData in ctx.get("relics", []):
			guc += r.global_ek_guc
			kat *= r.global_kat
			if r.global_ek_guc != 0: guc_lines.append([r.ad, r.global_ek_guc])
			if not is_equal_approx(r.global_kat, 1.0): kat_lines.append([r.ad, r.global_kat])
	return {"guc": guc, "kat": kat, "raw": int(floor(guc * kat)),
		"guc_lines": guc_lines, "kat_lines": kat_lines, "kosullu": kosullu}

static func _terrain_at(ctx: Dictionary, coord: Vector2i) -> StringName:
	return ctx.get("terrain", {}).get(coord, &"")

# ------------------------------------------------------------- saldırı & hasar

## Vuruş hattı (§3.4): hasar → on_hit tetikleri → ölümse on_kill/on_death
static func _attack(src: CombatUnit, dst: CombatUnit, units: Array, ctx: Dictionary, events: Array) -> void:
	# Tek döküm hesabı → hem hasar hem sunum (Güç×Kat ödemesi görünür olsun, §19/Balatro)
	var bd := compute_breakdown(src, dst, units, ctx)
	var raw: int = bd["raw"]
	var final := maxi(0, raw - dst.zirh)
	var absorbed := mini(final, dst.kalkan)
	dst.kalkan -= absorbed
	dst.hp -= final - absorbed
	events.append({"t": "ATTACK", "src": src.uid, "dst": dst.uid,
		"raw": raw, "final": final, "guc": bd["guc"], "kat": bd["kat"],
		"kat_lines": bd["kat_lines"], "crit": false})
	if absorbed > 0:
		events.append({"t": "STATUS", "target": dst.uid, "status": "kalkan", "stacks": dst.kalkan})
	src.vurus_sayaci += 1
	# BOSS Alev Nefesi: her vuruş hedefi tutuşturur (§6 Yanık — sabit hasar, 2 tur).
	# Tabya .tres'i yerine kural: boss PieceData'dan türemiyor, tabya taşımıyor.
	if src.is_boss and dst.hp > 0:
		_apply_status(dst, &"yanik", BOSS_YANIK_HASAR, events)
	# ON_HIT tabyaları (Kan Kaybı, Sarsıcı) — hedef ölmediyse
	if dst.hp > 0:
		for t: TraitData in src.traits:
			if t.tetik != TraitData.Tetik.ON_HIT:
				continue
			if t.kosul_deger > 1 and src.vurus_sayaci % t.kosul_deger != 0:
				continue   # "her N. vuruşta"
			events.append({"t": "TRAIT_PROC", "unit_id": src.uid, "trait_id": t.id, "ad": t.ad})
			if t.statu != &"":
				_apply_status(dst, t.statu, t.statu_deger, events)
	if dst.hp <= 0 and dst.alive:
		_kill(dst, units, ctx, events)
		# ON_KILL tabyaları (Kızıl Ziyafet): savaş boyu birikim
		for t: TraitData in src.traits:
			if t.tetik == TraitData.Tetik.ON_KILL:
				src.kalici_ek_guc += t.kalici_ek_guc
				src.kalici_kat += t.kalici_kat
				events.append({"t": "TRAIT_PROC", "unit_id": src.uid, "trait_id": t.id, "ad": t.ad})

## Vuruş olmayan hasar (DoT, Son Nefes): Zırh işlemez, Kalkan yine önce emer
static func _direct_damage(unit: CombatUnit, dmg: int, units: Array, ctx: Dictionary, events: Array) -> void:
	var absorbed := mini(dmg, unit.kalkan)
	unit.kalkan -= absorbed
	unit.hp -= dmg - absorbed
	if absorbed > 0:
		events.append({"t": "STATUS", "target": unit.uid, "status": "kalkan", "stacks": unit.kalkan})
	if unit.hp <= 0 and unit.alive:
		_kill(unit, units, ctx, events)

static func _kill(unit: CombatUnit, units: Array, ctx: Dictionary, events: Array) -> void:
	unit.alive = false
	events.append({"t": "DEATH", "unit_id": unit.uid})
	# ON_DEATH tabyaları (Son Nefes): komşu düşmanlara patlama — zincirleme olabilir
	for t: TraitData in unit.traits:
		if t.tetik != TraitData.Tetik.ON_DEATH or t.hasar_yuzde_can <= 0.0:
			continue
		events.append({"t": "TRAIT_PROC", "unit_id": unit.uid, "trait_id": t.id, "ad": t.ad})
		var dmg := int(floor(unit.max_hp * t.hasar_yuzde_can))
		for enemy: CombatUnit in _sorted_by_pos(units):
			if enemy.alive and enemy.side != unit.side \
					and BoardDefs.grid_distance(unit.coord, enemy.coord) == 1:
				events.append({"t": "STATUS_DAMAGE", "unit_id": enemy.uid, "status": "patlama", "damage": dmg})
				_direct_damage(enemy, dmg, units, ctx, events)

# ------------------------------------------------------------- statü & iyileştirme

## Statü uygula (§6 stack kuralları). Event stacks = yeni toplam.
static func _apply_status(unit: CombatUnit, statu: StringName, deger: int, events: Array) -> void:
	var stacks := 0
	match statu:
		&"zehir":
			unit.zehir += deger
			stacks = unit.zehir
		&"yanik":
			unit.yanik_hasar = maxi(unit.yanik_hasar, deger)
			unit.yanik_sure = maxi(unit.yanik_sure, 2)   # süre yenilenir, hasar toplanmaz
			stacks = unit.yanik_sure
		&"sersem":
			unit.sersem += deger
			stacks = unit.sersem
		&"kok":
			unit.kok += deger
			stacks = unit.kok
		&"kalkan":
			unit.kalkan += unit.hp if deger == 0 else deger   # 0 = "CAN kadar"
			stacks = unit.kalkan
		&"lanet":
			unit.lanet_sure = maxi(unit.lanet_sure, deger)    # toplanmaz, yenilenir
			stacks = unit.lanet_sure
		&"zirh":
			unit.zirh += deger
			stacks = unit.zirh
	events.append({"t": "STATUS", "target": unit.uid, "status": String(statu), "stacks": stacks})

static func _heal_neighbors(unit: CombatUnit, t: TraitData, units: Array, events: Array) -> void:
	for ally: CombatUnit in _sorted_by_pos(units):
		if not ally.alive or ally.side != unit.side or ally == unit:
			continue
		if BoardDefs.grid_distance(unit.coord, ally.coord) != 1 or ally.hp >= ally.max_hp:
			continue
		var amount := mini(t.heal, ally.max_hp - ally.hp)
		ally.hp += amount
		events.append({"t": "HEAL", "src": unit.uid, "dst": ally.uid, "amount": amount})

# ------------------------------------------------------------- hedefleme

## Komşu (Chebyshev=1) düşmanlardan en zayıf: min HP, tie: küçük y, x, uid
static func _pick_adjacent_target(unit: CombatUnit, units: Array) -> CombatUnit:
	var best: CombatUnit = null
	for enemy: CombatUnit in units:
		if not enemy.alive or enemy.side == unit.side:
			continue
		if BoardDefs.grid_distance(unit.coord, enemy.coord) != 1:
			continue
		if best == null or _weaker(enemy, best):
			best = enemy
	return best

static func _weaker(a: CombatUnit, b: CombatUnit) -> bool:
	if a.hp != b.hp: return a.hp < b.hp
	if a.coord.y != b.coord.y: return a.coord.y < b.coord.y
	if a.coord.x != b.coord.x: return a.coord.x < b.coord.x
	return a.uid < b.uid

## En yakın düşman: min mesafe, tie: küçük y, x, uid
static func _nearest_enemy(unit: CombatUnit, units: Array) -> CombatUnit:
	var best: CombatUnit = null
	var best_d := 999
	for enemy: CombatUnit in units:
		if not enemy.alive or enemy.side == unit.side:
			continue
		var d := BoardDefs.grid_distance(unit.coord, enemy.coord)
		if d < best_d or (d == best_d and _weaker(enemy, best)):
			best = enemy
			best_d = d
	return best

## Greedy adım: mesafeyi KISALTAN, boş ve sınır içi komşulardan ilki (DIRS8 sırası).
## Duvar tile'ları geçilmez (§7) — greedy doğal olarak etrafından dolanır.
static func _greedy_step(unit: CombatUnit, target: Vector2i, units: Array, ctx: Dictionary) -> Vector2i:
	var occupied := {}
	for u: CombatUnit in units:
		if u.alive and u != unit:
			occupied[u.coord] = true
	var best := unit.coord
	var best_d := BoardDefs.grid_distance(unit.coord, target)
	for dir in DIRS8:
		var next: Vector2i = unit.coord + dir
		if not BoardDefs.in_bounds(next) or occupied.has(next):
			continue
		if _terrain_at(ctx, next) == &"duvar":
			continue
		var d := BoardDefs.grid_distance(next, target)
		if d < best_d:
			best = next
			best_d = d
	return best

# ------------------------------------------------------------- durum sorguları

static func _side_alive(units: Array, side: int) -> bool:
	for u: CombatUnit in units:
		if u.alive and u.side == side:
			return true
	return false

## Tarafın SAVAŞAN birimi kaldı mı? Düz bayrak sayılmaz (savaşamaz); BOSS
## savaşır → sayılır (ejderha canlıyken düşman "tükenmiş" olmaz).
static func _side_pieces_alive(units: Array, side: int) -> bool:
	for u: CombatUnit in units:
		if u.alive and u.side == side and (not u.is_flag or u.is_boss):
			return true
	return false

## Bayrak varsa: bir bayrak düştü VEYA bir taraf tükendi (simetrik piece-out,
## gelistirme.md §13 — MoP'un tek taraflı kuralının düzeltmesi). Oyuncu için
## "tükendi" = sahada birim yok VE dizilecek yedek yok (player_reserves).
## Bayrak yoksa (saf birim testleri): eski "bir taraf yok oldu" mantığı.
static func _battle_over(units: Array, player_reserves: int = 0) -> bool:
	if _has_flags(units):
		if not (_flag_alive(units, SIDE_PLAYER) and _flag_alive(units, SIDE_ENEMY)):
			return true
		if not _side_pieces_alive(units, SIDE_ENEMY):
			return true
		return not _side_pieces_alive(units, SIDE_PLAYER) and player_reserves <= 0
	return not (_side_alive(units, SIDE_PLAYER) and _side_alive(units, SIDE_ENEMY))

## Kazanan. Bayraklıysa öncelik sırası: bayrak düşüşü → piece-out (ordusu
## tükenen kaybeder — iki zafer yolu: orduyu yok et VEYA bayrağı yık) →
## MAX_ROUND/çifte tükenmede bayrağı daha çok yıpranan kaybeder, eşitlik
## OYUNCU ALEYHİNE (kaybetmek ilerlemedir, §1.5).
static func _decide_winner(units: Array, player_reserves: int = 0) -> String:
	if _has_flags(units):
		var p := _flag_alive(units, SIDE_PLAYER)
		var e := _flag_alive(units, SIDE_ENEMY)
		if p and not e:
			return "PLAYER"
		if e and not p:
			return "ENEMY"
		if not p and not e:
			return "ENEMY"
		# İki bayrak da ayakta → piece-out kararı
		var p_pieces := _side_pieces_alive(units, SIDE_PLAYER) or player_reserves > 0
		var e_pieces := _side_pieces_alive(units, SIDE_ENEMY)
		if p_pieces and not e_pieces:
			return "PLAYER"
		if e_pieces and not p_pieces:
			return "ENEMY"
		var pf := _flag_of(units, SIDE_PLAYER)
		var ef := _flag_of(units, SIDE_ENEMY)
		return "PLAYER" if ef.hp < pf.hp else "ENEMY"
	var p_alive := _side_alive(units, SIDE_PLAYER)
	var e_alive := _side_alive(units, SIDE_ENEMY)
	if p_alive and not e_alive:
		return "PLAYER"
	if e_alive and not p_alive:
		return "ENEMY"
	if not p_alive and not e_alive:
		return "ENEMY"
	var p_hp := 0
	var e_hp := 0
	for u: CombatUnit in units:
		if u.alive:
			if u.side == SIDE_PLAYER: p_hp += u.hp
			else: e_hp += u.hp
	return "PLAYER" if p_hp > e_hp else "ENEMY"

# ------------------------------------------------------------- public durum

## Savaş bitti mi (tur-tur mod battle_screen bunu her tur çağırır).
## player_reserves: oyuncunun henüz dizilmemiş kadro üyesi sayısı (piece-out §13).
static func is_over(units: Array, player_reserves: int = 0) -> bool:
	return _battle_over(units, player_reserves)

## Kazanan ("PLAYER"/"ENEMY")
static func winner(units: Array, player_reserves: int = 0) -> String:
	return _decide_winner(units, player_reserves)

# ------------------------------------------------------------- bayrak yardımcıları

static func _has_flags(units: Array) -> bool:
	for u: CombatUnit in units:
		if u.is_flag:
			return true
	return false

static func _flag_alive(units: Array, side: int) -> bool:
	for u: CombatUnit in units:
		if u.is_flag and u.side == side and u.alive:
			return true
	return false

static func _flag_of(units: Array, side: int) -> CombatUnit:
	for u: CombatUnit in units:
		if u.is_flag and u.side == side:
			return u
	return null

## Birimin karşı tarafındaki (canlı) bayrak
static func _enemy_flag(unit: CombatUnit, units: Array) -> CombatUnit:
	for u: CombatUnit in units:
		if u.is_flag and u.alive and u.side != unit.side:
			return u
	return null

## Konuma göre deterministik sıralama (y, x, uid) — toplu efektler için
static func _sorted_by_pos(units: Array) -> Array:
	var arr := units.duplicate()
	arr.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		if a.coord.y != b.coord.y: return a.coord.y < b.coord.y
		if a.coord.x != b.coord.x: return a.coord.x < b.coord.x
		return a.uid < b.uid)
	return arr
