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

var speed := 1.0
var _skip := false
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
		"STATUS":
			_set_status(e["target"], e["status"], e["stacks"])
		"STATUS_DAMAGE":
			var view: PieceView = _views.get(e["unit_id"])
			if view:
				_hp[e["unit_id"]] -= e["damage"]
				_update_label(e["unit_id"])
				var renk := COLOR_STATUS if e["status"] == "zehir" else COLOR_DAMAGE
				_spawn_number(view.position, "-%d %s" % [e["damage"], e["status"]], renk)
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
				_spawn_number(view.position + Vector3(0, 0.4, 0), "★ %s" % e["ad"], COLOR_TRAIT)
			await _delay(0.28)
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
	var tw := src.attack_lunge(dst.position, 0.34 / speed)
	await _delay(0.13)   # vuruş anı: hamlenin tepe noktası
	dst.hit_flash(0.3 / speed)
	_hp[e["dst"]] -= e["final"]
	_update_label(e["dst"])
	_spawn_number(dst.position, "-%d" % e["final"], COLOR_DAMAGE)
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

## Damage number (§16.6): billboard Label3D, scale-pop + yukarı süzül + sön
func _spawn_number(world_pos: Vector3, text: String, color: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.008
	lbl.font = UITheme.body_font()
	lbl.font_size = 64
	lbl.outline_size = 18
	lbl.modulate = color
	_board.add_child(lbl)
	lbl.position = world_pos + Vector3(0, 1.5, 0)
	lbl.scale = Vector3.ONE * 0.2
	var pop := lbl.create_tween()
	pop.tween_property(lbl, "scale", Vector3.ONE * 1.3, 0.1 / speed)
	pop.tween_property(lbl, "scale", Vector3.ONE, 0.08 / speed)
	var drift := lbl.create_tween()
	drift.tween_property(lbl, "position:y", lbl.position.y + 0.9, 0.75 / speed)
	drift.parallel().tween_property(lbl, "modulate:a", 0.0, 0.45 / speed).set_delay(0.3 / speed)
	drift.tween_callback(lbl.queue_free)

## "Atla": kalan her şeyi anında uygula — final durum snapshot'ı (§17.2)
func _apply_final(result: Dictionary) -> void:
	for unit: CombatUnit in result["units"]:
		var view: PieceView = _views.get(unit.uid)
		if view == null:
			continue
		view.visible = unit.alive
		if unit.alive:
			var base: Vector3 = _board.coord_to_world(unit.coord)
			view.position = Vector3(base.x, _board.tile_top_y(unit.coord), base.z)
			_hp[unit.uid] = unit.hp
			_update_label(unit.uid)
