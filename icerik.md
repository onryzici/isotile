# PUS — İçerik Referansı

> **Amaç:** İçerik (relic / tabya / olay / ekonomi) ayarlarken tek bakılacak yer.
> **Kural:** Bu dosya **kodun gerçekte ne yaptığını** anlatır, `CLAUDE.md`'nin ne vaat ettiğini değil.
> Bir satır burada yazıyorsa oyunda çalışıyordur. Çalışmayanlar §7'de listeli.
>
> Son güncelleme: 2026-07-10. Kod değişince burayı da güncelle.

---

## 1. YADİGARLAR (Relics) — 10 adet, hepsi çalışıyor

**Veri:** `data/relics/*.tres` · **Model:** `src/logic/relic_data.gd`

Bir relic yalnız şu 5 alandan birini (veya birkaçını) doldurabilir. Kod başka bir şey okumuyor —
yeni bir efekt tipi istiyorsan önce koda kanca eklemek gerekir.

| Alan | Nerede işlenir | Ne yapar |
|---|---|---|
| `global_ek_guc` | `combat_resolver.gd:346` | Her oyuncu biriminin **Güç**'üne eklenir (toplamsal) |
| `global_kat` | `combat_resolver.gd:349` | Her oyuncu biriminin **Kat**'ıyla çarpılır |
| `baslangic_kalkan` | `battle_screen.gd:783` | **Yalnız round 0'da** sahadaki birimlere Kalkan |
| `mevzi_bonus` | `battle_screen.gd:804` | Her planlama fazında +AP (Mevzi), `AP_MAX` ile sınırlı |
| `altin_bonus` | `battle_screen.gd:882` | **Yalnız zafer anında** +Altın |

### Liste

| id | Ad | Fiyat | Etki (kodda gerçekte) |
|---|---|---|---|
| `kanli_tilsim` | Kanlı Tılsım | 11 | +1 Güç (tüm birimler) |
| `pus_muskasi` | Pus Muskası | 15 | +2 Güç |
| `yagmaci_hurcu` | Yağmacı Hurcu | 15 | +1 Güç · zaferde +8 Altın |
| `tiryaki_kupasi` | Tiryaki Kupası | 16 | Zaferde +12 Altın |
| `karanlik_zirh_parcasi` | Karanlık Zırh Parçası | 17 | Savaş başı +6 Kalkan |
| `kutsal_kalinti` | Kutsal Kalıntı | 18 | ×1.15 Kat |
| `sancaktar_borusu` | Sancaktar Borusu | 19 | Her tur +1 Mevzi (AP) |
| `atalarin_siperi` | Ataların Siperi | 20 | Savaş başı +8 Kalkan |
| `kefen_bayragi` | Kefen Bayrağı | 21 | ×1.1 Kat · savaş başı +4 Kalkan |
| `serdengecti_madalyonu` | Serdengeçti Madalyonu | 22 | ×1.2 Kat |

### Denge notu
Fiyat bandı 11–22, çok dar. **Kat** relic'leri (`kutsal_kalinti` 1.15, `kefen_bayragi` 1.1,
`serdengecti_madalyonu` 1.2) `CLAUDE.md` §3.6'ya göre "nadir ve pahalı" olmalı ama
en pahalısı en ucuzun iki katı bile değil. Güç relic'leri (+1/+2) geç oyunda anlamsızlaşıyor.

### Bilinen tuzak
`baslangic_kalkan` **yalnız `_round == 0`**'da uygulanıyor. Savaş ortasında sahaya inen
takviye birimler bu Kalkan'ı almaz — açıklamalar "tüm birimler" dediği için yanıltıcı.

---

## 2. TABYALAR (Traits) — 18 adet, hepsi çalışıyor

**Veri:** `data/traits/*.tres` · **Model:** `src/logic/trait_data.gd`

`tetik`: 0=PASSIVE · 1=ON_HIT · 2=ON_KILL · 3=ON_DEATH · 4=ON_DEPLOY · 5=ROUND_START · 6=AURA
`kosul`: 0=YOK · 1=HEDEF_AYNI_SATIR_KOLON · 2=DIS_KOLON · 3=YUKSEK_ZEMIN · 4=KOMSU_ETIKET_BASINA · 5=SAHADA_ETIKET_MIN
`hedef`: 0=KENDİ · 1=VURULAN · 2=KOMŞU_DOSTLAR · 3=KOMŞU_DÜŞMANLAR

