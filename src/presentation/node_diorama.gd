class_name NodeDiorama
extends Node3D
## Hizmet düğümü diyoraması (MoP "Gray grave" referansı, gelistirme §8/9/11):
## küçük izometrik tile ADASI + prop'lar + prop üstünde YÜZEN ELMAS seçenekler +
## üstte açıklama kutusu + altta ödül önizleme şeridi. Metin menüsü DEĞİL sahne —
## savaş tahtasıyla aynı tile art'ı, aynı env/ışık/partikül dili.
##
## Kullanım (ekranlar bundan türetilir):
##   build_island({Vector2i(0,0): 0, ...}) → add_flag/add_tombstone/add_tent/...
##   add_choice(dünya_noktası, ikon, bedel, renk, callback) → elmas buton
##   set_description(...) / set_footer(...) / add_footer_button(...)

const ISO_TILE := preload("res://shaders/iso_tile.gdshader")
const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const SLAB := preload("res://shaders/terrain_slab.gdshader")
const TILE_A_TEX := preload("res://assets/tiles/iso_tile_a.png")
const TILE_B_TEX := preload("res://assets/tiles/iso_tile_b.png")
const YESIL_A_TEX := preload("res://assets/tiles/yesil_a.png")
const YESIL_B_TEX := preload("res://assets/tiles/yesil_b.png")
const FLAG_BLUE := preload("res://assets/props/flag_blue.png")
const FLAG_RED := preload("res://assets/props/flag_red.png")
const FLAG_WAVE := preload("res://shaders/flag_wave.gdshader")
const SPARK := preload("res://assets/fx/spark.png")

const TILE_SIZE := 1.0
const BLOCK_H := 0.95
const LEVEL_H := 0.45
const TILE_TOP_CENTER_PX := 294.0   # board_view ile aynı (ön-esnetilmiş tile art'ı)
const DEPTH_PUSH := 0.45            # tile düzlemi geri itilir, prop'lar önde kalır
const PITCH := -35.0
const YAW := 45.0

var ui: CanvasLayer
var _cam: Camera3D
var _cells: Dictionary = {}         # Vector2i -> yükseklik
var _tiles: Dictionary = {}         # Vector2i -> MeshInstance3D
var _center := Vector2.ZERO
var _vdir := Vector3.ZERO
var _diamonds: Array = []           # {"ctrl": Control, "world": Vector3}
var _desc: Label
var _footer: Label
var _footer_row: HBoxContainer

func _ready() -> void:
	_setup_env()
	_setup_camera()
	_setup_ui()
	set_process(true)

## Her kare: elmas butonları prop'larının ekran izdüşümüne oturt
func _process(_dt: float) -> void:
	if _cam == null:
		return
	for d: Dictionary in _diamonds:
		var c: Control = d["ctrl"]
		c.position = _cam.unproject_position(d["world"]) - c.size * 0.5

# ------------------------------------------------------------------ sahne

func _setup_env() -> void:
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
	env.glow_enabled = true
	env.glow_intensity = 0.42
	env.glow_bloom = 0.015
	env.glow_hdr_threshold = 1.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.94
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.80
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.88, 0.68)
	key.light_energy = 1.65
	key.rotation_degrees = Vector3(-55, -35, 0)
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.5, 0.35, 0.75)
	fill.light_energy = 0.45
	fill.rotation_degrees = Vector3(-30, 140, 0)
	add_child(fill)

	# pus vinyeti (savaş ekranıyla aynı atmosfer)
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

	_setup_ambient_particles()

