# PUS

İzometrik 3D **otomatik-savaş** × **roguelite deckbuilder** × **grid taktik**.
Bütün kararlar savaştan önce alınır; savaş deterministik ve otomatik çözülür.

- **Motor:** Godot 4.7 (Forward+)
- **Tasarım dokümanı:** [`CLAUDE.md`](CLAUDE.md) — tüm sistemlerin spec'i
- **Güncelleme notları:** [`CHANGELOG.md`](CHANGELOG.md)

## Çalıştırma

1. [Godot 4.7](https://godotengine.org/download) indir.
2. Projeyi aç (`project.godot`) ve F5 — veya doğrudan:
   ```
   godot --path .
   ```

### Debug / test

```bash
# Deterministik savaş çözücü testleri (34 test)
godot --headless --path . --script res://tests/run_combat_test.gd

# Otomatik diz + savaş (görsel doğrulama)
godot --path . -- --autobattle
```

## Kontroller

| Girdi | İşlev |
|---|---|
| Sol tık (kart → tile) | Birim yerleştir |
| Sol tık (yerleşik birim) | Eline al / taşı |
| Sağ tık | Geri al / seçimi bırak |
| Q / E | Kamera 90° döndür |
| Tekerlek | Zoom |
| 1x / 2x / Atla | Savaş izleme hızı |

## Mimari (özet)

```
src/logic/          saf, deterministik — motor/görsel bilmez
  combat_resolver.gd  savaşı çözer, CombatEvent[] üretir
  piece_data.gd       birim verisi (Resource)
  trait_data.gd       tabya verisi (Resource)
src/presentation/   görsel/ses — logic'i okur, asla yazmaz
  combat_presenter.gd event listesini animasyonla oynatır
data/               tüm içerik .tres (kod ≠ içerik)
shaders/            toon + outline + overlay + liquid zemin + pus vinyeti
tests/              headless determinizm/formül testleri
```
