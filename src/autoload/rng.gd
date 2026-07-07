extends Node
## RNG — seed'li RandomNumberGenerator, TEK rastlantı kaynağı (CLAUDE.md §17.4).
## KURAL: yalnızca savaş ÖNCESİ alanda kullanılır (kart çekme, ödül, harita).
## Savaş içi (CombatResolver) rastlantı YASAK — determinizm sütunu (§1.2).

var _rng := RandomNumberGenerator.new()

func reseed(seed_value: int) -> void:
	_rng.seed = seed_value

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func randf() -> float:
	return _rng.randf()

func pick(arr: Array) -> Variant:
	return arr[_rng.randi_range(0, arr.size() - 1)] if not arr.is_empty() else null

func shuffle(arr: Array) -> void:
	# Fisher–Yates, seed'li (Array.shuffle() global RNG kullanır, onu kullanma)
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
