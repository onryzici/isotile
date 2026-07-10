# AĞIL — Ekran & Sistem Bible (Master of Piece referanslı)

> Bu doküman, Master of Piece'in (I M GAME) **doğrulanmış** yapısını senin oyununa uyarlar. Kaynak: Steam, Button Musher/Phrasemaker detaylı incelemesi, MobyGames, gamepressure, itch.io ve ekran görüntüleri.
> **Klon değil.** MoP'un iskeletini alır, kuzu-köyü kimliğiyle yeniden giydirir.
>
> **Önceki dosyalar:** PUS_CLAUDE.md (çekirdek mimari) + MoP_ARASTIRMA_VE_ISPLANI.md (iş planı) hâlâ geçerli. Bu dosya onların üstüne **ekran/UI/içerik** katmanını koyar. "PUS" adı burada **AĞIL** ile değişir.

---

## 0. KİMLİK

- **Ad:** **AĞIL** (koyunların barındığı ağıl = hem yuvanız hem oyunun kalbi).
- **Tema:** Kara Pus dünyayı yutmuş. Kuzu-halk (koyun insanları) köyleri pusun içinde kaybolmuş. Sen bir **Çoban-Kumandan**sın; bir **sürü** (paralı asker = koç/kuzu savaşçılar) toplayıp pusa dalıyor, **Kurt Tarikatı**'nı (Dragon Cult karşılığı) ve pusun ardındaki sırrı (bir tür **Çoban Yıldızı** / kayıp kutsal emanet) araştırıyorsun.
- **Ton:** Grim-cute. Darkest Dungeon karanlığı + kuzuların masumiyeti kontrastı. Kurt vs kuzu doğal düşmanlığı tüm sinerji/etiket sistemine oturur.
- **Sanat:** İzometrik, cel-shading, kalın karikatürel siyah outline, el boyaması dark-fantasy, halftone/dither pus efekti (aşağıda §15 detaylı).

---

## 1. HİKAYE ANLATISI

**Dünya kurgusu.** Yıllar önce gökten inen **Kara Pus**, ışığı ve hafızayı yutarak köyleri birbirinden kopardı. Pusun içinde **Kurt Tarikatı** türedi — bir zamanlar çoban olan, şimdi pusa tapan yaratıklar. Sürüler dağıldı, ağıllar boş kaldı. Sen, son ayakta kalan **Ağıl**'ın çobanısın: kalan kuzu-halkı toplar, pusun içinden geçen bir **sefer** düzenler, hem hayatta kalır hem de pusun kaynağındaki **Çoban Yıldızı**'nın sırrını çözersin.

