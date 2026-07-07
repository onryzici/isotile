extends Node
## EventBus — global sinyaller; UI <-> state gevşek bağ (CLAUDE.md §17.4).

# Ekran akışı
signal screen_change_requested(screen: StringName)
signal map_node_selected(node: Dictionary)     # harita düğümü seçildi (M2)
signal return_to_map(advance: bool)            # savaş/dükkan bitti; advance = katman ilerle
signal run_ended(won: bool)                    # sefer tamam/bitti → yeni run

# Deployment fazı (M0 Aşama 2'de kullanılacak)
signal piece_deployed(piece_id: StringName, coord: Vector2i)
signal piece_recalled(piece_id: StringName)
signal mevzi_changed(current: int)

# Savaş akışı
signal battle_started
signal battle_finished(player_won: bool)
