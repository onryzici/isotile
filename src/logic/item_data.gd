class_name ItemData
extends RelicData
## Item — tek kullanımlık eşya (gelistirme §5 Kitapçı/Ozan, §18 ~8 item).
## İki tür:
##   ANINDA        → haritada kullan, etki hemen işler (bölük CAN / sancak / zar).
##   SONRAKI_SAVAS → kuşanılır; miras alınan relic alanları (global_ek_guc,
##                   global_kat, baslangic_kalkan, mevzi_bonus) yalnız bir
##                   sonraki savaşta işler, savaş bitince tükenir.
## RelicData'dan türediği için resolver/battle_screen relic kancaları değişmeden
## çalışır — armed item = tek savaşlık relic.

enum Tur { ANINDA, SONRAKI_SAVAS }

@export var tur: Tur = Tur.ANINDA

# ANINDA etkileri
@export var heal_suru := false      # bölük tam CAN'a gelir
@export var bayrak_onar: int = 0    # sancak +X (cap'e kadar)
@export var zar_ver: int = 0        # +X sefer zarı
