extends Node
## AudioDirector — sfx/müzik yönetimi (CLAUDE.md §17.4, §20).
## M0: sfx kancaları hazır; ses dosyaları eklendiğinde register_sfx ile bağlanır.

var _sfx: Dictionary = {} # id -> AudioStream
var _players: Array[AudioStreamPlayer] = []
const POOL_SIZE := 8

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

func register_sfx(id: StringName, stream: AudioStream) -> void:
	_sfx[id] = stream

func play_sfx(id: StringName, pitch_jitter: float = 0.0) -> void:
	var stream: AudioStream = _sfx.get(id)
	if stream == null:
		return # ses henüz bağlanmadı — sessizce geç
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return
