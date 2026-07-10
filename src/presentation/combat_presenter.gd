class_name CombatPresenter
extends Node
## CombatResolver'ın ürettiği event listesini görsel olarak oynatır (§17.2).
## Mantık çoktan çözüldü; burada SADECE sunum var. Hız 1x/2x, "Atla" =
## kalan event'leri animasyonsuz anında uygula (§3.2).

signal finished(kazanan: String)
signal round_changed(round_no: int)
signal log_line(text: String)   # savaş logu (kim kime vurdu / kim düştü)

const COLOR_DAMAGE := Color(1.0, 0.6, 0.15)   # SALDIRI turuncu (§19)
const COLOR_HEAL := Color(0.35, 1.0, 0.4)
const COLOR_PUS := Color(0.75, 0.4, 1.0)
const COLOR_TRAIT := Color(0.4, 0.9, 1.0)     # tabya proc'u camgöbeği
const COLOR_STATUS := Color(0.7, 1.0, 0.5)    # zehir yeşili

## Statü kısaltmaları (statü şeridi için)
const STATUS_SHORT := {
	"zehir": "Zhr", "yanik": "Ynk", "sersem": "Srs",
	"kok": "Kök", "kalkan": "Klk", "lanet": "Lnt", "zirh": "Zrh",
}

## Ağır vuruş eşiği: Kat build'i patlayınca (yüksek final hasar) kritik VFX tetiklenir.
const CRIT_THRESH := 8

## Prosedürel FX dokuları (yumuşak yuvarlak/yıldız — Godot "default kare partikül"
## hissini kırar; assets/fx/*.png offline üretildi)
const FX_SPARK := preload("res://assets/fx/spark.png")
const FX_FLASH := preload("res://assets/fx/flash.png")
const FX_RING := preload("res://assets/fx/ring.png")
const FX_FIRE := preload("res://assets/fx/fire_sprite.png")   # boyalı alev (dalgalanır)
const FX_LIGHTNING := preload("res://assets/fx/lightning.png")   # şimşek (rahip)
const FLAME_WAVE := preload("res://shaders/flame_wave.gdshader")

var speed := 1.0
var _skip := false
var camera_rig: CameraRig   # ekran sarsıntısı için (battle_screen atar)
var _views: Dictionary   # uid -> PieceView
var _board: BoardView
var _info: Dictionary    # uid -> {ad, atk, spd, hp, max_hp} (savaş başı anlık görüntü)
var _hp: Dictionary      # uid -> oynatma sırasındaki güncel HP
var _statuses: Dictionary = {}   # uid -> {statu: stacks} (statü şeridi)

func set_speed(mult: float) -> void:
	speed = mult

func request_skip() -> void:
	_skip = true

## Tek-seferlik oynatma (autobattle / geriye uyum): tüm event'ler + finished.
func play(result: Dictionary, views: Dictionary, board: BoardView, info: Dictionary) -> void:
	setup(views, board, info)
	for event: Dictionary in result["events"]:
		if _skip:
			break
		await _play_event(event)
	if _skip:
		_apply_final(result)
	finished.emit(result["kazanan"])

## Tur-tur mod (§B.0/3): battle_screen bir kez setup çağırır, her tur play_round.
func setup(views: Dictionary, board: BoardView, info: Dictionary) -> void:
	_views = views
	_board = board
	_info = info
	_hp = {}
	for uid in info:
		_hp[uid] = info[uid]["hp"]

## Tur ortasında yeni yerleştirilen birimi kaydet
func add_unit(uid: int, view: PieceView, info_entry: Dictionary) -> void:
	_views[uid] = view
	_info[uid] = info_entry
	_hp[uid] = info_entry["hp"]

## Bir turun event'lerini oynat (HP/statü kalıcı — sıfırlanmaz). "Atla" o turu hızlar.
func play_round(events: Array) -> void:
	for event: Dictionary in events:
		if _skip:
			break
		await _play_event(event)
	_skip = false

## Turdan sonra görselleri otoriter birim durumuna eşitle (özellikle "Atla" sonrası)
func sync_views(units: Array) -> void:
	for unit: CombatUnit in units:
		var view: PieceView = _views.get(unit.uid)
		if view == null:
			continue
		view.visible = unit.alive
		_hp[unit.uid] = unit.hp
		if unit.alive:
			if not unit.is_flag:   # bayrak görseli kaide sırasında — yerinden oynatma
				var base: Vector3 = _board.coord_to_world(unit.coord)
				view.position = Vector3(base.x, _board.tile_top_y(unit.coord), base.z)
			_update_label(unit.uid)

# ------------------------------------------------------------- event oynatma

