extends Node3D
## BattleScreen — savaş sahnesi kökü (CLAUDE.md §17.5).
## Aşama 2: DEPLOYMENT FAZI — karttan birim seç, yeşil tile'a yerleştir,
## taşı / geri al, Mevzi (AP) ekonomisi. Düşman kurulumu sabit ve görünür.
## Aşama 3-4: CombatResolver + Presenter buraya bağlanacak.

const BG_COLOR := Color("0d0f1a")

## Encounter -> üst bar başlığı
const _ENC_TITLE := {
	&"kolay": "SAVAŞ", &"orta": "SAVAŞ", &"orta2": "SAVAŞ",
	&"elit": "ELİT SAVAŞ", &"boss": "BOSS SAVAŞI",
}
const OVERLAY_GREEN := Color(0.3, 0.8, 0.45, 0.45)
const OVERLAY_YELLOW := Color(0.95, 0.8, 0.3, 0.85)
const OVERLAY_RED := Color(0.95, 0.18, 0.12, 0.85)    # telegraph: vurulacak tile
const OVERLAY_ORANGE := Color(0.9, 0.5, 0.15, 0.45)   # telegraph: düşman hareket hedefi

## Savaş kurulumu artık Encounter'dan beslenir (§23): GameState.current_encounter
## hangi düşman / zemin / yükselti / altın setinin yükleneceğini belirler.
## Elle tasarlı setler için bkz. Encounters.DEFS.
var _enemy_setup: Dictionary = {}     # Vector2i -> düşman id
var _terrain_setup: Dictionary = {}   # Vector2i -> zemin tipi
var _heights: Dictionary = {}         # Vector2i -> yükseklik
var _enc_gold := 0                    # zafer altını (ödül akışı bunu kullanır)

var board: BoardView
var camera_rig: CameraRig
var deployment: DeploymentLogic
var ui: DeploymentUI

enum Phase { DEPLOY, PLANNING, RESOLVING, DONE }

## Tur-tur savaş durumu (§B.0/3)
var _units: Array = []                  # kalıcı CombatUnit listesi
var _combat_state: Dictionary = {}      # diken vb. tur-arası korunan
var _round := 0
var _presenter: CombatPresenter
var _uid_next := 0
var _committed: Dictionary = {}         # squad index -> uid (savaşa girmiş birim)
var _view_by_uid: Dictionary = {}       # uid -> PieceView
const AP_REGEN := 3                      # tur başı yenilenen Mevzi
const AP_MAX := 12

## Kumandanlar (§B.0/4): 2 kumandan, farklı yetenek. GameState.commander_id seçer.
const COMMANDERS := {
	&"cesur": {"ad": "Cesur Serdar", "yetenek": "⚡ Yıldırım", "tip": "bolt", "deger": 6, "cd": 2},
	&"bilge": {"ad": "Bilge Kâhin", "yetenek": "✚ Şifa Dalgası", "tip": "heal", "deger": 5, "cd": 3},
}
var _cmd: Dictionary = COMMANDERS[&"cesur"]
var _cmd_cd := 0
var _targeting := false                   # kumandan hedefleme modu
var _last_won := false                    # savaş sonucu (haritaya dönüşte ilerleme)

var _squad: Array = []
var _coord_by_index: Dictionary = {}   # squad index -> Vector2i
var _views_by_index: Dictionary = {}   # squad index -> PieceView
var _enemy_views: Dictionary = {}      # Vector2i -> PieceView
var _player_flag_coord: Vector2i       # bayraklar (§B.0/1)
var _enemy_flag_coord: Vector2i
var _enemy_flag_hp := 20
var _player_flag_view: PieceView
var _enemy_flag_view: PieceView
var _battle_player_flag: CombatUnit    # savaş sonu kalan CAN'ı okumak için
var _selected := -1
var _hand: HandCursor                  # deployment "tanrı eli" (grab/drop animasyonu)
var _hover: Variant = null             # Vector2i veya null
var _phase := Phase.DEPLOY
var _telegraph: Dictionary = {}        # Vector2i -> Color (düşman niyeti §11)

