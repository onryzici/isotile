class_name BoardDefs
## SAF MANTIK — grid sabitleri + koordinat yardımcıları (CLAUDE.md §3.1).
## Bu dosya motor/görsel hiçbir şey bilmez; CombatResolver da bunu kullanacak.
## Koordinat: Vector2i(kolon 0..5 = A..F, satır 0..4 = 1..5).

const COLS := 6
const ROWS := 5

const PLAYER_ROWS: Array[int] = [0, 1]   # satır 1-2: oyuncu deployment
const NOMANS_ROW := 2                     # satır 3: engel/zemin efekti
const ENEMY_ROWS: Array[int] = [3, 4]     # satır 4-5: düşman

const MAX_ROUND := 15
const SUDDEN_DEATH_ROUND := 8             # Pus Basıncı başlangıcı (§3.7)

static func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < COLS and c.y >= 0 and c.y < ROWS

static func is_player_zone(c: Vector2i) -> bool:
	return in_bounds(c) and c.y in PLAYER_ROWS

static func is_enemy_zone(c: Vector2i) -> bool:
	return in_bounds(c) and c.y in ENEMY_ROWS

## "A1".."F5" gösterimi (kolon harf, satır 1-tabanlı)
static func coord_name(c: Vector2i) -> String:
	return String.chr(65 + c.x) + str(c.y + 1)

## Grid (Chebyshev) mesafesi — 8-yönlü komşuluk dünyasında
static func grid_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