func _play_event(e: Dictionary) -> void:
	match e["t"]:
		"ROUND_START":
			round_changed.emit(e["round"])
			await _delay(0.4)
		"ACTIVATE":
			pass   # tempo için sessiz; imleç/vurgu M1 cilası
		"MOVE":
			var view: PieceView = _views.get(e["unit_id"])
			if view:
				_dust(view.position)   # adım tozu
				var base: Vector3 = _board.coord_to_world(e["to"])
				var target := Vector3(base.x, _board.tile_top_y(e["to"]), base.z)
				var tw := view.move_anim(target, 0.3 / speed)
				await tw.finished
		"ATTACK":
			await _play_attack(e)
		"HEAL":
			var dst: PieceView = _views.get(e["dst"])
			if dst:
				_hp[e["dst"]] = mini(_hp[e["dst"]] + e["amount"], _info[e["dst"]]["max_hp"])
				_update_label(e["dst"])
				_spawn_number(dst.position, "+%d" % e["amount"], COLOR_HEAL)
				AudioDirector.play_sfx(&"heal", 0.06)
			await _delay(0.25)
		"PUS_DAMAGE":
			var view: PieceView = _views.get(e["unit_id"])
			if view:
				_hp[e["unit_id"]] -= e["damage"]
				_update_label(e["unit_id"])
				_spawn_number(view.position, "-%d" % e["damage"], COLOR_PUS)
			await _delay(0.1)
		"SPEED_DICE":
			# HIZ eşitliği zarı (gelistirme §6): birimin üstünde kısa zar sonucu.
			# Akışı kesmez — minik gecikme, sayı kendiliğinden süzülüp söner.
			var dview: PieceView = _views.get(e["unit_id"])
			if dview:
				# "Zar N" düz metin: zar glifleri (⚀-⚅) gövde fontunda yok (tofu riski)
				_spawn_number(dview.position, "Zar %d" % e["roll"], Color(0.88, 0.92, 1.0))
			await _delay(0.12)
		"STATUS":
			_set_status(e["target"], e["status"], e["stacks"])
			var stv: PieceView = _views.get(e["target"])
			if stv and e["stacks"] > 0 and (e["status"] == "zehir" or e["status"] == "yanik"):
				_flame(stv.position, e["status"] == "zehir")
				AudioDirector.play_sfx(&"fire", 0.05)   # yanma/alev sesi (yakma anı)
		"STATUS_DAMAGE":
			var view: PieceView = _views.get(e["unit_id"])
			if view:
				_hp[e["unit_id"]] -= e["damage"]
				_update_label(e["unit_id"])
				var renk := COLOR_STATUS if e["status"] == "zehir" else COLOR_DAMAGE
				_spawn_number(view.position, "-%d %s" % [e["damage"], e["status"]], renk)
				if e["status"] == "zehir" or e["status"] == "yanik":
					_flame(view.position, e["status"] == "zehir")
			await _delay(0.22)
		"TERRAIN":
			var view: PieceView = _views.get(e["unit_id"])
			if view:
				_hp[e["unit_id"]] -= e["damage"]
				_update_label(e["unit_id"])
				_spawn_number(view.position, "-%d %s" % [e["damage"], e["terrain"]], COLOR_DAMAGE)
			if e["terrain"] == "diken":
				_board.clear_terrain(e["coord"])   # diken tükendi (§7)
			await _delay(0.25)
		"TRAIT_PROC":
			var view: PieceView = _views.get(e["unit_id"])
			if view:
				_impact(view.position + Vector3(0, 0.4, 0), COLOR_TRAIT, 0.6)
			log_line.emit("★ %s" % e["ad"])   # sade durum bilgisi (Savaş Kaydı)
			await _delay(0.16)
		"STUN_SKIP":
			var view: PieceView = _views.get(e["unit_id"])
			if view:
				_spawn_number(view.position, "Sersem!", Color(1.0, 0.9, 0.3))
			await _delay(0.3)
		"DEATH":
			var view: PieceView = _views.get(e["unit_id"])
			log_line.emit("☠ %s düştü" % _info.get(e["unit_id"], {}).get("ad", "?"))
			if view:
				AudioDirector.play_sfx(&"death", 0.07)
				_impact(view.position, Color(0.52, 0.48, 0.54), 1.5)   # toz bulutu
				var tw := view.die_anim(0.35 / speed)
				await tw.finished
				view.visible = false
		"END":
			await _delay(0.3)

