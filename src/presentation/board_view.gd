class_name BoardView
extends Node3D
## PRESENTATION — kübik blok grid'ini çizer + overlay yönetir (CLAUDE.md §16.3-16.4).
## Mantık board durumunu bilmez; sadece koordinat -> dünya eşlemesi ve görsel sunar.

const TILE_SIZE := 1.0
const TILE_GAP := 0.05          # bloklar arası ince boşluk (grid hissi)
const BLOCK_BASE_H := 0.95      # taban blok yüksekliği (uzun küpler)
const LEVEL_H := 0.45           # Yükselti başına ek yükseklik
const ENEMY_BASE_LIFT := 0.85   # düşman kaidesi ana ızgaradan AYRI, yüksek platform
const ENEMY_ROW_GAP := 0.2      # arka düşman sırası ile arena arasında boşluk

## Billboard tile düzlemini görüş ekseni boyunca geriye it: ortho kamerada ekran
## konumu DEĞİŞMEZ ama tile üstündeki 3D birimler düzlemin önünde kalır
## (yoksa birimin arka yarısı kendi tile'ının görseline gömülür).
const SPRITE_DEPTH_PUSH := 0.45

const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const OVERLAY := preload("res://shaders/grid_overlay.gdshader")
const ISO_TILE := preload("res://shaders/iso_tile.gdshader")

## TEST: tüm zemin test-tile.png sprite'ından, efektsiz (shader/tint/outline yok)
const USE_TEST_TILE := true
## İki ana kübik tile (Onur art'ı, 1024×1024): A = koyu üst, B = açık/gri üst.
## Tahtaya per-kare hash ile ~%70 A / %30 B karıştırılır (bkz. _tile_tex_for).
const TILE_A_TEX := preload("res://assets/tiles/iso_tile_a.png")   # koyu üst yüz
const TILE_B_TEX := preload("res://assets/tiles/iso_tile_b.png")   # açık/gri üst yüz
## Pus Ormanı (1. bölge) bioma seti (Onur art'ı, aynı geometri/ön-esnetme):
## yeşil-yosun üst yüzler; A = toprak yan, B = koyu yeşil yan.
const YESIL_A_TEX := preload("res://assets/tiles/yesil_a.png")
const YESIL_B_TEX := preload("res://assets/tiles/yesil_b.png")
## İnce ön-kaide (ledge) tile'ı — aynı stil, alçak blok (1024×768).
const INCE_TILE_TEX := preload("res://assets/tiles/ince_tile.png")
## Üst yüz elmasının merkezi (px, görselin üstünden). Ham tile'lar -35° kamera için
## dikeyde ×1.1472 ön-esnetildi (a/b 1024×1175, ince 1024×881) → düz lav/pus/overlay
## plane'leri üst yüze BİREBİR oturur. Elmas merkezi 256×1.1472 ≈ 294.
const TILE_TOP_CENTER_PX := 294.0

var _last_vdir := Vector3.ZERO   # kamera dönünce depth push'u tazelemek için

## TEXTURE TOP testi: 3D bloklar kalır, üst yüz Onur'un dokusu + hafif normal map
const USE_TEXTURE_TOP := true
const TOP_DIFFUSE := preload("res://assets/tiles/tile_top_diffuse.png")
const TOP_NORMAL := preload("res://assets/tiles/tile_top_normal.png")

## Biome renkleri (dummy — BiomeData .tres'e M4'te taşınır).
## Referans ton: desatüre yosun yeşili, düşman yakası çorak/pas, neredeyse
## siyah yan yüzler (Master of Piece paleti).
const GRASS_TOP := Color(0.30, 0.36, 0.17)
const GRASS_ENEMY := Color(0.33, 0.27, 0.15)   # düşman yakası çorak ton
const DIRT_SIDE := Color(0.10, 0.08, 0.07)
const NOMANS_TOP := Color(0.28, 0.21, 0.14)    # satır 3: toprak/çorak şerit
const PLAYER_BASE_TOP := Color(0.20, 0.24, 0.32)   # satır 0: oyuncu kaidesi (taş-mavi)
const ENEMY_BASE_TOP := Color(0.34, 0.18, 0.15)    # son satır: düşman kaidesi (kızıl çorak)