### Konum (PASSIVE — nerede durduğuna bağlı)
| id | Ad | Etki |
|---|---|---|
| `nisan` | Nişan | Hedef aynı satır/kolondaysa **×1.5 Kat** |
| `kanat` | Kanat | En dış kolonda (A/F) **+3 Güç** |
| `ruzgar_kanadi` | Rüzgar Kanadı | En dış kolonda **×1.5 Kat** |
| `yuksek_zemin` | Yüksek Zemin | Yükselti tile'ında **+2 Güç, ×1.25 Kat** |

### Sinerji (etiket bağı)
| id | Ad | Etki |
|---|---|---|
| `suru_lideri` | Sürü Lideri | Bitişik her *Kurt* dost için **+2 Güç** |
| `muhafiz_kalkani` | Muhafız Kalkanı | Bitişik her *Muhafız* dost için **+2 Güç** |
| `kutsal_bag` | Kutsal Bağ | Sahada 3+ *Kutsal* varsa hepsine **×1.4 Kat** |

### Tetik
| id | Ad | Tetik | Etki |
|---|---|---|---|
| `kan_kaybi` | Kan Kaybı | ON_HIT | Vuruşta hedefe **2 Zehir** |
| `alev_yemini` | Alev Yemini | ON_HIT | Vuruşta hedefe **2 Yanık** |
| `sarsici` | Sarsıcı | ON_HIT | **Her 2. vuruşta** hedef 1 tur **Sersem** |
| `kizil_ziyafet` | Kızıl Ziyafet | ON_KILL | Öldürünce savaş boyu kalıcı **+0.2 Kat** |
| `son_nefes` | Son Nefes | ON_DEATH | Ölünce komşu düşmanlara **max CAN'ın %50'si** hasar |
| `kor_patlamasi` | Kor Patlaması | ON_DEATH | Ölünce komşu düşmanlara **max CAN'ın %40'ı** hasar |
| `kalkan_durusu` | Kalkan Duruşu | ON_DEPLOY | Sahaya inince **CAN'ı kadar Kalkan** (`statu_deger=0` = "CAN kadar") |
| `ofke` | Öfke | ROUND_START | Her tur başı kalıcı **+1 Güç** birikir |
| `zafer_narasi` | Zafer Narası | ROUND_START | Her tur başı kalıcı **+0.15 Kat** birikir |
| `sargi` | Sargı | AURA | Komşu dostlar tur başı **+2 CAN** |

### Combo motoru (istifleme fırsatları)
- `nisan` + `kizil_ziyafet` → Kat×Kat, öldürdükçe patlar
- `yuksek_zemin` + `ruzgar_kanadi` → köşe yükseltisinde ×1.875 Kat
- `kalkan_durusu` + `son_nefes` → kamikaze tank
- `zafer_narasi` uzun savaşta üstel; ama Pus Basıncı (round ≥8) onu kırıyor

---

## 2b. SÖYLENTİLER (Rumors) — 6 adet, hepsi çalışıyor

**Veri:** `data/rumors/*.tres` (TraitData olarak — ayrı script yok) · **Alan:** `PieceData.rumor`

Birim başına **1** zayıf kalıcı pasif (gelistirme §14). Savaşta tabya gibi işlenir
(resolver birimin tabyalarına ekler), kayıtta `squad_rumors` olarak taşınır.
**Kaynak:** Meydan (Talim Kumarı) armağanı — kumar sonucu Upgrade YERİNE söylenti gelebilir.

| id | Ad | Tetik | Etki |
|---|---|---|---|
| `keskin_dis` | Keskin Diş | PASSIVE | +1 Güç |
| `ugurlu_tuy` | Uğurlu Tüy | PASSIVE | ×1.1 Kat |
| `kalin_post` | Kalın Post | ON_DEPLOY | Savaş başı 3 Kalkan |
| `pusu_kokusu` | Pusu Kokusu | ON_HIT | Vuruşta 1 Zehir |
| `eski_yara` | Eski Yara | ON_KILL | Öldürünce +0.1 Kat (savaş boyu) |
| `surunun_duasi` | Sürünün Duası | AURA | Komşu dostlar tur başı +1 CAN |

---

## 3. BİRİMLER (Pieces)

**Veri:** `data/pieces/*.tres`. Sprite'ı olan: `assets/units/<mesh_id>.png`.
`mesh_id` boşsa oyunda **renkli kapsül** çizilir (henüz sanatı yok demektir).