func _play_attack(e: Dictionary) -> void:
	var src: PieceView = _views.get(e["src"])
	var dst: PieceView = _views.get(e["dst"])
	if src == null or dst == null:
		return
	# Menzilli (okçu/nişancı) → atış anında ok sesi
	if int(_info.get(e["src"], {}).get("sinif", 0)) == 1:
		AudioDirector.play_sfx(&"arrow", 0.06)
	var tw := src.attack_lunge(dst.position, 0.34 / speed)
	await _delay(0.13)   # vuruş anı: hamlenin tepe noktası
	dst.hit_flash(0.3 / speed)
	_hp[e["dst"]] -= e["final"]
	_update_label(e["dst"])
	# Balatro dersi: build'in ödemesi GÖRÜNÜR olsun. Şiddet Kat çarpanı + hasar
	# büyüklüğüyle SÜREKLİ ölçeklenir (ikili eşik değil): ×8 vuruş ×2'den çok daha
	# patlayıcı görünür/duyulur.
	var final: int = e["final"]
	var kat: float = e.get("kat", 1.0)
	var heat := clampf((kat - 1.0) * 0.5 + float(final) / 22.0, 0.0, 1.0)
	var payoff: bool = kat >= 1.35 or final >= CRIT_THRESH
	var src_piece := String(_info.get(e["src"], {}).get("piece_id", ""))
	# Rahip → şimşek: gökten iner, hedef çarpılır (normal impact yerine)
	var is_bolt := src_piece == "rahip"
	if src_piece == "__boss":
		# BOSS ejderha → alev nefesi. Kaynak, gövde merkezi DEĞİL, sprite'ın AĞZI.
		_fire_breath(_board.to_local(src.boss_mouth_position()), dst.position)
		dst.squash(0.2, 0.36 / speed)
		_spawn_number(dst.position, "-%d" % final, Color(1.0, 0.66, 0.3), true)
		if camera_rig:
			camera_rig.shake(0.22, 0.28)
	elif is_bolt:
		_lightning(dst.position)
		dst.zap_flash(0.45 / speed)
		_spawn_number(dst.position, "-%d" % final, Color(0.7, 0.88, 1.0), payoff)
	else:
		# renk: ılık turuncu → sıcak sarı-beyaz (heat arttıkça)
		var hot := Color(1.0, 0.70, 0.34).lerp(Color(1.0, 0.96, 0.66), heat)
		_impact(dst.position, hot, 1.0 + heat * 1.9)
		dst.squash(0.12 + heat * 0.22, 0.34 / speed)   # darbe ezilmesi (ağır = daha çok)
		if payoff:
			# Ağır vuruş: büyük sıcak hasar sayısı + sarsıntı + hitstop (metin çağrısı YOK)
			_spawn_number(dst.position, "-%d" % final, Color(1.0, 0.9, 0.48), true)
			if camera_rig:
				camera_rig.shake(0.16 + heat * 0.36, 0.26)
			AudioDirector.play_sfx(&"hit", 0.0)
			await _hitstop(0.05 + heat * 0.07)   # freeze-frame: darbeyi "otur"tur
		else:
			_spawn_number(dst.position, "-%d" % final, COLOR_DAMAGE)
		AudioDirector.play_sfx(&"hit", 0.08)
	var sn: String = _info.get(e["src"], {}).get("ad", "?")
	var dn: String = _info.get(e["dst"], {}).get("ad", "?")
	log_line.emit("%s  ⚔ %s  −%d" % [sn, dn, e["final"]])
	await tw.finished

# ------------------------------------------------------------- yardımcılar

func _delay(base: float) -> void:
	if _skip:
		return
	await get_tree().create_timer(base / speed).timeout

## Hitstop (freeze-frame): darbe anında tüm dünyayı çok kısa dondurur → çarpışma
## "enerji harcamış" gibi oturur (game feel'in en ucuz büyük kazancı). Süre gerçek
## zamanlı beklenir (ignore_time_scale) çünkü time_scale=0 normal timer'ı durdurur.
func _hitstop(dur: float) -> void:
	if _skip or speed > 1.5:
		return   # atla / 2x'te freeze yok (tempo korunur)
	Engine.time_scale = 0.0
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0

func _update_label(uid: int) -> void:
	var view: PieceView = _views.get(uid)
	if view:
		view.set_stat_text("%d/%d/%d" % [_info[uid]["atk"], maxi(0, _hp[uid]), _info[uid]["spd"]])

## Statü şeridini güncelle ("Zhr 3  Klk 7" gibi)
func _set_status(uid: int, status: String, stacks: int) -> void:
	var view: PieceView = _views.get(uid)
	if view == null:
		return
	var dict: Dictionary = _statuses.get_or_add(uid, {})
	if stacks <= 0:
		dict.erase(status)
	else:
		dict[status] = stacks
	var parts: Array[String] = []
	for s in dict:
		parts.append("%s %d" % [STATUS_SHORT.get(s, s), dict[s]])
	view.set_status_text("  ".join(parts))

