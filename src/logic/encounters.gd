class_name Encounters
extends RefCounted
## SAF VERİ — savaş düğümü tanımları (M2). Elle tasarlı şablonlar (§23:
## prosedürel üretim YOK). M4'te EncounterData .tres'e taşınabilir; şimdilik
## tek bölge, kod-veri yeterli.
## Şema: {enemies: {Vector2i: piece_id}, terrain: {Vector2i: tip},
##        heights: {Vector2i: int}, gold: int}

const DEFS := {
	&"kolay": {
		"enemies": {Vector2i(1, 3): &"pus_yuruyucu", Vector2i(3, 3): &"pus_yuruyucu",
			Vector2i(2, 4): &"pus_yuruyucu"},
		"terrain": {Vector2i(2, 2): &"diken", Vector2i(4, 1): &"kutsal"},
		"heights": {Vector2i(3, 2): 1},
		"gold": 15,
	},
	&"orta": {
		"enemies": {Vector2i(1, 3): &"pus_yuruyucu", Vector2i(4, 3): &"pus_yuruyucu",
			Vector2i(2, 3): &"zirhli", Vector2i(3, 4): &"nisanci"},
		"terrain": {Vector2i(0, 2): &"duvar", Vector2i(2, 2): &"lav",
			Vector2i(3, 2): &"diken", Vector2i(5, 2): &"pus", Vector2i(1, 1): &"kutsal"},
		"heights": {Vector2i(1, 3): 1, Vector2i(4, 2): 1},
		"gold": 20,
	},
	&"orta2": {
		"enemies": {Vector2i(0, 3): &"nisanci", Vector2i(5, 3): &"nisanci",
			Vector2i(2, 3): &"pus_yuruyucu", Vector2i(3, 3): &"pus_yuruyucu"},
		"terrain": {Vector2i(1, 2): &"lav", Vector2i(4, 2): &"lav",
			Vector2i(2, 2): &"duvar", Vector2i(3, 2): &"duvar", Vector2i(2, 1): &"kutsal"},
		"heights": {Vector2i(0, 2): 1, Vector2i(5, 2): 1},
		"gold": 20,
	},
	&"elit": {
		"enemies": {Vector2i(1, 3): &"zirhli", Vector2i(4, 3): &"zirhli",
			Vector2i(2, 4): &"nisanci", Vector2i(3, 4): &"nisanci",
			Vector2i(2, 3): &"pus_yuruyucu"},
		"terrain": {Vector2i(0, 2): &"diken", Vector2i(5, 2): &"diken",
			Vector2i(2, 2): &"pus", Vector2i(3, 2): &"pus"},
		"heights": {Vector2i(2, 3): 1, Vector2i(3, 3): 1},
		"gold": 40,
	},
	&"boss": {
		"enemies": {Vector2i(2, 3): &"zirhli", Vector2i(3, 3): &"zirhli",
			Vector2i(1, 4): &"nisanci", Vector2i(4, 4): &"nisanci",
			Vector2i(0, 3): &"pus_yuruyucu", Vector2i(5, 3): &"pus_yuruyucu",
			Vector2i(2, 4): &"pus_yuruyucu"},
		"terrain": {Vector2i(1, 2): &"pus", Vector2i(4, 2): &"pus",
			Vector2i(2, 2): &"lav", Vector2i(3, 2): &"lav"},
		"heights": {},
		"gold": 60,
	},
	# 2. bölge — yeni düşman havuzu
	&"orta3": {
		"enemies": {Vector2i(0, 3): &"golge_okcu", Vector2i(5, 3): &"golge_okcu",
			Vector2i(2, 3): &"lanetli_sovalye", Vector2i(3, 4): &"kemik_cigligi"},
		"terrain": {Vector2i(2, 2): &"lav", Vector2i(3, 2): &"pus", Vector2i(0, 1): &"kutsal"},
		"heights": {Vector2i(2, 3): 1},
		"gold": 24,
	},
	&"elit2": {
		"enemies": {Vector2i(1, 3): &"pus_devi", Vector2i(4, 3): &"pus_devi",
			Vector2i(2, 4): &"golge_okcu", Vector2i(3, 4): &"golge_okcu",
			Vector2i(2, 3): &"kemik_cigligi"},
		"terrain": {Vector2i(0, 2): &"diken", Vector2i(5, 2): &"diken",
			Vector2i(2, 2): &"pus", Vector2i(3, 2): &"pus"},
		"heights": {Vector2i(2, 3): 1, Vector2i(3, 3): 1},
		"gold": 45,
	},
	&"boss2": {
		"enemies": {Vector2i(2, 3): &"pus_devi", Vector2i(3, 3): &"lanetli_sovalye",
			Vector2i(1, 4): &"golge_okcu", Vector2i(4, 4): &"golge_okcu",
			Vector2i(0, 3): &"kemik_cigligi", Vector2i(5, 3): &"kemik_cigligi",
			Vector2i(2, 4): &"lanetli_sovalye"},
		"terrain": {Vector2i(1, 2): &"lav", Vector2i(4, 2): &"lav",
			Vector2i(2, 2): &"pus", Vector2i(3, 2): &"pus", Vector2i(2, 1): &"kutsal"},
		"heights": {Vector2i(2, 4): 1, Vector2i(3, 4): 1},
		"gold": 75,
	},
	# 3. bölge — Kurt İni: tarikat havuzu (kurt sürüsü + şifacı rahipler)
	&"orta4": {
		"enemies": {Vector2i(1, 3): &"kurt_muridi", Vector2i(4, 3): &"kurt_muridi",
			Vector2i(0, 4): &"golge_okcu", Vector2i(3, 4): &"tarikat_rahibi"},
		"terrain": {Vector2i(2, 2): &"pus", Vector2i(3, 2): &"lav", Vector2i(5, 1): &"kutsal"},
		"heights": {Vector2i(4, 3): 1},
		"gold": 28,
	},
	&"orta5": {
		"enemies": {Vector2i(2, 3): &"kadim_kurt", Vector2i(0, 3): &"kurt_muridi",
			Vector2i(5, 3): &"kurt_muridi", Vector2i(3, 4): &"tarikat_rahibi"},
		"terrain": {Vector2i(1, 2): &"diken", Vector2i(4, 2): &"diken",
			Vector2i(2, 2): &"pus", Vector2i(3, 2): &"pus"},
		"heights": {Vector2i(2, 3): 1},
		"gold": 30,
	},
	&"elit3": {
		"enemies": {Vector2i(1, 3): &"kadim_kurt", Vector2i(4, 3): &"kadim_kurt",
			Vector2i(2, 4): &"tarikat_rahibi", Vector2i(3, 4): &"tarikat_rahibi",
			Vector2i(2, 3): &"golge_okcu"},
		"terrain": {Vector2i(0, 2): &"lav", Vector2i(5, 2): &"lav",
			Vector2i(2, 2): &"pus", Vector2i(3, 2): &"pus"},
		"heights": {Vector2i(1, 3): 1, Vector2i(4, 3): 1},
		"gold": 55,
	},
	&"boss3": {
		"enemies": {Vector2i(2, 3): &"kadim_kurt", Vector2i(3, 3): &"lanetli_sovalye",
			Vector2i(0, 3): &"kurt_muridi", Vector2i(5, 3): &"kurt_muridi",
			Vector2i(1, 4): &"tarikat_rahibi", Vector2i(4, 4): &"tarikat_rahibi",
			Vector2i(2, 4): &"golge_okcu"},
		"terrain": {Vector2i(1, 2): &"lav", Vector2i(4, 2): &"lav",
			Vector2i(2, 2): &"pus", Vector2i(3, 2): &"pus",
			Vector2i(0, 1): &"kutsal", Vector2i(5, 1): &"kutsal"},
		"heights": {Vector2i(2, 4): 1, Vector2i(3, 4): 1},
		"gold": 90,
	},
}