func _ready() -> void:
	_load_encounter()
	_setup_environment()
	_setup_ambient_particles()
	_setup_lights()
	_setup_camera()
	_setup_board()
	_squad = GameState.squad
	deployment = DeploymentLogic.new(GameState.mevzi)
	# Oyuncu bölgesindeki geçilmez zemin deploy'u da bloklar
	for coord: Vector2i in _terrain_setup:
		if BoardDefs.is_player_zone(coord) and _terrain_setup[coord] == &"duvar":
			deployment.occupied[coord] = true
	_setup_enemies()
	_setup_flags()
	_setup_ui()
	_update_telegraph()
	AudioDirector.play_music()   # atmosferik savaş müziği (döngü)
	# Görsel doğrulama/CI: --autobattle argümanıyla otomatik diz + savaş
	if "--autobattle" in OS.get_cmdline_user_args():
		_debug_autobattle.call_deferred()
	# El (grab) görsel doğrulaması: karttan seçimi kodla tetikle
	if "--handtest" in OS.get_cmdline_user_args():
		(func() -> void: _on_card_pressed(0)).call_deferred()
	# Döküm paneli görsel doğrulaması: birim diz + hover
	if "--bdtest" in OS.get_cmdline_user_args():
		_debug_breakdown.call_deferred()

func _debug_breakdown() -> void:
	_selected = 0
	_try_place(Vector2i(2, 1))
	await get_tree().create_timer(1.0).timeout
	_hover = Vector2i(2, 1)
	_refresh_breakdown()

# ------------------------------------------------------------------ kurulum

## Aktif encounter'ı GameState'ten çöz ve setleri yükle (§23). Kopyalarız —
## Encounters.DEFS sabit veri, savaş içinde mutasyona uğramamalı.
func _load_encounter() -> void:
	var enc := Encounters.get_def(GameState.current_encounter)
	_enemy_setup = enc["enemies"].duplicate()
	_terrain_setup = enc["terrain"].duplicate()
	_heights = enc["heights"].duplicate()
	_enc_gold = enc.get("gold", 0)

## Ambient toz zerreleri — yavaş süzülen altın motes (atmosfer, referans hissi)
func _setup_ambient() -> void:
	var p := GPUParticles3D.new()
	p.amount = 70
	p.lifetime = 9.0
	p.preprocess = 5.0
	p.position = Vector3(0, 1.4, 0)
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(4.5, 2.2, 4.0)
	mat.direction = Vector3(0.2, 1.0, 0.0)
	mat.spread = 35.0
	mat.initial_velocity_min = 0.04
	mat.initial_velocity_max = 0.14
	mat.gravity = Vector3(0, 0.015, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.3
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.albedo_color = Color(0.85, 0.74, 0.42, 0.5)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = dm
	p.draw_pass_1 = quad
	add_child(p)

func _setup_environment() -> void:
	# Arka plan: koyu mavi-gri radyal gradyan (referans hissi) — BG_CANVAS ile
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = preload("res://shaders/bg_gradient.gdshader")
	bg.material = bg_mat
	bg_layer.add_child(bg)
	add_child(bg_layer)

	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.40, 0.42, 0.55)
	env.ambient_light_energy = 0.22
	# Glow AÇIK ama KISIK — efektler pop'lar, sahne fazla parlamaz (referans mat ton)
	env.glow_enabled = true
	env.glow_intensity = 0.42
	env.glow_bloom = 0.015
	env.glow_hdr_threshold = 1.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Renk düzeltme (§referans): DESATÜRASYON + hafif koyulaştırma → moody/mat
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.94
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.80
	env.ssao_enabled = true   # sadece blok aralarında ince derinlik (§16.7)
	env.ssao_intensity = 0.85   # düz çim üstünde muddy gölge yapmasın
	env.ssao_radius = 0.45      # yalnız yakın köşe/oyuklar
	env.ssao_power = 2.2        # çabuk sönümlensin, geniş leke bırakmasın
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