var height_map: Dictionary = {}              # Vector2i -> int (0 = düz)
var _overlays: Dictionary = {}               # Vector2i -> MeshInstance3D
var _terrain_nodes: Dictionary = {}          # Vector2i -> Node3D
var _tile_mi: Dictionary = {}                # Vector2i -> MeshInstance3D (intro anim)

# ---- Kurulum (intro) animasyonu: tile'lar void'den dalga hâlinde yükselir ----
const INTRO_STEP := 0.09      # köşegen dalga adımı (coord başına gecikme)
const INTRO_TILE_DUR := 0.75  # tek tile'ın oturma süresi
const INTRO_DROP := 7.0       # başlangıç aşağı ofseti

## Bir tile/birim koordinatının animasyon gecikmesi (köşegen sweep, ön→arka)
func intro_delay(coord: Vector2i) -> float:
	return maxf(0.0, float(coord.x + coord.y) * INTRO_STEP)

## Tüm tile'ları aşağıdan yukarı, köşegen dalga hâlinde oturt (BACK overshoot).
func play_intro() -> void:
	for coord: Vector2i in _tile_mi:
		var mi: Node3D = _tile_mi[coord]
		var target: Vector3 = mi.position
		mi.position = Vector3(target.x, target.y - INTRO_DROP, target.z)
		mi.scale = Vector3(0.82, 0.82, 0.82)
		var d := intro_delay(coord)
		var tw := mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "position", target, INTRO_TILE_DUR) \
			.set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ONE, INTRO_TILE_DUR * 0.85) \
			.set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# terrain efektleri (lav/diken/pus) tile'ıyla birlikte pop
	for coord: Vector2i in _terrain_nodes:
		var node: Node3D = _terrain_nodes[coord]
		node.scale = Vector3.ZERO
		var tw := node.create_tween()
		tw.tween_property(node, "scale", Vector3.ONE, 0.35) \
			.set_delay(intro_delay(coord) + INTRO_TILE_DUR * 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _make_tile_material(top: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("top_color", top)
	mat.set_shader_parameter("side_color", DIRT_SIDE)
	mat.set_shader_parameter("use_side_split", true)
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	outline.set_shader_parameter("grow", 0.025)
	mat.next_pass = outline
	return mat

## Ön kaide sırası (satır −1): yarım boy, salt görsel — oyuncu bayrağı burada durur
const LEDGE_H := BLOCK_BASE_H * 0.5

## Grid'i inşa et. heights: Vector2i -> int (verilmeyen tile = 0)
func build(heights: Dictionary = {}) -> void:
	height_map = heights
	_last_vdir = _initial_vdir()   # ilk _process intro tween'ini bozmasın
	for row in BoardDefs.ROWS:
		for col in BoardDefs.COLS:
			var coord := Vector2i(col, row)
			_build_tile(coord)
	for col in BoardDefs.COLS:
		_build_ledge_tile(Vector2i(col, -1))

## Başlangıç kamera yönü (rig sabitlerinden — kamera henüz sahnede olmayabilir)
func _initial_vdir() -> Vector3:
	var p := deg_to_rad(-CameraRig.PITCH_DEG)
	var yaw := deg_to_rad(CameraRig.BASE_YAW_DEG)
	return -Vector3(cos(p) * sin(yaw), sin(p), cos(p) * cos(yaw)).normalized()

func _view_push() -> Vector3:
	return _last_vdir * SPRITE_DEPTH_PUSH

## Kamera Q/E ile dönünce sprite tile'ların derinlik kaydırmasını tazele
func _process(_dt: float) -> void:
	if not USE_TEST_TILE:
		set_process(false)
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vdir := (-cam.global_transform.basis.z).normalized()
	if vdir.is_equal_approx(_last_vdir):
		return
	_last_vdir = vdir
	for coord: Vector2i in _tile_mi:
		var n: Node3D = _tile_mi[coord]
		if n.has_meta("base_pos"):
			n.position = (n.get_meta("base_pos") as Vector3) + _view_push()

## Yarım boy ön kaide tile'ı — mantık grid'inin dışında, tıklanamaz (collision yok)
func _build_ledge_tile(coord: Vector2i) -> void:
	var base := coord_to_world(coord)
	var vis: Node3D
	if USE_TEST_TILE:
		var spr := _make_billboard_tile(INCE_TILE_TEX, TILE_TOP_CENTER_PX, LEDGE_H)
		spr.position = Vector3(base.x, LEDGE_H, base.z)
		spr.set_meta("base_pos", spr.position)
		spr.position += _view_push()
		vis = spr
	else:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(TILE_SIZE - TILE_GAP, LEDGE_H, TILE_SIZE - TILE_GAP)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _make_tile_material(PLAYER_BASE_TOP)
		mi.material_override.set_shader_parameter("is_ground", true)
		mi.position = Vector3(base.x, LEDGE_H * 0.5, base.z)
		if USE_TEXTURE_TOP:
			var plate := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(TILE_SIZE - TILE_GAP, TILE_SIZE - TILE_GAP)
			plate.mesh = pm
			var pmat := StandardMaterial3D.new()
			pmat.albedo_texture = TOP_DIFFUSE
			pmat.normal_enabled = true
			pmat.normal_texture = TOP_NORMAL
			pmat.normal_scale = 1.0
			pmat.roughness = 1.0
			plate.material_override = pmat
			plate.position = Vector3(0, LEDGE_H * 0.5 + 0.004, 0)
			plate.rotation.y = float(absi(coord.x * 73856093) % 4) * PI * 0.5
			mi.add_child(plate)
		vis = mi
	vis.name = "Ledge_%d" % coord.x
	add_child(vis)
	_tile_mi[coord] = vis

## Ana ızgara DÜZ (merdiven yok). Sadece en arka satır = düşman kaidesi, ayrı
## yüksek platform. Salt görsel — combat yükselti bonusu ctx heights'tan gelir.
func _base_offset(coord: Vector2i) -> float:
	if coord.y == BoardDefs.ROWS - 1:
		return ENEMY_BASE_LIFT
	return 0.0

func _build_tile(coord: Vector2i) -> void:
	var h: int = height_map.get(coord, 0)
	var block_h := BLOCK_BASE_H + h * LEVEL_H + _base_offset(coord)
	var base := coord_to_world(coord)
	var vis: Node3D
	if USE_TEST_TILE:
		vis = _make_sprite_tile(coord, block_h)
		vis.position = Vector3(base.x, block_h, base.z)
		vis.set_meta("base_pos", vis.position)
		vis.position += _view_push()
	else:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(TILE_SIZE - TILE_GAP, block_h, TILE_SIZE - TILE_GAP)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var top := GRASS_TOP
		if coord.y == BoardDefs.ROWS - 1:
			top = ENEMY_BASE_TOP
		elif coord.y == BoardDefs.NOMANS_ROW:
			top = NOMANS_TOP
		elif coord.y in BoardDefs.ENEMY_ROWS:
			top = GRASS_TOP.lerp(GRASS_ENEMY, 0.7)
		var hash_v := absi((coord.x * 73856093) ^ (coord.y * 19349663))
		var tint := 0.9 + float(hash_v % 100) / 100.0 * 0.16
		mi.material_override = _make_tile_material(top * tint)
		mi.material_override.set_shader_parameter("is_ground", true)
		mi.position = Vector3(base.x, block_h * 0.5, base.z)
		if USE_TEXTURE_TOP:
			# üst yüz plakası: doku + hafif normal map (DirectionalLight yakalar)
			var plate := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(TILE_SIZE - TILE_GAP, TILE_SIZE - TILE_GAP)
			plate.mesh = pm
			var pmat := StandardMaterial3D.new()
			pmat.albedo_texture = TOP_DIFFUSE
			pmat.normal_enabled = true
			pmat.normal_texture = TOP_NORMAL
			pmat.normal_scale = 1.0
			pmat.roughness = 1.0
			pmat.metallic = 0.0
			plate.material_override = pmat
			plate.position = Vector3(0, block_h * 0.5 + 0.004, 0)
			# tekrar hissini kır: tile başına 90° adım rastgele döndür (hash'li)
			plate.rotation.y = float(hash_v % 4) * PI * 0.5
			mi.add_child(plate)
		vis = mi
	vis.name = "Tile_%s" % BoardDefs.coord_name(coord)
	add_child(vis)
	_tile_mi[coord] = vis

	var body := StaticBody3D.new()
	body.position = Vector3(base.x, block_h * 0.5, base.z)
	body.set_meta("coord", coord)
	var cshape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(TILE_SIZE - TILE_GAP, block_h, TILE_SIZE - TILE_GAP)
	cshape.shape = box
	body.add_child(cshape)
	add_child(body)

## TEST tile: art olduğu gibi OPAK billboard (QuadMesh + alpha-scissor).
## Sprite3D KULLANILMAZ: Sprite3D şeffaf geçitte kalıyor ve büyük AABB'si
## şeffaf sıralamada yerdeki gölge quad'larını yenip üstlerine çiziliyordu.
## Alpha-scissor StandardMaterial3D = opak geçit → saf depth-buffer düzeni.
## - genişlik: elmaslar TAM kenetlenir (gap yok — aralık yan yüz sızdırır)
## - dikey: art 35°'ye önceden esnetilmiş, runtime ölçek yok
func _make_sprite_tile(coord: Vector2i, block_h: float) -> MeshInstance3D:
	return _make_billboard_tile(_tile_tex_for(coord), TILE_TOP_CENTER_PX, block_h)

## Per-kare A/B seçimi: sabit hash ile rastgele GÖRÜNEN ama kararlı desen.
## ~%30 B (açık), gerisi A (koyu) — "çoğunluk A" (Onur tercihi). Salt görsel,
## combat determinizmini etkilemez. Bioma: 1. bölge (Pus Ormanı) yeşil set,
## 2. bölge (Kemik Bataklığı) taş set (bölge = GameState.layer_index).
func _tile_tex_for(coord: Vector2i) -> Texture2D:
	var hash_v := absi((coord.x * 73856093) ^ (coord.y * 19349663) ^ 0x5f3759df)
	if GameState.layer_index < 6:
		return YESIL_B_TEX if (hash_v % 100) < 30 else YESIL_A_TEX
	return TILE_B_TEX if (hash_v % 100) < 30 else TILE_A_TEX

## top_center_px: üst yüz elması merkezinin görselin ÜSTÜNDEN piksel uzaklığı
## (tüm tile'larda 294 — elmas genişliği 1024 px, ölçülü). Genişlik dünyada √2·TILE.
## block_h: tile'ın temsil ettiği kübik bloğun yüksekliği → shader gerçek derinlik yazar
## (bkz. iso_tile.gdshader; düz billboard derinliği diken/lav/bayrakla çakışıyordu).
func _make_billboard_tile(tex: Texture2D, top_center_px: float, block_h: float) -> MeshInstance3D:
	var px := sqrt(2.0) * TILE_SIZE / float(tex.get_width())
	var quad := QuadMesh.new()
	quad.size = Vector2(tex.get_width() * px, tex.get_height() * px)
	# anchor görsel merkezinden üst yüz elması merkezine (y aşağı pozitif kayar)
	quad.center_offset = Vector3(0.0,
		-(tex.get_height() * 0.5 - top_center_px) * px, 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = ISO_TILE
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("block_h", block_h)
	mat.set_shader_parameter("half_xz", TILE_SIZE * 0.5)
	mat.set_shader_parameter("write_depth",
		not OS.get_cmdline_user_args().has("--flat-depth"))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Billboard quad'ın AABB'si dönünce büyüdüğünden görünürlük kırpması yanlış olabilir
	mi.extra_cull_margin = 4.0
	return mi

## Koordinat -> dünya konumu (tile merkezinin zemin izdüşümü).
## Satır 0 (oyuncu) kameraya yakın (+z), kolonlar x ekseninde ortalanır.
## Arka düşman sırası arenadan ENEMY_ROW_GAP kadar ayrık durur (salt görsel;
## birim/overlay/bayrak hepsi bu fonksiyonu kullandığından tutarlı kayar).
func coord_to_world(coord: Vector2i) -> Vector3:
	var z := (float(BoardDefs.ROWS - 1) * 0.5 - coord.y) * TILE_SIZE
	if coord.y == BoardDefs.ROWS - 1:
		z -= ENEMY_ROW_GAP
	return Vector3(
		(coord.x - (BoardDefs.COLS - 1) * 0.5) * TILE_SIZE,
		0.0,
		z
	)

## Tile üst yüzeyinin y'si (birim/overlay yerleşimi için)
func tile_top_y(coord: Vector2i) -> float:
	if coord.y < 0:
		return LEDGE_H   # ön kaide sırası (satır −1)
	return BLOCK_BASE_H + height_map.get(coord, 0) * LEVEL_H + _base_offset(coord)

## Overlay aç/kapa. color örn: yeşil deployment, kırmızı telegraph.
func set_overlay(coord: Vector2i, color: Color, visible_: bool = true) -> void:
	var ov: MeshInstance3D = _overlays.get(coord)
	if ov == null:
		var quad := PlaneMesh.new()
		# Sprite tile modunda elmas tam TILE_SIZE — overlay birebir aynı boyda
		var os := TILE_SIZE if USE_TEST_TILE else TILE_SIZE - TILE_GAP
		quad.size = Vector2(os, os)
		ov = MeshInstance3D.new()
		ov.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = OVERLAY
		ov.material_override = mat
		var base := coord_to_world(coord)
		# Shader depth_test_disabled — kaldırma payı gerekmez; yükseklik ekranda
		# kayma yaratır, üst yüz düzlemine yapışık dursun
		var lift := 0.01 if USE_TEST_TILE else 0.075
		ov.position = Vector3(base.x, tile_top_y(coord) + lift, base.z)
		add_child(ov)
		_overlays[coord] = ov
	(ov.material_override as ShaderMaterial).set_shader_parameter("color", color)
	ov.visible = visible_

func clear_overlays() -> void:
	for ov in _overlays.values():
		ov.visible = false

# ------------------------------------------------------------------ zemin (§7)

## Zemin görseli yerleştir (dummy §18): duvar = gri blok, lav/kutsal/pus =
## emissive slab, diken = koni demeti.
func set_terrain(coord: Vector2i, type: StringName) -> void:
	clear_terrain(coord)
	var root := Node3D.new()
	var base := coord_to_world(coord)
	var top_y := tile_top_y(coord)
	root.position = Vector3(base.x, top_y, base.z)
	match type:
		&"duvar":
			var wall := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.86, 0.85, 0.86)
			wall.mesh = mesh
			wall.material_override = _make_tile_material(Color(0.45, 0.44, 0.48))
			wall.material_override.set_shader_parameter("side_color", Color(0.28, 0.27, 0.32))
			wall.position.y = 0.425
			root.add_child(wall)
		&"lav":
			# bazalt üstünde kıvrılan akkor magma
			root.add_child(_make_slab(Color(0.09, 0.05, 0.04), Color(1.0, 0.34, 0.06), 1.3, 3.2, 0.5, 0.14))
		&"kutsal":
			# koyu taşta soluk altın parıltı
			root.add_child(_make_slab(Color(0.13, 0.11, 0.08), Color(1.0, 0.82, 0.45), 0.55, 2.6, 0.58, 0.06))
		&"pus":
			# akışkan mor sis girdapları
			root.add_child(_make_slab(Color(0.08, 0.06, 0.11), Color(0.5, 0.28, 0.75), 0.7, 2.2, 0.44, 0.4))
		&"diken":
			root.add_child(_make_spikes())
	add_child(root)
	_terrain_nodes[coord] = root

## Stilize diken tuzağı: koyu taban plakası + cel-shaded, outline'lı sivri kaya
## şardları (tehlike kızılı emissive). Eski düz kahve koniler yerine.
func _spike_mat(col: Color, emis: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("top_color", col)
	m.set_shader_parameter("use_side_split", false)
	m.set_shader_parameter("mottle_strength", 0.2)
	m.set_shader_parameter("emission_color", Color(0.9, 0.24, 0.16))
	m.set_shader_parameter("emission_strength", emis)
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	outline.set_shader_parameter("grow", 0.03)
	m.next_pass = outline
	return m

func _make_spikes() -> Node3D:
	var grp := Node3D.new()
	# koyu taban (şardların çıktığı çatlamış zemin)
	var slab := _make_slab(Color(0.10, 0.06, 0.06), Color(0.85, 0.22, 0.12), 0.9, 3.4, 0.6, 0.0)
	grp.add_child(slab)
	# sivri şard demeti — farklı boy/eğim/renk (stilize)
	var shards := [
		{"p": Vector3(-0.18, 0, -0.14), "h": 0.42, "r": 0.10, "tilt": Vector3(6, 20, -8)},
		{"p": Vector3(0.16, 0, 0.08), "h": 0.34, "r": 0.09, "tilt": Vector3(-5, -30, 7)},
		{"p": Vector3(-0.02, 0, 0.20), "h": 0.30, "r": 0.08, "tilt": Vector3(4, 60, -4)},
		{"p": Vector3(0.22, 0, -0.18), "h": 0.24, "r": 0.07, "tilt": Vector3(-8, 120, 10)},
		{"p": Vector3(-0.24, 0, 0.16), "h": 0.20, "r": 0.06, "tilt": Vector3(7, -80, -6)},
	]
	for s: Dictionary in shards:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = s["r"]
		cone.height = s["h"]
		cone.radial_segments = 5   # köşeli (kristal) siluet
		spike.mesh = cone
		spike.material_override = _spike_mat(Color(0.34, 0.30, 0.33), 0.5)
		spike.position = s["p"] + Vector3(0, s["h"] * 0.5, 0)
		spike.rotation_degrees = s["tilt"]
		grp.add_child(spike)
	return grp

func clear_terrain(coord: Vector2i) -> void:
	if _terrain_nodes.has(coord):
		_terrain_nodes[coord].queue_free()
		_terrain_nodes.erase(coord)

## Damarlı zemin plakası: koyu taban + noise'dan sızan ışık (terrain_slab shader)
func _make_slab(base: Color, glow: Color, strength: float, scale: float,
		threshold: float, anim: float) -> MeshInstance3D:
	# DÜZ plane (yan yüz YOK) → tile yüzeyine boyanmış gibi, kabarık durmaz.
	var slab := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.96, 0.96)
	slab.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/terrain_slab.gdshader")
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("glow_color", glow)
	mat.set_shader_parameter("glow_strength", strength)
	mat.set_shader_parameter("vein_scale", scale)
	mat.set_shader_parameter("vein_threshold", threshold)
	mat.set_shader_parameter("anim_speed", anim)
	slab.material_override = mat
	slab.position.y = 0.014   # tile üstüne ince yat (z-fighting olmasın)
	return slab
