extends Node3D
## BattleScreen — savaş sahnesi kökü (CLAUDE.md §17.5).
## Aşama 2: DEPLOYMENT FAZI — karttan birim seç, yeşil tile'a yerleştir,
## taşı / geri al, Mevzi (AP) ekonomisi. Düşman kurulumu sabit ve görünür.
## Aşama 3-4: CombatResolver + Presenter buraya bağlanacak.

const BG_COLOR := Color("0d0f1a")
const OVERLAY_GREEN := Color(0.3, 0.8, 0.45, 0.45)
const OVERLAY_YELLOW := Color(0.95, 0.8, 0.3, 0.85)
const OVERLAY_RED := Color(0.95, 0.18, 0.12, 0.85)    # telegraph: vurulacak tile
const OVERLAY_ORANGE := Color(0.9, 0.5, 0.15, 0.45)   # telegraph: düşman hareket hedefi

## Sabit düşman kurulumu (M0 tek savaş; M2'de EncounterData'ya taşınır)
const ENEMY_SETUP := {
	Vector2i(1, 3): &"pus_yuruyucu",
	Vector2i(4, 3): &"pus_yuruyucu",
	Vector2i(2, 3): &"zirhli",
	Vector2i(3, 4): &"nisanci",
}

## Sabit zemin yerleşimi (§7) — no-man's-land ağırlıklı; kutsal oyuncu bölgesinde
## (konumlama kararı yaratır). M2'de EncounterData'ya taşınır.
const TERRAIN_SETUP := {
	Vector2i(0, 2): &"duvar",
	Vector2i(2, 2): &"lav",
	Vector2i(3, 2): &"diken",
	Vector2i(5, 2): &"pus",
	Vector2i(1, 1): &"kutsal",
}

var board: BoardView
var camera_rig: CameraRig
var deployment: DeploymentLogic
var ui: DeploymentUI

enum Phase { DEPLOY, BATTLE, DONE }

var _squad: Array = []
var _coord_by_index: Dictionary = {}   # squad index -> Vector2i
var _views_by_index: Dictionary = {}   # squad index -> PieceView
var _enemy_views: Dictionary = {}      # Vector2i -> PieceView
var _selected := -1
var _hover: Variant = null             # Vector2i veya null
var _phase := Phase.DEPLOY
var _telegraph: Dictionary = {}        # Vector2i -> Color (düşman niyeti §11)

func _ready() -> void:
	_setup_environment()
	_setup_lights()
	_setup_camera()
	_setup_board()
	_squad = GameState.squad
	deployment = DeploymentLogic.new(GameState.mevzi)
	# Oyuncu bölgesindeki geçilmez zemin deploy'u da bloklar
	for coord: Vector2i in TERRAIN_SETUP:
		if BoardDefs.is_player_zone(coord) and TERRAIN_SETUP[coord] == &"duvar":
			deployment.occupied[coord] = true
	_setup_enemies()
	_setup_ui()
	_update_telegraph()
	# Görsel doğrulama/CI: --autobattle argümanıyla otomatik diz + savaş
	if "--autobattle" in OS.get_cmdline_user_args():
		_debug_autobattle.call_deferred()

# ------------------------------------------------------------------ kurulum

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.75)
	env.ambient_light_energy = 0.3
	# Glow AÇIK — emissive pop şart (§16.7)
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true   # bloklar arası derinlik (§16.7)
	env.ssao_intensity = 2.5
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	# Pus atmosferi + vinyet (§16.6): UI'ın altında tam ekran katman
	var fog_layer := CanvasLayer.new()
	fog_layer.layer = 0
	var fog := ColorRect.new()
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fog_mat := ShaderMaterial.new()
	fog_mat.shader = preload("res://shaders/fog_vignette.gdshader")
	fog.material = fog_mat
	fog_layer.add_child(fog)
	add_child(fog_layer)