## Aynı anda doğan sayılar üst üste binip "hayalet/çift baskı" gibi görünüyordu.
## Her yeni sayı bir öncekinden yanal olarak kaydırılır (döngüsel yuva).
var _num_slot := 0
const NUM_SLOTS := [-0.28, 0.24, -0.12, 0.34]

## Damage number (§16.6): billboard Label3D, scale-pop + yukarı süzül + sön.
## big = kritik (daha büyük + daha yüksek pop).
func _spawn_number(world_pos: Vector3, text: String, color: Color, big: bool = false) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	# Yüksek font + küçük pixel_size = keskin metin. Outline ince: 18px halka sayıyı
	# şişirip bulanıklaştırıyordu; okunurluk için ince ve tam siyah yeter.
	lbl.pixel_size = 0.0055 if big else 0.0042
	lbl.font = UITheme.body_font()
	lbl.font_size = 128
	lbl.outline_size = 14
	lbl.outline_modulate = Color(0, 0, 0, 0.9)
	lbl.modulate = color
	_board.add_child(lbl)
	var slot: float = NUM_SLOTS[_num_slot % NUM_SLOTS.size()]
	_num_slot += 1
	lbl.position = world_pos + Vector3(slot, 1.45, 0)
	lbl.scale = Vector3.ONE * 0.2
	var peak := 1.75 if big else 1.3
	var pop := lbl.create_tween()
	pop.tween_property(lbl, "scale", Vector3.ONE * peak, 0.1 / speed).set_trans(Tween.TRANS_BACK)
	pop.tween_property(lbl, "scale", Vector3.ONE * (1.25 if big else 1.0), 0.08 / speed)
	# Yay çizerek yukarı-yana süzül (dümdüz yukarı çıkmak yığılma hissi veriyordu)
	var drift := lbl.create_tween()
	drift.tween_property(lbl, "position:y", lbl.position.y + 0.85, 0.6 / speed) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drift.parallel().tween_property(lbl, "position:x", lbl.position.x + slot * 0.35, 0.6 / speed)
	drift.parallel().tween_property(lbl, "modulate:a", 0.0, 0.3 / speed).set_delay(0.3 / speed)
	drift.tween_callback(lbl.queue_free)

## Darbe VFX'i: yıldız FLASH + yumuşak yuvarlak KIVILCIM + (ağırsa) şok dalgası HALKASI.
## intensity 1.0 normal, >1.6 ağır. Kare additive partikül YOK → dokular yuvarlak/yıldız.
func _impact(world_pos: Vector3, color: Color, intensity: float) -> void:
	var at := world_pos + Vector3(0, 0.55, 0)
	# Flash KÜÇÜK kalmalı: eskiden 0.6+1.9×0.5 ≈ 1.55 dünya birimiydi ve additive+glow
	# ile hedefi tamamen yutan turuncu bir yumru oluyordu. Darbe "noktası" olsun.
	_flash(at, color, 0.42 + intensity * 0.3)
	_sparks(at, color, intensity)
	if intensity >= 1.6:
		_ring(at, color.lerp(Color(1, 1, 1), 0.35), 0.6 + intensity * 0.55)

## Kısa yıldız flash: hızlı büyür sonra sönerek kaybolur (darbenin "pop"u).
func _flash(pos: Vector3, color: Color, size: float) -> void:
	var mi := _fx_quad(FX_FLASH, color)
	_board.add_child(mi)
	mi.position = pos
	mi.scale = Vector3.ONE * size * 0.3
	var mat: StandardMaterial3D = mi.mesh.material
	var pop := mi.create_tween()
	pop.tween_property(mi, "scale", Vector3.ONE * size, 0.05 / speed) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(mi, "scale", Vector3.ONE * size * 0.72, 0.15 / speed)
	var fade := mi.create_tween()
	fade.tween_interval(0.04 / speed)
	fade.tween_property(mat, "albedo_color:a", 0.0, 0.16 / speed)
	fade.tween_callback(mi.queue_free)

## Genişleyen şok dalgası halkası (ağır vuruş): hızla açılır + solar.
func _ring(pos: Vector3, color: Color, size: float) -> void:
	var mi := _fx_quad(FX_RING, color)
	_board.add_child(mi)
	mi.position = pos
	mi.scale = Vector3.ONE * 0.25
	var mat: StandardMaterial3D = mi.mesh.material
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * size, 0.34 / speed) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var fade := mi.create_tween()
	fade.tween_property(mat, "albedo_color:a", 0.0, 0.34 / speed)
	fade.tween_callback(mi.queue_free)