| id | Ad | SALDIRI/CAN/HIZ | Sprite? |
|---|---|---|---|
| `mizrakli` | Mızraklı | 3/10/4 | ✔ (`kuzu`) |
| `okcu` | Okçu | 2/6/6 | ✔ |
| `sifaci` | Şifacı | 0/8/5 | ✔ |
| `rahip` | Rahip | 3/8/5 | ✔ (`priest`) — vuruşta **şimşek** efekti |
| `baltaci` | Baltacı | 5/11/3 | ✔ |
| `suikastci` | Suikastçı | 4/6/6 | ✔ |
| `serdengecti` | Serdengeçti | 4/12/3 | ✘ **kapsül** |
| `kalkanci` | Kalkancı | 1/16/2 | ✘ **kapsül** |
| `buyucu` | Büyücü | 3/7/4 | ✘ **kapsül** |
| `suvari` | Süvari | 3/9/8 | ✘ **kapsül** |

> Sunum kancası: `combat_presenter.gd` `piece_id`'ye bakar. `rahip` → şimşek, `__boss` → alev nefesi.
> Yeni imza efekti istersen `piece_id` ile dallandır.

---

## 4. BOSS — Ejderha

**Kod:** `CombatUnit.make_boss()` · **Görsel:** `assets/bosses/ejderha.png` (6 kare, hücre 460×474)

Boss düğümlerinde (`boss`, `boss2`) **düşman bayrağının yerine** geçer. Bayrak sayılır
(`is_flag=true`) → zafer koşulu değişmez: **ejderhayı yık, kazan.** Farkı (`is_boss=true`):

- Aktivasyon sırasına **girer** (bayrak girmez)
- **RANGED**: yerinden kımıldamaz, en yakına saldırır
- Her vuruşta **Yanık 3** uygular (Alev Nefesi, `BOSS_YANIK_HASAR`)
- Zehir/Yanık **ona da işler** (bayrağa işlemez); Pus Basıncı'ndan muaf

| Düğüm | CAN | SALDIRI | HIZ |
|---|---|---|---|
| `boss` (Bölge 1) | 70 | 6 | 5 |
| `boss2` (Bölge 2) | 95 | 6 | 5 |

Ayar yeri: CAN → `encounters.gd` `FLAG_HP`. SALDIRI/HIZ → `battle_screen.gd` `BOSS_ATK`/`BOSS_SPD`.

---

## 5. OLAY KARTLARI — 4 adet

**Kod:** `map_screen.gd:354-438` (`.tres` değil, koda gömülü). Ziyarette biri rastgele.
Yetersiz Altın varsa o seçenek **pasif** olur.

### Pus İçinde Bir Yaralı Asker
- **İyileştir** (−5 Altın) → `mizrakli` birim kadroya katılır
- **Soy** (+20 Altın) → bayrak CAN −3
- **Geç** → yok