func _setup_lights() -> void:
	# 1 sıcak anahtar ışık (üstten) + mor pus fill'i (§16.7) — moody kontrast
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.62)
	key.light_energy = 2.1
	key.rotation_degrees = Vector3(-55, -35, 0)
	key.shadow_enabled = true
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.5, 0.35, 0.75)
	fill.light_energy = 0.45
	fill.rotation_degrees = Vector3(-30, 140, 0)
	add_child(fill)

func _setup_camera() -> void:
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)

func _setup_board() -> void:
	board = BoardView.new()
	board.name = "BoardRoot"
	add_child(board)
	# İki Yükselti tile'ı (§7) — biri no-man's-land, biri düşman bölgesi
	board.build({
		Vector2i(1, 3): 1,
		Vector2i(4, 2): 1,
	})
	for coord: Vector2i in TERRAIN_SETUP:
		board.set_terrain(coord, TERRAIN_SETUP[coord])

## Resolver bağlamı: yükseklikler + zemin (saf mantık bunu okur)
func _ctx() -> Dictionary:
	return {"heights": board.height_map, "terrain": TERRAIN_SETUP}

## mesh_id doluysa sprite yolu (§16.5 billboard birim), boşsa kapsül
func _sprite_path(piece: PieceData) -> String:
	return "res://assets/%s.png" % piece.mesh_id if piece.mesh_id != &"" else ""

func _setup_enemies() -> void:
	for coord: Vector2i in ENEMY_SETUP:
		var data: PieceData = Database.get_resource("enemies", ENEMY_SETUP[coord])
		if data == null:
			push_warning("Düşman verisi yok: %s" % ENEMY_SETUP[coord])
			continue
		var view := PieceView.new()
		add_child(view)
		view.setup(&"ENEMY", data.stat_text(), 1.0 + 0.18 * (data.tier - 1), _sprite_path(data))
		var base := board.coord_to_world(coord)
		view.position = Vector3(base.x, board.tile_top_y(coord), base.z)
		_enemy_views[coord] = view

func _setup_ui() -> void:
	ui = DeploymentUI.new()
	add_child(ui)
	ui.build(_squad)
	ui.set_mevzi(deployment.mevzi)
	ui.card_pressed.connect(_on_card_pressed)
	ui.battle_pressed.connect(_on_battle_pressed)
	ui.restart_pressed.connect(func(): get_tree().reload_current_scene())

# ------------------------------------------------------------------ girdi

func _unhandled_input(event: InputEvent) -> void:
	if _phase != Phase.DEPLOY:
		return   # savaş sırasında deployment girdisi kapalı (kamera kendi handler'ında)
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_on_right_click(event.position)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_deselect()

func _raycast_tile(screen_pos: Vector2) -> Variant:
	var cam := camera_rig.camera
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider.has_meta("coord"):
		return hit.collider.get_meta("coord")
	return null

func _on_left_click(pos: Vector2) -> void:
	var coord = _raycast_tile(pos)
	if coord == null:
		return
	if _selected >= 0:
		_try_place(coord)
	elif _index_at(coord) >= 0:
		_pickup(coord)   # yerleşik birimi eline al (yeniden konumla)

func _on_right_click(pos: Vector2) -> void:
	if _selected >= 0:
		_deselect()
		return
	var coord = _raycast_tile(pos)
	if coord != null and _index_at(coord) >= 0:
		_recall(coord)

func _update_hover(pos: Vector2) -> void:
	var coord = _raycast_tile(pos)
	if coord == _hover:
		return
	_hover = coord
	_refresh_overlays()

# ------------------------------------------------------------------ deployment akışı

func _on_card_pressed(index: int) -> void:
	_selected = -1 if _selected == index else index
	ui.set_selected(_selected)
	_refresh_overlays()

func _index_at(coord: Vector2i) -> int:
	for i in _coord_by_index:
		if _coord_by_index[i] == coord:
			return i
	return -1