## Süzülen sıcak toz zerreleri (savaş ekranındakinin küçüğü)
func _setup_ambient_particles() -> void:
	var p := GPUParticles3D.new()
	p.amount = 36
	p.lifetime = 11.0
	p.preprocess = 8.0
	p.randomness = 1.0
	p.local_coords = false
	p.position = Vector3(0.0, 1.8, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(4.5, 2.6, 4.0)
	pm.direction = Vector3(0.15, 1.0, 0.0)
	pm.spread = 28.0
	pm.gravity = Vector3(0.0, 0.03, 0.0)
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.28
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.color = Color(1.0, 0.82, 0.55, 0.4)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(0.8, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.alpha_curve = ct
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.albedo_texture = SPARK
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.vertex_color_use_as_albedo = true
	quad.material = dm
	p.draw_pass_1 = quad
	add_child(p)

func _setup_camera() -> void:
	var rig := Node3D.new()
	rig.rotation_degrees.y = YAW
	# hedefi hafif yukarı al → sahne ekranda AŞAĞI iner (üst açıklama kutusuna girmesin)
	rig.position.y = 0.85
	add_child(rig)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 7.2
	var pr := deg_to_rad(-PITCH)
	_cam.position = Vector3(0, 18.0 * sin(pr), 18.0 * cos(pr))
	_cam.rotation_degrees.x = PITCH
	_cam.near = 0.05
	_cam.far = 100.0
	_cam.current = true
	rig.add_child(_cam)
	_vdir = -Vector3(cos(pr) * sin(deg_to_rad(YAW)), sin(pr),
		cos(pr) * cos(deg_to_rad(YAW))).normalized()

func _setup_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var root := Control.new()
	root.name = "UIRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.make()
	ui.add_child(root)

# ------------------------------------------------------------------ ada

## cells: Vector2i -> yükseklik (0 düz). Ada merkezlenir, tile'lar dalga intro'yla gelir.
func build_island(cells: Dictionary) -> void:
	_cells = cells
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for c: Vector2i in cells:
		mn = mn.min(Vector2(c))
		mx = mx.max(Vector2(c))
	_center = (mn + mx) * 0.5
	for c: Vector2i in cells:
		var h: int = cells[c]
		var block_h := BLOCK_H + h * LEVEL_H
		var spr := _make_billboard_tile(_tile_tex_for(c), block_h)
		var base := cell_world(c)
		spr.position = Vector3(base.x, block_h, base.z) + _vdir * DEPTH_PUSH
		add_child(spr)
		_tiles[c] = spr
	_play_intro()

## Tile'lar void'den köşegen dalga hâlinde yükselir (board_view intro'suyla aynı dil)
func _play_intro() -> void:
	for c: Vector2i in _tiles:
		var mi: Node3D = _tiles[c]
		var target: Vector3 = mi.position
		mi.position = target + Vector3(0, -7.0, 0)
		mi.scale = Vector3(0.82, 0.82, 0.82)
		var d := maxf(0.0, float(c.x + c.y) * 0.09)
		var tw := mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "position", target, 0.75) \
			.set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ONE, 0.65) \
			.set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Hücre -> dünya (zemin izdüşümü, ada merkezli)
func cell_world(c: Vector2i) -> Vector3:
	return Vector3((c.x - _center.x) * TILE_SIZE, 0.0, (c.y - _center.y) * TILE_SIZE)

## Hücrenin üst yüzey y'si
func cell_top(c: Vector2i) -> float:
	return BLOCK_H + int(_cells.get(c, 0)) * LEVEL_H

## Hücre üstü nokta (prop/elmas çipa) — lift = yüzeyden yükseklik
func cell_point(c: Vector2i, lift := 0.0) -> Vector3:
	var b := cell_world(c)
	return Vector3(b.x, cell_top(c) + lift, b.z)

## Bioma: 1. bölge (Pus Ormanı) yeşil set, 2. bölge taş set (board_view ile aynı kural).
## force_home_biome: run dışı ekranlar (Ağıl Meydanı) her zaman yeşil yuva seti kullanır.
var force_home_biome := false

func _tile_tex_for(c: Vector2i) -> Texture2D:
	var hash_v := absi((c.x * 73856093) ^ (c.y * 19349663) ^ 0x5f3759df)
	if force_home_biome or GameState.layer_index < 6:
		return YESIL_B_TEX if (hash_v % 100) < 30 else YESIL_A_TEX
	return TILE_B_TEX if (hash_v % 100) < 30 else TILE_A_TEX

