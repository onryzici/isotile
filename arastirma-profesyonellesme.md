# PUS — Tür Araştırması & Profesyonelleşme Yol Haritası

> Amaç: "oyunun bir amacı/hedefi yok" hissini kırmak. Sistemler (CLAUDE.md)
> zaten tam; eksik olan **his katmanları** — build'i görünür kılmak, sefer
> hedefini çerçevelemek, ilerlemeyi ödüllendirmek.

## 1. Tür araştırması — profesyonel oyunlar neyi doğru yapıyor

**Balatro (skor bağımlılığı):** "Geri bildirim, tasarımın kendisidir." Dopamin,
build'in ödeme anını *izlemekten* gelir — sıralı tetiklenme, yükselen sayı,
ses, ekran sarsıntısı. Skor sistemi ile geri bildirim BİRLİKTE tasarlanmış,
sonradan eklenmemiş. Üstel çarpan yığma + görünür ödeme = "bir el daha".

**Slay the Spire (uzun-vade amaç):** Ascension sistemi — oyunu öğrenip
kolaylaşınca artan zorluk kademeleri kalıcı hedef verir. Her sefer benzersiz:
harita sırası + kart ödülleri + relic'ler. Sinerji + strateji derinliği.

**Mechabellum / Into the Breach (izleme tatmini):** Kararlar savaştan ÖNCE;
telegraph savaş başında açılır → "büyük mutluluk ve umutsuzluk anları."
Konumlama kritik çünkü birim etkileşimini belirler. Otomatik olduğu için
oyuncu izleyip "sonra ne yapacağım"ı düşünebilir.

**Ortak formül:** güç-artışı anları (power spikes) sık + görünür + ödüllü;
build okunabilir; kararların sonucu net telegraph'lanır; meta ilerleme kalıcı
amaç verir.

Kaynaklar: rogueliker.com/slay-the-spire-review, blakecrosley.com/guides/design/balatro,
butwhytho.net Balatro review, pcgamer.com Mechabellum, store.steampowered.com (StS/Mechabellum).

## 2. PUS'un mevcut durumu — "amaç yok" hissinin kaynağı

- **Build motoru GÖRÜNMEZ.** Güç×Kat çekirdek ama oyuncu neden o hasarı
  yaptığını göremiyor, combo planlayamıyordu. (§19'da "şart" denmiş, eksikti.)
- **Sefer riski çerçevelenmiyor.** "1/10 katmandayım, bayrağım canım, 3 boss
  hedefim" bilgisi ana ekranda yok. (Sefer Durumu paneli kısmen çözdü.)
- **Savaş izleme düz.** Hasar sayıları var ama build ödeme cılası (Kat yığılınca
  büyüyen kritik, sinerji çağrıları) yok.
- **Meta amaç görünmüyor.** Neden tekrar oynayayım? Ascension/açılım yok.

## 3. Yol haritası (öncelikli)

### ✅ Sütun 1 — Build'i GÖRÜNÜR kıl (BU OTURUMDA YAPILDI)
- Canlı Güç×Kat dökümü: birim üzerine gelince (Taban + her Güç kaynağı) × (her
  Kat kaynağı) = vuruş hasarı. Koşullu bonuslar (Nişan, Kanat, Yükselti) ayrı
  gösterilir → konumlama öğretilir. Mantık katmanından okunur (determinist).
- Üst menü işlevsel: Kılavuz (codex), Sefer Durumu, Menü.

### ⬜ Sütun 2 — Savaş izleme cılası (Balatro dersi)
- Vuruşta döküm animasyonu: Güç sayıları akar, Kat çarpanı "pop"lar, sonuç
  sayısı büyür + ses. Kritik/yüksek Kat'ta ekran sarsıntısı + hale.
- Sinerji tetiklenince ekranda çağrı ("Kutsal Bağ ×1.4!").
- Power-spike anları görünür kutlanır.

### ⬜ Sütun 3 — Sefer hedefi & riski çerçevele
- Ana savaş ekranında: bölge/katman ilerleme çubuğu, "3 boss'a giden yol",
  bayrak = can vurgusu. Boss öncesi telegraph tanıtımı.
- Ödül ekranlarında "build'in nereye gidiyor" ipuçları.

### ⬜ Sütun 4 — Meta amaç & tekrar oynanabilirlik (StS ascension)
- Garnizon açılımları görünür hedef listesi (yeni birim/tabya/relic kilidi).
- Ascension benzeri zorluk kademeleri (Pus yoğunluğu artışı).
- "Yıldız birim" fantezisi: Söylenti (rumor) sistemi öne çıkarılır.

### ⬜ Sütun 5 — İçerik derinliği
- Kat üreten PASSIVE tabya havuzunu genişlet (şu an başlangıç bölüğünde yok →
  build hissi zayıf). Nadir ×Kat tabyaları + relic'ler = patlama potansiyeli.
- Olay kartları (§13) metin ekranı: dallanan seçimler.
