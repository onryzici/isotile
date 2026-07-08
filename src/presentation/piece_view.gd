class_name PieceView
extends Node3D
## Birim görseli (CLAUDE.md §16.5, §18): dummy kapsül VEYA billboard sprite.
## PieceData.mesh_id doluysa res://assets/<mesh_id>.png sprite olarak kullanılır;
## boşsa sınıf renkli kapsül (MELEE=kırmızı, RANGED=mavi, SUPPORT=yeşil).
## Animasyonlar asset gerektirmez: idle bob, tween lunge, flash, ölüm.

const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")

const CLASS_COLORS := {
	&"MELEE": Color(0.6, 0.22, 0.18),
	&"RANGED": Color(0.26, 0.36, 0.58),
	&"SUPPORT": Color(0.3, 0.5, 0.28),
	&"ENEMY": Color(0.42, 0.26, 0.55),   # düşman = mor (pus)
}

var _visual: Node3D          # MeshInstance3D (kapsül) veya Sprite3D
var _visual_h := 0.9         # görsel yükseklik (etiket konumu için)
var _is_sprite := false
var _mat: ShaderMaterial     # kapsül modunda flash için
var _badge_vp: SubViewport   # stat rozetlerinin çizildiği viewport
var _badges: StatBadges
var _badge_sprite: Sprite3D  # rozetleri dünyada gösteren billboard
var _max_hp := -1
var _is_flag := false
var _flag_hp_label: Label3D  # bayrak modunda büyük CAN göstergesi
var _status_label: Label3D

func setup(class_key: StringName, stat_text: String, scale_mul: float = 1.0, sprite_path: String = "") -> void:
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		_setup_sprite(sprite_path, scale_mul)
	else:
		_setup_capsule(class_key, scale_mul)
	_add_blob_shadow(scale_mul)

	# Stat rozetleri (§16.5): SubViewport'ta çizilir, billboard Sprite3D'de gösterilir
	_badge_vp = SubViewport.new()
	_badge_vp.size = Vector2i(StatBadges.VP_SIZE)
	_badge_vp.transparent_bg = true
	_badge_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_badges = StatBadges.new()
	_badge_vp.add_child(_badges)
	add_child(_badge_vp)

	_badge_sprite = Sprite3D.new()
	_badge_sprite.texture = _badge_vp.get_texture()
	_badge_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge_sprite.no_depth_test = true
	# Karakterin sağ-altında — yuksek çözünürlük viewport küçülünce keskin
	_badge_sprite.pixel_size = 0.74 / StatBadges.VP_SIZE.x
	_badge_sprite.position = Vector3(0.34, _visual_h * 0.28, 0.28)
	add_child(_badge_sprite)
	_apply_stat_text(stat_text)

	# Statü şeridi (§16.6 dummy'si): birimin altında minik metin satırı
	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.no_depth_test = true
	_status_label.pixel_size = 0.005
	_status_label.font = UITheme.body_font()
	_status_label.font_size = 30
	_status_label.outline_size = 8
	_status_label.modulate = Color(0.85, 0.95, 1.0)
	_status_label.position.y = _visual_h + 0.12
	add_child(_status_label)