func _try_place(coord: Vector2i) -> void:
	var piece: PieceData = _squad[_selected]
	if not deployment.place(piece.mevzi_maliyeti, coord):
		return
	var view := PieceView.new()
	add_child(view)
	view.setup(piece.class_key(), piece.stat_text(), 1.0, _sprite_path(piece))
	var base := board.coord_to_world(coord)
	view.position = Vector3(base.x, board.tile_top_y(coord), base.z)
	_coord_by_index[_selected] = coord
	_views_by_index[_selected] = view
	ui.set_card_deployed(_selected, true)
	ui.set_mevzi(deployment.mevzi)
	EventBus.piece_deployed.emit(piece.id, coord)
	EventBus.mevzi_changed.emit(deployment.mevzi)
	AudioDirector.play_sfx(&"deploy_clunk")   # ses dosyası bağlanınca çalar (§20)
	ui.battle_button.disabled = false
	_deselect()
	_update_telegraph()

func _remove_piece(coord: Vector2i) -> int:
	var index := _index_at(coord)
	if index < 0:
		return -1
	var piece: PieceData = _squad[index]
	deployment.remove(piece.mevzi_maliyeti, coord)
	_views_by_index[index].queue_free()
	_views_by_index.erase(index)
	_coord_by_index.erase(index)
	ui.set_card_deployed(index, false)
	ui.set_mevzi(deployment.mevzi)
	EventBus.piece_recalled.emit(piece.id)
	EventBus.mevzi_changed.emit(deployment.mevzi)
	ui.battle_button.disabled = _coord_by_index.is_empty()
	_update_telegraph()
	return index

func _pickup(coord: Vector2i) -> void:
	var index := _remove_piece(coord)
	if index >= 0:
		_selected = index
		ui.set_selected(index)
		_refresh_overlays()

func _recall(coord: Vector2i) -> void:
	if _remove_piece(coord) >= 0:
		_refresh_overlays()

func _deselect() -> void:
	_selected = -1
	ui.set_selected(-1)
	_refresh_overlays()

## Overlay önceliği: sarı hover > kırmızı telegraph > yeşil geçerli tile
func _refresh_overlays() -> void:
	board.clear_overlays()
	if _phase != Phase.DEPLOY:
		return
	for coord: Vector2i in _telegraph:
		board.set_overlay(coord, _telegraph[coord])
	if _selected < 0:
		return
	var piece: PieceData = _squad[_selected]
	for row in BoardDefs.PLAYER_ROWS:
		for col in BoardDefs.COLS:
			var coord := Vector2i(col, row)
			if not deployment.can_place(piece.mevzi_maliyeti, coord):
				continue
			if _hover != null and coord == _hover:
				board.set_overlay(coord, OVERLAY_YELLOW)
			elif not _telegraph.has(coord):
				board.set_overlay(coord, OVERLAY_GREEN)

# ------------------------------------------------------------------ telegraph (§11)

## Düşman niyetleri: determinizm sayesinde GERÇEK önizleme — mevcut kurulum
## klon birimlerle çözülür, 1. turdaki düşman hamleleri okunur.
## Kırmızı = vurulacak dostunun tile'ı, turuncu = düşmanın yürüyeceği tile.
func _update_telegraph() -> void:
	_telegraph.clear()
	for view: PieceView in _enemy_views.values():
		view.set_status_text("")
	if _coord_by_index.is_empty():
		_refresh_overlays()
		return
	var built := _build_units()
	var result := CombatResolver.resolve(built["units"], _ctx())
	var moves: Dictionary = {}    # düşman uid -> hedef koordinat
	var attacks: Dictionary = {}  # düşman uid -> vurulan dostun deploy koordinatı
	var round_count := 0
	for e: Dictionary in result["events"]:
		if e["t"] == "ROUND_START":
			round_count += 1
			if round_count >= 2:
				break
		elif e["t"] == "MOVE" and built["enemy_uids"].has(e["unit_id"]) \
				and not moves.has(e["unit_id"]):
			moves[e["unit_id"]] = e["to"]
		elif e["t"] == "ATTACK" and built["enemy_uids"].has(e["src"]) \
				and built["player_coords"].has(e["dst"]) and not attacks.has(e["src"]):
			attacks[e["src"]] = built["player_coords"][e["dst"]]
	for uid in moves:
		_telegraph[moves[uid]] = OVERLAY_ORANGE
	for uid in attacks:
		_telegraph[attacks[uid]] = OVERLAY_RED   # kırmızı turuncuyu ezer
	# Düşman üstünde niyet metni: "→C3  ⚔B2"
	for uid in built["enemy_uids"]:
		var parts: Array[String] = []
		if moves.has(uid):
			parts.append("→%s" % BoardDefs.coord_name(moves[uid]))
		if attacks.has(uid):
			parts.append("⚔%s" % BoardDefs.coord_name(attacks[uid]))
		if not parts.is_empty():
			(built["enemy_uids"][uid] as PieceView).set_status_text("  ".join(parts))
	_refresh_overlays()

