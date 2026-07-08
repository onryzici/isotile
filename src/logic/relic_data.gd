class_name RelicData
extends Resource
## Relic (yadigar) — run boyu global pasif (gelistirme B.3/B.9). Data-driven.
## Kumandan + trait + relic üçlüsü build motorunu besler. Etkiler oyuncu
## tarafının Güç×Kat'ına ve savaş ekonomisine işler (CombatResolver + battle_screen).

@export var id: StringName
@export var ad: String = ""
@export_multiline var aciklama: String = ""
@export var fiyat: int = 12

# Global savaş etkileri (oyuncu birimlerine)
@export var global_ek_guc: int = 0        # tüm oyuncu birimlerine +Güç
@export var global_kat: float = 1.0       # tüm oyuncu birimlerine ×Kat
@export var baslangic_kalkan: int = 0     # savaş başı tüm oyuncu birimlerine Kalkan

# Ekonomi etkileri (battle_screen / run)
@export var mevzi_bonus: int = 0          # tur başı ekstra AP
@export var altin_bonus: int = 0          # zafer başına ekstra altın