## board_view._make_billboard_tile ile aynı teknik (ray-box derinlikli sprite tile)
func _make_billboard_tile(tex: Texture2D, block_h: float) -> MeshInstance3D:
	var px := sqrt(2.0) * TILE_SIZE / float(tex.get_width())
	var quad := QuadMesh.new()
	quad.size = Vector2(tex.get_width() * px, tex.get_height() * px)
	quad.center_offset = Vector3(0.0,
		-(tex.get_height() * 0.5 - TILE_TOP_CENTER_PX) * px, 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = ISO_TILE
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("block_h", block_h)
	mat.set_shader_parameter("half_xz", TILE_SIZE * 0.5)
	mat.set_shader_parameter("write_depth", true)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	return mi

# ------------------------------------------------------------------ prop'lar

func _toon_mat(top: Color, side: Color = Color(0.1, 0.08, 0.07)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("top_color", top)
	m.set_shader_parameter("side_color", side)
	m.set_shader_parameter("use_side_split", false)
	var o := ShaderMaterial.new()
	o.shader = OUTLINE
	o.set_shader_parameter("grow", 0.025)
	m.next_pass = o
	return m

## Sancak (piece_view.setup_flag ile aynı dil: flag_wave shader, ayak izi çipası)
func add_flag(c: Vector2i, blue: bool, world_h := 1.6) -> Node3D:
	var tex: Texture2D = FLAG_BLUE if blue else FLAG_RED
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	var mat := ShaderMaterial.new()
	mat.shader = FLAG_WAVE
	mat.set_shader_parameter("tex", tex)
	sprite.material_override = mat
	var px := world_h / float(tex.get_height())
	sprite.pixel_size = px
	sprite.position = cell_point(c, tex.get_height() * px * 0.5 - 15.0 * px)
	add_child(sprite)
	return sprite

## Birim/karakter sprite'ı (assets/units/*.png) — billboard, alt-orta çipa
func add_sprite_prop(path: String, c: Vector2i, world_h := 1.1,
		offset := Vector3.ZERO) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var px := world_h / float(tex.get_height())
	sprite.pixel_size = px
	sprite.position = cell_point(c, world_h * 0.5) + offset
	add_child(sprite)
	return sprite

## Stilize mezar taşı: dikey levha + kapak + toprak yığını, hafif rastgele eğim
func add_tombstone(c: Vector2i, seed_v := 0, cross := false) -> Node3D:
	var grp := Node3D.new()
	grp.position = cell_point(c)
	var tilt := float((seed_v * 37) % 11 - 5)
	grp.rotation_degrees = Vector3(0, float((seed_v * 61) % 360), tilt)
	var stone := Color(0.44, 0.45, 0.50)
	# levha
	var slab := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.34, 0.5, 0.1)
	slab.mesh = sm
	slab.material_override = _toon_mat(stone, stone.darkened(0.5))
	slab.position.y = 0.25
	grp.add_child(slab)
	# yuvarlak tepe hissi: üstte dar kapak kutusu
	var cap := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.24, 0.1, 0.1)
	cap.mesh = cm
	cap.material_override = _toon_mat(stone.lightened(0.08), stone.darkened(0.5))
	cap.position.y = 0.54
	grp.add_child(cap)
	if cross:
		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.3, 0.08, 0.12)
		arm.mesh = am
		arm.material_override = _toon_mat(stone.lightened(0.05), stone.darkened(0.5))
		arm.position.y = 0.42
		grp.add_child(arm)
	# toprak yığını
	var mound := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.16
	mm.bottom_radius = 0.26
	mm.height = 0.1
	mm.radial_segments = 7
	mound.mesh = mm
	mound.material_override = _toon_mat(Color(0.16, 0.12, 0.09))
	mound.position = Vector3(0, 0.05, 0.16)
	grp.add_child(mound)
	add_child(grp)
	return grp

