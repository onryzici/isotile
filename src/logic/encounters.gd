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
}

## Bölge haritası şablonu (§2): alttan üste katmanlar; katmandaki
## düğümlerden biri seçilir. Gerçek KARABASAN boss'u M3'te.
const MAP_TEMPLATE := [
	[{"type": &"savas", "enc": &"kolay", "ad": "Savaş"}],
	[{"type": &"savas", "enc": &"orta", "ad": "Savaş"}, {"type": &"dukkan", "ad": "Dükkan"}],
	[{"type": &"olay", "ad": "Olay"}, {"type": &"savas", "enc": &"orta2", "ad": "Savaş"}],
	[{"type": &"elit", "enc": &"elit", "ad": "ELİT"}],
	[{"type": &"dukkan", "ad": "Dükkan"}],
	[{"type": &"boss", "enc": &"boss", "ad": "BOSS"}],
]

static func get_def(id: StringName) -> Dictionary:
	return DEFS.get(id, DEFS[&"orta"])
