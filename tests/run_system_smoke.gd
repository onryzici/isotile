extends SceneTree
func _init() -> void:
	var fails := 0
	var p := PieceData.new(); p.saldiri = 3; p.can = 10; p.hiz = 5
	var hero := CombatUnit.from_piece(p, CombatResolver.SIDE_PLAYER, Vector2i(0,0), 1)
	var e := PieceData.new(); e.can = 10
	var dummy := CombatUnit.from_piece(e, CombatResolver.SIDE_ENEMY, Vector2i(0,1), 2)
	var base: int = CombatResolver._compute_attack(hero, dummy, [hero,dummy], {})
	var rel := RelicData.new(); rel.global_ek_guc = 2; rel.global_kat = 1.5
	var boosted: int = CombatResolver._compute_attack(hero, dummy, [hero,dummy], {"relics":[rel]})
	print("relic hook: base=%d (bekle 3), boosted=%d (bekle 7)" % [base, boosted])
	if base != 3: fails += 1
	if boosted != 7: fails += 1
	# düşman tarafı relic'ten etkilenmemeli
	var e_dmg: int = CombatResolver._compute_attack(dummy, hero, [hero,dummy], {"relics":[rel]})
	if e_dmg != CombatResolver._compute_attack(dummy, hero, [hero,dummy], {}): fails += 1; print("  [FAIL] relic düşmana da işledi")
	# item = tek savaşlık relic (ItemData extends RelicData): resolver aynı kancayı okur
	var it := ItemData.new(); it.tur = ItemData.Tur.SONRAKI_SAVAS
	it.global_ek_guc = 2; it.global_kat = 1.5
	var item_boost: int = CombatResolver._compute_attack(hero, dummy, [hero,dummy], {"relics":[it]})
	if item_boost != boosted: fails += 1; print("  [FAIL] item relic kancasından işlemedi (%d != %d)" % [item_boost, boosted])
	print("=== RELIC HOOK + ITEM %s ===" % ("GEÇTİ" if fails==0 else "HATA"))
	quit(1 if fails else 0)