## Atmosfer: board çevresinde ağır ağır süzülen küçük kor/toz zerreleri (Onur:
## "küçük partiküller"). Additive + glow → hafif parıltı; türbülansla organik gezinir.
func _setup_ambient_particles() -> void:
	var p := GPUParticles3D.new()
	p.amount = 64
	p.lifetime = 11.0
	p.preprocess = 8.0          # sahne açılınca zaten dağılmış olsun
	p.randomness = 1.0
	p.local_coords = false
	p.position = Vector3(0.0, 2.2, -0.5)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(7.5, 3.6, 6.0)
	pm.direction = Vector3(0.15, 1.0, 0.0)
	pm.spread = 28.0
	pm.gravity = Vector3(0.0, 0.03, 0.0)   # neredeyse yerçekimsiz, yavaş yükseliş
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.30
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 1.2
	pm.color = Color(1.0, 0.82, 0.55, 0.45)   # sıcak kor tonu (soğuk bg'ye kontrast)
	# ömür boyu alfa: yumuşak gir → sabit → yumuşak çık
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.18, 1.0))
	curve.add_point(Vector2(0.8, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new(); ct.curve = curve
	pm.alpha_curve = ct
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.albedo_texture = preload("res://assets/fx/spark.png")
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.vertex_color_use_as_albedo = true
	quad.material = dm
	p.draw_pass_1 = quad
	add_child(p)

func _setup_lights() -> void:
	# 1 sıcak anahtar ışık (üstten) + mor pus fill'i (§16.7) — moody kontrast
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.88, 0.68)
	key.light_energy = 1.65   # kısık (referans mat/moody ton — fazla parlamasın)
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
	# Yükselti tile'ları encounter'dan (§7)
	board.build(_heights)
	for coord: Vector2i in _terrain_setup:
		board.set_terrain(coord, _terrain_setup[coord])
	board.play_intro()   # kurulum animasyonu: tile'lar dalga hâlinde yükselir

## Bir birim/bayrak görselini kendi tile'ının dalgasıyla senkron pop yaptır.
func _intro_pop(node: Node3D, coord: Vector2i) -> void:
	var target := node.scale
	node.scale = Vector3.ZERO
	var tw := node.create_tween()
	tw.tween_property(node, "scale", target, 0.5) \
		.set_delay(board.intro_delay(coord) + 0.46) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Resolver bağlamı: yükseklikler + zemin + HIZ-eşitliği zarı için seed'li RNG.
## RNG her çağrıda AYNI savaş-sabit seed'le TAZE kurulur → telegraph önizlemesi
## ve gerçek savaş aynı zarları atar; aynı kurulum = aynı sonuç (determinizm §1.2).
func _ctx() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.run_seed ^ hash(GameState.current_encounter) ^ (GameState.layer_index << 16)
	return {"heights": board.height_map, "terrain": _terrain_setup,
		"relics": GameState.relics, "rng": rng}

## mesh_id doluysa sprite yolu (§16.5 billboard birim), boşsa kapsül
func _sprite_path(piece: PieceData) -> String:
	return "res://assets/units/%s.png" % piece.mesh_id if piece.mesh_id != &"" else ""

func _setup_enemies() -> void:
	for coord: Vector2i in _enemy_setup:
		var data: PieceData = Database.get_resource("enemies", _enemy_setup[coord])
		if data == null:
			push_warning("Düşman verisi yok: %s" % _enemy_setup[coord])
			continue
		var view := PieceView.new()
		add_child(view)
		view.setup(&"ENEMY", data.stat_text(), 1.0 + 0.18 * (data.tier - 1), _sprite_path(data))
		var base := board.coord_to_world(coord)
		view.position = Vector3(base.x, board.tile_top_y(coord), base.z)
		_enemy_views[coord] = view
		_intro_pop(view, coord)

## Bayraklar (§B.0/1): oyuncu arka satırı (0) + düşman arka satırı (son).
## Zafer = düşman bayrağını yık. Oyuncu bayrağı CAN'ı kalıcı (GameState).
func _setup_flags() -> void:
	_enemy_flag_hp = Encounters.flag_hp(GameState.current_encounter)
	_player_flag_coord = _free_tile_in_row(0, {})
	var avoid := {}
	for c: Vector2i in _enemy_setup:
		avoid[c] = true
	for c: Vector2i in _terrain_setup:
		if _terrain_setup[c] == &"duvar":
			avoid[c] = true
	_enemy_flag_coord = _free_tile_in_row(BoardDefs.ROWS - 1, avoid)
	deployment.occupied[_player_flag_coord] = true   # bayrak tile'ı deploy'a kapalı
	_player_flag_view = _make_flag_view(_player_flag_coord, true, GameState.player_flag_hp)
	_enemy_flag_view = _make_flag_view(_enemy_flag_coord, false, _enemy_flag_hp)
	if OS.get_cmdline_user_args().has("--debug-flagtile"):
		get_tree().create_timer(2.0).timeout.connect(_debug_flag_geometry)

## Satırda merkezden dışa doğru ilk boş (avoid'da olmayan) tile
func _free_tile_in_row(row: int, avoid: Dictionary) -> Vector2i:
	for c in [3, 2, 4, 1, 5, 0]:
		var coord := Vector2i(c, row)
		if not avoid.has(coord):
			return coord
	return Vector2i(3, row)

## Hata ayıklama: bayrak tabanının ve durduğu tile'ın üst-yüz elmasının EKRAN
## koordinatlarını bastırır. "Bayrak tile'ın ortasında değil" iddiasını göz kararı
## yerine pikselle doğrulamak için (--debug-flagtile).
func _debug_flag_geometry() -> void:
	var cam := camera_rig.camera
	for entry in [[Vector2i(_player_flag_coord.x, -1), _player_flag_view, "MAVI"],
			[_enemy_flag_coord, _enemy_flag_view, "KIRMIZI"]]:
		var vc: Vector2i = entry[0]
		var view: PieceView = entry[1]
		var base := board.coord_to_world(vc)
		var top_y := board.tile_top_y(vc)
		var center := Vector3(base.x, top_y, base.z)
		# Elmasın 4 köşesi (tile üst yüzü, kenar uzunluğu TILE_SIZE)
		var h := BoardView.TILE_SIZE * 0.5
		var corners := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
		var ys: Array[float] = []
		for c: Vector3 in corners:
			ys.append(cam.unproject_position(center + c).y)
		ys.sort()
		var diamond_mid := (ys[0] + ys[3]) * 0.5
		print("[%s] tile merkez ekran=%s | elmas dikey orta=%.1f (tepe %.1f, dip %.1f)" % [
			entry[2], cam.unproject_position(center), diamond_mid, ys[0], ys[3]])
		print("      bayrak taban ekran=%s  => taban - elmasOrta = %.1f px" % [
			cam.unproject_position(view.position), cam.unproject_position(view.position).y - diamond_mid])

## Boss düğümlerinde düşman bayrağının YERİNE ejderha durur — zafer koşulu aynı
## (§B.0/1: karşı bayrağı yık). Ejderha ayrıca saldırır ve tutuşturur (CombatUnit.make_boss).
const BOSS_ENCOUNTERS: Array[StringName] = [&"boss", &"boss2"]
const BOSS_ATK := 6
const BOSS_SPD := 5

func _is_boss_encounter() -> bool:
	return GameState.current_encounter in BOSS_ENCOUNTERS

## Düşman tarafının "yıkılacak hedefi": normal savaşta bayrak, boss'ta ejderha
func _make_enemy_anchor(uid: int) -> CombatUnit:
	if _is_boss_encounter():
		return CombatUnit.make_boss(CombatResolver.SIDE_ENEMY, _enemy_flag_coord,
			_enemy_flag_hp, uid, BOSS_ATK, BOSS_SPD, "Ejderha")
	return CombatUnit.make_flag(CombatResolver.SIDE_ENEMY, _enemy_flag_coord,
		_enemy_flag_hp, uid, "Düşman Bayrağı")

func _make_flag_view(coord: Vector2i, side_blue: bool, hp: int) -> PieceView:
	var view := PieceView.new()
	add_child(view)
	if not side_blue and _is_boss_encounter():
		view.setup_boss(hp)
		var b := board.coord_to_world(coord)
		view.position = Vector3(b.x, board.tile_top_y(coord), b.z)
		_intro_pop(view, coord)
		return view
	view.setup_flag(side_blue, hp)
	# Oyuncu bayrağı GÖRSELDE ön kaide sırasında (satır −1) durur;
	# mantık koordinatı (satır 0) değişmez — determinizm/hedefleme aynı.
	var vis_coord := Vector2i(coord.x, -1) if side_blue else coord
	var base := board.coord_to_world(vis_coord)
	view.position = Vector3(base.x, board.tile_top_y(vis_coord), base.z)
	_intro_pop(view, vis_coord)
	return view

func _setup_ui() -> void:
	ui = DeploymentUI.new()
	add_child(ui)
	ui.build(_squad)
	ui.set_mevzi(deployment.mevzi)
	ui.set_gold(GameState.gold)
	ui.set_title(_ENC_TITLE.get(GameState.current_encounter, "SAVAŞ"))
	_cmd = COMMANDERS.get(GameState.commander_id, COMMANDERS[&"cesur"])
	ui.set_commander_name(_cmd["yetenek"])
	ui.card_pressed.connect(_on_card_pressed)
	ui.battle_pressed.connect(_on_end_turn)
	ui.commander_pressed.connect(_on_commander)
	ui.restart_pressed.connect(func(): EventBus.return_to_map.emit(_last_won))
	_hand = HandCursor.new()
	add_child(_hand)

# ------------------------------------------------------------------ girdi

func _unhandled_input(event: InputEvent) -> void:
	if _phase != Phase.DEPLOY and _phase != Phase.PLANNING:
		return   # tur çözülürken deployment girdisi kapalı (kamera kendi handler'ında)
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_on_right_click(event.position)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_deselect()

## El bir birim taşırken tile etkileşimi FARE değil, modelin AYAK (alt-orta) noktasından
## yapılır (Onur): kullanıcı, taşın alt ucunun durduğu tile'a bırakır. El yoksa fare aynen.
func _drop_point(screen_pos: Vector2) -> Vector2:
	if _hand and _hand.is_active():
		return screen_pos + _hand.foot_offset()
	return screen_pos

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
	var coord = _raycast_tile(_drop_point(pos))
	if coord == null:
		return
	if _targeting:
		_commander_target(coord)
		return
	if _selected >= 0:
		_try_place(coord)
	elif _index_at(coord) >= 0:
		_pickup(coord)   # yerleşik birimi eline al (yeniden konumla)

func _on_right_click(pos: Vector2) -> void:
	if _targeting:
		_cancel_targeting()
		return
	if _selected >= 0:
		_deselect()
		return
	var coord = _raycast_tile(pos)
	if coord != null and _index_at(coord) >= 0:
		_recall(coord)

func _update_hover(pos: Vector2) -> void:
	var coord = _raycast_tile(_drop_point(pos))
	if coord == _hover:
		return
	_hover = coord
	_refresh_overlays()
	_refresh_breakdown()

## Yerleşik bir oyuncu birimi üzerine gelince canlı Güç×Kat dökümünü göster (§19).
## Önizleme _build_units() üzerinden — sinerji/zemin/relic gerçek savaşla aynı.
func _refresh_breakdown() -> void:
	if _hover == null or _index_at(_hover) < 0:
		ui.hide_breakdown()
		return
	var built := _build_units()
	var hovered: CombatUnit = null
	for u: CombatUnit in built["units"]:
		if not u.is_flag and u.side == CombatResolver.SIDE_PLAYER and u.coord == _hover:
			hovered = u
			break
	if hovered == null:
		ui.hide_breakdown()
		return
	var bd := CombatResolver.compute_breakdown(hovered, null, built["units"], _ctx())
	# Birimin ekran pozisyonu → panel birimin yanında açılır (§19 canlı döküm)
	var world := board.coord_to_world(_hover)
	var anchor := camera_rig.camera.unproject_position(
		Vector3(world.x, board.tile_top_y(_hover) + 0.7, world.z))
	ui.show_breakdown(hovered.ad, bd, anchor)

# ------------------------------------------------------------------ deployment akışı

func _on_card_pressed(index: int) -> void:
	_selected = -1 if _selected == index else index
	ui.set_selected(_selected)
	if _selected >= 0:
		_grab_selected()
	else:
		_hand.cancel()
	_refresh_overlays()

## Seçili birim için "tanrı eli" kavrama animasyonunu başlat
func _grab_selected() -> void:
	if _selected < 0:
		return
	var piece: PieceData = _squad[_selected]
	var tex := _carry_texture(piece)
	var tint: Color = PieceView.CLASS_COLORS.get(piece.class_key(), Color.GRAY)
	_hand.grab(tex, tint, get_viewport().get_mouse_position())

## Taşıma önizlemesi için birim dokusu (mesh_id sprite'ı) — kapsülse null
func _carry_texture(piece: PieceData) -> Texture2D:
	var path := _sprite_path(piece)
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null

func _index_at(coord: Vector2i) -> int:
	for i in _coord_by_index:
		if _coord_by_index[i] == coord:
			return i
	return -1

func _try_place(coord: Vector2i) -> void:
	var piece: PieceData = _squad[_selected]
	if not deployment.place(piece.mevzi_maliyeti, coord):
		return
	var idx := _selected
	# El hedefe gidip birimi "bırakınca" gerçek PieceView sahnede pop eder.
	var base := board.coord_to_world(coord)
	var rest := Vector3(base.x, board.tile_top_y(coord), base.z)
	var drop := func() -> void:
		var view := PieceView.new()
		add_child(view)
		view.setup(piece.class_key(), piece.stat_text(), 1.0, _sprite_path(piece))
		view.position = rest
		_drop_in(view, rest)
		_coord_by_index[idx] = coord
		_views_by_index[idx] = view
		ui.set_card_deployed(idx, true)
		EventBus.piece_deployed.emit(piece.id, coord)
		AudioDirector.play_sfx(&"deploy_clunk")   # ses dosyası bağlanınca çalar (§20)
		_update_telegraph()
	# Grip'i, modelin AYAĞI tile tepesine oturacak şekilde hedefle (foot_offset kadar
	# yukarıda) — böylece bırakma anında el yukarı zıplamaz, ayak seçilen tile'da kalır.
	var grip_screen := camera_rig.camera.unproject_position(rest) - _hand.foot_offset()
	_hand.release(grip_screen, drop)
	ui.set_mevzi(deployment.mevzi)
	EventBus.mevzi_changed.emit(deployment.mevzi)
	ui.battle_button.disabled = false
	# El bırakma animasyonunu yürütür; seçim durumunu sessizce temizle
	_selected = -1
	ui.set_selected(-1)
	_refresh_overlays()

## Yerleştirilen birim yukarıdan tile'a "düşer" (el bırakmasıyla senkron)
func _drop_in(view: PieceView, rest: Vector3) -> void:
	view.position = rest + Vector3(0, 0.7, 0)
	view.scale = Vector3.ONE * 1.12
	var tw := view.create_tween().set_parallel(true)
	tw.tween_property(view, "position", rest, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(view, "scale", Vector3.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _remove_piece(coord: Vector2i) -> int:
	var index := _index_at(coord)
	if index < 0 or _committed.has(index):
		return -1   # savaşa girmiş birim geri alınamaz/taşınamaz (§B.0/3)
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
		_grab_selected()   # yerleşik birimi de el kaldırır (yeniden konumla)
		_refresh_overlays()

func _recall(coord: Vector2i) -> void:
	if _remove_piece(coord) >= 0:
		_refresh_overlays()

func _deselect() -> void:
	_selected = -1
	ui.set_selected(-1)
	if _hand:
		_hand.cancel()
	_refresh_overlays()

## Overlay önceliği: sarı hover > kırmızı telegraph > yeşil geçerli tile
func _refresh_overlays() -> void:
	board.clear_overlays()
	if _phase != Phase.DEPLOY and _phase != Phase.PLANNING:
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
	if _phase != Phase.DEPLOY:
		return   # tur-tur savaşta önizleme yok (canlı statüler korunur)
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
			Database.get_resource("enemies", _enemy_setup[coord]),
			CombatResolver.SIDE_ENEMY, coord, uid))
		views[uid] = _enemy_views[coord]
		enemy_uids[uid] = _enemy_views[coord]
	# Bayraklar (§B.0/1): hareketsiz hedefler. Oyuncu bayrağı player_coords'a
	# eklenir ki telegraph ona yapılacak saldırıyı da işaretleyebilsin.
	uid += 1
	var pflag := CombatUnit.make_flag(CombatResolver.SIDE_PLAYER, _player_flag_coord,
		GameState.player_flag_hp, uid, "Oyuncu Bayrağı")
	units.append(pflag)
	views[uid] = _player_flag_view
	player_coords[uid] = _player_flag_coord
	uid += 1
	units.append(_make_enemy_anchor(uid))
	views[uid] = _enemy_flag_view
	return {"units": units, "views": views, "player_coords": player_coords,
		"enemy_uids": enemy_uids, "player_flag": pflag}

# ------------------------------------------------------------------ savaş akışı

## "TUR ✓" (§B.0/3): bu turda dizilen takviyeleri bağla → 1 tur çöz → planlama.
func _on_end_turn() -> void:
	if _phase != Phase.DEPLOY and _phase != Phase.PLANNING:
		return
	if _phase == Phase.DEPLOY:
		if _coord_by_index.is_empty():
			return   # ilk tur en az 1 birim gerek
		_start_battle()
	_phase = Phase.RESOLVING
	_deselect()
	_telegraph.clear()
	board.clear_overlays()
	ui.hide_breakdown()
	for view: PieceView in _enemy_views.values():
		view.set_status_text("")
	ui.enter_battle_mode()
	await _run_turn()

func _info_of(u: CombatUnit) -> Dictionary:
	return {"ad": u.ad, "atk": u.atk, "spd": u.spd, "hp": u.hp, "max_hp": u.max_hp,
		"sinif": u.sinif, "piece_id": u.piece_id}

## Düşmanları + bayrakları CombatUnit olarak kur, presenter'ı bir kez ayarla
func _start_battle() -> void:
	_units = []
	_combat_state = {"diken": {}}
	_uid_next = 0
	_committed = {}
	_view_by_uid = {}
	var enemy_coords := _enemy_views.keys()
	enemy_coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for coord: Vector2i in enemy_coords:
		_uid_next += 1
		_units.append(CombatUnit.from_piece(
			Database.get_resource("enemies", _enemy_setup[coord]),
			CombatResolver.SIDE_ENEMY, coord, _uid_next))
		_view_by_uid[_uid_next] = _enemy_views[coord]
	_uid_next += 1
	_battle_player_flag = CombatUnit.make_flag(CombatResolver.SIDE_PLAYER,
		_player_flag_coord, GameState.player_flag_hp, _uid_next, "Oyuncu Bayrağı")
	_units.append(_battle_player_flag)
	_view_by_uid[_uid_next] = _player_flag_view
	_uid_next += 1
	_units.append(_make_enemy_anchor(_uid_next))
	_view_by_uid[_uid_next] = _enemy_flag_view
	_presenter = CombatPresenter.new()
	_presenter.camera_rig = camera_rig   # kritik vuruşta ekran sarsıntısı
	add_child(_presenter)
	_presenter.round_changed.connect(ui.set_round)
	_presenter.log_line.connect(ui.add_log)   # savaş logu
	ui.speed_selected.connect(_presenter.set_speed)
	ui.skip_pressed.connect(_presenter.request_skip)
	var info: Dictionary = {}
	for u: CombatUnit in _units:
		info[u.uid] = _info_of(u)
	_presenter.setup(_view_by_uid, board, info)
	EventBus.battle_started.emit()
	AudioDirector.play_sfx(&"battle_start")
	AudioDirector.play_sfx(&"battlecry", 0.05)   # savaş narası

## Yeni dizilenleri _units'e kat (ON_DEPLOY), 1 tur çöz, sonucu değerlendir
func _run_turn() -> void:
	var new_units: Array = []
	var indices := _coord_by_index.keys()
	indices.sort()
	for i: int in indices:
		if not _committed.has(i):
			_uid_next += 1
			var u := CombatUnit.from_piece(_squad[i], CombatResolver.SIDE_PLAYER,
				_coord_by_index[i], _uid_next)
			_units.append(u)
			_committed[i] = _uid_next
			_view_by_uid[_uid_next] = _views_by_index[i]
			_presenter.add_unit(_uid_next, _views_by_index[i], _info_of(u))
			new_units.append(u)
	# İlk turda relic savaş-başı kalkanı (§B.9)
	if _round == 0:
		var rshield := GameState.relic_sum(&"baslangic_kalkan")
		if rshield > 0:
			for u: CombatUnit in new_units:
				u.kalkan += rshield
	if not new_units.is_empty():
		var dp := CombatResolver.deploy_procs_for(new_units, _units, _ctx())
		if not dp.is_empty():
			await _presenter.play_round(dp)
	_round += 1
	var events := CombatResolver.resolve_round(_units, _ctx(), _round, _combat_state,
		_player_reserves())
	await _presenter.play_round(events)
	_presenter.sync_views(_units)
	if CombatResolver.is_over(_units, _player_reserves()) or _round >= BoardDefs.MAX_ROUND:
		_finish_battle()
	else:
		_enter_planning()

## Dizilmemiş kadro üyesi sayısı (piece-out §13: sahada birim kalmasa da yedek
## varsa savaş sürer). Ölen committed birimler _coord_by_index'te kaldığından
## yedek sayılmaz — doğru.
func _player_reserves() -> int:
	return _squad.size() - _coord_by_index.size()

## Tur arası planlama: AP yenile, takviye dizmeye izin ver
func _enter_planning() -> void:
	_phase = Phase.PLANNING
	deployment.mevzi = mini(AP_MAX, deployment.mevzi + AP_REGEN + GameState.relic_sum(&"mevzi_bonus"))
	_cmd_cd = maxi(0, _cmd_cd - 1)
	ui.enter_planning_mode(deployment.mevzi)
	ui.set_commander(_cmd_cd == 0, _cmd_cd)
	_refresh_overlays()

# ------------------------------------------------------------------ kumandan (§B.0/4)

## Kumandan yeteneği: bolt → hedefleme; heal → anında tüm dostları iyileştir
func _on_commander() -> void:
	if _phase != Phase.PLANNING or _cmd_cd > 0 or _targeting:
		return
	if _cmd["tip"] == "heal":
		_apply_heal_wave()
		_cmd_cd = _cmd["cd"]
		ui.set_commander(false, _cmd_cd)
		return
	_targeting = true
	_deselect()
	board.clear_overlays()
	for u: CombatUnit in _units:
		if u.alive and u.side == CombatResolver.SIDE_ENEMY:
			board.set_overlay(u.coord, OVERLAY_RED)

## Şifa Dalgası: tüm canlı oyuncu birimlerine +deger CAN
func _apply_heal_wave() -> void:
	var amt: int = _cmd["deger"]
	for u: CombatUnit in _units:
		if u.alive and not u.is_flag and u.side == CombatResolver.SIDE_PLAYER:
			u.hp = mini(u.max_hp, u.hp + amt)
			var view: PieceView = _view_by_uid.get(u.uid)
			if view:
				view.set_stat_text("%d/%d/%d" % [u.atk, u.hp, u.spd])
	AudioDirector.play_sfx(&"heal")

func _cancel_targeting() -> void:
	_targeting = false
	_refresh_overlays()

## Tıklanan tile'daki düşmana yıldırım hasarı uygula
func _commander_target(coord: Vector2i) -> void:
	var target: CombatUnit = null
	for u: CombatUnit in _units:
		if u.alive and u.side == CombatResolver.SIDE_ENEMY and u.coord == coord:
			target = u
			break
	if target == null:
		return   # geçersiz hedef — hedefleme sürer
	_apply_commander_bolt(target)
	_targeting = false
	_cmd_cd = _cmd["cd"]
	ui.set_commander(false, _cmd_cd)
	_refresh_overlays()
	if CombatResolver.is_over(_units, _player_reserves()):
		_finish_battle()

func _apply_commander_bolt(u: CombatUnit) -> void:
	var dmg: int = _cmd["deger"]
	var absorbed := mini(dmg, u.kalkan)
	u.kalkan -= absorbed
	u.hp -= dmg - absorbed
	var view: PieceView = _view_by_uid.get(u.uid)
	if view:
		view.hit_flash(0.3)
		view.set_stat_text("%d/%d/%d" % [u.atk, maxi(0, u.hp), u.spd])
	AudioDirector.play_sfx(&"hit", 0.05)
	if u.hp <= 0 and u.alive:
		u.alive = false
		if view:
			var tw := view.die_anim(0.35)
			tw.finished.connect(func(): view.visible = false)

func _finish_battle() -> void:
	_phase = Phase.DONE
	var kazanan := CombatResolver.winner(_units, _player_reserves())
	var player_won := kazanan == "PLAYER"
	_last_won = player_won
	if player_won:
		GameState.gold += _enc_gold + GameState.relic_sum(&"altin_bonus")   # zafer altını (§21)
	if _battle_player_flag != null:
		GameState.apply_flag_result(_battle_player_flag.hp)   # kalıcı bayrak CAN'ı (§B.0/2)
	ui.show_result(player_won)
	EventBus.battle_finished.emit(player_won)
	AudioDirector.play_sfx(&"victory" if player_won else &"defeat")

## --autobattle: dizip turları otomatik oyna (görsel doğrulama)
func _debug_autobattle() -> void:
	var spots: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(4, 1), Vector2i(0, 1)]
	for i in _squad.size():
		_selected = i
		_try_place(spots[i])
	await get_tree().create_timer(0.4).timeout
	while _phase == Phase.DEPLOY or _phase == Phase.PLANNING:
		await _on_end_turn()
		await get_tree().create_timer(0.15).timeout