## Kıvılcım: KISA, HIZLI, ÇİZGİ. Eskiden yumuşak yuvarlak blob'lardı — additive +
## glow + 0.5 sn ömür yüzünden havada asılı kalan sarı balonlar gibi görünüyordu
## (Onur: "vuruş efektleri güzel değil"). Artık hız yönünde uzayan (BILLBOARD_PARTICLES)
## ince şeritler; ağır yerçekimiyle hızla düşüp sönüyorlar.
func _sparks(pos: Vector3, color: Color, intensity: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = int(5 + 4 * intensity)
	p.lifetime = 0.3
	p.one_shot = true
	p.explosiveness = 1.0
	p.position = pos
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.06
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.2 * intensity
	mat.initial_velocity_max = 7.0 * intensity
	mat.gravity = Vector3(0, -11.0, 0)     # ağır: yay çizip anında düşsün
	mat.damping_min = 0.5
	mat.damping_max = 1.5
	mat.scale_min = 0.55
	mat.scale_max = 1.0
	var curve := Curve.new()               # uçta incelerek kaybol
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	mat.scale_curve = ct
	# Sıcak beyaz çekirdek → renk → şeffaf: "yanan metal" hissi
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.98, 0.9, 1.0))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	mat.color_ramp = gt
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.16)       # ince uzun şerit
	var sm := _fx_material(FX_SPARK, color)
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES   # +Y = hız yönü
	sm.vertex_color_use_as_albedo = true                     # color_ramp uygulansın
	quad.material = sm
	p.draw_pass_1 = quad
	_board.add_child(p)
	p.emitting = true
	var t := p.create_tween()
	t.tween_interval(0.55)
	t.tween_callback(p.queue_free)