## Bayrak/hedef nişanı (§B.0/1): alçak taş kaide + ince gönder + dalgalanan
## takım rengi sancak bezi. side_blue=true oyuncu (mavi), false düşman (kızıl).
func setup_flag(side_blue: bool, hp: int) -> void:
	_is_flag = true
	var tint := Color(0.36, 0.55, 0.85) if side_blue else Color(0.78, 0.30, 0.26)
	var root := Node3D.new()
	# alçak taş kaide
	var ped := MeshInstance3D.new()
	var pm := BoxMesh.new(); pm.size = Vector3(0.36, 0.10, 0.36)
	ped.mesh = pm; ped.position.y = 0.05
	ped.material_override = _mono_mat(Color(0.30, 0.30, 0.34))
	root.add_child(ped)
	# gönder — ince, koyu ahşap
	var POLE_H := 1.35
	var pole := MeshInstance3D.new()
	var plm := CylinderMesh.new()
	plm.top_radius = 0.024; plm.bottom_radius = 0.036; plm.height = POLE_H
	plm.radial_segments = 6
	pole.mesh = plm; pole.position.y = 0.10 + POLE_H * 0.5
	pole.material_override = _mono_mat(Color(0.17, 0.13, 0.10))
	root.add_child(pole)
	# tepe ucu (altın mızrak ucu, hafif parlar)
	var tip := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.0; tm.bottom_radius = 0.05; tm.height = 0.16
	tm.radial_segments = 6
	tip.mesh = tm; tip.position.y = 0.10 + POLE_H + 0.08
	var tipmat := _mono_mat(Color(0.85, 0.70, 0.38))
	tipmat.set_shader_parameter("emission_color", Color(1.0, 0.85, 0.5))
	tipmat.set_shader_parameter("emission_strength", 0.4)
	tip.material_override = tipmat
	root.add_child(tip)
	# sancak bezi — gönder üstünden yana sarkan ince kumaş; pivot direkte
	var banner := Node3D.new()
	banner.position = Vector3(0, 0.10 + POLE_H - 0.05, 0)
	var cloth := MeshInstance3D.new()
	var cm := BoxMesh.new(); cm.size = Vector3(0.52, 0.40, 0.03)
	cloth.mesh = cm
	cloth.position = Vector3(0.28, -0.20, 0)
	var bmat := _mono_mat(tint)
	bmat.set_shader_parameter("emission_color", tint)
	bmat.set_shader_parameter("emission_strength", 0.3)
	cloth.material_override = bmat
	banner.add_child(cloth)
	root.add_child(banner)
	# rüzgarda hafif salınım (gönder ekseni etrafında)
	var sway := create_tween().set_loops()
	sway.tween_property(banner, "rotation:y", deg_to_rad(16.0), 1.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway.tween_property(banner, "rotation:y", deg_to_rad(-12.0), 1.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	add_child(root)
	_visual = root
	_visual_h = 1.62
	_is_sprite = false
	_add_blob_shadow(0.85)
	# büyük CAN göstergesi
	_flag_hp_label = Label3D.new()
	_flag_hp_label.text = str(hp)
	_flag_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_flag_hp_label.no_depth_test = true
	_flag_hp_label.pixel_size = 0.007
	_flag_hp_label.font = UITheme.body_font()
	_flag_hp_label.font_size = 56
	_flag_hp_label.outline_size = 12
	_flag_hp_label.modulate = Color(0.95, 0.55, 0.5) if not side_blue else Color(0.65, 0.8, 1.0)
	_flag_hp_label.position.y = _visual_h + 0.45
	add_child(_flag_hp_label)
	_max_hp = hp

func _mono_mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("top_color", color)
	m.set_shader_parameter("use_side_split", false)
	m.set_shader_parameter("mottle_strength", 0.18)
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	outline.set_shader_parameter("grow", 0.04)
	m.next_pass = outline
	return m

func _setup_capsule(class_key: StringName, scale_mul: float) -> void:
	var color: Color = CLASS_COLORS.get(class_key, Color.GRAY)
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.26 * scale_mul
	mesh.height = 0.85 * scale_mul
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.position.y = mesh.height * 0.5
	_mat = ShaderMaterial.new()
	_mat.shader = TOON
	_mat.set_shader_parameter("top_color", color)
	_mat.set_shader_parameter("use_side_split", false)
	_mat.set_shader_parameter("mottle_strength", 0.12)   # birimlerde benek hafif
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	outline.set_shader_parameter("grow", 0.05)
	_mat.next_pass = outline
	body.material_override = _mat
	add_child(body)
	_visual = body
	_visual_h = mesh.height
	_is_sprite = false

func _setup_sprite(path: String, scale_mul: float) -> void:
	var tex: Texture2D = load(path)
	var sprite := Sprite3D.new()
	sprite.texture = tex
	# İç siyah kenar (inside border) + billboard shader'da; Sprite3D billboard'ı kapalı
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.no_depth_test = false
	var bmat := ShaderMaterial.new()
	bmat.shader = preload("res://shaders/sprite_border.gdshader")
	bmat.set_shader_parameter("tex", tex)
	bmat.set_shader_parameter("border_px", 3.0)
	sprite.material_override = bmat
	# Kutuya-sığdır: genişlik tile diamond'ının (ekran √2≈1.41) altında kalsın ki
	# komşu karelere taşmasın; boy MAX_H'yi aşmasın. En kısıtlayan eksen belirler.
	# Ayaklar tile yüzeyinde (görsel altı y=0), yatayda ortalı (art zaten ortalı).
	const SPRITE_MAX_W := 1.2
	const SPRITE_MAX_H := 1.45
	var px := minf(SPRITE_MAX_W * scale_mul / float(tex.get_width()),
		SPRITE_MAX_H * scale_mul / float(tex.get_height()))
	sprite.pixel_size = px
	var world_h := tex.get_height() * px
	sprite.position.y = world_h * 0.5
	add_child(sprite)
	_visual = sprite
	_visual_h = world_h
	_is_sprite = true

## Key ışığın (−55°, −35°) yere düşürdüğü gölgenin yatay yönü
const CAST_DIR := Vector3(0.574, 0.0, -0.819)

var _shadow_root: Node3D   # PieceView'ın DIŞINDA yaşar, _process ile takip eder

## İki katmanlı sahte gölge: ayak dibinde kontakt blob + ışık yönünde uzatılmış
## YATIK gölge elipsi (billboard tile'lar unshaded — gerçek shadow map alamaz).
## KRİTİK: quad'lar PieceView'ın ALTINDA render'dan düşüyor (sebep çözülemedi,
## ampirik: bağımsız node altında sorunsuz) — bu yüzden parent'ın altına
## park edilir, _process her kare konum/görünürlük eşitler.
func _add_blob_shadow(scale_mul: float) -> void:
	_shadow_root = Node3D.new()
	# 1) kontakt blob — ayak dibi
	_add_shadow_quad(Vector2(0.95, 0.7) * scale_mul, Vector3(0, 0.03, 0), 0.0,
		0.5 if _is_sprite else 0.42)
	# 2) yatık cast gölgesi — ışık yönünde uzar
	var len := (1.5 if _is_sprite else 1.25) * scale_mul
	var wid := (0.6 if _is_sprite else 0.5) * scale_mul
	var offset := CAST_DIR * len * 0.4 + Vector3(0, 0.045, 0)
	var yaw := -atan2(CAST_DIR.z, CAST_DIR.x)
	_add_shadow_quad(Vector2(len, wid), offset, yaw, 0.38)
	get_parent().add_child.call_deferred(_shadow_root)
	tree_exiting.connect(func():
		if is_instance_valid(_shadow_root):
			_shadow_root.queue_free())

func _process(_dt: float) -> void:
	if _shadow_root and _shadow_root.is_inside_tree():
		_shadow_root.global_position = global_position
		# NOT: scale kopyalanmaz! _intro_pop view'ı scale=ZERO yapıyor; sıfır
		# scale singular basis bırakır ve node bir daha görünmez oluyor.
		# Ölüm/doğum yerine görünürlük + alpha yeter:
		_shadow_root.visible = visible and scale.x > 0.3

func _add_shadow_quad(size: Vector2, pos: Vector3, yaw: float, alpha: float) -> void:
	var shadow := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	shadow.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = preload("res://assets/blob_shadow.png")
	mat.albedo_color = Color(0, 0, 0, alpha)
	shadow.material_override = mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = pos
	shadow.rotation.y = yaw
	_shadow_root.add_child(shadow)

func set_stat_text(text: String) -> void:
	_apply_stat_text(text)

## "atk/hp/spd" metnini rozetlere aktar; ilk uygulama max CAN'ı belirler.
## Bayrakta yalnız CAN (orta değer) büyük göstergede gösterilir.
func _apply_stat_text(text: String) -> void:
	var p := text.split("/")
	if p.size() < 3:
		return
	var hp := int(p[1])
	if _is_flag:
		if _flag_hp_label:
			_flag_hp_label.text = str(maxi(0, hp))
		return
	if _max_hp < 0:
		_max_hp = hp
	_badges.set_stats(int(p[0]), hp, int(p[2]), _max_hp)

func set_status_text(text: String) -> void:
	if _status_label:   # bayrak görünümünde statü şeridi yok
		_status_label.text = text

# ------------------------------------------------------- savaş animasyonları
## Hepsi tween tabanlı (§16.5). Presenter çağırır.

## Tile'dan tile'a yürüme
func move_anim(target: Vector3, dur: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(self, "position", target, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tw

## İleri hamle + geri dönüş (saldırı)
func attack_lunge(toward: Vector3, dur: float) -> Tween:
	var origin := position
	var dir := toward - origin
	dir.y = 0.0
	var lunge := origin + (dir.normalized() * 0.38 if dir.length() > 0.01 else Vector3.ZERO)
	var tw := create_tween()
	tw.tween_property(self, "position", lunge, dur * 0.38) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", origin, dur * 0.62) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tw

## Hasar aldı: kapsülde kırmızı emissive parlama, sprite'ta kırmızı modulate;
## her ikisinde ufak sarsıntı
func hit_flash(dur: float) -> void:
	if _is_sprite:
		var sprite := _visual as Sprite3D
		sprite.modulate = Color(1.0, 0.35, 0.3)
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, dur)
	elif _mat != null:
		_mat.set_shader_parameter("emission_color", Color(1.0, 0.25, 0.15))
		_mat.set_shader_parameter("emission_strength", 1.8)
		var tw := create_tween()
		tw.tween_property(_mat, "shader_parameter/emission_strength", 0.0, dur)
	var shake := create_tween()
	shake.tween_property(_visual, "position:x", 0.06, dur * 0.25) \
		.set_trans(Tween.TRANS_SINE)
	shake.tween_property(_visual, "position:x", 0.0, dur * 0.75) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## Ölüm: küçülerek yok ol
func die_anim(dur: float) -> Tween:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, dur) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if _badge_sprite:
		tw.tween_property(_badge_sprite, "modulate:a", 0.0, dur * 0.6)
	if _flag_hp_label:
		tw.tween_property(_flag_hp_label, "modulate:a", 0.0, dur * 0.6)
	return tw
