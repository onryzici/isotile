extends Node
## GameState — aktif run durumu (CLAUDE.md §17.4). M2: Altın, harita ilerlemesi,
## bölük CAN kalıcılığı. M3'te GarnisonState + kaydetme eklenecek.
##
## Açık kural (M2 kararı): savaşta ölen birim kadrodan ÇIKMAZ, "yaralı"
## döner (1 CAN). Şifahane/dükkan iyileştirmesi bu yüzden değerli.

var run_seed: int = 0
var gold := 0
var layer_index := 0                      # haritada sıradaki katman
var current_encounter: StringName = &"orta"
var current_node_type: StringName = &"savas"

var squad: Array = []                     # PieceData listesi (kadro, run içinde büyür)
var squad_hp: Dictionary = {}             # squad index -> güncel CAN
var mevzi: int = 6                        # savaş başı Mevzi (AP) (§21)

func start_new_run(seed_value: int = 0) -> void:
	run_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	RNG.reseed(run_seed)
	gold = 25
	layer_index = 0
	mevzi = 6
	squad = Database.get_all("pieces").duplicate()
	squad_hp.clear()
	for i in squad.size():
		squad_hp[i] = squad[i].can

func add_unit(piece: PieceData) -> void:
	squad.append(piece)
	squad_hp[squad.size() - 1] = piece.can

func heal_all() -> void:
	for i in squad.size():
		squad_hp[i] = squad[i].can

func current_hp(index: int) -> int:
	return clampi(squad_hp.get(index, squad[index].can), 1, squad[index].can)
