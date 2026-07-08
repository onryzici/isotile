# Master of Piece — Mekanik Araştırması + İş Planı

> Amaç: Master of Piece'in (I M GAME, EA çıkışı 4 Şub 2026, $14.99, Very Positive) **gerçek** mekaniklerini kaynaklardan doğrulayıp, senin oyunun (çalışma adı PUS) için Claude Code'a verilebilecek **fazlı iş planına** çevirmek.
>
> Bu doküman iki parçadır:
> **A. ARAŞTIRMA** — doğrulanmış mekanikler + benim ilk spec'imdeki hatalar + inceleme dersleri.
> **B. İŞ PLANI** — düzeltilmiş, fazlı, Claude Code'a hitap eden build planı.

---

# A. ARAŞTIRMA (doğrulanmış)

## A.1 Künye
- **Stüdyo:** I M GAME / I M fine (Kore). Site: im-game.co.kr
- **Çıkış:** 4 Şubat 2026, Steam Early Access. Fiyat $14.99.
- **Skor:** ~166–182 inceleme, %88–89 olumlu (Very Positive).
- **EA içeriği:** 4 bölge, 8 boss (bölge başına 2), 2 kumandan, outpost'lar, geniş relic/trait havuzu.
- **İçerik hacmi:** 100+ paralı asker & trait, 30 relic, 20 kart, 30 achievement, 13 dil.
- **EA planı:** 6 ay–1 yıl; 1.0'da yeni içerik + optimizasyon.
- **Tür etiketleri:** Turn-Based Strategy, Tactical, Roguelike Deckbuilder, Auto Battler, Board Game, Tabletop, Grid-Based Movement, Medieval, Dark Fantasy, Isometric, Choices Matter, Atmospheric.

## A.2 ÇEKİRDEK SAVAŞ (gerçek hali — dikkat, benim ilk varsayımımdan farklı)

**Hedef: düşman bayrağını/kampını yık.**
- Arena ızgaralı, izometrik. Karşı uçta **düşman bayrağı/kampı** var; kendi CAN'ı var, hatta kendisi de saldırır (screenshot'taki "16" ve "82" hex'leri bayrak canlarıdır).
- Kazanmak = düşman bayrağını **önce** yıkmak. Bir tür Stratego × lane-push auto-battler.

**Bayrak CAN'ı tüm run boyunca KALICI.**
- Senin kampının da CAN'ı var ve **savaşlar arası yenilenmiyor**. Sıfıra inerse run biter. Bu, Slay the Spire'daki oyuncu HP'sinin karşılığı — asıl roguelite gerilimi burada. (Kaynak: The Geekly Grind)

**Tur-tur oynanış (tek-deploy-izle DEĞİL).**
1. Her turun başında **Aksiyon Puanı (AP)** harcarsın:
   - Rezervden yeni birim ızgaraya sürükle,
   - VEYA mevcut birimleri **yana / geriye** taşı (zayıf noktayı tak, push kur),
   - VEYA **Kumandan yeteneği** aktive et.
2. Sonra tüm birimler **HIZ sırasına göre otomatik** hareket eder: düşman bayrağına doğru ilerler, önündekine saldırır.
3. Sonraki tur → tekrar AP harca → tekrar otomatik akış. Bayraklardan biri düşene kadar.

**Birim statları:** SALDIRI (attack), CAN (health), HIZ (speed → aksiyon sırası). Her birim **≤2 trait** taşır.

**Savaşı belirleyen katmanlar:** trait'ler, engeller, **bayrak canı**, statü efektleri. Tek yanlış konumlama akışı çevirir.

**Hız / his:** İncelemeler savaşların **hızlı ve zaman-dostu** olduğunu vurguluyor (oyuncu zamanına saygı).

## A.3 KADRO = DESTE (deckbuilding'in gerçek şekli)
- Kart yerine **birim (piece)** toplarsın. "Deste" dediği şey **kadronun kendisi**.
- Her birim ≤2 trait; trait'ler savaşta tetiklenir → sinerji/combo.
- Kadro run içinde büyür: yeni birim al, mevcutları geliştir.

