# PUS — CLAUDE.md

> **Tür:** İzometrik 3D otomatik-savaş (auto-battler) × roguelite deckbuilder × grid taktik
> **Motor:** Godot 4.3+ (Forward+)
> **Platform:** PC (Steam) — solo dev
> **Referans DNA:** Master of Piece + Wildfrost (birim-deckbuilder) + Into the Breach (telegraph'lı grid) + TFT/Mechabellum (kur-bırak-otomatik çözül) + Balatro (chips×mult / Güç×Kat sinerji yoğunluğu)
> **Çalışma adı:** PUS (dünyayı yutan kara sis). Kesin ad sonra.

Bu doküman Claude Code'a talimattır. Her bölüm buildable olacak şekilde somut sayı ve şema içerir. Görsel asset'ler **dummy primitiflerle** başlar (bkz. §18); sanat sonra girer, mantık asetten bağımsız çalışır.

---

## 0. TEK CÜMLE + ÇEKİRDEK KİMLİK

**Bütün kararlar savaştan ÖNCE alınır; savaş deterministik ve otomatik çözülür.**

Sen paralı asker bölüğünü izometrik ızgaraya dizersin, Emir Kartı oynarsın, sonra "SAVAŞ" dersin ve savaş HIZ sırasına göre kendi kendine akar. Beceri tavanı "sıra sıra vur"da değil, **konumlama + sinerji öngörüsünde**. Balatro mantığı tetiklenme anında değil, **kurulum anında** düşünülür.

**Neden eğlenceli:** Her birim `Güç` (toplamsal +) ve `Kat` (çarpımsal ×) katkısı taşır. Doğru komşuluk + doğru trait dizilimi hasarı katlar. İzleme fazı bir "makine kurdum, çalışmasını izliyorum" tatmini verir.

---

## 1. TASARIM SÜTUNLARI (dokunulmaz)

1. **Kurulum = oyun.** Combat izlenir, oynanmaz. Tüm zeka deployment ekranında.
2. **Determinizm.** Aynı seed + aynı kurulum = aynı sonuç. RNG yalnızca seed'li ve savaş öncesi (kart çekme, ödül) alanda. Savaş içi sıfır rastlantı.
3. **Okunabilirlik > detay.** Kamera uzak, birimler minik. Her şey ikon + sayı + renkle anlaşılır. Art fakir olsa da oyun anlaşılır olmalı.
4. **Güç×Kat.** Her stat kaynağı ya toplamsaldır ya çarpımsal. İkisinin ayrımı oyunun tüm derinliği.
5. **Başarısızlık ilerlemedir.** Kaybetmek = Anı kazanmak = Garnizon'u büyütmek. Ölüm hikayenin parçası.
6. **Scope kilidi.** Aşağıdaki §17'deki sınırlar aşılmaz. Yeni özellik = başka bir özelliği kesmeden girmez.

---

## 2. OYUN AKIŞI (macro loop)

```
GARNİZON (meta üs)
   │  Anı harca → tesis inşa et → kalıcı upgrade
   ▼
SEFER BAŞLAT (yeni run)
   │  Başlangıç bölüğü + Kumandan + başlangıç Emir destesi
   ▼
BÖLGE HARİTASI (Slay-the-Spire tarzı düğüm haritası)  ×3 bölge
   ├─ Savaş düğümü   → grid savaş → ödül (Altın / yeni birim / relic)
   ├─ Elit düğümü    → zor savaş → garantili relic
   ├─ Bina düğümü    → dükkan / trait füzyon / birim sürgün / item
   ├─ Olay düğümü    → dallanan hikaye kartı (seçim)
   ├─ Han düğümü     → Söylenti (rumor) kazıma
   └─ BOSS düğümü    → bölge sonu → sonraki bölge
   ▼
3. BOSS yenilir → SEFER TAMAM (kazanç) veya herhangi savaşta ölüm → SEFER BİTTİ (Anı topla)
   ▼
GARNİZON'a dön (meta ilerleme)
```

**Sefer uzunluğu hedefi:** 45–70 dk. Bölge = act. Her bölge ~10–14 düğüm.

---

## 3. SAVAŞ SİSTEMİ (kalp)

### 3.1 Izgara
- **Boyut:** 6 kolon (A–F) × 5 satır (1–5). Izometrik, kübik yükseklikli.
- **Alt yarı (satır 1–2):** oyuncu deployment bölgesi.
- **Satır 3:** no-man's-land. Engeller/zemin efektleri burada spawn olur.
- **Üst yarı (satır 4–5):** düşman bölgesi, savaş başında sabit yerleştirilmiş.
- Her tile: `{coord, height, terrain_type, occupant, tile_effect}`.

### 3.2 Faz sırası
1. **DEPLOYMENT FAZI** (oyuncu kontrolünde, süresiz):
   - Mevzi (AP) harca → birimleri satır 1–2'ye sürükle-bırak.
   - Emir Kartı oyna (elindeki kartlardan).
   - Birimleri kendi bölgende serbest yeniden konumla.
   - Düşman kurulumu + ilk turdaki niyetleri (intent) görünür (telegraph).
2. **"SAVAŞ" butonuna bas** → geri dönüş yok.
3. **RESOLUTION FAZI** (otomatik):
   - Tur döngüsü işler, `CombatResolver` olay listesi üretir, `CombatPresenter` oynatır.
   - Oyuncu sadece izler (hız 1x/2x/atla butonu var).
4. **SONUÇ:** zafer / yenilgi ekranı.

### 3.3 Tur (round) döngüsü
```
round = 0
while iki taraf da ayakta and round < MAX_ROUND(15):
    round += 1
    baslangic_efektleri()          # zemin hasarı, DoT (Zehir/Yanık), aura yenile
    aktivasyon_sirasi = tüm canlı birimler, HIZ azalan sırada
        eşitlik: önce alt satır (frontline), sonra düşük kolon index
    for birim in aktivasyon_sirasi:
        if birim öldüyse: skip
        birim.activate()           # hareket + saldırı + tetikler
    if round >= SUDDEN_DEATH_ROUND(8):
        pus_basinci()              # tüm birimler artan HP kaybı (aşağıda)
kazanan = ayakta kalan taraf
```

### 3.4 Birim aktivasyonu (`activate()`)
Hedefleme kuralı **birim sınıfına** bağlı:

- **KISA MENZİL (Melee):** 8-yönlü komşuda düşman varsa → en zayıf/en yakın olana saldır. Yoksa → en yakın düşmana doğru 1 tile ilerle (greedy, engel/duvarı dolaş), ilerledikten sonra komşuda düşman oluştuysa saldır.
- **UZAK MENZİL (Ranged):** hareket etmez. Grid mesafesine göre en yakın düşmana saldırır. `line_only` flag'li birimler yalnız aynı kolon/satırdaki düşmanı vurur.
- **DESTEK (Support):** saldırmaz. Aktivasyonda menzilindeki (varsayılan komşu) dostlara buff/heal uygular.

Saldırı sırası: `on_before_attack` tetikleri → hasar hesabı → hasar uygula → `on_hit` / `on_kill` tetikleri → hedefte `on_damaged` / `on_death` tetikleri.

### 3.5 Statlar
Her birim üç stat taşır (HUD'da 3 rakam):
| Stat | İkon | Anlam |
|---|---|---|
| **SALDIRI** | kılıç | Vuruş başına ham hasar tabanı |
| **CAN** | kalp | Ölmeden önce dayanma |
| **HIZ** | çan/kanat | Aktivasyon sırası (yüksek önce) |

Ek meta-statlar (savaş içinde değişir, HUD'da rozet olarak):
- **Zırh** (flat hasar azaltma), **Kalkan** (geçici ekstra CAN), **Zehir/Yanık** (DoT sayacı), **Sersem** (tur atlar), **Kök** (hareket edemez).

### 3.6 Hasar formülü (Güç×Kat — Balatro çekirdeği)
```
raw   = (SALDIRI_base + Σ EK_Güç) × Π KAT
final = max(0, floor(raw) − hedef.Zırh)
CAN veya Kalkan'dan düşülür (önce Kalkan)
```
- `EK_Güç`: trait/relic/aura/statü'den gelen **toplamsal +ATK** (chips).
- `KAT`: trait/relic/rumor'dan gelen **çarpımsal ×** (mult). Varsayılan 1.0.
- Kritik: bazı trait'ler `on_hit` ile `KAT`'ı geçici veya kalıcı büyütür → build motoru.

**Tasarım niyeti:** Güç kaynakları bol/ucuz, Kat kaynakları nadir/pahalı. Kat'ı yığmak (Balatro'daki x-mult jokerleri gibi) üstel patlama verir; pozisyonlama Kat'ı besler.

### 3.7 Pus Basıncı (sudden death)
`round ≥ 8`'den itibaren her tur başı **tüm** birimler `(round − 7) × 2` sabit HP kaybeder. Uzayan savaşları çözer, "sonsuz tank" build'lerini kırar. Görselde ekranın kenarlarından mor pus içeri sızar.

---

## 4. BİRİMLER (Bölük / Mercenaries)

Kart yerine **birim** toplarsın. Deste = kadro. Kadro run içinde büyür.

### 4.1 Birim veri modeli
```
PieceData (Resource):
  id: StringName
  ad: String
  sinif: enum{MELEE, RANGED, SUPPORT}
  saldiri: int
  can: int
  hiz: int
  mevzi_maliyeti: int          # 1–4 AP
  tabya_slotu: int = 2          # kaç trait taşıyabilir
  base_traits: Array[TraitData] # doğuştan gelen (0–2)
  etiketler: Array[StringName]  # sinerji tag'leri: {Kurt, Paralı, Kutsal, Makine...}
  tier: int                     # 1–3 (nadirlik / güç bandı)
  mesh_id: StringName           # dummy: renkli quad/kapsül
```

### 4.2 Sayı bantları (dengeleme başlangıcı)
| Tier | SALDIRI | CAN | HIZ | Mevzi |
|---|---|---|---|---|
| 1 (yaya) | 1–3 | 4–8 | 3–6 | 1 |
| 2 (usta) | 3–6 | 8–16 | 4–7 | 2 |
| 3 (kahraman) | 5–9 | 14–28 | 5–9 | 3–4 |

### 4.3 Örnek başlangıç bölüğü (dummy prototip)
1. **Mızraklı** — MELEE, 3/10/4, mevzi 1, trait: *Kalkan Duruşu*
2. **Okçu** — RANGED, 2/6/6, mevzi 1, trait: *Nişan*
3. **Şifacı** — SUPPORT, 0/8/5, mevzi 2, trait: *Sargı*
4. **Serdengeçti** — MELEE, 4/12/3, mevzi 2, trait: *Kan Kaybı*

Full oyun havuzu: **100+ birim** (spec bu 4 + §5 örnek trait setiyle sistemi tanımlar; kalanı içerik üretimi).

---

## 5. TABYALAR (Traits / Nitelikler) — SİNERJİ MOTORU

Her birim ≤2 tabya taşır. Tabyalar `Güç` (toplamsal), `Kat` (çarpımsal) ve tetikler üretir. **Asıl oyun burada.**

### 5.1 Tabya kategorileri
- **KONUM:** komşuluğa/satıra/yüksekliğe bağlı bonus.
- **SİNERJİ (etiket):** aynı etiketten N birim → hepsine bonus.
- **TETİK:** `on_hit / on_kill / on_death / on_deploy / round_start`.
- **AURA:** komşulara sürekli pasif.
- **STATÜ:** vuruşta statü efekti uygular.

### 5.2 Tabya veri modeli
```
TraitData (Resource):
  id, ad, kategori
  tetik: enum{PASSIVE, ON_HIT, ON_KILL, ON_DEATH, ON_DEPLOY, ROUND_START, AURA}
  kosul: String            # örn "kolon en dışta", "3+ Kurt etiketi"
  etki: Array[Effect]      # {tip: EK_GÜÇ|KAT|STATU|HEAL|SUMMON|MOVE, deger, hedef}
  ikon_id: StringName
```

### 5.3 Örnek tabya seti (temsili — sistemi gösterir)
| Ad | Kategori | Etki |
|---|---|---|
| **Nişan** | KONUM | Aynı satır/kolonda hedef varsa **×1.5 Kat**. |
| **Kanat** | KONUM | En dış kolondaysa (A veya F) **+3 Güç**. |
| **Yüksek Zemin** | KONUM | Yükselti tile'ındaysa **+2 Güç, ×1.25 Kat**. |
| **Sürü Lideri** | SİNERJİ | Bitişik her *Kurt* etiketli dost için **+2 Güç**. |
| **Kutsal Bağ** | SİNERJİ | Sahada 3+ *Kutsal* varsa hepsi **×1.4 Kat**. |
| **Kan Kaybı** | ON_HIT | Vuruşta hedefe **2 Zehir** uygula. |
| **Kızıl Ziyafet** | ON_KILL | Öldürünce kalıcı **×0.2 Kat** kazan (savaş boyu birikir). |
| **Son Nefes** | ON_DEATH | Ölünce komşu düşmanlara **CAN'ının %50'si** hasar. |
| **Sargı** | AURA | Komşu dostlar tur başı **+2 CAN** iyileşir. |
| **Sarsıcı** | ON_HIT | %... yok — **her 2. vuruşta** hedefi **1 tur Sersemlet**. |
| **Kalkan Duruşu** | ON_DEPLOY | Deployment'ta kendine **CAN kadar Kalkan**. |
| **Öfke** | ROUND_START | Her tur başı **+1 Güç** (biriken). |

Full oyun: 100+ tabya. Kat üreten tabyalar bilinçli olarak **nadir**.

### 5.4 Tabya füzyonu (Bina düğümünde)
İki birimden birinin tabyasını diğerine taşı → tek birimde 2 güçlü tabya birleştir. **Bu combo motorunun kalbi**: "Nişan + Kızıl Ziyafet" gibi Kat×Kat istifleri kur.

---

## 6. STATÜ EFEKTLERİ

| Statü | Davranış | Stack kuralı |
|---|---|---|
| **Zehir** | Tur başı `X` hasar, sonra `X→X−1`. | Sayaç toplanır. |
| **Yanık** | Tur başı `X` sabit hasar, `Y` tur. | Süre yenilenir, hasar toplanmaz. |
| **Sersem** | 1 aktivasyon atla. | Süre toplanır. |
| **Kök** | Hareket edemez (saldırabilir). | Süre toplanır. |
| **Zırh** | Her vuruşta `−X` flat. | Kalıcı, buff'la yenilenir. |
| **Kalkan** | CAN'dan önce tüketilen geçici HP. | Toplanır. |
| **Güçlenme** | `+Güç` veya `×Kat` geçici. | Kaynağa göre. |
| **Lanet** | `×0.5 Kat` (debuff). | Toplanmaz, süre yenilenir. |

---

## 7. ZEMİN & ENGELLER

Satır 3 (no-man's-land) ve seçili tile'larda spawn olur. Yükseklik hem görsel hem mekanik.

| Zemin | Etki |
|---|---|
| **Duvar** | Hareketi + LOS'u bloklar. Yıkılabilir (CAN'lı obje). |
| **Lav** | Üstünde biten birim tur başı 3 hasar. |
| **Diken** | Üzerine ilk giren 2 hasar alır. |
| **Kutsal Zemin** | Üstündeki dost **+2 Güç**. |
| **Pus Tile** | Üstündeki birim **×0.75 Kat** (lanetli sis). |
| **Yükselti** | Yüksek zemin: menzilli birim **+1 kolon menzil**, herkese **+1 Güç**. |

Konumlama derinliği: birimi Yükselti'ye koy + Yükselti tabyasını ver → Kat çarpanı çift beslenir. Melee'yi Lav yanına dizerek düşmanı içeri it (ilerideki *push* trait'leriyle).

---

## 8. EMİR KARTLARI (Order Cards) — 20 KART / DECKBUILDER KATMANI

Bunlar §5'teki tabyalardan **ayrı**. Kumandanın tek-kullanımlık taktik destesi. Deployment fazında elinden oynanır.

### 8.1 Mekanik
- Her savaş başı Emir destesinden `el_boyutu` (başlangıç 3) kart çek.
- Deployment'ta oynanır; oynanan kart çöpe gider. Savaş sonu deste karışır.
- Yeni kart Bina/ödül'den kazanılır (deckbuilding).

### 8.2 Örnek Emir Kartları (20 hedef)
| Ad | Etki |
|---|---|
| **Takviye** | Bu savaş için bir yaya birimini bedava dağıt. |
| **Mevzi Değiştir** | İki dost birimin yerini değiştir. |
| **Ateş Desteği** | Seçili tile + komşularına 4 hasar. |
| **Sis Perdesi** | Bir düşman ilk turunu atlar (Sersem). |
| **Kışkırt** | Bir dost 2 tur boyunca tüm melee düşmanları kendine çeker (taunt). |
| **Çevik Ayak** | Bir dost **+3 HIZ** (bu savaş). |
| **Kutsama** | Bir dost **×1.5 Kat** (bu savaş). |
| **Kan Parası** | 15 Altın kazan, ama bir dost **−3 CAN** başlar. |
| **Zincir Vuruş** | Bir dostun ilk saldırısı komşu 2 düşmana da sıçrar. |
| **Geri Çekil** | Bir dostu destene geri al (mevzisini iade et). |

Full: 20 kart. Kartlar arası da combo var (Kışkırt + Son Nefes = kamikaze tank).

---

## 9. YADİGARLAR (Relics) — 30 ADET

Global, run boyu pasifler. Elit/boss/dükkandan gelir.

### 9.1 Örnekler
| Ad | Etki |
|---|---|
| **Kırık Terazi** | Tüm melee birimler **+1 Güç**. |
| **Pus Kristali** | Her savaş başı ilk Emir Kartı bedava. |
| **Kanlı Sancak** | Bir dost öldüğünde diğer dostlar **×0.15 Kat** (bu savaş). |
| **Ustanın Cetveli** | Yükselti bonusları iki katına çıkar. |
| **Boş Miğfer** | Başlangıç Mevzi (AP) **+2**. |
| **Söylenti Defteri** | Ün kazancı **+50%**. |
| **Lanetli Sikke** | Altın kazancı **+40%**, ama her savaş 1 rastgele dost **Lanet** başlar. |

Full: 30 yadigar. Bilinçli ki bazıları build-around ("×Kat kaynağı" relic'leri nadir).

---

## 10. SÖYLENTİLER (Rumors) — HAN SİSTEMİ

Birim yeterince zafer/kill biriktirince **Ün** kazanır. Han (Tavern) düğümünde Ün harcayıp o birime **Söylenti** kazırsın: güçlü, adlandırılmış, kalıcı pasif.

### 10.1 Örnekler
| Söylenti | Şart | Etki |
|---|---|---|
| **Kızıl Biçici** | 10 kill | Öldürdüğünde kalıcı **×0.25 Kat**, savaşlar arası taşınır. |
| **Yıkılmaz** | 3 savaş sağ çık | Savaş başı **CAN'ı kadar Kalkan**. |
| **Sürü Hükümdarı** | 3+ Kurt dostla kazan | Tüm *Kurt* etiketliler **+3 Güç**. |
| **Sisin Efendisi** | Pus Tile'da kill | Pus Tile debuff'undan etkilenmez, tersine **×1.25 Kat** alır. |

Söylenti = geç-run power spike'ı. Bir "yıldız birim" yaratma fantezisi.

---

## 11. DÜŞMANLAR & NİYET (Telegraph)

Deployment'ta düşman kurulumu + **ilk tur niyetleri** görünür (Into the Breach mantığı, ama otomatik). Örn: "Damage" ok'u + hedef tile vurgusu.

### 11.1 Düşman arketipleri
| Arketip | Rol |
|---|---|
| **Pus Yürüyücü** | Temel melee, ucuz, kalabalık. |
| **Zırhlı** | Yüksek CAN + Zırh, yavaş. |
| **Nişancı** | Ranged, arka satırdan diker. |
| **Şaman** | Support, düşmanları buff'lar. |
| **Yığın** | Ölünce 2 küçük yaratık spawn. |

### 11.2 Örnek BOSS: **KARABASAN** (bölge 1 sonu — screenshot'taki mor canavar)
- Devasa, ızgaranın üstünde tünemiş, 82 CAN.
- **Tur başı niyet telegraph'ı** (deployment'ta görünür):
  - *Pençe*: bir satırın tamamına 6 hasar.
  - *Uluma*: tüm oyuncu birimlerine **Lanet** (×0.5 Kat) 2 tur.
  - *Sis Nefesi*: 2 rastgele tile → Pus Tile'a çevirir.
- **Faz 2 (CAN < %50):** Uluma cooldown'u düşer, ekstra *Pençe*.
- Yenmek için: Kat build'ini erken kur, Lanet turlarında burst'ü zamanla, Pus Tile'lardan uzak dur.

Full: 3 bölge × 1 boss + 2–3 elit + jenerik havuz.

---

## 12. BİNA & DÜKKAN DÜĞÜMLERİ

Bina düğümünde 3–4 hizmet:
- **Dükkan:** Altın'la birim / relic / item satın al.
- **Trait Füzyonu:** iki birimden tabya taşı (§5.4).
- **Sürgün:** işe yaramaz birimi kadrodan çıkar (deste inceltme).
- **Şifahane:** birimlerin CAN'ını yenile / Lanet temizle.

---

## 13. OLAY KARTLARI (Narrative Encounters)

Yol boyu dallanan kısa hikaye kartları (Slay the Spire olay mantığı). Metin + 2–3 seçim → sonuç (Altın, birim, relic, hasar, statü, seed'li risk).

```
EventData (Resource):
  id, baslik, govde_metni
  secenekler: Array[{etiket, sonuc: Array[Effect], sart?}]
```
Örn: *"Pus içinde bir yaralı asker."* → [İyileştir: −5 Altın, +1 birim] / [Soymak: +20 Altın, −5 Ün] / [Geç: hiçbir şey].

---

## 14. GARNİZON (Meta İlerleme)

Sefer bitince (kazan/kaybet) **Anı** toplanır. Garnizon'da kalıcı tesis inşa edilir.

### 14.1 Tesisler (örnek, tier'lı)
| Tesis | Etki |
|---|---|
| **Talimhane** | Başlangıç Mevzi (AP) +1 / +2 / +3. |
| **Kışla** | Başlangıç bölüğü kalitesi artar. |
| **Demirhane** | +1 relic slotuyla başla. |
| **Han Loncası** | Söylenti maliyeti −25%. |
| **Arşiv** | Yeni birim/tabya havuza açar (unlock). |
| **Erzak Deposu** | +1 item taşıma. |
| **Sunak** | Sefer başı 1 rastgele buff seç. |

Meta niyeti: her kayıp bir sonraki run'ı somut güçlendirir. **Anı** kalıcı; **Altın/Ün** run içi.

---

## 15. EKONOMİ / PARA BİRİMLERİ

| Birim | Kapsam | Kaynak | Harcama |
|---|---|---|---|
| **Altın** | Run içi | Savaş ödülü, olaylar | Dükkan (birim/relic/item) |
| **Ün** | Run içi | Kill/zafer | Söylenti kazıma (Han) |
| **Anı** | Kalıcı (meta) | Sefer sonu (kazan+kaybet) | Garnizon tesisleri |
| **Erzak** | Run içi (item şarjı) | Depo/olay | Tek-kullanımlık item |

---

## 16. İZOMETRİK 3D GÖRÜNÜŞ (tam render spec)

Screenshot'lardaki look: karanlık boşlukta yüzen, sıcak ışıklı kübik adalar; toon outline; emissive grid; punchy damage sayıları. Her parçası aşağıda.

### 16.1 Kamera
- **Camera3D**, `projection = ORTHOGONAL`. `size ≈ 10–14` (grid'e göre).
- Sabit izometrik açı: **pitch ≈ −35°, yaw = 45°** (klasik 2:1 diamond hissi için pitch ≈ −30°).
- **90° adımlarla döndürülebilir** (Q/E) → yükseklikli grid'de arka tile'ları görmek için. Rotasyon `tween` ile yumuşak.
- Hafif zoom (mouse wheel), sınırlı.
- Kamera bir `CameraRig` (Node3D) child'ı; rig döner/kaydırılır, kamera lokal sabit.

### 16.2 Toon / cel shading + outline
- Materyal: `StandardMaterial3D` yerine özel **toon ShaderMaterial** (ışığı 2–3 banda quantize et). Godot 4'te `shader_type spatial; render_mode cull_back;` + `LIGHT()` fonksiyonunda `step()`/`smoothstep()` ile band'leme.
- **Outline (iki yöntem, biri seç):**
  - **A — Inverse-hull:** her mesh'in ikinci bir materyali; `cull_front`, vertex'i normal boyunca `grow ≈ 0.02` büyüt, sabit siyah renk. Ucuz, per-object.
  - **B — Screen-space:** `WorldEnvironment` + tam ekran edge-detect (depth+normal) post-process quad. Daha tutarlı, biraz pahalı.
  - **Prototip için A** (dummy asset'lerde zaten mesh var).
- Renkler `emission` ile pop'lar (kritik vuruş halesi, grid glow).

### 16.3 Dünya = kübik bloklar
- Zemin **stacked cube** blokları (screenshot'taki gibi). Üst yüz = biome dokusu (çim/toprak/lav), yan yüzler = koyu toprak/kaya kenar.
- İmplementasyon: **GridMap** veya **MultiMeshInstance3D** (perf için tercih: MultiMesh; yüzlerce blok tek draw call).
- Yükseklik = blok `y` offset'i. Her tile'ın `height` alanı görsel + mekanik (Yükselti bonusu).
- Adalar karanlık boşlukta yüzer: blokların altı görünmez, arka plan düz koyu lacivert (`bg_color ≈ #0d0f1a`).

### 16.4 Izgara overlay (menzil / seçim)
- Tile üst yüzüne **emissive decal** ya da shader tint:
  - Yeşil = geçerli deployment tile.
  - Kırmızı = tehlike / düşman menzili / boss telegraph.
  - Sarı hale = seçili birim.
- `Decal` node veya tile-top mesh'e ayrı `ShaderMaterial` (animated pulse, `TIME` ile). Screenshot'taki kırmızı "yanan grid" tam bu: emissive kırmızı + hafif pulse.

### 16.5 Birimler
- Prototipte **billboarded quad** (kamera'ya bakan sprite) veya **düşük-poli kapsül/kutu**. Full oyunda: minik low-poly figür veya iso sprite.
- Animasyon **asset gerektirmez**: idle bob (`sin(TIME)` y-offset), saldırı = `tween` ileri lunge + geri, hasar = kısa kırmızı flash + shake, ölüm = scale→0 + fade + toz partikülü.
- Birim üstünde **stat plakası** (3 rakam) — `Label3D` ya da SubViewport UI, kamera'ya billboard.

### 16.6 VFX & feedback (audio-forward + görsel)
- **Damage number:** `Label3D`, billboard, spawn'da scale-pop (`0→1.3→1`) + yukarı float + fade. Kritik = daha büyük + sarı-turuncu + hafif ekran shake.
- **Kritik Hit:** hedefte turuncu emissive burst + "Critical Hit" etiketi (screenshot'taki gibi).
- **Vuruş çizgisi:** ranged için beyaz trail (Line3D / mesh trail).
- **Statü ikonları:** birim altında minik ikon şeridi (Zehir yeşil damla, Yanık alev, Sersem yıldız).
- **Pus atmosferi:** ekran kenarlarından içeri sızan mor/gri sis (fullscreen shader veya GPUParticles), Pus Basıncı fazında yoğunlaşır.

### 16.7 Ortam (WorldEnvironment)
- **Glow AÇIK** (emissive pop için şart) — bloom threshold ayarlı ki sadece emission parlasın.
- Ambient düşük, karanlık; playfield'ı **1 anahtar DirectionalLight** (sıcak, üstten) + hafif fill aydınlatır.
- SSAO opsiyonel (bloklar arası derinlik için hoş, perf'e bak).
- Renk paleti: koyu lacivert boşluk + sıcak çim yeşili/toprak + accent kırmızı (tehlike) + mor (pus/boss).

### 16.8 Depth sort / iso okunabilirlik
- Ortografik + gerçek 3D olduğundan Godot depth'i doğru sıralar (2D iso'daki manuel y-sort derdi **yok** — 3D'nin avantajı).
- Yüksek bloklar arkadakini kapatabilir → kamera rotasyonu (Q/E) + yarı-saydam occluder shader'ı (kameraya yakın blok fade) ile çöz.

---

## 17. GODOT 4 MİMARİSİ

### 17.1 Katman ayrımı (KATI — cocktail projesindeki gibi)
```
LOGIC (saf, deterministik, motordan bağımsız)
   CombatResolver  → CombatEvent[] üretir (RNG yok / sadece seed'li)
   RunState / GarrisonState (veri)
        │  (sadece veri + sinyal)
        ▼
PRESENTATION (görsel/ses)
   CombatPresenter → CombatEvent[]'i tween/particle/audio ile oynatır
   UI katmanı → RunState'i okur, girdi yollar
```
**Kural:** Presentation, Logic'i okur; Logic, Presentation'ı **hiç bilmez**. Test edilebilirlik + determinizm bundan gelir.

### 17.2 CombatResolver kontratı
```
CombatResolver.resolve(board_state, seed) -> CombatResult
  board_state: birimler + konumlar + engeller + relic/emir efektleri
  return:
    events: Array[CombatEvent]   # sıralı, oynatılabilir kayıt
    kazanan: enum{PLAYER, ENEMY}
    final_state: BoardState

CombatEvent örnekleri:
  {t:"ACTIVATE", unit_id}
  {t:"MOVE", unit_id, from, to}
  {t:"ATTACK", src, dst, raw, final, crit:bool}
  {t:"STATUS", target, status, stacks}
  {t:"DEATH", unit_id}
  {t:"TRAIT_PROC", unit_id, trait_id}
  {t:"ROUND_START", round}
```
Presenter bu listeyi sırayla, hız çarpanıyla, animasyonla oynatır. "Savaşı atla" = event'leri anında uygula, animasyonsuz.

### 17.3 Veri = Resource (data-driven, kod ≠ içerik)
Tüm içerik `.tres` Resource dosyaları; kod jenerik motor. Yeni birim/tabya/relic eklemek = yeni .tres, kod değişmez.
```
res://data/pieces/*.tres     → PieceData
res://data/traits/*.tres     → TraitData
res://data/relics/*.tres     → RelicData
res://data/rumors/*.tres     → RumorData
res://data/orders/*.tres     → OrderCardData
res://data/enemies/*.tres    → EnemyData
res://data/bosses/*.tres     → BossData
res://data/events/*.tres     → EventData
res://data/biomes/*.tres     → BiomeData (tile mesh/renk seti)
res://data/facilities/*.tres → FacilityData
```

### 17.4 Autoload (singleton)
- `Database` — tüm .tres'i açılışta yükler, id→resource sözlüğü.
- `GameState` — aktif RunState + GarrisonState, kaydet/yükle.
- `RNG` — **seed'li** RandomNumberGenerator, tek kaynak. Savaş içi kullanılmaz.
- `EventBus` — global sinyaller (UI ↔ state gevşek bağ).
- `AudioDirector` — sfx/müzik yönetimi.

### 17.5 Sahne ağacı (yüksek seviye)
```
Main
├─ Autoloads (Database, GameState, RNG, EventBus, AudioDirector)
├─ ScreenManager
│   ├─ GarrisonScreen
│   ├─ MapScreen (düğüm haritası)
│   ├─ BattleScreen
│   │   ├─ CameraRig → Camera3D (ortho)
│   │   ├─ WorldEnvironment (glow on)
│   │   ├─ DirectionalLight3D + fill
│   │   ├─ BoardRoot
│   │   │   ├─ TileGrid (MultiMesh bloklar)
│   │   │   ├─ GridOverlay (emissive decal/mesh)
│   │   │   └─ Units (PieceView node'ları)
│   │   ├─ VFXLayer (particles, damage numbers)
│   │   ├─ DeploymentUI (bölük, mevzi, emir eli)
│   │   └─ CombatPresenter
│   ├─ EventScreen (narrative)
│   └─ ShopScreen
└─ TransitionLayer
```

### 17.6 Kaydetme
- `RunState` her düğümde otomatik kaydedilir (kaldığı yerden devam).
- `GarrisonState` her meta değişimde kaydedilir.
- Format: `ResourceSaver` veya JSON. Seed saklanır (determinizm + debug replay).

---

## 18. DUMMY ASSET PLANI (önce mantık, sonra sanat)

Amaç: sıfır sanatla oynanabilir dikey dilim. Her görsel yerine primitif:

| Gerçek asset | Dummy karşılığı |
|---|---|
| Kübik zemin blokları | `BoxMesh` (1×h×1), biome başına düz renk `StandardMaterial3D` |
| Yükseklik | Box'ın `y` scale/offset |
| Grid overlay | Tile-top ince box'a yeşil/kırmızı emissive material |
| Birimler | Renkli `CapsuleMesh` (MELEE=kırmızı, RANGED=mavi, SUPPORT=yeşil) veya billboard quad |
| Birim stat plakası | `Label3D` "3/10/4" |
| Tabya/relic/statü ikonu | game-icons.net placeholder VEYA renkli `ColorRect` + harf |
| Damage number | `Label3D`, pop tween |
| Boss | Büyük gri `BoxMesh` + kırmızı emission |
| VFX | Godot built-in `GPUParticles3D` default |
| Ses | Kenney/freesound CC0 tek "click/hit/death" seti |

**Kritik:** dummy'de bile toon shader + outline + ortho kamera + glow **açık** olmalı — çünkü asıl kimlik shader'da, mesh'te değil. Dummy renkli kapsüller bile "PUS" gibi görünmeli. Şablon look'un %70'i: ortho kamera + toon band + siyah outline + emissive grid + koyu lacivert bg.

---

## 19. UI / UX SPEC (deployment ekranı — en önemli ekran)

- **Alt bar:** bölük (deploy edilebilir birimler, mevzi maliyeti rozetli), sürükle→grid'e bırak.
- **Sol/üst:** Mevzi (AP) sayacı, Kumandan seviyesi, Altın/Ün.
- **Emir eli:** ekranın altında 3 kart, tıkla-oyna.
- **Düşman telegraph:** düşman birimlerinin üstünde niyet ikonu + hedef tile kırmızı vurgu.
- **Birim tooltip:** hover'da tam stat + tabya açıklaması + "şu an ×Kat / +Güç ne" **canlı hesap gösterimi** (Balatro'nun anlık skor breakdown'u gibi — bu şart, build'i öğreten şey bu).
- **SAVAŞ butonu:** büyük, sağ altta, basınca onay yok (geri dönüşsüz, ama savaş hızlandırılabilir/atlanabilir).
- **Combat izleme kontrolü:** 1x / 2x / atla.

**Erişilebilirlik/okunabilirlik:** stat renkleri sabit (SALDIRI turuncu, CAN kırmızı, HIZ mavi). Statü ikonları renk+şekil (renk körü ayrımı).

---

## 20. SES (audio-forward)

- Deployment: sakin ambient + pus rüzgarı.
- Birim yerleştirme: tok "clunk".
- SAVAŞ başı: davul/gerilim yükselişi.
- Vuruş/kritik/ölüm: katmanlı sfx (kritik = daha derin + hafif rezonans).
- Statü: her statünün imza sesi (Zehir "fışş", Sersem "ding").
- Boss: imza motif.
- Zafer/yenilgi jingle.
Kaynak: freesound.org, Kenney audio, itch.io CC0 (prototip). Feedback'in yarısı sesle taşınır — dummy'de bile sfx bağla.

---

## 21. DENGE / SAYI HEDEFLERİ (ilk pass)

- Başlangıç Mevzi: 6. Kumandan seviyesi başına +1 (max ~10).
- Emir eli: 3. Deste başlangıç: 5 kart.
- Bölge başı düğüm: 10–14. Savaş:elit:olay:bina ≈ 5:1:2:2 + 1 Han + 1 Boss.
- Boss CAN: B1 ~80, B2 ~140, B3 ~220.
- Ortalama savaş süresi (izleme): 20–40 sn (2x'te 10–20).
- Hedef Kat tavanı (build tepe): ×8–×15 civarı bir "patladı" hissi; ötesi relic+rumor+füzyon kombosu ister.

---

## 22. MİLESTONE MERDİVENİ

- **M0 — Dummy dikey dilim (ÖNCE BU):** ortho kamera + toon shader + outline + 1 biome kübik grid + 4 birim (kapsül) + Güç×Kat hasar formülü + CombatResolver→Presenter oynatma + 1 savaş (deploy→savaş→sonuç). Sıfır sanat, tam mantık. **Buradan başla.**
- **M1 — Savaş derinliği:** tabya sistemi (§5 örnek 12 tabya), statü efektleri, zemin/engel, telegraph, sudden death.
- **M2 — Run iskeleti:** düğüm haritası, ödül, dükkan, Altın, Emir destesi + deckbuilding, relic (10).
- **M3 — İçerik + meta:** Han/Söylenti, olay kartları, füzyon/sürgün, Garnizon + Anı, 1. boss.
- **M4 — 3 bölge:** 3 boss, düşman havuzu, biome görselleri (asset girer), denge geçişi.
- **M5 — Cila:** VFX, ses, UI cila, save/replay, Steam entegrasyon, tutorial.

**Her milestone sonunda oynanabilir olmalı.** Sonraki milestone öncekini bozamaz.

---

## 23. SCOPE KİLİDİ (aşılmaz sınırlar)

**v1'e GİRENLER:** yukarıdaki her sistem, 3 bölge, ~100 birim, ~100 tabya, 30 relic, 20 Emir Kartı, Söylenti, Garnizon meta, deterministik otomatik savaş, tek-oyunculu.

**v1'e GİRMEYENLER (net ret):**
- ❌ Multiplayer / PvP.
- ❌ Prosedürel harita üretimi (elle tasarlı düğüm şablonları yeter).
- ❌ Serbest hareketli gerçek zamanlı savaş (savaş her zaman otomatik + turn-based).
- ❌ Diyalog ağacı / voice-over (olay kartları kısa metin).
- ❌ İkinci Kumandan sınıfı (v1 tek Kumandan; ikinci = post-launch).
- ❌ Manuel savaş kontrolü (tasarım sütunu #1'i ihlal eder).
- ❌ Yeni özellik, başka özelliği kesmeden girmez.

**Onur pattern notu:** Geniş ideation eğilimi burada frenlenir. Bu doküman TEK oyun. Yeni fikir gelirse → ayrı dosya, bu spec'e sızmaz. M0'ı bitirmeden M2+ konuşulmaz.

---

## 24. AÇIK KARARLAR (senin verecekklerin)

1. **Birim görseli:** billboard 2D sprite mi, low-poly 3D mi? (M4'te sanat girerken; M0 kapsülle geçilir.)
2. **Grid boyutu kesinleşsin mi:** 6×5 önerildi — 5×5 mi 6×5 mi? (M0 test edince karar.)
3. **Timeout felsefesi:** Pus Basıncı (önerilen) yeter mi, yoksa hard round-limit + oyuncu kaybı mı?
4. **Ad:** PUS kalsın mı, alternatif mi? (Steam sayfası için erken karar iyi olur.)

Bunları M0 çalışır çalışmaz netleştir; şimdilik önerilen varsayılanlarla ilerle.
