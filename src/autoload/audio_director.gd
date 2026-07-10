extends Node
## AudioDirector — sfx/müzik yönetimi (CLAUDE.md §17.4, §20).
## Sesler assets/audio/ altında (üretilmiş, CC0). SFX havuzu + tek müzik kanalı.

var _sfx: Dictionary = {} # id -> AudioStream
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
const POOL_SIZE := 8

## Ses id -> dosya. Gerçekçi SFX'ler SoundBible'dan (CC-BY 3.0 — bkz. CREDITS.md).
const SFX_FILES := {
	&"deploy_clunk": "res://assets/audio/sfx_deploy.wav",
	&"hit": "res://assets/audio/sfx_hit_real.mp3",       # gerçekçi vuruş
	&"arrow": "res://assets/audio/sfx_arrow.mp3",        # okçu ok atışı
	&"electric": "res://assets/audio/sfx_electric.mp3",  # şimşek/elektrik zap
	&"fire": "res://assets/audio/sfx_fire.mp3",     # yanma/alev
	&"battlecry": "res://assets/audio/sfx_battlecry.mp3",# savaş narası
	&"death": "res://assets/audio/sfx_death_cry.mp3",
	&"heal": "res://assets/audio/sfx_heal.wav",
	&"battle_start": "res://assets/audio/sfx_battle_start.wav",
	&"victory": "res://assets/audio/sfx_victory.wav",
	&"defeat": "res://assets/audio/sfx_defeat.wav",
}
const MUSIC_BATTLE := "res://assets/audio/the_last_stand.mp3"

## Ses AÇIK.
const ENABLED := true

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = SFX_VOL_DB
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

const SFX_VOL_DB := -3.0

## Bazı kaynak dosyalar uzun kuyruklu (örn. sfx_electric ~3 sn). Havuz oyuncusu sesi
## sonuna kadar çalıyordu → şimşek çakıp bittikten çok sonra bile vızıltı sürüyordu.
## Kesme süresi (sn) → o süre sonunda kısa fade-out + stop. 0 = tam uzunluk.
const SFX_MAX_SEC := {
	&"electric": 0.5,
	&"fire": 0.7,
	&"arrow": 0.55,
}

var _cut_tw: Dictionary = {}   # AudioStreamPlayer -> Tween (yeniden kullanımda iptal)

func play_sfx(id: StringName, pitch_jitter: float = 0.0) -> void:
	var stream: AudioStream = _sfx.get(id)
	if stream == null:
		return # ses henüz bağlanmadı — sessizce geç
	for p in _players:
		if not p.playing:
			# Bu oyuncu daha önce kesme tween'iyle kısılmış olabilir — iptal et ve sıfırla
			var old: Tween = _cut_tw.get(p)
			if old != null and old.is_valid():
				old.kill()
			_cut_tw.erase(p)
			p.volume_db = SFX_VOL_DB
			p.stream = stream
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			var cut: float = SFX_MAX_SEC.get(id, 0.0)
			if cut > 0.0:
				var tw := create_tween()
				tw.tween_interval(cut)
				tw.tween_property(p, "volume_db", -40.0, 0.1)
				tw.tween_callback(func() -> void:
					p.stop()
					p.volume_db = SFX_VOL_DB
					_cut_tw.erase(p))
				_cut_tw[p] = tw
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
	elif stream is AudioStreamMP3:
		stream.loop = true
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.volume_db = vol_db
	_music.play()

func stop_music() -> void:
	_music.stop()