## A.4 "20 KART" GERÇEĞİ (önemli düzeltme)
- Oynanan bir **kart eli YOK**. Deckbuilding tamamen roster üzerinden.
- O "20 kart" = **yol üstündeki dallanan olay kartları** (random card events): kısa hikaye + seçim → sonuç.
- Aktif oynama elemanı = **kumandan yetenekleri** (her tur kullanılabilir).
- **Senin fırsatın:** Gerçek MoP'ta "oynanan kart eli" yok. Benim ilk spec'imdeki **Emir Kartları** senin özgün farklılaştırıcın olabilir — ama bunun MoP'ta OLMADIĞINI bilerek bilinçli koy.

## A.5 KUMANDAN
- Oyuncu bir kumandandır; savaşta her tur **yetenek** kullanır (destek/buff/hasar). EA'da **2 kumandan** var, farklı oyun stilleri.
- Kumandan yeteneği AP veya cooldown'a tabi (aktif karar katmanı).

## A.6 HARİTA / RUN YAPISI
- Dünya haritası **kare ızgaralı**, dallanan yollar (Slay the Spire mantığı).
- **4 bölge (region)**; her bölgenin sonunda boss. Bölge başına 2 boss → toplam 8.
- Düğüm tipleri: **Savaş**, **Dükkan**, **Outpost** (bina olayları), **Random Olay (kart)**, **Boss**.
- Bölge içinde rota seçimi = risk/ödül dengesi.

## A.7 BİNA / OUTPOST OLAYLARI (dükkan katmanı)
Bölgeler boyunca ziyaret edilen binalar:
- **Trait birleştir** (fuse): iki birimin trait'lerini birleştir.
- **Birim sürgün** (banish): işe yaramaz birimi kadrodan çıkar (deste inceltme).
- **Relic / item satın al.**
- (Oyuncular: trait birleştirirken **hangi trait'in korunacağını seçmek** istiyor — şu an seçtiremiyor. Fırsat.)

## A.8 TAVERN + SÖYLENTİ (rumor)
- Birim zafer biriktirdikçe **ün (renown)** kazanır; efsane askerler gibi hakkında **söylenti** yayılır.
- **Tavern**'de söylenti yayarsın → trait/upgrade'den ayrı, özel yetenekler → takım sinerjisini büyütür.

## A.9 RELIC (yadigar)
- 30 relic. Global run pasifleri. Bina/boss/ödülden gelir. Kumandan + trait + relic üçlüsü build motoru.

## A.10 GARNİZON (meta ilerleme)
- Başarısız sefer = kayıp değil, **tohum**. Run'dan kazanılan kaynakla **Garnizon**'da tesis inşa edilir.
- Tesisler kalıcı upgrade verir: daha çok item taşıma, daha güçlü başlangıç birimleri, vb.
- "Failure is not the end" = her ölüm bir sonraki run'ı güçlendirir.

## A.11 SANAT DİLİ (doğrulanmış)
- **İzometrik**, gotik-ortaçağ sunum.
- Birimler = **boyanmış, oyulmuş ahşap minyatürler** — grid üstünde zıplayan, masaüstü savaş oyunu (tabletop) hissi.
- Karanlık fantezi paleti; "Kara Sis / Black Fog" atmosferi.
- Yani senin §16'daki toon + outline + kübik iso yaklaşımın **doğru rotada**; sadece "ahşap minyatür + kaide" materyalitesini hedefle (bkz. önceki mesajdaki karakter brief'i).

## A.12 İNCELEME DERSLERİ (senin fırsat listen)
**Övülenler:**
- Hızlı, zaman-dostu savaşlar.
- Konumlama + trait yönetimi oyuncu ajansı verir.
- Sanat/atmosfer güçlü.
- EA'ya göre bol içerik, tekrar oynanabilirlik.

**Şikayetler (= senin farklılaşma alanların):**
1. **Tekrara düşme** (en büyük risk): birkaç run sonra aynı hissettiriyor. → Build diverjansını, sinerji çeşitliliğini ve unlock temposunu güçlü tut.
2. **Denge dalgalı**: bazı bölümler fazla kolay, **bazı boss mekanikleri adaletsiz/cezalandırıcı** hissediyor. → Boss niyetlerini net **telegraph** et, coin-flip'ten kaçın, her boss için "okunabilir çözüm" bırak.
3. **UI: çift-tıklama** derdi, akıcı olmayan kontroller. → **Tek-tık**, net feedback, hover'da canlı hesap.
4. **Trait merge seçimi yok**: hangi trait korunacak seçtirilmiyor. → Sen seçtir.
5. **Zırh/ekipman katmanı yok**: oyuncular istiyor. → Opsiyonel ekipman/zırh katmanı ekle (farklılaştırıcı + tekrar-oynanabilirlik).

