# PUS — Güncelleme Notları

> İzometrik 3D otomatik-savaş × roguelite deckbuilder × grid taktik.
> Godot 4.7 (Forward+). Tasarım dokümanı: `CLAUDE.md`.

## M0 — Dummy Dikey Dilim

### Aşama 1 — Proje iskeleti + görsel kimlik
- Godot projesi (Forward+), 5 autoload: `Database` (data-driven .tres yükleyici), `GameState`, `RNG` (seed'li tek rastlantı kaynağı), `EventBus`, `AudioDirector` (sfx havuzu, sesler sonra bağlanır).
- Katı katman ayrımı: `src/logic/` (saf, motor-bağımsız, deterministik) / `src/presentation/` (görsel/ses). Logic, Presentation'ı hiç bilmez.
- 6×5 kübik blok grid (`BoardView`), yükseklik (Yükselti) destekli.
- Ortografik izometrik kamera rig'i: pitch −35°, yaw 45°, Q/E ile 90° tween'li rotasyon, tekerlekle zoom.
- Görsel kimlik shader'ları: toon/cel (2-3 band), inverse-hull outline, emissive kenar-parlamalı grid overlay.
- WorldEnvironment: glow, filmic tonemap, koyu lacivert boşluk (#0d0f1a).

### Aşama 2 — Deployment fazı
- `PieceData` Resource modeli; içerik `.tres` dosyalarında (kod ≠ içerik).
- Başlangıç bölüğü: Mızraklı, Okçu, Şifacı, Serdengeçti. Düşmanlar: Pus Yürüyücü, Zırhlı, Nişancı.
- Sürükle yerine seç-tıkla deployment: kart seç → yeşil tile'a bırak, taşı (tıkla), geri al (sağ tık), Mevzi (AP) ekonomisi (başlangıç 6).
- Tile raycast'i, geçerli tile (yeşil) / hover (sarı) overlay'leri.
- Deployment UI: bölük kartları, Mevzi sayacı, SAVAŞ butonu.

### Aşama 3 — CombatResolver (deterministik çekirdek)
- `CombatResolver.resolve(units, ctx, seed) -> {events, kazanan, rounds}` kontratı; savaş içi sıfır rastlantı — aynı kurulum = birebir aynı event listesi.
- Tur döngüsü: HIZ azalan aktivasyon (eşitlik: alt satır → düşük kolon → uid), MAX 15 tur.
- Sınıf davranışları: MELEE (komşuya vur / greedy ilerle), RANGED (yerinden en yakına), SUPPORT (komşu iyileştir).
- Güç×Kat hasar formülü: `final = max(0, floor((ATK + ΣGüç) × ΠKat) − Zırh)`, önce Kalkan tüketilir.
- Pus Basıncı (sudden death): 8. turdan itibaren herkese `(tur−7)×2` hasar.
- Headless test altyapısı (`tests/run_combat_test.gd`): formül, determinizm, senaryo testleri.

### Aşama 4 — CombatPresenter (izleme fazı)
- Event playback: yürüme/lunge tween'leri, vuruş flash + sarsıntı, damage number (pop + süzülme), ölümde küçülme.
- 1x / 2x / Atla kontrolleri ("Atla" kalan event'leri anında uygular), tur sayacı.
- ZAFER / YENİLGİ sonuç paneli.
- `--autobattle` debug argümanı (otomatik diz + savaş; CI/görsel doğrulama için).

## M1 — Savaş Derinliği

### Parça 1 — Tabya (trait) sistemi + statü efektleri
- `TraitData` Resource: tetik (PASSIVE / ON_HIT / ON_KILL / ON_DEATH / ON_DEPLOY / ROUND_START / AURA), koşul (dış kolon, aynı satır/kolon, yükselti, komşu/saha etiket sayısı), Güç-Kat katkıları, statü uygulama.
- 12 tabya (.tres): Nişan, Kanat, Yüksek Zemin, Sürü Lideri, Kutsal Bağ, Kan Kaybı, Kızıl Ziyafet, Son Nefes, Sargı, Sarsıcı, Kalkan Duruşu, Öfke.
- Statü motoru: Zehir (X hasar → X−1), Yanık, Sersem (aktivasyon atlar), Kök (yürüyemez), Kalkan, Lanet (×0.5 Kat), Zırh — spec stack kuralları.
- Birimlere doğuştan tabyalar; kartlarda tabya adı + tooltip.
- Savaş içi tabya geri bildirimi: "★ Tabya" proc yazıları, statü şeridi ("Klk 7", "Zhr 2"), "Sersem!" uyarısı.

### Parça 2 — Zemin/Engeller + Telegraph
- Zemin tipleri (mekanik + görsel): Duvar (hareket bloklar, melee dolaşır), Lav (tur başı 3), Diken (ilk girene 2, tükenir), Kutsal Zemin (+2 Güç), Pus Tile (×0.75 Kat), Yükselti (+1 Güç).
- Düşman niyet telegraph'ı: determinizm sayesinde gerçek önizleme — kurulum her değiştiğinde 1. tur simüle edilir; kırmızı = vurulacak dost tile'ı, turuncu = düşman hareket hedefi, düşman üstünde "→C3 ⚔B2" metni.
- 34 headless test — tamamı yeşil.

## Görsel/Ton Geçişi (referans: Master of Piece)
- Desatüre palet: yosun yeşili, çorak düşman yakası, simsiyaha yakın yan yüzler; tile başına deterministik ton kırılması.
- Toon shader'a world-space el boyaması benekleme (noise; doku asset'i yok).
- Mor pus vinyeti (fullscreen shader, yavaş akan fbm sis).
- Işık: sıcak anahtar + mor fill, düşük ambient, SSAO.
- Koyu UI teması (`UITheme`): koyu paneller, sıcak kenarlık, kırık beyaz metin.
- Zemin plakaları: domain-warped fbm "liquid" damarlar (lav = akkor magma kıvrımları, kutsal = soluk altın, pus = mor girdap); damar yalnız üst yüzde, yanlar temiz koyu kenar.
- Grid overlay glow'u kısıldı (neon hissi giderildi).

## Asset Entegrasyonu
- `PieceView` iki modlu: billboard sprite (`PieceData.mesh_id` → `assets/<id>.png`) veya sınıf renkli toon kapsül.
- Mızraklı → `main.png` (koç asker), Okçu → `archer.png` (koç okçu).
- Birim altı yumuşak siyah blob gölge (sprite'lar gerçek gölge düşüremediği için).
- İdle bob animasyonu kaldırıldı (istek üzerine).

## M2 — Run İskeleti (devam ediyor)
- `Encounters`: 5 elle tasarlı savaş tanımı (kolay/orta/orta2/elit/boss) + bölge harita şablonu. [hazır]
- `GameState` run durumu: Altın, katman ilerlemesi, bölük CAN kalıcılığı (ölen birim "yaralı" 1 CAN ile döner). [hazır]
- `MapScreen`: düğüm haritası + ilk olay kartı ("Pus İçinde Bir Yaralı Asker"). [hazır]
- Sırada: dükkan ekranı, savaşın encounter'dan beslenmesi, zafer ödül akışı, ekran geçişleri.

## M2 tamam + M3 (run + meta) — 2026-07 oturumları
- Dükkan, ödül ekranı, ekran geçişleri, run sonu ekranı; encounter'dan beslenen savaş.
- Garnizon meta (Kalıntı parası, 3 tesis), kayıt/yükleme (`user://`), tabya füzyon + sürgün.
- Ejderha boss (2 bölge sonu), sancak bayrakları, arka plan atmosferi.

## Kimlik: PUS → AĞIL
- Kuzu-köyü kimliği (gelistirme.md spec'i): koyun-halk vs Kurt Tarikatı.
- Görsel katman: ray-box tile derinliği (iso_tile shader), bayrak dalgası, efekt cilası.
- Zar sistemi (Değirmen → sefer zarı; reroll harcaması; savaş içi HIZ-eşitliği zarı seed'li).
- Simetrik piece-out yenilgi kuralı + 3x izleme hızı.

## Diyorama düğüm ekranları (MoP "Gray grave" dili)
- `NodeDiorama` taban sınıfı: iso tile adası + toon prop'lar + yüzen elmas seçenekler + sis.
- 7 düğüm: Şaman Çadırı, Sahra Revan, Gri Mezar, Nitelik Dükkanı, Yadigar Dükkanı,
  Darağacı, Meydan (Talim Kumarı).
- Söylenti sistemi: `data/rumors/*.tres` (6), birim başına 1 zayıf kalıcı pasif.
- Journey map KARA PUS fog-of-war (halftone dither shader, katman bazlı açılım).

## Ekran katmanı: Kart Olayı + Ağıl Meydanı (2026-07-10)
- Kart Olayı fiziksel kart (gelistirme §15.5): yırtık kenarlı parşömen, art paneli,
  ödül ikonlu seçenekler, halftone karartma, flip-in tween. Debug: `--olay`.
- Ağıl Meydanı hub'ı (gelistirme §2): NodeDiorama üstünde meydan adası — şenlik
  ateşi (SEFERE ÇIK), garnizon çadırı, kilitli Lonca/Arşiv plakaları, sürü kuzuları.
  Menü "Yeni Sefer" → Meydan; run Sefere Çık ile başlar; sefer sonu Meydan'a döner.
  Debug: `--hub`.
- NodeDiorama: `add_campfire` (taş halka + kütük + kor + kıvılcım + titrek ışık),
  `force_home_biome` (hub her zaman yeşil yuva seti).
- Garnizon campsite diyoraması: kamp adası + tesis prop'ları (İkmal İstasyonu,
  Atölye, Talimhane, dönen kanatlı Değirmen) + seviye/bedel elmasları. Debug: `--garrison`.