## Çadır: koni gövde + direk + giriş karartısı
func add_tent(c: Vector2i, canvas: Color) -> Node3D:
	var grp := Node3D.new()
	grp.position = cell_point(c)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.62
	cm.height = 1.05
	cm.radial_segments = 7
	cone.mesh = cm
	cone.material_override = _toon_mat(canvas, canvas.darkened(0.55))
	cone.position.y = 0.525
	grp.add_child(cone)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.025
	pm.bottom_radius = 0.025
	pm.height = 0.45
	pole.mesh = pm
	pole.material_override = _toon_mat(Color(0.32, 0.24, 0.15))
	pole.position.y = 1.2
	grp.add_child(pole)
	add_child(grp)
	return grp

## Ölü ağaç: eğik gövde + iki çıplak dal
func add_dead_tree(c: Vector2i, seed_v := 0) -> Node3D:
	var grp := Node3D.new()
	grp.position = cell_point(c)
	grp.rotation_degrees.y = float((seed_v * 83) % 360)
	var bark := Color(0.15, 0.12, 0.10)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.035
	tm.bottom_radius = 0.09
	tm.height = 0.95
	trunk.mesh = tm
	trunk.material_override = _toon_mat(bark)
	trunk.position.y = 0.475
	trunk.rotation_degrees.z = 7.0
	grp.add_child(trunk)
	for i in 2:
		var br := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.012
		bm.bottom_radius = 0.03
		bm.height = 0.45
		br.mesh = bm
		br.material_override = _toon_mat(bark)
		br.position = Vector3(0.1 - i * 0.2, 0.66 + i * 0.18, 0)
		br.rotation_degrees.z = 55.0 - i * 118.0
		grp.add_child(br)
	add_child(grp)
	return grp

## Zemine damarlı ışık plakası (lav/kutsal/pus slab dili)
func add_glow_slab(c: Vector2i, base: Color, glow: Color, strength: float,
		anim := 0.3) -> Node3D:
	var slab := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.96, 0.96)
	slab.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = SLAB
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("glow_color", glow)
	mat.set_shader_parameter("glow_strength", strength)
	mat.set_shader_parameter("vein_scale", 2.4)
	mat.set_shader_parameter("vein_threshold", 0.5)
	mat.set_shader_parameter("anim_speed", anim)
	slab.material_override = mat
	slab.position = cell_point(c, 0.014)
	add_child(slab)
	return slab

## Sis pufları: adanın kenarında ağır süzülen soluk bulutlar (referans mist)
func add_mist(c: Vector2i, tint := Color(0.75, 0.78, 0.9, 0.16)) -> Node3D:
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.randomness = 1.0
	p.local_coords = false
	p.position = cell_point(c, 0.25)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3(0.3, 0.15, 0)
	pm.spread = 60.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.03
	pm.initial_velocity_max = 0.1
	pm.scale_min = 3.0
	pm.scale_max = 6.5
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.color = tint
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(0.7, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.alpha_curve = ct
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.28)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_texture = SPARK
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.vertex_color_use_as_albedo = true
	dm.no_depth_test = false
	quad.material = dm
	p.draw_pass_1 = quad
	add_child(p)
	return p

## Sıcak fener/büyü nokta ışığı
func add_omni(c: Vector2i, color: Color, energy := 2.2, lift := 0.8) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 3.2
	l.position = cell_point(c, lift)
	add_child(l)
	return l