---

# B. İŞ PLANI (Claude Code'a verilecek)

Aşağısı doğrudan Claude Code'a hitap eden, düzeltilmiş mekaniklere oturan fazlı plandır. Godot 4.3+, Forward+. Katı **Logic/Presentation ayrımı** ve **data-driven Resource** yaklaşımı (önceki PUS_CLAUDE.md §17 geçerli, aşağıdaki düzeltmelerle).

## B.0 İLK 5 DÜZELTME (önceki PUS_CLAUDE.md'ye uygula)
1. **Zafer koşulu:** "düşmanı yok et" → **"düşman bayrağını yık"**. Bayrak = CAN'lı, saldırabilen özel birim; ızgaranın karşı ucunda.
2. **Bayrak CAN'ı KALICI:** `RunState.player_flag_hp` savaşlar arası taşınır, yenilenmez, 0 = game over. `enemy_flag_hp` her savaşta o savaşın hedefi.
3. **Tur-tur deployment:** tek deploy değil. Her tur: AP harca (deploy / yana-geri taşı / kumandan yeteneği) → otomatik hareket fazı → tekrar. Birimler düşman bayrağına doğru **ilerler**.
4. **Kumandan yeteneği** aktif katman (AP/cooldown). Emir Kartları opsiyonel özgün ek (MoP'ta yok).
5. **Trait merge'de oyuncu hangi trait'in kalacağını SEÇER.** Çift-tık YOK, tek-tık + hover canlı hesap.

## B.1 FAZ 0 — Deterministik Savaş Çekirdeği (dummy, sanatsız)
**Çıktı:** Ortho izo kamera + toon shader + 1 dummy grid + bayrak-yıkma savaşı, tur-tur, otomatik hareket.

Görevler:
- `CombatResolver` (saf, seed'li, motordan bağımsız) → `CombatEvent[]` üretir.
  - Board: NxM ızgara, oyuncu bayrağı alt uç, düşman bayrağı üst uç.
  - Tur döngüsü: `deploy_phase()` (girdi bekler) → `resolve_phase()` (HIZ sırası, ilerle+saldır) → tekrar.
  - İlerleme kuralı: her birim aktivasyonda düşman bayrağına doğru 1 tile ilerler; önünde düşman/engel varsa saldırır.
  - Bitiş: bir bayrak CAN ≤ 0.
- `CombatPresenter` → event'leri tween/particle ile oynatır (1x/2x/atla).
- Hasar formülü: `(SALDIRI + ΣGüç) × ΠKat − Zırh` (Balatro Güç×Kat, senin imzan).
- **Dummy asset:** BoxMesh zemin, renkli Capsule birim, Label3D statlar, büyük Box = bayrak.
- **Render kimliği açık:** ortho kamera, toon band, siyah outline, glow, koyu bg — dummy'de bile.

**Kabul kriteri:** 2 kadro dizip savaş başlat → birimler ilerler → bir bayrak düşer → sonuç. Aynı seed = aynı sonuç.

## B.2 FAZ 1 — Savaş Derinliği
- Trait sistemi (data-driven `TraitData`): KONUM / SİNERJİ / TETİK / AURA / STATÜ. 10–12 örnek trait.
- Statü efektleri: Zehir, Yanık, Sersem, Kök, Zırh, Kalkan, Güçlenme, Lanet.
- Engeller/zemin: Duvar, Lav, Diken, Yükselti, Pus Tile, Kutsal Zemin.
- **Kumandan** + her-tur yeteneği (AP/cooldown). En az 1 kumandan.
- Bayrak birimi: CAN + basit saldırı + (boss'larda) niyet telegraph'ı.
- Sudden death (Pus Basıncı) opsiyonel — MoP'ta net değil, dengeye göre karar.

**Kabul kriteri:** trait sinerjisi hasarı gözle görülür katlıyor; hover'da "şu an ×Kat / +Güç" canlı breakdown görünüyor.

## B.3 FAZ 2 — Run İskeleti + Kalıcı Bayrak
- Dallanan **düğüm haritası** (Savaş/Dükkan/Outpost/Olay/Boss).
- `RunState`: kadro, relic'ler, **kalıcı bayrak CAN'ı**, altın, ün, seed. Her düğümde autosave.
- Ödül akışı: savaş sonu → altın / yeni birim / relic seçimi.
- **Dükkan/Outpost:** birim/relic/item al, **trait birleştir (oyuncu seçimli)**, birim sürgün.
- Olay kartları (`EventData`): dallanan seçim → sonuç.

**Kabul kriteri:** 1 bölge baştan sona oynanıyor; bayrak CAN'ı savaşlar arası taşınıyor; 0'da game over.

## B.4 FAZ 3 — Meta + Sosyal Katman
- **Tavern + Söylenti**: ün biriktir → söylenti kazı → kalıcı-run pasif.
- **Garnizon**: sefer sonu kaynak → tesis inşa → kalıcı meta upgrade.
- Relic havuzu (≥15) + build-around relic'ler.
- İlk **boss** (net telegraph'lı, adaletli çözümlü — MoP'un "adaletsiz boss" şikayetine cevap).

**Kabul kriteri:** kaybettikten sonra Garnizon'da somut kalıcı ilerleme; ikinci run gözle görülür farklı.

## B.5 FAZ 4 — İçerik Genişleme
- 4 bölge, 8 boss (bölge başına 2). Her bölge farklı biome + mekanik twist.
- Birim havuzu ≥40 (etiket/sinerji ailesiyle), trait ≥40, relic 30, olay kartı 20.
- 2. kumandan.
- **Sanat girişi:** ahşap-minyatür + kaide materyalitesi (bkz. karakter brief). Biome tile setleri.
- **Anti-tekrar tedbirleri** (MoP'un #1 şikayeti): her bölgede mekanik değişkenlik, unlock temposu, "bu run şu build'e itiyor" çeşitliliği.

## B.6 FAZ 5 — Cila + Steam
- VFX/ses geçişi (audio-forward feedback).
- **UI cila:** tek-tık, hover canlı hesap, hız kontrolü, okunabilirlik (renk körü statü ayrımı).
- **Opsiyonel farklılaştırıcılar** (MoP'ta yok, sende olabilir): zırh/ekipman katmanı, Emir Kartı destesi, zorluk seçenekleri.
- Save/replay (seed), Steam achievement, tutorial.

## B.7 MoP'A GÖRE FARKLILAŞMA HEDEFLERİ (kopya değil)
Bu bir klon değil; MoP'un zayıf noktalarını hedef al:
1. **Tekrara karşı:** daha keskin build diverjansı (Balatro Güç×Kat motorunu MoP'tan agresif kullan → "patladı" anları).
2. **Adaletli boss:** her boss niyetini deployment'ta tam telegraph et, coin-flip yok.
3. **Akıcı UI:** tek-tık, canlı skor breakdown (Balatro tarzı öğreten UI).
4. **Trait agency:** merge'de oyuncu seçer.
5. **Ekipman katmanı:** opsiyonel zırh/item ile ekstra derinlik.
6. **Türkçe/kültürel kimlik:** MoP jenerik ortaçağ; sen Türkçe adlandırma + atmosferle ayrış (senin doğal alanın).

## B.8 SCOPE KİLİDİ (değişmez)
- v1: 4 bölge / 8 boss / 2 kumandan / ~40+ birim / 30 relic / tek oyunculu / deterministik otomatik savaş.
- GİRMEYEN: multiplayer, manuel savaş kontrolü, prosedürel harita (elle şablon yeter), voice-over.
- Faz sırası atlanmaz: Faz 0 bitmeden Faz 2+ konuşulmaz. Yeni fikir → ayrı dosya, bu plana sızmaz.

---

# C. KAYNAKLAR
- Steam mağaza sayfası (I M GAME) — künye, içerik hacmi, EA notu, tür etiketleri.
- The Geekly Grind, "Master of Piece Early Access Impressions" (12 Şub 2026) — bayrak-yıkma hedefi, kalıcı kamp canı, tur-tur deploy, Stratego benzetmesi, ahşap-minyatür sanat.
- gamepressure.com oyun veritabanı — izometrik, bayrak hedefi, HIZ=aksiyon sırası, tavern/söylenti, oyuncu övgü/şikayet listesi.
- MobyGames — stat/trait/engel/bayrak-canı doğrulaması.

> Not: Yukarıdaki tüm mekanikler kendi ifademle özetlenmiştir; oyun mekanikleri fikirdir, kopyalanabilir. Klonlama değil, **öğrenip farklılaşma** hedeflenir.
