class_name CombatUnit
extends RefCounted
## SAF MANTIK — savaş içi birim durumu. PieceData'dan (kalıcı veri) türetilir,
## savaş boyunca mutasyona uğrar (CLAUDE.md §3.5-3.6).

var uid: int                 # savaş içi benzersiz kimlik (event'ler bunu referanslar)
var piece_id: StringName
var ad: String
var side: int                # CombatResolver.SIDE_PLAYER / SIDE_ENEMY
var sinif: int               # PieceData.Sinif
var coord: Vector2i
var atk: int
var hp: int
var max_hp: int
var spd: int

# Güç×Kat kancaları (§3.6) — dış kaynaklar (relic/emir M2+) bunları besler
var ek_guc: int = 0          # toplamsal +ATK (chips)
var kat: float = 1.0         # çarpımsal × (mult)
var zirh: int = 0            # flat hasar azaltma
var kalkan: int = 0          # CAN'dan önce tüketilen geçici HP

# Tabyalar (§5) ve savaş boyu birikimler
var traits: Array = []           # TraitData
var etiketler: Array = []        # sinerji tag'leri
var kalici_ek_guc: int = 0       # Öfke vb. birikimi
var kalici_kat: float = 1.0      # Kızıl Ziyafet vb. (1.0'dan büyür)
var vurus_sayaci: int = 0        # Sarsıcı ("her N. vuruşta")

# Statü sayaçları (§6)
var zehir: int = 0               # tur başı X hasar, sonra X−1
var yanik_hasar: int = 0         # tur başı sabit hasar
var yanik_sure: int = 0
var sersem: int = 0              # aktivasyon atlar
var kok: int = 0                 # hareket edemez
var lanet_sure: int = 0          # ×0.5 Kat

var alive := true
var is_flag := false          # bayrak/kamp birimi (§B.0/1): hareketsiz hedef, CAN'lı

## Bayrak birimi (gelistirme B.0/1): ızgaranın karşı ucunda, CAN'lı, hareketsiz.
## Zafer = düşman bayrağını yıkmak. Oyuncu bayrağı CAN'ı run boyu KALICI (§B.0/2).
static func make_flag(side_: int, coord_: Vector2i, hp_: int, uid_: int, ad_: String = "Bayrak") -> CombatUnit:
	var u := CombatUnit.new()
	u.uid = uid_
	u.piece_id = &"__flag"
	u.ad = ad_
	u.side = side_
	u.sinif = PieceData.Sinif.MELEE
	u.coord = coord_
	u.atk = 0
	u.hp = hp_
	u.max_hp = hp_
	u.spd = -1                # aktivasyon sırasına girmez
	u.is_flag = true
	return u

static func from_piece(piece: PieceData, side_: int, coord_: Vector2i, uid_: int) -> CombatUnit:
	var u := CombatUnit.new()
	u.uid = uid_
	u.piece_id = piece.id
	u.ad = piece.ad
	u.side = side_
	u.sinif = piece.sinif
	u.coord = coord_
	u.atk = piece.saldiri
	u.hp = piece.can
	u.max_hp = piece.can
	u.spd = piece.hiz
	u.zirh = piece.zirh
	u.traits = piece.base_traits.duplicate()
	u.etiketler = piece.etiketler.duplicate()
	return u

func stat_text() -> String:
	return "%d/%d/%d" % [atk, hp, spd]