## Mevcut kurulumdan CombatUnit listesi + eşlemeler (telegraph ve savaş ortak)
func _build_units() -> Dictionary:
	var units: Array = []
	var views: Dictionary = {}          # uid -> PieceView
	var player_coords: Dictionary = {}  # oyuncu uid -> deploy koordinatı
	var enemy_uids: Dictionary = {}     # düşman uid -> PieceView
	var uid := 0
	var indices := _coord_by_index.keys()
	indices.sort()
	for i: int in indices:
		uid += 1
		units.append(CombatUnit.from_piece(_squad[i], CombatResolver.SIDE_PLAYER, _coord_by_index[i], uid))
		views[uid] = _views_by_index[i]
		player_coords[uid] = _coord_by_index[i]
	var enemy_coords := _enemy_views.keys()
	enemy_coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for coord: Vector2i in enemy_coords:
		uid += 1
		units.append(CombatUnit.from_piece(
			Database.get_resource("enemies", ENEMY_SETUP[coord]),
			CombatResolver.SIDE_ENEMY, coord, uid))
		views[uid] = _enemy_views[coord]
		enemy_uids[uid] = _enemy_views[coord]
	return {"units": units, "views": views, "player_coords": player_coords, "enemy_uids": enemy_uids}

# ------------------------------------------------------------------ savaş akışı

## "SAVAŞ" (§3.2): geri dönüş yok. Kurulum → CombatUnit'ler → resolve → playback.
func _on_battle_pressed() -> void:
	if _phase != Phase.DEPLOY or _coord_by_index.is_empty():
		return
	_phase = Phase.BATTLE
	_deselect()
	_telegraph.clear()
	board.clear_overlays()
	for view: PieceView in _enemy_views.values():
		view.set_status_text("")   # niyet metinleri temizlenir; savaşta statüler yazar

	var built := _build_units()
	var units: Array = built["units"]
	var views: Dictionary = built["views"]

	# Savaş başı anlık görüntü (presenter etiketleri bununla günceller;
	# resolver units'i yerinde mutasyona uğratır)
	var info: Dictionary = {}
	for u: CombatUnit in units:
		info[u.uid] = {"ad": u.ad, "atk": u.atk, "spd": u.spd, "hp": u.hp, "max_hp": u.max_hp}

	var result := CombatResolver.resolve(units, _ctx(), GameState.run_seed)

	ui.enter_battle_mode()
	EventBus.battle_started.emit()
	AudioDirector.play_sfx(&"battle_start")

	var presenter := CombatPresenter.new()
	add_child(presenter)
	presenter.round_changed.connect(ui.set_round)
	ui.speed_selected.connect(presenter.set_speed)
	ui.skip_pressed.connect(presenter.request_skip)
	presenter.finished.connect(_on_battle_finished)
	presenter.play(result, views, board, info)

func _on_battle_finished(kazanan: String) -> void:
	_phase = Phase.DONE
	var player_won := kazanan == "PLAYER"
	ui.show_result(player_won)
	EventBus.battle_finished.emit(player_won)
	AudioDirector.play_sfx(&"victory" if player_won else &"defeat")

## --autobattle: sabit dizilişle otomatik savaş (görsel doğrulama için)
func _debug_autobattle() -> void:
	var spots: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 0), Vector2i(4, 1), Vector2i(3, 0)]
	for i in _squad.size():
		_selected = i
		_try_place(spots[i])
	await get_tree().create_timer(0.4).timeout
	_on_battle_pressed()
