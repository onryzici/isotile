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
