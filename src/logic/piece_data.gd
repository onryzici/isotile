class_name PieceData
extends Resource
## Birim veri modeli (CLAUDE.md §4.1). Veri = Resource; kod jenerik motor (§17.3).

enum Sinif { MELEE, RANGED, SUPPORT }

@export var id: StringName
@export var ad: String = ""
@export var sinif: Sinif = Sinif.MELEE
@export var saldiri: int = 1
@export var can: int = 5
@export var hiz: int = 3
@export var zirh: int = 0             # flat hasar azaltma (Zırhlı arketipi §11.1)
@export var mevzi_maliyeti: int = 1   # 1-4 AP
@export var tabya_slotu: int = 2
@export var base_traits: Array = []   # TraitData listesi (doğuştan, 0-2)
@export var etiketler: Array[StringName] = []   # sinerji tag'leri
@export var tier: int = 1
@export var mesh_id: StringName = &""           # dummy: renkli kapsül
@export var starter: bool = true                # false = recruit havuzu (ödül/dükkan)
@export var fiyat: int = 8                       # dükkanda satın alma bedeli
@export var upgrades: int = 0                    # Şaman Çadırı yükseltme sayısı (en çok 2, gelistirme §9)
@export var rumor: TraitData = null              # Söylenti (§14): birim başına 1 zayıf pasif (Meydan verir)

func trait_names() -> String:
	var names: Array[String] = []
	for t in base_traits:
		names.append(t.ad)
	return ", ".join(names)

func stat_text() -> String:
	return "%d/%d/%d" % [saldiri, can, hiz]

func class_key() -> StringName:
	return [&"MELEE", &"RANGED", &"SUPPORT"][sinif]
