extends Node
## AudioDirector — sfx/müzik yönetimi (CLAUDE.md §17.4, §20).
## Sesler assets/audio/ altında (üretilmiş, CC0). SFX havuzu + tek müzik kanalı.

var _sfx: Dictionary = {} # id -> AudioStream
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
const POOL_SIZE := 8

## Ses id -> dosya (deploy/savaş/vuruş/ölüm/iyileşme/zafer/yenilgi)
const SFX_FILES := {
	&"deploy_clunk": "res://assets/audio/sfx_deploy.wav",
	&"hit": "res://assets/audio/sfx_hit.wav",
	&"death": "res://assets/audio/sfx_death.wav",
	&"heal": "res://assets/audio/sfx_heal.wav",
	&"battle_start": "res://assets/audio/sfx_battle_start.wav",
	&"victory": "res://assets/audio/sfx_victory.wav",
	&"defeat": "res://assets/audio/sfx_defeat.wav",
}
const MUSIC_BATTLE := "res://assets/audio/music_battle.ogg"

## Ses geçici olarak KAPALI (istek üzerine). Yeniden açmak için true yap.
const ENABLED := false

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -3.0
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = -13.0
	add_child(_music)
	# SFX'leri bağla (dosya yoksa sessizce geç)
	if not ENABLED:
		return
	for id: StringName in SFX_FILES:
		var s: AudioStream = load(SFX_FILES[id])
		if s != null:
			register_sfx(id, s)

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

## Döngülü müzik başlat (aynı parça çalıyorsa yeniden başlatma)
func play_music(path: String = MUSIC_BATTLE, vol_db: float = -13.0) -> void:
	if not ENABLED:
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.volume_db = vol_db
	_music.play()

func stop_music() -> void:
	_music.stop()