## Toz/duman: birim hareket/saldırırken ayak dibinden yayılan hafif toprak tozu
## (additive DEĞİL — yumuşak alpha, toprak rengi; genişleyip söner). Referans hissi.
func _dust(world_pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 9
	p.lifetime = 0.65
	p.one_shot = true
	p.explosiveness = 0.85
	p.position = world_pos + Vector3(0, 0.04, 0)
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.16, 0.01, 0.16)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 65.0
	mat.initial_velocity_min = 0.25
	mat.initial_velocity_max = 0.7
	mat.gravity = Vector3(0, 0.25, 0)   # hafifçe yükselir sonra durur
	mat.damping_min = 1.2
	mat.damping_max = 2.2
	mat.scale_min = 0.5
	mat.scale_max = 1.0
	var sc := Curve.new()               # toz açılarak büyür sonra söner
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(0.4, 1.0))
	sc.add_point(Vector2(1, 1.2))
	var sct := CurveTexture.new()
	sct.curve = sc
	mat.scale_curve = sct
	var grad := Gradient.new()           # toprak grisi → saydam
	grad.set_color(0, Color(0.55, 0.50, 0.42, 0.45))
	grad.set_color(1, Color(0.5, 0.46, 0.4, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	mat.color_ramp = gt
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA   # additive DEĞİL → toz gibi
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.albedo_texture = FX_SPARK
	dm.vertex_color_use_as_albedo = true
	dm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	quad.material = dm
	p.draw_pass_1 = quad
	_board.add_child(p)
	p.emitting = true
	var t := p.create_tween()
	t.tween_interval(1.0)
	t.tween_callback(p.queue_free)

## Additive, unshaded, billboard, dokulu FX materyali (sahne glow'uyla parlar).
func _fx_material(tex: Texture2D, color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = tex
	# rgb boost 1.3 idi; additive + WorldEnvironment glow ile birlikte beyaza patlıyordu
	m.albedo_color = Color(color.r * 1.05, color.g * 1.05, color.b * 1.05, 1.0)
	m.no_depth_test = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return m

## Tek billboard quad (flash/ring için) — _fx_material'lı MeshInstance3D.
func _fx_quad(tex: Texture2D, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = _fx_material(tex, color)
	mi.mesh = q
	return mi

## Gerçek yangın (boyalı alev, dalgalanır + renk titreşir). Y-dik billboard (iso'ya
## uyar). Birimin ÇEVRESİNE küçük alevler (ön/arka/yanlar) → tam yanıyor hissi.
## Normal derinlik testi: kameraya yakın alevler önde, uzaktakiler arkada (perspektif
## doğru — daha yakın bir karakter varsa onun arkasında). YERDEN yükselerek çıkar.
func _flame(world_pos: Vector3, poison: bool) -> void:
	# 3 alev, FARKLI boyut (büyük merkez + iki küçük yan) → sade ama canlı
	var spots := [
		[110.0, 0.05, 0.8],   # merkez-arka, büyük
		[10.0, 0.26, 0.5],    # sağ-ön, küçük
		[230.0, 0.24, 0.62],  # sol-ön, orta
	]
	for i in spots.size():
		var a := deg_to_rad(spots[i][0])
		var r: float = spots[i][1]
		var off := Vector3(cos(a) * r, 0.0, sin(a) * r * 0.75)
		_flame_quad(world_pos + off, poison, spots[i][2], float(i) * 2.1)

func _flame_quad(base_pos: Vector3, poison: bool, s: float, seed: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 1.1)
	q.center_offset = Vector3(0, q.size.y * 0.5, 0)   # taban origin'de → tabandan büyür
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = FLAME_WAVE
	mat.set_shader_parameter("tex", FX_FIRE)
	mat.set_shader_parameter("fade", 0.0)
	mat.set_shader_parameter("seed", seed)
	mat.set_shader_parameter("brightness", 1.25)
	# Anlık titreşen ateş/zehir renk rampası (dip → orta → sıcak; beyaz patlamayı kıs)
	if poison:
		mat.set_shader_parameter("col_low", Color(0.10, 0.40, 0.10))
		mat.set_shader_parameter("col_mid", Color(0.34, 0.85, 0.24))
		mat.set_shader_parameter("col_hot", Color(0.72, 1.0, 0.45))
	else:
		mat.set_shader_parameter("col_low", Color(0.72, 0.11, 0.03))
		mat.set_shader_parameter("col_mid", Color(1.0, 0.46, 0.10))
		mat.set_shader_parameter("col_hot", Color(1.0, 0.82, 0.34))
	mi.material_override = mat
	mi.position = Vector3(base_pos.x, base_pos.y + 0.05, base_pos.z)   # taban ~yer
	mi.scale = Vector3(s, s * 0.12, s)   # başlangıç: yerde ezik (yükselecek)
	_board.add_child(mi)
	# YERDEN yüksel: scale.y 0→tam (tabandan büyür) + fade — bir anda çıkmaz
	var tin := mi.create_tween().set_parallel(true)
	tin.tween_property(mi, "scale", Vector3(s, s, s), 0.28 / speed) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tin.tween_property(mat, "shader_parameter/fade", 1.0, 0.2 / speed)
	var tout := mi.create_tween()
	tout.tween_interval(0.62 / speed)
	tout.tween_property(mat, "shader_parameter/fade", 0.0, 0.35 / speed)
	tout.parallel().tween_property(mi, "scale", Vector3(s, s * 0.5, s), 0.35 / speed)
	tout.tween_callback(mi.queue_free)

## Şimşek (Rahip). Eskiden tek düz quad'dı: sabit boyda beliriyor, alfası titreyip
## kayboluyordu — "çakma" hissi yoktu. Şimdi:
##  · üç katman (geniş mavi hale + gövde + ince sıcak çekirdek) → hacim ve sıcaklık
##  · pivot TEPEDE: gövde yukarıdan aşağı doğru büyüyerek İNER (gerçek çakış)
##  · katmanlar faz kaydırmalı titrer → tek parça yanıp sönmez, elektrik gibi kaynar
##  · yerde çarpma halkası + yukarı fırlayan kıvılcım + kısa mavi ışık patlaması
const BOLT_H := 2.4
const BOLT_ASPECT := 0.25   # lightning.png 128×512
## Şimşeğin BİTTİĞİ yükseklik: birimin göğüs hizası. Ayak dibine (y≈0) indirilince
## gövde birimin altına taşıyordu (Onur: "aşağı çok uzuyor").
const BOLT_IMPACT_Y := 0.62

func _lightning(target_pos: Vector3) -> void:
	var base := target_pos + Vector3(0, BOLT_IMPACT_Y, 0)
	# [genişlik çarpanı, renk, alfa, titreşim faz kayması]
	var layers := [
		[2.3, Color(0.30, 0.48, 1.0), 0.5, 0],   # dış hale
		[1.0, Color(0.72, 0.86, 1.0), 1.0, 1],   # gövde
		[0.38, Color(1.0, 1.0, 1.0), 1.0, 2],    # sıcak çekirdek
	]
	for L in layers:
		_bolt_layer(base, float(L[0]), L[1], float(L[2]), int(L[3]))

	# Çarpma: kıvılcım + flaş (halka YOK — Onur: "alta çıkan yuvarlak şeyi
	# kaldıralım"; zeminde yatan disk izometride yamalı duruyordu)
	_sparks(base, Color(0.65, 0.85, 1.0), 1.7)
	_flash(base, Color(0.8, 0.9, 1.0), 0.85)

	# Kısa mavi ışık patlaması — sahne gerçekten aydınlanır (sadece additive quad değil)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.6, 0.78, 1.0)
	lamp.light_energy = 0.0
	lamp.omni_range = 5.0
	lamp.shadow_enabled = false
	_board.add_child(lamp)
	lamp.position = base + Vector3(0, 0.6, 0)
	var lt := lamp.create_tween()
	lt.tween_property(lamp, "light_energy", 7.0, 0.03 / speed)
	lt.tween_property(lamp, "light_energy", 1.5, 0.06 / speed)
	lt.tween_property(lamp, "light_energy", 4.0, 0.05 / speed)
	lt.tween_property(lamp, "light_energy", 0.0, 0.22 / speed)
	lt.tween_callback(lamp.queue_free)

	if camera_rig:
		camera_rig.shake(0.32, 0.26)
	AudioDirector.play_sfx(&"electric", 0.05)

## Tek şimşek katmanı: tepeden aşağı iner, faz kaydırmalı titrer, söner.
func _bolt_layer(base: Vector3, width_mul: float, color: Color, alpha: float,
		phase: int) -> void:
	var w := BOLT_H * BOLT_ASPECT * width_mul
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, BOLT_H)
	q.center_offset = Vector3(0, -BOLT_H * 0.5, 0)   # pivot TEPEDE → aşağı doğru büyür
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true   # yoksa billboard scale'i ezer, iniş animasyonu ölür
	m.albedo_texture = FX_LIGHTNING
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.no_depth_test = true
	# Katmanları ayna/kaydırma ile farklılaştır → üst üste bindirilmiş aynı görsel olmasın
	if phase == 2:
		m.uv1_scale = Vector3(-1.0, 1.0, 1.0)
		m.uv1_offset = Vector3(1.0, 0.0, 0.0)
	mi.material_override = m
	mi.position = base + Vector3(0, BOLT_H, 0)
	mi.scale = Vector3(1.0, 0.06, 1.0)
	_board.add_child(mi)

	var strike := mi.create_tween()
	strike.tween_property(mi, "scale", Vector3.ONE, 0.045 / speed) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# Faz kaydırmalı titreşim: her katman farklı ritimde → kaynayan elektrik
	var seq: Array = [[1.0, 0.2, 0.85, 0.1, 0.55], [0.6, 1.0, 0.15, 0.8, 0.3],
		[1.0, 0.45, 1.0, 0.25, 0.7]][phase]
	var tw := mi.create_tween()
	tw.tween_interval(0.03 / speed)
	for a: float in seq:
		tw.tween_property(m, "albedo_color:a", a * alpha, 0.045 / speed)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.1 / speed)
	tw.tween_callback(mi.queue_free)

## BOSS alev nefesi. Ağızdan hedefe doğru AÇILAN bir koni: sıra sıra alev puf'ları
## ağızdan başlayıp hedefe doğru gecikmeli patlar (nefesin ilerlediği okunur), ağızda
## dar ve beyaz-sıcak, hedefte geniş ve kızıl. Üstüne parçacık akışı, namlu parlaması,
## turuncu ışık ve hedefte tutuşma.
func _fire_breath(mouth: Vector3, dst_pos: Vector3) -> void:
	var aim := dst_pos + Vector3(0, 0.5, 0)
	var dir := aim - mouth
	var dist := maxf(dir.length(), 0.001)

	# --- koni gövdesi: hat boyunca büyüyen alev puf'ları ---
	const PUFFS := 9
	for i in PUFFS:
		var t := float(i) / float(PUFFS - 1)
		var pos := mouth.lerp(aim, t)
		var size := lerpf(0.3, 1.25, t)                       # ağızda dar, hedefte geniş
		var col := Color(1.0, 0.94, 0.68).lerp(Color(1.0, 0.32, 0.05), t)
		var mi := _fx_quad(FX_FIRE, col)
		_board.add_child(mi)
		mi.position = pos
		mi.scale = Vector3.ONE * size * 0.25
		var mat: StandardMaterial3D = mi.mesh.material
		var tw := mi.create_tween()
		tw.tween_interval(t * 0.10 / speed)                   # nefes ağızdan hedefe ilerler
		tw.tween_property(mi, "scale", Vector3.ONE * size, 0.07 / speed) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.11 / speed)
		tw.parallel().tween_property(mi, "scale", Vector3.ONE * size * 1.25, 0.2 / speed)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.2 / speed)
		tw.tween_callback(mi.queue_free)

	# --- namlu: ağızda sıcak parlama + turuncu ışık ---
	_flash(mouth, Color(1.0, 0.85, 0.5), 0.65)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.6, 0.25)
	lamp.light_energy = 0.0
	lamp.omni_range = 4.5
	lamp.shadow_enabled = false
	_board.add_child(lamp)
	lamp.position = mouth.lerp(aim, 0.35)
	var lt := lamp.create_tween()
	lt.tween_property(lamp, "light_energy", 5.0, 0.08 / speed)
	lt.tween_property(lamp, "light_energy", 0.0, 0.4 / speed)
	lt.tween_callback(lamp.queue_free)

	var p := GPUParticles3D.new()
	p.amount = 46
	p.lifetime = 0.42
	p.one_shot = true
	p.explosiveness = 0.35        # sürekli püskürtme hissi (hepsi aynı anda değil)
	p.position = mouth
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.12
	mat.direction = dir / dist
	mat.spread = 14.0
	mat.initial_velocity_min = dist / p.lifetime * 0.8
	mat.initial_velocity_max = dist / p.lifetime * 1.25
	mat.gravity = Vector3(0, 1.4, 0)   # kor yukarı kıvrılır
	mat.damping_min = 0.6
	mat.damping_max = 1.6
	mat.scale_min = 0.7
	mat.scale_max = 1.5
	var sc := Curve.new()               # uçarken şişip söner
	sc.add_point(Vector2(0, 0.35))
	sc.add_point(Vector2(0.45, 1.0))
	sc.add_point(Vector2(1, 0.2))
	var sct := CurveTexture.new()
	sct.curve = sc
	mat.scale_curve = sct
	var grad := Gradient.new()          # beyaz-sarı çekirdek → turuncu → koyu duman
	grad.set_color(0, Color(1.0, 0.95, 0.65, 1.0))
	grad.set_color(1, Color(0.55, 0.12, 0.03, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	mat.color_ramp = gt
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.34)
	var fm := _fx_material(FX_FIRE, Color(1.0, 0.72, 0.35))
	fm.vertex_color_use_as_albedo = true
	quad.material = fm
	p.draw_pass_1 = quad
	_board.add_child(p)
	p.emitting = true
	var t := p.create_tween()
	t.tween_interval(0.9)
	t.tween_callback(p.queue_free)

	# Hedefte tutuşma + sıcak flaş
	_flame(dst_pos, false)
	_flash(aim, Color(1.0, 0.72, 0.35), 1.0)
	_sparks(aim, Color(1.0, 0.6, 0.2), 1.4)
	AudioDirector.play_sfx(&"fire", 0.06)

## Sinerji/tabya çağrısı (Balatro "Kutsal Bağ ×1.4!"): gotik başlık, dramatik pop.
func _callout(world_pos: Vector3, text: String, color: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.013
	lbl.font = UITheme.display_font()
	lbl.font_size = 64
	lbl.outline_size = 22
	lbl.modulate = color
	_board.add_child(lbl)
	lbl.position = world_pos
	lbl.scale = Vector3.ONE * 0.1
	var pop := lbl.create_tween()
	pop.tween_property(lbl, "scale", Vector3.ONE * 1.2, 0.16 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(lbl, "scale", Vector3.ONE, 0.1 / speed)
	var fade := lbl.create_tween()
	fade.tween_interval(0.5 / speed)
	fade.tween_property(lbl, "position:y", lbl.position.y + 0.7, 0.55 / speed)
	fade.parallel().tween_property(lbl, "modulate:a", 0.0, 0.4 / speed).set_delay(0.2 / speed)
	fade.tween_callback(lbl.queue_free)

## Kat çarpanını kısa göster (1.5 / 2 / 0.75)
func _fmt_kat(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return "%.2f" % v

## En baskın Kat kaynağının adı (1.0'dan en çok sapan) — çağrıda isimlendirmek için
func _top_kat_name(lines: Array) -> String:
	var best := ""
	var best_dev := 0.0
	for l in lines:
		var dev: float = absf(float(l[1]) - 1.0)
		if dev > best_dev:
			best_dev = dev
			best = str(l[0])
	return best

## "Atla": kalan her şeyi anında uygula — final durum snapshot'ı (§17.2)
func _apply_final(result: Dictionary) -> void:
	for unit: CombatUnit in result["units"]:
		var view: PieceView = _views.get(unit.uid)
		if view == null:
			continue
		view.visible = unit.alive
		if unit.alive:
			if not unit.is_flag:   # bayrak görseli kaide sırasında — yerinden oynatma
				var base: Vector3 = _board.coord_to_world(unit.coord)
				view.position = Vector3(base.x, _board.tile_top_y(unit.coord), base.z)
			_hp[unit.uid] = unit.hp
			_update_label(unit.uid)