## Şenlik ateşi (gelistirme §15.6): taş halka + çapraz kütükler + emissive kor
## çekirdeği + yükselen kıvılcımlar + titreşen sıcak ışık. Alev sprite'ı bilinçli
## yok — ateş sanatı WIP, prosedürel alev istenmiyor; kor + glow dili yeter.
func add_campfire(c: Vector2i) -> Node3D:
	var grp := Node3D.new()
	grp.position = cell_point(c)
	add_child(grp)
	# taş halka
	for i in 6:
		var st := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 0.11, 0.13)
		st.mesh = bm
		var ang := TAU * float(i) / 6.0
		st.position = Vector3(cos(ang) * 0.34, 0.05, sin(ang) * 0.34)
		st.rotation_degrees.y = rad_to_deg(-ang) + float((i * 53) % 25)
		st.material_override = _toon_mat(Color(0.38, 0.38, 0.42), Color(0.16, 0.16, 0.18))
		grp.add_child(st)
	# çapraz kütükler
	for i in 3:
		var log_m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.045
		cm.bottom_radius = 0.045
		cm.height = 0.5
		log_m.mesh = cm
		log_m.material_override = _toon_mat(Color(0.30, 0.20, 0.12), Color(0.12, 0.08, 0.05))
		log_m.rotation_degrees = Vector3(64.0, float(i) * 120.0, 0.0)
		log_m.position.y = 0.13
		grp.add_child(log_m)
	# kor çekirdeği (emissive — glow AÇIK olduğundan parlar)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.16
	core.mesh = sm
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Color(1.0, 0.55, 0.18)
	em.emission_enabled = true
	em.emission = Color(1.0, 0.45, 0.12)
	em.emission_energy_multiplier = 2.4
	core.material_override = em
	core.position.y = 0.12
	grp.add_child(core)
	# yükselen kıvılcım korları
	var p := GPUParticles3D.new()
	p.amount = 26
	p.lifetime = 1.7
	p.preprocess = 2.0
	p.randomness = 1.0
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.09
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 14.0
	pm.gravity = Vector3(0, 0.55, 0)
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.8
	pm.scale_min = 0.35
	pm.scale_max = 0.8
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.color = Color(1.0, 0.62, 0.2, 0.85)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.7, 0.8))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.alpha_curve = ct
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.albedo_texture = SPARK
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.vertex_color_use_as_albedo = true
	quad.material = dm
	p.draw_pass_1 = quad
	p.position = Vector3(0, 0.18, 0)
	grp.add_child(p)
	# titreşen sıcak ışık (canlı ateş hissi)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.62, 0.25)
	l.light_energy = 2.6
	l.omni_range = 3.6
	l.position.y = 0.75
	grp.add_child(l)
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "light_energy", 3.3, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "light_energy", 2.4, 0.7).set_trans(Tween.TRANS_SINE)
	return grp

# ------------------------------------------------------------------ UI katmanı

## Üst açıklama kutusu (referans: "Lose flag durability, you can obtain artifacts")
func set_description(baslik: String, metin: String) -> void:
	if _desc == null:
		var panel := PanelContainer.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP,
			Control.PRESET_MODE_MINSIZE, 18)
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		var v := VBoxContainer.new()
		v.custom_minimum_size = Vector2(560, 0)
		panel.add_child(v)
		var t := Label.new()
		t.name = "T"
		t.theme_type_variation = "Title"
		t.add_theme_font_size_override("font_size", 30)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		_desc = Label.new()
		_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_desc.modulate = Color(1, 1, 1, 0.85)
		v.add_child(_desc)
		_ui_root().add_child(panel)
	(_desc.get_parent().get_node("T") as Label).text = baslik
	_desc.text = metin

## Alt ödül/önizleme şeridi (referans: "Receive a Rare Artifact ⚑ −2")
func set_footer(metin: String) -> void:
	if _footer == null:
		var panel := PanelContainer.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM,
			Control.PRESET_MODE_MINSIZE, 24)
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		var v := VBoxContainer.new()
		v.custom_minimum_size = Vector2(480, 0)
		panel.add_child(v)
		_footer = Label.new()
		_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(_footer)
		_footer_row = HBoxContainer.new()
		_footer_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_footer_row.add_theme_constant_override("separation", 10)
		v.add_child(_footer_row)
		_ui_root().add_child(panel)
	_footer.text = metin

## Alt şeride buton ekle (örn. "Geç →")
func add_footer_button(text: String, cb: Callable) -> Button:
	if _footer == null:
		set_footer("")
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(130, 40)
	b.pressed.connect(cb)
	_footer_row.add_child(b)
	return b

func _ui_root() -> Control:
	return ui.get_node("UIRoot") as Control

# ------------------------------------------------------------------ elmas seçenekler