## Bölge sınırları: katman → bölge index'i (harita adı + ileride bioma seçimi)
const REGION_STARTS := [0, 6, 10]

static func region_of(layer: int) -> int:
	var r := 0
	for i in REGION_STARTS.size():
		if layer >= REGION_STARTS[i]:
			r = i
	return r

## Bölge haritası şablonu (§2): alttan üste katmanlar; katmandaki
## düğümlerden biri seçilir. Gerçek KARABASAN boss'u M3'te.
const MAP_TEMPLATE := [
	[{"type": &"savas", "enc": &"kolay", "ad": "Savaş"}],
	[{"type": &"savas", "enc": &"orta", "ad": "Savaş"}, {"type": &"dukkan", "ad": "Dükkan"},
		{"type": &"nitelik", "ad": "Nitelik Dükkanı"}],
	[{"type": &"olay", "ad": "Olay"}, {"type": &"savas", "enc": &"orta2", "ad": "Savaş"},
		{"type": &"saman", "ad": "Şaman Çadırı"}],
	[{"type": &"elit", "enc": &"elit", "ad": "ELİT"}, {"type": &"mezar", "ad": "Gri Mezar"},
		{"type": &"yadigar", "ad": "Yadigar Dükkanı"}],
	[{"type": &"dukkan", "ad": "Dükkan"}, {"type": &"revir", "ad": "Sahra Revan"},
		{"type": &"kitapci", "ad": "Kitapçı"}],
	[{"type": &"boss", "enc": &"boss", "ad": "BOSS"}],
	# 2. bölge — Kemik Bataklığı
	[{"type": &"savas", "enc": &"orta3", "ad": "Savaş"}, {"type": &"dukkan", "ad": "Dükkan"},
		{"type": &"meydan", "ad": "Meydan"}],
	[{"type": &"olay", "ad": "Olay"}, {"type": &"elit", "enc": &"elit2", "ad": "ELİT"},
		{"type": &"mezar", "ad": "Gri Mezar"}],
	[{"type": &"revir", "ad": "Sahra Revan"}, {"type": &"kitapci", "ad": "Kitapçı"},
		{"type": &"daragaci", "ad": "Darağacı"}],
	[{"type": &"boss", "enc": &"boss2", "ad": "BOSS"}],
	# 3. bölge — Kurt İni
	[{"type": &"savas", "enc": &"orta4", "ad": "Savaş"}, {"type": &"dukkan", "ad": "Dükkan"},
		{"type": &"nitelik", "ad": "Nitelik Dükkanı"}],
	[{"type": &"olay", "ad": "Olay"}, {"type": &"savas", "enc": &"orta5", "ad": "Savaş"},
		{"type": &"meydan", "ad": "Meydan"}],
	[{"type": &"elit", "enc": &"elit3", "ad": "ELİT"}, {"type": &"mezar", "ad": "Gri Mezar"},
		{"type": &"yadigar", "ad": "Yadigar Dükkanı"}],
	[{"type": &"revir", "ad": "Sahra Revan"}, {"type": &"saman", "ad": "Şaman Çadırı"},
		{"type": &"kitapci", "ad": "Kitapçı"}],
	[{"type": &"boss", "enc": &"boss3", "ad": "BOSS"}],
]

## Düşman bayrağı CAN'ı (§B.0/1) — zorlukla ölçeklenir
## Boss düğümlerinde bu CAN bayrağa değil EJDERHA'ya aittir (battle_screen._make_enemy_anchor);
## ejderha saldırdığı ve tutuşturduğu için bandı belirgin şekilde yüksek.
const FLAG_HP := {
	&"kolay": 16, &"orta": 20, &"orta2": 22, &"elit": 30, &"boss": 70,
	&"orta3": 26, &"elit2": 34, &"boss2": 95,
	&"orta4": 30, &"orta5": 32, &"elit3": 40, &"boss3": 125,
}

static func get_def(id: StringName) -> Dictionary:
	return DEFS.get(id, DEFS[&"orta"])

static func flag_hp(id: StringName) -> int:
	return FLAG_HP.get(id, 20)
