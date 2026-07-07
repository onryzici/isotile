extends Node
## Main / ScreenManager iskeleti (CLAUDE.md §17.5).
## M0: doğrudan BattleScreen açar. M2'de Garnizon/Harita ekranları eklenir.

const BATTLE_SCREEN := preload("res://scenes/battle_screen.tscn")

var _current: Node

func _ready() -> void:
	GameState.start_new_run()
	EventBus.screen_change_requested.connect(_on_screen_change)
	_show_scene(BATTLE_SCREEN)

func _show_scene(scene: PackedScene) -> void:
	if _current:
		_current.queue_free()
	_current = scene.instantiate()
	add_child(_current)

func _on_screen_change(screen: StringName) -> void:
	match screen:
		&"battle":
			_show_scene(BATTLE_SCREEN)