**Anlatı yapısı (MoP'un Archive/lore mantığı gibi):**
- Ana hub'daki **Arşiv/Kütüphane**'de lore parça parça açılır (Kara Pus nasıl geldi, Kurt Tarikatı kim, Çoban Yıldızı ne).
- Sefer sırasında **Kart Olayları** (§5) kısa hikaye anları verir: köylüler, direnişçi kuzular, tarikat rahipleri. Ekran görüntüsündeki "Allied victory — Expedition + Resistance drove out Dragon Cult priests" tam bu tarz; sende: *"Sürü ile Direniş birlikte Kurt rahiplerini kovdu; köylü kuzular ağıla minnettar."*
- Her bölge sonu **boss** = bir Kurt Tarikatı büyüğü; yenince lore ilerler.
- 4. bölge bossu düşünce sefer biter → asıl oyun (Ordeal zorlukları) başlar.

**Frakisyonlar:**
- **Sürü / Sefer (Expedition):** senin bölüğün.
- **Direniş (Resistance):** pusa direnen bağımsız kuzu grupları — bazı kart olaylarında müttefik.
- **Kurt Tarikatı (Cult):** düşmanlar + bosslar.
- **Köylüler/Çiftçiler:** nötr, olaylarda ödül/risk kaynağı.

---

## 2. ANA HUB — "AĞIL MEYDANI" (Departure Ground eşdeğeri)

MoP'ta buna **Departure Ground** deniyor; Darkest Dungeon kasabası gibi. Sen buna **Ağıl Meydanı** de. Sefere çıkmadan önce buradasın. Binaya tıklayınca ne olur:

| Bina / Buton | Konum | Tıklayınca |
|---|---|---|
| **Sefere Çık (Start Journey)** | Merkez / ateş | Sefer başlar → yeni journey map üretilir → ilk savaş. |
| **Ağıl / Campsite (Garnizon)** | Sol | **Meta ilerleme.** Kaynak harcayıp kalıcı tesis inşa/geliştir (§12). |
| **Lonca (Guild)** | Yakın | Başlangıç ikilisini (2 merc), başlangıç relic'ini ve Kumandan yeteneğini **seç/değiştir** (Kumandan ilerledikçe açılır). |
| **Arşiv / Kütüphane** | Sağ karşı | Lore oku, geçmiş seferleri değerlendir, genel istatistikler. Kara Pus'un hikayesi burada. |
| **Onur Salonu (Hall of Fame)** | Karşı | Başarımlar (achievement). **Güzel dokunuş:** başarımlar binanın içinde fiziksel obje olarak belirir (MoP'taki gibi — kopyala bu fikri). |
| **Sözleşme (Contract)** | Üst sekme | Bounty/challenge sistemi (ekran görüntüsündeki "Contract" sekmesi). Özel hedefli seferler → ekstra ödül. |
| **Menü (☰)** | Sağ üst | Ayarlar, kaydet, çıkış. |

**Kumandanlar (Commanders):** MoP'ta Sigmund (tank), Livius (agresif), Serila (3.). Sende en az 2 kumandan, farklı sürü havuzu + oyun stili:
- **Çoban Zigment** (tank/savunma — kalkan koç sürüsü) — *başlangıç kumandanı, tutorial bununla.*
- **(2. kumandan)** (agresif — boynuz/hücum) — Zigment ile sefer bitince açılır.
- Her kumandanın ~28 kendine ait merc'i var (MoP sayısı). Sende hedef: kumandan başına 20+.

**Ekran görünümü:** İzometrik küçük bir ada (senin campsite screenshot'un gibi ama "meydan"). Ortada şenlik ateşi + çoban portresi. Sol üstte kumandan portresi (elmas çerçeve), adı, Exp bar, seviye bandı (kırmızı elmas rozet). Üstte para birimleri.

---

## 3. İLK OYUN — TUTORIAL (yeni oyuncu akışı)

MoP: yeni oyuncu ilk seferini sabit kumandanla (Sigmund) başlatır ve **zorunlu bir tutorial savaşına** girer. Sende birebir mantık:

**Tutorial akışı (adım adım, ilk açılışta zorlanır):**
1. **Cold open:** kısa bir anlatı kartı — Kara Pus, boş ağıl, "son sürüyü topla." (3-4 cümle, atlanabilir.)
2. **Ağıl Meydanı'na iniş** — kamera meydanı gösterir, tek tıklanabilir hedef parlar: **Sefere Çık**. (Diğer binalar tutorial'da kilitli/soluk.)
3. **Tutorial savaşı** (elle yönlendirmeli):
   - **Adım A:** "Bir kuzu-savaşçı yerleştir" → grid'de geçerli tile'lar yeşil parlar, sürükle-bırak öğretilir.
   - **Adım B:** "SAVAŞ / Turu bitir" → birimler HIZ sırasıyla ilerler, düşmanla çarpışır. Kamera hasar sayısını vurgular.
   - **Adım C:** "Düşman bayrağını gör" → karşı uçtaki bayrak + canı işaretlenir. "Onu yık = kazan" mesajı.
   - **Adım D:** yeni tur → "yeni birim koy / mevcut birimi yana-geri taşı / Kumandan yeteneği kullan" üçü tek tek tanıtılır.
   - **Adım E:** düşman bayrağı düşer → zafer ekranı → ödül seçimi (1 merc) tanıtılır.
4. **İlk düğüm seçimi** → journey map açılır, düğüm tipleri tooltip'le tanıtılır.
5. Tutorial biter, kilitler açılır. Bir daha zorlanmaz (ayarlardan tekrar oynatılabilir).

**Tutorial tasarım kuralı:** Metin balonları kısa, tek cümle, işaret oku ile. Oyuncu yapana kadar ilerlemez (gated). MoP'un "double-click UI" şikayetini burada çöz: **tek-tık**, net highlight.

---

## 4. JOURNEY MAP (Sefer Haritası) + PUS FOG-OF-WAR

- **Yapı:** Dallanan düğüm haritası (Slay the Spire). 4 bölge, her bölge sonu boss.
- **Görsel:** İzometrik arazi, üstünde **halftone/dither "Kara Pus"** overlay (ekran görüntüsü 2'deki nokta-desenli karanlık). Keşfedilmemiş bölgeler pusla kaplı; ilerledikçe pus açılır (fog-of-war). **Bu senin imza shader'ın** (§15.3).
- **Düğümler:** ikonlu, yolla bağlı. Üstüne gelince tooltip (ne olduğu + ödül). Bazı düğümler bayrak-dayanıklılığı (flag durability) riski taşır.
- **HUD (harita üstü):** Bayrak dayanıklılığı (10/10), sefer altını (octagon gem), zar sayısı, sürü sayısı (sağ alt "8"), kumandan portresi/Exp.

---

## 5. DÜĞÜM TİPLERİ (tam liste — MoP'tan doğrulanmış, adapte)

Her düğümü kuzu temasıyla yeniden adlandır. Mekanik = MoP'un doğrulanmış hali.

| AĞIL adı | MoP karşılığı | Ne yapar |
|---|---|---|
| **Çatışma** | Enemy Battle | Normal savaş. Ödül: 1 kuzu-savaşçı (merc). |
| **Elit Çatışma** | Elite Battle | Zor savaş. Ödül: 1 Relic (Yadigar). |
| **Boss (Kurt Büyüğü)** | Boss Battle | Bölge sonu zorunlu. Düşman bayrağı = boss. Ödül: bir merc'in Trait'ini yükselt. |
| **Kart Olayı** | Card Event | Dallanan hikaye. Bayrak dayanıklılığını daha büyük ödüle **takas et**, ya da ödülsüz bayrak **onar**. |
| **Yadigar Dükkanı** | Relic Shop | 2 relic'ten 1'ini seç (§10). |
| **Nitelik Dükkanı** | Trait Shop | 2 trait'ten 1'ini bir merc'e ver. |
| **Şaman Çadırı** | Shaman's Hut | Bir merc'in statını yükselt — 2 seçenekten 1 (§9). |
| **Meydan / Talim (Saloon)** | Bootcamp | **Kumar:** merc'in base statını rastgele değiştir + Upgrade veya Rumor ver (§7). |
| **Kitapçı / Ozan** | Bookstore | Item (kullanılabilir eşya) al. |
| **Darağacı / Kurban Taşı** | Gallows | Bir merc'i infaz et → Trait'ini başka merc'e geçir (deste inceltme + trait taşıma). |
| **Gri Mezar** | Gray Grave | **Risk:** bayrak dayanıklılığı kaybet → nadir **artifact** kazan (§11). |
| **Sahra Revan (Field Infirmary)** | (heal düğümü) | Yaralı merc'leri iyileştir / bayrak dayanıklılığını onar (§8). |

**Not:** İleri bölgelerde yeni düğüm tipleri açılır (MoP sürpriz saklıyor). Sende de 1-2 bölge-özel düğüm sakla (ör. bölge 3'te "Pus Sunağı").

---

## 6. ZAR SİSTEMİ (nasıl çalışır + nasıl görünür)

MoP'ta zar **Windmill/Değirmen** tesisinden sefer başında verilir (2/4/6/8 adet) ve şu işlere yarar:

**Zarın işlevleri:**
1. **HIZ eşitliği çözümü (otomatik):** İki birim aynı HIZ'daysa, kim önce vurur → **zar atılır**. Bu otomatik, spendable değil.
2. **Kumar / yeniden çevirme (spendable):** Meydan (Saloon/Bootcamp), dükkanlar ve bazı olaylarda **zar harcayıp** sonucu yeniden çevirebilir (reroll) ya da ekstra seçenek açabilirsin. Zar = "şansı zorlama" kaynağı.
3. **Gri Mezar / risk düğümlerinde** ödül olasılığını iyileştirmek için zar bas.

**Sende öneri (net kural):** Zar = sefer boyu taşınan sayılabilir kaynak. Harcama noktaları: (a) dükkan/ödül reroll, (b) Saloon kumarında ekstra çevirme, (c) risk düğümünde olasılık artırma. Değirmen tesisi başlangıç zar sayısını artırır.

**NASIL GÖRÜNMELİ (kritik — Claude hep text yapıyor, burada 3D fiziksel zar iste):**
- **3D fiziksel zar** (D6), cel-shaded, kalın siyah outline, ahşap/kemik dokulu, üstünde oyulmuş pip'ler (nokta) — kuzu temasıysa pip yerine minik boynuz/toynak sembolü olabilir.
- **Atış animasyonu:** zar ekranın ortasında/tepside zıplar, döner, yavaşlar, sonuç yüzü yukarı gelir. `RigidBody3D` ile gerçek fizik ya da önceden hesaplanmış (deterministik!) sonucun sahte-fizik tween'i. **Determinizm için:** sonuç seed'den gelir, animasyon sadece gösterim.
- **UI yerleşimi:** sol/alt köşede küçük bir **zar tepsisi** (kalan zar sayısı + "Çevir" butonu). Reroll basınca zar tepsiden fırlar.
- **Feedback:** atışta tok "clack" sesi, sonuçta parlama; iyi sonuç yeşil, kötü kırmızı glow.
- **HIZ eşitliği anında:** savaş içinde iki birim arasında minik bir zar belirir, hızlı döner, kazananı işaretler (savaş akışını kesmeden).

---

## 7. MEYDAN / TALİM — "SALOON" (Bootcamp) DETAY

Senin "saloon" dediğin = MoP'un **Bootcamp**'i. Kumarhane/talim mantığı.

- **Ne yapar:** Seçtiğin bir merc'in **base statını rastgele değiştirir** (kumar — attack/health/speed yeniden dağılır) VE ona bir **Upgrade** ya da **Rumor** verir.
- **Neden riskli:** 2 upgrade sonrası statlar sadece burada değişebilir. İyi merc'i buraya sokmak ateşle oynamaktır — zar/altın harcayıp tekrar çevirebilirsin (§6).
- **Görsel:** İzometrik bir talim çadırı / meydan. İçeride bir zar masası, ateş, gölgeli figürler. Merc'i sürükleyip masaya koyarsın, zar atılır, yeni statlar "slot makinesi" gibi dönerek oturur. **Balatro tarzı canlı sayı animasyonu** — statlar dönerek değişir, oyuncu görür.
- **UI:** solda merc kartı (eski statlar), ortada zar/masa, sağda yeni statlar + "Kabul / Yeniden Çevir (zar harca)" butonları.

---

## 8. SAHRA REVAN — FIELD INFIRMARY DETAY

MoP'un çekirdek listesinde ayrı "infirmary" yok ama **bayrak-dayanıklılığı onarımı** kart olaylarıyla var; senin campsite screenshot'unda **haç-çadır (Lv1)** = revir binası. Sende bunu net bir **iyileştirme düğümü** yap (MoP'un eksiğini kapatır — oyuncular heal istiyor).

- **Ne yapar (2 seçenekten biri):**
  1. **Bayrak Onarımı:** flag durability +X geri kazan (sefer HP'si).
  2. **Sürü Bakımı:** yaralı/zayıf merc'leri tazele — savaşta ölmüş bir merc'i geri getir ya da bir merc'e küçük kalıcı buff.
- **Görsel:** İzometrik çadır, haç/toynak sembollü sancak, sıcak fener ışığı, yataklarda sargılı kuzu-savaşçılar, bir şifacı figürü. Sıcak turuncu glow (revirin "güvenli/iyileştirici" hissi).
- **UI:** iki büyük seçenek kartı (Bayrak / Sürü), maliyet (altın veya bedava), Onayla.
- **Tempo:** Bu düğüm nadir/az sayıda olsun ki bayrak-dayanıklılığı gerilimi korunsun.

---

## 9. ŞAMAN ÇADIRI — SHAMAN'S HUT DETAY

- **Ne yapar:** Bir merc'in **statını yükselt** — 2 seçenekten 1 (ör. "+2 Saldırı" ya da "+3 Can"). Her merc 2 kez upgrade alabilir (herhangi kombinasyon).
- **Görsel:** İzometrik şaman çadırı, kemik/tüy süsler, mor-yeşil büyülü glow, dumanlar, oturan kapüşonlu şaman figürü (kuzu temasıysa boynuzlu bir kuzu-şaman). Mistik ışık.
- **UI:** merc seç → 2 upgrade kartı belirir (ikonlu: kılıç+2 / kalp+3 / ayak+1) → seç → stat Balatro-tarzı canlı artışla oturur.

---

## 10. YADİGAR DÜKKANI — RELIC SHOP DETAY

- **Ne yapar:** 2 relic'ten 1'ini **seç** (bedava seçim; MoP mantığı). Relic = global sefer pasifi.
- **Görsel:** İzometrik dükkan/tezgah, raf üstünde parlayan emanetler, tüccar figürü (gizemli, kapüşonlu). Her relic bir kaide üstünde döner, emissive glow.
- **UI:** iki relic kartı (ikon + ad + açıklama), üstüne gelince detay tooltip, "Seç". Seçilen parlar, diğeri kaybolur.
- **Ekonomi:** bazı dükkanlar ücretli (altın), Yadigar Dükkanı bedava-seçim. Ayrı bir **satın alma** dükkanı (Kitapçı/Ozan) altınla item satar.

---

## 11. GRİ MEZAR — GRAY GRAVE DETAY

Ekran görüntündeki düğüm. Mekaniği net: **"Bayrak dayanıklılığı kaybet, karşılığında nadir artifact/relic kazan."**

- **Ne yapar:** Bir bedel (flag durability −2 gibi) öde → **Nadir Artifact** al. Risk/ödül düğümü.
- **Görsel (ekrandaki gibi):** İzometrik küçük mezarlık adası — mezar taşları, kırık çitler, sis bulutları, ölü ağaçlar, taş zemin (senin cracked/mossy tile'ların). Ortada bir kırmızı sancak + kutsal mezar. Üstünde iki elmas seçim ikonu (mavi flask "1" / sarı yıldız "2") + bayrak-maliyet rozeti.
- **UI:** üstte açıklama kutusu ("Bayrak dayanıklılığı kaybet, artifact kazan"), altta ödül önizleme ("Nadir Artifact al, bayrak −2"), Onayla/Geç.
- **Zar bağlantısı:** artifact kalitesini/olasılığını zar harcayarak iyileştirebilirsin (§6).

---

## 12. CAMPSITE / AĞIL — META İLERLEME (tam yapı)

Senin screenshot 3'ün. Üst sekmeler: **Journey map | Campsite | Contract**. Bu meta hub'ın; sefer sonu kaynakla kalıcı tesis inşa/geliştir.

**Para birimleri:**
- **Kaynak (Resources)** — mavi kristal (screenshot: 1120). Sefer sonu kazanılır, tesis için. Ne kadar ilerlersen o kadar çok.
- **Altın (Coin)** — sarı (screenshot: 2314). Tesis geliştirme / sefer içi harcama.

**Görsel:** İzometrik orman kampı. Ortada şenlik ateşi (sıcak glow, yükselen kıvılcım partikülleri), etrafında inşa slotları — çadırlar/binalar Lv rozetli (Lv1/Lv2). Terracotta uçurum kenarları, çam ağaçları, sıcak sarı ışık. Alt şeritte inşa edilebilir tesisler + maliyetleri.

**Tesisler (MoP'un 5'i + screenshot'undaki isimler harmanı — sende genişlet):**
| Tesis | Etki (MoP doğrulanmış → adapte) |
|---|---|
| **Kışla / Barracks** | Savaş ödülü merc'i 1/2/3 karşılaşma boyunca yükseltilmiş gelir. |
| **Karargah / Command Center** | Başlangıçta **Çoban Pusulası** relic'i (sefer içi 1/2 kullanım). |
| **Depo / Storage (Warehouse)** | +1/2 item slotu; full'de yeni bölgeye girişte 1 rastgele item. |
| **Değirmen / Windmill** | Sefer başı +2/4/6/8 **zar**. |
| **Atölye / Workshop** | Boss yenince bayrak dayanıklılığı +3/4/5/6 geri kazan. |
| **Takas Tahtası / Trading board** | (screenshot) Dükkan indirimleri / ekstra takas. |
| **Gözcü Kulesi / Watchtower** | (screenshot) Harita düğümlerini önden gör / ekstra rota bilgisi. |
| **İkmal İstasyonu / Supply station** | (screenshot) Sefer başı ekstra altın/erzak. |

**Kural (MoP):** 5'ten (sende 6-8'den) sadece **belli sayıda** inşa edebilirsin → build çeşitliliği/seçim baskısı. Hepsi aynı **Kaynak** ile inşa/upgrade.

**Ordeal (zorluk katmanı):** İlk sefer bitince Ordeal açılır — 7 zorluk modifiyeri, üst üste binerek zorlaşır, daha çok Kaynak+XP verir. İlk üçü: düşman birimleri yükseltilmiş / düşman bayrak+boss HP artmış / savaştaki birim sayısı artmış. Asıl replayability burada.

---

## 13. SAVAŞ ÖZETİ (net kurallar, MoP doğrulanmış)

- **Auto-battler ama her tur karar verirsin.** Birimler önündekine saldırır.
- Her tur: yeni birim koy / mevcut birimi yana-geri taşı / Kumandan yeteneği kullan → sonra HIZ sırasıyla otomatik ilerleme+saldırı.
- **Zafer:** düşman bayrağını (boss savaşında = boss) önce yık.
- **Yenilgi 1:** kendi bayrağın düşerse. **Yenilgi 2:** düşmanı yıkmadan **merc'lerin biterse**. (MoP dengesizliği: düşman merc'i bitince kaybetmez — sen bunu **düzelt**: iki tarafa da simetrik "piece-out" kuralı ya da bayrak-only yenilgi.)
- Hız: 1x/2x/**3x** + atla.
- Bayrak dayanıklılığı **kalıcı**, savaşlar arası yenilenmez (sadece revir/atölye/olay onarır).

---

## 14. STAT / TRAIT / RUMOR / UPGRADE (MoP doğrulanmış)

- **3 stat:** Saldırı (attack), Can (health), Hız (speed). Hız eşitliği → zar.
- **Upgrade:** her merc 2 kez, herhangi kombinasyon. Sonrası sadece Saloon/Bootcamp kumarı.
- **Trait:** merc başına ≤2. Güçlü pasifler — asıl sinerji motoru. (Senin Güç×Kat formülün buraya oturur.)
- **Rumor:** merc başına 1. Zayıf ama faydalı pasif (Han/tavern mantığı; sende kart-olayı ödülü ya da özel düğümle verilebilir).
- **Etiket sinerjisi:** Kuzu temasıyla — *Koç / Çoban / Kutsal / Direnişçi* etiketleri; N tane aynı etiket → sürü bonusu.

---

## 15. UI & SANAT (shader/efekt seviyesinde)

MoP: cel-shading, kalın karikatürel siyah çizgiler, izometrik, dark-fantasy, Darkest Dungeon grimliği. Aşağısı Godot 4 karşılıkları.

### 15.1 Cel / toon shader
- Özel `spatial` shader: ışığı 2-3 banda quantize (`smoothstep`/`step` `LIGHT()` içinde).
- **Kalın siyah outline:** inverse-hull (ikinci materyal, `cull_front`, normal boyunca `grow`) — MoP'un imza kalın çizgisi. Kalınlığı biraz abart (karikatürel).
- Desatüre el-boyaması doku; renkler emission ile pop'lar.

### 15.2 Renk paleti
- Boşluk/arka plan: koyu lacivert-siyah.
- Arazi: yosun yeşili / çorak toprak / gri taş; yan yüzler simsiyah.
- Sıcak accent: ateş/fener turuncu-sarı (güvenli düğümler).
- Tehlike: kızıl. Pus/tarikat: mor.
- Kuzu-halk: kirli beyaz yün + kırmızı/mavi sancak (frakisyon rengi).

### 15.3 KARA PUS FOG-OF-WAR shader (imza)
- Journey map'te keşfedilmemiş alan: **halftone/dither** desenli karanlık overlay (ekran görüntüsü 2). 
- Godot: fullscreen ya da bölge-maskeli `ShaderMaterial`; bir **Bayer/ordered-dither matrix** ile alpha threshold → nokta-desenli sınır. Zaman ile hafif dalgalanma (`TIME`) → pus canlı.
- Keşfedilince pus maskesi o düğüm etrafında açılır (reveal tween).
- **Bu efekt oyunun görsel kimliğinin yarısı.** İlk yapılacak shader'lardan.

### 15.4 UI çerçeve dili (Darkest Dungeon grunge)
- Yatay ayraçlar: **yırtık kağıt / mürekkep fırça** çizgileri (screenshot'lardaki gibi), düz çizgi değil.
- Panel/kart kenarları: grungy, aşınmış, hafif düzensiz.
- Köşe süsleri: el-çizimi köşe parantezleri.
- Portre: **elmas (diamond) çerçeve**, altında seviye bandı (kırmızı elmas rozet + rakam), yanında ad + Exp bar.
- Tooltip'ler: koyu, hafif şeffaf, ince outline.

### 15.5 Kart Olayı görünümü (screenshot 2)
- Ortada büyük **fiziksel kart**: üstte başlık, altında **art paneli** (o sahnenin çizimi), altında hikaye metni, en altta **Confirm + ödül ikonları** (kitap+1, gem+1).
- Kart kenarı grungy/yırtık, hafif eğik duruş, arka plan halftone puslu blur.
- Kart belirişi: hafif 3D flip/scale-in tween.

### 15.6 Efektler / feedback
- Hasar sayısı: billboard `Label3D`, scale-pop + float + fade; kritik daha büyük + sarı + ekran shake.
- Kritik/ölüm: turuncu burst + toz partikülü.
- Şenlik ateşi: yükselen kıvılcım `GPUParticles3D` + sıcak glow (WorldEnvironment glow açık).
- Buton/hover: hafif ölçek + parlama; ses feedback (tok tık).
- Zar: §6.
- **Glow AÇIK** (emissive pop için şart), ambient düşük.

---

## 16. İKON KAYNAKLARI (ücretsiz — araştırıldı, eklenebilir)

**Ana kaynak: game-icons.net** — 4000+ ikon, CC BY 3.0 (atıf yeterli), tek renk, dark-fantasy'e birebir uyar. UI ikonlarının %90'ı buradan. İlgili ikon isimleri:

| Sistem | game-icons.net araması / ikon |
|---|---|
| Saldırı | `broadsword`, `crossed-swords` |
| Can | `heart-plus`, `hearts` |
| Hız | `run`, `footprint`, `wingfoot` |
| Bayrak (flag durability) | `flag`, `checkered-flag` |
| Zar | `dice-six-faces-six`, `perspective-dice-six-faces-one`, `rolling-dices` |
| Altın | `two-coins`, `coins` |
| Kaynak/kristal | `crystal-cluster`, `gem` |
| Relic/Yadigar | `relic-blade`, `gem-pendant`, `crowned-skull` |
| Trait/Nitelik | `skills`, `abstract-024` |
| Rumor | `conversation`, `town-crier` |
| Şaman | `witch-face`, `totem`, `feather-necklace` |
| Revir | `health-normal`, `medical-pack`, `bandage-roll` |
| Gri Mezar | `tombstone`, `grave-flowers` |
| Darağacı/Gallows | `hanging-sign`, `guillotine` |
| Kitapçı | `book-cover`, `spell-book` |
| Kamp/tesis | `campfire`, `camping-tent`, `watchtower`, `barn` |
| Kurt Tarikatı | `wolf-head`, `wolf-howl` |
| Kuzu-halk | `sheep`, `ram`, `wool` |
| Pus | `fog`, `smoking-orb` |
| Kumandan yeteneği | `sword-brandish`, `power-lightning` |

**3D asset (dummy/gerçek):**
- **Kenney.nl** (CC0): izometrik tile, low-poly çevre/karakter, UI pack, audio — prototip için ideal.
- **Quaternius** (CC0): low-poly karakter/çevre.
- **Synty POLYGON** (ücretli): profesyonel low-poly, dark-fantasy paketleri (sanat aşamasında).
- **itch.io**: "isometric tileset", "dark fantasy", CC0/ucuz.

**Ses:** freesound.org, Kenney audio, itch.io sfx (zar clack, ateş, vuruş, ölüm).

**Kart olayı sanatı (dummy):** başta düz renk + placeholder; sonra AI-gen ya da satın alınmış dark-fantasy illüstrasyon. Grunge çerçeveyi shader/overlay ile kendin ver.

---

## 17. DUMMY VISUAL PLANI

Her ekran önce dummy ile kurulur, sonra sanat girer:
| Ekran | Dummy |
|---|---|
| Ağıl Meydanı / Campsite | BoxMesh küp adalar + Label3D bina adları + renkli tıklanabilir alanlar |
| Journey map | Nokta grid + basit ikonlu düğümler + gri dither overlay placeholder |
| Kart Olayı | Boş panel + placeholder art rect + Lorem metin + ikonlu Confirm |
| Zar | Basit BoxMesh D6 + Label3D pip / tween döndürme |
| Savaş | (PUS_CLAUDE.md §18 dummy planı) |
| İkonlar | game-icons.net placeholder ya da renkli ColorRect + harf |

Dummy'de bile: cel shader + kalın outline + halftone pus + glow **açık** — kimlik shader'da.

---

## 18. İÇERİK HEDEFLERİ + SCOPE

**MoP referans sayıları (EA):** kumandan başına 28 merc, 32 relic, 9 item, 22 kart olayı, bölge başı 15 düşman (×4=60), 4 bölge, 8 boss, 7 Ordeal. itch aspirational: 140+ merc, 80+ relic, 400+ kart.

**AĞIL v1 hedefi (gerçekçi solo):**
- 2 kumandan × ~20 merc = 40 merc.
- 4 bölge, 8 boss, bölge başı ~10 düşman.
- ~25 relic, ~20 trait, ~20 kart olayı, ~8 item.
- Tüm düğüm tipleri (§5), campsite tesisleri (§12), zar sistemi, tutorial, Ordeal (en az 3).

**Scope kilidi:** PUS_CLAUDE.md §23 + MoP_ARASTIRMA §B.8 geçerli. Multiplayer/manuel-savaş/prosedürel-harita yok. Faz 0 (dummy savaş çekirdeği) bitmeden ekran/UI cilası yok. Yeni fikir → ayrı dosya.

**Farklılaştırma (MoP zayıflıklarına cevap):** simetrik piece-out yenilgi kuralı, net revir/heal düğümü, tek-tık UI, oyuncu-seçimli trait, kuzu-vs-kurt kültürel kimlik, Güç×Kat build patlaması.

---

## 19. KAYNAKLAR
- Button Musher / The Phrasemaker detaylı incelemesi (Şub 2026) — hub yapısı, tutorial, düğüm tipleri, garrison tesisleri, stat/trait/rumor, dice, Ordeal, denge notları.
- Steam (I M GAME) — künye, tür, içerik hacmi.
- itch.io (I M GAME) — aspirational içerik sayıları, campsite/facility notu.
- gamepressure / MobyGames — cel-shading, izometrik, bayrak-canı, flag durability.
- Ekran görüntüleri — Gray grave, Hill of sunshine (kart olayı), Campsite (tesisler), fog-of-war halftone.

> Tüm mekanikler kendi ifademle özetlendi; oyun mekaniği fikirdir, kopyalanabilir. Hedef: öğren + kuzu-köyü kimliğiyle farklılaş.
