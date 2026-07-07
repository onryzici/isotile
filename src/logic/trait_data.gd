class_name TraitData
extends Resource
## Tabya veri modeli (CLAUDE.md §5.2) — sinerji motorunun yakıtı.
## Tabya = Güç (toplamsal), Kat (çarpımsal) ve tetikler. Yeni tabya = yeni .tres.
##
## Alan kullanım sözleşmeleri:
##  - kat = 1.0 → etkisiz (çarpan). kalici_kat = 0.0 → etkisiz (Kat'a EKLENİR).
##  - statu == "kalkan" ve statu_deger == 0 → "mevcut CAN kadar" (Kalkan Duruşu).
##  - kosul_deger: SAHADA_ETIKET_MIN'de eşik N; ON_HIT'te "her N. vuruşta" (0 = her vuruş).

enum Tetik { PASSIVE, ON_HIT, ON_KILL, ON_DEATH, ON_DEPLOY, ROUND_START, AURA }
enum Kosul {
	YOK,
	HEDEF_AYNI_SATIR_KOLON,   # Nişan
	DIS_KOLON,                # Kanat (kolon A veya F)
	YUKSEK_ZEMIN,             # Yükselti tile'ında
	KOMSU_ETIKET_BASINA,      # Sürü Lideri (komşu etiketli dost başına ek_guc)
	SAHADA_ETIKET_MIN,        # Kutsal Bağ (sahada N+ etiketli → etiketlilerin hepsine)
}
enum Hedef { KENDI, VURULAN, KOMSU_DOSTLAR, KOMSU_DUSMANLAR }

@export var id: StringName
@export var ad: String = ""
@export_multiline var aciklama: String = ""
@export var tetik: Tetik = Tetik.PASSIVE
@export var kosul: Kosul = Kosul.YOK
@export var kosul_etiket: StringName = &""
@export var kosul_deger: int = 0

# Güç×Kat katkıları (§3.6)
@export var ek_guc: int = 0          # toplamsal; KOMSU_ETIKET_BASINA'da "başına"
@export var kat: float = 1.0         # çarpımsal
@export var kalici_ek_guc: int = 0   # ROUND_START/ON_KILL: savaş boyu biriken Güç
@export var kalici_kat: float = 0.0  # ON_KILL: savaş boyu Kat'a eklenen (+0.2 gibi)

# Statü / iyileştirme / patlama etkileri
@export var statu: StringName = &""  # zehir|yanik|sersem|kok|kalkan|lanet|zirh
@export var statu_deger: int = 0
@export var heal: int = 0                     # AURA: tur başı iyileştirme
@export var hasar_yuzde_can: float = 0.0      # ON_DEATH: max CAN oranı hasar
@export var hedef: Hedef = Hedef.KENDI