## Prop üstünde yüzen elmas buton (MoP dili): renkli döndürülmüş kare + ikon +
## bedel rozeti. world = çipa noktası (ekrana her kare izdüşürülür).
func add_choice(world: Vector3, icon: Texture2D, cost: String, color: Color,
		tip: String, cb: Callable) -> Control:
	var d := _Diamond.new()
	d.fill = color
	d.icon = icon
	d.cost = cost
	d.tooltip_text = tip
	d.size = Vector2(104, 128)
	d.pivot_offset = d.size * 0.5
	d.pressed.connect(cb)
	_ui_root().add_child(d)
	_diamonds.append({"ctrl": d, "world": world})
	# beliriş: pop
	d.scale = Vector2(0.2, 0.2)
	d.modulate.a = 0.0
	var tw := d.create_tween()
	tw.set_parallel(true)
	tw.tween_property(d, "scale", Vector2.ONE, 0.3) \
		.set_delay(0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(d, "modulate:a", 1.0, 0.25).set_delay(0.65)
	return d

func clear_choices() -> void:
	for d: Dictionary in _diamonds:
		(d["ctrl"] as Control).queue_free()
	_diamonds.clear()

func set_choice_enabled(ctrl: Control, on: bool) -> void:
	(ctrl as _Diamond).enabled = on
	ctrl.queue_redraw()

## İkonu kendi ekseninde döndür (rad/sn). 0 = sabit. Zar elması için.
func set_choice_spin(ctrl: Control, speed: float) -> void:
	(ctrl as _Diamond).spin = speed

## Döndürülmüş kare ikon buton + bedel rozeti (MoP "Gray grave" elmasları)
class _Diamond extends Control:
	signal pressed
	var fill := Color(0.85, 0.7, 0.3)
	var icon: Texture2D
	var cost := ""
	var enabled := true
	var spin := 0.0            # ikon dönüş hızı (rad/sn); 0 = sabit
	var _icon_rot := 0.0
	var _hover := false
	func _process(delta: float) -> void:
		if spin == 0.0 or not enabled:
			return
		_icon_rot = fmod(_icon_rot + spin * delta, TAU)
		queue_redraw()
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void:
			_hover = true
			if enabled:
				create_tween().tween_property(self, "scale", Vector2(1.12, 1.12), 0.1)
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			create_tween().tween_property(self, "scale", Vector2.ONE, 0.1)
			queue_redraw())
	func _gui_input(e: InputEvent) -> void:
		if enabled and e is InputEventMouseButton and e.pressed \
				and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pressed.emit()
	func _draw() -> void:
		var cx := size.x * 0.5
		var r := 44.0
		var cy := r + 6.0
		var col := fill if enabled else fill.darkened(0.55)
		if _hover and enabled:
			col = col.lightened(0.15)
		var pts := PackedVector2Array([
			Vector2(cx, cy - r), Vector2(cx + r, cy),
			Vector2(cx, cy + r), Vector2(cx - r, cy)])
		# gölge + gövde + kenar
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + Vector2(0, 4))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.45))
		draw_colored_polygon(pts, col)
		var edge := pts.duplicate()
		edge.append(pts[0])
		draw_polyline(edge, Color(0.08, 0.07, 0.06, 0.9), 3.0, true)
		if icon:
			var isz := Vector2(44, 44)
			var icol := Color(0.97, 0.94, 0.86) if enabled else Color(0.6, 0.58, 0.54)
			if spin != 0.0:
				draw_set_transform(Vector2(cx, cy), _icon_rot, Vector2.ONE)
				draw_texture_rect(icon, Rect2(-isz * 0.5, isz), false, icol)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_texture_rect(icon, Rect2(Vector2(cx, cy) - isz * 0.5, isz), false, icol)
		if cost != "":
			var f := UITheme.body_font()
			var fs := 19
			var w := f.get_string_size(cost, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			var pos := Vector2(cx - w * 0.5, cy + r + 24)
			draw_string_outline(f, pos, cost, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8,
				Color(0.05, 0.05, 0.06))
			draw_string(f, pos, cost, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color(0.95, 0.88, 0.7))