### Terk Edilmiş Sunak
- **Kalıntıyı al** → bayrak CAN −5, **rastgele relic**
- **Dua et** → bayrak CAN +8 (cap'e kadar)
- **Geç**

### Gezgin Tüccar
- **Kalıntı al** (−15 Altın) → rastgele relic
- **Erzak al** (−10 Altın) → tüm kadro tam CAN
- **Geç**

### Pus Fırtınası
- **İçine dal** → **%50**: +25 Altın · **%50**: bayrak CAN −4
- **Sığın** (−3 Altın) → başka etki yok
- **Geç**

> Bayrak CAN'ı olay ekonomisinin ana takas kalemi: para değil ama **run'ı bitiren kaynak**.
> Başlangıç 30 (+5/Garnizon seviyesi), 0 olursa sefer biter.

---

## 6. EKONOMİ — gerçekte iki para birimi var

### Altın (run içi) — `game_state.gd` `gold`
**Kazanç:** başlangıç `25 + meta_gold_lv*5` · savaş zaferi (encounter'a göre 15–75) ·
ödül ekranı "Altın" seçimi **+18** · olaylar (+20/+25) · relic `altin_bonus` (+8/+12)
**Harcama:** Dükkan relic 11–22 · Dükkan birim · **iyileştirme 10** · olaylar (−3/−5/−10/−15)

### Kalıntı (kalıcı, meta) — `game_state.gd` `meta_kalinti`
**Kazanç:** sefer sonu `geçilen_katman × 2 + (kazandıysa 10)` → `user://garrison.json`
**Harcama:** Garnizon. Maliyet `(seviye+1) × 10`.

| Tesis | Seviye başına |
|---|---|
| Başlangıç Altını | +5 Altın |
| Bayrak Dayanıklılığı | +5 bayrak CAN |
| Seferberlik | +1 başlangıç Mevzi |

### Dükkan (`shop_screen.gd`)
"Yadigarlar" (3 rastgele) · "Paralı Askerler" (2 rastgele) ·
**Bölüğü İyileştir (10)** · **Tabya Birleştir** (ücretsiz) · **Birim Sürgün** (ücretsiz) ·
**Stok Çevir (1 zar)**

### Zar (run içi) — `game_state.gd` `zar`
**Kazanç:** başlangıç `4 + meta_degirmen_lv*2` (Değirmen tesisi)
**Harcama:** ödül/dükkan/mezar **yeniden çevirme** (1 zar). Savaş içi HIZ-eşitliği zarı
otomatiktir, zar HARCAMAZ (seed'li, `SPEED_DICE` event).

---

## 6b. HİZMET DÜĞÜMLERİ (savaş dışı, tek ziyaret — hepsi çalışıyor)

Hepsi **izometrik diyorama** (`node_diorama.gd` tabanı, MoP "Gray grave" dili):
tile adası + prop'lar + prop üstünde yüzen elmas seçenekler + üst açıklama +
alt ödül şeridi. Yeni hizmet düğümü eklerken NodeDiorama'dan türet.

| Düğüm | Ekran | Ne yapar |
|---|---|---|
| **Şaman Çadırı** (`saman`) | `shaman_screen.gd` | Alt şeritten birim seç → birim büyü plakasına çıkar → 2 elmas: **+2 Saldırı / +3 Can / +1 Hız**'dan seed'li ikisi. Her birim EN ÇOK 2 kez (◆ pip). Kalıcı, kayda yazılır. |
| **Sahra Revan** (`revir`) | `infirmary_screen.gd` | İki elmastan BİRİ: sancağın üstünde **Bayrak Onarımı +10** / yaralı kuzunun üstünde **Sürü Bakımı** (tüm bölük tam CAN). Bedava. |
| **Gri Mezar** (`mezar`) | `grave_screen.gd` | Mezarın üstünde altın elmas: **sancak −2** → rastgele yadigar. Mavi elmas: **1 zar** ile teklifi çevir. Alt şerit teklifi önizler. Sancak 3'ün altındaysa kabul kapalı. |
| **Nitelik Dükkanı** (`nitelik`) | `trait_shop_screen.gd` | 2 tabya sunulur (seed'li) → boş slotu olan kuzuyu seç → kaide elmaslarından tabyayı seç → KALICI işlenir (`GameState.give_trait`, kayda `squad_traits`). Bedava. |
| **Yadigar Dükkanı** (`yadigar`) | `relic_choice_screen.gd` | 2 yadigardan 1'i **bedava** (MoP relic shop; altınlı Dükkan'dan ayrı). Kaidelerde altın gem elmasları. |
| **Darağacı** (`daragaci`) | `gallows_screen.gd` | Kurban seç (tabyalı) → mirasçı seç → İNFAZ: kurbanın tabyaları mirasçının boş slotlarına geçer, kurban kadrodan çıkar (`remove_unit` — kalan birimlerin CAN'ı korunur). Deste inceltme + tabya taşıma. |
| **Meydan / Talim Kumarı** (`meydan`) | `saloon_screen.gd` | Kuzu seç → statları seed'li yeniden dağılır (kumar) + armağan: Upgrade VEYA Söylenti (§2b). Beğenmezsen **1 zar** ile yeniden çevir. Zar elması kuzunun kafasının üstünde döner. |

| **Kitapçı** (`kitapci`) | `bookstore_screen.gd` | 3 seed'li item kaidesi; altınla al (çanta ≤3). **Stok Çevir: 1 zar.** Bölge başına 1 düğüm. |

**Sefer dışı diyoramalar:**
- **Ağıl Meydanı** (`hub_screen.gd`, debug `--hub`) — sefer öncesi hub (gelistirme §2).
  Menüde "Yeni Sefer" buraya gelir; run **Sefere Çık** elmasıyla başlar. Ateş = Sefere Çık,
  çadır = Garnizon, Lonca/Arşiv kilitli. Sefer sonu ekranı da buraya döner.
- **Kart Olayı** (`event_card.gd`, debug `--olay`) — fiziksel yırtık-kenar kart (gelistirme
  §15.5): art paneli placeholder, ödül ikonlu seçenekler, halftone karartma, flip-in.
- **Garnizon** (`garrison_screen.gd`, debug `--garrison`) — kamp adası diyoraması
  (gelistirme §12): ateş + 4 tesis prop'u (İkmal/Atölye/Talimhane/dönen Değirmen),
  tesis elmasları Sv+bedel gösterir, Kalıntı harcanınca kalıcı yükselir.

> Haritada yerleri: `encounters.gd MAP_TEMPLATE` — bölge başına 1 şaman, 1 revir, 1 mezar
> (elit'in alternatifi). İkonlar: `assets/icons/shaman.svg` (göz) / `medic.svg` (artı) /
> `grave.svg` (mezar taşı).

---

## 6c. ITEMLAR — 8 adet, hepsi çalışıyor

**Veri:** `data/items/*.tres` · **Model:** `src/logic/item_data.gd` (**RelicData'yı genişletir**)

Tek kullanımlık. Kaynak: Kitapçı düğümü. Çanta: `GameState.items`, kapasite **3** (`ITEM_CAP`).
Harita HUD'unda sol altta şerit — tıkla:
- **ANINDA** (`tur=0`): etki hemen işler (bölük CAN / sancak / zar).
- **SONRAKI_SAVAS** (`tur=1`): kuşanılır (`armed_items`) → bir sonraki savaşta miras relic
  alanları tek savaşlık işler (`battle_screen._ctx` relics + `relic_sum`), savaş sonu tükenir
  (`consume_armed_items`, zafer/yenilgi fark etmez). Kayıtta `item_ids` + `armed_item_ids`.

| id | Ad | Fiyat | Tür | Etki |
|---|---|---|---|---|
| `sans_kemigi` | Şans Kemiği | 10 | ANINDA | +2 zar |
| `sargi_denkleri` | Sargı Denkleri | 12 | ANINDA | bölük tam CAN |
| `sancak_yamasi` | Sancak Yaması | 14 | ANINDA | sancak +6 (cap'e kadar) |
| `kuru_erzak` | Kuru Erzak | 18 | ANINDA | bölük tam CAN + sancak +3 |
| `bileme_tasi` | Bileme Taşı | 12 | SONRAKİ | +2 Güç (tek savaş) |
| `kalkan_yagi` | Kalkan Yağı | 12 | SONRAKİ | savaş başı +6 Kalkan |
| `boru_cagrisi` | Boru Çağrısı | 14 | SONRAKİ | tur başı +2 Mevzi |
| `kutsanmis_yag` | Kutsanmış Yağ | 20 | SONRAKİ | ×1.25 Kat |

---

## 7. TASARIMDA VAR, KODDA YOK

`CLAUDE.md` bunları detaylıca tarif ediyor ama **hiç yazılmadılar.** İçerik ayarlarken
buralara vakit harcama — önce sistem gerekiyor.

| Sistem | Durum |
|---|---|
| **Lonca / Arşiv / Onur Salonu / Contract** (gelistirme §2) | Ağıl Meydanı'nda kilitli elmas plakalar var; arkasında sistem yok |
| **Kaynak parası + tesis çeşitliliği** (gelistirme §12) | Garnizon diyoraması 4 tesisli; spec 6-8 tesis + ayrı "Kaynak" parası istiyor (kodda tek meta para: **Kalıntı**) |
| **Tutorial** (gelistirme §3) | Yok — tek iz "Nasıl Oynanır" modalı |
| **Contract / Ordeal** (gelistirme §2/§12) | Yok |
| **Ün (Reputation)** | Hiçbir yerde kazanılmıyor/harcanmıyor |
| **Emir Kartları** | `data/orders/` yok. Tek iz: Kumandan yeteneği (`battle_screen._on_commander`) |
| **3.–4. bölge** | Harita şablonu 2 bölge (`encounters.gd MAP_TEMPLATE`); spec 4 istiyor |

> Harita düğümleri (hepsi çalışır): `savas`/`elit`/`boss`/`dukkan`/`olay`/`saman`/`revir`/
> `mezar`/`nitelik`/`yadigar`/`daragaci`/`meydan`/`kitapci`.

### Ölü kod
`game_state.gd:27` `relic_kat()` hiç çağrılmıyor (`global_kat` zaten resolver'da uygulanıyor).

---

## 8. İÇERİK EKLEME REÇETESİ

**Yeni relic:** `data/relics/<id>.tres` kopyala, §1'deki 5 alandan birini doldur. Kod değişmez.
**Yeni tabya:** `data/traits/<id>.tres`, `tetik`+`kosul` enum'larını §2'den seç. Kod değişmez.
**Yeni birim:** `data/pieces/<id>.tres` + `assets/units/<mesh_id>.png` (yoksa kapsül çizilir).
**Yeni savaş:** `encounters.gd` `DEFS`'e ekle + `FLAG_HP`'ye CAN gir + `MAP_TEMPLATE`'e düğüm koy.
**Yeni olay:** `map_screen.gd` `EVENTS` dizisi (henüz `.tres` değil).

> Asset ekledikten sonra **import şart**, yoksa doku tanınmaz:
> `Godot_..._console.exe --headless --path <repo> --import`
