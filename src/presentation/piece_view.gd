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
var _label: Label3D
var _status_label: Label3D

func setup(class_key: StringName, stat_text: String, scale_mul: float = 1.0, sprite_path: String = "") -> void:
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		_setup_sprite(sprite_path, scale_mul)
	else:
		_setup_capsule(class_key, scale_mul)
	_add_blob_shadow(scale_mul)

	_label = Label3D.new()
	_label.text = stat_text
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.006
	_label.font_size = 40
	_label.outline_size = 10
	_label.position.y = _visual_h + 0.35
	add_child(_label)

	# Statü şeridi (§16.6 dummy'si): birimin altında minik metin satırı
	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.no_depth_test = true
	_status_label.pixel_size = 0.005
	_status_label.font_size = 30
	_status_label.outline_size = 8
	_status_label.modulate = Color(0.85, 0.95, 1.0)
	_status_label.position.y = _visual_h + 0.12
	add_child(_status_label)

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
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# şeffaflık sıralama sorunlarına karşı kesin alfa kesimi
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.no_depth_test = false
	# hedef boy ~1.4 dünya birimi (görsellerin kendi kenar boşluğu payıyla)
	var target_h := 1.4 * scale_mul
	sprite.pixel_size = target_h / float(tex.get_height())
	sprite.position.y = target_h * 0.5
	add_child(sprite)
	_visual = sprite
	_visual_h = target_h
	_is_sprite = true

## Yumuşak siyah karaltı — sprite gerçek gölge düşüremez, bunu kullanır
func _add_blob_shadow(scale_mul: float) -> void:
	var shadow := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	var r := (0.74 if _is_sprite else 0.6) * scale_mul
	mesh.size = Vector2(r, r * 0.72)   # iso perspektifte hafif elips
	shadow.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/blob_shadow.gdshader")
	shadow.material_override = mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position.y = 0.025
	add_child(shadow)

func set_stat_text(text: String) -> void:
	_label.text = text

func set_status_text(text: String) -> void:
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
	else:
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
	if _label:
		tw.tween_property(_label, "modulate:a", 0.0, dur * 0.6)
	return tw
