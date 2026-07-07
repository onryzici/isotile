class_name DeploymentLogic
extends RefCounted
## SAF MANTIK — deployment kuralları (CLAUDE.md §3.2):
## satır 1-2'ye, boş tile'a, yeterli Mevzi (AP) varsa yerleştir.
## Görsel/girdi bilmez; BattleScreen orkestre eder.

var mevzi: int
var occupied: Dictionary = {}   # Vector2i -> true

func _init(start_mevzi: int) -> void:
	mevzi = start_mevzi

func is_free(coord: Vector2i) -> bool:
	return not occupied.has(coord)

func can_place(cost: int, coord: Vector2i) -> bool:
	return BoardDefs.is_player_zone(coord) and is_free(coord) and mevzi >= cost

func place(cost: int, coord: Vector2i) -> bool:
	if not can_place(cost, coord):
		return false
	occupied[coord] = true
	mevzi -= cost
	return true

## Geri alma: Mevzi iade edilir (kendi bölgende serbest yeniden konumlama
## "kaldır + tekrar yerleştir" olarak modellenir; net maliyet sıfır).
func remove(cost: int, coord: Vector2i) -> void:
	if occupied.erase(coord):
		mevzi += cost
